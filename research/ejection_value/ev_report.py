"""Run the ejection value study and print a plain-text report.

    python research/ejection_value/ev_report.py \
        --export study_export_A.jsonl [study_export_B.jsonl ...] \
        --bars DIR [--bars DIR ...] [--alias 53066709=53071896] [--horizons 24,48]

--export  one or more `archive_counts.py --export-study` files (overlaps are
          de-duplicated).
--bars    directories holding bars_<login>_<SYM>.csv (searched recursively).
--alias   use another account's bars (same server): Fleet B's IC account
          53066709 has no dump of its own; box 2's 53071896 is the same
          server (ICMarketsSC-Demo). This alias is the default.
Nothing here writes to any system; it reads files and prints.
"""
import argparse
import collections
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from ev_book import (DEFAULT_OFFSET_S, build_layers, calibrate_hidden, caps_by_instance,  # noqa: E402
                     depth_timelines, eject_anchors, mark_ejections, side_stats)
from ev_controls import f_per_hour, pair_controls  # noqa: E402
from ev_data import (filter_by_account, fleet_of, load_bars_dir, load_export,  # noqa: E402
                     parse_utc, symbol_of)
from ev_episodes import (build_chains, carry_rates, collect_ejections,  # noqa: E402
                         counterfactual, score_chain)

DEFAULT_ALIAS = {53066709: 53071896}


def _fmt(x, nd=2):
    if x is None:
        return "-"
    if isinstance(x, float):
        return ("%." + str(nd) + "f") % x
    return str(x)


def account_by_instance(export):
    out = {}
    for r in export.get("config_events", []):
        if r.get("account_login"):
            out[r["instance_id"]] = int(r["account_login"])
    return out


