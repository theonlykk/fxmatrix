"""measure_timing.py -- the broker's and the EA's timing on the calibration window, for the
timing model of the second pre-registration (replay-calibration-eurusd-2.md).

The EA's clock (send_logs / fill_logs ea_time_ms) and the broker's (deal_time_broker_msc,
the tick dump) differ by an offset that drifts within a session, so every measure is a
DURATION or lies within one clock. A send starts at ea_time_ms - duration_ms: ea_time_ms is
stamped when the archive row is queued, after OrderSend returns, and duration_ms is that
blocking call's own GetTickCount64 time (ea/grind_api_counter.mqh Grind_OrderSendCounted).

Measures (each summarised as n, p10, p25, p50, p75, p90, max; index int(n x q) of the
sorted values):
- M1 send duration per action (PENDING, MODIFY, CLOSE_BY, REMOVE; ok rows only), over the
  sends whose ea_time_ms lies between the window's first and last IN fill logs;
- M0 the clock offset: fill log - (deal time - 3 h) per IN fill (reported, never used:
  it shows why no measure crosses the two clocks);
- M1b the sends over 1 s (ok rows, the same sends as M1): count of all;
- M2 lam: a real IN deal's broker time F minus the first touching tick in [F - 2 s,
  F + 0.5 s] (T0's rule: ask <= price for a buy, bid >= price for a sell; ENT on L and EXT
  on S are buys; prices compared in points);
- M3 ENT reaction: the first send starting in [fill log - 50 ms, fill log + 2 s] after an
  ENT fill, minus the fill log time (the fill log is written in the trade event);
- M4 close-by reaction residual, per EXT fill with a CLOSE_BY naming its position (as
  position or position_by; the first starting at or after fill log - 50 ms, within 30 s):
  (close-by start - fill log) - (durations of the sends that start in [fill log - 50 ms,
  close-by start)) - (the first tick after F, minus F). About 0 = the EA sends the close-by
  on the first tick after the fill;
- M5 close-by completion: the position's first OUT_BY at or after F, minus (F + close-by
  start - fill log + the close-by's duration). About 0 = the close-by completes when its
  send returns;
- M6 the gap from the close-by's end to the next send's start (within 2 s; the next send
  starting at or after the end);
- M8 the deal's price: points better than the limit; whether it equals the executable side
  (ask for a buy, bid for a sell) of the newest tick at or before F; and of the newest tick
  at or before (first touch + 261 ms, the model's lam), and by how many points the deal is
  better for us than that price (buy: model - deal; sell: deal - model);
- M7 L0 after the close-by: the first PENDING or MODIFY, role ENT, layer 0, the fill's side,
  starting in [close-by end, close-by end + 120 s], minus fill log, minus (t2 - F), t2 = the
  first tick after F + (close-by end - fill log). About 0 = the L0 goes out on the first
  tick after the close-by.

The window per fleet: from the earliest run row's from_ms to the latest to_ms (server ms)
of run_eurusd_<fleet>.csv; a fill counts when its F lies in it; send_logs are read whole
(each measure starts from a fill in the window).

    python -I -B research/replay/measure_timing.py --inputs DIR --ticks TICKS.csv \
        --dl DIR --out FILE.md
    (DIR holds sends_EURUSD_OPT{B,C,D}_2026-10-09.jsonl and
     archive_EURUSD_OPT{B,C,D}_2026-10-08_2240.jsonl)

Read-only; standard library only; ascii, LF.
"""
import argparse
import bisect
import collections
import csv
import json
import os

ACTIONS = ("PENDING", "MODIFY", "CLOSE_BY", "REMOVE")
LEAD_MS = 50
REACT_MAX_MS = 2000
CB_MAX_MS = 30000
L0_MAX_MS = 120000
LAM_MODEL_MS = 261                   # the timing model's lam (plan 2 s3)
SERVER_OFFSET_MS = 3 * 3600 * 1000   # IC's server time is UTC + 3 (BOOT s6)


