This message has a line count at the bottom

# PLAN 4's WINDOW: TUE 20 OCT EXPORT AND HASH (COMMAND LIST)

| | |
|---|---|
| For | `docs/research/replay-calibration-eurusd-4.md` s3 ("The data") and s7 step 3: the window's data **exported and hashed ONLY**, then s7 step 4 |
| When | **Tue 20 Oct 2026.** Steps 1-2 from **22:10Z** (18:10 Toronto; the window ends 22:00Z = Wed 21 Oct 01:00 server, and the archive worker runs minutes behind). Step 3 from **22:30Z** (18:30 Toronto = 01:30 server) |
| Who | The operator runs every command. Claude gives ONE step per message, with the clock read first, and waits for its output |
| Writes | Seven files in `Downloads` (3 sends, 3 archives, 1 tick file) and their sha256 in git (`research/replay/inputs/eurusd_window_p4_raw.sha256`, under "THE WINDOW SET"). Nothing else |
| Status | DRAFT (Claude, 18 Oct ~06:10Z). From `docs/runbooks/plan3-holdout-export.md` (run clean 13 Oct) with plan 4's names, span and the one changed STOP line (X3) |

## 0. AUDIT TRAIL

| # | Fact | Where | Status |
|---|---|---|---|
| X1 | The window: Fri 16 Oct 00:00 server (cut `1792108800000`) to Wed 21 Oct 01:00 server (end `1792544400000` = Tue 20 Oct 22:00Z); the tick dump `2026.10.14 01:30` to `2026.10.21 01:30` server, joined to w2h at the 14 Oct 01:30 seam | plan 4 s3; the two stamps recomputed 18 Oct | VERIFIED |
| X2 | The export commands, the dump script's inputs (`InpTo` exclusive, `InpProbeOnly` default TRUE = no file) and the copy and hash steps are plan 3's, unchanged | `plan3-holdout-export.md` s2, X1-X8 | RECORDED (run 13 Oct) |
| X3 | **`bad_px=1` is EXPECTED** (the insurance dump over 14-17 Oct read 1: a tick with bid or ask <= 0, or ask < bid, dropped by the dumper, `scripts/grind_tick_dump.mq5` 129-133). Plan 3's runbook stops on any `bad_px` above 0; here **2 or more is a STOP**, and 0 is reported (not a STOP) | `eurusd_window_p4_raw.sha256` (the insurance); 02_TRAPS 16 Oct night and 18 Oct | RULED (plan 4 NEXT lists) |
| X4 | **No blind:** plan 4 froze before its window opened (02_TRAPS 16 Oct). "Exported and hashed ONLY" here means: nothing opens the seven files until their hashes are recorded; then s7 step 4 reads them | plan 4 s2; 02_TRAPS 16 Oct | RULED |
| X5 | The insurance copies (16 Oct, `_ins` names) stay as they are; Tuesday's names are new (`_2026-10-20_2210`, `win`), so no file in Downloads is overwritten (02_TRAPS: never reuse a name) | `eurusd_window_p4_raw.sha256` | VERIFIED (names) |
| X6 | wine-d's dump dialog shows the chunk input's OLD comment ("ticks read per CopyTicksRange call"): the input is minutes; read the rows back by order and value | 02_TRAPS 16 Oct night | RECORDED |
| X7 | B, C, D stay frozen until this export is done: D's two-arm build is Wed 21 Oct in market hours, after it | D's runbook "When" | RULED |

**One worked example.** The window ends 22:00Z; a EURUSD exit that fills at 21:59:58Z on C is archived by the
worker a minute or two later, so an export at 22:01Z could miss it while one at 22:10Z holds it. Plan 3 lost
nothing at 22:13Z; the early run at 21:45Z was short by 849 bytes on B (`eurusd_holdout_raw.sha256`).

## 1. WHAT "EXPORTED AND HASHED ONLY" MEANS HERE

- Allowed on the seven files: copy, size in bytes, sha256, and the FIRST line of each sends and archive file (its
  `_meta` line). For the tick file: the dump's own `TICKS|` log lines.
- Not allowed until step 8's record is committed: opening the files in a script, a replay run, `compare.py`,
  T0, `score_plan3.py`, any count or statistic of their rows.

## 2. STEPS

**Step 1 (desktop, PowerShell in `D:\pipshed`, from 22:10Z): the sends and the archives.** Six files.

    foreach ($f in 'B','C','D') { railway ssh --service archive-worker -i "$HOME\.ssh\id_ed25519" python scripts/archive_counts.py --export-sends --instance "GRIND_EURUSD_OPT$f" | Set-Content -Encoding utf8 "$HOME\Downloads\sends_EURUSD_OPT${f}_2026-10-20_2210.jsonl"; railway ssh --service archive-worker -i "$HOME\.ssh\id_ed25519" python scripts/archive_counts.py --export-archive --instance "GRIND_EURUSD_OPT$f" | Set-Content -Encoding utf8 "$HOME\Downloads\archive_EURUSD_OPT${f}_2026-10-20_2210.jsonl" }

