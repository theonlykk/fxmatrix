"""Compass round scoring on EQUITY (operator 7 Oct ~14:53Z; compass-round s4.4
amendment, from round 2). Read-only analysis of files; standard library only.
compass_score.py (the realised scorer) is imported, never changed: its loader,
windows, cuts, pip values and verdict table stay as they are and its realised
margin is reported beside the equity one.

    python research/compass/equity_score.py --export <archive or study export.jsonl>... \
        --round research/compass/round2.json --bidask <IC bid/ask folder>
    python -m unittest research/compass/test_equity_score.py -v

Why (HANDOFF s64, 7 Oct): with re-roll ON the timing of a realised loss is set
by each fleet's inherited book, not by the probe's lever (EURUSD long B vs C:
scalps alike, realised apart by an old layer closing on one fleet only). On
equity an inherited loss realised inside the round nets out against the open
MTM it already carried at the start.

Per instance side and window (a, b):
  change = cash + mark(b) - mark(a)
  cash   = for layers opened in [a, b): their open commission;
           for layers closed in [a, b): closeby_net + exit commission
  mark(t)= open MTM of the side's layers open at the end of the minute that ends
           at t (the bar opening at t - 60), both sides at the MID close (the
           boundaries fall at 22:00Z: the minute 21:59 is in IC's rollover hour,
           and bid / ask marks would put that spread into each side in
           proportion to its depth; holdout T3c marks at the mid too), pips x
           USD per pip (compass_score.pip_values).
Score = sum of the windows' changes / the windows' days. Verdict: margin =
probe - comparator per day; WIN above the threshold, LOSE below minus it, else
REPEAT; no add-probe gates (they guarded realised artefacts). A side with an
unpriced layer (no open price) at a mark is UNPRICED: export more history
(--export-archive). Threshold: GC-1 = max(the round file's threshold, the
median of the control pair's six same-settings EQUITY gaps). Cuts as
compass_score (scored before the cut if >= min_days_after_cut, else VOID).
Known small error: accrued swap is in the close (cash) but not in the marks
(cents a night at 0.01).
"""
import argparse
import datetime as dt
import os
import statistics
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "ejection_value"))
import compass_score as cs  # noqa: E402
import ev_data  # noqa: E402

EPS = 1e-9
SIDES = ("L", "S")


def mark_side(layers, inst, side, t, bars, pv):
    """(usd, unpriced) for the side's layers open at the end of the minute that
    ends at t, marked at that minute's mid close. (None, 0) when no bar opens
    before t."""
    i = bars.index_at_or_after(t) - 1
    if i < 0:
        return None, 0
    tm = bars.t[i] + 59
    pips, unpriced = 0.0, 0
    for lay in layers.get(inst, {}).values():
        if lay.side != side:
            continue
        start = lay.open_t if lay.open_t is not None else float("-inf")
        if not (start <= tm and (not lay.closed or lay.close_t > tm)):
            continue
        if lay.open_price is None:
            unpriced += 1
            continue
        mid = (bars.c[i] + bars.ask_close(i)) / 2.0
        if side == "L":
            pips += (mid - lay.open_price) / bars.pip
        else:
            pips += (lay.open_price - mid) / bars.pip
    return pips * pv, unpriced


def _cash(layers, inst, side, a, b):
    usd = 0.0
    for lay in layers.get(inst, {}).values():
        if lay.side != side:
            continue
        if lay.open_t is not None and a <= lay.open_t < b:
            usd += lay.open_commission or 0.0
        if lay.closed and a <= lay.close_t < b:
            usd += (lay.closeby_net or 0.0) + (lay.exit_commission or 0.0)
    return usd


def equity_side(layers, inst, side, windows, bars, pv):
    days = sum(d for _a, _b, d in windows)
    change, cash, unpriced, marks = 0.0, 0.0, 0, []
    for a, b, _d in windows:
        c = _cash(layers, inst, side, a, b)
        m0, u0 = mark_side(layers, inst, side, a, bars, pv)
        m1, u1 = mark_side(layers, inst, side, b, bars, pv)
        unpriced = max(unpriced, u0, u1)
        if m0 is None or m1 is None:
            return {"change": None, "per_day": None, "cash": None, "unpriced": unpriced,
                    "marks": marks, "days": days, "nobars": True}
        cash += c
        change += c + m1 - m0
        marks.append((m0, m1))
    return {"change": change, "per_day": change / days if days else 0.0, "cash": cash,
            "unpriced": unpriced, "marks": marks, "days": days}


