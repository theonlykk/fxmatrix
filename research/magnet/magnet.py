"""Magnet grid: do round numbers pull price back? (research/magnet/PREREG.md v1)

    python research/magnet/magnet.py --data <dir of bars_1514878887_<PAIR>.csv> --out <dir> --stage selfcheck
    python research/magnet/magnet.py --data <dir> --out <dir> --stage real      (refused unless the selfcheck PASSED)
    python -m pytest -q research/magnet/test_magnet.py

Prices are integers in tenths of a point ("t10": 1.60000 -> 1600000; 1 pip = 100). Implementation choices PREREG
leaves to the code (fixed before any run):
- an order rests iff price was on its passive side at the previous bar's close (sell: prev bid close < P; buy: prev
  ask close > P); the first bar of a half uses its own open as the previous close;
- inside a bar: exits of positions entered (or rolled) in EARLIER bars first, then sell entries upward to the bid
  high, then buy entries downward to the ask low; a position entered or rolled in a bar is checked from the next bar;
- only bars whose span [min(bid low, prev bid close), max(ask high, prev ask close)] holds a grid line (a magnet or
  an entry price), and the bar after any entry or roll, are visited; any fill or exit needs one of those;
- placebo offsets per pair from random.Random(20261027 + pair_index), the same offsets in both halves;
- the FTMO-day loss (s6) is the day's start equity (the last bar-close equity before it) minus its lowest bar-close
  equity, the seven pairs summed on the union of their bar times (each pair's equity carried forward).
"""
import argparse
import csv
import json
import os
import random
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "cluster"))
import osler  # noqa: E402  (the file checks and the halves of PREREG v3.2)

PAIRS = osler.PAIRS
USD_PER_PIP = {"EURUSD": 0.100, "GBPUSD": 0.100, "EURGBP": 0.134, "AUDCAD": 0.0714, "AUDCHF": 0.122,
               "CADCHF": 0.122, "GBPCHF": 0.122}
COMM = 0.06
PIP = 100
DAY = 86400
K_PLACEBO = 20
MAIN = {"name": "main", "s": 5000, "d": 1000, "cap": 8}
VARIANTS = [{"name": "quarters", "s": 2500, "d": 1000, "cap": 8},
            {"name": "d15", "s": 5000, "d": 1500, "cap": 8},
            {"name": "uncapped", "s": 5000, "d": 1000, "cap": 10 ** 9}]


# ---------------------------------------------------------------- fills and slots (PREREG s2)
def sell_fills(prev_close_bid, bid_high, p):
    return prev_close_bid < p <= bid_high


def buy_fills(prev_close_ask, ask_low, p):
    return prev_close_ask > p >= ask_low


def magnet(o, s, n):
    return o + n * s


def sell_entry(o, s, d, n):
    return o + n * s + d


def buy_entry(o, s, d, n):
    return o + n * s - d


# ---------------------------------------------------------------- the engine
def _candidates(b, o, s, d):
    """Bars whose span (with the gap from the previous close) holds a grid line."""
    lo = np.asarray(b["l"], dtype=np.int64)
    hi = np.asarray(b["h"], dtype=np.int64)
    c = np.asarray(b["c"], dtype=np.int64)
    sp = np.asarray(b["s"], dtype=np.int64)
    op = np.asarray(b["o"], dtype=np.int64)
    pc = np.concatenate((op[:1], c[:-1]))
    pcs = np.concatenate((sp[:1], sp[:-1]))
    a = np.minimum(lo, pc)
    z = np.maximum(hi + sp, pc + pcs)
    hit = np.zeros(lo.size, dtype=bool)
    for base in (o, o + d, o - d):
        hit |= np.floor_divide(z - base, s) >= -np.floor_divide(-(a - base), s)
    return np.nonzero(hit)[0]


