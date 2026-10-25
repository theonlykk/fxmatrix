This message has a line count at the bottom

# Argon Review: `research/cluster/PREREG.md` (The Cluster Measurement Pre-Registration)

- **Branch:** `review/argon-cluster`
- **Base commit (`origin/main`):** `b058521b36c21c03c84a471e9e1296149bb25019`
- **Files read (at `origin/main`):**
  - `prompts/argon_review_cluster.md` (lines 1-54)
  - `research/cluster/PREREG.md` (lines 1-102)
  - `research/opt_budget/PREREG_CAP.md` (lines 1-42)
  - `research/opt_budget/results.md` (lines 1-75)
  - `research/opt_budget/runs.py` (lines 1-137)
  - `research/opt_budget/depth.py` (lines 1-62)
  - `research/opt_budget/MECHANICS.md` (lines 1-64)
  - `research/replay/sweep.py` (lines 1-463)
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
  - `research/replay/results/sweep_notes.md` (lines 1-945)
  - `ea/grind_engine.mqh` (lines 1-3630)
  - `ea/grind_pure.mqh` (lines 1-691)

---

## Summary Table (Items 1-8)

| Item | Check | Verdict | Core Issue |
|---|---|---|---|
| 1 | Does it answer the question? (Measure vs EA anchor, L0, adds, re-centre, and s6 reading rule) | **DEFECT** | (a) In s2, the excursion anchor never moves from `L0` (the segment's first mid), whereas the EA places L0 at `mid -/+ width`, trails the flat opposite side's L0 via re-centring (`Grind_TryRecenterOppositeL0`), resets to flat when L0 closes (`entry +/- exit`), and shifts effective entries on rolls (`VL`). (b) By conservation of crossings on closed 1-step excursions (`EXTEND_k = RETRACE_{k+1}`), `p_k = C_k / (C_k + C_{k+1})` measures step-to-step activity decay at `k`, not whether a stack of depth `K` scalps: if price ranges freely across `k = 1 ... K` and turns back at `K` (`C_1 ~ ... ~ C_K >> C_{K+1}`), then `p_1 ~ ... ~ p_{K-1} ~ 50%` and `p_K >> 50%`, giving `K* = 0` under s5. (c) In s6, `cap` layers span `k = 0 ... cap - 1` steps of `a` from L0 and roll at `k = cap` (`PREREG_CAP.md:12`), so comparing `K*` directly to `cap` is off by 1 step. |
| 2 | s2, the measure (first level, first passage, gap of `m` levels, `n = 0`, pooling, segment ends) | **DEFECT** | A multi-level gap of `m` steps from `n = -k` (`|n| = k >= 1`) that crosses `n = 0` to `n_new = -k + m > 0` fails under `RETRACE (|n| falls) or EXTEND (|n| rises)`: if `m = 2k`, `|n_new| == |n|` (neither outcome holds); if `m > 2k`, `|n_new| > |n|` (misclassified as `EXTEND` despite moving toward and through `n = 0`), and the excursion-end rule `At n = 0` is skipped. Also lacks floating-point epsilon (`1e-9` as in `grind_pure.mqh:18`) on level passage, explicit `1 pip = 0.0001`, and segment bounds `from_ms <= time_msc_server <= to_ms`. |
| 3 | s4, the nulls (50% RW baseline, shuffle drift/dependence, 200 permutations, seed) | **DEFECT** | (a) On finite drifting segments with excursion-coupled steps, 50% is not the null expectation and Wilson intervals are invalid (`PREREG.md:98-99`). (b) In the shuffle, `gaps kept as their own runs of m` conflicts with line 25 (`counts as ONE decision`): expanding a gap of `m` into `m` unit moves changes the decision count; moreover, when a shuffled path has `N_k == 0`, `p_k = 0 / 0` is undefined, and when `>= 5` of 200 shuffles reach max depth `k` once (`p_k = 1 / 1 = 100%`), the 97.5% quantile is `100%`, making `p_k > shuffle_97.5%` impossible. (c) 200 permutations gives only 5 tail draws at 2.5%/97.5% without a quantile index rule, and `seed 20261025` does not fix the RNG library, method, or per-series vs global seeding scope. |
| 4 | s5, the definitions (noise rate across 24 x 15 cells, both-regimes guard, `N_k >= 30`, break-even `p*`) | **DEFECT** | Across `24 x 15 = 360` cells, the 97.5% shuffle cutoff lets ~9 false `REVERTING` cells through by chance; anchoring `K*` at `k = 1` and requiring `K* >= 2` in both regimes cuts false `CLUSTER`s to `< 1%` across 12 pair-scales, but kills power: in October's single segment (`15` trading days), `N_k >= 30` is unreachable at wide scales (`a = 14..26`), and at `N_k = 30` (`SE = 9.1%`, 97.5% binomial cutoff `20/30 = 66.7%`) a true 60% retrace rate has ~18% power. Break-even `p* = (a + c + s) / (2a)` is right for a market-order mid bet (`c = $0.06 / pip_usd` already covers both legs), whereas the EA's limit-to-limit scalp pays only commission `c` out of the `a`-pip scalp and absorbs spread `s` in fill distance (`a + s`). |
| 5 | s3, the data (segments, hashes, in-sample ticks, one broker, EURUSD October filename) | **CONFIRMED** | All 8 calm segments (`run_swcapw_<pair>.csv`), 1 October segment (`run_swcapo_<pair>.csv`), tick filenames, sha256 prefixes, and t3 scales match the repo records (`sweep_notes.md`, `runs.py`, `inputs/swcap/*.csv`). In-sample selection (`sweep11`) and single-broker (`IC 53077984`) are disclosed in s3 and s10; EURUSD's `ticks_53077984_EURUSD_w2hw.csv` is windowed to the same `[1790827200000, 1792539900000]` segment as `*_oct.csv`. |
| 6 | s7, the self-checks (sufficiency and Check 3's identity) | **DEFECT** | Check 3's identity (`the sum of N_k equals the number of moves less the moves from n = 0 less the dropped end decisions`) is wrong: an open decision at a segment's end is an uncompleted state waiting for a move that never occurred (not counted in `the number of moves`), so subtracting `less the dropped end decisions` fails by 1 per segment ending at `|n| >= 1` (including s9's own 10-level straight-run test: `9 != 10 - 1 - 1`). Check 1 also omits the recorded calm `TICKS_LOADED` counts (`sweep_notes.md:833-834`) and `inputs/swcap.sha256`, and Check 2 omits the synthetic walk's seed number. |
| 7 | s8, the predictions (falsifiability as written) | **DEFECT** | Only Prediction 3 is falsifiable as written. Predictions 1 (`Most p_k`), 2 (`lean above 50%`; `in October they do not`), and 4 (`No clear fall-off inside 7`, which conflicts with s5's exact definition `The fall-off: the first k > K* that is not REVERTING`) lack numeric count thresholds. |
| 8 | Post-hoc bending vectors and missing elements for the operator's question | **GAP** | Post-hoc bending vectors: unfixed calm-only fallback if October has `K* < 2` (as Prediction 2 anticipates), missing `K* == cap` tie case in s6, and unfixed shuffle/gap details. Missing for the operator's question: scales finer/coarser than t3's two adds (to separate physical range `K * a` in pips from layer count `K`), range-trading activity rate (`N_k / day`) per depth, and excursion holding time (stack age) / session time-of-day. |

---

## Detailed Review (Items 1-8)

### 1. Does it answer the question? (Measure vs EA anchor, L0, adds, re-centre, and s6 reading rule)

- **Verdict:** **DEFECT**
- **Quotes:**
  - `research/cluster/PREREG.md:8` ``| Why | The operator (25 Oct): "we are searching for a cluster of tight mean reversion"; "there is a drop of in range trading activity after a certain distance. the ideal place for the roll would be at that point"; "we might end up with more layers but less fx pairs". The OPT cap sweep (`research/opt_budget/PREREG_CAP.md`) found cap 9 better than 7 but not 11 or 13; this asks the price question underneath: **from a stack's anchor, how far does price stay more likely to come back than to go on?** |``
  - `research/cluster/PREREG.md:13` `A stack's anchor at 1.1600. Price falls to 1.1593 (depth k = 1), then 1.1586 (k = 2). From 1.1586 the next 7-pip move is`
  - `research/cluster/PREREG.md:16` `that, say 60%, and beyond K about 50%: a stack's layers down to depth K sit inside it, deeper ones do not. If K = 4 for`
  - `research/cluster/PREREG.md:17` `EURUSD at 7 pips, the layers below 1.1572 (the anchor less 4 x 7) add exposure outside the cluster.`
  - `research/cluster/PREREG.md:22` `- **Lattice:** levels at L0 + j x a, L0 = the segment's first mid; the state n (an integer) = the current level`
  - `research/cluster/PREREG.md:23` `  minus the anchor's, in steps of a; the anchor starts at the first level.`
  - `research/cluster/PREREG.md:26` `- **A decision:** at |n| = k >= 1, the next move is RETRACE (|n| falls) or EXTEND (|n| rises). Long and short`
  - `research/cluster/PREREG.md:27` `  excursions pooled (|n|). At n = 0 the excursion ends and the next move starts a new one (no decision at k = 0).`
  - `research/cluster/PREREG.md:54` `- **K\* (the cluster's depth)** for a series: the largest K with REVERTING at every k = 1 ... K (0 if not at k = 1).`
  - `research/cluster/PREREG.md:64` `or not at each scale; for a CLUSTER its depth against the current caps (OPT 7 on D and E, 9 on C's EURUSD and AUDCAD;`
  - `research/cluster/PREREG.md:67` `**Reading rule (fixed now):** a CLUSTER deeper than the cap says the arm rolls inside it (more layers is the`
  - `research/cluster/PREREG.md:68` `direction); shallower says layers past it sit outside (fewer layers, or the roll at the fall-off). Either is a`
  - `research/opt_budget/PREREG_CAP.md:12` `Cap 7: OPT holds 1.1600 ... 1.1558 and rolls from 1.1551 (the 1.1600 layer's exit moves to 1.1558). Cap 11: it also`
  - `research/opt_budget/results.md:63` `OPT's scalps by place in the stack, calm, BASE / B2: layers 1-4 1,206 (+$1,025) / 1,189 (+$1,010); layers 5-7 518`
  - `research/opt_budget/results.md:64` `(+$417) / 171 (+$143). About $0.8 a scalp at every depth. Time at depth, calm: OPT 1-4 75%, 5-7 17%; ALT at 1 49%, 5-7`
  - `research/opt_budget/MECHANICS.md:10` ``- **Depth** = open layers on the side (`grind_engine.mqh` 2015). Entries allowed while depth < cap (`grind_pure.mqh` 229).``
  - `research/opt_budget/MECHANICS.md:11` ``- **L0** (depth 0, no resting L0): BUY_LIMIT at mid - width, SELL_LIMIT at mid + width (`grind_pure.mqh` 124-137;``
  - `research/opt_budget/MECHANICS.md:12` ``  `grind_engine.mqh` 3214-3222), clamped at least 1 point off the market (ADR-013, `grind_pure.mqh` 198-227), placed only``
  - `research/opt_budget/MECHANICS.md:14` `- **Re-centre:** while one side holds layers and the other is flat, the flat side's resting L0 moves to mid -/+ width`
  - `research/opt_budget/MECHANICS.md:15` ``  when it is more than `stranded` pips from mid and not within `deadband` of the new price (3026-3071).``
  - `research/opt_budget/MECHANICS.md:16` `- **Adds:** target = anchor - add (long) / + add (short); anchor = the deepest layer's entry, or, if any layer is`
  - `research/opt_budget/MECHANICS.md:17` ``  rolled, the most extreme EFFECTIVE entry (2250-2288). One resting add; placed at the ENT fill (`fill_time_place`,``
  - `research/opt_budget/MECHANICS.md:31` ``- Only when depth >= cap (`grind_engine.mqh` 1401-1415). Roll gate: no roll while the OPPOSITE side holds more than``
  - `research/opt_budget/MECHANICS.md:33` `- Level = the add target (above). Crossed when the probe (long: min(ask, the lowest ask since the newest layer`
  - `research/opt_budget/MECHANICS.md:35` `- **A roll does not close the layer:** the candidate (long: the highest-entry layer not yet rolled) gets the level as`
  - `research/opt_budget/MECHANICS.md:36` `  its virtual level (VL); its exit moves to VL + exit (+ carry) (1025-1097). The loss is realised only when that exit`
  - `ea/grind_pure.mqh:128` `   return mid - Grind_PipsToPrice(width_pips, point);`
  - `ea/grind_pure.mqh:136` `   return mid + Grind_PipsToPrice(width_pips, point);`
  - `ea/grind_pure.mqh:154` `   return anchor_entry - (double)direction * Grind_PipsToPrice(add_pips, point);`
  - `ea/grind_engine.mqh:1074` `      Grind_VLSet(pos, level);`
  - `ea/grind_engine.mqh:1306` `      const double level = Grind_Normalize(Grind_ComputeAddTarget(side, is_long, add_pips));`
  - `ea/grind_engine.mqh:2271` `      anchor = side.layers[depth_idx].entry_price;`
  - `ea/grind_engine.mqh:2273` `      anchor = Grind_EffectiveEntry(side.layers[0].entry_price, side.layers[0].position_ticket);`
  - `ea/grind_engine.mqh:2286` `   return Grind_AddTargetPrice(anchor, add_pips, _Point, is_long ? 1 : -1);`
  - `ea/grind_engine.mqh:3045` `   const double dist_pips = Grind_StrandedDistMidPips(resting, current_mid, _Point);`
  - `ea/grind_engine.mqh:3046` `   if(!Grind_ShouldRecenter(dist_pips, stranded_thresh_pips))`
  - `ea/grind_engine.mqh:3050` `                   ? Grind_StraddleBuyPrice(current_mid, width_pips, _Point)`
  - `ea/grind_engine.mqh:3051` `                   : Grind_StraddleSellPrice(current_mid, width_pips, _Point);`
  - `ea/grind_engine.mqh:3214` `   double buy_target = Grind_StraddleBuyPrice(mid, width_pips, _Point);`
  - `ea/grind_engine.mqh:3215` `   double sell_target = Grind_StraddleSellPrice(mid, width_s, _Point);`
  - `ea/grind_engine.mqh:3224` `   if(Grind_SideDepth(g_grind_long) > 0 && Grind_SideDepth(g_grind_short) == 0)`
  - `ea/grind_engine.mqh:3227` `   if(Grind_SideDepth(g_grind_short) > 0 && Grind_SideDepth(g_grind_long) == 0)`
- **Analysis:**
  1. **Where the measure's anchor differs from the EA's:**
     - **L0 placement (`mid -/+ width` vs `L0 = the segment's first mid`):** In `PREREG.md:22-23`, the lattice starts at `L0 = the segment's first mid` and `the anchor starts at the first level`. In the EA (`MECHANICS.md:11-12`, `ea/grind_pure.mqh:128, 136`, `ea/grind_engine.mqh:3214-3222`), a flat side places its L0 limit order at `mid - width` (long) or `mid + width` (short).
     - **Adds at `anchor -/+ add` and exits at `entry +/- exit`:** In the EA (`MECHANICS.md:16-17`, `ea/grind_engine.mqh:2250-2287`), the code variable `anchor` is the **deepest** open layer's entry (`side.layers[depth_idx].entry_price`) or, if any layer is rolled, the most extreme effective entry, placing the next add at `anchor -/+ add_pips`. When price retraces by 1 step `a`, the deepest layer scalps (`entry +/- a`), reducing depth by 1 (`results.md:64`: `About $0.8 a scalp at every depth`). At `depth >= cap`, crossing the add target rolls the shallowest unrolled layer by setting `VL = level` (`MECHANICS.md:31-36`, `ea/grind_engine.mqh:1074, 1306`), moving the stack's effective top along with price.
     - **Re-centre and immovable anchor in s2:** In `PREREG.md:22-23, 27`, `n` is the current level minus the anchor's, the anchor starts at `L0`, and an excursion ends only at `n = 0` (`current level == anchor`). **No rule in s2 ever moves the anchor away from `L0`.** Thus the measure's anchor is permanently pinned to the segment's opening mid `L0` (Monday 00:00 in calm; 1 Oct 04:00 in October). In the EA (`MECHANICS.md:14-15`, `ea/grind_engine.mqh:3026-3071, 3224-3229`), while one side holds layers and the opposite side is flat, the flat side's L0 **re-centres** to `current_mid -/+ width` whenever `dist_pips > stranded` (`width + 1` pips) and outside `deadband` (2 pips); and whenever a stack closes its last (L0) layer at 1 step past L0, that side is flat and places a new L0 at `current_mid -/+ width`.
  2. **Why this difference breaks the measure and the reading rule in s6:**
     - **Pinned segment-start `L0` vs moving stacks:** When price moves away from the segment's opening mid `L0` and ranges around a new level without returning to `L0` (e.g., `sweep_notes.md:749-750` records October EURGBP `-144 (one-way, high +6)` and GBPUSD `+111 (range -132 / +141)` in a single 20-day segment), `|n|` remains at deep levels (`>= 15`) for most of the segment, starving `N_k` at `k = 1 ... K` (failing `N_k >= 30`), even though the EA's re-centred opposite side and rolled stack are actively trading shallow depths `1 ... cap`. Worse, when price drops 4 steps from `n = +8` to `n = +4`, `PREREG.md` records 4 **RETRACES** at `k = 8, 7, 6, 5` (moving toward the stale segment-start `L0`), whereas in the EA the short layers near `+8` already closed on the first step down and the re-centred **long** stack is **EXTENDING** through depths 1-4.
     - **Crossing conservation (`EXTEND_k = RETRACE_{k+1}`) misses a flat-activity cluster that bounces at depth `K`:** On any closed 1-step excursion starting and ending at `n = 0`, every transition `|n|: k -> k + 1` (`EXTEND` at `k`) must be matched by a transition `|n|: k + 1 -> k` (`RETRACE` at `k + 1`). Hence `EXTEND_k = RETRACE_{k+1}` (up to at most 1 at a segment end and multi-level gaps), and `p_k = C_k / (C_k + C_{k+1})` where `C_k = RETRACE_k`. If a pair exhibits the operator's exact phenomenon (`PREREG.md:8`: `"there is a drop of in range trading activity after a certain distance. the ideal place for the roll would be at that point"`), so excursions range across `k = 1 ... K` and turn around at `K` (`C_1 ~ C_2 ~ ... ~ C_K >> C_{K+1}`), then `p_1 ~ ... ~ p_{K-1} ~ 50%` and only `p_K >> 50%`. Because s5 (`PREREG.md:54`) requires `REVERTING at every k = 1 ... K (0 if not at k = 1)`, that series gets **`K* = 0`**! Even a tight 1-step oscillation between `k = 4` and `k = 5` (which scalps profitably every bounce in the EA) scores 100% `EXTEND` at `k = 4` (`p_4 -> 0%`) and 100% `RETRACE` at `k = 5` (`p_5 -> 100%`).
     - **Off-by-one between `k` and `cap` in s6:** In the EA (`PREREG_CAP.md:12`), Layer 1 sits at L0 (`k = 0`), Layers `2 ... cap` sit at `k = 1 ... cap - 1`, and the first roll occurs at `k = cap`. Comparing `K*` directly to `cap` in s6 (`PREREG.md:64-68`) instead of `cap - 1` is off by 1 step.
- **Smallest fix to `research/cluster/PREREG.md`:**
  In **s2 (`research/cluster/PREREG.md:22-28`)** and **s5-s6 (`research/cluster/PREREG.md:54-56, 64-68`)**, replace the fixed-anchor excursion and all-`k` `K*` rule with a first-entry excursion from each local extremum (or trailing anchor) and compare against `cap - 1`:
  ```markdown
  - **Lattice and excursions:** levels at L0 + j x a, L0 = the segment's first mid. Track both a long stack (anchored at the highest level j_high reached since the long excursion began; depth k = j_high - j >= 0) and a short stack (anchored at the lowest level j_low reached since the short excursion began; depth k = j - j_low >= 0), matching the EA's re-centred L0 on each new extremum. When a stack first reaches depth k >= 1 in an excursion (before returning to k = 0), record one first-passage decision at depth k: RETRACE if price returns to k - 1 (scalps that layer) before reaching k + 1, or EXTEND if price reaches k + 1 first; when price returns to k = 0 (or exceeds the anchor, updating j_high or j_low), that excursion ends and a new one begins at the new anchor.
  ```
  And in **s6 (`research/cluster/PREREG.md:67-68`)**, change `against the current caps` / `deeper than the cap` to compare `K*` (which counts add steps `k >= 1` beyond Layer 1) against `cap - 1` (since `cap` layers span `k = 0 ... cap - 1` and roll at `k = cap`).

---

### 2. s2, the measure: every step defined and open cases

- **Verdict:** **DEFECT**
- **Quotes:**
  - `research/cluster/PREREG.md:21` `- **Price:** mid = (bid + ask) / 2 of every tick, in order, within each segment (s3). Pips as the pair's point x 10.`
  - `research/cluster/PREREG.md:22` `- **Lattice:** levels at L0 + j x a, L0 = the segment's first mid; the state n (an integer) = the current level`
  - `research/cluster/PREREG.md:23` `  minus the anchor's, in steps of a; the anchor starts at the first level.`
  - `research/cluster/PREREG.md:24` `- **A move:** a tick whose mid reaches the next level up or down from the current level (first passage). A tick`
  - `research/cluster/PREREG.md:25` `  that crosses m > 1 levels at once (a gap) moves n by m and counts as ONE decision, at the level it left.`
  - `research/cluster/PREREG.md:26` `- **A decision:** at |n| = k >= 1, the next move is RETRACE (|n| falls) or EXTEND (|n| rises). Long and short`
  - `research/cluster/PREREG.md:27` `  excursions pooled (|n|). At n = 0 the excursion ends and the next move starts a new one (no decision at k = 0).`
  - `research/cluster/PREREG.md:28` `- **p_k** = RETRACE / (RETRACE + EXTEND) at depth k, for k = 1 ... 14 and a pooled "15 or more". Reported with N_k.`
  - `research/cluster/PREREG.md:29` `- **Segment ends:** the state is carried across a weekend inside one segment (October); the open decision at a`
  - `research/cluster/PREREG.md:30` `  segment's end is dropped (neither outcome).`
  - `research/opt_budget/runs.py:72` `def window(ticks, a, b):`
  - `research/opt_budget/runs.py:75` `    return ticks[bisect.bisect_left(ts, a):bisect.bisect_right(ts, b)]`
  - `ea/grind_pure.mqh:18` `#define GRIND_PRICE_EPS          1e-9`
  - `ea/grind_pure.mqh:454` `bool Grind_LatticeLevelCrossed(const bool is_long, const double price, const double level)`
  - `ea/grind_pure.mqh:457` `      return (price <= level + GRIND_PRICE_EPS);`
  - `ea/grind_pure.mqh:458` `   return (price >= level - GRIND_PRICE_EPS);`
- **Analysis:**
  1. **A gap of `m` levels that crosses `n = 0` fails under `RETRACE (|n| falls) or EXTEND (|n| rises)`:**
     - Suppose the current level is `n = -k` (`|n| = k >= 1`) and a single tick jumps by `+m` levels across `n = 0` to `n_new = -k + m > 0` (e.g., on a news spike, after the 10-minute hole in `h8w` week 8, or across a weekend opening inside October's single segment):
       - If `m = 2k` (e.g., `n = -1` to `n_new = +1`), then `|n_new| = k == |n|`: **`|n|` neither falls nor rises**, so the decision at `|n| = k` has **no defined outcome**.
       - If `m > 2k` (e.g., `n = -1` to `n_new = +2`), then `|n_new| = m - k > k = |n|`: **`|n|` rises**, so s2 misclassifies a move *toward and through `n = 0`* as **EXTEND** at depth `k`, when it actually retraced the entire `-k` excursion back to `0` and beyond.
       - Moreover, because `n` jumped from `-k` to `+m - k > 0` without landing on `0`, `At n = 0 the excursion ends and the next move starts a new one` never fires at `0`.
  2. **Tick exactly on a level / binary floating-point rounding:**
     - Line 24 uses `"reaches"` for `m = 1` and `"crosses"` for `m > 1`. Both must be inclusive (`>=` / `<=`) with a floating-point tolerance `eps = 1e-9` (matching `ea/grind_pure.mqh:18, 454-458`), because `(bid + ask) / 2` and `L0 + j * a` in IEEE-754 float can differ by `~1e-16` on exact decimal pip touches (e.g. `1.1600 - 3 * 0.0007`).
  3. **Segment windowing and pip unit in standalone Python:**
     - Line 21 says `within each segment (s3). Pips as the pair's point x 10.` It should state explicitly that ticks in a segment are sliced inclusively by `from_ms <= time_msc_server <= to_ms` (matching `research/opt_budget/runs.py:72-75`), that all ticks in `[from_ms, to_ms]` are processed without session-file filtering, and that `1 pip = 0.0001` for all six pairs.
- **Smallest fix to `research/cluster/PREREG.md`:**
  In **s2 (`research/cluster/PREREG.md:21, 24-27`)**, replace lines 21 and 24-27 with:
  ```markdown
  - **Price:** mid = (bid + ask) / 2 of every tick with `from_ms <= time_msc_server <= to_ms` (`runs.py` `window`), in order, within each segment (s3). 1 pip = 0.0001 on all six pairs (`point = 0.00001`, `eps = 1e-9`).
  - **A move:** a tick whose mid reaches at least one level `L0 + j_new x a` (`|mid - (L0 + j x a)| >= a - 1e-9`), advancing `j` to the furthest level reached (`dj = int(math.floor((mid - (L0 + j * a) + 1e-9) / a))` if `mid > L0 + j * a`, else `-int(math.floor(((L0 + j * a) - mid + 1e-9) / a))`). A tick with `|dj| = m > 1` (a gap) moves `n` by `dj` and counts as ONE decision, at the level `|n|` it left.
  - **A decision:** at `|n| = k >= 1`, the next move `dj` is **RETRACE** if `n * dj < 0` (moves toward `n = 0`, even if a gap crosses `n = 0` to the opposite side) or **EXTEND** if `n * dj > 0` (moves away from `n = 0`). Long and short excursions pooled (`|n|`). At `n = 0` (or when a gap crosses `n = 0`, after scoring the RETRACE at the level left) the excursion ends; if the gap landed at `n_new != 0`, the new excursion starts at `n_new`.
  ```

---

### 3. s4, the nulls: 50% random walk, shuffle properties, 200 permutations, and seed

- **Verdict:** **DEFECT**
- **Quotes:**
  - `research/cluster/PREREG.md:45` `1. **50%** (a driftless random walk), with a Wilson 95% interval on p_k.`
  - `research/cluster/PREREG.md:46` `2. **The shuffle** (keeps each segment's drift, removes everything else): the segment's sequence of move directions`
  - `research/cluster/PREREG.md:47` `   (up / down, gaps kept as their own runs of m) permuted 200 times (seed 20261025); p_k recomputed on each; the 2.5%`
  - `research/cluster/PREREG.md:48` `   and 97.5% of the 200 values per k.`
  - `research/cluster/PREREG.md:52` `- **REVERTING at k:** p_k above BOTH 50% and the shuffle's 97.5% value, with N_k >= 30.`
  - `research/cluster/PREREG.md:91` `levels counts one decision; a segment end drops its open decision; the shuffle keeps the up / down count). Then the`
  - `research/cluster/PREREG.md:98` `In-sample ticks (they chose t3's adds); one broker; mid prices (the spread is in p\* only); decisions within one`
  - `research/cluster/PREREG.md:99` `excursion are not independent, so the Wilson interval is too narrow and the shuffle band is the guard; a 1-pip lattice`
- **Analysis:**
  1. **Is a 50% random walk the right baseline at these scales?**
     - On an infinite driftless random walk, `E[p_k] = 50%`. On finite segments with drift (e.g., October EURGBP `-144` pips, GBPUSD `+111` pips, `sweep_notes.md:749-750`) and excursion-coupled decisions (`EXTEND_k = RETRACE_{k+1}`), `E[p_k] != 50%` and the binomial Wilson interval is invalid (`PREREG.md:98-99`). Pairing 50% with the shuffle band in s5 (`above BOTH 50% and the shuffle's 97.5% value`) is therefore necessary.
  2. **Does the shuffle keep drift and remove dependence? Three defects in s4's specification:**
     - **Gap wording conflict (`runs of m` vs `ONE decision`):** Line 47 says `gaps kept as their own runs of m`. If a gap of `m` levels is expanded into a run of `m` unit (`+/-1`) moves, replaying the shuffled sequence produces `m` decisions instead of 1 decision (`PREREG.md:25, 90-91`). Each move in a segment must be represented as a single signed integer step `dj` (`+/-1`, or `+/-m` for a gap) and permuted as one atomic element, which preserves the segment's move count, gap count, and net level drift `sum(dj)`.
     - **Undefined `p_k = 0 / 0` when `N_k == 0` in a shuffle replicate:** At deeper `k` (or at wide ALT scales `a = 15..26` in October's single segment), many shuffled permutations do not reach depth `k` (`N_k == 0`), making `p_k = RETRACE / (RETRACE + EXTEND) = 0 / 0` undefined. s4 does not state how `N_k == 0` replicates are handled when taking the 2.5% and 97.5% quantiles.
     - **Small-`N_k` boundary pinning at `100%` in shuffle replicates:** Whenever a shuffled permutation reaches maximum depth `k` and turns back without reaching `k + 1`, that replicate has `EXTEND_k = 0` and `RETRACE_k >= 1`, so `p_k = 100%`. If at least 5 of the 200 permutations (`2.5%`) top out at depth `k`, the shuffle's 97.5% value at depth `k` is `100%`, making `p_k` **above** the shuffle's 97.5% value (`PREREG.md:52`) impossible even if the real series has `N_k = 100` and `p_k = 85%`.
  3. **Is 200 enough for a 2.5% / 97.5% band, and is the seed fixed?**
     - With 200 permutations, the 2.5% and 97.5% tails rest on only `5` extreme draws (`0.025 x 200 = 5`, Monte Carlo tail SE `~1.1%`), and s4 does not define the quantile indexing/interpolation rule (e.g., 0-based index `4` vs `5` vs linear interpolation). Using `1,000` permutations (`25` tail draws) with an explicit index rule removes that noise.
     - `(seed 20261025)` does not specify the PRNG (`random.Random(20261025)` vs `numpy.random.default_rng(20261025)`), the shuffle call (`rng.shuffle`), or whether the generator is seeded fresh **per series** (vs once globally across all 24 series, which makes every series' band depend on the loop order of pairs/scales/regimes).
- **Smallest fix to `research/cluster/PREREG.md`:**
  In **s4 (`research/cluster/PREREG.md:46-48`)**, replace lines 46-48 with:
  ```markdown
  2. **The shuffle** (keeps each segment's net level drift and gap sizes, removes serial dependence): for each series, initialize `rng = random.Random(20261025)` and for each of 1,000 replicates permute each segment's list of signed move steps `dj` in place (`rng.shuffle`, each gap of `m` levels kept as one signed step `+/-m`), recomputing `p_k` across the series. Over the `M` replicates with `N_k >= 10` at depth `k` (if `M < 100`, the shuffle band at `k` is `n/a` and `k` is neither REVERTING nor TRENDING), sort the `M` values of `p_k` ascending and take `sorted_p[int(0.025 * M)]` (2.5%) and `sorted_p[int(0.975 * M)]` (97.5%).
  ```

---

### 4. s5, the definitions: false positives, "both regimes", `N_k >= 30`, and break-even `p*`

- **Verdict:** **DEFECT**
- **Quotes:**
  - `research/cluster/PREREG.md:52` `- **REVERTING at k:** p_k above BOTH 50% and the shuffle's 97.5% value, with N_k >= 30.`
  - `research/cluster/PREREG.md:53` `- **TRENDING at k:** p_k below both 50% and the shuffle's 2.5% value, with N_k >= 30.`
  - `research/cluster/PREREG.md:54` `- **K\* (the cluster's depth)** for a series: the largest K with REVERTING at every k = 1 ... K (0 if not at k = 1).`
  - `research/cluster/PREREG.md:55` `- **The fall-off:** the first k > K\* that is not REVERTING (reported with its p_k).`
  - `research/cluster/PREREG.md:56` `- **A CLUSTER (pair, scale):** K\* >= 2 in BOTH calm and October. Its depth: the smaller of the two K\*.`
  - `research/cluster/PREREG.md:57` `- **Reference only (not deciding): the break-even** p\* = (a + c + s) / (2a), c = the commission per close in pips at`
  - `research/cluster/PREREG.md:58` ``  0.01 lots ($0.06 / the pair's USD per pip at 0.01 lots, `research/replay/sweep.py` 56-59), s = the series' median spread in pips: a one-step bet``
  - `research/cluster/PREREG.md:59` `  of a pips each way needs p\* to pay its costs.`
  - `research/replay/sweep.py:56` `PAIRS = {"EURUSD": (2.0, 0.100), "GBPUSD": (2.5, 0.100), "EURGBP": (1.0, 0.134),`
  - `research/replay/sweep.py:57` `         "AUDCAD": (1.5, 0.0714), "AUDCHF": (1.5, 0.122), "CADCHF": (1.0, 0.122),`
  - `research/replay/sweep.py:58` `         "NZDCHF": (1.0, 0.120), "NZDCAD": (2.0, 0.0717), "AUDNZD": (2.0, 0.0574)}`
  - `research/replay/sweep.py:59` `COMM_USD = 0.06   # 0.03 a fill at 0.01 lots on ENT and EXT (measured, HANDOFF 2026-09-20)`
  - `research/replay/results/sweep_notes.md:560` `- **Counts:** OPT 60-96 scalps and 3-11 roll closes a week; ALT 3-10 scalps a week and NO roll in any week (A = 0):`
  - `research/replay/results/sweep_notes.md:798` `calm periods - and calm is pretty much where revenue is generated by OPT mostly and ALT is cheap insurance and ALT`
- **Analysis:**
  1. **How many false `REVERTING`s does the shuffle band let through by chance across `24 x 15 = 360` cells, and can `K*` / `CLUSTER` pass on noise?**
     - Across `24 series x 15 depths = 360` cells, a one-sided 97.5% shuffle threshold (`alpha = 0.025`) lets through `360 x 0.025 = 9` false `REVERTING` cells by chance (and `9` false `TRENDING` cells).
     - Anchoring `K*` at `k = 1` (`REVERTING at every k = 1 ... K`) means `P(K* >= 2)` in one series requires passing at both `k = 1` and `k = 2` (`0.025^2 = 0.000625` if independent, and at most `0.025` under positive correlation). Requiring `K* >= 2 in BOTH calm and October` (two independent time windows) bounds the per-(pair, scale) false-`CLUSTER` rate by `<= 0.025^2 = 0.000625` (`~3.9e-7` under step independence), or `<= 12 x 0.000625 = 0.75%` across all 12 `(pair, scale)` combinations. So `CLUSTER` is strongly protected against noise.
  2. **Is `"both regimes"` a fair guard, and is `N_k >= 30` enough?**
     - **False-negative (power) failure of `"both regimes"` + `N_k >= 30`:**
       - First, in October (`1 segment` of ~15 trading days), wide scales (all six ALT scales `15..26` pips, and wide OPT scales `14, 18` pips) do not generate 30 decisions per depth `k = 1, 2` (in `sweep8`, `sweep_notes.md:560`, ALT had only `3-10 scalps a week`). Thus `N_k >= 30` in October automatically disqualifies ALT (and wide OPT) by sample size alone.
       - Second, in the two-arm design (`sweep_notes.md:798`, `PREREG.md:83`), OPT is chosen to harvest mean reversion in **calm** weeks while ALT covers **October** volatility; requiring OPT's tight scale to show `K* >= 2` in October as well as calm contradicts Prediction 2 (`PREREG.md:83`: `At OPT's scales in calm, p_1 to p_3 lean above 50% (OPT earns in calm); in October they do not`).
       - Third, at `N_k = 30`, the standard error around `50%` is `sqrt(0.25 / 30) = 9.13%` and the 97.5% binomial cutoff is `20 / 30 = 66.7%` (requiring `>= 21 / 30 = 70.0%` to pass). A true retrace probability of `60%` (`PREREG.md:16`: `say 60%`) has only `~18%` power at a single depth `k` with `N_k = 30` (and `< 3.5%` power to pass `k = 1` and `k = 2` jointly).
  3. **Is the break-even `p* = (a + c + s) / (2a)` right for a one-step bet with costs on both legs?**
     - In `research/replay/sweep.py:56-59`, `COMM_USD = 0.06` is the round-trip commission at 0.01 lots (`0.03 a fill at 0.01 lots on ENT and EXT`), so `c = 0.06 / pip_usd` already includes commission on **both** legs.
     - For a **market-order** one-step bet on mid of `+/-a` pips that pays half-spread `s / 2` on entry and `s / 2` on exit (`s` total) plus round-trip commission `c`, a win nets `+a - c - s` pips and a loss nets `-a - c - s` pips; zero expected net gives `p* (a - c - s) + (1 - p*) (-a - c - s) = 0`, i.e., `p* = (a + c + s) / (2a)`.
     - **However**, in the EA (`MECHANICS.md:11, 21, 28, 48`), both ENT (`BUY_LIMIT` / `SELL_LIMIT`) and EXT (`SELL_LIMIT` / `BUY_LIMIT`, paired by `OrderCloseBy`) are **limit orders** separated by `a` pips: a completed scalp always realises the full `+a` pips less commission `c` (`p* = (a + c) / (2a)` on limit fills), while the spread `s` instead widens the mid excursion required to touch both limits from `a` to `a + s`.
- **Smallest fix to `research/cluster/PREREG.md`:**
  In **s5 (`research/cluster/PREREG.md:52-59`)**, require `N_k >= 30` in calm and `N_k >= 15` in October (single segment), report `CALM CLUSTER` (`K*_calm >= 2`) alongside `BOTH-REGIME CLUSTER` (`K* >= 2` in both), and note both `(a + c) / (2a)` (limit-order payout break-even) and `(a + c + s) / (2a)` (market-order mid break-even):
  ```markdown
  - **REVERTING at k:** p_k above BOTH 50% and the shuffle's 97.5% value, with N_k >= 30 in calm (8 segments) or N_k >= 15 in October (1 segment).
  - **TRENDING at k:** p_k below both 50% and the shuffle's 2.5% value, with N_k >= 30 in calm or N_k >= 15 in October.
  - **K\* (the cluster's depth)** for a series: the largest K with REVERTING at every k = 1 ... K (0 if not at k = 1).
  - **The fall-off:** the first k > K\* that is not REVERTING (reported with its p_k).
  - **A CLUSTER (pair, scale):** K\* >= 2 in BOTH calm and October (its depth: min(K\*_calm, K\*_oct)); **CALM-ONLY CLUSTER** if K\*_calm >= 2 and K\*_oct < 2 (reported for OPT's calm-revenue role).
  - **Reference only (not deciding): the break-even** p\* = (a + c + s) / (2a) for a market-order mid bet of a pips each way, and p\*_limit = (a + c) / (2a) for the EA's limit-to-limit scalp (where spread s widens the required mid move to a + s rather than reducing the a-pip limit payout), c = the round-trip commission per close in pips at 0.01 lots ($0.06 / the pair's USD per pip at 0.01 lots, `research/replay/sweep.py` 56-59), s = the series' median spread in pips.
  ```

---

### 5. s3, the data: segments, hashes, and suitability of the ticks

- **Verdict:** **CONFIRMED**
- **Quotes:**
  - `research/cluster/PREREG.md:36` ``| calm | `ticks_53077984_<PAIR>__h8w.csv` | the 8 weekly segments of `inputs/swcap/run_swcapw_<pair>.csv` (Mon 3 Aug - Fri 25 Sep, server time) | starts EURUSD `10e95fec`, GBPUSD `d3c8c37a`, EURGBP `1de6ee93`, AUDCAD `a3791e0b`, AUDCHF `69b567b2`, CADCHF `6ff77bfa` |``
  - `research/cluster/PREREG.md:37` ``| October | `ticks_53077984_<PAIR>_oct.csv`; EURUSD `ticks_53077984_EURUSD_w2hw.csv` | the one segment of `run_swcapo_<pair>.csv` (1 Oct 04:00 - 20 Oct 23:45 server) | GBPUSD `7c1c080f`, EURGBP `9139142b`, AUDCAD `f1be6881`, AUDCHF `df6a785d`, CADCHF `09d6aced`, EURUSD `93816e45` |``
  - `research/cluster/PREREG.md:39` `Pairs: E's six (GBPUSD, EURUSD, EURGBP, AUDCAD, AUDCHF, CADCHF). **Scales a:** each pair's t3 OPT add and t3 ALT add`
  - `research/cluster/PREREG.md:40` `(GBPUSD 9 / 15, EURUSD 7 / 23, EURGBP 5 / 23, AUDCAD 18 / 26, AUDCHF 14 / 20, CADCHF 10 / 17). 6 x 2 x 2 = 24 series.`
  - `research/cluster/PREREG.md:41` `One broker's ticks (IC 53077984); the same ticks chose t3's adds (in-sample: disclosed, s8).`
  - `research/opt_budget/runs.py:7` `T3 = {"GBPUSD": (9, 15), "EURUSD": (7, 23), "EURGBP": (5, 23), "AUDCAD": (18, 26), "AUDCHF": (14, 20), "CADCHF": (10, 17)}`
  - `research/replay/inputs/swcap/run_swcapw_eurusd.csv:2` `1,GRIND_EURUSD_OPTD,22260201,1785715200000,1786146300000,2.0,2.0,7.0,7.0,7.0,7.0,9,3.0,2.0,1,1,0,0,1,8,,ticks_53077984_EURUSD__h8w.csv,,sessions_eurusd_ic.csv`
  - `research/replay/inputs/swcap/run_swcapw_eurusd.csv:9` `8,GRIND_EURUSD_OPTD,22260201,1789948800000,1790379900000,2.0,2.0,7.0,7.0,7.0,7.0,9,3.0,2.0,1,1,0,0,1,8,,ticks_53077984_EURUSD__h8w.csv,,sessions_eurusd_ic.csv`
  - `research/replay/inputs/swcap/run_swcapo_eurusd.csv:2` `1,GRIND_EURUSD_OPTD,22260201,1790827200000,1792539900000,2.0,2.0,7.0,7.0,7.0,7.0,9,3.0,2.0,1,1,0,1,1,8,,ticks_53077984_EURUSD_w2hw.csv,,sessions_eurusd_ic.csv`
  - `research/replay/inputs/swcap/run_swcapo_gbpusd.csv:2` `1,GRIND_EURUSD_OPTD,22260201,1790827200000,1792539900000,2.5,2.5,9.0,9.0,9.0,9.0,9,3.5,2.0,1,1,0,1,1,8,,ticks_53077984_GBPUSD_oct.csv,,sessions_eurusd_ic.csv`
  - `research/replay/results/sweep_notes.md:466` `**Data:** the h8w ticks (sweep4: wine-d, 11 Oct; 3 Aug 00:00 to 1 Oct 04:00 server; sha256 starts EURUSD`
  - `research/replay/results/sweep_notes.md:467` `` `10e95fec`, GBPUSD `d3c8c37a`, EURGBP `1de6ee93`, AUDCAD `a3791e0b`, AUDCHF `69b567b2`, CADCHF `6ff77bfa`). ``
  - `research/replay/results/sweep_notes.md:524` `carried window, every setting): one hole in the h8w ticks, \`RPL|GAP|1790210065409|581\` = no tick from Thu 24 Sep`
  - `research/replay/results/sweep_notes.md:584` ``**Data:** `ticks_53077984_EURUSD_w2hw.csv` (plan 4's, `93816e45...6c81`); **one segment per``
  - `research/replay/results/sweep_notes.md:666` `    7c1c080f5b3d71a313f32d2538472a935c0e3b0513e82af574ac35350db59e95  48935532  ticks_53077984_GBPUSD_oct.csv  (1,417,912 ticks)`
  - `research/replay/results/sweep_notes.md:667` `    9139142b3bf03c268f1b165dc58a99e1367737e1a3e3efe73ee83e41f52e2379  29725639  ticks_53077984_EURGBP_oct.csv  (857,097)`
  - `research/replay/results/sweep_notes.md:668` `    f1be6881364bc7228729169748ed79543bddf9cb1cd243a1f410ffcb5c503ae2  51793365  ticks_53077984_AUDCAD_oct.csv  (1,504,955)`
  - `research/replay/results/sweep_notes.md:669` `    df6a785dae72432976ce447605b463820450ab97f28fb3eae698ab5b81baaaad  46667538  ticks_53077984_AUDCHF_oct.csv  (1,359,002)`
  - `research/replay/results/sweep_notes.md:670` `    09d6aced415c024232ea7df69239ff96c01b142e3350e3e8b55cb163588d14b5  39639857  ticks_53077984_CADCHF_oct.csv  (1,154,993)`
- **Analysis:**
  - Every tick filename, segment window (`1785715200000` = Mon 3 Aug 00:00 through `1790379900000` = Fri 25 Sep 23:45 across 8 weekly segments in `research/replay/inputs/swcap/run_swcapw_<pair>.csv`; `1790827200000` = Thu 1 Oct 04:00 through `1792539900000` = Tue 20 Oct 23:45 in `research/replay/inputs/swcap/run_swcapo_<pair>.csv`), sha256 prefix, and t3 add pair (`runs.py:7`) matches the repo records exactly.
  - Nothing is wrong with using these ticks for this pre-registered check provided the three known properties remain disclosed: (1) **in-sample** for t3's adds (`sweep11` chose the t3 adds on these exact segments, disclosed in `PREREG.md:41, 98`; note line 41 cross-references `(in-sample: disclosed, s8)` where `s10` is the limits section); (2) **one broker** (`IC 53077984`, disclosed in `PREREG.md:41, 98`); (3) **EURUSD's October file named `ticks_53077984_EURUSD_w2hw.csv`** because EURUSD reuses plan 4's joined `w2` + holdout dump (`sweep_notes.md:584`) while the other five pairs use `ticks_53077984_<PAIR>_oct.csv` (`sweep_notes.md:666-670`), and all six are windowed to the identical `[1790827200000, 1792539900000]` interval. (Note also the known ~10-minute weekday hole on `Thu 24 Sep 00:34 server` in week 8 of all six `__h8w.csv` files, `sweep_notes.md:524, 778`.)

---

### 6. s7, the self-checks: sufficiency and Check 3's identity

- **Verdict:** **DEFECT**
- **Quotes:**
  - `research/cluster/PREREG.md:27` `  excursions pooled (|n|). At n = 0 the excursion ends and the next move starts a new one (no decision at k = 0).`
  - `research/cluster/PREREG.md:29` `- **Segment ends:** the state is carried across a weekend inside one segment (October); the open decision at a`
  - `research/cluster/PREREG.md:30` `  segment's end is dropped (neither outcome).`
  - `research/cluster/PREREG.md:71` `## 7. SELF-CHECKS FIRST (any failure: STOP, record, amend before any p_k is read)`
  - `research/cluster/PREREG.md:73` ``1. Each tick file's sha256 equals the recorded one (s3); the tick counts equal the replay's `TICKS_LOADED` where``
  - `research/cluster/PREREG.md:74` `   recorded (October: sweep10's counts; EURUSD w2hw 1,021,095).`
  - `research/cluster/PREREG.md:75` `2. The tests (s9) pass; a synthetic random walk (seeded, 1,000,000 steps) gives every p_k within its Wilson interval`
  - `research/cluster/PREREG.md:76` `   of 50% for k = 1 ... 10 (at most one miss).`
  - `research/cluster/PREREG.md:77` `3. Per series the decisions add up: the sum of N_k equals the number of moves less the moves from n = 0 less the`
  - `research/cluster/PREREG.md:78` `   dropped end decisions.`
  - `research/cluster/PREREG.md:90` `zig-zag of one level gives p_1 = 100%; a straight run of 10 levels gives p_1 ... p_9 = 0% with N = 1 each; a gap of 3`
  - `research/replay/results/sweep_notes.md:833` ``sync 0, `TIMING|1|base`, `SESSIONS|...|5`, `TICKS_LOADED` the run's ticks file (h8w counts as sweep8's logs: EURUSD``
  - `research/replay/results/sweep_notes.md:834` `2,888,015, GBPUSD 4,282,592, EURGBP 2,515,345, AUDCAD 4,528,672, AUDCHF 3,785,001, CADCHF 3,167,556; October as`
- **Analysis:**
  1. **Is Check 3's identity right? NO -- it is off by `the dropped end decisions`:**
     - By `PREREG.md:24-30`, a **move** is a completed level passage from `n_prev` to `n_new`. Every move that occurs in a segment either leaves `n_prev = 0` (`moves from n = 0`, which produce no decision) or leaves `|n_prev| = k >= 1` (which resolves and increments `N_k` by 1).
     - The "open decision at a segment's end" (`PREREG.md:29-30`) is the unresolved state `|n_end| >= 1` after the segment's **last** move -- waiting for a next move that **never happens** before `to_ms`, and is therefore **never part of `the number of moves`**.
     - Take `PREREG.md:90`'s own stub test: `a straight run of 10 levels gives p_1 ... p_9 = 0% with N = 1 each`. That segment has `10` moves (`0->1, 1->2, ..., 9->10`), `1` move from `n = 0` (`0->1`), `1` dropped open decision at `n = 10` when the segment ends, and `sum(N_k) = 9`. Check 3's formula gives `10 - 1 - 1 = 8 != 9`. Thus Check 3 will fail on every series where any segment ends at `|n| >= 1`, forcing an immediate `STOP` under s7's header.
     - The true move-conservation identity is: `sum(N_k) == total_moves - moves_from_n0`.
  2. **Are the self-checks sufficient?**
     - **Check 1 gap:** Check 1 cites October's `TICKS_LOADED` counts (`sweep10` and `EURUSD w2hw 1,021,095`) but omits the six calm (`__h8w.csv`) `TICKS_LOADED` counts, which *are* recorded in `sweep_notes.md:833-834` (`EURUSD 2,888,015, GBPUSD 4,282,592, EURGBP 2,515,345, AUDCAD 4,528,672, AUDCHF 3,785,001, CADCHF 3,167,556`), and does not verify the 12 `research/replay/inputs/swcap/run_swcap*.csv` files against `research/replay/inputs/swcap.sha256`.
     - **Check 2 gap:** Check 2 says `(seeded, 1,000,000 steps)` without fixing the seed value (`20261025`).
- **Smallest fix to `research/cluster/PREREG.md`:**
  In **s7 (`research/cluster/PREREG.md:73-78`)**, replace lines 73-78 with:
  ```markdown
  1. Each tick file's sha256 starts with the recorded prefix (s3) and its tick count equals the replay's `TICKS_LOADED` (calm `sweep_notes.md` s11: EURUSD 2,888,015, GBPUSD 4,282,592, EURGBP 2,515,345, AUDCAD 4,528,672, AUDCHF 3,785,001, CADCHF 3,167,556; October `sweep_notes.md` s9-s10: EURUSD 1,021,095, GBPUSD 1,417,912, EURGBP 857,097, AUDCAD 1,504,955, AUDCHF 1,359,002, CADCHF 1,154,993); the 12 `research/replay/inputs/swcap/run_swcap*.csv` files match `research/replay/inputs/swcap.sha256`.
  2. The tests (s9) pass; a synthetic driftless random walk (`random.Random(20261025)`, 1,000,000 unit steps) gives every p_k within its Wilson interval of 50% for k = 1 ... 10 (at most one miss).
  3. Per series the decisions add up: the sum of N_k equals the number of moves less the moves from n = 0.
  ```

---

### 7. s8, the predictions: falsifiability as written

- **Verdict:** **DEFECT**
- **Quotes:**
  - `research/cluster/PREREG.md:55` `- **The fall-off:** the first k > K\* that is not REVERTING (reported with its p_k).`
  - `research/cluster/PREREG.md:82` `1. Most p_k sit inside the shuffle band: price at these scales is close to a random walk.`
  - `research/cluster/PREREG.md:83` `2. At OPT's scales in calm, p_1 to p_3 lean above 50% (OPT earns in calm); in October they do not.`
  - `research/cluster/PREREG.md:84` `3. **A CLUSTER (both regimes) on at most one pair at OPT's scale and on none at ALT's.**`
  - `research/cluster/PREREG.md:85` ``4. No clear fall-off inside 7 at OPT's scale (as `depth.py`: layers 5-7 scalp as well as 1-4).``
- **Analysis:**
  - **Prediction 3** is exact and falsifiable (`<= 1` of 6 pairs has a both-regime `CLUSTER` at OPT's scale, and `0` of 6 at ALT's scale).
  - **Prediction 1 (`Most p_k sit inside the shuffle band`)** is not falsifiable without a fraction threshold: a 95% shuffle band (`[2.5%, 97.5%]`) contains ~95% of cells under the null by construction, and `"Most"` (> 50% vs >= 90%) is undefined.
  - **Prediction 2 (`At OPT's scales in calm, p_1 to p_3 lean above 50% ...; in October they do not`)** is not falsifiable: `"lean above 50%"` and `"they do not"` have no count threshold across the `6 pairs x 3 depths = 18` cells in each regime.
  - **Prediction 4 (`No clear fall-off inside 7 at OPT's scale`)** is not falsifiable and contradicts s5's formal definition (`PREREG.md:55`: `**The fall-off:** the first k > K\* that is not REVERTING`). Under s5, whenever `K* < 7` (which Predictions 1 and 3 themselves predict on at least 5 of 6 pairs), `The fall-off` is `K* + 1 <= 7` (e.g., `fall-off = 1` when `K* = 0`). Adding the undefined word `"clear"` allows any outcome to be rationalized post hoc.
- **Smallest fix to `research/cluster/PREREG.md`:**
  In **s8 (`research/cluster/PREREG.md:82-85`)**, replace lines 82, 83, and 85 with exact counts:
  ```markdown
  1. At least 90% of defined p_k cells (with N_k >= 30 in calm or >= 15 in October) sit inside the [2.5%, 97.5%] shuffle band.
  2. At OPT's scales, p_k > 50% in at least 12 of the 18 (pair, k in 1..3) cells in calm, and in 9 or fewer of the 18 cells in October.
  3. **A CLUSTER (both regimes) on at most one pair at OPT's scale and on none at ALT's.**
  4. On any OPT series with K\* >= 2 in calm, the mean of p_5..p_7 is within 5 percentage points of the mean of p_1..p_4 (no drop-off inside k = 1..7).
  ```

---

### 8. Anything that would let the result be bent after the fact, and anything missing for the operator's question

- **Verdict:** **GAP**
- **Quotes:**
  - `research/cluster/PREREG.md:8` ``| Why | The operator (25 Oct): "we are searching for a cluster of tight mean reversion"; "there is a drop of in range trading activity after a certain distance. the ideal place for the roll would be at that point"; "we might end up with more layers but less fx pairs". The OPT cap sweep (`research/opt_budget/PREREG_CAP.md`) found cap 9 better than 7 but not 11 or 13; this asks the price question underneath: **from a stack's anchor, how far does price stay more likely to come back than to go on?** |``
  - `research/cluster/PREREG.md:9` ``| What follows | **Nothing live.** A pair with a cluster in both regimes becomes a candidate (a cap or a pair choice) for its own pre-registered simulator, then harness, check (as swcap). No cluster: the idea is not supported at these scales, and that is reported. |``
  - `research/cluster/PREREG.md:39` `Pairs: E's six (GBPUSD, EURUSD, EURGBP, AUDCAD, AUDCHF, CADCHF). **Scales a:** each pair's t3 OPT add and t3 ALT add`
  - `research/cluster/PREREG.md:40` `(GBPUSD 9 / 15, EURUSD 7 / 23, EURGBP 5 / 23, AUDCAD 18 / 26, AUDCHF 14 / 20, CADCHF 10 / 17). 6 x 2 x 2 = 24 series.`
  - `research/cluster/PREREG.md:67` `**Reading rule (fixed now):** a CLUSTER deeper than the cap says the arm rolls inside it (more layers is the`
  - `research/cluster/PREREG.md:68` `direction); shallower says layers past it sit outside (fewer layers, or the roll at the fall-off). Either is a`
  - `research/cluster/PREREG.md:99` `excursion are not independent, so the Wilson interval is too narrow and the shuffle band is the guard; a 1-pip lattice`
  - `research/cluster/PREREG.md:100` `offset (L0) could move a level: a sensitivity run at L0 + a/2 is reported beside the main one, not deciding.`
  - `research/replay/results/sweep_notes.md:877` `- **The operator's three rulings, all made AFTER nets were read (disclosed; post hoc):** (1) AUDCHF (~22:35Z): "we`
  - `research/replay/results/sweep_notes.md:944` `**Reading:** cap 9 earns more in both regimes on the harness, but FTMO's daily-loss breaches rise (the carried`
  - `research/replay/results/sweep_notes.md:945` `inventory, t3_drawdown); it is a candidate for the next trial or a fleet reload, not a fix for C164.`
- **Analysis:**
  1. **What would let the result be bent after the fact:**
     - **Post-hoc pivot from "both regimes" to "calm only" for OPT:** `PREREG.md:9, 56` requires `K* >= 2 in BOTH calm and October`, while Prediction 2 (`PREREG.md:83`) expects October *not* to revert at OPT's scales. If calm shows `K* >= 2` and October shows `K* = 0`, s6 must pre-commit now whether calm-only `K* >= 2` is a candidate for OPT (whose role in `sweep11` is calm revenue, `sweep_notes.md:798`) or is strictly `NO CLUSTER`, avoiding post-hoc rule changes after the table is read (as occurred in `sweep11`, `sweep_notes.md:877-882`).
     - **Missing tie case (`CLUSTER depth == cap`) in s6 (`PREREG.md:67-68`):** s6 defines `deeper than the cap` and `shallower`, leaving `K* == cap` (or `cap - 1`) unstated.
     - **Secondary numbers (`L0 + a/2` sensitivity run, Wilson intervals, `p*`):** Reporting Wilson intervals (already known to be too narrow, `PREREG.md:99`) and `L0 + a/2` beside the main table allows post-hoc rescue if the primary run finds no cluster.
  2. **What the operator's question needs that is missing:**
     - **Scales finer or coarser than t3's two adds (`PREREG.md:39-40`):** On AUDCAD (`18 / 26`), AUDCHF (`14 / 20`), and CADCHF (`10 / 17`), no tight scale (`5-9` pips) is measured at all, and on EURUSD/GBPUSD/EURGBP no intermediate scale between OPT (`5-9`) and ALT (`15-23`) is measured. If a pair has a mean-reverting range of physical width `D` pips, testing only two adds `a` cannot distinguish whether `D` is best spanned by more layers at a finer `a` (`"we might end up with more layers"`, `PREREG.md:8`) or fewer layers at a coarser `a`.
     - **Range-trading activity rate (`N_k / day`) and excursion age / time-of-day:** The operator asked where `"there is a drop of in range trading activity after a certain distance"` (`PREREG.md:8`). Reporting `N_k / day` (moves per trading day at depth `k`) and median excursion age (time from excursion start `k = 1` to return to `k = 0`) directly measures where range-trading activity drops off and whether excursions resolve intraday (scalping) or hang across days (driving October swap and FTMO daily-loss breaches, `sweep_notes.md:944-945`).
- **Smallest fix to `research/cluster/PREREG.md`:**
  - In **s6 (`research/cluster/PREREG.md:63, 67-69`)**, add `N_k / day` and median excursion duration to the reported table, and add the tie and regime-split rules:
    ```markdown
    **Reading rule (fixed now):** a CLUSTER with depth > cap - 1 says the arm rolls inside it (more layers); depth < cap - 1 says layers past it sit outside (fewer layers, or roll at the fall-off); depth == cap - 1 says the current cap sits at the cluster boundary (keep cap). A CALM-ONLY CLUSTER (K\*_calm >= 2, K\*_oct < 2) is reported as no two-regime cluster and does not trigger a cap candidate unless pre-registered separately.
    ```
  - In **s10 (`research/cluster/PREREG.md:98-100`)**, add:
    ```markdown
    Only t3's two adds per pair are tested here (not a cross-scale grid of finer/coarser adds, time-of-day sessions, or stack holding-time limits).
    ```

---

**SOUND WITH CHANGES** -- Fix before writing code or reading ticks: (1) in s2/s6, anchor excursions at each new extremum (or reset the anchor when a stack unwinds/re-centres) and record one first-passage decision per excursion upon first entry to depth `k` (avoiding both the immovable segment-start `L0` and the `EXTEND_k = RETRACE_{k+1}` identity that forces `p_1 ... p_{K-1} ~ 50%` and `K* = 0` on a flat-activity cluster bouncing at depth `K`), and compare `K*` to `cap - 1`; (2) in s2, define `RETRACE` by `n * dj < 0` and `EXTEND` by `n * dj > 0` so a gap crossing `n = 0` with `m >= 2|n|` is scored as a `RETRACE` at the level left before starting the new excursion at `n_new`, with `1 pip = 0.0001`, `eps = 1e-9`, and `from_ms <= time_msc_server <= to_ms`; (3) in s4, permute signed move tokens `dj` (keeping each `m`-level gap as one move) 1,000 times with `random.Random(20261025)` seeded per series, computing `2.5%` / `97.5%` (`sorted_p[int(0.025 * M)]`, `sorted_p[int(0.975 * M)]`) over replicates with `N_k >= 10`; (4) in s5, set `N_k >= 15` for October's single segment, define `CALM-ONLY CLUSTER` alongside both-regime `CLUSTER`, and note `p*_limit = (a + c) / (2a)` alongside `p* = (a + c + s) / (2a)`; (5) in s7, remove `less the dropped end decisions` from Check 3 so `sum of N_k equals the number of moves less the moves from n = 0`, add the six recorded calm `TICKS_LOADED` counts and `inputs/swcap.sha256` to Check 1, and fix `seed 20261025` in Check 2; (6) in s8, replace `"Most"`, `"lean above 50%"`, and `"No clear fall-off"` with exact cell counts; and (7) in s6/s10, add the `K* == cap - 1` tie rule, report `N_k / day` and excursion duration, and note the missing finer/coarser scale grid and time-of-day/age dimensions.

Line count: 357
