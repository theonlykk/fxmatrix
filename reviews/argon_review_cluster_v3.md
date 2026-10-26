This message has a line count at the bottom

# Argon Review v3: `research/cluster/PREREG.md` (Round Numbers in FX -- An Osler Replication, v3)

- **Branch:** `review/argon-cluster-v3`
- **Base commit (`origin/main`):** `f0459b77de4bc4c3ba5d1097cde417dbe60376c6`
- **v2 review commit (`origin/review/argon-cluster-v2`):** `1bc232dc1b51eb01a7e3a2df256fa52dd3355ff1`
- **Files read (at `origin/main` unless noted):**
  - `prompts/argon_review_cluster_v3.md` (lines 1-46)
  - `research/cluster/PREREG.md` (lines 1-119)
  - `scripts/grind_bar_dump.mq5` (lines 1-101; sha256 `a5370e009b4aa46e534879e98aa994e51f72b35a362e35a5cc8ad5d95f0187e9`)
  - `research/opt_budget/PREREG_CAP.md` (lines 1-42)
  - `reviews/argon_review_cluster_v2.md` at `origin/review/argon-cluster-v2` (lines 1-438)
- **Files NOT read:**
  - `D:\fxmatrix-exports\bars_ftmo` bar CSV files (**NOT READ**, per Rule 3)
  - `D:\mt5-replay` tick files (**NOT READ**, per Rule 3)
  - Osler (2001) FRBNY Staff Report 125 and Osler (2002) FRBNY Staff Report 150 (**NOT READ**, not in the repo; `s2` is judged for internal consistency and unchecked external items are listed in Check 7)
- **Synthetic Python checks run (in memory via `python -c`, no files created or left on disk):**
  1. IEEE-754 floating-point boundary check at `L = 1.1600` (`abs(1.159884 - 1.1600) <= 0.0001 * 1.1600` and `abs(1.160116 - 1.1600) <= 0.0001 * 1.1600`).
  2. Synthetic random-walk interval simulations of `s4` and `s5`: (a) 500 intervals of 10,000 minutes (`random.Random(42)`), (b) 300 intervals of 3,000 minutes (`random.Random(20261028)`), (c) two 665-interval x 14,400-minute runs at `sigma = 0.00008` and `sigma = 0.00015` (`np.random.default_rng(20261028)` and `20261029`), (d) 1,000 intervals of 3,000 minutes checking round levels located in `[q_min - band, q_min)` and `(q_max, q_max + band]` (`np.random.default_rng(20261028)`), and (e) 2,000 intervals of 4,000 minutes (`np.random.default_rng(1)`).
  3. Cross-pair correlation Monte Carlo (`10,000` trials of `M = 47` ten-day blocks across `K = 7` pairs with within-block equicorrelation `rho in {0.00, 0.10, 0.20, 0.30}`, `np.random.default_rng(20261026)`), comparing the flat pooled sign test (`n = 329`) against the 10-day time-block sign test (`M = 47`), plus exact binomial calculation for `8` wins of `10`.

---

## Summary Table (Checks 1-7)

| Check | Topic | Verdict | Core Finding |
|---|---|---|---|
| 1 | `s4`, the measure (minute quote, band, hit/side/re-arm, `+15` outcome, `CROSSING` sign, arbitrary levels, open edge cases) | **DEFECT** | (a) **Float boundary failure on s9's hand test:** in IEEE-754 float, `abs(1.159884 - 1.1600) <= 0.0001 * 1.1600` and `abs(1.160116 - 1.1600) <= 0.0001 * 1.1600` are both `False` (`+4.99e-18`), failing `research/cluster/PREREG.md:108` without `eps = 1e-12`. (b) **Ambiguous `"s3's order"` for the RNG seed:** `s3` lists pairs in fleet order on line 41 (`EURUSD, GBPUSD, ...`) and alphabetical order on lines 42-45 (`AUDCAD, AUDCHF, ...`). (c) **Open edge cases:** overlapping hits at the same level `L` when `L` exits and re-enters its band inside the 15-minute outcome window (`t_hit` to `t_hit + 15`); round levels in `[q_min - band, q_min)` and `(q_max, q_max + band]` that have 100% guaranteed reversals while arbitrary levels are restricted to `[q_min, q_max]`; overlapping round and arbitrary bands when `0.0001 * L < |L - R| <= 0.0002 * L`; and interval-boundary reset/lookup rules. |
| 2 | `s4` against `grind_bar_dump.mq5` (header/row format and `open + half the bar's spread`) | **GAP** | `grind_bar_dump.mq5:59-72` supplies every field `s4` and `s5` need (`symbol`, `server`, `digits`, `point`, `time_server`, `time_unix_server`, `open`, `spread_points`), and `open + spread_points * point / 2` is a sound bar-open mid proxy (noting that `MqlRates.spread` is the bar's minimum spread in points, not strictly the first quote's spread). **Gap:** `grind_bar_dump.mq5:60, 84` writes a single static `server_minus_gmt_s = TimeTradeServer() - TimeGMT()` at dump time (`26 Oct 2026`), whereas FTMO's server offset from GMT shifts by 1 hour between winter (`UTC+2`) and summer (`UTC+3`), affecting `s7`'s `09:00-16:00` New York time conversion (`research/cluster/PREREG.md:93-94`). |
| 3 | `s5`, the inference (interval unit, 600-bar trading-day rule, pooling 7 pairs across the same days) | **DEFECT** | Per pair, a 10-trading-day interval (`>= 600` bars/day) is the right unit. **However, pooling all 7 pairs' intervals (`~329` per half) into a flat `Binomial(N, 0.5)` sign test (and resampling individual pair-intervals in the bootstrap) breaks independence** because all 7 pairs share the same 10-day calendar blocks and common currency legs (`EURGBP = EURUSD / GBPUSD`, `CADCHF = AUDCHF / AUDCAD`, `GBPCHF`). At within-block correlation `rho = 0.20`, the nominal `p < 0.01` pooled test has true Type I error `3.44%` (`4.95%` at `rho = 0.30`). Also, `s5` omits minimum-count drop rules for `MVR > MVA` (`0` crossings -> `0 / 0`) and per-class `R100`/`R50` (`< 10` hits in that class), and does not state that bars on `< 600`-bar dates are excluded. |
| 4 | `s6.3`, the false-finding check (permuting minute returns within an interval; `at most 1 of 20 at p < 0.01`) | **GAP** | Permuting additive differences `dq_t = q_t - q_{t-1}` removes price-level structure while keeping each interval's start `q_0`, end `q_T`, drift, and step-size distribution, and `<= 1 of 20 at p < 0.01` is well calibrated (`Binomial(20, 0.01)` passes `98.31%` of the time under `alpha = 0.01`). **Gaps:** (a) permuting each pair independently destroys cross-pair correlation (masking Check 3's pooled dependence unless the same minute-index permutation is applied across all 7 pairs or `s5` uses 10-day time blocks); (b) shuffling across day boundaries inside an interval moves weekend/rollover jumps into mid-day minutes (permute within each trading day instead); and (c) `s6.3` checks only reversals (`RVR > RVA`), omitting crossing size (`MVR > MVA`). |
| 5 | `s7`, the decision (`both halves` hold-out and post-hoc bending vectors) | **GAP** | Requiring `p < 0.01` in both `2023-01-02..2024-12-31` and `2025-01-01..2026-10-23` is a genuine parameter-free chronological hold-out (`alpha = 0.01^2 = 0.0001`). **Post-hoc bending vectors to close:** (a) whether 10-day intervals reset at `2025-01-01` or straddle `2024-12-31 / 2025-01-01`; (b) whether `with RVR - RVA > 0` (`research/cluster/PREREG.md:89`) requires `mean(RVR - RVA) > 0` (and bootstrap lower bound `> 0`) in addition to the one-sided sign test; (c) the two pair orderings in `s3`; and (d) re-arming during an open `+15` window. |
| 6 | `s8`, the predictions (each falsifiable as written?) | **GAP** | Prediction 4 is falsifiable as written; Predictions 1 and 2 need minor metric clarification (`percentage points` and `mean(RVR - RVA)` over intervals); **Prediction 3 (`ROUND CROSSING EFFECT: yes in the first half; the second half weaker`, `research/cluster/PREREG.md:102`) is NOT falsifiable as written** because `ROUND CROSSING EFFECT` in `s7` is a two-half decision (`ROUND CROSSING EFFECT` vs `IN ONE HALF`) and `"weaker"` does not specify whether Half 2 fails `p < 0.01` or has a smaller `mean(MVR - MVA)`. |
| 7 | Is it a replication? (Departures of `s4-s5` from Osler in `s2`, what cannot be checked without the papers, and what matters) | **GAP** | Within `s2`'s summary, `s4-s5` faithfully replicates Osler's `0.0050` levels, `0.01% * L` band, `+15` minute horizon, `REVERSAL`/`CROSSING` definitions, and 10-trading-day interval sign test. **Departures that matter:** (1) pooling 7 correlated pairs (including 5 non-USD crosses) into a flat sign test; (2) running 24 hours across the `00:00-00:05` server rollover where widened `spread_points` (`r[i].spread` = bar minimum spread vs `open` = first tick Bid) can create artificial mid spikes; and (3) drawing 200 arbitrary levels in `[q_min, q_max]` while allowing round levels in `[q_min - band, q_min)` and `(q_max, q_max + band]`. Drawing 200 arbitrary levels instead of 30 does NOT distort the interval sign test (it reduces Monte Carlo variance of `RVA`). |

