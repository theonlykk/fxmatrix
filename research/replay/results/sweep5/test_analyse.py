"""Tests for sweep5's pre-registered marks (sweep_notes, 11 Oct ~19:30Z)."""
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import analyse as an  # noqa: E402


class Marks(unittest.TestCase):
    def test_d2_class(self):
        self.assertEqual(an.d2_class(26), "BETTER")
        self.assertEqual(an.d2_class(25), "NO DIFFERENCE")
        self.assertEqual(an.d2_class(15), "NO DIFFERENCE")
        self.assertEqual(an.d2_class(14), "WORSE")

    def test_verdict(self):
        self.assertTrue(an.beats_carrying(["BETTER"] * 5 + ["WORSE"] + ["NO DIFFERENCE"] * 3))
        self.assertFalse(an.beats_carrying(["BETTER"] * 5 + ["WORSE"] * 2 + ["NO DIFFERENCE"] * 2))
        self.assertFalse(an.beats_carrying(["BETTER"] * 4 + ["NO DIFFERENCE"] * 5))

    def test_week_of(self):
        self.assertEqual(an.week_of("2026-08-07"), "2026-08-03")
        self.assertEqual(an.week_of("2026-08-10"), "2026-08-10")

    def test_wins_strict(self):
        # a tie is not a win
        self.assertEqual(an.wins({("s", "w1"): 5.0, ("s", "w2"): 1.0}, {("s", "w1"): 5.0, ("s", "w2"): 0.0}), 1)


if __name__ == "__main__":
    unittest.main()
