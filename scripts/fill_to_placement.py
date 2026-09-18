#!/usr/bin/env python3
"""
Fill-to-placement gap, from the MT5 TERMINAL log Trades lines.

The Phase 1 promotion gate metric, and the pre-Phase-2 baseline. For each
entry fill, finds the next entry order placed on the same symbol and reports
the interval. That gap is guard contention as an entry experiences it.

Measured 2026-09-18 on GBPUSD ALT: L14 filled 10:38:55, its L15 entry order
reached the market 11:51:59. 73 minutes.

Read the TERMINAL log, not MQL5\\Logs. Trades lines live in
  ...\\Terminal\\<hash>\\logs\\<YYYYMMDD>.log
while expert Print output lives in
  ...\\Terminal\\<hash>\\MQL5\\Logs\\<YYYYMMDD>.log

Usage:
  python fill_to_placement.py <terminal_log> [--symbol GBPUSD] [--csv out.csv]
  python fill_to_placement.py <log> --max-gap-min 240

Caveats stated rather than hidden:
  - Trades lines carry no magic number, so on a symbol with two arms attached
    a fill and the next order cannot be attributed to an arm with certainty.
    Pairing is by symbol and direction in time order. On GBPUSD both OPT and
    ALT are attached, so treat per-symbol gaps as fleet-level for that symbol.
    Use --price to pin a specific order price when you need one arm.
  - An unpaired fill means no entry order followed within the window: either
    the ladder capped, or the guard never released a slot before the log ended.
    Reported separately; they are NOT zero-gap observations.
"""

import argparse
import csv
import re
import sys
from datetime import datetime, timedelta
from pathlib import Path

# 10:38:55.708  Trades  '1514582088': deal #522728921 buy 0.01 GBPUSD at 1.33614 done (based on order #545312685)
DEAL = re.compile(
    r"(?P<t>\d{2}:\d{2}:\d{2}\.\d{3})\s+Trades\s+'\d+':\s+deal\s+#(?P<deal>\d+)\s+"
    r"(?P<dir>buy|sell)\s+[\d.]+\s+(?P<sym>[A-Z]{6})\s+at\s+(?P<px>[\d.]+)\s+done"
)

# 11:51:59.702  Trades  '1514582088': buy limit 0.01 GBPUSD at 1.33436
ORDER = re.compile(
    r"(?P<t>\d{2}:\d{2}:\d{2}\.\d{3})\s+Trades\s+'\d+':\s+"
    r"(?P<dir>buy|sell)\s+limit\s+[\d.]+\s+(?P<sym>[A-Z]{6})\s+at\s+(?P<px>[\d.]+)\s*$"
)


def parse_time(s):
    return datetime.strptime(s, "%H:%M:%S.%f")


def decode_log(path):
    """MT5 terminal logs are usually UTF-16 LE, sometimes with no BOM.
    Reading one as UTF-8 yields replacement characters and matches nothing,
    so sniff rather than assume."""
    data = Path(path).read_bytes()
    if not data:
        sys.exit("ERROR: %s is empty." % path)
    if data[:2] == b"\xff\xfe":
        return data.decode("utf-16-le", errors="replace"), "utf-16-le (BOM)"
    if data[:2] == b"\xfe\xff":
        return data.decode("utf-16-be", errors="replace"), "utf-16-be (BOM)"
    if data[:3] == b"\xef\xbb\xbf":
        return data.decode("utf-8-sig", errors="replace"), "utf-8 (BOM)"
    head = data[:4000]
    if head.count(0) > len(head) // 4:
        enc = "utf-16-le" if head[1:2] == b"\x00" else "utf-16-be"
        return data.decode(enc, errors="replace"), enc + " (sniffed)"
    return data.decode("utf-8", errors="replace"), "utf-8"


def read_events(path):
    deals, orders = [], []
    raw, enc = decode_log(path)
    print("Decoded %s as %s." % (path, enc))
    for line in raw.splitlines():
        m = DEAL.search(line)
        if m:
            deals.append({"t": parse_time(m.group("t")), "sym": m.group("sym"),
                          "dir": m.group("dir"), "px": float(m.group("px")),
                          "deal": m.group("deal")})
            continue
        m = ORDER.search(line)
        if m:
            orders.append({"t": parse_time(m.group("t")), "sym": m.group("sym"),
                           "dir": m.group("dir"), "px": float(m.group("px"))})
    return deals, orders


EXIT_WINDOW_S = 2.0


def find_exit_follower(deal, orders_by_sym):
    """ADR-151 places a layer's exit within milliseconds of its ENTRY fill:
    opposite direction, same symbol, offset by exactly exit_pips. An EXIT
    fill (a scalp closing) has no such follower. Returns the exit order if
    this deal is an entry fill, else None."""
    for o in orders_by_sym.get(deal["sym"], []):
        dt = (o["t"] - deal["t"]).total_seconds()
        if dt < -0.001 or dt > EXIT_WINDOW_S:
            continue
        if o["dir"] == deal["dir"]:
            continue
        # a long layer's exit is ABOVE its entry, a short layer's BELOW
        if deal["dir"] == "buy" and o["px"] <= deal["px"]:
            continue
        if deal["dir"] == "sell" and o["px"] >= deal["px"]:
            continue
        return o
    return None


