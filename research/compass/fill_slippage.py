"""Fill slippage of entry limits per fleet, pair and side (backlog C132;
Gemini GR2-4, docs/research/compass-round2-review.md s6). Reported at a
compass round's scoring, never deciding. Read-only on the study export;
standard library only.

    python research/compass/fill_slippage.py --export <study_export.jsonl> --round research/compass/round2.json [--baseline research/compass/round1.json]
    python -m unittest research/compass/test_fill_slippage.py -v

Source: fill_logs rows with role ENT and entry_type IN. `slippage_pips` is
the EA's own number (grind_archive.mqh 425-434, test AR12): BUY (order -
deal) / pip, SELL (deal - order) / pip, so POSITIVE = filled better than the
limit, NEGATIVE = worse. Fill time = deal_time_broker_msc (server clock) -
the server offset (GMT+3 until the November clock change).
Fleets: the instance id's last letter B, C or D; anything else is A (FTMO).
A is left out by default (the holdout window is open; criteria s6).
"""
import argparse
import json
import os
import statistics
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import compass_score as cs  # noqa: E402

SERVER_OFFSET_S = 10800
HALF = -0.5


def fleet_of(instance_id):
    """'GRIND_EURUSD_OPTB' -> 'B'; an id not ending in B, C or D is A (FTMO)."""
    last = instance_id[-1:]
    return last if last in ("B", "C", "D") else "A"


def pair_of(instance_id):
    """'GRIND_EURGBP_OPTC' -> 'EURGBP'."""
    return instance_id.split("_")[1]


def entry_fills(rows, fleets=("B", "C", "D"), offset_s=SERVER_OFFSET_S):
    """ENT / IN fill_logs rows with a slippage number, on the given fleets."""
    out = []
    for r in rows:
        if r.get("table") != "fill_logs" or r.get("role") != "ENT":
            continue
        if r.get("entry_type") != "IN" or r.get("slippage_pips") is None:
            continue
        inst = r.get("instance_id") or ""
        fleet = fleet_of(inst)
        if fleet not in fleets or r.get("deal_time_broker_msc") is None:
            continue
        out.append({"fleet": fleet, "pair": pair_of(inst), "side": r.get("side"),
                    "inst": inst, "t": r["deal_time_broker_msc"] / 1000.0 - offset_s,
                    "slip": float(r["slippage_pips"]), "deal": r.get("deal_ticket"),
                    "order": r.get("order_ticket"), "deal_price": r.get("deal_price"),
                    "order_price": r.get("order_price_open")})
    return out


def in_windows(t, windows):
    return any(a <= t < b for a, b, _d in windows)


def stats(values):
    n = len(values)
    if n == 0:
        return {"n": 0}
    return {"n": n, "mean": sum(values) / n, "median": statistics.median(values),
            "worse": sum(1 for v in values if v < 0) / n,
            "worse_half": sum(1 for v in values if v < HALF) / n,
            "worst": min(values)}


def table(fills, windows):
    """(pair, side, fleet) -> stats of the fills inside the windows."""
    groups = {}
    for f in fills:
        if in_windows(f["t"], windows):
            groups.setdefault((f["pair"], f["side"], f["fleet"]), []).append(f["slip"])
    return {k: stats(v) for k, v in groups.items()}


def outliers(fills, windows, below=-5.0):
    """Fills inside the windows worse than `below` pips, worst first."""
    out = [f for f in fills if in_windows(f["t"], windows) and f["slip"] < below]
    return sorted(out, key=lambda f: f["slip"])


def load(paths):
    rows = []
    for p in paths:
        with open(p, encoding="utf-8-sig") as fh:
            for line in fh:
                line = line.strip()
                if line:
                    rows.append(json.loads(line))
    return rows


def windows_of(round_path):
    cfg = cs.load_round(round_path)
    return [(cs.utc(a), cs.utc(b), d) for a, b, d in cfg["windows"]]


def fmt(s):
    if not s or s["n"] == 0:
        return "%4d %6s %6s %5s %5s %6s" % (0, "-", "-", "-", "-", "-")
    return "%4d %+6.2f %+6.2f %4.0f%% %4.0f%% %+6.1f" % (
        s["n"], s["mean"], s["median"], 100 * s["worse"], 100 * s["worse_half"], s["worst"])


def report(fills, windows, label, below):
    tab = table(fills, windows)
    data_end = max((f["t"] for f in fills), default=None)
    print("== %s ==" % label)
    if data_end is not None and windows and data_end < max(b for _a, b, _d in windows):
        print("PROVISIONAL: the export ends before the last window does")
    print("%-7s %-4s %-5s %4s %6s %6s %5s %5s %6s" % (
        "pair", "side", "fleet", "n", "mean", "median", "worse", "<-0.5", "worst"))
    for key in sorted(tab):
        print("%-7s %-4s %-5s %s" % (key[0], key[1], key[2], fmt(tab[key])))
    by_fleet = {}
    for f in fills:
        if in_windows(f["t"], windows):
            by_fleet.setdefault(f["fleet"], []).append(f["slip"])
    for fleet in sorted(by_fleet):
        print("%-7s %-4s %-5s %s" % ("ALL", "", fleet, fmt(stats(by_fleet[fleet]))))
    out = outliers(fills, windows, below)
    print("outliers below %.1f pips: %d" % (below, len(out)))
    for f in out:
        print("  %s %s %+.1f deal %s order %s fill %s limit %s" % (
            f["inst"], f["side"], f["slip"], f["deal"], f["order"],
            f["deal_price"], f["order_price"]))


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--export", action="append", required=True)
    ap.add_argument("--round", required=True)
    ap.add_argument("--baseline", help="an earlier round file, reported first for comparison")
    ap.add_argument("--fleets", default="BCD")
    ap.add_argument("--below", type=float, default=-5.0)
    a = ap.parse_args(argv)
    fills = entry_fills(load(a.export), fleets=tuple(a.fleets))
    if a.baseline:
        report(fills, windows_of(a.baseline), "baseline " + os.path.basename(a.baseline), a.below)
    report(fills, windows_of(a.round), "round " + os.path.basename(a.round), a.below)
    return 0


if __name__ == "__main__":
    sys.exit(main())
