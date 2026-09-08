#!/usr/bin/env python3
"""Unit tests for scripts/sim_costs.py — mandatory regression suite (T1–T8, J1–J8)."""
from __future__ import annotations

import unittest
from datetime import datetime, timezone
from zoneinfo import ZoneInfo

import numpy as np
import pandas as pd

import sim_costs


class TestSimCosts(unittest.TestCase):
    def test_t1_usd_quoted_pip_value_gbpusd(self):
        """T1: 3-pip GBPUSD move at 0.01 lots = 0.30 USD gross."""
        entry = 1.2500
        exit_ = entry + 3 * 0.0001
        gross = sim_costs.price_diff_to_usd(exit_ - entry, "GBPUSD", 0.01)
        self.assertAlmostEqual(gross, 0.30, places=6)

    def test_t2_eurgbp_pip_value_not_flat_usd(self):
        """T2: 3-pip EURGBP = 0.30 GBP; converted USD != 0.30 at realistic rate."""
        entry = 0.8500
        exit_ = entry + 3 * 0.0001
        rate = 1.35
        gross = sim_costs.price_diff_to_usd(exit_ - entry, "EURGBP", 0.01, rate)
        self.assertAlmostEqual(gross, 0.30 * rate, places=6)
        self.assertNotAlmostEqual(gross, 0.30, places=2)

    def test_t3_commission_round_trip(self):
        """T3: 3-pip GBPUSD scalp nets 0.24 after 0.06 commission."""
        entry = 1.2500
        exit_ = entry + 3 * 0.0001
        net = sim_costs.pnl(entry, exit_, "GBPUSD", 0.01, direction=1)
        self.assertAlmostEqual(net, 0.24, places=6)
        self.assertAlmostEqual(sim_costs.commission_round_trip_usd(0.01), 0.06, places=6)

    def test_t4_no_spread_in_pnl(self):
        """T4: pnl identical for different spread constants, same prices."""
        entry, exit_ = 1.2500, 1.2503
        orig = sim_costs.PAIR_SPREAD_PIPS["GBPUSD"]
        try:
            sim_costs.PAIR_SPREAD_PIPS["GBPUSD"] = 0.18
            a = sim_costs.pnl(entry, exit_, "GBPUSD", 0.01, direction=1)
            sim_costs.PAIR_SPREAD_PIPS["GBPUSD"] = 2.50
            b = sim_costs.pnl(entry, exit_, "GBPUSD", 0.01, direction=1)
            self.assertAlmostEqual(a, b, places=9)
        finally:
            sim_costs.PAIR_SPREAD_PIPS["GBPUSD"] = orig

    def test_t5_jpy_point_size(self):
        """T5: JPY-style point 0.01 converts correctly (3 pips via pip_size, not 0.0001)."""
        spec = sim_costs.get_pair_spec("USDJPY")
        self.assertEqual(spec.point, 0.01)
        self.assertEqual(spec.pip_size, 0.01)
        pips = 0.03 / spec.pip_size
        self.assertAlmostEqual(pips, 3.0, places=6)
        # 3 pips × 10 JPY/pip at 0.01 lots ÷ USDJPY 150 ≈ 0.20 USD
        gross = sim_costs.price_diff_to_usd(0.03, "USDJPY", 0.01, conversion_rate=150.0)
        self.assertAlmostEqual(gross, 0.20, places=6)

    def test_t6_prague_daily_boundary(self):
        """T6: Prague midnight roll attributes loss to correct day."""
        prague = ZoneInfo("Europe/Prague")
        # 23:55 and 00:05 Prague on consecutive calendar days
        t1 = pd.Timestamp(datetime(2024, 3, 15, 23, 55, tzinfo=prague))
        t2 = pd.Timestamp(datetime(2024, 3, 16, 0, 5, tzinfo=prague))
        # Naive UTC normalize would put both on same UTC date in some zones;
        # Prague explicitly splits them.
        equity = [10_000.0, 9_600.0, 9_700.0]  # 400 drop day1, recovery day2
        times = [t1, t1, t2]
        gates = sim_costs.evaluate_risk_gates(
            equity, times, initial_balance=10_000.0, max_daily_loss_usd=500.0
        )
        self.assertAlmostEqual(gates["max_daily_equity_drawdown_usd"], 400.0, places=2)
        self.assertFalse(gates["gate_a_daily_loss_breach"])

        # Same 500 drop entirely within one Prague day
        equity2 = [10_000.0, 9_400.0, 9_500.0]
        gates2 = sim_costs.evaluate_risk_gates(
            equity2, times, initial_balance=10_000.0, max_daily_loss_usd=500.0
        )
        self.assertTrue(gates2["gate_a_daily_loss_breach"])

    def test_t7_gate_a_floating_intraday(self):
        """T7: 500 USD intraday equity drop breaches even if recovered."""
        times = pd.date_range("2024-01-01", periods=3, freq="h", tz="Europe/Prague")
        equity = [10_000.0, 9_400.0, 10_200.0]
        gates = sim_costs.evaluate_risk_gates(
            equity, times, initial_balance=10_000.0, max_daily_loss_usd=500.0
        )
        self.assertTrue(gates["gate_a_daily_loss_breach"])

    def test_t8_gate_b_peak_to_trough(self):
        """T8: peak-to-trough > 1000 USD breaches Gate B."""
        equity = [10_000.0, 10_500.0, 9_400.0]
        gates = sim_costs.evaluate_risk_gates(
            equity, None, initial_balance=10_000.0, max_total_loss_usd=1000.0
        )
        self.assertAlmostEqual(gates["max_absolute_drawdown_usd"], 1100.0, places=2)
        self.assertTrue(gates["gate_b_total_loss_breach"])


