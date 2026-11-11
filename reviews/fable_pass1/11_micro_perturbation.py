"""How sensitive is a 4-year total to rule details that should not matter? Three live arms are rerun with width
(+/- 0.1, 0.2 pip), stranded (+/- 0.2) and deadband (1.9, 2.0, 2.1) nudged: 45 runs each, FTMO bars, std clean
path, recorded bid/ask, limit fills, both fill models. Output: out/11_micro_perturbation.txt"""
from common import *
from core import ladder
C0 = np.zeros((0, 7))
L = ["Micro-perturbation of (width, stranded, deadband): 45 runs per arm and fill model. Total pips over 46 months, real bid/ask.",
     "pair   arm add | fill | base run | mean of 45 |   sd | min .. max | rolled closes min .. max"]
for pair, k in (("AUDCAD", 0), ("AUDCAD", 1), ("EURGBP", 1), ("EURUSD", 0)):
    b = load_bars(pair); tm, bid, ask = pseudo_ticks(b, "std", True)
    tod = ((tm // 60000) % 1440).astype(np.int64); per = np.zeros(len(tm), np.int64)
    w, a, s = GEO[pair][k]
    for fill, one in (("cont", False), ("one", True)):
        res = []
        for dw in (-0.2, -0.1, 0.0, 0.1, 0.2):
            for ds in (-0.2, 0.0, 0.2):
                for db in (1.9, 2.0, 2.1):
                    o = ladder(bid, ask, tod, per, 1, w + dw, float(a), float(a), s + dw + ds, db, 7, True, 0, 50, False, C0, one)
                    res.append((dw, ds, db, o[0][0] + o[1][0], o[3][0]))
        v = np.array([r[3] for r in res]); base = [r[3] for r in res if r[0] == 0 and r[1] == 0 and r[2] == 2.0][0]
        L.append("%s %s %3d | %s | %+8.0f | %+8.0f   | %4.0f | %+8.0f .. %+8.0f | %d .. %d" % (pair, ("OPT", "ALT")[k], a, fill, base, v.mean(), v.std(ddof=1),
                 v.min(), v.max(), min(r[4] for r in res), max(r[4] for r in res)))
        print(L[-1], flush=True)
open(os.path.join(OUT, "11_micro_perturbation.txt"), "w").write("\n".join(L) + "\n")
