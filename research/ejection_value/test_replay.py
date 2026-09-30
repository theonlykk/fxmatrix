"""Synthetic tests for the ladder replay (study s9) and the account filter.
Expected values are derived by hand in the comments, never read back from
the code.

    python -m unittest research/ejection_value/test_replay.py -v
"""
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from ev_data import Bars, filter_by_account  # noqa: E402
from ev_replay import (Geometry, SideReplay, fleet_day_metrics, peak_slots,  # noqa: E402
                       reconciled)

T = 1790700000.0          # a minute boundary is not needed; bars are 60 s apart
V = 1000.0                # $ per 1.0000 of price per layer (0.01 lot EURUSD ~ $0.10/pip)
COMM = -0.07


def bars(rows, spread=0):
    """rows: [(o, h, l, c)] or [(o, h, l, c, spread_points)]."""
    b = Bars("EURUSD", 1, "S", 5, 0.00001, 0, T + 60 * len(rows))
    for i, r in enumerate(rows):
        b.t.append(T + 60 * i)
        b.o.append(r[0]); b.h.append(r[1]); b.l.append(r[2]); b.c.append(r[3])
        b.spread.append(r[4] if len(r) > 4 else spread)
    return b


def flat(p, n, spread=0):
    return [(p, p, p, p, spread)] * n


def tl(width=5, add=10, exit_=10, cap=3, deadband=4.0, stranded=0.0):
    return [(0.0, Geometry(width, add, exit_, cap, deadband, stranded))]


def run(is_long, rows, geo, **kw):
    b = bars(rows)
    r = SideReplay(is_long, b, geo, V, COMM, **kw)
    r.run(0, len(b))
    return r


class TestLong(unittest.TestCase):
    def test_one_scalp(self):
        # bar0 flat 1.1000: L0 = 1.1000 - 5 pips = 1.0995.
        # bar1 C<O -> O-H-L-C: down to 1.0990 fills L0 at 1.0995 (next add
        # 1.0985 not reached). bar2 C>=O -> O-L-H-C: up to 1.1010 reaches
        # the exit 1.0995 + 10 pips = 1.1005: pnl 0.0010 x 1000 - 0.07 = 0.93.
        r = run(True, [(1.1, 1.1, 1.1, 1.1), (1.1, 1.1, 1.0990, 1.0995),
                       (1.0995, 1.1010, 1.0995, 1.1008)], tl())
        self.assertEqual([(k, round(p, 2)) for _t, k, p in r.events], [("scalp", 0.93)])
        self.assertEqual(len(r.layers), 0)

    def test_cap_blocks_adds(self):
        # cap 2: the fall to 1.0960 fills 1.0995 and 1.0985 only (1.0975 blocked).
        r = run(True, [(1.1, 1.1, 1.1, 1.1), (1.1, 1.1, 1.0960, 1.0965)], tl(cap=2))
        self.assertEqual([round(L.fill, 5) for L in r.layers], [1.0995, 1.0985])
        self.assertEqual(r.max_depth, 2)

    def test_long_fill_needs_the_ask(self):
        # spread 20 points: mid 1.1001, L0 1.0996. A bid low of 1.0995 is an
        # ask of 1.0997 > 1.0996: no fill. A bid low of 1.0994 (ask 1.0996) fills.
        r = run(True, [(1.1, 1.1, 1.1, 1.1, 20), (1.1, 1.1, 1.0995, 1.0995, 20)], tl())
        self.assertEqual(len(r.layers), 0)
        r = run(True, [(1.1, 1.1, 1.1, 1.1, 20), (1.1, 1.1, 1.0994, 1.0994, 20)], tl())
        self.assertEqual([round(L.fill, 5) for L in r.layers], [1.0996])

    def test_path_rule(self):
        # C>=O (O-L-H-C): fill at the low, exit at the high in the same bar.
        r = run(True, [(1.1, 1.1, 1.1, 1.1), (1.1, 1.1010, 1.0990, 1.1005)], tl())
        self.assertEqual(sum(1 for e in r.events if e[1] == "scalp"), 1)
        # C<O (O-H-L-C): the high comes first, the fill after it: no scalp.
        r = run(True, [(1.1, 1.1, 1.1, 1.1), (1.1, 1.1010, 1.0990, 1.0992)], tl())
        self.assertEqual(len(r.events), 0)
        self.assertEqual(len(r.layers), 1)

    def test_deepest_exit_returns_add_to_its_level(self):
        # exit 5, cap 5. bar1 down to 1.0984: fills 1.0995, 1.0985.
        # bar2 up to 1.0991: 1.0985's exit 1.0990 fills (0.0005 x 1000 - 0.07
        # = 0.43); the next add returns to 1.0985. bar3 down: refills 1.0985.
        # bar4 up: second scalp. End: one layer (1.0995).
        rows = [(1.1, 1.1, 1.1, 1.1), (1.1, 1.1, 1.0984, 1.0984),
                (1.0984, 1.0991, 1.0984, 1.0991), (1.0991, 1.0991, 1.0984, 1.0984),
                (1.0984, 1.0991, 1.0984, 1.0991)]
        r = run(True, rows, tl(exit_=5, cap=5))
        self.assertEqual([round(p, 2) for _t, k, p in r.events if k == "scalp"], [0.43, 0.43])
        self.assertEqual([round(L.fill, 5) for L in r.layers], [1.0995])

    def test_l0_recentre_needs_stranded_and_deadband(self):
        # stranded 10, deadband 4. L0 1.0995 from 1.1000. Price steps to
        # 1.10045: distance 9.5 <= 10 -> stays, although its target 1.09995
        # is 4.5 > 4 pips away (the stranded test decides). To 1.1010:
        # distance 15 > 10 and the target 1.1005 differs by 10 > 4 -> moves
        # (checked at the bar AFTER the move, from the previous close).
        r = run(True, [(1.1, 1.1, 1.1, 1.1), (1.10045,) * 4, (1.10045,) * 4],
                tl(stranded=10.0))
        self.assertAlmostEqual(r.l0, 1.0995, places=7)
        r = run(True, [(1.1, 1.1, 1.1, 1.1), (1.1010,) * 4, (1.1010,) * 4],
                tl(stranded=10.0))
        self.assertAlmostEqual(r.l0, 1.1005, places=7)


