#!/usr/bin/env python3
"""E7 gate: triangular width distribution vs fixed baseline. Analysis only."""
from __future__ import annotations

import argparse
import importlib.util
import json
import sys
import time
from concurrent.futures import ProcessPoolExecutor, as_completed
from pathlib import Path
from typing import Any
from unittest.mock import patch

import numpy as np
import pandas as pd

SCRIPT_DIR = Path(__file__).resolve().parent
ROOT = SCRIPT_DIR.parent
sys.path.insert(0, str(SCRIPT_DIR))

# Match run_width_exit_sweep: load v6 first, register canonical name for v7 imports.
spec6 = importlib.util.spec_from_file_location(
    "simv6", SCRIPT_DIR / "grid_sim_v6_dynamic_spacing.py"
)
simv6 = importlib.util.module_from_spec(spec6)
spec6.loader.exec_module(simv6)
sys.modules["grid_sim_v6_dynamic_spacing"] = simv6

spec7 = importlib.util.spec_from_file_location(
    "simv7", SCRIPT_DIR / "grid_sim_v7_real_signal.py"
)
simv7 = importlib.util.module_from_spec(spec7)
spec7.loader.exec_module(simv7)

from run_width_exit_sweep import aggregate_seed_results, risk_adjusted_score, survival_score, window_path

BASE_SEED = 20260904

PAIR_GEOM = {
    "GBPUSD": {"harvest": 5.0, "survival": 11.0, "exit": 5.0},
    "EURGBP": {"harvest": 2.5, "survival": 3.0, "exit": 2.0},
}
ALL_WINDOWS = ("q1_2024_chop", "truss_crisis", "full_quarter")
DEFAULT_N_SEEDS = 200
DEFAULT_SUBSTEPS = 20
BIAS_MODE = simv7.BiasMode.BOTH
DEFAULT_CHECKPOINT = ROOT / "temp" / "e7_triangular_gate.json"


def _load_sim_modules(root: Path) -> tuple[Any, Any]:
    """Worker-safe module load (mirrors run_width_exit_sweep._worker_cell)."""
    script_dir = root / "scripts"
    spec7 = importlib.util.spec_from_file_location(
        "simv7", script_dir / "grid_sim_v7_real_signal.py"
    )
    mod7 = importlib.util.module_from_spec(spec7)
    spec7.loader.exec_module(mod7)

    spec6 = importlib.util.spec_from_file_location(
        "simv6", script_dir / "grid_sim_v6_dynamic_spacing.py"
    )
    mod6 = importlib.util.module_from_spec(spec6)
    spec6.loader.exec_module(mod6)
    sys.modules["grid_sim_v6_dynamic_spacing"] = mod6
    return mod7, mod6


def load_window(pair: str, wkey: str) -> tuple[np.ndarray, np.ndarray, float, float]:
    path = window_path(pair, wkey)
    df = simv6.load_mt5_csv(str(path))
    closes = df["CLOSE"].to_numpy(dtype=float)
    times = df["datetime"].to_numpy()
    hours = (pd.Timestamp(times[-1]) - pd.Timestamp(times[0])).total_seconds() / 3600.0
    spread = float(simv6.PAIR_SPREAD_PIPS.get(pair, 0.5))
    return closes, times, hours, spread


def run_cell_seeds(
    closes: np.ndarray,
    times: np.ndarray,
    window_hours: float,
    pair: str,
    mode: str,
    geom: dict[str, float],
    pair_spread: float,
    n_seeds: int,
    substeps: int,
    base_seed: int,
    mod7: Any | None = None,
    mod6: Any | None = None,
) -> dict[str, Any]:
    """Run n_seeds paths for one (window, pair, mode) cell."""
    if mod7 is None or mod6 is None:
        mod7, mod6 = simv7, simv6

    dummy = np.zeros_like(closes)
    patched = dict(mod6.PAIR_SPREAD_PIPS)
    patched[pair] = pair_spread

    seed_results: list[dict] = []
    with patch.dict(mod6.PAIR_SPREAD_PIPS, patched, clear=False):
        for s in range(n_seeds):
            kwargs = dict(
                closes=closes,
                bid_theoretical_arr=dummy,
                offer_theoretical_arr=dummy,
                times=times,
                symbol=pair,
                bias_mode=mod7.BiasMode.BOTH,
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
            seed_results.append(mod7.simulate_one_path(**kwargs))

    cell = aggregate_seed_results(seed_results, window_hours)
    cell["risk_adj"] = risk_adjusted_score(cell)
    cell["survival_adj"] = survival_score(cell)
    if mode == "triangular":
        widths = [r.get("mean_drawn_width_pips", float("nan")) for r in seed_results]
        cell["mean_drawn_width_pips"] = float(np.nanmean(widths))
    return cell


def _run_cell_job(job: dict) -> tuple[str, dict]:
    """Process-pool worker: one (window, pair, mode) cell."""
    root = Path(job["root"])
    mod7, mod6 = _load_sim_modules(root)

    closes = np.asarray(job["closes"], dtype=float)
    times = pd.to_datetime(job["times"]).to_numpy()

    cell = run_cell_seeds(
        closes=closes,
        times=times,
        window_hours=float(job["window_hours"]),
        pair=job["pair"],
        mode=job["mode"],
        geom=job["geom"],
        pair_spread=float(job["pair_spread"]),
        n_seeds=int(job["n_seeds"]),
        substeps=int(job["substeps"]),
        base_seed=int(job["base_seed"]),
        mod7=mod7,
        mod6=mod6,
    )
    cell["window"] = job["wkey"]
    cell["pair"] = job["pair"]
    cell["mode"] = job["mode"]
    return job["key"], cell


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="E7 triangular vs fixed geometry gate")
    p.add_argument(
        "--smoke-test",
        action="store_true",
        help="n=2, q1_2024_chop, GBPUSD only, both modes; writes smoke checkpoint",
    )
    p.add_argument("--n-seeds", type=int, default=None, help="override seed count")
    p.add_argument("--substeps", type=int, default=DEFAULT_SUBSTEPS)
    p.add_argument("--checkpoint", type=Path, default=None, help="checkpoint JSON path")
    p.add_argument("--workers", type=int, default=None, help="process pool size")
    return p.parse_args()


