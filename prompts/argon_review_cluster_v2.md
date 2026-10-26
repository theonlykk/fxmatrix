This message has a line count at the bottom

# ARGON: REVIEW OF THE CLUSTER MEASUREMENT's PRE-REGISTRATION, v2

| | |
|---|---|
| Written | 26 Oct 2026 ~03:40Z (HANDOFF s91 continued 8), Claude (Lead Engineer) |
| What | v2 rewrites the measure after your v1 review (`reviews/argon_review_cluster.md` on `review/argon-cluster`): Part A counts activity per depth; Part B (new, the operator's idea) asks whether price turns more often at round numbers. Attack it before any code or tick |
| The document | `research/cluster/PREREG.md` on `origin/main` (all of it) |
| Sources | your v1 review; `research/opt_budget/runs.py` (`load_ticks`, `window`), `research/opt_budget/PREREG_CAP.md`, `research/opt_budget/MECHANICS.md`, `research/replay/inputs/swcap/*.csv`, `research/replay/inputs/swcap.sha256`, `research/replay/results/sweep_notes.md` (the tick records, 466-467, 660-670, 833-834), `ea/grind_engine.mqh` (the add target, the lattice) |
| Your reply | ONE new file `reviews/argon_review_cluster_v2.md` on a NEW branch `review/argon-cluster-v2` from `origin/main`; commit, push, then `git checkout main` |

## 0. RULES

1. Quote every line you cite as `<path>:<line>` followed by the line's text in backticks, exactly as at `origin/main`
   (your v1 review: at `origin/review/argon-cluster`). Say "not read" for anything you did not open.
2. Verdicts: **DEFECT**, **GAP**, **CONFIRMED**, **NOT A DEFECT** (with a quote), **NOT READ**; for a DEFECT or GAP
   the smallest text change that fixes it.
3. Read-only: edit no file but your reply; no helper script left in `D:\fxmatrix`; **do not open the tick files in
   `D:\mt5-replay`**; no compile, no MetaTrader, no `git stash`, no merge, no PR, no `git add .` or `-u`. You MAY run
   Python on synthetic data of your own (a random walk) to check a claim; say what you ran.
4. Commit only your reply to `review/argon-cluster-v2`, push, then `git checkout main`.
5. Bookends: FIRST line exactly `This message has a line count at the bottom`, LAST line exactly `Line count: N` (N =
   the file's lines including both). ASCII only.

## 1. CHECK

1. **Your v1 findings:** for each (1(a)-(c), 2-8), is it fixed in v2, and where? Quote both.
2. **Part A's measure:** is A_k = V_k / V_1 flat for a driftless random walk (finite segments, the last excursion
   open)? Does the cliff example compute as written? Does the shuffle (moves permuted, gaps as blocks) keep the drift
   and remove the structure? Is "two DROPs in a row, in both regimes" a fair guard, and is THIN well defined?
3. **Part A against the caps:** is "cap c holds depths 0 ... c - 1, rolls at c" right for the EA (quote the lattice
   and `Grind_CanPlaceEntryLayer`)? Does the reading rule follow?
4. **Part B's measure:** are the arrival, the re-arm, TURN and THROUGH defined without gaps (a tick exactly at L;
   two levels in one tick; an arrival at one level while another is open)? Are R100 / R50 / OTHER right for the six
   pairs' 5-digit quotes? Is "classes are each other's control" sound, or can drift or volatility differ by class?
5. **Part B's interval:** is a day-block bootstrap the right guard for dependence? Is 2,000 enough; the seed fixed;
   the quantile rule exact?
6. **s5's synthetic checks:** do they test the false-finding rate they claim to? Is "at most 1 of 12" and "9 of 10"
   a fair bar?
7. **s6's predictions:** each falsifiable as written?
8. **s7's confirmation:** is it enough to answer the operator's "tea leaves" (a pattern that ends when capital is
   deployed)? Anything that would let a result be bent after the fact, and anything the operator's two questions
   need that is missing. Keep to what you can quote.

End with one line: **SOUND**, **SOUND WITH CHANGES** (list them) or **NOT SOUND** (why).

Line count: 48
