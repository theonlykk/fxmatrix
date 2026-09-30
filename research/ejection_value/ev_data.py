"""Loaders for the ejection value study (docs/research/ejection-value-study.md).

Inputs:
- the pipshed export (`archive_counts.py --export-study`), JSON lines, one or
  more files (weekly exports overlap; rows are de-duplicated by table and id);
- M1 bar dumps from `scripts/grind_bar_dump.mq5` (bars_<login>_<SYM>.csv).

Standard library only. All times returned are UTC epoch seconds (float).
"""
import csv
import datetime as _dt
import glob
import json
import os
import re

FLEET_BY_SUFFIX = (("OPTB", "B"), ("ALTB", "B"), ("OPTC", "C"), ("ALTC", "C"),
                   ("OPT", "A"), ("ALT", "A"))


def fleet_of(instance_id):
    """GRIND_EURGBP_OPTB -> 'B'. Longest suffix first (OPTB before OPT)."""
    tail = instance_id.rsplit("_", 1)[-1]
    for suffix, fleet in FLEET_BY_SUFFIX:
        if tail == suffix:
            return fleet
    raise ValueError("unknown fleet suffix: %s" % instance_id)


def symbol_of(instance_id):
    """GRIND_EURGBP_OPTB -> 'EURGBP'."""
    parts = instance_id.split("_")
    if len(parts) != 3 or parts[0] != "GRIND":
        raise ValueError("unexpected instance id: %s" % instance_id)
    return parts[1]


def parse_utc(text):
    """'2026-09-28 07:46:01.123+00:00' (Postgres timestamptz as str) -> epoch s."""
    t = _dt.datetime.fromisoformat(text)
    if t.tzinfo is None:
        raise ValueError("naive timestamp: %s" % text)
    return t.timestamp()


def broker_msc_to_utc(msc, server_minus_gmt_s):
    """fill_logs.deal_time_broker_msc is SERVER clock in ms -> UTC epoch s."""
    return msc / 1000.0 - server_minus_gmt_s


def load_export(paths):
    """Read one or more export files. Returns {table: [rows]} with rows
    de-duplicated on (table, id) and sorted by id. `_meta` lines are kept
    per file under '_meta'. Files saved by PowerShell carry a BOM."""
    seen = {}
    metas = []
    for path in paths:
        with open(path, encoding="utf-8-sig") as fh:
            for lineno, line in enumerate(fh, 1):
                line = line.strip()
                if not line:
                    continue
                try:
                    rec = json.loads(line)
                except ValueError as exc:
                    raise ValueError("%s:%d: %s" % (path, lineno, exc))
                table = rec.get("table")
                if table == "_meta":
                    metas.append(dict(rec, file=os.path.basename(path)))
                    continue
                seen[(table, rec["id"])] = rec
    out = {"_meta": metas}
    for (table, _id), rec in sorted(seen.items(), key=lambda kv: (kv[0][0], kv[0][1])):
        out.setdefault(table, []).append(rec)
    return out


CURRENT_ACCOUNTS = (1514731800, 53066709, 53071896)   # A (cycle 3), B, C


def filter_by_account(export, accounts=CURRENT_ACCOUNTS):
    """Keep only rows whose session_id belongs to one of `accounts` (the
    session -> account map comes from config_events). Cycle 2 (FTMO
    1514582088, ended 23 Sep) used the SAME instance ids as fleet A, so a
    window reaching back before 24 Sep mixes the two books without this.
    Rows whose session is unknown are dropped. Returns (export, dropped)
    where dropped = {table: count}."""
    accounts = set(int(a) for a in accounts)
    sess = {}
    for r in export.get("config_events", []):
        if r.get("session_id") and r.get("account_login"):
            sess[r["session_id"]] = int(r["account_login"])
    out = {"_meta": export.get("_meta", [])}
    dropped = {}
    for table, rows in export.items():
        if table == "_meta":
            continue
        keep = [r for r in rows if sess.get(r.get("session_id")) in accounts]
        out[table] = keep
        if len(keep) != len(rows):
            dropped[table] = len(rows) - len(keep)
    return out, dropped


class Bars:
    """M1 bars for one symbol on one server: UTC open times, bid OHLC, bar
    spread in points. `point` and `pip` in price units (pip = 10 points on
    3- and 5-digit symbols)."""

    def __init__(self, symbol, account, server, digits, point, offset_s, to_utc):
        self.symbol = symbol
        self.account = account
        self.server = server
        self.digits = digits
        self.point = point
        self.pip = point * 10 if digits in (3, 5) else point
        self.offset_s = offset_s
        self.to_utc = to_utc          # dump end (UTC); bars at or after it are dropped
        self.t = []                   # bar open, UTC epoch s
        self.o, self.h, self.l, self.c = [], [], [], []
        self.spread = []              # points (M1 bars: the minute's minimum spread)
        # True per-minute ask OHLC (grind_bidask_dump.mq5); None for M1 bar dumps,
        # where the ask is approximated as bid + bar spread (GQ4).
        self.ao = self.ah = self.al = self.ac = None

    def __len__(self):
        return len(self.t)

    @property
    def has_ask(self):
        return self.al is not None

    def ask_open(self, i):
        return self.ao[i] if self.ao is not None else self.o[i] + self.spread[i] * self.point

    def ask_low(self, i):
        """Lowest ask in bar i: true (bid/ask dump) or bid low + bar spread (GQ4)."""
        return self.al[i] if self.al is not None else self.l[i] + self.spread[i] * self.point

    def ask_high(self, i):
        return self.ah[i] if self.ah is not None else self.h[i] + self.spread[i] * self.point

    def ask_close(self, i):
        return self.ac[i] if self.ac is not None else self.c[i] + self.spread[i] * self.point

    def index_at_or_after(self, t_utc):
        """First bar whose OPEN is >= t_utc (binary search)."""
        lo, hi = 0, len(self.t)
        while lo < hi:
            mid = (lo + hi) // 2
            if self.t[mid] < t_utc:
                lo = mid + 1
            else:
                hi = mid
        return lo

    def index_containing(self, t_utc):
        """Bar whose [open, open+60) contains t_utc, or the next bar."""
        i = self.index_at_or_after(t_utc)
        if i > 0 and self.t[i - 1] <= t_utc < self.t[i - 1] + 60:
            return i - 1
        return i


