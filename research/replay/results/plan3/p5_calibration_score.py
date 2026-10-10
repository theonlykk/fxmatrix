"""Plan 3 P5: the calibration window (all 29 segments, free runs at 145f092) scored under
plan 3 s3's C, B and D marks with 6-day tolerances. Reads compare.py's report.md (T2 per
segment and side) and live_spread's n = 6 output. Seen data: a check, not evidence.
usage: python -I p5_calibration_score.py REPORT_MD LIVE_SPREAD_N6_TXT"""
import collections, sys
rows, sec = [], False
for line in open(sys.argv[1]):
    if line.startswith("## T2 per segment and side"): sec = True; continue
    if sec and line.startswith("## "): break
    c = [x.strip() for x in line.strip().strip("|").split("|")]
    if sec and len(c) == 5 and c[1].isdigit():
        rows.append((c[0], c[2], [float(x) for x in c[3].split(" / ")], [float(x) for x in c[4].split(" / ")]))
tot = collections.defaultdict(lambda: [0.0] * 6)
for f, side, r, p in rows:
    t = tot[(f, side)]
    for i in range(3): t[2 * i] += r[i]; t[2 * i + 1] += p[i]
tol = {}
for line in open(sys.argv[2]):
    p = line.split()
    if len(p) > 3 and p[0] in "BCD" and len(p[0]) == 1: tol[(p[0], p[1], p[2])] = float(line.split("tol")[1])
out, beyond, sgn, se, sr = 0, 0, [], 0.0, 0.0
for (f, s) in sorted(tot):
    t = tot[(f, s)]; e = {"S": t[1] - t[0], "R": t[3] - t[2], "A": t[5] - t[4]}
    bad = [k for k in e if abs(e[k]) > tol[(f, s, k)]]; out += bool(bad)
    beyond += sum(abs(e[k]) > 2 * tol[(f, s, k)] for k in e)
    sgn.append(e["S"]); se += e["S"]; sr += t[0]
    print(f, s, "S %d/%d R %d/%d A %d/%d" % tuple(t), " ".join("%s %+d tol %.2f" % (k, e[k], tol[(f, s, k)]) for k in e), "OUT " + ",".join(bad) if bad else "ok")
print("C: sides OUT", out, "beyond 2x tol", beyond, "->", "FAIL" if out >= 2 or beyond else "pass")
one = all(x > 0 for x in sgn) or all(x < 0 for x in sgn)
print("B: S errors", [int(x) for x in sgn], "one sign", one, "sum %+d of %d (%+.1f%%) ->" % (se, sr, 100 * se / sr), "FAIL" if one and abs(se) > 0.05 * sr else "pass")
for side in "LS":
    for k, i in (("S", 0), ("R", 2)):
        for x in "CD":
            live = tot[(x, side)][i] - tot[("B", side)][i]; rep = tot[(x, side)][i + 1] - tot[("B", side)][i + 1]
            lim = max(tol[(x, side, k)], tol[("B", side, k)])
            bad = abs(live) > lim and (rep == 0 or (rep > 0) != (live > 0))
            print("D: %s %s %s-B live %+d replay %+d (limit %.2f) %s" % (side, k, x, live, rep, lim, "FAIL" if bad else "ok"))
