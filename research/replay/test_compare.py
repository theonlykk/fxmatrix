"""Tests for compare.py (hand-derived; run: python -B -m unittest test_compare).

The replay against the archive, replay-calibration-eurusd.md s6-s7 (pre-registered):
- a deal = an IN deal (ENT or EXT); it MATCHES a replay deal when side, role and layer
  agree, the price is within 0.2 pip and the time within 60 s (one to one, same segment);
- T0: a touching tick (ask <= price for a buy, bid >= price for a sell) in
  [fill - 2 s, fill + 0.5 s]; ENT on L and EXT on S are buys;
- T1 (sync runs), per fleet: matched / T0-touchable >= 95%; replay-only <= 5% of the real
  count; a segment failing either is UNPRICED for T2;
- T2 (free runs), per fleet and side over priced segments: S, R and ROLL_ACCEPTED within
  10% (or 1); rho = sum (S + R) e / sum R_eff D, R_eff = R + max(0, -open pips) / (D - e),
  e = exit, D = cap x add, the open book at each segment end; within 0.1; T2 fails when
  UNPRICED segments hold more than 20% of the fleet's real deals.
"""
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import compare as cp  # noqa: E402

T = 1791000000000   # a server ms


def deal(seg, t, side, role, layer, price):
    return {"seg": seg, "t": t, "side": side, "role": role, "layer": layer, "pts": cp.pts(price)}


SEGS = [{"seg_id": 1, "from_ms": T, "to_ms": T + 100000, "add_l": 7.0, "add_s": 6.0,
         "exit_l": 10.0, "exit_s": 9.0, "cap": 8},
        {"seg_id": 2, "from_ms": T + 100000, "to_ms": T + 200000, "add_l": 7.0, "add_s": 7.0,
         "exit_l": 10.0, "exit_s": 10.0, "cap": 8}]


class TestBasics(unittest.TestCase):
    def test_pts(self):
        self.assertEqual(cp.pts("1.13241"), 113241)
        self.assertEqual(cp.pts(1.10003), 110003)

    def test_is_buy(self):
        self.assertTrue(cp.is_buy("L", "ENT"))
        self.assertFalse(cp.is_buy("L", "EXT"))
        self.assertFalse(cp.is_buy("S", "ENT"))
        self.assertTrue(cp.is_buy("S", "EXT"))

    def test_segments_and_seg_of(self):
        rows = [{"seg_id": "7", "from_ms": "100", "to_ms": "200", "add_l": "7.0", "add_s": "6.5",
                 "exit_l": "10.0", "exit_s": "9.0", "cap": "8", "instance": "X"}]
        s = cp.segments(rows)
        self.assertEqual(s, [{"seg_id": 7, "from_ms": 100, "to_ms": 200, "add_l": 7.0,
                              "add_s": 6.5, "exit_l": 10.0, "exit_s": 9.0, "cap": 8}])
        self.assertEqual(cp.seg_of(T, SEGS), 1)
        self.assertEqual(cp.seg_of(T + 99999, SEGS), 1)
        self.assertEqual(cp.seg_of(T + 100000, SEGS), 2)
        self.assertIsNone(cp.seg_of(T + 200000, SEGS))
        self.assertIsNone(cp.seg_of(T - 1, SEGS))

    def test_within(self):
        self.assertTrue(cp.within(11, 10))      # 1 = max(1.0, 1)
        self.assertFalse(cp.within(12, 10))
        self.assertTrue(cp.within(33, 30))      # 10% of 30 = 3
        self.assertFalse(cp.within(34, 30))
        self.assertTrue(cp.within(27, 30))
        self.assertFalse(cp.within(26, 30))
        self.assertTrue(cp.within(1, 0))
        self.assertFalse(cp.within(2, 0))


