"""OPT cap sweep (PREREG_CAP.md). python capcmp.py DIR  (base_calm.json, c7_oct.json, c{9,11,13}_{calm,oct}.json)"""
import json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import score as sc
import compare as cp


def peak_layers(res):
    tot = {}
    for pair, segs in res.items():
        for m in segs[0]["marks"]:
            tot[m[0]] = tot.get(m[0], 0) + m[7] + m[8]
    return max(tot.values())


def inventory(res):
    out = {}
    for pair, segs in res.items():
        pu = sc.PIP_USD[pair]
        out[pair] = min((m[2] + m[5]) * pu for m in segs[0]["marks"])
    return out


def main(d):
    caps = {7: ("base_calm.json", "c7_oct.json")}
    for c in (9, 11, 13):
        caps[c] = ("c%d_calm.json" % c, "c%d_oct.json" % c)
    rows = {}
    for c, (fc, fo) in caps.items():
        rc, ro = json.load(open(os.path.join(d, fc))), json.load(open(os.path.join(d, fo)))
        nc, cc, oc, ppc = cp.fleet(rc)
        no, co, oo, ppo = cp.fleet(ro)
        ts, bal, eq = sc.fleet_marks(ro)
        w, d3, d5, mdd, _ = sc.ftmo(ts, bal, eq)
        rows[c] = dict(nc=nc, no=no, both=nc + no, rc=oc["R"], ro=oo["R"], sc=oc["S"], so=oo["S"], ftmo=w, d3=d3, d5=d5,
                       mdd=mdd, peak=peak_layers(ro), worst_week=min(cp.weeks(rc)), ppc=ppc, ppo=ppo, inv=inventory(ro))
    b = rows[7]
    print("| OPT cap | calm net | October net | both | OPT scalps calm / Oct | OPT rolled closes calm / Oct | "
          "largest FTMO-day loss | days > $300 / $500 | max peak-to-trough | peak open layers (Oct) | verdict |")
    print("|---|---|---|---|---|---|---|---|---|---|---|")
    for c, r in rows.items():
        better = r["both"] >= 1.2 * b["both"] and r["ftmo"] <= 1.1 * b["ftmo"]
        v = "BASE" if c == 7 else ("BETTER" if better else "NOT BETTER")
        print("| %d | %+.2f | %+.2f | %+.2f | %d / %d | %d / %d | %.2f | %d / %d | %.2f | %d | %s |" % (
            c, r["nc"], r["no"], r["both"], r["sc"], r["so"], r["rc"], r["ro"], r["ftmo"], r["d3"], r["d5"], r["mdd"],
            r["peak"], v))
    print()
    print("Per pair (reported, not deciding): calm net / October net / October worst open P&L (inventory), USD")
    print("| pair | " + " | ".join("cap %d" % c for c in rows) + " |")
    print("|---|" + "---|" * len(rows))
    for p in b["ppc"]:
        print("| %s | " % p + " | ".join("%+.0f / %+.0f / %.0f" % (r["ppc"][p], r["ppo"][p], r["inv"][p]) for r in rows.values()) + " |")


if __name__ == "__main__":
    main(sys.argv[1])
