"""analyse.py -- sweep7 (results/sweep_notes.md, sweep7; pre-registered 12 Oct, before any run).

One flat start a pair at Mon 3 Aug 00:00 server, the book carried to Fri 25 Sep 23:45 through
every weekend; two settings: the pair's live B geometry (as sweep4 ran it) and the same with
width 0.2 (stranded 1.2, deadband 2). Reported, never deciding:

- per pair and setting: S, R, A, realised, commission, the open book at the end, total net
  (sweep.score); requests (non-SEED PLACE / MODIFY / REMOVE in the orders log, plus one
  close-by per close); the worst floating loss and the worst equity over the eight weeks;
- Q1: the live setting carried for eight weeks against the sum of sweep4's eight weekly nets
  at the same geometry (flat every Monday);
- Q2: width 0.2 against the live width;
- the pairs' floating summed in dollars minute by minute (nine pairs, and A's seven), with the
  minutes below -$250 and -$400 (A's float gate and breaker are NOT in the harness).

Self-checks before anything is reported (any failure: STOP): each book rebuilt from the fill log
(ENT appends a layer on its side, EXT removes that side's layer at layer_index) must equal the
harness's end book, its close count must equal the SCALP_CLOSED rows, and its realised pips
must equal theirs within 0.1 pip a close.

  python -B analyse.py <dir with out_sw7_<pair>_free_{events,book,orders}.csv and the h8w ticks>
"""
import collections
import csv
import datetime as dt
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", ".."))

PAIRS = ("eurusd", "gbpusd", "eurgbp", "audcad", "audchf", "cadchf", "nzdchf", "nzdcad", "audnzd")
A_PAIRS = ("eurusd", "gbpusd", "eurgbp", "audchf", "cadchf", "nzdcad", "audnzd")   # A trades seven
SETTINGS = ("live", "live_w0.2")
PTS_PER_PIP = 10
MIN_MS = 60000
DAYS = 40   # trading days, Mon 3 Aug - Fri 25 Sep
THRESHOLDS = (-250.0, -400.0)


def fills_by_seg(events):
    """{seg: [(time_ms, role, side, layer_index, price_pts)]} in file order; close-by deals
    (entry_type OUT_BY) are not book changes."""
    out = collections.defaultdict(list)
    for r in events:
        if '"fill_log"' not in r["json"]:
            continue
        j = json.loads(r["json"])
        if j.get("type") != "fill_log" or j.get("entry_type") != "IN" or j.get("role") not in ("ENT", "EXT"):
            continue
        out[int(r["seg_id"])].append((int(r["time_ms"]), j["role"], j["side"], int(j["layer_index"]),
                                      int(round(float(j["deal_price"]) * 100000))))
    for k in out:
        out[k].sort(key=lambda f: f[0])   # stable: same-time fills keep file order
    return dict(out)


def _apply(book, f):
    """One fill on the book ({side: {layer number: entry pts}}); returns the realised pips of an
    EXT (0.0 for an ENT). layer_index is the layer's NUMBER: a new layer is numbered max + 1 on its
    side (Grind_SideNextIndex, engine 2021-2032) and an EXT carries the number it closes."""
    _t, role, side, layer, px = f
    if role == "ENT":
        if layer in book[side]:
            raise ValueError("ENT %s number %d already open" % (side, layer))
        book[side][layer] = px
        return 0.0
    if layer not in book[side]:
        raise ValueError("EXT %s number %d not open" % (side, layer))
    entry = book[side].pop(layer)
    return ((px - entry) if side == "L" else (entry - px)) / PTS_PER_PIP


def rebuild(fills):
    book = {"L": {}, "S": {}}
    realised, n = 0.0, 0
    for f in fills:
        realised += _apply(book, f)
        n += f[1] == "EXT"
    return {s: list(book[s].values()) for s in ("L", "S")}, realised, n


def check(seg, book, realised, n, harness_book, scalps):
    hb = {"L": [], "S": []}
    for r in harness_book:
        if int(r["seg_id"]) == seg:
            hb[r["side"]].append(int(round(float(r["entry"]) * 100000)))
    for side in ("L", "S"):
        if sorted(book[side]) != sorted(hb[side]):
            raise ValueError("seg %d: rebuilt %s book %s != harness %s" % (seg, side, sorted(book[side]),
                                                                           sorted(hb[side])))
    sc = [json.loads(r["json"]) for r in scalps if r["code"] == "SCALP_CLOSED" and int(r["seg_id"]) == seg]
    if len(sc) != n:
        raise ValueError("seg %d: %d EXT fills != %d SCALP_CLOSED" % (seg, n, len(sc)))
    want = sum(((float(j["exit_price"]) - float(j["entry_price"])) if j["direction"] == "LONG"
                else (float(j["entry_price"]) - float(j["exit_price"]))) * 10000 for j in sc)
    if abs(want - realised) > 0.1 * max(1, n):
        raise ValueError("seg %d: rebuilt realised %.1f != SCALP_CLOSED %.1f" % (seg, realised, want))


