This message has a line count at the bottom

# Argon Review v2: `research/cluster/PREREG.md` (The Cluster Measurement Pre-Registration, v2)

- **Branch:** `review/argon-cluster-v2`
- **Base commit (`origin/main`):** `9623022e2c1bd11b041fd346047e64abf303d4f2`
- **v1 review commit (`origin/review/argon-cluster`):** `2875f99685265e7a8903552a5d55efee6a65bd1a`
- **Files read (at `origin/main` unless noted):**
  - `prompts/argon_review_cluster_v2.md` (lines 1-48)
  - `research/cluster/PREREG.md` (lines 1-130)
  - `reviews/argon_review_cluster.md` at `origin/review/argon-cluster` (lines 1-357)
  - `research/opt_budget/runs.py` (lines 1-137)
  - `research/opt_budget/PREREG_CAP.md` (lines 1-42)
  - `research/opt_budget/MECHANICS.md` (lines 1-64)
  - `research/replay/inputs/swcap.sha256` (lines 1-12)
  - `research/replay/inputs/swcap/run_swcapw_eurusd.csv` (lines 1-9)
  - `research/replay/inputs/swcap/run_swcapw_gbpusd.csv` (lines 1-9)
  - `research/replay/inputs/swcap/run_swcapw_eurgbp.csv` (lines 1-9)
  - `research/replay/inputs/swcap/run_swcapw_audcad.csv` (lines 1-9)
  - `research/replay/inputs/swcap/run_swcapw_audchf.csv` (lines 1-9)
  - `research/replay/inputs/swcap/run_swcapw_cadchf.csv` (lines 1-9)
  - `research/replay/inputs/swcap/run_swcapo_eurusd.csv` (lines 1-2)
  - `research/replay/inputs/swcap/run_swcapo_gbpusd.csv` (lines 1-2)
  - `research/replay/inputs/swcap/run_swcapo_eurgbp.csv` (lines 1-2)
  - `research/replay/inputs/swcap/run_swcapo_audcad.csv` (lines 1-2)
  - `research/replay/inputs/swcap/run_swcapo_audchf.csv` (lines 1-2)
  - `research/replay/inputs/swcap/run_swcapo_cadchf.csv` (lines 1-2)
  - `research/replay/results/sweep_notes.md` (lines 450-945)
  - `ea/grind_engine.mqh` (lines 1-3630)
  - `ea/grind_pure.mqh` (lines 1-691)
- **Files NOT read:** `D:\mt5-replay` tick files (**NOT READ**, per Rule 3).
- **Synthetic Python checks run (in memory via `python -c`, no files left on disk):**
  1. Part A cliff swing (`[-1, -1, -1, -1, 1, 1, 1, 1] * 50`) and 2,000 driftless random walks of `N = 400` moves (`random.Random(20261025)`), plus 1,000-trial comparison of 8 weekly segments of 50 moves (`reset_8x50`) vs 1 un-reset walk of 400 moves (`no_reset_1x400`, `random.Random(20261027)`), and 200-trial false-`K` rate comparing concatenated vs within-segment shuffles (`task-44`).
  2. Part B 5-pip grid simulation and 2,000-resample day-block bootstrap across 10 runs of 40 days (calm) and 15 days (October) (`random.Random(20261027)` and `random.Random(20261026 + run)`), plus exact binomial pass/fail rates of s5.3's `>= 9 of 10` check at `alpha = 0.05` and `alpha = 0.065`.

---

## Summary Table (Checks 1-8)

