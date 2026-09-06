"""
v7: real term-structure signal for Layer 0 entry (fully verified against
Cursor's worked examples), combined with fxgrind-parity grid adds for layers 1+:
fixed entry-anchored spacing at GRIND_ADD_WIDTH_MULTIPLE x straddle half-width.

Key mechanism, all verified:
- FV_combined_BC from bars 6/12/48 (weights 0.50/0.30/0.20)
- r_BC uses CURRENT close (production behavior, confirmed - not pure history)
- dynamic_hs = QuoteSpread + sigma_FV * SpreadMultiplier
- bid_theoretical = FV_combined_BC * exp(r_BC - dynamic_hs)  [always BUY side]
- offer_theoretical = FV_combined_BC * exp(r_BC + dynamic_hs)  [always SELL side]
- ADR-013 clamp: if bid_theoretical >= current_bid, clamp to (current_bid - min_dist)
                 if offer_theoretical <= current_ask, clamp to (current_ask + min_dist)
- MM_LONG: only works the bid side. MM_SHORT: only works the offer side.
  MM_BOTH: works both simultaneously, whichever fills first determines direction.
"""
import numpy as np
import pandas as pd
from dataclasses import dataclass, field
from typing import List, Optional, Sequence

import sim_costs

GRIND_ADD_WIDTH_MULTIPLE = 2.0
EXIT_PIPS = 3.0
LOT_SIZE = sim_costs.DEFAULT_LOT_SIZE
QUOTE_SPREAD = 0.0004
SPREAD_MULTIPLIER = 0.500
MIN_DIST = 0.00001  # disclosed assumption: 1 point, standing in for broker stops-level

class BiasMode:
    LONG_ONLY = 1
    SHORT_ONLY = 2
    BOTH = 3

@dataclass
class Layer:
    entry_price: float
    direction: int
    exit_target_raw: float = 0.0
    entry_commission_usd: float = 0.0


def pips_to_price(pips, symbol="GBPUSD"):
    return sim_costs.pips_to_price(pips, symbol)


def add_pips_from_width(straddle_half_width_pips: float) -> float:
    """Fixed add spacing: GRIND_ADD_WIDTH_MULTIPLE x straddle half-width (fxgrind parity)."""
    return GRIND_ADD_WIDTH_MULTIPLE * float(straddle_half_width_pips)


def compute_add_target(layers: List[Layer], add_pips: float, symbol: str = "GBPUSD") -> float:
    """Entry-anchored add from previous layer entry (mirrors ea/grind_pure.mqh + grind_engine.mqh)."""
    cur = layers[-1]
    return cur.entry_price - cur.direction * pips_to_price(add_pips, symbol)


def precompute_gbpusd_signal(bc_closes, bc_spread_points, symbol="GBPUSD"):
    """Vectorized, one-time computation - verified against Cursor's worked example."""
    point = sim_costs.get_pair_spec(symbol).point
    n = len(bc_closes)
    fv_bc = np.full(n, np.nan)
    sigma_fv_bc = np.full(n, np.nan)
    for i in range(48, n):
        c6, c12, c48 = bc_closes[i-6], bc_closes[i-12], bc_closes[i-48]
        fv_bc[i] = 0.50*c6 + 0.30*c12 + 0.20*c48
        mean_bc = (c6+c12+c48)/3.0
        sigma_fv_bc[i] = np.sqrt(((c6-mean_bc)**2+(c12-mean_bc)**2+(c48-mean_bc)**2)/3.0)

    half_spread_arr = (bc_spread_points/10.0/2.0)*point
    bc_now = bc_closes + half_spread_arr
    r_bc = np.log(bc_now / fv_bc)
    dynamic_hs = QUOTE_SPREAD + sigma_fv_bc * SPREAD_MULTIPLIER

    bid_theoretical = fv_bc * np.exp(r_bc - dynamic_hs)
    offer_theoretical = fv_bc * np.exp(r_bc + dynamic_hs)
    return bid_theoretical, offer_theoretical

