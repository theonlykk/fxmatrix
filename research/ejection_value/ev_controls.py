"""GQ5-F controls for the scalp rate a side would have had below cap.

(1) CROSS-FLEET: the same pair, side and variant on another fleet of the
    same broker (C vs B until C63): in the hours when the CAPPED side is at
    cap and the CONTROL side is below cap, the control's scalps per hour.
(2) F per hour at cap: the trading an ejection actually bought, per chain
    (F_closed / chain hours), pooled.
(3) TWINS: the `_ALT` duplicate of the same fleet (AUDNZD, NZDCAD only;
    add 10, so it caps less) against its `_OPT` primary, as in (1).
"""
from ev_book import cap_at


def _at_cap_intervals(timeline, caps):
    return [(a, b) for a, b, d in timeline.segments() if d >= cap_at(caps, a)]


def _below_cap_intervals(timeline, caps):
    return [(a, b) for a, b, d in timeline.segments() if d < cap_at(caps, a)]


def _intersect(xs, ys):
    out = []
    i = j = 0
    xs, ys = sorted(xs), sorted(ys)
    while i < len(xs) and j < len(ys):
        a = max(xs[i][0], ys[j][0])
        b = min(xs[i][1], ys[j][1])
        if b > a:
            out.append((a, b))
        if xs[i][1] < ys[j][1]:
            i += 1
        else:
            j += 1
    return out


def control_rate(tl_capped, caps_capped, tl_ctrl, caps_ctrl, ctrl_layers, side):
    """Hours with the capped side at cap AND the control side below cap, and
    the control's scalps (non-ejected, non-rolled closes on `side`) in them."""
    windows = _intersect(_at_cap_intervals(tl_capped, caps_capped),
                         _below_cap_intervals(tl_ctrl, caps_ctrl))
    hours = sum(b - a for a, b in windows) / 3600.0
    n = 0
    nets = []
    for lay in ctrl_layers.values():
        if lay.side != side or not lay.closed or lay.ejected or lay.rolled:
            continue
        if any(a <= lay.close_t < b for a, b in windows):
            n += 1
            if lay.net() is not None:
                nets.append(lay.net())
    return {"hours": hours, "scalps": n,
            "rate": (n / hours) if hours > 0 else None,
            "mean_net": (sum(nets) / len(nets)) if nets else None}


def pair_controls(layers, timelines, caps, fleet_of, symbol_of):
    """Every (capped instance, side) with a cross-fleet (B<->C) or twin
    (_ALT) control. Returns a list of dict rows."""
    rows = []
    insts = sorted(layers)
    for inst in insts:
        fleet = fleet_of(inst)
        sym = symbol_of(inst)
        variant = inst.rsplit("_", 1)[-1]
        base_variant = variant[:3]                  # OPT / ALT
        for side in ("L", "S"):
            tl = timelines.get((inst, side))
            if tl is None:
                continue
            controls = []
            if fleet in ("B", "C"):
                other = "C" if fleet == "B" else "B"
                controls.append(("cross_fleet", "GRIND_%s_%s%s" % (sym, base_variant, other)))
            if base_variant == "OPT":
                suffix = variant[3:]                  # '', 'B', 'C'
                controls.append(("twin", "GRIND_%s_ALT%s" % (sym, suffix)))
            for kind, ctrl in controls:
                tlc = timelines.get((ctrl, side))
                if tlc is None or ctrl not in caps:
                    continue
                r = control_rate(tl, caps[inst], tlc, caps[ctrl], layers[ctrl], side)
                if r["hours"] <= 0:
                    continue
                rows.append(dict(r, capped=inst, control=ctrl, kind=kind, side=side))
    return rows


def f_per_hour(chains):
    """Pooled F_closed per hour of held-world cap time over scored chains."""
    ok = [c for c in chains if c.get("status") == "ok"]
    hours = sum(c["hours_at_cap_held"] for c in ok)
    f = sum(c["F_closed"] for c in ok)
    return {"chains": len(ok), "hours": hours, "F_closed": f,
            "per_hour": (f / hours) if hours > 0 else None}
