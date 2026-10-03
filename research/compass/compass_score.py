"""Compass round scoring (backlog C91; docs/architecture/fleet-d.md s6.5 as
amended by s6.8). Read-only analysis of files; standard library only
(Python 3.9+). Reuses the ejection study's export loader and layer builder
(research/ejection_value, replay v1: imported, never changed); its fleet
table does not know Fleet D, so accounts are passed explicitly here.

    python research/compass/compass_score.py --export <study_export.jsonl>... --round research/compass/round1.json

Per pair and side, for each probe fleet (C: add, D: exit):
- score = closed net per day: every layer CLOSED inside the round's windows
  (scalps + rolls + ejections; profit + swap + commission, all-in from the
  ledger), divided by the windows' days;
- comparator = the twin's own primary on the same account when the probe is a
  twin (it DECIDES, Gemini GD1-3), else the anchor (Fleet B) on the same side;
  the margin vs the anchor is always reported (cross_margin);
- verdict: WIN if the margin is MORE than the threshold, LOSE if less than
  minus it, else REPEAT (the same probe again; pool the rounds' windows);
- ADD probes have two gates before a WIN (GD1-4, GD1-5): the entry-time split
  (layers opened at or after the probe's reload) must not lose by more than
  the threshold, and closed net per layer-hour must be no worse; else
  REPEAT_GATE;
- promote: the WIN with the larger margin (one lever moves per round).
Reported, never deciding: entry split, layer-hours, open layers at the end,
depth at the reload.
Cuts (operator 3 Oct, Gemini GC-4 amended): a hand intervention listed in the
round file (pair, side, fleet, at) cuts every comparison involving that fleet
on that pair-side: it is scored on the windows before the first such
intervention if at least min_days_after_cut (default 1.0) days remain, else
VOID. Fleet-wide changes made alike on all fleets are not listed.
"""
import argparse
import datetime as dt
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "ejection_value"))
import ev_book  # noqa: E402
import ev_data  # noqa: E402

EPS = 1e-9
SIDES = ("L", "S")


def utc(text):
    """'2026-10-01T22:00Z' or '2026-10-01T06:19:13Z' -> epoch seconds."""
    fmt = "%Y-%m-%dT%H:%M:%SZ" if text.count(":") == 2 else "%Y-%m-%dT%H:%MZ"
    return dt.datetime.strptime(text, fmt).replace(tzinfo=dt.timezone.utc).timestamp()


def load_round(path):
    with open(path) as fh:
        return json.load(fh)


def windows_of(cfg):
    return [(utc(a), utc(b), int(d)) for a, b, d in cfg["windows"]]


def load(paths, accounts):
    """Export rows of the given accounts only (session -> account), then layers."""
    raw = ev_data.load_export(paths)
    exp, _dropped = ev_data.filter_by_account(raw, accounts=accounts)
    layers = ev_book.build_layers(exp)
    ev_book.mark_ejections(layers, exp)
    return exp, layers


def cut_windows(windows, cut):
    """Windows truncated at `cut` (epoch s; None = no cut). A window that
    ends after the cut keeps its part before it, counted in fractional days;
    windows starting at or after the cut are dropped."""
    if cut is None:
        return list(windows)
    out = []
    for a, b, d in windows:
        if cut <= a:
            continue
        if cut >= b:
            out.append((a, b, d))
        else:
            out.append((a, cut, (cut - a) / 86400.0))
    return out


def cut_for(cfg, pair, side, fleets):
    """Earliest listed intervention on this pair-side on any of `fleets`."""
    ts = [utc(i["at"]) for i in cfg.get("interventions", [])
          if i["pair"] == pair and i["side"] == side and i["fleet"] in fleets]
    return min(ts) if ts else None


def _in_windows(t, windows):
    return any(a <= t < b for a, b, _d in windows)


