#!/usr/bin/env python3
"""
Measure SPREAD (MT5 points) from data/*_m5.csv for simulation gating.

Read-only over CSVs. Writes data/spread_measurements.csv (untracked).
"""
from __future__ import annotations

import argparse
import importlib.util
import re
import sys
from pathlib import Path

import numpy as np
import pandas as pd

SCRIPT_DIR = Path(__file__).resolve().parent
DATA_ROOT = SCRIPT_DIR.parent / "data"
RECENT_BARS = 250_000
POINTS_TO_PIPS = 10.0

# Windows whose date ranges appear in WINDOW_META labels (run_width_exit_sweep.py).
# Keys without parseable ranges are listed in UNDATED_WINDOW_META_KEYS.
WINDOW_DATE_RANGES: dict[str, tuple[str, str]] = {
    "calib_chop_2020q3": ("2020-07-10", "2020-10-08"),
    "calib_stress_2022q1": ("2022-02-01", "2022-05-01"),
    "holdout_chop_2026q2": ("2026-04-24", "2026-07-23"),
    "holdout_stress_2020q1": ("2020-02-01", "2020-05-01"),
    "holdout_tail_2015q1": ("2015-01-02", "2015-03-01"),
}

UNDATED_WINDOW_META_KEYS = (
    "q1_2024_chop",
    "full_quarter",
    "truss_crisis",
    "vaccine_rally",
    "june_blowup",
)


def load_window_meta() -> dict[str, dict]:
    spec = importlib.util.spec_from_file_location(
        "run_width_exit_sweep", SCRIPT_DIR / "run_width_exit_sweep.py"
    )
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return dict(mod.WINDOW_META)


def verify_window_meta_labels(meta: dict[str, dict]) -> None:
    """Confirm dated windows still match label text in run_width_exit_sweep.py."""
    pattern = re.compile(r"(\d{4}-\d{2}-\d{2})\.\.(\d{4}-\d{2}-\d{2})")
    for key, (start, end) in WINDOW_DATE_RANGES.items():
        label = meta.get(key, {}).get("label", "")
        match = pattern.search(label)
        if not match:
            raise RuntimeError(f"WINDOW_META[{key!r}] label no longer contains dates: {label!r}")
        if (match.group(1), match.group(2)) != (start, end):
            raise RuntimeError(
                f"WINDOW_META[{key!r}] label dates {match.groups()} != configured {(start, end)}"
            )


def load_mt5_csv(path: Path) -> pd.DataFrame:
    spec = importlib.util.spec_from_file_location(
        "simv6", SCRIPT_DIR / "grid_sim_v6_dynamic_spacing.py"
    )
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod.load_mt5_csv(str(path))


def discover_symbols(data_root: Path, symbols: list[str] | None) -> list[str]:
    if symbols:
        return [s.upper() for s in symbols]
    found = sorted(p.stem.replace("_m5", "") for p in data_root.glob("*_m5.csv"))
    return found


def validate_spread_column(spread: pd.Series, symbol: str) -> None:
    if spread.isna().any():
        raise ValueError(f"{symbol}: SPREAD column contains NaN")
    numeric = pd.to_numeric(spread, errors="coerce")
    if numeric.isna().any():
        bad = spread[numeric.isna()].head(3).tolist()
        raise ValueError(f"{symbol}: SPREAD not numeric; examples: {bad}")
    rounded = numeric.round()
    if not np.allclose(numeric, rounded, rtol=0, atol=1e-9):
        diff = numeric - rounded
        idx = diff.abs().argmax()
        raise ValueError(
            f"{symbol}: SPREAD not integer points at index {idx}: "
            f"value={numeric.iloc[idx]!r} (implies wrong divisor)"
        )


def spread_stats_pips(points: np.ndarray) -> dict[str, float]:
    pips = points.astype(float) / POINTS_TO_PIPS
    return {
        "count": float(len(pips)),
        "median": float(np.median(pips)),
        "mean": float(np.mean(pips)),
        "p25": float(np.percentile(pips, 25)),
        "p75": float(np.percentile(pips, 75)),
        "p90": float(np.percentile(pips, 90)),
        "min": float(np.min(pips)),
        "max": float(np.max(pips)),
    }


