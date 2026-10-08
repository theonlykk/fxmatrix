"""Tests for build_seeds.py (hand-derived; run: python -B -m unittest test_build_seeds).

Seed format (base prompt s3.2): side,layer_index,entry,open_ms,ticket,vl,swap,volume;
times SERVER ms. Plan s3: the true open ENT positions at an init, from fill_logs;
vl = the latest ROLL_ACCEPTED detail "level" for the ticket before the init (0 = not
rolled); swap = build_swaps.predict_swap to the init (69 of 69 CARRY_EXIT_SHIFT
ledgers agree, HANDOFF s73). ea_time_ms is UTC: +10,800,000 for server ms.
"""
import datetime as dt
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_seeds as bsd  # noqa: E402

OFF = 10_800_000
# Server ms: 2026-10-08 05:00:00 server.
INIT = int((dt.datetime(2026, 10, 8, 5, 0, 0) - dt.datetime(1970, 1, 1)).total_seconds() * 1000)
H = 3_600_000


def fill(pos, deal, et, role, side, layer, price, t_ms):
    return {"table": "fill_logs", "position_id": pos, "deal_ticket": deal, "entry_type": et,
            "role": role, "side": side, "layer_index": layer, "deal_price": price,
            "volume": 0.01, "deal_time_broker_msc": t_ms}


def roll(ticket, level, srv_ms):
    return {"table": "ea_events", "code": "ROLL_ACCEPTED", "level": "INFO", "ticket": ticket,
            "ea_time_ms": srv_ms - OFF,
            "detail": {"ticket": ticket, "level": level, "side": "L", "layer_index": 0}}


def srv(y, m, d, hh=0, mm=0):
    return dt.datetime(y, m, d, hh, mm)


# Snapshots in SERVER time (build_swaps.snapshots_server's shape).
SNAPS = [(srv(2026, 10, 5, 23, 50), -8.0, 1.4),   # rate for the rollover into Tue 6
         (srv(2026, 10, 6, 23, 50), -8.0, 1.4),   # into Wed 7 (x1)
         (srv(2026, 10, 7, 23, 50), -8.2, 1.6)]   # into Thu 8 (x3)


class TestOpenPositions(unittest.TestCase):
    def test_open_closed_later_and_future(self):
        rows = [
            fill(101, 1, "IN", "ENT", "L", 0, 1.10000, INIT - 5 * H),      # open
            fill(102, 2, "IN", "ENT", "L", 1, 1.09930, INIT - 4 * H),      # closed before
            fill(102, 3, "OUT_BY", None, None, None, 1.10030, INIT - 1 * H),
            fill(103, 4, "IN", "ENT", "S", 0, 1.10100, INIT - 2 * H),      # closed AFTER init
            fill(103, 5, "OUT_BY", None, None, None, 1.10000, INIT + 1 * H),
            fill(104, 6, "IN", "ENT", "S", 1, 1.10170, INIT + 2 * H),      # opens after
        ]
        got = bsd.open_positions(rows, INIT)
        self.assertEqual([p["ticket"] for p in got], [101, 103])
        self.assertEqual(got[0], {"side": "L", "layer_index": 0, "entry": 1.10000,
                                  "open_ms": INIT - 5 * H, "ticket": 101, "volume": 0.01})
        self.assertEqual(got[1]["side"], "S")

    def test_ordering_long_first_then_layer(self):
        rows = [fill(201, 1, "IN", "ENT", "S", 1, 1.2, INIT - 9 * H),
                fill(202, 2, "IN", "ENT", "L", 2, 1.1, INIT - 8 * H),
                fill(203, 3, "IN", "ENT", "L", 0, 1.1, INIT - 7 * H),
                fill(204, 4, "IN", "ENT", "S", 0, 1.2, INIT - 6 * H)]
        got = bsd.open_positions(rows, INIT)
        self.assertEqual([(p["side"], p["layer_index"]) for p in got],
                         [("L", 0), ("L", 2), ("S", 0), ("S", 1)])

    def test_at_init_exactly_is_not_before(self):
        rows = [fill(301, 1, "IN", "ENT", "L", 0, 1.1, INIT)]
        self.assertEqual(bsd.open_positions(rows, INIT), [])

    def test_close_at_init_exactly_still_open(self):
        rows = [fill(311, 1, "IN", "ENT", "L", 0, 1.1, INIT - H),
                fill(311, 2, "OUT_BY", None, None, None, 1.1, INIT)]
        self.assertEqual([p["ticket"] for p in bsd.open_positions(rows, INIT)], [311])

    def test_plain_out_closes_too(self):
        rows = [fill(321, 1, "IN", "ENT", "L", 0, 1.1, INIT - H),
                fill(321, 2, "OUT", None, None, None, 1.1, INIT - 1)]
        self.assertEqual(bsd.open_positions(rows, INIT), [])

    def test_duplicate_deal_rows_once(self):
        r = fill(401, 1, "IN", "ENT", "L", 0, 1.1, INIT - H)
        self.assertEqual(len(bsd.open_positions([r, dict(r)], INIT)), 1)

    def test_open_ext_position_is_loud(self):
        rows = [fill(501, 1, "IN", "EXT", "L", 0, 1.1, INIT - H)]
        with self.assertRaises(ValueError):
            bsd.open_positions(rows, INIT)

    def test_closed_ext_position_is_fine(self):
        rows = [fill(511, 1, "IN", "EXT", "L", 0, 1.1, INIT - 2 * H),
                fill(511, 2, "OUT_BY", None, None, None, 1.1, INIT - H)]
        self.assertEqual(bsd.open_positions(rows, INIT), [])

    def test_other_tables_ignored(self):
        rows = [{"table": "scalp_history", "position_id": 9, "entry_type": "IN", "role": "ENT",
                 "deal_time_broker_msc": INIT - H}]
        self.assertEqual(bsd.open_positions(rows, INIT), [])


