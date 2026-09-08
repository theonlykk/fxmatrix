"""One-off fetch: GBPUSD M5 Truss Crisis window -> GBPUSD_truss_crisis_oos.csv"""
import csv
import sys
from datetime import datetime
from pathlib import Path

import MetaTrader5 as mt5
import numpy as np

TERMINAL = r"C:\Program Files\FTMO Global Markets MT5 Terminal\terminal64.exe"
OUT = Path(r"d:\fxmatrix\data\GBPUSD_truss_crisis_oos.csv")
SYMBOL = "GBPUSD"
TF = mt5.TIMEFRAME_M5
DATE_FROM = datetime(2022, 8, 1)
DATE_TO = datetime(2022, 11, 2)


def main() -> int:
    if not mt5.initialize(path=TERMINAL):
        print("INIT_FAIL", mt5.last_error())
        return 1

    rates = mt5.copy_rates_range(SYMBOL, TF, DATE_FROM, DATE_TO)
    err = mt5.last_error()
    mt5.shutdown()

    print("MT5_ERROR", err)
    print("BAR_COUNT", 0 if rates is None else len(rates))

    if rates is None or len(rates) <= 1:
        if rates is not None and len(rates) == 1:
            t = datetime.utcfromtimestamp(int(rates[0]["time"]))
            print("PLACEHOLDER_ONLY", t, rates[0]["close"])
        print("RESULT", "FAIL_NO_WRITE")
        return 3

    first_t = datetime.utcfromtimestamp(int(rates[0]["time"]))
    last_t = datetime.utcfromtimestamp(int(rates[-1]["time"]))
    print("FIRST_BAR", first_t)
    print("LAST_BAR", last_t)

    if first_t.year > 2022 or last_t.year < 2022 or first_t > datetime(2022, 8, 15):
        print("RESULT", "FAIL_SPURIOUS_RANGE")
        return 4

    closes = rates["close"]
    min_close = float(closes.min())
    max_close = float(closes.max())
    net_pips = (float(closes[-1]) - float(closes[0])) * 10000
    print("MIN_CLOSE", min_close)
    print("MAX_CLOSE", max_close)
    print("NET_PIPS", round(net_pips, 1))

    times = rates["time"].astype(np.int64)
    deltas = np.diff(times)
    non5 = int(np.sum(deltas != 300))
    unexpected = []
    for i, d in enumerate(deltas):
        if d == 300:
            continue
        t_prev = datetime.utcfromtimestamp(int(times[i]))
        t_next = datetime.utcfromtimestamp(int(times[i + 1]))
        if d > 3600 * 24 + 300:
            unexpected.append((t_prev, t_next, int(d)))

    print("TOTAL_GAPS_NON5MIN", non5)
    print("UNEXPECTED_GAPS", len(unexpected))
    for g in unexpected[:5]:
        print("GAP", g[0], "->", g[1], "sec=", g[2])

    OUT.parent.mkdir(parents=True, exist_ok=True)
    with OUT.open("w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["datetime", "OPEN", "HIGH", "LOW", "CLOSE", "SPREAD"])
        for r in rates:
            dt = datetime.utcfromtimestamp(int(r["time"])).strftime("%Y-%m-%d %H:%M:%S")
            w.writerow(
                [
                    dt,
                    f"{r['open']:.5f}",
                    f"{r['high']:.5f}",
                    f"{r['low']:.5f}",
                    f"{r['close']:.5f}",
                    int(r["spread"]),
                ]
            )

    print("WROTE", OUT)
    print("FILE_BYTES", OUT.stat().st_size)
    print("RESULT", "SUCCESS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
