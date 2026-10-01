This message has a line count at the bottom

# DEEPSEEK R1 -- RED-TEAM ADR-165: CONTINUOUS RE-ROLL

You are auditing a feature branch BEFORE it merges to `main`. It is
tested on GBPUSD and EURUSD: tests against stubs (`eac5e3d`) 2395/2434,
failing exactly the 39 predicted; the implementation (`ac4433e`)
2434/2434 on both. Find what tests cannot see. The attached files carry
NO line numbers: cite `file`, `function` and QUOTE the line (one line,
or part of one). A claim without a quote is discarded. The attached ADR
(`ADR-165-continuous-reroll.md`) gives the incident, the design and the
rulings (s9).

**The system:** an MQL5 passive limit-order FX market maker (no stops,
no market orders, hedging account, 0.01 lots, cap 8 layers per side),
eleven instances per terminal, one symbol and magic each ("account
slot" below means the instance's slot string, NOT an OPT/ALT arm). A
side adds a layer every `add` pips against it; each layer has an exit
`exit` pips from its entry. The exit queue (ADR-151) keeps only rank 0
(nearest) and the highest rank resting as broker limit orders.

**The ADR-162 virtual lattice (live, unchanged):** at cap, when the
market crosses the next level (lowest effective entry minus `add` for a
long; the ask for a long, the bid for a short, plus the tick-history
extreme), the UNROLLED layer with the highest entry is ROLLED: its exit
is re-priced to `level + exit` (+ the accrued swap, clamped passive),
its virtual level (VL) is stored in a GlobalVariable, and its effective
entry becomes the VL. `Grind_LatticeTrySide` loops up to `max_layers`
times per call. With nothing unrolled the side STRANDS:
`Grind_LatticeMaybeStranded` warns `ROLL_STRANDED` once per episode, 2
add steps past the level, and the loop stops.

**This branch (default OFF, `InpLatticeReroll`):**
- `Grind_LatticeRerollIndex` (new): among layers with a position and a
  VL, the highest VL (long) / lowest (short); ties to the lower
  `layer_index`; none -> -1.
- `Grind_LatticeTrySide` gains a trailing `reroll`. Where the first-roll
  candidate is < 0: if `reroll` and one re-roll already happened in
  this call, break; if `reroll` is off or the server clock is in
  23:50-00:15 (`Grind_LatticeRerollPaused(now)`, `now` =
  `TimeCurrent()`), strand as today; else take the re-roll index (none
  -> strand). The existing closing check then applies (exit position
  present -> note closing, stop the loop). The roll call passes source
  `"reroll"` and `allow_reroll = true`. On success: count the re-roll
  and clear that side's stranded latch.
- `Grind_LatticeRollLayer` gains a trailing `allow_reroll`: skips the
  `ALREADY_ROLLED` refusal and records the previous VL as `from_level`
  in the `ROLL_ACCEPTED` detail (`"reroll"`, `"from_level"`).
- `Grind_LatticeOnTick` passes `reroll` to both sides; `OnTick` passes
  `InpLatticeReroll`. `OnInit`: FATAL if reroll is on without the
  lattice; prints `GRIND_REROLL enable=`; `LATTICE_CONFIG` gains
  `"reroll"`.

**Ruled -- do not re-open:** which layer (highest effective entry, long:
GR-1); trigger the moment the next level is crossed (GR-2); at most ONE
re-roll per side per call, first rolls unlimited (GR-3, GC-2); the pause
23:50-00:15 SERVER time (GR-4, GC-3; a long rolls on the ask and a
short on the bid, so a spread spike cannot trigger a re-roll); keep
`ROLL_STRANDED` as the failure signal (GR-5); a closing candidate STOPS
the loop as for a first roll (GC-1); the accrual stays in the exit
formula and the clamp shift is deleted or re-recorded by the roll (s9);
no wind-down brake (operator, ADR-162 s19); default OFF. The realised
loss per rotation grows by `cap x add` (ADR s5): known and accepted.

**Deployment:** not before Mon 5 Oct (the D1 round 1 verdict); on the
IC demo fleets only (lattice on, auto-eject off); not on FTMO.

## GIVENS -- verify each (VERIFIED or FALSE, with the quote)

- G1. With `InpLatticeReroll = false` every path behaves exactly as
  before this branch: the new block reduces to the old strand-and-break,
  and `allow_reroll` is false at every call site.
- G2. The reroll FATAL in `OnInit` runs before `Grind_MagicLockClaim`.
- G3. With `allow_reroll = true`, `Grind_LatticeRollLayer` differs from
  a first roll ONLY in skipping the `ALREADY_ROLLED` refusal and
  recording `from_level`; the closing refusal still applies.
- G4. The re-roll path sends no market order and opens or closes no
  position: its requests are the exit modify and the exit queue's
  remove/place.
- G5. `Grind_EffectiveEntry` of a rolled layer equals its VL, so
  `Grind_LatticeRerollIndex` (by VL) picks the highest EFFECTIVE entry.
- G6. `Grind_LatticeOnTick` is called only from `OnTick` (not from
  `OnTimer`); a dead market therefore never re-rolls.

## THREATS -- verdict each: HOLDS / BREAKS / NEEDS-FIX

- **T-1 Wrong layer or wrong level.** After a re-roll the re-rolled
  layer has the LOWEST effective entry (long), so the next level steps
  down by `add`. Any path where the next level is computed from a stale
  value, the same layer is re-rolled twice in a row, or a layer without
  a resting exit (the exit queue holds only two) is re-priced wrongly
  (`exit_target` only, no modify).
- **T-2 Loop control.** The throttle `break`, the closing `break`, the
  backoff `break`, `rolled_count` (counts re-rolls too) and
  `closing_stop` / `Grind_LatticeResetClosingState` after the loop: any
  path where a re-roll leaves the closing state wrong, or the throttle
  hides a needed `ROLL_STRANDED`.
- **T-3 The stranded latch.** It is cleared on a successful re-roll.
  With re-roll on, a side can stay at cap for days. Is the latch ever
  left set so that a later real failure (every layer closing, modify
  failing, the pause) never warns? Is it cleared anywhere it should not
  be? No test covers the clear: say what the smallest test is.
- **T-4 The pause and server time.** `TimeCurrent()` is the last quote's
  server time. IC's server is UTC+3 in summer, so the Sunday open falls
  at about 00:00-00:05 server Monday: INSIDE the pause. ASSUMED: a
  weekend gap therefore strands a capped side until 00:15 and may warn
  `ROLL_STRANDED`; one re-roll per tick then works the backlog. Any
  hazard in that, or in a quote stamped before 23:50 arriving after it?
- **T-5 Interactions.** The nightly carry pass (re-prices rolled exits
  from the VL), I6 (`Grind_ReconExitMatchesEntry` from the VL),
  restart/reconstruction (VL GVs persist; ADR-163 rebuild), ADR-155
  commanded eject (validates the most underwater by effective entry),
  `ROLL_CLOSING_STUCK`, the breaker and quarantine (`blocked` returns
  early). Any of them broken by a VL that is overwritten again and
  again?
- **T-6 Failures.** A modify failure on a re-roll: backoff, fail count,
  VL not overwritten, `rerolls` not counted. A `GRIND_ROLL_CLOSING`
  return from the roll itself (exit position appears between the check
  and the roll). Any rc not handled the same as for a first roll?
- **T-7 Cost.** Requests per re-roll (modify plus the exit queue's
  remove/place), at most one re-roll per side per tick, eleven
  instances: the worst plausible day against a 2,000-requests-a-day
  budget per account, and the burst at 00:15 after a pause.
- **T-8 Tests.** Which behaviour has no test that fails without it? Any
  assertion in `fxgrind_tests_adr165.mqh` that passes vacuously (left
  over state from an earlier fixture, a reset that does not clear the
  stranded latch or the closing ticket, an `ArchiveFind` that would
  also pass if nothing ran)?

## OUTPUT

Sections in this order: `GIVENS CHECK` (G1-G6), `T-1` ... `T-8`
(verdict, evidence with quotes, smallest fix if any), `PREMISE VERDICT`
(is the branch safe to merge to `main` with the input OFF, and to switch
on for the IC fleets after round 1), `TEST GAPS`. No preamble. Do not
call anything fatal that has a fix: give the smallest fix. If you assume
a value (an MT5 behaviour, an order of events), say ASSUMED and why.

Line count: 139
