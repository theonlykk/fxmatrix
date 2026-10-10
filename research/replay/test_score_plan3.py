"""Tests for score_plan3.py (hand-derived; run: python -B -m unittest test_score_plan3).

Plan 3 s3 (docs/research/replay-calibration-eurusd-3.md): per fleet and side the free-run
counts S (scalps, rolled false), R (scalps, rolled true) and A (ROLL_ACCEPTED) after a cut;
a side is OUT when any |replay - real| > tol; FAIL on two OUT sides or any count beyond
2 x tol; bias FAIL when the signed S error has one sign (a zero breaks it) on all scoreable
sides and |sum| > 5% of the real S; difference FAIL when |live C-B or D-B| > the larger tol
of the two fleets and the replay's difference is zero or of the other sign; a side with
fewer than 10 real S is not scoreable; fewer than four scoreable sides: INCONCLUSIVE.
"""
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import score_plan3 as sp  # noqa: E402


def tol_all(v):
    return {(f, s, k): v for f in "BCD" for s in "LS" for k in "SRA"}


def counts(base, **over):
    """{(fleet, side): {'real': {S,R,A}, 'rep': {S,R,A}}}; base real = rep = base."""
    out = {}
    for f in "BCD":
        for s in "LS":
            out[(f, s)] = {"real": dict(base), "rep": dict(base)}
    for key, val in over.items():                 # e.g. B_L_rep_S=24
        f, s, who, k = key.split("_")
        out[(f, s)][who][k] = val
    return out


BASE = {"S": 20, "R": 4, "A": 5}


class CountsMark(unittest.TestCase):
    def test_all_equal_passes(self):
        r = sp.score(counts(BASE), tol_all(3.0))
        self.assertEqual(r["counts"]["out_sides"], [])
        self.assertEqual(r["verdict"], "PASS")

    def test_one_side_out_passes(self):
        r = sp.score(counts(BASE, B_L_rep_S=24), tol_all(3.0))     # |24 - 20| = 4 > 3
        self.assertEqual(r["counts"]["out_sides"], [("B", "L")])
        self.assertEqual(r["verdict"], "PASS")

    def test_two_sides_out_fails(self):
        r = sp.score(counts(BASE, B_L_rep_S=24, C_S_rep_R=0), tol_all(3.0))   # |0 - 4| = 4 > 3
        self.assertEqual(sorted(r["counts"]["out_sides"]), [("B", "L"), ("C", "S")])
        self.assertEqual(r["verdict"], "FAIL")

    def test_one_count_beyond_twice_fails(self):
        r = sp.score(counts(BASE, D_S_rep_A=12), tol_all(3.0))     # |12 - 5| = 7 > 6
        self.assertEqual(r["counts"]["beyond_2x"], [("D", "S", "A")])
        self.assertEqual(r["verdict"], "FAIL")

    def test_exactly_at_tolerance_is_in(self):
        r = sp.score(counts(BASE, B_L_rep_S=23), tol_all(3.0))     # |3| <= 3
        self.assertEqual(r["counts"]["out_sides"], [])


class BiasMark(unittest.TestCase):
    def test_one_sign_over_five_percent_fails(self):
        over = {"%s_%s_rep_S" % (f, s): 22 for f in "BCD" for s in "LS"}   # +2 x 6 = +12 of 120: 10%
        r = sp.score(counts(BASE, **over), tol_all(3.0))
        self.assertTrue(r["bias"]["fail"])
        self.assertEqual(r["verdict"], "FAIL")

    def test_a_zero_breaks_one_sign(self):
        over = {"%s_%s_rep_S" % (f, s): 22 for f in "BCD" for s in "LS"}
        over["D_S_rep_S"] = 20                                      # 0 on one side
        r = sp.score(counts(BASE, **over), tol_all(3.0))
        self.assertFalse(r["bias"]["fail"])

    def test_one_sign_under_five_percent_passes(self):
        over = {"%s_%s_rep_S" % (f, s): 21 for f in "BCD" for s in "LS"}   # +6 of 120: 5.0%, not more
        r = sp.score(counts(BASE, **over), tol_all(3.0))
        self.assertFalse(r["bias"]["fail"])


