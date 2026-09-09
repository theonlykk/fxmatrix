#!/usr/bin/env python3
"""Tests for generalised conversion-series alignment (C1-C7)."""
from __future__ import annotations

import re
import tempfile
import unittest
from pathlib import Path

import numpy as np
import pandas as pd

import sim_costs


def _legacy_eurgbp_align(eurgbp_times, gbp_df: pd.DataFrame) -> np.ndarray:
    """Pre-change alignment logic for EURGBP parity gate."""
    eur_t = pd.to_datetime(pd.Series(eurgbp_times))
    aligned = gbp_df.set_index("datetime")["CLOSE"].reindex(eur_t.values, method="ffill")
    if aligned.isna().any():
        aligned = aligned.bfill()
    return aligned.to_numpy(dtype=float)


def _write_csv(path: Path, rows: list[dict]) -> None:
    df = pd.DataFrame(rows)
    df.to_csv(path, index=False)


class TestConversionAlign(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)

    def tearDown(self) -> None:
        self.tmp.cleanup()

    def test_c1_eurgbp_alignment_byte_identical(self):
        """C1: EURGBP alignment matches pre-change result."""
        times = pd.date_range("2020-01-01 09:00", periods=20, freq="5min")
        eurgbp_rows = [
            {
                "datetime": t.strftime("%Y-%m-%d %H:%M:%S"),
                "OPEN": 0.85,
                "HIGH": 0.851,
                "LOW": 0.849,
                "CLOSE": 0.850,
                "SPREAD": 10,
            }
            for t in times
        ]
        gbp_times = list(times[[i for i in range(20) if i % 3 != 2]])
        gbp_rows = [
            {
                "datetime": t.strftime("%Y-%m-%d %H:%M:%S"),
                "OPEN": 1.30,
                "HIGH": 1.301,
                "LOW": 1.299,
                "CLOSE": 1.30 + i * 0.0001,
                "SPREAD": 8,
            }
            for i, t in enumerate(gbp_times)
        ]
        _write_csv(self.root / "EURGBP_testwin.csv", eurgbp_rows)
        gbp_df = pd.DataFrame(gbp_rows)
        gbp_df["datetime"] = pd.to_datetime(gbp_df["datetime"])
        _write_csv(self.root / "GBPUSD_testwin.csv", gbp_rows)

        legacy = _legacy_eurgbp_align(times, gbp_df)
        wrapper = sim_costs.load_aligned_gbpusd_closes(times, self.root, "testwin")
        general = sim_costs.load_aligned_conversion_closes(
            times, "EURGBP", self.root, "testwin"
        )
        np.testing.assert_allclose(legacy, wrapper, rtol=0, atol=1e-9)
        np.testing.assert_array_equal(wrapper, general)

    def test_c2_audchf_aligned_to_own_timestamps(self):
        """C2: AUDCHF gets USDCHF aligned to AUDCHF timestamps."""
        aud_t = pd.date_range("2020-01-01 09:00", periods=10, freq="5min")
        # USDCHF ticks on a sparser subset -- gaps require forward-fill on join
        chf_t = aud_t[[0, 1, 2, 5, 6, 9]]
        aud_rows = [
            {
                "datetime": t.strftime("%Y-%m-%d %H:%M:%S"),
                "OPEN": 0.65,
                "HIGH": 0.651,
                "LOW": 0.649,
                "CLOSE": 0.650,
                "SPREAD": 10,
            }
            for t in aud_t
        ]
        usd_rows = [
            {
                "datetime": t.strftime("%Y-%m-%d %H:%M:%S"),
                "OPEN": 0.90,
                "HIGH": 0.901,
                "LOW": 0.899,
                "CLOSE": 0.90 + i * 0.001,
                "SPREAD": 8,
            }
            for i, t in enumerate(chf_t)
        ]
        _write_csv(self.root / "AUDCHF_testwin.csv", aud_rows)
        _write_csv(self.root / "USDCHF_testwin.csv", usd_rows)

        aligned, stats = sim_costs.load_aligned_conversion_closes(
            aud_t, "AUDCHF", self.root, "testwin", return_stats=True
        )
        self.assertIsNotNone(aligned)
        self.assertEqual(len(aligned), len(aud_t))
        self.assertGreater(stats["forward_filled"], 0)

    def test_c3_usd_quoted_returns_none(self):
        """C3: EURUSD returns None without error."""
        times = pd.date_range("2020-01-01", periods=5, freq="h")
        result = sim_costs.load_aligned_conversion_closes(
            times, "EURUSD", self.root, "missing"
        )
        self.assertIsNone(result)

    def test_c4_missing_conversion_file_raises(self):
        """C4: missing conversion file raises with symbol and path."""
        times = pd.date_range("2020-01-01", periods=5, freq="h")
        _write_csv(
            self.root / "AUDCAD_testwin.csv",
            [
                {
                    "datetime": times[0].strftime("%Y-%m-%d %H:%M:%S"),
                    "OPEN": 0.9,
                    "HIGH": 0.901,
                    "LOW": 0.899,
                    "CLOSE": 0.9,
                    "SPREAD": 10,
                }
            ],
        )
        with self.assertRaises(FileNotFoundError) as ctx:
            sim_costs.load_aligned_conversion_closes(
                times, "AUDCAD", self.root, "testwin"
            )
        msg = str(ctx.exception)
        self.assertIn("AUDCAD", msg)
        self.assertIn("USDCAD", msg)
        self.assertIn("USDCAD_testwin.csv", msg)

    def test_c5_unknown_spread_raises(self):
        """C5: unknown pair spread lookup raises rather than defaulting 0.5."""
        with self.assertRaises(KeyError):
            sim_costs.get_pair_spread_pips("NOTAPAIR")

    def test_c6_leading_gaps_backfilled(self):
        """C6: leading gaps in conversion series are back-filled, not NaN."""
        times = pd.date_range("2020-01-01 09:00", periods=5, freq="5min")
        eurgbp_rows = [
            {
                "datetime": t.strftime("%Y-%m-%d %H:%M:%S"),
                "OPEN": 0.85,
                "HIGH": 0.851,
                "LOW": 0.849,
                "CLOSE": 0.850,
                "SPREAD": 10,
            }
            for t in times
        ]
        # GBPUSD starts two bars later
        gbp_rows = [
            {
                "datetime": times[i].strftime("%Y-%m-%d %H:%M:%S"),
                "OPEN": 1.30,
                "HIGH": 1.301,
                "LOW": 1.299,
                "CLOSE": 1.30,
                "SPREAD": 8,
            }
            for i in (2, 3, 4)
        ]
        _write_csv(self.root / "EURGBP_testwin.csv", eurgbp_rows)
        _write_csv(self.root / "GBPUSD_testwin.csv", gbp_rows)

        aligned, stats = sim_costs.load_aligned_conversion_closes(
            times, "EURGBP", self.root, "testwin", return_stats=True
        )
        self.assertFalse(np.any(np.isnan(aligned)))
        self.assertGreater(stats["back_filled_leading"], 0)

    def test_c7_no_gbpusd_closes_in_scripts(self):
        """C7: no occurrence of gbpusd_closes remains in scripts/."""
        scripts_dir = Path(__file__).resolve().parent
        pattern = re.compile(r"(?<!load_aligned_)gbpusd_closes")
        hits = []
        for path in scripts_dir.rglob("*.py"):
            if path.name == "test_conversion_align.py":
                continue
            text = path.read_text(encoding="utf-8")
            if pattern.search(text):
                hits.append(str(path.relative_to(scripts_dir)))
        self.assertEqual(hits, [], f"gbpusd_closes found in: {hits}")


class TestRingWindowAlignment(unittest.TestCase):
    """Verify alignment on sliced ring windows when data present."""

    DATA = Path(__file__).resolve().parent.parent / "data"
    WINDOWS = (
        ("calib_chop_2020q3", "AUDCHF"),
        ("holdout_chop_2026q2", "AUDCHF"),
        ("holdout_tail_2015q1", "AUDCHF"),
    )

    @unittest.skipUnless(
        (DATA / "AUDCHF_calib_chop_2020q3.csv").is_file(),
        "sliced ring data not present",
    )
    def test_alignment_length_per_window(self):
        for window, pair in self.WINDOWS:
            path = self.DATA / f"{pair}_{window}.csv"
            if not path.is_file():
                continue
            from grid_sim_v6_dynamic_spacing import load_mt5_csv

            df = load_mt5_csv(str(path))
            aligned, stats = sim_costs.load_aligned_conversion_closes(
                df["datetime"], pair, self.DATA, window, return_stats=True
            )
            self.assertEqual(len(aligned), len(df), f"{window}/{pair}")
            if stats:
                self.assertEqual(stats["primary_bars"], len(df))


if __name__ == "__main__":
    unittest.main()
