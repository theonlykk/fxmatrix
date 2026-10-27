This message has a line count at the bottom

# MAGNET GRID -- RESULTS (27 Oct 2026; PREREG v1)

| | |
|---|---|
| Decision (PREREG s7) | **MAGNET: NONE.** The real grid (magnets at xx00 / xx50) ranks **19th of 21** (H1) and **11th of 21** (H2) in pooled NET against 20 offset copies of itself. |
| What follows | **The idea stops here** (PREREG "What follows"). Nothing live changes. With Osler (`research/cluster/results.md`), two tests agree: round numbers carry no pull that a grid can use on these pairs. |
| Run | desktop, `main` `71d06c8`; selfcheck PASS (first in both halves in 0 of 20 permuted runs; mean rank 11.38); outputs and manifest in `run_v1/` |

## 1. ONE WORKED EXAMPLE (what was compared)

GBPUSD at 1.2730. The real grid rests a sell at 1.2760 (exit 1.2750) and a buy at 1.2690 (exit 1.2700). A placebo
grid with offset 13.7 pips rests the same shape around 1.27137 and 1.27637: a sell at 1.27737 (exit 1.27637), a buy
at 1.27037 (exit 1.27137). Same rules, same bars, same costs; only the magnets differ. If round numbers pull price
back, the real grid should earn more than (nearly) all twenty placebo grids.

## 2. THE RESULT (0.01 lots a position, USD, after spread and commission; no swap)

| grid | half | real NET | rank of 21 | placebo min / median / max |
|---|---|---|---|---|
| **main** (00 / 50, d 10, cap 8, rolls) | H1 2023-24 | +589.85 | **19** | +395.77 / +796.95 / +954.44 |
| **main** | H2 2025-26 | +198.67 | **11** | -205.15 / +211.77 / +452.01 |
| quarters (00 / 25 / 50 / 75) | H1 | -648.24 | 18 | -713.56 / -562.71 / -286.40 |
| quarters | H2 | +140.02 | 7 | -162.08 / +53.82 / +234.49 |
| d 15 | H1 | +1,068.70 | 14 | +920.03 / +1,199.42 / +1,408.07 |
| d 15 | H2 | +506.05 | 7 | +245.23 / +406.28 / +749.70 |
| uncapped (no rolls) | H1 | +5,385.10 | 19 | +5,152.14 / +5,576.57 / +5,754.74 |
| uncapped | H2 | +1,993.91 | 21 | +2,092.06 / +2,252.36 / +2,566.83 |

**Round magnets never rank first, in any variant or half.** In H1 they sit near the bottom; nowhere do they stand out.

**Per pair (main grid, rank of 21, H1 / H2):** EURUSD 21 / 13; GBPUSD 18 / 7; EURGBP 2 / 18; AUDCAD 15 / 20; AUDCHF
20 / 2; CADCHF 9 / 14; GBPCHF 1 / 6. No pair is near the top in both halves.

## 3. THE GRID ITSELF (main, real magnets; reported, not deciding)

- **It made a little money in both halves** (+$590 over two years, +$199 over 22 months, seven pairs at 0.01 lots),
  but so did the median placebo grid (+$797, +$212): the earnings come from price's back and forth around ANY level,
  not from round numbers. The total is realised +$1,484 / +$1,103 less the open book at the half's end, -$894 / -$904
  (57 and 55 positions, about 8,400 and 7,900 pips under water across the pairs). Swap is not counted; positions held
  for weeks would pay it, so the true figure is lower.
- **Risk:** the worst FTMO day of the seven pairs together **$573.81 (5 Aug 2024)** and **$601.35 (4 Apr 2025)**, one
  day over $500 in each half; the worst peak to trough **$1,280 (H1)** and **$1,596 (H2)**. That is more drawdown than
  two years' profit, at 0.01 lots.
- Trades: 11,116 entries in H1 and 9,956 in H2 across the seven pairs; 227 and 210 rolls.

## 4. THE PREDICTIONS (PREREG s8), SCORED

1. MAGNET EFFECT no, pooled rank 5-17 in each half: **half right** (NONE; but H1's rank 19 is outside 5-17: round
   levels did slightly WORSE than most offsets there).
2. Pooled NET negative in at least one half: **wrong** (+590, +199).
3. A day over $500 in four years: **right** (one in each half: 5 Aug 2024, 4 Apr 2025).
4. Selfcheck 0 of 20: **right**.

## 5. READING

The operator's lead ("magnetism to round numbers") gave two pre-registered tests on four years of FTMO minute data.
Osler's: a touch of a round level holds no more often than a touch of any level. This one: a grid that sells 10 pips
above round levels and buys 10 below, exiting at the level, earns no more than the same grid anywhere else (19th and
11th of 21). The small profit any such grid makes is the market's ordinary mean reversion, which the fxgrind lattice
already harvests, and it comes with drawdowns larger than the profit (5 Aug 2024, 4 Apr 2025). As the operator said:
"if this is random walk, then we are just trying to read tea leaves".

## 6. LIMITS

M1 bars (no same-bar exit; fills at the limit price); one feed; no swap; requests not modelled; USD per pip fixed; one
offset per variant. A real effect smaller than the spread between placebo grids (about +/- $300 over two years here)
could not be seen.

Line count: 71
