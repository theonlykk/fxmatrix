"""Read-only EURGBP v7 validation — temp analysis only."""
from __future__ import annotations

import importlib.util
import os
import sys
import time
from pathlib import Path

import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "scripts"
TEMP = ROOT / "temp"
sys.path.insert(0, str(SCRIPTS))

sys.path.insert(0, str(SCRIPTS))

import sim_costs

spec7 = importlib.util.spec_from_file_location("simv7", SCRIPTS / "grid_sim_v7_real_signal.py")
simv7 = importlib.util.module_from_spec(spec7)
spec7.loader.exec_module(simv7)

spec6 = importlib.util.spec_from_file_location("simv6", SCRIPTS / "grid_sim_v6_dynamic_spacing.py")
simv6 = importlib.util.module_from_spec(spec6)
spec6.loader.exec_module(simv6)
sys.modules["grid_sim_v6_dynamic_spacing"] = simv6  # simulate_one_path imports this name

SYMBOL_EURGBP = "EURGBP"
SYMBOL_GBPUSD = "GBPUSD"
STRADDLE_HALF_WIDTH_PIPS = 9.0


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


def sigma_fv_stats(closes: np.ndarray, label: str, symbol: str = SYMBOL_EURGBP) -> dict:
    pip = sim_costs.get_pair_spec(symbol).pip_size
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
        "sigma_fv_mean_pips": float(sig.mean() / pip),
        "dynamic_hs_mean_pips": float(dhs.mean() / pip),
        "dynamic_hs_median_pips": float(np.median(dhs) / pip),
        "n_bars": n,
    }


def simulate_instrumented(
    closes,
    bid_arr,
    offer_arr,
    times,
    bias_mode,
    seed,
    symbol=SYMBOL_EURGBP,
    gbpusd_closes=None,
    straddle_half_width_pips: float = STRADDLE_HALF_WIDTH_PIPS,
):
    """Single-seed run with L0/add/exit breakdown (fxgrind-parity add geometry)."""
    rng = np.random.default_rng(seed)
    n_bars = len(closes) - 1
    sigma = np.std(np.diff(np.log(closes)), ddof=1) * 2.5
    exit_dist = sim_costs.pips_to_price(simv7.EXIT_PIPS, symbol)
    half_spread = sim_costs.half_spread_price(symbol)
    entry_comm = sim_costs.commission_per_leg_usd(simv7.LOT_SIZE)
    exit_comm = entry_comm
    pod_half_width_pips = float(straddle_half_width_pips)

    layers = []
    pnl_realised = 0.0
    equity = 10000.0
    daily_start = 10000.0
    current_day = -1
    dd3 = dd4 = False
    max_layers = 0
    l0 = add = reload = exits = 0

    def conv_rate(bar_i: int) -> float | None:
        if gbpusd_closes is not None:
            return float(gbpusd_closes[bar_i])
        return None

    price_current = closes[0]
    for i in range(n_bars):
        rate = conv_rate(i)
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
                            entry_commission_usd=entry_comm,
                        )
                    )
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
                    gross = sim_costs.price_diff_to_usd(
                        (closed.exit_target_raw - closed.entry_price) * closed.direction,
                        symbol,
                        simv7.LOT_SIZE,
                        rate,
                    )
                    pnl_realised += gross - exit_comm
                    exits += 1
            if layers:
                cur = layers[-1]
                add_pips = simv7.add_pips_from_width(pod_half_width_pips)
                add_target = simv7.compute_add_target(layers, add_pips, symbol)
                eff_add = add_target - cur.direction * half_spread
                hit = (
                    (cur.direction == 1 and pp > eff_add >= pn)
                    or (cur.direction == -1 and pp < eff_add <= pn)
                )
                if hit:
                    layers.append(
                        simv7.Layer(
                            entry_price=add_target,
                            direction=cur.direction,
                            exit_target_raw=add_target + cur.direction * exit_dist,
                            entry_commission_usd=entry_comm,
                        )
                    )
                    add += 1
                    max_layers = max(max_layers, len(layers))

        price_current = end_price
        equity = 10000.0 + pnl_realised
        if times is not None:
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

    return {
        "l0": l0,
        "add": add,
        "reload": reload,
        "exits": exits,
        "max_layers": max_layers,
        "dd3": dd3,
        "dd4": dd4,
        "realised": pnl_realised,
    }


