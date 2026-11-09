This message has a line count at the bottom

# ARGON: REVIEW OF THE WIND-DOWN EXPORT RUNBOOK AND ITS ARCHIVE SCRIPT

| | |
|---|---|
| Written | 9 Nov 2026 (HANDOFF s93 continued 5), Claude (Lead Engineer) |
| What | Three Vultr boxes (wine-test, wine-d, wine-e) are to be **destroyed**, which cannot be undone. Attack the plan that keeps their data first: can any file be lost, can a box be destroyed before its copy is proven, can a step start E's MT5, do the commands do what the runbook says |
| The documents | `docs/runbooks/winddown-export.md`; `tools/winddown/archive_box.sh`; `tools/winddown/test_archive_box.sh` (all on `origin/main`) |
| Sources | `docs/runbooks/winddown/winddown_survey_1.txt`, `_2.txt` (the boxes as surveyed 8-9 Nov); `scripts/grind_history_dump.mq5`; `docs/runbooks/twoarm-build-e.md` s3-s4 (Fleet A's close); `handoffs/Handover/02_TRAPS.md`; `handoffs/Handover/06_LINUX_WINE_BOX.md`; pipshed `scripts/archive_counts.py` (repo `theonlykk/pipshed`, `main` `b9d2d22`; read it on GitHub or a clone outside `D:\fxmatrix`) |
| Your reply | ONE new file `reviews/argon_review_winddown.md` on a NEW branch `review/argon-winddown` from `origin/main`; commit, push, then `git checkout main` |

## 0. RULES FOR THIS REVIEW (read first)

1. **Quote every line you cite** as `<path>:<line>` followed by the line's text in backticks, exactly as it is at
   `origin/main` (pipshed lines at `b9d2d22`). If you did not read a file or a line, write "not read".
2. Every verdict is one of: **DEFECT** (a step or line that can lose data, destroy a box early, start E's MT5, or
   does not do what the runbook says), **GAP** (something needed and missing), **CONFIRMED**, **NOT A DEFECT** (say
   why, with a quote), **NOT READ**. For a DEFECT or GAP, give the smallest fix as replacement text.
3. **Read-only.** Edit no file but your reply. You MAY run `bash tools/winddown/test_archive_box.sh` (it builds a
   fake MT5 folder in a temporary directory and touches nothing else; it needs `bash`, `zstd`, GNU `tar`); report
   its full output, or that you could not run it and why. Run nothing else: no ssh, no scp, no railway, no MT5, no
   compile, no `git stash`, no merge, no PR, no `git add .` or `-u`.
4. Commit only `reviews/argon_review_winddown.md` to `review/argon-winddown`, push it, then `git checkout main`.
5. **Line-count bookends:** the reply's FIRST line is exactly `This message has a line count at the bottom` and its
   LAST line is exactly `Line count: N`, N being the file's total number of lines including both. ASCII only.

## 1. WHAT TO CHECK

1. **`archive_box.sh`, line by line.** Can any regular file under the MT5 folder be left out of both archives
   without the count catching it (symlinks, hard links, sparse files, names with spaces, newlines or leading dashes,
   files that change while archiving, `Bases` server folders whose names hold spaces)? Do the `--exclude` options
   remove exactly the `history` and `ticks` folders and nothing else? Is `set -euo pipefail` enough to stop on a
   failed `tar` or `zstd` inside a pipe? Does the ancestor skip in the MT5 check (X6) hold over
   `ssh box 'bash /root/archive_box.sh <host>'`, and can it miss a real `terminal64.exe` under Wine?
2. **The tests:** do the 8 tests cover what the runbook relies on? What one test would you add?
3. **The PowerShell lines** (s1 step 2, s2, s3 steps 4-7, s5): quoting under Windows PowerShell 5.1 (02_TRAPS
   records inner double quotes as a trap); does `scp` with a remote glob copy the core, cache and manifest; does
   the verify line compare every hash in the `.sha256` file and fail visibly on a missing file; `Tee-Object`'s
   encoding.
4. **Order and gates:** can any path through s3-s4 reach Vultr's Destroy before the three MATCH lines and Claude's
   go? Is the archive taken only after MT5 has exited and pipshed has had its minute (X4)? Is anything on a box
   (EA state files, Global Variables, the `Profiles` charts, the IC tick dumps in `MQL5/Files`, the account's
   trade database) left out of the core archive?
5. **wine-e:** can any step start E's MT5, directly or by a side effect? Is s4 step 1's fall-back for a refused
   FTMO login complete?
6. **pipshed (s5):** is `--export-archive` without `--instance` all instances, as X8 says (quote `archive_counts.py`)?
   Is anything in Postgres or Redis that the wind-down needs and the export leaves out?
7. **Anything else** a box's destruction would lose that the runbook does not keep.

## 2. YOUR REPLY's SHAPE

`reviews/argon_review_winddown.md`: a header (branch, base hash, files read), items 1-7 with quotes and verdicts
and any fixed text, then one line: **SOUND**, **SOUND WITH CHANGES** (list them) or **NOT SOUND** (why).

Line count: 56
