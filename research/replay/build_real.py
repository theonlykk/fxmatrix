"""build_real.py -- the replay harness's real_<tag>.csv and intervals_<tag>.csv.

real_<tag>.csv (fix 1 A1; sync mode, T1): time_ms,kind,side,layer,price,position_id,level,
kind ENT / EXT / OUT_BY / ROLL, in time order, server ms. ENT applies a true layer (side,
layer, entry = price, ticket = position_id); EXT changes nothing; OUT_BY removes
position_id from the true book; ROLL sets the true VL of position_id to level.

From the archive:
- ENT / EXT = fill_logs IN rows: deal_time_broker_msc (server ms), side (the layer's side,
  as fill_logs records it on both roles), layer_index, deal_price, position_id;
- OUT_BY = fill_logs OUT_BY rows (side / layer null there): side and layer from the
  position's own IN row (an OUT_BY with no IN row is an error), price = deal_price;
- ROLL = ROLL_ACCEPTED: ea_time_ms (UTC) + SERVER_OFFSET_MS; side, layer_index, ticket and
  level from the detail (the row's own "level" is the log level).
Rows inside [from_ms, to_ms); same-ms fills by deal ticket, a roll after the fills of its ms.
Duplicate deal rows are read once.

intervals_<tag>.csv (base s3.2): kind,from_ms,to_ms (server ms; may hold no rows).

Standard library only; ascii, LF, no BOM.
"""
import json

REAL_HEADER = "time_ms,kind,side,layer,price,position_id,level"
INTERVALS_HEADER = "kind,from_ms,to_ms"
SERVER_OFFSET_MS = 3 * 3600 * 1000      # IC server GMT+3 (BOOT s6)


def _detail(r):
    d = r.get("detail")
    if isinstance(d, dict):
        return d
    return json.loads(d) if d else {}


def real_rows(rows, from_ms, to_ms):
    fills = []
    seen = set()
    for r in rows:
        if r.get("table") != "fill_logs":
            continue
        k = r.get("deal_ticket")
        if k is not None:
            if k in seen:
                continue
            seen.add(k)
        fills.append(r)
    ins = {int(f["position_id"]): f for f in fills if f.get("entry_type") == "IN"}
    keyed = []
    for f in fills:
        t = int(f["deal_time_broker_msc"])
        if not (from_ms <= t < to_ms):
            continue
        et = f.get("entry_type")
        pos = int(f["position_id"])
        if et == "IN":
            row = (t, f["role"], f["side"], int(f["layer_index"]), float(f["deal_price"]), pos, 0.0)
        elif et == "OUT_BY":
            src = ins.get(pos)
            if src is None:
                raise ValueError("OUT_BY on position %d has no IN row" % pos)
            row = (t, "OUT_BY", src["side"], int(src["layer_index"]), float(f["deal_price"]), pos, 0.0)
        else:
            continue
        keyed.append(((t, 0, int(f.get("deal_ticket") or 0)), row))
    for r in rows:
        if r.get("table") != "ea_events" or r.get("code") != "ROLL_ACCEPTED":
            continue
        t = int(r["ea_time_ms"]) + SERVER_OFFSET_MS
        if not (from_ms <= t < to_ms):
            continue
        d = _detail(r)
        keyed.append(((t, 1, 0), (t, "ROLL", d["side"], int(d["layer_index"]), 0.0,
                                  int(d["ticket"]), float(d["level"]))))
    keyed.sort(key=lambda kv: kv[0])
    return [row for _k, row in keyed]


def to_real_csv(real):
    lines = [REAL_HEADER]
    for t, kind, side, layer, price, pos, level in real:
        lines.append("%d,%s,%s,%d,%.5f,%d,%.5f" % (t, kind, side, layer, price, pos, level))
    return "\n".join(lines) + "\n"


def to_intervals_csv(intervals):
    lines = [INTERVALS_HEADER] + ["%s,%d,%d" % (k, a, b) for k, a, b in intervals]
    return "\n".join(lines) + "\n"
