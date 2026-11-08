"""No-carry runner (research/nocarry/PREREG.md): E's t3 OPT and ALT on FTMO M1 bars, CONT / DAY / WEEK.

    python research/nocarry/run_nocarry.py <bars dir> <PAIR> --arm CONT|DAY|WEEK [--worse 0.5] --out <dir>

Writes <dir>/<arm>[_w05]_<PAIR>.json (the end split, month-end series, cut nights) and .npz (per-tick balance and
equity in USD after commission, for the FTMO-day losses of the twelve together: summarise.py). With --arm CONT it
also writes <dir>/cont_<PAIR>.json in run_bars.py's format: self-check a compares it with research/longrun/out_limit.

The engine is research/opt_budget/sim.py with run_bars.py's limit-fill patch (run_bars.load_sim("limit")), unchanged.
The tick loop is sim.run_instances re-written so that the cut (PREREG s3) and the flat windows (s2) can sit in it;
with no window it does exactly what run_instances does (test_cont_reproduces_sim_run_pair, self-check a). The bar
loader is run_bars.main()'s, copied (run_bars has no loader function)."""
import argparse
import csv
import datetime as dt
import json
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "longrun"))
import run_bars  # noqa: E402

sim = run_bars.load_sim("limit")
COMM = run_bars.COMM
DAY_MS = 86400000
CUT_MIN, START_MIN = 23 * 60 + 45, 60          # 23:45 and 01:00 server (PREREG s2)


# ---------------------------------------------------------------- the cut (PREREG s3)
def cut(it, t, bid, ask, worse=0.0):
    """PREREG s3 on one Instance at the cut tick t (after run_events): returns the cut Close records (c.cut = True)."""
    for o in it.orders:                                                   # 1. every resting order removed
        if o.removed_ms is None:
            o.removed_ms = t
    for sd in it.side.values():
        for o in (sd.l0, sd.add):
            if o is not None and o.removed_ms is None:
                o.removed_ms = t
        for l in sd.layers:
            if l.exit_order is not None and l.exit_order.removed_ms is None:
                l.exit_order.removed_ms = t
    out = []
    for s, sd in it.side.items():
        for l in sorted(sd.layers, key=lambda x: x.idx):
            if l.closing and l.exit_fill is not None:                     # 2. a dealt exit: a normal close
                it.closes.append(sim.Close(side=s, entry=l.entry, exit=l.exit_fill, rolled=l.vl is not None,
                                           open_ms=l.open_ms, close_ms=t, swap_pips=l.swap_pips,
                                           depth_open=l.depth_open))
                continue
            if sd.is_long:                                                # 3. a cut close at the quote
                px = sim.r5(bid - worse * sim.PIP)
            else:
                px = sim.r5(ask + worse * sim.PIP)
            c = sim.Close(side=s, entry=l.entry, exit=px, rolled=False, open_ms=l.open_ms, close_ms=t,
                          swap_pips=l.swap_pips, depth_open=l.depth_open)
            c.cut = True
            it.closes.append(c)
            out.append(c)
        sd.layers = []                                                    # 4. the resets
        sd.l0 = sd.add = sd.extreme = None
        sd.track_from = 0
    it.orders = []
    it.events = []
    it.cb_queue = []
    it.busy = 0
    it.ent_sent = False
    return out


# ---------------------------------------------------------------- the windows (PREREG s2)
def _day(ms):
    return ms // DAY_MS


def _minute(ms):
    return (ms % DAY_MS) // 60000


def _week(ms):
    d = dt.datetime.fromtimestamp(ms / 1000, dt.timezone.utc)
    return (d - dt.timedelta(days=d.isoweekday() - 1)).strftime("%Y-%m-%d")


def _start_cut(day_times):
    """(first tick at or after 01:00, first tick at or after 23:45 or the day's last tick) of one server day."""
    st = next((t for t in day_times if _minute(t) >= START_MIN), None)
    ct = next((t for t in day_times if _minute(t) >= CUT_MIN), day_times[-1])
    return st, ct


def windows(times_ms, arm):
    """Trading windows [(start_ms, cut_ms)] for "DAY" / "WEEK" (PREREG s2); "CONT": [(times_ms[0], None)]."""
    if arm == "CONT":
        return [(times_ms[0], None)]
    days = {}
    for t in times_ms:
        days.setdefault(_day(t), []).append(t)
    keys = sorted(days)
    out = []
    if arm == "DAY":
        for k in keys:
            st, ct = _start_cut(days[k])
            if st is not None and st < ct:
                out.append((st, ct))
        return out
    if arm == "WEEK":
        weeks = {}
        for k in keys:
            weeks.setdefault(_week(days[k][0]), []).append(k)
        for w in sorted(weeks):
            ks = weeks[w]
            st = next((s for s in (_start_cut(days[k])[0] for k in ks) if s is not None), None)
            ct = _start_cut(days[ks[-1]])[1]
            if st is not None and st < ct:
                out.append((st, ct))
        return out
    raise ValueError(arm)


