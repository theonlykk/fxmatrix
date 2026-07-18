"""Analyze exported OOS CSV and print summary stats."""
import sys
from pathlib import Path

import pandas as pd


def analyze(path: Path) -> None:
    df = pd.read_csv(path)
    df["datetime"] = pd.to_datetime(df["datetime"])
    print(f"FILE {path.name}")
    print(f"  BAR_COUNT {len(df)}")
    print(f"  FIRST {df['datetime'].iloc[0]}")
    print(f"  LAST {df['datetime'].iloc[-1]}")
    print(f"  MIN_CLOSE {df['CLOSE'].min():.5f}")
    print(f"  MAX_CLOSE {df['CLOSE'].max():.5f}")
    net = (df["CLOSE"].iloc[-1] - df["CLOSE"].iloc[0]) * 10000
    print(f"  NET_PIPS {net:.1f}")
    deltas = df["datetime"].diff().dt.total_seconds().fillna(300)
    non5 = int((deltas != 300).sum())
    unexpected = 0
    for i in range(1, len(df)):
        dt = (df["datetime"].iloc[i] - df["datetime"].iloc[i - 1]).total_seconds()
        if dt == 300:
            continue
        prev = df["datetime"].iloc[i - 1]
        if dt > 86400 * 3 or (prev.weekday() < 4 and dt > 900):
            unexpected += 1
    print(f"  NON5MIN_GAPS {non5}")
    print(f"  UNEXPECTED_GAPS {unexpected}")


if __name__ == "__main__":
    for p in sys.argv[1:]:
        analyze(Path(p))
