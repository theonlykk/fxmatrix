"""Tests for build_holdout.py (hand-derived; run: python -B -m unittest test_build_holdout).

Plan 3 s7 (docs/research/replay-calibration-eurusd-3.md; plan 2 s7): the holdout's inputs from
the existing builders. B and C run on from their 7 Oct inits, D from its 9 Oct init; the window
ends Tue 13 Oct 22:00Z = 14 Oct 01:00 server. The calibration's w2 ticks and the holdout's ticks
are joined at their common 01:30 server seam, with no gap and no overlap.
"""
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_holdout as bh  # noqa: E402

HEAD = "time_msc_server,bid,ask,flags"


def tick_text(frm, to, times, crlf=True):
    nl = "\r\n" if crlf else "\n"
    lines = ["# symbol=EURUSD account=1 server=X digits=5 server_minus_gmt_s=10800 from=%s to=%s "
             "chunk_min=60 kind=ticks_info" % (frm, to), HEAD]
    lines += ["%d,1.10000,1.10001,2" % t for t in times]
    return nl.join(lines) + nl


SEAM = "2026.10.09 01:30:00.000"
SEAM_MS = 1791509400000   # 2026.10.09 01:30:00 server as epoch ms (server clock read as UTC)


class TestConstants(unittest.TestCase):
    def test_window_end(self):
        # 13 Oct 22:00:00Z = 1791928800000 ms UTC; server is UTC + 3 h; = the calibration's end
        # (9 Oct 01:00 server, 1791507600000) plus five days.
        self.assertEqual(bh.WINDOW_END_SERVER_MS, 1791928800000 + 3 * 3600 * 1000)
        self.assertEqual(bh.WINDOW_END_SERVER_MS, 1791507600000 + 5 * 86400 * 1000)

    def test_cut(self):
        # 9 Oct 04:32:00Z = 07:32 server (plan 3 s3; score_plan3 --cut-ms).
        self.assertEqual(bh.CUT_SERVER_MS, 1791531120000)

    def test_starts(self):
        self.assertEqual([f[2] for f in bh.FLEETS],
                         ["2026-10-07T02:21:20", "2026-10-07T02:12:36", "2026-10-09T04:24:14"])

    def test_ids_do_not_collide_with_calibration(self):
        firsts = [f[3] for f in bh.FLEETS]
        self.assertEqual(firsts, [31, 41, 51])
        for k in firsts:
            self.assertGreater(k, 29)

    def test_tags(self):
        self.assertEqual([f[1] for f in bh.FLEETS], ["eurusd_b", "eurusd_c", "eurusd_d"])


class TestSeamMs(unittest.TestCase):
    def test_parse(self):
        self.assertEqual(bh.server_ms(SEAM), SEAM_MS)


