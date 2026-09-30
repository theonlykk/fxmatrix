"""Cap sensitivity (study s9): replay every side at its actual cap, check it
against the ledger (s9.2), then replay caps 5-10 for the instances that
pass and print a frontier table (s9.3). Plus the named cases' depth read
(s9.4).

    python research/ejection_value/ev_caps.py --export FILE [FILE ...] \
        --bars DIR [--bars DIR ...] [--caps 5,6,7,8,9,10] [--depth-at 2026-09-30T01:40]

Reads files and prints; writes nothing anywhere.
"""
import argparse
import collections
import datetime as _dt
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from ev_book import build_layers, depth_timelines, mark_ejections  # noqa: E402
from ev_data import (filter_by_account, fleet_of, load_bars_dir, load_export,  # noqa: E402
                     parse_utc, symbol_of)
from ev_replay import (SideReplay, actual_totals, fleet_day_metrics,  # noqa: E402
                       geometry_timeline, ledger_money, peak_slots, reconciled, run_pair)

DEFAULT_ALIAS = {53066709: 53071896}     # box 1 has no bar dump of its own; same server
SLOT_GUARD = 194


def _f(x, nd=2):
    return "-" if x is None else ("%.*f" % (nd, x) if isinstance(x, float) else str(x))


def _ts(t):
    return _dt.datetime.fromtimestamp(t, _dt.timezone.utc).strftime("%m-%d %H:%M")


def instance_accounts(ex):
    first = {}
    for r in ex.get("config_events", []):
        if r.get("event") != "INIT" or not r.get("account_login"):
            continue
        t = parse_utc(r["received_at"])
        k = r["instance_id"]
        if k not in first or t < first[k][0]:
            first[k] = (t, int(r["account_login"]))
    return first       # {instance: (first INIT on the current account, account)}


def replay_instance(inst, bars, tl, v, comm, t0, t1, cap=None):
    i0 = bars.index_at_or_after(t0)
    i1 = bars.index_at_or_after(t1)
    lo = SideReplay(True, bars, tl, v, comm, cap_override=cap)
    sh = SideReplay(False, bars, tl, v, comm, cap_override=cap)
    run_pair(lo, sh, i0, i1)
    return {"L": lo, "S": sh}


