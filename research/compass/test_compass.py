"""Synthetic tests for the compass scorer (C91; fleet-d.md s6.5 + s6.8).
Expected values are derived by hand in the comments, never read back.

    python -m unittest research/compass/test_compass.py -v

Guards (pass with the stub too) are marked GUARD in their docstring.
"""
import csv
import datetime as dt
import json
import os
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "ejection_value"))

import compass_score as cs  # noqa: E402
import ev_book  # noqa: E402

OFF = 10800   # server GMT+3


def T(text):
    return cs.utc(text)


def iso(t):
    return dt.datetime.fromtimestamp(t, dt.timezone.utc).isoformat(sep=" ")


def msc(t):
    return int((t + OFF) * 1000)


W1 = (T("2026-10-01T22:00Z"), T("2026-10-02T22:00Z"), 1)   # FTMO Fri 2 Oct
W2 = (T("2026-10-04T22:00Z"), T("2026-10-05T22:00Z"), 1)   # FTMO Mon 5 Oct


class Fx:
    """Export rows (fill_logs, ea_events, config_events) for several instances."""

    def __init__(self):
        self.rows = {"fill_logs": [], "ea_events": [], "config_events": []}
        self.nid = 1
        self.pos = 1000
        self.order = 5000

    def _id(self):
        self.nid += 1
        return self.nid

    def session(self, inst, account, t=T("2026-10-01T06:00Z")):
        sid = "%s-%d" % (inst, account)
        self.rows["config_events"].append({"table": "config_events", "id": self._id(),
            "instance_id": inst, "session_id": sid, "event": "INIT", "max_layers": 8,
            "account_login": account, "received_at": iso(t)})
        return sid

    def layer(self, inst, sid, side, t_open, t_close=None, profit=0.0, comm=-0.035,
              rolled=False, ejected=False):
        """ENT IN at t_open; if t_close: EXT IN + close-by pair. Layer net =
        profit + 2 * comm (ENT and EXT commissions; OUT_BY deals carry none)."""
        self.pos += 1
        lay = self.pos
        self.rows["fill_logs"].append({"table": "fill_logs", "id": self._id(),
            "instance_id": inst, "session_id": sid, "entry_type": "IN", "role": "ENT",
            "side": side, "layer_index": 0, "position_id": lay, "order_ticket": lay + 1,
            "deal_price": 1.0, "deal_time_broker_msc": msc(t_open), "commission": comm,
            "profit": 0.0, "swap": 0.0, "received_at": iso(t_open)})
        if t_close is None:
            return lay
        self.pos += 1
        ext = self.pos
        self.order += 1
        self.rows["fill_logs"].append({"table": "fill_logs", "id": self._id(),
            "instance_id": inst, "session_id": sid, "entry_type": "IN", "role": "EXT",
            "side": side, "layer_index": 0, "position_id": ext, "order_ticket": self.order,
            "deal_price": 1.001, "deal_time_broker_msc": msc(t_close), "commission": comm,
            "profit": 0.0, "swap": 0.0, "received_at": iso(t_close)})
        self.order += 1
        for p, pr in ((lay, profit), (ext, 0.0)):
            self.rows["fill_logs"].append({"table": "fill_logs", "id": self._id(),
                "instance_id": inst, "session_id": sid, "entry_type": "OUT_BY", "role": None,
                "side": None, "layer_index": None, "position_id": p, "order_ticket": self.order,
                "deal_price": 1.001, "deal_time_broker_msc": msc(t_close), "commission": 0.0,
                "profit": pr, "swap": 0.0, "received_at": iso(t_close)})
        if rolled or ejected:
            self.rows["ea_events"].append({"table": "ea_events", "id": self._id(),
                "instance_id": inst, "session_id": sid,
                "code": "ROLL_FILLED" if rolled else "EJECT_FILLED", "ticket": lay,
                "detail": {}, "received_at": iso(t_close)})
        return lay

    def export(self):
        return {k: sorted(v, key=lambda r: r["id"]) for k, v in self.rows.items()}

    def layers(self):
        exp = self.export()
        lay = ev_book.build_layers(exp)
        ev_book.mark_ejections(lay, exp)
        return lay


