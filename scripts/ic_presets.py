#!/usr/bin/env python3
"""IC presets for the cap-10 reload and round 2 (cap10-reload s2-s3; compass-round s4-s6).

    python scripts/ic_presets.py --table scripts/ic_geometry.json --stage c10 [--write]
    python scripts/ic_presets.py --table scripts/ic_geometry.json --stage p2 [--write]
    python scripts/ic_presets.py --table scripts/ic_geometry_r2.json --stage round [--write]
    python -m unittest scripts/test_ic_presets.py -v

Two stages, two reloads (cap10-reload GW-1):
- c10: each chart's LIVE preset (B *_b_lat; C and D *_p1 on the probed pairs,
  *_lat on the anchored ones) with ONLY InpMaxLayers 10, InpWidthPips = the
  pair's fixed width, InpStrandedThreshPips = width + 1 and InpConfigWarning
  changed. Add and exit stay as round 1 ran them. Scouts (AUDUSD) already have
  their c10 presets (4694471) and are only validated.
- p2: round 2's values per fleet and SIDE on top of c10: B the verdict anchor,
  C the add probe (anchor exit), D the exit probe (anchor add), the control
  pair and scouts the anchor on every fleet.
Width per pair = ceil to the half pip of (max(anchor add L, S) + 2) / 4
(compass-round s6, GC-7): room for one-pip add probes on either side inside
the ADR-153 guard (0.5 <= add / width <= 4.0). Per side: equal sides write the
base input with the per-side inputs -1; different sides write the base = the
long value and BOTH per-side inputs explicitly (the base must pass the guard
too: fxgrind.mq5 174-200).
Stage "round" (memo 2026-10-05: this week at cap 8): one reload per chart from its
LIVE preset with the round's width (the tightest the guard allows for every add any
fleet runs on the pair: ceil_0.5(max add / 4)), S = W + 1, the table's deadband and
cap, and B / C / D's add and exit per side, into <pair>_opt_<f>_r<N>.set.
A table's "roll_gate" ({"B": n, "C": n, "D": n}; C133, ADR-166) also writes
InpRollGateOpposite per fleet and InpApiEntryStop / InpApiSoftWarn (v2.2a) at the EA's
input positions; without it the presets are written as before.
Without --write nothing is written: a summary and every check is printed.
"""
import argparse
import json
import math
import os
import sys

FLEETS = ("B", "C", "D")
ACCOUNT = {"B": ("IC Markets demo 53066709", "wine-test"),
           "C": ("IC Markets demo 53071896", "wine-c"),
           "D": ("IC Markets demo 53077984", "wine-d")}
GUARD_MIN, GUARD_MAX = 0.5, 4.0
ADD_FLOOR = 3          # half pips and adds below 3 are OPEN (compass-round s9)
HALF_FLOOR = 2.5       # a C add probe marked "half" (operator 6 Oct, round 2 EURGBP long)
CAP = 10
DEADBAND = "4.0"
EPS = 1e-9
API_ENTRY_STOP = 1000000   # v2.2a C100 inputs: the EA defaults (fxgrind.mq5 42-43), written so the read-back shows them
API_SOFT_WARN = 999000
C10_CHANGES = {"InpMaxLayers", "InpWidthPips", "InpStrandedThreshPips", "InpConfigWarning"}


# ---------------------------------------------------------------- preset text

def parse(text):
    """[(key, value), ...] in file order; blank lines and lines without '=' dropped."""
    out = []
    for line in text.splitlines():
        line = line.strip()
        if not line or "=" not in line:
            continue
        k, _, v = line.partition("=")
        out.append((k.strip(), v.strip()))
    return out


def render(pairs):
    return "".join("%s=%s\n" % (k, v) for k, v in pairs)


def _set(pairs, updates):
    missing = set(updates) - {k for k, _ in pairs}
    if missing:
        raise KeyError("preset lacks %s" % sorted(missing))
    return [(k, updates.get(k, v)) for k, v in pairs]


