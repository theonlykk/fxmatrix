#!/usr/bin/env python3
"""Tests for scripts/ic_presets.py (cap-10 reload and round-2 presets; cap10-reload s2-s3,
compass-round s4-s6). Expected values are derived by hand in the comments.

    python -m unittest scripts/test_ic_presets.py -v

GUARD tests pass with the stub too; they are marked GUARD in their docstring.
"""
import json
import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)

import ic_presets as ip  # noqa: E402

BASE = """InpMagic=22260101
InpSlot=OPT
InpWidthPips=5.0
InpAddPips=9.0
InpExitPips=10.0
InpWidthPipsLong=-1.0
InpWidthPipsShort=-1.0
InpAddPipsLong=-1.0
InpAddPipsShort=-1.0
InpExitPipsLong=-1.0
InpExitPipsShort=-1.0
InpMaxLayers=8
InpLots=0.01
InpStrandedThreshPips=6.0
InpDeadbandPips=4.0
InpEnableCarryPass=true
InpEnableCommandedEject=true
InpAutoEject=false
InpVirtualLattice=true
InpLatticeReroll=true
InpBreakerEnable=false
InpTelemetryInstance=GRIND_GBPUSD_OPTB
InpConfigWarning=FLEET B C63 (IC Markets demo 53066709, box 1): main 0335f25, lattice on, auto-eject off
EnableTelemetry=true
TelemetryURL=https://pipshed.com/api/telemetry/push
TelemetryAPIKey=
TelemetryIntervalSec=60
"""


def kv(text):
    return dict(ip.parse(text))


class TestWidth(unittest.TestCase):
    def test_width_formula(self):
        # ceil to the half pip of (max(add_L, add_S) + 2) / 4
        cases = [((9, 9), 3.0),   # 11/4 = 2.75 -> 3.0
                 ((7, 7), 2.5),   # 9/4 = 2.25 -> 2.5
                 ((3, 3), 1.5),   # 5/4 = 1.25 -> 1.5
                 ((6, 6), 2.0),   # 8/4 = 2.00 exactly -> 2.0, not 2.5
                 ((4, 4), 1.5),   # 6/4 = 1.50 exactly -> 1.5
                 ((9, 7), 3.0),   # per side: the LARGER add sets it
                 ((7, 9), 3.0)]
        for (l, s), w in cases:
            self.assertAlmostEqual(ip.width_for(l, s), w, msg=str((l, s)))

    def test_guard_ratio(self):
        # ADR-153: 0.5 <= add / width <= 4.0 inclusive
        self.assertTrue(ip.guard_ok(3.0, 12.0))   # 4.0 exactly
        self.assertFalse(ip.guard_ok(2.0, 9.0))   # 4.5
        self.assertTrue(ip.guard_ok(1.5, 3.0))    # 2.0
        self.assertFalse(ip.guard_ok(6.0, 2.5))   # 0.4167


class TestSideFields(unittest.TestCase):
    def test_equal_sides_use_the_base_input(self):
        self.assertEqual(ip.side_fields("Add", 8, 8),
                         {"InpAddPips": "8.0", "InpAddPipsLong": "-1.0", "InpAddPipsShort": "-1.0"})

    def test_different_sides_are_both_explicit(self):
        # base = the long value (the base must pass the guard too), both sides explicit
        self.assertEqual(ip.side_fields("Exit", 9, 10),
                         {"InpExitPips": "9.0", "InpExitPipsLong": "9.0", "InpExitPipsShort": "10.0"})

    def test_resolved_reads_sides_with_inherit(self):
        p = kv(BASE.replace("InpAddPipsShort=-1.0", "InpAddPipsShort=7.0"))
        self.assertEqual(ip.resolved(p, "Add"), (9.0, 7.0))
        self.assertEqual(ip.resolved(p, "Exit"), (10.0, 10.0))


class TestC10(unittest.TestCase):
    def test_only_cap_width_s_and_warning_change(self):
        out = ip.c10(BASE, 3.0, "B", "GBPUSD")
        a, b = ip.parse(BASE), ip.parse(out)
        self.assertEqual([k for k, _ in a], [k for k, _ in b])        # same keys, same order
        changed = {k for (k, v1), (_k, v2) in zip(a, b) if v1 != v2}
        self.assertEqual(changed, {"InpMaxLayers", "InpWidthPips", "InpStrandedThreshPips",
                                   "InpConfigWarning"})
        p = kv(out)
        self.assertEqual(p["InpMaxLayers"], "10")
        self.assertEqual(p["InpWidthPips"], "3.0")
        self.assertEqual(p["InpStrandedThreshPips"], "4.0")              # W + 1
        self.assertEqual(p["InpAddPips"], "9.0")                          # kept
        self.assertTrue(out.endswith("\n"))

    def test_warning_names_fleet_account_box(self):
        p = kv(ip.c10(BASE, 3.0, "B", "GBPUSD"))
        w = p["InpConfigWarning"]
        for part in ("FLEET B", "cap-10", "53066709", "wine-test", "width 3.0"):
            self.assertIn(part, w)


