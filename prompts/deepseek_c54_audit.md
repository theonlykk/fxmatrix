This message has a line count at the bottom

# DEEPSEEK R1 -- RED-TEAM C54: ADR-162 B1 MERGED WITH C52, PLUS THE T-3 GUARD

You are auditing a feature branch BEFORE it merges to `main`. It is
tested on GBPUSD and EURUSD: the merge of `main` into the branch
(`47e7df5`) 2014/2014; the new tests (`ee0d24a`) 2052/2057, failing
exactly the 5 predicted; the fix (`c7855da`) 2057/2057. Find what tests
cannot see. The attached files carry NO line numbers: cite `file`,
`function` and QUOTE the line (one line, or part of one). A claim without
a quote is discarded. Line numbers below are ours, for orientation.

**The system:** an MQL5 passive limit-order FX market maker (no stops, no
market orders, hedging account, 0.01 lots). Eleven instances per terminal
share global variables (GVs). Each side holds filled layers, each with
one exit; the exit queue (ADR-151, K=1, H=0) keeps only rank 0 and the
highest rank resting, releasing and cancelling exits as ranks change in
tick and trade events. I6 checks each resting exit against its formula
(effective entry, exit pips, accrued carry, eject offset, carry shift;
2-point tolerance); a quarantine that does not clear in 3 s and 3 checks
halts the instance.

**B1 (ADR-162, the virtual lattice, input `InpVirtualLattice`, default
false):** at cap, when the market trades through the next grid level, the
OLDEST unrolled layer is "rolled": its exit is re-priced to that level's
exit (`Grind_LatticeRollLayer`, engine ~760) and a virtual level GV
(`GRIND_VL_<ticket>`) records the level, which every exit formula reads
as the layer's effective entry (`Grind_EffectiveEntry`, carry ~619).
Branch M (the layer has an exit order): modify first, then store the VL.
Branch S (no exit order): store the VL, the queue places the exit. A gap
loops per level (`Grind_LatticeTrySide`, engine ~829). A modify failure
backs the side off (60 s doubling, cap 1800 s). No layer is rolled twice.

**C52 (already on `main`, live on both fleets):** the nightly carry pass
(`grind_carry.mqh`, 23:50-00:00 broker, OnTimer, 2 items per 60 s step)
captures each layer at `Grind_CarryExitPassBegin` (~936) but, per item,
looks up the layer's CURRENT exit in the live book
(`Grind_CarryCurrentExitTicket` ~987, step ~1163) and shifts from
`Grind_CarryWorkBase` (~975), which reads the VL and offset GVs at step
time.

**This branch = B1 + C52 merged + C54:** commit 0 merged `main` into the
branch (only the test file conflicted; `grind_carry.mqh` auto-merged:
C52's lookup, B1's ticket-0 guard in `Grind_VLHas` ~597 and B1's prune
without its `GRIND_VL_` branch ~1006). C54's fix (engine ~778-784): in
`Grind_LatticeRollLayer`, after the ALREADY_ROLLED and CLOSING checks,
`if(layer.exit_order_ticket != 0 && !Grind_SelectOurOrder(...)) return
GRIND_ROLL_CLOSING;` -- an exit that filled at the broker but whose deal
is not processed yet (or was removed) no longer reports ROLL_REFUSED,
counts a failure or backs the side off; `TrySide` treats CLOSING as "stop
this tick" (engine ~875: `if(rc != GRIND_ROLL_OK) break;`).

**Ruled -- do not re-open:** Gemini GC1-GC5 (the attached spec, bottom):
one code for filled and removed exits; merge `main` into the branch;
LB30 made unconditional; OnTimer and OnTick are single-threaded per EA,
so a roll never lands inside a pass step; T-1, T-5, T-9's clock point,
C57 (offset/carry prune), C58 and C60 are out of scope. Earlier rulings
GA1-GA5 and GB1-GB10 (ADR-162) stand. Verified by us: pipshed's archive
keeps only whitelisted `scalp_closed` fields, so B1's new `rolled` key is
ignored there until C56.

