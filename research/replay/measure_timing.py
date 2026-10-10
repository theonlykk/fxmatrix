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
    res["M1"] = {a: summary(v) for a, v in
                 durations([s for s in sends if e_lo <= int(s["ea_time_ms"]) <= e_hi]).items()}
    res["M2"] = summary([x for x in (lam(ticks, r) for r in ins) if x is not None])
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
