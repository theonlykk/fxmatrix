import sys
from multiprocessing import Pool
from stair import path, run
pats = [(30, 20), (60, 40), (15, 10), (40, 20), (25, 20), (45, 40)]
def one(pat):
    down, up = pat
    steps = max(5, 150 // (down - up))
    pts = path(steps, down, up)
    best = None
    for a in (1, 2, 3, 4, 5, 6, 8, 10):
        for e in range(1, 2 * up + 1):
            for n in range(1, (2 * up) // a + 2):
                tot = run(a, e, n, pts)[0]
                if best is None or tot > best[0]:
                    best = (tot, a, e, n)
    tot, a, e, n = best
    return "bounce %2d, leg %2d (drift %2d/step, trend %d): best a%d e%d N%d  D=%d  e/bounce %.2f  D/bounce %.2f  net %+.0f" % (
        up, down, down - up, steps * (down - up), a, e, n, a * n, e / up, a * n / up, tot)
if __name__ == "__main__":
    with Pool(6) as p:
        for line in p.map(one, pats):
            print(line)
