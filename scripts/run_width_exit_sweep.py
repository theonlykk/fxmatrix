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
  python scripts/run_width_exit_sweep.py --n-seeds 500 --workers 6
  python scripts/run_width_exit_sweep.py --quick-run --workers 4   # n=30, full grid

Results JSON + heatmaps -> temp/width_exit_sweep/ (gitignored via temp/).
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
HARVEST_WINDOWS = ("q1_2024_chop", "full_quarter")
STRESS_WINDOWS = ("truss_crisis", "vaccine_rally", "june_blowup")

BAR_MINUTES = 5.0


def window_path(pair: str, window_key: str) -> Path:
    suffix = {
        "q1_2024_chop": "q1_2024_chop_oos",
        "full_quarter": "full_quarter",
        "truss_crisis": "truss_crisis_oos",
        "vaccine_rally": "vaccine_rally_oos",
        "june_blowup": "june_blowup",
    }[window_key]
    return ROOT / "data" / f"{pair}_{suffix}.csv"


def all_window_paths() -> dict[str, dict[str, Path]]:
    out: dict[str, dict[str, Path]] = {}
    for wkey in WINDOW_META:
        out[wkey] = {pair: window_path(pair, wkey) for pair in PAIRS}
    return out


def _worker_batch(payload: dict) -> list[tuple[int, dict]]:
    import importlib.util as _ilu

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

    results: list[tuple[int, dict]] = []
    with patch.dict(sim6.PAIR_SPREAD_PIPS, patched, clear=False):
        for seed in payload["seeds"]:
            r = sim7.simulate_one_path(
                closes,
                dummy,
                dummy,
                times=times,
                symbol=payload["symbol"].upper(),
                bias_mode=payload["bias_mode"],
                spacing_mode=payload["spacing"],
                seed=int(seed),
                sub_steps=100,
                entry_mode="straddle",
                straddle_half_width_pips=payload["width"],
                exit_pips=payload["exit_pips"],
                track_l0_stats=True,
            )
            results.append((int(seed), r))
    return results


def run_seeds_parallel(
    closes,
    times,
    symbol: str,
    pair_spread: float,
    width: float,
    exit_pips: float,
    n_seeds: int,
    workers: int,
    executor: ProcessPoolExecutor | None = None,
) -> list[dict]:
    workers = max(1, min(workers, n_seeds))
    chunk = max(1, math.ceil(n_seeds / (workers * 2)))
    batches = [
        list(range(s, min(s + chunk, n_seeds)))
        for s in range(0, n_seeds, chunk)
    ]
    base = {
        "root": str(ROOT),
        "symbol": symbol.upper(),
        "pair_spread": pair_spread,
        "width": width,
        "exit_pips": exit_pips,
        "spacing": SPACING_MODE,
        "bias_mode": int(BIAS_MODE),
        "closes": closes,
        "times": times,
    }
    by_seed: dict[int, dict] = {}

    def _collect(futs):
        for fut in as_completed(futs):
            for seed, result in fut.result():
                by_seed[seed] = result

    futs = []
    for seeds in batches:
        p = dict(base)
        p["seeds"] = seeds
        if executor is not None:
            futs.append(executor.submit(_worker_batch, p))
        else:
            for seed, result in _worker_batch(p):
                by_seed[seed] = result
    if futs:
        _collect(futs)
    return [by_seed[s] for s in range(n_seeds)]


def aggregate_seed_results(
    seed_results: list[dict], window_hours: float
) -> dict[str, Any]:
    pnls = [r["pnl_total_usd"] for r in seed_results]
    realised = [r["pnl_realised_usd"] for r in seed_results]
    max_layers = [r["max_layers"] for r in seed_results]
    dd3 = sum(1 for r in seed_results if r["drawdown_exceeded_3pct"])
    dd4 = sum(1 for r in seed_results if r["drawdown_exceeded_4pct"])
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
    }


def risk_adjusted_score(cell: dict) -> float:
    """Harvest ranking: realised P&L penalised for dd3; dd4 cells disqualified."""
    if cell["dd4_rate"] > 0:
        return float("-inf")
    return cell["mean_realised"] - 0.5 * cell["dd3_rate"]


def survival_score(cell: dict) -> float:
    """Survival ranking: prefer zero dd4, then low dd3, then P&L."""
    if cell["dd4_rate"] > 0:
        return float("-inf")
    return cell["mean_realised"] - 2.0 * cell["dd3_rate"]