def run_n_seeds(closes, spread_pts, times, symbol, n_seeds, mode_name, mode, gbpusd_closes=None):
    bid_arr, offer_arr = simv7.precompute_gbpusd_signal(closes, spread_pts, symbol=symbol)
    sim_kwargs = {}
    if gbpusd_closes is not None:
        sim_kwargs["gbpusd_closes"] = np.asarray(gbpusd_closes, dtype=float)
    pnls, realised, unrealised, max_layers, dd3, dd4 = [], [], [], [], [], []
    t0 = time.time()
    for s in range(n_seeds):
        r = simv7.simulate_one_path(
            closes,
            bid_arr,
            offer_arr,
            times=times,
            symbol=symbol,
            bias_mode=mode,
            seed=s,
            sub_steps=100,
            **sim_kwargs,
        )
        pnls.append(r["pnl_total_usd"])
        realised.append(r["pnl_realised_usd"])
        unrealised.append(r["pnl_unrealised_usd"])
        max_layers.append(r["max_layers"])
        dd3.append(int(r["drawdown_exceeded_3pct"]))
        dd4.append(int(r["drawdown_exceeded_4pct"]))
        if (s + 1) % 100 == 0:
            print(f"    {symbol} {mode_name}: {s+1}/{n_seeds} ({time.time()-t0:.0f}s)", flush=True)
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
        f"{'Window':<14}{'Mode':<9}"
        f"{'L0':>5}{'Add':>5}{'Rld':>5}{'Exit':>6}{'MaxL':>5}"
        f"{'MeanReal':>10}{'MeanTot':>10}{'Worst':>10}"
        f"{'DD3#':>5}{'DD3%':>6}{'DD4#':>5}{'DD4%':>6}"
    )
    print(hdr, flush=True)
    for key in sorted(results.keys()):
        win, mode = key
        r = results[key]
        c = counts.get(key, {})
        print(
            f"{win:<14}{mode:<9}"
            f"{c.get('l0', '-'):>5}{c.get('add', '-'):>5}{c.get('reload', '-'):>5}{c.get('exits', '-'):>6}"
            f"{r['max_max_layers']:>5d}"
            f"{r['mean_realised']:>10.2f}{r['mean_total']:>10.2f}{r['worst_total']:>10.2f}"
            f"{r['dd3_count']:>5d}{r['dd3_rate']:>6.1f}{r['dd4_count']:>5d}{r['dd4_rate']:>6.1f}",
            flush=True,
        )


def _aligned_gbpusd(times, suffix: str) -> np.ndarray | None:
    path = ROOT / "data" / f"GBPUSD_{suffix}.csv"
    if not path.is_file():
        return None
    gbp = simv6.load_mt5_csv(str(path))
    eur_t = pd.to_datetime(pd.Series(times))
    aligned = gbp.set_index("datetime")["CLOSE"].reindex(eur_t.values, method="ffill")
    if aligned.isna().any():
        aligned = aligned.bfill()
    return aligned.to_numpy(dtype=float)


