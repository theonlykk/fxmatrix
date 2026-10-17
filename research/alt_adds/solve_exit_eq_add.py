"""ALT's add when ALT's exit = its add (fleet D note s11): the add and the exit depend on each other.

    python research/alt_adds/solve_exit_eq_add.py <archive export .jsonl> [...]

Uses only alt_excursions.py's tested functions (load, anchors, excursion, quantile). For a quantile q,
start from add a0 = q-depth with the pair's OPT exit / (cap - 1), then repeat a <- q-depth with exit a /
(cap - 1) until it moves less than 0.05 pip. The q-depth is the WORSE side's quantile, the larger of the
whole file and the anchors from 9 Oct 00:00Z (the operator's "these last few days"), as in s9.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import alt_excursions as ax  # noqa: E402

SINCE_9_OCT_UTC_MS = 1791504000000
OPT_EXIT = {"EURUSD": 9, "GBPUSD": 9, "EURGBP": 6, "AUDCAD": 9, "AUDCHF": 11, "CADCHF": 11}  # D r3


def depth(pts, exit_pips, q):
    out = 0.0
    for since in (None, SINCE_9_OCT_UTC_MS):
        for side in ("L", "S"):
            ex = [ax.excursion(pts, i, side, exit_pips * ax.PIP)[0]
                  for i in ax.anchors(pts, 3600000) if since is None or pts[i][0] >= since]
            out = max(out, ax.quantile(ex, q))
    return out


def solve(pts, opt_exit, q, cap=7):
    a = depth(pts, opt_exit, q) / (cap - 1)
    for _ in range(50):
        na = depth(pts, a, q) / (cap - 1)
        if abs(na - a) < 0.05:
            return na
        a = na
    return a


def main(argv):
    for f in argv:
        inst = ax.instance_of(f)
        pair = inst.split("_")[1]
        pts = ax.load(f)
        print("%s  q90: %.1f  q95: %.1f" % (inst, solve(pts, OPT_EXIT[pair], 0.90), solve(pts, OPT_EXIT[pair], 0.95)))


if __name__ == "__main__":
    main(sys.argv[1:])
