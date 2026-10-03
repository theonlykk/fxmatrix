"""Tests for disconnects.py (C104, 3 Oct): broker disconnects per terminal
from MT5 journal files (<data>/logs/YYYYMMDD.log, UTF-16 or UTF-8).
Expected values derived by hand.

    python -m unittest research/compass/test_disconnects.py -v
"""
import os
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import disconnects as dc  # noqa: E402

DAY = "\n".join([
    "HM\t0\t16:27:20.100\tTrades\t'53071896': buy limit 0.01 GBPUSD at 1.32781",
    "QK\t0\t16:27:29.512\tNetwork\t'53071896': connection to ICMarketsSC-Demo lost",
    "PE\t0\t16:27:33.764\tNetwork\t'53071896': authorized on ICMarketsSC-Demo through Access Server",
    "KS\t0\t16:27:34.649\tNetwork\t'53071896': terminal synchronized with ICMarketsSC-Demo: 66 positions, 49 orders",
    "QK\t0\t21:59:58.000\tNetwork\t'53071896': connection to ICMarketsSC-Demo lost",
]) + "\n"


class TestParse(unittest.TestCase):
    def test_lost_and_restored(self):
        # 16:27:29.512 -> authorized 16:27:33.764 = 4.252 s; the 21:59:58 loss
        # never restores inside the file: end None, duration None
        ev = dc.parse_lines(DAY.splitlines(), "2026-09-28")
        self.assertEqual(len(ev), 2)
        self.assertEqual(ev[0]["start"], "2026-09-28 16:27:29.512")
        self.assertEqual(ev[0]["end"], "2026-09-28 16:27:33.764")
        self.assertAlmostEqual(ev[0]["seconds"], 4.252, places=3)
        self.assertIsNone(ev[1]["end"])
        self.assertIsNone(ev[1]["seconds"])

    def test_utf16_file_and_date_from_name(self):
        with tempfile.TemporaryDirectory() as d:
            path = os.path.join(d, "20260928.log")
            with open(path, "w", encoding="utf-16") as fh:
                fh.write(DAY)
            ev = dc.parse_file(path)
        self.assertEqual(ev[0]["start"][:10], "2026-09-28")
        self.assertEqual(len(ev), 2)

    def test_only_a_reconnect_line_ends_it_and_repeats_merge(self):
        # a repeated "lost" and an unrelated line inside the outage change
        # nothing: one event, 16:27:29.512 -> 16:27:33.764 = 4.252 s
        lines = DAY.splitlines()
        lines[2:2] = ["QK\t0\t16:27:30.000\tNetwork\t'53071896': connection to ICMarketsSC-Demo lost",
                      "AB\t0\t16:27:31.000\tTerminal\tsome other message"]
        ev = dc.parse_lines(lines, "2026-09-28")
        self.assertEqual(len(ev), 2)
        self.assertEqual(ev[0]["end"], "2026-09-28 16:27:33.764")
        self.assertAlmostEqual(ev[0]["seconds"], 4.252, places=3)

    def test_no_loss_no_events(self):
        """A quiet journal gives no events."""
        self.assertEqual(dc.parse_lines(DAY.splitlines()[:1], "2026-09-28"), [])


if __name__ == "__main__":
    unittest.main()
