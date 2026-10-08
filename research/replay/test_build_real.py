"""Tests for build_real.py (hand-derived; run: python -B -m unittest test_build_real).

real_<tag>.csv (fix 1 A1): time_ms,kind,side,layer,price,position_id,level, kind ENT / EXT /
OUT_BY / ROLL, rows in time order, server ms. From the archive: ENT and EXT = fill_logs IN
rows (deal_time_broker_msc, server ms; side = the LAYER's side, as fill_logs records it);
OUT_BY = fill_logs OUT_BY rows, side and layer from the position's own IN row; ROLL =
ROLL_ACCEPTED (ea_time_ms UTC + 10,800,000; side / layer_index / ticket / level from the
detail; the row's own "level" is the log level). intervals_<tag>.csv (base s3.2):
kind,from_ms,to_ms.
"""
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_real as br  # noqa: E402

OFF = 10_800_000
T = 1791400000000   # a server ms


def fill(pos, deal, et, role, side, layer, price, t_ms):
    return {"table": "fill_logs", "position_id": pos, "deal_ticket": deal, "entry_type": et,
            "role": role, "side": side, "layer_index": layer, "deal_price": price,
            "volume": 0.01, "deal_time_broker_msc": t_ms}


def roll(ticket, side, layer, level, srv_ms):
    return {"table": "ea_events", "code": "ROLL_ACCEPTED", "level": "INFO", "ticket": ticket,
            "ea_time_ms": srv_ms - OFF,
            "detail": {"ticket": ticket, "side": side, "layer_index": layer, "level": level}}


class TestRealRows(unittest.TestCase):
    def test_a_scalp_and_a_roll(self):
        rows = [
            fill(11, 101, "IN", "ENT", "L", 2, 1.10000, T + 1000),
            fill(12, 102, "IN", "EXT", "L", 2, 1.10100, T + 5000),
            fill(11, 103, "OUT_BY", None, None, None, 1.10100, T + 5300),
            fill(12, 104, "OUT_BY", None, None, None, 1.10000, T + 5300),
            roll(13, "S", 4, 1.10560, T + 3000),
        ]
        got = br.real_rows(rows + [fill(13, 99, "IN", "ENT", "S", 4, 1.1, T - 9000)], T, T + 10000)
        self.assertEqual(got, [
            (T + 1000, "ENT", "L", 2, 1.10000, 11, 0.0),
            (T + 3000, "ROLL", "S", 4, 0.0, 13, 1.10560),
            (T + 5000, "EXT", "L", 2, 1.10100, 12, 0.0),
            (T + 5300, "OUT_BY", "L", 2, 1.10100, 11, 0.0),
            (T + 5300, "OUT_BY", "L", 2, 1.10000, 12, 0.0),
        ])

    def test_window_half_open(self):
        rows = [fill(21, 201, "IN", "ENT", "L", 0, 1.1, T),
                fill(22, 202, "IN", "ENT", "L", 1, 1.1, T + 10000),
                roll(21, "L", 0, 1.09, T - 1)]
        self.assertEqual([r[5] for r in br.real_rows(rows, T, T + 10000)], [21])

    def test_same_ms_fills_by_deal_then_roll_last(self):
        rows = [roll(31, "L", 0, 1.09, T),
                fill(32, 302, "IN", "EXT", "S", 0, 1.1, T),
                fill(31, 301, "IN", "ENT", "L", 0, 1.1, T)]
        self.assertEqual([(r[1], r[5]) for r in br.real_rows(rows, T, T + 1)],
                         [("ENT", 31), ("EXT", 32), ("ROLL", 31)])

    def test_duplicate_deal_once(self):
        r = fill(41, 401, "IN", "ENT", "L", 0, 1.1, T)
        self.assertEqual(len(br.real_rows([r, dict(r)], T, T + 1)), 1)

    def test_out_by_without_its_in_row_is_loud(self):
        with self.assertRaises(ValueError):
            br.real_rows([fill(51, 501, "OUT_BY", None, None, None, 1.1, T)], T, T + 1)

    def test_detail_as_json_and_other_codes_ignored(self):
        r = roll(61, "S", 1, 1.105, T)
        r["detail"] = '{"ticket": 61, "side": "S", "layer_index": 1, "level": 1.105}'
        d = roll(61, "S", 1, 1.2, T)
        d["code"] = "ROLL_DEFERRED"
        self.assertEqual(br.real_rows([r, d], T, T + 1), [(T, "ROLL", "S", 1, 0.0, 61, 1.105)])


class TestCsv(unittest.TestCase):
    def test_real_format(self):
        out = br.to_real_csv([(T, "ENT", "L", 2, 1.1, 11, 0.0),
                              (T + 1, "ROLL", "S", 4, 0.0, 13, 1.1056)])
        self.assertEqual(out, "time_ms,kind,side,layer,price,position_id,level\n"
                              "1791400000000,ENT,L,2,1.10000,11,0.00000\n"
                              "1791400000001,ROLL,S,4,0.00000,13,1.10560\n")
        out.encode("ascii")

    def test_intervals(self):
        # D's API soft warn: server 2026.10.01 22:30:58 to 2026.10.02 00:00:00. By hand:
        # 2026-10-01 00:00 = 1790812800000 ms; + 22:30:58 (81,058,000) = 1790893858000;
        # + one day (86,400,000) = 1790899200000.
        out = br.to_intervals_csv([("API_SOFT_WARN", 1790893858000, 1790899200000)])
        self.assertEqual(out, "kind,from_ms,to_ms\nAPI_SOFT_WARN,1790893858000,1790899200000\n")
        self.assertEqual(br.to_intervals_csv([]), "kind,from_ms,to_ms\n")


if __name__ == "__main__":
    unittest.main()
