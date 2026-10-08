This message has a line count at the bottom

# THE GRID AS A VARIANCE TRADE -- FEWER DIALS, AND WHAT THE LITERATURE SAYS

| | |
|---|---|
| Status | **NOTES FOR THE OPERATOR** (Claude, 7 Oct ~23:15Z). s1-s4 are algebra (s1 checked by simulation); s5 a first look at three days of FTMO minute data; s6 a literature map; s7 conjectures to test. **8 Oct ~01:30Z: s9 the literature read in full (three readers), s10 the operator's two corrections (we follow the market; three scales W, e, D), s11 the edge ratio rho with its cost hurdle and a first look from our own trades, s12 calibration before any replay.** Nothing here changes a rule. Gemini later, one document at a time (after the IC-vs-FTMO rewrite and `scalps-per-roll.md`) |
| Origin | Operator 7 Oct ~22:23Z: "i would like to spend time tonight really obsessing about S/R and k* ... I feel that we are not the first people to look at efficient delta hedging of an option - so there must be volumes of research out there. I want to get a very good intuitive feel of this as if we can condense the 3 dials we have add/exit and layers into lower dimensions, i think we can really make our trading more sophisticated" |
| Builds on | `docs/research/scalps-per-roll.md` (k* = N*a/e - 1; S/R = k* under a random walk; the measures study s8) |

## 1. ONE LINE THAT EXPLAINS THE GRID

Take the cleanest grid: both sides, layers every a pips around an anchor,
exit e = a, no cap, one lot per layer. Its position is q = -(P - P0)/a
lots: long below the anchor, short above, one more lot per a pips. Over
any stretch where price makes n steps of a and ends dP from the anchor,
its total P&L (realised + open) is EXACTLY

    P&L = (a * n)/2 - dP^2/(2a)          (pips x lots)

- **Revenue = half the path travelled at step a** (a * n is the path
  length measured in steps of a: the operator's "sum of the M1 ranges",
  at the grid's own scale).
- **Cost = the square of how far price ended up, over 2a**: the open
  triangle of layers, realised or not.

Checked by simulation (three seeded random walks of 5,000 steps: the
formula equals the simulated P&L to the pip). Derivation: each step adds
q*delta, and (P_k+1 - P0)^2 - (P_k - P0)^2 = 2(P_k - P0)*delta + a^2;
sum it.

**Read it as a bet:** the grid wins when price travels a lot but ends up
near where it started. It loses when the net move is large compared with
the path, i.e. a trend.

## 2. WHY A RANDOM WALK GIVES ZERO -- AND WHY IT USUALLY "WINS"

For a random walk of n steps, E[dP^2] = n * a^2, so E[P&L] = 0: the
k* result of `scalps-per-roll.md` s2 in one line.

But the DISTRIBUTION is lopsided. dP^2 / (n a^2) is chi-squared with one
degree of freedom: its median is 0.455, its mean 1. So on a typical
stretch the grid makes about 0.27 * n * a pips (the median), and a few
trend stretches take it all back. **The grid is short volatility in the
displacement: many small wins, rare large losses, expectation zero.**
That is the "picking up pennies" profile, and it is why weeks of steady
scalping can be erased by one trend: exactly what the cards show (scalps
+$64 a day, rolls -$96 to -$142 on 7 Oct). The literature on grids says
the same: profitable in the short run, ruin in the long run without an
edge (Taranto and Khan 2020, s6).

## 3. THE CAP AND THE ROLL: A CORRIDOR

With a cap of N layers a side, the position cannot exceed N lots, so
beyond D = N * a the cost stops growing as a square and grows LINEARLY:
every further a pips costs one roll (N*a - e, the k* arithmetic). The
displacement cost becomes a "Huber" shape:

    cost(x) = x^2 / (2a)                 for |x| <= D
    cost(x) = D*|x|/a - D^2/(2a)         for |x| >  D

Rolling moves the corridor with the price (the lattice re-anchors one
step per roll), so after a trend the grid scalps around the NEW level
instead of waiting for price to come back. The deadband re-centres a
flat side the same way at no cost.

In option language: the grid is the delta hedge of a LONG-gamma position
without the option. Its "gamma" is 1/a lots per pip inside the corridor
and zero outside it; we earn the hedger's scalping (realised variance at
step a) and pay what the option would have paid us (the displacement).
It is a **corridor variance trade**: long the variance we see at the
small scale, short the variance at the corridor's scale.

