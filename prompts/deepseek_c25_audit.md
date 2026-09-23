This message has a line count at the bottom

# DEEPSEEK R1 -- RED-TEAM C25: ENABLING THE CARRY PASS

You are auditing an IMPLEMENTATION before it merges. It is tested (suite
1547/1547; the two new failures were predicted and seen before the fix).
Your job is what tests cannot see: whether turning carry ON is safe.

**The system:** an MQL5 passive limit-order FX market maker, no stops,
no market orders. Each side holds layers (positions). Under the F1
"barbell" exit queue, rank 0 (nearest) and rank `depth - 1` (deepest)
MUST have a resting exit limit; middle layers are "held" (no order).
Every exit's target is `raw + accrued + eject_offset + shift`, and
invariant I6 checks each resting exit against exactly that (2-point
tolerance). A plain I6 failure HALTS the instance.

**The carry pass** runs in a window around rollover. For every layer it
recomputes accrued swap (ledger + tonight's pending, weekday multiplier),
stores it, and moves the resting exit by it, clamping to the best passive
price; the clamp residual is stored as the shift.

**Until now carry was OFF:** `OnInit` refused to start with
`InpEnableCarryPass=true` (ADR-151 "phase A"). C25 closes ADR-151 Phase B
and removes that guard. **Do not re-open whether carry should be on**
(operator decision: an exit that ignores accrued swap locks in a loss).
Attack only whether enabling it is SAFE.

Attached at branch `c25-unblock-carry` `c551c9e`: `fxgrind.mq5`,
`grind_carry.mqh`, `grind_engine.mqh`, `grind_exitq.mqh`,
`grind_recon.mqh`, `grind_pure.mqh`, and ADR-151.

## GIVENS -- verify each, cite the line

- G1. The `OnInit` carry guard is gone; `OnInit` goes from the magic
  checks to `Grind_MagicLockClaim` (`fxgrind.mq5:135`).
- G2. `Grind_CarryRecordShift` (`grind_carry.mqh:513`) stores the shift
  and SETS the release marker when clamped, DELETES it otherwise; the
  carry pass calls it (`:1020`).
- G3. `Grind_CarryShiftGetValidated` (`:639`) returns the shift unbounded
  when the release marker exists or the layer is ejected; otherwise it
  bound-deletes via `Grind_CarryShiftWithinBound` (`:619`).
- G4. The release path already sets shift + marker on a clamp
  (`grind_engine.mqh:1981`).
- G5. Accrual is committed only with no resting order, or after a
  successful modify (`:976`, `:1015`).
- G6. The carry pass runs from `OnTimer` (`fxgrind.mq5:275`) gated by
  `InpEnableCarryPass`.

## THREATS -- verdict each: HOLDS / BREAKS / NEEDS-FIX

- **T-1 Other phase-A assumptions.** Besides the guard, does any code
  still assume carry is off (tests aside)? E.g. held layers, the OnInit
  prune (`fxgrind.mq5:189`), telemetry, reconstruction.
- **T-2 Marker lifetime.** A marker exempts a shift from the bound until
  an un-clamped pass clears it or the layer closes. Can a marker outlive
  its reason -- e.g. a later un-clamped pass that fails its modify (so
  `Grind_CarryRecordShift` never runs) leaving a stale exemption over a
  stale shift? Is that state still I6-consistent?
- **T-3 Interruption.** A restart, crash or window close in the MIDDLE of
  a pass: is every layer individually I6-consistent at every point
  (accrual and shift written only after that layer's successful modify)?
- **T-4 Positive carry and the sign guard.** Where accrual would move a
  long exit below entry, the guard blocks and accrual is not committed.
  Night after night the uncommitted accrual grows. Any state that becomes
  inconsistent, or any exit that should move but never does?
- **T-5 Rollover conditions.** The pass runs when spreads are widest and
  some symbols may be close-only. Modify rejections: does every rejection
  path leave no partial state, and does the pass retry sanely within the
  window without request storms?
- **T-6 API budget.** Nine instances, up to two resting exits per side
  (barbell), modified nightly. Estimate requests per night against the
  shared daily budget (soft warn 1,800) and FTMO's hyperactivity limits.
- **T-7 Double counting.** Accrual = ledger + pending(tonight). After
  rollover the ledger includes tonight's charge; the next pass recomputes
  absolutely. Any window where tonight is counted twice (pending AND
  ledger) and an exit is moved by it?
- **T-8 Ejected layers.** With carry on, the carry pass includes ejected
  layers (base = raw + offset). Confirm I6 holds after a clamp on an
  ejected exit (both the marker and the ejected bypass apply).
- **T-9 Held layers on release.** A middle layer accrues for days with no
  order, then becomes deepest. Its exit is released at
  `raw + accrued + offset`, clamped. Confirm the released price and the
  stored shift/marker satisfy I6 immediately and after the next pass.

## RULES

- Cite `file:line` for every claim about the code; otherwise mark it
  INFERRED.
- For each BREAKS / NEEDS-FIX give the SMALLEST fix. No redesign.
- Stay inside enabling carry.

## OUTPUT FORMAT (exact headings)

```
GIVENS CHECK     -- G1..G6: CONFIRMED / WRONG (with line)
T-1 .. T-9       -- verdict, evidence, smallest fix
PREMISE VERDICT  -- is it safe to enable carry? one paragraph
TEST GAPS        -- tests missing, with expected values
```

Line count: 101
