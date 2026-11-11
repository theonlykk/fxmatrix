This message has a line count at the bottom

# Argon Pre-Execution Review: `research/audcad_oos/PREREG.md` (`AUDCAD` 17-26 Rung Out-of-Sample Test, 2018-2022)

- **Branch:** `review/argon-audcad-oos`
- **Base commit (`origin/main`):** `c511c90362233e530411dbfb11a0460127b9d668`
- **Files read:**
  - `prompts/argon_review_audcad_oos.md` (lines 1-52)
  - `research/audcad_oos/PREREG.md` (lines 1-96)
  - `reviews/fable_pass1/report_pass1.md` (lines 1-1069)
  - `reviews/fable_pass1/core.py` (lines 1-337)
  - `reviews/fable_pass1/common.py` (lines 1-127)
  - `reviews/fable_pass1/04_ladder_bars.py` (lines 1-102)
  - `reviews/fable_pass1/04b_ladder_tables.py` (lines 1-75)
  - `reviews/fable_pass1/08_summary.py` (lines 1-170)
  - `reviews/fable_pass1/00_data_summary.py` (lines 1-35)
  - `reviews/fable_pass1/01_null_calibration.py` (lines 1-50)
  - `reviews/fable_pass1/test_core.py` (lines 1-49)
  - `reviews/fable_pass1/MANIFEST.md` (lines 1-72)
  - `reviews/fable_pass1/out/04_ladder_tables_cont.txt` (lines 1-480)
  - `reviews/fable_pass1/out/04_ladder_tables_one.txt` (lines 1-480)
  - `reviews/fable_pass1/out/00_data_summary.txt` (lines 1-60)
  - `reviews/fable_pass1/out/01_null_calibration.txt` (lines 1-26)
  - `research/fills/results.md` (lines 1-46)
  - `scripts/grind_bar_dump.mq5` (lines 1-101)
  - `handoffs/Handover/02_TRAPS.md` (lines 3020-3120)

---

## 1. The region and the rule (`s3`, `s6`)

### 1a. Translation of Fable's `AUDCAD` 17-26 region into the ten cells (`s3`)
- **Verdict:** `CONFIRMED`
- **Citations:**
  - `research/audcad_oos/PREREG.md:36` `- **Ten cells** (cap 7, deadband 2, width `a / 4`, stranded `a / 4 + 1` in pips, 0.01 lot):`
  - `research/audcad_oos/PREREG.md:37` `  `add a in {17, 18, 20, 23, 26}`, `exit in {a, 2a}`.`
  - `reviews/fable_pass1/common.py:35` `SCALES = [3, 4, 5, 6, 7, 8, 9, 10, 12, 14, 15, 17, 18, 20, 23, 26, 30, 40, 60, 100]`
  - `reviews/fable_pass1/04_ladder_bars.py:72` `    for a in SCALES:`
  - `reviews/fable_pass1/04_ladder_bars.py:73` `        w = a / 4.0; s = w + 1.0`
  - `reviews/fable_pass1/04_ladder_bars.py:77` `        for name, c, xm in [("cap1", 1, 1.0), ("cap3", 3, 1.0), ("cap15", 15, 1.0), ("exit0.5a", 7, 0.5), ("exit2a", 7, 2.0)]:`
  - `reviews/fable_pass1/report_pass1.md:50` `5. **One region in the whole scan survives at t >= 3 across all four variants:** AUDCAD at rungs 17 to 26, best`
  - `reviews/fable_pass1/report_pass1.md:51` `   with exit = 2 x add (about +19 to +23 USD/month per 0.01-lot arm on the conservative path, t 3.0 to 3.6, 4 of`
  - `reviews/fable_pass1/report_pass1.md:825` `- **AUDCAD is positive from about 15 pips up, peaking at 17 to 26:** +10 to +21 USD/month with exit = add (t 1.4`
  - `reviews/fable_pass1/report_pass1.md:826` `  to 3.6 across variants), +19 to +23 with exit = 2 x add at 17 to 23 (t 3.0 to 3.6). Above 30 pips the trade count`
  - `reviews/fable_pass1/report_pass1.md:950` `- AUDCAD at 17 to 26 pip rungs (and CADCHF, EURGBP more weakly at 20 to 60): plausibly, on this sample. The`
- **Analysis:** In `SCALES` (line 35 of `reviews/fable_pass1/common.py`), the rungs in `[17, 26]` are `{17, 18, 20, 23, 26}`, and the two exit multiples highlighted by Fable (`exit = add` in `scan`/`cap7` and `exit = 2 x add` in `design`/`exit2a`, both at `cap = 7, width = a / 4, stranded = a / 4 + 1, deadband = 2.0`) give the exact 10 cells in `s3`.

### 1b. Monthly averaging across the ten correlated cells (`s3`)
- **Verdict:** `CONFIRMED`
- **Citations:**
  - `research/audcad_oos/PREREG.md:41` `- **Primary statistic:** for each calendar month, the mean net USD across the ten cells; from that monthly series,`
  - `research/audcad_oos/PREREG.md:42` `  the sample mean, standard error and `t = mean / SE` across months.`
  - `reviews/fable_pass1/common.py:121` `def tstat(x):`
  - `reviews/fable_pass1/common.py:126` `    se = s / np.sqrt(n)`
  - `reviews/fable_pass1/common.py:127` `    return m, se, (m / se if se > 0 else 0.0), n`
- **Analysis:** Averaging the 10 cells within each calendar month `m` first (`x_bar_m = (1/10) * sum_{c=1..10} x_{c,m}`) and then computing `t = mean / SE` across the `M` monthly means treats the calendar month (`df = M - 1`), not the cell-month (`10 * M`), as the unit of replication. Under a zero-mean null, positive correlation `rho_bar` among the 10 cells within a month scales both the numerator's SD and the denominator's sample SD across months by the exact same factor `sqrt((1 + 9 * rho_bar) / 10)`, so inter-cell correlation does **not** inflate the Type I error of `t >= 2.0`. Under a positive alternative (`mu > 0`), high positive correlation prevents the 10-cell average from artificially shrinking the monthly SD below the single-cell monthly SD (~42-47 USD/month in 2023-2026), and criterion 4 (`At least 7 of the 10 cells have a positive net`) prevents 1-2 outlier cells from carrying a mostly negative region.

