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


class Sweep6(unittest.TestCase):
    """sweep6 (ADR-167 in the replay, branch replay-adr167): sweep4's eight weeks, each its own
    flat start (Mon 00:00 to Fri 23:45 server), the nine pairs, carry off, timing 0, h8w ticks.
    Three cap-8 settings already in sweep4 (the pair's live B geometry, a7.5e7.5n8, a10e10n8),
    each with no table (off) and with the three shapes of ADR-167 3.3 (step, linear, dead zone
    + linear) in the run file's optional 24th column light_add."""

    def test_settings_tables_and_rows(self):
        st = sw.get_set("sw6_eurusd")
        self.assertEqual(st["windows"], sw.get_set("sw4_eurusd")["windows"])
        names = [g[0] for g in st["geoms"]]
        self.assertEqual(len(names), 12)
        self.assertEqual(names[:4], ["live_off", "live_step", "live_lin", "live_dz"])
        self.assertEqual(names[4], "a7.5e7.5n8_off")
        self.assertEqual(names[-1], "a10e10n8_dz")
        self.assertEqual(st["geoms"][0], ("live_off", 7.0, 10.0, 8, None, ""))
        self.assertEqual(st["geoms"][1][5], "1;1;1;0.5")
        self.assertEqual(st["geoms"][2][5], "0.93;0.86;0.79;0.71;0.64;0.57;0.5")
        self.assertEqual(st["geoms"][3][5], "1;1;0.9;0.8;0.7;0.6;0.5")
        self.assertEqual(st["ticks"], "ticks_53077984_EURUSD__h8w.csv")
        rows = sw.build_rows(st["windows"], st["geoms"], st["base"], st["ticks"])
        self.assertEqual(len(rows), 96)
        self.assertEqual((rows[0]["light_add"], rows[8]["light_add"]), ("", "1;1;1;0.5"))
        self.assertEqual(rows[0]["carry"], 0)

    def test_tables_are_valid(self):
        # entries in (0, 1], 1 to 16 of them, none larger than the one before (the harness's rule)
        for _name, table in sw.TABLES6:
            if table == "":
                continue
            v = [float(x) for x in table.split(";")]
            self.assertTrue(1 <= len(v) <= 16)
            self.assertTrue(all(0.0 < x <= 1.0 for x in v))
            self.assertTrue(all(v[i + 1] <= v[i] for i in range(len(v) - 1)))

    def test_off_rows_equal_sweep4(self):
        # the off rows must be sweep4's rows for the same setting (the comparison's control)
        s6 = sw.get_set("sw6_gbpusd")
        s4 = sw.get_set("sw4_gbpusd")
        r6 = sw.build_rows(s6["windows"], s6["geoms"], s6["base"], s6["ticks"])
        r4 = sw.build_rows(s4["windows"], s4["geoms"], s4["base"], s4["ticks"])
        lab4 = sw.labels(s4["windows"], s4["geoms"])
        lab6 = sw.labels(s6["windows"], s6["geoms"])
        keys = ("from_ms", "to_ms", "width_l", "width_s", "add_l", "add_s", "exit_l", "exit_s", "cap",
                "stranded", "deadband", "lattice", "reroll", "gate", "carry", "ticks_file")
        for name4, name6 in (("live", "live_off"), ("a7.5e7.5n8", "a7.5e7.5n8_off"),
                             ("a10e10n8", "a10e10n8_off")):
            a = [tuple(r[k] for k in keys) for r in r4 if lab4[r["seg_id"]][0] == name4]
            b = [tuple(r[k] for k in keys) for r in r6 if lab6[r["seg_id"]][0] == name6]
            self.assertEqual(len(a), 8)
            self.assertEqual(a, b)

    def test_csv_has_the_light_add_column(self):
        st = sw.get_set("sw6_eurgbp")
        rows = sw.build_rows(st["windows"], st["geoms"], st["base"], st["ticks"])
        lines = sw.to_csv(rows, st["ticks"]).splitlines()
        self.assertEqual(lines[0], ",".join(sw.HEADER) + ",light_add")
        self.assertTrue(lines[1].endswith(",ticks_53077984_EURGBP__h8w.csv,,"))       # off: empty table
        self.assertTrue(lines[9].endswith(",ticks_53077984_EURGBP__h8w.csv,,1;1;1;0.5"))
        self.assertEqual(len(lines[9].split(",")), 24)

    def test_old_csv_has_no_light_add_column(self):
        st = sw.get_set("sw4_eurgbp")
        rows = sw.build_rows(st["windows"], st["geoms"], st["base"], st["ticks"])
        self.assertEqual(sw.to_csv(rows, st["ticks"]).splitlines()[0], ",".join(sw.HEADER))


