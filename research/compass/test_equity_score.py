"""Synthetic tests for the compass EQUITY scorer (operator 7 Oct ~14:53Z: a
round is decided on equity, not realised, from round 2; ~15:07Z after Gemini
GQ7-3: on the COHORT, the layers opened inside the round, so inherited
inventory drops out; plain equity and realised are reported beside it).
Expected values are derived by hand in the comments, never read back.

    python -m unittest research/compass/test_equity_score.py -v

Guards (pass with the stub too) are marked GUARD in their docstring.
"""
import datetime as dt
import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "ejection_value"))

import compass_score as cs  # noqa: E402
import equity_score as es  # noqa: E402
import ev_book  # noqa: E402
import ev_data  # noqa: E402

OFF = 10800
T0 = cs.utc("2026-10-07T22:00Z")
INST = "GRIND_GBPUSD_OPTB"
PV = 0.10          # USD per pip per 0.01 layer, given (not estimated) in E1-E6


def bars(bids, start=T0 - 60, spread=0.0001, symbol="GBPUSD"):
    """Per-minute bid/ask (true ask = bid + spread) from `start`, one bar a minute."""
    b = ev_data.Bars(symbol, 53066709, "ICMarketsSC-Demo", 5, 0.00001, OFF, start + 60 * len(bids))
    b.ao, b.ah, b.al, b.ac = [], [], [], []
    for i, bid in enumerate(bids):
        b.t.append(start + 60 * i)
        for arr in (b.o, b.h, b.l, b.c):
            arr.append(bid)
        for arr in (b.ao, b.ah, b.al, b.ac):
            arr.append(bid + spread)
        b.spread.append(10)
    return b


_pid = [1000]


def layer(book, inst, side, open_t, open_price, close_t=None, close_price=None,
          closeby_net=None, open_comm=-0.04, exit_comm=-0.04, profit=None, rolled=False):
    _pid[0] += 1
    lay = ev_book.Layer(inst, _pid[0])
    lay.side, lay.layer_index = side, 0
    lay.open_t, lay.open_price, lay.open_commission = open_t, open_price, open_comm
    if close_t is not None:
        lay.close_t, lay.close_price = close_t, close_price
        lay.closeby_net, lay.exit_commission = closeby_net, exit_comm
        lay.closeby_profit = closeby_net if profit is None else profit
        lay.closeby_swap = 0.0
    lay.rolled = rolled
    book.setdefault(inst, {})[lay.position_id] = lay
    return lay


# bars: T0-60 bid 1.00000 | T0 0.99900 | T0+60 0.99800 | T0+120 0.99950 (asks +1 pip,
# so mids +0.5 pip). Marks at the MID (7 Oct: the boundaries fall at 22:00Z, the
# minute 21:59 is inside IC's rollover hour; bid/ask marks would put that spread
# into each side in proportion to its depth; the holdout's T3c marks at the mid
# for the same reason). Window (T0, T0+180): the start mark is the minute ENDING
# at T0 (bar T0-60, mid 1.00005); the end mark the minute ending at T0+180 (bar
# T0+120, mid 0.99955).
B4 = [1.00000, 0.99900, 0.99800, 0.99950]
WIN = [(T0, T0 + 180, 1)]


