"""Tests for sweep.py (hand-derived; run: python -B -m unittest test_sweep).

A geometry sweep on the frozen harness (145f092) through its INPUT files only: one run
file row per (geometry, day window), each segment starting FLAT (empty seed and orders
files, as segment 20 of run_eurusd_d.csv), the other inputs as the live B / C / D rows
since 7 Oct (width 2, stranded 3, deadband 2, re-roll on, gate 0). Scored per segment from
the run's events (SCALP_CLOSED: entry, exit, rolled; ROLL_ACCEPTED) and end book (marked
at the last tick before the segment's end), in pips, gross and after commission.
"""
import json
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import compare as cmp  # noqa: E402
import sweep as sw  # noqa: E402

# 2026-10-01 01:00 server, read as UTC (the harness's server ms)
T1 = 1790816400000
H = 3600000


def scalp(seg, direction, entry, exit_, rolled):
    j = {"direction": direction, "entry_price": entry, "exit_price": exit_, "rolled": rolled}
    return {"seg_id": str(seg), "sync_idx": "-1", "time_ms": "0", "kind": "scalp",
            "code": "SCALP_CLOSED", "json": json.dumps(j)}


def roll(seg, side):
    return {"seg_id": str(seg), "sync_idx": "-1", "time_ms": "0", "kind": "lattice",
            "code": "ROLL_ACCEPTED", "json": json.dumps({"detail": {"side": side}})}


class BuildRows(unittest.TestCase):
    def setUp(self):
        self.windows = [("2026-10-01", "2026-10-01 01:00", "2026-10-01 23:45"),
                        ("2026-10-02", "2026-10-02 01:00", "2026-10-02 23:45")]
        self.geoms = [("a5e5n8", 5.0, 5.0, 8), ("a7e10n8", 7.0, 10.0, 8)]

    def test_header_is_the_harness_run_header(self):
        here = os.path.dirname(os.path.abspath(__file__))
        live = os.path.join(here, "inputs", "eurusd_20261008", "run_eurusd_d.csv")
        with open(live, encoding="utf-8-sig") as f:
            self.assertEqual(f.readline().strip().split(","), list(sw.HEADER))

    def test_rows_geometry_major_flat_start(self):
        rows = sw.build_rows(self.windows, self.geoms)
        self.assertEqual([r["seg_id"] for r in rows], [1, 2, 3, 4])
        self.assertEqual([(r["add_l"], r["exit_s"], r["cap"]) for r in rows],
                         [(5.0, 5.0, 8), (5.0, 5.0, 8), (7.0, 10.0, 8), (7.0, 10.0, 8)])
        r = rows[0]
        self.assertEqual((r["from_ms"], r["to_ms"]), (T1, T1 + 22 * H + 45 * 60000))
        self.assertEqual(rows[1]["from_ms"], T1 + 24 * H)
        self.assertEqual((r["seed_file"], r["orders_file"]), ("", ""))
        self.assertEqual((r["width_l"], r["width_s"], r["stranded"], r["deadband"]), (2.0, 2.0, 3.0, 2.0))
        self.assertEqual((r["lattice"], r["reroll"], r["gate"], r["carry"]), (1, 1, 0, 1))
        self.assertEqual(r["ticks_file"], "ticks_53077984_EURUSD_w2.csv")

    def test_labels(self):
        lab = sw.labels(self.windows, self.geoms)
        self.assertEqual(lab, {1: ("a5e5n8", "2026-10-01"), 2: ("a5e5n8", "2026-10-02"),
                               3: ("a7e10n8", "2026-10-01"), 4: ("a7e10n8", "2026-10-02")})


class ScalpPips(unittest.TestCase):
    def test_long_profit_and_short_loss(self):
        self.assertAlmostEqual(sw.scalp_pips("LONG", 1.13000, 1.13050), 5.0)
        self.assertAlmostEqual(sw.scalp_pips("SHORT", 1.13050, 1.13100), -5.0)


