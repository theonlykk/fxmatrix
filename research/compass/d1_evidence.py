"""D1 evidence (docs/architecture/fleet-d.md D1): the numbers behind the first
compass round's directions. Read-only analysis of files; standard library only
(Python 3.9+). Reuses the ejection study's loaders and layer builder
(research/ejection_value, replay v1: imported, never changed).

    python research/compass/d1_evidence.py --export <study_export.jsonl> --bars-ic <wine-c bidask dir>

Part 1 (trade history, the broker ledger): closed net per instance side on
fleets A, B, C over the same three FTMO days under B1 (28 Sep 00:10Z -> 30 Sep
22:00Z): scalps and ejections, all-in (profit + swap + commission). Then, per
pair and side, B1's step (mean of B and C minus A) against the same-settings
gap |B - C|, and the twins (OPT minus ALT on B and C).
Part 2 (IC price path, first-order): a single-lot ladder at the anchor add,
every level cycling independently (buy on the ask low at the level, sell at
level + X on a LATER minute's bid high; short mirrored), exit X-1 / X / X+1,
mean over every 1-pip ladder offset; $/day per side net of $0.07 commission.
No cap, no depth, no lattice: harvest only.
"""
import argparse
import collections
import datetime as dt
import os
import statistics as st
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "ejection_value"))
import ev_book  # noqa: E402
import ev_data  # noqa: E402

PAIRS = ["GBPUSD", "EURUSD", "EURGBP", "AUDCAD", "AUDCHF", "CADCHF", "NZDCHF", "NZDCAD", "AUDNZD"]
# anchor = Fleet B's register row (width / add / exit), cap 8
ANCHOR = {"GBPUSD": (5, 9, 10), "EURUSD": (7, 7, 10), "EURGBP": (3, 3, 5), "AUDCAD": (5, 6, 10),
          "AUDCHF": (5, 4, 10), "CADCHF": (5, 4, 10), "NZDCHF": (3, 3, 10), "NZDCAD": (5, 8, 10),
          "AUDNZD": (7, 8, 10)}
COMM = 0.07          # IC $ per 0.01 round trip (fleet-b.md s4: $3.5/lot/side)
IC_PRICES = 53071896  # wine-c's dump; B shares the server


def utc(text):
    return dt.datetime.fromisoformat(text).replace(tzinfo=dt.timezone.utc).timestamp()


W0, W1 = utc("2026-09-28T00:10"), utc("2026-09-30T22:00")


def load(path):
    raw = ev_data.load_export([path])
    exp, _dropped = ev_data.filter_by_account(raw)
    # scalp_history carries account_login, not session_id: keep it from the raw export
    exp["scalp_history"] = raw.get("scalp_history", [])
    layers = ev_book.build_layers(exp)
    ev_book.mark_ejections(layers, exp)
    return exp, layers


def key(inst, side):
    _g, pair, tail = inst.split("_")
    return ev_data.fleet_of(inst), pair, tail[:3], side


def side_totals(layers, t0, t1):
    """{(fleet, pair, OPT|ALT, side): [scalps, scalp $, ejections, ejection $, open at t1]}
    by CLOSE time in [t0, t1)."""
    out = collections.defaultdict(lambda: [0, 0.0, 0, 0.0, 0])
    for inst, by in layers.items():
        for lay in by.values():
            if lay.side is None:
                continue
            k = key(inst, lay.side)
            if lay.closed and t0 <= lay.close_t < t1:
                if lay.ejected or lay.rolled:
                    out[k][2] += 1
                    out[k][3] += lay.net()
                else:
                    out[k][0] += 1
                    out[k][1] += lay.net()
            if (lay.open_t is None or lay.open_t < t1) and (not lay.closed or lay.close_t >= t1):
                out[k][4] += 1
    return out


def crosscheck(exp, totals):
    """Scalp counts from the ledger vs scalp_history rows (non-ejected, non-rolled) per fleet,
    by the row's receipt time (seconds after the close)."""
    acct = {"A": 1514731800, "B": 53066709, "C": 53071896}
    sh = collections.Counter()
    for s in exp.get("scalp_history", []):
        f = ev_data.fleet_of(s["instance_id"])
        if s.get("account_login") != acct[f]:
            continue
        t = ev_data.parse_utc(s["received_at"])
        if W0 <= t < W1 and not s.get("ejected") and not s.get("rolled"):
            sh[f] += 1
    led = collections.Counter()
    for (f, _p, _s, _side), v in totals.items():
        led[f] += v[0]
    return led, sh


