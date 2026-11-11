"""Does the gap between sim.py and core.ladder come from sim.py's add 'chasing' the bid when the spread is wide
(the behaviour the EA's C165 Grind_AddClampHold removed)? Patch a copy of sim.py in memory with the C165 hold and compare."""
import sys, types
from common import *
from core import ladder
SIM = sys.argv[1]; pair = sys.argv[2]; nb = int(sys.argv[3])
base = open(SIM).read().replace("        price = self.ask if o.is_buy else self.bid\n", "        price = o.price_at(due)\n")
OLD = """        if sd.add is not None and sd.add.resting():
            if abs(sd.add.price_at(cur + D_MODIFY) - px) >= self.cfg.deadband * PIP - EPS:
                cur = self._modify(cur, sd.add, px)
            return cur
"""
NEW = """        if sd.add is not None and sd.add.resting():
            rest = sd.add.price_at(cur + D_MODIFY)
            if abs(px - tgt) > PT * 0.1:                       # C165 hold (grind_pure.mqh Grind_AddClampHold)
                if sd.is_long and rest <= tgt + PT * 0.1 and px < rest - PT * 0.1:
                    return cur
                if (not sd.is_long) and rest >= tgt - PT * 0.1 and px > rest + PT * 0.1:
                    return cur
            if abs(rest - px) >= self.cfg.deadband * PIP - EPS:
                cur = self._modify(cur, sd.add, px)
            return cur
"""
assert base.count(OLD) == 1
def load(src, name):
    m = types.ModuleType(name); sys.modules[name] = m; exec(compile(src, SIM, "exec"), m.__dict__); return m
s_old = load(base, "sim_old"); s_new = load(base.replace(OLD, NEW), "sim_c165")
b = load_bars(pair); bb = {k: v[:nb] for k, v in b.items()}
for path, clean in (("raw", False), ("clean", True)):
    tm, bid, ask = pseudo_ticks(bb, "std", clean); bid = np.round(bid, 5); ask = np.round(ask, 5)
    tk = list(zip(tm.tolist(), bid.tolist(), ask.tolist()))
    for arm, (w, a, s) in zip(("OPT", "ALT"), GEO[pair]):
        out = []
        for lab, sm in (("sim.py as is", s_old), ("sim.py + C165 hold", s_new)):
            it = sm.run_single(tk, sm.Cfg(width=w, add=a, exit=a, cap=7, stranded=s, deadband=2.0))
            tot = it.realised_pips() + it.open_pips(tk[-1][1], tk[-1][2])
            out.append("%s: closes %d rolls %d total %+.0f pips" % (lab, len(it.closes), it.rolls, tot))
        o = ladder(bid, ask, ((tm // 60000) % 1440).astype(np.int64), np.zeros(len(tm), np.int64), 1, w, float(a), float(a), s, 2.0, 7, True, 0, 1)
        out.append("core.ladder: closes %d rolls %d total %+.0f pips" % (o[2][0], o[4][0], o[0][0] + o[1][0]))
        print(pair, path, arm, a, "|", " | ".join(out), flush=True)
