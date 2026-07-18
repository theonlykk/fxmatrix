"""Read-only EURGBP v7 validation — temp analysis only."""
from __future__ import annotations

import importlib.util
import os
import sys
import time
from pathlib import Path
from unittest.mock import patch

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "scripts"
TEMP = ROOT / "temp"
EURGBP_PAIR_SPREAD = 0.63
PIP = 0.0001

spec7 = importlib.util.spec_from_file_location("simv7", SCRIPTS / "grid_sim_v7_real_signal.py")
simv7 = importlib.util.module_from_spec(spec7)
spec7.loader.exec_module(simv7)

spec6 = importlib.util.spec_from_file_location("simv6", SCRIPTS / "grid_sim_v6_dynamic_spacing.py")
simv6 = importlib.util.module_from_spec(spec6)
spec6.loader.exec_module(simv6)
sys.modules["grid_sim_v6_dynamic_spacing"] = simv6  # simulate_one_path imports this name


def load_truss() -> "pd.DataFrame":
    import pandas as pd  # noqa: F401 — used by simv6.load_mt5_csv return type

    for src in (
        TEMP / "EURGBP_truss_crisis_oos.csv",
        Path(os.environ["APPDATA"]) / "MetaQuotes/Terminal/Common/Files/EURGBP_truss_crisis_oos.csv",
    ):
        if src.exists() and src.stat().st_size > 1000:
            df = simv6.load_mt5_csv(str(src))
            print(f"EURGBP truss: {len(df)} bars from {src}", flush=True)
            return df
    raise RuntimeError("EURGBP truss CSV missing — run temp/run_eurgbp_truss_export.bat first")


def sigma_fv_stats(closes: np.ndarray, label: str) -> dict:
    n = len(closes)
    sigmas, dynamic_hs = [], []
    for i in range(48, n):
        c6, c12, c48 = closes[i - 6], closes[i - 12], closes[i - 48]
        mean_bc = (c6 + c12 + c48) / 3.0
        sigma = float(np.sqrt(((c6 - mean_bc) ** 2 + (c12 - mean_bc) ** 2 + (c48 - mean_bc) ** 2) / 3.0))
        sigmas.append(sigma)
        dynamic_hs.append(simv7.QUOTE_SPREAD + sigma * simv7.SPREAD_MULTIPLIER)
    sig = np.array(sigmas)
    dhs = np.array(dynamic_hs)
    return {
        "label": label,
        "sigma_fv_mean": float(sig.mean()),
        "sigma_fv_median": float(np.median(sig)),
        "sigma_fv_p90": float(np.percentile(sig, 90)),
        "sigma_fv_max": float(sig.max()),
        "sigma_fv_mean_pips": float(sig.mean() / PIP),
        "dynamic_hs_mean_pips": float(dhs.mean() / PIP),
        "dynamic_hs_median_pips": float(np.median(dhs) / PIP),
        "n_bars": n,
    }


