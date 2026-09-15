# ADR-147: Fix `_swap_pip_div` -- Stop Inferring Divisor from `point`

## Status

Accepted -- 2026-09-15.

## Context

`PairSpec.point` in this codebase is pip size in price units, not the MT5 tick
size. The comment above the JPY block in `sim_costs.py` states that
explicitly, and `test_t5_jpy_point_size` pins `point == 0.01` for USDJPY.

`_swap_pip_div` previously inferred the MT5 points-per-pip divisor from
`point`:

- Branch one: `point == 0.001` and `pip_size == 0.01` -> 10
- Branch two: `point == 0.00001` -> 10
- Branch three: JPY with `point == pip_size` -> 1
- Default: 10

That inference is unsound because `point` carries no tick-size information.
All five JPY pairs quote to three decimals on FTMO; `PAIR_SWAP_POINTS` is in
MT5 points (FTMO Specification panels, 2026-09-11 snapshot). The divisor must
be 10 for every supported pair.

**Effect:** USDJPY and AUDJPY (which follow the documented `point == pip_size`
convention) received divisor 1, overstating carry tenfold. Every figure
produced through `carry_pips` or `carry_usd` for those two pairs before this
commit is invalid, including AUDJPY's -56 ten-pair calibration score, which
ranked it last of ten and must not be relied on. `fleet_carry_v2_2026_09_13`
in `temp/` is also affected.

CHFJPY, NZDJPY and CADJPY returned the correct divisor only because their
`point` values (0.001) violate the documented convention and happened to trip
branch one.

**Rejected remedy:** Branch `fix/jpy-point-value` changed `point` to 0.001 on
USDJPY and AUDJPY. That broke `test_t5_jpy_point_size` and the
`price_diff_to_usd` path, which depend on `point` being pip size. That branch
must not be merged.

**Residual:** `point` remains inconsistent across six pairs (CHFJPY, NZDJPY,
CADJPY at 0.001 vs 0.01; NZDCAD, NZDCHF, AUDNZD at 0.00001 vs 0.0001).
Harmless once the divisor no longer reads `point`; `point` is then consumed
only by `grid_sim_v7_real_signal.py` (retired signal path). Normalising it is
deferred cleanup.

`TRIPLE_SWAP_WEEKDAY` is being settled empirically on 2026-09-16 per the
note at `sim_costs.py` line 580; this change does not touch it.

## Decision

Replace `_swap_pip_div` with a constant return of 10 and a docstring
explaining why the divisor cannot be inferred from `PairSpec.point`.

Do not change any `PairSpec`, `PAIR_SWAP_POINTS`, or carry date logic.

## Consequences

Carry-corrected sweep scores for USDJPY and AUDJPY require re-computation.
Operators must re-sweep those pairs before relying on calibration rankings.
CHFJPY, NZDJPY and CADJPY carry math was already correct under the old
accidental branch-one path and is unchanged in outcome.
