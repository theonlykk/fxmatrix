"""read_orders.py -- each sync miss of a compare.py run read against the replay's own order log
(fix 4, out_<tag>_sync_orders.csv) and the real fills. Read-only, standard library, no tests (a
reading aid, like classify_misses.py; plan s12 records what it found).

usage: python -B read_orders.py <inputs dir> <runs dir> <harness sha7> <ticks csv> <classified.csv> <out csv>

For each MISS row: the replay orders of that side, layer and role resting at the real fill time
(the state after every order row of that segment before it: a segment starts from its SEED rows), and for each one whether a tick reached its price
between its placement and the real fill (buy limit: ask <= price; sell limit: bid >= price, on
the 0.00001 grid). Also the real ROLL rows of that layer in the 6 h before, and the replay's
LATTICE rows of that layer in the same span. reading:
- AT_PRICE_TOUCHED: a replay order sat at the real price and a tick reached it, no replay fill;
- OTHER_PRICE_ROLLED: the replay order sat elsewhere and the real rolled the layer in the 6 h
  before while the replay's lattice did not touch it;
- OTHER_PRICE: the replay order sat elsewhere, no real roll;
- NO_ORDER: no replay order of that side, layer and role was resting.
Also: price values whose exact touches never fill in any run (both modes).
"""
import bisect, collections, csv, datetime as dt, sys

E = dt.datetime(1970, 1, 1)


def T(ms):
    return (E + dt.timedelta(milliseconds=int(ms))).strftime("%m-%d %H:%M:%S.%f")[:-3]


def ms_of(s):  # 'MM-DD HH:MM:SS.mmm' in 2026, server time
    d = dt.datetime.strptime("2026-" + s[:14], "%Y-%m-%d %H:%M:%S")
    return int((d - E).total_seconds() * 1000) + int(s[15:18])


def pts(x):
    return int(round(x * 100000))


def load_ticks(path):
    tt, bb, aa = [], [], []
    for line in open(path):
        if line[0] == "#" or line.startswith("time"):
            continue
        p = line.split(",")
        tt.append(int(p[0]))
        bb.append(pts(float(p[1])))
        aa.append(pts(float(p[2])))
    return tt, bb, aa


def load_orders(path):
    out = []
    for r in csv.DictReader(open(path)):
        out.append(dict(seg=r["seg_id"], t=int(r["time_ms"]), stage=r["stage"], action=r["action"],
                        ticket=r["ticket"], type=r["type"], side=r["side"], layer=int(r["layer"]),
                        role=r["role"], price=pts(float(r["price"]))))
    return out


def resting(orders, t, side, layer, role, seg):
    book = {}
    for r in orders:
        if r["t"] >= t:
            break
        if r["seg"] != seg or (r["side"], r["layer"], r["role"]) != (side, layer, role):
            continue
        key = (r["seg"], r["ticket"])
        if r["action"] in ("PLACE", "MODIFY"):
            book[key] = (r["price"], r["t"], r["type"])
        else:
            book.pop(key, None)
    return list(book.values())


def touched(ticks, p, t0, t1, buy):
    tt, bb, aa = ticks
    i = bisect.bisect_right(tt, t0)
    j = bisect.bisect_left(tt, t1)
    for k in range(i, j):
        if (aa[k] <= p) if buy else (bb[k] >= p):
            return tt[k]
    return None


