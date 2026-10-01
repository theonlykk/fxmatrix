"""C86 recheck: which rollover nights are charged how many nights of swap.

Reads a study export (pipshed `archive_counts.py --export-study`) with the
FROZEN replay v1 loaders in `research/ejection_value` (imported, never
changed). Trade history only: a layer's swap is what the broker booked on
its close-by (both OUT_BY deals), held at 0.01 lots on every instance.

A rollover is the server midnight (00:00 server = 21:00Z while both
servers run GMT+3). A layer CROSSES the rollover at M when open < M < close.
Each crossing is labelled by the PASS DAY: the server weekday before M,
i.e. the day whose 23:50 carry pass prices that rollover (Mon=0 .. Sun=6).

For each key (fleet, symbol, side) the baseline is the median swap of
layers that crossed exactly one rollover with pass day Mon or Thu. Every
other layer's swap is divided by its key's baseline; keys whose baseline
is under $0.03 a night in size are left out (too small to read).

Usage:
    python research/swap_day/swap_day.py --export FILE [FILE ...] [--offset-h 3]
"""
import argparse
import collections
import datetime as _dt
import os
import statistics
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "ejection_value"))

from ev_data import load_export, filter_by_account, fleet_of, symbol_of   # noqa: E402
from ev_book import build_layers                                          # noqa: E402

DAY = 86400
DAYNAMES = ("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun")
MIN_BASELINE = 0.03
BASELINE_DAYS = ((0,), (3,))


def pass_days(open_t, close_t, offset_s=10800):
    """Pass weekdays of every server midnight M with open_t < M < close_t.
    Times are UTC epoch seconds; offset_s = server minus GMT."""
    if open_t is None or close_t is None or close_t <= open_t:
        return ()
    first = (int((open_t + offset_s) // DAY) + 1) * DAY - offset_s   # first midnight after open
    out = []
    m = first
    while m < close_t:                     # first > open_t by construction
        server_day = _dt.datetime.fromtimestamp(m + offset_s, _dt.timezone.utc)
        out.append((server_day.weekday() - 1) % 7)       # the day before M
        m += DAY
    return tuple(out)


def layer_rows(layers, offset_s=10800):
    """[(fleet, symbol, side, pattern, swap)] for closed layers with a swap."""
    rows = []
    for inst, by_pos in layers.items():
        fleet = fleet_of(inst)
        sym = symbol_of(inst)
        for lay in by_pos.values():
            if lay.open_t is None or lay.close_t is None or lay.closeby_swap is None:
                continue
            pat = pass_days(lay.open_t, lay.close_t, offset_s)
            if not pat:
                continue
            rows.append((fleet, sym, lay.side, pat, float(lay.closeby_swap)))
    return rows


def ratios(rows, min_baseline=MIN_BASELINE):
    """{pattern: [(fleet, symbol, side, ratio)]} against each key's Mon/Thu median."""
    base = collections.defaultdict(list)
    for fleet, sym, side, pat, swap in rows:
        if pat in BASELINE_DAYS:
            base[(fleet, sym, side)].append(swap)
    med = {k: statistics.median(v) for k, v in base.items()}
    out = collections.defaultdict(list)
    for fleet, sym, side, pat, swap in rows:
        b = med.get((fleet, sym, side))
        if b is None or abs(b) < min_baseline:
            continue
        out[pat].append((fleet, sym, side, swap / b))
    return out, med


def _label(pat):
    return "+".join(DAYNAMES[d] for d in pat)


def report(by_pat, med):
    lines = []
    lines.append("keys with a usable Mon/Thu baseline: %d" %
                 sum(1 for v in med.values() if abs(v) >= MIN_BASELINE))
    lines.append("%-22s %-5s %5s %7s %7s %7s" % ("pass days crossed", "fleet", "n", "median", "p25", "p75"))
    for pat in sorted(by_pat, key=lambda p: (len(p), p)):
        for fleet in ("A", "B", "C", "ALL"):
            vals = [r for f, _s, _d, r in by_pat[pat] if fleet == "ALL" or f == fleet]
            if not vals:
                continue
            vals.sort()
            q = statistics.quantiles(vals, n=4) if len(vals) >= 2 else [vals[0]] * 3
            lines.append("%-22s %-5s %5d %7.2f %7.2f %7.2f" %
                         (_label(pat), fleet, len(vals), statistics.median(vals), q[0], q[2]))
    return "\n".join(lines)


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--export", nargs="+", required=True)
    ap.add_argument("--offset-h", type=int, default=3)
    a = ap.parse_args(argv)
    exp, dropped = filter_by_account(load_export(a.export))
    layers = build_layers(exp, offset_s=a.offset_h * 3600)
    rows = layer_rows(layers, a.offset_h * 3600)
    by_pat, med = ratios(rows)
    print("dropped (other accounts):", dropped)
    print("closed layers that crossed a rollover:", len(rows))
    print(report(by_pat, med))


if __name__ == "__main__":
    main()
