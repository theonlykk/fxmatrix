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

def trace_events_with_pnl(spacing_mode, seed):
    """Returns a list of (timestamp, event_type, direction, price, layers_after, cumulative_realized_pnl)."""
    from grid_sim_v7_real_signal import (Layer, adr013_clamp, pips_to_price, ADD_PIPS_FLOOR,
                                            EXIT_PIPS, WIDEN_RATIO, ADD_PIPS_CEILING, USD_PER_PIP)
    POINT = 0.0001
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
    cum_pnl = 0.0
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
                    bid_now = mid_now - half_spread
                    if bid_now >= offer_c:  # SHORT_ONLY
                        layers.append(Layer(entry_price=offer_c, direction=-1, exit_target_raw=offer_c-exit_price_dist))
                        current_add_pips = ADD_PIPS_FLOOR
                        events.append((times[i], "ENTRY", -1, offer_c, 1, cum_pnl))
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
                    entry_paid = closed.entry_price + closed.direction*half_spread
                    exit_received = cur.exit_target_raw - closed.direction*half_spread
                    pnl_raw = (exit_received - entry_paid) * closed.direction
                    cum_pnl += (pnl_raw/POINT)*USD_PER_PIP
                    events.append((times[i], "EXIT", closed.direction, cur.exit_target_raw, len(layers), cum_pnl))
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
                    events.append((times[i], "ADD", cur.direction, add_target, len(layers), cum_pnl))
        price_current = end_price

    return events

for seed_to_check, label in [(10, "worst reload_flat"), (16, "worst reload_anchor")]:
    events_anchor = trace_events_with_pnl("reload_anchor", seed_to_check)
    events_flat = trace_events_with_pnl("reload_flat", seed_to_check)

    print(f"\n{'='*90}\nSEED {seed_to_check} ({label})\n{'='*90}")
    print(f"reload_anchor: {len(events_anchor)} events, final cum_pnl (realized only) = ${events_anchor[-1][5]:.2f}" if events_anchor else "no events")
    print(f"reload_flat:   {len(events_flat)} events, final cum_pnl (realized only) = ${events_flat[-1][5]:.2f}" if events_flat else "no events")

    # Find where the two event sequences first differ in price (indicating divergence)
    divergence_idx = None
    for k in range(min(len(events_anchor), len(events_flat))):
        if abs(events_anchor[k][3] - events_flat[k][3]) > 1e-9:
            divergence_idx = k
            break

    if divergence_idx is None:
        print("Sequences identical throughout (no divergence found in overlapping events)")
        continue

    print(f"\nFirst divergence at event index {divergence_idx}:")
    print(f"  reload_anchor: {events_anchor[divergence_idx]}")
    print(f"  reload_flat:   {events_flat[divergence_idx]}")

    print(f"\n--- Events around divergence (index {max(0,divergence_idx-3)} to {divergence_idx+10}) ---")
    print("reload_anchor:")
    for e in events_anchor[max(0,divergence_idx-3):divergence_idx+10]:
        print(f"  {e[0]}  {e[1]:<7} dir={e[2]:+d}  price={e[3]:.5f}  layers={e[4]}  cum_pnl=${e[5]:.2f}")
    print("reload_flat:")
    for e in events_flat[max(0,divergence_idx-3):divergence_idx+10]:
        print(f"  {e[0]}  {e[1]:<7} dir={e[2]:+d}  price={e[3]:.5f}  layers={e[4]}  cum_pnl=${e[5]:.2f}")
