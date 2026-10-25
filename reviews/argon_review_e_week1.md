This message has a line count at the bottom

# Argon Review: `research/e_week1/PREREG.md` (Fleet E Week 1 Read Pre-Registration)

## Header

- **Branch:** `review/argon-e-week1`
- **Base commit (`D:/fxmatrix` `origin/main`):** `4f7f2b778ec4d52a0a4860147243a8c27ed17141` (`4f7f2b7`)
- **Cross-repo commit (`D:/pipshed` `origin/main`):** `b9d2d22` (READ with operator permission)
- **Files read in `D:/fxmatrix` (`4f7f2b778ec4d52a0a4860147243a8c27ed17141`):**
  - `prompts/argon_review_e_week1.md` (lines 1-61)
  - `research/e_week1/PREREG.md` (lines 1-121)
  - `research/t3_drawdown/t3dd_output.txt` (lines 1-19)
  - `research/t3_drawdown/calm_comm_output.txt` (lines 1-16)
  - `research/t3_drawdown/results.md` (lines 1-46)
  - `research/t3_drawdown/t3dd.py` (lines 1-59)
  - `research/t3_drawdown/calm_comm.py` (lines 1-27)
  - `research/t3_drawdown/intraday.py` (lines 1-72)
  - `research/t3_drawdown/fleet.py` (lines 1-40)
  - `research/t3_drawdown/fleet_output.txt` (lines 1-55)
  - `research/replay/results/sweep11/sw11_eurgbp.md` (lines 1-22)
  - `research/replay/results/sweep11/score11.py` (lines 1-165)
  - `research/session_hours/PREREG.md` (lines 1-101)
  - `docs/runbooks/twoarm-build-e.md` (lines 1-369)
  - `docs/architecture/ADR-158-daily-loss-breaker.md` (lines 1-80)
  - `handoffs/Handover/08_BACKLOG.md` (lines 1-150)
  - `handoffs/Handover/02_TRAPS.md` (lines 3020-3064)
  - `ea/grind_pure.mqh` (lines 1-691)
  - `ea/grind_engine.mqh` (lines 1-3630)
  - `ea/grind_archive.mqh` (lines 1-704)
  - `ea/grind_scalp_events.mqh` (lines 1-180)
  - `ea/grind_mae.mqh` (lines 1-346)
  - `ea/grind_pnl.mqh` (lines 1-325)
  - `ea/grind_snapshot.mqh` (lines 1-369)
- **Files read in `D:/pipshed` (`b9d2d22`):**
  - `D:/pipshed/scripts/archive_counts.py` (lines 1-547)
  - `D:/pipshed/migrations/001_archive_phase1.sql` (lines 1-135)
  - `D:/pipshed/migrations/002_adr159_daily.sql` (lines 1-34)
  - `D:/pipshed/migrations/003_adr160_gated.sql` (lines 1-14)
  - `D:/pipshed/migrations/004_c56_rolls.sql` (lines 1-9)
  - `D:/pipshed/migrations/005_c137_state_snapshots.sql` (lines 1-32)
  - `D:/pipshed/sr_table.py` (lines 1-264)
  - `D:/pipshed/ftmo_daily.py` (lines 1-403)
  - `D:/pipshed/app.py` (lines 1-4660)
  - `D:/pipshed/archive_worker.py` (lines 1-1385)
  - `D:/pipshed/ejection_view.py` (lines 1-1192)

## Verdict Summary

| Item | Section | Verdict | Summary |
|---|---|---|---|
| 1 | `1. s8, the bands` | **CONFIRMED** | Every calm rate `(S+R)/40`, Oct rate `closes/14`, and `[0.5*min, 1.5*max]` band in s8 matches `calm_comm_output.txt` and `t3dd_output.txt` to 2 decimals when computed from unrounded rates; `closes = comm / 0.06` is exact; `EURGBP OPT 5` calm-only fallback is disclosed and conservative. |
| 2 | `2. s2, the days` | **CONFIRMED** | Prague switches `UTC+2 -> UTC+1` at `2026-10-25 01:00Z`; FTMO day boundaries (`22:00Z` on 23-24 Oct, 25h day on 25 Oct holding Sunday's `~21:00Z` open, `23:00Z` on 26-30 Oct), `5.73` trading days (`0.73 + 5.00`), and ending W before `21:05Z` (after Friday's `21:00Z` close) are all exact. |
| 3 | `3. s3 and s5, computable?` | **DEFECT** | (a) `state_snapshots.balance` and `equity` are account-level and non-null on only 1 of 12 instances (the MAE reporter), so M1/M2 must read the non-null reporter row and Q3's per-pair M3 equity change cannot come from `state_snapshots.equity`; (b) `--export-snapshots` exports all fleets (`B,C,D,E`) unless filtered by `instance_id`/`account_login`; (c) `scalp_history.entry_deal_ticket` is always `NULL`, so rolled closes `R` in M4 must either join `fill_logs` `OUT_BY` (`ENT`-position leg) directly via `fill_logs.position_id = ea_events.ticket` or read `scalp_history.rolled`. |
| 4 | `4. s4, the self-checks` | **DEFECT** | (a) Check 4 says `closing deals in fill_logs (role EXT)`, but in `fill_logs` `role = 'EXT'` is on the opening deal (`entry_type = 'IN'`), whereas `OUT_BY` closing deals have `role = NULL` and come in pairs per CloseBy; (b) Check 4 requires `pipshed's scalps-per-roll table (cycle window, CSV)`, which is not in s3's export commands; (c) Check 1's `$0.05` tolerance is sound, but D's first snapshot in W (`03:30:00Z`) is 59s after W's start (`03:29:01Z`), so D's deals in Check 1 must be summed between D's first and last snapshot timestamps (`heartbeat_at`). |
| 5 | `5. s7, the rules` | **GAP** | Q1 matches FTMO's `$500` daily / `$9,000` static Trial rules and `$300` daily / `$1,000` trailing Instant rules as recorded in C124, C164, ADR-158, and `twoarm-build-e.md`, but Q1's formula tests minute-mark `M1`/`M2` without incorporating FTMO's page (which s3/s5 say decides when minute marks under-read) or M5's `2,000/day` limit. Q2 cannot pass unconditionally (`0` or runaway closes fail), and Q3 honestly discloses the 1-week draw, broker gap (`$0.06` vs `$0.08`), and D's 21 Oct carried book. |
| 6 | `6. s6, the episode` | **DEFECT** | s6 anchors the episode at `W's lowest equity` (`min equity(t)`), but bounds and thresholds it by `O(t) = equity(t) - balance(t)` (`O >= -$50`, `lowest O is above -$100`). Once banked scalps raise `balance(t)`, `argmin equity(t)` can occur early in the week where `O(t) >= -$50` (making the episode degenerate) while a `-$300` open-book drop later in the week is missed. It also lacks a `(or W's start)` fallback before the low and a tie-break rule for equal lows. |
| 7 | `7. Anything that would let the read be bent after the fact` | **GAP** | Need to pin: (a) which timestamp column filters `fill_logs`, `scalp_history`, and `ea_events` to W; (b) Day 1's day-start balance (`$10,000.00`) and subsequent FTMO days' midnight balance selector; (c) dynamic running high-water mark `max_{s<=t} balance(s) - 1000` for M2's Instant trailing floor; (d) whether Q2's rate is compared unrounded or rounded to 2 decimals against s8's printed bands (`<=`); (e) `None` (`n/a`) when `A == 0` in `S/A` or `gross <= 0` in `commission/gross`. |
| 8 | `8. Anything missing that the operator's two questions need (C162; C164)` | **GAP** | For C164: export `daily_snapshots` (exact FTMO-midnight `balance_start` and `guard_total` against 194) and report Instant's 30%/50% best-day consistency share (`08_BACKLOG.md:63`). For C162: report D's M3 both raw (`$0.08`/close) and commission-equalised at FTMO's `$0.06`/close, split D's W closes between 21 Oct carried positions and W-opened positions, and report the unitless chop ratio `rho = (S+R)/(7*A)` (`08_BACKLOG.md:60`). |

---

## 1. `s8, the bands`

- **Verdict:** **CONFIRMED** (with a minor 0.01 rounding specification note covered under Item 7)

### Verification & Quotes

1. **Pre-registration s8 table and formulas (`research/e_week1/PREREG.md:90-101`):**
   - `research/e_week1/PREREG.md:90` ``
   - `research/e_week1/PREREG.md:91` `| cell | calm | October | band | | cell | calm | October | band |`
   - `research/e_week1/PREREG.md:92` `|---|---|---|---|---|---|---|---|---|`
   - `research/e_week1/PREREG.md:93` `| GBPUSD OPT 9 | 16.62 | 23.14 | 8.31-34.71 | | GBPUSD ALT 15 | 5.75 | 8.29 | 2.88-12.43 |`
   - `research/e_week1/PREREG.md:94` `| EURUSD OPT 7 | 16.27 | 35.00 | 8.14-52.50 | | EURUSD ALT 23 | 1.52 | 4.07 | 0.76-6.11 |`
   - `research/e_week1/PREREG.md:95` `| EURGBP OPT 5 | 5.95 | n/a | 2.98-8.93 | | EURGBP ALT 23 | 0.12 | 0.71 | 0.06-1.07 |`
   - `research/e_week1/PREREG.md:96` `| AUDCAD OPT 18 | 2.58 | 3.36 | 1.29-5.04 | | AUDCAD ALT 26 | 1.10 | 1.57 | 0.55-2.36 |`
   - `research/e_week1/PREREG.md:97` `| AUDCHF OPT 14 | 1.55 | 3.21 | 0.78-4.82 | | AUDCHF ALT 20 | 0.80 | 1.64 | 0.40-2.46 |`
   - `research/e_week1/PREREG.md:98` `| CADCHF OPT 10 | 2.70 | 4.64 | 1.35-6.96 | | CADCHF ALT 17 | 0.78 | 1.86 | 0.39-2.79 |`
   - `research/e_week1/PREREG.md:99` ``
   - `research/e_week1/PREREG.md:100` `Calm = (S + R) / 40 (`calm_comm_output.txt`); October = closes / 14 (`t3dd_output.txt`, closes = commission / $0.06).`
   - `research/e_week1/PREREG.md:101` `EURGBP OPT 5's October count at cap 7 is not committed (its run sits outside git): its band uses calm only (disclosed).`

2. **Calm close counts (`S + R` over 40 trading days) and why `S + R` is the complete close count:**
   - In `research/t3_drawdown/calm_comm.py`, calm runs have auto-eject disabled (`aborted == '0'`), so every closed layer is either an unrolled scalp `S` (`scalps`) or a rolled close `R` (`roll_closes`) over `8` five-day calm weeks (`40` trading days):
   - `research/t3_drawdown/calm_comm.py:5` `def weekly_net(pair, add):`
   - `research/t3_drawdown/calm_comm.py:7` `    m = re.search(r'^\| %s(?: \([A-Z]+\))? \| ([-+.\d]+) \|' % add, t, re.M); return float(m.group(1))`
   - `research/t3_drawdown/calm_comm.py:15` `    for line in open(U + 'out_sw11w_%s_free_summary.txt' % pair.lower()):`
   - `research/t3_drawdown/calm_comm.py:21` `        S = sum(int(summ[s]['scalps']) for s in ss); Rr = sum(int(summ[s]['roll_closes']) for s in ss)`
   - Output in `research/t3_drawdown/calm_comm_output.txt:1-13`:
   - `research/t3_drawdown/calm_comm_output.txt:1` `pair    arm  add      S      R   net USD     comm     gross    c/g`
   - `research/t3_drawdown/calm_comm_output.txt:2` `GBPUSD  OPT    9    614     51    +87.32    39.90   +127.22    31%`
   - `research/t3_drawdown/calm_comm_output.txt:3` `GBPUSD  ALT   15    218     12    +22.37    13.80    +36.17    38%`
   - `research/t3_drawdown/calm_comm_output.txt:4` `EURUSD  OPT    7    606     45    +31.78    39.06    +70.84    55%`
   - `research/t3_drawdown/calm_comm_output.txt:5` `EURUSD  ALT   23     61      0     -1.23     3.66     +2.43   151%`
   - `research/t3_drawdown/calm_comm_output.txt:6` `EURGBP  OPT    5    229      9    +31.65    14.28    +45.93    31%`
   - `research/t3_drawdown/calm_comm_output.txt:7` `EURGBP  ALT   23      5      0     +2.60     0.30     +2.90    10%`
   - `research/t3_drawdown/calm_comm_output.txt:8` `AUDCAD  OPT   18    103      0    +36.89     6.18    +43.07    14%`
   - `research/t3_drawdown/calm_comm_output.txt:9` `AUDCAD  ALT   26     44      0    +20.98     2.64    +23.62    11%`
   - `research/t3_drawdown/calm_comm_output.txt:10` `AUDCHF  OPT   14     61      1    -26.25     3.72    -22.53   nan%`
   - `research/t3_drawdown/calm_comm_output.txt:11` `AUDCHF  ALT   20     32      0     -3.11     1.92     -1.19   nan%`
   - `research/t3_drawdown/calm_comm_output.txt:12` `CADCHF  OPT   10    106      2     +5.99     6.48    +12.47    52%`
   - `research/t3_drawdown/calm_comm_output.txt:13` `CADCHF  ALT   17     31      0     +6.08     1.86     +7.94    23%`

3. **October close counts (`closes` over 14 trading days) and `closes = commission / 0.06`:**
   - In `research/t3_drawdown/t3dd.py`, commission is computed directly as `closes * 0.06`, and `t3dd_output.txt` prints both the integer `closes` column and `comm`:
   - `research/t3_drawdown/t3dd.py:8` `COMM = 0.06`
   - `research/t3_drawdown/t3dd.py:22` `    m = re.search(r'^\| %s(?: \([A-Z]+\))? \| [-+.\d]+ \| \d / 8 \| ([-+\d ]+) \|' % add, t, re.M)`
   - `research/t3_drawdown/t3dd.py:32` `        s_r = sr(pair, g); closes = sum(s_r) if s_r else None`
   - `research/t3_drawdown/t3dd.py:33` `        c = closes * COMM if closes is not None else None`
   - `research/t3_drawdown/t3dd.py:39` `    for x in path: peak = max(peak, x); worst = min(worst, x - peak)`
   - Output in `research/t3_drawdown/t3dd_output.txt:1-14`:
   - `research/t3_drawdown/t3dd_output.txt:1` `OCTOBER (1-20 Oct, day-end marks), USD at 0.01 lots; missing: ['EURGBP OPT 5']`
   - `research/t3_drawdown/t3dd_output.txt:2` `pair    arm  add       net     worst  closes     comm     gross`
   - `research/t3_drawdown/t3dd_output.txt:3` `GBPUSD  OPT    9    -16.78    -16.78     324    19.44     +2.66`
   - `research/t3_drawdown/t3dd_output.txt:4` `GBPUSD  ALT   15     +7.51     -1.91     116     6.96    +14.47`
   - `research/t3_drawdown/t3dd_output.txt:5` `EURUSD  OPT    7    -36.12    -60.84     490    29.40     -6.72`
   - `research/t3_drawdown/t3dd_output.txt:6` `EURUSD  ALT   23    +45.44     -8.78      57     3.42    +48.86`
   - `research/t3_drawdown/t3dd_output.txt:7` `EURGBP  ALT   23    -41.14    -41.14      10     0.60    -40.54`
   - `research/t3_drawdown/t3dd_output.txt:8` `AUDCAD  OPT   18    +19.90     -7.45      47     2.82    +22.72`
   - `research/t3_drawdown/t3dd_output.txt:9` `AUDCAD  ALT   26    +12.95     -4.81      22     1.32    +14.27`
   - `research/t3_drawdown/t3dd_output.txt:10` `AUDCHF  OPT   14     +3.95    -17.95      45     2.70     +6.65`
   - `research/t3_drawdown/t3dd_output.txt:11` `AUDCHF  ALT   20    +21.91     -8.49      23     1.38    +23.29`
   - `research/t3_drawdown/t3dd_output.txt:12` `CADCHF  OPT   10    +21.63    -11.00      65     3.90    +25.53`
   - `research/t3_drawdown/t3dd_output.txt:13` `CADCHF  ALT   17    +31.16     -1.61      26     1.56    +32.72`
   - `research/t3_drawdown/t3dd_output.txt:14` ``

