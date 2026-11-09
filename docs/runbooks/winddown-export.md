This message has a line count at the bottom

# RUNBOOK -- WIND-DOWN: KEEP EVERYTHING, THEN CLOSE wine-test, wine-d AND wine-e

| | |
|---|---|
| Why | The operator ruled on C162 (Sun 8 Nov 22:18 EST = 9 Nov 03:18Z): **wind the effort down**; close the extra Vultr boxes; keep pipshed alive with one small FTMO fleet (C's t2) and a tick recorder on ONE box (HANDOFF s93 continued 5). This runbook is only the first part: **every box's data safely on the desktop before its box is destroyed.** |
| Closes | **wine-test** (Fleet B, IC demo 53066709), **wine-d** (Fleet D, IC demo 53077984), **wine-e** (Fleet E, FTMO trial 1515045375, closed 4 Nov). **wine-c stays** (Fleet C trades on; it becomes the last box). |
| Who | The operator runs every step. Claude gives ONE step per message and reads each result from `D:\fxmatrix-exports\winddown\` itself (no pasting). **No box is destroyed until Claude has read its verify file and said so in the chat.** |
| Order | Section 1 once; then **wine-test as the pilot** (s3), slowly; then wine-d (s3 again); then wine-e (s4); pipshed's archive (s5) after B and D are stopped. One box at a time. |
| Writes | Per box, in `D:\fxmatrix-exports\winddown\<host>\`: the core and cache archives, their manifest and sha256, the archive script's output and the desktop's verify file; for E, the broker's deal history and MetriX PDF. Then pipshed's whole archive in `...\winddown\pipshed\`. Nothing on any box is deleted by hand. |

## 0. AUDIT TRAIL

| # | Fact | Where | Status |
|---|---|---|---|
| X1 | Sizes (8 Nov ~04:30Z): MQL5 7.2 GB on wine-test (its logs 7.1), 5.4 on wine-c, 7.9 on wine-d (Files 1.6: the IC tick dumps), 2.0 on wine-e; `Bases` 2.0 / 1.5 / 1.5 / 4.1 GB; every disk at least 42 GB free; `zstd` 1.5 and `xz` on all four; 2 CPUs each | `docs/runbooks/winddown/winddown_survey_1.txt`, `_2.txt` | READ |
| X2 | The broker's deal history was last dumped on **3 Oct** (`history_<login>.csv` in `MQL5/Files`, 04:20-04:26Z) on wine-test, wine-c, wine-d; **never on wine-e**. The dump script is not at the top of `MQL5/Scripts` on the three IC boxes (s2 finds it) | same; `scripts/grind_history_dump.mq5` | READ |
| X3 | `grind_history_dump.mq5`: read-only, safe beside live EAs; every deal since `InpFrom` (default `2026.09.01 00:00` server, before any of these accounts opened) to `MQL5\Files\history_<login>.csv`, **overwriting** the 3 Oct file (a superset); prints `HISTDUMP|account=..|deals=N|written=N|bad=0|file=..` | `scripts/grind_history_dump.mq5` 1-15, 43, 91 | READ |
| X4 | The EA flushes queued archive events to pipshed every 2 s from `OnTimer`; `OnDeinit` does not flush: so Algo Trading OFF, **wait a minute**, THEN exit | `docs/runbooks/twoarm-build-e.md` s3 (Fleet A's close, Oct) | READ |
| X5 | Exit MT5 gracefully (File -> Exit, or `wine taskkill` without `/F`), never a hard kill | 02_TRAPS (graceful stop) | RULED |
| X6 | **Under Wine the MT5 process is not found by NAME:** `pgrep -a terminal64` printed nothing on three boxes whose terminals were running. `archive_box.sh` matches the full command line instead, skipping its own parent shells | survey 1; `tools/winddown/archive_box.sh` | READ |
| X7 | `archive_box.sh <host>` (as root): refuses while MT5 runs or if any output exists; archives `Bases` (less its `history` / `ticks` caches), `Config`, `logs`, `MQL5`, `Profiles`, `Tester`, `llm-agent` into `_core.tar.zst`, the caches into `_cache.tar.zst`, lists every file in `_manifest.txt`, tests both archives, counts their files against the manifest, writes `.sha256`, prints `ARCHIVE|PASS` or `ARCHIVE|FAIL`. 8 tests pass on a fake MT5 folder | `tools/winddown/archive_box.sh`, `test_archive_box.sh` | TESTED |
| X8 | pipshed: `archive_counts.py --export-archive` **without** `--instance` writes EVERY row of `config_events`, `ea_events`, `fill_logs`, `scalp_history` as JSON lines (`send_logs` keep only 14 days and are not in it) | pipshed `scripts/archive_counts.py` docstring and `main` (`b9d2d22`) | READ |
| X9 | **E's MT5 stays closed** (standing rule since 4 Nov): nothing on wine-e starts it. E's deals come from the DESKTOP terminal logged in to 1515045375, as Fleet A's in October, if FTMO still lets the closed trial log in | HANDOFF s93; `twoarm-build-e.md` s4 | RULED |
| X10 | Never reuse a file name; never overwrite | 02_TRAPS | RULED |

**One worked example.** wine-test's `MQL5/logs` is 7.1 GB of UTF-16 text, which compresses many times over; the
core archive should come to well under a tenth of the folder. The script counts files: if the manifest lists 9,412
and the two archives hold 9,411, it prints `ARCHIVE|FAIL` and the box is not destroyed.

## 1. ONCE, BEFORE ANY BOX (desktop PowerShell)

1. `D:\fxmatrix`: `git pull` (this runbook and `tools\winddown\` on `main`).
2. Space and folders (at least 15 GB free on D: expected):

       Get-PSDrive D | Select-Object Used,Free; 'wine-test','wine-d','wine-e','pipshed' | ForEach-Object { New-Item -ItemType Directory -Force "D:\fxmatrix-exports\winddown\$_" | Out-Null }

## 2. WHERE THE DUMP SCRIPT IS (read-only; wine-d asks root's password)

    foreach ($h in 'box1','root@216.128.158.33') { "=== $h"; ssh $h 'find /home/khalid/.mt5/drive_c -iname grind_history_dump.ex5' }

Each box should print one path. If one prints nothing, STOP: Claude gives the copy-and-compile step for that box.

## 3. ONE IC BOX (wine-test = `box1`, label `wine-test`; then wine-d = `root@216.128.158.33`, label `wine-d`)

1. **The box's desktop** (connect as usual), EAs still running: Navigator -> Scripts -> `grind_history_dump` onto
   any chart, `InpFrom` left at `2026.09.01 00:00`, OK. Experts tab: `HISTDUMP|account=<login>|...|bad=0`. The file
   stays in `MQL5\Files` and goes into the core archive.
2. **Algo Trading OFF** (toolbar). Wait **one full minute** by the clock (X4).
3. **File -> Exit.** Close the viewer. The demo account keeps its positions and orders; nothing more is done to it.
4. Desktop: the script to the box (wine-d asks the password):

       scp D:\fxmatrix\tools\winddown\archive_box.sh box1:/root/

5. Desktop: run it (several minutes; the output also lands in the box's folder):

       ssh box1 'bash /root/archive_box.sh wine-test' | Tee-Object -FilePath D:\fxmatrix-exports\winddown\wine-test\archive_run.txt

   It must end `ARCHIVE|PASS|wine-test`. `ARCHIVE|ABORT|terminal64.exe is running` means step 3 did not finish:
   back to step 3 (s6).
6. Desktop: copy the four files off:

       scp "box1:/root/winddown_wine-test_*" "box1:/root/winddown_wine-test.sha256" D:\fxmatrix-exports\winddown\wine-test\

7. Desktop: verify them against the box's hashes:

       $d = 'D:\fxmatrix-exports\winddown\wine-test'; Get-Content "$d\winddown_wine-test.sha256" | ForEach-Object { $h, $n = $_ -split '\s+', 2; $n = $n.TrimStart('*'); $a = (Get-FileHash "$d\$n" -Algorithm SHA256).Hash.ToLower(); $r = if ($a -eq $h) { 'MATCH' } else { 'MISMATCH' }; "$r $n" } | Out-File -Encoding utf8 "$d\verify_wine-test.txt"

8. **Claude reads** `archive_run.txt`, `verify_wine-test.txt` (three MATCH) and the manifest (today's
   `history_<login>.csv` in it), and says in the chat: **"wine-test may be destroyed."** Only then:
9. **The operator, Vultr:** `fxgrind-wine-test` -> Destroy. (No snapshot: the archives are the record.)

## 4. wine-e (`root@104.207.140.130`, password; label `wine-e`). E's MT5 is never started (X9)

1. **Desktop terminal** (Algo Trading OFF there), File -> Login to Trade Account: 1515045375 on its FTMO server.
   If it logs in: `grind_history_dump`, `InpFrom` `2026.10.20 00:00`; then copy `history_1515045375.csv` from the
   desktop terminal's `MQL5\Files` (File -> Open Data Folder) to `D:\fxmatrix-exports\winddown\wine-e\`. If FTMO
   refuses the login, say so: E's deals then rest on pipshed's archive (s5), `review_1104\snap_1102_1104.csv` and
   the account's own trade database inside the core archive (`Bases/<server>/trades`).
2. The operator: FTMO MetriX for 1515045375 as a PDF into the same folder.
3. Then s3 steps 4-9 with `root@104.207.140.130` and `wine-e`. The script refuses if anything has started MT5.

## 5. PIPSHED's WHOLE ARCHIVE (desktop, `D:\pipshed`; after B and D are stopped)

1. Row counts first (to see the size before the export):

       railway ssh --service archive-worker -i "$HOME\.ssh\id_ed25519" python scripts/archive_counts.py --limit 0 | Out-File -Encoding utf8 D:\fxmatrix-exports\winddown\pipshed\counts.txt

2. Claude reads the counts and gives the export command (all rows, X8) with its file name; then its size, line
   count and hash are recorded. pipshed itself stays up (the operator's ruling); this is the offline copy.

## 6. NEGATIVE SPACE AND FAILURE MODES

- **Not touched:** wine-c and Fleet C (trading on IC; its archive comes when it closes); pipshed's services (a later
  document); E's MT5. No `taskkill /F`. No file deleted on a box by hand: a box's files go only when Vultr destroys it.
- `ARCHIVE|ABORT|... exists`: an earlier run left files. STOP; do not delete them; Claude reads them first.
- `ARCHIVE|FAIL`: STOP; the box stays; Claude reads the manifest against the archives.
- A `MISMATCH`: copy that one file again into a new subfolder `retry1\` (never over the first copy) and verify again.
- The desktop runs short of space: STOP before the next box; nothing is lost while the box stands.
- `HISTDUMP|SELECT_FAILED` or `bad` above 0: STOP before step 2; the EAs are still running and nothing is lost.

## 7. RECORD

Claude writes the HANDOFF block: per box the archive sizes, the three hashes, the file counts, the deal counts, and
the time Vultr destroyed it.

Line count: 108
