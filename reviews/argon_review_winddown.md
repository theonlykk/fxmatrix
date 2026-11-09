This message has a line count at the bottom

# ARGON REVIEW: WIND-DOWN EXPORT RUNBOOK AND ARCHIVE SCRIPT

| Field | Value |
|---|---|
| Reviewer | Argon |
| Date | 9 Nov 2026 |
| Branch | `review/argon-winddown` |
| Base commit (`origin/main`) | `086e500da3fad75eceb7df240388c3f3a87a9bce` (`086e500`) |
| pipshed commit (`main`) | `b9d2d2208019d425c41e065197065be4ab1ed668` (`b9d2d22`) |
| Primary documents read (all lines) | `docs/runbooks/winddown-export.md` (1-108); `tools/winddown/archive_box.sh` (1-74); `tools/winddown/test_archive_box.sh` (1-64); `prompts/argon_review_winddown.md` (1-56) |
| FXMatrix sources read (all lines) | `docs/runbooks/winddown/winddown_survey_1.txt` (1-72); `docs/runbooks/winddown/winddown_survey_2.txt` (1-142); `scripts/grind_history_dump.mq5` (1-92); `scripts/grind_gv_list.mq5` (1-47); `docs/runbooks/twoarm-build-e.md` (1-369); `handoffs/Handover/02_TRAPS.md` (1-3118); `handoffs/Handover/06_LINUX_WINE_BOX.md` (1-437); `handoffs/HANDOFF_2026-09-24.md` (8800-9350) |
| pipshed sources read (`b9d2d22`) | `scripts/archive_counts.py` (1-547); `archive_worker.py` (1-1385); `app.py` (1-4660); `db_migrate.py` (1-89); `migrations/001_archive_phase1.sql` (1-135); `migrations/002_adr159_daily.sql` (1-34); `migrations/003_adr160_gated.sql` (1-14); `migrations/004_c56_rolls.sql` (1-9); `migrations/005_c137_state_snapshots.sql` (1-32) |
| Files not read | none (`not read` = none) |

---

## 1. `tools/winddown/archive_box.sh`, LINE BY LINE

### 1.1 `set -euo pipefail` vs `|| true` on lines 60-61

**Verdict: DEFECT**

Quotes:
- `tools/winddown/archive_box.sh:15` `set -euo pipefail`
- `tools/winddown/archive_box.sh:52` `tar -cf - "${EXCL[@]}" "${DIRS[@]/#/./}" | zstd -T0 -10 -q -o "$CORE"`
- `tools/winddown/archive_box.sh:54` `    tar -cf - "${CACHE[@]/#/./}" | zstd -T0 -3 -q -o "$CACH"`
- `tools/winddown/archive_box.sh:56` `    tar -cf - --files-from /dev/null | zstd -q -o "$CACH"`
- `tools/winddown/archive_box.sh:59` `zstd -t -q "$CORE" && zstd -t -q "$CACH"`
- `tools/winddown/archive_box.sh:60` `N_CORE=$(zstd -dc "$CORE" | tar -tvf - | grep -c '^-' || true)`
- `tools/winddown/archive_box.sh:61` `N_CACH=$(zstd -dc "$CACH" | tar -tvf - | grep -c '^-' || true)`
- `tools/winddown/archive_box.sh:69` `if [ "$N_MAN" -gt 0 ] && [ $((N_CORE + N_CACH)) -eq "$N_MAN" ]; then`
- `tools/winddown/archive_box.sh:70` `    echo "ARCHIVE|PASS|$LABEL"`

Analysis:
- On lines 52, 54, and 56, `set -euo pipefail` stops the script if either `tar -cf -` or `zstd` returns non-zero.
- On lines 60 and 61, however, the trailing `|| true` (added because `grep -c '^-'` exits `1` when the count is `0`, as on an empty cache archive) disables `set -e` and `pipefail` for the **entire pipeline** inside `$(...)`.
- While line 59 (`zstd -t -q`) checks the outer zstd frame checksums, if the inner tar stream in `$CORE` or `$CACH` is truncated or corrupt after the last file header (so `tar -tvf -` prints all file headers and then exits `2` with `Unexpected EOF in archive`), `|| true` swallows `tar`'s exit code `2`, `N_CORE + N_CACH` still equals `N_MAN`, and line 70 prints `ARCHIVE|PASS|$LABEL`.

Smallest fix (replace lines 60-61 of `tools/winddown/archive_box.sh`; `awk` exits `0` on count `0`, so `|| true` is removed and `pipefail` catches any `zstd -dc` or `tar -tvf -` failure):

```bash
N_CORE=$(zstd -dc "$CORE" | tar -tvf - | awk '/^-/{n++} END{print n+0}')
N_CACH=$(zstd -dc "$CACH" | tar -tvf - | awk '/^-/{n++} END{print n+0}')
```

### 1.2 Do the `--exclude` options remove only `Bases/<server>/history` and `Bases/<server>/ticks`?

**Verdict: GAP** (safe on the four surveyed boxes, but `tar` wildcards and unanchored matching are active unless disabled)

Quotes:
- `tools/winddown/archive_box.sh:35` `while IFS= read -r -d '' c; do CACHE+=("$c"); done < <(find Bases -mindepth 2 -maxdepth 2 -type d \( -name history -o -name ticks \) -print0 2>/dev/null | sort -z)`
- `tools/winddown/archive_box.sh:49` `EXCL=()`
- `tools/winddown/archive_box.sh:50` `for c in "${CACHE[@]}"; do EXCL+=(--exclude="./$c"); done`
- `tools/winddown/archive_box.sh:51` `# archive with ./ paths so each exclude names exactly one folder (no wildcards)`
- `tools/winddown/archive_box.sh:52` `tar -cf - "${EXCL[@]}" "${DIRS[@]/#/./}" | zstd -T0 -10 -q -o "$CORE"`

Analysis:
- Line 35 restricts `CACHE` to depth-2 directories under `Bases` named `history` or `ticks` (`Bases/<server>/history` and `Bases/<server>/ticks`).
- Line 51 states `(no wildcards)`, but GNU `tar` enables `--wildcards` and `--no-anchored` on `--exclude` patterns by default unless `--anchored --no-wildcards` is passed before `"${EXCL[@]}"`. If a `Bases/<server>` name ever contained glob metacharacters (`*`, `?`, `[`), `--exclude="./$c"` would glob-match instead of matching literally.
- Even if `--exclude` ever over-excluded a file from `$CORE`, that file would not be in `$CACH`, so `N_CORE + N_CACH < N_MAN` would catch it and print `ARCHIVE|FAIL` (line 72); if `--exclude` under-excluded a cache file, that file would be in both `$CORE` and `$CACH`, so `N_CORE + N_CACH > N_MAN` would also print `ARCHIVE|FAIL`.

