"""Synthetic tests for the ejection value study. Expected values are derived
by hand in the comments, never read back from the code.

    python -m unittest research/ejection_value/test_ejection_value.py -v
"""
import datetime as dt
import json
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from ev_book import (DepthTimeline, build_layers, calibrate_hidden, caps_by_instance,  # noqa: E402
                     depth_timelines, eject_anchors, mark_ejections, side_stats)
from ev_controls import control_rate  # noqa: E402
from ev_data import Bars, fleet_of, load_bars_file, load_export, symbol_of  # noqa: E402
from ev_episodes import (build_chains, collect_ejections, counterfactual,  # noqa: E402
                         midnights_between, night_multiplier, score_chain)

OFF = 10800
T0 = dt.datetime(2026, 9, 29, 8, 0, tzinfo=dt.timezone.utc).timestamp()   # Tue 08:00Z
INST = "GRIND_EURGBP_OPTB"


def iso(t):
    return dt.datetime.fromtimestamp(t, dt.timezone.utc).isoformat(sep=" ")


def msc(t_utc):
    return int((t_utc + OFF) * 1000)


class Fx:
    """Builds export rows for one instance."""

    def __init__(self, inst=INST):
        self.inst = inst
        self.rows = {"fill_logs": [], "ea_events": [], "config_events": [], "scalp_history": []}
        self.nid = 1
        self.pos = 1000
        self.order = 5000

    def _id(self):
        self.nid += 1
        return self.nid

    def config(self, t, max_layers=8, account=53066709):
        self.rows["config_events"].append({"table": "config_events", "id": self._id(),
            "instance_id": self.inst, "event": "INIT", "max_layers": max_layers,
            "account_login": account, "received_at": iso(t)})

    def ent(self, t, side, price, idx=0, comm=-0.04):
        self.pos += 1
        self.rows["fill_logs"].append({"table": "fill_logs", "id": self._id(),
            "instance_id": self.inst, "entry_type": "IN", "role": "ENT", "side": side,
            "layer_index": idx, "position_id": self.pos, "order_ticket": self.pos + 1,
            "deal_price": price, "deal_time_broker_msc": msc(t), "commission": comm,
            "profit": 0.0, "swap": 0.0, "received_at": iso(t)})
        return self.pos

    def close(self, t, pos, side, exit_price, profit, swap=0.0, comm=-0.04, idx=0):
        """EXT fill opens an opposite position, then a close-by pair."""
        self.pos += 1
        ext_pos = self.pos
        self.order += 1
        self.rows["fill_logs"].append({"table": "fill_logs", "id": self._id(),
            "instance_id": self.inst, "entry_type": "IN", "role": "EXT", "side": side,
            "layer_index": idx, "position_id": ext_pos, "order_ticket": self.order,
            "deal_price": exit_price, "deal_time_broker_msc": msc(t), "commission": comm,
            "profit": 0.0, "swap": 0.0, "received_at": iso(t)})
        self.order += 1
        for p, pr, sw in ((pos, profit, swap), (ext_pos, 0.0, 0.0)):
            self.rows["fill_logs"].append({"table": "fill_logs", "id": self._id(),
                "instance_id": self.inst, "entry_type": "OUT_BY", "role": None, "side": None,
                "layer_index": None, "position_id": p, "order_ticket": self.order,
                "deal_price": exit_price, "deal_time_broker_msc": msc(t), "commission": 0.0,
                "profit": pr, "swap": sw, "received_at": iso(t)})

    def eject(self, t_acc, t_fill, ticket, raw, entry):
        self.rows["ea_events"].append({"table": "ea_events", "id": self._id(),
            "instance_id": self.inst, "code": "EJECT_ACCEPTED", "ticket": ticket,
            "detail": {"raw": raw, "entry": entry, "source": "auto", "offset": 0.0, "accrued": 0.0},
            "received_at": iso(t_acc)})
        self.rows["ea_events"].append({"table": "ea_events", "id": self._id(),
            "instance_id": self.inst, "code": "EJECT_FILLED", "ticket": ticket,
            "detail": {}, "received_at": iso(t_fill)})

    def carry(self, t, swap_long, swap_short, point=1e-5):
        self.rows["ea_events"].append({"table": "ea_events", "id": self._id(),
            "instance_id": self.inst, "code": "CARRY_SNAPSHOT", "ticket": 0,
            "detail": {"swap_long": swap_long, "swap_short": swap_short, "rollover3days": 3,
                       "swap_mode": 1, "point": point}, "received_at": iso(t)})

    def export(self):
        return {k: sorted(v, key=lambda r: r["id"]) for k, v in self.rows.items()}


