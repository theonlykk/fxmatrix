"""Hand-valued tests for score10.py, the sweep10 scorer (run: python -B test_score10.py from this folder).

The rule (sweep_notes sweep10, the operator 22 Oct ~04:50Z), per pair, from the daily equity curves (pips at 0.01
lots, one flat start 1 Oct carried to 20 Oct):
- OFFSET at E's q88 ALT add: OPT + ALT ends above OPT alone AND its worst point is no lower than OPT alone's.
- RETUNE: only if OPT + ALT at q88 ends NEGATIVE while two ADJACENT cells of the ALT grid (by add) both end
  POSITIVE; then to the lower-middle add of the longest run of positive cells (ties: the larger summed net).
- DUP = OPT + 2 x ALT, reported the same way; the daily offset ratio reported, never deciding.
Every expected value below is worked by hand from the curves written here.
"""
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import score10 as s10  # noqa: E402

OPT = [0.0, -10.0, -30.0, -20.0]          # net -20, worst -30


def grid(**alts):
    """names in add order -> curves"""
    return {("a%de%dn7" % (a, a)): c for a, c in alts.items()}


def curves(alts):
    c = {"a4e4n7": OPT}
    c.update(alts)
    return c


class Combine(unittest.TestCase):
    def test_sum_and_dup(self):
        self.assertEqual(s10.combine(OPT, [0.0, 5.0, 10.0, 15.0]), [0.0, -5.0, -20.0, -5.0])
        self.assertEqual(s10.combine(OPT, [0.0, 5.0, 10.0, 15.0], 2), [0.0, 0.0, -10.0, 10.0])


class Decide(unittest.TestCase):
    # comb nets: a10 -5, a12 +10 (worst -5), a14 +15, a16 (q88) -15 (worst -30), a18 +5
    BASE = {10: [0.0, 5.0, 10.0, 15.0], 12: [0.0, 10.0, 25.0, 30.0], 14: [0.0, 8.0, 30.0, 35.0],
            16: [0.0, -5.0, 0.0, 5.0], 18: [0.0, 0.0, 5.0, 25.0]}

    def run_(self, over=None, q=16):
        alts = dict(self.BASE)
        alts.update(over or {})
        names = ["a%de%dn7" % (a, a) for a in sorted(alts)]
        c = curves({("a%de%dn7" % (a, a)): v for a, v in alts.items()})
        return s10.decide(c, "a4e4n7", names, "a%de%dn7" % (q, q))

    def test_offset_yes_and_retune_to_lower_middle_of_the_longest_positive_run(self):
        d = self.run_()
        self.assertTrue(d["offset"])                 # -15 > -20 and worst -30 >= -30
        self.assertTrue(d["retune"])                 # q88 -15 < 0; a12, a14 adjacent and positive
        self.assertEqual(d["to"], 12.0)              # run [12, 14]: lower middle 12
        self.assertEqual(d["cells"]["a12e12n7"]["comb_net"], 10.0)
        self.assertEqual(d["cells"]["a12e12n7"]["comb_worst"], -5.0)
        self.assertEqual(d["cells"]["a16e16n7"]["dup_net"], -10.0)    # -20 + 2 x 5
        self.assertEqual(d["cells"]["a16e16n7"]["dup_worst"], -30.0)  # [0, -20, -30, -10]

    def test_keep_when_q88_ends_non_negative(self):
        d = self.run_({16: [0.0, 10.0, 25.0, 25.0]})   # comb +5
        self.assertFalse(d["retune"])
        self.assertIsNone(d["to"])

    def test_keep_when_no_two_adjacent_positive_cells(self):
        d = self.run_({14: [0.0, 0.0, 0.0, 10.0]})     # comb a14 -10: positives a12, a18 isolated
        self.assertFalse(d["retune"])
        self.assertIsNone(d["to"])

    def test_offset_no_when_alt_loses(self):
        self.assertFalse(self.run_({16: [0.0, -5.0, -5.0, -5.0]})["offset"])   # comb -25 < -20

    def test_offset_no_when_worst_lower(self):
        self.assertFalse(self.run_({16: [0.0, -1.0, -1.0, 5.0]})["offset"])    # comb worst -31 < -30

    def test_tie_on_length_takes_the_larger_summed_net(self):
        # q88 = 14 negative; runs [10, 12] comb +1, +1 and [16, 18] comb +5, +5 -> 16
        over = {10: [0.0, 0.0, 0.0, 21.0], 12: [0.0, 0.0, 0.0, 21.0], 14: [0.0, 0.0, 0.0, 0.0],
                16: [0.0, 0.0, 0.0, 25.0], 18: [0.0, 0.0, 0.0, 25.0]}
        d = self.run_(over, q=14)
        self.assertTrue(d["retune"])
        self.assertEqual(d["to"], 16.0)

    def test_lower_middle_of_three_and_four(self):
        self.assertEqual(s10.lower_middle([10.0, 12.0, 14.0]), 12.0)
        self.assertEqual(s10.lower_middle([10.0, 12.0, 14.0, 16.0]), 12.0)
        self.assertEqual(s10.lower_middle([10.0, 12.0]), 10.0)


class Equity(unittest.TestCase):
    def test_commission_per_pair_from_the_sweep_set(self):
        self.assertAlmostEqual(s10.comm_for("audcad"), 0.06 / 0.0714)
        self.assertAlmostEqual(s10.comm_for("gbpusd"), 0.6)

    def test_curve_uses_the_pairs_commission_and_swap(self):
        # a long opened at 1.00000 (t 1000), closed at 1.00100 (t 2000, OUT): +10.0 pips; one scalp at t 2000:
        # - 0.06 / 0.0714 = -0.840336; a snapshot at t 1500 with the long open: -5 points x 1 / 10 = -0.5.
        pos = [[1, 1000, 1.00000, 2000, 1.00100, 1.0]]
        c = s10.curve(pos, [2000], [(1500, -5.0, 3.0, 1)], [3000], lambda t: (1.0, 1.0), s10.comm_for("audcad"))
        self.assertEqual(c[0], 0.0)
        self.assertAlmostEqual(c[1], 10.0 - 0.06 / 0.0714 - 0.5, places=6)


class Report(unittest.TestCase):
    def test_report_names_the_decision(self):
        alts = Decide.BASE
        names = ["a%de%dn7" % (a, a) for a in sorted(alts)]
        c = curves({("a%de%dn7" % (a, a)): v for a, v in alts.items()})
        info = {n: {"S": 0, "R": 0, "A": 0, "snaps": 0, "ends": [1, 2, 3]} for n in c}
        text = s10.report("TESTPAIR", c, info, "a4e4n7", names, "a16e16n7")
        self.assertIn("OFFSET at q88 (16): YES", text)
        self.assertIn("RETUNE: YES -> 12", text)


if __name__ == "__main__":
    unittest.main()
