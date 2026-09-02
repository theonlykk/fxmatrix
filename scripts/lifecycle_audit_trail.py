import importlib.util
import os
script_dir = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("simv6", os.path.join(script_dir, "grid_sim_v6_dynamic_spacing.py"))
simv6 = importlib.util.module_from_spec(spec)
spec.loader.exec_module(simv6)
import numpy as np
import pandas as pd

ADD_PIPS_FLOOR = simv6.ADD_PIPS_FLOOR
EXIT_PIPS = simv6.EXIT_PIPS
WIDEN_RATIO = simv6.WIDEN_RATIO
ADD_PIPS_CEILING = simv6.ADD_PIPS_CEILING
LOT_SIZE = simv6.LOT_SIZE
PAIR_SPREAD_PIPS = simv6.PAIR_SPREAD_PIPS


def lifecycle_trace(closes, highs, lows, times, symbol="GBPUSD", mode=simv6.SimMode.BUY_ONLY,
                     spacing_mode="exponential_no_reset", point=0.0001, seed=0, sub_steps=100,
                     n_trades_to_show=4):
    """
    Instrumented walkthrough producing one row per trade event: the quote
    that led to it (bid/ask being worked), the trade itself, resulting
    state, and the new quote that follows.
    """
    rng = np.random.default_rng(seed)
    n_bars = len(closes) - 1
    sigma = simv6.parkinson_sigma(highs, lows) * closes.mean()
    spread_pips = PAIR_SPREAD_PIPS.get(symbol, 0.5)
    exit_price_dist = simv6.pips_to_price(EXIT_PIPS, point)
    half_spread = simv6.pips_to_price(spread_pips / 2.0, point)

    layers = []
    current_add_pips = ADD_PIPS_FLOOR
    last_exit_price = None
    rows = []

    def get_signal(bar_idx):
        if mode == simv6.SimMode.BUY_ONLY: return 1
        if mode == simv6.SimMode.SELL_ONLY: return -1
        if bar_idx < 4: return 1
        return 1 if closes[bar_idx] >= np.mean(closes[bar_idx-4:bar_idx+1]) else -1

    def current_quotes():
        """Returns (bid_worked, ask_worked, add_target, exit_target) for the current top layer."""
        if not layers:
            return None, None, None, None
        cur = layers[-1]
        # Exit target (this layer's own)
        exit_target = cur.exit_target_raw
        # Add target (depends on spacing_mode state)
        if spacing_mode == "reload_anchor" and last_exit_price is not None:
            depth_mult = WIDEN_RATIO ** (len(layers) // 3)
            reload_step = min(ADD_PIPS_CEILING, ADD_PIPS_FLOOR * depth_mult)
            add_target = last_exit_price - cur.direction * simv6.pips_to_price(reload_step, point)
        else:
            still_shallow = len(layers) < 3
            add_pips_to_use = ADD_PIPS_FLOOR if (spacing_mode == "flat" or still_shallow) else current_add_pips
            add_target = cur.entry_price - cur.direction * simv6.pips_to_price(add_pips_to_use, point)

        if cur.direction == 1:  # BUY-direction: add=our bid, exit=our ask
            return add_target, exit_target, add_target, exit_target
        else:  # SELL-direction: add=our ask, exit=our bid
            return exit_target, add_target, add_target, exit_target

    price_current = closes[0]
    trades_shown = 0

    for i in range(n_bars):
        if trades_shown >= n_trades_to_show:
            break
        start_price = price_current
        end_price = closes[i+1]

        if i > 0 and len(layers) == 0:
            direction = get_signal(i)
            ts_reentry = pd.Timestamp(times[i]) if times is not None else i
            layers.append(simv6.Layer(entry_price=start_price, direction=direction,
                                        exit_target_raw=start_price + direction * exit_price_dist))
            current_add_pips = ADD_PIPS_FLOOR
            bid_after, ask_after, _, _ = current_quotes()
            if trades_shown < n_trades_to_show:
                rows.append({
                    "datetime": ts_reentry, "bid_worked": None, "ask_worked": None,
                    "trade_dir": "BUY" if direction == 1 else "SELL",
                    "trade_price": start_price, "size": LOT_SIZE,
                    "running_total_size": LOT_SIZE * len(layers), "layer": 1,
                    "bid_worked_follow": bid_after, "ask_worked_follow": ask_after,
                    "pod_flat": False,
                })
                trades_shown += 1

        dt = 1.0 / sub_steps
        t = np.linspace(0, 1, sub_steps+1)
        dW = rng.normal(0, np.sqrt(dt), sub_steps)
        W = np.zeros(sub_steps+1)
        W[1:] = np.cumsum(dW)
        bridge = W - t * W[-1]
        path = start_price + (end_price - start_price) * t + sigma * bridge

        if i == 0:
            direction = get_signal(0)
            layers.append(simv6.Layer(entry_price=start_price, direction=direction,
                                        exit_target_raw=start_price + direction * exit_price_dist))
            bid_after0, ask_after0, _, _ = current_quotes()
            if trades_shown < n_trades_to_show:
                rows.append({
                    "datetime": pd.Timestamp(times[0]) if times is not None else 0,
                    "bid_worked": None, "ask_worked": None,
                    "trade_dir": "BUY" if direction == 1 else "SELL",
                    "trade_price": start_price, "size": LOT_SIZE,
                    "running_total_size": LOT_SIZE * len(layers), "layer": 1,
                    "bid_worked_follow": bid_after0, "ask_worked_follow": ask_after0,
                    "pod_flat": False,
                })
                trades_shown += 1

        for j in range(1, len(path)):
            if trades_shown >= n_trades_to_show:
                break
            price_prev, price_now = path[j-1], path[j]
            bid_before, ask_before, _, _ = current_quotes()
            ts = pd.Timestamp(times[i]) if times is not None else i

            # Check exit
            if layers:
                cur = layers[-1]
                exit_target = cur.exit_target_raw
                effective_exit = exit_target + cur.direction * half_spread
                crossed = ((cur.direction == 1 and price_prev < effective_exit <= price_now) or
                           (cur.direction == -1 and price_prev > effective_exit >= price_now))
                if crossed:
                    closed = layers.pop()
                    if spacing_mode == "reload_anchor":
                        last_exit_price = closed.entry_price
                    bid_after, ask_after, _, _ = current_quotes()
                    rows.append({
                        "datetime": ts, "bid_worked": bid_before, "ask_worked": ask_before,
                        "trade_dir": "SELL" if closed.direction == 1 else "BUY",
                        "trade_price": exit_target, "size": LOT_SIZE,
                        "running_total_size": LOT_SIZE * len(layers), "layer": len(layers) + 1,
                        "bid_worked_follow": bid_after, "ask_worked_follow": ask_after,
                        "pod_flat": len(layers) == 0,
                    })
                    trades_shown += 1
                    continue

            # Check add
            if layers:
                cur = layers[-1]
                if spacing_mode == "reload_anchor" and last_exit_price is not None:
                    depth_mult = WIDEN_RATIO ** (len(layers) // 3)
                    reload_step = min(ADD_PIPS_CEILING, ADD_PIPS_FLOOR * depth_mult)
                    add_target = last_exit_price - cur.direction * simv6.pips_to_price(reload_step, point)
                else:
                    still_shallow = len(layers) < 3
                    add_pips_to_use = ADD_PIPS_FLOOR if (spacing_mode == "flat" or still_shallow) else current_add_pips
                    add_target = cur.entry_price - cur.direction * simv6.pips_to_price(add_pips_to_use, point)
                effective_add = add_target - cur.direction * half_spread
                hit = ((cur.direction == 1 and price_prev > effective_add >= price_now) or
                       (cur.direction == -1 and price_prev < effective_add <= price_now))
                if hit:
                    layers.append(simv6.Layer(entry_price=add_target, direction=cur.direction,
                                                exit_target_raw=add_target + cur.direction * exit_price_dist))
                    if spacing_mode == "reload_anchor":
                        last_exit_price = None
                    if len(layers) >= 3:
                        current_add_pips = min(ADD_PIPS_CEILING, current_add_pips * WIDEN_RATIO)
                    bid_after, ask_after, _, _ = current_quotes()
                    rows.append({
                        "datetime": ts, "bid_worked": bid_before, "ask_worked": ask_before,
                        "trade_dir": "BUY" if cur.direction == 1 else "SELL",
                        "trade_price": add_target, "size": LOT_SIZE,
                        "running_total_size": LOT_SIZE * len(layers), "layer": len(layers),
                        "bid_worked_follow": bid_after, "ask_worked_follow": ask_after,
                        "pod_flat": False,
                    })
                    trades_shown += 1

        price_current = end_price

    return pd.DataFrame(rows)


# ============================================================
# Run for all 6 combinations: 2 spacing modes x 3 trade modes
# ============================================================
df = simv6.load_mt5_csv(r"D:\fxmatrix\data\GBPUSD_full_quarter.csv")
closes = df['CLOSE'].values
highs = df['HIGH'].values
lows = df['LOW'].values
times = df['datetime'].values

for spacing_mode in ["exponential_no_reset", "reload_anchor"]:
    for mode_name, mode in [("MM_LONG (BUY_ONLY)", simv6.SimMode.BUY_ONLY),
                              ("MM_SHORT (SELL_ONLY)", simv6.SimMode.SELL_ONLY),
                              ("MM_BOTH (FLIPPING)", simv6.SimMode.FLIPPING)]:
        print(f"\n{'='*100}\n{spacing_mode} - {mode_name}\n{'='*100}")
        trace_df = lifecycle_trace(closes, highs, lows, times, symbol="GBPUSD",
                                     mode=mode, spacing_mode=spacing_mode, seed=0, n_trades_to_show=4)
        pd.set_option('display.max_columns', None)
        pd.set_option('display.width', 200)
        pd.set_option('display.float_format', lambda x: f'{x:.5f}')
        print(trace_df.to_string(index=False))