def flat_bars(t_start, n, bid, spread=0, point=1e-5, digits=5):
    b = Bars("EURGBP", 53071896, "ICMarketsSC-Demo", digits, point, OFF, t_start + n * 60)
    for i in range(n):
        b.t.append(t_start + 60 * i)
        b.o.append(bid); b.h.append(bid); b.l.append(bid); b.c.append(bid)
        b.spread.append(spread)
    return b


def set_bar(b, t, low=None, high=None, close=None, spread=None):
    i = b.index_at_or_after(t)
    if low is not None:
        b.l[i] = low
    if high is not None:
        b.h[i] = high
    if close is not None:
        b.c[i] = close
    if spread is not None:
        b.spread[i] = spread


class TestData(unittest.TestCase):
    def test_ids(self):
        self.assertEqual(fleet_of("GRIND_EURGBP_OPTB"), "B")
        self.assertEqual(fleet_of("GRIND_NZDCAD_ALTC"), "C")
        self.assertEqual(fleet_of("GRIND_AUDNZD_ALT"), "A")
        self.assertEqual(symbol_of("GRIND_AUDNZD_ALTB"), "AUDNZD")

    def test_bar_file_utc_and_partial_bar(self):
        # server 2026.09.28 00:00 = unix-as-UTC 1790553600 -> real UTC 1790542800
        body = ("# symbol=GBPUSD account=53071896 server=ICMarketsSC-Demo digits=5 "
                "point=0.00001000 server_minus_gmt_s=10800 from=2026.09.27 00:00 to=2026.09.28 00:02\n"
                "time_server,time_unix_server,open,high,low,close,spread_points,tick_volume\n"
                "2026.09.28 00:00,1790553600,1.3,1.31,1.29,1.305,5,10\n"
                "2026.09.28 00:01,1790553660,1.305,1.306,1.304,1.305,6,10\n"
                "2026.09.28 00:02,1790553720,1.305,1.306,1.304,1.305,7,3\n")
        with tempfile.TemporaryDirectory() as d:
            p = os.path.join(d, "bars_53071896_GBPUSD.csv")
            with open(p, "w", encoding="utf-8") as fh:
                fh.write(body)
            b = load_bars_file(p)
        self.assertEqual(len(b), 2)                      # the 00:02 bar was forming: dropped
        self.assertEqual(b.t[0], 1790542800.0)
        self.assertAlmostEqual(b.pip, 0.0001)
        self.assertAlmostEqual(b.ask_low(0), 1.29 + 5e-5)

    def test_export_dedup_and_bom(self):
        rows = ['{"table": "_meta", "days": 7}',
                '{"table": "fill_logs", "id": 3, "x": 1}',
                '{"table": "fill_logs", "id": 2, "x": 2}']
        with tempfile.TemporaryDirectory() as d:
            p1, p2 = os.path.join(d, "a.jsonl"), os.path.join(d, "b.jsonl")
            with open(p1, "w", encoding="utf-8-sig") as fh:
                fh.write("\n".join(rows) + "\n")
            with open(p2, "w", encoding="utf-8") as fh:
                fh.write(rows[1] + "\n")
            ex = load_export([p1, p2])
        self.assertEqual([r["id"] for r in ex["fill_logs"]], [2, 3])
        self.assertEqual(len(ex["_meta"]), 1)


