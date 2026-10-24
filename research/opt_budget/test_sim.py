"""Tests for sim.py (written first, against a stub; expected values derived by hand in the comments).
Run: python -m pytest -q research/opt_budget/test_sim.py"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sim

P = 0.00001          # point (5 digits)
T0 = 1_000_000_000   # ms


def cfg(add, cap=7, width=2.0, stranded=3.0, deadband=2.0, carry=False):
    return sim.Cfg(width=width, add=add, exit=add, cap=cap, stranded=stranded, deadband=deadband,
                   lattice=True, reroll=True, gate=0, carry=carry)


def ticks_from(asks, step_ms=5000, spread=2):
    """Each ask level held for one tick; bid = ask - spread points."""
    return [(T0 + i * step_ms, round(a - spread * P, 5), round(a, 5)) for i, a in enumerate(asks)]


# ---------------------------------------------------------------- pure rules
def test_budget():
    # PREREG s2: B(a) = 3 for a <= 3, 6 for 4..6, 7 at 7
    assert [sim.budget(a) for a in range(8)] == [3, 3, 3, 3, 6, 6, 6, 7]


def test_opt_add_target():
    # d < B: own target; d >= B, d < 7, a == d with an ALT resting add: ALT's price; else withheld (None)
    assert sim.opt_add_target(d=2, a=1, own=1.09771, alt_resting=None) == 1.09771
    assert sim.opt_add_target(d=3, a=1, own=1.09771, alt_resting=1.09751) is None
    assert sim.opt_add_target(d=3, a=3, own=1.09771, alt_resting=1.09291) == 1.09291
    assert sim.opt_add_target(d=3, a=3, own=1.09771, alt_resting=None) is None
    assert sim.opt_add_target(d=3, a=4, own=1.09221, alt_resting=1.09061) == 1.09221
    assert sim.opt_add_target(d=6, a=4, own=1.09081, alt_resting=1.09061) is None
    assert sim.opt_add_target(d=6, a=6, own=1.09081, alt_resting=1.08601) == 1.08601


def test_straddle_and_clamp():
    # mid 1.10001, width 2 pips: buy 1.09981, sell 1.10021 (MECHANICS s1)
    assert sim.straddle(1.10000, 1.10002, 2.0) == (1.09981, 1.10021)
    # ADR-013: a buy at or above bid clamps to bid - 1 point; a sell at or below ask to ask + 1 point
    assert sim.clamp_buy(1.10000, bid=1.10000) == 1.09999
    assert sim.clamp_sell(1.10002, ask=1.10002) == 1.10003


def test_add_anchor():
    # long, no virtual level: deepest entry 1.09911 - 7 pips = 1.09841
    lay = [sim.Layer(entry=1.09981, idx=0), sim.Layer(entry=1.09911, idx=1)]
    assert sim.add_target(lay, True, 7.0) == 1.09841
    # with L0 rolled to VL 1.09841: the lowest effective entry (1.09841) - 7 = 1.09771
    lay[0].vl = 1.09841
    assert sim.add_target(lay, True, 7.0) == 1.09771


def test_exit_ranks_rest_only_two():
    # three long layers, effective 1.09981 / 1.09911 / 1.09841: rank 0 = 1.09841, rank n-1 = 1.09981 rest; 1.09911 held
    lay = [sim.Layer(entry=1.09981, idx=0), sim.Layer(entry=1.09911, idx=1), sim.Layer(entry=1.09841, idx=2)]
    assert sorted(sim.resting_exit_idx(lay, True)) == [0, 2]


def test_roll_candidate():
    # the highest-entry long not yet rolled
    lay = [sim.Layer(entry=1.09981, idx=0), sim.Layer(entry=1.09911, idx=1)]
    assert sim.roll_candidate(lay, True) == 0
    lay[0].vl = 1.09841
    assert sim.roll_candidate(lay, True) == 1


# ---------------------------------------------------------------- one instance
def test_l0_fill_and_scalp():
    # tick 0 places the buy L0 at 1.09981 (one ENT a tick), tick 1 the sell at 1.10021; ask 1.09981 fills the buy at
    # 1.09981 (deal at +261 ms at the market then: the same tick's ask); its exit rests at 1.10051; bid 1.10051 fills
    # it: one scalp, +7.0 pips, not rolled
    # (the last tick only lets the close-by complete: it is sent on the tick after the exit's deal, +294 ms)
    tk = ticks_from([1.10002, 1.10002, 1.09981, 1.09981, 1.10010, 1.10053, 1.10053, 1.10053])
    r = sim.run_single(tk, cfg(7.0), carry_rows=None)
    closes = [(c.side, c.entry, c.exit, c.rolled) for c in r.closes]
    assert closes == [("L", 1.09981, 1.10051, False)]


def test_roll_at_cap_and_rolled_close():
    # cap 2, add = exit 7: longs at 1.09981 and 1.09911; level 1.09841; the short side is flat (gate 0 passes);
    # ask 1.09841 rolls L0 (highest entry) to VL 1.09841, its exit moves to 1.09911 (VL + 7); bid 1.09911 fills it:
    # a rolled close, 1.09911 - 1.09981 = -7.0 pips
    tk = ticks_from([1.10002, 1.10002, 1.09981, 1.09981, 1.09911, 1.09911, 1.09841, 1.09841, 1.09841,
                     1.09880, 1.09913, 1.09913, 1.09913])   # (last tick: the close-by completes)
    r = sim.run_single(tk, cfg(7.0, cap=2), carry_rows=None)
    assert r.rolls == 1
    rolled = [(c.entry, c.exit) for c in r.closes if c.rolled]
    assert rolled == [(1.09981, 1.09911)]


# ---------------------------------------------------------------- the budget, coupled
def test_budget_cluster_entries():
    # PREREG s1 in this grid: both arms L0 1.09981; OPT 1.09911, 1.09841 (3), withheld at 1.09771; ALT 1.09751 (2),
    # 1.09521 (3): OPT's 4th rests at ALT's 4th, 1.09291; both fill; OPT 1.09221, 1.09151 (6), withheld (ALT 4)
    path = [1.10002, 1.10002, 1.09981, 1.09981, 1.09911, 1.09911, 1.09841, 1.09841, 1.09771, 1.09771,
            1.09751, 1.09751, 1.09521, 1.09521, 1.09291, 1.09291, 1.09221, 1.09221, 1.09151, 1.09151,
            1.09081, 1.09081]
    tk = ticks_from(path)
    r = sim.run_pair(tk, cfg(7.0), cfg(23.0), carry_rows=None, budget=True)
    assert [l.entry for l in r.opt.book("L")] == [1.09981, 1.09911, 1.09841, 1.09291, 1.09221, 1.09151]
    assert [l.entry for l in r.alt.book("L")] == [1.09981, 1.09751, 1.09521, 1.09291]
    base = sim.run_pair(tk, cfg(7.0), cfg(23.0), carry_rows=None, budget=False)
    # uncoupled OPT: every 7 pips while ticks touch each level; a gap fills at the market (MECHANICS s4): 1.09701
    # rests, the next ask 1.09751 does not touch, 1.09521 does -> 1.09521; then 1.09451 rests, 1.09291 fills it;
    # 1.09221 fills the 7th
    assert [l.entry for l in base.opt.book("L")] == [1.09981, 1.09911, 1.09841, 1.09771, 1.09521, 1.09291, 1.09221]
