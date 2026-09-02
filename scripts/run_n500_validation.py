import importlib.util
import os
script_dir = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("simv5", os.path.join(script_dir, "grid_sim_v5_real_data.py"))
simv5 = importlib.util.module_from_spec(spec)
spec.loader.exec_module(simv5)
import numpy as np
import time

df = simv5.load_mt5_csv(r"D:\fxmatrix\data\GBPUSD_full_quarter.csv")
closes = df['CLOSE'].values
highs = df['HIGH'].values
lows = df['LOW'].values
times = df['datetime'].values

n_seeds = 500
print(f"Running {n_seeds} seeds - this will take a while, printing progress every 50 seeds.\n")

results = {"BUY_ONLY": [], "SELL_ONLY": [], "FLIPPING": []}
signal_splits = []  # for FLIPPING: (buy_count, sell_count) per seed

start_time = time.time()
for s in range(n_seeds):
    for mode_name, mode in [("BUY_ONLY", simv5.SimMode.BUY_ONLY),
                              ("SELL_ONLY", simv5.SimMode.SELL_ONLY),
                              ("FLIPPING", simv5.SimMode.FLIPPING)]:
        track = (mode_name == "FLIPPING")
        result, sig, _ = simv5.simulate_one_path(closes, highs, lows, times, symbol="GBPUSD",
                                                    mode=mode, seed=s, sub_steps=100,
                                                    track_signals=track)
        results[mode_name].append(result["pnl_total_usd"])
        if track:
            buy_ct = sum(1 for _,d,_ in sig if d==1)
            sell_ct = sum(1 for _,d,_ in sig if d==-1)
            signal_splits.append((s, buy_ct, sell_ct))

    if (s+1) % 50 == 0:
        elapsed = time.time() - start_time
        print(f"  {s+1}/{n_seeds} seeds done ({elapsed:.0f}s elapsed, "
              f"~{elapsed/(s+1)*n_seeds:.0f}s total estimated)")

print(f"\n=== FINAL RESULTS, n={n_seeds} ===\n")
for mode_name, pnls in results.items():
    print(f"{mode_name}: mean=${np.mean(pnls):.2f}, median=${np.median(pnls):.2f}, "
          f"range=${min(pnls):.2f} to ${max(pnls):.2f}, std=${np.std(pnls):.2f}")

# Identify "stuck on losing side" seeds properly - FLIPPING result close to
# BUY_ONLY's range rather than SELL_ONLY's range
buy_range = (min(results["BUY_ONLY"]), max(results["BUY_ONLY"]))
stuck_count = sum(1 for f in results["FLIPPING"] if f < buy_range[1] * 1.5)  # generous threshold
p = stuck_count / n_seeds
se = np.sqrt(p*(1-p)/n_seeds)
ci_low, ci_high = max(0, p - 1.96*se), min(1, p + 1.96*se)

print(f"\n=== Tail risk estimate, n={n_seeds} ===")
print(f"Seeds landing in 'stuck on losing side' range: {stuck_count}/{n_seeds} = {p*100:.1f}%")
print(f"95% CI: [{ci_low*100:.1f}%, {ci_high*100:.1f}%]  (SE={se*100:.2f}%)")
print(f"(Compare to the n=50 estimate: 20% with CI [8.9%, 31.1%] - this should be much tighter)")