## GIVENS -- verify each (VERIFIED or FALSE, with the quote)

- G1. The C54 guard returns `GRIND_ROLL_CLOSING` before any modify,
  report, VL write or queue call when the layer's exit order is set but
  not selectable.
- G2. `Grind_LatticeTrySide` changes neither the failure count nor the
  backoff on `GRIND_ROLL_CLOSING`.
- G3. With `InpVirtualLattice=false`, `Grind_LatticeOnTick` returns before
  any roll.
- G4. `Grind_CarryWorkBase` reads the VL live, so a pass item processed
  after a roll prices from the rolled level, not from the capture.
- G5. The merged `grind_carry.mqh` equals `main`'s except B1's two
  changes (the `Grind_VLHas` ticket-0 guard; the prune without VLs).

## THREATS -- verdict each: HOLDS / BREAKS / NEEDS-FIX

- **T-1 The guard's reach.** `Grind_SelectOurOrder` is false for: a
  filled exit whose deal is unprocessed; an exit cancelled by hand or by
  the broker; an order of another magic; ticket 0. In each case, what
  clears the layer's stale `exit_order_ticket` afterwards (deal
  processing, reconciliation, I3 quarantine, `Grind_RetryMissingExits`)?
  Is there a state where the ticket stays stale forever, so the side
  never rolls again and nothing reports it (the guard is silent)?
- **T-2 Off means off.** With `InpVirtualLattice=false` (every live
  preset), list EVERY code path the merged build runs differently from
  `main` `5685e4f` on a live book (init prints and markers, the
  `rolled` key in `scalp_closed`, the prune, `Grind_VLHas`, rank arrays,
  exit formulas). Can any change a live exit, an entry, an invariant or
  a halt?
- **T-3 Roll inside a carry pass.** Tests LB37-LB39 cover: pass step then
  roll (branch M); roll before the first step (branch M); roll between
  steps (branch S). Find an interleaving they miss that breaks I6 or
  loses an accrual: a gap loop rolling several layers mid-pass; a roll
  whose modify is CLAMPED (it records a carry shift) followed by the pass
  shifting the same exit; a pass clamp (shift plus release marker)
  followed by a roll (`Grind_CarryShiftDelete` or `RecordShift`); the
  short side; a sign-guard skip on the effective entry (GA2) after a
  roll.
- **T-4 Accrual used by a roll.** A roll reads `Grind_CarryAccruedGet`
  at roll time. Between a pass's commit of a new accrual and the modify
  of that layer's exit (same item) nothing can run; across items it can.
  Can a roll place or modify an exit with an accrual the pass is about
  to change, leaving the exit one night behind its GV?
- **T-5 Restart.** A reattach mid-pass after rolls: `Grind_ReconstructState`
  with VLs, accruals and shifts in GVs; the pass restarts from scratch.
  Does any rolled exit fail I6 or reconstruction?
- **T-6 Merge correctness.** Does anything in the auto-merged
  `grind_carry.mqh` or in `fxgrind.mq5` combine B1 and C52 in a way
  neither branch was tested for (other than T-3)?
- **T-7 Tests.** Which C54 behaviour has no test that fails without it?
  Does any assertion in `fxgrind_tests_c54.mqh` pass vacuously (inside an
  `if`, on leftover state, or on a fixture that never reaches the code)?

## OUTPUT

Sections in this order: `GIVENS CHECK` (G1-G5), `T-1` ... `T-7`
(verdict, evidence with quotes, smallest fix if any), `PREMISE VERDICT`
(is the branch safe to merge to `main` with the lattice OFF, and is B1 +
C52 + C54 consistent with it ON), `TEST GAPS`. No preamble. If you assume
a value (an MT5 behaviour, an order of events), say ASSUMED and why.

Line count: 123
