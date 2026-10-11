"""Toy two-sided lattice on the staircase (down 30, up 20, x15; units: 0.1 pip).
Levels at multiples of a from the start; long buys a free level on the way down while it
holds < N, exits at level + e; at the cap a NEW deeper level rolls (closes the highest long
at market, buys the new level). Shorts mirror. Commission 0.7 pip per close. Book marked
at the end. Idealised: not the EA (no L0 width, no exit re-levelling, no timing)."""
import itertools

def path(steps=15, down=30, up=20):
    p, pts = 0, [0]
    for _ in range(steps):
        for tgt in (p - down * 10, p - down * 10 + up * 10):
            d = 1 if tgt > p else -1
            while p != tgt:
                p += d
                pts.append(p)
    return pts

def run(a, e, n, pts, comm=7):
    A, E = a * 10, e * 10
    L, S = set(), set()
    pnl = cnt_s = cnt_r = 0
    prev = pts[0]
    for p in pts[1:]:
        up = p > prev
        if up:
            for lv in [x for x in L if x + E == p]:
                L.remove(lv); pnl += E - comm; cnt_s += 1
            if p % A == 0 and p not in S:
                if len(S) < n:
                    S.add(p)
                elif p > max(S):
                    lo = min(S); S.remove(lo); pnl += lo - p - comm; cnt_r += 1; S.add(p)
        else:
            for lv in [x for x in S if x - E == p]:
                S.remove(lv); pnl += E - comm; cnt_s += 1
            if p % A == 0 and p not in L:
                if len(L) < n:
                    L.add(p)
                elif p < min(L):
                    hi = max(L); L.remove(hi); pnl += p - hi - comm; cnt_r += 1; L.add(p)
        prev = p
    end = pts[-1]
    opn = sum(end - x for x in L) + sum(x - end for x in S)
    return (pnl + opn) / 10, cnt_s, cnt_r, opn / 10

if __name__ == "__main__":
  pts = path()
  res = []
  for a, e, n in itertools.product(range(2, 31), range(2, 41), range(1, 21)):
      tot, s, r, o = run(a, e, n, pts)
      res.append((tot, a, e, n, s, r, o))
  res.sort(reverse=True)
  print("best 12 (net pips, a, e, N, scalps, rolls, open at end):")
  for x in res[:12]: print("  %+7.1f a%-2d e%-2d N%-2d S%-4d R%-3d open %+.1f" % x)
  for a, e, n in ((5, 5, 8), (7, 10, 8), (7, 10, 10), (10, 10, 3), (10, 10, 8)):
      tot, s, r, o = run(a, e, n, pts)
      print("  check a%d e%d N%d: net %+.1f S %d R %d open %+.1f" % (a, e, n, tot, s, r, o))
  print("worst:", res[-1])
