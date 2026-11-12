"""AUDCAD wide rungs out of sample: research/audcad_oos/PREREG.md (amended s93j; Argon 2: SOUND).

    python research/audcad_oos/run_oos.py --selfcheck <in-sample bars> <new bars> <fable cont csv> <fable one csv>
    python research/audcad_oos/run_oos.py --oos <new bars>

Fable's engine, unchanged (reviews/fable_pass1/core.py `ladder`, common.py `pseudo_ticks` and friends, and
`summarise` from 04_ladder_bars.py); this file only points them at a given bar file and runs the ten cells (s3).
--selfcheck runs s4 a-d and prints `SELFCHECK: a .., b .., c .., d DONE`; it never runs the ladder on the new bars.
--oos refuses unless research/audcad_oos/selfcheck_out.txt on origin/main reads all PASS (s8), then runs the ten
cells in four variants on 2020-2022 (decides, s2a) and on 2018-2019 (reported only), each from flat on its own bars,
with the 0.2 pip sensitivity and s6's rule; writes oos_result.json beside this file and prints the tables."""
import hashlib
import importlib.util
import json
import math
import os
import subprocess
import sys
import tempfile

import numpy as np
import pandas as pd

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
FABLE = os.path.join(REPO, "reviews", "fable_pass1")
for k in ("FR_CACHE", "FR_OUT"):                       # Fable's common.py makes these at import: keep them out of
    os.environ.setdefault(k, tempfile.mkdtemp(prefix="oos_"))  # the repo; this runner never uses its cache
sys.path.insert(0, FABLE)

PAIR = "AUDCAD"
ADDS = (17, 18, 20, 23, 26)
CELLS = [(a, x) for a in ADDS for x in (a, 2 * a)]      # (add, exit): exit = a or 2a (s3)
VARIANTS = (("cont", "std"), ("cont", "alt"), ("one", "std"), ("one", "alt"))
SENS_PIPS_PER_CLOSE = 0.4                                # every fill 0.2 pip worse, entry and exit (s3)
GATE_LINE = "SELFCHECK: a PASS, b PASS, c PASS, d DONE"
FABLE_HASH = {"cont": "63052ba31b142d92", "one": "d224418cff16c238"}
MIN_BARS_MONTH = 15000


# ---------------------------------------------------------------- pure functions (tested without data)
def years_needed(y):
    return int(math.ceil(0.6 * y - 1e-12))


def passes(r):
    return (r["mean"] > 0 and r["t"] >= 2.0 and r["years_pos"] >= years_needed(r["years"])
            and r["cells_pos"] >= 7)


def decide(base, sens):
    """s6: base and sens are dicts of mean, t, years_pos, years, cells_pos (cont-std)."""
    if not base["mean"] > 0:
        return "FAILS"
    if not passes(base):
        return "INCONCLUSIVE"
    return "HOLDS" if passes(sens) else "FRAGILE"


def gate_ok(text):
    return bool(text) and GATE_LINE in text


def slice_bars(b, y0, y1):
    """The bars whose server-clock date falls in calendar years y0..y1 (PREREG s2a)."""
    yr = pd.to_datetime(b["t"], unit="s").year.values
    m = (yr >= y0) & (yr <= y1)
    return {k: v[m] for k, v in b.items()}


DECIDE = (2020, 2022)                                    # PREREG s2a: decides
REPORT = (2018, 2019)                                    # PREREG s2a: reported beside it, does not decide


def load_bars_file(path):
    """common.load_bars's body, for a given file and without its cache (s3)."""
    df = pd.read_csv(path, skiprows=1)
    return {"t": df["time_unix_server"].to_numpy(np.int64), "o": df["open"].to_numpy(float),
            "h": df["high"].to_numpy(float), "l": df["low"].to_numpy(float), "c": df["close"].to_numpy(float),
            "sp": df["spread_points"].to_numpy(float) * 1e-5, "tv": df["tick_volume"].to_numpy(np.int64)}


# ---------------------------------------------------------------- Fable's engine
def engine():
    import common
    import core
    spec = importlib.util.spec_from_file_location("ladder_bars_04", os.path.join(FABLE, "04_ladder_bars.py"))
    mod = importlib.util.module_from_spec(spec)
    argv, sys.argv = sys.argv, ["04_ladder_bars.py", "cont"]
    try:
        spec.loader.exec_module(mod)                     # defines summarise; its run_cell is not used
    finally:
        sys.argv = argv
    return common, core, mod.summarise


