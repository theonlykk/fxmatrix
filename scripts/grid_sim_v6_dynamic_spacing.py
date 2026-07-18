"""
v6: adds a dynamic add-spacing mechanism on top of v5 (real data, Parkinson
calibration, per-pair spread, all previously verified fixes intact).

Three spacing modes, selectable per run:
- "flat": current sim baseline, always 9 pips (unchanged from v5)
- "exponential_no_reset": proxy for the real EA's current GridExpBase
  behavior - each successive add (without an intervening exit) widens by
  a fixed ratio, never resets except when the stack goes fully flat
- "halve_on_exit": the new mechanism - starts tight (9 pips) on a fresh
  position; each add WITHOUT an intervening exit widens by the same ratio
  as exponential_no_reset; each EXIT halves the current add distance
  (floored at 9 pips)
"""
import numpy as np
import pandas as pd
from dataclasses import dataclass
from typing import List, Optional

ADD_PIPS_FLOOR = 9.0
EXIT_PIPS = 3.0
WIDEN_RATIO = 1.5  # matches the real EA's GridExpBase, used for widening in both non-flat modes
ADD_PIPS_CEILING = 100.0  # FIX: cap on widening - disclosed, arbitrary-but-reasonable choice,
                          # roughly 11x the floor; without this, unbounded widening recreates
                          # the exact GridExpBase exhaustion problem this mechanism aims to avoid
INITIAL_BALANCE = 10000.0
LOT_SIZE = 0.01
USD_PER_PIP_PER_LOT = 10.0
USD_PER_PIP = USD_PER_PIP_PER_LOT * (LOT_SIZE / 1.0)

PAIR_SPREAD_PIPS = {"EURUSD": 0.18, "GBPUSD": 0.64, "EURGBP": 0.58}

class SimMode:
    BUY_ONLY = 1
    SELL_ONLY = 2
    FLIPPING = 3

@dataclass
class Layer:
    entry_price: float
    direction: int
    exit_target_raw: float = 0.0

def load_mt5_csv(path):
    df = pd.read_csv(path)
    if 'datetime' not in df.columns:
        df['datetime'] = pd.to_datetime(df['DATE'] + ' ' + df['TIME'], format='%Y.%m.%d %H:%M:%S')
    else:
        df['datetime'] = pd.to_datetime(df['datetime'])
    return df.sort_values('datetime').reset_index(drop=True)

def parkinson_sigma(highs, lows):
    log_hl = np.log(highs / lows)
    variance = np.mean(log_hl**2) / (4 * np.log(2))
    return np.sqrt(variance)

def pips_to_price(pips, point=0.0001):
    return pips * point

