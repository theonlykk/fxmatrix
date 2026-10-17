"""How deep would a side go before its first layer scalps out? (fleet D note s5, s8: ALT's adds from our own fills)

    python research/alt_adds/alt_excursions.py --exit-pips 10 <archive export .jsonl> [...]

Read-only; standard library only. Input: `archive_counts.py --export-archive --instance GRIND_<PAIR>_<SLOT>`
(a UTF-8 BOM is tolerated).

Market price samples: every fill_logs IN deal (entries and exits fill at the market) and every
ROLL_ACCEPTED lattice level (the market touched it; the extremes fills alone miss). Never OUT_BY: its
price is the other position's entry (02_TRAPS).

For an anchor (the first sample at or after each UTC hour) a side "opens" there: a short at price p
runs until a sample at or below p - exit (its L0 scalps; every deeper layer has scalped before it); its
EXCURSION is the highest sample minus p in between. A long mirrors it. An anchor never recovered by the
end of the file is CENSORED at its running excursion. A side whose excursion exceeds its stack,
(cap - 1) x add, rolls; the stack that covers a given share of anchors gives ALT's add = stack / (cap - 1).
Hindsight on our own fills at grid resolution: a first guess, not a forecast.
"""
import argparse
import json
import math

BROKER_OFFSET_MS = 10800000  # IC's server runs GMT+3 (BOOT s6, verified 25 Sep)
PIP = 0.0001  # no JPY pair in this set


def load(path):
    """[(utc_ms, price)] sorted by time: IN fills and ROLL_ACCEPTED levels."""
    out = []
    with open(path, encoding="utf-8-sig") as f:
        for line in f:
            if not line.strip():
                continue
            r = json.loads(line)
            t = r.get("table")
            if t == "fill_logs" and r.get("entry_type") == "IN":
                out.append((int(r["deal_time_broker_msc"]) - BROKER_OFFSET_MS, float(r["deal_price"])))
            elif t == "ea_events" and r.get("code") == "ROLL_ACCEPTED":
                lvl = (r.get("detail") or {}).get("level")
                if lvl is not None:
                    out.append((int(r["ea_time_ms"]), float(lvl)))
    out.sort()
    return out


def instance_of(path):
    with open(path, encoding="utf-8-sig") as f:
        return json.loads(f.readline()).get("instance", path)


def anchors(pts, step_ms):
    """Index of the first sample at or after each step boundary that has one."""
    idx, last_bucket = [], None
    for i, (t, _) in enumerate(pts):
        b = t // step_ms
        if b != last_bucket:
            idx.append(i)
            last_bucket = b
    return idx


def excursion(pts, i, side, exit_px):
    """(pips, censored) for a side opened at pts[i]."""
    p = pts[i][1]
    worst = 0.0
    for _, q in pts[i + 1:]:
        if side == "S":
            if q <= p - exit_px + 1e-9:
                return (round(worst / PIP, 1), False)
            worst = max(worst, q - p)
        else:
            if q >= p + exit_px - 1e-9:
                return (round(worst / PIP, 1), False)
            worst = max(worst, p - q)
    return (round(worst / PIP, 1), True)


def quantile(xs, q):
    """Nearest rank: the ceil(q * n)-th smallest."""
    s = sorted(xs)
    k = max(1, math.ceil(q * len(s)))
    return s[k - 1]


def report(path, exit_pips, opt_add, cap_opt, cap_alt, since_ms=None):
    pts = load(path)
    exit_px = exit_pips * PIP
    rows = []
    for side in ("L", "S"):
        ex = []
        cens = 0
        for i in anchors(pts, 3600000):
            if since_ms is not None and pts[i][0] < since_ms:
                continue
            e, c = excursion(pts, i, side, exit_px)
            ex.append(e)
            cens += c
        stack_opt = (cap_opt - 1) * opt_add
        over = sum(1 for e in ex if e > stack_opt)
        q = {k: quantile(ex, k) for k in (0.5, 0.75, 0.9, 0.95, 1.0)}
        rows.append((side, len(ex), cens, stack_opt, over, q,
                     {k: q[k] / (cap_alt - 1) for k in (0.75, 0.9, 0.95)}))
    return pts, rows


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("files", nargs="+")
    ap.add_argument("--exit-pips", type=float, required=True, help="recovery threshold (L0's exit)")
    ap.add_argument("--opt-add", type=float, required=True)
    ap.add_argument("--cap-opt", type=int, default=8)
    ap.add_argument("--cap-alt", type=int, default=7)
    ap.add_argument("--since-utc-ms", type=int, default=None)
    a = ap.parse_args(argv)
    for f in a.files:
        pts, rows = report(f, a.exit_pips, a.opt_add, a.cap_opt, a.cap_alt, a.since_utc_ms)
        print("%s  samples=%d  exit=%s  opt_add=%s  OPT stack=%s" % (
            instance_of(f), len(pts), a.exit_pips, a.opt_add, (a.cap_opt - 1) * a.opt_add))
        for side, n, cens, stack, over, q, alt in rows:
            print("  %s anchors=%d censored=%d over_OPT_stack=%d (%.0f%%)  q50=%.1f q75=%.1f q90=%.1f "
                  "q95=%.1f max=%.1f  ALT add (cap %d) for q75/q90/q95: %.1f / %.1f / %.1f" % (
                      side, n, cens, over, 100.0 * over / max(1, n), q[0.5], q[0.75], q[0.9], q[0.95],
                      q[1.0], a.cap_alt, alt[0.75], alt[0.9], alt[0.95]))


if __name__ == "__main__":
    main()
