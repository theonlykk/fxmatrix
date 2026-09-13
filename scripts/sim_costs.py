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
    # JPY — recent median SPREAD (MT5 points / 10) from data/*_m5.csv,
    # last 250k M5 bars per symbol, sample through 2026-09-11; measured, not assumed.
    "USDJPY": 0.40,
    "AUDJPY": 0.80,
    "CHFJPY": 1.30,
    "NZDJPY": 1.00,
    "CADJPY": 1.20,
    # CAD/CHF ring — median SPREAD (MT5 points ÷ 10) from data/*_m5.csv,
    # sample 2015-01-02 through 2026-09-07 (~867k M5 bars each); measured, not assumed.
    "AUDCAD": 0.90,
    "AUDCHF": 0.80,
    "CADCHF": 1.10,
    # NZD extension — recent median SPREAD (MT5 points / 10) from data/*_m5.csv,
    # last 250k M5 bars per symbol, sample through 2026-09-11; measured, not assumed.
    "NZDCAD": 1.10,
    "NZDCHF": 1.00,
    "AUDNZD": 0.60,
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
    max_layers: int | None = None  # production InpMaxLayers; None = not ratified (raises)


PAIR_SPECS: dict[str, PairSpec] = {
    "EURUSD": PairSpec(
        symbol="EURUSD",
        point=0.0001,
        pip_size=0.0001,
        quote_currency="USD",
        contract_size=100_000.0,
        spread_pips=PAIR_SPREAD_PIPS["EURUSD"],
        conversion_pair=None,
        max_layers=12,
    ),
    "GBPUSD": PairSpec(
        symbol="GBPUSD",
        point=0.0001,
        pip_size=0.0001,
        quote_currency="USD",
        contract_size=100_000.0,
        spread_pips=PAIR_SPREAD_PIPS["GBPUSD"],
        conversion_pair=None,
        max_layers=12,
    ),
    "EURGBP": PairSpec(
        symbol="EURGBP",
        point=0.0001,
        pip_size=0.0001,
        quote_currency="GBP",
        contract_size=100_000.0,
        spread_pips=PAIR_SPREAD_PIPS["EURGBP"],
        conversion_pair="GBPUSD",
        max_layers=8,
    ),
    # JPY pairs — point and pip_size both equal one pip in price units (0.01),
    # not the MT5 tick size (0.001 on three-decimal quotes). See test_sim_costs J1.
    "USDJPY": PairSpec(
        symbol="USDJPY",
        point=0.01,
        pip_size=0.01,
        quote_currency="JPY",
        contract_size=100_000.0,
        spread_pips=PAIR_SPREAD_PIPS["USDJPY"],
        conversion_pair=None,
    ),
    "AUDJPY": PairSpec(
        symbol="AUDJPY",
        point=0.01,
        pip_size=0.01,
        quote_currency="JPY",
        contract_size=100_000.0,
        spread_pips=PAIR_SPREAD_PIPS["AUDJPY"],
        conversion_pair="USDJPY",
    ),
    "CHFJPY": PairSpec(
        symbol="CHFJPY",
        point=0.001,
        pip_size=0.01,
        quote_currency="JPY",
        contract_size=100_000.0,
        spread_pips=PAIR_SPREAD_PIPS["CHFJPY"],
        conversion_pair="USDJPY",
    ),
    "NZDJPY": PairSpec(
        symbol="NZDJPY",
        point=0.001,
        pip_size=0.01,
        quote_currency="JPY",
        contract_size=100_000.0,
        spread_pips=PAIR_SPREAD_PIPS["NZDJPY"],
        conversion_pair="USDJPY",
    ),
    "CADJPY": PairSpec(
        symbol="CADJPY",
        point=0.001,
        pip_size=0.01,
        quote_currency="JPY",
        contract_size=100_000.0,
        spread_pips=PAIR_SPREAD_PIPS["CADJPY"],
        conversion_pair="USDJPY",
    ),
    # CAD/CHF ring — point and pip_size both equal one pip in price units (0.0001),
    # not the MT5 tick size (0.00001 on five-decimal quotes).
    # max_layers=8: cross pairs, matching EURGBP cap; at 8 layers worst-case ladder
    # loss is below EURGBP live (AUDCAD $288, AUDCHF/CADCHF $479 vs EURGBP $517
    # at a 500-pip excursion).
    "AUDCAD": PairSpec(
        symbol="AUDCAD",
        point=0.0001,
        pip_size=0.0001,
        quote_currency="CAD",
        contract_size=100_000.0,
        spread_pips=PAIR_SPREAD_PIPS["AUDCAD"],
        conversion_pair="USDCAD",
        max_layers=8,
    ),
    "AUDCHF": PairSpec(
        symbol="AUDCHF",
        point=0.0001,
        pip_size=0.0001,
        quote_currency="CHF",
        contract_size=100_000.0,
        spread_pips=PAIR_SPREAD_PIPS["AUDCHF"],
        conversion_pair="USDCHF",
        max_layers=8,
    ),
    "CADCHF": PairSpec(
        symbol="CADCHF",
        point=0.0001,
        pip_size=0.0001,
        quote_currency="CHF",
        contract_size=100_000.0,
        spread_pips=PAIR_SPREAD_PIPS["CADCHF"],
        conversion_pair="USDCHF",
        max_layers=8,
    ),
    # NZD crosses — point is MT5 tick (0.00001 on five-decimal quotes); pip_size
    # is one pip in price units (0.0001). max_layers unset until geometry ratified.
    "NZDCAD": PairSpec(
        symbol="NZDCAD",
        point=0.00001,
        pip_size=0.0001,
        quote_currency="CAD",
        contract_size=100_000.0,
        spread_pips=PAIR_SPREAD_PIPS["NZDCAD"],
        conversion_pair="USDCAD",
    ),
    "NZDCHF": PairSpec(
        symbol="NZDCHF",
        point=0.00001,
        pip_size=0.0001,
        quote_currency="CHF",
        contract_size=100_000.0,
        spread_pips=PAIR_SPREAD_PIPS["NZDCHF"],
        conversion_pair="USDCHF",
    ),
    "AUDNZD": PairSpec(
        symbol="AUDNZD",
        point=0.00001,
        pip_size=0.0001,
        quote_currency="NZD",
        contract_size=100_000.0,
        spread_pips=PAIR_SPREAD_PIPS["AUDNZD"],
        conversion_pair="NZDUSD",
    ),
}