def draw_triangular_width_pips(harvest_pips: float, survival_pips: float, rng) -> float:
    """Right-triangular on [Harvest, Survival], peak at Harvest. Inverse-CDF, no rejection."""
    u = float(rng.uniform(0.0, 1.0))
    w = survival_pips - (survival_pips - harvest_pips) * np.sqrt(u)
    return round(w * 10.0) / 10.0


def adr013_clamp(theoretical, direction, current_mid, half_spread, min_dist=MIN_DIST):
    """direction: 1=BUY (clamp vs bid), -1=SELL (clamp vs ask)"""
    current_bid = current_mid - half_spread
    current_ask = current_mid + half_spread
    if direction == 1:
        if theoretical >= current_bid:
            return min(theoretical, current_bid - min_dist)
        return theoretical
    else:
        if theoretical <= current_ask:
            return max(theoretical, current_ask + min_dist)
        return theoretical

def simulate_one_path(closes, bid_theoretical_arr, offer_theoretical_arr, times=None,
                       symbol="GBPUSD", bias_mode=BiasMode.BOTH,
                       seed=0, sub_steps=100, sigma_for_bridge=None,
                       entry_mode="signal", straddle_half_width_pips=9.0,
                       triangular_harvest_pips=None, triangular_survival_pips=None,
                       exit_pips=None, track_l0_stats=False,
                       gbpusd_closes: Sequence[float] | None = None,
                       conversion_rate: float | None = None,
                       initial_balance: float = sim_costs.DEFAULT_INITIAL_BALANCE,
                       max_daily_loss_usd: float | None = None,
                       max_total_loss_usd: float | None = None):
    """
    bid_theoretical_arr / offer_theoretical_arr: precomputed real-signal levels
    (same length as closes), used ONLY for the flat->Layer-0 re-entry decision.
    Layers 1+ use fixed entry-anchored adds at 2 x straddle half-width (fxgrind).

    gbpusd_closes: optional per-bar GBPUSD close series for EURGBP USD conversion.
    conversion_rate: constant GBPUSD when gbpusd_closes not supplied (required for EURGBP).
    """
    rng = np.random.default_rng(seed)
    n_bars = len(closes) - 1
    sigma = sigma_for_bridge if sigma_for_bridge is not None else \
        np.std(np.diff(np.log(closes)), ddof=1) * 2.5

    symbol = symbol.upper()
    pair_spec = sim_costs.get_pair_spec(symbol)
    point = pair_spec.point
    half_spread = sim_costs.half_spread_price(symbol)
    _exit_pips = EXIT_PIPS if exit_pips is None else float(exit_pips)
    exit_price_dist = pips_to_price(_exit_pips, symbol)
    entry_comm_leg = sim_costs.commission_per_leg_usd(LOT_SIZE)
    exit_comm_leg = entry_comm_leg

    conversion_policy = "native_usd"
    conversion_rate_used: float | None = None
    if pair_spec.quote_currency != "USD":
        if gbpusd_closes is not None:
            conversion_policy = "per_bar_gbpusd"
            conversion_rate_used = float(np.mean(gbpusd_closes))
        elif conversion_rate is not None:
            conversion_policy = "constant_gbpusd"
            conversion_rate_used = float(conversion_rate)
        else:
            raise ValueError(
                f"{symbol} simulation requires gbpusd_closes or conversion_rate"
            )

    def _rate_at(bar_idx: int) -> float | None:
        if pair_spec.quote_currency == "USD":
            return None
        if gbpusd_closes is not None:
            return float(gbpusd_closes[bar_idx])
        return conversion_rate_used

    layers: List[Layer] = []
    layer_entry_bars: List[int] = []
    layer_is_l0: List[bool] = []
    pod_had_add = False
    l0_hold_mins: List[float] = []
    l0_exit_dist_pips: List[float] = []
    l0_had_adds: List[bool] = []
    n_exits = 0
    pnl_realised_usd = 0.0
    equity_peak = initial_balance
    equity_current = initial_balance
    max_absolute_drawdown_usd = 0.0
    max_daily_equity_drawdown_usd = 0.0
    gate_a_daily_loss_breach = False
    gate_b_total_loss_breach = False
    peak_running = initial_balance
    prague_day = None
    day_start_equity = initial_balance
    if max_daily_loss_usd is None:
        max_daily_loss_usd = initial_balance * sim_costs.DEFAULT_MAX_DAILY_LOSS_FRAC
    if max_total_loss_usd is None:
        max_total_loss_usd = initial_balance * sim_costs.DEFAULT_MAX_TOTAL_LOSS_FRAC
    daily_start_balance = initial_balance
    current_day = -1
    drawdown_3pct = False
    drawdown_4pct = False
    max_layers = 0
    total_trades = 0
    resting_straddle_width_pips = None
    pod_half_width_pips: float | None = None
    drawn_widths_pips: List[float] = []
    def _unrealised_gross_and_comm(end_price: float, bar_idx: int) -> tuple[float, float]:
        unrealised = 0.0
        sunk_comm = 0.0
        rate = _rate_at(bar_idx)
        for lay in layers:
            # Mark at bid (long) or ask (short); entry is stored limit — no entry spread adjustment.
            mark_price = end_price - half_spread if lay.direction == 1 else end_price + half_spread
            unrealised += sim_costs.price_diff_to_usd(
                (mark_price - lay.entry_price) * lay.direction,
                symbol,
                LOT_SIZE,
                rate,
            )
            sunk_comm += lay.entry_commission_usd
        return unrealised - sunk_comm, sunk_comm

    def compute_equity_usd_at_price(price, bar_idx: int) -> float:
        unrealised, _ = _unrealised_gross_and_comm(price, bar_idx)
        return initial_balance + pnl_realised_usd + unrealised

    def try_enter_from_flat(bar_idx, mid_price):
        """Work the real-signal-derived resting order(s), per bias_mode."""
        bid_lvl = bid_theoretical_arr[bar_idx]
        offer_lvl = offer_theoretical_arr[bar_idx]
        if np.isnan(bid_lvl) or np.isnan(offer_lvl):
            return None  # still in the 48-bar warmup
        bid_clamped = adr013_clamp(bid_lvl, 1, mid_price, half_spread)
        offer_clamped = adr013_clamp(offer_lvl, -1, mid_price, half_spread)
        return bid_clamped, offer_clamped

    price_current = closes[0]
    prev_equity = initial_balance

    for i in range(n_bars):
        start_price = price_current
        end_price = closes[i+1]

        dt = 1.0 / sub_steps
        t = np.linspace(0, 1, sub_steps+1)
        dW = rng.normal(0, np.sqrt(dt), sub_steps)
        W = np.zeros(sub_steps+1)
        W[1:] = np.cumsum(dW)
        bridge = W - t * W[-1]
        path = start_price + (end_price - start_price) * t + sigma * bridge

        bar_start_quotes = None
        if not layers:
            if entry_mode == "triangular":
                if triangular_harvest_pips is None or triangular_survival_pips is None:
                    raise ValueError("triangular mode requires harvest and survival pips")
                if resting_straddle_width_pips is None:
                    resting_straddle_width_pips = draw_triangular_width_pips(
                        float(triangular_harvest_pips),
                        float(triangular_survival_pips),
                        rng,
                    )
                    drawn_widths_pips.append(resting_straddle_width_pips)
                straddle_dist = pips_to_price(resting_straddle_width_pips, symbol)
                buy_rest = start_price - straddle_dist
                sell_rest = start_price + straddle_dist
                bar_start_quotes = (buy_rest, sell_rest)
            elif entry_mode == "straddle":
                straddle_dist = pips_to_price(straddle_half_width_pips, symbol)
                buy_rest = start_price - straddle_dist
                sell_rest = start_price + straddle_dist
                bar_start_quotes = (buy_rest, sell_rest)
            else:
                bid_lvl = bid_theoretical_arr[i]
                offer_lvl = offer_theoretical_arr[i]
                if not (np.isnan(bid_lvl) or np.isnan(offer_lvl)):
                    bid_clamped_fixed = adr013_clamp(bid_lvl, 1, start_price, half_spread)
                    offer_clamped_fixed = adr013_clamp(offer_lvl, -1, start_price, half_spread)
                    bar_start_quotes = (bid_clamped_fixed, offer_clamped_fixed)

        for j in range(0, len(path)):
            mid_now = path[j]

            if not layers:
                if bar_start_quotes is not None:
                    bid_clamped, offer_clamped = bar_start_quotes
                    bid_ask_now = (mid_now - half_spread, mid_now + half_spread)
                    filled_dir = None
                    if bias_mode in (BiasMode.LONG_ONLY, BiasMode.BOTH) and bid_ask_now[1] <= bid_clamped:
                        filled_dir = 1
                        fill_price = bid_clamped
                    if bias_mode in (BiasMode.SHORT_ONLY, BiasMode.BOTH) and bid_ask_now[0] >= offer_clamped:
                        if filled_dir is None:
                            filled_dir = -1
                            fill_price = offer_clamped
                    if filled_dir is not None:
                        if entry_mode == "triangular" and resting_straddle_width_pips is not None:
                            pod_half_width_pips = resting_straddle_width_pips
                        elif entry_mode == "straddle":
                            pod_half_width_pips = float(straddle_half_width_pips)
                        else:
                            pod_half_width_pips = float(straddle_half_width_pips)
                        layers.append(Layer(
                            entry_price=fill_price,
                            direction=filled_dir,
                            exit_target_raw=fill_price + filled_dir * exit_price_dist,
                            entry_commission_usd=entry_comm_leg,
                        ))
                        pnl_realised_usd -= entry_comm_leg
                        layer_entry_bars.append(i)
                        layer_is_l0.append(True)
                        pod_had_add = False
                        total_trades += 1
                        max_layers = max(max_layers, 1)
                        resting_straddle_width_pips = None
                continue

            if j == 0:
                continue
            price_prev, price_now = path[j-1], path[j]

            if layers:
                cur = layers[-1]
                exit_target = cur.exit_target_raw
                effective_exit = exit_target + cur.direction * half_spread
                crossed = ((cur.direction == 1 and price_prev < effective_exit <= price_now) or
                           (cur.direction == -1 and price_prev > effective_exit >= price_now))
                if crossed:
                    closed = layers.pop()
                    was_l0 = layer_is_l0.pop()
                    entry_bar = layer_entry_bars.pop()
                    if track_l0_stats and was_l0:
                        hold_mins = (i - entry_bar + 1) * 5.0
                        l0_hold_mins.append(hold_mins)
                        ep = closed.entry_price
                        xp = closed.exit_target_raw
                        dist_pips = abs(xp - ep) / point
                        l0_exit_dist_pips.append(dist_pips)
                        l0_had_adds.append(pod_had_add)
                        pod_had_add = False
                    rate = _rate_at(i)
                    gross = sim_costs.price_diff_to_usd(
                        (closed.exit_target_raw - closed.entry_price) * closed.direction,
                        symbol,
                        LOT_SIZE,
                        rate,
                    )
                    pnl_realised_usd += gross - exit_comm_leg
                    total_trades += 1
                    n_exits += 1
                    if not layers:
                        resting_straddle_width_pips = None
                        pod_half_width_pips = None

            if layers:
                cur = layers[-1]
                add_pips = add_pips_from_width(pod_half_width_pips)
                add_target = compute_add_target(layers, add_pips, symbol)
                effective_add = add_target - cur.direction * half_spread
                hit = ((cur.direction == 1 and price_prev > effective_add >= price_now) or
                       (cur.direction == -1 and price_prev < effective_add <= price_now))
                if hit:
                    layers.append(Layer(
                        entry_price=add_target,
                        direction=cur.direction,
                        exit_target_raw=add_target + cur.direction * exit_price_dist,
                        entry_commission_usd=entry_comm_leg,
                    ))
                    pnl_realised_usd -= entry_comm_leg
                    layer_entry_bars.append(i)
                    layer_is_l0.append(False)
                    pod_had_add = True
                    max_layers = max(max_layers, len(layers))

        price_current = end_price
        equity_current = compute_equity_usd_at_price(end_price, i + 1)

        # Prague day roll for Gate A and legacy fractional DD (00:00 Europe/Prague)
        if times is not None:
            bar_prague = sim_costs.prague_calendar_day(times[i + 1])
            if prague_day is None:
                prague_day = bar_prague
                day_start_equity = initial_balance
            elif bar_prague != prague_day:
                prague_day = bar_prague
                day_start_equity = prev_equity
            daily_start_balance = day_start_equity
            current_day = bar_prague
        else:
            if current_day == -1:
                daily_start_balance = initial_balance
                current_day = 0
                day_start_equity = initial_balance
            daily_start_balance = day_start_equity

        equity_peak = max(equity_peak, equity_current)
        peak_running = max(peak_running, equity_current)
        abs_dd = peak_running - equity_current
        max_absolute_drawdown_usd = max(max_absolute_drawdown_usd, abs_dd)
        if abs_dd >= max_total_loss_usd:
            gate_b_total_loss_breach = True

        daily_dd_usd = day_start_equity - equity_current
        max_daily_equity_drawdown_usd = max(max_daily_equity_drawdown_usd, daily_dd_usd)
        if daily_dd_usd >= max_daily_loss_usd:
            gate_a_daily_loss_breach = True

        prev_equity = equity_current

        if daily_start_balance > 0:
            dd = (daily_start_balance - equity_current) / daily_start_balance
            if dd >= 0.04:
                drawdown_4pct = True
            if dd >= 0.03:
                drawdown_3pct = True

    final_price = closes[-1]
    unrealised_usd, _ = _unrealised_gross_and_comm(final_price, len(closes) - 1)

    out = {
        "pnl_realised_usd": pnl_realised_usd,
        "pnl_unrealised_usd": unrealised_usd,
        "pnl_total_usd": pnl_realised_usd + unrealised_usd,
        "max_layers": max_layers,
        "total_trades": total_trades,
        "n_exits": n_exits,
        "drawdown_exceeded_3pct": drawdown_3pct,
        "drawdown_exceeded_4pct": drawdown_4pct,
        "equity_peak": equity_peak,
        "max_absolute_drawdown_usd": max_absolute_drawdown_usd,
        "max_daily_equity_drawdown_usd": max_daily_equity_drawdown_usd,
        "gate_a_daily_loss_breach": gate_a_daily_loss_breach,
        "gate_b_total_loss_breach": gate_b_total_loss_breach,
        "conversion_policy": conversion_policy,
        "conversion_rate_used": conversion_rate_used,
        "initial_balance": initial_balance,
    }
    if track_l0_stats:
        out["l0_hold_mins"] = l0_hold_mins
        out["l0_exit_dist_pips"] = l0_exit_dist_pips
        out["l0_had_adds"] = l0_had_adds
    if entry_mode == "triangular" and drawn_widths_pips:
        out["mean_drawn_width_pips"] = float(np.mean(drawn_widths_pips))
        out["median_drawn_width_pips"] = float(np.median(drawn_widths_pips))
        out["n_width_draws"] = len(drawn_widths_pips)
    return out


if __name__ == "__main__":
    import sys

    if len(sys.argv) > 1 and sys.argv[1] == "--self-test":
        import importlib.util
        spec = importlib.util.spec_from_file_location("test_grid_add", "scripts/test_grid_add_mechanics.py")
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        raise SystemExit(0)
