This message has a line count at the bottom

# ARGON: SECOND REVIEW OF THE AUDCAD OUT-OF-SAMPLE PRE-REGISTRATION (AMENDED)

| | |
|---|---|
| Reviewer | Argon |
| Date | 2026-11-11 |
| Branch | `review/argon-audcad-oos-2` |
| Base commit (`origin/main`) | `f067c6e4553dfbaf13160ed7fbedac26bddd739b` |
| Target document | `research/audcad_oos/PREREG.md` (lines 1-111) |
| Prompts | `prompts/argon_review_audcad_oos_2.md` (lines 1-41), `prompts/argon_review_audcad_oos.md` (lines 1-52) |
| Files read at `origin/main` | `research/audcad_oos/PREREG.md` (lines 1-111); `reviews/fable_pass1/report_pass1.md` (lines 1-1069); `reviews/fable_pass1/core.py` (lines 1-337); `reviews/fable_pass1/common.py` (lines 1-127); `reviews/fable_pass1/04_ladder_bars.py` (lines 1-102); `reviews/fable_pass1/01_null_calibration.py` (lines 1-50); `reviews/fable_pass1/test_core.py` (lines 1-49); `reviews/fable_pass1/out/04_ladder_tables_cont.txt` (lines 1-480); `reviews/fable_pass1/out/04_ladder_tables_one.txt` (lines 1-480); `reviews/fable_pass1/MANIFEST.md` (lines 1-72); `reviews/fable_pass1/00_data_summary.py` (lines 1-35); `reviews/fable_pass1/04b_ladder_tables.py` (lines 1-75); `reviews/fable_pass1/08_summary.py` (lines 1-170); `reviews/fable_pass1/out/00_data_summary.txt` (lines 1-60); `reviews/fable_pass1/out/01_null_calibration.txt` (lines 1-26); `research/fills/results.md` (lines 1-46); `scripts/grind_bar_dump.mq5` (lines 1-101); `handoffs/Handover/02_TRAPS.md` (lines 3020-3120) |
| Bar files opened | None |

---

## 1. THE FIVE AMENDMENTS

### Amendment 1: s6 rule 3 (years with 6+ months, ceil(0.6 x Y) of them positive; a year's net the sum of its monthly nets)

- **Verdict:** **CONFIRMED**

#### Evidence (`origin/main`)
- research/audcad_oos/PREREG.md:26 `  2020-01-01 or earlier; otherwise an IC Markets demo login on the same terminal. **At least 36 calendar months** are`
- research/audcad_oos/PREREG.md:61 `   below low or open / close outside [low, high]; no negative spread; **at least 15,000 bars in every month`
- research/audcad_oos/PREREG.md:62 `   counted** (a month with fewer is dropped and listed). Reported: first and last bar, bars per year, months covered,`
- research/audcad_oos/PREREG.md:78 `3. **At least ceil(0.6 x Y) of the Y calendar years** with 6 or more months in the file have a positive region net`
- research/audcad_oos/PREREG.md:79 `   (Y = 5: 3; Y = 4: 3; Y = 3: 2); a year's region net is the sum of its monthly region nets.`
- reviews/fable_pass1/04_ladder_bars.py:40 `    eq = real + openp`
- reviews/fable_pass1/04_ladder_bars.py:41 `    d = np.diff(np.r_[0.0, eq])`
- reviews/fable_pass1/04_ladder_bars.py:44 `    usd = d * USD[pair]`
- reviews/fable_pass1/04_ladder_bars.py:45 `    net = usd - COMM * dc`
- reviews/fable_pass1/04_ladder_bars.py:48 `    ypos = sum(1 for y in np.unique(years) if net[years == y].sum() > 0)`

#### Assessment
This amendment is right and complete. Because s2 permits a file with 36 to 60 calendar months and s4 c drops any month with fewer than 15,000 bars, the number of calendar years with at least 6 counted months is `Y in {3, 4, 5}`. Requiring `ceil(0.6 x Y)` positive years (`3` of `5`, `3` of `4`, `2` of `3`) and defining each year's region net as the sum of its monthly region nets matches `summarise` in `reviews/fable_pass1/04_ladder_bars.py` (lines 40-48) and prevents a stub year from deciding rule 3.

---

### Amendment 2: s3 (`ladder` call and the 0.2 pip sensitivity as "net minus 0.4 pip x 0.0714 USD per close")

