#!/usr/bin/env python3
# One-off (plan 2 s15): needs the 868bcc3 sync order logs (base and _t0) under /tmp/claude-0/r8
# and the send_logs of s0. Usage: price_agree.py b|c|d
"""Compare replay order prices (PLACE/MODIFY) to live send requested_price, timed vs t0."""
import csv, json, sys, bisect, collections, datetime as dt
SRV = 3*3600*1000
def live(fleet):
    rows=[]; tk={}
    for l in open(f'/mnt/user-data/uploads/Downloads/sends_EURUSD_OPT{fleet.upper()}_2026-10-09.jsonl',encoding='utf-8-sig'):
        d=json.loads(l)
        if d.get('table')!='send_logs' or not d.get('ok'): continue
        if d['action']=='PENDING' and d.get('result_order'):
            tk[d['result_order']]=(d['side'],d['layer_index'],d['role'])
        rows.append(d)
    out=[]
    for d in rows:
        if d['action']=='PENDING': key=(d['side'],d['layer_index'],d['role']); act='PLACE'
        elif d['action']=='MODIFY':
            if d['order_ticket'] not in tk: continue
            key=tk[d['order_ticket']]; act='MODIFY'
        else: continue
        t=dt.datetime.fromisoformat(d['received_at']).timestamp()*1000+SRV
        out.append((t,act,key,round(d['requested_price'],5)))
    return out
def replay(path):
    out=[]
    for r in csv.DictReader(open(path)):
        if r['action'] not in ('PLACE','MODIFY') or r['stage']=='SYNC': continue
        out.append((int(r['time_ms']),r['action'],(r['side'],int(r['layer']),r['role']),round(float(r['price']),5),r['seg_id']))
    return out
def agree(L, R, win=3000):
    # for each live send find replay row with same act+key nearest in time within win
    idx=collections.defaultdict(list)
    for r in R: idx[(r[1],r[2])].append(r)
    for v in idx.values(): v.sort()
    c=collections.Counter(); diffs=collections.Counter()
    for t,act,key,p in L:
        v=idx.get((act,key),[])
        ts=[x[0] for x in v]; i=bisect.bisect_left(ts,t)
        best=None
        for j in (i-1,i,i+1):
            if 0<=j<len(v) and abs(v[j][0]-t)<=win and (best is None or abs(v[j][0]-t)<abs(best[0]-t)): best=v[j]
        if best is None: c['nomatch']+=1; continue
        d=round((best[3]-p)*1e5)
        c['match']+=1; c['eq' if d==0 else 'ne']+=1; diffs[d]+=1
    return c,diffs
fl=sys.argv[1]
L=live(fl)
for tag in ['868bcc3','868bcc3_t0']:
    R=replay(f'/tmp/claude-0/r8/eurusd_{fl}_sync_{tag}/out_eurusd_{fl}_sync_orders.csv')
    for act in ['PLACE','MODIFY']:
        c,d=agree([x for x in L if x[1]==act],R)
        print(fl,tag,act,dict(c),'eq%%=%.1f'%(100*c['eq']/max(1,c['match'])), sorted(d.items())[:12])
