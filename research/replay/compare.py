"""compare.py -- the replay against the archive (replay-calibration-eurusd.md s6-s7).

Pre-registered marks (s6, rulings s12):
- a deal = an IN deal (ENT or EXT; OUT_BY rows are bookkeeping). A replay deal MATCHES a
  real one when segment, side, role and layer agree, the price is within 0.2 pip and the
  time within 60 s. Matching is one to one: nearest in time first, then augmented to the
  largest number of pairs (an augmenting path never unmatches a real deal);
- T0: a touching tick (ask <= price for a buy, bid >= price for a sell) in
  [fill - 2 s, fill + 0.5 s]. ENT on L and EXT on S are buys;
- T1 (the sync runs), per fleet: matched / T0-touchable >= 95% AND replay-only deals
  <= 5% of the real count; the rate over all real deals is reported beside it. A segment
  failing either mark (or, with no real deal, holding a replay-only deal) is UNPRICED;
- T2 (the free runs), per fleet and side, summed over priced segments: scalps S, roll
  closes R and ROLL_ACCEPTED within 10% (or 1) of the real count;
  rho = sum (S + R) e / sum R_eff D, R_eff = R + max(0, -open pips) / (D - e), e = the
  side's exit, D = cap x the side's add, the open book marked at the last tick before the
  segment's end; within 0.1 (both undefined counts as equal). T2 FAILS for a fleet when
  UNPRICED segments hold more than 20% of its real deals.
Misses (s7) are listed with what is known mechanically: M1 when T0 finds no touch; every
other category is assigned by hand from the evidence.

    python -B research/replay/compare.py --inputs DIR --runs DIR --harness SHA7 \
        --ticks TICKS.csv --archive-b B.jsonl --archive-c C.jsonl --archive-d D.jsonl --out DIR

Standard library only; ascii, LF.
"""
import argparse
import bisect
import calendar
import csv
import datetime as dt
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_seeds  # noqa: E402

PRICE_TOL_PTS = 2            # 0.2 pip at 5 decimals
TIME_TOL_MS = 60000
T0_BEFORE_MS = 2000
T0_AFTER_MS = 500
PTS_PER_PIP = 10
FLEETS = (("B", "eurusd_b"), ("C", "eurusd_c"), ("D", "eurusd_d"))


def pts(price):
    return int(round(float(price) * 100000))


def is_buy(side, role):
    return (side == "L") == (role == "ENT")


def read_csv(path):
    with open(path, encoding="utf-8-sig", newline="") as f:
        return [r for r in csv.DictReader(line for line in f if not line.startswith("#"))]


def read_events(path):
    """events csv: seg_id,sync_idx,time_ms,kind,code,json; the json field is not quoted."""
    out = []
    with open(path, encoding="utf-8-sig") as f:
        head = None
        for line in f:
            line = line.rstrip("\r\n")
            if not line:
                continue
            parts = line.split(",", 5)
            if head is None:
                head = parts
                continue
            out.append(dict(zip(head, parts)))
    return out


def read_jsonl(path):
    with open(path, encoding="utf-8-sig") as f:
        return [json.loads(line) for line in f if line.strip()]


def segments(run_rows):
    out = []
    for r in run_rows:
        out.append({"seg_id": int(r["seg_id"]), "from_ms": int(r["from_ms"]),
                    "to_ms": int(r["to_ms"]), "add_l": float(r["add_l"]),
                    "add_s": float(r["add_s"]), "exit_l": float(r["exit_l"]),
                    "exit_s": float(r["exit_s"]), "cap": int(r["cap"])})
    return out


def seg_of(t, segs):
    for s in segs:
        if s["from_ms"] <= t < s["to_ms"]:
            return s["seg_id"]
    return None


def _deal(seg, t, side, role, layer, price_pts):
    return {"seg": seg, "t": t, "side": side, "role": role, "layer": layer, "pts": price_pts}