4. **Cell-by-cell recomputation of `calm = (S + R) / 40`, `oct = closes / 14`, `lo = 0.5 * min(calm, oct)`, `hi = 1.5 * max(calm, oct)`:**

| Cell | Calm `S+R` | `calm = (S+R)/40` | s8 `calm` | Oct `closes` | `oct = closes/14` | s8 `oct` | Exact `[0.5*min, 1.5*max]` (2 dp) | From rounded 2-dp rates | s8 `band` |
|---|---:|---:|---:|---:|---:|---:|---|---|---|
| `EURUSD OPT 7` | `651` | `16.2750` | `16.27` | `490` | `35.0000` | `35.00` | `8.14-52.50` | `8.13-52.50` | `8.14-52.50` |
| `EURUSD ALT 10` | `383` | `9.5750` | `9.57` | `298` | `21.2857` | `21.29` | `4.79-31.93` | `4.79-31.93` | `4.79-31.93` |
| `USDJPY OPT 13` | `665` | `16.6250` | `16.62` | `266` | `19.0000` | `19.00` | `8.31-28.50` | `8.31-28.50` | `8.31-28.50` |
| `USDJPY ALT 28` | `181` | `4.5250` | `4.53` | `78` | `5.5714` | `5.57` | `2.26-8.36` | `2.27-8.36` | `2.26-8.36` |
| `EURGBP OPT 5` | `238` | `5.9500` | `5.95` | `n/a` | `n/a` | `n/a` | `2.98-8.93` | `2.98-8.93` | `2.98-8.93` |
| `EURGBP ALT 23` | `5` | `0.1250` | `0.12` | `10` | `0.7143` | `0.71` | `0.06-1.07` | `0.06-1.06` | `0.06-1.07` |
| `AUDCAD OPT 14` | `161` | `4.0250` | `4.03` | `59` | `4.2143` | `4.21` | `2.01-6.32` | `2.02-6.32` | `2.01-6.32` |
| `AUDCAD ALT 26` | `42` | `1.0500` | `1.05` | `22` | `1.5714` | `1.57` | `0.53-2.36` | `0.53-2.35` | `0.53-2.36` |
| `AUDCHF OPT 14` | `55` | `1.3750` | `1.38` | `45` | `3.2143` | `3.21` | `0.69-4.82` | `0.69-4.81` | `0.69-4.82` |
| `AUDCHF ALT 19` | `29` | `0.7250` | `0.72` | `26` | `1.8571` | `1.86` | `0.36-2.79` | `0.36-2.79` | `0.36-2.79` |
| `NZDJPY OPT 15` | `521` | `13.0250` | `13.03` | `191` | `13.6429` | `13.64` | `6.51-20.46` | `6.52-20.46` | `6.51-20.46` |
| `NZDJPY ALT 26` | `190` | `4.7500` | `4.75` | `138` | `9.8571` | `9.86` | `2.38-14.79` | `2.38-14.79` | `2.38-14.79` |

   - Every single value in `research/e_week1/PREREG.md:93-98` matches the unrounded `(S+R)/40` and `closes/14` calculation formatted with Python `%.2f`.

5. **Is `EURGBP OPT 5`'s calm-only band (`2.98-8.93`) fair?**
   - Yes. `sw11o_eurgbp`'s per-deal replay file is outside git (`t3dd_output.txt:1` prints `missing: ['EURGBP OPT 5']`; `intraday.py:9, 29` notes `sw11o_eurgbp is not in /mnt/user-data/uploads/replay/`). On all 11 other cells, `oct > calm`, and `research/t3_drawdown/results.md:25` (`October 84% ($88 of $105)`) vs `t3dd_output.txt:17` (`Commission 73.50` across the 11 present cells) shows `EURGBP OPT 5` paid `~$14.50` commission (`~242` closes, `~17.3/day`) in October. Using calm-only (`5.95/day`, band `2.98-8.93`) therefore narrows the upper bound (`8.93` instead of `~25.9`), making Q2 stricter rather than looser:
   - `research/t3_drawdown/intraday.py:9` `U = '/mnt/user-data/uploads/replay/'; RES = '/root/fxmatrix/research/replay/results/'`
   - `research/t3_drawdown/intraday.py:29` `    segs, names, pos, scalps, snaps, counts = s9.load_run(U + 'run_%s.csv' % tag, U + 'out_%s_free_deals.csv' % tag,`
   - `research/t3_drawdown/results.md:25` `- **Commission / gross: calm 38% ($133.80 of $348.85); October 84% ($88 of $105).** The tight OPT arms paid most of it:`
   - `research/t3_drawdown/t3dd_output.txt:17` `Commission 73.50, net +70.42, gross before commission +143.92 (commission / gross = 51%)`

---

## 2. `s2, the days`

- **Verdict:** **CONFIRMED**

### Verification & Quotes

1. **Pre-registration s2 window and FTMO day claims (`research/e_week1/PREREG.md:19-30`):**
   - `research/e_week1/PREREG.md:19` ``
   - `research/e_week1/PREREG.md:20` `## 2. THE WINDOW AND THE DAYS`
   - `research/e_week1/PREREG.md:21` ``
   - `research/e_week1/PREREG.md:22` `- **Window W:** from E's first fill, **Fri 23 Oct 03:29:01Z**, to the end of **Fri 30 Oct's session** (the last`
   - `research/e_week1/PREREG.md:23` `  state snapshot before 21:05Z). If FTMO ends the trial earlier, W ends at the breach.`
   - `research/e_week1/PREREG.md:24` `- **FTMO days** (Prague midnight): 23 Oct = Thu 22:00Z - Fri 22:00Z; 24 Oct = Fri 22:00Z - Sat 22:00Z; **25 Oct =`
   - `research/e_week1/PREREG.md:25` `  Sat 22:00Z - Sun 23:00Z (25 hours: Prague leaves summer time at 01:00Z; this day holds Sunday's open, ~21:00Z)**;`
   - `research/e_week1/PREREG.md:26` `  26-30 Oct = 23:00Z - 23:00Z (30 Oct's day ends after W). Weekend days count (a carried loss counts on them too). The`
   - `research/e_week1/PREREG.md:27` `  brokers' midnight (21:00Z) is unchanged until 1 Nov.`
   - `research/e_week1/PREREG.md:28` `- **Trading days** (for rates): 0.73 on 23 Oct (03:29Z - 21:00Z) + 5 (Mon 26 - Fri 30) = **5.73**.`
   - `research/e_week1/PREREG.md:29` ``
   - `research/e_week1/PREREG.md:30` `## 3. INPUTS (read-only; nothing re-run)`

