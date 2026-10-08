"""build_swaps.py -- the replay harness's swaps.csv from the archive.

Base prompt s3.2: swaps.csv = server_date,points_long,points_short,mult, one
row per server date D = the rollover INTO D 00:00 server. The harness adds
points x mult x tick_value x volume to every open position when a tick
crosses into D (fix 1 A3). The points written are EFFECTIVE (operator 8 Oct
~20:37Z): the broker rounds each night's charge to the cent, the harness
does not, so each row carries round(rate x mult x 0.01, 2) / (mult x 0.01)
and the harness books the broker's cent exactly at 0.01 lot (a '#' line in
the file says so; mult-0 rows keep the raw rate).

The rule, measured EXACTLY (no tolerance) 8 Oct ~20:35Z on every closed EURUSD
ENT position of B, C and D since 24 Sep (626 of 626; HANDOFF s73): the points
are the swap_long / swap_short of the CARRY_SNAPSHOT NEAREST to D 00:00 server
(ties: the earlier; none within MAX_RATE_GAP = no rate); the multiplier is 3
into Thursday, 0 into Saturday and Sunday, 1 otherwise; the broker charges
each night round(points x mult x tick_value x volume, 2). (s72's first model,
the latest snapshot before D 00:00 with one rounding of the sum, matched 600
of 626 exactly: there was no snapshot on Mon 5 Oct night.) (The
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


MAX_RATE_GAP = dt.timedelta(hours=96)


def rate_for(snaps, d):
    """(points_long, points_short) of the snapshot nearest d 00:00 (ties: the earlier), or None."""
    times = [s[0] for s in snaps]
    t = dt.datetime.combine(d, dt.time())
    i = bisect.bisect_left(times, t)
    best = None
    for j in (i - 1, i):
        if 0 <= j < len(snaps):
            gap = abs(times[j] - t)
            if gap <= MAX_RATE_GAP and (best is None or gap < best[0]):
                best = (gap, j)
    if best is None:
        return None
    j = best[1]
    return (snaps[j][1], snaps[j][2])


REF_VOLUME = 0.01       # every EURUSD layer on B, C, D (fill_logs volume 0.01 throughout)
REF_TICK_VALUE = 1.0    # IC EURUSD on a USD account (15 of 15 CARRY_SNAPSHOT; fix 5 GH5-2)
COMMENT = ("# points are EFFECTIVE: each night's broker charge at 0.01 lot and tick value 1.0 "
           "rounded to the cent / (mult x 0.01); mult 0 rows keep the raw rate (HANDOFF s73)")


def effective_points(points, mult):
    """Points that make points x mult x tick value x volume equal the broker's cent at REF_VOLUME."""
    if mult == 0:
        return points
    unit = mult * REF_TICK_VALUE * REF_VOLUME
    return round(points * unit, 2) / unit


def build_rows(snaps, first, last):
    """One row per server date first..last inclusive; ValueError if a date has no rate."""
    rows = []
    d = first
    while d <= last:
        r = rate_for(snaps, d)
        if r is None:
            raise ValueError("no CARRY_SNAPSHOT before %s 00:00 server" % d.isoformat())
        m = multiplier(d)
        rows.append((d.strftime("%Y.%m.%d"), effective_points(r[0], m), effective_points(r[1], m), m))
        d += dt.timedelta(days=1)
    return rows


def to_csv(rows):
    lines = [COMMENT, HEADER] + ["%s,%s,%s,%d" % (d, repr(pl), repr(ps), m) for d, pl, ps, m in rows]
    return "\n".join(lines) + "\n"


def predict_swap(snaps, side, opened, closed, volume):
    """Account-currency swap of a position (EURUSD, tick value 1.0) from open to close, server
    times: each night's charge rounded to the cent, as the broker books it."""
    total = 0.0
    d = opened.date() + dt.timedelta(days=1)
    while dt.datetime.combine(d, dt.time()) <= closed:
        m = multiplier(d)
        if m:
            r = rate_for(snaps, d)
            if r is None:
                raise ValueError("no rate for %s" % d)
            total += round((r[0] if side == "L" else r[1]) * m * 1.0 * volume, 2)
        d += dt.timedelta(days=1)
    return round(total, 2) + 0.0


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
