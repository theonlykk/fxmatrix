This message has a line count at the bottom

# ARGON: REVIEW OF THE C162 GO / NO-GO MEMO (DRAFT)

| | |
|---|---|
| Written | 8 Nov 2026 (HANDOFF s93 continued 3), Claude (Lead Engineer) |
| What | Attack the draft before the operator rules on it: is every number and quotation true to its source, is the conclusion neither stretched nor understated, is anything that argues the other way left out, are the options fair |
| The document | `docs/research/c162-go-no-go-memo-2026-11-08.md` on `origin/main` (all of it) |
| fxmatrix sources | every file in the memo's s9; also `research/nocarry/out/*.json` and `research/nocarry/selfcheck_out.txt` (the no-carry figures), `research/longrun/out_limit/*.json`, `research/e_week1/PREREG.md`, `docs/research/replay-calibration-eurusd-4.md` |
| Your reply | ONE new file `reviews/argon_review_c162_memo.md` on a NEW branch `review/argon-c162-memo` from `origin/main`; commit, push, then `git checkout main` |

## 0. RULES FOR THIS REVIEW (read first)

1. **Quote every line you cite** as `<path>:<line>` followed by the line's text in backticks, exactly as it is at
   `origin/main`. If you did not read a file or a line, write "not read". Open it; do not answer from memory.
2. Every verdict is one of: **DEFECT** (a number, quote or claim the source does not support), **GAP** (something the
   memo needs and lacks, including evidence that cuts the other way), **CONFIRMED**, **NOT A DEFECT** (say why, with
   a quote), **NOT READ**.
3. For any DEFECT or GAP, give the smallest change to the memo's text that fixes it.
4. **Read-only.** Edit no file but your reply; no helper scripts left in the repo (any in a scratch folder outside
   `D:\fxmatrix`, or deleted before you commit). Do not run any simulator, replay or bars. Do not compile, do not
   launch MetaTrader, no `git stash`, no merge, no PR, no `git add .` or `-u`.
5. Commit only `reviews/argon_review_c162_memo.md` to `review/argon-c162-memo`, push it, then `git checkout main`.
6. **Line-count bookends:** the reply's FIRST line is exactly `This message has a line count at the bottom` and its
   LAST line is exactly `Line count: N`, N being the file's total number of lines including both. ASCII only.

## 1. WHAT TO CHECK

1. **Every number in the memo against its source.** One row per figure (dollars, counts, dates, times, percentages):
   the memo's line, the source line that supports it, the verdict. Where a figure is derived (e.g. +$1,087, -$11,487,
   +$15k, $79k, $23 a trading day), show the arithmetic from the source's numbers.
2. **Every quotation** (the operator's words, s1 table and s3) exact against its source, and attributed to the right
   person and date. Flag any paraphrase presented as a quote.
3. **s2's table:** is each row's "in or out of sample" label fair (read `two-arm-viability-2026-10-21.md` s8 and
   `research/longrun/results.md` s2, s6)? Is "everything in sample said maybe; everything out of sample said no" true
   of every row?
4. **Balance.** List any evidence in the sources that argues FOR the grid and is missing or understated in the memo
   (for example: ALT +$800 over four years; sweep9's period-level offset, s8.2; trial 1's positive balance; C's
   live weeks; 2026's +$876). For each, say whether its absence changes the conclusion.
5. **Stretch.** Does the memo claim more than the sources show anywhere (s3's "carry is not the problem", s4's "one
   mechanism" for trials 2 and 3, s5's scope, s7's claims about the replay and C165)? Is s5 complete: any untested
   premise or bias the sources record that s5 omits?
6. **s6, the options:** is each option's "for" and "against" fair and sourced? Is any option missing? Is the
   recommendation consistent with `research/nocarry/PREREG.md` s6 and with the operator's own test (memo s1)?
7. **s8, the loose ends:** is each stated correctly (quote HANDOFF s93 and `ea/grind_engine.mqh` for the storm)?
   Anything open in the sources that a stop or a continuation would need and s8 leaves out?
8. **Fitness as an internal record:** anything wrong about FTMO's rules as the repo records them; anything a reader
   in six months could not trace to a file on `main`.

## 2. YOUR REPLY's SHAPE

`reviews/argon_review_c162_memo.md`: a header (branch, base hash, files read), then items 1-8, each with its rows,
quotes and verdicts, and for a DEFECT or GAP the fixed text. End with one line: **SOUND** (the memo as written),
**SOUND WITH CHANGES** (list them) or **NOT SOUND** (why).

Line count: 57