## 4. FROM THREE DIALS TO TWO SCALES

The three dials (add a, exit e, cap N) are really:

| quantity | what it is | in dials |
|---|---|---|
| **s = e** | the FINE scale: how far price must turn for us to get paid | exit |
| **D = N * a** | the COARSE scale: how far price can run before we pay linearly | cap x add |
| **D / e = k* + 1** | the ratio of the two scales | k* itself |
| 1/a, N | how many lots per pip, the most lots at risk | sizing |

So k* is not just "scalps per roll": **k* + 1 is the ratio of the coarse
scale to the fine scale**, and the grid is a bet that the market's
variance at the fine scale exceeds its variance at the coarse scale.

Measure the market's variance AT A PRICE SCALE s: cut the path into
zig-zag legs that reverse by s, count them, and form

    V(s) = s^2 x (legs per day)          (pips^2 per day)

For a random walk V(s) is FLAT (the expected time for a reversal of s is
s^2 / sigma^2). A market that reverts falls with s; a trending one rises.
The rough statement of s1-s3 is then

    edge per day  ~  (lots / 2a) x [ V(e) - V(D) ]  - costs

**Choosing a geometry = choosing two points on the pair's V(s) curve**
where it falls between them, then sizing by a (= D / N). The dials stop
being three free knobs and become: where does this pair chop (e), how
far does it run before it turns (D), and how many lots per pip we can
afford. Volatility moves V(s) up and down (activity); only its SLOPE
between e and D is edge.

## 5. A FIRST LOOK: FTMO MINUTE DATA, 5-7 OCT (2.8 DAYS, TOO SHORT FOR D)

Mid of bid and ask; each minute walked open -> low -> high -> close (or
open -> high -> low -> close on a down minute); 20:50-22:20Z excluded;
V(s) in pips^2 per day, legs in brackets. Source: the dump of 7 Oct
(`bidask_1514731800_*.csv`), a sandbox script (not committed).

| pair | s=2 | 3 | 5 | 7 | 10 | 14 | 20 | 28 |
|---|---|---|---|---|---|---|---|---|
| GBPUSD | 1787 (1254) | 1965 (613) | 2057 (231) | 2287 (131) | 2316 (65) | 1815 (26) | 1710 (12) | 2234 (8) |
| EURUSD | 1526 (1073) | 1760 (550) | 1840 (207) | 1795 (103) | 2134 (60) | 1952 (28) | 2845 (20) | 2788 (10) |
| EURGBP | 424 (298) | 372 (116) | 427 (48) | 523 (30) | 427 (12) | 419 (6) | 569 (4) | 1116 (4) |
| AUDCHF | 491 (345) | 547 (171) | 489 (55) | 418 (24) | 569 (16) | 418 (6) | 285 (2) | 279 (1) |
| CADCHF | 423 (297) | 446 (139) | 356 (40) | 297 (17) | 427 (12) | 279 (4) | 142 (1) | - |
| NZDCAD | 827 (581) | 803 (251) | 738 (83) | 784 (45) | 569 (16) | 279 (4) | 569 (4) | 836 (3) |
| AUDNZD | 1257 (884) | 1261 (394) | 1084 (122) | 1098 (63) | 1102 (31) | 1045 (15) | 853 (6) | 558 (2) |

- From 2 to 10 pips the curves are nearly FLAT: at the fine scales these
  three days looked like a random walk (s=1 reads low because a minute
  bar hides reversals inside it: ticks needed there).
- EURUSD rises from 10 to 20-28 pips (the EUR sell-off of 7 Oct): a
  trend at the coarse scale, exactly where B's EURUSD rolls lost.
  AUDNZD and the CHF crosses lean the other way (falling with s).
- At D (24-72 pips) there are only 0-5 legs in three days: **the coarse
  end needs weeks or months of data**, or a time-based variance ratio
  (`vr.py`) instead of leg counts. That is the measures study's job.

## 6. WHAT THE LITERATURE GIVES US

1. **Hedging on price moves (our add levels) is the efficient way to
   hedge.** Fukasawa and Rosenbaum-Tankov show that rebalancing when the
   price or hedge ratio leaves a band (hitting times) beats rebalancing on
   a clock; in the diffusion case the optimal band scales with gamma
   (Rosenbaum and Tankov 2014, citing Fukasawa). Our lattice IS a
   move-based hedge with a constant band a.