def real_deals(real_rows, segs, order_pts=None):
    """IN deals per segment. pts = the ORDER's price when order_pts {position_id: pts} is
    given (the EA's decision; the replay fills at its order's price, GRC-5), else the deal's;
    fill_pts = the deal's price (IC's price improvement included; T0 reads it)."""
    out = []
    for r in real_rows:
        if r["kind"] not in ("ENT", "EXT"):
            continue
        t = int(r["time_ms"])
        seg = seg_of(t, segs)
        if seg is None:
            continue
        fill = pts(r["price"])
        price = fill if order_pts is None else order_pts[int(r["position_id"])]
        d = _deal(seg, t, r["side"], r["kind"], int(r["layer"]), price)
        d["fill_pts"] = fill
        out.append(d)
    return out


def order_prices(archive_rows):
    """{position_id: order price pts} from the archive's fill_logs IN rows."""
    out = {}
    for r in archive_rows:
        if r.get("table") == "fill_logs" and r.get("entry_type") == "IN":
            out[int(r["position_id"])] = pts(r["order_price_open"])
    return out


def real_rolls(real_rows, segs):
    out = []
    for r in real_rows:
        if r["kind"] != "ROLL":
            continue
        seg = seg_of(int(r["time_ms"]), segs)
        if seg is not None:
            out.append({"seg": seg, "side": r["side"]})
    return out


def replay_deals(deal_rows):
    return [_deal(int(r["seg_id"]), int(r["time_ms"]), r["side"], r["role"], int(r["layer"]),
                  pts(r["price"]))
            for r in deal_rows if r["entry_type"] == "0"]


def replay_scalps(event_rows):
    out = []
    for r in event_rows:
        if r["kind"] != "scalp" or r["code"] != "SCALP_CLOSED":
            continue
        j = json.loads(r["json"])
        out.append({"seg": int(r["seg_id"]), "side": "L" if j["direction"] == "LONG" else "S",
                    "rolled": bool(j["rolled"])})
    return out


def replay_rolls(event_rows):
    out = []
    for r in event_rows:
        if r["code"] != "ROLL_ACCEPTED":
            continue
        j = json.loads(r["json"])
        out.append({"seg": int(r["seg_id"]), "side": j["detail"]["side"]})
    return out


def _server_ms(s):
    return calendar.timegm(dt.datetime.strptime(s, "%Y-%m-%d %H:%M:%S").timetuple()) * 1000


def real_scalps(archive_rows, segs):
    seen = set()
    out = []
    for r in archive_rows:
        if r.get("table") != "scalp_history":
            continue
        key = tuple(sorted((k, json.dumps(v)) for k, v in r.items()
                           if k not in ("id", "received_at")))
        if key in seen:
            continue
        seen.add(key)
        seg = seg_of(_server_ms(r["close_time_broker"]), segs)
        if seg is None:
            continue
        out.append({"seg": seg, "side": "L" if r["direction"] == "LONG" else "S",
                    "rolled": bool(r["rolled"])})
    return out


class Ticks:
    def __init__(self, times, bids, asks):
        self.t, self.b, self.a = times, bids, asks

    @classmethod
    def load(cls, path):
        t, b, a = [], [], []
        with open(path, encoding="utf-8-sig") as f:
            head = None
            for line in f:
                if line.startswith("#") or not line.strip():
                    continue
                parts = line.strip().split(",")
                if head is None:
                    head = parts
                    it, ib, ia = head.index("time_msc_server"), head.index("bid"), head.index("ask")
                    continue
                t.append(int(parts[it]))
                b.append(pts(parts[ib]))
                a.append(pts(parts[ia]))
        return cls(t, b, a)

    def touchable(self, d, price_mode="deal"):
        lo = bisect.bisect_left(self.t, d["t"] - T0_BEFORE_MS)
        hi = bisect.bisect_right(self.t, d["t"] + T0_AFTER_MS)
        if price_mode == "order":
            price = d["pts"]
        elif price_mode == "deal":
            price = d.get("fill_pts", d["pts"])
        else:
            raise ValueError("price_mode must be 'order' or 'deal'")
        if is_buy(d["side"], d["role"]):
            return any(self.a[i] <= price for i in range(lo, hi))
        return any(self.b[i] >= price for i in range(lo, hi))

    def mark(self, at_ms):
        i = bisect.bisect_left(self.t, at_ms) - 1
        if i < 0:
            return None
        return self.b[i], self.a[i]


