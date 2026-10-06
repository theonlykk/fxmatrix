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


class TestHalfPip(unittest.TestCase):
    """A C add probe marked "half": true sits exactly 0.5 pip from the anchor and at or above
    2.5 (operator 5 Oct ~00:00Z, round 2 EURGBP long: C lost at add 4, the flip to 2 is below
    the add-3 floor, so C probes 2.5). Probes without the mark keep the one-pip and add-3 rules."""

    def geo(self, c_long):
        # EURGBP anchor 3 / 5 both sides; C short 4 (one pip), D exits 4 (one pip)
        return {"control": "NZDCAD", "scouts": [], "pairs": {"EURGBP": {
            "anchor": {"L": {"add": 3, "exit": 5}, "S": {"add": 3, "exit": 5}},
            "C": {"L": c_long, "S": {"add": 4}},
            "D": {"L": {"exit": 4}, "S": {"exit": 4}}}}}

    def eurgbp_errs(self, c_long):
        return [e for e in ip.check_plan(self.geo(c_long)) if "outside the guard" not in e]

    def test_h1_half_pip_inward_accepted(self):
        """H1: add 2.5 marked half, 0.5 below the anchor's 3 -> no error."""
        self.assertEqual(self.eurgbp_errs({"add": 2.5, "half": True}), [])

    def test_h2_unmarked_half_pip_rejected(self):
        """H2 (GUARD): add 2.5 without the mark -> 'not one pip from the anchor' (unchanged rule)."""
        self.assertTrue(any("not one pip" in e for e in self.eurgbp_errs({"add": 2.5})))

    def test_h3_marked_probe_must_be_half_a_pip_away(self):
        """H3: add 2 marked half is 1.0 from the anchor -> 'not half a pip from the anchor'."""
        self.assertTrue(any("not half a pip" in e for e in self.eurgbp_errs({"add": 2, "half": True})))

    def test_h4_half_pip_floor(self):
        """H4: anchor 2.5 is itself below the add-3 floor; a half probe at 2.0 (0.5 below it) is below
        the 2.5 half-pip floor -> 'below the half-pip floor 2.5'."""
        g = self.geo({"add": 2.0, "half": True})
        g["pairs"]["EURGBP"]["anchor"]["L"]["add"] = 2.5
        self.assertTrue(any("half-pip floor" in e for e in ip.check_plan(g)))

    def test_h5_half_on_exit_probe_rejected(self):
        """H5: the mark is for C's add probe only; on D's exit -> 'half pips on add probes only'."""
        g = self.geo({"add": 4})
        g["pairs"]["EURGBP"]["D"]["L"] = {"exit": 4.5, "half": True}
        self.assertTrue(any("add probes only" in e for e in ip.check_plan(g)))


BASE_V22 = BASE.replace("InpBreakerEnable=false\n",
                        "InpBreakerEnable=false\nInpSessionEnable=false\nInpFillTimePlace=true\n"
                        "InpSlotNearReserve=8\nInpEntryHorizonPips=0\nInpCapLegA=GBP\n")


def hand_v22(text, gate):
    """The three inputs of main (v2.2a + ADR-166) inserted BY HAND at the EA's positions
    (fxgrind.mq5: InpRollGateOpposite after InpLatticeReroll; InpApiEntryStop and
    InpApiSoftWarn after InpEntryHorizonPips)."""
    return (text.replace("InpLatticeReroll=true\n", "InpLatticeReroll=true\nInpRollGateOpposite=%s\n" % gate)
                .replace("InpEntryHorizonPips=0\n",
                         "InpEntryHorizonPips=0\nInpApiEntryStop=1000000\nInpApiSoftWarn=999000\n"))