def is_entry_order(order, exit_orders):
    """Any limit identified as some entry fill's exit is not an entry."""
    return id(order) not in exit_orders


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("log")
    ap.add_argument("--symbol", help="restrict to one symbol, e.g. GBPUSD")
    ap.add_argument("--price", type=float,
                    help="only pair to an order at this exact price")
    ap.add_argument("--max-gap-min", type=float, default=480.0,
                    help="ignore pairings wider than this (default 480)")
    ap.add_argument("--csv")
    args = ap.parse_args()

    try:
        deals, orders = read_events(args.log)
    except Exception as exc:
        sys.exit("ERROR: cannot read %s: %s" % (args.log, exc))

    if args.symbol:
        deals = [d for d in deals if d["sym"] == args.symbol]
        orders = [o for o in orders if o["sym"] == args.symbol]
    if args.price is not None:
        orders = [o for o in orders if abs(o["px"] - args.price) < 1e-9]

    orders_by_sym = {}
    for o in orders:
        orders_by_sym.setdefault(o["sym"], []).append(o)
    for v in orders_by_sym.values():
        v.sort(key=lambda o: o["t"])

    entry_fills, exit_ids = [], set()
    for d in deals:
        follower = find_exit_follower(d, orders_by_sym)
        if follower is not None:
            entry_fills.append(d)
            exit_ids.add(id(follower))

    entry_orders = [o for o in orders if is_entry_order(o, exit_ids)]
    entry_orders.sort(key=lambda o: o["t"])

    print("Parsed %d deals (%d entry fills, %d exit fills / unclassified), "
          "%d limit orders of which %d are entries."
          % (len(deals), len(entry_fills), len(deals) - len(entry_fills),
             len(orders), len(entry_orders)))
    print("Only ENTRY fills are paired: an exit fill has no add due after it.")
    print()

    deals = entry_fills

    used = set()
    rows, unpaired = [], []
    for d in sorted(deals, key=lambda x: x["t"]):
        match = None
        for i, o in enumerate(entry_orders):
            if i in used or o["sym"] != d["sym"] or o["t"] <= d["t"]:
                continue
            gap = (o["t"] - d["t"]).total_seconds() / 60.0
            if gap > args.max_gap_min:
                break
            match = (i, o, gap)
            break
        if match is None:
            unpaired.append(d)
            continue
        i, o, gap = match
        used.add(i)
        rows.append({"symbol": d["sym"], "fill_time": d["t"].strftime("%H:%M:%S.%f")[:-3],
                     "fill_dir": d["dir"], "fill_px": d["px"],
                     "order_time": o["t"].strftime("%H:%M:%S.%f")[:-3],
                     "order_px": o["px"], "gap_min": round(gap, 2)})

    if not rows:
        print("No fill/entry-order pairs found.")
        if not deals and not orders:
            print("Nothing parsed at all. Either the encoding sniff was wrong")
            print("(check the Decoded line above) or this is the wrong log:")
            print("Trades lines are in Terminal\\<hash>\\logs, NOT")
            print("Terminal\\<hash>\\MQL5\\Logs, which holds expert Print output.")
        else:
            print("Parsed events but found no pairings. Try a wider --max-gap-min,")
            print("or check --symbol / --price if you narrowed the set.")
        return

    print("%-8s %-13s %-4s %-10s %-13s %-10s %9s"
          % ("symbol", "fill", "dir", "fill_px", "placed", "order_px", "gap_min"))
    print("-" * 78)
    for r in rows:
        print("%-8s %-13s %-4s %-10.5f %-13s %-10.5f %9.2f"
              % (r["symbol"], r["fill_time"], r["fill_dir"], r["fill_px"],
                 r["order_time"], r["order_px"], r["gap_min"]))

    gaps = sorted(r["gap_min"] for r in rows)
    n = len(gaps)
    median = gaps[n // 2] if n % 2 else (gaps[n // 2 - 1] + gaps[n // 2]) / 2
    print()
    print("n=%d  min=%.2f  median=%.2f  mean=%.2f  max=%.2f  (minutes)"
          % (n, gaps[0], median, sum(gaps) / n, gaps[-1]))
    over = [g for g in gaps if g > 1.0]
    print("gaps over 1 minute: %d of %d (%.0f%%)" % (len(over), n, 100.0 * len(over) / n))

    if unpaired:
        print()
        print("%d fills had no entry order within %.0f min. These are NOT"
              % (len(unpaired), args.max_gap_min))
        print("zero-gap observations: the ladder capped, or the guard never released")
        print("a slot before the log ended.")
        for d in unpaired[:10]:
            print("  %s %s %s at %.5f"
                  % (d["t"].strftime("%H:%M:%S"), d["sym"], d["dir"], d["px"]))
        if len(unpaired) > 10:
            print("  ... and %d more" % (len(unpaired) - 10))

    if args.csv:
        with open(args.csv, "w", newline="", encoding="utf-8") as fh:
            w = csv.DictWriter(fh, fieldnames=list(rows[0].keys()))
            w.writeheader()
            w.writerows(rows)
        print()
        print("Wrote %s" % args.csv)


if __name__ == "__main__":
    main()
