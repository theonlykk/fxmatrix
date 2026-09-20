"""Exit counterfactual replay -- implements prompts/exit_counterfactual_prereg.md (A3, 9823fb6).
Usage: set EXIT_REPLAY_DATA to a folder with deals_dump_20260918_2354.csv and the eight *_m1_bidask.csv files, then run.
Analysis only: reads CSVs, writes nothing."""

import numpy as np, pandas as pd, re
import os
UP=os.environ.get('EXIT_REPLAY_DATA','data/local/')  # folder holding the deals dump and the *_m1_bidask.csv files

PIP=1e-4
PAIRS=['GBPUSD','EURUSD','EURGBP','AUDCAD','AUDCHF','CADCHF','NZDCAD','AUDNZD']
LIVE={'GBPUSD':{'OPT':7,'ALT':10},'EURUSD':{'OPT':7,'ALT':10},'EURGBP':{'OPT':5,'ALT':8},
      'AUDCAD':{'OPT':5,'ALT':10},'AUDCHF':{'OPT':5,'ALT':10},'CADCHF':{'OPT':5,'ALT':10},
      'NZDCAD':{'OPT':5,'ALT':7},'AUDNZD':{'OPT':5,'ALT':7}}
GROUP={'GBPUSD':'majors','EURUSD':'majors','EURGBP':'EURGBP','AUDCAD':'crosses','AUDCHF':'crosses',
       'CADCHF':'crosses','NZDCAD':'NZD','AUDNZD':'NZD'}
XS=list(range(3,16))
ADR151=pd.Timestamp('2026-09-17 05:16:00')
CAL_DATES={'2026-09-10','2026-09-14','2026-09-16','2026-09-18'}

def load_deals():
    d=pd.read_csv(UP+'deals_dump_20260918_2354.csv'); d=d[d.symbol.notna()].copy()
    d['t']=pd.to_datetime(d.time,format='%Y.%m.%d %H:%M:%S')
    d[['slot','side','layer','role']]=d.comment.str.extract(r'^GRIND\|(OPT|ALT)\|(L|S)\|L(\d+)\|(ENT|EXT)$')
    return d

def build_layers(d):
    ent=d[(d.entry=='IN')&(d.role=='ENT')].set_index('position_id')
    ext=d[(d.entry=='IN')&(d.role=='EXT')].set_index('position_id')
    ob=d[d.entry=='OUT_BY'].copy(); ob[['a','b']]=ob.comment.str.extract(r'#(\d+) by #(\d+)').astype(float)
    man=d[d.entry=='OUT'].set_index('position_id')
    pair_of={}; cb_profit={}
    for key,grp in ob.groupby(['a','b']):
        a,b=int(key[0]),int(key[1])
        e,x=(a,b) if a in ent.index and b in ext.index else ((b,a) if b in ent.index and a in ext.index else (None,None))
        if e is None: continue
        pair_of[e]=x; cb_profit[e]=grp.profit.sum()
    rows=[]
    for pid,r in ent.iterrows():
        row=dict(pid=pid,symbol=r.symbol,slot=r.slot,side=r.side,t_ent=r.t,p_ent=r.price,date=r.t.strftime('%Y-%m-%d'))
        if pid in pair_of:
            x=ext.loc[pair_of[pid]]; row.update(obs='scalp',t_obs=x.t,p_obs=x.price,cb_profit=cb_profit[pid])
        elif pid in man.index:
            m=man.loc[pid]; row.update(obs='manual',t_obs=m.t,p_obs=m.price)
        else: row.update(obs='open')
        rows.append(row)
    L=pd.DataFrame(rows)
    L['sign']=np.where(L.side=='L',1,-1)
    L['group']=L.symbol.map(GROUP); L['live_x']=[LIVE[s][a] for s,a in zip(L.symbol,L.slot)]
    L['split']=np.where(L.date.isin(CAL_DATES),'cal','hold')
    return L

def load_bars():
    B={}
    for s in PAIRS:
        b=pd.read_csv(UP+f'{s}_m1_bidask.csv'); b['t']=pd.to_datetime(b.time_broker)
        B[s]=b
    return B

def usd_per_pip(L):
    out={}
    for s in PAIRS:
        if s.endswith('USD'): out[s]=0.10; continue
        sc=L[(L.symbol==s)&(L.obs=='scalp')]
        pips=(sc.p_obs-sc.p_ent)*sc.sign/PIP
        ok=pips.abs()>0.5
        out[s]=float(np.median(sc.cb_profit[ok]/pips[ok]))
    return out

