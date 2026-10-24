"""Hand-valued tests for session_hours.py (run: python research/session_hours/test_session_hours.py).

Expected values are worked by hand from the records below, never read from the code's output.
Broker time is GMT+3 (both brokers, verified 25 Sep; until 1 Nov): broker 22:32:49 = 19:32:49Z.
"""
import os
import sys
import unittest
from datetime import datetime, timezone

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import session_hours as sh  # noqa: E402


def utc(s):
    return datetime.strptime(s, "%Y-%m-%d %H:%M:%S").replace(tzinfo=timezone.utc)


def fill(ticket, pos, etype, broker_time, price=1.1, role=None, side=None, layer=None, inst="GRIND_EURUSD_OPTB"):
    return {"table": "fill_logs", "instance_id": inst, "deal_ticket": ticket, "position_id": pos,
            "entry_type": etype, "role": role, "side": side, "layer_index": layer,
            "deal_price": price, "deal_time_broker": broker_time}


def scalp(direction, entry, exit_, close_broker, gross, rolled=False, ejected=False, inst="GRIND_EURUSD_OPTB"):
    return {"table": "scalp_history", "instance_id": inst, "direction": direction, "entry_price": entry,
            "exit_price": exit_, "close_time_broker": close_broker, "gross_pnl": gross,
            "rolled": rolled, "ejected": ejected, "broker_utc_offset_s": 10800}


class Clock(unittest.TestCase):
    def test_broker_to_utc_minus_3h(self):
        self.assertEqual(sh.broker_to_utc("2026-10-21 22:32:49"), utc("2026-10-21 19:32:49"))

    def test_broker_after_midnight_is_previous_utc_day(self):
        # 01:15 server on Thu 22 Oct is 22:15Z on Wed 21 Oct.
        self.assertEqual(sh.broker_to_utc("2026-10-22 01:15:00"), utc("2026-10-21 22:15:00"))

    def test_blocks_at_their_edges(self):
        cases = {"2026-10-21 06:59:59": "ASIA", "2026-10-21 07:00:00": "LDN_AM",
                 "2026-10-21 10:59:59": "LDN_AM", "2026-10-21 11:00:00": "LDN_NY",
                 "2026-10-21 15:59:59": "LDN_NY", "2026-10-21 16:00:00": "NY_PM",
                 "2026-10-21 20:59:59": "NY_PM", "2026-10-21 21:00:00": "ASIA",
                 "2026-10-21 00:00:00": "ASIA"}
        for s, want in cases.items():
            self.assertEqual(sh.block(utc(s)), want, s)

    def test_adr161_window_weekdays_11_00_to_20_55(self):
        # Wed 21 Oct; ADR-161 = 07:00-16:55 Toronto (EDT, UTC-4) = 11:00-20:55Z.
        self.assertFalse(sh.in_window(utc("2026-10-21 10:59:59")))
        self.assertTrue(sh.in_window(utc("2026-10-21 11:00:00")))
        self.assertTrue(sh.in_window(utc("2026-10-21 20:54:59")))
        self.assertFalse(sh.in_window(utc("2026-10-21 20:55:00")))
        # Saturday 24 Oct 12:00Z: closed (weekday rule).
        self.assertFalse(sh.in_window(utc("2026-10-24 12:00:00")))
        # Sunday 25 Oct 22:00Z (the open): not a weekday window in Toronto (18:00 Sunday).
        self.assertFalse(sh.in_window(utc("2026-10-25 22:00:00")))


