"""Random-walk calibration of vr.py's measures (minute sampling, 14000 minutes,
40 seeded paths): the values a pair must beat.

    python research/markout/cal.py
"""
import random,math,statistics as st
random.seed(7)
def zigzag(m,h):
    n=0; ext=m[0]; d=0
    for x in m:
        if d>=0:
            if x>ext: ext=x
            elif ext-x>=h: n+=1; d=-1; ext=x
        if d<0:
            if x<ext: ext=x
            elif x-ext>=h: n+=1; d=1; ext=x
    return n
N=14000
res={5:[],10:[],20:[]}; vr240=[]; vr1440=[]; vr60=[]
for rep in range(40):
    s=1.0; m=[0.0]
    for _ in range(N-1): m.append(m[-1]+random.gauss(0,s))
    v1=st.fmean([(m[i+1]-m[i])**2 for i in range(N-1)])
    def vq(q): return st.fmean([(m[i+q]-m[i])**2 for i in range(N-q)])/(q*v1)
    vr60.append(vq(60)); vr240.append(vq(240)); vr1440.append(vq(1440))
    for h in res: res[h].append(zigzag(m,h)*h*h/(v1*N))
print("random walk, sigma 1 pip/min, 14000 minutes, 40 paths:")
for h in res: print(f"  Z({h}) mean {st.fmean(res[h]):.2f} sd {st.stdev(res[h]):.2f}")
for nm,v in (("VR60",vr60),("VR240",vr240),("VR1440",vr1440)): print(f"  {nm} mean {st.fmean(v):.2f} sd {st.stdev(v):.2f}")
