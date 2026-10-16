"""Pair cost ranking for choosing rings (docs/research/fleet-d-two-arm-ring-2026-10-16.md s3).
Read-only analysis of grind_bidask_dump minute-bar files (one bidask_<login>_<PAIR>.csv per pair);
standard library only (Python 3.9+).

    python research/pair_choice/spread_rank.py <bidask folder>

Per pair: median spread (ask_close - bid_close, server hours 02-22: the rollover hours excluded), median
hourly range of the mid, median daily range, spread / hourly range (the project's cost yardstick: lower is
cheaper to grid; 07_ROADMAP "avoid expensive legs"), and daily path / range at one-minute resolution.
Raw spread, before commission. No unit tests: an exploratory ranking whose numbers are quoted in the note
(the convention of research/markout).
"""
import csv, sys, os, statistics as st, collections
D=sys.argv[1]
rows=[]
for fn in sorted(os.listdir(D)):
    if not fn.endswith('.csv'): continue
    sym=fn.split('_')[-1][:-4]; pip=0.01 if 'JPY' in sym else 0.0001
    lines=[l for l in open(os.path.join(D,fn)) if not l.startswith('#')]
    r=list(csv.DictReader(lines))
    spreads=[]; hours=collections.defaultdict(list); days=collections.defaultdict(list)
    for x in r:
        t=x['time_server']; hh=int(t[11:13])
        bc,ac=float(x['bid_close']),float(x['ask_close'])
        mid_h=(float(x['bid_high'])+float(x['ask_high']))/2; mid_l=(float(x['bid_low'])+float(x['ask_low']))/2
        mid_c=(bc+ac)/2
        if 2<=hh<=22: spreads.append((ac-bc)/pip)       # skip the rollover hours (server 23-01)
        hours[t[:13]].append((mid_h,mid_l)); days[t[:10]].append((mid_h,mid_l,mid_c))
    hr=[(max(h for h,l in v)-min(l for h,l in v))/pip for v in hours.values() if len(v)>=30]
    dr=[];pr=[]
    for k,v in days.items():
        if len(v)<600: continue
        rng=(max(a for a,b,c in v)-min(b for a,b,c in v))/pip
        path=sum(abs(v[i][2]-v[i-1][2]) for i in range(1,len(v)))/pip
        dr.append(rng); pr.append(path/rng if rng else 0)
    rows.append((sym, st.median(spreads), st.median(hr), st.median(dr), st.median(pr)))
print('pair     spread  hourly_rng  daily_rng  spread/hourly  path/range(1-min, daily)')
for s,sp,h,d,p in sorted(rows, key=lambda x:x[1]/x[2]):
    print(f'{s:8} {sp:6.2f} {h:10.1f} {d:10.1f} {sp/h:12.3f} {p:12.1f}')
