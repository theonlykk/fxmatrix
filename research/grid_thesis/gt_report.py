"""Grid-thesis and backlog measurements (docs/research/grid-thesis.md s11;
backlog C4, C10, C26, C49, C82). Read-only analysis of files; standard
library only (Python 3.9+). Reuses the ejection study's loaders and layer
builder (research/ejection_value, replay v1: imported, never changed).

    python research/grid_thesis/gt_report.py --export <file> --bars-a <dir> [--bars-ic <dir>] [--seed 20260930]

--bars-a: the FTMO (fleet A) bidask_*/bars_* dump folder; --bars-ic: the IC
folder (wine-c; fleet B uses wine-c's prices, same server). M5 and M6 use
--bars-a only. The surrogate and offset draws are seeded: same inputs, same
output.
"""
import argparse
import collections
import datetime as dt
import os
import random
import statistics as st
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "ejection_value"))
import ev_book  # noqa: E402
import ev_data  # noqa: E402

CURRENT = {"A": 1514731800, "B": 53066709, "C": 53071896}
PRICE_ACCOUNT = {"A": 1514731800, "B": 53071896, "C": 53071896}   # B priced from wine-c's dump
# fleet A (cycle 3) add / exit per pair (10_GEOMETRY_REGISTER.md), for the price-path tests
GEO_A = {"GBPUSD": (10, 10), "EURUSD": (8, 10), "EURGBP": (4, 5), "AUDCAD": (7, 10), "AUDCHF": (6, 10),
         "CADCHF": (6, 10), "NZDCHF": (6, 10), "NZDCAD": (10, 10), "AUDNZD": (10, 10)}
LONG = "L"


def fleet(inst):
    return ev_data.fleet_of(inst)


def sym(inst):
    return ev_data.symbol_of(inst)


def utc(ts):
    return dt.datetime.utcfromtimestamp(ts)


# ---------------------------------------------------------------- loading

def load(paths):
    raw = ev_data.load_export(paths)
    exp, dropped = ev_data.filter_by_account(raw)
    # scalp_history carries account_login, not session_id: filter it here
    exp["scalp_history"] = [s for s in raw.get("scalp_history", [])
                            if s.get("account_login") == CURRENT[fleet(s["instance_id"])]]
    return exp, dropped


def positions(fills):
    """Every position (ENT and EXT) from its IN deal and closing deals."""
    ins, outs = {}, collections.defaultdict(list)
    for r in fills:
        if r["entry_type"] == "IN":
            ins[r["position_id"]] = r
        elif r["entry_type"] in ("OUT", "OUT_BY"):
            outs[r["position_id"]].append(r)
    res = []
    for pid, i in ins.items():
        o = outs.get(pid)
        res.append(dict(inst=i["instance_id"], fleet=fleet(i["instance_id"]), sym=sym(i["instance_id"]),
                        side="L" if i["deal_type"] == "BUY" else "S", closed=bool(o),
                        swap=sum(x["swap"] or 0 for x in o) if o else None,
                        comm=(i.get("commission") or 0) + (sum(x.get("commission") or 0 for x in o) if o else 0)))
    return res


def latest_snapshots(events):
    snap = {}
    for e in events:
        if e["code"] == "CARRY_SNAPSHOT":
            k = e["instance_id"]
            if k not in snap or e["received_at"] > snap[k]["received_at"]:
                snap[k] = e
    return snap


# ---------------------------------------------------------------- episodes