class TestMark(unittest.TestCase):
    def test_e1_mark_both_sides_at_the_mid(self):
        """E1: at T0 (mid 1.00005) a long from 1.00100 = -9.5 pips -> -0.95; a short
        from 1.00050 = +4.5 -> +0.45; at T0+180 (mid 0.99955) the long -14.5 -> -1.45,
        the short +9.5 -> +0.95."""
        book = {}
        layer(book, INST, "L", T0 - 600, 1.00100)
        layer(book, INST, "S", T0 - 600, 1.00050)
        b = bars(B4)
        self.assertAlmostEqual(es.mark_side(book, INST, "L", T0, b, PV)[0], -0.95, places=9)
        self.assertAlmostEqual(es.mark_side(book, INST, "S", T0, b, PV)[0], +0.45, places=9)
        self.assertAlmostEqual(es.mark_side(book, INST, "L", T0 + 180, b, PV)[0], -1.45, places=9)
        self.assertAlmostEqual(es.mark_side(book, INST, "S", T0 + 180, b, PV)[0], +0.95, places=9)

    def test_e2_mark_counts_only_layers_open_at_the_minute_end(self):
        """E2: a long opened at T0+30 is not in the T0 mark (minute ends T0-1); a long
        closed at T0+90 is in the T0 mark but not the T0+180 one; an unpriced long
        open at the mark counts 1 unpriced and adds nothing."""
        book = {}
        layer(book, INST, "L", T0 + 30, 0.99900)
        layer(book, INST, "L", T0 - 600, 1.00100, T0 + 90, 0.99800, -1.50)
        layer(book, INST, "L", T0 - 600, None)
        b = bars(B4)
        usd, unpriced = es.mark_side(book, INST, "L", T0, b, PV)
        self.assertAlmostEqual(usd, -0.95, places=9)        # the closed-later long only
        self.assertEqual(unpriced, 1)
        usd, unpriced = es.mark_side(book, INST, "L", T0 + 180, b, PV)
        self.assertAlmostEqual(usd, +0.55, places=9)        # the new long: 0.99955 - 0.99900
        self.assertEqual(unpriced, 1)


class TestEquityChange(unittest.TestCase):
    def test_e3_inherited_loss_realised_in_the_window_nets_out(self):
        """E3 (THE CASE, 7 Oct EURUSD B vs C): a long from 1.00100 opened before the
        window (its open commission paid before) closes at T0+90, closeby_net -1.50,
        exit commission -0.04. Realised (compass) = -1.50 - 0.04 - 0.04 = -1.58.
        Equity change = cash in the window (-1.50 - 0.04 = -1.54) + end mark (0, closed)
        - start mark (-0.95) = -0.59: only the move from the start mark (mid 1.00005)
        to the exit counts."""
        book = {}
        layer(book, INST, "L", T0 - 600, 1.00100, T0 + 90, 0.99850, -1.50)
        e = es.equity_side(book, INST, "L", WIN, bars(B4), PV)
        self.assertAlmostEqual(e["change"], -0.59, places=9)
        self.assertAlmostEqual(e["per_day"], -0.59, places=9)
        self.assertAlmostEqual(e["cash"], -1.54, places=9)
        m = cs.side_metrics(book, INST, "L", WIN, T0)
        self.assertAlmostEqual(m["net"], -1.58, places=9)   # the realised view, for contrast

    def test_e4_opened_in_the_window_and_still_open(self):
        """E4: a long opened at T0+30 at 0.99900 (commission -0.04), open at the end:
        cash -0.04 + end mark +0.55 (mid 0.99955) - start mark 0 = +0.51."""
        book = {}
        layer(book, INST, "L", T0 + 30, 0.99900)
        e = es.equity_side(book, INST, "L", WIN, bars(B4), PV)
        self.assertAlmostEqual(e["change"], 0.51, places=9)

    def test_e5_opened_and_closed_in_the_window_equals_realised(self):
        """E5: opened T0+10, closed T0+100, closeby_net +0.93, commissions -0.04 each:
        cash = -0.04 + 0.93 - 0.04 = +0.85 = compass net; no mark -> change +0.85."""
        book = {}
        layer(book, INST, "S", T0 + 10, 1.00000, T0 + 100, 0.99900, 0.93)
        e = es.equity_side(book, INST, "S", WIN, bars(B4), PV)
        self.assertAlmostEqual(e["change"], 0.85, places=9)
        self.assertAlmostEqual(cs.side_metrics(book, INST, "S", WIN, T0)["net"], 0.85, places=9)

    def test_e6_held_through_and_sides_apart(self):
        """E6: a short from 1.00050 held through: start +0.45, end +0.95 -> +0.50; the
        long side of the same instance (E3's long) is scored apart (-0.59)."""
        book = {}
        layer(book, INST, "S", T0 - 600, 1.00050)
        layer(book, INST, "L", T0 - 600, 1.00100, T0 + 90, 0.99850, -1.50)
        b = bars(B4)
        self.assertAlmostEqual(es.equity_side(book, INST, "S", WIN, b, PV)["change"], 0.50, places=9)
        self.assertAlmostEqual(es.equity_side(book, INST, "L", WIN, b, PV)["change"], -0.59, places=9)

    def test_e7_two_windows_skip_the_gap(self):
        """E7: windows (T0, T0+60) and (T0+120, T0+180), one day each; a long from
        1.00100 held through. W1: start mark bar T0-60 (mid 1.00005) -9.5, end mark bar
        T0 (0.99905) -19.5 -> -1.00. W2: start mark bar T0+60 (0.99805) -29.5, end bar
        T0+120 (0.99955) -14.5 -> +1.50. Total +0.50 over 2 days -> +0.25 a day; the move
        inside the gap (0.99900 -> 0.99800) is not counted."""
        book = {}
        layer(book, INST, "L", T0 - 600, 1.00100)
        win = [(T0, T0 + 60, 1), (T0 + 120, T0 + 180, 1)]
        e = es.equity_side(book, INST, "L", win, bars(B4), PV)
        self.assertAlmostEqual(e["change"], 0.50, places=9)
        self.assertAlmostEqual(e["per_day"], 0.25, places=9)

    def test_e8_unpriced_is_reported(self):
        """E8: a long with no open price open at the start: unpriced 1 (its change is
        not known; the verdict for that comparison is UNPRICED, E11)."""
        book = {}
        layer(book, INST, "L", T0 - 600, None)
        e = es.equity_side(book, INST, "L", WIN, bars(B4), PV)
        self.assertEqual(e["unpriced"], 1)


