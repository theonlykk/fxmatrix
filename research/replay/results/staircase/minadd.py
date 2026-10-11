"""The staircase (bounce 20, leg 30) with a minimum add (operator 10 Oct: adds below 3 are not used)."""
from stair import path, run

if __name__ == "__main__":
    pts = path(15, 30, 20)
    for amin in (3, 7):
        t, a, e, n = max((run(a, e, n, pts)[0], a, e, n)
                         for a in range(amin, 21) for e in range(2, 41) for n in range(1, 11))
        print("add >= %d: best net %+.0f at add %d exit %d layers %d (depth %d)" % (amin, t, a, e, n, a * n))
    for a, e, n in ((7, 13, 3), (7, 13, 8), (7, 10, 8)):
        print("add %d exit %d layers %d (depth %d): net %+.0f" % (a, e, n, a * n, run(a, e, n, pts)[0]))
