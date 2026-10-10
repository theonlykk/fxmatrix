"""score_plan3.py -- plan 3's marks (docs/research/replay-calibration-eurusd-3.md s3).

For each fleet: T0 and T1 (SYNC, matched as compare.py over ALL deals, counted after the
cut) and the FREE run's counts per side after the cut: S (scalps, rolled false), R (scalps,
rolled true), A (ROLL_ACCEPTED). Then the count, bias and difference marks and the
scoreable rule over the three fleets. Read-only, standard library + compare.py.

usage: python -I score_plan3.py --inputs DIR --runs DIR --harness SHA7 --ticks CSV
           --archive-b F --archive-c F --archive-d F --tol LIVE_SPREAD_TXT [--cut-ms MS] --out FILE
(--cut-ms omitted: every deal counts, as for the calibration window, plan 3 P5.)
"""
import argparse
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import compare as cp  # noqa: E402

FLEETS = "BCD"
SIDES = "LS"
KINDS = "SRA"
MIN_REAL_S = 10
MIN_SCOREABLE = 4
BIAS_FRACTION = 0.05


# ---------------------------------------------------------------- pure parts (tested)

def side_counts(scalps, rolls, cut_ms=None):
    """{side: {S, R, A}} over items with t >= cut_ms (all when cut_ms is None)."""
    out = {s: {"S": 0, "R": 0, "A": 0} for s in SIDES}
    for x in scalps:
        if cut_ms is None or x["t"] >= cut_ms:
            out[x["side"]]["R" if x["rolled"] else "S"] += 1
    for x in rolls:
        if cut_ms is None or x["t"] >= cut_ms:
            out[x["side"]]["A"] += 1
    return out


def t1_after(reals, replays, touch, cut_ms=None):
    """T1's totals over deals at or after cut_ms; the matching runs over ALL deals."""
    m = cp.match(reals, replays)
    matched_reps = set(m.values())
    after = [i for i, r in enumerate(reals) if cut_ms is None or r["t"] >= cut_ms]
    reps_after = [j for j, p in enumerate(replays) if cut_ms is None or p["t"] >= cut_ms]
    out = {"real": len(after),
           "touch": sum(1 for i in after if touch[i]),
           "matched_touch": sum(1 for i in after if touch[i] and i in m),
           "replay": len(reps_after),
           "replay_only": sum(1 for j in reps_after if j not in matched_reps)}
    out["rate"] = out["matched_touch"] / out["touch"] if out["touch"] else None
    out["pass"] = out["real"] > 0 and not cp._t1_fails(out["real"], out["matched_touch"],
                                                       out["touch"], out["replay_only"])
    return out


def _sign(x):
    return (x > 0) - (x < 0)


def score(counts, tol):
    """counts {(fleet, side): {'real': {S,R,A}, 'rep': {S,R,A}}}; tol {(fleet, side, kind): t}."""
    scoreable = [(f, s) for f in FLEETS for s in SIDES if counts[(f, s)]["real"]["S"] >= MIN_REAL_S]
    out_sides, beyond = [], []
    for f, s in scoreable:
        c = counts[(f, s)]
        out = False
        for k in KINDS:
            err = abs(c["rep"][k] - c["real"][k])
            if err > tol[(f, s, k)]:
                out = True
            if err > 2 * tol[(f, s, k)]:
                beyond.append((f, s, k))
        if out:
            out_sides.append((f, s))
    errs = [counts[fs]["rep"]["S"] - counts[fs]["real"]["S"] for fs in scoreable]
    real_s = sum(counts[fs]["real"]["S"] for fs in scoreable)
    one_sign = bool(errs) and (all(e > 0 for e in errs) or all(e < 0 for e in errs))
    bias_fail = one_sign and abs(sum(errs)) > BIAS_FRACTION * real_s
    diff_fails, diff_rows = [], []
    for s in SIDES:
        for k in ("S", "R"):
            for x in "CD":
                if (x, s) not in scoreable or ("B", s) not in scoreable:
                    continue
                live = counts[(x, s)]["real"][k] - counts[("B", s)]["real"][k]
                rep = counts[(x, s)]["rep"][k] - counts[("B", s)]["rep"][k]
                limit = max(tol[(x, s, k)], tol[("B", s, k)])
                fail = abs(live) > limit and (rep == 0 or _sign(rep) != _sign(live))
                diff_rows.append((s, k, x, live, rep, limit, fail))
                if fail:
                    diff_fails.append((s, k, x))
    if len(scoreable) < MIN_SCOREABLE:
        verdict = "INCONCLUSIVE"
    elif len(out_sides) >= 2 or beyond or bias_fail or diff_fails:
        verdict = "FAIL"
    else:
        verdict = "PASS"
    return {"scoreable": scoreable,
            "counts": {"out_sides": out_sides, "beyond_2x": beyond},
            "bias": {"errors": errs, "sum": sum(errs), "real_s": real_s, "one_sign": one_sign,
                     "fail": bias_fail},
            "difference": {"rows": diff_rows, "fails": diff_fails},
            "verdict": verdict}