def replay(L,B,xs=XS,include_entry_minute=False,manual_rule='A',end=None):
    """Returns long table: one row per layer per X."""
    res=[]
    for s in PAIRS:
        b=B[s]
        if end is not None: b=b[b.t<=end]
        tm=b.t.values; bh=b.bid_high.values; al=b.ask_low.values
        t_end=b.t.iloc[-1]; bid_c=b.bid_close.iloc[-1]; ask_c=b.ask_close.iloc[-1]
        Ls=L[L.symbol==s]
        if end is not None: Ls=Ls[Ls.t_ent<=end]
        for _,r in Ls.iterrows():
            emin=r.t_ent.floor('min').to_datetime64()
            i0=np.searchsorted(tm,emin,'left' if include_entry_minute else 'right')
            if r.side=='L':
                path=np.maximum.accumulate(bh[i0:]) if i0<len(bh) else np.array([])
            else:
                path=-np.minimum.accumulate(al[i0:]) if i0<len(al) else np.array([])
            man_t = r.t_obs if (r.obs=='manual' and manual_rule=='A' and (end is None or r.t_obs<=end)) else None
            for X in xs:
                tgt=r.p_ent+r.sign*X*PIP
                key=tgt-1e-9 if r.side=='L' else -tgt-1e-9
                j=np.searchsorted(path,key,'left') if len(path) else 0
                filled=j<len(path)
                if filled:
                    ft=pd.Timestamp(tm[i0+j])
                    if man_t is not None and ft.floor('min')>=man_t.floor('min'): filled=False
                if filled:
                    out,exit_t,pips=('fill',ft+pd.Timedelta(seconds=30),float(X))
                elif man_t is not None:
                    out,exit_t,pips=('manual',man_t,(r.p_obs-r.p_ent)*r.sign/PIP)
                else:
                    mark=bid_c if r.side=='L' else ask_c
                    out,exit_t,pips=('open',t_end,(mark-r.p_ent)*r.sign/PIP)
                res.append((r.pid,s,r.slot,r.group,r.split,X,out,exit_t,pips,(exit_t-r.t_ent).total_seconds()/86400))
    return pd.DataFrame(res,columns=['pid','symbol','slot','group','split','X','out','t_exit','gross','pos_days'])

d=load_deals(); L=build_layers(d); B=load_bars()
UPP=usd_per_pip(L)
R0=replay(L,B).merge(L[['pid','obs','live_x']],on='pid')
NOEXIT=set(R0[(R0.X==R0.live_x)&(R0.obs=='manual')&(R0.out=='fill')].pid)
L['noexit']=L.pid.isin(NOEXIT)
def run(**kw):
    R=replay(L,B,**kw).merge(L[['pid','noexit','t_obs','p_obs','p_ent','sign','t_ent','obs','live_x']],on='pid')
    if kw.get('manual_rule','A')=='A':
        m=R.noexit & ((kw.get('end') is None) | (R.t_obs<=kw.get('end',pd.Timestamp.max)))
        R.loc[m,'out']='manual'; R.loc[m,'t_exit']=R.loc[m,'t_obs']
        R.loc[m,'gross']=(R.loc[m,'p_obs']-R.loc[m,'p_ent'])*R.loc[m,'sign']/PIP
        R.loc[m,'pos_days']=(R.loc[m,'t_obs']-R.loc[m,'t_ent']).dt.total_seconds()/86400
    usd=np.where(R.out=='open',0.03,0.06)
    R['comm']=usd/R.symbol.map(UPP)
    R['net']=R.gross-R.comm
    return R
def curves(R,by):
    g=R.groupby(by+['X']).agg(gross=('gross','sum'),comm=('comm','sum'),net=('net','sum'),pos_days=('pos_days','sum'),
        fills=('out',lambda s:(s=='fill').sum()),n=('pid','count')).reset_index()
    g['net_per_posday']=g.net/g.pos_days
    return g
def smooth(v):
    v=np.asarray(v,float); out=np.empty_like(v)
    for i in range(len(v)):
        out[i]=np.median(v[max(0,i-1):i+2])
    return out
def select(xs,vals):
    sm=smooth(vals); mx=sm.max(); imax=int(np.argmax(sm))
    if mx<=0: return None,'max<=0',sm
    ok=sm>=0.9*mx; idx=np.where(ok)[0]
    if xs[imax] in (xs[0],xs[-1]): return None,f'max at boundary X={xs[imax]}',sm
    if (np.diff(idx)!=1).any(): return None,'acceptable set not contiguous',sm
    return xs[idx[(len(idx)-1)//2]],f'set {xs[idx[0]]}-{xs[idx[-1]]}',sm

def main():
    XS_=np.array(XS)
    R=run()
    print('14 no-exit manual layers:',len(NOEXIT))
    for grp in ['majors','EURGBP','crosses','NZD']:
        c=curves(R[(R.group==grp)&(R.split=='cal')],[]); c['net_day']=c.net/4
        print(f'\n-- {grp} calibration'); print(c.round(2).to_string(index=False))
        for m in ['net_day','net_per_posday']:
            x,why,_=select(XS_,c[m].values); print(f'   {m}: X*={x} ({why})')
    H=R[R.split=='hold']; rng=np.random.default_rng(20260920)
    for grp,x in [('EURGBP',11),('EURGBP',3),('crosses',14),('crosses',6),('majors',3),('majors',5)]:
        h=H[H.group==grp]; live=h[h.X==h.live_x].set_index('pid').net
        star=h[h.X==x].set_index('pid').net.reindex(live.index); diff=star-live
        bs=[diff.values[rng.integers(0,len(diff),len(diff))].sum() for _ in range(2000)]
        print(f'holdout {grp} X*={x}: star={star.sum():.1f} live={live.sum():.1f} interval={np.percentile(bs,[5,95]).round(1)}')

if __name__=='__main__':
    main()
