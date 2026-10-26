This message has a line count at the bottom

# ROUND NUMBERS IN FX -- AN OSLER REPLICATION -- RESULTS (26 Oct 2026; PREREG v3.2)

| | |
|---|---|
| Decision (PREREG s7) | **ROUND REVERSAL EFFECT: NONE. ROUND CROSSING EFFECT: NONE.** Neither half passes either test. |
| What follows | **The round-aware lattice stops here** (PREREG "What follows": no effect, the idea stops, and that is reported). Nothing live changes. |
| Data | FTMO M1 bars, 2 Jan 2023 - 23 Oct 2026, seven pairs (hashes PREREG s3, re-checked by both stages); 98 common ten-day blocks (H1 51, H2 47); 686 pair-blocks |
| Run | desktop, `main` `bd46567`; selfcheck PASS (reversals 0 of 20, crossing size 1 of 20); outputs and manifest in `run_v32/` |
| History | v3.1's selfcheck failed on crossing size (the comparison was tilted toward any grid; `selfcheck_v31/`); v3.2 matched the comparison's structure (PREREG s1b). No real number was read before v3.2's selfcheck passed. |

## 1. ONE WORKED EXAMPLE (prices)

EURUSD falls toward 1.1600. Its band is 1.15988 - 1.16012 (0.01% either side). At 14:03 server the minute quote
is 1.16010: a hit from above. At 14:18 (15 minutes on), is the quote still above 1.1600 (a REVERSAL: the level
held) or below (a CROSSING)? The same is counted at twenty comparison grids drawn for that pair and block, say
1.16137, 1.16637, 1.15637 (one grid, offset 13.7 pips from the round grid), each measured exactly as the round
grid. Osler's finding (1996-98): round levels held about 59% of the time against about 55% for other levels.

## 2. THE RESULT

Reversal rate at round levels against the comparison grids (mean over the counted pair-blocks):

| | round (RVR) | comparison (RVA) | round hits |
|---|---|---|---|
| H1 2023-24 (356 pair-blocks) | 57.7% | 57.5% | 62,985 |
| H2 2025-26 (329 pair-blocks) | 58.3% | 58.2% | 57,410 |

The test (PREREG s5: D_j = the mean over pairs of RVR - RVA per block; one-sided sign test; bootstrap 95%):

| measure | half | blocks won / lost | p | mean D_j | 95% interval |
|---|---|---|---|---|---|
| reversal | H1 | 31 / 20 | 0.080 | +0.17 points | -0.37 to +0.71 |
| reversal | H2 | 24 / 23 | 0.500 | +0.07 points | -0.44 to +0.56 |
| crossing size at 15 min | H1 | 29 / 22 | 0.200 | +0.00088% of L | -0.00001 to +0.00190 |
| crossing size at 15 min | H2 | 30 / 17 | 0.040 | +0.00076% of L | +0.00000 to +0.00146 |

Decision rule: p < 0.01 and mean > 0 in BOTH halves. Neither test reaches p < 0.01 in either half.

**Size, not only significance:** Osler's reversal effect was +1.5 to +4.5 points. Here the interval excludes
anything above about +0.7 points in either half: an effect of her size would have shown. The crossing-size
difference is about 0.0008% of the level, roughly 0.1 pip on EURUSD at 1.16, against the 5-26 pip adds the
fleet uses; even if real, it is no premise for a geometry.

## 3. REPORTED, NOT DECIDING

- **Per class:** R100 (levels ending 00) +0.05 / +0.15 points (p 0.50 / 0.39); R50 -0.11 / -0.03 (0.29 / 0.39).
  R100 sits above R50 in both halves, but neither differs from the comparison. (Against the same RVA; not
  structure-matched.)
- **Osler's hours (16:00-23:00 server):** +0.57 / -0.20 points (p 0.50 / 0.61).
- **Crossing size later:** 30 min +0.00035 / +0.00037% (p 0.95 / 0.50); 60 min p 0.80 / 0.39; 120 min p 0.50 / 0.12.
- **Per pair, reversal (H1 / H2):** EURUSD -1.5 / -1.2 points (round levels hold LESS often; p 0.95 / 0.99);
  GBPUSD -0.2 / -0.6; EURGBP +0.8 / +2.5 (p 0.44 / 0.07); AUDCAD +0.2 / +0.2; AUDCHF +0.5 / +0.4; CADCHF
  +0.6 / -0.2; GBPCHF +1.0 / -0.6. No pair is significant in both halves; seven pairs and two halves give
  fourteen draws, so one near 0.07 is expected.

## 4. THE PREDICTIONS (PREREG s8), SCORED

1. Pooled RVR - RVA between +1 and +5 points in each half: **WRONG** (+0.17, +0.07).
2. ROUND REVERSAL EFFECT in both halves, larger at R100: **WRONG** (NONE; R100 above R50, both near zero).
3. Crossing size p < 0.01 in H1, H2's mean smaller: **WRONG on the first part** (H1 p 0.20); H2's mean smaller
   (+0.00076 against +0.00088): right, but moot.
4. Synthetic check 0 or 1 of 20: right for v3.2 (0 and 1); v3.1 failed it (2 of 20), which is why v3.2 exists.

## 5. READING

On four years of FTMO minute quotes, price at a round number (00 or 50) does not hold or break any differently
from price at any other level spaced the same way. Osler's 1996-98 effect, measured on Reuters quotes at a bank
dealing desk, is not visible here at her scale (a 0.01% band, 15 minutes). The operator's caution ("if this is
random walk, then we are just trying to read tea leaves") is what the data says for this question: the "back and
forth around whole numbers" is the back and forth around every level.

## 6. LIMITS

One feed (FTMO's demo minute bars: the open plus half the bar's spread), not ticks; Osler's band and horizon taken
as published, not searched; the comparison is v3.2's structure-matched grids, not her uniform levels (v3.1's
uniform comparison failed its own null check). A longer horizon, a wider band or tick data could show something
this does not; none of them was pre-registered, and looking now would be searching.

Line count: 81