class TestBook(unittest.TestCase):
    def test_layer_net_all_in(self):
        f = Fx()
        p = f.ent(T0, "L", 0.86000)
        f.close(T0 + 600, p, "L", 0.86050, profit=0.67, swap=-0.02)
        lay = build_layers(f.export())[INST][p]
        # 0.67 - 0.02 (close-by) - 0.04 (EXT IN) - 0.04 (ENT IN) = 0.57
        self.assertAlmostEqual(lay.net(), 0.57)
        self.assertTrue(lay.net_complete)
        self.assertEqual(lay.side, "L")

    def test_closeby_with_missing_exit_in_deal(self):
        # 28 Sep GBPUSD_OPTC: the exit fill arrived in a resync with no event,
        # so fill_logs has the layer's ENT IN deal and both OUT_BY legs only
        f = Fx()
        p = f.ent(T0, "L", 1.32686)
        f.close(T0 + 600, p, "L", 1.32785, profit=0.99)
        ex = f.export()
        ex["fill_logs"] = [r for r in ex["fill_logs"] if r.get("role") != "EXT"]
        lay = build_layers(ex)[INST][p]
        self.assertTrue(lay.closed)
        # 0.99 (close-by) - 0.04 (ENT IN); the missing EXT commission counts 0
        self.assertAlmostEqual(lay.net(), 0.95)

    def test_closeby_with_both_in_deals_missing_is_skipped(self):
        import ev_book
        f = Fx()
        p = f.ent(T0, "L", 1.32686)
        f.close(T0 + 600, p, "L", 1.32785, profit=0.99)
        ex = f.export()
        ex["fill_logs"] = [r for r in ex["fill_logs"] if r["entry_type"] != "IN"]
        L = build_layers(ex)
        self.assertEqual(len(L.get(INST, {})), 0)
        self.assertEqual(len(ev_book.UNMATCHED_CLOSEBYS), 1)

    def test_depth_and_hidden(self):
        f = Fx()
        f.config(T0 - 3600)
        a = f.ent(T0 + 60, "L", 0.86000, 0)
        f.ent(T0 + 120, "L", 0.85970, 1)
        f.close(T0 + 180, a, "L", 0.86050, 0.6)
        ex = f.export()
        L = build_layers(ex)
        tls = depth_timelines(L, T0, T0 + 600)
        tl = tls[(INST, "L")]
        # visible: +1 @60, +1 @120, -1 @180 -> depth before 150 is 2
        self.assertEqual(tl.depth_before(T0 + 150), 2)
        # an anchor says depth 8 at 150: 6 layers were open all window
        hidden, spread = calibrate_hidden(tl, [(T0 + 150, 8)])
        self.assertEqual((hidden, spread), (6, 0))
        self.assertEqual(tl.depth_before(T0 + 300), 7)

    def test_side_stats_hours_at_cap(self):
        # cap 2; depth 0 [0,60), 1 [60,120), 2 [120,180), 1 [180,600)
        f = Fx()
        f.config(T0 - 3600, max_layers=2)
        a = f.ent(T0 + 60, "L", 0.86000, 0)
        f.ent(T0 + 120, "L", 0.85970, 1)
        f.close(T0 + 180, a, "L", 0.86050, 0.6)
        ex = f.export()
        L = build_layers(ex)
        tls = depth_timelines(L, T0, T0 + 600)
        s = side_stats(L, tls, caps_by_instance(ex), T0, T0 + 600)[(INST, "L")]
        self.assertAlmostEqual(s["hours_at_cap"], 60 / 3600.0)
        self.assertAlmostEqual(s["hours_below_cap"], 540 / 3600.0)
        self.assertEqual((s["scalps_at"], s["scalps_below"]), (1, 0))   # closed from depth 2

    def test_eject_anchor_side(self):
        f = Fx()
        f.config(T0 - 3600)
        f.eject(T0, T0 + 5, 1234, raw=0.86050, entry=0.86000)   # raw above entry: long
        f.eject(T0, T0 + 5, 1235, raw=0.85950, entry=0.86000)   # below: short
        ex = f.export()
        an = eject_anchors(ex, caps_by_instance(ex))
        self.assertEqual(an[(INST, "L")], [(T0, 8)])
        self.assertEqual(an[(INST, "S")], [(T0, 8)])


class TestCarry(unittest.TestCase):
    def test_multiplier(self):
        self.assertEqual(night_multiplier(dt.date(2026, 9, 29)), 1)    # Tue
        self.assertEqual(night_multiplier(dt.date(2026, 9, 30)), 3)    # Wed
        self.assertEqual(night_multiplier(dt.date(2026, 10, 3)), 0)    # Sat
        self.assertEqual(night_multiplier(dt.date(2026, 10, 4)), 0)    # Sun

    def test_midnights(self):
        # server midnight at the end of Tue 29 Sep = 21:00Z Tue
        m = midnights_between(T0, T0 + 24 * 3600, OFF)
        self.assertEqual(len(m), 1)
        self.assertEqual(m[0][0], dt.datetime(2026, 9, 29, 21, tzinfo=dt.timezone.utc).timestamp())
        self.assertEqual(m[0][1], dt.date(2026, 9, 29))


def _ejected_long(f, open_t, fill_t, entry, close_price, profit, swap=0.0, idx=0):
    p = f.ent(open_t, "L", entry, idx)
    f.eject(fill_t - 30, fill_t, p, raw=round(entry + 0.0005, 5), entry=entry)
    f.close(fill_t, p, "L", close_price, profit, swap=swap, idx=idx)
    return p