class Layers(unittest.TestCase):
    def test_scalped_layer_linked_by_position_price_and_close_time(self):
        # A long ENT at 1.10000 filled 10:05:00 server (07:05Z); its EXT at 1.10070; both closed by
        # close-by at 13:00:00 server (10:00Z); the scalp row: LONG 1.1 -> 1.1007, gross +0.70.
        recs = [fill(1, 101, "IN", "2026-10-21 10:05:00", 1.1, "ENT", "L", 0),
                fill(2, 102, "IN", "2026-10-21 13:00:00", 1.1007, "EXT", "L", 0),
                fill(3, 101, "OUT_BY", "2026-10-21 13:00:00", 1.1007),
                fill(4, 102, "OUT_BY", "2026-10-21 13:00:00", 1.1),
                scalp("LONG", 1.1, 1.1007, "2026-10-21 13:00:00", 0.70)]
        ls = sh.layers(recs)
        self.assertEqual(len(ls), 1)
        L = ls[0]
        self.assertEqual(L["entry_utc"], utc("2026-10-21 07:05:00"))
        self.assertEqual(L["close_utc"], utc("2026-10-21 10:00:00"))
        self.assertEqual(L["status"], "scalped")
        self.assertAlmostEqual(L["gross"], 0.70)
        self.assertEqual(L["side"], "L")

    def test_rolled_layer(self):
        recs = [fill(1, 201, "IN", "2026-10-21 18:00:00", 1.2, "ENT", "S", 6),
                fill(2, 201, "OUT_BY", "2026-10-21 19:30:01", 1.21),
                scalp("SHORT", 1.2, 1.21, "2026-10-21 19:30:00", -10.0, rolled=True)]
        L = sh.layers(recs)[0]
        # the close is matched within 2 s (19:30:01 against 19:30:00)
        self.assertEqual(L["status"], "rolled")
        self.assertAlmostEqual(L["gross"], -10.0)

    def test_open_layer_has_no_close(self):
        recs = [fill(1, 301, "IN", "2026-10-21 18:00:00", 1.2, "ENT", "L", 1)]
        L = sh.layers(recs)[0]
        self.assertEqual(L["status"], "open")
        self.assertIsNone(L["close_utc"])
        self.assertIsNone(L["gross"])

    def test_closed_without_a_scalp_row_is_unlinked(self):
        recs = [fill(1, 401, "IN", "2026-10-21 18:00:00", 1.2, "ENT", "L", 1),
                fill(2, 401, "OUT", "2026-10-21 18:10:00", 1.19)]
        L = sh.layers(recs)[0]
        self.assertEqual(L["status"], "unlinked")
        self.assertIsNone(L["gross"])

    def test_two_layers_same_price_paired_by_close_time(self):
        # Two longs at 1.1 entered at 10:00 and 11:00 server; closed 12:00 (+0.5) and 14:00 (-3.0, rolled).
        recs = [fill(1, 501, "IN", "2026-10-21 10:00:00", 1.1, "ENT", "L", 0),
                fill(2, 502, "IN", "2026-10-21 11:00:00", 1.1, "ENT", "L", 0),
                fill(3, 501, "OUT_BY", "2026-10-21 14:00:00", 1.07),
                fill(4, 502, "OUT_BY", "2026-10-21 12:00:00", 1.105),
                scalp("LONG", 1.1, 1.105, "2026-10-21 12:00:00", 0.5),
                scalp("LONG", 1.1, 1.07, "2026-10-21 14:00:00", -3.0, rolled=True)]
        by = {L["position_id"]: L for L in sh.layers(recs)}
        self.assertEqual(by[502]["status"], "scalped")
        self.assertAlmostEqual(by[502]["gross"], 0.5)
        self.assertEqual(by[501]["status"], "rolled")
        self.assertAlmostEqual(by[501]["gross"], -3.0)

    def test_duplicate_deal_tickets_counted_once(self):
        f = fill(1, 601, "IN", "2026-10-21 10:00:00", 1.1, "ENT", "L", 0)
        self.assertEqual(len(sh.layers([f, dict(f)])), 1)

    def test_ejected_layer(self):
        recs = [fill(1, 701, "IN", "2026-10-21 10:00:00", 1.1, "ENT", "L", 3),
                fill(2, 701, "OUT_BY", "2026-10-21 12:00:00", 1.09),
                scalp("LONG", 1.1, 1.09, "2026-10-21 12:00:00", -1.0, ejected=True)]
        self.assertEqual(sh.layers(recs)[0]["status"], "ejected")

    def test_a_scalp_row_is_used_once(self):
        # Two layers, same price, closed the same second, ONE scalp row: one scalped, one unlinked.
        recs = [fill(1, 801, "IN", "2026-10-21 10:00:00", 1.1, "ENT", "L", 0),
                fill(2, 802, "IN", "2026-10-21 10:30:00", 1.1, "ENT", "L", 0),
                fill(3, 801, "OUT_BY", "2026-10-21 12:00:00", 1.105),
                fill(4, 802, "OUT_BY", "2026-10-21 12:00:00", 1.105),
                scalp("LONG", 1.1, 1.105, "2026-10-21 12:00:00", 0.5)]
        st = sorted(L["status"] for L in sh.layers(recs))
        self.assertEqual(st, ["scalped", "unlinked"])

    def test_a_non_offset_scalp_row_stops(self):
        recs = [scalp("LONG", 1.1, 1.105, "2026-10-21 12:00:00", 0.5)]
        recs[0]["broker_utc_offset_s"] = 7200
        with self.assertRaises(ValueError):
            sh.layers(recs)


