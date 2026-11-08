This message has a line count at the bottom

# ARGON: REVIEW OF THE PRE-REGISTRATION FOR THE NO-CARRY TEST

| | |
|---|---|
| Written | 7 Nov 2026 (HANDOFF s93), Claude (Lead Engineer) |
| What | Attack the pre-registration before any runner exists: is every arm implementable on the committed engine, is every measure computable, is the decision rule fixed and fair, is anything missing or gameable |
| The document | `research/nocarry/PREREG.md` on `origin/main` (all of it) |
| fxmatrix sources | `research/opt_budget/sim.py`, `research/opt_budget/MECHANICS.md`, `research/longrun/run_bars.py`, `research/longrun/results.md`, `research/longrun/MANIFEST.md`, `research/cluster/PREREG.md` (s3 and its notes on server time), `ea/grind_pure.mqh` (`Grind_PragueUtcOffset`), `handoffs/HANDOFF_2026-09-24.md` (s93) |
| Your reply | ONE new file `reviews/argon_review_nocarry.md` on a NEW branch `review/argon-nocarry` from `origin/main`; commit, push, then `git checkout main` |

## 0. RULES FOR THIS REVIEW (read first)

1. **Quote every line you cite** as `<path>:<line>` followed by the line's text in backticks, exactly as it is at
   `origin/main`. If you did not read a file or a line, write "not read". Open it; do not answer from memory.
2. Every verdict is one of: **DEFECT** (wrong, or not implementable or computable as written), **GAP** (a needed
   measure, check or rule is missing), **CONFIRMED**, **NOT A DEFECT** (say why, with a quote), **NOT READ**.
3. For any DEFECT or GAP, give the smallest change to the document's text that fixes it.
4. **Read-only.** Edit no file but your reply; no helper scripts left in the repo (any in a scratch folder outside
   `D:\fxmatrix`, or deleted before you commit). Do not run the simulator or any bars; the bars are not in the repo
   and no result may be produced before the pre-registration is final. Do not compile, do not launch MetaTrader,
   no `git stash`, no merge, no PR, no `git add .` or `-u`.
5. Commit only `reviews/argon_review_nocarry.md` to `review/argon-nocarry`, push it, then `git checkout main`.
6. **Line-count bookends:** the reply's FIRST line is exactly `This message has a line count at the bottom` and its
   LAST line is exactly `Line count: N`, N being the file's total number of lines including both. ASCII only.

## 1. WHAT TO CHECK

1. **s3, the cut, against `sim.py`:** list every piece of `Instance` and `Side` state the cut must clear or reset
   (orders, `events`, `cb_queue`, `busy`, `l0`, `add`, `extreme`, `track_from`, layers with `vl`, `closing` layers,
   `ent_sent`, anything else). Is a layer whose exit has dealt but whose close-by has not run handled right by s3
   step 2? Can the cut and the flat window be done in the runner without editing `sim.py` (`run_instances` would be
   re-written in the runner: say whether that breaks s8's "importing `sim.py` unchanged" or self-check a)?
2. **s2, the times:** are the bars' times server time (quote `run_bars.py` and `research/cluster/PREREG.md`)? Is
   01:00 server FTMO's day start in both halves of the year (quote `Grind_PragueUtcOffset`), and how many days a
   year is it out by an hour? Is 23:45 server before the rollover's wide spreads on these bars, or should the cut be
   earlier? Does `run_bars.py`'s use of `fromtimestamp(t, utc)` for weekdays still give the right server day?
3. **s4, the FTMO-day loss:** computed from five-minute marks, it misses lows between marks: how big can that miss
   be with ticks 15 s apart, and should the lowest equity be tracked on every tick instead? Is "balance at the
   day's start" right for FTMO (the repo's record of the trial's rule; say where it is recorded and not read on
   FTMO's site)?
4. **s5, the self-checks:** is a) achievable if the runner re-writes the loop? Is c) sufficient? Is e) checkable
   from the bars alone? Anything that would make a check fail for a reason that is not an error.
5. **s6, the rule:** is it fixed before any number? Could DAY pass or fail whatever happens (e.g. is "at most four
   $500 days" loose or tight against what the continuous run's day losses imply)? Is judging the twelve instances
   together, not each arm, fair? Is 2026 (to 23 Oct) as a year fair?
6. **s7, the biases:** confirm "no swap anywhere" (quote `run_bars.py`'s call to `run_pair` and `sim.py`'s
   `rollover`). Anything missing (the weekly 4,000-bar skip and holidays; the restart's first hour; latency at the
   cut; the bar spread field's meaning)?
7. **s1, the worked example:** check the arithmetic and that it matches s3's mechanics and GBPUSD's t3 preset in
   `run_bars.py`'s `GEO`.
8. **Anything that would let the result be bent after the fact** (a choice left open, a measure without a formula),
   and anything missing that the C162 memo will need from this test.

## 2. YOUR REPLY's SHAPE

`reviews/argon_review_nocarry.md`: a header (branch, base hash, files read), then one row per item 1-8: the verdict,
the quotes, and for a DEFECT or GAP the fixed text. End with one line: **SOUND** (commit as written), **SOUND WITH
CHANGES** (list them) or **NOT SOUND** (why).

Line count: 62
