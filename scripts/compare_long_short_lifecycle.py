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

def trace_lifecycle(bias_mode, seed=0, max_events=30):
    """Instrumented version tracking every entry, add, exit, with layer count and flat/in-position state."""
    from grid_sim_v7_real_signal import (Layer, adr013_clamp, pips_to_price, ADD_PIPS_FLOOR,
                                            EXIT_PIPS, WIDEN_RATIO, ADD_PIPS_CEILING)
    rng = np.random.default_rng(seed)
    n_bars = len(closes) - 1
    sigma = np.std(np.diff(np.log(closes)), ddof=1) * 2.5
    spread_pips = simv6.PAIR_SPREAD_PIPS.get("GBPUSD", 0.5)
    exit_price_dist = pips_to_price(EXIT_PIPS)
    half_spread = pips_to_price(spread_pips/2.0)

    layers = []
    current_add_pips = ADD_PIPS_FLOOR
    last_exit_price = None
    events = []
    flat_periods = []
    flat_start = None
    price_current = closes[0]

    for i in range(n_bars):
        start_price = price_current
        end_price = closes[i+1]

        bar_start_quotes = None
        if not layers:
            bid_lvl, offer_lvl = bid_arr[i], offer_arr[i]
            if not (np.isnan(bid_lvl) or np.isnan(offer_lvl)):
                bid_c = adr013_clamp(bid_lvl, 1, start_price, half_spread)
                offer_c = adr013_clamp(offer_lvl, -1, start_price, half_spread)
                bar_start_quotes = (bid_c, offer_c)
            if flat_start is None:
                flat_start = i

        dt = 1.0/100
        t = np.linspace(0,1,101)
        dW = rng.normal(0, np.sqrt(dt), 100)
        W = np.zeros(101)
        W[1:] = np.cumsum(dW)
        bridge = W - t*W[-1]
        path = start_price + (end_price-start_price)*t + sigma*bridge

        for j in range(0, len(path)):
            mid_now = path[j]
            if not layers:
                if bar_start_quotes is not None:
                    bid_c, offer_c = bar_start_quotes
                    ask_now, bid_now = mid_now+half_spread, mid_now-half_spread
                    filled = None
                    if bias_mode in (simv7.BiasMode.LONG_ONLY, simv7.BiasMode.BOTH) and ask_now <= bid_c:
                        filled = (1, bid_c)
                    if bias_mode in (simv7.BiasMode.SHORT_ONLY, simv7.BiasMode.BOTH) and bid_now >= offer_c and filled is None:
                        filled = (-1, offer_c)
                    if filled is not None:
                        if flat_start is not None:
                            flat_periods.append(i - flat_start)
                            flat_start = None
                        d, p = filled
                        layers.append(Layer(entry_price=p, direction=d, exit_target_raw=p+d*exit_price_dist))
                        current_add_pips = ADD_PIPS_FLOOR
                        events.append((times[i], "ENTRY", d, p, len(layers)))
                continue
            if j == 0: continue
            price_prev, price_now = path[j-1], path[j]
            if layers:
                cur = layers[-1]
                eff_exit = cur.exit_target_raw + cur.direction*half_spread
                crossed = ((cur.direction==1 and price_prev<eff_exit<=price_now) or
                           (cur.direction==-1 and price_prev>eff_exit>=price_now))
                if crossed:
                    closed = layers.pop()
                    last_exit_price = closed.entry_price
                    events.append((times[i], "EXIT", closed.direction, cur.exit_target_raw, len(layers)))
                    if not layers:
                        flat_start = None  # will be set at next bar's top
            if layers:
                cur = layers[-1]
                if last_exit_price is not None:
                    depth_mult = WIDEN_RATIO ** (len(layers)//3)
                    reload_step = min(ADD_PIPS_CEILING, ADD_PIPS_FLOOR*depth_mult)
                    add_target = last_exit_price - cur.direction*pips_to_price(reload_step)
                else:
                    still_shallow = len(layers) < 3
                    add_pips = ADD_PIPS_FLOOR if still_shallow else current_add_pips
                    add_target = cur.entry_price - cur.direction*pips_to_price(add_pips)
                eff_add = add_target - cur.direction*half_spread
                hit = ((cur.direction==1 and price_prev>eff_add>=price_now) or
                       (cur.direction==-1 and price_prev<eff_add<=price_now))
                if hit:
                    layers.append(Layer(entry_price=add_target, direction=cur.direction,
                                          exit_target_raw=add_target+cur.direction*exit_price_dist))
                    last_exit_price = None
                    if len(layers)>=3:
                        current_add_pips = min(ADD_PIPS_CEILING, current_add_pips*WIDEN_RATIO)
                    events.append((times[i], "ADD", cur.direction, add_target, len(layers)))
        price_current = end_price
        if len(events) >= max_events:
            break

    return events, flat_periods

print("=== MM_LONG lifecycle (first 30 events) ===")
events_long, flat_long = trace_lifecycle(simv7.BiasMode.LONG_ONLY, seed=0)
for e in events_long:
    print(f"  {e[0]}  {e[1]:<6} dir={e[2]:+d}  price={e[3]:.5f}  layers={e[4]}")
print(f"\nFlat-period lengths (in bars) between entries: {flat_long[:20]}")
print(f"Mean flat period: {np.mean(flat_long):.1f} bars" if flat_long else "N/A")

print("\n\n=== MM_SHORT lifecycle (first 30 events) ===")
events_short, flat_short = trace_lifecycle(simv7.BiasMode.SHORT_ONLY, seed=0)
for e in events_short:
    print(f"  {e[0]}  {e[1]:<6} dir={e[2]:+d}  price={e[3]:.5f}  layers={e[4]}")
print(f"\nFlat-period lengths (in bars) between entries: {flat_short[:20]}")
print(f"Mean flat period: {np.mean(flat_short):.1f} bars" if flat_short else "N/A")
