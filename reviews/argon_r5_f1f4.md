# Argon Round-5 Check of `prompts/cursor_plan4_f1f4.md` (`8b65360` -> `702ca00`)

## 1. Round-4 Points: Resolution Status (`8b65360` -> `702ca00`)

1. **R4-1 (`F2 c-d`, `RT71`: real `OUT_BY` before replay `CB_DONE`) — RESOLVED in prompt rule (see Section 2 for `efada62` execution details).**
   - `702ca00:prompts/cursor_plan4_f1f4.md:111`: `- **c, d. One rule for the close-by in sync: a pair completes when its ENT's real OUT_BY row is`
   - `702ca00:prompts/cursor_plan4_f1f4.md:112`: `  applied, at that row's time, BEFORE that row's reset**, whatever the state of the replay's own`
   - `702ca00:prompts/cursor_plan4_f1f4.md:117`: `  - at the OUT_BY row, a pair still queued or in flight is completed there and then, and its`
   - `702ca00:prompts/cursor_plan4_f1f4.md:118`: `    later CB_DONE does nothing;`
   - `702ca00:prompts/cursor_plan4_f1f4.md:152`: `- **RT71 (F2 c-d, OUT_BY first).** As RT69 but the real OUT_BY row before the replay's`
   - `702ca00:prompts/cursor_plan4_f1f4.md:153`: `  CB_DONE. Expected: the OUT_BY deal rows and one SCALP_CLOSED at the real OUT_BY time; the`
   - `702ca00:prompts/cursor_plan4_f1f4.md:154`: `  later CB_DONE writes nothing; depth 0 from that row.`
   - Completing at `OUT_BY` before `efada62:ea/fxgrind_replay_core.mqh:2593` (`Rpl_SyncResetToTrueBook();`) avoids the post-reset failure at `efada62:ea/fxgrind_replay_core.mqh:2301` (`if(!Rpl_FindPosMeta(before[i].t1, ent))`) and `efada62:ea/grind_engine.mqh:2891` (`if(side.layers[i].position_ticket != position_id)`).

2. **R4-2 (`F2 b`, `RT72`: in-flight `exec == true` exit fill at real `EXT`) — RESOLVED.**
   - `702ca00:prompts/cursor_plan4_f1f4.md:105`: `- **b.** If the engine's layer still has a resting exit order at that row that the replay has`
   - `702ca00:prompts/cursor_plan4_f1f4.md:106`: `  NOT touched (no deal in flight: not executing in the broker book, core 1123): remove that order`
   - `702ca00:prompts/cursor_plan4_f1f4.md:107`: `  from the replay's book and set the layer's exit_position_ticket to the row's position_id.`
   - `702ca00:prompts/cursor_plan4_f1f4.md:109`: `  it did not make. If the replay HAS touched it (its deal event pending, timed: touch + latency),`
   - `702ca00:prompts/cursor_plan4_f1f4.md:110`: `  change nothing: the replay's own fill completes as today.`
   - `702ca00:prompts/cursor_plan4_f1f4.md:155`: `- **RT72 (F2 b, a fill in flight).** Timed; the replay touches the exit at t; the real EXT row`
   - `702ca00:prompts/cursor_plan4_f1f4.md:156`: `  at t + 100 ms (before t + 261). Expected: one replay EXT deal at t + 261 (the replay's own); no`
   - Checking `efada62:ea/fxgrind_replay_core.mqh:702` (`bool Rpl_BkIsExec(const ulong ticket)`) / `efada62:ea/fxgrind_replay_core.mqh:1123` (`g_rpl_bk[i].exec = true;`) preserves touched fills; when removing an untouched order, `efada62:ea/grind_engine.mqh:3006` (`side.layers[layer_idx].exit_order_ticket = 0;`) must also be cleared alongside `Grind_OrderTestRemove`.

