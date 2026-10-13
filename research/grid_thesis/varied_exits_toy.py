"""varied_exits_toy.py -- 12 Oct night (docs/research/grid-edge-assessment-2026-10-12.md s4-s5).

Two toys, no rolls, spread, commission or carry; prices in pips, 1-pip steps.
(1) An 8/8 book on a rally: longs above the price at +5, +12 ... +54 (add 7, exit 10), 8 shorts
    below; the price rises 56. Equity change = longs' gain to their exit or to the end, minus the
    shorts' 8 x 56.
(2) One long ladder, levels 200, 190 ... 130 (add 10, cap 8), each level buys again when the price
    returns: exits all 10 against exits 10, 15 ... 45 by depth, on four paths.

  python -I varied_exits_toy.py
"""


def eight_by_eight(rise=56, add=7, exit_=10):
    longs = [5 + add * k for k in range(8)]
    gain = sum(min(rise, d + exit_) for d in longs)
    closed = sum(1 for d in longs if d + exit_ <= rise)
    return gain, -8 * rise, gain - 8 * rise, closed


def path(*legs):
    p = [legs[0]]
    for x in legs[1:]:
        s = 1 if x > p[-1] else -1
        p += list(range(p[-1] + s, x + s, s))
    return p


def ladder(prices, exit_of):
    levels = [200 - 10 * k for k in range(8)]
    open_, realised, scalps = {}, 0, 0
    for px in prices:
        for k in list(open_):
            if px >= open_[k] + exit_of(k):
                realised += exit_of(k); scalps += 1; del open_[k]
        for k, lv in enumerate(levels):
            if k not in open_ and px <= lv:
                open_[k] = lv
    mtm = sum(prices[-1] - e for e in open_.values())
    return realised, mtm, realised + mtm, scalps


PATHS = (("A full reversion 200->121->200", (200, 121, 200)),
         ("B chop at the low 121<->141 x3", (200, 121, 141, 121, 141, 121, 141, 121)),
         ("C bounce fails 200->121->160->121", (200, 121, 160, 121)),
         ("D adverse 200->121->100", (200, 121, 100)))

if __name__ == "__main__":
    g, s, n, c = eight_by_eight()
    print("8/8 book, rally 56: longs %+d (%d closed at their exit), shorts %+d, equity %+d" % (g, c, s, n))
    print()
    print("%-36s %-24s %-24s" % ("path", "exits all 10: real/mtm/eq (S)", "exits 10..45: real/mtm/eq (S)"))
    for name, legs in PATHS:
        u = ladder(path(*legs), lambda k: 10)
        v = ladder(path(*legs), lambda k: 10 + 5 * k)
        print("%-36s %4d / %5d / %5d (%d)     %4d / %5d / %5d (%d)" % ((name,) + u + v))
