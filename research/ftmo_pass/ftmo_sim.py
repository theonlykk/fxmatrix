"""FTMO 2-Step pass probability by block bootstrap of real days (C124).

    python ftmo_sim.py --history <history_*.csv> [...] --bars <bidask folder>

Rules (ftmo.com/en/trading-objectives, 2-Step, read 5 Oct; operator):
  capital 10,000; Challenge target +1,000, Verification +500, each from a
  fresh 10,000; daily loss: equity must stay above the day-start BALANCE
  minus 500 (00:00 CE(S)T = 22:00Z); max loss: equity above 9,000;
  at least 4 trading days per phase; no time limit (runs are cut at
  `max_days` and counted unresolved). Funded: 90% of profit paid out,
  the same two loss limits apply. Fee 100 (refund on the first payout:
  a scenario), VPS 20 USD a month.

A simulated day replays one real day's numbers (ftmo_days): equity moves
by dE = r + m1 - m0; the daily test uses the real day's `low` (equity
minus its own day-start balance, so the open loss that day carried in
counts); the max-loss test uses the simulated equity plus the real day's
intraday dip (low - m0). Days are drawn in blocks of consecutive days
from one source, never across sources. The target counts at a day's
end on equity (an open book is flattened at that equity: spread ignored).
"""
import argparse
import glob
import os
import random
import statistics

CAPITAL = 10000.0
DAILY = 500.0
MAXLOSS = 1000.0
MIN_DAYS = 4


def day_numbers(d, shift=0.0):
    """(dE, daily_low_vs_balance, dip_vs_start_equity) of a day record,
    with `shift` USD added to the day's realised P&L (drift sensitivity;
    spread evenly, so the low moves by the whole shift only at the end:
    taken conservatively as min(0, shift) on the low)."""
    dE = d["r"] + d["m1"] - d["m0"] + shift
    low = d["low"] + min(0.0, shift)
    dip = d["low"] - d["m0"] + min(0.0, shift)
    return dE, low, dip


def run_phase(days, target, min_days=MIN_DAYS):
    """Walk an iterable of day records from a fresh 10,000.
    Returns ("pass" | "daily" | "maxloss" | "open", days used, equity)."""
    eq = CAPITAL
    n = 0
    for d in days:
        n += 1
        dE, low, dip = d
        if low < -DAILY:
            return "daily", n, eq + dip
        if eq + dip < CAPITAL - MAXLOSS:
            return "maxloss", n, eq + dip
        eq += dE
        if eq - CAPITAL >= target and n >= min_days:
            return "pass", n, eq
    return "open", n, eq


def draw_block(sources, block, rng):
    """One block: a source chosen in proportion to its length, a random
    start, up to `block` consecutive days of that source (fewer at its end)."""
    s = rng.choices(sources, weights=[len(x) for x in sources])[0]
    a = rng.randrange(len(s))
    return s[a:a + block]


def block_stream(sources, block, rng, shift=0.0, tail=None):
    """Endless day numbers drawn block by block. `tail` = (p, record): each
    day is replaced by `record` with probability p (a tail day the sample
    does not contain, e.g. cycle 2's 23 Sep)."""
    while True:
        for d in draw_block(sources, block, rng):
            if tail is not None and rng.random() < tail[0]:
                d = tail[1]
            yield day_numbers(d, shift)


def take(stream, n):
    for _ in range(n):
        yield next(stream)


def attempt(sources, rng, block=2, shift=0.0, max_days=250, funded_days=250,
            payout_every=21, split=0.9, tail=None):
    """One attempt: Challenge, Verification, then a funded account paid
    every `payout_every` trading days (90% of profit above 10,000, then
    reset to 10,000) until a breach or `funded_days`."""
    res = {"phase1": None, "phase2": None, "days": 0, "payouts": 0.0, "n_payouts": 0,
           "funded_days": 0}
    st = block_stream(sources, block, rng, shift, tail)
    out, n, _ = run_phase(take(st, max_days), 1000.0)
    res["phase1"], res["days"] = out, n
    if out != "pass":
        return res
    st = block_stream(sources, block, rng, shift, tail)
    out, n, _ = run_phase(take(st, max_days), 500.0)
    res["phase2"] = out
    res["days"] += n
    if out != "pass":
        return res
    st = block_stream(sources, block, rng, shift, tail)
    eq = CAPITAL
    k = 0
    for _ in range(funded_days):
        dE, low, dip = next(st)
        k += 1
        if low < -DAILY or eq + dip < CAPITAL - MAXLOSS:
            break
        eq += dE
        if k % payout_every == 0 and eq > CAPITAL:
            res["payouts"] += split * (eq - CAPITAL)
            res["n_payouts"] += 1
            eq = CAPITAL
    res["funded_days"] = k
    return res


def summarise(results, fee=100.0, vps_month=20.0, refund=False, days_per_month=21):
    n = len(results)
    p1 = sum(r["phase1"] == "pass" for r in results) / n
    p2 = sum(r["phase2"] == "pass" for r in results) / n
    fails = {}
    for r in results:
        why = r["phase1"] if r["phase1"] != "pass" else r["phase2"]
        if why != "pass":
            fails[why] = fails.get(why, 0) + 1
    passed = [r for r in results if r["phase2"] == "pass"]
    ev = []
    for r in results:
        months = (r["days"] + r["funded_days"]) / days_per_month
        v = r["payouts"] - fee - vps_month * months
        if refund and r["n_payouts"] > 0:
            v += fee
        ev.append(v)
    return dict(
        n=n, p_challenge=p1, p_both=p2,
        p_verif_given_challenge=(p2 / p1) if p1 else 0.0,
        fails={k: v / n for k, v in sorted(fails.items())},
        days_to_pass_median=statistics.median(r["days"] for r in passed) if passed else None,
        payout_mean_if_passed=statistics.fmean(r["payouts"] for r in passed) if passed else 0.0,
        ev_per_attempt=statistics.fmean(ev),
    )


def main(argv=None):
    import ftmo_days
    ap = argparse.ArgumentParser(description="FTMO 2-Step pass probability (C124)")
    ap.add_argument("--history", action="append", required=True)
    ap.add_argument("--bars", required=True)
    ap.add_argument("--magics", default="", help="comma list: keep positions opened by these")
    ap.add_argument("--n", type=int, default=20000)
    ap.add_argument("--block", type=int, default=2)
    ap.add_argument("--shift", type=float, default=0.0)
    ap.add_argument("--seed", type=int, default=1)
    a = ap.parse_args(argv)
    bars = {}
    for p in glob.glob(os.path.join(a.bars, "*.csv")):
        bars[os.path.basename(p).split("_")[-1][:-4]] = ftmo_days.load_bars(p)
    mg = {int(x) for x in a.magics.split(",") if x} or None
    sources = []
    for h in a.history:
        days = ftmo_days.build_days(ftmo_days.load_history(h), bars, mg)
        print(os.path.basename(h), len(days), "days")
        for d in days:
            print("  day %d  r %+8.2f  m0 %+8.2f  m1 %+8.2f  dE %+8.2f  low %+8.2f  open<=%d"
                  % (d["day"], d["r"], d["m0"], d["m1"], d["r"] + d["m1"] - d["m0"], d["low"], d["n_open_max"]))
        sources.append(days)
    rng = random.Random(a.seed)
    res = [attempt(sources, rng, block=a.block, shift=a.shift) for _ in range(a.n)]
    for refund in (False, True):
        s = summarise(res, refund=refund)
        print("refund" if refund else "no refund", s)


if __name__ == "__main__":
    main()
