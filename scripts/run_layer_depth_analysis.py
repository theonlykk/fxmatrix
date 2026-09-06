#!/usr/bin/env python3
"""
Layer-depth profitability analysis — per-layer resolution and P&L by open depth.

Tags each opened layer by stack depth at entry (0=L0, 1=first add, 2=second add, ...).
Tracks individual resolution: exit hit vs buried-then-resolved vs window-end open.

Production geometry (locked): WIDEN_RATIO=1.304, ADD_PIPS_FLOOR=9.0, EXIT_PIPS=3.0,
SpreadMultiplier=0.5.

Usage (full sweep on Surface, 8 workers):
  python scripts/run_layer_depth_analysis.py --workers 8

Smoke / wiring:
  python scripts/run_layer_depth_analysis.py --smoke-test
  python scripts/run_layer_depth_analysis.py --test-wiring

Sanity (one window, one bias, n=20):
  python scripts/run_layer_depth_analysis.py --window full_quarter --bias MM_LONG --n-seeds 20 --workers 4
"""
from __future__ import annotations

import argparse
import importlib.util
import json
import math
import os
import sys
import time
from concurrent.futures import ProcessPoolExecutor, as_completed
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

import numpy as np
import pandas as pd

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(SCRIPT_DIR)

spec7 = importlib.util.spec_from_file_location(
    "simv7", os.path.join(SCRIPT_DIR, "grid_sim_v7_real_signal.py")
)
simv7 = importlib.util.module_from_spec(spec7)
spec7.loader.exec_module(simv7)
spec6 = importlib.util.spec_from_file_location(
    "simv6", os.path.join(SCRIPT_DIR, "grid_sim_v6_dynamic_spacing.py")
)
simv6 = importlib.util.module_from_spec(spec6)
spec6.loader.exec_module(simv6)

import sim_costs

SPACING_MODES = ["reload_anchor", "reload_flat"]
BIAS_MODES = {
    "MM_LONG": simv7.BiasMode.LONG_ONLY,
    "MM_SHORT": simv7.BiasMode.SHORT_ONLY,
    "MM_BOTH": simv7.BiasMode.BOTH,
}
ALL_WINDOWS = {
    "full_quarter": os.path.join(ROOT, "data", "GBPUSD_full_quarter.csv"),
    "june_blowup": os.path.join(ROOT, "data", "GBPUSD_june_blowup.csv"),
    "truss_crisis": os.path.join(ROOT, "data", "GBPUSD_truss_crisis_oos.csv"),
    "vaccine_rally": os.path.join(ROOT, "data", "GBPUSD_vaccine_rally_oos.csv"),
    "q1_2024_chop": os.path.join(ROOT, "data", "GBPUSD_q1_2024_chop_oos.csv"),
}
TREND_HORIZON_BARS = 12  # 1 hour on M5


@dataclass
class OpenLayer:
    layer_id: int
    open_depth: int
    direction: int
    entry_price: float
    exit_target_raw: float
    open_bar: int
    open_substep: float
    was_buried: bool = False
    entry_commission_usd: float = 0.0


@dataclass
class LayerOutcome:
    layer_id: int
    open_depth: int
    direction: int
    resolved: bool
    resolution: str  # exit_hit | window_end
    was_buried: bool
    pnl_usd: float
    time_to_resolution_bars: float | None
    trend_adverse_pips_1h: float | None = None
    trend_net_pips_1h: float | None = None
    trend_sustained: bool | None = None


