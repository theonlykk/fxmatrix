This message has a line count at the bottom

# ROUND NUMBERS IN FX -- AN OSLER REPLICATION -- PRE-REGISTRATION v3.2 (26 Oct 2026 ~18:30Z; no real number read)

| | |
|---|---|
| Status | **v3.2 (26 Oct ~18:30Z): v3.1's selfcheck FAILED on crossing size (s6.3: 2 of 20 against a bar of 1; reversals 0 of 20; files PASS; `research/cluster/selfcheck_v31/`), so the comparison levels are replaced (s1b). `--stage real` was never run under v3.1: no real-series number exists.** **v3.1: v3 AMENDED by Argon's review** (`reviews/argon_review_cluster_v3.md` on `review/argon-cluster-v3`, `b23763a`: SOUND WITH CHANGES, 96 quotes exact; every change taken: the float tolerance, the pair order, levels inside the range, re-arm and horizon pinned, server hours fixed for DST, **the test on common calendar blocks** (the seven pairs share days and legs), the day-permuted false-finding check on both effects, blocks per half, prediction 3, the rollover excluded). Before any bar is read. v1 (`b058521`) and v2 (`9623022`) reviewed by Argon (`review/argon-cluster`, `review/argon-cluster-v2`); v2's Part A dropped (s1); v2's Part B rebuilt as a replication of Osler (s2). No code, no bar read. |
| Why | The operator (26 Oct ~03:23-04:39Z): "if this is random walk, then we are just trying to read tea leaves and any repeated pattern we do see might end as soon as we deploy capital ... there is a lot of back and forth around 'whole' numbers ... maybe we use those as clusters where we add and are more sparse between add layers"; "it would be interesting to explore ... and use the work of carol osler in determining it ... why dont we start with the definitions/findings from the osler paper?"; "agree to all - proceed". |
| What follows | **Nothing live.** A reversal effect that holds in BOTH halves (s7) becomes the premise of a round-aware lattice (denser adds approaching R100 / R50, wider after a crossing), pre-registered and checked in the simulator, then the harness. A crossing effect bears on where that lattice must widen. No effect: the idea stops, and that is reported. |

## 1. WHAT CHANGED FROM v2, AND WHY

