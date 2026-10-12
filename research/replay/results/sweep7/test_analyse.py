"""Tests for sweep7/analyse.py (hand-derived; run: python -B -m unittest test_analyse).

sweep7: one flat start a pair at Mon 3 Aug 00:00 server, the book carried to Fri 25 Sep 23:45
(results/sweep_notes.md, sweep7). Besides sweep.score's totals, analyse.py rebuilds each book
from the run's fill log (ENT appends a layer on its side; EXT removes that side's layer at
layer_index), checks the rebuild against the harness's end book and its SCALP_CLOSED rows, marks
the book at every tick (long at bid, short at ask) for the worst floating loss, counts the
requests (non-SEED PLACE / MODIFY / REMOVE, plus one close-by a close) and sums the nine pairs'
floating in dollars minute by minute.
"""
import json
import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", ".."))
import analyse as an  # noqa: E402

M = 60000
T0 = 1785715200000   # Mon 3 Aug 00:00 server, read as UTC


def fill(seg, t, role, side, layer, price):
    j = {"type": "fill_log", "role": role, "entry_type": "IN", "side": side,
         "layer_index": layer, "deal_price": price}
    return {"seg_id": str(seg), "sync_idx": "-1", "time_ms": str(t), "kind": "ea_event", "code": "",
            "json": json.dumps(j)}


def closeby(seg, t):
    j = {"type": "fill_log", "role": None, "entry_type": "OUT_BY", "side": None, "layer_index": 0,
         "deal_price": 1.0}
    return {"seg_id": str(seg), "sync_idx": "-1", "time_ms": str(t), "kind": "ea_event", "code": "",
            "json": json.dumps(j)}


def scalp(seg, t, direction, entry, exit_):
    j = {"direction": direction, "entry_price": entry, "exit_price": exit_, "rolled": False}
    return {"seg_id": str(seg), "sync_idx": "-1", "time_ms": str(t), "kind": "scalp",
            "code": "SCALP_CLOSED", "json": json.dumps(j)}


def tick(t, bid, ask):
    return (t, int(round(bid * 100000)), int(round(ask * 100000)))


class Rebuild(unittest.TestCase):
    def test_append_and_remove_by_index(self):
        ev = [fill(1, T0 + 1 * M, "ENT", "L", 0, 1.10000), fill(1, T0 + 2 * M, "ENT", "L", 1, 1.09930),
              fill(1, T0 + 2 * M, "ENT", "S", 0, 1.10050),
              fill(1, T0 + 3 * M, "EXT", "L", 0, 1.10100), closeby(1, T0 + 3 * M)]
        fl = an.fills_by_seg(ev)
        self.assertEqual(len(fl[1]), 4)                 # close-by deals are not book changes
        book, realised, n = an.rebuild(fl[1])
        self.assertEqual(book, {"L": [109930], "S": [110050]})
        self.assertAlmostEqual(realised, 10.0)          # 1.10100 - 1.10000
        self.assertEqual(n, 1)

    def test_short_exit_realised(self):
        fl = an.fills_by_seg([fill(2, T0, "ENT", "S", 0, 1.20000), fill(2, T0 + M, "EXT", "S", 0, 1.19900)])
        book, realised, n = an.rebuild(fl[2])
        self.assertEqual(book, {"L": [], "S": []})
        self.assertAlmostEqual(realised, 10.0)

    def test_check_against_harness(self):
        book = {"L": [109930], "S": [110050]}
        harness_book = [{"seg_id": "1", "side": "L", "entry": "1.09930"},
                        {"seg_id": "1", "side": "S", "entry": "1.10050"}]
        scalps = [scalp(1, T0 + 3 * M, "LONG", 1.10000, 1.10100)]
        an.check(1, book, 10.0, 1, harness_book, scalps)          # passes silently
        with self.assertRaises(ValueError):
            an.check(1, {"L": [109930], "S": []}, 10.0, 1, harness_book, scalps)   # book differs
        with self.assertRaises(ValueError):
            an.check(1, book, 10.0, 2, harness_book, scalps)                       # count differs
        with self.assertRaises(ValueError):
            an.check(1, book, 13.0, 1, harness_book, scalps)                       # realised differs


