"""score9.py -- the sweep9 scorer (sweep_notes sweep9; docs/research/two-arm-viability-2026-10-21.md s5).

Per segment (one geometry, one flat start, the book carried): a DAILY equity curve in pips at 0.01 lots,
equity(T) = sum over positions opened by T of dir x (close or mark - open) - comm x scalps closed by T + swap by T,
each position closed at its own OUT / OUT_BY deal's price (a close-by closes both legs at one price), open ones
marked at the last tick before T (long at bid, short at ask); swap at each CARRY_SNAPSHOT on the positions open then
(swap_long / swap_short x multiplier points; 10 points a pip). Day ends = server midnights inside the window, then
the window's end. Then the offset ratio of every other geometry against the OPT geometry on OPT's losing days, over
the period and per burst (1-7 Oct, 14-16 Oct), and the pass mark (>= 0.25 and > 0 in both bursts).

  python -B score9.py --runs <dir of run_sw9_*.csv> --outs <dir of out_sw9_*_free_{deals,events}.csv>
                      --ticks <w2hw ticks csv> --opt a7e7n7 --out <report.md> [--csv <curves.csv>]
"""
import argparse
import bisect
import csv
import datetime as dt
import glob
import json
import os
import sys

sys.path.insert(0, os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")))
import compare as cmp  # noqa: E402

DAY_MS = 86400000
PTS = 100000.0           # EURUSD price units per point x 10 = per pip: (price diff) x 10000 = pips
COMM = 0.6               # pips a close at 0.01 lots (0.06 USD / 0.10 USD a pip)
BURSTS = {"b1": ("2026-10-01", "2026-10-07"), "b2": ("2026-10-14", "2026-10-16")}


def read_csv(path):
    with open(path, encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(line for line in f if not line.startswith("#")))


def positions(deals):
    """seg -> list of [dir, open_ms, open_px, close_ms or None, close_px or None, weight of the close]."""
    by = {}
    for d in deals:
        seg, pid, t = int(d["seg_id"]), d["position"], int(d["time_ms"])
        px, entry, dtype = float(d["price"]), int(d["entry_type"]), int(d["deal_type"])
        p = by.setdefault(seg, {})
        if entry == 0:
            p[pid] = [1 if dtype == 0 else -1, t, px, None, None, 1.0]
        elif pid in p and p[pid][3] is None:
            # an OUT_BY leg carries the OTHER position's entry price (02_TRAPS): both legs of a close-by then book
            # the whole pair's P&L, so each counts half; a close at market (OUT) counts in full
            p[pid][3], p[pid][4], p[pid][5] = t, px, (0.5 if entry == 3 else 1.0)
    return {s: list(v.values()) for s, v in by.items()}


def equity_at(pos, scalp_times, snaps, t, mark, comm=COMM):
    """Pips at time t. snaps: (time_ms, swap_long, swap_short, multiplier) in points."""
    eq = 0.0
    mk = None
    for d, o_ms, o_px, c_ms, c_px, w in pos:
        if o_ms > t:
            continue
        if c_ms is not None and c_ms <= t:
            eq += w * d * (c_px - o_px) * 10000.0
        else:
            if mk is None:
                mk = mark(t)
            px = mk[0] if d == 1 else mk[1]
            eq += d * (px - o_px) * 10000.0
    eq -= comm * sum(1 for s in scalp_times if s <= t)
    for s_ms, sl, ss, mult in snaps:
        if s_ms > t:
            continue
        for d, o_ms, _o, c_ms, _c, _w in pos:
            if o_ms <= s_ms and (c_ms is None or c_ms > s_ms):
                eq += (sl if d == 1 else ss) * mult / 10.0
    return eq


def day_ends(from_ms, to_ms):
    ends = []
    t = (from_ms // DAY_MS + 1) * DAY_MS
    while t < to_ms:
        ends.append(t)
        t += DAY_MS
    ends.append(to_ms)
    return ends


def daily(curve):
    return [b - a for a, b in zip(curve, curve[1:])]


def offset_ratio(opt, alt, days=None):
    idx = range(len(opt)) if days is None else days
    lose = [i for i in idx if opt[i] < 0]
    if not lose:
        return None
    return sum(alt[i] for i in lose) / -sum(opt[i] for i in lose)


def meaningful(r_all, r_b1, r_b2):
    return (r_all is not None and r_b1 is not None and r_b2 is not None
            and r_all >= 0.25 and r_b1 > 0 and r_b2 > 0)


def _date(ms):
    return dt.datetime.fromtimestamp((ms - 1) // 1000, dt.timezone.utc).strftime("%Y-%m-%d")


def burst_days(ends):
    """Indices of daily P&L entries (day i = ends[i-1]..ends[i], day 0 from the start) by burst, by the server
    calendar date of each day's end minus 1 ms."""
    out = {}
    for b, (lo, hi) in BURSTS.items():
        out[b] = [i for i, e in enumerate(ends) if lo <= _date(e) <= hi]
    return out


class Ticks:
    def __init__(self, path):
        self.t, self.b, self.a = [], [], []
        with open(path, encoding="utf-8-sig") as f:
            head = None
            for line in f:
                if line.startswith("#") or not line.strip():
                    continue
                parts = line.strip().split(",")
                if head is None:
                    head = parts
                    it, ib, ia = head.index("time_msc_server"), head.index("bid"), head.index("ask")
                    continue
                self.t.append(int(parts[it]))
                self.b.append(float(parts[ib]))
                self.a.append(float(parts[ia]))

    def mark(self, t):
        i = bisect.bisect_left(self.t, t) - 1
        return (self.b[i], self.a[i]) if i >= 0 else None


def load_run(run_csv, deals_csv, events_csv):
    segs = {int(r["seg_id"]): r for r in read_csv(run_csv)}
    names = {}
    for r in segs.values():
        names[int(r["seg_id"])] = "a%se%sn%s" % (_g(r["add_l"]), _g(r["exit_l"]), r["cap"])
    pos = positions(read_csv(deals_csv))
    scalps, snaps, counts = {}, {}, {}
    for e in cmp.read_events(events_csv):
        seg = int(e["seg_id"])
        c = counts.setdefault(seg, {"S": 0, "R": 0, "A": 0})
        if e["code"] == "SCALP_CLOSED":
            j = json.loads(e["json"])
            c["R" if j["rolled"] else "S"] += 1
            scalps.setdefault(seg, []).append(int(e["time_ms"]))
        elif e["code"] == "ROLL_ACCEPTED":
            c["A"] += 1
        elif e["code"] == "CARRY_SNAPSHOT":
            dj = json.loads(e["json"])["detail"]
            snaps.setdefault(seg, []).append((int(e["time_ms"]), float(dj["swap_long"]), float(dj["swap_short"]),
                                              int(dj["multiplier"])))
    return segs, names, pos, scalps, snaps, counts


def _g(x):
    v = float(x)
    return ("%d" % v) if v == int(v) else ("%g" % v)


def score_all(run_files, outs, ticks):
    curves, info = {}, {}
    for rf in run_files:
        tag = os.path.basename(rf)[4:-4]
        segs, names, pos, scalps, snaps, counts = load_run(
            rf, os.path.join(outs, "out_%s_free_deals.csv" % tag), os.path.join(outs, "out_%s_free_events.csv" % tag))
        for seg, r in segs.items():
            ends = day_ends(int(r["from_ms"]), int(r["to_ms"]))
            p, sc, sn = pos.get(seg, []), scalps.get(seg, []), snaps.get(seg, [])
            pts = [0.0] + [equity_at(p, sc, sn, e, ticks.mark) for e in ends]
            name = names[seg]
            curves[name] = pts
            c = counts.get(seg, {"S": 0, "R": 0, "A": 0})
            info[name] = dict(c, net=pts[-1], worst=min(pts), ends=ends, snaps=len(sn),
                              open_n=sum(1 for x in p if x[3] is None))
    return curves, info


def report(curves, info, opt):
    ends = info[opt]["ends"]
    bi = burst_days(ends)
    od = daily(curves[opt])
    lines = ["# sweep9 scored (score9.py): EURUSD 1-20 Oct, one flat start carried; pips at 0.01 lots", "",
             "OPT = %s: net %+.1f, worst equity %+.1f, S %d, R %d, A %d" % (
                 opt, info[opt]["net"], info[opt]["worst"], info[opt]["S"], info[opt]["R"], info[opt]["A"]), "",
             "Self-check: CARRY_SNAPSHOT per segment min %d, max %d (server nights in the window: %d; fewer = swap "
             "under-counted)" % (min(i["snaps"] for i in info.values()), max(i["snaps"] for i in info.values()),
                                 len(ends) - 1), "",
             "| geometry | S | R | A | S / A | net | worst | offset (period) | burst 1 | burst 2 | 2 x (DUP) | MEANINGFUL |",
             "|---|---|---|---|---|---|---|---|---|---|---|---|"]
    for name in sorted(curves, key=lambda n: _key(n)):
        i = info[name]
        ad = daily(curves[name])
        r, r1, r2 = offset_ratio(od, ad), offset_ratio(od, ad, bi["b1"]), offset_ratio(od, ad, bi["b2"])
        sa = ("%.1f" % (i["S"] / i["A"])) if i["A"] else "-"
        f = lambda x: "-" if x is None else "%+.2f" % x
        lines.append("| %s | %d | %d | %d | %s | %+.1f | %+.1f | %s | %s | %s | %s | %s |" % (
            name, i["S"], i["R"], i["A"], sa, i["net"], i["worst"], f(r), f(r1), f(r2),
            f(None if r is None else 2 * r), "YES" if (name != opt and meaningful(r, r1, r2)) else ""))
    return "\n".join(lines) + "\n"


def _key(n):
    a, rest = n[1:].split("e")
    e, c = rest.split("n")
    return (int(c), float(e), float(a))


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--runs", required=True)
    ap.add_argument("--outs", required=True)
    ap.add_argument("--ticks", required=True)
    ap.add_argument("--opt", default="a7e7n7")
    ap.add_argument("--out", required=True)
    ap.add_argument("--csv")
    a = ap.parse_args(argv)
    runs = sorted(glob.glob(os.path.join(a.runs, "run_sw9_*.csv")))
    curves, info = score_all(runs, a.outs, Ticks(a.ticks))
    with open(a.out, "w", newline="\n") as f:
        f.write(report(curves, info, a.opt))
    if a.csv:
        with open(a.csv, "w", newline="\n") as f:
            w = csv.writer(f)
            ends = info[a.opt]["ends"]
            w.writerow(["geometry", "start"] + [_date(e) for e in ends])
            for name in sorted(curves, key=_key):
                w.writerow([name] + ["%.1f" % x for x in curves[name]])
    return 0


if __name__ == "__main__":
    sys.exit(main())