class TestCohort(unittest.TestCase):
    """C1-C8: the cohort = layers OPENED in [start, end): value = their open
    commissions + closeby_net and exit commission of those closed before `end` +
    the mid mark at `end` of those still open. Nothing inherited counts."""

    def test_c1_inherited_layer_realised_in_the_round_counts_nothing(self):
        """C1 (THE CASE): E3's inherited long (opened T0-600, closed T0+90, realised
        -1.58) is not in the cohort: value 0.00, n 0."""
        book = {}
        layer(book, INST, "L", T0 - 600, 1.00100, T0 + 90, 0.99850, -1.50)
        c = es.cohort_side(book, INST, "L", T0, T0 + 180, bars(B4), PV, days=1)
        self.assertAlmostEqual(c["value"], 0.0, places=9)
        self.assertEqual(c["n"], 0)

    def test_c2_opened_and_still_open_at_the_end(self):
        """C2: a long opened T0+30 at 0.99900 (commission -0.04), open at T0+180: -0.04 +
        end mark (mid 0.99955: +5.5 pips -> +0.55) = +0.51; n 1."""
        book = {}
        layer(book, INST, "L", T0 + 30, 0.99900)
        c = es.cohort_side(book, INST, "L", T0, T0 + 180, bars(B4), PV, days=1)
        self.assertAlmostEqual(c["value"], 0.51, places=9)
        self.assertEqual(c["n"], 1)

    def test_c3_opened_and_closed_equals_realised(self):
        """C3: opened T0+10, closed T0+100, closeby_net +0.93, commissions -0.04 each
        -> -0.04 + 0.93 - 0.04 = +0.85 (= compass net)."""
        book = {}
        layer(book, INST, "S", T0 + 10, 1.00000, T0 + 100, 0.99900, 0.93)
        c = es.cohort_side(book, INST, "S", T0, T0 + 180, bars(B4), PV, days=1)
        self.assertAlmostEqual(c["value"], 0.85, places=9)

    def test_c4_the_end_mark_time_cuts_the_cohort(self):
        """C4: end T0+120 (the mark: the minute ending T0+120 = bar T0+60, mid 0.99805).
        A long opened T0+30 at 0.99900, closed later at T0+130: still open at the end
        -> -0.04 + (0.99805 - 0.99900 = -9.5 pips -> -0.95) = -0.99. A long opened
        T0+150 (after the end) is not in the cohort. Total -0.99, n 1."""
        book = {}
        layer(book, INST, "L", T0 + 30, 0.99900, T0 + 130, 0.99950, 0.50)
        layer(book, INST, "L", T0 + 150, 0.99950)
        c = es.cohort_side(book, INST, "L", T0, T0 + 120, bars(B4), PV, days=1)
        self.assertAlmostEqual(c["value"], -0.99, places=9)
        self.assertEqual(c["n"], 1)

    def test_c5_per_day_and_sides_apart(self):
        """C5: C2's long on L and C3's short on S of one instance; days 2 -> L +0.51 / 2
        = +0.255, S +0.85 / 2 = +0.425."""
        book = {}
        layer(book, INST, "L", T0 + 30, 0.99900)
        layer(book, INST, "S", T0 + 10, 1.00000, T0 + 100, 0.99900, 0.93)
        b = bars(B4)
        self.assertAlmostEqual(es.cohort_side(book, INST, "L", T0, T0 + 180, b, PV, days=2)["per_day"], 0.255, places=9)
        self.assertAlmostEqual(es.cohort_side(book, INST, "S", T0, T0 + 180, b, PV, days=2)["per_day"], 0.425, places=9)

    def test_c6_unpriced_cohort_layer(self):
        """C6: a cohort long with no open price, open at the end: unpriced 1."""
        book = {}
        layer(book, INST, "L", T0 + 30, None)
        c = es.cohort_side(book, INST, "L", T0, T0 + 180, bars(B4), PV, days=1)
        self.assertEqual(c["unpriced"], 1)

    def test_c7_layer_hours_reported(self):
        """C7: C2's long is in the cohort from T0+30 to the end T0+180 = 150 s =
        150 / 3600 h; a cohort layer closed at T0+100 after opening at T0+10 adds 90 s.
        Total 240 s = 0.0666... h."""
        book = {}
        layer(book, INST, "L", T0 + 30, 0.99900)
        layer(book, INST, "L", T0 + 10, 1.00000, T0 + 100, 0.99900, -1.0)
        c = es.cohort_side(book, INST, "L", T0, T0 + 180, bars(B4), PV, days=1)
        self.assertAlmostEqual(c["layer_hours"], 240 / 3600.0, places=9)

    def test_c9_open_cohort_short_marked_at_the_mid(self):
        """C9 (after the mutation round: a flipped short sign survived): a short opened
        T0+30 at 0.99900, open at T0+180 (mid 0.99955): (0.99900 - 0.99955) = -5.5
        pips -> -0.55, commission -0.04 -> -0.59."""
        book = {}
        layer(book, INST, "S", T0 + 30, 0.99900)
        c = es.cohort_side(book, INST, "S", T0, T0 + 180, bars(B4), PV, days=1)
        self.assertAlmostEqual(c["value"], -0.59, places=9)

    def test_c8_round_end_and_start_from_the_round_file(self):
        """C8: round_span uses the first window's start and "equity_end" when given,
        else the last window's end."""
        cfg = round_cfg()
        self.assertEqual(es.round_span(cfg), (T0, T0 + 180))
        cfg["equity_end"] = "2026-10-07T22:02Z"
        self.assertEqual(es.round_span(cfg), (T0, T0 + 120))