- **Verdict:** **CONFIRMED**

#### Evidence (`origin/main`)
- research/audcad_oos/PREREG.md:46 `- **Sensitivity:** every fill 0.2 pip worse at its own price: net minus 0.4 pip x 0.0714 USD per close (entry and`
- reviews/fable_pass1/04_ladder_bars.py:34 `        o = ladder(bid, ask, tod, per, nper, w, a, x, strd, 2.0, cap, True, 0, 50, False, C0, ONE)`
- reviews/fable_pass1/core.py:92 `def ladder(bid, ask, tod_min, period, nper, width, add, exit_, stranded, deadband, cap,`
- reviews/fable_pass1/core.py:93 `           reroll, gate, max_reroll_tick, mkt_fill=False, clog=np.zeros((0, 7)), one_add=False):`
- reviews/fable_pass1/core.py:126 `        while j < nl[0]:                                  # longs: sell limit at xp, filled when bid >= xp`
- reviews/fable_pass1/core.py:127 `            if b >= xp[0, j] - EPS:`
- reviews/fable_pass1/core.py:128 `                fx = xp[0, j]; nfill += 1`
- reviews/fable_pass1/core.py:129 `                if mkt_fill and b > fx:`
- reviews/fable_pass1/core.py:130 `                    impr += (b - fx) / PIP`
- reviews/fable_pass1/core.py:131 `                    fx = b`
- reviews/fable_pass1/core.py:132 `                pnl = (fx - ent[0, j]) / PIP`
- reviews/fable_pass1/core.py:146 `        while j < nl[1]:                                  # shorts: buy limit at xp, filled when ask <= xp`
- reviews/fable_pass1/core.py:147 `            if a <= xp[1, j] + EPS:`
- reviews/fable_pass1/core.py:148 `                fx = xp[1, j]; nfill += 1`
- reviews/fable_pass1/core.py:172 `                        p = l0[s]; nfill += 1`
- reviews/fable_pass1/core.py:189 `                        tgt = apx[s]; nfill += 1`
- reviews/fable_pass1/core.py:205 `                    tgt = _add_target(ent[s], eff[s], rolled[s], order[s], nl[s], is_long, A)`
- reviews/fable_pass1/core.py:215 `                    ent[s, k] = tgt; eff[s, k] = tgt; rolled[s, k] = False`
- reviews/fable_pass1/report_pass1.md:668 `     adjustment: net + 2 x d x closes x USD-per-pip. Range over the four bar variants. This assumes the broker passes the`

#### Assessment
This amendment is right and complete:
1. `research/audcad_oos/PREREG.md` (lines 41-43) specifies the exact 17-argument call `ladder(bid, ask, tod, per, nper, w, a, x, s, 2.0, 7, True, 0, 50, False, C0, ONE)` matching line 34 of `reviews/fable_pass1/04_ladder_bars.py`.
2. In `reviews/fable_pass1/core.py` (lines 126-219), when `mkt_fill=False`, every exit fill sets `fx = xp[0, j]` (line 128) or `fx = xp[1, j]` (line 148), every L0 entry sets `p = l0[s]` (line 172), and every add entry sets `ent[s, k] = tgt` (lines 189, 205, 215). Widening `bid` and `ask` would not worsen the fill price of any triggered limit order; deducting `0.4 pip x 0.0714 USD` per close (`0.02856` USD per close, covering entry and exit) directly penalizes every closed layer by 0.2 pip per fill, matching Fable's `2 x d x closes x USD-per-pip` convention on line 668 of `reviews/fable_pass1/report_pass1.md`.

---

### Amendment 3: s4 a (control against the desktop's `04_ladder_cells_*.csv` by hash, not the repo's two-decimal tables)

- **Verdict:** **CONFIRMED**

