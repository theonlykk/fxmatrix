import importlib.util
import os
script_dir = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("simv5", os.path.join(script_dir, "grid_sim_v5_real_data.py"))
simv5 = importlib.util.module_from_spec(spec)
spec.loader.exec_module(simv5)
import numpy as np

df = simv5.load_mt5_csv(r"D:\fxmatrix\data\GBPUSD_full_quarter.csv")
closes = df['CLOSE'].values
highs = df['HIGH'].values
lows = df['LOW'].values
times = df['datetime'].values

n_seeds = 50
for mode_name, mode in [("BUY_ONLY", simv5.SimMode.BUY_ONLY),
                          ("SELL_ONLY", simv5.SimMode.SELL_ONLY),
                          ("FLIPPING", simv5.SimMode.FLIPPING)]:
    pnls = []
    for s in range(n_seeds):
        result, _, _ = simv5.simulate_one_path(closes, highs, lows, times, symbol="GBPUSD",
                                                 mode=mode, seed=s, sub_steps=100)
        pnls.append(result["pnl_total_usd"])
    print(f"{mode_name}: mean P&L over {n_seeds} random realizations of REAL GBPUSD full-quarter data "
          f"= ${np.mean(pnls):.2f} (range ${min(pnls):.2f} to ${max(pnls):.2f})")
