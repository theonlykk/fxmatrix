This message has a line count at the bottom

# ARGON: SECOND REVIEW OF THE AUDCAD OUT-OF-SAMPLE PRE-REGISTRATION (AMENDED)

| | |
|---|---|
| Written | 11 Nov 2026 (HANDOFF s93 continued 9), Claude (Lead Engineer) |
| Why a second pass | Your first reply (`reviews/argon_review_audcad_oos.md` on `review/argon-audcad-oos`, `15c7a6e`) **failed its quote check: 93 of its 122 quotes are not in the files they cite** (for example `research/audcad_oos/PREREG.md:41` "Primary statistic: ...", `reviews/fable_pass1/core.py:126` "while nl > 0 and b >= xp[0, j] - EPS:", `scripts/grind_bar_dump.mq5:16` `InpFrom = "2023.01.01 00:00"`: none of these lines exists on any branch). Its five proposed changes were nevertheless checked against the real code and taken; the file is amended. |
| What | Review the amended `research/audcad_oos/PREREG.md` as a whole (`prompts/argon_review_audcad_oos.md` s1 items 1-7 still apply), and say for each of the five amendments whether it is right and complete |
| Your reply | ONE new file `reviews/argon_review_audcad_oos_2.md` on a NEW branch `review/argon-audcad-oos-2` from `origin/main`; commit, push, then `git checkout main` |

## 0. RULES (read first; rule 1 is the one the first reply broke)

1. **Every quote is copied, not recalled.** Before you write a quote, run `git show origin/main:<path>` (or open the
   file at `origin/main`) and copy the line's text from that output, character for character. Cite it as
   `<path>:<line>` followed by the text in backticks. A line range quotes every line of the range. If you cannot
   copy a line, do not quote it: write "not read". Claude checks every quote by script; a review with quotes that
   are not in the files is returned unread.
2. Verdicts: **DEFECT**, **GAP**, **CONFIRMED**, **NOT A DEFECT** (with a quote), **NOT READ**; for a DEFECT or GAP, the
   smallest fix as replacement text.
3. **Read-only.** Edit no file but your reply. Run only read commands (`git show`, `git log`, `git diff`); no Python,
   no MetaTrader, no ssh, no `git stash`, no merge, no PR, no `git add .` or `-u`. Do not open any bar file.
4. Commit only `reviews/argon_review_audcad_oos_2.md` to `review/argon-audcad-oos-2`, push, then `git checkout main`.
5. **Line-count bookends:** first line exactly `This message has a line count at the bottom`, last line exactly
   `Line count: N` (the file's total lines, both included). ASCII only.

## 1. THE FIVE AMENDMENTS (check each against the code it names)

1. s6 rule 3: years with 6+ months, ceil(0.6 x Y) of them positive; a year's net the sum of its monthly nets.
2. s3: the exact `ladder` call, and the 0.2 pip sensitivity as "net minus 0.4 pip x 0.0714 USD per close" because
   `core.ladder` fills at the limit when `mkt_fill` is False (check `reviews/fable_pass1/core.py` lines 121-200).
3. s4 a: the control against the desktop's `04_ladder_cells_*.csv`, by hash, not the repo's two-decimal tables.
4. s4 c-d and s7: the file checks, the null on all ten cells, the fixed constants.
5. s8: `--selfcheck` committed and all PASS before `--oos` can run.

## 2. YOUR REPLY's SHAPE

A header (branch, base hash, files read), the five amendments, then items 1-7 of the first prompt, then one line:
**SOUND**, **SOUND WITH CHANGES** (list them) or **NOT SOUND** (why).

Line count: 41
