This message has a line count at the bottom

# ARGON: REVIEW OF GBPCHF OPT's ADDITION TO FLEET C's t2 RELOAD (a delta review; tonight from 22:30Z)

| | |
|---|---|
| Written | 25 Oct 2026 ~21:40Z (HANDOFF s91 continued 6), Claude (Lead Engineer) |
| What | The operator added GBPCHF OPT (magic 22261001) to tonight's t2 reload: cap 7 -> 9 only, like EURUSD OPT. You reviewed the runbook for the other two charts this morning (`reviews/argon_review_c_t2.md` on `review/argon-c-t2`). Review ONLY what this commit changed |
| The change | `git diff HEAD~1 HEAD` on `origin/main` (this prompt's own commit): `scripts/ic_geometry_twoarm_c_t2.json`, `ea/presets_c/gbpchf_opt_c_t2.set` (new), `research/opt_budget/check_c_t2.py`, `docs/runbooks/twoarm-reload-c-t2.md` |
| Your reply | ONE new file `reviews/argon_review_c_t2_gbpchf.md` on a NEW branch `review/argon-c-t2-gbpchf` from `origin/main`; commit, push, then `git checkout main` |

## 0. RULES

1. Quote every line you cite as `<path>:<line>` followed by the line's text in backticks, exactly as at `origin/main`.
2. Verdicts: **DEFECT**, **GAP**, **CONFIRMED**, **NOT A DEFECT** (with a quote), **NOT READ**. For a DEFECT or GAP,
   the smallest text change that fixes it.
3. Read-only: edit no file but your reply; no helper script left in `D:\fxmatrix`; no compile, no MetaTrader, no
   `git stash`, no merge, no PR, no `git add .` or `-u`. You MAY run `python research/opt_budget/check_c_t2.py`.
4. Commit only your reply to `review/argon-c-t2-gbpchf`, push, then `git checkout main`.
5. Bookends: FIRST line exactly `This message has a line count at the bottom`, LAST line exactly `Line count: N` (N =
   the file's lines including both). ASCII only. **Keep it short: this is a delta; aim under 150 lines.**

## 1. CHECK

1. `gbpchf_opt_c_t2.set` against `gbpchf_opt_c_t1.set`: only `InpMaxLayers` and `InpConfigWarning` differ; magic,
   instance, width, add, exit, stranded, deadband, lattice, re-roll, gate, eject, breaker, the key row unchanged.
2. `eurusd_opt_c_t2.set` and `audcad_opt_c_t2.set` are byte-identical to the previous commit (the generator re-run).
3. The checker: GBPCHF's expected values right; does it still catch any other change (read the code)?
4. The runbook's edits: s0's GBPCHF row (`geo=`, `rebuild=` false/false), K7's 132, s1 and s2.3's fingerprint and
   count, s2.4's three lines, s3's order, magic and stranded read-back (3.5), step 4's GBPCHF expectation (the short
   add at 1.10405 = 1.10315 + 9 pips), s5 (GBPCHF's short at 7: flatten only).
5. GBPCHF's state in s0.2 (short 7 at cap, not rolled because the long holds 1 under roll gate 0): after a cap raise
   to 9, does anything differ from EURUSD's case that your morning review covered (K1-K5)? Quote the gate's source.
6. s0.2's "observed" note (GBPCHF long's resting add 15 pips from its target): is there a reason in source a reload
   would move it, or leave it? Say which, with quotes; this is not a blocker unless it would harm the chart.

End with one line: **GO**, **GO WITH CHANGES** (list them) or **NO GO** (why).

Line count: 39
