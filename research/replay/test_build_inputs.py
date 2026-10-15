"""Tests for build_inputs.py (hand-derived; run: python -B -m unittest test_build_inputs).

One fleet's files: run_<tag>.csv (build_segments, seg_id from first_id, seed_<seg_id>.csv
or empty for a flat start), the seeds (build_seeds), real_<tag>.csv over the whole window
(build_real; the harness keeps each segment's own rows) and intervals_<tag>.csv (header
only when none).
"""
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_inputs as bi  # noqa: E402
from test_build_segments import init, lat, U1, U2, T1, T2, END  # noqa: E402


def fill(pos, deal, et, role, side, layer, price, t_ms):
    return {"table": "fill_logs", "position_id": pos, "order_ticket": pos, "deal_ticket": deal,
            "entry_type": et, "role": role, "side": side, "layer_index": layer, "deal_price": price,
            "volume": 0.01, "deal_time_broker_msc": t_ms}


OFF = 10_800_000


def send_place(srv_ms, ticket, side, layer, role, price, otype):
    return {"table": "send_logs", "action": "PENDING", "ok": True, "ea_time_ms": srv_ms - OFF,
            "result_order": ticket, "order_ticket": None, "side": side, "layer_index": layer,
            "role": role, "requested_price": price, "order_type": otype}


