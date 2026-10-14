This message has a line count at the bottom

# CURSOR PROMPT: PLAN 4's HARNESS FIXES F1-F4 AND THE INPUT BUILDERS (TESTS FIRST)

| | |
|---|---|
| Written | 14 Oct 2026 (HANDOFF s82 continued), Claude (Lead Engineer) |
| Why | Plan 3 FAILED on T1 (C 94.4%, D 94.9%). Its nine misses have four mechanical causes in the harness and one in the input builder (`docs/research/replay-consult-plan4.md` s2-s3, s8, s10). Plan 4 (`docs/research/replay-calibration-eurusd-4.md` s2-s4, REVIEWED and agreed) allows exactly these fixes, F1-F4, and nothing else |
| Branches | **Part A (Python):** `plan4-tools` from `main` (`ebeaee7` or later). **Part B (MQL5):** `replay-plan4` from `replay-harness` `efada62`. Never commit to `main` or `replay-harness` |
| Review | This prompt is committed; the reviewer reads it at its commit; Cursor reads the same bytes |

## 0. RESTATE AND STOP (do this first; write nothing else)

1. Restate each change of s2 and s3 in one line, quoting this prompt.
2. List every test you will add (name, one line), and **for each MQL5 test the hand-derived
   expected values** (times, prices, counts) you will assert, with the arithmetic.
3. Say which existing tests (Python and RT) you expect each change to affect, and why.
4. STOP. Wait for the operator's "go".

## 1. AUDIT TRAIL (verified facts; file and line at the given commit)

| # | Fact | Where | Status |
|---|---|---|---|
| A1 | IC EURUSD trade session: Mon-Thu 00:01-23:59, Fri 00:01-23:57 server (quotes from 00:00). Read as MT5's [from, to): closed [23:59:00, 00:01:00) Mon-Thu nights, [Fri 23:57:00, Mon 00:01:00) | operator, Specification window, 14 Oct; plan 4 s2 | MEASURED |
| A2 | The timed broker step fills any touched order on any tick: `Rpl_TmBrokerStep` | `ea/fxgrind_replay_core.mqh` 1117-1135 @ `efada62` | READ |
| A3 | The timing-0 fill step: `Rpl_FillsOnTick` | core 2371-2423 | READ |
| A4 | The EA's send seams: `g_grind_order_test_send_ok`, `g_grind_order_test_send_retcode` (place, modify, remove) | `ea/grind_engine.mqh` 106-108, 268-317 | READ |
| A5 | The close-by send seam: `g_grind_closeby_test_send_ok`, `g_grind_closeby_test_send_retcode` | `ea/grind_closeby.mqh` 29-31 | READ |
| A6 | `Grind_GuardsAllowTrading` (called only at the top of `Grind_OnTickEngine`, engine 3193, and in live's quarantine branch, `fxgrind.mq5` 477) refuses a tick when `Grind_FeedStaleAfterTick` finds more than `GRIND_FEED_STALE_MS` (5000) since the last call (strict `>`; the first call, last <= 0, is not stale) | engine 1996-2011; `ea/grind_pure.mqh` 11, 255-266 | READ |
| A7 | The harness defeats A6: it sets `g_grind_last_feed_tick_msc` to the terminal's live tick before the EA runs, so the guard never fires | core 2670-2672 (timing 0), 2768-2770 (timed) | READ |
| A8 | `Rpl_SyncResetToTrueBook` sets `g_grind_start_add_reprice_long / _short = true` on every sync reset (core 2534-2535); `Grind_EnsureAddNext` then uses a 0.05-pip deadband once (engine 2561-2566). Live sets them only in `OnInit` (`fxgrind.mq5` 291-292); the harness also at segment start (core 2803-2804) | as given | READ |
| A9 | Sync: `Rpl_ApplySyncDealsUpTo` (core 2539-2595): an `EXT` row removes the side's newest layer of that number from the true book (2555-2570); an `OUT_BY` row removes the true-book entry whose ticket is the row's `position_id` (2571-2579); then `Rpl_SyncResetToTrueBook` | as given | READ |
| A10 | The replay's own close-by completes in `Rpl_ProcessCloseByDone` (core 2291-2368), from `CB_DONE` (timed, core 1005-1024) or at the end of the tick (timing 0, core 2716) | as given | READ |
| A11 | `build_real.py` times ENT / EXT / OUT_BY by `deal_time_broker_msc` and ROLL by `ea_time_ms` + 3 h (lines 51-75). The EA host's clock ran 485-2,515 ms behind IC's: 12 ROLL rows of plan 3's holdout fall between an exit and its close-by although every one comes after the close-by in the archive's `seq` (shared by `fill_logs` and `ea_events` within a `session_id`) | `research/replay/build_real.py`; consult s10 R2-3 | MEASURED |
| A12 | `send_logs` keep 14 days. `build_holdout.py` loads one sends file a fleet (line 126); its window end and first segment ids are constants (lines 35-38) | `research/replay/build_holdout.py` | READ |
| A13 | Run files: header `...,seed_file,ticks_file,orders_file` (`build_segments.py` 22-24); the harness reads the optional `orders_file` column (`Rpl_LoadOrdersFile`, core 1883) | as given | READ |

## 2. PART A: PYTHON (branch `plan4-tools` from `main`)

Tests first, in their own commit, run with `python -B -m unittest` from `research/replay`; then
the code, in its own commit. Report the new tests failing before the code and passing after, and
**any new test that passes in both states**.

- **A-1. `build_real.py`: the ROLL clock (A11).** A ROLL row's time becomes
  `max(ea_time_ms + SERVER_OFFSET_MS, T)`, where `T` is the largest `deal_time_broker_msc` of the
  `fill_logs` rows of the SAME `session_id` whose `seq` is LOWER than the roll's `seq` (no such row:
  unchanged). Ties keep the existing order (a roll after the fills of its ms). Rows without `seq` or
  `session_id` (old test fixtures): unchanged. Tests (hand values): a roll at fill-time minus 485 ms
  with a lower `seq` than both OUT_BY rows moves to the OUT_BY time and sorts after them; a roll
  with a lower `seq` than a fill keeps its time; another session's fills are ignored; the existing
  tests unchanged.