2. **With transaction costs, the optimal no-trade band widens with the
   cube root of cost and gamma squared** (Whalley and Wilmott; in
   Zakamouline's form, half-width (3/2 * lambda * S * Gamma^2 / gamma)^(1/3),
   lambda the cost, gamma risk aversion). For us: the fine scale e cannot
   shrink toward the cost per close without the cost eating the edge;
   the cube-root law says how slowly the right e grows with cost.
   Arzel and Lehdili (2026) still use this formula as the prior for deep
   hedging bands.
3. **Market making with an inventory bound** (Gueant, Lehalle and
   Fernandez-Tapia 2013, after Avellaneda-Stoikov): a dealer quoting
   both sides of a Brownian price with a hard inventory limit; optimal
   quotes in closed form, depending on volatility, order arrival and risk
   aversion. Our width / exit are the quote distances and the cap the
   inventory bound. To read in full: how their optimal quote spacing
   between inventory levels scales with sigma (whether it says "widen
   the add when volatility rises").
4. **Mean-reversion round trips in closed form** (Bertram 2010; Leung and
   Li 2015, with costs and a stop-loss): for an Ornstein-Uhlenbeck
   price, the expected profit per unit TIME of trading between two levels
   in closed form from first-passage times. A scalp is one such round
   trip; their optimal band for a given reversion speed and noise is a
   model for our e on a pair whose reversion we can estimate.
5. **Variance ratios** (Lo and MacKinlay 1988): the standard test of
   whether variance at a long horizon equals the sum at short horizons;
   s4's V(e) against V(D) is the same test in PRICE scale, not time.
6. **Grids and gambler's ruin** (Taranto and Khan 2020): grid trading is
   profitable in the short term and ruined in the long term without an
   edge, s2's lopsided distribution.

## 7. CONJECTURES TO TEST (replay first, then live)

- **C-1:** S/R / k* tracks V(e) / V(D) per pair over weeks (above 1 when
  the pair reverts between e and D). If it holds, pipshed's S/R - k* and a
  price-only V(s) curve measure the same edge, one from our fills and one
  from the market.
- **C-2:** a pair's V(s) SHAPE persists from week to week more than its
  level (level = volatility, shape = edge). Only then can it pick
  geometry ahead of time.
- **C-3:** the compass's wins and losses so far line up with the slope of
  V(s) between the probe's e and D.
- **C-4:** the two-scale parameterisation (e, D, with a = D / N) explains
  the geometry results as well as the three dials do; if so, probes move
  ONE scale at a time.

## 8. WHAT IT WOULD CHANGE (proposals, nothing decided)

- **pipshed (C137):** beside S/R and k*, a V(s) curve per pair (s = 2 to
  80 pips, rolling weeks) with the live e and D marked on it.
- **The compass:** probes as moves of e or of D (the fine or the coarse
  scale), not of add or exit separately.
- **Pair selection:** pairs whose V(s) falls from 5-10 to 30-70 pips are
  grid pairs; pairs whose V(s) rises there are not, whatever their k*.
- **The S/R replay (C135)** becomes the check that s1-s4's continuum
  picture matches the EA's discrete rules (width, deadband, gate).

## 9. THE LITERATURE, READ (8 Oct ~00:45-01:00Z)

Three readers, one strand each; each source marked as read. Results that
are a reader's own derivation or check, not the paper's, are marked so.

1. **Geometry alone cannot earn.** Every serious source agrees with s2:
   zero expectation on a driftless random walk, negative after costs. The
   academic grid papers add nothing (Taranto-Khan 2020: no costs, the
   grid theorem unproved, ruin "almost surely"; Chen et al. 2025, arXiv
   2506.11921: in-sample BTC/ETH). Olsen's Alpha Engine / coastline
   trader (Golub, Glattfelder, Olsen 2017, SSRN 2951348; read in full with
   its reference code: thresholds 0.25-1.5%, cascade one unit per
   threshold, scalp = spacing, no cap, no stop, thresholds tilt above 15 /
   30 units) claims a profit on a random walk: impossible, a warning about
   unmarked open inventory.
2. **FX scaling laws** (Glattfelder, Dupuis, Olsen 2011, arXiv 0809.1040,
   read in full by extraction; 13 pairs, tick mid 2002-2007): directional
   changes per year at threshold s ~ s^E, E averaging -2.03 (random walk
   -2). In our terms V(s) ~ s^(2+E): **USD majors E ~ -1.91 (EURUSD
   -1.908, GBPUSD -1.904, USDJPY -1.928): V rises 20-30% from 5 to 70
   pips (trendy at the coarse scale); EUR / GBP / CHF crosses E ~ -2.13 to
   -2.18 (EURGBP -2.178, EURCHF -2.158, GBPCHF -2.131): V falls 25-37%
   (reverting).** Overshoot after a reversal ~ the threshold, which a
   random walk also gives (P(run beyond x) = exp(-x/e); with e = 8, 5% at
   24 pips, 0.01% at 72): our roll risk is the real tail beyond that curve.
   V(s) is a known estimator (duration-based volatility, Andersen, Dobrev,
   Schaumburg 2008): noise inflates it below ~3 spreads on ticks; minute
   bars deflate it at a few pips.
3. **Exit size against cost.** Mean-anchored (OU, Bertram 2010, via
   restatements; reader re-derived): optimal band u* ~ (1.5 c sigma^2 /
   theta)^(1/3), the cube-root law of the Whalley-Wilmott hedging band.
   Unanchored lattice (the reader's derivation from our P&L identity, not
   published): E[P&L] = RV(1 - VR)/(2a) - c n/2, maximised at **a* ~ 2c /
   (1 - VR)**, VR = net move^2 / path variance over the stack's life. At
   c 0.8 our exit of 10 is optimal at VR ~ 0.84 (GBPUSD); at c 1.4 at VR ~
   0.72 (AUDNZD). Leung-Li 2015 (read in full): with a stop the optimal
   entry region moves away from the stop.
4. **Inventory-bounded market making** (Gueant, Lehalle, Fernandez-Tapia
   2013, read in full by extraction): the quote step per unit of inventory
   (our add) is linear in sigma (STEP ~ sigma sqrt(gamma / (2kA))) while the
   cap is loose; the exit (2 x base ~ 2/k) does not depend on sigma or
   depth. **With a tight cap (ours) the reader's own solution of the
   paper's exact equations says the cap sets the spacing, which widens
   toward it (gaps ~ 1 : 1.4 : 2.9 for a cap of 4) and barely moves with
   sigma** (not the paper's claim; a lead for a graded add, cf. B1 27 Sep).
   Avellaneda-Stoikov's skew: when long, quote the offer close, the bid far.
5. **Hedging on price moves is efficient** (Fukasawa 2014; Rosenbaum-
   Tankov 2014, read in full): hitting-time rebalancing gives ~1/3 of the
   tracking variance of clock rebalancing at the same number of trades; a
   constant band is the efficient scheme when the hedge changes by one lot
   per band (our lattice). Efficient for tracking variance, not for P&L.

## 10. WHAT OUR GRID DOES THAT THE MODELS DO NOT (operator 8 Oct ~01:00Z)

1. **We follow the market (the roll).** A roll books the oldest layer's
   loss and re-centres the stack where the price is: the grid needs price
   to oscillate WITHIN D over a stack's life, not to return to a fixed
   level. So the anchored OU result (s9.3, Bertram) does not fit us; the
   lattice-local a* = 2c/(1 - VR) does. Operator: "we think that market
   will cluster in different ranges - and we want to follow the market to
   those cluster ranges ... trade that path dependent volatility". FX
   literature on clustering at levels (not read yet): Osler 2000 / 2003
   (take-profit and stop orders at round numbers: reversals there, then
   acceleration through them). The operator's M1 vs M5 point: sum of ten
   M1 ranges >= sum of two M5 ranges on ANY path; the information is the
   size against a random walk (range ~ sqrt(time)): ratio sqrt(5) = 2.24;
   above = back-and-forth, below = trend. Parked: operator ~01:07Z, "we
   dont go down the path of time series analysis or worse signals".
2. **Inventory drives entry (a momentum leg).** A loaded side buys only at
   its fixed adds a away; an empty side's L0 floats W from the market
   (C103; docs, not checked in source tonight). In a fall the long stack is
   a reversion bet and the empty short side sells a W bounce and scalps if
   the fall resumes: a continuation bet at the small scale. This week: short
   EURUSD scalped 13 / 1, 14 / 0, 12 / 1 (S / R; B, C, D) while the longs
   rolled. The GLFT / Avellaneda-Stoikov skew in direction; for them risk
   control, for us also a profit leg.

So the grid has **three scales: W (counter entry), e (exit) and D = N*a
(stack)**, and its edge is a joint property of the path at W, e and D,
not V(s) alone. Still zero on a random walk (optional stopping).

## 11. ONE NUMBER: THE EDGE RATIO rho

    rho = (S + R) * e / (R * D)        (closes per roll / (D/e))

- **rho = 1 on a random walk at any geometry** (s2); rho > 1: the pair
  turned inside the stack more often than a random walk would.
- **The cost hurdle is e / (e - c)**: S/R > k* (with costs) is exactly
  rho > e/(e - c). GBPUSD / EURUSD (e 10, c 0.8) 1.09; EURGBP (e 5) 1.14;
  AUDNZD (c 1.4) 1.16; D AUDCHF (e 9) 1.08. Geometry drops out of the
  comparison except through the hurdle: one number per pair and side,
  comparable across fleets, probes and days.
- **Count the open book.** Realised-only flatters: open losses are rolls
  in waiting. R_eff = R + max(0, -open pips) / (D - e). Fleet D (started
  flat 1 Oct 05:19Z), 1-8 Oct 00:02Z, gross of commission (D's ~$96 of
  commission reconciles +$177 realised to its +$74 balance):

| D | realised $ | open $ | equity $ | rho realised | rho with open book |
|---|---:|---:|---:|---:|---:|
| GBPUSD | +78.3 | -19.3 | +59.0 | 3.12 | 1.98 |
| NZDCAD | +50.0 | -6.3 | +43.7 | (1 roll) | 7.5 (thin) |
| AUDNZD | +28.9 | -12.6 | +16.3 | 1.95 | 1.33 |
| AUDCHF | +32.0 | -27.1 | +4.9 | 1.06 | 0.81 |
| NZDCHF | +1.4 | -6.0 | -4.6 | 1.15 | 1.02 |
| AUDCAD | +12.8 | -23.2 | -10.4 | 1.26 | 0.77 |
| CADCHF | +5.2 | -16.9 | -11.7 | 1.03 | 0.84 |
| EURGBP | -12.0 | -18.5 | -30.5 | 0.99 | 0.79 |
| EURUSD | -19.7 | -29.0 | -48.6 | 0.84 | 0.74 |

- **Noise:** rho moves roughly with 1/R, so its relative error is ~1/sqrt(R):
  35-45% for a two-day round on a pair with 5-10 rolls. Telling 0.81 from
  1.0 needs ~50+ rolls (weeks live). Per-day figures filtered to days with
  a roll are biased LOW (every pair's daily median sat below its pooled
  value): ranges need multi-day blocks with the open book at each end.
- **The operator's frame (~01:10Z):** like a forward spread that "in theory
  could be 500bps, but over the last 5 yrs had been in a 100bp range" -
  get "down to a single number of truth - even given a set of conditions"
  and trade around it, from our own trade history. Structural use: choose
  each pair's geometry so its hurdle sits below the low end of its rho
  range. Tactical use ("this week is at the edge") is nearer a signal:
  hold until the ranges are established.
- From 8 Oct 00:00Z `state_snapshots` give each instance's open MTM per side
  every minute: rho with the open book becomes exact per pair, side and
  day on all four fleets from tonight (backlog C141).
- **Can a probe lift a pair's rho (operator ~01:19Z, AUDCHF 0.81)?** Only
  by moving the geometry onto scales where the pair does revert; a probe
  finds an edge, it cannot make one. A two-day round cannot resolve it
  (noise above): the replay sweep first (s12), then a probe aimed at its
  peak, one scale at a time (C-4).

## 12. CALIBRATION BEFORE ANY REPLAY (operator 8 Oct ~01:22Z-01:31Z)

We were loath to backtest because a replay does not replicate real life.
Operator: "we dont have much trade data, but we have more than zero ...
pick a fxpair with a lot of trade points we can calibrate against and see
if we can replicate the trade history we observed"; "getting a reliable
replay would be a huge result". The plan (to be written as a
pre-registered document for Gemini, next chat):

- **EURUSD on B, C and D**: one IC price stream, three geometries, three
  observed histories (D 115 scalps / 30 rolls / 618 deals since 1 Oct,
  started flat 05:19Z; C 98 / 35; B 87 / 32 / 827 deals). A replay that
  reproduces all three from one tick stream has the rules, not a fit.
  A trend week and chop.
- **Ticks**, not minute bars (limit fills are touch events): IC EURUSD
  from wine-d, a tick-writing variant of `scripts/grind_bidask_dump.mq5`.
- **Ground truth**: fill_logs, config_events (the geometry timeline),
  ROLL_* events (`study_2026-10-08_0110.jsonl`, 21,999 fill rows, 5,195
  scalps, 1,393 config events, from 22 Sep).
- **Engine, Gemini to rule**: (a) MT5 Strategy Tester running the real EA
  on IC's real ticks (same code; an IC terminal for testing; live-only
  paths never run in the tester) or (b) the Python port (C118), tests first.
