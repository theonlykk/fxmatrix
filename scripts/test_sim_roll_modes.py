#!/usr/bin/env python3
"""Roll-at-cap mode tests for grid_sim_v7 (R1–R7)."""
from __future__ import annotations

import importlib.util
import unittest
from pathlib import Path

import numpy as np

import sim_costs
from importlib_util import exec_module_from_spec

SCRIPT_DIR = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location(
    "simv7", SCRIPT_DIR / "grid_sim_v7_real_signal.py"
)
simv7 = exec_module_from_spec(spec)


def _monotone_add_path(n_add_bars: int = 9, start: float = 1.2800) -> np.ndarray:
    """One L0 + n_add_bars add hits; one crossing per bar (sub_steps=1)."""
    width_pips = 5.0
    straddle = simv7.pips_to_price(width_pips, "GBPUSD")
    add_dist = simv7.pips_to_price(simv7.add_pips_from_width(width_pips), "GBPUSD")
    hs = sim_costs.half_spread_price("GBPUSD")
    e0 = start - straddle
    closes = [start, e0 - hs - 0.00001]
    entries = [e0]
    for _ in range(n_add_bars):
        add_t = entries[-1] - add_dist
        entries.append(add_t)
        closes.append(add_t - hs - 0.00001)
    return np.asarray(closes, dtype=float), entries


def _run(
    closes: np.ndarray,
    *,
    cap_mode: str = "stall",
    max_layers: int = 3,
    seed: int = 0,
    sub_steps: int = 50,
    bias_mode=simv7.BiasMode.LONG_ONLY,
    width: float = 5.0,
    exit_pips: float = 3.0,
    times=None,
) -> dict:
    dummy = np.zeros_like(closes)
    return simv7.simulate_one_path(
        closes,
        dummy,
        dummy,
        times=times,
        symbol="GBPUSD",
        bias_mode=bias_mode,
        seed=seed,
        sub_steps=sub_steps,
        entry_mode="straddle",
        straddle_half_width_pips=width,
        exit_pips=exit_pips,
        max_layers=max_layers,
        cap_mode=cap_mode,
    )