class Path:
    """The book marked at every tick (long at bid, short at ask), fills applied when their time
    is at or before the tick's."""

    def __init__(self, fills, comm_pips):
        self.fills, self.i, self.comm_pips = list(fills), 0, comm_pips
        self.book = {"L": {}, "S": {}}
        self.sum = {"L": 0, "S": 0}
        self.realised = self.comm = 0.0
        self.worst_float = self.worst_equity = 0.0
        self.worst_float_t = self.worst_equity_t = None
        self.last_float = self.last_equity = 0.0
        self.last_tick = None
        self.minute_min = {}

    def on_tick(self, t, bid, ask):
        while self.i < len(self.fills) and self.fills[self.i][0] <= t:
            f = self.fills[self.i]
            r = _apply(self.book, f)
            self.sum = {s: sum(self.book[s].values()) for s in ("L", "S")}
            if f[1] == "EXT":
                self.realised += r
                self.comm += self.comm_pips
            self.i += 1
        fl = (len(self.book["L"]) * bid - self.sum["L"] + self.sum["S"] - len(self.book["S"]) * ask) / PTS_PER_PIP
        eq = self.realised - self.comm + fl
        self.last_float, self.last_equity, self.last_tick = fl, eq, (t, bid, ask)
        if fl < self.worst_float:
            self.worst_float, self.worst_float_t = fl, t
        if eq < self.worst_equity:
            self.worst_equity, self.worst_equity_t = eq, t
        m = t // MIN_MS
        if m not in self.minute_min or fl < self.minute_min[m]:
            self.minute_min[m] = fl


def requests(order_rows, closes):
    out = {s: {"place": 0, "modify": 0, "remove": 0, "close": c, "total": c} for s, c in closes.items()}
    for r in order_rows:
        if r["stage"] == "SEED" or r["action"] not in ("PLACE", "MODIFY", "REMOVE"):
            continue
        o = out.setdefault(int(r["seg_id"]), {"place": 0, "modify": 0, "remove": 0, "close": 0, "total": 0})
        o[r["action"].lower()] += 1
        o["total"] += 1
    return out


def fleet_sum(mins, usd):
    """{pair: {minute: floating pips}} -> {minute: dollars}, each pair carried forward from its
    last minute (0 before its first)."""
    last = {p: 0.0 for p in mins}
    out = collections.OrderedDict()
    for m in sorted({m for d in mins.values() for m in d}):
        for p, d in mins.items():
            if m in d:
                last[p] = d[m] * usd[p]
        out[m] = sum(last.values())
    return out


def fleet_worst(s, thresholds):
    worst_m = min(s, key=lambda m: s[m]) if s else None
    return {"worst": s[worst_m] if s else 0.0, "worst_minute": worst_m,
            "below": {th: sum(1 for v in s.values() if v < th) for th in thresholds}}


def server_time(ms):
    return dt.datetime.fromtimestamp(ms / 1000, dt.timezone.utc).strftime("%Y-%m-%d %H:%M")


class _Marks:
    """sweep.score's ticks.mark(at_ms): the last tick before at_ms, recorded while streaming."""

    def __init__(self, last):
        self.last = last

    def mark(self, at_ms):
        return self.last.get(at_ms)


def stream_ticks(path):
    with open(path, encoding="utf-8-sig") as f:
        head = None
        for line in f:
            if line.startswith("#") or not line.strip():
                continue
            parts = line.rstrip("\r\n").split(",")
            if head is None:
                head = parts
                it, ib, ia = head.index("time_msc_server"), head.index("bid"), head.index("ask")
                continue
            yield int(parts[it]), int(round(float(parts[ib]) * 100000)), int(round(float(parts[ia]) * 100000))


def score_pair(pair, d):
    import compare as cmp
    import sweep as sw
    st = sw.get_set("sw7_" + pair)
    rows = sw.build_rows(st["windows"], st["geoms"], st["base"], st["ticks"])
    segs = [{"seg_id": r["seg_id"], "from_ms": r["from_ms"], "to_ms": r["to_ms"]} for r in rows]
    lab = sw.labels(st["windows"], st["geoms"])
    events = cmp.read_events(os.path.join(d, "out_sw7_%s_free_events.csv" % pair))
    book = cmp.read_csv(os.path.join(d, "out_sw7_%s_free_book.csv" % pair))
    orders = cmp.read_csv(os.path.join(d, "out_sw7_%s_free_orders.csv" % pair))
    fl = fills_by_seg(events)
    for s in segs:
        b, real, n = rebuild(fl.get(s["seg_id"], []))
        check(s["seg_id"], b, real, n, book, events)
    paths = {s["seg_id"]: Path(fl.get(s["seg_id"], []), st["comm_pips"]) for s in segs}
    last = {}
    for t, b, a in stream_ticks(os.path.join(d, st["ticks"])):
        for s in segs:
            if s["from_ms"] <= t < s["to_ms"]:
                paths[s["seg_id"]].on_tick(t, b, a)
                last[s["to_ms"]] = (b, a)
    for s in segs:
        p = paths[s["seg_id"]]
        if p.i != len(p.fills):
            raise ValueError("%s seg %d: %d fills after the last tick" % (pair, s["seg_id"], len(p.fills) - p.i))
    sc = sw.score(segs, events, book, _Marks(last), comm_pips=st["comm_pips"])
    closes = {s["seg_id"]: sc[s["seg_id"]]["S"] + sc[s["seg_id"]]["R"] for s in segs}
    rq = requests(orders, closes)
    out = {}
    for s in segs:
        g = lab[s["seg_id"]][0]
        o, p = sc[s["seg_id"]], paths[s["seg_id"]]
        out[g] = dict(o, requests=rq[s["seg_id"]], worst_float=p.worst_float, worst_float_t=p.worst_float_t,
                      worst_equity=p.worst_equity, worst_equity_t=p.worst_equity_t,
                      path_equity=p.last_equity, minute_min=p.minute_min)
    return out, st["pip_usd"]


