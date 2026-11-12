This message has a line count at the bottom

# ARGON: THIRD REVIEW -- THE AUDCAD AMENDMENT (s2a), THE RUNNER AND THE SELF-CHECKS

| | |
|---|---|
| Reviewer | Argon |
| Date | 2026-11-11 |
| Branch | `review/argon-audcad-oos-3` |
| Base commit (`origin/main`) | `1c9efd8f5a0b1b031a4cda05495d24fb2cc700a6` |
| Documents read at `origin/main` | `research/audcad_oos/PREREG.md` (lines 1-128); `research/audcad_oos/run_oos.py` (lines 1-328); `research/audcad_oos/test_run_oos.py` (lines 1-79); `research/audcad_oos/selfcheck_out.txt` (lines 1-50); `research/audcad_oos/MANIFEST.md` (lines 1-16); `prompts/argon_review_audcad_oos_3.md` (lines 1-44) |
| Sources read at `origin/main` | `reviews/fable_pass1/core.py` (lines 1-337); `reviews/fable_pass1/common.py` (lines 1-127); `reviews/fable_pass1/04_ladder_bars.py` (lines 1-102); `reviews/fable_pass1/01_null_calibration.py` (lines 1-50); `reviews/fable_pass1/test_core.py` (lines 1-49) |
| Bar files opened | None |

---

## 1. s2a's JUSTIFICATION, COMMIT ORDER, AND SLICE RULE

- **Verdict:** **CONFIRMED**

### Evidence (`origin/main`)
- research/audcad_oos/selfcheck_out.txt:31 `c  bars 1854026, first 2018-01-02 00:02:00, last 2022-12-30 23:54:00; months 60; bars by year 2018 371885, 2019 371500, 2020 371568, 2021 371680, 2022 367393`
- research/audcad_oos/selfcheck_out.txt:32 `c  OHLC inconsistent 0; negative spread 0; months under 15000 bars: none`
- research/audcad_oos/selfcheck_out.txt:33 `c  blow-out bars 24.80%; median recorded spread 0.80 pip overall, 0.70 in server hours 2-21`
- research/audcad_oos/selfcheck_out.txt:34 `c  2018: median spread 1.40 pip (hours 2-21: 1.10), blow-out bars 46.74% (hours 2-21: 44.63%)`
- research/audcad_oos/selfcheck_out.txt:35 `c  2019: median spread 4.00 pip (hours 2-21: 4.00), blow-out bars 54.10% (hours 2-21: 51.65%)`
- research/audcad_oos/selfcheck_out.txt:36 `c  2020: median spread 0.40 pip (hours 2-21: 0.40), blow-out bars 12.13% (hours 2-21: 10.10%)`
- research/audcad_oos/selfcheck_out.txt:37 `c  2021: median spread 0.40 pip (hours 2-21: 0.40), blow-out bars 7.21% (hours 2-21: 3.98%)`
- research/audcad_oos/selfcheck_out.txt:38 `c  2022: median spread 0.60 pip (hours 2-21: 0.60), blow-out bars 3.55% (hours 2-21: 0.27%)`
- research/audcad_oos/selfcheck_out.txt:39 `c  months dropped from the statistics (s4 c): 0`
- research/audcad_oos/PREREG.md:25 `- **Feed:** FTMO-Demo, the in-sample feed and the venue of the live remainder, if its history reaches back to`
- research/audcad_oos/PREREG.md:26 `  2020-01-01 or earlier; otherwise an IC Markets demo login on the same terminal. **At least 36 calendar months** are`
- research/audcad_oos/PREREG.md:31 `## 2a. AMENDMENT (11 Nov, after self-check c, before any ladder run on the new bars)`
- research/audcad_oos/PREREG.md:34 `  **1.4 pips in 2018 and 4.0 in 2019** (2020: 0.4, 2021: 0.4, 2022: 0.6; in sample 2023-2026: 0.8-1.0), and the`
- research/audcad_oos/PREREG.md:35 `  blow-out rule flags **47% and 54%** of their bars (2020-2022: 12%, 7%, 4%; in sample 4%). Run as registered, those`
- research/audcad_oos/PREREG.md:36 `  two years would charge two to four times the in-sample spread on every fill and freeze half the price path: a`
- research/audcad_oos/PREREG.md:37 `  verdict driven by the feed's old spread field, not by the region.`
- research/audcad_oos/PREREG.md:38 `- **The operator's ruling (11 Nov, before any result):** **2020-01-01 to 2022-12-31 decides**: 36 months, s2's own`
- research/audcad_oos/PREREG.md:39 `  floor. The ladder runs on those bars alone, from flat at the first bar of 2020 (so nothing is carried in from`
- research/audcad_oos/PREREG.md:41 `  **2018-2019 is run the same way on its own bars and reported beside it, as a description under this caveat; it does`
- research/audcad_oos/PREREG.md:42 `  not decide.** The null (s4 d) takes the 2020-2022 bars' median range.`
- reviews/fable_pass1/common.py:72 `    sp = b["sp"] / PIP`
- reviews/fable_pass1/common.py:73 `    med = np.median(sp)`
- reviews/fable_pass1/common.py:74 `    return sp > max(3.0 * med, med + 1.0)`
- reviews/fable_pass1/common.py:101 `    bo = np.repeat(blowout_mask(b)[m], 4)`
- reviews/fable_pass1/common.py:105 `    mid = mid[last]`
- reviews/fable_pass1/common.py:106 `    return tm, mid - 0.5 * spr, mid + 0.5 * spr`