class TestP2(unittest.TestCase):
    def setUp(self):
        self.c10 = ip.c10(BASE, 3.0, "B", "GBPUSD")

    def test_per_side_values_written(self):
        p = kv(ip.p2(self.c10, (9, 8), (10, 10), "C", "GBPUSD", "ADD probe"))
        self.assertEqual((p["InpAddPips"], p["InpAddPipsLong"], p["InpAddPipsShort"]),
                         ("9.0", "9.0", "8.0"))
        self.assertEqual((p["InpExitPips"], p["InpExitPipsLong"], p["InpExitPipsShort"]),
                         ("10.0", "-1.0", "-1.0"))
        self.assertEqual(p["InpWidthPips"], "3.0")
        self.assertEqual(p["InpMaxLayers"], "10")
        self.assertIn("ADD probe", p["InpConfigWarning"])


GEO = {
    "cap": 10, "control": "NZDCAD", "scouts": ["AUDUSD"],
    "pairs": {
        "GBPUSD": {"anchor": {"L": {"add": 9, "exit": 10}, "S": {"add": 9, "exit": 10}},
                   "C": {"L": {"add": 8}, "S": {"add": 10}},
                   "D": {"L": {"exit": 9}, "S": {"exit": 11}}},
        "NZDCAD": {"anchor": {"L": {"add": 8, "exit": 10}, "S": {"add": 8, "exit": 10}}},
    }}


class TestPlan(unittest.TestCase):
    def test_round2_values_per_fleet_and_side(self):
        # B = anchor; C = probe add, anchor exit; D = anchor add, probe exit; control = anchor
        plan = ip.p2_values(GEO)
        self.assertEqual(plan[("GBPUSD", "B")], ((9, 9), (10, 10), "anchor"))
        self.assertEqual(plan[("GBPUSD", "C")], ((8, 10), (10, 10), "ADD probe"))
        self.assertEqual(plan[("GBPUSD", "D")], ((9, 9), (9, 11), "EXIT probe"))
        for f in "BCD":
            self.assertEqual(plan[("NZDCAD", f)], ((8, 8), (10, 10), "control (anchor)"))

    def test_probe_must_be_one_pip_from_the_anchor(self):
        bad = json.loads(json.dumps(GEO))
        bad["pairs"]["GBPUSD"]["C"]["L"]["add"] = 7     # 2 pips
        self.assertTrue(any("GBPUSD C L" in e for e in ip.check_plan(bad)))
        bad = json.loads(json.dumps(GEO))
        bad["pairs"]["GBPUSD"]["D"]["S"]["exit"] = 10   # 0 pips: no probe
        self.assertTrue(any("GBPUSD D S" in e for e in ip.check_plan(bad)))
        self.assertEqual(ip.check_plan(GEO), [])

    def test_add_floor_and_control_unprobed(self):
        bad = json.loads(json.dumps(GEO))
        bad["pairs"]["GBPUSD"]["anchor"]["L"]["add"] = 3
        bad["pairs"]["GBPUSD"]["C"]["L"]["add"] = 2     # below the add-3 floor (s8.11: OPEN)
        self.assertTrue(any("floor" in e for e in ip.check_plan(bad)))
        bad = json.loads(json.dumps(GEO))
        bad["pairs"]["NZDCAD"]["C"] = {"L": {"add": 7}, "S": {"add": 7}}
        self.assertTrue(any("control" in e for e in ip.check_plan(bad)))

    def test_width_from_the_anchor_with_headroom(self):
        # GBPUSD anchor adds 9/9 -> width 3.0; probes 8 and 10 -> 2.67, 3.33 inside the guard
        self.assertAlmostEqual(ip.pair_width(GEO, "GBPUSD"), 3.0)


class TestValidate(unittest.TestCase):
    def test_clean_file_passes(self):
        out = ip.c10(BASE, 3.0, "B", "GBPUSD")
        self.assertEqual(ip.validate(BASE, out, 3.0), [])

    def test_catches_each_rule(self):
        good = ip.c10(BASE, 3.0, "B", "GBPUSD")
        cases = {
            "key": good.replace("TelemetryAPIKey=", "TelemetryAPIKey=abc"),
            "InpMaxLayers": good.replace("InpMaxLayers=10", "InpMaxLayers=8"),
            "Stranded": good.replace("InpStrandedThreshPips=4.0", "InpStrandedThreshPips=6.0"),
            "guard": good.replace("InpAddPips=9.0", "InpAddPips=13.0"),
            "InpMagic": good.replace("InpMagic=22260101", "InpMagic=22260102"),
            "InpLatticeReroll": good.replace("InpLatticeReroll=true", "InpLatticeReroll=false"),
            "order": good.replace("InpSlot=OPT\n", "").replace("InpMagic=22260101\n",
                                                                "InpMagic=22260101\nInpSlot=OPT\nX=1\n"),
        }
        for word, text in cases.items():
            errs = ip.validate(BASE, text, 3.0)
            self.assertTrue(errs, word)
            self.assertTrue(any(word.lower() in e.lower() for e in errs), (word, errs))


