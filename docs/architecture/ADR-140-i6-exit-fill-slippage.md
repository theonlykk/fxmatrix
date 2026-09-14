# ADR-140: I6 Filled-Exit Favourable Slippage Tolerance

## Status

Accepted -- 2026-09-14.

## Context

**Live incident (2026-09-14 15:20Z, GRIND_GBPUSD_OPT):**

The instance halted with `I6_LONG_EXIT`. Layer L04: entry 1.34762,
`exit_pips` 7, formula exit 1.34832. The resting exit order (ticket
541583361) sat at 1.34832; it filled at 1.34826, six points away from
the limit price. The symmetric 2-point I6 check rejected the fill and
blocked CloseBy on a netted pair. The operator closed two positions
manually.

**Third favourable-slippage case on 2026-09-14:**

1. AUDCHF exit filled 2 points better (halted; fixed by ADR-139 epsilon
   at the 2-point boundary, not this defect).
2. GBPUSD L0 entry filled 3 points better.
3. This GBPUSD L04 exit fill (6 points from limit).

**Root cause:**

`exit_target` in `Grind_ReconCheckInvariants` is populated from two
sources in `grind_recon.mqh`:

- Resting exit ORDER price (~608, ~620): exactly the formula price, because
  the EA placed it there.
- Filled exit POSITION price (~642, ~658): the broker fill price, which can
  differ from the limit.

`Grind_ReconExitMatchesEntry` compared both against `entry +/- exit_pips`
with the same symmetric `2.0 * point` tolerance. A limit order never fills
worse than its price -- only at it or better -- so a favourably slipped
exit fill can read as an invariant breach when the fill price lands outside
the 2-point window on the favourable side.

This will recur constantly now that exits are actually filling.

## Decision

Add `exit_is_filled` (default `false`, last parameter) to
`Grind_ReconExitMatchesEntry`. When `true`, apply an asymmetric rule;
when `false`, keep the existing symmetric check unchanged.

**Filled exit (position price):**

- LONG layer exit is a SELL LIMIT. Filling better means a HIGHER price.
  Accept any `exit_target` with `exit_target - expected >= 0` with no upper
  bound. Adverse deviation keeps the existing `2.0 * point + GRIND_PRICE_EPS`
  tolerance via the symmetric fallback.
- SHORT layer exit is a BUY LIMIT. Filling better means a LOWER price.
  Accept any `exit_target` with `exit_target - expected <= 0` with no lower
  bound. Adverse deviation keeps the same 2-point symmetric fallback.

**Resting exit order:** unchanged symmetric check (`exit_is_filled=false`).
The EA placed the order at the formula price; it should be exact.

**Call sites (~231 long, ~250 short):** pass
`long_layers[i].has_exit_position` / `short_layers[i].has_exit_position`
as `exit_is_filled`.

Implementation:

    const double diff = exit_target - expected;
    if (exit_is_filled) {
       if (is_long  && diff >= 0.0) return true;
       if (!is_long && diff <= 0.0) return true;
    }
    return (MathAbs(diff) <= 2.0 * point + GRIND_PRICE_EPS);

## Implementation

| Change | Location | Summary |
|--------|----------|---------|
| 1 | `grind_recon.mqh` | `exit_is_filled` param + asymmetric filled branch |
| 2 | `grind_recon.mqh` | Call sites pass `has_exit_position` |
| 3 | `fxgrind_tests.mq5` | SL1-SL5 regression tests |
| 4 | This document | ADR-140 |

## Verification

- MetaEditor compile: `fxgrind.mq5` -- 0 errors, 0 warnings.
- Unit suite: 932 total assertions (920 baseline + 12 SL).
  - **SL1:** live GBPUSD fill case; filled vs resting diverge on same price.
  - **SL2:** large favourable long fill accepted; resting order rejected.
  - **SL3:** adverse long fill still rejected beyond 2 points; within 2 points
    still accepted.
  - **SL4:** short side mirrored (AUDCHF-shaped boundary + large favour +
    adverse reject/accept).
  - **SL5:** default `exit_is_filled` preserves FB1 unfilled behaviour.

## Consequences

Positive:

- A filled exit can no longer halt an instance for filling on the favourable
  side of the formula price, regardless of magnitude.
- Adverse deviation beyond 2 points still halts.
- Resting exit orders remain under the unchanged symmetric rule.
- CloseBy pairing is unaffected; it keys on tickets, not prices.

Negative / bounded:

- A filled exit more than 2 points adverse still halts (SL3/SL4).
- Resting orders placed at wrong prices still halt (SL1 second assertion).

## References

- ADR-125: fxgrind clean slate (I6 invariant introduced).
- ADR-139: `GRIND_PRICE_EPS` for binary boundary at exactly 2 points. Does
  NOT cover favourable fill slippage beyond the tolerance window.