def run(export_paths, bars_dirs, caps, depth_at, out=sys.stdout):
    w = lambda s="": print(s, file=out)  # noqa: E731
    raw = load_export(export_paths)
    ex, dropped = filter_by_account(raw)
    layers = build_layers(ex)
    mark_ejections(layers, ex)
    bars = {}
    for d in bars_dirs:
        bars.update(load_bars_dir(d))
    starts = instance_accounts(ex)
    fills = ex.get("fill_logs", [])
    t_export = max(parse_utc(r["received_at"]) for r in fills)

    w("CAP SENSITIVITY (study s9) -- first-order replay on M1 bars")
    w("exports: %s; rows dropped (other accounts / unknown sessions): %s"
      % (", ".join(os.path.basename(p) for p in export_paths), dropped or "none"))
    w("bars: %s" % ", ".join("%s/%s %d" % (a, s, len(b)) for (a, s), b in sorted(bars.items())))
    w()

    rec = {}
    w("== RECONCILIATION at the actual cap (s9.2): replay vs ledger, both sides")
    w("  %-18s %-11s %-11s %5s %5s %4s %4s %8s %8s %6s %6s  %s" % (
        "instance", "from", "to", "sc_r", "sc_a", "ej_r", "ej_a", "net_r", "net_a", "v", "comm", "verdict"))
    for inst in sorted(starts):
        t_start, acct = starts[inst]
        b = bars.get((DEFAULT_ALIAS.get(acct, acct), symbol_of(inst)))
        tl = geometry_timeline(ex, inst)
        v, comm = ledger_money(layers.get(inst, {}))
        if b is None or not tl or v is None or comm is None:
            w("  %-18s skipped: %s" % (inst[6:], "no bars" if b is None else
                                         "no geometry" if not tl else "no ledger money"))
            continue
        t_end = min(b.to_utc, t_export)
        if t_start < b.t[0]:
            w("  %-18s skipped: bars start %s after the instance %s" % (inst[6:], _ts(b.t[0]), _ts(t_start)))
            continue
        sides = replay_instance(inst, b, tl, v, comm, t_start, t_end)
        r_tot = collections.Counter()
        a_tot = collections.Counter()
        for sd, rp in sides.items():
            for k2, x in rp.totals().items():
                if k2 in ("scalps", "ejections", "closed_net"):
                    r_tot[k2] += x
            for k2, x in actual_totals(layers.get(inst, {}), sd, t_start, t_end).items():
                a_tot[k2] += x
        r_tot = dict(r_tot, closed_net=float(r_tot["closed_net"]))
        a_tot = dict(a_tot, closed_net=float(a_tot["closed_net"]))
        ok, why = reconciled(r_tot, a_tot)
        rec[inst] = {"ok": ok, "bars": b, "tl": tl, "v": v, "comm": comm,
                     "t0": t_start, "t1": t_end, "acct": acct}
        w("  %-18s %-11s %-11s %5d %5d %4d %4d %8s %8s %6s %6s  %s" % (
            inst[6:], _ts(t_start), _ts(t_end), r_tot["scalps"], a_tot["scalps"],
            r_tot["ejections"], a_tot["ejections"], _f(r_tot["closed_net"]), _f(a_tot["closed_net"]),
            _f(v, 0), _f(comm), "RECONCILED" if ok else "NOT: " + "; ".join(why)))
    w()

    w("== FRONTIER per instance (reconciled only; add, exit, width unchanged)")
    w("  %-18s %4s %8s %6s %5s %8s %5s %5s %8s" % (
        "instance", "cap", "closed", "scalps", "ej", "ej$", "maxd", "open", "mtm_end"))
    fleet_series = collections.defaultdict(lambda: collections.defaultdict(dict))
    for inst in sorted(rec):
        R = rec[inst]
        if not R["ok"]:
            continue
        for cap in caps:
            sides = replay_instance(inst, R["bars"], R["tl"], R["v"], R["comm"], R["t0"], R["t1"], cap)
            tot = collections.Counter()
            md = 0
            for sd, rp in sides.items():
                t = rp.totals()
                for k2 in ("closed_net", "scalps", "ejections", "eject_net", "open_layers", "mtm_end"):
                    tot[k2] += t[k2]
                md = max(md, t["max_depth"])
                fleet_series[(fleet_of(inst), cap)][(inst, sd)] = rp
            w("  %-18s %4d %8s %6d %5d %8s %5d %5d %8s" % (
                inst[6:], cap, _f(float(tot["closed_net"])), tot["scalps"], tot["ejections"],
                _f(float(tot["eject_net"])), md, tot["open_layers"], _f(float(tot["mtm_end"]))))
    w()

    w("== FRONTIER per fleet (reconciled instances only; FTMO day rolls 22:00Z)")
    w("  %-5s %4s %4s %9s %10s %10s %10s %6s" % (
        "fleet", "cap", "n", "closed", "worst_day", "worst_carr", "mean_carr", "slots"))
    for (fleet, cap) in sorted(fleet_series):
        sides = fleet_series[(fleet, cap)]
        n_inst = len({k[0] for k in sides})
        t0 = min(rp.mtm[0][0] for rp in sides.values() if rp.mtm)
        t1 = max(rp.mtm[-1][0] for rp in sides.values() if rp.mtm)
        days = fleet_day_metrics({k: rp.mtm for k, rp in sides.items()},
                                 {k: [(t, p) for t, _k, p in rp.events] for k, rp in sides.items()},
                                 t0, t1)
        closed = sum(p for rp in sides.values() for _t, _k, p in rp.events)
        worst = min(d[2] for d in days) if days else None
        carr = [d[1] for d in days[1:]] if len(days) > 1 else []
        slots = peak_slots([rp.slots for rp in sides.values()])
        w("  %-5s %4d %4d %9s %10s %10s %10s %6d%s" % (
            fleet, cap, n_inst, _f(closed), _f(worst), _f(min(carr) if carr else None),
            _f(sum(carr) / len(carr) if carr else None), slots,
            "  > guard %d" % SLOT_GUARD if slots > SLOT_GUARD else ""))
    w("  worst_day: the lowest (closed since the day's 22:00Z roll + open MTM) on any day;")
    w("  carr: open MTM carried into each roll (the first day excluded: it starts flat).")
    w("  The slot count covers ONLY the reconciled instances of that fleet.")
    w()

    for when in depth_at:
        t = parse_utc(when if "+" in when else when + "+00:00")
        tls = depth_timelines(layers, min(s[0] for s in starts.values()), t_export)
        w("== DEPTH AT %s UTC (actual book, s9.4)" % when)
        rows = collections.defaultdict(dict)
        for (inst, sd), tl in tls.items():
            tag = "alt" if inst.rsplit("_", 1)[-1].startswith("ALT") else ""
            rows[symbol_of(inst)][(fleet_of(inst), tag, sd)] = tl.depth_before(t)
        for sym in sorted(rows):
            cells = ["%s%s %s=%d" % (f, ("/" + tag) if tag else "", sd, d)
                     for (f, tag, sd), d in sorted(rows[sym].items())]
            w("  %-7s %s" % (sym, "  ".join(cells)))
        w()
    return 0


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--export", nargs="+", required=True)
    ap.add_argument("--bars", action="append", default=[])
    ap.add_argument("--caps", default="5,6,7,8,9,10")
    ap.add_argument("--depth-at", action="append", default=[])
    a = ap.parse_args(argv)
    return run(a.export, a.bars, [int(x) for x in a.caps.split(",")], a.depth_at)


if __name__ == "__main__":
    sys.exit(main())
