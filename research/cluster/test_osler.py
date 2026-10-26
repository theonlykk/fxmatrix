"""Tests for osler.py (written first, against a stub; expected values derived by hand from PREREG.md v3.1).
Run: python -m pytest -q research/cluster/test_osler.py

Units: prices are held as integers in tenths of a point ("t10": 1.16000 -> 1160000; 1 point = 10 t10), so the
band and every comparison are exact; PREREG s4's 1e-12 tolerance becomes a 1e-6 t10 tolerance (inclusive edges)."""
import os, sys, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import osler

DAY = 86400
MON = 1704672000          # 2024-01-08 00:00 "server" (time_unix_server is server-local seconds), a Monday
L = 1160000               # 1.16000 in t10


def series(qs, start=MON + 12 * 3600, step=60):
    """One bar a minute from midday; returns (t, q) lists."""
    return [start + i * step for i in range(len(qs))], list(qs)


# ---------------------------------------------------------------- the quote and the band (PREREG s4)
def test_quote_t10():
    # open 1.16000, spread 10 points -> mid = 1.16005 -> 1160050 t10
    assert osler.quote_t10(1.16000, 10) == 1160050
    # open 1.15999, spread 3 points -> 1.159990 + 0.000015 = 1.160005 -> 1160005 t10 (half points kept)
    assert osler.quote_t10(1.15999, 3) == 1160005


def test_band_edges_inclusive():
    # 0.0001 x 1.16 = 0.000116 = 116 t10: the band at 1.1600 is 1.159884 .. 1.160116 inclusive (Argon v3 1(a))
    assert osler.in_band(1159884, L) and osler.in_band(1160116, L)
    assert not osler.in_band(1159883, L) and not osler.in_band(1160117, L)


def test_excluded_rollover():
    # 23:55 .. 00:10 server excluded, inclusive at both ends; 23:54 and 00:11 not
    assert osler.excluded(MON + 23 * 3600 + 55 * 60)
    assert osler.excluded(MON + DAY + 10 * 60)
    assert not osler.excluded(MON + 23 * 3600 + 54 * 60)
    assert not osler.excluded(MON + DAY + 11 * 60)


# ---------------------------------------------------------------- hits (PREREG s4)
def test_hit_needs_a_minute_outside_first():
    # inside at the first bar: no hit (no earlier minute outside)
    t, q = series([L, L + 500, L])
    hits = osler.level_hits(t, q, L)
    assert hits == [(2, +1)]          # the hit at index 2, arriving from above (+1)


def test_no_rehit_without_a_minute_outside():
    # out(above), in, in, out(below), in -> two hits: (1, +1) and (4, -1)
    t, q = series([L + 500, L, L + 50, L - 500, L - 100])
    assert osler.level_hits(t, q, L) == [(1, +1), (4, -1)]


def test_hit_in_rollover_not_taken():
    # the transition falls at 23:58 server: no hit
    t = [MON + 23 * 3600 + 57 * 60, MON + 23 * 3600 + 58 * 60]
    assert osler.level_hits(t, [L + 500, L], L) == []


# ---------------------------------------------------------------- the outcome at +15 (PREREG s4)
def test_reversal_from_above():
    # from above, hit at minute 1, q at +15 back above L -> REVERSAL
    qs = [L + 500, L] + [L + 300] * 20
    t, q = series(qs)
    assert osler.outcome(t, q, 1, L, +1, 15)[0] == "REVERSAL"


def test_crossing_from_above():
    # from above, q at +15 below L (beyond, in the direction of the move) -> CROSSING; move = 300 t10 / L in %
    qs = [L + 500, L] + [L - 300] * 20
    t, q = series(qs)
    kind, move = osler.outcome(t, q, 1, L, +1, 15)
    assert kind == "CROSSING"
    assert abs(move - 300 / L * 100) < 1e-12


def test_exactly_at_level_is_reversal():
    qs = [L + 500, L] + [L] * 20
    t, q = series(qs)
    assert osler.outcome(t, q, 1, L, +1, 15)[0] == "REVERSAL"


def test_no_bar_in_window_dropped():
    # hit at index 1; the next bar is 25 minutes later (beyond +15 .. +20): dropped
    t = [MON + 43200, MON + 43260, MON + 43260 + 25 * 60]
    q = [L + 500, L, L - 300]
    assert osler.outcome(t, q, 1, L, +1, 15) == (None, None)


# ---------------------------------------------------------------- levels (PREREG s4)
def test_round_levels_inside_range_only():
    # range 1.15720 .. 1.16630 -> round levels 1.1600 (R100) and 1.1650 (R50); 1.1550 and 1.1700 outside
    assert osler.round_levels(1157200, 1166300) == [1160000, 1165000]
    assert osler.round_class(1160000) == "R100" and osler.round_class(1165000) == "R50"


def test_arbitrary_draws_avoid_round_bands_and_stay_in_range():
    rng = random.Random(1)
    lv = osler.draw_arbitrary(rng, 1157200, 1166300, 200)
    assert len(lv) == 200
    for x in lv:
        assert 1157200 <= x <= 1166300
        assert x % 10 == 0                              # rounded to 0.00001 (one point)
        nearest = round(x / 5000) * 5000                # round levels: multiples of 0.0050 = 5000 t10
        assert abs(x - nearest) > 0.0002 * x            # 0.0002 x L from any round level


# ---------------------------------------------------------------- a pair-block (PREREG s5)
def test_pair_block_with_nine_round_hits_not_counted():
    # nine round hits (each reversed) -> the pair-block is not counted for the reversal test
    qs = []
    for _ in range(9):
        qs += [L + 500, L] + [L + 300] * 16
    t, q = series(qs)
    st = osler.pair_block_stats(t, q, [L], [], min_hits=10, min_cross=5)
    assert st["round_hits"] == 9 and st["counted_reversal"] is False


def test_pair_block_ten_round_hits_counted():
    qs = []
    for _ in range(10):
        qs += [L + 500, L] + [L + 300] * 16
    t, q = series(qs)
    st = osler.pair_block_stats(t, q, [L], [], min_hits=10, min_cross=5)
    assert st["round_hits"] == 10 and st["counted_reversal"] is True and st["rvr"] == 1.0


# ---------------------------------------------------------------- inference (PREREG s5)
def test_sign_test_eight_of_ten():
    # P(X >= 8 | n = 10, p = 0.5) = (45 + 10 + 1) / 1024 = 0.0546875
    assert abs(osler.sign_test_p(8, 10) - 56 / 1024) < 1e-15


def test_common_days_and_blocks():
    # a day counts only if every pair has >= 600 bars; blocks of 10 common days, last partial dropped
    counts = {"A": {1: 600, 2: 700, 3: 599}, "B": {1: 650, 2: 600, 3: 900}}
    assert osler.common_days(counts) == [1, 2]
    assert osler.blocks(list(range(25))) == [list(range(10)), list(range(10, 20))]


def test_bootstrap_ci_constant():
    # all D_j equal: every resampled mean equals it
    lo, hi = osler.bootstrap_ci([0.02] * 30, seed=20261027, n=2000)
    assert abs(lo - 0.02) < 1e-12 and abs(hi - 0.02) < 1e-12