| Check | Topic | Verdict | Core Finding |
|---|---|---|---|
| 1 | v1 findings (1(a)-(c), 2-8): fixed in v2 and where? | **DEFECT** | 1(b), 1(c), 2, 3, 5, and 7 are fixed (or mostly fixed); **1(a) is NOT fixed** (`research/cluster/PREREG.md:43, 45` still pins the anchor to `L0` because an excursion ends only at `n = 0`), and **6 (s5.4's identity)** introduces a range mismatch (`k = 1 ... 14` in `research/cluster/PREREG.md:48` vs `the moves less the moves into n = 0` in `research/cluster/PREREG.md:92` whenever `|n| >= 15`). |
| 2 | Part A's measure (`A_k = V_k / V_1`, cliff example, shuffle, two DROPs in a row, THIN) | **DEFECT** | (a) On finite segments with open last excursions, a driftless random walk's `A_k` is **not flat** (median `A_k` decays from `1.000` at `k = 1` to `0.565` at `k = 4` and `0.244` at `k = 7` on `8 x 50` steps). (b) **The cliff example does not compute as written:** on `1.1600 -> 1.1572 -> 1.1600` (`0 -> -4 -> 0`), each swing visits `k = 1, 2, 3` twice (`V_1 = V_2 = V_3 = 2`) but visits the turnaround apex `k = 4` only **once** (`-3 -> -4`, so `V_4 = 1`, `A_4 = 0.5 != 1`), which fails s8's unit test (`research/cluster/PREREG.md:112`). (c) In calm (8 segments), permuting `the series' moves` without permuting *within each segment* and resetting `n = 0` at segment starts inflates the single-regime false-`K` rate from `2.5%` to `10.0%` and destroys weekly drift signs. (d) If `s > 0` shuffles are skipped (`V_1 = 0`), indexing `the 26th and 975th of the 1,000 sorted values` shifts or goes out of bounds. |
| 3 | Part A against the caps (`cap c holds depths 0 ... c - 1, rolls at c`, reading rule) | **CONFIRMED** | Confirmed against `ea/grind_pure.mqh:229, 231`, `ea/grind_engine.mqh:1303, 1306, 1314, 1404, 2057, 2271, 2286, 2309`, and `research/opt_budget/PREREG_CAP.md:12`. The reading rule (`K > cap` more layers, `K < cap` fewer, `cap K` rolls at the fall-off) follows once `K`'s definition in Check 2 is fixed. |
| 4 | Part B's measure (arrival, re-arm, TURN/THROUGH, 5-digit classes, classes as control) | **GAP** | (a) `since L's last arrival (re-armed)` (`research/cluster/PREREG.md:68`) omits initial arming before `L`'s **first** arrival in a segment (a level within `< s` of the segment's first mid would trigger without a full `s`-pip approach). (b) On a single-tick gap from `>= L + s` to `<= L - s` (`1.1607 to 1.1592`, `research/cluster/PREREG.md:114-115`), `after the arrival` (`research/cluster/PREREG.md:70`) must include the arrival tick itself (`on or after the arrival tick`), and `L + s` / `L - s` should be written `L +/- s` / `L -/+ s` for both directions. (c) `R100 / R50 / OTHER` are exact for all six 5-digit pairs (using integer pip arithmetic `round(L * 10000)` to avoid IEEE-754 modulo error). (d) Pooling raw counts across pairs (`t_class = sum(TURN) / sum(TURN + THROUGH)`) can suffer Simpson's paradox if a range-bound pair sits near an `R100` level while a trending pair does not. |
| 5 | Part B's interval (day-block bootstrap, 2,000 resamples, seed, quantile rule) | **GAP** | Day-block bootstrap by server date is the right dependence guard across and within pairs, and `51st` / `1,950th` of 2,000 (`sorted_d[50]` and `sorted_d[1949]` in 0-based indexing) is exact (`50 / 2,000 = 2.5%` each tail). However, `research/cluster/PREREG.md:74-76` does not specify that server date is the **arrival tick's** server date (`t_msc // 86400000`), that `days` is sorted before `rng.choices(days, k=len(days))`, or how `random.Random(20261026)` is seeded across `(regime, s)` and shared between `d100` and `d50`. |
| 6 | s5's synthetic checks (`at most 1 of 12` and `9 of 10` bars, false-finding rate) | **DEFECT** | (a) In Part B (`research/cluster/PREREG.md:89-91`), requiring **two-sided** 95% intervals (`[2.5%, 97.5%]`) for `d100` and `d50` to include `0` on `>= 9 of 10` runs in each regime tests single-regime two-sided coverage (`alpha = 0.05` per interval), NOT Part B's one-sided both-regime `ROUND EFFECT` rule (`alpha = 0.025^2`), and **fails 30.3% to 59.6% of the time on a pure Gaussian random walk** (in our synthetic run with `seed 20261027`, calm got `8/10` on `d50` and `7/10` jointly, triggering a false `STOP`). (b) In s5.4 (`research/cluster/PREREG.md:92`), `the sum over k of arrivals = the moves less the moves into n = 0` fails whenever `|n| >= 15` unless `V_k` is summed over all `k >= 1` (not just `k = 1 ... 14`, `research/cluster/PREREG.md:48`). |
| 7 | s6's predictions (each falsifiable as written?) | **GAP** | Predictions 1, 2, and 3 are falsifiable (clarify `percentage points` on Prediction 2's `+1 and +8 points`). Prediction 4 (`after a THROUGH at R100 the continuation share above OTHER's`) omits the target distance (`L -/+ 2s` vs `through_mid -/+ s`), scale (`s = 5`), pooling, and regime (`calm`, `October`, or both). |
| 8 | s7's confirmation ("tea leaves", post-hoc bending vectors, missing elements) | **GAP** | (a) s7 (`research/cluster/PREREG.md:104-106`) says `by the same rule` on `Mon 26 Oct 00:00 to Fri 6 Nov 23:57`, but s3/s4's rules require **two regimes** (`calm` and `October`), leaving undefined whether the 2-week confirmation dump is split into 2 weekly segments or 1 carried segment, what seeds it uses, and whether Part A's `K` must match the in-sample direction (`K > cap` vs `K < cap`). Also, on 10 trading days, `median V_k >= 20` (`THIN`) will block wide scales in Part A. (b) For the operator's second question (`"a lot of back and forth around 'whole' numbers"`), Part B's `t_class` only measures single `s`-pip turn probability, missing arrival/oscillation density (`arrivals per level per day`) and sub-`s` chop around `R100`/`R50`. |

---

## Detailed Findings (Checks 1-8)

### 1. Your v1 findings: for each (1(a)-(c), 2-8), is it fixed in v2, and where?

- **Verdict:** **DEFECT** (1(b), 1(c), 2, 3, 5, and 7 are fixed or mostly fixed; **1(a) is NOT fixed**; **6 introduces a depth-truncation bug in s5.4's identity**).

#### 1(a) Immovable segment-start anchor `L0` vs EA stack anchor / re-centring
- **v1 quote (`origin/review/argon-cluster`):**
  - `reviews/argon_review_cluster.md:39` ``| 1 | Does it answer the question? (Measure vs EA anchor, L0, adds, re-centre, and s6 reading rule) | **DEFECT** | (a) In s2, the excursion anchor never moves from `L0` (the segment's first mid), whereas the EA places L0 at `mid -/+ width`, trails the flat opposite side's L0 via re-centring (`Grind_TryRecenterOppositeL0`), resets to flat when L0 closes (`entry +/- exit`), and shifts effective entries on rolls (`VL`). (b) By conservation of crossings on closed 1-step excursions (`EXTEND_k = RETRACE_{k+1}`), `p_k = C_k / (C_k + C_{k+1})` measures step-to-step activity decay at `k`, not whether a stack of depth `K` scalps: if price ranges freely across `k = 1 ... K` and turns back at `K` (`C_1 ~ ... ~ C_K >> C_{K+1}`), then `p_1 ~ ... ~ p_{K-1} ~ 50%` and `p_K >> 50%`, giving `K* = 0` under s5. (c) In s6, `cap` layers span `k = 0 ... cap - 1` steps of `a` from L0 and roll at `k = cap` (`PREREG_CAP.md:12`), so comparing `K*` directly to `cap` is off by 1 step. |``
  - `reviews/argon_review_cluster.md:102` ``     - **Re-centre and immovable anchor in s2:** In `PREREG.md:22-23, 27`, `n` is the current level minus the anchor's, the anchor starts at `L0`, and an excursion ends only at `n = 0` (`current level == anchor`). **No rule in s2 ever moves the anchor away from `L0`.** Thus the measure's anchor is permanently pinned to the segment's opening mid `L0` (Monday 00:00 in calm; 1 Oct 04:00 in October). In the EA (`MECHANICS.md:14-15`, `ea/grind_engine.mqh:3026-3071, 3224-3229`), while one side holds layers and the opposite side is flat, the flat side's L0 **re-centres** to `current_mid -/+ width` whenever `dist_pips > stranded` (`width + 1` pips) and outside `deadband` (2 pips); and whenever a stack closes its last (L0) layer at 1 step past L0, that side is flat and places a new L0 at `current_mid -/+ width`.``
- **v2 quote (`origin/main`):**
  - `research/cluster/PREREG.md:42` `- **Lattice:** levels at L0 + j x a, L0 = the segment's first mid; state n = the level index of the last level`
  - `research/cluster/PREREG.md:43` `  reached, relative to the anchor; the anchor = the level at the start of each excursion (the first, L0).`
  - `research/cluster/PREREG.md:45` `  level passed (m moves, in order). **An excursion** runs from leaving n = 0 to the next arrival at n = 0; a gap`
  - `research/cluster/PREREG.md:46` `  that passes through n = 0 ends the excursion at 0 and starts the next on the other side.`
- **Status:** **NOT FIXED.** Because an excursion ends only at `n = 0` (`research/cluster/PREREG.md:45-46`), the level at the start of the next excursion is still `n = 0` (`L0`). Thus `the anchor = the level at the start of each excursion (the first, L0)` (`research/cluster/PREREG.md:43`) is a tautology: the anchor never moves from `L0` inside a segment. When a segment drifts away from its opening mid `L0` and then ranges tightly around a new level (e.g., around `L0 - 8a`), all of that tight back-and-forth range trading is recorded as arrivals at deep levels `k = 6 ... 10` while `V_1` is starved, distorting `A_k = V_k / V_1`.

#### 1(b) `p_k` crossing conservation (`p_k` finds a wall, not a range)
- **v1 quote (`origin/review/argon-cluster`):**
  - `reviews/argon_review_cluster.md:105` ``     - **Crossing conservation (`EXTEND_k = RETRACE_{k+1}`) misses a flat-activity cluster that bounces at depth `K`:** On any closed 1-step excursion starting and ending at `n = 0`, every transition `|n|: k -> k + 1` (`EXTEND` at `k`) must be matched by a transition `|n|: k + 1 -> k` (`RETRACE` at `k + 1`). Hence `EXTEND_k = RETRACE_{k+1}` (up to at most 1 at a segment end and multi-level gaps), and `p_k = C_k / (C_k + C_{k+1})` where `C_k = RETRACE_k`. If a pair exhibits the operator's exact phenomenon (`PREREG.md:8`: `"there is a drop of in range trading activity after a certain distance. the ideal place for the roll would be at that point"`), so excursions range across `k = 1 ... K` and turn around at `K` (`C_1 ~ C_2 ~ ... ~ C_K >> C_{K+1}`), then `p_1 ~ ... ~ p_{K-1} ~ 50%` and only `p_K >> 50%`. Because s5 (`PREREG.md:54`) requires `REVERTING at every k = 1 ... K (0 if not at k = 1)`, that series gets **`K* = 0`**! Even a tight 1-step oscillation between `k = 4` and `k = 5` (which scalps profitably every bounce in the EA) scores 100% `EXTEND` at `k = 4` (`p_4 -> 0%`) and 100% `RETRACE` at `k = 5` (`p_5 -> 100%`).``
- **v2 quote (`origin/main`):**
  - `research/cluster/PREREG.md:18` `for a random walk; p_k moves only where crossings stop. **p_k finds a wall, not a range.** Hence:`
  - `research/cluster/PREREG.md:20` `- **Part A** counts activity per depth (the operator's "drop in range trading activity"): in the example 2`
  - `research/cluster/PREREG.md:22` `- **Part B** asks the wall question directly, where it belongs: does price turn more often at round numbers?`
  - `research/cluster/PREREG.md:47` `- **The measure:** V_k = arrivals at depth k = |n| (from either side), summed over the series; **A_k = V_k / V_1**,`
- **Status:** **FIXED** in concept in s1 (`research/cluster/PREREG.md:18, 20, 22`), s3 (`research/cluster/PREREG.md:47-57`), and s4 (`research/cluster/PREREG.md:64-80`) (subject to the cliff-example turnaround calculation defect in Check 2 below).

#### 1(c) Off-by-one between depth `k` and `cap`
- **v1 quote (`origin/review/argon-cluster`):**
  - `reviews/argon_review_cluster.md:106` ``     - **Off-by-one between `k` and `cap` in s6:** In the EA (`PREREG_CAP.md:12`), Layer 1 sits at L0 (`k = 0`), Layers `2 ... cap` sit at `k = 1 ... cap - 1`, and the first roll occurs at `k = cap`. Comparing `K*` directly to `cap` in s6 (`PREREG.md:64-68`) instead of `cap - 1` is off by 1 step.``
- **v2 quote (`origin/main`):**
  - `research/cluster/PREREG.md:58` `- **Against the caps (Argon 1(c)):** a stack with cap c holds layers at depths 0 ... c - 1 (L0 at the anchor) and`
  - `research/cluster/PREREG.md:59` `  rolls at depth c. **A CLUSTER of depth K reads: the layers at depths < K sit inside it; cap K would roll at the`
  - `research/cluster/PREREG.md:60` `  fall-off.** Against today's caps (OPT 7; C's three OPT 9; ALT 7): K > cap says more layers; K < cap fewer.`
- **Status:** **FIXED** in s3 (`research/cluster/PREREG.md:58-60`).

#### v1 Item 2: Gap crossing `n = 0`, `eps = 1e-9`, `1 pip = 0.0001`, segment bounds `from_ms <= time_msc_server <= to_ms`
- **v1 quote (`origin/review/argon-cluster`):**
  - `reviews/argon_review_cluster.md:40` ``| 2 | s2, the measure (first level, first passage, gap of `m` levels, `n = 0`, pooling, segment ends) | **DEFECT** | A multi-level gap of `m` steps from `n = -k` (`|n| = k >= 1`) that crosses `n = 0` to `n_new = -k + m > 0` fails under `RETRACE (|n| falls) or EXTEND (|n| rises)`: if `m = 2k`, `|n_new| == |n|` (neither outcome holds); if `m > 2k`, `|n_new| > |n|` (misclassified as `EXTEND` despite moving toward and through `n = 0`), and the excursion-end rule `At n = 0` is skipped. Also lacks floating-point epsilon (`1e-9` as in `grind_pure.mqh:18`) on level passage, explicit `1 pip = 0.0001`, and segment bounds `from_ms <= time_msc_server <= to_ms`. |``
- **v2 quote (`origin/main`):**
  - `research/cluster/PREREG.md:33` `E's six pairs. Mid = (bid + ask) / 2 per tick; a tick is in a segment when `from_ms <= time_msc_server <= to_ms``
  - `research/cluster/PREREG.md:34` ``(`research/opt_budget/runs.py` `window`). Pips: 0.0001 (all six pairs quote 5 digits). Prices compared to a level``
  - `research/cluster/PREREG.md:35` `with eps = 1e-9. One broker (IC 53077984); the ticks chose t3's adds (in-sample for Part A's scales; never used for`
  - `research/cluster/PREREG.md:44` `- **Moves:** a tick whose mid reaches the next level up or down. A tick that passes m > 1 levels counts every`
  - `research/cluster/PREREG.md:45` `  level passed (m moves, in order). **An excursion** runs from leaving n = 0 to the next arrival at n = 0; a gap`
  - `research/cluster/PREREG.md:46` `  that passes through n = 0 ends the excursion at 0 and starts the next on the other side.`
  - `research/opt_budget/runs.py:15` `def load_ticks(p):`
  - `research/opt_budget/runs.py:27` `            out.append((int(parts[it]), float(parts[ib]), float(parts[ia])))`
  - `research/opt_budget/runs.py:72` `def window(ticks, a, b):`
  - `research/opt_budget/runs.py:75` `    return ticks[bisect.bisect_left(ts, a):bisect.bisect_right(ts, b)]`
- **Status:** **FIXED** in s2 (`research/cluster/PREREG.md:33-35`) and s3 (`research/cluster/PREREG.md:44-46`).

#### v1 Item 3: Null baseline, shuffle gap representation, `0 / 0` / boundary pinning, 1,000 permutations, RNG seed, quantile index
- **v1 quote (`origin/review/argon-cluster`):**
  - `reviews/argon_review_cluster.md:41` ``| 3 | s4, the nulls (50% RW baseline, shuffle drift/dependence, 200 permutations, seed) | **DEFECT** | (a) On finite drifting segments with excursion-coupled steps, 50% is not the null expectation and Wilson intervals are invalid (`PREREG.md:98-99`). (b) In the shuffle, `gaps kept as their own runs of m` conflicts with line 25 (`counts as ONE decision`): expanding a gap of `m` into `m` unit moves changes the decision count; moreover, when a shuffled path has `N_k == 0`, `p_k = 0 / 0` is undefined, and when `>= 5` of 200 shuffles reach max depth `k` once (`p_k = 1 / 1 = 100%`), the 97.5% quantile is `100%`, making `p_k > shuffle_97.5%` impossible. (c) 200 permutations gives only 5 tail draws at 2.5%/97.5% without a quantile index rule, and `seed 20261025` does not fix the RNG library, method, or per-series vs global seeding scope. |``
- **v2 quote (`origin/main`):**
  - `research/cluster/PREREG.md:50` `- **Null (the shuffle):** the series' moves (a gap's m moves kept together as one block, in its direction) permuted`
  - `research/cluster/PREREG.md:51` ``  1,000 times, generator `random.Random(20261025 + i)`, i = the series' index in s3's order (pairs as listed, OPT``
  - `research/cluster/PREREG.md:52` `  then ALT, calm then October); A_k recomputed each time; the band = the 26th and 975th of the 1,000 sorted values.`
  - `research/cluster/PREREG.md:53` `  A permutation with V_1 = 0 or V_k undefined is skipped and counted.`
- **Status:** **PARTIALLY FIXED** in s3 (`research/cluster/PREREG.md:50-53`). The 1,000 permutations, gap-block consistency (`m` moves in both real and shuffle), and `random.Random(20261025 + i)` per series are fixed; however, permuting `the series' moves` across calm's 8 weekly segments instead of within each segment (and indexing `26th and 975th of the 1,000` when `V_1 = 0` permutations are skipped) remains defective (see Check 2).

#### v1 Item 4: Multiple-testing guard, October sample size (`THIN`), break-even `p*`
- **v1 quote (`origin/review/argon-cluster`):**
  - `reviews/argon_review_cluster.md:42` ``| 4 | s5, the definitions (noise rate across 24 x 15 cells, both-regimes guard, `N_k >= 30`, break-even `p*`) | **DEFECT** | Across `24 x 15 = 360` cells, the 97.5% shuffle cutoff lets ~9 false `REVERTING` cells through by chance; anchoring `K*` at `k = 1` and requiring `K* >= 2` in both regimes cuts false `CLUSTER`s to `< 1%` across 12 pair-scales, but kills power: in October's single segment (`15` trading days), `N_k >= 30` is unreachable at wide scales (`a = 14..26`), and at `N_k = 30` (`SE = 9.1%`, 97.5% binomial cutoff `20/30 = 66.7%`) a true 60% retrace rate has ~18% power. Break-even `p* = (a + c + s) / (2a)` is right for a market-order mid bet (`c = $0.06 / pip_usd` already covers both legs), whereas the EA's limit-to-limit scalp pays only commission `c` out of the `a`-pip scalp and absorbs spread `s` in fill distance (`a + s`). |``
- **v2 quote (`origin/main`):**
  - `research/cluster/PREREG.md:54` `- **DROP at k:** A_k below the band's lower edge, counted only where the shuffle's median V_k is at least 20 (with`
  - `research/cluster/PREREG.md:55` `  fewer, depth k is too thin to read: reported as THIN).`
  - `research/cluster/PREREG.md:56` `- **The fall-off K:** the smallest k >= 2 with DROP at k and at k + 1 (two in a row). None: K = none.`
  - `research/cluster/PREREG.md:57` `- **A CLUSTER (pair, scale):** K exists in BOTH regimes; its depth = the smaller K.`
- **Status:** **FIXED** (break-even `p*` removed; threshold lowered from `N_k >= 30` to shuffle median `V_k >= 20`, with `DROP at k and at k + 1` in both regimes).

#### v1 Item 5: Data table, segment windows, hashes, disclosures
- **v1 quote (`origin/review/argon-cluster`):**
  - `reviews/argon_review_cluster.md:43` ``| 5 | s3, the data (segments, hashes, in-sample ticks, one broker, EURUSD October filename) | **CONFIRMED** | All 8 calm segments (`run_swcapw_<pair>.csv`), 1 October segment (`run_swcapo_<pair>.csv`), tick filenames, sha256 prefixes, and t3 scales match the repo records (`sweep_notes.md`, `runs.py`, `inputs/swcap/*.csv`). In-sample selection (`sweep11`) and single-broker (`IC 53077984`) are disclosed in s3 and s10; EURUSD's `ticks_53077984_EURUSD_w2hw.csv` is windowed to the same `[1790827200000, 1792539900000]` segment as `*_oct.csv`. |``
- **v2 and source quotes (`origin/main`):**
  - `research/cluster/PREREG.md:30` ``| calm | `ticks_53077984_<PAIR>__h8w.csv` | the 8 weekly segments of `inputs/swcap/run_swcapw_<pair>.csv` (3 Aug - 25 Sep, server time) | starts EURUSD `10e95fec`, GBPUSD `d3c8c37a`, EURGBP `1de6ee93`, AUDCAD `a3791e0b`, AUDCHF `69b567b2`, CADCHF `6ff77bfa` |``
  - `research/cluster/PREREG.md:31` ``| October | `ticks_53077984_<PAIR>_oct.csv`; EURUSD `ticks_53077984_EURUSD_w2hw.csv` | the one segment of `run_swcapo_<pair>.csv` (1 Oct 04:00 - 20 Oct 23:45 server) | GBPUSD `7c1c080f`, EURGBP `9139142b`, AUDCAD `f1be6881`, AUDCHF `df6a785d`, CADCHF `09d6aced`, EURUSD `93816e45` |``
  - `research/opt_budget/runs.py:7` `T3 = {"GBPUSD": (9, 15), "EURUSD": (7, 23), "EURGBP": (5, 23), "AUDCAD": (18, 26), "AUDCHF": (14, 20), "CADCHF": (10, 17)}`
  - `research/replay/inputs/swcap/run_swcapw_eurusd.csv:2` `1,GRIND_EURUSD_OPTD,22260201,1785715200000,1786146300000,2.0,2.0,7.0,7.0,7.0,7.0,9,3.0,2.0,1,1,0,0,1,8,,ticks_53077984_EURUSD__h8w.csv,,sessions_eurusd_ic.csv`
  - `research/replay/inputs/swcap/run_swcapw_eurusd.csv:9` `8,GRIND_EURUSD_OPTD,22260201,1789948800000,1790379900000,2.0,2.0,7.0,7.0,7.0,7.0,9,3.0,2.0,1,1,0,0,1,8,,ticks_53077984_EURUSD__h8w.csv,,sessions_eurusd_ic.csv`
  - `research/replay/inputs/swcap/run_swcapo_eurusd.csv:2` `1,GRIND_EURUSD_OPTD,22260201,1790827200000,1792539900000,2.0,2.0,7.0,7.0,7.0,7.0,9,3.0,2.0,1,1,0,1,1,8,,ticks_53077984_EURUSD_w2hw.csv,,sessions_eurusd_ic.csv`
  - `research/replay/inputs/swcap.sha256:11` `d50a92549a223f370d13a54e407fbdd13f9fb11fd9a45c30a86e455f79181051  swcap/run_swcapw_eurusd.csv`
  - `research/replay/results/sweep_notes.md:466` `**Data:** the h8w ticks (sweep4: wine-d, 11 Oct; 3 Aug 00:00 to 1 Oct 04:00 server; sha256 starts EURUSD`
  - `research/replay/results/sweep_notes.md:467` ``10e95fec`, GBPUSD `d3c8c37a`, EURGBP `1de6ee93`, AUDCAD `a3791e0b`, AUDCHF `69b567b2`, CADCHF `6ff77bfa`).`
  - `research/replay/results/sweep_notes.md:666` `    7c1c080f5b3d71a313f32d2538472a935c0e3b0513e82af574ac35350db59e95  48935532  ticks_53077984_GBPUSD_oct.csv  (1,417,912 ticks)`
  - `research/replay/results/sweep_notes.md:670` `    09d6aced415c024232ea7df69239ff96c01b142e3350e3e8b55cb163588d14b5  39639857  ticks_53077984_CADCHF_oct.csv  (1,154,993)`
- **Status:** **CONFIRMED** (preserved in s2, `research/cluster/PREREG.md:30-31, 33-35`, and the v1 typo `(s8)` is fixed).

#### v1 Item 6: Self-checks (calm `TICKS_LOADED`, synthetic seed, conservation identity)
- **v1 quote (`origin/review/argon-cluster`):**
  - `reviews/argon_review_cluster.md:44` ``| 6 | s7, the self-checks (sufficiency and Check 3's identity) | **DEFECT** | Check 3's identity (`the sum of N_k equals the number of moves less the moves from n = 0 less the dropped end decisions`) is wrong: an open decision at a segment's end is an uncompleted state waiting for a move that never occurred (not counted in `the number of moves`), so subtracting `less the dropped end decisions` fails by 1 per segment ending at `|n| >= 1` (including s9's own 10-level straight-run test: `9 != 10 - 1 - 1`). Check 1 also omits the recorded calm `TICKS_LOADED` counts (`sweep_notes.md:833-834`) and `inputs/swcap.sha256`, and Check 2 omits the synthetic walk's seed number. |``
- **v2 and source quotes (`origin/main`):**
  - `research/cluster/PREREG.md:48` `  k = 1 ... 14. A driftless random walk's profile is flat (equal expected arrivals at every depth per excursion);`
  - `research/cluster/PREREG.md:84` ``1. The tick files' sha256 equal the recorded ones; counts equal the replay's `TICKS_LOADED` where recorded``
  - `research/cluster/PREREG.md:85` ``   (October: sweep10's; EURUSD w2hw 1,021,095; calm: sweep8's logs, `sweep_notes.md` 833-834).``
  - `research/cluster/PREREG.md:86` `2. The tests pass (s8).`
  - `research/cluster/PREREG.md:87` `3. **Synthetic random walks** (seed 20261027; per series the same number of moves and the same overall up / down`
  - `research/cluster/PREREG.md:92` `4. Identities: per series, the sum over k of arrivals = the moves less the moves into n = 0; per class, TURN +`
  - `research/cluster/PREREG.md:93` `   THROUGH + dropped = arrivals.`
  - `research/replay/results/sweep_notes.md:833` ``sync 0, `TIMING|1|base`, `SESSIONS|...|5`, `TICKS_LOADED` the run's ticks file (h8w counts as sweep8's logs: EURUSD``
  - `research/replay/results/sweep_notes.md:834` `2,888,015, GBPUSD 4,282,592, EURGBP 2,515,345, AUDCAD 4,528,672, AUDCHF 3,785,001, CADCHF 3,167,556; October as`
- **Status:** **PARTIALLY FIXED / NEW DEFECT.** Calm `TICKS_LOADED` (`research/replay/results/sweep_notes.md:833-834`) and `seed 20261027` are fixed (`research/cluster/PREREG.md:84-87`), and `less the dropped end decisions` is gone (`research/cluster/PREREG.md:92`). However, `research/cluster/PREREG.md:48` restricts `k` to `k = 1 ... 14` (dropping v1's pooled `15 or more`), so `the sum over k of arrivals = the moves less the moves into n = 0` (`research/cluster/PREREG.md:92`) fails whenever an excursion reaches `|n| >= 15` unless `the sum over k of arrivals` explicitly sums over all `k >= 1` (see Check 6).

#### v1 Item 7: Falsifiability of predictions
- **v1 quote (`origin/review/argon-cluster`):**
  - `reviews/argon_review_cluster.md:45` ``| 7 | s8, the predictions (falsifiability as written) | **DEFECT** | Only Prediction 3 is falsifiable as written. Predictions 1 (`Most p_k`), 2 (`lean above 50%`; `in October they do not`), and 4 (`No clear fall-off inside 7`, which conflicts with s5's exact definition `The fall-off: the first k > K* that is not REVERTING`) lack numeric count thresholds. |``
- **v2 quote (`origin/main`):**
  - `research/cluster/PREREG.md:97` `1. Part A: a CLUSTER on at most 1 of the 12 pair-scales; none at ALT's scale.`
  - `research/cluster/PREREG.md:98` `2. Part B, calm, s = 5: pooled d100 between +1 and +8 points; d50 smaller than d100.`
  - `research/cluster/PREREG.md:99` `3. Part B: a ROUND EFFECT at R100 in both regimes (lean, from Osler); none at R50.`
  - `research/cluster/PREREG.md:100` `4. Osler's second effect (reported): after a THROUGH at R100 the continuation share above OTHER's.`
- **Status:** **MOSTLY FIXED** in s6 (`research/cluster/PREREG.md:97-100`); only Prediction 4 still lacks regime/scale/pooling qualifiers (see Check 7).

#### v1 Item 8: Post-hoc bending vectors and missing elements
- **v1 quote (`origin/review/argon-cluster`):**
  - `reviews/argon_review_cluster.md:46` ``| 8 | Post-hoc bending vectors and missing elements for the operator's question | **GAP** | Post-hoc bending vectors: unfixed calm-only fallback if October has `K* < 2` (as Prediction 2 anticipates), missing `K* == cap` tie case in s6, and unfixed shuffle/gap details. Missing for the operator's question: scales finer/coarser than t3's two adds (to separate physical range `K * a` in pips from layer count `K`), range-trading activity rate (`N_k / day`) per depth, and excursion holding time (stack age) / session time-of-day. |``
- **v2 quote (`origin/main`):**
  - `research/cluster/PREREG.md:59` `  rolls at depth c. **A CLUSTER of depth K reads: the layers at depths < K sit inside it; cap K would roll at the`
  - `research/cluster/PREREG.md:60` `  fall-off.** Against today's caps (OPT 7; C's three OPT 9; ALT 7): K > cap says more layers; K < cap fewer.`
  - `research/cluster/PREREG.md:104` `A finding from s3 or s4 counts as **CONFIRMED** only if it also holds, by the same rule, on **new ticks: E's six`
  - `research/cluster/PREREG.md:105` `pairs from Mon 26 Oct 00:00 to Fri 6 Nov 23:57 server**, dumped on wine-d (IC 53077984, as every h8w and `_oct``
- **Status:** **PARTIALLY FIXED.** Out-of-sample confirmation is added in s7 (`research/cluster/PREREG.md:104-107`) and `cap K would roll at the fall-off` covers the tie conceptually (`research/cluster/PREREG.md:59`), while finer/coarser scales, `V_k / day`, and confirmation window segmentation remain open (see Check 8).

---

### 2. Part A's measure: `A_k = V_k / V_1`, cliff example, shuffle, two DROPs in a row, and THIN

- **Verdict:** **DEFECT**
- **Quotes:**
  - `research/cluster/PREREG.md:15` `price swings 1.1600 -> 1.1572 -> 1.1600 for ever (depth 0 to 4 and back). Each swing gives at depth 1 one step out`
  - `research/cluster/PREREG.md:20` `- **Part A** counts activity per depth (the operator's "drop in range trading activity"): in the example 2`
  - `research/cluster/PREREG.md:21` `  crossings per swing at each of depths 1-4 and none at 5, a cliff at K = 4.`
  - `research/cluster/PREREG.md:40` `- **Series:** pair x scale a x regime; a = the pair's t3 OPT add and t3 ALT add (GBPUSD 9 / 15, EURUSD 7 / 23, EURGBP`
  - `research/cluster/PREREG.md:47` `- **The measure:** V_k = arrivals at depth k = |n| (from either side), summed over the series; **A_k = V_k / V_1**,`
  - `research/cluster/PREREG.md:48` `  k = 1 ... 14. A driftless random walk's profile is flat (equal expected arrivals at every depth per excursion);`
  - `research/cluster/PREREG.md:49` `  the cliff example gives A_1 ... A_4 = 1, A_5 = 0.`
  - `research/cluster/PREREG.md:50` `- **Null (the shuffle):** the series' moves (a gap's m moves kept together as one block, in its direction) permuted`
  - `research/cluster/PREREG.md:51` ``  1,000 times, generator `random.Random(20261025 + i)`, i = the series' index in s3's order (pairs as listed, OPT``
  - `research/cluster/PREREG.md:52` `  then ALT, calm then October); A_k recomputed each time; the band = the 26th and 975th of the 1,000 sorted values.`
  - `research/cluster/PREREG.md:53` `  A permutation with V_1 = 0 or V_k undefined is skipped and counted.`
  - `research/cluster/PREREG.md:54` `- **DROP at k:** A_k below the band's lower edge, counted only where the shuffle's median V_k is at least 20 (with`
  - `research/cluster/PREREG.md:55` `  fewer, depth k is too thin to read: reported as THIN).`
  - `research/cluster/PREREG.md:56` `- **The fall-off K:** the smallest k >= 2 with DROP at k and at k + 1 (two in a row). None: K = none.`
  - `research/cluster/PREREG.md:57` `- **A CLUSTER (pair, scale):** K exists in BOTH regimes; its depth = the smaller K.`
  - `research/cluster/PREREG.md:111` ``research/cluster/cluster.py` with `test_cluster.py` first, in their own commit, against a stub, hand values: A: the`
  - `research/cluster/PREREG.md:112` `v1 cliff (1.1600 <-> 1.1572 at 7 pips) gives A_1 ... A_4 = 1 and A_5 = 0; a 10-level straight run gives V_1 ... V_10 =`
- **Analysis:**
  1. **Is `A_k = V_k / V_1` flat for a driftless random walk (finite segments, the last excursion open)? NO.**
     - For an **infinite-horizon completed excursion** from `|n| = 1` back to `0`, gambler's ruin gives `P(reach k before 0 | start at 1) = 1 / k` and expected visits to `k` before `0` given reaching `k` equal to `2k`, so `E[V_k per completed excursion] = (1 / k) * (2k) = 2` for all `k >= 1`.
     - On **finite segments with the last excursion open** (total moves `N < inf`), `sum_{k>=1} V_k <= N`, and excursions that would reach depth `k` require `O(k^2)` steps and are truncated at segment end:
       - In our synthetic check (`random.Random(20261027)`, 1,000 walks of `8` weekly segments x `50` moves = `400` moves, resetting `n = 0` per segment), median `V_k` decays monotonically (`[75, 63, 51, 42, 32, 26, 19, 15, 10, 8, 5, 3, 2, 1]` for `k = 1 ... 14`) and median `A_k` decays monotonically from `1.000` (`k = 1`) to `0.844` (`k = 2`), `0.680` (`k = 3`), `0.565` (`k = 4`), `0.244` (`k = 7`), and `0.012` (`k = 14`).
       - On 1 segment of `400` moves without weekly resets (`random.Random(20261025)`, 2,000 walks), `E[V_k]` falls from `30.0` (`k = 1`) to `11.4` (`k = 14`) and median `A_k` falls from `1.000` (`k = 1`) to `0.854` (`k = 4`) and `0.367` (`k = 14`), while mean `E[A_k] = E[V_k / V_1]` rises to `1.40` at `k = 10-11` because open excursions that wander away from `0` early have small `V_1` (`1` or `2`) and large `V_k`.
     - Because `DROP at k` (`research/cluster/PREREG.md:54`) compares `A_k` against **the shuffle's 2.5% band** rather than `1.0`, finite-segment decay is absorbed by the shuffle null *provided* the shuffle preserves segment boundaries (see item 3 below).
  2. **Does the cliff example compute as written? NO -- `A_4 = 0.5`, not `1`.**
     - In `research/cluster/PREREG.md:15, 20-21, 49, 111-112`, one swing of `1.1600 -> 1.1572 -> 1.1600` at 7-pip steps is the 8-move cycle `0 -> -1 -> -2 -> -3 -> -4 -> -3 -> -2 -> -1 -> 0`.
     - Under `V_k = arrivals at depth k = |n|` (`research/cluster/PREREG.md:47`), each swing arrives at `k = 1` twice (`0 -> -1`, `-2 -> -1`), `k = 2` twice (`-1 -> -2`, `-3 -> -2`), `k = 3` twice (`-2 -> -3`, `-4 -> -3`), **`k = 4` ONCE** (`-3 -> -4`; the return step `-4 -> -3` arrives at `3`, not `4`), and `k = 5` zero times (`V_5 = 0`).
     - Verified in Python (`[-1, -1, -1, -1, 1, 1, 1, 1] * 50`): `V_1..V_6 = [100, 100, 100, 50, 0, 0]`, giving **`A_1 = 1.0, A_2 = 1.0, A_3 = 1.0, A_4 = 0.5, A_5 = 0.0`**.
     - Why the discrepancy? Each swing has 2 **step traversals** across `[k - 1, k]` (i.e., `max(|n_prev|, |n_new|) == k`) for `k = 1, 2, 3, 4`, but only 1 **arrival** at the turnaround state `|n| = 4`. As written, `test_cluster.py` (`research/cluster/PREREG.md:112`: `gives A_1 ... A_4 = 1 and A_5 = 0`) contradicts `research/cluster/PREREG.md:47` (`V_k = arrivals at depth k = |n|`) and will halt at Self-Check 2 (`research/cluster/PREREG.md:86`).
  3. **Does the shuffle (moves permuted, gaps as blocks) keep the drift and remove the structure? ONLY if permuted within each segment with `n = 0` reset per segment.**
     - In calm (`research/cluster/PREREG.md:30`), each series has **8 weekly segments**, each starting at `n = 0` (`L0 = the segment's first mid`, `research/cluster/PREREG.md:42`).
     - `research/cluster/PREREG.md:50` says `the series' moves (a gap's m moves kept together as one block, in its direction) permuted 1,000 times`. If all 8 segments' moves are concatenated and permuted across the whole series:
       - If `n = 0` is not reset at the 8 segment boundaries in the shuffle, the shuffled walk is 1 segment of `8x` length (`median A_4 = 0.854` vs `0.565` for `8` reset segments); in our 200-trial Python simulation (`task-44`, `random.Random(20261027)`), that mismatch quadruples the single-regime false-`K` rate on a driftless random walk from `5/200 (2.5%)` to `20/200 (10.0%)`.
       - Even if `n = 0` is reset at segment boundaries, permuting moves across the 8 weeks destroys each week's drift (e.g., 4 weeks drifting `+20` and 4 weeks drifting `-20` have zero net 8-week drift when pooled, so the shuffle generates driftless weeks with much lower deep `A_k` than the real drifting weeks).
     - Permuting each segment's move-blocks **within each segment** (`rng.shuffle` on each segment's move list, resetting `n = 0` at each segment start) preserves every segment's exact drift and gap-block structure while removing serial structure.
  4. **Is `"two DROPs in a row, in both regimes"` a fair guard, and is `THIN` well defined?**
     - Within a single regime (`within_seg_reset` in `task-44`), `DROP at k and at k + 1` for some `k in 2 ... 13` occurs on `~2.5%` to `5%` of random walks (because `A_k` and `A_{k+1}` on the same path have correlation `~0.9`, so `P(DROP_{k+1} | DROP_k) ~ 0.5-0.7`, offset by scanning 12 depth pairs). Requiring `K exists in BOTH regimes` (`calm` and `October`, independent windows) reduces the false-`CLUSTER` rate per pair-scale to `~0.04^2 = 0.16%` (`~0.02` expected false `CLUSTER`s across 12 pair-scales), which is a fair guard.
     - Two small definition gaps in `research/cluster/PREREG.md:52-55`:
       - **Skipped permutations and quantile indexing (`research/cluster/PREREG.md:52-53`):** If `s > 0` permutations have `V_1 = 0` and are skipped, there are `M = 1,000 - s < 1,000` sorted values, so `the 26th and 975th of the 1,000 sorted values` is out of bounds if `M < 975` (and `V_k` is an integer count `>= 0`, never "undefined"). Fix by indexing `sorted_vals[int(0.025 * M)]` and `sorted_vals[int(0.975 * M)]` (which equal 0-based `sorted_vals[25]` = 26th and `sorted_vals[974]` = 975th when `M = 1,000`).
       - **`THIN` (`research/cluster/PREREG.md:54-55`):** With `M` valid permutations (an even number `1,000` when none are skipped), specify whether `the shuffle's median V_k` is `sorted_V[M // 2]` (or `(sorted_V[(M - 1) // 2] + sorted_V[M // 2]) / 2`).
- **Smallest fix to `research/cluster/PREREG.md`:**
  - In `research/cluster/PREREG.md:20-21, 48-55, 111-112`, either (Option A, smallest text change keeping `V_k = arrivals at depth k = |n|`) update the cliff example's `k = 4` turnaround value to `1 arrival at 4` (`A_1 ... A_3 = 1, A_4 = 0.5, A_5 = 0`), or (Option B, if `A_1 ... A_4 = 1` is desired) define `V_k` as step traversals between `k - 1` and `k` (`max(|n_prev|, |n_new|) == k`); and specify within-segment shuffling and `M`-based quantile indexing:
    ```markdown
    - **The measure:** V_k = arrivals at depth k = |n| (from either side), summed over the series' segments (resetting n = 0 at each segment start); **A_k = V_k / V_1**, k = 1 ... 14. On an infinite completed excursion a driftless random walk's profile is flat; the cliff example (1.1600 <-> 1.1572) gives V_1 = V_2 = V_3 = 2, V_4 = 1 (the turnaround), V_5 = 0 per swing, so A_1 ... A_3 = 1, A_4 = 0.5, A_5 = 0 (K = 4).
    - **Null (the shuffle):** within each segment of the series, the segment's move blocks (each normal move +/-1, or a gap's m moves kept together as one block +/-m) are permuted in place 1,000 times (`rng.shuffle`), generator `random.Random(20261025 + i)`, i = 0 ... 23 in s3's order (pairs as listed, OPT then ALT, calm then October); A_k is recomputed across the series each time. Permutations with V_1 = 0 are skipped and counted; over the M remaining permutations, the band = `sorted_A[int(0.025 * M)]` (26th when M = 1,000) and `sorted_A[int(0.975 * M)]` (975th when M = 1,000).
    - **DROP at k:** A_k strictly below the band's lower edge, counted only where `sorted_V[M // 2] >= 20` (with fewer, depth k is reported as THIN and cannot be a DROP).
    ```

---

### 3. Part A against the caps: is `"cap c holds depths 0 ... c - 1, rolls at c"` right for the EA, and does the reading rule follow?

- **Verdict:** **CONFIRMED**
- **Quotes:**
  - `research/cluster/PREREG.md:58` `- **Against the caps (Argon 1(c)):** a stack with cap c holds layers at depths 0 ... c - 1 (L0 at the anchor) and`
  - `research/cluster/PREREG.md:59` `  rolls at depth c. **A CLUSTER of depth K reads: the layers at depths < K sit inside it; cap K would roll at the`
  - `research/cluster/PREREG.md:60` `  fall-off.** Against today's caps (OPT 7; C's three OPT 9; ALT 7): K > cap says more layers; K < cap fewer.`
  - `research/opt_budget/PREREG_CAP.md:12` `Cap 7: OPT holds 1.1600 ... 1.1558 and rolls from 1.1551 (the 1.1600 layer's exit moves to 1.1558). Cap 11: it also`
  - `research/opt_budget/MECHANICS.md:10` ``- **Depth** = open layers on the side (`grind_engine.mqh` 2015). Entries allowed while depth < cap (`grind_pure.mqh` 229).``
  - `research/opt_budget/MECHANICS.md:16` `- **Adds:** target = anchor - add (long) / + add (short); anchor = the deepest layer's entry, or, if any layer is`
  - `research/opt_budget/MECHANICS.md:33` ``- Only when depth >= cap (`grind_engine.mqh` 1401-1415). Roll gate: no roll while the OPPOSITE side holds more than``
  - `research/opt_budget/MECHANICS.md:35` `- Level = the add target (above). Crossed when the probe (long: min(ask, the lowest ask since the newest layer`
  - `ea/grind_pure.mqh:154` `   return anchor_entry - (double)direction * Grind_PipsToPrice(add_pips, point);`
  - `ea/grind_pure.mqh:229` `bool Grind_CanPlaceEntryLayer(const int current_layers, const int max_layers)`
  - `ea/grind_pure.mqh:231` `   return (current_layers < max_layers);`
  - `ea/grind_engine.mqh:1303` `      if(Grind_SideDepth(side) < max_layers)`
  - `ea/grind_engine.mqh:1306` `      const double level = Grind_Normalize(Grind_ComputeAddTarget(side, is_long, add_pips));`
  - `ea/grind_engine.mqh:1314` `      if(!Grind_LatticeLevelCrossed(is_long, probe, level))`
  - `ea/grind_engine.mqh:1404` `   if(Grind_SideDepth(g_grind_long) >= max_layers)`
  - `ea/grind_engine.mqh:2057` `   if(!Grind_CanPlaceEntryLayer(Grind_SideDepth(side), max_layers))`
  - `ea/grind_engine.mqh:2271` `      anchor = side.layers[depth_idx].entry_price;`
  - `ea/grind_engine.mqh:2286` `   return Grind_AddTargetPrice(anchor, add_pips, _Point, is_long ? 1 : -1);`
  - `ea/grind_engine.mqh:2309` `   if(n <= 0 || !Grind_CanPlaceEntryLayer(n, max_layers))`
- **Analysis:**
  - In the EA, `Grind_TryPlaceL0` (`ea/grind_engine.mqh:2057`) places layer `0` (`L0`, depth `0` from the stack's anchor) when `current_layers == 0 < max_layers`.
  - Subsequent adds in `Grind_SendNextAddEnt` / `Grind_EnsureAddNext` (`ea/grind_engine.mqh:2309`) are allowed while `Grind_CanPlaceEntryLayer(n, max_layers)` (`n < max_layers`, `ea/grind_pure.mqh:229, 231`) is true, placing layers `1, 2, ..., c - 1` at `anchor -/+ add_pips` (`ea/grind_engine.mqh:2271, 2286`), i.e., at depths `1 ... c - 1` from `L0`.
  - Once `Grind_SideDepth(side) == max_layers` (`c` open layers spanning depths `0 ... c - 1`), `Grind_CanPlaceEntryLayer(c, c)` is `false` and `Grind_LatticeOnTick` / `Grind_LatticeTrySide` (`ea/grind_engine.mqh:1303, 1306, 1314, 1404`) computes the roll `level` via `Grind_ComputeAddTarget` one step `a` beyond the deepest layer (`c - 1`), which sits at depth `c` (matching `research/opt_budget/PREREG_CAP.md:12`: cap 7 holds `1.1600 ... 1.1558` [depths `0 ... 6`] and rolls at `1.1551` [depth `7`]).
  - Because `K` in `research/cluster/PREREG.md:56` is the **fall-off** depth (`the smallest k >= 2 with DROP at k and at k + 1`), the active cluster spans depths `0 ... K - 1` (`< K`) and drops off at depth `K`. A stack with `cap = K` holds layers at depths `0 ... K - 1` and rolls at depth `K`, so `K > cap` means more layers, `K < cap` means fewer layers, and `K == cap` means the current cap already rolls at the fall-off.

---

### 4. Part B's measure: arrival, re-arm, TURN and THROUGH, R100 / R50 / OTHER, and classes as control

- **Verdict:** **GAP**
- **Quotes:**
  - `research/cluster/PREREG.md:34` ``(`research/opt_budget/runs.py` `window`). Pips: 0.0001 (all six pairs quote 5 digits). Prices compared to a level``
  - `research/cluster/PREREG.md:35` `with eps = 1e-9. One broker (IC 53077984); the ticks chose t3's adds (in-sample for Part A's scales; never used for`
  - `research/cluster/PREREG.md:64` `- **Levels:** every 5 pips (multiples of 0.0005). **Classes:** R100 (multiples of 100 pips: 1.1600, 0.9800), R50`
  - `research/cluster/PREREG.md:65` `  (multiples of 50 pips, not of 100: 1.1650), OTHER (the rest).`
  - `research/cluster/PREREG.md:66` `- **Scale:** s = 5 pips (primary) and s = 10 pips (reported, not deciding).`
  - `research/cluster/PREREG.md:67` `- **An arrival at level L:** the first tick whose mid reaches L (at or beyond it, eps) from one side, after the mid`
  - `research/cluster/PREREG.md:68` `  has been at least s away from L on that side since L's last arrival (re-armed). The arrival side = the side it came`
  - `research/cluster/PREREG.md:69` `  from.`
  - `research/cluster/PREREG.md:70` `- **The outcome:** after the arrival, which comes first: the mid back at L + s on the arrival side (**TURN**) or at L`
  - `research/cluster/PREREG.md:71` `  - s on the far side (**THROUGH**); a gap past L - s is THROUGH. An arrival still open at the segment's end is`
  - `research/cluster/PREREG.md:72` `  dropped and counted.`
  - `research/cluster/PREREG.md:73` `- **Rates:** t_class = TURN / (TURN + THROUGH), per pair, per regime, and pooled over the six pairs.`
  - `research/cluster/PREREG.md:76` `  1,950th of the sorted differences). A random walk gives the same t in every class (a class has no meaning to it),`
  - `research/cluster/PREREG.md:77` `  so the classes are each other's control; no shuffle.`
  - `research/cluster/PREREG.md:114` `the up / down count and the gap blocks. B: a bounce off 1.1600 from above is TURN; a gap from 1.1607 to 1.1592 is`
  - `research/cluster/PREREG.md:115` `THROUGH; a re-arm needs s away first; an open arrival at the end is dropped. Then the code; then the operator runs`
- **Analysis:**
  1. **Are the arrival, re-arm, TURN, and THROUGH defined without gaps?**
     - Because `research/cluster/PREREG.md:67-68` defines arming and arrivals per level `L` (`since L's last arrival`), each 5-pip level `L` has its own independent state machine, which handles **an arrival at one level while another is open** (routine at `s = 10` pips, where levels are 5 pips apart) and **two or more levels crossed in one tick** (each armed level `L` reached on that tick records its own arrival).
     - Likewise, once `L` is armed on a side (say above, `mid >= L + s - eps`), `mid` cannot reach the opposite arming zone (`<= L - s + eps`) without first reaching `<= L + eps` and triggering `L`'s arrival; and once `L` is open, the very first tick that reaches distance `>= s` from `L` (`>= L + s - eps` or `<= L - s + eps`) simultaneously resolves the outcome (`TURN` or `THROUGH`) and re-arms `L` on that side.
     - **Three small specification gaps in `research/cluster/PREREG.md:67-71`:**
       - **(a) Initial arming before `L`'s first arrival in a segment:** Line 68 says `since L's last arrival (re-armed)`. Before `L`'s **first** arrival in a segment, `mid` must also have been at least `s` away from `L` (`mid >= L + s - eps` to arm from above, or `mid <= L - s + eps` to arm from below). Otherwise a level `L` within `< s` of the segment's opening `mid_0` (or `L == mid_0`) would fire an arrival on its first touch without an `s`-pip approach.
       - **(b) Single-tick gap past `L -/+ s` (`1.1607 to 1.1592`, `research/cluster/PREREG.md:114-115`):** On a 2-tick jump from `1.1607` (`>= L + s`) straight to `1.1592` (`<= L - s`), tick 2 (`1.1592`) is **both** the arrival tick at `L = 1.1600` and the `THROUGH` tick. Line 70 says `after the arrival, which comes first`; it should say `on or after the arrival tick` so that an arrival tick already at or beyond the far-side `L -/+ s` threshold resolves immediately on that tick as `THROUGH` (and re-arms `L` on the far side).
       - **(c) Directional sign in `L + s` / `L - s` (`research/cluster/PREREG.md:70-71`):** Line 70 writes `L + s on the arrival side (TURN) or at L - s on the far side (THROUGH)`, which assumes arrival from above. State `L +/- s on the arrival side (TURN) or L -/+ s on the far side (THROUGH)`.
  2. **Are `R100 / R50 / OTHER` right for the six pairs' 5-digit quotes? YES.**
     - All six pairs (`GBPUSD, EURUSD, EURGBP, AUDCAD, AUDCHF, CADCHF`) quote 5 digits (`point = 0.00001`, `1 pip = 0.0001`), so 5-pip levels are multiples of `0.0005` (`integer_pips = round(L * 10000)` divisible by `5`), `R100` is `integer_pips % 100 == 0` (`0.0100`), `R50` is `integer_pips % 100 == 50`, and `OTHER` is `integer_pips % 50 != 0` (18 of every 20 levels).
  3. **Is `"classes are each other's control"` sound, or can drift or volatility differ by class?**
     - On a continuous-state random walk (even with drift or time-varying volatility), `R100`, `R50`, and `OTHER` are translation-invariant modulo 100 pips, so under the null `E[t_R100] = E[t_R50] = E[t_OTHER]`. (A constant drift lowers `t` equally across all levels crossed in the drift's direction.)
     - **Two finite-sample caveats to note:**
       1. Because `R100` levels are 100 pips apart, a segment with a narrow 30-50 pip range visits at most 1 `R100` level (or none); if a pair's multi-day range happens to have its turnaround extremum near an `R100` level on a pure random walk, all touches of that extremum are `TURN`s. The day-block bootstrap and the two-regime + out-of-sample confirmation (`s7`) guard against this.
       2. In `research/cluster/PREREG.md:73-74`, pooling across pairs by summing raw counts (`t_class = sum(TURN) / sum(TURN + THROUGH)`) weights pairs by their arrival counts: if a range-bound pair (higher `t` in all classes) sits near an `R100` figure while a strongly trending pair (lower `t` in all classes) sits between figures (generating `OTHER` and `R50` arrivals but few `R100` arrivals), `t_R100 - t_OTHER` pooled can be nonzero by Simpson's paradox even when `t_R100 == t_OTHER` within every pair. Reporting the per-pair `d100` alongside the pooled `d100` (`research/cluster/PREREG.md:73, 79`) makes any pair-composition skew visible.
- **Smallest fix to `research/cluster/PREREG.md`:**
  In `research/cluster/PREREG.md:67-72`, replace lines 67-72 with:
  ```markdown
  - **An arrival at level L (tracked independently per 5-pip level L, resetting at each segment start):** the first tick whose mid reaches L (at or beyond it, eps = 1e-9) from one side, after the mid has been at least s away from L on that side (`mid >= L + s - eps` for above; `mid <= L - s + eps` for below) before L's first arrival in the segment or since L's last arrival (re-armed). The arrival side = the side it was armed from.
  - **The outcome:** on or after the arrival tick, which comes first: the mid back at `L +/- s` on the arrival side (**TURN**, `eps = 1e-9`) or at `L -/+ s` on the far side (**THROUGH**, `eps = 1e-9`; a gap past `L -/+ s` on the arrival tick itself resolves immediately on that tick as THROUGH). The tick that resolves TURN or THROUGH simultaneously re-arms L on that side. An arrival still open at the segment's end is dropped and counted.
  ```

---

### 5. Part B's interval: day-block bootstrap, 2,000 resamples, seed, and quantile rule

- **Verdict:** **GAP**
- **Quotes:**
  - `research/cluster/PREREG.md:74` `- **The effect:** d100 = t_R100 - t_OTHER and d50 = t_R50 - t_OTHER (pooled). Interval: a day-block bootstrap (the`
  - `research/cluster/PREREG.md:75` ``  arrivals grouped by server date; 2,000 resamples of days with replacement, `random.Random(20261026)`; the 51st and``
  - `research/cluster/PREREG.md:76` `  1,950th of the sorted differences). A random walk gives the same t in every class (a class has no meaning to it),`
- **Analysis:**
  1. **Is a day-block bootstrap the right guard for dependence? YES.**
     - Grouping all 6 pairs' resolved arrivals by server date (`day = time_msc_server // 86_400_000`) and resampling server days with replacement preserves both within-day serial correlation (repeated bounces at the same level `L`) and cross-pair contemporaneous correlation on shared USD/EUR/CHF/CAD moves.
     - Note that October has `D = 15` server trading days (1 Oct - 20 Oct) and calm has `D = 40` server trading days (8 weeks x 5 days); at `D = 15`, a percentile bootstrap has slightly narrower effective coverage (`~92-93%` vs nominal `95%`), which matters for Check 6 below.
  2. **Is 2,000 enough, is the quantile rule exact, and is the seed fixed?**
     - `2,000` resamples gives `50` tail draws at `2.5%` (Monte Carlo tail SE `~0.35%`), which is sufficient.
     - In 1-based indexing (`1 ... 2,000`), the `51st` value (`sorted_d[50]` in 0-based Python) leaves `50` values (`2.5%`) below it and the `1,950th` value (`sorted_d[1949]` in 0-based Python) leaves `50` values (`2.5%`) above it, which is exact.
     - **Three reproducibility gaps in `research/cluster/PREREG.md:74-76`:**
       1. Specify that an arrival's server date is the **arrival tick's** server date (`arrival_time_msc // 86_400_000`).
       2. Specify how `random.Random(20261026)` is called across the 4 `(regime, s)` combinations (`calm s=5`, `Oct s=5`, `calm s=10`, `Oct s=10`): e.g., sort the unique server dates `days` ascending, initialize `rng = random.Random(20261026 + idx)` per `(regime, s)`, and for each of the 2,000 resamples draw `sample_days = [days[rng.randrange(len(days))] for _ in range(len(days))]` (or `rng.choices(days, k=len(days))`), computing both `d100` and `d50` from the same resampled day set.
       3. State that if a resample has `0` resolved arrivals in `R100` or `R50` (possible in a small window if `R100` was only touched on a few days), that resample is skipped and counted, indexing `int(0.025 * M)` and `int(0.975 * M) - 1`.
- **Smallest fix to `research/cluster/PREREG.md`:**
  In `research/cluster/PREREG.md:74-76`, replace lines 74-76 with:
  ```markdown
  - **The effect:** d100 = t_R100 - t_OTHER and d50 = t_R50 - t_OTHER (pooled by summing TURN and THROUGH across the six pairs). Interval: a day-block bootstrap (resolved arrivals grouped by the arrival tick's server date `t_msc // 86400000`, `days` sorted ascending; 2,000 resamples via `rng.choices(days, k=len(days))` with `rng = random.Random(20261026)` seeded fresh per `(regime, s)`, computing both d100 and d50 on each resample; the 51st (`sorted_d[50]`) and 1,950th (`sorted_d[1949]`) of the 2,000 sorted differences).
  ```

---

### 6. s5's synthetic checks: do they test the false-finding rate they claim to, and are `"at most 1 of 12"` and `"9 of 10"` a fair bar?

- **Verdict:** **DEFECT**
- **Quotes:**
  - `research/cluster/PREREG.md:48` `  k = 1 ... 14. A driftless random walk's profile is flat (equal expected arrivals at every depth per excursion);`
  - `research/cluster/PREREG.md:78` `- **A ROUND EFFECT (class R100 or R50):** its d above 0 with the bootstrap interval above 0, pooled, in BOTH`
  - `research/cluster/PREREG.md:79` `  regimes at s = 5. Per pair reported, not deciding. **Reported beside it (Osler's second effect):** after a THROUGH`
  - `research/cluster/PREREG.md:82` `## 5. SELF-CHECKS FIRST (any failure: STOP, record, amend before any real number is read)`
  - `research/cluster/PREREG.md:87` `3. **Synthetic random walks** (seed 20261027; per series the same number of moves and the same overall up / down`
  - `research/cluster/PREREG.md:88` `   count as the real series, i.e. one shuffle each): Part A gives a CLUSTER on at most 1 of the 12 pair-scales.`
  - `research/cluster/PREREG.md:89` `   Part B, 10 runs per regime: a Gaussian walk of the mid per pair (the real series' tick count, first mid and`
  - `research/cluster/PREREG.md:90` `   standard deviation of tick-to-tick mid changes), the same rules; the d100 and d50 intervals include 0 on at least`
  - `research/cluster/PREREG.md:91` `   9 of the 10 runs. More false findings than that: the rules are too loose; amend before reading real data.`
  - `research/cluster/PREREG.md:92` `4. Identities: per series, the sum over k of arrivals = the moves less the moves into n = 0; per class, TURN +`
  - `research/cluster/PREREG.md:93` `   THROUGH + dropped = arrivals.`
- **Analysis:**
  1. **Part B's synthetic check (`the d100 and d50 intervals include 0 on at least 9 of the 10 runs`, `research/cluster/PREREG.md:89-91`) is miscalibrated and fails ~30% to 60% of the time on a true Gaussian random walk:**
     - Each `[51st, 1,950th]` interval is a **two-sided 95% confidence interval** (`alpha = 0.05` two-sided miss rate per interval under the null, or `alpha ~ 0.065` for a 15-to-40 day percentile bootstrap).
     - Because `OTHER` has 18x as many levels as `R100` and `R50`, `Corr(d100, d50) ~ 1/19 = 0.05`, so `d100` and `d50` miss `0` almost independently.
     - Under **Reading A** (`d100 and d50` both include `0` on `>= 9 of 10` runs in each of the 2 regimes): on 1 run, `P(both include 0) = (1 - alpha)^2 = 0.9025` at `alpha = 0.05` (`0.874` at `alpha = 0.065`). By `Binomial(10, p)`, `P(>= 9 of 10 in one regime) = 74.6%` (`63.6%` at `alpha = 0.065`), so across **both** regimes (`calm` and `October`), the check **fails 44.4% of the time at ideal `alpha = 0.05` and 59.6% of the time at `alpha = 0.065`**!
     - Under **Reading B** (`>= 9 of 10` evaluated separately for each of the 4 series `calm d100`, `calm d50`, `Oct d100`, `Oct d50`): each `Binomial(10, 1 - alpha)` passes with probability `91.39%` at `alpha = 0.05` (`86.5%` at `alpha = 0.065`), so requiring all 4 to pass (`0.9139^4` or `0.865^4`) **fails 30.3% of the time at `alpha = 0.05` and 43.9% of the time at `alpha = 0.065`**!
     - Indeed, when we ran Part B's simulation in Python with the pre-registered seed `random.Random(20261027)`, `calm_40d` produced `d100_ok = 9/10`, `d50_ok = 8/10`, `both_ok = 7/10` -- an immediate **false STOP** under `research/cluster/PREREG.md:82, 90-91`!
     - **Why it also tests the wrong event:** Part B's actual decision rule (`ROUND EFFECT`, `research/cluster/PREREG.md:78`) requires a **one-sided positive** lower bound (`d > 0` and 51st bootstrap value `> 0`, `alpha_one_sided = 0.025`) in **BOTH regimes** (`alpha_both = 0.025^2 = 0.000625` per class, or `~0.125%` across `R100` and `R50` per pair of calm+Oct runs). Testing `ROUND EFFECT` directly across the 10 synthetic `(calm, October)` run-pairs (`0 of 10` or `at most 1 of 10` false `ROUND EFFECT`s) AND checking overall two-sided coverage across all `40` `(regime, class, run)` intervals (`at least 35 of the 40 intervals include 0`, which has `98.6%` pass probability at `alpha = 0.05` and `93.3%` at `alpha = 0.065`) fixes both defects.
  2. **Part A's synthetic check (`at most 1 of the 12 pair-scales`, `research/cluster/PREREG.md:87-88`):**
     - Under within-segment permutation, a synthetic shuffle is exchangeable with the 1,000 null shuffles; its per-pair-scale false-`CLUSTER` rate across both regimes is `~0.04^2 = 0.16%` (`E[false CLUSTERs] ~ 0.02` out of 12, `P(<= 1 of 12) = 99.98%`). While `<= 1 of 12` on a single synthetic draw has low power to detect a moderately loose rule (e.g., a 5% per-pair-scale false rate still passes `<= 1 of 12` 88% of the time), it is a fair sanity check if paired with the within-segment shuffle fix in Check 2.
  3. **s5.4's Part A identity (`the sum over k of arrivals = the moves less the moves into n = 0`, `research/cluster/PREREG.md:92`) fails whenever `|n| >= 15`:**
     - `research/cluster/PREREG.md:48` defines `V_k` and `A_k` for `k = 1 ... 14` (unlike v1, which had a pooled `15 or more` bucket).
     - Every move lands at some `n_new`; if `n_new == 0`, it is a move into `n = 0`, and if `|n_new| = k >= 1`, it is an arrival at depth `k`.
     - In real data (e.g., October EURGBP moves `-144` pips = `28` levels of 5 pips), `|n|` regularly exceeds `14`. If `the sum over k of arrivals` sums `V_k` over `k = 1 ... 14`, it misses all arrivals at `k >= 15` and **fails Self-Check 4 (`STOP`)**! `research/cluster/PREREG.md:92` must state `the sum over all k >= 1 of arrivals = the moves less the moves into n = 0`.
- **Smallest fix to `research/cluster/PREREG.md`:**
  In `research/cluster/PREREG.md:89-93`, replace lines 89-93 with:
  ```markdown
     Part B, 10 runs per regime (`random.Random(20261027)`): a Gaussian walk of the mid per pair (preserving each segment's tick timestamps, first mid, and standard deviation of tick-to-tick mid changes), the same rules; across the 10 (calm, October) run-pairs, at most 1 gives a ROUND EFFECT (both regimes, s = 5), and across the 40 (regime, class in {R100, R50}, run) two-sided 95% intervals at s = 5, at least 35 include 0. More false findings than that: the rules are too loose; amend before reading real data.
  4. Identities: per series, the sum over all k >= 1 of arrivals = the moves less the moves into n = 0; per class, TURN +
     THROUGH + dropped = arrivals.
  ```

---

### 7. s6's predictions: each falsifiable as written?

- **Verdict:** **GAP**
- **Quotes:**
  - `research/cluster/PREREG.md:79` `  regimes at s = 5. Per pair reported, not deciding. **Reported beside it (Osler's second effect):** after a THROUGH`
  - `research/cluster/PREREG.md:80` `  at a round level, the share that reach a further s beyond before returning to L, against OTHER.`
  - `research/cluster/PREREG.md:97` `1. Part A: a CLUSTER on at most 1 of the 12 pair-scales; none at ALT's scale.`
  - `research/cluster/PREREG.md:98` `2. Part B, calm, s = 5: pooled d100 between +1 and +8 points; d50 smaller than d100.`
  - `research/cluster/PREREG.md:99` `3. Part B: a ROUND EFFECT at R100 in both regimes (lean, from Osler); none at R50.`
  - `research/cluster/PREREG.md:100` `4. Osler's second effect (reported): after a THROUGH at R100 the continuation share above OTHER's.`
- **Analysis:**
  - **Prediction 1 (`research/cluster/PREREG.md:97`):** Falsifiable as written (`<= 1` of 12 total, `0` of 6 at ALT).
  - **Prediction 2 (`research/cluster/PREREG.md:98`):** Falsifiable once `points` is specified as **percentage points** (`+0.01 <= d100 <= +0.08`, i.e., `+1.0%` to `+8.0%`, avoiding confusion with price points `0.00001`).
  - **Prediction 3 (`research/cluster/PREREG.md:99`):** Falsifiable as written (`ROUND EFFECT` at `R100`, not at `R50`).
  - **Prediction 4 (`research/cluster/PREREG.md:100`) & Osler's second effect (`research/cluster/PREREG.md:79-80`):** Not falsifiable as written because it omits: (i) whether `a further s beyond before returning to L` means reaching `L -/+ 2s` (vs `through_tick_mid -/+ s` when a gap resolved the THROUGH), and (ii) which scale (`s = 5`), aggregation (`pooled` across the six pairs), and regime (`both regimes`, or `calm` / `October`) Prediction 4 is scored on.
- **Smallest fix to `research/cluster/PREREG.md`:**
  - In `research/cluster/PREREG.md:80`, change `reach a further s beyond before returning to L` to `reach L -/+ 2s on the far side before returning to L (unfinished at segment end dropped)`.
  - In `research/cluster/PREREG.md:98, 100`, replace lines 98 and 100 with:
    ```markdown
    2. Part B, calm, s = 5: pooled d100 between +1.0 and +8.0 percentage points (+0.01 <= d100 <= +0.08); d50 < d100.
    4. Osler's second effect (reported): at s = 5, pooled over the six pairs, the continuation share after a THROUGH at R100 is above OTHER's in both regimes.
    ```

---

### 8. s7's confirmation: is it enough to answer the operator's "tea leaves", anything that would let a result be bent after the fact, and anything the operator's two questions need that is missing

- **Verdict:** **GAP**
- **Quotes:**
  - `research/cluster/PREREG.md:8` `| Why | The operator (25 Oct): "we are searching for a cluster of tight mean reversion"; "there is a drop of in range trading activity after a certain distance. the ideal place for the roll would be at that point"; and (~03:23Z 26 Oct) "if this is random walk, then we are just trying to read tea leaves and any repeated pattern we do see might end as soon as we deploy capital ... there is a lot of back and forth around 'whole' numbers ... maybe we use those as clusters where we add and are more sparse between add layers ... i feel we could test this". |`
  - `research/cluster/PREREG.md:9` `| What follows | **Nothing live.** A result that holds in both regimes AND on the confirmation ticks (s7) becomes a candidate geometry for its own pre-registered simulator, then harness, check. No result: reported as such. |`
  - `research/cluster/PREREG.md:54` `- **DROP at k:** A_k below the band's lower edge, counted only where the shuffle's median V_k is at least 20 (with`
  - `research/cluster/PREREG.md:57` `- **A CLUSTER (pair, scale):** K exists in BOTH regimes; its depth = the smaller K.`
  - `research/cluster/PREREG.md:60` `  fall-off.** Against today's caps (OPT 7; C's three OPT 9; ALT 7): K > cap says more layers; K < cap fewer.`
  - `research/cluster/PREREG.md:78` `- **A ROUND EFFECT (class R100 or R50):** its d above 0 with the bootstrap interval above 0, pooled, in BOTH`
  - `research/cluster/PREREG.md:104` `A finding from s3 or s4 counts as **CONFIRMED** only if it also holds, by the same rule, on **new ticks: E's six`
  - `research/cluster/PREREG.md:105` `pairs from Mon 26 Oct 00:00 to Fri 6 Nov 23:57 server**, dumped on wine-d (IC 53077984, as every h8w and `_oct``
  - `research/cluster/PREREG.md:106` ``file) after 6 Nov's close with `grind_tick_dump`, hashed, and read once. Until then a finding is IN-SAMPLE only and``
  - `research/cluster/PREREG.md:107` `nothing is built on it beyond a simulator pre-registration.`
  - `research/cluster/PREREG.md:127` `lattice starts at the segment's first mid (a sensitivity run at L0 + a / 2 reported, not deciding); arrivals within`
- **Analysis:**
  1. **Is s7's confirmation enough to answer the operator's "tea leaves", and what would let a result be bent after the fact?**
     - Testing on 2 weeks of unseen future ticks (`Mon 26 Oct 00:00 to Fri 6 Nov 23:57 server`, `research/cluster/PREREG.md:104-106`) before building any live preset directly addresses in-sample overfitting on the August-October ticks (and `research/cluster/PREREG.md:9, 106-107` rightly still requires a simulator and harness check afterwards, since mid-price statistics do not price spread, commission, swap, or limit-order execution).
     - **However, `by the same rule` in s7 (`research/cluster/PREREG.md:104`) has four ambiguities that could let a result be bent after the fact or cause a sample-size failure:**
       1. **One carried segment vs two weekly segments (`26 Oct - 6 Nov`):** In s3/s4, a finding requires holding in **two** regimes (`calm`, which is 8 weekly segments ending Friday `23:45`, and `October`, which is 1 carried segment). The confirmation window (`Mon 26 Oct 00:00 to Fri 6 Nov 23:57`) is **one** 2-week period. s7 does not specify whether it is evaluated as **one carried 2-week segment** (`[26 Oct 00:00, 6 Nov 23:57]`) or **two weekly flat-start segments** (`Mon 26 Oct 00:00 - Fri 30 Oct 23:45` and `Mon 2 Nov 00:00 - Fri 6 Nov 23:45`), nor what RNG seeds apply. Choosing between 1 carried segment and 2 weekly segments *after* 6 Nov would let a borderline result be bent.
       2. **Direction match for Part A (`K > cap` vs `K < cap`):** In s3 (`research/cluster/PREREG.md:57, 60`), if in-sample finds a `CLUSTER` with `K = 10` (`> cap 7`, reading "more layers") and the confirmation window finds `K_confirm = 3` (`< cap 7`, reading "fewer layers"), both have "a `K`", but they prescribe opposite changes! Confirmation for Part A must require `K_confirm` to fall on the **same side of `cap`** (`K > cap`, `K < cap`, or `K == cap`) as the in-sample `CLUSTER`.
       3. **10-day sample size vs `THIN` (`median V_k >= 20`, `research/cluster/PREREG.md:54`) and 10-day bootstrap (`research/cluster/PREREG.md:75`):** `26 Oct - 6 Nov` is only **10 trading days** (1/4 of calm's 40 days and 2/3 of October's 15 days). In Part A, requiring `median V_k >= 20` on 10 days will mark nearly all medium/wide scales `THIN`; scaling `THIN` to `median V_k >= 10` on the 10-day confirmation window preserves equivalent per-day activity density (`>= 1` arrival/day).
       4. **Explicit `K == cap` tie rule (`research/cluster/PREREG.md:60`) and non-deciding numbers (`s = 10`, `L0 + a/2`, per-pair `d`):** Add `K == cap says keep cap` to line 60, and state that calm-only or `s = 10` / single-pair / `L0 + a/2` results cannot override a negative primary finding.
  2. **What the operator's two questions need that is missing:**
     - **Question 1 (`"a drop of in range trading activity after a certain distance. the ideal place for the roll would be at that point"`):**
       - As shown in Check 1(a) and Check 2, pinning the anchor to `L0` (`research/cluster/PREREG.md:42-46`) means any range that forms away from the segment's opening price `L0` is mis-binned into deep `k` instead of measuring distance from a stack's anchor; and only t3's two adds (`OPT` and `ALT`) are tested (`research/cluster/PREREG.md:40`).
     - **Question 2 (`"there is a lot of back and forth around 'whole' numbers ... maybe we use those as clusters where we add"`):**
       - Part B (`research/cluster/PREREG.md:67-73`) only measures `t_class = TURN / (TURN + THROUGH)` (the probability that a single `s`-pip arrival reverses by `s` pips). If price chops back and forth 10 times within `< s` pips of `1.1600` (`1.1603 <-> 1.1597`) before moving to `1.1595`, Part B records **0 TURNs and 1 THROUGH**! Nor does `t_class` measure whether round levels attract more frequent visits (`arrivals per level per day`). Reporting **arrivals per visited level per day** (`arrivals_class / (visited_levels_class * days)`) and **1-to-2 pip chop count around `L` while an arrival is open** alongside `t_class` directly tests whether there is "a lot of back and forth around whole numbers" without changing Part B's deciding rule.
- **Smallest fix to `research/cluster/PREREG.md`:**
  - In `research/cluster/PREREG.md:60`, change `K > cap says more layers; K < cap fewer.` to `K > cap says more layers; K < cap fewer; K == cap says keep cap.`
  - In `research/cluster/PREREG.md:79-80`, add: `Also reported (not deciding): arrivals per visited level per day and mean 1-pip crossings of L per arrival while open (back-and-forth intensity).`
  - In `research/cluster/PREREG.md:104-107`, specify the confirmation window's segmentation, seed, `THIN` scaling, and direction match:
    ```markdown
    A finding from s3 or s4 counts as **CONFIRMED** only if it also holds on **new ticks: E's six pairs from Mon 26 Oct 00:00 to Fri 6 Nov 23:45 server**, split into two weekly segments (Mon 26 Oct 00:00 - Fri 30 Oct 23:45 and Mon 2 Nov 00:00 - Fri 6 Nov 23:45 server; seeds `20261106 + i` for A, `20261106` for B), dumped on wine-d (IC 53077984) after 6 Nov's close with `grind_tick_dump`, hashed, and read once: for Part A, K exists on the confirmation series (with THIN at median V_k < 10 for the 2-week window) and lies on the same side of `cap` (`>`, `<`, or `==`) as in-sample; for Part B, the class's pooled d at s = 5 is above 0 with its 2,000-resample day-block bootstrap interval above 0.
    ```

---

**SOUND WITH CHANGES** -- Fix before writing code or reading ticks: (1) in s1/s3/s8 (`research/cluster/PREREG.md:20-21, 47-49, 111-112`), reconcile `V_k = arrivals at depth k = |n|` with the cliff example (`1.1600 <-> 1.1572` has 1 arrival at the turnaround `k = 4`, giving `A_1 ... A_3 = 1, A_4 = 0.5, A_5 = 0`, or else define `V_k` as step traversals `max(|n_prev|, |n_new|) == k`), note that `A_k` is flat only on infinite completed excursions, permute move-blocks **within each segment** while resetting `n = 0` at each segment start, and index the `M` non-skipped shuffles by `sorted_A[int(0.025 * M)]` and `sorted_A[int(0.975 * M)]`; (2) in s3 (`research/cluster/PREREG.md:42-46`), either re-anchor excursions after stack unwind/local extrema or state in s10 that `n = 0` is pinned to the segment's opening `L0`; (3) in s4 (`research/cluster/PREREG.md:67-76`), require initial arming (`>= s` away from `L`) before `L`'s first arrival in a segment, evaluate outcomes `on or after the arrival tick` with `L +/- s` / `L -/+ s` so a single-tick gap (`1.1607 -> 1.1592`) resolves immediately as `THROUGH`, and specify `arrival_time_msc // 86400000` and per-`(regime, s)` seeding for the day-block bootstrap; (4) in s5 (`research/cluster/PREREG.md:89-93`), replace Part B's miscalibrated `>= 9 of 10` per-regime two-sided check (which fails 30%-60% of the time on a Gaussian walk, including `7/10` in calm at `seed 20261027`) with `<= 1 of 10` false two-regime `ROUND EFFECT`s and `>= 35 of 40` two-sided intervals containing `0`, and state `sum over all k >= 1 of arrivals` in s5.4; and (5) in s6/s7 (`research/cluster/PREREG.md:98, 100, 104-107`), specify `percentage points` on Prediction 2, `L -/+ 2s` and `s = 5, pooled, both regimes` on Prediction 4, and the exact segmentation (2 weekly segments), seeds, 2-week `THIN` threshold (`>= 10`), and same-side-of-`cap` requirement for s7's confirmation run.

Line count: 438