def summary(v):
    v = sorted(v)
    n = len(v)
    if n == 0:
        return {"n": 0}
    out = {"n": n}
    for name, q in (("p10", 0.10), ("p25", 0.25), ("p50", 0.50), ("p75", 0.75), ("p90", 0.90)):
        out[name] = v[min(n - 1, int(n * q))]
    out["max"] = v[-1]
    return out


def durations(rows):
    out = collections.defaultdict(list)
    for r in rows:
        if r.get("ok") and r.get("action") in ACTIONS:
            out[r["action"]].append(int(r["duration_ms"]))
    return dict(out)


def clock_offsets(fills):
    return [int(r["ea_time_ms"]) - (int(r["deal_time_broker_msc"]) - SERVER_OFFSET_MS)
            for r in fills if r["entry_type"] == "IN"]


def over_ms(rows, limit):
    ok = [r for r in rows if r.get("ok") and r.get("action") in ACTIONS]
    return (sum(1 for r in ok if int(r["duration_ms"]) > limit), len(ok))


def pts(x):
    return int(round(float(x) * 100000))


class Ticks:
    def __init__(self, t, bid, ask):
        self.t = list(t)
        self.bid = [pts(b) for b in bid]
        self.ask = [pts(a) for a in ask]

    @classmethod
    def load(cls, path):
        t, b, a = [], [], []
        with open(path, encoding="ascii") as fh:
            for line in fh:
                if not line or line[0] in "#t":
                    continue
                p = line.rstrip("\n").split(",")
                t.append(int(p[0]))
                b.append(p[1])
                a.append(p[2])
        return cls(t, b, a)

    def first_after(self, ms):
        i = bisect.bisect_right(self.t, ms)
        return self.t[i] if i < len(self.t) else None


def is_buy(f):
    return (f["side"] == "L") == (f["role"] == "ENT")


def lam(ticks, f):
    fb = int(f["deal_time_broker_msc"])
    px = pts(f["order_price_open"])
    buy = is_buy(f)
    i = bisect.bisect_left(ticks.t, fb - 2000)
    j = bisect.bisect_right(ticks.t, fb + 500)
    for k in range(i, j):
        if (ticks.ask[k] <= px) if buy else (ticks.bid[k] >= px):
            return fb - ticks.t[k]
    return None


def first_touch(ticks, f):
    fb = int(f["deal_time_broker_msc"])
    px = pts(f["order_price_open"])
    buy = is_buy(f)
    i = bisect.bisect_left(ticks.t, fb - 2000)
    j = bisect.bisect_right(ticks.t, fb + 500)
    for k in range(i, j):
        if (ticks.ask[k] <= px) if buy else (ticks.bid[k] >= px):
            return ticks.t[k]
    return None


def market_at(ticks, ms, buy):
    i = bisect.bisect_right(ticks.t, ms) - 1
    if i < 0:
        return None
    return ticks.ask[i] if buy else ticks.bid[i]


def deal_price_class(ticks, f, lam_ms):
    buy = is_buy(f)
    px = pts(f["order_price_open"])
    dp = pts(f["deal_price"])
    out = {"vs_limit": (px - dp) if buy else (dp - px),
           "at_market_F": market_at(ticks, int(f["deal_time_broker_msc"]), buy) == dp}
    t0 = first_touch(ticks, f)
    if t0 is None:
        out["at_model"] = None
        out["model_pts"] = None
        return out
    m = market_at(ticks, t0 + lam_ms, buy)
    out["at_model"] = (m == dp)
    out["model_pts"] = (m - dp) if buy else (dp - m)
    return out


def _start(s):
    return int(s["ea_time_ms"]) - int(s["duration_ms"])


def _sorted_sends(sends):
    ss = sorted(sends, key=_start)
    return ss, [_start(s) for s in ss]


def ent_reaction(sends, f, _cache=None):
    ss, st = _cache if _cache else _sorted_sends(sends)
    fl = int(f["ea_time_ms"])
    i = bisect.bisect_left(st, fl - LEAD_MS)
    if i < len(st) and st[i] <= fl + REACT_MAX_MS:
        return st[i] - fl
    return None


