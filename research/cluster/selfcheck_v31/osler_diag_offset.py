"""Osler selfcheck diagnostic (synthetic data ONLY; no real-data statistic is computed).

Question: is the crossing-size false-finding excess (selfcheck 2 of 20) mechanical, or does the
within-day permutation keep real structure at TRUE round numbers? Re-run the same 20 permuted runs
(same seeds, same code) with the round grid replaced by a DUMMY grid offset 25 pips (levels ending
25 / 75). Arbitrary levels are kept 0.0002 x L away from the dummy grid instead.

    python osler_diag_offset.py D:\\fxmatrix\\research\\cluster D:\\fxmatrix-exports\\bars_ftmo D:\\fxmatrix-exports\\osler_diag
"""
import os
import sys

code_dir, data_dir, out_dir = sys.argv[1], sys.argv[2], sys.argv[3]
sys.path.insert(0, code_dir)
import osler  # noqa: E402

OFFSET = 2500  # 25 pips in t10 (tenths of a point)


def dummy_levels(qmin, qmax):
    lo = -(-(int(qmin) - OFFSET) // osler.ROUND_STEP) * osler.ROUND_STEP + OFFSET
    return list(range(lo, int(qmax) + 1, osler.ROUND_STEP))


def dummy_class(level):
    return "R100" if (level - OFFSET) % (2 * osler.ROUND_STEP) == 0 else "R50"


def dummy_draw(rng, qmin, qmax, n):
    out = []
    while len(out) < n:
        x = int(round(rng.uniform(qmin, qmax) / 10.0)) * 10
        if x < qmin or x > qmax:
            continue
        nearest = int(round((x - OFFSET) / osler.ROUND_STEP)) * osler.ROUND_STEP + OFFSET
        if abs(x - nearest) <= 0.0002 * x:
            continue
        out.append(x)
    return out


osler.round_levels = dummy_levels
osler.round_class = dummy_class
osler.draw_arbitrary = dummy_draw

os.makedirs(out_dir, exist_ok=True)
ok, lines, loaded = osler.selfcheck_files(data_dir)
rep = ["DIAG offset grid +%d t10 (levels ending 25 / 75); synthetic runs only" % OFFSET,
       "files: %s" % ("PASS" if ok else "FAIL")] + ["  " + ln for ln in lines]
print("\n".join(rep), flush=True)
if not ok:
    sys.exit(1)
sig = {"rev": 0, "mv15": 0}
for r in range(20):
    syn = osler.permute_within_days(loaded, r)
    del_real = None  # the real series is never passed to run()
    rows, blk = osler.run(syn)
    res = osler.tests(rows, blk)
    line = "run %2d:" % r
    for meas in ("rev", "mv15"):
        hit = any(res[meas][h]["p"] < 0.01 for h in ("H1", "H2"))
        sig[meas] += hit
        line += " %s H1 p=%.4f H2 p=%.4f mean H1 %+.5f H2 %+.5f%s" % (
            meas, res[meas]["H1"]["p"], res[meas]["H2"]["p"],
            res[meas]["H1"]["mean"] or 0.0, res[meas]["H2"]["mean"] or 0.0, " SIG" if hit else "")
    rep.append(line)
    print(line, flush=True)
rep.append("DIAG: reversal significant in %d of 20, crossing size in %d of 20" % (sig["rev"], sig["mv15"]))
print(rep[-1], flush=True)
open(os.path.join(out_dir, "diag_offset.txt"), "w").write("\n".join(rep) + "\n")