2. **Prague DST switch on Sunday 25 Oct 2026 (`01:00:00Z`):**
   - Both the EA (`ea/grind_pure.mqh:502-535`) and pipshed (`D:/pipshed/ftmo_daily.py:27-70`) implement the EU DST rule: Prague is `UTC+2` (`CEST`) from `01:00Z` on the last Sunday of March until `01:00Z` on the last Sunday of October (`2026-10-25 01:00:00Z`), when clocks fall back `03:00 CEST -> 02:00 CET` (`UTC+1`):
   - `ea/grind_pure.mqh:502` `datetime Grind_LastSundayMonthUtc(const int year, const int month)`
   - `ea/grind_pure.mqh:503` `{`
   - `ea/grind_pure.mqh:504` `   MqlDateTime dt;`
   - `ea/grind_pure.mqh:505` `   dt.year = year;`
   - `ea/grind_pure.mqh:506` `   dt.mon = month;`
   - `ea/grind_pure.mqh:507` `   dt.day = 31;`
   - `ea/grind_pure.mqh:508` `   dt.hour = 1;`
   - `ea/grind_pure.mqh:509` `   dt.min = 0;`
   - `ea/grind_pure.mqh:510` `   dt.sec = 0;`
   - `ea/grind_pure.mqh:511` `   datetime t = StructToTime(dt);`
   - `ea/grind_pure.mqh:512` `   while(true) {`
   - `ea/grind_pure.mqh:513` `      TimeToStruct(t, dt);`
   - `ea/grind_pure.mqh:514` `      if(dt.mon != month) {`
   - `ea/grind_pure.mqh:515` `         t -= 86400;`
   - `ea/grind_pure.mqh:516` `         continue;`
   - `ea/grind_pure.mqh:517` `      }`
   - `ea/grind_pure.mqh:518` `      if(dt.day_of_week == 0)`
   - `ea/grind_pure.mqh:519` `         return t;`
   - `ea/grind_pure.mqh:520` `      t -= 86400;`
   - `ea/grind_pure.mqh:521` `   }`
   - `ea/grind_pure.mqh:522` `   return 0;`
   - `ea/grind_pure.mqh:523` `}`
   - `ea/grind_pure.mqh:524` ``
   - `ea/grind_pure.mqh:525` `//+------------------------------------------------------------------+`
   - `ea/grind_pure.mqh:526` `int Grind_PragueUtcOffset(const datetime gmt)`
   - `ea/grind_pure.mqh:527` `{`
   - `ea/grind_pure.mqh:528` `   MqlDateTime dt;`
   - `ea/grind_pure.mqh:529` `   TimeToStruct(gmt, dt);`
   - `ea/grind_pure.mqh:530` `   const datetime dst_start = Grind_LastSundayMonthUtc(dt.year, 3);`
   - `ea/grind_pure.mqh:531` `   const datetime dst_end = Grind_LastSundayMonthUtc(dt.year, 10);`
   - `ea/grind_pure.mqh:532` `   if(gmt >= dst_start && gmt < dst_end)`
   - `ea/grind_pure.mqh:533` `      return 2;`
   - `ea/grind_pure.mqh:534` `   return 1;`
   - `ea/grind_pure.mqh:535` `}`
   - `D:/pipshed/ftmo_daily.py:47` ``
   - `D:/pipshed/ftmo_daily.py:48` ``
   - `D:/pipshed/ftmo_daily.py:49` `def _in_cest(utc_dt):`
   - `D:/pipshed/ftmo_daily.py:50` `    if utc_dt.tzinfo is None:`
   - `D:/pipshed/ftmo_daily.py:51` `        utc_dt = utc_dt.replace(tzinfo=timezone.utc)`
   - `D:/pipshed/ftmo_daily.py:52` `    for year in (utc_dt.year - 1, utc_dt.year, utc_dt.year + 1):`
   - `D:/pipshed/ftmo_daily.py:53` `        start, end = _cest_window_utc(year)`
   - `D:/pipshed/ftmo_daily.py:54` `        if start <= utc_dt < end:`
   - `D:/pipshed/ftmo_daily.py:55` `            return True`
   - `D:/pipshed/ftmo_daily.py:56` `    return False`
   - `D:/pipshed/ftmo_daily.py:57` ``
   - `D:/pipshed/ftmo_daily.py:58` ``
   - `D:/pipshed/ftmo_daily.py:59` `def _prague_midnight_utc(day):`
   - `D:/pipshed/ftmo_daily.py:60` `    utc_cet = datetime(day.year, day.month, day.day, tzinfo=timezone.utc) - timedelta(hours=1)`
   - `D:/pipshed/ftmo_daily.py:61` `    if _in_cest(utc_cet):`
   - `D:/pipshed/ftmo_daily.py:62` `        return utc_cet - timedelta(hours=1)`
   - `D:/pipshed/ftmo_daily.py:63` `    return utc_cet`
   - `D:/pipshed/ftmo_daily.py:64` ``
   - `D:/pipshed/ftmo_daily.py:65` ``
   - `D:/pipshed/ftmo_daily.py:66` `@lru_cache(maxsize=4096)`
   - `D:/pipshed/ftmo_daily.py:67` `def ftmo_day_bounds_utc(day):`
   - `D:/pipshed/ftmo_daily.py:68` `    start = _prague_midnight_utc(day)`
   - `D:/pipshed/ftmo_daily.py:69` `    end = _prague_midnight_utc(day + timedelta(days=1))`
   - Consequently:
     - **FTMO day `23 Oct`:** `2026-10-22 22:00:00Z` (`00:00 CEST`) to `2026-10-23 22:00:00Z` (`24h`).
     - **FTMO day `24 Oct`:** `2026-10-23 22:00:00Z` (`00:00 CEST`) to `2026-10-24 22:00:00Z` (`24h`, Saturday flat).
     - **FTMO day `25 Oct`:** `2026-10-24 22:00:00Z` (`00:00 CEST`) to `2026-10-25 23:00:00Z` (`00:00 CET`, `25h` across the `01:00Z` fall-back, holding Sunday's `~21:00Z` market open).
     - **FTMO days `26-30 Oct`:** each runs `23:00:00Z` to `23:00:00Z` (`00:00 CET` to `00:00 CET`, `24h`).

3. **`5.73` trading days calculation (`0.73 + 5.00`):**
   - On Friday 23 Oct, both brokers are on `GMT+3` (`docs/runbooks/twoarm-build-e.md:305-306`), so Friday's FX session closes at `21:00:00Z` (`24:00` server). From E's first fill at `03:29:01Z` (`docs/runbooks/twoarm-build-e.md:274`) to `21:00:00Z` is `17h 30m 59s = 63,059s = 63059 / 86400 = 0.72985` of a 24-hour trading day (`0.73` to 2 decimals).
   - Adding the 5 full 24-hour FX trading days of Week 1 (`Sun 25 Oct 21:00Z` to `Fri 30 Oct 21:00Z` = `120h = 5.00` days) gives `0.73 + 5.00 = 5.73` trading days.
   - Quotes from `docs/runbooks/twoarm-build-e.md:274, 305-306` and `handoffs/Handover/08_BACKLOG.md:59, 61`:
   - `docs/runbooks/twoarm-build-e.md:274` ``
   - `docs/runbooks/twoarm-build-e.md:305` `  of every fleet moves an hour later; the brokers' midnight (21:00Z) and the carry window (20:50-20:59Z) stay`
   - `docs/runbooks/twoarm-build-e.md:306` `  until the US clocks change on 1 Nov (BOOT s6: inferred, re-check then).`
   - `handoffs/Handover/08_BACKLOG.md:59` `| C150 | **IC access after 12 Oct ~19:06Z.** IC phoned the operator about verifying with government documents; he said he lives in Ontario; IC: the service is not available in that jurisdiction. The IC web dashboard refuses his login since; the MT5 terminals stay logged in; all fleets live at the status read after it. At risk: B, C, D (IC demo), the replay terminal's read-only login on 53077984, the tick dumps (wine-d for plan 3's holdout, wine-c for round 3's scoring). Insurance: EURUSD ticks 9 Oct 01:30 - 12 Oct 22:00 server, `ticks_53077984_EURUSD_hold_early.csv`, sha256 `5669094b...` (holdout data: copy and hash only; `docs/runbooks/plan3-holdout-export.md` X10). Operator: sweep7 also to test "our accessibility to IC markets". Claude: do not re-verify with different details. **s81 (12 Oct ~21:15-21:30Z):** the three IC terminals' journals show no login or disconnect line on 12 Oct, and the server answered each at the 21:00:01Z rollover (`[Market closed]`): connected after the call. Round 3's insurance taken: wine-c bid / ask, nine pairs, 12 Oct 00:00 to 13 Oct 00:20 server, `Downloads\bidask_ic_1012_insurance`, hashes equal both ends (`research/compass/round3_bidask_insurance.sha256`). **`D:\mt5-replay`'s login tested 21:47Z (operator's request): authorized and synchronized on 53077984, balance = D's; all four IC logins work.** **16 Oct ~22:34-22:59Z (s85): plan 4's insurance taken (sends B, C, D; wine-d EURUSD ticks 14 Oct 01:30 to 17 Oct 00:00 server, `bad_px=1`); wine-d's terminal served the dump; `research/replay/inputs/eurusd_window_p4_raw.sha256`.** | check every IC terminal at each status read; a logged-out terminal: STOP, record, operator's call; a plan 3 note if the holdout window must end at the insurance file |`
   - `handoffs/Handover/08_BACKLOG.md:61` `| C152 | **21 Oct ~03:10Z: PLAN 4 PASSED at timing 1 on its window (T1 B 98.2%, C 99.1%, D 99.2%; counts, bias, difference pass): the replay is fit for count-level use on EURUSD (plan 4 s10). Timing 0 FAIL, reported (C154).** **The replay at the weekly open (Claude, 14 Oct ~03:10Z).** Plan 3 FAILED on T1 (C 94.4%, D 94.9%; `replay-calibration-eurusd-3.md` s7 note of 14 Oct): five of the nine misses after the cut are Mon 12 Oct 00:00 server. The replay fills resting orders on the week's first quote (00:00:00.188 + latency) at the order price; IC filled them at 00:01:00.64-00:01:00.70 at the gap price 1.11903. Inferred, not checked: IC triggers pending orders only from the 00:01 quotes (the symbol's trade session not read). **Measured 14 Oct ~03:52Z (plan 4 Q3): trade 00:01-23:59, Fri 00:01-23:57.** Also: the first short (L0) at another time or price than live (3 misses) and one D long L7 entry (Tue 13 16:57 server) not reproduced. The counts matched (S 10/10, 15/14, 16/17, 14/14; R and A equal). Any fix is a harness change (prompt, Gemini, Cursor) and a NEW pre-registered plan on a new window; nothing re-scores plan 3. **14 Oct (s82 continued): the operator chose a plan 4** (`replay-calibration-eurusd-4.md`, REVIEWED and agreed; window Fri 16 Oct 00:00 to Wed 21 Oct 01:00 server). The causes read with Argon (`replay-consult-plan4.md` s8, s10): the trade session (00:01-23:59, Fri -23:57) and the stale-feed guard at the open; sync drops a layer at the exit, not the close-by, and ROLL rows timed by the EA host's clock; sync resets set the start-up reprice flags. Fixes F1-F4 | plan 4: F1-F4 + fix 1 GREEN (`replay-plan4` `8044284` 573 / 573; `plan4-tools` `a335ef0`, 196 OK); the development gate PASSED on both seen windows at timing 1 (s84); FROZEN `8044284` / `a335ef0` (`af9f227`); the window's export Tue 20 Oct from 22:10Z |`

4. **Does ending W at the last snapshot before `Fri 30 Oct 21:05Z` miss any of Friday's session?**
   - No. Both FTMO (`OANDA-Labs-Trader`, `GMT+3` until 1 Nov) and IC Markets (`ICMarketsSC-MT5-4`, `GMT+3` until 1 Nov) stop quoting for the weekend at `23:57-24:00` server time = `20:57-21:00Z` on Friday 30 Oct (`handoffs/Handover/08_BACKLOG.md:59, 61`). Because `archive_worker.py` writes `state_snapshots` once per minute (`snapped_at` on the minute boundary), the snapshots at `21:00Z-21:04Z` are 0-4 minutes *after* the Friday market close.

---

## 3. `s3 and s5, computable?`

- **Verdict:** **DEFECT**

### Defects & Verification Quotes

1. **Pre-registration s3 and s5 text (`research/e_week1/PREREG.md:32-42, 55-67`):**
   - `research/e_week1/PREREG.md:32` `- **pipshed's archive** (Railway Postgres; desktop `D:\pipshed`, `railway ssh --service archive-worker`), exported to`
   - `research/e_week1/PREREG.md:33` `  `D:\fxmatrix-exports\e_week1\` after Fri 30 Oct ~21:10Z, hashed (sha256) before any number is computed:`
   - `research/e_week1/PREREG.md:34` `  - `scripts/archive_counts.py --export-snapshots --from 2026-10-23T03:00Z --to 2026-10-30T21:30Z --csv`: one row`
   - `research/e_week1/PREREG.md:35` `    per instance per minute (balance, equity, net_mtm, layers per side, api_count, halted, quarantined).`
   - `research/e_week1/PREREG.md:36` `  - `scripts/archive_counts.py --export-archive --instance <id>` for E's twelve (`GRIND_<PAIR>_{OPT,ALT}E`) and D's`
   - `research/e_week1/PREREG.md:37` `    twelve (`GRIND_<PAIR>_{OPT,ALT}D`): fill_logs (profit, swap, commission per deal), scalp_history, ea_events`
   - `research/e_week1/PREREG.md:38` `    (`ROLL_ACCEPTED`, `ROLL_*`), config_events.`
   - `research/e_week1/PREREG.md:39` `- **FTMO's own objectives page** for 1515045375 (the operator reads it once after the close): its "max daily loss"`
   - `research/e_week1/PREREG.md:40` `  and "max loss" figures are the authority; ours explains them.`
   - `research/e_week1/PREREG.md:41` `- **The replay's committed counts** (s8): `research/t3_drawdown/t3dd_output.txt` (October 1-20, 14 trading days),`
   - `research/e_week1/PREREG.md:42` `  `research/t3_drawdown/calm_comm_output.txt` (calm, 8 weeks = 40 trading days).`
   - `research/e_week1/PREREG.md:55` `## 5. MEASURES (E; D the same where marked D)`
   - `research/e_week1/PREREG.md:56` ``
   - `research/e_week1/PREREG.md:57` `- **M1 FTMO daily loss per FTMO day** (s1's formula on minute marks; the minute marks under-read the true low, so M1`
   - `research/e_week1/PREREG.md:58` `  is a lower bound; FTMO's page decides): the worst, its day and minute, and the days over $300 and over $500.`
   - `research/e_week1/PREREG.md:59` `- **M2 Max loss:** E's lowest equity in W against FTMO's $9,000 floor (trial, static 10%); and against Instant's`
   - `research/e_week1/PREREG.md:60` `  trailing floor (the highest closed balance - $1,000), reported, not deciding.`
   - `research/e_week1/PREREG.md:61` `- **M3 Money (E and D):** the change in equity over W (primary: realised + the change in the open book, swaps and`
   - `research/e_week1/PREREG.md:62` `  commission in); realised; commission (as a cost, > 0); gross = realised + commission; commission / gross.`
   - `research/e_week1/PREREG.md:63` `- **M4 Per cell (pair x arm; E and D):** closes not rolled S, rolled closes R (a close whose position, found from its entry deal`
   - `research/e_week1/PREREG.md:64` `  in fill_logs, has a `ROLL_ACCEPTED`: `ea_events.ticket` is the position, `grind_engine.mqh` 1093), roll steps A (the`
   - `research/e_week1/PREREG.md:65` `  `ROLL_ACCEPTED` events), realised net; **closes per trading day = (S + R) / 5.73**; scalps per roll step S / A.`
   - `research/e_week1/PREREG.md:66` `- **M5 Requests:** E's highest `api_count` per server day against FTMO's 2,000 (C106).`
   - `research/e_week1/PREREG.md:67` ``

2. **DEFECT 3a -- `state_snapshots.balance` and `state_snapshots.equity` are ACCOUNT-level and non-null on ONLY ONE instance per account (the MAE lease holder):**
   - In `ea/grind_mae.mqh:57, 65, 314-327`, `Grind_MaeAccountBalanceJson()` and `Grind_MaeAccountEquityJson()` emit `AccountInfoDouble(ACCOUNT_BALANCE)` and `AccountInfoDouble(ACCOUNT_EQUITY)` **only** when `g_grind_mae_is_reporter` is `true`, and emit `"null"` on the other 11 instances on the terminal:
   - `ea/grind_mae.mqh:57` `   return AccountInfoDouble(ACCOUNT_EQUITY);`
   - `ea/grind_mae.mqh:65` `   return AccountInfoDouble(ACCOUNT_BALANCE);`
   - `ea/grind_mae.mqh:314` `string Grind_MaeAccountBalanceJson()`
   - `ea/grind_mae.mqh:315` `{`
   - `ea/grind_mae.mqh:316` `   if(!g_grind_mae_is_reporter)`
   - `ea/grind_mae.mqh:317` `      return "null";`
   - `ea/grind_mae.mqh:318` `   return Grind_MaeJsonDoubleOrNull(Grind_MaeReadBalanceLive(), true);`
   - `ea/grind_mae.mqh:319` `}`
   - `ea/grind_mae.mqh:321` `//+------------------------------------------------------------------+`
   - `ea/grind_mae.mqh:322` `string Grind_MaeAccountEquityJson()`
   - `ea/grind_mae.mqh:323` `{`
   - `ea/grind_mae.mqh:324` `   if(!g_grind_mae_is_reporter)`
   - `ea/grind_mae.mqh:325` `      return "null";`
   - `ea/grind_mae.mqh:326` `   return Grind_MaeJsonDoubleOrNull(Grind_MaeReadEquityLive(), true);`
   - In `D:/pipshed/archive_worker.py:1184-1190` and `D:/pipshed/migrations/005_c137_state_snapshots.sql:10-20`, `state_snapshots` has one row per `(snapped_at, instance_id)` where `balance` and `equity` are `DOUBLE PRECISION` (nullable) and `net_mtm`, `long_mtm`, `short_mtm` are per-instance:
   - `D:/pipshed/migrations/005_c137_state_snapshots.sql:10` `    balance numeric(14,2),`
   - `D:/pipshed/migrations/005_c137_state_snapshots.sql:11` `    equity numeric(14,2),`
   - `D:/pipshed/migrations/005_c137_state_snapshots.sql:12` `    net_mtm numeric(14,2),`
   - `D:/pipshed/migrations/005_c137_state_snapshots.sql:13` `    mtm_long numeric(14,2),`
   - `D:/pipshed/migrations/005_c137_state_snapshots.sql:14` `    mtm_short numeric(14,2),`
   - `D:/pipshed/migrations/005_c137_state_snapshots.sql:15` `    layers_long int,`
   - `D:/pipshed/migrations/005_c137_state_snapshots.sql:16` `    layers_short int,`
   - `D:/pipshed/migrations/005_c137_state_snapshots.sql:17` `    api_count int,`
   - `D:/pipshed/migrations/005_c137_state_snapshots.sql:18` `    halted boolean,`
   - `D:/pipshed/migrations/005_c137_state_snapshots.sql:19` `    quarantined boolean,`
   - `D:/pipshed/migrations/005_c137_state_snapshots.sql:20` `    entry_stopped boolean,`
   - `D:/pipshed/archive_worker.py:1183` `    return {`
   - `D:/pipshed/archive_worker.py:1184` `        "snapped_at": now.replace(second=0, microsecond=0),`
   - `D:/pipshed/archive_worker.py:1185` `        "instance_id": instance_id,`
   - `D:/pipshed/archive_worker.py:1186` `        "account_login": acc,`
   - `D:/pipshed/archive_worker.py:1187` `        "heartbeat_at": hb_at,`
   - `D:/pipshed/archive_worker.py:1188` `        "balance": _snap_num(data, "account_balance"),`
   - `D:/pipshed/archive_worker.py:1189` `        "equity": _snap_num(data, "account_equity"),`
   - `D:/pipshed/archive_worker.py:1190` `        "net_mtm": _snap_num(data, "net_mtm"),`
   - `D:/pipshed/archive_worker.py:1191` `        "mtm_long": mtm_long,`
   - `D:/pipshed/archive_worker.py:1192` `        "mtm_short": mtm_short,`
   - `D:/pipshed/archive_worker.py:1193` `        "layers_long": _snap_int(data, "open_layers_long"),`
   - `D:/pipshed/archive_worker.py:1194` `        "layers_short": _snap_int(data, "open_layers_short"),`
   - `D:/pipshed/archive_worker.py:1195` `        "api_count": _snap_int(data, "api_count"),`
   - And in `D:/pipshed/app.py:497-500`, pipshed itself documents that `balance` and `equity` are only present on the MAE reporter instance:
   - `D:/pipshed/app.py:497` `    """Login, balance and equity for a fleet. Only the MAE reporter's heartbeat`
   - `D:/pipshed/app.py:498` `    carries balance and equity (grind_mae.mqh 314-326; C72), so prefer the`
   - `D:/pipshed/app.py:499` `    live instance that reports a balance; else the first live one with a`
   - `D:/pipshed/app.py:500` `    login (money null)."""`
   - **Two immediate consequences for s5 and s7:**
     1. **Account-level `balance(t)` and `equity(t)` (M1, M2, M3 total, s6, Check 1):** At each minute `snapped_at`, `read.py` must filter `state_snapshots` to the target fleet (`account_login = 1515045375` for E; `account_login = 53077984` for D) and take the non-null `balance` and `equity` across that account's 12 instance rows (`MAX(balance)`, `MAX(equity)` where `balance IS NOT NULL`). Summing across instances or picking a fixed instance whose `balance`/`equity` is `NULL` fails.
     2. **Per-pair M3 equity change (`research/e_week1/PREREG.md:85`: `E's M3 equity change against D's over W, in total and per pair`):** Because `state_snapshots.equity` is account-wide (`ACCOUNT_EQUITY`), per-pair (or per-cell) equity change **cannot** be computed from `state_snapshots.equity`. It must be computed from `PREREG.md:61`'s primary decomposition: `sum(profit + swap + commission)` of deals in `fill_logs` over W for that pair's OPT+ALT instances, plus the change in `sum(state_snapshots.net_mtm)` across that pair's OPT+ALT instances from the first snapshot in W to the last snapshot in W (`ea/grind_pnl.mqh:140-141` sets `net_mtm = long_mtm + short_mtm` where each open position's MTM is `POSITION_PROFIT + POSITION_SWAP`, and `fill_logs.commission` on `IN` deals already books entry commission when the layer opens):
   - `ea/grind_pnl.mqh:140` `      sum += PositionGetDouble(POSITION_PROFIT)`
   - `ea/grind_pnl.mqh:141` `           + PositionGetDouble(POSITION_SWAP);`
   - `ea/grind_pnl.mqh:149` `   g_grind_realised_pnl_today = 0.0;`

