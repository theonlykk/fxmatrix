"""Tests for scripts/backfill_scalp_closed.py pairing logic."""

from __future__ import annotations

import csv
import unittest
from pathlib import Path

from backfill_scalp_closed import (
    existing_scalp_keys,
    fetch_existing_scalps,
    pair_scalps,
    parse_mt5_time,
    scalp_already_present,
    ScalpRecord,
)
from unittest.mock import patch


class BackfillScalpClosedTests(unittest.TestCase):
    def test_parse_mt5_time_to_iso8601(self) -> None:
        self.assertEqual(
            parse_mt5_time("2026.09.10 16:42:08"),
            "2026-09-10T16:42:08Z",
        )

    def test_pair_one_scalp_sums_both_out_by_legs(self) -> None:
        rows = [
            {
                "deal_ticket": "1",
                "time": "2026.09.10 11:54:46",
                "symbol": "EURGBP",
                "magic": "22260301",
                "entry": "IN",
                "type": "buy",
                "volume": "0.01",
                "price": "0.85868",
                "profit": "0.00",
                "swap": "0.00",
                "commission": "-0.03",
                "position_id": "100",
                "order": "100",
                "reason": "3",
                "comment": "GRIND|OPT|L|L00|ENT",
            },
            {
                "deal_ticket": "2",
                "time": "2026.09.10 15:12:23",
                "symbol": "EURGBP",
                "magic": "22260301",
                "entry": "IN",
                "type": "sell",
                "volume": "0.01",
                "price": "0.85917",
                "profit": "0.00",
                "swap": "0.00",
                "commission": "-0.03",
                "position_id": "200",
                "order": "200",
                "reason": "3",
                "comment": "GRIND|OPT|L|L00|EXT",
            },
            {
                "deal_ticket": "3",
                "time": "2026.09.10 15:12:23",
                "symbol": "EURGBP",
                "magic": "22260301",
                "entry": "OUT_BY",
                "type": "sell",
                "volume": "0.01",
                "price": "0.85917",
                "profit": "0.66",
                "swap": "0.00",
                "commission": "0.00",
                "position_id": "100",
                "order": "999",
                "reason": "3",
                "comment": "#100 by #200",
            },
            {
                "deal_ticket": "4",
                "time": "2026.09.10 15:12:23",
                "symbol": "EURGBP",
                "magic": "22260301",
                "entry": "OUT_BY",
                "type": "buy",
                "volume": "0.01",
                "price": "0.85868",
                "profit": "0.00",
                "swap": "0.00",
                "commission": "0.00",
                "position_id": "200",
                "order": "999",
                "reason": "3",
                "comment": "#100 by #200",
            },
        ]
        scalps = pair_scalps(rows)
        self.assertEqual(len(scalps), 1)
        scalp = scalps[0]
        self.assertEqual(scalp.instance_id, "GRIND_EURGBP_OPT")
        self.assertEqual(scalp.direction, "LONG")
        self.assertEqual(scalp.layer_depth, 0)
        self.assertAlmostEqual(scalp.gross_pnl, 0.66)
        self.assertEqual(scalp.payload()["stack_depth"], None)

    def test_skip_manual_close(self) -> None:
        rows = [
            {
                "deal_ticket": "1",
                "time": "2026.09.10 17:54:54",
                "symbol": "EURUSD",
                "magic": "0",
                "entry": "OUT",
                "type": "buy",
                "volume": "0.01",
                "price": "1.16265",
                "profit": "0.17",
                "swap": "0.00",
                "commission": "-0.03",
                "position_id": "539592770",
                "order": "539622392",
                "reason": "0",
                "comment": "",
            }
        ]
        self.assertEqual(pair_scalps(rows), [])

    def test_dedup_existing_by_instance_and_close_time(self) -> None:
        candidate = ScalpRecord(
            ent_position_id="1",
            close_time="2026-09-10T15:12:23Z",
            instance_id="GRIND_EURGBP_OPT",
            instrument="EURGBP",
            direction="LONG",
            entry_price=0.85868,
            exit_price=0.85917,
            layer_depth=0,
            gross_pnl=0.66,
        )
        existing = [
            {
                "instance_id": "GRIND_EURGBP_OPT",
                "close_time": "2026-09-10T15:12:23Z",
                "entry_price": 0.85868,
                "exit_price": 0.85917,
                "stack_depth": 1,
            }
        ]
        keys = existing_scalp_keys(existing)
        self.assertTrue(scalp_already_present(candidate, keys))

    def test_dedup_ignores_stack_depth(self) -> None:
        candidate = ScalpRecord(
            ent_position_id="1",
            close_time="2026-09-10T15:12:23Z",
            instance_id="GRIND_EURGBP_OPT",
            instrument="EURGBP",
            direction="LONG",
            entry_price=0.85868,
            exit_price=0.85917,
            layer_depth=0,
            gross_pnl=0.66,
        )
        keys = existing_scalp_keys(
            [
                {
                    "instance_id": "GRIND_EURGBP_OPT",
                    "close_time": "2026-09-10T15:12:23Z",
                    "stack_depth": 5,
                }
            ]
        )
        self.assertTrue(scalp_already_present(candidate, keys))

    def test_fetch_existing_scalps_reads_records(self) -> None:
        payload = {
            "date": "2026-09-10",
            "total": 1,
            "records": [
                {
                    "instance_id": "GRIND_EURGBP_OPT",
                    "close_time": "2026-09-10T15:12:23Z",
                }
            ],
        }
        with patch("backfill_scalp_closed.api_get_json", return_value=payload):
            records = fetch_existing_scalps("token")
        self.assertEqual(len(records), 1)
        self.assertEqual(records[0]["instance_id"], "GRIND_EURGBP_OPT")

    def test_real_dump_yields_expected_scalp_count(self) -> None:
        csv_path = Path(__file__).resolve().parents[1] / "data/local/deals_dump_20260910_2246.csv"
        if not csv_path.exists():
            self.skipTest("local deal dump not present")
        with csv_path.open(newline="", encoding="utf-8") as handle:
            deals = list(csv.DictReader(handle))
        scalps = pair_scalps(deals)
        self.assertEqual(len(scalps), 27)
        self.assertAlmostEqual(sum(s.gross_pnl for s in scalps), 20.87, places=2)


if __name__ == "__main__":
    unittest.main()
