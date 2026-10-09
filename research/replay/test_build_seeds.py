"""Tests for build_seeds.py (hand-derived; run: python -B -m unittest test_build_seeds).

Seed format (base prompt s3.2; fix 3 adds accrued): side,layer_index,entry,open_ms,ticket,vl,
swap,volume,accrued;
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

    def test_roll_at_init_exactly_not_before(self):
        self.assertEqual(bsd.latest_vl([roll(101, 1.09, INIT)], 101, INIT), 0.0)

    def test_only_roll_accepted(self):
        r = roll(101, 1.09, INIT - H)
        r["code"] = "ROLL_REFUSED"
        d = roll(101, 1.08, INIT - 2 * H)
        d["code"] = "ROLL_DEFERRED"
        self.assertEqual(bsd.latest_vl([r, d], 101, INIT), 0.0)

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

    def test_init_just_after_server_midnight(self):
        # Long opened Wed 7 Oct 12:00 server, init Thu 8 Oct 01:30 server (Wed 22:30Z):
        # the rollover into Thu 8 (x3 at -8.2) is before the init: -0.246 -> -0.25.
        open_l = int((srv(2026, 10, 7, 12) - dt.datetime(1970, 1, 1)).total_seconds() * 1000)
        at = int((srv(2026, 10, 8, 1, 30) - dt.datetime(1970, 1, 1)).total_seconds() * 1000)
        got = bsd.seed_rows([fill(611, 1, "IN", "ENT", "L", 0, 1.1, open_l)], SNAPS, at)
        self.assertAlmostEqual(got[0]["swap"], -0.25, places=9)

    def test_flat(self):
        self.assertEqual(bsd.seed_rows([], SNAPS, INIT), [])


def ms(t):
    return int((t - dt.datetime(1970, 1, 1)).total_seconds() * 1000)


class TestAccrued(unittest.TestCase):
    """Fix 3: the EA's accrued carry (GV GRIND_CARRY_ACCRUED_<ticket>, a PRICE offset) as the
    last carry pass before the init left it: the pass runs 23:50 server on Mon-Fri; for a
    position open at it, accrued pips = ledger (its swap so far, USD x 10 at 0.01 lot) +
    pending (the pass snapshot's points x the EA's multiplier for TOMORROW / 10: 0 when
    tomorrow is Sat / Sun, 3 when tomorrow is WEDNESDAY, else 1: grind_carry.mqh 196-213,
    1115-1123); price = -direction x pips x 0.0001; 0 when opened after that pass."""

    def test_one_night_long_and_short(self):
        # Long opened Tue 6 10:00, init Thu 8 05:00: the Wed 7 23:50 pass; ledger = into Wed 7
        # (x1 at -8.0: -0.08 USD = -0.8 pip); pending = -8.2 x 1 / 10 = -0.82: +0.000162.
        self.assertAlmostEqual(bsd.accrued_price(SNAPS, "L", ms(srv(2026, 10, 6, 10)), INIT),
                               0.000162, places=10)
        # Short opened Wed 7 12:00: ledger 0; pending +1.6 / 10 = +0.16 pip: +0.000016.
        self.assertAlmostEqual(bsd.accrued_price(SNAPS, "S", ms(srv(2026, 10, 7, 12)), INIT),
                               0.000016, places=10)

    def test_triple_a_night_early(self):
        # Long opened Mon 5 10:00, init Wed 7 05:00: the Tue 6 23:50 pass; ledger into Tue 6
        # (-0.08 USD = -0.8); pending: tomorrow is Wednesday -> x3: -8.0 x 3 / 10 = -2.4.
        self.assertAlmostEqual(
            bsd.accrued_price(SNAPS, "L", ms(srv(2026, 10, 5, 10)), ms(srv(2026, 10, 7, 5))),
            0.00032, places=10)

    def test_opened_after_the_pass(self):
        self.assertEqual(bsd.accrued_price(SNAPS, "L", ms(srv(2026, 10, 7, 23, 55)), INIT), 0.0)
        # opened exactly at the pass's start: not in its work list either
        self.assertEqual(bsd.accrued_price(SNAPS, "L", ms(srv(2026, 10, 7, 23, 50)), INIT), 0.0)

    def test_no_pass_on_the_weekend(self):
        snaps = SNAPS + [(srv(2026, 10, 8, 23, 50), -8.0, 1.4), (srv(2026, 10, 9, 23, 50), -8.0, 1.4)]
        opened = ms(srv(2026, 10, 8, 10))
        # Mon 12 10:00 and Sat 10 12:00 both read the Fri 9 pass: ledger into Fri 9 (-0.8);
        # pending x0 (tomorrow Saturday): +0.00008.
        for at in (srv(2026, 10, 12, 10), srv(2026, 10, 10, 12)):
            self.assertAlmostEqual(bsd.accrued_price(snaps, "L", opened, ms(at)), 0.00008,
                                   places=10)
        # Fri 9 at 23:49 still reads Thu 8's pass: ledger 0 (opened Thu 10:00, no rollover
        # yet); pending into Fri x1 at the Thu snapshot (-8.0): +0.00008.
        self.assertAlmostEqual(bsd.accrued_price(snaps, "L", opened, ms(srv(2026, 10, 9, 23, 49))),
                               0.00008, places=10)

    def test_at_the_pass_minute(self):
        # Defined, not observed (no init falls in 23:50-23:59): an init at 23:50:00 reads that
        # day's pass. Long opened Tue 6 10:00, at Wed 7 23:50: ledger into Wed 7 (-0.8),
        # pending -8.2 x 1 / 10 (tomorrow Thursday): +0.000162; at 23:49:59, Tue 6's pass:
        # ledger 0, pending -8.0 x 3 / 10 (tomorrow Wednesday): +0.00024.
        opened = ms(srv(2026, 10, 6, 10))
        self.assertAlmostEqual(bsd.accrued_price(SNAPS, "L", opened, ms(srv(2026, 10, 7, 23, 50))),
                               0.000162, places=10)
        self.assertAlmostEqual(
            bsd.accrued_price(SNAPS, "L", opened, ms(srv(2026, 10, 7, 23, 50)) - 1000),
            0.00024, places=10)

    def test_seed_rows_carry_it(self):
        got = bsd.seed_rows([fill(621, 1, "IN", "ENT", "L", 0, 1.1, ms(srv(2026, 10, 6, 10)))],
                            SNAPS, INIT)
        self.assertAlmostEqual(got[0]["accrued"], 0.000162, places=10)


class TestCsv(unittest.TestCase):
    def test_format(self):
        seed = [{"side": "L", "layer_index": 0, "entry": 1.1, "open_ms": 1791400000123,
                 "ticket": 1975880441, "vl": 1.09300, "swap": -0.33, "volume": 0.01,
                 "accrued": 0.000162},
                {"side": "S", "layer_index": 2, "entry": 1.12345, "open_ms": 1791400001000,
                 "ticket": 1975880442, "vl": 0.0, "swap": 0.0, "volume": 0.01, "accrued": 0.0}]
        self.assertEqual(bsd.to_seed_csv(seed),
                         "side,layer_index,entry,open_ms,ticket,vl,swap,volume,accrued\n"
                         "L,0,1.10000,1791400000123,1975880441,1.09300,-0.33,0.01,0.00016200\n"
                         "S,2,1.12345,1791400001000,1975880442,0.00000,0.00,0.01,0.00000000\n")

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

    def test_at_cap_boundary(self):
        # Newest open 1 ms before the tick file starts warns; at the start it does not.
        t0 = INIT - 2 * H
        self.assertEqual(bsd.cap_warnings(self._seed("L", 8, t0 - 1), 8, INIT, t0),
                         [("L", 8, t0 - 1)])
        self.assertEqual(bsd.cap_warnings(self._seed("L", 8, t0), 8, INIT, t0), [])

    def test_at_cap_inside_ticks_ok(self):
        seed = self._seed("L", 8, INIT - 1 * H)
        self.assertEqual(bsd.cap_warnings(seed, 8, INIT, INIT - 2 * H), [])


if __name__ == "__main__":
    unittest.main()