class TestRollGate(unittest.TestCase):
    """C133 / ADR-166 (operator 6 Oct ~20:37Z: the gate at 0 on every IC chart, built Wed 7 Oct).
    A round table's "roll_gate" ({"B": n, "C": n, "D": n}, each an int >= -1) writes
    InpRollGateOpposite per fleet, and with it InpApiEntryStop 1000000 / InpApiSoftWarn 999000
    (v2.2a, C100: the values the EA defaults to), so the read-back shows all three. Without the
    key a preset is written as before (old rounds rebuild byte-identically)."""

    def out(self, gate=0):
        return ip.round_preset(BASE_V22, 2.5, (9, 9), (10, 10), "B", "GBPUSD", "anchor", 8, 2.0, 2, roll_gate=gate)

    def test_g1_keys_inserted_at_the_ea_positions(self):
        """G1: exact key order, written out by hand from fxgrind.mq5's input order."""
        want = ["InpMagic", "InpSlot", "InpWidthPips", "InpAddPips", "InpExitPips",
                "InpWidthPipsLong", "InpWidthPipsShort", "InpAddPipsLong", "InpAddPipsShort",
                "InpExitPipsLong", "InpExitPipsShort", "InpMaxLayers", "InpLots",
                "InpStrandedThreshPips", "InpDeadbandPips", "InpEnableCarryPass",
                "InpEnableCommandedEject", "InpAutoEject", "InpVirtualLattice", "InpLatticeReroll",
                "InpRollGateOpposite", "InpBreakerEnable", "InpSessionEnable", "InpFillTimePlace",
                "InpSlotNearReserve", "InpEntryHorizonPips", "InpApiEntryStop", "InpApiSoftWarn",
                "InpCapLegA", "InpTelemetryInstance", "InpConfigWarning", "EnableTelemetry",
                "TelemetryURL", "TelemetryAPIKey", "TelemetryIntervalSec"]
        self.assertEqual([k for k, _ in ip.parse(self.out())], want)

    def test_g2_values_and_nothing_else_changes(self):
        """G2: gate 0, API 1000000 / 999000; of the base's keys only the round's four change
        (as test_changes_and_values); the warning names the gate."""
        p = kv(self.out())
        self.assertEqual((p["InpRollGateOpposite"], p["InpApiEntryStop"], p["InpApiSoftWarn"]),
                         ("0", "1000000", "999000"))
        base = kv(BASE_V22)
        changed = {k for k in base if base[k] != p[k]}
        self.assertEqual(changed, {"InpWidthPips", "InpStrandedThreshPips", "InpDeadbandPips", "InpConfigWarning"})
        self.assertIn("roll gate 0", p["InpConfigWarning"])
        self.assertEqual(kv(self.out(-1))["InpRollGateOpposite"], "-1")

    def test_g3_no_gate_no_new_keys(self):
        """G3 (GUARD): roll_gate not given -> the base's keys exactly, as before this change."""
        out = ip.round_preset(BASE_V22, 2.5, (9, 9), (10, 10), "B", "GBPUSD", "anchor", 8, 2.0, 2)
        self.assertEqual([k for k, _ in ip.parse(out)], [k for k, _ in ip.parse(BASE_V22)])

    def test_g4_validate_accepts_the_generated_preset(self):
        """G4: the generated preset carries the gate and passes validate with gate=0."""
        out = self.out()
        self.assertIn("InpRollGateOpposite=0\n", out)
        self.assertEqual(ip.validate(BASE_V22, out, 2.5, cap=8, deadband="2.0", gate=0), [])

    def test_g5_validate_catches_each_rule(self):
        """G5: on the base geometry (width 5, S 6, deadband 4, cap 8) with the three keys inserted by
        hand: clean with gate 0 (and with "-1" when -1 is wanted); each mutation names its input."""
        good = hand_v22(BASE_V22, "0")
        v = lambda t, g=0: ip.validate(BASE_V22, t, 5.0, cap=8, deadband="4.0", gate=g)
        self.assertEqual(v(good), [])
        self.assertEqual(v(hand_v22(BASE_V22, "-1"), -1), [])
        cases = [(good.replace("InpRollGateOpposite=0", "InpRollGateOpposite=1"), "InpRollGateOpposite"),
                 (good.replace("InpRollGateOpposite=0\n", ""), "InpRollGateOpposite"),
                 (good.replace("InpApiEntryStop=1000000", "InpApiEntryStop=1900"), "InpApiEntryStop"),
                 (good.replace("InpApiSoftWarn=999000", "InpApiSoftWarn=1800"), "InpApiSoftWarn"),
                 (good.replace("InpRollGateOpposite=0\nInpBreakerEnable=false",
                               "InpBreakerEnable=false\nInpRollGateOpposite=0"), "order")]
        for text, word in cases:
            errs = v(text)
            self.assertTrue(any(word in e for e in errs), (word, errs))

    def test_g6_check_plan_reads_roll_gate(self):
        """G6: a table's roll_gate: ints >= -1 for B, C and D; absent = no error (off)."""
        def errs(rg):
            g = json.loads(json.dumps(GEO8))
            if rg is not None:
                g["roll_gate"] = rg
            return [e for e in ip.check_plan(g) if "roll_gate" in e]
        self.assertEqual(errs(None), [])
        self.assertEqual(errs({"B": 0, "C": 0, "D": 0}), [])
        self.assertEqual(errs({"B": -1, "C": 2, "D": 0}), [])
        for bad in ({"B": -2, "C": 0, "D": 0}, {"B": True, "C": 0, "D": 0},
                    {"B": 0.5, "C": 0, "D": 0}, {"B": 0, "C": 0}, {"B": "0", "C": 0, "D": 0}):
            self.assertTrue(errs(bad), bad)

    def test_g7_repo_round2_table_writes_gate_0(self):
        """G7: the committed round-2 table carries roll_gate 0 on B, C, D (operator 6 Oct ~20:37Z)
        and build_round writes it with the API values on all 27, 0 errors."""
        geo = ip.load_table(os.path.join(HERE, "ic_geometry_r2.json"))
        self.assertEqual(geo.get("roll_gate"), {"B": 0, "C": 0, "D": 0})
        files, errs = ip.build_round(geo, ROOT)
        self.assertEqual(errs, [])
        for path, text in files.items():
            p = kv(text)
            self.assertEqual((p.get("InpRollGateOpposite"), p.get("InpApiEntryStop"), p.get("InpApiSoftWarn")),
                             ("0", "1000000", "999000"), path)

    def test_g8_committed_r2_presets_carry_every_ea_input_in_order(self):
        """G8: every committed *_r2.set holds exactly the EA's inputs (ea/fxgrind.mq5 `input` lines),
        in the EA's order: a new EA input missing from a preset fails here."""
        import glob
        import re
        with open(os.path.join(ROOT, "ea", "fxgrind.mq5"), encoding="utf-8", errors="replace") as fh:
            ea = re.findall(r"^input\s+\S+\s+(\w+)", fh.read(), re.M)
        files = sorted(glob.glob(os.path.join(ROOT, "ea", "presets_*", "*_r2.set")))
        self.assertEqual(len(files), 27)
        for f in files:
            self.assertEqual([k for k, _ in ip.parse(ip._read(f))], ea, os.path.basename(f))


if __name__ == "__main__":
    unittest.main()
