"""Tests for scripts/validate_m1_bidask.py fixtures are in-memory only."""
from __future__ import annotations

import sys
from pathlib import Path

import pandas as pd

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))
from validate_m1_bidask import check_bars, summarise


def _base_row(time_broker: str) -> dict:
    return {
        "time_broker": time_broker,
        "bid_open": 1.10000,
        "bid_high": 1.10010,
        "bid_low": 1.09990,
        "bid_close": 1.10005,
        "ask_open": 1.10020,
        "ask_high": 1.10030,
        "ask_low": 1.10010,
        "ask_close": 1.10025,
        "ticks": 5,
    }


def test_t1_valid_three_rows():
    rows = [_base_row("2026-09-10 10:00:00"), _base_row("2026-09-10 10:01:00"), _base_row("2026-09-10 10:02:00")]
    df = pd.DataFrame(rows)
    assert check_bars(df) == []


def test_t2_duplicate_minute_r1():
    rows = [_base_row("2026-09-10 10:00:00"), _base_row("2026-09-10 10:00:00")]
    msgs = check_bars(pd.DataFrame(rows))
    assert len(msgs) == 1
    assert "R1" in msgs[0]


def test_t3_seconds_r2():
    row = _base_row("2026-09-10 10:00:30")
    msgs = check_bars(pd.DataFrame([row]))
    assert len(msgs) == 1
    assert "R2" in msgs[0]


def test_t4_bid_high_r3():
    row = _base_row("2026-09-10 10:00:00")
    row["bid_open"] = 1.10005
    row["bid_high"] = 1.10000
    row["bid_low"] = 1.09990
    row["bid_close"] = 1.10004
    msgs = check_bars(pd.DataFrame([row]))
    assert len(msgs) == 1
    assert "R3" in msgs[0]


def test_t5_ask_low_r4():
    row = _base_row("2026-09-10 10:00:00")
    row["ask_close"] = 1.10010
    row["ask_low"] = 1.10020
    row["ask_high"] = 1.10030
    msgs = check_bars(pd.DataFrame([row]))
    assert len(msgs) == 1
    assert "R4" in msgs[0]


def test_t6_crossed_r5():
    row = _base_row("2026-09-10 10:00:00")
    row["bid_open"] = 1.10005
    row["bid_close"] = 1.10008
    row["bid_low"] = 1.10000
    row["bid_high"] = 1.10010
    row["ask_open"] = 1.10010
    row["ask_close"] = 1.10005
    row["ask_low"] = 1.09995
    row["ask_high"] = 1.10015
    msgs = check_bars(pd.DataFrame([row]))
    assert len(msgs) == 1
    assert "R5" in msgs[0]


def test_t7_ticks_r6():
    row = _base_row("2026-09-10 10:00:00")
    row["ticks"] = 0
    msgs = check_bars(pd.DataFrame([row]))
    assert len(msgs) == 1
    assert "R6" in msgs[0]


def test_t8_summarise():
    rows = [_base_row("2026-09-10 10:00:00"), _base_row("2026-09-10 10:01:00"), _base_row("2026-09-10 10:02:00")]
    df = pd.DataFrame(rows)
    s = summarise(df)
    assert s["rows"] == 3
    assert s["first"] == "2026-09-10 10:00:00"
    assert s["last"] == "2026-09-10 10:02:00"
    assert s["rows_per_date"] == {"2026-09-10": 3}
