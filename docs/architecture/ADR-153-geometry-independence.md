# ADR-153: Geometry Independence -- Break add == 2 x width, Tie stranded to width

## Status

Proposed -- 2026-09-20. Gemini approved the direction (both the break and
the `stranded = 2 x width` revision) on 2026-09-20; DeepSeek audit and
Cursor implementation outstanding.

Supersedes the fixed relationship set by ADR-125 (`0bd0877`, 2026-09-06).

## Context

`fxgrind.mq5:119` calls `Grind_ValidateAddWidthRelationship`
(`grind_pure.mqh:40`), which requires `add_pips == GRIND_ADD_WIDTH_MULTIPLE
(2.0) x width_pips` to 1e-8 and returns `INIT_FAILED` otherwise. MT5 then
removes the EA from the chart.

ADR-125 gave two reasons: parity with
`scripts/grid_sim_v7_real_signal.py`, and protection against preset drift.
A third, geometric reason was never written down: with L0 legs at
`mid -/+ width`, `add = 2 x width` puts both legs and every add on one
uniform lattice.

**The rule now blocks the work it was meant to protect.** Geometry cycle 3
sets add spacing per pair from trade volume -- entries per day, measured
from 793 real layers over 10-18 Sep -- and six of eight pairs need an add
that is not twice their width.

**Changing width instead does not work.** Width is the distance from mid at
which L0 quotes, and that distance is the compensation for adverse
selection: quoting at mid -2 rather than mid -5 opens 3 pips worse against
mid with the exit still a fixed distance from entry. Halving width
alongside add would change the ladder spacing AND the price the instance is
willing to open at, so next week's result could not be attributed to
either. Cycle 3's design is one variable per arm.

**Second defect, found while ruling on the first.** `InpStrandedThreshPips`
equals the old `add` (= 2 x width) in every preset today. The cycle-3
proposal initially had it follow the new `add`. In
`Grind_TryRecenterOppositeL0` (`grind_engine.mqh:1482-1524`) the gate is
`|resting - mid| > stranded`, and a freshly placed L0 sits at exactly
`mid -/+ width`. So when `stranded < width` the gate is true at placement
and never goes false; the only remaining brake is the deadband check at
`:1520`, and the flat side's L0 follows mid in `InpDeadbandPips` steps.
Each step is an `OrderModify` against a 2,000/day API cap the fleet already
hit on 2026-09-17.

## Decision

**1. Remove the fixed multiple. Keep a range guard.**

`Grind_ValidateAddWidthRelationship` no longer tests equality. `OnInit`
fails only when the geometry is outside a sane band:

    width_pips  > 0
    add_pips    > 0
    0.5 <= add_pips / width_pips <= 4.0

The band keeps ADR-125's drift protection -- a typo of 40 instead of 4
still fails at startup -- without dictating the geometry.

**2. `InpStrandedThreshPips` follows WIDTH, not add.**

The preset convention becomes `stranded = 2 x width`, which is numerically
what every preset holds today, so the ADR-124 rescue semantics are
unchanged: the gate opens only once the quote has drifted a full extra
`width` beyond where it was placed.

**3. New `OnInit` check, fatal:**

    stranded_thresh_pips > width_pips + deadband_pips

Below that bound the stranded gate is permanently open and the deadband
becomes the de facto control. Failing at startup makes the mistake
impossible to ship.

## Consequences

**The uniform lattice goes.** Under cycle 3, AUDCHF OPT quotes its L0 legs
10 pips apart (2 x width) while adding every 4. The two legs sit on
opposite sides of mid and never interact, and each side's own ladder stays
uniform, so the loss is aesthetic rather than mechanical. Gemini ruled the
lattice has no trading purpose that survives the attribution argument.

**The simulator diverges from the EA** on any arm where `add != 2 x width`.
That is acceptable under ARCHITECT s12, which already requires a geometry
parameter derived from simulated fills to be re-validated against real
fills before it governs live orders. The simulator has known cost-model
defects; the EA should not be constrained to keep it honest.

**Nothing changes for today's fleet.** Every live preset satisfies both the
new range check (ratio exactly 2.0) and the new stranded bound
(2 x width > width + 4 for every width >= 5; EURGBP at width 3 gives
6 > 7 FALSE -- see Open Questions).

## Open questions

**EURGBP fails the new bound at today's width.** width 3, deadband 4:
`2 x 3 = 6` is not greater than `3 + 4 = 7`. Under cycle 3 EURGBP moves to
width 2, which is worse (4 > 6 false). Either the bound is
`stranded >= width + deadband` with EURGBP's deadband reduced, or EURGBP's
stranded is set explicitly above the bound rather than by the 2 x width
convention. **Must be settled before the spec goes to Cursor.**

## Testing

Tests first, and they must fail before the change:

- `add/width` ratio at 0.49, 0.5, 2.0, 4.0, 4.01 -- reject, accept, accept,
  accept, reject.
- `stranded` at `width + deadband` exactly (reject) and one point above
  (accept).
- A cycle-3 geometry (width 5, add 4, exit 10, stranded 10) starts clean.
- Every current preset still passes both checks.
- The ADR-124 recentre is unchanged when `stranded = 2 x width`: same
  modify count as today on a fixture where mid drifts.

## Review

DeepSeek is MANDATORY (ARCHITECT s2: grid geometry, and it changes when
orders are placed). Gemini has ruled on the direction; the audit is for the
mechanism and the bound.