def side_metrics(layers, inst, side, windows, entry_cutoff):
    days = sum(d for _a, _b, d in windows)
    end = max((b for _a, b, _d in windows), default=entry_cutoff)
    m = {"scalps": 0, "rolls": 0, "ejections": 0, "net": 0.0, "entry_net": 0.0,
         "layer_hours": 0.0, "open_end": 0, "depth_at_cutoff": 0, "days": days}
    for lay in layers.get(inst, {}).values():
        if lay.side != side:
            continue
        start = lay.open_t if lay.open_t is not None else float("-inf")
        stop = lay.close_t if lay.closed else float("inf")
        if lay.closed and _in_windows(lay.close_t, windows):
            n = lay.net()
            m["net"] += n
            if lay.rolled:
                m["rolls"] += 1
            elif lay.ejected:
                m["ejections"] += 1
            else:
                m["scalps"] += 1
            if lay.open_t is not None and lay.open_t >= entry_cutoff:
                m["entry_net"] += n
        for a, b, _d in windows:
            lo, hi = max(a, start), min(b, stop)
            if hi > lo:
                m["layer_hours"] += (hi - lo) / 3600.0
        if start < end and stop >= end:
            m["open_end"] += 1
        if start <= entry_cutoff < stop:
            m["depth_at_cutoff"] += 1
    m["per_day"] = m["net"] / days if days else 0.0
    m["entry_per_day"] = m["entry_net"] / days if days else 0.0
    m["per_hour"] = m["net"] / m["layer_hours"] if m["layer_hours"] > 0 else None
    return m


def threshold_for(cfg, pair, side, twin):
    base = float(cfg["threshold"])
    if not twin:
        return base
    return max(base, float(cfg.get("twin_thresholds", {}).get("%s|%s" % (pair, side), 0.0)))


def decide(probe, comp, threshold, lever):
    """Returns (verdict, margin, gate_note)."""
    margin = probe["per_day"] - comp["per_day"]
    if margin > threshold + EPS:
        if lever == "add":
            entry_margin = probe["entry_per_day"] - comp["entry_per_day"]
            if entry_margin < -threshold - EPS:
                return "REPEAT_GATE", margin, "entry split %+.2f" % entry_margin
            ph, ch = probe.get("per_hour"), comp.get("per_hour")
            if ph is not None and ch is not None and ph < ch - EPS:
                return "REPEAT_GATE", margin, "per layer-hour %.4f < %.4f" % (ph, ch)
        return "WIN", margin, ""
    if margin < -threshold - EPS:
        return "LOSE", margin, ""
    return "REPEAT", margin, ""


def score_round(cfg, layers):
    windows = windows_of(cfg)
    min_days = float(cfg.get("min_days_after_cut", 1.0))
    rows = []
    for pair, spec in cfg["pairs"].items():
        for side in SIDES:
            row = {"pair": pair, "side": side, "anchor": spec["anchor"], "probes": {}}
            # the anchor over the whole round (no cut), for the table's anchor column
            row["anchor_full"] = side_metrics(layers, spec["anchor"], side, windows,
                                              windows[0][0])
            for fleet in ("C", "D"):
                if fleet not in spec:
                    continue
                p = spec[fleet]
                cutoff = utc(cfg["reloads"][p["probe"]])
                twin = "primary" in p
                comp_fleet = fleet if twin else "B"
                cut = cut_for(cfg, pair, side, {fleet, comp_fleet})
                win_c = cut_windows(windows, cut)
                days_used = sum(d for _a, _b, d in win_c)
                pm = side_metrics(layers, p["probe"], side, win_c, cutoff)
                # the cross margin vs the anchor uses the cut of (probe fleet, B)
                win_a = cut_windows(windows, cut_for(cfg, pair, side, {fleet, "B"}))
                am = side_metrics(layers, spec["anchor"], side, win_a, cutoff)
                comp_inst = p["primary"] if twin else spec["anchor"]
                cm = side_metrics(layers, comp_inst, side, win_c, cutoff)
                thr = threshold_for(cfg, pair, side, twin)
                verdict, margin, note = decide(pm, cm, thr, p["lever"])
                if cut is not None:
                    if days_used < min_days - EPS:
                        verdict = "VOID"
                    note = ("cut %s, %.2f d used" % (
                        dt.datetime.fromtimestamp(cut, dt.timezone.utc).strftime("%a %H:%M:%SZ"),
                        days_used) + ("; " + note if note else ""))
                row["probes"][fleet] = {"probe": p["probe"], "lever": p["lever"],
                                        "comparator": comp_inst, "threshold": thr,
                                        "verdict": verdict, "margin": margin, "note": note,
                                        "cut": cut, "days_used": days_used,
                                        "cross_margin": pm["per_day"] - am["per_day"],
                                        "probe_m": pm, "comp_m": cm, "anchor_m": am}
            wins = [(v["margin"], f) for f, v in row["probes"].items() if v["verdict"] == "WIN"]
            row["promote"] = max(wins)[1] if wins else None
            rows.append(row)
    return rows