class TestParse(unittest.TestCase):
    def test_real_deals(self):
        rows = [{"time_ms": str(T + 5), "kind": "ENT", "side": "L", "layer": "2",
                 "price": "1.10000", "position_id": "11", "level": "0.00000"},
                {"time_ms": str(T + 6), "kind": "OUT_BY", "side": "L", "layer": "2",
                 "price": "1.10100", "position_id": "11", "level": "0.00000"},
                {"time_ms": str(T + 100001), "kind": "EXT", "side": "S", "layer": "0",
                 "price": "1.10100", "position_id": "12", "level": "0.00000"},
                {"time_ms": str(T + 7), "kind": "ROLL", "side": "S", "layer": "3",
                 "price": "0.00000", "position_id": "13", "level": "1.11000"},
                {"time_ms": str(T + 300000), "kind": "ENT", "side": "S", "layer": "0",
                 "price": "1.10100", "position_id": "14", "level": "0.00000"}]
        a, b = deal(1, T + 5, "L", "ENT", 2, 1.10000), deal(2, T + 100001, "S", "EXT", 0, 1.10100)
        a["fill_pts"], b["fill_pts"] = a["pts"], b["pts"]
        self.assertEqual(cp.real_deals(rows, SEGS), [a, b])
        # with the orders' prices: pts = the order's price, fill_pts = the deal's.
        got = cp.real_deals(rows, SEGS, {11: cp.pts(1.10009), 12: cp.pts(1.10092), 14: 1})
        self.assertEqual([(d["pts"], d["fill_pts"]) for d in got],
                         [(110009, 110000), (110092, 110100)])
        arch = [{"table": "fill_logs", "entry_type": "IN", "position_id": 11,
                 "order_price_open": 1.10009},
                {"table": "fill_logs", "entry_type": "OUT_BY", "position_id": 11,
                 "order_price_open": 1.2},
                {"table": "scalp_history", "entry_type": "IN", "position_id": 12,
                 "order_price_open": 1.3}]
        self.assertEqual(cp.order_prices(arch), {11: 110009})
        self.assertEqual(cp.real_rolls(rows, SEGS), [{"seg": 1, "side": "S"}])

    def test_replay_deals(self):
        rows = [{"seg_id": "21", "sync_idx": "0", "time_ms": str(T), "deal": "800000001",
                 "order": "9000", "position": "900000001", "entry_type": "0", "deal_type": "0",
                 "role": "EXT", "side": "S", "layer": "0", "price": "1.13151"},
                {"seg_id": "21", "sync_idx": "0", "time_ms": str(T), "deal": "800000002",
                 "order": "7", "position": "1978117505", "entry_type": "3", "deal_type": "0",
                 "role": "ENT", "side": "S", "layer": "0", "price": "1.13151"}]
        self.assertEqual(cp.replay_deals(rows), [deal(21, T, "S", "EXT", 0, 1.13151)])

    def test_replay_events(self):
        ev = [{"seg_id": "21", "sync_idx": "-1", "time_ms": str(T), "kind": "scalp",
               "code": "SCALP_CLOSED", "json": '{"direction":"SHORT","rolled":false}'},
              {"seg_id": "21", "sync_idx": "-1", "time_ms": str(T), "kind": "scalp",
               "code": "SCALP_CLOSED", "json": '{"direction":"LONG","rolled":true}'},
              {"seg_id": "22", "sync_idx": "-1", "time_ms": str(T), "kind": "ea_event",
               "code": "ROLL_ACCEPTED", "json": '{"code":"ROLL_ACCEPTED","detail":{"side":"L"}}'},
              {"seg_id": "22", "sync_idx": "-1", "time_ms": str(T), "kind": "ea_event",
               "code": "ROLL_FILLED", "json": '{"code":"ROLL_FILLED","detail":{"side":"S"}}'}]
        self.assertEqual(cp.replay_scalps(ev), [{"seg": 21, "side": "S", "rolled": False},
                                                {"seg": 21, "side": "L", "rolled": True}])
        self.assertEqual(cp.replay_rolls(ev), [{"seg": 22, "side": "L"}])

    def test_read_events(self):
        import tempfile
        with tempfile.TemporaryDirectory() as d:
            path = os.path.join(d, "ev.csv")
            with open(path, "w", newline="") as f:
                f.write("seg_id,sync_idx,time_ms,kind,code,json\r\n"
                        '21,-1,5,scalp,SCALP_CLOSED,{"direction":"SHORT","rolled":false}\r\n\r\n'
                        "22,3,6,ea_event,,{\"a\":1,\"b\":2}\n")
            self.assertEqual(cp.read_events(path), [
                {"seg_id": "21", "sync_idx": "-1", "time_ms": "5", "kind": "scalp",
                 "code": "SCALP_CLOSED", "json": '{"direction":"SHORT","rolled":false}'},
                {"seg_id": "22", "sync_idx": "3", "time_ms": "6", "kind": "ea_event", "code": "",
                 "json": '{"a":1,"b":2}'}])

    def test_real_scalps(self):
        # close_time_broker is server time; 2026-10-01 09:40:04 server = 1790847604000 ms.
        a = {"table": "scalp_history", "id": 1, "direction": "SHORT", "entry_price": 1.13241,
             "exit_price": 1.13152, "layer_depth": 0, "stack_depth": 1,
             "close_time_broker": "2026-10-01 09:40:04", "rolled": False}
        b = dict(a, id=2)                                   # a duplicate row
        c = dict(a, id=3, direction="LONG", rolled=True, close_time_broker="2026-10-01 09:40:05")
        d = dict(a, id=4, close_time_broker="2026-10-05 00:00:00")   # outside every segment
        segs = [{"seg_id": 5, "from_ms": 1790847604000, "to_ms": 1790847605000, "add_l": 7.0,
                 "add_s": 7.0, "exit_l": 10.0, "exit_s": 10.0, "cap": 8},
                {"seg_id": 6, "from_ms": 1790847605000, "to_ms": 1790847606000, "add_l": 7.0,
                 "add_s": 7.0, "exit_l": 10.0, "exit_s": 10.0, "cap": 8}]
        rows = [a, b, c, d, {"table": "fill_logs"}]
        self.assertEqual(cp.real_scalps(rows, segs), [{"seg": 5, "side": "S", "rolled": False},
                                                      {"seg": 6, "side": "L", "rolled": True}])