Smallest fix (replace line 52 of `tools/winddown/archive_box.sh`):

```bash
tar -cf - --anchored --no-wildcards "${EXCL[@]}" "${DIRS[@]/#/./}" | zstd -T0 -10 -q -o "$CORE"
```

### 1.3 Can any regular file under the MT5 folder be left out of both archives without the count catching it?

**Verdict: NOT A DEFECT** (for symlinks, hard links, sparse files, spaces, newlines, leading dashes, changing files, and `Bases` server folders with spaces)

Quotes:
- `tools/winddown/archive_box.sh:33` `for d in Bases Config logs MQL5 Profiles Tester llm-agent; do [ -e "$d" ] && DIRS+=("$d"); done`
- `tools/winddown/archive_box.sh:46` `find "${DIRS[@]}" -type f -printf '%s\t%TY-%Tm-%Td_%TH:%TM\t%p\n' | LC_ALL=C sort -t $'\t' -k3 > "$MAN"`
- `tools/winddown/archive_box.sh:47` `N_MAN=$(wc -l < "$MAN")`
- `tools/winddown/archive_box.sh:54` `    tar -cf - "${CACHE[@]/#/./}" | zstd -T0 -3 -q -o "$CACH"`
- `tools/winddown/archive_box.sh:69` `if [ "$N_MAN" -gt 0 ] && [ $((N_CORE + N_CACH)) -eq "$N_MAN" ]; then`
- `tools/winddown/archive_box.sh:72` `    echo "ARCHIVE|FAIL|$LABEL|core + cache $((N_CORE + N_CACH)) against manifest $N_MAN"`
- `docs/runbooks/winddown/winddown_survey_2.txt:3` `Bases`
- `docs/runbooks/winddown/winddown_survey_2.txt:15` `uninstall.exe`

Analysis by case:
1. **Top-level folders under `MT5_ROOT`:** `winddown_survey_2.txt` (lines 3-15, 38-50, 74-86, 110-122) lists the exact top-level entries on all four boxes: `Bases`, `Config`, `llm-agent`, `logs`, `MetaEditor64.exe`, `metatester64.exe`, `MQL5`, `Profiles`, `Sounds`, `terminal64.exe`, `Terminal.ico`, `Tester`, `uninstall.exe`. Every directory other than `Sounds` is in `DIRS` (line 33).
2. **Symlinks:** `find "${DIRS[@]}" -type f` (line 46, without `-L`) does not follow symlinks and does not count `-type l`. GNU `tar -cf -` (without `-h`) records symlinks with type `l` (`lrwxrwxrwx` in `tar -tvf -`), which is not matched by `^-'`. Symlinks cannot mask a missing regular file.
3. **Hard links:** If two paths in the same archive are hard links to the same inode, `find ... -type f` counts both (`+2` in `N_MAN`), whereas `tar -cf -` (without `--hard-dereference`) records the first as `-` (`-rw-...`) and the second as `h` (`hrw-... link to ...`). That makes `N_CORE + N_CACH < N_MAN`, failing closed with `ARCHIVE|FAIL` (line 72). If one hard link were in `$CORE` and the other in `$CACH`, the two separate `tar` invocations (lines 52 and 54) each record their copy as `-` (`1 + 1 = 2`), so both copies are archived in full. Thus a hard link can never cause silent data loss.
4. **Sparse files:** Neither line 52 nor line 54 passes `-S` / `--sparse` to `tar`. Without `--sparse`, GNU `tar` stores sparse regular files as ordinary regular files (`-rw-...`, typeflag `'0'`), never `S`, so `tar -tvf -` always lists them with leading `-`.
5. **Spaces in file names and in `Bases/<server>` folders:** Line 35 reads `find ... -print0` with `IFS= read -r -d ''`, preserving spaces in server names (such as `Bases/FTMO Demo 2/ticks`). Line 46 separates fields with `\t` and sorts with `sort -t $'\t' -k3`. Lines 50, 52, and 54 quote `"${EXCL[@]}"`, `"${DIRS[@]/#/./}"`, and `"${CACHE[@]/#/./}"`.
6. **Newlines in file names:** A filename containing a literal `\n` adds an extra line to `$MAN` (`wc -l`, line 47), whereas GNU `tar -tvf -` escapes `\n` as `\n` on one line. That makes `N_MAN > N_CORE + N_CACH` and fails closed with `ARCHIVE|FAIL` (line 72).
7. **Leading dashes:** Every path passed to `find` (line 46) starts with one of `Bases`..`llm-agent`, and every path passed to `tar` (lines 50, 52, 54) is prefixed with `./`, so no file or folder name can be parsed as an option flag by `find` or `tar`.
8. **Files changing while archiving:** MT5 is stopped before `archive_box.sh` runs (lines 24-28). If another process modified or truncated a file while `tar` read it, GNU `tar` exits `1` (`file changed as we read it`), caught by `set -euo pipefail` (line 15); if a file were created or unlinked between `find` (line 46) and `tar` (lines 52-54), `N_CORE + N_CACH` would mismatch `N_MAN` at line 69.

### 1.4 Does the ancestor skip in X6 hold over `ssh`, and can it miss a real `terminal64.exe` under Wine?

**Verdict: CONFIRMED** for the ancestor skip over `ssh`; **GAP** for case-sensitive `pgrep -f` and open `MetaEditor64.exe`

Quotes:
- `tools/winddown/archive_box.sh:23` `ancestors() { local p=$$; while [ "${p:-1}" -gt 1 ]; do echo "$p"; p=$(ps -o ppid= -p "$p" | tr -d ' '); done; }`
- `tools/winddown/archive_box.sh:24` `RUNNING=$(pgrep -f terminal64 | grep -vxF -f <(ancestors) || true)`
- `tools/winddown/archive_box.sh:25` `if [ -n "$RUNNING" ]; then`
- `tools/winddown/archive_box.sh:26` `    echo "ARCHIVE|ABORT|terminal64.exe is running (pid $(echo $RUNNING)): exit MT5 first (runbook s3 step 3)"`
- `docs/runbooks/twoarm-build-e.md:99` `    setsid nohup env WINEPREFIX=$HOME/.mt5 wine "$HOME/.mt5/drive_c/Program Files/MetaTrader 5/terminal64.exe" >/dev/null 2>&1 &`
- `handoffs/Handover/02_TRAPS.md:3101` `- **A Wine "Program Error: setup.exe" on a box may be Edge's updater, not MT5's.** On wine-test at C165's compile a`