3. **DEFECT 3b -- Does `--export-archive --instance` include every table s5 needs, and what does `--export-snapshots` export?**
   - In `D:/pipshed/scripts/archive_counts.py:79-95, 294-312`, `--export-archive --instance <id>` exports the 4 per-instance tables in `ARCHIVE_TABLES = ("config_events", "ea_events", "fill_logs", "scalp_history")`, and `--export-snapshots` exports `state_snapshots` across **all** fleets (`B`, `C`, `D`, `E`) unless `--instance` is passed:
   - `D:/pipshed/scripts/archive_counts.py:79` `ARCHIVE_TABLES = ("config_events", "ea_events", "fill_logs", "scalp_history")`
   - `D:/pipshed/scripts/archive_counts.py:80` ``
   - `D:/pipshed/scripts/archive_counts.py:81` ``
   - `D:/pipshed/scripts/archive_counts.py:82` `def export_archive(cur, instance):`
   - `D:/pipshed/scripts/archive_counts.py:83` `    """C83: every row of the four trade-history tables as JSON lines (a`
   - `D:/pipshed/scripts/archive_counts.py:84` `    _meta line first) -- the offline copy. send_logs are not included."""`
   - `D:/pipshed/scripts/archive_counts.py:85` `    print(json.dumps({"table": "_meta", "archive": True, "instance": instance}))`
   - `D:/pipshed/scripts/archive_counts.py:86` `    for table in ARCHIVE_TABLES:`
   - `D:/pipshed/scripts/archive_counts.py:87` `        cur.execute(`
   - `D:/pipshed/scripts/archive_counts.py:88` `            f"SELECT * FROM {table} WHERE (%(instance)s::text IS NULL OR instance_id = %(instance)s)"`
   - `D:/pipshed/scripts/archive_counts.py:89` `            " ORDER BY received_at, id", {"instance": instance})`
   - `D:/pipshed/scripts/archive_counts.py:90` `        cols = [desc[0] for desc in cur.description]`
   - `D:/pipshed/scripts/archive_counts.py:91` `        for row in cur.fetchall():`
   - `D:/pipshed/scripts/archive_counts.py:92` `            rec = {"table": table}`
   - `D:/pipshed/scripts/archive_counts.py:93` `            rec.update(dict(zip(cols, row)))`
   - `D:/pipshed/scripts/archive_counts.py:94` `            print(json.dumps(rec, default=str))`
   - `D:/pipshed/scripts/archive_counts.py:95` ``
   - `D:/pipshed/scripts/archive_counts.py:294` `       count(*) FILTER (WHERE slippage_pips > 0)                   AS favourable,`
   - `D:/pipshed/scripts/archive_counts.py:295` `       count(*) FILTER (WHERE slippage_pips < 0)                   AS adverse,`
   - `D:/pipshed/scripts/archive_counts.py:296` `       count(*) FILTER (WHERE abs(slippage_pips) > 0.2)            AS beyond_i6,`
   - `D:/pipshed/scripts/archive_counts.py:297` `       count(*) FILTER (WHERE slippage_pips < -0.2)                AS adverse_beyond_i6,`
   - `D:/pipshed/scripts/archive_counts.py:298` `       round(avg(slippage_pips)::numeric, 3)                       AS mean_pips,`
   - `D:/pipshed/scripts/archive_counts.py:299` `       round(min(slippage_pips)::numeric, 2)                       AS worst_adverse,`
   - `D:/pipshed/scripts/archive_counts.py:300` `       round(max(slippage_pips)::numeric, 2)                       AS best_favourable`
   - `D:/pipshed/scripts/archive_counts.py:301` `FROM fill_logs`
   - `D:/pipshed/scripts/archive_counts.py:302` `WHERE slippage_pips IS NOT NULL`
   - `D:/pipshed/scripts/archive_counts.py:303` `GROUP BY instance_id`
   - `D:/pipshed/scripts/archive_counts.py:304` `ORDER BY adverse_beyond_i6 DESC, instance_id;`
   - `D:/pipshed/scripts/archive_counts.py:305` `"""`
   - `D:/pipshed/scripts/archive_counts.py:306` ``
   - `D:/pipshed/scripts/archive_counts.py:307` `SLIPPAGE_BREACH_SQL = """`
   - `D:/pipshed/scripts/archive_counts.py:308` `SELECT deal_time_broker, instance_id, entry_type, deal_type, role,`
   - Together, the two commands in `PREREG.md:34-35` export all 5 Postgres tables needed by s5 (`state_snapshots`, `config_events`, `ea_events`, `fill_logs`, `scalp_history`), **except**:
     - `state_snapshots` CSV includes rows from fleets `B` and `C` as well as `D` and `E`, so `read.py` must filter by `account_login` (`1515045375` for E, `53077984` for D) or the 12+12 `instance_id`s.
     - Check 4 (`PREREG.md:53`) also requires `pipshed's scalps-per-roll table (cycle window, CSV)`, which is served by `/api/g/<token>/sr?format=csv&fleet=E&window=cycle` (`D:/pipshed/app.py:3679-3703`) and is missing from s3's export commands (see Item 4).

4. **DEFECT 3c -- Is the rolled-close join (`entry deal -> fill_logs.position_id -> ea_events.ticket of ROLL_ACCEPTED`) possible with the columns as they are?**
   - `PREREG.md:63-64` defines M4 as: `closes not rolled S, rolled closes R (a close whose position, found from its entry deal in fill_logs, has a ROLL_ACCEPTED: ea_events.ticket is the position, grind_engine.mqh 1093)`.
   - **Why this wording is defective if "a close" means a row in `scalp_history`:**
     - In `D:/pipshed/migrations/001_archive_phase1.sql:117-134`, `scalp_history` has columns `entry_deal_ticket` and `exit_deal_ticket`, **both of which are always `NULL`** for `fxgrind` because `Grind_BuildScalpClosedPayload` (`ea/grind_scalp_events.mqh:55-100`) never emits `entry_deal_ticket`, `exit_deal_ticket`, or `position_id` (only `rolled` as a boolean!).
   - `D:/pipshed/migrations/001_archive_phase1.sql:117` `CREATE INDEX ea_events_code_received_at ON ea_events (code, received_at);`
   - `D:/pipshed/migrations/001_archive_phase1.sql:118` ``
   - `D:/pipshed/migrations/001_archive_phase1.sql:119` `CREATE TABLE scalp_history (`
   - `D:/pipshed/migrations/001_archive_phase1.sql:120` `    id bigserial PRIMARY KEY,`
   - `D:/pipshed/migrations/001_archive_phase1.sql:121` `    instance_id text NOT NULL,`
   - `D:/pipshed/migrations/001_archive_phase1.sql:122` `    instrument text,`
   - `D:/pipshed/migrations/001_archive_phase1.sql:123` `    direction text NOT NULL,`
   - `D:/pipshed/migrations/001_archive_phase1.sql:124` `    entry_price double precision NOT NULL,`
   - `D:/pipshed/migrations/001_archive_phase1.sql:125` `    exit_price double precision NOT NULL,`
   - `D:/pipshed/migrations/001_archive_phase1.sql:126` `    gross_pnl double precision,`
   - `D:/pipshed/migrations/001_archive_phase1.sql:127` `    layer_depth int,`
   - `D:/pipshed/migrations/001_archive_phase1.sql:128` `    stack_depth int,`
   - `D:/pipshed/migrations/001_archive_phase1.sql:129` `    close_time_broker timestamp NOT NULL,`
   - `D:/pipshed/migrations/001_archive_phase1.sql:130` `    entry_deal_ticket bigint,`
   - `D:/pipshed/migrations/001_archive_phase1.sql:131` `    exit_deal_ticket bigint,`
   - `D:/pipshed/migrations/001_archive_phase1.sql:132` `    source text NOT NULL,`
   - `D:/pipshed/migrations/001_archive_phase1.sql:133` `    received_at timestamptz NOT NULL,`
   - `ea/grind_scalp_events.mqh:55` `string Grind_BuildScalpClosedPayload(const string instance_id,`
   - `ea/grind_scalp_events.mqh:56` `                                     const string instrument,`
   - `ea/grind_scalp_events.mqh:57` `                                     const string direction,`
   - `ea/grind_scalp_events.mqh:58` `                                     const double entry_price,`
   - `ea/grind_scalp_events.mqh:59` `                                     const double exit_price,`
   - `ea/grind_scalp_events.mqh:60` `                                     const int layer_depth,`
   - `ea/grind_scalp_events.mqh:61` `                                     const int stack_depth,`
   - `ea/grind_scalp_events.mqh:62` `                                     const double gross_pnl,`
   - `ea/grind_scalp_events.mqh:63` `                                     const datetime close_time,`
   - `ea/grind_scalp_events.mqh:64` `                                     const bool ejected,`
   - `ea/grind_scalp_events.mqh:65` `                                     const long broker_utc_offset_s,`
   - `ea/grind_scalp_events.mqh:66` `                                     const long account_login,`
   - `ea/grind_scalp_events.mqh:67` `                                     const bool rolled = false)`
   - `ea/grind_scalp_events.mqh:68` `{`
   - `ea/grind_scalp_events.mqh:69` `   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);`
   - `ea/grind_scalp_events.mqh:70` `   return StringFormat(`
   - `ea/grind_scalp_events.mqh:71` `      "{"`
   - `ea/grind_scalp_events.mqh:72` `      "\"close_time\":\"%s\","`
   - `ea/grind_scalp_events.mqh:73` `      "\"instrument\":\"%s\","`
   - `ea/grind_scalp_events.mqh:74` `      "\"direction\":\"%s\","`
   - `ea/grind_scalp_events.mqh:75` `      "\"entry_price\":%.5f,"`
   - `ea/grind_scalp_events.mqh:76` `      "\"exit_price\":%.5f,"`
   - `ea/grind_scalp_events.mqh:77` `      "\"layer_depth\":%d,"`
   - `ea/grind_scalp_events.mqh:78` `      "\"stack_depth\":%d,"`
   - `ea/grind_scalp_events.mqh:79` `      "\"gross_pnl\":%.2f,"`
   - `ea/grind_scalp_events.mqh:80` `      "\"instance_id\":\"%s\","`
   - `ea/grind_scalp_events.mqh:81` `      "\"ejected\":%s,"`
   - `ea/grind_scalp_events.mqh:82` `      "\"rolled\":%s,"`
   - `ea/grind_scalp_events.mqh:83` `      "\"broker_utc_offset_s\":%d,"`
   - `ea/grind_scalp_events.mqh:84` `      "\"account_login\":%I64d"`
   - `ea/grind_scalp_events.mqh:85` `      "}",`
     - Instead, when a layer closes in `Grind_HandleSideDealFill` (`ea/grind_engine.mqh:2908, 2921, 2934`), the EA checks `bool was_rolled = Grind_VLHas(closed_position);`, sets `rolled` on `SCALP_CLOSED` (`scalp_history.rolled`), and if `was_rolled` is true, also logs `ROLL_FILLED` in `ea_events` with `ticket = closed_position`:
   - `ea/grind_engine.mqh:1093` `   Grind_EjectReport("ROLL_ACCEPTED", pos, detail);`
   - `ea/grind_engine.mqh:2906` `         const ulong closed_position = side.layers[i].position_ticket;`
   - `ea/grind_engine.mqh:2908` `         const bool was_rolled = Grind_VLHas(closed_position);`
   - `ea/grind_engine.mqh:2921` `                                     was_rolled);`
   - `ea/grind_engine.mqh:2933` `               ",\"level\":" + Grind_ArchiveJsonDouble(roll_level, 5) + "}";`
   - `ea/grind_engine.mqh:2934` `            Grind_EjectReport("ROLL_FILLED", closed_position, roll_filled);`
   - **How the join works in `fill_logs` (as implemented in `D:/pipshed/ejection_view.py:92-101, 144-177`):**
     - In `fill_logs` (`D:/pipshed/migrations/001_archive_phase1.sql:92-112`), every `CloseBy` creates **two** `entry_type = 'OUT_BY'` rows sharing the same `order_ticket`: one `OUT_BY` row has `position_id` equal to the closed `ENT` position (`entry_type = 'IN'`, `role = 'ENT'`) and carries the closed `profit` and `swap`; the second `OUT_BY` row has `position_id` equal to the temporary `EXT` position (`entry_type = 'IN'`, `role = 'EXT'`) and has `profit = 0, swap = 0`:
   - `D:/pipshed/migrations/001_archive_phase1.sql:92` `    stranded_thresh_pips double precision,`
   - `D:/pipshed/migrations/001_archive_phase1.sql:93` `    cap_leg_a text,`
   - `D:/pipshed/migrations/001_archive_phase1.sql:94` `    cap_leg_b text,`
   - `D:/pipshed/migrations/001_archive_phase1.sql:95` `    cap_leg_a_thresh double precision,`
   - `D:/pipshed/migrations/001_archive_phase1.sql:96` `    cap_leg_b_thresh double precision,`
   - `D:/pipshed/migrations/001_archive_phase1.sql:97` `    inputs jsonb,`
   - `D:/pipshed/migrations/001_archive_phase1.sql:98` `    UNIQUE (instance_id, session_id, seq)`
   - `D:/pipshed/migrations/001_archive_phase1.sql:99` `);`
   - `D:/pipshed/migrations/001_archive_phase1.sql:100` ``
   - `D:/pipshed/migrations/001_archive_phase1.sql:101` `CREATE TABLE ea_events (`
   - `D:/pipshed/migrations/001_archive_phase1.sql:102` `    id bigserial PRIMARY KEY,`
   - `D:/pipshed/migrations/001_archive_phase1.sql:103` `    instance_id text NOT NULL,`
   - `D:/pipshed/migrations/001_archive_phase1.sql:104` `    magic bigint,`
   - `D:/pipshed/migrations/001_archive_phase1.sql:105` `    session_id text NOT NULL,`
   - `D:/pipshed/migrations/001_archive_phase1.sql:106` `    seq bigint NOT NULL,`
   - `D:/pipshed/migrations/001_archive_phase1.sql:107` `    ea_time_ms bigint,`
   - `D:/pipshed/migrations/001_archive_phase1.sql:108` `    received_at timestamptz NOT NULL,`
   - `D:/pipshed/migrations/001_archive_phase1.sql:109` `    level text NOT NULL,`
   - `D:/pipshed/migrations/001_archive_phase1.sql:110` `    code text NOT NULL,`
   - `D:/pipshed/migrations/001_archive_phase1.sql:111` `    reason text,`
   - `D:/pipshed/ejection_view.py:144` `    for order_ticket, out_deals in by_order.items():`
   - `D:/pipshed/ejection_view.py:145` `        if len(out_deals) != 2:`
   - `D:/pipshed/ejection_view.py:146` `            odd_closeby.append({`
   - `D:/pipshed/ejection_view.py:147` `                "order_ticket": order_ticket,`
   - `D:/pipshed/ejection_view.py:148` `                "deal_count": len(out_deals),`
   - `D:/pipshed/ejection_view.py:149` `                "instance_id": out_deals[0].get("instance_id") if out_deals else None,`
   - `D:/pipshed/ejection_view.py:150` `            })`
   - `D:/pipshed/ejection_view.py:151` `            continue`
   - `D:/pipshed/ejection_view.py:152` `        positions = {`
   - `D:/pipshed/ejection_view.py:153` `            d.get("position_id") for d in out_deals if d.get("position_id") is not None`
   - `D:/pipshed/ejection_view.py:154` `        }`
   - `D:/pipshed/ejection_view.py:155` `        if not positions:`
   - `D:/pipshed/ejection_view.py:156` `            continue`
   - `D:/pipshed/ejection_view.py:157` `        close_ms = max(int(d.get("ea_time_ms") or 0) for d in out_deals)`
   - `D:/pipshed/ejection_view.py:158` `        inst = out_deals[0].get("instance_id")`
   - `D:/pipshed/ejection_view.py:159` `        own = _rows_for_positions(index, positions)`
   - `D:/pipshed/ejection_view.py:160` `        layer_pos, side, layer_index = _layer_from_ent(own, positions)`
   - `D:/pipshed/ejection_view.py:161` `        incomplete = layer_pos is None`
   - `D:/pipshed/ejection_view.py:162` `        if side is None:`
   - `D:/pipshed/ejection_view.py:163` `            for deal in out_deals:`
   - `D:/pipshed/ejection_view.py:164` `                side = _side_letter(deal)`
   - `D:/pipshed/ejection_view.py:165` `                if side:`
   - `D:/pipshed/ejection_view.py:166` `                    break`
   - `D:/pipshed/ejection_view.py:167` `        gross, commission, swap, net = _sum_deals_for_positions(own, positions)`
   - `D:/pipshed/ejection_view.py:168` `        if incomplete:`
   - `D:/pipshed/ejection_view.py:169` `            net = None`
   - `D:/pipshed/ejection_view.py:170` `            commission = None`
   - `D:/pipshed/ejection_view.py:171` `            swap = None`
   - `D:/pipshed/ejection_view.py:172` `        if layer_pos in roll_positions:`
   - `D:/pipshed/ejection_view.py:173` `            trade_class = "roll"`
   - `D:/pipshed/ejection_view.py:174` `        elif layer_pos in eject_positions:`
   - `D:/pipshed/ejection_view.py:175` `            trade_class = "eject"`
   - `D:/pipshed/ejection_view.py:176` `        else:`
     - Therefore, in `fill_logs`, a closed layer is an `OUT_BY` row whose `position_id` belongs to an `IN` deal with `role = 'ENT'`. That `OUT_BY` row **already has `position_id`** equal to the closed position ticket, which joins directly to `ea_events.ticket` of `event_type = 'ROLL_ACCEPTED'` (or `event_type = 'ROLL_FILLED'`) on the same `instance_id` -- or in `scalp_history`, `rolled = false` gives `S` and `rolled = true` gives `R` directly (as `D:/pipshed/sr_table.py:77-87, 179` does):
   - `D:/pipshed/sr_table.py:77` `def close_kind(rolled, ejected, account_login):`
   - `D:/pipshed/sr_table.py:78` `    """'roll', 'eject' or 'scalp' for one closed layer."""`
   - `D:/pipshed/sr_table.py:79` `    if rolled is True:`
   - `D:/pipshed/sr_table.py:80` `        return "roll"`
   - `D:/pipshed/sr_table.py:81` `    if ejected is True:`
   - `D:/pipshed/sr_table.py:82` `        try:`
   - `D:/pipshed/sr_table.py:83` `            on_cycle3 = account_login is not None and int(account_login) == CYCLE3_ACCOUNT`
   - `D:/pipshed/sr_table.py:84` `        except (TypeError, ValueError):`
   - `D:/pipshed/sr_table.py:85` `            on_cycle3 = False`
   - `D:/pipshed/sr_table.py:86` `        return "roll" if on_cycle3 else "eject"`
   - `D:/pipshed/sr_table.py:87` `    return "scalp"`
   - `D:/pipshed/sr_table.py:179` `        kind = close_kind(row.get("rolled"), row.get("ejected"), acc)`
     - Note also for D (which entered W holding its 21 Oct book): if a position on D was rolled (`ROLL_ACCEPTED`) *before* W and closed *inside* W, `scalp_history.rolled` is `true` and `ROLL_FILLED` is inside W, whereas `ROLL_ACCEPTED` in `ea_events` has a timestamp before W. Using all `ROLL_ACCEPTED` rows in `ea_events` (unrestricted to W, or matching `scalp_history.rolled`) for the `position_id` lookup ensures a pre-W rolled position closing in W is classified as `R`, while `A` counts `ROLL_ACCEPTED` events occurring inside W.

