"""Plan 3 P3: live sends in the 2 Oct payrolls minute (15:29-15:33 server), per fleet:
counts by action / ok / retcode, durations, and every send over 1 s or refused.
usage: python -I burst_sends.py SENDS_DIR   (sends_EURUSD_OPT{B,C,D}_2026-10-09.jsonl)"""
import collections, datetime as dt, json, os, sys
OFF = 3 * 3600 * 1000
A = int(dt.datetime(2026, 10, 2, 15, 29, tzinfo=dt.timezone.utc).timestamp() * 1000)
B = int(dt.datetime(2026, 10, 2, 15, 33, tzinfo=dt.timezone.utc).timestamp() * 1000)
for f in "BCD":
    rows = []
    with open(os.path.join(sys.argv[1], "sends_EURUSD_OPT%s_2026-10-09.jsonl" % f), encoding="utf-8-sig") as fh:
        for line in fh:
            r = json.loads(line)
            if r.get("table") == "send_logs" and A <= int(r["ea_time_ms"]) + OFF <= B:
                rows.append(r)
    durs = sorted(r["duration_ms"] for r in rows)
    print(f, "sends", len(rows), dict(sorted(collections.Counter((r["action"], r["ok"], r["retcode"]) for r in rows).items())),
          "median ms", durs[len(durs) // 2], "max ms", durs[-1], "over 1 s", sum(d > 1000 for d in durs))
    for r in rows:
        if r["duration_ms"] > 1000 or not r["ok"]:
            start = (int(r["ea_time_ms"]) + OFF - r["duration_ms"]) / 1000
            print("   %s %s ok %s rc %s %d ms" % (dt.datetime.fromtimestamp(start, dt.timezone.utc).strftime("%H:%M:%S.%f")[:-3],
                                               r["action"], r["ok"], r["retcode"], r["duration_ms"]))