Analysis:
- **Ancestor skip over `ssh box1 'bash /root/archive_box.sh wine-test'`:** In bash, `$$` inside `<(ancestors)` resolves to the PID of the `archive_box.sh` shell itself. Walking `ps -o ppid=` until `p <= 1` outputs the PIDs of `archive_box.sh`, any parent `bash -c` spawned by `sshd`, the session `sshd`, and the daemon `sshd`. Because MT5 on every box is launched detached inside the desktop session (`setsid nohup ... terminal64.exe`, `twoarm-build-e.md` line 99), its parent is PID `1` (or the XFCE session), never `sshd` or `archive_box.sh`. Thus `grep -vxF -f <(ancestors)` never filters out a real `terminal64.exe`.
- **What `pgrep -f terminal64` can miss:** Without `-i`, `pgrep -f terminal64` is case-sensitive and would miss `TERMINAL64.EXE` if started with an uppercase command line; and if `MetaEditor64.exe` (`02_TRAPS.md` line 3103) were left open in VNC after MT5 exited, it could still write to `MQL5/`.

Smallest fix (replace line 24 of `tools/winddown/archive_box.sh`):

```bash
RUNNING=$(pgrep -fi 'terminal64|metaeditor64' | grep -vxF -f <(ancestors) || true)
```

---

## 2. THE TESTS (`tools/winddown/test_archive_box.sh`)

### 2.1 Execution report (Rule 3)

Running `bash tools/winddown/test_archive_box.sh` in the Windows PowerShell workspace (`D:\fxmatrix`) failed to launch because `bash` is not installed / not on `PATH` on this Windows machine (exit code `1`):

```text
bash : The term 'bash' is not recognized as the name of a cmdlet, function, script file, or operable program. Check the spelling of the name, or if a path was included, verify that the path is correct and try again.
At line:1 char:1
+ bash tools/winddown/test_archive_box.sh
+ ~~~~
    + CategoryInfo          : ObjectNotFound: (bash:String) [], CommandNotFoundException
    + FullyQualifiedErrorId : CommandNotFoundException
```

### 2.2 Coverage of the 8 tests and the one test to add

**Verdict: CONFIRMED** on the 8 existing tests; **GAP** on testing the `ARCHIVE|FAIL` count-mismatch branch and a parent shell whose command line mentions `terminal64`

Quotes:
- `tools/winddown/test_archive_box.sh:26` `out="$(MT5_ROOT="$R" OUT="$T/out" bash "$HERE/archive_box.sh" wine-x 2>&1)"; rc=$?`
- `tools/winddown/test_archive_box.sh:28` `ok "first run: ARCHIVE|PASS"`
- `tools/winddown/test_archive_box.sh:30` `ok "counts: 11 files = 8 core + 3 cache (executable and Sounds not kept)"`
- `tools/winddown/test_archive_box.sh:38` `ok "core holds trades, not caches; cache holds both servers' caches"`
- `tools/winddown/test_archive_box.sh:43` `ok "round trip: every kept folder identical byte for byte"`
- `tools/winddown/test_archive_box.sh:46` `ok "the .sha256 file verifies"`
- `tools/winddown/test_archive_box.sh:50` `ok "a second run with the same label refuses to overwrite"`
- `tools/winddown/test_archive_box.sh:52` `bash -c 'exec -a terminal64.exe sleep 30' & SP=$!; sleep 0.3`
- `tools/winddown/test_archive_box.sh:57` `ok "refuses while terminal64.exe runs, writes nothing"`
- `tools/winddown/test_archive_box.sh:62` `ok "a box with no caches: empty cache archive, still PASS"`
- `handoffs/HANDOFF_2026-09-24.md:9338` ``  `test_archive_box.sh` (8 / 8, including a calling shell that mentions terminal64);``

Analysis:
- The 8 tests verify: (1) `ARCHIVE|PASS`, (2) `11 = 8 + 3` count and exclusion of `terminal64.exe` and `Sounds`, (3) `trades/53066709/deals.dat` in core and both servers' caches (including `FTMO Demo 2` with a space) in cache, (4) byte-for-byte `diff -r` round-trip of `Bases Config logs MQL5 Profiles Tester`, (5) `sha256sum -c`, (6) refusal to overwrite on a second run with the same label, (7) refusal while `terminal64.exe` runs with nothing written, and (8) empty-cache box (`cache 0`, still `PASS`).
- Two things are missing:
  1. Despite `HANDOFF_2026-09-24.md` line 9338 saying `(8 / 8, including a calling shell that mentions terminal64)`, none of the invocations in `test_archive_box.sh` (lines 26, 48, 53, 60) actually put `terminal64` in the parent shell's command line (line 52 spawns a background sibling `exec -a terminal64.exe sleep 30` for the negative test).
  2. None of the 8 tests exercises the `ARCHIVE|FAIL` branch (lines 71-73 of `archive_box.sh`) where `N_CORE + N_CACH != N_MAN`.

Smallest fix (add test 9 before line 64 of `tools/winddown/test_archive_box.sh`, testing both a parent shell whose command text mentions `terminal64.exe` and a count mismatch via a hard link that triggers `ARCHIVE|FAIL` with non-zero exit code):

```bash
ln "$R/Config/common.ini" "$R/Config/common_hardlink.ini"
out5="$(bash -c 'MT5_ROOT="$1" OUT="$2" bash "$3" wine-fail # calling shell mentions terminal64.exe' _ "$R" "$T/out" "$HERE/archive_box.sh" 2>&1)"; rc=$?
rm -f "$R/Config/common_hardlink.ini"
[ $rc -ne 0 ] && echo "$out5" | grep -q '^ARCHIVE|FAIL|wine-fail|core + cache 8 against manifest 9$' || { echo "$out5"; fail "mismatch did not fail"; }
ok "calling shell mentioning terminal64.exe is skipped; count mismatch exits non-zero with ARCHIVE|FAIL"
```

---

## 3. THE POWERSHELL LINES (s1 step 2, s2, s3 steps 4-7, s5)

### 3.1 Quoting under Windows PowerShell 5.1 and `scp` with a remote glob

**Verdict: CONFIRMED**

