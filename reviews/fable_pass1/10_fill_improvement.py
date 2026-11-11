"""How much better than its limit price does a touched limit fill, if the deal is done at the market of the touching
tick (the replay's 'deal at the market' convention, zero latency)? IC ticks, Aug-Oct 2026, one resting add per side.
Measured directly as the mean of (limit - fill) over all entry and exit fills. Also the same P&L under limit fills.
Output: out/10_fill_improvement.txt / .csv"""
from ticks import *
from core import ladder
C0 = np.zeros((0, 7))
rows = []
for pair in PAIRS:
    t, bid, ask = load_ticks(pair)
    tod = ((t // 60000) % 1440).astype(np.int64); per = np.zeros(len(t), np.int64)
    hr = (t // 3600000) % 24
    cells = [(arm, w, float(a), s) for arm, (w, a, s) in zip(("OPT", "ALT"), GEO[pair])] + [("scan", a / 4.0, float(a), a / 4.0 + 1) for a in (5, 10, 20)]
    for name, w, a, s in cells:
        ol = ladder(bid, ask, tod, per, 1, w, a, a, s, 2.0, 7, True, 0, 1, False, C0, True)
        om = ladder(bid, ask, tod, per, 1, w, a, a, s, 2.0, 7, True, 0, 1, True, C0, True)
        rows.append(dict(pair=pair, cell=name, add=a, fills=int(om[11]), closes=int(om[2][0]), improvement_per_fill_pips=om[10] / max(om[11], 1),
                         pips_limit=ol[0][0] + ol[1][0], pips_market=om[0][0] + om[1][0],
                         net_usd_limit=(ol[0][0] + ol[1][0]) * USD[pair] - COMM * ol[2][0], net_usd_market=(om[0][0] + om[1][0]) * USD[pair] - COMM * om[2][0]))
    print(pair, "done", flush=True)
D = pd.DataFrame(rows); D.to_csv(os.path.join(OUT, "10_fill_improvement.csv"), index=False)
L = ["Price improvement of touched limits under 'deal at the market of the touching tick' (IC ticks, 2026-08-03 .. 2026-10-21).",
     "pair   cell  add | fills | mean improvement per fill (pips) | per close (x2) as % of commission | real bid/ask pips: limit fills -> market fills | net USD: limit -> market"]
for r in D.itertuples():
    L.append("%s %-4s %3.0f | %5d | %.3f                            | %3.0f%%                              | %+7.0f -> %+7.0f                             | %+7.1f -> %+7.1f"
             % (r.pair, r.cell, r.add, r.fills, r.improvement_per_fill_pips, 100 * 2 * r.improvement_per_fill_pips / comm_pips(r.pair),
                r.pips_limit, r.pips_market, r.net_usd_limit, r.net_usd_market))
live = D[D.cell.isin(["OPT", "ALT"])]
L.append("all 12 live arms, net USD over the window: limit fills %+.0f ; market fills %+.0f" % (live.net_usd_limit.sum(), live.net_usd_market.sum()))
open(os.path.join(OUT, "10_fill_improvement.txt"), "w").write("\n".join(L) + "\n")
print("\n".join(L))
