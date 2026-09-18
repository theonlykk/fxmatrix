#!/usr/bin/env python3
"""
Aggregate roll-mode sweep cells into a mode x P x window table.

Reads a checkpoint written by run_width_exit_sweep.py and reports, per
(window, cap_mode, max_layers):

  total_pnl      sum of mean_pnl across pairs   <- rank on this
  total_realised sum of mean_realised           <- shown, NOT ranked on
  exits/fc       sum(mean_exits) / sum(mean_forced_closes)
  stranded_hr    mean of mean_stranded_hours across pairs
  fc_pnl         sum of mean_forced_close_pnl_usd
  pairs          number of pairs in the group

Ranking on realised systematically favours stall: stall parks losses as
open inventory, rolling crystallises them. total_pnl is the comparison.

Magnitudes are not usable. The simulator is single-sided, so a capped
stall ladder idles the whole instance where live the other side keeps
scalping. Compare modes, not levels.

Usage:
  python aggregate_roll_modes.py <checkpoint.json> [--pair-detail] [--csv out.csv]
"""

import argparse
import json
import sys
from collections import defaultdict
from pathlib import Path

NEEDED = [
    "cap_mode", "max_layers", "window", "pair",
    "mean_pnl", "mean_realised", "mean_exits",
    "mean_forced_closes", "mean_stranded_hours",
    "mean_forced_close_pnl_usd",
]


def load_cells(path):
    try:
        payload = json.loads(Path(path).read_text(encoding="utf-8"))
    except Exception as exc:
        sys.exit("ERROR: cannot read %s: %s" % (path, exc))
    cells = payload.get("cells") or {}
    if not cells:
        sys.exit("ERROR: no 'cells' in %s" % path)
    rows = list(cells.values())
    missing = [f for f in NEEDED if f not in rows[0]]
    if missing:
        print("WARNING: cells are missing fields: %s" % ", ".join(missing))
        print("Fields present: %s" % ", ".join(sorted(rows[0].keys())))
    meta = {k: payload.get(k) for k in
            ("git_commit", "cost_model_version", "n_seeds", "substeps")
            if payload.get(k) is not None}
    return rows, meta


def group(rows, keys):
    out = defaultdict(list)
    for r in rows:
        out[tuple(r.get(k) for k in keys)].append(r)
    return out


def summarise(cells):
    def s(field):
        return sum(float(c.get(field) or 0.0) for c in cells)
    fc = s("mean_forced_closes")
    pairs = sorted({c.get("pair") for c in cells})
    stranded = [float(c.get("mean_stranded_hours") or 0.0) for c in cells]
    return {
        "total_pnl": s("mean_pnl"),
        "total_realised": s("mean_realised"),
        "forced_closes": fc,
        "exits_per_fc": (s("mean_exits") / fc) if fc > 0 else None,
        "stranded_hr": (sum(stranded) / len(stranded)) if stranded else 0.0,
        "fc_pnl": s("mean_forced_close_pnl_usd"),
        "pairs": pairs,
    }


def fmt(v, width=10, places=1):
    if v is None:
        return "-".rjust(width)
    return ("%.*f" % (places, v)).rjust(width)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("checkpoint")
    ap.add_argument("--pair-detail", action="store_true",
                    help="also print a per-pair breakdown for each window")
    ap.add_argument("--csv", help="write the aggregate table to this path")
    args = ap.parse_args()

    rows, meta = load_cells(args.checkpoint)
    if meta:
        print("Run metadata: " + ", ".join("%s=%s" % kv for kv in meta.items()))
    print("Cells: %d" % len(rows))
    print()

    groups = group(rows, ("window", "cap_mode", "max_layers"))
    header = ("window", "mode", "P", "total_pnl", "total_real",
              "exits/fc", "fc_n", "fc_pnl", "stranded_hr", "pairs")
    print("%-22s %-13s %3s %10s %10s %10s %8s %10s %11s %5s"
          % header)
    print("-" * 112)

    csv_rows = []
    for key in sorted(groups, key=lambda k: (str(k[0]), str(k[1]), k[2] or 0)):
        window, mode, p = key
        g = summarise(groups[key])
        print("%-22s %-13s %3s %s %s %s %s %s %s %5d"
              % (window, mode, p,
                 fmt(g["total_pnl"]), fmt(g["total_realised"]),
                 fmt(g["exits_per_fc"], 10, 2), fmt(g["forced_closes"], 8, 0),
                 fmt(g["fc_pnl"]), fmt(g["stranded_hr"], 11, 1),
                 len(g["pairs"])))
        csv_rows.append([window, mode, p, g["total_pnl"], g["total_realised"],
                         g["exits_per_fc"], g["forced_closes"], g["fc_pnl"],
                         g["stranded_hr"], len(g["pairs"]),
                         " ".join(str(x) for x in g["pairs"])])

    # Point 5: a window whose pair set differs from the widest one cannot
    # be compared against it, and conclusions there cover only its pairs.
    by_window = defaultdict(set)
    for r in rows:
        by_window[r.get("window")].add(r.get("pair"))
    widest = max((len(v) for v in by_window.values()), default=0)
    partial = {w: sorted(v) for w, v in by_window.items() if len(v) < widest}
    if partial:
        print()
        print("NOTE: these windows cover fewer pairs than the widest window "
              "(%d pairs)." % widest)
        print("Conclusions from them apply only to the pairs listed.")
        for w, ps in sorted(partial.items()):
            print("  %-22s %d pairs: %s" % (w, len(ps), ", ".join(ps)))

    if args.pair_detail:
        for window in sorted(by_window):
            print()
            print("=== %s, per pair ===" % window)
            print("%-9s %-13s %3s %10s %10s %10s %11s"
                  % ("pair", "mode", "P", "mean_pnl", "mean_real",
                     "exits/fc", "stranded_hr"))
            sub = group([r for r in rows if r.get("window") == window],
                        ("pair", "cap_mode", "max_layers"))
            for key in sorted(sub, key=lambda k: (str(k[0]), str(k[1]), k[2] or 0)):
                pair, mode, p = key
                g = summarise(sub[key])
                print("%-9s %-13s %3s %s %s %s %s"
                      % (pair, mode, p, fmt(g["total_pnl"]),
                         fmt(g["total_realised"]),
                         fmt(g["exits_per_fc"], 10, 2),
                         fmt(g["stranded_hr"], 11, 1)))

    if args.csv:
        import csv
        with open(args.csv, "w", newline="", encoding="utf-8") as fh:
            w = csv.writer(fh)
            w.writerow(["window", "mode", "P", "total_pnl", "total_realised",
                        "exits_per_fc", "forced_closes", "fc_pnl",
                        "stranded_hr", "n_pairs", "pairs"])
            w.writerows(csv_rows)
        print()
        print("Wrote %s" % args.csv)


if __name__ == "__main__":
    main()