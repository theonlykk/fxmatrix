#!/usr/bin/env python3
"""
Slice the five pre-registered AUD/CAD/CHF ring windows from continuous M5 CSVs.

Produces 5 x (N primary pairs + unique conversion pairs) files per window.
Primary pairs are sliced verbatim -- no forward-fill, no dropped bars.
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
from dataclasses import dataclass
from pathlib import Path

import numpy as np
import pandas as pd

SCRIPT_DIR = Path(__file__).resolve().parent
DATA_ROOT = SCRIPT_DIR.parent / "data"

DEFAULT_RING_PAIRS = ("AUDCAD", "AUDCHF", "CADCHF")

SNB_DEPEG = pd.Timestamp("2015-01-15 00:00:00")
GAP_THRESHOLD_DAYS = 4

MT5_COLUMNS = ("datetime", "OPEN", "HIGH", "LOW", "CLOSE", "SPREAD")


def _load_sim_costs():
    spec = importlib.util.spec_from_file_location("sim_costs", SCRIPT_DIR / "sim_costs.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


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


def resolve_ring_pairs(pairs: list[str] | None) -> tuple[str, ...]:
    if not pairs:
        return DEFAULT_RING_PAIRS
    return tuple(p.upper() for p in pairs)


def resolve_conversion_for_primary(ring_pairs: tuple[str, ...]) -> dict[str, str]:
    sim_costs = _load_sim_costs()
    out: dict[str, str] = {}
    for sym in ring_pairs:
        spec = sim_costs.get_pair_spec(sym)
        if spec.conversion_pair:
            out[sym] = spec.conversion_pair
    return out


def resolve_output_symbols(ring_pairs: tuple[str, ...]) -> tuple[str, ...]:
    sim_costs = _load_sim_costs()
    conversion_pairs: list[str] = []
    seen: set[str] = set()
    for sym in ring_pairs:
        spec = sim_costs.get_pair_spec(sym)
        conv = spec.conversion_pair
        if conv and conv not in seen:
            conversion_pairs.append(conv)
            seen.add(conv)
    return ring_pairs + tuple(conversion_pairs)


def conversion_index_primary(
    conversion_pair: str,
    ring_pairs: tuple[str, ...],
    conversion_for_primary: dict[str, str],
) -> str:
    primaries = [p for p in ring_pairs if conversion_for_primary.get(p) == conversion_pair]
    if not primaries:
        raise KeyError(f"No primary maps to conversion pair {conversion_pair!r}")
    return primaries[-1]


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
    ring_pairs: tuple[str, ...],
    conversion_for_primary: dict[str, str],
    output_symbols: tuple[str, ...],
    data_root: Path,
    write: bool,
) -> dict:
    """Slice all symbols for one window. Returns report dict."""
    report: dict = {"window": window, "symbols": {}, "alignment": {}, "gaps": {}}

    primaries = {
        sym: slice_primary(frames[sym], window.start, window.end) for sym in ring_pairs
    }

    for sym, pdf in primaries.items():
        report["symbols"][sym] = {
            "bars": len(pdf),
            "first": pdf["datetime"].iloc[0] if len(pdf) else None,
            "last": pdf["datetime"].iloc[-1] if len(pdf) else None,
            "median_spread_pips": median_spread_pips(pdf) if len(pdf) else None,
        }
        report["gaps"][sym] = find_gaps(pdf["datetime"]) if len(pdf) else []

    outputs: dict[str, pd.DataFrame] = dict(primaries)

    conversion_pairs = [s for s in output_symbols if s not in ring_pairs]
    for conv in conversion_pairs:
        index_primary = conversion_index_primary(conv, ring_pairs, conversion_for_primary)
        aligned, stats = align_conversion_to_primary(primaries[index_primary], frames[conv])
        outputs[conv] = aligned
        report["alignment"][conv] = {
            "indexed_to": index_primary,
            **stats,
        }
        if conv == "USDCHF" and "AUDCHF" in ring_pairs and "CADCHF" in ring_pairs:
            usdchf_aud, usdchf_aud_stats = align_conversion_to_primary(
                primaries["AUDCHF"], frames["USDCHF"]
            )
            aud_ts = set(primaries["AUDCHF"]["datetime"])
            cad_ts = set(primaries["CADCHF"]["datetime"])
            ts_diff = len(aud_ts.symmetric_difference(cad_ts))
            report["alignment"][conv]["audchf_vs_cadchf_timestamp_diff"] = ts_diff
            report["alignment"][conv]["audchf_ffill_if_reindexed"] = usdchf_aud_stats[
                "forward_filled"
            ]
            report["alignment"][conv]["output_file_index"] = index_primary

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
        for sym in ring_pairs:
            pdf = primaries[sym]
            pre = int((pdf["datetime"] < SNB_DEPEG).sum())
            post = int((pdf["datetime"] >= SNB_DEPEG).sum())
            report["symbols"][sym]["pre_depeg_bars"] = pre
            report["symbols"][sym]["post_depeg_bars"] = post

    return report


def print_report(
    reports: list[dict],
    ring_pairs: tuple[str, ...],
    output_symbols: tuple[str, ...],
) -> None:
    sim_costs = _load_sim_costs()
    ref_medians = {
        sym: sim_costs.PAIR_SPREAD_PIPS.get(sym) for sym in output_symbols
    }

    print("=" * 72)
    print("WINDOW SLICE REPORT")
    print("=" * 72)
    print(
        f"  Windows: {len(WINDOWS)}  Symbols: {len(output_symbols)}  "
        f"Files: {len(WINDOWS) * len(output_symbols)}"
    )

    print("\n--- Event window date constants ---")
    for w in WINDOWS:
        if w.kind != "harvest":
            print(f"  {w.name}: [{w.start.date()}, {w.end.date()})  -- {w.date_note}")

    for rep in reports:
        w: WindowDef = rep["window"]
        print(f"\n{'=' * 72}")
        print(f"WINDOW: {w.name}  ({w.role} / {w.kind})  [{w.start.date()}, {w.end.date()})")
        print("=" * 72)

        ring_bars = [rep["symbols"][s]["bars"] for s in ring_pairs]
        if max(ring_bars) - min(ring_bars) > 50:
            print(f"  NOTE: ring pair bar counts differ: {dict(zip(ring_pairs, ring_bars))}")

        print(f"\n  {'Symbol':<10} {'Bars':>8} {'First':<20} {'Last':<20} {'Med spread':>12}")
        for sym in output_symbols:
            s = rep["symbols"][sym]
            med = s["median_spread_pips"]
            med_s = f"{med:.2f} pips" if med is not None else "n/a"
            ref = ref_medians.get(sym)
            flag = ""
            if ref and med and med > ref * 1.5:
                flag = f"  HIGH vs ref {ref:.2f}"
            elif ref and med and med < ref * 0.5:
                flag = f"  LOW vs ref {ref:.2f}"
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
            if conv == "USDCHF" and "audchf_vs_cadchf_timestamp_diff" in info:
                print(
                    f"      AUDCHF/CADCHF timestamp diff={info['audchf_vs_cadchf_timestamp_diff']}; "
                    f"AUDCHF-indexed ffill would be {info['audchf_ffill_if_reindexed']}"
                )
                print(
                    "      Output USDCHF matches CADCHF bars. AUDCHF sweep must left-join "
                    "USDCHF onto AUDCHF timestamps at load (same ffill policy)."
                )

        for sym in ring_pairs:
            gaps = rep["gaps"].get(sym, [])
            if gaps:
                print(f"\n  Gaps > {GAP_THRESHOLD_DAYS}d in {sym}: {len(gaps)}")
                for prev, curr, delta in gaps[:3]:
                    print(f"    {prev} -> {curr}  ({delta})")

        if w.name == "holdout_tail_2015q1":
            print("\n  SNB de-peg split (2015-01-15):")
            for sym in ring_pairs:
                s = rep["symbols"][sym]
                print(
                    f"    {sym}: pre={s.get('pre_depeg_bars', 0)} bars  "
                    f"post={s.get('post_depeg_bars', 0)} bars"
                )


def main() -> None:
    parser = argparse.ArgumentParser(description="Slice pre-registered ring windows")
    parser.add_argument("--data-root", type=Path, default=DATA_ROOT)
    parser.add_argument("--dry-run", action="store_true", help="Report only, do not write CSVs")
    parser.add_argument(
        "pairs",
        nargs="*",
        help=f"Primary pairs to slice (default: {', '.join(DEFAULT_RING_PAIRS)})",
    )
    args = parser.parse_args()

    ring_pairs = resolve_ring_pairs(args.pairs)
    conversion_for_primary = resolve_conversion_for_primary(ring_pairs)
    output_symbols = resolve_output_symbols(ring_pairs)

    frames = {sym: load_continuous(sym, args.data_root) for sym in output_symbols}
    reports = [
        process_window(
            w,
            frames,
            ring_pairs,
            conversion_for_primary,
            output_symbols,
            args.data_root,
            write=not args.dry_run,
        )
        for w in WINDOWS
    ]
    print_report(reports, ring_pairs, output_symbols)

    if not args.dry_run:
        n_files = len(WINDOWS) * len(output_symbols)
        print(f"\n  Wrote {n_files} files to {args.data_root}/")
        print("  Format verified via load_mt5_csv reload check per file.")


if __name__ == "__main__":
    main()