- **Part A (activity per depth from a stack's anchor) is dropped.** Argon's v2 review: its anchor never moves (an
  excursion ends only at the segment's first level), so a trending week is one excursion, unlike the EA's re-anchoring;
  on finite weeks a random walk's profile is not flat; the worked example was wrong (the apex is arrived at once per
  swing). The question it reached for (how deep a stack should go) was answered directly by the cap sweep
  (`research/opt_budget/PREREG_CAP.md`, swcap), where the EA's anchoring is modelled.
- **Part B becomes a replication** with Osler's definitions (s2), on four years of minute data never used here (s3).

## 1b. WHAT CHANGED FROM v3.1, AND WHY (synthetic data only; no real number read)

- **The failure:** s6.3's 20 day-permuted runs gave crossing size p < 0.01 in 2 (bar 1); the mean of D_j was above 0
  in most runs. The same runs with a DUMMY grid (levels ending 25 / 75) gave the same (2 of 20; mean D_j > 0 in 17 / 20
  runs in H1, 18 / 20 in H2): the tilt favours any regular grid, not round numbers.
- **The mechanism (Claude, sandbox, synthetic only):** pure random walks with one volatility show no tilt (8 seeds);
  random walks whose volatility changes from day to day show it (crossing size mean D_j > 0 in 12 of 12 halves). The
  round grid has a handful of levels per pair-block, the uniform comparison about 200 pooled: a mean over a few levels
  weighs each level about equally, a mean over many weighs each CROSSING equally, and when calm days give many small
  crossings and wild days few large ones, the few-level mean reads larger with nothing there. Comparison grids at
  random offsets POOLED TOGETHER kept the tilt; comparison grids measured EACH ON ITS OWN, with the round grid's
  minimums, and then averaged removed it (volatile walks: 3 of 12 halves positive, none significant; day-permuted
  real minutes, 6 runs: crossing size 6 of 12 halves positive, reversals 5 of 12, none significant).
- **So (s4): the comparison is K = 20 randomly offset copies of the round grid,** each measured exactly as the round
  grid, then averaged: the same number of levels, the same spacing, the same minimums. This departs from Osler's
  uniform arbitrary levels; it is a structure-matched version of her comparison.
- Unchanged: the data, the quote, the band, hits, outcomes, the blocks, the sign test, the halves, the decision rule
  (s7), the predictions (s8), s6.3's bar (at most 1 of 20, each effect). The selfcheck is re-run in full.

## 2. OSLER's DEFINITIONS AND FINDINGS (the prior)

- **Order clustering** (Osler, "Currency Orders and Exchange-Rate Dynamics", FRBNY Staff Report 125, 2001; a bank's
  order book, 1 Sep 1999 - 11 Apr 2000, 9,667 orders): about 8.7% of orders at rates ending 00 against about 1% if
  uniform; then 50, other 0s, 5s; 25 and 75 not special. Take-profits cluster AT 00 (9.3% against stop-losses' 4.4%);
  stop-loss buys just above round numbers (14.4% at 01-10 against 7.4% at 90-99), stop-loss sells just below.
- **Price behaviour** (Osler, "Stop-Loss Orders and Price Cascades in Currency Markets", FRBNY Staff Report 150, 2002;
  Reuters minute quotes 9:00-16:00 New York, Jan 1996 - Apr 1998, DEM, JPY, GBP against the dollar): **round = rates
  ending 00 or 50; a hit = within 0.01% of the level; a reversal = the rate is not beyond the level 15 minutes after
  the hit; a crossing = it is beyond, in the direction of the move.** Comparison levels: arbitrary numbers drawn
  uniformly in the period's range. Inference: 58 ten-trading-day intervals, each a Bernoulli trial (p = 0.5). Reversal
  frequency, round against arbitrary: DEM 59.3% / 54.8% (+4.5 points, 46 of 58 intervals), JPY 60.1 / 57.3 (+2.8),
  GBP 58.1 / 56.6 (+1.5, not significant). After crossings, round-number moves larger (DEM 0.061% against 0.054% at 15
  minutes); the crossing effect lasts hours, the reversal effect under 30 minutes.

## 3. DATA (dumped 26 Oct ~04:42-04:44Z; not read before this is committed)

- **Source:** `grind_bar_dump.mq5` (read-only, `scripts/`, unchanged since `91dd953`; sha256 starts `a5370e009b4aa46e`)
  on the desktop's MT5, FTMO-Demo, account 1514878887 (Fleet A's closed trial; history only), Max bars Unlimited.
  M1 bars, bid OHLC, `spread_points`, server time (`server_minus_gmt_s` in each file's header).
- **Span:** 2 Jan 2023 00:05 - 23 Oct 2026 23:54 server; about 1.41 million bars a pair. **Seven pairs:** E's six
  (EURUSD, GBPUSD, EURGBP, AUDCAD, AUDCHF, CADCHF) and C's GBPCHF; all quote 5 digits (pip 0.0001).
- **Files** (`D:\fxmatrix-exports\bars_ftmo\bars_1514878887_<PAIR>.csv`; sha256 first 16, bytes): AUDCAD
  `B8ECCFF28A6BCAD0` 93,922,653; AUDCHF `091FB6B90C308FF4` 93,257,760; CADCHF `A136CD9577EC0448` 93,895,970; EURGBP
  `E9A2BE7535EA8D76` 93,018,928; EURUSD `2BDF7E05817E41A6` 92,973,101; GBPCHF `BFC4346FF988130A` 94,323,103; GBPUSD
  `742D88ADD02017E0` 93,112,293. Bar counts: 1,410,650; 1,410,274; 1,409,386; 1,409,300; 1,407,677; 1,410,930;
  1,407,893 (the dump's log).
- **New to this project:** no study here has used 2023 - Jul 2026; Aug - Oct 2026 overlaps the replay's ticks (another
  broker's feed; never used for round numbers).

## 4. THE MEASURE (Osler's, made exact for minute bars)

- **Pairs, in this order (pair_index 0-6):** EURUSD, GBPUSD, EURGBP, AUDCAD, AUDCHF, CADCHF, GBPCHF.
- **The minute quote:** q_t = the bar's open + spread_points x point / 2 (the mid at the minute's first quote;
  `MqlRates.spread` is the bar's spread in points). Prices compared with a tolerance of 1e-12.
- **Excluded minutes:** the server rollover, 23:55 to 00:10 server (spreads widen): no hit is taken there.
- **Levels:** round = multiples of 0.0050 (Osler's rates ending 00 or 50 at four decimals: 1.1600, 1.1650);
  **R100** = multiples of 0.0100, **R50** = the others. **Only levels inside [the block's lowest q, highest q]** count,
  round and comparison alike (a level beyond the range can only be reversed from). **Comparison grids (v3.2):** per
  pair and block (s5), K = 20 offsets o_k, each a multiple of 0.00001 in (0, 0.0050), drawn uniformly
  (`random.Random(20261026 + 1000 x pair_index + block_index)`, `randrange(10, 5000, 10)` in tenths of a point) and
  redrawn if within 0.0002 x (the block's highest q) of 0 or 0.0050 (no band overlaps a round level); grid k = the
  levels L = o_k + n x 0.0050 inside the range. Each grid is measured exactly as the round grid (hits, outcomes, its
  own pooled rates), never pooled with another grid.
- **The band:** |q_t - L| <= 0.0001 x L + 1e-12 (Osler's 0.01%; about 1.2 pips on EURUSD at 1.16).
- **A hit at L:** the first minute whose q is inside L's band after the last minute outside it; its **side** = the
  side of that last outside minute (+1 above, -1 below). The level re-arms at the first minute outside its band
  (even inside an earlier hit's 15 minutes); a minute inside two levels' bands is a hit for each.
- **The outcome:** q of the first bar with t_hit + 60 x h <= time_unix_server <= t_hit + 60 x (h + 5), h = 15
  minutes, inside the same block (else dropped and counted): **CROSSING** if beyond L in the direction of the move
  ((q_15 - L) x side < 0), else **REVERSAL**.
- **Rates:** RVR = reversals / hits at round levels (the round grid's hits pooled); per comparison grid k, RV_k the
  same; **RVA = the mean of RV_k over the grids with at least 10 hits** (the round grid's minimum, s5); also RVR per
  class R100, R50 (against the same RVA: reported, not deciding, and not structure-matched).
- **Crossing size (Osler's second effect):** after a CROSSING, the move in the crossing's direction from L at 15
  minutes, as a percentage of L: MVR (round, pooled) against **MVA = the mean of MV_k over the comparison grids with
  at least 5 crossings**; and at 30, 60, 120 minutes. Osler's hours (s7) the same way (grids with at least 10 hits
  in those hours).

## 5. INFERENCE (on common calendar blocks: the seven pairs share days and legs)

- **Halves:** H1 = 2023-01-02 to 2024-12-31, H2 = 2025-01-01 to 2026-10-23 (server dates). **Blocks:** inside each
  half, consecutive runs of 10 common trading days (a trading day = a server date on which every pair has at least
  600 bars), the same blocks for every pair; the last partial block of a half dropped. About 47 a half.
- **Per pair and block:** RVR and RVA (s4); counted only with at least 10 round hits in the class tested (all round,
  R100 or R50) and, for crossing size, at least 5 round crossings.
- **Per block:** D_j = the mean over the pairs counted in block j of (RVR - RVA); a block with no pair counted is
  dropped and counted.
- **The test, per half:** WINs = blocks with D_j > 0 (ties dropped); one-sided binomial sign test against p = 0.5
  over the blocks; effect = the mean of D_j with a 95% interval from 2,000 resamples of blocks
  (`random.Random(20261027)`; the 51st and 1,950th of the sorted means).
- **The same for crossing size** (D_j from MVR - MVA at 15 minutes) and per class (R100, R50).
- **Per pair** (reported, not deciding): the same sign test over that pair's blocks.

## 6. SELF-CHECKS FIRST (any failure: STOP, record, amend before any real number is read)

1. Each file's sha256 and bar count equal s3's; each header says digits=5, server=FTMO-Demo, the expected symbol;
   times strictly increasing.
2. The tests pass (s9).
3. **False-finding rate:** 20 synthetic runs (`random.Random(20261028 + run)`): each pair's minute changes q_k -
   q_(k-1) permuted within each trading day (the overnight and weekend jumps kept at the day boundaries), q rebuilt
   from the day's first q; s5's test per half significant at p < 0.01 in at most 1 of the 20 runs, for reversals
   and, separately, for crossing size. Else the rule is too loose: amend before reading the real result.

## 7. THE DECISION

- **ROUND REVERSAL EFFECT** if s5's test gives p < 0.01 AND the mean of D_j > 0 **in BOTH halves** (H2 is the
  hold-out for H1: the operator's "tea leaves"). One half only: IN ONE HALF (reported, not built on). Neither: NONE.
- **ROUND CROSSING EFFECT** by the same rule on MVR > MVA at 15 minutes.
- Per pair, per class and Osler's hours reported, not deciding. **Osler's hours (09:00-16:00 New York) are 16:00 to
  23:00 server all year:** FTMO's server keeps 00:00 at 17:00 New York (GMT+2 in New York's winter, GMT+3 in its
  summer), so no offset conversion is needed (the header's `server_minus_gmt_s` is the dump day's only).
- **Watching, not deciding:** the same measures on the live weeks from 26 Oct (the desktop dump repeated after 6 Nov),
  reported beside the result.

## 8. CLAUDE's PREDICTIONS (before any bar is read)

1. Pooled RVR - RVA between +1 and +5 points in each half.
2. ROUND REVERSAL EFFECT: yes (both halves), larger at R100 than R50.
3. Crossing size: p < 0.01 in H1; in H2 the mean of D_j smaller than in H1 (whether or not H2 passes).
4. Synthetic check: 0 or 1 of 20 significant.

## 9. THE CODE AND THE RUN

`research/cluster/osler.py` with `test_osler.py` first, in their own commit, against a stub; hand values: a hit from
above that is back above at +15 is REVERSAL; one below is CROSSING; the band at 1.1600 is 1.159884 to 1.160116; no
re-hit without a minute outside; a pair-block with 9 round hits is not counted; a level beyond the block's range
is not taken; a hit in 23:55-00:10 server is not taken; the sign test's p for 8 wins of 10. Then
the code; then the operator runs it on the desktop (`python research\cluster\osler.py --data
D:\fxmatrix-exports\bars_ftmo`); outputs and a hash manifest committed; then `results.md`.
**v3.2:** the new tests first (comparison offsets and grids, the per-grid averaging, the selfcheck's version line), then
the code; the selfcheck re-run to `D:\fxmatrix-exports\osler_out_v32` (its file names PREREG v3.2; `--stage real` refuses
any other).

## 10. LIMITS

One feed (FTMO's), minute quotes from bars (the open plus half the bar's spread); Osler's band and horizon taken as
published, not tuned; dependence across pairs and levels in one block (common calendar blocks are the unit);
the comparison grids are offset copies of the round grid (v3.2), not Osler's uniform levels; a reversal effect of a few points is a premise for a geometry, not a profit.

Line count: 159
