This message has a line count at the bottom

# SCALPS PER ROLL -- THE BREAK-EVEN RATIO k*, AND WHAT PRICE DATA CAN TELL US ABOUT IT

| | |
|---|---|
| Status | **NOTES + PROPOSAL** (Claude, 7 Oct ~20:10Z). s1-s5 are arithmetic and one measurement; s6 is how the compass uses it (no rule changes); s7-s8 propose a price-data replay and a measures study, NOT pre-registered. Goes to Gemini AFTER the IC-vs-FTMO rewrite (one document at a time) |
| Origin | Operator 7 Oct ~19:44Z: "there has to be some geometry no? 8 scalps equals a roll, but the roll has to occur less frequently than a scalp. is there a way of crystallising the mathematical relationship?"; ~19:51Z: "can we use [tick data] to estimate S/R?"; ~19:54Z: break-even scalps per roll for a given add / exit / cap; ~19:58Z: "should our compass probe look to maximise S/R - k*"; ~20:03Z: "is there a correlation between ATR or any other vol measure ... vs S/R or k* ... our actual trade data is still the gold standard, but maybe there is something we can extract from price data"; ~20:05Z: "please document all.. what about something really simple like sum abs(M1 change) to estimate the path travelled?" |
| Rules it keeps | Trade history is the gold standard; a simulator is "first-order, not reconciled" until it reproduces our own fills (`docs/research/grid-thesis.md` s6). The cohort's equity decides the compass (`docs/research/compass-equity-amendment.md` s7) |

## 0. AUDIT TRAIL

| # | Fact | Where | Status |
|---|---|---|---|
| K1 | A roll moves the exit of the side's highest-entry unrolled layer to the virtual add level + exit; the virtual level is one add below the deepest layer; the next roll repeats one add lower | ADR-162 (lattice), ADR-165 (re-roll) | VERIFIED (docs) |
| K2 | On a regular stack (cap N, add a, exit e) every roll's realised loss is N*a - e pips: entries x .. x-(N-1)a, level x-Na, exit x-Na+e; the second roll moves x-a to x-(N+1)a+e, the same distance | arithmetic on K1 | VERIFIED |
| K3 | IC commission about $0.08 per closed 0.01-lot layer (B 7 Oct broker day: 102 closes, -$8.16); limit orders pay no spread | pipshed fleet card 7 Oct ~17:20Z | MEASURED |
| K4 | Fleet B, 5 Oct 22:00Z - 7 Oct 13:36Z, seven ring pairs, ejections excluded: 100 scalps (mean +9.1 pips), 50 roll closes (mean -36.2 pips), gross -$105.34 (s5) | study export `study_2026-10-07_1336.jsonl` (sha256 `79eb2326354861a8`), `scalp_history`, `rolled` flag | MEASURED |
| K5 | The bid / ask dumps are minute OHLC built from ticks; `CopyTicksRange` returns ticks on the IC boxes (C63 probe) | `scripts/grind_bidask_dump.mq5`; `scripts/grind_tick_probe.mq5` | VERIFIED |
| K6 | Existing price measures: variance ratio (`research/markout/vr.py`); zigzag legs at 5/10/20 pips (M5) and cycles per level vs surrogates (M6, `research/grid_thesis/gt_report.py`) | repo | VERIFIED |

## 1. THE IDENTITY

Per pair and side, D = N*a is the stack's depth in pips. A scalp earns e;
a roll costs D - e (K2). Over any window, realised pips are

    realised = e*S - (D - e)*R = e * R * (S/R - k*)

with S scalps and R roll closes, and the break-even ratio

    k* = D/e - 1 = N*a/e - 1          (before costs)
    k* = (N*a - e + c) / (e - c)      (c = cost per close, in pips)

So a side makes money (realised) only while it scalps more than k* times
per roll. "8 scalps pay a roll" is k* = 8a/e - 1. Open MTM is outside the
identity: over a long window it averages out; over a short one it is what
the cohort's equity adds back.

## 2. THE RANDOM-WALK RESULT: S/R LANDS ON k*

Count the side's depth in steps of a (take e = a). A step down fills a layer
(depth +1); at depth N a step down is a roll instead. A step up closes the
layer with the lowest exit: after a roll that is the ROLLED layer (its exit
is the lowest), so each roll's loss is realised on the next step up, before
any scalp. Under a symmetric random walk the depth is a walk reflected at 0
and N, and it spends an equal share of time at each depth 0..N (1/(N+1)
each). Per a-step:

