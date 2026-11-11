"""Null calibration of the M1-bar method on a synthetic lattice random walk (no real data).
A +/-0.1 pip lattice walk is an exact martingale with no overshoot. We (1) run T1 (both node rules) and T3 on the fine path (truth,
expected r = 0.5 and gross = 0), (2) build M1 bid OHLC bars from it, turn them into 4 pseudo-ticks per bar as
run_bars.py does (std) and with high/low swapped (alt), and rerun. The difference bar - fine is the bias the bar
approximation adds under the null. Two volatilities: sigma per bar 1.26 pips (EURUSD-like) and 3.8 pips (fast).
Output: out/01_null_calibration.txt"""
from common import *
from core import steps, steps_grid, ladder

def bars_from(x, k):
    n = len(x) // k
    y = x[:n * k].reshape(n, k)
    return y[:, 0], y.max(1), y.min(1), y[:, -1]

def pticks(o, h, l, c, order):
    up = c >= o
    if order == "alt":
        up = ~up
    n = len(o); p = np.empty(4 * n)
    p[0::4] = o; p[1::4] = np.where(up, l, h); p[2::4] = np.where(up, h, l); p[3::4] = c
    return p

def lad(p, a, blk):
    n = len(p); tod = np.full(n, 600, np.int64); per = (np.arange(n) // blk).astype(np.int64)
    w = round(a / 4, 1)
    o = ladder(p, p, tod, per, per[-1] + 1, w, float(a), float(a), w + 1, 2.0, 7, True, 0, 50)
    eq = o[0] + o[1]
    return eq[-1], o[2][-1]

lines = []
P = lambda s="": (lines.append(s), print(s, flush=True))
rng = np.random.default_rng(7)
for k, nb, lab in ((160, 400_000, "sigma/bar 1.26 pips"), (1440, 60_000, "sigma/bar 3.8 pips")):
    x = np.round(1.1 + np.cumsum(rng.choice(np.array([-1e-5, 1e-5]), k * nb)), 5)
    o, h, l, c = bars_from(x, k)
    P("== %s, %d bars, mean bar range %.2f pips" % (lab, nb, ((h - l) / PIP).mean()))
    P("   a | GRID-node r: fine  bar(std) bar(alt) | actual-node r: fine  bar(std) | grid steps fine/bar | ladder gross per close, rungs: fine  bar(std)  bar(alt) | closes fine/bar")
    for a in (3, 4, 5, 7, 9, 10, 14, 18, 23, 30):
        res = []
        for name, p in (("fine", x), ("std", pticks(o, h, l, c, "std")), ("alt", pticks(o, h, l, c, "alt"))):
            i, d, px = steps(p, a * PIP)
            r_act = (d[1:] != d[:-1]).mean()
            i, d = steps_grid(p, a * PIP)
            r = (d[1:] != d[:-1]).mean()
            tot, cl = lad(p, a, max(len(p) // 40, 1))
            res.append((r, len(d), tot / max(cl, 1) / a, cl, r_act))
        P("  %3d | %.4f  %.4f  %.4f | %.4f  %.4f | %6d/%6d | %+.4f  %+.4f  %+.4f | %6d/%6d" % (a, res[0][0], res[1][0], res[2][0],
          res[0][4], res[1][4], res[0][1], res[1][1], res[0][2], res[1][2], res[2][2], res[0][3], res[1][3]))
    P()
open(os.path.join(OUT, "01_null_calibration.txt"), "w").write("\n".join(lines) + "\n")
