#!/usr/bin/env python3
"""
Slice the five pre-registered AUD/CAD/CHF ring windows from continuous M5 CSVs.

Produces 25 files: 5 windows x (AUDCAD, AUDCHF, CADCHF, USDCAD, USDCHF).
Ring pairs are sliced verbatim -- no forward-fill, no dropped bars.
Conversion series are left-joined onto their primary pair's timestamps and
forward-filled (back-filled at window start if needed).

Event-window date constants (reviewable; harvest dates are ratified exactly)
-----------------------------------------------------------------------------
calib_stress_2022q1  [2022-02-01, 2022-05-01)
    Commodity spike (Russia-Ukraine, energy). Feb-Apr 2022 inclusive; end
    exclusive May 1 matches harvest-window scan event exclusion.

holdout_stress_2020q1  [2020-02-01, 2020-05-01)
    COVID crash. Feb-Apr 2020 inclusive; same convention as scan.

holdout_tail_2015q1  [2015-01-02, 2015-03-01)
    SNB CHF de-peg 2015-01-15. Start 2015-01-02 = first bar in dataset
    (data begins 2015-01-02 09:00). End 2015-03-01 captures all of February
    post-de-peg; ~12 days pre-event is a known limitation.

Output format verified against grid_sim_v6_dynamic_spacing.load_mt5_csv:
    datetime,OPEN,HIGH,LOW,CLOSE,SPREAD
    datetime as YYYY-MM-DD HH:MM:SS
"""
from __future__ import annotations

import argparse
import importlib.util
import sys
from dataclasses import dataclass
from pathlib import Path

import numpy as np
import pandas as pd

SCRIPT_DIR = Path(__file__).resolve().parent
DATA_ROOT = SCRIPT_DIR.parent / "data"

RING_PAIRS = ("AUDCAD", "AUDCHF", "CADCHF")
CONVERSION_FOR_PRIMARY = {"AUDCAD": "USDCAD", "AUDCHF": "USDCHF", "CADCHF": "USDCHF"}
OUTPUT_SYMBOLS = (*RING_PAIRS, "USDCAD", "USDCHF")

# Ten-year medians from sim_costs (MT5 points / 10 = pips) for spread comparison.
TEN_YEAR_MEDIAN_PIPS = {"AUDCAD": 0.90, "AUDCHF": 0.80, "CADCHF": 1.10, "USDCAD": None, "USDCHF": None}

SNB_DEPEG = pd.Timestamp("2015-01-15 00:00:00")
GAP_THRESHOLD_DAYS = 4

MT5_COLUMNS = ("datetime", "OPEN", "HIGH", "LOW", "CLOSE", "SPREAD")


@dataclass(frozen=True)
class WindowDef:
    name: str
    role: str
    kind: str
    start: pd.Timestamp
    end: pd.Timestamp  # exclusive
    date_note: str


WINDOWS: tuple[WindowDef, ...] = (
    WindowDef(
        "calib_chop_2020q3",
        "calibration",
        "harvest",
        pd.Timestamp("2020-07-10"),
        pd.Timestamp("2020-10-08"),
        "Ratified by harvest scan (path/range + shift-stability).",
    ),
    WindowDef(
        "calib_stress_2022q1",
        "calibration",
        "stress",
        pd.Timestamp("2022-02-01"),
        pd.Timestamp("2022-05-01"),
        "Commodity spike Feb-Apr 2022; end exclusive May 1.",
    ),
    WindowDef(
        "holdout_chop_2026q2",
        "holdout",
        "harvest",
        pd.Timestamp("2026-04-24"),
        pd.Timestamp("2026-07-23"),
        "Ratified by harvest scan; forward walk vs 2020 calibration harvest.",
    ),
    WindowDef(
        "holdout_stress_2020q1",
        "holdout",
        "stress",
        pd.Timestamp("2020-02-01"),
        pd.Timestamp("2020-05-01"),
        "COVID crash Feb-Apr 2020; end exclusive May 1.",
    ),
    WindowDef(
        "holdout_tail_2015q1",
        "holdout",
        "tail",
        pd.Timestamp("2015-01-02"),
        pd.Timestamp("2015-03-01"),
        "SNB de-peg; start = dataset origin, ~12d pre-event.",
    ),
)


