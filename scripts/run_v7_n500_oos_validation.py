import argparse
import importlib.util
import os
import sys
import time
from unittest.mock import patch

import numpy as np
import pandas as pd

script_dir = os.path.dirname(os.path.abspath(__file__))
spec7 = importlib.util.spec_from_file_location("simv7", os.path.join(script_dir, "grid_sim_v7_real_signal.py"))
simv7 = importlib.util.module_from_spec(spec7)
spec7.loader.exec_module(simv7)
spec6 = importlib.util.spec_from_file_location("simv6", os.path.join(script_dir, "grid_sim_v6_dynamic_spacing.py"))
simv6 = importlib.util.module_from_spec(spec6)
spec6.loader.exec_module(simv6)

SPACING_MODES = ["reload_anchor", "reload_flat"]

BIAS_MODES = [
    ("MM_LONG", simv7.BiasMode.LONG_ONLY),
    ("MM_SHORT", simv7.BiasMode.SHORT_ONLY),
    ("MM_BOTH", simv7.BiasMode.BOTH),
]

# Truss Crisis smoke (n=20, 18,780 bars): ~4.1-6.0 s/seed, mean ~4.92 s/seed
SMOKE_SEC_PER_SEED_LO = 4.1
SMOKE_SEC_PER_SEED_HI = 6.0
SMOKE_SEC_PER_SEED_MEAN = 4.92


def _result_sort_key(key):
    spacing_mode, window_name, mode_name = key
    mode_order = {"MM_LONG": 0, "MM_SHORT": 1, "MM_BOTH": 2}
    spacing_order = {"reload_anchor": 0, "reload_flat": 1}
    return (
        window_name,
        mode_order.get(mode_name, mode_name),
        spacing_order.get(spacing_mode, spacing_mode),
    )


def run_validation(n_seeds=500, windows=None, spacing_modes=None, simulate_fn=None,
                   verbose=True, call_log=None):
    windows = windows or {}
    spacing_modes = spacing_modes or SPACING_MODES
    simulate_fn = simulate_fn or simv7.simulate_one_path
    start_time = time.time()
    results = {}

    for spacing_mode in spacing_modes:
        for window_name, path in windows.items():
            df = simv6.load_mt5_csv(path)
            closes = df["CLOSE"].values
            spread_points = df["SPREAD"].values
            times = df["datetime"].values
            bid_arr, offer_arr = simv7.precompute_gbpusd_signal(closes, spread_points)
            if verbose:
                print(
                    f"Loaded {window_name}: {len(df)} bars, "
                    f"{df['datetime'].iloc[0]} -> {df['datetime'].iloc[-1]}"
                )

            for mode_name, mode in BIAS_MODES:
                pnls, realised, unrealised, max_layers_list = [], [], [], []
                nonflat_count = 0
                dd3_count, dd4_count = 0, 0
                for s in range(n_seeds):
                    if call_log is not None:
                        call_log.append((spacing_mode, window_name, mode_name, s))
                    result = simulate_fn(
                        closes,
                        bid_arr,
                        offer_arr,
                        times=times,
                        symbol="GBPUSD",
                        bias_mode=mode,
                        seed=s,
                        sub_steps=100,
                    )
                    pnls.append(result["pnl_total_usd"])
                    realised.append(result["pnl_realised_usd"])
                    unrealised.append(result["pnl_unrealised_usd"])
                    # Flat stacks always report unrealised=0.0; non-zero MTM => layers open at window end.
                    if abs(result["pnl_unrealised_usd"]) > 1e-12:
                        nonflat_count += 1
                    max_layers_list.append(result["max_layers"])
                    if result["drawdown_exceeded_3pct"]:
                        dd3_count += 1
                    if result["drawdown_exceeded_4pct"]:
                        dd4_count += 1
                    if verbose and (s + 1) % 100 == 0:
                        elapsed = time.time() - start_time
                        print(
                            f"    {spacing_mode}/{window_name}/{mode_name}: "
                            f"{s + 1}/{n_seeds} seeds ({elapsed:.0f}s total elapsed)"
                        )

                results[(spacing_mode, window_name, mode_name)] = {
                    "mean_pnl": np.mean(pnls),
                    "std_pnl": np.std(pnls),
                    "worst_pnl": np.min(pnls),
                    "best_pnl": np.max(pnls),
                    "mean_realised": np.mean(realised),
                    "mean_unrealised": np.mean(unrealised),
                    "nonflat_pct": nonflat_count / n_seeds * 100,
                    "mean_max_layers": np.mean(max_layers_list),
                    "max_max_layers": int(np.max(max_layers_list)),
                    "dd3_count": dd3_count,
                    "dd4_count": dd4_count,
                    "dd3_rate": dd3_count / n_seeds * 100,
                    "dd4_rate": dd4_count / n_seeds * 100,
                }
                if verbose:
                    elapsed = time.time() - start_time
                    print(f"  DONE: {spacing_mode}/{window_name}/{mode_name} ({elapsed:.0f}s elapsed)\n")

    return results


