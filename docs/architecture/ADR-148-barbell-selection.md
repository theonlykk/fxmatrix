# ADR-148: Dual-Regime (Barbell) Geometry Selection

## Status

Accepted -- 2026-09-15.

## Context

Width/exit calibration sweeps produce separate risk-adjusted surfaces per
window and per pair. The legacy `select_geometry_from_calibration` pools
across calibration windows and across pairs, returning a single geometry for
the entire fleet.

On AUDNZD that pooling discarded the chop optimum rather than compromising.
`calib_chop_2020q3` (ranging) peaked at (7.0, 5.0) with risk_adj 268.29;
`calib_stress_2022q1` (stress) peaked at (3.0, 5.0) with risk_adj 747.03;
the pooled answer was (3.0, 5.0) -- the stress peak winning on magnitude.

ADR-125 and the sweep caveat block already warn "do NOT pool stress +
ranging into one surface." That caveat is printed on every run while Q3
selection pooled anyway.

Per Gemini memorandum 2026-09-15 (R1/R2/R4/R5), regime-paired arms are
ratified: OPT carries the chop/ranging-optimal geometry, ALT the
stress-optimal, both deployed simultaneously on the same pair.

## Decision

1. **Regime-paired arms.** OPT is selected from ranging-regime calibration
   windows only; ALT from stress-regime calibration windows only. Both arms
   deploy together on each pair. Per Gemini 2026-09-15.

2. **New pure selector.** Add `select_barbell_per_pair` in
   `scripts/run_width_exit_sweep.py`. It does not replace
   `select_geometry_from_calibration`; existing Q3/Q4 behaviour is unchanged.
   Q5 prints barbell selections unconditionally after Q4.

3. **Exit A/B retired (Gemini R2).** Arms may now differ in width AND exit.
   The live OPT/ALT gap measures regime-match, not a controlled geometry
   experiment. This is a deliberate retirement of the prior exit-only A/B.

4. **Holdout evaluates the combined system (Gemini R4).** Holdout windows
   score the OPT+ALT pair after both geometries are locked from disjoint
   calibration subsets. ARCHITECT.md s12 remains intact: two selections from
   two non-overlapping calibration subsets do not contaminate holdout
   evaluation.

## Hard blockers before mixed-width pairs go live (Gemini R3)

- Worst-case exposure for a mixed-width pair must be modelled before any
  such pair is armed live.
- `InpCapLegAThresh` and `InpCapLegBThresh` must be armed via a dedicated
  ADR with a failing ALLOW test per ARCHITECT.md s11. ADR-146 D5 already
  requires arming for CHF pairs.

No mixed-width pair goes live until both items are satisfied.

## Consequences

- Fleet geometry may diverge by regime within a pair; preset authoring must
  map OPT to ranging-optimal and ALT to stress-optimal cells from Q5.
- Q3 pooled geometry remains for backward compatibility and cross-check;
  operators should treat Q5 as authoritative for arm assignment.
- Pairs where ranging and stress optima agree (Q5 "arms AGREE") may still
  deploy identical geometry on both slots.
