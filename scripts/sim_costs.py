"""
Central simulation cost and unit-conversion model for grid_sim v7 family.

Spread constants are used for FILL TIMING ONLY — never in P&L.
Commission defaults match FTMO-style USD account: 3.00 USD per lot per side.
"""
from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Mapping, Sequence

import numpy as np
import pandas as pd

# Default account / broker parameters
DEFAULT_LOT_SIZE = 0.01
DEFAULT_COMMISSION_USD_PER_LOT_PER_SIDE = 3.00
DEFAULT_INITIAL_BALANCE = 10_000.0
DEFAULT_MAX_DAILY_LOSS_FRAC = 0.05  # Gate A: 5% of initial
DEFAULT_MAX_TOTAL_LOSS_FRAC = 0.10  # Gate B: 10% of initial
PRAGUE_TZ = "Europe/Prague"

# Increment whenever cost semantics change (pip value, commission, spread-in-P&L,
# gate definitions). Checkpoints refuse resume when this differs from the stamp.
COST_MODEL_VERSION = 1

# Per-pair spread (pips) — FILL TIMING ONLY; never multiply into P&L.
# Values unchanged from grid_sim_v6_dynamic_spacing.PAIR_SPREAD_PIPS (2026-07-18).
PAIR_SPREAD_PIPS: dict[str, float] = {
    "EURUSD": 0.18,
    "GBPUSD": 0.64,
    "EURGBP": 0.58,
}


@dataclass(frozen=True)
class PairSpec:
    """Static pair specification — extend table for JPY or new pairs."""

    symbol: str
    point: float
    pip_size: float
    quote_currency: str
    contract_size: float  # units per 1.0 lot
    spread_pips: float
    conversion_pair: str | None = None  # e.g. GBPUSD when quote is GBP


PAIR_SPECS: dict[str, PairSpec] = {
    "EURUSD": PairSpec(
        symbol="EURUSD",
        point=0.0001,
        pip_size=0.0001,
        quote_currency="USD",
        contract_size=100_000.0,
        spread_pips=PAIR_SPREAD_PIPS["EURUSD"],
        conversion_pair=None,
    ),
    "GBPUSD": PairSpec(
        symbol="GBPUSD",
        point=0.0001,
        pip_size=0.0001,
        quote_currency="USD",
        contract_size=100_000.0,
        spread_pips=PAIR_SPREAD_PIPS["GBPUSD"],
        conversion_pair=None,
    ),
    "EURGBP": PairSpec(
        symbol="EURGBP",
        point=0.0001,
        pip_size=0.0001,
        quote_currency="GBP",
        contract_size=100_000.0,
        spread_pips=PAIR_SPREAD_PIPS["EURGBP"],
        conversion_pair="GBPUSD",
    ),
    # Template for JPY pairs — not yet used in production sweeps.
    "USDJPY": PairSpec(
        symbol="USDJPY",
        point=0.01,
        pip_size=0.01,
        quote_currency="JPY",
        contract_size=100_000.0,
        spread_pips=0.30,
        conversion_pair=None,
    ),
}


def get_pair_spec(symbol: str) -> PairSpec:
    key = symbol.upper()
    if key not in PAIR_SPECS:
        raise KeyError(f"Unknown pair {symbol!r}; add to PAIR_SPECS in sim_costs.py")
    return PAIR_SPECS[key]


def pips_to_price(pips: float, symbol: str) -> float:
    spec = get_pair_spec(symbol)
    return pips * spec.pip_size


def half_spread_price(symbol: str) -> float:
    """Half bid-ask in price units — for fill triggers and MTM marking at bid/ask only."""
    spec = get_pair_spec(symbol)
    return pips_to_price(spec.spread_pips / 2.0, symbol)


def commission_per_leg_usd(
    lots: float = DEFAULT_LOT_SIZE,
    commission_usd_per_lot_per_side: float = DEFAULT_COMMISSION_USD_PER_LOT_PER_SIDE,
) -> float:
    return commission_usd_per_lot_per_side * lots