#### Evidence (`origin/main`)
- research/audcad_oos/PREREG.md:56 `   17-26): closes, rolled closes and rolls equal, net USD equal to the cent. Those two files are not in the repo:`
- reviews/fable_pass1/04_ladder_bars.py:52 `    return dict(months=n, closes=n_close, rolled_closes=int(rclose[-1]), rolls=int(rolls[-1]),`
- reviews/fable_pass1/04_ladder_bars.py:55 `                closes_per_day=n_close / 989.0, total_usd=usd.sum(), comm_usd=COMM * n_close, net_usd=net.sum(),`
- reviews/fable_pass1/04_ladder_bars.py:74 `            cells.append(("scan", "cap7", a / 4.0, float(a), float(a), a / 4.0 + 1, 7))`
- reviews/fable_pass1/04_ladder_bars.py:75 `        if path == "std":`
- reviews/fable_pass1/04_ladder_bars.py:80 `                cells.append(("design", "exit2a", a / 4.0, float(a), 2.0 * a, a / 4.0 + 1, 7))`
- reviews/fable_pass1/out/04_ladder_tables_cont.txt:135 `   20 |      3.4   |   +19.7 ( +3.2)    +25.1 ( +4.7) |    5.9                    |   +14.54 ( +2.1)    +19.90 ( +3.3) | 3 / 4`
- reviews/fable_pass1/out/04_ladder_tables_cont.txt:275 `   20 |  -6.2 (  -10.04) |  -1.7 (   -5.81) |  +2.1 (  +14.54) |  +0.5 (   +6.87) |  +0.6 (   +4.29) |  +3.0 (  +19.22)`