def load_mt5_csv(path: str | Path) -> pd.DataFrame:
    spec = importlib.util.spec_from_file_location(
        "simv6", SCRIPT_DIR / "grid_sim_v6_dynamic_spacing.py"
    )
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod.load_mt5_csv(str(path))


def load_continuous(symbol: str, data_root: Path = DATA_ROOT) -> pd.DataFrame:
    path = data_root / f"{symbol}_m5.csv"
    if not path.is_file():
        raise FileNotFoundError(path)
    df = load_mt5_csv(path)
    missing = set(MT5_COLUMNS) - set(df.columns)
    if missing:
        raise ValueError(f"{path}: missing columns {sorted(missing)}")
    return df


def slice_primary(df: pd.DataFrame, start: pd.Timestamp, end: pd.Timestamp) -> pd.DataFrame:
    """Slice ring pair by date range. No fill, no drop beyond range filter."""
    mask = (df["datetime"] >= start) & (df["datetime"] < end)
    out = df.loc[mask, list(MT5_COLUMNS)].copy()
    return out.reset_index(drop=True)


def align_conversion_to_primary(
    primary: pd.DataFrame,
    conversion: pd.DataFrame,
) -> tuple[pd.DataFrame, dict]:
    """
    Left-join conversion onto primary timestamps. Forward-fill conversion OHLC;
    back-fill start gaps. Primary rows are never dropped.
    """
    primary_n = len(primary)
    idx = primary[["datetime"]].copy()
    conv = conversion[list(MT5_COLUMNS)].copy()
    merged = idx.merge(conv, on="datetime", how="left", suffixes=("", "_dup"))
    if len(merged) != primary_n:
        raise RuntimeError(
            f"Primary bar loss during join: {primary_n} -> {len(merged)}"
        )

    price_cols = ["OPEN", "HIGH", "LOW", "CLOSE", "SPREAD"]
    missing_before = merged[price_cols].isna().any(axis=1)
    matched_exact = int((~missing_before).sum())

    after_ffill = merged[price_cols].ffill()
    leading_bfill = after_ffill.isna().any(axis=1)
    merged[price_cols] = after_ffill.bfill()

    if merged[price_cols].isna().any().any():
        raise RuntimeError("Conversion alignment left NaN after ffill/bfill")

    stats = {
        "primary_bars": primary_n,
        "matched_exact": matched_exact,
        "forward_filled": int(missing_before.sum() - leading_bfill.sum()),
        "back_filled_leading": int(leading_bfill.sum()),
    }
    return merged[list(MT5_COLUMNS)], stats


def write_mt5_csv(df: pd.DataFrame, path: Path) -> None:
    out = df.copy()
    out["datetime"] = pd.to_datetime(out["datetime"]).dt.strftime("%Y-%m-%d %H:%M:%S")
    path.parent.mkdir(parents=True, exist_ok=True)
    out.to_csv(path, index=False, columns=list(MT5_COLUMNS))


def median_spread_pips(df: pd.DataFrame) -> float:
    return float(df["SPREAD"].median()) / 10.0


def find_gaps(times: pd.Series, threshold_days: int = GAP_THRESHOLD_DAYS) -> list[tuple]:
    gaps = times.diff()
    big = gaps[gaps > pd.Timedelta(days=threshold_days)]
    result = []
    for idx in big.index:
        prev = times.iloc[idx - 1]
        curr = times.iloc[idx]
        result.append((prev, curr, curr - prev))
    return result