Quotes:
- `handoffs/Handover/02_TRAPS.md:1699` `- **PowerShell: never end a native command's quoted path with a`
- `handoffs/Handover/02_TRAPS.md:1701` `  escapes the quote): give the full target file name. Remote Wine paths:`
- `handoffs/Handover/02_TRAPS.md:2133` ``- **PowerShell drops the INNER double quotes of an `ssh box '...'` command**``
- `handoffs/Handover/02_TRAPS.md:2136` `  path. Write remote commands with NO inner double quotes: glob the spaces`
- `docs/runbooks/winddown-export.md:37` `       Get-PSDrive D | Select-Object Used,Free; 'wine-test','wine-d','wine-e','pipshed' | ForEach-Object { New-Item -ItemType Directory -Force "D:\fxmatrix-exports\winddown\$_" | Out-Null }`
- `docs/runbooks/winddown-export.md:41` `    foreach ($h in 'box1','root@216.128.158.33') { "=== $h"; ssh $h 'find /home/khalid/.mt5/drive_c -iname grind_history_dump.ex5' }`
- `docs/runbooks/winddown-export.md:54` `       scp D:\fxmatrix\tools\winddown\archive_box.sh box1:/root/`
- `docs/runbooks/winddown-export.md:58` `       ssh box1 'bash /root/archive_box.sh wine-test' | Tee-Object -FilePath D:\fxmatrix-exports\winddown\wine-test\archive_run.txt`
- `docs/runbooks/winddown-export.md:64` `       scp "box1:/root/winddown_wine-test_*" "box1:/root/winddown_wine-test.sha256" D:\fxmatrix-exports\winddown\wine-test\`
- `docs/runbooks/winddown-export.md:88` `       railway ssh --service archive-worker -i "$HOME\.ssh\id_ed25519" python scripts/archive_counts.py --limit 0 | Out-File -Encoding utf8 D:\fxmatrix-exports\winddown\pipshed\counts.txt`

Analysis:
- None of the `ssh` commands (lines 41, 58, 88) contain inner double quotes inside single quotes (`02_TRAPS.md` line 2133).
- On line 64, the local path `D:\fxmatrix-exports\winddown\wine-test\` contains no spaces and is unquoted, avoiding the `\"` trailing-backslash trap (`02_TRAPS.md` lines 1699-1700).
- On line 64, `"box1:/root/winddown_wine-test_*"` has an underscore before `*`, so it matches `winddown_wine-test_core.tar.zst`, `winddown_wine-test_cache.tar.zst`, and `winddown_wine-test_manifest.txt` (lines 37-39 of `archive_box.sh`), while `"box1:/root/winddown_wine-test.sha256"` (dot, no underscore after `wine-test`) copies the `.sha256` file without duplicate transfer.

### 3.2 Does the verify line compare every hash in `.sha256` and fail visibly on a missing file?

**Verdict: DEFECT**

Quote:
- `docs/runbooks/winddown-export.md:68` `       $d = 'D:\fxmatrix-exports\winddown\wine-test'; Get-Content "$d\winddown_wine-test.sha256" | ForEach-Object { $h, $n = $_ -split '\s+', 2; $n = $n.TrimStart('*'); $a = (Get-FileHash "$d\$n" -Algorithm SHA256).Hash.ToLower(); $r = if ($a -eq $h) { 'MATCH' } else { 'MISMATCH' }; "$r $n" } | Out-File -Encoding utf8 "$d\verify_wine-test.txt"`

Analysis:
- When all three files exist in `$d`, line 68 compares every hash in `winddown_wine-test.sha256` and writes three `MATCH <filename>` lines to `verify_wine-test.txt`.
- **If one of the three files `$d\$n` is missing**, however, `Get-FileHash "$d\$n"` emits a non-terminating `ItemNotFoundException` to the console and returns `$null`; then `($null).Hash.ToLower()` throws a `RuntimeException` (`You cannot call a method on a null-valued expression`) that aborts that iteration of `ForEach-Object` **before** `"$r $n"` is output to the pipeline. As a result, `verify_wine-test.txt` **silently omits the missing file's line** (containing only 2 lines instead of writing `MISMATCH <filename>` or `MISSING <filename>` into `verify_wine-test.txt`).
- Likewise, if `winddown_wine-test.sha256` itself is missing, `Get-Content` emits a non-terminating error and `Out-File` writes a 0-byte `verify_wine-test.txt`.

Smallest fix (replace line 68 of `docs/runbooks/winddown-export.md` so a missing target file evaluates `$a = 'MISSING'` and writes `MISMATCH <filename>` into `verify_<label>.txt`, and `-ErrorAction Stop` prevents creating an empty verify file if `.sha256` is missing):

```powershell
       $d = 'D:\fxmatrix-exports\winddown\wine-test'; Get-Content -ErrorAction Stop "$d\winddown_wine-test.sha256" | ForEach-Object { $h, $n = $_ -split '\s+', 2; $n = $n.TrimStart('*'); $a = if (Test-Path -LiteralPath "$d\$n") { (Get-FileHash -LiteralPath "$d\$n" -Algorithm SHA256).Hash.ToLower() } else { 'MISSING' }; $r = if ($a -eq $h) { 'MATCH' } else { 'MISMATCH' }; "$r $n" } | Out-File -Encoding utf8 "$d\verify_wine-test.txt"
```

### 3.3 `Tee-Object`'s encoding on line 58

**Verdict: NOT A DEFECT**

Quotes:
- `docs/runbooks/winddown-export.md:58` `       ssh box1 'bash /root/archive_box.sh wine-test' | Tee-Object -FilePath D:\fxmatrix-exports\winddown\wine-test\archive_run.txt`
- `handoffs/Handover/02_TRAPS.md:2178` ``- **`--export-archive` files start with a UTF-8 BOM:** `json.loads` on``

Analysis:
- In Windows PowerShell 5.1, `Tee-Object -FilePath` has no `-Encoding` parameter and writes **UTF-16LE with BOM** (`FF FE`), whereas `Out-File -Encoding utf8` (lines 68 and 88) writes UTF-8 with BOM (`02_TRAPS.md` line 2178).
- Because `archive_run.txt` is read by Claude's file reader or PowerShell `Get-Content` (line 70), both of which decode UTF-16LE BOM transparently, no output is lost; any Python helper inspecting `archive_run.txt` should open it with `encoding='utf-16'` (or `utf-8-sig` if rewritten with `Out-File -Encoding utf8`).

---

## 4. ORDER AND GATES