def _parse_header(line):
    if not line.startswith("#"):
        raise ValueError("bar file has no # header line")
    # values may hold spaces ('from=2026.09.27 00:00'): a value runs to the next ' key='
    return {k: v.strip() for k, v in re.findall(r"(\w+)=(.*?)(?=\s+\w+=|$)", line[1:].strip())}


def _server_text_to_unix(text):
    # '2026.09.28 19:15' (server clock) -> unix seconds as if UTC (MQL datetime)
    t = _dt.datetime.strptime(text, "%Y.%m.%d %H:%M").replace(tzinfo=_dt.timezone.utc)
    return int(t.timestamp())


def load_bars_file(path):
    """Read one bars_<login>_<SYM>.csv. `time_unix_server` is the SERVER clock
    written as unix seconds; UTC = that - server_minus_gmt_s (header). The
    bar opening at the dump's `to` minute (and later) was still forming and
    is dropped."""
    with open(path, encoding="utf-8-sig") as fh:
        hdr = _parse_header(fh.readline())
        offset = int(hdr["server_minus_gmt_s"])
        to_server = _server_text_to_unix(hdr["to"])
        bars = Bars(hdr["symbol"], int(hdr["account"]), hdr["server"], int(hdr["digits"]),
                    float(hdr["point"]), offset, to_server - offset)
        reader = csv.DictReader(fh)
        for row in reader:
            t_server = int(row["time_unix_server"])
            if t_server >= to_server:
                continue
            bars.t.append(float(t_server - offset))
            bars.o.append(float(row["open"]))
            bars.h.append(float(row["high"]))
            bars.l.append(float(row["low"]))
            bars.c.append(float(row["close"]))
            bars.spread.append(int(row["spread_points"]))
    for a, b in zip(bars.t, bars.t[1:]):
        if b <= a:
            raise ValueError("%s: bar times not increasing" % path)
    return bars


def merge_bars(parts):
    """Join several dumps of one symbol/account (overlapping runs); later
    files win on a duplicate minute."""
    if not parts:
        raise ValueError("no bars")
    base = parts[0]
    by_t = {}
    for p in parts:
        if (p.symbol, p.account) != (base.symbol, base.account):
            raise ValueError("merging different symbols or accounts")
        for i in range(len(p)):
            by_t[p.t[i]] = (p.o[i], p.h[i], p.l[i], p.c[i], p.spread[i])
    out = Bars(base.symbol, base.account, base.server, base.digits, base.point,
               base.offset_s, max(p.to_utc for p in parts))
    for t in sorted(by_t):
        o, h, l, c, s = by_t[t]
        out.t.append(t); out.o.append(o); out.h.append(h); out.l.append(l)
        out.c.append(c); out.spread.append(s)
    return out


def load_bidask_file(path):
    """Read one bidask_<login>_<SYM>.csv (grind_bidask_dump.mq5): per-minute
    bid and ask OHLC built from ticks. `spread` = the minute's minimum spread
    (as an M1 bar's); the minute at the dump's `to` (and later) is dropped."""
    with open(path, encoding="utf-8-sig") as fh:
        hdr = _parse_header(fh.readline())
        offset = int(hdr["server_minus_gmt_s"])
        to_server = _server_text_to_unix(hdr["to"])
        bars = Bars(hdr["symbol"], int(hdr["account"]), hdr["server"], int(hdr["digits"]),
                    float(hdr["point"]), offset, to_server - offset)
        bars.ao, bars.ah, bars.al, bars.ac = [], [], [], []
        for row in csv.DictReader(fh):
            t_server = int(row["time_unix_server"])
            if t_server >= to_server:
                continue
            bars.t.append(float(t_server - offset))
            bars.o.append(float(row["bid_open"])); bars.h.append(float(row["bid_high"]))
            bars.l.append(float(row["bid_low"])); bars.c.append(float(row["bid_close"]))
            bars.ao.append(float(row["ask_open"])); bars.ah.append(float(row["ask_high"]))
            bars.al.append(float(row["ask_low"])); bars.ac.append(float(row["ask_close"]))
            bars.spread.append(int(row["spread_min_points"]))
    for a, b in zip(bars.t, bars.t[1:]):
        if b <= a:
            raise ValueError("%s: minute times not increasing" % path)
    return bars


def load_bidask_dir(directory):
    """All bidask_<login>_<SYM>.csv under `directory`: {(account, symbol): Bars}.
    One file per symbol and account (a later run replaces an earlier one)."""
    out = {}
    for path in sorted(glob.glob(os.path.join(directory, "**", "bidask_*_*.csv"), recursive=True)):
        b = load_bidask_file(path)
        out[(b.account, b.symbol)] = b
    return out


def load_bars_dir(directory):
    """All bars_<login>_<SYM>.csv under `directory` (recursive), merged per
    (account, symbol). Returns {(account, symbol): Bars}."""
    groups = {}
    for path in sorted(glob.glob(os.path.join(directory, "**", "bars_*_*.csv"), recursive=True)):
        b = load_bars_file(path)
        groups.setdefault((b.account, b.symbol), []).append(b)
    return {k: merge_bars(v) for k, v in groups.items()}
