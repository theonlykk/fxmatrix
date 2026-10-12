"""sweep.py -- geometry sweeps on the frozen replay harness (145f092), by input files only.

build: one run_<tag>.csv row per (geometry, day window), each segment starting FLAT (empty
seed and orders files, as segment 20 of run_eurusd_d.csv, D's flat start on 1 Oct); the
other inputs as the live B / C / D EURUSD rows since 7 Oct (width 2, stranded 3, deadband 2,
lattice on, re-roll on, roll gate 0, carry on).
score: per segment from the run's FREE outputs: S (scalps, rolled false), R (roll closes),
A (ROLL_ACCEPTED), realised pips (the SCALP_CLOSED entry and exit prices), commission
(comm_pips per close), the open book at the end marked at the last tick before the
segment's end, total = realised - commission + open.

Pre-holdout ticks only (w2 ends 9 Oct 01:30 server; plan 3's holdout is not read).
Not a plan 3 mark: plan 3 fits the replay at the LIVE geometries; other geometries are
indicative only (plan 3 s5).

  python -B sweep.py build --tag sweep1 --out inputs/sweep1/run_sweep1.csv
  python -B sweep.py score --tag sweep1 --run <run csv> --events <out events> --book <out book>
                           --ticks <w2 ticks csv> --out <report.md>
"""
import argparse
import calendar
import datetime as dt
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_segments as bs  # noqa: E402
import compare as cmp  # noqa: E402

HEADER = tuple(bs.RUN_HEADER.split(","))
TICKS_FILE = "ticks_53077984_EURUSD_w2.csv"
BASE = {"instance": "GRIND_EURUSD_OPTD", "magic": 22260201,
        "width_l": 2.0, "width_s": 2.0, "stranded": 3.0, "deadband": 2.0,
        "lattice": 1, "reroll": 1, "gate": 0, "carry": 1,
        "fill_time_place": bs.FILL_TIME_PLACE, "reserve": bs.RESERVE}
COMM_PIPS = 0.7   # $3.5 / lot / side: $0.07 per 0.01-lot round trip = 0.7 EURUSD pips

DAYS = ("2026-10-01", "2026-10-02", "2026-10-05", "2026-10-06", "2026-10-07", "2026-10-08")
# server 01:00 (after the rollover spread) to 23:45 (before the 23:50 carry pass)
WINDOWS = tuple((d, d + " 01:00", d + " 23:45") for d in DAYS)
WEEK = (("1-8 Oct", "2026-10-01 04:00", "2026-10-08 23:45"),)   # w2's first tick is 04:00 server
SETS = {
    # daily flat starts: your 5 / 5 / 8 and B's live 7 / 10 / 8
    "sweep1": (WINDOWS, (("a5e5n8", 5.0, 5.0, 8), ("a7e10n8", 7.0, 10.0, 8))),
    # one flat start, the book carried all week: a x e at N 8, and N 6 / 10 at 7 / 10
    "sweep2": (WEEK, tuple(("a%ge%gn8" % (a, e), float(a), float(e), 8)
                           for a in (5, 6, 7) for e in (5, 7, 10))
               + (("a7e10n6", 7.0, 10.0, 6), ("a7e10n10", 7.0, 10.0, 10))),
}


# sweep3: the nine IC pairs. width = the live B width (register, 9 Oct); USD per pip at 0.01
# lots measured from scalps (HANDOFF 2026-09-20; NZDCHF "near 0.12", FULL_TRIAL_RECORD)
PAIRS = {"EURUSD": (2.0, 0.100), "GBPUSD": (2.5, 0.100), "EURGBP": (1.0, 0.134),
         "AUDCAD": (1.5, 0.0714), "AUDCHF": (1.5, 0.122), "CADCHF": (1.0, 0.122),
         "NZDCHF": (1.0, 0.120), "NZDCAD": (2.0, 0.0717), "AUDNZD": (2.0, 0.0574)}
COMM_USD = 0.06   # 0.03 a fill at 0.01 lots on ENT and EXT (measured, HANDOFF 2026-09-20)
GRID3 = tuple(("a%ge%gn%d" % (a, e, n), a, e, n, None)
              for a in (2.5, 5.0, 7.5, 10.0) for e in (2.5, 5.0, 7.5, 10.0) for n in (6, 8, 10))


