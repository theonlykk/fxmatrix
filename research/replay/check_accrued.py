"""check_accrued.py -- seed column 9 (accrued) against send_logs (fix 3 s8). Read-only; no tests.

usage: python -I -B check_accrued.py <inputs dir> <dir with sends_EURUSD_OPT{B,C,D}_2026-10-09.jsonl
       and archive_EURUSD_OPT{B,C,D}_2026-10-08_2240.jsonl>        (env WIDE=1 for rule W)

For each seed row (segment s, position P: ticket, side, layer) every EXT placement for P's
side and layer is read from send_logs: a PENDING row (role EXT, side, layer_index) and every
MODIFY of an order such a PENDING created. Expected price = round(eff + dir x exit x 0.0001
+ accrued, 5): eff = the latest ROLL_ACCEPTED detail.level for P up to LAG_MS (5 s) after the
placement (a roll's MODIFY is sent just before its event row), else P's seed vl when > 0,
else the entry; exit = the exit pips of the segment that holds the placement.
- Rule N (default): placements from the init to min(the next weekday carry pass at 23:50
  server, the fleet's next init, P's first OUT / OUT_BY deal).
- Rule W (WIDE=1; the GV holds from one pass to the next): from max(the last weekday pass
  before the init + 10 min (the pass reaches each layer within 23:50-23:59), P's open, the
  fleet's first init) to min(the next pass, P's first OUT / OUT_BY deal).
A row is CHECKED when it has a placement; it AGREES when every placement equals the expected
price to the point. Times are server ms (send_logs / ea_events ea_time_ms are UTC: + 3 h).
"""
import csv
import datetime as dt
import json
import sys
from collections import defaultdict

OFF = 3 * 3600 * 1000
LAG = int(__import__("os").environ.get("LAG_MS", "5000"))  # a roll's MODIFY is sent just before its ROLL_ACCEPTED row
EPOCH = dt.datetime(1970, 1, 1)


def ms(d):
    return int((d - EPOCH).total_seconds() * 1000)


def next_pass(init_ms):
    t = EPOCH + dt.timedelta(milliseconds=init_ms)
    d = t.date()
    while True:
        p = dt.datetime.combine(d, dt.time(23, 50))
        if p > t and d.weekday() < 5:
            return ms(p)
        d += dt.timedelta(days=1)


def last_pass(init_ms):
    t = EPOCH + dt.timedelta(milliseconds=init_ms)
    d = t.date()
    while True:
        p = dt.datetime.combine(d, dt.time(23, 50))
        if p <= t and d.weekday() < 5:
            return ms(p)
        d -= dt.timedelta(days=1)


WIDE = __import__("os").environ.get("WIDE") == "1"


def jl(path):
    out = []
    with open(path, encoding="utf-8-sig") as f:
        for line in f:
            line = line.strip()
            if line:
                out.append(json.loads(line))
    return out


def detail(r):
    d = r.get("detail")
    if isinstance(d, dict):
        return d
    return json.loads(d) if d else {}


