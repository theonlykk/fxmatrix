"""Layers, depth timelines and scalp rates from the archive export.

A LAYER is one ENT position: opened by an ENT IN deal, closed by a close-by
(two OUT_BY deals sharing an order_ticket: the layer's position and the
opposite position its EXT fill opened). Its net is everything the broker
booked on it: profit + swap + commission of both OUT_BY deals, plus the
commission of the ENT IN and EXT IN deals (commission is charged on IN
deals only, 02_TRAPS 26 Sep).

Depth per (instance, side) is rebuilt from those events. A layer opened
before the export window and still open at its end is invisible; the
constant it adds is estimated from ANCHORS (known depths: depth == cap at
every EJECT_ACCEPTED) and reported, never silently assumed zero.
"""
import collections

from ev_data import broker_msc_to_utc, parse_utc

DEFAULT_OFFSET_S = 10800   # both servers GMT+3 (01_BOOT, verified 25 Sep)


class Layer:
    __slots__ = ("instance", "side", "position_id", "layer_index", "open_t", "open_price",
                 "open_commission", "close_t", "close_price", "exit_commission",
                 "closeby_net", "closeby_profit", "closeby_swap", "ejected", "rolled")

    def __init__(self, instance, position_id):
        self.instance = instance
        self.position_id = position_id
        self.side = None
        self.layer_index = None
        self.open_t = None            # None: opened before the window
        self.open_price = None
        self.open_commission = None   # None when the ENT deal is outside the window
        self.close_t = None           # None: still open at the window end
        self.close_price = None
        self.exit_commission = 0.0
        self.closeby_net = None
        self.closeby_profit = None    # both legs' profit (price P&L of the layer)
        self.closeby_swap = None      # swap booked over the layer's life
        self.ejected = False
        self.rolled = False

    @property
    def closed(self):
        return self.close_t is not None

    def net(self):
        """All-in realised $ (None while open). A missing ENT commission
        (opened before the window) is counted as 0 and flagged by
        `net_complete`."""
        if self.closeby_net is None:
            return None
        return self.closeby_net + self.exit_commission + (self.open_commission or 0.0)

    @property
    def net_complete(self):
        return self.closeby_net is not None and self.open_commission is not None


def _num(x):
    return float(x) if x is not None else 0.0


UNMATCHED_CLOSEBYS = []   # (instance, order_ticket) where neither leg's IN deal is known


