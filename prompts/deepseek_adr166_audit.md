This message has a line count at the bottom

# DEEPSEEK R1 -- RED-TEAM ADR-166: THE ROLL GATE

You are auditing a feature branch BEFORE it merges to `main`. It is
tested on GBPUSD and EURUSD: tests against stubs (`47facb4`) 2548/2580,
failing exactly the 32 tests tagged to fail (31 tagged F plus RG7c, whose
"(G)" label is a derivation slip: it fails at the stubs for the reason in
T-8); the implementation with three test-mechanics fixes (`634c7ea`)
2580/2580 on both. Find what tests cannot see. The attached files carry
NO line numbers: cite `file`, `function` and QUOTE the line (one line,
or part of one). A claim without a quote is discarded. The attached
design (`cursor_adr166_roll_gate.md`) gives the reason, the premises
P1-P4, the changes C1-C12, the tests and Gemini's rulings (s10).

**The system:** an MQL5 passive limit-order FX market maker (no stops,
no market orders, hedging account, 0.01 lots, cap 8 layers per side),
nine instances per terminal on the IC demo fleets, one symbol and magic
each. A side adds a layer every `add` pips against it; each layer has an
exit `exit` pips from its entry. The exit queue (ADR-151) keeps only
rank 0 (nearest) and the highest rank resting as broker limit orders.
An empty side places its L0 entry at mid +/- width on every call.

**The lattice (live, unchanged):** at cap, when the market crosses the
next level (lowest effective entry minus `add` for a long; the ask for a
long, the bid for a short, folded with a tick-history extreme tracked
since the newest layer opened), `Grind_LatticeTrySide` ROLLS the unrolled
layer with the highest entry (ADR-162; up to `max_layers` per call), or,
with `InpLatticeReroll`, RE-ROLLS the rolled layer with the highest VL
(ADR-165; one per side per call; paused 23:50-00:15 server). A roll moves
that layer's exit to `level + exit` and stores its virtual level (VL).
With nothing to roll the side strands and warns `ROLL_STRANDED`.

**This branch (default OFF, `InpRollGateOpposite = -1`):**
- `Grind_ValidateRollGateInputs(lattice, gate)`: -1, or >= 0 with the
  lattice; `OnInit` FATAL otherwise. `Grind_RollGateHolds(gate, opp)`:
  `gate >= 0 && opp > gate`.
- `Grind_LatticeTrySide` gains trailing `roll_gate`, `opposite_depth`.
  After the disabled / blocked / backoff returns and BEFORE anything
  else: if the gate holds, call `Grind_LatticeRollGateRestartExtreme`
  (that side's tracking = true, extreme = 0, from_msc = market time +
  1 ms) and `Grind_LatticeRollDeferredNote` (INFO `ROLL_DEFERRED` to the
  archive, once per gated episode, only when the live market crosses the
  next level), then `return 0`. Otherwise clear that side's deferred
  latch and continue exactly as before.
- `Grind_LatticeOnTick` passes each side the OTHER side's
  `Grind_SideDepth` (= `ArraySize(layers)`, filled layers only).
- The deferred latch also clears below cap (`Grind_LatticeTrackOneSide`)
  and in `Grind_LatticeResetBackoff`. `OnInit` prints
  `GRIND_ROLL_GATE opposite_max=`; `LATTICE_CONFIG` gains `"roll_gate"`.

**Ruled -- do not re-open (operator and Gemini, design s1 and s10):** the
gate itself (no roll while the opposite side holds more than N filled
layers); counting filled layers, not resting entries (GR6-2); no
throttle on first rolls at release (GR6-1); the extreme restart to
market time + 1 ms (GR6-3); `ROLL_DEFERRED` INFO archive-only and no
`ROLL_STRANDED` while gated (GR6-4); at 8/8 both sides hold (GR6-5);
scoring on equity (GR6-6). Whether the gate makes money is the live
test's question, not yours.

**Deployment:** IC demo fleets only (lattice on, auto-eject off), one
fleet at N = 0, the others at -1; not on FTMO. Build planned Fri 9 Oct.

## GIVENS -- verify each (VERIFIED or FALSE, with the quote)

- G1. With `InpRollGateOpposite = -1` every path behaves exactly as
  before this branch: `Grind_RollGateHolds(-1, x)` is false, and the
  only other new statement on that path clears the new deferred latch.