def commission_round_trip_usd(
    lots: float = DEFAULT_LOT_SIZE,
    commission_usd_per_lot_per_side: float = DEFAULT_COMMISSION_USD_PER_LOT_PER_SIDE,
) -> float:
    return 2.0 * commission_per_leg_usd(lots, commission_usd_per_lot_per_side)


def pip_value_quote_currency(
    symbol: str,
    lots: float = DEFAULT_LOT_SIZE,
) -> float:
    """Quote-currency value of one pip at `lots` (before USD conversion)."""
    spec = get_pair_spec(symbol)
    return spec.contract_size * spec.pip_size * lots


def pip_value_usd(
    symbol: str,
    lots: float = DEFAULT_LOT_SIZE,
    conversion_rate: float | None = None,
) -> float:
    """
    USD value of one pip at `lots`.
    USD-quoted pairs: exactly 10 USD per lot (0.10 at 0.01 lots).
    EURGBP: GBP pip value × GBPUSD rate; conversion_rate required.
    """
    spec = get_pair_spec(symbol)
    quote_val = pip_value_quote_currency(symbol, lots)
    if spec.quote_currency == "USD":
        return quote_val
    if spec.quote_currency == "JPY":
        if conversion_rate is None:
            raise ValueError(f"{symbol} requires conversion_rate (USDJPY) for pip_value_usd")
        return quote_val / conversion_rate
    if conversion_rate is None:
        raise ValueError(
            f"{symbol} requires conversion_rate (GBPUSD) for pip_value_usd; "
            "pass per-bar rate or explicit constant — never silent default"
        )
    return quote_val * conversion_rate


def price_diff_to_usd(
    price_diff: float,
    symbol: str,
    lots: float = DEFAULT_LOT_SIZE,
    conversion_rate: float | None = None,
) -> float:
    """Signed price difference → USD P&L (gross, no commission)."""
    spec = get_pair_spec(symbol)
    pips = price_diff / spec.pip_size
    return pips * pip_value_usd(symbol, lots, conversion_rate)


def pnl(
    entry: float,
    exit: float,
    pair: str,
    lots: float,
    direction: int,
    conversion_rate: float | None = None,
    commission_usd_per_lot_per_side: float = DEFAULT_COMMISSION_USD_PER_LOT_PER_SIDE,
) -> float:
    """
    Net USD P&L for one completed round trip at stored limit prices.
    Gross = (exit - entry) * direction in pips × pair-aware pip value.
    No spread term. Minus round-trip commission.
    """
    gross = price_diff_to_usd((exit - entry) * direction, pair, lots, conversion_rate)
    return gross - commission_round_trip_usd(lots, commission_usd_per_lot_per_side)


def layer_unrealised_usd(
    entry_price: float,
    direction: int,
    mark_price: float,
    symbol: str,
    entry_commission_usd: float,
    lots: float = DEFAULT_LOT_SIZE,
    conversion_rate: float | None = None,
) -> float:
    """
    Unrealised USD for one open layer.
    Mark at bid (long) or ask (short) via caller-supplied mark_price.
    Entry is the stored limit fill price — no spread re-pricing on entry.
    Sunk entry commission included.
    """
    gross = price_diff_to_usd((mark_price - entry_price) * direction, symbol, lots, conversion_rate)
    return gross - entry_commission_usd


def prague_calendar_day(ts) -> pd.Timestamp:
    """Calendar date at 00:00 Europe/Prague for a bar timestamp."""
    t = pd.Timestamp(ts)
    if t.tzinfo is None:
        t = t.tz_localize("UTC")
    return t.tz_convert(PRAGUE_TZ).normalize()