# ---------------------------------------------------------------- data (I/O)

def read_tol(path):
    """live_spread.py's output: lines 'B L S daily [...] sd x tol y'."""
    tol = {}
    with open(path) as fh:
        for line in fh:
            p = line.split()
            if len(p) > 3 and p[0] in FLEETS and len(p[0]) == 1 and "tol" in p:
                tol[(p[0], p[1], p[2])] = float(p[p.index("tol") + 1])
    return tol


def real_scalps_t(archive_rows, segs):
    """scalp_history closes inside the segments, de-duplicated as compare.py, with time."""
    seen, out = set(), []
    for r in archive_rows:
        if r.get("table") != "scalp_history":
            continue
        key = tuple(sorted((k, json.dumps(v)) for k, v in r.items() if k not in ("id", "received_at")))
        if key in seen:
            continue
        seen.add(key)
        t = cp._server_ms(r["close_time_broker"])
        if cp.seg_of(t, segs) is None:
            continue
        out.append({"t": t, "side": "L" if r["direction"] == "LONG" else "S", "rolled": bool(r["rolled"])})
    return out


def real_rolls_t(real_rows, segs):
    return [{"t": int(r["time_ms"]), "side": r["side"]} for r in real_rows
            if r["kind"] == "ROLL" and cp.seg_of(int(r["time_ms"]), segs) is not None]


def replay_scalps_t(event_rows):
    out = []
    for r in event_rows:
        if r["kind"] == "scalp" and r["code"] == "SCALP_CLOSED":
            j = json.loads(r["json"])
            out.append({"t": int(r["time_ms"]), "side": "L" if j["direction"] == "LONG" else "S",
                        "rolled": bool(j["rolled"])})
    return out


def replay_rolls_t(event_rows):
    out = []
    for r in event_rows:
        if r["code"] == "ROLL_ACCEPTED":
            j = json.loads(r["json"])
            out.append({"t": int(r["time_ms"]), "side": j["detail"]["side"]})
    return out


def fleet(inputs, runs, harness, tag, ticks, archive_rows, cut_ms):
    segs = cp.segments(cp.read_csv(os.path.join(inputs, "run_%s.csv" % tag)))
    real_rows = cp.read_csv(os.path.join(inputs, "real_%s.csv" % tag))
    reals = cp.real_deals(real_rows, segs, cp.order_prices(archive_rows))
    touch = [ticks.touchable(d, "order") for d in reals]

    def out(mode, kind):
        return cp.read_csv(os.path.join(runs, "%s_%s_%s" % (tag, mode, harness),
                                        "out_%s_%s_%s.csv" % (tag, mode, kind)))
    sync = cp.replay_deals(out("sync", "deals"), out("sync", "orders"))
    after = [i for i, r in enumerate(reals) if cut_ms is None or r["t"] >= cut_ms]
    t0 = {"real": len(after), "touch": sum(1 for i in after if touch[i])}
    ev = cp.read_events(os.path.join(runs, "%s_free_%s" % (tag, harness), "out_%s_free_events.csv" % tag))
    real_c = side_counts(real_scalps_t(archive_rows, segs), real_rolls_t(real_rows, segs), cut_ms)
    rep_c = side_counts(replay_scalps_t(ev), replay_rolls_t(ev), cut_ms)
    return {"t0": t0, "t1": t1_after(reals, sync, touch, cut_ms), "real": real_c, "rep": rep_c}


