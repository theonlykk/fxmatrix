"""build_holdout.py -- plan 3 s7's holdout inputs (docs/research/replay-calibration-eurusd-3.md s3, s7).

The existing builders (build_inputs.fleet_files: build_segments, build_seeds, build_orders,
build_real) on the holdout's exports (research/replay/inputs/eurusd_holdout_raw.sha256, the
_2026-10-13_2210 set). Plan 2 s7 / plan 3 s3: B and C run on from their 7 Oct inits (no synthetic
init), D from its 9 Oct 04:24:14Z init; an init inside the window cuts a segment; the window ends
Tue 13 Oct 22:00Z = 14 Oct 01:00 server. The scorer counts deals after the cut (9 Oct 04:32Z).

Ticks: the calibration's w2 dump (1 Oct 04:00 to 9 Oct 01:30 server) and the holdout's dump
(9 Oct 01:30 to 14 Oct 01:30 server) joined at their common seam (join_ticks: the headers must
meet, no tick of the first at or after the seam, none of the second before it, both sorted).
Segment ids: B 31.., C 41.., D 51.. (the calibration's are 1-29; tags stay eurusd_b/c/d, which
compare.py and score_plan3.py read). Intervals: none; any breaker or API-limit code in a fleet's
window (gate_codes) stops the build, since the harness would need an interval for it.

    python -B research/replay/build_holdout.py join --w2 W2.csv --hold HOLD.csv --out JOINED.csv
    python -B research/replay/build_holdout.py build --out DIR --ticks JOINED.csv \
        --b ARCHIVE_B --c ARCHIVE_C --d ARCHIVE_D --sends-b S_B --sends-c S_C --sends-d S_D

swaps.csv: build_swaps.py (--from 2026-10-01 --to 2026-10-14) on the three holdout archives.
Standard library only; ascii, LF (run files), CRLF kept in the tick file, no BOM.
"""
import argparse
import datetime as dt
import json
import os
import re
import sys

import build_inputs
import build_seeds
import build_segments

SERVER_OFFSET_MS = 3 * 3600 * 1000
FLEETS = (("b", "eurusd_b", "2026-10-07T02:21:20", 31),
          ("c", "eurusd_c", "2026-10-07T02:12:36", 41),
          ("d", "eurusd_d", "2026-10-09T04:24:14", 51))
WINDOW_END_SERVER_MS = 1791939600000      # 2026.10.14 01:00:00 server = 13 Oct 22:00Z
CUT_SERVER_MS = 1791531120000             # 2026.10.09 07:32:00 server = 9 Oct 04:32Z
TICK_HEADER = "time_msc_server,bid,ask,flags"
GATE_PREFIXES = ("BREAKER_", "WARN_API_")


def server_ms(text):
    """'2026.10.09 01:30:00.000' (server clock) as epoch ms read as UTC, as time_msc_server."""
    t = dt.datetime.strptime(text, "%Y.%m.%d %H:%M:%S.%f")
    return int((t - dt.datetime(1970, 1, 1)).total_seconds() * 1000)


def _split(text):
    if "\r\n" not in text or re.search(r"(?<!\r)\n", text):
        raise ValueError("tick file must be CRLF throughout")
    lines = text.split("\r\n")
    if lines[-1] != "":
        raise ValueError("tick file must end with CRLF")
    lines = lines[:-1]
    if len(lines) < 2 or not lines[0].startswith("#") or lines[1] != TICK_HEADER:
        raise ValueError("tick file header")
    m = re.search(r" from=(\S+ \S+) to=(\S+ \S+) ", lines[0])
    if not m:
        raise ValueError("tick file from / to")
    times = [int(x.split(",", 1)[0]) for x in lines[2:]]
    if any(b < a for a, b in zip(times, times[1:])):
        raise ValueError("ticks out of order")
    return lines[0], m.group(1), m.group(2), lines[2:], times


def join_ticks(first, second):
    h1, f1, t1, rows1, ms1 = _split(first)
    h2, f2, t2, rows2, ms2 = _split(second)
    if t1 != f2:
        raise ValueError("headers do not meet: %s / %s" % (t1, f2))
    seam = server_ms(t1)
    if ms1 and ms1[-1] >= seam:
        raise ValueError("first file has a tick at or after the seam")
    if ms2 and ms2[0] < seam:
        raise ValueError("second file has a tick before the seam")
    head = h1.replace(" to=%s " % t1, " to=%s " % t2, 1) + " joined_at=%s" % t1
    out = "\r\n".join([head, TICK_HEADER] + rows1 + rows2) + "\r\n"
    info = {"first": len(rows1), "second": len(rows2), "joined": len(rows1) + len(rows2),
            "first_ms": (ms1 or ms2)[0], "seam_ms": seam,
            "gap_ms": (ms2[0] - ms1[-1]) if ms1 and ms2 else None}
    return out, info


def gate_codes(rows, from_ms, to_ms):
    """Breaker / API-limit ea_events in [from_ms, to_ms) server ms, as (code, server ms)."""
    out = []
    for r in rows:
        if r.get("table") != "ea_events":
            continue
        code = r.get("code") or ""
        t = int(r["ea_time_ms"]) + SERVER_OFFSET_MS
        if code.startswith(GATE_PREFIXES) and from_ms <= t < to_ms:
            out.append((code, t))
    return sorted(out, key=lambda x: x[1])


