"""Tests for build_segments.py: the replay's run_<tag>.csv rows (base prompt
s3.2) from the archive's INIT config events and LATTICE_CONFIG markers
(replay-calibration-eurusd.md s2: a segment from each init to the next, or
to the window end). Times in the run file are SERVER ms; the archive's
ea_time_ms is UTC epoch ms, so the builder adds 3 h. (First draft of this
test assumed ea_time_ms was server time; the real archive showed otherwise:
B's INIT received 2026-10-01 03:58:53Z has ea_time_ms 1790827132001 =
03:58:52.001Z.)
Expected values are derived by hand in the comments, never read back.

    python -B -m unittest research/replay/test_build_segments.py -v
"""
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_segments as bseg  # noqa: E402

# Archive ea_time_ms (UTC): 2026-10-07 02:18:03.005Z = 1791339483005.
U1 = 1791339483005
U2 = U1 + 197000          # the Load, 3 min 17 s later
OFF = 3 * 3600 * 1000
T1 = U1 + OFF             # 05:18:03.005 server
T2 = U2 + OFF
END = 1791507600000       # 2026-10-09 01:00:00 server = 8 Oct 22:00Z


def init(ms, w=2.0, a=7.0, e=10.0, s=3.0, db=2.0, carry=True, ws=None, as_=None, es_=None, cap=8):
    return {"table": "config_events", "event": "INIT", "ea_time_ms": ms,
            "instance_id": "GRIND_EURUSD_OPTB", "magic": 22260201, "max_layers": cap,
            "inputs": {"width_pips_long": w, "width_pips_short": w if ws is None else ws,
                       "add_pips_long": a, "add_pips_short": a if as_ is None else as_,
                       "exit_pips_long": e, "exit_pips_short": e if es_ is None else es_,
                       "stranded_thresh_pips": s, "deadband_pips": db,
                       "enable_carry_pass": carry}}


def lat(ms, detail):
    return {"table": "ea_events", "code": "LATTICE_CONFIG", "ea_time_ms": ms, "detail": detail}