### 1c. Threshold calibration (`t >= 2.0`, 3 of 5 years, 7 of 10 cells), outcome completeness, and year-count mismatch (`s2` vs `s6`)
- **Verdict:** `DEFECT`
- **Citations:**
  - `research/audcad_oos/PREREG.md:16` `With `exit = 2a` on the conservative bar path (`cont-std`) those five cells average about +20 USD a month at`
  - `research/audcad_oos/PREREG.md:17` `0.01 lot (`t` 1.9 to 3.5); with `exit = a`, about +12 USD a month (`t` 1.1 to 2.3); across all ten, about +15 USD`
  - `research/audcad_oos/PREREG.md:26` `  history reaches back to 2020-01-01 or earlier; (2) the IC Markets terminal (`ICMarketsSC-Demo`), same check.`
  - `research/audcad_oos/PREREG.md:27` `  At least 36 calendar months are needed; 60 (all of 2018-2022) is the target.`
  - `research/audcad_oos/PREREG.md:66` `The AUDCAD 17-26 region **HOLDS** out of sample if, on the base variant (`cont-std`):`
  - `research/audcad_oos/PREREG.md:67` `1. The 10-cell region's monthly mean net USD is **positive**, and`
  - `research/audcad_oos/PREREG.md:68` `2. Its `t`-statistic across months is **>= 2.0**, and`
  - `research/audcad_oos/PREREG.md:69` `3. **At least 3 of the 5 years** have a positive region net, and`
  - `research/audcad_oos/PREREG.md:70` `4. **At least 7 of the 10 cells** have a positive net over the period,`
  - `research/audcad_oos/PREREG.md:71` `and on the **+0.2 pip/fill sensitivity** all four still hold (if the base passes and the sensitivity does not, the`
  - `research/audcad_oos/PREREG.md:72` `verdict is **FRAGILE**, which for trading purposes is treated as inconclusive). If the region mean on `cont-std``
  - `research/audcad_oos/PREREG.md:73` `is `<= 0`, the verdict is **FAILS**. Anything in between (`> 0` with `t < 2.0` or fewer years/cells) is **INCONCLUSIVE**.`
  - `reviews/fable_pass1/04_ladder_bars.py:41` `    eq = o["real"] + o["openp"]; d = np.diff(np.r_[0.0, eq])`
  - `reviews/fable_pass1/04_ladder_bars.py:45` `    net = usd - COMM * dc`
  - `reviews/fable_pass1/04_ladder_bars.py:48` `    ypos = int(sum(1 for y in np.unique(years) if net[years == y].sum() > 0))`
- **Analysis:**
  1. **Power on a full 60-month (5-year) sample:** In 2023-2026 `cont-std` (lines 133-137 and 273-277 of `reviews/fable_pass1/out/04_ladder_tables_cont.txt`), the 5 `exit = a` cells average `+11.78` USD/month and the 5 `exit = 2a` cells average `+19.00` USD/month (10-cell mean `+15.39` USD/month, single-cell monthly SD ~42-47 USD/month). Over `M = 60` months at `+15` USD/month and `sigma = 45` USD/month, `SE = 45 / sqrt(60) = 5.81` USD/month and `E[t] = 2.58`, giving ~72% power to clear `t >= 2.0` (one-sided Type I error ~2.5% under `mu = 0`) and >95% probability of at least 3 of 5 positive years.
  2. **Outcome classification completeness:** On a 5-year sample, the four verdicts (`HOLDS`, `FRAGILE`, `INCONCLUSIVE`, `FAILS`) partition all outcomes with no unclassified case: `mean <= 0` -> `FAILS`; `mean > 0` and base fails any of 2-4 -> `INCONCLUSIVE`; base passes 1-4 and sensitivity fails any of 1-4 -> `FRAGILE`; both pass 1-4 -> `HOLDS`.
  3. **Why this is a `DEFECT`:** First, `s2` (lines 26-27 of `research/audcad_oos/PREREG.md`) allows running with as few as 36 calendar months (`2020-01-01` to `2022-12-31`, i.e. `Y = 3` calendar years, or `Y = 4` years if starting in 2019), whereas criterion 3 (line 69 of `research/audcad_oos/PREREG.md`) hard-codes `At least 3 of the 5 years`. If the terminal only has 3 calendar years (2020-2022), requiring 3 positive years becomes a 3-of-3 (100%) requirement (and a partial stub year if the feed starts mid-year has undefined status). Second, `s6` does not state whether a year's region net is the sum of its monthly mark-to-market region nets (`real + openp` change minus commission, as in lines 41-48 of `reviews/fable_pass1/04_ladder_bars.py`) or realised-only P&L.
- **Smallest fix (replacement text for lines 69-70 of `research/audcad_oos/PREREG.md`):**
  ```markdown
  3. **At least `ceil(0.6 * Y)` of the `Y` full calendar years** (`>= 3 of 5`, `3 of 4`, or `2 of 3` years with `>= 6`
     months of bars; any leading partial year with `< 6` months is included in the monthly series but not counted as a
     standalone year) have a positive region net (sum of that year's monthly mark-to-market region nets, matching
     `04_ladder_bars.py`), and
  4. **At least 7 of the 10 cells** have a positive total mark-to-market `net_usd` over the period,
  ```

---

## 2. The variants and the sensitivity (`s3`)

### 2a. `cont-std` as primary variant and reporting all four (`s3`)
- **Verdict:** `CONFIRMED`
- **Citations:**
  - `research/audcad_oos/PREREG.md:40` `  path (`clean = True`, blow-out bars frozen). `cont-std` is the primary variant; the other three are reported`
  - `reviews/fable_pass1/08_summary.py:85` `S3. Which bar variant is nearest the tick truth? IC ticks Aug-Oct 2026; truth = ladder on ticks, one resting add, real bid/ask,`
  - `reviews/fable_pass1/report_pass1.md:603` `S3. Which bar variant is nearest the tick truth? IC ticks Aug-Oct 2026; truth = ladder on ticks, one resting add, real bid/ask,`
  - `reviews/fable_pass1/report_pass1.md:605` `pair   | tick truth | bars cont-std  cont-alt | bars one-std  one-alt | nearest`
  - `reviews/fable_pass1/report_pass1.md:609` `AUDCAD |     -6827  |     -6940     -1080     |     -3784      +564   | cont-std`
  - `reviews/fable_pass1/report_pass1.md:614` `- **`cont-std` is the closest of the four on five of the six pairs,** and the only one with the right sign on every`
- **Analysis:** On Fable's IC tick validation (`S3`), `cont-std` is nearest tick truth on 5 of 6 pairs and within 1.7% on `AUDCAD` (`-6940` vs `-6827` pips), while reporting `cont-alt`, `one-std`, and `one-alt` alongside preserves the intra-bar order and fill-model bracket.

