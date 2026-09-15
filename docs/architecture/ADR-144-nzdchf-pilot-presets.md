# ADR-144: NZDCHF Pilot Presets (22260701 / 22260702)

## Status

Accepted -- 2026-09-14.

## Context

The live fxgrind fleet runs twelve instances across six currency pairs. NZDCHF
calibration selected width 7 / exit 5 (OPT, score 2687.9 carry-corrected,
2nd of ten cells). Before attaching charts on the VPS, the pair needs preset
files that follow the same conventions as the twelve existing presets in
`ea/presets/`.

Every derived field in those twelve files follows a rule without exception:

- `InpAddPips` = 2 x `InpWidthPips` (matches `GRIND_ADD_WIDTH_MULTIPLE = 2.0`
  in `scripts/grid_sim_v7_real_signal.py`, ADR-125 decision 7).
- `InpStrandedThreshPips` = 2 x `InpWidthPips`.
- `InpDeadbandPips` = 4.0.
- Magic suffix 1 for OPT, 2 for ALT.
- `InpTelemetryInstance` = `GRIND_` plus uppercased filename stem.
- Cap thresholds 0.0 (ARCHITECT.md section 11).
- `TelemetryAPIKey` blank (public repo; operator fills in EA properties).

ADR-143 deliberately excluded 22260701 and 22260702 from
`GRIND_CAP_ALL_MAGICS` and `Grind_MagicLockReleaseAllKnown` until NZDCHF is
ratified live. This ADR adds presets only; it does not extend those lists.

## Decision

Add two preset files:

| Field | OPT (`nzdchf_opt.set`) | ALT (`nzdchf_alt.set`) |
|---|---|---|
| Magic | 22260701 | 22260702 |
| Width / Add | 7.0 / 14.0 | 7.0 / 14.0 |
| Exit | 5.0 | 7.0 |
| Max layers | 8 | 8 |
| Cap legs | NZD / CHF | NZD / CHF |

Add and stranded are derived from width by convention (14.0 = 2 x 7.0), not
chosen independently.

**Why OPT exit 5:** Calibration-selected cell (width 7 / exit 5).

**Why ALT exit 7:** Exits 2, 5 and 7 are the only cells measured in the 3x3
sweep grid for NZDCHF. Fleet ALT exits elsewhere (10, 10, 10, 8) follow no
derivable rule; 10 or 14 would be analogy from other pairs, not data from this
grid. Exit 7 is the only wider measured cell above OPT's exit 5.

**Single-sided model caveat:** `scripts/grid_sim_v7_real_signal.py` is a
single-sided model -- the straddle is placed only inside `if not layers:` and
adds inherit `cur.direction`, so the opposite side is abandoned once a pod
opens (see its docstring: "Single-sided model: cap applies to len(layers) --
the active side's depth only"). The sweep score ranks cells within that
consistent model; it is not a prediction about the EA's two-sided book. OPT
at exit 5 would be the first live arm with its exit inside the straddle
half-width of 7 pips; ALT at exit 7 sits exactly on it.
The live A/B pair is therefore the experiment on that difference -- the
re-validation against real fill data that ARCHITECT.md section 12 requires.

Add `scripts/test_presets.py` with P-series convention tests (all presets) and
N-series NZDCHF pilot tests.

## Consequences

**Presets are inert** until the operator attaches charts on the VPS and loads
them. Outstanding gates, none addressed here:

- The `nzdchf_holdout_2026_09_14` result, still unread.
- NZDCHF margin per lot from the FTMO Specification panel, required to
  promote `max_layers=8` out of RESEARCH ONLY in `scripts/sim_costs.py`.
- `GRIND_CAP_ALL_MAGICS` and `Grind_MagicLockReleaseAllKnown` extended from
  twelve to fourteen (separate change).
- NZDCHF added to Market Watch on the VPS; two charts attached.

No `.mq5` or `.mqh` file is touched. The MQL5 suite (984/985) is unaffected.
