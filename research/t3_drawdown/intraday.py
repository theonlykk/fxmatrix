"""t3 October intraday: equity every 5 min (server ms) with sweep9's accounting (positions, commission per close,
swap from CARRY_SNAPSHOT, open marked at bid / ask), per cell and as a 12-cell fleet in USD at 0.01 lots.
FTMO daily loss = balance at the FTMO day start (01:00 server = 22:00Z in summer) - the day's lowest equity;
balance = closed P&L - commission + swap of closed positions. Self-check: day-end equity == committed curves."""
import sys, csv, os, bisect
sys.path.insert(0, '/root/fxmatrix/research/replay'); sys.path.insert(0, '/root/fxmatrix/research/replay/results/sweep9')
import numpy as np
import score9 as s9
U = '/mnt/user-data/uploads/replay/'; RES = '/root/fxmatrix/research/replay/results/'
PIP = {"EURUSD": 0.100, "GBPUSD": 0.100, "EURGBP": 0.134, "AUDCAD": 0.0714, "AUDCHF": 0.122, "CADCHF": 0.122}
T3 = {"GBPUSD": (9, 15), "EURUSD": (7, 23), "EURGBP": (5, 23), "AUDCAD": (18, 26), "AUDCHF": (14, 20), "CADCHF": (10, 17)}
STEP = 5 * 60000
def run_for(pair, add):
    if pair == 'EURUSD': return 'sw9_d7'
    if pair == 'EURGBP' and add == 5: return 'sw11o_eurgbp'
    return 'sw10_' + pair.lower()
def committed(pair, g):
    f = RES + ('sweep9/sw9_curves.csv' if pair == 'EURUSD' else 'sweep10/sw10_%s_curves.csv' % pair.lower())
    for r in csv.reader(open(f)):
        if r[0] == g: return [float(x) for x in r[1:]]
    return None
ticks = {}
def T(pair):
    if pair not in ticks:
        ticks[pair] = s9.Ticks(U + ('ticks_53077984_EURUSD_w2hw.csv' if pair == 'EURUSD' else 'ticks_53077984_%s_oct.csv' % pair))
    return ticks[pair]
def cell(pair, add):
    tag = run_for(pair, add)
    segs, names, pos, scalps, snaps, counts = s9.load_run(U + 'run_%s.csv' % tag, U + 'out_%s_free_deals.csv' % tag,
                                                         U + 'out_%s_free_events.csv' % tag)
    g = 'a%de%dn7' % (add, add)
    seg = [s for s, n in names.items() if n == g]; assert len(seg) == 1, (pair, add, seg); seg = seg[0]
    r = segs[seg]; f0, t1 = int(r['from_ms']), int(r['to_ms'])
    p, sc, sn = pos.get(seg, []), sorted(scalps.get(seg, [])), snaps.get(seg, [])
    comm = 0.06 / PIP[pair]
    tk = T(pair)
    # self-check: day ends reproduce the committed curve
    ends = s9.day_ends(f0, t1)
    mine = [0.0] + [s9.equity_at(p, sc, sn, e, tk.mark, comm=comm) for e in ends]
    ref = committed(pair, g)
    if ref is not None:
        bad = max(abs(a - b) for a, b in zip(mine, ref))
        assert len(mine) == len(ref) and bad < 0.11, (pair, add, bad)
    # per-position swap credited by time
    P = np.array([[d, o, opx, c if c is not None else 2**62, cpx if cpx is not None else 0.0, w] for d, o, opx, c, cpx, w in p], float) if p else np.zeros((0, 6))
    sw_t, sw_v, sw_close = [], [], []
    for s_ms, sl, ss, mult in sn:
        for i, (d, o, _o, c, _c, _w) in enumerate(p):
            if o <= s_ms and (c is None or c > s_ms):
                sw_t.append(s_ms); sw_v.append((sl if d == 1 else ss) * mult / 10.0); sw_close.append(c if c is not None else 2**62)
    sw_t, sw_v, sw_close = np.array(sw_t), np.array(sw_v), np.array(sw_close)
    times = np.arange(f0, t1 + 1, STEP); eq = np.empty(len(times)); bal = np.empty(len(times))
    for k, t in enumerate(times):
        opened = P[:, 1] <= t; closed = opened & (P[:, 3] <= t); openp = opened & ~closed
        realised = float(np.sum(P[closed, 5] * P[closed, 0] * (P[closed, 4] - P[closed, 2]))) * 10000.0
        mk = tk.mark(int(t)); fl = 0.0
        if openp.any() and mk:
            px = np.where(P[openp, 0] == 1, mk[0], mk[1])
            fl = float(np.sum(P[openp, 0] * (px - P[openp, 2]))) * 10000.0
        nc = bisect.bisect_right(sc, int(t)) * comm
        swc = float(np.sum(sw_v[sw_t <= t])) if len(sw_t) else 0.0
        swb = float(np.sum(sw_v[(sw_t <= t) & (sw_close <= t)])) if len(sw_t) else 0.0
        eq[k] = (realised + fl - nc + swc) * PIP[pair]; bal[k] = (realised - nc + swb) * PIP[pair]
    return times, eq, bal, (mine[-1], ref[-1] if ref else None)
if __name__ == '__main__':
    out = {}
    for pair, (o, a) in T3.items():
        for arm, add in (('OPT', o), ('ALT', a)):
            times, eq, bal, chk = cell(pair, add)
            out[(pair, arm)] = (times, eq, bal)
            print('%s %s %d: end %+.2f USD (pips %s vs committed %s), low %+.2f' % (pair, arm, add, eq[-1], round(chk[0], 1), chk[1], eq.min()), flush=True)
    np.save('/tmp/claude-0/-home-claude/8c85a736-7cc7-58a4-8120-9c451cc4c3f8/scratchpad/t3dd/cells.npy', {('%s|%s' % k): v for k, v in out.items()}, allow_pickle=True)