- rolls: down-steps at depth N = 1 / (2(N+1))
- closes: up-steps at depth >= 1 = N / (2(N+1)); of these, roll closes
  equal the rolls, so scalps = (N-1) / (2(N+1))
- S/R = N - 1 = k* (e = a), and the pips net to zero:
  a(N-1)/(2(N+1)) - (N-1)a/(2(N+1)) = 0.

For any e this follows from optional stopping: no rule earns on a
martingale, so once the open MTM averages out, scalps exactly pay rolls.
**In a random walk S/R = k* for every geometry; before costs the grid
earns nothing and after costs it loses them.** Its edge is how much more
often the price reverses inside D than a random walk does.

## 3. WHY A LOW k* IS NOT ENOUGH

k* is the price of a roll; the market sets how often it is paid. A smaller
stack makes rolls cheaper AND more frequent, and in a random walk the two
cancel. Example: random walk, ~50 pips of daily range, cap 8, e = a. A walk
needs on average (sigma/a)^2 steps of a per day; rolls are 1/(2(N+1)) of
them.

| | add 4 (D 32) | add 8 (D 64) |
|---|---:|---:|
| k* = N - 1 | 7 | 7 |
| a-steps a day (50^2 / a^2) | 156 | 39 |
| rolls a day (/18) | 8.7 | 2.2 |
| scalps a day (x7) | 61 | 15 |
| scalp pips (x e) | +243 | +122 |
| roll pips (x (D - e)) | -243 | -122 |
| net before costs | 0 | 0 |
| closes | ~70 | ~17 |
| commission at 0.8 pip a close | -56 pips | -14 pips |

Costs hurt a tight geometry twice: more closes, and a fixed cost is a larger
share of a small exit (0.6-0.8 pip is 12-16% of a 5-pip exit, 6-8% of a
10-pip one). With exits held at 10 a small add lowers k* (AUDCHF 2.2) but
the 32-pip stack fills after a 32-pip move: AUDCHF made 11 scalps for 7
rolls and CADCHF 5 for 7 in K4's window, both short of their k* of 2.4.

**What makes a geometry good is S/R - k*, and that depends on matching D to
how far the pair travels before it reverses.** A pair that turns within 25
pips is well served by a 32-pip stack; the same stack rolls through every
40-60 pip run. A low k* helps only on a pair that genuinely reverses within
that short distance.

## 4. TABLES

At the round-2 anchor (cap 8; cost from K3 at approximate 0.01-lot pip
values: USD-quoted $0.10, GBP $0.132, CHF $0.125, CAD $0.072, NZD $0.058):

| pair | add / exit | D | roll cost D - e | c (pips) | k* before costs | k* with costs |
|---|---|---:|---:|---:|---:|---:|
| GBPUSD | 9 / 10 | 72 | 62 | 0.8 | 6.2 | 6.8 |
| EURUSD | 7 / 10 | 56 | 46 | 0.8 | 4.6 | 5.1 |
| EURGBP | 3 / 5 | 24 | 19 | 0.6 | 3.8 | 4.5 |
| AUDCHF | 4 / 10 | 32 | 22 | 0.6 | 2.2 | 2.4 |
| CADCHF | 4 / 10 | 32 | 22 | 0.6 | 2.2 | 2.4 |
| NZDCAD | 8 / 10 | 64 | 54 | 1.1 | 5.4 | 6.2 |
| AUDNZD | 8 / 10 | 64 | 54 | 1.4 | 5.4 | 6.4 |

General, k* = N*a/e - 1 before costs:

| exit | cap | a=2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 5 | 6 | 1.4 | 2.6 | 3.8 | 5.0 | 6.2 | 7.4 | 8.6 | 9.8 | 11.0 |
| 5 | 8 | 2.2 | 3.8 | 5.4 | 7.0 | 8.6 | 10.2 | 11.8 | 13.4 | 15.0 |
| 5 | 10 | 3.0 | 5.0 | 7.0 | 9.0 | 11.0 | 13.0 | 15.0 | 17.0 | 19.0 |
| 10 | 6 | 0.2 | 0.8 | 1.4 | 2.0 | 2.6 | 3.2 | 3.8 | 4.4 | 5.0 |
| 10 | 8 | 0.6 | 1.4 | 2.2 | 3.0 | 3.8 | 4.6 | 5.4 | 6.2 | 7.0 |
| 10 | 10 | 1.0 | 2.0 | 3.0 | 4.0 | 5.0 | 6.0 | 7.0 | 8.0 | 9.0 |

k* rises linearly in cap and add (it is D/e - 1) and falls fastest in exit.

## 5. FLEET B, ONE WINDOW (K4)

