"""Layer outcome by the UTC hour of entry: does a session gate (ADR-161) earn? (HANDOFF s89 continued 2)

Unit: one layer = one ENT position (an IN fill with role ENT). Its entry time is that fill's broker time
(GMT+3) in UTC; its outcome is the scalp_history row that closed it (scalped, rolled, ejected), linked by
the position's close fill, the direction, the entry price and the close time (within 2 s). A layer with no
close inside its era is open; a close with no scalp row is unlinked. Pre-registration: PREREG.md here.

Run: python research/session_hours/session_hours.py <archive dir> > research/session_hours/results.md
"""
import glob
import json
import os
import sys
from collections import defaultdict
from datetime import datetime, timedelta, timezone

BROKER_OFFSET_S = 10800                 # both brokers GMT+3 until 1 Nov (verified 25 Sep)
WINDOW_OPEN = timedelta(hours=11)       # ADR-161: 07:00 Toronto (EDT) = 11:00Z
WINDOW_CLOSE = timedelta(hours=20, minutes=55)   # 16:55 Toronto = 20:55Z
CLOSE_MATCH_S = 2
BLOCKS = ("ASIA", "LDN_AM", "LDN_NY", "NY_PM")  # 21-07Z, 07-11Z, 11-16Z, 16-21Z
MIN_PAIR_CLOSED = 20                    # a pair counts in the verdict with >= 20 closed layers each side

COMMISSION_BY_SUFFIX = {"OPT": 0.06, "OPTB": 0.08, "OPTD": 0.08}   # USD a closed layer (sr_table.py)

ERAS = {
    # A: FTMO 1514878887 on the IC strategy, 7 Oct 22:08Z attach to 21 Oct 21:46Z (Algo off).
    "A": ("OPT", datetime(2026, 10, 7, 22, 8, tzinfo=timezone.utc), datetime(2026, 10, 21, 21, 46, tzinfo=timezone.utc)),
    # B: IC 53066709, the gate build 7 Oct 02:25Z to Friday's close 23 Oct 21:00Z.
    "B": ("OPTB", datetime(2026, 10, 7, 2, 25, tzinfo=timezone.utc), datetime(2026, 10, 23, 21, 0, tzinfo=timezone.utc)),
    # D1: IC 53077984, the gate build to the two-arm rebuild's first flatten (21 Oct 14:50Z).
    "D1": ("OPTD", datetime(2026, 10, 7, 2, 25, tzinfo=timezone.utc), datetime(2026, 10, 21, 14, 50, tzinfo=timezone.utc)),
    # D2: D's t1 OPT after the rebuild (reported, not deciding: two days).
    "D2": ("OPTD", datetime(2026, 10, 21, 15, 55, tzinfo=timezone.utc), datetime(2026, 10, 23, 21, 0, tzinfo=timezone.utc)),
}
DECIDING = ("A", "B", "D1")
EPISODE_DATES = ("2026-10-07", "2026-10-14", "2026-10-15", "2026-10-16")   # UTC entry dates (roll flurries)


def broker_to_utc(s):
    t = datetime.strptime(s, "%Y-%m-%d %H:%M:%S").replace(tzinfo=timezone.utc)
    return t - timedelta(seconds=BROKER_OFFSET_S)


def block(dt):
    h = dt.hour
    if h >= 21 or h < 7:
        return "ASIA"
    if h < 11:
        return "LDN_AM"
    if h < 16:
        return "LDN_NY"
    return "NY_PM"


def in_window(dt):
    if dt.weekday() >= 5:
        return False
    since = timedelta(hours=dt.hour, minutes=dt.minute, seconds=dt.second)
    return WINDOW_OPEN <= since < WINDOW_CLOSE


def _key_price(p):
    return round(float(p), 6)


