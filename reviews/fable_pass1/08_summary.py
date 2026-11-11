"""Summary tables for the report, built only from the CSVs written by 02, 04 (cont and one), 06 and 10.
Output: out/08_summary.txt"""
from common import *
R = pd.read_csv(os.path.join(OUT, "02_reversal_bars.csv"))
H = pd.read_csv(os.path.join(OUT, "02_reversal_by_hour.csv"))
CC = {f: pd.read_csv(os.path.join(OUT, "04_ladder_cells_%s.csv" % f)) for f in ("cont", "one")}
MM = {f: pd.read_csv(os.path.join(OUT, "04_ladder_monthly_%s.csv" % f)) for f in ("cont", "one")}
A = pd.read_csv(os.path.join(OUT, "06_ticks_T1.csv"))
B = pd.read_csv(os.path.join(OUT, "06_ticks_ladder.csv"))
F = pd.read_csv(os.path.join(OUT, "10_fill_improvement.csv"))
L = []
P = lambda s="": L.append(s)
VAR = [("cont", "std"), ("cont", "alt"), ("one", "std"), ("one", "alt")]

def cell(fill, pair, path, kind, name, add, mode):
    C = CC[fill]
    return C[(C.pair == pair) & (C.path == path) & (C.kind == kind) & (C.name == name) & (C["add"] == add) & (C["mode"] == mode)].iloc[0]

def tk(pair, kind, name, add, path, mode):
    return B[(B.pair == pair) & (B.kind == kind) & (B.name == name) & (B["add"] == add) & (B.path == path) & (B["mode"] == mode)].iloc[0]

P("S1. T1 at the live rungs. r = share of rung-sized steps of the mid that reverse the previous step; 0.5 = random walk.")
P("    Bars: FTMO, 46 months, clean path, entries in server hours 2-21, limit convention (node on the grid line);")
P("    std = conservative intra-bar order, alt = optimistic; SE and t across months. F = add x (2r - 1), gross pips per")
P("    one-rung fade; k = commission + recorded spread. Ticks: IC, Aug-Oct 2026, same hours: grid = limit convention,")
P("    act = node at the actual price of the crossing tick (market convention).")
P("pair   arm add |  steps | r std  (SE)     t   | r alt   t   | F std   F alt |   k   | B4 verdict std / alt  | ticks: n   r grid  r act")
def v1(t, Fg, k, r):
    if r < 0.5 or abs(t) < 2: return "ABSENT"
    if t >= 3: return "PRESENT" if Fg - k > 0 else "WEAK"
    return "BORDERLINE"
for pair in PAIRS:
    for arm, (w, a, s) in zip(("OPT", "ALT"), GEO[pair]):
        s_ = R[(R.pair == pair) & (R.a == a) & (R.order == "std")].iloc[0]; al = R[(R.pair == pair) & (R.a == a) & (R.order == "alt")].iloc[0]
        ta = A[(A.pair == pair) & (A.a == (a if a in set(A.a) else min(set(A.a), key=lambda x: abs(x - a))))].iloc[0]
        P("%s %s %3d | %6d | %.4f (%.4f) %+5.1f | %.4f %+5.1f | %+5.2f  %+5.2f | %.2f  | %-10s / %-10s | a=%-2d %5d  %.3f   %.3f"
          % (pair, arm, a, s_.n_core, s_.r_core, s_.r_core_se, s_.r_core_t, al.r_core, al.r_core_t, s_.F_core_gross, al.F_core_gross,
             s_.k_core, v1(s_.r_core_t, s_.F_core_gross, s_.k_core, s_.r_core), v1(al.r_core_t, al.F_core_gross, al.k_core, al.r_core),
             ta.a, ta.n_core, ta.r_core, ta.r_actual_core))
