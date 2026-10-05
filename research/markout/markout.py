"""Markouts of our entry fills (markout study s3.2).

    python research/markout/markout.py <grind_bidask_dump folder> <archive export .jsonl>

Every ENT layer (ev_book.build_layers on the archive) opened after the first bar + 1 h:
markout(h) = (mid(t + h) - entry) / pip for a long, (entry - mid) for a short, h in
minutes; mid = the minute bar containing t + h (in a closed-market gap: the next bar
within 3 days, else none). Depth = the side's open layers at the fill, itself included.
Mean and naive standard error (fills are NOT independent: see the study s5).
"""
import csv,glob,sys,bisect,statistics as st,collections,math
import os
sys.path.insert(0,os.path.join(os.path.dirname(os.path.abspath(__file__)),'..','ejection_value'))
import ev_data, ev_book
D=sys.argv[1] if len(sys.argv)>1 else 'bidask_ftmo_2026-10-02'
mids={}
for p in glob.glob(D+'/*.csv'):
    sym=p.split('_')[-1][:-4]; t=[];m=[]
    for r in csv.reader(open(p)):
        if not r or r[0].startswith('#') or r[0]=='time_server': continue
        t.append(int(r[1])-10800); m.append((float(r[5])+float(r[9]))/2)
    mids[sym]=(t,m)
exp=ev_data.load_export([sys.argv[2] if len(sys.argv)>2 else 'archive_2026-10-02.jsonl'])
layers=ev_book.build_layers(exp)
H=(0,1,5,15,60,240,1440)
def mid_at(sym,ts):
    t,m=mids[sym]; i=bisect.bisect_right(t,ts)-1   # bar containing ts (bar start <= ts)
    if i<0: return None
    if ts-t[i]>120:  # in a gap (weekend/closed): take the next bar if within 3 days
        j=i+1
        if j>=len(t) or t[j]-ts>3*86400: return None
        return m[j]
    return m[i]
def fleet(inst):
    for f in 'BCD':
        if inst.endswith('OPT'+f) or inst.endswith('ALT'+f): return f
    return 'A'
recs=[]
for inst,by in layers.items():
    sym=ev_data.symbol_of(inst)
    if sym not in mids: continue
    pip=0.0001
    lays=[l for l in by.values() if l.open_t is not None and l.open_price]
    for l in lays:
        if l.open_t < mids[sym][0][0]+3600: continue
        depth=sum(1 for o in by.values() if o.side==l.side and o.open_t is not None and o.open_t<=l.open_t and (o.close_t is None or o.close_t>l.open_t))
        sgn=1 if l.side=='L' else -1
        mk={}
        for h in H:
            x=mid_at(sym,l.open_t+60*h)
            mk[h]=None if x is None else sgn*(x-l.open_price)/pip
        recs.append(dict(f=fleet(inst),sym=sym,side=l.side,depth=depth,t=l.open_t,mk=mk))
print("entry fills with markouts:",len(recs), "from", min(r['t'] for r in recs))
def summ(rs,label):
    cells=[]
    for h in H:
        v=[r['mk'][h] for r in rs if r['mk'][h] is not None]
        if len(v)<5: cells.append("    -      "); continue
        se=st.stdev(v)/math.sqrt(len(v))
        cells.append(f"{st.fmean(v):+6.1f}+-{se:3.1f}")
    print(f"{label:18s} n={len(rs):5d} "+" ".join(cells))
print("markout in pips (+ = market came back our way), mean +- se, at", H, "minutes")
summ(recs,"ALL")
for f in 'ABCD': summ([r for r in recs if r['f']==f],"fleet "+f)
def db(d): return '1 (L0)' if d==1 else '2-3' if d<=3 else '4-5' if d<=5 else '6-7' if d<=7 else '8+ (cap)'
for b in ('1 (L0)','2-3','4-5','6-7','8+ (cap)'): summ([r for r in recs if db(r['depth'])==b],"depth "+b)
for s in sorted({r['sym'] for r in recs}): summ([r for r in recs if r['sym']==s],s)
