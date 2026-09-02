import importlib.util
import os
script_dir = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("simv6", os.path.join(script_dir, "grid_sim_v6_dynamic_spacing.py"))
simv6 = importlib.util.module_from_spec(spec)
spec.loader.exec_module(simv6)
import numpy as np
import pandas as pd

df = simv6.load_mt5_csv(r"D:\fxmatrix\data\GBPUSD_full_quarter.csv")

# Take a manageable, real slice - first 1500 bars of the real full quarter
# (~5 trading days), real prices, real volatility, real spread
slice_df = df.iloc[:1500].reset_index(drop=True)
closes = slice_df['CLOSE'].values
highs = slice_df['HIGH'].values
lows = slice_df['LOW'].values
times = slice_df['datetime'].values

print(f"Real GBPUSD slice: {times[0]} to {times[-1]}, "
      f"price range {closes.min():.5f}-{closes.max():.5f}\n")

def print_walkthrough(spacing_mode, seed=0):
    print(f"{'='*70}\n{spacing_mode.upper()} - detailed walkthrough\n{'='*70}")

    # Monkey-patch a verbose event log by re-implementing the loop with prints -
    # simplest reliable way to get real add/exit prices and timestamps directly.
    # We call simulate_one_path with track_spacing_history for the add side,
    # and separately reconstruct exits by re-running with a small patch.
    result, signals, layer_hist, spacing_hist = simv6.simulate_one_path(
        closes, highs, lows, times, symbol="GBPUSD", mode=simv6.SimMode.BUY_ONLY,
        spacing_mode=spacing_mode, seed=seed, sub_steps=100, track_spacing_history=True)

    print(f"Final: max_layers={result['max_layers']}, exits={result['total_exits']}, "
          f"P&L=${result['pnl_total_usd']:.2f}\n")

    print("Add events (bar_idx, layer_count_after, distance_pips_used):")
    for e in spacing_hist[:40]:  # first 40 events to keep this readable
        bar_idx, layer_count, dist = e
        ts = pd.Timestamp(times[min(bar_idx, len(times)-1)])
        price = closes[min(bar_idx, len(closes)-1)]
        print(f"  bar={bar_idx:<5} time={ts}  price={price:.5f}  "
              f"layers_after={layer_count:<3}  distance_used={dist:.2f} pips")
    if len(spacing_hist) > 40:
        print(f"  ... ({len(spacing_hist)-40} more events not shown)")
    print()

print_walkthrough("exponential_no_reset")
print_walkthrough("reload_anchor")