3. **R4-3 (`F2 a, c-d`: stored deferred pairs and re-seeded `exit_position_ticket`) — RESOLVED.**
   - `702ca00:prompts/cursor_plan4_f1f4.md:102`: `  (its exit position = the row's position_id, stored in the true book), using the same layer`
   - `702ca00:prompts/cursor_plan4_f1f4.md:103`: `  selection as today. A re-seed of a closing layer (Rpl_SyncResetToTrueBook, core 2520;`
   - `702ca00:prompts/cursor_plan4_f1f4.md:104`: `  Rpl_AppendLayerManual sets exit_position_ticket = 0, core 1753) carries that exit position.`
   - `702ca00:prompts/cursor_plan4_f1f4.md:115`: `    book does not complete it: the harness keeps that pair (the EA's queue entry is already gone,`
   - `702ca00:prompts/cursor_plan4_f1f4.md:116`: `    grind_closeby.mqh 251) and completes it at the OUT_BY row;`
   - Matches `efada62:ea/fxgrind_replay_core.mqh:2520` (`if(!present) {`), `efada62:ea/fxgrind_replay_core.mqh:1753` (`side.layers[n].exit_position_ticket = 0;`), and `efada62:ea/grind_closeby.mqh:251` (`ArrayRemove(queue, i, 1);`).

4. **R4-4 (`A-1`: `seq` direction in tests and window filter order in `build_real.py`) — RESOLVED.**
   - `702ca00:prompts/cursor_plan4_f1f4.md:47`: `The new time is applied BEFORE the [from_ms, to_ms) filter (build_real.py 69-70).`
   - `702ca00:prompts/cursor_plan4_f1f4.md:49`: `session_id (old test fixtures): unchanged. Tests (hand values): a roll logged AFTER both OUT_BY`
   - `702ca00:prompts/cursor_plan4_f1f4.md:50`: `rows (a HIGHER seq) but timed 485 ms before them moves to the OUT_BY time and sorts after them;`
   - `702ca00:prompts/cursor_plan4_f1f4.md:52`: `session's fills are ignored; a roll timed just before from_ms that moves inside the window is`
   - Matches `ebeaee7:research/replay/build_real.py:69` (`t = int(r["ea_time_ms"]) + SERVER_OFFSET_MS`) and `ebeaee7:research/replay/build_real.py:70` (`if not (from_ms <= t < to_ms):`).

## 2. New Issues in `F2 a-e` / `RT71` Against `efada62`

1. **`F2 c-d` (`702ca00:prompts/cursor_plan4_f1f4.md:119`: `- completing writes the OUT_BY deal rows at the row's time and runs Grind_ProcessDeal as today`): running `Grind_ProcessDeal` inside `Rpl_ApplySyncDealsUpTo` drops promoted exit orders from `g_rpl_bk` in timed mode and reads unseeded market quotes.**
   - On `DEAL_ENTRY_OUT_BY`, `Grind_ProcessDeal` calls `efada62:ea/grind_engine.mqh:2940` (`Grind_RemoveLayerAt(side, i);`) and `efada62:ea/grind_engine.mqh:2941` (`Grind_ExitQManageSide(side, is_long, magic, slot, lots, exit_pips);`), which clamps against the seeded quote at `efada62:ea/grind_engine.mqh:3494` (`const bool clamped = Grind_ExitQClampPassive(is_long, formula, price);`), places a promoted exit order whenever depth was `>= 3` at `efada62:ea/grind_engine.mqh:3500` (`const ulong ticket = Grind_PlaceLimit(otype, price, lots, magic, comment);`), and sets `efada62:ea/grind_engine.mqh:3503` (`side.layers[i].exit_order_ticket = ticket;`).
   - In `efada62:ea/fxgrind_replay_core.mqh`, `2660` (`Rpl_ApplySyncDealsUpTo(t);`) runs before `2665` (`Grind_MarketTestSeed(tick.bid, tick.ask, 0, 0);`) in timing 0, and `2762` (`Rpl_ApplySyncDealsUpTo(t);`) runs without `Rpl_TmSeedMarketAt` in timed mode, followed by `2763` (`Rpl_TmProcessSyncRemovals(t);`). `Rpl_TmProcessSyncRemovals` calls `efada62:ea/fxgrind_replay_core.mqh:1107` (`Rpl_OrderLogDiff(t, "SYNC");`), which updates `g_rpl_order_snap` (`efada62:ea/fxgrind_replay_core.mqh:1512`: `ArrayResize(g_rpl_order_snap, g_grind_order_test_count);`), while `efada62:ea/fxgrind_replay_core.mqh:1109` (`if(g_rpl_orders[i].action != "REMOVE")`) ignores `"PLACE"`. Thus the promoted exit order never reaches `efada62:ea/fxgrind_replay_core.mqh:469` (`void Rpl_BkPlace(const ulong ticket, const long type, const double price, const long live_ms)`) in timed mode (nor `efada62:ea/fxgrind_replay_core.mqh:2712` `Rpl_ScanNewOrders(t);` before `efada62:ea/fxgrind_replay_core.mqh:2676` `Rpl_FillsOnTick(t, tick.bid, tick.ask);` in timing 0) and can never fill.

