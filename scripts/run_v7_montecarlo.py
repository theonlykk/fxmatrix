import importlib.util
import os
import time
script_dir = os.path.dirname(os.path.abspath(__file__))
spec7 = importlib.util.spec_from_file_location("simv7", os.path.join(script_dir, "grid_sim_v7_real_signal.py"))
simv7 = importlib.util.module_from_spec(spec7)
spec7.loader.exec_module(simv7)
spec6 = importlib.util.spec_from_file_location("simv6", os.path.join(script_dir, "grid_sim_v6_dynamic_spacing.py"))
simv6 = importlib.util.module_from_spec(spec6)
spec6.loader.exec_module(simv6)
import numpy as np

WINDOWS = {
    "full_quarter": r"D:\fxmatrix\data\GBPUSD_full_quarter.csv",
    "june_blowup": r"D:\fxmatrix\data\GBPUSD_june_blowup.csv",
}

n_seeds = 20
start_time = time.time()
results = {}

for window_name, path in WINDOWS.items():
    df = simv6.load_mt5_csv(path)
    closes = df['CLOSE'].values
    spread_points = df['SPREAD'].values
    times = df['datetime'].values

    bid_arr, offer_arr = simv7.precompute_gbpusd_signal(closes, spread_points)

    for mode_name, mode in [("MM_LONG", simv7.BiasMode.LONG_ONLY),
                              ("MM_SHORT", simv7.BiasMode.SHORT_ONLY),
                              ("MM_BOTH", simv7.BiasMode.BOTH)]:
        pnls, max_layers_list, trades_list = [], [], []
        dd3, dd4 = 0, 0
        for s in range(n_seeds):
            result = simv7.simulate_one_path(closes, bid_arr, offer_arr, times=times, symbol="GBPUSD",
                                                bias_mode=mode, spacing_mode="reload_anchor",
                                                seed=s, sub_steps=100)
            pnls.append(result["pnl_total_usd"])
            max_layers_list.append(result["max_layers"])
            trades_list.append(result["total_trades"])
            if result["drawdown_exceeded_3pct"]: dd3 += 1
            if result["drawdown_exceeded_4pct"]: dd4 += 1

        results[(window_name, mode_name)] = {
            "mean_pnl": np.mean(pnls), "median_pnl": np.median(pnls),
            "std_pnl": np.std(pnls), "min_pnl": np.min(pnls), "max_pnl": np.max(pnls),
            "mean_max_layers": np.mean(max_layers_list), "mean_trades": np.mean(trades_list),
            "dd3_rate": dd3/n_seeds*100, "dd4_rate": dd4/n_seeds*100,
        }
        elapsed = time.time() - start_time
        print(f"  done: {window_name:<14}{mode_name:<10} ({elapsed:.0f}s elapsed)")

print(f"\n=== RESULTS (n={n_seeds} seeds each) ===\n")
print(f"{'Window':<14}{'Mode':<10}{'Mean P&L':<12}{'Std':<10}{'Min':<10}{'Max':<10}{'MeanLayers':<12}{'MeanTrades':<12}{'DD3%':<8}{'DD4%'}")
for (window_name, mode_name), r in results.items():
    print(f"{window_name:<14}{mode_name:<10}${r['mean_pnl']:<11.2f}${r['std_pnl']:<9.2f}"
          f"${r['min_pnl']:<9.2f}${r['max_pnl']:<9.2f}{r['mean_max_layers']:<12.1f}"
          f"{r['mean_trades']:<12.0f}{r['dd3_rate']:<8.1f}{r['dd4_rate']:.1f}")