class TestDecide(unittest.TestCase):
    def test_e9_strict_margins(self):
        """E9: margin > thr WIN, < -thr LOSE, equal either way REPEAT; no gates."""
        self.assertEqual(es.decide_equity(3.00, 1.00, 1.50)[0], "WIN")      # +2.00
        self.assertEqual(es.decide_equity(1.00, 3.00, 1.50)[0], "LOSE")     # -2.00
        self.assertEqual(es.decide_equity(2.50, 1.00, 1.50)[0], "REPEAT")   # +1.50 exactly
        self.assertEqual(es.decide_equity(1.00, 2.50, 1.50)[0], "REPEAT")   # -1.50 exactly
        self.assertAlmostEqual(es.decide_equity(3.00, 1.00, 1.50)[1], 2.00, places=9)


def round_cfg():
    return {"round": "t", "accounts": {"B": 53066709, "C": 53071896, "D": 53077984},
            "windows": [[ "2026-10-07T22:00Z", "2026-10-07T22:03Z", 1]],
            "threshold": 1.19, "interventions": [], "min_days_after_cut": 1.0,
            "control": {"pair": "NZDCAD", "instances": {"B": "GRIND_NZDCAD_OPTB",
                                                         "C": "GRIND_NZDCAD_OPTC",
                                                         "D": "GRIND_NZDCAD_OPTD"}},
            "pairs": {"GBPUSD": {"anchor": "GRIND_GBPUSD_OPTB",
                                 "C": {"probe": "GRIND_GBPUSD_OPTC", "lever": "add"},
                                 "D": {"probe": "GRIND_GBPUSD_OPTD", "lever": "exit"}},
                      "NZDCAD": {"anchor": "GRIND_NZDCAD_OPTB"}},
            "reloads": {"GRIND_GBPUSD_OPTC": "2026-10-06T03:25:10Z",
                        "GRIND_GBPUSD_OPTD": "2026-10-06T03:18:23Z"}}


