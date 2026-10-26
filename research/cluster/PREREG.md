This message has a line count at the bottom

# ROUND NUMBERS IN FX -- AN OSLER REPLICATION -- PRE-REGISTRATION v3 (26 Oct 2026 ~04:55Z; before any bar is read)

| | |
|---|---|
| Status | **DRAFT v3 for review** (Argon: `prompts/argon_review_cluster_v3.md`; reply on `review/argon-cluster-v3`). v1 (`b058521`) and v2 (`9623022`) reviewed by Argon (`review/argon-cluster`, `review/argon-cluster-v2`); v2's Part A dropped (s1); v2's Part B rebuilt as a replication of Osler (s2). No code, no bar read. |
| Why | The operator (26 Oct ~03:23-04:39Z): "if this is random walk, then we are just trying to read tea leaves and any repeated pattern we do see might end as soon as we deploy capital ... there is a lot of back and forth around 'whole' numbers ... maybe we use those as clusters where we add and are more sparse between add layers"; "it would be interesting to explore ... and use the work of carol osler in determining it ... why dont we start with the definitions/findings from the osler paper?"; "agree to all - proceed". |
| What follows | **Nothing live.** A reversal effect that holds in BOTH halves (s7) becomes the premise of a round-aware lattice (denser adds approaching R100 / R50, wider after a crossing), pre-registered and checked in the simulator, then the harness. A crossing effect bears on where that lattice must widen. No effect: the idea stops, and that is reported. |

## 1. WHAT CHANGED FROM v2, AND WHY

- **Part A (activity per depth from a stack's anchor) is dropped.** Argon's v2 review: its anchor never moves (an
  excursion ends only at the segment's first level), so a trending week is one excursion, unlike the EA's re-anchoring;
  on finite weeks a random walk's profile is not flat; the worked example was wrong (the apex is arrived at once per
  swing). The question it reached for (how deep a stack should go) was answered directly by the cap sweep
  (`research/opt_budget/PREREG_CAP.md`, swcap), where the EA's anchoring is modelled.
- **Part B becomes a replication** with Osler's definitions (s2), on four years of minute data never used here (s3).

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

- **The minute quote:** q_t = the bar's open + spread_points x point / 2 (the mid at the minute's first quote).
- **Levels:** round = multiples of 0.0050 (Osler's rates ending 00 or 50 at four decimals: 1.1600, 1.1650);
  **R100** = multiples of 0.0100, **R50** = the others. **Arbitrary:** per interval (s5), 200 levels drawn uniformly in [the
  interval's lowest q, highest q] (`random.Random(20261026 + 1000 x pair_index + interval_index)`, pairs in s3's
  order), rounded to 0.00001; a draw within 0.0001 x L of a round level redrawn.
- **The band:** |q_t - L| <= 0.0001 x L (Osler's 0.01%; about 1.2 pips on EURUSD at 1.16).
- **A hit at L:** the first minute whose q is inside L's band after the last minute outside it; its **side** = the
  side of that last outside minute (+1 above, -1 below). The level is re-armed only after a minute outside the band.
- **The outcome:** q at the hit minute + 15 (the first bar at or after it, within 5 minutes; else dropped and
  counted): **CROSSING** if beyond L in the direction of the move ((q_15 - L) x side < 0), else **REVERSAL**.
- **Rates:** RVR = reversals / hits at round levels; RVA = the same at the interval's arbitrary levels (all their
  hits pooled); also per class R100, R50.
- **Crossing size (Osler's second effect):** after a CROSSING, the move in the crossing's direction from L at 15
  minutes, as a percentage of L: MVR (round) against MVA (arbitrary); and at 30, 60, 120 minutes.

## 5. INFERENCE

- **Intervals:** consecutive blocks of 10 trading days (a trading day = a server date with at least 600 bars),
  per pair; the last partial block dropped. About 95 a pair.
- **Per interval:** a WIN if RVR > RVA (ties and intervals with fewer than 10 round hits dropped and counted).
- **The test:** one-sided binomial sign test against p = 0.5 on the WINs, per pair and pooled (all pairs' intervals);
  effect = the mean of RVR - RVA over intervals, with a 95% interval from 2,000 resamples of intervals
  (`random.Random(20261027)`; the 51st and 1,950th of the sorted means).
- **The same for crossing size** (WIN if MVR > MVA at 15 minutes) and per class (R100, R50).

## 6. SELF-CHECKS FIRST (any failure: STOP, record, amend before any real number is read)

1. Each file's sha256 and bar count equal s3's; each header says digits=5, server=FTMO-Demo, the expected symbol;
   times strictly increasing.
2. The tests pass (s9).
3. **False-finding rate:** 20 synthetic runs (`random.Random(20261028 + run)`): each pair's minute returns permuted
   within each interval (keeps each interval's drift and volatility, removes any level structure), q rebuilt from the
   interval's first q; s5's pooled sign test on reversals significant at p < 0.01 in at most 1 of the 20. Else the
   rule is too loose: amend before reading the real result.

## 7. THE DECISION

- **ROUND REVERSAL EFFECT** if the pooled sign test gives p < 0.01 with RVR - RVA > 0 **in BOTH halves**: 2023-01-02 to
  2024-12-31 and 2025-01-01 to 2026-10-23 (the second half is the hold-out for the first: the operator's "tea
  leaves"). One half only: IN ONE HALF (reported, not built on). Neither: NONE.
- **ROUND CROSSING EFFECT** by the same rule on MVR > MVA at 15 minutes.
- Per pair, per class and Osler's hours (09:00-16:00 New York local time, server time converted with each file's
  offset and New York's DST) reported, not deciding.
- **Watching, not deciding:** the same measures on the live weeks from 26 Oct (the desktop dump repeated after 6 Nov),
  reported beside the result.

## 8. CLAUDE's PREDICTIONS (before any bar is read)

1. Pooled RVR - RVA between +1 and +5 points in each half.
2. ROUND REVERSAL EFFECT: yes (both halves), larger at R100 than R50.
3. ROUND CROSSING EFFECT: yes in the first half; the second half weaker.
4. Synthetic check: 0 or 1 of 20 significant.

## 9. THE CODE AND THE RUN

`research/cluster/osler.py` with `test_osler.py` first, in their own commit, against a stub; hand values: a hit from
above that is back above at +15 is REVERSAL; one below is CROSSING; the band at 1.1600 is 1.159884 to 1.160116; no
re-hit without a minute outside; an interval with 9 round hits is dropped; the sign test's p for 8 wins of 10. Then
the code; then the operator runs it on the desktop (`python research\cluster\osler.py --data
D:\fxmatrix-exports\bars_ftmo`); outputs and a hash manifest committed; then `results.md`.

## 10. LIMITS

One feed (FTMO's), minute quotes from bars (the open plus half the bar's spread); Osler's band and horizon taken as
published, not tuned; dependence between levels in one interval (intervals are the unit); the arbitrary levels'
range is the interval's; a reversal effect of a few points is a premise for a geometry, not a profit.

Line count: 119