---

## Detailed Findings (Checks 1-7)

### 1. `s4`, the measure: exactness of every step and open edge cases

- **Verdict:** **DEFECT**
- **Quotes (`origin/main`):**
  - `prompts/argon_review_cluster_v3.md:29` `   the outcome at +15 with the 5-minute rule; CROSSING's sign; the arbitrary levels, their seed and the redraw)? Any`
  - `prompts/argon_review_cluster_v3.md:30` `   case left open (a minute inside two bands; a level hit twice in one interval; a gap over the weekend inside +15)?`
  - `research/cluster/PREREG.md:17` ``  (`research/opt_budget/PREREG_CAP.md`, swcap), where the EA's anchoring is modelled.``
  - `research/opt_budget/PREREG_CAP.md:12` `Cap 7: OPT holds 1.1600 ... 1.1558 and rolls from 1.1551 (the 1.1600 layer's exit moves to 1.1558). Cap 11: it also`
  - `research/cluster/PREREG.md:40` `- **Span:** 2 Jan 2023 00:05 - 23 Oct 2026 23:54 server; about 1.41 million bars a pair. **Seven pairs:** E's six`
  - `research/cluster/PREREG.md:41` `  (EURUSD, GBPUSD, EURGBP, AUDCAD, AUDCHF, CADCHF) and C's GBPCHF; all quote 5 digits (pip 0.0001).`
  - `research/cluster/PREREG.md:42` ``- **Files** (`D:\fxmatrix-exports\bars_ftmo\bars_1514878887_<PAIR>.csv`; sha256 first 16, bytes): AUDCAD``
  - `research/cluster/PREREG.md:43` ``  `B8ECCFF28A6BCAD0` 93,922,653; AUDCHF `091FB6B90C308FF4` 93,257,760; CADCHF `A136CD9577EC0448` 93,895,970; EURGBP``
  - `research/cluster/PREREG.md:44` ``  `E9A2BE7535EA8D76` 93,018,928; EURUSD `2BDF7E05817E41A6` 92,973,101; GBPCHF `BFC4346FF988130A` 94,323,103; GBPUSD``
  - `research/cluster/PREREG.md:45` ``  `742D88ADD02017E0` 93,112,293. Bar counts: 1,410,650; 1,410,274; 1,409,386; 1,409,300; 1,407,677; 1,410,930;``
  - `research/cluster/PREREG.md:46` `  1,407,893 (the dump's log).`
  - `research/cluster/PREREG.md:52` `- **The minute quote:** q_t = the bar's open + spread_points x point / 2 (the mid at the minute's first quote).`
  - `research/cluster/PREREG.md:53` `- **Levels:** round = multiples of 0.0050 (Osler's rates ending 00 or 50 at four decimals: 1.1600, 1.1650);`
  - `research/cluster/PREREG.md:54` `  **R100** = multiples of 0.0100, **R50** = the others. **Arbitrary:** per interval (s5), 200 levels drawn uniformly in [the`
  - `research/cluster/PREREG.md:55` ``  interval's lowest q, highest q] (`random.Random(20261026 + 1000 x pair_index + interval_index)`, pairs in s3's``
  - `research/cluster/PREREG.md:56` `  order), rounded to 0.00001; a draw within 0.0001 x L of a round level redrawn.`
  - `research/cluster/PREREG.md:57` `- **The band:** |q_t - L| <= 0.0001 x L (Osler's 0.01%; about 1.2 pips on EURUSD at 1.16).`
  - `research/cluster/PREREG.md:58` `- **A hit at L:** the first minute whose q is inside L's band after the last minute outside it; its **side** = the`
  - `research/cluster/PREREG.md:59` `  side of that last outside minute (+1 above, -1 below). The level is re-armed only after a minute outside the band.`
  - `research/cluster/PREREG.md:60` `- **The outcome:** q at the hit minute + 15 (the first bar at or after it, within 5 minutes; else dropped and`
  - `research/cluster/PREREG.md:61` `  counted): **CROSSING** if beyond L in the direction of the move ((q_15 - L) x side < 0), else **REVERSAL**.`
  - `research/cluster/PREREG.md:62` `- **Rates:** RVR = reversals / hits at round levels; RVA = the same at the interval's arbitrary levels (all their`
  - `research/cluster/PREREG.md:63` `  hits pooled); also per class R100, R50.`
  - `research/cluster/PREREG.md:64` `- **Crossing size (Osler's second effect):** after a CROSSING, the move in the crossing's direction from L at 15`
  - `research/cluster/PREREG.md:65` `  minutes, as a percentage of L: MVR (round) against MVA (arbitrary); and at 30, 60, 120 minutes.`
  - `research/cluster/PREREG.md:107` `` `research/cluster/osler.py` with `test_osler.py` first, in their own commit, against a stub; hand values: a hit from ``
  - `research/cluster/PREREG.md:108` `above that is back above at +15 is REVERSAL; one below is CROSSING; the band at 1.1600 is 1.159884 to 1.160116; no`
  - `research/cluster/PREREG.md:109` `re-hit without a minute outside; an interval with 9 round hits is dropped; the sign test's p for 8 wins of 10. Then`
