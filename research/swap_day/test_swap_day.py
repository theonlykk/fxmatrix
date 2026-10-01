"""Hand-derived tests for swap_day.py (server = GMT+3, rollover 21:00Z)."""
import datetime as dt
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from swap_day import pass_days, ratios   # noqa: E402


def z(y, mo, d, h, mi=0, s=0):
    return dt.datetime(y, mo, d, h, mi, s, tzinfo=dt.timezone.utc).timestamp()


class PassDays(unittest.TestCase):
    def test_wednesday_night(self):
        # 30 Sep 2026 is a Wednesday; 21:00Z = 1 Oct 00:00 server: priced by Wednesday's pass
        self.assertEqual(pass_days(z(2026, 9, 30, 20), z(2026, 9, 30, 22)), (2,))

    def test_no_rollover(self):
        self.assertEqual(pass_days(z(2026, 10, 1, 1), z(2026, 10, 1, 5)), ())

    def test_weekend(self):
        # Fri 2 Oct 20:00Z to Mon 5 Oct 01:00Z: midnights Fri 21Z, Sat 21Z, Sun 21Z
        self.assertEqual(pass_days(z(2026, 10, 2, 20), z(2026, 10, 5, 1)), (4, 5, 6))

    def test_monday_then_tuesday(self):
        self.assertEqual(pass_days(z(2026, 9, 28, 12), z(2026, 9, 30, 12)), (0, 1))

    def test_edges_strict(self):
        m = z(2026, 9, 30, 21)
        self.assertEqual(pass_days(m, m + 60), ())        # opened AT the midnight
        self.assertEqual(pass_days(m - 60, m), ())        # closed AT the midnight
        self.assertEqual(pass_days(m - 1, m + 1), (2,))

    def test_unknown_times(self):
        self.assertEqual(pass_days(None, z(2026, 9, 30, 22)), ())
        self.assertEqual(pass_days(z(2026, 9, 30, 22), z(2026, 9, 30, 20)), ())


class Ratios(unittest.TestCase):
    def test_against_mon_thu_median(self):
        rows = [
            ("B", "AUDCHF", "S", (0,), -0.10), ("B", "AUDCHF", "S", (3,), -0.12),
            ("B", "AUDCHF", "S", (0,), -0.11),          # baseline median -0.11
            ("B", "AUDCHF", "S", (2,), -0.33),          # 3.0
            ("B", "AUDCHF", "S", (1,), -0.11),          # 1.0
            ("C", "EURGBP", "L", (0,), -0.01),          # baseline below $0.03: dropped
            ("C", "EURGBP", "L", (2,), -0.03),
            ("A", "GBPUSD", "L", (2,), -0.30),          # no baseline: dropped
        ]
        out, med = ratios(rows)
        self.assertAlmostEqual(med[("B", "AUDCHF", "S")], -0.11)
        self.assertEqual([round(r, 6) for *_k, r in out[(2,)]], [3.0])
        self.assertEqual([round(r, 6) for *_k, r in out[(1,)]], [1.0])
        # Mon rows -0.10 and -0.11 over -0.11; the Thu row -0.12 over -0.11
        self.assertEqual(sorted(round(r, 6) for *_k, r in out[(0,)]), [0.909091, 1.0])
        self.assertEqual([round(r, 6) for *_k, r in out[(3,)]], [1.090909])
        self.assertNotIn(("C", "EURGBP", "L"), [k[:3] for v in out.values() for k in v])


if __name__ == "__main__":
    unittest.main()
