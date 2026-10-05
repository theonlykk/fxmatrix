"""Variance ratios and the zigzag oscillation ratio per pair (markout study s3.1).

    python research/markout/vr.py <grind_bidask_dump folder>

Mid = (bid close + ask close) / 2 per minute; minutes 20:50-22:15Z dropped (rollover).
VR(q) = Var(q-minute change) / (q x Var(1-minute change)), overlapping, only where both
ends exist. Z(h) = (number of h-pip zigzag legs) x h^2 / (reference variance per minute
x minutes): above the random-walk value (cal.py) = more oscillation at h pips than the
reference horizon implies.
"""
import csv,glob,os,math,statistics as st
import sys
D=sys.argv[1] if len(sys.argv)>1 else 'bidask_ftmo_2026-10-02'
def load(path):
    t=[];m=[]
    for r in csv.reader(open(path)):
        if not r or r[0].startswith('#') or r[0]=='time_server': continue
        ts=int(r[1])-10800
        bid=float(r[5]);ask=float(r[9])
        t.append(ts);m.append((bid+ask)/2)
    return t,m
def pipof(sym): return 0.01 if 'JPY' in sym else 0.0001
def roll_ok(ts):  # drop 20:50-22:15Z (rollover spreads)
    s=ts%86400; return not (20*3600+50*60 <= s < 22*3600+15*60)
def vr(t,m,pip):
    idx={ts:i for i,ts in enumerate(t)}
    out={}
    def var_q(q):
        xs=[]
        for i,ts in enumerate(t):
            j=idx.get(ts+60*q)
            if j is None or not roll_ok(ts) or not roll_ok(ts+60*q): continue
            xs.append((m[j]-m[i])/pip)
        return sum(x*x for x in xs)/len(xs) if xs else float('nan'), len(xs)
    v1,_=var_q(1)
    for q in (5,15,60,240,1440):
        vq,n=var_q(q); out[q]=vq/(q*v1)
    return out,v1
def zigzag(m,pip,h):
    n=0; ext=m[0]; d=0
    for x in m:
        if d>=0:
            if x>ext: ext=x
            elif (ext-x)/pip>=h: n+=1; d=-1; ext=x
        if d<0:
            if x<ext: ext=x
            elif (x-ext)/pip>=h: n+=1; d=1; ext=x
    return n
rows=[]
for p in sorted(glob.glob(D+'/*.csv')):
    sym=p.split('_')[-1][:-4]; pip=pipof(sym)
    t,m=load(p)
    r,v1=vr(t,m,pip)
    minutes=len(t)
    # variance per minute at the day horizon, from 1440 VR
    v_day_per_min=r[1440]*v1; v_4h=r[240]*v1
    z={h: zigzag(m,pip,h)*h*h/(v_day_per_min*minutes) for h in (5,10,20)}
    z4={h: zigzag(m,pip,h)*h*h/(v_4h*minutes) for h in (10,)}
    rows.append((sym,r,z,z4,math.sqrt(v1*1440*r[1440])))
print("pair    VR5   VR15  VR60  VR240 VR1440 | Z(5)  Z(10) Z(20) vs day-var | Z(10) vs 4h | daily sd pips")
for sym,r,z,z4,sd in sorted(rows,key=lambda x:x[1][1440]):
    print(f"{sym} {r[5]:5.2f} {r[15]:5.2f} {r[60]:5.2f} {r[240]:5.2f} {r[1440]:6.2f} | {z[5]:5.2f} {z[10]:5.2f} {z[20]:5.2f}            | {z4[10]:5.2f}      | {sd:5.1f}")
