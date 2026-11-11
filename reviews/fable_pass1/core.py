"""Core numba routines for the pass-1 review (independent of the project's sim.py). ASCII only.

steps():   T1 -- threshold steps of a mid path, node reset to the ACTUAL mid at each crossing.
ladder():  T3 -- idealised two-sided fxgrind ladder, written from MECHANICS.md:
           L0 at mid -/+ width placed once; flat-side re-centre beyond `stranded` (deadband);
           adds every `add` to `cap`; exits at effective entry + `exit`; lattice rolls / re-rolls at cap,
           roll gate (rolls only while the opposite side holds <= gate layers), re-roll pause 23:50-00:15 server.
           Idealisations: zero latency; a touched limit fills at its own price; every exit rests; an exit whose
           target is already passed when it is (re)priced rests 1 point off the market (as the EA's passive clamp);
           no carry, breaker, slot/API guards.
"""
import numpy as np
from numba import njit

PIP = 1e-4
PT = 1e-5
EPS = 0.5e-5


@njit(cache=True)
def steps(mid, a):
    """a in price units. Returns (idx, dir, node_price) arrays: sample index of each step, +1/-1, node mid."""
    n = len(mid)
    idx = np.empty(n, np.int64)
    dr = np.empty(n, np.int8)
    px = np.empty(n, np.float64)
    k = 0
    node = mid[0]
    for i in range(1, n):
        d = mid[i] - node
        if d >= a - 1e-12:
            idx[k] = i; dr[k] = 1; px[k] = mid[i]; k += 1
            node = mid[i]
        elif d <= -a + 1e-12:
            idx[k] = i; dr[k] = -1; px[k] = mid[i]; k += 1
            node = mid[i]
    return idx[:k], dr[:k], px[:k]


@njit(cache=True)
def steps_grid(p, a):
    """Grid (renko) steps: node moves by exactly a each time the path reaches node +/- a; several steps if a
    sample is several rungs away. This is the right rule for OHLC pseudo-ticks: highs and lows are true extremes
    of a continuous path, so the path really was AT the level when it crossed. (Resetting the node to the sampled
    price, as steps() does, is badly biased on pseudo-ticks: nodes land on bar extremes. See 01_null_calibration.)
    Returns (idx, dir)."""
    n = len(p)
    cap_ = 4 * n + 16
    idx = np.empty(cap_, np.int64)
    dr = np.empty(cap_, np.int8)
    k = 0
    node = p[0]
    for i in range(1, n):
        while p[i] >= node + a - 1e-12:
            node += a
            if k < cap_:
                idx[k] = i; dr[k] = 1; k += 1
        while p[i] <= node - a + 1e-12:
            node -= a
            if k < cap_:
                idx[k] = i; dr[k] = -1; k += 1
    return idx[:k], dr[:k]


@njit(cache=True)
def _add_target(ent, eff, rolled, order, n, is_long, add_px):
    # anchor: most extreme EFFECTIVE entry if any layer is rolled, else the newest layer's entry
    anyr = False
    for j in range(n):
        if rolled[j]:
            anyr = True
            break
    if anyr:
        anchor = eff[0]
        for j in range(1, n):
            if is_long:
                if eff[j] < anchor:
                    anchor = eff[j]
            else:
                if eff[j] > anchor:
                    anchor = eff[j]
    else:
        b = 0
        for j in range(1, n):
            if order[j] > order[b]:
                b = j
        anchor = ent[b]
    return anchor - add_px if is_long else anchor + add_px