class TestLatestVl(unittest.TestCase):
    def test_latest_before_init(self):
        rows = [roll(101, 1.09500, INIT - 3 * H), roll(101, 1.09430, INIT - 1 * H),
                roll(101, 1.09360, INIT + 1 * H), roll(999, 1.0, INIT - 2 * H)]
        self.assertEqual(bsd.latest_vl(rows, 101, INIT), 1.09430)

    def test_none_is_zero(self):
        self.assertEqual(bsd.latest_vl([roll(999, 1.0, INIT - H)], 101, INIT), 0.0)

    def test_ea_time_is_utc(self):
        # ea_time_ms 2 h before the init in UTC terms is 1 h AFTER it in server terms.
        r = roll(101, 1.09, INIT + H)
        self.assertEqual(r["ea_time_ms"], INIT - 2 * H)
        self.assertEqual(bsd.latest_vl([r], 101, INIT), 0.0)

    def test_detail_as_json_string(self):
        r = roll(101, 1.09500, INIT - H)
        r["detail"] = '{"ticket": 101, "level": 1.095}'
        self.assertEqual(bsd.latest_vl([r], 101, INIT), 1.095)


class TestSeedRows(unittest.TestCase):
    def test_vl_and_swap(self):
        # Long opened Tue 6 Oct 10:00 server, init Thu 8 Oct 05:00 server:
        # into Wed 7 x1 at -8.0, into Thu 8 x3 at -8.2: (-8.0 - 24.6) x 0.01 = -0.326 -> -0.33.
        # Short opened Wed 7 Oct 12:00 server: into Thu 8 x3 at +1.6: +0.048 -> 0.05.
        open_l = int((srv(2026, 10, 6, 10) - dt.datetime(1970, 1, 1)).total_seconds() * 1000)
        open_s = int((srv(2026, 10, 7, 12) - dt.datetime(1970, 1, 1)).total_seconds() * 1000)
        rows = [fill(601, 1, "IN", "ENT", "L", 0, 1.10000, open_l),
                fill(602, 2, "IN", "ENT", "S", 0, 1.10500, open_s),
                roll(601, 1.09300, INIT - H)]
        got = bsd.seed_rows(rows, SNAPS, INIT)
        self.assertEqual(len(got), 2)
        self.assertEqual(got[0]["vl"], 1.09300)
        self.assertAlmostEqual(got[0]["swap"], -0.33, places=9)
        self.assertEqual(got[1]["vl"], 0.0)
        self.assertAlmostEqual(got[1]["swap"], 0.05, places=9)

    def test_flat(self):
        self.assertEqual(bsd.seed_rows([], SNAPS, INIT), [])


class TestCsv(unittest.TestCase):
    def test_format(self):
        seed = [{"side": "L", "layer_index": 0, "entry": 1.1, "open_ms": 1791400000123,
                 "ticket": 1975880441, "vl": 1.09300, "swap": -0.33, "volume": 0.01},
                {"side": "S", "layer_index": 2, "entry": 1.12345, "open_ms": 1791400001000,
                 "ticket": 1975880442, "vl": 0.0, "swap": 0.0, "volume": 0.01}]
        self.assertEqual(bsd.to_seed_csv(seed),
                         "side,layer_index,entry,open_ms,ticket,vl,swap,volume\n"
                         "L,0,1.10000,1791400000123,1975880441,1.09300,-0.33,0.01\n"
                         "S,2,1.12345,1791400001000,1975880442,0.00000,0.00,0.01\n")

    def test_ascii_no_bom(self):
        out = bsd.to_seed_csv([])
        self.assertEqual(out, bsd.SEED_HEADER + "\n")
        out.encode("ascii")


class TestCapWarnings(unittest.TestCase):
    def _seed(self, side, n, newest_open):
        return [{"side": side, "layer_index": i, "open_ms": newest_open - (n - 1 - i) * H}
                for i in range(n)]

    def test_below_cap_never_warns(self):
        seed = self._seed("L", 7, INIT - 30 * H)
        self.assertEqual(bsd.cap_warnings(seed, 8, INIT, INIT), [])

    def test_at_cap_old_open_before_ticks_warns(self):
        # Preload start = max(newest open, init - 24 h) = init - 24 h; ticks from init - 2 h.
        seed = self._seed("S", 8, INIT - 30 * H)
        self.assertEqual(bsd.cap_warnings(seed, 8, INIT, INIT - 2 * H),
                         [("S", 8, INIT - 24 * H)])

    def test_at_cap_inside_ticks_ok(self):
        seed = self._seed("L", 8, INIT - 1 * H)
        self.assertEqual(bsd.cap_warnings(seed, 8, INIT, INIT - 2 * H), [])


if __name__ == "__main__":
    unittest.main()