def simulate_one_path(closes, highs=None, lows=None, times=None, symbol="GBPUSD",
                       mode=SimMode.FLIPPING, spacing_mode="flat",
                       point=0.0001, seed=0, sub_steps=100,
                       track_signals=False, track_layer_history=False,
                       track_spacing_history=False, sigma_method="parkinson"):
    rng = np.random.default_rng(seed)
    n_bars = len(closes) - 1

    if sigma_method == "parkinson" and highs is not None and lows is not None:
        sigma = parkinson_sigma(highs, lows) * closes.mean()
    else:
        sigma = np.std(np.diff(np.log(closes)), ddof=1) * 2.5

    spread_pips = PAIR_SPREAD_PIPS.get(symbol, 0.5)
    exit_price = pips_to_price(EXIT_PIPS, point)
    half_spread = pips_to_price(spread_pips / 2.0, point)
    pip_size = point

    layers: List[Layer] = []
    current_add_pips = ADD_PIPS_FLOOR  # dynamic state - only matters for non-flat modes
    bars_since_snap = None  # tracks time-decay for "snap_with_expiry" mode
    pre_exit_wide_pips = ADD_PIPS_FLOOR  # remembers the wide distance to revert to if the snap expires
    EXPIRY_BARS = 5  # disclosed default: tight re-entry window stays "live" for 5 bars (25 min)
    exits_since_successful_add = 0  # for "second_chance_only": counts exits since the last successful tight re-add
    last_exit_price = None  # for "reload_anchor": remembers the price of the most recently exited layer
    pnl_realised_usd = 0.0
    equity_peak = INITIAL_BALANCE
    equity_current = INITIAL_BALANCE
    daily_start_balance = INITIAL_BALANCE
    current_day = -1
    drawdown_3pct = False
    drawdown_4pct = False
    max_layers = 0
    total_trades = 0
    total_exits = 0
    signals_log = []
    layer_count_history = []
    spacing_history = []
    times_given = times is not None

    def get_signal(bar_idx):
        if mode == SimMode.BUY_ONLY: return 1
        if mode == SimMode.SELL_ONLY: return -1
        if bar_idx < 4: return 1
        return 1 if closes[bar_idx] >= np.mean(closes[bar_idx-4:bar_idx+1]) else -1

    def price_diff_to_usd(price_diff):
        return (price_diff / pip_size) * USD_PER_PIP

    def compute_equity_usd_at_price(price):
        unrealised = 0.0
        for lay in layers:
            close_price = price - half_spread if lay.direction == 1 else price + half_spread
            entry_price = lay.entry_price + lay.direction * half_spread
            unrealised += price_diff_to_usd((close_price - entry_price) * lay.direction)
        return INITIAL_BALANCE + pnl_realised_usd + unrealised

    price_current = closes[0]

    for i in range(n_bars):
        start_price = price_current
        end_price = closes[i+1]

        if i > 0 and len(layers) == 0:
            direction = get_signal(i)
            if track_signals: signals_log.append((i, direction, "RE-ENTRY"))
            layers.append(Layer(entry_price=start_price, direction=direction,
                                 exit_target_raw=start_price + direction * exit_price))
            total_trades += 1
            current_add_pips = ADD_PIPS_FLOOR  # fresh position always starts tight

        dt = 1.0 / sub_steps
        t = np.linspace(0, 1, sub_steps+1)
        dW = rng.normal(0, np.sqrt(dt), sub_steps)
        W = np.zeros(sub_steps+1)
        W[1:] = np.cumsum(dW)
        bridge = W - t * W[-1]
        path = start_price + (end_price - start_price) * t + sigma * bridge

        if i == 0:
            direction = get_signal(0)
            if track_signals: signals_log.append((0, direction, "INITIAL"))
            layers.append(Layer(entry_price=start_price, direction=direction,
                                 exit_target_raw=start_price + direction * exit_price))
            total_trades += 1
            max_layers = max(max_layers, len(layers))

        for j in range(1, len(path)):
            price_prev, price_now = path[j-1], path[j]

            if layers:
                cur = layers[-1]
                effective_exit = cur.exit_target_raw + cur.direction * half_spread
                crossed = ((cur.direction == 1 and price_prev < effective_exit <= price_now) or
                           (cur.direction == -1 and price_prev > effective_exit >= price_now))
                if crossed:
                    closed = layers.pop()
                    entry_paid = closed.entry_price + closed.direction * half_spread
                    exit_received = closed.exit_target_raw - closed.direction * half_spread
                    pnl_raw = (exit_received - entry_paid) * closed.direction
                    pnl_realised_usd += price_diff_to_usd(pnl_raw)
                    total_trades += 1
                    total_exits += 1
                    if spacing_mode == "reload_anchor":
                        last_exit_price = closed.entry_price  # anchor to the CLOSED layer's entry price (100), not its exit target (103) - per Khalid's explicit correction
                    if spacing_mode == "halve_on_exit":
                        current_add_pips = max(ADD_PIPS_FLOOR, current_add_pips / 2.0)
                    elif spacing_mode == "snap_with_expiry":
                        pre_exit_wide_pips = current_add_pips  # remember what we were widening toward
                        current_add_pips = ADD_PIPS_FLOOR       # full aggressive snap, per Khalid's proposal
                        bars_since_snap = 0                      # start the expiry clock
                    elif spacing_mode == "second_chance_only":
                        exits_since_successful_add += 1
                        if exits_since_successful_add == 1:
                            # First exit in a fresh stretch: give the benefit of the doubt
                            pre_exit_wide_pips = current_add_pips
                            current_add_pips = ADD_PIPS_FLOOR
                            bars_since_snap = 0
                        # else: second+ exit without an intervening successful add -
                        # decline the "third chance", leave current_add_pips untouched
                        # (falls through to normal widening behavior on the next add)

            if layers:
                cur = layers[-1]
                if spacing_mode == "reload_anchor" and last_exit_price is not None:
                    # Anchor the reload to the price that JUST exited (real evidence
                    # someone was selling/buying there), stepping out by a reload
                    # distance that scales with CURRENT depth - not consecutive-add
                    # history - as a separate, deliberate capital-preservation throttle.
                    depth_multiplier = WIDEN_RATIO ** (len(layers) // 3)
                    reload_step = min(ADD_PIPS_CEILING, ADD_PIPS_FLOOR * depth_multiplier)
                    add_target = last_exit_price - cur.direction * pips_to_price(reload_step, point)
                    add_pips_to_use = reload_step  # for logging clarity
                else:
                    still_shallow = len(layers) < 3  # first 2 adds (creating layers 1,2) stay flat
                    add_pips_to_use = ADD_PIPS_FLOOR if (spacing_mode == "flat" or still_shallow) else current_add_pips
                    add_price = pips_to_price(add_pips_to_use, point)
                    add_target = cur.entry_price - cur.direction * add_price
                effective_add = add_target - cur.direction * half_spread
                hit = ((cur.direction == 1 and price_prev > effective_add >= price_now) or
                       (cur.direction == -1 and price_prev < effective_add <= price_now))
                if hit:
                    layers.append(Layer(entry_price=add_target, direction=cur.direction,
                                         exit_target_raw=add_target + cur.direction * exit_price))
                    max_layers = max(max_layers, len(layers))
                    if spacing_mode == "reload_anchor":
                        last_exit_price = None  # the reload opportunity has been consumed
                    if spacing_mode in ("exponential_no_reset", "halve_on_exit", "snap_with_expiry", "second_chance_only", "reload_anchor") and len(layers) >= 3:
                        current_add_pips = min(ADD_PIPS_CEILING, current_add_pips * WIDEN_RATIO)
                    if spacing_mode in ("snap_with_expiry", "second_chance_only"):
                        bars_since_snap = None  # a successful add resets the expiry clock - no longer "waiting"
                    if spacing_mode == "second_chance_only":
                        exits_since_successful_add = 0  # back to normal - eligible for a fresh "first chance" next time
                    if track_spacing_history:
                        spacing_history.append((i, len(layers), add_pips_to_use))

        price_current = end_price
        if track_layer_history: layer_count_history.append((i, len(layers)))

        # Expiry check for snap_with_expiry: if the tight re-entry window has
        # gone stale (not filled within EXPIRY_BARS), abandon the "fresh range"
        # hypothesis and widen back out from wherever we would have been.
        if spacing_mode in ("snap_with_expiry", "second_chance_only") and bars_since_snap is not None:
            bars_since_snap += 1
            if bars_since_snap > EXPIRY_BARS:
                current_add_pips = min(ADD_PIPS_CEILING, pre_exit_wide_pips)
                bars_since_snap = None

        equity_current = compute_equity_usd_at_price(end_price)
        equity_peak = max(equity_peak, equity_current)

        if times_given:
            bar_day = pd.Timestamp(times[i+1]).normalize()
            if bar_day != current_day:
                daily_start_balance = INITIAL_BALANCE if current_day == -1 else equity_current
                current_day = bar_day
        else:
            if current_day == -1:
                daily_start_balance = INITIAL_BALANCE
                current_day = 0

        if daily_start_balance > 0:
            dd = (daily_start_balance - equity_current) / daily_start_balance
            if dd >= 0.04: drawdown_4pct = True
            if dd >= 0.03: drawdown_3pct = True

    final_price = closes[-1]
    unrealised_usd = 0.0
    for lay in layers:
        close_price = final_price - half_spread if lay.direction == 1 else final_price + half_spread
        entry_price = lay.entry_price + lay.direction * half_spread
        unrealised_usd += price_diff_to_usd((close_price - entry_price) * lay.direction)

    return {
        "pnl_realised_usd": pnl_realised_usd, "pnl_unrealised_usd": unrealised_usd,
        "pnl_total_usd": pnl_realised_usd + unrealised_usd, "max_layers": max_layers,
        "total_trades": total_trades, "total_exits": total_exits,
        "drawdown_exceeded_3pct": drawdown_3pct, "drawdown_exceeded_4pct": drawdown_4pct,
        "equity_peak": equity_peak, "equity_current": equity_current,
    }, signals_log, layer_count_history, spacing_history
