This message has a line count at the bottom

# MARKOUT AND VARIANCE STUDY -- IS THE GRID SELLING CONVEXITY AT A GOOD PRICE?

| | |
|---|---|
| Status | **FIRST PASS, exploratory** (Claude, 5 Oct ~03:20Z, HANDOFF s56). Not a ruling; no geometry change follows from it alone. Re-run on the 1-7 Oct holdout (C84) and on IC's own dumps before any conclusion |
| Origin | Operator, 5 Oct ~03:00Z (the EUR grind; Sun 4 Oct ~23:00 Toronto): "i am wondering if the whole vision of how to trade fx is plausible ... in rates and credit you eventually lean against an arbitrage ... with spot fx you have no such thing to lean against"; and "my belief is that convexity is overpriced ... delta hedging an option feels like it is doing what we are doing - is that fair?" |
| Code | `research/markout/` (`vr.py`, `cal.py`, `markout.py`; README). Standard library only; reuses `research/ejection_value` loaders (imported, never changed) |
| Data | FTMO `grind_bidask_dump` minute bars, 21 pairs, 20 Sep 21:05 - 3 Oct 07:30 server (`bidask_ftmo_2026-10-02/`, Downloads and the Surface); the archive export `archive_2026-10-02.jsonl` (fill_logs from 11 Sep) |

## 1. THE QUESTION, IN OPTION TERMS

The grid's trades are a long-option holder's delta hedge: sell rallies,
buy dips. Holding those trades WITHOUT the option replicates minus the
option: the grid is synthetically SHORT convexity. Scalps play the part
of theta; inventory at cap is the gamma loss in a trend. Unlike a short
option book, nobody pays the grid a premium: its "theta" comes from the
path itself. For a pure random walk the scalps exactly fund the expected
inventory loss (the grid's expectation is zero before costs, negative
after). So the grid's edge cannot be "convexity is overpriced"; it must
be that price MEAN-REVERTS at the scalp scale (an exit, ~10 pips) more
than at the inventory scale (cap x add, ~60-80 pips), and that our
passive fills are not too adversely selected. Both are measurable.

## 2. TWO FACTS THAT SET THE BASELINES

- **A resting buy limit pays the spread here, it does not earn it.** MT5
  fills a buy limit when the ASK reaches it, so the mid is already half a
  spread below our entry at the fill: a random walk gives a markout of
  about -1/2 spread at every horizon. Zero is NOT the baseline.
- **Minute sampling under-counts small zigzags** (`cal.py`, 40 random
  walks of 14,000 minutes): a random walk scores Z(5) 0.66, Z(10) 0.82,
  Z(20) 0.90 (sd 0.03-0.11), VR(60) 0.99 +/- 0.08, VR(240) 0.96 +/- 0.15,
  VR(1440) 0.91 +/- 0.38. Twelve trading days make the day-scale ratio
  too noisy to lean on; the 1-hour and 4-hour ones carry the weight.

## 3. METHOD

### 3.1 Price behaviour per pair (`vr.py`)

Mid = (bid close + ask close) / 2 per minute; 20:50-22:15Z dropped
(rollover spreads). VR(q) = Var(q-minute change) / (q x Var(1-minute
change)), overlapping, only where both ends exist (no weekend spans):
below 1 = mean reversion at q minutes, above 1 = trend. Z(h) = number of
h-pip zigzag legs x h^2 / (reference variance per minute x minutes):
above the random-walk value = more oscillation at h pips than the
reference horizon implies (good for a grid at that scale).

### 3.2 Our entry fills (`markout.py`)

Every ENT layer in the archive opened after 21 Sep (4,518 fills, all
four fleets): markout(h) = (mid(t + h) - entry) / pip for a long, the
negative for a short, h = 0, 1, 5, 15, 60, 240, 1440 minutes, on FTMO's
mid (IC's mid differs by fractions of a pip; IC dumps for B, C, D are
the robustness check left in s6). Depth = the side's open layers at the
fill, the new one included.

## 4. FIRST RESULTS

### 4.1 All fills (pips; + = the market came back our way; mean +/- naive se)

| | 0 | 1m | 5m | 15m | 1h | 4h | 1d |
|---|---|---|---|---|---|---|---|
| all (4,518) | -0.4 | -0.7 | -0.8 | -1.0 | -0.6 | +0.5 | +1.0 |
| depth 1 = L0 (463) | -0.3 | -0.6 | -1.2 | **-2.3** | **-2.3** | **-5.0** | **-4.5** |
| depth 2-3 (1,000) | -0.4 | -0.6 | -0.7 | -1.4 | -1.0 | -0.2 | -1.1 |
| depth 4-5 (991) | -0.4 | -0.6 | -0.7 | -1.2 | -1.1 | +0.0 | +2.6 |
| depth 6-7 (863) | -0.3 | -0.6 | -0.6 | -0.6 | +0.1 | **+2.2** | **+5.4** |
| depth 8+ (1,201) | -0.6 | -0.8 | -0.8 | -0.4 | +0.4 | **+2.5** | +0.9 |