def _fmt_m(m):
    ph = "%.3f" % m["per_hour"] if m["per_hour"] is not None else "-"
    return "%6.2f/d (sc %d ro %d ej %d; entry %6.2f/d; %5.1f lh, %s $/lh; open %d; depth@reload %d)" % (
        m["per_day"], m["scalps"], m["rolls"], m["ejections"], m["entry_per_day"],
        m["layer_hours"], ph, m["open_end"], m["depth_at_cutoff"])


def report(cfg, exp, rows, out=sys.stdout):
    windows = windows_of(cfg)
    last_fill = max((ev_data.broker_msc_to_utc(r["deal_time_broker_msc"], ev_book.DEFAULT_OFFSET_S)
                     for r in exp.get("fill_logs", [])), default=0)
    end = max(b for _a, b, _d in windows)
    p = lambda s="": print(s, file=out)  # noqa: E731
    p("== %s: windows %s; days %d ==" % (cfg.get("round", "round"),
      ", ".join("%s->%s" % (a, b) for a, b, _d in cfg["windows"]), sum(d for *_x, d in windows)))
    if last_fill < end:
        p("!! DATA ENDS %s, BEFORE THE ROUND ENDS (%s): provisional, not a verdict" % (
            dt.datetime.fromtimestamp(last_fill, dt.timezone.utc).strftime("%Y-%m-%d %H:%MZ"),
            dt.datetime.fromtimestamp(end, dt.timezone.utc).strftime("%Y-%m-%d %H:%MZ")))
    p("%-7s %s | %-8s | %-6s %-11s %7s %7s %5s | %-6s %-11s %7s %7s %5s | promote" % (
        "pair", "s", "anchor/d", "C add", "verdict", "margin", "cross", "thr",
        "D exit", "verdict", "margin", "cross", "thr"))
    for r in rows:
        cells = []
        for f in ("C", "D"):
            v = r["probes"].get(f)
            if not v:
                cells.append("%-6s %-11s %7s %7s %5s" % ("-", "", "", "", ""))
                continue
            cells.append("%6.2f %-11s %+7.2f %+7.2f %5.2f" % (
                v["probe_m"]["per_day"], v["verdict"], v["margin"], v["cross_margin"], v["threshold"]))
        anchor = r["anchor_full"]["per_day"]
        p("%-7s %s | %8.2f | %s | %s | %s" % (r["pair"], r["side"], anchor, cells[0], cells[1],
                                            r["promote"] or "anchor stays"))
    p()
    p("== detail (per instance side; margins vs the comparator named) ==")
    for r in rows:
        for f, v in r["probes"].items():
            p("%s %s %s %-18s %s" % (r["pair"], r["side"], f, v["probe"], _fmt_m(v["probe_m"])))
            p("%s %s %s %-18s %s%s" % (r["pair"], r["side"], f, "vs " + v["comparator"], _fmt_m(v["comp_m"]),
                                      ("  [" + v["note"] + "]") if v["note"] else ""))


def main(argv=None):
    ap = argparse.ArgumentParser(description="Compass round scoring (C91)")
    ap.add_argument("--export", required=True, action="append")
    ap.add_argument("--round", default=os.path.join(HERE, "round1.json"))
    args = ap.parse_args(argv)
    cfg = load_round(args.round)
    exp, layers = load(args.export, list(cfg["accounts"].values()))
    report(cfg, exp, score_round(cfg, layers))


if __name__ == "__main__":
    main()
