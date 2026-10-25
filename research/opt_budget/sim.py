"""OPT budget simulator: fxgrind's engine and the replay's timed broker, in Python (MECHANICS.md).

One instance = one arm on one pair; run_pair() runs OPT and ALT on the same ticks and, with budget=True, gates OPT's
adds by ALT's depth (PREREG.md s2). Prices in quote units, pips at 5 digits (1 pip = 10 points)."""
import datetime as _dt
import heapq
from dataclasses import dataclass, field

PT = 0.00001
PIP = 10 * PT
EPS = PT * 0.5
D_PLACE, D_MODIFY, D_CLOSEBY, D_REMOVE, D_LAM = 287, 288, 294, 43, 261   # sens base (MECHANICS s4)
EXITQ_K = 1


def r5(x):
    return round(x + 0.0, 5)


@dataclass
class Cfg:
    width: float
    add: float
    exit: float
    cap: int
    stranded: float
    deadband: float
    lattice: bool = True
    reroll: bool = True
    gate: int = 0
    carry: bool = False


@dataclass(eq=False)
class Layer:
    entry: float
    idx: int
    vl: float = None
    open_ms: int = 0
    exit_order: object = None
    closing: bool = False
    exit_fill: float = None
    swap_pips: float = 0.0
    depth_open: int = 0

    def eff(self):
        return self.vl if self.vl is not None else self.entry


@dataclass(eq=False)
class Order:
    is_buy: bool
    price: float
    live_ms: int
    role: str            # "ENT" or "EXT"
    side: str            # "L" or "S"
    layer: object = None
    mods: list = field(default_factory=list)
    removed_ms: int = None
    exec: bool = False       # touched at the broker (deal pending)
    done: bool = False       # the deal handler has run (the EA no longer sees the order)

    def price_at(self, t):
        px, best = self.price, -1
        for f, p in self.mods:
            if best < f <= t:
                best, px = f, p
        return px

    def resting(self):
        # as the EA sees it: a touched order whose deal is not yet processed is still its order (the replay keeps the
        # order record until the deal handler runs, fxgrind_replay_core.mqh 1217-1236, 1036-1070)
        return not self.done and self.removed_ms is None


@dataclass
class Close:
    side: str
    entry: float
    exit: float
    rolled: bool
    open_ms: int
    close_ms: int
    swap_pips: float
    depth_open: int = 0      # (output only) the side's depth once this layer joined: its place in the stack


# ---------------------------------------------------------------- pure rules (tested)
def budget(a, variant="B"):
    if variant == "B2":                      # PREREG_B2.md: two sections of four (cap 7: layers 1-4, 5-7)
        return 4 if a <= 4 else 7
    return 3 if a <= 3 else (6 if a <= 6 else 7)


def opt_add_target(d, a, own, alt_resting, variant="B"):
    if d < budget(a, variant):
        return own
    if d < 7 and a == d and alt_resting is not None:
        return alt_resting
    return None


def straddle(bid, ask, width):
    mid = (bid + ask) / 2.0
    return r5(mid - width * PIP), r5(mid + width * PIP)


def clamp_buy(price, bid):
    return r5(min(price, bid - PT)) if price >= bid else r5(price)


def clamp_sell(price, ask):
    return r5(max(price, ask + PT)) if price <= ask else r5(price)


def add_target(layers, is_long, add):
    if not layers:
        return None
    if any(l.vl is not None for l in layers):
        effs = [l.eff() for l in layers]
        anchor = min(effs) if is_long else max(effs)
    else:
        anchor = max(layers, key=lambda l: l.idx).entry
    return r5(anchor - add * PIP if is_long else anchor + add * PIP)


def _ranks(layers, is_long):
    out = []
    for i, li in enumerate(layers):
        rk = 0
        for j, lj in enumerate(layers):
            if j == i:
                continue
            a, b = lj.eff(), li.eff()
            if is_long:
                beats = a < b - EPS or (abs(a - b) <= EPS and lj.idx < li.idx)
            else:
                beats = a > b + EPS or (abs(a - b) <= EPS and lj.idx < li.idx)
            rk += beats
        out.append(rk)
    return out


