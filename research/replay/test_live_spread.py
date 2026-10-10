"""Tests for live_spread.py (hand-derived; run: python -B -m unittest test_live_spread)."""
import json
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import live_spread as ls  # noqa: E402


def row(direction, close, rolled, rid):
    return json.dumps({"table": "scalp_history", "id": rid, "received_at": "x%d" % rid,
                       "direction": direction, "close_time_broker": close, "rolled": rolled,
                       "entry_price": 1.1, "exit_price": 1.2})


class Tests(unittest.TestCase):
    def test_counts_split_by_side_and_rolled_and_dedupe(self):
        lines = [row("LONG", "2026-10-01 10:00:00", False, 1),
                 row("LONG", "2026-10-01 10:00:00", False, 2),   # the same close twice: one
                 row("SHORT", "2026-10-01 11:00:00", True, 3),
                 row("LONG", "2026-10-02 09:00:00", True, 4),
                 json.dumps({"table": "fill_logs", "id": 5})]
        c = ls.daily_scalps(lines)
        self.assertEqual(c[("2026-10-01", "L", "S")], 1)
        self.assertEqual(c[("2026-10-01", "S", "R")], 1)
        self.assertEqual(c[("2026-10-02", "L", "R")], 1)
        self.assertEqual(sum(c.values()), 3)

    def test_rolls_by_server_day(self):
        # 1790898000000 = 2026-10-01 23:40:00 (server ms read as UTC); +3,600,000 = 2 Oct 00:40
        rows = [{"kind": "ROLL", "side": "L", "time_ms": "1790898000000"},
                {"kind": "ROLL", "side": "L", "time_ms": "1790901600000"},
                {"kind": "ENT", "side": "L", "time_ms": "1790898000000"}]
        c = ls.daily_rolls(rows)
        self.assertEqual(c[("2026-10-01", "L", "A")], 1)
        self.assertEqual(c[("2026-10-02", "L", "A")], 1)
        self.assertEqual(sum(c.values()), 2)

    def test_tolerance(self):
        # sd 6.0, n 3: 6 * 1.7320508 / 3 = 3.4641; sd 1.0: 0.577 -> the floor 2
        self.assertAlmostEqual(ls.tolerance(6.0, 3), 3.4641016, places=6)
        self.assertEqual(ls.tolerance(1.0, 3), 2.0)

    def test_table_uses_every_day_including_zeros(self):
        days = ("d1", "d2", "d3")
        c = {("d1", "L", "S"): 2, ("d2", "L", "S"): 4}          # d3 missing = 0: [2, 4, 0], sd 2
        t = {(s, k): (v, sd, tol) for s, k, v, sd, tol in ls.table(c, 3, days)}
        v, sd, tol = t[("L", "S")]
        self.assertEqual(v, [2, 4, 0])
        self.assertAlmostEqual(sd, 2.0)
        self.assertEqual(tol, 2.0)                                # 2 * 1.732 / 3 = 1.15 -> floor


if __name__ == "__main__":
    unittest.main()
