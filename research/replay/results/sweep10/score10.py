"""score10.py -- the sweep10 scorer (sweep_notes sweep10; HANDOFF s88, (B)).

Per pair: the daily equity curves of sweep9 (score9.py's tested functions: positions, each OUT_BY leg half, open
ones marked at bid / ask, swap from CARRY_SNAPSHOT, day ends at server midnights) with the PAIR's commission (0.06
USD a close / its pip value at 0.01 lots, sweep.get_set). Then the rule, decided on the period, per pair:
- OFFSET at E's q88 ALT add: OPT + ALT ends above OPT alone AND its worst point is no lower than OPT alone's.
- RETUNE: only if OPT + ALT at q88 ends NEGATIVE while two ADJACENT ALT cells (by add) both end POSITIVE; then to
  the lower-middle add of the longest run of positive cells (ties: the larger summed net). Else KEEP.
- DUP = OPT + 2 x ALT, reported the same way; the daily offset ratio (score9's) reported, never deciding.

  python -B score10.py --pair AUDCHF --run <run_sw10_audchf.csv> --outs <dir of out_sw10_*_free_{deals,events}.csv>
                       --ticks <ticks_53077984_AUDCHF_oct.csv> --out <report.md> [--csv <curves.csv>]
"""
import argparse
import csv
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.normpath(os.path.join(HERE, "..", "sweep9")))
sys.path.insert(0, os.path.normpath(os.path.join(HERE, "..", "..")))
import score9 as s9  # noqa: E402
import sweep as sw  # noqa: E402


def comm_for(pair):
    return sw.get_set("sw10_" + pair.lower())["comm_pips"]


def curve(pos, scalps, snaps, ends, mark, comm):
    return [0.0] + [s9.equity_at(pos, scalps, snaps, e, mark, comm=comm) for e in ends]


def combine(opt, alt, k=1):
    return [o + k * a for o, a in zip(opt, alt)]


def lower_middle(adds):
    return adds[(len(adds) - 1) // 2]


def _add(name):
    return float(name[1:].split("e")[0])


def decide(curves, opt, grid, q88):
    """grid: ALT cell names in add order; q88: the name of E's q88 cell."""
    o = curves[opt]
    cells = {}
    for n in grid:
        c1, c2 = combine(o, curves[n]), combine(o, curves[n], 2)
        cells[n] = {"alt_net": curves[n][-1], "alt_worst": min(curves[n]), "comb_net": c1[-1], "comb_worst": min(c1),
                    "dup_net": c2[-1], "dup_worst": min(c2)}
    q = cells[q88]
    offset = q["comb_net"] > o[-1] and q["comb_worst"] >= min(o)
    runs, cur = [], []
    for n in grid:
        if cells[n]["comb_net"] > 0:
            cur.append(n)
        else:
            if cur:
                runs.append(cur)
            cur = []
    if cur:
        runs.append(cur)
    bands = [r for r in runs if len(r) >= 2]
    retune, to = False, None
    if q["comb_net"] < 0 and bands:
        best = max(bands, key=lambda r: (len(r), sum(cells[n]["comb_net"] for n in r)))
        retune, to = True, lower_middle([_add(n) for n in best])
    return {"offset": offset, "retune": retune, "to": to, "cells": cells, "bands": bands}


def score_pair(pair, run_csv, outs, ticks):
    tag = os.path.basename(run_csv)[4:-4]
    segs, names, pos, scalps, snaps, counts = s9.load_run(
        run_csv, os.path.join(outs, "out_%s_free_deals.csv" % tag), os.path.join(outs, "out_%s_free_events.csv" % tag))
    comm = comm_for(pair)
    curves, info = {}, {}
    for seg, r in segs.items():
        ends = s9.day_ends(int(r["from_ms"]), int(r["to_ms"]))
        p, sc, sn = pos.get(seg, []), scalps.get(seg, []), snaps.get(seg, [])
        name = names[seg]
        curves[name] = curve(p, sc, sn, ends, ticks.mark, comm)
        c = counts.get(seg, {"S": 0, "R": 0, "A": 0})
        info[name] = dict(c, ends=ends, snaps=len(sn), open_n=sum(1 for x in p if x[3] is None))
    return curves, info


def report(pair, curves, info, opt, grid, q88):
    d = decide(curves, opt, grid, q88)
    o = curves[opt]
    od = s9.daily(o)
    f = lambda x: "-" if x is None else "%+.2f" % x
    lines = ["# sweep10 %s (score10.py): 1-20 Oct, one flat start carried; pips at 0.01 lots, commission %.3f a close"
             % (pair, comm_for(pair) if pair.upper() in sw.OPT10 else 0.0), "",
             "OPT %s: net %+.1f, worst %+.1f, S %d, R %d, A %d" % (
                 opt, o[-1], min(o), info[opt]["S"], info[opt]["R"], info[opt]["A"]),
             "Self-check: CARRY_SNAPSHOT per segment min %d, max %d" % (
                 min(i["snaps"] for i in info.values()), max(i["snaps"] for i in info.values())), "",
             "**OFFSET at q88 (%g): %s** (OPT + ALT %+.1f against OPT %+.1f; worst %+.1f against %+.1f)" % (
                 _add(q88), "YES" if d["offset"] else "NO", d["cells"][q88]["comb_net"], o[-1],
                 d["cells"][q88]["comb_worst"], min(o)),
             "**RETUNE: %s**%s" % ("YES -> %g" % d["to"] if d["retune"] else "NO (KEEP q88)",
                                   "" if d["retune"] else (" (no band of two adjacent positive cells)"
                                                           if d["cells"][q88]["comb_net"] < 0 else "")), "",
             "| ALT | S | R | A | S / A | ALT net | ALT worst | OPT + ALT | worst | OPT + 2 x ALT | worst | daily ratio |",
             "|---|---|---|---|---|---|---|---|---|---|---|---|"]
    for n in grid:
        c, i = d["cells"][n], info[n]
        sa = ("%.1f" % (i["S"] / i["A"])) if i["A"] else "-"
        lines.append("| %s%s | %d | %d | %d | %s | %+.1f | %+.1f | %+.1f | %+.1f | %+.1f | %+.1f | %s |" % (
            n, " (q88)" if n == q88 else "", i["S"], i["R"], i["A"], sa, c["alt_net"], c["alt_worst"], c["comb_net"],
            c["comb_worst"], c["dup_net"], c["dup_worst"], f(s9.offset_ratio(od, s9.daily(curves[n])))))
    return "\n".join(lines) + "\n"


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--pair", required=True)
    ap.add_argument("--run", required=True)
    ap.add_argument("--outs", required=True)
    ap.add_argument("--ticks", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--csv")
    a = ap.parse_args(argv)
    pair = a.pair.upper()
    st = sw.get_set("sw10_" + pair.lower())
    names = [g[0] for g in st["geoms"]]
    opt, grid = names[0], names[1:]
    q88 = "a%de%dn7" % (sw.Q88[pair], sw.Q88[pair])
    curves, info = score_pair(pair, a.run, a.outs, s9.Ticks(a.ticks))
    with open(a.out, "w", newline="\n") as f:
        f.write(report(pair, curves, info, opt, grid, q88))
    if a.csv:
        with open(a.csv, "w", newline="\n") as f:
            w = csv.writer(f)
            w.writerow(["geometry", "start"] + [s9._date(e) for e in info[opt]["ends"]])
            for n in names:
                w.writerow([n] + ["%.1f" % x for x in curves[n]])
    return 0


if __name__ == "__main__":
    sys.exit(main())
