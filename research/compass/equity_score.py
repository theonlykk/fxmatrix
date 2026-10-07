"""Compass round scoring on EQUITY (operator 7 Oct ~14:53Z; compass-round s4.4
amendment): from round 2 a probe is decided on its equity change over the
round's windows, realised + change in open MTM; realised is reported beside it.
STUB (tests first).
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "ejection_value"))
import compass_score as cs  # noqa: E402,F401


def mark_side(layers, inst, side, t, bars, pv):
    return None, None


def equity_side(layers, inst, side, windows, bars, pv):
    return {"change": None, "per_day": None, "cash": None, "unpriced": None}


def decide_equity(probe_per_day, comp_per_day, threshold):
    return None, None


def control_threshold_equity(cfg, layers, bars_by_pair, pv_by_pair):
    return {"median": None, "gc1": None, "gaps": []}


def score_round_equity(cfg, layers, bidask, pv=None):
    return {"control": {"gc1": None}, "rows": []}
