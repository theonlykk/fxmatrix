"""IC Markets raw tick loader (bid/ask, server time). Joins the windows of each pair into one series without overlap:
six pairs: __h8w (3 Aug - 1 Oct 04:00) + _oct (1 Oct 01:30 - 21 Oct 01:30); EURUSD has no _oct, so
__h8w + _w2 (1 Oct 04:00 - 9 Oct 01:30) + _hold (9 - 14 Oct) + _win (14 - 21 Oct). ASCII only."""
from common import *

WINDOWS = {p: ["__h8w", "_oct"] for p in PAIRS}
WINDOWS["EURUSD"] = ["__h8w", "_w2", "_hold", "_win"]


def load_ticks(pair):
    npz = os.path.join(CACHE, "ticks_%s.npz" % pair)
    if os.path.exists(npz):
        z = np.load(npz)
        return z["t"], z["bid"], z["ask"]
    ts, bs, as_ = [], [], []
    last = -1
    for w in WINDOWS[pair]:
        f = os.path.join(TICKS_DIR, "ticks_53077984_%s%s.csv" % (pair, w))
        df = pd.read_csv(f, skiprows=1)
        t = df["time_msc_server"].to_numpy(np.int64)
        m = t > last
        ts.append(t[m]); bs.append(df["bid"].to_numpy(float)[m]); as_.append(df["ask"].to_numpy(float)[m])
        last = t[m][-1] if m.any() else last
    t = np.concatenate(ts); bid = np.concatenate(bs); ask = np.concatenate(as_)
    assert (np.diff(t) >= 0).all()
    np.savez(npz, t=t, bid=bid, ask=ask)
    return t, bid, ask


def bars_from_ticks(t, bid, ask):
    """MT5-style M1 bars from ticks: bid OHLC and the MINIMUM spread of the minute. Same dict layout as load_bars."""
    minute = t // 60000
    first = np.r_[0, np.nonzero(np.diff(minute))[0] + 1]
    last = np.r_[first[1:] - 1, len(t) - 1]
    h = np.maximum.reduceat(bid, first); l = np.minimum.reduceat(bid, first)
    sp = np.minimum.reduceat(ask - bid, first)
    spmean = np.add.reduceat(ask - bid, first) / (last - first + 1)
    return {"t": minute[first] * 60, "o": bid[first], "h": h, "l": l, "c": bid[last], "sp": sp, "tv": last - first + 1,
            "sp_mean": spmean, "sp_first": (ask - bid)[first], "sp_last": (ask - bid)[last]}


def week_id(t_ms):
    return ((t_ms // 86400000) + 3) // 7          # weeks starting Monday (server clock)