def part1(exp, layers):
    days = (W1 - W0) / 86400
    t = side_totals(layers, W0, W1)
    print("== Part 1: closed net, 28 Sep 00:10Z -> 30 Sep 22:00Z (%.2f d), by close time ==" % days)
    print("%-7s %-3s %-1s | %-34s | %-34s | %-34s" % ("pair", "slt", "s", "A  scalps $  ej $  net/d open",
                                                     "B", "C"))
    for p in PAIRS:
        for slot in ("OPT", "ALT"):
            for side in "LS":
                cells, seen = [], False
                for f in "ABC":
                    v = t.get((f, p, slot, side))
                    if v:
                        seen = True
                        cells.append("%3d %6.2f %2d %7.2f %6.2f %2d" % (v[0], v[1], v[2], v[3],
                                                                    (v[1] + v[3]) / days, v[4]))
                    else:
                        cells.append("%34s" % "-")
                if seen:
                    print("%-7s %-3s %-1s | %s" % (p, slot, side, " | ".join(cells)))
    led, sh = crosscheck(exp, t)
    print("cross-check scalps (ledger vs scalp_history by receipt time):",
          ", ".join("%s %d/%d" % (f, led[f], sh[f]) for f in "ABC"))

    def net(f, p, s, slot="OPT"):
        v = t.get((f, p, slot, s))
        return (v[1] + v[3]) / days if v else float("nan")

    print("\n== B1 step (mean B,C minus A) vs same-settings gap |B-C|; $/day; "
          "PASS = |step| > max(1, gap) ==")
    for p in PAIRS:
        for s in "LS":
            a, b, c = net("A", p, s), net("B", p, s), net("C", p, s)
            step, gap = (b + c) / 2 - a, abs(b - c)
            verdict = ("PASS " + ("tighter" if step > 0 else "wider")) if abs(step) > max(1.0, gap) else "none"
            line = "%-7s %s  A %6.2f  B %6.2f  C %6.2f  step %+6.2f  gap %5.2f  %-12s" % (
                p, s, a, b, c, step, gap, verdict)
            if p in ("NZDCAD", "AUDNZD"):
                line += "  OPT-ALT: B %+.2f  C %+.2f  | ALT gap %.2f" % (
                    b - net("B", p, s, "ALT"), c - net("C", p, s, "ALT"),
                    abs(net("B", p, s, "ALT") - net("C", p, s, "ALT")))
            print(line)


def pip_values(layers):
    pv = collections.defaultdict(list)
    for inst, by in layers.items():
        if ev_data.fleet_of(inst) == "A":
            continue
        for lay in by.values():
            if lay.closed and not lay.ejected and not lay.rolled and lay.closeby_profit \
                    and lay.open_price and lay.close_price:
                pips = abs(lay.close_price - lay.open_price) / 0.0001
                if pips > 1:
                    pv[inst.split("_")[1]].append(abs(lay.closeby_profit) / pips)
    return {k: st.median(v) for k, v in pv.items()}


def side_cycles(rows, levels, x):
    """Completed round trips per side. rows = (bid_high, bid_low, ask_high, ask_low) per minute.
    Long: buy when the ask low touches the level, sell at level + x on a LATER minute's bid high.
    Short: sell when the bid high touches the level, buy back at level - x on a later ask low."""
    nl = ns = 0
    for lv in levels:
        hold_l = hold_s = False
        tl = ts = -1
        for i, (bh, _bl, _ah, al) in enumerate(rows):
            if hold_l:
                if i > tl and bh >= lv + x:
                    nl += 1
                    hold_l = False
            elif al <= lv:
                hold_l, tl = True, i
            if hold_s:
                if i > ts and al <= lv - x:
                    ns += 1
                    hold_s = False
            elif bh >= lv:
                hold_s, ts = True, i
    return nl, ns


def part2(layers, bars_dir):
    bid = ev_data.load_bidask_dir(bars_dir)
    pv = pip_values(layers)
    print("\n== Part 2: IC price path, anchor add, exit X-1 / X / X+1: cycles/day and $/day per side "
          "(net of $%.2f), mean over 1-pip offsets ==" % COMM)
    for p in PAIRS:
        b = bid[(IC_PRICES, p)]
        pip = 0.0001
        rows = [(b.h[i], b.l[i], b.ah[i], b.al[i]) for i in range(len(b))]
        days = len(rows) / 1440.0
        _w, add, x0 = ANCHOR[p]
        lo, hi = min(r[3] for r in rows), max(r[0] for r in rows)
        line = "%-7s pv %.3f add %d days %.2f |" % (p, pv[p], add, days)
        for x in (x0 - 1, x0, x0 + 1):
            tl = ts = 0.0
            for off in range(add):
                lv = (int(lo / (add * pip)) - 1) * add * pip + off * pip
                levels = []
                while lv <= hi + add * pip:
                    levels.append(round(lv, 6))
                    lv += add * pip
                nl, ns = side_cycles(rows, levels, x * pip)
                tl += nl
                ts += ns
            cl, cs = tl / add / days, ts / add / days
            line += "  X%-2d L %5.1f $%5.2f  S %5.1f $%5.2f |" % (x, cl, cl * (x * pv[p] - COMM),
                                                              cs, cs * (x * pv[p] - COMM))
        print(line)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--export", required=True)
    ap.add_argument("--bars-ic", required=True)
    args = ap.parse_args(argv)
    exp, layers = load(args.export)
    part1(exp, layers)
    part2(layers, args.bars_ic)


if __name__ == "__main__":
    main()
