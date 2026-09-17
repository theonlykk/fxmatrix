This message has a line count at the bottom

# CURSOR SPEC -- SIMULATOR: ROLL-AT-CAP MODES (RESEARCH ONLY)

## TASK

Add a cap-behaviour mode to the grid simulator so the sweep can compare
today's stall-at-cap against two rolling variants, with the layer cap P as a
sweep dimension. Research code only. Nothing in `ea/`, presets, pipshed or
the VPS changes.

Staff Architect cleared this simulator expansion 2026-09-17 before any ADR:
three modes, spread and commission on forced closes, calibration/holdout.

## CONTEXT (verified against fxmatrix `1ac8c1a`)

- `scripts/grid_sim_v7_real_signal.py` `simulate_one_path` (~111): single-
  sided inventory (first fill sets direction), exits are LIFO (only
  `layers[-1]` can exit, ~337-384), adds from `compute_add_target(layers)`
  = `layers[-1].entry_price - direction * add_pips` (~59). At cap, an add hit
  only sets `cap_reached = True` (~400-401): that is STALL.
- Exit pricing: `effective_exit = exit_target + direction * half_spread`;
  realised = gross via `sim_costs.price_diff_to_usd` minus `exit_comm_leg`
  plus `sim_costs.carry_usd(symbol, direction, open_dt, close_dt, ...)`.
  Entry commission debited at add (~412). MTM marks longs at mid - half
  spread, shorts at mid + half spread (~220).
- `scripts/run_width_exit_sweep.py`: jobs built in `run_sweep` (~650-735)
  with `max_layers = sim_costs.get_pair_max_layers(pair)`; worker calls
  `sim7.simulate_one_path(..., max_layers=payload["max_layers"])` (~314);
  `make_cell_key(wkey, pair, width, exit)` (~143); checkpoint schema
  `CELL_SCHEMA_FIELDS` (~482); pre-registered `WINDOW_ROLES` (~113).
- `sim_costs.PAIR_SPECS` still has `max_layers=12` for GBPUSD/EURUSD; live
  presets are all 8 since `affc323`. This spec makes P explicit per job.
- Existing tests: `scripts/test_sim_layer_cap.py` (K1-K7),
  `scripts/test_grid_add_mechanics.py`, `scripts/test_sim_costs.py`.

## DEFINITIONS

`cap_mode` (new `simulate_one_path` kwarg, default `"stall"`):

- **stall** -- current behaviour, byte-for-byte.
- **roll_on_add** -- when `len(layers) == P` and the add level is hit
  (the existing `hit` test), FORCE-CLOSE the oldest layer `layers[0]`, then
  place the add exactly as today. This is "stranded by one add step".
- **roll_on_fill** -- after any append (L0 or add) that makes
  `len(layers) == P`, FORCE-CLOSE `layers[0]` immediately, so a slot is
  always free. Requires P >= 2; P < 2 with a roll mode raises ValueError.

**Forced close** of layer X at sub-step price `p`:
- close price: long `p - half_spread`, short `p + half_spread` (crosses the
  spread; no limit, no clamp);
- realised += `price_diff_to_usd((close - X.entry) * X.direction)`
  `- exit_comm_leg + carry_usd(X open time -> this bar close time)`;
- pop `layers[0]` together with the SAME index of `layer_is_l0` and
  `layer_entry_bars` (these lists are parallel; today they are popped at
  the end; roll pops at index 0);
- never counted as an exit/scalp (`n_exits`, `total_trades` unchanged).

## OBJECTIVE

### Commit 1 -- tests (must fail against current code, except R1)

New `scripts/test_sim_roll_modes.py`, same import pattern as
`test_sim_layer_cap.py`:

- **R1 regression**: for 3 fixed seeds on a synthetic path that reaches cap,
  `cap_mode="stall"` output dict equals the output with the kwarg omitted,
  every key, exactly. (Passes before and after; proves default unchanged.)
- **R2 roll_on_add, monotone fall**: long-only, P=3, a path falling 10 add
  steps with no retrace. Assert forced closes = 7, `max_layers` peak 3,
  final open layers 3, and realised equals the hand-computed sum of seven
  forced closes (entries, bid close prices, commissions) within 1e-9.
  Carry off (`times=None`).
- **R3 roll_on_fill depth**: same path, P=3: after every step the open depth
  is <= 2; forced closes counted.
- **R4 no roll in chop**: path oscillating inside the ladder never hitting
  the add level at cap: roll_on_add forced closes = 0 and result equals
  stall exactly.
