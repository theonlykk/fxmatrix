import sys, types
from common import *
from core import ladder
SIM = "/mnt/user-data/uploads/fxmatrix/research/opt_budget/sim.py"
src = open(SIM).read().replace("        price = self.ask if o.is_buy else self.bid\n", "        price = o.price_at(due)\n")
src = src.replace("            l.vl = level\n            self.rolls += 1\n", "            self.rlog.append((t, s, l.entry, level, l.vl is not None, opp.depth()))\n            l.vl = level\n            self.rolls += 1\n")
sim = types.ModuleType("sim_limit"); sys.modules["sim_limit"] = sim; exec(compile(src, SIM, "exec"), sim.__dict__)
sim.Instance.rlog = None
pair = "AUDCAD"; b = load_bars(pair); n = int(sys.argv[1]); bb = {k: v[:n] for k, v in b.items()}
tm, bid, ask = pseudo_ticks(bb, "std", True); bid = np.round(bid, 5); ask = np.round(ask, 5)
tk = list(zip(tm.tolist(), bid.tolist(), ask.tolist()))
w, a, s = GEO[pair][0]
it = sim.Instance(sim.Cfg(width=w, add=a, exit=a, cap=7, stranded=s, deadband=2.0), "one"); it.rlog = []
sim.run_instances(tk, [it])
clog = np.zeros((200000, 7))
o = ladder(bid, ask, ((tm // 60000) % 1440).astype(np.int64), np.zeros(len(tm), np.int64), 1, w, float(a), float(a), s, 2.0, 7, True, 0, 1, False, clog)
ts = lambda ms: pd.to_datetime(ms, unit="ms").strftime("%Y-%m-%d %H:%M:%S")
A = [(ts(t), sd, round(e, 5), round(lv, 5), rr) for (t, sd, e, lv, rr, od) in it.rlog]
B = [(ts(int(tm[int(r[0])])), "LS"[int(r[1]) - 10], round(float(r[2]), 5), round(float(r[3]), 5), bool(r[4])) for r in clog[:o[9]] if r[1] >= 10]
print("rolls sim", len(A), "mine", len(B), "| re-rolls sim", sum(x[4] for x in A), "mine", sum(x[4] for x in B))
import collections
da = collections.Counter(x[0][:10] for x in A); db = collections.Counter(x[0][:10] for x in B)
days = sorted(set(da) | set(db)); k = 0
for d in days:
    if da[d] != db[d]:
        print("day", d, "sim", da[d], "mine", db[d]); k += 1
        if k == 1:
            print("  sim :", [x for x in A if x[0][:10] == d][:12]); print("  mine:", [x for x in B if x[0][:10] == d][:12])
        if k > 12: break
print()
d0, d1 = "2023-03-06", "2023-03-08"
print("sim rolls:"); [print("  ", x) for x in A if d0 <= x[0][:10] <= d1]
print("mine rolls:"); [print("  ", x) for x in B if d0 <= x[0][:10] <= d1]
print("sim closes in window (close time, side, entry, exit, rolled, open):")
for c in it.closes:
    if d0 <= ts(c.close_ms)[:10] <= d1 or d0 <= ts(c.open_ms)[:10] <= d1:
        print("  ", ts(c.close_ms), c.side, c.entry, c.exit, c.rolled, ts(c.open_ms))
print("mine closes in window:")
for r in clog[:o[9]]:
    if r[1] < 10:
        ct, ot = ts(int(tm[int(r[0])])), ts(int(tm[int(r[6])]))
        if d0 <= ct[:10] <= d1 or d0 <= ot[:10] <= d1:
            print("  ", ct, "LS"[int(r[1])], round(float(r[2]), 5), round(float(r[3]), 5), bool(r[4]), ot)