def measure_symbol(path: Path, symbol: str) -> dict:
    df = load_mt5_csv(path)
    if "SPREAD" not in df.columns:
        raise ValueError(f"{path}: missing SPREAD column")
    validate_spread_column(df["SPREAD"], symbol)

    points = pd.to_numeric(df["SPREAD"], errors="coerce").to_numpy(dtype=float)
    times = pd.to_datetime(df["datetime"])
    full = spread_stats_pips(points)

    recent_n = min(RECENT_BARS, len(points))
    recent_pts = points[-recent_n:]
    recent = spread_stats_pips(recent_pts)

    window_medians: dict[str, float | None] = {}
    for key, (start_s, end_s) in WINDOW_DATE_RANGES.items():
        start = pd.Timestamp(start_s)
        end = pd.Timestamp(end_s)
        mask = (times >= start) & (times < end)
        if not mask.any():
            window_medians[key] = None
        else:
            window_medians[key] = float(np.median(points[mask]) / POINTS_TO_PIPS)

    return {
        "symbol": symbol,
        "bars": len(points),
        "first": str(times.iloc[0]),
        "last": str(times.iloc[-1]),
        "full": full,
        "recent": recent,
        "recent_bars": recent_n,
        "window_medians": window_medians,
    }


def build_output_row(result: dict) -> dict:
    row = {
        "symbol": result["symbol"],
        "bars": result["bars"],
        "first": result["first"],
        "last": result["last"],
        "full_median_pips": round(result["full"]["median"], 4),
        "full_mean_pips": round(result["full"]["mean"], 4),
        "full_p25_pips": round(result["full"]["p25"], 4),
        "full_p75_pips": round(result["full"]["p75"], 4),
        "full_p90_pips": round(result["full"]["p90"], 4),
        "full_min_pips": round(result["full"]["min"], 4),
        "full_max_pips": round(result["full"]["max"], 4),
        "recent_bars": result["recent_bars"],
        "recent_median_pips": round(result["recent"]["median"], 4),
        "recent_mean_pips": round(result["recent"]["mean"], 4),
        "recent_p25_pips": round(result["recent"]["p25"], 4),
        "recent_p75_pips": round(result["recent"]["p75"], 4),
        "recent_p90_pips": round(result["recent"]["p90"], 4),
        "recent_min_pips": round(result["recent"]["min"], 4),
        "recent_max_pips": round(result["recent"]["max"], 4),
    }
    for key in WINDOW_DATE_RANGES:
        val = result["window_medians"].get(key)
        row[f"window_{key}_median_pips"] = round(val, 4) if val is not None else ""
    return row


def print_summary_table(rows: list[dict]) -> None:
    print(f"{'symbol':<10} {'bars':>8} {'full_med':>10} {'recent_med':>12} {'recent_p90':>12}")
    for row in rows:
        print(
            f"{row['symbol']:<10} {row['bars']:>8} "
            f"{row['full_median_pips']:>10.2f} {row['recent_median_pips']:>12.2f} "
            f"{row['recent_p90_pips']:>12.2f}"
        )


def main() -> int:
    parser = argparse.ArgumentParser(description="Measure M5 SPREAD from data/*_m5.csv")
    parser.add_argument(
        "symbols",
        nargs="*",
        help="Symbols to measure (default: all *_m5.csv in data/)",
    )
    parser.add_argument("--data-root", type=Path, default=DATA_ROOT)
    parser.add_argument(
        "--output",
        type=Path,
        default=DATA_ROOT / "spread_measurements.csv",
        help="Write detailed CSV here (default: data/spread_measurements.csv)",
    )
    args = parser.parse_args()

    meta = load_window_meta()
    verify_window_meta_labels(meta)

    symbols = discover_symbols(args.data_root, args.symbols or None)
    if not symbols:
        print("No *_m5.csv files found.", file=sys.stderr)
        return 1

    undated = [k for k in sorted(meta.keys()) if k in UNDATED_WINDOW_META_KEYS]
    if undated:
        print(
            "NOTE: WINDOW_META keys without derivable date ranges "
            f"(full/recent only): {', '.join(undated)}",
            file=sys.stderr,
        )

    results: list[dict] = []
    for sym in symbols:
        path = args.data_root / f"{sym}_m5.csv"
        if not path.is_file():
            print(f"SKIP {sym}: missing {path}", file=sys.stderr)
            continue
        results.append(measure_symbol(path, sym))

    if not results:
        print("No symbols measured.", file=sys.stderr)
        return 1

    rows = [build_output_row(r) for r in results]
    out_df = pd.DataFrame(rows)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    out_df.to_csv(args.output, index=False)

    print_summary_table(rows)
    print(f"\nWrote {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
