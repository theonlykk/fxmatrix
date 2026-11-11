"""Shared loaders for the pass-1 review. ASCII only.

Bars: FTMO M1 bid OHLC + spread (points) + tick volume, server time (bars_1514878887_<PAIR>.csv).
All six pairs are 5-digit, 1 pip = 0.0001.

Usage from other scripts:  from common import *
Paths: BARS_DIR / TICKS_DIR / CACHE / OUT are taken from the environment (FR_BARS, FR_TICKS, FR_CACHE, FR_OUT)
or default to the folders used in the review sandbox. On the PC set e.g.
    set FR_BARS=D:\\fxmatrix-exports\\bars_ftmo
    set FR_TICKS=D:\\fxmatrix-exports\\ticks_ic
    set FR_CACHE=D:\\fxmatrix-exports\\fable_review\\cache
    set FR_OUT=D:\\fxmatrix-exports\\fable_review\\out
Needs numpy, pandas, numba.
"""
import os
import numpy as np
import pandas as pd

BARS_DIR = os.environ.get("FR_BARS", "/mnt/user-data/uploads/fxmatrix-exports/bars_ftmo")
TICKS_DIR = os.environ.get("FR_TICKS", "/mnt/user-data/uploads/fxmatrix-exports/ticks_ic")
CACHE = os.environ.get("FR_CACHE", "/home/claude/fr/cache")
OUT = os.environ.get("FR_OUT", "/home/claude/fr/out")
os.makedirs(CACHE, exist_ok=True)
os.makedirs(OUT, exist_ok=True)

PAIRS = ["EURUSD", "GBPUSD", "EURGBP", "AUDCAD", "AUDCHF", "CADCHF"]
PIP = 1e-4
PT = 1e-5
# from run_bars.py: (width, add, stranded) OPT then ALT; exit = add, cap 7, deadband 2
GEO = {"EURUSD": ((2.0, 7, 3.0), (6.0, 23, 7.0)), "GBPUSD": ((2.5, 9, 3.5), (4.0, 15, 5.0)),
       "EURGBP": ((1.5, 5, 2.5), (6.0, 23, 7.0)), "AUDCAD": ((4.5, 18, 5.5), (6.5, 26, 7.5)),
       "AUDCHF": ((3.5, 14, 4.5), (5.0, 20, 6.0)), "CADCHF": ((2.5, 10, 3.5), (4.5, 17, 5.5))}
USD = {"EURUSD": 0.100, "GBPUSD": 0.100, "EURGBP": 0.134, "AUDCAD": 0.0714, "AUDCHF": 0.122, "CADCHF": 0.122}
COMM = 0.06                      # USD per close per 0.01 lot
SCALES = [3, 4, 5, 6, 7, 8, 9, 10, 12, 14, 15, 17, 18, 20, 23, 26, 30, 40, 60, 100]


def comm_pips(pair):
    return COMM / USD[pair]


def load_bars(pair):
    """Returns dict of numpy arrays: t (unix seconds, server clock), o, h, l, c (bid), sp (spread in price), tv."""
    npz = os.path.join(CACHE, "bars_%s.npz" % pair)
    if os.path.exists(npz):
        z = np.load(npz)
        return {k: z[k] for k in z.files}
    f = os.path.join(BARS_DIR, "bars_1514878887_%s.csv" % pair)
    df = pd.read_csv(f, skiprows=1)
    d = {"t": df["time_unix_server"].to_numpy(np.int64), "o": df["open"].to_numpy(float),
         "h": df["high"].to_numpy(float), "l": df["low"].to_numpy(float), "c": df["close"].to_numpy(float),
         "sp": df["spread_points"].to_numpy(float) * PT, "tv": df["tick_volume"].to_numpy(np.int64)}
    np.savez(npz, **d)
    return d


def bar_header(pair):
    with open(os.path.join(BARS_DIR, "bars_1514878887_%s.csv" % pair)) as fh:
        return fh.readline().strip()


def weekday_mask(t):
    """Server-clock weekday bars only (Mon-Fri)."""
    dow = ((t // 86400) + 3) % 7          # 0 = Monday (1970-01-01 was a Thursday)
    return dow < 5


def blowout_mask(b):
    """Bars whose recorded spread (MT5 stores the MINIMUM spread of the minute) is far above normal:
    > max(3 x pair median, median + 1 pip). In such bars (mostly the rollover, server 23:55-01:05) the bid is
    displaced by the widened spread, so bid-only bars show dips that are not moves of the market."""
    sp = b["sp"] / PIP
    med = np.median(sp)
    return sp > max(3.0 * med, med + 1.0)


def pseudo_ticks(b, order="std", clean=True):
    """M1 bar -> 4 pseudo-ticks 15 s apart, as run_bars.py: open, then low and high in the bar's direction
    (low first when close >= open), then close. order="alt" swaps the high/low order (sensitivity test).
    clean=True: in blow-out bars (blowout_mask) the mid is frozen at the last normal mid (the recorded spread is
    kept), so that spread blow-outs do not masquerade as price moves. clean=False: exactly run_bars.py's ticks.
    Returns t_ms (int64), bid, ask."""
    m = weekday_mask(b["t"])
    t, o, h, l, c, sp = (b[k][m] for k in ("t", "o", "h", "l", "c", "sp"))
    up = c >= o
    if order == "alt":
        up = ~up
    n = len(t)
    bid = np.empty(4 * n)
    bid[0::4] = o
    bid[1::4] = np.where(up, l, h)
    bid[2::4] = np.where(up, h, l)
    bid[3::4] = c
    tm = np.empty(4 * n, np.int64)
    for j in range(4):
        tm[j::4] = t * 1000 + j * 15000
    spr = np.repeat(sp, 4)
    if not clean:
        return tm, bid, bid + spr
    mid = bid + 0.5 * spr
    bo = np.repeat(blowout_mask(b)[m], 4)
    good = np.where(~bo, np.arange(4 * n), -1)
    last = np.maximum.accumulate(good)
    last[last < 0] = np.argmax(~bo)             # leading blow-out bars: use the first normal mid
    mid = mid[last]
    return tm, mid - 0.5 * spr, mid + 0.5 * spr


def month_id(t_ms):
    """Integer month index (year*12 + month-1) per sample, server clock."""
    dt = pd.to_datetime(t_ms, unit="ms")
    return (dt.year.values * 12 + dt.month.values - 1).astype(np.int64)


def month_label(mid_):
    return "%04d-%02d" % (mid_ // 12, mid_ % 12 + 1)


def tstat(x):
    x = np.asarray(x, float)
    x = x[np.isfinite(x)]
    n = len(x)
    if n < 2:
        return np.nan, np.nan, np.nan, n
    m = x.mean()
    se = x.std(ddof=1) / np.sqrt(n)
    return m, se, (m / se if se > 0 else np.nan), n
