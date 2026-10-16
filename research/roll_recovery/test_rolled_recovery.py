"""Tests for rolled_recovery.py (hand values). Run: python -m unittest research/roll_recovery/test_rolled_recovery.py"""
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rolled_recovery as rr  # noqa: E402

H = 3600 * 1000  # one hour in ms


def fill(msc, px, et):
    return {"table": "fill_logs", "entry_type": et, "deal_price": px, "deal_time_broker_msc": msc}


def rolled(close_broker, entry, exit_, direction="SHORT"):
    return {"table": "scalp_history", "rolled": True, "direction": direction, "entry_price": entry,
            "exit_price": exit_, "close_time_broker": close_broker, "broker_utc_offset_s": 10800}


class T(unittest.TestCase):
    def setUp(self):
        import datetime as dt
        self.b0 = int((dt.datetime(2026, 10, 16, 0, 0, 0) - dt.datetime(1970, 1, 1)).total_seconds() * 1000)

    def test_path_excludes_out_by(self):
        rows = [fill(self.b0, 1.3300, "IN"), fill(self.b0 + H, 1.3145, "OUT_BY"), fill(self.b0 + 2 * H, 1.3310, "OUT")]
        self.assertEqual([px for _, px in rr.market_path(rows)], [1.3300, 1.3310])

    def test_short_recovers_at_entry(self):
        # short entered 1.3200, rolled close at 1.3330 at 01:00 broker; price later 1.3250 (02:00), 1.3199 (05:00)
        rows = [fill(self.b0 + 2 * H, 1.3250, "IN"), fill(self.b0 + 5 * H, 1.3199, "IN")]
        r = rolled("2026-10-16 01:00:00", 1.3200, 1.3330)
        h, best = rr.recovery(r, rr.market_path(rows))
        self.assertAlmostEqual(h, 4.0)          # 05:00 - 01:00
        self.assertAlmostEqual(best, 1.3199)
        self.assertAlmostEqual(rr.close_pips(r), -130.0)

    def test_long_not_recovered(self):
        rows = [fill(self.b0 + 2 * H, 1.3250, "IN"), fill(self.b0 + 3 * H, 1.3280, "OUT")]
        r = rolled("2026-10-16 01:00:00", 1.3300, 1.3240, "LONG")
        h, best = rr.recovery(r, rr.market_path(rows))
        self.assertIsNone(h)
        self.assertAlmostEqual(best, 1.3280)
        self.assertAlmostEqual(rr.close_pips(r), -60.0)

    def test_a_close_by_at_the_entry_does_not_count_as_recovery(self):
        # the OUT_BY row carries the short's own entry price: it must not read as the market there
        rows = [fill(self.b0 + 2 * H, 1.3200, "OUT_BY"), fill(self.b0 + 3 * H, 1.3260, "IN")]
        r = rolled("2026-10-16 01:00:00", 1.3200, 1.3330)
        h, _ = rr.recovery(r, rr.market_path(rows))
        self.assertIsNone(h)


if __name__ == "__main__":
    unittest.main()
