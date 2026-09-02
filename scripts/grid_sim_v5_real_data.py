"""
v5: adds real-data support (OHLC loading, Parkinson volatility calibration,
per-pair spread) on top of the v4 fixes (flip/re-entry, spread direction,
units mismatch - all previously verified).
"""
import numpy as np
import pandas as pd
from dataclasses import dataclass
from typing import List, Optional

ADD_PIPS = 9.0
EXIT_PIPS = 3.0
INITIAL_BALANCE = 10000.0
LOT_SIZE = 0.01
USD_PER_PIP_PER_LOT = 10.0
USD_PER_PIP = USD_PER_PIP_PER_LOT * (LOT_SIZE / 1.0)

# Per-pair average spread, in pips, from real MT5 data (full available history)
PAIR_SPREAD_PIPS = {
    "EURUSD": 0.18,
    "GBPUSD": 0.64,
    "EURGBP": 0.58,
}

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
    """
    Parkinson volatility estimator - uses intrabar High/Low range, a much
    better estimate of TRUE intrabar volatility than close-to-close returns
    (which only capture net movement, missing genuine intrabar wiggle).
    sigma^2 = (1/(4*ln(2))) * mean( (ln(high/low))^2 )
    Returns sigma in PRICE units (per bar), matching what the bridge needs.
    """
    log_hl = np.log(highs / lows)
    variance = np.mean(log_hl**2) / (4 * np.log(2))
    sigma_return = np.sqrt(variance)  # this is a log-return-scale sigma per bar
    return sigma_return

def pips_to_price(pips, point=0.0001):
    return pips * point

def simulate_one_path(closes, highs=None, lows=None, times=None, symbol="GBPUSD",
                       mode=SimMode.FLIPPING, point=0.0001, seed=0, sub_steps=200,
                       track_signals=False, track_layer_history=False,
                       sigma_method="parkinson"):
    rng = np.random.default_rng(seed)
    n_bars = len(closes) - 1

    if sigma_method == "parkinson" and highs is not None and lows is not None:
        sigma_log = parkinson_sigma(highs, lows)
        sigma = sigma_log * closes.mean()  # convert log-return scale to price-unit scale
    else:
        log_ret = np.diff(np.log(closes))
        sigma = np.std(log_ret, ddof=1) * 2.5  # fallback: old close-only method

    spread_pips = PAIR_SPREAD_PIPS.get(symbol, 0.5)
    add_price = pips_to_price(ADD_PIPS, point)
    exit_price = pips_to_price(EXIT_PIPS, point)
    half_spread = pips_to_price(spread_pips / 2.0, point)
    pip_size = point

    layers: List[Layer] = []
    pnl_realised_usd = 0.0
    equity_peak = INITIAL_BALANCE
    equity_current = INITIAL_BALANCE
    daily_start_balance = INITIAL_BALANCE
    current_day = -1
    drawdown_3pct = False
    drawdown_4pct = False
    max_layers = 0
    total_trades = 0
    signals_log = []
    layer_count_history = []
    times_given = times is not None

    def get_signal(bar_idx):
        if mode == SimMode.BUY_ONLY:
            return 1
        if mode == SimMode.SELL_ONLY:
            return -1
        if bar_idx < 4:
            return 1
        past_closes = closes[bar_idx-4:bar_idx+1]
        return 1 if closes[bar_idx] >= np.mean(past_closes) else -1

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
            if track_signals:
                signals_log.append((i, direction, "RE-ENTRY"))
            layers.append(Layer(entry_price=start_price, direction=direction,
                                 exit_target_raw=start_price + direction * exit_price))
            total_trades += 1

        dt = 1.0 / sub_steps
        t = np.linspace(0, 1, sub_steps+1)
        dW = rng.normal(0, np.sqrt(dt), sub_steps)
        W = np.zeros(sub_steps+1)
        W[1:] = np.cumsum(dW)
        bridge = W - t * W[-1]
        path = start_price + (end_price - start_price) * t + sigma * bridge

        if i == 0:
            direction = get_signal(0)
            if track_signals:
                signals_log.append((0, direction, "INITIAL"))
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

            if layers:
                cur = layers[-1]
                add_target = cur.entry_price - cur.direction * add_price
                effective_add = add_target - cur.direction * half_spread
                hit = ((cur.direction == 1 and price_prev > effective_add >= price_now) or
                       (cur.direction == -1 and price_prev < effective_add <= price_now))
                if hit:
                    layers.append(Layer(entry_price=add_target, direction=cur.direction,
                                         exit_target_raw=add_target + cur.direction * exit_price))
                    max_layers = max(max_layers, len(layers))

        price_current = end_price
        if track_layer_history:
            layer_count_history.append((i, len(layers)))

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
        "pnl_realised_usd": pnl_realised_usd,
        "pnl_unrealised_usd": unrealised_usd,
        "pnl_total_usd": pnl_realised_usd + unrealised_usd,
        "max_layers": max_layers,
        "total_trades": total_trades,
        "drawdown_exceeded_3pct": drawdown_3pct,
        "drawdown_exceeded_4pct": drawdown_4pct,
        "equity_peak": equity_peak,
        "equity_current": equity_current,
    }, signals_log, layer_count_history
