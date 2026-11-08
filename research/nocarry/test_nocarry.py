"""Tests for run_nocarry.py (written first, against a stub; PREREG.md s5 b).
Run: python -m pytest -q research/nocarry/test_nocarry.py

Times are server time: T0 = 2024-01-08 00:00 server, a Monday (19730 x 86400). Prices at 5 digits."""
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import run_nocarry as rn

sim = rn.sim
T0 = 1704672000


def ms(day, hh, mm, ss=0):
    return (T0 + day * 86400 + hh * 3600 + mm * 60 + ss) * 1000


def inst(name="OPT"):
    return sim.Instance(sim.Cfg(width=2.5, add=9.0, exit=9.0, cap=7, stranded=3.5, deadband=2.0), name)


def lay(entry, idx, open_ms=0, **kw):
    return sim.Layer(entry=entry, idx=idx, open_ms=open_ms, **kw)


def pips(c):
    return ((c.exit - c.entry) if c.side == "L" else (c.entry - c.exit)) / sim.PIP


# ---------------------------------------------------------------- the cut (PREREG s1, s3)
def test_cut_closes_longs_at_bid_shorts_at_ask_worked_example():
    it = inst()
    it.side["S"].layers += [lay(1.34500, 0, 1), lay(1.34590, 1, 2), lay(1.34680, 2, 3)]
    it.side["L"].layers += [lay(1.34700, 0, 4)]
    t = ms(0, 23, 45)
    cs = rn.cut(it, t, bid=1.34610, ask=1.34620)
    assert len(cs) == 4 and it.open_layers() == 0
    assert all(c.cut and not c.rolled and c.close_ms == t for c in cs)
    assert sorted(c.exit for c in cs if c.side == "S") == [1.34620] * 3
    assert [c.exit for c in cs if c.side == "L"] == [1.34610]
    shorts = sorted(round(pips(c), 6) for c in cs if c.side == "S")
    assert shorts == [-12.0, -3.0, 6.0]                                   # s1: -9.0 pips on the shorts
    assert math.isclose(it.realised_pips(), -18.0, abs_tol=1e-6)


def test_cut_half_pip_worse_in_the_sensitivity():
    it = inst()
    it.side["S"].layers.append(lay(1.34500, 0))
    it.side["L"].layers.append(lay(1.34700, 0))
    cs = rn.cut(it, ms(0, 23, 45), bid=1.34610, ask=1.34620, worse=0.5)
    assert {c.side: c.exit for c in cs} == {"S": 1.34625, "L": 1.34605}


def test_dealt_exit_at_the_cut_is_a_normal_close():
    it = inst()
    dealt = lay(1.34500, 0, 1, vl=1.34590, closing=True, exit_fill=1.34500)    # a rolled layer's exit has dealt
    it.side["S"].layers += [dealt, lay(1.34680, 1, 2)]
    it.cb_queue.append((dealt, "S"))
    cs = rn.cut(it, ms(0, 23, 45), bid=1.34610, ask=1.34620)
    normal = [c for c in it.closes if not getattr(c, "cut", False)]
    assert len(normal) == 1 and normal[0].exit == 1.34500 and normal[0].rolled
    assert len(cs) == 1 and cs[0].exit == 1.34620 and cs[0].cut
    assert it.cb_queue == [] and it.open_layers() == 0


def test_cut_resets_every_piece_of_state_and_keeps_the_history():
    it = inst()
    it.bid, it.ask = 1.30000, 1.30010
    t = ms(0, 10, 0)
    it.on_tick(t)
    it.on_tick(t + 15000)
    placed = list(it.orders)
    assert placed                                                         # the L0s are resting
    it.rolls = 5
    it.events.append((t + 10 ** 9, 999, "DEAL", None))
    it.side["L"].extreme, it.side["L"].track_from = 1.29000, t
    rn.cut(it, ms(0, 23, 45), bid=1.30000, ask=1.30010)
    assert it.orders == [] and all(o.removed_ms is not None for o in placed)
    for sd in it.side.values():
        assert sd.l0 is None and sd.add is None and sd.extreme is None and sd.track_from == 0 and sd.layers == []
    assert it.events == [] and it.cb_queue == [] and it.busy == 0 and it.ent_sent is False
    assert it.rolls == 5


