This message has a line count at the bottom

# ADR-162 -- THE GRID CONTINUES PAST CAP: VIRTUAL LAYERS, REAL EXITS

**Status:** Phase A MERGED `c12901a` (s12); B1 + C54 MERGED `db86ede`
(s13-s14); B2 MERGED `669da60` (s15), all 2026-09-25, default OFF.
Deploy: Fleet B by preset, after C56 (pipshed) and a read-only check that
tick history works on the Wine box. Drafted 2026-09-24. Replaces ADR-157's trigger
(backlog C45). Not mid-cycle 3 (auto-eject is pre-registered ON there);
default-OFF input for a Fleet B phase or cycle 4. Operator's standard:
simple, boring, predictable. Every site below was read in `main` at
`5b81baf` (EA code = tested `238bb66`).

## 1. THE RULE (operator)

The grid never stops. Past cap, each further grid level is a VIRTUAL
layer: no entry order, but a real exit, paid for by the OLDEST remaining
layer. A virtual level fires the moment the market trades through its
ENTRY (never through its exit), with no delay; a gap through several
levels fires them all. Everything stays passive: a rolled exit is only
ever placed on the far side of the market, so it fills on a retrace.
No march, no stability test, no spread test, no N dial. V-shaped
recoveries are not designed against: their cost is bounded (s4).

## 2. THE MODEL: EFFECTIVE ENTRY