class TestFleetFiles(unittest.TestCase):
    def setUp(self):
        # Flat at the first init (T1); one long L00 at 1.10000 filled 60 s after it, still
        # open at the second init (T2, 3 min 17 s after T1, the same server day: swap 0).
        self.rows = [init(U1), lat(U1, {"enable": True, "reroll": True, "roll_gate": -1}),
                     init(U2, es_=11.0), lat(U2, {"enable": True, "reroll": True, "roll_gate": 0}),
                     fill(900, 1, "IN", "ENT", "L", 0, 1.10000, T1 + 60000)]

    def test_files(self):
        files = bi.fleet_files(self.rows, "eurusd_b", T1, END, 1, "ticks_w2.csv", [], [])
        self.assertEqual(sorted(files), ["intervals_eurusd_b.csv", "real_eurusd_b.csv",
                                         "run_eurusd_b.csv", "seed_2.csv"])
        run = files["run_eurusd_b.csv"].split("\n")
        self.assertEqual(len(run), 4)            # header, two rows, trailing ""
        self.assertTrue(run[1].startswith("1,GRIND_EURUSD_OPTB,22260201,%d,%d," % (T1, T2)))
        self.assertTrue(run[1].endswith(",,ticks_w2.csv,"))
        self.assertTrue(run[2].startswith("2,GRIND_EURUSD_OPTB,22260201,%d,%d," % (T2, END)))
        self.assertTrue(run[2].endswith(",seed_2.csv,ticks_w2.csv,"))
        self.assertEqual(files["seed_2.csv"],
                         "side,layer_index,entry,open_ms,ticket,vl,swap,volume,accrued\n"
                         "L,0,1.10000,%d,900,0.00000,0.00,0.01,0.00000000\n" % (T1 + 60000))
        self.assertEqual(files["real_eurusd_b.csv"],
                         "time_ms,kind,side,layer,price,position_id,level\n"
                         "%d,ENT,L,0,1.10000,900,0.00000\n" % (T1 + 60000))
        self.assertEqual(files["intervals_eurusd_b.csv"], "kind,from_ms,to_ms\n")

    def test_orders_files(self):
        # fix 2: the book resting at each init from the sends. Before T1: nothing. At T2:
        # the short L00 placed 10 ms after T1 and the long L00's exit placed with its fill.
        sends = [send_place(T1 + 10, 51, "S", 0, "ENT", 1.10500, "ORDER_TYPE_SELL_LIMIT"),
                 send_place(T1 + 60001, 52, "L", 0, "EXT", 1.10100, "ORDER_TYPE_SELL_LIMIT")]
        files = bi.fleet_files(self.rows, "eurusd_b", T1, END, 1, "t.csv", [], [], sends=sends)
        self.assertEqual(sorted(files), ["intervals_eurusd_b.csv", "orders_2.csv",
                                         "real_eurusd_b.csv", "run_eurusd_b.csv", "seed_2.csv"])
        self.assertEqual(files["orders_2.csv"], "side,layer,role,price,ticket,type\n"
                         "L,0,EXT,1.10100,52,SELL_LIMIT\nS,0,ENT,1.10500,51,SELL_LIMIT\n")
        run = files["run_eurusd_b.csv"].split("\n")
        self.assertTrue(run[1].endswith(",,t.csv,"))
        self.assertTrue(run[2].endswith(",seed_2.csv,t.csv,orders_2.csv"))

    def test_orders_must_fit_the_seed(self):
        sends = [send_place(T1 + 10, 51, "S", 3, "EXT", 1.10500, "ORDER_TYPE_BUY_LIMIT")]
        with self.assertRaises(ValueError):
            bi.fleet_files(self.rows, "eurusd_b", T1, END, 1, "t.csv", [], [], sends=sends)

    def test_window_intervals(self):
        # Plan s12 (9 Oct): the 1 Oct entry gate (ADR-160) from send_logs: on 1 ms after the
        # last gate-checked entry each EA placed (S L00: B 17:51:06.226, C 17:50:43.354,
        # D 17:46:35.708 server) before the fill-time add it did not place (S L00 fills
        # 18:36:5x); off at B's / C's breaker-off re-init (their segment end) and at D's
        # first entry after it (L08, 19:07:24.789). D's API soft warn as before.
        self.assertEqual(bi.INTERVALS["eurusd_b"],
                         [("BREAKER_GATED", 1790877066227, 1790900826000)])
        self.assertEqual(bi.INTERVALS["eurusd_c"],
                         [("BREAKER_GATED", 1790877043355, 1790900610001)])
        self.assertEqual(bi.INTERVALS["eurusd_d"],
                         [("BREAKER_GATED", 1790876795709, 1790881644789),
                          ("API_SOFT_WARN", 1790893858000, 1790899200000)])

    def test_first_id_and_intervals(self):
        files = bi.fleet_files(self.rows, "eurusd_d", T1, END, 20, "t.csv", [],
                               [("API_SOFT_WARN", T1 + 5, T1 + 9)])
        self.assertIn("seed_21.csv", files)
        self.assertTrue(files["run_eurusd_d.csv"].split("\n")[1].startswith("20,"))
        self.assertEqual(files["intervals_eurusd_d.csv"],
                         "kind,from_ms,to_ms\nAPI_SOFT_WARN,%d,%d\n" % (T1 + 5, T1 + 9))

    def test_real_includes_a_deal_at_the_window_start(self):
        rows = self.rows + [fill(901, 2, "IN", "ENT", "S", 0, 1.10200, T1)]
        real = bi.fleet_files(rows, "eurusd_b", T1, END, 1, "t.csv", [], [])["real_eurusd_b.csv"]
        self.assertIn("\n%d,ENT,S,0,1.10200,901,0.00000\n" % T1, real)

    def test_all_ascii_no_bom(self):
        for name, text in bi.fleet_files(self.rows, "eurusd_c", T1, END, 10, "t.csv", [], []).items():
            text.encode("ascii")
            self.assertTrue(text.endswith("\n"), name)

    def test_fleet_files_sessions_file_optional(self):
        base = bi.fleet_files(self.rows, "eurusd_b", T1, END, 1, "ticks_w2.csv", [], [])
        self.assertEqual(
            bi.fleet_files(self.rows, "eurusd_b", T1, END, 1, "ticks_w2.csv", [], [],
                           sessions_file=None),
            base)
        with_sess = bi.fleet_files(self.rows, "eurusd_b", T1, END, 1, "ticks_w2.csv", [], [],
                                   sessions_file="sessions_eurusd_ic.csv")
        run = with_sess["run_eurusd_b.csv"].splitlines()
        self.assertTrue(run[0].endswith(",seed_file,ticks_file,orders_file,sessions_file"))
        self.assertEqual(len(run[0].split(",")), 24)
        self.assertTrue(run[1].endswith(",,ticks_w2.csv,,sessions_eurusd_ic.csv"))
        self.assertTrue(run[2].endswith(",seed_2.csv,ticks_w2.csv,,sessions_eurusd_ic.csv"))

    def test_sessions_cli_crlf_copy_and_column(self):
        import json
        import shutil
        import tempfile
        from test_build_segments import init, lat
        ic = (
            "day_of_week,trade_from,trade_to\n"
            "1,00:01,23:59\n"
            "2,00:01,23:59\n"
            "3,00:01,23:59\n"
            "4,00:01,23:59\n"
            "5,00:01,23:57\n"
        )
        # Same archive shape as test_build_holdout.TestPlan4Holdout.test_build_defaults_byte_identical_and_plan4_flags:
        # one INIT+LATTICE per fleet, B a second INIT 60s later, one PENDING send 10ms after the first INIT.
        # Times are build_inputs.FLEETS' window-start seconds plus 100ms, so each INIT is inside [t0, t0+1000).
        # b 2026-10-01T03:58:52 = 1790827132000; c 04:14:28 = 1790828068000; d 05:12:58 = 1790831578000.
        starts = {"b": 1790827132100, "c": 1790828068100, "d": 1790831578100}
        tmp = tempfile.mkdtemp()
        try:
            ticks_path = os.path.join(tmp, "ticks.csv")
            with open(ticks_path, "w", encoding="ascii", newline="\n") as f:
                f.write("time_msc_server,bid,ask,flags\n%d,1.10000,1.10002,0\n" % starts["b"])
            arch = {}
            sends = {}
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
            sess_src = os.path.join(tmp, "sessions_eurusd_ic.csv")
            with open(sess_src, "wb") as f:
                f.write(ic.replace("\n", "\r\n").encode("ascii"))

            out_plain = os.path.join(tmp, "out_plain")
            bi.main(["--out", out_plain, "--ticks", ticks_path, "--tick-start-ms", "0",
                     "--b", arch["b"], "--c", arch["c"], "--d", arch["d"],
                     "--sends-b", sends["b"], "--sends-c", sends["c"], "--sends-d", sends["d"]])
            with open(os.path.join(out_plain, "run_eurusd_b.csv"), "rb") as f:
                plain = f.read().decode("ascii")
            self.assertEqual(len(plain.splitlines()[0].split(",")), 23)

            out_sess = os.path.join(tmp, "out_sess")
            bi.main(["--out", out_sess, "--ticks", ticks_path, "--tick-start-ms", "0",
                     "--b", arch["b"], "--c", arch["c"], "--d", arch["d"],
                     "--sends-b", sends["b"], "--sends-c", sends["c"], "--sends-d", sends["d"],
                     "--sessions", sess_src])
            with open(os.path.join(out_sess, "run_eurusd_b.csv"), "rb") as f:
                run_b = f.read().decode("ascii")
            lines = run_b.splitlines()
            self.assertTrue(lines[0].endswith(",orders_file,sessions_file"))
            self.assertEqual(len(lines[0].split(",")), 24)
            for row in lines[1:]:
                self.assertTrue(row.endswith(",sessions_eurusd_ic.csv"), row)
            with open(os.path.join(out_sess, "sessions_eurusd_ic.csv"), "rb") as f:
                copied = f.read()
            self.assertNotIn(b"\r", copied)
            self.assertEqual(copied.decode("ascii"), ic)
        finally:
            shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
    unittest.main()
