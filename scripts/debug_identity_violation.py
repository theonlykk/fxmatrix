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

bid_arr, offer_arr = simv7.precompute_gbpusd_signal(closes, spread_points)
valid = ~np.isnan(bid_arr)

# Find every bar where the identity is violated (bid_theoretical > close - should be impossible)
violation_mask = valid & (bid_arr > closes)
n_violations = violation_mask.sum()
print(f"Total identity violations (bid_theoretical > close): {n_violations} / {valid.sum()}")

# Also check spread_points for anything unusual
print(f"\nSPREAD column stats: min={spread_points.min()}, max={spread_points.max()}, "
      f"any zero? {np.any(spread_points==0)}, any negative? {np.any(spread_points<0)}")

if n_violations > 0:
    first_idx = np.where(violation_mask)[0][0]
    i = first_idx
    print(f"\n=== First violation at index {i}, time={times[i]} ===")
    print(f"close[i] = {closes[i]:.6f}")
    print(f"bid_theoretical[i] = {bid_arr[i]:.6f}")
    print(f"Difference: {(bid_arr[i]-closes[i])*10000:.2f} pips")
    print(f"spread_points[i] = {spread_points[i]}")

    c6, c12, c48 = closes[i-6], closes[i-12], closes[i-48]
    fv_bc = 0.50*c6 + 0.30*c12 + 0.20*c48
    mean_bc = (c6+c12+c48)/3.0
    sigma_fv = np.sqrt(((c6-mean_bc)**2+(c12-mean_bc)**2+(c48-mean_bc)**2)/3.0)
    dynamic_hs = 0.0004 + sigma_fv*0.5
    half_spread = (spread_points[i]/10.0/2.0)*0.0001
    bc_now = closes[i] + half_spread
    r_bc = np.log(bc_now/fv_bc)
    bid_manual = fv_bc * np.exp(r_bc - dynamic_hs)

    print(f"\nManual recompute:")
    print(f"  c6={c6:.6f}, c12={c12:.6f}, c48={c48:.6f}")
    print(f"  fv_bc = {fv_bc:.6f}")
    print(f"  sigma_fv = {sigma_fv:.8f}")
    print(f"  dynamic_hs = {dynamic_hs:.8f}  (should ALWAYS be > 0)")
    print(f"  half_spread = {half_spread:.8f}")
    print(f"  r_bc = {r_bc:.8f}")
    print(f"  bid_manual = {bid_manual:.6f}  (function gave {bid_arr[i]:.6f})")
    print(f"  Do manual and function match? {np.isclose(bid_manual, bid_arr[i])}")
    print(f"\n  Identity check: bc_now * exp(-dynamic_hs) = {bc_now*np.exp(-dynamic_hs):.6f}")
    print(f"  bc_now = {bc_now:.6f}, close = {closes[i]:.6f}")
    print(f"  Is bid_manual < close? {bid_manual < closes[i]}  <- this MUST be true mathematically")

    # Check the 6 nearest violations to see if there's a pattern (e.g. weekend gap)
    print(f"\n=== Checking for a pattern - timestamps around all violations ===")
    viol_indices = np.where(violation_mask)[0][:10]
    for vi in viol_indices:
        print(f"  index={vi}, time={times[vi]}, gap={(bid_arr[vi]-closes[vi])*10000:.2f} pips")
