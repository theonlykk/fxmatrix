"""C125 verdict: FTMO's equity per day, day-bootstrap (read-only).

    python holdout_verdict.py --history history_1514731800.csv --bars <FTMO bidask folder> [--week2]

docs/research/holdout-verdict-criteria.md s2-s3 (operator 5 Oct ~18:20Z:
"equity matters the most"; Gemini GH-1..GH-6). Each FTMO day of the
window (22:00Z-22:00Z) gives FTMO's change in equity, dE = r + m1 - m0
(`research/ftmo_pass/ftmo_days.build_days`, unchanged): realised plus
the change in open MTM. The day is the unit (GH-1: fills are not
independent; days are drawn with replacement, B resamples, seeded):
  SUPPORTED      the 2.5% quantile of the resampled mean daily change > 0
  NOT SUPPORTED  the total change over the window <= 0
  INCONCLUSIVE   otherwise: extend once (12-16 Oct) and decide on all
                 the days pooled; inconclusive again = NOT SUPPORTED.
"""
import argparse
import glob
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "ftmo_pass"))
import ftmo_days as fd  # noqa: E402

WEEK1 = ("2026-10-05T22:00Z", "2026-10-09T21:00Z")
WEEK2 = ("2026-10-11T22:00Z", "2026-10-16T21:00Z")


def utc(text):
    import datetime as dt
    return dt.datetime.strptime(text, "%Y-%m-%dT%H:%MZ").replace(tzinfo=dt.timezone.utc).timestamp()


def in_window(days, window):
    """Day records whose day STARTS inside [start, end)."""
    raise NotImplementedError("tests first")


def verdict(changes, B=20000, seed=1):
    """{'n', 'total', 'mean', 'lb', 'verdict'} for a list of daily equity changes."""
    raise NotImplementedError("tests first")


def final(week1, week2=None, B=20000, seed=1):
    """The criteria's s3 with the one extension: week1 alone unless it is
    INCONCLUSIVE; then all days pooled, and INCONCLUSIVE again counts as NOT SUPPORTED."""
    raise NotImplementedError("tests first")