def run_grid(b, o, s, d, cap, usd_per_pip, equity=False):
    """One grid on one series: counts, realised and open P&L; with equity=True also the per-bar equity (USD)."""
    O, H, Lo, C, SP = b["o"], b["h"], b["l"], b["c"], b["s"]
    n_bars = len(O)
    shorts = {}     # slot n -> [real entry, effective entry, exit price, first bar its exit may fill]
    longs = {}
    realised_pips = 0.0
    closes = entries = rolls = 0
    ev = []
    cand = _candidates(b, o, s, d).tolist() if n_bars else []
    ci, forced, i = 0, -1, -1
    while True:
        nxt = cand[ci] if ci < len(cand) else n_bars
        if i < forced < nxt:
            nxt = forced
        if nxt >= n_bars:
            break
        while ci < len(cand) and cand[ci] <= nxt:
            ci += 1
        i = nxt
        pcb = C[i - 1] if i > 0 else O[i]
        pca = pcb + (SP[i - 1] if i > 0 else SP[i])
        bh, al = H[i], Lo[i] + SP[i]
        changed = False
        for n in [k for k, v in shorts.items() if v[3] <= i and al <= v[2]]:
            v = shorts.pop(n)
            realised_pips += (v[0] - v[2]) / PIP
            closes += 1
            changed = True
        for n in [k for k, v in longs.items() if v[3] <= i and bh >= v[2]]:
            v = longs.pop(n)
            realised_pips += (v[2] - v[0]) / PIP
            closes += 1
            changed = True
        n = (pcb - o - d) // s + 1                       # the lowest sell entry above the previous bid close
        while sell_entry(o, s, d, n) <= bh:
            p = sell_entry(o, s, d, n)
            if n not in shorts and sell_fills(pcb, bh, p):
                if len(shorts) < cap:
                    shorts[n] = [p, p, magnet(o, s, n), i + 1]
                    entries += 1
                else:
                    k = min(shorts, key=lambda m: shorts[m][1])
                    v = shorts.pop(k)
                    shorts[n] = [v[0], p, magnet(o, s, n), i + 1]
                    rolls += 1
                changed = True
                forced = i + 1
            n += 1
        n = -((-(pca - o + d)) // s) - 1                 # the highest buy entry below the previous ask close
        while buy_entry(o, s, d, n) >= al:
            p = buy_entry(o, s, d, n)
            if n not in longs and buy_fills(pca, al, p):
                if len(longs) < cap:
                    longs[n] = [p, p, magnet(o, s, n), i + 1]
                    entries += 1
                else:
                    k = max(longs, key=lambda m: longs[m][1])
                    v = longs.pop(k)
                    longs[n] = [v[0], p, magnet(o, s, n), i + 1]
                    rolls += 1
                changed = True
                forced = i + 1
            n -= 1
        if equity and changed:
            ev.append((i, realised_pips * usd_per_pip - closes * COMM, len(longs), sum(v[0] for v in longs.values()),
                       len(shorts), sum(v[0] for v in shorts.values())))
    last_bid = C[-1]
    last_ask = C[-1] + SP[-1]
    open_pips = (sum(v[0] - last_ask for v in shorts.values()) + sum(last_bid - v[0] for v in longs.values())) / PIP
    realised_usd = realised_pips * usd_per_pip - closes * COMM
    out = {"entries": entries, "closes": closes, "rolls": rolls, "realised_pips": realised_pips,
           "realised_usd": realised_usd, "open_short": len(shorts), "open_long": len(longs), "open_pips": open_pips,
           "net_usd": realised_usd + open_pips * usd_per_pip}
    if equity:
        out["equity"] = _equity(b, ev, usd_per_pip)
    return out


def _equity(b, ev, usd_per_pip):
    n = len(b["c"])
    cols = [np.zeros(n) for _ in range(5)]
    if ev:
        idx = np.array([e[0] for e in ev])
        for j, arr in enumerate(cols):
            vals = np.array([e[j + 1] for e in ev], dtype=float)
            step = np.zeros(n)
            step[idx] = np.diff(np.concatenate(([0.0], vals)))
            arr[:] = np.cumsum(step)
    r, ql, sl, qs, ss = cols
    bid = np.asarray(b["c"], dtype=float)
    ask = bid + np.asarray(b["s"], dtype=float)
    return r + ((ql * bid - sl) + (ss - qs * ask)) / PIP * usd_per_pip


# ---------------------------------------------------------------- the comparison (PREREG s4)
def placebo_offsets(rng, s, k):
    return [rng.randrange(500, s - 500 + 1, 10) for _ in range(k)]


def rank_of_real(real, placebos):
    return 1 + sum(1 for p in placebos if p >= real)


def ftmo_day(t_server):
    return (int(t_server) - 3600) // DAY


def permute_bars_within_days(b, rng):
    """Each day's bars after its first shuffled as (open gap, high, low, close relative to the open, spread); each day's
    first bar kept, so each day's first open and last close are unchanged."""
    t = b["t"]
    O, H, Lo, C, SP = (b[k] for k in ("o", "h", "l", "c", "s"))
    rel = [(O[i] - (C[i - 1] if i else O[i]), H[i] - O[i], Lo[i] - O[i], C[i] - O[i], SP[i]) for i in range(len(O))]
    out = {"t": list(t), "o": [], "h": [], "l": [], "c": [], "s": []}
    i = 0
    while i < len(t):
        j, day = i, t[i] // DAY
        while j < len(t) and t[j] // DAY == day:
            j += 1
        block = [rel[i]] + rng.sample(rel[i + 1:j], j - i - 1)
        prev = None
        for k, (g, dh, dl, dc, sp) in enumerate(block):
            op = O[i] if k == 0 else prev + g
            out["o"].append(op)
            out["h"].append(op + dh)
            out["l"].append(op + dl)
            out["c"].append(op + dc)
            out["s"].append(sp)
            prev = op + dc
        i = j
    return out


# ---------------------------------------------------------------- data and runs
def load_bars(path):
    with open(path, encoding="ascii") as f:
        f.readline()
        cols = f.readline().strip().split(",")
        assert cols[:7] == ["time_server", "time_unix_server", "open", "high", "low", "close", "spread_points"], cols
        b = {"t": [], "o": [], "h": [], "l": [], "c": [], "s": []}
        for row in csv.reader(f):
            b["t"].append(int(row[1]))
            for k, j in (("o", 2), ("h", 3), ("l", 4), ("c", 5)):
                b[k].append(int(round(float(row[j]) * 100000)) * 10)
            b["s"].append(int(row[6]) * 10)
    return b


def split_halves(b):
    out = {}
    for h, lo, hi in (("H1", 0, osler.H2_FIRST_DAY - 1), ("H2", osler.H2_FIRST_DAY, osler.LAST_DAY)):
        idx = [i for i, t in enumerate(b["t"]) if lo <= t // DAY <= hi]
        out[h] = {k: [b[k][i] for i in idx] for k in b}
    return out


def run_all(halves, spec, with_equity=False, log=None):
    res = {}
    for h in ("H1", "H2"):
        res[h] = {}
        for pi, p in enumerate(PAIRS):
            b = halves[p][h]
            offs = placebo_offsets(random.Random(20261027 + pi), spec["s"], K_PLACEBO)
            real = run_grid(b, 0, spec["s"], spec["d"], spec["cap"], USD_PER_PIP[p], equity=with_equity)
            plac = [run_grid(b, x, spec["s"], spec["d"], spec["cap"], USD_PER_PIP[p])["net_usd"] for x in offs]
            res[h][p] = {"real": real, "placebo": plac, "offsets": offs}
            if log:
                log("%s %s %s real %.2f placebo median %.2f" % (spec["name"], h, p, real["net_usd"],
                                                                 sorted(plac)[K_PLACEBO // 2]))
    return res


def pooled(res):
    out = {}
    for h, per in res.items():
        real = sum(v["real"]["net_usd"] for v in per.values())
        plac = [sum(v["placebo"][k] for v in per.values()) for k in range(K_PLACEBO)]
        out[h] = {"real": real, "placebo": plac, "rank": rank_of_real(real, plac)}
    return out


def risk(res, halves):
    """The real grid, seven pairs together: the worst FTMO-day loss, days over $500, the worst peak to trough."""
    out = {}
    for h, per in res.items():
        t_all = sorted(set().union(*[set(halves[p][h]["t"]) for p in per]))
        pos = {t: i for i, t in enumerate(t_all)}
        tot = np.zeros(len(t_all))
        for p, v in per.items():
            series = np.full(len(t_all), np.nan)
            series[[pos[t] for t in halves[p][h]["t"]]] = v["real"]["equity"]
            if np.isnan(series[0]):
                series[0] = 0.0
            last = np.maximum.accumulate(np.where(~np.isnan(series), np.arange(len(series)), 0))
            tot += series[last]
        days = np.array([ftmo_day(t) for t in t_all])
        cuts = np.nonzero(np.diff(days))[0] + 1
        starts = np.concatenate(([0], cuts))
        ends = np.concatenate((cuts, [len(t_all)]))
        losses = [((tot[a - 1] if a > 0 else 0.0) - tot[a:e].min(), int(days[a])) for a, e in zip(starts, ends)]
        worst = max(losses)
        peak = np.maximum.accumulate(np.maximum(tot, 0.0))
        out[h] = {"worst_ftmo_day_loss": float(worst[0]), "worst_day": worst[1],
                  "days_over_500": int(sum(1 for x, _ in losses if x > 500)),
                  "max_drawdown": float((peak - tot).max()), "end_equity": float(tot[-1])}
    return out


def decide(pool):
    first = {h: pool[h]["rank"] == 1 for h in ("H1", "H2")}
    if first["H1"] and first["H2"]:
        return "MAGNET EFFECT"
    if first["H1"] or first["H2"]:
        return "IN ONE HALF (%s)" % ("H1" if first["H1"] else "H2")
    return "NONE"


def selfcheck_ok(text):
    return "MAGNET PREREG v1" in text and "SELFCHECK: PASS" in text


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--stage", choices=("selfcheck", "real"), required=True)
    ap.add_argument("--runs", type=int, default=20)
    a = ap.parse_args(argv)
    os.makedirs(a.out, exist_ok=True)
    log = lambda s: print(s, flush=True)
    ok, lines, _ = osler.selfcheck_files(a.data)
    for ln in lines:
        log("FILE " + ln)
    sc_path = os.path.join(a.out, "selfcheck.txt")
    if not ok:
        open(sc_path, "w").write("\n".join(["MAGNET PREREG v1", "s5.1 files: FAIL"] + lines + ["SELFCHECK: FAIL"]) + "\n")
        log("SELFCHECK: FAIL (files)")
        return 1
    data = {p: load_bars(os.path.join(a.data, "bars_1514878887_%s.csv" % p)) for p in PAIRS}
    if a.stage == "selfcheck":
        rep = ["MAGNET PREREG v1", "s5.1 files: PASS"] + ["  " + ln for ln in lines]
        both_first, ranks = 0, []
        for r in range(a.runs):
            rng = random.Random(20261028 + r)
            perm = {p: split_halves(permute_bars_within_days(data[p], rng)) for p in PAIRS}
            pool = pooled(run_all(perm, MAIN))
            rk = (pool["H1"]["rank"], pool["H2"]["rank"])
            ranks += list(rk)
            hit = rk == (1, 1)
            both_first += hit
            line = "run %2d: pooled rank H1 %d H2 %d%s" % (r, rk[0], rk[1], " BOTH FIRST" if hit else "")
            rep.append(line)
            log(line)
        mean_rank = sum(ranks) / len(ranks)
        good = both_first <= 1 and 7 <= mean_rank <= 15
        rep.append("s5.3: first in both halves in %d of %d runs (bar <= 1); mean pooled rank %.2f (bar 7-15)"
                   % (both_first, a.runs, mean_rank))
        rep.append("SELFCHECK: %s" % ("PASS" if good else "FAIL"))
        open(sc_path, "w").write("\n".join(rep) + "\n")
        log(rep[-2])
        log(rep[-1])
        return 0 if good else 1
    if not os.path.exists(sc_path) or not selfcheck_ok(open(sc_path).read()):
        log("REFUSED: run --stage selfcheck first (a MAGNET PREREG v1 selfcheck that PASSED on these files)")
        return 2
    halves = {p: split_halves(data[p]) for p in PAIRS}
    summary = {}
    for spec in [MAIN] + VARIANTS:
        res = run_all(halves, spec, with_equity=(spec is MAIN), log=log)
        pool = pooled(res)
        entry = {"pooled": pool, "decision": decide(pool) if spec is MAIN else "reported (not deciding)",
                 "per_pair": {h: {p: {"real": {k: v for k, v in res[h][p]["real"].items() if k != "equity"},
                                      "rank": rank_of_real(res[h][p]["real"]["net_usd"], res[h][p]["placebo"]),
                                      "placebo": res[h][p]["placebo"], "offsets": res[h][p]["offsets"]}
                                  for p in PAIRS} for h in ("H1", "H2")}}
        if spec is MAIN:
            entry["risk"] = risk(res, halves)
        summary[spec["name"]] = entry
        log("%s: pooled rank H1 %d H2 %d -> %s" % (spec["name"], pool["H1"]["rank"], pool["H2"]["rank"],
                                                   entry["decision"]))
    with open(os.path.join(a.out, "summary.json"), "w") as f:
        json.dump(summary, f, indent=1)
    log("MAGNET: %s" % summary["main"]["decision"])
    return 0


if __name__ == "__main__":
    sys.exit(main())