# live B geometry (add, exit) per pair, cap 8 (register, LIVE NOW, 9 Oct)
LIVE_B = {"EURUSD": (7.0, 10.0), "GBPUSD": (9.0, 10.0), "EURGBP": (3.0, 5.0), "AUDCAD": (6.0, 10.0),
          "AUDCHF": (4.0, 10.0), "CADCHF": (4.0, 10.0), "NZDCHF": (3.0, 10.0), "NZDCAD": (8.0, 10.0),
          "AUDNZD": (8.0, 10.0)}
WEEKS4 = ("2026-08-03", "2026-08-10", "2026-08-17", "2026-08-24", "2026-08-31",
          "2026-09-07", "2026-09-14", "2026-09-21")
GRID4 = tuple(("a%ge%gn10" % (a, e), a, e, 10, None) for a in (5.0, 7.5, 10.0) for e in (5.0, 7.5, 10.0)) + \
    tuple(("a%ge%gn%d" % (a, a, n), a, a, n, None) for a in (7.5, 10.0) for n in (6, 8))


# sweep6: ADR-167's light-side add tables (ADR 3.3) in the run file's optional 24th column
# (branch replay-adr167; "" = off). Three cap-8 settings that sweep4 already ran.
TABLES6 = (("off", ""), ("step", "1;1;1;0.5"), ("lin", "0.93;0.86;0.79;0.71;0.64;0.57;0.5"),
           ("dz", "1;1;0.9;0.8;0.7;0.6;0.5"))
BASES6 = (("a7.5e7.5n8", 7.5, 7.5, 8), ("a10e10n8", 10.0, 10.0, 8))


GRID5 = (("a5e5n10", 5.0, 5.0, 10, None), ("a7.5e7.5n6", 7.5, 7.5, 6, None),
         ("a7.5e7.5n10", 7.5, 7.5, 10, None), ("a10e10n6", 10.0, 10.0, 6, None),
         ("a10e10n10", 10.0, 10.0, 10, None))


def _days(monday):
    d0 = dt.datetime.strptime(monday, "%Y-%m-%d")
    return [(d0 + dt.timedelta(days=k)).strftime("%Y-%m-%d") for k in range(5)]


def _friday(monday):
    d = dt.datetime.strptime(monday, "%Y-%m-%d") + dt.timedelta(days=4)
    return d.strftime("%Y-%m-%d")


def get_set(tag):
    """windows, geoms (name, add, exit, cap, carry or None), base inputs, ticks file,
    commission in pips per close, USD per pip at 0.01 lots."""
    if tag in SETS:
        windows, geoms = SETS[tag]
        return {"windows": windows, "geoms": tuple(tuple(g) + (None,) * (5 - len(g)) for g in geoms),
                "base": dict(BASE), "ticks": TICKS_FILE, "comm_pips": COMM_PIPS, "pip_usd": 0.10}
    if tag.startswith("sw4_") and tag[4:].upper() in PAIRS:
        pair = tag[4:].upper()
        width, pip_usd = PAIRS[pair]
        base = dict(BASE)
        base.update({"width_l": width, "width_s": width, "stranded": width + 1.0, "carry": 0})
        windows = tuple((m, m + " 00:00", _friday(m) + " 23:45") for m in WEEKS4)
        geoms = GRID4 + (("live",) + LIVE_B[pair] + (8, None),)
        return {"windows": windows, "geoms": geoms, "base": base,
                "ticks": "ticks_53077984_%s__h8w.csv" % pair,
                "comm_pips": COMM_USD / pip_usd, "pip_usd": pip_usd}
    if tag.startswith("sw6_") and tag[4:].upper() in PAIRS:
        st = get_set("sw4_" + tag[4:])
        bases = (("live",) + LIVE_B[tag[4:].upper()] + (8,),) + BASES6
        st["geoms"] = tuple(("%s_%s" % (b[0], tn), b[1], b[2], b[3], None, table)
                            for b in bases for tn, table in TABLES6)
        return st
    if tag.startswith("sw5_") and tag[4:].upper() in PAIRS:
        st = get_set("sw4_" + tag[4:])
        st["windows"] = tuple((d, d + " 01:00", d + " 23:45") for m in WEEKS4 for d in _days(m))
        st["geoms"] = GRID5 + (st["geoms"][-1],)
        return st
    if not tag.startswith("sw3_") or tag[4:].upper() not in PAIRS:
        raise KeyError(tag)
    pair = tag[4:].upper()
    width, pip_usd = PAIRS[pair]
    base = dict(BASE)
    base.update({"width_l": width, "width_s": width, "stranded": width + 1.0, "carry": 0})
    geoms = GRID3
    ticks = "ticks_53077984_%s__w2.csv" % pair
    if pair == "EURUSD":
        ticks = TICKS_FILE
        geoms = GRID3 + (("a7e10n8c", 7.0, 10.0, 8, 1), ("a5e5n8c", 5.0, 5.0, 8, 1))
    return {"windows": WEEK, "geoms": geoms, "base": base, "ticks": ticks,
            "comm_pips": COMM_USD / pip_usd, "pip_usd": pip_usd}