A roll does one thing: it re-labels the oldest position's EFFECTIVE
entry to the virtual level ("assume the most underwater layer is
actually layer 9"). Everything else follows from using the effective
entry wherever the grid reasons about levels:

    effective_entry(layer) = VL(ticket) if the position has a virtual
                             level, else entry_price
    exit_target(layer)     = ExitPrice(effective_entry) + accrued (+ carry shift)

For an unrolled book effective_entry == entry_price everywhere, so
nothing changes for a book that never reaches cap.

## 3. WORKED EXAMPLE (long, add 10, exit 5, cap 8; prices in pips)

    L0 140 ... L6 80 (exit 85), L7 70 (exit 75)            depth 8 = cap
    market falls to 19:
      level 60 crossed -> L0 effective 60, exit 65
      level 50 crossed -> L1 effective 50, exit 55
      level 40, 30, 20 -> L2, L3, L4 effective 40, 30, 20; exits 45, 35, 25
    market lifts to 25: L4's rolled exit (a SELL at 25) fills
      depth 7 -> the engine places ONE REAL add (a BUY). Virtual adds are
      never placed; only their exits are.
      today's code anchors that buy on the highest layer_index = the last
      REAL layer, L7 at 70 -> target 60 -> above the market -> clamped
      passive to ~25 (enters at the market, lattice out of step)
      with the effective entry it anchors on the last VIRTUAL level held,
      L3's 30 -> buy at 20, below the market, exactly where a real grid
      would re-add (as a normal scalp re-opens its own level today:
      L0 100 / L1 90 / L1 exits at 95 -> the add returns to 90, not 85).

## 4. COST: FIXED AND BOUNDED

Every roll realises `entry(Lk) - (level + exit)`; on a uniform ladder
that is `cap x add - exit` (8 x 10 - 5 = 75 pips), whatever the depth.
At most `cap` layers can be rolled on a side at any one time, so the
worst case per episode is `cap x (cap x add - exit)` (600 pips; $60 on
GBPUSD at 0.01 lots).

## 5. CODE SITES (verified)

| site | today | change |
|---|---|---|
| Add anchor: `Grind_ComputeAddTarget` (`grind_engine.mqh` 1509) | anchors on `Grind_FindDeepestLayerArrayIndex` (highest `layer_index`, 1294) | anchor on the LOWEST effective entry (long) / highest (short). Identical for an unrolled book; after a rolled fill it re-adds at the lattice, not near market (s3) |
| Exit ranks: `Grind_ExitQRanks` (`grind_exitq.mqh` 84) fed `entry_price` at engine 483/491 (command), 553/565 (auto), 2392 (queue), recon 445 | rank by entry | feed EFFECTIVE entries (== rank by exit price). Barbell unchanged: rank 0 + highest rank rest; the highest rank is automatically the oldest UNROLLED layer, which holds a live ticket for the next roll |
| Exit target: `Grind_ExitQFormulaTarget` (exitq 243), recon I6 expected (recon 133, 376), carry formula (carry 906/915), layer add (engine 1457), recon rebuild (recon 1125/1141) | `ExitPrice(entry) + accrued + eject_offset` | `ExitPrice(effective_entry) + accrued` for a rolled layer (see G2 on the offset) |
| Roll: new, beside `Grind_EjectAcceptLayer` (engine 379) | ADR-155 moves the exit to the market (`Grind_EjectTargetPrice`) | modify the oldest unrolled layer's exit to `level +/- exit`, store `VL`, archive `ROLL_ACCEPTED` (ticket, entry, level, target, cost) |
| Trigger: new, per side in `OnTick` beside `Grind_AutoEjectOnTick` (`fxgrind.mq5` 320) | ADR-157 stability + spread tests | at cap: `next = lowest_effective -/+ add`; fire while ask <= next (long) / bid >= next (short); loop for a gap |
| Detection catch-up | none | the M1 bar low/high since the last check (bars are bid-based: add the spread for longs; never fire earlier than a real limit would fill) for ticks skipped while busy and a restart mid-gap |
| Persistence: new GV `GRIND_VL_<ticket>` beside `GRIND_EJECT_OFFSET_<ticket>` (carry 547) | offset GV, deleted when the position closes (engine 1992) | VL GV with the same hygiene; reconstruction reads it; nothing else to store (k is the count of VL GVs on the side) |
| Next layer index: `Grind_SideNextIndex` (engine 1280) | max + 1 | unchanged; indices keep climbing after rolled fills (L08, L09 ...); see G5 |

## 6. WHAT IT RETIRES AND WHAT STAYS

Retires (for instances with the new input ON): ADR-157's W/k stability
test, its M1 stability data, backoff and orphan trailing. Stays: the
ADR-155 command path, gaining a "roll here" mode = fire the next level
now at the lattice level beyond the market (manual tail). A side whose
market sits more than `S` add steps beyond its lowest effective level
with nothing left to roll raises WARN `ROLL_STRANDED` (pipshed).

## 7. INPUTS

`InpVirtualLattice = false` (default OFF). With it ON, `InpAutoEject`
must be OFF or `OnInit` refuses (fail closed). `S` for the WARN is a
compiled constant until data says otherwise.

## 8. TESTS TO WRITE (names later, tests first as always)

Effective entry (unrolled == entry); add anchor on the lowest effective
entry (s3's re-add at 20, not near 25); ranks by effective entry
(rolled layer ranks 0, oldest unrolled is the highest rank); the
trigger fires through the entry not the exit (64 fires nothing, 60
fires); a gap fires every level in order (60 -> L0 ... 20 -> L4); cost
per roll is `cap x add - exit` on a uniform ladder; worst case stops at
`cap`; VL GV round-trips through reconstruction and I6; OFF is inert.

## 9. EVIDENCE BEFORE BUILD

Cycle 3's live ejections at week end (none so far: deepest side 4 of 8
on both fleets at 22:18Z 24 Sep) and cycle 2's deep books: how often
sides reached cap, how far past, and what the lattice would have
realised against what ADR-155/157 did.

## 10. FOR GEMINI

- **G1.** The effective-entry model: one substitution (effective entry
  for entry) at the sites in s5 instead of special-casing rolled
  layers. Any site that reasons about levels that we missed?
- **G2.** Store the virtual level (entry space) in a new GV, not
  ADR-155's exit offset (exit space, entangled with nightly carry
  accrual). Keep reading offset GVs for legacy ejected positions.
  Accept, or reuse the offset?
