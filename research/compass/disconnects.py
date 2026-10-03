"""Broker disconnects from MT5 journal files (C104; runbook s1: reported,
never deciding). A disconnect starts at a "connection to <server> lost" line
and ends at the next "authorized on" or "terminal synchronized" line; one
still open at the file's end has no end. Journal times are the terminal
machine's clock (UTC on the VPS and the wine boxes); the date comes from the
file name (YYYYMMDD.log). Files may be UTF-16 (MT5) or UTF-8.

    python research/compass/disconnects.py <journal.log> [...]
"""
import datetime as dt
import os
import re
import sys

LOST = re.compile(r"connection to .+ lost")
BACK = re.compile(r"authorized on|terminal synchronized")
TIME = re.compile(r"\b(\d\d:\d\d:\d\d\.\d{3})\b")


def _stamp(date, hms):
    return dt.datetime.strptime(date + " " + hms, "%Y-%m-%d %H:%M:%S.%f")


def parse_lines(lines, date):
    events, cur = [], None
    for line in lines:
        m = TIME.search(line)
        if not m:
            continue
        hms = m.group(1)
        if LOST.search(line):
            if cur is None:
                cur = {"start": date + " " + hms, "end": None, "seconds": None}
                events.append(cur)
        elif cur is not None and BACK.search(line):
            cur["end"] = date + " " + hms
            cur["seconds"] = (_stamp(date, hms) - _stamp(*cur["start"].split(" "))).total_seconds()
            cur = None
    return events


def _read(path):
    raw = open(path, "rb").read()
    if raw[:2] in (b"\xff\xfe", b"\xfe\xff"):
        return raw.decode("utf-16")
    return raw.decode("utf-8-sig", errors="replace")


def parse_file(path):
    name = os.path.basename(path)[:8]
    date = "%s-%s-%s" % (name[:4], name[4:6], name[6:8])
    return parse_lines(_read(path).splitlines(), date)


def main(argv=None):
    paths = argv if argv is not None else sys.argv[1:]
    total = 0
    for path in paths:
        for e in parse_file(path):
            total += 1
            print("%s  lost %s  back %s  %s" % (os.path.basename(path), e["start"], e["end"] or "-",
                  "%.1f s" % e["seconds"] if e["seconds"] is not None else "UNRESOLVED"))
    print("disconnects: %d" % total)


if __name__ == "__main__":
    main()
