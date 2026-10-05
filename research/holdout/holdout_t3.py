"""C125 T3 driver: the money where T1 says it should be (read-only).

    python holdout_t3.py --export <archive export .jsonl> --bars <bidask folder> [--bars-ic <folder>]

docs/research/holdout-verdict-criteria.md s2 (T3a, T3b, T3c) and s5. Uses
`compass_score.load` and `side_metrics` (unchanged) for realised all-in
net by close time, and `ftmo_days.load_bars` / `usd_per_quote` for marks.
The export should be the ARCHIVE export (every row), so layers opened
more than 14 days before the window still carry their open price.
"""
import argparse
import glob
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "compass"))
sys.path.insert(0, os.path.join(HERE, "..", "ftmo_pass"))
import compass_score as cs  # noqa: E402
import ftmo_days as fd      # noqa: E402

REVERTING = ("GBPUSD", "EURGBP", "NZDCAD")
TRENDING = ("AUDCHF", "NZDCHF", "AUDCAD")
FLEETS = (("A", "OPT"), ("B", "OPTB"), ("C", "OPTC"), ("D", "OPTD"))
ACCOUNTS = [1514731800, 53066709, 53071896, 53077984]
FLEET_PAIRS = {"A": ("EURUSD", "GBPUSD", "EURGBP", "AUDCHF", "CADCHF", "NZDCAD", "AUDNZD")}
WINDOW = ("2026-10-04T22:00Z", "2026-10-09T21:00Z", 5)
MARKS = ("2026-10-04T22:30Z", "2026-10-09T20:45Z")


def inst(pair, slot):
    return "GRIND_%s_%s" % (pair, slot)


def runs(fleet, pair):
    """Does this fleet run this pair (A: the seven-pair ring only)."""
    return pair in FLEET_PAIRS.get(fleet, (pair,))


def realised(layers, instance, t0, t1):
    """Realised all-in net of both sides closed in [t0, t1) (compass_score.side_metrics)."""
    raise NotImplementedError("tests first")


def mtm_mid(layers, instance, t, bars):
    """(open MTM in USD at t marked at the minute mid, layers open at t without a price)."""
    raise NotImplementedError("tests first")


def t3(layers, bars_by_fleet, window=WINDOW, marks=MARKS):
    """T3a, T3b, T3c as in the criteria s2. Returns a dict."""
    raise NotImplementedError("tests first")
