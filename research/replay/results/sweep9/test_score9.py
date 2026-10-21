"""Tests for score9.py (hand-derived; run: python -B -m unittest test_score9 from this folder).

The sweep9 scorer (sweep_notes sweep9; docs/research/two-arm-viability-2026-10-21.md s5): from a run's deals and
events and the ticks, a DAILY equity curve per segment in pips at 0.01 lots:
equity(T) = sum over positions opened by T of dir x (close or mark - open) - 0.6 x scalps closed by T + swap by T.
Each position closes at its own OUT / OUT_BY deal's price; open ones are marked at the last tick before T (a long at
bid, a short at ask). Swap: at each CARRY_SNAPSHOT, every open position earns swap_long / swap_short x multiplier
points (10 points a pip). The offset ratio of an ALT curve against an OPT curve = (ALT's P&L on OPT's losing days) /
-(OPT's P&L on those days); None when OPT has no losing day.
"""
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import score9 as s9  # noqa: E402

D = 86400000
T0 = 1790827200000          # Thu 1 Oct 04:00 server, read as UTC


def deal(seg, t, pos, entry, dtype, price):
    return {"seg_id": str(seg), "time_ms": str(t), "position": str(pos), "entry_type": str(entry),
            "deal_type": str(dtype), "price": "%.5f" % price}


class Positions(unittest.TestCase):
    def test_scalp_by_close_by(self):
        # long ENT bought 1.15506; EXT sell opened 1.15583; close-by: each OUT_BY leg carries the OTHER position's
        # entry price (02_TRAPS): the short closes at 1.15506 (+7.7), the long at 1.15583 (+7.7); each counts
        # half: realised +7.7 pips. (Corrected 21 Oct ~23:00Z: the first version had the long close at its own
        # price; the cross-check against sweep8's scores found it, before any sweep9 output was read.)
        ds = [deal(1, 100, 1, 0, 0, 1.15506), deal(1, 200, 2, 0, 1, 1.15583),
              deal(1, 201, 2, 3, 0, 1.15506), deal(1, 201, 1, 3, 1, 1.15583)]
        pos = s9.positions(ds)[1]
        self.assertEqual(len(pos), 2)
        self.assertAlmostEqual(s9.equity_at(pos, [], [], 300, lambda t: (1.2, 1.2001), 0.0), 7.7, places=6)

    def test_open_long_marked_at_bid_short_at_ask(self):
        ds = [deal(1, 100, 1, 0, 0, 1.10000), deal(1, 100, 2, 0, 1, 1.10100)]
        pos = s9.positions(ds)[1]
        # bid 1.10050, ask 1.10060: long +5.0, short +4.0
        self.assertAlmostEqual(s9.equity_at(pos, [], [], 500, lambda t: (1.10050, 1.10060), 0.0), 9.0, places=6)

    def test_position_not_yet_opened_or_already_closed(self):
        ds = [deal(1, 100, 1, 0, 0, 1.10000), deal(1, 400, 1, 1, 1, 1.10070)]
        pos = s9.positions(ds)[1]
        mk = lambda t: (1.10020, 1.10030)
        self.assertAlmostEqual(s9.equity_at(pos, [], [], 50, mk, 0.0), 0.0, places=6)
        self.assertAlmostEqual(s9.equity_at(pos, [], [], 300, mk, 0.0), 2.0, places=6)
        self.assertAlmostEqual(s9.equity_at(pos, [], [], 500, mk, 0.0), 7.0, places=6)

    def test_commission_per_scalp_closed_by_t(self):
        ds = [deal(1, 100, 1, 0, 0, 1.10000), deal(1, 200, 1, 1, 1, 1.10070)]
        pos = s9.positions(ds)[1]
        self.assertAlmostEqual(s9.equity_at(pos, [150, 200], [], 300, lambda t: (1.1, 1.1), 0.6), 7.0 - 1.2, places=6)
        self.assertAlmostEqual(s9.equity_at(pos, [150, 200], [], 160, lambda t: (1.1, 1.1), 0.6), -0.6, places=6)

    def test_swap_on_positions_open_at_the_snapshot(self):
        ds = [deal(1, 100, 1, 0, 0, 1.10000), deal(1, 100, 2, 0, 1, 1.10000), deal(1, 1000, 2, 1, 0, 1.10000)]
        pos = s9.positions(ds)[1]
        snaps = [(500, -8.0, 1.5, 1), (2000, -8.0, 1.5, 3)]
        # t=500: long -0.80, short +0.15; t=2000 (x3): the long only, -2.40; marks flat at 1.10000
        self.assertAlmostEqual(s9.equity_at(pos, [], snaps, 3000, lambda t: (1.1, 1.1), 0.0), -0.80 + 0.15 - 2.40, places=6)
        self.assertAlmostEqual(s9.equity_at(pos, [], snaps, 600, lambda t: (1.1, 1.1), 0.0), -0.65, places=6)


class Days(unittest.TestCase):
    def test_day_ends_are_server_midnights_within_the_window(self):
        ends = s9.day_ends(T0, T0 + 2 * D + 5 * 3600000)
        self.assertEqual(ends, [T0 + 20 * 3600000, T0 + 44 * 3600000, T0 + 2 * D + 5 * 3600000])

    def test_daily_pnl(self):
        self.assertEqual(s9.daily([0.0, 5.0, 2.0, 2.5]), [5.0, -3.0, 0.5])


class Offset(unittest.TestCase):
    def test_ratio_on_opts_losing_days(self):
        opt = [-10.0, 5.0, -30.0, 2.0]
        alt = [4.0, -100.0, 6.0, 9.0]
        self.assertAlmostEqual(s9.offset_ratio(opt, alt), 10.0 / 40.0)

    def test_negative_when_alt_loses_with_opt(self):
        self.assertAlmostEqual(s9.offset_ratio([-10.0, -10.0], [-1.0, -3.0]), -0.2)

    def test_none_without_a_losing_day(self):
        self.assertIsNone(s9.offset_ratio([1.0, 0.0], [5.0, 5.0]))

    def test_subset_of_days(self):
        opt = [-10.0, 5.0, -30.0, 2.0]
        alt = [4.0, -100.0, 6.0, 9.0]
        self.assertAlmostEqual(s9.offset_ratio(opt, alt, [2, 3]), 6.0 / 30.0)

    def test_meaningful(self):
        self.assertTrue(s9.meaningful(0.25, 0.1, 0.01))
        self.assertFalse(s9.meaningful(0.24, 0.5, 0.5))
        self.assertFalse(s9.meaningful(0.5, 0.5, 0.0))
        self.assertFalse(s9.meaningful(0.5, None, 0.5))

    def test_dup_doubles_the_ratio(self):
        opt = [-10.0, 5.0, -30.0]
        alt = [4.0, -1.0, 6.0]
        self.assertAlmostEqual(s9.offset_ratio(opt, [2 * x for x in alt]), 2 * s9.offset_ratio(opt, alt))


class Bursts(unittest.TestCase):
    def test_burst_day_indices(self):
        ends = s9.day_ends(T0, T0 + 19 * D + 19 * 3600000 + 45 * 60000)
        idx = s9.burst_days(ends)
        # day 0 = Thu 1 Oct; 1-7 Oct = indices 0..6, 14-16 Oct = 13..15 (server calendar days)
        self.assertEqual(idx["b1"], [0, 1, 2, 3, 4, 5, 6])
        self.assertEqual(idx["b2"], [13, 14, 15])


if __name__ == "__main__":
    unittest.main()