class Score(unittest.TestCase):
    def test_one_segment(self):
        segs = [{"seg_id": 1, "from_ms": T1, "to_ms": T1 + H}]
        events = [scalp(1, "LONG", 1.13000, 1.13050, False),     # +5.0
                  scalp(1, "SHORT", 1.13000, 1.12950, False),    # +5.0
                  scalp(1, "LONG", 1.13300, 1.13100, True),      # -20.0, a roll close
                  roll(1, "L"), roll(1, "L")]
        book = [{"seg_id": "1", "side": "L", "entry": "1.13100"}]
        # last tick before T1 + H: bid 1.13000 -> the long is -10.0 pips open
        ticks = cmp.Ticks([T1, T1 + H - 1, T1 + H], [113050, 113000, 120000], [113052, 113002, 120002])
        out = sw.score(segs, events, book, ticks, comm_pips=0.7)[1]
        self.assertEqual((out["S"], out["R"], out["A"]), (2, 1, 2))
        self.assertAlmostEqual(out["realised"], -10.0)
        self.assertAlmostEqual(out["comm"], 2.1)
        self.assertAlmostEqual(out["open"], -10.0)
        self.assertEqual(out["open_n"], 1)
        self.assertAlmostEqual(out["total_net"], -10.0 - 2.1 - 10.0)

    def test_empty_segment_is_zero(self):
        segs = [{"seg_id": 7, "from_ms": T1, "to_ms": T1 + H}]
        ticks = cmp.Ticks([T1], [113000], [113002])
        out = sw.score(segs, [], [], ticks, comm_pips=0.7)[7]
        self.assertEqual((out["S"], out["R"], out["A"], out["open_n"]), (0, 0, 0, 0))
        self.assertAlmostEqual(out["total_net"], 0.0)


class Edge(unittest.TestCase):
    def test_k_rho_and_rho_with_the_open_book(self):
        # S 40, R 5, open -70 pips, e 5, D 40: k* 7, S/R 8, rho 45*5/(5*40) = 1.125;
        # open as rolls in waiting: R 5 + 70 / 35 = 7, rho 225 / 280 = 0.8036
        e = sw.edge([(40, 5, 5.0, 40.0, -70.0)])
        self.assertAlmostEqual(e["k"], 7.0)
        self.assertAlmostEqual(e["sr"], 8.0)
        self.assertAlmostEqual(e["rho"], 1.125)
        self.assertAlmostEqual(e["rho_open"], 0.8035714, places=6)


class Sweep3(unittest.TestCase):
    """sweep3: add 2.5 / 5 / 7.5 / 10 x exit 2.5 / 5 / 7.5 / 10 x layers 6 / 8 / 10 on each
    of the nine IC pairs, one flat start, the book carried 1-8 Oct, carry pass OFF (no
    per-pair swaps), the pair's live width and stranded = width + 1; EURUSD adds two
    carry-ON controls (7 / 10 / 8 and 5 / 5 / 8) to measure what turning carry off does."""

    def test_eurgbp_rows(self):
        st = sw.get_set("sw3_eurgbp")
        rows = sw.build_rows(st["windows"], st["geoms"], st["base"], st["ticks"])
        self.assertEqual(len(rows), 48)
        r = rows[0]
        self.assertEqual((r["add_l"], r["exit_l"], r["cap"]), (2.5, 2.5, 6))
        self.assertEqual((rows[1]["cap"], rows[3]["exit_l"], rows[12]["add_l"]), (8, 5.0, 5.0))
        self.assertEqual((r["width_l"], r["width_s"], r["stranded"], r["carry"]), (1.0, 1.0, 2.0, 0))
        self.assertEqual(r["ticks_file"], "ticks_53077984_EURGBP__w2.csv")
        self.assertEqual(st["geoms"][0][0], "a2.5e2.5n6")
        self.assertIn("ticks_53077984_EURGBP__w2.csv", sw.to_csv(rows, st["ticks"]).splitlines()[1])

    def test_eurusd_has_two_carry_on_controls(self):
        st = sw.get_set("sw3_eurusd")
        rows = sw.build_rows(st["windows"], st["geoms"], st["base"], st["ticks"])
        self.assertEqual(len(rows), 50)
        self.assertEqual([(r["add_l"], r["exit_l"], r["cap"], r["carry"]) for r in rows[48:]],
                         [(7.0, 10.0, 8, 1), (5.0, 5.0, 8, 1)])
        self.assertEqual(rows[0]["carry"], 0)
        self.assertEqual(rows[0]["ticks_file"], "ticks_53077984_EURUSD_w2.csv")

    def test_commission_in_pips_per_pair(self):
        # $0.06 per close at 0.01 lots (0.03 a fill, measured); USD per pip from scalps
        self.assertAlmostEqual(sw.get_set("sw3_eurusd")["comm_pips"], 0.6)
        self.assertAlmostEqual(sw.get_set("sw3_eurgbp")["comm_pips"], 0.06 / 0.134)
        self.assertAlmostEqual(sw.get_set("sw3_audnzd")["comm_pips"], 0.06 / 0.0574)

    def test_old_sets_unchanged(self):
        st = sw.get_set("sweep1")
        self.assertEqual((st["comm_pips"], st["ticks"]), (0.7, "ticks_53077984_EURUSD_w2.csv"))
        self.assertEqual(sw.build_rows(st["windows"], st["geoms"], st["base"], st["ticks"])[0]["carry"], 1)

    def test_surface_table(self):
        geoms = [("a2.5e2.5n6", 2.5, 2.5, 6, None), ("a2.5e5n6", 2.5, 5.0, 6, None)]
        nets = {"a2.5e2.5n6": -10.0, "a2.5e5n6": 4.0}
        txt = sw.surface(geoms, nets)
        self.assertIn("| layers 6 | exit 2.5 | exit 5 |", txt)
        self.assertIn("| add 2.5 | -10 | +4 |", txt)