- **R5 pricing**: a single forced close on a short uses ask (mid + half
  spread) and debits one exit commission leg.
- **R6 guard**: roll mode with P=1 raises ValueError; stall with P=1 does not.
- **R7 new outputs present** in all three modes with correct types.

### Commit 2 -- simulator

- `cap_mode` kwarg as defined; validate value.
- New output keys: `cap_mode`, `n_forced_closes`, `forced_close_pnl_usd`
  (sum incl. commission and carry), `forced_close_loss_pips_mean` (mean of
  `(close - entry) * direction` in pips, 0.0 if none),
  `stranded_bars` = bars ending with `len(layers) == P` AND end price beyond
  the next add level (long: `end_price < add_target`, short: `>`).
  `stranded_bars` is computed in ALL modes (it is the stall metric).
- No change to exits, L0 logic, add pricing, carry maths or gates.

### Commit 3 -- sweep runner

- CLI: `--cap-modes` (comma, default `stall`), `--max-layers-grid` (comma
  ints, default: pair cap from `sim_costs`), `--preset-geometry` (flag).
- `--preset-geometry`: instead of the width/exit grid, read
  `InpWidthPips` / `InpExitPips` from `ea/presets/<pair>_opt.set` and
  `_alt.set` and run exactly those (width, exit) cells per pair. Print the
  table read before simulating. Pairs without presets are skipped with a
  printed note.
- Cell key gains mode and P: `f"{wkey}|{pair}|{width:g}|{exit:g}|{mode}|P{P}"`.
  Add aggregate fields to `CELL_SCHEMA_FIELDS`: `mean_forced_closes`,
  `mean_forced_close_pnl_usd`, `mean_forced_close_loss_pips`,
  `mean_stranded_hours` (bars x 5 / 60), `exits_per_forced_close`
  (mean n_exits / mean forced closes; null when 0).
- Old checkpoints are incompatible: refuse to resume a checkpoint whose
  schema lacks the new fields (existing check ~587 must fire). Do not
  migrate old files.
- Selection output: per (pair, width, exit), rank (mode, P) on CALIBRATION
  windows only using the existing gate-then-optimise rules; then print
  HOLDOUT results for the selected (mode, P) alongside stall at the same P.
  Never select on holdout.

### Commit 4 -- report `prompts/cursor_roll_modes_report.md`

Test output (verbatim), files changed, and a `--smoke-test` run with
`--cap-modes stall,roll_on_add,roll_on_fill --max-layers-grid 4,8
--preset-geometry --pairs GBPUSD`, pasting the summary table. Report the
exact command, `--n-seeds`, `--substeps`, `--workers`, number of cells, total
wall-clock seconds and seconds per cell, and the machine it ran on.
Also print the Surface launch command for the calibration pass
(`--cap-modes stall,roll_on_add,roll_on_fill --max-layers-grid 4,8
--preset-geometry`, calibration windows only, pairs with presets excluding
NZDCHF) -- print it, do not run it.

## NEGATIVE SPACE

- Do NOT touch `ea/`, `ea/presets/`, pipshed, deploy scripts, or any ADR.
- Do NOT change `sim_costs.PAIR_SPECS` caps, spreads, commission or carry.
- Do NOT change stall-mode behaviour in any way (R1 is the proof).
- Do NOT run the full sweep, or any run beyond the single smoke test in
  Commit 4, on this desktop. Full and calibration runs happen on the
  Surface (`C:\fxmatrix`), launched by the operator.
- Do NOT interpret results or recommend a mode.
- No merge to main; branch `research/roll-at-cap` from `main`.

## FAILURE MODES

- Parallel lists (`layers`, `layer_is_l0`, `layer_entry_bars`) popped at
  different indices -> silent carry/hold-time corruption. Assert lengths
  equal after every forced close.
- Forced close in the same sub-step as an exit of `layers[-1]`: exits are
  processed first today (~337); keep that order, then the add/roll block.
- A roll while depth changed within the step: re-check `len(layers) == P`
  immediately before closing.
- `stranded_bars` using the add target of an empty ladder: guard `layers`.
- Resume of an old checkpoint silently mixing schemas.

## SELF-REVIEW (answer each in the report)

1. R1 identical dicts for all keys? Paste the key list compared.
2. R2 hand computation shown line by line?
3. Which line numbers now contain the roll block, and is exit-before-add
   order preserved?
4. Paste the preset geometry table the runner read.
5. `git diff --stat main...research/roll-at-cap` (three dots): only
   `scripts/` and the report?

Line count: 162
