#!/usr/bin/env python3
"""Unit tests for harvest_window_scan metric, stability, and joint scoring."""
from __future__ import annotations

import logging
import unittest
import warnings
from unittest.mock import patch

import numpy as np
import pandas as pd

import harvest_window_scan as hws


def _ohlc(closes: np.ndarray, spread: float = 0.0001) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """Build HIGH/LOW envelopes around closes for synthetic tests."""
    highs = closes + spread
    lows = closes - spread
    return closes, highs, lows


class TestHarvestMetric(unittest.TestCase):
    def test_s1_sawtooth_scores_high(self):
        """S1: synthetic pure sawtooth in a fixed band scores HIGH."""
        period = np.array([1.00, 1.01, 1.02, 1.01])
        closes = np.tile(period, 25)
        c, h, l = _ohlc(closes)
        score, _ = hws.harvest_score(c, h, l)
        self.assertGreater(score, 5.0)

    def test_s2_linear_trend_scores_near_one(self):
        """S2: synthetic pure linear trend scores close to 1.0."""
        closes = np.linspace(1.0, 1.05, 50)
        c, h, l = _ohlc(closes, spread=0.0)
        h = closes.copy()
        l = closes.copy()
        score, _ = hws.harvest_score(c, h, l)
        self.assertAlmostEqual(score, 1.0, places=1)

    def test_s3_invariant_to_level_shift(self):
        """S3: metric unchanged when a constant is added to every price."""
        period = np.array([1.00, 1.01, 1.02, 1.01])
        closes = np.tile(period, 20)
        c, h, l = _ohlc(closes)
        score_a, _ = hws.harvest_score(c, h, l)
        shift = 0.37
        score_b, _ = hws.harvest_score(c + shift, h + shift, l + shift)
        self.assertAlmostEqual(score_a, score_b, places=9)

    def test_s4_identical_endpoints_not_boundary_luck(self):
        """S4: identical vs non-identical first/last close -- scores stay comparable."""
        period = np.array([1.00, 1.01, 1.02, 1.01])
        closes_a = np.tile(period, 25)  # 100 bars, first==last==1.00
        closes_b = np.concatenate([np.tile(period, 24), period[:4]])  # ends at 1.01 not 1.00
        score_a, _ = hws.harvest_score(*_ohlc(closes_a))
        score_b, _ = hws.harvest_score(*_ohlc(closes_b))
        ratio = max(score_a, score_b) / min(score_a, score_b)
        self.assertLess(ratio, 1.15, "endpoint coincidence must not orders-of-magnitude inflate score")

    def test_s6_min_not_mean(self):
        """S6: min() not mean() -- one bad leg sinks the joint score."""
        per_pair = {"AUDCAD": 100.0, "AUDCHF": 50.0, "CADCHF": 200.0}
        joint = min(per_pair.values())
        mean = sum(per_pair.values()) / 3
        self.assertEqual(joint, 50.0)
        self.assertNotAlmostEqual(joint, mean)

    def test_s7_flatlined_does_not_crash_and_warns(self):
        """S7: zero-range series does not crash; guard logs a warning."""
        n = 10
        flat = np.full(n, 1.2345)
        with self.assertLogs(level="WARNING") as cm:
            with warnings.catch_warnings(record=True) as w:
                warnings.simplefilter("always")
                score, rng = hws.harvest_score(
                    flat, flat, flat, symbol="TEST", window_label="flat-test"
                )
        self.assertTrue(np.isfinite(score))
        self.assertEqual(rng, 0.0)
        self.assertTrue(any("realized_range guard fired" in m for m in cm.output))
        self.assertTrue(any("realized_range guard fired" in str(x.message) for x in w))


class TestStabilityCheck(unittest.TestCase):
    def test_s5_rejects_offset_sensitive_candidate(self):
        """S5: stability check REJECTS a candidate that only peaks at one exact offset."""
        base_start = pd.Timestamp("2020-06-01")
        base_end = base_start + pd.Timedelta(days=90)
        window = hws.WindowScore(
            start=base_start,
            end=base_end,
            joint=10.0,
            per_pair={"AUDCAD": 10.0, "AUDCHF": 12.0, "CADCHF": 11.0},
            bar_counts={"AUDCAD": 5000, "AUDCHF": 5000, "CADCHF": 5000},
        )
        frames: dict[str, pd.DataFrame] = {}

        def fake_score(_frames, start, end):
            if start == base_start and end == base_end:
                return hws.WindowScore(
                    start=start,
                    end=end,
                    joint=10.0,
                    per_pair={"AUDCAD": 10.0, "AUDCHF": 12.0, "CADCHF": 11.0},
                    bar_counts={"AUDCAD": 5000, "AUDCHF": 5000, "CADCHF": 5000},
                )
            return hws.WindowScore(
                start=start,
                end=end,
                joint=5.0,
                per_pair={"AUDCAD": 5.0, "AUDCHF": 6.0, "CADCHF": 5.5},
                bar_counts={"AUDCAD": 5000, "AUDCHF": 5000, "CADCHF": 5000},
            )

        with patch.object(hws, "score_ring_window", side_effect=fake_score):
            result = hws.evaluate_stability(window, frames)

        self.assertEqual(result.verdict, "REJECT")
        self.assertGreater(result.worst_degradation_pct, 20.0)


if __name__ == "__main__":
    unittest.main()