class TestEject(unittest.TestCase):
    def _rows(self, spike=False):
        # 60 flat bars (S3 needs 60 bars of spread history), then a drop to
        # 1.0960 at bar 60 (fills 1.0995 and 1.0985 at cap 2), then flat at
        # 1.0965. The low (bar 60) is the most recent extreme; S1 needs it
        # W = 5 bars old: first true at bar 65.
        rows = flat(1.1, 60, 10) + [(1.1, 1.1, 1.0960, 1.0965, 10)] + flat(1.0965, 8, 10)
        if spike:
            rows[65] = (1.0965, 1.0965, 1.0965, 1.0965, 20)   # 20 > 1.5 x ~10
        return rows

    def test_s1_s3_eject_most_underwater(self):
        # Spread 10 points = 1 pip: the ask is bid + 0.0001. mid = 1.10005,
        # L0 = 1.09955; buy limits fill on the ask, so both fill (ask low
        # 1.0961). At bar 65's close: eject the highest fill (1.09955) at
        # the bid close 1.0965: (1.0965 - 1.09955) x 1000 - 0.07 = -3.12.
        r = run(True, self._rows(), tl(cap=2))
        ej = [(round((t - T) / 60), round(p, 2)) for t, k, p in r.events if k == "eject"]
        self.assertEqual(ej[0], (66, -3.12))           # t_close of bar 65 = T + 66 min
        self.assertEqual(len(ej), 1)                    # the next add rests at 1.09755: not reached
        self.assertEqual([round(L.fill, 5) for L in r.layers], [1.09855])

    def test_spread_spike_blocks(self):
        # bar 65 spread 20 > 1.5 x mean(~10.2): no fire at 65; bar 66 fires.
        r = run(True, self._rows(spike=True), tl(cap=2))
        ej = [round((t - T) / 60) for t, k, p in r.events if k == "eject"]
        self.assertEqual(ej, [67])