### 4.1 Can any path through s3-s4 reach Vultr's Destroy before the three `MATCH` lines and Claude's go?

**Verdict: CONFIRMED** (with a minor manifest wording note for `wine-e` in s4 step 3)

Quotes:
- `docs/runbooks/winddown-export.md:9` ``| Who | The operator runs every step. Claude gives ONE step per message and reads each result from `D:\fxmatrix-exports\winddown\` itself (no pasting). **No box is destroyed until Claude has read its verify file and said so in the chat.** |``
- `docs/runbooks/winddown-export.md:70` ``8. **Claude reads** `archive_run.txt`, `verify_wine-test.txt` (three MATCH) and the manifest (today's``
- `docs/runbooks/winddown-export.md:71` ``   `history_<login>.csv` in it), and says in the chat: **"wine-test may be destroyed."** Only then:``
- `docs/runbooks/winddown-export.md:72` ``9. **The operator, Vultr:** `fxgrind-wine-test` -> Destroy. (No snapshot: the archives are the record.)``
- `docs/runbooks/winddown-export.md:82` ``3. Then s3 steps 4-9 with `root@104.207.140.130` and `wine-e`. The script refuses if anything has started MT5.``
- `docs/runbooks/winddown-export.md:97` ``- `ARCHIVE|ABORT|... exists`: an earlier run left files. STOP; do not delete them; Claude reads them first.``
- `docs/runbooks/winddown-export.md:98` ``- `ARCHIVE|FAIL`: STOP; the box stays; Claude reads the manifest against the archives.``

Analysis:
- Every path in s3 and s4 gates step 9 (`Vultr -> Destroy`) on step 8: `ARCHIVE|PASS|<label>` in `archive_run.txt`, three `MATCH` lines in `verify_<label>.txt`, the manifest check, and Claude's explicit chat sentence `"<host> may be destroyed."`.
- Note on s4 step 3 (line 82): because `grind_history_dump` is never run on `wine-e` (E's MT5 is never started; `history_1515045375.csv` is dumped on the desktop terminal in s4 step 1, lines 76-78), `winddown_wine-e_manifest.txt` will not contain `history_1515045375.csv` (`winddown_survey_1.txt` lines 65-72). For `wine-e`, step 8 checks `logs/20261104.log` in the manifest instead of `history_<login>.csv`.

### 4.2 Is the archive taken only after MT5 has exited and pipshed has had its minute (X4)?

**Verdict: CONFIRMED**

Quotes:
- `docs/runbooks/winddown-export.md:20` ``| X4 | The EA flushes queued archive events to pipshed every 2 s from `OnTimer`; `OnDeinit` does not flush: so Algo Trading OFF, **wait a minute**, THEN exit | `docs/runbooks/twoarm-build-e.md` s3 (Fleet A's close, Oct) | READ |``
- `docs/runbooks/winddown-export.md:50` `2. **Algo Trading OFF** (toolbar). Wait **one full minute** by the clock (X4).`
- `docs/runbooks/winddown-export.md:51` `3. **File -> Exit.** Close the viewer. The demo account keeps its positions and orders; nothing more is done to it.`
- `docs/runbooks/winddown-export.md:60` ``   It must end `ARCHIVE|PASS|wine-test`. `ARCHIVE|ABORT|terminal64.exe is running` means step 3 did not finish:``

Analysis:
- On both live IC boxes (`wine-test` and `wine-d`), Algo Trading is turned OFF and a full clock minute elapses (step 2) before `File -> Exit` (step 3), and `archive_box.sh` refuses to start while `terminal64` is still in the process table (step 5). On `wine-e`, MT5 has been closed since 4 Nov (`HANDOFF_2026-09-24.md` line 9150). Section 5 (`pipshed`) runs only after B and D are stopped (line 84).

### 4.3 Is anything on a box (EA state files, Global Variables, `Profiles` charts, IC tick dumps in `MQL5/Files`, the account's trade database) left out of the core archive?

**Verdict: CONFIRMED** for the archived folders; **GAP** for saving a plain-text CSV dump of Global Variables (`grind_gv_list.mq5`) on `wine-test` and `wine-d` as Fleet A's close did

Quotes:
- `tools/winddown/archive_box.sh:33` `for d in Bases Config logs MQL5 Profiles Tester llm-agent; do [ -e "$d" ] && DIRS+=("$d"); done`
- `tools/winddown/archive_box.sh:35` `while IFS= read -r -d '' c; do CACHE+=("$c"); done < <(find Bases -mindepth 2 -maxdepth 2 -type d \( -name history -o -name ticks \) -print0 2>/dev/null | sort -z)`
- `tools/winddown/test_archive_box.sh:35` `grep -q 'trades/53066709/deals.dat' "$T/core.lst" || fail "the trades folder is not in core"`
- `docs/runbooks/winddown/winddown_survey_1.txt:8` `832K	MQL5/Files`
- `docs/runbooks/winddown/winddown_survey_1.txt:34` `1.6G	MQL5/Files`
- `docs/runbooks/twoarm-build-e.md:177` ``   Then A's Global Variables to a file, as the twins' (monday-build s7): `grind_gv_list` from the Navigator``
- `docs/runbooks/twoarm-build-e.md:179` ``   `InpContains` `GRIND`: `MQL5\Files\gv_list_1514878887.csv` (zipped in s4.2). Then **close MT5 on the VPS**``
- `docs/runbooks/twoarm-build-e.md:351` `  off for the archive flush, then MT5 closed on the VPS before its logs are zipped; A's GVs kept, but by the`
- `docs/runbooks/twoarm-build-e.md:352` ``  repo's `grind_gv_list` (a CSV in `MQL5\Files`), not by copying a GV file; (4) **GE-8.1:** the six symbols``
- `scripts/grind_gv_list.mq5:21` `   const string fname = StringFormat("gv_list_%I64d.csv", login);`

Analysis:
- **Account trade database (`Bases/<server>/trades`):** Kept in `_core.tar.zst` because line 35 of `archive_box.sh` excludes only `Bases/<server>/history` and `Bases/<server>/ticks` (verified by `test_archive_box.sh` line 35).
- **IC tick dumps and `history_<login>.csv` in `MQL5/Files`:** Kept in `_core.tar.zst` under `MQL5/Files` (`832K` on `wine-test`, `1.6G` of IC tick dumps on `wine-d`, `winddown_survey_1.txt` lines 8 and 34).
- **`Profiles` charts and presets:** Kept in `_core.tar.zst` under top-level `Profiles` and `MQL5/Profiles` / `MQL5/Presets`.
- **EA state and Global Variables:** The EA keeps its persistent carry ledger, VLs, and snapshot anchors in terminal Global Variables (`02_TRAPS.md` lines 2239-2242). While MT5's binary `Profiles` folder is archived in `_core.tar.zst`, `twoarm-build-e.md` (lines 177-179, 351-352, 365) established at Fleet A's close that Global Variables should also be dumped to a plain-text CSV `MQL5\Files\gv_list_<login>.csv` via `scripts/grind_gv_list.mq5` so they are readable without binary decoding.

