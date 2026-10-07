This message has a line count at the bottom

# THE GRID AS A VARIANCE TRADE -- FEWER DIALS, AND WHAT THE LITERATURE SAYS

| | |
|---|---|
| Status | **NOTES FOR THE OPERATOR** (Claude, 7 Oct ~23:15Z). s1-s4 are algebra (s1 checked by simulation); s5 a first look at three days of FTMO minute data; s6 a literature map; s7 conjectures to test. Nothing here changes a rule. Gemini later, one document at a time (after the IC-vs-FTMO rewrite and `scalps-per-roll.md`) |
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

## SOURCES

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

Line count: 223
