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
    return {"table": "fill_logs", "position_id": pos, "deal_ticket": deal, "entry_type": et,
            "role": role, "side": side, "layer_index": layer, "deal_price": price,
            "volume": 0.01, "deal_time_broker_msc": t_ms}


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
        self.assertTrue(run[1].endswith(",,ticks_w2.csv"))
        self.assertTrue(run[2].startswith("2,GRIND_EURUSD_OPTB,22260201,%d,%d," % (T2, END)))
        self.assertTrue(run[2].endswith(",seed_2.csv,ticks_w2.csv"))
        self.assertEqual(files["seed_2.csv"],
                         "side,layer_index,entry,open_ms,ticket,vl,swap,volume\n"
                         "L,0,1.10000,%d,900,0.00000,0.00,0.01\n" % (T1 + 60000))
        self.assertEqual(files["real_eurusd_b.csv"],
                         "time_ms,kind,side,layer,price,position_id,level\n"
                         "%d,ENT,L,0,1.10000,900,0.00000\n" % (T1 + 60000))
        self.assertEqual(files["intervals_eurusd_b.csv"], "kind,from_ms,to_ms\n")

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


if __name__ == "__main__":
    unittest.main()
