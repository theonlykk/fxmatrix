import importlib.util
import os
script_dir = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("simv6", os.path.join(script_dir, "grid_sim_v6_dynamic_spacing.py"))
simv6 = importlib.util.module_from_spec(spec)
spec.loader.exec_module(simv6)
import numpy as np

WINDOWS = {
    "1500bar_slice": None,  # handled specially below
    "full_quarter": r"D:\fxmatrix\data\GBPUSD_full_quarter.csv",
}

MODES = [("BUY_ONLY", simv6.SimMode.BUY_ONLY),
         ("SELL_ONLY", simv6.SimMode.SELL_ONLY),
         ("FLIPPING", simv6.SimMode.FLIPPING)]

df_full = simv6.load_mt5_csv(r"D:\fxmatrix\data\GBPUSD_full_quarter.csv")

for window_name in WINDOWS:
    if window_name == "1500bar_slice":
        df = df_full.iloc[:1500].reset_index(drop=True)
    else:
        df = df_full
    closes = df['CLOSE'].values
    highs = df['HIGH'].values
    lows = df['LOW'].values
    times = df['datetime'].values

    print(f"\n{'='*80}\n{window_name.upper()} ({len(closes)} bars)\n{'='*80}")

    for spacing_mode in ["exponential_no_reset", "reload_anchor"]:
        print(f"\n--- {spacing_mode} ---")
        for mode_name, mode in MODES:
            result, _, _, _ = simv6.simulate_one_path(
                closes, highs, lows, times, symbol="GBPUSD",
                mode=mode, spacing_mode=spacing_mode, seed=0, sub_steps=100)
            print(f"  {mode_name:<10} realized=${result['pnl_realised_usd']:>8.2f}  "
                  f"unrealized=${result['pnl_unrealised_usd']:>9.2f}  "
                  f"total=${result['pnl_total_usd']:>9.2f}  "
                  f"max_layers={result['max_layers']:<3} exits={result['total_exits']}")