def server_ms(s):
    return calendar.timegm(dt.datetime.strptime(s, "%Y-%m-%d %H:%M").timetuple()) * 1000


def build_rows(windows, geoms, base=None, ticks=TICKS_FILE):
    rows = []
    for g in geoms:
        name, add, ext, cap = g[:4]
        carry = g[4] if len(g) > 4 else None
        for _day, frm, to in windows:
            r = dict(BASE if base is None else base)
            r.update({"seg_id": len(rows) + 1, "from_ms": server_ms(frm), "to_ms": server_ms(to),
                      "add_l": add, "add_s": add, "exit_l": ext, "exit_s": ext, "cap": cap,
                      "seed_file": "", "ticks_file": ticks, "orders_file": ""})
            if carry is not None:
                r["carry"] = carry
            if len(g) > 5 and g[5] is not None:
                r["light_add"] = g[5]
            rows.append(r)
    return rows


def labels(windows, geoms):
    out, k = {}, 0
    for name, *_g in geoms:
        for day, *_w in windows:
            k += 1
            out[k] = (name, day)
    return out


def to_csv(rows, ticks=TICKS_FILE):
    """The harness run file. Rows that carry "light_add" (sweep6) add the optional 24th column
    (ADR-167 replay build); every other set is written exactly as before."""
    text = bs.to_run_csv(rows, ticks, [""] * len(rows), first_id=rows[0]["seg_id"])
    if not any("light_add" in r for r in rows):
        return text
    lines = text.rstrip("\n").split("\n")
    out = [lines[0] + ",light_add"]
    for r, line in zip(rows, lines[1:]):
        out.append(line + "," + r.get("light_add", ""))
    return "\n".join(out) + "\n"


def surface(geoms, nets):
    """One table per layer count: rows add, columns exit, cells net pips."""
    adds = sorted({g[1] for g in geoms if g[4] is None})
    exits = sorted({g[2] for g in geoms if g[4] is None})
    caps = sorted({g[3] for g in geoms if g[4] is None})
    by = {(g[1], g[2], g[3]): g[0] for g in geoms if g[4] is None}
    out = []
    for n in caps:
        out.append("| layers %d | %s |" % (n, " | ".join("exit %g" % e for e in exits)))
        out.append("|---|%s" % ("---|" * len(exits)))
        for a in adds:
            cells = []
            for e in exits:
                name = by.get((a, e, n))
                cells.append("-" if name is None or name not in nets else "%+.0f" % nets[name])
            out.append("| add %g | %s |" % (a, " | ".join(cells)))
        out.append("")
    return "\n".join(out)


def scalp_pips(direction, entry, exit_):
    d = (float(exit_) - float(entry)) if direction == "LONG" else (float(entry) - float(exit_))
    return round(d * 10000, 1)


def score(segs, events, book_rows, ticks, comm_pips=COMM_PIPS):
    out = {s["seg_id"]: {"S": 0, "R": 0, "A": 0, "realised": 0.0, "comm": 0.0,
                         "open": 0.0, "open_n": 0} for s in segs}
    for r in events:
        seg = int(r["seg_id"])
        if seg not in out:
            continue
        if r["code"] == "SCALP_CLOSED":
            j = json.loads(r["json"])
            o = out[seg]
            o["R" if j["rolled"] else "S"] += 1
            o["realised"] += scalp_pips(j["direction"], j["entry_price"], j["exit_price"])
            o["comm"] += comm_pips
        elif r["code"] == "ROLL_ACCEPTED":
            out[seg]["A"] += 1
    books = {}
    for b in book_rows:
        books.setdefault(int(b["seg_id"]), []).append({"side": b["side"], "pts": cmp.pts(b["entry"])})
    for s in segs:
        o = out[s["seg_id"]]
        bk = books.get(s["seg_id"], [])
        mk = ticks.mark(s["to_ms"])
        if bk and mk:
            o["open"] = cmp.open_pips(bk, "L", mk[0], mk[1]) + cmp.open_pips(bk, "S", mk[0], mk[1])
        o["open_n"] = len(bk)
        o["realised"] = round(o["realised"], 1)
        o["comm"] = round(o["comm"], 1)
        o["total_net"] = round(o["realised"] - o["comm"] + o["open"], 1)
    return out