| pair | k* (costs) | scalps (mean pips) | roll closes (mean pips) | S/R |
|---|---:|---|---|---:|
| GBPUSD | 6.8 | 23 (+10.4) | 3 (-60.6) | 7.7 |
| EURUSD | 5.1 | 27 (+10.1) | 14 (-53.1) | 1.9 |
| EURGBP | 4.5 | 19 (+5.0) | 15 (-31.0) | 1.3 |
| AUDCHF | 2.4 | 11 (+9.7) | 7 (-9.3) | 1.6 |
| CADCHF | 2.4 | 5 (+9.9) | 7 (-20.9) | 0.7 |
| NZDCAD | 6.2 | 6 (+10.6) | 0 | - |
| AUDNZD | 6.4 | 9 (+9.7) | 4 (-51.9) | 2.2 |
| total | | 100 (+9.1) | 50 (-36.2) | 2.0 |

- GBPUSD fits K2: -60.6 pips a roll close against 62.
- EURUSD and EURGBP roll closes ran deeper than K2 (-53 vs 46; -31 vs
  19): inherited layers from deeper earlier stacks re-rolled (the K3 of
  the compass amendment). AUDCHF's -9.3 against 22 is not explained here
  (irregular gaps, partial stacks): a question for the replay (s7).
- A trending window: only GBPUSD above its k*.

## 6. THE COMPASS (NO RULE CHANGE)

S/R - k* is the right diagnostic but the wrong objective:

1. **Money is margin x activity** (s1): realised = e * R * (S/R - k*). A
   large margin on a geometry that rarely rolls makes little, and with no
   roll the ratio is undefined. The objective is P&L per day.
2. **It ignores the open book.** A deep stack can show a fine S/R because
   it has not yet paid for a trend; the loss is open. The cohort's equity
   counts it.
3. **Too few rolls for a ratio in a two-day round.** K4: GBPUSD 3 rolls;
   one more takes its S/R from 7.7 to 5.8, across its k* of 6.8.

So the cohort's equity keeps deciding. For each probe, S, R, S/R, k* (with
costs) and e * R * (S/R - k*) are REPORTED beside it, so a win or loss
reads as "rolled less", "scalped more" or "paid less per roll". This goes
into the running realised report (backlog C91).

## 7. PROPOSAL A -- THE S/R REPLAY (price data, first-order)

`research/compass/sr_replay.py`, tests first, standard library:

- Per pair: long and short sides together, cap N, add a, exit e, width W
  and deadband, lattice rolls, re-roll, the roll gate (opposite side
  filled -> roll held), cost per close. Output per pair-day: S, R, S/R,
  k*, net pips, the open MTM at the day's end.
- Hand-derived tests: a swing inside D (scalps, no roll); a straight
  trend (no scalp, one roll per a beyond D); a seeded random walk (S/R
  near k*, net near zero before costs: the check that code and s2 agree);
  the gate holding a roll while the other side is filled.
- **Reconcile before use:** replay round 2 (7 Oct 02:25Z - 8 Oct 22:00Z)
  with B's geometry against B's own S and R per pair (scalp history,
  `ROLL_ACCEPTED`). Until it matches it is labelled "first-order, not
  reconciled"; the misses say what the model lacks (L0 placement and
  re-centring, inherited layers, fill timing).
- **Then a sweep:** cap 6-10, add 0.5-1.5x today's, exit as now and
  wider, per pair over months of minute data: which D suits each pair.
  Reported, never deciding unless pre-registered; the compass tests its
  candidates live.
- **Minute bars or ticks:** a minute bar misleads only when its range
  spans both a fill level and an exit (order unknown). The replay counts
  such bars per pair; where they matter (EURGBP add 3, CHF pairs add 4),
  a tick dump (a variant of the minute dump, K5) for those pairs only.

## 8. PROPOSAL B -- VOLATILITY AND PATH SHAPE AGAINST S/R - k*

**What theory predicts (s2).** In a random walk S/R = k* whatever the
volatility. Volatility sets ACTIVITY (a-steps a day scale with
sigma^2 / a^2, so S and R both scale with it), not the margin. A
volatility measure predicting the margin means real FX departs from a
random walk in a volatility-dependent way (quiet regimes reverting, news
days trending): that is the hypothesis worth testing.

**Measures, per pair-day (and per session):**

