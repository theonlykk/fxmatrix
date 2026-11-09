This message has a line count at the bottom

# RUNBOOK -- WIND-DOWN: KEEP EVERYTHING, THEN CLOSE wine-test, wine-d AND wine-e

| | |
|---|---|
| Why | The operator ruled on C162 (Sun 8 Nov 22:18 EST = 9 Nov 03:18Z): **wind the effort down**; close the extra Vultr boxes; keep pipshed alive with one small FTMO fleet (C's t2) and a tick recorder on ONE box (HANDOFF s93 continued 5). This runbook is only the first part: **every box's data safely on the desktop before its box is destroyed.** |
| Closes | **wine-test** (Fleet B, IC demo 53066709), **wine-d** (Fleet D, IC demo 53077984), **wine-e** (Fleet E, FTMO trial 1515045375, closed 4 Nov). **wine-c stays** (Fleet C trades on; it becomes the last box). |
| Who | The operator runs every step. Claude gives ONE step per message and reads each result from `D:\fxmatrix-exports\winddown\` itself (no pasting). **No box is destroyed until Claude has read its verify file and said so in the chat.** |
| Order | Section 1 once; then **wine-test as the pilot** (s3), slowly; then wine-d (s3 again); then wine-e (s4); pipshed's exports (s5) after B and D are stopped and **before 17 Nov** (pipshed deletes `send_logs` after 14 days: E's 4 Nov storm goes on 18 Nov). One box at a time. |
| Writes | Per box, in `D:\fxmatrix-exports\winddown\<host>\`: the core, cache and AppData archives, their manifest and sha256, the archive script's output, the desktop's verify file and the box's repo state; for E, the broker's deal history and MetriX's PDF and trading-history CSV. Then pipshed's exports in `...\winddown\pipshed\`. Nothing on any box is deleted by hand. |
| Reviewed | Argon (`reviews/argon_review_winddown.md` on `review/argon-winddown`, `0fbd7ee`): SOUND WITH CHANGES, 93 of 93 quotes exact; every change checked and taken (s0 X11-X14). |

## 0. AUDIT TRAIL

| # | Fact | Where | Status |
|---|---|---|---|
| X1 | Sizes (9 Nov ~04:30Z): MQL5 7.2 GB on wine-test (its logs 7.1), 5.4 on wine-c, 7.9 on wine-d (Files 1.6: the IC tick dumps), 2.0 on wine-e; `Bases` 2.0 / 1.5 / 1.5 / 4.1 GB; every disk at least 42 GB free; `zstd` 1.5 and `xz` on all four; 2 CPUs each | `docs/runbooks/winddown/winddown_survey_1.txt`, `_2.txt` | READ |
| X2 | The broker's deal history was last dumped on **3 Oct** (`history_<login>.csv` in `MQL5/Files`, 04:20-04:26Z) on wine-test, wine-c, wine-d; **never on wine-e**. The dump script is not at the top of `MQL5/Scripts` on the three IC boxes (s2 finds it) | same; `scripts/grind_history_dump.mq5` | READ |
| X3 | `grind_history_dump.mq5`: read-only, safe beside live EAs; every deal since `InpFrom` (default `2026.09.01 00:00` server, before any of these accounts opened) to `MQL5\Files\history_<login>.csv`, **overwriting** the 3 Oct file (a superset); prints `HISTDUMP|account=..|deals=N|written=N|bad=0|file=..` | `scripts/grind_history_dump.mq5` 1-15, 43, 91 | READ |
| X4 | The EA flushes queued archive events to pipshed every 2 s from `OnTimer`; `OnDeinit` does not flush: so Algo Trading OFF, **wait a minute**, THEN exit | `docs/runbooks/twoarm-build-e.md` s3 (Fleet A's close, Oct) | READ |
| X5 | Exit MT5 gracefully (File -> Exit, or `wine taskkill` without `/F`), never a hard kill | 02_TRAPS (graceful stop) | RULED |
| X6 | **Under Wine the MT5 process is not found by NAME:** `pgrep -a terminal64` printed nothing on three boxes whose terminals were running. `archive_box.sh` matches the full command line instead, any case, for `terminal64` or `metaeditor64`, skipping its own parent shells | survey 1; `tools/winddown/archive_box.sh` | READ |
| X7 | `archive_box.sh <host>` (as root): refuses while MT5 or MetaEditor runs or if any output exists; archives the **whole** MT5 folder (executables included, X13) less `Bases/*/history` and `Bases/*/ticks` into `_core.tar.zst`, those caches into `_cache.tar.zst`, the Wine user's `AppData/Roaming/MetaQuotes` (MQL5's common Files) into `_appdata.tar.zst`; lists every file in `_manifest.txt`; tests the archives; counts their files against the manifest root by root (a failed `tar` or `zstd` in the count now stops it, X11); writes `.sha256` (four files); prints `ARCHIVE|PASS` or `ARCHIVE|FAIL`. 9 tests pass on a fake drive_c | `tools/winddown/archive_box.sh`, `test_archive_box.sh` | TESTED |
| X8 | pipshed: `archive_counts.py --export-archive` **without** `--instance` writes EVERY row of `config_events`, `ea_events`, `fill_logs`, `scalp_history` as JSON lines (`send_logs` keep only 14 days and are not in it) | pipshed `scripts/archive_counts.py` docstring and `main` (`b9d2d22`) | READ |
| X9 | **E's MT5 stays closed** (standing rule since 4 Nov): nothing on wine-e starts it. E's deals come from the DESKTOP terminal logged in to 1515045375, as Fleet A's in October, if FTMO still lets the closed trial log in | HANDOFF s93; `twoarm-build-e.md` s4 | RULED |
| X10 | Never reuse a file name; never overwrite | 02_TRAPS | RULED |
| X11 | Argon 1.1 (DEFECT, taken): the old count's `|| true` masked a failed `tar -tvf`; shown here: a tar stream cut inside a file, in a valid zstd frame, passed `zstd -t` and counted 1 file; the new count exits 2 | review 1.1; sandbox check 9 Nov | TESTED |
| X12 | pipshed (Argon 6.2, taken): `send_logs` are deleted after 14 days (`archive_worker.py` 942) and are exported only per instance (`--export-sends` needs `--instance`); `state_snapshots` (the 1-minute series since 8 Oct) only by `--export-snapshots --from --to`; `daily_snapshots` are derived by the worker (`derived_at`) from rows in the archive, not exported; the archive queues' lengths are on `/api/g/<token>/archive/` | pipshed `b9d2d22`: `archive_counts.py` 47, 79, 97-106, 407-414; `archive_worker.py` 30-32, 125-140, 942; `app.py` 3754-3772 | READ |
| X13 | MT5 **build 6274** (today's installer) does not start under Wine 9.0; the boxes run **6231**'s three binaries, first copied from wine-d (Argon 7.2): the archive now keeps every executable | `06_LINUX_WINE_BOX.md` 417-420 | READ |
| X14 | Argon 4, 5.2, 7.1 (GAPs, taken): a plain-text Global Variables list (`grind_gv_list`, as Fleet A's close); MetriX's trading-history CSV for E, and E's 95 close-out deals in `logs/20261104.log`; each box's repo checked for uncommitted or unpushed work before any Destroy | review 4, 5.2, 7.1; `twoarm-build-e.md` s3-s4 | RULED |

**One worked example.** wine-test's `MQL5/logs` is 7.1 GB of UTF-16 text, which compresses many times over; the
core archive should come to well under a tenth of the folder. The script counts files: if the manifest lists 9,412
MT5 files and the core and cache archives hold 9,411, it prints `ARCHIVE|FAIL` and the box is not destroyed.

## 1. ONCE, BEFORE ANY BOX (desktop PowerShell)

1. `D:\fxmatrix`: `git pull` (this runbook and `tools\winddown\` on `main`).
2. Space and folders (at least 15 GB free on D: expected):

       Get-PSDrive D | Select-Object Used,Free; 'wine-test','wine-d','wine-e','pipshed' | ForEach-Object { New-Item -ItemType Directory -Force "D:\fxmatrix-exports\winddown\$_" | Out-Null }

## 2. THE THREE BOXES BEFORE ANYTHING (read-only; wine-d and wine-e ask root's password)

    'box1','root@216.128.158.33','root@104.207.140.130' | ForEach-Object { "=== $_"; ssh $_ '{ git -C /home/khalid/fxmatrix-repo status -sb; git -C /home/khalid/fxmatrix-repo log --oneline origin/main..HEAD; ls -la /root; find /home/khalid/.mt5/drive_c -iname grind_history_dump.ex5 -o -iname grind_gv_list.ex5; } 2>&1' } | Out-File -Encoding utf8 D:\fxmatrix-exports\winddown\boxes_before.txt

Claude reads it: each box's repo clean and nothing unpushed (else that work is copied off first), what `/root` holds,
and on wine-test and wine-d both scripts found. A script missing on an IC box: STOP; Claude gives the
copy-and-compile step for that box.

## 3. ONE IC BOX (wine-test = `box1`, label `wine-test`; then wine-d = `root@216.128.158.33`, label `wine-d`)

1. **The box's desktop** (connect as usual), EAs still running: Navigator -> Scripts -> `grind_history_dump` onto
   any chart, `InpFrom` left at `2026.09.01 00:00`, OK. Experts tab: `HISTDUMP|account=<login>|...|bad=0`. Then
   `grind_gv_list` onto the chart, `InpContains` left at `GRIND`: `GVLIST|account=<login>|total=..|written=..`. Both
   files stay in `MQL5\Files` and go into the core archive.
2. **Algo Trading OFF** (toolbar). Wait **one full minute** by the clock (X4).
3. **File -> Exit.** Close the viewer. The demo account keeps its positions and orders; nothing more is done to it.
4. Desktop: the script to the box (wine-d asks the password):

       scp D:\fxmatrix\tools\winddown\archive_box.sh box1:/root/

5. Desktop: run it (several minutes; the output also lands in the box's folder):

       ssh box1 'bash /root/archive_box.sh wine-test' | Tee-Object -FilePath D:\fxmatrix-exports\winddown\wine-test\archive_run.txt

   It must end `ARCHIVE|PASS|wine-test`. `ARCHIVE|ABORT|MT5 or MetaEditor is running` means step 3 did not
   finish (or MetaEditor is open): back to step 3 (s6).
6. Desktop: copy the five files off:

       scp "box1:/root/winddown_wine-test_*" "box1:/root/winddown_wine-test.sha256" D:\fxmatrix-exports\winddown\wine-test\

7. Desktop: verify them against the box's hashes:

       $d = 'D:\fxmatrix-exports\winddown\wine-test'; Get-Content -ErrorAction Stop "$d\winddown_wine-test.sha256" | ForEach-Object { $h, $n = $_ -split '\s+', 2; $n = $n.TrimStart('*'); $f = Join-Path $d $n; if (Test-Path -LiteralPath $f) { $a = (Get-FileHash -LiteralPath $f -Algorithm SHA256).Hash.ToLower(); $r = if ($a -eq $h) { 'MATCH' } else { 'MISMATCH' } } else { $r = 'MISSING' }; "$r $n" } | Out-File -Encoding utf8 "$d\verify_wine-test.txt"

8. **Claude reads** `archive_run.txt`, `verify_wine-test.txt` (**four MATCH**, no MISMATCH or MISSING) and the
   manifest (today's `history_<login>.csv` and `gv_list_<login>.csv` in it), and says in the chat: **"wine-test may
   be destroyed."** Only then:
9. **The operator, Vultr:** `fxgrind-wine-test` -> Destroy. (No snapshot: the archives are the record.)

## 4. wine-e (`root@104.207.140.130`, password; label `wine-e`). E's MT5 is never started (X9)

1. **Desktop terminal** (Algo Trading OFF there), File -> Login to Trade Account: 1515045375 on its FTMO server.
   If it logs in: `grind_history_dump`, `InpFrom` `2026.10.20 00:00`; then copy `history_1515045375.csv` from the
   desktop terminal's `MQL5\Files` (File -> Open Data Folder) to `D:\fxmatrix-exports\winddown\wine-e\`. If FTMO
   refuses the login, say so: E's deals before the close-out then rest on pipshed's archive (s5); the 95 broker
   close-out deals of 4 Nov 01:36:55-56Z, which no EA saw, rest in `logs/20261104.log` and `Bases/<server>/trades`
   inside the core archive, and in MetriX's CSV (step 2); `review_1104\snap_1102_1104.csv` holds the minute marks.
2. The operator: FTMO MetriX for 1515045375, **as a PDF and its trading-history CSV**, into the same folder.
3. Then s3 steps 4-9 with `root@104.207.140.130` and `wine-e`. The script refuses if anything has started MT5.

## 5. PIPSHED's EXPORTS (desktop, `D:\pipshed`; after B and D are stopped; before 17 Nov)

1. Claude reads pipshed's archive status itself (`/api/g/<token>/archive/`, X12): `queue_len`, `processing_len`
   and `deadletter_len` all 0, so no final event of B or D is still queued.
2. Row counts (to see the sizes before the exports):

       railway ssh --service archive-worker -i "$HOME\.ssh\id_ed25519" python scripts/archive_counts.py --limit 0 | Out-File -Encoding utf8 D:\fxmatrix-exports\winddown\pipshed\counts.txt

3. Then, one command a message, each into its own new file in `...\winddown\pipshed\`, Claude giving each:
   (a) `--export-archive` (every row of `config_events`, `ea_events`, `fill_logs`, `scalp_history`, all instances,
   X8); (b) `--export-snapshots --csv` from 2026-10-08 to the day of the export (`state_snapshots`, all instances);
   (c) `--export-sends --instance <id>` for every instance the archive names (`send_logs`: the last 14 days, E's
   storm of 4 Nov among them). `daily_snapshots` are derived from (a) and are not exported (X12). Each file's size,
   line count and hash recorded. pipshed itself stays up (the operator's ruling); these are the offline copy.

## 6. NEGATIVE SPACE AND FAILURE MODES

- **Not touched:** wine-c and Fleet C (trading on IC; its archive comes when it closes, and it keeps a copy of the
  6231 binaries meanwhile, X13); pipshed's services (a later document); E's MT5. No `taskkill /F`. No file deleted
  on a box by hand: a box's files go only when Vultr destroys it.
- `ARCHIVE|ABORT|... exists`: an earlier run left files. STOP; do not delete them; Claude reads them first.
- `ARCHIVE|FAIL`: STOP; the box stays; Claude reads the manifest against the archives.
- A `MISMATCH` or `MISSING`: copy that one file again into a new subfolder `retry1\` (never over the first copy)
  and verify again.
- The desktop runs short of space: STOP before the next box; nothing is lost while the box stands.
- `HISTDUMP|SELECT_FAILED`, `bad` above 0 or a `GVLIST|FILE_OPEN_FAILED`: STOP before step 2; the EAs are still
  running and nothing is lost.

## 7. RECORD

Claude writes the HANDOFF block: per box the archive sizes, the four hashes, the file counts, the deal and GV
counts, and the time Vultr destroyed it; for pipshed each export's size, lines and hash.

Line count: 127
