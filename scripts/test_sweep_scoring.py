#!/usr/bin/env python3
"""Unit tests for sweep scoring and pre-registered window split (T9–T13)."""
from __future__ import annotations

import math
import unittest

import run_width_exit_sweep as sweep


def _clean_cell(**overrides) -> dict:
    base = {
        "mean_realised": 10.0,
        "dd3_rate": 0.0,
        "dd4_rate": 0.0,
        "gate_a_breach_rate": 0.0,
        "gate_b_breach_rate": 0.0,
        "mean_max_daily_equity_drawdown_usd": 0.0,
        "mean_max_absolute_drawdown_usd": 0.0,
    }
    base.update(overrides)
    return base


class TestSweepScoring(unittest.TestCase):
    def test_t9_gate_a_only_disqualified(self):
        """T9: Gate A breach alone disqualifies."""
        cell = _clean_cell(gate_a_breach_rate=10.0)
        self.assertTrue(sweep.is_gate_disqualified(cell))
        self.assertEqual(sweep.risk_adjusted_score(cell), float("-inf"))
        self.assertEqual(sweep.survival_score(cell), float("-inf"))

    def test_t10_gate_b_only_disqualified(self):
        """T10: Gate B breach alone disqualifies."""
        cell = _clean_cell(gate_b_breach_rate=5.0)
        self.assertTrue(sweep.is_gate_disqualified(cell))
        self.assertEqual(sweep.risk_adjusted_score(cell), float("-inf"))
        self.assertEqual(sweep.survival_score(cell), float("-inf"))

    def test_t11_dd4_telemetry_does_not_disqualify(self):
        """T11: dd4_rate > 0 with clean gates is NOT disqualified."""
        cell = _clean_cell(dd4_rate=100.0, dd3_rate=50.0, mean_realised=20.0)
        self.assertFalse(sweep.is_gate_disqualified(cell))
        self.assertTrue(math.isfinite(sweep.risk_adjusted_score(cell)))
        self.assertTrue(math.isfinite(sweep.survival_score(cell)))

    def test_t12_ranking_uses_mean_realised_not_dd3(self):
        """T12: Higher mean_realised wins when gates are clean; dd3 ignored."""
        high_pnl = _clean_cell(mean_realised=100.0, dd3_rate=80.0)
        low_pnl = _clean_cell(mean_realised=50.0, dd3_rate=0.0)
        self.assertGreater(
            sweep.risk_adjusted_score(high_pnl),
            sweep.risk_adjusted_score(low_pnl),
        )

    def test_t13_window_roles_complete_and_exclusive(self):
        """T13: Every window has one role; none is both calibration and holdout."""
        roles = sweep.WINDOW_ROLES
        for wkey in sweep.WINDOW_META:
            self.assertIn(wkey, roles, f"{wkey} missing from WINDOW_ROLES")
        cal = set(sweep.CALIBRATION_WINDOWS)
        hold = set(sweep.HOLDOUT_WINDOWS)
        self.assertEqual(len(cal & hold), 0)
        for wkey, role in roles.items():
            self.assertIn(role, ("calibration", "holdout", "support"))

    def test_module_import_and_runtime_helpers(self):
        """Regression: module-level imports (np/pd) must not break runtime helpers."""
        est = sweep.estimate_sweep_runtime(
            n_cells=10,
            n_seeds=2,
            substeps=100,
            workers=1,
            bar_counts=[24000],
        )
        self.assertGreater(est, 0.0)


if __name__ == "__main__":
    unittest.main()