class Sweep4(unittest.TestCase):
    """sweep4: 8 weeks (Mon 3 Aug - Fri 25 Sep), each week its own flat start (Mon 00:00 to
    Fri 23:45 server), the nine pairs, 13 grid settings (add 5 / 7.5 / 10 x exit 5 / 7.5 / 10
    at 10 layers; 7.5 / 7.5 and 10 / 10 at 6 and 8 layers) + the pair's live B geometry
    (cap 8); carry off, timing 0; ticks from the one long dump (h8w)."""

    def test_rows_and_windows(self):
        st = sw.get_set("sw4_gbpusd")
        rows = sw.build_rows(st["windows"], st["geoms"], st["base"], st["ticks"])
        self.assertEqual(len(st["windows"]), 8)
        self.assertEqual(len(st["geoms"]), 14)
        self.assertEqual(len(rows), 14 * 8)
        self.assertEqual(st["windows"][0], ("2026-08-03", "2026-08-03 00:00", "2026-08-07 23:45"))
        self.assertEqual(st["windows"][-1], ("2026-09-21", "2026-09-21 00:00", "2026-09-25 23:45"))
        self.assertEqual(st["ticks"], "ticks_53077984_GBPUSD__h8w.csv")
        self.assertEqual(st["geoms"][-1][:4], ("live", 9.0, 10.0, 8))
        self.assertEqual((rows[0]["carry"], rows[0]["width_l"]), (0, 2.5))

    def test_grid_names(self):
        names = [g[0] for g in sw.get_set("sw4_eurgbp")["geoms"]]
        self.assertEqual(names[:3], ["a5e5n10", "a5e7.5n10", "a5e10n10"])
        self.assertIn("a7.5e7.5n6", names)
        self.assertIn("a10e10n8", names)
        self.assertEqual(sw.get_set("sw4_eurgbp")["geoms"][-1][:4], ("live", 3.0, 5.0, 8))


class Sweep5(unittest.TestCase):
    """sweep5: each of the 40 trading days (3 Aug - 25 Sep) its own flat start, 01:00 to 23:45
    server; 5 sweep4 grid settings + the live B geometry; ticks h8w; carry off."""

    def test_days_and_settings(self):
        st = sw.get_set("sw5_nzdchf")
        self.assertEqual(len(st["windows"]), 40)
        self.assertEqual(st["windows"][0], ("2026-08-03", "2026-08-03 01:00", "2026-08-03 23:45"))
        self.assertEqual(st["windows"][4][0], "2026-08-07")          # Friday
        self.assertEqual(st["windows"][5][0], "2026-08-10")          # next Monday
        self.assertEqual(st["windows"][-1][0], "2026-09-25")
        self.assertEqual([g[0] for g in st["geoms"]],
                         ["a5e5n10", "a7.5e7.5n6", "a7.5e7.5n10", "a10e10n6", "a10e10n10", "live"])
        self.assertEqual(st["geoms"][-1][1:4], (3.0, 10.0, 8))
        self.assertEqual(st["ticks"], "ticks_53077984_NZDCHF__h8w.csv")
        rows = sw.build_rows(st["windows"], st["geoms"], st["base"], st["ticks"])
        self.assertEqual(len(rows), 240)
        self.assertEqual(rows[0]["carry"], 0)


if __name__ == "__main__":
    unittest.main()