Naive se: 0.1-0.3 up to 1 h, 0.5-0.7 at 4 h, 1.1-1.5 at 1 d.

- **Short horizon: adverse selection, about half a pip beyond the
  spread.** The fill-time markout (-0.4) is the half spread; by 15
  minutes it is -1.0: the market keeps going for a while after it
  fills us.
- **L0 is the worst entry by far:** -2.3 pips at 15 minutes to 1 hour
  and -5.0 at 4 hours. A first layer typically fills as a move STARTS.
- **Deep layers are the best entries:** depth 6-7 +2.2 at 4 hours and
  +5.4 at a day. After an extended move, price tends to come back. In
  this sample scaling in WAS rewarded at the 4-hour horizon; the
  inventory scale (8+) is positive at 4 h but not at a day (+0.9 +/- 1.1),
  where the trend days (CHF 1 Oct, EUR) live.

### 4.2 Per pair (markout at 1 h and 4 h; VR at 1 h and 4 h; Z(10) vs 4 h)

| pair | mk 1h | mk 4h | VR60 | VR240 | Z(10) vs 4h | reading |
|---|---|---|---|---|---|---|
| GBPUSD | +0.7 | +1.1 | 0.82 | 0.75 | 0.93 | reverting at 1-4 h |
| EURUSD | +0.5 | +0.9 | 0.97 | 0.91 | 0.80 | about a random walk |
| EURGBP | +0.3 | +0.9 | 0.85 | 0.77 | 0.80 | reverting at 1-4 h |
| NZDCAD | +0.1 | +1.8 | 0.88 | 0.68 | **1.19** | reverting; rich oscillation |
| AUDNZD | -1.4 | +0.3 | 1.03 | 0.74 | 0.98 | reverting at 4 h, not 1 h |
| AUDCAD | -1.0 | -0.7 | 1.10 | 0.96 | 0.68 | trending at 15-60 min |
| CADCHF | -1.4 | -0.4 | 0.93 | 0.66 | 1.12 | oscillates, but fills adverse |
| NZDCHF | -1.6 | +0.2 | 1.11 | 0.95 | 0.84 | trending at 1 h |
| AUDCHF | **-2.4** | -0.3 | **1.37** | 1.09 | 0.71 | trending (the CHF week) |

Random-walk Z(10) vs 4 h is about 0.85; VR(60) +/- 0.08, VR(240) +/- 0.15.

- **The two measures agree:** the rank correlation of VR(60) with our
  fills' 1-hour markout across the nine pairs is **-0.83** (with the
  4-hour markout -0.65). Pairs that trend at the hour are the pairs whose
  entries hurt. Price data alone ranks pairs for the grid.
- **Outside our nine:** NZDUSD (VR240 0.67, Z(10) 1.25) and USDCHF (0.56,
  1.25) look like grid pairs on these measures; EURCHF, GBPCHF, EURCAD and
  GBPCAD trended through the sample (VR(1440) 1.2-2.1, Z(10) vs 4 h 0.50-0.79).

## 5. WHAT THIS DOES AND DOES NOT SHOW

- **Twelve trading days, one regime** (the SNB on 24 Sep, the CHF trend
  1 Oct, payrolls 2 Oct). Every number here is a hypothesis for the holdout.
- **Fills are not independent:** four fleets trade the same ticks and a
  move fills several layers in minutes. The naive se above is too small
  by perhaps 2-3x; treat differences under ~1 pip at 1 h as noise.
- **Markouts at fixed horizons are not P&L:** the grid exits at +exit
  pips whenever it gets there. The markouts say whether the market comes
  back toward an entry, not whether that entry scalped.
- **Supports the grid where it oscillates, not in general:** consistent
  with the operator's reading (richness and cheapness last minutes, not
  days): reversion is real at 1-4 hours on some pairs, absent or reversed
  on others, and the first layer is reliably the worst entry.

## 6. NEXT (proposals, nothing ruled)

1. **Holdout:** NOT 1-7 Oct (1-2 Oct are in this sample): FTMO days
   5-9 Oct, pre-registered in `docs/research/holdout-verdict-criteria.md`
   (5 Oct ~04:20Z). Originally written: re-run on 1-7 Oct (C84's window; the FTMO and IC dumps
   for that week) with the code unchanged; the per-pair ranking and the
   L0-versus-depth pattern are the two things to confirm.
2. **IC's own mid** for B, C, D fills (wine-c dumps), and markouts per
   fleet x depth (does D's tighter exit change anything?).
3. **If L0's adverse selection holds:** it argues AGAINST a tighter
   counter-side L0 (C103) and for a wider first step, or for placing L0
   only after a small move away from mid. A Gemini question, after the
   holdout.
4. **If depth's positive 4-hour markout holds:** scaling in is rewarded
   at 4 hours, and the inventory question is the day horizon (trend days)
   only: per-currency exposure limits rather than less depth.
5. **Pair selection by VR(60) / Z(10):** a cheap pre-screen for scouts
   and rings, beside spread / range (MEMO_2026-10-03 s8).

Line count: 144
