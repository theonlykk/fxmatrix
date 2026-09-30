"""Per-side ladder REPLAY on M1 bars (study s9): the cap sensitivity test.

The EA's rules, simplified (every simplification is listed in study s9.1):
- A side's layers are limit fills. Long: a flat side's L0 rests at mid -
  width; after a fill at level x the next add rests at x - add; buy
  limits fill when the ASK (bid + bar spread) touches. Short mirrors:
  L0 at mid + width, adds at x + add, sell limits fill on the BID.
- Every layer exits at its fill price +/- exit (long: sell limit on the
  bid; short: buy limit on the ask). When the deepest layer exits, the
  next add returns to that layer's level (ADR-162 s3).
- A flat side's resting L0 is re-centred at a bar boundary only when it
  is further than `stranded_thresh_pips` from mid AND the new target
  differs from it by more than `deadband_pips` (Grind_ReCenterOpposite).
- At cap (depth == cap) the ADR-157 trigger is evaluated at each bar
  close: S1 -- over the last 2W bars the side's extreme (lowest bid for a
  long, highest ask for a short; ties: the most recent) is at least W bars
  old; S3 -- the bar's spread <= k x the mean spread of the last 60 bars.
  It closes the most underwater layer at that bar's close (long: bid;
  short: ask). Live ejections fill 0-2 min later at a passive price.
- Intra-bar path: O-L-H-C when close >= open, else O-H-L-C (bid path; the
  ask is bid + that bar's spread). Gap fills take the better price.
- Money: `v` dollars per unit of price per layer and `comm` all-in
  commission per layer, both from the instance's own ledger. No swap.

Nothing here reads anything but the objects passed in.
"""
import collections

EPS = 1e-9
FTMO_ROLL_UTC_HOUR = 22


class Geometry:
    __slots__ = ("width", "add", "exit", "cap", "deadband", "stranded")

    def __init__(self, width, add, exit_, cap, deadband=4.0, stranded=0.0):
        self.width, self.add, self.exit, self.cap = width, add, exit_, cap
        self.deadband, self.stranded = deadband, stranded


def geometry_timeline(export, instance):
    """[(t_utc, Geometry)] from INIT config_events of `instance`, sorted.
    Rows missing add/exit/width/max_layers are skipped."""
    from ev_data import parse_utc
    out = []
    for r in export.get("config_events", []):
        if r.get("instance_id") != instance or r.get("event") != "INIT":
            continue
        need = ("width_pips", "add_pips", "exit_pips", "max_layers")
        if any(r.get(k) is None for k in need):
            continue
        out.append((parse_utc(r["received_at"]),
                    Geometry(float(r["width_pips"]), float(r["add_pips"]), float(r["exit_pips"]),
                             int(r["max_layers"]), float(r.get("deadband_pips") or 4.0),
                             float(r.get("stranded_thresh_pips") or 0.0))))
    out.sort(key=lambda x: x[0])
    return out


def geom_at(timeline, t):
    cur = timeline[0][1]
    for ti, g in timeline:
        if ti <= t:
            cur = g
        else:
            break
    return cur


class Layer:
    __slots__ = ("level", "fill", "t")

    def __init__(self, level, fill, t):
        self.level, self.fill, self.t = level, fill, t


