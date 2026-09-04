#!/usr/bin/env python3
"""E7 gate: triangular width distribution vs fixed baseline. Analysis only."""
from __future__ import annotations

import importlib.util
import json
import sys
import time
from concurrent.futures import ProcessPoolExecutor, as_completed
from pathlib import Path

import numpy as np
import pandas as pd

SCRIPT_DIR = Path(__file__).resolve().parent
ROOT = SCRIPT_DIR.parent
sys.path.insert(0, str(SCRIPT_DIR))

spec7 = importlib.util.spec_from_file_location("simv7", SCRIPT_DIR / "grid_sim_v7_real_signal.py")
simv7 = importlib.util.module_from_spec(spec7)
spec7.loader.exec_module(simv7)
spec6 = importlib.util.spec_from_file_location("simv6", SCRIPT_DIR / "grid_sim_v6_dynamic_spacing.py")
simv6 = importlib.util.module_from_spec(spec6)
spec6.loader.exec_module(sim6)

from run_width_exit_sweep import aggregate_seed_results, risk_adjusted_score, survival_score, window_path

# Reproducibility: base seed for the gate run (per-path seed = base + path index)
BASE_SEED = 20260904

PAIRS = {
    "GBPUSD": {"harvest": 5.0, "survival": 11.0, "exit": 5.0},
    "EURGBP": {"harvest": 2.5, "survival": 3.0, "exit": 2.0},
}
WINDOWS = ("q1_2024_chop", "truss_crisis", "full_quarter")
N_SEEDS = 200
SUBSTEPS = 20
BIAS_MODE = simv7.BiasMode.BOTH
SPACING_MODE = "reload_anchor"
CHECKPOINT_PATH = ROOT / "temp" / "e7_triangular_gate.json"


def load_window(pair: str, wkey: str) -> tuple[np.ndarray, np.ndarray, float]:
    path = window_path(pair, wkey)
    df = pd.read_csv(path)
    df["datetime"] = pd.to_datetime(df["datetime"])
    closes = df["CLOSE"].to_numpy(dtype=float)
    times = df["datetime"].to_numpy()
    hours = (pd.Timestamp(times[-1]) - pd.Timestamp(times[0])).total_seconds() / 3600.0
    return closes, times, hours


def _run_cell_job(job: dict) -> tuple[str, dict]:
    """Process-pool worker: one (window, pair, mode) cell."""
    root = Path(job["root"])
    script_dir = root / "scripts"
    spec7 = importlib.util.spec_from_file_location("simv7", script_dir / "grid_sim_v7_real_signal.py")
    sim7 = importlib.util.module_from_spec(spec7)
    spec7.loader.exec_module(sim7)
    spec6 = importlib.util.spec_from_file_location("simv6", script_dir / "grid_sim_v6_dynamic_spacing.py")
    sim6 = importlib.util.module_from_spec(spec6)
    spec6.loader.exec_module(sim6)
    sys.modules["grid_sim_v6_dynamic_spacing"] = sim6

    from run_width_exit_sweep import aggregate_seed_results, risk_adjusted_score, survival_score

    closes = np.asarray(job["closes"], dtype=float)
    times = np.asarray(job["times"])
    pair = job["pair"]
    mode = job["mode"]
    geom = job["geom"]
    n_seeds = job["n_seeds"]
    substeps = job["substeps"]
    base_seed = job["base_seed"]

    dummy = np.zeros_like(closes)
    spread = sim6.PAIR_SPREAD_PIPS.get(pair, 0.5)
    patched = dict(simv6.PAIR_SPREAD_PIPS)
    patched[pair] = spread

    seed_results = []
    from unittest.mock import patch

    with patch.dict(simv6.PAIR_SPREAD_PIPS, patched, clear=False):
        for s in range(n_seeds):
            kwargs = dict(
                closes=closes,
                bid_theoretical_arr=dummy,
                offer_theoretical_arr=dummy,
                times=times,
                symbol=pair,
                bias_mode=sim7.BiasMode.BOTH,
                spacing_mode="reload_anchor",
                seed=base_seed + s,
                sub_steps=substeps,
                exit_pips=geom["exit"],
                track_l0_stats=True,
            )
            if mode == "fixed":
                kwargs["entry_mode"] = "straddle"
                kwargs["straddle_half_width_pips"] = geom["harvest"]
            else:
                kwargs["entry_mode"] = "triangular"
                kwargs["triangular_harvest_pips"] = geom["harvest"]
                kwargs["triangular_survival_pips"] = geom["survival"]
            seed_results.append(sim7.simulate_one_path(**kwargs))

    hours = (pd.Timestamp(times[-1]) - pd.Timestamp(times[0])).total_seconds() / 3600.0
    cell = aggregate_seed_results(seed_results, hours)
    cell["risk_adj"] = risk_adjusted_score(cell)
    cell["survival_adj"] = survival_score(cell)
    if mode == "triangular":
        widths = [r.get("mean_drawn_width_pips", float("nan")) for r in seed_results]
        cell["mean_drawn_width_pips"] = float(np.nanmean(widths))
    cell["window"] = job["wkey"]
    cell["pair"] = pair
    cell["mode"] = mode
    return job["key"], cell


