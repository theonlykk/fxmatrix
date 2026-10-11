import math
import sys
T = sys.argv[1] if len(sys.argv) > 1 else '/mnt/user-data/uploads/Downloads/'
files={'EURUSD':T+'ticks_53077984_EURUSD_w2.csv'}
for _p in ('GBPUSD','EURGBP','AUDCAD','AUDCHF','CADCHF','NZDCHF','NZDCAD','AUDNZD'):
    files[_p]=T+'ticks_w2_8pairs/ticks_53077984_%s__w2.csv' % _p
END=1791503100000  # 8 Oct 23:45 server
def load(f):
    out=[]
    for line in open(f):
        if not line[0].isdigit(): continue
        t,b,a,_=line.split(',')
        t=int(t)
        if t>END: break
        out.append((t,(float(b)+float(a))/2))
    return out
def zigzag(px,step):
    # count reversals of size >= step pips
    n=0; ext=px[0]; d=0
    for p in px:
        if d>=0:
            if p>ext: ext=p
            elif (ext-p)*1e4>=step: n+=1; d=-1; ext=p
        if d<0:
            if p<ext: ext=p
            elif (p-ext)*1e4>=step: n+=1; d=1; ext=p
    return n
H={}
for k,f in files.items():
    s=load(f); px=[p for _,p in s]
    hours={}
    for t,p in s: hours[t//3600000]=p
    H[k]=hours
    net=(px[-1]-px[0])*1e4; rng=(max(px)-min(px))*1e4
    z5, z10 = zigzag(px, 5), zigzag(px, 10)
    print(f"{k}: start {px[0]:.5f} end {px[-1]:.5f} net {net:+.0f} pips, high-low range {rng:.0f}, 5-pip swings {z5}, 10-pip swings {z10}, 25-pip swings {zigzag(px,25)}, 10-pip swings per pip of net move {z10/max(1,abs(net)):.2f}")
ks=sorted(set(H['EURUSD'])&set(H['GBPUSD']))
def rets(h): return [math.log(h[ks[i]]/h[ks[i-1]]) for i in range(1,len(ks))]
a,b=rets(H['EURUSD']),rets(H['GBPUSD'])
ma,mb=sum(a)/len(a),sum(b)/len(b)
c=sum((x-ma)*(y-mb) for x,y in zip(a,b))/math.sqrt(sum((x-ma)**2 for x in a)*sum((y-mb)**2 for y in b))
print(f"hourly-return correlation EURUSD vs GBPUSD: {c:.2f} over {len(a)} hours")
