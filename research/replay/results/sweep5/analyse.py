"""analyse.py -- sweep5's PRE-REGISTERED marks (results/sweep_notes.md, 11 Oct ~19:30Z).

Each day (40, 3 Aug - 25 Sep) a flat start 01:00 - 23:45 server, the book marked at 23:45.
D1 per pair: median over the 5 grid settings of the 40-day total net; count pairs > 0.
D2 per pair: for each (setting, week) the sum of the week's daily nets vs sweep4's carried-week
   net (results/sweep4/weekly_<pair>.csv): wins >= 26 of 40 BETTER, <= 14 WORSE, else NO
   DIFFERENCE; daily-flat beats carrying if >= 5 of 9 pairs BETTER and <= 1 WORSE.
Reported: the standard deviation of weekly totals, daily-flat vs carried (median over settings).

  python -B analyse.py <dir with out_sw5_<pair>_free_{events,book}.csv and the h8w ticks>
"""
import csv
import datetime as dt
import os
import statistics
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", ".."))

PAIRS = ("eurusd", "gbpusd", "eurgbp", "audcad", "audchf", "cadchf", "nzdchf", "nzdcad", "audnzd")


def d2_class(wins_of_40):
    if wins_of_40 >= 26:
        return "BETTER"
    if wins_of_40 <= 14:
        return "WORSE"
    return "NO DIFFERENCE"


def beats_carrying(classes):
    return classes.count("BETTER") >= 5 and classes.count("WORSE") <= 1


def week_of(day):
    d = dt.datetime.strptime(day, "%Y-%m-%d")
    return (d - dt.timedelta(days=d.weekday())).strftime("%Y-%m-%d")


def wins(daily_week_sum, carried):
    return sum(1 for k, v in daily_week_sum.items() if v > carried[k])


def score_pair(pair, d):
    import compare as cmp
    import sweep as sw
    st = sw.get_set("sw5_" + pair)
    rows = sw.build_rows(st["windows"], st["geoms"], st["base"], st["ticks"])
    segs = [{"seg_id": r["seg_id"], "from_ms": r["from_ms"], "to_ms": r["to_ms"]} for r in rows]
    sc = sw.score(segs, cmp.read_events(os.path.join(d, "out_sw5_%s_free_events.csv" % pair)),
                  cmp.read_csv(os.path.join(d, "out_sw5_%s_free_book.csv" % pair)),
                  cmp.Ticks.load(os.path.join(d, st["ticks"])), comm_pips=st["comm_pips"])
    lab = sw.labels(st["windows"], st["geoms"])
    return [{"setting": lab[s["seg_id"]][0], "day": lab[s["seg_id"]][1], "S": sc[s["seg_id"]]["S"],
             "R": sc[s["seg_id"]]["R"], "net": sc[s["seg_id"]]["total_net"],
             "gross": round(sc[s["seg_id"]]["realised"] + sc[s["seg_id"]]["open"], 1)} for s in segs]


def main(d):
    grid = ("a5e5n10", "a7.5e7.5n6", "a7.5e7.5n10", "a10e10n6", "a10e10n10")
    lines = ["# sweep5 marks (pre-registered; daily flat 01:00-23:45 server; net pips after commission; timing 0)", "",
             "| pair | D1: median 40-day total (5 settings) | days > 0 (median setting) | live: 40-day total | "
             "D2: daily wins of 40 | D2 class | sd weekly: daily / carried |",
             "|---|---|---|---|---|---|---|"]
    classes, d1pos = [], 0
    for p in PAIRS:
        rows = score_pair(p, d)
        with open(os.path.join(HERE, "daily_%s.csv" % p), "w", newline="") as f:
            w = csv.DictWriter(f, fieldnames=list(rows[0]))
            w.writeheader()
            w.writerows(rows)
        tot = {g: sum(r["net"] for r in rows if r["setting"] == g) for g in grid}
        d1 = statistics.median(tot.values())
        d1pos += d1 > 0
        days = sorted({r["day"] for r in rows})
        med_day = [statistics.median(r["net"] for r in rows if r["day"] == dd and r["setting"] in grid) for dd in days]
        live = sum(r["net"] for r in rows if r["setting"] == "live")
        dsum = {}
        for r in rows:
            if r["setting"] in grid:
                k = (r["setting"], week_of(r["day"]))
                dsum[k] = dsum.get(k, 0.0) + r["net"]
        carried = {}
        with open(os.path.join(HERE, "..", "sweep4", "weekly_%s.csv" % p)) as f:
            for r in csv.DictReader(f):
                if r["setting"] in grid:
                    carried[(r["setting"], r["week"])] = float(r["net"])
        assert set(dsum) == set(carried) and len(dsum) == 40, p
        n = wins(dsum, carried)
        c = d2_class(n)
        classes.append(c)
        weeks = sorted({k[1] for k in dsum})
        sd_d = statistics.median(statistics.pstdev([dsum[(g, w)] for w in weeks]) for g in grid)
        sd_c = statistics.median(statistics.pstdev([carried[(g, w)] for w in weeks]) for g in grid)
        lines.append("| %s | %+.0f | %d of %d | %+.0f | %d | %s | %.0f / %.0f |" % (
            p.upper(), d1, sum(1 for x in med_day if x > 0), len(days), live, n, c, sd_d, sd_c))
    lines += ["", "- D1: %d of 9 pairs positive over 40 days (median of the 5 grid settings)." % d1pos,
              "- D2: BETTER %d, NO DIFFERENCE %d, WORSE %d -> daily-flat %s carrying the week." % (
                  classes.count("BETTER"), classes.count("NO DIFFERENCE"), classes.count("WORSE"),
                  "BEATS" if beats_carrying(classes) else "does NOT beat")]
    txt = "\n".join(lines) + "\n"
    with open(os.path.join(HERE, "marks.md"), "w", newline="\n") as f:
        f.write(txt)
    print(txt)


if __name__ == "__main__":
    main(sys.argv[1])
