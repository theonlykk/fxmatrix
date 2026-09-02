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

print("=== Per-seed breakdown: FLIPPING vs BUY_ONLY vs SELL_ONLY, same seeds ===\n")
for s in range(50):
    r_buy, _, _ = simv5.simulate_one_path(closes, highs, lows, times, symbol="GBPUSD",
                                            mode=simv5.SimMode.BUY_ONLY, seed=s, sub_steps=100)
    r_sell, _, _ = simv5.simulate_one_path(closes, highs, lows, times, symbol="GBPUSD",
                                             mode=simv5.SimMode.SELL_ONLY, seed=s, sub_steps=100)
    r_flip, sig, _ = simv5.simulate_one_path(closes, highs, lows, times, symbol="GBPUSD",
                                                mode=simv5.SimMode.FLIPPING, seed=s, sub_steps=100,
                                                track_signals=True)
    buy_signals = sum(1 for _,d,_ in sig if d==1)
    sell_signals = sum(1 for _,d,_ in sig if d==-1)
    print(f"seed={s}: BUY_ONLY=${r_buy['pnl_total_usd']:.2f}  SELL_ONLY=${r_sell['pnl_total_usd']:.2f}  "
          f"FLIPPING=${r_flip['pnl_total_usd']:.2f}  (flip signals: {buy_signals} BUY / {sell_signals} SELL)")
