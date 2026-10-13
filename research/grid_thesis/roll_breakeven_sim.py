"""roll_breakeven_sim.py -- 12 Oct night (docs/research/grid-edge-assessment-2026-10-12.md s6).

One long ladder on a lattice: add a, exit e, cap N. A level buys when touched and free; a layer
sells at entry + e (a scalp, S); at the cap, when the price touches the next level below the
deepest, the SHALLOWEST layer is closed there (a roll step: realised loss N * a = D) and the level
buys. Prices: a 1-pip random walk, 3600 steps a day (about 60 pips a day). Fills exactly at the
levels; commission c a close. Break-even scalps per roll: D / e (no costs), (D + c) / (e - c).

  python -I roll_breakeven_sim.py      (about 15 s)
"""
import random
import statistics

a, e, N, comm = 7, 10, 8, 0.7
D = N * a


def run(days, drift=0.0, steps_per_day=3600):
    px, anchor = 0, 0
    held = []                     # entries, shallowest first
    S = R = 0
    real = 0.0
    closes = 0
    daily, eq_prev = [], 0.0
    for _d in range(days):
        for _ in range(steps_per_day):
            px += 1 if random.random() < 0.5 + drift else -1
            keep = []
            for en in held:
                if px >= en + e:
                    S += 1; real += e; closes += 1
                else:
                    keep.append(en)
            held = keep
            if px <= anchor and (anchor - px) % a == 0 and px not in held:
                if len(held) < N:
                    held.append(px); held.sort(reverse=True)
                elif px < min(held):
                    top = held.pop(0); R += 1; real -= (top - px); closes += 1
                    held.append(px); held.sort(reverse=True)
            if not held and px > anchor:
                anchor = px - (px - anchor) % a
        eq = real + sum(px - en for en in held)
        daily.append(eq - eq_prev)
        eq_prev = eq
    return S, R, real, closes, daily, eq_prev


if __name__ == "__main__":
    print("a=%d e=%d N=%d: a roll step costs D = %d; break-even scalps per roll %.2f (no costs), %.2f (%.1f a close)" % (
        a, e, N, D, D / e, (D + comm) / (e - comm), comm))
    random.seed(11)
    S, R, real, closes, daily, eq = run(2000)
    sd = statistics.stdev(daily)
    se = sd / len(daily) ** 0.5
    print("no drift, 2000 days: S/R %.2f; before costs %+.2f a day (sd %.0f, se %.1f); after costs %+.2f a day; "
          "days up %.0f%%; worst day %+.0f, best %+.0f" % (
              S / R, eq / 2000, sd, se, (eq - closes * comm) / 2000,
              100 * sum(1 for x in daily if x > 0) / len(daily), min(daily), max(daily)))
    for p_up in (0.4975, 0.495):
        random.seed(3)
        s, r, re_, cl, dly, eq2 = run(300, drift=p_up - 0.5)
        print("drift %+.0f pips a day against the stack: S/R %.2f, before costs %+.1f a day, after costs %+.1f a day" % (
            (2 * p_up - 1) * 3600, s / r, eq2 / 300, (eq2 - cl * comm) / 300))
