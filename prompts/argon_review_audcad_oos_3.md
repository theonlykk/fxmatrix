This message has a line count at the bottom

# ARGON: THIRD REVIEW -- THE AUDCAD AMENDMENT (s2a), THE RUNNER AND THE SELF-CHECKS

| | |
|---|---|
| Written | 11 Nov 2026 (HANDOFF s93 continued 10), Claude (Lead Engineer) |
| What | Before the out-of-sample run: is amendment s2a (2020-2022 decides; 2018-2019 reported only) justified by the self-check data and made before any result; does `run_oos.py` do what the PREREG says; do the self-checks show what they claim |
| Documents | `research/audcad_oos/PREREG.md` (s2a is new; s6 rule now "on 2020-2022"; s7's new bias line), `research/audcad_oos/run_oos.py`, `research/audcad_oos/test_run_oos.py`, `research/audcad_oos/selfcheck_out.txt`, `research/audcad_oos/MANIFEST.md`, all on `origin/main` |
| Sources | `reviews/fable_pass1/core.py`, `common.py`, `04_ladder_bars.py`, `01_null_calibration.py`, `test_core.py` |
| Your reply | ONE new file `reviews/argon_review_audcad_oos_3.md` on a NEW branch `review/argon-audcad-oos-3` from `origin/main`; commit, push, then `git checkout main` |

## 0. RULES (as the second review; rule 1 matters most)

1. **Every quote is copied, not recalled:** from `git show origin/main:<path>` output, character for character, cited
   as `- <path>:<line> ` followed by the line in backticks. If you cannot copy a line, write "not read". Claude checks
   every quote by script.
2. Verdicts: **DEFECT**, **GAP**, **CONFIRMED**, **NOT A DEFECT** (with a quote), **NOT READ**; for a DEFECT or GAP the
   smallest fix as replacement text.
3. **Read-only.** Run only read commands (`git show`, `git log`, `git diff`); no Python, no MetaTrader, no bar file.
4. Commit only `reviews/argon_review_audcad_oos_3.md` to `review/argon-audcad-oos-3`, push, then `git checkout main`.
5. Line-count bookends: first line exactly `This message has a line count at the bottom`, last line exactly
   `Line count: N`. ASCII only.

## 1. WHAT TO CHECK

1. **s2a's justification:** do `selfcheck_out.txt`'s per-year lines support it (quote them)? Was it made before any
   ladder run on the new bars (the commit order: `git log --oneline -6 -- research/audcad_oos/`, and whether any
   commit before `b1feed9` holds a ladder result on 2018-2022)? Is "from flat at the first bar of 2020, the subset's
   own blow-out median" the right way to cut it, or does it change the test in a way s2a does not state?
2. **The runner against the PREREG:** the ladder call (s3) as `04_ladder_bars.py`; the ten cells; the four
   variants; the sensitivity as net minus 0.4 x 0.0714 per close; the region, years and cells rules (s6) in
   `decide`, `passes`, `region`; `slice_bars` and the decide / report periods; the gate (s8). Any line that does not
   match the PREREG.
3. **The self-checks:** a (20 cells, both fills, against the references by hash), b, c, d. Does d now compare the
   bars with the same walk tick by tick, as `01_null_calibration.py` does? Is its reading in the commit message fair?
4. **Anything** that would make a 2020-2022 verdict misleading that s7 does not state.

## 2. YOUR REPLY's SHAPE

A header (branch, base hash, files read), items 1-4 with quotes and verdicts, then one line: **SOUND**, **SOUND WITH
CHANGES** (list them) or **NOT SOUND** (why).

Line count: 44
