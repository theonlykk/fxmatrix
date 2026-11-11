"""Tables from out/04_ladder_cells_<fill>.csv -> out/04_ladder_tables_<fill>.txt   (python 04b_ladder_tables.py cont|one)"""
from common import *
import sys
FILL = sys.argv[1] if len(sys.argv) > 1 else "cont"
C = pd.read_csv(os.path.join(OUT, "04_ladder_cells_%s.csv" % FILL))
M = pd.read_csv(os.path.join(OUT, "04_ladder_monthly_%s.csv" % FILL))
L = []
P = lambda s="": L.append(s)
def cell(pair, path, kind, name, add, mode):
    q = C[(C.pair == pair) & (C.path == path) & (C.kind == kind) & (C.name == name) & (C["add"] == add) & (C["mode"] == mode)]
    return q.iloc[0] if len(q) else None
P("T3 LIVE ARMS on FTMO M1 bars, 2023-01 .. 2026-10 (46 months), 0.01 lot per layer. Fill model: %s (see 04_ladder_bars.py)." % FILL)
P("gross = mid, no costs. net = recorded bid/ask (minimum-of-minute spread) and 0.06 USD per close.")
P("Paths: std = clean, conservative intra-bar order; alt = clean, optimistic order; raw = run_bars.py ticks (blow-outs in).")
P("%/rung = P&L per close as % of the rung. t = mean monthly change / SE across months. y+ = calendar years (of 4) with net > 0.")
P()
P("pair   arm add | path | closes  /day rolled |  GROSS pips  %/rung    t  |  spread-mode pips  %/rung | comm USD |  NET USD  per month (SE)     t   y+ | maxDD pips")
for pair in PAIRS:
    for arm, (w, a, s) in zip(("OPT", "ALT"), GEO[pair]):
        for path in ("std", "alt", "raw"):
            g = cell(pair, path, "live", arm, float(a), "gross"); sp = cell(pair, path, "live", arm, float(a), "spread")
            P("%s %s %3d | %s  | %6d %5.1f %6d | %+9.0f %+7.1f %+6.1f | %+9.0f        %+7.1f | %8.0f | %+8.0f  %+7.1f (%5.1f) %+6.1f  %d  | %7.0f"
              % (pair, arm, a, path, sp.closes, sp.closes_per_day, sp.rolled_closes, g.total_pips, g.per_close_pct_rung, g.t_pips,
                 sp.total_pips, sp.per_close_pct_rung, sp.comm_usd, sp.net_usd, sp.net_month_usd, sp.net_month_se, sp.net_t,
                 sp.years_pos_net, sp.maxdd_pips))
    P()
P()
P("T3 SCALE SCAN, cap 7, exit = add, width = add/4 (std path / alt path). GROSS %/rung (t)  and  NET USD per month (t).")
for pair in PAIRS:
    P("== %s" % pair)
    P("  add | closes/day | gross %%/rung std (t)   alt (t)     | cost %%/rung (spread+comm) | net USD/month std (t)    alt (t)    | years+ std/alt")
    for a in SCALES:
        gs = cell(pair, "std", "scan", "cap7", float(a), "gross"); ga = cell(pair, "alt", "scan", "cap7", float(a), "gross")
        ss = cell(pair, "std", "scan", "cap7", float(a), "spread"); sa = cell(pair, "alt", "scan", "cap7", float(a), "spread")
        cost = 100 * ((gs.total_pips - ss.total_pips) / max(ss.closes, 1) + comm_pips(pair)) / a
        P("  %3d | %8.1f   | %+7.1f (%+5.1f)  %+7.1f (%+5.1f) | %6.1f                    | %+8.2f (%+5.1f)  %+8.2f (%+5.1f) | %d / %d"
          % (a, ss.closes_per_day, gs.per_close_pct_rung, gs.t_pips, ga.per_close_pct_rung, ga.t_pips, cost,
             ss.net_month_usd, ss.net_t, sa.net_month_usd, sa.net_t, ss.years_pos_net, sa.years_pos_net))
    P()
P()
P("T3 DESIGN SCAN (std path): NET t-statistic of monthly USD by design and add. Cells with |t| >= 3.5 would be candidates.")
names = ["cap1", "cap3", "cap7", "cap15", "exit0.5a", "exit2a"]
for pair in PAIRS:
    P("== %s   net t (net USD/month)" % pair)
    P("  add | " + " | ".join("%-16s" % n for n in names))
    for a in SCALES:
        cells_ = []
        for n in names:
            c = cell(pair, "std", "scan" if n == "cap7" else "design", n, float(a), "spread")
            cells_.append("%+5.1f (%+8.2f)" % (c.net_t, c.net_month_usd))
        P("  %3d | " % a + " | ".join("%-16s" % x for x in cells_))
    P()
P("T3 DESIGN SCAN (std path): GROSS t-statistic of monthly pips (no costs at all).")
for pair in PAIRS:
    P("== %s   gross t (gross %% of rung per close)" % pair)
    P("  add | " + " | ".join("%-16s" % n for n in names))
    for a in SCALES:
        cells_ = []
        for n in names:
            c = cell(pair, "std", "scan" if n == "cap7" else "design", n, float(a), "gross")
            cells_.append("%+5.1f (%+6.1f%%)" % (c.t_pips, c.per_close_pct_rung))
        P("  %3d | " % a + " | ".join("%-16s" % x for x in cells_))
    P()
# live arms by calendar year
P("T3 LIVE ARMS by calendar year, std path (alt path in brackets): NET USD at 0.01 lot")
M["year"] = M.month.str[:4]
for pair in PAIRS:
    for arm, (w, a, s) in zip(("OPT", "ALT"), GEO[pair]):
        out = []
        for y in ("2023", "2024", "2025", "2026"):
            v = [M[(M.pair == pair) & (M.path == p) & (M.kind == "live") & (M.name == arm) & (M["mode"] == "spread") & (M.year == y)].net_usd.sum() for p in ("std", "alt")]
            out.append("%s %+7.0f [%+7.0f]" % (y, v[0], v[1]))
        P("%s %s %3d : " % (pair, arm, a) + "   ".join(out))
open(os.path.join(OUT, "04_ladder_tables_%s.txt" % FILL), "w").write("\n".join(L) + "\n")
print("written", FILL)