Smallest fix (in `docs/runbooks/winddown-export.md` s2 line 41 and s3 step 1 line 47, check for and run `grind_gv_list` right after `grind_history_dump` on `wine-test` and `wine-d`):

```markdown
    foreach ($h in 'box1','root@216.128.158.33') { "=== $h"; ssh $h 'find /home/khalid/.mt5/drive_c -iname "grind_history_dump.ex5" -o -iname "grind_gv_list.ex5"' }
```

And in s3 step 1 (`docs/runbooks/winddown-export.md` after line 49):

```markdown
   Then drag `grind_gv_list` (`InpContains` `GRIND`) onto the chart: Experts tab `GVLIST|account=<login>|...`, writing `MQL5\Files\gv_list_<login>.csv`.
```

---

## 5. `wine-e`

### 5.1 Can any step start E's MT5, directly or by a side effect?

**Verdict: CONFIRMED**

Quotes:
- `docs/runbooks/winddown-export.md:25` ``| X9 | **E's MT5 stays closed** (standing rule since 4 Nov): nothing on wine-e starts it. E's deals come from the DESKTOP terminal logged in to 1515045375, as Fleet A's in October, if FTMO still lets the closed trial log in | HANDOFF s93; `twoarm-build-e.md` s4 | RULED |``
- `docs/runbooks/winddown-export.md:41` `    foreach ($h in 'box1','root@216.128.158.33') { "=== $h"; ssh $h 'find /home/khalid/.mt5/drive_c -iname grind_history_dump.ex5' }`
- `docs/runbooks/winddown-export.md:76` `1. **Desktop terminal** (Algo Trading OFF there), File -> Login to Trade Account: 1515045375 on its FTMO server.`
- `docs/runbooks/winddown-export.md:82` ``3. Then s3 steps 4-9 with `root@104.207.140.130` and `wine-e`. The script refuses if anything has started MT5.``

Analysis:
- Section 2 (line 41) touches only `box1` and `root@216.128.158.33`.
- Section 4 step 1 (line 76) logs in to `1515045375` on the **desktop** terminal (with Algo Trading OFF there) and never opens a GUI or Wine session on `wine-e`.
- Section 4 step 3 (line 82) runs only s3 steps 4-9 (`scp` of `archive_box.sh`, `ssh` running `archive_box.sh`, `scp` of the four output files, desktop hash verify, Claude gate, Vultr Destroy). Nothing in `archive_box.sh` invokes `wine` or `terminal64.exe`, and lines 24-28 abort if `terminal64` is running.

### 5.2 Is s4 step 1's fall-back for a refused FTMO login complete?

**Verdict: GAP**

Quotes:
- `docs/runbooks/winddown-export.md:79` ``   refuses the login, say so: E's deals then rest on pipshed's archive (s5), `review_1104\snap_1102_1104.csv` and``
- `docs/runbooks/winddown-export.md:80` ``   the account's own trade database inside the core archive (`Bases/<server>/trades`).``
- `docs/runbooks/winddown-export.md:81` `2. The operator: FTMO MetriX for 1515045375 as a PDF into the same folder.`
- `handoffs/HANDOFF_2026-09-24.md:9143` ``  - **E (03:45Z): the broker book EMPTY on all 12** (0 positions, 0 orders, `net_mtm` 0), while the EA's state still``
- `handoffs/HANDOFF_2026-09-24.md:9144` `    held full stacks (95 layers in all: AUDCAD L7 / S2, AUDCHF L7 / S1, CADCHF L6-7 / S1, EURGBP L3 / S2-7, EURUSD L1 /`
- `handoffs/HANDOFF_2026-09-24.md:9181` `- **01:36:55-56Z 4 Nov: FTMO closed all 95 positions in ~1.5 s** (95 deals "based on order #576878989, ...":`
- `handoffs/HANDOFF_2026-09-24.md:9182` `  consecutive server orders, several per 10 ms, no EA request before them; shorts bought at the ask, longs sold at`

Analysis:
- When FTMO liquidated all 95 of E's positions on 4 Nov at `01:36:55-56Z` (`HANDOFF_2026-09-24.md` lines 9143-9144, 9181-9182), E's EAs never processed those closes (the EA state still held 95 layers until MT5 was stopped). Because pipshed's `fill_logs` and `scalp_history` receive only EA-pushed events, **pipshed's archive (s5) does NOT contain FTMO's 95 close-out deals**, and `review_1104\snap_1102_1104.csv` contains 1-minute state snapshots (`state_snapshots`), not deal rows.
- Meanwhile, `Bases/<server>/trades` is MetaQuotes' binary `.dat` cache, not directly readable without an authenticated MT5 terminal.
- Two plain-text records of those 95 close-out deals exist even if FTMO refuses the MT5 terminal login:
  1. **FTMO MetriX's CSV/XLSX Trading History export** on the same MetriX web page the operator already opens in s4 step 2 (line 81) to save the PDF.
  2. **`wine-e`'s terminal journal `logs/20261104.log`** (archived in `_core.tar.zst`, `winddown_survey_2.txt` line 125), which `HANDOFF_2026-09-24.md` line 9181 confirmed holds all 95 deal lines (`"based on order #576878989, ..."`).

Smallest fix (replace lines 79-81 of `docs/runbooks/winddown-export.md`):

```markdown
   refuses the login, say so: E's deals before the 4 Nov close-out rest on pipshed's archive (s5), and the 95
   broker close-out deals of 4 Nov 01:36:55-56Z rest in `logs/20261104.log` and `Bases/<server>/trades` inside
   the core archive, plus the MetriX CSV export below (`review_1104\snap_1102_1104.csv` holds the minute marks).
2. The operator: FTMO MetriX for 1515045375 as a PDF and its Trading History CSV into the same folder.
```

---

## 6. `pipshed` (s5)

### 6.1 Does `--export-archive` without `--instance` export all instances, as X8 says?

**Verdict: CONFIRMED**