@dataclass
class DepthAccumulator:
    opened: int = 0
    resolved: int = 0
    buried_before_resolve: int = 0
    pnl_sum: float = 0.0
    ttr_values: list[float] = field(default_factory=list)
    trend_adverse_sum: float = 0.0
    trend_adverse_count: int = 0
    trend_sustained_count: int = 0
    trend_sample_count: int = 0

    def add(self, outcome: LayerOutcome) -> None:
        self.opened += 1
        if outcome.was_buried:
            self.buried_before_resolve += 1
        if outcome.resolved:
            self.resolved += 1
        self.pnl_sum += outcome.pnl_usd
        if outcome.time_to_resolution_bars is not None:
            self.ttr_values.append(outcome.time_to_resolution_bars)
        if outcome.trend_adverse_pips_1h is not None:
            self.trend_adverse_sum += outcome.trend_adverse_pips_1h
            self.trend_adverse_count += 1
            if outcome.trend_sustained:
                self.trend_sustained_count += 1
            self.trend_sample_count += 1

    def to_dict(self) -> dict:
        ttr = self.ttr_values
        return {
            "opened": self.opened,
            "resolved": self.resolved,
            "resolution_rate_pct": (100.0 * self.resolved / self.opened) if self.opened else 0.0,
            "buried_before_resolve": self.buried_before_resolve,
            "buried_rate_pct": (100.0 * self.buried_before_resolve / self.opened) if self.opened else 0.0,
            "mean_pnl_usd_per_layer": (self.pnl_sum / self.opened) if self.opened else 0.0,
            "mean_pnl_resolved_only_usd": (self.pnl_sum / self.resolved) if self.resolved else 0.0,
            "mean_ttr_bars": float(np.mean(ttr)) if ttr else None,
            "median_ttr_bars": float(np.median(ttr)) if ttr else None,
            "trend_adverse_pips_1h_mean": (
                self.trend_adverse_sum / self.trend_adverse_count
                if self.trend_adverse_count
                else None
            ),
            "trend_sustained_rate_pct": (
                100.0 * self.trend_sustained_count / self.trend_sample_count
                if self.trend_sample_count
                else None
            ),
        }


def _trend_metrics(
    closes: np.ndarray,
    open_bar: int,
    direction: int,
    entry_price: float,
    horizon: int = TREND_HORIZON_BARS,
) -> tuple[float | None, float | None, bool | None]:
    """Post-open path: adverse excursion and net move in pips (favorable = toward exit)."""
    if open_bar + 1 >= len(closes):
        return None, None, None
    end = min(open_bar + 1 + horizon, len(closes) - 1)
    segment = closes[open_bar + 1 : end + 1]
    if len(segment) == 0:
        return None, None, None
    if direction == 1:
        pip = sim_costs.get_pair_spec("GBPUSD").pip_size
        adverse = (entry_price - np.min(segment)) / pip
        net = (segment[-1] - entry_price) / pip
        sustained = net < -3.0
    else:
        pip = sim_costs.get_pair_spec("GBPUSD").pip_size
        adverse = (np.max(segment) - entry_price) / pip
        net = (entry_price - segment[-1]) / pip
        sustained = net < -3.0
    return float(adverse), float(net), bool(sustained)


