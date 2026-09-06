#!/usr/bin/env python3
"""Unit tests for sweep scoring, window split, and checkpoint provenance (T9–T19)."""
from __future__ import annotations

import math
import tempfile
import unittest
from pathlib import Path

import sim_costs
import run_width_exit_sweep as sweep


def _clean_cell(**overrides) -> dict:
    base = {field: 0.0 for field in sweep.CELL_SCHEMA_FIELDS}
    base.update(
        {
            "cell_key": "q1_2024_chop|GBPUSD|9|3",
            "window": "q1_2024_chop",
            "pair": "GBPUSD",
            "width": 9.0,
            "exit_pips": 3.0,
            "regime": "ranging",
            "mean_realised": 10.0,
            "mean_pnl": 10.0,
            "median_pnl": 10.0,
            "dd3_rate": 0.0,
            "dd4_rate": 0.0,
            "gate_a_breach_rate": 0.0,
            "gate_b_breach_rate": 0.0,
            "mean_max_daily_equity_drawdown_usd": 0.0,
            "mean_max_absolute_drawdown_usd": 0.0,
            "disqualified_dd4": False,
            "disqualified_gate_a": False,
            "disqualified_gate_b": False,
            "disqualified_gates": False,
            "max_max_layers": 1,
            "dd3_count": 0,
            "dd4_count": 0,
            "gate_a_breach_count": 0,
            "gate_b_breach_count": 0,
            "l0_unwind_n": 0,
        }
    )
    base.update(overrides)
    return base


def _valid_checkpoint(**overrides) -> dict:
    ckpt = {
        "provenance": sweep.build_provenance(),
        "cells": {"k1": _clean_cell()},
    }
    ckpt.update(overrides)
    return ckpt


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


class TestCheckpointProvenance(unittest.TestCase):
    def test_t15_matching_provenance_resumes(self):
        """T15: Matching version and complete cells pass validation."""
        sweep.validate_checkpoint_provenance(_valid_checkpoint())

    def test_t16_mismatched_cost_model_version_refused(self):
        """T16: Mismatched cost_model_version is refused."""
        ckpt = _valid_checkpoint()
        ckpt["provenance"]["cost_model_version"] = 999
        with self.assertRaises(sweep.CheckpointProvenanceError):
            sweep.validate_checkpoint_provenance(ckpt)

    def test_t17_absent_provenance_refused(self):
        """T17: Checkpoint with no provenance block is refused."""
        ckpt = _valid_checkpoint()
        del ckpt["provenance"]
        with self.assertRaises(sweep.CheckpointProvenanceError):
            sweep.validate_checkpoint_provenance(ckpt)

    def test_t18_missing_required_cell_field_refused(self):
        """T18: Version match but missing gate_a_breach_rate is refused."""
        ckpt = _valid_checkpoint()
        del ckpt["cells"]["k1"]["gate_a_breach_rate"]
        with self.assertRaises(sweep.CheckpointProvenanceError) as ctx:
            sweep.validate_checkpoint_provenance(ckpt)
        self.assertIn("gate_a_breach_rate", str(ctx.exception))

    def test_t19_git_commit_alone_does_not_block(self):
        """T19: Different git_commit with matching version resumes."""
        ckpt = _valid_checkpoint()
        ckpt["provenance"]["git_commit"] = "deadbeef"
        sweep.validate_checkpoint_provenance(ckpt)

    def test_refuse_exits_nonzero(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "stale_partial.json"
            ckpt = _valid_checkpoint()
            del ckpt["provenance"]
            path.write_text(__import__("json").dumps(ckpt), encoding="utf-8")
            with self.assertRaises(SystemExit) as ctx:
                sweep.refuse_checkpoint_provenance(path, sweep.CheckpointProvenanceError("absent"))
            self.assertEqual(ctx.exception.code, 1)


if __name__ == "__main__":
    unittest.main()
