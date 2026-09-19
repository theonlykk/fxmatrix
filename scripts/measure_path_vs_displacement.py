#!/usr/bin/env python3
"""Path vs displacement from M5 bars. One pass per file; pandas/numpy only."""
from __future__ import annotations

import json
from pathlib import Path

import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parent.parent
DATA_DIR = ROOT / "data"

FLEET = (
    "GBPUSD",
    "EURUSD",
    "EURGBP",
    "AUDCAD",
    "AUDCHF",
    "CADCHF",
    "NZDCAD",
    "AUDNZD",
)

EXIT_PIPS = {
    "GBPUSD": (7, 10),
    "EURUSD": (7, 10),
    "EURGBP": (5, 8),
    "AUDCAD": (5, 10),
    "AUDCHF": (5, 10),
    "CADCHF": (5, 10),
    "NZDCAD": (5, 7),
    "AUDNZD": (5, 7),
}

POINT = 0.00001
PIP_SIZE = POINT * 10.0


def price_to_pips(diff: float | np.ndarray) -> float | np.ndarray:
    return diff / PIP_SIZE


def load_m5(symbol: str) -> pd.DataFrame:
    path = DATA_DIR / f"{symbol}_m5.csv"
    df = pd.read_csv(path)
    df["datetime"] = pd.to_datetime(df["datetime"])
    df = df.sort_values("datetime").reset_index(drop=True)
    rename = {c: c.lower() for c in df.columns if c.isupper()}
    df = df.rename(columns=rename)
    df["utc_date"] = df["datetime"].dt.date
    return df


def daily_stats(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()
    df["bar_move"] = df["close"].diff().abs()
    g = df.groupby("utc_date", sort=True)
    out = pd.DataFrame(
        {
            "path_pips": price_to_pips(g["bar_move"].sum()),
            "displacement_pips": price_to_pips(
                (g["close"].last() - g["close"].first()).abs()
            ),
            "range_pips": price_to_pips(g["high"].max() - g["low"].min()),
            "bars": g["close"].count(),
        }
    )
    out["ratio"] = out["path_pips"] / out["displacement_pips"].replace(0, np.nan)
    out["date"] = out.index.astype(str)
    return out.reset_index(drop=True)


def gbpusd_band_split(df: pd.DataFrame, day: str, lo: float, hi: float, anchor: float) -> dict:
    sub = df[df["utc_date"] == pd.Timestamp(day).date()].copy()
    if len(sub) < 2:
        return {"date": day}
    sub["bar_move"] = sub["close"].diff().abs()
    move = sub["bar_move"].iloc[1:]
    c1 = sub["close"].iloc[1:]
    in_band = (c1 >= lo) & (c1 <= hi)
    above = c1 >= anchor
    other = ~(in_band | above)
    return {
        "date": day,
        "path_total_pips": float(price_to_pips(move.sum())),
        "path_in_band_pips": float(price_to_pips(move[in_band].sum())),
        "path_above_anchor_pips": float(price_to_pips(move[above].sum())),
        "path_other_pips": float(price_to_pips(move[other].sum())),
        "bars": int(len(sub)),
    }


def summarize(series: pd.Series) -> dict:
    s = series.dropna()
    return {
        "n": int(len(s)),
        "median": float(s.median()),
        "q25": float(s.quantile(0.25)),
        "q75": float(s.quantile(0.75)),
    }


def main() -> None:
    all_daily: dict[str, pd.DataFrame] = {}
    meta = {}
    gbp_df = None
    for sym in FLEET:
        df = load_m5(sym)
        if sym == "GBPUSD":
            gbp_df = df
        meta[sym] = {
            "path": str(DATA_DIR / f"{sym}_m5.csv"),
            "rows": len(df),
            "start": str(df["datetime"].iloc[0]),
            "end": str(df["datetime"].iloc[-1]),
            "point": POINT,
            "pip_size": PIP_SIZE,
        }
        all_daily[sym] = daily_stats(df)

    pooled = pd.concat(all_daily.values(), ignore_index=True)
    week_dates = ["2026-09-14", "2026-09-15", "2026-09-16", "2026-09-17", "2026-09-18"]
    week_rows = []
    for sym in FLEET:
        d = all_daily[sym]
        for day in week_dates:
            row = d[d["date"] == day]
            if len(row):
                week_rows.append({"symbol": sym, **row.iloc[0].to_dict()})

    assert gbp_df is not None
    gbp_band = [
        gbpusd_band_split(gbp_df, day, 1.334, 1.339, 1.34301)
        for day in ("2026-09-17", "2026-09-18")
    ]

    sym_summary = {
        sym: {
            "path": summarize(all_daily[sym]["path_pips"]),
            "displacement": summarize(all_daily[sym]["displacement_pips"]),
            "ratio": summarize(all_daily[sym]["ratio"]),
            "range": summarize(all_daily[sym]["range_pips"]),
        }
        for sym in FLEET
    }
    pool_summary = {
        "path": summarize(pooled["path_pips"]),
        "displacement": summarize(pooled["displacement_pips"]),
        "ratio": summarize(pooled["ratio"]),
        "range": summarize(pooled["range_pips"]),
    }
    scalp_capacity = {}
    for sym in FLEET:
        med_path = sym_summary[sym]["path"]["median"]
        opt_e, alt_e = EXIT_PIPS[sym]
        scalp_capacity[sym] = {
            "median_path_pips": med_path,
            "opt_E": opt_e,
            "alt_E": alt_e,
            "crude_opt_round_trips": med_path / (2 * opt_e),
            "crude_alt_round_trips": med_path / (2 * alt_e),
        }

    out = {
        "meta": meta,
        "symbol_summary": sym_summary,
        "pooled_summary": pool_summary,
        "week_2026_09_14_18": week_rows,
        "gbpusd_band_split": gbp_band,
        "scalp_capacity_crude": scalp_capacity,
    }
    out_path = ROOT / "temp" / "path_vs_displacement_results.json"
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with out_path.open("w", encoding="utf-8") as fh:
        json.dump(out, fh, indent=2)
    print("Wrote", out_path)


if __name__ == "__main__":
    main()
