"""extras.py -- sweep7, 12-13 Oct night, AFTER the pre-registered marks (reported, never deciding;
docs/research/grid-edge-assessment-2026-10-12.md s3, s7).

(1) A's seven pairs (live geometry, carried from 3 Aug): closed P&L (realised - commission) and
    equity in dollars at 0.01 lots at the end of each server day.
(2) Each pair's roll closes as a multiple of the roll step D = N x add: (loss + e) / D, rounded to
    0.5; and the ROLL_ACCEPTED count split into rolls and re-rolls (a re-rolled ticket carries
    several steps of loss when it closes).
(3) The chop ratio rho counted by roll CLOSES, (S + R) e / (R D) (compare.rho, the form in
    grid-as-variance-trade.md s11), against rho counted by roll STEPS, (S + R) e / (A D), with and
    without the open book at the end (its loss added to the steps' cost). Each roll step costs D
    and each rolled close gives back e, so on a random walk S e + R e = A D: rho by steps is 1.
    Counted by closes, rho is too high whenever re-rolls bundle steps on one ticket.

  python -B extras.py <dir with out_sw7_<pair>_free_events.csv and the h8w ticks>   (writes extras.md)
"""
import collections
import csv
import datetime as dt
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", ".."))
import analyse as an  # noqa: E402
import compare as cmp  # noqa: E402
import sweep as sw  # noqa: E402

FROM_MS, TO_MS = 1785715200000, 1790379900000


def daily_a7(d):
    daily = collections.defaultdict(dict)
    for p in an.A_PAIRS:
        st = sw.get_set("sw7_" + p)
        u = st["pip_usd"]
        fl = an.fills_by_seg(cmp.read_events(os.path.join(d, "out_sw7_%s_free_events.csv" % p)))[1]
        path = an.Path(fl, st["comm_pips"])
        for t, b, a in an.stream_ticks(os.path.join(d, st["ticks"])):
            if FROM_MS <= t < TO_MS:
                path.on_tick(t, b, a)
                day = dt.datetime.fromtimestamp(t / 1000, dt.timezone.utc).strftime("%Y-%m-%d")
                daily[day][p] = ((path.realised - path.comm) * u, path.last_equity * u)
    last, rows = {}, []
    for day in sorted(daily):
        last.update(daily[day])
        rows.append((day, sum(v[0] for v in last.values()), sum(v[1] for v in last.values())))
    return rows


def roll_multiples(d, pair):
    st = sw.get_set("sw7_" + pair)
    g = st["geoms"][0]
    e, D = g[2], g[3] * g[1]
    mult, acc = collections.Counter(), collections.Counter()
    for r in cmp.read_events(os.path.join(d, "out_sw7_%s_free_events.csv" % pair)):
        if r["seg_id"] != "1":
            continue
        if r["code"] == "SCALP_CLOSED":
            j = json.loads(r["json"])
            if j["rolled"]:
                loss = -sw.scalp_pips(j["direction"], j["entry_price"], j["exit_price"])
                mult[round((loss + e) / D * 2) / 2] += 1
        elif r["code"] == "ROLL_ACCEPTED":
            j = json.loads(r["json"])
            acc["reroll" if (j.get("detail") or j).get("reroll") else "roll"] += 1
    return D, mult, acc


def main(d):
    L = ["# sweep7 extras (after the marks; reported, never deciding)", "",
         "## (1) A's seven pairs, live geometry, carried from 3 Aug: dollars at 0.01 lots, end of each server day", "",
         "| day | closed (realised - commission) | equity |", "|---|---|---|"]
    rows = daily_a7(d)
    L += ["| %s | %+.0f | %+.0f |" % r for r in rows]
    eq = [r[2] for r in rows]
    ch = sorted(eq[i + 4] - eq[i] for i in range(len(eq) - 4))
    L += ["", "Four-day equity changes: n %d, min %+.0f, median %+.0f, max %+.0f." % (len(ch), ch[0], ch[len(ch) // 2], ch[-1]), "",
          "## (2) Roll closes as multiples of the roll step D, (loss + e) / D; roll acceptances", "",
          "| pair | D | closes by multiple | accepted: rolls / re-rolls |", "|---|---|---|---|"]
    for p in an.PAIRS:
        D, m, acc = roll_multiples(d, p)
        L.append("| %s | %g | %s | %d / %d |" % (p.upper(), D, ", ".join("%gx: %d" % kv for kv in sorted(m.items())),
                                                 acc["roll"], acc["reroll"]))
    L += ["", "## (3) The chop ratio rho: by roll closes (as compare.rho) against by roll steps", "",
          "| pair | S | R (closes) | A (steps) | rho by closes | rho by steps | by steps, open book counted | noise ~1/sqrt(A) |",
          "|---|---|---|---|---|---|---|---|"]
    with open(os.path.join(HERE, "summary.csv"), newline="") as f:
        for r in csv.DictReader(f):
            if r["setting"] != "live":
                continue
            g = sw.get_set("sw7_" + r["pair"])["geoms"][0]
            e, D = g[2], g[3] * g[1]
            S, R, A, op = int(r["S"]), int(r["R"]), int(r["A"]), float(r["open"])
            L.append("| %s | %d | %d | %d | %.2f | %.2f | %.2f | %.2f |" % (
                r["pair"].upper(), S, R, A, (S + R) * e / (R * D), (S + R) * e / (A * D),
                (S + R) * e / (A * D + max(0.0, -op)), 1 / math.sqrt(A)))
    txt = "\n".join(L) + "\n"
    with open(os.path.join(HERE, "extras.md"), "w", newline="\n") as f:
        f.write(txt)
    print(txt)


if __name__ == "__main__":
    main(sys.argv[1])
