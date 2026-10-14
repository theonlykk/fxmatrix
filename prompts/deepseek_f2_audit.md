This message has a line count at the bottom

# DEEPSEEK R1 -- RED-TEAM F2: THE REPLAY HARNESS'S SYNC CLOSE-BY

You are auditing ONE change on a feature branch (`replay-plan4` at `7d8fa13`), before it is
compiled and used. Nothing here runs live: it is a REPLAY harness. Find what the tests cannot
see. The attached files carry NO line numbers: cite `file`, `function` and QUOTE the line (one
line, or part of one). A claim without a quote is discarded. If you did not see something,
say "not in the attached files" rather than guess.

**Attached:** `fxgrind_replay_core.mqh` (the harness at `7d8fa13`, whole);
`replay_core_F1F4.diff` (its diff from the base `efada62`: F3, F4, F1 and F2 together; F2 is
yours); `replay_tests_RT64_RT74.mq5` (the new tests; RT69-RT74 are F2's);
`grind_engine_deals_exitq.mqh` (two excerpts of the EA engine, unchanged: deal handling to
`Grind_OnTickEngine`, and `Grind_ProcessDeal` to `Grind_ExitQManageSide`); `grind_closeby.mqh`
(the EA's close-by queue, whole, unchanged); `cursor_plan4_f1f4.md` (the prompt Cursor
implemented; F2 is in its s3).

**The system:** an MQL5 passive limit-order FX market maker (hedging account, 0.01 lots, cap 8
layers a side). A filled entry is a layer; its exit is a limit order `exit` pips away; when the
exit fills, the EA closes the pair with CLOSE_BY (the broker reports two `OUT_BY` deals, one
per position). The exit queue (ADR-151) keeps only some exits resting; the rest are "held"
(no order) and promoted when a layer leaves.

**The harness:** it runs the EA's own engine over recorded ticks, with seams instead of
`OrderSend`. FREE mode: the replay's own fills. SYNC mode: it also reads the live account's
real deals (`real_*.csv`: `ENT`, `EXT`, `OUT_BY`, `ROLL` rows with times), keeps a TRUE BOOK
of the live layers, and after each batch of rows resets the engine's layers to it
(`Rpl_SyncResetToTrueBook`), so the replay's orders can be compared with live's one by one.
Timing: `timing 0` (instant) or `timing 1` (timed: send latencies place 287, modify 288,
close-by 294, remove 43 ms; a touched order fills after 261 ms through a pending deal event; a
`CB_DONE` event completes a close-by).

**F2 (sync only): a layer leaves the book at its real `OUT_BY`, never earlier.**
- A real `EXT` row marks the true-book layer closing (`exit_pos`); it no longer removes it.
- If the replay has NOT touched that layer's exit (no exit position, and in timed mode the
  exit order not executing), F2 removes the replay's exit order, clears `exit_order_ticket`,
  sets `exit_position_ticket` to the real exit position, and writes NO deal row.