class TestReplayOrderPrice(unittest.TestCase):
    # plan 2 (timing = 1): a replay deal's price is R1's market price; its ORDER price is
    # the FILL row of the run's order log for that order ticket. Without an order log (or
    # without a FILL row for the ticket) the deal's own price stands (plan 1's runs, where
    # the two are equal).
    def deal_row(self, order, price):
        return {"seg_id": "1", "time_ms": str(T), "side": "L", "role": "ENT", "layer": "0",
                "entry_type": "0", "order": order, "price": price}

    def test_order_price_from_fill_row(self):
        deals = [self.deal_row("77", "1.09995")]
        orders = [{"seg_id": "1", "time_ms": str(T), "action": "FILL", "ticket": "77", "price": "1.10000"},
                  {"seg_id": "1", "time_ms": str(T), "action": "PLACE", "ticket": "77", "price": "1.10010"}]
        got = cp.replay_deals(deals, orders)
        self.assertEqual(got[0]["pts"], cp.pts(1.10000))

    def test_no_order_log_keeps_deal_price(self):
        got = cp.replay_deals([self.deal_row("77", "1.09995")])
        self.assertEqual(got[0]["pts"], cp.pts(1.09995))

    def test_ticket_reused_in_another_segment(self):
        # tickets restart per segment: the FILL row must be the deal's own segment's
        deals = [self.deal_row("77", "1.09995")]
        orders = [{"seg_id": "1", "time_ms": str(T - 5), "action": "FILL", "ticket": "77", "price": "1.10000"},
                  {"seg_id": "2", "time_ms": str(T), "action": "FILL", "ticket": "77", "price": "1.20000"}]
        self.assertEqual(cp.replay_deals(deals, orders)[0]["pts"], cp.pts(1.10000))

    def test_nearest_fill_row_in_time(self):
        # the same ticket filled twice in a segment: the FILL row nearest the deal's time
        deals = [self.deal_row("77", "1.09995")]
        orders = [{"seg_id": "1", "time_ms": str(T - 300), "action": "FILL", "ticket": "77", "price": "1.10000"},
                  {"seg_id": "1", "time_ms": str(T + 90000), "action": "FILL", "ticket": "77", "price": "1.11111"}]
        self.assertEqual(cp.replay_deals(deals, orders)[0]["pts"], cp.pts(1.10000))

    def test_no_fill_row_keeps_deal_price(self):
        orders = [{"seg_id": "1", "time_ms": str(T), "action": "PLACE", "ticket": "77", "price": "1.10010"}]
        got = cp.replay_deals([self.deal_row("77", "1.09995")], orders)
        self.assertEqual(got[0]["pts"], cp.pts(1.09995))


