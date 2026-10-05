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
    """Open profit in USD of one position at t (long at bid, short at ask)."""
    q = quote_at(bars, pos["symbol"], t)
    k = usd_per_quote(bars, pos["symbol"], t)
    if q is None or k is None:
        return 0.0
    px = q[0] if pos["side"] == "L" else q[1]
    sgn = 1 if pos["side"] == "L" else -1
    return sgn * (px - pos["price"]) * 100000 * pos["volume"] * k


def build_days(deals, bars, magics=None, step=60, until=None):
    """Per-FTMO-day records (see the module doc). `magics`: keep only
    positions OPENED by these magics (their closes count whatever the
    closing deal's magic). Days run from the first kept deal's day to
    `until`'s day (default: the last kept deal's); a day is recorded when
    it traded or held positions AND the market quoted in it (a bar of a
    traded symbol inside the day: weekends drop out)."""
    owner = {}
    for d in deals:
        if d["entry"] == 0 and d["type"] in (0, 1):
            owner.setdefault(d["position"], d["magic"])

    def keep(d):
        if d["type"] not in (0, 1):
            return False
        if magics is None:
            return True
        return owner.get(d["position"], d["magic"]) in magics

    ds = [d for d in deals if keep(d)]
    if not ds:
        return []
    first = day_of(ds[0]["t"])
    last = day_of(until) if until is not None else day_of(ds[-1]["t"])
    syms = sorted({d["symbol"] for d in ds if d["symbol"] in bars})

    def quoted(a, b):
        for sy in syms:
            ts = bars[sy][0]
            j = bisect.bisect_left(ts, a)
            if j < len(ts) and ts[j] < b:
                return True
        return False
    open_pos = {}
    out = []
    i = 0
    for day in range(first, last + 1):
        t0 = day * DAY + DAY_START
        t1 = t0 + DAY
        m0 = sum(position_mtm(p, bars, t0) for p in open_pos.values())
        r = 0.0
        low = m0
        nmax = len(open_pos)
        t = t0
        traded = False
        while t <= t1:
            while i < len(ds) and ds[i]["t"] <= t:
                d = ds[i]
                r += d["profit"] + d["swap"] + d["commission"]
                traded = True
                if d["entry"] == 0:
                    open_pos[d["position"]] = dict(
                        symbol=d["symbol"], price=d["price"], volume=d["volume"],
                        side="L" if d["type"] == 0 else "S")
                elif d["position"] in open_pos:
                    del open_pos[d["position"]]
                i += 1
            nmax = max(nmax, len(open_pos))
            eq = r + sum(position_mtm(p, bars, t) for p in open_pos.values())
            low = min(low, eq)
            t += step
        m1 = sum(position_mtm(p, bars, t1) for p in open_pos.values())
        if (traded or open_pos) and quoted(t0, t1):
            out.append(dict(day=day, r=r, m0=m0, m1=m1, low=low, n_open_max=nmax))
    return out
