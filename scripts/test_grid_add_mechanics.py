#!/usr/bin/env python3
"""Unit tests for fxgrind-parity add mechanics in grid_sim_v7 (T20–T26)."""
from __future__ import annotations

import importlib.util
import unittest
from pathlib import Path

import numpy as np
import pandas as pd

SCRIPT_DIR = Path(__file__).resolve().parent
ROOT = SCRIPT_DIR.parent

spec7 = importlib.util.spec_from_file_location(
    "simv7", SCRIPT_DIR / "grid_sim_v7_real_signal.py"
)
simv7 = importlib.util.module_from_spec(spec7)
spec7.loader.exec_module(simv7)

spec_sweep = importlib.util.spec_from_file_location(
    "run_width_exit_sweep", SCRIPT_DIR / "run_width_exit_sweep.py"
)
sweep = importlib.util.module_from_spec(spec_sweep)
spec_sweep.loader.exec_module(sweep)


class TestGridAddMechanics(unittest.TestCase):
    def test_t20_long_add_below_previous_entry(self):
        """T20: LONG width 5 -> add 10 pips below previous entry."""
        entry = 1.25000
        layers = [simv7.Layer(entry_price=entry, direction=1, exit_target_raw=entry + 0.0003)]
        add_pips = simv7.add_pips_from_width(5.0)
        target = simv7.compute_add_target(layers, add_pips, "GBPUSD")
        self.assertAlmostEqual(add_pips, 10.0, places=6)
        self.assertAlmostEqual(target, 1.24900, places=6)

    def test_t21_short_add_above_previous_entry(self):
        """T21: SHORT width 5 -> add 10 pips above previous entry."""
        entry = 1.25000
        layers = [simv7.Layer(entry_price=entry, direction=-1, exit_target_raw=entry - 0.0003)]
        add_pips = simv7.add_pips_from_width(5.0)
        target = simv7.compute_add_target(layers, add_pips, "GBPUSD")
        self.assertAlmostEqual(target, 1.25100, places=6)

    def test_t22_spacing_identical_at_all_depths(self):
        """T22: spacing constant at depth 1, 4, and 11 — no widening."""
        width = 7.0
        expected_pips = simv7.add_pips_from_width(width)
        for depth in (1, 4, 11):
            layers = [
                simv7.Layer(entry_price=1.25000 - i * 0.0001, direction=1, exit_target_raw=0.0)
                for i in range(depth)
            ]
            pips = simv7.add_pips_from_width(width)
            self.assertAlmostEqual(pips, expected_pips, places=9)
            self.assertAlmostEqual(pips, 14.0, places=6)

    def test_t23_anchor_is_entry_not_exit(self):
        """T23: add uses entry price even when last exit price differs."""
        entry = 1.25000
        exit_target = 1.25030  # exit above entry for long
        layers = [
            simv7.Layer(entry_price=entry, direction=1, exit_target_raw=exit_target)
        ]
        add_pips = simv7.add_pips_from_width(5.0)
        from_entry = simv7.compute_add_target(layers, add_pips, "GBPUSD")
        wrong_anchor = exit_target - simv7.pips_to_price(add_pips, "GBPUSD")
        self.assertAlmostEqual(from_entry, 1.24900, places=6)
        self.assertNotAlmostEqual(from_entry, wrong_anchor, places=6)

    def test_t24_eurgbp_width_2_5_spacing_5(self):
        """T24: EURGBP width 2.5 -> add spacing 5.0 pips."""
        self.assertAlmostEqual(simv7.add_pips_from_width(2.5), 5.0, places=6)

    def test_t25_l0_root_anchor_first_add(self):
        """T25: one layer (L0 fill) -> first add is add_pips from L0 entry."""
        l0_entry = 1.24000
        layers = [simv7.Layer(entry_price=l0_entry, direction=1, exit_target_raw=l0_entry + 0.0003)]
        self.assertEqual(len(layers), 1)
        add_pips = simv7.add_pips_from_width(9.0)
        target = simv7.compute_add_target(layers, add_pips, "GBPUSD")
        self.assertAlmostEqual(target, 1.23820, places=6)

    def test_t26_sweep_worker_call_integrity(self):
        """T26: _worker_cell path returns without TypeError (no dead kwargs)."""
        closes = np.linspace(1.25, 1.26, 80)
        times = pd.date_range("2026-01-01", periods=80, freq="5min").values
        payload = {
            "root": str(ROOT),
            "symbol": "GBPUSD",
            "pair_spread": 0.18,
            "width": 9.0,
            "exit_pips": 3.0,
            "bias_mode": int(simv7.BiasMode.BOTH),
            "closes": closes.tolist(),
            "times": times.tolist(),
            "window_hours": 1.0,
            "gbpusd_closes": None,
            "window": "q1_2024_chop",
            "regime": "ranging",
            "cell_key": "q1_2024_chop|GBPUSD|9|3",
            "n_seeds": 1,
            "substeps": 20,
        }
        cell = sweep._worker_cell(payload)
        self.assertEqual(cell["width"], 9.0)
        self.assertIn("mean_pnl", cell)


if __name__ == "__main__":
    unittest.main()