class TestCounterfactual(unittest.TestCase):
    def _one(self, bars_mut, swap_long=0.0, h=24, fill_t=None):
        fill_t = fill_t or T0
        f = Fx()
        f.config(T0 - 86400)
        f.carry(T0 - 3600, swap_long, 0.0)
        # long at 0.86000, exit 5 pips -> X0 0.86050; ejected at 0.85700 (-30 pips)
        # value per price from the close: profit -4.00 over -0.00300 -> 1333.33 $/unit
        _ejected_long(f, T0 - 7200, fill_t, 0.86000, 0.85700, -4.00)
        ex = f.export()
        L = build_layers(ex)
        mark_ejections(L, ex)
        ej = collect_ejections(ex, L)[0]
        b = flat_bars(fill_t - 600, 60 * 50, 0.85700)
        bars_mut(b)
        from ev_episodes import carry_rates
        r = counterfactual(ej, b, carry_rates(ex).get(INST), h, OFF)
        return ej, r

    def test_long_hit(self):
        # bid reaches 0.86051 three hours after the fill
        ej, r = self._one(lambda b: set_bar(b, T0 + 3 * 3600, high=0.86051))
        self.assertEqual(r["status"], "ok")
        self.assertTrue(r["hit"])
        self.assertEqual(r["t_hit"], T0 + 3 * 3600)
        self.assertTrue(r["borderline"])                 # 0.1 pip beyond X: borderline
        # E = -4.00 - 0.04 (EXT) - 0.04 (ENT) = -4.08
        self.assertAlmostEqual(r["E"], -4.08)
        # H = (0.86050 - 0.86000) * 1333.33 - 0.08 = 0.6667 - 0.08 = 0.5867
        self.assertAlmostEqual(r["H"], 0.5 / 0.75 - 0.08, places=4)
        # worst bid 0.85700 = the eject price: no excursion beyond it
        self.assertAlmostEqual(r["mae_beyond_eject"], 0.0)

    def test_long_no_hit_mark_and_mae(self):
        def mut(b):
            set_bar(b, T0 + 3600, low=0.85500)          # 20 pips worse than the eject
            set_bar(b, T0 + 24 * 3600 - 60, close=0.85800)
        ej, r = self._one(mut)
        self.assertFalse(r["hit"])
        # MTM at 24 h: (0.85800 - 0.86000) * 1333.33 - 0.04 = -2.6667 - 0.04
        self.assertAlmostEqual(r["H"], -0.002 / 0.003 * 4 - 0.04, places=4)
        # beyond the eject: (0.85500 - 0.85700) * 1333.33 = -2.6667
        self.assertAlmostEqual(r["mae_beyond_eject"], -0.002 / 0.003 * 4, places=4)

    def test_carry_moves_exit_away(self):
        # swap_long -10 points a night: X moves up 10 points (1 pip) at 21:00Z.
        # bid touches 0.86052 at 22:00Z: past X0 (0.86050) but short of X (0.86060)
        ej, r = self._one(lambda b: set_bar(b, T0 + 14 * 3600, high=0.86052), swap_long=-10.0)
        self.assertFalse(r["hit"])
        self.assertEqual(r["nights"], 1)
        # without carry the same touch is a hit
        ej2, r2 = self._one(lambda b: set_bar(b, T0 + 14 * 3600, high=0.86052), swap_long=0.0)
        self.assertTrue(r2["hit"])

    def test_no_data_when_bars_end_early(self):
        def cut(b):
            n = 60 * 5                                     # keep ~5 h of bars
            del b.t[n:], b.o[n:], b.h[n:], b.l[n:], b.c[n:], b.spread[n:]
            b.to_utc = b.t[-1] + 60
        ej, r = self._one(cut)
        self.assertEqual(r["status"], "no_data")

    def test_short_uses_ask(self):
        f = Fx()
        f.config(T0 - 86400)
        f.carry(T0 - 3600, 0.0, 0.0)
        p = f.ent(T0 - 7200, "S", 0.86000)
        f.eject(T0 - 30, T0, p, raw=0.85950, entry=0.86000)
        f.close(T0, p, "S", 0.86300, -4.00)
        ex = f.export()
        L = build_layers(ex)
        mark_ejections(L, ex)
        ej = collect_ejections(ex, L)[0]
        b = flat_bars(T0 - 600, 60 * 30, 0.86300, spread=5)
        # bid low 0.85948 with spread 5 points: ask 0.85953 > X 0.85950 -> no hit
        set_bar(b, T0 + 3600, low=0.85948)
        from ev_episodes import carry_rates
        r = counterfactual(ej, b, carry_rates(ex).get(INST), 24, OFF)
        self.assertFalse(r["hit"])
        self.assertTrue(r["borderline"])                   # missed by 0.3 pip


