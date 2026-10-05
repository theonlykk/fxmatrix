"""C124 evidence run: the day records and the scenario table (read-only).

    python c124_run.py <downloads folder>    # history_<login>.csv + bidask_ftmo_2026-10-02/

Every number quoted in docs/research/ftmo-pass-probability.md comes from
this script's output (seed 1, 20,000 attempts per scenario).
"""
import datetime
import glob
import os
import random
import sys

import ftmo_days as fd
import ftmo_sim as fs

RING7 = {22260101, 22260201, 22260301, 22260501, 22260601, 22260801, 22260901}
ACCTS = [("A", "1514731800"), ("B", "53066709"), ("C", "53071896"), ("D", "53077984")]
# 23 Sep 2026, cycle 2 (docs/FULL_TRIAL_RECORD_1514582088.md 26, 76-82, 89-99): open MTM -332
# carried in at 00:00Z, liquidated at -505.34 vs the day-start balance (16 instances)
SEP23 = dict(day=-1, r=-505.34 + 332.0, m0=-332.0, m1=0.0, low=-505.34, n_open_max=128)


def label(day):
    t = day * 86400 + 22 * 3600 + 3 * 3600          # 01:00Z: the FTMO day's own (CEST) date
    return datetime.datetime.fromtimestamp(t, datetime.timezone.utc).strftime("%a %d %b")


def main(folder):
    bars = {os.path.basename(p).split("_")[-1][:-4]: fd.load_bars(p)
            for p in glob.glob(os.path.join(folder, "bidask_ftmo_2026-10-02", "*.csv"))}
    until = max(v[0][-1] for v in bars.values())
    days = {}
    for f, acct in ACCTS:
        deals = fd.load_history(os.path.join(folder, "history_%s.csv" % acct))
        for lab, mg in (("all", None), ("ring7", RING7)):
            days[(f, lab)] = fd.build_days(deals, bars, mg, until=until)
    for (f, lab), ds in days.items():
        print("fleet %s %s: %d days" % (f, lab, len(ds)))
        for d in ds:
            print("  %s  r %+8.2f  m0 %+8.2f  m1 %+8.2f  dE %+8.2f  low %+8.2f  open<=%d" % (
                label(d["day"]), d["r"], d["m0"], d["m1"], d["r"] + d["m1"] - d["m0"], d["low"], d["n_open_max"]))
    scen = [
        ("A all (FTMO, 11 then 7 instances)", [days[("A", "all")]], 0.0),
        ("A ring7", [days[("A", "ring7")]], 0.0),
        ("A+B+C+D ring7 (IC days under FTMO rules)", [days[(f, "ring7")] for f, _ in ACCTS], 0.0),
        ("A+B+C+D ring7, drift -10/day", [days[(f, "ring7")] for f, _ in ACCTS], -10.0),
        ("A+B+C+D ring7, drift +10/day", [days[(f, "ring7")] for f, _ in ACCTS], 10.0),
        ("A+B+C+D ring7 + one 23-Sep day", [days[(f, "ring7")] for f, _ in ACCTS] + [[SEP23]], 0.0),
    ]
    print()
    print("%-44s %6s %6s %6s %8s %8s %9s %9s  %s" % ("scenario", "P(ch)", "P(v|ch)", "P(both)", "days", "payout", "EV", "EV+ref", "fails"))
    for name, src, shift in scen:
        rng = random.Random(1)
        res = [fs.attempt(src, rng, block=2, shift=shift) for _ in range(20000)]
        s0 = fs.summarise(res)
        s1 = fs.summarise(res, refund=True)
        fails = " ".join("%s %.2f" % kv for kv in s0["fails"].items())
        print("%-44s %6.3f %6.3f %6.3f %8s %8.0f %9.1f %9.1f  %s" % (
            name, s0["p_challenge"], s0["p_verif_given_challenge"], s0["p_both"],
            s0["days_to_pass_median"], s0["payout_mean_if_passed"], s0["ev_per_attempt"], s1["ev_per_attempt"], fails))


    pool = [days[(f, "ring7")] for f, _ in ACCTS]
    flat = [d for src in pool for d in src]
    dEs = [d["r"] + d["m1"] - d["m0"] for d in flat]
    mu = sum(dEs) / len(dEs)
    sd = (sum((x - mu) ** 2 for x in dEs) / (len(dEs) - 1)) ** 0.5
    print()
    print("ring7 pool: %d days, mean dE %+.2f, sd %.2f, se %.2f, worst low %+.2f" % (
        len(dEs), mu, sd, sd / len(dEs) ** 0.5, min(d["low"] for d in flat)))
    print("grid (ring7 pool; drift set to mu by shifting every day; tail = cycle 2's 23 Sep with probability p a day; 5,000 attempts each)")
    print("%8s" % "drift" + "".join("  p=%-6s P(both)  days    EV  EV+ref" % t for t in ("0", "1/250", "1/100", "1/50")))
    for target in (0.0, 5.0, 10.0, 15.0, 20.0):
        row = "%+8.1f" % target
        for p in (0.0, 1 / 250, 1 / 100, 1 / 50):
            rng = random.Random(1)
            res = [fs.attempt(pool, rng, block=2, shift=target - mu, tail=(p, SEP23)) for _ in range(5000)]
            s0, s1 = fs.summarise(res), fs.summarise(res, refund=True)
            dd = s0["days_to_pass_median"]
            row += "  %8s %6.3f %5s %6.0f %6.0f" % ("", s0["p_both"], "-" if dd is None else "%d" % dd,
                                                    s0["ev_per_attempt"], s1["ev_per_attempt"])
        print(row)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else ".")
