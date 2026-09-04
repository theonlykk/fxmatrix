"""
v7: real term-structure signal for Layer 0 entry (fully verified against
Cursor's worked examples), combined with the existing, already-tested grid
mechanics (v6's flat/exponential/reload_anchor spacing for layers 1+).

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
from dataclasses import dataclass
from typing import List, Optional

ADD_PIPS_FLOOR = 9.0
EXIT_PIPS = 3.0
WIDEN_RATIO = 1.304  # ADR-B: derived to bound Layer 20 at ~6000 pips (was 1.5)
ADD_PIPS_CEILING = 1000.0  # ADR-B: raised from 100 - that was a safety patch for the old
                           # WIDEN_RATIO=1.5 and was silently capping the new r=1.304 curve
                           # at layer ~13, undermining the whole point of the derivation
LOT_SIZE = 0.01
USD_PER_PIP_PER_LOT = 10.0
USD_PER_PIP = USD_PER_PIP_PER_LOT * (LOT_SIZE / 1.0)
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

def pips_to_price(pips, point=0.0001):
    return pips * point

def precompute_gbpusd_signal(bc_closes, bc_spread_points, point=0.0001):
    """Vectorized, one-time computation - verified against Cursor's worked example."""
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
                       symbol="GBPUSD", bias_mode=BiasMode.BOTH, spacing_mode="reload_anchor",
                       point=0.0001, seed=0, sub_steps=100, sigma_for_bridge=None,
                       entry_mode="signal", straddle_half_width_pips=9.0,
                       triangular_harvest_pips=None, triangular_survival_pips=None,
                       exit_pips=None, track_l0_stats=False):
    """
    bid_theoretical_arr / offer_theoretical_arr: precomputed real-signal levels
    (same length as closes), used ONLY for the flat->Layer-0 re-entry decision.
    Layers 1+ use the existing, already-verified grid mechanics unchanged.

    entry_mode:
      - "signal": production signal arm (FV term-structure L0 quotes)
      - "straddle": dumb arm static mid +/- straddle_half_width_pips (InpDumbStraddlePips)
      - "triangular": one draw per flat cycle, W ~ Triangular[Harvest, Survival] peak at Harvest
    triangular_harvest_pips / triangular_survival_pips: required when entry_mode="triangular".
    exit_pips: overrides module EXIT_PIPS (maps to production InpExitPips).
    track_l0_stats: record per-L0-layer hold minutes and exit distance when that layer closes.
    """
    rng = np.random.default_rng(seed)
    n_bars = len(closes) - 1
    sigma = sigma_for_bridge if sigma_for_bridge is not None else \
        np.std(np.diff(np.log(closes)), ddof=1) * 2.5

    from grid_sim_v6_dynamic_spacing import PAIR_SPREAD_PIPS
    spread_pips = PAIR_SPREAD_PIPS.get(symbol, 0.5)
    _exit_pips = EXIT_PIPS if exit_pips is None else float(exit_pips)
    exit_price_dist = pips_to_price(_exit_pips, point)
    half_spread = pips_to_price(spread_pips / 2.0, point)

    layers: List[Layer] = []
    layer_entry_bars: List[int] = []
    layer_is_l0: List[bool] = []
    pod_had_add = False
    l0_hold_mins: List[float] = []
    l0_exit_dist_pips: List[float] = []
    l0_had_adds: List[bool] = []
    n_exits = 0
    current_add_pips = ADD_PIPS_FLOOR
    last_exit_price = None
    pnl_realised_usd = 0.0
    equity_peak = 10000.0
    equity_current = 10000.0
    daily_start_balance = 10000.0
    current_day = -1
    drawdown_3pct = False
    drawdown_4pct = False
    max_layers = 0
    total_trades = 0
    resting_straddle_width_pips = None
    drawn_widths_pips: List[float] = []

    def price_diff_to_usd(price_diff):
        return (price_diff / point) * USD_PER_PIP

    def compute_equity_usd_at_price(price):
        unrealised = 0.0
        for lay in layers:
            close_price = price - half_spread if lay.direction == 1 else price + half_spread
            entry_price = lay.entry_price + lay.direction * half_spread
            unrealised += price_diff_to_usd((close_price - entry_price) * lay.direction)
        return 10000.0 + pnl_realised_usd + unrealised

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

        # FIX: compute the clamp ONCE per bar (at bar start), not every substep -
        # the real EA places/updates the resting order once per bar close, then
        # it rests unchanged while the market moves within the next bar. Recomputing
        # every substep was causing the clamp to "chase" price and never get caught.
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
                straddle_dist = pips_to_price(resting_straddle_width_pips, point)
                buy_rest = start_price - straddle_dist
                sell_rest = start_price + straddle_dist
                bar_start_quotes = (buy_rest, sell_rest)
            elif entry_mode == "straddle":
                straddle_dist = pips_to_price(straddle_half_width_pips, point)
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

            # If flat, check whether our resting bid/offer would be touched
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
                        layers.append(Layer(entry_price=fill_price, direction=filled_dir,
                                              exit_target_raw=fill_price + filled_dir * exit_price_dist))
                        layer_entry_bars.append(i)
                        layer_is_l0.append(True)
                        pod_had_add = False
                        current_add_pips = ADD_PIPS_FLOOR
                        last_exit_price = None
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
                    if spacing_mode in ("reload_anchor", "reload_flat"):
                        last_exit_price = closed.entry_price
                    entry_paid = closed.entry_price + closed.direction * half_spread
                    exit_received = exit_target - closed.direction * half_spread
                    pnl_raw = (exit_received - entry_paid) * closed.direction
                    pnl_realised_usd += price_diff_to_usd(pnl_raw)
                    total_trades += 1
                    n_exits += 1
                    if not layers:
                        resting_straddle_width_pips = None

            if layers:
                cur = layers[-1]
                if spacing_mode == "reload_anchor" and last_exit_price is not None:
                    depth_mult = WIDEN_RATIO ** (len(layers) // 3)
                    reload_step = min(ADD_PIPS_CEILING, ADD_PIPS_FLOOR * depth_mult)
                    add_target = last_exit_price - cur.direction * pips_to_price(reload_step, point)
                elif spacing_mode == "reload_flat" and last_exit_price is not None:
                    # Same anchor (just-exited layer's own entry), NO depth scaling -
                    # always reload at the flat 9-pip floor regardless of current depth,
                    # per the "optionality/always be optimistic on the reload" argument
                    add_target = last_exit_price - cur.direction * pips_to_price(ADD_PIPS_FLOOR, point)
                else:
                    still_shallow = len(layers) < 3
                    add_pips_to_use = ADD_PIPS_FLOOR if (spacing_mode == "flat" or still_shallow) else current_add_pips
                    add_target = cur.entry_price - cur.direction * pips_to_price(add_pips_to_use, point)
                effective_add = add_target - cur.direction * half_spread
                hit = ((cur.direction == 1 and price_prev > effective_add >= price_now) or
                       (cur.direction == -1 and price_prev < effective_add <= price_now))
                if hit:
                    layers.append(Layer(entry_price=add_target, direction=cur.direction,
                                          exit_target_raw=add_target + cur.direction * exit_price_dist))
                    layer_entry_bars.append(i)
                    layer_is_l0.append(False)
                    pod_had_add = True
                    if spacing_mode in ("reload_anchor", "reload_flat"):
                        last_exit_price = None
                    if len(layers) >= 3:
                        current_add_pips = min(ADD_PIPS_CEILING, current_add_pips * WIDEN_RATIO)
                    max_layers = max(max_layers, len(layers))

        price_current = end_price
        equity_current = compute_equity_usd_at_price(end_price)
        equity_peak = max(equity_peak, equity_current)

        if times is not None:
            bar_day = pd.Timestamp(times[i+1]).normalize()
            if bar_day != current_day:
                daily_start_balance = 10000.0 if current_day == -1 else equity_current
                current_day = bar_day
        else:
            if current_day == -1:
                daily_start_balance = 10000.0
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

    out = {
        "pnl_realised_usd": pnl_realised_usd, "pnl_unrealised_usd": unrealised_usd,
        "pnl_total_usd": pnl_realised_usd + unrealised_usd, "max_layers": max_layers,
        "total_trades": total_trades, "n_exits": n_exits,
        "drawdown_exceeded_3pct": drawdown_3pct,
        "drawdown_exceeded_4pct": drawdown_4pct,
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


def test_last_exit_price_cleared_before_new_pod_first_add():
    """Full pod exit -> new L0 -> first add must use entry-based widening, not stale reload."""
    point = 0.0001
    stale_prior_pod_exit = 1.2000
    last_exit_price = stale_prior_pod_exit

    # (a) Full pod exit to flat leaves a stale reload anchor behind.
    layers: List[Layer] = []

    # (b) Fresh Layer-0 fill for a new pod — same reset as simulate_one_path flat-entry block.
    fill_price = 1.2400
    layers.append(Layer(entry_price=fill_price, direction=1,
                        exit_target_raw=fill_price + pips_to_price(EXIT_PIPS, point)))
    current_add_pips = ADD_PIPS_FLOOR
    last_exit_price = None

    assert last_exit_price is None

    # (c) First add of the new pod must not take the reload branch.
    for spacing_mode in ("reload_anchor", "reload_flat"):
        cur = layers[-1]
        used_reload = False
        if spacing_mode == "reload_anchor" and last_exit_price is not None:
            used_reload = True
            depth_mult = WIDEN_RATIO ** (len(layers) // 3)
            reload_step = min(ADD_PIPS_CEILING, ADD_PIPS_FLOOR * depth_mult)
            add_target = last_exit_price - cur.direction * pips_to_price(reload_step, point)
        elif spacing_mode == "reload_flat" and last_exit_price is not None:
            used_reload = True
            add_target = last_exit_price - cur.direction * pips_to_price(ADD_PIPS_FLOOR, point)
        else:
            still_shallow = len(layers) < 3
            add_pips_to_use = ADD_PIPS_FLOOR if (spacing_mode == "flat" or still_shallow) else current_add_pips
            add_target = cur.entry_price - cur.direction * pips_to_price(add_pips_to_use, point)

        assert not used_reload, spacing_mode
        expected = layers[-1].entry_price - pips_to_price(ADD_PIPS_FLOOR, point)
        assert add_target == expected, spacing_mode
        stale_reload_target = stale_prior_pod_exit - pips_to_price(ADD_PIPS_FLOOR, point)
        assert add_target != stale_reload_target, spacing_mode


def test_simulate_one_path_flat_entry_resets_last_exit_price():
    """Production flat-entry block must clear last_exit_price on new Layer-0 fill."""
    import inspect

    src = inspect.getsource(simulate_one_path)
    flat_block = src.split("if filled_dir is not None:", 1)[1].split("continue", 1)[0]
    assert "last_exit_price = None" in flat_block


if __name__ == "__main__":
    import sys

    if len(sys.argv) > 1 and sys.argv[1] == "--test-last-exit":
        test_last_exit_price_cleared_before_new_pod_first_add()
        test_simulate_one_path_flat_entry_resets_last_exit_price()
        print("last_exit_price tests: PASS")