INST = "GRIND_GBPUSD_OPTD"


def one_side_book():
    """Long side of INST:
      a) open Thu 20:00 (before W1), close Fri 02:00 (in W1), profit 0.90 -> net 0.83
      b) open Fri 10:00, close Sun 21:30 (weekend gap, outside both)  -> not counted
      c) open Mon 01:00, close Mon 05:00, ROLLED, profit -5.00          -> net -5.07
      d) open Mon 10:00, close Tue 01:00 (after W2)                     -> not counted
      e) open Mon 20:00, still open
    Short side: one scalp in W1 (must not leak into the long side)."""
    fx = Fx()
    sid = fx.session(INST, 53077984)
    fx.layer(INST, sid, "L", T("2026-10-01T20:00Z"), T("2026-10-02T02:00Z"), profit=0.90)
    fx.layer(INST, sid, "L", T("2026-10-02T10:00Z"), T("2026-10-04T21:30Z"), profit=0.50)
    fx.layer(INST, sid, "L", T("2026-10-05T01:00Z"), T("2026-10-05T05:00Z"), profit=-5.00, rolled=True)
    fx.layer(INST, sid, "L", T("2026-10-05T10:00Z"), T("2026-10-06T01:00Z"), profit=0.90)
    fx.layer(INST, sid, "L", T("2026-10-05T20:00Z"))
    fx.layer(INST, sid, "S", T("2026-10-02T03:00Z"), T("2026-10-02T04:00Z"), profit=0.90)
    return fx


class TestSideMetrics(unittest.TestCase):
    def setUp(self):
        self.lay = one_side_book().layers()
        self.m = cs.side_metrics(self.lay, INST, "L", [W1, W2], T("2026-10-01T21:00Z"))

    def test_close_time_attribution(self):
        # a and c close inside the windows; b in the weekend gap, d after W2
        self.assertEqual(self.m["scalps"], 1)
        self.assertEqual(self.m["rolls"], 1)
        self.assertEqual(self.m["ejections"], 0)
        self.assertAlmostEqual(self.m["net"], 0.83 - 5.07, places=6)     # -4.24

    def test_per_day_divides_by_window_days(self):
        self.assertEqual(self.m["days"], 2)
        self.assertAlmostEqual(self.m["per_day"], -2.12, places=6)

    def test_entry_split_uses_cutoff(self):
        # cutoff Thu 21:00: a (opened 20:00) is out, c is in -> -5.07, per day -2.535
        self.assertAlmostEqual(self.m["entry_net"], -5.07, places=6)
        self.assertAlmostEqual(self.m["entry_per_day"], -2.535, places=6)

    def test_layer_hours_clipped_to_windows(self):
        # a 22:00->02:00 = 4; b Fri 10:00->22:00 = 12 (weekend outside); c 4;
        # d Mon 10:00->22:00 = 12; e Mon 20:00->22:00 = 2 -> 34
        self.assertAlmostEqual(self.m["layer_hours"], 34.0, places=6)
        self.assertAlmostEqual(self.m["per_hour"], -4.24 / 34.0, places=6)

    def test_open_at_end_and_depth_at_cutoff(self):
        # at Mon 22:00: d (closes Tue) and e open -> 2; at Thu 21:00 only a -> 1
        self.assertEqual(self.m["open_end"], 2)
        self.assertEqual(self.m["depth_at_cutoff"], 1)


def M(per_day, entry_per_day=None, per_hour=0.10):
    return {"per_day": per_day,
            "entry_per_day": per_day if entry_per_day is None else entry_per_day,
            "per_hour": per_hour}


