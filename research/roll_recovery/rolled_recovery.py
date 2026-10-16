"""Rolled closes and recovery: did price come back through a rolled layer's original entry?
(docs/research/roll-geometry-notes-2026-10-15.md s7; backlog C153.) Read-only analysis of
`archive_counts.py --export-archive --instance <id>` files (JSON lines; a UTF-8 BOM is
tolerated). Standard library only (Python 3.9+).

    python research/roll_recovery/rolled_recovery.py <archive.jsonl> [<archive.jsonl> ...]

The price path is the instance's own MARKET fills: fill_logs rows with entry_type IN or OUT.
OUT_BY rows are excluded: a close-by's deal_price is the OTHER position's entry, not the market
(the first draft of 16 Oct used them and reported every rolled close as recovered).
A rolled close is a scalp_history row with rolled = true. "Recovered" = a later market fill at or
through the rolled layer's ORIGINAL entry (short: price <= entry; long: price >= entry). This is
hindsight about the realised loss, not the P&L of a hold policy (see the note, s7).
"""
import datetime as dt
import json
import statistics
import sys

PIP = 0.0001
DEFAULT_OFFSET_S = 10800          # broker time = UTC + 3 h (IC and FTMO, summer)
EPOCH = dt.datetime(1970, 1, 1)


def _utc(seconds):
    return dt.datetime.fromtimestamp(seconds, dt.timezone.utc).replace(tzinfo=None)


def load_rows(path):
    raw = open(path, "rb").read()
    if raw.startswith(b"\xef\xbb\xbf"):
        raw = raw[3:]
    return [json.loads(line) for line in raw.decode("utf-8").splitlines() if line.strip()]


def market_path(rows):
    """[(utc_seconds, price)] from fill_logs IN / OUT rows, oldest first."""
    pts = []
    for r in rows:
        if r.get("table") != "fill_logs" or r.get("entry_type") not in ("IN", "OUT"):
            continue
        px, msc = r.get("deal_price"), r.get("deal_time_broker_msc")
        if not isinstance(px, (int, float)) or not isinstance(msc, (int, float)):
            continue
        pts.append((msc / 1000.0 - DEFAULT_OFFSET_S, float(px)))
    pts.sort()
    return pts


def close_utc_seconds(r):
    t = dt.datetime.strptime(r["close_time_broker"], "%Y-%m-%d %H:%M:%S")
    return (t - EPOCH).total_seconds() - (r.get("broker_utc_offset_s") or DEFAULT_OFFSET_S)


def close_pips(r):
    e, c = r["entry_price"], r["exit_price"]
    return ((e - c) if r["direction"] == "SHORT" else (c - e)) / PIP


def recovery(r, path):
    """(hours to recover or None, best later price or None)."""
    t, e, short = close_utc_seconds(r), r["entry_price"], r["direction"] == "SHORT"
    later = [(ts, px) for ts, px in path if ts > t]
    if not later:
        return None, None
    best = min(px for _, px in later) if short else max(px for _, px in later)
    hit = next((ts for ts, px in later if (px <= e if short else px >= e)), None)
    return ((hit - t) / 3600.0 if hit is not None else None), best


def report(path_file):
    rows = load_rows(path_file)
    path = market_path(rows)
    sh = [r for r in rows if r.get("table") == "scalp_history"]
    rolled = sorted((r for r in sh if r.get("rolled")), key=close_utc_seconds)
    inst = next((r.get("instance_id") for r in rows if r.get("instance_id")), "?")
    cfg = [r for r in rows if r.get("table") == "config_events" and r.get("event") == "INIT"]
    geo = cfg[-1] if cfg else {}
    out = ["## %s (add %s, exit %s, cap %s at its last INIT)" % (
        inst, geo.get("add_pips"), geo.get("exit_pips"), geo.get("max_layers")), ""]
    if not path:
        out.append("no market fills")
        return "\n".join(out)
    end = path[-1][0]
    out.append("market path: %d fills, %s to %s UTC" % (
        len(path), _utc(path[0][0]).strftime("%Y-%m-%d %H:%M"),
        _utc(end).strftime("%Y-%m-%d %H:%M")))
    out += ["", "| close (UTC) | dir | entry | close | pips | best later | recovered after (h) |",
            "|---|---|---|---|---|---|---|"]
    hrs, never, young, total = [], 0, 0, 0.0
    for r in rolled:
        h, best = recovery(r, path)
        p = close_pips(r)
        total += p
        t = close_utc_seconds(r)
        if h is not None:
            hrs.append(h)
        elif end - t < 48 * 3600:
            young += 1
        else:
            never += 1
        out.append("| %s | %s | %.5f | %.5f | %.1f | %s | %s |" % (
            _utc(t).strftime("%m-%d %H:%M"), r["direction"], r["entry_price"],
            r["exit_price"], p, "%.5f" % best if best is not None else "-",
            "%.1f" % h if h is not None else "-"))
    out.append("")
    out.append("rolled closes %d, %.1f pips; recovered through the original entry %d; within 24 h %d; "
               "not recovered and older than 48 h %d; younger than 48 h %d" % (
                   len(rolled), total, len(hrs), sum(1 for h in hrs if h <= 24), never, young))
    if hrs:
        s = sorted(hrs)
        out.append("hours to recover: median %.1f, 25%% %.1f, 75%% %.1f, max %.1f" % (
            statistics.median(s), s[int(0.25 * (len(s) - 1))], s[int(0.75 * (len(s) - 1))], s[-1]))
    days = {}
    for r in sh:
        k = _utc(close_utc_seconds(r)).date()
        d = days.setdefault(k, [0, 0.0, 0, 0.0])
        if r.get("rolled") or r.get("ejected"):
            d[2] += 1
            d[3] += close_pips(r)
        else:
            d[0] += 1
            d[1] += close_pips(r)
    out += ["", "| day (UTC) | scalps | pips | rolled / ejected closes | pips | net |", "|---|---|---|---|---|---|"]
    for k in sorted(days):
        d = days[k]
        out.append("| %s | %d | %.1f | %d | %.1f | %.1f |" % (k, d[0], d[1], d[2], d[3], d[1] + d[3]))
    return "\n".join(out)


def main(argv):
    if not argv:
        print(__doc__)
        return 1
    print("\n\n".join(report(p) for p in argv))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
