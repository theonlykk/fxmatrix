This message has a line count at the bottom

# OPT BUDGET -- RESULT (24 Oct 2026): NOT WORTH IT

Rule, gate and decision: `PREREG.md` (pre-registered `02d3af9` on `main`; amendment A1 `d764faa`, before any BUDGET run).
Simulator `sim.py` (`MECHANICS.md`; 9 / 9 tests). Runs `runs.py` (outputs hashed in `runs_outputs.sha256`, not in
git); scoring `score.py`, `compare.py` (`compare_output.txt`). GBPUSD's October BUDGET run re-run: identical.

## 1. ONE WORKED EXAMPLE

EURUSD, the calm weeks: BASE (t3 as live) +$36.81; BUDGET -$18.29. Price swung within a few adds of where the stacks
began; OPT's 4th-7th layers did much of the scalping there; withheld until ALT's 4th filled, those trades were lost,
and the rolls saved did not pay for them.

## 2. CALIBRATION (BASE simulator against the replay)

October: closes within 4% on every cell; fleet net -$13.86 against +$15.59; largest FTMO-day loss $616.52 against
$626.51; max peak-to-trough $325.72 against $308.57. Calm: fleet net +$229.86 against +$215.05; closes within 5% on ten
cells, EURGBP ALT 4 against 5 and CADCHF ALT 36 against 31 (pass under A1).

## 3. BUDGET AGAINST BASE (USD at 0.01 lots, the twelve cells as one account)

| measure | calm BASE | calm BUDGET | October BASE | October BUDGET |
|---|---|---|---|---|
| fleet net | +229.86 | +104.03 | -13.86 | +40.07 |
| commission | 134.16 | 98.04 | 81.30 | 55.02 |
| OPT scalps / rolled closes / roll steps | 1,724 / 107 / 133 | 1,203 / 26 / 31 | 969 / 133 / 160 | 628 / 36 / 44 |
| worst calm week | -68.16 | -70.53 | | |
| largest FTMO-day loss | | | 616.52 | 613.63 |
| days over $300 / $500 | | | 11 / 3 | 15 / 5 |
| max peak-to-trough | | | 325.72 | 278.88 |

Per pair (calm BASE / BUDGET; October BASE / BUDGET): GBPUSD +94.91 / +57.96, -21.72 / +4.30; EURUSD +36.81 / -18.29,
+2.13 / -6.95; EURGBP +31.99 / +13.79, -101.02 / -84.06; AUDCAD +60.85 / +42.89, +32.83 / +23.50; AUDCHF -8.57 / -3.80,
+25.65 / +48.64; CADCHF +13.87 / +11.48, +48.27 / +54.64.

## 4. VERDICT BY THE RULE: NOT WORTH IT

Criterion 1 FAILED (calm net 45% of BASE, against 80%); criterion 2 held (October +$53.93); criterion 3 FAILED (largest
FTMO-day loss 100% of BASE; both periods +$144.10 against +$216.00). The idea stops; no EA code.

**Predictions:** (1) calm OPT closes down 20% or more: HELD (-33%); (2) October's largest FTMO-day loss down 10-30%:
FAILED (-0.5%); (3) NOT WORTH IT on criterion 1: HELD.

**Reading:** the rule did what it was built to do (rolled closes down 70-75%, worth $54 in October), but the small-
range revenue it gave up was larger, and it leaves FTMO's constraint untouched: the inventory is still carried (OPT's
first cluster now sits far from price instead of rolling), so more days cross $300 and $500, not fewer.
The operator (24 Oct ~23:07Z): "boring remains best, but best is far from sufficient".

## 5. LIMITS

As PREREG s8; the simulator is not the harness (calibration bounds the gap at the fleet level; per-cell nets differ
by up to about $20).

## 6. VARIANT B2 (two sections of four; `PREREG_B2.md`): NOT WORTH IT

Calm +$121.24 (BASE +$229.86, 53%); October +$12.04 (-$13.86); largest FTMO-day loss $575.67 ($616.52, 93%); days over
$300 / $500 15 / 4. Predictions: (1) calm between B and 80% of BASE: HELD; (2) FTMO-day loss within 5%: FAILED (-7%);
(3) NOT WORTH IT: HELD. `compare_b2_output.txt`.

## 7. WHY SECTIONS LOSE (`depth.py`; `depth_calm_output.txt`, `depth_oct_output.txt`)

OPT's scalps by place in the stack, calm, BASE / B2: layers 1-4 1,206 (+$1,025) / 1,189 (+$1,010); layers 5-7 518
(+$417) / 171 (+$143). About $0.8 a scalp at every depth. Time at depth, calm: OPT 1-4 75%, 5-7 17%; ALT at 1 49%, 5-7
5%; while OPT holds 5-7, ALT holds 2-4 77% of the time (October 60%). ALT reaches its 5th layer after 4 x 23 = 92 pips,
OPT after 4 x 7 = 28: tying OPT's 5th to ALT's 5th waits for a 92-pip move.

## 8. THE OPT CAP SWEEP (`PREREG_CAP.md`; `capcmp_output.txt`) AND ITS HARNESS CHECK (sweep_notes swcap)

Simulator (both periods; largest FTMO-day loss): cap 7 +$216.00, $616.52; cap 9 +$305.93, $643.85 (BETTER); cap 11
+$297.10, $678.39; cap 13 +$236.60, $750.76. Harness, cap 9: +$336.00, $638.94: CONFIRMED. Per pair the wide-add pairs
(AUDCAD 18, AUDCHF 14, CADCHF 10) barely change past 9; GBPUSD and EURUSD trade calm revenue for October; EURGBP's
October worsens at every cap.

Line count: 75