def _num(x):
    return "%.1f" % float(x)


# ---------------------------------------------------------------- geometry rules

def width_for(add_l, add_s):
    return math.ceil((max(float(add_l), float(add_s)) + 2.0) / 4.0 * 2.0 - EPS) / 2.0


def guard_ok(width, add):
    r = float(add) / float(width)
    return GUARD_MIN - EPS <= r <= GUARD_MAX + EPS


def side_fields(kind, val_l, val_s):
    base = "Inp%sPips" % kind
    if abs(float(val_l) - float(val_s)) < EPS:
        return {base: _num(val_l), base + "Long": "-1.0", base + "Short": "-1.0"}
    return {base: _num(val_l), base + "Long": _num(val_l), base + "Short": _num(val_s)}


def resolved(p, kind):
    base = float(p["Inp%sPips" % kind])
    out = []
    for side in ("Long", "Short"):
        v = float(p["Inp%sPips%s" % (kind, side)])
        out.append(base if v < 0 else v)
    return tuple(out)


def _warning(fleet, text):
    acct, box = ACCOUNT[fleet]
    return "FLEET %s %s (%s, %s)" % (fleet, text, acct, box)


def c10(base_text, width, fleet, pair):
    w = float(width)
    pairs = _set(parse(base_text), {
        "InpMaxLayers": str(CAP),
        "InpWidthPips": _num(w),
        "InpStrandedThreshPips": _num(w + 1.0),
        "InpConfigWarning": _warning(fleet, "cap-10 reload: cap 10, width %s fixed per pair, "
                                            "S = W + 1; add/exit as round 1; lattice + reroll on"
                                     % _num(w)),
    })
    return render(pairs)


def p2(c10_text, adds, exits, fleet, pair, role):
    p = dict(parse(c10_text))
    upd = {}
    upd.update(side_fields("Add", adds[0], adds[1]))
    upd.update(side_fields("Exit", exits[0], exits[1]))
    upd["InpConfigWarning"] = _warning(fleet, "round 2 %s %s: cap 10, width %s; lattice + reroll on"
                                       % (pair, role, p["InpWidthPips"]))
    return render(_set(parse(c10_text), upd))


# ---------------------------------------------------------------- the table

def load_table(path):
    with open(path) as fh:
        return json.load(fh)


def _anchor(geo, pair):
    a = geo["pairs"][pair]["anchor"]
    return (a["L"]["add"], a["S"]["add"]), (a["L"]["exit"], a["S"]["exit"])


def pair_width(geo, pair):
    adds, _exits = _anchor(geo, pair)
    return width_for(*adds)


def p2_values(geo):
    """{(pair, fleet): ((add_L, add_S), (exit_L, exit_S), role)}"""
    out = {}
    scouts = set(geo.get("scouts", []))
    for pair, spec in geo["pairs"].items():
        adds, exits = _anchor(geo, pair)
        for f in FLEETS:
            if pair == geo.get("control"):
                out[(pair, f)] = (adds, exits, "control (anchor)")
            elif pair in scouts:
                out[(pair, f)] = (adds, exits, "scout baseline")
            elif f == "B":
                out[(pair, f)] = (adds, exits, "anchor")
            elif f == "C":
                out[(pair, f)] = ((spec["C"]["L"]["add"], spec["C"]["S"]["add"]), exits, "ADD probe")
            else:
                out[(pair, f)] = (adds, (spec["D"]["L"]["exit"], spec["D"]["S"]["exit"]), "EXIT probe")
    return out