Quotes (from `theonlykk/pipshed` at `b9d2d22`):
- `scripts/archive_counts.py:28` `    --export-archive EVERY row of config_events, ea_events, fill_logs and`
- `scripts/archive_counts.py:29` `                     scalp_history as JSON lines (C83: the offline copy of the`
- `scripts/archive_counts.py:30` `                     trade history; no day window, all codes); honours --instance`
- `scripts/archive_counts.py:79` `ARCHIVE_TABLES = ("config_events", "ea_events", "fill_logs", "scalp_history")`
- `scripts/archive_counts.py:82` `def export_archive(cur, instance):`
- `scripts/archive_counts.py:85` `    print(json.dumps({"table": "_meta", "archive": True, "instance": instance}))`
- `scripts/archive_counts.py:86` `    for table in ARCHIVE_TABLES:`
- `scripts/archive_counts.py:87` `        cur.execute(`
- `scripts/archive_counts.py:88` `            f"SELECT * FROM {table} WHERE (%(instance)s::text IS NULL OR instance_id = %(instance)s)"`
- `scripts/archive_counts.py:89` `            " ORDER BY received_at, id", {"instance": instance})`
- `scripts/archive_counts.py:394` `    parser.add_argument("--instance")`
- `scripts/archive_counts.py:430` `            if args.export_archive:`
- `scripts/archive_counts.py:431` `                export_archive(cur, args.instance)`

Analysis:
- When `--instance` is omitted, `args.instance` is `None`, so `%(instance)s::text IS NULL` evaluates to `TRUE` for every row of `config_events`, `ea_events`, `fill_logs`, and `scalp_history` across all instances (`A`, `B`, `C`, `D`, `E`).

### 6.2 Is anything in Postgres or Redis that the wind-down needs and the export leaves out?

**Verdict: GAP**

Quotes (from `theonlykk/pipshed` at `b9d2d22` and `docs/runbooks/winddown-export.md`):
- `docs/runbooks/winddown-export.md:88` `       railway ssh --service archive-worker -i "$HOME\.ssh\id_ed25519" python scripts/archive_counts.py --limit 0 | Out-File -Encoding utf8 D:\fxmatrix-exports\winddown\pipshed\counts.txt`
- `docs/runbooks/winddown-export.md:90` `2. Claude reads the counts and gives the export command (all rows, X8) with its file name; then its size, line`
- `docs/runbooks/winddown-export.md:91` `   count and hash are recorded. pipshed itself stays up (the operator's ruling); this is the offline copy.`
- `scripts/archive_counts.py:31` `    --export-sends   every send_logs row of ONE --instance (required) as JSON lines,`
- `scripts/archive_counts.py:34` `    --export-snapshots  C137: state_snapshots rows (one per instance per minute)`
- `scripts/archive_counts.py:47` `TABLES = {`
- `scripts/archive_counts.py:524` `            tables = [args.table] if args.table else list(TABLES)`
- `migrations/001_archive_phase1.sql:8` `CREATE TABLE send_logs (`
- `migrations/002_adr159_daily.sql:1` `CREATE TABLE daily_snapshots (`
- `migrations/005_c137_state_snapshots.sql:4` `CREATE TABLE state_snapshots (`
- `archive_worker.py:30` `ARCHIVE_QUEUE = "fxmatrix:archive:queue"`
- `archive_worker.py:31` `ARCHIVE_PROCESSING = "fxmatrix:archive:processing"`
- `archive_worker.py:32` `ARCHIVE_DEADLETTER = "fxmatrix:archive:deadletter"`
- `archive_worker.py:137` `FROM daily_snapshots`
- `archive_worker.py:942` `            "DELETE FROM send_logs WHERE received_at < now() - interval '14 days'"`
- `app.py:4061` `    r.set(redis_key, json.dumps(payload), ex=REDIS_TTL_SECONDS)`
- `app.py:4162` `    pipe.expire(redis_key, 604800)  # 7 days`

Analysis:
1. **Postgres `send_logs` (`migrations/001_archive_phase1.sql` line 8) will be deleted by 14-day retention while `pipshed` stays up:**
   - Because `pipshed` stays running (`winddown-export.md` line 91), `archive_worker.py` line 942 (`DELETE FROM send_logs WHERE received_at < now() - interval '14 days'`) continues pruning `send_logs` every 24 hours.
   - E's 4 Nov `[Trade disabled]` placement storm (`HANDOFF_2026-09-24.md` lines 9190-9195, which `NEXT SESSION` item 3 on line 9348 plans to inspect for the stop-on-refusal fix) and B and D's last 14 days of order sends (`action`, `order_type`, `requested_price`, `ok`, `retcode`, `duration_ms`) are in `send_logs` now, are excluded from `--export-archive`, and will be permanently erased on 18 Nov unless exported in s5.
2. **Postgres `state_snapshots` (`migrations/005_c137_state_snapshots.sql` line 4) is omitted from both `--limit 0` (`TABLES`, line 47) and `--export-archive` (`ARCHIVE_TABLES`, line 79):**
   - `state_snapshots` holds the 1-minute intraday series (`balance`, `equity`, `net_mtm`, `mtm_long`, `mtm_short`, `layers_long`, `layers_short`, `api_count`, geometry, `closes_since_init`, `fills`) for every instance since 8 Oct. `archive_counts.py` already supports `--export-snapshots --from ... --to ...` (line 34) across all instances when `--instance` is omitted.
3. **Postgres `daily_snapshots` (`migrations/002_adr159_daily.sql` line 1, `archive_worker.py` lines 125-140) is omitted from both `TABLES` and `ARCHIVE_TABLES`:**
   - While raw `DAILY_SNAPSHOT` events are in `ea_events`, `daily_snapshots` holds the worker-derived columns (`ejections_auto`, `ejections_command`, `ejected_fills`, `ejected_realised`, `carry_clamps`, `critical_events`, `rolls_accepted`, `rolls_refused`, `rolled_fills`, `rolled_realised`, `gated_seconds`, `history_ok`).
