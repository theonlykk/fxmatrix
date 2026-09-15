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

    def test_calib_tail_window_registered(self):
        self.assertIn("calib_tail_2015q1", sweep.WINDOW_META)
        self.assertEqual(sweep.WINDOW_ROLES["calib_tail_2015q1"], "calibration")
        self.assertIn("calib_tail_2015q1", sweep.CALIBRATION_WINDOWS)

    def test_calib_tail_resolves_to_existing_slice(self):
        calib_path = sweep.window_path("AUDCHF", "calib_tail_2015q1")
        holdout_path = sweep.window_path("AUDCHF", "holdout_tail_2015q1")
        self.assertEqual(calib_path, holdout_path)
        self.assertTrue(str(calib_path).endswith("AUDCHF_holdout_tail_2015q1.csv"))

    def test_holdout_tail_role_unchanged(self):
        self.assertEqual(sweep.WINDOW_ROLES["holdout_tail_2015q1"], "holdout")
        self.assertIn("holdout_tail_2015q1", sweep.HOLDOUT_WINDOWS)


def _barbell_cell(pair: str, window: str, width: float, exit_pips: float, risk_adj: float) -> dict:
    return _clean_cell(
        cell_key=f"{window}|{pair}|{int(width)}|{int(exit_pips)}",
        window=window,
        pair=pair,
        width=width,
        exit_pips=exit_pips,
        regime=sweep.WINDOW_META[window]["regime"],
        risk_adj=risk_adj,
    )


def _barbell_base_fixture() -> tuple[dict, list[str]]:
    """Two pairs, three windows, three grid cells; holdout-only (9, 5) outlier."""
    pairs = ("AAABBB", "CCCDDD")
    calib_chop = "calib_chop_2020q3"
    calib_stress = "calib_stress_2022q1"
    holdout = "holdout_chop_2026q2"
    grid = ((3.0, 5.0), (5.0, 5.0), (7.0, 5.0))
    holdout_only = (9.0, 5.0)
    scores = {
        ("AAABBB", calib_chop): {(7.0, 5.0): 100.0, (5.0, 5.0): 50.0, (3.0, 5.0): 10.0},
        ("AAABBB", calib_stress): {(3.0, 5.0): 100.0, (5.0, 5.0): 50.0, (7.0, 5.0): 10.0},
        ("CCCDDD", calib_chop): {(5.0, 5.0): 100.0, (7.0, 5.0): 50.0, (3.0, 5.0): 10.0},
        ("CCCDDD", calib_stress): {(5.0, 5.0): 100.0, (3.0, 5.0): 50.0, (7.0, 5.0): 10.0},
    }
    cells: dict = {}
    for pair in pairs:
        for window in (calib_chop, calib_stress):
            for width, exit_pips in grid:
                ra = scores[(pair, window)][(width, exit_pips)]
                c = _barbell_cell(pair, window, width, exit_pips, ra)
                cells[c["cell_key"]] = c
        c = _barbell_cell(pair, holdout, holdout_only[0], holdout_only[1], 9999.0)
        cells[c["cell_key"]] = c
    window_keys = [calib_chop, calib_stress, holdout]
    return cells, window_keys


class TestBarbellSelection(unittest.TestCase):
    def test_barbell_selects_per_pair_per_regime(self):
        cells, window_keys = _barbell_base_fixture()
        out = sweep.select_barbell_per_pair(cells, window_keys, "risk_adj")
        aa_r, _ = out["AAABBB"]["ranging"]
        aa_s, _ = out["AAABBB"]["stress"]
        cc_r, _ = out["CCCDDD"]["ranging"]
        cc_s, _ = out["CCCDDD"]["stress"]
        self.assertEqual(aa_r, (7.0, 5.0))
        self.assertEqual(aa_s, (3.0, 5.0))
        self.assertEqual(cc_r, (5.0, 5.0))
        self.assertEqual(cc_s, (5.0, 5.0))

    def test_barbell_ignores_holdout_windows(self):
        cells, window_keys = _barbell_base_fixture()
        holdout_only = (9.0, 5.0)
        out = sweep.select_barbell_per_pair(cells, window_keys, "risk_adj")
        for pair, regimes in out.items():
            for regime, (cell, _score) in regimes.items():
                with self.subTest(pair=pair, regime=regime):
                    self.assertNotEqual(cell, holdout_only)

    def test_barbell_excludes_disqualified_cells(self):
        cells, window_keys = _barbell_base_fixture()
        key = "calib_chop_2020q3|AAABBB|7|5"
        cells[key]["risk_adj"] = float("-inf")
        out = sweep.select_barbell_per_pair(cells, window_keys, "risk_adj")
        cell, _ = out["AAABBB"]["ranging"]
        self.assertEqual(cell, (5.0, 5.0))

    def test_barbell_groups_both_stress_windows(self):
        cells, window_keys = _barbell_base_fixture()
        tail = "calib_tail_2015q1"
        window_keys = window_keys + [tail]
        pair = "AAABBB"
        stress_grid = ((3.0, 5.0), (5.0, 5.0), (7.0, 5.0))
        # calib_stress: (3,5)=100; calib_tail: (5,5)=200 -> avg (5,5)=140 beats (3,5)=60.
        stress_scores = {
            "calib_stress_2022q1": {(3.0, 5.0): 100.0, (5.0, 5.0): 80.0, (7.0, 5.0): 60.0},
            tail: {(3.0, 5.0): 20.0, (5.0, 5.0): 200.0, (7.0, 5.0): 40.0},
        }
        for window, grid_scores in stress_scores.items():
            for width, exit_pips in stress_grid:
                c = _barbell_cell(pair, window, width, exit_pips, stress_scores[window][(width, exit_pips)])
                cells[c["cell_key"]] = c
        out = sweep.select_barbell_per_pair(cells, window_keys, "risk_adj")
        cell, score = out["AAABBB"]["stress"]
        self.assertEqual(cell, (5.0, 5.0))
        self.assertAlmostEqual(score, 140.0, places=9)

    def test_barbell_missing_regime_returns_none(self):
        cells, window_keys = _barbell_base_fixture()
        out = sweep.select_barbell_per_pair(cells, ["calib_chop_2020q3"], "risk_adj")
        cell, score = out["AAABBB"]["stress"]
        self.assertIsNone(cell)
        self.assertEqual(score, float("-inf"))


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