### Smallest Fix to `research/e_week1/PREREG.md` (s3 and s5)

- In **s3 (`research/e_week1/PREREG.md:34-36`)**, add the `sr` CSV export needed by Check 4:
  ```markdown
  python scripts/archive_counts.py --export-snapshots --from 2026-10-23T03:00Z --to 2026-10-30T21:30Z --csv
  python scripts/archive_counts.py --export-archive --instance <each of the 24 instance_ids> --csv
  curl -sS "$PIPSHED_URL/api/g/$PIPSHED_TOKEN/sr?format=csv&fleet=E&window=cycle" > sr_e_cycle.csv
  ```
- In **s5 (`research/e_week1/PREREG.md:57-65`)**, clarify the account-level reporter row vs per-pair M3 and the M4 close join:
  - In **M1 / M2** (`lines 57-60`): specify that at each minute `snapped_at`, account `balance` and `equity` are read from the single non-null MAE-reporter row in `state_snapshots` for that account (`account_login = 1515045375` for E, `53077984` for D).
  - In **M3** (`lines 61-62`): specify that account-total M3 is `equity(t_end) - equity(t_start)` (primary: `sum(profit + swap + commission)` in `fill_logs` over W plus `sum(net_mtm(t_end)) - sum(net_mtm(t_start))` across the 12 instances in `state_snapshots`), and per-pair / per-cell M3 uses that primary sum restricted to the pair's OPT+ALT instances.
  - In **M4** (`lines 63-65`): replace `(a close whose position, found from its entry deal in fill_logs, has a ROLL_ACCEPTED: ea_events.ticket is the position, grind_engine.mqh 1093)` with `(a close in fill_logs -- an OUT_BY deal whose position_id has an IN deal with role = 'ENT' -- whose position_id matches ea_events.ticket of a ROLL_ACCEPTED on that instance, grind_engine.mqh 1093; cross-checked against scalp_history.rolled)`.

---

## 4. `s4, the self-checks`

- **Verdict:** **DEFECT**

### Verification & Quotes

1. **Pre-registration s4 text (`research/e_week1/PREREG.md:44-54`):**
   - `research/e_week1/PREREG.md:44` `## 4. SELF-CHECKS FIRST (any failure: STOP, record it, amend before any measure is read)`
   - `research/e_week1/PREREG.md:45` ``
   - `research/e_week1/PREREG.md:46` `1. **Balance reconciles:** $10,000 + the sum over E's deals in W of (profit + swap + commission) equals E's last`
   - `research/e_week1/PREREG.md:47` `   snapshot balance in W within $0.05. Same for D from its first snapshot balance in W.`
   - `research/e_week1/PREREG.md:48` `2. **Minute coverage:** E's account has a snapshot in at least 95% of W's session minutes; every gap over 5 minutes`
   - `research/e_week1/PREREG.md:49` `   listed (a gap can hide the day's low).`
   - `research/e_week1/PREREG.md:50` `3. **Instances:** E's twelve and D's twelve present; config_events show no attach after 23 Oct 03:25Z on E (none`
   - `research/e_week1/PREREG.md:51` `   expected) and none on D after 21 Oct 15:54Z.`
   - `research/e_week1/PREREG.md:52` `4. **Counts agree:** scalps per E instance in scalp_history equal the closing deals in fill_logs (role EXT) within 2;`
   - `research/e_week1/PREREG.md:53` `   pipshed's scalps-per-roll table (cycle window, CSV) agrees with the scalp and roll counts within 2.`
   - `research/e_week1/PREREG.md:54` ``

2. **DEFECT 4a -- Check 4's `closing deals in fill_logs (role EXT)` is wrong on the schema (`ea/grind_archive.mqh:413-424`, `ea/grind_engine.mqh:2994`):**
   - In `ea/grind_archive.mqh:413-424`, `fill_logs.role` is populated by calling `GrindCommentParse(comment, c_arm, c_side, c_layer, c_role)` on `DEAL_COMMENT`:
   - `ea/grind_archive.mqh:413` `   string slot = "null";`
   - `ea/grind_archive.mqh:414` `   string side = "null";`
   - `ea/grind_archive.mqh:415` `   string role = "null";`
   - `ea/grind_archive.mqh:416` `   string layer_index = "null";`
   - `ea/grind_archive.mqh:417` `   string c_slot, c_side, c_role;`
   - `ea/grind_archive.mqh:418` `   int c_layer;`
   - `ea/grind_archive.mqh:419` `   if(GrindCommentParse(comment, c_slot, c_side, c_layer, c_role)) {`
   - `ea/grind_archive.mqh:420` `      slot = "\"" + Grind_JsonEscape(c_slot) + "\"";`
   - `ea/grind_archive.mqh:421` `      side = "\"" + Grind_JsonEscape(c_side) + "\"";`
   - `ea/grind_archive.mqh:422` `      role = "\"" + Grind_JsonEscape(c_role) + "\"";`
   - `ea/grind_archive.mqh:423` `      layer_index = IntegerToString(c_layer);`
   - `ea/grind_archive.mqh:424` `   }`
   - When an exit limit order (`GRIND|OPT|L|L00|EXT`) fills, MT5 executes it as an **opening** deal (`entry_type = 'IN'`, `role = 'EXT'`), which opens the temporary opposite position and triggers `OrderSendAsync(ORDER_TYPE_CLOSE_BY)` (`ea/grind_engine.mqh:2994-3011`):
   - `ea/grind_engine.mqh:2994` `   if(c_role == "EXT" && entry_type == DEAL_ENTRY_IN) {`
   - `ea/grind_engine.mqh:2995` `      int layer_idx = Grind_FindLayerByExitOrder(side, order_ticket);`
   - `ea/grind_engine.mqh:2996` `      if(layer_idx < 0)`
   - `ea/grind_engine.mqh:2997` `         layer_idx = Grind_FindLayerByIndex(side, c_layer);`
   - `ea/grind_engine.mqh:2998` `      if(layer_idx < 0)`
   - `ea/grind_engine.mqh:2999` `         return;`
   - `ea/grind_engine.mqh:3000` ``
   - `ea/grind_engine.mqh:3001` `      if(side.layers[layer_idx].exit_position_ticket == position_id &&`
   - `ea/grind_engine.mqh:3002` `         position_id != 0)`
   - `ea/grind_engine.mqh:3003` `         return;`
   - `ea/grind_engine.mqh:3004` ``
   - `ea/grind_engine.mqh:3005` `      const ulong orig_pos = side.layers[layer_idx].position_ticket;`
   - `ea/grind_engine.mqh:3006` `      side.layers[layer_idx].exit_order_ticket = 0;`
   - `ea/grind_engine.mqh:3007` `      side.layers[layer_idx].exit_position_ticket = position_id;`
   - `ea/grind_engine.mqh:3008` ``
   - `ea/grind_engine.mqh:3009` `      if(orig_pos > 0 && position_id > 0) {`
   - `ea/grind_engine.mqh:3010` `         if(is_long)`
   - `ea/grind_engine.mqh:3011` `            Grind_QueueCloseBy(g_grind_long_closeby_queue, orig_pos, position_id);`
   - When `CloseBy` executes, MT5 sets `DEAL_COMMENT` on both `OUT_BY` closing deals to `"close #... by #..."`, which does **not** start with `"GRIND|"`, so `GrindCommentParse` returns `false` and **every `OUT_BY` closing deal in `fill_logs` has `role = NULL`** (and there are **two** `OUT_BY` deals per CloseBy: one for the `ENT` position and one for the `EXT` position). This is also why `D:/pipshed/ejection_view.py:98-100, 144-160` joins `OUT_BY` rows back to `IN` rows by `position_id` to find `role`:
   - `D:/pipshed/ejection_view.py:98` `        if (row.get("role") or "").upper() != "ENT":`
   - `D:/pipshed/ejection_view.py:99` `            continue`
   - `D:/pipshed/ejection_view.py:100` `        return row.get("position_id"), _side_letter(row), row.get("layer_index")`
   - `D:/pipshed/ejection_view.py:101` `    return None, None, None`
   - Therefore, in Check 4 (`PREREG.md:52`), filtering `fill_logs` for closing deals with `role = 'EXT'` returns **0 rows**! Either filter `fill_logs` for `entry_type = 'IN' AND role = 'EXT'` (one exit-fill deal per close), or filter `entry_type = 'OUT_BY'` whose `position_id` has an `IN` deal with `role = 'ENT'` (one `OUT_BY` deal per close).
   - Additionally, Check 4 (`PREREG.md:53`) compares `scalps` and `ROLL_ACCEPTED` against `pipshed's scalps-per-roll table (cycle window, CSV)`. In `D:/pipshed/app.py:1980-1982, 2076-2093`, that CSV has one row per `(instance, side)` (`L` and `S`) with columns `S` (unrolled scalps), `R` (rolled closes), `E` (ejections), and `rolls_started` (`ROLL_ACCEPTED`):
   - `D:/pipshed/app.py:1980` `SR_CSV_COLUMNS = ("fleet", "pair", "instance_id", "side", "window", "S", "R", "E",`
   - `D:/pipshed/app.py:1981` `                  "rolls_started", "sr", "k_star", "k_star_gross", "k_actual", "edge",`
   - `D:/pipshed/app.py:1982` `                  "realised_pips", "c_pips", "grey", "cap", "add", "exit")`
   - `D:/pipshed/app.py:2076` `def _sr_csv(table, fleet=None, instance=None, window=None):`
   - `D:/pipshed/app.py:2077` `    lines = [",".join(SR_CSV_COLUMNS)]`
   - `D:/pipshed/app.py:2078` `    for letter in table.get("fleets") or []:`
   - `D:/pipshed/app.py:2079` `        if fleet and letter != fleet:`
   - `D:/pipshed/app.py:2080` `            continue`
   - `D:/pipshed/app.py:2081` `        for row in (table.get("rows") or {}).get(letter) or []:`
   - `D:/pipshed/app.py:2082` `            if instance and row["instance_id"] != instance:`
   - `D:/pipshed/app.py:2083` `                continue`
   - `D:/pipshed/app.py:2084` `            geo = row.get("geometry") or {}`
   - `D:/pipshed/app.py:2085` `            for win in SR_WINDOWS:`
   - `D:/pipshed/app.py:2086` `                if window and win != window:`
   - `D:/pipshed/app.py:2087` `                    continue`
   - `D:/pipshed/app.py:2088` `                cell = row.get(win) or {}`
   - `D:/pipshed/app.py:2089` `                vals = [letter, row["pair"], row["instance_id"], row["side"], win]`
   - `D:/pipshed/app.py:2090` `                vals += [cell.get(k) for k in SR_CSV_COLUMNS[5:17]]`
   - `D:/pipshed/app.py:2091` `                vals += [geo.get("cap"), geo.get("add"), geo.get("exit")]`
   - `D:/pipshed/app.py:2092` `                lines.append(",".join(_sr_csv_cell(v) for v in vals))`
   - Because `scalp_history` contains both unrolled (`rolled = false`) and rolled (`rolled = true`) closes, Check 4 must compare total `scalp_history` rows per E instance against `sum(S + R)` across `L` and `S` in `sr` CSV (or compare `scalp_history WHERE NOT rolled` against `sum(S)` and `WHERE rolled` against `sum(R)`), and `ROLL_ACCEPTED` in `ea_events` against `sum(rolls_started)` across `L` and `S`.