class TestShort(unittest.TestCase):
    def test_short_mirror_with_spread(self):
        # spread 20 points (2 pips). mid = 1.1000 + 0.0001 -> L0 1.1006.
        # bar1 up to 1.1010 (bid): the sell limit fills at 1.1006. Its exit
        # buy limit is 1.0996: needs ask <= 1.0996, i.e. bid <= 1.0994.
        # bar2 low 1.0990: fills at 1.0996: (1.1006 - 1.0996) x 1000 - 0.07 = 0.93.
        rows = [(1.1, 1.1, 1.1, 1.1, 20), (1.1, 1.1010, 1.1, 1.1008, 20),
                (1.1008, 1.1008, 1.0990, 1.0992, 20)]
        r = run(False, rows, tl())
        self.assertEqual([(k, round(p, 2)) for _t, k, p in r.events], [("scalp", 0.93)])

    def test_short_gap_fill_takes_the_better_price(self):
        # L0 1.1006; bar1 opens above it at 1.1012 and rises: the sell limit
        # fills at the segment's start, 1.1012, not at 1.1006.
        rows = [(1.1, 1.1, 1.1, 1.1, 20), (1.1012, 1.1015, 1.1012, 1.1015, 20)]
        r = run(False, rows, tl())
        self.assertEqual([round(L.fill, 5) for L in r.layers], [1.1012])

    def test_short_exit_missed_by_spread(self):
        # bar2 low 1.0995: ask 1.0997 > 1.0996 -> no exit.
        rows = [(1.1, 1.1, 1.1, 1.1, 20), (1.1, 1.1010, 1.1, 1.1008, 20),
                (1.1008, 1.1008, 1.0995, 1.0997, 20)]
        r = run(False, rows, tl())
        self.assertEqual(len(r.events), 0)
        self.assertEqual(len(r.layers), 1)


class TestAggregates(unittest.TestCase):
    def test_fleet_day_metrics(self):
        # roll R = 22:00Z. Side a: -10 at R-120, -20 at R+60, -15 at R+120;
        # side b: -5, -5, 0. An ejection of -12 on a at R+90.
        # Day before R: carried -15 at its first point, worst -15.
        # Day from R: first point R+60: carried -25, move -25; at R+120:
        # closed since R = -12, MTM -15 -> -27. Worst -27.
        R = 1790719200.0            # 2026-09-30 22:00:00Z
        s = {"a": [(R - 120, -10.0), (R + 60, -20.0), (R + 120, -15.0)],
             "b": [(R - 120, -5.0), (R + 60, -5.0), (R + 120, 0.0)]}
        c = {"a": [(R + 90, -12.0)], "b": []}
        self.assertEqual(fleet_day_metrics(s, c, 0, 2e10),
                         [(R - 86400, -15.0, -15.0), (R, -25.0, -27.0)])

    def test_peak_slots(self):
        # forward-filled sum: t1: 3+0, t2: 3+4, t3: 1+4 -> peak 7
        self.assertEqual(peak_slots([[(1, 3), (3, 1)], [(2, 4)]]), 7)

    def test_reconciliation_rule(self):
        act = {"scalps": 100, "ejections": 5, "closed_net": 20.0}
        ok = lambda **d: reconciled(dict(act, **d), act)[0]  # noqa: E731
        self.assertTrue(ok(scalps=109))
        self.assertFalse(ok(scalps=111))       # > 10%
        self.assertTrue(ok(ejections=7))       # max(20% x 5, 2) = 2
        self.assertFalse(ok(ejections=8))
        self.assertTrue(ok(closed_net=23.0))   # max(15% x 20, $3) = 3
        self.assertFalse(ok(closed_net=23.5))


