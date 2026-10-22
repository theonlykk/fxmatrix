"""score11.py -- sweep11: each pair's OPT add from the calm weeks and ALT add from October (sweep_notes sweep11).

Per pair, on the add = exit line at cap 7 (pips at 0.01 lots):
- calm net per add = the sum of the eight weekly flat-start nets (sweep.py score, unchanged: realised - commission +
  the open book at Friday's mark; carry off) from the sw11w run;
- October net per add = the end of the daily curve, one flat start carried 1 - 20 Oct: sweep9's curves (EURUSD),
  sweep10's (the other five), and the sw11o run scored here by score10's curve (the pair's commission, swap).
Then select() (the rule) and both() (each arm over both periods). See test_score11.py for the rule in words.

  python -B score11.py --pair GBPUSD --calm-run <run_sw11w_gbpusd.csv> --oct-run <run_sw11o_gbpusd.csv>
                       --outs <dir of out_sw11?_*_free_*.csv> --calm-ticks <h8w ticks> --oct-ticks <oct ticks>
                       --out <report.md> --json <result.json>
"""
import argparse
import csv
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
for d in (os.path.join(HERE, "..", "sweep10"), os.path.join(HERE, "..", "sweep9"), os.path.join(HERE, "..", "..")):
    sys.path.insert(0, os.path.normpath(d))
import compare as cmp  # noqa: E402
import score9 as s9  # noqa: E402
import score10 as s10  # noqa: E402
import sweep as sw  # noqa: E402

CALM_LIMIT = -100.0
STAGED = {"EURUSD": (7, 18), "GBPUSD": (9, 21), "EURGBP": (3, 16), "AUDCAD": (6, 26), "AUDCHF": (4, 20),
          "CADCHF": (4, 9)}   # E's t1 OPT and t2 ALT adds


def _windows(adds):
    return [adds[i - 1:i + 2] for i in range(1, len(adds) - 1)]


def _best_middle(adds, val):
    """The middle of the window of three adjacent adds with the largest summed val (ties: the smaller middle)."""
    best = None
    for w in _windows(adds):
        s = sum(val[a] for a in w)
        if best is None or s > best[0]:
            best = (s, w[1])
    return best


def select(calm, octo, limit=CALM_LIMIT):
    adds = sorted(calm)
    opt = None
    b = _best_middle(adds, calm)
    if b is not None and b[0] > 0 and calm[b[1]] > 0:
        opt = float(b[1])
    elig = sorted(a for a in octo if (opt is None or a > opt) and a in calm and calm[a] >= limit)
    alt = None
    if len(elig) >= 3:
        m = _best_middle(elig, octo)[1]
        if octo[m] > 0:
            alt = float(m)
    elif elig:
        m = max(elig, key=lambda a: (octo[a], -a))
        if octo[m] > 0:
            alt = float(m)
    return opt, alt


def both(calm, octo, opt, alt):
    o = 0.0 if opt is None else calm[opt] + octo[opt]
    a = 0.0 if alt is None else calm[alt] + octo[alt]
    return {"opt": o, "alt": a, "total": o + a}


def weekly(labels, sc):
    out = {}
    for seg in sorted(sc):
        name = labels[seg][0]
        out.setdefault(float(name[1:].split("e")[0]), []).append(sc[seg]["total_net"])
    return out


def _add(name):
    return float(name[1:].split("e")[0])


def october_known(pair):
    """End nets of the October line already run: sweep9's cap-7 diagonal (EURUSD) or sweep10's grid."""
    f = os.path.join(HERE, "..", "sweep9", "sw9_curves.csv") if pair == "EURUSD" else \
        os.path.join(HERE, "..", "sweep10", "sw10_%s_curves.csv" % pair.lower())
    out = {}
    with open(f, newline="") as fh:
        for row in csv.reader(fh):
            if row[0].endswith("n7") and row[0] != "geometry":
                a = _add(row[0])
                if row[0] == "a%de%dn7" % (a, a):
                    out[a] = float(row[-1])
    return out