P()
P("S2. T3 at the live parameters on FTMO bars (46 months, 0.01 lot), four bar variants:")
P("    fill model cont (every traversed level fills) or one (one resting add, EA-like but slow on bars) x intra-bar order std or alt.")
P("    All four fill at the limit price. Net = recorded bid/ask + 0.06 USD per close. yrs+ = calendar years of 4 with net > 0.")
P("    B4 verdict per variant: A = ABSENT (no gross evidence, or net < 0 with t <= -2), I- / I+ = INCONCLUSIVE leaning -, +, P = PRESENT.")
P("pair   arm add | gross pips/close, 4 variants     | cost/close FTMO (IC) | net USD/month (t), yrs+ : cont-std | cont-alt | one-std | one-alt                                   | verdicts")
def v3(gt, nm, nt, yp):
    if gt < 2: return "A"
    if nm > 0 and nt >= 2.5 and yp >= 3: return "P"
    if nm < 0 and nt <= -2: return "A"
    return "I+" if nm > 0 else "I-"
verd = {}
for pair in PAIRS:
    for arm, (w, a, s) in zip(("OPT", "ALT"), GEO[pair]):
        g = [cell(f, pair, p, "live", arm, float(a), "gross") for f, p in VAR]
        n = [cell(f, pair, p, "live", arm, float(a), "spread") for f, p in VAR]
        t_ = tk(pair, "live", arm, float(a), "tick_one", "spread")
        vs = [v3(gi.t_pips, ni.net_month_usd, ni.net_t, ni.years_pos_net) for gi, ni in zip(g, n)]
        verd[(pair, arm)] = vs
        P("%s %s %3d | %+5.2f  %+5.2f  %+5.2f  %+5.2f     | %4.2f (%4.2f)          | %s | %s"
          % (pair, arm, a, *[gi.total_pips / gi.closes for gi in g], comm_pips(pair) + n[0].spread_at_fills, comm_pips(pair) + t_.spread_at_fills,
             " | ".join("%+7.1f (%+5.1f) %d" % (ni.net_month_usd, ni.net_t, ni.years_pos_net) for ni in n), " ".join("%-2s" % v for v in vs)))
P()
for f, p in VAR:
    q = MM[f]; q = q[(q.path == p) & (q.kind == "live") & (q["mode"] == "spread")].groupby("month").net_usd.sum()
    mn, se, t, n_ = tstat(q.values); yr = q.groupby(q.index.str[:4]).sum()
    P("    fleet of 12 arms, %s-%s: %+7.1f USD/month (SE %.1f, t %+.1f); total %+.0f; by year: %s" % (f, p, mn, se, t, q.sum(),
      "  ".join("%s %+.0f" % (y, v) for y, v in yr.items())))
P()
P("S2b. The same with the replay's fill convention approximated: a touched limit deals at the market, which on IC ticks is")
P("     better than the limit by d pips per fill on average (10_fill_improvement.py). Bars cannot see this; first-order")
P("     adjustment: net + 2 x d x closes x USD-per-pip. Range over the four bar variants. This assumes the broker passes the")
P("     improvement on and that d on FTMO equals d on IC; neither is checked here.")
P("pair   arm add |  d (pips/fill) | net USD/month at limit fills: min .. max | with market-fill adjustment: min .. max")
tot_lo = tot_hi = alo = ahi = 0.0
for pair in PAIRS:
    for arm, (w, a, s) in zip(("OPT", "ALT"), GEO[pair]):
        d = F[(F.pair == pair) & (F.cell == arm)].improvement_per_fill_pips.iloc[0]
        n = [cell(f, pair, p, "live", arm, float(a), "spread") for f, p in VAR]
        lim = [ni.net_month_usd for ni in n]; adj = [ni.net_month_usd + 2 * d * ni.closes * USD[pair] / 46.0 for ni in n]
        tot_lo += min(lim); tot_hi += max(lim); alo += min(adj); ahi += max(adj)
        P("%s %s %3d |  %.2f          | %+7.1f .. %+7.1f                       | %+7.1f .. %+7.1f" % (pair, arm, a, d, min(lim), max(lim), min(adj), max(adj)))
P("    sum of the 12 arms (sum of per-arm minima .. sum of per-arm maxima): limit fills %+.0f .. %+.0f USD/month ; adjusted %+.0f .. %+.0f USD/month"
  % (tot_lo, tot_hi, alo, ahi))
