# ADR-142: Asymmetric I6 Tolerance on Filled Exits + Quarantinable Adverse Fills

## Status

Accepted -- 2026-09-14.

## Context

**Two opposite halts on GRIND_GBPUSD_OPT, 2026-09-14:**

1. **15:05:40Z** -- a sell limit filled six points LOWER than expected (adverse).
   The instance halted with `I6_LONG_EXIT`.

2. **16:47:06Z** -- ADR-141 payload: layer 2, side L, entry 1.34969,
   exit_target 1.35044, expected 1.35039, **diff_points +5**, exit_is **POSITION**.
   A long layer's exit is a SELL LIMIT at 1.35039; it filled at 1.35044, five
   points HIGHER (better). I6 halted the instance for capturing extra alpha.

A limit order can only fill at its price or better. Halting for a favourable
fill is mathematically and commercially absurd.

**Slippage distribution (358 fills, `--slippage`):**

- Mean +0.1 pips.
- 4 adverse breaches beyond the 0.2-pip tolerance out of 204 slipped fills (~2%).
- Worst adverse -0.8 pips; best favourable +2.3 pips.

**Race with CloseBy:**

Two adverse breaches on other instances did NOT halt, because
`Grind_ProcessCloseByQueues` netted the pair before the invariant check.
Only GBPUSD_OPT halted when reconstruction happened to see the unpaired exit
first. A hard halt that depends on execution order is a race condition
disguised as a safety feature.

**ADR-140 abandoned:**

A prior branch (`fix/i6-exit-fill-slippage`) was structurally identical but
justified on a case that was adverse, not favourable. It would have blinded
the fleet to broker bridge failures. ADR-141's payload is what made the
correct version possible.

## Decision

### Part 1 -- asymmetric tolerance for filled exits

`Grind_ReconExitMatchesEntry` gains `exit_is_filled` (default `false`, last
parameter). When `true`:

- LONG (SELL LIMIT filled higher): accept any `diff >= 0` with no upper bound.
- SHORT (BUY LIMIT filled lower): accept any `diff <= 0` with no lower bound.
- Adverse deviation keeps the existing `2.0 * point + GRIND_PRICE_EPS`
  symmetric fallback.

Call sites pass `has_exit_position`. Resting exit ORDERS remain symmetric
(exact placement expected).

### Part 2 -- adverse fills become quarantinable

When I6 fails on a **filled position** with adverse deviation beyond tolerance,
emit distinct reason codes:

- `I6_LONG_EXIT_FILL_ADVERSE`
- `I6_SHORT_EXIT_FILL_ADVERSE`

Resting-order mismatches keep `I6_LONG_EXIT` / `I6_SHORT_EXIT` and remain a
**hard halt** (genuine bookkeeping fault).

Add both FILL_ADVERSE codes to `Grind_IsQuarantinableReason`. Behaviour:

- CloseBy nets the pair during quarantine -> layer disappears -> check passes
  -> `QUARANTINE_RELEASE`.
- Pair fails to net and quarantine window expires -> escalates to hard halt.

Quarantine window, check count, and escalation logic unchanged. ADR-141 payload
(`exit_is`, signed `diff_points`) flows through unchanged.

## Implementation

| Change | Location | Summary |
|--------|----------|---------|
| 1 | `grind_recon.mqh` | `exit_is_filled` param + asymmetric branch |
| 2 | `grind_recon.mqh` | FILL_ADVERSE reason when filled + adverse |
| 3 | `grind_quarantine.mqh` | Quarantinable FILL_ADVERSE codes |
| 4 | `fxgrind_tests.mq5` | EF1-EF6 regression tests |
| 5 | This document | ADR-142 |

## Verification

- MetaEditor compile: `fxgrind.mq5` -- 0 errors, 0 warnings.
- Unit suite: 956 total assertions (940 baseline + 16 EF).
  - **EF1:** live +5-point favourable fill passes; same price resting fails.
  - **EF2:** large favourable fill passes; resting fails.
  - **EF3:** short mirror favourable/adverse.
  - **EF4:** adverse fill -> FILL_ADVERSE + quarantinable.
  - **EF5:** resting mismatch -> I6_LONG_EXIT + not quarantinable.
  - **EF6:** quarantine enter + release on pass.

## Consequences

Positive:

- An instance no longer stops for a better-than-expected fill.
- An adverse fill gets CloseBy a chance to resolve before paging the operator.
- A stranded off-price execution still escalates to hard halt after quarantine.

Negative / bounded:

- Resting orders placed at wrong prices still halt immediately.
- Adverse tolerance is NOT widened; only favourable direction is unbounded.

## References

- ADR-125: I6 invariant introduced.
- ADR-128: invariant quarantine before halt.
- ADR-139: `GRIND_PRICE_EPS` at the 2-point boundary.
- ADR-141: invariant detail payloads (enabled diagnosis of this defect).
- ADR-140: abandoned (adverse-case justification; number buried).
