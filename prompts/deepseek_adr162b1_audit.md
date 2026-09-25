This message has a line count at the bottom

# DEEPSEEK R1 -- RED-TEAM ADR-162 PHASE B1 (TRIGGER AT CAP, ROLL, GAP LOOP)

You are auditing an IMPLEMENTATION before it merges. It is tested: suite
2002/2002 on GBPUSD and EURUSD at `3188f72`; the stub commit failed all 69
predicted assertions. Find what tests cannot see. The attached files carry
NO line numbers: cite `file`, `function` and QUOTE the line (one line, or
part of one). A claim without a quote is discarded. Line numbers below are
ours, for orientation.

**The system:** an MQL5 passive limit-order FX market maker (no stops, no
market orders, hedging account, 0.01 lots so fills are all-or-nothing).
Eleven instances (one per magic) share terminal global variables (GVs),
including ONE daily request count (`GRIND_DAILY_API_COUNT`, limit 2000;
at 1900 ENTRIES stop for every instance; exits never stop). Each side holds
filled layers, each with one exit; the exit queue (ADR-151, K=1, H=0) keeps
only rank 0 and the highest rank resting; I3 requires the same ranks; I6
checks each resting exit against its formula. The queue CANCELS and PLACES
but never re-prices a live exit. Nightly carry shifts exits by accrued swap.

**ADR-162** (design in the attached spec): past the layer cap the grid
continues with VIRTUAL layers. When the market trades through the next
grid level, the oldest unrolled layer's EFFECTIVE entry is re-labelled to
that level (GV `GRIND_VL_<ticket>`) and its exit moves to level + exit
(+ accrued). Phase A (merged) substituted the effective entry at every
formula and rank site. **Phase B1 (this branch, `adr162-phase-b1`)** adds
the input `InpVirtualLattice` (default OFF), the trigger on the live tick,
the roll, the gap loop and a retry backoff. B2 (not here) adds an M1-bar
catch-up and a stranded WARN; B1 is never deployed without B2.

**Ruled -- do not re-open:** fires at cap only, never for a gate-blocked
add (Q1); no layer is ever rolled twice; modify first, VL stored only
after success (GB1); a VL is deleted only on the close path (GB2); a roll
deletes a hand-eject offset and carry shift (GB3); a new `rolled` flag in
`scalp_closed` (GB4); the candidate is the oldest unrolled layer by ACTUAL
entry, even a middle rank with no exit (GB6); the level is
`Grind_ComputeAddTarget` (GB7); tick path only in B1 (GB8); rolls ignore
the entry gate, breaker, API entry stop and session window (GB9); backoff
doubles per consecutive failure from 60 s, capped at 1800 s (GB5/GB10).
**Already found after Cursor and fixed on the branch:** a test forward
declaration with no body (compile error); LB25 built layers without exit
fields and passed three assertions on stale memory; LB30 dropped the wrong
ticket; the backoff overflowed `int` from 27 failures (LB32, now capped in
double before the cast).

## GIVENS -- verify each (VERIFIED or FALSE, with the quote)

- G1. `Grind_LatticeRollLayer` (`grind_engine.mqh` ~760): with a live exit
  it modifies FIRST (~788), and only on success sets the VL (~797),
  deletes the eject offset, records a clamp difference with
  `Grind_CarryRecordShift` (~801) as `Grind_ExitQManageSide` does, else
  deletes the carry shift. With no exit (branch S, ~805) it sets the VL,
  deletes offset and shift. Both then archive `ROLL_ACCEPTED` and call
  `Grind_ExitQManageSide` (~816). On a failed modify nothing is stored.
- G2. The roll target `Grind_ExitPrice(level) + accrued` equals
  `Grind_ExitQFormulaTarget` (`grind_exitq.mqh`) once the VL is set and
  the offset deleted.
- G3. `Grind_LatticeTrySide` (~821): returns 0 if disabled, blocked or
  inside the side's backoff; loops at most `max_layers` times; each pass
  re-checks depth >= cap, recomputes the level, compares ask (long) / bid
  (short), picks the candidate, stops if its exit has filled; on
  MODIFY_FAILED doubles the backoff (~860, ~868) and stops; resets the
  failure count on success.
- G4. `OnTick` (`fxgrind.mq5` ~332) calls `Grind_LatticeOnTick` after
  `Grind_EjectPollCommand` (~327) and `Grind_AutoEjectOnTick`, with
  blocked = halted || quarantined. Nothing in the roll path consults
  `Grind_EntriesBlocked` (`grind_engine.mqh` ~1086) or the session window.