def check_plan(geo):
    errs = []
    scouts = set(geo.get("scouts", []))
    for pair, spec in geo["pairs"].items():
        adds, exits = _anchor(geo, pair)
        w = pair_width(geo, pair)
        fixed = pair == geo.get("control") or pair in scouts
        if fixed and ("C" in spec or "D" in spec):
            errs.append("%s is the control or a scout: never probed" % pair)
        for i, side in enumerate(("L", "S")):
            if adds[i] < ADD_FLOOR:
                errs.append("%s anchor %s add %s below the add-%d floor" % (pair, side, adds[i], ADD_FLOOR))
            for a in (adds[i] - 1, adds[i], adds[i] + 1):        # headroom for one-pip add probes
                if a >= ADD_FLOOR and not guard_ok(w, a):
                    errs.append("%s %s add %s / width %s outside the guard" % (pair, side, a, w))
            if fixed:
                continue
            for fleet, kind, anchor in (("C", "add", adds[i]), ("D", "exit", exits[i])):
                try:
                    v = spec[fleet][side][kind]
                except KeyError:
                    errs.append("%s %s %s: no %s probe" % (pair, fleet, side, kind))
                    continue
                if spec[fleet][side].get("half"):
                    if kind != "add":
                        errs.append("%s %s %s: half pips on add probes only" % (pair, fleet, side))
                        continue
                    if abs(abs(v - anchor) - 0.5) > EPS:
                        errs.append("%s %s %s: half probe %s is not half a pip from the anchor %s"
                                    % (pair, fleet, side, v, anchor))
                    if v < HALF_FLOOR - EPS:
                        errs.append("%s %s %s: add probe %s below the half-pip floor %s"
                                    % (pair, fleet, side, v, HALF_FLOOR))
                    continue
                if abs(abs(v - anchor) - 1) > EPS:
                    errs.append("%s %s %s: %s probe %s is not one pip from the anchor %s"
                                % (pair, fleet, side, kind, v, anchor))
                if kind == "add" and v < ADD_FLOOR:
                    errs.append("%s %s %s: add probe %s below the add-%d floor" % (pair, fleet, side, v, ADD_FLOOR))
    return errs + check_roll_gate(geo)


def check_roll_gate(geo):
    """A table's optional "roll_gate" (ADR-166): {"B": n, "C": n, "D": n}, each an int >= -1
    (-1 = off, the EA's default). Absent: presets are written without the v2.2a / ADR-166 keys."""
    rg = geo.get("roll_gate")
    if rg is None:
        return []
    if not isinstance(rg, dict):
        return ["roll_gate must be {\"B\": n, \"C\": n, \"D\": n}"]
    errs = []
    for f in FLEETS:
        if f not in rg:
            errs.append("roll_gate: fleet %s missing" % f)
            continue
        v = rg[f]
        if isinstance(v, bool) or not isinstance(v, int) or v < -1:
            errs.append("roll_gate %s: %r is not an int >= -1" % (f, v))
    return errs


def with_v22_keys(pairs, gate):
    """pairs with InpRollGateOpposite = gate inserted after InpLatticeReroll and InpApiEntryStop /
    InpApiSoftWarn after InpEntryHorizonPips (fxgrind.mq5 input order); a key already present is
    set, not duplicated."""
    new = {"InpRollGateOpposite": str(int(gate)), "InpApiEntryStop": str(API_ENTRY_STOP),
           "InpApiSoftWarn": str(API_SOFT_WARN)}
    after = {"InpLatticeReroll": ["InpRollGateOpposite"],
             "InpEntryHorizonPips": ["InpApiEntryStop", "InpApiSoftWarn"]}
    keys = {k for k, _ in pairs}
    missing = set(after) - keys
    if missing:
        raise KeyError("preset lacks %s" % sorted(missing))
    out = []
    for k, v in pairs:
        if k in new:
            continue
        out.append((k, v))
        for nk in after.get(k, []):
            out.append((nk, new[nk]))
    return out


