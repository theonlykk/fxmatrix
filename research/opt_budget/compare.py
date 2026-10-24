"""BUDGET against BASE (PREREG s5-s6). python compare.py BASE_CALM BUDGET_CALM BASE_OCT BUDGET_OCT"""
import json, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import score as sc


def fleet(res):
    net = comm = 0.0
    opt = {"S": 0, "R": 0, "A": 0}
    per_pair = {}
    for pair, segs in res.items():
        p = 0.0
        for arm in ("OPT", "ALT"):
            c = sc.cell(pair, arm, segs)
            net += c["net_usd"]; comm += c["comm_usd"]; p += c["net_usd"]
            if arm == "OPT":
                for k in opt:
                    opt[k] += c[k]
        per_pair[pair] = p
    return net, comm, opt, per_pair


def weeks(res):
    n = len(next(iter(res.values())))
    out = [0.0] * n
    for pair, segs in res.items():
        pu, cp = sc.PIP_USD[pair], sc.COMM / sc.PIP_USD[pair]
        for i, s in enumerate(sorted(segs, key=lambda x: x["from_ms"])):
            for arm in ("OPT", "ALT"):
                a = s[arm]
                out[i] += (a["realised"] + a["open"] - (a["S"] + a["R"]) * cp) * pu
    return out


def decide(bc, uc, bo, uo):
    c1 = uc["net"] >= 0.8 * bc["net"]
    c2 = uo["net"] >= bo["net"] - 20.0
    c3 = uo["ftmo"] <= 0.8 * bo["ftmo"] or (uc["net"] + uo["net"]) >= 1.2 * (bc["net"] + bo["net"])
    return c1, c2, c3, ("WORTH THE HARNESS" if (c1 and c2 and c3) else "NOT WORTH IT")


def main(bcf, ucf, bof, uof):
    out = {}
    for tag, f in (("base_calm", bcf), ("budget_calm", ucf), ("base_oct", bof), ("budget_oct", uof)):
        res = json.load(open(f))
        net, comm, opt, pp = fleet(res)
        d = {"net": net, "comm": comm, "gross": net + comm, "opt": opt, "per_pair": pp}
        if tag.endswith("calm"):
            w = weeks(res)
            d["worst_week"], d["weeks"] = min(w), w
        else:
            ts, bal, eq = sc.fleet_marks(res)
            d["ftmo"], d["d300"], d["d500"], d["mdd"], _ = sc.ftmo(ts, bal, eq)
        out[tag] = d
    bc, uc, bo, uo = out["base_calm"], out["budget_calm"], out["base_oct"], out["budget_oct"]
    print("| measure | calm BASE | calm BUDGET | October BASE | October BUDGET |")
    print("|---|---|---|---|---|")
    print("| fleet net USD | %+.2f | %+.2f | %+.2f | %+.2f |" % (bc["net"], uc["net"], bo["net"], uo["net"]))
    print("| commission | %.2f | %.2f | %.2f | %.2f |" % (bc["comm"], uc["comm"], bo["comm"], uo["comm"]))
    print("| gross | %+.2f | %+.2f | %+.2f | %+.2f |" % (bc["gross"], uc["gross"], bo["gross"], uo["gross"]))
    for k in ("S", "R", "A"):
        print("| OPT %s | %d | %d | %d | %d |" % (k, bc["opt"][k], uc["opt"][k], bo["opt"][k], uo["opt"][k]))
    print("| worst calm week | %+.2f | %+.2f | | |" % (bc["worst_week"], uc["worst_week"]))
    print("| largest FTMO-day loss | | | %.2f | %.2f |" % (bo["ftmo"], uo["ftmo"]))
    print("| days > $300 / > $500 | | | %d / %d | %d / %d |" % (bo["d300"], bo["d500"], uo["d300"], uo["d500"]))
    print("| max peak-to-trough | | | %.2f | %.2f |" % (bo["mdd"], uo["mdd"]))
    print()
    print("| pair | calm BASE | calm BUDGET | October BASE | October BUDGET |")
    print("|---|---|---|---|---|")
    for p in bc["per_pair"]:
        print("| %s | %+.2f | %+.2f | %+.2f | %+.2f |" % (p, bc["per_pair"][p], uc["per_pair"][p], bo["per_pair"][p], uo["per_pair"][p]))
    c1, c2, c3, v = decide(bc, uc, bo, uo)
    print()
    print("criterion 1 (calm net >= 80%% of BASE): %s (%.0f%%)" % (c1, 100 * uc["net"] / bc["net"] if bc["net"] else 0))
    print("criterion 2 (October net >= BASE - $20): %s (%+.2f)" % (c2, uo["net"] - bo["net"]))
    print("criterion 3 (October FTMO-day loss <= 80%%, or both periods >= 120%%): %s (%.0f%%; both %+.2f vs %+.2f)" % (
        c3, 100 * uo["ftmo"] / bo["ftmo"], uc["net"] + uo["net"], bc["net"] + bo["net"]))
    print("VERDICT:", v)


if __name__ == "__main__":
    main(*sys.argv[1:5])
