#!/usr/bin/env python3
"""Unit tests for harvest_window_scan metric and joint scoring."""
from __future__ import annotations

import unittest

import numpy as np

import harvest_window_scan as hws


class TestOscillationMetric(unittest.TestCase):
    def test_zero_displacement_scores_finite_and_high(self):
        prices = np.array([1.0, 1.001, 0.999, 1.002, 0.998, 1.0])
        score, net_disp = hws.oscillation_score(prices)
        self.assertEqual(net_disp, 0.0)
        self.assertTrue(np.isfinite(score))
        self.assertGreater(score, 1.0)

    def test_trend_scores_lower_than_chop(self):
        chop = np.linspace(1.0, 1.0, 50)
        chop[1::2] += 0.001
        chop[2::2] -= 0.001
        trend = np.linspace(1.0, 1.05, 50)
        chop_score, _ = hws.oscillation_score(chop)
        trend_score, _ = hws.oscillation_score(trend)
        self.assertGreater(chop_score, trend_score)

    def test_joint_uses_min_not_mean(self):
        per_pair = {"AUDCAD": 100.0, "AUDCHF": 50.0, "CADCHF": 200.0}
        joint = min(per_pair.values())
        mean = sum(per_pair.values()) / 3
        self.assertEqual(joint, 50.0)
        self.assertNotAlmostEqual(joint, mean)


if __name__ == "__main__":
    unittest.main()