def build_layers(export, offset_s=DEFAULT_OFFSET_S):
    """Return {instance: {position_id: Layer}} from export['fill_logs'].
    Close-bys whose two IN deals are both unknown are skipped and listed in
    UNMATCHED_CLOSEBYS (reported, never guessed)."""
    del UNMATCHED_CLOSEBYS[:]
    fills = export.get("fill_logs", [])
    layers = collections.defaultdict(dict)
    in_deals = {}                                   # (instance, position_id) -> row
    for r in fills:
        if r["entry_type"] == "IN":
            in_deals[(r["instance_id"], r["position_id"])] = r

    for r in fills:
        if r["entry_type"] == "IN" and r.get("role") == "ENT":
            lay = layers[r["instance_id"]].setdefault(r["position_id"],
                                                       Layer(r["instance_id"], r["position_id"]))
            lay.side = r["side"]
            lay.layer_index = r["layer_index"]
            lay.open_t = broker_msc_to_utc(r["deal_time_broker_msc"], offset_s)
            lay.open_price = float(r["deal_price"])
            lay.open_commission = _num(r.get("commission"))

    groups = collections.defaultdict(list)
    for r in fills:
        if r["entry_type"] == "OUT_BY":
            groups[(r["instance_id"], r["order_ticket"])].append(r)
    for (inst, _order), deals in groups.items():
        if len(deals) != 2:
            raise ValueError("close-by group of %d deals: %s %s" % (len(deals), inst, _order))
        ext_in = [in_deals.get((inst, d["position_id"])) for d in deals]
        # the layer is the leg whose IN deal is NOT the EXT fill
        legs = [(d, i) for d, i in zip(deals, ext_in)]
        ext_legs = [(d, i) for d, i in legs if i is not None and i.get("role") == "EXT"]
        ent_legs = [(d, i) for d, i in legs if i is not None and i.get("role") == "ENT"]
        if len(ext_legs) == 1:
            ext_deal, ext_row = ext_legs[0]
            lay_deal = deals[0] if deals[1] is ext_deal else deals[1]
        elif len(ent_legs) == 1:
            # the EXT fill's own IN deal never reached the archive (a fill during
            # a broker resync has no event, C76): the layer is the ENT leg
            lay_deal = ent_legs[0][0]
            ext_deal = deals[0] if deals[1] is lay_deal else deals[1]
            ext_row = None
        else:
            UNMATCHED_CLOSEBYS.append((inst, _order))
            continue
        lay = layers[inst].setdefault(lay_deal["position_id"], Layer(inst, lay_deal["position_id"]))
        if lay.side is None and ext_row is not None:
            lay.side = ext_row["side"]
            lay.layer_index = ext_row["layer_index"]
        lay.close_t = broker_msc_to_utc(lay_deal["deal_time_broker_msc"], offset_s)
        if ext_row is not None:
            lay.close_price = float(ext_row["deal_price"])
            lay.exit_commission = _num(ext_row.get("commission"))
        else:
            # the layer's own OUT_BY leg is priced at the exit (production rows:
            # layer leg 0.85804 = exit; the exit position's leg = layer entry)
            lay.close_price = float(lay_deal["deal_price"])
            lay.exit_commission = 0.0          # unknown: its IN deal is missing
        lay.closeby_net = sum(_num(d.get("profit")) + _num(d.get("swap")) + _num(d.get("commission"))
                              for d in deals)
        lay.closeby_profit = sum(_num(d.get("profit")) for d in deals)
        lay.closeby_swap = sum(_num(d.get("swap")) for d in deals)
    return layers


def mark_ejections(layers, export):
    """Flag ejected / rolled layers from ea_events (EJECT_FILLED, ROLL_FILLED
    carry the layer's position ticket)."""
    for r in export.get("ea_events", []):
        code = r["code"]
        if code not in ("EJECT_FILLED", "ROLL_FILLED"):
            continue
        lay = layers.get(r["instance_id"], {}).get(r["ticket"])
        if lay is None:
            continue
        if code == "EJECT_FILLED":
            lay.ejected = True
        else:
            lay.rolled = True


def caps_by_instance(export):
    """{instance: [(t_utc, max_layers)]} from INIT config events, sorted."""
    out = collections.defaultdict(list)
    for r in export.get("config_events", []):
        if r.get("event") != "INIT" or r.get("max_layers") is None:
            continue
        out[r["instance_id"]].append((parse_utc(r["received_at"]), int(r["max_layers"])))
    for v in out.values():
        v.sort()
    return out


def cap_at(caps, t):
    """max_layers in force at t (the latest INIT at or before t; else the
    first known)."""
    if not caps:
        raise ValueError("no INIT config for this instance")
    cur = caps[0][1]
    for ti, c in caps:
        if ti <= t:
            cur = c
        else:
            break
    return cur


class DepthTimeline:
    """Step function of visible depth for one (instance, side), plus the
    hidden constant `hidden` (layers open through the whole window)."""

    def __init__(self, t0, t1, events, hidden=0):
        self.t0, self.t1 = t0, t1
        self.events = sorted(events)       # (t, delta); at equal t, closes (-1) first
        self.hidden = hidden

    def depth_before(self, t):
        """Depth strictly before an event at time t (visible + hidden)."""
        d = self.hidden
        for te, delta in self.events:
            if te < t:
                d += delta
            else:
                break
        return d

    def segments(self):
        """[(start, end, depth)] covering [t0, t1]."""
        out = []
        d = self.hidden
        cur = self.t0
        for te, delta in self.events:
            if te < self.t0:
                d += delta
                continue
            if te > self.t1:
                break
            if te > cur:
                out.append((cur, te, d))
                cur = te
            d += delta
        if self.t1 > cur:
            out.append((cur, self.t1, d))
        return out


