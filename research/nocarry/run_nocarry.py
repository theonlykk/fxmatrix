"""No-carry runner (research/nocarry/PREREG.md): E's t3 OPT and ALT on FTMO M1 bars, CONT / DAY / WEEK.

STUB: the interface the tests (test_nocarry.py) are written against. Every function raises until the runner is
written, in its own commit, after the tests."""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "longrun"))
import run_bars  # noqa: E402

sim = run_bars.load_sim("limit")
COMM = run_bars.COMM


def cut(it, t, bid, ask, worse=0.0):
    """PREREG s3 on one Instance at the cut tick t (after run_events): returns the cut Close records (c.cut = True)."""
    raise NotImplementedError


def windows(times_ms, arm):
    """Trading windows [(start_ms, cut_ms)] for "DAY" / "WEEK" (PREREG s2); "CONT": [(times_ms[0], None)]."""
    raise NotImplementedError


def run_arm(ticks, cfg_opt, cfg_alt, arm, u, worse=0.0):
    """Run ALT and OPT on ticks under the arm. Returns {"opt", "alt", "marks", "cuts", "eq"}; eq holds per-tick
    arrays t, bal_opt, eq_opt, bal_alt, eq_alt in USD after commission, recorded after each tick."""
    raise NotImplementedError


def combine(parts):
    """parts: [(t, bal, eq)] numpy arrays; the union time grid, each part held at its last value (0 before its first
    tick). Returns (t, bal, eq) summed."""
    raise NotImplementedError


def day_losses(t_ms, bal, eq):
    """FTMO days, key (t - 3,600,000) // 86,400,000: {key: (start balance, lowest equity, loss)} (PREREG s4)."""
    raise NotImplementedError


def win_neg(E, k):
    """(windows with E[i] - E[i-k] < 0, windows) over i = k .. len(E) - 1."""
    raise NotImplementedError


def split(it, u, bid, ask):
    """The end split of one instance in USD (PREREG s4)."""
    raise NotImplementedError


def decide(base, sens):
    """PREREG s6 on {"net", "years", "neg12", "n12", "days500"} for the base run and the 0.5 pip sensitivity."""
    raise NotImplementedError