def process_window(
    window: WindowDef,
    frames: dict[str, pd.DataFrame],
    data_root: Path,
    write: bool,
) -> dict:
    """Slice all symbols for one window. Returns report dict."""
    report: dict = {"window": window, "symbols": {}, "alignment": {}, "gaps": {}}

    primaries = {sym: slice_primary(frames[sym], window.start, window.end) for sym in RING_PAIRS}

    for sym, pdf in primaries.items():
        report["symbols"][sym] = {
            "bars": len(pdf),
            "first": pdf["datetime"].iloc[0] if len(pdf) else None,
            "last": pdf["datetime"].iloc[-1] if len(pdf) else None,
            "median_spread_pips": median_spread_pips(pdf) if len(pdf) else None,
        }
        report["gaps"][sym] = find_gaps(pdf["datetime"]) if len(pdf) else []

    # USDCAD aligned to AUDCAD
    usdcad_aligned, usdcad_stats = align_conversion_to_primary(
        primaries["AUDCAD"], frames["USDCAD"]
    )
    report["alignment"]["USDCAD"] = {
        "indexed_to": "AUDCAD",
        **usdcad_stats,
        "timestamps_match_audcad": True,
    }

    # USDCHF aligned to CADCHF (illiquid CHF cross; primary time index)
    usdchf_cad, usdchf_cad_stats = align_conversion_to_primary(
        primaries["CADCHF"], frames["USDCHF"]
    )
    # Also report what AUDCHF join would need (same USDCHF source, different index)
    usdchf_aud, usdchf_aud_stats = align_conversion_to_primary(
        primaries["AUDCHF"], frames["USDCHF"]
    )
    aud_ts = set(primaries["AUDCHF"]["datetime"])
    cad_ts = set(primaries["CADCHF"]["datetime"])
    ts_diff = len(aud_ts.symmetric_difference(cad_ts))
    report["alignment"]["USDCHF"] = {
        "indexed_to": "CADCHF",
        "output_file_index": "CADCHF",
        **usdchf_cad_stats,
        "audchf_vs_cadchf_timestamp_diff": ts_diff,
        "audchf_ffill_if_reindexed": usdchf_aud_stats["forward_filled"],
    }

    outputs: dict[str, pd.DataFrame] = {
        "AUDCAD": primaries["AUDCAD"],
        "AUDCHF": primaries["AUDCHF"],
        "CADCHF": primaries["CADCHF"],
        "USDCAD": usdcad_aligned,
        "USDCHF": usdchf_cad,
    }

    for sym, df in outputs.items():
        if sym not in report["symbols"]:
            report["symbols"][sym] = {}
        report["symbols"][sym].update(
            {
                "bars": len(df),
                "first": df["datetime"].iloc[0] if len(df) else None,
                "last": df["datetime"].iloc[-1] if len(df) else None,
                "median_spread_pips": median_spread_pips(df) if len(df) else None,
            }
        )

    if write:
        for sym, df in outputs.items():
            path = data_root / f"{sym}_{window.name}.csv"
            write_mt5_csv(df, path)
            loaded = load_mt5_csv(path)
            if len(loaded) != len(df):
                raise RuntimeError(f"{path}: reload bar count mismatch")
            report["symbols"][sym]["path"] = str(path)

    if window.name == "holdout_tail_2015q1":
        for sym in RING_PAIRS:
            pdf = primaries[sym]
            pre = int((pdf["datetime"] < SNB_DEPEG).sum())
            post = int((pdf["datetime"] >= SNB_DEPEG).sum())
            report["symbols"][sym]["pre_depeg_bars"] = pre
            report["symbols"][sym]["post_depeg_bars"] = post

    return report


