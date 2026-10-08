"""build_segments.py -- the replay harness's run_<tag>.csv rows.

Base prompt s3.2: one row per segment,
seg_id,instance,magic,from_ms,to_ms,width_l,width_s,add_l,add_s,exit_l,exit_s,
cap,stranded,deadband,lattice,reroll,gate,carry,fill_time_place,reserve,
seed_file,ticks_file (times SERVER ms).

Plan s2: a segment runs from each INIT to the next INIT (every input change
and compile is an init) or to the window end. The archive's ea_time_ms is UTC
epoch ms (B's 7 Oct INIT received 02:18:04Z has ea_time_ms 1791339483005 =
02:18:03.005Z); the run file wants SERVER ms, so +3 h (SERVER_OFFSET_MS).
Window bounds are passed in server ms. Per segment: the INIT row's inputs (per-side width / add / exit,
max_layers, stranded, deadband, enable_carry_pass) and the LATTICE_CONFIG the
same init wrote (enable; reroll and roll_gate absent before their builds =
off / -1). Fill-time place ON and reserve 8 in every EURUSD preset over the
window (git: 0335f25, 2859be6, b438420, 5bb5fdb).

Standard library only.
"""
import json

RUN_HEADER = ("seg_id,instance,magic,from_ms,to_ms,width_l,width_s,add_l,add_s,exit_l,exit_s,"
              "cap,stranded,deadband,lattice,reroll,gate,carry,fill_time_place,reserve,"
              "seed_file,ticks_file")
SERVER_OFFSET_MS = 3 * 3600 * 1000   # IC server GMT+3 (BOOT s6)
LATTICE_MATCH_MS = 2000       # a LATTICE_CONFIG belongs to the init within 2 s of it
FILL_TIME_PLACE = 1
RESERVE = 8


def _obj(x):
    if isinstance(x, dict):
        return x
    return json.loads(x) if x else {}


def segments(rows, window_from_ms, window_to_ms):
    inits = sorted((r for r in rows if r.get("table") == "config_events" and r.get("event") == "INIT"),
                   key=lambda r: int(r["ea_time_ms"]))
    lats = [r for r in rows if r.get("table") == "ea_events" and r.get("code") == "LATTICE_CONFIG"]
    srv = lambda r: int(r["ea_time_ms"]) + SERVER_OFFSET_MS
    inits = [r for r in inits if window_from_ms <= srv(r) < window_to_ms]
    if not inits or srv(inits[0]) != window_from_ms:
        raise ValueError("the window must start at an INIT (%d)" % window_from_ms)
    out = []
    for i, r in enumerate(inits):
        t = srv(r)
        nxt = srv(inits[i + 1]) if i + 1 < len(inits) else window_to_ms
        near = [x for x in lats if abs(srv(x) - t) <= LATTICE_MATCH_MS]
        if len(near) != 1:
            raise ValueError("init at %d has %d LATTICE_CONFIG within %d ms" % (t, len(near), LATTICE_MATCH_MS))
        lat = _obj(near[0]["detail"])
        inp = _obj(r["inputs"])
        out.append({
            "instance": r["instance_id"], "magic": int(r["magic"]),
            "from_ms": t, "to_ms": nxt,
            "width_l": float(inp["width_pips_long"]), "width_s": float(inp["width_pips_short"]),
            "add_l": float(inp["add_pips_long"]), "add_s": float(inp["add_pips_short"]),
            "exit_l": float(inp["exit_pips_long"]), "exit_s": float(inp["exit_pips_short"]),
            "cap": int(r["max_layers"]),
            "stranded": float(inp["stranded_thresh_pips"]), "deadband": float(inp["deadband_pips"]),
            "lattice": 1 if lat.get("enable") else 0,
            "reroll": 1 if lat.get("reroll") else 0,
            "gate": int(lat.get("roll_gate", -1)),
            "carry": 1 if inp.get("enable_carry_pass") else 0,
            "fill_time_place": FILL_TIME_PLACE, "reserve": RESERVE,
        })
    return out


def to_run_csv(segs, ticks_file, seed_names, first_id=1):
    if len(seed_names) != len(segs):
        raise ValueError("one seed name per segment")
    lines = [RUN_HEADER]
    for k, s in enumerate(segs):
        lines.append(",".join(str(v) for v in (
            first_id + k, s["instance"], s["magic"], s["from_ms"], s["to_ms"],
            s["width_l"], s["width_s"], s["add_l"], s["add_s"], s["exit_l"], s["exit_s"],
            s["cap"], s["stranded"], s["deadband"], s["lattice"], s["reroll"], s["gate"],
            s["carry"], s["fill_time_place"], s["reserve"], seed_names[k], ticks_file)))
    return "\n".join(lines) + "\n"