def resting_exit_idx(layers, is_long):
    n = len(layers)
    return [i for i, rk in enumerate(_ranks(layers, is_long)) if rk < EXITQ_K or rk == n - 1]


def roll_candidate(layers, is_long):
    best = None
    for i, l in enumerate(layers):
        if l.vl is not None:
            continue
        if best is None:
            best = i
            continue
        b = layers[best]
        if is_long:
            better = l.entry > b.entry or (l.entry == b.entry and l.idx < b.idx)
        else:
            better = l.entry < b.entry or (l.entry == b.entry and l.idx < b.idx)
        if better:
            best = i
    return best


def reroll_candidate(layers, is_long):
    best = None
    for i, l in enumerate(layers):
        if l.vl is None:
            continue
        if best is None or (l.vl > layers[best].vl if is_long else l.vl < layers[best].vl):
            best = i
    return best


# ---------------------------------------------------------------- one instance
class Side:
    def __init__(self, is_long):
        self.is_long = is_long
        self.layers = []
        self.l0 = None
        self.add = None
        self.extreme = None
        self.track_from = 0

    def depth(self):
        return len(self.layers)

    def next_idx(self):
        return (max(l.idx for l in self.layers) + 1) if self.layers else 0


class Instance:
    def __init__(self, cfg, name="x"):
        self.cfg, self.name = cfg, name
        self.side = {"L": Side(True), "S": Side(False)}
        self.orders = []
        self.events = []
        self.seq = 0
        self.busy = 0
        self.cb_queue = []
        self.closes = []
        self.rolls = 0
        self.peer = None          # ALT instance, for OPT under the budget
        self.budget = False
        self.variant = "B"
        self.bid = self.ask = None
        self.ent_sent = False

    # --- views
    def book(self, s):
        return sorted(self.side[s].layers, key=lambda l: l.idx)

    def resting_add_price(self, s, t):
        o = self.side[s].add
        return o.price_at(t + D_MODIFY) if (o is not None and o.resting()) else None

    # --- sends (each advances the EA's cursor)
    def _place(self, cur, is_buy, price, role, s, layer=None):
        cur += D_PLACE
        o = Order(is_buy=is_buy, price=r5(price), live_ms=cur, role=role, side=s, layer=layer)
        self.orders.append(o)
        return o, cur

    def _modify(self, cur, o, price):
        cur += D_MODIFY
        o.mods.append((cur, r5(price)))
        return cur

    def _remove(self, cur, o):
        cur += D_REMOVE
        o.removed_ms = cur
        return cur

    def _push(self, due, kind, payload):
        self.seq += 1
        heapq.heappush(self.events, (due, self.seq, kind, payload))

    # --- exits
    def exit_target(self, l, is_long):
        c = self.cfg
        f = l.eff() + (c.exit * PIP if is_long else -c.exit * PIP)
        if c.carry:
            f -= (1 if is_long else -1) * l.swap_pips * PIP
        return r5(f)

    def exit_passive(self, target, is_long):
        if is_long:
            return r5(max(target, self.bid + PT))
        return r5(min(target, self.ask - PT))

    def exitq(self, s, cur):
        sd = self.side[s]
        lay = sd.layers
        n = len(lay)
        if n == 0:
            return cur
        rk = _ranks(lay, sd.is_long)
        for i, l in enumerate(lay):
            allowed = rk[i] < EXITQ_K or rk[i] == n - 1
            if not allowed and l.exit_order is not None and l.exit_order.resting():
                cur = self._remove(cur, l.exit_order)
                l.exit_order = None
        for i, l in enumerate(lay):
            if not (rk[i] < EXITQ_K or rk[i] == n - 1):
                continue
            if l.closing or (l.exit_order is not None and l.exit_order.resting()):
                continue
            px = self.exit_passive(self.exit_target(l, sd.is_long), sd.is_long)
            l.exit_order, cur = self._place(cur, not sd.is_long, px, "EXT", s, layer=l)
        return cur

    # --- adds
    def own_add_target(self, s, t):
        sd = self.side[s]
        own = add_target(sd.layers, sd.is_long, self.cfg.add)
        if own is None or not (self.budget and self.peer is not None):
            return own
        a = self.peer.side[s].depth()
        return opt_add_target(sd.depth(), a, own, self.peer.resting_add_price(s, t), self.variant)

    def _add_px(self, sd, tgt):
        px = clamp_buy(tgt, self.bid) if sd.is_long else clamp_sell(tgt, self.ask)
        ok = px < self.ask if sd.is_long else px > self.bid
        return px if ok else None

    def send_add(self, s, cur, t):
        sd = self.side[s]
        n = sd.depth()
        if n <= 0 or n >= self.cfg.cap:
            return cur
        if sd.add is not None and sd.add.resting():
            return cur
        tgt = self.own_add_target(s, t)
        if tgt is None or self.ent_sent:
            return cur
        px = self._add_px(sd, tgt)
        if px is None:
            return cur
        sd.add, cur = self._place(cur, sd.is_long, px, "ENT", s)
        self.ent_sent = True
        return cur

    def ensure_add(self, s, cur, t):
        sd = self.side[s]
        n = sd.depth()
        if n <= 0 or n >= self.cfg.cap:
            return cur
        tgt = self.own_add_target(s, t)
        if tgt is None:
            if sd.add is not None and sd.add.resting():
                cur = self._remove(cur, sd.add)
                sd.add = None
            return cur
        px = self._add_px(sd, tgt)
        if px is None:
            return cur
        if sd.add is not None and sd.add.resting():
            if abs(sd.add.price_at(cur + D_MODIFY) - px) >= self.cfg.deadband * PIP - EPS:
                cur = self._modify(cur, sd.add, px)
            return cur
        return self.send_add(s, cur, t)

    # --- the lattice
    def lattice(self, s, cur, t):
        c, sd = self.cfg, self.side[s]
        opp = self.side["S" if s == "L" else "L"]
        if sd.depth() < c.cap:
            sd.extreme = None
            return cur
        if c.gate >= 0 and opp.depth() > c.gate:
            sd.extreme = None
            sd.track_from = t
            return cur
        mkt = self.ask if sd.is_long else self.bid
        newest = max(l.open_ms for l in sd.layers)
        if sd.extreme is None or sd.track_from < newest:
            sd.extreme, sd.track_from = mkt, max(newest, sd.track_from)
        sd.extreme = min(sd.extreme, mkt) if sd.is_long else max(sd.extreme, mkt)
        rerolls = 0
        for _ in range(c.cap):
            level = add_target(sd.layers, sd.is_long, c.add)
            crossed = sd.extreme <= level + EPS if sd.is_long else sd.extreme >= level - EPS
            if not crossed:
                break
            i = roll_candidate(sd.layers, sd.is_long)
            if i is None:
                if not c.reroll or rerolls >= 1:
                    break
                i = reroll_candidate(sd.layers, sd.is_long)
                if i is None:
                    break
                rerolls += 1
            l = sd.layers[i]
            if l.closing:
                break
            l.vl = level
            self.rolls += 1
            if l.exit_order is not None and l.exit_order.resting():
                tgt = self.exit_passive(self.exit_target(l, sd.is_long), sd.is_long)
                cur = self._modify(cur, l.exit_order, tgt)
            cur = self.exitq(s, cur)
        return cur

    # --- the EA's OnTick (timed: drops the tick while busy)
    def on_tick(self, t):
        if self.busy > t:
            return
        cur = t
        c = self.cfg
        self.ent_sent = False
        while self.cb_queue:
            l, s = self.cb_queue.pop(0)
            cur += D_CLOSEBY
            self._push(cur, "CB_DONE", (l, s))
        if c.lattice:
            for s in ("L", "S"):
                cur = self.lattice(s, cur, t)
        bid, ask = self.bid, self.ask
        mid = (bid + ask) / 2.0
        buy_t, sell_t = straddle(bid, ask, c.width)
        buy_t, sell_t = clamp_buy(buy_t, bid), clamp_sell(sell_t, ask)
        L, S = self.side["L"], self.side["S"]
        for sd, tgt, s in ((L, buy_t, "L"), (S, sell_t, "S")):
            if sd.depth() == 0 and (sd.l0 is None or not sd.l0.resting()) and not self.ent_sent:
                if (tgt < ask) if sd.is_long else (tgt > bid):
                    sd.l0, cur = self._place(cur, sd.is_long, tgt, "ENT", s)
                    self.ent_sent = True
        for busy_side, flat, s in ((L, S, "S"), (S, L, "L")):
            if busy_side.depth() > 0 and flat.depth() == 0 and flat.l0 is not None and flat.l0.resting():
                resting = flat.l0.price_at(cur + D_MODIFY)
                if abs(resting - mid) / PIP > c.stranded:
                    tgt = r5(mid + c.width * PIP) if s == "S" else r5(mid - c.width * PIP)
                    tgt = clamp_sell(tgt, ask) if s == "S" else clamp_buy(tgt, bid)
                    ok = tgt > bid if s == "S" else tgt < ask
                    if ok and abs(tgt - resting) >= c.deadband * PIP - EPS:
                        cur = self._modify(cur, flat.l0, tgt)
        for s in ("L", "S"):
            cur = self.ensure_add(s, cur, t)
        self.busy = cur

    # --- broker
    def broker(self, t, sess_open):
        if not sess_open:
            return
        keep = []
        for o in self.orders:
            if o.exec or (o.removed_ms is not None and o.removed_ms <= t):
                continue
            if o.live_ms <= t:
                px = o.price_at(t)
                if (o.is_buy and self.ask <= px) or (not o.is_buy and self.bid >= px):
                    o.exec = True
                    self._push(t + D_LAM, "DEAL", o)
                    continue
            keep.append(o)
        self.orders = keep

    # --- events (deal and close-by handlers)
    def run_events(self, t, prev, cur_tick):
        while self.events and self.events[0][0] <= t:
            due, _, kind, pay = heapq.heappop(self.events)
            mk = cur_tick if due >= t else prev
            save = (self.bid, self.ask)
            self.bid, self.ask = mk[1], mk[2]
            cur = max(due, self.busy)
            if kind == "DEAL":
                cur = self.on_deal(pay, due, cur)
            else:
                cur = self.on_closeby(pay, due, cur)
            self.busy = cur
            self.bid, self.ask = save

    def on_deal(self, o, due, cur):
        o.done = True
        price = self.ask if o.is_buy else self.bid
        s = o.side
        sd = self.side[s]
        if o.role == "ENT":
            if o is sd.l0:
                sd.l0 = None
            if o is sd.add:
                sd.add = None
            sd.layers.append(Layer(entry=r5(price), idx=sd.next_idx(), open_ms=due, depth_open=sd.depth() + 1))
            cur = self.exitq(s, cur)
            save = self.ent_sent
            self.ent_sent = False
            cur = self.send_add(s, cur, due)
            self.ent_sent = save
        else:
            l = o.layer
            if l in sd.layers and not l.closing:
                l.closing = True
                l.exit_fill = r5(price)
                l.exit_order = None
                self.cb_queue.append((l, s))
        return cur

    def on_closeby(self, pay, due, cur):
        l, s = pay
        sd = self.side[s]
        if l not in sd.layers:
            return cur
        sd.layers.remove(l)
        self.closes.append(Close(side=s, entry=l.entry, exit=l.exit_fill, rolled=l.vl is not None,
                                 open_ms=l.open_ms, close_ms=due, swap_pips=l.swap_pips,
                                 depth_open=l.depth_open))
        return self.exitq(s, cur)

    # --- carry
    def rollover(self, t, row):
        if not self.cfg.carry or row is None:
            return
        pl, ps, mult = row
        for s, sd in self.side.items():
            pts = pl if s == "L" else ps
            for l in sd.layers:
                l.swap_pips += pts * mult / 10.0
                if l.exit_order is not None and l.exit_order.resting():
                    tgt = self.exit_passive(self.exit_target(l, sd.is_long), sd.is_long)
                    l.exit_order.mods.append((t + D_MODIFY, tgt))

    # --- marks
    def realised_pips(self):
        return sum(((c.exit - c.entry) if c.side == "L" else (c.entry - c.exit)) / PIP + c.swap_pips
                   for c in self.closes)

    def open_pips(self, bid, ask):
        tot = 0.0
        for s, sd in self.side.items():
            for l in sd.layers:
                px = bid if s == "L" else ask
                tot += ((px - l.entry) if s == "L" else (l.entry - px)) / PIP + l.swap_pips
        return tot