def closeby_chain(ticks, sends, f, outby, _cache=None):
    ss, st = _cache if _cache else _sorted_sends(sends)
    fl = int(f["ea_time_ms"])
    fb = int(f["deal_time_broker_msc"])
    pos = f["position_id"]
    i0 = bisect.bisect_left(st, fl - LEAD_MS)
    cb = None
    k = i0
    while k < len(ss) and st[k] <= fl + CB_MAX_MS:
        s = ss[k]
        if s.get("action") == "CLOSE_BY" and s.get("ok") and pos in (s.get("position_ticket"),
                                                                      s.get("position_by_ticket")):
            cb = k
            break
        k += 1
    if cb is None:
        return None
    t1 = ticks.first_after(fb)
    if t1 is None:
        return None
    c = ss[cb]
    cb_start = st[cb]
    cb_end = int(c["ea_time_ms"])
    ahead = sum(int(ss[m]["duration_ms"]) for m in range(i0, cb))
    out = {"react_resid": (cb_start - fl) - ahead - (t1 - fb)}
    obs = [o for o in outby.get(pos, []) if o >= fb]
    out["outby_resid"] = (min(obs) - (fb + (cb_start - fl) + int(c["duration_ms"]))) if obs else None
    n = bisect.bisect_left(st, cb_end)
    out["next_gap"] = (st[n] - cb_end) if n < len(st) and st[n] - cb_end <= REACT_MAX_MS else None
    out["l0_resid"] = None
    t2 = ticks.first_after(fb + (cb_end - fl))
    m = n
    while t2 is not None and m < len(ss) and st[m] <= cb_end + L0_MAX_MS:
        s = ss[m]
        if (s.get("action") in ("PENDING", "MODIFY") and s.get("role") == "ENT"
                and s.get("layer_index") == 0 and s.get("side") == f["side"]):
            out["l0_resid"] = (st[m] - fl) - (t2 - fb)
            break
        m += 1
    return out


def window(run_rows):
    return (min(int(r["from_ms"]) for r in run_rows), max(int(r["to_ms"]) for r in run_rows))


def read_jsonl(path, table):
    out = []
    with open(path, encoding="utf-8-sig") as fh:
        for line in fh:
            line = line.strip()
            if line:
                r = json.loads(line)
                if r.get("table") == table:
                    out.append(r)
    return out


def measure_fleet(ticks, run_rows, sends, fills):
    lo, hi = window(run_rows)
    fills = [r for r in fills if lo <= int(r["deal_time_broker_msc"]) < hi]
    cache = _sorted_sends(sends)
    outby = collections.defaultdict(list)
    for r in fills:
        if r["entry_type"] == "OUT_BY":
            outby[r["position_id"]].append(int(r["deal_time_broker_msc"]))
    res = {"window": (lo, hi)}
    ins = [r for r in fills if r["entry_type"] == "IN"]
    e_lo = min(int(r["ea_time_ms"]) for r in ins)
    e_hi = max(int(r["ea_time_ms"]) for r in ins)
    win_sends = [s for s in sends if e_lo <= int(s["ea_time_ms"]) <= e_hi]
    res["M1"] = {a: summary(v) for a, v in durations(win_sends).items()}
    res["M1b"] = over_ms(win_sends, 1000)
    res["M0"] = summary(clock_offsets(ins))
    res["M2"] = summary([x for x in (lam(ticks, r) for r in ins) if x is not None])
    pc = [deal_price_class(ticks, r, LAM_MODEL_MS) for r in ins]
    res["M8"] = {"n": len(pc),
                 "at_limit": sum(1 for c in pc if c["vs_limit"] == 0),
                 "better": sum(1 for c in pc if c["vs_limit"] > 0),
                 "worse": sum(1 for c in pc if c["vs_limit"] < 0),
                 "net_pts": sum(c["vs_limit"] for c in pc),
                 "at_market_F": sum(1 for c in pc if c["at_market_F"]),
                 "touched": sum(1 for c in pc if c["at_model"] is not None),
                 "at_model": sum(1 for c in pc if c["at_model"]),
                 "model_within_2": sum(1 for c in pc if c["model_pts"] is not None
                                       and abs(c["model_pts"]) <= 2),
                 "ent_off_2": sum(1 for r, c in zip(ins, pc) if r["role"] == "ENT"
                                  and abs(c["vs_limit"]) > 2),
                 "ent": sum(1 for r in ins if r["role"] == "ENT")}
    res["M3"] = summary([x for x in (ent_reaction(sends, r, cache) for r in ins
                                     if r["role"] == "ENT") if x is not None])
    chains = [closeby_chain(ticks, sends, r, outby, cache) for r in ins if r["role"] == "EXT"]
    chains = [c for c in chains if c is not None]
    res["n_ext"] = sum(1 for r in ins if r["role"] == "EXT")
    res["n_chain"] = len(chains)
    for key, name in (("react_resid", "M4"), ("outby_resid", "M5"), ("next_gap", "M6"),
                      ("l0_resid", "M7")):
        res[name] = summary([c[key] for c in chains if c[key] is not None])
    return res