def cash_layer(book, inst, side, net):
    """Opened and closed inside the window: equity change = net (E5) with both
    commissions 0, so change = closeby_net exactly."""
    layer(book, inst, side, T0 + 10, 1.00000, T0 + 100, 1.00000, net, open_comm=0.0, exit_comm=0.0)


def control_book(book, nets_l, nets_s):
    for f, nl, ns in zip("BCD", nets_l, nets_s):
        cash_layer(book, "GRIND_NZDCAD_OPT" + f, "L", nl)
        cash_layer(book, "GRIND_NZDCAD_OPT" + f, "S", ns)


class TestControl(unittest.TestCase):
    def test_e10_gc1_from_equity_gaps(self):
        """E10: NZDCAD changes L B 1.00 C 3.00 D 2.00 -> gaps B-C 2, B-D 1, C-D 1;
        S B 1.00 C 1.00 D 4.00 -> 0, 3, 3. Pool 0,1,1,2,3,3 -> median 1.5 -> GC-1
        max(1.19, 1.5) = 1.5."""
        book = {}
        control_book(book, (1.0, 3.0, 2.0), (1.0, 1.0, 4.0))
        bars_by_pair = {"NZDCAD": bars(B4, symbol="NZDCAD")}
        c = es.control_threshold_equity(round_cfg(), book, bars_by_pair, {"NZDCAD": PV})
        self.assertAlmostEqual(c["median"], 1.5, places=9)
        self.assertAlmostEqual(c["gc1"], 1.5, places=9)
        self.assertEqual(len(c["gaps"]), 6)


    def test_e14_control_gaps_on_the_cohort(self):
        """E14 (after the mutation round: control gaps on plain equity survived):
        NZDCAD B, C, D each +1.00 cash per side (cohort gaps all 0 -> median 0 ->
        GC-1 1.19); B and C ALSO carry an inherited layer per side realised in the
        window (closeby -5.00). On the cohort they count nothing: median 0.0, GC-1
        1.19. (On plain equity the L gaps would be 0, 4.09, 4.09 and the S gaps 0,
        5.49, 5.49: median 4.09.)"""
        book = {}
        control_book(book, (1.0, 1.0, 1.0), (1.0, 1.0, 1.0))
        for f in "BC":
            layer(book, "GRIND_NZDCAD_OPT" + f, "L", T0 - 600, 1.00100, T0 + 90, 0.99600, -5.00)
            layer(book, "GRIND_NZDCAD_OPT" + f, "S", T0 - 600, 1.00050, T0 + 90, 1.00550, -5.00)
        c = es.control_threshold_equity(round_cfg(), book, {"NZDCAD": bars(B4, symbol="NZDCAD")},
                                        {"NZDCAD": PV})
        self.assertAlmostEqual(c["median"], 0.0, places=9)
        self.assertAlmostEqual(c["gc1"], 1.19, places=9)


