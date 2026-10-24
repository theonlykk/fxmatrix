import csv, re
U = '/mnt/user-data/uploads/replay/'; R = '/root/fxmatrix/research/replay/results/sweep11/'
PIP = {"EURUSD": 0.100, "GBPUSD": 0.100, "EURGBP": 0.134, "AUDCAD": 0.0714, "AUDCHF": 0.122, "CADCHF": 0.122}
T3 = {"GBPUSD": (9, 15), "EURUSD": (7, 23), "EURGBP": (5, 23), "AUDCAD": (18, 26), "AUDCHF": (14, 20), "CADCHF": (10, 17)}
def weekly_net(pair, add):
    t = open(R + 'sw11_%s.md' % pair.lower()).read()
    m = re.search(r'^\| %s(?: \([A-Z]+\))? \| ([-+.\d]+) \|' % add, t, re.M); return float(m.group(1))
tot = {'tight': [0, 0, 0], 'wide': [0, 0, 0]}
print("%-7s %-3s %4s %6s %6s %9s %8s %9s %6s" % ("pair", "arm", "add", "S", "R", "net USD", "comm", "gross", "c/g"))
for pair, (o, a) in T3.items():
    segs = {}
    for r in csv.DictReader(l for l in open(U + 'run_sw11w_%s.csv' % pair.lower()) if not l.startswith('#')):
        segs[int(r['seg_id'])] = float(r['add_l'])
    summ = {}
    for line in open(U + 'out_sw11w_%s_free_summary.txt' % pair.lower()):
        d = dict(kv.split('=') for kv in line.strip().split(',') if '=' in kv)
        if 'seg_id' in d: summ[int(d['seg_id'])] = d
    for arm, add in (('OPT', o), ('ALT', a)):
        ss = [s for s, ad in segs.items() if ad == add]; assert len(ss) == 8, (pair, add, len(ss))
        assert all(summ[s]['aborted'] == '0' for s in ss)
        S = sum(int(summ[s]['scalps']) for s in ss); Rr = sum(int(summ[s]['roll_closes']) for s in ss)
        net = weekly_net(pair, add) * PIP[pair]; comm = (S + Rr) * 0.06; gross = net + comm
        k = 'tight' if (arm == 'OPT' and add <= 14) else 'wide'
        tot[k][0] += net; tot[k][1] += comm; tot[k][2] += gross
        print("%-7s %-3s %4d %6d %6d %+9.2f %8.2f %+9.2f %5.0f%%" % (pair, arm, add, S, Rr, net, comm, gross, 100 * comm / gross if gross > 0 else float('nan')))
for k, (n, c, g) in tot.items(): print("%s: net %+.2f, commission %.2f, gross %+.2f" % (k, n, c, g))
n = sum(v[0] for v in tot.values()); c = sum(v[1] for v in tot.values()); print("FLEET calm: net %+.2f, commission %.2f, gross %+.2f, commission/gross %.0f%%" % (n, c, n + c, 100 * c / (n + c)))