def fmt(s):
    if s.get("n", 0) == 0:
        return "n 0"
    return "n %d: p10 %d, p25 %d, p50 %d, p75 %d, p90 %d, max %d" % (
        s["n"], s["p10"], s["p25"], s["p50"], s["p75"], s["p90"], s["max"])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--inputs", required=True)
    ap.add_argument("--ticks", required=True)
    ap.add_argument("--dl", required=True)
    ap.add_argument("--out", required=True)
    a = ap.parse_args()
    ticks = Ticks.load(a.ticks)
    lines = ["# Timing on the calibration window (measure_timing.py)", ""]
    for fl in "BCD":
        with open(os.path.join(a.inputs, "run_eurusd_%s.csv" % fl.lower()), encoding="ascii") as fh:
            runs = list(csv.DictReader(fh))
        sends = read_jsonl(os.path.join(a.dl, "sends_EURUSD_OPT%s_2026-10-09.jsonl" % fl), "send_logs")
        fills = read_jsonl(os.path.join(a.dl, "archive_EURUSD_OPT%s_2026-10-08_2240.jsonl" % fl), "fill_logs")
        r = measure_fleet(ticks, runs, sends, fills)
        lines.append("## Fleet %s (window %d - %d server ms; %d EXT fills, %d with a close-by)"
                     % (fl, r["window"][0], r["window"][1], r["n_ext"], r["n_chain"]))
        lines.append("")
        for act in ACTIONS:
            lines.append("- M1 %s duration (ms): %s" % (act, fmt(r["M1"].get(act, {"n": 0}))))
        lines.append("- M1b sends over 1 s: %d of %d" % r["M1b"])
        lines.append("- M0 clock offset, fill log - (deal time - 3 h) (ms): %s" % fmt(r["M0"]))
        m8 = r["M8"]
        lines.append("- M8 deal price: %d deals; at the limit %d, better %d, worse %d (net %+d points); "
                     "= the market at the deal (newest tick at or before F) %d; touched (order price) %d, "
                     "= the market at first touch + %d ms %d, within 0.2 pip of it %d; ENT deals more than "
                     "0.2 pip from the order price %d of %d"
                     % (m8["n"], m8["at_limit"], m8["better"], m8["worse"], m8["net_pts"], m8["at_market_F"],
                        m8["touched"], LAM_MODEL_MS, m8["at_model"], m8["model_within_2"], m8["ent_off_2"], m8["ent"]))
        for name, label in (("M2", "lam, deal - first touch"), ("M3", "ENT reaction"),
                            ("M4", "close-by reaction residual"), ("M5", "OUT_BY - close-by end"),
                            ("M6", "gap after the close-by"), ("M7", "L0 after the close-by, residual")):
            lines.append("- %s %s (ms): %s" % (name, label, fmt(r[name])))
        lines.append("")
    with open(a.out, "w", encoding="ascii", newline="\n") as fh:
        fh.write("\n".join(lines))
    print("\n".join(lines))


if __name__ == "__main__":
    main()
