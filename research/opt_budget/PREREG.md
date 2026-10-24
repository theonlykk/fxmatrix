This message has a line count at the bottom

# OPT BUDGET -- PRE-REGISTRATION (24 Oct 2026; written before any simulator run)

**Question (operator, 24 Oct ~20:51-20:57Z):** "what if we budgeted the layers of opt arm across the alt arm ... only add
the first three layers of opt while the layers of alt were less than 3 and then the next three layers of opt when
the layers of alt were between 4 and 6 ... small prices clusters to trade that were separated by larger gaps. we would
minimize the number of rolls but take advantage of small range trades"; then "opt still rolls as before, it is just
that we have something slowly down the add layers pace. I think a new cluster. maybe we put the opt and alt 4th layer
at the same place? if alt layer exits, I think opt 4-6 would have exited." Test path ruled ~21:01Z: a Python check
first (this), the replay harness only if it passes.

## 1. ONE WORKED EXAMPLE (EURUSD long, OPT add = exit 7, ALT add = exit 23, cap 7; price falling from 1.1600)

OPT fills 1.1600, 1.1593, 1.1586 (3 layers) while ALT holds 1.1600 and 1.1577 (2): OPT's 4th add is withheld. ALT
fills 1.1554 (3 layers); its next add rests at 1.1531, and OPT now places its 4th add at 1.1531 too. At 1.1531 both
fill: ALT 4, so OPT may hold 6; OPT's 5th and 6th rest at 1.1524 and 1.1517 (its normal spacing). OPT's 7th waits for
ALT's 7th the same way (ALT 6 -> OPT's 7th at ALT's 7th add price). Today OPT would hold 1.1600 ... 1.1558 (7) by 1.1558
and roll from 1.1551. Rolls are unchanged: only at cap 7 (MECHANICS s3).

## 2. THE RULE (per pair, per side; ALT unchanged)

a = ALT's depth on the side; OPT's budget B(a) = 3 if a <= 3, 6 if 4 <= a <= 6, 7 if a = 7.
- OPT depth d < B(a): OPT adds as today (anchor -/+ OPT's add).
- d >= B(a) and d < 7: OPT's add is withheld (a resting OPT add is cancelled), EXCEPT when a = d (3 or 6) and ALT has a
  resting add: then OPT's add rests at ALT's resting add price (the new cluster), moving with it.
- L0, exits, rolls, re-rolls, carry: unchanged. OPT never closes a layer because of the rule.

## 3. RUNS (simulator `sim.py`, MECHANICS.md; t3's adds: GBPUSD 9 / 15, EURUSD 7 / 23, EURGBP 5 / 23, AUDCAD 18 / 26,
AUDCHF 14 / 20, CADCHF 10 / 17; exit = add, cap 7, deadband 2, lattice, re-roll, gate 0; width and stranded as the
replay's run files)

- **Calm:** sweep4's eight Aug - Sep weeks, weekly flat starts, carry OFF, the h8w ticks (as sweep11's `sw11w`).
- **October:** 1-20 Oct, one flat start, carry ON with each pair's swaps (as sweep9 / sweep10 / `sw11o`).
- **BASE** = the twelve cells uncoupled (t3 as live); **BUDGET** = the same with s2 applied to each pair's OPT.

## 4. SELF-CHECKS FIRST: THE CALIBRATION GATE (BASE simulator against the replay; any failure: STOP, report, amend
before any BUDGET run)

- C1 every cell and period: the simulator's closes (S + R) within +-15% of the replay's (`out_*_summary.txt`).
- C2 each period: the fleet's USD net within +-$40 of the replay's (calm +$215.05 over the 8 weeks summed; October
  +$15.59).
- C3 October: the fleet's largest FTMO-day loss (day-start balance - the day's lowest equity, 5-minute marks) within
  +-25% of the replay's $626.51, and its max peak-to-trough within +-25% of $308.57 (t3dd, 24 Oct).
- C4 the tests (`test_sim.py`) all pass.

## 5. MEASURES (each period; BUDGET and BASE both from the simulator, so its errors largely cancel)

Fleet USD net, commission, gross; OPT's S, R and A; October: the largest FTMO-day loss, days over $300 and $500, max
peak-to-trough; calm: the worst week. Per pair beside the fleet.

## 6. DECISION (BUDGET against BASE)

**WORTH THE HARNESS** if all three:
1. calm: BUDGET's fleet net >= 80% of BASE's (the small-range revenue mostly kept);
2. October: BUDGET's fleet net >= BASE's - $20;
3. October: BUDGET's largest FTMO-day loss <= 80% of BASE's, OR the two periods' combined net >= BASE's x 1.2.
Else **NOT WORTH IT** (the idea stops here, no EA code). Either way the per-pair table is reported, not deciding.

## 7. CLAUDE'S PREDICTIONS (before any run)

(1) BUDGET cuts OPT's closes by 20% or more in the calm weeks; (2) it lowers October's largest FTMO-day loss by 10-30%;
(3) the verdict is NOT WORTH IT on criterion 1 (calm revenue falls more than 20%).

## 8. LIMITS

In-sample adds (sweep11); one October path; every pair on the EURUSD chart in the replay; the simulator is not the
harness (C1-C3 bound the gap); OPT and ALT share no slot, cap or roll gate (they are separate instances live).

Line count: 70