@njit(cache=True)
def ladder(bid, ask, tod_min, period, nper, width, add, exit_, stranded, deadband, cap,
           reroll, gate, max_reroll_tick, mkt_fill=False, clog=np.zeros((0, 7)), one_add=False):
    """All distances in pips. period: nondecreasing int per sample in [0, nper).
    Returns per period (values at the period's last sample, cumulative):
      real (pips realised), openp (open mark, pips: longs at bid, shorts at ask), closes, rclose (rolled closes),
      rolls, minEq (lowest realised+open inside the period), layers (open at period end),
      rloss (pips realised on rolled closes), spfill (sum of spread, pips, at entry and exit fills), nlog,
      impr (total price improvement in pips under mkt_fill, one_add mode), nfill (fills counted for it).
    mkt_fill=False: a touched limit fills at its own price (never better). mkt_fill=True: it fills at the market
    price of the touching sample when that is better (buy at min(limit, ask), sell at max(limit, bid)); this is the
    zero-latency version of the replay's "deal at the market" convention (MECHANICS s4). Only meaningful on real ticks.
    one_add=False ("continuous path"): every add level the sample has traversed fills, each at its own limit price.
        Right when the path between two samples was continuous and slow against the EA's ~0.3 s per order.
    one_add=True ("one resting add", as the EA): one add order rests per side; after it fills the next is placed
        at its target, or 1 point outside the market if price is already through the target (ADR-013 clamp), live
        from the next sample; it is re-priced when the target moves by >= deadband, except that a clamped add
        resting at or beyond its target is held (C165). On real ticks this is the EA's rule; on bar pseudo-ticks
        (15 s apart) it behaves like a very slow EA, so the two settings bracket the truth on bars.
    clog: optional (K, 7) array; each close is logged as (sample index, side 0/1, entry, exit price, rolled, eff, open index),
    and each roll as (sample index, 10 + side, entry, new level, was rolled, old eff, open index)."""
    N = len(bid)
    w = width * PIP; A = add * PIP; X = exit_ * PIP; STR = stranded; DB = deadband * PIP
    ent = np.zeros((2, cap)); eff = np.zeros((2, cap)); xp = np.zeros((2, cap))
    rolled = np.zeros((2, cap), np.bool_); order = np.zeros((2, cap), np.int64)
    nl = np.zeros(2, np.int64); nxt = np.zeros(2, np.int64); oi = np.zeros((2, cap), np.int64)
    l0 = np.full(2, np.nan); ext = np.full(2, np.nan); apx = np.full(2, np.nan)
    real = 0.0; closes = 0; rclose = 0; rolls = 0; rloss = 0.0; spfill = 0.0; nlog = 0; KLOG = clog.shape[0]; impr = 0.0; nfill = 0
    o_real = np.zeros(nper); o_open = np.zeros(nper); o_closes = np.zeros(nper, np.int64)
    o_rclose = np.zeros(nper, np.int64); o_rolls = np.zeros(nper, np.int64); o_min = np.full(nper, 1e18)
    o_layers = np.zeros(nper, np.int64); o_rloss = np.zeros(nper); o_spfill = np.zeros(nper)
    for i in range(N):
        b = bid[i]; a = ask[i]; mid = 0.5 * (b + a); sp = (a - b) / PIP
        # ---- 1. exit fills (limit price)
        j = 0
        while j < nl[0]:                                  # longs: sell limit at xp, filled when bid >= xp
            if b >= xp[0, j] - EPS:
                fx = xp[0, j]; nfill += 1
                if mkt_fill and b > fx:
                    impr += (b - fx) / PIP
                    fx = b
                pnl = (fx - ent[0, j]) / PIP
                if nlog < KLOG:
                    clog[nlog, 0] = i; clog[nlog, 1] = 0; clog[nlog, 2] = ent[0, j]; clog[nlog, 3] = fx
                    clog[nlog, 4] = 1.0 if rolled[0, j] else 0.0; clog[nlog, 5] = eff[0, j]; clog[nlog, 6] = oi[0, j]; nlog += 1
                real += pnl; closes += 1; spfill += sp
                if rolled[0, j]:
                    rclose += 1; rloss += pnl
                last = nl[0] - 1
                ent[0, j] = ent[0, last]; eff[0, j] = eff[0, last]; xp[0, j] = xp[0, last]
                rolled[0, j] = rolled[0, last]; order[0, j] = order[0, last]; oi[0, j] = oi[0, last]
                nl[0] = last
            else:
                j += 1
        j = 0
        while j < nl[1]:                                  # shorts: buy limit at xp, filled when ask <= xp
            if a <= xp[1, j] + EPS:
                fx = xp[1, j]; nfill += 1
                if mkt_fill and a < fx:
                    impr += (fx - a) / PIP
                    fx = a
                pnl = (ent[1, j] - fx) / PIP
                if nlog < KLOG:
                    clog[nlog, 0] = i; clog[nlog, 1] = 1; clog[nlog, 2] = ent[1, j]; clog[nlog, 3] = fx
                    clog[nlog, 4] = 1.0 if rolled[1, j] else 0.0; clog[nlog, 5] = eff[1, j]; clog[nlog, 6] = oi[1, j]; nlog += 1
                real += pnl; closes += 1; spfill += sp
                if rolled[1, j]:
                    rclose += 1; rloss += pnl
                last = nl[1] - 1
                ent[1, j] = ent[1, last]; eff[1, j] = eff[1, last]; xp[1, j] = xp[1, last]
                rolled[1, j] = rolled[1, last]; order[1, j] = order[1, last]; oi[1, j] = oi[1, last]
                nl[1] = last
            else:
                j += 1
        # ---- 2. entry fills (limit price)
        for s in range(2):
            is_long = (s == 0)
            if nl[s] == 0:
                if not np.isnan(l0[s]):
                    hit = (a <= l0[s] + EPS) if is_long else (b >= l0[s] - EPS)
                    if hit:
                        p = l0[s]; nfill += 1
                        if mkt_fill:
                            if is_long and a < p:
                                impr += (p - a) / PIP
                                p = a
                            if (not is_long) and b > p:
                                impr += (b - p) / PIP
                                p = b
                        ent[s, 0] = p; eff[s, 0] = p; rolled[s, 0] = False
                        xp[s, 0] = p + X if is_long else p - X
                        order[s, 0] = nxt[s]; nxt[s] += 1; oi[s, 0] = i
                        nl[s] = 1; l0[s] = np.nan; spfill += sp
                        ext[s] = np.nan
            if nl[s] > 0 and one_add:
                if nl[s] < cap and not np.isnan(apx[s]):
                    hit = (a <= apx[s] + EPS) if is_long else (b >= apx[s] - EPS)
                    if hit:
                        tgt = apx[s]; nfill += 1
                        if mkt_fill:
                            if is_long and a < tgt:
                                impr += (tgt - a) / PIP
                                tgt = a
                            if (not is_long) and b > tgt:
                                impr += (b - tgt) / PIP
                                tgt = b
                        k = nl[s]
                        ent[s, k] = tgt; eff[s, k] = tgt; rolled[s, k] = False
                        xp[s, k] = tgt + X if is_long else tgt - X
                        order[s, k] = nxt[s]; nxt[s] += 1; oi[s, k] = i
                        nl[s] = k + 1; spfill += sp
                        ext[s] = np.nan; apx[s] = np.nan
            if nl[s] > 0 and not one_add:
                while nl[s] < cap:
                    tgt = _add_target(ent[s], eff[s], rolled[s], order[s], nl[s], is_long, A)
                    hit = (a <= tgt + EPS) if is_long else (b >= tgt - EPS)
                    if not hit:
                        break
                    if mkt_fill:
                        if is_long and a < tgt:
                            tgt = a
                        if (not is_long) and b > tgt:
                            tgt = b
                    k = nl[s]
                    ent[s, k] = tgt; eff[s, k] = tgt; rolled[s, k] = False
                    xp[s, k] = tgt + X if is_long else tgt - X
                    order[s, k] = nxt[s]; nxt[s] += 1; oi[s, k] = i
                    nl[s] = k + 1; spfill += sp
                    ext[s] = np.nan
        # ---- 3. lattice at cap
        paused = (tod_min[i] >= 23 * 60 + 50) or (tod_min[i] < 15)
        for s in range(2):
            is_long = (s == 0)
            o = 1 - s
            if nl[s] < cap:
                ext[s] = np.nan
                continue
            if gate >= 0 and nl[o] > gate:
                ext[s] = np.nan                           # extreme restarts when the gate releases
                continue
            mkt = a if is_long else b
            if np.isnan(ext[s]):
                ext[s] = mkt
            elif is_long:
                if mkt < ext[s]:
                    ext[s] = mkt
            else:
                if mkt > ext[s]:
                    ext[s] = mkt
            rr = 0
            for it in range(200):
                level = _add_target(ent[s], eff[s], rolled[s], order[s], nl[s], is_long, A)
                crossed = (ext[s] <= level + 1e-9) if is_long else (ext[s] >= level - 1e-9)
                if not crossed:
                    break
                c = -1
                for j in range(nl[s]):                    # candidate: highest-entry (long) layer not yet rolled
                    if rolled[s, j]:
                        continue
                    if c < 0:
                        c = j
                    elif is_long:
                        if ent[s, j] > ent[s, c] or (ent[s, j] == ent[s, c] and order[s, j] < order[s, c]):
                            c = j
                    else:
                        if ent[s, j] < ent[s, c] or (ent[s, j] == ent[s, c] and order[s, j] < order[s, c]):
                            c = j
                if c < 0:
                    if (not reroll) or rr >= max_reroll_tick or paused:
                        break
                    for j in range(nl[s]):                # re-roll: the highest-VL (long) layer
                        if c < 0:
                            c = j
                        elif is_long:
                            if eff[s, j] > eff[s, c]:
                                c = j
                        else:
                            if eff[s, j] < eff[s, c]:
                                c = j
                    rr += 1
                if nlog < KLOG:
                    clog[nlog, 0] = i; clog[nlog, 1] = 10 + s; clog[nlog, 2] = ent[s, c]; clog[nlog, 3] = level
                    clog[nlog, 4] = 1.0 if rolled[s, c] else 0.0; clog[nlog, 5] = eff[s, c]; clog[nlog, 6] = oi[s, c]; nlog += 1
                eff[s, c] = level; rolled[s, c] = True; rolls += 1
                if is_long:
                    t_ = level + X
                    xp[s, c] = t_ if t_ > b + PT else b + PT      # passive clamp
                else:
                    t_ = level - X
                    xp[s, c] = t_ if t_ < a - PT else a - PT
        # ---- 4. L0 maintenance (effective from the next sample)
        for s in range(2):
            is_long = (s == 0)
            o = 1 - s
            if nl[s] > 0:
                l0[s] = np.nan
                continue
            if is_long:
                tgt = mid - w
                if tgt >= b:
                    tgt = b - PT
            else:
                tgt = mid + w
                if tgt <= a:
                    tgt = a + PT
            if np.isnan(l0[s]):
                l0[s] = tgt
            elif nl[o] > 0:
                if abs(l0[s] - mid) / PIP > STR and abs(tgt - l0[s]) >= DB - EPS:
                    l0[s] = tgt
        # ---- 4b. the resting add (one_add mode), effective from the next sample
        if one_add:
            for s in range(2):
                is_long = (s == 0)
                if nl[s] == 0 or nl[s] >= cap:
                    apx[s] = np.nan
                    continue
                tgt = _add_target(ent[s], eff[s], rolled[s], order[s], nl[s], is_long, A)
                des = tgt; clamped = False
                if is_long and tgt >= b:
                    des = b - PT; clamped = True
                if (not is_long) and tgt <= a:
                    des = a + PT; clamped = True
                if np.isnan(apx[s]):
                    apx[s] = des
                else:
                    hold = False
                    if clamped:
                        if is_long:
                            hold = (apx[s] <= tgt + 0.1 * PT) and (des < apx[s] - 0.1 * PT)
                        else:
                            hold = (apx[s] >= tgt - 0.1 * PT) and (des > apx[s] + 0.1 * PT)
                    if (not hold) and abs(des - apx[s]) >= DB - EPS:
                        apx[s] = des
        # ---- marks
        op = 0.0
        for j in range(nl[0]):
            op += (b - ent[0, j]) / PIP
        for j in range(nl[1]):
            op += (ent[1, j] - a) / PIP
        p = period[i]
        eq = real + op
        if eq < o_min[p]:
            o_min[p] = eq
        o_real[p] = real; o_open[p] = op; o_closes[p] = closes; o_rclose[p] = rclose; o_rolls[p] = rolls
        o_layers[p] = nl[0] + nl[1]; o_rloss[p] = rloss; o_spfill[p] = spfill
    return o_real, o_open, o_closes, o_rclose, o_rolls, o_min, o_layers, o_rloss, o_spfill, nlog, impr, nfill
