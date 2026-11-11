"""Cross-check: the project's own sim.py (with run_bars.py's --fill limit patch) against core.ladder, on exactly
run_bars.py's pseudo-ticks (weekday bars, holiday-short weeks skipped, blow-outs left in) at the live parameters.
    python 07_crosscheck_sim.py <path to sim.py> <PAIR>
Output: out/07_crosscheck_<PAIR>.txt. core.ladder is run in both fill models: one = one resting add (the EA's and
sim.py's rule) and cont = every traversed level fills. sim.py also has order latency (287 ms; irrelevant on 15 s
ticks), one entry send per tick and the two-resting-exits queue, which core.ladder has not; core.ladder has the
C165 hold and the re-roll pause, which sim.py has not."""
import sys, types, time
from common import *
from core import ladder

SIM, pair = sys.argv[1], sys.argv[2]
MARKET_LINE = "        price = self.ask if o.is_buy else self.bid\n"
LIMIT_LINE = "        price = o.price_at(due)     # LIMIT FILL (bar runs): the limit price, never better\n"
src = open(SIM, encoding="utf-8").read()
assert src.count(MARKET_LINE) == 1
src = src.replace(MARKET_LINE, LIMIT_LINE)
sim = types.ModuleType("sim_limit"); sim.__dict__["__name__"] = "sim_limit"; sys.modules["sim_limit"] = sim
exec(compile(src, SIM, "exec"), sim.__dict__)

b = load_bars(pair)
t = b["t"]; dow = ((t // 86400) + 3) % 7
wk = (t // 86400 - dow)                      # Monday's day number = week key
keep = np.zeros(len(t), bool)
for u in np.unique(wk):
    m = wk == u
    if m.sum() >= 4000:
        keep |= m
keep &= dow < 5
bb = {k: v[keep] for k, v in b.items()}
tm, bid, ask = pseudo_ticks(bb, "std", False)
bid = np.round(bid, 5); ask = np.round(ask, 5)
tk = list(zip(tm.tolist(), bid.tolist(), ask.tolist()))
(wo, ao, so), (wa, aa, sa) = GEO[pair]
co = sim.Cfg(width=wo, add=ao, exit=ao, cap=7, stranded=so, deadband=2.0)
ca = sim.Cfg(width=wa, add=aa, exit=aa, cap=7, stranded=sa, deadband=2.0)
t0 = time.time()
r = sim.run_pair(tk, co, ca)
el = time.time() - t0
L = ["Cross-check %s: project sim.py (--fill limit) vs core.ladder on run_bars.py's ticks (%d ticks, sim.py took %.0f s)" % (pair, len(tk), el)]
tod = ((tm // 60000) % 1440).astype(np.int64); per = np.zeros(len(tm), np.int64)
for name, it, (w, a, s) in (("OPT", r.opt, GEO[pair][0]), ("ALT", r.alt, GEO[pair][1])):
    pips = lambda c: ((c.exit - c.entry) if c.side == "L" else (c.entry - c.exit)) / sim.PIP
    sc = sum(pips(c) for c in it.closes if not c.rolled); rc = sum(pips(c) for c in it.closes if c.rolled)
    op = it.open_pips(tk[-1][1], tk[-1][2])
    C0 = np.zeros((0, 7))
    o1 = ladder(bid, ask, tod, per, 1, w, float(a), float(a), s, 2.0, 7, True, 0, 1, False, C0, True)
    o2 = ladder(bid, ask, tod, per, 1, w, float(a), float(a), s, 2.0, 7, True, 0, 50, False, C0, False)
    L.append("%s add %d | sim.py:            closes=%d rolled=%d rolls=%d scalp=%+.0f rolled=%+.0f open=%+.0f total=%+.0f pips, net USD=%+.0f"
             % (name, a, len(it.closes), sum(1 for c in it.closes if c.rolled), it.rolls, sc, rc, op, sc + rc + op,
                (sc + rc + op) * USD[pair] - COMM * len(it.closes)))
    for lab, q in (("core.ladder one: ", o1), ("core.ladder cont:", o2)):
        L.append("          | %s closes=%d rolled=%d rolls=%d realised=%+.0f (rolled part %+.0f) open=%+.0f total=%+.0f pips, net USD=%+.0f"
                 % (lab, q[2][0], q[3][0], q[4][0], q[0][0], q[7][0], q[1][0], q[0][0] + q[1][0],
                    (q[0][0] + q[1][0]) * USD[pair] - COMM * q[2][0]))
open(os.path.join(OUT, "07_crosscheck_%s.txt" % pair), "w").write("\n".join(L) + "\n")
print("\n".join(L))