**Step 2 (desktop): sizes, hashes and first lines.**

    Get-ChildItem "$HOME\Downloads\*_EURUSD_OPT?_2026-10-20_2210.jsonl" | ForEach-Object { '{0} {1} {2}' -f $_.Name, $_.Length, (Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLower(); Get-Content $_.FullName -TotalCount 1 }

Expected: six names, each a size well above zero (the 16 Oct sends were about 1.0-1.1 MB) and a 64-character
hash, each followed by its `_meta` line (`{"table": "_meta", ... "instance": "GRIND_EURUSD_OPT<f>"}`, with
`"sends": true` or `"archive": true`). STOP on a missing file, a size of a few bytes, or a first line that is an
error text: re-run step 1 for that file only, under the same name.

**Step 3 (wine-d, VNC, from 22:30Z = 01:30 server): the EURUSD tick dump.** On a FRESH EURUSD chart (never an EA
chart), drag `grind_tick_dump` from Scripts and TYPE these in the inputs dialog (VNC takes typing, not paste).
Read every row back before OK (X6: the chunk row's label is old; its value is minutes):

    InpSymbols      EURUSD
    InpFrom         2026.10.14 01:30
    InpTo           2026.10.21 01:30
    InpChunkMinutes 60
    InpRetries      5
    InpProbeOnly    false
    InpTag          win

`InpTo` must NOT be empty and `InpProbeOnly` must be false. The file will be `ticks_53077984_EURUSD_win.csv`.
Close the chart afterwards.

**Step 4 (desktop): the dump's log lines.**

    ssh root@216.128.158.33 'iconv -f UTF-16LE -t UTF-8 /home/khalid/.mt5/drive_c/Program*Files/MetaTrader*5/MQL5/logs/20261020.log | grep -a -e TICKS | tail -5'

Expected: one `TICKS|EURUSD|ticks=...|bad_px=1|time_back=0|...` line, no EMPTY, FAILED or DELETED line, then
`TICKS|END`; `first=2026.10.14 01:30:00.144` (the insurance's first tick, the same span start) and `last` before
`2026.10.21 01:30`. **`bad_px` 2 or more, or `time_back` above 0: STOP** (X3). `bad_px=0`: report it and go on.

**Step 5 (desktop): the hash on the box.**

    ssh root@216.128.158.33 'sha256sum /home/khalid/.mt5/drive_c/Program*Files/MetaTrader*5/MQL5/Files/ticks_53077984_EURUSD_win.csv; stat -c %s /home/khalid/.mt5/drive_c/Program*Files/MetaTrader*5/MQL5/Files/ticks_53077984_EURUSD_win.csv'

**Step 6 (desktop): copy it to Downloads.**

    scp "root@216.128.158.33:/home/khalid/.mt5/drive_c/Program*Files/MetaTrader*5/MQL5/Files/ticks_53077984_EURUSD_win.csv" "$HOME\Downloads"

**Step 7 (desktop): the hash on the desktop.**

    Get-ChildItem "$HOME\Downloads\ticks_53077984_EURUSD_win.csv" | ForEach-Object { '{0} {1} {2}' -f $_.Name, $_.Length, (Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLower() }

It must equal step 5's hash and size. STOP if not: copy again.

**Step 8 (Claude): the record.** The seven names, sizes and hashes, and step 4's `TICKS|` lines, go into
`research/replay/inputs/eurusd_window_p4_raw.sha256` under "THE WINDOW SET", and the handoff, as one docs
patch. Claude does not stage or open the files for this. Once the operator has pushed it, plan 4 s7 step 4
(s5 below) may read them.

## 3. NEGATIVE SPACE

- No script, replay, `compare.py`, T0 or scorer on any of the seven files before step 8's record is pushed.
- No preset file for the dump. No dump on an EA chart. Nothing on wine-d between 20:50Z and 21:15Z (the carry
  window; the dump is at 22:30Z).
- No fleet action: no compile, no reload, no chart with an EA touched (D's build is Wednesday, X7).
- No change to any mark, tolerance, match rule, window or code of plan 4; `8044284` / `a335ef0` unchanged.

## 4. FAILURE MODES (STOP and report; do not improvise)

- `railway ssh` fails or a file is a few bytes long: report its first line.
- The dump's log shows EMPTY, FAILED, DELETED, `bad_px` 2 or more, `time_back` above 0, or no `TICKS|END`.
- The two tick hashes differ after a second copy.
- wine-d shows a restart, a new login or an alert while you are on it.
- **wine-d is logged out of IC, or the dump cannot reach the server (C150):** never log in again with other
  details. Steps 1-2 still run (pipshed, not IC). The insurance dump (`win_ins`, 14 Oct 01:30 to 17 Oct 00:00
  server) does NOT cover the window's Mon and Tue: whether plan 4 can be scored then is a plan 4 note BEFORE
  any window file is read (the operator's call).

## 5. AFTER THE RECORD: PLAN 4 s7 STEP 4 (Claude, on `8044284` / `a335ef0`; NOT this runbook's steps)

In order, as plan 3 s7, each through its own message: the join of w2h and `win` at `2026.10.14 01:30` server
(the seam checked: no gap, no overlap); `build_holdout.py` from `plan4-tools` `a335ef0` with the `_2210` sends of
13 Oct as `--sends-extra-*` (rows deduplicated by `send_logs.id`, plan 4 s3) and `--window-end-ms
1792544400000`; the manifest; T0; the twelve runs on `D:\mt5-replay` (`replay-plan4` `8044284`); `compare.py
--t0-price order`; `score_plan3.py --cut-ms 1792108800000 --tol results/plan3/live_spread_n3.txt`; the verdict
by plan 4 s5 (from the T0 / T1 table and the counts verdict, not the report's last line).

Line count: 121