def get_pair_spec(symbol: str) -> PairSpec:
    key = symbol.upper()
    if key not in PAIR_SPECS:
        raise KeyError(f"Unknown pair {symbol!r}; add to PAIR_SPECS in sim_costs.py")
    return PAIR_SPECS[key]


def get_pair_spread_pips(symbol: str) -> float:
    """Spread constant for fill timing — raises on unknown pair (no silent default)."""
    key = symbol.upper()
    if key not in PAIR_SPREAD_PIPS:
        raise KeyError(
            f"Unknown pair {symbol!r}; add spread to PAIR_SPREAD_PIPS in sim_costs.py"
        )
    return PAIR_SPREAD_PIPS[key]


def get_pair_max_layers(symbol: str) -> int:
    """Production layer cap for simulation — raises if pair has no ratified cap."""
    spec = get_pair_spec(symbol)
    if spec.max_layers is None:
        raise ValueError(
            f"No max_layers cap configured for {symbol!r}; "
            f"add max_layers to PAIR_SPECS in sim_costs.py (do not default)"
        )
    return spec.max_layers


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
    EURGBP: GBP pip value × GBPUSD rate (multiply); conversion_rate required.
    JPY/CAD/CHF quotes: divide by USDJPY/USDCAD/USDCHF (inverse-quoted vs USD).
    """
    spec = get_pair_spec(symbol)
    quote_val = pip_value_quote_currency(symbol, lots)
    if spec.quote_currency == "USD":
        return quote_val
    if spec.quote_currency == "JPY":
        if conversion_rate is None:
            raise ValueError(f"{symbol} requires conversion_rate (USDJPY) for pip_value_usd")
        return quote_val / conversion_rate
    if spec.quote_currency in ("CAD", "CHF"):
        conv = spec.conversion_pair
        if conversion_rate is None:
            raise ValueError(
                f"{symbol} requires conversion_rate ({conv}) for pip_value_usd"
            )
        return quote_val / conversion_rate
    if spec.quote_currency == "GBP":
        if conversion_rate is None:
            raise ValueError(
                f"{symbol} requires conversion_rate (GBPUSD) for pip_value_usd; "
                "pass per-bar rate or explicit constant — never silent default"
            )
        return quote_val * conversion_rate
    raise ValueError(
        f"{symbol}: unknown quote_currency {spec.quote_currency!r} — "
        "add explicit rule in pip_value_usd"
    )


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
    conversion_closes: Sequence[float] | None,
) -> tuple[float | None, str]:
    """
    Return (rate, policy_label) for quote-to-USD conversion at bar_index.
    USD pairs: (None, 'native_usd').
    Non-USD: per-bar conversion close if series provided, else constant conversion_rate.
    Raises if non-USD and neither source supplied.
    """
    spec = get_pair_spec(symbol)
    if spec.quote_currency == "USD":
        return None, "native_usd"
    if conversion_closes is not None:
        return float(conversion_closes[bar_index]), "per_bar_conversion"
    if conversion_rate is not None:
        return float(conversion_rate), "constant_conversion"
    raise ValueError(
        f"{symbol} requires conversion_closes per-bar series or explicit conversion_rate"
    )


def _align_closes_to_primary(
    primary_times: Sequence,
    conversion_df: pd.DataFrame,
) -> tuple[np.ndarray, dict[str, int]]:
    """Reindex conversion CLOSE onto primary timestamps: ffill, then bfill leading gaps."""
    primary_t = pd.to_datetime(pd.Series(primary_times))
    conv = conversion_df.copy()
    conv["datetime"] = pd.to_datetime(conv["datetime"])
    conv_indexed = conv.set_index("datetime")["CLOSE"]
    aligned_raw = conv_indexed.reindex(primary_t.values)
    missing_before = aligned_raw.isna()
    after_ffill = aligned_raw.ffill()
    leading_bfill = after_ffill.isna()
    aligned = after_ffill.bfill()
    if aligned.isna().any():
        raise ValueError("conversion alignment left NaN after ffill/bfill")
    n_primary = len(primary_t)
    if len(aligned) != n_primary:
        raise RuntimeError(
            f"alignment length mismatch: primary={n_primary} aligned={len(aligned)}"
        )
    stats = {
        "primary_bars": n_primary,
        "matched_exact": int((~missing_before).sum()),
        "forward_filled": int(missing_before.sum() - leading_bfill.sum()),
        "back_filled_leading": int(leading_bfill.sum()),
    }
    return aligned.to_numpy(dtype=float), stats


def load_aligned_conversion_closes(
    primary_times: Sequence,
    symbol: str,
    data_root: str | Path,
    window_suffix: str,
    *,
    return_stats: bool = False,
) -> np.ndarray | None | tuple[np.ndarray | None, dict[str, int]]:
    """
    Load conversion-pair closes aligned to primary bar timestamps.

    Looks up conversion_pair from PairSpec. USD-quoted pairs return None.
    Raises FileNotFoundError if conversion_pair is set but the CSV is missing.
    """
    spec = get_pair_spec(symbol)
    if spec.conversion_pair is None:
        empty: dict[str, int] = {}
        return (None, empty) if return_stats else None

    root = Path(data_root)
    conv_pair = spec.conversion_pair
    path = root / f"{conv_pair}_{window_suffix}.csv"
    if not path.is_file():
        raise FileNotFoundError(
            f"{symbol} requires conversion pair {conv_pair}; file not found: {path}"
        )
    from grid_sim_v6_dynamic_spacing import load_mt5_csv

    conv_df = load_mt5_csv(str(path))
    aligned, stats = _align_closes_to_primary(primary_times, conv_df)
    assert len(aligned) == len(primary_times)
    stats["conversion_pair"] = conv_pair  # type: ignore[assignment]
    if return_stats:
        return aligned, stats
    return aligned


def load_aligned_gbpusd_closes(
    eurgbp_times: Sequence,
    data_root: str | Path,
    window_suffix: str,
) -> np.ndarray | None:
    """
    Legacy EURGBP wrapper. Returns None if GBPUSD file missing (historical behaviour).
    """
    try:
        result = load_aligned_conversion_closes(
            eurgbp_times, "EURGBP", data_root, window_suffix, return_stats=False
        )
        return result
    except FileNotFoundError:
        return None
