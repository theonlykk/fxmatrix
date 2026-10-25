This message has a line count at the bottom

# ARGON: REVIEW OF THE CLUSTER MEASUREMENT's PRE-REGISTRATION

| | |
|---|---|
| Written | 25 Oct 2026 ~19:55Z (HANDOFF s91 continued 5), Claude (Lead Engineer) |
| What | Attack the measure before any code is written or any tick read: does it answer the operator's question, is every step defined, can it be bent after the fact, will it find structure that is not there (or miss structure that is) |
| The document | `research/cluster/PREREG.md` on `origin/main` (all of it) |
| Sources | `research/opt_budget/PREREG_CAP.md`, `research/opt_budget/results.md` (s7, s8), `research/opt_budget/runs.py` (`load_ticks`), `research/opt_budget/MECHANICS.md`, `research/replay/sweep.py` (56-59), `research/replay/inputs/swcap/*.csv`, `research/replay/results/sweep_notes.md` (the h8w and October tick records), `ea/grind_engine.mqh` (the add target and the lattice) |
| Your reply | ONE new file `reviews/argon_review_cluster.md` on a NEW branch `review/argon-cluster` from `origin/main`; commit, push, then `git checkout main` |

## 0. RULES FOR THIS REVIEW (read first)

1. **Quote every line you cite** as `<path>:<line>` followed by the line's text in backticks, exactly as it is at
   `origin/main`. If you did not read a file or a line, write "not read". Open it; do not answer from memory.
2. Every verdict is one of: **DEFECT**, **GAP**, **CONFIRMED**, **NOT A DEFECT** (say why, with a quote), **NOT READ**.
3. For any DEFECT or GAP, give the smallest change to the document's text that fixes it.
4. **Read-only.** Edit no file but your reply; leave no helper script in `D:\fxmatrix` (use a scratch folder outside
   it, or delete it before you commit). Do not read the tick files in `D:\mt5-replay` (no measure is read before the
   review), do not compile, do not launch MetaTrader, no `git stash`, no merge, no PR, no `git add .` or `-u`.
5. Commit only `reviews/argon_review_cluster.md` to `review/argon-cluster`, push it, then `git checkout main`.
6. **Line-count bookends:** the reply's FIRST line is exactly `This message has a line count at the bottom` and its
   LAST line is exactly `Line count: N`, N being the file's total number of lines including both. ASCII only.

## 1. WHAT TO CHECK

1. **Does it answer the question?** The operator's words are in the header. Does "p_k by depth from a stack's
   anchor" measure what a grid stack lives on? Where does the measure's anchor differ from the EA's (the L0 at
   mid -/+ width, the adds at anchor -/+ add, the re-centre; quote `MECHANICS.md` and the source), and does that
   difference matter for the reading rule in s6?
2. **s2, the measure:** is every step defined: the first level, first passage, a gap of m levels as one decision, the
   end of an excursion at n = 0, long and short pooled, the segment ends? Any case left open (a tick exactly on a
   level; a gap that crosses n = 0; the weekend inside October's one segment)?
3. **s4, the nulls:** is a 50% random walk the right baseline at these scales? Does the shuffle keep what it says
   (drift) and remove what it says (dependence)? Is 200 enough for a 2.5% / 97.5% band? Is the seed fixed?
4. **s5, the definitions:** can REVERTING and K\* pass on noise (24 series x 15 depths: how many false REVERTINGs
   does the shuffle band let through by chance)? Is "both regimes" a fair guard? Is N_k >= 30 enough? Is the
   break-even p\* right for a one-step bet with costs on both legs (quote `sweep.py` 56-59)?
5. **s3, the data:** do the segments and hashes match what the repo records (quote the run files and
   `sweep_notes.md`)? Is anything wrong with using these ticks (in-sample, one broker, EURUSD's October file named
   differently)?
6. **s7, the self-checks:** are they sufficient, and is check 3's identity right?
7. **s8, the predictions:** are they falsifiable as written?
8. **Anything that would let the result be bent after the fact,** and anything the operator's question needs that is
   missing (e.g. a scale finer or coarser than the adds; time-of-day; the stack's age).

## 2. YOUR REPLY's SHAPE

`reviews/argon_review_cluster.md`: a header (branch, base hash, files read), then one row per item 1-8: the verdict,
the quotes, and for a DEFECT or GAP the fixed text. End with one line: **SOUND** (commit as written), **SOUND WITH
CHANGES** (list them) or **NOT SOUND** (why).

Line count: 54