def report(per_fleet, sc, tol, cut_ms, harness):
    lines = ["# Plan 3 score, harness %s, cut %s" % (harness, cut_ms if cut_ms is not None else "none (all deals)"), ""]
    lines.append("| fleet | T0 | T1 matched / touchable | replay-only | T0 | T1 |")
    lines.append("|---|---|---|---|---|---|")
    ok = True
    for f in FLEETS:
        t0, t1 = per_fleet[f]["t0"], per_fleet[f]["t1"]
        t0_ok = t0["real"] > 0 and t0["touch"] * 100 >= 95 * t0["real"]
        ok = ok and t0_ok and t1["pass"]
        lines.append("| %s | %d / %d | %d / %d = %s | %d = %s | %s | %s |" % (
            f, t0["touch"], t0["real"], t1["matched_touch"], t1["touch"],
            "%.1f%%" % (100 * t1["rate"]) if t1["rate"] is not None else "-", t1["replay_only"],
            "%.1f%%" % (100 * t1["replay_only"] / t1["real"]) if t1["real"] else "-",
            "PASS" if t0_ok else "FAIL", "PASS" if t1["pass"] else "FAIL"))
    lines += ["", "| fleet | side | scoreable | S real / rep (tol) | R real / rep (tol) | A real / rep (tol) | OUT |",
              "|---|---|---|---|---|---|---|"]
    for f in FLEETS:
        for s in SIDES:
            r, p = per_fleet[f]["real"][s], per_fleet[f]["rep"][s]
            cells = ["%d / %d (%.2f)" % (r[k], p[k], tol[(f, s, k)]) for k in KINDS]
            lines.append("| %s | %s | %s | %s | %s | %s | %s |" % (
                f, s, "yes" if (f, s) in sc["scoreable"] else "no", cells[0], cells[1], cells[2],
                "OUT" if (f, s) in sc["counts"]["out_sides"] else ""))
    b = sc["bias"]
    lines += ["", "- Count mark: OUT sides %s; beyond 2 x tol %s." % (sc["counts"]["out_sides"] or "none",
                                                                     sc["counts"]["beyond_2x"] or "none"),
              "- Bias mark: S errors %s, one sign %s, sum %+d of %d real S: %s." % (
                  b["errors"], b["one_sign"], b["sum"], b["real_s"], "FAIL" if b["fail"] else "pass"),
              "- Difference mark:"]
    for s, k, x, live, rep, limit, fail in sc["difference"]["rows"]:
        lines.append("  - %s %s %s-B live %+d replay %+d (limit %.2f): %s" % (s, k, x, live, rep, limit,
                                                                             "FAIL" if fail else "ok"))
    if sc["verdict"] == "INCONCLUSIVE":
        verdict = "INCONCLUSIVE"
    elif not ok:
        verdict = "FAIL"
    else:
        verdict = sc["verdict"]
    lines += ["", "**Verdict: %s** (T0 and T1 %s; counts / bias / difference / scoreable: %s)." % (
        verdict, "pass" if ok else "FAIL", sc["verdict"]), ""]
    return "\n".join(lines)


def main(argv=None):
    ap = argparse.ArgumentParser()
    for a in ("inputs", "runs", "harness", "ticks", "archive-b", "archive-c", "archive-d", "tol", "out"):
        ap.add_argument("--" + a, required=True)
    ap.add_argument("--cut-ms", type=int, default=None)
    a = ap.parse_args(argv)
    ticks = cp.Ticks.load(a.ticks)
    tol = read_tol(a.tol)
    per_fleet, counts = {}, {}
    for f, path in zip(FLEETS, (a.archive_b, a.archive_c, a.archive_d)):
        per_fleet[f] = fleet(a.inputs, a.runs, a.harness, "eurusd_%s" % f.lower(), ticks,
                             cp.read_jsonl(path), a.cut_ms)
        for s in SIDES:
            counts[(f, s)] = {"real": per_fleet[f]["real"][s], "rep": per_fleet[f]["rep"][s]}
    text = report(per_fleet, score(counts, tol), tol, a.cut_ms, a.harness)
    with open(a.out, "w", newline="\n") as fh:
        fh.write(text)
    print(text)


if __name__ == "__main__":
    main()