- **Pass marks fixed before any run**, e.g. >= 90% of real deals matched
  on side and layer within 0.2 pip and 60 s; daily S and R per side within
  10%; rho per side within 0.1. Every miss categorised (deadband
  re-quotes, carry shifts, the gate, API, latency).
- Only after a pass: geometry sweeps on the same week, then back over IC's
  tick history: the rho ranges (s11), AUDCHF the first case.

## SOURCES

Added 8 Oct (s9): Glattfelder, Dupuis, Olsen (2011) https://arxiv.org/pdf/0809.1040 (read in full by extraction; appendix tables A13-A22 not seen); Golub, Glattfelder, Olsen (2017) Alpha Engine https://www.smallake.kr/wp-content/uploads/2019/02/SSRN-id2951348.pdf and https://raw.githubusercontent.com/AntonVonGolub/Code/master/code.java (read in full); Andersen, Dobrev, Schaumburg (2008) https://gcoe.ier.hit-u.ac.jp/information/schedule/pdf/ADS_DRVDraft_0807.pdf (read in full); Gueant, Lehalle, Fernandez-Tapia (2013) https://arxiv.org/pdf/1105.3115 (read in full by extraction, figures not seen); Avellaneda-Stoikov (2008) https://www.math.nyu.edu/~avellane/HighFrequencyTrading.pdf (read); Gueant (2017) https://arxiv.org/pdf/1605.01862 (s2-4); Fukasawa (2014) https://arxiv.org/pdf/1204.0637 (read in full); Baviera and Santagostino Baldi (2017) https://arxiv.org/pdf/1706.07021 (read in full); Chen, Chen, Jang (2025) https://arxiv.org/html/2506.11921v1 (read in full); Bertram (2010) original NOT accessed (restatements only); Cartea-Jaimungal-Penalva (2015), Osler (2000/2003), Guillaume et al. (1997) NOT read.