class TestDecide(unittest.TestCase):
    def test_win_lose_repeat(self):
        self.assertEqual(cs.decide(M(3.20), M(2.00), 1.19, "exit")[0], "WIN")      # +1.20
        self.assertEqual(cs.decide(M(0.80), M(2.00), 1.19, "exit")[0], "LOSE")     # -1.20
        self.assertEqual(cs.decide(M(2.50), M(2.00), 1.19, "exit")[0], "REPEAT")   # +0.50

    def test_margin_equal_to_threshold_repeats(self):
        # 3.19 - 2.00 = 1.19 (1.1900000000000002 in floats): not MORE than 1.19
        self.assertEqual(cs.decide(M(3.19), M(2.00), 1.19, "exit")[0], "REPEAT")

    def test_add_gate_entry_split(self):
        # raw +1.50 wins; entry split 0.10 vs 1.80 = -1.70 < -1.19 -> gated for ADD only
        p, c = M(3.50, entry_per_day=0.10), M(2.00, entry_per_day=1.80)
        self.assertEqual(cs.decide(p, c, 1.19, "add")[0], "REPEAT_GATE")
        self.assertEqual(cs.decide(p, c, 1.19, "exit")[0], "WIN")

    def test_add_gate_per_layer_hour(self):
        p, c = M(3.50, per_hour=0.05), M(2.00, per_hour=0.08)
        self.assertEqual(cs.decide(p, c, 1.19, "add")[0], "REPEAT_GATE")
        self.assertEqual(cs.decide(p, c, 1.19, "exit")[0], "WIN")

    def test_add_gate_passes_when_comparator_held_nothing(self):
        p, c = M(3.50, per_hour=0.05), M(2.00, per_hour=None)
        self.assertEqual(cs.decide(p, c, 1.19, "add")[0], "WIN")

    def test_margin_returned(self):
        self.assertAlmostEqual(cs.decide(M(3.20), M(2.00), 1.19, "exit")[1], 1.20, places=9)


class TestThresholds(unittest.TestCase):
    def test_threshold_for(self):
        cfg = cs.load_round(os.path.join(HERE, "round1.json"))
        self.assertAlmostEqual(cs.threshold_for(cfg, "AUDNZD", "L", True), 1.40)
        self.assertAlmostEqual(cs.threshold_for(cfg, "AUDNZD", "S", True), 1.19)
        self.assertAlmostEqual(cs.threshold_for(cfg, "AUDNZD", "L", False), 1.19)
        self.assertAlmostEqual(cs.threshold_for(cfg, "GBPUSD", "L", False), 1.19)


def tiny_round():
    """One plain pair (GBPUSD) and one twin pair (AUDNZD), window W1 only.
    Every layer opens Fri 01:00 and closes Fri 02:00 (1 h, after every cutoff)."""
    cfg = {"threshold": 1.19, "twin_thresholds": {"AUDNZD|L": 1.40},
           "windows": [["2026-10-01T22:00Z", "2026-10-02T22:00Z", 1]],
           "accounts": {"B": 53066709, "C": 53071896, "D": 53077984},
           "pairs": {
               "GBPUSD": {"anchor": "GRIND_GBPUSD_OPTB",
                          "C": {"probe": "GRIND_GBPUSD_OPTC", "lever": "add"},
                          "D": {"probe": "GRIND_GBPUSD_OPTD", "lever": "exit"}},
               "AUDNZD": {"anchor": "GRIND_AUDNZD_OPTB",
                          "C": {"probe": "GRIND_AUDNZD_ALTC", "primary": "GRIND_AUDNZD_OPTC",
                                "lever": "add"},
                          "D": {"probe": "GRIND_AUDNZD_ALTD", "primary": "GRIND_AUDNZD_OPTD",
                                "lever": "exit"}}},
           "reloads": {k: "2026-10-01T06:30Z" for k in (
               "GRIND_GBPUSD_OPTC", "GRIND_GBPUSD_OPTD", "GRIND_AUDNZD_ALTC", "GRIND_AUDNZD_ALTD")}}
    fx = Fx()
    t0, t1 = T("2026-10-02T01:00Z"), T("2026-10-02T02:00Z")
    for inst, acct, profit in (("GRIND_GBPUSD_OPTB", 53066709, 1.00),   # net 0.93
                               ("GRIND_GBPUSD_OPTC", 53071896, 3.00),   # net 2.93: +2.00
                               ("GRIND_GBPUSD_OPTD", 53077984, 4.00),   # net 3.93: +3.00
                               ("GRIND_AUDNZD_OPTB", 53066709, 1.00),   # net 0.93
                               ("GRIND_AUDNZD_ALTC", 53071896, 2.40),   # net 2.33
                               ("GRIND_AUDNZD_OPTC", 53071896, 1.10)):  # net 1.03
        sid = fx.session(inst, acct)
        fx.layer(inst, sid, "L", t0, t1, profit=profit)
    return cfg, fx.layers()