def run(fleet, inputs, sends_path, archive_path):
    runs = list(csv.DictReader(open("%s/run_eurusd_%s.csv" % (inputs, fleet))))
    sends = [r for r in jl(sends_path) if r.get("table") == "send_logs"]
    arch = jl(archive_path)
    # EXT order tickets -> (side, layer); placements list
    ext_order = {}
    plc = defaultdict(list)          # (side, layer) -> [(srv_ms, price, kind)]
    for r in sends:
        t = int(r["ea_time_ms"]) + OFF
        if r["action"] == "PENDING" and r.get("role") == "EXT" and r.get("ok"):
            key = (r["side"], int(r["layer_index"]))
            if r.get("result_order"):
                ext_order[int(r["result_order"])] = key
            plc[key].append((t, float(r["requested_price"]), "PENDING"))
    for r in sends:
        t = int(r["ea_time_ms"]) + OFF
        if r["action"] == "MODIFY" and r.get("ok") and r.get("order_ticket"):
            key = ext_order.get(int(r["order_ticket"]))
            if key and r.get("requested_price") is not None:
                plc[key].append((t, float(r["requested_price"]), "MODIFY"))
    closes = {}
    for r in arch:
        if r.get("table") == "fill_logs" and r.get("entry_type") in ("OUT", "OUT_BY"):
            p = int(r["position_id"])
            t = int(r["deal_time_broker_msc"])
            closes[p] = min(closes.get(p, t), t)
    rolls = defaultdict(list)
    for r in arch:
        if r.get("table") == "ea_events" and r.get("code") == "ROLL_ACCEPTED":
            d = detail(r)
            rolls[int(d.get("ticket", r.get("ticket") or 0))].append(
                (int(r["ea_time_ms"]) + OFF, float(d["level"])))
    inits = sorted(int(x["from_ms"]) for x in runs)
    res = []
    for x in runs:
        if not x["seed_file"]:
            continue
        s = int(x["seg_id"])
        init = int(x["from_ms"])
        later = [i for i in inits if i > init]
        seed = list(csv.DictReader(open("%s/%s" % (inputs, x["seed_file"]))))
        for p in seed:
            tk = int(p["ticket"])
            side = p["side"]
            lay = int(p["layer_index"])
            if WIDE:
                start = max(last_pass(init) + 600000, int(p["open_ms"]), inits[0])  # the pass reaches each layer within 23:50-23:59
                end = min(next_pass(init), closes.get(tk, 1 << 62))
            else:
                start = init
                end = min([next_pass(init)] + later[:1] + [closes.get(tk, 1 << 62)])
            direction = 1 if side == "L" else -1
            ex = float(x["exit_l"] if side == "L" else x["exit_s"])
            acc = float(p["accrued"])
            got = [q for q in plc[(side, lay)] if start <= q[0] < end]
            bad = []
            for t, price, kind in got:
                lv = [v for (rt, v) in sorted(rolls.get(tk, [])) if rt < t + LAG]
                eff = lv[-1] if lv else (float(p["vl"]) if float(p["vl"]) > 0 else float(p["entry"]))
                if WIDE:
                    seg = [y for y in runs if int(y["from_ms"]) <= t < int(y["to_ms"])]
                    ex = float(seg[0]["exit_l"] if side == "L" else seg[0]["exit_s"])
                exp = round(eff + direction * ex * 0.0001 + acc, 5)
                if abs(exp - price) > 0.000005:
                    bad.append((t, kind, price, exp))
            res.append((fleet, s, side, lay, tk, len(got), bad))
    return res


if __name__ == "__main__":
    inputs, dl = sys.argv[1], sys.argv[2]
    allr = []
    for f in "bcd":
        F = f.upper()
        allr += run(f, inputs, "%s/sends_EURUSD_OPT%s_2026-10-09.jsonl" % (dl, F),
                    "%s/archive_EURUSD_OPT%s_2026-10-08_2240.jsonl" % (dl, F))
    rows = len(allr)
    checked = [r for r in allr if r[5] > 0]
    agree = [r for r in checked if not r[6]]
    pos = {r[4] for r in allr}
    pos_checked = {r[4] for r in checked}
    pos_bad = {r[4] for r in checked if r[6]}
    print("seed rows %d, positions %d" % (rows, len(pos)))
    print("rows checked %d: agree %d, differ %d; unchecked %d"
          % (len(checked), len(agree), len(checked) - len(agree), rows - len(checked)))
    print("positions checked %d: all rows agree %d, some row differs %d; never checked %d"
          % (len(pos_checked), len(pos_checked - pos_bad), len(pos_bad), len(pos - pos_checked)))
    print("placements checked %d" % sum(r[5] for r in allr))
    for r in checked:
        if r[6]:
            for b in r[6]:
                t = EPOCH + dt.timedelta(milliseconds=b[0])
                print("DIFF", r[0], "seg", r[1], r[2], "L%02d" % r[3], r[4], t.strftime("%m-%d %H:%M:%S.%f")[:-3],
                      b[1], "real", b[2], "model", b[3], "d_pts", round((b[2] - b[3]) / 0.00001))
    un = defaultdict(int)
    for r in allr:
        if r[5] == 0:
            un["%s%d" % (r[0].upper(), r[1])] += 1
    print("UNCHECKED", dict(un))
    per = defaultdict(lambda: [0, 0])
    for r in checked:
        per["%s%d" % (r[0].upper(), r[1])][0 if not r[6] else 1] += 1
    print("PER SEG agree/differ", dict(per))