class DifferenceMark(unittest.TestCase):
    def test_reversed_large_difference_fails(self):
        c = counts(BASE, C_L_real_S=28, C_L_rep_S=19)               # live C-B +8, replay -1
        r = sp.score(c, tol_all(3.0))
        self.assertIn(("L", "S", "C"), r["difference"]["fails"])
        self.assertEqual(r["verdict"], "FAIL")

    def test_zero_replay_difference_fails(self):
        c = counts(BASE, D_S_real_R=9)                              # live D-B +5 > 3, replay 0
        r = sp.score(c, tol_all(3.0))
        self.assertIn(("S", "R", "D"), r["difference"]["fails"])

    def test_small_live_difference_is_not_scored(self):
        c = counts(BASE, C_L_real_S=23, C_L_rep_S=17)               # live +3 = limit, not more
        r = sp.score(c, tol_all(3.0))
        self.assertNotIn(("L", "S", "C"), r["difference"]["fails"])

    def test_limit_is_the_larger_tol(self):
        tol = tol_all(3.0)
        tol[("C", "L", "S")] = 9.0                                  # live +8 <= 9: not scored
        c = counts(BASE, C_L_real_S=28, C_L_rep_S=19)
        r = sp.score(c, tol)
        self.assertNotIn(("L", "S", "C"), r["difference"]["fails"])


class Scoreable(unittest.TestCase):
    def test_side_under_ten_real_s_is_left_out(self):
        c = counts(BASE, B_L_real_S=9, B_L_rep_S=30)               # would be beyond 2 x tol
        r = sp.score(c, tol_all(3.0))
        self.assertNotIn(("B", "L"), r["scoreable"])
        self.assertEqual(r["counts"]["beyond_2x"], [])
        self.assertEqual(r["verdict"], "PASS")

    def test_fewer_than_four_scoreable_is_inconclusive(self):
        c = counts(BASE, B_L_real_S=5, B_S_real_S=5, C_L_real_S=5)
        r = sp.score(c, tol_all(3.0))
        self.assertEqual(len(r["scoreable"]), 3)
        self.assertEqual(r["verdict"], "INCONCLUSIVE")


class TimeCut(unittest.TestCase):
    def test_counts_after_cut_only(self):
        scalps = [{"t": 100, "side": "L", "rolled": False}, {"t": 200, "side": "L", "rolled": False},
                  {"t": 200, "side": "S", "rolled": True}, {"t": 50, "side": "S", "rolled": True}]
        rolls = [{"t": 199, "side": "L"}, {"t": 201, "side": "L"}]
        c = sp.side_counts(scalps, rolls, cut_ms=200)
        self.assertEqual(c["L"], {"S": 1, "R": 0, "A": 1})
        self.assertEqual(c["S"], {"S": 0, "R": 1, "A": 0})

    def test_no_cut_counts_all(self):
        scalps = [{"t": 1, "side": "L", "rolled": False}]
        self.assertEqual(sp.side_counts(scalps, [], cut_ms=None)["L"]["S"], 1)

    def test_t1_after_cut(self):
        # four real deals (two before the cut), three replay deals; matching over all
        reals = [{"seg": 1, "t": 0, "side": "L", "role": "ENT", "layer": 0, "pts": 100},
                 {"seg": 1, "t": 10, "side": "L", "role": "EXT", "layer": 0, "pts": 110},
                 {"seg": 1, "t": 1000, "side": "S", "role": "ENT", "layer": 0, "pts": 200},
                 {"seg": 1, "t": 2000, "side": "S", "role": "EXT", "layer": 0, "pts": 190}]
        reps = [{"seg": 1, "t": 1, "side": "L", "role": "ENT", "layer": 0, "pts": 100},
                {"seg": 1, "t": 1001, "side": "S", "role": "ENT", "layer": 0, "pts": 200},
                {"seg": 1, "t": 1500, "side": "S", "role": "ENT", "layer": 1, "pts": 210}]
        touch = [True, True, True, False]
        r = sp.t1_after(reals, reps, touch, cut_ms=1000)
        self.assertEqual((r["real"], r["touch"], r["matched_touch"], r["replay_only"]), (2, 1, 1, 1))


if __name__ == "__main__":
    unittest.main()
