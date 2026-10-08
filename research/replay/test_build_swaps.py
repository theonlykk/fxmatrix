"""Tests for build_swaps.py: the replay's swaps.csv from the archive's
CARRY_SNAPSHOT events (replay-calibration-eurusd.md s12; base prompt s3.2).

The rule, measured EXACTLY (to the cent, no tolerance) on 8 Oct ~20:35Z
against every closed EURUSD ENT position on B, C, D since 24 Sep (626 of
626; HANDOFF s73): the rollover INTO server date D charges, per position and
per night, round(rate x mult x tick_value x volume, 2), where the rate is the
CARRY_SNAPSHOT NEAREST to D 00:00 server (ties: the earlier; none within 96 h
= no rate) and mult is 3 into Thursday, 0 into Saturday and Sunday, 1 on
every other night (into Monday included). The first model (the latest
snapshot before D 00:00, no per-night rounding) matched 600 of 626 exactly:
no snapshot on Mon 5 Oct night left it on Saturday's rate for the night into
Tue 6 Oct. Expected values are derived by hand in the comments.

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

    def test_none_beyond_96_hours(self):
        # The first snapshot is Tue 6 Oct 23:50:09 server. Into Sat 3 Oct 00:00: 95 h 50 min
        # away -> used; into Fri 2 Oct: 119 h 50 min -> None.
        self.assertEqual(bs.rate_for(self.snaps, dt.date(2026, 10, 3)), (-8.067, 1.364))
        self.assertIsNone(bs.rate_for(self.snaps, dt.date(2026, 10, 2)))

    def test_missing_evening_uses_nearest(self):
        # 8 Oct record: Sat 3 Oct 23:50 server 1.508, then none until an init on Tue 6 Oct
        # 01:38 server at 1.409. Into Tue 6 Oct: 24 h 10 min vs 1 h 38 min -> 1.409.
        # Into Mon 5 Oct: 24 h 10 min (Sat) vs 25 h 38 min (Tue) -> 1.508.
        s = bs.snapshots_server([snap("2026-10-03 20:50:03", -8.232, 1.508),
                                 snap("2026-10-05 22:38:02", -8.111, 1.409)], OFF)
        self.assertEqual(bs.rate_for(s, dt.date(2026, 10, 6)), (-8.111, 1.409))
        self.assertEqual(bs.rate_for(s, dt.date(2026, 10, 5)), (-8.232, 1.508))

    def test_tie_takes_the_earlier(self):
        # 23:00 server the evening before and 01:00 server after: both 1 h away.
        s = bs.snapshots_server([snap("2026-10-06 22:00:00", -1.0, 1.0),
                                 snap("2026-10-06 20:00:00", -8.0, 1.5)], OFF)
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
        # Into Fri 2 Oct: 119 h 50 min from the only snapshot -> no rate.
        snaps = bs.snapshots_server([snap("2026-10-06 20:50:09", -8.067, 1.364)], OFF)
        with self.assertRaises(ValueError):
            bs.build_rows(snaps, dt.date(2026, 10, 2), dt.date(2026, 10, 7))


class TestPredictSwap(unittest.TestCase):
    def test_hold_over_wednesday_night(self):
        # Long 0.01 opened Wed 7 Oct 10:00 server, closed Thu 8 Oct 09:00:
        # one rollover, into Thu: -8.051 x 3 x 0.01 = -0.24153 -> -0.24 (the archive's
        # one-night longs into Thu 8 Oct carry -0.24).
        snaps = bs.snapshots_server([snap("2026-10-07 20:50:22", -8.051, 1.355)], OFF)
        got = bs.predict_swap(snaps, "L", dt.datetime(2026, 10, 7, 10), dt.datetime(2026, 10, 8, 9), 0.01)
        self.assertAlmostEqual(got, -0.24, places=9)

    def test_weekend(self):
        # Short opened Fri 2 Oct 16:00 server, closed Mon 5 Oct 04:00: rollovers into
        # Sat (x0), Sun (x0), Mon (x1 at 1.508): 0.01508 -> 0.02 (archive: 0.02 on B, C, D).
        snaps = bs.snapshots_server([snap("2026-10-02 20:50:01", -8.232, 1.508)], OFF)
        got = bs.predict_swap(snaps, "S", dt.datetime(2026, 10, 2, 16), dt.datetime(2026, 10, 5, 4), 0.01)
        self.assertAlmostEqual(got, 0.02, places=9)

    def test_each_night_rounded(self):
        # Short opened Mon 5 Oct 10:00 server, closed Wed 7 Oct 09:00: into Tue 6 at 1.409
        # (the 01:38 init snapshot, nearest) 0.01409 -> 0.01; into Wed 7 at 1.364 0.01364 ->
        # 0.01; total 0.02 (archive: 0.02; one rounding of the sum, 0.02773, gives 0.03).
        snaps = bs.snapshots_server([snap("2026-10-03 20:50:03", -8.232, 1.508),
                                     snap("2026-10-05 22:38:02", -8.111, 1.409),
                                     snap("2026-10-06 20:50:05", -8.067, 1.364)], OFF)
        got = bs.predict_swap(snaps, "S", dt.datetime(2026, 10, 5, 10), dt.datetime(2026, 10, 7, 9), 0.01)
        self.assertAlmostEqual(got, 0.02, places=9)


if __name__ == "__main__":
    unittest.main()
