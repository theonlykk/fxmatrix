This message has a line count at the bottom

# ARGON: REVIEW OF THE ROUND-NUMBER STUDY's PRE-REGISTRATION, v3 (AN OSLER REPLICATION)

| | |
|---|---|
| Written | 26 Oct 2026 ~05:00Z (HANDOFF s91 continued 9), Claude (Lead Engineer) |
| What | v3 drops v2's Part A (your v2 review) and rebuilds Part B as a replication of Osler (FRBNY Staff Reports 125, 2001, and 150, 2002) on four years of FTMO minute bars. Attack it before any code or bar |
| The document | `research/cluster/PREREG.md` on `origin/main` (all of it) |
| Sources | your v2 review (`reviews/argon_review_cluster_v2.md` on `origin/review/argon-cluster-v2`); `scripts/grind_bar_dump.mq5` (the files' format); `research/opt_budget/PREREG_CAP.md`. Osler's papers are NOT in the repo: judge s2's summary only for internal consistency and say what you cannot check |
| Your reply | ONE new file `reviews/argon_review_cluster_v3.md` on a NEW branch `review/argon-cluster-v3` from `origin/main`; commit, push, then `git checkout main` |

## 0. RULES

1. Quote every line you cite as `<path>:<line>` followed by the line's text in backticks, exactly as at `origin/main`
   (your v2 review: at `origin/review/argon-cluster-v2`). Say "not read" for anything you did not open.
2. Verdicts: **DEFECT**, **GAP**, **CONFIRMED**, **NOT A DEFECT** (with a quote), **NOT READ**; for a DEFECT or GAP
   the smallest text change that fixes it.
3. Read-only: edit no file but your reply; no helper script left in `D:\fxmatrix`; **do not open the bar files in
   `D:\fxmatrix-exports\bars_ftmo`** or anything in `D:\mt5-replay`; no compile, no MetaTrader, no `git stash`, no
   merge, no PR, no `git add .` or `-u`. You MAY run Python on synthetic data of your own; say what you ran.
4. Commit only your reply to `review/argon-cluster-v3`, push, then `git checkout main`.
5. Bookends: FIRST line exactly `This message has a line count at the bottom`, LAST line exactly `Line count: N` (N =
   the file's lines including both). ASCII only.

## 1. CHECK

1. **s4, the measure:** is every step exact (the minute quote from a bar; the band; a hit, its side and the re-arm;
   the outcome at +15 with the 5-minute rule; CROSSING's sign; the arbitrary levels, their seed and the redraw)? Any
   case left open (a minute inside two bands; a level hit twice in one interval; a gap over the weekend inside +15)?
2. **s4 against the files:** does `grind_bar_dump.mq5`'s output (quote the header and row format) support every input
   s4 uses? Is "open + half the bar's spread" a sound mid for MT5's `MqlRates.spread`?
3. **s5, the inference:** is the interval the right unit; is the trading-day rule (600 bars) sound; does pooling the
   seven pairs' intervals break the sign test's independence (the same days across pairs)? If so, the smallest fix.
4. **s6.3, the false-finding check:** does permuting minute returns within an interval remove level structure while
   keeping what it should? Is "at most 1 of 20 at p < 0.01" a fair bar for the pooled test as specified?
5. **s7, the decision:** is "both halves" a real hold-out here? Anything that would let the result be bent after the
   fact (a choice left open, a threshold without a number)?
6. **s8, the predictions:** each falsifiable as written?
7. **Is it a replication?** Where does s4-s5 depart from Osler as s2 states her method (minute bars vs her minute
   quotes, 24 hours vs her 9:00-16:00 New York, 200 arbitrary levels vs her sets of 30, the pooled test), and does any
   departure matter?

End with one line: **SOUND**, **SOUND WITH CHANGES** (list them) or **NOT SOUND** (why).

Line count: 46
