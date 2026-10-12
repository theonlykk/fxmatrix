This message has a line count at the bottom

# PLAN 3 HOLDOUT: TUE 13 OCT EXPORT AND HASH (COMMAND LIST)

| | |
|---|---|
| For | `docs/research/replay-calibration-eurusd-3.md` s7, first bullet: the holdout's data **exported and hashed ONLY** |
| When | Tue 13 Oct 2026. Steps 1-2 from **22:10Z** (18:10 Toronto); step 3 from **22:30Z** (18:30 Toronto) |
| Who | The operator runs every command. Claude gives ONE step per message and waits for its output |
| Writes | Seven files in `Downloads` (3 sends, 3 archives, 1 tick file) and their sha256 in git. Nothing else |
| Status | Written 12 Oct (HANDOFF s80 continued); not yet run |

## 0. AUDIT TRAIL

| # | Fact | Where | Status |
|---|---|---|---|
| X1 | `--export-sends --instance X`: every send_logs row of one instance, a `_meta` line first; refuses without `--instance` | pipshed `scripts/archive_counts.py` (`6ea487e`) | READ |
| X2 | `--export-archive --instance X`: every row of config_events, ea_events, fill_logs, scalp_history for that instance | same file, `export_archive(cur, instance)` | READ |
| X3 | send_logs keep 14 days: 9 Oct's rows go on 23 Oct. The 9 Oct export already holds B's and C's sends back to their 7 Oct inits | 03_COOKBOOK retention; 02_TRAPS 2026-10-09 | RECORDED |
| X4 | PowerShell's `Set-Content -Encoding utf8` writes a BOM; the readers open with `utf-8-sig` | 02_TRAPS (1688, 2178) | RECORDED |
| X5 | `scripts/grind_tick_dump.mq5` inputs: `InpSymbols` (default `EURUSD`), `InpFrom` (server, inclusive), `InpTo` (server, exclusive; EMPTY = now), `InpChunkMinutes` 60, `InpRetries` 5, `InpProbeOnly` (default TRUE = no file), `InpTag`; file `ticks_<login>_<SYM>_<tag>.csv` in `MQL5/Files` | the script, lines 18-24, 90 | READ |
| X6 | w2 ends at 9 Oct 01:30 server; the holdout dump starts there (the seam is checked for no gap and no overlap when the inputs are built, plan 2 s7) | plan 2 s7; HANDOFF s73 | RECORDED |
| X7 | A `.set` written UTF-16LE with a BOM left `InpSymbols` and `InpTo` at their defaults (11 Oct). This list uses NO preset: four values are typed | 02_TRAPS 2026-10-11 | RECORDED |
| X8 | wine-d has no ssh short name: `root@216.128.158.33`; the MQL5 log is UTF-16LE, named by the UTC day | 06_LINUX_WINE_BOX s10 | RECORDED |
| X9 | Round 3's scoring the same evening reads live EURUSD deals and bid / ask of 12-13 Oct. Operator 12 Oct ~01:39Z: it does not spoil the holdout | plan 3 s7 note | RULED |
| X10 | IC, 12 Oct ~19:06Z: "not available in this jurisdiction"; the web dashboard locked, the terminals logged in (C150). Insurance dump taken on wine-d the same evening: `ticks_53077984_EURUSD_hold_early.csv`, 9 Oct 01:30 to 12 Oct 22:00 server, 110,670 ticks, sha256 `5669094b04844a6aece341a2a6bb8018b230b691dbccb9fd878ca23936b9cc90`, 3,793,242 bytes, in Downloads and on wine-d. Copy and hash only, like the seven | HANDOFF s80 continued 9 | RECORDED |

## 1. WHAT "EXPORTED AND HASHED ONLY" MEANS HERE

- Allowed on the seven files: copy, size in bytes, sha256, and the FIRST line
  of each sends and archive file (to see it is an export and not an error
  message). For the tick file: the dump's own `TICKS|` log lines.
- Not allowed until plan 3 s7's next step: opening the files in a script, a
  replay run, `compare.py`, T0, `score_plan3.py`, any count or statistic of
  their rows.
- Round 3's scoring (`docs/runbooks/compass-round.md` s4.2: the study export,
  wine-c's bid / ask dump, the journals) is a separate job the same evening
  and is not part of this list.

## 2. STEPS

