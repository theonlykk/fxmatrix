"""T5 on IC Markets raw ticks, 3 Aug - 21 Oct 2026 (about 11 weeks), six pairs.
A. T1 on the tick mid (grid nodes and actual-price nodes), weekly SE; spread actually quoted at the steps.
B. Bar-method validation: MT5-style M1 bars built from the same ticks (bid OHLC + minimum spread), run through the
   bar pipeline (std / alt clean paths, raw path) and compared with the tick truth: r(a) and the ladder.
   lambda = (truth - std) / (alt - std): where the truth sits inside the std..alt bracket.
C. T3 on ticks: the 12 live arms and a scale scan, gross (mid) / spread (real bid, ask) / net (with commission), weekly.
   Tick fill models: one = one resting add per side, the EA's rule (primary on ticks); cont = every traversed level fills;
   one_mkt = one resting add and a touched limit deals at the market of the touching tick when that is better
   (zero-latency version of the replay's "deal at the market"). Bars from ticks: cont and one, std / alt / raw paths.
Outputs: out/06_ticks_T1.csv, out/06_ticks_ladder.csv, out/06_ticks_tests.txt"""
from ticks import *
from core import steps, steps_grid, ladder
import multiprocessing as mp, sys

C0 = np.zeros((0, 7))
T1_SCALES = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 12, 14, 18, 23, 30]
LAD_SCALES = [3, 4, 5, 6, 7, 8, 9, 10, 12, 14, 18, 23, 30]


def rate(d):
    return (d[1:] != d[:-1]).mean() if len(d) > 2 else np.nan


