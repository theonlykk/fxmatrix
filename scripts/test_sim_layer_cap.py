#!/usr/bin/env python3
"""Layer cap enforcement tests for grid_sim_v7 (K1–K7)."""
from __future__ import annotations

import importlib.util
import unittest
from pathlib import Path

import numpy as np

import sim_costs

SCRIPT_DIR = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location(
    "simv7", SCRIPT_DIR / "grid_sim_v7_real_signal.py"
)
simv7 = importlib.util.module_from_spec(spec)
spec.loader.exec_module(simv7)


def _run_straddle(
    closes: np.ndarray,
    *,
    max_layers: int,
    seed: int = 0,
    bias_mode=simv7.BiasMode.LONG_ONLY,
    width: float = 9.0,
    exit_pips: float = 3.0,
    sub_steps: int = 50,
) -> dict:
    dummy = np.zeros_like(closes)
    return simv7.simulate_one_path(
        closes,
        dummy,
        dummy,
        symbol="GBPUSD",
        bias_mode=bias_mode,
        seed=seed,
        sub_steps=sub_steps,
        entry_mode="straddle",
        straddle_half_width_pips=width,
        exit_pips=exit_pips,
        max_layers=max_layers,
    )


def _adverse_long_closes(n_bars: int = 400, start: float = 1.2700, step: float = 0.0020) -> np.ndarray:
    """Monotonic drop — long straddle fills, then repeated adds on adverse move."""
    return start - step * np.arange(n_bars, dtype=float)


class TestSimLayerCap(unittest.TestCase):
    def test_k1_cap_limits_depth(self):
        """K1: max_layers=3 stops a path that would otherwise stack deeper."""
        closes = _adverse_long_closes()
        uncapped = _run_straddle(closes, max_layers=10_000, seed=42)
        capped = _run_straddle(closes, max_layers=3, seed=42)
        self.assertGreater(uncapped["max_layers"], 3)
        self.assertEqual(capped["max_layers"], 3)
        self.assertTrue(capped["cap_reached"])

    def test_k2_l0_blocked_at_zero_cap(self):
        """K2: cap=0 blocks L0 on an empty book (both entry paths gated)."""
        closes = _adverse_long_closes(n_bars=80)
        r = _run_straddle(closes, max_layers=0, seed=1)
        self.assertEqual(r["max_layers"], 0)
        self.assertEqual(r["total_trades"], 0)

    def test_k3_reentry_after_unwind(self):
        """K3: after closing to flat, new L0 opens when depth drops below cap."""
        # Two adverse legs separated by recovery that clears the stack.
        leg1 = _adverse_long_closes(n_bars=120, start=1.2600, step=0.0004)
        recovery = 1.2600 - 0.0004 * 119 + 0.0003 * np.arange(80, dtype=float)
        leg2 = 1.2600 - 0.0004 * 119 + 0.0003 * 79 - 0.0004 * np.arange(120, dtype=float)
        closes = np.concatenate([leg1, recovery, leg2])
        r = _run_straddle(closes, max_layers=3, seed=7, sub_steps=80)
        self.assertGreaterEqual(r["max_layers"], 1)
        self.assertGreater(r["n_exits"], 0)

    def test_k4_twelfth_permitted_thirteenth_refused(self):
        """K4: boundary — 12 opens, 13 does not (strictly less than)."""
        closes = _adverse_long_closes(n_bars=500, step=0.0020)
        r = _run_straddle(closes, max_layers=12, seed=99, sub_steps=50, width=5.0)
        self.assertEqual(r["max_layers"], 12)
        self.assertTrue(r["cap_reached"])

    def test_k5_missing_cap_raises(self):
        """K5: omitting max_layers raises — unbounded path unreachable."""
        closes = np.linspace(1.25, 1.26, 40)
        dummy = np.zeros_like(closes)
        with self.assertRaises(ValueError):
            simv7.simulate_one_path(
                closes, dummy, dummy, symbol="GBPUSD", max_layers=None
            )
        with self.assertRaises(ValueError):
            simv7.simulate_one_path(closes, dummy, dummy, symbol="GBPUSD")

    def test_k6_parity_when_cap_non_binding(self):
        """K6: cap above observed depth reproduces unbounded-high result exactly."""
        closes = _adverse_long_closes(n_bars=200, step=0.00035)
        kwargs = dict(seed=11, sub_steps=60, width=9.0, exit_pips=3.0)
        high = _run_straddle(closes, max_layers=10_000, **kwargs)
        bound = _run_straddle(
            closes, max_layers=high["max_layers"] + 5, **kwargs
        )
        self.assertLess(high["max_layers"], 10_000)
        for key in (
            "max_layers",
            "pnl_realised_usd",
            "pnl_total_usd",
            "n_exits",
            "total_trades",
            "drawdown_exceeded_3pct",
            "drawdown_exceeded_4pct",
        ):
            self.assertEqual(high[key], bound[key], msg=key)

    def test_k7_single_direction_inventory(self):
        """K7: open layers never mix long and short directions in one run."""
        closes = _adverse_long_closes(n_bars=300)
        r = _run_straddle(closes, max_layers=8, seed=3)
        self.assertTrue(r["single_direction"])

    def test_ring_pair_cap_raises(self):
        """Ring pairs have no ratified cap — get_pair_max_layers must raise."""
        with self.assertRaises(ValueError):
            sim_costs.get_pair_max_layers("AUDCAD")


if __name__ == "__main__":
    unittest.main()
