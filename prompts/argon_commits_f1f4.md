This message has a line count at the bottom

# ARGON: REVIEW OF CURSOR'S COMMITS FOR PLAN 4's F1-F4 AND THE INPUT BUILDERS

| | |
|---|---|
| Written | 14 Oct 2026 ~21:45Z (HANDOFF s83), Claude (Lead Engineer) |
| What | Read Cursor's commits on two branches against the prompt they implement and the agreed restate. Find defects; confirm or refute Claude's findings (s2) |
| The prompt | `prompts/cursor_plan4_f1f4.md` at `3738152` (all of it) |
| The restate | `reviews/cursor_restate_f1f4.md` on `review/cursor-restate` `e4d96f4` (the agreed test arithmetic) |
| Part A | `origin/plan4-tools`: `2193b6b` (tests), `bcfc305` (code); base `3738152` |
| Part B | `origin/replay-plan4`: `19d8db6` (B-0, RT64-RT74), `538b15e` (F3), `68fe443` (F4), `acc93fd` (F1), `9748480` (F2), `7d8fa13` (record); base `replay-harness` `efada62` |
| Your reply | ONE new file `reviews/argon_commits_f1f4.md` on a NEW branch `review/argon-commits-f1f4` from `origin/main`; commit, push, then `git checkout main` |

## 0. RULES FOR THIS REVIEW (read first)

1. **Quote every line you cite**, as `<commit>:<path>:<line>` followed by the line's text in
   backticks, exactly as it is at that commit. If you did not read a file or a line, write
   "not read". Do not summarise a document from memory: open it.
2. Every verdict is one of: **DEFECT** (the code or a test does not do what the prompt says, or
   will fail), **CONFIRMED** (Claude's finding is right), **NOT A DEFECT** (say why, with a
   quote), **NOT READ**.
3. For any DEFECT, give the smallest change that fixes it, with hand-derived values for a test
   that would catch it (times in ms, prices to 5 decimals).
4. **Read-only.** Do not edit any file but your reply. Do not compile, do not run the MQL5 suite,
   do not launch MetaTrader, do not `git stash`, do not merge, no PR, no `git add .` or `-u`
   (add your file by name). You MAY run the Python tests on `plan4-tools`
   (`python -B -m unittest` from `research/replay`) and say what they print.
5. Commit only `reviews/argon_commits_f1f4.md` to `review/argon-commits-f1f4`, push it, then
   `git checkout main` so `D:\fxmatrix` is left on `main`.

## 1. AUDIT TRAIL (Claude's reading at the SHAs above; check it, do not trust it)

| # | Fact | Where | Status |
|---|---|---|---|
| R1 | Commit order and files as the prompt asks; Part B changes only `ea/fxgrind_replay_core.mqh` and `ea/fxgrind_replay_tests.mq5`; no `ea/grind_*.mqh`, `ea/fxgrind.mq5` or preset touched | `git diff --stat efada62 origin/replay-plan4` | READ |
| R2 | RT1-RT63 unchanged: the test diff is additions (RT64-RT74, their calls in `OnStart`) and two header comment lines | `git diff efada62 origin/replay-plan4 -- ea/fxgrind_replay_tests.mq5` | READ |
| R3 | B-0's core change is two empty stubs, `Rpl_AddTestSession` and `Rpl_SessionsCount` (returns 0), so B-0 compiles; F1 fills both | `19d8db6`, `acc93fd` | READ |
| R4 | Python: 195 OK at `bcfc305`; at `2193b6b` 2 failures and 6 errors, all eight new tests; two invariance tests pass both ways (reported in the commit message) | run by Claude in a sandbox | MEASURED |
| R5 | F3: the two lines gone from `Rpl_SyncResetToTrueBook`; the segment-start lines kept | core at `7d8fa13` 3092-3093 | READ |
| R6 | F4: `g_rpl_last_engine_attempt_tick_ms`, strict `> 5000`, set either way, 0 at segment start and in `Rpl_ResetAll`; timed keys on `stage_market_ms`, timing 0 on `t` | `68fe443` | READ |
| R7 | F1: `Rpl_SessionIsOpen` gates `Rpl_TmBrokerStep` and `Rpl_FillsOnTick`; `Rpl_SessionSendGateBegin / End` around `Rpl_TmRunStage`, the timed DEAL handler, `Rpl_ProcessCloseByDone` and the timing-0 CLOSEBY, LATTICE, ENGINE and TIMER calls; `Rpl_LoadSessionsFile` per segment after `Rpl_ResetAll`, logged once | `acc93fd` | READ |
| R8 | F2: `RplTrueLayer.exit_pos`; EXT marks the newest non-closing true-book layer of that side and number; `Rpl_SyncApplyRealExtToSide` (touched = `exit_position_ticket != 0` or, timed, the exit order executing); `Rpl_ProcessCloseByDone` defers a pair whose `t1` is in the true book (sync, not while completing); at an `OUT_BY` row whose `position_id` is in the true book, `Rpl_SyncPopCloseByForEntTicket` (deferred list, pending timed `CB_DONE`, EA queues) then `Rpl_SyncCompleteCloseByAt`, before the row's removal | `9748480` | READ |

