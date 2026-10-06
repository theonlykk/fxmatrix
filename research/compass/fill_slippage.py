"""Fill slippage of entry limits per fleet, pair and side (backlog C132;
Gemini GR2-4, docs/research/compass-round2-review.md s6). Reported at a
compass round's scoring, never deciding. Read-only on the study export;
standard library only.

    python research/compass/fill_slippage.py --export <study_export.jsonl> --round research/compass/round2.json [--baseline research/compass/round1.json]
    python -m unittest research/compass/test_fill_slippage.py -v

Source: fill_logs rows with role ENT and entry_type IN. `slippage_pips` is
the EA's own number (grind_archive.mqh 425-434, test AR12): BUY (order -
deal) / pip, SELL (deal - order) / pip, so POSITIVE = filled better than the
limit, NEGATIVE = worse. Fill time = deal_time_broker_msc (server clock) -
the server offset (GMT+3 until the November clock change).
Fleets: the instance id's last letter B, C or D; anything else is A (FTMO).
A is left out by default (the holdout window is open; criteria s6).
"""
import argparse
import json
import os
import statistics
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import compass_score as cs  # noqa: E402

SERVER_OFFSET_S = 10800
HALF = -0.5


def fleet_of(instance_id):
    raise NotImplementedError


def pair_of(instance_id):
    raise NotImplementedError


def entry_fills(rows, fleets=("B", "C", "D"), offset_s=SERVER_OFFSET_S):
    raise NotImplementedError


def in_windows(t, windows):
    raise NotImplementedError


def stats(values):
    raise NotImplementedError


def table(fills, windows):
    raise NotImplementedError


def outliers(fills, windows, below=-5.0):
    raise NotImplementedError
