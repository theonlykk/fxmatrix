"""C125 verdict tests: expected values derived by hand (exact bootstrap tail
probabilities computed by enumerating every resample, in the comments)."""
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import holdout_verdict as hv  # noqa: E402


class TestVerdict(unittest.TestCase):
    def test_V1_every_day_up_is_supported(self):
        # [10, 20, 30, 40]: no resample has a mean <= 0 (the smallest is 10): lower bound > 0
        r = hv.verdict([10.0, 20.0, 30.0, 40.0])
        self.assertEqual((r["n"], r["total"], r["mean"]), (4, 100.0, 25.0))
        self.assertGreater(r["lb"], 0.0)
        self.assertEqual(r["verdict"], "SUPPORTED")

    def test_V2_total_down_is_not_supported(self):
        # [-40, 10, 10, 10]: total -10 <= 0
        self.assertEqual(hv.verdict([-40.0, 10.0, 10.0, 10.0])["verdict"], "NOT SUPPORTED")

    def test_V3_up_but_not_convincing_is_inconclusive(self):
        # [-30, 10, 10, 20]: total +10 > 0, but P(resampled sum <= 0) = 0.3867 (exact, 4^4 resamples)
        # > 0.025, so the 2.5% quantile is <= 0
        r = hv.verdict([-30.0, 10.0, 10.0, 20.0])
        self.assertLessEqual(r["lb"], 0.0)
        self.assertEqual(r["verdict"], "INCONCLUSIVE")

    def test_V4_total_exactly_zero_is_not_supported(self):
        self.assertEqual(hv.verdict([-10.0, 10.0])["verdict"], "NOT SUPPORTED")

    def test_V5_the_one_extension(self):
        w1 = [-30.0, 10.0, 10.0, 20.0]                      # INCONCLUSIVE (V3)
        # decided week 1 stands: the extension is not used
        self.assertEqual(hv.final([10.0, 20.0, 30.0, 40.0], [-99.0])["verdict"], "SUPPORTED")
        self.assertEqual(hv.final([-40.0, 10.0, 10.0, 10.0], [99.0])["verdict"], "NOT SUPPORTED")
        # pooled 8 days, still not convincing (exact P(sum <= 0) = 0.348): NOT SUPPORTED, no third week
        r = hv.final(w1, [-30.0, 10.0, 10.0, 20.0])
        self.assertEqual((r["n"], r["verdict"]), (8, "NOT SUPPORTED"))
        # pooled with four +40 days: exact P(sum <= 0) = 0.0111 < 0.025: SUPPORTED
        r = hv.final(w1, [40.0, 40.0, 40.0, 40.0])
        self.assertEqual((r["n"], r["verdict"]), (8, "SUPPORTED"))
        # week 1 inconclusive and no week 2 yet: INCONCLUSIVE (extend)
        self.assertEqual(hv.final(w1)["verdict"], "INCONCLUSIVE")

    def test_V6_days_by_their_start(self):
        # day d starts at d * 86400 + 79200 (22:00Z); window 1970-01-05T22:00Z .. 1970-01-09T21:00Z
        # = starts 4 x 86400 + 79200 .. 8 x 86400 + 75600: days 4, 5, 6, 7 in, 3 and 8 out
        days = [dict(day=d) for d in range(3, 9)]
        got = hv.in_window(days, ("1970-01-05T22:00Z", "1970-01-09T21:00Z"))
        self.assertEqual([d["day"] for d in got], [4, 5, 6, 7])


if __name__ == "__main__":
    unittest.main()