**Step 1 (desktop, PowerShell in `D:\pipshed`, from 22:10Z): the sends and
the archives.** Six files. The archive worker runs minutes behind, hence
22:10Z and not 22:00Z.

    foreach ($f in 'B','C','D') { railway ssh --service archive-worker -i "$HOME\.ssh\id_ed25519" python scripts/archive_counts.py --export-sends --instance "GRIND_EURUSD_OPT$f" | Set-Content -Encoding utf8 "$HOME\Downloads\sends_EURUSD_OPT${f}_2026-10-13.jsonl"; railway ssh --service archive-worker -i "$HOME\.ssh\id_ed25519" python scripts/archive_counts.py --export-archive --instance "GRIND_EURUSD_OPT$f" | Set-Content -Encoding utf8 "$HOME\Downloads\archive_EURUSD_OPT${f}_2026-10-13.jsonl" }

**Step 2 (desktop): sizes, hashes and first lines.**

    Get-ChildItem "$HOME\Downloads\*_EURUSD_OPT?_2026-10-13.jsonl" | ForEach-Object { '{0} {1} {2}' -f $_.Name, $_.Length, (Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLower(); Get-Content $_.FullName -TotalCount 1 }

Expected: six names, each with a size well above zero and a 64-character
hash, each followed by its `_meta` line (`{"table": "_meta", ... "instance":
"GRIND_EURUSD_OPT<f>"}`, with `"sends": true` or `"archive": true`). STOP on a missing file, a size of a
few bytes, or a first line that is an error text: re-run step 1 for that
file only.

**Step 3 (wine-d, VNC, from 22:30Z = 01:30 server): the EURUSD tick dump.**
On a FRESH EURUSD chart (never an EA chart), drag `grind_tick_dump` from
Scripts and TYPE these in the inputs dialog (VNC takes typing, not paste).
Read every row back before OK:

    InpSymbols      EURUSD
    InpFrom         2026.10.09 01:30
    InpTo           2026.10.14 01:30
    InpChunkMinutes 60
    InpRetries      5
    InpProbeOnly    false
    InpTag          hold

`InpTo` must NOT be empty and `InpProbeOnly` must be false (its default is
true and writes no file). The file will be
`ticks_53077984_EURUSD_hold.csv`.

**Step 4 (desktop): the dump's log lines.**

    ssh root@216.128.158.33 'iconv -f UTF-16LE -t UTF-8 /home/khalid/.mt5/drive_c/Program*Files/MetaTrader*5/MQL5/logs/20261013.log | grep -a -e TICKS | tail -5'

Expected: one `TICKS|EURUSD|ticks=...|bad_px=0|time_back=0` line, no EMPTY,
FAILED or DELETED line, then `TICKS|END`. STOP on anything else.

**Step 5 (desktop): the hash on the box.**

    ssh root@216.128.158.33 'sha256sum /home/khalid/.mt5/drive_c/Program*Files/MetaTrader*5/MQL5/Files/ticks_53077984_EURUSD_hold.csv'

**Step 6 (desktop): copy it to Downloads.**

    scp "root@216.128.158.33:/home/khalid/.mt5/drive_c/Program*Files/MetaTrader*5/MQL5/Files/ticks_53077984_EURUSD_hold.csv" "$HOME\Downloads"

**Step 7 (desktop): the hash on the desktop.**

    Get-ChildItem "$HOME\Downloads\ticks_53077984_EURUSD_hold.csv" | ForEach-Object { '{0} {1} {2}' -f $_.Name, $_.Length, (Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLower() }

It must equal step 5's hash. STOP if not: copy again.

**Step 8 (Claude): the record.** The seven names, sizes and hashes (and X10's insurance file) go into
`research/replay/inputs/eurusd_holdout_raw.sha256` and the handoff, as one
docs patch. Claude does not stage or open the files for this.

## 3. NEGATIVE SPACE

- No script, replay, `compare.py`, T0 or scorer on any of the seven files.
- No preset file for the dump. No dump on an EA chart. Nothing on wine-d
  between 20:50Z and 21:15Z (the carry window).
- No fleet action: no compile, no reload, no chart with an EA is touched.
- No change to any mark, tolerance, window or code of plan 3.

## 4. FAILURE MODES (STOP and report; do not improvise)

- `railway ssh` fails or a file is a few bytes long: report the first line.
- The dump's log shows EMPTY, FAILED, DELETED, `bad_px` or `time_back` above
  zero, or no `TICKS|END`.
- The two tick hashes differ after a second copy.
- wine-d shows a restart, a new login or an alert while you are on it.
- **wine-d is logged out of IC, or the dump cannot reach the server (X10):**
  do not log in again with other details. Steps 1-2 still run (pipshed,
  not IC). The insurance file stands in for step 3; whether plan 3's
  holdout window ends at 12 Oct 22:00 server is the operator's call, as a
  plan 3 note BEFORE any holdout file is read.

Line count: 121
