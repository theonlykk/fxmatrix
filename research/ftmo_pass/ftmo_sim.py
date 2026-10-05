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
    raise NotImplementedError("C124 stub: tests first")


def draw_block(sources, block, rng):
    raise NotImplementedError("C124 stub: tests first")


def block_stream(sources, block, rng, shift=0.0, tail=None):
    raise NotImplementedError("C124 stub: tests first")


def take(stream, n):
    for _ in range(n):
        yield next(stream)


def attempt(sources, rng, block=2, shift=0.0, max_days=250, funded_days=250,
            payout_every=21, split=0.9, tail=None):
    raise NotImplementedError("C124 stub: tests first")


def summarise(results, fee=100.0, vps_month=20.0, refund=False, days_per_month=21):
    raise NotImplementedError("C124 stub: tests first")


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