def _fits(r, p):
    return (r["seg"] == p["seg"] and r["side"] == p["side"] and r["role"] == p["role"]
            and r["layer"] == p["layer"] and abs(r["pts"] - p["pts"]) <= PRICE_TOL_PTS
            and abs(r["t"] - p["t"]) <= TIME_TOL_MS)


def match(reals, replays):
    """{real index: replay index}, one to one; nearest first, then the largest number."""
    cand = {i: [] for i in range(len(reals))}
    pairs = []
    for i, r in enumerate(reals):
        for j, p in enumerate(replays):
            if _fits(r, p):
                key = (abs(r["t"] - p["t"]), abs(r["pts"] - p["pts"]), i, j)
                pairs.append(key)
                cand[i].append(key)
    for i in cand:
        cand[i] = [k[3] for k in sorted(cand[i])]
    pairs.sort()
    r2p, p2r = {}, {}
    for _d, _q, i, j in pairs:
        if i not in r2p and j not in p2r:
            r2p[i], p2r[j] = j, i

    def augment(i, seen):
        for j in cand[i]:
            if j in seen:
                continue
            seen.add(j)
            if j not in p2r or augment(p2r[j], seen):
                r2p[i], p2r[j] = j, i
                return True
        return False

    sys.setrecursionlimit(max(10000, 4 * len(reals) + 100))
    for i in range(len(reals)):
        if i not in r2p:
            augment(i, set())
    return r2p


def _t1_fails(real, matched_touch, touch, replay_only):
    if real == 0:
        return replay_only > 0
    return matched_touch * 100 < 95 * touch or replay_only * 100 > 5 * real


def t1(reals, replays, touch):
    m = match(reals, replays)
    matched_reps = set(m.values())
    segs = {}

    def row(seg):
        return segs.setdefault(seg, {"real": 0, "touch": 0, "matched": 0, "matched_touch": 0,
                                     "replay": 0, "replay_only": 0})
    for i, r in enumerate(reals):
        s = row(r["seg"])
        s["real"] += 1
        s["touch"] += 1 if touch[i] else 0
        if i in m:
            s["matched"] += 1
            s["matched_touch"] += 1 if touch[i] else 0
    for j, p in enumerate(replays):
        s = row(p["seg"])
        s["replay"] += 1
        if j not in matched_reps:
            s["replay_only"] += 1
    tot = {k: sum(s[k] for s in segs.values())
           for k in ("real", "touch", "matched", "matched_touch", "replay", "replay_only")}
    tot["rate"] = tot["matched_touch"] / tot["touch"] if tot["touch"] else None
    tot["rate_all"] = tot["matched"] / tot["real"] if tot["real"] else None
    tot["replay_only_frac"] = tot["replay_only"] / tot["real"] if tot["real"] else None
    tot["pass"] = tot["real"] > 0 and not _t1_fails(tot["real"], tot["matched_touch"],
                                                    tot["touch"], tot["replay_only"])
    unpriced = sorted(seg for seg, s in segs.items()
                      if _t1_fails(s["real"], s["matched_touch"], s["touch"], s["replay_only"]))
    return {"segs": segs, "total": tot, "unpriced": unpriced, "pairs": m,
            "misses": [i for i in range(len(reals)) if i not in m],
            "extras": [j for j in range(len(replays)) if j not in matched_reps]}


def open_pips(book, side, bid, ask):
    tot = 0
    for p in book:
        if p["side"] != side:
            continue
        tot += (bid - p["pts"]) if side == "L" else (p["pts"] - ask)
    return tot / PTS_PER_PIP


