"""Tests for measure_timing.py (hand-derived; run: python -B -m unittest test_measure_timing).

The broker and EA timing of the calibration window, measured within one clock or as
durations (the EA's clock and the broker's differ by a drifting offset; durations do not):
- M1 a send's duration (send_logs duration_ms; ok rows), per action;
- M2 lam = deal time F - the first touching tick in [F - 2 s, F + 0.5 s] (T0's rule);
- M3 ENT reaction = the first send starting in [fill log - 50 ms, fill log + 2 s], minus the
  fill log time (a send starts at ea_time_ms - duration_ms: ea_time_ms is stamped after
  OrderSend returns);
- M4 close-by reaction residual = (the close-by's start - fill log) - (durations of sends
  that start in [fill log - 50 ms, close-by start)) - (first tick after F - F);
- M5 close-by completion = the first OUT_BY of the position at or after F - (F + close-by
  start - fill log + its duration);
- M6 the gap from the close-by's end to the next send's start (within 2 s);
- M0 the clock offset: fill log - (deal time - 3 h) per IN fill (reported, never used);
- M1b sends over 1 s (ok rows): count of the window's sends;
- M8 the deal's price: points better than the limit; whether it equals the executable side
  (ask for a buy, bid for a sell) of the newest tick at or before F; and of the newest tick
  at or before (first touch + lam), and by how many points the deal is better for us than
  that price (buy: model - deal; sell: deal - model);
- M7 L0 after the close-by: (the first PENDING / MODIFY ENT layer 0 of the same side starting
  in [close-by end, + 120 s]) - fill log - (t2 - F), t2 = the first tick after
  F + (close-by end - fill log).
"""
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import measure_timing as mt  # noqa: E402

E = 1791000000000      # an EA-clock ms
F = 1791010800000      # a broker (server) ms


def send(end, dur, action, role=None, side=None, layer=None, pos=None, by=None, ok=True):
    return {"ea_time_ms": end, "duration_ms": dur, "action": action, "role": role,
            "side": side, "layer_index": layer, "position_ticket": pos,
            "position_by_ticket": by, "ok": ok}


def fill(ea, broker, entry, role, side, pos, price=1.10000, layer=0):
    return {"ea_time_ms": ea, "deal_time_broker_msc": broker, "entry_type": entry,
            "role": role, "side": side, "position_id": pos, "order_price_open": price,
            "layer_index": layer}


class TestQuantiles(unittest.TestCase):
    def test_summary(self):
        # 10 values 1..10: p10 = v[1] = 2, p25 = v[2] = 3, median = v[5] = 6, p75 = v[7] = 8,
        # p90 = v[9] = 10 (index int(n x q)), max 10
        s = mt.summary(list(range(10, 0, -1)))
        self.assertEqual(s, {"n": 10, "p10": 2, "p25": 3, "p50": 6, "p75": 8, "p90": 10, "max": 10})

    def test_empty(self):
        self.assertEqual(mt.summary([])["n"], 0)


class TestDurations(unittest.TestCase):
    def test_by_action_ok_only(self):
        rows = [send(E, 287, "PENDING"), send(E, 290, "PENDING"), send(E, 43, "REMOVE"),
                send(E, 4000, "MODIFY", ok=False), send(E, 288, "MODIFY")]
        d = mt.durations(rows)
        self.assertEqual(sorted(d["PENDING"]), [287, 290])
        self.assertEqual(d["REMOVE"], [43])
        self.assertEqual(d["MODIFY"], [288])        # the failed MODIFY is left out


class TestLam(unittest.TestCase):
    def test_first_touch_buy_and_sell(self):
        # buy (L ENT) at 1.10000: ticks ask 1.10010 at F-3000 (outside), 1.10000 at F-261
        # (touch), 1.09990 at F-100 -> lam 261
        t = mt.Ticks([F - 3000, F - 261, F - 100], [1.09995, 1.09980, 1.09990],
                     [1.10010, 1.10000, 1.09990])
        self.assertEqual(mt.lam(t, fill(E, F, "IN", "ENT", "L", 1, 1.10000)), 261)
        # sell (L EXT) at 1.09990: bid 1.09990 first at F-100 -> 100
        self.assertEqual(mt.lam(t, fill(E, F, "IN", "EXT", "L", 1, 1.09990)), 100)

    def test_no_touch(self):
        t = mt.Ticks([F - 3000], [1.0], [1.0])
        self.assertIsNone(mt.lam(t, fill(E, F, "IN", "ENT", "L", 1, 0.9)))


