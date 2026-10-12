"""Tests for analyse.py: sweep6's pre-registered marks (sweep_notes, 12 Oct; hand-derived)."""
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import analyse as an  # noqa: E402


class Marks(unittest.TestCase):
    def test_e1_classes(self):
        # weekly median paired difference (table - off); BETTER if > 0 in >= 6 of 8 weeks
        self.assertEqual(an.e1_class([1, 2, 3, 4, 5, 6, -1, -2]), "BETTER")
        self.assertEqual(an.e1_class([-1, -2, -3, -4, -5, -6, 1, 0]), "WORSE")
        self.assertEqual(an.e1_class([1, 1, 1, 1, 1, -1, -1, -1]), "NO DIFFERENCE")    # 5 of 8
        self.assertEqual(an.e1_class([0] * 8), "NO DIFFERENCE")                         # zero is neither

    def test_e2_verdict(self):
        # per table: HELPS if >= 5 of 9 pairs BETTER and <= 1 WORSE; HURTS if >= 5 WORSE and <= 1 BETTER
        self.assertEqual(an.e2_verdict(["BETTER"] * 5 + ["WORSE"] + ["NO DIFFERENCE"] * 3), "HELPS")
        self.assertEqual(an.e2_verdict(["BETTER"] * 5 + ["WORSE"] * 2 + ["NO DIFFERENCE"] * 2), "NO VERDICT")
        self.assertEqual(an.e2_verdict(["WORSE"] * 6 + ["BETTER"] + ["NO DIFFERENCE"] * 2), "HURTS")
        self.assertEqual(an.e2_verdict(["NO DIFFERENCE"] * 9), "NO VERDICT")

    def test_weekly_median_difference(self):
        # three settings; differences per setting for two weeks; the median per week
        net = {("live", "off", "w1"): 10, ("live", "step", "w1"): 14,
               ("a", "off", "w1"): -5, ("a", "step", "w1"): -9,
               ("b", "off", "w1"): 0, ("b", "step", "w1"): 1,
               ("live", "off", "w2"): 3, ("live", "step", "w2"): 3,
               ("a", "off", "w2"): 7, ("a", "step", "w2"): 2,
               ("b", "off", "w2"): -1, ("b", "step", "w2"): -4}
        # w1 diffs 4, -4, 1 -> median 1; w2 diffs 0, -5, -3 -> median -3
        self.assertEqual(an.median_diffs(net, ("live", "a", "b"), "step", ("w1", "w2")), [1, -3])

    def test_control_check(self):
        # the off rows must equal sweep4's weekly nets for the same setting and week
        off = {("live", "w1"): 10.0, ("a7.5e7.5n8", "w1"): -5.0}
        s4 = {("live", "w1"): 10.0, ("a7.5e7.5n8", "w1"): -5.0, ("a5e5n10", "w1"): 99.0}
        self.assertEqual(an.control_mismatches(off, s4), [])
        off[("live", "w1")] = 10.1
        self.assertEqual(an.control_mismatches(off, s4), [("live", "w1", 10.1, 10.0)])


if __name__ == "__main__":
    unittest.main()