def main() -> None:
    t0 = time.time()
    results: dict = {
        "base_seed": BASE_SEED,
        "n_seeds": N_SEEDS,
        "substeps": SUBSTEPS,
        "pairs": PAIRS,
        "windows": list(WINDOWS),
        "cells": {},
    }

    print("E7 GATE — triangular vs fixed")
    print(f"base_seed={BASE_SEED} n_seeds={N_SEEDS} substeps={SUBSTEPS}")
    print(f"checkpoint: {CHECKPOINT_PATH}")
    print("=" * 88)

    CHECKPOINT_PATH.parent.mkdir(parents=True, exist_ok=True)
    if CHECKPOINT_PATH.exists():
        results = json.loads(CHECKPOINT_PATH.read_text(encoding="utf-8"))
        print(f"Loaded checkpoint with {len(results.get('cells', {}))} cells")

    jobs = []
    for wkey in WINDOWS:
        for pair, geom in PAIRS.items():
            closes, times, hours = load_window(pair, wkey)
            for mode in ("fixed", "triangular"):
                key = f"{wkey}|{pair}|{mode}"
                if key in results["cells"]:
                    print(f"Skip cached {key}", flush=True)
                    continue
                jobs.append(
                    {
                        "key": key,
                        "wkey": wkey,
                        "pair": pair,
                        "mode": mode,
                        "geom": geom,
                        "closes": closes.tolist(),
                        "times": [str(t) for t in times],
                        "n_seeds": N_SEEDS,
                        "substeps": SUBSTEPS,
                        "base_seed": BASE_SEED,
                        "root": str(ROOT),
                    }
                )

    workers = min(4, max(1, len(jobs)))
    print(f"Pending cells: {len(jobs)} | workers={workers}", flush=True)
    if jobs:
        with ProcessPoolExecutor(max_workers=workers) as pool:
            futs = [pool.submit(_run_cell_job, j) for j in jobs]
            for fut in as_completed(futs):
                key, cell = fut.result()
                results["cells"][key] = cell
                CHECKPOINT_PATH.write_text(json.dumps(results, indent=2), encoding="utf-8")
                print(
                    f"Done {key} | risk_adj={cell['risk_adj']:.1f} exits={cell['mean_exits']:.0f}",
                    flush=True,
                )

    print("\n" + "=" * 88)
    print(
        f"{'Window':18} {'Pair':8} {'Mode':10} {'RealPnL':>9} {'RiskAdj':>9} "
        f"{'Exits':>7} {'Harv/hr':>7} {'MedHold':>8} {'dd3%':>6} {'dd4%':>6} {'MaxL':>5}"
    )
    print("-" * 88)
    for wkey in WINDOWS:
        for pair in PAIRS:
            for mode in ("fixed", "triangular"):
                c = results["cells"][f"{wkey}|{pair}|{mode}"]
                print(
                    f"{wkey:18} {pair:8} {mode:10} "
                    f"{c['mean_realised']:9.1f} {c['risk_adj']:9.1f} "
                    f"{c['mean_exits']:7.0f} {c['harvest_per_hr']:7.3f} "
                    f"{c['median_l0_hold_min']:8.1f} {c['dd3_rate']:6.1f} {c['dd4_rate']:6.1f} "
                    f"{c['mean_max_layers']:5.1f}"
                )
                if mode == "triangular":
                    print(
                        f"{'':18} {'':8} {'  drawn W':10} "
                        f"mean={c.get('mean_drawn_width_pips', float('nan')):.2f} pips"
                    )

    print(f"\nWrote {CHECKPOINT_PATH}")
    print(f"Elapsed {time.time()-t0:.1f}s")


if __name__ == "__main__":
    main()