def sweep4_live_sum(pair):
    with open(os.path.join(HERE, "..", "sweep4", "weekly_%s.csv" % pair), newline="") as f:
        return round(sum(float(r["net"]) for r in csv.DictReader(f) if r["setting"] == "live"), 1)


def main(d):
    res, usd = {}, {}
    for p in PAIRS:
        res[p], usd[p] = score_pair(p, d)
    with open(os.path.join(HERE, "summary.csv"), "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["pair", "setting", "S", "R", "A", "realised", "comm", "open", "open_n", "total_net",
                    "requests", "req_place", "req_modify", "req_remove", "req_close", "worst_float",
                    "worst_float_at", "worst_equity", "worst_equity_at"])
        for p in PAIRS:
            for g in SETTINGS:
                o = res[p][g]
                rq = o["requests"]
                w.writerow([p, g, o["S"], o["R"], o["A"], o["realised"], o["comm"], round(o["open"], 1),
                            o["open_n"], o["total_net"], rq["total"], rq["place"], rq["modify"], rq["remove"],
                            rq["close"], round(o["worst_float"], 1),
                            server_time(o["worst_float_t"]) if o["worst_float_t"] else "",
                            round(o["worst_equity"], 1),
                            server_time(o["worst_equity_t"]) if o["worst_equity_t"] else ""])
    L = ["# sweep7 (pre-registered; one flat start, eight weeks carried; pips at 0.01 lots after "
         "commission; timing 0, carry off, cap 8; reported, never deciding)", "",
         "Self-checks passed: every rebuilt book equals the harness's end book; closes and realised "
         "equal SCALP_CLOSED.", "",
         "## Q1: carried eight weeks (live) against flat every Monday (sweep4, live, 8-week sum)", "",
         "| pair | carried net | sweep4 weekly sum | carried - weekly | open at end (n) | worst floating (at) |",
         "|---|---|---|---|---|---|"]
    for p in PAIRS:
        o = res[p]["live"]
        s4 = sweep4_live_sum(p)
        L.append("| %s | %+.0f | %+.0f | %+.0f | %+.0f (%d) | %+.0f (%s) |" % (
            p.upper(), o["total_net"], s4, o["total_net"] - s4, o["open"], o["open_n"], o["worst_float"],
            server_time(o["worst_float_t"]) if o["worst_float_t"] else "-"))
    L += ["", "## Q2: width 0.2 against the live width (both carried eight weeks)", "",
          "| pair | net live / 0.2 | S live / 0.2 | R live / 0.2 | A live / 0.2 | requests a day live / 0.2 | "
          "worst floating live / 0.2 |", "|---|---|---|---|---|---|---|"]
    for p in PAIRS:
        a, b = res[p]["live"], res[p]["live_w0.2"]
        L.append("| %s | %+.0f / %+.0f | %d / %d | %d / %d | %d / %d | %.0f / %.0f | %+.0f / %+.0f |" % (
            p.upper(), a["total_net"], b["total_net"], a["S"], b["S"], a["R"], b["R"], a["A"], b["A"],
            a["requests"]["total"] / DAYS, b["requests"]["total"] / DAYS, a["worst_float"], b["worst_float"]))
    L += ["", "## The pairs' floating summed in dollars, minute by minute (A's gate and breaker NOT modelled)", "",
          "| setting | pairs | worst (at, server) | minutes below -$250 | minutes below -$400 | net at the end ($) |",
          "|---|---|---|---|---|---|"]
    for g in SETTINGS:
        for name, ps in (("nine", PAIRS), ("A's seven", A_PAIRS)):
            s = fleet_sum({p: res[p][g]["minute_min"] for p in ps}, {p: usd[p] for p in ps})
            fw = fleet_worst(s, THRESHOLDS)
            net = sum(res[p][g]["total_net"] * usd[p] for p in ps)
            L.append("| %s | %s | %+.0f (%s) | %d | %d | %+.0f |" % (
                g, name, fw["worst"], server_time(fw["worst_minute"] * MIN_MS) if fw["worst_minute"] else "-",
                fw["below"][-250.0], fw["below"][-400.0], net))
    txt = "\n".join(L) + "\n"
    with open(os.path.join(HERE, "marks.md"), "w", newline="\n") as f:
        f.write(txt)
    print(txt)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
