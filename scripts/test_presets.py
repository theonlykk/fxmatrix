#!/usr/bin/env python3
"""Unit tests for ea/presets/*.set -- preset convention and NZDCHF pilot geometry."""
from __future__ import annotations

import unittest
from pathlib import Path

PRESET_DIR = Path(__file__).resolve().parent.parent / "ea" / "presets"

EXPECTED_DEADBAND = 4.0
ADD_WIDTH_MULTIPLE = 2.0

NZDCHF_OPT = {
    "InpMagic": "22260701", "InpSlot": "OPT",
    "InpWidthPips": "7.0", "InpAddPips": "14.0", "InpExitPips": "5.0",
    "InpMaxLayers": "8", "InpStrandedThreshPips": "14.0",
    "InpCapLegA": "NZD", "InpCapLegB": "CHF",
    "InpTelemetryInstance": "GRIND_NZDCHF_OPT",
}
NZDCHF_ALT = {
    "InpMagic": "22260702", "InpSlot": "ALT",
    "InpWidthPips": "7.0", "InpAddPips": "14.0", "InpExitPips": "7.0",
    "InpMaxLayers": "8", "InpStrandedThreshPips": "14.0",
    "InpCapLegA": "NZD", "InpCapLegB": "CHF",
    "InpTelemetryInstance": "GRIND_NZDCHF_ALT",
}


def load_preset(path: Path) -> dict[str, str]:
    out: dict[str, str] = {}
    for line in path.read_text(encoding="ascii").splitlines():
        line = line.strip()
        if not line or "=" not in line:
            continue
        key, _, value = line.partition("=")
        out[key.strip()] = value.strip()
    return out


def all_presets() -> dict[str, dict[str, str]]:
    return {p.name: load_preset(p) for p in sorted(PRESET_DIR.glob("*.set"))}


class TestPresetConventions(unittest.TestCase):
    """P-series: invariants that must hold for EVERY preset in the directory."""

    def setUp(self):
        self.presets = all_presets()
        self.assertTrue(self.presets, "no presets found")

    def test_p1_add_is_twice_width(self):
        for name, p in self.presets.items():
            with self.subTest(preset=name):
                self.assertAlmostEqual(
                    float(p["InpAddPips"]),
                    ADD_WIDTH_MULTIPLE * float(p["InpWidthPips"]), places=6)

    def test_p2_stranded_is_twice_width(self):
        for name, p in self.presets.items():
            with self.subTest(preset=name):
                self.assertAlmostEqual(
                    float(p["InpStrandedThreshPips"]),
                    ADD_WIDTH_MULTIPLE * float(p["InpWidthPips"]), places=6)

    def test_p3_deadband_is_four(self):
        for name, p in self.presets.items():
            with self.subTest(preset=name):
                self.assertAlmostEqual(float(p["InpDeadbandPips"]), EXPECTED_DEADBAND, places=6)

    def test_p4_magic_suffix_matches_slot(self):
        for name, p in self.presets.items():
            with self.subTest(preset=name):
                suffix = p["InpMagic"][-1]
                self.assertEqual(suffix, "1" if p["InpSlot"] == "OPT" else "2")

    def test_p5_telemetry_instance_matches_filename(self):
        for name, p in self.presets.items():
            with self.subTest(preset=name):
                stem = name[: -len(".set")]
                self.assertEqual(p["InpTelemetryInstance"], "GRIND_" + stem.upper())

    def test_p6_cap_thresholds_are_zero(self):
        for name, p in self.presets.items():
            with self.subTest(preset=name):
                self.assertEqual(float(p["InpCapLegAThresh"]), 0.0)
                self.assertEqual(float(p["InpCapLegBThresh"]), 0.0)

    def test_p7_telemetry_api_key_blank_public_repo(self):
        for name, p in self.presets.items():
            with self.subTest(preset=name):
                self.assertEqual(p["TelemetryAPIKey"], "")

    def test_p8_magics_are_unique(self):
        magics = [p["InpMagic"] for p in self.presets.values()]
        self.assertEqual(len(magics), len(set(magics)))


class TestNzdchfPilotPresets(unittest.TestCase):
    """N-series: the NZDCHF pilot pair, geometry locked at width 7 / add 14."""

    def test_n1_both_preset_files_exist(self):
        self.assertTrue((PRESET_DIR / "nzdchf_opt.set").is_file())
        self.assertTrue((PRESET_DIR / "nzdchf_alt.set").is_file())

    def test_n2_opt_arm_fields_exact(self):
        p = load_preset(PRESET_DIR / "nzdchf_opt.set")
        for key, expected in NZDCHF_OPT.items():
            with self.subTest(field=key):
                self.assertEqual(p[key], expected)

    def test_n3_alt_arm_fields_exact(self):
        p = load_preset(PRESET_DIR / "nzdchf_alt.set")
        for key, expected in NZDCHF_ALT.items():
            with self.subTest(field=key):
                self.assertEqual(p[key], expected)

    def test_n4_arms_differ_only_in_exit_and_identity(self):
        opt = load_preset(PRESET_DIR / "nzdchf_opt.set")
        alt = load_preset(PRESET_DIR / "nzdchf_alt.set")
        identity = {"InpMagic", "InpSlot", "InpExitPips",
                    "InpTelemetryInstance", "InpConfigWarning"}
        for key in set(opt) | set(alt):
            if key in identity:
                continue
            with self.subTest(field=key):
                self.assertEqual(opt[key], alt[key])

    def test_n5_exit_arms_are_measured_grid_cells(self):
        opt = load_preset(PRESET_DIR / "nzdchf_opt.set")
        alt = load_preset(PRESET_DIR / "nzdchf_alt.set")
        measured = {2.0, 5.0, 7.0}
        self.assertIn(float(opt["InpExitPips"]), measured)
        self.assertIn(float(alt["InpExitPips"]), measured)
        self.assertGreater(float(alt["InpExitPips"]), float(opt["InpExitPips"]))


if __name__ == "__main__":
    unittest.main(verbosity=2)
