"""C125 verdict: FTMO's equity per day, day-bootstrap (read-only).

    python holdout_verdict.py --history history_1514731800.csv --bars <FTMO bidask folder> [--week2]

docs/research/holdout-verdict-criteria.md s2-s3 (operator 5 Oct ~18:10Z:
"equity matters the most"; Gemini GH-1..GH-6). Each FTMO day of the
window (22:00Z-22:00Z) gives FTMO's change in equity, dE = r + m1 - m0
(`research/ftmo_pass/ftmo_days.build_days`, unchanged): realised plus
the change in open MTM. The day is the unit (GH-1: fills are not
independent; days are drawn with replacement, B resamples, seeded):
  SUPPORTED      the 2.5% quantile of the resampled mean daily change > 0
  NOT SUPPORTED  the total change over the window <= 0
  INCONCLUSIVE   otherwise: extend once (12-16 Oct) and decide on all
                 the days pooled; inconclusive again = NOT SUPPORTED.
"""
import argparse
import glob
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "ftmo_pass"))
import ftmo_days as fd  # noqa: E402

WEEK1 = ("2026-10-05T22:00Z", "2026-10-09T21:00Z")
WEEK2 = ("2026-10-11T22:00Z", "2026-10-16T21:00Z")


def utc(text):
    import datetime as dt
    return dt.datetime.strptime(text, "%Y-%m-%dT%H:%MZ").replace(tzinfo=dt.timezone.utc).timestamp()


def in_window(days, window):
    """Day records whose day STARTS inside [start, end)."""
    a, b = utc(window[0]), utc(window[1])
    return [d for d in days if a <= d["day"] * fd.DAY + fd.DAY_START < b]


def verdict(changes, B=20000, seed=1):
    """{'n', 'total', 'mean', 'lb', 'verdict'} for a list of daily equity changes."""
    xs = [float(x) for x in changes]
    n = len(xs)
    total = sum(xs)
    rng = random.Random(seed)
    means = sorted(sum(rng.choice(xs) for _ in range(n)) / n for _ in range(B))
    lb = means[int(0.025 * B)]
    if total <= 0:
        v = "NOT SUPPORTED"
    elif lb > 0:
        v = "SUPPORTED"
    else:
        v = "INCONCLUSIVE"
    return {"n": n, "total": total, "mean": total / n, "lb": lb, "verdict": v}


def final(week1, week2=None, B=20000, seed=1):
    """The criteria's s3 with the one extension: week1 alone unless it is
    INCONCLUSIVE; then all days pooled, and INCONCLUSIVE again counts as NOT SUPPORTED."""
    r = verdict(week1, B, seed)
    if r["verdict"] != "INCONCLUSIVE" or week2 is None:
        return r
    r = verdict(list(week1) + list(week2), B, seed)
    if r["verdict"] == "INCONCLUSIVE":
        r["verdict"] = "NOT SUPPORTED"
        r["note"] = "inconclusive after the extension"
    return r


def main(argv=None):
    ap = argparse.ArgumentParser(description="C125 verdict on FTMO's daily equity")
    ap.add_argument("--history", required=True, help="history_1514731800.csv (grind_history_dump, after the close)")
    ap.add_argument("--bars", required=True, help="FTMO grind_bidask_dump folder covering the window")
    ap.add_argument("--week2", action="store_true", help="also the extension week 12-16 Oct")
    a = ap.parse_args(argv)
    bars = {os.path.basename(p).split("_")[-1][:-4]: fd.load_bars(p) for p in glob.glob(os.path.join(a.bars, "*.csv"))}
    until = max(v[0][-1] for v in bars.values())
    days = fd.build_days(fd.load_history(a.history), bars, until=until)
    w1 = in_window(days, WEEK1)
    w2 = in_window(days, WEEK2) if a.week2 else None
    for d in w1 + (w2 or []):
        print("day start %d  r %+8.2f  m0 %+8.2f  m1 %+8.2f  dE %+8.2f  low %+8.2f" % (
            d["day"] * fd.DAY + fd.DAY_START, d["r"], d["m0"], d["m1"], d["r"] + d["m1"] - d["m0"], d["low"]))
    de = lambda ds: [d["r"] + d["m1"] - d["m0"] for d in ds]
    print("week 1:", verdict(de(w1)))
    print("FINAL:", final(de(w1), de(w2) if w2 is not None else None))


if __name__ == "__main__":
    main()