def layers(records):
    fills, scalps = {}, []
    for r in records:
        t = r.get("table")
        if t == "fill_logs":
            fills.setdefault(r["deal_ticket"], r)
        elif t == "scalp_history":
            off = r.get("broker_utc_offset_s")
            if off is not None and int(off) != BROKER_OFFSET_S:
                raise ValueError(f"broker offset {off} on a scalp row, expected {BROKER_OFFSET_S}")
            scalps.append(r)
    ents = [f for f in fills.values() if f.get("entry_type") == "IN" and f.get("role") == "ENT"]
    closes = defaultdict(list)
    for f in fills.values():
        if f.get("entry_type") in ("OUT_BY", "OUT"):
            closes[f["position_id"]].append(f)
    unused = defaultdict(list)   # (instance, direction, price) -> scalp rows not yet used
    for s in scalps:
        unused[(s["instance_id"], s["direction"], _key_price(s["entry_price"]))].append(s)
    out = []
    for e in sorted(ents, key=lambda f: (f["deal_time_broker"], f["deal_ticket"])):
        L = {"instance_id": e["instance_id"], "position_id": e["position_id"], "side": e.get("side"),
             "layer_index": e.get("layer_index"), "entry_price": e["deal_price"],
             "entry_utc": broker_to_utc(e["deal_time_broker"]), "close_utc": None, "status": "open", "gross": None}
        cl = sorted(closes.get(e["position_id"], []), key=lambda f: f["deal_time_broker"])
        if cl:
            c = cl[0]
            L["close_utc"] = broker_to_utc(c["deal_time_broker"])
            direction = "LONG" if e.get("side") == "L" else "SHORT"
            pool = unused[(e["instance_id"], direction, _key_price(e["deal_price"]))]
            match = None
            for s in pool:
                if abs((broker_to_utc(s["close_time_broker"]) - L["close_utc"]).total_seconds()) <= CLOSE_MATCH_S:
                    match = s
                    break
            if match is None:
                L["status"] = "unlinked"
            else:
                pool.remove(match)
                L["gross"] = float(match["gross_pnl"])
                L["status"] = "ejected" if match.get("ejected") else ("rolled" if match.get("rolled") else "scalped")
        out.append(L)
    return out


def in_era(layers_, start, end):
    out = []
    for L in layers_:
        if not (start <= L["entry_utc"] < end):
            continue
        L = dict(L)
        if L.get("close_utc") is None or L["close_utc"] >= end:
            L["status"], L["gross"] = "open", None
        out.append(L)
    return out


def summarise(layers_, commission):
    closed = [L for L in layers_ if L["status"] in ("scalped", "rolled", "ejected")]
    gross = sum(L["gross"] for L in closed)
    net = gross - commission * len(closed)
    rolled = sum(1 for L in closed if L["status"] == "rolled")
    return {"entered": len(layers_), "closed": len(closed),
            "scalped": sum(1 for L in closed if L["status"] == "scalped"), "rolled": rolled,
            "ejected": sum(1 for L in closed if L["status"] == "ejected"),
            "open": sum(1 for L in layers_ if L["status"] == "open"),
            "unlinked": sum(1 for L in layers_ if L["status"] == "unlinked"),
            "gross": gross, "net": net,
            "net_per_closed": (net / len(closed)) if closed else None,
            "roll_rate": (rolled / len(closed)) if closed else None}


def _direction(e):
    if e["counted"] == 0:
        return None
    if e["net_out"] < e["net_in"] and e["rr_out"] > e["rr_in"] and 2 * e["worse_out"] >= e["counted"]:
        return "OUTSIDE WORSE"
    if e["net_in"] < e["net_out"] and e["rr_in"] > e["rr_out"] and 2 * e["worse_in"] >= e["counted"]:
        return "INSIDE WORSE"
    return None


def verdict(eras):
    dirs = [_direction(e) for e in eras.values()]
    for d in ("OUTSIDE WORSE", "INSIDE WORSE"):
        if dirs.count(d) >= 2:
            return ("WORTH A REPLAY", d)
    return ("NOT WORTH IT", None)


# ---------------------------------------------------------------- the report (not unit-tested; tables only)

def _load(path):
    with open(path, encoding="utf-8-sig") as fh:
        lines = fh.read().splitlines()
    return [json.loads(x) for x in lines[1:] if x.strip()]


def _fmt(v, d=2):
    return "-" if v is None else (f"{v:+.{d}f}" if isinstance(v, float) else str(v))


def _row(label, s):
    rr = "-" if s["roll_rate"] is None else f"{100 * s['roll_rate']:.1f}%"
    return (f"| {label} | {s['entered']} | {s['closed']} | {s['scalped']} | {s['rolled']} | {s['open']} | "
            f"{s['unlinked']} | {_fmt(s['net'])} | {_fmt(s['net_per_closed'], 3)} | {rr} |")


