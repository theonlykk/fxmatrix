"""Do live limit fills get a better price than the limit? (Fable pass 1, s4.6 and s6.2 item 2; measured 11 Nov 2026.)

    python research/fills/measure_fills.py <archive_all.jsonl> <sends dir>

Inputs are pipshed's exports (docs/runbooks/winddown-export.md s5): `--export-archive` (fill_logs) and one
`--export-sends` file per instance (send_logs, kept 14 days: from 28 Oct 2026). For every ENT or EXT fill received
from 28 Oct 06:00Z, the resting limit at the fill is the requested price of the order's LAST successful PENDING
(place) or MODIFY send before the fill (EA clock). Improvement in pips: limit - deal for a BUY, deal - limit for a
SELL; positive = better than the limit. The fill log's own `order_price_open` is NOT used: it is the order's first
price, and about 9% of orders were modified before they filled. Fills whose order was placed before the send window
are counted as unmatched. Broker: instance suffix B, C, D = IC Markets demo; E = FTMO trial."""
import collections
import json
import math
import os
import statistics as st
import sys


def broker(instance):
    c = instance.rsplit("_", 1)[1][-1]
    return "IC" if c in "BCD" else ("FTMO" if c == "E" else "older")


def main(archive, sends):
    px = collections.defaultdict(list)
    for fn in sorted(os.listdir(sends)):
        for line in open(os.path.join(sends, fn), encoding="utf-8-sig"):
            if not line.strip():
                continue
            r = json.loads(line)
            if r.get("table") == "_meta" or not r["ok"]:
                continue
            t = r["result_order"] if r["action"] == "PENDING" else r["order_ticket"] if r["action"] == "MODIFY" else None
            if t and r["requested_price"]:
                px[(r["instance_id"], t)].append((r["ea_time_ms"], r["requested_price"]))
    for v in px.values():
        v.sort()
    res, bypair, unmatched, modified = collections.defaultdict(list), collections.defaultdict(list), collections.Counter(), 0
    for line in open(archive, encoding="utf-8-sig"):
        r = json.loads(line)
        if r.get("table") != "fill_logs" or r.get("role") not in ("ENT", "EXT") or str(r["received_at"]) < "2026-10-28 06":
            continue
        hist = px.get((r["instance_id"], r["order_ticket"]))
        before = [p for (t, p) in (hist or []) if t <= r["ea_time_ms"]]
        if not before:
            unmatched[broker(r["instance_id"])] += 1
            continue
        modified += len(hist) > 1
        lim = before[-1]
        imp = ((lim - r["deal_price"]) if r["deal_type"] == "BUY" else (r["deal_price"] - lim)) / 1e-4
        b = broker(r["instance_id"])
        res[(b, r["role"])].append(imp)
        bypair[(b, r["instance_id"].split("_")[1])].append(imp)
    n_all = sum(len(v) for v in res.values())
    print("fills matched %d; unmatched (order placed before 28 Oct) %s; orders modified before the fill %d (%.1f%%)"
          % (n_all, dict(unmatched), modified, 100.0 * modified / max(1, n_all)))
    print("%-16s %5s %8s %6s %7s %8s %8s %6s %6s" % ("", "n", "mean", "se", "median", "better", "at lim", "worse", "worst"))

    def row(label, v):
        v = sorted(v)
        n = len(v)
        print("%-16s %5d %+8.3f %6.3f %+7.2f %7.1f%% %7.1f%% %5.1f%% %+6.1f"
              % (label, n, st.mean(v), st.pstdev(v) / math.sqrt(n), v[n // 2], 100.0 * sum(x > 0.05 for x in v) / n,
                 100.0 * sum(abs(x) <= 0.05 for x in v) / n, 100.0 * sum(x < -0.05 for x in v) / n, v[0]))
    for k in sorted(res):
        row("%s %s" % k, res[k])
    print()
    for k in sorted(bypair):
        if len(bypair[k]) >= 150:
            row("%s %s" % k, bypair[k])


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
