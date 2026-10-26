"""Round numbers in FX: an Osler replication (research/cluster/PREREG.md v3.1).

    python research/cluster/osler.py --data <dir of bars_1514878887_<PAIR>.csv> --out <dir> --stage selfcheck
    python research/cluster/osler.py --data <dir> --out <dir> --stage real      (refused unless selfcheck PASSED)
    python -m pytest -q research/cluster/test_osler.py

Prices are integers in tenths of a point ("t10": 1.16000 -> 1160000; one point = 10 t10), so the band (0.0001 x L)
and every comparison are exact; PREREG s4's 1e-12 tolerance is a 1e-6 t10 tolerance (inclusive edges).
Implementation choices PREREG leaves to the code (stated here, fixed before any bar is read):
- block_index for the arbitrary levels' seed counts blocks over the whole run (H1's first, then H2's), from 0;
- the synthetic runs' permutation uses numpy's PCG64 seeded by random.Random(20261028 + run).getrandbits(63), the
  pairs permuted in PREREG s4's order from that one generator;
- the "move" after a crossing is (L - q_h) x side / L x 100 (positive in the crossing's direction), in % of L.
"""
import argparse
import csv
import hashlib
import json
import math
import os
import random
import sys

import numpy as np

PAIRS = ["EURUSD", "GBPUSD", "EURGBP", "AUDCAD", "AUDCHF", "CADCHF", "GBPCHF"]   # PREREG s4: pair_index 0-6
EXPECTED = {   # PREREG s3: sha256 first 16, bytes, bars
    "AUDCAD": ("B8ECCFF28A6BCAD0", 93922653, 1410650), "AUDCHF": ("091FB6B90C308FF4", 93257760, 1410274),
    "CADCHF": ("A136CD9577EC0448", 93895970, 1409386), "EURGBP": ("E9A2BE7535EA8D76", 93018928, 1409300),
    "EURUSD": ("2BDF7E05817E41A6", 92973101, 1407677), "GBPCHF": ("BFC4346FF988130A", 94323103, 1410930),
    "GBPUSD": ("742D88ADD02017E0", 93112293, 1407893),
}
DAY = 86400
H2_FIRST_DAY = 20089          # 2025-01-01 as days since 1970-01-01 (server dates)
LAST_DAY = 20749              # 2026-10-23
ROUND_STEP = 5000             # 0.0050 in t10
HORIZONS = (15, 30, 60, 120)
TOL = 1e-6


# ---------------------------------------------------------------- the quote, the band, the clock
def quote_t10(open_price, spread_points):
    return int(round(open_price * 100000)) * 10 + int(spread_points) * 5


def in_band(q, level):
    return abs(q - level) <= level * 1e-4 + TOL


def excluded(t_server):
    m = (int(t_server) % DAY) // 60
    return m >= 23 * 60 + 55 or m <= 10


def _excluded_vec(t):
    m = (t % DAY) // 60
    return (m >= 23 * 60 + 55) | (m <= 10)


def _ny_hours_vec(t):
    # PREREG s7: Osler's 09:00-16:00 New York = 16:00-23:00 server all year
    m = (t % DAY) // 60
    return (m >= 16 * 60) & (m < 23 * 60)


# ---------------------------------------------------------------- hits and outcomes
def _hits_arrays(t, q, level):
    d = q - level
    inside = np.abs(d) <= level * 1e-4 + TOL
    idx = np.nonzero(inside[1:] & ~inside[:-1])[0] + 1
    if idx.size == 0:
        return idx, idx
    idx = idx[~_excluded_vec(t[idx])]
    side = np.where(d[idx - 1] > 0, 1, -1)
    return idx, side


def level_hits(t, q, level):
    t = np.asarray(t, dtype=np.int64)
    q = np.asarray(q, dtype=np.int64)
    idx, side = _hits_arrays(t, q, level)
    return [(int(i), int(s)) for i, s in zip(idx, side)]