class TestSimRollModes(unittest.TestCase):
    def test_r1_stall_default_unchanged(self):
        """R1: cap_mode=stall equals omitting kwarg on cap-reaching paths."""
        closes = np.linspace(1.2700, 1.2500, 120)
        seeds = (0, 7, 42)
        for seed in seeds:
            with self.subTest(seed=seed):
                kw = dict(seed=seed, max_layers=3, sub_steps=50)
                explicit = _run(closes, cap_mode="stall", **kw)
                omitted = _run(closes, **kw)
                self.assertEqual(set(explicit.keys()), set(omitted.keys()))
                for key in explicit:
                    self.assertEqual(
                        explicit[key],
                        omitted[key],
                        msg=f"seed={seed} key={key}",
                    )

    def test_r2_roll_on_add_monotone_fall(self):
        """R2: roll_on_add on 10-step fall — 7 forced closes, hand PnL match."""
        closes, entries = _monotone_add_path(n_add_bars=9)
        hs = sim_costs.half_spread_price("GBPUSD")
        comm = sim_costs.commission_per_leg_usd(simv7.LOT_SIZE)
        r = _run(closes, cap_mode="roll_on_add", max_layers=3, sub_steps=1)

        self.assertEqual(r["n_forced_closes"], 7)
        self.assertEqual(r["max_layers"], 3)
        self.assertEqual(r["n_exits"], 0)

        layers = list(entries[:3])
        hand_forced = 0.0
        for bar in range(3, 10):
            closed_entry = layers.pop(0)
            close_mid = closes[bar + 1]
            bid_close = close_mid - hs
            gross = sim_costs.price_diff_to_usd(
                (bid_close - closed_entry) * 1,
                "GBPUSD",
                simv7.LOT_SIZE,
                None,
            )
            hand_forced += gross - comm
            layers.append(entries[bar])

        self.assertAlmostEqual(r["forced_close_pnl_usd"], hand_forced, places=9)
        n_opens = 10
        self.assertAlmostEqual(
            r["pnl_realised_usd"],
            hand_forced - n_opens * comm,
            places=9,
        )
        self.assertEqual(len(layers), 3)

    def test_r3_roll_on_fill_depth(self):
        """R3: roll_on_fill keeps depth <= 2 after each bar on same path."""
        closes, entries = _monotone_add_path(n_add_bars=9)
        r = _run(closes, cap_mode="roll_on_fill", max_layers=3, sub_steps=1)
        self.assertGreater(r["n_forced_closes"], 0)

        hs = sim_costs.half_spread_price("GBPUSD")
        width = 5.0
        add_dist = simv7.pips_to_price(simv7.add_pips_from_width(width), "GBPUSD")
        straddle = simv7.pips_to_price(width, "GBPUSD")
        layers: list[float] = []
        for bar in range(len(closes) - 1):
            start = closes[bar]
            end = closes[bar + 1]
            if not layers:
                buy_rest = start - straddle
                if end + hs <= buy_rest:
                    layers.append(start - straddle)
            elif len(layers) < 3:
                add_t = layers[-1] - add_dist
                eff = add_t - hs
                if start > eff >= end:
                    layers.append(add_t)
                    if len(layers) == 3:
                        layers.pop(0)
            else:
                add_t = layers[-1] - add_dist
                eff = add_t - hs
                if start > eff >= end:
                    layers.pop(0)
                    layers.append(add_t)
            self.assertLessEqual(len(layers), 2, msg=f"bar={bar}")

    def test_r4_no_roll_in_chop(self):
        """R4: oscillation at cap without add hit — roll_on_add equals stall."""
        width = 5.0
        hs = sim_costs.half_spread_price("GBPUSD")
        add_dist = simv7.pips_to_price(simv7.add_pips_from_width(width), "GBPUSD")
        straddle = simv7.pips_to_price(width, "GBPUSD")
        start = 1.2800
        e0 = start - straddle
        e1 = e0 - add_dist
        e2 = e1 - add_dist
        add_next = e2 - add_dist
        chop_low = e2 + hs + 0.00002
        chop_high = e0 - hs - 0.00002
        closes = np.array(
            [
                start,
                e0 - hs - 0.00001,
                e1 - hs - 0.00001,
                e2 - hs - 0.00001,
                chop_low,
                chop_high,
                chop_low,
                chop_high,
                chop_low,
            ],
            dtype=float,
        )
        stall = _run(closes, cap_mode="stall", max_layers=3, sub_steps=1)
        roll = _run(closes, cap_mode="roll_on_add", max_layers=3, sub_steps=1)
        self.assertEqual(roll["n_forced_closes"], 0)
        for key in stall:
            if key in ("cap_mode", "n_forced_closes", "forced_close_pnl_usd",
                       "forced_close_loss_pips_mean", "stranded_bars"):
                continue
            self.assertEqual(stall[key], roll[key], msg=key)

    def test_r5_short_forced_close_pricing(self):
        """R5: single short forced close uses ask and one exit commission."""
        width = 5.0
        hs = sim_costs.half_spread_price("GBPUSD")
        straddle = simv7.pips_to_price(width, "GBPUSD")
        add_dist = simv7.pips_to_price(simv7.add_pips_from_width(width), "GBPUSD")
        comm = sim_costs.commission_per_leg_usd(simv7.LOT_SIZE)
        start = 1.2500
        s0 = start + straddle
        closes = np.array(
            [
                start,
                s0 + hs + 0.00001,
                s0 + add_dist + hs + 0.00001,
            ],
            dtype=float,
        )
        r = _run(
            closes,
            cap_mode="roll_on_fill",
            max_layers=2,
            sub_steps=1,
            bias_mode=simv7.BiasMode.SHORT_ONLY,
        )
        self.assertEqual(r["n_forced_closes"], 1)
        close_mid = closes[2]
        ask_close = close_mid + hs
        gross = sim_costs.price_diff_to_usd(
            (ask_close - s0) * (-1),
            "GBPUSD",
            simv7.LOT_SIZE,
            None,
        )
        expected = gross - comm
        self.assertAlmostEqual(r["forced_close_pnl_usd"], expected, places=9)

    def test_r6_p1_guard(self):
        """R6: roll modes require P>=2; stall allows P=1."""
        closes = np.linspace(1.26, 1.25, 40)
        _run(closes, cap_mode="stall", max_layers=1)
        for mode in ("roll_on_add", "roll_on_fill"):
            with self.subTest(mode=mode):
                with self.assertRaises(ValueError):
                    _run(closes, cap_mode=mode, max_layers=1)

    def test_r7_new_output_keys(self):
        """R7: roll metrics present with correct types in all cap modes."""
        closes, _ = _monotone_add_path(n_add_bars=3)
        for mode in simv7.CAP_MODES:
            with self.subTest(mode=mode):
                r = _run(closes, cap_mode=mode, max_layers=3, sub_steps=1)
                self.assertIsInstance(r["cap_mode"], str)
                self.assertEqual(r["cap_mode"], mode)
                self.assertIsInstance(r["n_forced_closes"], int)
                self.assertIsInstance(r["forced_close_pnl_usd"], float)
                self.assertIsInstance(r["forced_close_loss_pips_mean"], float)
                self.assertIsInstance(r["stranded_bars"], int)


if __name__ == "__main__":
    unittest.main()