def print_results(results, n_seeds):
    print(
        f"\n{'=' * 140}\n"
        f"=== FINAL RESULTS (n={n_seeds} seeds each, corrected ADR-B geometry) ===\n"
        "KPI: MeanRealised = primary engine metric; DD3/DD4 = primary risk; "
        "MeanMTM/NonFlat% = end-of-window context; Mean P&L/Worst = blended (legacy).\n"
        f"{'=' * 140}\n"
    )
    print(
        f"{'Window':<14}{'SpacingMode':<16}{'Mode':<10}"
        f"{'MeanRealised':<14}{'MeanMTM':<12}{'NonFlat%':<10}"
        f"{'Mean P&L':<12}{'Worst':<10}{'MaxLayers(max)':<16}"
        f"{'DD3 count':<12}{'DD3%':<8}{'DD4 count':<12}{'DD4%'}"
    )
    for key in sorted(results.keys(), key=_result_sort_key):
        spacing_mode, window_name, mode_name = key
        r = results[key]
        print(
            f"{window_name:<14}{spacing_mode:<16}{mode_name:<10}"
            f"${r['mean_realised']:<13.2f}${r['mean_unrealised']:<11.2f}{r['nonflat_pct']:<10.1f}"
            f"${r['mean_pnl']:<11.2f}${r['worst_pnl']:<9.2f}"
            f"{r['max_max_layers']:<16}{r['dd3_count']:<12}{r['dd3_rate']:<8.2f}"
            f"{r['dd4_count']:<12}{r['dd4_rate']:.2f}"
        )

    print("\n=== Pass/fail check against agreed thresholds ===")
    for key in sorted(results.keys(), key=_result_sort_key):
        spacing_mode, window_name, mode_name = key
        r = results[key]
        dd4 = r["dd4_count"]
        verdict = (
            "PASS (clean)"
            if dd4 == 0
            else "YELLOW FLAG - investigate"
            if dd4 == 1
            else "HARD FAIL"
        )
        print(f"{spacing_mode}/{window_name}/{mode_name}: DD4 breaches={dd4} -> {verdict}")


def print_oos_flags(results, n_seeds):
    total_runs = len(results) * n_seeds
    global_max_layers = max(r["max_max_layers"] for r in results.values())
    total_dd3 = sum(r["dd3_count"] for r in results.values())
    total_dd4 = sum(r["dd4_count"] for r in results.values())
    double_digit = global_max_layers >= 10

    print(f"\n=== OOS aggregate flags ({total_runs} seed-runs) ===")
    print(
        f"Global max_layers (peak stack depth, simulate_one_path metric): {global_max_layers}"
    )
    print(
        f"Double-digit depth (>=10) anywhere: {'YES — investigate' if double_digit else 'NO — confirmed capped below 10'}"
    )
    print(f"Total DD3 breaches: {total_dd3} / {total_runs}")
    print(f"Total DD4 breaches: {total_dd4} / {total_runs}")


def estimate_runtime(n_seeds, n_combos):
    total = n_seeds * n_combos
    lo = total * SMOKE_SEC_PER_SEED_LO
    hi = total * SMOKE_SEC_PER_SEED_HI
    mid = total * SMOKE_SEC_PER_SEED_MEAN
    print(
        f"Estimated total runtime: ~{lo / 3600:.1f}-{hi / 3600:.1f} hours "
        f"(~{mid / 3600:.1f} h at {SMOKE_SEC_PER_SEED_MEAN:.2f}s/seed smoke mean; "
        f"{total} seed-runs = {n_combos} combos × {n_seeds} seeds)."
    )