- G2. The roll-gate FATAL in `OnInit` runs before `Grind_MagicLockClaim`.
- G3. The gated path sends no order request, writes no VL, emits no
  `ROLL_STRANDED`, and leaves the closing state, the backoff and the
  fail count unchanged.
- G4. `opposite_depth` is the other side's filled-layer count at the
  moment of the call (`Grind_SideDepth`), never a resting entry.
- G5. `Grind_LatticeRollGateRestartExtreme` touches only the gated
  side's tracking, extreme and from_msc.
- G6. `ROLL_DEFERRED` goes to the archive only (no telemetry emit) and
  at most once per gated episode per side.

## THREATS -- verdict each: HOLDS / BREAKS / NEEDS-FIX

- **T-1 Gate decision.** `OnTick` evaluates the long side, then the
  short side, in one `Grind_LatticeOnTick` call, each with the other's
  depth read at that moment. Any path where the depth is stale (a fill
  processed between the two calls, a layer array mid-update), where the
  gate decision for one side changes the other's, or where `blocked` /
  backoff ordering lets a gated side act?
- **T-2 The extreme restart.** After a restart `tracking` is true, so
  `Grind_LatticeTrackOneSide` skips its initialisation and copies ticks
  from `from_msc` to `Grind_MarketTimeMsc()`. Cases: a dead market (no
  newer tick, so `from_msc` > market time); `CopyTicksRange` returning
  -1 or 0; the gate releasing on the same tick it last held; an EA
  restart while gated (globals re-initialised). Can any of them replay a
  dip from the held period, or leave the extreme stuck so that a real
  crossing after release is MISSED for longer than one tick?
- **T-3 The deferred latch.** Set on the first gated call that finds a
  roll due; cleared when an ungated call runs, below cap, or in the test
  reset. Any path where it spams the archive (cleared every call while
  still gated), or never re-arms after a real release?
- **T-4 Release.** When the opposite side empties the next call rolls
  every level the CURRENT market has crossed (first rolls unthrottled,
  re-rolls one per call). In a continuation that is the moment the
  counter layer's exit fills. Hazards in that timing: a roll placed
  while the counter side's new L0 is about to fill; a burst of modifies
  (count them per side and per instance); interaction with the pause.
- **T-5 Interactions.** The nightly carry pass and I6 (price from the
  VL; the gate writes no VL), reconstruction / ADR-163 rebuild after a
  restart while gated, ADR-155 commanded eject, `ROLL_CLOSING_STUCK`
  (only evaluated inside the ungated loop: a closing layer during a long
  hold never warns), the breaker and quarantine. Anything that relied on
  `TrySide` running its loop every call at cap?
- **T-6 Inputs and presets.** A preset without `InpRollGateOpposite`
  takes the default -1 (ASSUMED: MT5 uses the compiled default for a key
  missing from a .set). Values above `max_layers`, negative values below
  -1, the gate on with re-roll off. Anything that should FATAL and does
  not, or FATALs and should not?
- **T-7 Cost.** Requests saved and added: a held side sends nothing; a
  release can send up to `max_layers` modifies plus the exit queue's
  remove / place. Nine instances, a trending day, N = 0: the worst
  plausible burst and day.
- **T-8 Tests.** Which behaviour has no test that fails without it? Any
  assertion in `fxgrind_tests_adr166.mqh` that passes vacuously (state
  left from an earlier fixture, a reset that does not clear the new
  latch, the market-time seam left seeded, an `ArchiveFind` that would
  pass if nothing ran)? RG7c: at the stubs the first call of RG7 already
  rolls 7101, so the second call finds the next level out of reach and
  returns 0; confirm or refute that reading.

## OUTPUT

Sections in this order: `GIVENS CHECK` (G1-G6), `T-1` ... `T-8`
(verdict, evidence with quotes, smallest fix if any), `PREMISE VERDICT`
(is the branch safe to merge to `main` with the input at -1, and to set
N = 0 on one IC fleet), `TEST GAPS`. No preamble. Do not call anything
fatal that has a fix: give the smallest fix. If you assume a value (an
MT5 behaviour, an order of events), say ASSUMED and why.

Line count: 138
