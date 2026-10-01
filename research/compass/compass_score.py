"""Compass round scoring (backlog C91; docs/architecture/fleet-d.md s6.5 as
amended by s6.8). Read-only analysis of files; standard library only.

STUB (tests-first commit): only the round loader is real.
"""
import datetime as dt
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "ejection_value"))


def utc(text):
    """'2026-10-01T22:00Z' -> epoch seconds."""
    return dt.datetime.strptime(text, "%Y-%m-%dT%H:%M:%SZ" if text.count(":") == 2
                                else "%Y-%m-%dT%H:%MZ").replace(tzinfo=dt.timezone.utc).timestamp()


def load_round(path):
    with open(path) as fh:
        return json.load(fh)


def load(paths, accounts):
    raise NotImplementedError


def side_metrics(layers, inst, side, windows, entry_cutoff):
    raise NotImplementedError


def threshold_for(cfg, pair, side, twin):
    raise NotImplementedError


def decide(probe, comp, threshold, lever):
    raise NotImplementedError


def score_round(cfg, layers):
    raise NotImplementedError