class TestScoreRound(unittest.TestCase):
    def setUp(self):
        cfg, lay = tiny_round()
        self.rows = {(r["pair"], r["side"]): r for r in cs.score_round(cfg, lay)}

    def test_larger_winning_margin_is_promoted(self):
        r = self.rows[("GBPUSD", "L")]
        self.assertEqual(r["probes"]["C"]["verdict"], "WIN")
        self.assertAlmostEqual(r["probes"]["C"]["margin"], 2.00, places=6)
        self.assertEqual(r["probes"]["D"]["verdict"], "WIN")
        self.assertAlmostEqual(r["probes"]["D"]["margin"], 3.00, places=6)
        self.assertEqual(r["promote"], "D")

    def test_no_trades_repeats_and_anchor_stays(self):
        r = self.rows[("GBPUSD", "S")]
        self.assertEqual(r["probes"]["C"]["verdict"], "REPEAT")
        self.assertEqual(r["probes"]["D"]["verdict"], "REPEAT")
        self.assertIsNone(r["promote"])

    def test_twin_decides_against_its_primary(self):
        # C twin 2.33 vs C primary 1.03 = +1.30 < 1.40 (AUDNZD long twin) -> REPEAT,
        # although vs the anchor (0.93) it is +1.40 > 1.19: reported, not deciding
        r = self.rows[("AUDNZD", "L")]
        c = r["probes"]["C"]
        self.assertEqual(c["comparator"], "GRIND_AUDNZD_OPTC")
        self.assertAlmostEqual(c["margin"], 1.30, places=6)
        self.assertAlmostEqual(c["cross_margin"], 1.40, places=6)
        self.assertEqual(c["verdict"], "REPEAT")
        self.assertIsNone(r["promote"])


class TestLoad(unittest.TestCase):
    def test_accounts_filter_keeps_d_and_drops_others(self):
        fx = Fx()
        sd = fx.session("GRIND_GBPUSD_OPTD", 53077984)
        sx = fx.session("GRIND_GBPUSD_OPTD", 99999999)
        fx.layer("GRIND_GBPUSD_OPTD", sd, "L", T("2026-10-02T01:00Z"), T("2026-10-02T02:00Z"), profit=1.0)
        fx.layer("GRIND_GBPUSD_OPTD", sx, "L", T("2026-10-02T01:00Z"), T("2026-10-02T02:00Z"), profit=9.0)
        with tempfile.TemporaryDirectory() as d:
            path = os.path.join(d, "x.jsonl")
            with open(path, "w") as fh:
                for rows in fx.export().values():
                    for r in rows:
                        fh.write(json.dumps(r) + "\n")
            _exp, lay = cs.load([path], [53066709, 53071896, 53077984])
        nets = [l.net() for l in lay["GRIND_GBPUSD_OPTD"].values() if l.closed]
        self.assertEqual(len(nets), 1)
        self.assertAlmostEqual(nets[0], 0.93, places=6)


class TestRoundFile(unittest.TestCase):
    def test_round1_matches_register(self):
        """GUARD: every probe has a reload time equal to its register row
        (preset de73e46); windows are Fri 2 + Mon 5 Oct, 2 days."""
        cfg = cs.load_round(os.path.join(HERE, "round1.json"))
        reg = os.path.join(HERE, "..", "..", "docs", "research", "geometry_register.csv")
        with open(reg, newline="") as fh:
            opened = {r["instance"]: r["from_utc"] for r in csv.DictReader(fh)
                      if r["preset_commit"] == "de73e46"}
        probes = {p[f]["probe"] for p in cfg["pairs"].values() for f in ("C", "D")}
        self.assertEqual(len(probes), 18)
        self.assertEqual(set(cfg["reloads"]), probes)
        for inst in probes:
            self.assertEqual(cfg["reloads"][inst], opened[inst], inst)
        self.assertEqual(sum(w[2] for w in cfg["windows"]), 2)