### 2b. How `"bid - 0.2 pip, ask + 0.2 pip"` behaves inside `core.ladder` (`s3`)
- **Verdict:** `DEFECT`
- **Citations:**
  - `research/audcad_oos/PREREG.md:43` `- **Sensitivity:** every fill 0.2 pip worse (`bid - 0.2 pip, ask + 0.2 pip` on every pseudo-tick), to cover the`
  - `research/audcad_oos/PREREG.md:44` `  gap between a bar's minimum spread and the spread at fills (`reviews/fable_pass1/report_pass1.md` s4.1, s7:`
  - `research/audcad_oos/PREREG.md:45` `  0.06-0.17 pip per round trip in normal hours) and a conservative fill convention (`research/fills/results.md`).`
  - `research/fills/results.md:19` `| FTMO exits | 469 | +0.094 (0.011) | 43.7% | 40.7% | 15.6% | -0.4 |`
  - `reviews/fable_pass1/core.py:123` `        mid = 0.5 * (b + a)`
  - `reviews/fable_pass1/core.py:126` `        while nl > 0 and b >= xp[0, j] - EPS:`
  - `reviews/fable_pass1/core.py:128` `            fx = (b if b > xp[0, j] else xp[0, j]) if mkt_fill else xp[0, j]`
  - `reviews/fable_pass1/core.py:129` `            pnl = (fx - ent[0, j]) / PIP`
  - `reviews/fable_pass1/core.py:146` `        while ns > 0 and a <= xp[1, j] + EPS:`
  - `reviews/fable_pass1/core.py:148` `            fx = (a if a < xp[1, j] else xp[1, j]) if mkt_fill else xp[1, j]`
  - `reviews/fable_pass1/core.py:149` `            pnl = (ent[1, j] - fx) / PIP`
  - `reviews/fable_pass1/core.py:170` `                if (s == 0 and a <= l0[s] + EPS) or (s == 1 and b >= l0[s] - EPS):`
  - `reviews/fable_pass1/core.py:172` `                    p = ((a if a < l0[0] else l0[0]) if s == 0 else (b if b > l0[1] else l0[1])) if mkt_fill else l0[s]`
  - `reviews/fable_pass1/core.py:181` `                    xp[s, 0] = p + X if s == 0 else p - X`
  - `reviews/fable_pass1/core.py:190` `                        p = ((a if a < tgt else tgt) if s == 0 else (b if b > tgt else tgt)) if mkt_fill else tgt`
  - `reviews/fable_pass1/core.py:207` `                            p = ((a if a < tgt else tgt) if s == 0 else (b if b > tgt else tgt)) if mkt_fill else tgt`
  - `reviews/fable_pass1/core.py:234` `                ext[0] = a <= level`
  - `reviews/fable_pass1/core.py:235` `                ext[1] = b >= level`
  - `reviews/fable_pass1/08_summary.py:79` `        lim = [ni.net_month_usd for ni in n]; adj = [ni.net_month_usd + 2 * d * ni.closes * USD[pair] / 46.0 for ni in n]`