def edge(parts):
    """parts: (S, R, e, D, open pips) per segment, all one geometry. k* = D/e - 1 (zero
    cost), S/R, rho = (S + R) e / (R D) (1 on a random walk), and rho_open with each
    segment's open loss counted as rolls in waiting (compare.rho, C141)."""
    S = sum(p[0] for p in parts)
    R = sum(p[1] for p in parts)
    e, D = parts[0][2], parts[0][3]
    return {"k": D / e - 1, "sr": (S / R) if R else None,
            "rho": cmp.rho([(s, r, ee, dd, 0.0) for s, r, ee, dd, _o in parts]),
            "rho_open": cmp.rho(parts)}


def _f(x, fmt="%.2f"):
    return "-" if x is None else fmt % x


def report(tag, segs, lab, sc, geoms=None, comm_pips=COMM_PIPS, pip_usd=0.10):
    lines = ["# Sweep %s (harness 145f092, FREE, flat start at each window; pips at 0.01 lots, "
             "$%.4g a pip, commission %.2f pip a close)" % (tag, pip_usd, comm_pips),
             "",
             "| geometry | day | S | R | A | realised | commission | open (n) | total net |",
             "|---|---|---|---|---|---|---|---|---|"]
    tot = {}
    for s in segs:
        g, d = lab[s["seg_id"]]
        o = sc[s["seg_id"]]
        lines.append("| %s | %s | %d | %d | %d | %+.1f | %.1f | %+.1f (%d) | %+.1f |" % (
            g, d, o["S"], o["R"], o["A"], o["realised"], o["comm"], o["open"], o["open_n"], o["total_net"]))
        t = tot.setdefault(g, {"S": 0, "R": 0, "A": 0, "realised": 0.0, "comm": 0.0, "open": 0.0, "total_net": 0.0})
        for k in t:
            t[k] += o[k]
    lines += ["", "| geometry | S | R | A | S/R | realised | open (sum) | gross (before commission) | commission | total net |",
              "|---|---|---|---|---|---|---|---|---|---|"]
    for g, t in tot.items():
        sr = ("%.2f" % (t["S"] / t["R"])) if t["R"] else "-"
        lines.append("| %s | %d | %d | %d | %s | %+.1f | %+.1f | %+.1f | %.1f | %+.1f |" % (
            g, t["S"], t["R"], t["A"], sr, t["realised"], t["open"], t["realised"] + t["open"],
            t["comm"], t["total_net"]))
    if geoms:
        lines += ["", "| geometry | k* = N a / e - 1 | S/R | rho (closed only) | rho (open book as rolls) |",
                  "|---|---|---|---|---|"]
        for name, add, ext, cap, *_c in geoms:
            parts = [(sc[s["seg_id"]]["S"], sc[s["seg_id"]]["R"], ext, cap * add, sc[s["seg_id"]]["open"])
                     for s in segs if lab[s["seg_id"]][0] == name]
            e = edge(parts)
            lines.append("| %s | %.2f | %s | %s | %s |" % (name, e["k"], _f(e["sr"]), _f(e["rho"]), _f(e["rho_open"])))
    if geoms and tag.startswith("sw3_"):
        nets = {g: t["total_net"] for g, t in tot.items()}
        gross = {g: t["realised"] + t["open"] for g, t in tot.items()}
        lines += ["", "## Net pips (after commission)", "", surface(geoms, nets),
                  "## Gross pips (before commission)", "", surface(geoms, gross)]
    return "\n".join(lines) + "\n"


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=("build", "score"))
    ap.add_argument("--tag", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--run")
    ap.add_argument("--events")
    ap.add_argument("--book")
    ap.add_argument("--ticks")
    a = ap.parse_args(argv)
    st = get_set(a.tag)
    windows, geoms = st["windows"], st["geoms"]
    if a.cmd == "build":
        os.makedirs(os.path.dirname(a.out) or ".", exist_ok=True)
        with open(a.out, "w", newline="\n") as f:
            f.write(to_csv(build_rows(windows, geoms, st["base"], st["ticks"]), st["ticks"]))
        return 0
    segs = cmp.segments(cmp.read_csv(a.run))
    sc = score(segs, cmp.read_events(a.events), cmp.read_csv(a.book), cmp.Ticks.load(a.ticks),
               comm_pips=st["comm_pips"])
    with open(a.out, "w", newline="\n") as f:
        f.write(report(a.tag, segs, labels(windows, geoms), sc, geoms, st["comm_pips"], st["pip_usd"]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
