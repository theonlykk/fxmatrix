"""Drive sim.py on the replay's inputs: the t3 cells' segments from the run files, ticks, swaps, sessions.
python runs.py oct|calm --data DIR --out FILE [--budget]"""
import argparse, csv, json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sim

T3 = {"GBPUSD": (9, 15), "EURUSD": (7, 23), "EURGBP": (5, 23), "AUDCAD": (18, 26), "AUDCHF": (14, 20), "CADCHF": (10, 17)}


def read_csv(p):
    with open(p, encoding="utf-8-sig") as f:
        return list(csv.DictReader(l for l in f if not l.startswith("#")))


def load_ticks(p):
    out = []
    with open(p, encoding="utf-8-sig") as f:
        head = None
        for line in f:
            if line.startswith("#") or not line.strip():
                continue
            parts = line.rstrip("\n").split(",")
            if head is None:
                head = parts
                it, ib, ia = head.index("time_msc_server"), head.index("bid"), head.index("ask")
                continue
            out.append((int(parts[it]), float(parts[ib]), float(parts[ia])))
    return out


def load_swaps(p):
    rows = {}
    for r in read_csv(p):
        rows[r["server_date"]] = (float(r["points_long"]), float(r["points_short"]), float(r["mult"]))
    return rows


def load_sessions(p):
    s = {}
    for r in read_csv(p):
        a, b = r["trade_from"].split(":"), r["trade_to"].split(":")
        s[int(r["day_of_week"])] = (int(a[0]) * 60 + int(a[1]), int(b[0]) * 60 + int(b[1]))
    return s


def seg_cfg(row):
    return sim.Cfg(width=float(row["width_l"]), add=float(row["add_l"]), exit=float(row["exit_l"]),
                   cap=int(row["cap"]), stranded=float(row["stranded"]), deadband=float(row["deadband"]),
                   lattice=row["lattice"] == "1", reroll=row["reroll"] == "1", gate=int(row["gate"]),
                   carry=row["carry"] == "1")


def opt_cfg(row, cap):
    c = seg_cfg(row)
    if cap is not None:
        c.cap = int(cap)
    return c


def oct_run_file(pair, add):
    if pair == "EURUSD":
        return "run_sw9_d7.csv"
    if pair == "EURGBP" and add == 5:
        return "run_sw11o_eurgbp.csv"
    return "run_sw10_%s.csv" % pair.lower()


def find_rows(data, fname, add):
    return [r for r in read_csv(os.path.join(data, fname)) if float(r["add_l"]) == add and int(r["cap"]) == 7]


def window(ticks, a, b):
    import bisect
    ts = [t[0] for t in ticks]
    return ticks[bisect.bisect_left(ts, a):bisect.bisect_right(ts, b)]


def run(period, data, budget, pairs, variant="B", opt_cap=None):
    sessions = load_sessions(os.path.join(data, "sessions_eurusd_ic.csv"))
    out = {}
    for pair in pairs:
        o_add, a_add = T3[pair]
        if period == "oct":
            ro = find_rows(data, oct_run_file(pair, o_add), o_add)
            ra = find_rows(data, oct_run_file(pair, a_add), a_add)
            assert len(ro) == 1 and len(ra) == 1, (pair, len(ro), len(ra))
            segs = [(ro[0], ra[0])]
            swaps = load_swaps(os.path.join(data, "swaps_EURUSD_window.csv" if pair == "EURUSD" else "swaps_%s.csv" % pair))
        else:
            fn = "run_sw11w_%s.csv" % pair.lower()
            ro, ra = find_rows(data, fn, o_add), find_rows(data, fn, a_add)
            assert len(ro) == 8 and len(ra) == 8, (pair, len(ro), len(ra))
            segs = list(zip(sorted(ro, key=lambda r: int(r["from_ms"])), sorted(ra, key=lambda r: int(r["from_ms"]))))
            swaps = None
        tk_all = load_ticks(os.path.join(data, segs[0][0]["ticks_file"]))
        res = []
        for so, sa in segs:
            assert so["from_ms"] == sa["from_ms"] and so["to_ms"] == sa["to_ms"] and so["ticks_file"] == sa["ticks_file"]
            co, ca = opt_cfg(so, opt_cap), seg_cfg(sa)
            tk = window(tk_all, int(so["from_ms"]), int(so["to_ms"]))
            r = sim.run_pair(tk, co, ca, carry_rows=swaps if co.carry else None, budget=budget, sessions=sessions,
                             variant=variant)
            def summ(it):
                S = sum(1 for c in it.closes if not c.rolled)
                R = sum(1 for c in it.closes if c.rolled)
                bd = {}
                for c in it.closes:
                    v = bd.setdefault(str(c.depth_open), [0, 0.0, 0, 0.0])
                    pips = ((c.exit - c.entry) if c.side == "L" else (c.entry - c.exit)) / sim.PIP + c.swap_pips
                    if c.rolled:
                        v[2] += 1; v[3] = round(v[3] + pips, 1)
                    else:
                        v[0] += 1; v[1] = round(v[1] + pips, 1)
                return {"S": S, "R": R, "A": it.rolls, "realised": round(it.realised_pips(), 1),
                        "open": round(it.open_pips(tk[-1][1], tk[-1][2]), 1), "by_depth": bd}
            res.append({"from_ms": int(so["from_ms"]), "to_ms": int(so["to_ms"]), "ticks": len(tk),
                        "OPT": summ(r.opt), "ALT": summ(r.alt), "occ": r.occ,
                        "marks": [(m[0], m[1][1][0], m[1][1][1], m[1][1][2], m[1][0][0], m[1][0][1], m[1][0][2],
                                   m[1][1][3], m[1][0][3]) for m in r.marks]})
            print(pair, so["from_ms"], "OPT", res[-1]["OPT"], "ALT", res[-1]["ALT"], flush=True)
        out[pair] = res
    return out


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("period", choices=["oct", "calm"])
    ap.add_argument("--data", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--budget", action="store_true")
    ap.add_argument("--pairs", default=",".join(T3))
    ap.add_argument("--variant", default="B", choices=["B", "B2"])
    ap.add_argument("--opt-cap", type=int, default=None)
    a = ap.parse_args()
    res = run(a.period, a.data, a.budget, a.pairs.split(","), a.variant, a.opt_cap)
    with open(a.out, "w") as f:
        json.dump(res, f)
