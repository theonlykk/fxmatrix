"""classify_misses.py -- a first-pass category (replay plan s7) for each row of a compare.py
misses.csv, with its evidence. Read-only, standard library, no tests (a reading aid, like
check_accrued.py; every category it gives is checked by hand in the record, plan s12).

usage: python -B classify_misses.py <inputs dir> <runs dir> <harness sha7> <downloads dir> <misses.csv> <out csv>
(downloads dir: sends_EURUSD_OPT{B,C,D}_2026-10-09.jsonl and ticks_53077984_EURUSD_w2.csv)

Rules, first that fits:
- M3: 2 Oct 15:29-15:32 server (12:30Z US payrolls: several fills a second);
- M10: C seg 16 (the 6 Oct re-roll reload);
- M9: a row in the carry window 23:50-23:59 server;
- M11: within 60 s of a BREAKER_GATED interval in intervals_<tag>.csv;
- an L00 entry miss: the real order (send_logs: the last PENDING L00 ENT of that side before the
  fill) and the replay's close on that side just before it (deals, entry_type 3). M4? when the
  real order was re-centred (MODIFY) before it filled: the tick that re-centred decides the price.
  Else the replay's L0 = mid at its close +/- W (rounded): M3 when that price is farther than the
  real order and the touch did not reach it, or when the replay filled there within 60 s (a
  placement made at a different instant, hence a different mid); else M13?.
- an EXTRA paired with a classified miss (same fleet, segment, side, role, layer, within 60 s)
  takes its category; every other row is "open" (needs the replay's own order log).
"""
import bisect, csv, collections, datetime as dt, json, sys
E=dt.datetime(1970,1,1); OFF=3*3600*1000
def T(ms): return (E+dt.timedelta(milliseconds=int(ms))).strftime('%m-%d %H:%M:%S.%f')[:-3]
D=R=I=H=''
def sends(F):
    out=[]
    for l in open(f'{D}/sends_EURUSD_OPT{F}_2026-10-09.jsonl',encoding='utf-8-sig'):
        r=json.loads(l)
        if r.get('table')!='send_logs': continue
        out.append((int(r['ea_time_ms'])+OFF, r['action'], r.get('side'), r.get('layer_index'), r.get('role'), r.get('requested_price'), r.get('order_ticket') or r.get('result_order'), r.get('ok')))
    return out
def rep(f, mode='sync'):
    return [(int(r['time_ms']), 'REP', r['role'], r['side'], r['layer'], r['price'], r['entry_type']) for r in csv.DictReader(open((R+'/eurusd_%s_%s_%s/out_eurusd_%s_%s_deals.csv' % (f,mode,H,f,mode)))) if r['entry_type']=='0']
def real(f):
    return [(int(r['time_ms']), 'REAL', r['kind'], r['side'], r['layer'], r['price']) for r in csv.DictReader(open(f'{I}/real_eurusd_{f}.csv')) if r['kind'] in ('ENT','EXT','ROLL')]
def show(f, a, b, side=None, mode='sync'):
    F=f.upper()
    rows=[(t,'SEND',*x) for (t,*x) in sends(F) if a<=t<=b]
    rows+= [(t,*x) for (t,*x) in rep(f,mode) if a<=t<=b]
    rows+= [(t,*x) for (t,*x) in real(f) if a<=t<=b]
    rows.sort(key=lambda r:r[0])
    for r in rows:
        if side and r[1]=='SEND' and r[3] not in (side,None): continue
        print(T(r[0]), *r[1:])
def ms(s):  # 'MM-DD HH:MM:SS' 2026
    return int((dt.datetime.strptime('2026-'+s,'%Y-%m-%d %H:%M:%S')-E).total_seconds()*1000)
def events(f, mode='sync'):
    out=[]
    for i,l in enumerate(open((R+'/eurusd_%s_%s_%s/out_eurusd_%s_%s_events.csv' % (f,mode,H,f,mode)))):
        if i==0: continue
        p=l.rstrip('\n').split(',',5)
        out.append((int(p[2]), p[4], p[5]))
    return out
_TK=None
def ticks():
    global _TK
    if _TK is None:
        tt=[];bb=[];aa=[]
        for l in open(f'{D}/ticks_53077984_EURUSD_w2.csv'):
            if l[0]=='#' or l.startswith('time'): continue
            p=l.split(',')
            tt.append(int(p[0])); bb.append(float(p[1])); aa.append(float(p[2]))
        _TK=(tt,bb,aa)
    return _TK
def tick_at(t):
    tt,bb,aa=ticks(); i=bisect.bisect_right(tt,t)-1
    return tt[i],bb[i],aa[i]
def extreme(a,b,short=True):
    tt,bb,aa=ticks(); i=bisect.bisect_left(tt,a); j=bisect.bisect_right(tt,b)
    if short: return max(bb[i:j]) if j>i else None
    return min(aa[i:j]) if j>i else None
def rep_all(f, mode='sync'):
    return [(int(r['time_ms']), r['entry_type'], r['role'], r['side'], int(r['layer']) if r['layer'] not in ('','-1') else -1, float(r['price']), r['position']) for r in csv.DictReader(open((R+'/eurusd_%s_%s_%s/out_eurusd_%s_%s_deals.csv' % (f,mode,H,f,mode))))]

