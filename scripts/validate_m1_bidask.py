#!/usr/bin/env python3
"""Validate M1 bid/ask CSV files from export_m1_bidask.mq5."""
from __future__ import annotations

import sys
from pathlib import Path

import pandas as pd

REQUIRED_COLS = (
    "time_broker",
    "bid_open",
    "bid_high",
    "bid_low",
    "bid_close",
    "ask_open",
    "ask_high",
    "ask_low",
    "ask_close",
    "ticks",
)


def load_bars(path: Path | str) -> pd.DataFrame:
    df = pd.read_csv(path)
    missing = [c for c in REQUIRED_COLS if c not in df.columns]
    if missing:
        raise ValueError(f"missing columns {missing} in {path}")
    return df


def check_bars(df: pd.DataFrame) -> list[str]:
    msgs: list[str] = []
    if df.empty:
        return msgs

    prev: str | None = None
    for tb in df["time_broker"].astype(str):
        if prev is not None:
            if tb <= prev:
                msgs.append(f"R1 time_broker not strictly increasing at {tb}")
                break
        prev = tb

    for tb in df["time_broker"].astype(str):
        parts = tb.strip().split(" ")
        if len(parts) != 2 or len(parts[1].split(":")) != 3:
            msgs.append(f"R2 time_broker bad format at {tb}")
            break
        sec = int(parts[1].split(":")[2])
        if sec != 0:
            msgs.append(f"R2 time_broker seconds not zero at {tb}")
            break

    for _, row in df.iterrows():
        tb = str(row["time_broker"])
        bo, bh, bl, bc = float(row["bid_open"]), float(row["bid_high"]), float(row["bid_low"]), float(row["bid_close"])
        lo = min(bo, bc)
        hi = max(bo, bc)
        if bl > lo + 1e-12 or bh + 1e-12 < hi:
            msgs.append(f"R3 bid OHLC inconsistent at {tb}")
            break

    for _, row in df.iterrows():
        tb = str(row["time_broker"])
        ao, ah, al, ac = float(row["ask_open"]), float(row["ask_high"]), float(row["ask_low"]), float(row["ask_close"])
        lo = min(ao, ac)
        hi = max(ao, ac)
        if al > lo + 1e-12 or ah + 1e-12 < hi:
            msgs.append(f"R4 ask OHLC inconsistent at {tb}")
            break

    for _, row in df.iterrows():
        tb = str(row["time_broker"])
        bl, bh = float(row["bid_low"]), float(row["bid_high"])
        al, ah = float(row["ask_low"]), float(row["ask_high"])
        if al + 1e-12 < bl or ah + 1e-12 < bh:
            msgs.append(f"R5 ask/bid range crossed at {tb}")
            break

    for _, row in df.iterrows():
        tb = str(row["time_broker"])
        ticks = int(row["ticks"])
        if ticks < 1:
            msgs.append(f"R6 ticks < 1 at {tb}")
            break

    return msgs


def summarise(df: pd.DataFrame) -> dict:
    if df.empty:
        return {"rows": 0, "first": None, "last": None, "rows_per_date": {}}
    times = df["time_broker"].astype(str)
    dates = times.str.slice(0, 10)
    rows_per_date = dates.value_counts().sort_index().to_dict()
    return {
        "rows": int(len(df)),
        "first": str(times.iloc[0]),
        "last": str(times.iloc[-1]),
        "rows_per_date": {str(k): int(v) for k, v in rows_per_date.items()},
    }


def main(argv: list[str] | None = None) -> int:
    args = argv if argv is not None else sys.argv[1:]
    if len(args) != 1:
        print("usage: python scripts/validate_m1_bidask.py <folder>", file=sys.stderr)
        return 2
    folder = Path(args[0])
    if not folder.is_dir():
        print(f"not a directory: {folder}", file=sys.stderr)
        return 2

    paths = sorted(folder.glob("*_m1_bidask.csv"))
    if not paths:
        print(f"no *_m1_bidask.csv in {folder}", file=sys.stderr)
        return 1

    for path in paths:
        symbol = path.name.replace("_m1_bidask.csv", "")
        df = load_bars(path)
        violations = check_bars(df)
        s = summarise(df)
        print(f"{symbol}: rows={s['rows']} first={s['first']} last={s['last']}")
        print(f"  violations={len(violations)}", end="")
        if violations:
            print(f" first={violations[0]}")
        else:
            print()
        for date, count in sorted(s["rows_per_date"].items()):
            print(f"  {date}: {count} rows")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