class TestJpyPipParity(unittest.TestCase):
    """J1–J8: JPY pip-value parity — independently derived expected values."""

    LOTS = 0.01
    USDJPY_RATE = 153.63
    # 0.01 lots = 1,000 units; 1 pip = 0.01 JPY → 10 JPY per pip (J2 derivation)
    JPY_PIP_VALUE = 1_000.0 * 0.01
    USD_PIP_AT_RATE = JPY_PIP_VALUE / USDJPY_RATE  # 10 / 153.63 ≈ 0.0651

    def test_j1_pip_size_one_pip_not_one_hundred(self):
        """J1: pip_size 0.01 — a 0.01 price move is ONE pip, not one hundred."""
        spec = sim_costs.get_pair_spec("USDJPY")
        self.assertEqual(spec.pip_size, 0.01)
        pips_one = 0.01 / spec.pip_size
        self.assertAlmostEqual(pips_one, 1.0, places=9)
        # If pip_size were wrongly 0.0001, the same move would count as 100 pips.
        self.assertAlmostEqual(0.01 / 0.0001, 100.0, places=9)

    def test_j2_pip_value_quote_currency_ten_jpy(self):
        """J2: pip_value_quote_currency at 0.01 lots = 10.0 JPY."""
        expected = self.JPY_PIP_VALUE
        actual = sim_costs.pip_value_quote_currency("USDJPY", self.LOTS)
        self.assertAlmostEqual(actual, expected, places=9)
        self.assertAlmostEqual(actual, 10.0, places=9)

    def test_j3_pip_value_usd_divides_by_rate(self):
        """J3: pip_value_usd = 10 / 153.63 ≈ 0.0651 USD (not 0.10 USD-quoted flat)."""
        expected = self.USD_PIP_AT_RATE
        actual = sim_costs.pip_value_usd(
            "USDJPY", self.LOTS, conversion_rate=self.USDJPY_RATE
        )
        self.assertAlmostEqual(actual, expected, places=6)
        self.assertAlmostEqual(round(expected, 4), 0.0651, places=4)
        self.assertNotAlmostEqual(actual, 0.10, places=2)

    def test_j4_higher_usdjpy_rate_lowers_usd_pip_value(self):
        """J4: JPY-quoted pairs divide by rate — higher USDJPY → lower USD pip value."""
        rate_low = 150.0
        rate_high = 160.0
        pip_low = self.JPY_PIP_VALUE / rate_low
        pip_high = self.JPY_PIP_VALUE / rate_high
        self.assertLess(pip_high, pip_low)
        actual_low = sim_costs.pip_value_usd("USDJPY", self.LOTS, conversion_rate=rate_low)
        actual_high = sim_costs.pip_value_usd("USDJPY", self.LOTS, conversion_rate=rate_high)
        self.assertAlmostEqual(actual_low, pip_low, places=9)
        self.assertAlmostEqual(actual_high, pip_high, places=9)
        self.assertLess(actual_high, actual_low)

    def test_j5_three_pip_scalp_net_not_usd_quoted(self):
        """J5: 3-pip USDJPY scalp nets 0.1353 USD, not 0.24 (USD-quoted answer)."""
        gross_expected = 3.0 * self.USD_PIP_AT_RATE
        commission = sim_costs.commission_round_trip_usd(self.LOTS)
        net_expected = gross_expected - commission
        self.assertAlmostEqual(round(net_expected, 4), 0.1353, places=4)
        entry = self.USDJPY_RATE
        exit_ = entry + 3.0 * 0.01
        net_actual = sim_costs.pnl(
            entry, exit_, "USDJPY", self.LOTS, direction=1,
            conversion_rate=self.USDJPY_RATE,
        )
        self.assertAlmostEqual(net_actual, net_expected, places=6)
        self.assertNotAlmostEqual(round(net_actual, 2), 0.24, places=2)

    def test_j6_omitting_conversion_rate_raises(self):
        """J6: JPY pair without conversion_rate raises — no silent default."""
        with self.assertRaises(ValueError) as ctx:
            sim_costs.pip_value_usd("USDJPY", self.LOTS)
        self.assertIn("conversion_rate", str(ctx.exception))

    def test_j7_audjpy_same_usd_pip_as_usdjpy(self):
        """J7: AUDJPY USD pip value equals USDJPY — base currency must not leak."""
        expected = self.USD_PIP_AT_RATE
        actual = sim_costs.pip_value_usd(
            "AUDJPY", self.LOTS, conversion_rate=self.USDJPY_RATE
        )
        self.assertAlmostEqual(actual, expected, places=6)
        self.assertEqual(
            sim_costs.get_pair_spec("AUDJPY").conversion_pair, "USDJPY"
        )

    def test_j8_chfjpy_same_usd_pip_as_usdjpy(self):
        """J8: CHFJPY USD pip value equals USDJPY — base currency must not leak."""
        expected = self.USD_PIP_AT_RATE
        actual = sim_costs.pip_value_usd(
            "CHFJPY", self.LOTS, conversion_rate=self.USDJPY_RATE
        )
        self.assertAlmostEqual(actual, expected, places=6)
        self.assertEqual(
            sim_costs.get_pair_spec("CHFJPY").conversion_pair, "USDJPY"
        )


if __name__ == "__main__":
    unittest.main()
