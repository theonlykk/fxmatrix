This message has a line count at the bottom

# ARGON: REVIEW OF THE RUNBOOK FOR FLEET C's OPT RELOAD TO t2 (EURUSD CAP 9; AUDCAD ADD = EXIT 18, CAP 9)

| | |
|---|---|
| Written | 25 Oct 2026 ~04:50Z (HANDOFF s90 continued 4), Claude (Lead Engineer) |
| What | Read the runbook against the EA source and the presets. Find what is wrong or missing before the operator runs it on Monday 26 Oct |
| The runbook | `docs/runbooks/twoarm-reload-c-t2.md` on `origin/main` (all 107 lines) |
| The presets | `ea/presets_c/eurusd_opt_c_t2.set`, `ea/presets_c/audcad_opt_c_t2.set` against their `_t1` twins; `scripts/ic_geometry_twoarm_c_t2.json`; `research/opt_budget/check_c_t2.py` |
| The source | `ea/fxgrind.mq5`, `ea/grind_engine.mqh`, `ea/grind_recon.mqh`, `ea/grind_carry.mqh` at `origin/main` (EA code unchanged since `5bb5fdb`) |
| Your reply | ONE new file `reviews/argon_review_c_t2.md` on a NEW branch `review/argon-c-t2` from `origin/main`; commit, push, then `git checkout main` |

## 0. RULES FOR THIS REVIEW (read first)

1. **Quote every line you cite** as `<path>:<line>` followed by the line's text in backticks, exactly as it is at
   `origin/main`. If you did not read a file or a line, write "not read". Do not answer from memory: open it.
2. Every verdict is one of: **DEFECT** (the runbook is wrong, or a step would fail or harm a chart), **GAP** (a needed
   step or check is missing), **CONFIRMED** (the runbook's claim is right), **NOT A DEFECT** (say why, with a quote),
   **NOT READ**.
3. For any DEFECT or GAP, give the smallest change to the runbook's text that fixes it.
4. **Read-only.** Edit no file but your reply. Do not compile, do not run the MQL5 suite, do not launch MetaTrader,
   no `git stash`, no merge, no PR, no `git add .` or `-u` (add your file by name). You MAY run
   `python research/opt_budget/check_c_t2.py` and say what it prints.
5. Commit only `reviews/argon_review_c_t2.md` to `review/argon-c-t2`, push it, then `git checkout main` so
   `D:\fxmatrix` is left on `main`.

## 1. WHAT THE RELOAD DOES (context; check it, do not trust it)

Fleet C (wine-c, IC Markets demo) runs six instances: EURUSD, GBPCHF, AUDCAD, each an OPT arm and an ALT arm, all at
cap (`InpMaxLayers`) 7. Two charts change, by Remove then Attach with a new preset; no EA code changes:

- **EURUSD OPT (magic 22260201):** cap 7 -> 9 only. Exit unchanged, so no exit rebuild.
- **AUDCAD OPT (magic 22260401):** add = exit 6 -> 18, width 1.5 -> 4.5, stranded 2.5 -> 5.5, cap 7 -> 9. These are E's
  `ea/presets_e/audcad_opt_e_t3.set` values except the cap (E's is 7). The exits rebuild at start-up.

Worked example (AUDCAD OPT long): layers at 0.9800 and 0.9794, exits resting at 0.9806 and 0.9800, next add at 0.9788.
After the reload the claim is: exits rebuilt to 0.9818 and 0.9812 (entry + 18), the next add moved to 0.9776 (deepest
- 18); nothing fills at once because the exits move AWAY from the market.

## 2. CLAUDE'S AUDIT (runbook s0.1, K1-K7): give each a verdict with quotes

| # | Claim | Where Claude read it |
|---|---|---|
| K1 | Raising the cap cannot trip I7: it fails only when a side holds MORE layers than the cap | `grind_recon.mqh` 489-495 |
| K2 | The lattice acts only at depth >= cap: a side at 7 under cap 9 stops rolling and adds again | `grind_engine.mqh` 1401-1415, 1303-1304 |
| K3 | With rolled layers (virtual levels), the add target anchors on the lowest effective entry | `grind_engine.mqh` 2250-2288 |
| K4 | A changed exit is rebuilt at start-up from the stored exit label (`GRIND_GEO_EXIT_<magic>_L/_S`), clamped passive where needed | `grind_carry.mqh` 614; `grind_engine.mqh` 3074-3169 |
| K5 | After an exit rebuild the one-shot add re-price moves the resting add to the new distance | `fxgrind.mq5` 289-292; `grind_engine.mqh` 2561-2575 |
| K6 | C's six charts load the Experts copy built 21 Oct 16:21:21 | archive (`ea_build`), HANDOFF s89 continued 2: say NOT READ if you cannot check it |
| K7 | The commitment guard (positions + orders + resting entries <= 194) is not at risk on C's six instances with two at cap 9 | INFERRED (harness); check whether anything in source makes this unsafe |

## 3. THE RUNBOOK's OWN QUESTIONS (s8): answer each

1. K1-K5: is any path at a CAP RAISE with rolled layers (virtual levels) not covered, e.g. a re-roll state, or the
   lattice's extreme tracking on a side that was at cap 7 and is now below cap 9?
2. AUDCAD's exit change moves every exit 12 pips AWAY: is anything in the rebuild (clamps, carry shift records,
   ExitQ's rank-0 and furthest-exit rule, ADR-151's held middle exits) built for exits moving closer only?
3. Is Remove-then-Attach still the right path when the chart already runs the Experts copy (K6), or is F7 + Load
   now equivalent? (Claude's view: keep Remove-then-Attach; disagree only with a quote.)
4. Does a reload with a new cap need anything on pipshed or the archive (the geometry table, `vs_anchor`)?

## 4. ALSO CHECK

5. The two `_t2` presets differ from their `_t1` twins ONLY in the lines s1 names (and the warning line); nothing else
   moved (the magic, the telemetry instance, the key row, the per-side `-1.0` rows).
6. Runbook s3 step 2's read-back list against the preset files: is any input named wrong or missing?
7. Runbook s5 (rollback): is "cap 9 -> 7 trips I7 on a side holding 8 or 9 layers" right, and is there any other
   state (a virtual level, a stored exit label) that a rollback to `_t1` would trip on?
8. Anything else in the runbook that would hurt a live chart. Keep it to what you can quote.

## 5. YOUR REPLY's SHAPE

`reviews/argon_review_c_t2.md`: a header (branch, base hash, files read), then one row per item above (K1-K7, Q1-Q4,
items 5-8): the verdict, the quotes, and for a DEFECT or GAP the fixed runbook text. End with one line: **GO** (the
runbook may run as written), **GO WITH CHANGES** (list them) or **NO GO** (why).

Line count: 78
