This message has a line count at the bottom

# OPT BUDGET, VARIANT B2 (TWO SECTIONS) -- PRE-REGISTRATION (24 Oct 2026; before any B2 run)

**Question (operator, 24 Oct ~23:39Z):** "instead of splitting the adding of the opt layers into three sections, what
if we just split it into two? the first four layers with the first four layers of alt, and the second four layers of
opt with the second four layers of alt?" With cap 7 (t3 as live) the second section is OPT's layers 5-7.

## 1. ONE WORKED EXAMPLE (EURUSD long, OPT add = exit 7, ALT add = exit 23, cap 7; falling from 1.1600)

OPT 1.1600, 1.1593, 1.1586, 1.1579 (4), then withheld; ALT 1.1600, 1.1577, 1.1554, 1.1531 (4): ALT's 5th add rests at
1.1508 and OPT's 5th rests there too; both fill at 1.1508; OPT 1.1501, 1.1494 (7, cap); rolls from there as today.

## 2. THE RULE (as PREREG.md s2 with a new budget)

a = ALT's depth on the side; **B2(a) = 4 if a <= 4, 7 if a >= 5.** OPT depth d < B2(a): adds as today; d >= B2(a) and
d < 7: withheld, EXCEPT a = d = 4 with an ALT resting add: OPT's add rests at ALT's add price. Everything else as
PREREG.md s2.

## 3. RUNS, CALIBRATION, MEASURES, DECISION

As PREREG.md s3-s6 and A1. BASE is the same BASE (`runs_outputs.sha256`: `base_oct.json`, `base_calm.json`, re-used,
not re-run); calibration already passed (PREREG.md s9). **Decision as PREREG.md s6** (WORTH THE HARNESS only if: calm
net >= 80% of BASE; October net >= BASE - $20; October's largest FTMO-day loss <= 80% of BASE or both periods >= 120%).

## 4. CLAUDE'S PREDICTIONS (before any B2 run)

(1) B2 keeps more calm revenue than B (calm net above B's +$104.03) but under 80% of BASE's +$229.86; (2) October's
largest FTMO-day loss within 5% of BASE's $616.52; (3) NOT WORTH IT.

Line count: 31