def round_span(cfg):   # STUB (tests first, cohort)
    return None


def cohort_side(layers, inst, side, start, end, bars, pv, days):   # STUB
    return {"value": None, "per_day": None, "n": None, "unpriced": None, "layer_hours": None}


def decide_equity(probe_per_day, comp_per_day, threshold):
    margin = probe_per_day - comp_per_day
    if margin > threshold + EPS:
        return "WIN", margin
    if margin < -threshold - EPS:
        return "LOSE", margin
    return "REPEAT", margin


def control_threshold_equity(cfg, layers, bars_by_pair, pv_by_pair):
    ctrl = cfg.get("control")
    base = float(cfg["threshold"])
    if not ctrl:
        return {"median": None, "gc1": base, "gaps": [], "void": [], "base": base}
    windows = cs.windows_of(cfg)
    min_days = float(cfg.get("min_days_after_cut", 1.0))
    pair, inst = ctrl["pair"], ctrl["instances"]
    bars, pv = bars_by_pair.get(pair), pv_by_pair.get(pair, 0.0)
    gaps, void = [], []
    for side in SIDES:
        for x, y in cs.CONTROL_FLEET_PAIRS:
            cut = cs.cut_for(cfg, pair, side, {x, y})
            win = cs.cut_windows(windows, cut)
            days = sum(d for _a, _b, d in win)
            if cut is not None and days < min_days - EPS:
                void.append((side, "%s-%s" % (x, y)))
                continue
            ex = equity_side(layers, inst[x], side, win, bars, pv) if bars else None
            ey = equity_side(layers, inst[y], side, win, bars, pv) if bars else None
            if not ex or not ey or ex["per_day"] is None or ey["per_day"] is None \
                    or ex["unpriced"] or ey["unpriced"]:
                void.append((side, "%s-%s" % (x, y)))
                continue
            gaps.append({"side": side, "fleets": "%s-%s" % (x, y),
                         "gap": abs(ex["per_day"] - ey["per_day"]),
                         "x": ex["per_day"], "y": ey["per_day"]})
    median = statistics.median([g["gap"] for g in gaps]) if gaps else None
    return {"median": median, "gc1": max(base, median) if median is not None else base,
            "gaps": gaps, "void": void, "base": base, "pair": pair}


def bars_by_pair(cfg, bidask):
    accounts = set(cfg["accounts"].values())
    out = {}
    for (acct, sym), b in sorted(bidask.items(), key=lambda kv: kv[0][0] not in accounts):
        out.setdefault(sym, b)
    return out


def score_round_equity(cfg, layers, bidask, pv=None):
    windows = cs.windows_of(cfg)
    min_days = float(cfg.get("min_days_after_cut", 1.0))
    bp = bars_by_pair(cfg, bidask)
    if pv is None:
        pv = cs.pip_values(layers, {s: b.pip for s, b in bp.items()})
    control = control_threshold_equity(cfg, layers, bp, pv)
    thr = control["gc1"]
    rows = []
    for pair, spec in cfg["pairs"].items():
        bars, pvp = bp.get(pair), pv.get(pair, 0.0)
        for side in SIDES:
            row = {"pair": pair, "side": side, "anchor": spec["anchor"], "probes": {},
                   "anchor_eq": equity_side(layers, spec["anchor"], side, windows, bars, pvp)
                   if bars else None}
            for fleet in ("C", "D"):
                if fleet not in spec:
                    continue
                p = spec[fleet]
                comp_inst = p.get("primary", spec["anchor"])
                comp_fleet = fleet if "primary" in p else "B"
                cut = cs.cut_for(cfg, pair, side, {fleet, comp_fleet})
                win = cs.cut_windows(windows, cut)
                days_used = sum(d for _a, _b, d in win)
                pe = equity_side(layers, p["probe"], side, win, bars, pvp) if bars else None
                ce = equity_side(layers, comp_inst, side, win, bars, pvp) if bars else None
                cutoff = cs.utc(cfg["reloads"][p["probe"]]) if p["probe"] in cfg.get("reloads", {}) \
                    else windows[0][0]
                pm = cs.side_metrics(layers, p["probe"], side, win, cutoff)
                cm = cs.side_metrics(layers, comp_inst, side, win, cutoff)
                out = {"probe": p["probe"], "lever": p["lever"], "comparator": comp_inst,
                       "threshold": thr, "realised_margin": pm["per_day"] - cm["per_day"],
                       "probe_eq": pe, "comp_eq": ce, "days_used": days_used, "cut": cut}
                if cut is not None and days_used < min_days - EPS:
                    out.update(verdict="VOID", margin=None)
                elif pe is None or ce is None or pe["per_day"] is None or ce["per_day"] is None:
                    out.update(verdict="NOBARS", margin=None)
                elif pe["unpriced"] or ce["unpriced"]:
                    out.update(verdict="UNPRICED", margin=None)
                else:
                    v, m = decide_equity(pe["per_day"], ce["per_day"], thr)
                    out.update(verdict=v, margin=m)
                row["probes"][fleet] = out
            wins = [(v["margin"], f) for f, v in row["probes"].items() if v["verdict"] == "WIN"]
            row["promote"] = max(wins)[1] if wins else None
            rows.append(row)
    return {"control": control, "rows": rows, "pv": pv}


