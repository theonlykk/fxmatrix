"""Hand-valued tests for score11.py, the sweep11 selection (run: python -B test_score11.py from this folder).

The rule (sweep_notes sweep11; the operator 22 Oct ~18:44Z: OPT from the calm weeks, ALT from October, "presets that we
can defend"), per pair, on the add = exit line at cap 7 (pips at 0.01 lots):
- OPT: over windows of three ADJACENT adds of the calm grid, the window with the largest summed calm net (eight weekly
  flat starts, Aug - Sep); OPT = its middle add, IF that add's own calm net > 0 AND the window's sum > 0; else NO OPT.
  Ties: the smaller middle add.
- ALT: among October adds ABOVE OPT's (all, if no OPT) whose calm net is at least -100 (the cost of the insurance),
  windows of three ADJACENT eligible adds; the largest summed October net (ALT alone, one flat start carried 1 - 20 Oct);
  ALT = its middle add IF its own October net > 0; else NO ALT. Fewer than three eligible: the best single one if > 0.
  Ties: the smaller middle add.
- Reported: each arm over both periods (calm + October), the pair's total, against the staged t1 + t2.
"""
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import score11 as s11  # noqa: E402

CALM = {3: -50.0, 4: 10.0, 5: 40.0, 6: 30.0, 8: -20.0, 10: -5.0, 12: -30.0, 16: -60.0, 20: -90.0, 24: -150.0}
OCT = {3: -400.0, 4: -300.0, 5: -200.0, 6: -100.0, 8: 50.0, 10: 120.0, 12: 200.0, 16: 180.0, 20: 250.0, 24: 400.0}


class Select(unittest.TestCase):
    def test_opt_middle_of_best_calm_window_and_alt_from_october_with_the_calm_limit(self):
        # calm windows: (3,4,5) 0, (4,5,6) 80, (5,6,8) 50, (6,8,10) 5, ... -> OPT 5 (own +40)
        # ALT eligible above 5 with calm >= -100: 6, 8, 10, 12, 16, 20 (24 out: calm -150)
        # October windows: (6,8,10) 70, (8,10,12) 370, (10,12,16) 500, (12,16,20) 630 -> ALT 16 (own +180)
        self.assertEqual(s11.select(CALM, OCT), (5.0, 16.0))

    def test_no_opt_when_no_calm_window_is_positive(self):
        calm = {a: -10.0 for a in CALM}
        # no OPT; ALT eligible = every October add with calm >= -100 (all): windows ... best (16,20,24) 830 -> 20
        self.assertEqual(s11.select(calm, OCT), (None, 20.0))

    def test_no_opt_when_the_middle_add_itself_is_not_positive(self):
        calm = dict(CALM)
        calm.update({4: 60.0, 5: -1.0, 6: 60.0})   # best window (4,5,6) 119, middle -1 -> no OPT
        self.assertIsNone(s11.select(calm, OCT)[0])

    def test_tie_takes_the_smaller_middle(self):
        calm = {3: 10.0, 4: 10.0, 5: 10.0, 6: 10.0, 8: -500.0}
        self.assertEqual(s11.select(calm, {3: 1.0, 4: 1.0, 5: 1.0, 6: 1.0, 8: 1.0})[0], 4.0)

    def test_fewer_than_three_eligible_takes_the_best_single(self):
        calm = {3: 10.0, 4: 30.0, 5: 20.0, 6: -500.0, 8: -20.0, 10: -30.0}
        # OPT: (3,4,5) 60 -> 4; ALT eligible above 4 with calm >= -100: 5, 8, 10 -> three; make 10 ineligible
        calm[10] = -101.0
        self.assertEqual(s11.select(calm, {3: 0.0, 4: 0.0, 5: 5.0, 6: 99.0, 8: 7.0, 10: 50.0}), (4.0, 8.0))

    def test_no_alt_when_the_best_window_middle_is_not_positive(self):
        octo = {a: -5.0 for a in OCT}
        self.assertEqual(s11.select(CALM, octo), (5.0, None))


class Both(unittest.TestCase):
    def test_both_periods_per_arm_and_total(self):
        # OPT 5: calm +40, October -200 -> -160; ALT 16: calm -60, October +180 -> +120; total -40
        self.assertEqual(s11.both(CALM, OCT, 5.0, 16.0), {"opt": -160.0, "alt": 120.0, "total": -40.0})
        self.assertEqual(s11.both(CALM, OCT, None, 16.0), {"opt": 0.0, "alt": 120.0, "total": 120.0})


class Weekly(unittest.TestCase):
    def test_weekly_nets_summed_per_geometry(self):
        labels = {1: ("a3e3n7", "w1"), 2: ("a3e3n7", "w2"), 3: ("a4e4n7", "w1"), 4: ("a4e4n7", "w2")}
        sc = {1: {"total_net": 5.0}, 2: {"total_net": -2.5}, 3: {"total_net": 1.0}, 4: {"total_net": 1.0}}
        self.assertEqual(s11.weekly(labels, sc), {3.0: [5.0, -2.5], 4.0: [1.0, 1.0]})


if __name__ == "__main__":
    unittest.main()
