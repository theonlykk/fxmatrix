"""Hand-checked tests of core.py (run: python test_core.py). Mirrors the cases in the project's test_sim.py
where the idealisations allow, plus null-hypothesis checks on synthetic random walks."""
import numpy as np
from core import steps, ladder, PIP

def run(asks, spread_pts=2, cap=7, add=7.0, width=2.0, stranded=3.0, mode="ba"):
    ask = np.array(asks, float); bid = ask - spread_pts * 1e-5
    n = len(ask)
    tod = np.full(n, 600, np.int64); per = np.zeros(n, np.int64)
    return ladder(bid, ask, tod, per, 1, width, add, add, stranded, 2.0, cap, True, 0, 1)

# 1. L0 fill and scalp (test_sim.test_l0_fill_and_scalp): buy L0 at 1.09981, exit 1.10051 -> +7.0 pips, 1 close
r = run([1.10002, 1.10002, 1.09981, 1.09981, 1.10010, 1.10053, 1.10053, 1.10053])
assert r[2][0] == 1 and abs(r[0][0] - 7.0) < 1e-6, (r[0][0], r[2][0])
# 2. roll at cap 2 (test_sim.test_roll_at_cap_and_rolled_close): rolled close -7.0 pips
r = run([1.10002, 1.10002, 1.09981, 1.09981, 1.09911, 1.09911, 1.09841, 1.09841, 1.09841, 1.09880, 1.09913,
         1.09913, 1.09913], cap=2)
assert r[4][0] == 1 and r[3][0] == 1 and abs(r[7][0] + 7.0) < 1e-6, (r[4][0], r[3][0], r[7][0])
# 3. cap 9 holds nine layers (test_sim.test_cap9_holds_nine)
levels = [round(1.09981 - 0.0007 * k, 5) for k in range(11)]
r = run([1.10002, 1.10002] + [x for lv in levels for x in (lv, lv)], cap=9)
assert r[6][0] >= 9, r[6][0]       # 9 longs (shorts may also have opened on this path? none: price only falls)
# 4. sliding ladder arithmetic: 7 layers, 2 rungs beyond, then bounce 2 rungs: two rolled closes of -6 rungs each
path = [1.10002, 1.10002] + [round(1.09981 - 0.0007 * k, 5) for k in range(9)]       # L0 + 6 adds, then 2 rolls
low = path[-1]
path += [round(low + 0.0007 + 0.00002, 5), round(low + 0.0014 + 0.00002, 5)] * 1
r = run(path, cap=7, width=2.0, stranded=1e9)   # stranded huge: short L0 never re-centres, so shorts stay flat
assert r[4][0] == 2 and r[3][0] == 2 and abs(r[7][0] + 84.0) < 1e-6, (r[4][0], r[3][0], r[7][0])
# 5. null checks on a lattice random walk (+/-0.1 pip steps: no overshoot, so a touched limit is exactly at the
#    market and the martingale null is exact): steps() reversal rate = 0.5, ladder gross = 0.
#    (On a coarsely SAMPLED walk the ladder is biased negative: touches between samples that come back are missed.
#    M1 bars do not have that problem because high and low are true extremes; see 01_null_calibration.py.)
rng = np.random.default_rng(1)
x = 1.1 + np.cumsum(rng.choice(np.array([-1e-5, 1e-5]), 30_000_000))
x = np.round(x, 5)
for a in (3, 7, 23):
    i, d, p = steps(x, a * PIP)
    rev = (d[1:] != d[:-1]).mean()
    assert abs(rev - 0.5) < 4 * 0.5 / np.sqrt(len(d)), (a, rev, len(d))
    print("lattice walk, a=%d: steps=%d reversal rate=%.4f" % (a, len(d), rev))
tod = np.full(len(x), 600, np.int64); per = (np.arange(len(x)) // 500000).astype(np.int64)
for a, w in ((7.0, 2.0), (23.0, 6.0)):
    o = ladder(x, x, tod, per, 60, w, a, a, w + 1, 2.0, 7, True, 0, 1)
    eq = o[0] + o[1]; d = np.diff(np.r_[0.0, eq])
    t = d.mean() / (d.std(ddof=1) / np.sqrt(len(d)))
    print("lattice walk, add %.0f: closes=%d rolled=%d total=%.0f pips, t=%.2f, gross per close %.4f rung"
          % (a, o[2][-1], o[3][-1], eq[-1], t, eq[-1] / o[2][-1] / a))
    assert abs(t) < 3.0
print("all tests passed")
