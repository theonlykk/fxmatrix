"""Four years of E's t3 OPT and ALT on FTMO M1 bars, continuously (research/longrun/results.md; descriptive, not
pre-registered).

    python research/longrun/run_bars.py <bars dir> <PAIR> --fill limit > out_limit/cont_<PAIR>.json
    python research/longrun/run_bars.py <bars dir> <PAIR> --fill market > out_market/cont_<PAIR>.json

The engine is research/opt_budget/sim.py (MECHANICS.md). Each M1 bar becomes four ticks 15 s apart: open, then the
low and high in the bar's direction (low first when close >= open), then close; ask = bid + the bar's spread.
--fill market is sim.py as committed: a touched limit deals at the market 261 ms later, which on bar ticks is the
bar's extreme, not the limit (the flaw, results.md s2). --fill limit patches that one line so a touched limit deals
at its own price (on real ticks the two nearly coincide). Output: month-end realised and open per arm, the end
split (scalps, rolled closes, open, commission), holding times of winning and losing closes, open layers' ages."""
import argparse
import csv
import datetime as dt
import json
import os
import sys
import types

HERE = os.path.dirname(os.path.abspath(__file__))
SIM = os.path.join(HERE, "..", "opt_budget", "sim.py")
GEO = {"EURUSD": ((2.0, 7, 3.0), (6.0, 23, 7.0)), "GBPUSD": ((2.5, 9, 3.5), (4.0, 15, 5.0)),
       "EURGBP": ((1.5, 5, 2.5), (6.0, 23, 7.0)), "AUDCAD": ((4.5, 18, 5.5), (6.5, 26, 7.5)),
       "AUDCHF": ((3.5, 14, 4.5), (5.0, 20, 6.0)), "CADCHF": ((2.5, 10, 3.5), (4.5, 17, 5.5))}   # ea/presets_e/*_e_t3.set
USD = {"EURUSD": 0.100, "GBPUSD": 0.100, "EURGBP": 0.134, "AUDCAD": 0.0714, "AUDCHF": 0.122, "CADCHF": 0.122}
COMM = 0.06
MARKET_LINE = "        price = self.ask if o.is_buy else self.bid\n"
LIMIT_LINE = "        price = o.price_at(due)     # LIMIT FILL (bar runs): the limit price, never better\n"


def load_sim(fill):
    src = open(SIM, encoding="utf-8").read()
    if fill == "limit":
        assert src.count(MARKET_LINE) == 1, "sim.py's deal line changed"
        src = src.replace(MARKET_LINE, LIMIT_LINE)
    mod = types.ModuleType("sim_" + fill)
    mod.__dict__["__name__"] = "sim_" + fill
    sys.modules[mod.__name__] = mod
    exec(compile(src, SIM, "exec"), mod.__dict__)
    return mod


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("data")
    ap.add_argument("pair", choices=sorted(GEO))
    ap.add_argument("--fill", choices=("market", "limit"), required=True)
    a = ap.parse_args()
    sim = load_sim(a.fill)
    pair = a.pair
    weeks = {}
    with open(os.path.join(a.data, "bars_1514878887_%s.csv" % pair)) as f:
        f.readline(); f.readline()
        for row in csv.reader(f):
            t = int(row[1]); o, h, l, c = map(float, row[2:6]); sp = int(row[6]) * 1e-5
            d = dt.datetime.fromtimestamp(t, dt.timezone.utc)
            if d.isoweekday() > 5:
                continue
            wk = (d - dt.timedelta(days=d.isoweekday() - 1)).strftime("%Y-%m-%d")
            weeks.setdefault(wk, []).append((t, o, h, l, c, sp))
    tk = []
    for k in sorted(weeks):
        if len(weeks[k]) < 4000:          # skip holiday-short weeks (as the weekly runs did)
            continue
        for (t, o, h, l, c, sp) in weeks[k]:
            for j, p in enumerate([o, l, h, c] if c >= o else [o, h, l, c]):
                tk.append((t * 1000 + j * 15000, round(p, 5), round(p + sp, 5)))
    (wo, ao, so), (wa, aa, sa) = GEO[pair]
    co = sim.Cfg(width=wo, add=ao, exit=ao, cap=7, stranded=so, deadband=2.0)
    ca = sim.Cfg(width=wa, add=aa, exit=aa, cap=7, stranded=sa, deadband=2.0)
    r = sim.run_pair(tk, co, ca)
    u = USD[pair]

    def pips(c):
        return ((c.exit - c.entry) if c.side == "L" else (c.entry - c.exit)) / sim.PIP

    def split(it):
        sc = sum(pips(c) for c in it.closes if not c.rolled)
        rc = sum(pips(c) for c in it.closes if c.rolled)
        return {"scalp": round(sc * u, 2), "rolled": round(rc * u, 2), "open": round(it.open_pips(tk[-1][1], tk[-1][2]) * u, 2),
                "comm": round(-COMM * len(it.closes), 2), "layers": it.open_layers()}

    def holds(it):
        win = [(c.close_ms - c.open_ms) / 3.6e6 for c in it.closes if pips(c) > 0]
        los = [(c.close_ms - c.open_ms) / 3.6e6 for c in it.closes if pips(c) <= 0]
        med = lambda v: sorted(v)[len(v) // 2] if v else None
        ages = [(tk[-1][0] - l.open_ms) / 3.6e6 for sd in it.side.values() for l in sd.layers]
        return {"n_win": len(win), "n_loss": len(los), "med_h_win": med(win), "med_h_loss": med(los),
                "mean_h_win": sum(win) / len(win) if win else None, "mean_h_loss": sum(los) / len(los) if los else None,
                "open_ages_h": sorted(round(x) for x in ages)}
    months = {}
    for (t, vals) in r.marks:
        months[dt.datetime.fromtimestamp(t / 1000, dt.timezone.utc).strftime("%Y-%m")] = vals
    series = []
    for m, vals in sorted(months.items()):
        (ra, oa, na, la), (ro, oo, no, lo) = vals          # ALT first, then OPT (sim.run_pair)
        series.append({"m": m, "opt_real": round(ro * u - COMM * no, 2), "opt_open": round(oo * u, 2), "opt_layers": lo,
                       "alt_real": round(ra * u - COMM * na, 2), "alt_open": round(oa * u, 2), "alt_layers": la})
    print(json.dumps({"pair": pair, "series": series, "opt_end": split(r.opt), "alt_end": split(r.alt),
                      "opt_hold": holds(r.opt), "alt_hold": holds(r.alt)}))


if __name__ == "__main__":
    main()