runs={}
gi={}
OUT=''
def seg(f,t):
    for x in runs[f]:
        if int(x['from_ms'])<=t<int(x['to_ms']): return x
NEWS=(ms('10-02 15:29:00'), ms('10-02 15:32:00'))
def in_gate(f,t,pad=60000):
    return any(k=='BREAKER_GATED' and a-pad<=t<=b+pad for k,a,b in gi.get(f,[]))
def l00_evidence(f,t,side):
    F=f.upper(); short=side=='S'; x=seg(f,t); W=float(x['width_s' if short else 'width_l'])
    s=sends(F)
    pend=[y for y in s if y[0]<t and y[2]==side and y[3]==0 and y[4]=='ENT' and y[1]=='PENDING']
    p=pend[-1]; mods=[y for y in s if y[1]=='MODIFY' and y[6]==p[6] and y[0]<t]
    if mods: return 'M4?', 're-centred %d times before the fill (K3): which tick re-centred decides the price; needs the replay order log' % len(mods)
    ra=rep_all(f)
    rc=[r for r in ra if r[0]<t and r[1]=='3' and r[3]==side and r[2]=='EXT']
    if not rc: return 'M13', 'no replay close before'
    _,b,a=tick_at(rc[-1][0]); pred=round((b+a)/2+(W if short else -W)*0.0001,5)
    order=p[5]; ext=extreme(p[0], t+500, short)
    farther = pred>order+1e-9 if short else pred<order-1e-9
    if farther and ((short and ext<pred-1e-9) or ((not short) and ext>pred+1e-9)):
        return 'M3', 'placement: replay L0 at its own close %.3f s earlier = %.5f, real %.5f placed later; touch %.5f did not reach the replay price' % ((p[0]-rc[-1][0])/1000, pred, order, ext)
    ex=[r for r in ra if r[1]=='0' and r[2]=='ENT' and r[3]==side and r[4]==0 and abs(r[0]-t)<=60000 and abs(r[5]-pred)<0.000015]
    if ex:
        return 'M3', 'placement: the replay placed L0 at its own close (%.3f s before the real) at %.5f and filled there %.3f s before the real fill at %.5f' % ((p[0]-rc[-1][0])/1000, pred, (t-ex[0][0])/1000, order)
    return 'M13?', 'pred %.5f real %.5f touch %.5f: replay should have filled; needs the replay order log' % (pred, order, ext)

def main():
    global I,R,H,D,runs,gi,NEWS,OUT
    I,R,H,D,MIS,OUT=sys.argv[1:7]
    runs.update({f:list(csv.DictReader(open('%s/run_eurusd_%s.csv' % (I,f)))) for f in 'bcd'})
    for f in 'bcd':
        for r in csv.DictReader(open('%s/intervals_eurusd_%s.csv' % (I,f))):
            gi.setdefault(f,[]).append((r['kind'],int(r['from_ms']),int(r['to_ms'])))
    rows=list(csv.DictReader(open(MIS)))
    out=[]
    for m in rows:
        f=m['fleet'][-1]; t=int(m['time_ms']); g=None; why=''
        if NEWS[0]<=t<=NEWS[1]: g,why='M3','2 Oct 12:30Z US payrolls burst (15:30 server): several fills a second'
        elif f=='c' and m['seg']=='16': g,why='M10','C seg 16: the 6 Oct Monday-build re-roll reload (ORDERS_KEPT 3/4, 2/4; the real EA moved 27 orders)'
        elif T(t)[6:11] in ('23:50','23:51','23:52','23:53','23:54','23:55','23:56','23:57','23:58','23:59'): g,why='M9','placed in the carry window 23:50-23:59 server'
        elif in_gate(f,t): g,why='M11','at the edge of the 1 Oct ADR-160 gate interval (data, earliest ON)'
        elif m['role']=='ENT' and m['layer']=='0' and m['kind']=='MISS': g,why=l00_evidence(f,t,m['side'])
        out.append([m['fleet'][-1].upper(),m['kind'],m['seg'],T(t),m['side'],m['role'],'L%02d'%int(m['layer']),m['price'],m['near_dt_ms'],m['near_dpts'],g,why])
    # extras: inherit from a paired miss (same fleet/seg/side/role/layer within 60 s)
    for o in out:
        if o[10] is None and o[1]=='EXTRA':
            t=ms(o[3][:14])
            pair=[p for p in out if p[1]=='MISS' and p[0]==o[0] and p[2]==o[2] and p[4]==o[4] and p[5]==o[5] and p[6]==o[6] and abs(ms(p[3][:14])-t)<=60000 and p[10]]
            if pair: o[10],o[11]=pair[0][10],'paired with the miss at %s (%s)' % (pair[0][3][6:], pair[0][10])
    for o in out:
        if o[10] is None: o[10],o[11]='open','to read with the replay order log'
    c=collections.Counter((o[0],o[10]) for o in out)
    tot=collections.Counter(o[10] for o in out)
    print(tot)
    for f in 'BCD': print(f, {k[1]:v for k,v in c.items() if k[0]==f})
    w=csv.writer(open(OUT,'w',newline=''),lineterminator='\n')
    w.writerow(['fleet','kind','seg','time_server','side','role','layer','price','near_dt_ms','near_dpts','category','evidence'])
    for o in out: w.writerow(o)

if __name__ == '__main__':
    main()