class Sweep7(unittest.TestCase):
    """sweep7 (operator 12 Oct ~21:57Z: "run uninterrupted over the 8 weeks"): ONE flat start a
    pair at Mon 3 Aug 00:00 server, the book carried to Fri 25 Sep 23:45 server through every
    weekend; two settings: the pair's live B geometry as sweep4 ran it, and the same with the
    width 0.2 (stranded 1.2 = width + 1, deadband 2 unchanged). No light_add column: the
    replay-adr167 build with no table runs as 145f092 (R3; sweep6 C0)."""

    def test_window_and_settings(self):
        st = sw.get_set("sw7_eurusd")
        self.assertEqual(st["windows"], (("8w", "2026-08-03 00:00", "2026-09-25 23:45"),))
        self.assertEqual(st["ticks"], "ticks_53077984_EURUSD__h8w.csv")
        self.assertEqual([g[0] for g in st["geoms"]], ["live", "live_w0.2"])
        rows = sw.build_rows(st["windows"], st["geoms"], st["base"], st["ticks"])
        self.assertEqual(len(rows), 2)
        # 2026-08-03 00:00 and 2026-09-25 23:45, read as UTC
        self.assertEqual((rows[0]["from_ms"], rows[0]["to_ms"]), (1785715200000, 1790379900000))
        self.assertEqual((rows[0]["width_l"], rows[0]["width_s"], rows[0]["stranded"]), (2.0, 2.0, 3.0))
        self.assertEqual((rows[1]["width_l"], rows[1]["width_s"], rows[1]["stranded"]), (0.2, 0.2, 1.2))
        for r in rows:
            self.assertEqual((r["add_l"], r["add_s"], r["exit_l"], r["exit_s"], r["cap"]),
                             (7.0, 7.0, 10.0, 10.0, 8))
            self.assertEqual((r["deadband"], r["lattice"], r["reroll"], r["gate"], r["carry"]),
                             (2.0, 1, 1, 0, 0))
            self.assertEqual((r["seed_file"], r["orders_file"]), ("", ""))
            self.assertNotIn("light_add", r)

    def test_live_row_is_sweep4s_live_but_for_the_window(self):
        for pair in ("gbpusd", "audchf", "eurgbp"):
            s7 = sw.get_set("sw7_" + pair)
            s4 = sw.get_set("sw4_" + pair)
            r7 = sw.build_rows(s7["windows"], s7["geoms"], s7["base"], s7["ticks"])[0]
            r4 = [r for r in sw.build_rows(s4["windows"], s4["geoms"], s4["base"], s4["ticks"])
                  if sw.labels(s4["windows"], s4["geoms"])[r["seg_id"]][0] == "live"][0]
            for k in ("width_l", "width_s", "add_l", "add_s", "exit_l", "exit_s", "cap", "stranded",
                      "deadband", "lattice", "reroll", "gate", "carry", "fill_time_place", "reserve",
                      "instance", "magic", "ticks_file"):
                self.assertEqual(r7[k], r4[k], (pair, k))
            self.assertEqual(r7["from_ms"], r4["from_ms"])     # Mon 3 Aug 00:00, sweep4's first week

    def test_width_rows_per_pair(self):
        st = sw.get_set("sw7_gbpusd")
        rows = sw.build_rows(st["windows"], st["geoms"], st["base"], st["ticks"])
        self.assertEqual((rows[0]["width_l"], rows[0]["stranded"]), (2.5, 3.5))
        self.assertEqual((rows[1]["width_l"], rows[1]["stranded"]), (0.2, 1.2))
        self.assertEqual((rows[1]["add_l"], rows[1]["exit_l"]), (9.0, 10.0))

    def test_csv_has_23_columns(self):
        st = sw.get_set("sw7_nzdcad")
        rows = sw.build_rows(st["windows"], st["geoms"], st["base"], st["ticks"])
        lines = sw.to_csv(rows, st["ticks"]).splitlines()
        self.assertEqual(lines[0], ",".join(sw.HEADER))
        self.assertEqual(len(lines), 3)
        self.assertEqual(lines[2].split(",")[5:7], ["0.2", "0.2"])
        self.assertEqual(lines[2].split(",")[12], "1.2")
        self.assertEqual(len(lines[2].split(",")), 23)

    def test_old_sets_unchanged_by_the_width_field(self):
        st = sw.get_set("sw6_eurusd")
        rows = sw.build_rows(st["windows"], st["geoms"], st["base"], st["ticks"])
        self.assertEqual({(r["width_l"], r["stranded"]) for r in rows}, {(2.0, 3.0)})