#### Assessment
This amendment is right and complete. In `reviews/fable_pass1/04_ladder_bars.py` (lines 74-80), `scan` (`cap7`) is run on all paths and `design` (`exit2a`) is run on `path == "std"`, so `04_ladder_cells_cont.csv` and `04_ladder_cells_one.csv` contain all 10 `AUDCAD` `std` cells at `a in {17, 18, 20, 23, 26}` with full floating-point `net_usd` and exact integer `closes`, `rolled_closes`, and `rolls`. Naming their desktop path (`D:\fxmatrix-exports\fable_review\out\`) and sha256 prefixes (`63052ba31b142d92` and `d224418cff16c238` from `reviews/fable_pass1/MANIFEST.md` lines 48-49) makes "net USD equal to the cent" well-defined and exact.

---

### Amendment 4: s4 c-d and s7 (the file checks, the null on all ten cells, the fixed constants)

- **Verdict:** **CONFIRMED**

#### Evidence (`origin/main`)
- research/audcad_oos/PREREG.md:61 `   below low or open / close outside [low, high]; no negative spread; **at least 15,000 bars in every month`
- research/audcad_oos/PREREG.md:62 `   counted** (a month with fewer is dropped and listed). Reported: first and last bar, bars per year, months covered,`
- research/audcad_oos/PREREG.md:63 `   the share of blow-out bars, the median recorded spread overall and in server hours 2-21. No ladder result.`
- research/audcad_oos/PREREG.md:65 `   cut into bars with the new file's median bar range; **all ten cells'** gross in each variant on it, reported as`
- research/audcad_oos/PREREG.md:98 `- **Fixed constants from the in-sample code:** USD per pip 0.0714 (USDCAD ranged about 1.25-1.45 in 2018-2022, so`
- research/audcad_oos/PREREG.md:99 `  the true value moved by up to about 8%); the blow-out threshold is the new file's own median spread`
- reviews/fable_pass1/common.py:33 `USD = {"EURUSD": 0.100, "GBPUSD": 0.100, "EURGBP": 0.134, "AUDCAD": 0.0714, "AUDCHF": 0.122, "CADCHF": 0.122}`
- reviews/fable_pass1/common.py:64 `    dow = ((t // 86400) + 3) % 7          # 0 = Monday (1970-01-01 was a Thursday)`
- reviews/fable_pass1/common.py:72 `    sp = b["sp"] / PIP`
- reviews/fable_pass1/common.py:73 `    med = np.median(sp)`
- reviews/fable_pass1/common.py:74 `    return sp > max(3.0 * med, med + 1.0)`
- reviews/fable_pass1/core.py:221 `        paused = (tod_min[i] >= 23 * 60 + 50) or (tod_min[i] < 15)`
- reviews/fable_pass1/01_null_calibration.py:26 `    o = ladder(p, p, tod, per, per[-1] + 1, w, float(a), float(a), w + 1, 2.0, 7, True, 0, 50)`

#### Assessment
This amendment is right and complete:
1. **s4 c:** Checks header `symbol=AUDCAD`, `digits=5`, `point=0.00001000`, OHLC bounds (`high >= low`, `open` and `close` in `[low, high]`), `sp >= 0`, and at least 15,000 bars in every counted month before any ladder run.
2. **s4 d:** Extends `reviews/fable_pass1/01_null_calibration.py` (which originally only ran `exit = a` on `cont` at `a in {18, 23}` in the region) to all ten cells (`a in {17, 18, 20, 23, 26}`, `exit in {a, 2a}`) across all four variants at the new file's median bar range.
3. **s7:** Explicitly documents the fixed constants inherited from `common.py` and `core.py`: `USD["AUDCAD"] = 0.0714`, `blowout_mask` using the new file's own median spread, the re-roll pause at `23:50-00:15` server time (`core.py` line 221), and `weekday_mask` dropping weekends only.

---

### Amendment 5: s8 (`--selfcheck` committed and all PASS before `--oos` can run)

- **Verdict:** **CONFIRMED**

#### Evidence (`origin/main`)
- research/audcad_oos/PREREG.md:29 `  before it is opened for anything but its header.`
- research/audcad_oos/PREREG.md:106 `2. The operator exports the bars (s2); Claude hashes the file and reads its header only.`
- research/audcad_oos/PREREG.md:85 `- **Consequence:** FAILS or INCONCLUSIVE: Fable's region is closed and the live remainder runs C's t2 as planned.`

#### Assessment
This amendment is right and complete. Splitting the runner into `run_oos.py --selfcheck` (committed with its output on `main`) and `run_oos.py --oos` (which refuses to run unless the self-check output exists on `main` and reads all `PASS`) enforces in code and git history that no 2018-2022 ladder result can be computed or read before all self-checks pass.

---

## 2. ITEMS 1-7 OF THE FIRST PROMPT ON THE AMENDED `PREREG.md`

### Item 1: The region and the rule (s3, s6)

- **Verdict:** **CONFIRMED**

#### Evidence (`origin/main`)
- research/audcad_oos/PREREG.md:16 `**+884 USD** after commission at 0.01 lot, +19.2 USD a month, t 3.0, 4 of 4 years positive. The ten cells of the`
- research/audcad_oos/PREREG.md:17 `region average about +15 USD a month in that variant. HOLDS (s6) asks for the same sign, with t at least 2, in`
- research/audcad_oos/PREREG.md:18 `five years it never saw.`
- research/audcad_oos/PREREG.md:36 `- **The ten cells:** AUDCAD, cap 7, deadband 2, width a / 4, stranded a / 4 + 1 (Fable's scan and design cells),`
- research/audcad_oos/PREREG.md:37 `  **add a in {17, 18, 20, 23, 26}, exit in {a, 2a}.**`
- research/audcad_oos/PREREG.md:44 `- **The region:** each month, the mean of the ten cells' net USD; its mean over months and its t (mean / se across`
- research/audcad_oos/PREREG.md:45 `  months).`
- research/audcad_oos/PREREG.md:76 `1. The region's mean monthly net USD is above zero.`
- research/audcad_oos/PREREG.md:77 `2. Its t over months is **2.0 or more**.`
- research/audcad_oos/PREREG.md:78 `3. **At least ceil(0.6 x Y) of the Y calendar years** with 6 or more months in the file have a positive region net`
- research/audcad_oos/PREREG.md:79 `   (Y = 5: 3; Y = 4: 3; Y = 3: 2); a year's region net is the sum of its monthly region nets.`
- research/audcad_oos/PREREG.md:80 `4. **At least 7 of the 10 cells** have a positive net.`
- research/audcad_oos/PREREG.md:82 `- The region's mean at or below zero: **FAILS**. Above zero but not all four: **INCONCLUSIVE**.`
- research/audcad_oos/PREREG.md:83 `- A HOLDS that fails any of 1-4 under the 0.2 pip sensitivity is **FRAGILE**, treated as INCONCLUSIVE.`
- reviews/fable_pass1/common.py:35 `SCALES = [3, 4, 5, 6, 7, 8, 9, 10, 12, 14, 15, 17, 18, 20, 23, 26, 30, 40, 60, 100]`
- reviews/fable_pass1/report_pass1.md:50 `    than half of all cells scanned have net t <= -2 and none at those rungs is significantly positive. The one`
- reviews/fable_pass1/report_pass1.md:51 `    region that approaches my pre-set bar is AUDCAD at rungs 17 to 26, best with exit = 2 x add (+18 to +23`
- reviews/fable_pass1/report_pass1.md:825 `- **AUDCAD is positive from about 15 pips up,** peaking at 17 to 26: +10 to +21 USD/month with exit = add (t 1.4`
- reviews/fable_pass1/report_pass1.md:826 `  to 3.6 across variants), +19 to +23 with exit = 2 x add at 17 to 23 (t 3.0 to 3.6), positive in 3 or 4 of 4`
- reviews/fable_pass1/report_pass1.md:950 `- AUDCAD at 17 to 26 pip rungs (and CADCHF, EURGBP more weakly at 20 to 60): plausibly, on this sample. The`
- reviews/fable_pass1/out/04_ladder_tables_cont.txt:133 `   17 |      4.4   |   +17.6 ( +3.1)    +23.2 ( +4.3) |   10.0                    |   +10.08 ( +1.4)    +16.80 ( +2.3) | 3 / 3`
- reviews/fable_pass1/out/04_ladder_tables_cont.txt:273 `   17 |  -6.2 (  -13.55) |  -3.4 (  -13.05) |  +1.4 (  +10.08) |  +0.8 (  +12.19) |  -1.5 (  -13.38) |  +3.2 (  +21.69)`

#### Assessment
1. **Exact match to Fable's region:** In `reviews/fable_pass1/common.py` (line 35), the rungs in `[17, 26]` are `{17, 18, 20, 23, 26}`, and Fable's s1, s4.8, and s5 identify `AUDCAD` at rungs `17` to `26` with `exit = add` or `2 x add`, `cap 7` (`width = a / 4`, `stranded = a / 4 + 1`, `deadband = 2`). That is exactly the ten cells in s3.
2. **Monthly region average and t-statistic:** Averaging the ten cells' net USD within each calendar month before computing `tstat` across months treats each calendar month as a single observation (`n <= 60`), avoiding inflated degrees of freedom from correlated cells.
3. **Power and false-positive control:** In sample (`cont-std`), the 10 cells average `+15.19` USD/month (`+10.08, +6.84, +14.54, +14.93, +12.52` for `exit = a` and `+21.69, +18.28, +19.22, +22.58, +13.23` for `exit = 2a` in `reviews/fable_pass1/out/04_ladder_tables_cont.txt` lines 133-137 and 273-277). A one-sided `t >= 2.0` threshold (`alpha approx 0.025`) together with `ceil(0.6 x Y)` positive years, `>= 7/10` positive cells, and survival under the 0.2 pip/fill sensitivity is both hard to pass by chance and well-powered for a true `+15` USD/month effect over 36-60 months.
4. **Exhaustive classification:** Every possible outcome is classified into `HOLDS`, `FRAGILE` (treated as `INCONCLUSIVE`), `INCONCLUSIVE`, `FAILS`, or `NOT TESTABLE` (s2).

---

### Item 2: The variants and the sensitivity (s3)

- **Verdict:** **CONFIRMED**

#### Evidence (`origin/main`)
- research/audcad_oos/PREREG.md:39 `  bars frozen at the last normal mid). Mode "spread": the recorded bid / ask, then 0.06 USD commission per close`
- research/audcad_oos/PREREG.md:46 `- **Sensitivity:** every fill 0.2 pip worse at its own price: net minus 0.4 pip x 0.0714 USD per close (entry and`
- research/audcad_oos/PREREG.md:49 `  minimum (understated by 0.06-0.17 pip, Fable s4.1), and live fills keep only part of the touching-tick improvement`
- reviews/fable_pass1/report_pass1.md:609 `AUDCAD |     -6827  |     -6940     -1080     |     -3784      +564   | cont-std`
- reviews/fable_pass1/report_pass1.md:614 `In five pairs of six the most conservative variant (cont-std) is the nearest to the tick truth: within a few`
- reviews/fable_pass1/04_ladder_bars.py:34 `        o = ladder(bid, ask, tod, per, nper, w, a, x, strd, 2.0, cap, True, 0, 50, False, C0, ONE)`
- research/fills/results.md:18 `| FTMO (E) entries | 482 | +0.101 (0.010) | 41.7% | 46.7% | 11.6% | -0.5 |`
- research/fills/results.md:19 `| FTMO exits | 469 | +0.094 (0.011) | 43.7% | 40.7% | 15.6% | -0.4 |`
- research/fills/results.md:28 `| AUDCAD | +0.084 | | +0.266 |`

#### Assessment
1. **Why `cont-std` decides:** Fable s4.6 (`reviews/fable_pass1/report_pass1.md` lines 609, 614) showed `cont-std` is nearest the tick truth on 5 of 6 pairs and within 1.7% on `AUDCAD` (`-6940` vs `-6827` pips), whereas `cont-alt`, `one-std`, and `one-alt` are optimistic.
2. **Sensitivity and `ladder` arguments:** As confirmed under Amendment 2 above, `PREREG.md` s3 now specifies the exact `ladder` call from line 34 of `reviews/fable_pass1/04_ladder_bars.py` and applies the 0.2 pip per fill sensitivity directly to net USD (`net minus 0.4 pip x 0.0714 USD per close`).

---

### Item 3: The control (s4 a)

- **Verdict:** **CONFIRMED**

#### Evidence (`origin/main`)
- research/audcad_oos/PREREG.md:56 `   17-26): closes, rolled closes and rolls equal, net USD equal to the cent. Those two files are not in the repo:`
- reviews/fable_pass1/common.py:44 `    npz = os.path.join(CACHE, "bars_%s.npz" % pair)`
- reviews/fable_pass1/common.py:48 `    f = os.path.join(BARS_DIR, "bars_1514878887_%s.csv" % pair)`
- reviews/fable_pass1/04_ladder_bars.py:74 `            cells.append(("scan", "cap7", a / 4.0, float(a), float(a), a / 4.0 + 1, 7))`
- reviews/fable_pass1/04_ladder_bars.py:75 `        if path == "std":`
- reviews/fable_pass1/04_ladder_bars.py:80 `                cells.append(("design", "exit2a", a / 4.0, float(a), 2.0 * a, a / 4.0 + 1, 7))`
- reviews/fable_pass1/out/04_ladder_tables_one.txt:133 `   17 |      4.6   |   +20.0 ( +3.7)    +24.3 ( +4.4) |   10.3                    |   +13.94 ( +1.9)    +20.07 ( +2.7) | 3 / 3`
- reviews/fable_pass1/out/04_ladder_tables_one.txt:273 `   17 |  -6.2 (  -13.55) |  -3.1 (  -11.58) |  +1.9 (  +13.94) |  +1.2 (  +17.53) |  -0.1 (   -0.69) |  +3.3 (  +22.34)`

#### Assessment
As confirmed under Amendment 3 above, `04_ladder_cells_cont.csv` and `04_ladder_cells_one.csv` hold all 10 `AUDCAD` `std` cells (`scan` `cap7` and `design` `exit2a` at `17-26`), and because `core.ladder` is a single-threaded deterministic `@njit` loop on IEEE-754 `float64` arrays, reproducing `closes`, `rolled_closes`, `rolls`, and `net_usd` to the cent on the same desktop is exact. Note for `run_oos.py` implementation: `common.load_bars` caches by pair name (`bars_%s.npz` on line 44 of `reviews/fable_pass1/common.py`), so `run_oos.py` should use a distinct `FR_CACHE` (or bypass the `.npz` cache) when switching from the 2023-2026 control file to the 2018-2022 OOS file, as already stated in `PREREG.md` line 35 ("points the loader at a given bar file").

---

### Item 4: The data (s2)

- **Verdict:** **CONFIRMED**

#### Evidence (`origin/main`)
- research/audcad_oos/PREREG.md:25 `- **Feed:** FTMO-Demo, the in-sample feed and the venue of the live remainder, if its history reaches back to`
- research/audcad_oos/PREREG.md:26 `  2020-01-01 or earlier; otherwise an IC Markets demo login on the same terminal. **At least 36 calendar months** are`
- research/audcad_oos/PREREG.md:27 `  needed; with fewer from both, the result is NOT TESTABLE and nothing else is run.`
- scripts/grind_bar_dump.mq5:15 `input string InpSymbols = "GBPUSD,EURUSD,EURGBP,AUDCAD,AUDCHF,AUDNZD,CADCHF,NZDCAD,NZDCHF";`
- scripts/grind_bar_dump.mq5:16 `input string InpFrom    = "2026.09.27 00:00";   // server time, inclusive`
- scripts/grind_bar_dump.mq5:17 `input string InpTo      = "";                   // server time; empty = now`
- scripts/grind_bar_dump.mq5:39 `      n = CopyRates(sym, PERIOD_M1, from_t, to_t, r);`
- scripts/grind_bar_dump.mq5:51 `   const string fname = StringFormat("bars_%I64d_%s.csv", login, sym);`
- scripts/grind_bar_dump.mq5:82 `   const datetime from_t = StringToTime(InpFrom);`
- scripts/grind_bar_dump.mq5:83 `   const datetime to_t = (InpTo == "") ? TimeTradeServer() : StringToTime(InpTo);`
- handoffs/Handover/02_TRAPS.md:3067 `  request from 2023; chunking does not help (the cap counts back from now). Raising it needs a terminal restart, which`
- handoffs/Handover/02_TRAPS.md:3068 `  restarts a live fleet: pull long bar history on the desktop's terminal (no EAs; Max bars Unlimited) instead.`
- reviews/fable_pass1/report_pass1.md:360 `  (AUDCHF), 0.83 (CADCHF) pips in core hours where the IC per-minute minimum is 0.08 to 0.14. FTMO's crosses are`
- reviews/fable_pass1/report_pass1.md:361 `  0.4 to 0.8 pip wider than IC's. Mean bar ranges agree within 8%, so it is the same market at different spreads.`
- reviews/fable_pass1/report_pass1.md:362 `  On IC the per-minute mean spread exceeds the per-minute minimum by 0.06 to 0.17 pip, which is how much a bar's`

#### Assessment
1. **Exporter capability:** `scripts/grind_bar_dump.mq5` parses `InpFrom` and `InpTo` via `StringToTime` (lines 82-83), calls `CopyRates(sym, PERIOD_M1, from_t, to_t, r)` (line 39), and writes `bars_<login>_<sym>.csv` (line 51) with the metadata header (lines 59-63). On the desktop terminal with `Max bars Unlimited` (`handoffs/Handover/02_TRAPS.md` lines 3067-3068), it can export the full 2018-2022 range.
2. **No post-hoc feed choice:** The feed hierarchy (`FTMO-Demo` if its history reaches `2020-01-01` or earlier, else `IC Markets` demo if at least 36 calendar months, else `NOT TESTABLE`) leaves zero discretion after seeing the data.
3. **What an IC feed changes besides core-hours spread:**
   - Because `blowout_mask` (`reviews/fable_pass1/common.py` lines 72-74) uses `sp > max(3.0 * med, med + 1.0)` where `med` is the file's median spread in pips, a narrower IC median spread sets the blow-out floor at `med + 1.0` (~1.1-1.3 pips) rather than `3.0 * med` (~2.8 pips on FTMO), freezing more rollover/wider-spread bars on the clean path.
   - Mean M1 bar ranges differ by up to ~8% between FTMO and IC (`reviews/fable_pass1/report_pass1.md` line 361), and LP quote micro-extremes around rollover can differ slightly. Both are properly documented in s4 c and s7.

---

### Item 5: Self-checks c and d (s4)

- **Verdict:** **CONFIRMED**

#### Evidence (`origin/main`)
- research/audcad_oos/PREREG.md:61 `   below low or open / close outside [low, high]; no negative spread; **at least 15,000 bars in every month`
- research/audcad_oos/PREREG.md:62 `   counted** (a month with fewer is dropped and listed). Reported: first and last bar, bars per year, months covered,`
- research/audcad_oos/PREREG.md:63 `   the share of blow-out bars, the median recorded spread overall and in server hours 2-21. No ladder result.`
- research/audcad_oos/PREREG.md:65 `   cut into bars with the new file's median bar range; **all ten cells'** gross in each variant on it, reported as`
- reviews/fable_pass1/test_core.py:43 `    o = ladder(x, x, tod, per, 60, w, a, a, w + 1, 2.0, 7, True, 0, 1)`
- reviews/fable_pass1/test_core.py:48 `    assert abs(t) < 3.0`
- reviews/fable_pass1/test_core.py:49 `print("all tests passed")`
- reviews/fable_pass1/01_null_calibration.py:23 `def lad(p, a, blk):`
- reviews/fable_pass1/01_null_calibration.py:26 `    o = ladder(p, p, tod, per, per[-1] + 1, w, float(a), float(a), w + 1, 2.0, 7, True, 0, 50)`
- reviews/fable_pass1/01_null_calibration.py:33 `for k, nb, lab in ((160, 400_000, "sigma/bar 1.26 pips"), (1440, 60_000, "sigma/bar 3.8 pips")):`

#### Assessment
As confirmed under Amendment 4 above, s4 c catches any corrupted, wrong-symbol, or truncated bar file (and drops partial months `< 15,000` bars) before any ladder run, and s4 d runs Fable's `01_null_calibration.py` lattice random-walk method calibrated to the new file's median bar range across all ten cells and all four variants.

---

### Item 6: Biases (s7)

- **Verdict:** **CONFIRMED**

#### Evidence (`origin/main`)
- research/audcad_oos/PREREG.md:90 `- **The region was chosen in sample** from 612 cells (Fable s4.8); this test exists to check that choice.`
- research/audcad_oos/PREREG.md:91 `- **No swap.** Wide-rung layers are held for days to weeks; AUD and CAD rates differed in 2018-2022. Swap is a`
- research/audcad_oos/PREREG.md:92 `  cost to a grid that holds both sides at different times; this test flatters the region by it.`
- research/audcad_oos/PREREG.md:95 `- **The recorded spread is a minimum**, and an IC feed (if used) is 0.4-0.8 pip narrower than FTMO's on the crosses`
- research/audcad_oos/PREREG.md:96 `  in core hours (Fable s4.1): the sensitivity covers part of it.`
- research/audcad_oos/PREREG.md:97 `- **One more period of one pair.** A HOLDS does not make AUDCAD's ranging a law; it makes it two regimes, not one.`
- research/audcad_oos/PREREG.md:98 `- **Fixed constants from the in-sample code:** USD per pip 0.0714 (USDCAD ranged about 1.25-1.45 in 2018-2022, so`
- research/audcad_oos/PREREG.md:99 `  the true value moved by up to about 8%); the blow-out threshold is the new file's own median spread`
- reviews/fable_pass1/common.py:33 `USD = {"EURUSD": 0.100, "GBPUSD": 0.100, "EURGBP": 0.134, "AUDCAD": 0.0714, "AUDCHF": 0.122, "CADCHF": 0.122}`
- reviews/fable_pass1/common.py:62 `def weekday_mask(t):`
- reviews/fable_pass1/common.py:64 `    dow = ((t // 86400) + 3) % 7          # 0 = Monday (1970-01-01 was a Thursday)`
- reviews/fable_pass1/common.py:65 `    return dow < 5`
- reviews/fable_pass1/common.py:68 `def blowout_mask(b):`
- reviews/fable_pass1/common.py:72 `    sp = b["sp"] / PIP`
- reviews/fable_pass1/common.py:73 `    med = np.median(sp)`
- reviews/fable_pass1/common.py:74 `    return sp > max(3.0 * med, med + 1.0)`
- reviews/fable_pass1/core.py:221 `        paused = (tod_min[i] >= 23 * 60 + 50) or (tod_min[i] < 15)`

#### Assessment
All material biases and fixed-constant assumptions are now stated in s7: in-sample selection from 612 cells, omission of swap (with a mandatory swap check before any live decision if `HOLDS`), bar vs tick approximation, minimum-of-minute spread and FTMO vs IC spread difference, single-pair scope, fixed `USD["AUDCAD"] = 0.0714` across 2018-2022 USDCAD moves, `blowout_mask` using the new file's own median spread, the `23:50-00:15` server-clock re-roll pause across DST, and `weekday_mask` dropping only weekends.

---

### Item 7: Order of work (s8)

- **Verdict:** **CONFIRMED**

#### Evidence (`origin/main`)
- research/audcad_oos/PREREG.md:29 `  before it is opened for anything but its header.`
- research/audcad_oos/PREREG.md:106 `2. The operator exports the bars (s2); Claude hashes the file and reads its header only.`

#### Assessment
As confirmed under Amendment 5 above, `PREREG.md` s8 (lines 105-109) now requires `run_oos.py --selfcheck` and its output to be committed to `main` before `run_oos.py --oos` can run, and `--oos` refuses to execute unless that self-check output exists on `main` and reads all `PASS`. No step can read a 2018-2022 result before the self-checks are committed.

---

**SOUND**

Line count: 305