- **G3.** Ranking by effective entry changes the ORDER only for rolled
  layers (and would change it for an unrolled book only if accrued
  carry exceeded one add distance). Any risk to I3 coverage or the
  trim-before-protect path during the moment of a roll?
- **G4.** Gap detection by tick plus M1 catch-up, bid bars plus spread
  for longs. Is "never earlier than a real limit" the right bias?
- **G5.** Layer indices climb past 7 after rolled fills; comments
  carry `L%02d`. Any parser, invariant or pipshed assumption that
  indices stay below the cap (or below 100)?
- **G6.** Fixed cost per roll assumes a uniform ladder; after
  re-centering or partial fills the ladder is not uniform. State the
  cost as `entry(Lk) - (level + exit)` per roll (known at firing) and
  keep the worst-case bound as `cap` rolls. Accept?

## 11. GEMINI RULINGS (2026-09-24) AND OUR VERIFICATION

His reply: 13 lines as pasted, no line-count footer.

- **G1 ACCEPTED AS A GUARD.** The effective entry is used ONLY at the
  lattice sites in s5 (add anchor, exit ranks, exit target, I6, roll,
  trigger). Reporting keeps the ACTUAL entry: the heartbeat's
  `entry_price` (`grind_heartbeat_detail.mqh` 249-254) is unchanged and
  gains a `virtual_level` field for rolled layers; P&L and MTM come from
  the broker's position profit. His "margin allocation" point has no
  target: the grind EA has no per-entry margin logic (its "margin" is
  the commitment guard's spare slots).
- **G2 ACCEPTED.** New `GRIND_VL_<ticket>` GV, entry space.
- **G3 REJECTED (verified in source).** Trim-before-protect does not
  rank by floating loss: it cancels live exits that the barbell
  predicate `Grind_ExitQRequired(rank, depth)` does not require
  (engine 2392-2405), and I3 coverage uses the SAME predicate (recon
  507, 536, 1057). Queue and I3 must rank identically or every rolled
  book fails I3. Ranking by ACTUAL entry is also what stalls the
  lattice: the rolled L0 stays the highest rank, the next candidate
  (L1) is a middle rank with no live exit, and ADR-155's validator
  refuses it (`GRIND_EJECT_NOT_DEEPEST` / `NO_EXIT_ORDER`,
  `grind_pure.mqh` 284). Effective ranks keep the oldest UNROLLED layer
  at the highest rank. "True drawdown" stays visible through G1's
  reporting rule.
- **G4 ACCEPTED.** (His backtesting remark does not apply: this is live
  detection.)
- **G5 VERIFIED SAFE, test added.** Both parsers split on `|` and read
  the integer after `L` (`GrindCommentParse`, `grind_comment.mqh`;
  pipshed `_parse_grind_comment`, `app.py` 1164), so `L100` parses.
  Layer arrays are dynamic and map labels by lookup
  (`Grind_ReconEnsureLayer`, recon 310); no bound ties `layer_index` to
  the cap (`Grind_CanPlaceEntryLayer` counts layers, not indices).
  `GRIND|OPT|L|L100|EXT` is 20 of 31 chars. Add a parse test for L100.
- **G6 CONFIRMED.** His arithmetic matches s4 (L0 140 -> 65 = -75,
  L1 130 -> 55 = -75); state the cost per roll as
  `entry(Lk) - (level + exit)`, known when it fires.

## 12. PHASE A -- MERGED `c12901a` (2026-09-25)

**Landed** (EA code = tested `9466b22`; spec with Gemini GA1-GA5, all
accepted: `prompts/cursor_adr162_phase_a.md`). GV `GRIND_VL_<ticket>`
(entry space) and `Grind_EffectiveEntry` (carry 617), substituted at
every exit-price formula (exitq 253; recon 133, 378; carry 952, 962,
976; engine 408) and every rank array (engine 484, 493, 556, 569, 2426;
recon 447). Add anchor on the effective extreme only when the side holds
a VL (engine 1514, GA1); carry sign guard on the effective entry (carry
650, GA2); a hand eject of a rolled layer is allowed (GA3). VL deleted on
close (engine 2026), pruned with its position (carry 997), in
`scripts/grind_gv_clean.mq5`; heartbeat `virtual_level` on rolled layers
only. No input, no trigger, no roll: nothing outside tests sets a VL, so
a live book is unchanged by construction. Reporting keeps the actual
entry; the `EJECT_ACCEPTED` `raw` field is effective-based by design.

**Verified:** stub `cb4c51f` 1850/1874 on GBPUSD and EURUSD, exactly the
24 predicted failures; tip `9466b22` 1875/1875 on both.

**Found after Cursor, fixed on the branch:** (1) the spec missed a sixth
exit-price site, `Grind_CarryWorkBase` (carry 976), the base the nightly
pass actually modifies to; VL10 had checked only the stored copy
(`g_grind_carry_exit_work_formula`). Test `268bde0`, fix `b982f77`.
(2) The new assertion then failed for a setup reason: `PassBegin` ends
with the prune, which deleted the test's VL (test position 1001 does not
exist); `9466b22` re-sets it after `PassBegin`, as F5 does for the offset.

