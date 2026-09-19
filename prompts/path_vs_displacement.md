This message has a line count at the bottom

A typical fleet day offers roughly 400-750 pips of close-to-close path per
symbol (GBPUSD median 742 pips) against net displacement near 20-42 pips --
path exceeds displacement by a median ratio of about 19:1. That is the
oscillation a market-making ladder harvests versus the trend it holds at cap.
**The operator week 2026-09-14 .. 2026-09-18 and the GBPUSD 17-18 Sep
force-close case cannot be measured from the M5 files on this machine:** they
end 2026-09-07 (AUDCAD) to 2026-09-11 (GBPUSD/EURUSD/EURGBP). Sections 3 and
4 below are therefore absent; the operator must copy fresher M5 exports from
the Surface to close that gap.

## Step 0 -- Data located

Source: `data/{SYMBOL}_m5.csv` under the repo root (`D:/fxmatrix/data/`).
Reachable on this desktop. Same files the sweep harness uses via
`run_width_exit_sweep.py` / `load_mt5_csv` (full-history `{pair}_m5.csv`).

| field | value |
|-------|-------|
| format | CSV, MT5 export |
| columns | `datetime`, `OPEN`, `HIGH`, `LOW`, `CLOSE`, `SPREAD` |
| bar interval | M5 (5 minutes) |
| pip conversion | `point = 0.00001`; `pip_size = point * 10 = 0.0001` price units (all 8 symbols are non-JPY 5-digit; no symbol-specific point table needed) |
| date grouping | calendar date of `datetime` column; **no timezone in file** -- grouped as stored (MT5 server time, treated as UTC date label per prompt) |

Fleet symbol coverage:

| symbol | rows | first bar | last bar |
|--------|------|-----------|----------|
| GBPUSD | 861,002 | 2015-01-02 09:00 | **2026-09-11 23:50** |
| EURUSD | 868,866 | 2015-01-02 09:00 | **2026-09-11 23:50** |
| EURGBP | 868,920 | 2015-01-02 09:00 | **2026-09-11 23:50** |
| AUDCAD | 867,913 | 2015-01-02 00:05 | 2026-09-07 23:50 |
| AUDCHF | 867,530 | 2015-01-02 09:00 | 2026-09-07 23:50 |
| CADCHF | 867,677 | 2015-01-02 00:05 | 2026-09-07 23:50 |
| NZDCAD | 867,003 | 2015-01-02 00:05 | 2026-09-11 23:50 |
| AUDNZD | 868,785 | 2015-01-02 09:00 | 2026-09-11 23:50 |

All 8 fleet symbols present. **None extend to 2026-09-14 or later.**

Compute: ~45 s for 8 symbols (pandas groupby; under 5-minute budget).

## 1. Per symbol -- median and quartiles

Daily `path` = sum of `abs(close[i]-close[i-1])` in pips within each date.
`displacement` = `abs(close[last]-close[first])`. `ratio` = path/displacement.
`range` = `max(high)-min(low)`. Sample = trading days with >= 2 bars.

### GBPUSD (n=3035 days)

| stat | path | displacement | ratio | range |
|------|-----:|-------------:|------:|------:|
| q25 | 622.3 | 18.9 | 10.4 | 72.1 |
| median | **742.9** | **41.8** | **17.8** | **95.4** |
| q75 | 918.8 | 74.3 | 37.0 | 128.2 |

### EURUSD (n=3035)

| stat | path | displacement | ratio | range |
|------|-----:|-------------:|------:|------:|
| q25 | 450.4 | 14.3 | 10.5 | 53.4 |
| median | 558.9 | 31.5 | 17.6 | 72.5 |
| q75 | 700.2 | 56.1 | 36.6 | 98.3 |

### EURGBP (n=3035)

| stat | path | displacement | ratio | range |
|------|-----:|-------------:|------:|------:|
| q25 | 311.7 | 9.1 | 11.5 | 34.9 |
| median | 407.5 | 19.5 | 19.5 | 49.7 |
| q75 | 510.0 | 36.8 | 41.1 | 69.1 |

### AUDCAD (n=3031)

| stat | path | displacement | ratio | range |
|------|-----:|-------------:|------:|------:|
| q25 | 439.5 | 12.2 | 11.7 | 48.0 |
| median | 527.0 | 25.6 | 20.4 | 62.3 |
| q75 | 641.1 | 46.7 | 43.1 | 83.2 |

### AUDCHF (n=3031)