def validate(base_text, out_text, width, cap=None, deadband=None, gate=None):
    """gate None: the output keeps the base's keys and order exactly. gate n: the base's keys
    plus InpRollGateOpposite = n and the two API inputs at the EA's positions (with_v22_keys)."""
    errs = []
    a, b = parse(base_text), parse(out_text)
    if gate is None:
        if [k for k, _ in a] != [k for k, _ in b]:
            return ["keys or their order differ from the base preset"]
    else:
        have = dict(b)
        for k, want in (("InpRollGateOpposite", str(int(gate))), ("InpApiEntryStop", str(API_ENTRY_STOP)),
                        ("InpApiSoftWarn", str(API_SOFT_WARN))):
            if k not in have:
                errs.append("%s missing" % k)
            elif have[k] != want:
                errs.append("%s %s, not %s" % (k, have[k], want))
        if errs:
            return errs
        if [k for k, _ in with_v22_keys(a, gate)] != [k for k, _ in b]:
            return ["keys or their order differ from the base preset with the v2.2a / ADR-166 inputs"]
    base, p = dict(a), dict(b)
    for k in ("InpMagic", "InpSlot", "InpTelemetryInstance"):
        if p[k] != base[k]:
            errs.append("%s changed from the base (%s -> %s)" % (k, base[k], p[k]))
    if p.get("TelemetryAPIKey", "") != "":
        errs.append("TelemetryAPIKey not blank")
    want_cap = CAP if cap is None else int(cap)
    if p["InpMaxLayers"] != str(want_cap):
        errs.append("InpMaxLayers %s, not %d" % (p["InpMaxLayers"], want_cap))
    w = float(width)
    if abs(float(p["InpWidthPips"]) - w) > EPS or p["InpWidthPipsLong"] != "-1.0" or p["InpWidthPipsShort"] != "-1.0":
        errs.append("width not %s on both sides" % _num(w))
    if abs(float(p["InpStrandedThreshPips"]) - (w + 1.0)) > EPS:
        errs.append("InpStrandedThreshPips %s, not W + 1 = %s" % (p["InpStrandedThreshPips"], _num(w + 1)))
    want_db = DEADBAND if deadband is None else str(deadband)
    if p["InpDeadbandPips"] != want_db:
        errs.append("InpDeadbandPips %s, not %s" % (p["InpDeadbandPips"], want_db))
    for k, want in (("InpVirtualLattice", "true"), ("InpLatticeReroll", "true"),
                    ("InpAutoEject", "false"), ("InpBreakerEnable", "false")):
        if p.get(k) != want:
            errs.append("%s %s, not %s" % (k, p.get(k), want))
    adds = [float(p["InpAddPips"])] + list(resolved(p, "Add"))
    for add in adds:
        if not guard_ok(w, add):
            errs.append("guard ratio: add %s / width %s outside [%.1f, %.1f]" % (add, w, GUARD_MIN, GUARD_MAX))
    if min([float(p["InpExitPips"])] + list(resolved(p, "Exit"))) <= 0:
        errs.append("an exit is not positive")
    return errs


# ---------------------------------------------------------------- build

def live_preset(root, fleet, pair):
    f = fleet.lower()
    d = os.path.join(root, "ea", "presets_" + f)
    stem = pair.lower() + "_opt_" + f
    if fleet != "B" and os.path.exists(os.path.join(d, stem + "_p1.set")):
        return os.path.join(d, stem + "_p1.set")
    return os.path.join(d, stem + "_lat.set")


def c10_path(root, fleet, pair):
    f = fleet.lower()
    return os.path.join(root, "ea", "presets_" + f, "%s_opt_%s_c10.set" % (pair.lower(), f))


def p2_path(root, fleet, pair):
    f = fleet.lower()
    return os.path.join(root, "ea", "presets_" + f, "%s_opt_%s_p2.set" % (pair.lower(), f))


def _read(path):
    with open(path, encoding="ascii") as fh:
        return fh.read()