def simulate_instrumented(closes, bid_arr, offer_arr, times, bias_mode, spacing_mode, seed, pair_spread):
    """Single-seed run with L0/add/reload/exit breakdown."""
    rng = np.random.default_rng(seed)
    n_bars = len(closes) - 1
    sigma = np.std(np.diff(np.log(closes)), ddof=1) * 2.5
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
                    layers.append(simv7.Layer(
                        entry_price=fill_p, direction=filled,
                        exit_target_raw=fill_p + filled * exit_dist))
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
                crossed = (
                    (cur.direction == 1 and pp < eff_exit <= pn)
                    or (cur.direction == -1 and pp > eff_exit >= pn)
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
                    reload_step = min(simv7.ADD_PIPS_CEILING, simv7.ADD_PIPS_FLOOR * depth_mult)
                    add_target = last_exit_price - cur.direction * simv7.pips_to_price(reload_step, PIP)
                    used_reload = True
                elif spacing_mode == "reload_flat" and last_exit_price is not None:
                    add_target = last_exit_price - cur.direction * simv7.pips_to_price(simv7.ADD_PIPS_FLOOR, PIP)
                    used_reload = True
                else:
                    still_shallow = len(layers) < 3
                    add_pips = simv7.ADD_PIPS_FLOOR if (spacing_mode == "flat" or still_shallow) else current_add_pips
                    add_target = cur.entry_price - cur.direction * simv7.pips_to_price(add_pips, PIP)
                eff_add = add_target - cur.direction * half_spread
                hit = (
                    (cur.direction == 1 and pp > eff_add >= pn)
                    or (cur.direction == -1 and pp < eff_add <= pn)
                )
                if hit:
                    layers.append(simv7.Layer(
                        entry_price=add_target, direction=cur.direction,
                        exit_target_raw=add_target + cur.direction * exit_dist))
                    if used_reload:
                        reload += 1
                    else:
                        add += 1
                    if spacing_mode in ("reload_anchor", "reload_flat"):
                        last_exit_price = None
                    if len(layers) >= 3:
                        current_add_pips = min(simv7.ADD_PIPS_CEILING, current_add_pips * simv7.WIDEN_RATIO)
                    max_layers = max(max_layers, len(layers))

        price_current = end_price
        equity = 10000.0 + pnl_realised
        if times is not None:
            import pandas as pd
            bar_day = pd.Timestamp(times[i + 1]).normalize()
            if bar_day != current_day:
                daily_start = 10000.0 if current_day == -1 else equity
                current_day = bar_day
        if daily_start > 0:
            dd = (daily_start - equity) / daily_start
            if dd >= 0.04:
                dd4 = True
            if dd >= 0.03:
                dd3 = True

    return {"l0": l0, "add": add, "reload": reload, "exits": exits,
            "max_layers": max_layers, "dd3": dd3, "dd4": dd4,
            "realised": pnl_realised}


def run_n_seeds(closes, spread_pts, times, symbol, pair_spread, n_seeds, spacing, mode_name, mode):
    bid_arr, offer_arr = simv7.precompute_gbpusd_signal(closes, spread_pts, PIP)
    patched = dict(simv6.PAIR_SPREAD_PIPS)
    patched[symbol] = pair_spread
    pnls, realised, unrealised, max_layers, dd3, dd4 = [], [], [], [], [], []
    t0 = time.time()
    with patch.dict(simv6.PAIR_SPREAD_PIPS, patched, clear=False):
        for s in range(n_seeds):
            r = simv7.simulate_one_path(
                closes, bid_arr, offer_arr, times=times, symbol=symbol,
                bias_mode=mode, spacing_mode=spacing, seed=s, sub_steps=100)
            pnls.append(r["pnl_total_usd"])
            realised.append(r["pnl_realised_usd"])
            unrealised.append(r["pnl_unrealised_usd"])
            max_layers.append(r["max_layers"])
            dd3.append(int(r["drawdown_exceeded_3pct"]))
            dd4.append(int(r["drawdown_exceeded_4pct"]))
            if (s + 1) % 100 == 0:
                print(f"    {symbol} {spacing} {mode_name}: {s+1}/{n_seeds} ({time.time()-t0:.0f}s)", flush=True)
    return {
        "mean_realised": float(np.mean(realised)),
        "mean_total": float(np.mean(pnls)),
        "worst_total": float(np.min(pnls)),
        "mean_max_layers": float(np.mean(max_layers)),
        "max_max_layers": int(np.max(max_layers)),
        "dd3_count": int(np.sum(dd3)),
        "dd4_count": int(np.sum(dd4)),
        "dd3_rate": float(np.mean(dd3) * 100),
        "dd4_rate": float(np.mean(dd4) * 100),
        "nonflat_end": int(np.sum(np.abs(np.array(unrealised)) > 1e-12)),
    }


def print_sigma_table(stats_list):
    print("\n=== sigma_fv_bc (FV 6/12/48 term-structure dispersion) ===", flush=True)
    print(f"{'Window':<22} {'bars':>6} {'sigma mean':>12} {'pips':>6} {'median':>12} {'p90':>12} {'dyn_hs mean':>12}", flush=True)
    for s in stats_list:
        print(
            f"{s['label']:<22} {s['n_bars']:>6} {s['sigma_fv_mean']:>12.6f} {s['sigma_fv_mean_pips']:>6.2f} "
            f"{s['sigma_fv_median']:>12.6f} {s['sigma_fv_p90']:>12.6f} {s['dynamic_hs_mean_pips']:>10.2f} pips",
            flush=True,
        )


def print_results(title, results, counts, n_seeds):
    print(f"\n{'='*130}\n{title} (n={n_seeds})\n{'='*130}", flush=True)
    hdr = (
        f"{'Window':<14}{'Spacing':<14}{'Mode':<9}"
        f"{'L0':>5}{'Add':>5}{'Rld':>5}{'Exit':>6}{'MaxL':>5}"
        f"{'MeanReal':>10}{'MeanTot':>10}{'Worst':>10}"
        f"{'DD3#':>5}{'DD3%':>6}{'DD4#':>5}{'DD4%':>6}"
    )
    print(hdr, flush=True)
    for key in sorted(results.keys()):
        win, spacing, mode = key
        r = results[key]
        c = counts.get(key, {})
        print(
            f"{win:<14}{spacing:<14}{mode:<9}"
            f"{c.get('l0', '-'):>5}{c.get('add', '-'):>5}{c.get('reload', '-'):>5}{c.get('exits', '-'):>6}"
            f"{r['max_max_layers']:>5d}"
            f"{r['mean_realised']:>10.2f}{r['mean_total']:>10.2f}{r['worst_total']:>10.2f}"
            f"{r['dd3_count']:>5d}{r['dd3_rate']:>6.1f}{r['dd4_count']:>5d}{r['dd4_rate']:>6.1f}",
            flush=True,
        )


def main():
    n_seeds = int(os.environ.get("N_SEEDS", "500"))
    print(
        f"Config: WIDEN_RATIO={simv7.WIDEN_RATIO} ADD_PIPS_CEILING={simv7.ADD_PIPS_CEILING} "
        f"EXIT_PIPS={simv7.EXIT_PIPS} QUOTE_SPREAD={simv7.QUOTE_SPREAD} N_SEEDS={n_seeds}",
        flush=True,
    )
    print(f"EURGBP PAIR_SPREAD_PIPS={EURGBP_PAIR_SPREAD} (was 0.58 placeholder; GBPUSD=0.64)", flush=True)

    df_fq = simv6.load_mt5_csv(str(ROOT / "data" / "EURGBP_full_quarter.csv"))
    df_truss = load_truss()
    df_gbp_fq = simv6.load_mt5_csv(str(ROOT / "data" / "GBPUSD_full_quarter.csv"))
    df_gbp_truss = simv6.load_mt5_csv(str(ROOT / "data" / "GBPUSD_truss_crisis_oos.csv"))

    windows = {
        "full_quarter": {"EURGBP": (df_fq, EURGBP_PAIR_SPREAD), "GBPUSD": (df_gbp_fq, simv6.PAIR_SPREAD_PIPS["GBPUSD"])},
        "truss_crisis": {"EURGBP": (df_truss, EURGBP_PAIR_SPREAD), "GBPUSD": (df_gbp_truss, simv6.PAIR_SPREAD_PIPS["GBPUSD"])},
    }

    sigma_stats = []
    for df, name in [
        (df_fq, "EURGBP full_quarter"),
        (df_truss, "EURGBP truss_crisis"),
        (df_gbp_fq, "GBPUSD full_quarter"),
        (df_gbp_truss, "GBPUSD truss_crisis"),
    ]:
        sigma_stats.append(sigma_fv_stats(df["CLOSE"].values.astype(float), name))
    print_sigma_table(sigma_stats)

    ratio_eur_gbp = sigma_stats[0]["sigma_fv_mean"] / sigma_stats[2]["sigma_fv_mean"]
    ratio_truss = sigma_stats[1]["sigma_fv_mean"] / sigma_stats[3]["sigma_fv_mean"]
    print(
        f"\nEURGBP/GBPUSD sigma_fv ratio: full_quarter={ratio_eur_gbp:.3f} truss_crisis={ratio_truss:.3f}",
        flush=True,
    )

    spacing_modes = ["reload_anchor", "reload_flat"]
    bias_modes = [
        ("MM_LONG", simv7.BiasMode.LONG_ONLY),
        ("MM_SHORT", simv7.BiasMode.SHORT_ONLY),
        ("MM_BOTH", simv7.BiasMode.BOTH),
    ]

    eur_results, gbp_results = {}, {}
    eur_counts, gbp_counts = {}, {}
    run_gbp_baseline = os.environ.get("RUN_GBP_BASELINE", "0") == "1"

    for win_name, pairs in windows.items():
        print(f"\n--- Window: {win_name} ---", flush=True)
        for symbol, (df, pair_spread) in pairs.items():
            if symbol == "GBPUSD" and not run_gbp_baseline:
                continue
            closes = df["CLOSE"].values.astype(float)
            spread_pts = df["SPREAD"].values.astype(float)
            times = df["datetime"].values
            bid_arr, offer_arr = simv7.precompute_gbpusd_signal(closes, spread_pts, PIP)
            store = eur_results if symbol == "EURGBP" else gbp_results
            counts_store = eur_counts if symbol == "EURGBP" else gbp_counts
            for spacing in spacing_modes:
                for mode_name, mode in bias_modes:
                    key = (win_name, spacing, mode_name)
                    print(f"  Running {symbol} {key}...", flush=True)
                    store[key] = run_n_seeds(
                        closes, spread_pts, times, symbol, pair_spread,
                        n_seeds, spacing, mode_name, mode)
                    counts_store[key] = simulate_instrumented(
                        closes, bid_arr, offer_arr, times, mode, spacing, 0, pair_spread)

    print_results("EURGBP validation", eur_results, eur_counts, n_seeds)
    if run_gbp_baseline:
        print_results("GBPUSD baseline (same methodology)", gbp_results, gbp_counts, n_seeds)
    else:
        print("\n(GBPUSD n=500 baseline omitted — see ADR-091 Section 5a/5d; set RUN_GBP_BASELINE=1 to rerun)", flush=True)

    # Geometry sensitivity on EURGBP full_quarter MM_BOTH reload_flat seed=0
    print("\n=== EXIT_PIPS sensitivity (EURGBP full_quarter, MM_BOTH, reload_flat, seed=0) ===", flush=True)
    closes = df_fq["CLOSE"].values.astype(float)
    spread_pts = df_fq["SPREAD"].values.astype(float)
    times = df_fq["datetime"].values
    bid_arr, offer_arr = simv7.precompute_gbpusd_signal(closes, spread_pts, PIP)
    for exit_pips in [3.0, 2.0, 1.5]:
        old = simv7.EXIT_PIPS
        simv7.EXIT_PIPS = exit_pips
        r = simulate_instrumented(
            closes, bid_arr, offer_arr, times, simv7.BiasMode.BOTH, "reload_flat", 0, EURGBP_PAIR_SPREAD)
        simv7.EXIT_PIPS = old
        print(
            f"  EXIT_PIPS={exit_pips}: L0={r['l0']} add={r['add']} reload={r['reload']} exits={r['exits']} "
            f"max_layers={r['max_layers']} realised=${r['realised']:.2f}",
            flush=True,
        )

    # WIDEN_RATIO spot check
    print("\n=== WIDEN_RATIO sensitivity (EURGBP truss_crisis, MM_BOTH reload_anchor, seed=0) ===", flush=True)
    closes = df_truss["CLOSE"].values.astype(float)
    spread_pts = df_truss["SPREAD"].values.astype(float)
    times = df_truss["datetime"].values
    bid_arr, offer_arr = simv7.precompute_gbpusd_signal(closes, spread_pts, PIP)
    for widen in [1.304, 1.5, 1.2]:
        old = simv7.WIDEN_RATIO
        simv7.WIDEN_RATIO = widen
        r = simulate_instrumented(
            closes, bid_arr, offer_arr, times, simv7.BiasMode.BOTH, "reload_anchor", 0, EURGBP_PAIR_SPREAD)
        simv7.WIDEN_RATIO = old
        print(
            f"  WIDEN_RATIO={widen}: max_layers={r['max_layers']} add={r['add']} reload={r['reload']} "
            f"realised=${r['realised']:.2f} dd3={r['dd3']} dd4={r['dd4']}",
            flush=True,
        )

    return 0


if __name__ == "__main__":
    sys.exit(main())