class Era(unittest.TestCase):
    def test_era_keeps_entries_inside_and_censors_outcomes_at_the_end(self):
        # Era 2026-10-21 08:00Z to 12:00Z. Layer a: entered 07:00Z (before): dropped.
        # Layer b: entered 09:00Z, closed 11:00Z: kept as closed. Layer c: entered 10:00Z, closed 13:00Z
        # (after the era's end): kept, status open (the outcome is not observed inside the era).
        a = {"entry_utc": utc("2026-10-21 07:00:00"), "close_utc": utc("2026-10-21 07:30:00"), "status": "scalped", "gross": 1.0}
        b = {"entry_utc": utc("2026-10-21 09:00:00"), "close_utc": utc("2026-10-21 11:00:00"), "status": "scalped", "gross": 1.0}
        c = {"entry_utc": utc("2026-10-21 10:00:00"), "close_utc": utc("2026-10-21 13:00:00"), "status": "rolled", "gross": -5.0}
        out = sh.in_era([a, b, c], utc("2026-10-21 08:00:00"), utc("2026-10-21 12:00:00"))
        self.assertEqual(len(out), 2)
        got = {L["entry_utc"].hour: (L["status"], L["gross"]) for L in out}
        self.assertEqual(got[9], ("scalped", 1.0))
        self.assertEqual(got[10], ("open", None))


class Summary(unittest.TestCase):
    def test_summary_counts_net_and_roll_rate(self):
        # Three closed layers inside the window (scalps +0.7, +0.7, roll -4.0) and one open; commission 0.08.
        # closed 3; net = 0.7 + 0.7 - 4.0 - 3 x 0.08 = -2.84; per closed layer -0.94667; roll rate 1/3.
        mk = lambda st, g: {"entry_utc": utc("2026-10-21 12:00:00"), "status": st, "gross": g}
        s = sh.summarise([mk("scalped", 0.7), mk("scalped", 0.7), mk("rolled", -4.0), mk("open", None)], 0.08)
        self.assertEqual(s["entered"], 4)
        self.assertEqual(s["closed"], 3)
        self.assertEqual(s["scalped"], 2)
        self.assertEqual(s["rolled"], 1)
        self.assertEqual(s["open"], 1)
        self.assertAlmostEqual(s["gross"], -2.6)
        self.assertAlmostEqual(s["net"], -2.84)
        self.assertAlmostEqual(s["net_per_closed"], -2.84 / 3)
        self.assertAlmostEqual(s["roll_rate"], 1 / 3)

    def test_summary_of_nothing_closed(self):
        s = sh.summarise([{"entry_utc": utc("2026-10-21 12:00:00"), "status": "open", "gross": None}], 0.06)
        self.assertEqual(s["closed"], 0)
        self.assertIsNone(s["net_per_closed"])
        self.assertIsNone(s["roll_rate"])