class TestReactions(unittest.TestCase):
    def setUp(self):
        # ticks (broker ms): F-500, F+340 (first after F), F+500 (inside the close-by's
        # send, which runs F+345 - F+639), F+700 (first after it), F+1100
        self.t = mt.Ticks([F - 500, F + 340, F + 500, F + 700, F + 1100], [1.1] * 5, [1.1] * 5)

    def test_ent_reaction(self):
        sends = [send(E - 300, 287, "PENDING"),            # starts E-587: before the window
                 send(E + 44, 43, "REMOVE"),               # starts E+1
                 send(E + 331, 287, "PENDING", "EXT")]
        self.assertEqual(mt.ent_reaction(sends, fill(E, F, "IN", "ENT", "S", 7)), 1)

    def test_closeby_chain(self):
        f = fill(E, F, "IN", "EXT", "L", 9)
        # close-by starts E+345 (next tick at F+340 + 5 ms), duration 294, ends E+639;
        # one REMOVE starts E+300 (43 ms) before it, so the residual = 345 - 43 - 340 = -38
        sends = [send(E + 343, 43, "REMOVE"),
                 send(E + 639, 294, "CLOSE_BY", pos=9, by=11),
                 send(E + 927, 287, "PENDING", "EXT", "S", 2),      # starts E+640: gap 1
                 send(E + 1350, 287, "PENDING", "ENT", "L", 0)]     # starts E+1063
        archive_outby = {9: [F + 632, F + 640]}
        r = mt.closeby_chain(self.t, sends, f, archive_outby)
        self.assertEqual(r["react_resid"], -38)
        # OUT_BY F+632 - (F + 345 + 294) = -7
        self.assertEqual(r["outby_resid"], -7)
        self.assertEqual(r["next_gap"], 1)
        # L0: start - fill log = 1063; close-by end in the broker frame F + 639: first tick
        # after it F+700 -> 1063 - 700 = 363
        self.assertEqual(r["l0_resid"], 363)

    def test_closeby_names_by_ticket_and_side(self):
        f = fill(E, F, "IN", "EXT", "L", 9)
        sends = [send(E + 639, 294, "CLOSE_BY", pos=11, by=9),          # named as by
                 send(E + 1350, 287, "PENDING", "ENT", "S", 0),          # the other side
                 send(E + 1700, 287, "MODIFY", "ENT", "L", 0)]           # starts E+1413
        r = mt.closeby_chain(self.t, sends, f, {})
        self.assertEqual(r["react_resid"], 5)                           # 345 - 0 - 340
        self.assertIsNone(r["outby_resid"])
        self.assertEqual(r["l0_resid"], 1413 - 700)

    def test_no_closeby(self):
        f = fill(E, F, "IN", "EXT", "L", 9)
        self.assertIsNone(mt.closeby_chain(self.t, [send(E + 300, 43, "REMOVE")], f, {}))


class TestClockAndOutliers(unittest.TestCase):
    def test_clock_offset(self):
        # fill log minus (broker deal time - 3 h): E - (F - 10800000) = E - 1791000000000 = 0;
        # a second fill logged 900 ms before its deal: -900
        fs = [fill(E, F, "IN", "ENT", "L", 1), fill(E + 100, F + 1000, "IN", "EXT", "L", 1)]
        self.assertEqual(sorted(mt.clock_offsets(fs)), [-900, 0])

    def test_over_1s(self):
        rows = [send(E, 287, "PENDING"), send(E, 1001, "MODIFY"), send(E, 1000, "REMOVE"),
                send(E, 5000, "CLOSE_BY", ok=False)]
        self.assertEqual(mt.over_ms(rows, 1000), (1, 3))     # 1001 only; failed rows left out


class TestDealPrice(unittest.TestCase):
    def test_price_classes(self):
        # ticks: F-300 bid/ask 1.09995/1.10000 (touches the buy limit 1.10000),
        # F-39 ask 1.09992 (newest at or before F-300+261 = F-39, and before F)
        t = mt.Ticks([F - 300, F - 39, F + 50], [1.09990, 1.09987, 1.09990],
                     [1.10000, 1.09992, 1.10001])
        better = dict(fill(E, F, "IN", "ENT", "L", 1, 1.10000), deal_price=1.09992)
        c = mt.deal_price_class(t, better, 261)
        # market at F = ask of F-39 = 1.09992 = deal; at touch (F-300) + 261 = F-39: the same
        self.assertEqual(c, {"vs_limit": 8, "at_market_F": True, "at_model": True, "model_pts": 0})
        worse = dict(fill(E, F, "IN", "ENT", "L", 1, 1.10000), deal_price=1.10001)
        c = mt.deal_price_class(t, worse, 261)
        # deal 1 point worse than the limit; market at F is 1.09992, not the deal; model 1.09992
        self.assertEqual(c, {"vs_limit": -1, "at_market_F": False, "at_model": False, "model_pts": -9})

    def test_sell_side(self):
        # a sell (L EXT) at 1.10010: bid 1.10010 at F-300 touches; bid 1.10013 at F-39
        t = mt.Ticks([F - 300, F - 39], [1.10010, 1.10013], [1.10015, 1.10018])
        f = dict(fill(E, F, "IN", "EXT", "L", 1, 1.10010), deal_price=1.10013)
        c = mt.deal_price_class(t, f, 261)
        self.assertEqual(c, {"vs_limit": 3, "at_market_F": True, "at_model": True, "model_pts": 0})

    def test_no_touch(self):
        t = mt.Ticks([F - 3000], [1.0], [2.0])
        f = dict(fill(E, F, "IN", "ENT", "L", 1, 1.5), deal_price=1.5)
        self.assertIsNone(mt.deal_price_class(t, f, 261)["at_model"])


class TestFirstAfter(unittest.TestCase):
    def test_strictly_after(self):
        t = mt.Ticks([F, F + 300], [1.1, 1.1], [1.1, 1.1])
        self.assertEqual(t.first_after(F), F + 300)          # a tick AT F is not after it
        self.assertEqual(t.first_after(F - 1), F)
        self.assertIsNone(t.first_after(F + 300))


class TestWindow(unittest.TestCase):
    def test_in_window(self):
        rows = [{"from_ms": "100", "to_ms": "200"}, {"from_ms": "200", "to_ms": "350"}]
        self.assertEqual(mt.window(rows), (100, 350))


if __name__ == "__main__":
    unittest.main()