def simulate_layer_outcomes(
    closes: np.ndarray,
    bid_arr: np.ndarray,
    offer_arr: np.ndarray,
    bias_mode: int,
    spacing_mode: str,
    seed: int,
    symbol: str = "GBPUSD",
    sub_steps: int = 100,
) -> list[LayerOutcome]:
    """Mirror grid_sim_v7_real_signal path with per-layer outcome tracking."""
    rng = np.random.default_rng(seed)
    n_bars = len(closes) - 1
    sigma = float(np.std(np.diff(np.log(closes)), ddof=1) * 2.5)
    exit_dist = sim_costs.pips_to_price(simv7.EXIT_PIPS, symbol)
    half_spread = sim_costs.half_spread_price(symbol)
    entry_comm = sim_costs.commission_per_leg_usd(simv7.LOT_SIZE)
    exit_comm = entry_comm

    layers: list[simv7.Layer] = []
    open_meta: list[OpenLayer] = []
    next_id = 0
    current_add_pips = simv7.ADD_PIPS_FLOOR
    last_exit_price: float | None = None
    outcomes: list[LayerOutcome] = []

    def register_open(fill_price: float, direction: int, depth: int, bar_i: int, substep: float) -> None:
        nonlocal next_id
        open_meta.append(
            OpenLayer(
                layer_id=next_id,
                open_depth=depth,
                direction=direction,
                entry_price=fill_price,
                exit_target_raw=fill_price + direction * exit_dist,
                open_bar=bar_i,
                open_substep=substep,
                entry_commission_usd=entry_comm,
            )
        )
        layers.append(
            simv7.Layer(
                entry_price=fill_price,
                direction=direction,
                exit_target_raw=fill_price + direction * exit_dist,
                entry_commission_usd=entry_comm,
            )
        )
        next_id += 1

    def mark_buried(new_top_index: int) -> None:
        for idx in range(new_top_index):
            if not open_meta[idx].was_buried:
                open_meta[idx].was_buried = True

    def close_top(bar_i: int, substep: float) -> float:
        """Close top layer; return closed entry price for reload_anchor logic."""
        closed_layer = layers.pop()
        closed_meta = open_meta.pop()
        gross = sim_costs.price_diff_to_usd(
            (closed_meta.exit_target_raw - closed_meta.entry_price) * closed_meta.direction,
            symbol,
            simv7.LOT_SIZE,
        )
        pnl = gross - exit_comm
        ttr = (bar_i - closed_meta.open_bar) + (substep - closed_meta.open_substep) / sub_steps
        adv, net, sustained = _trend_metrics(
            closes, closed_meta.open_bar, closed_meta.direction, closed_meta.entry_price
        )
        outcomes.append(
            LayerOutcome(
                layer_id=closed_meta.layer_id,
                open_depth=closed_meta.open_depth,
                direction=closed_meta.direction,
                resolved=True,
                resolution="exit_hit",
                was_buried=closed_meta.was_buried,
                pnl_usd=pnl,
                time_to_resolution_bars=ttr,
                trend_adverse_pips_1h=adv,
                trend_net_pips_1h=net,
                trend_sustained=sustained,
            )
        )
        return closed_meta.entry_price

    price_current = closes[0]
    for i in range(n_bars):
        start_price = price_current
        end_price = closes[i + 1]
        dt = 1.0 / sub_steps
        t = np.linspace(0, 1, sub_steps + 1)
        dW = rng.normal(0, np.sqrt(dt), sub_steps)
        W = np.zeros(sub_steps + 1)
        W[1:] = np.cumsum(dW)
        bridge = W - t * W[-1]
        path = start_price + (end_price - start_price) * t + sigma * bridge

        bar_start_quotes = None
        if not layers:
            b, o = bid_arr[i], offer_arr[i]
            if not (np.isnan(b) or np.isnan(o)):
                bar_start_quotes = (
                    simv7.adr013_clamp(b, 1, start_price, half_spread),
                    simv7.adr013_clamp(o, -1, start_price, half_spread),
                )

        for j in range(len(path)):
            mid = path[j]
            substep = float(j)

            if not layers and bar_start_quotes is not None:
                bid_c, offer_c = bar_start_quotes
                ba = (mid - half_spread, mid + half_spread)
                filled_dir = None
                fill_p = None
                if bias_mode in (simv7.BiasMode.LONG_ONLY, simv7.BiasMode.BOTH) and ba[1] <= bid_c:
                    filled_dir, fill_p = 1, bid_c
                if bias_mode in (simv7.BiasMode.SHORT_ONLY, simv7.BiasMode.BOTH) and ba[0] >= offer_c:
                    if filled_dir is None:
                        filled_dir, fill_p = -1, offer_c
                if filled_dir is not None:
                    register_open(fill_p, filled_dir, depth=0, bar_i=i, substep=substep)
                    current_add_pips = simv7.ADD_PIPS_FLOOR
                    last_exit_price = None
                continue

            if j == 0:
                continue
            pp, pn = path[j - 1], path[j]

            if layers:
                cur = layers[-1]
                eff_exit = cur.exit_target_raw + cur.direction * half_spread
                crossed = (cur.direction == 1 and pp < eff_exit <= pn) or (
                    cur.direction == -1 and pp > eff_exit >= pn
                )
                if crossed:
                    closed_entry = close_top(i, substep)
                    if spacing_mode in ("reload_anchor", "reload_flat"):
                        last_exit_price = closed_entry

            if layers:
                cur = layers[-1]
                if spacing_mode == "reload_anchor" and last_exit_price is not None:
                    depth_mult = simv7.WIDEN_RATIO ** (len(layers) // 3)
                    reload_step = min(
                        simv7.ADD_PIPS_CEILING, simv7.ADD_PIPS_FLOOR * depth_mult
                    )
                    add_target = last_exit_price - cur.direction * sim_costs.pips_to_price(
                        reload_step, symbol
                    )
                elif spacing_mode == "reload_flat" and last_exit_price is not None:
                    add_target = last_exit_price - cur.direction * sim_costs.pips_to_price(
                        simv7.ADD_PIPS_FLOOR, symbol
                    )
                else:
                    still_shallow = len(layers) < 3
                    add_pips = (
                        simv7.ADD_PIPS_FLOOR
                        if (spacing_mode == "flat" or still_shallow)
                        else current_add_pips
                    )
                    add_target = cur.entry_price - cur.direction * sim_costs.pips_to_price(
                        add_pips, symbol
                    )
                eff_add = add_target - cur.direction * half_spread
                hit = (cur.direction == 1 and pp > eff_add >= pn) or (
                    cur.direction == -1 and pp < eff_add <= pn
                )
                if hit:
                    depth = len(layers)
                    mark_buried(depth)
                    register_open(add_target, cur.direction, depth=depth, bar_i=i, substep=substep)
                    if spacing_mode in ("reload_anchor", "reload_flat"):
                        last_exit_price = None
                    if len(layers) >= 3:
                        current_add_pips = min(
                            simv7.ADD_PIPS_CEILING,
                            current_add_pips * simv7.WIDEN_RATIO,
                        )

        price_current = end_price

    final_price = closes[-1]
    for lay_meta in open_meta:
        mark_price = (
            final_price - half_spread
            if lay_meta.direction == 1
            else final_price + half_spread
        )
        pnl = sim_costs.layer_unrealised_usd(
            lay_meta.entry_price,
            lay_meta.direction,
            mark_price,
            symbol,
            lay_meta.entry_commission_usd,
            simv7.LOT_SIZE,
        )
        adv, net, sustained = _trend_metrics(
            closes, lay_meta.open_bar, lay_meta.direction, lay_meta.entry_price
        )
        outcomes.append(
            LayerOutcome(
                layer_id=lay_meta.layer_id,
                open_depth=lay_meta.open_depth,
                direction=lay_meta.direction,
                resolved=False,
                resolution="window_end",
                was_buried=lay_meta.was_buried,
                pnl_usd=pnl,
                time_to_resolution_bars=None,
                trend_adverse_pips_1h=adv,
                trend_net_pips_1h=net,
                trend_sustained=sustained,
            )
        )

    return outcomes


def aggregate_outcomes(outcomes: list[LayerOutcome]) -> dict[str, Any]:
    by_depth: dict[int, DepthAccumulator] = {}
    for o in outcomes:
        by_depth.setdefault(o.open_depth, DepthAccumulator()).add(o)

    depth_rows = {str(d): acc.to_dict() for d, acc in sorted(by_depth.items())}

    shallow = DepthAccumulator()
    deep = DepthAccumulator()
    for o in outcomes:
        if o.open_depth <= 1:
            shallow.add(o)
        elif o.open_depth >= 2:
            deep.add(o)

    return {
        "total_layers": len(outcomes),
        "by_depth": depth_rows,
        "depth_0_1": shallow.to_dict(),
        "depth_2_plus": deep.to_dict(),
        "_raw_by_depth": {
            str(d): {
                "opened": acc.opened,
                "resolved": acc.resolved,
                "buried_before_resolve": acc.buried_before_resolve,
                "pnl_sum": acc.pnl_sum,
                "ttr_values": acc.ttr_values,
                "trend_adverse_sum": acc.trend_adverse_sum,
                "trend_adverse_count": acc.trend_adverse_count,
                "trend_sustained_count": acc.trend_sustained_count,
                "trend_sample_count": acc.trend_sample_count,
            }
            for d, acc in by_depth.items()
        },
        "_raw_shallow": _acc_raw(shallow),
        "_raw_deep": _acc_raw(deep),
    }


def _acc_raw(acc: DepthAccumulator) -> dict:
    return {
        "opened": acc.opened,
        "resolved": acc.resolved,
        "buried_before_resolve": acc.buried_before_resolve,
        "pnl_sum": acc.pnl_sum,
        "ttr_values": acc.ttr_values,
        "trend_adverse_sum": acc.trend_adverse_sum,
        "trend_adverse_count": acc.trend_adverse_count,
        "trend_sustained_count": acc.trend_sustained_count,
        "trend_sample_count": acc.trend_sample_count,
    }


def _acc_from_raw(raw: dict) -> DepthAccumulator:
    acc = DepthAccumulator()
    acc.opened = raw["opened"]
    acc.resolved = raw["resolved"]
    acc.buried_before_resolve = raw["buried_before_resolve"]
    acc.pnl_sum = raw["pnl_sum"]
    acc.ttr_values = list(raw["ttr_values"])
    acc.trend_adverse_sum = raw["trend_adverse_sum"]
    acc.trend_adverse_count = raw["trend_adverse_count"]
    acc.trend_sustained_count = raw["trend_sustained_count"]
    acc.trend_sample_count = raw["trend_sample_count"]
    return acc


def _worker_batch(payload: dict) -> list[tuple[int, dict]]:
    root = Path(payload["root"])
    spec_lda = importlib.util.spec_from_file_location(
        "layer_depth_analysis_worker", root / "scripts" / "run_layer_depth_analysis.py"
    )
    lda = importlib.util.module_from_spec(spec_lda)
    sys.modules[spec_lda.name] = lda
    spec_lda.loader.exec_module(lda)

    closes = np.asarray(payload["closes"], dtype=float)
    bid = np.asarray(payload["bid"], dtype=float)
    offer = np.asarray(payload["offer"], dtype=float)

    out: list[tuple[int, dict]] = []
    for seed in payload["seeds"]:
        outcomes = lda.simulate_layer_outcomes(
            closes,
            bid,
            offer,
            bias_mode=payload["bias_mode"],
            spacing_mode=payload["spacing"],
            seed=int(seed),
        )
        out.append((int(seed), lda.aggregate_outcomes(outcomes)))
    return out


def merge_aggregates(agg_list: list[dict]) -> dict:
    merged_by_depth: dict[int, DepthAccumulator] = {}
    merged_shallow = DepthAccumulator()
    merged_deep = DepthAccumulator()
    total_layers = 0

    for agg in agg_list:
        total_layers += agg["total_layers"]
        for depth_str, raw in agg["_raw_by_depth"].items():
            d = int(depth_str)
            acc = merged_by_depth.setdefault(d, DepthAccumulator())
            src = _acc_from_raw(raw)
            acc.opened += src.opened
            acc.resolved += src.resolved
            acc.buried_before_resolve += src.buried_before_resolve
            acc.pnl_sum += src.pnl_sum
            acc.ttr_values.extend(src.ttr_values)
            acc.trend_adverse_sum += src.trend_adverse_sum
            acc.trend_adverse_count += src.trend_adverse_count
            acc.trend_sustained_count += src.trend_sustained_count
            acc.trend_sample_count += src.trend_sample_count

        sh = _acc_from_raw(agg["_raw_shallow"])
        dp = _acc_from_raw(agg["_raw_deep"])
        for target, src in ((merged_shallow, sh), (merged_deep, dp)):
            target.opened += src.opened
            target.resolved += src.resolved
            target.buried_before_resolve += src.buried_before_resolve
            target.pnl_sum += src.pnl_sum
            target.ttr_values.extend(src.ttr_values)
            target.trend_adverse_sum += src.trend_adverse_sum
            target.trend_adverse_count += src.trend_adverse_count
            target.trend_sustained_count += src.trend_sustained_count
            target.trend_sample_count += src.trend_sample_count

    return {
        "total_layers": total_layers,
        "by_depth": {str(d): acc.to_dict() for d, acc in sorted(merged_by_depth.items())},
        "depth_0_1": merged_shallow.to_dict(),
        "depth_2_plus": merged_deep.to_dict(),
    }


def parallel_seed_runs(
    closes,
    bid,
    offer,
    n_seeds: int,
    spacing_mode: str,
    bias_mode: int,
    workers: int = 1,
) -> list[dict]:
    workers = max(1, min(workers, n_seeds))
    chunk = max(1, math.ceil(n_seeds / (workers * 2)))
    batches = []
    for start in range(0, n_seeds, chunk):
        batches.append(list(range(start, min(n_seeds, start + chunk))))

    payload_base = {
        "root": str(ROOT),
        "closes": closes,
        "bid": bid,
        "offer": offer,
        "spacing": spacing_mode,
        "bias_mode": int(bias_mode),
    }
    results_by_seed: dict[int, dict] = {}
    with ProcessPoolExecutor(max_workers=workers) as pool:
        futs = []
        for seeds in batches:
            p = dict(payload_base)
            p["seeds"] = seeds
            futs.append(pool.submit(_worker_batch, p))
        for fut in as_completed(futs):
            for seed, result in fut.result():
                results_by_seed[seed] = result
    return [results_by_seed[s] for s in range(n_seeds)]


def run_analysis(
    n_seeds: int = 500,
    windows: dict | None = None,
    spacing_modes: list | None = None,
    bias_filter: list[str] | None = None,
    workers: int = 1,
    verbose: bool = True,
) -> dict:
    windows = windows or ALL_WINDOWS
    spacing_modes = spacing_modes or SPACING_MODES
    bias_items = [
        (k, v) for k, v in BIAS_MODES.items() if bias_filter is None or k in bias_filter
    ]
    start = time.time()
    results: dict[str, Any] = {}

    for spacing_mode in spacing_modes:
        for window_name, path in windows.items():
            df = simv6.load_mt5_csv(path)
            closes = df["CLOSE"].values
            spread_pts = df["SPREAD"].values
            bid, offer = simv7.precompute_gbpusd_signal(closes, spread_pts)
            if verbose:
                print(
                    f"Loaded {window_name}: {len(df)} bars, "
                    f"{df['datetime'].iloc[0]} -> {df['datetime'].iloc[-1]}"
                )

            for mode_name, mode in bias_items:
                if verbose:
                    print(
                        f"  {spacing_mode}/{window_name}/{mode_name}: "
                        f"{n_seeds} seeds, {workers} workers",
                        flush=True,
                    )
                seed_aggs = parallel_seed_runs(
                    closes, bid, offer, n_seeds, spacing_mode, mode, workers=workers
                )
                key = f"{spacing_mode}|{window_name}|{mode_name}"
                results[key] = merge_aggregates(seed_aggs)
                if verbose:
                    d01 = results[key]["depth_0_1"]
                    d2p = results[key]["depth_2_plus"]
                    print(
                        f"    DONE total_layers={results[key]['total_layers']} "
                        f"L0-1 mean_pnl=${d01['mean_pnl_usd_per_layer']:.3f} "
                        f"L2+ mean_pnl=${d2p['mean_pnl_usd_per_layer']:.3f} "
                        f"L2+ sustained={d2p.get('trend_sustained_rate_pct')}",
                        flush=True,
                    )

    return {"cells": results, "elapsed_sec": time.time() - start, "n_seeds": n_seeds}


def print_summary(payload: dict) -> None:
    print(f"\n{'=' * 120}")
    print(f"LAYER DEPTH ANALYSIS — n={payload['n_seeds']} seeds/cell, elapsed={payload['elapsed_sec']:.0f}s")
    print(f"{'=' * 120}\n")
    print(
        f"{'Cell':<45}{'Depth':<6}{'Opened':<8}{'Res%':<7}{'Bur%':<7}"
        f"{'MnPnL':<8}{'MnTTR':<8}{'Adv1h':<8}{'Sust%':<7}"
    )
    for key in sorted(payload["cells"]):
        cell = payload["cells"][key]
        for label, bucket in [("0-1", cell["depth_0_1"]), ("2+", cell["depth_2_plus"])]:
            if bucket["opened"] == 0:
                continue
            print(
                f"{key:<45}{label:<6}{bucket['opened']:<8}"
                f"{bucket['resolution_rate_pct']:<7.1f}{bucket['buried_rate_pct']:<7.1f}"
                f"{bucket['mean_pnl_usd_per_layer']:<8.3f}"
                f"{(bucket['mean_ttr_bars'] or 0):<8.1f}"
                f"{(bucket['trend_adverse_pips_1h_mean'] or 0):<8.1f}"
                f"{(bucket['trend_sustained_rate_pct'] or 0):<7.1f}"
            )


def sanity_check_depth_tagging() -> None:
    """Verify depth assignment: L0=0, first add=1, burial flag on deeper open."""
    path = ALL_WINDOWS["full_quarter"]
    df = simv6.load_mt5_csv(path)
    closes = df["CLOSE"].values[:500]
    spread = df["SPREAD"].values[:500]
    bid, offer = simv7.precompute_gbpusd_signal(closes, spread)
    outcomes = simulate_layer_outcomes(
        closes, bid, offer, simv7.BiasMode.LONG_ONLY, "reload_flat", seed=42
    )
    assert outcomes, "expected at least one layer outcome on real data"
    depths = [o.open_depth for o in outcomes]
    assert 0 in depths, f"expected L0 depth=0, got depths={sorted(set(depths))}"
    assert all(d >= 0 for d in depths), "depth must be non-negative"
    buried = [o for o in outcomes if o.was_buried]
    deep = [o for o in outcomes if o.open_depth >= 2]
    if len(deep) >= 3:
        assert sum(o.was_buried for o in deep) >= 1, "depth>=2 sample should include buried layers"
    resolved = [o for o in outcomes if o.resolved]
    for o in resolved:
        assert o.resolution == "exit_hit"
        assert o.time_to_resolution_bars is not None
    print(
        f"sanity_check_depth_tagging OK: layers={len(outcomes)} "
        f"depths={sorted(set(depths))} resolved={len(resolved)} buried={len(buried)}"
    )


def test_wiring() -> None:
    sanity_check_depth_tagging()
    fake = pd.DataFrame({
        "CLOSE": np.linspace(1.25, 1.26, 80),
        "SPREAD": np.full(80, 20),
        "datetime": pd.date_range("2026-01-01", periods=80, freq="5min"),
    })
    with __import__("unittest.mock").mock.patch.object(simv6, "load_mt5_csv", return_value=fake):
        payload = run_analysis(
            n_seeds=2,
            windows={"smoke": "dummy.csv"},
            spacing_modes=["reload_flat"],
            bias_filter=["MM_LONG"],
            workers=1,
            verbose=False,
        )
    assert "reload_flat|smoke|MM_LONG" in payload["cells"]
    print("test_wiring OK")


def main() -> int:
    parser = argparse.ArgumentParser(description="Layer-depth resolution and P&L analysis")
    parser.add_argument("--n-seeds", type=int, default=500)
    parser.add_argument("--workers", type=int, default=1)
    parser.add_argument("--window", type=str, choices=list(ALL_WINDOWS), default=None)
    parser.add_argument("--bias", type=str, choices=list(BIAS_MODES), default=None)
    parser.add_argument("--spacing", type=str, choices=SPACING_MODES, default=None)
    parser.add_argument("--output", type=str, default=None, help="JSON output path")
    parser.add_argument("--smoke-test", action="store_true")
    parser.add_argument("--test-wiring", action="store_true")
    args = parser.parse_args()

    if args.test_wiring:
        test_wiring()
        return 0

    if args.smoke_test:
        sanity_check_depth_tagging()
        payload = run_analysis(
            n_seeds=2,
            windows={"full_quarter": ALL_WINDOWS["full_quarter"]},
            spacing_modes=["reload_flat"],
            bias_filter=["MM_LONG"],
            workers=1,
            verbose=True,
        )
        print_summary(payload)
        return 0

    windows = ALL_WINDOWS
    if args.window:
        windows = {args.window: ALL_WINDOWS[args.window]}
    spacing_modes = [args.spacing] if args.spacing else SPACING_MODES
    bias_filter = [args.bias] if args.bias else None

    payload = run_analysis(
        n_seeds=args.n_seeds,
        windows=windows,
        spacing_modes=spacing_modes,
        bias_filter=bias_filter,
        workers=args.workers,
        verbose=True,
    )
    print_summary(payload)

    out_path = args.output or os.path.join(
        ROOT, "temp", f"layer_depth_analysis_n{args.n_seeds}_report.json"
    )
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(payload, f, indent=2)
    print(f"\nWrote {out_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
