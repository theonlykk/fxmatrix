"""Plan 2 s18: D 21's 10:31 re-centre. The short L0 re-centres when the long side
holds layers, the short side is flat and |resting - mid| > stranded (14.0 pips in
seg 21's run row; Grind_TryRecenterOppositeL0 / Grind_ShouldRecenter). This prints,
for live's and each replay's resting S L00 ENT price, the distance to mid on every
tick from the real L2 ENT (10:31:07.285) to live's re-centre (11:03:10.950), and
the first tick (if any) at which each crosses 14.0.

usage: python -I d21_stranded.py TICKS_CSV
"""
import bisect, csv, datetime as dt, sys
T0 = int(dt.datetime(2026, 10, 1, tzinfo=dt.timezone.utc).timestamp() * 1000)
def ms(h, m, s, f=0): return T0 + ((h * 60 + m) * 60 + s) * 1000 + f
A, B = ms(10, 31, 7, 285), ms(11, 3, 10, 950)
PIP = 0.0001
rest = {"live": 1.13122, "timing 1": 1.13125, "timing 0": 1.13133}
ticks = []
with open(sys.argv[1], newline="") as fh:
    for row in csv.reader(fh):
        if not row or not row[0].isdigit():
            continue  # the '# symbol=...' line and the header
        t = int(row[0])
        if A <= t <= B: ticks.append((t, float(row[1]), float(row[2])))
print("ticks in window:", len(ticks))
for name, p in rest.items():
    first = next(((t, (p - (b + a) / 2) / PIP) for t, b, a in ticks if (p - (b + a) / 2) / PIP > 14.0 + 1e-9), None)
    mx = max((p - (b + a) / 2) / PIP for t, b, a in ticks)
    when = dt.datetime.fromtimestamp(first[0] / 1000, dt.timezone.utc).strftime("%H:%M:%S.%f")[:-3] if first else "-"
    print("%-9s resting %.5f  max distance %.2f pips  first > 14.0: %s%s" % (name, p, mx, when, (" (%.2f)" % first[1]) if first else ""))