def print_report(reports: list[dict]) -> None:
    print("=" * 72)
    print("WINDOW SLICE REPORT")
    print("=" * 72)
    print(f"  Windows: {len(WINDOWS)}  Symbols: {len(OUTPUT_SYMBOLS)}  Files: {len(WINDOWS) * len(OUTPUT_SYMBOLS)}")

    print("\n--- Event window date constants ---")
    for w in WINDOWS:
        if w.kind != "harvest":
            print(f"  {w.name}: [{w.start.date()}, {w.end.date()})  -- {w.date_note}")

    for rep in reports:
        w: WindowDef = rep["window"]
        print(f"\n{'=' * 72}")
        print(f"WINDOW: {w.name}  ({w.role} / {w.kind})  [{w.start.date()}, {w.end.date()})")
        print("=" * 72)

        ring_bars = [rep["symbols"][s]["bars"] for s in RING_PAIRS]
        if max(ring_bars) - min(ring_bars) > 50:
            print(f"  NOTE: ring pair bar counts differ: {dict(zip(RING_PAIRS, ring_bars))}")

        print(f"\n  {'Symbol':<10} {'Bars':>8} {'First':<20} {'Last':<20} {'Med spread':>12}")
        for sym in OUTPUT_SYMBOLS:
            s = rep["symbols"][sym]
            med = s["median_spread_pips"]
            med_s = f"{med:.2f} pips" if med is not None else "n/a"
            ref = TEN_YEAR_MEDIAN_PIPS.get(sym)
            flag = ""
            if ref and med and med > ref * 1.5:
                flag = f"  HIGH vs 10y {ref:.2f}"
            elif ref and med and med < ref * 0.5:
                flag = f"  LOW vs 10y {ref:.2f}"
            print(
                f"  {sym:<10} {s['bars']:>8} {str(s['first']):<20} {str(s['last']):<20} "
                f"{med_s:>12}{flag}"
            )

        print("\n  Alignment:")
        for conv, info in rep["alignment"].items():
            print(
                f"    {conv}: indexed_to={info['indexed_to']}  "
                f"matched={info['matched_exact']}  ffill={info['forward_filled']}  "
                f"bfill_leading={info['back_filled_leading']}  "
                f"primary_bars={info['primary_bars']}"
            )
            if conv == "USDCHF":
                print(
                    f"      AUDCHF/CADCHF timestamp diff={info['audchf_vs_cadchf_timestamp_diff']}; "
                    f"AUDCHF-indexed ffill would be {info['audchf_ffill_if_reindexed']}"
                )
                print(
                    "      Output USDCHF matches CADCHF bars. AUDCHF sweep must left-join "
                    "USDCHF onto AUDCHF timestamps at load (same ffill policy)."
                )

        for sym in RING_PAIRS:
            gaps = rep["gaps"].get(sym, [])
            if gaps:
                print(f"\n  Gaps > {GAP_THRESHOLD_DAYS}d in {sym}: {len(gaps)}")
                for prev, curr, delta in gaps[:3]:
                    print(f"    {prev} -> {curr}  ({delta})")

        if w.name == "holdout_tail_2015q1":
            print("\n  SNB de-peg split (2015-01-15):")
            for sym in RING_PAIRS:
                s = rep["symbols"][sym]
                print(
                    f"    {sym}: pre={s.get('pre_depeg_bars', 0)} bars  "
                    f"post={s.get('post_depeg_bars', 0)} bars"
                )


def main() -> None:
    parser = argparse.ArgumentParser(description="Slice pre-registered ring windows")
    parser.add_argument("--data-root", type=Path, default=DATA_ROOT)
    parser.add_argument("--dry-run", action="store_true", help="Report only, do not write CSVs")
    args = parser.parse_args()

    frames = {sym: load_continuous(sym, args.data_root) for sym in OUTPUT_SYMBOLS}
    reports = [
        process_window(w, frames, args.data_root, write=not args.dry_run)
        for w in WINDOWS
    ]
    print_report(reports)

    if not args.dry_run:
        n_files = len(WINDOWS) * len(OUTPUT_SYMBOLS)
        print(f"\n  Wrote {n_files} files to {args.data_root}/")
        print("  Format verified via load_mt5_csv reload check per file.")


if __name__ == "__main__":
    main()