def main() -> None:
    args = parse_args()
    t0 = time.time()

    if args.smoke_test:
        n_seeds = 2
        windows = ("q1_2024_chop",)
        pairs = ("GBPUSD",)
        checkpoint_path = args.checkpoint or (ROOT / "temp" / "e7_triangular_gate_smoke.json")
        workers = 1
    else:
        n_seeds = args.n_seeds if args.n_seeds is not None else DEFAULT_N_SEEDS
        windows = ALL_WINDOWS
        pairs = tuple(PAIR_GEOM.keys())
        checkpoint_path = args.checkpoint or DEFAULT_CHECKPOINT
        workers = args.workers

    results: dict[str, Any] = {
        "base_seed": BASE_SEED,
        "n_seeds": n_seeds,
        "substeps": args.substeps,
        "pairs": {k: PAIR_GEOM[k] for k in pairs},
        "windows": list(windows),
        "cells": {},
    }

    print("E7 GATE — triangular vs fixed")
    print(f"base_seed={BASE_SEED} n_seeds={n_seeds} substeps={args.substeps}")
    print(f"checkpoint: {checkpoint_path}")
    print("=" * 88)

    checkpoint_path.parent.mkdir(parents=True, exist_ok=True)
    if checkpoint_path.exists():
        results = json.loads(checkpoint_path.read_text(encoding="utf-8"))
        print(f"Loaded checkpoint with {len(results.get('cells', {}))} cells")

    jobs: list[dict] = []
    planned_keys: list[str] = []
    for wkey in windows:
        for pair in pairs:
            geom = PAIR_GEOM[pair]
            closes, times, hours, spread = load_window(pair, wkey)
            for mode in ("fixed", "triangular"):
                key = f"{wkey}|{pair}|{mode}"
                planned_keys.append(key)
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
                        "times": [pd.Timestamp(t).isoformat() for t in times],
                        "window_hours": hours,
                        "pair_spread": spread,
                        "n_seeds": n_seeds,
                        "substeps": args.substeps,
                        "base_seed": BASE_SEED,
                        "root": str(ROOT),
                    }
                )

    if workers is None:
        workers = min(4, max(1, len(jobs)))
    print(f"Pending cells: {len(jobs)} | workers={workers}", flush=True)

    if jobs:
        if workers == 1 and len(jobs) == 1:
            key, cell = _run_cell_job(jobs[0])
            results["cells"][key] = cell
            checkpoint_path.write_text(json.dumps(results, indent=2), encoding="utf-8")
            print(
                f"Done {key} | risk_adj={cell['risk_adj']:.1f} exits={cell['mean_exits']:.0f}",
                flush=True,
            )
        elif workers == 1:
            for job in jobs:
                key, cell = _run_cell_job(job)
                results["cells"][key] = cell
                checkpoint_path.write_text(json.dumps(results, indent=2), encoding="utf-8")
                print(
                    f"Done {key} | risk_adj={cell['risk_adj']:.1f} exits={cell['mean_exits']:.0f}",
                    flush=True,
                )
        else:
            with ProcessPoolExecutor(max_workers=workers) as pool:
                futs = [pool.submit(_run_cell_job, j) for j in jobs]
                for fut in as_completed(futs):
                    key, cell = fut.result()
                    results["cells"][key] = cell
                    checkpoint_path.write_text(json.dumps(results, indent=2), encoding="utf-8")
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
    for key in planned_keys:
        if key not in results["cells"]:
            print(f"{key}: MISSING")
            continue
        c = results["cells"][key]
        wkey, pair, mode = key.split("|")
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

    print(f"\nWrote {checkpoint_path}")
    print(f"Elapsed {time.time()-t0:.1f}s")


if __name__ == "__main__":
    main()