- Rosenbaum, M. and Tankov, P. (2014), "Asymptotically optimal
  discretization of hedging strategies with jumps", Annals of Applied
  Probability 24(3): https://arxiv.org/pdf/1108.5940
- Zakamouline, V., "Optimal Hedging of Options with Transaction Costs"
  (c. 2005; the Whalley-Wilmott band, eq. 12):
  https://www.efmaefm.org/0efmameetings/EFMA%20ANNUAL%20MEETINGS/2005-Milan/papers/284-zakamouline_paper.pdf
- Whalley, A.E., partial transaction costs paper (Warwick):
  https://text.www2.warwick.ac.uk/fac/soc/wbs/subjects/finance/faculty1/elizabeth_whalley/whalleypartialtcjan06.pdf
- Arzel, J. and Lehdili, N. (2026), "Bridging Stochastic Control and Deep
  Hedging": https://arxiv.org/abs/2603.29994
- Gueant, O., Lehalle, C.-A. and Fernandez-Tapia, J. (2013), "Dealing
  with the Inventory Risk": https://arxiv.org/abs/1105.3115
- Bertram, W. (2010), OU trading thresholds (as implemented by
  ArbitrageLab):
  https://hudson-and-thames-arbitragelab.readthedocs-hosted.com/en/latest/time_series_approach/ou_optimal_threshold_bertram.html
- Leung, T. and Li, X. (2015), "Optimal Mean Reversion Trading with
  Transaction Costs and Stop-Loss Exit": https://ar5iv.org/html/1411.5062
- Lo, A. and MacKinlay, A.C. (1988), "Stock Market Prices Do Not Follow
  Random Walks": https://web.mit.edu/~alo/www/Papers/lo-mackinlay-88.html
- Taranto, A. and Khan, S. (2020), "Gambler's ruin problem and
  bi-directional grid constrained trading and investment strategies",
  IMFI 17(3):
  https://businessperspectives.org/publishing-policies2/gambler-s-ruin-problem-and-bi-directional-grid-constrained-trading-and-investment-strategies

Line count: 385