P()
P("S3. Which bar variant is nearest the tick truth? IC ticks Aug-Oct 2026; truth = ladder on ticks, one resting add, real bid/ask,")
P("    limit fills. Bar variants are built from the same ticks (bid OHLC + minimum spread). Sum of pips over scan rungs 3..10.")
P("pair   | tick truth | bars cont-std  cont-alt | bars one-std  one-alt | nearest")
for pair in PAIRS:
    q = B[(B.pair == pair) & (B.kind == "scan") & (B["add"] <= 10) & (B["mode"] == "spread")]
    v = {p: q[q.path == p].total_pips.sum() for p in ("tick_one", "std", "alt", "std_one", "alt_one")}
    near = min(("std", "alt", "std_one", "alt_one"), key=lambda p: abs(v[p] - v["tick_one"]))
    P("%s | %+9.0f  | %+9.0f %+9.0f     | %+9.0f %+9.0f   | %s" % (pair, v["tick_one"], v["std"], v["alt"], v["std_one"], v["alt_one"],
      {"std": "cont-std", "alt": "cont-alt", "std_one": "one-std", "alt_one": "one-alt"}[near]))
P()
P("S4. Live arms on IC ticks, 2026-08-03 .. 2026-10-21 (12 calendar weeks touched), one resting add, real bid/ask,")
P("    0.06 USD per close. limit = touched limits fill at their price; market = at the touching tick's market when better.")
P("pair   arm add | closes | gross pips (%/rung, weekly t) | spread at fills | net USD, limit fills (per week, t) | net USD, market fills")
tl = tm_ = 0.0
for pair in PAIRS:
    for arm, (w, a, s) in zip(("OPT", "ALT"), GEO[pair]):
        g = tk(pair, "live", arm, float(a), "tick_one", "gross"); s_ = tk(pair, "live", arm, float(a), "tick_one", "spread")
        m_ = tk(pair, "live", arm, float(a), "tick_one_mkt", "spread")
        tl += s_.net_usd; tm_ += m_.net_usd
        P("%s %s %3d | %6d | %+7.0f (%+6.1f, %+4.1f)       | %.2f            | %+7.1f (%+6.2f, %+4.1f)          | %+7.1f (%+6.2f, %+4.1f)" % (pair, arm, a, s_.closes,
          g.total_pips, g.per_close_pct_rung, g.t, s_.spread_at_fills, s_.net_usd, s_.net_week, s_.net_t, m_.net_usd, m_.net_week, m_.net_t))
P("    all 12 arms: limit fills %+.0f USD ; market fills %+.0f USD" % (tl, tm_))
P()
P("S5. What a plain bar replay sees at the rollover (bars built from the IC ticks, so the truth is known). Ladder, cap 7,")
P("    width add/4, every traversed level fills, Aug-Oct 2026. raw = bid OHLC + minimum spread, blow-out bars left in")
P("    (run_bars.py's construction); std = the same with blow-out bars frozen. Pips over the window.")
P("pair   add | GROSS (mid): tick truth    raw    std | REAL BID/ASK: tick truth    raw    std | raw - truth, USD per year at 0.01 lot")
for pair in PAIRS:
    for a in (5.0, 10.0):
        f = lambda path, mode: tk(pair, "scan", "cap7", a, path, mode).total_pips
        P("%s %3.0f |              %+7.0f %+7.0f %+7.0f |               %+7.0f %+7.0f %+7.0f | %+6.0f" % (pair, a, f("tick", "gross"), f("raw", "gross"),
          f("std", "gross"), f("tick", "spread"), f("raw", "spread"), f("std", "spread"),
          (f("raw", "spread") - f("tick", "spread")) * USD[pair] * 365.0 / 79.0))