def rho(parts):
    """parts: (S, R, e, D, open pips) per segment; None when the denominator is 0."""
    num = sum((S + R) * e for S, R, e, D, _o in parts)
    den = sum((R + max(0.0, -o) / (D - e)) * D for S, R, e, D, o in parts)
    return num / den if den > 0 else None


def within(rep, real):
    return abs(rep - real) <= max(0.1 * real, 1)


def t2(segs, unpriced, unpriced_share):
    """segs[seg][side] = {e, D, real: {S, R, A, open}, rep: {...}}."""
    sides = {}
    for side in ("L", "S"):
        parts = {"real": [], "rep": []}
        sums = {"real": {"S": 0, "R": 0, "A": 0}, "rep": {"S": 0, "R": 0, "A": 0}}
        for seg in sorted(segs):
            if seg in unpriced or side not in segs[seg]:
                continue
            g = segs[seg][side]
            for who in ("real", "rep"):
                c = g[who]
                for k in ("S", "R", "A"):
                    sums[who][k] += c[k]
                parts[who].append((c["S"], c["R"], g["e"], g["D"], c["open"]))
        r_real, r_rep = rho(parts["real"]), rho(parts["rep"])
        if r_real is None or r_rep is None:
            rho_ok = r_real is None and r_rep is None
        else:
            rho_ok = abs(r_rep - r_real) <= 0.1
        res = {"real": sums["real"], "rep": sums["rep"], "rho_real": r_real, "rho_rep": r_rep,
               "rho_ok": rho_ok}
        for k in ("S", "R", "A"):
            res[k + "_ok"] = within(sums["rep"][k], sums["real"][k])
        res["pass"] = res["S_ok"] and res["R_ok"] and res["A_ok"] and rho_ok
        sides[side] = res
    share_ok = unpriced_share <= 0.2
    return {"sides": sides, "share_ok": share_ok,
            "pass": share_ok and all(s["pass"] for s in sides.values())}


# ---------------------------------------------------------------- the runs, end to end


def _count(items, seg, side, rolled=None):
    return sum(1 for x in items if x["seg"] == seg and x["side"] == side
               and (rolled is None or x["rolled"] == rolled))


def fleet_report(inputs, runs, harness, tag, ticks, archive_rows, t0_price="deal"):
    segs = segments(read_csv(os.path.join(inputs, "run_%s.csv" % tag)))
    real_rows = read_csv(os.path.join(inputs, "real_%s.csv" % tag))
    reals = real_deals(real_rows, segs, order_prices(archive_rows))
    reals_fill = real_deals(real_rows, segs)
    touch = [ticks.touchable(d, t0_price) for d in reals]

    def out(mode, kind):
        d = os.path.join(runs, "%s_%s_%s" % (tag, mode, harness))
        return read_csv(os.path.join(d, "out_%s_%s_%s.csv" % (tag, mode, kind)))

    sync_deals = replay_deals(out("sync", "deals"))
    t1r = t1(reals, sync_deals, touch)
    t1_fill = t1(reals_fill, sync_deals, touch)     # on the deal's price: reported
    free_deals = replay_deals(out("free", "deals"))
    free_t1 = t1(reals, free_deals, touch)          # reported, never deciding
    ev = read_events(os.path.join(runs, "%s_free_%s" % (tag, harness),
                                  "out_%s_free_events.csv" % tag))
    rep_sc, rep_ro = replay_scalps(ev), replay_rolls(ev)
    real_sc, real_ro = real_scalps(archive_rows, segs), real_rolls(real_rows, segs)
    book = {}
    for r in out("free", "book"):
        book.setdefault(int(r["seg_id"]), []).append({"side": r["side"], "pts": pts(r["entry"])})
    seg_rows = {}
    for s in segs:
        mk = ticks.mark(s["to_ms"])
        true_book = [{"side": p["side"], "pts": pts(p["entry"])}
                     for p in build_seeds.open_positions(archive_rows, s["to_ms"])]
        seg_rows[s["seg_id"]] = {}
        for side in ("L", "S"):
            e = s["exit_l"] if side == "L" else s["exit_s"]
            D = s["cap"] * (s["add_l"] if side == "L" else s["add_s"])
            g = {"e": e, "D": D}
            for who, sc, ro, bk in (("real", real_sc, real_ro, true_book),
                                    ("rep", rep_sc, rep_ro, book.get(s["seg_id"], []))):
                g[who] = {"S": _count(sc, s["seg_id"], side, False),
                          "R": _count(sc, s["seg_id"], side, True),
                          "A": _count(ro, s["seg_id"], side),
                          "open": open_pips(bk, side, mk[0], mk[1]) if mk else 0.0}
            seg_rows[s["seg_id"]][side] = g
    held = sum(t1r["segs"].get(sg, {"real": 0})["real"] for sg in t1r["unpriced"])
    share = held / len(reals) if reals else 0.0
    t2r = t2(seg_rows, t1r["unpriced"], share)
    t0 = {"real": len(reals), "touch": sum(touch)}
    return {"tag": tag, "segs": segs, "reals": reals, "touch": touch, "t0": t0, "t1": t1r,
            "free_t1": free_t1, "t1_fill": t1_fill, "sync_deals": sync_deals, "seg_rows": seg_rows,
            "unpriced_share": share, "t2": t2r}