class TestChains(unittest.TestCase):
    def test_chain_and_freed_slot_by_depth(self):
        # cap 2. Two layers L0 (0.86000) and L1 (0.85970): at cap.
        # t+0: L0 ejected (depth 1). t+10m: new add N1 (depth 2): the held
        # world holds L0 (k_open 1): 1 + 1 >= 2 -> FREED. t+20m: N1 scalps.
        # t+30m: L1 scalps in both worlds (depth 0). t+40m: add N2 at depth 0:
        # 0 + 1 = 1 < 2 -> NOT freed (the held world would add too).
        f = Fx()
        f.config(T0 - 86400, max_layers=2)
        f.carry(T0 - 3600, 0.0, 0.0)
        l0 = f.ent(T0 - 7200, "L", 0.86000, 0)
        l1 = f.ent(T0 - 3600, "L", 0.85970, 1)
        f.eject(T0 - 30, T0, l0, raw=0.86050, entry=0.86000)
        f.close(T0, l0, "L", 0.85700, -4.00)
        n1 = f.ent(T0 + 600, "L", 0.85690, 1)
        f.close(T0 + 1200, n1, "L", 0.85740, 0.67)
        f.close(T0 + 1800, l1, "L", 0.86020, 0.67)
        n2 = f.ent(T0 + 2400, "L", 0.85800, 0)
        ex = f.export()
        L = build_layers(ex)
        mark_ejections(L, ex)
        caps = caps_by_instance(ex)
        tls = depth_timelines(L, T0 - 86400, T0 + 86400)
        ejs = collect_ejections(ex, L)
        b = flat_bars(T0 - 600, 60 * 30, 0.85700)       # never back to X: no hit, 30 h
        from ev_episodes import carry_rates
        for e in ejs:
            counterfactual(e, b, carry_rates(ex).get(INST), 24, OFF)
        chains = build_chains(ejs, 24)
        self.assertEqual(len(chains), 1)
        ch = score_chain(chains[0], L, tls[(INST, "L")], caps, b, 24)
        self.assertEqual(ch["freed_layers"], 1)
        # F_closed = N1's net: 0.67 - 0.04 - 0.04 = 0.59
        self.assertAlmostEqual(ch["F_closed"], 0.59)
        self.assertNotIn(n2, [e.ticket for e in ch["members"]])

    def test_two_ejections_one_chain(self):
        f = Fx()
        f.config(T0 - 86400)
        f.carry(T0 - 3600, 0.0, 0.0)
        _ejected_long(f, T0 - 9000, T0, 0.86000, 0.85700, -4.00)
        _ejected_long(f, T0 - 8000, T0 + 3600, 0.85960, 0.85690, -3.60, idx=1)
        _ejected_long(f, T0 - 7000, T0 + 30 * 3600, 0.85920, 0.85600, -4.26, idx=2)
        ex = f.export()
        L = build_layers(ex)
        mark_ejections(L, ex)
        ejs = collect_ejections(ex, L)
        b = flat_bars(T0 - 600, 60 * 60, 0.85700)
        from ev_episodes import carry_rates
        for e in ejs:
            counterfactual(e, b, carry_rates(ex).get(INST), 24, OFF)
        chains = build_chains(ejs, 24)
        # 2nd fill (+1 h) is inside the 1st's 24 h: same chain; the 3rd (+30 h)
        # comes after the chain end (+25 h): a new chain
        self.assertEqual([len(c["members"]) for c in chains], [2, 1])


class TestControls(unittest.TestCase):
    def test_control_rate_overlap(self):
        capped = DepthTimeline(0, 7200, [(0, 1), (0, 1), (1800, -1)])       # cap 2: at cap [0,1800)
        ctrl = DepthTimeline(0, 7200, [(0, 1), (900, 1), (3600, -1)])        # below 2 in [0,900)
        f = Fx("GRIND_EURGBP_OPTC")
        p = f.ent(-100, "L", 0.86)
        f.close(600, p, "L", 0.8605, 0.6)                                    # inside the overlap
        q = f.ent(-100, "L", 0.86)
        f.close(1000, q, "L", 0.8605, 0.6)                                   # control at cap: out
        L = build_layers(f.export())
        r = control_rate(capped, [(-1, 2)], ctrl, [(-1, 2)], L["GRIND_EURGBP_OPTC"], "L")
        self.assertAlmostEqual(r["hours"], 900 / 3600.0)
        self.assertEqual(r["scalps"], 1)


if __name__ == "__main__":
    unittest.main()
