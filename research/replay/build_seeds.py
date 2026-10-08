"""build_seeds.py -- the replay harness's seed_<seg_id>.csv files.

Base prompt s3.2: seed = side,layer_index,entry,open_ms,ticket,vl,swap,volume
(times SERVER ms; vl 0 = not rolled; swap in account currency). Plan s3: every
segment after D's flat attach starts at an init from the TRUE open positions at
that moment, rebuilt from fill_logs:

- open = an IN ENT deal before the init (deal_time_broker_msc, server ms) with
  no OUT / OUT_BY on its position before the init; an IN EXT position still
  open at an init is an error (the harness seeds layers only; none found on the
  29 inits, previous chat 8 Oct ~20:20Z);
- vl = the detail "level" of the latest ROLL_ACCEPTED for the ticket before the
  init (ea_time_ms is UTC: + SERVER_OFFSET_MS); the row's own "level" is the log
  level ("INFO");
- swap = build_swaps.predict_swap from the open to the init, to the cent (the
  broker's POSITION_SWAP, which the EA's carry ledger reads at init: 69 of 69
  CARRY_EXIT_SHIFT accrued_ledger_pips agree, HANDOFF s73).

cap_warnings: a seeded side AT CAP tracks the lattice from its newest open (at
most GRIND_VL_CATCHUP_MAX_SEC = 24 h back), so its preload needs ticks from
max(newest open, init - 24 h); warn when the tick file starts later.

Standard library only.
"""
import datetime as dt
import json

import build_swaps

SEED_HEADER = "side,layer_index,entry,open_ms,ticket,vl,swap,volume"
SERVER_OFFSET_MS = 3 * 3600 * 1000      # IC server GMT+3 (BOOT s6)
CATCHUP_MS = 86400 * 1000              # GRIND_VL_CATCHUP_MAX_SEC
_EPOCH = dt.datetime(1970, 1, 1)


def _detail(r):
    d = r.get("detail")
    if isinstance(d, dict):
        return d
    return json.loads(d) if d else {}


def _fills(rows):
    seen = set()
    out = []
    for r in rows:
        if r.get("table") != "fill_logs":
            continue
        key = r.get("deal_ticket")
        if key is not None:
            if key in seen:
                continue
            seen.add(key)
        out.append(r)
    return out


def open_positions(rows, at_ms):
    fills = _fills(rows)
    closed = set()
    for f in fills:
        if f.get("entry_type") in ("OUT", "OUT_BY") and int(f["deal_time_broker_msc"]) < at_ms:
            closed.add(int(f["position_id"]))
    out = []
    for f in fills:
        if f.get("entry_type") != "IN" or int(f["deal_time_broker_msc"]) >= at_ms:
            continue
        pos = int(f["position_id"])
        if pos in closed:
            continue
        if f.get("role") != "ENT":
            raise ValueError("position %d (%s) is open at %d" % (pos, f.get("role"), at_ms))
        out.append({"side": f["side"], "layer_index": int(f["layer_index"]),
                    "entry": float(f["deal_price"]), "open_ms": int(f["deal_time_broker_msc"]),
                    "ticket": pos, "volume": float(f["volume"])})
    out.sort(key=lambda p: (0 if p["side"] == "L" else 1, p["layer_index"]))
    return out


def latest_vl(rows, ticket, at_ms):
    best_t = None
    best = 0.0
    for r in rows:
        if r.get("table") != "ea_events" or r.get("code") != "ROLL_ACCEPTED":
            continue
        d = _detail(r)
        if int(d.get("ticket", r.get("ticket") or 0)) != int(ticket):
            continue
        t = int(r["ea_time_ms"]) + SERVER_OFFSET_MS
        if t >= at_ms:
            continue
        if best_t is None or t > best_t:
            best_t = t
            best = float(d["level"])
    return best


def _srv_dt(ms):
    return _EPOCH + dt.timedelta(milliseconds=ms)


def seed_rows(rows, snaps, at_ms):
    out = []
    for p in open_positions(rows, at_ms):
        sw = build_swaps.predict_swap(snaps, p["side"], _srv_dt(p["open_ms"]), _srv_dt(at_ms),
                                      p["volume"])
        q = dict(p)
        q["vl"] = latest_vl(rows, p["ticket"], at_ms)
        q["swap"] = round(sw, 2) + 0.0
        out.append(q)
    return out


def to_seed_csv(seed):
    lines = [SEED_HEADER]
    for p in seed:
        lines.append("%s,%d,%.5f,%d,%d,%.5f,%.2f,%.2f" % (
            p["side"], p["layer_index"], p["entry"], p["open_ms"], p["ticket"],
            p["vl"], p["swap"], p["volume"]))
    return "\n".join(lines) + "\n"


def cap_warnings(seed, cap, from_ms, tick_start_ms):
    out = []
    for side in ("L", "S"):
        layers = [p for p in seed if p["side"] == side]
        if len(layers) < cap:
            continue
        start = max(max(p["open_ms"] for p in layers), from_ms - CATCHUP_MS)
        if start < tick_start_ms:
            out.append((side, len(layers), start))
    return out