- **A-2. `build_segments.py` / `build_inputs.py`: an optional `sessions_file` column.** When a
  sessions file name is given, the run header gains `,sessions_file` after `orders_file` and every
  row carries the name; when not given, the output is byte-identical to today's (test it).
- **A-3. `build_holdout.py`: the plan 4 window (A12).** New optional arguments, all defaulting to
  plan 3's values so that a build without them is byte-identical to today's (test it on a synthetic
  archive): `--window-end-ms` (default `1791939600000`), `--first-ids` (default `31,41,51`),
  `--sessions FILE` (copied into `--out` and named in the run files, A-2), and
  `--sends-extra-b / -c / -d` (each optional, one file). Sends are joined: every `send_logs` row of
  both files, deduplicated by `id` (two rows with one `id` and different content: an error), sorted
  by (`ea_time_ms`, `seq`, `id`) as the exporter writes them; `_meta` lines dropped from the join.
  Tests: a duplicate read once; a conflicting duplicate refused; the order; the defaults.
- **A-4.** A file `research/replay/inputs/sessions_eurusd_ic.csv`: header
  `day_of_week,trade_from,trade_to` (0 = Sunday, as MQL5 `day_of_week`; times HH:MM server), rows
  `1,00:01,23:59`, `2,00:01,23:59`, `3,00:01,23:59`, `4,00:01,23:59`, `5,00:01,23:57`. ASCII, LF.

## 3. PART B: MQL5 (branch `replay-plan4` from `replay-harness` `efada62`)

Files you may change: `ea/fxgrind_replay_core.mqh`, `ea/fxgrind_replay.mq5`,
`ea/fxgrind_replay_tests.mq5`. **No other file under `ea/`** (the harness mirrors the EA at
`5bb5fdb`: `RPL_MIRRORS_EA` stays). Commits: B-0 the tests (all new RTs, against the current code;
state which you EXPECT to fail there, and why: you cannot run them); then one commit for each of
F3, F4, F1, F2, in that order; then the record. The operator compiles and runs the suite at B-0
(the new RTs must fail as you stated, the 461 existing must pass) and at the last commit.

