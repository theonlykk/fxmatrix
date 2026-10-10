"""live_spread.py -- plan 3's tolerances, from LIVE data only (replay-calibration-eurusd-3.md s4).

Per fleet and side, the live daily counts of
- S: scalp_history closes with rolled = false (as compare.py's T2),
- R: scalp_history closes with rolled = true,
- A: ROLL rows of real_eurusd_<fleet>.csv (ROLL_ACCEPTED, as compare.py's T2),
on each server weekday of DAYS; their sample standard deviation sd; and the tolerance for
a holdout of n days:

    tol = max(FLOOR, sd * sqrt(n) / 3)

(a third of the live spread of an n-day total, never below FLOOR). The archive rows are
de-duplicated as compare.py does (every field except id and received_at). Read-only,
standard library.

usage: python -I live_spread.py ARCHIVE_DIR INPUTS_DIR [N_DAYS]
ARCHIVE_DIR holds archive_EURUSD_OPT{B,C,D}_2026-10-08_2240.jsonl; INPUTS_DIR is
research/replay/inputs/eurusd_20261008.
"""
import collections
import datetime as dt
import json
import math
import os
import statistics
import sys

DAYS = ("2026-10-01", "2026-10-02", "2026-10-05", "2026-10-06", "2026-10-07", "2026-10-08")
FLOOR = 2.0


def daily_scalps(lines):
    """{(day, side, 'S' or 'R'): count} from archive json lines, de-duplicated."""
    seen, out = set(), collections.Counter()
    for line in lines:
        r = json.loads(line)
        if r.get("table") != "scalp_history":
            continue
        key = tuple(sorted((k, json.dumps(v)) for k, v in r.items() if k not in ("id", "received_at")))
        if key in seen:
            continue
        seen.add(key)
        side = "L" if r["direction"] == "LONG" else "S"
        out[(r["close_time_broker"][:10], side, "R" if r["rolled"] else "S")] += 1
    return out


def daily_rolls(rows):
    """{(day, side, 'A'): count} from real_*.csv rows (server ms)."""
    out = collections.Counter()
    for r in rows:
        if r["kind"] != "ROLL":
            continue
        day = dt.datetime.fromtimestamp(int(r["time_ms"]) / 1000, dt.timezone.utc).strftime("%Y-%m-%d")
        out[(day, r["side"], "A")] += 1
    return out


def tolerance(sd, n_days):
    return max(FLOOR, sd * math.sqrt(n_days) / 3.0)


def table(counts, n_days, days=DAYS):
    """[(side, kind, daily list, sd, tol)] for sides L, S and kinds S, R, A."""
    out = []
    for side in ("L", "S"):
        for kind in ("S", "R", "A"):
            v = [counts.get((d, side, kind), 0) for d in days]
            sd = statistics.stdev(v)
            out.append((side, kind, v, sd, tolerance(sd, n_days)))
    return out


def main(archive_dir, inputs_dir, n_days="3"):
    import csv
    n = int(n_days)
    print("days: %s; holdout days n = %d; tol = max(%.0f, sd * sqrt(n) / 3)" % (", ".join(DAYS), n, FLOOR))
    for f in "bcd":
        with open(os.path.join(archive_dir, "archive_EURUSD_OPT%s_2026-10-08_2240.jsonl" % f.upper()),
                  encoding="utf-8-sig") as fh:
            c = daily_scalps(fh)
        with open(os.path.join(inputs_dir, "real_eurusd_%s.csv" % f), newline="") as fh:
            c.update(daily_rolls(csv.DictReader(fh)))
        for side, kind, v, sd, tol in table(c, n):
            print("%s %s %s daily %-26s sd %5.2f tol %5.2f" % (f.upper(), side, kind, v, sd, tol))


if __name__ == "__main__":
    main(*sys.argv[1:4])
