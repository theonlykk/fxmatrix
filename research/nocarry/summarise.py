"""The no-carry result against research/nocarry/PREREG.md s4 and s6 (run only after selfcheck.py has passed).

    python research/nocarry/summarise.py <run dir> > summary.json

For each run (CONT, DAY, WEEK, DAY_w05, WEEK_w05) and each group (the twelve, the six OPT, the six ALT): the net and
its parts, the years, the windows of month-end equity, peak to trough, and the FTMO days from the per-tick arrays;
then s6's label for DAY (deciding) and, reported beside it, for WEEK."""
import datetime as dt
import json
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import run_nocarry as rn  # noqa: E402

PAIRS = ("AUDCAD", "AUDCHF", "CADCHF", "EURGBP", "EURUSD", "GBPUSD")
RUNS = ("CONT", "DAY", "WEEK", "DAY_w05", "WEEK_w05")
GROUPS = {"all12": ("opt", "alt"), "opt6": ("opt",), "alt6": ("alt",)}
PARTS = ("scalp", "rolled", "cut", "open", "comm", "net")


def day_date(key):
    return dt.datetime.fromtimestamp((key * rn.DAY_MS + 3600000) / 1000, dt.timezone.utc).strftime("%Y-%m-%d")


def summarise_run(out, run):
    js = {p: json.load(open(os.path.join(out, "%s_%s.json" % (run, p)))) for p in PAIRS}
    res = {}
    # month-end equity per group
    months = [m["m"] for m in js[PAIRS[0]]["series"]]
    for p in PAIRS:
        assert [m["m"] for m in js[p]["series"]] == months, p
    # the per-tick arrays: one union grid, then each group's balance and equity
    zs = {p: np.load(os.path.join(out, "%s_%s.npz" % (run, p))) for p in PAIRS}
    for g, arms in GROUPS.items():
        parts = {k: round(sum(js[p][a + "_end"][k] for p in PAIRS for a in arms), 2) for k in PARTS}
        E = [round(sum(m[a + "_real"] + m[a + "_open"] for p in PAIRS for m in [js[p]["series"][i]] for a in arms), 2)
             for i in range(len(months))]
        years, last = {}, 0.0
        for i, m in enumerate(months):
            if i == len(months) - 1 or months[i + 1][:4] != m[:4]:
                years[m[:4]] = round(E[i] - last, 2)
                last = E[i]
        peak, ptt = 0.0, 0.0
        for e in E:
            peak = max(peak, e)
            ptt = min(ptt, e - peak)
        w1, w3, w12 = rn.win_neg(E, 1), rn.win_neg(E, 3), rn.win_neg(E, 12)
        series = [(zs[p]["t"], sum(zs[p]["bal_" + a] for a in arms), sum(zs[p]["eq_" + a] for a in arms))
                  for p in PAIRS]
        t, bal, eq = rn.combine(series)
        dl = rn.day_losses(t, bal, eq)
        losses = sorted(((v[2], k) for k, v in dl.items()), reverse=True)
        res[g] = {"parts": parts, "years": years, "neg1": w1, "neg3": w3, "neg12": w12, "peak_to_trough": round(ptt, 2),
                  "worst12": round(min((E[i] - E[i - 12] for i in range(12, len(E))), default=0.0), 2),
                  "ftmo_days": len(dl), "days500": sum(1 for v in dl.values() if v[2] >= 500.0),
                  "days400": sum(1 for v in dl.values() if v[2] >= 400.0),
                  "worst10": [(day_date(k), v) for v, k in losses[:10]],
                  "per_pair": {p: {a: js[p][a + "_end"] for a in arms} for p in PAIRS}}
    res["cut_nights"] = {p: (js[p].get("cut_nights"), js[p].get("med_cut_night_usd")) for p in PAIRS}
    return res


def rule_input(g):
    return {"net": g["parts"]["net"], "years": list(g["years"].values()), "neg12": g["neg12"][0], "n12": g["neg12"][1],
            "days500": g["days500"]}


def main():
    out = sys.argv[1]
    S = {r: summarise_run(out, r) for r in RUNS}
    labels = {}
    for arm in ("DAY", "WEEK"):
        for g in GROUPS:
            labels["%s/%s" % (arm, g)] = rn.decide(rule_input(S[arm][g]), rule_input(S[arm + "_w05"][g]))
    S["labels"] = labels
    S["VERDICT"] = labels["DAY/all12"]
    print(json.dumps(S, indent=1))


if __name__ == "__main__":
    main()