def episodes(layers, bidask, pv):
    """One side of one instance from flat to flat (or open at the end)."""
    t_end = max(max((l.close_t or 0), (l.open_t or 0)) for by in layers.values() for l in by.values())
    out = []
    for inst, by in layers.items():
        for side in {l.side for l in by.values()}:
            ls = sorted([l for l in by.values() if l.side == side and l.open_t], key=lambda l: l.open_t)
            evs = []
            for l in ls:
                evs.append((l.open_t, 1, l))
                if l.close_t:
                    evs.append((l.close_t, -1, l))
            evs.sort(key=lambda e: (e[0], e[1]))
            depth, cur = 0, None
            for t, dlt, l in evs:
                if dlt == 1:
                    if depth == 0:
                        cur = dict(inst=inst, side=side, start=t, layers=[], maxd=0, end=None)
                    depth += 1
                    cur["layers"].append(l)
                    cur["maxd"] = max(cur["maxd"], depth)
                else:
                    depth -= 1
                    if depth == 0 and cur:
                        cur["end"] = t
                        out.append(cur)
                        cur = None
            if cur:
                out.append(cur)
    for e in out:
        b = bidask.get((PRICE_ACCOUNT[fleet(e["inst"])], sym(e["inst"])))
        end = e["end"] or t_end
        e["closed_net"] = sum(l.closeby_net or 0 for l in e["layers"] if l.close_t)
        e["n_scalp"] = sum(1 for l in e["layers"] if l.close_t and not l.ejected)
        e["n_ej"] = sum(1 for l in e["layers"] if l.ejected)
        e["hours"] = (end - e["start"]) / 3600
        e["layer_hours"] = sum(((l.close_t or t_end) - l.open_t) / 3600 for l in e["layers"])
        e["peak_loss_usd"] = None
        e["adverse_pips"] = None
        if b:
            i0, i1 = b.index_containing(e["start"]), b.index_containing(end)
            worst, adv, l0 = 0.0, 0.0, e["layers"][0]
            for i in range(i0, min(i1 + 1, len(b))):
                tm = b.t[i] + 59
                openl = [l for l in e["layers"] if l.open_t <= tm and (l.close_t is None or l.close_t > tm)]
                if openl:
                    m = sum(((b.c[i] - l.open_price) if l.side == LONG else (l.open_price - b.ask_close(i))) / b.pip
                            for l in openl)
                    worst = min(worst, m)
                x = ((l0.open_price - b.l[i]) if e["side"] == LONG else (b.ah[i] - l0.open_price)) / b.pip
                adv = max(adv, x)
            e["peak_loss_usd"] = worst * pv.get((PRICE_ACCOUNT[fleet(e["inst"])], sym(e["inst"])), 0.1)
            e["adverse_pips"] = adv
    return out, t_end


def pip_values(layers, bidask):
    pv = collections.defaultdict(list)
    for inst, by in layers.items():
        for l in by.values():
            if l.close_t and not l.ejected and l.closeby_profit and l.open_price and l.close_price:
                b = bidask.get((PRICE_ACCOUNT[fleet(inst)], sym(inst)))
                pip = b.pip if b else 0.0001
                pips = abs(l.close_price - l.open_price) / pip
                if pips > 1:
                    pv[(PRICE_ACCOUNT[fleet(inst)], sym(inst))].append(abs(l.closeby_profit) / pips)
    return {k: st.median(v) for k, v in pv.items()}


# ---------------------------------------------------------------- price-path helpers (M5, M6)

def rows_of(b):
    return [(b.h[i], b.l[i], b.ah[i], b.al[i], b.o[i], b.c[i]) for i in range(len(b))]


def zigzag(hi, lo, thr):
    legs, direction, ext, start = [], 0, None, None
    for h, l in zip(hi, lo):
        if ext is None:
            ext = start = (h + l) / 2
            continue
        if direction >= 0:
            if h > ext:
                ext = h
            elif ext - l >= thr:
                if direction == 1:
                    legs.append(ext - start)
                start, ext, direction = ext, l, -1
                continue
            if direction == 0 and ext - start >= thr:
                direction = 1
        if direction == -1:
            if l < ext:
                ext = l
            elif h - ext >= thr:
                legs.append(start - ext)
                start, ext, direction = ext, h, 1
    return legs


def surrogate(rows, rng, block=60):
    blocks = [rows[i:i + block] for i in range(0, len(rows), block)]
    rng.shuffle(blocks)
    out, level = [], rows[0][4]
    for bl in blocks:
        d = level - bl[0][4]
        out.extend(tuple(x + d for x in r) for r in bl)
        level = out[-1][5]
    return out


def cycles(rows, levels, x):
    """Completed round trips per level: a long buys when the ask low touches the level and
    sells at level + x on a later minute's bid high; a short mirrors it. The if/elif keeps an
    exit out of the minute its entry filled (study s10 C2); `i > t` restates it."""
    cnt = collections.Counter()
    for lv in levels:
        hold_l = hold_s = False
        tl = ts = -1
        for i, (bh, bl, ah, al, _o, _c) in enumerate(rows):
            if hold_l:
                if i > tl and bh >= lv + x:
                    cnt[lv] += 1
                    hold_l = False
            elif al <= lv:
                hold_l, tl = True, i
            if hold_s:
                if i > ts and al <= lv - x:
                    cnt[lv] += 1
                    hold_s = False
            elif bh >= lv:
                hold_s, ts = True, i
    return [cnt[lv] for lv in levels]


