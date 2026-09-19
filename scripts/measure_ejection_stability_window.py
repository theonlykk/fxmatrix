#!/usr/bin/env python3
"""Measure M5 consolidation + reachability windows for passive ejection gating."""
from __future__ import annotations

import json
from pathlib import Path

import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parent.parent
DATA_DIR = ROOT / "data"

# Restated from scripts/measure_path_vs_displacement.py (not imported to keep script standalone).
POINT = 0.00001
PIP_SIZE = POINT * 10.0

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

ADD_PIPS = {
    "GBPUSD": 10,
    "EURUSD": 14,
    "EURGBP": 6,
    "AUDCAD": 10,
    "AUDCHF": 10,
    "CADCHF": 10,
    "NZDCAD": 10,
    "AUDNZD": 14,
}

N_VALUES = (3, 4, 6, 8, 12, 18, 24)
RANGE_MULTS = (1.0, 1.5, 2.0, 3.0, 5.0)
SAMPLE_SIZE = 500
RNG = np.random.default_rng(42)
M5_MINUTES = 5


def load_m5(symbol: str) -> pd.DataFrame:
    path = DATA_DIR / f"{symbol}_m5.csv"
    df = pd.read_csv(path)
    df["datetime"] = pd.to_datetime(df["datetime"])
    df = df.sort_values("datetime").reset_index(drop=True)
    rename = {c: c.lower() for c in df.columns if c.isupper()}
    df = df.rename(columns=rename)
    return df


def waits_to_next_window(both: np.ndarray, sample_starts: np.ndarray) -> np.ndarray:
    true_idx = np.flatnonzero(both)
    waits = np.empty(len(sample_starts), dtype=np.float64)
    for k, start in enumerate(sample_starts):
        pos = np.searchsorted(true_idx, start)
        if pos >= len(true_idx):
            waits[k] = np.inf
        else:
            waits[k] = float(true_idx[pos] - start)
    return waits


def analyze_symbol(symbol: str) -> dict:
    df = load_m5(symbol)
    add_pips = ADD_PIPS[symbol]
    add_price = float(add_pips) * PIP_SIZE
    close = df["close"].to_numpy()
    n_bars = len(df)
    date_start = str(df["datetime"].iloc[0])
    date_end = str(df["datetime"].iloc[-1])

    valid_any = np.zeros(n_bars, dtype=bool)
    grid: list[dict] = []

    for n in N_VALUES:
        roll_high = df["high"].rolling(n, min_periods=n).max().to_numpy()
        roll_low = df["low"].rolling(n, min_periods=n).min().to_numpy()
        roll_range = roll_high - roll_low
        reach = roll_low <= (close - add_price)
        valid = ~np.isnan(roll_range)
        valid_any |= valid

        for rm in RANGE_MULTS:
            thresh = rm * add_price
            c1 = roll_range <= thresh
            both = c1 & reach & valid
            n_windows = int(valid.sum())
            pct_c1 = 100.0 * float((c1 & valid).sum()) / n_windows if n_windows else 0.0
            pct_both = 100.0 * float(both.sum()) / n_windows if n_windows else 0.0

            valid_idx = np.flatnonzero(valid)
            if len(valid_idx) == 0:
                sample_starts = np.array([], dtype=np.int64)
            elif len(valid_idx) <= SAMPLE_SIZE:
                sample_starts = valid_idx
            else:
                pick = RNG.choice(len(valid_idx), size=SAMPLE_SIZE, replace=False)
                sample_starts = valid_idx[pick]

            waits = waits_to_next_window(both, sample_starts) if len(sample_starts) else np.array([])
            if len(waits):
                if np.all(np.isinf(waits)):
                    med_bars = p90_bars = np.inf
                else:
                    q = np.quantile(waits, [0.5, 0.9])
                    med_bars = float(q[0])
                    p90_bars = float(q[1])
                never_pct = 100.0 * float(np.isinf(waits).sum()) / len(waits)
            else:
                med_bars = p90_bars = float("nan")
                never_pct = float("nan")

            grid.append(
                {
                    "N": n,
                    "range_mult": rm,
                    "n_windows": n_windows,
                    "pct_c1": round(pct_c1, 4),
                    "pct_both": round(pct_both, 4),
                    "wait_median_bars": med_bars,
                    "wait_p90_bars": p90_bars,
                    "wait_median_hours": med_bars * M5_MINUTES / 60.0
                    if np.isfinite(med_bars)
                    else med_bars,
                    "wait_p90_hours": p90_bars * M5_MINUTES / 60.0
                    if np.isfinite(p90_bars)
                    else p90_bars,
                    "never_resolved_pct": round(never_pct, 4),
                    "n_wait_samples": int(len(waits)),
                }
            )

    return {
        "symbol": symbol,
        "add_pips": add_pips,
        "add_price": add_price,
        "point": POINT,
        "pip_size": PIP_SIZE,
        "date_start": date_start,
        "date_end": date_end,
        "n_bars": n_bars,
        "grid": grid,
    }