def sha(path, n=None):
    h = hashlib.sha256(open(path, "rb").read()).hexdigest()
    return h[:n] if n else h


def run_variant(b, fill, order, months_keep=None):
    """The ten cells on one bar set: per cell the summary row and its monthly net and closes."""
    common, core, summarise = engine()
    tm, bid, ask = common.pseudo_ticks(b, order, True)
    tod = ((tm // 60000) % 1440).astype(np.int64)
    um, per = np.unique(common.month_id(tm), return_inverse=True)
    per = per.astype(np.int64)
    nper = len(um)
    years = um // 12
    c0 = np.zeros((0, 7))
    out = {}
    for a, x in CELLS:
        o = core.ladder(bid, ask, tod, per, nper, a / 4.0, float(a), float(x), a / 4.0 + 1, 2.0, 7, True, 0, 50,
                        False, c0, fill == "one")
        st, d, net = summarise(PAIR, o, float(a), um, years)
        dc = np.diff(np.r_[0, o[2]])
        out[(a, x)] = {"summary": st, "net": np.asarray(net, float), "closes_m": np.asarray(dc, float)}
    return um, out


def region(um, cells, keep, sens=False):
    usd = 0.0714                                          # common.USD["AUDCAD"]
    rows = []
    for k in CELLS:
        n = cells[k]["net"] - (SENS_PIPS_PER_CLOSE * usd * cells[k]["closes_m"] if sens else 0.0)
        rows.append(n)
    m = np.vstack(rows)[:, keep]
    reg = m.mean(axis=0)
    u = um[keep]
    mean = float(reg.mean())
    se = float(reg.std(ddof=1) / math.sqrt(len(reg)))
    t = mean / se if se > 0 else float("nan")
    by_year = {}
    for y in np.unique(u // 12):
        sel = (u // 12) == y
        if sel.sum() >= 6:
            by_year[int(y)] = float(reg[sel].sum())
    cells_tot = {"%d/%d" % k: float(m[i].sum()) for i, k in enumerate(CELLS)}
    return {"mean": mean, "se": se, "t": t, "months": int(len(reg)), "years": len(by_year),
            "years_pos": sum(1 for v in by_year.values() if v > 0), "by_year": by_year,
            "cells_pos": sum(1 for v in cells_tot.values() if v > 0), "cells_net": cells_tot,
            "total": float(reg.sum())}


# ---------------------------------------------------------------- s4
def check_a(insample, csvs):
    bad = 0
    b = load_bars_file(insample)
    for fill in ("cont", "one"):
        h = sha(csvs[fill], 16)
        if h != FABLE_HASH[fill]:
            print("a  %s reference %s: sha256 %s, expected %s" % (fill, csvs[fill], h, FABLE_HASH[fill]))
            bad += 1
            continue
        ref = pd.read_csv(csvs[fill])
        ref = ref[(ref["pair"] == PAIR) & (ref["path"] == "std") & (ref["mode"] == "spread")]
        um, cells = run_variant(b, fill, "std")
        for a, x in CELLS:
            kind, name = ("scan", "cap7") if x == a else ("design", "exit2a")
            r = ref[(ref["kind"] == kind) & (ref["name"] == name) & (ref["add"] == a)]
            s = cells[(a, x)]["summary"]
            if len(r) != 1:
                print("a  %s %d/%d: %d reference rows" % (fill, a, x, len(r)))
                bad += 1
                continue
            r = r.iloc[0]
            same = (int(r["closes"]) == s["closes"] and int(r["rolled_closes"]) == s["rolled_closes"]
                    and int(r["rolls"]) == s["rolls"] and abs(float(r["net_usd"]) - s["net_usd"]) < 0.005)
            bad += not same
            print("a  %-4s %2d/%2d  closes %5d/%5d  rolled %4d/%4d  rolls %5d/%5d  net %+9.2f/%+9.2f  %s"
                  % (fill, a, x, s["closes"], int(r["closes"]), s["rolled_closes"], int(r["rolled_closes"]),
                     s["rolls"], int(r["rolls"]), s["net_usd"], float(r["net_usd"]), "same" if same else "DIFFERENT"))
    return bad


def check_b():
    p = subprocess.run([sys.executable, "test_core.py"], cwd=FABLE, capture_output=True, text=True)
    for line in (p.stdout + p.stderr).strip().splitlines()[-6:]:
        print("b  " + line)
    print("b  test_core.py exit %d" % p.returncode)
    return int(p.returncode != 0)


def check_c(path):
    import common
    bad = 0
    head = open(path).readline().strip()
    for want in ("symbol=AUDCAD", "digits=5", "point=0.00001000"):
        ok = want in head.split()
        bad += not ok
        print("c  header %-18s %s" % (want, "ok" if ok else "MISSING"))
    b = load_bars_file(path)
    o, h, l, c, sp = b["o"], b["h"], b["l"], b["c"], b["sp"]
    n_bad = int(((h < l) | (o > h) | (o < l) | (c > h) | (c < l)).sum())
    n_neg = int((sp < 0).sum())
    bad += (n_bad > 0) + (n_neg > 0)
    t = pd.to_datetime(b["t"], unit="s")
    mon = (t.year * 12 + t.month - 1).values
    um, cnt = np.unique(mon, return_counts=True)
    short = [("%04d-%02d" % (u // 12, u % 12 + 1), int(k)) for u, k in zip(um, cnt) if k < MIN_BARS_MONTH]
    yrs = pd.Series(t.year).value_counts().sort_index()
    bo = common.blowout_mask(b)
    hr = t.hour.values
    print("c  bars %d, first %s, last %s; months %d; bars by year %s"
          % (len(t), t[0], t[-1], len(um), ", ".join("%d %d" % kv for kv in yrs.items())))
    print("c  OHLC inconsistent %d; negative spread %d; months under %d bars: %s"
          % (n_bad, n_neg, MIN_BARS_MONTH, short if short else "none"))
    print("c  blow-out bars %.2f%%; median recorded spread %.2f pip overall, %.2f in server hours 2-21"
          % (100 * bo.mean(), np.median(sp) / 1e-4, np.median(sp[(hr >= 2) & (hr <= 21)]) / 1e-4))
    yv = t.year.values
    for y in np.unique(yv):
        sel = yv == y
        core_h = sel & (hr >= 2) & (hr <= 21)
        print("c  %d: median spread %.2f pip (hours 2-21: %.2f), blow-out bars %.2f%% (hours 2-21: %.2f%%)"
              % (y, np.median(sp[sel]) / 1e-4, np.median(sp[core_h]) / 1e-4, 100 * bo[sel].mean(), 100 * bo[core_h].mean()))
    print("c  months dropped from the statistics (s4 c): %d" % len(short))
    return bad, [u for u, k in zip(um, cnt) if k < MIN_BARS_MONTH]


def check_d(path):
    """Fable's 01_null_calibration.py method: a +/-0.1 pip lattice walk cut into bars, four pseudo-ticks a bar,
    k steps a bar chosen so that the median bar range matches the new file's weekday bars."""
    common, core, _ = engine()
    b = slice_bars(load_bars_file(path), *DECIDE)
    m = common.weekday_mask(b["t"])
    target = float(np.median((b["h"][m] - b["l"][m]) / 1e-4))
    rng = np.random.default_rng(7)
    k, best = None, None
    for kk in (30, 40, 60, 80, 100, 120, 160, 200, 250, 300, 400, 500):
        x = np.cumsum(rng.choice(np.array([-1e-5, 1e-5]), kk * 4000))
        y = x[:(len(x) // kk) * kk].reshape(-1, kk)
        med = float(np.median((y.max(1) - y.min(1)) / 1e-4))
        if best is None or abs(med - target) < best:
            k, best = kk, abs(med - target)
    nb = 400000
    x = np.round(0.9 + np.cumsum(rng.choice(np.array([-1e-5, 1e-5]), k * nb)), 5)
    y = x[:nb * k].reshape(nb, k)
    o, h, l, c = y[:, 0], y.max(1), y.min(1), y[:, -1]
    print("d  2020-2022 median weekday bar range %.2f pips; lattice walk %d steps a bar (median range %.2f), %d bars"
          % (target, k, float(np.median((h - l) / 1e-4)), nb))
    # the truth: the same walk, tick by tick (Fable's "fine" path); the bias of the bars is bar - fine
    tod_f = np.full(len(x), 600, np.int64)
    per_f = (np.arange(len(x)) // max(len(x) // 40, 1)).astype(np.int64)
    fine = []
    for a, xx in CELLS:
        w = a / 4.0
        lo = core.ladder(x, x, tod_f, per_f, per_f[-1] + 1, w, float(a), float(xx), w + 1, 2.0, 7, True, 0, 50,
                         False, np.zeros((0, 7)), False)
        fine.append((lo[0] + lo[1])[-1] / max(lo[2][-1], 1) / a)
    del tod_f, per_f
    print("d  fine (tick by tick) gross per close, in rungs, ten cells: %s" % " ".join("%+.3f" % v for v in fine))
    for fill in ("cont", "one"):
        for order in ("std", "alt"):
            up = c >= o
            if order == "alt":
                up = ~up
            p = np.empty(4 * nb)
            p[0::4] = o
            p[1::4] = np.where(up, l, h)
            p[2::4] = np.where(up, h, l)
            p[3::4] = c
            tod = np.full(len(p), 600, np.int64)
            per = (np.arange(len(p)) // max(len(p) // 40, 1)).astype(np.int64)
            res = []
            for a, xx in CELLS:
                w = a / 4.0
                lo = core.ladder(p, p, tod, per, per[-1] + 1, w, float(a), float(xx), w + 1, 2.0, 7, True, 0, 50,
                                 False, np.zeros((0, 7)), fill == "one")
                eq = lo[0] + lo[1]
                res.append(eq[-1] / max(lo[2][-1], 1) / a)
            print("d  %s-%s gross per close, in rungs, ten cells: %s" % (fill, order, " ".join("%+.3f" % v for v in res)))
            print("d  %s-%s bias (bars - fine), in rungs:         %s"
                  % (fill, order, " ".join("%+.3f" % (v - f) for v, f in zip(res, fine))))
    return 0


def selfcheck(args):
    insample, new, ccont, cone = args
    fails = {"a": check_a(insample, {"cont": ccont, "one": cone}), "b": check_b()}
    fails["c"], _ = check_c(new)
    check_d(new)
    print("SELFCHECK: " + ", ".join("%s %s" % (k, "PASS" if v == 0 else "FAIL (%d)" % v) for k, v in fails.items())
          + ", d DONE")


# ---------------------------------------------------------------- the result
def oos(args):
    (new,) = args
    p = subprocess.run(["git", "-C", REPO, "show", "origin/main:research/audcad_oos/selfcheck_out.txt"],
                       capture_output=True, text=True)
    if p.returncode != 0 or not gate_ok(p.stdout):
        sys.exit("OOS|REFUSED|selfcheck_out.txt is not on origin/main or does not read all PASS (PREREG s8)")
    _, short = check_c(new)
    full = load_bars_file(new)
    res = {}
    for label, (y0, y1) in (("2020-2022 (decides)", DECIDE), ("2018-2019 (reported only)", REPORT)):
        b = slice_bars(full, y0, y1)                     # from flat at the first bar of y0 (s2a)
        res[label] = {}
        print("== %s: %d bars" % (label, len(b["t"])))
        for fill, order in VARIANTS:
            um, cells = run_variant(b, fill, order)
            keep = ~np.isin(um, short)
            base = region(um, cells, keep)
            sens = region(um, cells, keep, sens=True)
            res[label]["%s-%s" % (fill, order)] = {
                "base": base, "sens": sens,
                "cells": {"%d/%d" % k: {kk: (float(vv) if isinstance(vv, (int, float, np.floating, np.integer)) else vv)
                                        for kk, vv in cells[k]["summary"].items()} for k in CELLS}}
            print("%-9s region %+7.2f USD/month (se %.2f, t %+.2f) over %d months; years +%d of %d %s; cells +%d of 10"
                  % ("%s-%s" % (fill, order), base["mean"], base["se"], base["t"], base["months"], base["years_pos"],
                     base["years"], {k: round(v, 1) for k, v in base["by_year"].items()}, base["cells_pos"]))
            print("%-9s  sens %+7.2f USD/month (t %+.2f); years +%d of %d; cells +%d of 10"
                  % ("", sens["mean"], sens["t"], sens["years_pos"], sens["years"], sens["cells_pos"]))
    d = res["2020-2022 (decides)"]["cont-std"]
    verdict = decide(d["base"], d["sens"])
    res["VERDICT"] = verdict
    print("VERDICT (cont-std, PREREG s6): %s" % verdict)
    json.dump(res, open(os.path.join(HERE, "oos_result.json"), "w"), indent=1, default=str)


if __name__ == "__main__":
    if sys.argv[1] == "--selfcheck":
        selfcheck(sys.argv[2:])
    elif sys.argv[1] == "--oos":
        oos(sys.argv[2:])
    else:
        sys.exit(__doc__)
