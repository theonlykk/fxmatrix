"""T1 + T4 on the FTMO M1 bars, all six pairs, whole period.
Grid (renko) steps of the MID at rung a; r = share of steps that reverse the previous step; one-rung fade
F = a(2r-1) pips gross; k = commission + mean recorded spread at the steps; uncertainty by calendar month.
Both intra-bar orders (std = run_bars.py's, alt = high/low swapped): std is exact when the bar range < a and
conservative (r biased down) otherwise; alt is optimistic. Truth lies between (01_null_calibration.py).
Outputs: out/02_reversal_bars.csv (one row per pair/order/a), out/02_reversal_by_hour.csv,
         out/02_reversal_by_runlen.csv, out/02_reversal_by_year.csv, out/02_reversal_bars.txt (tables)."""
from common import *
from core import steps_grid

rows, hrows, lrows, yrows = [], [], [], []
rng = np.random.default_rng(11)
for pair in PAIRS:
    b = load_bars(pair)
    for order, clean in (("std", True), ("alt", True), ("raw", False)):
        tm, bid, ask = pseudo_ticks(b, "std" if order == "raw" else order, clean)
        mid = 0.5 * (bid + ask)
        sp = (ask - bid) / PIP
        mon = month_id(tm)
        hour = ((tm // 3600000) % 24).astype(np.int64)
        year = (mon // 12).astype(np.int64)
        brange = np.repeat(((b["h"] - b["l"]) / PIP), 4)
        for a in SCALES:
            idx, d = steps_grid(mid, a * PIP)
            if len(d) < 50:
                continue
            rev = (d[1:] != d[:-1]).astype(np.float64)
            e = idx[:-1]                                    # entry sample of each fade (the previous step)
            x = idx[1:]
            m_e, h_e, y_e = mon[e], hour[e], year[e]
            spr = 0.5 * (sp[e] + sp[x])
            # run length at entry
            rl = np.ones(len(d), np.int64)
            for i in range(1, len(d)):
                rl[i] = rl[i - 1] + 1 if d[i] == d[i - 1] else 1
            rl_e = rl[:-1]
            # monthly
            um = np.unique(m_e)
            mr = np.array([rev[m_e == u].mean() for u in um if (m_e == u).sum() >= 5])
            mn, se, t, nm = tstat(mr - 0.5)
            r_pool = rev.mean()
            k = comm_pips(pair) + spr.mean()
            F = a * (2 * r_pool - 1)
            # monthly net fade per trade, pips (month means), for a t on the net
            mnet = np.array([(a * (2 * rev[m_e == u] - 1) - comm_pips(pair) - spr[m_e == u]).mean() for u in um if (m_e == u).sum() >= 5])
            nmn, nse, nt, _ = tstat(mnet)
            amb = (brange[x] >= a).mean()
            core = (h_e >= 2) & (h_e <= 21)
            r_core = rev[core].mean()
            mrc = np.array([rev[core & (m_e == u)].mean() for u in um if (core & (m_e == u)).sum() >= 5])
            cmn, cse, ct, _ = tstat(mrc - 0.5)
            k_core = comm_pips(pair) + spr[core].mean()
            rows.append(dict(pair=pair, order=order, a=a, steps=len(d), months=nm, r_pool=r_pool, r_month_mean=0.5 + mn,
                             r_se=se, t=t, F_gross_pips=F, spread_at_steps=spr.mean(), comm_pips=comm_pips(pair), k_pips=k,
                             F_net_pips=F - k, F_net_month_mean=nmn, F_net_se=nse, F_net_t=nt,
                             share_steps_in_bars_range_ge_a=amb, r_core=r_core, r_core_se=cse, r_core_t=ct, n_core=int(core.sum()), k_core=k_core, F_core_gross=a * (2 * r_core - 1), F_core_net=a * (2 * r_core - 1) - k_core, steps_per_day=len(d) / 989.0))
            for L in range(1, 9):
                msk = (rl_e == L) if L < 8 else (rl_e >= 8)
                if msk.sum() >= 30:
                    lrows.append(dict(pair=pair, order=order, a=a, runlen=("%d" % L if L < 8 else "8+"), n=int(msk.sum()),
                                      r=rev[msk].mean(), se_binom=np.sqrt(0.25 / msk.sum())))
            for y in np.unique(y_e):
                msk = y_e == y
                yrows.append(dict(pair=pair, order=order, a=a, year=int(y), n=int(msk.sum()), r=rev[msk].mean(),
                                  se_binom=np.sqrt(0.25 / max(msk.sum(), 1)), spread=spr[msk].mean(),
                                  F_net=a * (2 * rev[msk].mean() - 1) - comm_pips(pair) - spr[msk].mean()))
            if order == "std" and a in (5, 7, 10, 14, 20, 30):
                # by hour: pooled with month-block bootstrap
                cnt = np.zeros((len(um), 24)); rv = np.zeros((len(um), 24)); sps = np.zeros((len(um), 24))
                mi = np.searchsorted(um, m_e)
                np.add.at(cnt, (mi, h_e), 1.0); np.add.at(rv, (mi, h_e), rev); np.add.at(sps, (mi, h_e), spr)
                bs = rng.integers(0, len(um), (1000, len(um)))
                for h in range(24):
                    n = cnt[:, h].sum()
                    if n < 30:
                        continue
                    r = rv[:, h].sum() / n
                    rb = rv[bs, h].sum(1) / np.maximum(cnt[bs, h].sum(1), 1)
                    s = sps[:, h].sum() / n
                    hrows.append(dict(pair=pair, a=a, hour=h, n=int(n), r=r, r_se_boot=rb.std(), spread=s,
                                      F_gross=a * (2 * r - 1), F_net=a * (2 * r - 1) - comm_pips(pair) - s))
        print(pair, order, "done", flush=True)
R = pd.DataFrame(rows); H = pd.DataFrame(hrows); L = pd.DataFrame(lrows); Y = pd.DataFrame(yrows)
R.to_csv(os.path.join(OUT, "02_reversal_bars.csv"), index=False)
H.to_csv(os.path.join(OUT, "02_reversal_by_hour.csv"), index=False)
L.to_csv(os.path.join(OUT, "02_reversal_by_runlen.csv"), index=False)
Y.to_csv(os.path.join(OUT, "02_reversal_by_year.csv"), index=False)
with open(os.path.join(OUT, "02_reversal_bars.txt"), "w") as fh:
    fh.write("T1 on FTMO M1 bars, 2023-01-02 .. 2026-10-23. r = share of grid steps of the mid that reverse the previous step\n"
             "(random walk = 0.5). std/alt = the two intra-bar orders on the clean path (blow-out bars frozen): truth lies between.\n"
             "raw = run_bars.py's ticks as they are (std order, blow-outs left in). core = entries in server hours 2..21 only.\n"
             "F = a(2r-1) = gross pips per one-rung fade; k = commission + mean recorded (minimum-of-minute) spread at the steps.\n"
             "SE and t are across calendar months.\n\n")
    for pair in PAIRS:
        fh.write("== %s  (commission %.2f pips per close)\n" % (pair, comm_pips(pair)))
        fh.write("   a | steps  /day | r std   (SE)     t   | r alt  | r raw  | core: r std (SE)    t    r alt | k core | F core gross std/alt | F core net std / alt | amb%\n")
        for a in SCALES:
            g = lambda o: R[(R.pair == pair) & (R.a == a) & (R.order == o)]
            if len(g("std")) == 0:
                continue
            s_, al, rw = g("std").iloc[0], g("alt").iloc[0], g("raw").iloc[0]
            fh.write(" %3d | %6d %5.1f | %.4f (%.4f) %+5.1f | %.4f | %.4f | %.4f (%.4f) %+5.1f  %.4f | %5.2f  | %+6.2f / %+6.2f      | %+6.2f / %+6.2f      | %4.1f\n"
                     % (a, s_.steps, s_.steps_per_day, s_.r_month_mean, s_.r_se, s_.t, al.r_month_mean, rw.r_month_mean,
                        s_.r_core, s_.r_core_se, s_.r_core_t, al.r_core, s_.k_core, s_.F_core_gross, al.F_core_gross,
                        s_.F_core_net, al.F_core_net, 100 * s_.share_steps_in_bars_range_ge_a))
        fh.write("\n")
print(open(os.path.join(OUT, "02_reversal_bars.txt")).read())