def never_filled_values(runs, harness, ticks):
    tt, bb, aa = ticks
    res = collections.defaultdict(lambda: [0, 0])
    for f in "bcd":
        for mode in ("sync", "free"):
            rows = load_orders("%s/eurusd_%s_%s_%s/out_eurusd_%s_%s_orders.csv" % (runs, f, mode, harness, f, mode))
            cur, iv = {}, []
            for r in rows:
                key = (r["seg"], r["ticket"])
                if key in cur:
                    p0, t0, ty = cur.pop(key)
                    iv.append((p0, t0, r["t"], ty, r["action"]))
                if r["action"] in ("PLACE", "MODIFY"):
                    cur[key] = (r["price"], r["t"], r["type"])
            for p, t0, t1, ty, end in iv:
                buy = ty == "BUY_LIMIT"
                i = bisect.bisect_right(tt, t0)
                j = bisect.bisect_left(tt, t1)
                for k in range(i, j):
                    q = aa[k] if buy else bb[k]
                    if q == p:
                        res[(p, buy)][1] += 1
                if end == "FILL":
                    k = bisect.bisect_left(tt, t1)
                    if k < len(tt) and tt[k] == t1 and (aa[k] if buy else bb[k]) == p:
                        res[(p, buy)][0] += 1
    return res


def main():
    inputs, runs, harness, ticks_path, classified, out_path = sys.argv[1:7]
    ticks = load_ticks(ticks_path)
    orders = {f: load_orders("%s/eurusd_%s_sync_%s/out_eurusd_%s_sync_orders.csv" % (runs, f, harness, f))
              for f in "bcd"}
    real = {f: list(csv.DictReader(open("%s/real_eurusd_%s.csv" % (inputs, f)))) for f in "bcd"}
    rows = []
    for m in csv.DictReader(open(classified)):
        if m["kind"] != "MISS":
            continue
        f = m["fleet"].lower()
        t = ms_of(m["time_server"])
        side, layer, role = m["side"], int(m["layer"][1:]), m["role"]
        price = pts(float(m["price"]))
        buy = (side == "L" and role == "ENT") or (side == "S" and role == "EXT")
        rest = resting(orders[f], t, side, layer, role, m["seg"])
        rolls = [int(r["time_ms"]) for r in real[f] if r["kind"] == "ROLL" and r["side"] == side
                 and int(r["layer"]) == layer and t - 21600000 <= int(r["time_ms"]) <= t]
        lat = [r for r in orders[f] if r["stage"] == "LATTICE" and (r["side"], r["layer"], r["role"]) == (side, layer, "EXT")
               and t - 21600000 <= r["t"] <= t]
        at = [x for x in rest if x[0] == price]
        if at and any(touched(ticks, x[0], x[1], t, buy) for x in at):
            reading = "AT_PRICE_TOUCHED"
        elif not rest:
            reading = "NO_ORDER"
        elif rolls and not lat:
            reading = "OTHER_PRICE_ROLLED"
        else:
            reading = "OTHER_PRICE"
        rows.append([m["fleet"], m["seg"], m["time_server"], side, m["layer"], role, m["price"], m["category"], reading,
                     ";".join("%.5f@%s" % (x[0] / 100000.0, T(x[1])[6:]) for x in rest),
                     ";".join(T(x)[6:] for x in rolls), len(lat)])
    w = csv.writer(open(out_path, "w", newline=""), lineterminator="\n")
    w.writerow(["fleet", "seg", "time_server", "side", "layer", "role", "price", "first_pass", "reading",
                "replay_orders_resting", "real_rolls_6h", "replay_lattice_rows_6h"])
    for r in rows:
        w.writerow(r)
    c = collections.Counter((r[7], r[8]) for r in rows)
    for k in sorted(c):
        print(c[k], k[0], k[1])
    res = never_filled_values(runs, harness, ticks)
    fail_only = sorted(k for k, v in res.items() if v[0] == 0 and v[1] > 0)
    both = [k for k, v in res.items() if v[0] > 0 and v[1] > 0]
    print("exact-touch price values (both modes, all fleets): fill only %d, never fill %d (touches %d), both %d"
          % (sum(1 for v in res.values() if v[0] > 0 and v[1] == 0), len(fail_only),
             sum(res[k][1] for k in fail_only), len(both)))
    print("never fill:", " ".join("%.5f%s" % (p / 100000.0, "b" if b else "s") for p, b in fail_only))


if __name__ == "__main__":
    main()
