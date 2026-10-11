"""Tests for analyse.py: sweep4's pre-registered marks (sweep_notes, 11 Oct ~15:10Z)."""
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import analyse as an  # noqa: E402


class Marks(unittest.TestCase):
    def test_q1_classes(self):
        self.assertEqual(an.q1_class([1, 2, 3, 4, 5, 6, -1, -2]), "persistently positive")   # 6 of 8 > 0
        self.assertEqual(an.q1_class([-1, -2, -3, -4, -5, -6, 1, 0]), "persistently negative")
        self.assertEqual(an.q1_class([1, 1, 1, 1, 1, -1, -1, -1]), "mixed")                 # 5 of 8
        self.assertEqual(an.q1_class([0, 0, 0, 0, 0, 0, 0, 0]), "mixed")                    # zero is neither

    def test_q2_top_half(self):
        # week medians for 9 pairs; top 4 by median (higher is better)
        med = {"A": 5, "B": 4, "C": 3, "D": 2, "E": 1, "F": 0, "G": -1, "H": -2, "I": -3}
        self.assertEqual(an.top_half(med), {"A", "B", "C", "D"})

    def test_q3_robust(self):
        # setting positive in >= 6 of 8 weeks on >= 5 of 9 pairs
        weekly = {p: [1] * 6 + [-1, -1] for p in "ABCDE"}
        weekly.update({p: [-1] * 8 for p in "FGHI"})
        self.assertTrue(an.robust(weekly))
        weekly["E"] = [1] * 5 + [-1] * 3
        self.assertFalse(an.robust(weekly))


if __name__ == "__main__":
    unittest.main()