def evaluate_risk_gates(
    equity_series: Sequence[float],
    timestamps: Sequence | None,
    initial_balance: float = DEFAULT_INITIAL_BALANCE,
    max_daily_loss_usd: float | None = None,
    max_total_loss_usd: float | None = None,
) -> dict:
    """
    Dual FTMO-style gates on an equity path.

    Gate A: worst intraday drop from that day's Prague start equity >= max_daily_loss_usd.
    Daily floor reference: day-start equity minus fixed max_daily_loss_usd
    (max_daily_loss_usd defaults to 5% of *initial* balance).

    Gate B: peak-to-trough drawdown >= max_total_loss_usd (default 10% of initial).
    """
    if max_daily_loss_usd is None:
        max_daily_loss_usd = initial_balance * DEFAULT_MAX_DAILY_LOSS_FRAC
    if max_total_loss_usd is None:
        max_total_loss_usd = initial_balance * DEFAULT_MAX_TOTAL_LOSS_FRAC

    eq = np.asarray(equity_series, dtype=float)
    n = len(eq)
    if n == 0:
        return {
            "equity_peak": initial_balance,
            "max_absolute_drawdown_usd": 0.0,
            "max_daily_equity_drawdown_usd": 0.0,
            "gate_a_daily_loss_breach": False,
            "gate_b_total_loss_breach": False,
        }

    equity_peak = float(np.maximum.accumulate(eq).max())
    peak_running = initial_balance
    max_abs_dd = 0.0
    max_daily_dd = 0.0
    gate_a = False
    gate_b = False

    if timestamps is not None and len(timestamps) == n:
        days = [prague_calendar_day(t) for t in timestamps]
    else:
        days = list(range(n))

    day_start_equity = eq[0]
    current_day = days[0]

    for i in range(n):
        if days[i] != current_day:
            current_day = days[i]
            day_start_equity = eq[i - 1] if i > 0 else eq[0]

        peak_running = max(peak_running, eq[i])
        abs_dd = peak_running - eq[i]
        max_abs_dd = max(max_abs_dd, abs_dd)
        if abs_dd >= max_total_loss_usd:
            gate_b = True

        daily_dd = day_start_equity - eq[i]
        max_daily_dd = max(max_daily_dd, daily_dd)
        if daily_dd >= max_daily_loss_usd:
            gate_a = True

    return {
        "equity_peak": float(max(equity_peak, peak_running)),
        "max_absolute_drawdown_usd": float(max_abs_dd),
        "max_daily_equity_drawdown_usd": float(max_daily_dd),
        "gate_a_daily_loss_breach": gate_a,
        "gate_b_total_loss_breach": gate_b,
    }


def resolve_conversion_rate(
    symbol: str,
    bar_index: int,
    conversion_rate: float | None,
    gbpusd_closes: Sequence[float] | None,
) -> tuple[float | None, str]:
    """
    Return (rate, policy_label) for EURGBP USD conversion at bar_index.
    USD pairs: (None, 'native_usd').
    EURGBP: per-bar GBPUSD close if series provided, else constant conversion_rate.
    Raises if EURGBP and neither source supplied.
    """
    spec = get_pair_spec(symbol)
    if spec.quote_currency == "USD":
        return None, "native_usd"
    if gbpusd_closes is not None:
        return float(gbpusd_closes[bar_index]), "per_bar_gbpusd"
    if conversion_rate is not None:
        return float(conversion_rate), "constant_gbpusd"
    raise ValueError(
        f"{symbol} requires gbpusd_closes per-bar series or explicit conversion_rate"
    )


def load_aligned_gbpusd_closes(
    eurgbp_times: Sequence,
    data_root: str | Path,
    window_suffix: str,
) -> np.ndarray | None:
    """
    Load GBPUSD closes aligned to EURGBP bar timestamps for the same window suffix.
    Returns None if GBPUSD file missing.
    """
    root = Path(data_root)
    path = root / f"GBPUSD_{window_suffix}.csv"
    if not path.is_file():
        return None
    from grid_sim_v6_dynamic_spacing import load_mt5_csv

    gbp = load_mt5_csv(str(path))
    eur_t = pd.to_datetime(pd.Series(eurgbp_times))
    gbp_t = pd.to_datetime(gbp["datetime"])
    aligned = gbp.set_index("datetime")["CLOSE"].reindex(eur_t.values, method="ffill")
    if aligned.isna().any():
        aligned = aligned.bfill()
    return aligned.to_numpy(dtype=float)