class TestRepo(unittest.TestCase):
    def test_live_preset_map(self):
        """GUARD: the charts' live presets (fleet-d s6.6): B *_b_lat; C and D *_p1 on the
        seven probed pairs, *_lat on NZDCAD and AUDNZD; 27 files, all present."""
        names = {
            "B": ["%s_opt_b_lat.set" % p for p in ("gbpusd", "eurusd", "eurgbp", "audcad", "audchf",
                                                  "cadchf", "nzdchf", "nzdcad", "audnzd")],
        }
        for f in ("c", "d"):
            names[f.upper()] = ["%s_opt_%s_p1.set" % (p, f) for p in (
                "gbpusd", "eurusd", "eurgbp", "audcad", "audchf", "cadchf", "nzdchf")] + \
                ["nzdcad_opt_%s_lat.set" % f, "audnzd_opt_%s_lat.set" % f]
        for fleet, files in names.items():
            for n in files:
                self.assertTrue(os.path.exists(os.path.join(
                    ROOT, "ea", "presets_" + fleet.lower(), n)), n)

    def test_repo_table_builds_clean(self):
        """The committed table (scripts/ic_geometry.json) builds both stages with no errors:
        27 c10 files and 30 p2 files (nine pairs + the AUDUSD scout on three fleets)."""
        geo = ip.load_table(os.path.join(HERE, "ic_geometry.json"))
        self.assertEqual(ip.check_plan(geo), [])
        c10, errs = ip.build(geo, ROOT, "c10")
        self.assertEqual(errs, [])
        self.assertEqual(len(c10), 27)
        p2, errs = ip.build(geo, ROOT, "p2", c10_texts=c10)
        self.assertEqual(errs, [])
        self.assertEqual(len(p2), 30)


# ---------------------------------------------------------------- this week's rounds at cap 8 (memo 2026-10-05)

GEO8 = {
    "cap": 8, "deadband": 2.0, "width": "tight", "round": 2, "control": "NZDCAD", "scouts": [],
    "pairs": {
        "GBPUSD": {"anchor": {"L": {"add": 9, "exit": 10}, "S": {"add": 9, "exit": 10}},
                   "C": {"L": {"add": 8}, "S": {"add": 10}},
                   "D": {"L": {"exit": 9}, "S": {"exit": 11}}},
        "NZDCAD": {"anchor": {"L": {"add": 8, "exit": 10}, "S": {"add": 8, "exit": 10}}},
    }}


class TestTightWidth(unittest.TestCase):
    def test_tight_width_formula(self):
        # ceil to the half pip of (the largest add any fleet runs on the pair this round) / 4
        cases = [((9, 9, 8, 8), 2.5),   # 9/4 = 2.25 -> 2.5
                 ((3, 3, 4, 4), 1.0),   # 4/4 = 1.00 exactly -> 1.0
                 ((6, 6, 5, 5), 1.5),   # 6/4 = 1.50 exactly -> 1.5
                 ((7, 7, 6, 6), 2.0),   # 7/4 = 1.75 -> 2.0
                 ((8,), 2.0),           # 8/4 = 2.00 exactly
                 ((9, 10), 2.5)]        # 10/4 = 2.50 exactly
        for adds, w in cases:
            self.assertAlmostEqual(ip.tight_width(adds), w, msg=str(adds))

    def test_pair_round_width_uses_every_fleets_adds(self):
        # GBPUSD: anchor 9/9, C probes 8 (L) and 10 (S): largest 10 -> 2.5; NZDCAD control 8/8 -> 2.0
        self.assertAlmostEqual(ip.round_width(GEO8, "GBPUSD"), 2.5)
        self.assertAlmostEqual(ip.round_width(GEO8, "NZDCAD"), 2.0)
        # added after the mutation round (ignoring C's adds survived: GBPUSD's anchor 9 alone also gives 2.5):
        # anchor 8, C probes 9 -> 9/4 = 2.25 -> 2.5 (the anchor alone would give 2.0)
        geo = json.loads(json.dumps(GEO8))
        geo["pairs"]["AUDNZD"] = {"anchor": {"L": {"add": 8, "exit": 10}, "S": {"add": 8, "exit": 10}},
                                  "C": {"L": {"add": 9}, "S": {"add": 9}}}
        self.assertAlmostEqual(ip.round_width(geo, "AUDNZD"), 2.5)