def test_restart_places_the_long_l0_first_and_the_short_one_tick_later():
    it = inst()
    it.bid, it.ask = 1.30000, 1.30010
    it.on_tick(ms(0, 10, 0))
    it.on_tick(ms(0, 10, 0, 15))
    rn.cut(it, ms(0, 23, 45), bid=1.30000, ask=1.30010)
    it.bid, it.ask = 1.30000, 1.30010
    t = ms(1, 1, 0)
    it.on_tick(t)
    assert it.side["L"].l0 is not None and it.side["L"].l0.resting() and it.side["S"].l0 is None
    it.on_tick(t + 15000)
    assert it.side["S"].l0 is not None and it.side["S"].l0.resting()


# ---------------------------------------------------------------- the windows (PREREG s2)
def every(day, h0, m0, h1, m1, step_min=15):
    a, b = ms(day, h0, m0), ms(day, h1, m1)
    return list(range(a, b + 1, step_min * 60000))


def test_day_windows_start_0100_cut_2345_or_an_early_close():
    times = every(0, 0, 0, 23, 45) + every(1, 0, 0, 23, 45) + every(2, 0, 0, 20, 0)
    assert rn.windows(times, "DAY") == [(ms(0, 1, 0), ms(0, 23, 45)), (ms(1, 1, 0), ms(1, 23, 45)),
                                        (ms(2, 1, 0), ms(2, 20, 0))]


def test_week_windows_cut_on_the_weeks_last_trading_day():
    w1 = sum((every(d, 0, 0, 23, 45) for d in range(4)), [])               # Mon-Thu: Good Friday closed
    w2 = every(7, 0, 0, 23, 45) + every(11, 0, 0, 23, 45)                   # next Monday and Friday
    assert rn.windows(w1 + w2, "WEEK") == [(ms(0, 1, 0), ms(3, 23, 45)), (ms(7, 1, 0), ms(11, 23, 45))]


def test_cont_is_one_window_without_a_cut():
    times = every(0, 0, 0, 23, 45)
    assert rn.windows(times, "CONT") == [(times[0], None)]


# ---------------------------------------------------------------- the loop (PREREG s3, s5 a, c)
def ticks_two_days():
    """Mon 00:00 to Tue 03:00 every 15 s: a slow swing, then a rise into the cut (shorts stacked at 23:45)."""
    out = []
    t, end = ms(0, 0, 0), ms(1, 3, 0)
    while t <= end:
        h = (t - ms(0, 0, 0)) / 3.6e6
        mid = 1.30000 + 0.0012 * math.sin(2 * math.pi * h / 3.0) + (0.0008 * (h - 18) if h > 18 else 0.0)
        bid = round(mid, 5)
        out.append((t, bid, round(bid + 0.00010, 5)))
        t += 15000
    return out


def cfgs():
    return (sim.Cfg(width=2.5, add=9.0, exit=9.0, cap=7, stranded=3.5, deadband=2.0),
            sim.Cfg(width=4.0, add=15.0, exit=15.0, cap=7, stranded=5.0, deadband=2.0))


def test_cont_reproduces_sim_run_pair():
    tk = ticks_two_days()
    co, ca = cfgs()
    ref = sim.run_pair(tk, co, ca)
    r = rn.run_arm(tk, co, ca, "CONT", u=0.1)
    assert r["marks"] == ref.marks
    for a, b in ((r["opt"], ref.opt), (r["alt"], ref.alt)):
        assert [(c.side, c.entry, c.exit, c.rolled, c.open_ms, c.close_ms) for c in a.closes] == \
               [(c.side, c.entry, c.exit, c.rolled, c.open_ms, c.close_ms) for c in b.closes]


def test_day_is_flat_and_still_from_the_cut_to_the_restart():
    tk = ticks_two_days()
    co, ca = cfgs()
    r = rn.run_arm(tk, co, ca, "DAY", u=0.1)
    c0, r0 = ms(0, 23, 45), ms(1, 1, 0)
    cuts = [c for it in (r["opt"], r["alt"]) for c in it.closes if getattr(c, "cut", False)]
    assert any(c.close_ms == c0 for c in cuts)                            # not vacuous: layers were cut at 23:45
    assert all(c.close_ms in (c0, tk[-1][0]) for c in cuts)               # ... or at Tuesday's last tick (s2)
    for it in (r["opt"], r["alt"]):
        for c in it.closes:
            assert not (c0 < c.open_ms < r0) and not (c0 < c.close_ms < r0)
    e = r["eq"]
    inside = (e["t"] >= c0) & (e["t"] < r0)
    assert inside.any()
    assert np.array_equal(e["eq_opt"][inside], e["bal_opt"][inside])
    assert np.array_equal(e["eq_alt"][inside], e["bal_alt"][inside])
    for t, vals in r["marks"]:
        if c0 <= t < r0 and t != c0:
            assert all(v[3] == 0 for v in vals)                          # zero layers at the marks in the window