def conc(v):
    v = sorted(v, reverse=True)
    tot = sum(v)
    k = max(1, len(v) // 10)
    m = st.mean(v)
    return tot, (sum(v[:k]) / tot if tot else 0.0), (st.pvariance(v) / m if m else 0.0)


def ladder(rows, pip, add, offset):
    lo, hi = min(r[3] for r in rows), max(r[0] for r in rows)
    lv = (int(lo / (add * pip)) - 1) * add * pip + offset * pip
    out = []
    while lv <= hi + add * pip:
        out.append(round(lv, 6))
        lv += add * pip
    return out


# ---------------------------------------------------------------- report

def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--export", nargs="+", required=True)
    ap.add_argument("--bars-a", required=True)
    ap.add_argument("--bars-ic")
    ap.add_argument("--seed", type=int, default=20260930)
    ap.add_argument("--surrogates", type=int, default=40)
    ap.add_argument("--offsets", type=int, default=20)
    a = ap.parse_args(argv)
    exp, dropped = load(a.export)
    ba = dict(ev_data.load_bidask_dir(a.bars_a))
    if a.bars_ic:
        ba.update(ev_data.load_bidask_dir(a.bars_ic))
    layers = ev_book.build_layers(exp)
    ev_book.mark_ejections(layers, exp)
    pv = pip_values(layers, ba)
    eps, t_end = episodes(layers, ba, pv)
    P = positions(exp["fill_logs"])
    snaps = latest_snapshots(exp["ea_events"])
    print("GRID THESIS / BACKLOG MEASUREMENTS")
    print("exports:", ", ".join(os.path.basename(p) for p in a.export), "| dropped:", dropped)
    print("window end (UTC):", utc(t_end), "| episodes:", len(eps))

    # C10 carry cost
    print("\n== C10 carry: swap booked on closed positions + accrued on the open book (latest snapshot)")
    sw = collections.defaultdict(float)
    for p in P:
        if p["closed"] and p["swap"]:
            sw[(p["fleet"], p["sym"], p["side"])] += p["swap"]
    for k, e in snaps.items():
        sw[(fleet(k), sym(k), "L")] += e["detail"].get("accrued_swap_long") or 0
        sw[(fleet(k), sym(k), "S")] += e["detail"].get("accrued_swap_short") or 0
    first = {f: min((p_open for p_open in [l.open_t for inst, by in layers.items() if fleet(inst) == f
                                           for l in by.values() if l.open_t]), default=None) for f in "ABC"}
    for f in "ABC":
        tot = sum(v for k, v in sw.items() if k[0] == f)
        days = (t_end - first[f]) / 86400 if first[f] else float("nan")
        print(f"  {f}: total {tot:7.2f} over {days:.1f} days = {tot / days:5.2f} per day")

    # C4 pips by side
    print("\n== C4 scalps and ejections by side (gross USD includes swap), swap per side")
    agg = collections.defaultdict(lambda: collections.defaultdict(float))
    for s in exp["scalp_history"]:
        if s.get("rolled"):
            continue
        side = "L" if s["direction"] == "LONG" else "S"
        key = "ej" if s.get("ejected") else "sc"
        agg[(s["instrument"], side)][key + "_n"] += 1
        agg[(s["instrument"], side)][key + "_usd"] += s["gross_pnl"] or 0
    for k, v in sw.items():
        agg[(k[1], k[2])]["swap"] += v
    tot_sw = sum(v["swap"] for v in agg.values())
    tot_sc = sum(v["sc_usd"] for v in agg.values())
    for k in sorted(agg):
        v = agg[k]
        print(f"  {k[0]} {k[1]} scalps {int(v['sc_n']):4d} {v['sc_usd']:8.2f}  ejections {int(v['ej_n']):3d} {v['ej_usd']:8.2f}  swap {v['swap']:6.2f}")
    print(f"  all: swap {tot_sw:.2f} vs scalp gross {tot_sc:.2f} ({100 * tot_sw / tot_sc:.2f}%)")

    # C26 clamps
    print("\n== C26 carry-pass counts per night and fleet")
    by = collections.defaultdict(collections.Counter)
    for e in exp["ea_events"]:
        if e["code"] in ("CARRY_PASS_SUMMARY", "CARRY_PASS_INCOMPLETE"):
            d = e["detail"] or {}
            c = by[(e["received_at"][:10], fleet(e["instance_id"]))]
            c["passes"] += 1
            c["incomplete"] += 1 if (e["code"] == "CARRY_PASS_INCOMPLETE" or d.get("incomplete")) else 0
            for f in ("eligible", "shifted", "clamped", "failed"):
                c[f] += d.get(f) or 0
    for k in sorted(by):
        c = by[k]
        print(f"  {k[0]} {k[1]} passes {c['passes']:2d} incomplete {c['incomplete']:2d} eligible {c['eligible']:3d} "
              f"shifted {c['shifted']:3d} clamped {c['clamped']} failed {c['failed']}")

    # M1
    print("\n== M1 deepest layer per episode")
    for f in "ABC":
        E = [e for e in eps if fleet(e["inst"]) == f]
        c = collections.Counter(min(e["maxd"], 8) for e in E)
        n = len(E)
        if n:
            print(f"  {f}: {n} episodes; " + " ".join(f"{k}:{c[k]}" for k in range(1, 9)) +
                  f" | <=2: {(c[1] + c[2]) / n:.0%} >=5: {sum(c[k] for k in range(5, 9)) / n:.0%} cap: {c[8] / n:.0%}")

    # M2
    print("\n== M2 scalps per ejection; worst 4-hour ejection cluster")
    for f in "ABC":
        E = [e for e in eps if fleet(e["inst"]) == f]
        ns, ne = sum(e["n_scalp"] for e in E), sum(e["n_ej"] for e in E)
        ej = sorted((l.close_t, l.closeby_net or 0) for e in E for l in e["layers"] if l.ejected and l.close_t)
        worst = (0.0, None)
        for t, _ in ej:
            s = sum(v for tt, v in ej if t <= tt < t + 4 * 3600)
            if s < worst[0]:
                worst = (s, t)
        when = utc(worst[1]).strftime("%d %b %H:%MZ") if worst[1] else "-"
        print(f"  {f}: scalps {ns} ejections {ne} per ejection {ns / ne if ne else float('inf'):.1f}; "
              f"worst 4 h ${worst[0]:.2f} from {when}")

    # M3
    print("\n== M3 closed net per layer-day")
    m3 = collections.defaultdict(lambda: [0.0, 0.0])
    for e in eps:
        m3[(fleet(e["inst"]), sym(e["inst"]))][0] += e["closed_net"]
        m3[(fleet(e["inst"]), sym(e["inst"]))][1] += e["layer_hours"]
    for p in sorted({k[1] for k in m3}):
        print(f"  {p} " + " | ".join(f"{f} {m3[(f, p)][0]:7.2f} {24 * m3[(f, p)][0] / m3[(f, p)][1] if m3[(f, p)][1] else 0:6.2f}"
                                     for f in "ABC"))
    for f in "ABC":
        n = sum(v[0] for k, v in m3.items() if k[0] == f)
        lh = sum(v[1] for k, v in m3.items() if k[0] == f)
        print(f"  fleet {f}: closed {n:.2f}, $ per layer-day {24 * n / lh:.3f}")

    # M4
    print("\n== M4 deep episodes (max depth >= 6)")
    deep = [e for e in eps if e["maxd"] >= 6]
    done = [e for e in deep if e["end"]]
    print(f"  {len(deep)} deep, {len(done)} closed: net {sum(e['closed_net'] for e in done):.2f}, "
          f"peak open {sum(e['peak_loss_usd'] or 0 for e in done):.2f}, no ejection {sum(1 for e in done if e['n_ej'] == 0)}")

    # M7
    print("\n== M7 peak open loss by deepest layer (median / worst USD) and excursion vs room")
    for f in "ABC":
        rows = collections.defaultdict(list)
        for e in eps:
            if fleet(e["inst"]) == f and e["peak_loss_usd"] is not None:
                rows[min(e["maxd"], 8)].append(e["peak_loss_usd"])
        print(f"  {f}: " + " ".join(f"d{k}:{st.median(v):.1f}/{min(v):.1f}" for k, v in sorted(rows.items())))
    cfg = collections.defaultdict(list)
    for r in exp["config_events"]:
        if r.get("event") == "INIT" and r.get("add_pips"):
            cfg[r["instance_id"]].append((ev_data.parse_utc(r["received_at"]), r["add_pips"], r["max_layers"]))
    ex = []
    for e in eps:
        g = [x for x in sorted(cfg[e["inst"]]) if x[0] <= e["start"] + 120] or sorted(cfg[e["inst"]])[:1]
        if g and e["adverse_pips"] is not None:
            add, cap = g[-1][1], g[-1][2]
            ex.append((e["adverse_pips"] > add * (cap - 1), e["adverse_pips"] / (add * (cap - 1))))
    print(f"  exceeded the room to cap: {sum(1 for x, _ in ex if x)}/{len(ex)}; median excursion/room {st.median(r for _, r in ex):.2f}")

    # C49
    print("\n== C49 deep adds (depth >= 6) by time since the previous fill on the side")
    rows = []
    for e in eps:
        ls = sorted(e["layers"], key=lambda l: l.open_t)
        for i, l in enumerate(ls):
            depth = sum(1 for x in ls[:i + 1] if x.close_t is None or x.close_t > l.open_t)
            if depth < 6 or i == 0:
                continue
            gap = (l.open_t - max(x.open_t for x in ls[:i])) / 60
            outcome = "open" if l.close_t is None else ("ejected" if l.ejected else "scalped")
            rows.append((gap, outcome))
    for lo, hi, lab in ((0, 5, "< 5 min"), (5, 30, "5-30 min"), (30, 120, "30-120 min"), (120, 1e9, ">= 2 h")):
        sel = [o for g, o in rows if lo <= g < hi]
        c = collections.Counter(sel)
        if sel:
            print(f"  {lab:10s} n={len(sel):3d} scalped {c['scalped'] / len(sel):.0%} ejected {c['ejected'] / len(sel):.0%} open {c['open'] / len(sel):.0%}")

    # M5 and M6 (price path, fleet A prices)
    rng = random.Random(a.seed)
    a_bars = ev_data.load_bidask_dir(a.bars_a)
    print("\n== M5 zigzag legs per trading day at 5/10/20 pips; longest leg without a 10-pip retrace")
    print("== M6 concentration (top-decile share of cycles): real (mean of offsets) vs hourly-block surrogates")
    for (_acc, s), b in sorted(a_bars.items(), key=lambda x: x[0][1]):
        rows_ = rows_of(b)
        hi = [(b.h[i] + b.ah[i]) / 2 for i in range(len(b))]
        lo = [(b.l[i] + b.al[i]) / 2 for i in range(len(b))]
        days = (b.t[-1] - b.t[0]) / 86400 * 5 / 7
        per = [len(zigzag(hi, lo, t * b.pip)) / days for t in (5, 10, 20)]
        longest = max(x / b.pip for x in zigzag(hi, lo, 10 * b.pip))
        add, x = GEO_A[s]
        real = [conc(cycles(rows_, ladder(rows_, b.pip, add, rng.uniform(0, add)), x * b.pip)) for _ in range(a.offsets)]
        sur = []
        for _ in range(a.surrogates):
            sp = surrogate(rows_, rng)
            sur.append(conc(cycles(sp, ladder(sp, b.pip, add, rng.uniform(0, add)), x * b.pip)))
        r_sh = st.mean(r[1] for r in real)
        p = sum(1 for r in sur if r[1] >= r_sh) / len(sur)
        print(f"  {s} M5 {per[0]:5.1f} {per[1]:5.1f} {per[2]:5.1f} longest {longest:5.1f} | M6 cycles real {st.mean(r[0] for r in real):6.1f} "
              f"surr {st.mean(r[0] for r in sur):6.1f} share real {r_sh:.2f} surr {st.mean(r[1] for r in sur):.2f} p={p:.2f}")

    print("\n== M6 trade history: busiest entry level's share of scalps in deep episodes (depth >= 5, >= 10 scalps)")
    shares, nlev = [], []
    for e in eps:
        if e["maxd"] < 5:
            continue
        c = collections.Counter(round(l.open_price, 4) for l in e["layers"] if l.close_t and not l.ejected)
        tot = sum(c.values())
        if tot >= 10:
            shares.append(c.most_common(1)[0][1] / tot)
            nlev.append(len(c))
    if shares:
        n_med, k_med = int(st.median(nlev)), 12
        sims = []
        for _ in range(5000):
            cc = [0] * n_med
            for _ in range(k_med):
                cc[rng.randrange(n_med)] += 1
            sims.append(max(cc) / k_med)
        print(f"  episodes {len(shares)}, median busiest share {st.median(shares):.0%} on median {n_med} levels; "
              f"chance (12 scalps on {n_med} equal levels) {st.median(sims):.0%}")


if __name__ == "__main__":
    main()
