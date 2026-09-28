"""Ejections, chains and the counterfactual (study s2, rulings s7).

Per ejection e (one layer, keyed by instance and position ticket):
  E  = the ejected layer's realised net (ledger, all-in).
  X0 = its exit before the ejection: the first EJECT_ACCEPTED `raw` (the
       formula exit incl. accrued carry, excl. the eject offset).
  X(t) moves each server midnight by that night's carry with ITS SIGN
       (GQ3): long X += -swap_long_pts * point * mult; short X += swap_short_pts
       * point * mult (paying swap moves the exit away, earning moves it closer).
  hit: long bid >= X (bar high); short ask <= X (bar low + bar spread, GQ4).
  H  = held layer's value: at the hit, price P&L at X + all swap to then +
       both commissions; else its mark at the horizon (bid for a long, ask
       for a short) + swap to then + the ENT commission.

Auto-eject takes the layer whose exit ranks depth-1 (the exit furthest from
the market: the most underwater layer, usually L0; grind_engine.mqh
559-585). So F is defined by DEPTH, not layer index (correction to GQ1):
a layer is FREED-SLOT when it was added while the held world was still at
cap: depth_before(add) + k_open(add) >= cap, where k_open counts chain
layers held in the held world whose exit has not yet been reached.

CHAIN: ejections on one (instance, side) whose fill falls before the
running chain end are one episode; chain end = max over members of
min(t_hit, fill + h). A member that was itself a freed-slot layer does not
exist in the held world: H = 0 and its E sits in F.

  V_doc    = sum over held members (E - H) + F_closed            (study s2)
  V_strict = V_doc + F_open (freed-slot layers still open at chain end,
             marked to market there; omitting them flatters ejection)
"""
import datetime as _dt

from ev_book import cap_at
from ev_data import parse_utc

BORDERLINE_PIPS = 1.0
MT5_WED = 3


def night_multiplier(day_ended_server, x3_day=MT5_WED):
    """Carry multiplier for the rollover that ENDS server day D.
    ASSUMPTION (inferred, not verified against the ledger; C61 open):
    Wed = 3, Sat/Sun = 0, other weekdays 1. MT5 day_of_week: Sun=0..Sat=6."""
    dow = (day_ended_server.weekday() + 1) % 7      # python Mon=0 -> MT5 Mon=1
    if dow in (0, 6):
        return 0
    return 3 if dow == x3_day else 1