P()
P("S6. Reversal rate by session (FTMO bars, clean path, std order; server hours; server 00:00 = New York 17:00).")
P("    binomial SE in brackets (a lower bound on the true uncertainty). Fnet = a(2r-1) - commission - recorded spread.")
for pair in PAIRS:
    for a in (5, 10, 20):
        h = H[(H.pair == pair) & (H.a == a)]
        out = []
        for lab, lo, hi in (("1-8 Asia", 1, 8), ("9-14 London", 9, 14), ("15-21 NY", 15, 21), ("22-23 late", 22, 23)):
            q = h[(h.hour >= lo) & (h.hour <= hi)]
            n = q.n.sum()
            if n < 30:
                out.append("%s: n<30" % lab); continue
            r = (q.r * q.n).sum() / n; sp = (q.spread * q.n).sum() / n
            out.append("%s: r=%.3f (%.3f) n=%d Fnet=%+.2f" % (lab, r, 0.5 / np.sqrt(n), n, a * (2 * r - 1) - comm_pips(pair) - sp))
        P("  %s a=%2d | " % (pair, a) + " | ".join(out))
P()
P("S7. The best cells of the scans (FTMO bars, std path, recorded bid/ask + commission, limit fills), ranked by net t.")
P("    6 pairs x 20 rungs x 6 designs = 720 cells per fill model; the largest t expected by chance alone is about 3.")
for fill in ("cont", "one"):
    C = CC[fill]
    q = C[(C.path == "std") & (C["mode"] == "spread") & (C.kind != "live")].copy()
    for lab, sub in (("rungs 3..30", q[q["add"] <= 30]), ("rungs 40..100 (context only)", q[q["add"] > 30])):
        P("  fill model %s, %s" % (fill, lab))
        for r in sub.sort_values("net_t", ascending=False).head(8).itertuples():
            P("    %s %-8s add %3.0f : net %+7.2f USD/month, t %+4.1f, years+ %d/4, closes/day %.1f, maxDD %.0f pips"
              % (r.pair, r.name, r.add, r.net_month_usd, r.net_t, r.years_pos_net, r.closes_per_day, r.maxdd_pips))
        P("    cells with net t >= 3.5: %d of %d ; net t >= 2: %d ; net t <= -2: %d ; by pair, cells with net t >= 2: %s"
          % ((sub.net_t >= 3.5).sum(), len(sub), (sub.net_t >= 2).sum(), (sub.net_t <= -2).sum(),
             " ".join("%s %d" % (p, ((sub.pair == p) & (sub.net_t >= 2)).sum()) for p in PAIRS)))
P()
P("S8. By calendar year, the three arms that lean positive: NET USD at 0.01 lot, cont-std / cont-alt / one-std / one-alt.")
for pair, arm, a in (("EURGBP", "ALT", 23), ("AUDCAD", "OPT", 18), ("AUDCAD", "ALT", 26)):
    out = []
    for y in ("2023", "2024", "2025", "2026"):
        v = []
        for f, p in VAR:
            M = MM[f]
            v.append(M[(M.pair == pair) & (M.path == p) & (M.kind == "live") & (M.name == arm) & (M["mode"] == "spread") & (M.month.str[:4] == y)].net_usd.sum())
        out.append("%s %+5.0f/%+5.0f/%+5.0f/%+5.0f" % (y, *v))
    P("  %s %s %d : " % (pair, arm, a) + "   ".join(out))
P()
P("S9. Scale scan, cap 7, exit = add, width = add/4: net USD/month (t) by rung, min .. max over the four bar variants, limit fills.")
for pair in PAIRS:
    P("  %s" % pair)
    for a in SCALES:
        n = [cell(f, pair, p, "scan", "cap7", float(a), "spread") for f, p in VAR]
        g = [cell(f, pair, p, "scan", "cap7", float(a), "gross") for f, p in VAR]
        lo = min(n, key=lambda x: x.net_month_usd); hi = max(n, key=lambda x: x.net_month_usd)
        P("    add %3d : closes/day %6.1f | gross %%/rung %+6.1f .. %+6.1f | net %+8.2f (t %+5.1f) .. %+8.2f (t %+5.1f) | years+ %d .. %d"
          % (a, n[0].closes_per_day, min(x.per_close_pct_rung for x in g), max(x.per_close_pct_rung for x in g),
             lo.net_month_usd, lo.net_t, hi.net_month_usd, hi.net_t, min(x.years_pos_net for x in n), max(x.years_pos_net for x in n)))
open(os.path.join(OUT, "08_summary.txt"), "w").write("\n".join(L) + "\n")
print("\n".join(L))