class Verdict(unittest.TestCase):
    # Per era: net per closed layer inside / outside the window, roll rate inside / outside, the pairs where
    # outside is worse on net per closed layer (worse_out) and where inside is (worse_in), of the pairs counted.
    # An era has a direction when net AND roll rate agree AND at least half the counted pairs agree.
    def test_two_of_three_eras_same_direction_and_most_pairs_is_worth_a_replay(self):
        eras = {"A": dict(net_in=0.20, net_out=-0.10, rr_in=0.05, rr_out=0.09, worse_out=5, worse_in=2, counted=7),
                "B": dict(net_in=0.15, net_out=0.02, rr_in=0.04, rr_out=0.07, worse_out=6, worse_in=3, counted=9),
                "D1": dict(net_in=0.05, net_out=0.10, rr_in=0.06, rr_out=0.05, worse_out=2, worse_in=4, counted=6)}
        self.assertEqual(sh.verdict(eras), ("WORTH A REPLAY", "OUTSIDE WORSE"))

    def test_split_eras_is_not_worth_it(self):
        # A: outside worse. B: inside worse. D1: mixed (inside worse on net, but its roll rate is lower):
        # no direction. One era each way: not worth it.
        eras = {"A": dict(net_in=0.20, net_out=-0.10, rr_in=0.05, rr_out=0.09, worse_out=5, worse_in=2, counted=7),
                "B": dict(net_in=0.05, net_out=0.15, rr_in=0.07, rr_out=0.04, worse_out=2, worse_in=7, counted=9),
                "D1": dict(net_in=0.05, net_out=0.10, rr_in=0.05, rr_out=0.06, worse_out=2, worse_in=4, counted=6)}
        self.assertEqual(sh.verdict(eras), ("NOT WORTH IT", None))

    def test_direction_needs_net_AND_roll_rate(self):
        # Outside worse on net in A and B, but its roll rate is LOWER in B: B does not count.
        eras = {"A": dict(net_in=0.20, net_out=-0.10, rr_in=0.05, rr_out=0.09, worse_out=5, worse_in=2, counted=7),
                "B": dict(net_in=0.15, net_out=0.02, rr_in=0.07, rr_out=0.04, worse_out=6, worse_in=3, counted=9),
                "D1": dict(net_in=0.05, net_out=0.10, rr_in=0.06, rr_out=0.05, worse_out=2, worse_in=4, counted=6)}
        self.assertEqual(sh.verdict(eras), ("NOT WORTH IT", None))

    def test_most_pairs_means_at_least_half(self):
        # A and B agree (outside worse) but in B only 4 of 9 pairs agree: under half: B does not count.
        eras = {"A": dict(net_in=0.20, net_out=-0.10, rr_in=0.05, rr_out=0.09, worse_out=5, worse_in=2, counted=7),
                "B": dict(net_in=0.15, net_out=0.02, rr_in=0.04, rr_out=0.07, worse_out=4, worse_in=5, counted=9),
                "D1": dict(net_in=0.05, net_out=0.10, rr_in=0.06, rr_out=0.05, worse_out=2, worse_in=4, counted=6)}
        self.assertEqual(sh.verdict(eras), ("NOT WORTH IT", None))

    def test_inside_worse_counts_too(self):
        # The mirror: outside better in A and B (net and roll rate), most pairs: worth a replay, INSIDE WORSE.
        eras = {"A": dict(net_in=-0.10, net_out=0.20, rr_in=0.09, rr_out=0.05, worse_out=1, worse_in=6, counted=7),
                "B": dict(net_in=0.02, net_out=0.15, rr_in=0.07, rr_out=0.04, worse_out=2, worse_in=7, counted=9),
                "D1": dict(net_in=0.05, net_out=0.10, rr_in=0.06, rr_out=0.06, worse_out=3, worse_in=3, counted=6)}
        self.assertEqual(sh.verdict(eras), ("WORTH A REPLAY", "INSIDE WORSE"))


if __name__ == "__main__":
    unittest.main(verbosity=1)
