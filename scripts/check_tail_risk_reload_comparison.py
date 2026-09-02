import importlib.util
import os
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

for window_name, path in WINDOWS.items():
    df = simv6.load_mt5_csv(path)
    closes = df['CLOSE'].values
    spread_points = df['SPREAD'].values
    times = df['datetime'].values
    bid_arr, offer_arr = simv7.precompute_gbpusd_signal(closes, spread_points)

    print(f"\n{'='*80}\n{window_name.upper()}\n{'='*80}")

    for mode_name, mode in [("MM_LONG", simv7.BiasMode.LONG_ONLY),
                              ("MM_SHORT", simv7.BiasMode.SHORT_ONLY),
                              ("MM_BOTH", simv7.BiasMode.BOTH)]:
        for spacing_mode in ["reload_anchor", "reload_flat"]:
            pnls, max_layers_list = [], []
            for s in range(n_seeds):
                result = simv7.simulate_one_path(closes, bid_arr, offer_arr, times=times, symbol="GBPUSD",
                                                    bias_mode=mode, spacing_mode=spacing_mode,
                                                    seed=s, sub_steps=100)
                pnls.append(result["pnl_total_usd"])
                max_layers_list.append(result["max_layers"])

            print(f"{mode_name} / {spacing_mode}:")
            print(f"  max_layers across seeds: mean={np.mean(max_layers_list):.1f}, "
                  f"MAX={np.max(max_layers_list)}, per-seed: {max_layers_list}")
            print(f"  P&L across seeds: mean=${np.mean(pnls):.2f}, "
                  f"WORST=${np.min(pnls):.2f}, BEST=${np.max(pnls):.2f}")
        print()
