"""Tests for research/audcad_oos/run_oos.py (PREREG s6, s8 and the loader of s3). Run:
    python -m pytest -q research/audcad_oos/test_run_oos.py
They need no bar data and no numba compile of the ladder."""
import os
import sys
import tempfile

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import run_oos as ro  # noqa: E402


def r(mean, t, ypos, y, cpos):
    return {"mean": mean, "t": t, "years_pos": ypos, "years": y, "cells_pos": cpos}


def test_years_needed_is_ceil_of_point_six():
    assert [ro.years_needed(y) for y in (3, 4, 5)] == [2, 3, 3]


def test_holds_needs_all_four():
    good = r(12.0, 2.3, 3, 5, 8)
    assert ro.decide(good, good) == "HOLDS"
    assert ro.decide(r(12.0, 1.99, 3, 5, 8), good) == "INCONCLUSIVE"     # t below 2.0
    assert ro.decide(r(12.0, 2.3, 2, 5, 8), good) == "INCONCLUSIVE"      # 2 of 5 years
    assert ro.decide(r(12.0, 2.3, 3, 5, 6), good) == "INCONCLUSIVE"      # 6 of 10 cells
    assert ro.decide(r(12.0, 2.0, 2, 3, 7), good) == "HOLDS"             # Y = 3 needs 2; t exactly 2.0


def test_fails_at_or_below_zero():
    assert ro.decide(r(0.0, 0.0, 0, 5, 0), r(-1.0, -1.0, 0, 5, 0)) == "FAILS"
    assert ro.decide(r(-3.0, -1.5, 1, 5, 2), r(-5.0, -2.0, 0, 5, 1)) == "FAILS"


def test_fragile_when_the_sensitivity_breaks_a_hold():
    assert ro.decide(r(12.0, 2.3, 3, 5, 8), r(8.0, 1.6, 3, 5, 7)) == "FRAGILE"
    assert ro.decide(r(12.0, 2.3, 3, 5, 8), r(-1.0, -0.2, 2, 5, 4)) == "FRAGILE"


def test_gate_needs_every_check():
    assert ro.gate_ok("x\nSELFCHECK: a PASS, b PASS, c PASS, d DONE\n")
    assert not ro.gate_ok("SELFCHECK: a FAIL (2), b PASS, c PASS, d DONE")
    assert not ro.gate_ok("SELFCHECK: a PASS, b PASS, c FAIL (1), d DONE")
    assert not ro.gate_ok("")
    assert not ro.gate_ok(None)


def test_loader_matches_fables_on_a_small_file():
    d = tempfile.mkdtemp()
    p = os.path.join(d, "bars_1514878887_AUDCAD.csv")
    with open(p, "w") as f:
        f.write("# symbol=AUDCAD account=1514878887 server=FTMO-Demo digits=5 point=0.00001000\n")
        f.write("time_server,time_unix_server,open,high,low,close,spread_points,tick_volume\n")
        f.write("2018.01.02 00:02,1514851320,0.98000,0.98010,0.97990,0.98005,25,7\n")
        f.write("2018.01.02 00:03,1514851380,0.98005,0.98020,0.98001,0.98011,18,4\n")
    b = ro.load_bars_file(p)
    os.environ["FR_BARS"], os.environ["FR_CACHE"], os.environ["FR_OUT"] = d, tempfile.mkdtemp(), tempfile.mkdtemp()
    sys.path.insert(0, os.path.join(HERE, "..", "..", "reviews", "fable_pass1"))
    import importlib
    import common  # noqa: E402  (Fable's, unchanged)
    common = importlib.reload(common)               # re-read FR_BARS / FR_CACHE set just above
    c = common.load_bars("AUDCAD")
    assert sorted(b) == sorted(c)
    for k in b:
        assert np.array_equal(b[k], c[k]), k
