import sys, types
from common import *
from core import ladder
SIM = "/mnt/user-data/uploads/fxmatrix/research/opt_budget/sim.py"
src = open(SIM).read().replace("        price = self.ask if o.is_buy else self.bid\n", "        price = o.price_at(due)\n")
sim = types.ModuleType("sim_limit"); sys.modules["sim_limit"] = sim; exec(compile(src, SIM, "exec"), sim.__dict__)
pair = "AUDCAD"; b = load_bars(pair)
n = 20000
bb = {k: v[:n] for k, v in b.items()}
tm, bid, ask = pseudo_ticks(bb, "std", True); bid = np.round(bid, 5); ask = np.round(ask, 5)
tk = list(zip(tm.tolist(), bid.tolist(), ask.tolist()))
w, a, s = GEO[pair][0]
it = sim.run_single(tk, sim.Cfg(width=w, add=a, exit=a, cap=7, stranded=s, deadband=2.0))
A = [(c.close_ms, c.side, c.entry, c.exit, c.rolled, c.open_ms) for c in it.closes]
clog = np.zeros((20000, 7))
o = ladder(bid, ask, ((tm // 60000) % 1440).astype(np.int64), np.zeros(len(tm), np.int64), 1, w, float(a), float(a), s, 2.0, 7, True, 0, 1, False, clog)
B = [(int(tm[int(r[0])]), "LS"[int(r[1])], round(float(r[2]), 5), round(float(r[3]), 5), bool(r[4]), int(tm[int(r[6])])) for r in clog[:o[9]]]
print("sim closes", len(A), "mine", len(B), "sim rolls", it.rolls, "mine", o[4][0])
pa = sum(((x[3]-x[2]) if x[1]=="L" else (x[2]-x[3]))/PIP for x in A); pb = sum(((x[3]-x[2]) if x[1]=="L" else (x[2]-x[3]))/PIP for x in B)
print("realised sim %.1f mine %.1f ; open sim %.1f mine %.1f" % (pa, pb, it.open_pips(tk[-1][1], tk[-1][2]), o[1][0]))
import pandas as pd
ts = lambda ms: pd.to_datetime(ms, unit="ms").strftime("%m-%d %H:%M")
key = lambda x: (x[5] // 60000, x[1])
A2 = sorted(A, key=lambda x: x[5]); B2 = sorted(B, key=lambda x: x[5])
print("first 45 by OPEN time:  sim (open, close, side, entry, exit, rolled, pips)   ||   mine")
pp = lambda x: ((x[3]-x[2]) if x[1]=="L" else (x[2]-x[3]))/PIP
for q in range(45):
    a_ = A2[q] if q < len(A2) else None; b_ = B2[q] if q < len(B2) else None
    f = lambda x: "%s %s %s %.5f %.5f %s %+6.1f" % (ts(x[5]), ts(x[0]), x[1], x[2], x[3], "R" if x[4] else "-", pp(x)) if x else ""
    print("  ", f(a_), "  ||  ", f(b_))
