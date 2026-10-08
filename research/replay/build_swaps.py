"""build_swaps.py -- the replay harness's swaps.csv from the archive.

Base prompt s3.2: swaps.csv = server_date,points_long,points_short,mult, one
row per server date D = the rollover INTO D 00:00 server. The harness adds
points x mult x tick_value x volume to every open position when a tick
crosses into D (fix 1 A3).

The rule, measured 8 Oct ~19:50Z on every closed EURUSD ENT position of B, C
and D since 24 Sep (622 of 622 to the cent; HANDOFF s72): the points are the
latest CARRY_SNAPSHOT's swap_long / swap_short before D 00:00 server; the
multiplier is 3 into Thursday, 0 into Saturday and Sunday, 1 otherwise. (The
EA's own carry pass applies its triple one night EARLY, at the rollover into
Wednesday: backlog C144. The harness runs that code as it is; swaps.csv
carries what the broker charged.)

    python -B research/replay/build_swaps.py --from 2026-10-01 --to 2026-10-09 \
        --out swaps.csv archive_A.jsonl [archive_B.jsonl ...]

Standard library only; reads the archives, writes one file (no BOM).
"""
import argparse
import bisect
import datetime as dt
import json
import sys

SERVER_OFFSET = dt.timedelta(hours=3)   # IC and FTMO servers run GMT+3 (BOOT s6)
HEADER = "server_date,points_long,points_short,mult"


def multiplier(d):
    """Rollover INTO server date d: 3 into Thursday, 0 into Sat / Sun, else 1."""
    wd = d.weekday()            # Monday 0
    if wd == 3:
        return 3
    if wd in (5, 6):
        return 0
    return 1


def _utc(text):
    s = str(text).replace("Z", "+00:00")
    t = dt.datetime.fromisoformat(s)
    if t.tzinfo is not None:
        t = t.astimezone(dt.timezone.utc).replace(tzinfo=None)
    return t


def snapshots_server(rows, offset=SERVER_OFFSET):
    """(server_time, swap_long, swap_short) for every CARRY_SNAPSHOT row, sorted."""
    out = []
    for r in rows:
        if r.get("table") != "ea_events" or r.get("code") != "CARRY_SNAPSHOT":
            continue
        d = r["detail"] if isinstance(r["detail"], dict) else json.loads(r["detail"])
        out.append((_utc(r["received_at"]) + offset, float(d["swap_long"]), float(d["swap_short"])))
    out.sort(key=lambda x: x[0])
    return out


def rate_for(snaps, d):
    """(points_long, points_short) of the latest snapshot strictly before d 00:00, or None."""
    times = [s[0] for s in snaps]
    i = bisect.bisect_left(times, dt.datetime.combine(d, dt.time())) - 1
    if i < 0:
        return None
    return (snaps[i][1], snaps[i][2])


def build_rows(snaps, first, last):
    """One row per server date first..last inclusive; ValueError if a date has no rate."""
    rows = []
    d = first
    while d <= last:
        r = rate_for(snaps, d)
        if r is None:
            raise ValueError("no CARRY_SNAPSHOT before %s 00:00 server" % d.isoformat())
        rows.append((d.strftime("%Y.%m.%d"), r[0], r[1], multiplier(d)))
        d += dt.timedelta(days=1)
    return rows


def to_csv(rows):
    lines = [HEADER] + ["%s,%s,%s,%d" % (d, repr(pl), repr(ps), m) for d, pl, ps, m in rows]
    return "\n".join(lines) + "\n"


def predict_swap(snaps, side, opened, closed, volume):
    """Account-currency swap of a position (EURUSD, tick value 1.0) from open to close, server times."""
    total = 0.0
    d = opened.date() + dt.timedelta(days=1)
    while dt.datetime.combine(d, dt.time()) <= closed:
        m = multiplier(d)
        if m:
            r = rate_for(snaps, d)
            if r is None:
                raise ValueError("no rate for %s" % d)
            total += (r[0] if side == "L" else r[1]) * m * 1.0 * volume
        d += dt.timedelta(days=1)
    return total


def _load(paths):
    rows = []
    for p in paths:
        with open(p, encoding="utf-8-sig") as f:
            for line in f:
                if line.strip():
                    rows.append(json.loads(line))
    return rows


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--from", dest="first", required=True)
    ap.add_argument("--to", dest="last", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("archives", nargs="+")
    a = ap.parse_args(argv)
    snaps = snapshots_server(_load(a.archives))
    rows = build_rows(snaps, dt.date.fromisoformat(a.first), dt.date.fromisoformat(a.last))
    with open(a.out, "w", encoding="ascii", newline="\n") as f:
        f.write(to_csv(rows))
    for r in rows:
        print("%s,%s,%s,%d" % r)
    return 0


if __name__ == "__main__":
    sys.exit(main())