| stat | path | displacement | ratio | range |
|------|-----:|-------------:|------:|------:|
| q25 | 369.4 | 10.9 | 11.4 | 40.5 |
| median | 454.3 | 22.7 | 19.4 | 53.7 |
| q75 | 570.5 | 42.0 | 41.9 | 74.9 |

### CADCHF (n=3031)

| stat | path | displacement | ratio | range |
|------|-----:|-------------:|------:|------:|
| q25 | 335.3 | 9.0 | 11.5 | 37.3 |
| median | 414.0 | 20.9 | 19.3 | 50.3 |
| q75 | 522.1 | 38.6 | 43.3 | 69.5 |

### NZDCAD (n=3029)

| stat | path | displacement | ratio | range |
|------|-----:|-------------:|------:|------:|
| q25 | 443.8 | 12.7 | 12.0 | 49.5 |
| median | 528.7 | 27.1 | 19.8 | 64.0 |
| q75 | 659.8 | 45.8 | 40.9 | 85.5 |

### AUDNZD (n=3035)

| stat | path | displacement | ratio | range |
|------|-----:|-------------:|------:|------:|
| q25 | 400.4 | 10.8 | 12.5 | 43.2 |
| median | 485.7 | 22.8 | 20.9 | 57.2 |
| q75 | 603.7 | 39.9 | 44.7 | 76.7 |

## 2. Pooled across 8 symbols (n=24262 symbol-days)

| stat | path | displacement | ratio | range |
|------|-----:|-------------:|------:|------:|
| q25 | 400.8 | 11.7 | 11.4 | 44.7 |
| median | **507.7** | **25.5** | **19.3** | **62.0** |
| q75 | 655.8 | 47.1 | 40.9 | 86.7 |

Path is typically 10-20x net displacement: most intraday motion cancels, but
a capped side holding displacement forgoes the non-cancelled oscillation.

## 3. Week 2026-09-14 .. 2026-09-18 (fleet run week)

**Not computable.** Local M5 files end 2026-09-11 (GBPUSD) or earlier. Zero
bars exist for 2026-09-14 through 2026-09-18. Operator: copy updated
`{SYMBOL}_m5.csv` from the Surface into `data/` and re-run
`scripts/measure_path_vs_displacement.py`.

## 4. GBPUSD 2026-09-17 and 2026-09-18 (force-close case)

**Not computable** from reachable data (same cutoff). Intended metrics:

- daily `path` for 17-Sep and 18-Sep
- split of bar-to-bar path with close in [1.334, 1.339] vs close >= 1.34301
  (anchor of force-closed ladder)

Script implements the split; returns empty when dates absent.

## 5. Crude scalp-capacity estimate (upper bound)

Formula (crude): `median_daily_path / (2 * E)` round trips per day. Ignores
guard saturation, layer cap, spread, and that only one ladder side faces each
move. **Upper bound only.**

| symbol | E OPT / ALT | median path | crude OPT rt/day | crude ALT rt/day |
|--------|-------------|------------:|-----------------:|-----------------:|
| GBPUSD | 7 / 10 | 742 | 53.0 | 37.1 |
| EURUSD | 7 / 10 | 559 | 39.9 | 27.9 |
| EURGBP | 5 / 8 | 408 | 40.8 | 25.5 |
| AUDCAD | 5 / 10 | 527 | 52.7 | 26.3 |
| AUDCHF | 5 / 10 | 454 | 45.4 | 22.7 |
| CADCHF | 5 / 10 | 414 | 41.4 | 20.7 |
| NZDCAD | 5 / 7 | 529 | 52.9 | 37.8 |
| AUDNZD | 5 / 7 | 486 | 48.6 | 34.7 |

Fleet observed **102 scalps on 2026-09-18** (operator report). Per-symbol
upper bound above is ~27-53 round trips/day at median path -- far above 102
for one day across the whole fleet, but the bound is per symbol per side and
assumes perfect harvesting. The gap between 102 actual and the theoretical
ceiling is where guard, cap, spread and side selection live; this table does
not resolve those.

## Caveat (from roll-at-cap-notes)

Path/displacement here is **unconditional** over all days in 2015-2026. A
ladder at cap built after a sustained move is a conditioned case (trend
underway); displacement-heavy days may dominate that population. These
figures describe typical daily oscillation availability, not the conditional
distribution at cap -- which likely shows **lower** path relative to
displacement than the pooled median.

## Cancelled work

The first-passage retrace-probability prompt is dropped. `numba` is not
required. Script: `scripts/measure_path_vs_displacement.py` (pandas/numpy only).

Line count: 180
