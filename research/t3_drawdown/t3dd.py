"""t3 drawdown and commission read (descriptive; measures fixed before computing, see chat 24 Oct ~18:45Z).
October: committed day-end curves (sweep9 EURUSD, sweep10 others): one flat start 1 Oct, carried to 20 Oct,
carry ON, net = realised - commission + swap + open MTM, pips at 0.01 lots. Calm: sw11 weekly nets (flat starts)."""
import csv, re, sys
R = '/root/fxmatrix/research/replay/results/'
PIP = {"EURUSD": 0.100, "GBPUSD": 0.100, "EURGBP": 0.134, "AUDCAD": 0.0714, "AUDCHF": 0.122, "CADCHF": 0.122}
T3 = {"GBPUSD": (9, 15), "EURUSD": (7, 23), "EURGBP": (5, 23), "AUDCAD": (18, 26), "AUDCHF": (14, 20), "CADCHF": (10, 17)}
COMM = 0.06
def curves(pair):
    f = R + ('sweep9/sw9_curves.csv' if pair == 'EURUSD' else 'sweep10/sw10_%s_curves.csv' % pair.lower())
    rows = list(csv.reader(open(f))); hdr = rows[0]
    return hdr[1:], {r[0]: [float(x) for x in r[1:]] for r in rows[1:]}
def sr(pair, g):
    f = R + ('sweep9/sw9_report.md' if pair == 'EURUSD' else 'sweep10/sw10_%s.md' % pair.lower())
    t = open(f).read()
    m = re.search(r'^\| %s(?: \([^)]*\))? \| (\d+) \| (\d+) \|' % g, t, re.M)
    if m: return int(m.group(1)), int(m.group(2))
    m = re.search(r'OPT(?: =)? %s: net [^,]+, worst[^,]+, S (\d+), R (\d+)' % g, t)
    return (int(m.group(1)), int(m.group(2))) if m else None
def weekly(pair, add):
    t = open(R + 'sweep11/sw11_%s.md' % pair.lower()).read()
    m = re.search(r'^\| %s(?: \([A-Z]+\))? \| [-+.\d]+ \| \d / 8 \| ([-+\d ]+) \|' % add, t, re.M)
    return [float(x) for x in m.group(1).split()] if m else None
days = None; fleet = None; out = []; comm_tot = 0.0; net_tot = 0.0; missing = []
for pair, (o, a) in T3.items():
    d, cv = curves(pair); days = d
    for arm, add in (("OPT", o), ("ALT", a)):
        g = 'a%de%dn7' % (add, add)
        if g not in cv:
            missing.append('%s %s %d' % (pair, arm, add)); continue
        usd = [x * PIP[pair] for x in cv[g]]
        s_r = sr(pair, g); closes = sum(s_r) if s_r else None
        c = closes * COMM if closes is not None else None
        fleet = usd if fleet is None else [p + q for p, q in zip(fleet, usd)]
        out.append((pair, arm, add, usd[-1], min(usd), closes, c))
        if c is not None: comm_tot += c; net_tot += usd[-1]
def dd(path):
    peak, worst = path[0], 0.0
    for x in path: peak = max(peak, x); worst = min(worst, x - peak)
    return worst
print("OCTOBER (1-20 Oct, day-end marks), USD at 0.01 lots; missing:", missing)
print("%-7s %-3s %4s %9s %9s %7s %8s %9s" % ("pair", "arm", "add", "net", "worst", "closes", "comm", "gross"))
for pair, arm, add, net, worst, closes, c in out:
    print("%-7s %-3s %4d %+9.2f %+9.2f %7s %8.2f %+9.2f" % (pair, arm, add, net, worst, closes, c, net + c))
steps = [b - a for a, b in zip(fleet, fleet[1:])]
print("\nFleet (11 cells): net %+.2f, worst equity %+.2f, max drawdown %.2f, worst day %+.2f (%s), best day %+.2f" % (
    fleet[-1], min(fleet), dd(fleet), min(steps), days[1 + steps.index(min(steps))], max(steps)))
print("Fleet path:", " ".join("%s %+.0f" % (dd_[5:], v) for dd_, v in zip(days, fleet)))
print("Commission %.2f, net %+.2f, gross before commission %+.2f (commission / gross = %.0f%%)" % (
    comm_tot, net_tot, net_tot + comm_tot, 100 * comm_tot / (net_tot + comm_tot) if net_tot + comm_tot else 0))
# calm
wk = [0.0] * 8; cnet = 0.0
for pair, (o, a) in T3.items():
    for add in (o, a):
        w = weekly(pair, add)
        if w is None: print("no weekly", pair, add); continue
        wk = [p + q * PIP[pair] for p, q in zip(wk, w)]
print("\nCALM (8 Aug-Sep weeks, flat starts), fleet USD per week:", " ".join("%+.1f" % x for x in wk),
      "| total %+.2f, worst week %+.2f, weeks > 0: %d / 8" % (sum(wk), min(wk), sum(1 for x in wk if x > 0)))
