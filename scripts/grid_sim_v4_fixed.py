import numpy as np
from dataclasses import dataclass
from typing import List, Optional, Tuple

ADD_PIPS = 9.0
EXIT_PIPS = 3.0
SPREAD_PIPS = 0.4
TWITCH_FACTOR = 2.5
SUB_STEPS = 200
INITIAL_BALANCE = 10000.0

# FIX: proper dollar-per-pip conversion (was missing entirely - raw price
# differences were added directly to a dollar balance with no scaling)
LOT_SIZE = 0.01          # matches the real EA's BaseLotSize
USD_PER_PIP_PER_LOT = 10.0  # standard convention: $10/pip for a 1.0 lot (USD-quoted pairs)
USD_PER_PIP = USD_PER_PIP_PER_LOT * (LOT_SIZE / 1.0)  # = $0.10 per pip at 0.01 lot

class SimMode:
    BUY_ONLY = 1
    SELL_ONLY = 2
    FLIPPING = 3

@dataclass
class Layer:
    entry_price: float      # RAW mid-referenced price (spread NOT baked in here anymore)
    direction: int
    exit_target_raw: float = 0.0   # RAW mid-referenced exit level
    filled: bool = False

@dataclass
class SimulationResult:
    pnl_realised_usd: float = 0.0
    pnl_unrealised_usd: float = 0.0
    pnl_total_usd: float = 0.0
    max_layers: int = 0
    total_trades: int = 0
    drawdown_exceeded_3pct: bool = False
    drawdown_exceeded_4pct: bool = False
    equity_peak: float = INITIAL_BALANCE
    equity_current: float = INITIAL_BALANCE

def pips_to_price(pips, point=0.0001):
    return pips * point

def simulate_one_path(closes, times=None, mode=SimMode.FLIPPING, point=0.0001, seed=0,
                       twitch=TWITCH_FACTOR, sub_steps=SUB_STEPS,
                       track_signals=False, track_layer_history=False):
    rng = np.random.default_rng(seed)
    n_bars = len(closes) - 1
    log_ret = np.diff(np.log(closes))
    sigma = np.std(log_ret, ddof=1) * twitch

    add_price = pips_to_price(ADD_PIPS, point)
    exit_price = pips_to_price(EXIT_PIPS, point)
    half_spread = pips_to_price(SPREAD_PIPS / 2.0, point)
    pip_size = point  # FIX: point already IS 1 pip in this codebase's convention (0.0001 = 1 pip)

    layers: List[Layer] = []
    result = SimulationResult()
    daily_start_balance = INITIAL_BALANCE
    current_day = -1
    times_given = times is not None
    signals_log = []
    layer_count_history = []

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
        # FIX (Bug 4 - units mismatch): convert a raw price difference to USD
        pips = price_diff / pip_size
        return pips * USD_PER_PIP

    def compute_equity_usd_at_price(price):
        # FIX: exit at bid (BUY) / ask (SELL) - spread applied HERE, independently
        # of whatever price the layer's own target level sits at (see below)
        unrealised_usd = 0.0
        for lay in layers:
            close_price = price - half_spread if lay.direction == 1 else price + half_spread
            entry_price = lay.entry_price + lay.direction * half_spread  # ask(BUY)/bid(SELL) paid at entry
            unrealised_usd += price_diff_to_usd((close_price - entry_price) * lay.direction)
        return INITIAL_BALANCE + result.pnl_realised_usd + unrealised_usd

    price_current = closes[0]

    for i in range(n_bars):
        start_price = price_current
        end_price = closes[i+1]

        if i > 0 and len(layers) == 0:
            direction = get_signal(i)
            if track_signals:
                signals_log.append((i, direction, "RE-ENTRY"))
            # FIX (Bug 3): entry_price stored RAW (mid-referenced), spread applied
            # separately at the point of computing realized/unrealized P&L, not
            # baked into the stored price used to derive the exit target.
            new_layer = Layer(entry_price=start_price, direction=direction,
                               exit_target_raw=start_price + direction * exit_price, filled=True)
            layers.append(new_layer)
            result.total_trades += 1

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
            new_layer = Layer(entry_price=start_price, direction=direction,
                               exit_target_raw=start_price + direction * exit_price, filled=True)
            layers.append(new_layer)
            result.total_trades += 1
            if len(layers) > result.max_layers:
                result.max_layers = len(layers)

        for j in range(1, len(path)):
            price_prev = path[j-1]
            price_now = path[j]

            if layers:
                current_layer = layers[-1]
                exit_target = current_layer.exit_target_raw
                effective_exit = exit_target + current_layer.direction * half_spread
                crossed = ((current_layer.direction == 1 and price_prev < effective_exit <= price_now) or
                           (current_layer.direction == -1 and price_prev > effective_exit >= price_now))
                if crossed:
                    closed_layer = layers.pop()
                    # FIX (Bug 3): apply spread INDEPENDENTLY on both legs.
                    # BUY: pay ask on entry, receive bid on exit.
                    entry_paid = closed_layer.entry_price + closed_layer.direction * half_spread
                    exit_received = exit_target - closed_layer.direction * half_spread
                    pnl_raw = (exit_received - entry_paid) * closed_layer.direction
                    result.pnl_realised_usd += price_diff_to_usd(pnl_raw)
                    result.total_trades += 1

            if layers:
                current_layer = layers[-1]
                add_target = current_layer.entry_price - current_layer.direction * add_price
                effective_add = add_target - current_layer.direction * half_spread
                hit = ((current_layer.direction == 1 and price_prev > effective_add >= price_now) or
                       (current_layer.direction == -1 and price_prev < effective_add <= price_now))
                if hit:
                    new_layer = Layer(entry_price=add_target, direction=current_layer.direction,
                                       exit_target_raw=add_target + current_layer.direction * exit_price, filled=True)
                    layers.append(new_layer)
                    if len(layers) > result.max_layers:
                        result.max_layers = len(layers)

        price_current = end_price
        if track_layer_history:
            layer_count_history.append((i, len(layers)))

        equity = compute_equity_usd_at_price(end_price)
        result.equity_current = equity
        if equity > result.equity_peak:
            result.equity_peak = equity

        if times_given:
            bar_day = int(times[i+1]) // 86400
            if bar_day != current_day:
                daily_start_balance = INITIAL_BALANCE if current_day == -1 else equity
                current_day = bar_day
        else:
            if current_day == -1:
                daily_start_balance = INITIAL_BALANCE
                current_day = 0

        if daily_start_balance > 0:
            dd = (daily_start_balance - equity) / daily_start_balance
            if dd >= 0.04:
                result.drawdown_exceeded_4pct = True
            if dd >= 0.03:
                result.drawdown_exceeded_3pct = True

    final_price = closes[-1]
    unrealised_usd = 0.0
    for lay in layers:
        close_price = final_price - half_spread if lay.direction == 1 else final_price + half_spread
        entry_price = lay.entry_price + lay.direction * half_spread
        unrealised_usd += price_diff_to_usd((close_price - entry_price) * lay.direction)
    result.pnl_unrealised_usd = unrealised_usd
    result.pnl_total_usd = result.pnl_realised_usd + unrealised_usd

    return result, signals_log, layer_count_history
