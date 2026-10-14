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


class TestPlan4Holdout(unittest.TestCase):
    def test_join_sends_dedup_sort_and_drop_meta(self):
        r1 = {"table": "send_logs", "id": 12, "ea_time_ms": 2000, "seq": 5, "action": "MODIFY", "ok": True}
        r2 = {"table": "send_logs", "id": 10, "ea_time_ms": 1000, "seq": 3, "action": "PENDING", "ok": True}
        r3 = {"table": "send_logs", "id": 11, "ea_time_ms": 2000, "seq": 4, "action": "PENDING", "ok": True}
        meta = {"_meta": {"exported_at": "2026-10-13"}}
        got = bh.join_sends([meta, r1, r2], [dict(r2), r3, meta])
        self.assertEqual(got, [r2, r3, r1])

    def test_join_sends_conflicting_duplicate_raises(self):
        r1 = {"table": "send_logs", "id": 10, "ea_time_ms": 1000, "seq": 3, "action": "PENDING",
              "requested_price": 1.10000, "ok": True}
        r2 = dict(r1, requested_price=1.10010)
        with self.assertRaises(ValueError):
            bh.join_sends([r1], [r2])

    def test_build_defaults_byte_identical_and_plan4_flags(self):
        import json
        import shutil
        import tempfile
        from test_build_segments import init, lat
        off = bh.SERVER_OFFSET_MS
        # Fleet start times matching bh.FLEETS:
        # B: 2026-10-07T02:21:20Z = 1791339680000 UTC
        # C: 2026-10-07T02:12:36Z = 1791339156000 UTC
        # D: 2026-10-09T04:24:14Z = 1791519854000 UTC
        starts = {"b": 1791339680100, "c": 1791339156200, "d": 1791519854300}
        tmp = tempfile.mkdtemp()
        try:
            ticks_path = os.path.join(tmp, "ticks_hold.csv")
            with open(ticks_path, "w", encoding="ascii", newline="") as f:
                f.write(tick_text("2026.10.01 04:00:00.000", "2026.10.14 01:30:00.000",
                                  [starts["c"] + off - 1000]))
            arch = {}
            sends = {}
            extra_b = os.path.join(tmp, "sends_extra_b.jsonl")
            for k, u in starts.items():
                arch[k] = os.path.join(tmp, "arch_%s.jsonl" % k)
                sends[k] = os.path.join(tmp, "sends_%s.jsonl" % k)
                rows = [init(u), lat(u, {"enable": True, "reroll": True, "roll_gate": 0})]
                if k == "b":
                    u2 = u + 60000
                    rows += [init(u2), lat(u2, {"enable": True, "reroll": True, "roll_gate": 0})]
                with open(arch[k], "w", encoding="utf-8", newline="\n") as f:
                    for r in rows:
                        f.write(json.dumps(r) + "\n")
                s_rows = [{"_meta": {"fleet": k}},
                          {"table": "send_logs", "id": 1, "ea_time_ms": u + 10, "seq": 1,
                           "action": "PENDING", "ok": True, "result_order": 501,
                           "order_ticket": None, "side": "L", "layer_index": 0,
                           "role": "ENT", "requested_price": 1.10000,
                           "order_type": "ORDER_TYPE_BUY_LIMIT"}]
                with open(sends[k], "w", encoding="utf-8", newline="\n") as f:
                    for r in s_rows:
                        f.write(json.dumps(r) + "\n")
            with open(extra_b, "w", encoding="utf-8", newline="\n") as f:
                f.write(json.dumps({"_meta": {"extra": True}}) + "\n")
                f.write(json.dumps({"table": "send_logs", "id": 1, "ea_time_ms": starts["b"] + 10,
                                    "seq": 1, "action": "PENDING", "ok": True, "result_order": 501,
                                    "order_ticket": None, "side": "L", "layer_index": 0,
                                    "role": "ENT", "requested_price": 1.10000,
                                    "order_type": "ORDER_TYPE_BUY_LIMIT"}) + "\n")
                f.write(json.dumps({"table": "send_logs", "id": 2, "ea_time_ms": starts["b"] + 20,
                                    "seq": 2, "action": "PENDING", "ok": True, "result_order": 502,
                                    "order_ticket": None, "side": "S", "layer_index": 0,
                                    "role": "ENT", "requested_price": 1.10500,
                                    "order_type": "ORDER_TYPE_SELL_LIMIT"}) + "\n")
            sess_src = os.path.join(tmp, "sessions_eurusd_ic.csv")
            with open(sess_src, "w", encoding="ascii", newline="\n") as f:
                f.write("day_of_week,trade_from,trade_to\n1,00:01,23:59\n")

            out_def = os.path.join(tmp, "out_def")
            bh.main(["build", "--out", out_def, "--ticks", ticks_path,
                     "--b", arch["b"], "--c", arch["c"], "--d", arch["d"],
                     "--sends-b", sends["b"], "--sends-c", sends["c"], "--sends-d", sends["d"]])
            with open(os.path.join(out_def, "run_eurusd_b.csv"), "rb") as f:
                run_b_def = f.read().decode("ascii")
            self.assertEqual(len(run_b_def.splitlines()[0].split(",")), 23)
            self.assertTrue(run_b_def.splitlines()[1].startswith("31,"))
            self.assertIn(",%d," % bh.WINDOW_END_SERVER_MS, run_b_def.splitlines()[2])

            out_p4 = os.path.join(tmp, "out_p4")
            new_end = bh.WINDOW_END_SERVER_MS - 3600000
            bh.main(["build", "--out", out_p4, "--ticks", ticks_path,
                     "--b", arch["b"], "--c", arch["c"], "--d", arch["d"],
                     "--sends-b", sends["b"], "--sends-c", sends["c"], "--sends-d", sends["d"],
                     "--sends-extra-b", extra_b, "--window-end-ms", str(new_end),
                     "--first-ids", "61,71,81", "--sessions", sess_src])
            with open(os.path.join(out_p4, "run_eurusd_b.csv"), "rb") as f:
                run_b_p4 = f.read().decode("ascii")
            self.assertEqual(len(run_b_p4.splitlines()[0].split(",")), 24)
            self.assertTrue(run_b_p4.splitlines()[0].endswith(",orders_file,sessions_file"))
            self.assertTrue(run_b_p4.splitlines()[1].startswith("61,"))
            self.assertTrue(run_b_p4.splitlines()[2].endswith(",orders_62.csv,sessions_eurusd_ic.csv"))
            self.assertIn(",%d," % new_end, run_b_p4.splitlines()[2])
            self.assertTrue(os.path.isfile(os.path.join(out_p4, "sessions_eurusd_ic.csv")))
            with open(os.path.join(out_p4, "orders_62.csv"), "rb") as f:
                orders_62 = f.read().decode("ascii")
            self.assertIn("S,0,ENT,1.10500,502,SELL_LIMIT", orders_62)
        finally:
            shutil.rmtree(tmp, ignore_errors=True)

    def test_sessions_eurusd_ic_csv_file(self):
        path = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                            "inputs", "sessions_eurusd_ic.csv")
        with open(path, "rb") as f:
            raw = f.read()
        self.assertNotIn(b"\r", raw)
        text = raw.decode("ascii")
        self.assertEqual(text, (
            "day_of_week,trade_from,trade_to\n"
            "1,00:01,23:59\n"
            "2,00:01,23:59\n"
            "3,00:01,23:59\n"
            "4,00:01,23:59\n"
            "5,00:01,23:57\n"
        ))


if __name__ == "__main__":
    unittest.main()
