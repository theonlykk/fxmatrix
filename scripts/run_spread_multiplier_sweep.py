#!/usr/bin/env python3
"""
SpreadMultiplier sweep — n=500 Monte Carlo across all five validated GBPUSD windows.

Varies only L0 quote half-spread vol term: dynamic_hs = QUOTE_SPREAD + sigma * multiplier.
Exit/add geometry unchanged (fixed InpExitPips / InpAddPipsFloor grid).

Usage (full sweep, production baseline):
  python scripts/run_spread_multiplier_sweep.py --spread-multiplier 0.5

Usage (parallel seeds, 6 workers):
  python scripts/run_spread_multiplier_sweep.py --spread-multiplier 0.5 --workers 6

Usage (vol term removed):
  python scripts/run_spread_multiplier_sweep.py --spread-multiplier 0.0

Smoke test (one window, 2 seeds):
  python scripts/run_spread_multiplier_sweep.py --spread-multiplier 0.5 --smoke-test

Wiring tests:
  python scripts/run_spread_multiplier_sweep.py --test-wiring
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
from contextlib import contextmanager
from datetime import datetime, timezone
from pathlib import Path
from unittest.mock import patch

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

SPACING_MODES = ["reload_anchor", "reload_flat"]
BIAS_MODES = [
    ("MM_LONG", simv7.BiasMode.LONG_ONLY),
    ("MM_SHORT", simv7.BiasMode.SHORT_ONLY),
    ("MM_BOTH", simv7.BiasMode.BOTH),
]
ALL_WINDOWS = {
    "full_quarter": os.path.join(ROOT, "data", "GBPUSD_full_quarter.csv"),
    "june_blowup": os.path.join(ROOT, "data", "GBPUSD_june_blowup.csv"),
    "truss_crisis": os.path.join(ROOT, "data", "GBPUSD_truss_crisis_oos.csv"),
    "vaccine_rally": os.path.join(ROOT, "data", "GBPUSD_vaccine_rally_oos.csv"),
    "q1_2024_chop": os.path.join(ROOT, "data", "GBPUSD_q1_2024_chop_oos.csv"),
}
STRESS_WINDOWS = ("truss_crisis", "vaccine_rally")
PIP = 0.0001
PAIR_SPREAD_PIPS = simv6.PAIR_SPREAD_PIPS.get("GBPUSD", 0.64)


@contextmanager
def spread_multiplier_context(multiplier: float):
    old = simv7.SPREAD_MULTIPLIER
    simv7.SPREAD_MULTIPLIER = float(multiplier)
    try:
        yield
    finally:
        simv7.SPREAD_MULTIPLIER = old


def precompute_signal(closes: np.ndarray, spread_points: np.ndarray, multiplier: float):
    with spread_multiplier_context(multiplier):
        return simv7.precompute_gbpusd_signal(closes, spread_points)


def _result_sort_key(key):
    spacing_mode, window_name, mode_name = key
    window_order = {
        "full_quarter": 0,
        "june_blowup": 1,
        "truss_crisis": 2,
        "vaccine_rally": 3,
        "q1_2024_chop": 4,
    }
    mode_order = {"MM_LONG": 0, "MM_SHORT": 1, "MM_BOTH": 2}
    spacing_order = {"reload_anchor": 0, "reload_flat": 1}
    return (
        window_order.get(window_name, 99),
        spacing_order.get(spacing_mode, spacing_mode),
        mode_order.get(mode_name, mode_name),
    )


def simulate_instrumented(
    closes,
    bid_arr,
    offer_arr,
    times,
    bias_mode,
    spacing_mode,
    seed,
    pair_spread=PAIR_SPREAD_PIPS,
):
    """Single-seed fill breakdown (seed=0 reference for per-scalp edge)."""
    rng = np.random.default_rng(seed)
    n_bars = len(closes) - 1
    sigma = float(np.std(np.diff(np.log(closes)), ddof=1) * 2.5)
    exit_dist = simv7.pips_to_price(simv7.EXIT_PIPS, PIP)
    half_spread = simv7.pips_to_price(pair_spread / 2.0, PIP)

    layers = []
    current_add_pips = simv7.ADD_PIPS_FLOOR
    last_exit_price = None
    pnl_realised = 0.0
    equity = 10000.0
    daily_start = 10000.0
    current_day = -1
    dd3 = dd4 = False
    max_layers = 0
    l0 = add = reload = exits = 0

    def usd(diff):
        return (diff / PIP) * simv7.USD_PER_PIP

    price_current = closes[0]
    for i in range(n_bars):
        start_price = price_current
        end_price = closes[i + 1]
        dt = 1.0 / 100
        t = np.linspace(0, 1, 101)
        dW = rng.normal(0, np.sqrt(dt), 100)
        W = np.zeros(101)
        W[1:] = np.cumsum(dW)
        bridge = W - t * W[-1]
        path = start_price + (end_price - start_price) * t + sigma * bridge

        bar_quotes = None
        if not layers:
            b, o = bid_arr[i], offer_arr[i]
            if not (np.isnan(b) or np.isnan(o)):
                bar_quotes = (
                    simv7.adr013_clamp(b, 1, start_price, half_spread),
                    simv7.adr013_clamp(o, -1, start_price, half_spread),
                )

        for j in range(len(path)):
            mid = path[j]
            if not layers and bar_quotes is not None:
                bid_c, offer_c = bar_quotes
                ba = (mid - half_spread, mid + half_spread)
                filled = None
                if bias_mode in (simv7.BiasMode.LONG_ONLY, simv7.BiasMode.BOTH) and ba[1] <= bid_c:
                    filled, fill_p = 1, bid_c
                if bias_mode in (simv7.BiasMode.SHORT_ONLY, simv7.BiasMode.BOTH) and ba[0] >= offer_c:
                    if filled is None:
                        filled, fill_p = -1, offer_c
                if filled is not None:
                    layers.append(
                        simv7.Layer(
                            entry_price=fill_p,
                            direction=filled,
                            exit_target_raw=fill_p + filled * exit_dist,
                        )
                    )
                    current_add_pips = simv7.ADD_PIPS_FLOOR
                    last_exit_price = None
                    l0 += 1
                    max_layers = max(max_layers, 1)
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
                    closed = layers.pop()
                    if spacing_mode in ("reload_anchor", "reload_flat"):
                        last_exit_price = closed.entry_price
                    entry_paid = closed.entry_price + closed.direction * half_spread
                    exit_recv = closed.exit_target_raw - closed.direction * half_spread
                    pnl_realised += usd((exit_recv - entry_paid) * closed.direction)
                    exits += 1
            if layers:
                cur = layers[-1]
                used_reload = False
                if spacing_mode == "reload_anchor" and last_exit_price is not None:
                    depth_mult = simv7.WIDEN_RATIO ** (len(layers) // 3)
                    reload_step = min(
                        simv7.ADD_PIPS_CEILING, simv7.ADD_PIPS_FLOOR * depth_mult
                    )
                    add_target = last_exit_price - cur.direction * simv7.pips_to_price(
                        reload_step, PIP
                    )
                    used_reload = True
                elif spacing_mode == "reload_flat" and last_exit_price is not None:
                    add_target = last_exit_price - cur.direction * simv7.pips_to_price(
                        simv7.ADD_PIPS_FLOOR, PIP
                    )
                    used_reload = True
                else:
                    still_shallow = len(layers) < 3
                    add_pips = (
                        simv7.ADD_PIPS_FLOOR
                        if (spacing_mode == "flat" or still_shallow)
                        else current_add_pips
                    )
                    add_target = cur.entry_price - cur.direction * simv7.pips_to_price(
                        add_pips, PIP
                    )
                eff_add = add_target - cur.direction * half_spread
                hit = (cur.direction == 1 and pp > eff_add >= pn) or (
                    cur.direction == -1 and pp < eff_add <= pn
                )
                if hit:
                    layers.append(
                        simv7.Layer(
                            entry_price=add_target,
                            direction=cur.direction,
                            exit_target_raw=add_target + cur.direction * exit_dist,
                        )
                    )
                    if spacing_mode in ("reload_anchor", "reload_flat"):
                        last_exit_price = None
                    if used_reload:
                        reload += 1
                    else:
                        add += 1
                    if len(layers) >= 3:
                        current_add_pips = min(
                            simv7.ADD_PIPS_CEILING,
                            current_add_pips * simv7.WIDEN_RATIO,
                        )
                    max_layers = max(max_layers, len(layers))

        price_current = end_price
        if times is not None:
            bar_day = pd.Timestamp(times[i + 1]).normalize()
            if bar_day != current_day:
                daily_start = 10000.0 if current_day == -1 else equity
                current_day = bar_day
        unreal = 0.0
        for lay in layers:
            cp = end_price - half_spread if lay.direction == 1 else end_price + half_spread
            ep = lay.entry_price + lay.direction * half_spread
            unreal += usd((cp - ep) * lay.direction)
        equity = 10000.0 + pnl_realised + unreal
        if daily_start > 0:
            dd = (daily_start - equity) / daily_start
            if dd >= 0.04:
                dd4 = True
            if dd >= 0.03:
                dd3 = True

    per_scalp = pnl_realised / exits if exits else 0.0
    return {
        "l0": l0,
        "add": add,
        "reload": reload,
        "exits": exits,
        "entries_total": l0 + add + reload,
        "realised_usd": pnl_realised,
        "per_scalp_usd": per_scalp,
        "max_layers": max_layers,
        "dd3": dd3,
        "dd4": dd4,
    }


def _worker_simulate_batch(payload: dict) -> list[tuple[int, dict]]:
    """Process-pool worker: run a batch of seeds (Windows spawn-safe)."""
    import importlib.util as _ilu

    root = Path(payload["root"])
    spec7 = _ilu.spec_from_file_location(
        "simv7", root / "scripts" / "grid_sim_v7_real_signal.py"
    )
    sim7 = _ilu.module_from_spec(spec7)
    spec7.loader.exec_module(sim7)
    spec6 = _ilu.spec_from_file_location(
        "simv6", root / "scripts" / "grid_sim_v6_dynamic_spacing.py"
    )
    sim6 = _ilu.module_from_spec(spec6)
    spec6.loader.exec_module(sim6)
    sys.modules["grid_sim_v6_dynamic_spacing"] = sim6

    patched = dict(sim6.PAIR_SPREAD_PIPS)
    patched[payload["symbol"].upper()] = payload["pair_spread"]

    closes = np.asarray(payload["closes"], dtype=float)
    bid = np.asarray(payload["bid"], dtype=float)
    offer = np.asarray(payload["offer"], dtype=float)
    times = np.asarray(payload["times"])
    out: list[tuple[int, dict]] = []
    with patch.dict(sim6.PAIR_SPREAD_PIPS, patched, clear=False):
        for seed in payload["seeds"]:
            r = sim7.simulate_one_path(
                closes,
                bid,
                offer,
                times=times,
                symbol=payload["symbol"].upper(),
                bias_mode=payload["bias_mode"],
                spacing_mode=payload["spacing"],
                seed=int(seed),
                sub_steps=100,
            )
            out.append((int(seed), r))
    return out


def parallel_seed_runs(
    closes,
    bid,
    offer,
    times,
    n_seeds: int,
    spacing_mode: str,
    bias_mode,
    workers: int = 1,
    symbol: str = "GBPUSD",
    pair_spread: float = PAIR_SPREAD_PIPS,
) -> list[dict]:
    """Run n_seeds independent paths; return results in seed order (0..n-1)."""
    workers = max(1, min(workers, n_seeds))
    chunk = max(1, math.ceil(n_seeds / (workers * 2)))
    batches = []
    for start in range(0, n_seeds, chunk):
        batches.append(list(range(start, min(n_seeds, start + chunk))))
    payload_base = {
        "root": str(ROOT),
        "symbol": symbol.upper(),
        "pair_spread": pair_spread,
        "closes": closes,
        "bid": bid,
        "offer": offer,
        "times": times,
        "spacing": spacing_mode,
        "bias_mode": int(bias_mode),
    }
    results_by_seed: dict[int, dict] = {}
    with ProcessPoolExecutor(max_workers=workers) as pool:
        futs = []
        for seeds in batches:
            p = dict(payload_base)
            p["seeds"] = seeds
            futs.append(pool.submit(_worker_simulate_batch, p))
        for fut in as_completed(futs):
            for seed, result in fut.result():
                results_by_seed[seed] = result
    return [results_by_seed[s] for s in range(n_seeds)]


def _aggregate_seed_results(seed_results: list[dict], n_seeds: int) -> dict:
    pnls = [r["pnl_total_usd"] for r in seed_results]
    realised = [r["pnl_realised_usd"] for r in seed_results]
    unrealised = [r["pnl_unrealised_usd"] for r in seed_results]
    total_trades_list = [r.get("total_trades", 0) for r in seed_results]
    max_layers_list = [r["max_layers"] for r in seed_results]
    nonflat_count = sum(1 for r in seed_results if abs(r["pnl_unrealised_usd"]) > 1e-12)
    dd3_count = sum(1 for r in seed_results if r["drawdown_exceeded_3pct"])
    dd4_count = sum(1 for r in seed_results if r["drawdown_exceeded_4pct"])
    return {
        "mean_pnl": float(np.mean(pnls)),
        "std_pnl": float(np.std(pnls)),
        "worst_pnl": float(np.min(pnls)),
        "best_pnl": float(np.max(pnls)),
        "mean_realised": float(np.mean(realised)),
        "mean_unrealised": float(np.mean(unrealised)),
        "nonflat_pct": nonflat_count / n_seeds * 100.0,
        "mean_max_layers": float(np.mean(max_layers_list)),
        "max_max_layers": int(np.max(max_layers_list)),
        "mean_total_trades": float(np.mean(total_trades_list)),
        "dd3_count": dd3_count,
        "dd4_count": dd4_count,
        "dd3_rate": dd3_count / n_seeds * 100.0,
        "dd4_rate": dd4_count / n_seeds * 100.0,
    }


def run_sweep(
    spread_multiplier: float,
    n_seeds: int = 500,
    windows: dict | None = None,
    spacing_modes: list | None = None,
    verbose: bool = True,
    call_log: list | None = None,
    workers: int = 1,
) -> dict:
    windows = windows or ALL_WINDOWS
    spacing_modes = spacing_modes or SPACING_MODES
    start_time = time.time()
    results = {}
    fill_ref = {}

    for spacing_mode in spacing_modes:
        for window_name, path in windows.items():
            df = simv6.load_mt5_csv(path)
            closes = df["CLOSE"].values
            spread_points = df["SPREAD"].values
            times = df["datetime"].values
            bid_arr, offer_arr = precompute_signal(closes, spread_points, spread_multiplier)
            if verbose:
                print(
                    f"Loaded {window_name}: {len(df)} bars, "
                    f"{df['datetime'].iloc[0]} -> {df['datetime'].iloc[-1]}"
                )

            for mode_name, mode in BIAS_MODES:
                if call_log is not None:
                    for s in range(n_seeds):
                        call_log.append((spacing_mode, window_name, mode_name, s))

                if workers == 1:
                    seed_results = []
                    for s in range(n_seeds):
                        seed_results.append(
                            simv7.simulate_one_path(
                                closes,
                                bid_arr,
                                offer_arr,
                                times=times,
                                symbol="GBPUSD",
                                bias_mode=mode,
                                spacing_mode=spacing_mode,
                                seed=s,
                                sub_steps=100,
                            )
                        )
                        if verbose and (s + 1) % 100 == 0:
                            elapsed = time.time() - start_time
                            print(
                                f"    sm={spread_multiplier} {spacing_mode}/{window_name}/{mode_name}: "
                                f"{s + 1}/{n_seeds} seeds ({elapsed:.0f}s elapsed)",
                                flush=True,
                            )
                else:
                    if verbose:
                        print(
                            f"    sm={spread_multiplier} {spacing_mode}/{window_name}/{mode_name}: "
                            f"running {n_seeds} seeds with {workers} workers...",
                            flush=True,
                        )
                    seed_results = parallel_seed_runs(
                        closes,
                        bid_arr,
                        offer_arr,
                        times,
                        n_seeds,
                        spacing_mode,
                        mode,
                        workers=workers,
                    )

                key = (spacing_mode, window_name, mode_name)
                cell = _aggregate_seed_results(seed_results, n_seeds)
                results[key] = cell
                dd3_count = cell["dd3_count"]
                dd4_count = cell["dd4_count"]

                fill_ref[key] = simulate_instrumented(
                    closes,
                    bid_arr,
                    offer_arr,
                    times,
                    mode,
                    spacing_mode,
                    seed=0,
                )
                if verbose:
                    elapsed = time.time() - start_time
                    r = results[key]
                    f = fill_ref[key]
                    print(
                        f"  DONE: sm={spread_multiplier} {spacing_mode}/{window_name}/{mode_name} "
                        f"realised=${r['mean_realised']:.2f} DD3={dd3_count} DD4={dd4_count} "
                        f"maxL={r['max_max_layers']} L0(ref)={f['l0']} ({elapsed:.0f}s)\n",
                        flush=True,
                    )

    return {"monte_carlo": results, "fill_reference_seed0": fill_ref, "elapsed_sec": time.time() - start_time}


def summarize_by_window(results: dict) -> dict:
    out = {}
    for window in ALL_WINDOWS:
        cells = [r for (sp, w, _m), r in results.items() if w == window]
        if not cells:
            continue
        out[window] = {
            "mean_realised_sum": sum(c["mean_realised"] for c in cells),
            "dd3_total": sum(c["dd3_count"] for c in cells),
            "dd4_total": sum(c["dd4_count"] for c in cells),
            "max_max_layers": max(c["max_max_layers"] for c in cells),
        }
    return out


def print_results(payload: dict, spread_multiplier: float, n_seeds: int) -> None:
    results = payload["monte_carlo"]
    fill_ref = payload["fill_reference_seed0"]
    print(
        f"\n{'=' * 150}\n"
        f"SPREAD MULTIPLIER SWEEP — multiplier={spread_multiplier} (n={n_seeds} seeds/cell)\n"
        f"{'=' * 150}\n"
    )
    print(
        f"{'Window':<14}{'Spacing':<14}{'Mode':<9}"
        f"{'MeanReal':<11}{'DD3#':<6}{'DD4#':<6}{'MaxL':<5}"
        f"{'L0s0':<6}{'Adds0':<6}{'Rlds0':<6}{'Exits0':<7}{'PerScalp0':<10}"
        f"{'MnTrades':<9}"
    )
    for key in sorted(results.keys(), key=_result_sort_key):
        spacing_mode, window_name, mode_name = key
        r = results[key]
        f = fill_ref[key]
        print(
            f"{window_name:<14}{spacing_mode:<14}{mode_name:<9}"
            f"${r['mean_realised']:<10.2f}{r['dd3_count']:<6}{r['dd4_count']:<6}"
            f"{r['max_max_layers']:<5}"
            f"{f['l0']:<6}{f['add']:<6}{f['reload']:<6}{f['exits']:<7}"
            f"${f['per_scalp_usd']:<9.3f}{r['mean_total_trades']:<9.1f}"
        )

    ws = summarize_by_window(results)
    print(f"\n=== Per-window rollup (sum MeanRealised across 6 cells) ===")
    for wname, w in ws.items():
        tag = " ** STRESS **" if wname in STRESS_WINDOWS else ""
        print(
            f"  {wname:<14} sum_realised=${w['mean_realised_sum']:>8.2f}  "
            f"DD3={w['dd3_total']:<4} DD4={w['dd4_total']:<4} maxL={w['max_max_layers']}{tag}"
        )

    stress_dd3 = sum(ws[w]["dd3_total"] for w in STRESS_WINDOWS if w in ws)
    stress_dd4 = sum(ws[w]["dd4_total"] for w in STRESS_WINDOWS if w in ws)
    print(
        f"\n=== Stress windows combined ({', '.join(STRESS_WINDOWS)}) ==="
        f"\n  DD3 total (6 cells × {n_seeds} seeds each = 30 seed-runs/window): {stress_dd3}"
        f"\n  DD4 total: {stress_dd4}"
    )
    print(f"\nElapsed: {payload['elapsed_sec']:.0f}s")


def test_spread_multiplier_affects_signal():
    fake_closes = np.linspace(1.25, 1.30, 60)
    fake_spread = np.full(60, 6.4)
    bid0, off0 = precompute_signal(fake_closes, fake_spread, 0.0)
    bid5, off5 = precompute_signal(fake_closes, fake_spread, 0.5)
    valid = ~np.isnan(bid0) & ~np.isnan(bid5)
    assert np.any(valid)
    # multiplier=0 -> tighter bid (higher for buy side below mid in log space — wider half spread lowers bid)
    # With 0 multiplier, dynamic_hs is smaller -> bid should be >= bid at 0.5 mult (closer to mid from below)
    assert np.mean(bid0[valid]) >= np.mean(bid5[valid])


def test_workers_parity(n_seeds: int = 20, workers_a: int = 1, workers_b: int = 4) -> None:
    """Per-seed outcomes must match regardless of worker count."""
    path = ALL_WINDOWS["full_quarter"]
    df = simv6.load_mt5_csv(path)
    closes = df["CLOSE"].values
    spread_points = df["SPREAD"].values
    times = df["datetime"].values
    bid_arr, offer_arr = precompute_signal(closes, spread_points, 0.5)
    spacing_mode = "reload_anchor"
    _, mode = BIAS_MODES[0]  # MM_LONG

    runs_a = parallel_seed_runs(
        closes, bid_arr, offer_arr, times, n_seeds, spacing_mode, mode, workers=workers_a
    )
    runs_b = parallel_seed_runs(
        closes, bid_arr, offer_arr, times, n_seeds, spacing_mode, mode, workers=workers_b
    )
    assert len(runs_a) == n_seeds and len(runs_b) == n_seeds
    keys = (
        "pnl_total_usd",
        "pnl_realised_usd",
        "pnl_unrealised_usd",
        "max_layers",
        "total_trades",
        "drawdown_exceeded_3pct",
        "drawdown_exceeded_4pct",
    )
    for s in range(n_seeds):
        for k in keys:
            va = runs_a[s].get(k)
            vb = runs_b[s].get(k)
            assert va == vb, f"seed {s} key {k}: workers={workers_a} got {va!r}, workers={workers_b} got {vb!r}"

    sweep_a = run_sweep(
        0.5,
        n_seeds=n_seeds,
        windows={"full_quarter": path},
        spacing_modes=["reload_anchor"],
        verbose=False,
        workers=workers_a,
    )
    sweep_b = run_sweep(
        0.5,
        n_seeds=n_seeds,
        windows={"full_quarter": path},
        spacing_modes=["reload_anchor"],
        verbose=False,
        workers=workers_b,
    )
    assert sweep_a["monte_carlo"] == sweep_b["monte_carlo"]
    assert sweep_a["fill_reference_seed0"] == sweep_b["fill_reference_seed0"]


def test_wiring():
    call_log = []

    def stub_simulate(*args, **kwargs):
        return {
            "pnl_total_usd": 0.0,
            "pnl_realised_usd": 0.0,
            "pnl_unrealised_usd": 0.0,
            "max_layers": 0,
            "total_trades": 0,
            "drawdown_exceeded_3pct": False,
            "drawdown_exceeded_4pct": False,
        }

    fake_df = pd.DataFrame({
        "CLOSE": np.linspace(1.25, 1.26, 60),
        "SPREAD": np.full(60, 20),
        "datetime": pd.date_range("2026-01-01", periods=60, freq="5min"),
    })
    fake_windows = {"smoke_win": "dummy.csv"}
    with patch.object(simv6, "load_mt5_csv", return_value=fake_df):
        payload = run_sweep(
            spread_multiplier=0.25,
            n_seeds=2,
            windows=fake_windows,
            spacing_modes=SPACING_MODES,
            verbose=False,
            call_log=call_log,
        )
    assert len(payload["monte_carlo"]) == len(SPACING_MODES) * len(BIAS_MODES)
    assert len(call_log) == len(SPACING_MODES) * len(BIAS_MODES) * 2


def main():
    parser = argparse.ArgumentParser(description="SpreadMultiplier n=500 sweep (GBPUSD, 5 windows)")
    parser.add_argument(
        "--spread-multiplier",
        type=float,
        required=True,
        help="Vol term on L0 dynamic_hs (0.0=removed, 0.5=production)",
    )
    parser.add_argument("--n-seeds", type=int, default=500, help="Seeds per cell (default 500)")
    parser.add_argument(
        "--output-json",
        type=str,
        default="",
        help="Write full results JSON (default: temp/spread_mult_<value>_report.json)",
    )
    parser.add_argument(
        "--smoke-test",
        action="store_true",
        help="Sanity run: full_quarter only, n=2 seeds",
    )
    parser.add_argument(
        "--windows",
        nargs="*",
        default=None,
        help="Optional subset of window keys (default: all five)",
    )
    parser.add_argument(
        "--workers",
        type=int,
        default=1,
        help="Parallel worker processes for seed batches (default 1 = sequential)",
    )
    args = parser.parse_args()

    print(f"Config: WIDEN_RATIO={simv7.WIDEN_RATIO} ADD_PIPS_CEILING={simv7.ADD_PIPS_CEILING}")
    print(f"QUOTE_SPREAD={simv7.QUOTE_SPREAD} SPREAD_MULTIPLIER(run)={args.spread_multiplier}")
    if args.workers > 1:
        print(f"Workers: {args.workers} (seed-level multiprocessing)")
    assert simv7.WIDEN_RATIO == 1.304
    assert simv7.ADD_PIPS_CEILING == 1000.0

    if args.smoke_test:
        windows = {"full_quarter": ALL_WINDOWS["full_quarter"]}
        n_seeds = 2
        print("SMOKE TEST: full_quarter only, n=2 seeds, both spacing modes, all bias modes\n")
    else:
        windows = ALL_WINDOWS
        if args.windows:
            windows = {k: ALL_WINDOWS[k] for k in args.windows}
            missing = [k for k in args.windows if k not in ALL_WINDOWS]
            if missing:
                print(f"ERROR: unknown windows: {missing}")
                sys.exit(1)
        n_seeds = args.n_seeds
        n_cells = len(windows) * len(SPACING_MODES) * len(BIAS_MODES)
        print(
            f"Full sweep: {len(windows)} windows × 2 spacing × 3 bias = {n_cells} cells × {n_seeds} seeds"
        )
        print("WARNING: Both reload_anchor and reload_flat — expect multi-hour runtime.\n")

    missing = [p for p in windows.values() if not os.path.isfile(p)]
    if missing:
        print(f"ERROR: missing CSV(s): {missing}")
        sys.exit(1)

    payload = run_sweep(
        args.spread_multiplier,
        n_seeds=n_seeds,
        windows=windows,
        workers=args.workers,
    )
    print_results(payload, args.spread_multiplier, n_seeds)

    out_path = args.output_json or os.path.join(
        ROOT,
        "temp",
        f"spread_mult_{args.spread_multiplier:g}_n{n_seeds}_report.json",
    )
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    serializable = {
        "spread_multiplier": args.spread_multiplier,
        "n_seeds": n_seeds,
        "workers": args.workers,
        "windows": list(windows.keys()),
        "timestamp_utc": datetime.now(timezone.utc).isoformat(),
        "elapsed_sec": payload["elapsed_sec"],
        "monte_carlo": {
            f"{k[0]}|{k[1]}|{k[2]}": v for k, v in payload["monte_carlo"].items()
        },
        "fill_reference_seed0": {
            f"{k[0]}|{k[1]}|{k[2]}": v for k, v in payload["fill_reference_seed0"].items()
        },
        "window_summary": summarize_by_window(payload["monte_carlo"]),
    }
    with open(out_path, "w", encoding="utf-8") as fh:
        json.dump(serializable, fh, indent=2)
    print(f"\nWrote JSON: {out_path}")


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--test-wiring":
        test_wiring()
        test_spread_multiplier_affects_signal()
        print("All wiring tests: PASS")
    elif len(sys.argv) > 1 and sys.argv[1] == "--test-workers-parity":
        test_workers_parity(n_seeds=20, workers_a=1, workers_b=4)
        print("Workers parity test (n=20, workers 1 vs 4): PASS")
    else:
        main()