def build(geo, root, stage, c10_texts=None):
    """Returns ({path: text}, [errors]). stage 'c10' builds the non-scout pairs from
    the live presets (and validates the scouts' existing c10 files); 'p2' builds every
    pair from its c10 text (c10_texts, else the file on disk)."""
    out, errs = {}, list(check_plan(geo))
    scouts = set(geo.get("scouts", []))
    plan = p2_values(geo)
    for pair in geo["pairs"]:
        w = pair_width(geo, pair)
        for f in FLEETS:
            cpath = c10_path(root, f, pair)
            if stage == "c10":
                if pair in scouts:
                    errs += ["%s: %s" % (os.path.basename(cpath), e)
                             for e in validate(_read(cpath), _read(cpath), w)]
                    continue
                base = _read(live_preset(root, f, pair))
                text = c10(base, w, f, pair)
                errs += ["%s: %s" % (os.path.basename(cpath), e) for e in validate(base, text, w)]
                changed = {k for (k, v1), (_k, v2) in zip(parse(base), parse(text)) if v1 != v2}
                if not changed <= C10_CHANGES:
                    errs.append("%s: c10 changed %s" % (os.path.basename(cpath), sorted(changed - C10_CHANGES)))
                out[cpath] = text
            else:
                ctext = (c10_texts or {}).get(cpath) or _read(cpath)
                adds, exits, role = plan[(pair, f)]
                text = p2(ctext, adds, exits, f, pair, role)
                ppath = p2_path(root, f, pair)
                errs += ["%s: %s" % (os.path.basename(ppath), e) for e in validate(ctext, text, w)]
                p = dict(parse(text))
                if resolved(p, "Add") != tuple(float(x) for x in adds) or \
                        resolved(p, "Exit") != tuple(float(x) for x in exits):
                    errs.append("%s: written add/exit differ from the plan" % os.path.basename(ppath))
                out[ppath] = text
    return out, errs


# ---------------------------------------------------------------- this week's rounds at cap 8 (memo 2026-10-05)

def tight_width(adds):
    """The tightest width the ADR-153 typo guard allows for these adds: ceil to the
    half pip of max(adds) / 4 (the guard's upper bound, add / width <= 4.0)."""
    return math.ceil(max(float(a) for a in adds) / 4.0 * 2.0 - EPS) / 2.0


def round_width(geo, pair):
    """One width per pair on B, C and D: the tight width of every add any fleet runs
    on the pair this round (the anchor's two sides and C's probes)."""
    spec = geo["pairs"][pair]
    adds = [spec["anchor"][s]["add"] for s in ("L", "S")]
    if "C" in spec:
        adds += [spec["C"][s]["add"] for s in ("L", "S")]
    return tight_width(adds)


def round_preset(base_text, width, adds, exits, fleet, pair, role, cap, deadband, rnd, roll_gate=None):
    """A chart's live preset with this round's width, S = W + 1, deadband, cap, add and
    exit per side and the warning; every other key and the key order kept. With roll_gate
    (an int >= -1) the three v2.2a / ADR-166 inputs are inserted (with_v22_keys)."""
    w = float(width)
    gate_txt = "" if roll_gate is None else ", roll gate %d" % int(roll_gate)
    upd = {
        "InpMaxLayers": str(int(cap)),
        "InpWidthPips": _num(w),
        "InpStrandedThreshPips": _num(w + 1.0),
        "InpDeadbandPips": _num(float(deadband)),
        "InpConfigWarning": _warning(fleet, "round %d %s %s: cap %d, width %s, deadband %s; lattice + reroll on%s"
                                     % (int(rnd), pair, role, int(cap), _num(w), _num(float(deadband)),
                                        gate_txt)),
    }
    upd.update(side_fields("Add", adds[0], adds[1]))
    upd.update(side_fields("Exit", exits[0], exits[1]))
    pairs = _set(parse(base_text), upd)
    if roll_gate is not None:
        pairs = with_v22_keys(pairs, roll_gate)
    return render(pairs)