- G5. `OnInit` refuses `InpVirtualLattice && InpAutoEject` (`fxgrind.mq5`
  ~141).
- G6. `Grind_LatticeCandidateIndex` (~694): layers with a ticket and no VL;
  long the highest actual entry, short the lowest; tie, lower index.
- G7. `Grind_VLHas` (`grind_carry.mqh` ~597) is false for ticket 0; the
  prune `Grind_CarryPruneShiftGvs` (~985) has no `GRIND_VL_` branch.
- G8. Close path (`grind_engine.mqh` ~2226-2252): `was_rolled` is read
  before the GVs are deleted; `scalp_closed` carries `rolled`;
  `ROLL_FILLED` is archived with the level.

## THREATS -- verdict each: HOLDS / BREAKS / NEEDS-FIX

- **T-1 I6 and I3 around a roll.** Is there ANY path where a VL exists
  while a live exit rests at a price that is not its formula target (I6
  would quarantine)? Consider: branch S when the queue then fails to
  place (slot guard); a modify that succeeds at the broker but reports
  failure; the <= 1 s GV flush window after a modify. After each roll the
  new highest rank has no exit until `Grind_ExitQManageSide` places it in
  the same call: can the next tick's I3 check see it naked, and when?
- **T-2 Gap loop.** Does the loop always terminate within `max_layers`?
  Can it roll a layer, then on the next pass pick a candidate whose exit
  the queue just CANCELLED (so branch S) or just PLACED (so branch M)?
  State the requests per level and per episode; can anything in the loop
  exceed 3 per level or re-roll a layer?
- **T-3 Candidate and ranks.** Is the candidate always the highest rank
  when an unrolled layer sits above the rolled ones? When it is a middle
  rank (after rolled fills and real re-adds), does branch S leave queue,
  I3 and I6 consistent? An exit order that has filled at the broker but
  whose deal is not yet processed (so `exit_position_ticket` is still 0):
  what does the roll do, and is MODIFY_FAILED + backoff the right result?
- **T-4 Carry pass mid-roll.** The nightly pass captures work items at
  `Grind_CarryExitPassBegin` and modifies later from
  `Grind_CarryWorkBase` over several timer steps. A roll between those
  steps on a captured layer: does the pass then move the rolled exit to
  the right price, keep the shift and release-marker semantics
  (`Grind_CarryShiftGetValidated`) and the sign guard consistent?
- **T-5 The level.** For an UNROLLED book at cap the level anchors on the
  highest `layer_index` (Phase A GA1 path), not the lowest entry. If an
  add filled away from its lattice level (clamped, gap), how far can the
  first virtual level sit from where the ADR intends, and in which
  direction? Any risk from `Grind_Normalize` or `GRIND_PRICE_EPS`?
- **T-6 Same-tick interactions.** A hand eject (`Grind_EjectPollCommand`)
  and a roll of the same layer in one tick; a carry-pass modify and a
  roll in one tick; `Grind_OnTickEngine` running after the roll in the
  same tick (adds, L0) with depth unchanged: any conflict?
- **T-7 Reporting and counts.** `g_grind_scalp_count` and the daily
  realised P&L still count a rolled fill as a scalp in the EA: where, and
  does anything in the EA (not pipshed) act on that count? Are
  `ROLL_ACCEPTED`, `ROLL_REFUSED` and `ROLL_FILLED` emitted exactly once
  per event?
- **T-8 Restart.** A reinit with rolled layers (VLs present, backoff and
  failure count reset): reconstruction, ranks and the first tick's
  trigger. Can the first tick re-roll or roll a layer already rolled?
- **T-9 Backoff.** `now` is `TimeCurrent()` (server time of the last
  quote): can it go backwards or stall so the backoff never expires, or
  expire early? Any path that returns MODIFY_FAILED without calling the
  broker (so it backs off for nothing)?
- **T-10 Tests.** Which B1 branches have no test that fails without them
  (short clamp, short gap, branch S on the short side, the ALREADY_ROLLED
  and CLOSING refusals inside the roll, the reset of the failure count)?
  Which assertion passes vacuously (e.g. an assertion inside an `if`)?

## OUTPUT

Sections in this order: `GIVENS CHECK` (G1-G8), `T-1` ... `T-10` (verdict,
evidence with quotes, smallest fix if any), `PREMISE VERDICT` (is "modify
first, VL after, queue after" consistent for every branch), `TEST GAPS`.
No preamble. If you assume a value (a timeout, an MT5 behaviour, an order
of calls), say ASSUMED and why.

Line count: 139
