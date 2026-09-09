#!/usr/bin/env python3
"""Tests for slice_ring_windows alignment and primary bar preservation."""
from __future__ import annotations

import unittest

import pandas as pd

import slice_ring_windows as srw


def _make_bars(symbol: str, start: str, n: int, step_min: int = 5) -> pd.DataFrame:
    times = pd.date_range(start, periods=n, freq=f"{step_min}min")
    base = 1.0 if "USD" not in symbol else 0.7
    return pd.DataFrame(
        {
            "datetime": times,
            "OPEN": base,
            "HIGH": base + 0.001,
            "LOW": base - 0.001,
            "CLOSE": base,
            "SPREAD": 10,
        }
    )


class TestSliceAlignment(unittest.TestCase):
    def test_primary_bar_count_unchanged(self):
        primary = _make_bars("AUDCAD", "2020-01-01 09:00", 100)
        # Conversion missing every 3rd bar
        conv = primary.iloc[[i for i in range(len(primary)) if i % 3 != 2]].copy()
        conv["CLOSE"] = 1.35
        out, stats = srw.align_conversion_to_primary(primary, conv)
        self.assertEqual(len(out), len(primary))
        self.assertEqual(stats["primary_bars"], 100)
        self.assertFalse(out[["OPEN", "HIGH", "LOW", "CLOSE"]].isna().any().any())

    def test_forward_fill_applied(self):
        primary = _make_bars("CADCHF", "2020-01-01", 10)
        conv = primary.iloc[[0, 1, 2, 7, 8, 9]].copy()
        _, stats = srw.align_conversion_to_primary(primary, conv)
        self.assertGreater(stats["forward_filled"], 0)

    def test_twenty_five_file_count(self):
        self.assertEqual(len(srw.WINDOWS) * len(srw.OUTPUT_SYMBOLS), 25)


if __name__ == "__main__":
    unittest.main()