## 2. CLAUDE'S FINDINGS (confirm or refute each, with quotes)

- **C-1. A gap in Part A (the prompt's fault):** `build_inputs.py`'s CLI (`main`) has no
  `--sessions` flag; only `fleet_files` gained `sessions_file`. The development gate (plan 4 s4)
  rebuilds the calibration window (set `eurusd_20261008`) with `build_inputs.py`, so F1 could not
  be switched on for that window. Is that right, and is anything else missing for the gate
  (the sessions file must sit in the set's folder and its manifest: `tools/replay_run.ps1
  -Mode Inputs` copies only the files the manifest lists)?
- **C-2. A test gap in F1:** RT67 runs at timing 0 only, so the send gate in the TIMED path
  (`Rpl_TmRunStage`, the DEAL handler, the CB_DONE handler) is never run by a test. Right? If so,
  give a timed case with hand values: the tick times, the stage start times (place 287 ms,
  modify 288, closeby 294, remove 43, latency 261; core 346-352), and the expected order rows.
- **C-3. Part A on the default path:** `join_sends` now runs even with no extra file (drops
  `_meta`, dedups, sorts by `(ea_time_ms, seq, id)`), and ROLL rows of one ms now sort by `seq`
  (`build_real.py` key `(t, 1, seq)`, was `(t, 1, 0)`). Claude reads both as harmless because the
  exporter writes `send_logs` oldest first by `ea_time_ms`, then `seq`, then `id` (pipshed
  `6ea487e`), and `build_orders._events` sorts by `(time, input index)`. Proposed proof at the
  gate: rebuild plan 3's holdout set with NO new flags; every file hashes equal to
  `research/replay/inputs/eurusd_holdout.sha256` except `real_eurusd_b / c / d.csv`, whose only
  differences are the 12 ROLL rows of the prompt's A11. Sound? Anything else that could differ?
- **C-4. B-0's message does not state which RTs should fail at B-0** (prompt s3). Claude's
  expectation, from reading: RT1-RT63 all pass (461); at least one assertion fails in each of
  RT64-RT74: RT64 (the add is modified to 1.09859), RT65 (both modes: a send on the 6 s tick and
  5 L1 rows), RT66 (the two gated cases fill at 00:00; the ungated pass), RT67 (the four closed
  ticks; 23:58:59 and 00:01:00 pass), RT68 (count, gating, abort; the no-column case passes),
  RT69-RT74 (depth and timing: the layer leaves at the EXT row or at the replay's own CB_DONE).
  At `7d8fa13` all pass: 461 + 95 = 556 assertions (RT65's helper runs twice: 12 at timing 0,
  16 timed). Confirm or refute per RT, quoting the assertion that fails at B-0.
- **C-5. Minor, proposed "record, do not fix":** the F2 completion writes no `timing.csv` row; its
  order rows (stamped at the OUT_BY row's time) can follow the tick's SYNC rows (stamped at the
  tick) in the order log; it seeds the market at the OUT_BY row's time even when the EA is busy
  (`g_rpl_tm_free_ms` later); `g_rpl_sync_idx` is now set at the start of each sync row (same
  final value). Does any of these change an output that `compare.py` or `score_plan3.py`
  reads? If yes, it is not minor.

## 3. QUESTIONS (answer each; a quote for every claim)

- **Q1. F2's completion inside the sync step** (`Rpl_SyncCompleteCloseByAt`). Does it do every
  item of the prompt's "How the completion runs": the market seeded at the row's time; an order
  the EA places in it registered in the broker book (timed `Rpl_BkPlace` via
  `Rpl_TmDiffStageSends`) and the order scan (timing 0); outputs drained at the row's time; a
  queued pair taken off the EA queue first; only pairs from the queue, a pending `CB_DONE` or
  the deferred list? Is calling `Rpl_TmProcessSyncRemovals(sync_tick_ms)` (timed) or
  `Rpl_OrderLogDiff(sync_tick_ms, "SYNC")` (timing 0) BEFORE the completion right, so that the
  completion's diff holds only its own sends?
- **Q2. "Touched" in `Rpl_SyncApplyRealExtToSide`.** Is there a case where the replay has filled
  or is filling the exit but the test misses it (e.g. timing 0, the exit order filled earlier in
  the same tick; a re-seed between the touch and the deal event), or where it reads touched but
  the replay made no exit (a stale `exit_position_ticket` from an earlier exit of the same
  number)? Give the case in ticks and prices, or NOT A DEFECT with quotes.
- **Q3. The deferral key.** `Rpl_ProcessCloseByDone` defers when `before[i].t1` is in the true
  book. Is `t1` always the ENT position in every place a pair is queued (engine 3011-3013,
  3440-3442 at `efada62`; `grind_closeby.mqh` `Grind_QueueCloseBy`)? Is a pair whose ENT is a
  replay-only layer (not in the true book) right to complete at once, as today?
- **Q4. F1 coverage.** Is there any path that can send or fill while CLOSED and is not gated: the
  timed TIMER handler, the queued-OnTick handler, the F2 completion, a sync reset that removes
  orders (`Rpl_TmProcessSyncRemovals`), a deal event already pending when the session closes?
  Which of these SHOULD be gated by the prompt's words ("every EA stage or handler whose start is
  CLOSED"), and which are not sends?
- **Q5. F4 against live.** Live's guard: `Grind_GuardsAllowTrading` (engine 1996-2011),
  `Grind_FeedStaleAfterTick` (`grind_pure.mqh` 255-266). Is "the previous engine ATTEMPT in this
  segment, never stale at a segment's first attempt" the same as live across an init (what does
  live's `g_grind_last_feed_tick_msc` hold after `OnInit`, `fxgrind.mq5`)? In the timed path, is
  `stage_market_ms` the tick the EA's guard would have seen?
- **Q6. Compile risks in MetaEditor** (the operator compiles in the GUI; Cursor could not). Any
  declaration after use, struct copy of a struct holding a string or an array, `int` / `uint`
  mixing (`RplSendGateSnap.prev_cb_rc` is `uint`, `g_grind_closeby_test_send_retcode` is `int`),
  a missing `return`, or a name clash with an EA global?
- **Q7. The new tests: can any pass for the wrong reason** at `7d8fa13` (a fill, a recenter or
  another send producing the same rows; a helper whose assertions are skipped by an `if`, as
  RT65's `if(l1_n == 4)`)? For RT64, check the ROLL row it uses (`...,ROLL,L,0,,6401,1.09800`):
  does the roll change L2's add target away from 1.09860 at `7d8fa13`?
- **Q8.** What fact is missing?

## 4. NEGATIVE SPACE

- No edit to any file but `reviews/argon_commits_f1f4.md`; no commit on any branch but
  `review/argon-commits-f1f4`; nothing on `main`, `plan4-tools`, `replay-plan4` or
  `replay-harness`.
- No compile, no suite, no MetaTrader, no deploy, no stash, no merge, no PR.
- Do not propose any change outside F1-F4 and the builders (plan 4 s2: any other harness change
  is a new plan).
- Do not restate the prompt back; answer s2 and s3.

## 5. REPLY FORMAT

`reviews/argon_commits_f1f4.md`: a header naming the SHAs you read; then C-1 .. C-5, then
Q1 .. Q8, each with its verdict word first, then the quotes, then (for a DEFECT) the fix and its
test values. End with a list of every file and line range you opened.

Line count: 135