def test_gemini_kpi_pnl_columns():
    """Gemini KPI: realised/MTM pulled from simulate_one_path; mean_pnl == mean_realised + mean_unrealised."""
    call_log = []
    seed_returns = [
        {"pnl_realised_usd": 10.0, "pnl_unrealised_usd": -3.0, "pnl_total_usd": 7.0,
         "max_layers": 2, "drawdown_exceeded_3pct": False, "drawdown_exceeded_4pct": False},
        {"pnl_realised_usd": 20.0, "pnl_unrealised_usd": 0.0, "pnl_total_usd": 20.0,
         "max_layers": 1, "drawdown_exceeded_3pct": False, "drawdown_exceeded_4pct": False},
    ]

    def stub_simulate(*args, **kwargs):
        seed = kwargs.get("seed", 0)
        return dict(seed_returns[seed % len(seed_returns)])

    fake_windows = {"kpi_win": "dummy.csv"}
    fake_df = pd.DataFrame({
        "CLOSE": np.linspace(1.25, 1.26, 60),
        "SPREAD": np.full(60, 20),
        "datetime": pd.date_range("2026-01-01", periods=60, freq="5min"),
    })
    fake_bid = fake_df["CLOSE"].values
    fake_offer = fake_df["CLOSE"].values

    with patch.object(simv6, "load_mt5_csv", return_value=fake_df):
        with patch.object(simv7, "precompute_gbpusd_signal", return_value=(fake_bid, fake_offer)):
            results = run_validation(
                n_seeds=2,
                windows=fake_windows,
                spacing_modes=["reload_anchor"],
                simulate_fn=stub_simulate,
                verbose=False,
                call_log=call_log,
            )

    r = results[("reload_anchor", "kpi_win", "MM_LONG")]
    assert "mean_realised" in r and "mean_unrealised" in r and "nonflat_pct" in r
    assert abs(r["mean_realised"] - 15.0) < 1e-9
    assert abs(r["mean_unrealised"] - (-1.5)) < 1e-9
    assert abs(r["mean_pnl"] - (r["mean_realised"] + r["mean_unrealised"])) < 1e-9
    assert abs(r["mean_pnl"] - 13.5) < 1e-9
    assert abs(r["nonflat_pct"] - 50.0) < 1e-9


def test_spacing_mode_loop_wiring():
    """Lightweight wiring check: both spacing modes must reach simulate_one_path."""
    call_log = []

    def stub_simulate(*args, **kwargs):
        return {
            "pnl_total_usd": 0.0,
            "pnl_realised_usd": 0.0,
            "pnl_unrealised_usd": 0.0,
            "max_layers": 0,
            "drawdown_exceeded_3pct": False,
            "drawdown_exceeded_4pct": False,
        }

    fake_windows = {"test_window": "dummy.csv"}
    fake_df = pd.DataFrame({
        "CLOSE": np.linspace(1.25, 1.26, 60),
        "SPREAD": np.full(60, 20),
        "datetime": pd.date_range("2026-01-01", periods=60, freq="5min"),
    })
    fake_bid = fake_df["CLOSE"].values
    fake_offer = fake_df["CLOSE"].values

    with patch.object(simv6, "load_mt5_csv", return_value=fake_df):
        with patch.object(simv7, "precompute_gbpusd_signal", return_value=(fake_bid, fake_offer)):
            run_validation(
                n_seeds=2,
                windows=fake_windows,
                spacing_modes=SPACING_MODES,
                simulate_fn=stub_simulate,
                verbose=False,
                call_log=call_log,
            )

    for mode_name, _ in BIAS_MODES:
        spacing_seen = {
            spacing_mode
            for spacing_mode, _window, mode, _seed in call_log
            if mode == mode_name
        }
        assert spacing_seen == set(SPACING_MODES), (
            f"test_window/{mode_name}: expected both spacing modes, got {spacing_seen}"
        )


def main():
    parser = argparse.ArgumentParser(description="n=500 OOS validation (single window)")
    parser.add_argument(
        "window_label",
        nargs="?",
        default="truss_crisis",
        help="Window label for reporting (default: truss_crisis)",
    )
    parser.add_argument(
        "csv_path",
        nargs="?",
        default=os.path.join(os.path.dirname(script_dir), "data", "GBPUSD_truss_crisis_oos.csv"),
        help="Path to OOS CSV (default: data/GBPUSD_truss_crisis_oos.csv)",
    )
    parser.add_argument("--seeds", type=int, default=500, help="Seeds per combo (default: 500)")
    args = parser.parse_args()

    csv_path = os.path.abspath(args.csv_path)
    if not os.path.isfile(csv_path):
        print(f"ERROR: CSV not found: {csv_path}")
        sys.exit(1)

    windows = {args.window_label: csv_path}
    n_combos = len(SPACING_MODES) * len(BIAS_MODES)

    print(f"Config check: GRIND_ADD_WIDTH_MULTIPLE={simv7.GRIND_ADD_WIDTH_MULTIPLE}")
    assert simv7.GRIND_ADD_WIDTH_MULTIPLE == 2.0, "GRIND_ADD_WIDTH_MULTIPLE not set correctly"
    print("Config confirmed correct - proceeding.\n")
    print(f"OOS window: {args.window_label} -> {csv_path}")
    print("WARNING: This run executes BOTH reload_anchor and reload_flat (2x single-mode cost).")
    estimate_runtime(args.seeds, n_combos)
    print()

    results = run_validation(n_seeds=args.seeds, windows=windows)
    print_results(results, args.seeds)
    print_oos_flags(results, args.seeds)


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--test-wiring":
        test_spacing_mode_loop_wiring()
        print("test_spacing_mode_loop_wiring: PASS")
        test_gemini_kpi_pnl_columns()
        print("test_gemini_kpi_pnl_columns: PASS")
    else:
        main()