def run(export_paths, bars_dirs, aliases, horizons, out=sys.stdout):
    ex, dropped = filter_by_account(load_export(export_paths))   # cycle 2 shares fleet A's ids
    fills = ex.get("fill_logs", [])
    if not fills:
        print("no fill_logs rows", file=out)
        return 1
    t0 = min(parse_utc(r["received_at"]) for r in fills)
    t1 = max(parse_utc(r["received_at"]) for r in fills)

    layers = build_layers(ex)
    mark_ejections(layers, ex)
    caps = caps_by_instance(ex)
    tls = depth_timelines(layers, t0, t1)
    anchors = eject_anchors(ex, caps)
    calib = {}
    for key, tl in tls.items():
        calib[key] = calibrate_hidden(tl, anchors.get(key, []))

    bars = {}
    for d in bars_dirs:
        bars.update(load_bars_dir(d))
    accounts = account_by_instance(ex)

    def bars_for(inst):
        acct = accounts.get(inst)
        acct = aliases.get(acct, acct)
        return bars.get((acct, symbol_of(inst)))

    rates = carry_rates(ex)
    ejs = collect_ejections(ex, layers)

    w = lambda s="": print(s, file=out)  # noqa: E731
    w("EJECTION VALUE STUDY -- report")
    w("exports: %s" % ", ".join(os.path.basename(p) for p in export_paths))
    w("rows dropped (other accounts / unknown sessions): %s" % (dropped or "none"))
    w("window (fill_logs received_at, UTC): %s .. %s (%.1f h)"
      % (fills[0]["received_at"][:19], fills[-1]["received_at"][:19], (t1 - t0) / 3600))
    w("bars: %s" % ", ".join("%s/%s %d" % (a, s, len(b)) for (a, s), b in sorted(bars.items())))
    w()

    w("== DEPTH CALIBRATION (hidden = layers open through the whole window, from cap anchors)")
    for key in sorted(calib):
        hidden, spread = calib[key]
        if spread is None and hidden == 0:
            continue
        w("  %-22s %s hidden=%d anchor_spread=%s" % (key[0], key[1], hidden, _fmt(spread)))
    w("  (sides without anchors assume hidden=0: their cap hours are a LOWER bound"
      " unless the export starts before the fleet did)")
    w()

    w("== Q1: HOURS AT CAP AND SCALP RATES (per side)")
    stats = side_stats(layers, tls, caps, t0, t1)
    w("  %-22s %s %8s %8s %6s %6s %7s %7s %7s %9s" % ("instance", "sd", "h_at", "h_below",
      "n_blw", "n_at", "r_blw", "r_at", "mean$", "forgone$"))
    for key in sorted(stats):
        s = stats[key]
        if s["hours_at_cap"] <= 0 and s["scalps_at"] == 0:
            continue
        w("  %-22s %s %8s %8s %6d %6d %7s %7s %7s %9s" % (
            key[0], key[1], _fmt(s["hours_at_cap"], 1), _fmt(s["hours_below_cap"], 1),
            s["scalps_below"], s["scalps_at"], _fmt(s["rate_below"]), _fmt(s["rate_at"]),
            _fmt(s["mean_scalp_net"]), _fmt(s["forgone"])))
    w()

    for h in horizons:
        for ej in ejs:
            b = bars_for(ej.instance)
            if b is None:
                ej.cf[h] = {"status": "no_bars"}
                continue
            counterfactual(ej, b, rates.get(ej.instance), h, DEFAULT_OFFSET_S)
        chains = build_chains(ejs, h)
        for ch in chains:
            score_chain(ch, layers, tls[(ch["instance"], ch["side"])], caps,
                        bars_for(ch["instance"]), h)
        w("== Q2/Q3: EPISODES AT HORIZON %d h" % h)
        w("  %-20s %s %3s %-16s %6s %8s %8s %6s %7s %7s %8s %8s %s" % (
            "instance", "sd", "n", "start(UTC)", "status", "E-H", "F_clsd", "freed",
            "F_open", "V_doc", "V_strict", "MAE+$", "hits"))
        tot = collections.defaultdict(float)
        cnt = collections.Counter()
        for ch in sorted(chains, key=lambda c: c["start"]):
            hits = "".join(
                ("B" if m.cf[h].get("borderline") else "Y") if m.cf[h].get("hit")
                else ("b" if m.cf[h].get("borderline") else "n") if m.cf[h].get("hit") is False
                else "?" for m in ch["members"] if not m.freed)
            mae = sum((m.cf[h].get("mae_beyond_eject") or 0.0) for m in ch["members"] if not m.freed)
            import datetime as _dt
            st = _dt.datetime.fromtimestamp(ch["start"], _dt.timezone.utc).strftime("%m-%d %H:%M")
            w("  %-20s %s %3d %-16s %6s %8s %8s %6d %7s %7s %8s %8s %s" % (
                ch["instance"][6:], ch["side"], len(ch["members"]), st, ch["status"],
                _fmt(ch["E_minus_H"]), _fmt(ch["F_closed"]), ch["freed_layers"],
                _fmt(ch["F_open"]), _fmt(ch["V_doc"]), _fmt(ch["V_strict"]), _fmt(mae), hits))
            if ch["status"] == "ok":
                f = fleet_of(ch["instance"])
                for k in ("V_doc", "E_minus_H", "F_closed"):
                    tot[(f, k)] += ch[k]
                if ch["V_strict"] is not None:
                    tot[(f, "V_strict")] += ch["V_strict"]
                cnt[(f, "ok")] += 1
                cnt[(f, "pos")] += ch["V_doc"] > 0
            else:
                cnt[("*", ch["status"])] += 1
        w("  hits: Y hit, B hit within 1 pip (borderline), n no hit, b missed by < 1 pip, ? unscored")
        for f in ("A", "B", "C"):
            if cnt[(f, "ok")]:
                w("  fleet %s: scored %d, V_doc>0 in %d; sum V_doc %s, V_strict %s (E-H %s, F %s)" % (
                    f, cnt[(f, "ok")], cnt[(f, "pos")], _fmt(tot[(f, "V_doc")]),
                    _fmt(tot[(f, "V_strict")]), _fmt(tot[(f, "E_minus_H")]),
                    _fmt(tot[(f, "F_closed")])))
        unscored = {k[1]: v for k, v in cnt.items() if k[0] == "*"}
        if unscored:
            w("  unscored chains: %s" % ", ".join("%s %d" % kv for kv in sorted(unscored.items())))
        fph = f_per_hour(chains)
        w("  control (2) F per held-cap hour: %s over %s h (%d chains)" % (
            _fmt(fph["per_hour"], 3), _fmt(fph["hours"], 1), fph["chains"]))
        w()

    w("== GQ5-F CONTROLS (1) cross-fleet and (3) twins: control scalps/h while capped side at cap")
    rows = pair_controls(layers, tls, caps, fleet_of, symbol_of)
    for r in rows:
        own = stats.get((r["capped"], r["side"]), {})
        w("  %-20s %s vs %-20s %-11s h=%6s n=%3d rate=%6s own_below=%6s own_at=%6s" % (
            r["capped"][6:], r["side"], r["control"][6:], r["kind"], _fmt(r["hours"], 1),
            r["scalps"], _fmt(r["rate"]), _fmt(own.get("rate_below")), _fmt(own.get("rate_at"))))
    if not rows:
        w("  (none: no overlapping at-cap / below-cap hours)")
    return 0


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--export", nargs="+", required=True)
    ap.add_argument("--bars", action="append", default=[])
    ap.add_argument("--alias", action="append", default=[])
    ap.add_argument("--horizons", default="24,48")
    a = ap.parse_args(argv)
    aliases = dict(DEFAULT_ALIAS)
    for s in a.alias:
        k, v = s.split("=")
        aliases[int(k)] = int(v)
    horizons = [int(x) for x in a.horizons.split(",")]
    return run(a.export, a.bars, aliases, horizons)


if __name__ == "__main__":
    sys.exit(main())
