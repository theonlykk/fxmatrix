"""T2: variance ratios of the mid (clean path: blow-out bars frozen) from FTMO M1 bars.
Close mids are forward-filled onto a 1-minute grid inside each trading week; VR(q) = mean(r_q^2) / (q * mean(r_1^2))
with overlapping q-minute returns, computed per calendar month, then mean and SE across months. Also with a 5-minute
base (less quote noise). VR < 1 = mean reversion between the base and q. Output: out/03_variance_ratio.txt/.csv"""
from common import *
QS = [5, 15, 60, 240, 1440]
rows = []
for pair in PAIRS:
    b = load_bars(pair)
    tm, bid, ask = pseudo_ticks(b, "std", True)
    t = tm[3::4] // 60000                       # minute index of each bar close
    mid = 0.5 * (bid[3::4] + ask[3::4])
    week = (t + 3 * 1440) // (7 * 1440)         # weeks starting Monday 00:00 server
    acc = {}                                    # (month, base, q) -> [sum r_q^2, n_q, sum r_b^2, n_b]
    for w in np.unique(week):
        m = week == w
        tt, mm = t[m], mid[m]
        g = np.arange(tt[0], tt[-1] + 1)
        x = np.log(mm[np.searchsorted(tt, g, side="right") - 1])
        mon = month_id(g * 60000)
        for base in (1, 5):
            rb = x[base:] - x[:-base]
            for q in QS:
                if q <= base or len(x) <= q:
                    continue
                rq = x[q:] - x[:-q]
                for u in np.unique(mon):
                    a = acc.setdefault((u, base, q), [0.0, 0, 0.0, 0])
                    sq = mon[q:] == u; sb = mon[base:] == u
                    a[0] += (rq[sq] ** 2).sum(); a[1] += sq.sum(); a[2] += (rb[sb] ** 2).sum(); a[3] += sb.sum()
    for base in (1, 5):
        for q in QS:
            if q <= base:
                continue
            v = np.array([(a[0] / a[1]) / ((q / base) * a[2] / a[3]) for (u, b_, q_), a in acc.items() if b_ == base and q_ == q and a[1] > 100])
            mn, se, t_, n = tstat(v - 1.0)
            rows.append(dict(pair=pair, base_min=base, q_min=q, VR=1 + mn, SE=se, t_vs_1=t_, months=n))
    print(pair, "done", flush=True)
R = pd.DataFrame(rows); R.to_csv(os.path.join(OUT, "03_variance_ratio.csv"), index=False)
with open(os.path.join(OUT, "03_variance_ratio.txt"), "w") as fh:
    fh.write("Variance ratio of the mid, monthly estimates, mean (SE) [t vs 1]. 1.00 = random walk; < 1 = reverting.\n")
    for base in (1, 5):
        fh.write("\nbase %d min   " % base + "".join("%-24s" % ("q=%d min" % q) for q in QS if q > base) + "\n")
        for pair in PAIRS:
            fh.write("%-13s " % pair + "".join("%.3f (%.3f) [%+5.1f]    " % (r.VR, r.SE, r.t_vs_1) for r in R[(R.pair == pair) & (R.base_min == base)].itertuples()) + "\n")
print(open(os.path.join(OUT, "03_variance_ratio.txt")).read())