def round_path(root, fleet, pair, rnd):
    f = fleet.lower()
    return os.path.join(root, "ea", "presets_" + f, "%s_opt_%s_r%d.set" % (pair.lower(), f, int(rnd)))


def build_round(geo, root):
    """Returns ({path: text}, [errors]) for this round's presets on B, C, D from each
    chart's live preset (the plan as p2_values: B anchor, C add probe, D exit probe,
    the control on the anchor), checked by check_plan's probe rules and validate."""
    out = {}
    errs = [e for e in check_plan(geo) if "outside the guard" not in e]   # headroom is c10's rule
    cap, db, rnd = int(geo["cap"]), float(geo["deadband"]), int(geo["round"])
    if any("roll_gate" in e for e in errs):
        return {}, errs
    plan = p2_values(geo)
    rg = geo.get("roll_gate")
    for pair in geo["pairs"]:
        w = round_width(geo, pair)
        for f in FLEETS:
            gate = None if rg is None else rg[f]
            adds, exits, role = plan[(pair, f)]
            base = _read(live_preset(root, f, pair))
            text = round_preset(base, w, adds, exits, f, pair, role, cap, db, rnd, roll_gate=gate)
            path = round_path(root, f, pair, rnd)
            errs += ["%s: %s" % (os.path.basename(path), e)
                     for e in validate(base, text, w, cap=cap, deadband=_num(db), gate=gate)]
            p = dict(parse(text))
            if resolved(p, "Add") != tuple(float(x) for x in adds) or \
                    resolved(p, "Exit") != tuple(float(x) for x in exits):
                errs.append("%s: written add/exit differ from the plan" % os.path.basename(path))
            out[path] = text
    return out, errs


def summary(files):
    rows = []
    for path in sorted(files):
        p = dict(parse(files[path]))
        al, as_ = resolved(p, "Add")
        el, es = resolved(p, "Exit")
        rows.append("%-26s W %-4s S %-4s cap %s  add L/S %4.1f/%4.1f  exit L/S %4.1f/%4.1f  %s" % (
            os.path.basename(path), p["InpWidthPips"], p["InpStrandedThreshPips"], p["InpMaxLayers"],
            al, as_, el, es, p["InpTelemetryInstance"]))
    return rows


def main(argv=None):
    ap = argparse.ArgumentParser(description="IC presets for the cap-10 reload and round 2")
    ap.add_argument("--table", required=True)
    ap.add_argument("--stage", choices=("c10", "p2", "round"), required=True)
    ap.add_argument("--root", default=os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    ap.add_argument("--write", action="store_true")
    args = ap.parse_args(argv)
    geo = load_table(args.table)
    c10_texts = None
    if args.stage == "round":
        files, errs = build_round(geo, args.root)
        print("\n".join(summary(files)))
        if errs:
            print("\n".join("ERROR " + e for e in errs))
            return 1
        print("%d files, 0 errors%s" % (len(files), "" if args.write else " (dry run: nothing written)"))
        if args.write:
            for path, text in files.items():
                with open(path, "w", encoding="ascii", newline="\n") as fh:
                    fh.write(text)
        return 0
    if args.stage == "p2":
        c10_texts, e0 = build(geo, args.root, "c10")
        if e0:
            print("\n".join("ERROR c10 " + e for e in e0))
            return 1
    files, errs = build(geo, args.root, args.stage, c10_texts=c10_texts)
    print("\n".join(summary(files)))
    if errs:
        print("\n".join("ERROR " + e for e in errs))
        return 1
    print("%d files, 0 errors%s" % (len(files), "" if args.write else " (dry run: nothing written)"))
    if args.write:
        for path, text in files.items():
            with open(path, "w", encoding="ascii", newline="\n") as fh:
                fh.write(text)
    return 0


if __name__ == "__main__":
    sys.exit(main())
