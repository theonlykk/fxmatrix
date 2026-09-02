import importlib.util
import os
script_dir = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("simv7", os.path.join(script_dir, "grid_sim_v7_real_signal.py"))
simv7 = importlib.util.module_from_spec(spec)
spec.loader.exec_module(simv7)
spec6 = importlib.util.spec_from_file_location("simv6", os.path.join(script_dir, "grid_sim_v6_dynamic_spacing.py"))
simv6 = importlib.util.module_from_spec(spec6)
spec6.loader.exec_module(simv6)
import numpy as np

df = simv6.load_mt5_csv(r"D:\fxmatrix\data\GBPUSD_full_quarter.csv")
closes = df['CLOSE'].values
spread_points = df['SPREAD'].values
times = df['datetime'].values

print(f"Real GBPUSD data: {len(closes)} bars, {times[0]} to {times[-1]}")

bid_arr, offer_arr = simv7.precompute_gbpusd_signal(closes, spread_points)
valid = ~np.isnan(bid_arr)
print(f"Valid signal bars (post-warmup): {valid.sum()} / {len(closes)}")

gaps_bid = (closes[valid] - bid_arr[valid]) * 10000
gaps_offer = (offer_arr[valid] - closes[valid]) * 10000
print(f"\nGap from price to bid_theoretical: mean={gaps_bid.mean():.1f} pips, "
      f"median={np.median(gaps_bid):.1f}, min={gaps_bid.min():.1f}, max={gaps_bid.max():.1f}")
print(f"Gap from price to offer_theoretical: mean={gaps_offer.mean():.1f} pips, "
      f"median={np.median(gaps_offer):.1f}, min={gaps_offer.min():.1f}, max={gaps_offer.max():.1f}")
print(f"\nFraction of bars where bid gap < 5 pips: {np.mean(gaps_bid < 5)*100:.1f}%")
print(f"Fraction of bars where offer gap < 5 pips: {np.mean(gaps_offer < 5)*100:.1f}%")

print("\n=== Running actual simulation on real data, all three bias modes ===")
for name, mode in [("MM_LONG", simv7.BiasMode.LONG_ONLY),
                     ("MM_SHORT", simv7.BiasMode.SHORT_ONLY),
                     ("MM_BOTH", simv7.BiasMode.BOTH)]:
    result = simv7.simulate_one_path(closes, bid_arr, offer_arr, times=times, symbol="GBPUSD",
                                       bias_mode=mode, spacing_mode="reload_anchor", seed=0, sub_steps=100)
    print(f"{name}: trades={result['total_trades']}, max_layers={result['max_layers']}, "
          f"P&L=${result['pnl_total_usd']:.2f}, realized=${result['pnl_realised_usd']:.2f}, "
          f"unrealized=${result['pnl_unrealised_usd']:.2f}")