# ---------------------------------------------------------------- the FTMO day (PREREG s4)
def test_ftmo_day_loss_by_hand_with_a_low_between_marks():
    t = np.array([ms(0, 1, 0), ms(0, 12, 0), ms(0, 12, 0, 15), ms(0, 23, 59), ms(1, 0, 59, 45),
                  ms(1, 1, 0), ms(1, 10, 0), ms(1, 10, 0, 30)], dtype=np.int64)
    bal = np.array([0, 0, 0, -100, -100, -100, -100, -100], dtype=float)
    eq = np.array([0, -50, -300, -150, -200, -180, -600, -650], dtype=float)
    d = rn.day_losses(t, bal, eq)
    k1, k2 = 19730, 19731                                                 # 00:59:45 Tue is still Monday's day
    assert set(d) == {k1, k2}
    assert d[k1] == (0.0, -300.0, 300.0)
    assert d[k2] == (-100.0, -650.0, 550.0)


def test_combine_holds_each_part_at_its_last_value():
    a = (np.array([10, 20, 30]), np.array([1.0, 2.0, 3.0]), np.array([1.0, 2.0, 3.0]))
    b = (np.array([20, 25]), np.array([10.0, 20.0]), np.array([10.0, 20.0]))
    t, bal, eq = rn.combine([a, b])
    assert list(t) == [10, 20, 25, 30]
    assert list(bal) == [1.0, 12.0, 22.0, 23.0] and list(eq) == [1.0, 12.0, 22.0, 23.0]


# ---------------------------------------------------------------- windows of month-end equity, the split (s4, s5 d)
def test_windows_negative():
    assert rn.win_neg([0, 1, 0, 2, 1], 1) == (2, 4)
    E = [math.sin(i / 3.0) * 100 + i for i in range(46)]
    assert rn.win_neg(E, 12) == (sum(E[i] - E[i - 12] < 0 for i in range(12, 46)), 34)


def test_split_counts_cut_closes_apart_and_adds_up():
    it = inst()
    C = sim.Close
    it.closes = [C("L", 1.00000, 1.00100, False, 0, 1, 0.0), C("S", 1.00000, 1.00200, True, 0, 1, 0.0)]
    for e, x in ((1.00050, 1.00000), (1.00000, 1.00020)):
        c = C("L", e, x, False, 0, 2, 0.0)
        c.cut = True
        it.closes.append(c)
    it.side["L"].layers.append(lay(1.00000, 0))
    it.rolls = 3
    s = rn.split(it, 0.1, 1.00030, 1.00040)
    assert (s["scalp"], s["rolled"], s["cut"], s["open"], s["comm"]) == (1.0, -2.0, -0.3, 0.3, -0.24)
    assert s["net"] == round(1.0 - 2.0 - 0.3 + 0.3 - 0.24, 2)
    assert (s["n_cut"], s["n_cut_loss"], s["rolls"]) == (2, 1, 3)
    assert math.isclose(s["med_cut_pips"], 2.0, abs_tol=1e-6)


# ---------------------------------------------------------------- the decision rule (PREREG s6)
def test_decide():
    ok = {"net": 100.0, "years": [1.0, -1.0, 1.0, 1.0], "neg12": 16, "n12": 34, "days500": 4}
    assert rn.decide(ok, ok) == "EDGE WITHOUT CARRY"
    assert rn.decide(dict(ok, neg12=17), dict(ok, neg12=17)) == "NO EDGE"
    assert rn.decide(dict(ok, net=0.0), dict(ok, net=0.0)) == "NO EDGE"
    assert rn.decide(dict(ok, years=[1.0, -1.0, -1.0, 1.0]), ok) == "NO EDGE"
    assert rn.decide(dict(ok, days500=5), dict(ok, days500=5)) == "EDGE, NOT FTMO-SAFE"
    assert rn.decide(ok, dict(ok, net=-1.0)) == "FRAGILE"
    assert rn.decide(ok, dict(ok, days500=5)) == "FRAGILE"
