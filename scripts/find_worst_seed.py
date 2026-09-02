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

df = simv6.load_mt5_csv(r"D:\fxmatrix\data\GBPUSD_june_blowup.csv")
closes = df['CLOSE'].values
spread_points = df['SPREAD'].values
times = df['datetime'].values
bid_arr, offer_arr = simv7.precompute_gbpusd_signal(closes, spread_points)

n_seeds = 20
print("Per-seed P&L, MM_SHORT, both modes, june_blowup:\n")
print(f"{'seed':<6}{'reload_anchor':<16}{'reload_flat':<16}{'difference'}")
anchor_pnls = []
flat_pnls = []
for s in range(n_seeds):
    r_anchor = simv7.simulate_one_path(closes, bid_arr, offer_arr, times=times, symbol="GBPUSD",
                                          bias_mode=simv7.BiasMode.SHORT_ONLY, spacing_mode="reload_anchor",
                                          seed=s, sub_steps=100)
    r_flat = simv7.simulate_one_path(closes, bid_arr, offer_arr, times=times, symbol="GBPUSD",
                                        bias_mode=simv7.BiasMode.SHORT_ONLY, spacing_mode="reload_flat",
                                        seed=s, sub_steps=100)
    anchor_pnls.append(r_anchor['pnl_total_usd'])
    flat_pnls.append(r_flat['pnl_total_usd'])
    diff = r_flat['pnl_total_usd'] - r_anchor['pnl_total_usd']
    print(f"{s:<6}${r_anchor['pnl_total_usd']:<15.2f}${r_flat['pnl_total_usd']:<15.2f}${diff:+.2f}")

print(f"\nWorst reload_anchor seed: {np.argmin(anchor_pnls)} (${min(anchor_pnls):.2f})")
print(f"Worst reload_flat seed: {np.argmin(flat_pnls)} (${min(flat_pnls):.2f})")
print(f"-> {'SAME seed' if np.argmin(anchor_pnls)==np.argmin(flat_pnls) else 'DIFFERENT seeds - worth checking both'}")