HEAD = ("| | entered | closed | scalped | rolled | open | unlinked | net USD | net / closed | roll rate |\n"
        "|---|---|---|---|---|---|---|---|---|---|")


def report(archive_dir):
    by_era = {}
    out = []
    for era, (suffix, start, end) in ERAS.items():
        files = sorted(glob.glob(os.path.join(archive_dir, f"archive_*_{suffix}_*.jsonl")))
        com = COMMISSION_BY_SUFFIX[suffix]
        per_pair = {}
        for f in files:
            pair = os.path.basename(f).split("_")[1]
            per_pair[pair] = in_era(layers(_load(f)), start, end)
        by_era[era] = (per_pair, com)
        allL = [L for v in per_pair.values() for L in v]
        out.append(f"\n## {era}: {start:%d %b %H:%MZ} to {end:%d %b %H:%MZ} ({len(files)} pairs, commission {com})\n")
        out.append("**Inside / outside ADR-161's window (entry time):**\n\n" + HEAD)
        for lab, sel in (("inside 11:00-20:55Z", True), ("outside", False)):
            out.append(_row(lab, summarise([L for L in allL if in_window(L["entry_utc"]) == sel], com)))
        out.append("\n**By block (entry hour, UTC):**\n\n" + HEAD)
        for b in BLOCKS:
            out.append(_row(b, summarise([L for L in allL if block(L["entry_utc"]) == b], com)))
        out.append("\n**Episode days (entry date 7, 14, 15, 16 Oct) and the rest, inside / outside:**\n\n" + HEAD)
        for ep in (True, False):
            for sel in (True, False):
                sub = [L for L in allL if (L["entry_utc"].strftime("%Y-%m-%d") in EPISODE_DATES) == ep
                       and in_window(L["entry_utc"]) == sel]
                out.append(_row(f"{'episode' if ep else 'other days'}, {'inside' if sel else 'outside'}",
                                summarise(sub, com)))
        out.append("\n**Per pair, inside / outside:**\n\n" + HEAD)
        for pair, v in sorted(per_pair.items()):
            for sel in (True, False):
                out.append(_row(f"{pair} {'in' if sel else 'out'}",
                                summarise([L for L in v if in_window(L["entry_utc"]) == sel], com)))
    eras_v = {}
    for era in DECIDING:
        per_pair, com = by_era[era]
        allL = [L for v in per_pair.values() for L in v]
        si = summarise([L for L in allL if in_window(L["entry_utc"])], com)
        so = summarise([L for L in allL if not in_window(L["entry_utc"])], com)
        wo = wi = cnt = 0
        for v in per_pair.values():
            a = summarise([L for L in v if in_window(L["entry_utc"])], com)
            b = summarise([L for L in v if not in_window(L["entry_utc"])], com)
            if a["closed"] >= MIN_PAIR_CLOSED and b["closed"] >= MIN_PAIR_CLOSED:
                cnt += 1
                wo += b["net_per_closed"] < a["net_per_closed"]
                wi += a["net_per_closed"] < b["net_per_closed"]
        eras_v[era] = dict(net_in=si["net_per_closed"] or 0.0, net_out=so["net_per_closed"] or 0.0,
                           rr_in=si["roll_rate"] or 0.0, rr_out=so["roll_rate"] or 0.0,
                           worse_out=wo, worse_in=wi, counted=cnt)
    v = verdict(eras_v)
    head = ["# Session hours: layer outcome by entry time (results; PREREG.md is the rule)", "",
            f"**VERDICT (pre-registered rule): {v[0]}{'' if v[1] is None else ' -- ' + v[1]}**", "",
            "| era | net / closed in | out | roll rate in | out | pairs: outside worse | inside worse | counted | direction |",
            "|---|---|---|---|---|---|---|---|---|"]
    for era, e in eras_v.items():
        head.append(f"| {era} | {e['net_in']:+.3f} | {e['net_out']:+.3f} | {100 * e['rr_in']:.1f}% | "
                    f"{100 * e['rr_out']:.1f}% | {e['worse_out']} | {e['worse_in']} | {e['counted']} | "
                    f"{_direction(e) or 'none'} |")
    return "\n".join(head + out) + "\n"


if __name__ == "__main__":
    sys.stdout.write(report(sys.argv[1]))