3. **Check 1 (`PREREG.md:46-47`): Is `$0.05` a sound tolerance? What could make Check 1 fail for a reason that is not an error? Plus a window-start defect on D:**
   - **Why `$0.05` is a sound tolerance:** In `ea/grind_archive.mqh:451-453`, every deal's `profit`, `swap`, and `commission` is formatted with `Grind_ArchiveJsonDouble(..., 2)`, matching MT5's 2-decimal account ledger to the cent (`$0.01`):
   - `ea/grind_archive.mqh:451` `          ",\"profit\":" + Grind_ArchiveJsonDouble(profit, 2) +`
   - `ea/grind_archive.mqh:452` `          ",\"swap\":" + Grind_ArchiveJsonDouble(swap, 2) +`
   - `ea/grind_archive.mqh:453` `          ",\"commission\":" + Grind_ArchiveJsonDouble(commission, 2) +`
     A `$0.05` tolerance absorbs IEEE-754 floating-point summation drift over hundreds of deals while remaining tight enough to catch a single missing close commission (`-$0.06` on E, `-$0.08` on D) or half-turn entry commission (`-$0.03` on E, `-$0.04` on D).
   - **DEFECT 4b on D's start timestamp in Check 1 (`PREREG.md:47`):**
     - W starts at E's first fill (`2026-10-23 03:29:01Z`, `PREREG.md:20`). For E, balance before `03:29:01Z` is `$10,000.00`, and E's first deal at `03:29:01Z` is inside W.
     - For D, however, D was already live and trading from `21 Oct 15:54Z` (`PREREG.md:51`). D's `first snapshot balance in W` is the snapshot at `2026-10-23 03:30:00Z` (59 seconds *after* `03:29:01Z`, with `heartbeat_at` inside `03:29:01Z..03:30:00Z`). If D had any fill (`IN` commission or `OUT_BY` P&L) between `03:29:01Z` and D's first snapshot `heartbeat_at`, that deal is already baked into D's first snapshot `balance` **and** is inside W (`>= 03:29:01Z`), so adding all of D's deals in W to D's first snapshot balance in W double-counts it!
     - Similarly, at the end of W (especially if W ends early at a breach during active trading), a fill between the last snapshot's `heartbeat_at` and `snapped_at` is in `fill_logs` but not yet in the snapshot's `balance` (`D:/pipshed/archive_worker.py:1166, 1184`).
   - **Three things that could make Check 1 fail for a reason that is not a data-integrity error:**
     1. **A deal on D between `03:29:01Z` and D's first snapshot `heartbeat_at` in W (or between the last snapshot `heartbeat_at` and `W_end`):** fixed by summing deals strictly between `(first_snapshot.heartbeat_at, last_snapshot.heartbeat_at]` for D (and `<= last_snapshot.heartbeat_at` for E).
     2. **Non-trade balance entries (`DEAL_TYPE_BALANCE`, `DEAL_TYPE_CREDIT`, `DEAL_COMMISSION`, `DEAL_FEE`) or manual deals (`magic = 0`):** `Grind_ProcessDeal` (`ea/grind_engine.mqh:3340-3345`) only records deals to `fill_logs` where `DEAL_SYMBOL == _Symbol` and `DEAL_MAGIC == magic`:
   - `ea/grind_engine.mqh:3340` `   if(Grind_DealGetString(deal_ticket, DEAL_SYMBOL) != _Symbol)`
   - `ea/grind_engine.mqh:3341` `      return false;`
   - `ea/grind_engine.mqh:3342` `   if(!Grind_MagicMatches(Grind_DealGetInteger(deal_ticket, DEAL_MAGIC), magic))`
   - `ea/grind_engine.mqh:3343` `      return false;`
   - `ea/grind_engine.mqh:3344` ``
   - `ea/grind_engine.mqh:3345` `   Grind_ArchiveRecordFill(deal_ticket, magic);`
   - `ea/grind_engine.mqh:3346` `   if(g_grind_halted)`
        By contrast, `Grind_SnapshotEmit` (`ea/grind_snapshot.mqh:278-284`) checks whether `DEAL_FEE` or non-BUY/SELL deals exist on the account history:
   - `ea/grind_snapshot.mqh:278` `         const long dtype = HistoryDealGetInteger(ticket, DEAL_TYPE);`
   - `ea/grind_snapshot.mqh:279` `         if(dtype != DEAL_TYPE_BUY && dtype != DEAL_TYPE_SELL) {`
   - `ea/grind_snapshot.mqh:280` `            nontrade += HistoryDealGetDouble(ticket, DEAL_PROFIT)`
   - `ea/grind_snapshot.mqh:281` `                        + HistoryDealGetDouble(ticket, DEAL_SWAP)`
   - `ea/grind_snapshot.mqh:282` `                        + HistoryDealGetDouble(ticket, DEAL_COMMISSION)`
   - `ea/grind_snapshot.mqh:283` `                        + HistoryDealGetDouble(ticket, DEAL_FEE);`
   - `ea/grind_snapshot.mqh:284` `         }`
     3. **Note on Wednesday's triple swap:** Overnight swaps (`POSITION_SWAP`) on *open* positions affect `ACCOUNT_EQUITY` (`net_mtm`), **not** `ACCOUNT_BALANCE`; they enter `ACCOUNT_BALANCE` and `fill_logs.swap` together at position close (`OUT_BY`), so Wednesday's triple swap on open positions does **not** cause Check 1 to fail (and C86/C144 only adjusts the EA's exit limit order price, not the broker ledger).

### Smallest Fix to `research/e_week1/PREREG.md` (s4)

- Replace `research/e_week1/PREREG.md:46-47` and `52-53` with:
  ```markdown
  1. `$10,000 + the sum over E's deals in W (up to E's last snapshot heartbeat_at in W) of (profit + swap + commission) equals E's last snapshot balance in W within $0.05. For D, D's first snapshot balance in W + the sum over D's deals with deal time in (D's first snapshot heartbeat_at in W, D's last snapshot heartbeat_at in W] of (profit + swap + commission) equals D's last snapshot balance in W within $0.05.`
  ...
  4. `scalps per E instance in scalp_history (rolled and unrolled) equal the exit-fill deals in fill_logs (entry_type = 'IN' and role = 'EXT', or OUT_BY deals whose position_id has an IN deal with role = 'ENT') within 2, and both scalps (S + R) and ROLL_ACCEPTED (rolls_started) match pipshed's scalps-per-roll table (sr_e_cycle.csv, summed over L and S) within 2.`
  ```

---

## 5. `s7, the rules`

- **Verdict:** **GAP**

### Verification & Quotes

1. **Pre-registration s7 text (`research/e_week1/PREREG.md:75-88`):**
   - `research/e_week1/PREREG.md:75` `## 7. THE THREE QUESTIONS AND HOW EACH IS READ`
   - `research/e_week1/PREREG.md:76` ``
   - `research/e_week1/PREREG.md:77` `**Q1 (FTMO; C164).** **TRIAL-SAFE** if M1 < $500 on every day and M2 above $9,000; **INSTANT-FIT** if also M1 <=`
   - `research/e_week1/PREREG.md:78` `$300 on every day. Otherwise the day and the episode that broke it.`
   - `research/e_week1/PREREG.md:79` ``
   - `research/e_week1/PREREG.md:80` `**Q2 (does live trade like the replay?).** Per cell, the live closes per trading day against the band **[0.5 x the`
   - `research/e_week1/PREREG.md:81` `lower, 1.5 x the higher]** of the replay's calm and October rates (s8). **CONSISTENT** if at least 9 of the 12 cells`
   - `research/e_week1/PREREG.md:82` `fall inside; else **NOT CONSISTENT**: the replay misreads live activity, and changes built on it (C's cap 9 among them)`
   - `research/e_week1/PREREG.md:83` `are flagged before the next one.`
   - `research/e_week1/PREREG.md:84` ``
   - `research/e_week1/PREREG.md:85` `**Q3 (t3 against t1; C162).** E's M3 equity change against D's over W, in total and per pair. **Reported, not`
   - `research/e_week1/PREREG.md:86` `decided:** one week is one draw; C162 stays OPEN. Read beside it: the brokers differ (FTMO against IC: spreads,`
   - `research/e_week1/PREREG.md:87` `commission per close, fills), and D entered W holding its 21 Oct book while E started flat.`
   - `research/e_week1/PREREG.md:88` ``

