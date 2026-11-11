"""Compact tables quoted in the report. Output: out/12_report_tables.txt
(a) T1 by rung, core hours, clean path: r std (t) / r alt.  (d) compact scale scan.  (e) commission.  (f) r by run length.  (b) what the rollover does to a raw bid-only mid:
reversal rate and recorded spread by server hour on run_bars.py's raw pseudo-ticks, rung 5.  (c) the US-data hour."""
from common import *
from core import steps_grid
R = pd.read_csv(os.path.join(OUT, "02_reversal_bars.csv")); H = pd.read_csv(os.path.join(OUT, "02_reversal_by_hour.csv"))
L = []
P = lambda s="": L.append(s)
RUNGS = [3, 5, 7, 10, 14, 20, 30, 40, 60]
P("(a) T1, FTMO bars 2023-01 .. 2026-10, clean path, entries in server hours 2-21: r std (monthly t) / r alt")
P("pair   | " + " | ".join("a=%-17d" % a for a in RUNGS))
for pair in PAIRS:
    out = []
    for a in RUNGS:
        s_ = R[(R.pair == pair) & (R.a == a) & (R.order == "std")].iloc[0]; al = R[(R.pair == pair) & (R.a == a) & (R.order == "alt")].iloc[0]
        out.append("%.3f (%+5.1f) / %.3f" % (s_.r_core, s_.r_core_t, al.r_core))
    P("%s | " % pair + " | ".join(out))
P()
P("(a2) the same as gross fade F = a(2r-1) in pips, std / alt, against k = commission + recorded spread (pips)")
P("pair   | " + " | ".join("a=%-13d" % a for a in RUNGS) + " | k")
for pair in PAIRS:
    out = []
    for a in RUNGS:
        s_ = R[(R.pair == pair) & (R.a == a) & (R.order == "std")].iloc[0]; al = R[(R.pair == pair) & (R.a == a) & (R.order == "alt")].iloc[0]
        out.append("%+6.2f / %+6.2f" % (s_.F_core_gross, al.F_core_gross))
    P("%s | " % pair + " | ".join(out) + " | %.2f" % R[(R.pair == pair) & (R.a == 10) & (R.order == "std")].k_core.iloc[0])
P()
P("(b) raw bid-only path (blow-outs left in), rung 5: reversal rate r and mean recorded spread (pips) at the steps, by server hour")
for pair in PAIRS:
    b = load_bars(pair); tm, bid, ask = pseudo_ticks(b, "std", False)
    mid = 0.5 * (bid + ask); sp = (ask - bid) / PIP; hr = (tm // 3600000) % 24
    idx, d = steps_grid(mid, 5 * PIP); rev = (d[1:] != d[:-1]); e = idx[:-1]
    P("%s: " % pair + " ".join("%d:%.2f/%.1f" % (h, rev[hr[e] == h].mean(), sp[e][hr[e] == h].mean()) for h in (22, 23, 0, 1, 2, 3)) +
      " | hours 2-21: %.3f | all hours: %.3f | share of steps in hours 23,0,1: %.1f%%" % (rev[(hr[e] >= 2) & (hr[e] <= 21)].mean(), rev.mean(),
      100 * np.isin(hr[e], [23, 0, 1]).mean()))
P()
P("(c) server hour 15 (US data, 08:30 New York in summer and winter alike), clean path, std order: r (bootstrap SE), n")
for pair in PAIRS:
    out = []
    for a in (5, 7, 10):
        q = H[(H.pair == pair) & (H.a == a) & (H.hour == 15)]
        if len(q):
            out.append("a=%d: %.3f (%.3f) n=%d" % (a, q.r.iloc[0], q.r_se_boot.iloc[0], q.n.iloc[0]))
    P("%s: " % pair + " | ".join(out))
CC = {f: pd.read_csv(os.path.join(OUT, "04_ladder_cells_%s.csv" % f)) for f in ("cont", "one")}
VAR = [("cont", "std"), ("cont", "alt"), ("one", "std"), ("one", "alt")]
def cell(fill, pair, path, kind, name, add, mode):
    C = CC[fill]
    return C[(C.pair == pair) & (C.path == path) & (C.kind == kind) & (C.name == name) & (C["add"] == add) & (C["mode"] == mode)].iloc[0]
P()
P("(d) scale scan, cap 7, exit = add, width = add/4, FTMO bars, recorded bid/ask + commission, limit fills:")
P("    net USD/month at 0.01 lot, cont-std (t)  ..  one-alt (t)   [the most conservative and the most optimistic bar variant]")
SC = [5, 7, 10, 14, 17, 20, 23, 26, 30]
P("pair   | " + " | ".join("add %-21d" % a for a in SC))
for pair in PAIRS:
    out = []
    for a in SC:
        lo = cell("cont", pair, "std", "scan", "cap7", float(a), "spread"); hi = cell("one", pair, "alt", "scan", "cap7", float(a), "spread")
        out.append("%+6.0f (%+5.1f) .. %+5.0f (%+4.1f)" % (lo.net_month_usd, lo.net_t, hi.net_month_usd, hi.net_t))
    P("%s | " % pair + " | ".join(out))
P()
P("(d2) the same with exit = 2 x add")
P("pair   | " + " | ".join("add %-21d" % a for a in SC))
for pair in PAIRS:
    out = []
    for a in SC:
        lo = cell("cont", pair, "std", "design", "exit2a", float(a), "spread"); hi = cell("one", pair, "std", "design", "exit2a", float(a), "spread")
        out.append("%+6.0f (%+5.1f) .. %+5.0f (%+4.1f)" % (lo.net_month_usd, lo.net_t, hi.net_month_usd, hi.net_t))
    P("%s | " % pair + " | ".join(out))
P("    (here the two columns are cont-std and one-std; the design cells were run on the std path only)")
P()
P("(e) closes and commission of the 12 live arms over 46 months at 0.01 lot, per bar variant")
for f, p in VAR:
    cl = sum(cell(f, pair, p, "live", arm, float(g[1]), "spread").closes for pair in PAIRS for arm, g in zip(("OPT", "ALT"), GEO[pair]))
    P("    %s-%s: %d closes, commission %.0f USD = %.0f USD/month" % (f, p, cl, COMM * cl, COMM * cl / 46.0))
P()
P("(f) reversal rate by length of the run so far (number of consecutive same-direction rungs), all hours, clean path: std / alt (n std)")
LR = pd.read_csv(os.path.join(OUT, "02_reversal_by_runlen.csv"))
for pair, a in (("EURUSD", 7), ("GBPUSD", 9), ("EURGBP", 5), ("EURGBP", 23), ("AUDCAD", 18), ("AUDCAD", 26), ("AUDCHF", 14), ("CADCHF", 10)):
    out = []
    for rl in ("1", "2", "3", "4", "5", "6", "7", "8+"):
        s_ = LR[(LR.pair == pair) & (LR.a == a) & (LR.order == "std") & (LR.runlen.astype(str) == rl)]
        al = LR[(LR.pair == pair) & (LR.a == a) & (LR.order == "alt") & (LR.runlen.astype(str) == rl)]
        if len(s_) and len(al):
            out.append("%s: %.3f/%.3f (%d)" % (rl, s_.r.iloc[0], al.r.iloc[0], s_.n.iloc[0]))
    P("  %s add %2d | " % (pair, a) + " | ".join(out))
open(os.path.join(OUT, "12_report_tables.txt"), "w").write("\n".join(L) + "\n")
print("\n".join(L))