def midnights_between(t_a, t_b, offset_s):
    """Server midnights m with t_a < m <= t_b, as (m_utc, server date of the
    day that ended)."""
    out = []
    s_a = t_a + offset_s
    first = (int(s_a // 86400) + 1) * 86400
    m = first
    while m - offset_s <= t_b:
        ended = _dt.datetime.fromtimestamp(m - 86400, _dt.timezone.utc).date()
        out.append((m - offset_s, ended))
        m += 86400
    return out


class Ejection:
    def __init__(self, instance, ticket):
        self.instance = instance
        self.ticket = ticket
        self.side = None
        self.x0 = None
        self.entry = None
        self.accept_t = None
        self.fill_t = None
        self.source = None
        self.n_accept = 0
        self.layer = None
        self.freed = False           # a freed-slot layer of an earlier chain member
        # per horizon results: {h: dict}
        self.cf = {}


def collect_ejections(export, layers):
    """[Ejection] from EJECT_ACCEPTED/_FILLED, joined to their layers."""
    by_key = {}
    for r in export.get("ea_events", []):
        if r["code"] not in ("EJECT_ACCEPTED", "EJECT_FILLED"):
            continue
        key = (r["instance_id"], r["ticket"])
        ej = by_key.get(key)
        if ej is None:
            ej = by_key[key] = Ejection(*key)
        t = parse_utc(r["received_at"])
        d = r.get("detail") or {}
        if r["code"] == "EJECT_ACCEPTED":
            ej.n_accept += 1
            if ej.accept_t is None or t < ej.accept_t:
                ej.accept_t = t
                ej.x0 = float(d["raw"])
                ej.entry = float(d["entry"])
                ej.source = d.get("source")
                ej.side = "L" if ej.x0 > ej.entry else "S"
        else:
            ej.fill_t = t if ej.fill_t is None else min(ej.fill_t, t)
    out = []
    for ej in by_key.values():
        ej.layer = layers.get(ej.instance, {}).get(ej.ticket)
        if ej.layer is not None and ej.layer.close_t is not None:
            ej.fill_t = ej.layer.close_t          # ledger time beats receipt time
        out.append(ej)
    out.sort(key=lambda e: (e.instance, e.side or "", e.fill_t or 0))
    return out


def carry_rates(export):
    """{instance: [(t_utc, swap_long_pts, swap_short_pts, x3_day, swap_mode, point)]}
    from CARRY_SNAPSHOT events, sorted by time."""
    out = {}
    for r in export.get("ea_events", []):
        if r["code"] != "CARRY_SNAPSHOT":
            continue
        d = r.get("detail") or {}
        out.setdefault(r["instance_id"], []).append((
            parse_utc(r["received_at"]), float(d.get("swap_long", 0.0)),
            float(d.get("swap_short", 0.0)), int(d.get("rollover3days", MT5_WED)),
            int(d.get("swap_mode", 1)), float(d.get("point", 0.0))))
    for v in out.values():
        v.sort()
    return out


def _rate_at(rates, t):
    if not rates:
        return None
    cur = rates[0]
    for r in rates:
        if r[0] <= t:
            cur = r
    return cur


def value_per_price(layer, ej):
    """USD per 1.0 of price for this layer, from its own realised close
    (profit / price move). None when the move is under a pip-ish epsilon."""
    if layer is None or layer.closeby_profit is None or layer.close_price is None:
        return None
    open_p = layer.open_price if layer.open_price is not None else ej.entry
    move = (layer.close_price - open_p) * (1 if ej.side == "L" else -1)
    if abs(move) < 1e-9:
        return None
    return layer.closeby_profit / move


def swap_path(ej, rates, point, offset_s, t_end):
    """[(m_utc, shift_price, swap_price)] per server midnight crossed after the
    fill up to t_end; shift moves X, swap_price is the swap in price units
    (times value_per_price = $). Empty when rates are unknown or not in
    points (swap_mode != 1: flagged by the caller)."""
    rate = _rate_at(rates, ej.fill_t)
    if rate is None or rate[4] != 1:
        return None
    _t, sl, ss, x3, _mode, _pt = rate
    out = []
    for m_utc, ended in midnights_between(ej.fill_t, t_end, offset_s):
        mult = night_multiplier(ended, x3)
        if ej.side == "L":
            out.append((m_utc, -sl * point * mult, sl * point * mult))
        else:
            out.append((m_utc, ss * point * mult, ss * point * mult))
    return out


def counterfactual(ej, bars, rates, h_hours, offset_s):
    """Fill ej.cf[h_hours]; returns the dict. Needs bars covering
    [fill, fill + h]; otherwise status 'no_data' (hit before the data ends
    still counts)."""
    res = {"status": None, "hit": None, "t_hit": None, "borderline": False,
           "E": None, "H": None, "mae_from_entry": None, "mae_beyond_eject": None,
           "vpp": None, "carry_known": True, "nights": 0}
    ej.cf[h_hours] = res
    lay = ej.layer
    if lay is None or lay.net() is None or ej.fill_t is None or ej.x0 is None:
        res["status"] = "no_layer"
        return res
    vpp = value_per_price(lay, ej)
    if vpp is None:
        res["status"] = "no_vpp"
        return res
    res["vpp"] = vpp
    res["E"] = lay.net()
    t_end = ej.fill_t + h_hours * 3600.0
    sp = swap_path(ej, rates, bars.point, offset_s, t_end)
    if sp is None:
        res["carry_known"] = False
        sp = []
    sgn = 1 if ej.side == "L" else -1
    open_p = lay.open_price if lay.open_price is not None else ej.entry
    past_swap = lay.closeby_swap or 0.0
    comm_in = lay.open_commission or 0.0
    comm_out = lay.exit_commission
    pip = bars.pip

    i = bars.index_at_or_after(ej.fill_t)
    worst = None
    best_gap = None           # closest approach to X (pips); negative = beyond
    x = ej.x0
    fwd_swap_px = 0.0
    k = 0
    last_i = None
    while i < len(bars) and bars.t[i] < t_end:
        while k < len(sp) and sp[k][0] <= bars.t[i]:
            x += sp[k][1]
            fwd_swap_px += sp[k][2]
            k += 1
        if ej.side == "L":
            adverse = bars.l[i]
            fav = bars.h[i]
            gap = (x - fav) / pip           # <= 0 : bid reached X
        else:
            adverse = bars.ask_high(i)
            fav = bars.ask_low(i)
            gap = (fav - x) / pip           # <= 0 : ask reached X
        if worst is None or (adverse - worst) * sgn < 0:
            worst = adverse
        best_gap = gap if best_gap is None else min(best_gap, gap)
        last_i = i
        if gap <= 0:
            res["hit"] = True
            res["t_hit"] = bars.t[i]
            res["borderline"] = gap > -BORDERLINE_PIPS
            res["nights"] = k
            res["H"] = ((x - open_p) * sgn * vpp + past_swap + fwd_swap_px * vpp
                        + comm_in + comm_out)
            break
        i += 1
    if res["hit"] is None:
        if bars.to_utc < t_end:
            res["status"] = "no_data"
            return res
        if last_i is None:
            res["status"] = "no_bars"
            return res
        res["hit"] = False
        res["nights"] = k
        res["borderline"] = best_gap is not None and best_gap < BORDERLINE_PIPS
        mark = bars.c[last_i] if ej.side == "L" else bars.ask_close(last_i)
        res["H"] = (mark - open_p) * sgn * vpp + past_swap + fwd_swap_px * vpp + comm_in
    if worst is not None:
        res["mae_from_entry"] = (worst - open_p) * sgn * vpp
        res["mae_beyond_eject"] = (worst - lay.close_price) * sgn * vpp
    res["status"] = "ok"
    return res


def _end_of(ej, h_hours):
    r = ej.cf.get(h_hours) or {}
    if r.get("t_hit") is not None:
        return r["t_hit"]
    return ej.fill_t + h_hours * 3600.0


def build_chains(ejections, h_hours):
    """Group ejections per (instance, side) into chains (see module doc)."""
    chains = []
    groups = {}
    for ej in ejections:
        if ej.fill_t is None or ej.side is None:
            continue
        groups.setdefault((ej.instance, ej.side), []).append(ej)
    for key, lst in groups.items():
        lst.sort(key=lambda e: e.fill_t)
        cur = None
        for ej in lst:
            if cur is not None and ej.fill_t < cur["end"]:
                cur["members"].append(ej)
                cur["end"] = max(cur["end"], _end_of(ej, h_hours))
            else:
                cur = {"instance": key[0], "side": key[1], "members": [ej],
                       "start": ej.fill_t, "end": _end_of(ej, h_hours)}
                chains.append(cur)
    return chains


def score_chain(chain, layers, timeline, caps, bars, h_hours):
    """Freed-slot layers, F, and V for one chain. Mutates members' `freed`."""
    inst, side = chain["instance"], chain["side"]
    start, end = chain["start"], chain["end"]
    sgn = 1 if side == "L" else -1

    def k_open(t):
        n = 0
        for m in chain["members"]:
            if m.freed:
                continue
            if m.fill_t <= t < _end_of(m, h_hours):
                n += 1
        return n

    adds = sorted((l for l in layers[inst].values()
                   if l.side == side and l.open_t is not None and start < l.open_t < end),
                  key=lambda l: l.open_t)
    # a member that is itself freed-slot is not held, which lowers k_open for
    # later adds: iterate to a fixed point (monotone, so it settles quickly)
    for m in chain["members"]:
        m.freed = False
    for _ in range(10):
        freed_layers = [lay for lay in adds
                        if timeline.depth_before(lay.open_t) + k_open(lay.open_t)
                        >= cap_at(caps[inst], lay.open_t)]
        freed_ids = {l.position_id for l in freed_layers}
        changed = False
        for m in chain["members"]:
            f = m.ticket in freed_ids
            if f != m.freed:
                m.freed = f
                changed = True
        if not changed:
            break

    f_closed = 0.0
    f_open = 0.0
    n_open = 0
    vpps = [m.cf[h_hours]["vpp"] for m in chain["members"] if m.cf.get(h_hours, {}).get("vpp")]
    vpp = vpps[0] if vpps else None
    i_end = bars.index_at_or_after(end) - 1 if bars is not None else -1
    for lay in freed_layers:
        if lay.closed and lay.close_t <= end:
            f_closed += lay.net()
        else:
            n_open += 1
            if vpp is None or i_end < 0:
                f_open = None
                continue
            if f_open is not None:
                mark = bars.c[i_end] if side == "L" else bars.ask_close(i_end)
                f_open += (mark - lay.open_price) * sgn * vpp + (lay.open_commission or 0.0)

    e_minus_h = 0.0
    status = "ok"
    for m in chain["members"]:
        if m.freed:
            continue
        r = m.cf.get(h_hours) or {}
        if r.get("status") != "ok":
            status = r.get("status") or "missing"
            continue
        e_minus_h += r["E"] - r["H"]
    if bars is None or bars.to_utc < end:
        status = "no_data" if status == "ok" else status
    if status != "ok":
        e_minus_h = None            # a partial sum would read as a result
    v_doc = (e_minus_h + f_closed) if e_minus_h is not None else None
    chain.update({
        "h": h_hours, "status": status, "freed_layers": len(freed_layers),
        "freed_open": n_open, "E_minus_H": e_minus_h, "F_closed": f_closed,
        "F_open": f_open, "V_doc": v_doc,
        "V_strict": (v_doc + f_open) if (f_open is not None and v_doc is not None) else None,
        "hours_at_cap_held": (end - start) / 3600.0,
    })
    return chain