- **F3 (A8).** Remove the two lines in `Rpl_SyncResetToTrueBook` (core 2534-2535). Keep them at
  segment start (2803-2804).
- **F4 (A6, A7).** The harness applies the stale-feed rule itself, in both paths: before calling
  `Grind_OnTickEngine` (timed `STAGE:ENGINE`, core 924; timing 0, core 2703), compare the
  time of the tick the EA will see (timed: the newest tick at the stage's start,
  `Rpl_TmMarketMsAt`; timing 0: the tick) with the tick time of the previous engine ATTEMPT in this
  segment: if the difference is more than 5000 ms (strict), skip the call for this tick. Record the
  tick time as the last attempt either way. The first attempt of a segment is never stale. No other
  stage is affected. Leave A7 as it is (the EA's own guard stays inert in the replay).
- **F1 (A1-A5).** A trade-session table, loaded from the run row's optional `sessions_file` (A-2,
  A-4); no column or empty: no table (today's behaviour), and the log says so: print
  `RPL|SESSIONS|<file>|<rows>` or `RPL|SESSIONS|none` once a run. A named file that is missing or
  malformed aborts the run. With a table, a time is OPEN when its server day has a row and
  `trade_from <= time-of-day < trade_to`; otherwise CLOSED. While CLOSED:
  - **Broker:** no order is touched or filled (timed `Rpl_TmBrokerStep`; timing 0
    `Rpl_FillsOnTick`). An order touched by the first OPEN tick fills as today (timed: at the tick's
    quote, after the latency; timing 0: at its price).
  - **Sends:** every EA stage or handler whose start is CLOSED (timed: `STAGE:CLOSEBY`, `LATTICE`,
    `ENGINE`, `TIMER`, the `DEAL` and `CB_DONE` handlers; timing 0: the same calls in
    `Rpl_ProcessOneTickInstant`) runs with both send seams refusing:
    `send_ok = false`, `retcode = 10018` (TRADE_RETCODE_MARKET_CLOSED); restored after the stage.
  - Tests may set the table directly (a test helper); `Rpl_ResetAll` clears it.
- **F2 (sync only; A9, A10).** A layer leaves the book at its real close-by, never earlier:
  - **a.** A real `EXT` row no longer removes the layer from the true book; it marks it closing
    (its exit position = the row's `position_id`), using the same layer selection as today.
  - **b.** If the engine's layer still has a resting exit order at that row (the replay did not fill
    it): remove that order from the replay's book, cancel its pending deal events, and set the
    layer's `exit_position_ticket` to the row's `position_id`. **Write no deal row** (as sync ENT
    rows write none): the replay must not be credited with a deal it did not make.
  - **c.** The real `OUT_BY` row removes the layer from the true book (as today); the reset then
    removes it from the engine.
  - **d.** The replay's own close-by completion (`Rpl_ProcessCloseByDone`) does not complete a pair
    whose ENT position is still in the true book: it is deferred, and completed when that ENT's real
    `OUT_BY` row is applied, at that row's time, BEFORE the reset of that row. If the real `OUT_BY`
    was applied first, the completion runs at its own time, as today.
  - **e.** No exit order is re-placed for a closing layer between its `EXT` and `OUT_BY` rows.
- **Tests (B-0), hand-derived, each asserting the NEW behaviour, at least:**
  - **RT64 (F3).** Sync; a long add order resting at X; a sync row triggers a reset; the next tick
    has bid = X, so the clamped add target is X - 0.00001 (ADR-013 buy clamp). Expected: no MODIFY;
    the order stays at X. (Today: MODIFY to X - 0.00001.)
  - **RT65 (F4, timed and timing 0).** A tick sequence where the engine would send on every tick,
    with gaps of 1 s, 6 s, 1 s, and one gap of exactly 5000 ms. Expected: no engine send on the tick
    after the 6 s gap; sends on the others (exactly 5000 ms is not stale); the first tick of the
    segment sends.
  - **RT66 (F1 broker, the 12 Oct open).** A buy limit at 1.11909 resting from Friday; ticks Fri
    23:56:59.456 (bid 1.12007 / ask 1.12019), Mon 00:00:00.188 (1.11847 / 1.11903), Mon
    00:01:00.170 (1.11847 / 1.11903), Mon 00:01:00.372 (same), Mon 00:02:00.174 (same); the A-4
    table. Expected, timed base: one fill, at 1.11903, at 00:01:00.170 + the latency (base 261 ms:
    00:01:00.431); none at 00:00. Timing 0: one fill at 00:01:00.170 at 1.11909. Without a table:
    today's fill at 00:00:00.188 (+ latency).
  - **RT67 (F1 sends and boundaries).** Ticks where the engine would place an order at Tue 23:58:59,
    23:59:00.000, 23:59:30, Wed 00:00:30, 00:01:00.000, and Fri 23:57:30. Expected: the sends at
    23:59:00.000, 23:59:30, 00:00:30 and Fri 23:57:30 are refused (no order); 23:58:59 and
    00:01:00.000 succeed.
  - **RT68 (F1 file).** A run file with `sessions_file` loads it (`RPL|SESSIONS|...|5`); a named
    missing file aborts; no column: `RPL|SESSIONS|none` and no gating.
  - **RT69 (F2 d, the C 17:16 case).** Sync; a short layer whose exit the replay fills itself;
    the real `EXT` 9 ms later; the real `OUT_BY` about 1 s later; ticks between. Expected: the
    side keeps depth 1 until the first tick at or after the `OUT_BY` row; the new short L0 is
    placed only from that tick; the OUT_BY deal rows carry the real OUT_BY time. (Today: L0 on the
    first tick after the EXT row.)
  - **RT70 (F2 b, e).** Sync; the replay does NOT fill the exit; the real `EXT` arrives. Expected:
    the resting exit is gone, no deal row for it, no new exit order, depth 1 until the `OUT_BY`
    row, 0 after.
  - **RT71 (F2 d, CB_DONE late).** As RT69 but the real `OUT_BY` before the replay's `CB_DONE`.
    Expected: the completion at `CB_DONE`'s time, as today.
  - **RT41 must still pass unchanged** (one exit, at T1).
- **The record (last commit).** The suite is NOT run by you (it needs a compiled `.ex5`): write
  `PENDING: operator compile and suite` where the figure would go.

## 4. NEGATIVE SPACE

- Do not deploy, do not CLI compile, do not launch MetaTrader, do not run the suite, do not
  `git stash`, do not check out files from other commits, do not merge, no PR, no `git add .` or
  `-u` (add files by name), do not push to `main` or `replay-harness`.
- Do not change any EA file (`ea/grind_*.mqh`, `ea/fxgrind.mq5`, `ea/fxgrind_tests*.mq5`), any
  preset, `compare.py`, `score_plan3.py`, `live_spread.py`, or any existing input set or result
  (A-4 adds a new file; it changes none).
- Do not change an existing test's expected value. If an existing test fails after a change,
  STOP and report it (test, value, why) before touching it.
- Do not model anything not in s2-s3: no new latency, no gap fill for timing 0, no other session
  logic, no change to `Rpl_InNightlyGapExclude` (a report filter only).
- Python: standard library only; ASCII; LF; no BOM. MQL5: declare globals before first use.

## 5. FAILURE MODES: STOP AND REPORT

- An F-change seems to need an EA file, or a seam that does not exist.
- F2's deferral (d) leaves a layer in the engine after its ENT has left the true book, or removes
  one still in it, in any test.
- A new Python test passes before its code: report which. For MQL5, a new RT you cannot show will
  fail at B-0: say so in the restate.
- The rows of A-1 cannot be matched by `session_id` and `seq` in a fixture or archive.
- Anything in this prompt contradicts the code: quote both.

## 6. QUESTIONS FOR THE REVIEWER (answer inside the review; do not edit this file)

- **Q1.** F2 d defers the replay's own close-by completion to the real `OUT_BY`. Is "complete it
  at the real OUT_BY's time, before that row's reset" right, or should the completion keep its own
  time and only the layer's removal wait?
- **Q2.** F2 b writes no deal row for a real exit the replay did not make. Right for T1?
- **Q3.** F4 keys the stale rule on the previous engine ATTEMPT (not the previous tick). Right,
  given live's guard updates only when it is called?
- **Q4.** F1 refuses sends by the stage's start time. Any stage whose sends could straddle 00:01?
- **Q5.** What fact is missing?

Line count: 181