def _nearest(d, pool):
    best = None
    for p in pool:
        if (p["seg"], p["side"], p["role"], p["layer"]) != (d["seg"], d["side"], d["role"],
                                                              d["layer"]):
            continue
        k = (abs(p["t"] - d["t"]), p)
        if best is None or k[0] < best[0]:
            best = k
    return best[1] if best else None


def miss_rows(rep):
    rows = []
    reals, deals, t1r = rep["reals"], rep["sync_deals"], rep["t1"]
    for kind, idx, pool, src in (("MISS", t1r["misses"], deals, reals),
                                 ("EXTRA", t1r["extras"], reals, deals)):
        for i in idx:
            d = src[i]
            n = _nearest(d, pool)
            cat = ""
            if kind == "MISS" and not rep["touch"][i]:
                cat = "M1"
            rows.append({"fleet": rep["tag"], "kind": kind, "seg": d["seg"], "time_ms": d["t"],
                         "side": d["side"], "role": d["role"], "layer": d["layer"],
                         "price": "%.5f" % (d["pts"] / 100000.0),
                         "fill_price": "%.5f" % (d.get("fill_pts", d["pts"]) / 100000.0),
                         "near_dt_ms": "" if n is None else n["t"] - d["t"],
                         "near_dpts": "" if n is None else n["pts"] - d["pts"],
                         "category": cat})
    rows.sort(key=lambda r: (r["seg"], r["time_ms"], r["kind"]))
    return rows


def _pct(x):
    return "n/a" if x is None else "%.1f%%" % (100 * x)


def _f(x):
    return "n/a" if x is None else "%.2f" % x