def _load(path):
    with open(path, encoding="utf-8-sig") as f:
        return [json.loads(line) for line in f if line.strip()]


def join_sends(first, second=None):
    """Every send_logs row of both lists, deduplicated by id, sorted by (ea_time_ms, seq, id)."""
    by_id = {}
    kept = []
    for r in list(first) + list(second or ()):
        if "_meta" in r or r.get("table") != "send_logs":
            continue
        rid = r.get("id")
        if rid is not None:
            rid = int(rid)
            if rid in by_id:
                if by_id[rid] != r:
                    raise ValueError("conflicting send_logs row for id %d" % rid)
                continue
            by_id[rid] = r
        kept.append(r)
    return sorted(kept, key=lambda r: (int(r["ea_time_ms"]), int(r.get("seq") or 0),
                                       int(r.get("id") or 0)))


def _first_tick_ms(path):
    with open(path, encoding="ascii", newline="") as f:
        for line in f:
            if line[:1].isdigit():
                return int(line.split(",", 1)[0])
    raise ValueError("no ticks in %s" % path)


def cmd_join(a):
    with open(a.w2, encoding="ascii", newline="") as f:
        first = f.read()
    with open(a.hold, encoding="ascii", newline="") as f:
        second = f.read()
    out, info = join_ticks(first, second)
    with open(a.out, "w", encoding="ascii", newline="") as f:
        f.write(out)
    print("JOINED", os.path.basename(a.out), info)
    return 0


def cmd_build(a):
    window_end_ms = int(getattr(a, "window_end_ms", WINDOW_END_SERVER_MS))
    first_ids_raw = getattr(a, "first_ids", None)
    if first_ids_raw is None:
        first_ids = [f[3] for f in FLEETS]
    else:
        first_ids = [int(x) for x in str(first_ids_raw).split(",") if x.strip()]
    if len(first_ids) != len(FLEETS):
        raise ValueError("--first-ids needs %d comma-separated integers" % len(FLEETS))
    data = {k: _load(getattr(a, k)) for k, _t, _w, _f in FLEETS}
    sends = {}
    for k, _t, _w, _f in FLEETS:
        extra = getattr(a, "sends_extra_" + k, None)
        sends[k] = join_sends(_load(getattr(a, "sends_" + k)),
                              _load(extra) if extra else None)
    snaps = build_inputs.build_swaps.snapshots_server([r for k in data for r in data[k]])
    tick_start = _first_tick_ms(a.ticks)
    ticks_name = os.path.basename(a.ticks)
    os.makedirs(a.out, exist_ok=True)
    sessions_path = getattr(a, "sessions", None)
    sessions_name = None
    if sessions_path:
        sessions_name = os.path.basename(sessions_path)
        with open(sessions_path, encoding="ascii") as src:
            sess_text = src.read()
        with open(os.path.join(a.out, sessions_name), "w", encoding="ascii", newline="\n") as dst:
            dst.write(sess_text)
    for (k, tag, w, _default_first), first in zip(FLEETS, first_ids):
        rows = data[k]
        start = build_inputs._init_server_ms(rows, w)
        gates = gate_codes(rows, start, window_end_ms)
        if gates:
            raise ValueError("%s: gate codes in the window: %s" % (tag, gates))
        segs = build_segments.segments(rows, start, window_end_ms)
        print("WINDOW", tag, start, window_end_ms, "segments", len(segs),
              [(first + i, s["from_ms"], s["to_ms"]) for i, s in enumerate(segs)])
        files = build_inputs.fleet_files(rows, tag, start, window_end_ms, first, ticks_name,
                                         snaps, [], sends=sends[k], sessions_file=sessions_name)
        for s in segs:
            warn = build_seeds.cap_warnings(build_seeds.seed_rows(rows, snaps, s["from_ms"]),
                                            s["cap"], s["from_ms"], tick_start)
            if warn:
                print("CAP_WARNING", tag, s["from_ms"], warn)
        for name, text in sorted(files.items()):
            with open(os.path.join(a.out, name), "w", encoding="ascii", newline="\n") as f:
                f.write(text)
            print(name, len(text.splitlines()) - 1, "rows")
    return 0


def main(argv=None):
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    j = sub.add_parser("join")
    for x in ("w2", "hold", "out"):
        j.add_argument("--" + x, required=True)
    b = sub.add_parser("build")
    b.add_argument("--out", required=True)
    b.add_argument("--ticks", required=True)
    b.add_argument("--window-end-ms", type=int, default=WINDOW_END_SERVER_MS)
    b.add_argument("--first-ids", default=",".join(str(f[3]) for f in FLEETS))
    b.add_argument("--sessions", default=None)
    for k, _t, _w, _f in FLEETS:
        b.add_argument("--" + k, required=True)
        b.add_argument("--sends-" + k, required=True)
        b.add_argument("--sends-extra-" + k, default=None)
    a = ap.parse_args(argv)
    return cmd_join(a) if a.cmd == "join" else cmd_build(a)


if __name__ == "__main__":
    sys.exit(main())
