"""Score runs.py output: per cell and fleet USD at 0.01 lots, commission 0.06 a close; October FTMO days.
python score.py FILE [--ref oct|calm] [--vs BASEFILE]"""
import argparse, json, datetime as dt

PIP_USD = {"EURUSD": 0.100, "GBPUSD": 0.100, "EURGBP": 0.134, "AUDCAD": 0.0714, "AUDCHF": 0.122, "CADCHF": 0.122}
COMM = 0.06
DAY = 86400000
# the replay's own numbers (PREREG s4): closes S + R and net pips per cell
REF_OCT = {("GBPUSD", "OPT"): (324, -167.8), ("GBPUSD", "ALT"): (116, 75.1), ("EURUSD", "OPT"): (490, -361.2),
           ("EURUSD", "ALT"): (57, 454.4), ("EURGBP", "OPT"): (156, -409.2), ("EURGBP", "ALT"): (10, -307.0),
           ("AUDCAD", "OPT"): (47, 278.7), ("AUDCAD", "ALT"): (22, 181.4), ("AUDCHF", "OPT"): (45, 32.4),
           ("AUDCHF", "ALT"): (23, 179.6), ("CADCHF", "OPT"): (65, 177.3), ("CADCHF", "ALT"): (26, 255.4)}


def ref_calm(data_dir, md_dir):
    """The replay's calm numbers per t3 cell: closes from out_sw11w_<pair>_free_summary.txt (8 weeks), net pips from
    the committed sweep11 tables (sum of the weekly nets)."""
    import csv, re, os
    t3 = {"GBPUSD": (9, 15), "EURUSD": (7, 23), "EURGBP": (5, 23), "AUDCAD": (18, 26), "AUDCHF": (14, 20), "CADCHF": (10, 17)}
    out = {}
    for pair, (o, a) in t3.items():
        segs = {}
        with open(os.path.join(data_dir, "run_sw11w_%s.csv" % pair.lower()), encoding="utf-8-sig") as f:
            for r in csv.DictReader(l for l in f if not l.startswith("#")):
                segs[int(r["seg_id"])] = float(r["add_l"])
        summ = {}
        for line in open(os.path.join(data_dir, "out_sw11w_%s_free_summary.txt" % pair.lower())):
            d = dict(kv.split("=") for kv in line.strip().split(",") if "=" in kv)
            if "seg_id" in d:
                summ[int(d["seg_id"])] = int(d["scalps"]) + int(d["roll_closes"])
        md = open(os.path.join(md_dir, "sw11_%s.md" % pair.lower())).read()
        for arm, add in (("OPT", o), ("ALT", a)):
            closes = sum(summ[s] for s, ad in segs.items() if ad == add)
            m = re.search(r"^\| %s(?: \([A-Z]+\))? \| ([-+.\d]+) \|" % add, md, re.M)
            out[(pair, arm)] = (closes, float(m.group(1)))
    return out


def cell(pair, arm, segs):
    S = sum(s[arm]["S"] for s in segs); R = sum(s[arm]["R"] for s in segs); A = sum(s[arm]["A"] for s in segs)
    comm_pips = COMM / PIP_USD[pair]
    net = sum(s[arm]["realised"] + s[arm]["open"] for s in segs) - (S + R) * comm_pips
    return {"S": S, "R": R, "A": A, "closes": S + R, "net_pips": round(net, 1),
            "net_usd": round(net * PIP_USD[pair], 2), "comm_usd": round((S + R) * COMM, 2)}


def fleet_marks(res):
    """October: one segment per pair; sum USD equity and balance across the twelve cells at each 5-min mark."""
    series = None
    for pair, segs in res.items():
        assert len(segs) == 1
        pu, cp = PIP_USD[pair], COMM / PIP_USD[pair]
        rows = [(m[0], (m[1] - m[3] * cp + m[4] - m[6] * cp) * pu, (m[1] + m[2] - m[3] * cp + m[4] + m[5] - m[6] * cp) * pu)
                for m in segs[0]["marks"]]
        if series is None:
            series = {t: [b, e] for t, b, e in rows}
        else:
            for t, b, e in rows:
                if t in series:
                    series[t][0] += b; series[t][1] += e
    ts = sorted(series)
    return ts, [series[t][0] for t in ts], [series[t][1] for t in ts]


def ftmo(ts, bal, eq):
    days = {}
    for t, b, e in zip(ts, bal, eq):
        k = (t - 3600000) // DAY                       # FTMO day starts 01:00 server (22:00Z in summer)
        if k not in days:
            days[k] = [b, e]
        days[k][1] = min(days[k][1], e)
    losses = [s - lo for s, lo in days.values()]
    peak, mdd = eq[0], 0.0
    for e in eq:
        peak = max(peak, e); mdd = min(mdd, e - peak)
    return max(losses), sum(1 for x in losses if x > 300), sum(1 for x in losses if x > 500), -mdd, eq[-1]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("file")
    ap.add_argument("--ref", choices=["oct", "calm"])
    a = ap.parse_args()
    res = json.load(open(a.file))
    REF = REF_OCT if a.ref == "oct" else (ref_calm("/mnt/user-data/uploads/replay",
                                                   "/root/fxmatrix/research/replay/results/sweep11") if a.ref == "calm" else {})
    tot = {"net_usd": 0.0, "comm_usd": 0.0}
    print("%-7s %-3s %6s %6s %5s %10s %9s" % ("pair", "arm", "closes", "ref", "dev", "net pips", "ref net"))
    for pair, segs in res.items():
        for arm in ("OPT", "ALT"):
            c = cell(pair, arm, segs)
            tot["net_usd"] += c["net_usd"]; tot["comm_usd"] += c["comm_usd"]
            ref = REF.get((pair, arm))
            if ref:
                print("%-7s %-3s %6d %6d %+4.0f%% %+10.1f %+9.1f" % (pair, arm, c["closes"], ref[0],
                      100.0 * (c["closes"] - ref[0]) / ref[0], c["net_pips"], ref[1]))
            else:
                print("%-7s %-3s %6d %6s %5s %+10.1f" % (pair, arm, c["closes"], "", "", c["net_pips"]))
    print("FLEET net USD %+.2f, commission %.2f, gross %+.2f" % (tot["net_usd"], tot["comm_usd"], tot["net_usd"] + tot["comm_usd"]))
    if a.ref == "oct" or all(len(v) == 1 for v in res.values()):
        ts, bal, eq = fleet_marks(res)
        w, d300, d500, mdd, end = ftmo(ts, bal, eq)
        print("OCTOBER fleet: largest FTMO-day loss %.2f, days > $300 %d, > $500 %d, max peak-to-trough %.2f, end equity %+.2f"
              % (w, d300, d500, mdd, end))


if __name__ == "__main__":
    main()