def report_md(reps, harness, t0_price="deal"):
    out = ["# Replay vs archive, harness %s (compare.py)" % harness, ""]
    if t0_price != "deal":   # plan 1's reports (deal price) stay byte for byte as committed
        out += ["T0 touches on the %s price." % t0_price.upper(), ""]
    out.append("| fleet | T0 | T1 matched / touchable | T1 all | replay-only | T1 | "
               "unpriced segs (share) | T2 | T1 on deal price (reported) |")
    out.append("|---|---|---|---|---|---|---|---|---|")
    for name, rep in reps:
        t = rep["t1"]["total"]
        tf = rep["t1_fill"]["total"]
        out.append("| %s | %d / %d | %d / %d = %s | %s | %d = %s | %s | %s (%s) | %s | %s / %s |" % (
            name, rep["t0"]["touch"], rep["t0"]["real"], t["matched_touch"], t["touch"],
            _pct(t["rate"]), _pct(t["rate_all"]), t["replay_only"], _pct(t["replay_only_frac"]),
            "PASS" if t["pass"] else "FAIL", ",".join(map(str, rep["t1"]["unpriced"])) or "-",
            _pct(rep["unpriced_share"]), "PASS" if rep["t2"]["pass"] else "FAIL",
            _pct(tf["rate"]), _pct(tf["replay_only_frac"])))
    out += ["", "## T1 per segment (sync)", "",
            "| fleet | seg | real | touch | matched | replay | replay-only | free run matched |",
            "|---|---|---|---|---|---|---|---|"]
    for name, rep in reps:
        fs = rep["free_t1"]["segs"]
        for seg in sorted(rep["t1"]["segs"]):
            s = rep["t1"]["segs"][seg]
            out.append("| %s | %d | %d | %d | %d | %d | %d | %d |" % (
                name, seg, s["real"], s["touch"], s["matched"], s["replay"], s["replay_only"],
                fs.get(seg, {"matched": 0})["matched"]))
    out += ["", "## T2 per side (free, priced segments)", "",
            "| fleet | side | S real / rep | R real / rep | ROLL_ACCEPTED real / rep | "
            "rho real / rep | pass |", "|---|---|---|---|---|---|---|"]
    for name, rep in reps:
        for side, s in rep["t2"]["sides"].items():
            out.append("| %s | %s | %d / %d %s | %d / %d %s | %d / %d %s | %s / %s %s | %s |" % (
                name, side, s["real"]["S"], s["rep"]["S"], "ok" if s["S_ok"] else "X",
                s["real"]["R"], s["rep"]["R"], "ok" if s["R_ok"] else "X",
                s["real"]["A"], s["rep"]["A"], "ok" if s["A_ok"] else "X",
                _f(s["rho_real"]), _f(s["rho_rep"]), "ok" if s["rho_ok"] else "X",
                "PASS" if s["pass"] else "FAIL"))
    out += ["", "## T2 per segment and side (free; S / R / A / open pips, real vs rep)", "",
            "| fleet | seg | side | real | rep |", "|---|---|---|---|---|"]
    for name, rep in reps:
        for seg in sorted(rep["seg_rows"]):
            for side in ("L", "S"):
                g = rep["seg_rows"][seg][side]
                out.append("| %s | %d | %s | %d / %d / %d / %.1f | %d / %d / %d / %.1f |" % (
                    name, seg, side, g["real"]["S"], g["real"]["R"], g["real"]["A"],
                    g["real"]["open"], g["rep"]["S"], g["rep"]["R"], g["rep"]["A"],
                    g["rep"]["open"]))
    return "\n".join(out) + "\n"


MISS_HEADER = ["fleet", "kind", "seg", "time_ms", "side", "role", "layer", "price", "fill_price",
               "near_dt_ms", "near_dpts", "category"]


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--inputs", required=True)
    ap.add_argument("--runs", required=True)
    ap.add_argument("--harness", required=True)
    ap.add_argument("--ticks", required=True)
    ap.add_argument("--archive-b", required=True)
    ap.add_argument("--archive-c", required=True)
    ap.add_argument("--archive-d", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--t0-price", choices=("deal", "order"), default="deal",
                    help="T0's touch price: deal (plan 1) or order (plan 2, K15)")
    a = ap.parse_args(argv)
    ticks = Ticks.load(a.ticks)
    arch = {"B": a.archive_b, "C": a.archive_c, "D": a.archive_d}
    reps = []
    for name, tag in FLEETS:
        reps.append((name, fleet_report(a.inputs, a.runs, a.harness, tag, ticks,
                                        read_jsonl(arch[name]), a.t0_price)))
    os.makedirs(a.out, exist_ok=True)
    with open(os.path.join(a.out, "report.md"), "w", newline="\n") as f:
        f.write(report_md(reps, a.harness, a.t0_price))
    with open(os.path.join(a.out, "misses.csv"), "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=MISS_HEADER, lineterminator="\n")
        w.writeheader()
        for _name, rep in reps:
            for r in miss_rows(rep):
                w.writerow(r)
    return 0


if __name__ == "__main__":
    sys.exit(main())
