"""Tests for build_swaps.py: the replay's swaps.csv from the archive's
CARRY_SNAPSHOT events (replay-calibration-eurusd.md s12; base prompt s3.2).

The rule was measured on 8 Oct ~19:50Z against every closed EURUSD ENT
position on B, C, D since 24 Sep (622 of 622 to the cent): the swap of the
rollover INTO server date D is the rate of the latest CARRY_SNAPSHOT before
D 00:00 server, times 3 into Thursday, 0 into Saturday and Sunday, 1 on
every other night (into Monday included). Expected values are derived by
hand in the comments, never read back.

    python -B -m unittest research/replay/test_build_swaps.py -v
"""
import datetime as dt
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_swaps as bs  # noqa: E402

OFF = dt.timedelta(hours=3)


def snap(utc, sl, ss):
    """One CARRY_SNAPSHOT as the archive holds it (received_at in UTC)."""
    return {"table": "ea_events", "code": "CARRY_SNAPSHOT",
            "received_at": utc + "+00:00",
            "detail": {"swap_long": sl, "swap_short": ss}}


class TestMultiplier(unittest.TestCase):
    def test_week(self):
        # 2026-10-05 is a Monday. Into Mon 1, Tue 1, Wed 1, Thu 3, Fri 1, Sat 0, Sun 0.
        got = [bs.multiplier(dt.date(2026, 10, 5) + dt.timedelta(days=i)) for i in range(7)]
        self.assertEqual(got, [1, 1, 1, 3, 1, 0, 0])


class TestRateFor(unittest.TestCase):
    def setUp(self):
        # Snapshots at 20:50Z = 23:50 server on Tue 6 Oct and Wed 7 Oct.
        self.snaps = bs.snapshots_server(
            [snap("2026-10-06 20:50:09", -8.067, 1.364),
             snap("2026-10-07 20:50:22", -8.051, 1.355)], OFF)

    def test_latest_before_midnight(self):
        # Into Wed 7 Oct 00:00 server: the Tue 23:50:09 snapshot.
        self.assertEqual(bs.rate_for(self.snaps, dt.date(2026, 10, 7)), (-8.067, 1.364))
        # Into Thu 8 Oct: the Wed 23:50:22 snapshot.
        self.assertEqual(bs.rate_for(self.snaps, dt.date(2026, 10, 8)), (-8.051, 1.355))

    def test_default_offset_is_three_hours(self):
        # GUARD-free check of the default: 20:50Z with no offset given = 23:50 server,
        # so it is the rate INTO the next day, not into the same day.
        s = bs.snapshots_server([snap("2026-10-06 20:50:09", -8.067, 1.364)])
        self.assertEqual(s[0][0], dt.datetime(2026, 10, 6, 23, 50, 9))

    def test_none_before_first(self):
        self.assertIsNone(bs.rate_for(self.snaps, dt.date(2026, 10, 6)))

    def test_snapshot_at_midnight_not_used(self):
        # A snapshot stamped exactly 00:00:00 server belongs to the NEW day.
        s = bs.snapshots_server([snap("2026-10-06 21:00:00", -1.0, 1.0),
                                 snap("2026-10-06 20:50:00", -8.0, 1.5)], OFF)
        self.assertEqual(bs.rate_for(s, dt.date(2026, 10, 7)), (-8.0, 1.5))


class TestRows(unittest.TestCase):
    def test_rows_and_csv(self):
        snaps = bs.snapshots_server(
            [snap("2026-10-06 20:50:09", -8.067, 1.364),
             snap("2026-10-07 20:50:22", -8.051, 1.355)], OFF)
        rows = bs.build_rows(snaps, dt.date(2026, 10, 7), dt.date(2026, 10, 10))
        # Wed 7: -8.067 x1; Thu 8: -8.051 x3; Fri 9: -8.051 x1 (latest); Sat 10: x0.
        self.assertEqual(rows, [("2026.10.07", -8.067, 1.364, 1),
                                ("2026.10.08", -8.051, 1.355, 3),
                                ("2026.10.09", -8.051, 1.355, 1),
                                ("2026.10.10", -8.051, 1.355, 0)])
        text = bs.to_csv(rows)
        self.assertTrue(text.startswith("server_date,points_long,points_short,mult\n"))
        self.assertIn("2026.10.08,-8.051,1.355,3\n", text)
        self.assertFalse(text.startswith("﻿"))   # no BOM (fix 3 Z2)

    def test_missing_rate_raises(self):
        snaps = bs.snapshots_server([snap("2026-10-06 20:50:09", -8.067, 1.364)], OFF)
        with self.assertRaises(ValueError):
            bs.build_rows(snaps, dt.date(2026, 10, 6), dt.date(2026, 10, 7))


class TestPredictSwap(unittest.TestCase):
    def test_hold_over_wednesday_night(self):
        # Long 0.01 opened Wed 7 Oct 10:00 server, closed Thu 8 Oct 09:00:
        # one rollover, into Thu: -8.051 x 3 x 0.01 = -0.24153.
        snaps = bs.snapshots_server([snap("2026-10-07 20:50:22", -8.051, 1.355)], OFF)
        got = bs.predict_swap(snaps, "L", dt.datetime(2026, 10, 7, 10), dt.datetime(2026, 10, 8, 9), 0.01)
        self.assertAlmostEqual(got, -0.24153, places=9)

    def test_weekend(self):
        # Short opened Fri 2 Oct 16:00 server, closed Mon 5 Oct 04:00: rollovers into
        # Sat (x0), Sun (x0), Mon (x1 at the latest rate 1.508): 1.508 x 0.01 = 0.01508.
        snaps = bs.snapshots_server([snap("2026-10-02 20:50:01", -8.232, 1.508)], OFF)
        got = bs.predict_swap(snaps, "S", dt.datetime(2026, 10, 2, 16), dt.datetime(2026, 10, 5, 4), 0.01)
        self.assertAlmostEqual(got, 0.01508, places=9)


if __name__ == "__main__":
    unittest.main()