# ---------------------------------------------------------------- cuts (GC-4, 3 Oct)
# Operator 3 Oct (Gemini GC-4, amended): a hand intervention on one fleet's
# pair-side CUTS every comparison that involves that fleet on that pair-side:
# scored on the windows before the first such intervention, if at least
# min_days_after_cut (default 1.0) days remain; else VOID. Fleet-wide changes
# applied alike to all fleets are not interventions (never listed).

CUT_FRI = T("2026-10-02T02:26:15Z")


class TestCutWindows(unittest.TestCase):
    def test_cut_inside_first_window_drops_the_rest(self):
        # 22:00 -> 02:26:15 = 4 h 26 m 15 s = 15975 s = 0.184895833 days; W2 gone
        w = cs.cut_windows([W1, W2], CUT_FRI)
        self.assertEqual(len(w), 1)
        self.assertEqual(w[0][0], W1[0])
        self.assertEqual(w[0][1], CUT_FRI)
        self.assertAlmostEqual(w[0][2], 15975 / 86400.0, places=9)

    def test_cut_before_after_or_none(self):
        self.assertEqual(cs.cut_windows([W1, W2], T("2026-10-01T21:00Z")), [])
        self.assertEqual(cs.cut_windows([W1, W2], T("2026-10-06T01:00Z")), [W1, W2])
        self.assertEqual(cs.cut_windows([W1, W2], None), [W1, W2])

    def test_cut_between_windows_keeps_the_first_whole(self):
        # Sun 12:00 is between W1 and W2: W1 whole (1 day), W2 gone
        self.assertEqual(cs.cut_windows([W1, W2], T("2026-10-04T12:00Z")), [W1])


def cut_round(interventions, windows=None, extra=None):
    cfg, lay = tiny_round()
    cfg["interventions"] = interventions
    if windows:
        cfg["windows"] = windows
    if extra:
        fx = Fx()
        for inst, acct, t0, t1, profit in extra:
            fx.layer(inst, fx.session(inst, acct), "L", t0, t1, profit=profit)
        for k, v in fx.layers().items():
            lay.setdefault(k, {}).update(v)
    return {(r["pair"], r["side"]): r for r in cs.score_round(cfg, lay)}


