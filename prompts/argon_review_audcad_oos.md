This message has a line count at the bottom

# ARGON: REVIEW OF THE AUDCAD OUT-OF-SAMPLE PRE-REGISTRATION

| | |
|---|---|
| Written | 11 Nov 2026 (HANDOFF s93 continued 8), Claude (Lead Engineer) |
| What | Attack the plan before any 2018-2022 bar is read: is the test fair to the hypothesis and hard to pass by luck, is the decision rule fixed tightly enough, can the engine and the data do what it says |
| The document | `research/audcad_oos/PREREG.md` on `origin/main` (all of it) |
| Sources | `reviews/fable_pass1/` (`report_pass1.md` s1, s4.1-s4.2, s4.6, s4.8, s5; `core.py`; `common.py`; `04_ladder_bars.py`; `01_null_calibration.py`; `test_core.py`; `out/04_ladder_tables_cont.txt`, `out/04_ladder_tables_one.txt`; `MANIFEST.md`); `research/fills/results.md`; `scripts/grind_bar_dump.mq5`; `handoffs/Handover/02_TRAPS.md` (2026-10-26) |
| Your reply | ONE new file `reviews/argon_review_audcad_oos.md` on a NEW branch `review/argon-audcad-oos` from `origin/main`; commit, push, then `git checkout main` |

## 0. RULES FOR THIS REVIEW (read first)

1. **Quote every line you cite** as `<path>:<line>` followed by the line's text in backticks, exactly as it is at
   `origin/main`. If you did not read a file or a line, write "not read".
2. Every verdict is one of: **DEFECT** (the plan cannot do what it says, or a rule can be gamed or read two ways),
   **GAP** (something needed and missing), **CONFIRMED**, **NOT A DEFECT** (say why, with a quote), **NOT READ**. For
   a DEFECT or GAP, give the smallest fix as replacement text.
3. **Read-only.** Edit no file but your reply. Run nothing: no Python, no MetaTrader, no ssh, no `git stash`, no
   merge, no PR, no `git add .` or `-u`. Do not open any bar file.
4. Commit only `reviews/argon_review_audcad_oos.md` to `review/argon-audcad-oos`, push it, then `git checkout main`.
5. **Line-count bookends:** the reply's FIRST line is exactly `This message has a line count at the bottom` and its
   LAST line is exactly `Line count: N`, N being the file's total number of lines including both. ASCII only.

## 1. WHAT TO CHECK

1. **The region and the rule (s3, s6).** Are the ten cells the region Fable described (quote s4.8 and s5), no wider
   and no narrower? Is averaging the ten cells per month, then a t over months, a fair test of a region whose cells
   are strongly correlated? Are thresholds (t >= 2.0, 3 of 5 years, 7 of 10 cells) hard enough to fail a fluke and
   soft enough to pass a real effect of the in-sample size (about +15 USD a month, s1)? Is any outcome unclassified?
2. **The variants and the sensitivity (s3).** Is `cont-std` the right decider by Fable's own evidence (s4.6)? Does
   "bid - 0.2 pip, ask + 0.2 pip" make every fill 0.2 pip worse in `core.ladder`, given how it fills limits (quote
   the code)? Anything else in `ladder`'s arguments (as `04_ladder_bars.py` calls it) the runner must match?
3. **The control (s4 a).** Do `out/04_ladder_cells_cont.csv` / `_one.csv` (not in the repo; their hashes are in the
   MANIFEST, their tables in `out/04_ladder_tables_*.txt`) hold every AUDCAD cell the control names, on the `std`
   path? Is "equal to the cent" achievable given numba and floating point?
4. **The data (s2).** Can `grind_bar_dump.mq5` export 2018-2022 with these inputs (quote it)? Is the FTMO / IC fall-back
   and the 36-month floor stated so that no choice is left until after the data is seen? What does an IC feed change
   besides the spread?
5. **Self-checks c and d (s4).** Enough to catch a broken or partial file before results? Is d's use of Fable's null
   method sound (quote `01_null_calibration.py`)?
6. **Biases (s7).** Anything missing that would make a HOLDS misleading (holiday handling, the server clock across DST
   in 2018-2022, AUDCAD's volatility regime, the blow-out rule's median taken from a different period)?
7. **Order of work (s8).** Can any step read a 2018-2022 result before the self-checks are committed?

## 2. YOUR REPLY's SHAPE

`reviews/argon_review_audcad_oos.md`: a header (branch, base hash, files read), items 1-7 with quotes and verdicts
and any fixed text, then one line: **SOUND**, **SOUND WITH CHANGES** (list them) or **NOT SOUND** (why).

Line count: 52
