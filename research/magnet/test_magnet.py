"""Tests for magnet.py (written first, against a stub; hand values from PREREG.md v1).
Run: python -m pytest -q research/magnet/test_magnet.py

Units: integer tenths of a point ("t10": 1.60000 -> 1600000; 1 point = 10, 1 pip = 100). Magnets every S = 5000
(50 pips); entry offset d = 1000 (10 pips)."""
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import magnet as mg

L = 1600000
S = 5000
D = 1000
T0 = 1704672000            # 2024-01-08 00:00 server, a Monday (19730 x 86400)


def bars(rows, t0=T0 + 12 * 3600):
    """rows: (bid open, bid high, bid low, bid close, spread t10), one a minute."""
    o, h, l, c, s = zip(*rows)
    return {"t": [t0 + 60 * i for i in range(len(rows))], "o": list(o), "h": list(h), "l": list(l), "c": list(c),
            "s": list(s)}


# ---------------------------------------------------------------- fills (PREREG s2)
def test_sell_fills_at_bid_high_equal_not_one_point_below():
    assert mg.sell_fills(1600500, 1601000, 1601000)          # prev close below P, bid high = P
    assert not mg.sell_fills(1600500, 1600990, 1601000)      # one point short
    assert not mg.sell_fills(1601000, 1601500, 1601000)      # price was not below P before: not resting


def test_buy_fills_when_ask_low_reaches_p():
    # P = 1.59900; spread 2 points = 20 t10: bid low 1.59899 -> ask low 1.59901 > P: no; bid low 1.59898 -> ask 1.59900
    assert not mg.buy_fills(1599500, 1598990 + 20, 1599000)
    assert mg.buy_fills(1599500, 1598980 + 20, 1599000)


def test_slot_prices():
    assert mg.sell_entry(0, S, D, 320) == 1601000 and mg.buy_entry(0, S, D, 320) == 1599000
    assert mg.magnet(2500, S, 320) == 1602500


# ---------------------------------------------------------------- the engine (PREREG s2)
def test_entry_then_exit_next_bar_and_rearm():
    # bar 0 at 1.60050; bar 1 rises to 1.60100 (the sell at L + 10 fills) and dips to 1.59990 in the same bar (no exit
    # in the entry's bar); bar 2's ask low reaches 1.60000: exit (+10 pips); bar 3 back to 1.60100: the slot re-armed
    b = bars([(1600500, 1600500, 1600500, 1600500, 20),
              (1600500, 1601000, 1599990, 1600200, 20),
              (1600200, 1600200, 1599980, 1600100, 20),
              (1600100, 1601000, 1600100, 1600800, 20)])
    r = mg.run_grid(b, 0, S, D, cap=8, usd_per_pip=0.1)
    assert r["closes"] == 1 and r["entries"] == 2 and r["rolls"] == 0
    assert r["realised_pips"] == 10.0                      # (1.60100 - 1.60000) / 0.0001
    assert abs(r["realised_usd"] - (10.0 * 0.1 - 0.06)) < 1e-9


def test_ninth_short_rolls_the_lowest_entry_short():
    # cap 2: shorts at 1.60100 (exit 1.6000) and 1.60600 (exit 1.6050); price reaches 1.61100: no third short, the
    # 1.60100 short rolls (effective entry 1.61100, exit 1.6100); then the ask falls to 1.6100: it exits at a loss of
    # 90 pips (real entry 1.60100)
    b = bars([(1600500, 1600500, 1600500, 1600500, 20),
              (1600500, 1601000, 1600500, 1600900, 20),
              (1600900, 1606000, 1600900, 1605900, 20),
              (1605900, 1611000, 1605900, 1610900, 20),
              (1610900, 1610900, 1609980, 1610500, 20)])
    r = mg.run_grid(b, 0, S, D, cap=2, usd_per_pip=0.1)
    assert r["entries"] == 2 and r["rolls"] == 1 and r["closes"] == 1
    assert r["realised_pips"] == -90.0
    assert r["open_short"] == 1 and r["open_long"] == 0


def test_placebo_offset_is_a_translation():
    rng = random.Random(5)
    rows, p = [], 1600300
    for _ in range(600):
        o = p
        h, l = o + rng.randrange(0, 400, 10), o - rng.randrange(0, 400, 10)
        c = rng.randrange(l, h + 1, 10)
        rows.append((o, h, l, c, 20))
        p = c
    b0 = bars(rows)
    b1 = bars([(o + 2500, h + 2500, l + 2500, c + 2500, s) for o, h, l, c, s in rows])
    r0 = mg.run_grid(b0, 0, S, D, cap=8, usd_per_pip=0.1)
    r1 = mg.run_grid(b1, 2500, S, D, cap=8, usd_per_pip=0.1)
    for k in ("entries", "closes", "rolls", "realised_pips", "net_usd"):
        assert r0[k] == r1[k], k


def test_net_marks_open_short_at_ask():
    # one short at 1.60100 open at the end; last bid close 1.60050, spread 20 -> ask 1.60052: open = +4.8 pips
    b = bars([(1600500, 1600500, 1600500, 1600500, 20),
              (1600500, 1601000, 1600500, 1600500, 20)])
    r = mg.run_grid(b, 0, S, D, cap=8, usd_per_pip=0.1)
    assert r["open_short"] == 1 and abs(r["open_pips"] - 4.8) < 1e-9


# ---------------------------------------------------------------- the comparison and the checks (PREREG s4-s6)
def test_offsets():
    a = mg.placebo_offsets(random.Random(20261027), S, 20)
    assert a == mg.placebo_offsets(random.Random(20261027), S, 20) and len(a) == 20
    assert all(x % 10 == 0 and 500 <= x <= 4500 for x in a)
    q = mg.placebo_offsets(random.Random(1), 2500, 20)
    assert all(500 <= x <= 2000 for x in q)


def test_rank_first_of_21():
    assert mg.rank_of_real(10.0, [9.0] * 20) == 1
    assert mg.rank_of_real(10.0, [11.0] + [9.0] * 19) == 2


def test_ftmo_day_starts_at_server_0100():
    assert mg.ftmo_day(T0 + 3600) == mg.ftmo_day(T0 + 86399 + 3600)
    assert mg.ftmo_day(T0 + 3599) != mg.ftmo_day(T0 + 3600)


def test_permute_bars_keeps_each_days_first_bar_and_last_close():
    rows = [(1600000 + 10 * i, 1600050 + 10 * i, 1599950 + 10 * i, 1600010 + 10 * i, 20) for i in range(30)]
    b = bars(rows, t0=T0)
    p = mg.permute_bars_within_days(b, random.Random(3))
    assert p["o"][0] == b["o"][0] and p["c"][-1] == b["c"][-1]
    assert sorted(h - o for h, o in zip(p["h"], p["o"])) == sorted(h - o for h, o in zip(b["h"], b["o"]))
