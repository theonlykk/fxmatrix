"""Grid-phase robustness of T3 at the live parameters. The ladder's levels depend on where the first order happened
to be placed; two runs that differ by one fill drift apart and end with different totals. To see how much of a
4-year total is this 'phase noise', each live arm is run from 8 different start times (0, 7, 14, ... 49 hours into
the data) on the std and alt clean paths, gross and with recorded bid/ask + commission.
Output: out/09_phase_ensemble.csv, out/09_phase_ensemble.txt"""
from common import *
from core import ladder
import multiprocessing as mp

OFFS = [0, 7, 14, 21, 28, 35, 42, 49]          # hours


def do_pair(pair):
    b = load_bars(pair)
    rows = []
    for path in ("std", "alt"):
        tm, bid, ask = pseudo_ticks(b, path, True)
        for arm, (w, a, s) in zip(("OPT", "ALT"), GEO[pair]):
            for off in OFFS:
                k = int(np.searchsorted(tm, tm[0] + off * 3600000))
                t_, b_, a_ = tm[k:], bid[k:], ask[k:]
                tod = ((t_ // 60000) % 1440).astype(np.int64)
                um, per = np.unique(month_id(t_), return_inverse=True); per = per.astype(np.int64)
                m = 0.5 * (b_ + a_)
                g = ladder(m, m, tod, per, len(um), w, float(a), float(a), s, 2.0, 7, True, 0, 50)
                r = ladder(b_, a_, tod, per, len(um), w, float(a), float(a), s, 2.0, 7, True, 0, 50)
                rows.append(dict(pair=pair, arm=arm, add=a, path=path, offset_h=off, gross_pips=g[0][-1] + g[1][-1], closes=int(r[2][-1]),
                                 rolled=int(r[3][-1]), net_usd=(r[0][-1] + r[1][-1]) * USD[pair] - COMM * r[2][-1]))
    return rows


if __name__ == "__main__":
    with mp.Pool(2) as pool:
        out = pool.map(do_pair, PAIRS)
    D = pd.DataFrame([r for o in out for r in o]); D.to_csv(os.path.join(OUT, "09_phase_ensemble.csv"), index=False)
    L = ["Grid-phase ensemble: 8 start offsets per arm. 46 months, 0.01 lot. mean [min .. max] (sd across the 8 runs).",
         "pair   arm add | path | GROSS pips                                  | NET USD (recorded bid/ask + commission)      | net USD/month, mean of 8 | runs with net > 0"]
    tot = {"std": np.zeros(len(OFFS)), "alt": np.zeros(len(OFFS))}
    for pair in PAIRS:
        for arm in ("OPT", "ALT"):
            for path in ("std", "alt"):
                q = D[(D.pair == pair) & (D.arm == arm) & (D.path == path)]
                tot[path] += q.sort_values("offset_h").net_usd.values
                L.append("%s %s %3d | %s  | %+8.0f [%+8.0f .. %+8.0f] (sd %6.0f) | %+7.0f [%+7.0f .. %+7.0f] (sd %5.0f)       | %+7.1f                  | %d / 8"
                         % (pair, arm, q["add"].iloc[0], path, q.gross_pips.mean(), q.gross_pips.min(), q.gross_pips.max(), q.gross_pips.std(ddof=1),
                            q.net_usd.mean(), q.net_usd.min(), q.net_usd.max(), q.net_usd.std(ddof=1), q.net_usd.mean() / 46.0, (q.net_usd > 0).sum()))
    for path in ("std", "alt"):
        L.append("all 12 arms, %s: net USD mean %+.0f [%+.0f .. %+.0f]" % (path, tot[path].mean(), tot[path].min(), tot[path].max()))
    open(os.path.join(OUT, "09_phase_ensemble.txt"), "w").write("\n".join(L) + "\n")
    print("\n".join(L))
