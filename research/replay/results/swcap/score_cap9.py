"""swcap (sweep_notes): the harness fleet with t3's OPT at cap 9 and the ALT cells as run, scored as t3_drawdown.
Calm: weekly nets from swcapw_<pair>.md (sweep.py score) + ALT's calm nets (sweep11 tables). October: score9's
accounting at 5-minute marks, FTMO day from 01:00 server. python score_cap9.py DATA_DIR"""
import csv, os, re, sys
import numpy as np
HERE = os.path.dirname(os.path.abspath(__file__))
REPLAY = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, REPLAY); sys.path.insert(0, os.path.join(REPLAY, "results", "sweep9"))
import score9 as s9  # noqa: E402

PIP = {"EURUSD": 0.100, "GBPUSD": 0.100, "EURGBP": 0.134, "AUDCAD": 0.0714, "AUDCHF": 0.122, "CADCHF": 0.122}
T3 = {"GBPUSD": (9, 15), "EURUSD": (7, 23), "EURGBP": (5, 23), "AUDCAD": (18, 26), "AUDCHF": (14, 20), "CADCHF": (10, 17)}
STEP, DAY = 300000, 86400000


def calm_total(md, gname):
    t = open(md).read()
    m = re.search(r"^\| %s \| \d+ \| \d+ \| \d+ \| [^|]+ \| [^|]+ \| [^|]+ \| [^|]+ \| [^|]+ \| ([-+.\d]+) \|" % gname, t, re.M)
    return float(m.group(1))


def alt_calm(pair, add):
    t = open(os.path.join(REPLAY, "results", "sweep11", "sw11_%s.md" % pair.lower())).read()
    return float(re.search(r"^\| %s(?: \([A-Z]+\))? \| ([-+.\d]+) \|" % add, t, re.M).group(1))


def oct_cell(data, tag, gname, pair):
    segs, names, pos, scalps, snaps, counts = s9.load_run(os.path.join(data, "run_%s.csv" % tag),
                                                         os.path.join(data, "out_%s_free_deals.csv" % tag),
                                                         os.path.join(data, "out_%s_free_events.csv" % tag))
    seg = [s for s, n in names.items() if n == gname]
    assert len(seg) == 1, (tag, gname)
    seg = seg[0]
    r = segs[seg]
    f0, t1 = int(r["from_ms"]), int(r["to_ms"])
    p, sc, sn = pos.get(seg, []), sorted(scalps.get(seg, [])), snaps.get(seg, [])
    tk = s9.Ticks(os.path.join(data, "ticks_53077984_EURUSD_w2hw.csv" if pair == "EURUSD" else
                               "ticks_53077984_%s_oct.csv" % pair))
    comm = 0.06 / PIP[pair]
    times = list(range(f0, t1 + 1, STEP))
    eq, bal = [], []
    for t in times:
        e = s9.equity_at(p, sc, sn, t, tk.mark, comm=comm)
        closed = [x for x in p if x[1] <= t and x[3] is not None and x[3] <= t]
        b = sum(w * d * (cpx - opx) * 10000.0 for d, o, opx, c, cpx, w in closed)
        b -= comm * sum(1 for s in sc if s <= t)
        for s_ms, sl, ss, mult in sn:
            if s_ms <= t:
                for d, o, _o, c, _c, _w in closed:
                    if o <= s_ms < c:
                        b += (sl if d == 1 else ss) * mult / 10.0
        eq.append(e * PIP[pair]); bal.append(b * PIP[pair])
    c = counts.get(seg, {"S": 0, "R": 0, "A": 0})
    return times, np.array(eq), np.array(bal), c


def oct_alt_tag(pair, add):
    if pair == "EURUSD":
        return "sw9_d7"
    return "sw10_%s" % pair.lower()


def main(data):
    calm = {}
    for pair, (o, a) in T3.items():
        calm[pair] = (calm_total(os.path.join(HERE, "swcapw_%s.md" % pair.lower()), "a%de%dn9" % (o, o)) * PIP[pair],
                      alt_calm(pair, a) * PIP[pair])
    calm_net = sum(x + y for x, y in calm.values())
    t0, EQ, BAL, octn, opt_counts = None, None, None, {}, {}
    for pair, (o, a) in T3.items():
        to, eo, bo, co = oct_cell(data, "swcapo_%s" % pair.lower(), "a%de%dn9" % (o, o), pair)
        ta, ea, ba, ca = oct_cell(data, oct_alt_tag(pair, a), "a%de%dn7" % (a, a), pair)
        assert to == ta
        octn[pair] = (eo[-1], ea[-1])
        opt_counts[pair] = co
        if t0 is None:
            t0, EQ, BAL = to, eo + ea, bo + ba
        else:
            assert to == t0
            EQ, BAL = EQ + eo + ea, BAL + bo + ba
    days = {}
    for t, b, e in zip(t0, BAL, EQ):
        k = (t - 3600000) // DAY
        if k not in days:
            days[k] = [b, e]
        days[k][1] = min(days[k][1], e)
    losses = [s - lo for s, lo in days.values()]
    peak, mdd = EQ[0], 0.0
    for e in EQ:
        peak = max(peak, e); mdd = min(mdd, e - peak)
    oct_net = float(EQ[-1])
    both = calm_net + oct_net
    a_ok = both >= 1.2 * 230.64
    b_ok = max(losses) <= 1.1 * 626.51
    print("| pair | calm OPT cap 9 | calm ALT | October OPT cap 9 | October ALT |")
    print("|---|---|---|---|---|")
    for p in T3:
        print("| %s | %+.2f | %+.2f | %+.2f | %+.2f |" % (p, calm[p][0], calm[p][1], octn[p][0], octn[p][1]))
    print()
    print("calm net %+.2f; October net %+.2f; both %+.2f (rule: >= %.2f) -> %s" % (calm_net, oct_net, both, 1.2 * 230.64, a_ok))
    print("October largest FTMO-day loss %.2f (rule: <= %.2f) -> %s; days > $300 %d, > $500 %d; max peak-to-trough %.2f"
          % (max(losses), 1.1 * 626.51, b_ok, sum(1 for x in losses if x > 300), sum(1 for x in losses if x > 500), -mdd))
    print("OPT cap 9 October S / R / A:", {p: (c["S"], c["R"], c["A"]) for p, c in opt_counts.items()})
    print("VERDICT:", "CONFIRMED" if (a_ok and b_ok) else "NOT CONFIRMED")


if __name__ == "__main__":
    main(sys.argv[1])