class TestTicks(unittest.TestCase):
    def setUp(self):
        # (time, bid, ask)
        self.tk = cp.Ticks([T - 2001, T - 2000, T + 500, T + 501],
                           [cp.pts(x) for x in (1.10050, 1.10000, 1.10000, 1.10060)],
                           [cp.pts(x) for x in (1.09990, 1.10010, 1.10020, 1.09980)])

    def test_buy_touch_window(self):
        # buy at 1.10010: the tick at T-2000 (ask 1.10010) touches; T-2001's ask 1.09990 is
        # outside the window.
        self.assertTrue(self.tk.touchable(deal(1, T, "L", "ENT", 0, 1.10010)))
        self.assertFalse(self.tk.touchable(deal(1, T, "L", "ENT", 0, 1.10000)))
        # T+501's ask 1.09980 is outside the window.
        self.assertFalse(self.tk.touchable(deal(1, T, "S", "EXT", 0, 1.09985)))

    def test_sell_touch_window(self):
        # sell at 1.10000: bid 1.10000 at T-2000 and T+500 touch.
        self.assertTrue(self.tk.touchable(deal(1, T, "S", "ENT", 0, 1.10000)))
        # sell at 1.10050: only T-2001 (outside) and T+501 (outside, 1.10060) reach it.
        self.assertFalse(self.tk.touchable(deal(1, T, "L", "EXT", 0, 1.10050)))
        self.assertTrue(self.tk.touchable(deal(1, T + 1, "L", "EXT", 0, 1.10050)))

    def test_touch_reads_the_fill_price(self):
        # a buy whose ORDER is 1.10010 but filled at 1.10000 (price improvement): T0 asks for
        # a touch at the fill price (ask <= 1.10000), none in the window.
        d = deal(1, T, "L", "ENT", 0, 1.10010)
        d["fill_pts"] = cp.pts(1.10000)
        self.assertFalse(self.tk.touchable(d))
        d["fill_pts"] = cp.pts(1.10010)
        self.assertTrue(self.tk.touchable(d))

    def test_touch_order_price_mode(self):
        # plan 2 (K15, GTM2-3): T0 on the ORDER price. The order 1.10010 filled at 1.10000
        # (improvement): the order price is touched at T-2000 (ask 1.10010) -> touchable;
        # the order 1.10000 filled at 1.10010 (worse): no ask <= 1.10000 in the window.
        d = deal(1, T, "L", "ENT", 0, 1.10010)
        d["fill_pts"] = cp.pts(1.10000)
        self.assertTrue(self.tk.touchable(d, "order"))
        self.assertFalse(self.tk.touchable(d, "deal"))
        e = deal(1, T, "L", "ENT", 0, 1.10000)
        e["fill_pts"] = cp.pts(1.10010)
        self.assertFalse(self.tk.touchable(e, "order"))
        self.assertTrue(self.tk.touchable(e, "deal"))
        self.assertTrue(self.tk.touchable(e))              # the default stays the deal price

    def test_mark(self):
        self.assertEqual(self.tk.mark(T + 500), (cp.pts(1.10000), cp.pts(1.10010)))
        self.assertEqual(self.tk.mark(T + 501), (cp.pts(1.10000), cp.pts(1.10020)))
        self.assertIsNone(self.tk.mark(T - 2001))


