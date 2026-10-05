"""C125 T3 driver: the money where T1 says it should be (read-only).

    python holdout_t3.py --export <archive export .jsonl> --bars <bidask folder> [--bars-ic <folder>]

docs/research/holdout-verdict-criteria.md s2 (T3a, T3b, T3c) and s5. Uses
`compass_score.load` and `side_metrics` (unchanged) for realised all-in
net by close time, and `ftmo_days.load_bars` / `usd_per_quote` for marks.
The export should be the ARCHIVE export (every row), so layers opened
more than 14 days before the window still carry their open price.
"""
import argparse
import glob
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "compass"))
sys.path.insert(0, os.path.join(HERE, "..", "ftmo_pass"))
import compass_score as cs  # noqa: E402
import ftmo_days as fd      # noqa: E402

REVERTING = ("GBPUSD", "EURGBP", "NZDCAD")
TRENDING = ("AUDCHF", "NZDCHF", "AUDCAD")
FLEETS = (("A", "OPT"), ("B", "OPTB"), ("C", "OPTC"), ("D", "OPTD"))
ACCOUNTS = [1514731800, 53066709, 53071896, 53077984]
FLEET_PAIRS = {"A": ("EURUSD", "GBPUSD", "EURGBP", "AUDCHF", "CADCHF", "NZDCAD", "AUDNZD")}
WINDOW = ("2026-10-04T22:00Z", "2026-10-09T21:00Z", 5)
MARKS = ("2026-10-04T22:30Z", "2026-10-09T20:45Z")


def inst(pair, slot):
    return "GRIND_%s_%s" % (pair, slot)


def runs(fleet, pair):
    """Does this fleet run this pair (A: the seven-pair ring only)."""
    return pair in FLEET_PAIRS.get(fleet, (pair,))


def realised(layers, instance, t0, t1):
    """Realised all-in net of both sides closed in [t0, t1) (compass_score.side_metrics)."""
    w = [(t0, t1, (t1 - t0) / 86400.0)]
    return sum(cs.side_metrics(layers, instance, side, w, t0)["net"] for side in cs.SIDES)


def mtm_mid(layers, instance, t, bars):
    """(open MTM in USD at t marked at the minute mid, layers open at t without a price or quote)."""
    sym = instance.split("_")[1]
    total, unpriced = 0.0, 0
    for l in layers.get(instance, {}).values():
        start = l.open_t if l.open_t is not None else float("-inf")
        if not (start <= t and (not l.closed or l.close_t > t)):
            continue
        q = fd.quote_at(bars, sym, t)
        k = fd.usd_per_quote(bars, sym, t) if q is not None else None
        if l.open_price is None or q is None or k is None:
            unpriced += 1
            continue
        mid = (q[0] + q[1]) / 2
        sgn = 1 if l.side == "L" else -1
        total += sgn * (mid - l.open_price) * 100000 * 0.01 * k
    return total, unpriced


def t3(layers, bars_by_fleet, window=WINDOW, marks=MARKS):
    """T3a, T3b, T3c as in the criteria s2. Returns a dict."""
    t0, t1, days = cs.utc(window[0]), cs.utc(window[1]), window[2]
    m0, m1 = cs.utc(marks[0]), cs.utc(marks[1])
    rev_net, t3b, t3c, unpriced = {}, {}, 0.0, 0
    for f, slot in FLEETS:
        rev = [p for p in REVERTING if runs(f, p)]
        rev_net[f] = round(sum(realised(layers, inst(p, slot), t0, t1) for p in rev), 10)
        if f != "A":
            tr = [p for p in TRENDING if runs(f, p)]
            t3b[f] = rev_net[f] / (len(rev) * days) - sum(
                realised(layers, inst(p, slot), t0, t1) for p in tr) / (len(tr) * days)
        bars = bars_by_fleet.get(f, {})
        for p in rev:
            i = inst(p, slot)
            a, ua = mtm_mid(layers, i, m0, bars)
            b, ub = mtm_mid(layers, i, m1, bars)
            t3c += realised(layers, i, m0, m1) + b - a
            unpriced += ua + ub
    positive = sum(1 for v in rev_net.values() if v > 0)
    return {"rev_net": rev_net, "t3a_positive": positive, "t3a_pass": positive >= 3,
            "t3b": t3b, "t3c": t3c, "t3c_pass": t3c > 0, "unpriced": unpriced}


def main(argv=None):
    ap = argparse.ArgumentParser(description="C125 T3 (holdout-verdict-criteria s2)")
    ap.add_argument("--export", action="append", required=True)
    ap.add_argument("--bars", required=True, help="FTMO grind_bidask_dump folder (fleet A)")
    ap.add_argument("--bars-ic", help="IC grind_bidask_dump folder (B, C, D); default: the FTMO folder")
    a = ap.parse_args(argv)

    def folder(d):
        return {os.path.basename(p).split("_")[-1][:-4]: fd.load_bars(p) for p in glob.glob(os.path.join(d, "*.csv"))}
    fb = folder(a.bars)
    ib = folder(a.bars_ic) if a.bars_ic else fb
    _exp, layers = cs.load(a.export, ACCOUNTS)
    r = t3(layers, {"A": fb, "B": ib, "C": ib, "D": ib})
    print("window", WINDOW, "marks", MARKS)
    print("T3a reverting group realised per fleet:", {k: round(v, 2) for k, v in r["rev_net"].items()},
          "positive", r["t3a_positive"], "of 4 ->", "PASS" if r["t3a_pass"] else "FAIL")
    print("T3b (reported) reverting minus trending per instance-day:", {k: round(v, 3) for k, v in r["t3b"].items()})
    print("T3c realised + change in open MTM (mid), reverting group, A-D: %+.2f ->" % r["t3c"],
          "> 0" if r["t3c_pass"] else "<= 0", "| layers not marked:", r["unpriced"])


if __name__ == "__main__":
    main()