- **Step-by-step audit:**
  1. **The minute quote from a bar (`research/cluster/PREREG.md:52`):**
     - Exact: `q_t = open + spread_points * 0.000005` (since `point = 0.00001` for all seven 5-digit pairs, `research/cluster/PREREG.md:41, 79`).
  2. **The band (`research/cluster/PREREG.md:57, 108`) -- IEEE-754 float defect on s9's hand test:**
     - At `L = 1.1600`, `0.0001 * L = 0.000116`, so the exact mathematical band is `[1.159884, 1.160116]`, as stated in `research/cluster/PREREG.md:108`.
     - However, in IEEE-754 double precision (Python `float`), `abs(1.159884 - 1.1600)` evaluates to `0.00011600000000009047 > 0.0001 * 1.1600` (`+4.987e-18`), so both `abs(1.159884 - 1.1600) <= 0.0001 * 1.1600` and `abs(1.160116 - 1.1600) <= 0.0001 * 1.1600` return **`False`**! Adding `eps = 1e-12` (`abs(q_t - L) <= 0.0001 * L + 1e-12`) fixes this and passes `test_osler.py`'s hand test (`research/cluster/PREREG.md:108`).
  3. **A hit, its side, and the re-arm (`research/cluster/PREREG.md:58-59`):**
     - Within any sequence of minutes `t = 0, 1, ..., T - 1` for a single level `L`, every minute is either inside `L`'s band (`|q_t - L| <= 0.0001 * L + 1e-12`) or outside it (`q_t > L + 0.0001 * L + 1e-12` with `side = +1`, or `q_t < L - 0.0001 * L - 1e-12` with `side = -1`). Because a hit is `the first minute whose q is inside L's band after the last minute outside it` and `The level is re-armed only after a minute outside the band`, minute `t >= 1` is a hit at `L` if and only if `t` is inside `L`'s band and `t - 1` was outside `L`'s band, with `side` equal to the side of `t - 1`. (If `t = 0` starts inside `L`'s band, `L` is unarmed until the first minute outside `L`'s band.)
     - **Missing boundary specification:** `research/cluster/PREREG.md:58-61` does not explicitly state that each interval's state machine starts fresh at the first bar of the interval (resetting arming) and only evaluates hits whose outcome bar falls within the same interval. Because arbitrary levels exist only within a single interval (`research/cluster/PREREG.md:54`), round and arbitrary levels only receive identical boundary treatment if each interval is evaluated as a self-contained slice of bars.
  4. **The outcome at `+15` with the 5-minute rule and `CROSSING`'s sign (`research/cluster/PREREG.md:60-61, 64-65`):**
     - **`CROSSING`'s sign is exact:** When approaching from above (`side = +1`), crossing means `q_15 < L`, so `(q_15 - L) * (+1) < 0`; when approaching from below (`side = -1`), crossing means `q_15 > L`, so `(q_15 - L) * (-1) < 0`; when `q_15 == L`, `(q_15 - L) * side == 0` is `REVERSAL`, matching Osler's `not beyond the level 15 minutes after the hit` (`research/cluster/PREREG.md:28-29`) and s9's hand test (`research/cluster/PREREG.md:107-108`).
     - **Timestamp lookup for `+15` (and `+30, +60, +120`):** Specify in terms of `time_unix_server` (seconds) that for a hit at `t_hit`, `q_h` (`h in {15, 30, 60, 120}`) is the `q` of the first bar in the same interval with `t_hit + 60 * h <= time_unix_server <= t_hit + 60 * (h + 5)`, else dropped and counted.
     - **Crossing size formula (`MVR`, `MVA`, `research/cluster/PREREG.md:64-65`):** Specify that for each hit that is a `CROSSING` at `+15` (`(q_15 - L) * side < 0`), its percentage move at horizon `h in {15, 30, 60, 120}` is `100.0 * (-(q_h - L) * side / L)`, and `MVR` (respectively `MVA`) is the arithmetic mean of that quantity over all round (respectively arbitrary) `+15` crossings in the interval that have a valid `q_h`.
  5. **The arbitrary levels, their seed, and the redraw (`research/cluster/PREREG.md:54-56`):**
     - **(a) Contradictory `"pairs in s3's order"` (`pair_index`):** `research/cluster/PREREG.md:41` lists the seven pairs in fleet order (`EURUSD, GBPUSD, EURGBP, AUDCAD, AUDCHF, CADCHF, GBPCHF`), whereas `research/cluster/PREREG.md:42-45` lists the seven files in alphabetical order (`AUDCAD, AUDCHF, CADCHF, EURGBP, EURUSD, GBPCHF, GBPUSD`). Nor does line 55 state whether `pair_index` (`0 ... 6`) and `interval_index` (`0 ... N - 1`) are 0-based.
     - **(b) Uniform draw call:** State explicitly `L = round(rng.uniform(low_q, high_q), 5)` (drawing 200 levels in sequence).
     - **(c) Redraw distance (`within 0.0001 x L of a round level`) leaves overlapping round/arbitrary bands:** Because both the round level `R` and the arbitrary level `L` have bands of half-width `0.0001 * level`, redrawing only when `|L - R| <= 0.0001 * L` allows an arbitrary level at `L = R + 0.00015 * R`, whose band `[R + 0.00005 * R, R + 0.00025 * R]` overlaps `R`'s band `[R - 0.0001 * R, R + 0.0001 * R]` by 50%. Redrawing when `|L - R| <= 0.0002 * L + 1e-12` makes round and arbitrary bands disjoint.
     - **(d) Boundary bias at `[lowest q, highest q]`:** A round level `R` that lies just outside `[q_min, q_max]` in `[q_min - 0.0001 * R, q_min)` or `(q_max, q_max + 0.0001 * R]` is still hit when `q_t` reaches `q_min` or `q_max` (since `|q_min - R| <= 0.0001 * R`), and **every hit on such a round level is a 100% guaranteed `REVERSAL`** because `q_{t+15} in [q_min, q_max]` can never cross `R`! By contrast, arbitrary levels drawn in `[q_min, q_max]` can never lie outside `[q_min, q_max]`. In our 1,000-interval synthetic check (`np.random.default_rng(20261028)`), `0.15%` of all round hits occurred on round levels outside `[q_min, q_max]` with `100%` reversal rate. Restricting eligible round levels in an interval to `q_min <= R <= q_max` puts round and arbitrary levels on the exact same range `[q_min, q_max]`.
  6. **The three edge cases asked in Check 1 (`prompts/argon_review_cluster_v3.md:29-30`):**
     - **(i) A minute inside two bands:** Round levels are `50` pips (`0.0050`) apart with `~2.4`-pip bands, so two round bands never overlap. However, 200 arbitrary levels in a ~150-pip interval have an average spacing of `~0.75` pips, so their `~2.4`-pip bands overlap heavily and a single minute `q_t` routinely sits inside 2 to 5 arbitrary bands at once. Evaluating each level `L` with its own independent state machine and summing hits/reversals across levels handles this cleanly; state this explicitly.
     - **(ii) A level hit twice in one interval (and re-hit inside an open `+15`-minute window):** Across 10 trading days (`~14,400` bars), the same level `L` is hit multiple times (`research/cluster/PREREG.md:70` requires `>= 10` round hits per interval). However, `research/cluster/PREREG.md:58-60` leaves open whether `L` can re-arm and record a new hit **while a prior hit at `L` is still within its 15-minute outcome window** (`t_hit` to `t_hit + 15`): under the literal rule (`t` inside band and `t - 1` outside band), if `q` bounces in and out of `L`'s band at `t = 1, 3, 5, 7`, `L` records 4 hits whose `+15` outcomes at `t = 16, 18, 20, 22` are nearly identical. State explicitly that each level `L` re-arms on any minute outside its band regardless of pending `+15` lookups (and each hit evaluates its own `t_hit + 15` independently), or else specify that `L` cannot re-arm until `t_hit + 15` has passed.
     - **(iii) A gap over the weekend inside `+15`:** Under timestamp lookup (`t_hit + 900 <= time_unix_server <= t_hit + 1200`), a hit in the last 15 minutes before Friday's `23:54` server close has no bar until Monday `00:05` (`~48` hours later), so it is outside the 5-minute window and is **dropped and counted**. Writing the lookup explicitly in seconds (`t_hit + 900 <= time_unix_server <= t_hit + 1200`, within the same interval) prevents a coder from indexing `i + 15` across the weekend gap.
- **Smallest fix to `research/cluster/PREREG.md:53-65`:**
  ```markdown
  - **Levels (evaluated per interval, only for levels L in [q_min, q_max] of the interval):** round = multiples of 0.0050 in [q_min, q_max] (**R100** = multiples of 0.0100, **R50** = the others). **Arbitrary:** per interval (s5), 200 levels drawn via `round(rng.uniform(q_min, q_max), 5)` (`rng = random.Random(20261026 + 1000 * pair_index + interval_index)`, with `pair_index = 0 ... 6` in s3's alphabetical file order `AUDCAD ... GBPUSD` and `interval_index = 0 ... N - 1` per pair); a draw within `0.0002 * L + 1e-12` of any round level is redrawn so round and arbitrary bands do not overlap.
  - **The band:** `|q_t - L| <= 0.0001 * L + 1e-12` (Osler's 0.01%; at 1.1600, 1.159884 to 1.160116 inclusive).
  - **A hit at L (tracked independently per level L, resetting at the start of each interval):** any bar `k >= 1` of the interval whose `q` is inside L's band when bar `k - 1` was outside it (re-arming immediately on every bar outside L's band, even if an earlier hit at L is within +15 minutes); its **side** = `+1` if `q_{k-1} > L` else `-1`.
  - **The outcome:** for a hit at `t_hit = time_unix_server`, `q_15` is the `q` of the first bar in the same interval with `t_hit + 900 <= time_unix_server <= t_hit + 1200` (else dropped and counted): **CROSSING** if `(q_15 - L) * side < 0`, else **REVERSAL**.
  - **Crossing size (Osler's second effect):** for each hit that is a CROSSING at +15, the signed move `100 * (-(q_h - L) * side / L)` at `h in {15, 30, 60, 120}` minutes (`q_h` = first bar in the same interval with `t_hit + 60*h <= time_unix_server <= t_hit + 60*(h+5)`, else dropped at horizon `h`), averaged over the interval's round crossings (**MVR**) and arbitrary crossings (**MVA**).
  ```

---

### 2. `s4` against the files: `grind_bar_dump.mq5`'s output and `"open + half the bar's spread"`

- **Verdict:** **GAP**
- **Quotes (`origin/main`):**
  - `scripts/grind_bar_dump.mq5:4` `//| Writes one CSV per symbol to MQL5\Files: M1 OHLC (bid) and the   |`
  - `scripts/grind_bar_dump.mq5:5` `//| bar spread in points, for [InpFrom, InpTo]. Places, modifies and |`
  - `scripts/grind_bar_dump.mq5:7` `//| (the grind_tick_probe.mq5 pattern). Bar times are TRADE SERVER   |`
  - `scripts/grind_bar_dump.mq5:8` `//| time; the header records the server-minus-GMT offset.            |`
  - `scripts/grind_bar_dump.mq5:23` `   return TimeToString(t, TIME_DATE | TIME_MINUTES);`
  - `scripts/grind_bar_dump.mq5:57` `   const int d = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);`
  - `scripts/grind_bar_dump.mq5:58` `   const double pt = SymbolInfoDouble(sym, SYMBOL_POINT);`
  - `scripts/grind_bar_dump.mq5:59` `   FileWriteString(fh, StringFormat("# symbol=%s account=%I64d server=%s digits=%d point=%s "`
  - `scripts/grind_bar_dump.mq5:60` `                                    "server_minus_gmt_s=%I64d from=%s to=%s\n",`
  - `scripts/grind_bar_dump.mq5:61` `                                    sym, login, AccountInfoString(ACCOUNT_SERVER), d,`
  - `scripts/grind_bar_dump.mq5:62` `                                    DoubleToString(pt, 8), offset_s,`
  - `scripts/grind_bar_dump.mq5:63` `                                    BarDumpTime(from_t), BarDumpTime(to_t)));`
  - `scripts/grind_bar_dump.mq5:64` `   FileWriteString(fh, "time_server,time_unix_server,open,high,low,close,spread_points,tick_volume\n");`
  - `scripts/grind_bar_dump.mq5:66` `      FileWriteString(fh, StringFormat("%s,%I64d,%s,%s,%s,%s,%d,%I64d\n",`
  - `scripts/grind_bar_dump.mq5:67` `                                       BarDumpTime(r[i].time), (long)r[i].time,`
  - `scripts/grind_bar_dump.mq5:68` `                                       DoubleToString(r[i].open, d),`
  - `scripts/grind_bar_dump.mq5:69` `                                       DoubleToString(r[i].high, d),`
  - `scripts/grind_bar_dump.mq5:70` `                                       DoubleToString(r[i].low, d),`
  - `scripts/grind_bar_dump.mq5:71` `                                       DoubleToString(r[i].close, d),`
  - `scripts/grind_bar_dump.mq5:72` `                                       r[i].spread, (long)r[i].tick_volume));`
  - `scripts/grind_bar_dump.mq5:84` `   const long offset_s = (long)(TimeTradeServer() - TimeGMT());`
  - `research/cluster/PREREG.md:52` `- **The minute quote:** q_t = the bar's open + spread_points x point / 2 (the mid at the minute's first quote).`
  - `research/cluster/PREREG.md:79` `1. Each file's sha256 and bar count equal s3's; each header says digits=5, server=FTMO-Demo, the expected symbol;`
  - `research/cluster/PREREG.md:93` `- Per pair, per class and Osler's hours (09:00-16:00 New York local time, server time converted with each file's`
  - `research/cluster/PREREG.md:94` `  offset and New York's DST) reported, not deciding.`
  - `research/cluster/PREREG.md:115` `One feed (FTMO's), minute quotes from bars (the open plus half the bar's spread); Osler's band and horizon taken as`
- **Analysis:**
  1. **Does `grind_bar_dump.mq5`'s output support every input `s4` (and `s5-s7`) uses?**
     - **For `s4`, `s5`, and `s6`: YES.** Line 1 of each CSV is the comment header `# symbol=%s account=%I64d server=%s digits=%d point=%s server_minus_gmt_s=%I64d from=%s to=%s` (`scripts/grind_bar_dump.mq5:59-63`), line 2 is the column header `time_server,time_unix_server,open,high,low,close,spread_points,tick_volume` (`scripts/grind_bar_dump.mq5:64`), and each data row (`scripts/grind_bar_dump.mq5:66-72`) provides `time_server` (`YYYY.MM.DD HH:MI`), `time_unix_server` (integer server-time epoch seconds), `open` (formatted to `d = 5` digits), and `spread_points` (`r[i].spread`, integer points). Together with `point` (`0.00001000`) from line 1, every input to `s4`, `s5`, and `s6` is present.
     - **Gap for `s7`'s non-deciding `09:00-16:00 New York local time` breakdown (`research/cluster/PREREG.md:93-94`):** `scripts/grind_bar_dump.mq5:84` computes `offset_s = (long)(TimeTradeServer() - TimeGMT())` **once when the script is executed** (on 26 Oct 2026, after EU DST ended on 25 Oct while US DST is still active until 1 Nov 2026). Across the 4-year history (`2023-2026`), FTMO's trade server shifts between winter (`UTC+2`) and summer (`UTC+3`) on the **US DST schedule** so that `00:00` server time is always `17:00` New York time (`server_time = New York local time + 7 hours` year-round, except during the 1-week US/EU DST transition if FTMO uses EU DST). Subtracting the single static `server_minus_gmt_s` from 4 years of historical server timestamps and then applying `America/New_York` DST shifts the window by 1 hour for half of every year. Since FTMO aligns daily server midnight (`00:00`) with `17:00` New York (`server = NY + 7h`), `09:00-16:00` New York is simply `16:00 <= HH:MI < 23:00` in `time_server` (or else `server_minus_gmt_s` must be computed per date from the server's DST rule rather than the static header snapshot).
  2. **Is `"open + half the bar's spread"` a sound mid for MT5's `MqlRates.spread`?**
     - **Yes, it is sound for `s4`, with two technical clarifications:**
       1. In MetaTrader 5, `MqlRates` stores **Bid** OHLC (`r[i].open` is the first tick's Bid in that minute) and a single integer `r[i].spread` in points for the whole 1-minute bar (in MT5 `.hcc` history containers, the **minimum** spread recorded during that minute, not necessarily the exact spread on the first tick). Thus `research/cluster/PREREG.md:115` (`the open plus half the bar's spread`) is exact, whereas the parenthetical in `research/cluster/PREREG.md:52` (`the mid at the minute's first quote`) is an approximation whenever spread changes inside the minute.
       2. During normal trading hours, `spread_points` varies by only a few points (`0.1-0.5` pips) within a minute and has no alignment with `0.0050` multiples versus arbitrary levels, and both `RVR` and `RVA` use the exact same `q_t` series. The one time of day when `r[i].open + r[i].spread * point / 2` can distort `q_t` is the daily rollover (`00:00-00:05` server time), when opening Bid drops during a wide rollover spread while `r[i].spread` records the narrower minimum spread later in the minute (creating a brief artificial downward dip in `q_t`; see Check 7).
- **Smallest fix to `research/cluster/PREREG.md:52, 93-94`:**
  - In `research/cluster/PREREG.md:52`, change `(the mid at the minute's first quote)` to `(the bar's opening bid plus half the bar's recorded spread)`.
  - In `research/cluster/PREREG.md:93-94`, change `(09:00-16:00 New York local time, server time converted with each file's offset and New York's DST)` to `(09:00-16:00 New York local time = 16:00-23:00 FTMO server time, since FTMO's server clock shifts with DST so 00:00 server is 17:00 New York)`.

---

### 3. `s5`, the inference: interval unit, 600-bar trading-day rule, and pooling the seven pairs' intervals

- **Verdict:** **DEFECT**
- **Quotes (`origin/main`):**
  - `research/cluster/PREREG.md:30` `  uniformly in the period's range. Inference: 58 ten-trading-day intervals, each a Bernoulli trial (p = 0.5). Reversal`
  - `research/cluster/PREREG.md:69` `- **Intervals:** consecutive blocks of 10 trading days (a trading day = a server date with at least 600 bars),`
  - `research/cluster/PREREG.md:70` `  per pair; the last partial block dropped. About 95 a pair.`
  - `research/cluster/PREREG.md:71` `- **Per interval:** a WIN if RVR > RVA (ties and intervals with fewer than 10 round hits dropped and counted).`
  - `research/cluster/PREREG.md:72` `- **The test:** one-sided binomial sign test against p = 0.5 on the WINs, per pair and pooled (all pairs' intervals);`
  - `research/cluster/PREREG.md:73` `  effect = the mean of RVR - RVA over intervals, with a 95% interval from 2,000 resamples of intervals`
  - `research/cluster/PREREG.md:74` ``  (`random.Random(20261027)`; the 51st and 1,950th of the sorted means).``
  - `research/cluster/PREREG.md:75` `- **The same for crossing size** (WIN if MVR > MVA at 15 minutes) and per class (R100, R50).`
  - `research/cluster/PREREG.md:109` `re-hit without a minute outside; an interval with 9 round hits is dropped; the sign test's p for 8 wins of 10. Then`
- **Analysis:**
  1. **Is the 10-trading-day interval the right unit?**
     - **Per pair, YES.** Within a 10-trading-day block (`~14,400` bars), individual hits at round levels and across the 200 overlapping arbitrary bands are serially and spatially dependent because they share the same path `q_t`. Collapsing each 10-day interval into a single comparison (`RVR > RVA` and `RVR - RVA`) absorbs all within-interval dependence, while consecutive 10-day intervals on a pair are separated by 14,400 minutes (`960x` the 15-minute outcome horizon) and are effectively independent.
     - **Two missing drop rules in `research/cluster/PREREG.md:71, 75`:**
       1. **Per-class (`R100, R50`) minimum hits:** Line 71 drops `intervals with fewer than 10 round hits`. When testing `R100` or `R50` separately (`research/cluster/PREREG.md:75`), an interval with `>= 10` total round hits often has `< 10` hits (or `1-2` hits) at `R100` (`0.0100` apart). Because the baseline reversal rate is `~57-62% > 50%` (a hit enters at the band edge `L +/- 0.0001*L` and must travel `0.0001*L` further to cross `L`), an interval with only `1` hit at `R100` gives `RVR_R100 = 1.0 > RVA` (`WIN`) `~60%` of the time on a pure random walk! Each class (`R100`, `R50`) must require `>= 10` hits **in that class** (`hits_class >= 10`) in the interval.
       2. **Crossing size (`MVR > MVA`) minimum crossings:** If an interval has `0` round crossings (or `0` crossings in `R100`/`R50`, or `0` arbitrary crossings), `MVR` (or `MVA`) is `0 / 0` (undefined). Require `>= 5` round crossings (and `>= 1` arbitrary crossing) in the interval for `MVR > MVA`, else drop and count.
  2. **Is the trading-day rule (`a server date with at least 600 bars`, `research/cluster/PREREG.md:69`) sound?**
     - **Yes, once two boundary details are stated explicitly:**
       - A full weekday on FTMO (`UTC+2/+3`) has `~1,430-1,440` M1 bars; `>= 600` bars (`10` hours) cleanly filters out weekend maintenance bars and Christmas/New Year holidays, yielding `~950` trading days (`~95` ten-day intervals) over `2 Jan 2023 - 23 Oct 2026`.
       - **State explicitly:** (i) bars on server dates (`time_server[:10]`) with `< 600` bars are **excluded** before forming consecutive 10-trading-day blocks, and (ii) to keep the 7 pairs aligned on the same calendar blocks (see item 3 below) and prevent an interval from straddling the `2024-12-31 / 2025-01-01` hold-out split (`research/cluster/PREREG.md:89-90`), define a trading day as a server date on which **all 7 pairs have `>= 600` bars** (or form blocks per half `2023-2024` and `2025-2026` separately, dropping the trailing `< 10`-day partial block at the end of each half).
  3. **Does pooling the seven pairs' intervals break the sign test's independence (the same days across pairs)? YES.**
     - **Why:** The seven pairs (`EURUSD, GBPUSD, EURGBP, AUDCAD, AUDCHF, CADCHF, GBPCHF`) are built from only 5 non-USD currencies (`EUR, GBP, AUD, CAD, CHF`) and linked by exact triangular identities (`EURGBP = EURUSD / GBPUSD`, `CADCHF = AUDCHF / AUDCAD`, `GBPCHF = GBPUSD * USDCHF`). In every 10-trading-day block `j`, all 7 pairs experience the same macro announcements (FOMC, CPI, NFP, ECB, BoE, SNB), USD/CHF/GBP directional cascades, and volatility regimes.
     - **Quantitative impact on `s5`'s pooled sign test (`Binomial(7M, 0.5)`) and bootstrap:**
       - With `M ~ 47` ten-day blocks per half and `K = 7` pairs (`n = 329` pair-intervals per half), if the pair-level indicators `I(RVR_{p,j} > RVA_{p,j})` within the same 10-day block `j` have pairwise correlation `rho > 0`, the variance of the pooled win count is inflated by the cluster design effect `DEFF = 1 + (K - 1) * rho = 1 + 6 * rho`.
       - In our 10,000-trial Monte Carlo simulation (`M = 47, K = 7`, `np.random.default_rng(20261026)`), the nominal `p < 0.01` one-sided cutoff (`>= 187` wins of `329`) has actual Type I error `0.76%` at `rho = 0.00`, **`1.75%` at `rho = 0.10`**, **`3.44%` at `rho = 0.20`**, and **`4.95%` at `rho = 0.30`** (nearly **5x** nominal)!
       - Likewise, resampling individual `(pair, interval)` cells in `s5`'s 2,000-resample bootstrap (`research/cluster/PREREG.md:73-74`) treats the 7 pairs in the same 10-day block as independent, understating the bootstrap standard error by `sqrt(1 + 6 * rho)`.
- **Smallest fix to `research/cluster/PREREG.md:69-75`:**
  Make the **10-trading-day time block `j`** (`M ~ 47` blocks per half, `~95` total, on common server trading days where all 7 pairs have `>= 600` bars, formed separately within `2023-2024` and `2025-2026`) the unit of the pooled sign test and bootstrap:
  ```markdown
  - **Intervals:** within each half (s7), consecutive blocks of 10 common trading days (a common trading day = a server date `time_server[:10]` with at least 600 bars on all seven pairs; bars on other dates and the last partial block of each half dropped). About 47 blocks a half (94 total).
  - **Per pair-interval:** a WIN if RVR > RVA (ties and pair-intervals with fewer than 10 hits in the tested round set -- all round, R100, or R50 -- dropped and counted). For crossing size: WIN if MVR > MVA at 15 minutes (pair-intervals with fewer than 5 crossings in the tested round set or 0 arbitrary crossings dropped and counted).
  - **The test:** per pair, one-sided binomial sign test against p = 0.5 on the pair's WINs. **Pooled (across the seven pairs):** per 10-day time block `j`, let `D_j` be the mean of `RVR_{p,j} - RVA_{p,j}` (or `MVR_{p,j} - MVA_{p,j}`) over the pairs valid in block `j`; block `j` is a pooled WIN if `D_j > 0` (ties `D_j == 0` dropped), tested by the one-sided binomial sign test against p = 0.5 over the `M` time blocks; pooled effect = the mean of `D_j` over blocks, with a 95% interval from 2,000 block resamples (`random.Random(20261027)`; the 51st and 1,950th of the sorted means).
  ```
  *(Verified in our 10,000-trial simulation: testing `D_j > 0` across `M = 47` time blocks (`>= 32` wins of `47` for `p < 0.01`) keeps actual Type I error at `0.73%-0.94%` across all `rho in [0.00, 0.30]` while averaging across the 7 pairs cuts within-block noise by `sqrt(7)`, giving `> 99%` power for a true `+2.5` percentage-point reversal effect.)*

---

### 4. `s6.3`, the false-finding check: permuting minute returns and `"at most 1 of 20 at p < 0.01"`

- **Verdict:** **GAP**
- **Quotes (`origin/main` and `origin/review/argon-cluster-v2`):**
  - `research/cluster/PREREG.md:82` ``3. **False-finding rate:** 20 synthetic runs (`random.Random(20261028 + run)`): each pair's minute returns permuted``
  - `research/cluster/PREREG.md:83` `   within each interval (keeps each interval's drift and volatility, removes any level structure), q rebuilt from the`
  - `research/cluster/PREREG.md:84` `   interval's first q; s5's pooled sign test on reversals significant at p < 0.01 in at most 1 of the 20. Else the`
  - `research/cluster/PREREG.md:85` `   rule is too loose: amend before reading the real result.`
  - `reviews/argon_review_cluster_v2.md:47` ``| 6 | s5's synthetic checks (`at most 1 of 12` and `9 of 10` bars, false-finding rate) | **DEFECT** | (a) In Part B (`research/cluster/PREREG.md:89-91`), requiring **two-sided** 95% intervals (`[2.5%, 97.5%]`) for `d100` and `d50` to include `0` on `>= 9 of 10` runs in each regime tests single-regime two-sided coverage (`alpha = 0.05` per interval), NOT Part B's one-sided both-regime `ROUND EFFECT` rule (`alpha = 0.025^2`), and **fails 30.3% to 59.6% of the time on a pure Gaussian random walk** (in our synthetic run with `seed 20261027`, calm got `8/10` on `d50` and `7/10` jointly, triggering a false `STOP`). (b) In s5.4 (`research/cluster/PREREG.md:92`), `the sum over k of arrivals = the moves less the moves into n = 0` fails whenever `|n| >= 15` unless `V_k` is summed over all `k >= 1` (not just `k = 1 ... 14`, `research/cluster/PREREG.md:48`). |``
- **Analysis:**
  1. **Does permuting minute returns within an interval remove level structure while keeping what it should?**
     - Permuting the additive minute changes `dq_k = q_k - q_{k-1}` (`k = 1 ... T - 1`) within an interval and rebuilding `q_k = round(q_0 + sum_{m=1}^k dq_{pi(m)}, 6)` keeps the interval's exact starting quote `q_0`, ending quote `q_{T-1}`, net drift `q_{T-1} - q_0`, and unconditional step-size distribution while destroying any attachment of reversals or crossings to `0.0050` multiples.
     - **Three gaps in `s6.3`'s permutation procedure (`research/cluster/PREREG.md:82-84`):**
       1. **Cross-pair correlation is wiped out if each pair is permuted with a different ordering:** If `rng.shuffle` is called sequentially on pair 0, pair 1, ..., pair 6, the 7 pairs receive independent permutations in the synthetic runs, so `rho = 0` by construction in `s6.3` even when `rho > 0` in the real data! Applying the **same permutation of minute steps across all 7 pairs** on shared timestamps (or adopting Check 3's 10-day time-block pooled sign test) ensures `s6.3` tests the true cross-pair dependence structure.
       2. **Weekend and daily rollover jumps inside the 10-day interval:** A 10-trading-day interval contains 9 daily rollover breaks and 1 weekend gap (`~48` hours between Friday `23:54` and Monday `00:05`). Permuting `dq_k` across the entire 10-day interval moves the weekend/overnight jump `dq_k` onto an ordinary mid-day 1-minute bar while keeping the original bar timestamps `time_unix_server`. Permuting `dq_k` **within each trading day** of the interval keeps overnight/weekend jumps at day boundaries (where the 5-minute lookup rule drops pre-gap hits) while still removing all intraday level structure.
       3. **Exact definition of `"minute returns"`:** State explicitly that `dq_k = q_k - q_{k-1}` is the additive first difference of `q_t` (rebuilt via cumulative sum from `q_0` and rounded to `6` decimals `0.000005`).
  2. **Is `"at most 1 of 20 at p < 0.01"` a fair bar for the pooled test as specified?**
     - **Yes, statistically `<= 1 of 20` is well calibrated for a single `p < 0.01` test:** Under `Binomial(20, 0.01)`, `P(0 of 20) = 81.79%` and `P(1 of 20) = 16.52%`, so `P(<= 1 of 20) = 98.31%` (`1.69%` false-STOP rate when true size is `alpha = 0.01`, unlike v2's miscalibrated `>= 9 of 10` check on four `alpha = 0.05` two-sided intervals in `reviews/argon_review_cluster_v2.md:47`).
     - **Missing check on crossing size (`MVR > MVA`):** `s5` and `s7` also make a primary decision on `ROUND CROSSING EFFECT` (`MVR > MVA` at 15 minutes, `research/cluster/PREREG.md:75, 92`), yet `s6.3` (`research/cluster/PREREG.md:84`) only checks reversals (`RVR > RVA`). Adding `and on crossing size (MVR > MVA at 15 minutes) in at most 1 of the 20` (`96.65%` joint pass rate under `alpha = 0.01`) guards both primary tests.
- **Smallest fix to `research/cluster/PREREG.md:82-85`:**
  ```markdown
  3. **False-finding rate:** 20 synthetic runs (`random.Random(20261028 + run)` for `run = 0 ... 19`): within each interval and trading day, the additive minute changes `dq_k = q_k - q_{k-1}` are permuted (`rng.shuffle`), `q` rebuilt from the interval's first `q_0` (`round(q_0 + cumsum, 6)`); s5's pooled sign test on reversals (`RVR > RVA`) and on crossing size (`MVR > MVA` at 15 minutes) are each significant at p < 0.01 in at most 1 of the 20 runs. Else the rule is too loose: amend before reading the real result.
  ```

---

### 5. `s7`, the decision: is `"both halves"` a real hold-out, and can anything be bent after the fact?

- **Verdict:** **GAP**
- **Quotes (`origin/main`):**
  - `research/cluster/PREREG.md:35` `## 3. DATA (dumped 26 Oct ~04:42-04:44Z; not read before this is committed)`
  - `research/cluster/PREREG.md:89` `- **ROUND REVERSAL EFFECT** if the pooled sign test gives p < 0.01 with RVR - RVA > 0 **in BOTH halves**: 2023-01-02 to`
  - `research/cluster/PREREG.md:90` `  2024-12-31 and 2025-01-01 to 2026-10-23 (the second half is the hold-out for the first: the operator's "tea`
  - `research/cluster/PREREG.md:91` `  leaves"). One half only: IN ONE HALF (reported, not built on). Neither: NONE.`
  - `research/cluster/PREREG.md:92` `- **ROUND CROSSING EFFECT** by the same rule on MVR > MVA at 15 minutes.`
  - `research/cluster/PREREG.md:93` `- Per pair, per class and Osler's hours (09:00-16:00 New York local time, server time converted with each file's`
  - `research/cluster/PREREG.md:94` `  offset and New York's DST) reported, not deciding.`
  - `research/cluster/PREREG.md:95` `- **Watching, not deciding:** the same measures on the live weeks from 26 Oct (the desktop dump repeated after 6 Nov),`
  - `research/cluster/PREREG.md:96` `  reported beside the result.`
  - `research/cluster/PREREG.md:116` `published, not tuned; dependence between levels in one interval (intervals are the unit); the arbitrary levels'`
- **Analysis:**
  1. **Is `"both halves"` a real hold-out here?**
     - **Yes.** Although both halves (`2023-01-02 to 2024-12-31` and `2025-01-01 to 2026-10-23`) are already on disk (`research/cluster/PREREG.md:35, 42-46`), **zero parameters of the measure are estimated or tuned on the first half**: the levels (`0.0050`), band (`0.01% * L`), outcome horizon (`+15` minutes), and block length (`10 trading days`) are fixed a priori from Osler (2002) (`research/cluster/PREREG.md:27-30, 115-116`), and the data files are SHA-256-locked before any bar is read (`research/cluster/PREREG.md:42-46, 79`). Requiring `p < 0.01` one-sided in **both** non-overlapping ~2-year halves reduces the joint false-positive rate under independence to `0.01^2 = 0.0001` and tests whether any effect persists across two distinct multi-year market regimes (`2023-2024` vs `2025-2026`).
  2. **Choices left open in `s4-s7` that could let a borderline result be bent after the fact:**
     - **(a) Interval construction at the `2024-12-31 / 2025-01-01` boundary (`research/cluster/PREREG.md:69-70, 89-90`):** `s5` says `consecutive blocks of 10 trading days ... the last partial block dropped` without saying whether blocks are built separately inside Half 1 (`2023-01-02..2024-12-31`) and Half 2 (`2025-01-01..2026-10-23`) or across the full 4-year span (which creates a boundary block straddling `2024-12-31 / 2025-01-01` and shifts every Half 2 block by up to 9 trading days).
     - **(b) Meaning of `"with RVR - RVA > 0"` in `research/cluster/PREREG.md:89` (and `MVR > MVA` in line 92):** Does `gives p < 0.01 with RVR - RVA > 0 in BOTH halves` mean only that the one-sided sign test is in the right tail (`WIN` share `> 0.5` with `p < 0.01`), or ALSO that the half's mean effect `mean(RVR - RVA) > 0` (and its 95% bootstrap lower bound `sorted_means[50] > 0`)? State explicitly that in each half: (i) the one-sided sign test on `WIN` has `p < 0.01`, AND (ii) the half's mean effect (`mean(RVR - RVA)` or `mean(MVR - MVA)`) is `> 0`.
     - **(c) Pair order (`s3's order`) for the arbitrary-level RNG seed (`research/cluster/PREREG.md:41 vs 42-45, 55`):** Pin `pair_index = 0 ... 6` to alphabetical file order (`AUDCAD ... GBPUSD`, Check 1) so no one can toggle between fleet order and file order.
     - **(d) Re-arming during an open `+15` window (`research/cluster/PREREG.md:58-60`):** Pin immediate re-arming on the next minute outside the band (Check 1) so no one can toggle between immediate re-arm and `+15`-blocked re-arm.
- **Smallest fix to `research/cluster/PREREG.md:89-92`:**
  ```markdown
  - **ROUND REVERSAL EFFECT** if in **BOTH halves** (`2023-01-02 <= date <= 2024-12-31` and `2025-01-01 <= date <= 2026-10-23`, intervals built separately in each half) the pooled one-sided sign test gives `p < 0.01` (`WIN` share `> 0.5`) AND the half's pooled mean effect (`mean(D_j)`) is `> 0`. One half only: IN ONE HALF (reported, not built on). Neither: NONE.
  - **ROUND CROSSING EFFECT** by the same rule on `MVR - MVA` at 15 minutes (`p < 0.01` on the pooled one-sided sign test AND `mean(D_j) > 0` in both halves).
  ```

---

### 6. `s8`, the predictions: is each falsifiable as written?

- **Verdict:** **GAP**
- **Quotes (`origin/main`):**
  - `research/cluster/PREREG.md:98` `## 8. CLAUDE's PREDICTIONS (before any bar is read)`
  - `research/cluster/PREREG.md:100` `1. Pooled RVR - RVA between +1 and +5 points in each half.`
  - `research/cluster/PREREG.md:101` `2. ROUND REVERSAL EFFECT: yes (both halves), larger at R100 than R50.`
  - `research/cluster/PREREG.md:102` `3. ROUND CROSSING EFFECT: yes in the first half; the second half weaker.`
  - `research/cluster/PREREG.md:103` `4. Synthetic check: 0 or 1 of 20 significant.`
- **Analysis:**
  - **Prediction 1 (`research/cluster/PREREG.md:100`):** Almost falsifiable as written; clarify that `"points"` means **percentage points** (`+0.01 <= mean(RVR - RVA) <= +0.05` in each half, as in `research/cluster/PREREG.md:31`: `+4.5 points`) rather than `0.00001` price points, and that `"Pooled RVR - RVA"` is `s5`'s mean of `RVR - RVA` over the half's intervals.
  - **Prediction 2 (`research/cluster/PREREG.md:101`):** `ROUND REVERSAL EFFECT: yes (both halves)` is falsifiable by `s7`'s rule; clarify whether `"larger at R100 than R50"` means pooled `mean(RVR_R100 - RVA) > mean(RVR_R50 - RVA)` in **each half** (or over all 4 years).
  - **Prediction 3 (`research/cluster/PREREG.md:102`):** **NOT falsifiable as written.** In `s7` (`research/cluster/PREREG.md:89-92`), `ROUND CROSSING EFFECT` is a two-half decision whose possible outcomes are `ROUND CROSSING EFFECT` (both halves `p < 0.01`), `IN ONE HALF` (one half `p < 0.01`), or `NONE`. Saying `"yes in the first half; the second half weaker"` leaves open whether Half 2 passes `p < 0.01` (`ROUND CROSSING EFFECT`) or fails `p < 0.01` (`IN ONE HALF`), and does not state which metric (`mean(MVR - MVA)` or `WIN` rate) is smaller in Half 2 than in Half 1.
  - **Prediction 4 (`research/cluster/PREREG.md:103`):** **Falsifiable as written** (`0` or `1` of the 20 synthetic runs in `s6.3` has `p < 0.01`).
- **Smallest fix to `research/cluster/PREREG.md:100-103`:**
  ```markdown
  1. Pooled mean(RVR - RVA) over intervals between +1.0 and +5.0 percentage points (+0.01 to +0.05) in each half.
  2. ROUND REVERSAL EFFECT: yes (both halves), with pooled mean(RVR_R100 - RVA) > mean(RVR_R50 - RVA) in each half.
  3. ROUND CROSSING EFFECT: Half 1 passes (p < 0.01, mean(MVR - MVA) > 0); Half 2 has a smaller pooled mean(MVR - MVA) than Half 1 and p >= 0.01 (overall decision: IN ONE HALF).
  4. Synthetic check: 0 or 1 of 20 significant on reversals and on crossing size.
  ```

---

### 7. Is it a replication? Departures of `s4-s5` from Osler (`s2`), what cannot be checked, and what matters

- **Verdict:** **GAP**
- **Quotes (`origin/main`):**
  - `prompts/argon_review_cluster_v3.md:40` `7. **Is it a replication?** Where does s4-s5 depart from Osler as s2 states her method (minute bars vs her minute`
  - `prompts/argon_review_cluster_v3.md:41` `   quotes, 24 hours vs her 9:00-16:00 New York, 200 arbitrary levels vs her sets of 30, the pooled test), and does any`
  - `prompts/argon_review_cluster_v3.md:42` `   departure matter?`
  - `research/cluster/PREREG.md:9` `| What follows | **Nothing live.** A reversal effect that holds in BOTH halves (s7) becomes the premise of a round-aware lattice (denser adds approaching R100 / R50, wider after a crossing), pre-registered and checked in the simulator, then the harness. A crossing effect bears on where that lattice must widen. No effect: the idea stops, and that is reported. |`
  - `research/cluster/PREREG.md:22` `- **Order clustering** (Osler, "Currency Orders and Exchange-Rate Dynamics", FRBNY Staff Report 125, 2001; a bank's`
  - `research/cluster/PREREG.md:26` `- **Price behaviour** (Osler, "Stop-Loss Orders and Price Cascades in Currency Markets", FRBNY Staff Report 150, 2002;`
  - `research/cluster/PREREG.md:27` `  Reuters minute quotes 9:00-16:00 New York, Jan 1996 - Apr 1998, DEM, JPY, GBP against the dollar): **round = rates`
  - `research/cluster/PREREG.md:28` `  ending 00 or 50; a hit = within 0.01% of the level; a reversal = the rate is not beyond the level 15 minutes after`
  - `research/cluster/PREREG.md:29` `  the hit; a crossing = it is beyond, in the direction of the move.** Comparison levels: arbitrary numbers drawn`
  - `research/cluster/PREREG.md:30` `  uniformly in the period's range. Inference: 58 ten-trading-day intervals, each a Bernoulli trial (p = 0.5). Reversal`
  - `research/cluster/PREREG.md:31` `  frequency, round against arbitrary: DEM 59.3% / 54.8% (+4.5 points, 46 of 58 intervals), JPY 60.1 / 57.3 (+2.8),`
  - `research/cluster/PREREG.md:32` `  GBP 58.1 / 56.6 (+1.5, not significant). After crossings, round-number moves larger (DEM 0.061% against 0.054% at 15`
  - `research/cluster/PREREG.md:33` `  minutes); the crossing effect lasts hours, the reversal effect under 30 minutes.`
- **What cannot be checked without Osler's papers (FRBNY SR 125, 2001, and SR 150, 2002 -- `NOT READ`, not in repo):**
  1. Whether Osler's hit rule re-armed a level immediately after 1 minute outside the `0.01%` band (`research/cluster/PREREG.md:58-59`) or suppressed re-hits at the same level `L` during the 15-minute outcome horizon (`t_hit` to `t_hit + 15`) or until a wider excursion away from `L`.
  2. Whether Osler drew sets of 30 arbitrary levels per 10-day interval (mentioned in `prompts/argon_review_cluster_v3.md:41`, whereas `research/cluster/PREREG.md:29-30` says `arbitrary numbers drawn uniformly in the period's range` without stating `30`), whether she excluded arbitrary draws near round levels, and how she handled hits in the final 15 minutes before `16:00` New York time.
  3. Whether Osler's crossing-size test (`DEM 0.061% against 0.054% at 15 minutes`, `research/cluster/PREREG.md:32`) used the 58-interval binomial sign test (`MVR > MVA`) or a pooled crossing-level t-test / bootstrap.
  4. Whether the empirical percentages in `s2` (`8.7%`, `9.3% vs 4.4%`, `14.4% vs 7.4%`, `59.3% / 54.8%`, `46 of 58`, `60.1 / 57.3`, `58.1 / 56.6`, `0.061% vs 0.054%`) match the printed tables of SR 125 and SR 150. *(Internal consistency check of `s2`: `59.3 - 54.8 = +4.5`, `60.1 - 57.3 = +2.8`, `58.1 - 56.6 = +1.5`, and `46 of 58` in `Binomial(58, 0.5)` has one-sided `p = 3.84e-6`, all internally consistent.)*
- **Where `s4-s5` departs from Osler as stated in `s2` (and `prompts/argon_review_cluster_v3.md:40-42`), and whether each departure matters:**
  1. **Minute bars (`open + spread_points * point / 2`, `research/cluster/PREREG.md:52`) vs Osler's Reuters minute quotes (`research/cluster/PREREG.md:27`):**
     - *Does it matter?* **Only during the daily `00:00-00:05` server rollover (and for sub-minute stop cascades).** During normal hours, the bar's opening Bid plus half the bar's spread (`MqlRates.spread`) is an accurate 1-minute quote snapshot. However, during FTMO's daily server rollover (`00:00-00:05` server = `17:00-17:05` NY), `r[i].open` is the Bid at the start of the minute (when rollover spread is widest, often 5-15 pips) while `r[i].spread` is the bar's **minimum** spread over the minute; if spread narrows inside that minute, `q_t = open + spread / 2` exhibits an artificial downward dip at `00:00-00:05` that reverts by `+15` minutes (`00:15-00:20`). Also, sampling only once per minute at `open` (ignoring `high`/`low`) misses fast intrabar stop cascades that cross `L`'s `~2.4`-pip band in `< 60` seconds, though that matches Osler's 1-minute quote sampling.
  2. **24-hour server days (`research/cluster/PREREG.md:40, 69`) vs Osler's `09:00-16:00` New York hours (`research/cluster/PREREG.md:27, 93-94`):**
     - *Does it matter?* **Yes, moderately.** Osler restricted her sample to active New York hours (`09:00-16:00` NY = 7 hours/day). Including all 24 hours adds 17 hours/day of Asian, early-European, and rollover trading where: (i) low Asian volatility reduces the probability of crossing the `0.01% * L` (`~1.2`-pip) distance in 15 minutes, lifting baseline `RVR` and `RVA` alike and potentially diluting institutional order-book effects concentrated in London/NY hours, and (ii) the `00:00-00:05` server rollover spread widening enters the 24-hour sample. Because the EA trades 24 hours a day, testing 24 hours (while reporting `09:00-16:00` NY in `s7`, `research/cluster/PREREG.md:93-94`, with the fixed NY time mapping from Check 2) is justified for the EA's premise.
  3. **200 arbitrary levels per interval (`research/cluster/PREREG.md:54-56`) vs Osler's sets of 30 (`prompts/argon_review_cluster_v3.md:41`):**
     - *Does it matter?* **No for the interval sign test -- it is an improvement**, provided the range boundary `[q_min, q_max]` and band-overlap redraw (`0.0002 * L`) from Check 1 are fixed. Because `s5` collapses all arbitrary hits in an interval into a single interval rate `RVA` (`research/cluster/PREREG.md:62-63, 71`) and runs the sign test across intervals (not across individual levels or hits), using 200 levels instead of 30 does not inflate the degrees of freedom of the sign test; it simply reduces the Monte Carlo draw variance of the benchmark `RVA` on `[q_min, q_max]`.
  4. **The pooled test across seven pairs (`2` USD majors + `5` non-USD crosses, `research/cluster/PREREG.md:40-41, 72, 89`) vs Osler's per-pair tests on `3` USD majors (`DEM, JPY, GBP`, `research/cluster/PREREG.md:27, 30-32`):**
     - *Does it matter?* **Yes -- this is the largest departure and matters in two ways:**
       1. **Statistical dependence across pairs on the same 10-day blocks (Check 3):** Treating `7 x 47 = 329` pair-intervals per half as independent Bernoulli trials inflates the `p < 0.01` Type I error rate up to `3.4%-5.0%` when pairs co-move (`rho = 0.20-0.30`). Fixing the pooled test to test the 10-day time-block mean `D_j > 0` across the `M ~ 47` time blocks per half (`Check 3`) restores exact Type I error control.
       2. **Economic heterogeneity (5 minor cross rates vs 2 USD majors):** Five of the seven pairs (`EURGBP, AUDCAD, AUDCHF, CADCHF, GBPCHF`) are cross rates whose prices are ratios of USD legs; customer take-profit and stop-loss clustering at `0.0050` cross figures may be much weaker on `AUDCAD`, `AUDCHF`, and `CADCHF` than on `EURUSD` and `GBPUSD` (even in Osler's 3 USD majors, `GBP` `+1.5` points was not significant, `research/cluster/PREREG.md:32`). If the pooled test passes solely because of `EURUSD`/`GBPUSD` while the crosses show zero effect (or fails because the 5 crosses dilute `EURUSD`/`GBPUSD`), applying a round-number lattice across all fleet pairs (`research/cluster/PREREG.md:9`) would mismatch the pairs where the effect actually lives. Requiring a pair to show `RVR - RVA > 0` in both halves before deploying a round-aware lattice on that pair (or noting this in `s7`) prevents cross-pair dilution or misattribution.

---

**SOUND WITH CHANGES** -- Fix before writing code or reading bars: (1) in `s4` (`research/cluster/PREREG.md:53-65`), add float tolerance `eps = 1e-12` to the band (`|q_t - L| <= 0.0001 * L + 1e-12`, fixing `False` at `1.159884` and `1.160116` on `1.1600`), restrict eligible round levels to the interval's `[q_min, q_max]` so round levels outside `[q_min, q_max]` do not get guaranteed 100% reversals, redraw arbitrary levels within `0.0002 * L + 1e-12` of round levels so round and arbitrary bands do not overlap, pin `pair_index = 0 ... 6` to `s3`'s alphabetical file order (`AUDCAD ... GBPUSD`), state that each level `L` resets at the interval start and re-arms on every bar outside its band (even within `+15` minutes of an earlier hit), and write the horizon lookup as `t_hit + 60*h <= time_unix_server <= t_hit + 60*(h+5)` within the same interval for `h in {15, 30, 60, 120}`; (2) in `s5` and `s7` (`research/cluster/PREREG.md:69-75, 89-94`), build 10-day blocks separately within each half on common trading days (`>= 600` bars on all 7 pairs, dropping `< 600`-bar dates), require `>= 10` hits in the tested class (`R100`/`R50`) and `>= 5` round crossings for `MVR > MVA`, replace the flat `7 x M` pooled sign test and pair-interval bootstrap with the 10-day time-block sign test (`D_j = mean_p(RVR_{p,j} - RVA_{p,j}) > 0` over the `M ~ 47` blocks per half) and block bootstrap, require both `p < 0.01` and `mean(D_j) > 0` in each half, and map `09:00-16:00` New York to `16:00-23:00` FTMO server time instead of using the static header `server_minus_gmt_s`; and (3) in `s6.3` and `s8` (`research/cluster/PREREG.md:82-85, 100-103`), permute `dq_k = q_k - q_{k-1}` within each trading day, check `<= 1 of 20 at p < 0.01` on both reversals (`RVR > RVA`) and crossing size (`MVR > MVA`), and make Prediction 3 falsifiable by stating whether Half 2 has `p >= 0.01` (`IN ONE HALF`) and `mean(MVR - MVA)` smaller than Half 1's.

Line count: 308