def october_new(pair, run_csv, outs, ticks):
    curves, _info = s10.score_pair(pair, run_csv, outs, ticks) if pair != "EURUSD" else _score_eurusd(run_csv, outs,
                                                                                                         ticks)
    return {_add(n): c[-1] for n, c in curves.items()}


def _score_eurusd(run_csv, outs, ticks):
    tag = os.path.basename(run_csv)[4:-4]
    segs, names, pos, scalps, snaps, counts = s9.load_run(
        run_csv, os.path.join(outs, "out_%s_free_deals.csv" % tag), os.path.join(outs, "out_%s_free_events.csv" % tag))
    curves = {}
    for seg, r in segs.items():
        ends = s9.day_ends(int(r["from_ms"]), int(r["to_ms"]))
        curves[names[seg]] = s10.curve(pos.get(seg, []), scalps.get(seg, []), snaps.get(seg, []), ends, ticks.mark,
                                       sw.get_set("sw11o_eurusd")["comm_pips"])
    return curves, None


def calm_nets(pair, run_csv, outs, ticks_path):
    st = sw.get_set("sw11w_" + pair.lower())
    tag = os.path.basename(run_csv)[4:-4]
    segs = cmp.segments(cmp.read_csv(run_csv))
    sc = sw.score(segs, cmp.read_events(os.path.join(outs, "out_%s_free_events.csv" % tag)),
                  cmp.read_csv(os.path.join(outs, "out_%s_free_book.csv" % tag)), cmp.Ticks.load(ticks_path),
                  comm_pips=st["comm_pips"])
    return weekly(sw.labels(st["windows"], st["geoms"]), sc)


def report(pair, wk, octo, opt, alt):
    calm = {a: sum(v) for a, v in wk.items()}
    so, sa = STAGED[pair]
    b, bs = both(calm, octo, opt, alt), both(calm, octo, float(so), float(sa))
    f = lambda x: "none" if x is None else "%g" % x
    lines = ["# sweep11 %s (score11.py): OPT from the calm weeks, ALT from October; pips at 0.01 lots" % pair, "",
             "**OPT %s, ALT %s** (staged: OPT %d, ALT %d)" % (f(opt), f(alt), so, sa), "",
             "Both periods (calm 8 weeks + October): chosen OPT %+.1f, ALT %+.1f, total %+.1f; staged OPT %+.1f, ALT "
             "%+.1f, total %+.1f" % (b["opt"], b["alt"], b["total"], bs["opt"], bs["alt"], bs["total"]), "",
             "| add | calm net | weeks > 0 | weekly | October net |", "|---|---|---|---|---|"]
    for a in sorted(set(calm) | set(octo)):
        w = wk.get(a)
        lines.append("| %g%s | %s | %s | %s | %s |" % (
            a, " (OPT)" if a == opt else (" (ALT)" if a == alt else ""),
            "-" if w is None else "%+.1f" % sum(w), "-" if w is None else "%d / %d" % (sum(1 for x in w if x > 0), len(w)),
            "-" if w is None else " ".join("%+.0f" % x for x in w), "%+.1f" % octo[a] if a in octo else "-"))
    return "\n".join(lines) + "\n", {"pair": pair, "opt": opt, "alt": alt, "both": b, "staged": bs,
                                     "calm": calm, "octo": octo}


def main(argv=None):
    ap = argparse.ArgumentParser()
    for k in ("pair", "calm-run", "oct-run", "outs", "calm-ticks", "oct-ticks", "out", "json"):
        ap.add_argument("--" + k, required=True)
    a = ap.parse_args(argv)
    pair = a.pair.upper()
    wk = calm_nets(pair, a.calm_run, a.outs, a.calm_ticks)
    octo = october_known(pair)
    octo.update(october_new(pair, a.oct_run, a.outs, s9.Ticks(a.oct_ticks)))
    opt, alt = select({k: sum(v) for k, v in wk.items()}, octo)
    text, res = report(pair, wk, octo, opt, alt)
    with open(a.out, "w", newline="\n") as fh:
        fh.write(text)
    with open(a.json, "w", newline="\n") as fh:
        json.dump(res, fh, sort_keys=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