# ---------------------------------------------------------------- the loop
class _Book:
    """Running realised pips and close count of one instance (per-tick equity only; marks use sim's own sums)."""

    def __init__(self, it):
        self.it, self.n, self.r = it, 0, 0.0

    def realised(self):
        cs = self.it.closes
        while self.n < len(cs):
            c = cs[self.n]
            self.r += ((c.exit - c.entry) if c.side == "L" else (c.entry - c.exit)) / sim.PIP + c.swap_pips
            self.n += 1
        return self.r


def run_arm(ticks, cfg_opt, cfg_alt, arm, u, worse=0.0, mark_ms=300000):
    """Run ALT and OPT on ticks under the arm. Returns {"opt", "alt", "marks", "cuts", "eq"}; eq holds per-tick
    arrays t, bal_opt, eq_opt, bal_alt, eq_alt in USD after commission, and lay_* / ord_* (open layers, resting
    orders), recorded after each tick."""
    alt = sim.Instance(cfg_alt, "ALT")
    opt = sim.Instance(cfg_opt, "OPT")
    opt.peer, opt.budget, opt.variant = alt, False, "B"
    insts = [alt, opt]                                                    # ALT before OPT, as sim.run_pair
    books = [_Book(alt), _Book(opt)]
    win = windows([tk[0] for tk in ticks], arm)
    n = len(ticks)
    T = np.empty(n, dtype=np.int64)
    B = np.empty((2, n))
    E = np.empty((2, n))
    LAY = np.empty((2, n), dtype=np.int16)
    ORD = np.empty((2, n), dtype=np.int16)
    marks, cuts = [], []
    prev, next_mark, wi = None, None, 0
    for i, tk in enumerate(ticks):
        t, bid, ask = tk
        if prev is None:
            prev = tk
            next_mark = (t // mark_ms + 1) * mark_ms
        while next_mark <= t:
            marks.append((next_mark, [(it.realised_pips(), it.open_pips(prev[1], prev[2]), len(it.closes),
                                       it.open_layers()) for it in insts]))
            next_mark += mark_ms
        while wi < len(win) and win[wi][1] is not None and t > win[wi][1]:
            wi += 1
        if wi < len(win) and t >= win[wi][0]:
            if win[wi][1] is not None and t == win[wi][1]:
                for it in insts:
                    it.run_events(t, prev, tk)
                    it.bid, it.ask = bid, ask
                for it in insts:
                    cuts.append((t, it.name, cut(it, t, bid, ask, worse)))
                wi += 1
            else:
                for it in insts:
                    it.run_events(t, prev, tk)
                    it.bid, it.ask = bid, ask
                    it.broker(t, True)
                for it in insts:
                    it.on_tick(t)
        T[i] = t
        for j, (it, bk) in enumerate(zip(insts, books)):
            bal = bk.realised() * u - COMM * bk.n
            B[j, i] = bal
            E[j, i] = bal + it.open_pips(bid, ask) * u
            LAY[j, i] = it.open_layers()
            ORD[j, i] = sum(1 for o in it.orders if o.removed_ms is None or o.removed_ms > t)
        prev = tk
    if prev is not None:
        marks.append((prev[0], [(it.realised_pips(), it.open_pips(prev[1], prev[2]), len(it.closes),
                                 it.open_layers()) for it in insts]))
    eq = {"t": T, "bal_alt": B[0], "eq_alt": E[0], "bal_opt": B[1], "eq_opt": E[1],
          "lay_alt": LAY[0], "lay_opt": LAY[1], "ord_alt": ORD[0], "ord_opt": ORD[1]}
    return {"opt": opt, "alt": alt, "marks": marks, "cuts": cuts, "eq": eq}


# ---------------------------------------------------------------- measures (PREREG s4)
def combine(parts):
    """parts: [(t, bal, eq)] numpy arrays; the union time grid, each part held at its last value (0 before its first
    tick). Returns (t, bal, eq) summed."""
    t = parts[0][0]
    for p in parts[1:]:
        t = np.union1d(t, p[0])
    bal = np.zeros(len(t))
    eq = np.zeros(len(t))
    for pt, pb, pe in parts:
        k = np.searchsorted(pt, t, side="right") - 1
        have = k >= 0
        bal[have] += np.asarray(pb, dtype=float)[k[have]]
        eq[have] += np.asarray(pe, dtype=float)[k[have]]
    return t, bal, eq


def day_losses(t_ms, bal, eq):
    """FTMO days, key (t - 3,600,000) // 86,400,000: {key: (start balance, lowest equity, loss)} (PREREG s4)."""
    keys = (np.asarray(t_ms, dtype=np.int64) - 3600000) // DAY_MS
    out = {}
    start_bal = 0.0
    i, n = 0, len(keys)
    while i < n:
        j = i
        while j < n and keys[j] == keys[i]:
            j += 1
        lo = float(np.min(eq[i:j]))
        out[int(keys[i])] = (float(start_bal), lo, float(round(max(0.0, start_bal - lo), 2)))
        start_bal = float(bal[j - 1])
        i = j
    return out


def win_neg(E, k):
    """(windows with E[i] - E[i-k] < 0, windows) over i = k .. len(E) - 1."""
    return sum(1 for i in range(k, len(E)) if E[i] - E[i - k] < 0), max(0, len(E) - k)


def _pips(c):
    return ((c.exit - c.entry) if c.side == "L" else (c.entry - c.exit)) / sim.PIP


def split(it, u, bid, ask):
    """The end split of one instance in USD (PREREG s4)."""
    cut_c = [c for c in it.closes if getattr(c, "cut", False)]
    rest = [c for c in it.closes if not getattr(c, "cut", False)]
    sc = sum(_pips(c) for c in rest if not c.rolled)
    rc = sum(_pips(c) for c in rest if c.rolled)
    cc = sum(_pips(c) for c in cut_c)
    s = {"scalp": round(sc * u, 2), "rolled": round(rc * u, 2), "cut": round(cc * u, 2),
         "open": round(it.open_pips(bid, ask) * u, 2), "comm": round(-COMM * len(it.closes), 2)}
    s["net"] = round(s["scalp"] + s["rolled"] + s["cut"] + s["open"] + s["comm"], 2)
    s["net_unrounded"] = (sc + rc + cc + it.open_pips(bid, ask)) * u - COMM * len(it.closes)
    v = sorted(_pips(c) for c in cut_c)
    s.update({"n_closes": len(it.closes), "n_cut": len(cut_c), "n_cut_loss": sum(1 for x in v if x <= 0),
              "med_cut_pips": v[len(v) // 2] if v else None, "rolls": it.rolls, "layers": it.open_layers()})
    return s


def decide(base, sens):
    """PREREG s6 on {"net", "years", "neg12", "n12", "days500"} for the base run and the 0.5 pip sensitivity."""
    def label(x):
        edge = x["net"] > 0 and sum(1 for y in x["years"] if y > 0) >= 3 and 2 * x["neg12"] < x["n12"]
        if not edge:
            return "NO EDGE"
        return "EDGE WITHOUT CARRY" if x["days500"] <= 4 else "EDGE, NOT FTMO-SAFE"
    b = label(base)
    if b == "NO EDGE":
        return b
    return b if label(sens) == b else "FRAGILE"


# ---------------------------------------------------------------- the bars and the command line
def load_ticks(data, pair):
    """run_bars.main()'s loader, unchanged in effect: weekdays only, weeks under 4,000 bars skipped, four ticks a bar."""
    weeks = {}
    with open(os.path.join(data, "bars_1514878887_%s.csv" % pair)) as f:
        f.readline(); f.readline()
        for row in csv.reader(f):
            t = int(row[1]); o, h, l, c = map(float, row[2:6]); sp = int(row[6]) * 1e-5
            d = dt.datetime.fromtimestamp(t, dt.timezone.utc)
            if d.isoweekday() > 5:
                continue
            wk = (d - dt.timedelta(days=d.isoweekday() - 1)).strftime("%Y-%m-%d")
            weeks.setdefault(wk, []).append((t, o, h, l, c, sp))
    tk = []
    for k in sorted(weeks):
        if len(weeks[k]) < 4000:
            continue
        for (t, o, h, l, c, sp) in weeks[k]:
            for j, p in enumerate([o, l, h, c] if c >= o else [o, h, l, c]):
                tk.append((t * 1000 + j * 15000, round(p, 5), round(p + sp, 5)))
    return tk


def legacy_json(pair, r, tk):
    """run_bars.py's output, built the same way (CONT only: self-check a)."""
    u = run_bars.USD[pair]

    def pips(c):
        return ((c.exit - c.entry) if c.side == "L" else (c.entry - c.exit)) / sim.PIP

    def split_rb(it):
        sc = sum(pips(c) for c in it.closes if not c.rolled)
        rc = sum(pips(c) for c in it.closes if c.rolled)
        return {"scalp": round(sc * u, 2), "rolled": round(rc * u, 2), "open": round(it.open_pips(tk[-1][1], tk[-1][2]) * u, 2),
                "comm": round(-COMM * len(it.closes), 2), "layers": it.open_layers()}

    def holds(it):
        win = [(c.close_ms - c.open_ms) / 3.6e6 for c in it.closes if pips(c) > 0]
        los = [(c.close_ms - c.open_ms) / 3.6e6 for c in it.closes if pips(c) <= 0]
        med = lambda v: sorted(v)[len(v) // 2] if v else None
        ages = [(tk[-1][0] - l.open_ms) / 3.6e6 for sd in it.side.values() for l in sd.layers]
        return {"n_win": len(win), "n_loss": len(los), "med_h_win": med(win), "med_h_loss": med(los),
                "mean_h_win": sum(win) / len(win) if win else None, "mean_h_loss": sum(los) / len(los) if los else None,
                "open_ages_h": sorted(round(x) for x in ages)}
    months = {}
    for (t, vals) in r["marks"]:
        months[dt.datetime.fromtimestamp(t / 1000, dt.timezone.utc).strftime("%Y-%m")] = vals
    series = []
    for m, vals in sorted(months.items()):
        (ra, oa, na, la), (ro, oo, no, lo) = vals
        series.append({"m": m, "opt_real": round(ro * u - COMM * no, 2), "opt_open": round(oo * u, 2), "opt_layers": lo,
                       "alt_real": round(ra * u - COMM * na, 2), "alt_open": round(oa * u, 2), "alt_layers": la})
    return json.dumps({"pair": pair, "series": series, "opt_end": split_rb(r["opt"]), "alt_end": split_rb(r["alt"]),
                       "opt_hold": holds(r["opt"]), "alt_hold": holds(r["alt"])})


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("data")
    ap.add_argument("pair", choices=sorted(run_bars.GEO))
    ap.add_argument("--arm", choices=("CONT", "DAY", "WEEK"), required=True)
    ap.add_argument("--worse", type=float, default=0.0)
    ap.add_argument("--out", required=True)
    a = ap.parse_args()
    tk = load_ticks(a.data, a.pair)
    (wo, ao, so), (wa, aa, sa) = run_bars.GEO[a.pair]
    co = sim.Cfg(width=wo, add=ao, exit=ao, cap=7, stranded=so, deadband=2.0)
    ca = sim.Cfg(width=wa, add=aa, exit=aa, cap=7, stranded=sa, deadband=2.0)
    u = run_bars.USD[a.pair]
    r = run_arm(tk, co, ca, a.arm, u, a.worse)
    tag = "%s%s_%s" % (a.arm, "_w%02d" % round(a.worse * 10) if a.worse else "", a.pair)
    os.makedirs(a.out, exist_ok=True)
    if a.arm == "CONT" and not a.worse:
        with open(os.path.join(a.out, "cont_%s.json" % a.pair), "w", newline="\n") as f:
            f.write(legacy_json(a.pair, r, tk) + "\n")
    months = {}
    for (t, vals) in r["marks"]:
        months[dt.datetime.fromtimestamp(t / 1000, dt.timezone.utc).strftime("%Y-%m")] = vals
    series = []
    for m, vals in sorted(months.items()):
        (ra, oa, na, la), (ro, oo, no, lo) = vals
        series.append({"m": m, "opt_real": round(ro * u - COMM * no, 2), "opt_open": round(oo * u, 2), "opt_layers": lo,
                       "alt_real": round(ra * u - COMM * na, 2), "alt_open": round(oa * u, 2), "alt_layers": la})
    nights = {}
    for (t, name, cs) in r["cuts"]:
        v = nights.setdefault(t, {"t": t, "n": 0, "usd": 0.0})
        v["n"] += len(cs)
        v["usd"] += sum(_pips(c) * u - COMM for c in cs)
    nv = sorted(round(v["usd"], 2) for v in nights.values() if v["n"])
    out = {"pair": a.pair, "arm": a.arm, "worse": a.worse, "u": u, "series": series,
           "opt_end": split(r["opt"], u, tk[-1][1], tk[-1][2]), "alt_end": split(r["alt"], u, tk[-1][1], tk[-1][2]),
           "cut_nights": len(nv), "med_cut_night_usd": nv[len(nv) // 2] if nv else None}
    with open(os.path.join(a.out, tag + ".json"), "w", newline="\n") as f:
        f.write(json.dumps(out) + "\n")
    np.savez(os.path.join(a.out, tag + ".npz"), **r["eq"])


if __name__ == "__main__":
    main()
