"""T3 on the FTMO M1 bars: the idealised fxgrind ladder (core.ladder) on all six pairs, whole period.
Paths:  std  = clean path (blow-out bars frozen), run_bars.py's intra-bar order   [primary; conservative order]
        alt  = clean path, high/low swapped                                     [optimistic order]
        raw  = run_bars.py's pseudo-ticks exactly (blow-outs left in, std order) [what a plain bar replay sees]
Modes:  gross  = bid = ask = mid, no commission (tests the path property alone)
        spread = recorded bid/ask (ask = bid + the bar's recorded MINIMUM spread), no commission
        net    = spread minus 0.06 USD per close per 0.01 lot  (USD per pip from run_bars.py)
Cells:  live   = the 12 live arms, exact (width, add, stranded), exit = add, cap 7, deadband 2
        scan   = add a in SCALES, width a/4, stranded a/4 + 1, cap 7, exit a
        design = caps 1, 3, 15 at every a (exit = a); cap 7 with exit a/2 and 2a      (std path only)
Fill models (command line: cont | one):
        cont = "continuous path": every add level a pseudo-tick has traversed fills at its limit price
               (pessimistic in true jumps: news, gaps);
        one  = "one resting add", the EA's rule (ADR-013 clamp, C165 hold); on 15 s pseudo-ticks this is a very slow
               EA that gets better entries in fast moves than a real one would (optimistic). This is also how the
               project's sim.py behaves on bar ticks (07_crosscheck_sim.py). The truth on bars lies between.
Unit of uncertainty: calendar month (change in realised + open mark).
    python 04_ladder_bars.py cont      -> out/04_ladder_cells_cont.csv, out/04_ladder_monthly_cont.csv
    python 04_ladder_bars.py one       -> out/04_ladder_cells_one.csv,  out/04_ladder_monthly_one.csv"""
from common import *
from core import ladder
import multiprocessing as mp, time, sys

FILL = sys.argv[1] if len(sys.argv) > 1 else "cont"
ONE = (FILL == "one")
C0 = np.zeros((0, 7))


def run_cell(tm, bid, ask, tod, per, nper, w, a, x, strd, cap, gross):
    if gross:
        m = 0.5 * (bid + ask)
        o = ladder(m, m, tod, per, nper, w, a, x, strd, 2.0, cap, True, 0, 50, False, C0, ONE)
    else:
        o = ladder(bid, ask, tod, per, nper, w, a, x, strd, 2.0, cap, True, 0, 50, False, C0, ONE)
    return o


def summarise(pair, o, a, months, years):
    real, openp, closes, rclose, rolls, mineq, layers, rloss, spfill = o[:9]
    eq = real + openp
    d = np.diff(np.r_[0.0, eq])
    dc = np.diff(np.r_[0, closes])
    n_close = int(closes[-1])
    usd = d * USD[pair]
    net = usd - COMM * dc
    mn, se, t, n = tstat(d)
    nmn, nse, nt, _ = tstat(net)
    ypos = sum(1 for y in np.unique(years) if net[years == y].sum() > 0)
    ygross = sum(1 for y in np.unique(years) if d[years == y].sum() > 0)
    peak = np.maximum.accumulate(np.r_[0.0, eq[:-1]])
    dd = (peak - mineq).max()
    return dict(months=n, closes=n_close, rolled_closes=int(rclose[-1]), rolls=int(rolls[-1]),
                total_pips=eq[-1], open_pips_end=openp[-1], layers_end=int(layers[-1]), rolled_loss_pips=rloss[-1],
                mean_month_pips=mn, se_month_pips=se, t_pips=t, per_close_pct_rung=100 * eq[-1] / max(n_close, 1) / a,
                closes_per_day=n_close / 989.0, total_usd=usd.sum(), comm_usd=COMM * n_close, net_usd=net.sum(),
                net_month_usd=nmn, net_month_se=nse, net_t=nt, years_pos_net=ypos, years_pos_this=ygross,
                maxdd_pips=dd, spread_at_fills=spfill[-1] / max(2 * n_close, 1)), d, net


def do_pair(pair):
    b = load_bars(pair)
    rows, mrows = [], []
    for path, order, clean in (("std", "std", True), ("alt", "alt", True), ("raw", "std", False)):
        tm, bid, ask = pseudo_ticks(b, order, clean)
        tod = ((tm // 60000) % 1440).astype(np.int64)
        mon = month_id(tm)
        um, per = np.unique(mon, return_inverse=True)
        per = per.astype(np.int64); nper = len(um)
        years = um // 12
        cells = []
        for arm, (w, a, s) in zip(("OPT", "ALT"), GEO[pair]):
            cells.append(("live", arm, w, float(a), float(a), s, 7))
        for a in SCALES:
            cells.append(("scan", "cap7", a / 4.0, float(a), float(a), a / 4.0 + 1, 7))
        if path == "std":
            for a in SCALES:
                for cap in (1, 3, 15):
                    cells.append(("design", "cap%d" % cap, a / 4.0, float(a), float(a), a / 4.0 + 1, cap))
                cells.append(("design", "exit0.5a", a / 4.0, float(a), a / 2.0, a / 4.0 + 1, 7))
                cells.append(("design", "exit2a", a / 4.0, float(a), 2.0 * a, a / 4.0 + 1, 7))
        for kind, name, w, a, x, s, cap in cells:
            res = {}
            for mode, gross in (("gross", True), ("spread", False)):
                o = run_cell(tm, bid, ask, tod, per, nper, w, a, x, s, cap, gross)
                res[mode], d, net = summarise(pair, o, a, um, years)
                base = dict(pair=pair, path=path, kind=kind, name=name, width=w, add=a, exit=x, stranded=s, cap=cap)
                rows.append({**base, "mode": mode, **res[mode]})
                if kind == "live" or (kind == "scan"):
                    for i, u in enumerate(um):
                        mrows.append({**base, "mode": mode, "month": month_label(u), "d_pips": d[i], "net_usd": net[i]})
        sys.stderr.write("%s %s done\n" % (pair, path)); sys.stderr.flush()
    return rows, mrows


if __name__ == "__main__":
    t0 = time.time()
    with mp.Pool(2) as pool:
        out = pool.map(do_pair, PAIRS)
    rows = [r for o in out for r in o[0]]; mrows = [r for o in out for r in o[1]]
    pd.DataFrame(rows).to_csv(os.path.join(OUT, "04_ladder_cells_%s.csv" % FILL), index=False)
    pd.DataFrame(mrows).to_csv(os.path.join(OUT, "04_ladder_monthly_%s.csv" % FILL), index=False)
    print("done in %.0f s, %d cells" % (time.time() - t0, len(rows)))
