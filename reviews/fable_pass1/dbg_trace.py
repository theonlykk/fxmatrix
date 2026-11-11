import sys, types
from common import *
SIM = "/mnt/user-data/uploads/fxmatrix/research/opt_budget/sim.py"
src = open(SIM).read().replace("        price = self.ask if o.is_buy else self.bid\n", "        price = o.price_at(due)\n")
sim = types.ModuleType("sim_limit"); sys.modules["sim_limit"] = sim; exec(compile(src, SIM, "exec"), sim.__dict__)
ts = lambda ms: pd.to_datetime(ms, unit="ms").strftime("%m-%d %H:%M:%S")
log = []
op, om, od = sim.Instance._place, sim.Instance._modify, sim.Instance.on_deal
def _place(self, cur, is_buy, price, role, s, layer=None):
    o, c = op(self, cur, is_buy, price, role, s, layer); log.append((cur, "PLACE %s %s %s %.5f bid %.5f ask %.5f" % (role, s, "buy" if is_buy else "sell", price, self.bid, self.ask))); return o, c
def _modify(self, cur, o, price):
    log.append((cur, "MODIFY %s %s -> %.5f (was %.5f) bid %.5f ask %.5f" % (o.role, o.side, price, o.price_at(cur), self.bid, self.ask))); return om(self, cur, o, price)
def on_deal(self, o, due, cur):
    log.append((due, "DEAL %s %s at %.5f bid %.5f ask %.5f" % (o.role, o.side, o.price_at(due), self.bid, self.ask))); return od(self, o, due, cur)
sim.Instance._place, sim.Instance._modify, sim.Instance.on_deal = _place, _modify, on_deal
pair = "AUDCAD"; b = load_bars(pair); bb = {k: v[:6000] for k, v in b.items()}
tm, bid, ask = pseudo_ticks(bb, "std", True); bid = np.round(bid, 5); ask = np.round(ask, 5)
tk = list(zip(tm.tolist(), bid.tolist(), ask.tolist()))
w, a, s = GEO[pair][0]
it = sim.run_single(tk, sim.Cfg(width=w, add=a, exit=a, cap=7, stranded=s, deadband=2.0))
n = 0
for t, m in log:
    if "ENT" in m and ("MODIFY" not in m or True):
        print(ts(t), m); n += 1
        if n > 70: break
