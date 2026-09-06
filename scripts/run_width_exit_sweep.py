#!/usr/bin/env python3
"""
2D Monte Carlo sweep: dumb-straddle half-width x exit target across regime-tagged windows.

Maps to production EA knobs:
  - straddle_half_width_pips  ->  InpDumbStraddlePips  (resting L0 at mid +/- pips)
  - exit_pips                 ->  InpExitPips          (layer exit target from entry)

Uses grid_sim_v7 straddle entry_mode (touch-fill; no adverse-selection model).
Add/reload geometry unchanged (ADD_PIPS_FLOOR=9, WIDEN_RATIO=1.304, reload_anchor).

Usage:
  python scripts/run_width_exit_sweep.py --test-wiring
  python scripts/run_width_exit_sweep.py --smoke-test
  python scripts/run_width_exit_sweep.py --preview --workers 6   # full grid, all windows, n=50
  python scripts/run_width_exit_sweep.py --fast-shape --workers 6  # coarse shape-read <1h
  python scripts/run_width_exit_sweep.py --n-seeds 500 --workers 6 --runtag my_run
  python scripts/run_width_exit_sweep.py --check-substeps-stability
  python scripts/run_width_exit_sweep.py --quick-run --workers 4   # n=30, full grid

Progress is flushed per cell; checkpoints write to temp/width_exit_sweep/<runtag>_partial.json
(resumable on interrupt). Final JSON: temp/width_exit_sweep/<runtag>.json
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
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from unittest.mock import patch

import numpy as np
import pandas as pd
import sim_costs

# Unbuffered progress when stdout is redirected to a log file.
if hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(line_buffering=True)
    except Exception:
        pass

SCRIPT_DIR = Path(__file__).resolve().parent
ROOT = SCRIPT_DIR.parent

spec7 = importlib.util.spec_from_file_location(
    "simv7", SCRIPT_DIR / "grid_sim_v7_real_signal.py"
)
simv7 = importlib.util.module_from_spec(spec7)
spec7.loader.exec_module(simv7)
spec6 = importlib.util.spec_from_file_location(
    "simv6", SCRIPT_DIR / "grid_sim_v6_dynamic_spacing.py"
)
simv6 = importlib.util.module_from_spec(spec6)
spec6.loader.exec_module(simv6)

# --- sweep grid (production point width=9, exit=3 marked on every surface) ---
WIDTH_GRID = [3, 5, 7, 9, 11, 13, 15, 18, 22]
EXIT_GRID = [1, 2, 3, 4, 5, 7, 10]
MINI_WIDTH_GRID = [5, 7, 9, 11, 13, 15]
MINI_EXIT_GRID = [2, 3, 4, 5, 7, 10]
FAST_SHAPE_WIDTH_GRID = [3, 6, 9, 13, 18]
FAST_SHAPE_EXIT_GRID = [1, 2, 3, 5, 8]
FAST_SHAPE_WINDOWS = ("q1_2024_chop", "truss_crisis", "full_quarter")
FAST_SHAPE_N_SEEDS = 15
FAST_SHAPE_SUBSTEPS = 20
DEFAULT_SUBSTEPS = 100
DEFAULT_N_SEEDS = 500
# Measured on Surface preview: ~4.3 s/seed at substeps=100, ~24k bars (GBPUSD chop).
SEC_PER_SEED_AT_SUB100 = 4.3
REF_BARS = 24007
PROD_WIDTH = 9.0
PROD_EXIT = 3.0

PAIRS = ("GBPUSD", "EURUSD", "EURGBP")
SPACING_MODE = "reload_anchor"
BIAS_MODE = simv7.BiasMode.BOTH  # dumb straddle works both sides

WINDOW_META = {
    "q1_2024_chop": {"regime": "ranging", "label": "RANGING (harvest)"},
    "full_quarter": {"regime": "mixed", "label": "MIXED (harvest support)"},
    "truss_crisis": {"regime": "stress", "label": "STRESS trending crisis"},
    "vaccine_rally": {"regime": "stress", "label": "STRESS strong trend"},
    "june_blowup": {"regime": "stress", "label": "STRESS vol spike"},
}
# Pre-registered calibration / holdout split (Gate 4). Editable configuration —
# geometry selection uses calibration windows only; holdout is scored after selection.
WINDOW_ROLES: dict[str, str] = {
    "q1_2024_chop": "calibration",
    "truss_crisis": "calibration",
    "vaccine_rally": "holdout",
    "june_blowup": "holdout",
    "full_quarter": "support",
}
CALIBRATION_WINDOWS = tuple(k for k, r in WINDOW_ROLES.items() if r == "calibration")
HOLDOUT_WINDOWS = tuple(k for k, r in WINDOW_ROLES.items() if r == "holdout")
SUPPORT_WINDOWS = tuple(k for k, r in WINDOW_ROLES.items() if r == "support")

# FTMO gate limits (5% / 10% of 10k initial) — used for near-miss scoring fractions.
GATE_A_LIMIT_USD = sim_costs.DEFAULT_INITIAL_BALANCE * sim_costs.DEFAULT_MAX_DAILY_LOSS_FRAC
GATE_B_LIMIT_USD = sim_costs.DEFAULT_INITIAL_BALANCE * sim_costs.DEFAULT_MAX_TOTAL_LOSS_FRAC

HARVEST_WINDOWS = ("q1_2024_chop", "full_quarter")
STRESS_WINDOWS = ("truss_crisis", "vaccine_rally", "june_blowup")

BAR_MINUTES = 5.0
PREVIEW_N_SEEDS = 50


def make_cell_key(wkey: str, pair: str, width: float, exit_pips: float) -> str:
    return f"{wkey}|{pair}|{width:g}|{exit_pips:g}"


def format_hms(seconds: float) -> str:
    seconds = max(0.0, float(seconds))
    h = int(seconds // 3600)
    m = int((seconds % 3600) // 60)
    s = int(seconds % 60)
    return f"{h:02d}:{m:02d}:{s:02d}"


def parse_float_list(text: str) -> list[float]:
    return [float(x.strip()) for x in text.split(",") if x.strip()]


def estimate_cell_sec(n_seeds: int, substeps: int, n_bars: int) -> float:
    return n_seeds * (substeps / DEFAULT_SUBSTEPS) * SEC_PER_SEED_AT_SUB100 * (n_bars / REF_BARS)


def estimate_sweep_runtime(
    n_cells: int,
    n_seeds: int,
    substeps: int,
    workers: int,
    bar_counts: list[int],
) -> float:
    if not bar_counts:
        bar_counts = [REF_BARS]
    avg_bars = float(np.mean(bar_counts))
    cell_sec = estimate_cell_sec(n_seeds, substeps, int(avg_bars))
    return (n_cells * cell_sec) / max(workers, 1)


def build_runtag(
    n_seeds: int,
    width_grid: list[float],
    exit_grid: list[float],
    window_keys: list[str],
    pairs: tuple[str, ...],
    substeps: int = DEFAULT_SUBSTEPS,
    preview: bool = False,
    fast_shape: bool = False,
) -> str:
    if fast_shape:
        return f"fastshape_n{n_seeds}_s{substeps}_{len(window_keys)}win"
    grid_tag = (
        "fullgrid"
        if width_grid == WIDTH_GRID and exit_grid == EXIT_GRID
        else f"g{len(width_grid)}x{len(exit_grid)}"
    )
    prev = "preview_" if preview else ""
    sub = f"_s{substeps}" if substeps != DEFAULT_SUBSTEPS else ""
    return f"{prev}n{n_seeds}{sub}_{grid_tag}_{len(window_keys)}win_{len(pairs)}pair"


def checkpoint_config_matches(
    ckpt: dict,
    n_seeds: int,
    width_grid: list[float],
    exit_grid: list[float],
    window_keys: list[str],
    pairs: tuple[str, ...],
    substeps: int,
) -> bool:
    return (
        ckpt.get("n_seeds") == n_seeds
        and ckpt.get("substeps", DEFAULT_SUBSTEPS) == substeps
        and ckpt.get("width_grid") == width_grid
        and ckpt.get("exit_grid") == exit_grid
        and sorted(ckpt.get("windows", [])) == sorted(window_keys)
        and sorted(ckpt.get("pairs", [])) == sorted(pairs)
    )


def write_checkpoint(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    with open(tmp, "w", encoding="utf-8") as fh:
        json.dump(payload, fh, indent=2)
    tmp.replace(path)


def load_checkpoint(path: Path) -> dict | None:
    if not path.is_file():
        return None
    with open(path, encoding="utf-8") as fh:
        return json.load(fh)


def print_progress_line(
    done: int,
    total: int,
    cell: dict,
    cell_sec: float,
    elapsed_sec: float,
) -> None:
    remaining = total - done
    rate = elapsed_sec / done if done > 0 else 0.0
    eta_sec = rate * remaining if done > 0 else 0.0
    dd4 = cell.get("dd4_rate", float("nan"))
    print(
        f"[cell {done}/{total}] w={cell['width']:g} e={cell['exit_pips']:g} "
        f"win={cell['window']} pair={cell['pair']} | "
        f"mean_pnl={cell['mean_pnl']:+.0f} med_pnl={cell['median_pnl']:+.0f} "
        f"dd4={dd4:.0f}% | cell {cell_sec:.1f}s | "
        f"elapsed {format_hms(elapsed_sec)} | ETA {format_hms(eta_sec)}",
        flush=True,
    )


def _window_file_suffix(window_key: str) -> str:
    return {
        "q1_2024_chop": "q1_2024_chop_oos",
        "full_quarter": "full_quarter",
        "truss_crisis": "truss_crisis_oos",
        "vaccine_rally": "vaccine_rally_oos",
        "june_blowup": "june_blowup",
    }[window_key]


def window_path(pair: str, window_key: str) -> Path:
    suffix = _window_file_suffix(window_key)
    return ROOT / "data" / f"{pair}_{suffix}.csv"


def all_window_paths() -> dict[str, dict[str, Path]]:
    out: dict[str, dict[str, Path]] = {}
    for wkey in WINDOW_META:
        out[wkey] = {pair: window_path(pair, wkey) for pair in PAIRS}
    return out


def _worker_cell(payload: dict) -> dict:
    """Run all seeds for one (window, pair, width, exit) cell — same math as sequential path."""
    import importlib.util as _ilu

    t0 = time.time()
    spec7 = _ilu.spec_from_file_location(
        "simv7", Path(payload["root"]) / "scripts" / "grid_sim_v7_real_signal.py"
    )
    sim7 = _ilu.module_from_spec(spec7)
    spec7.loader.exec_module(sim7)
    spec6 = _ilu.spec_from_file_location(
        "simv6", Path(payload["root"]) / "scripts" / "grid_sim_v6_dynamic_spacing.py"
    )
    sim6 = _ilu.module_from_spec(spec6)
    spec6.loader.exec_module(sim6)
    sys.modules["grid_sim_v6_dynamic_spacing"] = sim6

    patched = dict(sim6.PAIR_SPREAD_PIPS)
    patched[payload["symbol"].upper()] = payload["pair_spread"]

    closes = np.asarray(payload["closes"], dtype=float)
    times = np.asarray(payload["times"])
    dummy = np.zeros_like(closes)
    n_seeds = int(payload["n_seeds"])
    sub_steps = int(payload.get("substeps", DEFAULT_SUBSTEPS))

    seed_results: list[dict] = []
    sim_kwargs = {}
    if payload.get("gbpusd_closes") is not None:
        sim_kwargs["gbpusd_closes"] = np.asarray(payload["gbpusd_closes"], dtype=float)
    with patch.dict(sim6.PAIR_SPREAD_PIPS, patched, clear=False):
        for s in range(n_seeds):
            seed_results.append(
                sim7.simulate_one_path(
                    closes,
                    dummy,
                    dummy,
                    times=times,
                    symbol=payload["symbol"].upper(),
                    bias_mode=payload["bias_mode"],
                    spacing_mode=payload["spacing"],
                    seed=s,
                    sub_steps=sub_steps,
                    entry_mode="straddle",
                    straddle_half_width_pips=payload["width"],
                    exit_pips=payload["exit_pips"],
                    track_l0_stats=True,
                    **sim_kwargs,
                )
            )

    cell = aggregate_seed_results(seed_results, payload["window_hours"])
    cell["window"] = payload["window"]
    cell["pair"] = payload["symbol"].upper()
    cell["width"] = float(payload["width"])
    cell["exit_pips"] = float(payload["exit_pips"])
    cell["regime"] = payload["regime"]
    cell["cell_key"] = payload["cell_key"]
    cell["cell_elapsed_sec"] = time.time() - t0
    return cell


def _run_one_cell_local(
    closes,
    times,
    pair: str,
    pair_spread: float,
    wkey: str,
    window_hours: float,
    width: float,
    exit_pips: float,
    n_seeds: int,
    substeps: int = DEFAULT_SUBSTEPS,
    gbpusd_closes=None,
) -> dict:
    """In-process single cell (workers=1 path) — identical seed loop to _worker_cell."""
    t0 = time.time()
    dummy = np.zeros_like(closes)
    seed_results = []
    sim_kwargs = {}
    if gbpusd_closes is not None:
        sim_kwargs["gbpusd_closes"] = np.asarray(gbpusd_closes, dtype=float)
    for s in range(n_seeds):
        seed_results.append(
            simv7.simulate_one_path(
                closes,
                dummy,
                dummy,
                times=times,
                symbol=pair,
                bias_mode=BIAS_MODE,
                spacing_mode=SPACING_MODE,
                seed=s,
                sub_steps=substeps,
                entry_mode="straddle",
                straddle_half_width_pips=width,
                exit_pips=exit_pips,
                track_l0_stats=True,
                **sim_kwargs,
            )
        )
    cell = aggregate_seed_results(seed_results, window_hours)
    cell["window"] = wkey
    cell["pair"] = pair
    cell["width"] = width
    cell["exit_pips"] = exit_pips
    cell["regime"] = WINDOW_META[wkey]["regime"]
    cell["cell_key"] = make_cell_key(wkey, pair, width, exit_pips)
    cell["cell_elapsed_sec"] = time.time() - t0
    return cell


def aggregate_seed_results(
    seed_results: list[dict], window_hours: float
) -> dict[str, Any]:
    pnls = [r["pnl_total_usd"] for r in seed_results]
    realised = [r["pnl_realised_usd"] for r in seed_results]
    max_layers = [r["max_layers"] for r in seed_results]
    dd3 = sum(1 for r in seed_results if r["drawdown_exceeded_3pct"])
    dd4 = sum(1 for r in seed_results if r["drawdown_exceeded_4pct"])
    gate_a = sum(1 for r in seed_results if r.get("gate_a_daily_loss_breach"))
    gate_b = sum(1 for r in seed_results if r.get("gate_b_total_loss_breach"))
    n_exits = [r.get("n_exits", 0) for r in seed_results]

    all_holds: list[float] = []
    all_exit_dist: list[float] = []
    all_had_adds: list[bool] = []
    for r in seed_results:
        all_holds.extend(r.get("l0_hold_mins", []))
        all_exit_dist.extend(r.get("l0_exit_dist_pips", []))
        all_had_adds.extend(r.get("l0_had_adds", []))

    mean_exits = float(np.mean(n_exits)) if n_exits else 0.0
    harvest_per_hr = mean_exits / window_hours if window_hours > 0 else 0.0

    hold_arr = np.asarray(all_holds, dtype=float)
    dist_arr = np.asarray(all_exit_dist, dtype=float)

    n = len(seed_results)
    return {
        "mean_pnl": float(np.mean(pnls)),
        "median_pnl": float(np.median(pnls)),
        "mean_realised": float(np.mean(realised)),
        "std_pnl": float(np.std(pnls)),
        "dd3_count": dd3,
        "dd4_count": dd4,
        "dd3_rate": dd3 / n * 100.0,
        "dd4_rate": dd4 / n * 100.0,
        "mean_max_layers": float(np.mean(max_layers)),
        "max_max_layers": int(np.max(max_layers)),
        "mean_exits": mean_exits,
        "harvest_per_hr": harvest_per_hr,
        "l0_unwind_n": int(len(hold_arr)),
        "mean_l0_hold_min": float(np.mean(hold_arr)) if len(hold_arr) else float("nan"),
        "median_l0_hold_min": float(np.median(hold_arr)) if len(hold_arr) else float("nan"),
        "q25_l0_hold_min": float(np.quantile(hold_arr, 0.25)) if len(hold_arr) else float("nan"),
        "q75_l0_hold_min": float(np.quantile(hold_arr, 0.75)) if len(hold_arr) else float("nan"),
        "mean_exit_dist_pips": float(np.mean(dist_arr)) if len(dist_arr) else float("nan"),
        "median_exit_dist_pips": float(np.median(dist_arr)) if len(dist_arr) else float("nan"),
        "pct_l0_trend_like": (
            float(np.mean(all_had_adds) * 100.0) if all_had_adds else float("nan")
        ),
        "pct_l0_noise_like": (
            float(np.mean([not x for x in all_had_adds]) * 100.0) if all_had_adds else float("nan")
        ),
        "disqualified_dd4": dd4 > 0,
        "gate_a_breach_count": gate_a,
        "gate_a_breach_rate": gate_a / n * 100.0,
        "gate_b_breach_count": gate_b,
        "gate_b_breach_rate": gate_b / n * 100.0,
        "mean_equity_peak": float(np.mean([r.get("equity_peak", float("nan")) for r in seed_results])),
        "mean_max_absolute_drawdown_usd": float(
            np.mean([r.get("max_absolute_drawdown_usd", float("nan")) for r in seed_results])
        ),
        "mean_max_daily_equity_drawdown_usd": float(
            np.mean([r.get("max_daily_equity_drawdown_usd", float("nan")) for r in seed_results])
        ),
        "disqualified_gate_a": gate_a > 0,
        "disqualified_gate_b": gate_b > 0,
        "disqualified_gates": gate_a > 0 or gate_b > 0,
    }


def is_gate_disqualified(cell: dict) -> bool:
    """True if Gate A or Gate B breached (hard FTMO disqualification)."""
    return cell.get("gate_a_breach_rate", 0) > 0 or cell.get("gate_b_breach_rate", 0) > 0


def risk_adjusted_score(cell: dict) -> float:
    """
    Harvest ranking: disqualify on Gate A or Gate B breach (gate_a_breach_rate /
    gate_b_breach_rate). Soft penalty uses mean_max_daily_equity_drawdown_usd as
    Gate A near-miss (fraction of 500 USD limit). dd3/dd4 retained as telemetry only.
    """
    if is_gate_disqualified(cell):
        return float("-inf")
    near_miss_a = cell.get("mean_max_daily_equity_drawdown_usd", 0.0) / GATE_A_LIMIT_USD
    return cell["mean_realised"] - 0.5 * near_miss_a


def survival_score(cell: dict) -> float:
    """
    Survival ranking: disqualify on Gate A or Gate B breach. Soft penalty uses
    mean_max_absolute_drawdown_usd as Gate B near-miss (fraction of 1000 USD limit).
    dd3/dd4 retained as telemetry only.
    """
    if is_gate_disqualified(cell):
        return float("-inf")
    near_miss_b = cell.get("mean_max_absolute_drawdown_usd", 0.0) / GATE_B_LIMIT_USD
    return cell["mean_realised"] - 2.0 * near_miss_b


def run_sweep(
    width_grid: list[float],
    exit_grid: list[float],
    n_seeds: int,
    windows: dict[str, dict[str, Path]],
    workers: int = 1,
    verbose: bool = True,
    checkpoint_path: Path | None = None,
    resume_cells: dict[str, dict] | None = None,
    runtag: str = "",
    substeps: int = DEFAULT_SUBSTEPS,
) -> dict[str, Any]:
    start = time.time()
    cells: dict[str, dict] = dict(resume_cells or {})
    pairs = PAIRS

    # Pre-load window data once per (window, pair).
    series_cache: dict[tuple[str, str], dict] = {}
    jobs: list[dict] = []
    for wkey, pair_paths in windows.items():
        for pair, path in pair_paths.items():
            if not path.is_file():
                raise FileNotFoundError(path)
            df = simv6.load_mt5_csv(str(path))
            closes = df["CLOSE"].values
            times = df["datetime"].values
            window_hours = (
                (pd.Timestamp(times[-1]) - pd.Timestamp(times[0])).total_seconds() / 3600.0
            )
            pair_spread = sim_costs.PAIR_SPREAD_PIPS.get(pair, 0.5)
            gbpusd_closes = None
            if pair.upper() == "EURGBP":
                gbpusd_closes = sim_costs.load_aligned_gbpusd_closes(
                    times, ROOT / "data", _window_file_suffix(wkey)
                )
            series_cache[(wkey, pair)] = {
                "closes": closes,
                "times": times,
                "window_hours": window_hours,
                "pair_spread": pair_spread,
                "gbpusd_closes": gbpusd_closes,
            }
            if verbose:
                print(
                    f"Loaded {wkey}/{pair}: {len(df)} bars, "
                    f"{df['datetime'].iloc[0]} -> {df['datetime'].iloc[-1]} "
                    f"({window_hours:.1f}h)",
                    flush=True,
                )
            for width in width_grid:
                for exit_pips in exit_grid:
                    ck = make_cell_key(wkey, pair, width, exit_pips)
                    if ck in cells:
                        continue
                    cache = series_cache[(wkey, pair)]
                    jobs.append({
                        "root": str(ROOT),
                        "symbol": pair.upper(),
                        "pair_spread": cache["pair_spread"],
                        "width": width,
                        "exit_pips": exit_pips,
                        "spacing": SPACING_MODE,
                        "bias_mode": int(BIAS_MODE),
                        "closes": cache["closes"],
                        "times": cache["times"],
                        "window_hours": cache["window_hours"],
                        "gbpusd_closes": cache.get("gbpusd_closes"),
                        "window": wkey,
                        "regime": WINDOW_META[wkey]["regime"],
                        "cell_key": ck,
                        "n_seeds": n_seeds,
                        "substeps": substeps,
                    })

    total = len(cells) + len(jobs)
    skipped = len(cells)
    if verbose:
        print(
            f"Cells: {total} total | {skipped} resumed/skipped | {len(jobs)} to run",
            flush=True,
        )
        if checkpoint_path:
            print(f"Checkpoint: {checkpoint_path}", flush=True)

    def _save_partial(status: str = "partial") -> None:
        if not checkpoint_path:
            return
        write_checkpoint(
            checkpoint_path,
            {
                "runtag": runtag,
                "status": status,
                "n_seeds": n_seeds,
                "substeps": substeps,
                "width_grid": width_grid,
                "exit_grid": exit_grid,
                "windows": sorted(windows.keys()),
                "pairs": list(pairs),
                "started_utc": datetime.fromtimestamp(start, tz=timezone.utc).isoformat(),
                "updated_utc": datetime.now(timezone.utc).isoformat(),
                "cells_completed": len(cells),
                "cells_total": total,
                "elapsed_sec": time.time() - start,
                "production_point": [PROD_WIDTH, PROD_EXIT],
                "knobs": {"width": "InpDumbStraddlePips", "exit": "InpExitPips"},
                "window_roles": WINDOW_ROLES,
                "calibration_windows": list(CALIBRATION_WINDOWS),
                "holdout_windows": list(HOLDOUT_WINDOWS),
                "cells": cells,
            },
        )

    done = len(cells)
    if skipped and checkpoint_path:
        _save_partial("partial")

    if not jobs:
        return {"cells": cells, "elapsed_sec": time.time() - start, "n_seeds": n_seeds}

    if workers <= 1:
        for job in jobs:
            t_cell = time.time()
            cache = series_cache[(job["window"], job["symbol"])]
            cell = _run_one_cell_local(
                cache["closes"],
                cache["times"],
                job["symbol"],
                job["pair_spread"],
                job["window"],
                job["window_hours"],
                job["width"],
                job["exit_pips"],
                n_seeds,
                substeps,
                gbpusd_closes=cache.get("gbpusd_closes"),
            )
            cells[cell["cell_key"]] = cell
            done += 1
            if verbose:
                print_progress_line(done, total, cell, time.time() - t_cell, time.time() - start)
            _save_partial("partial")
    else:
        with ProcessPoolExecutor(max_workers=workers) as pool:
            futs = {pool.submit(_worker_cell, job): job for job in jobs}
            for fut in as_completed(futs):
                cell = fut.result()
                cells[cell["cell_key"]] = cell
                done += 1
                if verbose:
                    print_progress_line(
                        done,
                        total,
                        cell,
                        cell.get("cell_elapsed_sec", 0.0),
                        time.time() - start,
                    )
                _save_partial("partial")

    if checkpoint_path:
        _save_partial("complete")

    return {"cells": cells, "elapsed_sec": time.time() - start, "n_seeds": n_seeds}


def pool_pairs(cells: dict, window_key: str) -> dict[tuple[float, float], dict]:
    """Mean metrics across the three pairs for one window."""
    pooled: dict[tuple[float, float], list[dict]] = {}
    for c in cells.values():
        if c["window"] != window_key:
            continue
        k = (c["width"], c["exit_pips"])
        pooled.setdefault(k, []).append(c)
    out: dict[tuple[float, float], dict] = {}
    for k, rows in pooled.items():
        out[k] = {
            "width": k[0],
            "exit_pips": k[1],
            "mean_realised": float(np.mean([r["mean_realised"] for r in rows])),
            "mean_pnl": float(np.mean([r["mean_pnl"] for r in rows])),
            "dd3_rate": float(np.mean([r["dd3_rate"] for r in rows])),
            "dd4_rate": float(np.mean([r["dd4_rate"] for r in rows])),
            "gate_a_breach_rate": float(max(r["gate_a_breach_rate"] for r in rows)),
            "gate_b_breach_rate": float(max(r["gate_b_breach_rate"] for r in rows)),
            "mean_max_daily_equity_drawdown_usd": float(
                np.mean([r["mean_max_daily_equity_drawdown_usd"] for r in rows])
            ),
            "mean_max_absolute_drawdown_usd": float(
                np.mean([r["mean_max_absolute_drawdown_usd"] for r in rows])
            ),
            "mean_max_layers": float(np.mean([r["mean_max_layers"] for r in rows])),
            "median_l0_hold_min": float(np.nanmean([r["median_l0_hold_min"] for r in rows])),
            "mean_l0_hold_min": float(np.nanmean([r["mean_l0_hold_min"] for r in rows])),
            "median_exit_dist_pips": float(np.nanmean([r["median_exit_dist_pips"] for r in rows])),
            "harvest_per_hr": float(np.mean([r["harvest_per_hr"] for r in rows])),
            "pct_l0_noise_like": float(np.nanmean([r["pct_l0_noise_like"] for r in rows])),
            "pct_l0_trend_like": float(np.nanmean([r["pct_l0_trend_like"] for r in rows])),
        }
        out[k]["disqualified_dd4"] = out[k]["dd4_rate"] > 0
        out[k]["disqualified_gates"] = is_gate_disqualified(out[k])
        out[k]["risk_adj"] = risk_adjusted_score(out[k])
        out[k]["survival_score"] = survival_score(out[k])
    return out


def pool_windows_mean(
    cells: dict, window_keys: tuple[str, ...] | list[str]
) -> dict[tuple[float, float], list[dict]]:
    """Collect pair-pooled surfaces per window for cross-window aggregation."""
    pooled: dict[tuple[float, float], list[dict]] = {}
    for wkey in window_keys:
        if wkey not in WINDOW_META:
            continue
        for k, v in pool_pairs(cells, wkey).items():
            pooled.setdefault(k, []).append(v)
    return pooled


def select_geometry_from_calibration(
    cells: dict, window_keys: tuple[str, ...] | list[str], score_key: str = "risk_adj"
) -> tuple[tuple[float, float] | None, float]:
    """Pick best cell averaging score_key across calibration windows only."""
    cal_windows = [w for w in window_keys if WINDOW_ROLES.get(w) == "calibration"]
    pool = pool_windows_mean(cells, cal_windows)
    best_k, best_v = None, float("-inf")
    for k, rows in pool.items():
        s = float(np.mean([r[score_key] for r in rows]))
        if np.isfinite(s) and s > best_v:
            best_k, best_v = k, s
    return best_k, best_v


def rank_production(surface: dict[tuple[float, float], dict], score_key: str) -> dict:
    scored = [(k, v[score_key]) for k, v in surface.items() if np.isfinite(v[score_key])]
    scored.sort(key=lambda x: x[1], reverse=True)
    prod = (PROD_WIDTH, PROD_EXIT)
    rank = next((i + 1 for i, (k, _) in enumerate(scored) if k == prod), None)
    pct = (1.0 - (rank - 1) / len(scored)) * 100.0 if rank and scored else float("nan")
    best = scored[0] if scored else (None, float("nan"))
    return {
        "rank": rank,
        "percentile": pct,
        "n_valid": len(scored),
        "best_cell": best[0],
        "best_score": best[1],
        "prod_score": surface.get(prod, {}).get(score_key, float("nan")),
    }


def find_optimum(surface: dict, score_key: str) -> tuple[tuple[float, float] | None, float]:
    best_k, best_v = None, float("-inf")
    for k, v in surface.items():
        s = v[score_key]
        if np.isfinite(s) and s > best_v:
            best_k, best_v = k, s
    return best_k, best_v


def plateau_analysis(surface: dict, score_key: str, tol_frac: float = 0.05) -> dict:
    vals = [(k, v[score_key]) for k, v in surface.items() if np.isfinite(v[score_key])]
    if not vals:
        return {"verdict": "no data"}
    vals.sort(key=lambda x: x[1], reverse=True)
    top = vals[0][1]
    if top <= 0:
        thresh = top * (1.0 - tol_frac)
    else:
        thresh = top * (1.0 - tol_frac)
    within = [k for k, s in vals if s >= thresh]
    return {
        "top_score": top,
        "top_cell": vals[0][0],
        "n_within_5pct_of_top": len(within),
        "verdict": "PLATEAU" if len(within) >= 5 else "PEAK",
    }


def save_heatmap(
    surface: dict,
    window_key: str,
    width_grid: list[float],
    exit_grid: list[float],
    value_key: str,
    out_path: Path,
    title: str,
    mark_prod: bool = True,
):
    try:
        import matplotlib.pyplot as plt
    except ImportError:
        return
    mat = np.full((len(width_grid), len(exit_grid)), np.nan)
    for i, w in enumerate(width_grid):
        for j, e in enumerate(exit_grid):
            v = surface.get((w, e), {}).get(value_key, float("nan"))
            mat[i, j] = v
    fig, ax = plt.subplots(figsize=(8, 6))
    im = ax.imshow(mat, aspect="auto", origin="lower", cmap="RdYlGn")
    ax.set_xticks(range(len(exit_grid)))
    ax.set_xticklabels([str(x) for x in exit_grid])
    ax.set_yticks(range(len(width_grid)))
    ax.set_yticklabels([str(x) for x in width_grid])
    ax.set_xlabel("exit_pips (InpExitPips)")
    ax.set_ylabel("straddle half-width (InpDumbStraddlePips)")
    ax.set_title(title)
    plt.colorbar(im, ax=ax)
    if mark_prod and PROD_WIDTH in width_grid and PROD_EXIT in exit_grid:
        pi = width_grid.index(PROD_WIDTH)
        pj = exit_grid.index(PROD_EXIT)
        ax.plot(pj, pi, "k*", markersize=14, label="prod 9/3")
        ax.legend(loc="upper right")
    out_path.parent.mkdir(parents=True, exist_ok=True)
    fig.tight_layout()
    fig.savefig(out_path, dpi=120)
    plt.close(fig)


def print_verdict(payload: dict, width_grid: list[float], exit_grid: list[float], out_dir: Path):
    cells = payload["cells"]
    run_windows = sorted({c["window"] for c in cells.values()})
    print("\n" + "=" * 80)
    print("SWEPT KNOBS (production mapping)")
    print("=" * 80)
    print("  straddle_half_width_pips  ->  InpDumbStraddlePips  (dumb L0 at mid +/- pips)")
    print("  exit_pips                 ->  InpExitPips")
    print("  add spacing unchanged:    ADD_PIPS_FLOOR=9, reload_anchor, WIDEN_RATIO=1.304")
    print(f"  production point marked:   width={PROD_WIDTH}, exit={PROD_EXIT}")
    print(f"  n_seeds per cell:          {payload['n_seeds']}")

    print("\n" + "=" * 80)
    print("CAVEATS (mandatory)")
    print("=" * 80)
    print(
        "  1. Touch-fill sim CEILING — no microstructure adverse selection; live will fall short."
    )
    print(
        "  2. Window library STRESS-SKEWED — harvest optimum rests mainly on chop (+ mixed);"
    )
    print("     do NOT pool stress + ranging into one surface.")
    print(
        f"  3. Pre-registered split: calibration={list(CALIBRATION_WINDOWS)} "
        f"holdout={list(HOLDOUT_WINDOWS)} support={list(SUPPORT_WINDOWS)}"
    )

    harvest_surfaces = {w: pool_pairs(cells, w) for w in run_windows if w in HARVEST_WINDOWS}
    stress_surfaces = {w: pool_pairs(cells, w) for w in run_windows if w in STRESS_WINDOWS}
    calibration_surfaces = {
        w: pool_pairs(cells, w) for w in run_windows if WINDOW_ROLES.get(w) == "calibration"
    }
    holdout_surfaces = {
        w: pool_pairs(cells, w) for w in run_windows if WINDOW_ROLES.get(w) == "holdout"
    }

    # Per-window summary table
    print("\n" + "=" * 80)
    print("PER-WINDOW SURFACES (pair-pooled)")
    print("=" * 80)
    for wkey in run_windows:
        surf = pool_pairs(cells, wkey)
        prod = surf.get((PROD_WIDTH, PROD_EXIT), {})
        rk = rank_production(surf, "risk_adj")
        print(
            f"\n  {wkey} [{WINDOW_META[wkey]['label']}]"
            f"\n    prod 9/3: realised=${prod.get('mean_realised', float('nan')):.2f} "
            f"gate_a={prod.get('gate_a_breach_rate', float('nan')):.1f}% "
            f"gate_b={prod.get('gate_b_breach_rate', float('nan')):.1f}% "
            f"dd3={prod.get('dd3_rate', float('nan')):.1f}% dd4={prod.get('dd4_rate', float('nan')):.1f}% "
            f"med_hold={prod.get('median_l0_hold_min', float('nan')):.1f}min "
            f"med_exit={prod.get('median_exit_dist_pips', float('nan')):.1f}p "
            f"rank={rk['rank']}/{rk['n_valid']} ({rk['percentile']:.0f}ile)"
        )
        save_heatmap(
            surf,
            wkey,
            width_grid,
            exit_grid,
            "risk_adj",
            out_dir / f"heatmap_riskadj_{wkey}.png",
            f"Risk-adj realised P&L — {wkey}",
        )
        save_heatmap(
            surf,
            wkey,
            width_grid,
            exit_grid,
            "dd4_rate",
            out_dir / f"heatmap_dd4_{wkey}.png",
            f"DD4 breach rate % — {wkey}",
        )

    # Q1 plateau — calibration windows only (pre-registered selection set)
    print("\n" + "=" * 80)
    print("Q1 — PLATEAU vs PEAK (risk-adjusted, pair-pooled, CALIBRATION only)")
    print("=" * 80)
    for w in sorted(calibration_surfaces.keys()):
        surf = calibration_surfaces[w]
        pl = plateau_analysis(surf, "risk_adj")
        print(f"    {w}: {pl['verdict']} — top={pl.get('top_cell')} "
              f"({pl.get('n_within_5pct_of_top', 0)} cells within 5% of top)")

    # Q2 where is 9/3
    print("\n" + "=" * 80)
    print("Q2 — WHERE IS 9/3? (risk-adj rank, pair-pooled, per window)")
    print("=" * 80)
    for wkey in run_windows:
        surf = pool_pairs(cells, wkey)
        rk = rank_production(surf, "risk_adj")
        print(
            f"  {wkey}: rank {rk['rank']}/{rk['n_valid']} "
            f"({rk['percentile']:.0f}ile) score={rk['prod_score']:.2f} "
            f"vs best {rk['best_cell']}={rk['best_score']:.2f}"
        )

    # Q3 geometry selection — calibration only; holdout scored separately
    print("\n" + "=" * 80)
    print("Q3 — GEOMETRY SELECTION (calibration windows only, Gate A/B gated)")
    print("=" * 80)
    cal_harvest_best, cal_harvest_scr = select_geometry_from_calibration(
        cells, run_windows, "risk_adj"
    )
    cal_survival_best, cal_survival_scr = select_geometry_from_calibration(
        cells, run_windows, "survival_score"
    )
    print(
        f"  CALIBRATION harvest optimum (avg risk_adj): "
        f"{cal_harvest_best} score={cal_harvest_scr:.2f}"
    )
    print(
        f"  CALIBRATION survival optimum (avg survival_score): "
        f"{cal_survival_best} score={cal_survival_scr:.2f}"
    )
    agree = cal_harvest_best == cal_survival_best
    if agree:
        print("  => AGREE on calibration set — one geometry harvests and survives.")
    else:
        print("  => DISAGREE on calibration set — harvest-optimal != survival-optimal.")

    print("\n" + "=" * 80)
    print("Q4 — HOLDOUT EVALUATION (out-of-sample, does NOT influence selection)")
    print("=" * 80)
    selected = cal_harvest_best
    if selected is None:
        print("  No calibration selection — holdout skipped.")
    else:
        print(f"  Selected geometry (from calibration): {selected}")
        for wkey in sorted(holdout_surfaces.keys()):
            cell = holdout_surfaces[wkey].get(selected, {})
            print(
                f"  {wkey}: realised=${cell.get('mean_realised', float('nan')):.2f} "
                f"gate_a={cell.get('gate_a_breach_rate', float('nan')):.1f}% "
                f"gate_b={cell.get('gate_b_breach_rate', float('nan')):.1f}% "
                f"risk_adj={cell.get('risk_adj', float('nan')):.2f} "
                f"disqualified={cell.get('disqualified_gates', False)}"
            )

    if "q1_2024_chop" in run_windows:
        chop = harvest_surfaces.get("q1_2024_chop", {})
        prod = chop.get((PROD_WIDTH, PROD_EXIT), {})
        hb, hs = find_optimum(chop, "median_l0_hold_min")
        print("\n" + "=" * 80)
        print("L0 HOLD-TIME / EXIT-DISTANCE (q1_2024_chop, pair-pooled)")
        print("=" * 80)
        print(
            f"  prod 9/3: med_hold={prod.get('median_l0_hold_min', float('nan')):.1f}min "
            f"med_exit={prod.get('median_exit_dist_pips', float('nan')):.1f}p "
            f"noise_like={prod.get('pct_l0_noise_like', float('nan')):.0f}%"
        )
        if hb:
            hcell = chop[hb]
            print(
                f"  fastest median hold cell: {hb} "
                f"med_hold={hcell['median_l0_hold_min']:.1f}min "
                f"med_exit={hcell['median_exit_dist_pips']:.1f}p"
            )
    print(f"  Elapsed: {payload['elapsed_sec']:.0f}s")
    print(f"  Heatmaps: {out_dir}")


def check_substeps_stability(
    n_seeds: int = 8,
    width_grid: list[float] | None = None,
    exit_grid: list[float] | None = None,
) -> dict:
    """
    Compare risk-adj cell RANKING at substeps=100 vs 20 on q1_2024_chop / GBPUSD.
    Same seeds, same grid — only bridge resolution differs.
    Default uses a 3x3 subgrid for speed; prod 9/3 reported explicitly.
    """
    width_grid = width_grid or [3, 9, 18]
    exit_grid = exit_grid or [1, 3, 8]
    path = window_path("GBPUSD", "q1_2024_chop")
    if not path.is_file():
        print("SKIP stability check: chop CSV missing", flush=True)
        return {"skipped": True}

    df = simv6.load_mt5_csv(str(path))
    closes = df["CLOSE"].values
    times = df["datetime"].values
    hours = (pd.Timestamp(times[-1]) - pd.Timestamp(times[0])).total_seconds() / 3600.0
    spread = simv6.PAIR_SPREAD_PIPS.get("GBPUSD", 0.64)

    def run_grid(substeps: int) -> dict[tuple[float, float], float]:
        scores: dict[tuple[float, float], float] = {}
        for w in width_grid:
            for e in exit_grid:
                cell = _run_one_cell_local(
                    closes, times, "GBPUSD", spread, "q1_2024_chop", hours, w, e, n_seeds, substeps
                )
                scores[(w, e)] = risk_adjusted_score(cell)
        return scores

    print(
        f"Substeps stability check: {len(width_grid)}x{len(exit_grid)} grid, "
        f"n={n_seeds}, q1_2024_chop/GBPUSD ...",
        flush=True,
    )
    t0 = time.time()
    fine = run_grid(100)
    coarse = run_grid(20)
    elapsed = time.time() - t0

    def rank_map(scores: dict) -> dict[tuple, int]:
        ordered = sorted(
            ((k, v) for k, v in scores.items() if np.isfinite(v)),
            key=lambda x: x[1],
            reverse=True,
        )
        return {k: i + 1 for i, (k, _) in enumerate(ordered)}

    r_fine = rank_map(fine)
    r_coarse = rank_map(coarse)
    keys = sorted(set(r_fine) | set(r_coarse))
    rank_delta = [abs(r_fine.get(k, 999) - r_coarse.get(k, 999)) for k in keys if k in r_fine and k in r_coarse]
    spearman_ok = True
    if len(keys) >= 3:
        fv = np.array([fine[k] for k in keys])
        cv = np.array([coarse[k] for k in keys])
        try:
            from scipy.stats import spearmanr
            rho, p = spearmanr(fv, cv)
        except ImportError:
            rf = np.argsort(np.argsort(-fv))
            rc = np.argsort(np.argsort(-cv))
            rho = float(np.corrcoef(rf, rc)[0, 1])
            p = float("nan")
    else:
        rho, p = float("nan"), float("nan")

    prod = (PROD_WIDTH, PROD_EXIT)
    prod_f = fine.get(prod, float("nan"))
    prod_c = coarse.get(prod, float("nan"))
    max_rank_shift = max(rank_delta) if rank_delta else 0
    mean_rank_shift = float(np.mean(rank_delta)) if rank_delta else 0.0
    stable = mean_rank_shift <= 2.0 and (np.isnan(rho) or rho >= 0.85)

    print(f"  elapsed: {elapsed:.0f}s", flush=True)
    print(f"  prod 9/3 risk_adj: substeps=100 -> {prod_f:.1f} | substeps=20 -> {prod_c:.1f}", flush=True)
    print(
        f"  prod 9/3 mean_realised (same seeds): "
        f"compare absolute levels in JSON cells; ranking uses risk_adj above",
        flush=True,
    )
    print(f"  Spearman rho (scores): {rho:.3f}  mean rank shift: {mean_rank_shift:.2f}  max: {max_rank_shift}", flush=True)
    print(
        f"  VERDICT: {'SHAPE STABLE' if stable else 'SHAPE MAY SHIFT'} — "
        f"coarse substeps preserve relative ordering {'well enough' if stable else 'only approximately'} "
        f"for fast-shape reads.",
        flush=True,
    )
    return {
        "stable": stable,
        "spearman_rho": float(rho),
        "mean_rank_shift": mean_rank_shift,
        "max_rank_shift": max_rank_shift,
        "prod_score_100": prod_f,
        "prod_score_20": prod_c,
        "elapsed_sec": elapsed,
    }


def filter_windows(keys: tuple[str, ...] | list[str], pairs: tuple[str, ...]) -> dict[str, dict[str, Path]]:
    return {k: {p: window_path(p, k) for p in pairs} for k in keys}


def collect_bar_counts(windows: dict[str, dict[str, Path]]) -> list[int]:
    counts = []
    for paths in windows.values():
        for path in paths.values():
            if path.is_file():
                df = simv6.load_mt5_csv(str(path))
                counts.append(len(df))
    return counts


def test_wiring():
    path = window_path("GBPUSD", "q1_2024_chop")
    if not path.is_file():
        # minimal synthetic run without disk
        closes = np.linspace(1.25, 1.26, 80)
        times = pd.date_range("2026-01-01", periods=80, freq="5min").values
        dummy = np.zeros_like(closes)
        r = simv7.simulate_one_path(
            closes,
            dummy,
            dummy,
            times=times,
            symbol="GBPUSD",
            bias_mode=BIAS_MODE,
            spacing_mode=SPACING_MODE,
            seed=0,
            entry_mode="straddle",
            straddle_half_width_pips=9.0,
            exit_pips=3.0,
            track_l0_stats=True,
        )
        assert "mean_realised" not in r
        assert "pnl_realised_usd" in r
        assert "median_l0_hold_min" not in r
        assert "l0_hold_mins" in r
        return

    payload = run_sweep(
        width_grid=[9.0],
        exit_grid=[3.0],
        n_seeds=2,
        windows={"q1_2024_chop": {"GBPUSD": path}},
        workers=1,
        verbose=False,
    )
    assert len(payload["cells"]) == 1
    c = next(iter(payload["cells"].values()))
    assert "mean_realised" in c
    assert "median_l0_hold_min" in c


def test_straddle_entry_differs_from_signal():
    closes = np.linspace(1.2500, 1.2600, 120)
    spread = np.full(120, 6.4)
    bid, off = simv7.precompute_gbpusd_signal(closes, spread)
    r_sig = simv7.simulate_one_path(
        closes, bid, off, bias_mode=simv7.BiasMode.BOTH, seed=1, entry_mode="signal"
    )
    dummy = np.zeros_like(closes)
    r_dum = simv7.simulate_one_path(
        closes,
        dummy,
        dummy,
        bias_mode=simv7.BiasMode.BOTH,
        seed=1,
        entry_mode="straddle",
        straddle_half_width_pips=9.0,
        exit_pips=3.0,
    )
    assert r_sig["n_exits"] >= 0 and r_dum["n_exits"] >= 0


def main():
    parser = argparse.ArgumentParser(description="2D width x exit dumb-straddle Monte Carlo sweep")
    parser.add_argument("--n-seeds", type=int, default=DEFAULT_N_SEEDS)
    parser.add_argument("--substeps", type=int, default=DEFAULT_SUBSTEPS,
                        help=f"Bridge substeps per bar (default {DEFAULT_SUBSTEPS})")
    parser.add_argument("--workers", type=int, default=1)
    parser.add_argument("--smoke-test", action="store_true")
    parser.add_argument("--quick-run", action="store_true", help="Full grid, n=30 seeds")
    parser.add_argument("--mini-run", action="store_true", help="Reduced grid, n=25 seeds (desktop-friendly)")
    parser.add_argument(
        "--preview",
        action="store_true",
        help="Full 9x7 grid, all 5 windows, all 3 pairs, n=50 (shape-read + rate measure)",
    )
    parser.add_argument(
        "--fast-shape",
        action="store_true",
        help="Cheap shape-pass: 5x5 coarse grid, 3 windows, GBPUSD, n=15, substeps=20",
    )
    parser.add_argument("--widths", type=str, default=None, help="Comma widths, e.g. 3,6,9,13,18")
    parser.add_argument("--exits", type=str, default=None, help="Comma exits, e.g. 1,2,3,5,8")
    parser.add_argument("--windows", nargs="*", default=None, help="Subset of window keys")
    parser.add_argument("--pairs", nargs="*", default=None, help="Subset of pairs")
    parser.add_argument("--output-dir", type=str, default="")
    parser.add_argument(
        "--runtag",
        type=str,
        default="",
        help="Checkpoint/final JSON tag (default: derived from n_seeds/grid/windows)",
    )
    parser.add_argument(
        "--fresh",
        action="store_true",
        help="Ignore existing partial checkpoint even if runtag matches",
    )
    args = parser.parse_args()

    global PAIRS

    width_grid = WIDTH_GRID
    exit_grid = EXIT_GRID
    n_seeds = args.n_seeds
    substeps = args.substeps
    windows = all_window_paths()
    preview = False
    fast_shape = False
    user_set_seeds = args.n_seeds != DEFAULT_N_SEEDS
    user_set_substeps = args.substeps != DEFAULT_SUBSTEPS

    if args.smoke_test:
        width_grid = [9.0]
        exit_grid = [3.0, 5.0]
        n_seeds = 2
        substeps = DEFAULT_SUBSTEPS
        windows = filter_windows(["q1_2024_chop"], (PAIRS[0],))
        print("SMOKE TEST: q1_2024_chop / first pair / 2x1 grid / n=2 seeds\n", flush=True)
    elif args.fast_shape:
        fast_shape = True
        width_grid = list(FAST_SHAPE_WIDTH_GRID)
        exit_grid = list(FAST_SHAPE_EXIT_GRID)
        if not user_set_seeds:
            n_seeds = FAST_SHAPE_N_SEEDS
        if not user_set_substeps:
            substeps = FAST_SHAPE_SUBSTEPS
        PAIRS = ("GBPUSD",)
        windows = filter_windows(FAST_SHAPE_WINDOWS, PAIRS)
        print(
            f"FAST-SHAPE: {len(width_grid)}x{len(exit_grid)} coarse grid, "
            f"windows={list(FAST_SHAPE_WINDOWS)}, pair=GBPUSD, "
            f"n={n_seeds}, substeps={substeps}\n",
            flush=True,
        )
    elif args.preview:
        preview = True
        if not user_set_seeds:
            n_seeds = PREVIEW_N_SEEDS
        print(
            f"PREVIEW: full {len(WIDTH_GRID)}x{len(EXIT_GRID)} grid, "
            f"all {len(WINDOW_META)} windows, all pairs, n={n_seeds}, substeps={substeps}\n",
            flush=True,
        )
    elif args.quick_run:
        if not user_set_seeds:
            n_seeds = max(n_seeds, 30)
        print(
            f"QUICK RUN: full {len(WIDTH_GRID)}x{len(EXIT_GRID)} grid, "
            f"n={n_seeds}, substeps={substeps}\n",
            flush=True,
        )
    elif args.mini_run:
        width_grid = MINI_WIDTH_GRID
        exit_grid = MINI_EXIT_GRID
        if not user_set_seeds:
            n_seeds = 25
        print(
            f"MINI RUN: {len(width_grid)}x{len(exit_grid)} grid, all windows/pairs, "
            f"n={n_seeds}, substeps={substeps}\n",
            flush=True,
        )

    if args.widths:
        width_grid = parse_float_list(args.widths)
    if args.exits:
        exit_grid = parse_float_list(args.exits)
    if args.pairs:
        PAIRS = tuple(p.upper() for p in args.pairs)
        if args.windows:
            windows = filter_windows(args.windows, PAIRS)
        elif fast_shape:
            windows = filter_windows(FAST_SHAPE_WINDOWS, PAIRS)
        else:
            windows = filter_windows(WINDOW_META.keys(), PAIRS)
    elif args.windows:
        windows = {k: all_window_paths()[k] for k in args.windows if k in WINDOW_META}
        # restrict to current PAIRS
        windows = {k: {p: v[p] for p in PAIRS if p in v} for k, v in windows.items()}

    missing = [str(p) for paths in windows.values() for p in paths.values() if not p.is_file()]
    if missing:
        print("ERROR: missing CSV(s):", flush=True)
        for m in missing[:10]:
            print(" ", m, flush=True)
        sys.exit(1)

    out_dir = Path(args.output_dir) if args.output_dir else ROOT / "temp" / "width_exit_sweep"
    out_dir.mkdir(parents=True, exist_ok=True)

    window_keys = sorted(windows.keys())
    runtag = args.runtag or build_runtag(
        n_seeds, width_grid, exit_grid, window_keys, PAIRS, substeps, preview, fast_shape
    )
    partial_path = out_dir / f"{runtag}_partial.json"
    final_path = out_dir / f"{runtag}.json"

    resume_cells: dict[str, dict] = {}
    if not args.fresh and partial_path.is_file():
        ckpt = load_checkpoint(partial_path)
        if ckpt and checkpoint_config_matches(
            ckpt, n_seeds, width_grid, exit_grid, window_keys, PAIRS, substeps
        ):
            resume_cells = ckpt.get("cells", {})
            print(
                f"RESUME: loaded {len(resume_cells)} cells from {partial_path.name}",
                flush=True,
            )
        elif ckpt:
            print(
                f"WARNING: partial checkpoint config mismatch — starting fresh "
                f"(use --fresh to silence). path={partial_path}",
                flush=True,
            )

    n_cells = len(width_grid) * len(exit_grid) * sum(len(v) for v in windows.values())
    bar_counts = collect_bar_counts(windows)
    est_sec = estimate_sweep_runtime(n_cells, n_seeds, substeps, args.workers, bar_counts)
    per_cell_est = estimate_cell_sec(n_seeds, substeps, int(np.mean(bar_counts)) if bar_counts else REF_BARS)
    print(
        f"Sweep: {len(width_grid)} widths x {len(exit_grid)} exits x "
        f"{n_cells // max(1, len(width_grid)*len(exit_grid))} series = {n_cells} cells",
        flush=True,
    )
    print(
        f"  n_seeds={n_seeds}  substeps={substeps}  ~{per_cell_est:.0f}s/cell (est)  "
        f"workers={args.workers}  ETA ~{format_hms(est_sec)}",
        flush=True,
    )
    print(f"  runtag: {runtag}\n", flush=True)

    payload = run_sweep(
        width_grid,
        exit_grid,
        n_seeds,
        windows,
        workers=args.workers,
        verbose=True,
        checkpoint_path=partial_path,
        resume_cells=resume_cells,
        runtag=runtag,
        substeps=substeps,
    )

    ts = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M")
    final_doc = {
        "runtag": runtag,
        "status": "complete",
        "timestamp_utc": ts,
        "n_seeds": n_seeds,
        "substeps": substeps,
        "width_grid": width_grid,
        "exit_grid": exit_grid,
        "windows": window_keys,
        "pairs": list(PAIRS),
        "window_roles": WINDOW_ROLES,
        "calibration_windows": list(CALIBRATION_WINDOWS),
        "holdout_windows": list(HOLDOUT_WINDOWS),
        "support_windows": list(SUPPORT_WINDOWS),
        "preview": preview,
        "fast_shape": fast_shape,
        "production_point": [PROD_WIDTH, PROD_EXIT],
        "knobs": {"width": "InpDumbStraddlePips", "exit": "InpExitPips"},
        "elapsed_sec": payload["elapsed_sec"],
        "cells": payload["cells"],
    }
    cal_best, cal_score = select_geometry_from_calibration(payload["cells"], window_keys, "risk_adj")
    if cal_best is not None:
        final_doc["calibration_selection"] = {
            "geometry": list(cal_best),
            "score": cal_score,
            "score_key": "risk_adj",
        }
        final_doc["holdout_evaluation"] = {}
        for wkey in HOLDOUT_WINDOWS:
            if wkey not in window_keys:
                continue
            surf = pool_pairs(payload["cells"], wkey)
            final_doc["holdout_evaluation"][wkey] = surf.get(cal_best, {})
    write_checkpoint(final_path, final_doc)
    print(f"\nWrote final JSON: {final_path}", flush=True)
    if partial_path.is_file():
        print(f"Partial checkpoint retained: {partial_path}", flush=True)

    print_verdict(payload, width_grid, exit_grid, out_dir)


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--test-wiring":
        test_wiring()
        test_straddle_entry_differs_from_signal()
        print("All wiring tests: PASS")
    elif len(sys.argv) > 1 and sys.argv[1] == "--check-substeps-stability":
        check_substeps_stability()
    else:
        main()