def _f(x):
    return "      -" if x is None else "%+7.2f" % x


def report(cfg, exp, res, out=sys.stdout):
    p = lambda *a: print(*a, file=out)  # noqa: E731
    windows = cs.windows_of(cfg)
    end = max(b for _a, b, _d in windows)
    last = max((ev_data.broker_msc_to_utc(r["deal_time_broker_msc"], 10800)
                for r in exp.get("fill_logs", []) if r.get("deal_time_broker_msc")), default=0)
    p("== %s: EQUITY (realised + change in open MTM), per day; windows %s ==" % (
        cfg.get("round", "round"), ", ".join("%s->%s" % (a, b) for a, b, _d in cfg["windows"])))
    if last < end:
        p("!! fills end %s, before the round ends (%s): on a Friday this is the close; "
          "otherwise provisional" % (dt.datetime.fromtimestamp(last, dt.timezone.utc).strftime("%Y-%m-%d %H:%MZ"),
                                     dt.datetime.fromtimestamp(end, dt.timezone.utc).strftime("%Y-%m-%d %H:%MZ")))
    c = res["control"]
    p("threshold GC-1 %.2f = max(%.2f, median %s of %d %s equity gaps; void %s)" % (
        c["gc1"], c["base"], "-" if c["median"] is None else "%.2f" % c["median"], len(c["gaps"]),
        c.get("pair", "-"), c.get("void")))
    for g in c["gaps"]:
        p("   control %s %s: %+.2f vs %+.2f -> gap %.2f" % (g["side"], g["fleets"], g["x"], g["y"], g["gap"]))
    p("pair   side anchor | C eq    margin  verdict  (realised margin) | D eq    margin  verdict  (realised margin) | promote")
    for r in res["rows"]:
        a = r["anchor_eq"]["per_day"] if r["anchor_eq"] else None
        cols = []
        for f in ("C", "D"):
            v = r["probes"].get(f)
            if v is None:
                cols.append("%-50s" % "      -")
                continue
            pe = v["probe_eq"]["per_day"] if v["probe_eq"] else None
            cols.append("%s %s %-8s (%+.2f)" % (_f(pe), _f(v["margin"]), v["verdict"], v["realised_margin"]))
        p("%-6s %-4s %s | %s | %s | %s" % (r["pair"], r["side"], _f(a), cols[0], cols[1], r["promote"] or "-"))


def main(argv=None):
    ap = argparse.ArgumentParser(description="compass round scored on equity (realised + change in open MTM)")
    ap.add_argument("--export", action="append", required=True)
    ap.add_argument("--round", required=True)
    ap.add_argument("--bidask", required=True, help="grind_bidask_dump.mq5 folder (IC)")
    args = ap.parse_args(argv)
    cfg = cs.load_round(args.round)
    exp, layers = cs.load(args.export, list(cfg["accounts"].values()))
    res = score_round_equity(cfg, layers, ev_data.load_bidask_dir(args.bidask))
    report(cfg, exp, res)
    return 0


if __name__ == "__main__":
    sys.exit(main())