# sw8: OPT against ALT (the two-arm t1 presets, 21 Oct) on the eight pre-fit weeks. Hand values
# from the presets (D: ea/presets_d/*_t1.set; E's ALT: ea/presets_e/*_alt_e_t1.set):
# (OPT width, add = exit), (ALT q95 width, add = exit), (ALT q90 width, add = exit)
SW8 = {"eurusd": ((2.0, 7.0), (7.0, 27.0), (6.0, 23.0)),
       "gbpusd": ((2.5, 9.0), (7.5, 30.0), (6.0, 24.0)),
       "eurgbp": ((1.0, 3.0), (5.0, 19.0), (4.0, 16.0)),
       "audcad": ((1.5, 6.0), (7.0, 27.0), (7.0, 27.0)),
       "audchf": ((1.0, 4.0), (5.5, 22.0), (5.5, 21.0)),
       "cadchf": ((1.0, 4.0), (3.0, 12.0), (2.5, 9.0))}
REPO = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))


def preset(path):
    out = {}
    with open(os.path.join(REPO, path)) as f:
        for line in f:
            line = line.strip()
            if "=" in line:
                k, v = line.split("=", 1)
                out[k] = v
    return out


class Sweep8(unittest.TestCase):
    def test_windows_eight_weeks_then_the_carried_window(self):
        st = sw.get_set("sw8_eurusd")
        self.assertEqual(len(st["windows"]), 9)
        self.assertEqual(st["windows"][0], ("2026-08-03", "2026-08-03 00:00", "2026-08-07 23:45"))
        self.assertEqual(st["windows"][7], ("2026-09-21", "2026-09-21 00:00", "2026-09-25 23:45"))
        self.assertEqual(st["windows"][8], ("8w", "2026-08-03 00:00", "2026-09-25 23:45"))

    def test_geometries_per_pair(self):
        for pair, ((ow, oa), (aw, aa), (bw, ba)) in SW8.items():
            g = sw.get_set("sw8_" + pair)["geoms"]
            self.assertEqual([x[0] for x in g], ["opt_t1", "alt_q95", "alt_q90"], pair)
            self.assertEqual(g[0][1:4] + (g[0][6],), (oa, oa, 7, ow), pair)
            self.assertEqual(g[1][1:4] + (g[1][6],), (aa, aa, 7, aw), pair)
            self.assertEqual(g[2][1:4] + (g[2][6],), (ba, ba, 7, bw), pair)

    def test_geometries_equal_the_live_presets(self):
        for pair in SW8:
            g = sw.get_set("sw8_" + pair)["geoms"]
            files = ("ea/presets_d/%s_opt_d_t1.set" % pair, "ea/presets_d/%s_alt_d_t1.set" % pair,
                     "ea/presets_e/%s_alt_e_t1.set" % pair)
            for geo, path in zip(g, files):
                p = preset(path)
                self.assertEqual(float(p["InpWidthPips"]), geo[6], path)
                self.assertEqual(float(p["InpAddPips"]), geo[1], path)
                self.assertEqual(float(p["InpExitPips"]), geo[2], path)
                self.assertEqual(int(p["InpMaxLayers"]), geo[3], path)
                self.assertEqual(float(p["InpStrandedThreshPips"]), round(geo[6] + 1.0, 6), path)
                self.assertEqual(float(p["InpDeadbandPips"]), 2.0, path)
                self.assertEqual(p["InpRollGateOpposite"], "0", path)

    def test_rows_flat_start_carry_off(self):
        st = sw.get_set("sw8_gbpusd")
        rows = sw.build_rows(st["windows"], st["geoms"], st["base"], st["ticks"])
        self.assertEqual(len(rows), 27)
        self.assertEqual([r["seg_id"] for r in rows], list(range(1, 28)))
        for r in rows:
            self.assertEqual((r["cap"], r["carry"], r["gate"], r["lattice"], r["reroll"], r["deadband"]),
                             (7, 0, 0, 1, 1, 2.0))
            self.assertEqual((r["seed_file"], r["orders_file"]), ("", ""))
            self.assertEqual(r["ticks_file"], "ticks_53077984_GBPUSD__h8w.csv")
            self.assertEqual(r["width_l"], r["width_s"])
            self.assertEqual(r["stranded"], round(r["width_l"] + 1.0, 6))
        self.assertEqual((rows[9]["width_l"], rows[9]["add_l"], rows[9]["exit_s"]), (7.5, 30.0, 30.0))
        self.assertEqual((rows[26]["width_l"], rows[26]["add_s"], rows[26]["exit_l"]), (6.0, 24.0, 24.0))
        self.assertEqual((rows[8]["from_ms"], rows[8]["to_ms"]), (1785715200000, 1790379900000))

    def test_labels(self):
        st = sw.get_set("sw8_eurusd")
        lab = sw.labels(st["windows"], st["geoms"])
        self.assertEqual(lab[1], ("opt_t1", "2026-08-03"))
        self.assertEqual(lab[9], ("opt_t1", "8w"))
        self.assertEqual(lab[10], ("alt_q95", "2026-08-03"))
        self.assertEqual(lab[27], ("alt_q90", "8w"))

    def test_csv_has_the_sessions_column(self):
        st = sw.get_set("sw8_eurusd")
        rows = sw.build_rows(st["windows"], st["geoms"], st["base"], st["ticks"])
        lines = sw.to_csv(rows, st["ticks"], st["sessions"]).rstrip("\n").split("\n")
        self.assertEqual(lines[0].split(",")[-1], "sessions_file")
        self.assertEqual(len(lines), 28)
        for line in lines[1:]:
            f = line.split(",")
            self.assertEqual(len(f), 24)
            self.assertEqual(f[23], "sessions_eurusd_ic.csv")
            self.assertEqual(f[21], "ticks_53077984_EURUSD__h8w.csv")

    def test_commission_and_pip_value(self):
        st = sw.get_set("sw8_audcad")
        self.assertAlmostEqual(st["pip_usd"], 0.0714)
        self.assertAlmostEqual(st["comm_pips"], 0.06 / 0.0714)

    def test_only_fleet_es_six_pairs(self):
        for bad in ("sw8_nzdcad", "sw8_audnzd", "sw8_nzdchf", "sw8_gbpchf"):
            with self.assertRaises(KeyError):
                sw.get_set(bad)

    def test_older_sets_have_no_sessions_column(self):
        for tag in ("sw7_eurusd", "sw4_cadchf", "sweep2"):
            st = sw.get_set(tag)
            self.assertIsNone(st.get("sessions"))
            rows = sw.build_rows(st["windows"], st["geoms"], st["base"], st["ticks"])
            self.assertEqual(len(sw.to_csv(rows, st["ticks"]).split("\n")[1].split(",")), 23)


