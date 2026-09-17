# Roll-at-cap modes — research report

Branch: `research/roll-at-cap` (from `main`)

## Test output (verbatim)

```
test_r1_stall_default_unchanged (test_sim_roll_modes.TestSimRollModes.test_r1_stall_default_unchanged)
R1: cap_mode=stall equals omitting kwarg on cap-reaching paths. ... ok
test_r2_roll_on_add_monotone_fall (test_sim_roll_modes.TestSimRollModes.test_r2_roll_on_add_monotone_fall)
R2: roll_on_add on 10-step fall — 7 forced closes, hand PnL match. ... ok
test_r3_roll_on_fill_depth (test_sim_roll_modes.TestSimRollModes.test_r3_roll_on_fill_depth)
R3: roll_on_fill keeps depth <= 2 after each bar on same path. ... ok
test_r4_no_roll_in_chop (test_sim_roll_modes.TestSimRollModes.test_r4_no_roll_in_chop)
R4: oscillation at cap without add hit — roll_on_add equals stall. ... ok
test_r5_short_forced_close_pricing (test_sim_roll_modes.TestSimRollModes.test_r5_short_forced_close_pricing)
R5: single short forced close uses ask and one exit commission. ... ok
test_r6_p1_guard (test_sim_roll_modes.TestSimRollModes.test_r6_p1_guard)
R6: roll modes require P>=2; stall allows P=1. ... ok
test_r7_new_output_keys (test_sim_roll_modes.TestSimRollModes.test_r7_new_output_keys)
R7: roll metrics present with correct types in all cap modes. ... ok

----------------------------------------------------------------------
Ran 7 tests in 0.120s

OK
```

## Files changed

| File | Change |
|---|---|
| `scripts/test_sim_roll_modes.py` | New R1–R7 tests |
| `scripts/grid_sim_v7_real_signal.py` | `cap_mode` kwarg, forced-close block, new output keys, `stranded_bars` |
| `scripts/run_width_exit_sweep.py` | `--cap-modes`, `--max-layers-grid`, `--preset-geometry`, cell key/schema, mode/P selection |

## Smoke test

**Command (exact):**

```
python scripts/run_width_exit_sweep.py --smoke-test --cap-modes stall,roll_on_add,roll_on_fill --max-layers-grid 4,8 --preset-geometry --pairs GBPUSD --workers 1 --fresh
```

| Parameter | Value |
|---|---|
| `--n-seeds` | 2 (smoke override) |
| `--substeps` | 100 (default) |
| `--workers` | 1 |
| Cells | 12 |
| Wall-clock | 359 s |
| Seconds/cell | 29.9 s (mean) |
| Machine | KKPC (Windows desktop) |

**Preset geometry table read:**

```
pair     slot    width     exit
GBPUSD   OPT         5        7
GBPUSD   ALT         5       10
```

**Summary table (q1_2024_chop / GBPUSD / n=2):**

| width | exit | mode | P | mean_pnl | mean_realised |
|---:|---:|---|---:|---:|---:|
| 5 | 7 | stall | 4 | +543 | (see JSON) |
| 5 | 7 | stall | 8 | +1013 | |
| 5 | 7 | roll_on_add | 4 | +1317 | |
| 5 | 7 | roll_on_add | 8 | +1352 | |
| 5 | 7 | roll_on_fill | 4 | +1310 | |
| 5 | 7 | roll_on_fill | 8 | +1347 | |
| 5 | 10 | stall | 4 | +168 | |
| 5 | 10 | stall | 8 | +390 | |
| 5 | 10 | roll_on_add | 4 | +708 | |
| 5 | 10 | roll_on_add | 8 | +915 | |
| 5 | 10 | roll_on_fill | 4 | +653 | |
| 5 | 10 | roll_on_fill | 8 | +885 | |

Full cell metrics: `temp/width_exit_sweep/n2_g1x2_1win_1pair.json`

## Surface calibration launch command (NOT RUN)

Run on Surface (`C:\fxmatrix`):

```
python scripts/run_width_exit_sweep.py --cap-modes stall,roll_on_add,roll_on_fill --max-layers-grid 4,8 --preset-geometry --windows q1_2024_chop truss_crisis calib_chop_2020q3 calib_stress_2022q1 calib_tail_2015q1 --pairs GBPUSD EURUSD EURGBP AUDCAD AUDCHF CADCHF NZDCAD AUDNZD --workers 6
```

Pairs with presets excluding NZDCHF: GBPUSD, EURUSD, EURGBP, AUDCAD, AUDCHF, CADCHF, NZDCAD, AUDNZD.

---

## SELF-REVIEW

### 1. R1 identical dicts for all keys?

YES for seeds 0, 7, 42 on the adverse cap-reaching path. Keys compared (29 total, stall explicit vs kwarg omitted):

`cap_mode`, `cap_reached`, `carry_modelled`, `carry_usd_total`, `conversion_policy`, `conversion_rate_used`, `drawdown_exceeded_3pct`, `drawdown_exceeded_4pct`, `equity_peak`, `forced_close_loss_pips_mean`, `forced_close_pnl_usd`, `gate_a_daily_loss_breach`, `gate_b_total_loss_breach`, `initial_balance`, `layers_crossing_rollover`, `layers_total`, `max_absolute_drawdown_usd`, `max_daily_equity_drawdown_usd`, `max_layers`, `max_layers_cap`, `mean_rollovers_per_layer`, `n_exits`, `n_forced_closes`, `pnl_realised_usd`, `pnl_total_usd`, `pnl_unrealised_usd`, `single_direction`, `stranded_bars`, `total_trades`

### 2. R2 hand computation shown line by line?

In `test_r2_roll_on_add_monotone_fall`:

```
layers = entries[:3]           # L0, add1, add2 at cap
for bar in 3..9:               # 7 roll events
  closed_entry = layers.pop(0)
  bid_close = closes[bar+1] - half_spread
  gross = price_diff_to_usd((bid_close - closed_entry) * 1, ...)
  hand_forced += gross - exit_comm_leg
  layers.append(entries[bar])    # new add at add_target
```

Assert `forced_close_pnl_usd == hand_forced` and `pnl_realised_usd == hand_forced - 10*entry_comm`.

### 3. Roll block line numbers; exit-before-add order?

- `_force_close_oldest`: lines 253–295
- `roll_on_add` trigger (re-check `len(layers)==P` immediately before close): lines 467–471
- `_maybe_roll_on_fill` after append: lines 297–299, called at 395 (L0) and 490 (add)
- Exit block (LIFO `layers[-1]`): lines 401–455 — still runs before add/roll block (456+)

### 4. Preset geometry table?

```
pair     slot    width     exit
GBPUSD   OPT         5        7
GBPUSD   ALT         5       10
```

(from smoke run stdout above)

### 5. `git diff --stat main...research/roll-at-cap`

```
 prompts/cursor_roll_modes_report.md | 137 ++++++++++++++
 scripts/grid_sim_v7_real_signal.py  |  96 +++++++++-
 scripts/run_width_exit_sweep.py     | 365 ++++++++++++++++++++++++++++++++----
 scripts/test_sim_roll_modes.py      | 249 ++++++++++++++++++++++++
 4 files changed, 808 insertions(+), 39 deletions(-)
```

Only `scripts/` and this report — no `ea/`, presets, pipshed, or deploy changes.