2. **`F2 c-d` + `RT71` (`702ca00:prompts/cursor_plan4_f1f4.md:153`): `SCALP_CLOSED` gets the tick/handler timestamp instead of the `OUT_BY` row's timestamp unless `Rpl_DrainOutputs` is called at `rd.time_ms`.**
   - `Grind_ProcessDeal` only enqueues `SCALP_CLOSED` at `efada62:ea/grind_engine.mqh:2909` (`Grind_QueueScalpClosedEvent(g_grind_telemetry_instance,`), while `efada62:ea/fxgrind_replay_core.mqh:2291` (`void Rpl_ProcessCloseByDone(const long tick_ms, const RplCbTask &before[], const int before_n)`) does not call `efada62:ea/fxgrind_replay_core.mqh:2239` (`void Rpl_DrainOutputs(const long tick_ms)`), which stamps `SCALP_CLOSED` with its argument at `efada62:ea/fxgrind_replay_core.mqh:2256` (`Rpl_WriteEventOutput(tick_ms, "scalp", "SCALP_CLOSED", g_rpl_last_scalp_json);`). Because `Rpl_DrainOutputs` is otherwise called only at `efada62:ea/fxgrind_replay_core.mqh:1023` / `efada62:ea/fxgrind_replay_core.mqh:1078` (`Rpl_DrainOutputs(start);`) or `efada62:ea/fxgrind_replay_core.mqh:2730` / `efada62:ea/fxgrind_replay_core.mqh:2775` (`Rpl_DrainOutputs(t);`), completing at `rd.time_ms` must call `Rpl_DrainOutputs(rd.time_ms)`.

3. **`F2 c-d` (`702ca00:prompts/cursor_plan4_f1f4.md:117`): `Rpl_ProcessCloseByDone` skips a "still queued" pair unless popped from the EA close-by queue first.**
   - `efada62:ea/fxgrind_replay_core.mqh:2297` (`if(Rpl_QueueHasTask(after, after_n, before[i].t1, before[i].t2))`) and `efada62:ea/fxgrind_replay_core.mqh:2298` (`continue;`) skip any pair still in `g_grind_long_closeby_queue` / `g_grind_short_closeby_queue`, and `Rpl_ProcessCloseByDone` does not call `efada62:ea/fxgrind_replay_core.mqh:2425` (`void Rpl_RemoveCloseByQueueTicket(const ulong ticket)`), while `efada62:ea/grind_engine.mqh:2940` (`Grind_RemoveLayerAt(side, i);`) removes the layer before `efada62:ea/fxgrind_replay_core.mqh:2493` (`Rpl_RemoveLayerByTicket(g_grind_long, g_grind_long.layers[i].position_ticket);`) or `efada62:ea/fxgrind_replay_core.mqh:2505` (`Rpl_RemoveLayerByTicket(g_grind_short, g_grind_short.layers[i].position_ticket);`) can purge it. Completing a queued pair at `OUT_BY` must call `Rpl_RemoveCloseByQueueTicket` first (and only complete pairs from the queue, pending `RPL_TM_EV_CLOSEBY_DONE`, or deferred-pairs list, not case `b`).

4. **`F2 a, b, e` (`702ca00:prompts/cursor_plan4_f1f4.md:123`: `- **e.** No exit order is re-placed for a closing layer between its EXT and OUT_BY rows.`): a `present` engine layer with `exit_order_ticket == 0` and `exit_position_ticket == 0` at a real `EXT` row.**
   - If the engine layer is already `present` (`efada62:ea/fxgrind_replay_core.mqh:2516`: `present = true;`) but has `exit_order_ticket == 0` and `exit_position_ticket == 0` (e.g. a middle layer where `efada62:ea/grind_engine.mqh:3480` `if(!Grind_ExitQRequired(ranks[i], n))` is true, or an `ENT` re-seeded while `g_rpl_tm_free_ms > t` or with F1/F4 blocking `ENGINE`), neither `efada62:ea/fxgrind_replay_core.mqh:2520` (`if(!present) {`) nor `F2 b`'s "still has a resting exit order" branch sets `exit_position_ticket`, so `efada62:ea/grind_engine.mqh:3482` (`if(side.layers[i].exit_order_ticket != 0 || side.layers[i].exit_position_ticket != 0)`) would place an exit order, violating `F2 e`.