class SideReplay:
    """One side of one instance. Call `run(i0, i1)` over bar indices."""

    def __init__(self, is_long, bars, timeline, v, comm, cap_override=None,
                 W=5, k=1.5, auto_eject=True, seed=()):
        self.long = is_long
        self.b = bars
        self.tl = timeline
        self.v = v
        self.comm = comm
        self.cap_override = cap_override
        self.W, self.k, self.auto_eject = W, k, auto_eject
        self.layers = [Layer(x, x, None) for x in seed]   # fill order: deepest last
        self.next_add = None
        self.l0 = None
        self.events = []          # (t, kind, pnl) kind in 'scalp', 'eject'
        self.mtm = []             # (t_close, mtm $) per bar
        self.slots = []           # (t_close, positions + orders)
        self.max_depth = len(self.layers)
        if self.layers:
            g = geom_at(timeline, bars.t[0])
            self.next_add = self._step(self.layers[-1].level, g.add, away=True)

    # --- price helpers -------------------------------------------------
    def _pips(self, n):
        return n * self.b.pip

    def _step(self, x, add_pips, away):
        """A level `add_pips` further from the market than x (away=True)."""
        d = self._pips(add_pips)
        if self.long:
            return x - d if away else x + d
        return x + d if away else x - d

    def _exit_of(self, lay, g):
        d = self._pips(g.exit)
        return lay.fill + d if self.long else lay.fill - d

    def _pnl(self, lay, out_price):
        diff = (out_price - lay.fill) if self.long else (lay.fill - out_price)
        return diff * self.v + self.comm

    # --- the bar loop ----------------------------------------------------
    def run(self, i0, i1):
        b = self.b
        for i in range(i0, i1):
            g = geom_at(self.tl, b.t[i])
            cap = self.cap_override or g.cap
            s = b.spread[i] * b.point
            if not self.layers:
                prev = i - 1 if i > i0 else i
                mid = b.c[prev] + s / 2.0 if i > i0 else b.o[i] + s / 2.0
                self._place_l0(mid, g)
            o, h, l, c = b.o[i], b.h[i], b.l[i], b.c[i]
            path = (o, l, h, c) if c >= o else (o, h, l, c)
            t = b.t[i]
            for a, z in zip(path, path[1:]):
                if z < a:
                    self._down(a, z, s, g, cap, t)
                elif z > a:
                    self._up(a, z, s, g, cap, t)
            t_close = t + 60
            if self.auto_eject and len(self.layers) >= cap and self._s1(i) and self._s3(i):
                self._eject(c, s, t_close)
            self._record(c, s, cap, t_close)
        return self

    def _place_l0(self, mid, g):
        d = self._pips(g.width)
        target = mid - d if self.long else mid + d
        if self.l0 is None:
            self.l0 = target
            return
        dist = abs(self.l0 - mid) / self.b.pip
        if dist > g.stranded + EPS and abs(target - self.l0) / self.b.pip > g.deadband + EPS:
            self.l0 = target

    def _fill(self, level, fill, t, g, cap):  # noqa: ARG002 (cap kept for symmetry)
        self.layers.append(Layer(level, fill, t))
        self.max_depth = max(self.max_depth, len(self.layers))
        self.l0 = None
        self.next_add = self._step(level, g.add, away=True)   # rests only while depth < cap

    def _can_add(self, cap):
        return len(self.layers) < cap

    def _pending_entry(self):
        return self.l0 if not self.layers else self.next_add

    def _down(self, a, z, s, g, cap, t):
        """Bid moves down from a to z (z < a)."""
        if self.long:
            # buy limits fill when the ask (bid + s) <= level
            while self._can_add(cap):
                lvl = self._pending_entry()
                if lvl is None or z + s > lvl + EPS:
                    break
                fill = min(lvl, a + s)
                self._fill(lvl, fill, t, g, cap)
        else:
            # short exits: buy limits fill when ask <= exit
            self._exits(lambda ex: z + s <= ex + EPS, lambda ex: min(ex, a + s), g, t)

    def _up(self, a, z, s, g, cap, t):
        """Bid moves up from a to z (z > a)."""
        if self.long:
            self._exits(lambda ex: z >= ex - EPS, lambda ex: max(ex, a), g, t)
        else:
            while self._can_add(cap):
                lvl = self._pending_entry()
                if lvl is None or z < lvl - EPS:
                    break
                fill = max(lvl, a)
                self._fill(lvl, fill, t, g, cap)

    def _exits(self, reached, price_of, g, t):
        while self.layers:
            # the exit nearest the market fills first
            key = (lambda L: self._exit_of(L, g)) if self.long else (lambda L: -self._exit_of(L, g))
            lay = min(self.layers, key=key)
            ex = self._exit_of(lay, g)
            if not reached(ex):
                break
            deepest = self.layers[-1] is lay
            self.layers.remove(lay)
            self.events.append((t, "scalp", self._pnl(lay, price_of(ex))))
            if not self.layers:
                self.next_add = None
                self.l0 = None
            elif deepest:
                self.next_add = lay.level

    def _s1(self, i):
        W = self.W
        lo = i - 2 * W + 1
        if lo < 0:
            return False
        b = self.b
        if self.long:
            best, j = None, None
            for x in range(lo, i + 1):
                if best is None or b.l[x] <= best + EPS:
                    best, j = b.l[x], x
        else:
            best, j = None, None
            for x in range(lo, i + 1):
                ah = b.h[x] + b.spread[x] * b.point
                if best is None or ah >= best - EPS:
                    best, j = ah, x
        return i - j >= W

    def _s3(self, i):
        if i < 59:
            return False
        sp = self.b.spread
        mean = sum(sp[i - 59:i + 1]) / 60.0
        return sp[i] <= self.k * mean + EPS

    def _eject(self, c, s, t):
        # the most underwater layer: highest fill for a long, lowest for a short
        lay = max(self.layers, key=lambda L: L.fill) if self.long else min(self.layers, key=lambda L: L.fill)
        was_deepest = self.layers[-1] is lay
        self.layers.remove(lay)
        out = c if self.long else c + s
        self.events.append((t, "eject", self._pnl(lay, out)))
        if not self.layers:
            self.next_add = None
            self.l0 = None
        elif was_deepest:
            self.next_add = lay.level

    def _record(self, c, s, cap, t):
        px = c if self.long else c + s
        self.mtm.append((t, sum(((px - L.fill) if self.long else (L.fill - px)) * self.v
                                for L in self.layers)))
        n = len(self.layers)
        orders = (1 if n == 0 else 0) + (1 if 0 < n < cap else 0) + min(n, 2)
        self.slots.append((t, n + orders))

    # --- summaries ---------------------------------------------------------
    def totals(self):
        sc = [p for _t, k, p in self.events if k == "scalp"]
        ej = [p for _t, k, p in self.events if k == "eject"]
        return {"scalps": len(sc), "scalp_net": sum(sc), "ejections": len(ej),
                "eject_net": sum(ej), "closed_net": sum(sc) + sum(ej),
                "open_layers": len(self.layers), "max_depth": self.max_depth,
                "mtm_end": self.mtm[-1][1] if self.mtm else 0.0}


