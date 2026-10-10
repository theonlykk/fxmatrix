"""Plan 2 s16 / fix 7 K8: do the replay's carry MODIFY prices equal live's?

For each fleet and run, every TIMER-stage MODIFY in the replay's order log
is matched to live's carry-window MODIFYs (send_logs, broker time 23:50-23:59
server) on the same server night by REQUESTED PRICE (live's carry sends carry
no side, layer or role). Live's 10025 sends (an unchanged price) are listed
but never matched.

Usage (Python 3.11+, read-only):
    python -I carry_prices.py SENDS_DIR RUNS_DIR HARNESS
SENDS_DIR holds sends_EURUSD_OPT{B,C,D}_2026-10-09.jsonl; RUNS_DIR is
research/replay/runs on branch replay-harness; HARNESS e.g. 868bcc3.
"""
import collections
import csv
import datetime as dt
import json
import os
import sys


def live_carry(path):
    out = collections.defaultdict(list)
    with open(path, encoding="utf-8-sig") as fh:
        for line in fh:
            r = json.loads(line)
            if r.get("table") != "send_logs" or r["action"] != "MODIFY":
                continue
            bt = r["broker_time"]
            if not (bt[11:13] == "23" and int(bt[14:16]) >= 50):
                continue
            out[bt[:10]].append((round(r["requested_price"], 5), r["retcode"]))
    return out


def replay_carry(path):
    out = []
    with open(path, newline="") as fh:
        for r in csv.DictReader(fh):
            if r["stage"] != "TIMER" or r["action"] != "MODIFY":
                continue
            t = dt.datetime.fromtimestamp(int(r["time_ms"]) / 1000, dt.timezone.utc)
            out.append((t.date().isoformat(), t.strftime("%H:%M:%S"), r["side"] + r["layer"],
                        round(float(r["price"]), 5)))
    return out


def main(sends_dir, runs_dir, harness):
    for fleet in "bcd":
        live = live_carry(os.path.join(sends_dir, "sends_EURUSD_OPT%s_2026-10-09.jsonl" % fleet.upper()))
        print("== %s live carry MODIFYs (night: price/retcode)" % fleet.upper())
        for night in sorted(live):
            print("   %s %s" % (night, " ".join("%.5f/%d" % p for p in live[night])))
        for mode in ("sync", "free"):
            for suffix in ("", "_t0"):
                folder = "eurusd_%s_%s_%s%s" % (fleet, mode, harness, suffix)
                rows = replay_carry(os.path.join(runs_dir, folder, "out_eurusd_%s_%s_orders.csv" % (fleet, mode)))
                miss = [r for r in rows if r[3] not in [p for p, rc in live.get(r[0], []) if rc == 10009]]
                wk = [r for r in rows if dt.date.fromisoformat(r[0]).weekday() >= 5]
                print("   %-34s replay %2d, equal to a live 10009 price that night %2d, weekend %d; not equal: %s"
                      % (folder, len(rows), len(rows) - len(miss), len(wk),
                         " ".join("%s %s %s %.5f" % r for r in miss) or "-"))


if __name__ == "__main__":
    main(*sys.argv[1:4])