class TestEndToEnd(unittest.TestCase):
    def test_runner_reconciles_one_scalp(self):
        # One instance on box 2's account. Bars (server = UTC + 3 h): flat
        # 1.1000, bar 10 dips to 1.0990 (the replay's L0 1.0995 fills), bar
        # 11 reaches 1.1010 (its exit 1.1005). The ledger holds the same
        # scalp: ENT 1.0995, EXT 1.1005, profit 1.00, commission 2 x -0.035.
        # v = 1.00 / 0.0010 = 1000, comm = -0.07: replay 0.93 = ledger 0.93.
        import io
        import json
        import tempfile
        import ev_caps
        off, t0 = 10800, 1790542800            # 2026-09-28 00:00 server
        inst, sess, acct = "GRIND_EURUSD_OPTC", "s1", 53071896
        prices = [(1.1, 1.1, 1.1, 1.1)] * 10 + [(1.1, 1.1, 1.0990, 1.0995),
                  (1.0995, 1.1010, 1.0995, 1.1008)] + [(1.1008,) * 4] * 8
        iso = lambda t: __import__("datetime").datetime.fromtimestamp(  # noqa: E731
            t, __import__("datetime").timezone.utc).isoformat(sep=" ")
        rows = [{"table": "config_events", "id": 1, "instance_id": inst, "session_id": sess,
                 "event": "INIT", "account_login": acct, "received_at": iso(t0), "width_pips": 5,
                 "add_pips": 10, "exit_pips": 10, "max_layers": 3, "deadband_pips": 4,
                 "stranded_thresh_pips": 0}]
        def fill(i, et, role, pos, order, price, profit=0.0, comm=0.0, t=None):
            rows.append({"table": "fill_logs", "id": 10 + i, "instance_id": inst, "session_id": sess,
                         "entry_type": et, "role": role, "side": "L" if role else None,
                         "layer_index": 0, "position_id": pos, "order_ticket": order,
                         "deal_price": price, "deal_time_broker_msc": int((t + off) * 1000),
                         "commission": comm, "profit": profit, "swap": 0.0, "received_at": iso(t)})
        t_ent, t_ext = t0 + 10 * 60 + 30, t0 + 11 * 60 + 30
        fill(1, "IN", "ENT", 101, 501, 1.0995, comm=-0.035, t=t_ent)
        fill(2, "IN", "EXT", 102, 502, 1.1005, comm=-0.035, t=t_ext)
        fill(3, "OUT_BY", None, 101, 503, 1.1005, profit=1.00, t=t_ext)
        fill(4, "OUT_BY", None, 102, 503, 1.1005, t=t_ext)
        with tempfile.TemporaryDirectory() as d:
            with open(os.path.join(d, "ex.jsonl"), "w") as fh:
                fh.write("\n".join(json.dumps(r) for r in rows) + "\n")
            with open(os.path.join(d, "bars_53071896_EURUSD.csv"), "w") as fh:
                fh.write("# symbol=EURUSD account=53071896 server=ICMarketsSC-Demo digits=5 "
                         "point=0.00001 server_minus_gmt_s=10800 from=2026.09.28 00:00 "
                         "to=2026.09.28 00:20\n")
                fh.write("time_server,time_unix_server,open,high,low,close,spread_points,tick_volume\n")
                for i, (o, h, l, c) in enumerate(prices):
                    fh.write("x,%d,%s,%s,%s,%s,0,1\n" % (t0 + off + 60 * i, o, h, l, c))
            buf = io.StringIO()
            ev_caps.run([os.path.join(d, "ex.jsonl")], [d], [5, 8], [], out=buf)
        text = buf.getvalue()
        self.assertIn("EURUSD_OPTC", text)
        self.assertIn("RECONCILED", text)
        line = [x for x in text.splitlines() if x.strip().startswith("EURUSD_OPTC") and "RECONC" in x][0]
        self.assertEqual(line.split()[5:11], ["1", "1", "0", "0", "0.93", "0.93"])   # dates are two tokens each
        self.assertEqual(sum(1 for x in text.splitlines() if x.strip().startswith("EURUSD_OPTC")), 3)


class TestAccountFilter(unittest.TestCase):
    def test_cycle2_rows_dropped(self):
        # same instance id, two sessions: cycle 2's account and fleet A's.
        ex = {"_meta": [],
              "config_events": [
                  {"instance_id": "GRIND_EURGBP_OPT", "session_id": "s2", "account_login": 1514582088},
                  {"instance_id": "GRIND_EURGBP_OPT", "session_id": "s3", "account_login": 1514731800}],
              "fill_logs": [{"session_id": "s2", "id": 1}, {"session_id": "s3", "id": 2},
                            {"session_id": "unknown", "id": 3}]}
        out, dropped = filter_by_account(ex)
        self.assertEqual([r["id"] for r in out["fill_logs"]], [2])
        self.assertEqual(dropped, {"config_events": 1, "fill_logs": 2})


if __name__ == "__main__":
    unittest.main()