**DeepSeek `6e10967`** (each verdict checked in source): G1-G9 verified;
T-2 (missed site), T-4 (eject a rolled layer), T-5 (sign guard) HOLD.
Carried to Phase B:
- **B1** (T-1/T-6): `Grind_VLHas` false for ticket 0 (the anchor loop,
  engine 1524, has no ticket-0 guard; unreachable today, every layer
  carries a position ticket).
- **B2** (T-3): when may a VL be deleted? The prune deletes it whenever
  `PositionSelectByTicket` fails. At `OnInit` it runs after
  reconstruction (`fxgrind.mq5` 195) and the EA has no connection check
  anywhere, so it rests on the premise reconstruction already rests on
  (offset and carry GVs too). A lost live VL fails I6 on the rolled
  exit. For Gemini: close path only, or prune gated on a healthy
  reconstruction.
- **B3** (T-8): tests for command ranks (engine 484/493), auto ranks
  (556/569), the short side of I6, sign guard, anchor, queue, carry base
  and close; a live VL surviving the prune; a restart with a VL through
  `Grind_ReconstructState`.
- **B4** (GA5): a rolled exit's fill is flagged in `scalp_closed` and not
  counted as a scalp (s4, Daily card).

## 13. PHASE B1 -- BUILT ON `adr162-phase-b1`, NOT MERGED (2026-09-25)

**Operator decisions (2026-09-25).** Q1: fires at cap only, never for a
gate-blocked add. No layer is ever rolled twice, by any path: one
automatic sweep, then a stranded side (every layer rolled, market S or
more add steps beyond the lowest effective level) raises ROLL_STRANDED
(B2) and waits; the operator investigates first (it may be a fault, not a
trend), then uses the ADR-155 hand eject or leaves it. "Roll here" is
DEFERRED until B has run live (backlog C53): s6's "roll here" and C45's
text are superseded. Q2 (inferred from ADR-161, not discussed with the
operator): rolls run outside the session window; Fleet C does not run
the lattice. Q4: deploy target at week end. Phase B is split: B1 (input,
trigger, roll, gap loop, B1-B4), B2 (M1 catch-up, ROLL_STRANDED, C55),
pipshed (C56).