class TestScoreRound(unittest.TestCase):
    def test_e11_the_motivating_case_and_promotion(self):
        """E11 (COHORT decides, ~15:07Z): GBPUSD long. B (anchor) scalps +1.00 (cash).
        C (add probe) scalps +1.00 AND realises an inherited long (E3's: realised
        -1.58, plain equity -0.59, cohort 0). D (exit probe) scalps +4.00. Control
        gaps all 1.0 -> GC-1 max(1.19, 1.0) = 1.19. Cohort per day: B +1.00, C +1.00,
        D +4.00. C margin 0.00 -> REPEAT (plain equity -0.59, realised -1.58: both
        reported). D margin +3.00 -> WIN, promoted. Short side: nothing -> REPEAT,
        margin 0. A C short opened in the round with no open price -> UNPRICED."""
        book = {}
        control_book(book, (1.0, 2.0, 1.0), (1.0, 2.0, 1.0))   # gaps 1,0,1 / 1,0,1 -> median 1.0
        cash_layer(book, "GRIND_GBPUSD_OPTB", "L", 1.00)
        cash_layer(book, "GRIND_GBPUSD_OPTC", "L", 1.00)
        layer(book, "GRIND_GBPUSD_OPTC", "L", T0 - 600, 1.00100, T0 + 90, 0.99850, -1.50)
        cash_layer(book, "GRIND_GBPUSD_OPTD", "L", 4.00)
        bidask = {(53066709, "GBPUSD"): bars(B4), (53066709, "NZDCAD"): bars(B4, symbol="NZDCAD")}
        res = es.score_round_equity(round_cfg(), book, bidask, pv={"GBPUSD": PV, "NZDCAD": PV})
        self.assertAlmostEqual(res["control"]["gc1"], 1.19, places=9)
        rows = {(r["pair"], r["side"]): r for r in res["rows"]}
        long_ = rows[("GBPUSD", "L")]
        self.assertAlmostEqual(long_["probes"]["C"]["margin"], 0.00, places=9)
        self.assertEqual(long_["probes"]["C"]["verdict"], "REPEAT")
        self.assertAlmostEqual(long_["probes"]["C"]["equity_margin"], -0.59, places=9)
        self.assertAlmostEqual(long_["probes"]["C"]["realised_margin"], -1.58, places=9)
        self.assertAlmostEqual(long_["probes"]["D"]["margin"], 3.00, places=9)
        self.assertEqual(long_["probes"]["D"]["verdict"], "WIN")
        self.assertEqual(long_["promote"], "D")
        short = rows[("GBPUSD", "S")]
        self.assertEqual(short["probes"]["C"]["verdict"], "REPEAT")
        self.assertAlmostEqual(short["probes"]["C"]["margin"], 0.0, places=9)
        layer(book, "GRIND_GBPUSD_OPTC", "S", T0 + 20, None)
        res = es.score_round_equity(round_cfg(), book, bidask, pv={"GBPUSD": PV, "NZDCAD": PV})
        rows = {(r["pair"], r["side"]): r for r in res["rows"]}
        self.assertEqual(rows[("GBPUSD", "S")]["probes"]["C"]["verdict"], "UNPRICED")

    def test_e13_gc1_above_base_decides_and_the_larger_win_is_promoted(self):
        """E13 (after the mutation round: 'threshold = base' and 'promote the smaller'
        survived E11): control L and S B 1, C 4, D 1 -> gaps 3, 0, 3 each side -> pool
        0,0,3,3,3,3 -> median 3.0 -> GC-1 3.0 (> base 1.19). GBPUSD long B 1.00, C 4.50
        (margin +3.50 > 3.0: WIN), D 3.00 (+2.00: REPEAT under 3.0, WIN under 1.19) ->
        promote C. Then D 5.00 (+4.00): both WIN, the larger (D) is promoted."""
        def run(d_net):
            book = {}
            control_book(book, (1.0, 4.0, 1.0), (1.0, 4.0, 1.0))
            cash_layer(book, "GRIND_GBPUSD_OPTB", "L", 1.00)
            cash_layer(book, "GRIND_GBPUSD_OPTC", "L", 4.50)
            cash_layer(book, "GRIND_GBPUSD_OPTD", "L", d_net)
            bidask = {(53066709, "GBPUSD"): bars(B4), (53066709, "NZDCAD"): bars(B4, symbol="NZDCAD")}
            res = es.score_round_equity(round_cfg(), book, bidask, pv={"GBPUSD": PV, "NZDCAD": PV})
            return res, {(r["pair"], r["side"]): r for r in res["rows"]}[("GBPUSD", "L")]
        res, row = run(3.00)
        self.assertAlmostEqual(res["control"]["gc1"], 3.0, places=9)
        self.assertEqual(row["probes"]["C"]["verdict"], "WIN")
        self.assertEqual(row["probes"]["D"]["verdict"], "REPEAT")
        self.assertEqual(row["promote"], "C")
        _res, row = run(5.00)
        self.assertEqual(row["probes"]["D"]["verdict"], "WIN")
        self.assertEqual(row["promote"], "D")

    def test_e15_report_prints(self):
        """E15 (after a format error in report() at 7 Oct ~15:25Z): the report runs on
        E13's book and prints the cohort header, GC-1 and a GBPUSD row with WIN."""
        import io
        book = {}
        control_book(book, (1.0, 4.0, 1.0), (1.0, 4.0, 1.0))
        cash_layer(book, "GRIND_GBPUSD_OPTB", "L", 1.00)
        cash_layer(book, "GRIND_GBPUSD_OPTC", "L", 4.50)
        cash_layer(book, "GRIND_GBPUSD_OPTD", "L", 3.00)
        bidask = {(53066709, "GBPUSD"): bars(B4), (53066709, "NZDCAD"): bars(B4, symbol="NZDCAD")}
        res = es.score_round_equity(round_cfg(), book, bidask, pv={"GBPUSD": PV, "NZDCAD": PV})
        out = io.StringIO()
        es.report(round_cfg(), {"fill_logs": []}, res, out=out)
        text = out.getvalue()
        self.assertIn("COHORT EQUITY", text)
        self.assertIn("GC-1 3.00", text)
        self.assertTrue(any(l.startswith("GBPUSD L") and "WIN" in l for l in text.splitlines()), text)

    def test_e12_realised_scorer_untouched(self):
        """E12 (GUARD): compass_score's realised rule is unchanged: decide() still WINs
        at +2.00 over 1.50 for an exit probe."""
        p = {"per_day": 3.0, "entry_per_day": 3.0, "per_hour": 1.0}
        c = {"per_day": 1.0, "entry_per_day": 1.0, "per_hour": 1.0}
        self.assertEqual(cs.decide(p, c, 1.5, "exit")[0], "WIN")


if __name__ == "__main__":
    unittest.main()