class TestMatch(unittest.TestCase):
    def test_tolerances(self):
        r = [deal(1, T, "L", "ENT", 1, 1.10000)]
        self.assertEqual(cp.match(r, [deal(1, T - 60000, "L", "ENT", 1, 1.10002)]), {0: 0})
        self.assertEqual(cp.match(r, [deal(1, T + 60000, "L", "ENT", 1, 1.09998)]), {0: 0})
        self.assertEqual(cp.match(r, [deal(1, T - 60001, "L", "ENT", 1, 1.10000)]), {})
        self.assertEqual(cp.match(r, [deal(1, T, "L", "ENT", 1, 1.10003)]), {})
        self.assertEqual(cp.match(r, [deal(1, T, "L", "ENT", 2, 1.10000)]), {})
        self.assertEqual(cp.match(r, [deal(1, T, "L", "EXT", 1, 1.10000)]), {})
        self.assertEqual(cp.match(r, [deal(1, T, "S", "ENT", 1, 1.10000)]), {})
        self.assertEqual(cp.match(r, [deal(2, T, "L", "ENT", 1, 1.10000)]), {})

    def test_one_to_one_nearest(self):
        r = [deal(1, T, "L", "ENT", 1, 1.10000), deal(1, T + 10, "L", "ENT", 1, 1.10000)]
        p = [deal(1, T + 9, "L", "ENT", 1, 1.10000)]
        self.assertEqual(cp.match(r, p), {1: 0})          # nearest in time when only one
        p2 = [deal(1, T + 50, "L", "ENT", 1, 1.10000), deal(1, T - 5, "L", "ENT", 1, 1.10000)]
        self.assertEqual(cp.match(r, p2), {0: 1, 1: 0})

    def test_maximum(self):
        # Real A can take p0 or p1 (p0 nearer); real B only p0. Greedy by time gives one
        # match; the maximum is two (A-p1, B-p0).
        r = [deal(1, T, "L", "ENT", 1, 1.10000), deal(1, T + 70000, "L", "ENT", 1, 1.10000)]
        p = [deal(1, T + 20000, "L", "ENT", 1, 1.10000), deal(1, T - 50000, "L", "ENT", 1, 1.10000)]
        self.assertEqual(cp.match(r, p), {0: 1, 1: 0})


class TestT1(unittest.TestCase):
    def test_summary_and_marks(self):
        # 20 real deals in segment 1, the first not touchable; the replay finds 19 of them
        # (all touchable ones but the 20th) and one more of its own.
        reals = [deal(1, T + 1000 * i, "L", "ENT", i % 8, 1.10000) for i in range(20)]
        touch = [i != 0 for i in range(20)]
        reps = [dict(reals[i]) for i in range(19)] + [deal(1, T + 500, "S", "ENT", 0, 1.2)]
        out = cp.t1(reals, reps, touch)
        s = out["segs"][1]
        self.assertEqual((s["real"], s["touch"], s["matched"], s["matched_touch"],
                          s["replay"], s["replay_only"]), (20, 19, 19, 18, 20, 1))
        tot = out["total"]
        self.assertAlmostEqual(tot["rate"], 18 / 19)
        self.assertAlmostEqual(tot["rate_all"], 19 / 20)
        self.assertAlmostEqual(tot["replay_only_frac"], 1 / 20)
        self.assertFalse(tot["pass"])                     # 94.7% < 95%
        self.assertEqual(out["unpriced"], [1])
        self.assertEqual(out["misses"], [19])
        self.assertEqual(out["extras"], [19])

    def test_pass_at_the_marks(self):
        reals = [deal(1, T + 1000 * i, "L", "ENT", 0, 1.10000) for i in range(20)]
        touch = [True] * 20
        reps = [dict(reals[i]) for i in range(19)] + [deal(1, T, "S", "ENT", 0, 1.2)]
        out = cp.t1(reals, reps, touch)
        self.assertTrue(out["total"]["pass"])             # 19/20 = 95%; 1/20 = 5%
        self.assertEqual(out["unpriced"], [])
        reps2 = reps + [deal(1, T, "S", "ENT", 0, 1.3)]
        out2 = cp.t1(reals, reps2, touch)
        self.assertFalse(out2["total"]["pass"])           # 2/20 replay-only
        self.assertEqual(out2["unpriced"], [1])

    def test_empty_segment(self):
        out = cp.t1([], [deal(3, T, "L", "ENT", 0, 1.1)], [])
        self.assertEqual(out["unpriced"], [3])
        out = cp.t1([], [], [])
        self.assertEqual(out["unpriced"], [])


