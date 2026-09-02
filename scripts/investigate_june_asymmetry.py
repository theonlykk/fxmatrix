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
import pandas as pd

df = simv6.load_mt5_csv(r"D:\fxmatrix\data\GBPUSD_june_blowup.csv")
closes = df['CLOSE'].values
spread_points = df['SPREAD'].values
times = df['datetime'].values

bid_arr, offer_arr = simv7.precompute_gbpusd_signal(closes, spread_points)
valid = ~np.isnan(bid_arr)

gap_bid_pips = (closes - bid_arr) * 10000
gap_offer_pips = (offer_arr - closes) * 10000

print(f"June window: {times[0]} to {times[-1]}, {len(closes)} bars")
print(f"Price: starts {closes[0]:.5f}, ends {closes[-1]:.5f} "
      f"(net move: {(closes[-1]-closes[0])*10000:.1f} pips)\n")

print("=== Gap statistics over the whole window ===")
print(f"Bid gap:   mean={gap_bid_pips[valid].mean():.1f}, median={np.median(gap_bid_pips[valid]):.1f}, "
      f"min={gap_bid_pips[valid].min():.1f}, max={gap_bid_pips[valid].max():.1f}")
print(f"Offer gap: mean={gap_offer_pips[valid].mean():.1f}, median={np.median(gap_offer_pips[valid]):.1f}, "
      f"min={gap_offer_pips[valid].min():.1f}, max={gap_offer_pips[valid].max():.1f}")

print(f"\nFraction of bars bid gap < 5 pips: {np.mean(gap_bid_pips[valid]<5)*100:.1f}%")
print(f"Fraction of bars offer gap < 5 pips: {np.mean(gap_offer_pips[valid]<5)*100:.1f}%")

# Split into first half vs second half of the window to see if the asymmetry
# is stable throughout, or concentrated in a specific stretch
mid = len(closes)//2
print(f"\n=== First half of window ===")
print(f"Bid gap mean: {gap_bid_pips[valid][:mid][valid[:mid]].mean() if valid[:mid].any() else 'N/A':.1f}" 
      if valid[:mid].any() else "N/A")
first_half_valid = valid[:mid]
print(f"Bid gap mean (first half): {gap_bid_pips[:mid][first_half_valid].mean():.1f}")
print(f"Offer gap mean (first half): {gap_offer_pips[:mid][first_half_valid].mean():.1f}")

second_half_valid = valid[mid:]
print(f"\n=== Second half of window ===")
print(f"Bid gap mean (second half): {gap_bid_pips[mid:][second_half_valid].mean():.1f}")
print(f"Offer gap mean (second half): {gap_offer_pips[mid:][second_half_valid].mean():.1f}")

# Show the trajectory in 10 chunks to see the evolution over time
print(f"\n=== Gap trajectory over time (10 chunks) ===")
chunk_size = len(closes)//10
for c in range(10):
    start, end = c*chunk_size, min((c+1)*chunk_size, len(closes))
    chunk_valid = valid[start:end]
    if chunk_valid.any():
        bid_mean = gap_bid_pips[start:end][chunk_valid].mean()
        offer_mean = gap_offer_pips[start:end][chunk_valid].mean()
        price_chunk = closes[start:end].mean()
        print(f"  chunk {c} ({times[start]} to {times[end-1]}): "
              f"avg_price={price_chunk:.5f}, bid_gap={bid_mean:.1f}, offer_gap={offer_mean:.1f}")