class TestRoundPreset(unittest.TestCase):
    def test_changes_and_values(self):
        # BASE (GBPUSD B: width 5, add 9, S 6, deadband 4, cap 8) at width 2.5, deadband 2, anchor 9/9, 10/10:
        # width 2.5, S = W + 1 = 3.5, deadband 2.0, cap stays 8; adds and exits on the base input, sides -1
        out = ip.round_preset(BASE, 2.5, (9, 9), (10, 10), "B", "GBPUSD", "anchor", 8, 2.0, 2)
        a, b = ip.parse(BASE), ip.parse(out)
        self.assertEqual([k for k, _ in a], [k for k, _ in b])
        changed = {k for (k, v1), (_k, v2) in zip(a, b) if v1 != v2}
        self.assertEqual(changed, {"InpWidthPips", "InpStrandedThreshPips", "InpDeadbandPips", "InpConfigWarning"})
        p = kv(out)
        self.assertEqual((p["InpWidthPips"], p["InpStrandedThreshPips"], p["InpDeadbandPips"], p["InpMaxLayers"]),
                         ("2.5", "3.5", "2.0", "8"))
        for part in ("FLEET B", "round 2", "GBPUSD", "anchor", "cap 8", "width 2.5", "deadband 2.0"):
            self.assertIn(part, p["InpConfigWarning"])

    def test_probe_sides_written(self):
        # C: adds 8 (L) / 10 (S) differ -> base = long 8, both sides explicit; exits equal -> base 10, sides -1
        p = kv(ip.round_preset(BASE, 2.5, (8, 10), (10, 10), "C", "GBPUSD", "ADD probe", 8, 2.0, 2))
        self.assertEqual((p["InpAddPips"], p["InpAddPipsLong"], p["InpAddPipsShort"]), ("8.0", "8.0", "10.0"))
        self.assertEqual((p["InpExitPips"], p["InpExitPipsLong"], p["InpExitPipsShort"]), ("10.0", "-1.0", "-1.0"))

    def test_validate_with_cap_and_deadband(self):
        out = ip.round_preset(BASE, 2.5, (9, 9), (10, 10), "B", "GBPUSD", "anchor", 8, 2.0, 2)
        self.assertEqual(ip.validate(BASE, out, 2.5, cap=8, deadband="2.0"), [])
        bad = out.replace("InpDeadbandPips=2.0", "InpDeadbandPips=4.0")
        self.assertTrue(any("deadband" in e.lower() for e in ip.validate(BASE, bad, 2.5, cap=8, deadband="2.0")))
        bad = out.replace("InpMaxLayers=8", "InpMaxLayers=10")
        self.assertTrue(any("maxlayers" in e.lower() for e in ip.validate(BASE, bad, 2.5, cap=8, deadband="2.0")))


class TestRoundBuild(unittest.TestCase):
    def test_repo_round2_table_builds_clean(self):
        """The committed round-2 table (scripts/ic_geometry_r2.json) builds 27 _r2 files with no
        errors (nine pairs x B, C, D), every width the tight width of its pair, the same on B, C, D,
        cap 8, deadband 2.0, S = W + 1."""
        geo = ip.load_table(os.path.join(HERE, "ic_geometry_r2.json"))
        files, errs = ip.build_round(geo, ROOT)
        self.assertEqual(errs, [])
        self.assertEqual(len(files), 27)
        for path, text in files.items():
            p = kv(text)
            self.assertTrue(path.endswith("_r2.set"), path)
            self.assertEqual((p["InpMaxLayers"], p["InpDeadbandPips"]), ("8", "2.0"))
            self.assertAlmostEqual(float(p["InpStrandedThreshPips"]), float(p["InpWidthPips"]) + 1.0)
        widths = {}
        for path, text in files.items():
            pair = os.path.basename(path).split("_")[0].upper()
            widths.setdefault(pair, set()).add(kv(text)["InpWidthPips"])
        self.assertTrue(all(len(v) == 1 for v in widths.values()), widths)
        # provisional table: GBPUSD 2.5, EURGBP 1.0 (C probes 4), AUDCAD 1.5, NZDCAD 2.0
        self.assertEqual({k: v.pop() for k, v in widths.items() if k in ("GBPUSD", "EURGBP", "AUDCAD", "NZDCAD")},
                         {"GBPUSD": "2.5", "EURGBP": "1.0", "AUDCAD": "1.5", "NZDCAD": "2.0"})


if __name__ == "__main__":
    unittest.main()