- **Analysis:** In `core.ladder` with `mkt_fill = False`, a touched limit order fills at its **limit price** (`fx = xp[0, j]`, `fx = xp[1, j]`, `p = l0[s]`, `p = tgt`), **not** at `b` or `a`. Therefore, passing `bid - 0.2 * PIP, ask + 0.2 * PIP` into `core.ladder` does **not** subtract `0.2` pip from the fill price of every executed fill: any bar whose high/low crosses a limit by more than `0.2` pip still books the exact same `X = exit_` pips between `ent` and `xp`. Instead, shifting `bid - 0.2 * PIP, ask + 0.2 * PIP` widens the trigger/roll/clamp spread by `+0.4` pip per round trip (`ask - bid` increases by `0.4` pip, so a bar's extremum must reach `0.2` pip further on entry and `0.2` pip further on exit to trigger limits, rolls trigger `0.2` pip sooner at lines 234-235 of `reviews/fable_pass1/core.py`, and passive clamps / open marks sit `0.2` pip worse). Conversely, docking `0.2` pip per fill (`0.4` pip per close = `2 * 0.2 * closes * USD["AUDCAD"]`, as in line 79 of `reviews/fable_pass1/08_summary.py`) directly reduces every close's P&L by `0.4` pip (`$0.02856`/close) even when a bar shoots well past the limit. Because line 43 of `research/audcad_oos/PREREG.md` states both `"every fill 0.2 pip worse"` (price slippage language) and `"(bid - 0.2 pip, ask + 0.2 pip on every pseudo-tick)"` (quote-widening language), it can be read two ways (either quote-shift only, or quote-shift plus/versus `-0.4 * PIP * closes` price adjustment).
- **Smallest fix (replacement text for lines 43-45 of `research/audcad_oos/PREREG.md`):**
  ```markdown
  - **Sensitivity:** pass `bid - 0.2 * PIP, ask + 0.2 * PIP` on every pseudo-tick into `core.ladder` (widening the
    effective trigger/roll/clamp spread by +0.4 pip per round trip) **and** also report the direct fill-price penalty
    `net_usd - 2 * 0.2 * closes * USD["AUDCAD"]` (-0.2 pip per fill = -0.4 pip per close on executed fills, as in
    `08_summary.py` S2b); the sensitivity gate in s6 is evaluated on the `bid - 0.2 * PIP, ask + 0.2 * PIP` ladder run.
  ```

### 2c. Matching `04_ladder_bars.py`'s exact `core.ladder` arguments (`s3`)
- **Verdict:** `GAP`
- **Citations:**
  - `reviews/fable_pass1/04_ladder_bars.py:22` `C0 = np.zeros((0, 7), dtype=np.float64)`
  - `reviews/fable_pass1/04_ladder_bars.py:34` `    o = ladder(bid, ask, tod, per, nper, w, a, x, strd, 2.0, cap, True, 0, 50, False, C0, ONE)`
  - `reviews/fable_pass1/04_ladder_bars.py:65` `    tod = ((tm // 60000) % 1440).astype(np.int64)`
  - `reviews/fable_pass1/04_ladder_bars.py:66` `    um, per = np.unique(mon, return_inverse=True); nper = len(um)`
  - `reviews/fable_pass1/test_core.py:10` `    return ladder(bid, ask, tod, per, nper, w, a, x, s, db, cap, reroll, gate, 1, mkt, clog, one_add)`
- **Analysis:** Lines 36-40 of `research/audcad_oos/PREREG.md` specify `cap = 7, deadband = 2.0, width = a / 4, stranded = a / 4 + 1, clean = True` and `one_add`, but omit `reroll = True, gate = 0, max_reroll_tick = 50, mkt_fill = False` (note line 10 of `reviews/fable_pass1/test_core.py` uses `max_reroll_tick = 1`, whereas line 34 of `reviews/fable_pass1/04_ladder_bars.py` uses `50`). Self-check `a` would catch a mismatch on 2023-2026, but pinning the exact call signature in `s3` prevents any discrepancy.
- **Smallest fix (append to line 40 of `research/audcad_oos/PREREG.md`):**
  ```markdown
    alongside as the range across bar approximations. All `core.ladder` calls use `deadband = 2.0, cap = 7,
    reroll = True, gate = 0, max_reroll_tick = 50, mkt_fill = False, clog = np.zeros((0, 7))`, `tod = ((tm // 60000) %
    1440).astype(np.int64)`, and monthly `per` from `np.unique(mon, return_inverse=True)` as in `04_ladder_bars.py`.
  ```

---

## 3. The control (`s4 a`)

### 3a. Location of `04_ladder_cells_*.csv` vs contents of `04_ladder_tables_*.txt`
- **Verdict:** `GAP`
- **Citations:**
  - `research/audcad_oos/PREREG.md:50` `- **a. 2023-2026 positive control:** run the same script on `D:\fxmatrix-exports\bars_ftmo\AUDCAD_M1.csv` and verify`
  - `research/audcad_oos/PREREG.md:51` `  that for all ten cells on `cont-std` and `one-std`, `closes`, `rolls`, and `net_usd` match`
  - `research/audcad_oos/PREREG.md:52` `  `reviews/fable_pass1/out/04_ladder_cells_cont.csv` and `_one.csv` (and the table in `04_ladder_tables_cont.txt` /`
  - `research/audcad_oos/PREREG.md:53` `  `_one.txt`) to the cent.`
  - `reviews/fable_pass1/MANIFEST.md:48` `out/04_ladder_cells_cont.csv           325067  63052ba31b142d92  **no** (regenerate: 04_ladder_bars.py cont)`
  - `reviews/fable_pass1/MANIFEST.md:50` `out/04_ladder_cells_one.csv            325060  d224418cff16c238  **no** (regenerate: 04_ladder_bars.py one)`
  - `reviews/fable_pass1/MANIFEST.md:52` `out/04_ladder_tables_cont.txt           39457  fd8c1793e5e0c3ae  yes`
  - `reviews/fable_pass1/MANIFEST.md:53` `out/04_ladder_tables_one.txt            39457  bc0ac27c0bc06478  yes`
  - `reviews/fable_pass1/common.py:31` `    "AUDCAD": ((4.5, 18, 5.5), (6.5, 26, 7.5)),`
  - `reviews/fable_pass1/04_ladder_bars.py:70` `                st, m = summarise(pair, run_cell(b, k, tod, per, nper, w, a, a, s, 5), um, a)`
  - `reviews/fable_pass1/04b_ladder_tables.py:5` `C = pd.read_csv(os.path.join(OUT, "04_ladder_cells_%s.csv" % FILL))`
  - `reviews/fable_pass1/out/04_ladder_tables_cont.txt:133` `   17 |      0.8   |   +17.6 ( +3.1)    +20.2 ( +3.6) |   11.6                    |   +10.08 ( +1.4)   +15.69 ( +2.2) | 3 / 3`
  - `reviews/fable_pass1/out/04_ladder_tables_cont.txt:273` `   17 |  -3.6 (   -7.01) |  -0.6 (   -2.46) |  +1.4 (  +10.08) |  +1.3 (  +18.41) |  +0.3 (   +0.84) |  +3.2 (  +21.69)`
  - `reviews/fable_pass1/out/04_ladder_tables_one.txt:133` `   17 |      0.8   |   +20.0 ( +3.7)    +23.8 ( +4.5) |   10.2                    |   +16.61 ( +2.2)   +23.16 ( +3.4) | 3 / 3`
  - `reviews/fable_pass1/out/04_ladder_tables_one.txt:273` `   17 |  -3.6 (   -7.01) |  -0.2 (   -1.02) |  +2.2 (  +16.61) |  +1.6 (  +24.21) |  +1.4 (   +5.25) |  +3.4 (  +23.70)`
- **Analysis:** Per lines 48-53 of `reviews/fable_pass1/MANIFEST.md`, `out/04_ladder_cells_cont.csv` and `out/04_ladder_cells_one.csv` are **not** in the repo; they live in `D:\fxmatrix-exports\fable_review\out\` on the desktop (with SHA-256 prefixes `63052ba31b142d92` and `d224418cff16c238`). What is in the repo (`reviews/fable_pass1/out/04_ladder_tables_cont.txt` and `_one.txt`) contains:
  - For all 5 `exit = a` (`cap7`) cells (lines 133-137): `closes/day` (`%.1f`), `gross %/rung std (t)`, `cost %/rung`, `net USD/month std (t)` (`%.2f`, i.e. cents/month), and `years+`.
  - For all 5 `exit = 2a` (`exit2a`) cells (lines 273-277 and 412-416): `net t (net USD/month)` (`%.2f`, cents/month) and `gross t (gross % of rung per close)`.
  - Note also that the `T3 LIVE ARMS` rows at lines 28-33 of `04_ladder_tables_*.txt` (`OPT 18` and `ALT 26`) were run with `cap = 5` (line 70 of `reviews/fable_pass1/04_ladder_bars.py`), whereas the 10 region cells use `cap = 7`. Therefore, for the 10 `cap = 7` cells, `04_ladder_tables_*.txt` provides `net_month_usd` to the cent (`%.2f`) and `net_t` (`%.1f`) for all 10 cells (plus `closes/day` and `years+` for the 5 `exit = a` cells), while exact integer `closes`, `rolled_closes`, and total `net_usd` for all 10 `cap = 7` cells come from `D:\fxmatrix-exports\fable_review\out\04_ladder_cells_cont.csv` and `_one.csv`.

### 3b. Is `"equal to the cent"` achievable given Numba and floating point?
- **Verdict:** `CONFIRMED`
- **Citations:**
  - `reviews/fable_pass1/core.py:90` `@njit(cache=True)`
  - `reviews/fable_pass1/core.py:91` `def ladder(bid, ask, tod_min, period_id, n_periods,`
  - `reviews/fable_pass1/core.py:121` `    for i in range(n_ticks):`
- **Analysis:** `core.ladder` is compiled with `@njit(cache=True)` without `fastmath=True` or parallel reductions, executing a strictly sequential `float64` loop over `n_ticks`. On the same desktop and `AUDCAD_M1.csv`, `closes` and `rolled_closes` match as exact integers (`==`) and `net_usd` / `net_month_usd` match bit-for-bit (and within `abs(x - y) <= 0.005` USD when compared against the 2-decimal `net USD/month` columns in `04_ladder_tables_*.txt`).
- **Smallest fix (replacement text for lines 50-53 of `research/audcad_oos/PREREG.md`):**
  ```markdown
  - **a. 2023-2026 positive control:** run the same script on `D:\fxmatrix-exports\bars_ftmo\AUDCAD_M1.csv` and verify
    that for all ten cells on `cont-std` and `one-std`, `closes`, `rolled_closes`, `net_usd`, and `net_month_usd` match
    `D:\fxmatrix-exports\fable_review\out\04_ladder_cells_cont.csv` (`sha256` `63052ba31b142d92`) and `_one.csv`
    (`sha256` `d224418cff16c238`) with exact integer equality on `closes`/`rolled_closes` and `|delta| < 1e-6` USD on
    `net_usd` (and match the 2-decimal `net USD/month` values in `reviews/fable_pass1/out/04_ladder_tables_cont.txt` and
    `_one.txt` lines 133-137 and 273-277 within `0.005` USD).
  ```

---

## 4. The data (`s2`)

### 4a. Exporting 2018-2022 with `scripts/grind_bar_dump.mq5` and MT5 limits
- **Verdict:** `CONFIRMED` (with operational notes from `02_TRAPS.md`)
- **Citations:**
  - `research/audcad_oos/PREREG.md:28` `- **Window:** `2018.01.01 00:00` to `2023.01.01 00:00` server time, M1 bars, exported with`
  - `research/audcad_oos/PREREG.md:29` `  `scripts/grind_bar_dump.mq5` (`InpSymbols = "AUDCAD"`, `InpFrom = "2018.01.01 00:00"`,`
  - `research/audcad_oos/PREREG.md:30` `  `InpTo = "2023.01.01 00:00"`) to `D:\fxmatrix-exports\bars_audcad_oos\AUDCAD_M1.csv`.`
  - `scripts/grind_bar_dump.mq5:15` `input string InpSymbols   = "EURUSD,GBPUSD,EURGBP,AUDCAD,AUDCHF,CADCHF";`
  - `scripts/grind_bar_dump.mq5:16` `input string InpFrom      = "2023.01.01 00:00";`
  - `scripts/grind_bar_dump.mq5:17` `input string InpTo        = "2026.10.24 00:00";`
  - `scripts/grind_bar_dump.mq5:39` `   int n = CopyRates(sym, PERIOD_M1, from_t, to_t, rates);`
  - `scripts/grind_bar_dump.mq5:51` `      string fn = StringFormat("bars\\%s_M1.csv", sym);`
  - `handoffs/Handover/02_TRAPS.md:3066` `- **MT5's "Max bars in chart" caps `CopyRates`:** wine-d's terminal returned 99,542 M1 bars (from 20 Jul 2026) for a`
  - `handoffs/Handover/02_TRAPS.md:3068` `  restarts a live fleet: pull long bar history on the desktop's terminal (no EAs; Max bars Unlimited) instead.`
  - `handoffs/Handover/02_TRAPS.md:3073` `  Khan\AppData\Roaming\MetaQuotes\Terminal\81A933A9AFC5DE3C23B15CAB19C63850\MQL5`; its files land in `MQL5\Files` on`
  - `handoffs/Handover/02_TRAPS.md:3074` `  C: (move them to D: at once); its log is `MQL5\Logs\<yyyymmdd>.log`, read with `Select-String -Encoding Unicode`.`
- **Analysis:** `scripts/grind_bar_dump.mq5` has no hard-coded date limit (`CopyRates(sym, PERIOD_M1, from_t, to_t, rates)` on line 39), and the desktop MT5 terminal already has `"Max bars in chart"` set to `Unlimited` (line 3068 of `handoffs/Handover/02_TRAPS.md`), so the ~3.3M bar span back to 2018 is not capped by MT5's chart limit (whereas live Wine boxes are capped at ~100k bars). Note two details: (1) line 51 of `scripts/grind_bar_dump.mq5` writes to `MQL5\Files\bars\AUDCAD_M1.csv` on `C:`, which must be moved to `D:\fxmatrix-exports\bars_audcad_oos\AUDCAD_M1.csv`; and (2) `CopyRates` is inclusive of `to_t`, so although `2023.01.01 00:00` is a Sunday (dropped by `weekday_mask`), `run_oos.py` should assert that no bar has timestamp `>= 1672531200` (`2023-01-01 00:00:00` server) so `2023-01` is never included as a month.

### 4b. Fall-back from FTMO to IC and the 36-month floor (`s2`)
- **Verdict:** `GAP`
- **Citations:**
  - `research/audcad_oos/PREREG.md:25` `- **Source, in order of preference:** (1) the FTMO MT5 terminal on the desktop (`server=FTMO-Demo`), if its`
  - `research/audcad_oos/PREREG.md:26` `  history reaches back to 2020-01-01 or earlier; (2) the IC Markets terminal (`ICMarketsSC-Demo`), same check.`
  - `research/audcad_oos/PREREG.md:27` `  At least 36 calendar months are needed; 60 (all of 2018-2022) is the target.`
  - `reviews/fable_pass1/report_pass1.md:148` `  the spread is 1.12 pips at fills versus 0.95 for the bar field's mean on the same ticks -- a gap of 0.17 pip.`
  - `reviews/fable_pass1/report_pass1.md:591` `pair   arm add | gross pips/close, 4 variants     | cost/close FTMO (IC) | net USD/month (t), yrs+ : cont-std | cont-alt | one-std | one-alt                                   | verdicts`
  - `reviews/fable_pass1/report_pass1.md:598` `AUDCAD OPT  18 | +5.40  +6.66  +7.12  +8.36     | 1.39 (1.03)          |    +4.0 ( +0.6) 2 |    +9.2 ( +1.4) 3 |   +11.2 ( +1.7) 3 |   +16.2 ( +2.7) 4 | I+ I+ I+ P`
  - `reviews/fable_pass1/report_pass1.md:599` `AUDCAD ALT  26 | +10.55  +11.67  +12.75  +14.12     | 1.39 (1.01)          |    +5.3 ( +0.8) 3 |    +8.4 ( +1.2) 3 |   +11.4 ( +1.6) 3 |   +14.8 ( +2.0) 4 | I+ I+ I+ I+`
  - `reviews/fable_pass1/out/00_data_summary.txt:34` `  spread pips: mean=1.24 median=0.90 p10=0.70 p90=1.30 p99=10.40 max=28.3 ; bar range pips: mean=1.43 median=1.20 p90=2.50 p99=5.20`
- **Analysis:** Switching from `FTMO-Demo` to `ICMarketsSC-Demo` changes more than just the file header:
  1. **Tighter baseline spread (~0.36-0.38 pip/close lower cost on IC):** In Fable `S2` (lines 598-599 of `reviews/fable_pass1/report_pass1.md`), `AUDCAD` cost/close is `1.39` pips on FTMO vs `1.01-1.03` pips on IC (~0.37 pip tighter on IC). Running on IC without a spread adjustment makes the net hurdle materially easier to clear than on FTMO.
  2. **Blow-out threshold `thr = max(3.0 * med, 3.0 * pip)` (line 76 of `reviews/fable_pass1/core.py`):** Because IC's median spread is lower (`~0.5-0.6` pip vs FTMO's `0.90` pip in line 34 of `reviews/fable_pass1/out/00_data_summary.txt`), `3.0 * med` drops to the `3.0 * pip` floor on IC vs `2.7` pips on FTMO, changing which widened bars are frozen by `clean = True`.
  3. **Liquidity-provider highs/lows and DST transition weeks:** Different LP feeds produce slightly different M1 wick extrema and zero-spread counts, and if a terminal has only 36 months (3 years), criterion 3 in `s6` needs the `ceil(0.6 * Y)` fix from Item 1c.
- **Smallest fix (append to line 27 of `research/audcad_oos/PREREG.md`):**
  ```markdown
    If the fallback `ICMarketsSC-Demo` feed is used, record the difference between its median spread and FTMO's 2023-2026
    median spread (`0.90` pip in `out/00_data_summary.txt`) in `results.md`, and if IC's median spread is tighter than
    FTMO's by `d_sp > 0`, also report the FTMO-spread-matched run (`bid - 0.5 * d_sp, ask + 0.5 * d_sp`).
  ```

---

## 5. Self-checks `c` and `d` (`s4`)

### 5a. Self-check `c` (data summary and bar defects on 2018-2022)
- **Verdict:** `GAP`
- **Citations:**
  - `research/audcad_oos/PREREG.md:56` `- **c. Data summary on the 2018-2022 file before running the ladder:** bar count, first and last timestamp, months`
  - `research/audcad_oos/PREREG.md:57` `  covered, weekday vs weekend bars, gaps `> 5 min`, `> 60 min`, `> 1 day`, non-increasing timestamps (`<= 0` must be`
  - `research/audcad_oos/PREREG.md:58` `  0), spread quantiles (mean, median, p90, p99, max) overall and by server hour, bar-range quantiles, and daily`
  - `research/audcad_oos/PREREG.md:59` `  close-to-close sigma.`
  - `reviews/fable_pass1/common.py:24` `PIPS = {"EURUSD": 1e-4, "GBPUSD": 1e-4, "EURGBP": 1e-4, "AUDCAD": 1e-4, "AUDCHF": 1e-4, "CADCHF": 1e-4}`
  - `reviews/fable_pass1/common.py:67` `            sp=d[:, 5].astype(np.float64) * (pip * 0.1),`
  - `reviews/fable_pass1/00_data_summary.py:7` `    P(bar_header(pair))`
  - `reviews/fable_pass1/00_data_summary.py:21` `    bad = ((b["h"] < b["l"]) | (b["o"] > b["h"] + 1e-9) | (b["o"] < b["l"] - 1e-9) | (b["c"] > b["h"] + 1e-9) | (b["c"] < b["l"] - 1e-9)).sum()`
  - `reviews/fable_pass1/00_data_summary.py:22` `    P("  ohlc inconsistent bars=%d ; zero-spread bars=%d" % (bad, (b["sp"] <= 0).sum()))`
  - `reviews/fable_pass1/00_data_summary.py:27` `    P("  by year: " + " | ".join("%d bars=%d med_sp=%.2f mean_sp=%.2f mean_rng=%.2f" % (y, (yr == y).sum(), np.median(sp[yr == y]),`
  - `reviews/fable_pass1/out/00_data_summary.txt:31` `# symbol=AUDCAD account=1514878887 server=FTMO-Demo digits=5 point=0.00001000 server_minus_gmt_s=10800 from=2023.01.01 00:00 to=2026.10.24 00:00`
- **Analysis:** Compared against `00_data_summary.py` and `common.load_bars`, self-check `c` in lines 56-59 of `research/audcad_oos/PREREG.md` misses four checks that could silently corrupt the run:
  1. **`digits` and `point` in the CSV header:** Line 67 of `reviews/fable_pass1/common.py` converts the integer `spread` column using `d[:, 5] * (pip * 0.1)`, hard-coding `point = 1e-5` (`digits = 5`). If historical bars were exported with `digits = 4` (`point = 1e-4`), spreads would be understated by 10x. Self-check `c` must assert `digits=5` and `point=0.00001000` in `bar_header`.
  2. **OHLC consistency (`bad == 0`):** Line 21 of `reviews/fable_pass1/00_data_summary.py` checks `(h < l) | (o > h) | (o < l) | (c > h) | (c < l)`, which `PREREG.md` omits.
  3. **Negative and zero spreads (`sp < 0` must be 0, count `sp == 0`):** Line 58 of `research/audcad_oos/PREREG.md` lists `mean, median, p90, p99, max` but omits `min` / `sp < 0` and `sp == 0` (line 22 of `reviews/fable_pass1/00_data_summary.py`).
  4. **Multi-week holes / truncated months:** Counting `gaps > 1 day` (~50 weekends/year) and `months covered` does not catch a multi-week hole inside a month (a month with 500 bars still appears in `months covered` and receives full `1/M` weight in `tstat`). Checking `max(gaps)` (no gap `> 5 days`) and minimum weekday bars per month (e.g. `>= 15,000` bars for every non-boundary month, plus the by-year summary from line 27 of `reviews/fable_pass1/00_data_summary.py`) closes this gap.
- **Smallest fix (replacement text for lines 56-59 of `research/audcad_oos/PREREG.md`):**
  ```markdown
  - **c. Data summary on the 2018-2022 file before running the ladder:** print `bar_header` and assert `digits=5` and
    `point=0.00001000`; report bar count, first and last timestamp (assert last `< 2023-01-01`), months covered and min
    weekday bars per month (assert `>= 15,000` for every full month), weekday vs weekend bars, gaps `> 5 min`, `> 60 min`,
    `> 1 day`, `> 5 days` and `max_gap`, non-increasing timestamps (`<= 0` must be 0), OHLC-inconsistent bars (as in
    `00_data_summary.py`, must be 0), negative-spread bars (`< 0` must be 0) and zero-spread count, spread quantiles (min,
    p10, median, mean, p90, p99, max) overall, by server hour, and by year, bar-range quantiles, and daily close-to-close sigma.
  ```

### 5b. Self-check `d` (random-walk null at 2018-2022 volatility)
- **Verdict:** `GAP`
- **Citations:**
  - `research/audcad_oos/PREREG.md:60` `- **d. Random-walk null at 2018-2022 volatility:** run `01_null_calibration.py`'s check at the 2018-2022 bar-range`
  - `research/audcad_oos/PREREG.md:61` `  scale to confirm that at rungs 17-26 a driftless random walk still gives `|gross per close| <= 0.15` of a rung on`
  - `research/audcad_oos/PREREG.md:62` `  both `std` and `alt` (`reviews/fable_pass1/report_pass1.md` s4.2).`
  - `reviews/fable_pass1/01_null_calibration.py:6` `The bias depends on the ratio of bar range to rung size. EURUSD's median bar range is 1.1 pips (mean 1.44);`
  - `reviews/fable_pass1/01_null_calibration.py:21` `    for a in [3, 4, 5, 7, 9, 10, 14, 18, 23, 30]:`
  - `reviews/fable_pass1/01_null_calibration.py:26` `        os_ = ladder(bs, bs, todb, pb, 1, w, float(a), float(a), s, 2.0, 7, True, 0, 50, False, C0)`
  - `reviews/fable_pass1/01_null_calibration.py:27` `        oa = ladder(ba, ba, todb, pb, 1, w, float(a), float(a), s, 2.0, 7, True, 0, 50, False, C0)`
  - `reviews/fable_pass1/out/01_null_calibration.txt:12` `   30 | 0.4821  0.4821  0.4821 | 0.4821  0.4972 |    698/   698 | -0.1778  -0.1840  -0.1840 |    656/   640`
- **Analysis:**
  1. **Why `d` is needed even with `core.py` unchanged:** As line 6 of `reviews/fable_pass1/01_null_calibration.py` notes, intra-bar order bias (`std` vs `alt`) depends on the ratio of 1-minute bar range to rung size `a`. If 2018-2022 (which includes March 2020) had a larger bar range than 2023-2026, intra-bar order bias could reach higher rungs, so testing at the 2018-2022 bar-range scale is sound.
  2. **Why lines 60-62 of `research/audcad_oos/PREREG.md` have a `GAP`:** Lines 21-27 of `reviews/fable_pass1/01_null_calibration.py` only test `a in [3, 4, 5, 7, 9, 10, 14, 18, 23, 30]` with `exit = a` (omitting `a in {17, 20, 26}` and all five `exit = 2a` cells). Moreover, on a single finite random walk (`400,000` bars), end-of-sample open-inventory mark plus random drift can push `|(real + openp) / (closes * a)|` slightly past `0.15` at wide rungs even when `bar(std)` and `bar(alt)` are identical to the fine-tick truth (see line 12 of `reviews/fable_pass1/out/01_null_calibration.txt` where `a = 30` is `-0.1778` on `fine` and `-0.1840` on `bar(std)` and `bar(alt)`, so `|bar - fine| = 0.0062` of a rung). And for `exit = 2a`, each close is `2a` pips (`1.0` exit unit = `2.0` rungs), so normalizing by `a` instead of `exit` doubles the fluctuation.
- **Smallest fix (replacement text for lines 60-62 of `research/audcad_oos/PREREG.md`):**
  ```markdown
  - **d. Random-walk null at 2018-2022 volatility:** run `01_null_calibration.py`'s check (`400,000` bars, `seed = 20261025`)
    at the 2018-2022 `AUDCAD` mean bar-range scale across all ten cells (`a in {17, 18, 20, 23, 26}, exit in {a, 2a}`)
    to confirm that bar-discretisation bias `|bar(std) - fine|` and intra-bar order divergence `|bar(alt) - bar(std)|`
    are both `<= 0.05` of `exit` per close on every cell, and the 10-cell mean `|gross per close / exit|` is `<= 0.15`
    on both `std` and `alt`.
  ```

---

## 6. Biases (`s7`)

- **Verdict:** `GAP`
- **Citations:**
  - `research/audcad_oos/PREREG.md:75` `- **Swaps / carry are not in the bar simulator** (`reviews/fable_pass1/report_pass1.md` s6.2 item 7, s7). Wide rungs`
  - `research/audcad_oos/PREREG.md:78` `- **The bar spread field is the minute's minimum;** the +0.2 pip/fill sensitivity tests against that.`
  - `reviews/fable_pass1/core.py:75` `    if clean:`
  - `reviews/fable_pass1/core.py:76` `        med = np.median(sp); thr = max(3.0 * med, 3.0 * pip)`
  - `reviews/fable_pass1/common.py:25` `USD = {"EURUSD": 0.10, "GBPUSD": 0.10, "EURGBP": 0.127, "AUDCAD": 0.0714, "AUDCHF": 0.113, "CADCHF": 0.113}`
  - `reviews/fable_pass1/common.py:71` `def weekday_mask(t):`
  - `reviews/fable_pass1/common.py:73` `    dow = ((t // 86400) + 4) % 7`
  - `reviews/fable_pass1/04_ladder_bars.py:65` `    tod = ((tm // 60000) % 1440).astype(np.int64)`
  - `reviews/fable_pass1/core.py:259` `        pause = (tod >= 1430) or (tod < 15)`
  - `reviews/fable_pass1/report_pass1.md:955` `- The effect on AUDCAD is the pair having ranged. A grid is by construction long "the range holds". Whether`
  - `reviews/fable_pass1/report_pass1.md:1014` `6. **`run_bars.py` drops holiday-short weeks,** which are the thin, gappy ones; harmless but it flatters a grid.`
- **Analysis:** Four biases in the 2018-2022 bar test are missing from `s7`:
  1. **Single 5-year pooled median spread in the blow-out filter (line 76 of `reviews/fable_pass1/core.py`):** `med = np.median(sp)` is computed once across the entire 2018-2022 array. If baseline spreads shifted across years (e.g. wider in 2018-2020 than in 2021-2022), a single 5-year median over-freezes active bars in high-spread years and under-freezes rollover bars in low-spread years.
  2. **Holiday-short weeks and thin holiday bars are kept (lines 71-74 of `reviews/fable_pass1/common.py`, line 1014 of `reviews/fable_pass1/report_pass1.md`):** `weekday_mask` keeps all Monday-Friday bars including Christmas/New Year thin sessions and post-holiday opens.
  3. **Server clock across DST transitions in 2018-2022 (line 65 of `reviews/fable_pass1/04_ladder_bars.py`, line 259 of `reviews/fable_pass1/core.py`):** `tod_min` assumes server `00:00` is always New York 17:00 rollover (`pause` at `23:50-00:15` and `tod == 0` in `bars_to_ticks`). During any US/EU DST mismatch weeks in 2018-2022 (or if a broker's historical server offset changed), rollover bars outside `tod == 0` are frozen only if `sp > thr`.
  4. **2018-2022 macro/volatility regime and fixed `USD["AUDCAD"] = 0.0714` (line 25 of `reviews/fable_pass1/common.py`, line 955 of `reviews/fable_pass1/report_pass1.md`):** `2018-2022` includes the 2018-2019 trend and the March 2020 COVID crash/rebound (~1,800-pip range vs 2023-2026's ~500-pip range), testing whether the grid survives a major dislocation. Also, `USD["AUDCAD"] = 0.0714` (`USDCAD ~ 1.40`) is slightly below 2018-2022's average `1 / USDCAD` (`~0.075-0.079` at `USDCAD ~ 1.26-1.34`), making the fixed `$0.06` commission slightly heavier in pips (~5-9% conservative).
- **Smallest fix (append to line 78 of `research/audcad_oos/PREREG.md`):**
  ```markdown
  - **Whole-file median spread in `bars_to_ticks` (`core.py`):** `med = np.median(sp)` is taken across the entire
    2018-2022 file rather than by year; self-check `c` reports `med_sp` by year so any cross-year spread shift is visible.
  - **Holidays and server DST (`common.py`, `core.py`):** `weekday_mask` keeps thin weekday holidays, and `tod_min`
    assumes server `00:00` is always NY 17:00 rollover; self-check `c`'s hourly median spread profile checks whether
    rollover stayed in hour `0`.
  - **2018-2022 volatility regime and fixed pip value (`common.py`):** 2018-2022 includes the March 2020 COVID shock,
    and `USD["AUDCAD"] = 0.0714` (`USDCAD = 1.40`) values pips ~5-9% lower against the fixed `$0.06` commission than
    2018-2022 spot `USDCAD` (~1.26-1.34), which is slightly conservative.
  ```

---

## 7. Order of work (`s8`)

- **Verdict:** `DEFECT`
- **Citations:**
  - `research/audcad_oos/PREREG.md:83` `3. Write `research/audcad_oos/run_oos.py` importing `reviews/fable_pass1/core.py` and `common.py`. Run self-checks`
  - `research/audcad_oos/PREREG.md:84` `   `a`-`d` first; stop if any fails.`
  - `research/audcad_oos/PREREG.md:85` `4. Run the ten cells across the four variants and the sensitivity on 2018-2022. Write`
  - `research/audcad_oos/PREREG.md:86` `   `research/audcad_oos/results.md` with the self-check output, the 10-cell table, the by-year table, the region`
- **Analysis:** Because steps 3 and 4 both use `research/audcad_oos/run_oos.py`, a single script without mode separation will run self-checks `a`-`d` and immediately proceed to run and print the 2018-2022 OOS ladder in the same invocation before the human or agent has inspected the data summary (`c`, where several items such as hourly spread profile and year-by-year bar counts are diagnostic tables) and null calibration (`d`). Requiring a two-stage CLI gate (`python research/audcad_oos/run_oos.py --selfcheck` in step 3, which executes only `a`-`d` with hard `assert` gates and exits before loading 2018-2022 into `core.ladder`, followed by `python research/audcad_oos/run_oos.py --oos` in step 4) makes it impossible to see the 2018-2022 ladder numbers before `a`-`d` are verified.
- **Smallest fix (replacement text for lines 83-85 of `research/audcad_oos/PREREG.md`):**
  ```markdown
  3. Write `research/audcad_oos/run_oos.py` importing `reviews/fable_pass1/core.py` and `common.py` with two CLI modes:
     `--selfcheck` (runs only self-checks `a`-`d` with programmatic `assert` gates and exits without calling `core.ladder`
     on the 2018-2022 bars) and `--oos` (runs `a`-`d` assertions and then the 2018-2022 ladder). Run
     `python research/audcad_oos/run_oos.py --selfcheck` first and verify all four checks pass; stop if any fails.
  4. Run `python research/audcad_oos/run_oos.py --oos` to evaluate the ten cells across the four variants and the
     sensitivity on 2018-2022. Write
  ```

---

**SOUND WITH CHANGES** (1. In `s6`, replace `At least 3 of the 5 years` with `At least ceil(0.6 * Y) of the Y full calendar years` (`>= 6` months) and specify that annual region net is the sum of monthly mark-to-market region nets as in `04_ladder_bars.py`; 2. In `s3`, clarify that `bid - 0.2 * PIP, ask + 0.2 * PIP` widens `core.ladder`'s trigger/roll/clamp spread by `+0.4` pip per round trip while `mkt_fill = False` still fills at the limit price, report the direct `-0.4` pip/close fill-price adjustment alongside, and pin `reroll = True, gate = 0, max_reroll_tick = 50, mkt_fill = False`; 3. In `s4 a` and `s2`, point to `D:\fxmatrix-exports\fable_review\out\04_ladder_cells_cont.csv` and `_one.csv` for the 10-cell integer `closes`/`rolled_closes` and `net_usd` (noting `04_ladder_tables_*.txt` is in-repo with 2-decimal `net USD/month`), and log/match spread if the IC fallback feed is used; 4. In `s4 c-d` and `s7`, assert `digits=5, point=0.00001000`, `ohlc_inconsistent == 0`, `sp < 0 == 0`, `min_bars_per_month >= 15,000`, test all 10 cells in the random-walk null, and list the whole-file median spread, holiday, DST, and `USD["AUDCAD"]` biases; 5. In `s8`, gate step 3 with `run_oos.py --selfcheck` so `a`-`d` are verified before `--oos` runs `core.ladder` on 2018-2022.)

Line count: 353