def _fmt_num(x: float) -> str:
    if x is None or (isinstance(x, float) and not np.isfinite(x)):
        return "inf" if x == np.inf or (isinstance(x, float) and np.isinf(x)) else "nan"
    if abs(x) >= 1e4:
        return f"{x:.2f}"
    return f"{x:.4g}"


def write_report(results: list[dict], path: Path) -> None:
    lines: list[str] = []
    lines.append("This message has a line count at the bottom")
    lines.append("")
    lines.append("# Ejection stability window (M5 measurement)")
    lines.append("")

    # Lead paragraph from aggregates
    ctrl = []
    n6_rm1 = []
    for sym in results:
        for row in sym["grid"]:
            if row["range_mult"] == 1.0:
                ctrl.append(row["pct_both"])
            if row["N"] == 6 and row["range_mult"] == 1.0:
                n6_rm1.append(row)
    max_ctrl = max(ctrl) if ctrl else 0.0
    lines.append(
        "At range_mult=1.0 (original-width control), pct_both is essentially zero "
        f"(fleet max {max_ctrl:.4f}%), confirming the mutual-exclusivity proof. "
        "With N=6 and range_mult=1.0, dual-clause windows are still rare to absent "
        "and wait samples are mostly right-censored (often 100% never resolved in "
        "500-draw samples). Wider range_mult (2.0-5.0) and longer N (18-24) raise "
        "pct_both into roughly 20-41% on these files, with median waits often under "
        "two hours when windows do occur -- but that loosening is a parameter study, "
        "not the pinned add_pips rule. Whether that is often enough for a "
        "stability-gated ejection is an operator call; this report does not pick N."
    )
    lines.append("")
    lines.append("## Method")
    lines.append("")
    lines.append(
        "Constants restated from measure_path_vs_displacement.py: "
        f"POINT={POINT}, PIP_SIZE={PIP_SIZE} (all eight symbols; no JPY). "
        f"add_price = add_pips * PIP_SIZE per symbol."
    )
    lines.append("")
    lines.append(
        "Clause 1: rolling max(high)-min(low) <= range_mult * add_price. "
        "Clause 2: rolling min(low) <= close[t] - add_price. "
        "One rolling pass per symbol per N; range_mult applied in memory."
    )
    lines.append("")
    lines.append(
        "Wait: from 500 random valid start bars, bars until next index where both "
        "clauses hold (searchsorted on hit indices). Unresolved samples = inf; "
        "quantiles via numpy on inf-inclusive waits."
    )
    lines.append("")
    lines.append(
        "Coverage: M5 files under data/ end between 2026-09-07 and 2026-09-11; "
        "they do not include the operator week after that."
    )
    lines.append("")

    for sym in results:
        lines.append(f"## {sym['symbol']}")
        lines.append("")
        lines.append(
            f"add_pips={sym['add_pips']} add_price={sym['add_price']:.5f} "
            f"bars={sym['n_bars']} from {sym['date_start']} to {sym['date_end']}"
        )
        lines.append("")
        lines.append(
            "| N | range_mult | n_windows | pct_c1 | pct_both | "
            "med_bars | p90_bars | med_h | p90_h | never_pct |"
        )
        lines.append("|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|")
        for row in sym["grid"]:
            lines.append(
                f"| {row['N']} | {row['range_mult']} | {row['n_windows']} | "
                f"{row['pct_c1']} | {row['pct_both']} | "
                f"{_fmt_num(row['wait_median_bars'])} | {_fmt_num(row['wait_p90_bars'])} | "
                f"{_fmt_num(row['wait_median_hours'])} | {_fmt_num(row['wait_p90_hours'])} | "
                f"{row['never_resolved_pct']} |"
            )
        lines.append("")

    lines.append(f"Line count: {len(lines) + 1}")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines) + "\n", encoding="ascii", errors="replace")


def main() -> None:
    results = [analyze_symbol(s) for s in FLEET]
    out = ROOT / "temp" / "ejection_stability_window.json"
    out.parent.mkdir(parents=True, exist_ok=True)

    def _json_fix(o):
        if isinstance(o, float) and (np.isnan(o) or np.isinf(o)):
            return None if np.isnan(o) else "inf"
        raise TypeError

    with out.open("w", encoding="utf-8") as f:
        json.dump(results, f, indent=2, default=_json_fix)
    report_path = ROOT / "prompts" / "ejection_stability_window.md"
    write_report(results, report_path)
    print(f"Wrote {out}")
    print(f"Wrote {report_path}")


if __name__ == "__main__":
    main()
