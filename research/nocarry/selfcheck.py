"""Self-checks a, c, d, e of research/nocarry/PREREG.md s5 (b is test_nocarry.py), run BEFORE any result is read.

    python research/nocarry/selfcheck.py <bars dir> <run dir>

Reads only: the CONT JSON in run_bars.py's format (a), the per-tick layer / order / balance arrays of DAY and WEEK
(c), each split's parts (d), and one week of GBPUSD OPT under DAY (e). Prints no totals."""
import datetime as dt
import filecmp
import hashlib
import json
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import run_nocarry as rn  # noqa: E402

PAIRS = ("AUDCAD", "AUDCHF", "CADCHF", "EURGBP", "EURUSD", "GBPUSD")
RUNS = [("DAY", ""), ("WEEK", ""), ("DAY", "_w05"), ("WEEK", "_w05")]


def sha16(p):
    return hashlib.sha256(open(p, "rb").read()).hexdigest()[:16]


def check_a(out):
    ref = os.path.join(HERE, "..", "longrun", "out_limit")
    bad = 0
    for p in PAIRS:
        a, b = os.path.join(out, "cont_%s.json" % p), os.path.join(ref, "cont_%s.json" % p)
        same = filecmp.cmp(a, b, shallow=False)
        bad += not same
        print("a  %s  %s  %s  %s" % (p, sha16(a), sha16(b), "IDENTICAL" if same else "DIFFERENT"))
    return bad


def check_c(out):
    bad = 0
    for arm, w in RUNS:
        for p in PAIRS:
            z = np.load(os.path.join(out, "%s%s_%s.npz" % (arm, w, p)))
            t = z["t"]
            win = rn.windows(list(t), arm)
            starts = np.searchsorted(t, [s for s, _ in win])
            cuts = np.searchsorted(t, [c for _, c in win])
            flat = np.ones(len(t), dtype=bool)                            # ticks that must be flat
            for k in range(len(win)):
                flat[starts[k]:cuts[k]] = False                           # trading ticks [start, cut)
            v = 0
            for s in ("alt", "opt"):
                v += int(np.count_nonzero(z["lay_" + s][flat]))
                v += int(np.count_nonzero(z["ord_" + s][flat]))
                v += int(np.count_nonzero(z["eq_" + s][flat] != z["bal_" + s][flat]))
                # the balance cannot move between a cut and its restart (no open, no close)
                for k in range(len(win)):
                    a = cuts[k]
                    b = starts[k + 1] if k + 1 < len(win) else len(t)
                    seg = z["bal_" + s][a:b]
                    v += int(np.count_nonzero(seg != seg[0])) if len(seg) else 0
            n_mk = int(np.count_nonzero(flat & (t % 300000 == 0)))
            bad += v > 0
            print("c  %-4s%-4s %s  windows %4d  flat ticks %8d (five-minute marks among them %6d)  violations %d"
                  % (arm, w, p, len(win), int(flat.sum()), n_mk, v))
    return bad


def check_d(out):
    bad = n = 0
    worst = 0.0
    for arm, w in [("CONT", "")] + RUNS:
        for p in PAIRS:
            j = json.load(open(os.path.join(out, "%s%s_%s.json" % (arm, w, p))))
            for g in ("opt_end", "alt_end"):
                s = j[g]
                parts = round(s["scalp"] + s["rolled"] + s["cut"] + s["open"] + s["comm"], 2)
                gap = abs(s["net"] - s["net_unrounded"])
                worst = max(worst, gap)
                n += 1
                bad += (parts != s["net"]) or gap > 0.02
    print("d  %d splits: net = the rounded parts in all; the largest gap to the unrounded total $%.4f; failures %d"
          % (n, worst, bad))
    return bad


def check_e(bars, out):
    tk = rn.load_ticks(bars, "GBPUSD")
    wk = [x for x in tk if rn._week(x[0]) == "2026-10-19"]
    (wo, ao, so), (wa, aa, sa) = rn.run_bars.GEO["GBPUSD"]
    co = rn.sim.Cfg(width=wo, add=ao, exit=ao, cap=7, stranded=so, deadband=2.0)
    ca = rn.sim.Cfg(width=wa, add=aa, exit=aa, cap=7, stranded=sa, deadband=2.0)
    u = rn.run_bars.USD["GBPUSD"]
    r = rn.run_arm(wk, co, ca, "DAY", u)
    bars_at = {}
    with open(os.path.join(bars, "bars_1514878887_GBPUSD.csv")) as f:
        f.readline(); f.readline()
        for row in f:
            x = row.split(",")
            t = int(x[1]) * 1000
            if wk[0][0] <= t <= wk[-1][0]:
                bars_at[t] = (float(x[2]), float(x[2]) + int(x[6]) * 1e-5)
    bad = 0
    print("e  GBPUSD OPT, DAY, 19-23 Oct 2026: every cut close (entry from that day's run; exit against the bar)")
    for (t, name, cs) in r["cuts"]:
        if name != "OPT":
            continue
        bid, ask = bars_at[t]
        for c in sorted(cs, key=lambda c: c.open_ms):
            want = round(bid, 5) if c.side == "L" else round(ask, 5)
            ok = abs(c.exit - want) < 1e-9
            bad += not ok
            pp = rn._pips(c)
            print("e  %s  %s  opened %s at %.5f  cut at %.5f (bar open %s %.5f) %+6.1f pips  $%+.2f  %s"
                  % (dt.datetime.fromtimestamp(t / 1000, dt.timezone.utc).strftime("%a %d %b %H:%M"), c.side,
                     dt.datetime.fromtimestamp(c.open_ms / 1000, dt.timezone.utc).strftime("%H:%M:%S"), c.entry,
                     c.exit, "bid" if c.side == "L" else "ask", want, pp, pp * u - rn.COMM, "ok" if ok else "WRONG"))
    # the week alone equals the full run that week (each day starts flat): the balance's moves tick by tick
    z = np.load(os.path.join(out, "DAY_GBPUSD.npz"))
    i0 = int(np.searchsorted(z["t"], wk[0][0]))
    full = z["bal_opt"][i0:i0 + len(wk)] - (z["bal_opt"][i0 - 1] if i0 else 0.0)
    same = np.allclose(full, r["eq"]["bal_opt"], atol=1e-6) and np.array_equal(z["t"][i0:i0 + len(wk)], r["eq"]["t"])
    bad += not same
    print("e  the week run alone matches the full DAY run's OPT balance tick by tick: %s" % ("yes" if same else "NO"))
    return bad


def main():
    bars, out = sys.argv[1], sys.argv[2]
    fails = {"a": check_a(out), "c": check_c(out), "d": check_d(out), "e": check_e(bars, out)}
    print("SELF-CHECKS: " + ", ".join("%s %s" % (k, "PASS" if v == 0 else "FAIL (%d)" % v) for k, v in fails.items()))


if __name__ == "__main__":
    main()