@dataclass
class PairResult:
    opt: Instance
    alt: Instance
    marks: list


def _session_open(ms, sessions):
    if sessions is None:
        return True
    d = _dt.datetime.fromtimestamp(ms / 1000, _dt.timezone.utc)
    rng = sessions.get(d.isoweekday())
    if rng is None:
        return False
    m = d.hour * 60 + d.minute
    return rng[0] <= m <= rng[1]


def run_instances(ticks, insts, carry_rows=None, sessions=None, mark_ms=300000, occ=None):
    """Run instances on the same ticks, in order (ALT before OPT). Returns marks every mark_ms:
    (t, [(realised_pips, open_pips, closes) per instance]), plus the last tick."""
    prev = None
    day = None
    marks = []
    next_mark = None
    for tk in ticks:
        t, bid, ask = tk
        if prev is None:
            prev = tk
            next_mark = (t // mark_ms + 1) * mark_ms
        d = t // 86400000
        if day is not None and d != day and carry_rows is not None:
            key = _dt.datetime.fromtimestamp(t / 1000, _dt.timezone.utc).strftime("%Y.%m.%d")
            for it in insts:
                it.rollover(t, carry_rows.get(key))
        day = d
        while next_mark <= t:
            marks.append((next_mark, [(it.realised_pips(), it.open_pips(prev[1], prev[2]), len(it.closes))
                                      for it in insts]))
            next_mark += mark_ms
        if occ is not None and len(insts) == 2:
            # (output only) time at each (side, OPT depth, ALT depth); gaps over 60 s count 60 s
            dt_ms = min(t - prev[0], 60000)
            for sd in ("L", "S"):
                k = "%s|%d|%d" % (sd, insts[1].side[sd].depth(), insts[0].side[sd].depth())
                occ[k] = occ.get(k, 0) + dt_ms
        sess = _session_open(t, sessions)
        for it in insts:
            it.run_events(t, prev, tk)
            it.bid, it.ask = bid, ask
            it.broker(t, sess)
        for it in insts:
            it.on_tick(t)
        prev = tk
    if prev is not None:
        marks.append((prev[0], [(it.realised_pips(), it.open_pips(prev[1], prev[2]), len(it.closes))
                                for it in insts]))
    return marks


def run_single(ticks, cfg, carry_rows=None, sessions=None):
    it = Instance(cfg, "one")
    run_instances(ticks, [it], carry_rows, sessions)
    return it


def run_pair(ticks, cfg_opt, cfg_alt, carry_rows=None, budget=False, sessions=None, variant="B"):
    alt = Instance(cfg_alt, "ALT")
    opt = Instance(cfg_opt, "OPT")
    opt.peer, opt.budget, opt.variant = alt, budget, variant
    occ = {}
    marks = run_instances(ticks, [alt, opt], carry_rows, sessions, occ=occ)
    r = PairResult(opt=opt, alt=alt, marks=marks)
    r.occ = occ
    return r