# sw9: the October surface (21 Oct): one flat start 1 Oct 04:00 server, the book carried to 20 Oct 23:45, EURUSD
# w2hw ticks, carry ON, sessions on; cap 8 grid add x exit, one run file per exit (sw9_e<exit>), plus the add = exit
# diagonal at cap 7 (sw9_d7). Width = add / 4 rounded UP to 0.5, at least 2.0 (ADR-153: add / width <= 4).
ADDS9 = (4, 5, 6, 7, 8, 10, 12, 14, 16, 18, 20, 23, 27)
EXITS9 = (4, 5, 7, 9, 11, 14, 18, 23, 27)
WIDTH9 = {4: 2.0, 5: 2.0, 6: 2.0, 7: 2.0, 8: 2.0, 10: 2.5, 12: 3.0, 14: 3.5, 16: 4.0, 18: 4.5, 20: 5.0, 23: 6.0, 27: 7.0}


class Sweep9(unittest.TestCase):
    def test_one_carried_window(self):
        for tag in ("sw9_e4", "sw9_e27", "sw9_d7"):
            st = sw.get_set(tag)
            self.assertEqual(st["windows"], (("oct", "2026-10-01 04:00", "2026-10-20 23:45"),))

    def test_exit_files_cap8_grid(self):
        seen = set()
        for e in EXITS9:
            g = sw.get_set("sw9_e%d" % e)["geoms"]
            self.assertEqual(len(g), 13)
            for (name, a, ex, cap, carry, light, w), add in zip(g, ADDS9):
                self.assertEqual((name, a, ex, cap, carry, light, w),
                                 ("a%de%dn8" % (add, e), float(add), float(e), 8, None, None, WIDTH9[add]))
                seen.add(name)
        self.assertEqual(len(seen), 117)

    def test_diagonal_cap7(self):
        g = sw.get_set("sw9_d7")["geoms"]
        self.assertEqual([x[0] for x in g], ["a%de%dn7" % (a, a) for a in ADDS9])
        for (name, a, ex, cap, carry, light, w), add in zip(g, ADDS9):
            self.assertEqual((a, ex, cap, w), (float(add), float(add), 7, WIDTH9[add]))

    def test_width_rule_ratio_at_most_4(self):
        for add, w in WIDTH9.items():
            self.assertLessEqual(add / w, 4.0)
            self.assertEqual(w, sw.width9(float(add)))

    def test_rows_carry_on_ticks_and_window(self):
        st = sw.get_set("sw9_e7")
        rows = sw.build_rows(st["windows"], st["geoms"], st["base"], st["ticks"])
        self.assertEqual(len(rows), 13)
        for r in rows:
            self.assertEqual((r["carry"], r["gate"], r["lattice"], r["reroll"], r["deadband"], r["cap"]), (1, 0, 1, 1, 2.0, 8))
            self.assertEqual((r["seed_file"], r["orders_file"]), ("", ""))
            self.assertEqual(r["ticks_file"], "ticks_53077984_EURUSD_w2hw.csv")
            self.assertEqual((r["from_ms"], r["to_ms"]), (1790827200000, 1792540800000 - 15 * 60000))
            self.assertEqual(r["stranded"], round(r["width_l"] + 1.0, 6))
            self.assertEqual((r["instance"], r["magic"]), ("GRIND_EURUSD_OPTD", 22260201))
        self.assertEqual((rows[3]["add_l"], rows[3]["exit_s"], rows[3]["width_s"]), (7.0, 7.0, 2.0))

    def test_csv_sessions_column(self):
        st = sw.get_set("sw9_d7")
        rows = sw.build_rows(st["windows"], st["geoms"], st["base"], st["ticks"])
        lines = sw.to_csv(rows, st["ticks"], st["sessions"]).rstrip("\n").split("\n")
        self.assertEqual(len(lines), 14)
        self.assertTrue(all(len(x.split(",")) == 24 and x.endswith(",sessions_eurusd_ic.csv") for x in lines[1:]))

    def test_commission_as_sweep8(self):
        st = sw.get_set("sw9_e9")
        self.assertAlmostEqual(st["comm_pips"], 0.6)
        self.assertAlmostEqual(st["pip_usd"], 0.1)

    def test_no_other_sw9_tags(self):
        for bad in ("sw9_e6", "sw9_d8", "sw9_eurusd"):
            with self.assertRaises(KeyError):
                sw.get_set(bad)


if __name__ == "__main__":
    unittest.main()
