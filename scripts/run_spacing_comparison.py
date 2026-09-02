import importlib.util
import os
script_dir = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("simv6", os.path.join(script_dir, "grid_sim_v6_dynamic_spacing.py"))
simv6 = importlib.util.module_from_spec(spec)
spec.loader.exec_module(simv6)
import numpy as np
import time

df = simv6.load_mt5_csv(r"D:\fxmatrix\data\GBPUSD_full_quarter.csv")
closes = df['CLOSE'].values
highs = df['HIGH'].values
lows = df['LOW'].values
times = df['datetime'].values

n_seeds = 30  # smaller run first given three spacing modes x three trade modes
print(f"Running {n_seeds} seeds across 3 spacing modes x 3 trade modes on REAL GBPUSD full-quarter data.\n")

start_time = time.time()
results = {}
for spacing_mode in ["flat", "exponential_no_reset", "halve_on_exit"]:
    for mode_name, mode in [("BUY_ONLY", simv6.SimMode.BUY_ONLY),
                              ("SELL_ONLY", simv6.SimMode.SELL_ONLY),
                              ("FLIPPING", simv6.SimMode.FLIPPING)]:
        pnls, max_layers_list, dd3, dd4 = [], [], 0, 0
        for s in range(n_seeds):
            result, _, _, _ = simv6.simulate_one_path(
                closes, highs, lows, times, symbol="GBPUSD",
                mode=mode, spacing_mode=spacing_mode, seed=s, sub_steps=100)
            pnls.append(result["pnl_total_usd"])
            max_layers_list.append(result["max_layers"])
            if result["drawdown_exceeded_3pct"]: dd3 += 1
            if result["drawdown_exceeded_4pct"]: dd4 += 1
        results[(spacing_mode, mode_name)] = {
            "mean_pnl": np.mean(pnls), "median_pnl": np.median(pnls),
            "mean_max_layers": np.mean(max_layers_list),
            "dd3_rate": dd3/n_seeds*100, "dd4_rate": dd4/n_seeds*100,
        }
        elapsed = time.time() - start_time
        print(f"  done: {spacing_mode:<22} {mode_name:<10} ({elapsed:.0f}s elapsed)")

print(f"\n=== RESULTS ===\n")
print(f"{'Spacing':<22}{'Mode':<10}{'Mean P&L':<12}{'Median P&L':<12}{'Mean MaxLayers':<16}{'DD3% rate':<10}{'DD4% rate'}")
for (spacing_mode, mode_name), r in results.items():
    print(f"{spacing_mode:<22}{mode_name:<10}${r['mean_pnl']:<11.2f}${r['median_pnl']:<11.2f}"
          f"{r['mean_max_layers']:<16.1f}{r['dd3_rate']:<10.1f}{r['dd4_rate']:.1f}")