4. **Redis queue drain check (`archive_worker.py` lines 30-32):**
   - Before running the Postgres export in s5, s5 should verify that `fxmatrix:archive:queue`, `fxmatrix:archive:processing`, and `fxmatrix:archive:deadletter` have length `0` (so no event from B or D's final minute is still queued or stuck in deadletter). Note also that once B and D stop, their Redis `fxmatrix:state:<id>` keys expire in 300 s (`app.py` line 4061) and `fxmatrix:closed_history:<id>` / `fxmatrix:scalp_history:<id>` expire in 7 days (`app.py` line 4162).

Smallest fix (replace lines 90-91 of `docs/runbooks/winddown-export.md` so s5 also checks the Redis archive queues and exports `state_snapshots`, `send_logs`, and `daily_snapshots` alongside `--export-archive`):

```markdown
2. Claude reads the counts, confirms `fxmatrix:archive:queue`, `processing` and `deadletter` are 0, and gives the
   export commands into `D:\fxmatrix-exports\winddown\pipshed\`: (a) `--export-archive` (all rows of `config_events`,
   `ea_events`, `fill_logs`, `scalp_history`, X8), (b) `--export-snapshots --from 2026-10-01T00:00:00Z --to 2026-11-15T00:00:00Z`
   (`state_snapshots`), and (c) a read-only dump of `send_logs` (before the 14-day retention erases E's 4 Nov storm and
   B/D's last fortnight) and `daily_snapshots`; then each file's size, line count and hash are recorded.
```

---

## 7. ANYTHING ELSE A BOX'S DESTRUCTION WOULD LOSE THAT THE RUNBOOK DOES NOT KEEP

### 7.1 Uncommitted files in `/home/khalid/fxmatrix-repo`, `/home/khalid`, or `/root`

**Verdict: GAP**

Quotes:
- `docs/runbooks/twoarm-build-e.md:194` `       cd C:\fxmatrix; git status -sb; git fetch -q origin; git log --oneline origin/main..HEAD; git tag -l "vps-*"; git ls-remote --tags origin "vps-*"`
- `handoffs/Handover/06_LINUX_WINE_BOX.md:188` ``4. **Code, by git on the box** (no scp): `~/fxmatrix-repo` is a clone;``
- `handoffs/Handover/02_TRAPS.md:1703` ``- **wine-d's `Scripts/fxmatrix` lacks the research scripts** (its repo is``
- `handoffs/Handover/02_TRAPS.md:1704` ``  on `hotfix-api-stop`). Install one without changing the branch:``

Analysis:
- When the Windows VPS was closed (`twoarm-build-e.md` s4.1, line 194), the runbook checked `git status -sb` and `git log --oneline origin/main..HEAD` before destroying the box.
- On `wine-test`, `wine-d`, and `wine-e`, `archive_box.sh` archives only `/home/khalid/.mt5/drive_c/Program Files/MetaTrader 5`. It does not check `/home/khalid/fxmatrix-repo` (which on `wine-d` was once on a non-`main` branch, `02_TRAPS.md` line 1704) or rollback backups in `/root/` (such as `/root/c165_prev_*`).

Smallest fix (extend s2 line 41 of `docs/runbooks/winddown-export.md` to check `/home/khalid/fxmatrix-repo` status and unpushed commits on all three boxes before any Destroy):

```powershell
    foreach ($h in 'box1','root@216.128.158.33','root@104.207.140.130') { "=== $h"; ssh $h 'git -C /home/khalid/fxmatrix-repo status -sb; git -C /home/khalid/fxmatrix-repo log --oneline origin/main..HEAD; find /home/khalid/.mt5/drive_c -iname "grind_history_dump.ex5" -o -iname "grind_gv_list.ex5"' }
```

### 7.2 MT5 build 6231 executables (`terminal64.exe`, `MetaEditor64.exe`, `metatester64.exe`) under Wine 9.0

**Verdict: NOT A DEFECT** for closing `wine-test`, `wine-d`, and `wine-e` now (because `wine-c` stays up), **GAP** if `wine-c` is later closed without keeping one copy of the 6231 `.exe` files

Quotes:
- `tools/winddown/archive_box.sh:14` `# ARCHIVE|PASS or ARCHIVE|FAIL. The MT5 executables, Sounds and the icon are not kept (reinstallable).`
- `handoffs/Handover/06_LINUX_WINE_BOX.md:417` ``- **MT5 is build 6231, copied from wine-d, not the installer's.** Today's `mt5setup.exe` installs 6274, which stops``
- `handoffs/Handover/06_LINUX_WINE_BOX.md:418` `  at start under Wine 9.0 ("A debugger has been found running in your system"). The install was kept and its three`

Analysis:
- Line 14 of `archive_box.sh` comments that `The MT5 executables, Sounds and the icon are not kept (reinstallable)`.
- As `06_LINUX_WINE_BOX.md` lines 417-420 record (C161), MetaQuotes' live installer (`mt5setup.exe`) now installs build `6274`, which refuses to start under Ubuntu 24.04's Wine 9.0, so `wine-e` had to copy the three working build `6231` binaries (`terminal64.exe`, `MetaEditor64.exe`, `metatester64.exe`) from `wine-d`.
- Because `wine-c` stays alive (`winddown-export.md` line 8), `wine-c` still holds those three build `6231` binaries, so destroying `wine-test`, `wine-d`, and `wine-e` does not lose the last copy. However, keeping those three `.exe` files from one box (or when `wine-c` eventually closes) preserves the working Wine 9.0 build `6231` binaries offline.

---

## 8. OVERALL VERDICT

**SOUND WITH CHANGES** (1. In `tools/winddown/archive_box.sh` lines 60-61, replace `grep -c '^-' || true` with `awk '/^-/{n++} END{print n+0}'` so `|| true` cannot mask a failed `zstd -dc` or `tar -tvf -` in the count pipeline; pass `--anchored --no-wildcards` before `"${EXCL[@]}"` on line 52; and use `pgrep -fi 'terminal64|metaeditor64'` on line 24. 2. In `tools/winddown/test_archive_box.sh`, add a 9th test exercising a parent shell command mentioning `terminal64` and a count mismatch that exits non-zero with `ARCHIVE|FAIL`. 3. In `docs/runbooks/winddown-export.md` s3 step 7 line 68, guard `Get-FileHash` with `Test-Path -LiteralPath "$d\$n"` and `Get-Content -ErrorAction Stop` so a missing file writes `MISMATCH <file>` into `verify_<label>.txt` instead of throwing on `($null).Hash` and omitting the line. 4. In `docs/runbooks/winddown-export.md` s2/s3/s4/s5, run `grind_gv_list` alongside `grind_history_dump` on the IC boxes, include the FTMO MetriX Trading History CSV in s4 step 2 for `1515045375`, check `git -C /home/khalid/fxmatrix-repo status -sb` before Destroy, and in s5 export `state_snapshots`, `send_logs`, and `daily_snapshots` after confirming Redis archive queues are 0.)

Line count: 451