- `Rpl_ProcessCloseByDone` defers a pair whose ENT is still in the true book.
- At a real `OUT_BY` row for an ENT in the true book, the pair (from the deferred list, a
  pending timed `CB_DONE`, or the EA's queue) completes at the row's time
  (`Rpl_SyncCompleteCloseByAt`) BEFORE the row removes the layer from the true book.

**Ruled -- do not re-open:** completing at the real `OUT_BY` time (not the replay's own);
no deal row for a real exit the replay did not make; F1-F4 are the only harness changes plan 4
allows; the latencies above. Whether the replay is "good enough" is the pre-registered
scorer's question, not yours.

**How it is judged:** plan 4 scores the SYNC runs by T1: >= 95% of live deals matched by a
replay deal of the same side, layer and role within 60 s, and replay-only deals <= 5%. A
wrong deal row, a missing one or a mistimed one moves T1.

## GIVENS -- verify each (VERIFIED or FALSE, with the quote)

- G1. A real `EXT` row marks the NEWEST true-book layer of that side and layer number that is
  not already closing; it removes nothing from the true book.
- G2. `Rpl_SyncResetToTrueBook` re-applies a closing layer's real exit position after a
  re-seed (so the mark survives a reset).
- G3. "Touched" in `Rpl_SyncApplyRealExtToSide` is: `exit_position_ticket != 0`, or (timed)
  the exit order executing in the broker book. Untouched: the order is removed from the EA's
  order seam and `exit_order_ticket` zeroed; no deal row is written.
- G4. With sync on and not completing, `Rpl_ProcessCloseByDone` defers (stores and skips) a
  pair whose `t1` is a true-book ticket.
- G5. At an `OUT_BY` row whose `position_id` is a true-book ticket, the pair is taken from the
  deferred list, else a pending timed `CB_DONE` event, else the EA's long or short close-by
  queue (removed from it), and completed before that row's true-book removal.
- G6. `Rpl_SyncCompleteCloseByAt` seeds the market at the row's time, completes with
  `g_rpl_sync_completing_out_by` set, registers the completion's own sends (timed:
  `Rpl_TmDiffStageSends`; timing 0: `Rpl_ScanNewOrders`, `Rpl_OrderLogDiff`), and drains the
  outputs at the row's time.

## THREATS -- verdict each: HOLDS / BREAKS / NEEDS-FIX

- **T-1 Order inside the sync step.** The completion runs inside `Rpl_ApplySyncDealsUpTo`,
  which in timing 0 runs BEFORE the tick's own market seed and in timed mode right after
  `Rpl_TmRunEventsUpTo`. It first calls `Rpl_TmProcessSyncRemovals(sync_tick_ms)` (timed) or
  `Rpl_OrderLogDiff(sync_tick_ms, "SYNC")` (timing 0). Can this lose, double or mislabel any
  order row (the reset's REMOVEs, the completion's PLACEs), cancel a pending deal event it
  should not, or leave a stale market seed that a later stage of the same tick reads?
- **T-2 "Touched".** Find a case where the replay HAS filled, or is filling, the exit but the
  test says untouched (timing 0: the exit filled on an earlier tick; timed: a re-seed between
  the touch and the deal event; the deal event already cancelled), or where it says touched
  but the replay made no exit (a stale `exit_position_ticket`, a re-used layer number). Give
  the case in ticks, times and prices.
- **T-3 The replay closes, live does not (yet).** The replay fills an exit and queues the
  close-by; live keeps the layer open for hours, or rolls it (a `ROLL` row moves its level).
  Under F2 the pair stays deferred and the engine layer stays "closing" (no exit order can be
  placed for it) until live's own `OUT_BY`. Before F2 the replay's `CB_DONE` removed the layer
  and the next reset re-seeded it fresh, so an exit was placed again. Which reproduces live
  better for T1, and what does each do to the replay's deal rows when live finally exits?
  Is any pair deferred FOREVER (live's `OUT_BY` outside the segment, or never), and does that
  leak into the next segment (`Rpl_ResetAll`)?
- **T-4 The deferral key.** `Rpl_ProcessCloseByDone` keys on `before[i].t1`. Is `t1` the ENT
  position at every `Grind_QueueCloseBy` call site in the attached engine and close-by code?
  Live's two `OUT_BY` rows carry the ENT and the EXT positions: is the EXT one correctly a
  no-op? A pair whose ENT is a replay-only layer: completes at once, as before?
- **T-5 Double or missing completion.** Timed: a `CB_DONE` event and the `OUT_BY` row due in
  the same tick (events run first): count the `OUT_BY` deal rows and `SCALP_CLOSED` events.
  Timing 0: the end-of-tick `Rpl_ProcessCloseByDone` with its `cb_before` snapshot after a
  completion in the sync step. Any path to two completions, or none?
- **T-6 The completion's sends and the EA's clock (timed).** The completion's sends start at
  `MathMax(out_by_ms, g_rpl_tm_free_ms)` and set `g_rpl_tm_free_ms`; no timing row is written.
  Can they overlap a handler already in progress, move the free time backwards, or put a
  promoted exit in the broker book before its send ends?
- **T-7 F1 in the completion.** The completion runs `Rpl_ProcessCloseByDone(out_by_ms, ...)`,
  whose sends F1 refuses (retcode 10018) outside the trade session. Can a real `OUT_BY` fall in
  a closed span (23:59-00:01, Friday 23:57 to Monday 00:01, server), and what then happens to a
  promoted exit (placed later by the engine, or never)?
- **T-8 Tests.** For RT69-RT74: which assertion passes vacuously or for the wrong reason (a
  fill, a recenter or another send producing the same rows; an `if` that skips assertions; a
  fixture left from an earlier test)? Which F2 behaviour has no test that fails without it?

## OUTPUT

Sections in this order: `GIVENS CHECK` (G1-G6), `T-1` ... `T-8` (verdict, evidence with
quotes, smallest fix if any, with a test: ticks, times in ms, prices to 5 decimals),
`PREMISE VERDICT` (is F2 safe to use for plan 4's sync runs as it stands), `TEST GAPS`. No
preamble. Do not call anything fatal that has a fix: give the smallest fix. If you assume a
value or an MT5 behaviour, say ASSUMED and why.

Line count: 121
