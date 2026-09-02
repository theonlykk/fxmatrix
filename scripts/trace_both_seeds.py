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

def trace_events(spacing_mode, seed):
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
                    if bid_now >= offer_c:  # SHORT_ONLY
                        if last_exit_price is not None:
                            events.append((times[i], "REENTER", -1, offer_c, 1))
                        else:
                            events.append((times[i], "ENTRY", -1, offer_c, 1))
                        layers.append(Layer(entry_price=offer_c, direction=-1, exit_target_raw=offer_c-exit_price_dist))
                        current_add_pips = ADD_PIPS_FLOOR
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
            if layers:
                cur = layers[-1]
                if spacing_mode == "reload_anchor" and last_exit_price is not None:
                    depth_mult = WIDEN_RATIO ** (len(layers)//3)
                    reload_step = min(ADD_PIPS_CEILING, ADD_PIPS_FLOOR*depth_mult)
                    add_target = last_exit_price - cur.direction*pips_to_price(reload_step)
                elif spacing_mode == "reload_flat" and last_exit_price is not None:
                    add_target = last_exit_price - cur.direction*pips_to_price(ADD_PIPS_FLOOR)
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

    final_price = closes[-1]
    return events, layers, final_price

for seed_to_check, label in [(10, "worst reload_flat"), (16, "worst reload_anchor")]:
    print(f"\n{'='*90}\nSEED {seed_to_check} ({label})\n{'='*90}")
    for mode in ["reload_anchor", "reload_flat"]:
        events, final_layers, final_price = trace_events(mode, seed_to_check)
        print(f"\n--- {mode} ---")
        for e in events:
            print(f"  {e[0]}  {e[1]:<8} dir={e[2]:+d}  price={e[3]:.5f}  layers_after={e[4]}")
        print(f"  Final: {len(final_layers)} layers still open, final price={final_price:.5f}")