def lad_run(pair, tm, bid, ask, w, a, s, gross, rr, mkt=False, one=False):
    tod = ((tm // 60000) % 1440).astype(np.int64)
    uw, per = np.unique(week_id(tm), return_inverse=True)
    per = per.astype(np.int64)
    if gross:
        m = 0.5 * (bid + ask)
        o = ladder(m, m, tod, per, len(uw), w, a, a, s, 2.0, 7, True, 0, rr, mkt, C0, one)
    else:
        o = ladder(bid, ask, tod, per, len(uw), w, a, a, s, 2.0, 7, True, 0, rr, mkt, C0, one)
    eq = o[0] + o[1]
    d = np.diff(np.r_[0.0, eq]); dc = np.diff(np.r_[0, o[2]])
    net = d * USD[pair] - COMM * dc
    mn, se, t, n = tstat(d); nm, nse, nt, _ = tstat(net)
    return dict(closes=int(o[2][-1]), rolled=int(o[3][-1]), total_pips=eq[-1], per_close_pct_rung=100 * eq[-1] / max(o[2][-1], 1) / a,
                week_pips=mn, week_se=se, t=t, weeks=n, net_usd=net.sum(), net_week=nm, net_week_se=nse, net_t=nt,
                open_pips=o[1][-1], spread_at_fills=o[8][-1] / max(2 * o[2][-1], 1))


def do_pair(pair):
    t, bid, ask = load_ticks(pair)
    mid = 0.5 * (bid + ask); sp = (ask - bid) / PIP
    wk = week_id(t); hr = (t // 3600000) % 24
    b = bars_from_ticks(t, bid, ask)
    paths = {}
    for name, order, clean in (("std", "std", True), ("alt", "alt", True), ("raw", "std", False)):
        paths[name] = pseudo_ticks(b, order, clean)
    r1, r2 = [], []
    for a in T1_SCALES:
        idx, d = steps_grid(mid, a * PIP)
        rev = (d[1:] != d[:-1]).astype(float); e = idx[:-1]; x = idx[1:]
        wr = np.array([rev[wk[e] == u].mean() for u in np.unique(wk[e]) if (wk[e] == u).sum() >= 5])
        mn, se, tt, n = tstat(wr - 0.5)
        core = (hr[e] >= 2) & (hr[e] <= 21)
        spr = 0.5 * (sp[e] + sp[x])
        ia, da, pa = steps(mid, a * PIP)
        ra = (da[1:] != da[:-1]); ca = (hr[ia[:-1]] >= 2) & (hr[ia[:-1]] <= 21)
        row = dict(pair=pair, a=a, steps=len(d), r_grid=rev.mean(), r_week_mean=0.5 + mn, r_se=se, t=tt, weeks=n,
                   r_core=rev[core].mean(), n_core=int(core.sum()), r_actual=rate(da), r_actual_core=ra[ca].mean(),
                   spread_at_steps=spr.mean(), spread_at_steps_core=spr[core].mean(), comm=comm_pips(pair),
                   F_gross=a * (2 * rev.mean() - 1), F_net=a * (2 * rev.mean() - 1) - comm_pips(pair) - spr.mean(),
                   F_core_net=a * (2 * rev[core].mean() - 1) - comm_pips(pair) - spr[core].mean())
        for name, (tm, pb, pa_) in paths.items():
            pm = 0.5 * (pb + pa_)
            i2, d2 = steps_grid(pm, a * PIP)
            row["r_bar_" + name] = rate(d2); row["steps_bar_" + name] = len(d2)
            if name in ("std", "alt"):
                h2 = (tm[i2[:-1]] // 3600000) % 24
                c2 = (h2 >= 2) & (h2 <= 21)
                row["r_bar_%s_core" % name] = (d2[1:] != d2[:-1])[c2].mean()
        r1.append(row)
    cells = [("live", arm, w, float(a), s) for arm, (w, a, s) in zip(("OPT", "ALT"), GEO[pair])]
    cells += [("scan", "cap7", a / 4.0, float(a), a / 4.0 + 1) for a in LAD_SCALES]
    for kind, name, w, a, s in cells:
        for mode, gross in (("gross", True), ("spread", False)):
            base = dict(pair=pair, kind=kind, name=name, width=w, add=a, mode=mode)
            r2.append({**base, "path": "tick", **lad_run(pair, t, bid, ask, w, a, s, gross, 1)})
            r2.append({**base, "path": "tick_one", **lad_run(pair, t, bid, ask, w, a, s, gross, 1, False, True)})
            r2.append({**base, "path": "tick_one_mkt", **lad_run(pair, t, bid, ask, w, a, s, gross, 1, True, True)})
            for pn, (tm, pb, pa_) in paths.items():
                r2.append({**base, "path": pn, **lad_run(pair, tm, pb, pa_, w, a, s, gross, 50)})
                r2.append({**base, "path": pn + "_one", **lad_run(pair, tm, pb, pa_, w, a, s, gross, 50, False, True)})
    sys.stderr.write(pair + " done\n"); sys.stderr.flush()
    return r1, r2


if __name__ == "__main__":
    with mp.Pool(2) as pool:
        out = pool.map(do_pair, PAIRS)
    A = pd.DataFrame([r for o in out for r in o[0]]); B = pd.DataFrame([r for o in out for r in o[1]])
    A.to_csv(os.path.join(OUT, "06_ticks_T1.csv"), index=False); B.to_csv(os.path.join(OUT, "06_ticks_ladder.csv"), index=False)
    L = []
    P = lambda s="": L.append(s)
    P("T5 on IC Markets raw ticks, 2026-08-03 .. 2026-10-21 (about 11 weeks). SE and t across weeks.")
    P()
    P("A/B. Reversal rate r(a) of the tick mid, and the same from MT5-style M1 bars built from these ticks.")
    P("lam = (tick truth - bar std) / (bar alt - bar std), all-hours r.  F = a(2r-1); k = commission + quoted spread at the steps.")
    for pair in PAIRS:
        P("== %s (commission %.2f pips)" % (pair, comm_pips(pair)))
        P("   a | steps | r tick grid (SE)     t  | r actual-node (core) | r core | bar std   alt    raw  |  lam  | core: tick / bar std / bar alt | spread@steps (core) | F gross | F net  | F core net")
        for r in A[A.pair == pair].itertuples():
            lam = (r.r_grid - r.r_bar_std) / (r.r_bar_alt - r.r_bar_std) if abs(r.r_bar_alt - r.r_bar_std) > 0.004 else np.nan
            P(" %3d | %6d | %.4f (%.4f) %+5.1f | %.4f (%.4f)      | %.4f | %.4f %.4f %.4f | %5.2f | %.4f / %.4f / %.4f       | %.2f (%.2f)        | %+6.2f  | %+6.2f | %+6.2f"
              % (r.a, r.steps, r.r_week_mean, r.r_se, r.t, r.r_actual, r.r_actual_core, r.r_core, r.r_bar_std, r.r_bar_alt, r.r_bar_raw, lam,
                 r.r_core, r.r_bar_std_core, r.r_bar_alt_core, r.spread_at_steps, r.spread_at_steps_core, r.F_gross, r.F_net, r.F_core_net))
        P()
    P("C. The ladder (cap 7, exit = add) on ticks and on bars built from the same ticks. Pips over the window unless USD.")
    P("   tick fill models: one = one resting add (the EA's rule; primary), cont = every traversed level fills at its limit,")
    P("   one_mkt = as one, and a touched limit deals at the touching tick's market price when that is better.")
    P("   bars: [std .. alt] bracket under cont and under one. gross = mid, no costs. real = real bid/ask, no commission.")
    for pair in PAIRS:
        P("== %s" % pair)
        P("  cell      add | closes | GROSS tick: one   cont | bars cont [std..alt]  bars one [std..alt] | gross %/rung one (t) | REAL tick: one  one_mkt   cont | bars cont [std..alt]  bars one [std..alt] | spread@fills | NET USD tick one (per week, t) | net one_mkt")
        q = B[B.pair == pair]
        for (kind, name, add), g in q.groupby(["kind", "name", "add"], sort=False):
            f = lambda path, mode, col="total_pips": g[(g.path == path) & (g["mode"] == mode)][col].iloc[0]
            P("  %-4s %-4s %4.0f | %6d | %+7.0f %+7.0f       | [%+6.0f .. %+6.0f]     [%+6.0f .. %+6.0f]   | %+6.1f (%+4.1f)        | %+7.0f %+7.0f %+7.0f      | [%+6.0f .. %+6.0f]     [%+6.0f .. %+6.0f]   | %.2f         | %+7.1f (%+6.2f, %+4.1f)        | %+7.1f"
              % (kind, name, add, f("tick_one", "spread", "closes"), f("tick_one", "gross"), f("tick", "gross"), f("std", "gross"), f("alt", "gross"),
                 f("std_one", "gross"), f("alt_one", "gross"), f("tick_one", "gross", "per_close_pct_rung"), f("tick_one", "gross", "t"),
                 f("tick_one", "spread"), f("tick_one_mkt", "spread"), f("tick", "spread"), f("std", "spread"), f("alt", "spread"),
                 f("std_one", "spread"), f("alt_one", "spread"), f("tick_one", "spread", "spread_at_fills"),
                 f("tick_one", "spread", "net_usd"), f("tick_one", "spread", "net_week"), f("tick_one", "spread", "net_t"), f("tick_one_mkt", "spread", "net_usd")))
        P()
    open(os.path.join(OUT, "06_ticks_tests.txt"), "w").write("\n".join(L) + "\n")
    print("\n".join(L))