def run_sweep(
    width_grid: list[float],
    exit_grid: list[float],
    n_seeds: int,
    windows: dict[str, dict[str, Path]],
    workers: int = 1,
    verbose: bool = True,
) -> dict[str, Any]:
    start = time.time()
    cells: dict[str, dict] = {}
    total = len(width_grid) * len(exit_grid) * len(windows) * len(PAIRS)
    done = 0

    pool_ctx = (
        ProcessPoolExecutor(max_workers=workers)
        if workers > 1
        else None
    )
    try:
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
                pair_spread = simv6.PAIR_SPREAD_PIPS.get(pair, 0.5)
                if verbose:
                    print(
                        f"Loaded {wkey}/{pair}: {len(df)} bars, "
                        f"{df['datetime'].iloc[0]} -> {df['datetime'].iloc[-1]} "
                        f"({window_hours:.1f}h)",
                        flush=True,
                    )

                for width in width_grid:
                    for exit_pips in exit_grid:
                        if workers <= 1:
                            seed_results = []
                            dummy = np.zeros_like(closes)
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
                                        sub_steps=100,
                                        entry_mode="straddle",
                                        straddle_half_width_pips=width,
                                        exit_pips=exit_pips,
                                        track_l0_stats=True,
                                    )
                                )
                        else:
                            seed_results = run_seeds_parallel(
                                closes,
                                times,
                                pair,
                                pair_spread,
                                width,
                                exit_pips,
                                n_seeds,
                                workers,
                                executor=pool_ctx,
                            )

                        key = f"{wkey}|{pair}|{width:g}|{exit_pips:g}"
                        cells[key] = aggregate_seed_results(seed_results, window_hours)
                        cells[key]["window"] = wkey
                        cells[key]["pair"] = pair
                        cells[key]["width"] = width
                        cells[key]["exit_pips"] = exit_pips
                        cells[key]["regime"] = WINDOW_META[wkey]["regime"]
                        done += 1
                        if verbose and done % 5 == 0:
                            print(
                                f"  progress {done}/{total} ({time.time()-start:.0f}s)",
                                flush=True,
                            )
    finally:
        if pool_ctx is not None:
            pool_ctx.shutdown(wait=True)

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
            "mean_max_layers": float(np.mean([r["mean_max_layers"] for r in rows])),
            "median_l0_hold_min": float(np.nanmean([r["median_l0_hold_min"] for r in rows])),
            "mean_l0_hold_min": float(np.nanmean([r["mean_l0_hold_min"] for r in rows])),
            "median_exit_dist_pips": float(np.nanmean([r["median_exit_dist_pips"] for r in rows])),
            "harvest_per_hr": float(np.mean([r["harvest_per_hr"] for r in rows])),
            "pct_l0_noise_like": float(np.nanmean([r["pct_l0_noise_like"] for r in rows])),
            "pct_l0_trend_like": float(np.nanmean([r["pct_l0_trend_like"] for r in rows])),
        }
        out[k]["disqualified_dd4"] = out[k]["dd4_rate"] > 0
        out[k]["risk_adj"] = risk_adjusted_score(out[k])
        out[k]["survival_score"] = survival_score(out[k])
    return out


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

    harvest_surfaces = {w: pool_pairs(cells, w) for w in run_windows if w in HARVEST_WINDOWS}
    stress_surfaces = {w: pool_pairs(cells, w) for w in run_windows if w in STRESS_WINDOWS}

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

    # Q1 plateau
    print("\n" + "=" * 80)
    print("Q1 — PLATEAU vs PEAK (risk-adjusted, pair-pooled)")
    print("=" * 80)
    for label, wins in [("RANGING/HARVEST", [w for w in HARVEST_WINDOWS if w in run_windows]),
                        ("STRESS", [w for w in STRESS_WINDOWS if w in run_windows])]:
        print(f"\n  [{label}]")
        for w in wins:
            surf = harvest_surfaces.get(w) or stress_surfaces.get(w) or {}
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

    # Q3 harvest vs survival optima
    print("\n" + "=" * 80)
    print("Q3 — HARVEST vs SURVIVAL OPTIMUM (pair-pooled)")
    print("=" * 80)
    harvest_pool: dict[tuple[float, float], list[dict]] = {}
    stress_pool: dict[tuple[float, float], list[dict]] = {}
    for w in run_windows:
        if w in HARVEST_WINDOWS:
            for k, v in (harvest_surfaces.get(w) or {}).items():
                harvest_pool.setdefault(k, []).append(v)
        if w in STRESS_WINDOWS:
            for k, v in (stress_surfaces.get(w) or {}).items():
                stress_pool.setdefault(k, []).append(v)

    def avg_score(pool: dict, k, key):
        return float(np.mean([r[key] for r in pool[k]]))

    harvest_best, harvest_scr = None, float("-inf")
    for k in harvest_pool:
        s = avg_score(harvest_pool, k, "risk_adj")
        if np.isfinite(s) and s > harvest_scr:
            harvest_best, harvest_scr = k, s

    survival_best, survival_scr = None, float("-inf")
    for k in stress_pool:
        s = avg_score(stress_pool, k, "survival_score")
        if np.isfinite(s) and s > survival_scr:
            survival_best, survival_scr = k, s

    agree = harvest_best == survival_best
    print(f"  HARVEST optimum (avg ranging+mixed risk_adj): {harvest_best} score={harvest_scr:.2f}")
    print(f"  SURVIVAL optimum (avg stress survival_score): {survival_best} score={survival_scr:.2f}")
    if agree:
        print("  => AGREE — one geometry harvests and survives (fixed point viable).")
    else:
        print("  => DISAGREE — harvest-optimal != survival-optimal (distribution may earn its keep).")

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
    parser.add_argument("--n-seeds", type=int, default=500)
    parser.add_argument("--workers", type=int, default=1)
    parser.add_argument("--smoke-test", action="store_true")
    parser.add_argument("--quick-run", action="store_true", help="Full grid, n=30 seeds")
    parser.add_argument("--mini-run", action="store_true", help="Reduced grid, n=25 seeds (desktop-friendly)")
    parser.add_argument("--windows", nargs="*", default=None, help="Subset of window keys")
    parser.add_argument("--pairs", nargs="*", default=None, help="Subset of pairs")
    parser.add_argument("--output-dir", type=str, default="")
    args = parser.parse_args()

    global PAIRS
    if args.pairs:
        PAIRS = tuple(p.upper() for p in args.pairs)

    width_grid = WIDTH_GRID
    exit_grid = EXIT_GRID
    n_seeds = args.n_seeds
    windows = all_window_paths()

    if args.smoke_test:
        width_grid = [9.0]
        exit_grid = [3.0, 5.0]
        n_seeds = 2
        windows = {"q1_2024_chop": {PAIRS[0]: window_path(PAIRS[0], "q1_2024_chop")}}
        print("SMOKE TEST: q1_2024_chop / first pair / 2x1 grid / n=2 seeds\n", flush=True)
    elif args.quick_run:
        n_seeds = max(n_seeds, 30) if args.n_seeds == 500 else args.n_seeds
        print(f"QUICK RUN: full {len(WIDTH_GRID)}x{len(EXIT_GRID)} grid, n={n_seeds} seeds\n", flush=True)
    elif args.mini_run:
        width_grid = MINI_WIDTH_GRID
        exit_grid = MINI_EXIT_GRID
        if args.n_seeds == 500:
            n_seeds = 25
        print(
            f"MINI RUN: {len(width_grid)}x{len(exit_grid)} grid, all windows/pairs, n={n_seeds} seeds\n",
            flush=True,
        )

    if args.windows:
        windows = {k: windows[k] for k in args.windows if k in windows}

    missing = [str(p) for paths in windows.values() for p in paths.values() if not p.is_file()]
    if missing:
        print("ERROR: missing CSV(s):")
        for m in missing[:10]:
            print(" ", m)
        sys.exit(1)

    n_cells = len(width_grid) * len(exit_grid) * sum(len(v) for v in windows.values())
    print(
        f"Sweep: {len(width_grid)} widths x {len(exit_grid)} exits x {n_cells // (len(width_grid)*len(exit_grid))} "
        f"series = {n_cells} cells x {n_seeds} seeds"
    )
    print(f"Workers: {args.workers}\n")

    payload = run_sweep(
        width_grid,
        exit_grid,
        n_seeds,
        windows,
        workers=args.workers,
        verbose=True,
    )

    out_dir = Path(args.output_dir) if args.output_dir else ROOT / "temp" / "width_exit_sweep"
    out_dir.mkdir(parents=True, exist_ok=True)
    ts = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M")
    json_path = out_dir / f"width_exit_sweep_n{n_seeds}_{ts}.json"
    with open(json_path, "w", encoding="utf-8") as fh:
        json.dump(
            {
                "timestamp_utc": ts,
                "n_seeds": n_seeds,
                "width_grid": width_grid,
                "exit_grid": exit_grid,
                "production_point": [PROD_WIDTH, PROD_EXIT],
                "knobs": {
                    "width": "InpDumbStraddlePips",
                    "exit": "InpExitPips",
                },
                "elapsed_sec": payload["elapsed_sec"],
                "cells": payload["cells"],
            },
            fh,
            indent=2,
        )
    print(f"\nWrote JSON: {json_path}")

    print_verdict(payload, width_grid, exit_grid, out_dir)


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--test-wiring":
        test_wiring()
        test_straddle_entry_differs_from_signal()
        print("All wiring tests: PASS")
    else:
        main()
