"""analyse.py -- sweep6's PRE-REGISTERED marks (results/sweep_notes.md, sweep6, 12 Oct).

ADR-167 (the light side's add by depth gap) in the replay build (branch replay-adr167),
on sweep4's eight weeks. Per pair: score every (setting_table, week) segment with sweep.score
(net pips after commission, the open book marked at Fri 23:45 server); write weekly_<pair>.csv.

C0 (control, before any mark): the off rows must equal sweep4's weekly nets for the same
   setting and week (results/sweep4/weekly_<pair>.csv). Any mismatch: STOP, no mark is read.
E1 per pair and table (step, lin, dz): the weekly MEDIAN over the 3 settings of the paired
   difference net(table) - net(off); BETTER if > 0 in >= 6 of 8 weeks, WORSE if < 0 in
   >= 6 of 8, else NO DIFFERENCE.
E2 per table: HELPS if >= 5 of 9 pairs BETTER and <= 1 WORSE; HURTS if >= 5 WORSE and
   <= 1 BETTER; else NO VERDICT.
Reported (never deciding): the 8-week sum of the median difference; the standard deviation of
weekly nets and the worst week, table vs off (median setting); S and R totals.

  python -B analyse.py <dir with out_sw6_<pair>_free_{events,book}.csv and the h8w ticks>
"""
import csv
import os
import statistics
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", ".."))

PAIRS = ("eurusd", "gbpusd", "eurgbp", "audcad", "audchf", "cadchf", "nzdchf", "nzdcad", "audnzd")
BASES = ("live", "a7.5e7.5n8", "a10e10n8")
TABLES = ("step", "lin", "dz")


def e1_class(diffs):
    pos = sum(1 for d in diffs if d > 0)
    neg = sum(1 for d in diffs if d < 0)
    if pos >= 6:
        return "BETTER"
    if neg >= 6:
        return "WORSE"
    return "NO DIFFERENCE"


def e2_verdict(classes):
    b = sum(1 for c in classes if c == "BETTER")
    w = sum(1 for c in classes if c == "WORSE")
    if b >= 5 and w <= 1:
        return "HELPS"
    if w >= 5 and b <= 1:
        return "HURTS"
    return "NO VERDICT"


def median_diffs(net, bases, table, weeks):
    """net {(base, table, week): pips}; the weekly median over bases of table - off."""
    return [statistics.median(net[(b, table, w)] - net[(b, "off", w)] for b in bases) for w in weeks]


def control_mismatches(off, sweep4):
    """off {(base, week): net}, sweep4 {(setting, week): net}; rows that differ by more than 0.05."""
    return [(b, w, v, sweep4.get((b, w))) for (b, w), v in sorted(off.items())
            if sweep4.get((b, w)) is None or abs(v - sweep4[(b, w)]) > 0.05]


def score_pair(pair, d):
    import compare as cmp
    import sweep as sw
    st = sw.get_set("sw6_" + pair)
    rows = sw.build_rows(st["windows"], st["geoms"], st["base"], st["ticks"])
    segs = [{"seg_id": r["seg_id"], "from_ms": r["from_ms"], "to_ms": r["to_ms"]} for r in rows]
    sc = sw.score(segs, cmp.read_events(os.path.join(d, "out_sw6_%s_free_events.csv" % pair)),
                  cmp.read_csv(os.path.join(d, "out_sw6_%s_free_book.csv" % pair)),
                  cmp.Ticks.load(os.path.join(d, st["ticks"])), comm_pips=st["comm_pips"])
    lab = sw.labels(st["windows"], st["geoms"])
    out = []
    for s in segs:
        g, w = lab[s["seg_id"]]
        base, table = g.rsplit("_", 1)
        o = sc[s["seg_id"]]
        out.append({"setting": base, "table": table, "week": w, "S": o["S"], "R": o["R"],
                    "net": o["total_net"], "gross": round(o["realised"] + o["open"], 1)})
    return out


def read_sweep4(pair):
    with open(os.path.join(HERE, "..", "sweep4", "weekly_%s.csv" % pair), newline="") as f:
        return {(r["setting"], r["week"]): float(r["net"]) for r in csv.DictReader(f)}


def main(d):
    data, mism = {}, []
    for p in PAIRS:
        rows = score_pair(p, d)
        with open(os.path.join(HERE, "weekly_%s.csv" % p), "w", newline="") as f:
            w = csv.DictWriter(f, fieldnames=list(rows[0]))
            w.writeheader()
            w.writerows(rows)
        data[p] = rows
        off = {(r["setting"], r["week"]): r["net"] for r in rows if r["table"] == "off"}
        mism += [(p,) + m for m in control_mismatches(off, read_sweep4(p))]
    lines = ["# sweep6 marks (pre-registered; ADR-167 tables vs off; net pips after commission; "
             "timing 0, carry off, cap 8)", ""]
    if mism:
        lines += ["**C0 FAILED: the off rows do not reproduce sweep4. STOP; no mark is read.**", ""]
        lines += ["- %s %s %s: sweep6 %s, sweep4 %s" % m for m in mism]
        txt = "\n".join(lines) + "\n"
        with open(os.path.join(HERE, "marks.md"), "w", newline="\n") as f:
            f.write(txt)
        print(txt)
        return 1
    lines += ["C0: the off rows equal sweep4's weekly nets on all nine pairs (%d rows)." %
              sum(len([r for r in data[p] if r["table"] == "off"]) for p in PAIRS), ""]
    weeks = sorted({r["week"] for r in data[PAIRS[0]]})
    net = {p: {(r["setting"], r["table"], r["week"]): r["net"] for r in data[p]} for p in PAIRS}
    for t in TABLES:
        lines += ["## Table %s" % t, "",
                  "| pair | " + " | ".join(w[5:] for w in weeks) + " | weeks > 0 | 8-week sum | E1 | "
                  "sd weekly off / %s | worst week off / %s | S off / %s | R off / %s |" % (t, t, t, t),
                  "|---|" + "---|" * (len(weeks) + 8)]
        classes = []
        for p in PAIRS:
            md = median_diffs(net[p], BASES, t, weeks)
            c = e1_class(md)
            classes.append(c)
            med_off = [statistics.median(net[p][(b, "off", w)] for b in BASES) for w in weeks]
            med_on = [statistics.median(net[p][(b, t, w)] for b in BASES) for w in weeks]
            s_off = sum(r["S"] for r in data[p] if r["table"] == "off")
            s_on = sum(r["S"] for r in data[p] if r["table"] == t)
            r_off = sum(r["R"] for r in data[p] if r["table"] == "off")
            r_on = sum(r["R"] for r in data[p] if r["table"] == t)
            lines.append("| %s | %s | %d | %+.0f | %s | %.0f / %.0f | %+.0f / %+.0f | %d / %d | %d / %d |" % (
                p.upper(), " | ".join("%+.0f" % x for x in md), sum(1 for x in md if x > 0), sum(md), c,
                statistics.stdev(med_off), statistics.stdev(med_on), min(med_off), min(med_on),
                s_off, s_on, r_off, r_on))
        lines += ["", "- E2 (%s): BETTER %d, NO DIFFERENCE %d, WORSE %d -> **%s**" % (
            t, classes.count("BETTER"), classes.count("NO DIFFERENCE"), classes.count("WORSE"),
            e2_verdict(classes)), ""]
    txt = "\n".join(lines) + "\n"
    with open(os.path.join(HERE, "marks.md"), "w", newline="\n") as f:
        f.write(txt)
    print(txt)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