class Path(unittest.TestCase):
    def test_floating_and_equity(self):
        # long 1.10000 at t1; long 1.09930 at t2; layer 0 exits at 1.10100 at t3
        fl = [(T0 + 1 * M, "ENT", "L", 0, 110000), (T0 + 2 * M, "ENT", "L", 1, 109930),
              (T0 + 3 * M, "EXT", "L", 0, 110100)]
        ticks = [tick(T0, 1.10000, 1.10002), tick(T0 + 1 * M, 1.09995, 1.09997),
                 tick(T0 + 2 * M, 1.09900, 1.09902), tick(T0 + 3 * M, 1.10100, 1.10102)]
        p = an.Path(fl, comm_pips=0.7)
        for t, b, a in ticks:
            p.on_tick(t, b, a)
        # t1: -0.5; t2: (1.09900 - 1.10000) + (1.09900 - 1.09930) = -13.0; t3: 1.10100 - 1.09930 = +17
        self.assertAlmostEqual(p.worst_float, -13.0)
        self.assertEqual(p.worst_float_t, T0 + 2 * M)
        self.assertAlmostEqual(p.last_float, 17.0)
        self.assertAlmostEqual(p.realised, 10.0)
        self.assertAlmostEqual(p.worst_equity, -13.0)                 # before the close
        self.assertAlmostEqual(p.last_equity, 10.0 - 0.7 + 17.0)
        self.assertEqual(p.minute_min, {(T0 // M): 0.0, (T0 // M) + 1: -0.5, (T0 // M) + 2: -13.0,
                                        (T0 // M) + 3: 17.0})

    def test_short_marked_at_ask(self):
        p = an.Path([(T0, "ENT", "S", 0, 120000)], comm_pips=0.0)
        p.on_tick(T0, 1.20010, 1.20030)
        self.assertAlmostEqual(p.last_float, -3.0)                    # 1.20000 - 1.20030

    def test_a_fill_after_the_tick_is_not_marked(self):
        p = an.Path([(T0 + 5, "ENT", "L", 0, 110000)], comm_pips=0.0)
        p.on_tick(T0, 1.09000, 1.09002)
        self.assertAlmostEqual(p.last_float, 0.0)


class Requests(unittest.TestCase):
    def test_count(self):
        rows = [{"seg_id": "1", "stage": "SEED", "action": "PLACE"},
                {"seg_id": "1", "stage": "ENGINE", "action": "PLACE"},
                {"seg_id": "1", "stage": "FILL", "action": "PLACE"},
                {"seg_id": "1", "stage": "LATTICE", "action": "MODIFY"},
                {"seg_id": "1", "stage": "ENGINE", "action": "REMOVE"},
                {"seg_id": "1", "stage": "FILL", "action": "FILL"},
                {"seg_id": "2", "stage": "ENGINE", "action": "MODIFY"}]
        self.assertEqual(an.requests(rows, closes={1: 2, 2: 0}),
                         {1: {"place": 2, "modify": 1, "remove": 1, "close": 2, "total": 6},
                          2: {"place": 0, "modify": 1, "remove": 0, "close": 0, "total": 1}})


class Fleet(unittest.TestCase):
    def test_sum_carries_each_pair_forward(self):
        mins = {"A": {0: -10.0, 2: -30.0}, "B": {1: -20.0}}
        usd = {"A": 0.1, "B": 0.05}
        s = an.fleet_sum(mins, usd)
        # m0: -1 + 0; m1: -1 + -1; m2: -3 + -1
        self.assertEqual([round(v, 6) for v in s.values()], [-1.0, -2.0, -4.0])
        self.assertEqual(list(s.keys()), [0, 1, 2])
        w = an.fleet_worst(s, (-1.5, -3.5))
        self.assertEqual((round(w["worst"], 6), w["worst_minute"]), (-4.0, 2))
        self.assertEqual(w["below"], {-1.5: 2, -3.5: 1})


if __name__ == "__main__":
    unittest.main()
