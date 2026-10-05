"""FTMO-day records from a deal history and minute bars (C124; read-only).

    days = build_days(deals, bars, magics=None)

A day is the FTMO day, 22:00Z to 22:00Z (00:00 Prague, CEST; the page:
"the account balance recorded at 00:00 CE(S)T"). For each day:
  r    realised P&L of the day: profit + swap + commission of every deal
       whose time falls in the day (entry commissions included);
  m0   open MTM at the day start, m1 at the day end;
  low  min over the day's minutes of (realised so far + open MTM), i.e.
       equity minus the day-start BALANCE: the daily-loss test (carried
       open loss counts at once);
  n_open_max  most positions open at once.
MTM marks a long at the minute bar's bid close, a short at its ask close,
converted to USD at the minute's mid of the quote currency's USD rate.
Balance (type 2) deals are not trading P&L and are skipped.
"""
import csv
import bisect

DAY = 86400
DAY_START = 22 * 3600          # 22:00Z = 00:00 CEST (summer)
QUOTE_RATE = {                 # quote currency -> (symbol, invert)
    "USD": (None, False), "CAD": ("USDCAD", True), "CHF": ("USDCHF", True),
    "GBP": ("GBPUSD", False), "NZD": ("NZDUSD", False), "AUD": ("AUDUSD", False),
    "EUR": ("EURUSD", False),
}


def day_of(t):
    """FTMO day index: the day that STARTS at 22:00Z containing t."""
    return (int(t) - DAY_START) // DAY


def load_history(path):
    """Deals as dicts (time in UTC seconds) from grind_history_dump's CSV."""
    rows = []
    with open(path, newline="") as fh:
        head = fh.readline()
        off = 0
        for tok in head.split():
            if tok.startswith("server_minus_gmt_s="):
                off = int(tok.split("=")[1])
        for r in csv.DictReader(fh):
            rows.append(dict(
                deal=int(r["deal"]), position=int(r["position"]),
                t=int(r["time_msc_server"]) / 1000.0 - off,
                type=int(r["type"]), entry=int(r["entry"]), magic=int(r["magic"]),
                symbol=r["symbol"], volume=float(r["volume"]), price=float(r["price"]),
                commission=float(r["commission"]), swap=float(r["swap"]),
                profit=float(r["profit"])))
    rows.sort(key=lambda d: (d["t"], d["deal"]))
    return rows


def load_bars(path):
    """(times UTC, bid closes, ask closes) from a grind_bidask_dump CSV."""
    off = 10800
    t, b, a = [], [], []
    with open(path) as fh:
        for r in csv.reader(fh):
            if not r:
                continue
            if r[0].startswith("#"):
                for tok in r[0].split():
                    if tok.startswith("server_minus_gmt_s="):
                        off = int(tok.split("=")[1])
                continue
            if r[0] == "time_server":
                continue
            t.append(int(r[1]) - off)
            b.append(float(r[5]))
            a.append(float(r[9]))
    return t, b, a


def quote_at(bars, sym, t):
    """(bid, ask) of the last bar starting at or before t, or None."""
    if sym not in bars:
        return None
    ts, b, a = bars[sym]
    i = bisect.bisect_right(ts, t) - 1
    if i < 0:
        return None
    return b[i], a[i]


def usd_per_quote(bars, sym, t):
    """USD value of one unit of the symbol's quote currency at t."""
    rs, inv = QUOTE_RATE[sym[3:]]
    if rs is None:
        return 1.0
    q = quote_at(bars, rs, t)
    if q is None:
        return None
    mid = (q[0] + q[1]) / 2
    return 1.0 / mid if inv else mid


def position_mtm(pos, bars, t):
    raise NotImplementedError("C124 stub: tests first")


def build_days(deals, bars, magics=None, step=60, until=None):
    raise NotImplementedError("C124 stub: tests first")