class TestT2(unittest.TestCase):
    def test_open_pips(self):
        book = [{"side": "L", "pts": cp.pts(1.10100)}, {"side": "L", "pts": cp.pts(1.10000)},
                {"side": "S", "pts": cp.pts(1.09900)}]
        bid, ask = cp.pts(1.10050), cp.pts(1.10060)
        self.assertAlmostEqual(cp.open_pips(book, "L", bid, ask), -5.0 + 5.0)
        self.assertAlmostEqual(cp.open_pips(book, "S", bid, ask), -16.0)

    def test_rho(self):
        self.assertAlmostEqual(cp.rho([(9, 1, 10.0, 56.0, 0.0)]), 100 / 56)
        # open -92 pips over D - e = 46: R_eff = 1 + 2 = 3.
        self.assertAlmostEqual(cp.rho([(9, 1, 10.0, 56.0, -92.0)]), 100 / (3 * 56))
        # an open gain does not reduce R.
        self.assertAlmostEqual(cp.rho([(9, 1, 10.0, 56.0, 40.0)]), 100 / 56)
        # pooled: (100 + 4 * 9) / (56 + 2 * 48)
        self.assertAlmostEqual(cp.rho([(9, 1, 10.0, 56.0, 0.0), (2, 2, 9.0, 48.0, 0.0)]),
                               136 / 152)
        self.assertIsNone(cp.rho([(3, 0, 10.0, 56.0, 0.0)]))

    def test_t2_side_and_fleet(self):
        def part(S, R, A, op):
            return {"S": S, "R": R, "A": A, "open": op}
        geo = {"e": 10.0, "D": 56.0}
        segs = {1: {"L": dict(geo, real=part(20, 2, 2, 0.0), rep=part(22, 2, 3, 0.0)),
                    "S": dict(geo, real=part(10, 1, 1, 0.0), rep=part(30, 1, 1, 0.0))},
                2: {"L": dict(geo, real=part(9, 1, 1, 0.0), rep=part(0, 9, 9, 0.0)),
                    "S": dict(geo, real=part(10, 1, 1, 0.0), rep=part(10, 1, 1, 0.0))}}
        # segment 2 unpriced: left out of the sums.
        out = cp.t2(segs, unpriced=[2], unpriced_share=0.2)
        L, S = out["sides"]["L"], out["sides"]["S"]
        self.assertEqual((L["real"]["S"], L["rep"]["S"], L["real"]["A"], L["rep"]["A"]),
                         (20, 22, 2, 3))
        self.assertTrue(L["S_ok"])
        self.assertTrue(L["R_ok"])
        self.assertTrue(L["A_ok"])                         # 3 vs 2: within 1
        self.assertAlmostEqual(L["rho_real"], 220 / 112)
        self.assertAlmostEqual(L["rho_rep"], 240 / 112)
        self.assertFalse(L["rho_ok"])                      # 0.18 apart
        self.assertFalse(S["S_ok"])
        self.assertFalse(out["pass"])
        self.assertTrue(out["share_ok"])                   # 20% is not more than 20%
        out2 = cp.t2(segs, unpriced=[2], unpriced_share=0.21)
        self.assertFalse(out2["share_ok"])

    def test_t2_pass(self):
        p = {"S": 10, "R": 2, "A": 2, "open": -5.0}
        segs = {1: {"L": {"e": 10.0, "D": 56.0, "real": p, "rep": dict(p)},
                    "S": {"e": 10.0, "D": 56.0, "real": p, "rep": dict(p, S=11)}}}
        out = cp.t2(segs, unpriced=[], unpriced_share=0.0)
        self.assertTrue(out["pass"])
        self.assertFalse(cp.t2(segs, unpriced=[], unpriced_share=0.21)["pass"])
        segs[1]["L"]["rep"] = dict(p, A=4)                 # ROLL_ACCEPTED 4 vs 2 alone
        out = cp.t2(segs, unpriced=[], unpriced_share=0.0)
        self.assertFalse(out["sides"]["L"]["pass"])
        self.assertFalse(out["pass"])
        segs[1]["L"]["rep"] = dict(p)
        segs[1]["S"]["rep"] = dict(p, R=0, open=0.0)
        segs[1]["S"]["real"] = dict(p, R=0, open=0.0)
        self.assertTrue(cp.t2(segs, unpriced=[], unpriced_share=0.0)["pass"])  # rho n/a both
        segs[1]["S"]["rep"] = dict(p, R=1, open=0.0)
        self.assertFalse(cp.t2(segs, unpriced=[], unpriced_share=0.0)["sides"]["S"]["rho_ok"])


if __name__ == "__main__":
    unittest.main()