**Corrections to s5 and C45.** The roll target is `ExitPrice(level) +
accrued` (the formula once the VL is set and any offset cleared), clamped
passive; not "level +/- exit". A gap does NOT send all rolled exits at
once: under K=1/H=0 only the newest rolled exit and the oldest unrolled
layer's exit rest, and each fill releases the next. The gap loops per
level (modify, store VL, queue cancels the old rank 0 and places the new
highest): about 3 requests per level, at most cap levels per side per
episode, against ONE fleet-wide daily count (2000; entries stop at 1900).

**Spec** `prompts/cursor_adr162_phase_b1.md` (on the branch, rulings
inside). GB1 modify first, VL only after success. GB2 VL deleted on the
close path only (the prune lost its `GRIND_VL_` branch; Phase A test VL12
flipped on purpose). GB3 a roll deletes a hand-eject offset and carry
shift. GB4 a new `rolled` key in `scalp_closed` (reusing `ejected` breaks
pipshed `eject_mismatch`). GB5 accepted on a wrong premise (a per-side
budget) and amended by Claude: backoff doubles per consecutive failure
from 60 s, capped at 1800 s; GB10 accepted the amendment. GB6 candidate =
oldest unrolled by ACTUAL entry (branch S: a middle rank with no exit gets
the VL and the queue places it). GB7 level = `Grind_ComputeAddTarget`.
GB8 tick path only; B1 never deploys without B2. GB9 rolls ignore the
entry gate, breaker, API entry stop and session window.

**Built:** Cursor `5865060` (tests vs stubs), `f95d4b8` (implementation).
Claude patches: `a949d65` (a test forward declaration with no body broke
the compile), `867d3c8` (LB25 built layers without exit fields and passed
3 of 4 on stale memory; LB30 dropped the wrong ticket), `d5cf777` (LB32),
`3188f72` (the backoff overflowed `int` from 27 failures; capped in double
before the cast). Audit inputs `9315e18`; DeepSeek response `73b1a8d`.

**Verified:** stub plus compile fix 1927/1999 on GBPUSD (all 69 predicted
plus the 3 LB25/LB30 faults); before the overflow fix 2000/2002 (only
LB32: the overflow is real on this build); tip `3188f72` 2002/2002 on
GBPUSD and EURUSD.

**DeepSeek `73b1a8d`, each verdict checked in source.** G1-G8 verified.
T-3 CORRECT: an exit filled at the broker but not yet processed fails the
roll at `Grind_SelectOurOrder` with no broker call, reports ROLL_REFUSED
and backs off for nothing; fix in C54. T-10 CORRECT: LB30's "rolled
target" sits inside an `if`; the failure-count reset is not asserted; no
short gap test; the refusals inside the roll are untested; tests in C54.
T-4 REAL BUT PRE-EXISTING: the carry-pass race (C52), a live defect not
caused by B1. T-1 (slot guard after a roll; unchecked GV writes):
pre-existing and engine-wide. T-5 (anchor on the highest index): ruled
GA1/GB7, and under K=1/H=0 the highest index is the lowest entry. T-2,
T-6, T-7, T-8 hold; T-9 reduces to T-3.

**Before merge:** C54. Deploys nowhere until B2 (C55).

## 14. PHASE B1 + C54 -- MERGED `db86ede` (2026-09-25)

**C54** (spec `prompts/cursor_c54_b1_post_audit.md`, Gemini GC1-GC5 all
accepted, two of his reasons corrected in the spec). Commit 0 `47e7df5`
merged `main` (C52) into the branch: only the test file conflicted.
Tests `ee0d24a`: LB30 made unconditional ("found"); LB33-LB36 (T-3 and
T-10: order-gone roll, refusals, failure-count reset, short gap); LB37-LB39
(a roll during the carry pass: pass then roll, roll then pass, branch S).
Fix `c7855da`: `Grind_LatticeRollLayer` returns CLOSING when the layer's
exit order is set but not selectable (no broker call, no ROLL_REFUSED, no
failure count, no backoff).

