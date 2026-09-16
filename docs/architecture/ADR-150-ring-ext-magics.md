# ADR-150: Ring Extension Fleet Magic Tables (NZDCAD, AUDNZD)

## Status

Accepted -- 2026-09-16.

## Context

Four new fxgrind presets merged at `e894618` for NZDCAD and AUDNZD ring
extension pairs. Until the EA's hardcoded fleet tables carry sixteen
magics, those instances are invisible to the cross-instance exposure cap
and to boot-time magic-lock release.

NZDCHF presets (22260701, 22260702) exist on main but are deliberately
excluded per ADR-146 pending re-calibration. Adding them would re-admit a
rejected geometry by the back door.

## Decision

Extend three index-aligned tables from twelve to sixteen entries:

| magic | preset | legs | width/exit |
|---|---|---|---|
| 22260801 | nzdcad_opt.set | NZD / CAD | 5 / 5 |
| 22260802 | nzdcad_alt.set | NZD / CAD | 5 / 7 |
| 22260901 | audnzd_opt.set | AUD / NZD | 7 / 5 |
| 22260902 | audnzd_alt.set | AUD / NZD | 7 / 7 |

Tables updated: `GRIND_CAP_ALL_MAGICS`, `GRIND_CAP_MAGIC_LEG_A`,
`GRIND_CAP_MAGIC_LEG_B` in `ea/grind_cap.mqh`, and the local array in
`Grind_MagicLockReleaseAllKnown` in `ea/grind_magic_lock.mqh`.

Leg values derived from preset `InpCapLegA` / `InpCapLegB` fields. Nothing
in code verifies the string values -- only array lengths are tested.

### Geometry basis

NZDCAD 5/5 and 5/7; AUDNZD 7/5 and 7/7. Selected from
`ring_ext_nzdcad_2026_09_15` and `ring_ext_audnzd_2026_09_15` at n=50,
substeps=100. Width chosen on mean realised across both calibration
windows; exits 5 and 7 because exit 10 scored materially worse on both
pairs.

### Calibration-only selection

Neither pair has holdout slices -- only `calib_chop_2020q3` and
`calib_stress_2022q1` exist. This is the same footing the AUD/CAD/CHF ring
went live on, which ADR-146 records as the gap that let NZDCHF through
unmeasured. It is a deliberate, recorded exception on a demo account, not
an oversight. Cutting holdout slices for both pairs is the remedy and is
outstanding.

### Same-width arms, not barbell

These pairs deploy same-width OPT/ALT arms, not the ADR-148 barbell
(regime-paired) geometry. Mixed-width pairs remain blocked by Gemini R3
until the cap is armed and mixed-width exposure is modelled. Barbell
selections are recorded for later deployment:

- NZDCAD: chop 5/5, stress 7/5
- AUDNZD: chop 7/5, stress 3/5

### Topology change

The fleet moves from six currencies at four instances each to AUD 6, CAD 6,
and CHF/EUR/GBP/NZD/USD at 4. A 1.5x spread where there was none. Per
ADR-149 section 6 the cap threshold is derivable from structure only on a
uniform fleet; this addition makes a per-currency threshold judgement
necessary rather than structural.

### Test cover

`CL4_LegMembershipTableMatchesMagics` catches length drift between the
three tables. `RX2_NewMagicLegsCorrect` checks leg membership via
`Grind_CapMagicCarriesLeg` for the four new magics. Neither test catches
wrong currency strings; values were checked against preset files by hand.

Thresholds remain at 0.0 in all presets. Arming is a separate change.

## Consequences

- NZDCAD and AUDNZD instances participate in cap summation and magic-lock
  release on boot.
- Operators must update all three tables together when adding fleet pairs.
- CM1 and CM2 fleet-size expectations move to sixteen; CM2 CHF sum stays
  0.42 because new magics append after CHF carriers at indices 8-11.