### Assessment
1. **Per-year lines in `selfcheck_out.txt` support s2a:** Lines 34-38 of `research/audcad_oos/selfcheck_out.txt` show that FTMO's stored M1 history has a median recorded spread of `1.40` pips in 2018 (`1.10` in server hours 2-21) and `4.00` pips in 2019 (`4.00` in server hours 2-21), versus `0.40`, `0.40`, and `0.60` pips in 2020-2022. Under the 5-year pooled median spread (`0.80` pip, giving a blow-out threshold of `2.40` pips), `46.74%` of 2018 bars (`44.63%` in hours 2-21) and `54.10%` of 2019 bars (`51.65%` in hours 2-21) are flagged as blow-outs. In `common.pseudo_ticks` (lines 101-106 of `reviews/fable_pass1/common.py`), blow-out bars freeze the mid price at the last normal bar while keeping `spr` on bid/ask, so including 2018-2019 in a pooled 5-year run would freeze roughly half the price path in those two years and charge `1.4-4.0` pips on fills. Restricting the deciding window to `2020-2022` (36 calendar months) satisfies the pre-registered 36-month floor and the `2020-01-01` FTMO cutoff in s2 (lines 25-26 of `research/audcad_oos/PREREG.md`).
2. **Commit order (`git log --oneline -6 -- research/audcad_oos/`):**
   - `c511c90` (`s93i`): initial `PREREG.md`.
   - `f067c6e` (`s93j`): `PREREG.md` amended after Argon 1.
   - `b2bdb5f`: `MANIFEST.md` (hash and header of the new bar file only), `run_oos.py` stub, and `test_run_oos.py` (6 tests failing against stub).
   - `5de5e7a`: `run_oos.py` implemented (`--selfcheck` and `--oos` gated on committed `selfcheck_out.txt`).
   - `f9fd8da`: `PREREG.md` s2a amendment, `run_oos.py` slice and tick-by-tick null update, `test_run_oos.py` (7/7 tests).
   - `18e3ac2`: `selfcheck_out.txt` committed (the commit on `origin/main` corresponding to the prompt's `b1feed9` reference).
   No commit in the repository (`c511c90` through `1c9efd8`) holds any ladder result on 2018-2022 (`oos_result.json` and `results.md` do not exist), and `--selfcheck` never runs `core.ladder` on the new bars.
3. **"From flat at the first bar of 2020, the subset's own blow-out median":**
   - Running `2020-2022` from flat on its own slice is the right way to cut it: carrying open layers or rolled effective entries out of the corrupted 2018-2019 feed into `2020-01-01` would contaminate 2020's starting state and first-month mark-to-market change (`d = np.diff(np.r_[0.0, eq])`), and had FTMO's export started at `2020-01-01` (s2's explicit cutoff), `2020-2022` would have been run from flat with `blowout_mask` computed on `2020-2022` alone.
   - One mechanical consequence of computing `blowout_mask` on each slice separately that s2a does not explicitly note: in `check_c` (line 203 of `research/audcad_oos/run_oos.py`), `bo = common.blowout_mask(b)` was computed on the **pooled 2018-2022 file** (`med = 0.80` pip, threshold `max(3.0 * 0.80, 0.80 + 1.0) = 2.40` pips), which produced the per-year blow-out percentages in `selfcheck_out.txt` lines 34-38 (`46.74%`, `54.10%`, `12.13%`, `7.21%`, `3.55%`). When `oos()` slices `2020-2022` and passes that subset to `common.pseudo_ticks`, `med` is the `2020-2022` median (`0.40` pip), lowering the blow-out threshold from `2.40` pips to `0.40 + 1.0 = 1.40` pips (freezing bars with spread in `(1.40, 2.40]` pips as well). Conversely, when `2018-2019` is run on its own slice, its subset median spread is `~2.7-3.5` pips, raising its blow-out threshold to `3.0 * med` (`~8-10.5` pips) so that far fewer than 47%-54% of bars are frozen in the `2018-2019` descriptive run. This does not require changing `run_oos.py` (which uses Fable's `common.pseudo_ticks` unchanged as required by s3), but should be kept in mind when reading `results.md` (see Item 4).

---

## 2. THE RUNNER (`run_oos.py`) AGAINST `PREREG.md`

- **Verdict:** **CONFIRMED**

### Evidence (`origin/main`)
- research/audcad_oos/run_oos.py:31 `PAIR = "AUDCAD"`
- research/audcad_oos/run_oos.py:32 `ADDS = (17, 18, 20, 23, 26)`
- research/audcad_oos/run_oos.py:33 `CELLS = [(a, x) for a in ADDS for x in (a, 2 * a)]      # (add, exit): exit = a or 2a (s3)`
- research/audcad_oos/run_oos.py:34 `VARIANTS = (("cont", "std"), ("cont", "alt"), ("one", "std"), ("one", "alt"))`
- research/audcad_oos/run_oos.py:35 `SENS_PIPS_PER_CLOSE = 0.4                                # every fill 0.2 pip worse, entry and exit (s3)`
- research/audcad_oos/run_oos.py:36 `GATE_LINE = "SELFCHECK: a PASS, b PASS, c PASS, d DONE"`
- research/audcad_oos/run_oos.py:37 `FABLE_HASH = {"cont": "63052ba31b142d92", "one": "d224418cff16c238"}`
- research/audcad_oos/run_oos.py:38 `MIN_BARS_MONTH = 15000`
- research/audcad_oos/run_oos.py:42 `def years_needed(y):`
- research/audcad_oos/run_oos.py:43 `    return int(math.ceil(0.6 * y - 1e-12))`
- research/audcad_oos/run_oos.py:46 `def passes(r):`
- research/audcad_oos/run_oos.py:47 `    return (r["mean"] > 0 and r["t"] >= 2.0 and r["years_pos"] >= years_needed(r["years"])`
- research/audcad_oos/run_oos.py:48 `            and r["cells_pos"] >= 7)`
- research/audcad_oos/run_oos.py:51 `def decide(base, sens):`
- research/audcad_oos/run_oos.py:53 `    if not base["mean"] > 0:`
- research/audcad_oos/run_oos.py:54 `        return "FAILS"`
- research/audcad_oos/run_oos.py:55 `    if not passes(base):`
- research/audcad_oos/run_oos.py:56 `        return "INCONCLUSIVE"`
- research/audcad_oos/run_oos.py:57 `    return "HOLDS" if passes(sens) else "FRAGILE"`
- research/audcad_oos/run_oos.py:60 `def gate_ok(text):`
- research/audcad_oos/run_oos.py:61 `    return bool(text) and GATE_LINE in text`
- research/audcad_oos/run_oos.py:64 `def slice_bars(b, y0, y1):`
- research/audcad_oos/run_oos.py:66 `    yr = pd.to_datetime(b["t"], unit="s").year.values`
- research/audcad_oos/run_oos.py:67 `    m = (yr >= y0) & (yr <= y1)`
- research/audcad_oos/run_oos.py:68 `    return {k: v[m] for k, v in b.items()}`
- research/audcad_oos/run_oos.py:71 `DECIDE = (2020, 2022)                                    # PREREG s2a: decides`
- research/audcad_oos/run_oos.py:72 `REPORT = (2018, 2019)                                    # PREREG s2a: reported beside it, does not decide`
- research/audcad_oos/run_oos.py:105 `    tm, bid, ask = common.pseudo_ticks(b, order, True)`
- research/audcad_oos/run_oos.py:114 `        o = core.ladder(bid, ask, tod, per, nper, a / 4.0, float(a), float(x), a / 4.0 + 1, 2.0, 7, True, 0, 50,`
- research/audcad_oos/run_oos.py:115 `                        False, c0, fill == "one")`
- research/audcad_oos/run_oos.py:116 `        st, d, net = summarise(PAIR, o, float(a), um, years)`
- research/audcad_oos/run_oos.py:117 `        dc = np.diff(np.r_[0, o[2]])`
- research/audcad_oos/run_oos.py:123 `    usd = 0.0714                                          # common.USD["AUDCAD"]`
- research/audcad_oos/run_oos.py:126 `        n = cells[k]["net"] - (SENS_PIPS_PER_CLOSE * usd * cells[k]["closes_m"] if sens else 0.0)`
- research/audcad_oos/run_oos.py:128 `    m = np.vstack(rows)[:, keep]`
- research/audcad_oos/run_oos.py:129 `    reg = m.mean(axis=0)`
- research/audcad_oos/run_oos.py:131 `    mean = float(reg.mean())`
- research/audcad_oos/run_oos.py:132 `    se = float(reg.std(ddof=1) / math.sqrt(len(reg)))`
- research/audcad_oos/run_oos.py:133 `    t = mean / se if se > 0 else float("nan")`
- research/audcad_oos/run_oos.py:137 `        if sel.sum() >= 6:`
- research/audcad_oos/run_oos.py:138 `            by_year[int(y)] = float(reg[sel].sum())`
- research/audcad_oos/run_oos.py:290 `    p = subprocess.run(["git", "-C", REPO, "show", "origin/main:research/audcad_oos/selfcheck_out.txt"],`
- research/audcad_oos/run_oos.py:292 `    if p.returncode != 0 or not gate_ok(p.stdout):`
- research/audcad_oos/run_oos.py:293 `        sys.exit("OOS|REFUSED|selfcheck_out.txt is not on origin/main or does not read all PASS (PREREG s8)")`
- research/audcad_oos/run_oos.py:297 `    for label, (y0, y1) in (("2020-2022 (decides)", DECIDE), ("2018-2019 (reported only)", REPORT)):`
- research/audcad_oos/run_oos.py:298 `        b = slice_bars(full, y0, y1)                     # from flat at the first bar of y0 (s2a)`
- research/audcad_oos/run_oos.py:315 `    d = res["2020-2022 (decides)"]["cont-std"]`
- research/audcad_oos/run_oos.py:316 `    verdict = decide(d["base"], d["sens"])`
- reviews/fable_pass1/04_ladder_bars.py:34 `        o = ladder(bid, ask, tod, per, nper, w, a, x, strd, 2.0, cap, True, 0, 50, False, C0, ONE)`
- research/audcad_oos/test_run_oos.py:20 `    assert [ro.years_needed(y) for y in (3, 4, 5)] == [2, 3, 3]`
- research/audcad_oos/test_run_oos.py:29 `    assert ro.decide(r(12.0, 2.0, 2, 3, 7), good) == "HOLDS"             # Y = 3 needs 2; t exactly 2.0`
- research/audcad_oos/test_run_oos.py:76 `    s = ro.slice_bars(b, 2020, 2022)`
- research/audcad_oos/test_run_oos.py:77 `    assert list(s["t"]) == [1577836800, 1609459199, 1609459200, 1672531199]`

### Assessment
Every component of `research/audcad_oos/run_oos.py` matches `research/audcad_oos/PREREG.md`:
1. **`ladder` call (s3):** Lines 114-115 of `run_oos.py` call `core.ladder(bid, ask, tod, per, nper, a / 4.0, float(a), float(x), a / 4.0 + 1, 2.0, 7, True, 0, 50, False, c0, fill == "one")`, matching line 34 of `reviews/fable_pass1/04_ladder_bars.py` and `PREREG.md` line 54.
2. **Ten cells and four variants (s3):** `ADDS = (17, 18, 20, 23, 26)`, `CELLS = [(a, x) for a in ADDS for x in (a, 2 * a)]`, `VARIANTS = (("cont", "std"), ("cont", "alt"), ("one", "std"), ("one", "alt"))`, and `common.pseudo_ticks(b, order, True)` (`clean=True`).
3. **Sensitivity (s3):** `SENS_PIPS_PER_CLOSE = 0.4` and `usd = 0.0714`, subtracting `0.4 * 0.0714 * closes_m` from each cell's monthly net USD (`PREREG.md` line 59).
4. **Region, years, and cells rules (s6):** `region` filters months by `keep` (`>= 15000` bars), averages the ten cells' monthly net USD (`reg = m.mean(axis=0)`), computes `mean`, `se` (`ddof=1`), and `t = mean / se`, sums `reg` within each calendar year having `>= 6` counted months (`sel.sum() >= 6`), and counts cells with positive total net USD (`cells_pos`). `years_needed`, `passes`, and `decide` implement rules 1-4 and the `HOLDS` / `FRAGILE` / `INCONCLUSIVE` / `FAILS` classification (`PREREG.md` lines 88-96).
5. **`slice_bars` and decide/report periods (s2a):** `slice_bars` filters server-clock years `y0..y1`; `oos()` runs `DECIDE = (2020, 2022)` and `REPORT = (2018, 2019)` each from flat on its own slice, and computes `verdict = decide(d["base"], d["sens"])` on `res["2020-2022 (decides)"]["cont-std"]`.
6. **Gate (s8):** `oos()` runs `git -C REPO show origin/main:research/audcad_oos/selfcheck_out.txt` and exits with `OOS|REFUSED|...` unless `SELFCHECK: a PASS, b PASS, c PASS, d DONE` is present in the committed output on `origin/main`.

---

## 3. THE SELF-CHECKS (`a`, `b`, `c`, `d`) AND THE NULL CALIBRATION

- **Verdict:** **CONFIRMED**

### Evidence (`origin/main`)
- research/audcad_oos/selfcheck_out.txt:1 `a  cont 17/17  closes  4394/ 4394  rolled  504/ 504  rolls   581/  581  net   +463.85/  +463.85  same`
- research/audcad_oos/selfcheck_out.txt:6 `a  cont 20/40  closes  1524/ 1524  rolled  290/ 290  rolls   357/  357  net   +884.25/  +884.25  same`
- research/audcad_oos/selfcheck_out.txt:11 `a  one  17/17  closes  4591/ 4591  rolled  519/ 519  rolls   577/  577  net   +641.09/  +641.09  same`
- research/audcad_oos/selfcheck_out.txt:20 `a  one  26/52  closes   888/  888  rolled  157/ 157  rolls   208/  208  net   +655.14/  +655.14  same`
- research/audcad_oos/selfcheck_out.txt:26 `b  all tests passed`
- research/audcad_oos/selfcheck_out.txt:27 `b  test_core.py exit 0`
- research/audcad_oos/selfcheck_out.txt:28 `c  header symbol=AUDCAD      ok`
- research/audcad_oos/selfcheck_out.txt:29 `c  header digits=5           ok`
- research/audcad_oos/selfcheck_out.txt:30 `c  header point=0.00001000   ok`
- research/audcad_oos/selfcheck_out.txt:40 `d  2020-2022 median weekday bar range 1.40 pips; lattice walk 100 steps a bar (median range 1.40), 400000 bars`
- research/audcad_oos/selfcheck_out.txt:41 `d  fine (tick by tick) gross per close, in rungs, ten cells: -0.298 -0.229 -0.282 -0.356 -0.281 -0.302 -0.222 -0.317 -0.280 -0.470`
- research/audcad_oos/selfcheck_out.txt:42 `d  cont-std gross per close, in rungs, ten cells: -0.244 -0.235 -0.270 -0.470 -0.276 -0.254 -0.235 -0.296 -0.307 -0.470`
- research/audcad_oos/selfcheck_out.txt:43 `d  cont-std bias (bars - fine), in rungs:         +0.054 -0.006 +0.012 -0.114 +0.005 +0.048 -0.014 +0.021 -0.027 +0.000`
- research/audcad_oos/selfcheck_out.txt:45 `d  cont-alt bias (bars - fine), in rungs:         +0.054 -0.006 +0.012 -0.114 +0.005 +0.048 -0.014 +0.021 -0.027 +0.000`
- research/audcad_oos/selfcheck_out.txt:47 `d  one-std bias (bars - fine), in rungs:         +0.150 +0.081 +0.120 -0.109 +0.101 +0.048 +0.012 +0.029 -0.008 -0.010`
- research/audcad_oos/selfcheck_out.txt:49 `d  one-alt bias (bars - fine), in rungs:         +0.150 +0.081 +0.120 -0.109 +0.101 +0.048 +0.012 +0.029 -0.008 -0.010`
- research/audcad_oos/selfcheck_out.txt:50 `SELFCHECK: a PASS, b PASS, c PASS, d DONE`
- research/audcad_oos/run_oos.py:168 `            same = (int(r["closes"]) == s["closes"] and int(r["rolled_closes"]) == s["rolled_closes"]`
- research/audcad_oos/run_oos.py:169 `                    and int(r["rolls"]) == s["rolls"] and abs(float(r["net_usd"]) - s["net_usd"]) < 0.005)`
- research/audcad_oos/run_oos.py:225 `    b = slice_bars(load_bars_file(path), *DECIDE)`
- research/audcad_oos/run_oos.py:248 `        lo = core.ladder(x, x, tod_f, per_f, per_f[-1] + 1, w, float(a), float(xx), w + 1, 2.0, 7, True, 0, 50,`
- research/audcad_oos/run_oos.py:249 `                         False, np.zeros((0, 7)), False)`
- research/audcad_oos/run_oos.py:250 `        fine.append((lo[0] + lo[1])[-1] / max(lo[2][-1], 1) / a)`
- research/audcad_oos/run_oos.py:274 `                  % (fill, order, " ".join("%+.3f" % (v - f) for v, f in zip(res, fine))))`
- reviews/fable_pass1/01_null_calibration.py:34 `    x = np.round(1.1 + np.cumsum(rng.choice(np.array([-1e-5, 1e-5]), k * nb)), 5)`
- reviews/fable_pass1/01_null_calibration.py:40 `        for name, p in (("fine", x), ("std", pticks(o, h, l, c, "std")), ("alt", pticks(o, h, l, c, "alt"))):`
- reviews/fable_pass1/01_null_calibration.py:45 `            tot, cl = lad(p, a, max(len(p) // 40, 1))`
- reviews/fable_pass1/01_null_calibration.py:46 `            res.append((r, len(d), tot / max(cl, 1) / a, cl, r_act))`

### Assessment
1. **Self-checks a, b, c:**
   - **a:** Verifies SHA-256 prefixes `63052ba31b142d92` (`cont`) and `d224418cff16c238` (`one`) and reproduces all 20 in-sample `AUDCAD` `std` cells (10 `cont` + 10 `one`) with identical `closes`, `rolled_closes`, `rolls`, and `net_usd` to the cent.
   - **b:** Runs `reviews/fable_pass1/test_core.py` unchanged with exit code `0`.
   - **c:** Confirms header tokens, `1,854,026` bars across 60 complete months (`0` dropped), `0` OHLC inconsistencies, `0` negative spreads, and reports overall and per-year spreads and blow-out shares.
2. **Self-check d and its commit-message reading (`18e3ac2`):**
   - `check_d` (lines 221-275 of `research/audcad_oos/run_oos.py`) now runs `core.ladder` on the fine `+/- 0.1` pip lattice walk `x` tick by tick (lines 243-252) and subtracts `fine` from each bar variant's gross per close (`v - f`, line 274) on the exact same walk, matching `reviews/fable_pass1/01_null_calibration.py` (lines 34-48).
   - Because each bar has median range `1.40` pips (`k = 100` steps of `0.1` pip) while rungs are `17-26` pips (`width >= 4.25` pips), a single bar's `[low, high]` span is much smaller than the rung and exit distances, so `std` and `alt` produce identical results, and the `cont-std` bar-minus-fine difference across the ten cells ranges from `-0.114` rungs/close (`18/36`) to `+0.054` rungs/close (`17/17`), with a 10-cell mean of `+0.0019` rungs/close. Meanwhile `one-std` and `one-alt` show a positive bar-approximation bias on the `exit = a` cells (`+0.150, +0.120, +0.101, +0.012, -0.008` rungs/close). The commit message's reading (`in cont-std -0.11 to +0.05 rungs a close`) is accurate and fair.

---

## 4. ANY UNSTATED BIAS IN A 2020-2022 VERDICT (s7)

- **Verdict:** **CONFIRMED**

### Evidence (`origin/main`)
- research/audcad_oos/PREREG.md:111 `- **Three years, not five (s2a):** at the in-sample effect (about +15 USD a month) and its monthly scatter, t >= 2.0`
- research/audcad_oos/PREREG.md:112 `  over 36 months is reachable but not certain; a real effect can come out INCONCLUSIVE. 2020-2022's spreads (0.4-0.6`
- research/audcad_oos/PREREG.md:113 `  pip) are narrower than the in-sample's (0.8-1.0), which favours the region by a few tenths of a pip a fill; the`
- research/audcad_oos/PREREG.md:114 `  0.2 pip sensitivity covers about that.`
- research/audcad_oos/PREREG.md:115 `- **Fixed constants from the in-sample code:** USD per pip 0.0714 (USDCAD ranged about 1.25-1.45 in 2018-2022, so`
- research/audcad_oos/PREREG.md:116 `  the true value moved by up to about 8%); the blow-out threshold is the new file's own median spread`
- research/audcad_oos/selfcheck_out.txt:36 `c  2020: median spread 0.40 pip (hours 2-21: 0.40), blow-out bars 12.13% (hours 2-21: 10.10%)`
- research/audcad_oos/selfcheck_out.txt:37 `c  2021: median spread 0.40 pip (hours 2-21: 0.40), blow-out bars 7.21% (hours 2-21: 3.98%)`
- research/audcad_oos/selfcheck_out.txt:38 `c  2022: median spread 0.60 pip (hours 2-21: 0.60), blow-out bars 3.55% (hours 2-21: 0.27%)`

### Assessment
`research/audcad_oos/PREREG.md` s7 (lines 111-118) already states the two main consequences of s2a: (1) reduced statistical power over 36 months (`t >= 2.0` on 36 months is harder to reach for a true `+15` USD/month effect, while rule 3 requires `2` of `3` positive years), and (2) `2020-2022`'s narrower stored median spreads (`0.4-0.6` pip vs `0.8-1.0` pip in sample, partially offset by the `0.2` pip/fill = `0.4` pip/close sensitivity). Two secondary points from `selfcheck_out.txt` are worth noting when interpreting `results.md`, though neither requires amending `PREREG.md` or `run_oos.py`:
1. **Core-hour blow-outs in 2020 (`10.10%` in server hours 2-21 at the 2.40-pip threshold, and higher under `2020-2022`'s `1.40`-pip subset threshold):** In 2022 (`0.27%` in hours 2-21) and in sample 2023-2026, `blowout_mask` freezes almost exclusively rollover bars (`23:55-01:05`). In 2020 (`selfcheck_out.txt` line 36), `10.10%` of core-hour bars had spreads above `2.40` pips (and when `2020-2022` is run on its own slice with `med = 0.40` pip, `blowout_mask` freezes bars with spread `> 1.40` pips), so daytime volatility/liquidity spikes in 2020 have their mid frozen until the spread returns to `<= 1.40` pips.
2. **Spread gap in 2020-2021 vs sensitivity size:** In 2020 and 2021 (`median spread 0.40 pip` vs `0.8-1.0 pip` in sample), the recorded spread is `0.4-0.6` pip narrower than in sample (`0.2-0.3` pip per fill, plus the minimum-of-minute understatement of `0.06-0.17` pip per fill), so the `0.2` pip/fill sensitivity (`0.4` pip per close) is a necessary floor rather than a conservative upper bound on 2020-2021 execution costs.

---

**SOUND**

Line count: 204
