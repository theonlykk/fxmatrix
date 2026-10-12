"""Light-side add rules on a toy two-sided book (illustration only; not a sweep, not evidence).

Written 12 Oct 2026 (HANDOFF s80 continued 9) for docs/research/light-side-add-discussion.md s5.
Prices are in pips on a line. Start: 8 longs at 200, 190, ..., 130 (add 10, exit 10, cap 8),
no shorts, price 121, equity -352.

Rules of the toy:
- A long exits at entry + 10 on an uptick; a short exits at entry - 10 on a downtick.
- A long add rests 10 below the deepest long (only while longs < 8).
- The FIRST short trails at mid + 2 and is re-centred when it is more than 3 from mid and the
  shift is at least 2 (the EA's empty-side L0: width 2, stranded 3, deadband 2).
- Later short adds rest at (highest short) + RULE(gap), gap = longs - shorts, re-quoted when
  the target moves by 2 or more. A target below the market goes AT the market (the EA's
  ADR-013 clamp moves a sell limit below the bid up to the market).
- No rolls (no path goes below 120), no spread, no commission, no carry.

Run: python3 research/grid_thesis/light_side_toy.py
"""

LIN = [0.93, 0.86, 0.79, 0.71, 0.64, 0.57, 0.5]  # ADR-167's linear table (gap 1..7)


def today(gap, n_shorts):
    return 10.0


def equaliser(gap, n_shorts):
    return 10.0 * (LIN[min(gap, 7) - 1] if gap > 0 else 1.0)


def inverse(gap, n_shorts):
    return 10.0 * (1 + max(gap, 0) / 4.0)


def geometric(gap, n_shorts):
    return 10.0 * 2 ** (n_shorts - 1)


def slower_x2(gap, n_shorts):
    return 20.0 if gap >= 4 else 10.0


def pause_ge3(gap, n_shorts):
    return None if gap >= 3 else 10.0


def pause_ge1(gap, n_shorts):
    return None if gap >= 1 else 10.0


RULES = [
    ("today (symmetric, add 10)", today),
    ("equaliser (ADR-167 linear)", equaliser),
    ("inverse 10 x (1 + gap/4)", inverse),
    ("geometric 10, 20, 40 ...", geometric),
    ("x2 while gap >= 4", slower_x2),
    ("pause while gap >= 3", pause_ge3),
    ("pause while gap >= 1", pause_ge1),
]

EPS = 1e-9


def run(path, rule, log=None):
    longs = [200.0, 190.0, 180.0, 170.0, 160.0, 150.0, 140.0, 130.0]
    shorts, realised = [], 0.0
    lrest = srest = None
    prev = path[0]

    def note(text):
        if log is not None:
            log.append("%.1f %s -> %d/%d" % (p, text, len(longs), len(shorts)))

    for p in path:
        up, down = p > prev + EPS, p < prev - EPS
        for e in sorted(longs):
            if up and p >= e + 10 - EPS:
                longs.remove(e)
                realised += 10
                lrest = None
                note("long %g exits" % e)
        for s in sorted(shorts, reverse=True):
            if down and p <= s - 10 + EPS:
                shorts.remove(s)
                realised += 10
                srest = None
                note("short %g exits" % s)
        if down and lrest is not None and len(longs) < 8 and p <= lrest + EPS:
            longs.append(lrest)
            lrest = None
            note("long add %g" % longs[-1])
        if up and srest is not None and len(shorts) < 8 and p >= srest - EPS:
            shorts.append(srest)
            srest = None
            note("short add %g" % shorts[-1])
        if longs and len(longs) < 8:
            t = round(min(longs) - 10, 1)
            if lrest is None or abs(t - lrest) >= 2 - EPS:
                lrest = t
        else:
            lrest = None
        if not shorts:
            t = round(p + 2, 1)
            if srest is None or (abs(srest - p) > 3 + EPS and abs(t - srest) >= 2 - EPS):
                srest = t
        elif len(shorts) < 8:
            a = rule(len(longs) - len(shorts), len(shorts))
            if a is None:
                srest = None
            else:
                t = max(round(max(shorts) + a, 1), round(p, 1))
                if srest is None or abs(t - srest) >= 2 - EPS:
                    srest = t
        else:
            srest = None
        prev = p
    p = path[-1]
    equity = sum(p - e for e in longs) + sum(s - p for s in shorts) + realised
    return round(equity, 1), len(longs), len(shorts)


def leg(a, b):
    n = int(round(abs(b - a) * 10))
    step = 0.1 if b > a else -0.1
    return [round(a + step * i, 1) for i in range(n + 1)]


def chop():
    out = leg(121, 131) + leg(131, 121)[1:]
    for _ in range(2):
        out += leg(121, 131)[1:] + leg(131, 121)[1:]
    return out


PATHS = [
    ("A 121->200", leg(121, 200)),
    ("B 121->156.6->121", leg(121, 156.6) + leg(156.6, 121)[1:]),
    ("C chop 121-131 x3", chop()),
    ("D 121->200->121", leg(121, 200) + leg(200, 121)[1:]),
]


def main():
    print("start 121, equity -352; holding the 8 longs to 200 = +280")
    print("%-28s" % "rule" + "".join("%-20s" % name for name, _ in PATHS))
    for rname, rule in RULES:
        cells = []
        for _, path in PATHS:
            eq, nl, ns = run(path, rule)
            cells.append("%+.0f (%d/%d)" % (eq, nl, ns))
        print("%-28s" % rname + "".join("%-20s" % c for c in cells))


if __name__ == "__main__":
    main()
