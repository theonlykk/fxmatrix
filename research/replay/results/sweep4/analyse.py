"""analyse.py -- sweep4's PRE-REGISTERED marks (results/sweep_notes.md, 11 Oct ~15:10Z).

Per pair: score every (setting, week) segment with sweep.score (net pips after commission,
the open book marked at Fri 23:45 server); write weekly_<pair>.csv. Then:
Q1 per pair: median net of the 13 grid settings per week; persistently positive if > 0 in
   >= 6 of 8 weeks, persistently negative if < 0 in >= 6 of 8, else mixed.
Q2 GBPUSD, NZDCHF, NZDCAD each in the top half (top 4 of 9 by that week's median) in >= 5 of 8.
Q3 a grid setting is robust if positive in >= 6 of 8 weeks on >= 5 of 9 pairs.
Q4 (reported) the live B geometry's weekly net vs the grid median.

  python -B analyse.py <dir with out_sw4_<pair>_free_{events,book}.csv and the h8w ticks>
"""
import csv
import os
import statistics
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", ".."))

PAIRS = ("eurusd", "gbpusd", "eurgbp", "audcad", "audchf", "cadchf", "nzdchf", "nzdcad", "audnzd")
TOP3 = ("gbpusd", "nzdchf", "nzdcad")


def q1_class(medians):
    pos = sum(1 for m in medians if m > 0)
    neg = sum(1 for m in medians if m < 0)
    if pos >= 6:
        return "persistently positive"
    if neg >= 6:
        return "persistently negative"
    return "mixed"


def top_half(week_medians):
    return set(sorted(week_medians, key=lambda p: week_medians[p], reverse=True)[:4])


def robust(weekly_by_pair):
    """weekly_by_pair: {pair: [net per week]} for ONE setting."""
    return sum(1 for v in weekly_by_pair.values() if sum(1 for x in v if x > 0) >= 6) >= 5


def score_pair(pair, d):
    import compare as cmp
    import sweep as sw
    st = sw.get_set("sw4_" + pair)
    rows = sw.build_rows(st["windows"], st["geoms"], st["base"], st["ticks"])
    segs = [{"seg_id": r["seg_id"], "from_ms": r["from_ms"], "to_ms": r["to_ms"]} for r in rows]
    sc = sw.score(segs, cmp.read_events(os.path.join(d, "out_sw4_%s_free_events.csv" % pair)),
                  cmp.read_csv(os.path.join(d, "out_sw4_%s_free_book.csv" % pair)),
                  cmp.Ticks.load(os.path.join(d, st["ticks"])), comm_pips=st["comm_pips"])
    lab = sw.labels(st["windows"], st["geoms"])
    out = []
    for s in segs:
        g, w = lab[s["seg_id"]]
        o = sc[s["seg_id"]]
        out.append({"setting": g, "week": w, "S": o["S"], "R": o["R"], "net": o["total_net"],
                    "gross": round(o["realised"] + o["open"], 1)})
    return out


def main(d):
    data = {}
    for p in PAIRS:
        rows = score_pair(p, d)
        with open(os.path.join(HERE, "weekly_%s.csv" % p), "w", newline="") as f:
            w = csv.DictWriter(f, fieldnames=list(rows[0]))
            w.writeheader()
            w.writerows(rows)
        data[p] = rows
    weeks = sorted({r["week"] for r in data[PAIRS[0]]})
    grid = sorted({r["setting"] for r in data[PAIRS[0]] if r["setting"] != "live"})
    net = {p: {(r["setting"], r["week"]): r["net"] for r in data[p]} for p in PAIRS}
    med = {p: [statistics.median(net[p][(g, w)] for g in grid) for w in weeks] for p in PAIRS}
    lines = ["# sweep4 marks (pre-registered; net pips after commission; timing 0, carry off)", "",
             "## Q1: median net of the 13 grid settings per pair and week", "",
             "| pair | " + " | ".join(w[5:] for w in weeks) + " | weeks > 0 | class |",
             "|---|" + "---|" * (len(weeks) + 2)]
    for p in PAIRS:
        lines.append("| %s | %s | %d | %s |" % (p.upper(), " | ".join("%+.0f" % m for m in med[p]),
                                                sum(1 for m in med[p] if m > 0), q1_class(med[p])))
    lines += ["", "## Q2: sweep3's top three in the top half (top 4 of 9) per week", ""]
    tops = [top_half({p: med[p][i] for p in PAIRS}) for i in range(len(weeks))]
    for p in TOP3:
        n = sum(1 for t in tops if p in t)
        lines.append("- %s: top half in %d of %d weeks -> %s" % (p.upper(), n, len(weeks),
                                                                  "HOLDS" if n >= 5 else "does not hold"))
    lines += ["", "## Q3: grid settings positive in >= 6 of 8 weeks, counted by pair", "",
              "| setting | pairs with >= 6 of 8 weeks > 0 | robust |", "|---|---|---|"]
    for g in grid:
        wb = {p: [net[p][(g, w)] for w in weeks] for p in PAIRS}
        k = sum(1 for v in wb.values() if sum(1 for x in v if x > 0) >= 6)
        lines.append("| %s | %d | %s |" % (g, k, "YES" if robust(wb) else "no"))
    lines += ["", "## Q4 (reported): the live B geometry vs the grid median, per pair", "",
              "| pair | live: weeks > 0 | live: sum of 8 weeks | grid median: sum of 8 weeks |", "|---|---|---|---|"]
    for p in PAIRS:
        lv = [net[p][("live", w)] for w in weeks]
        lines.append("| %s | %d | %+.0f | %+.0f |" % (p.upper(), sum(1 for x in lv if x > 0), sum(lv), sum(med[p])))
    txt = "\n".join(lines) + "\n"
    with open(os.path.join(HERE, "marks.md"), "w", newline="\n") as f:
        f.write(txt)
    print(txt)


if __name__ == "__main__":
    main(sys.argv[1])
