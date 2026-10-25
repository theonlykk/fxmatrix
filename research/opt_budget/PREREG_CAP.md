This message has a line count at the bottom

# OPT CAP SWEEP -- PRE-REGISTRATION (25 Oct 2026 ~01:35Z; before any cap run)

**Question (operator, 25 Oct ~01:24-01:28Z):** "we have too few layers in the opt arm before it rolls ... there is a
drop of in range trading activity after a certain distance. the ideal place for the roll would be at that point";
"proceed. we might end up with more layers but less fx pairs". Evidence so far (`depth.py`, BASE): no fall-off inside
7 layers (calm scalps a day while present: layer 1 0.8, layer 4 1.7, layer 7 8.8; about $0.8 a scalp throughout).

## 1. ONE WORKED EXAMPLE (EURUSD long, OPT add = exit 7; falling from 1.1600)

Cap 7: OPT holds 1.1600 ... 1.1558 and rolls from 1.1551 (the 1.1600 layer's exit moves to 1.1558). Cap 11: it also
holds 1.1551, 1.1544, 1.1537, 1.1530 and rolls from 1.1523; the 1.1600 layer then waits for 1.1530 + 7 = 1.1537 after
its roll, not 1.1558 + 7.

## 2. RUNS

OPT's cap 9, 11, 13 (ALT unchanged at 7; everything else t3 as PREREG.md s3), calm and October, uncoupled (no budget).
BASE = cap 7 (the existing `base_*.json`). No other change.

## 3. MEASURES (each cap against BASE)

As PREREG.md s5, plus: OPT's rolled closes; per pair, net (calm, October) and the most negative open P&L (inventory);
the fleet's peak open layers at a 5-minute mark (October; positions only, the commitment guard counts orders too and is
not simulated).

## 4. DECISION (per cap, fleet)

**BETTER** if both: (a) calm + October net >= 1.2 x BASE's (+$216.00); (b) October's largest FTMO-day loss <= 1.1 x
BASE's ($616.52). Else NOT BETTER. The per-pair table is reported, not deciding (for "fewer pairs").

## 5. CLAUDE'S PREDICTIONS (before any run)

(1) calm net rises with the cap to 11 and flattens by 13; (2) OPT's rolled closes fall with the cap in both periods;
(3) October's largest FTMO-day loss rises with the cap; (4) no cap is BETTER (it fails on (b)).

## 6. LIMITS

As PREREG.md s8; the commitment guard (194 positions + orders + resting entries on the account) is not simulated: a
cap that scores may not fit on E's twelve instances.

Line count: 42