**Verified:** merge state 2014/2014; tests 2052/2057 failing exactly the
five predicted (three LB33, two LB34); fix 2057/2057; all on GBPUSD and
EURUSD. LB37-LB39 passed in every state: B1 and C52 agree on the tested
paths.

**DeepSeek `9f9a86d`, each verdict checked.** G1-G5 verified; T-4, T-5
HOLD. T-6 "BREAKS" REJECTED: the prune lost its `GRIND_VL_` branch on
purpose (GB2), not in the merge. T-2 "stale VL with the lattice off"
REJECTED: a VL is keyed by position ticket, tickets are never reused,
and none exists live. T-1 CORRECT, pre-existing: a stale exit ticket on
an allowed rank is cleared only by deal processing (the queue's cancel
path clears non-allowed ranks); a hand delete trips I3 (loud), but a
filled exit whose deal event is lost now makes the roll return CLOSING
every tick silently -> a latched WARN in B2 (C55). T-3 (short side, sign
guard on the effective entry): pre-existing GA2 semantics, a test gap ->
short-side roll-during-pass tests in C55. T-7: its "vacuous" rows are
the spec's declared preconditions.

**With `InpVirtualLattice=false`** (every preset) the build differs from
`5685e4f` only by: `GRIND_LATTICE enable=false` printed and a
`LATTICE_CONFIG` marker at init, `rolled:false` in `scalp_closed`
(pipshed's archive ignores it until C56), and empty VL lookups. Deploys
nowhere until B2.

## 15. PHASE B2 -- MERGED `669da60` (2026-09-25)

**Design changes from s10 G4 / backlog C55 (operator, Gemini GD1-GD6):**
catch-up reads TICK HISTORY (`CopyTicksRange`, exact bid and ask of every
tick, including ticks `OnTick` never saw), not M1 bars (bid bars with the
bar's MINIMUM spread would roll a long side on a rollover spread spike).
Per side at cap the lattice keeps a RUNNING EXTREME (lowest ask / highest
bid) since the side reached cap: window from 1 s after its newest open,
at most 24 h back, cursor past the last tick read, reset below cap, no
GV. A level traded through while a roll was held off (backoff, closing,
quarantine) rolls afterwards even if the market has come back: operator,
2026-09-25, "if we are 8 deep and the market is gapping, i would rather
we were active in these demos than not". ROLL_STRANDED: every layer
rolled and the LIVE market 2 add steps beyond the lowest effective level,
one WARN per episode. ROLL_CLOSING_STUCK: the candidate "closing" 60 s on
the same position (DeepSeek C54 T-1), latched. Tick-read failure: silent
retry (GD6).

**Built:** spec `prompts/cursor_c55_adr162_phase_b2.md`; Cursor `4ca8119`
(stubs, seams, 57 tests), `9db6b85` (implementation); Claude `00e0e4e`
(MQL5 rejects `static` on file-scope functions: six removed). Suites
(GBPUSD and EURUSD): stubs 2091/2114 failing exactly the 23 predicted;
`00e0e4e` 2114/2114.

**DeepSeek `bb7b942`, checked:** every threat HOLDS. T-2 (a stale extreme
across a refill) verified in source: a rolled exit's OUT_BY path never
places an add, and the re-add is placed only by the tick engine, which
runs after the lattice's tracking, so the reset always comes first.
Follow-ups (backlog C62, none blocking): a defensive reset when the
side's newest open changes; a sanity band on historical tick prices
(T-1: a bad print would roll, as it would on the live path today); tests
for the live `CopyTicksRange` branch (never executed in tests: the seam
takes over), the live-price-only fold and an open-time lookup failure;
`stuck_s` reports the constant 60.

**Before the lattice goes on Fleet B:** C56; a read-only script on the
box proving `CopyTicksRange(COPY_TICKS_INFO)` returns ticks (GD6 note);
presets `InpVirtualLattice=true`, `InpAutoEject=false` (OnInit refuses
otherwise); a weekday during the session, not a dial day.

Line count: 357