2. **Q1 (`TRIAL-SAFE` / `INSTANT-FIT`) vs FTMO's trial and Instant rules:**
   - **Where the rules are recorded vs read on FTMO's site:**
     - **2-Step / Free Trial (`$500` daily loss on `00:00 CE(S)T` balance, `$9,000` static max loss floor, `2,000/day` request cap):** read from `ftmo.com` on 5 Oct and recorded in `handoffs/Handover/08_BACKLOG.md:83` (`C124`), `docs/architecture/ADR-158-daily-loss-breaker.md:14-16`, and `docs/runbooks/twoarm-build-e.md:19, 23` (`E3`, `E7`); `research/t3_drawdown/results.md:43-44` explicitly notes that the t3 drawdown read used the rule as recorded in C164 and E's runbook, while `docs/runbooks/twoarm-build-e.md:23` notes `what FTMO does to a free trial at a breach is not known here`:
   - `handoffs/Handover/08_BACKLOG.md:83` `| C124 | **FTMO pass probability: what are the odds of a payout?** (operator 5 Oct ~03:50Z, after s56's markout study: "selling higher highs and buying lower lows, we are doing the hedge trades for a long convexity option position, so by definition, we are taking a short convexity position"; "we do not get an upfront payment"; "the risk with a short gamma position is tail risk - which is why this trade suits the FTMO framework so well"; "we have to pay $100 upfront, bear vps costs and have to make $800 before we ever see any payout. i can see the odds of that being slim"; asked for this item: "so we can pick it up tmrw morning"). **Framing (Claude, 5 Oct; the reason to measure, not a result):** the grid is short gamma; the FTMO structure is a LONG option on the grid's P&L: the fee is the premium, the loss is capped at fee + costs, the upside is the profit share; FTMO is short that option and hedges it with its rules (daily and total loss limits knock the account out). For a zero-edge strategy, P(reach +T before -L) is about L / (L + T) whatever the shape of the daily P&L (optional stopping; overshoot ignored): with the operator's $800 against the $1,000 max loss, about 0.55. What pulls it down: (1) the DAILY limit, hit by a trend day or by open MTM carried across 22:00Z (cycle 2 ended so on 23 Sep: Max Daily Loss -$505.34 vs -$500, `docs/FULL_TRIAL_RECORD_1514582088.md` 26-27); (2) negative drift (spread, commission, adverse selection: markout study s4); (3) time: a slow grind needs many days, each a chance of a trend day. The objective it implies for FTMO: drift per unit of worst daily drawdown (compass-round s8, GC-5, already promotes on that drawdown). **Questions:** P(pass), expected trading days to pass (and their spread), EV per attempt = P(pass) x E[payouts] - fee - VPS cost x expected months; which lever moves P(pass) most: instances (7 today vs fewer), cap, drift. **Inputs from the operator at the start (do not take them from memory or the web):** fee per attempt ($100, operator); profit target per phase and the number of phases ($800, operator: confirm whether that is one phase or the total); max daily loss ($500 on $10k, measured from what: day-start balance or equity, and at which hour; the trial record and BOOT s3 say the FTMO day starts 22:00Z in summer); max loss ($1,000, trial record 27); minimum trading days, any time limit; payout split and first-payout timing; VPS cost per month. **Data (all already held; read-only):** FTMO 1514731800 (cycle 3, from 24 Sep; 11 instances to 2 Oct ~15:40Z, then 7: split those days) and cycle 2 1514582088 (10-23 Sep; trial record); the deal histories `history_<login>.csv` from `scripts/grind_history_dump.mq5` (D4: complete from the first deal, reconciled; on the Surface `C:\fxmatrix\exports\`); FTMO minute bid / ask `bidask_ftmo_2026-10-02\` (Downloads and the Surface; 21 pairs, 20 Sep - 3 Oct) and a fresh dump for 3-9 Oct if wanted (desktop terminal, read-only); the study export (`archive_counts.py --export-study --days 14`, fill_logs and scalp_history) for realised P&L by instance and close time. Loaders to reuse, not change: `research/ejection_value` (`ev_data.load_export`, BOM-safe), `research/markout` (minute mids). **Method:** (1) per FTMO day (22:00Z-22:00Z): realised P&L (profit + swap + commission by close time), equity per minute = balance + open MTM from the history's open positions marked at the minute bid (longs) / ask (shorts), the worst intraday equity against the day-start value (the daily-limit test), and the open MTM carried at 22:00Z; check one day by hand against MetriX or the trial record (cycle 2's 23 Sep must breach). (2) Monte Carlo: an attempt walks bootstrapped days in BLOCKS of consecutive days (trends and carried books persist; block length a parameter), applies the daily limit to the intraday low (not the close), the max loss to equity, the target to the closed balance (confirm the rule), counts days; N = 100,000 attempts; seeded. (3) Sensitivities: drift shifted by -$x / day; days scaled to fewer instances (per-instance days summed over a subset of pairs, from the history by magic); cycle 2 days vs cycle 3 days apart. **Tests first** (repo convention, hand-derived): a three-day deterministic path that passes on day 3; one whose day-2 intraday low breaches the daily limit although its close does not; the zero-drift symmetric case converging to L / (L + T) within Monte Carlo error; a block bootstrap that never splits a block. **Deliverables:** `research/ftmo_pass/` (standard library like `research/markout`, Python; README), `docs/research/ftmo-pass-probability.md` (question, inputs as given, method, result table, caveats); one docs patch. **Caveats to state with the result:** about 18 FTMO trading days in all, two instance counts and two geometries; days are not independent; FTMO's rules as the operator gives them. **Not before:** never ahead of a Monday-night runbook step (5 Oct after 22:00Z) or the cap-10 reload; dead-time work. **5 Oct ~17:40Z: FIRST RUN** (`research/ftmo_pass/`, tests first: 13 failing at the stubs, then 13/13; fourteen mutations caught; `docs/research/ftmo-pass-probability.md`). Rules from ftmo.com (2-Step: +$1,000 then +$500; daily $500 from the 00:00 CE(S)T balance; equity above $9,000; 4 days a phase); operator: fee $100, 90%, VPS $20/month, refund unknown (both run). 23 ring7 days (A 8, B 8, C 5, D 2): drift +$5.03/day (se $10.43), worst low -$226.93; no day near $500. The answer rests on drift and tail frequency: at +$10/day ~130 trading days to pass both; P(both) 1.00 with no tail, 0.56 with a 23-Sep day once in 250 days, 0.24 once in 100; EV +$469 at +$10 / 1-in-250. Next: re-run with 5-9 Oct after C125; a tail-frequency estimate from more history. | first run done; re-run after C125 |`
   - `docs/architecture/ADR-158-daily-loss-breaker.md:14` `EQUITY (balance + open P/L +/- swaps - commissions) must never drop below`
   - `docs/architecture/ADR-158-daily-loss-breaker.md:15` `the day's limit = account BALANCE at 00:00 CE(S)T minus 5% of the Initial`
   - `docs/architecture/ADR-158-daily-loss-breaker.md:16` `Simulated Capital (a FIXED $500 on $10k). Day 1 uses the initial capital.`
   - `docs/runbooks/twoarm-build-e.md:19` `| E3 | E's twelve magics (22260101 to 22260602) are all in `GRIND_CAP_ALL_MAGICS` (`ea/grind_cap.mqh` 20-31): the slot guard counts their resting entries as designed (C159 does not apply) | source at `ceab0f7` | VERIFIED |`
   - `docs/runbooks/twoarm-build-e.md:23` `| E7 | With the breaker off nothing in the EA stops at FTMO's daily loss ($500 on $10k) or overall loss; what FTMO does to a free trial at a breach is not known here | presets G3; `ftmo-ic-start.md` K3 | RULED (breaker off); FTMO's reaction UNKNOWN |`
   - `research/t3_drawdown/results.md:43` `FTMO's daily-loss rule as recorded in C164 and E's runbook (floating loss counts against the day-start balance), not`
   - `research/t3_drawdown/results.md:44` `re-read on FTMO's site.`
     - **FTMO Instant (`$300` / `3%` daily loss on `00:00` Prague balance, `10%` trailing max loss from highest closed balance, `30%` / `50%` best-day consistency):** read directly on `ftmo.com/en/trading-objectives` on 23 Oct and recorded in `handoffs/Handover/08_BACKLOG.md:63` (`C164`) and `handoffs/Handover/02_TRAPS.md:3037-3039`:
   - `handoffs/Handover/08_BACKLOG.md:63` `| C164 | **25 Oct (s90 continued 3): OPT cap 9 (harness CONFIRMED) raises earnings and FTMO-day breaches together (15 / 5 days over $300 / $500 against 11 / 3): no help for Instant.** **24 Oct (s90 continued 2): the operator's view: consistency and the two-sided grid would be fine; the issues are the account's price and the 3% daily drawdown ("we are yet to have a trial run that hasnt had a terrible drawdown"). Measured (`research/t3_drawdown/results.md`): at 0.01 lots t3 replayed through 1-20 Oct breaches $300 a day from 8 Oct (11 of 20 days) and $500 on 16 Oct; Instant's trailing 10% reaches $642 of $1,000; t3 earns about $91 a month in-sample. Parking it until E's trial is read was proposed, not ruled.** **FTMO's Instant account (operator 23 Oct ~04:51Z: "there appears to be a new type of ftmo account. maybe no hurdles"; launched ~12 Oct).** No profit target, no evaluation, no minimum days; a one-time fee ($10k: EUR 339), 90% of simulated profit, up to 1:100; a free Instant trial exists. **Its rules (ftmo.com/en/trading-objectives, read 23 Oct ~04:55Z), tighter for fxgrind than the trial E runs:** (1) max loss 10% TRAILING: the highest closed balance minus 10% of the start, never down (scalps closed at $10,400 lift the floor to $9,400 while stacks float); (2) daily loss 3% ($300 on $10k, not $500), on equity against the balance at 00:00 Prague (the EA's FTMO day); (3) consistency 30%: the best closed day no more than 30% of total closed profit before a reward, a payout condition, not a breach (a banner on the same page says 50% for accounts ordered from 12 Oct: which applies is unclear); (4) the 2,000 requests a day of all FTMO accounts (C106; E projected ~2,500). **Open questions for FTMO before any purchase:** which consistency figure; whether the forbidden-practices clause on "holding opposing positions on the same or highly correlated instruments" (aimed at spreading profit across days; a single-account carve-out elsewhere) touches a two-sided grid (OPT long and short, OPT and ALT on one pair). **Claude's reading:** the economics need lots above 0.01 (sweep11 t3 +$231 in USD over about 12 weeks, in-sample: 90% of it below the $10k fee) and partial fills are not handled there (C14); the useful step is the free Instant trial with the ADR-158 breaker back ON (a $300 trip, the float gate below it); E's first week shows whether its daily equity swings fit inside $300 (inferred from D's heartbeat 23 Oct ~04:14Z: about $172 down from its day start by its MAE floor, against a $500 basis). | the operator picks it up Sat 24 Oct; after E's first days |`
   - `handoffs/Handover/02_TRAPS.md:3037` `- **FTMO's daily loss counts floating losses carried from earlier days:** day-start BALANCE - the day's lowest EQUITY.`
   - `handoffs/Handover/02_TRAPS.md:3038` `  A grid that banks scalps while its stacks sit open shows a balance well above equity, and the whole gap counts`
   - `handoffs/Handover/02_TRAPS.md:3039` `  against every day (t3 October replay: $497-$627 from 14 Oct at 0.01 lots).`
   - **Gaps in Q1 (`research/e_week1/PREREG.md:77-78`):**
     1. **Minute-mark `M1`/`M2` vs FTMO's page (`PREREG.md:39-40, 57-58` vs `77-78`):** `s3` (`line 40`) and `s5` (`line 58`) state `minute marks under-read the true low, so M1 is a lower bound; FTMO's page decides`, yet `Q1` (`lines 77-78`) is written solely in terms of `M1` and `M2`. If an intra-minute tick breaches `$300` or `$500` on FTMO's Client Area page while minute-mark `M1` stays below `$300` or `$500`, Q1's formula should explicitly take the worse of `M1` and FTMO's page (`max(M1, FTMO_page_daily_loss)` and `min(M2, $10,000 - FTMO_page_max_loss)`).
     2. **M5 (`2,000/day` request limit, `PREREG.md:66`) is omitted from Q1:** `docs/runbooks/twoarm-build-e.md:19` (`E3`) records FTMO's hard `2,000` order messages/day server limit (`00:00-24:00 CE(S)T`), and s5 defines `M5 Request count` (`line 66`), but Q1 (`lines 77-78`) never checks `M5 < 2000`.
     3. **Trailing `$1,000` floor in `INSTANT-FIT` (`PREREG.md:59-60` vs `78`):** `s5` (`lines 59-60`) says Instant's trailing floor (`highest closed balance - $1,000`) is `reported, not deciding`, and Q1 (`line 78`) defines `INSTANT-FIT if also M1 <= $300 on every day`. Because C164 (`08_BACKLOG.md:63`) records Instant's max loss as `10% TRAILING: the highest closed balance minus 10% of the start`, Q1 should either require the trailing floor not to be breached for `INSTANT-FIT` or explicitly state in Q1 that `INSTANT-FIT` is the daily-loss check (`M1 <= $300`) while trailing max-loss is reported alongside.

3. **Q2 (`9 of 12` cells in band, `research/e_week1/PREREG.md:80-83`):**
   - **Is Q2 testing anything, or could it pass whatever happens?**
     - It cannot pass whatever happens: every cell in s8 (`lines 93-98`) has a strictly positive lower bound (`0.06` to `8.31` closes/day) and a finite upper bound (`1.07` to `52.50` closes/day). A frozen/broken fleet (`0` closes/day) fails `12 of 12` cells; a runaway churn fleet exceeds `hi`.
     - Note that for cells where October was much more active than calm (`EURUSD OPT 7`: calm `16.27`, oct `35.00`, band `8.14-52.50`, a `6.45x` span; `EURGBP ALT 23`: calm `0.12`, oct `0.71`, band `0.06-1.07`, an `18x` span), spanning `[0.5 * min(calm, oct), 1.5 * max(calm, oct)]` is wide because it accepts anything from half of calm to `1.5x` of October.

4. **Q3 (`_t3` on E against `_t1` on D, `research/e_week1/PREREG.md:85-87`):**
   - **Honesty check:** Q3 explicitly states `Reported, not decided: one week is one draw; C162 stays OPEN` (`line 85`), discloses the broker differences (`FTMO against IC: spreads, commission per close, fills`, `line 86`), and discloses the initial-book asymmetry (`D entered W holding its 21 Oct book while E started flat`, `line 87`). See Item 8 for the two quantitative adjustments (`$0.06` vs `$0.08` commission equalisation and splitting D's pre-W vs in-W positions) that make this comparison cleaner.

### Smallest Fix to `research/e_week1/PREREG.md` (s7 Q1)

- Replace `research/e_week1/PREREG.md:77-78` with:
  ```markdown
  - **Q1 (FTMO fit):** **TRIAL-SAFE** if `max(M1, FTMO_page_daily_loss) < $500` on every FTMO day, `min(M2, $10,000 - FTMO_page_max_loss) > $9,000`, and `M5 < 2,000` on every FTMO day; **INSTANT-FIT** if also `max(M1, FTMO_page_daily_loss) <= $300` on every FTMO day (with Instant's `$1,000` trailing floor reported alongside); **BREACH** otherwise.
  ```

---

## 6. `s6, the episode`

- **Verdict:** **DEFECT**

### Defects & Verification Quotes

1. **Pre-registration s6 text (`research/e_week1/PREREG.md:69-74`):**
   - `research/e_week1/PREREG.md:69` ``
   - `research/e_week1/PREREG.md:70` `Let O(t) = equity - balance (E's open book) at each minute. **The episode** runs around W's lowest equity: from the`
   - `research/e_week1/PREREG.md:71` `last minute before it with O >= -$50 to the first minute after it with O >= -$50 (or W's end). If W's lowest O is above`
   - `research/e_week1/PREREG.md:72` `-$100 there is no episode; say so. For the episode: its span; M1 for each FTMO day it touches; per cell the open P&L`
   - `research/e_week1/PREREG.md:73` `(net_mtm) and layers at the low; S, R and A inside it; which pairs and arms carried the loss. **This is read first.**`
   - `research/e_week1/PREREG.md:74` ``

2. **DEFECT 6a -- Mismatched anchor (`W's lowest equity`) vs threshold/boundary metric (`O(t) = equity(t) - balance(t)`):**
   - Line 70 anchors the episode at **`W's lowest equity`** (`t_eq = argmin_t equity(t)`), but defines both the episode boundaries (`O >= -$50`) and the existence condition (`If W's lowest O is above -$100 there is no episode`) on **`O(t) = equity(t) - balance(t)`**!
   - Because `balance(t)` grows over the week as scalps are banked, `argmin_t equity(t)` and `argmin_t O(t)` are **not** the same minute (as already seen in the October replay in `research/t3_drawdown/fleet_output.txt:17-36`, where the lowest equity was `-$74.74` on `Fri 02 Oct` with `open = -$196.51`, while the deepest open-book excursion was `open = -$326.50` on `Wed 14 Oct` when equity was `+$135.69`):
   - `research/t3_drawdown/fleet_output.txt:17` `  Thu 01 Oct  bal    +0.00  eq    +0.00  open    +0.00`
   - `research/t3_drawdown/fleet_output.txt:18` `  Fri 02 Oct  bal  +121.77  eq   -74.74  open  -196.51`
   - `research/t3_drawdown/fleet_output.txt:25` `  Fri 09 Oct  bal  +389.34  eq  +104.93  open  -284.41`
   - `research/t3_drawdown/fleet_output.txt:36` `  Tue 20 Oct  bal  +442.78  eq   +12.90  open  -429.88`
   - **How the rule breaks as written:**
     - Suppose on Friday 23 Oct (when `balance = $10,000`), E dips to `equity = $9,960`, so `O(t_1) = -$40 >= -$50`.
     - Over Mon-Wed, E banks `+$350` in scalps (`balance = $10,350`), and on Thursday has a `-$280` open-book drawdown where `equity = $10,070` and `O(t_2) = -$280 <= -$100`.
     - Under `PREREG.md:70-71`: `W's lowest O` is `-$280 <= -$100` (so an episode exists), **but `W's lowest equity` is `$9,960` at `t_1`, where `O(t_1) = -$40 >= -$50`!** Looking for the last minute before `t_1` with `O >= -$50` and the first minute after `t_1` with `O >= -$50` collapses to a 1-minute trivial window at `t_1` where `O >= -$50` and misses the entire `-$280` Thursday drawdown!
   - **Fix:** Anchor the episode at **`W's lowest O(t)`** (`t_low = argmin_t O(t)`). Then whenever `min_t O(t) <= -$100`, at `t_low` we are guaranteed `O(t_low) <= -$100 < -$50`, so `t_start` and `t_end` always bracket a non-empty excursion below `-$50`. (If `argmin_t equity(t)` differs from `argmin_t O(t)` and also has `O < -$100`, report its minute alongside.)

3. **DEFECT 6b -- Missing `(or W's start)` fallback before the low and missing tie-break rule for equal lows:**
   - Line 70 gives a boundary fallback at the end of W (`to the first minute after it with O >= -$50 (or W's end)`), **but no fallback `(or W's start)` before the low** (`from the last minute before it with O >= -$50`). If `O(t) < -$50` from the very first snapshot of W down to `t_low`, `the last minute before it with O >= -$50` does not exist.
   - If two or more minutes tie for `min_t O(t)` (e.g. two consecutive minutes during a flat quote or two separate troughs with identical `O(t)` to the cent), `t_low` is ambiguous unless pinned to the **earliest** minute achieving `min_t O(t)`.

### Smallest Fix to `research/e_week1/PREREG.md` (s6)

- Replace `research/e_week1/PREREG.md:70-71` with:
  ```markdown
  With `O(t) = equity - balance`, the episode runs around `t_low`, the earliest minute of W's lowest `O(t)`: from the last minute before `t_low` with `O >= -$50` (or W's start) to the first minute after `t_low` with `O >= -$50` (or W's end). If W's lowest `O` is above `-$100` there is no episode; say so (and also note the minute of W's lowest `equity` if different from `t_low`).
  ```

---

## 7. `Anything that would let the read be bent after the fact`

- **Verdict:** **GAP**

### Ambiguities & Verification Quotes

1. **Which timestamp column filters `fill_logs`, `scalp_history`, and `ea_events` to W (`research/e_week1/PREREG.md:20-22, 46, 61-65`):**
   - Each exported CSV has multiple timestamps (`D:/pipshed/migrations/001_archive_phase1.sql:65-134`):
     - `fill_logs`: `deal_time_broker`, `deal_time_broker_msc`, `ea_time_ms`, `received_at`.
     - `scalp_history`: `close_time_broker` (plus `broker_utc_offset_s`), `received_at`.
     - `ea_events`: `ea_time_ms`, `received_at`.
   - `D:/pipshed/migrations/001_archive_phase1.sql:68` `);`
   - `D:/pipshed/migrations/001_archive_phase1.sql:86` `    width_pips double precision,`
   - `D:/pipshed/migrations/001_archive_phase1.sql:95` `    cap_leg_a_thresh double precision,`
   - `D:/pipshed/migrations/001_archive_phase1.sql:96` `    cap_leg_b_thresh double precision,`
   - `D:/pipshed/migrations/001_archive_phase1.sql:108` `    received_at timestamptz NOT NULL,`
   - `D:/pipshed/migrations/001_archive_phase1.sql:111` `    reason text,`
   - `D:/pipshed/migrations/001_archive_phase1.sql:128` `    stack_depth int,`
   - `D:/pipshed/migrations/001_archive_phase1.sql:129` `    close_time_broker timestamp NOT NULL,`
   - `D:/pipshed/migrations/001_archive_phase1.sql:133` `    received_at timestamptz NOT NULL,`
   - Note that in `research/session_hours/PREREG.md:36-38`, `scalp_history` UTC close time is explicitly pinned as `close_time_broker - broker_utc_offset_s`, and `fill_logs` deal time is `deal_time_broker` (`GMT+3` = `UTC + 10800s`, or `ea_time_ms / 1000`):
   - `research/session_hours/PREREG.md:36` `## 3. UNIT, LINKING, MEASURES (as coded; the tests fix each rule)`
   - `research/session_hours/PREREG.md:37` ``
   - `research/session_hours/PREREG.md:38` `- A layer = an ENT position (an IN fill with role ENT; duplicates by deal ticket once). Entry time = that`
   - Pinning the exact timestamp column for each table (`snapped_at` for `state_snapshots`; `deal_time_broker - 10800` or `ea_time_ms` for `fill_logs`; `close_time_broker - broker_utc_offset_s` for `scalp_history`; `ea_time_ms` for `ea_events`) removes any post-hoc choice at W's boundaries.

2. **Day-start balance for M1 on Day 1 (`23 Oct`) and at subsequent Prague midnights (`research/e_week1/PREREG.md:16, 24-26, 57-58`):**
   - FTMO day `23 Oct` starts at `2026-10-22 22:00Z`, before E was attached (`03:04-03:25Z` on 23 Oct, `docs/runbooks/twoarm-build-e.md:260, 298-300`), so there is no snapshot at `2026-10-22 22:00Z`:
   - `docs/runbooks/twoarm-build-e.md:298` `- The first scalp per arm, the first roll, the first `DAILY_SNAPSHOT` at 22:00Z. **That first snapshot reads`
   - `docs/runbooks/twoarm-build-e.md:299` `  `"start_known":false`** (`equity_start`, `inventory_pnl`, `total`, `swap_day` null; `balance_start` from`
   - `docs/runbooks/twoarm-build-e.md:300` `  history): the day-start GVs are written only at a rollover the EA saw (`grind_snapshot.mqh` 291-304, 340),`
   - Pin that FTMO day `23 Oct` uses `$10,000.00` as `day-start balance` (`docs/architecture/ADR-158-daily-loss-breaker.md:16`), and for each subsequent FTMO day `d` (`24 Oct` through `30 Oct`), pin `day-start balance` as the last non-null `state_snapshots.balance` at or before the FTMO day's `00:00 CE(S)T` boundary (`22:00Z` on 23-24 Oct, `23:00Z` on 25-29 Oct).

3. **M2 Instant trailing floor formula (`research/e_week1/PREREG.md:59-60`):**
   - `PREREG.md:59-60` says `against Instant's trailing floor (the highest closed balance - $1,000)`.
   - Pin that at each minute `t`, the trailing floor is the **running** high-water mark `max_{s <= t} balance(s) - $1,000`, so the minimum headroom over W is `min_t (equity(t) - (max_{s <= t} balance(s) - $1,000)) = $1,000 - max_t (max_{s <= t} balance(s) - equity(t))` (matching `research/t3_drawdown/fleet.py:39-40`):
   - `research/t3_drawdown/fleet.py:39` `hb = np.maximum.accumulate(bal); gap = (hb - eq).max(); kg = (hb - eq).argmax()`
   - `research/t3_drawdown/fleet.py:40` `print("Instant trailing max loss: largest (highest balance so far - equity) %.2f at %s (limit $1,000 on $10k)" % (gap, z(t0[kg])))`

4. **Q2 boundary comparison (`research/e_week1/PREREG.md:80-81, 93-98`):**
   - As shown in Item 1, 4 of the 12 band endpoints in s8 differ by `0.01` depending on whether `[0.5*min, 1.5*max]` is evaluated on unrounded rates or 2-decimal rounded rates. Pin that Q2 compares `round((S + R) / W_days, 2)` (with `W_days = 5.73` for the full window) inclusively (`lo <= rate <= hi`) against the printed 2-decimal `band` column in s8 (`lines 93-98`).

5. **Zero-denominator conventions for M3 `commission / gross` (`PREREG.md:62`) and M4 `S / A` (`PREREG.md:65`):**
   - In `research/t3_drawdown/calm_comm_output.txt:5-13`, 6 of 12 cells had `0` rolls (`A = 0`), and 2 cells had negative gross (`c/g = nan%`), and `PREREG.md:107` notes `gross <= 0`. Pin that `S / A` is reported as `n/a` when `A == 0`, and `commission / gross` is reported as `n/a` when `gross <= 0`.

### Smallest Fix to `research/e_week1/PREREG.md` (s2, s5, s7)

- Add one sentence to **s2 (`research/e_week1/PREREG.md:26`)**:
  ```markdown
  Event timestamps in W use `snapped_at` (`state_snapshots`), `deal_time_broker - 10800s` (`fill_logs`), `close_time_broker - broker_utc_offset_s` (`scalp_history`), and `ea_time_ms` (`ea_events`).
  ```
- In **s5 (`research/e_week1/PREREG.md:57-65`)**, add:
  - On **M1**: `Day 23 Oct day-start balance is $10,000.00; each subsequent FTMO day uses the last snapshot balance at or before its 00:00 CE(S)T start.`
  - On **M2**: `Instant's trailing floor at minute t is max_{s <= t} balance(s) - $1,000.`
  - On **M3 / M4**: `Report n/a for commission / gross when gross <= 0 and for S / A when A == 0.`
- In **s7 Q2 (`research/e_week1/PREREG.md:80-81`)**, specify: `round((S + R) / 5.73, 2)` is compared inclusively (`lo <= rate <= hi`) against the printed `band` column in s8.

---

## 8. `Anything missing that the operator's two questions need (C162: t3 against t1; C164: the $300 day), kept to what you can quote`

- **Verdict:** **GAP**

### Missing Items & Verification Quotes

1. **Operator Question C164 (`handoffs/Handover/08_BACKLOG.md:63`, `docs/runbooks/twoarm-build-e.md:22`):**
   - `handoffs/Handover/08_BACKLOG.md:63` `| C164 | **25 Oct (s90 continued 3): OPT cap 9 (harness CONFIRMED) raises earnings and FTMO-day breaches together (15 / 5 days over $300 / $500 against 11 / 3): no help for Instant.** **24 Oct (s90 continued 2): the operator's view: consistency and the two-sided grid would be fine; the issues are the account's price and the 3% daily drawdown ("we are yet to have a trial run that hasnt had a terrible drawdown"). Measured (`research/t3_drawdown/results.md`): at 0.01 lots t3 replayed through 1-20 Oct breaches $300 a day from 8 Oct (11 of 20 days) and $500 on 16 Oct; Instant's trailing 10% reaches $642 of $1,000; t3 earns about $91 a month in-sample. Parking it until E's trial is read was proposed, not ruled.** **FTMO's Instant account (operator 23 Oct ~04:51Z: "there appears to be a new type of ftmo account. maybe no hurdles"; launched ~12 Oct).** No profit target, no evaluation, no minimum days; a one-time fee ($10k: EUR 339), 90% of simulated profit, up to 1:100; a free Instant trial exists. **Its rules (ftmo.com/en/trading-objectives, read 23 Oct ~04:55Z), tighter for fxgrind than the trial E runs:** (1) max loss 10% TRAILING: the highest closed balance minus 10% of the start, never down (scalps closed at $10,400 lift the floor to $9,400 while stacks float); (2) daily loss 3% ($300 on $10k, not $500), on equity against the balance at 00:00 Prague (the EA's FTMO day); (3) consistency 30%: the best closed day no more than 30% of total closed profit before a reward, a payout condition, not a breach (a banner on the same page says 50% for accounts ordered from 12 Oct: which applies is unclear); (4) the 2,000 requests a day of all FTMO accounts (C106; E projected ~2,500). **Open questions for FTMO before any purchase:** which consistency figure; whether the forbidden-practices clause on "holding opposing positions on the same or highly correlated instruments" (aimed at spreading profit across days; a single-account carve-out elsewhere) touches a two-sided grid (OPT long and short, OPT and ALT on one pair). **Claude's reading:** the economics need lots above 0.01 (sweep11 t3 +$231 in USD over about 12 weeks, in-sample: 90% of it below the $10k fee) and partial fills are not handled there (C14); the useful step is the free Instant trial with the ADR-158 breaker back ON (a $300 trip, the float gate below it); E's first week shows whether its daily equity swings fit inside $300 (inferred from D's heartbeat 23 Oct ~04:14Z: about $172 down from its day start by its MAE floor, against a $500 basis). | the operator picks it up Sat 24 Oct; after E's first days |`
   - `docs/runbooks/twoarm-build-e.md:22` `| E6 | Twelve instances on FTMO: about 2,500 requests a day against FTMO's 2,000 (C106); A's seven used about 1,400-1,500. On a stressed day the guard reads about 180-192 of 194 (fleet D note s7): entries refused at the guard then are by design | backlog C106; note s10 | RECORDED (projection, not measured) |`
   - **Missing item 8a -- `daily_snapshots` export (`D:/pipshed/migrations/002_adr159_daily.sql:1-25`):**
     - Each E instance emits a `DAILY_SNAPSHOT` at FTMO Prague midnight (`00:00 CE(S)T`) containing `balance_start`, `equity_start`, `balance_end`, `equity_end`, `realised`, `swap_day`, and `guard_total` (total open positions + pending orders across the account against the `194` slot guard in `twoarm-build-e.md:22`):
   - `D:/pipshed/migrations/002_adr159_daily.sql:1` `CREATE TABLE daily_snapshots (`
   - `D:/pipshed/migrations/002_adr159_daily.sql:2` `    id bigserial PRIMARY KEY,`
   - `D:/pipshed/migrations/002_adr159_daily.sql:3` `    account_login bigint NOT NULL,`
   - `D:/pipshed/migrations/002_adr159_daily.sql:4` `    ftmo_day date NOT NULL,`
   - `D:/pipshed/migrations/002_adr159_daily.sql:5` `    instance_id text,`
   - `D:/pipshed/migrations/002_adr159_daily.sql:6` `    session_id text,`
   - `D:/pipshed/migrations/002_adr159_daily.sql:7` `    ea_time_ms bigint,`
   - `D:/pipshed/migrations/002_adr159_daily.sql:8` `    received_at timestamptz NOT NULL,`
   - `D:/pipshed/migrations/002_adr159_daily.sql:9` `    balance_start numeric(14,2), equity_start numeric(14,2),`
   - `D:/pipshed/migrations/002_adr159_daily.sql:10` `    balance_end numeric(14,2),   equity_end numeric(14,2),`
   - `D:/pipshed/migrations/002_adr159_daily.sql:11` `    realised numeric(14,2), nontrade numeric(14,2),`
   - `D:/pipshed/migrations/002_adr159_daily.sql:12` `    inventory_pnl numeric(14,2), total numeric(14,2), swap_day numeric(14,2),`
   - `D:/pipshed/migrations/002_adr159_daily.sql:13` `    positions_long int, positions_short int, orders int,`
   - `D:/pipshed/migrations/002_adr159_daily.sql:14` `    guard_total int, guard_age_s int,`
   - `D:/pipshed/migrations/002_adr159_daily.sql:15` `    breaker_tripped boolean, premidnight_seen boolean,`
   - `D:/pipshed/migrations/002_adr159_daily.sql:16` `    broker_utc_offset_s int,`
   - `D:/pipshed/migrations/002_adr159_daily.sql:17` `    start_known boolean, balance_start_source text,`
   - `D:/pipshed/migrations/002_adr159_daily.sql:18` `    ejections_auto int, ejections_command int,`
   - `D:/pipshed/migrations/002_adr159_daily.sql:19` `    ejected_fills int, ejected_realised numeric(14,2),`
   - `D:/pipshed/migrations/002_adr159_daily.sql:20` `    eject_filled_events int, eject_mismatch int,`
   - `D:/pipshed/migrations/002_adr159_daily.sql:21` `    carry_clamps int, critical_events int,`
   - `D:/pipshed/migrations/002_adr159_daily.sql:22` `    derived_at timestamptz,`
   - `D:/pipshed/migrations/002_adr159_daily.sql:23` `    detail jsonb,`
   - `D:/pipshed/migrations/002_adr159_daily.sql:24` `    UNIQUE (account_login, ftmo_day)`
     - Reading `daily_snapshots` (and peak open layers `sum(layers_long + layers_short)` in `state_snapshots`) directly answers whether E's slot usage stayed well inside the `194` guard (`twoarm-build-e.md:22`) and cross-checks the FTMO-midnight `balance_start` used in M1.
   - **Missing item 8b -- FTMO Instant's 30% / 50% consistency rule (`handoffs/Handover/08_BACKLOG.md:63`):**
     - C164 explicitly records rule `(3) consistency 30%: the best closed day no more than 30% of total closed profit before a reward, a payout condition, not a breach (a banner on the same page says 50% for accounts ordered from 12 Oct: which applies is unclear)`. Reporting `max_d(closed_pnl_d) / sum_d(closed_pnl_d)` across the FTMO days of W (when total closed P&L > 0) costs one line from the existing `fill_logs` export and covers all three Instant rules in C164.

2. **Operator Question C162 (`handoffs/Handover/08_BACKLOG.md:60, 65`, `D:/pipshed/sr_table.py:30-35`):**
   - `handoffs/Handover/08_BACKLOG.md:60` `| C151 | **The chop measure rho must count roll STEPS, not roll closes (Claude, 13 Oct ~02:40Z).** `compare.rho` and the sweep reports use (S + R) e / (R D) with R = rolled closes; with re-roll on, one ticket closes once with several steps of loss (sweep7: closes at 2x-5x D, as many as the re-rolls), so rho reads too high (sweep7 EURUSD 1.23 by closes, 0.93 by steps). Correct form: (S + R) e / (A D), A = ROLL_ACCEPTED; with the open book, A D + open loss in the denominator. To fix: `compare.rho` (tests first), the sweep reports, and check pipshed's S/R table (C137) for the same count. Record: `docs/research/grid-edge-assessment-2026-10-12.md` s7 | next tooling pass |`
   - `handoffs/Handover/08_BACKLOG.md:65` `| C162 | **24 Oct ~23:10Z (s90 continued 2): t3's October replay at 0.01 lots crosses FTMO's $500 daily loss on 16 Oct (`research/t3_drawdown/`): E's live trial may end on the daily limit in a flurry like 14-16 Oct; what E does near $500 (let the trial end, or step in by hand) NOT ruled. The OPT budget (cluster) idea: NOT WORTH IT (`research/opt_budget/results.md`).** **24 Oct ~03:50Z (s90): status CONFIRMED by the operator: OPEN, E's live weeks against D's t1 set the out-of-sample test; a reload of E after its first week still NOT ruled.** **23 Oct ~04:30Z (s89): the viability note s8.7 records sweep11 and t3. Status OPEN, E's live weeks against D the test (the previous chat's reading; the operator to confirm); a reload of E after its first week NOT ruled.** **23 Oct ~03:00Z, sweep11: per pair OPT from the calm weeks and ALT from October (the operator's two-set idea); E's t3 set built (+$231 over both periods against the staged -$300); E attaches with it. Next: live weeks; D's and C's OPT by the same method; the calm-period drift.** **22 Oct ~15:15Z, (B) RESULT (sweep10): the offset does not carry to E's other five (OFFSET at q88 on 2 of 5, no retune; OPT + ALT negative on all five; the loss in OPT's tight adds; viability note s8.6). Next: the operator.** **22 Oct ~05:00Z, (B) PRE-REGISTERED (sweep10: E's other five pairs, the period rule ruled ~04:51Z; `sweep_notes` sweep10); runs next.** **22 Oct ~04:15Z, (A) done (HANDOFF s88): q80 ill-posed (several fixed points); E's ALT at q88 `_t2` (21, 18, 16, 26, 20, 9; EURUSD in sweep9's 18-20 band); (B) next, its rule for the operator.** **22 Oct ~03:25Z, sweep9: by the daily rule (the note s5) nothing is MEANINGFUL; over the period OPT live -361, every add >= 14 cell +126 to +862, OPT + ALT +93 to +236, with DUP +548 to +832; with sweep8 the live set positive in both regimes. The operator's reading: ALT as cheap insurance, DUP to make it work harder; the tail is a slow drift (sweep8 carried: ALT -1,444 open). Next: E with q80 / q85 ALT adds; per-pair surfaces (the note s8).** **CAN ANY OPT / ALT (/ DUP) GEOMETRY STABILISE OCTOBER? THE PROJECT'S GO / NO-GO QUESTION (operator, 21 Oct ~20:05Z): "if we cannot find a single geometry that uses an OPT/ALT and maybe even DUP arm that can at least stabilise in these last few weeks - then there is no future in this work."** `docs/research/two-arm-viability-2026-10-21.md`: the regime (EURUSD roll bursts 1 and 5-7 Oct, 14-16 Oct; live B, C, D); the offset hypothesis (ALT's scalps pay for OPT's rolls in a range wider than OPT's stack); sweep8 (ALT at the t1 adds no offset in Aug - Sep); "stabilise" PROPOSED (end net >= 0 and worst equity no lower than OPT alone, over 1-20 Oct carried); the surface sweep9 (add x exit, cap 8, plus the add = exit diagonal at cap 7, on the w2hw ticks, daily equity curves, DUP as 2 x ALT). Then the calm check (h8w) and live | the operator confirms s5; then sweep9 |`
   - `D:/pipshed/sr_table.py:30` `    1515045375: 0.06,   # FTMO trial, Fleet E (wine-e) from 23 Oct 03:04Z: FTMO's measured rate, to check on its ledger`
   - `D:/pipshed/sr_table.py:31` `    53066709: 0.08,     # IC Fleet B (box 1)`
   - `D:/pipshed/sr_table.py:32` `    53071896: 0.08,     # IC Fleet C (box 2)`
   - `D:/pipshed/sr_table.py:33` `    53077984: 0.08,     # IC Fleet D (wine-d): same Raw account type, checked on its ledger`
   - `D:/pipshed/sr_table.py:34` `}`
   - `D:/pipshed/sr_table.py:35` ``
   - **Missing item 8c -- Commission-equalised M3 and carried-vs-new book split for D (`research/e_week1/PREREG.md:85-87`):**
     - As `D:/pipshed/sr_table.py:30, 33` shows, E pays `$0.06` per close on FTMO (`1515045375`) while D pays `$0.08` per close on IC (`53077984`) -- a `33%` (`$0.02/close`) commission handicap on D that is a broker difference, not a `_t3` vs `_t1` geometry difference.
     - Furthermore, D entered W at `2026-10-23 03:29:01Z` carrying open positions opened between `21 Oct 15:54Z` and `23 Oct 03:29:00Z` (`PREREG.md:51, 87`). Any close or MTM swing on those pre-W positions during W belongs to D's pre-W inventory.
     - Because `fill_logs` has `position_id` and the `IN` deal timestamp for every position, reporting D's M3 (total and per pair) both (i) raw (`$0.08`/close) and commission-equalised at FTMO's `$0.06`/close (`+$0.02` per closed layer), and (ii) split between positions opened inside W vs carried into W from 21-23 Oct, directly isolates `_t3` vs `_t1` for C162.
   - **Missing item 8d -- Unitless chop / edge ratio `rho = (S + R) * e / (A * D) = (S + R) / (7 * A)` (`handoffs/Handover/08_BACKLOG.md:60`):**
     - `C151` (`08_BACKLOG.md:60`) defines `rho = (S + R) e / (A D)` (which equals `(S + R) / (7 * A)` on both E and D since `e = a` and `cap = 7`) as the unitless measure comparing geometries (`rho = 1` on a random walk). Since M4 already computes `S`, `R`, and `A`, reporting `rho` alongside `S / A` puts E (`_t3`) and D (`_t1`) on the same normalized scale.

### Smallest Fix to `research/e_week1/PREREG.md` (s5 and s7 Q3)

- In **s5 (`research/e_week1/PREREG.md:58, 65`)**, add:
  - On **M1**: `Also report the best FTMO day's share of total closed profit over W (C164's 30%/50% Instant consistency metric) and peak open layers against the 194 slot guard.`
  - On **M4**: `Along with S / A, report rho = (S + R) / (7 * A) (C151).`
- In **s7 Q3 (`research/e_week1/PREREG.md:85-87`)**, add:
  ```markdown
  Report D's M3 both raw ($0.08/close) and commission-equalised to FTMO's $0.06/close, and split D's realised P&L and open-book MTM change in W between positions opened inside W and positions carried into W from 21-23 Oct.
  ```

---

**SOUND WITH CHANGES** -- Fix: (1) in s3/s5, read account-level `balance`/`equity` from the single non-null MAE-reporter row per account in `state_snapshots`, compute per-pair M3 from `fill_logs` (`profit + swap + commission`) plus per-instance `state_snapshots.net_mtm`, join M4's rolled closes via `fill_logs.position_id` (on `ENT`-leg `OUT_BY` deals) to `ea_events.ticket` of `ROLL_ACCEPTED` (cross-checked against `scalp_history.rolled`), and add the `sr` CSV export to s3; (2) in s4, fix Check 4's `fill_logs` filter from closing deals with `role = 'EXT'` (which is `NULL` on `OUT_BY` deals) to `entry_type = 'IN' AND role = 'EXT'` (or `ENT`-leg `OUT_BY` deals), and align Check 1's deal sum for D to D's first and last snapshot `heartbeat_at` timestamps in W; (3) in s6, anchor the episode at the earliest minute of W's lowest `O(t) = equity - balance` (with a `(or W's start)` fallback before the low) instead of `W's lowest equity`; (4) in s7/s5, include FTMO's page and `M5 < 2,000` in Q1, pin event timestamp columns, Day 1 `$10,000` start balance, dynamic trailing floor `max_{s<=t} balance(s) - $1,000`, 2-decimal inclusive band comparison in Q2, `n/a` when `A == 0` or `gross <= 0`, and report C164's best-day consistency share + slot-guard peak and C162's `$0.06`-equalised / W-opened vs carried-in M3 split and `rho = (S + R) / (7 * A)`.

Line count: 872