class TestSegments(unittest.TestCase):
    def setUp(self):
        self.rows = [
            init(U1), lat(U1, {"enable": True, "reroll": True, "roll_gate": -1}),
            init(U2, es_=11.0), lat(U2, {"enable": True, "reroll": True, "roll_gate": 0}),
            {"table": "config_events", "event": "DEINIT", "ea_time_ms": U2 - 1},
        ]

    def test_two_segments_cut_at_inits(self):
        segs = bseg.segments(self.rows, T1, END)
        self.assertEqual([(s["from_ms"], s["to_ms"]) for s in segs], [(T1, T2), (T2, END)])

    def test_fields(self):
        s1, s2 = bseg.segments(self.rows, T1, END)
        # first: gate -1 (compile init), exits 10 / 10; second: gate 0, short exit 11
        self.assertEqual((s1["gate"], s1["exit_l"], s1["exit_s"]), (-1, 10.0, 10.0))
        self.assertEqual((s2["gate"], s2["exit_l"], s2["exit_s"]), (0, 10.0, 11.0))
        self.assertEqual((s2["width_l"], s2["add_s"], s2["cap"], s2["stranded"], s2["deadband"]),
                         (2.0, 7.0, 8, 3.0, 2.0))
        self.assertEqual((s2["lattice"], s2["reroll"], s2["carry"], s2["fill_time_place"], s2["reserve"]),
                         (1, 1, 1, 1, 8))
        self.assertEqual((s2["instance"], s2["magic"]), ("GRIND_EURUSD_OPTB", 22260201))

    def test_lattice_defaults_when_keys_absent(self):
        # A 1 Oct LATTICE_CONFIG carries only "enable": re-roll off, gate -1.
        rows = [init(U1), lat(U1, {"enable": True})]
        (s,) = bseg.segments(rows, T1, END)
        self.assertEqual((s["lattice"], s["reroll"], s["gate"]), (1, 0, -1))

    def test_lattice_marker_must_be_near_its_init(self):
        # A LATTICE_CONFIG 10 s after the init does not belong to it: error, not a guess.
        rows = [init(U1), lat(U1 + 10000, {"enable": True})]
        with self.assertRaises(ValueError):
            bseg.segments(rows, T1, END)

    def test_window_clips(self):
        # Inits before the window start are dropped; the window start must BE an init.
        rows = [init(U1 - 3600000), lat(U1 - 3600000, {"enable": False})] + self.rows
        segs = bseg.segments(rows, T1, END)
        self.assertEqual(len(segs), 2)
        with self.assertRaises(ValueError):
            bseg.segments(self.rows, T1 + 1, END)

    def test_run_csv(self):
        segs = bseg.segments(self.rows, T1, END)
        text = bseg.to_run_csv(segs, "ticks_w.csv", seed_names=["", "seed_2.csv"], first_id=7)
        lines = text.splitlines()
        self.assertEqual(lines[0], bseg.RUN_HEADER)
        self.assertTrue(lines[0].endswith(",seed_file,ticks_file,orders_file"))
        self.assertEqual(len(lines[0].split(",")), 23)
        # seg 7: flat (empty seed), seg 8 seeded; no orders files given: the 23rd field empty
        self.assertEqual(lines[1], "7,GRIND_EURUSD_OPTB,22260201,%d,%d,2.0,2.0,7.0,7.0,10.0,10.0,8,3.0,2.0,1,1,-1,1,1,8,,ticks_w.csv," % (T1, T2))
        self.assertEqual(lines[2].split(",")[16], "0")
        self.assertEqual(lines[2].split(",")[20], "seed_2.csv")
        self.assertEqual(len(lines[2].split(",")), 23)

    def test_run_csv_orders_files(self):
        # fix 2: field 23 names the segment's resting-orders file (empty when none).
        segs = bseg.segments(self.rows, T1, END)
        text = bseg.to_run_csv(segs, "ticks_w.csv", seed_names=["", "seed_2.csv"], first_id=7,
                               order_names=["orders_7.csv", ""])
        lines = text.splitlines()
        self.assertTrue(lines[1].endswith(",,ticks_w.csv,orders_7.csv"))
        self.assertTrue(lines[2].endswith(",seed_2.csv,ticks_w.csv,"))
        with self.assertRaises(ValueError):
            bseg.to_run_csv(segs, "ticks_w.csv", seed_names=["", ""], order_names=[""])

    # Added after the mutation round (7 of 16 mutants survived the first six tests).
    def test_init_at_window_end_is_not_a_segment(self):
        # An init exactly at the window end (server END = UTC END - 3 h) starts nothing.
        rows = self.rows + [init(END - OFF), lat(END - OFF, {"enable": True})]
        segs = bseg.segments(rows, T1, END)
        self.assertEqual([(s["from_ms"], s["to_ms"]) for s in segs], [(T1, T2), (T2, END)])

    def test_two_lattice_markers_near_one_init_is_an_error(self):
        rows = [init(U1), lat(U1, {"enable": True}), lat(U1 + 1000, {"enable": True})]
        with self.assertRaises(ValueError):
            bseg.segments(rows, T1, END)

    def test_off_switches_and_per_side_inputs(self):
        # Lattice off, carry off, cap 6; long 7/7/10, short 3/6/9: each field read from its own key.
        rows = [init(U1, w=7.0, a=7.0, e=10.0, ws=3.0, as_=6.0, es_=9.0, carry=False, cap=6),
                lat(U1, {"enable": False})]
        (s,) = bseg.segments(rows, T1, END)
        self.assertEqual((s["width_l"], s["width_s"], s["add_l"], s["add_s"], s["exit_l"], s["exit_s"]),
                         (7.0, 3.0, 7.0, 6.0, 10.0, 9.0))
        self.assertEqual((s["lattice"], s["carry"], s["cap"]), (0, 0, 6))

    def test_run_csv_needs_one_seed_name_per_segment(self):
        segs = bseg.segments(self.rows, T1, END)
        with self.assertRaises(ValueError):
            bseg.to_run_csv(segs, "ticks_w.csv", seed_names=[""])


if __name__ == "__main__":
    unittest.main()
