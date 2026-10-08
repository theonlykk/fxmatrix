"""build_inputs.py -- the replay harness's input files per fleet (base prompt s3.2, fix 1 A1).

Per fleet tag (eurusd_b / eurusd_c / eurusd_d; seg_id global: B 1-9, C 10-19, D 20-29,
HANDOFF s73): run_<tag>.csv (build_segments), seed_<seg_id>.csv for every segment that
does not start flat (build_seeds; the run row names it, or leaves it empty), real_<tag>.csv
over the whole window (build_real; the harness keeps each segment's own rows) and
intervals_<tag>.csv (header only when none). swaps.csv comes from build_swaps.py.

    python -B research/replay/build_inputs.py --out DIR --ticks ticks_53077984_EURUSD_w2.csv \
        --tick-start-ms MS --b ARCHIVE_B --c ARCHIVE_C --d ARCHIVE_D

Standard library only; ascii, LF, no BOM.
"""
import argparse
import datetime as dt
import json
import os
import sys

import build_real
import build_seeds
import build_segments
import build_swaps

SERVER_OFFSET_MS = 3 * 3600 * 1000
# Plan s2: each fleet's window starts at its lattice init (UTC); round 2 ends 8 Oct 22:00Z.
FLEETS = (("b", "eurusd_b", "2026-10-01T03:58:52", 1),
          ("c", "eurusd_c", "2026-10-01T04:14:28", 10),
          ("d", "eurusd_d", "2026-10-01T05:12:58", 20))
WINDOW_END_SERVER_MS = 1791507600000          # 2026.10.09 01:00:00 server = 8 Oct 22:00Z
# Plan s12, s4.2 check 3: D's API soft warn, server 2026.10.01 22:30:58 - 2026.10.02 00:00:00.
INTERVALS = {"eurusd_d": [("API_SOFT_WARN", 1790893858000, 1790899200000)]}


def fleet_files(rows, tag, window_from_ms, window_to_ms, first_id, ticks_file, snaps, intervals):
    segs = build_segments.segments(rows, window_from_ms, window_to_ms)
    files = {}
    names = []
    for k, s in enumerate(segs):
        seed = build_seeds.seed_rows(rows, snaps, s["from_ms"])
        if seed:
            name = "seed_%d.csv" % (first_id + k)
            files[name] = build_seeds.to_seed_csv(seed)
            names.append(name)
        else:
            names.append("")
    files["run_%s.csv" % tag] = build_segments.to_run_csv(segs, ticks_file, names, first_id)
    files["real_%s.csv" % tag] = build_real.to_real_csv(
        build_real.real_rows(rows, window_from_ms, window_to_ms))
    files["intervals_%s.csv" % tag] = build_real.to_intervals_csv(intervals)
    return files


def _load(path):
    with open(path, encoding="utf-8-sig") as f:
        return [json.loads(line) for line in f if line.strip()]


def _init_server_ms(rows, utc_iso):
    """The INIT whose ea_time_ms falls in the plan's window-start second (UTC), in server ms."""
    t0 = int((dt.datetime.fromisoformat(utc_iso) - dt.datetime(1970, 1, 1)).total_seconds() * 1000)
    hits = [int(r["ea_time_ms"]) for r in rows if r.get("table") == "config_events"
            and r.get("event") == "INIT" and t0 <= int(r["ea_time_ms"]) < t0 + 1000]
    if len(hits) != 1:
        raise ValueError("%d INIT rows at %s" % (len(hits), utc_iso))
    return hits[0] + SERVER_OFFSET_MS


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--ticks", required=True)
    ap.add_argument("--tick-start-ms", type=int, required=True)
    ap.add_argument("--end-ms", type=int, default=WINDOW_END_SERVER_MS)
    for k, _t, _w, _f in FLEETS:
        ap.add_argument("--" + k, required=True)
    a = ap.parse_args(argv)
    data = {k: _load(getattr(a, k)) for k, _t, _w, _f in FLEETS}
    snaps = build_swaps.snapshots_server([r for k in data for r in data[k]])
    os.makedirs(a.out, exist_ok=True)
    for k, tag, w, first in FLEETS:
        rows = data[k]
        start = _init_server_ms(rows, w)
        files = fleet_files(rows, tag, start, a.end_ms, first, a.ticks, snaps, INTERVALS.get(tag, []))
        for s in build_segments.segments(rows, start, a.end_ms):
            warn = build_seeds.cap_warnings(build_seeds.seed_rows(rows, snaps, s["from_ms"]),
                                            s["cap"], s["from_ms"], a.tick_start_ms)
            if warn:
                print("CAP_WARNING", tag, s["from_ms"], warn)
        for name, text in sorted(files.items()):
            with open(os.path.join(a.out, name), "w", encoding="ascii", newline="\n") as f:
                f.write(text)
            print(name, len(text.splitlines()) - 1, "rows")
    return 0


if __name__ == "__main__":
    sys.exit(main())