def main():
    n_seeds = int(os.environ.get("N_SEEDS", "500"))
    eurgbp_spread = sim_costs.PAIR_SPREAD_PIPS[SYMBOL_EURGBP]
    print(
        f"Config: GRIND_ADD_WIDTH_MULTIPLE={simv7.GRIND_ADD_WIDTH_MULTIPLE} "
        f"EXIT_PIPS={simv7.EXIT_PIPS} QUOTE_SPREAD={simv7.QUOTE_SPREAD} N_SEEDS={n_seeds}",
        flush=True,
    )
    print(f"EURGBP PAIR_SPREAD_PIPS={eurgbp_spread} (from sim_costs; GBPUSD={sim_costs.PAIR_SPREAD_PIPS[SYMBOL_GBPUSD]})", flush=True)

    df_fq = simv6.load_mt5_csv(str(ROOT / "data" / "EURGBP_full_quarter.csv"))
    df_truss = load_truss()
    df_gbp_fq = simv6.load_mt5_csv(str(ROOT / "data" / "GBPUSD_full_quarter.csv"))
    df_gbp_truss = simv6.load_mt5_csv(str(ROOT / "data" / "GBPUSD_truss_crisis_oos.csv"))

    gbpusd_fq = _aligned_gbpusd(df_fq["datetime"].values, "full_quarter")
    gbpusd_truss = _aligned_gbpusd(df_truss["datetime"].values, "truss_crisis_oos")

    windows = {
        "full_quarter": {
            SYMBOL_EURGBP: (df_fq, gbpusd_fq),
            SYMBOL_GBPUSD: (df_gbp_fq, None),
        },
        "truss_crisis": {
            SYMBOL_EURGBP: (df_truss, gbpusd_truss),
            SYMBOL_GBPUSD: (df_gbp_truss, None),
        },
    }

    sigma_stats = []
    for df, name, sym in [
        (df_fq, "EURGBP full_quarter", SYMBOL_EURGBP),
        (df_truss, "EURGBP truss_crisis", SYMBOL_EURGBP),
        (df_gbp_fq, "GBPUSD full_quarter", SYMBOL_GBPUSD),
        (df_gbp_truss, "GBPUSD truss_crisis", SYMBOL_GBPUSD),
    ]:
        sigma_stats.append(sigma_fv_stats(df["CLOSE"].values.astype(float), name, sym))
    print_sigma_table(sigma_stats)

    ratio_eur_gbp = sigma_stats[0]["sigma_fv_mean"] / sigma_stats[2]["sigma_fv_mean"]
    ratio_truss = sigma_stats[1]["sigma_fv_mean"] / sigma_stats[3]["sigma_fv_mean"]
    print(
        f"\nEURGBP/GBPUSD sigma_fv ratio: full_quarter={ratio_eur_gbp:.3f} truss_crisis={ratio_truss:.3f}",
        flush=True,
    )

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
        for symbol, (df, gbpusd_closes) in pairs.items():
            if symbol == SYMBOL_GBPUSD and not run_gbp_baseline:
                continue
            closes = df["CLOSE"].values.astype(float)
            spread_pts = df["SPREAD"].values.astype(float)
            times = df["datetime"].values
            bid_arr, offer_arr = simv7.precompute_gbpusd_signal(closes, spread_pts, symbol=symbol)
            store = eur_results if symbol == SYMBOL_EURGBP else gbp_results
            counts_store = eur_counts if symbol == SYMBOL_EURGBP else gbp_counts
            for mode_name, mode in bias_modes:
                key = (win_name, mode_name)
                print(f"  Running {symbol} {key}...", flush=True)
                store[key] = run_n_seeds(
                    closes,
                    spread_pts,
                    times,
                    symbol,
                    n_seeds,
                    mode_name,
                    mode,
                    gbpusd_closes=gbpusd_closes,
                )
                counts_store[key] = simulate_instrumented(
                    closes,
                    bid_arr,
                    offer_arr,
                    times,
                    mode,
                    0,
                    symbol=symbol,
                    gbpusd_closes=gbpusd_closes,
                )

    print_results("EURGBP validation", eur_results, eur_counts, n_seeds)
    if run_gbp_baseline:
        print_results("GBPUSD baseline (same methodology)", gbp_results, gbp_counts, n_seeds)
    else:
        print("\n(GBPUSD n=500 baseline omitted — see ADR-091 Section 5a/5d; set RUN_GBP_BASELINE=1 to rerun)", flush=True)

    print("\n=== EXIT_PIPS sensitivity (EURGBP full_quarter, MM_BOTH, reload_flat, seed=0) ===", flush=True)
    closes = df_fq["CLOSE"].values.astype(float)
    spread_pts = df_fq["SPREAD"].values.astype(float)
    times = df_fq["datetime"].values
    bid_arr, offer_arr = simv7.precompute_gbpusd_signal(closes, spread_pts, symbol=SYMBOL_EURGBP)
    for exit_pips in [3.0, 2.0, 1.5]:
        old = simv7.EXIT_PIPS
        simv7.EXIT_PIPS = exit_pips
        r = simulate_instrumented(
            closes,
            bid_arr,
            offer_arr,
            times,
            simv7.BiasMode.BOTH,
            "reload_flat",
            0,
            symbol=SYMBOL_EURGBP,
            gbpusd_closes=gbpusd_fq,
        )
        simv7.EXIT_PIPS = old
        print(
            f"  EXIT_PIPS={exit_pips}: L0={r['l0']} add={r['add']} reload={r['reload']} exits={r['exits']} "
            f"max_layers={r['max_layers']} realised=${r['realised']:.2f}",
            flush=True,
        )

    print("\n=== Add spacing (2x width) note: fixed entry-anchored adds — no WIDEN_RATIO sweep ===", flush=True)
    closes = df_truss["CLOSE"].values.astype(float)
    spread_pts = df_truss["SPREAD"].values.astype(float)
    times = df_truss["datetime"].values
    bid_arr, offer_arr = simv7.precompute_gbpusd_signal(closes, spread_pts, symbol=SYMBOL_EURGBP)
    r = simulate_instrumented(
        closes,
        bid_arr,
        offer_arr,
        times,
        simv7.BiasMode.BOTH,
        0,
        symbol=SYMBOL_EURGBP,
        gbpusd_closes=gbpusd_truss,
    )
    print(
        f"  truss_crisis seed=0: max_layers={r['max_layers']} add={r['add']} reload={r['reload']} "
        f"realised=${r['realised']:.2f} dd3={r['dd3']} dd4={r['dd4']}",
        flush=True,
    )

    return 0


if __name__ == "__main__":
    sys.exit(main())
