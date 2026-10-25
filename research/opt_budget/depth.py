"""Where OPT's scalps come from (by place in the stack) and how deep OPT and ALT sit.
python depth.py BASE.json B2.json  (one period)"""
import json, sys
PIP_USD = {"EURUSD": 0.100, "GBPUSD": 0.100, "EURGBP": 0.134, "AUDCAD": 0.0714, "AUDCHF": 0.122, "CADCHF": 0.122}
COMM = 0.06


def by_depth(res, arm):
    out = {k: [0, 0.0, 0, 0.0] for k in range(1, 8)}
    for pair, segs in res.items():
        pu = PIP_USD[pair]
        for s in segs:
            for k, v in s[arm]["by_depth"].items():
                o = out[int(k)]
                o[0] += v[0]; o[1] += v[1] * pu - v[0] * COMM; o[2] += v[2]; o[3] += v[3] * pu - v[2] * COMM
    return out


def occupancy(res):
    joint, tot = {}, 0
    for pair, segs in res.items():
        for s in segs:
            for k, ms in s["occ"].items():
                _, d_opt, d_alt = k.split("|")
                key = (int(d_opt), int(d_alt))
                joint[key] = joint.get(key, 0) + ms
                tot += ms
    return joint, tot


def main(bf, vf):
    b, v = json.load(open(bf)), json.load(open(vf))
    print("OPT closes by place in the stack (USD net of 0.06 a close): scalps n / USD, rolled n / USD")
    print("| layer | BASE scalps | BASE USD | B2 scalps | B2 USD | BASE rolled | USD | B2 rolled | USD |")
    print("|---|---|---|---|---|---|---|---|---|")
    bb, vv = by_depth(b, "OPT"), by_depth(v, "OPT")
    for k in range(1, 8):
        print("| %d | %d | %+.2f | %d | %+.2f | %d | %+.2f | %d | %+.2f |" % (k, bb[k][0], bb[k][1], vv[k][0], vv[k][1],
              bb[k][2], bb[k][3], vv[k][2], vv[k][3]))
    for name, d in (("BASE", bb), ("B2", vv)):
        print("%s: scalps 1-4 %d (%+.2f), 5-7 %d (%+.2f); rolled 1-4 %+.2f, 5-7 %+.2f" % (name,
              sum(d[k][0] for k in range(1, 5)), sum(d[k][1] for k in range(1, 5)),
              sum(d[k][0] for k in range(5, 8)), sum(d[k][1] for k in range(5, 8)),
              sum(d[k][3] for k in range(1, 5)), sum(d[k][3] for k in range(5, 8))))
    for name, res in (("BASE", b), ("B2", v)):
        joint, tot = occupancy(res)
        po = {i: sum(ms for (o, a), ms in joint.items() if o == i) / tot for i in range(8)}
        pa = {i: sum(ms for (o, a), ms in joint.items() if a == i) / tot for i in range(8)}
        print("%s time at depth 0..7 (both sides pooled): OPT %s | ALT %s" % (name,
              " ".join("%.0f%%" % (100 * po[i]) for i in range(8)), " ".join("%.0f%%" % (100 * pa[i]) for i in range(8))))
        deep = {(o, a): ms for (o, a), ms in joint.items() if o >= 5}
        dt = sum(deep.values())
        if dt:
            print("  %s: while OPT holds 5-7, ALT's depth: %s" % (name, " ".join(
                "%d:%.0f%%" % (i, 100 * sum(ms for (o, a), ms in deep.items() if a == i) / dt) for i in range(8))))
        mo = sum(o * ms for (o, a), ms in joint.items()) / tot
        ma = sum(a * ms for (o, a), ms in joint.items()) / tot
        print("  %s mean depth: OPT %.2f, ALT %.2f" % (name, mo, ma))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
