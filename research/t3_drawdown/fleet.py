import numpy as np, datetime as dt
D = np.load('/tmp/claude-0/-home-claude/8c85a736-7cc7-58a4-8120-9c451cc4c3f8/scratchpad/t3dd/cells.npy', allow_pickle=True).item()
t0 = None
for k, (t, e, b) in D.items():
    if t0 is None: t0 = t
    assert len(t) == len(t0) and (t == t0).all(), k
eq = sum(v[1] for v in D.values()); bal = sum(v[2] for v in D.values())
DAY = 86400000; srv = lambda ms: dt.datetime.utcfromtimestamp(ms / 1000)   # server clock (GMT+3)
z = lambda ms: srv(ms - 3 * 3600000).strftime('%a %d %b %H:%MZ')
print("12-cell fleet, 1-20 Oct, 5-min marks: end %+.2f, lowest equity %+.2f at %s, highest %+.2f" % (eq[-1], eq.min(), z(t0[eq.argmin()]), eq.max()))
peak = np.maximum.accumulate(eq); ddv = eq - peak; i = ddv.argmin(); j = eq[:i + 1].argmax()
print("max peak-to-trough %.2f: from %+.2f (%s) to %+.2f (%s)" % (ddv[i], eq[j], z(t0[j]), eq[i], z(t0[i])))
# FTMO days: start 01:00 server (22:00Z summer)
starts = sorted(set(((t - 3600000) // DAY) * DAY + 3600000 for t in t0))
rows = []
for s in starts:
    m = (t0 >= s) & (t0 < s + DAY)
    if not m.any(): continue
    k0 = np.argmax(m); start_bal = bal[k0]; low = eq[m].min(); kl = np.where(m)[0][eq[m].argmin()]
    rows.append((start_bal - low, srv(s).strftime('%a %d %b'), start_bal, eq[k0], low, z(t0[kl]), eq[np.where(m)[0][-1]]))
print("\nFTMO daily loss (day-start BALANCE - day's lowest EQUITY), worst first:")
print("%-11s %9s %9s %9s %9s %-16s %9s" % ("FTMO day", "loss", "start bal", "start eq", "low eq", "at", "end eq"))
for r in sorted(rows, reverse=True)[:6]:
    print("%-11s %9.2f %+9.2f %+9.2f %+9.2f %-16s %+9.2f" % (r[1], r[0], r[2], r[3], r[4], r[5], r[6]))
print("days: %d, days with loss > $50: %d" % (len(rows), sum(1 for r in rows if r[0] > 50)))
worst = max(r[0] for r in rows); dd = -ddv.min()
print("\nworst FTMO-day loss %.2f; max drawdown %.2f" % (worst, dd))
print("\nday-start (01:00 server): balance, equity, open = equity - balance")
for s in starts:
    k = np.searchsorted(t0, s)
    if k < len(t0): print("  %s  bal %+8.2f  eq %+8.2f  open %+8.2f" % (srv(s).strftime('%a %d %b'), bal[k], eq[k], eq[k] - bal[k]))
kl = eq.argmin(); print("\nat the low (%s), per cell: balance, open" % z(t0[kl]))
for k, (t, e, b) in sorted(D.items()):
    print("  %-12s bal %+8.2f open %+8.2f" % (k, b[kl], e[kl] - b[kl]))
print("\nFTMO-day losses in order:", " ".join("%s %.0f" % (r[1][4:10], r[0]) for r in sorted(rows, key=lambda r: dt.datetime.strptime(r[1] + ' 2026', '%a %d %b %Y'))))
for lim in (300, 500):
    first = [r for r in sorted(rows, key=lambda r: dt.datetime.strptime(r[1] + ' 2026', '%a %d %b %Y')) if r[0] > lim]
    print("days over $%d: %d; first %s" % (lim, len(first), first[0][1] if first else '-'))
hb = np.maximum.accumulate(bal); gap = (hb - eq).max(); kg = (hb - eq).argmax()
print("Instant trailing max loss: largest (highest balance so far - equity) %.2f at %s (limit $1,000 on $10k)" % (gap, z(t0[kg])))
