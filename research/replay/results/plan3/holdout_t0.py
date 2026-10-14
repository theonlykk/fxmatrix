"""holdout_t0.py -- plan 3 s7's T0 on the holdout (replay-calibration-eurusd-3.md s3), before any run.

T0: a touching tick on the ORDER price for >= 95% of real deals, per fleet; below it STOP.
The same lines as score_plan3.fleet (compare.segments, compare.real_deals with the archive's
order prices, Ticks.touchable(d, "order"), deals at or after the cut), without the runs.
Also printed, not deciding: the whole window from each fleet's init.

    python -B research/replay/results/plan3/holdout_t0.py --inputs research/replay/inputs/eurusd_holdout \
        --ticks ticks_53077984_EURUSD_w2h.csv --archive-b A_B --archive-c A_C --archive-d A_D
"""
import argparse
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
import compare as cp  # noqa: E402

CUT_MS = 1791531120000
MARK = 0.95


def t0(inputs, tag, ticks, archive_rows, cut_ms):
    segs = cp.segments(cp.read_csv(os.path.join(inputs, "run_%s.csv" % tag)))
    real_rows = cp.read_csv(os.path.join(inputs, "real_%s.csv" % tag))
    reals = cp.real_deals(real_rows, segs, cp.order_prices(archive_rows))
    touch = [ticks.touchable(d, "order") for d in reals]
    after = [i for i, r in enumerate(reals) if cut_ms is None or r["t"] >= cut_ms]
    return ({"real": len(after), "touch": sum(1 for i in after if touch[i])},
            {"real": len(reals), "touch": sum(touch)},
            [reals[i] for i in after if not touch[i]])


def main(argv=None):
    ap = argparse.ArgumentParser()
    for a in ("inputs", "ticks", "archive-b", "archive-c", "archive-d"):
        ap.add_argument("--" + a, required=True)
    a = ap.parse_args(argv)
    ticks = cp.Ticks.load(a.ticks)
    ok_all = True
    print("T0 on the ORDER price; scored window from the cut %d (9 Oct 04:32Z); mark >= 95%%" % CUT_MS)
    for f, path in (("B", a.archive_b), ("C", a.archive_c), ("D", a.archive_d)):
        sc, whole, miss = t0(a.inputs, "eurusd_%s" % f.lower(), ticks, cp.read_jsonl(path), CUT_MS)
        frac = sc["touch"] / sc["real"] if sc["real"] else 0.0
        ok = sc["real"] > 0 and frac >= MARK
        ok_all = ok_all and ok
        print("T0|%s|scored %d / %d = %.1f%%|%s|whole window %d / %d" % (
            f, sc["touch"], sc["real"], 100 * frac, "pass" if ok else "STOP", whole["touch"], whole["real"]))
        for d in miss:
            print("  untouched", {k: d[k] for k in sorted(d) if k in ("t", "seg", "side", "role", "layer", "pts", "fill_pts")})
    print("T0|ALL|%s" % ("pass" if ok_all else "STOP"))
    return 0 if ok_all else 1


if __name__ == "__main__":
    sys.exit(main())