def depth_timelines(layers, t0, t1):
    """{(instance, side): DepthTimeline} over [t0, t1]; a layer opened before
    the window counts from t0 (sort key puts closes before opens at a tie)."""
    ev = collections.defaultdict(list)
    for inst, by_pos in layers.items():
        for lay in by_pos.values():
            if lay.side is None:
                continue
            key = (inst, lay.side)
            ev.setdefault(key, [])
            start = lay.open_t if lay.open_t is not None else t0
            ev[key].append((start, +1))
            if lay.close_t is not None:
                ev[key].append((lay.close_t, -1))
    return {k: DepthTimeline(t0, t1, v) for k, v in ev.items()}


def calibrate_hidden(timeline, anchors):
    """Set `timeline.hidden` from anchors [(t, known_depth)]: each gives
    known - visible_before(t). Returns (hidden, spread) where spread =
    max - min over anchors (0 = consistent). No anchors: (0, None)."""
    if not anchors:
        timeline.hidden = 0
        return 0, None
    timeline.hidden = 0
    diffs = [known - timeline.depth_before(t) for t, known in anchors]
    diffs.sort()
    hidden = diffs[len(diffs) // 2]
    timeline.hidden = hidden
    return hidden, diffs[-1] - diffs[0]


def eject_anchors(export, caps, offset_s=DEFAULT_OFFSET_S):
    """{(instance, side): [(t_utc, cap)]}: at every auto EJECT_ACCEPTED the
    side is at cap (Grind_AutoEjectPick returns unless depth >= max_layers).
    Side comes from the exit geometry: a long layer's exit is above its
    entry (raw > entry)."""
    out = collections.defaultdict(list)
    for r in export.get("ea_events", []):
        if r["code"] != "EJECT_ACCEPTED":
            continue
        d = r.get("detail") or {}
        if d.get("source") != "auto":
            continue
        side = "L" if float(d["raw"]) > float(d["entry"]) else "S"
        t = parse_utc(r["received_at"])
        out[(r["instance_id"], side)].append((t, cap_at(caps[r["instance_id"]], t)))
    return out


def side_stats(layers, timelines, caps, t0, t1):
    """Per (instance, side): hours at cap, scalps below and at cap (by depth
    just before each close), rates per hour, mean scalp net. Ejected and
    rolled closes are not scalps (counts exclude, 02_TRAPS 26 Sep)."""
    out = {}
    for key, tl in timelines.items():
        inst, side = key
        hours_at = hours_below = 0.0
        for a, b, d in tl.segments():
            c = cap_at(caps[inst], a)
            if d >= c:
                hours_at += (b - a) / 3600.0
            else:
                hours_below += (b - a) / 3600.0
        n_at = n_below = 0
        nets = []
        for lay in layers[inst].values():
            if lay.side != side or not lay.closed or lay.ejected or lay.rolled:
                continue
            if not (t0 <= lay.close_t <= t1):
                continue
            d = tl.depth_before(lay.close_t)
            if d >= cap_at(caps[inst], lay.close_t):
                n_at += 1
            else:
                n_below += 1
            if lay.net() is not None:
                nets.append(lay.net())
        mean_net = sum(nets) / len(nets) if nets else None
        rate_below = n_below / hours_below if hours_below > 0 else None
        rate_at = n_at / hours_at if hours_at > 0 else None
        forgone = (hours_at * rate_below * mean_net
                   if rate_below is not None and mean_net is not None else None)
        forgone_net_of_at = None
        if rate_below is not None and mean_net is not None:
            forgone_net_of_at = hours_at * (rate_below - (rate_at or 0.0)) * mean_net
        out[key] = {
            "hours_at_cap": hours_at, "hours_below_cap": hours_below,
            "scalps_below": n_below, "scalps_at": n_at,
            "rate_below": rate_below, "rate_at": rate_at, "mean_scalp_net": mean_net,
            "forgone": forgone, "forgone_net_of_at_rate": forgone_net_of_at,
            "hidden_layers": tl.hidden,
        }
    return out
