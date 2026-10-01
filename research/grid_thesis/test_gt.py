"""Hand-derived tests for the price-path helpers of gt_report.py."""
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gt_report as g  # noqa: E402


def bar(bid_h, bid_l, spread=0.0):
    # (bid high, bid low, ask high, ask low, open, close); open/close at the bid mid
    return (bid_h, bid_l, bid_h + spread, bid_l + spread, (bid_h + bid_l) / 2, (bid_h + bid_l) / 2)


class TestCycles(unittest.TestCase):
    def test_long_and_short_round_trips(self):
        # level 1.0, exit 0.1, no spread. Minute 0 touches 1.0 (long opens AND short opens),
        # minute 1 reaches 1.1 (long closes), minute 2 reaches 0.9 (short closes): 2 cycles.
        rows = [bar(1.0, 1.0), bar(1.1, 1.05), bar(0.95, 0.9)]
        self.assertEqual(g.cycles(rows, [1.0], 0.1), [2])

    def test_no_exit_in_the_fill_minute(self):
        # the whole move happens inside minute 0: nothing may close in the minute it filled
        rows = [bar(1.1, 0.9)]
        self.assertEqual(g.cycles(rows, [1.0], 0.1), [0])

    def test_ask_decides_a_buy(self):
        # bid low touches 1.0 but the ask (spread 0.02) stays above it: no long; the short opens
        # at bid high 1.05 >= 1.0 and closes when the ask low <= 0.9
        rows = [bar(1.05, 1.0, 0.02), bar(0.9, 0.85, 0.02)]
        self.assertEqual(g.cycles(rows, [1.0], 0.1), [1])


    def test_bid_touch_does_not_buy(self):
        # minute 0: the bid low touches 1.0 but the ask low is 1.02 -> no long (a short opens at
        # bid high 1.05); minute 1 rises to bid 1.12 (ask low 1.08): no long ever opened, so no
        # long round trip; the short never reaches 0.9. A buy filled on the bid would count 1.
        rows = [bar(1.05, 1.0, 0.02), bar(1.12, 1.06, 0.02)]
        self.assertEqual(g.cycles(rows, [1.0], 0.1), [0])


    def test_ask_touch_does_not_sell(self):
        # minute 0: bid high 0.99 < 1.0 <= ask high 1.01 -> no short (a long opens: ask low 0.97);
        # minute 1 falls to ask low 0.87: a short sold on the ask would close (1 cycle); the long
        # never reaches 1.1. Correct count 0.
        rows = [bar(0.99, 0.95, 0.02), bar(0.89, 0.85, 0.02)]
        self.assertEqual(g.cycles(rows, [1.0], 0.1), [0])


class TestConcAndZigzag(unittest.TestCase):
    def test_conc(self):
        # 10 levels: one with 10 cycles, nine with 1 -> total 19, top decile (1 level) 10/19
        tot, share, disp = g.conc([10] + [1] * 9)
        self.assertEqual(tot, 19)
        self.assertAlmostEqual(share, 10 / 19)
        # mean 1.9, population variance = (8.1^2 + 9 * 0.9^2) / 10 = 7.29 -> 7.29 / 1.9
        self.assertAlmostEqual(disp, 7.29 / 1.9)

    def test_zigzag_legs(self):
        # mid path 0 -> 10 -> 4 -> 12 with threshold 5: legs up 10, down 6, (last leg open)
        hi = [0, 10, 4, 12]
        lo = [0, 10, 4, 12]
        self.assertEqual(g.zigzag(hi, lo, 5), [10, 6])

    def test_zigzag_no_leg_before_the_first_swing(self):
        # 0 -> 3 -> -3 -> 4, threshold 5: the move 0 -> 3 is not a leg (under the threshold before
        # the first reversal); legs: down 3 -> -3 = 6 (closed by the rise to 4), last leg open
        self.assertEqual(g.zigzag([0, 3, -3, 4], [0, 3, -3, 4], 5), [6])

    def test_ladder_spacing(self):
        rows = [bar(1.0050, 1.0000)]
        lv = g.ladder(rows, 0.0001, 10, 0)
        self.assertTrue(all(abs((b - a) - 0.0010) < 1e-9 for a, b in zip(lv, lv[1:])))
        self.assertLessEqual(lv[0], 1.0000)
        self.assertGreaterEqual(lv[-1], 1.0050)


if __name__ == "__main__":
    unittest.main()
