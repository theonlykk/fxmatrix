import importlib.util
import os
script_dir = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("simv6", os.path.join(script_dir, "grid_sim_v6_dynamic_spacing.py"))
simv6 = importlib.util.module_from_spec(spec)
spec.loader.exec_module(simv6)
import numpy as np
import pandas as pd

# Same 1500-bar slice as the walkthrough, checking realized vs unrealized split
df = simv6.load_mt5_csv(r"D:\fxmatrix\data\GBPUSD_full_quarter.csv")
slice_df = df.iloc[:1500].reset_index(drop=True)
closes = slice_df['CLOSE'].values
highs = slice_df['HIGH'].values
lows = slice_df['LOW'].values
times = slice_df['datetime'].values

print("=== Realized vs Unrealized breakdown, 1500-bar slice ===\n")
for spacing_mode in ["exponential_no_reset", "reload_anchor"]:
    result, _, _, _ = simv6.simulate_one_path(
        closes, highs, lows, times, symbol="GBPUSD", mode=simv6.SimMode.BUY_ONLY,
        spacing_mode=spacing_mode, seed=0, sub_steps=100)
    print(f"{spacing_mode}:")
    print(f"  Realized P&L:   ${result['pnl_realised_usd']:.2f}")
    print(f"  Unrealized P&L: ${result['pnl_unrealised_usd']:.2f}")
    print(f"  Total P&L:      ${result['pnl_total_usd']:.2f}")
    print(f"  Max layers reached: {result['max_layers']}, total exits: {result['total_exits']}")
    print()

# Also check the FULL quarter (not just the slice) for one representative seed,
# same breakdown - to see if this pattern holds at the longer window too
print("=== Same breakdown, FULL quarter (not just the slice), seed=0 ===\n")
df_full = simv6.load_mt5_csv(r"D:\fxmatrix\data\GBPUSD_full_quarter.csv")
closes_full = df_full['CLOSE'].values
highs_full = df_full['HIGH'].values
lows_full = df_full['LOW'].values
times_full = df_full['datetime'].values

for spacing_mode in ["exponential_no_reset", "reload_anchor"]:
    result, _, _, _ = simv6.simulate_one_path(
        closes_full, highs_full, lows_full, times_full, symbol="GBPUSD", mode=simv6.SimMode.BUY_ONLY,
        spacing_mode=spacing_mode, seed=0, sub_steps=100)
    print(f"{spacing_mode}:")
    print(f"  Realized P&L:   ${result['pnl_realised_usd']:.2f}")
    print(f"  Unrealized P&L: ${result['pnl_unrealised_usd']:.2f}")
    print(f"  Total P&L:      ${result['pnl_total_usd']:.2f}")
    print(f"  Max layers reached: {result['max_layers']}, total exits: {result['total_exits']}")
    print()