def ledger_money(layers_of_instance):
    """(v, comm) for one instance from its closed layers: v = median of
    closeby_profit / signed price move per layer; comm = median all-in
    commission per layer (net - profit - swap). None when unknown."""
    vs, cs = [], []
    for lay in layers_of_instance.values():
        if not lay.closed or lay.open_price is None or lay.close_price is None:
            continue
        move = lay.close_price - lay.open_price
        if lay.side == "S":
            move = -move
        if abs(move) > 1e-12 and lay.closeby_profit:
            vs.append(lay.closeby_profit / move)
        if lay.net_complete:
            cs.append(lay.net() - lay.closeby_profit - (lay.closeby_swap or 0.0))
    med = lambda xs: sorted(xs)[len(xs) // 2] if xs else None  # noqa: E731
    return med(vs), med(cs)


def actual_totals(layers_of_instance, side, t0, t1):
    """The ledger's scalps, ejections and closed net for one side, closed
    within [t0, t1] (rolls excluded from scalps, counted apart)."""
    sc = ej = 0
    net = 0.0
    for lay in layers_of_instance.values():
        if lay.side != side or not lay.closed or not (t0 <= lay.close_t <= t1):
            continue
        n = lay.net()
        if n is None:
            continue
        net += n
        if lay.ejected:
            ej += 1
        elif not lay.rolled:
            sc += 1
    return {"scalps": sc, "ejections": ej, "closed_net": net}


def reconciled(rep, act, tol_scalps=0.10, tol_ej=(0.20, 2), tol_net=(0.15, 3.0)):
    """Study s9.2: scalps within 10%; ejections within 20% or 2; closed net
    within 15% or $3 (the looser of each pair). Returns (ok, reasons)."""
    why = []
    a, r = act["scalps"], rep["scalps"]
    if abs(r - a) > tol_scalps * max(a, 1) + EPS:
        why.append("scalps %d vs %d" % (r, a))
    a, r = act["ejections"], rep["ejections"]
    if abs(r - a) > max(tol_ej[0] * a, tol_ej[1]) + EPS:
        why.append("ejections %d vs %d" % (r, a))
    a, r = act["closed_net"], rep["closed_net"]
    if abs(r - a) > max(tol_net[0] * abs(a), tol_net[1]) + EPS:
        why.append("net %.2f vs %.2f" % (r, a))
    return (not why), why


def fleet_day_metrics(series_by_side, closed_by_side, t_start, t_end):
    """Per FTMO day (rolls 22:00Z): carried MTM at the roll and the worst
    of (closed since the roll + MTM now), summed over all sides of a fleet.
    `series_by_side`: {key: [(t, mtm)]}; `closed_by_side`: {key: [(t, pnl)]}.
    Returns [(day_start_utc, carried_mtm, worst_equity_move)]."""
    grid = sorted({t for s in series_by_side.values() for t, _ in s if t_start <= t <= t_end})
    if not grid:
        return []
    # forward-filled MTM per side on the grid
    tot_mtm = collections.defaultdict(float)
    for s in series_by_side.values():
        j, cur = 0, 0.0
        for t in grid:
            while j < len(s) and s[j][0] <= t:
                cur = s[j][1]
                j += 1
            tot_mtm[t] += cur
    closes = sorted(e for evs in closed_by_side.values() for e in evs)
    # cumulative closed on the grid
    cum = {}
    j, run = 0, 0.0
    for t in grid:
        while j < len(closes) and closes[j][0] <= t:
            run += closes[j][1]
            j += 1
        cum[t] = run
    out = []
    day = None
    for t in grid:
        roll = _roll_start(t)
        if day is None or roll != day[0]:
            if day is not None:
                out.append(tuple(day))
            day = [roll, tot_mtm[t], None, cum[t]]
        move = (cum[t] - day[3]) + tot_mtm[t]
        day[2] = move if day[2] is None else min(day[2], move)
    out.append(tuple(day))
    return [(d[0], d[1], d[2]) for d in out]


def _roll_start(t):
    """The latest 22:00Z at or before t."""
    day = int(t // 86400) * 86400
    roll = day + FTMO_ROLL_UTC_HOUR * 3600
    return roll if roll <= t else roll - 86400


def peak_slots(slot_series):
    """Peak of the summed positions + orders across sides (forward-filled)."""
    grid = sorted({t for s in slot_series for t, _ in s})
    best = 0
    idx = [0] * len(slot_series)
    cur = [0] * len(slot_series)
    for t in grid:
        for k, s in enumerate(slot_series):
            while idx[k] < len(s) and s[idx[k]][0] <= t:
                cur[k] = s[idx[k]][1]
                idx[k] += 1
        best = max(best, sum(cur))
    return best