def _lookup(t, idx, h_min):
    target = t[idx] + 60 * h_min
    j = np.searchsorted(t, target, side="left")
    ok = j < t.size
    jj = np.where(ok, j, 0)
    ok &= t[jj] <= target + 300
    return jj, ok


def outcome(t, q, i, level, side, h_min):
    t = np.asarray(t, dtype=np.int64)
    q = np.asarray(q, dtype=np.int64)
    jj, ok = _lookup(t, np.array([i]), h_min)
    if not ok[0]:
        return (None, None)
    qh = int(q[jj[0]])
    kind = "CROSSING" if (qh - level) * side < 0 else "REVERSAL"
    move = (level - qh) * side / level * 100.0
    return (kind, move)


# ---------------------------------------------------------------- levels
def round_levels(qmin, qmax):
    lo = -(-int(qmin) // ROUND_STEP) * ROUND_STEP
    return list(range(lo, int(qmax) + 1, ROUND_STEP))


def round_class(level):
    return "R100" if level % (2 * ROUND_STEP) == 0 else "R50"


def draw_arbitrary(rng, qmin, qmax, n):
    out = []
    while len(out) < n:
        x = int(round(rng.uniform(qmin, qmax) / 10.0)) * 10
        if x < qmin or x > qmax:
            continue
        nearest = int(round(x / ROUND_STEP)) * ROUND_STEP
        if abs(x - nearest) <= 0.0002 * x:
            continue
        out.append(x)
    return out


# ---------------------------------------------------------------- v3.2: the comparison grids (STUB)
K_GRIDS = 20


def comparison_offsets(rng, qmax, k=K_GRIDS):
    raise NotImplementedError


def grid_levels(qmin, qmax, off):
    raise NotImplementedError


def comparison_stats(t, q, qmin, qmax, offsets, min_hits=10, min_cross=5):
    raise NotImplementedError


def selfcheck_ok(text):
    raise NotImplementedError


# ---------------------------------------------------------------- a pair-block
def _level_outcomes(t, q, level, ny):
    """For one level: per hit, (reversal at 15, crossing moves at each horizon or nan, ny-hours flag)."""
    idx, side = _hits_arrays(t, q, level)
    if idx.size == 0:
        return None
    jj, ok = _lookup(t, idx, 15)
    idx, side, jj = idx[ok], side[ok], jj[ok]
    if idx.size == 0:
        return None
    q15 = q[jj]
    cross = (q15 - level) * side < 0
    moves = {}
    for h in HORIZONS:
        jh, okh = _lookup(t, idx, h)
        mv = (level - q[jh]) * side / level * 100.0
        moves[h] = np.where(okh & cross, mv, np.nan)
    return {"n": idx.size, "rev": int((~cross).sum()), "cross": int(cross.sum()), "moves": moves,
            "ny_n": int(ny[idx].sum()), "ny_rev": int((~cross & ny[idx]).sum())}


def pair_block_stats(t, q, round_lv, arb_lv, min_hits=10, min_cross=5):
    t = np.asarray(t, dtype=np.int64)
    q = np.asarray(q, dtype=np.int64)
    ny = _ny_hours_vec(t)
    acc = {}
    for name, levels in (("round", round_lv), ("arb", arb_lv)):
        for lv in levels:
            keys = [name] + ([round_class(lv)] if name == "round" else [])
            r = _level_outcomes(t, q, lv, ny)
            if r is None:
                continue
            for k in keys:
                a = acc.setdefault(k, {"n": 0, "rev": 0, "cross": 0, "ny_n": 0, "ny_rev": 0,
                                       "moves": {h: [] for h in HORIZONS}})
                for f in ("n", "rev", "cross", "ny_n", "ny_rev"):
                    a[f] += r[f]
                for h in HORIZONS:
                    m = r["moves"][h]
                    a["moves"][h].extend(m[~np.isnan(m)].tolist())

    def get(k, f):
        return acc.get(k, {}).get(f, 0)

    def rate(k):
        return get(k, "rev") / get(k, "n") if get(k, "n") else None

    def mean_move(k, h):
        m = acc.get(k, {}).get("moves", {}).get(h, [])
        return float(np.mean(m)) if m else None

    st = {"round_hits": get("round", "n"), "arb_hits": get("arb", "n"),
          "r100_hits": get("R100", "n"), "r50_hits": get("R50", "n"),
          "round_cross": get("round", "cross"), "arb_cross": get("arb", "cross"),
          "rvr": rate("round"), "rva": rate("arb"), "rvr_r100": rate("R100"), "rvr_r50": rate("R50"),
          "ny_round_hits": get("round", "ny_n"), "ny_arb_hits": get("arb", "ny_n"),
          "ny_rvr": get("round", "ny_rev") / get("round", "ny_n") if get("round", "ny_n") else None,
          "ny_rva": get("arb", "ny_rev") / get("arb", "ny_n") if get("arb", "ny_n") else None}
    for h in HORIZONS:
        st["mvr_%d" % h] = mean_move("round", h)
        st["mva_%d" % h] = mean_move("arb", h)
    st["counted_reversal"] = st["round_hits"] >= min_hits
    st["counted_r100"] = st["r100_hits"] >= min_hits
    st["counted_r50"] = st["r50_hits"] >= min_hits
    st["counted_cross"] = st["round_cross"] >= min_cross
    st["counted_ny"] = st["ny_round_hits"] >= min_hits
    return st


# ---------------------------------------------------------------- inference
def sign_test_p(wins, n):
    if n <= 0:
        return 1.0
    return sum(math.comb(n, k) for k in range(wins, n + 1)) / 2.0 ** n


def common_days(counts):
    days = None
    for c in counts.values():
        ok = {d for d, k in c.items() if k >= 600}
        days = ok if days is None else days & ok
    return sorted(days or [])


def blocks(days):
    return [days[i:i + 10] for i in range(0, len(days) - 9, 10)]


def bootstrap_ci(values, seed=20261027, n=2000):
    rng = random.Random(seed)
    k = len(values)
    means = sorted(sum(values[rng.randrange(k)] for _ in range(k)) / k for _ in range(n))
    return means[50], means[1949]


def half_test(dvals, seed=20261027):
    d = [x for x in dvals if x is not None]
    wins = sum(1 for x in d if x > 0)
    losses = sum(1 for x in d if x < 0)
    n = wins + losses
    out = {"blocks": len(d), "wins": wins, "losses": losses, "ties": len(d) - n,
           "p": sign_test_p(wins, n), "mean": (sum(d) / len(d)) if d else None}
    out["ci"] = bootstrap_ci(d, seed) if d else (None, None)
    return out


# ---------------------------------------------------------------- data
def sha16(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()[:16].upper()


def load_pair(path):
    with open(path, encoding="ascii") as f:
        header = f.readline().strip()
        cols = f.readline().strip().split(",")
        assert cols == ["time_server", "time_unix_server", "open", "high", "low", "close", "spread_points",
                        "tick_volume"], cols
        t, q = [], []
        for row in csv.reader(f):
            t.append(int(row[1]))
            q.append(quote_t10(float(row[2]), int(row[6])))
    meta = dict(kv.split("=", 1) for kv in header.lstrip("# ").split() if "=" in kv)
    return meta, np.array(t, dtype=np.int64), np.array(q, dtype=np.int64)


def selfcheck_files(data):
    lines, ok = [], True
    loaded = {}
    for p in PAIRS:
        path = os.path.join(data, "bars_1514878887_%s.csv" % p)
        h, size = sha16(path), os.path.getsize(path)
        meta, t, q = load_pair(path)
        exp_h, exp_size, exp_n = EXPECTED[p]
        checks = {"sha256": h == exp_h, "bytes": size == exp_size, "bars": t.size == exp_n,
                  "symbol": meta.get("symbol") == p, "digits": meta.get("digits") == "5",
                  "server": meta.get("server") == "FTMO-Demo", "increasing": bool(np.all(np.diff(t) > 0))}
        good = all(checks.values())
        ok &= good
        lines.append("%s %s sha=%s bytes=%d bars=%d %s" % (p, "OK" if good else "FAIL", h, size, t.size,
                                                          " ".join(k for k, v in checks.items() if not v)))
        loaded[p] = (t, q)
    return ok, lines, loaded


# ---------------------------------------------------------------- the run
def run(loaded, min_hits=10, min_cross=5, log=None):
    counts = {p: {} for p in PAIRS}
    for p in PAIRS:
        d, c = np.unique(loaded[p][0] // DAY, return_counts=True)
        counts[p] = dict(zip(d.tolist(), c.tolist()))
    days = [d for d in common_days(counts) if d <= LAST_DAY]
    halves = {"H1": [d for d in days if d < H2_FIRST_DAY], "H2": [d for d in days if d >= H2_FIRST_DAY]}
    blk = [("H1", b) for b in blocks(halves["H1"])] + [("H2", b) for b in blocks(halves["H2"])]
    rows = []
    for pi, p in enumerate(PAIRS):
        t_all, q_all = loaded[p]
        day_all = t_all // DAY
        for bi, (half, bdays) in enumerate(blk):
            m = np.isin(day_all, bdays)
            t, q = t_all[m], q_all[m]
            qmin, qmax = int(q.min()), int(q.max())
            rnd = round_levels(qmin, qmax)
            arb = draw_arbitrary(random.Random(20261026 + 1000 * pi + bi), qmin, qmax, 200)
            st = pair_block_stats(t, q, rnd, arb, min_hits, min_cross)
            st.update({"pair": p, "half": half, "block": bi, "first_day": bdays[0], "last_day": bdays[-1],
                       "round_levels": len(rnd)})
            rows.append(st)
        if log:
            log("%s done" % p)
    return rows, blk


def block_d(rows, blk, measure):
    """D_j per block (PREREG s5): the mean over counted pairs of the measure's difference."""
    out = {"H1": [], "H2": []}
    for bi, (half, _) in enumerate(blk):
        diffs = []
        for r in rows:
            if r["block"] != bi:
                continue
            if measure == "rev" and r["counted_reversal"] and r["rva"] is not None:
                diffs.append(r["rvr"] - r["rva"])
            elif measure == "r100" and r["counted_r100"] and r["rva"] is not None:
                diffs.append(r["rvr_r100"] - r["rva"])
            elif measure == "r50" and r["counted_r50"] and r["rva"] is not None:
                diffs.append(r["rvr_r50"] - r["rva"])
            elif measure == "ny" and r["counted_ny"] and r["ny_rva"] is not None:
                diffs.append(r["ny_rvr"] - r["ny_rva"])
            elif measure.startswith("mv"):
                h = int(measure[2:])
                if r["counted_cross"] and r["mvr_%d" % h] is not None and r["mva_%d" % h] is not None:
                    diffs.append(r["mvr_%d" % h] - r["mva_%d" % h])
        out[half].append(sum(diffs) / len(diffs) if diffs else None)
    return out


def tests(rows, blk):
    res = {}
    for meas in ("rev", "r100", "r50", "ny", "mv15", "mv30", "mv60", "mv120"):
        d = block_d(rows, blk, meas)
        res[meas] = {h: half_test(d[h]) for h in ("H1", "H2")}
    return res


def permute_within_days(loaded, run_no):
    """PREREG s6.3: each pair's minute changes permuted within each trading day; the jumps across day boundaries
    kept in place, so each day's first q (and its sum of changes) is unchanged."""
    seed = random.Random(20261028 + run_no).getrandbits(63)
    gen = np.random.Generator(np.random.PCG64(seed))
    out = {}
    for p in PAIRS:
        t, q = loaded[p]
        day = t // DAY
        dq = np.diff(q)
        inside = np.nonzero(day[1:] == day[:-1])[0]
        order = inside[np.lexsort((gen.random(inside.size), day[1:][inside]))]
        dq2 = dq.copy()
        dq2[inside] = dq[order]
        out[p] = (t, np.concatenate(([q[0]], q[0] + np.cumsum(dq2))))
    return out


def decide(res, key):
    passes = {h: (res[key][h]["p"] < 0.01 and (res[key][h]["mean"] or 0) > 0) for h in ("H1", "H2")}
    if passes["H1"] and passes["H2"]:
        return "EFFECT (both halves)"
    if passes["H1"] or passes["H2"]:
        return "IN ONE HALF (%s)" % ("H1" if passes["H1"] else "H2")
    return "NONE"


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--stage", choices=("selfcheck", "real"), required=True)
    ap.add_argument("--runs", type=int, default=20)
    a = ap.parse_args(argv)
    os.makedirs(a.out, exist_ok=True)
    log = lambda s: print(s, flush=True)
    ok, lines, loaded = selfcheck_files(a.data)
    for ln in lines:
        log("FILE " + ln)
    sc_path = os.path.join(a.out, "selfcheck.txt")
    if a.stage == "selfcheck":
        rep = ["s6.1 files: %s" % ("PASS" if ok else "FAIL")] + ["  " + ln for ln in lines]
        if not ok:
            open(sc_path, "w").write("\n".join(rep + ["SELFCHECK: FAIL"]) + "\n")
            log("SELFCHECK: FAIL (files)")
            return 1
        sig = {"rev": 0, "mv15": 0}
        for r in range(a.runs):
            syn = permute_within_days(loaded, r)
            rows, blk = run(syn)
            res = tests(rows, blk)
            line = "run %2d:" % r
            for meas in ("rev", "mv15"):
                hit = any(res[meas][h]["p"] < 0.01 for h in ("H1", "H2"))
                sig[meas] += hit
                line += " %s H1 p=%.4f H2 p=%.4f%s" % (meas, res[meas]["H1"]["p"], res[meas]["H2"]["p"],
                                                      " SIG" if hit else "")
            rep.append(line)
            log(line)
        good = sig["rev"] <= 1 and sig["mv15"] <= 1
        rep.append("s6.3 synthetic: reversal significant in %d of %d runs, crossing size in %d of %d (bar: <= 1)"
                   % (sig["rev"], a.runs, sig["mv15"], a.runs))
        rep.append("SELFCHECK: %s" % ("PASS" if good else "FAIL"))
        open(sc_path, "w").write("\n".join(rep) + "\n")
        log(rep[-2])
        log(rep[-1])
        return 0 if good else 1
    # real
    if not os.path.exists(sc_path) or "SELFCHECK: PASS" not in open(sc_path).read() or not ok:
        log("REFUSED: run --stage selfcheck first (it must PASS on these files)")
        return 2
    rows, blk = run(loaded, log=log)
    res = tests(rows, blk)
    with open(os.path.join(a.out, "pair_blocks.csv"), "w", newline="") as f:
        cols = list(rows[0].keys())
        w = csv.DictWriter(f, fieldnames=cols)
        w.writeheader()
        w.writerows(rows)
    per_pair = {}
    for p in PAIRS:
        for h in ("H1", "H2"):
            d = [r["rvr"] - r["rva"] for r in rows if r["pair"] == p and r["half"] == h
                 and r["counted_reversal"] and r["rva"] is not None]
            per_pair["%s %s" % (p, h)] = half_test(d)
    summary = {"tests": res, "per_pair_reversal": per_pair,
               "decision": {"ROUND REVERSAL EFFECT": decide(res, "rev"),
                            "ROUND CROSSING EFFECT": decide(res, "mv15")},
               "blocks": {"H1": sum(1 for h, _ in blk if h == "H1"), "H2": sum(1 for h, _ in blk if h == "H2")}}
    with open(os.path.join(a.out, "summary.json"), "w") as f:
        json.dump(summary, f, indent=1, default=lambda o: list(o) if isinstance(o, tuple) else str(o))
    for k, v in summary["decision"].items():
        log("%s: %s" % (k, v))
    return 0


if __name__ == "__main__":
    sys.exit(main())