class TestJoin(unittest.TestCase):
    def test_join(self):
        a = tick_text("2026.10.01 04:00:00.000", SEAM, [SEAM_MS - 5000, SEAM_MS - 1])
        b = tick_text(SEAM, "2026.10.14 01:30:00.000", [SEAM_MS, SEAM_MS + 7])
        out, info = bh.join_ticks(a, b)
        lines = out.split("\r\n")
        self.assertTrue(lines[0].startswith("#"))
        self.assertIn("from=2026.10.01 04:00:00.000", lines[0])
        self.assertIn("to=2026.10.14 01:30:00.000", lines[0])
        self.assertEqual(lines[1], HEAD)
        self.assertEqual([int(x.split(",")[0]) for x in lines[2:-1]],
                         [SEAM_MS - 5000, SEAM_MS - 1, SEAM_MS, SEAM_MS + 7])
        self.assertEqual(lines[-1], "")
        self.assertEqual(info, {"first": 2, "second": 2, "joined": 4, "first_ms": SEAM_MS - 5000,
                                "seam_ms": SEAM_MS, "gap_ms": 1})

    def test_headers_must_meet(self):
        # every tick on its own side of both seams: only the headers disagree.
        a = tick_text("2026.10.01 04:00:00.000", "2026.10.09 01:00:00.000", [SEAM_MS - 3600000])
        b = tick_text(SEAM, "2026.10.14 01:30:00.000", [SEAM_MS])
        with self.assertRaises(ValueError):
            bh.join_ticks(a, b)

    def test_overlap_first(self):
        a = tick_text("2026.10.01 04:00:00.000", SEAM, [SEAM_MS - 5, SEAM_MS])
        b = tick_text(SEAM, "2026.10.14 01:30:00.000", [SEAM_MS + 1])
        with self.assertRaises(ValueError):
            bh.join_ticks(a, b)

    def test_overlap_second(self):
        a = tick_text("2026.10.01 04:00:00.000", SEAM, [SEAM_MS - 5])
        b = tick_text(SEAM, "2026.10.14 01:30:00.000", [SEAM_MS - 1, SEAM_MS + 1])
        with self.assertRaises(ValueError):
            bh.join_ticks(a, b)

    def test_unsorted(self):
        a = tick_text("2026.10.01 04:00:00.000", SEAM, [SEAM_MS - 5, SEAM_MS - 9])
        b = tick_text(SEAM, "2026.10.14 01:30:00.000", [SEAM_MS + 1])
        with self.assertRaises(ValueError):
            bh.join_ticks(a, b)

    def test_column_header(self):
        a = tick_text("2026.10.01 04:00:00.000", SEAM, [SEAM_MS - 5]).replace(HEAD, "t,bid,ask,flags")
        b = tick_text(SEAM, "2026.10.14 01:30:00.000", [SEAM_MS + 1])
        with self.assertRaises(ValueError):
            bh.join_ticks(a, b)

    def test_crlf_only(self):
        a = tick_text("2026.10.01 04:00:00.000", SEAM, [SEAM_MS - 5], crlf=False)
        b = tick_text(SEAM, "2026.10.14 01:30:00.000", [SEAM_MS + 1])
        with self.assertRaises(ValueError):
            bh.join_ticks(a, b)

    def test_mixed_line_ends(self):
        a = tick_text("2026.10.01 04:00:00.000", SEAM, [SEAM_MS - 5, SEAM_MS - 3])
        a = a.replace("\r\n%d," % (SEAM_MS - 3), "\n%d," % (SEAM_MS - 3))
        b = tick_text(SEAM, "2026.10.14 01:30:00.000", [SEAM_MS + 1])
        with self.assertRaises(ValueError):
            bh.join_ticks(a, b)


def ev(code, utc_ms):
    return {"table": "ea_events", "code": code, "ea_time_ms": utc_ms}


class TestGateCodes(unittest.TestCase):
    # The calibration's intervals (BREAKER_GATED, API_SOFT_WARN) came from the breaker and the
    # API soft limit; the holdout needs none, so any such code in a fleet's window stops the build.
    def test_none(self):
        rows = [ev("ROLL_ACCEPTED", 1000), ev("DEAL_REPLAYED", 2000)]
        self.assertEqual(bh.gate_codes(rows, 0, 10 ** 13), [])

    def test_found_in_window(self):
        off = 3 * 3600 * 1000
        rows = [ev("BREAKER_GATE_ON", 5000), ev("WARN_API_SOFT_LIMIT", 6000), ev("BREAKER_TRIPPED", 99000)]
        self.assertEqual(bh.gate_codes(rows, 5000 + off, 99000 + off),
                         [("BREAKER_GATE_ON", 5000 + off), ("WARN_API_SOFT_LIMIT", 6000 + off)])

    def test_before_window_ignored(self):
        off = 3 * 3600 * 1000
        rows = [ev("BREAKER_GATE_ON", 4999)]
        self.assertEqual(bh.gate_codes(rows, 5000 + off, 99000 + off), [])


if __name__ == "__main__":
    unittest.main()
