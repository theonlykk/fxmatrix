# ADR-139: I6 Exit-Target Float Boundary Epsilon

## Status

Accepted -- 2026-09-13.

## Context

**Live incident (2026-09-14 ~00:53Z, GRIND_AUDCHF_OPT):**

During reconstruction after a fleet restart, the instance halted with
`I6_SHORT_EXIT`. Layer S/L01: entry 0.58531, `exit_pips` 5, expected exit
0.58481. The filled exit position sat at 0.58479 -- exactly 2 points below
expected, within the designed I6 tolerance.

**Root cause:**

`Grind_ReconExitMatchesEntry` compared:

    MathAbs(exit_target - expected) <= 2.0 * point

For this case, `MathAbs(0.58481 - 0.58479)` evaluates to
`2.0000000000020002e-05` against a tolerance of `2e-05`. The comparison fails
by `2e-17`: binary representation error, not slippage.

Exit prices land on exact pip boundaries constantly (`entry +/- exit_pips *
pip_size`), and broker fills are exact multiples of point. So
`|exit - expected|` lands exactly on `2 * point` regularly; roughly half of
those comparisons lose to representation error depending on subtraction
direction.

**Cost:**

The halt blocked CloseBy on two netted layers. The operator closed four
positions manually to clear the book.

This defect was latent from ADR-125 and only surfaced when reconstruction
encountered an exit sitting exactly on the 2-point boundary.

## Decision

Add `GRIND_PRICE_EPS` (`1e-9`) in `grind_pure.mqh` and apply it to the I6
boundary comparison only:

    return (MathAbs(exit_target - expected) <= 2.0 * point + GRIND_PRICE_EPS);

**Magnitude justification:** `1e-9` is far below one point on any symbol we
trade (smallest point = `1e-5`), so it cannot mask a real breach at 3 points
or beyond. It absorbs only sub-point representation noise at the tolerance
edge.

**Unchanged:**

- The `2.0 * point` tolerance itself.
- The `shift` parameter (ADR-135b carry exit adjustment).
- Both call sites in `Grind_ReconCheckBookInvariants`.

**Neighbouring comparisons (Gemini review -- SAFE, do not change):**

- `Grind_PriceWithinDeadband` uses strict `<`; boundary evaluates false and
  the EA re-quotes at exactly 4 pips. Fails safe.
- `Grind_Adr013ClampBuy` / `ClampSell` compare against `point * 0.1` with
  strict `>`; boundary reads as "price did not move". Fails safe.

## Implementation

| Change | Location | Summary |
|--------|----------|---------|
| 1 | `grind_pure.mqh` | `#define GRIND_PRICE_EPS 1e-9` |
| 2 | `grind_recon.mqh` | Add epsilon to I6 `<=` comparison |
| 3 | `fxgrind_tests.mq5` | FB1-FB4 boundary regression tests |

## Verification

- MetaEditor compile: `fxgrind.mq5` -- 0 errors, 0 warnings.
- Unit suite: 920/920 (910 baseline + FB1-FB4).
  - **FB1:** live AUDCHF case (0.58479) and symmetric +2-point case accept.
  - **FB2:** 3-point breaches still reject.
  - **FB3:** long-side boundary shape matches short.
  - **FB4:** shifted expected (ADR-135b) boundary accept/reject.

## Consequences

Positive:

- I6 now accepts a difference of exactly 2 points as intended; reconstruction
  and per-tick invariant checks no longer halt on representation noise.
- `GRIND_PRICE_EPS` is available for future boundary comparisons if needed.

Negative / bounded:

- The acceptance window is not widened beyond 2 points plus negligible float
  noise; 3-point breaches still fail (FB2/FB3/FB4).

## References

- ADR-125: fxgrind clean slate (I6 invariant introduced).
- ADR-135b: carry exit `shift` parameter on `Grind_ReconExitMatchesEntry`.