| measure | what it is | expected link |
|---|---|---|
| L = sum (M1 high - M1 low) | path travelled, PRIMARY (operator ~20:12Z: "sum (M1 high - M1 low) is probably better"): each minute's out-and-back counts | activity (S, R), not the margin |
| L_c = sum abs(M1 close change) | path travelled, secondary (operator ~20:05Z); misses every reversal inside a minute (about half the range-based L for a random walk) | activity |
| ER = abs(net change) / L | efficiency ratio: 1 = straight line, near 0 = chop | low ER, higher margin |
| ATR, realised sigma | size of moves | activity; the margin only if regime-dependent |
| reversal rate at step a | the path cut into a-pip steps; 50% = random walk | above 50%, margin above 0 (the grid's own mechanics) |
| share of zigzag legs > D | runs long enough to roll (M5 at the pair's D) | more, lower margin |
| VR at horizon D | `vr.py` | below 1, margin above 0 |

Notes on L: high and low of ONE quote side (or the mid of bid and ask),
never a bid high against an ask low, and the rollover hour left out (one
spread spike inflates a day). It depends on the sampling scale (M1 counts
moves below a that the grid never trades, and mid-quote bounce); L_a = a x (number of a-steps)
is the grid's own version, and L / L_a measures sub-a noise. ER needs a
random-walk benchmark for the same path length: E abs(net) for n steps of
a is a*sqrt(2n/pi), so Z = abs(net) / (a*sqrt(2n/pi)) below 1 means more
reverting than chance on that day.

**The trap.** Same-day correlations will be strong and mean nothing: a
trend day has a low reversal rate AND a low S/R; the same path is measured
twice. Only prediction counts:
1. **Over time:** does a pair's trailing measure (yesterday, last five
   days) predict the next day's S/R - k*? Useful only if the reversion
   character persists (volatility persists; reversion is the question).
2. **Across pairs:** do pairs with a higher reversal rate over weeks have
   a higher margin? A pair-selection screen (what holdout T1 tried with
   markouts).

**Predictions, to be fixed before any run (draft):**
- P1: L, ATR and sigma predict activity (R, S, closes), r > 0.5.
- P2: none of them predicts the next day's margin in sign once activity
  is removed (the random-walk null), OR the same-day margin falls with
  volatility (the regime hypothesis): the run says which.
- P3: the reversal rate at step a ranks pairs by margin across weeks
  better than chance (rank correlation over the nine, day-bootstrap).
- P4: the trailing reversal rate predicts the next day's margin more
  weakly than across pairs (reversion character persists less than
  volatility).

Data: a few months of minute bid / ask for the nine pairs (FTMO and IC
dumps, `InpFrom` set back), ticks only where s7's ambiguous-bar count
says so; about 60 trading days x 9 pairs. Day-bootstrap intervals; the
outcomes come from the reconciled replay (s7). First-order until our own
fills agree; any rule from it (a volatility filter, a wider stack on news
days) goes through the compass live before it changes anything.

## 9. ORDER

1. The IC-vs-FTMO rewrite to Gemini (window from Fri 9).
2. `sr_replay.py` built tests first alongside; reconciled on round 2's
   data (IC dump Thursday evening).
3. This document to Gemini with the reconciliation result; s8's
   predictions fixed (Gemini, operator) before the measures run.
4. pipshed (backlog C137, operator ~20:15Z-20:22Z): per fleet and pair
   side, S, R, S/R, k* (theory, at the live geometry, with the pair's
   own cost per close), k* actual (mean roll loss / mean scalp gain:
   inherited and re-rolled layers show here) and S/R - k*, over today,
   5 FTMO days and the cycle; fewer than 3 rolls greyed. A one-minute
   state snapshot table for intraday equity, balance, open MTM, layers
   and API; charts later.
5. Operator 7 Oct ~22:23Z: "if we can condense the 3 dials we have
   add/exit and layers into lower dimensions, i think we can really make
   our trading more sophisticated"; the literature on discrete delta
   hedging (move-based hedging, bandwidths, transaction costs) as the
   starting point.

## 10. FOR GEMINI (attack the premises; say which fact is missing)

- **GS-1.** s2: S/R = k* under a random walk (reflected depth, uniform on
  0..N; optional stopping for e != a). Does the gate (rolls held while the
  other side is filled) or the L0 re-centring break the result?
- **GS-2.** s6: the margin is reported, the cohort's equity decides. Any
  reason to decide on the margin over longer pooled windows instead?
- **GS-3.** s7: what must the replay reproduce before its sweep is
  trusted, and to what tolerance?
- **GS-4.** s8: are the measures the right ones (L, ER, ATR, reversal rate
  at a, legs > D, VR at D), and is P1-P4 a fair pre-registration?
- **GS-5.** What fact is missing?

Line count: 276