class TestScoreRoundCuts(unittest.TestCase):
    def test_cut_on_probe_fleet_voids_only_that_comparison(self):
        # C cut Fri 01:30 (before every 02:00 close): 3.5 h < 1 day -> VOID;
        # D vs B untouched: +3.00 WIN and promoted
        r = cut_round([{"pair": "GBPUSD", "side": "L", "fleet": "C", "at": "2026-10-02T01:30:00Z"}])
        g = r[("GBPUSD", "L")]
        self.assertEqual(g["probes"]["C"]["verdict"], "VOID")
        self.assertAlmostEqual(g["probes"]["C"]["days_used"], 3.5 / 24.0, places=9)
        self.assertEqual(g["probes"]["D"]["verdict"], "WIN")
        self.assertAlmostEqual(g["probes"]["D"]["margin"], 3.00, places=6)
        self.assertEqual(g["promote"], "D")

    def test_cut_on_anchor_fleet_voids_both(self):
        r = cut_round([{"pair": "GBPUSD", "side": "L", "fleet": "B", "at": "2026-10-02T01:30:00Z"}])
        g = r[("GBPUSD", "L")]
        self.assertEqual(g["probes"]["C"]["verdict"], "VOID")
        self.assertEqual(g["probes"]["D"]["verdict"], "VOID")
        self.assertIsNone(g["promote"])

    def test_cut_on_other_side_or_pair_changes_nothing(self):
        """GUARD: interventions elsewhere leave GBPUSD long as scored without cuts."""
        r = cut_round([{"pair": "GBPUSD", "side": "S", "fleet": "C", "at": "2026-10-02T01:30:00Z"},
                       {"pair": "AUDNZD", "side": "L", "fleet": "B", "at": "2026-10-02T01:30:00Z"}])
        g = r[("GBPUSD", "L")]
        self.assertEqual(g["probes"]["C"]["verdict"], "WIN")
        self.assertEqual(g["probes"]["D"]["verdict"], "WIN")

    def test_salvage_when_a_day_remains(self):
        # Windows W1 + W2; C cut Mon 12:00 -> W1 (1 day) + Mon 22:00(Sun)->12:00 = 14 h
        # -> days 1 + 14/24 = 1.583333. C's extra layer closes Mon 13:00 (after the
        # cut, profit -10.00) and is excluded. Fri layers: C 2.93, B 0.93.
        # margin = (2.93 - 0.93) / 1.583333 = 1.263158 > 1.19 -> WIN.
        # Without the cut: C (2.93 - 10.07) / 2 = -3.57 vs B 0.465 -> LOSE.
        r = cut_round([{"pair": "GBPUSD", "side": "L", "fleet": "C", "at": "2026-10-05T12:00:00Z"}],
                      windows=[["2026-10-01T22:00Z", "2026-10-02T22:00Z", 1],
                               ["2026-10-04T22:00Z", "2026-10-05T22:00Z", 1]],
                      extra=[("GRIND_GBPUSD_OPTC", 53071896, T("2026-10-05T10:00Z"),
                              T("2026-10-05T13:00Z"), -10.00)])
        c = r[("GBPUSD", "L")]["probes"]["C"]
        self.assertAlmostEqual(c["days_used"], 1 + 14 / 24.0, places=9)
        self.assertAlmostEqual(c["margin"], 2.00 / (1 + 14 / 24.0), places=6)
        self.assertEqual(c["verdict"], "WIN")

    def test_twin_cut_on_its_own_fleet(self):
        # AUDNZD long, C: twin and primary both on C; cut on C Fri 01:30 -> VOID
        r = cut_round([{"pair": "AUDNZD", "side": "L", "fleet": "C", "at": "2026-10-02T01:30:00Z"}])
        self.assertEqual(r[("AUDNZD", "L")]["probes"]["C"]["verdict"], "VOID")
        self.assertEqual(r[("AUDNZD", "L")]["probes"]["D"]["verdict"], "REPEAT")

    def test_min_days_after_cut_is_configurable(self):
        # same C cut as the first test, but min 0.1 day: 3.5 h = 0.1458 day remains,
        # no close inside it -> both nets 0 -> margin 0 -> REPEAT (not VOID)
        cfg, lay = tiny_round()
        cfg["interventions"] = [{"pair": "GBPUSD", "side": "L", "fleet": "C", "at": "2026-10-02T01:30:00Z"}]
        cfg["min_days_after_cut"] = 0.1
        r = {(x["pair"], x["side"]): x for x in cs.score_round(cfg, lay)}
        self.assertEqual(r[("GBPUSD", "L")]["probes"]["C"]["verdict"], "REPEAT")


class TestRound1Interventions(unittest.TestCase):
    def test_round1_lists_the_three_hand_ejects(self):
        """fleet-d.md s7, 2 Oct window 1: NZDCHF long B (EJECT_ACCEPTED 02:26:15Z),
        NZDCHF long C (02:29:27Z), AUDCHF long C (03:51:45Z)."""
        cfg = cs.load_round(os.path.join(HERE, "round1.json"))
        got = sorted((i["pair"], i["side"], i["fleet"], i["at"]) for i in cfg["interventions"])
        self.assertEqual(got, [("AUDCHF", "L", "C", "2026-10-02T03:51:45Z"),
                               ("NZDCHF", "L", "B", "2026-10-02T02:26:15Z"),
                               ("NZDCHF", "L", "C", "2026-10-02T02:29:27Z")])


if __name__ == "__main__":
    unittest.main()
