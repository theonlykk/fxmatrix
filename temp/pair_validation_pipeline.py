#!/usr/bin/env python3
"""
Reusable pair-validation pipeline (temp/ analysis only — no production changes).

Stages: slot classification, data check, native sigma, spread calibration,
geometry sweep (actual grid, volatility-scaled), Monte Carlo n=500,
passivity headroom, gap-slippage stress, live-tick reference check, final report.
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
from dataclasses import asdict, dataclass, field
from pathlib import Path
from typing import Any
from unittest.mock import patch

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "scripts"
TEMP = ROOT / "temp"
DATA = ROOT / "data"

# --- load v7 / v6 sim modules (same pattern as run_v7_n500_validation.py) ---
spec7 = importlib.util.spec_from_file_location("simv7", SCRIPTS / "grid_sim_v7_real_signal.py")
simv7 = importlib.util.module_from_spec(spec7)
spec7.loader.exec_module(simv7)
spec6 = importlib.util.spec_from_file_location("simv6", SCRIPTS / "grid_sim_v6_dynamic_spacing.py")
simv6 = importlib.util.module_from_spec(spec6)
spec6.loader.exec_module(simv6)
sys.modules["grid_sim_v6_dynamic_spacing"] = simv6

spec_eurgbp = importlib.util.spec_from_file_location(
    "eurgbp_val", TEMP / "eurgbp_v7_validation_analysis.py"
)
eurgbp_val = importlib.util.module_from_spec(spec_eurgbp)
spec_eurgbp.loader.exec_module(eurgbp_val)

PIP = 0.0001
POINT = PIP

WINDOWS = {
    "full_quarter": "full_quarter",
    "june_blowup": "june_blowup",
    "truss_crisis": "truss_crisis_oos",
    "vaccine_rally": "vaccine_rally_oos",
    "q1_2024_chop": "q1_2024_chop_oos",
}

# ADR-091 published n=500 reference (reload_anchor unless noted) for GBPUSD sanity check.
# Section 5 "Mean P&L" is total P&L (mean_pnl), not realised-only. Omitted fields = no ADR ref.
ADR091_REF = {
    ("full_quarter", "reload_anchor", "MM_LONG"): {
        "mean_pnl": 179.70, "dd3_count": 0, "dd4_count": 0, "max_max_layers": 7
    },
    ("full_quarter", "reload_anchor", "MM_SHORT"): {
        "mean_pnl": 31.23, "dd3_count": 0, "dd4_count": 0, "max_max_layers": 7
    },
    ("full_quarter", "reload_anchor", "MM_BOTH"): {
        "mean_pnl": 285.05, "dd3_count": 0, "dd4_count": 0, "max_max_layers": 7
    },
    ("june_blowup", "reload_anchor", "MM_SHORT"): {
        "mean_pnl": -3.0, "dd3_count": 0, "dd4_count": 0, "note": "~small loss post bug-fix"
    },
    ("truss_crisis", "reload_anchor", "MM_LONG"): {
        "dd3_count": 5, "dd3_rate": 1.0, "dd4_count": 0, "max_max_layers": 9
    },
}

ADR091_MEAN_PNL_TOLERANCE = 25.0

PRODUCTION_CONSTANTS = {
    "GBPUSD": {
        "WIDEN_RATIO": 1.304,
        "ADD_PIPS_FLOOR": 9.0,
        "EXIT_PIPS": 3.0,
        "ADD_PIPS_CEILING": 1000.0,
        "PAIR_SPREAD_PIPS": 0.64,
    },
    "EURUSD": {
        "WIDEN_RATIO": 1.304,
        "ADD_PIPS_FLOOR": 9.0,
        "EXIT_PIPS": 3.0,
        "ADD_PIPS_CEILING": 1000.0,
        "PAIR_SPREAD_PIPS": 0.18,
    },
    "EURGBP": {
        "WIDEN_RATIO": 1.304,
        "ADD_PIPS_FLOOR": 9.0,
        "EXIT_PIPS": 3.0,
        "ADD_PIPS_CEILING": 1000.0,
        "PAIR_SPREAD_PIPS": 0.63,
    },
}

# MT5 5-day verify baselines (Python instrumented reference targets)
MT5_VERIFY_5DAY = {
    "MM_LONG": {"l0": 13, "add": 11, "reload": 20, "exits": 41, "max_layers": 3},
    "MM_SHORT": {"l0": 24, "add": 11, "reload": 13, "exits": 48, "max_layers": 4},
}

BIAS_MODES = [
    ("MM_LONG", simv7.BiasMode.LONG_ONLY),
    ("MM_SHORT", simv7.BiasMode.SHORT_ONLY),
    ("MM_BOTH", simv7.BiasMode.BOTH),
]
SPACING_MODES = ["reload_anchor", "reload_flat"]


@dataclass
class Geometry:
    widen_ratio: float
    add_pips_floor: float
    exit_pips: float
    add_pips_ceiling: float = 1000.0

    def as_dict(self) -> dict:
        return asdict(self)


@dataclass
class PipelineReport:
    pair: str
    slot: dict
    data: dict
    sigma: dict
    spread: dict
    geometry_sweep: dict
    derived_geometry: Geometry
    production_geometry: Geometry
    mc_geometry: Geometry
    monte_carlo: dict
    passivity: dict
    gap_stress: dict
    live_tick: dict
    verdict: dict
    elapsed_sec: float = 0.0
    meta: dict = field(default_factory=dict)


def classify_slot(symbol: str) -> dict:
    """BC-slot = direct USD leg; AB-slot = cross needing two USD legs."""
    sym = symbol.upper()
    if len(sym) != 6:
        raise ValueError(f"unsupported symbol: {symbol}")
    base, quote = sym[:3], sym[3:]
    if quote == "USD":
        return {
            "slot": "BC",
            "symbol": sym,
            "signal_fn": "V2_ComputeBcBid/Offer",
            "legs": [sym],
            "digits": 5,
            "pip_points": 10,
        }
    if base == "USD":
        return {
            "slot": "BC",
            "symbol": sym,
            "signal_fn": "V2_ComputeBcBid/Offer",
            "legs": [sym],
            "digits": 5,
            "pip_points": 10,
            "note": "USD-base treated as BC native",
        }
    # Cross — AB slot with synthetic leg names (EURGBP -> EURUSD + GBPUSD)
    leg_ac = f"{base}USD"
    leg_bc = f"{quote}USD"
    return {
        "slot": "AB",
        "symbol": sym,
        "signal_fn": "V2_ComputeAbBid/Offer",
        "legs": [leg_ac, leg_bc],
        "digits": 5,
        "pip_points": 10,
    }


def window_csv(pair: str, window_key: str) -> Path:
    suffix = WINDOWS[window_key]
    return DATA / f"{pair.upper()}_{suffix}.csv"


def check_data(pair: str) -> dict:
    slot = classify_slot(pair)
    out: dict[str, Any] = {"windows": {}, "missing": [], "leg_files": {}}
    for wkey in WINDOWS:
        p = window_csv(pair, wkey)
        if p.exists() and p.stat().st_size > 500:
            df = simv6.load_mt5_csv(str(p))
            out["windows"][wkey] = {
                "path": str(p),
                "bars": len(df),
                "from": str(df["datetime"].iloc[0]),
                "to": str(df["datetime"].iloc[-1]),
                "mean_spread_pts": float(df["SPREAD"].mean()),
                "mean_spread_pips": float(df["SPREAD"].mean() / 10.0),
            }
        else:
            out["missing"].append({"window": wkey, "path": str(p)})
    if slot["slot"] == "AB":
        for leg in slot["legs"]:
            for wkey in WINDOWS:
                lp = window_csv(leg.replace("USD", "") if leg.endswith("USD") else leg, wkey)
                # legs are EURUSD/GBPUSD — use direct path
                lp = DATA / f"{leg}_{WINDOWS[wkey]}.csv"
                out["leg_files"].setdefault(leg, {})[wkey] = {
                    "path": str(lp),
                    "exists": lp.exists() and lp.stat().st_size > 500,
                }
    out["all_primary_present"] = len(out["missing"]) == 0
    return out


def sigma_fv_stats(closes: np.ndarray, label: str) -> dict:
    return eurgbp_val.sigma_fv_stats(closes.astype(float), label)


def calibrate_spread(df, symbol: str, slot: dict) -> dict:
    spread_pts = df["SPREAD"].astype(float)
    spread_pips = spread_pts / float(slot["pip_points"])
    prod = PRODUCTION_CONSTANTS.get(symbol.upper(), {})
    stored = simv6.PAIR_SPREAD_PIPS.get(symbol.upper(), prod.get("PAIR_SPREAD_PIPS"))
    mean_pips = float(spread_pips.mean())
    median_pips = float(spread_pips.median())
    p90_pips = float(np.percentile(spread_pips, 90))
    recommended = round(mean_pips, 2)
    return {
        "symbol": symbol.upper(),
        "digits": slot["digits"],
        "pip_points": slot["pip_points"],
        "mean_spread_pips": mean_pips,
        "median_spread_pips": median_pips,
        "p90_spread_pips": p90_pips,
        "stored_pair_spread_pips": stored,
        "recommended_pair_spread_pips": recommended,
        "delta_vs_stored": None if stored is None else round(mean_pips - stored, 3),
        "half_spread_price": float(mean_pips / 2.0 * PIP),
    }


@contextmanager
def geometry_patch(geo: Geometry, pair_spread_pips: float, symbol: str):
    old = (simv7.WIDEN_RATIO, simv7.ADD_PIPS_FLOOR, simv7.EXIT_PIPS, simv7.ADD_PIPS_CEILING)
    simv7.WIDEN_RATIO = geo.widen_ratio
    simv7.ADD_PIPS_FLOOR = geo.add_pips_floor
    simv7.EXIT_PIPS = geo.exit_pips
    simv7.ADD_PIPS_CEILING = geo.add_pips_ceiling
    patched = dict(simv6.PAIR_SPREAD_PIPS)
    patched[symbol.upper()] = pair_spread_pips
    with patch.dict(simv6.PAIR_SPREAD_PIPS, patched, clear=False):
        yield
    simv7.WIDEN_RATIO, simv7.ADD_PIPS_FLOOR, simv7.EXIT_PIPS, simv7.ADD_PIPS_CEILING = old


def merge_ab_window(primary_df, slot: dict, window_key: str):
    """Inner-join AB legs (AC, BC) with primary cross pair on datetime — same as verify_v2_six_instance_parity."""
    leg_ac, leg_bc = slot["legs"]
    df_ac = simv6.load_mt5_csv(str(window_csv(leg_ac, window_key)))
    df_bc = simv6.load_mt5_csv(str(window_csv(leg_bc, window_key)))
    return df_ac.merge(df_bc, on="datetime", suffixes=("_ac", "_bc")).merge(primary_df, on="datetime")


def fv_sigma(closes, i: int) -> tuple[float, float]:
    c6, c12, c48 = closes[i - 6], closes[i - 12], closes[i - 48]
    fv = 0.5 * c6 + 0.3 * c12 + 0.2 * c48
    m = (c6 + c12 + c48) / 3.0
    sig = float(((c6 - m) ** 2 + (c12 - m) ** 2 + (c48 - m) ** 2) / 3.0) ** 0.5
    return fv, sig


def ab_bid_offer(eu_cl, gu_cl, eu_sp, gu_sp, i: int, qs: float, sm: float, point: float = 0.0001):
    """AB-slot bid/offer — r_ac − r_bc in log space; DHS from max leg sigma (verify script parity)."""
    fv_ac, sig_ac = fv_sigma(eu_cl, i)
    fv_bc, sig_bc = fv_sigma(gu_cl, i)
    ac_now = eu_cl[i] + (eu_sp[i] / 10.0 / 2.0) * point
    bc_now = gu_cl[i] + (gu_sp[i] / 10.0 / 2.0) * point
    r_ac = math.log(ac_now / fv_ac)
    r_bc = math.log(bc_now / fv_bc)
    inst = r_ac - r_bc
    dhs = qs + max(sig_ac, sig_bc) * sm
    ratio = fv_ac / fv_bc
    bid = ratio * math.exp(inst - dhs)
    offer = ratio * math.exp(inst + dhs)
    return bid, offer


def window_signal_arrays(symbol: str, window_key: str, primary_df) -> tuple[np.ndarray, ...]:
    """Return aligned closes, spread_pts, times, bid_arr, offer_arr for BC or AB slots."""
    slot = classify_slot(symbol)
    if slot["slot"] == "BC":
        closes = primary_df["CLOSE"].values.astype(float)
        spread_pts = primary_df["SPREAD"].values.astype(float)
        times = primary_df["datetime"].values
        bid_arr, offer_arr = simv7.precompute_gbpusd_signal(closes, spread_pts, POINT)
        return closes, spread_pts, times, bid_arr, offer_arr

    merged = merge_ab_window(primary_df, slot, window_key)
    closes = merged["CLOSE"].values.astype(float)
    spread_pts = merged["SPREAD"].values.astype(float)
    times = merged["datetime"].values
    ac_cl = merged["CLOSE_ac"].values.astype(float)
    bc_cl = merged["CLOSE_bc"].values.astype(float)
    ac_sp = merged["SPREAD_ac"].values.astype(float)
    bc_sp = merged["SPREAD_bc"].values.astype(float)
    n = len(merged)
    bid_arr = np.full(n, np.nan)
    offer_arr = np.full(n, np.nan)
    for i in range(48, n):
        b, o = ab_bid_offer(
            ac_cl, bc_cl, ac_sp, bc_sp, i, simv7.QUOTE_SPREAD, simv7.SPREAD_MULTIPLIER, POINT,
        )
        bid_arr[i] = b
        offer_arr[i] = o
    return closes, spread_pts, times, bid_arr, offer_arr


def precompute_signal(closes, spread_pts, slot: dict, window_key: str | None = None, primary_df=None):
    if slot["slot"] == "BC":
        return simv7.precompute_gbpusd_signal(closes, spread_pts, POINT)
    if primary_df is None or window_key is None:
        raise ValueError("AB slot requires primary_df and window_key")
    _, _, _, bid_arr, offer_arr = window_signal_arrays(slot["symbol"], window_key, primary_df)
    return bid_arr, offer_arr


def _worker_simulate_batch(payload: dict) -> list[dict]:
    """Process-pool worker: run a batch of seeds with fixed geometry (Windows spawn-safe)."""
    import importlib.util
    from unittest.mock import patch

    root = Path(payload["root"])
    spec7 = importlib.util.spec_from_file_location("simv7", root / "scripts" / "grid_sim_v7_real_signal.py")
    sim7 = importlib.util.module_from_spec(spec7)
    spec7.loader.exec_module(sim7)
    spec6 = importlib.util.spec_from_file_location("simv6", root / "scripts" / "grid_sim_v6_dynamic_spacing.py")
    sim6 = importlib.util.module_from_spec(spec6)
    spec6.loader.exec_module(sim6)
    import sys
    sys.modules["grid_sim_v6_dynamic_spacing"] = sim6

    geo = payload["geo"]
    sim7.WIDEN_RATIO = geo["widen_ratio"]
    sim7.ADD_PIPS_FLOOR = geo["add_pips_floor"]
    sim7.EXIT_PIPS = geo["exit_pips"]
    sim7.ADD_PIPS_CEILING = geo.get("add_pips_ceiling", 1000.0)
    patched = dict(sim6.PAIR_SPREAD_PIPS)
    patched[payload["symbol"].upper()] = payload["pair_spread"]

    closes = np.asarray(payload["closes"], dtype=float)
    bid = np.asarray(payload["bid"], dtype=float)
    offer = np.asarray(payload["offer"], dtype=float)
    times = np.asarray(payload["times"])
    out = []
    with patch.dict(sim6.PAIR_SPREAD_PIPS, patched, clear=False):
        for seed in payload["seeds"]:
            r = sim7.simulate_one_path(
                closes, bid, offer, times=times, symbol=payload["symbol"].upper(),
                bias_mode=payload["bias_mode"], spacing_mode=payload["spacing"],
                seed=int(seed), sub_steps=100,
            )
            out.append(r)
    return out


def parallel_seed_runs(
    closes, bid, offer, times, symbol, pair_spread, geo: Geometry,
    n_seeds: int, spacing: str, mode, workers: int = 6,
) -> list[dict]:
    workers = max(1, min(workers, n_seeds))
    chunk = max(1, math.ceil(n_seeds / (workers * 2)))
    batches = []
    for start in range(0, n_seeds, chunk):
        batches.append(list(range(start, min(n_seeds, start + chunk))))
    payload_base = {
        "root": str(ROOT),
        "symbol": symbol.upper(),
        "pair_spread": pair_spread,
        "geo": geo.as_dict(),
        "closes": closes,
        "bid": bid,
        "offer": offer,
        "times": times,
        "spacing": spacing,
        "bias_mode": int(mode),
    }
    results: list[dict] = []
    with ProcessPoolExecutor(max_workers=workers) as pool:
        futs = []
        for seeds in batches:
            p = dict(payload_base)
            p["seeds"] = seeds
            futs.append(pool.submit(_worker_simulate_batch, p))
        for fut in as_completed(futs):
            results.extend(fut.result())
    return results


def aggregate_run(primary_df, window_key, symbol, pair_spread, geo, n_seeds,
                  spacing="reload_anchor", mode=simv7.BiasMode.BOTH, workers: int = 6) -> dict:
    """Run n_seeds; return risk-adjusted aggregate score inputs."""
    closes, spread_pts, times, bid_arr, offer_arr = window_signal_arrays(symbol, window_key, primary_df)
    runs = parallel_seed_runs(
        closes, bid_arr, offer_arr, times, symbol, pair_spread, geo,
        n_seeds, spacing, mode, workers=workers,
    )
    dd3 = sum(int(r["drawdown_exceeded_3pct"]) for r in runs)
    dd4 = sum(int(r["drawdown_exceeded_4pct"]) for r in runs)
    realised = [r["pnl_realised_usd"] for r in runs]
    max_layers = [r["max_layers"] for r in runs]
    return {
        "mean_realised": float(np.mean(realised)),
        "dd3_count": dd3,
        "dd4_count": dd4,
        "max_max_layers": int(np.max(max_layers)) if max_layers else 0,
        "n_seeds": n_seeds,
    }


def score_geometry(agg: dict, geo: Geometry | None = None, vol_ratio: float = 1.0) -> float:
    """Higher is better. DD4 hard-fail; penalize depth, DD3, and drift from vol-scaled anchor."""
    if agg["dd4_count"] > 0:
        return -1e9 + agg["dd4_count"]
    score = agg["mean_realised"]
    score -= agg["dd3_count"] * 500.0
    if agg["max_max_layers"] > 9:
        score -= (agg["max_max_layers"] - 9) * 200.0
    if geo is not None:
        anchor_w = 1.304  # ADR-091 reference; weak vol scaling optional later
        anchor_f = 9.0 * vol_ratio
        anchor_e = 3.0 * max(0.85, min(1.15, vol_ratio ** 0.5))
        score -= abs(geo.widen_ratio - anchor_w) * 25.0
        score -= abs(geo.add_pips_floor - anchor_f) * 12.0
        score -= abs(geo.exit_pips - anchor_e) * 8.0
    return score


def build_geometry_grid(reference_sigma_pips: float, gbp_reference_pips: float = None) -> dict[str, list[float]]:
    """Return separate sweep axes (volatility-scaled), not full Cartesian grid upfront."""
    gbp_reference_pips = gbp_reference_pips or reference_sigma_pips
    vol_ratio = reference_sigma_pips / gbp_reference_pips if gbp_reference_pips > 0 else 1.0
    base_floor = 9.0 * vol_ratio
    base_exit = 3.0 * max(0.85, min(1.15, vol_ratio ** 0.5))
    return {
        "widen_ratio": [1.15, 1.20, 1.25, 1.304, 1.35, 1.40, 1.50],
        "add_pips_floor": sorted({round(x, 1) for x in [base_floor * m for m in (0.88, 0.94, 1.0, 1.06, 1.12)]}),
        "exit_pips": sorted({round(x, 1) for x in [base_exit * m for m in (0.85, 1.0, 1.15)]}),
        "vol_ratio": vol_ratio,
        "base_floor": round(base_floor, 2),
        "base_exit": round(base_exit, 2),
    }


def _run_combo(primary_df, window_key, pair, pair_spread, widen, floor, exit_p, n_seeds, workers=6) -> dict:
    geo = Geometry(widen, floor, exit_p)
    return aggregate_run(primary_df, window_key, pair, pair_spread, geo, n_seeds, workers=workers)


def geometry_sweep(pair: str, df_fq, df_jb, pair_spread: float, ref_sigma_pips: float,
                     gbp_sigma_pips: float, n_seeds: int = 30, top_k: int = 5,
                     workers: int = 6) -> dict:
    axes = build_geometry_grid(ref_sigma_pips, gbp_sigma_pips)
    base_floor = axes["base_floor"]
    base_exit = axes["base_exit"]

    # Phase A: sweep WIDEN_RATIO with vol-scaled base floor/exit
    print(f"  Phase A: WIDEN_RATIO sweep ({len(axes['widen_ratio'])} values, n={n_seeds})...", flush=True)
    vol_ratio = axes["vol_ratio"]
    phase_a = []
    t0 = time.time()
    for w in axes["widen_ratio"]:
        geo = Geometry(w, base_floor, base_exit)
        fq = _run_combo(df_fq, "full_quarter", pair, pair_spread, w, base_floor, base_exit, n_seeds, workers)
        jb = _run_combo(df_jb, "june_blowup", pair, pair_spread, w, base_floor, base_exit, n_seeds, workers)
        comb = {
            "dd3_count": fq["dd3_count"] + jb["dd3_count"],
            "dd4_count": fq["dd4_count"] + jb["dd4_count"],
            "mean_realised": (fq["mean_realised"] + jb["mean_realised"]) / 2.0,
            "max_max_layers": max(fq["max_max_layers"], jb["max_max_layers"]),
        }
        phase_a.append({
            "geometry": geo.as_dict(),
            "score": score_geometry(comb, geo, vol_ratio),
            "full_quarter": fq,
            "june_blowup": jb,
            "combined": comb,
        })
    phase_a.sort(key=lambda x: x["score"], reverse=True)
    best_w = phase_a[0]["geometry"]["widen_ratio"]
    print(f"    best WIDEN_RATIO={best_w} ({time.time()-t0:.0f}s)", flush=True)

    # Phase B: sweep floor × exit at best widen (both windows for scoring)
    print(f"  Phase B: ADD_PIPS_FLOOR × EXIT_PIPS at W={best_w}...", flush=True)
    phase_b = []
    t1 = time.time()
    for f in axes["add_pips_floor"]:
        for e in axes["exit_pips"]:
            fq = _run_combo(df_fq, "full_quarter", pair, pair_spread, best_w, f, e, n_seeds, workers)
            jb = _run_combo(df_jb, "june_blowup", pair, pair_spread, best_w, f, e, n_seeds, workers)
            geo = Geometry(best_w, f, e)
            comb = {
                "dd3_count": fq["dd3_count"] + jb["dd3_count"],
                "dd4_count": fq["dd4_count"] + jb["dd4_count"],
                "mean_realised": (fq["mean_realised"] + jb["mean_realised"]) / 2.0,
                "max_max_layers": max(fq["max_max_layers"], jb["max_max_layers"]),
            }
            phase_b.append({
                "geometry": geo.as_dict(),
                "score": score_geometry(comb, geo, vol_ratio),
                "full_quarter": fq,
                "june_blowup": jb,
                "combined": comb,
            })
    phase_b.sort(key=lambda x: x["score"], reverse=True)
    print(f"    Phase B done ({time.time()-t1:.0f}s)", flush=True)

    prod = PRODUCTION_CONSTANTS[pair.upper()]
    prod_geo = Geometry(prod["WIDEN_RATIO"], prod["ADD_PIPS_FLOOR"], prod["EXIT_PIPS"], prod["ADD_PIPS_CEILING"])
    prod_fq = _run_combo(df_fq, "full_quarter", pair, pair_spread, prod_geo.widen_ratio,
                         prod_geo.add_pips_floor, prod_geo.exit_pips, n_seeds, workers)
    prod_jb = _run_combo(df_jb, "june_blowup", pair, pair_spread, prod_geo.widen_ratio,
                         prod_geo.add_pips_floor, prod_geo.exit_pips, n_seeds, workers)
    prod_comb = {
        "dd3_count": prod_fq["dd3_count"] + prod_jb["dd3_count"],
        "dd4_count": prod_fq["dd4_count"] + prod_jb["dd4_count"],
        "mean_realised": (prod_fq["mean_realised"] + prod_jb["mean_realised"]) / 2.0,
        "max_max_layers": max(prod_fq["max_max_layers"], prod_jb["max_max_layers"]),
    }
    prod_score = score_geometry(prod_comb, prod_geo, vol_ratio)
    best = phase_b[0] if phase_b else phase_a[0]
    # Prefer production geometry when within sweep noise (avoids n=10 exit_pips overfit)
    if abs(prod_score - best["score"]) <= max(15.0, 0.05 * abs(best["score"])):
        best = {
            "geometry": prod_geo.as_dict(),
            "score": prod_score,
            "full_quarter": prod_fq,
            "june_blowup": prod_jb,
            "combined": prod_comb,
            "selected": "production_within_sweep_margin",
        }
    return {
        "axes": axes,
        "n_seeds_per_combo": n_seeds,
        "phase_a_top3": phase_a[:3],
        "phase_b_top5": phase_b[:top_k],
        "production_scored": {
            "geometry": prod_geo.as_dict(),
            "full_quarter": prod_fq,
            "june_blowup": prod_jb,
            "score": prod_score,
        },
        "best": best,
    }


def summarize_mc_by_window(results: dict) -> dict:
    """Roll up MC cells by window (all spacing × bias modes)."""
    by_window: dict[str, dict] = {}
    for wkey in WINDOWS:
        cells = [v for k, v in results.items() if k[1] == wkey]
        if not cells:
            continue
        realised = [c["mean_realised"] for c in cells]
        by_window[wkey] = {
            "mean_realised_avg": float(np.mean(realised)),
            "mean_realised_min": float(np.min(realised)),
            "mean_realised_max": float(np.max(realised)),
            "dd3_total": int(sum(c["dd3_count"] for c in cells)),
            "dd4_total": int(sum(c["dd4_count"] for c in cells)),
            "max_max_layers": int(max(c["max_max_layers"] for c in cells)),
            "n_cells": len(cells),
        }
    return by_window


def per_scalp_edges_all_windows(pair: str, geo: Geometry, pair_spread: float) -> dict:
    return {wkey: per_scalp_edge_check(pair, geo, pair_spread, wkey) for wkey in WINDOWS}


def geometry_key(geo: Geometry) -> tuple[float, float, float]:
    return (geo.widen_ratio, geo.add_pips_floor, geo.exit_pips)


def build_geometry_comparison(prod_mc: dict, derived_mc: dict) -> dict:
    """Side-by-side production vs sweep-derived at full n=500 scale."""
    prod_ws = prod_mc.get("window_summary", {})
    derived_ws = derived_mc.get("window_summary", {})
    prod_edges = prod_mc.get("per_scalp_by_window", {})
    derived_edges = derived_mc.get("per_scalp_by_window", {})
    windows: dict[str, dict] = {}
    pct_deltas: list[float] = []
    for wkey in WINDOWS:
        p = prod_ws.get(wkey, {})
        d = derived_ws.get(wkey, {})
        p_real = p.get("mean_realised_avg")
        d_real = d.get("mean_realised_avg")
        pct = None
        if p_real and abs(p_real) > 1e-6:
            pct = (d_real - p_real) / abs(p_real) * 100.0
            pct_deltas.append(pct)
        windows[wkey] = {
            "production": {
                "mean_realised_avg": p_real,
                "dd3_total": p.get("dd3_total"),
                "dd4_total": p.get("dd4_total"),
                "max_max_layers": p.get("max_max_layers"),
                "per_scalp_usd": prod_edges.get(wkey, {}).get("per_scalp_usd"),
                "per_scalp_exits": prod_edges.get(wkey, {}).get("exits"),
            },
            "derived": {
                "mean_realised_avg": d_real,
                "dd3_total": d.get("dd3_total"),
                "dd4_total": d.get("dd4_total"),
                "max_max_layers": d.get("max_max_layers"),
                "per_scalp_usd": derived_edges.get(wkey, {}).get("per_scalp_usd"),
                "per_scalp_exits": derived_edges.get(wkey, {}).get("exits"),
            },
            "derived_vs_production_pct": pct,
        }
    avg_pct = float(np.mean(pct_deltas)) if pct_deltas else None
    sweep_n30_pct = None  # filled by caller if available
    if avg_pct is None:
        edge_verdict = "insufficient data"
    elif avg_pct >= 15.0:
        edge_verdict = "holds_up — derived edge ≥15% at n=500 (sweep ~20-25% not a small-sample artifact)"
    elif avg_pct >= 8.0:
        edge_verdict = "partial — derived edge shrinks but remains meaningful (~8-15%) at n=500"
    elif avg_pct >= 3.0:
        edge_verdict = "marginal — derived edge largely noise at n=500 (~3-8%)"
    else:
        edge_verdict = "gone — derived edge within noise at n=500 (<3%)"
    return {
        "production_geometry": prod_mc.get("geometry"),
        "derived_geometry": derived_mc.get("geometry"),
        "n_seeds": prod_mc.get("n_seeds"),
        "windows": windows,
        "aggregate": {
            "production_mean_realised_sum": sum(
                v.get("mean_realised_avg") or 0 for v in prod_ws.values()
            ),
            "derived_mean_realised_sum": sum(
                v.get("mean_realised_avg") or 0 for v in derived_ws.values()
            ),
            "production_dd3_total": prod_mc.get("aggregate_dd3"),
            "production_dd4_total": prod_mc.get("aggregate_dd4"),
            "derived_dd3_total": derived_mc.get("aggregate_dd3"),
            "derived_dd4_total": derived_mc.get("aggregate_dd4"),
            "avg_derived_vs_production_pct": avg_pct,
        },
        "edge_verdict": edge_verdict,
    }


def print_geometry_comparison(comp: dict) -> None:
    print("\n" + "=" * 72, flush=True)
    print("GEOMETRY COMPARISON — production vs sweep-derived (n=500, all windows)", flush=True)
    pg = comp["production_geometry"]
    dg = comp["derived_geometry"]
    print(
        f"  Production: W={pg['widen_ratio']} F={pg['add_pips_floor']} E={pg['exit_pips']}",
        flush=True,
    )
    print(
        f"  Derived:    W={dg['widen_ratio']} F={dg['add_pips_floor']} E={dg['exit_pips']}",
        flush=True,
    )
    print(
        f"{'Window':<16} {'Prod $real':>10} {'Deriv $real':>11} {'Δ%':>7} "
        f"{'P-DD3':>6} {'D-DD3':>6} {'P-maxL':>7} {'D-maxL':>7} "
        f"{'P$/scalp':>9} {'D$/scalp':>9}",
        flush=True,
    )
    print("-" * 72, flush=True)
    for wkey, row in comp["windows"].items():
        p, d = row["production"], row["derived"]
        pct = row.get("derived_vs_production_pct")
        pct_s = f"{pct:+.1f}" if pct is not None else "N/A"
        print(
            f"{wkey:<16} "
            f"{(p.get('mean_realised_avg') or 0):>10.2f} "
            f"{(d.get('mean_realised_avg') or 0):>11.2f} "
            f"{pct_s:>7} "
            f"{(p.get('dd3_total') or 0):>6} "
            f"{(d.get('dd3_total') or 0):>6} "
            f"{(p.get('max_max_layers') or 0):>7} "
            f"{(d.get('max_max_layers') or 0):>7} "
            f"{(p.get('per_scalp_usd') or 0):>9.3f} "
            f"{(d.get('per_scalp_usd') or 0):>9.3f}",
            flush=True,
        )
    agg = comp["aggregate"]
    print("-" * 72, flush=True)
    print(
        f"Aggregate DD3: prod={agg['production_dd3_total']} derived={agg['derived_dd3_total']} | "
        f"DD4: prod={agg['production_dd4_total']} derived={agg['derived_dd4_total']}",
        flush=True,
    )
    avg_pct = agg.get("avg_derived_vs_production_pct")
    if avg_pct is not None:
        print(f"Avg derived vs production (mean realised, by window): {avg_pct:+.1f}%", flush=True)
    print(f"Edge verdict: {comp['edge_verdict']}", flush=True)
    print("=" * 72 + "\n", flush=True)


def run_monte_carlo(pair: str, geo: Geometry, pair_spread: float, n_seeds: int = 500,
                    workers: int = 6, label: str = "") -> dict:
    """Full 5-window × 2-spacing × 3-bias matrix at derived geometry."""
    tag = f" [{label}]" if label else ""
    print(
        f"  MC{tag}: W={geo.widen_ratio} F={geo.add_pips_floor} E={geo.exit_pips} "
        f"n={n_seeds} seeds...",
        flush=True,
    )
    windows = {}
    for wkey in WINDOWS:
        p = window_csv(pair, wkey)
        if p.exists():
            windows[wkey] = str(p)

    results = {}
    t0 = time.time()
    total_cells = len(windows) * len(SPACING_MODES) * len(BIAS_MODES)
    cell_idx = 0
    for spacing in SPACING_MODES:
        for wname, path in windows.items():
            df = simv6.load_mt5_csv(path)
            closes, spread_pts, times, bid_arr, offer_arr = window_signal_arrays(pair, wname, df)
            for mode_name, mode in BIAS_MODES:
                cell_idx += 1
                print(f"    MC cell {cell_idx}/{total_cells}: {spacing}/{wname}/{mode_name}...", flush=True)
                runs = parallel_seed_runs(
                    closes, bid_arr, offer_arr, times, pair, pair_spread, geo,
                    n_seeds, spacing, mode, workers=workers,
                )
                pnls = [r["pnl_total_usd"] for r in runs]
                realised = [r["pnl_realised_usd"] for r in runs]
                unrealised = [r["pnl_unrealised_usd"] for r in runs]
                max_layers_list = [r["max_layers"] for r in runs]
                dd3 = sum(int(r["drawdown_exceeded_3pct"]) for r in runs)
                dd4 = sum(int(r["drawdown_exceeded_4pct"]) for r in runs)
                nonflat = sum(1 for r in runs if abs(r["pnl_unrealised_usd"]) > 1e-12)
                key = (spacing, wname, mode_name)
                results[key] = {
                    "mean_pnl": float(np.mean(pnls)),
                    "mean_realised": float(np.mean(realised)),
                    "mean_unrealised": float(np.mean(unrealised)),
                    "nonflat_pct": nonflat / n_seeds * 100.0,
                    "max_max_layers": int(np.max(max_layers_list)),
                    "dd3_count": dd3,
                    "dd4_count": dd4,
                    "dd3_rate": dd3 / n_seeds * 100.0,
                    "dd4_rate": dd4 / n_seeds * 100.0,
                }
                print(
                    f"      done{tag} in {time.time()-t0:.0f}s cumulative | "
                    f"realised=${results[key]['mean_realised']:.2f} DD3={dd3} DD4={dd4}",
                    flush=True,
                )
    edge = per_scalp_edge_check(pair, geo, pair_spread, "full_quarter")
    per_scalp_all = per_scalp_edges_all_windows(pair, geo, pair_spread)
    window_summary = summarize_mc_by_window(results)
    adr_compare = compare_adr091(results, pair)
    return {
        "n_seeds": n_seeds,
        "geometry": geo.as_dict(),
        "geometry_selection": None,
        "label": label or None,
        "results": {f"{k[0]}|{k[1]}|{k[2]}": v for k, v in results.items()},
        "window_summary": window_summary,
        "per_scalp_by_window": per_scalp_all,
        "aggregate_dd4": sum(r["dd4_count"] for r in results.values()),
        "aggregate_dd3": sum(r["dd3_count"] for r in results.values()),
        "per_scalp_edge": edge,
        "adr091_comparison": adr_compare,
        "elapsed_sec": time.time() - t0,
    }


def per_scalp_edge_check(pair, geo, pair_spread, window) -> dict:
    path = window_csv(pair, window)
    df = simv6.load_mt5_csv(str(path))
    closes, spread_pts, times, bid_arr, offer_arr = window_signal_arrays(pair, window, df)
    with geometry_patch(geo, pair_spread, pair):
        r = eurgbp_val.simulate_instrumented(
            closes, bid_arr, offer_arr, times, simv7.BiasMode.BOTH, "reload_anchor", 0, pair_spread,
        )
    exits = r["exits"]
    realised = r["realised"]
    per_scalp = realised / exits if exits else 0.0
    return {
        "window": window,
        "exits": exits,
        "realised_usd": realised,
        "per_scalp_usd": per_scalp,
        "positive_per_scalp": per_scalp > 0,
        "l0": r["l0"], "add": r["add"], "reload": r["reload"], "max_layers": r["max_layers"],
    }


def geometry_close(derived: Geometry, prod: Geometry) -> bool:
    param_delta = {
        k: getattr(derived, k) - getattr(prod, k)
        for k in ("widen_ratio", "add_pips_floor", "exit_pips")
    }
    return all(
        abs(param_delta[k]) < (0.08 if k == "widen_ratio" else 0.5)
        for k in param_delta
    )


def select_geometry_for_mc(sweep: dict, derived: Geometry, prod: Geometry) -> tuple[Geometry, str]:
    """Pick MC/trusted geometry: prefer locked production when sweep says so or derived ≈ production."""
    best = sweep.get("best") or {}
    if best.get("selected") == "production_within_sweep_margin":
        return prod, "sweep_preferred_production"
    if geometry_close(derived, prod):
        return prod, "derived_within_production_margin"
    return derived, "sweep_derived"


def mc_results_from_report_payload(monte_carlo: dict) -> dict:
    """Rebuild tuple-keyed results dict from a saved report JSON monte_carlo section."""
    out = {}
    for key, val in monte_carlo.get("results", {}).items():
        spacing, wname, mode = key.split("|", 2)
        out[(spacing, wname, mode)] = val
    return out


def compare_adr091(results: dict, pair: str = "GBPUSD") -> list[dict]:
    """Compare MC cells against ADR-091 reference — GBPUSD pipeline calibration only."""
    if pair.upper() != "GBPUSD":
        return []
    rows = []
    for key, ref in ADR091_REF.items():
        wname, spacing, mode = key
        rkey = (spacing, wname, mode)
        if rkey not in results:
            continue
        got = results[rkey]
        ref_fields = {
            "mean_pnl": "mean_pnl" in ref,
            "dd3_count": "dd3_count" in ref,
            "dd4_count": "dd4_count" in ref,
        }
        row = {
            "key": "|".join(key),
            "ref": ref,
            "ref_fields": ref_fields,
            "got": {
                k: got[k]
                for k in ("mean_pnl", "mean_realised", "dd3_count", "dd4_count", "max_max_layers")
                if k in got
            },
            "delta_mean_pnl": (
                got["mean_pnl"] - ref["mean_pnl"] if ref_fields["mean_pnl"] else None
            ),
            "delta_dd3": got["dd3_count"] - ref["dd3_count"] if ref_fields["dd3_count"] else None,
            "delta_dd4": got["dd4_count"] - ref["dd4_count"] if ref_fields["dd4_count"] else None,
        }
        rows.append(row)
    return rows


def evaluate_adr091_ok(comparison_rows: list[dict], mean_pnl_tolerance: float = ADR091_MEAN_PNL_TOLERANCE) -> bool:
    """Return True when every referenced ADR-091 metric is within tolerance."""
    for row in comparison_rows:
        ref_fields = row.get("ref_fields") or {}
        if ref_fields.get("mean_pnl"):
            delta = row.get("delta_mean_pnl")
            if delta is None or abs(delta) >= mean_pnl_tolerance:
                return False
        if ref_fields.get("dd3_count"):
            if row.get("delta_dd3") not in (None, 0):
                return False
        if ref_fields.get("dd4_count"):
            if row.get("delta_dd4") not in (None, 0):
                return False
    return True


def format_adr_delta(value: float | None) -> str:
    if value is None:
        return "N/A"
    if isinstance(value, float) and value.is_integer():
        return f"{int(value):+d}" if abs(value - int(value)) < 1e-9 else f"{value:+.2f}"
    if isinstance(value, int):
        return f"{value:+d}"
    return f"{value:+.2f}"


def passivity_check(df, pair_spread: float) -> dict:
    closes = df["CLOSE"].values.astype(float)
    spread_pts = df["SPREAD"].values.astype(float)
    stats = sigma_fv_stats(closes, "passivity")
    half_market = (spread_pts / 10.0 / 2.0) * PIP
    dynamic_hs = simv7.QUOTE_SPREAD + stats["sigma_fv_mean"] * simv7.SPREAD_MULTIPLIER
    model_half = pair_spread / 2.0 * PIP
    headroom_vs_market = float(np.mean(dynamic_hs / np.maximum(half_market[48:], 1e-9)))
    headroom_vs_model = float(dynamic_hs / max(model_half, 1e-9))
    return {
        "sigma_fv_mean_pips": stats["sigma_fv_mean_pips"],
        "dynamic_hs_mean_pips": stats["dynamic_hs_mean_pips"],
        "mean_market_half_spread_pips": float(np.mean(spread_pts[48:] / 10.0 / 2.0)),
        "model_half_spread_pips": pair_spread / 2.0,
        "headroom_dynamic_vs_market_mean_ratio": headroom_vs_market,
        "headroom_dynamic_vs_model_ratio": headroom_vs_model,
        "passes_margin": headroom_vs_market > 1.0,
    }


def gap_stress(pair: str, geo: Geometry, pair_spread: float, gap_pips: float = 500.0) -> dict:
    """Gap splice on full_quarter — pair-scaled gap by sigma ratio vs GBPUSD reference."""
    df = simv6.load_mt5_csv(str(window_csv(pair, "full_quarter"))).copy()
    closes = df["CLOSE"].values.astype(float)
    gbp_df = simv6.load_mt5_csv(str(window_csv("GBPUSD", "full_quarter")))
    sig_pair = sigma_fv_stats(closes, pair)["sigma_fv_mean"]
    sig_gbp = sigma_fv_stats(gbp_df["CLOSE"].values.astype(float), "GBPUSD")["sigma_fv_mean"]
    scaled_gap = gap_pips * (sig_pair / sig_gbp if sig_gbp > 0 else 1.0)
    gap_bar = min(400, len(closes) - 5)
    df.loc[gap_bar + 1, "CLOSE"] = closes[gap_bar] - scaled_gap * PIP

    out = {}
    closes, spread_pts, times, bid_arr, offer_arr = window_signal_arrays(pair, "full_quarter", df)
    with geometry_patch(geo, pair_spread, pair):
        for mode_name, mode in [("MM_LONG", simv7.BiasMode.LONG_ONLY), ("MM_SHORT", simv7.BiasMode.SHORT_ONLY)]:
            tr = eurgbp_val.simulate_instrumented(
                closes, bid_arr, offer_arr, times, mode, "reload_flat", 0, pair_spread,
            )
            out[mode_name] = {
                "gap_pips_scaled": round(scaled_gap, 1),
                "gap_bar": gap_bar,
                "max_layers": tr["max_layers"],
                "realised_usd": tr["realised"],
                "dd3": tr["dd3"],
                "dd4": tr["dd4"],
                "exits": tr["exits"],
                "ceiling_relevant": tr["max_layers"] >= 13,
            }
    return out


def live_tick_reference(pair: str, geo: Geometry, pair_spread: float) -> dict:
    """Seed-0 instrumented 5-day slice vs documented MT5 verify baselines."""
    df = simv6.load_mt5_csv(str(window_csv(pair, "full_quarter")))
    # Approximate 5-day verify window (2026-03-09 .. 2026-03-13)
    mask = (df["datetime"] >= "2026-03-09") & (df["datetime"] < "2026-03-14")
    sub = df.loc[mask].reset_index(drop=True)
    if len(sub) < 100:
        sub = df.iloc[:500].reset_index(drop=True)
    closes, spread_pts, times, bid_arr, offer_arr = window_signal_arrays(pair, "full_quarter", sub)
    rows = {}
    with geometry_patch(geo, pair_spread, pair):
        for mode_name, mode in [("MM_LONG", simv7.BiasMode.LONG_ONLY), ("MM_SHORT", simv7.BiasMode.SHORT_ONLY)]:
            r = eurgbp_val.simulate_instrumented(
                closes, bid_arr, offer_arr, times, mode, "reload_anchor", 0, pair_spread,
            )
            ref = MT5_VERIFY_5DAY[mode_name]
            rows[mode_name] = {
                "python": {k: r[k] for k in ("l0", "add", "reload", "exits", "max_layers", "realised")},
                "mt5_reference": ref,
                "delta": {k: r[k] - ref[k] for k in ("l0", "add", "reload", "exits", "max_layers")},
                "note": "MT5 reference from v2_production_verify_bounded STAGE1/2; characterizes sim-vs-real gap",
            }
    return rows


def evaluate_pair_mc_ok(report: PipelineReport) -> tuple[bool, dict]:
    """Pair-aware MC pass criteria: GBPUSD vs ADR-091; others vs own risk/economics."""
    mc = report.monte_carlo
    pair = report.pair.upper()
    edge = mc.get("per_scalp_edge", {})
    passivity_ok = report.passivity.get("passes_margin", False)

    if mc.get("skipped"):
        if pair == "GBPUSD":
            ok = geometry_close(report.derived_geometry, report.production_geometry) and passivity_ok
        else:
            ok = passivity_ok
        return ok, {"mode": "sweep_only", "passivity_ok": passivity_ok}

    economics_ok = edge.get("positive_per_scalp", False)

    if pair == "GBPUSD":
        risk_ok = mc.get("aggregate_dd4", 999) == 0
        adr_ok = evaluate_adr091_ok(mc.get("adr091_comparison", []))
        pipeline_ok = risk_ok and adr_ok
        return pipeline_ok, {
            "mode": "gbpusd_calibration",
            "risk_ok": risk_ok,
            "adr_ok": adr_ok,
            "economics_ok": economics_ok,
            "passivity_ok": passivity_ok,
        }

    risk_ok = mc.get("aggregate_dd4", 999) == 0 and mc.get("aggregate_dd3", 999) == 0
    pipeline_ok = risk_ok and economics_ok and passivity_ok
    return pipeline_ok, {
        "mode": "pair_validation",
        "risk_ok": risk_ok,
        "adr_ok": None,
        "economics_ok": economics_ok,
        "passivity_ok": passivity_ok,
        "per_scalp_usd": edge.get("per_scalp_usd"),
    }


def go_no_go(report: PipelineReport) -> dict:
    mc = report.monte_carlo
    pair = report.pair.upper()
    derived = report.derived_geometry
    prod = report.production_geometry
    param_delta = {
        k: round(getattr(derived, k) - getattr(prod, k), 4)
        for k in ("widen_ratio", "add_pips_floor", "exit_pips")
    }
    derived_matches_production = geometry_close(derived, prod)
    pipeline_ok, criteria = evaluate_pair_mc_ok(report)
    adr_ok = criteria.get("adr_ok")
    if adr_ok is None:
        adr_ok = True

    if pair == "GBPUSD":
        recommendation = (
            "GO — pipeline reproduces known-good GBPUSD geometry and ADR-091 risk profile; "
            "safe to run EURUSD/EURGBP next."
            if pipeline_ok and derived_matches_production
            else "NO-GO — investigate pipeline divergence before running other pairs."
        )
    else:
        recommendation = (
            f"GO — {pair} selected geometry passes n=500 risk (DD3/DD4 clean), "
            f"positive per-scalp edge, and passivity headroom."
            if pipeline_ok
            else f"NO-GO — {pair} failed pair validation criteria: {criteria}."
        )

    return {
        "pipeline_trustworthy": pipeline_ok,
        "derived_matches_production": derived_matches_production,
        "mc_geometry_selection": mc.get("geometry_selection"),
        "param_delta_derived_vs_production": param_delta,
        "pass_criteria": criteria,
        "recommendation": recommendation,
        "mc_dd4_total": mc.get("aggregate_dd4"),
        "mc_dd3_total": mc.get("aggregate_dd3"),
    }


def render_markdown(report: PipelineReport) -> str:
    v = report.verdict
    lines = [
        f"# Pair validation report — {report.pair}",
        "",
        f"Elapsed: {report.elapsed_sec:.0f}s",
        "",
        "## Slot classification",
        f"- Slot: **{report.slot['slot']}** ({report.slot['signal_fn']})",
        "",
        "## Derived vs production geometry",
        "",
        "| Parameter | Production | Derived | Delta |",
        "|-----------|------------|---------|-------|",
    ]
    for k in ("widen_ratio", "add_pips_floor", "exit_pips"):
        lines.append(
            f"| {k} | {getattr(report.production_geometry, k)} | "
            f"{getattr(report.derived_geometry, k)} | "
            f"{v['param_delta_derived_vs_production'][k]:+.4f} |"
        )
    mc_geo = report.mc_geometry
    lines.extend([
        "",
        "## MC geometry (trusted for stage 6+)",
        "",
        f"- widen_ratio={mc_geo.widen_ratio} add_pips_floor={mc_geo.add_pips_floor} "
        f"exit_pips={mc_geo.exit_pips}",
        f"- selection: {v.get('mc_geometry_selection', report.monte_carlo.get('geometry_selection', 'n/a'))}",
        "",
        f"**Verdict:** {v['recommendation']}",
        "",
        f"- MC aggregate DD4: {v['mc_dd4_total']} | DD3: {v['mc_dd3_total']}",
        f"- Pipeline trustworthy: {v['pipeline_trustworthy']}",
        f"- Derived ≈ production: {v['derived_matches_production']}",
        "",
        "## ADR-091 comparison (selected cells)",
        "",
    ])
    for row in report.monte_carlo.get("adr091_comparison", []):
        parts = [f"`{row['key']}`"]
        parts.append(f"delta_mean_pnl={format_adr_delta(row.get('delta_mean_pnl'))}")
        parts.append(f"delta_dd3={format_adr_delta(row.get('delta_dd3'))}")
        parts.append(f"delta_dd4={format_adr_delta(row.get('delta_dd4'))}")
        lines.append("- " + ", ".join(parts))
    lines.append("")
    lines.append("## Per-scalp edge (full_quarter, MM_BOTH, seed 0)")
    edge = report.monte_carlo.get("per_scalp_edge", {})
    lines.append(f"- exits={edge.get('exits')} per_scalp=${edge.get('per_scalp_usd', 0):.3f} "
                 f"positive={edge.get('positive_per_scalp')}")
    comp = report.meta.get("geometry_comparison")
    if comp:
        lines.extend(["", "## Geometry comparison (production vs sweep-derived, n=500)", ""])
        lines.append(f"- Edge verdict: **{comp.get('edge_verdict')}**")
        avg = comp.get("aggregate", {}).get("avg_derived_vs_production_pct")
        if avg is not None:
            lines.append(f"- Avg derived vs production (by window): {avg:+.1f}%")
        lines.extend(["", "| Window | Prod $real | Deriv $real | Δ% | P-DD3 | D-DD3 | P-maxL | D-maxL | P$/scalp | D$/scalp |",
                      "|--------|------------|-------------|-----|-------|-------|--------|--------|----------|----------|"])
        for wkey, row in comp.get("windows", {}).items():
            p, d = row["production"], row["derived"]
            pct = row.get("derived_vs_production_pct")
            pct_s = f"{pct:+.1f}" if pct is not None else "N/A"
            lines.append(
                f"| {wkey} | {(p.get('mean_realised_avg') or 0):.2f} | {(d.get('mean_realised_avg') or 0):.2f} | "
                f"{pct_s} | {p.get('dd3_total', 0)} | {d.get('dd3_total', 0)} | "
                f"{p.get('max_max_layers', 0)} | {d.get('max_max_layers', 0)} | "
                f"{(p.get('per_scalp_usd') or 0):.3f} | {(d.get('per_scalp_usd') or 0):.3f} |"
            )
    return "\n".join(lines)


def run_pipeline(pair: str, n_sweep: int = 30, n_mc: int = 500, workers: int = 6,
                 skip_mc: bool = False, dual_geometry_mc: bool = False) -> PipelineReport:
    pair = pair.upper()
    t0 = time.time()
    print(f"\n{'='*72}\nPair validation pipeline — {pair}\n{'='*72}", flush=True)

    slot = classify_slot(pair)
    print(f"[1] Slot: {slot['slot']} ({slot['signal_fn']})", flush=True)

    data = check_data(pair)
    if not data["all_primary_present"]:
        raise FileNotFoundError(f"Missing windows: {data['missing']}")
    print(f"[2] Data: all 5 windows present", flush=True)

    df_fq = simv6.load_mt5_csv(str(window_csv(pair, "full_quarter")))
    df_jb = simv6.load_mt5_csv(str(window_csv(pair, "june_blowup")))
    sig_fq = sigma_fv_stats(df_fq["CLOSE"].values.astype(float), f"{pair} full_quarter")
    sig_jb = sigma_fv_stats(df_jb["CLOSE"].values.astype(float), f"{pair} june_blowup")
    gbp_sig = sigma_fv_stats(
        simv6.load_mt5_csv(str(window_csv("GBPUSD", "full_quarter")))["CLOSE"].values.astype(float),
        "GBPUSD full_quarter",
    )
    print(f"[3] sigma_fv mean pips: {sig_fq['sigma_fv_mean_pips']:.2f} (GBPUSD ref {gbp_sig['sigma_fv_mean_pips']:.2f})", flush=True)

    spread = calibrate_spread(df_fq, pair, slot)
    pair_spread = spread["recommended_pair_spread_pips"]
    print(f"[4] Spread: mean={spread['mean_spread_pips']:.2f} pips, recommended={pair_spread}", flush=True)

    print(f"[5] Geometry sweep (n={n_sweep})...", flush=True)
    sweep = geometry_sweep(
        pair, df_fq, df_jb, pair_spread,
        sig_fq["sigma_fv_mean_pips"], gbp_sig["sigma_fv_mean_pips"], n_seeds=n_sweep,
        workers=workers,
    )
    best = sweep["best"]
    derived = Geometry(**best["geometry"]) if best else Geometry(1.304, 9.0, 3.0)
    prod = PRODUCTION_CONSTANTS[pair]
    prod_geo = Geometry(prod["WIDEN_RATIO"], prod["ADD_PIPS_FLOOR"], prod["EXIT_PIPS"], prod["ADD_PIPS_CEILING"])
    mc_geo, mc_selection = select_geometry_for_mc(sweep, derived, prod_geo)
    print(
        f"     Best sweep: W={derived.widen_ratio} F={derived.add_pips_floor} E={derived.exit_pips} "
        f"(prod W={prod_geo.widen_ratio} F={prod_geo.add_pips_floor} E={prod_geo.exit_pips})",
        flush=True,
    )
    print(
        f"     MC trusted: W={mc_geo.widen_ratio} F={mc_geo.add_pips_floor} E={mc_geo.exit_pips} "
        f"({mc_selection})",
        flush=True,
    )

    if skip_mc:
        print("[6-9] Skipped (--skip-mc: stages 1-5 only)", flush=True)
        report = PipelineReport(
            pair=pair,
            slot=slot,
            data=data,
            sigma={"full_quarter": sig_fq, "june_blowup": sig_jb, "gbpusd_ref": gbp_sig},
            spread=spread,
            geometry_sweep=sweep,
            derived_geometry=derived,
            production_geometry=prod_geo,
            mc_geometry=mc_geo,
            monte_carlo={"skipped": True, "note": "stages 1-5 only (--skip-mc)"},
            passivity={},
            gap_stress={},
            live_tick={},
            verdict={},
            elapsed_sec=time.time() - t0,
        )
        report.verdict = go_no_go(report)
        return report

    print(f"[6] Monte Carlo n={n_mc} (5 windows × 2 spacing × 3 bias)...", flush=True)
    geometry_comparison = None
    mc_runs: dict[str, dict] = {}

    if dual_geometry_mc and not geometry_close(derived, prod_geo):
        for label, geo in [("production", prod_geo), ("derived", derived)]:
            mc_runs[label] = run_monte_carlo(
                pair, geo, pair_spread, n_seeds=n_mc, workers=workers, label=label,
            )
        geometry_comparison = build_geometry_comparison(mc_runs["production"], mc_runs["derived"])
        # n=30 sweep reference for context
        sweep_prod = sweep.get("production_scored", {})
        sweep_best = sweep.get("best", {})
        if sweep_prod.get("combined") and sweep_best.get("combined"):
            sp = sweep_prod["combined"]["mean_realised"]
            sb = sweep_best["combined"]["mean_realised"]
            if sp and abs(sp) > 1e-6:
                geometry_comparison["sweep_n30_derived_vs_production_pct"] = (sb - sp) / abs(sp) * 100.0
        print_geometry_comparison(geometry_comparison)
        derived_key = geometry_key(derived)
        mc = mc_runs["derived"] if geometry_key(mc_geo) == derived_key else mc_runs["production"]
        mc["geometry_selection"] = mc_selection
        mc["alternate_geometry_mc"] = {
            k: v for k, v in mc_runs.items()
            if geometry_key(Geometry(**v["geometry"])) != geometry_key(mc_geo)
        }
        meta = {"geometry_comparison": geometry_comparison, "monte_carlo_by_geometry": mc_runs}
    else:
        mc = run_monte_carlo(pair, mc_geo, pair_spread, n_seeds=n_mc, workers=workers, label="primary")
        mc["geometry_selection"] = mc_selection
        meta = {}

    print("[7] Passivity headroom...", flush=True)
    passivity = passivity_check(df_fq, pair_spread)

    print("[8] Gap-slippage stress...", flush=True)
    gap = gap_stress(pair, mc_geo, pair_spread)

    print("[9] Live-tick reference (5-day instrumented vs MT5 baselines)...", flush=True)
    live = live_tick_reference(pair, mc_geo, pair_spread)

    report = PipelineReport(
        pair=pair,
        slot=slot,
        data=data,
        sigma={"full_quarter": sig_fq, "june_blowup": sig_jb, "gbpusd_ref": gbp_sig},
        spread=spread,
        geometry_sweep=sweep,
        derived_geometry=derived,
        production_geometry=prod_geo,
        mc_geometry=mc_geo,
        monte_carlo=mc,
        passivity=passivity,
        gap_stress=gap,
        live_tick=live,
        verdict={},
        elapsed_sec=time.time() - t0,
        meta=meta,
    )
    report.verdict = go_no_go(report)
    return report


def compare_adr091_from_report(json_path: str) -> list[dict]:
    payload = json.loads(Path(json_path).read_text(encoding="utf-8"))
    results = mc_results_from_report_payload(payload["monte_carlo"])
    return compare_adr091(results, payload.get("pair", "GBPUSD"))


def verify_report_verdict(json_path: str) -> dict:
    """Re-run ADR-091 comparison and go_no_go on a saved report (no MC re-run)."""
    payload = json.loads(Path(json_path).read_text(encoding="utf-8"))
    mc = dict(payload["monte_carlo"])
    mc["adr091_comparison"] = compare_adr091(mc_results_from_report_payload(mc), payload["pair"])
    report = PipelineReport(
        pair=payload["pair"],
        slot=payload["slot"],
        data=payload["data"],
        sigma=payload["sigma"],
        spread=payload["spread"],
        geometry_sweep=payload["geometry_sweep"],
        derived_geometry=Geometry(**payload["derived_geometry"]),
        production_geometry=Geometry(**payload["production_geometry"]),
        mc_geometry=Geometry(**payload["mc_geometry"]),
        monte_carlo=mc,
        passivity=payload["passivity"],
        gap_stress=payload["gap_stress"],
        live_tick=payload["live_tick"],
        verdict={},
        elapsed_sec=payload.get("elapsed_sec", 0.0),
        meta=payload.get("meta", {}),
    )
    verdict = go_no_go(report)
    return {
        "verdict": verdict,
        "adr091_comparison": mc["adr091_comparison"],
        "adr_ok": (
            evaluate_adr091_ok(mc["adr091_comparison"])
            if payload["pair"].upper() == "GBPUSD"
            else None
        ),
    }


def main() -> int:
    ap = argparse.ArgumentParser(description="Pair validation pipeline (temp analysis)")
    ap.add_argument("--pair", default="GBPUSD")
    ap.add_argument("--n-sweep", type=int, default=30, help="seeds per geometry combo in sweep")
    ap.add_argument("--n-mc", type=int, default=500, help="seeds for full Monte Carlo matrix")
    ap.add_argument("--workers", type=int, default=6, help="parallel worker processes for seed batches")
    ap.add_argument("--skip-mc", action="store_true", help="stop after geometry sweep (stages 1-5)")
    ap.add_argument("--dual-geometry-mc", action="store_true",
                    help="run full n=500 MC at both production and sweep-derived geometries")
    ap.add_argument("--compare-adr091-only", metavar="REPORT.json",
                    help="run compare_adr091 against saved report JSON and exit")
    ap.add_argument("--verify-report", metavar="REPORT.json",
                    help="recompute ADR-091 comparison and go_no_go verdict from saved report")
    ap.add_argument("--out-prefix", default=None)
    args = ap.parse_args()

    if args.verify_report:
        result = verify_report_verdict(args.verify_report)
        print(json.dumps(result, indent=2))
        return 0 if result["verdict"]["pipeline_trustworthy"] else 1

    if args.compare_adr091_only:
        rows = compare_adr091_from_report(args.compare_adr091_only)
        print(json.dumps(rows, indent=2))
        return 0 if rows else 1

    report = run_pipeline(
        args.pair.upper(), n_sweep=args.n_sweep, n_mc=args.n_mc, workers=args.workers,
        skip_mc=args.skip_mc, dual_geometry_mc=args.dual_geometry_mc,
    )
    prefix = args.out_prefix or str(TEMP / f"pair_validation_{args.pair.upper()}")
    json_path = f"{prefix}_report.json"
    md_path = f"{prefix}_report.md"

    def json_default(o):
        if isinstance(o, Geometry):
            return o.as_dict()
        if isinstance(o, np.generic):
            return o.item()
        raise TypeError(type(o))

    payload = asdict(report)
    Path(json_path).write_text(json.dumps(payload, indent=2, default=json_default), encoding="utf-8")
    Path(md_path).write_text(render_markdown(report), encoding="utf-8")

    print(f"\n{'='*72}\nFINAL: {report.verdict['recommendation']}\n"
          f"Reports: {json_path}\n         {md_path}\n{'='*72}", flush=True)
    return 0 if report.verdict["pipeline_trustworthy"] else 1


if __name__ == "__main__":
    sys.exit(main())
