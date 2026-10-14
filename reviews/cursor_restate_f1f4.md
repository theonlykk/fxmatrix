# Plan 4 (F1--F4, A-1--A-4) --- Section 0 Restate (`3738152`)

Prompt: `prompts/cursor_plan4_f1f4.md` at `3738152`  
Reference: `docs/research/replay-consult-plan4.md` (s1--s12)

---

## 1. One-Line Restatement of Each Change (Sections 2 & 3, Quoting the Prompt)

### Section 2 --- Part A: Python (`research/replay/`)

- **A-1 (`build_real.py`: the ROLL clock, A11):** `"A ROLL row's time becomes max(ea_time_ms + SERVER_OFFSET_MS, T), where T is the largest deal_time_broker_msc of the fill_logs rows of the SAME session_id whose seq is LOWER than the roll's seq (no such row: unchanged). The new time is applied BEFORE the [from_ms, to_ms) filter (build_real.py 69-70)."` (ties keep `"a roll after the fills of its ms"`; rows without `seq` or `session_id` are unchanged).
- **A-2 (`build_segments.py` / `build_inputs.py`: optional `sessions_file` column):** `"When a sessions file name is given, the run header gains ,sessions_file after orders_file and every row carries the name; when not given, the output is byte-identical to today's (test it)."`
- **A-3 (`build_holdout.py`: the plan 4 window, A12):** `"New optional arguments, all defaulting to plan 3's values so that a build without them is byte-identical to today's (test it on a synthetic archive): --window-end-ms (default 1791939600000), --first-ids (default 31,41,51), --sessions FILE (copied into --out and named in the run files, A-2), and --sends-extra-b / -c / -d (each optional, one file). Sends are joined: every send_logs row of both files, deduplicated by id (two rows with one id and different content: an error), sorted by (ea_time_ms, seq, id) as the exporter writes them; _meta lines dropped from the join."`
- **A-4 (`research/replay/inputs/sessions_eurusd_ic.csv`):** `"A file research/replay/inputs/sessions_eurusd_ic.csv: header day_of_week,trade_from,trade_to (0 = Sunday, as MQL5 day_of_week; times HH:MM server), rows 1,00:01,23:59, 2,00:01,23:59, 3,00:01,23:59, 4,00:01,23:59, 5,00:01,23:57. ASCII, LF."`

### Section 3 --- Part B: MQL5 (`ea/fxgrind_replay_core.mqh`, `ea/fxgrind_replay_tests.mq5`)

- **F3 (`ea/fxgrind_replay_core.mqh`, A8):** `"Remove the two lines in Rpl_SyncResetToTrueBook (core 2534-2535). Keep them at segment start (2803-2804)."`
- **F4 (`ea/fxgrind_replay_core.mqh`, A6, A7):** `"The harness applies the stale-feed rule itself, in both paths: before calling Grind_OnTickEngine (timed STAGE:ENGINE, core 924; timing 0, core 2703), compare the time of the tick the EA will see (timed: the newest tick at the stage's start, Rpl_TmMarketMsAt; timing 0: the tick) with the tick time of the previous engine ATTEMPT in this segment: if the difference is more than 5000 ms (strict), skip the call for this tick. Record the tick time as the last attempt either way. The first attempt of a segment is never stale."`
- **F1 (`ea/fxgrind_replay_core.mqh`, A1--A5):** Load the optional trade-session table from `sessions_file` (printing `"RPL|SESSIONS|<file>|<rows>"` or `"RPL|SESSIONS|none"` once per run, aborting on a missing/malformed file, and clearing the table in `Rpl_ResetAll`); when a time is `CLOSED` (outside `"trade_from <= time-of-day < trade_to"`), `"Broker: no order is touched or filled (timed Rpl_TmBrokerStep; timing 0 Rpl_FillsOnTick)"` and `"Sends: every EA stage or handler whose start is CLOSED ... runs with both send seams refusing: send_ok = false, retcode = 10018 (TRADE_RETCODE_MARKET_CLOSED); restored after the stage."`
- **F2 (`ea/fxgrind_replay_core.mqh`, sync only, A9, A10):** `"A layer leaves the book at its real close-by, never earlier"` ---
  - **F2 a:** `"A real EXT row no longer removes the layer from the true book; it marks it closing (its exit position = the row's position_id, stored in the true book), using the same layer selection as today. A re-seed of a closing layer (Rpl_SyncResetToTrueBook, core 2520; Rpl_AppendLayerManual sets exit_position_ticket = 0, core 1753) carries that exit position."`
  - **F2 b:** `"If the replay has NOT touched the layer's exit at that row (an exit order not executing in the broker book, core 1123 / Rpl_BkIsExec 702, OR no exit order at all, e.g. a held exit under the exit queue, engine 3480): remove any such order from the replay's book, clear the layer's exit_order_ticket, and set its exit_position_ticket to the row's position_id. Write no deal row (as sync ENT rows write none): the replay must not be credited with a deal it did not make. If the replay HAS touched it (its deal event pending, timed: touch + latency), change nothing: the replay's own fill completes as today."`
  - **F2 c, d:** `"One rule for the close-by in sync: a pair completes when its ENT's real OUT_BY row is applied, at that row's time, BEFORE that row's reset, whatever the state of the replay's own close-by: queued, sent and awaiting CB_DONE, or already reached CB_DONE."` It runs as a `CB_DONE` at the `OUT_BY` row's time (market seeded at that time, any promoted exit registered in `Rpl_BkPlace` / order scan, outputs drained with `Rpl_DrainOutputs` at that time, queued pairs removed via `Rpl_RemoveCloseByQueueTicket` first, only pairs from the queue / pending `CB_DONE` / deferred list completed, and true-book removal held until completion has run).
  - **F2 e:** `"No exit order is re-placed for a closing layer between its EXT and OUT_BY rows."`

---

## 2. Tests to Be Added and Hand-Derived Expected Values

### 2.1 Part A: Python Tests (`research/replay/test_*.py`)

1. **`test_build_real.py::test_roll_clock_after_out_by_moves_to_out_by_time`:** A `ROLL` row in `session_id="s1"` with `seq=15` and `ea_time_ms + OFF = T + 4815` (`5300 - 485 = 4815`, i.e. 485 ms before two `OUT_BY` fills at `T + 5300` with `seq=13, 14` in `session_id="s1"`) moves to `max(T + 4815, T + 5300) = T + 5300` and sorts after both `OUT_BY` rows at `T + 5300`.
2. **`test_build_real.py::test_roll_before_fill_keeps_its_time`:** A `ROLL` row in `session_id="s1"` with `seq=5` at `T + 3000` before a fill in `session_id="s1"` with `seq=6` at `T + 5000` has no lower-`seq` fill and keeps `T + 3000`.
3. **`test_build_real.py::test_roll_ignores_other_session_fills`:** A `ROLL` row in `session_id="s1"` with `seq=10` at `T + 3000` ignores a fill in `session_id="s2"` with `seq=5` at `T + 8000` and keeps `T + 3000`.
4. **`test_build_real.py::test_roll_before_from_ms_moved_into_window_is_kept`:** A `ROLL` row in `session_id="s1"` with `seq=10` timed at `T - 200` (before `from_ms = T`) after a fill in `session_id="s1"` with `seq=9` at `T + 100` moves to `max(T - 200, T + 100) = T + 100` before the `[T, T + 1000)` filter and is retained at `T + 100`.
5. **`test_build_segments.py::test_run_csv_sessions_file_optional`:** Calling `to_run_csv` without `sessions_file` is byte-identical to today's 23-column output; calling `to_run_csv(..., sessions_file="sessions_eurusd_ic.csv")` appends `,sessions_file` to the header (24 columns) and `,sessions_eurusd_ic.csv` to every row.
6. **`test_build_inputs.py::test_fleet_files_sessions_file_optional`:** `fleet_files` without `sessions_file` is byte-identical to today; with `sessions_file="sessions_eurusd_ic.csv"`, `run_<tag>.csv` has the 24-column header ending in `,orders_file,sessions_file` and every row ends in `,sessions_eurusd_ic.csv`.
7. **`test_build_holdout.py::test_join_sends_dedup_sort_and_drop_meta`:** Joining two `send_logs` lists drops `_meta` rows, deduplicates identical rows with the same `id`, and sorts by `(ea_time_ms, seq, id)`.
8. **`test_build_holdout.py::test_join_sends_conflicting_duplicate_raises`:** Two `send_logs` rows with the same `id` and different content raise `ValueError`.
9. **`test_build_holdout.py::test_build_defaults_byte_identical_and_plan4_flags`:** Running `cmd_build` on a synthetic 3-fleet archive without the new flags produces output byte-identical to today's (`window_end_ms=1791939600000`, `first_ids=[31, 41, 51]`, 23-column `run_*.csv`); running with `--window-end-ms`, `--first-ids`, `--sessions`, and `--sends-extra-b/-c/-d` applies the overridden window end and segment IDs, copies the sessions file into `--out`, writes `,sessions_eurusd_ic.csv` in `run_*.csv`, and joins the extra sends.
10. **`test_build_holdout.py::test_sessions_eurusd_ic_csv_file`:** Verifies `research/replay/inputs/sessions_eurusd_ic.csv` is ASCII, LF-only, header `day_of_week,trade_from,trade_to`, with rows `1,00:01,23:59`, `2,00:01,23:59`, `3,00:01,23:59`, `4,00:01,23:59`, `5,00:01,23:57`.

---

### 2.2 Part B: MQL5 Tests (`RT64`--`RT74` in `ea/fxgrind_replay_tests.mq5`)

Constants used across `RT64`--`RT74`:
- `RPL_T0 = D'2026.10.06 10:00:00'` = `1791280800` s = `1791280800000` ms (Tuesday, `day_of_week = 2`).
- `_Point = 0.00001`, `1 pip = 0.00010`, `stops_level = 0` in `Grind_MarketTestSeed(..., 0, 0)` so ADR-013 step is `max(0, 1) * _Point = 0.00001` (`0.1` pip).
- Default `Rpl_DefaultConfig(cfg)`: `width_l = 2.0`, `width_s = 15.0`, `add_l = 7.0`, `add_s = 7.0`, `exit_l = 10.0`, `exit_s = 10.0`, `cap = 8`, `stranded = 50.0`, `deadband = 2.0`, `lattice = true`.
- Timed `"base"` profile (`Rpl_TmApplySens("base")`, `ea/fxgrind_replay_core.mqh:346-352`): `d_place = 287` ms, `d_modify = 288` ms, `d_closeby = 294` ms, `d_remove = 43` ms, `lam = 261` ms, `thru_pts = 0`, `limit_price = false`.
- Order-row timestamping in `ea/fxgrind_replay_core.mqh`:
  - `Rpl_OrderLogAppendRowAt` stamps `g_rpl_orders[n].time_ms = t` at **line 747** of `ea/fxgrind_replay_core.mqh`.
  - In timed mode (`timing = 1`), `Rpl_TmDiffStageSends` computes `const long send_start = cursor; cursor += dur;` (**lines 877--878**) and calls `Rpl_TmApplySendRow(stage, send_start, cursor, ...)` (**line 880**), which calls `Rpl_OrderLogAppendRowAt(send_start, ...)` at **line 770** --- so `g_rpl_orders[n].time_ms` is `send_start` (not `send_end`), while `Rpl_BkPlace(ticket, otype, price, send_end)` (**line 772**) and `Rpl_BkModify(ticket, price, send_end)` (**line 780**) set the broker book's `live_ms` / `from_ms` to `send_end = cursor`, and `Rpl_TmWriteTimingRow` (**lines 936, 1077**) writes `end_ms = cursor`.
  - In timing `0`, `Rpl_OrderLogDiff` calls `Rpl_OrderLogAppendRowAt(t, ...)` at **lines 2266, 2270, 2283** with the tick/sync timestamp `t`.

---

#### `RT64` --- `Test_RT64_SyncResetNoStartupAddReprice` (F3)
- **One-line summary:** After `Rpl_SyncResetToTrueBook()` runs on a sync row, a resting add order at `X = 1.09860` when `bid = X` (`max_buy = X - 0.00001`, 0.1 pip away `< deadband = 2.0` pips) is NOT modified.
- **Setup & Arithmetic:**
  - `cfg.sync = true`, timing `0`, `from_ms = 1791280800000`, `to_ms = 1791280803000`, `add_l = 7.0` pips (`0.00070`), `deadband = 2.0` pips (`0.00020`).
  - Seed long L0 (`ticket = 6401`, `entry = 1.10000`, `open_ms = T0 - 3600000`) and long L1 (`ticket = 6402`, `entry = 1.09930`, `open_ms = T0 - 1800000`).
  - Sync row at `t0 + 500 = 1791280800500`: `1791280800500,ROLL,L,0,,6401,1.09800` (triggers `Rpl_SyncResetToTrueBook()` before Tick 1 without changing L1's add target).
  - **Tick 0** at `t0 = 1791280800000`: `bid = 1.09900, ask = 1.09902`.
    - L2 add formula target: `X = 1.09930 - 0.00070 = 1.09860`.
    - ADR-013 buy clamp: `max_buy = bid - 0.00001 = 1.09899 >= 1.09860`, so unclamped target is `1.09860`.
    - Engine places `L` L2 `ENT` (`BUY_LIMIT`) at `1.09860` and consumes the segment-start `g_grind_start_add_reprice_long`.
  - **Tick 1** at `t1 = 1791280801000`: `bid = 1.09860, ask = 1.09862`.
    - `Rpl_ApplySyncDealsUpTo(t1)` applies the `ROLL` row and calls `Rpl_SyncResetToTrueBook()`.
    - In `Grind_EnsureAddNext` on Tick 1: formula target `X = 1.09860`; ADR-013 buy clamp with `bid = 1.09860` yields `clamped = 1.09860 - 0.00001 = 1.09859`.
    - Price difference from resting order: `|1.09859 - 1.09860| = 0.00001` (`0.1` pip).
    - With F3, `g_grind_start_add_reprice_long` is `false`, so threshold is `deadband = 2.0` pips (`0.00020`); since `0.00001 < 0.00020`, no `MODIFY` is sent.
- **Hand-derived expected values asserted:**
  - `MODIFY` count for `(side="L", layer=2, role="ENT")` in `g_rpl_orders` == `0`;
  - Resting order price for `L` L2 `ENT` == `1.09860` (`+- 1e-6`).
- **Expected at `B-0` (`efada62`):** **FAILS** --- `Rpl_SyncResetToTrueBook` sets `g_grind_start_add_reprice_long = true` (core 2534), using the `0.05`-pip (`0.000005`) threshold so `0.00001 >= 0.000005` modifies `L` L2 `ENT` to `1.09859` (`MODIFY` count = `1`, price = `1.09859`).

---

#### `RT65` --- `Test_RT65_StaleFeedEngineSkip` (F4)
- **One-line summary:** In both timing `0` and timed `"base"` (`d_place = 287`, `d_modify = 288`), `Grind_OnTickEngine` is skipped on a tick whose gap from the previous engine attempt is `6000 ms > 5000 ms`, runs on the tick `1000 ms` later, and runs on a tick whose gap is `5000 ms` (strict `>`), stepping `bid` UP (`1.11800, 1.11830, 1.11860, 1.11890, 1.11920; ask = bid + 0.00002`) so the resting `BUY_LIMIT` add order is never touched.
- **Setup & Arithmetic:**
  - Run sub-case A (timing `0`) and sub-case B (timed `"base"`: `d_place = 287`, `d_modify = 288`, `d_closeby = 294`, `d_remove = 43`, `lam = 261` from `Rpl_TmApplySens("base")`, `ea/fxgrind_replay_core.mqh:346-352`).
  - `from_ms = T0 = 1791280800000`, `to_ms = T0 + 15000 = 1791280815000`, `width_l = 2.0` pips (`0.00020`), `width_s = 15.0` pips (`0.00150`), `add_l = 7.0` pips (`0.00070`), `exit_l = 10.0` pips (`0.00100`), `deadband = 2.0` pips (`0.00020`), `stranded = 1000.0` pips.
  - Seed long L0 position (`ticket = 6501`, `entry = 1.12000`, `open_ms = T0 - 3600000`), so L1 formula target is `1.12000 - 0.00070 = 1.11930`.
  - Keep the short side and L0 exit quiet: with `width_s = 15.0` (`0.00150`) and `stranded = 1000.0`, `S` L0 `ENT` (`SELL_LIMIT` at `mid(t0) + 0.00150 = 1.11801 + 0.00150 = 1.11951`) is above the highest `bid` (`1.11920`) so it is never touched, and its distance from `mid` (`<= 15.0` pips `< stranded = 1000.0` pips) never triggers `Grind_TryRecenterOppositeL0`.
    - Note on `t0` sends: if `L` L0 `EXT` (`SELL_LIMIT` at `1.12100`, `ticket = 6511`) and `S` L0 `ENT` (`SELL_LIMIT` at `1.11951`, `ticket = 6512`) are seeded at segment start, `Grind_RetryMissingExits` and `Grind_TryPlaceL0` send nothing on `t0` (avoiding `g_grind_ent_sent_this_tick = true` at `ea/grind_engine.mqh:2099` blocking `Grind_EnsureAddNext` at `ea/grind_engine.mqh:2579`), so `L` L1 `ENT` is the sole send on every non-stale tick (`t0, t1, t3, t4`). (If instead `L` L0 `EXT` and `S` L0 `ENT` are not seeded, `t0` places `L` L0 `EXT` at `1.12100` (`send_start = 1791280800000, send_end = 1791280800287`) and `S` L0 `ENT` at `1.11951` (`send_start = 1791280800287, send_end = 1791280800574`), `t1` places `L` L1 `ENT` at `1.11829` (`send_start = 1791280801000, send_end = 1791280801287`), `t2` is skipped, `t3` modifies `L` L1 `ENT` to `1.11889` (`send_start = 1791280808000, send_end = 1791280808288`), and `t4` modifies `L` L1 `ENT` to `1.11919` (`send_start = 1791280813000, send_end = 1791280813288`); in `RT65` we seed `6511` and `6512` so `L` L1 `ENT` is placed on `t0` and modified on `t1, t3, t4`.)
  - Five ticks stepping `bid` **UP** by `3.0` pips (`0.00030 > deadband 0.00020`) per tick with `ask = bid + 0.00002` (so each tick's `ask` is strictly above the resting `BUY_LIMIT` from the prior tick and the resting add is never touched):
    1. `t0 = T0 + 0 = 1791280800000` (1st attempt of segment, never stale): `bid = 1.11800, ask = 1.11802` (`mid = 1.11801`).
       - ADR-013 buy clamp on `1.11930`: `clamped = bid - 0.00001 = 1.11799` -> `PLACE` `L` L1 `ENT` (`BUY_LIMIT`) at `1.11799`.
       - Last engine attempt recorded as `1791280800000` (`T0 + 0`).
       - Timed `"base"`: `stage_start = 1791280800000`, `send_start = 1791280800000`, `send_end = 1791280800000 + d_place(287) = 1791280800287`.
         - Order row `g_rpl_orders[0].time_ms = send_start = 1791280800000` (stamped at `ea/fxgrind_replay_core.mqh:747` inside `Rpl_OrderLogAppendRowAt`, called from `Rpl_TmApplySendRow` at `line 770` with `send_start` from `Rpl_TmDiffStageSends` at `line 877`);
         - Broker book `live_ms = send_end = 1791280800287` (`Rpl_BkPlace`, `line 772`);
         - `STAGE:ENGINE` / `ONTICK` `end_ms = g_rpl_tm_free_ms = 1791280800287` (`lines 936, 1076--1077`).
    2. `t1 = T0 + 1000 = 1791280801000` (gap `1000 - 0 = 1000 ms <= 5000`, not stale): `bid = 1.11830, ask = 1.11832` (`mid = 1.11831`).
       - Broker check: `ask = 1.11832 > 1.11799` (resting `BUY_LIMIT` at `1.11799` is not touched).
       - ADR-013 buy clamp: `clamped = 1.11830 - 0.00001 = 1.11829` (`|1.11829 - 1.11799| = 0.00030 >= 0.00020`) -> `MODIFY` `L` L1 `ENT` from `1.11799` to `1.11829`.
       - Last engine attempt recorded as `1791280801000` (`T0 + 1000`).
       - Timed `"base"`: `start = MathMax(1791280801000, 1791280800287) = 1791280801000`, `send_start = 1791280801000`, `send_end = 1791280801000 + d_modify(288) = 1791280801288`.
         - Order row `g_rpl_orders[1].time_ms = send_start = 1791280801000` (`line 747` via `line 770` / `line 877`);
         - Broker modification `from_ms = send_end = 1791280801288` (`Rpl_BkModify`, `line 780`);
         - `STAGE:ENGINE` / `ONTICK` `end_ms = g_rpl_tm_free_ms = 1791280801288` (`lines 936, 1076--1077`).
    3. `t2 = T0 + 7000 = 1791280807000` (gap `7000 - 1000 = 6000 ms > 5000`, **STALE**): `bid = 1.11860, ask = 1.11862` (`mid = 1.11861`).
       - Broker check: `ask = 1.11862 > 1.11829` (not touched).
       - `Grind_OnTickEngine` **skipped** by F4 (`6000 > 5000`); `0` sends on `t2`; order stays at `1.11829`.
       - Last engine attempt recorded as `1791280807000` (`T0 + 7000`).
       - Timed `"base"`: `start = MathMax(1791280807000, 1791280801288) = 1791280807000`, `sends = 0`, `end_ms = g_rpl_tm_free_ms = 1791280807000`.
    4. `t3 = T0 + 8000 = 1791280808000` (gap from `t2`: `8000 - 7000 = 1000 ms <= 5000`, not stale): `bid = 1.11890, ask = 1.11892` (`mid = 1.11891`).
       - Broker check: `ask = 1.11892 > 1.11829` (not touched).
       - ADR-013 buy clamp: `clamped = 1.11890 - 0.00001 = 1.11889` (`|1.11889 - 1.11829| = 0.00060 >= 0.00020`) -> `MODIFY` `L` L1 `ENT` from `1.11829` to `1.11889`.
       - Last engine attempt recorded as `1791280808000` (`T0 + 8000`).
       - Timed `"base"`: `start = MathMax(1791280808000, 1791280807000) = 1791280808000`, `send_start = 1791280808000`, `send_end = 1791280808000 + d_modify(288) = 1791280808288`.
         - Order row `g_rpl_orders[2].time_ms = send_start = 1791280808000` (`line 747` via `line 770` / `line 877`);
         - Broker modification `from_ms = send_end = 1791280808288` (`Rpl_BkModify`, `line 780`);
         - `STAGE:ENGINE` / `ONTICK` `end_ms = g_rpl_tm_free_ms = 1791280808288`.
    5. `t4 = T0 + 13000 = 1791280813000` (gap from `t3`: `13000 - 8000 = 5000 ms <= 5000`, boundary is NOT stale): `bid = 1.11920, ask = 1.11922` (`mid = 1.11921`).
       - Broker check: `ask = 1.11922 > 1.11889` (not touched); `bid = 1.11920 < 1.11951` (short L0 `ENT` not touched).
       - ADR-013 buy clamp: `clamped = 1.11920 - 0.00001 = 1.11919` (`|1.11919 - 1.11889| = 0.00030 >= 0.00020`) -> `MODIFY` `L` L1 `ENT` from `1.11889` to `1.11919`.
       - Last engine attempt recorded as `1791280813000` (`T0 + 13000`).
       - Timed `"base"`: `start = MathMax(1791280813000, 1791280808288) = 1791280813000`, `send_start = 1791280813000`, `send_end = 1791280813000 + d_modify(288) = 1791280813288`.
         - Order row `g_rpl_orders[3].time_ms = send_start = 1791280813000` (`line 747` via `line 770` / `line 877`);
         - Broker modification `from_ms = send_end = 1791280813288` (`Rpl_BkModify`, `line 780`);
         - `STAGE:ENGINE` / `ONTICK` `end_ms = g_rpl_tm_free_ms = 1791280813288`.
- **Hand-derived expected values asserted (both timing 0 and timed `"base"`):**
  - Total `L` L1 `ENT` rows in `g_rpl_orders` == `4` (`1` `PLACE` at `1.11799`, `3` `MODIFY` at `1.11829`, `1.11889`, `1.11919`), and `Rpl_DealsCount() == 0` (resting add never touched);
  - Order-log row timestamps `g_rpl_orders[i].time_ms` (stamped at `ea/fxgrind_replay_core.mqh:747` in `Rpl_OrderLogAppendRowAt`, called with `t` at `lines 2266/2270` in timing `0` and with `send_start` at `line 770` / `line 877` in timed mode):
    - Timing `0`: `1791280800000`, `1791280801000`, `1791280808000`, `1791280813000`;
    - Timed `"base"`: `send_start = 1791280800000`, `1791280801000`, `1791280808000`, `1791280813000` (with corresponding `send_end` / broker `live_ms`/`from_ms` / `STAGE:ENGINE` `end_ms` = `1791280800287` (`+287`), `1791280801288` (`+288`), `1791280808288` (`+288`), `1791280813288` (`+288`));
  - Count of sends from `t2 = 1791280807000` (`[T0 + 7000, T0 + 7999]`) == `0`.
- **Expected at `B-0` (`efada62`):** **FAILS** --- `efada62` sets `g_grind_last_feed_tick_msc = live.time_msc` before `Grind_OnTickEngine`, so `t2` is never skipped and sends a 5th order row (`MODIFY` to `1.11859` with `g_rpl_orders` `time_ms = send_start = 1791280807000`, `send_end = 1791280807000 + d_modify(288) = 1791280807288`).

---

#### `RT66` --- `Test_RT66_SessionBroker12OctOpen` (F1 broker)
- **One-line summary:** On the 12 Oct Monday open, a resting `BUY_LIMIT` at `1.11909` does not touch or fill at `00:00:00.188` when the A-4 session table is active, and fills from the first OPEN tick at `00:01:00.170` (`00:01:00.431` at `1.11903` in timed `"base"`, `00:01:00.170` at `1.11909` in timing `0`), whereas without a session table it fills at `00:00:00.188`.
- **Setup & Arithmetic:**
  - `from_ms = RplMs(D'2026.10.09 23:56:59', 0) = 1791590219000`, `to_ms = RplMs(D'2026.10.12 00:03:00', 0) = 1791763380000`.
  - Seed resting `BUY_LIMIT` (`L`, layer `0`, `ENT`, `ticket = 6611`) at `1.11909`.
  - Ticks:
    1. Fri `2026.10.09 23:56:59.456` = `1791590219000 + 456 = 1791590219456` (`day_of_week = 5`, `23:56:59 < 23:57`, **OPEN**): `bid = 1.12007, ask = 1.12019` (`ask 1.12019 > 1.11909`: no touch).
    2. Mon `2026.10.12 00:00:00.188` = `1791763200000 + 188 = 1791763200188` (`day_of_week = 1`, `00:00:00 < 00:01`, **CLOSED**): `bid = 1.11847, ask = 1.11903` (`ask 1.11903 <= 1.11909`, gated when table active).
    3. Mon `2026.10.12 00:01:00.170` = `1791763260000 + 170 = 1791763260170` (`day_of_week = 1`, `00:01:00 >= 00:01`, **OPEN**): `bid = 1.11847, ask = 1.11903` (`ask <= 1.11909`: touched).
    4. Mon `2026.10.12 00:01:00.372` = `1791763260000 + 372 = 1791763260372` (**OPEN**): `bid = 1.11847, ask = 1.11903`.
    5. Mon `2026.10.12 00:02:00.174` = `1791763320000 + 174 = 1791763320174` (**OPEN**): `bid = 1.11847, ask = 1.11903`.
- **Hand-derived expected values asserted:**
  - **Sub-case A (with A-4 session table, timed `"base"`, `lam = 261` ms):**
    - `L` L0 `ENT` `DEAL_ENTRY_IN` count == `1`;
    - Deal `time_ms == 1791763260170 + 261 = 1791763260431` (`2026.10.12 00:01:00.431`);
    - Deal `price == 1.11903` (tick quote `ask` at `00:01:00.170`).
  - **Sub-case B (with A-4 session table, timing `0`):**
    - `L` L0 `ENT` `DEAL_ENTRY_IN` count == `1`;
    - Deal `time_ms == 1791763260170` (`2026.10.12 00:01:00.170`);
    - Deal `price == 1.11909` (limit price).
  - **Sub-case C (without session table, timed `"base"` and timing `0`):**
    - Timed `"base"`: deal `time_ms == 1791763200188 + 261 = 1791763200449` (`00:00:00.449`), `price == 1.11903`;
    - Timing `0`: deal `time_ms == 1791763200188` (`00:00:00.188`), `price == 1.11909`.
- **Expected at `B-0` (`efada62`):** **FAILS** --- Sub-cases A and B fill at `00:00:00.449` (`1791763200449`) and `00:00:00.188` (`1791763200188`) because no session gating exists at `efada62`.

---

#### `RT67` --- `Test_RT67_SessionSendsAndBoundaries` (F1 sends & boundaries)
- **One-line summary:** With the A-4 session table, EA sends at `23:59:00.000`, `23:59:30`, `00:00:30`, and `Fri 23:57:30` are refused with `retcode = 10018` (`0` orders placed), while sends at `23:58:59` and `00:01:00.000` succeed (`L` L0 `ENT` placed at `1.09981`).
- **Setup & Arithmetic:**
  - Flat book, `width_l = 2.0` pips (`0.00020`), `width_s = 15.0` pips (`0.00150`), `bid = 1.10000, ask = 1.10002` (`mid = 1.10001`, so an allowed tick places `L` L0 `ENT` at `1.10001 - 0.00020 = 1.09981` and `S` L0 `ENT` at `1.10001 + 0.00150 = 1.10151`).
  - With the A-4 session table (`Mon-Thu 00:01-23:59`, `Fri 00:01-23:57`), run a single-tick check at each of the 6 timestamps:
    1. Tue `D'2026.10.06 23:58:59'` = `1791331139000` (`day_of_week = 2`, `23:58 < 23:59`, **OPEN**): send **succeeds** (`Rpl_OrderSeamCount() == 2`, `L` L0 `ENT` at `1.09981`).
    2. Tue `D'2026.10.06 23:59:00'` = `1791331140000` (`day_of_week = 2`, `23:59 == trade_to`, **CLOSED** under `trade_from <= t < trade_to`): send **refused** (`retcode = 10018`, `Rpl_OrderSeamCount() == 0`).
    3. Tue `D'2026.10.06 23:59:30'` = `1791331170000` (`day_of_week = 2`, `23:59 >= 23:59`, **CLOSED**): send **refused** (`Rpl_OrderSeamCount() == 0`).
    4. Wed `D'2026.10.07 00:00:30'` = `1791331230000` (`day_of_week = 3`, `00:00 < 00:01`, **CLOSED**): send **refused** (`Rpl_OrderSeamCount() == 0`).
    5. Wed `D'2026.10.07 00:01:00'` = `1791331260000` (`day_of_week = 3`, `00:01 == trade_from`, **OPEN**): send **succeeds** (`Rpl_OrderSeamCount() == 2`, `L` L0 `ENT` at `1.09981`).
    6. Fri `D'2026.10.09 23:57:30'` = `1791590250000` (`day_of_week = 5`, `23:57 >= 23:57`, **CLOSED**): send **refused** (`Rpl_OrderSeamCount() == 0`).
  - Also verify `g_grind_order_test_send_ok == true` and `g_grind_closeby_test_send_ok == true` after each CLOSED stage.
- **Hand-derived expected values asserted:**
  - `Rpl_OrderSeamCount() == 2` and `Rpl_OrderPriceForLayer("L", 0, "ENT") == 1.09981` at `1791331139000` (`23:58:59`) and `1791331260000` (`00:01:00.000`);
  - `Rpl_OrderSeamCount() == 0` and `Rpl_OrdersCount() == 0` at `1791331140000` (`23:59:00.000`), `1791331170000` (`23:59:30`), `1791331230000` (`00:00:30`), and `1791590250000` (`Fri 23:57:30`);
  - `g_grind_order_test_send_ok == true` restored after each CLOSED tick.
- **Expected at `B-0` (`efada62`):** **FAILS** --- sends at the 4 CLOSED timestamps succeed (`Rpl_OrderSeamCount() == 2` instead of `0`).

---

#### `RT68` --- `Test_RT68_SessionsFileLoadAndAbort` (F1 file)
- **One-line summary:** `Rpl_RunReplayFiles` loads a valid `sessions_file` column (`5` rows, gating a CLOSED tick), aborts (`returns false`) when a named `sessions_file` is missing, and runs ungated (`0` rows) when the `sessions_file` column is absent.
- **Setup & Arithmetic:**
  - Single tick at `D'2026.10.06 23:59:30'` = `1791331170000` (`bid = 1.10000, ask = 1.10002`, CLOSED under A-4).
  - **Sub-case 1 (`run_rt68.csv` with `,sessions_file` = `sessions_rt68.csv` containing the 5 rows of A-4):**
    - `Rpl_RunReplayFiles("rt68", false)` returns `true`, loads `5` session rows (prints `RPL|SESSIONS|sessions_rt68.csv|5`), and refuses sends at `23:59:30` (`Rpl_OrdersCount() == 0`).
  - **Sub-case 2 (`run_rt68m.csv` with `,sessions_file` = `sessions_does_not_exist.csv`):**
    - `Rpl_RunReplayFiles("rt68m", false)` aborts and returns `false`.
  - **Sub-case 3 (`run_rt68n.csv` without `sessions_file` column):**
    - `Rpl_RunReplayFiles("rt68n", false)` returns `true`, loads `0` session rows (prints `RPL|SESSIONS|none`), and places `L` L0 `ENT` (`1.09981`) and `S` L0 `ENT` (`1.10151`) at `23:59:30` (`Rpl_OrdersCount() == 2`).
- **Hand-derived expected values asserted:**
  - Sub-case 1: `ok1 == true`, `g_rpl_sessions_count == 5`, `Rpl_OrdersCount() == 0`;
  - Sub-case 2: `ok2 == false`;
  - Sub-case 3: `ok3 == true`, `g_rpl_sessions_count == 0`, `Rpl_OrdersCount() == 2`.
- **Expected at `B-0` (`efada62`):** **FAILS** --- `Rpl_RunReplayFiles` at `efada62` ignores column 24 (`sessions_file`), so Sub-case 1 has `Rpl_OrdersCount() == 2` and Sub-case 2 returns `true` instead of `false`.

---

#### `RT69` --- `Test_RT69_SyncDeferCloseByToRealOutBy` (F2 d --- the C 17:16 case)
- **One-line summary:** When the replay fills an exit at `T0`, the real `EXT` row arrives `9 ms` later (`T0 + 9`), and the real `OUT_BY` row arrives `1 s` later (`T0 + 1000`), the layer stays in the book until `T0 + 1000`, the two `OUT_BY` deal rows carry `T0 + 1000`, and the new `S` L0 `ENT` is placed only at `T0 + 1000`.
- **Setup & Arithmetic:**
  - `cfg.sync = true`, timing `0`, `from_ms = T0 = 1791280800000`, `to_ms = T0 + 2000 = 1791280802000`, `width_s = 2.0` pips (`0.00020`), `exit_s = 10.0` pips (`0.00100`).
  - Seed short L0 (`S`, layer `0`, `entry = 1.10500`, `ticket = 6901`, `open_ms = T0 - 3600000`) and resting exit (`S`, layer `0`, `EXT`, `BUY_LIMIT` at `1.10400`, `ticket = 6911`).
  - Sync rows:
    - `1791280800009,EXT,S,0,1.10400,6902,` (`T0 + 9`, 9 ms after replay's exit fill)
    - `1791280801000,OUT_BY,S,0,1.10400,6901,` (`T0 + 1000`, 1 s after replay's exit fill)
    - `1791280801000,OUT_BY,S,0,1.10500,6902,` (`T0 + 1000`)
  - Ticks:
    1. **Tick 0** at `T0 + 0` (`1791280800000`): `bid = 1.10398, ask = 1.10400` -> replay fills `S` L0 `EXT` (`6911`) at `1.10400` (`pos_id = 900000001`), queues close-by `(6901, 900000001)`, which reaches `Rpl_ProcessCloseByDone` at `T0 + 0` and is **deferred** because `6901` is still in `g_rpl_true_book`. Short depth remains `1`.
    2. **Tick 1** at `T0 + 100` (`1791280800100`): `bid = 1.10450, ask = 1.10452`. Real `EXT` (`T0 + 9`) marks `6901` closing in `g_rpl_true_book`. Short depth remains `1`; `0` `S` L0 `ENT` orders placed.
    3. **Tick 2** at `T0 + 500` (`1791280800500`): `bid = 1.10450, ask = 1.10452`. Short depth remains `1`; `0` `S` L0 `ENT` orders placed.
    4. **Tick 3** at `T0 + 1000` (`1791280801000`): `bid = 1.10450, ask = 1.10452` (`mid = 1.10451`).
       - Real `OUT_BY` for `6901` at `T0 + 1000` completes the deferred pair `(6901, 900000001)` at `time_ms = T0 + 1000` (`1791280801000`), writing two `DEAL_ENTRY_OUT_BY` deal rows at `T0 + 1000` (`6901` at `1.10400`, `gross_pnl = (1.10500 - 1.10400) / 0.00001 * 1.0 * 0.01 = +1.00`, and `900000001` at `1.10500`) and `1` `SCALP_CLOSED` event at `T0 + 1000`, and removing `6901` (short depth becomes `0`).
       - `Grind_OnTickEngine` at `T0 + 1000` sees short depth `0` and places the new `S` L0 `ENT` (`SELL_LIMIT` at `mid + width_s = 1.10451 + 0.00020 = 1.10471`) at `T0 + 1000`.
- **Hand-derived expected values asserted:**
  - After running ticks up to `T0 + 500` (before `T0 + 1000`): `Rpl_ShortDepth() == 1`, `OUT_BY` deal count == `0`, and `S` L0 `ENT` `PLACE` count == `0`;
  - After Tick 3 (`T0 + 1000`):
    - `DEAL_ENTRY_OUT_BY` deal count == `2`, both with `time_ms == 1791280801000` (`T0 + 1000`), prices `1.10400` and `1.10500`;
    - `SCALP_CLOSED` event count == `1`, with `time_ms == 1791280801000` (`T0 + 1000`);
    - `S` L0 `ENT` `PLACE` count == `1`, with `time_ms == 1791280801000` (`T0 + 1000`) and `price == 1.10471`.
- **Expected at `B-0` (`efada62`):** **FAILS** --- `Rpl_ProcessCloseByDone` at `efada62` completes the close-by at `T0 + 0` (`OUT_BY` deals at `1791280800000`), `Rpl_ShortDepth()` at `T0 + 500` is `0` (or `1` if re-entered), and `S` L0 `ENT` is placed at `T0 + 0` / `T0 + 100` instead of `T0 + 1000`.

---

#### `RT70` --- `Test_RT70_SyncUntouchedExitRemovedOnRealExt` (F2 b, e)
- **One-line summary:** When the replay does NOT touch a layer's exit and the real `EXT` row arrives, the resting exit order is removed, `exit_position_ticket` is set to the row's `position_id`, `0` deal rows are written, no new exit order is placed between `EXT` and `OUT_BY`, and the layer leaves at `OUT_BY`.
- **Setup & Arithmetic:**
  - `cfg.sync = true`, timing `0`, `from_ms = T0 = 1791280800000`, `to_ms = T0 + 4000 = 1791280804000`, `exit_s = 10.0` pips (`0.00100`).
  - Seed short L0 (`S`, layer `0`, `entry = 1.10500`, `ticket = 7001`, `open_ms = T0 - 3600000`) and resting exit (`S`, layer `0`, `EXT`, `BUY_LIMIT` at `1.10400`, `ticket = 7011`).
  - Sync rows:
    - `1791280800500,EXT,S,0,1.10400,7002,` (`T0 + 500`)
    - `1791280802500,OUT_BY,S,0,1.10400,7001,` (`T0 + 2500`)
  - Ticks (all with `bid = 1.10450, ask = 1.10452`, so `ask 1.10452 > 1.10400` and the replay never touches `7011`):
    - **Tick 0** at `T0 + 0`: `7011` rests at `1.10400`, `Rpl_ShortDepth() == 1`.
    - **Tick 1** at `T0 + 1000` (after `EXT` at `T0 + 500`): `7011` is removed from the order book, `g_grind_short.layers[0].exit_order_ticket == 0`, `g_grind_short.layers[0].exit_position_ticket == 7002UL`, `Rpl_DealsCount() == 0`, `Rpl_ShortDepth() == 1`, and `Grind_ExitQManageSide` does not re-place an exit order.
    - **Tick 2** at `T0 + 2000` (still before `OUT_BY` at `T0 + 2500`): still `!Rpl_OrderExistsForLayer("S", 0, "EXT")` and `Rpl_ShortDepth() == 1`.
    - **Tick 3** at `T0 + 3000` (after `OUT_BY` at `T0 + 2500`): `7001` is removed (`Rpl_ShortDepth() == 0`, `Rpl_DealsCount() == 0`).
- **Hand-derived expected values asserted:**
  - After `T0 + 1000` and `T0 + 2000`:
    - `Rpl_ShortDepth() == 1` and `Rpl_HasPosition(7001UL) == true`;
    - `Rpl_OrderExistsForLayer("S", 0, "EXT") == false`;
    - `g_grind_short.layers[0].exit_order_ticket == 0` and `g_grind_short.layers[0].exit_position_ticket == 7002UL`;
    - `Rpl_DealsCount() == 0`;
  - After `T0 + 3000`:
    - `Rpl_ShortDepth() == 0`, `!Rpl_HasPosition(7001UL)`, and `Rpl_DealsCount() == 0`.
- **Expected at `B-0` (`efada62`):** **FAILS** --- at `efada62`, the `EXT` row at `T0 + 500` removes `7001` from `g_rpl_true_book` (core 2566--2570) and `Rpl_SyncResetToTrueBook` removes layer `7001` at `T0 + 1000`, so `Rpl_ShortDepth()` at `T0 + 1000` is `0` instead of `1`.

---

#### `RT71` --- `Test_RT71_SyncOutByBeforeReplayCbDone` (F2 c--d, `OUT_BY` first)
- **One-line summary:** In timed `"base"` sync mode, when the replay has filled an exit (`T0 + 261`) and sent its close-by (`T0 + 300 -> T0 + 594`), and the real `OUT_BY` row arrives at `T0 + 450` (before `CB_DONE` at `T0 + 594`), the pair completes at `T0 + 450` and the later `CB_DONE` at `T0 + 594` is a no-op.
- **Setup & Arithmetic:**
  - `cfg.sync = true`, timed `"base"` (`d_closeby = 294` ms, `lam = 261` ms), `from_ms = T0 = 1791280800000`, `to_ms = T0 + 2000 = 1791280802000`.
  - Seed short L0 (`S`, layer `0`, `entry = 1.10500`, `ticket = 7101`, `open_ms = T0 - 3600000`) and resting exit (`S`, layer `0`, `EXT`, `BUY_LIMIT` at `1.10400`, `ticket = 7111`).
  - Sync rows:
    - `1791280800270,EXT,S,0,1.10400,7102,` (`T0 + 270`)
    - `1791280800450,OUT_BY,S,0,1.10400,7101,` (`T0 + 450`)
    - `1791280800450,OUT_BY,S,0,1.10500,7102,` (`T0 + 450`)
  - Ticks:
    1. **Tick 0** at `T0 + 0`: `bid = 1.10398, ask = 1.10400` -> touches `7111` at `T0 + 0`, schedules `RPL_TM_EV_DEAL` at `T0 + 261`.
    2. **Tick 1** at `T0 + 300`: `bid = 1.10450, ask = 1.10452`.
       - `Rpl_TmRunEventsUpTo(T0 + 300)` runs `DEAL` at `T0 + 261` (`fill_price = 1.10400`, `pos_id = 900000001`), queuing close-by `(7101, 900000001)`.
       - Real `EXT` at `T0 + 270` marks `7101` closing in `g_rpl_true_book`.
       - `ONTICK` at `T0 + 300` runs `STAGE:CLOSEBY` (`300 -> 300 + 294 = 594`), popping `(7101, 900000001)` and scheduling `RPL_TM_EV_CLOSEBY_DONE` at `T0 + 594`.
    3. **Tick 2** at `T0 + 500`: `bid = 1.10450, ask = 1.10452`.
       - Real `OUT_BY` for `7101` at `T0 + 450` (before `T0 + 594`) completes `(7101, 900000001)` at `time_ms = T0 + 450` (`1791280800450`), writing `2` `DEAL_ENTRY_OUT_BY` deal rows at `T0 + 450` and `1` `SCALP_CLOSED` event at `T0 + 450`, and removing `7101` (short depth = `0`).
    4. **Tick 3** at `T0 + 700`: `bid = 1.10450, ask = 1.10452` (after `T0 + 594`).
       - `RPL_TM_EV_CLOSEBY_DONE` at `T0 + 594` finds both positions already closed by `OUT_BY` and writes nothing.
- **Hand-derived expected values asserted:**
  - `DEAL_ENTRY_IN` `EXT` deal count == `1`, at `time_ms == 1791280800261` (`T0 + 261`), `price == 1.10400`;
  - `DEAL_ENTRY_OUT_BY` deal count == `2`, both at `time_ms == 1791280800450` (`T0 + 450`, prices `1.10400` and `1.10500`), `0` deals at `T0 + 594`;
  - `SCALP_CLOSED` event count == `1`, at `time_ms == 1791280800450` (`T0 + 450`);
  - `Rpl_ShortDepth() == 0` after `T0 + 500` and at end of run.
- **Expected at `B-0` (`efada62`):** **FAILS** --- at `efada62`, the sync resets at `T0 + 300` / `T0 + 500` purge `7101` and `900000001` from `g_rpl_pos_meta` (`Rpl_PurgeTicketFromSeams`), so `CB_DONE` at `T0 + 594` hits `!Rpl_FindPosMeta` (core 2301) and writes `0` `OUT_BY` deals and `0` `SCALP_CLOSED` events.

---

#### `RT72` --- `Test_RT72_TimedInFlightExitAtRealExt` (F2 b, a fill in flight)
- **One-line summary:** In timed `"base"` sync mode, when the broker touches an exit order at `T0 + 0` (`DEAL` pending at `T0 + 261`) and the real `EXT` row arrives at `T0 + 100` (`Rpl_BkIsExec == true`), the pending deal is NOT cancelled and completes at `T0 + 261`.
- **Setup & Arithmetic:**
  - `cfg.sync = true`, timed `"base"` (`lam = 261` ms), `from_ms = T0 = 1791280800000`, `to_ms = T0 + 2000 = 1791280802000`.
  - Seed short L0 (`S`, layer `0`, `entry = 1.10500`, `ticket = 7201`, `open_ms = T0 - 3600000`) and resting exit (`S`, layer `0`, `EXT`, `BUY_LIMIT` at `1.10400`, `ticket = 7211`).
  - Sync rows:
    - `1791280800100,EXT,S,0,1.10400,7202,` (`T0 + 100`)
    - `1791280801000,OUT_BY,S,0,1.10400,7201,` (`T0 + 1000`)
  - Ticks:
    1. **Tick 0** at `T0 + 0`: `bid = 1.10398, ask = 1.10400` -> `Rpl_TmBrokerStep` touches `7211` at `T0 + 0`, sets `exec = true`, schedules `RPL_TM_EV_DEAL` at `T0 + 261`.
    2. **Tick 1** at `T0 + 100`: `bid = 1.10450, ask = 1.10452`. Real `EXT` at `T0 + 100` sees `Rpl_BkIsExec(7211) == true` (replay HAS touched it), so F2 b leaves `7211` and its pending `DEAL` event intact.
    3. **Tick 2** at `T0 + 300`: `bid = 1.10450, ask = 1.10452`. `Rpl_TmRunEventsUpTo(T0 + 300)` fires `RPL_TM_EV_DEAL` at `T0 + 261` (`1791280800261`, `price = 1.10400`).
    4. **Tick 3** at `T0 + 1000`: `bid = 1.10450, ask = 1.10452`. Real `OUT_BY` at `T0 + 1000` completes the close-by at `T0 + 1000`.
- **Hand-derived expected values asserted:**
  - `DEAL_ENTRY_IN` `EXT` deal count == `1`, with `time_ms == 1791280800261` (`T0 + 261`) and `price == 1.10400`;
  - `g_rpl_tm_sync_dropped_events == 0`;
  - `DEAL_ENTRY_OUT_BY` deal count == `2`, at `time_ms == 1791280801000` (`T0 + 1000`).
- **Expected at `B-0` (`efada62`):** **FAILS** --- at `efada62`, the `EXT` row at `T0 + 100` removes `7201` from `g_rpl_true_book`, `Rpl_SyncResetToTrueBook` calls `Grind_OrderTestRemove(7211)`, and `Rpl_TmProcessSyncRemovals` calls `Rpl_BkDrop(7211)` and `Rpl_TmCancelDealEvents(7211)` (core 1111--1112), dropping the pending deal (`EXT` deal count = `0`, `g_rpl_tm_sync_dropped_events == 1`).

---

#### `RT73` --- `Test_RT73_SyncHeldExitAtRealExt` (F2 b, a held exit)
- **One-line summary:** When a middle layer under the barbell exit queue has no exit order (`exit_order_ticket == 0`) and its real `EXT` row arrives, F2 b sets `exit_position_ticket` to the row's `position_id`, places no exit order for it between `EXT` and `OUT_BY` (even after depth drops to 2), and removes the layer at its `OUT_BY`.
- **Setup & Arithmetic:**
  - `cfg.sync = true`, timing `0`, `from_ms = T0 = 1791280800000`, `to_ms = T0 + 4000 = 1791280804000`, `exit_l = 10.0` pips (`0.00100`).
  - Seed 3 long layers (barbell exit queue at `depth = 3`: `Grind_ExitQRequired(rank, 3)` is `true` for `rank 0` = L2 and `rank 2` = L0, and `false` for `rank 1` = L1):
    - L0: `ticket = 7301, entry = 1.10000, open_ms = T0 - 3600000` (`rank 2`, exit `1.10100`)
    - L1: `ticket = 7302, entry = 1.09930, open_ms = T0 - 2400000` (`rank 1`, **held bare**, `exit_order_ticket == 0`)
    - L2: `ticket = 7303, entry = 1.09860, open_ms = T0 - 1200000` (`rank 0`, exit `1.09960`)
  - Sync rows:
    - `1791280800500,EXT,L,1,1.10030,7304,` (`T0 + 500`, real `EXT` for held middle layer L1)
    - `1791280800600,OUT_BY,L,2,1.09960,7303,` (`T0 + 600`, removes L2 so depth drops from 3 to 2 where `Grind_ExitQRequired` is `true` for all layers)
    - `1791280802500,OUT_BY,L,1,1.10030,7302,` (`T0 + 2500`, L1's own `OUT_BY`)
  - Ticks (all with `bid = 1.09900, ask = 1.09902`):
    1. **Tick 0** at `T0 + 0`: exits placed for L0 (`1.10100`) and L2 (`1.09960`); L1 (`7302`) has no exit order (`!Rpl_OrderExistsForLayer("L", 1, "EXT")`), `Rpl_LongDepth() == 3`.
    2. **Tick 1** at `T0 + 500` (at L1 `EXT`): F2 b sets L1's `exit_position_ticket = 7304UL` (`exit_order_ticket == 0`), `Rpl_LongDepth() == 3`, `!Rpl_OrderExistsForLayer("L", 1, "EXT")`.
    3. **Tick 2** at `T0 + 1000` (after L2 `OUT_BY` at `T0 + 600`, before L1 `OUT_BY` at `T0 + 2500`): `Rpl_LongDepth() == 2` (`7301` and `7302`), and because `7302` has `exit_position_ticket == 7304UL != 0`, `Grind_ExitQManageSide` does NOT place an exit order for L1 (`!Rpl_OrderExistsForLayer("L", 1, "EXT")`).
    4. **Tick 3** at `T0 + 3000` (after L1 `OUT_BY` at `T0 + 2500`): `7302` is removed (`Rpl_LongDepth() == 1`, `!Rpl_HasPosition(7302UL)`).
- **Hand-derived expected values asserted:**
  - At `T0 + 0`: `Rpl_OrderExistsForLayer("L", 0, "EXT") == true`, `Rpl_OrderExistsForLayer("L", 2, "EXT") == true`, `Rpl_OrderExistsForLayer("L", 1, "EXT") == false`, `Rpl_LongDepth() == 3`;
  - At `T0 + 500`: `Rpl_LongDepth() == 3`, `Rpl_HasPosition(7302UL) == true`, `g_grind_long.layers[1].exit_position_ticket == 7304UL`, `Rpl_OrderExistsForLayer("L", 1, "EXT") == false`;
  - At `T0 + 1000`: `Rpl_LongDepth() == 2`, `Rpl_HasPosition(7302UL) == true`, `Rpl_OrderExistsForLayer("L", 1, "EXT") == false`;
  - At `T0 + 3000`: `Rpl_LongDepth() == 1`, `Rpl_HasPosition(7302UL) == false`.
- **Expected at `B-0` (`efada62`):** **FAILS** --- at `efada62`, the `EXT` row at `T0 + 500` immediately removes `7302` from `g_rpl_true_book` and from `g_grind_long.layers` (`Rpl_LongDepth() == 2` and `Rpl_HasPosition(7302UL) == false` at `T0 + 500`).

---

#### `RT74` --- `Test_RT74_SyncCompletionPromotesExitToBrokerBook` (F2, promotion at completion)
- **One-line summary:** In timed `"base"` sync mode, when a 3-layer book's completion at an `OUT_BY` row (`T0 + 1500`) drops depth from 3 to 2 and `Grind_ExitQManageSide` promotes the middle layer's held exit (`BUY_LIMIT` at `1.12575`, live at `T0 + 1500 + 287 = T0 + 1787`), that promoted exit is registered in `g_rpl_bk` and fills when touched at `T0 + 2000` (`DEAL` at `T0 + 2261`).
- **Setup & Arithmetic:**
  - `cfg.sync = true`, timed `"base"` (`d_place = 287` ms, `d_closeby = 294` ms, `lam = 261` ms), `from_ms = T0 = 1791280800000`, `to_ms = T0 + 3000 = 1791280803000`, `exit_s = 10.0` pips (`0.00100`).
  - Seed 3 short layers (`depth = 3`, so `rank 0` = S2 and `rank 2` = S0 have exits, while `rank 1` = S1 is held bare):
    - S0: `ticket = 7401, entry = 1.12605, open_ms = T0 - 3600000`, seeded `EXT` `BUY_LIMIT` at `1.12505` (`ticket = 7411`)
    - S1: `ticket = 7402, entry = 1.12675, open_ms = T0 - 1800000`, **held bare** (target `1.12675 - 0.00100 = 1.12575`)
    - S2: `ticket = 7403, entry = 1.12745, open_ms = T0 - 900000`, seeded `EXT` `BUY_LIMIT` at `1.12645` (`ticket = 7413`)
  - Sync rows:
    - `1791280800300,EXT,S,2,1.12645,7404,` (`T0 + 300`)
    - `1791280801500,OUT_BY,S,2,1.12645,7403,` (`T0 + 1500`)
  - Ticks:
    1. **Tick 0** at `T0 + 0`: `bid = 1.12643, ask = 1.12645` -> touches S2's exit (`7413` at `1.12645`), schedules `RPL_TM_EV_DEAL` at `T0 + 261`.
    2. **Tick 1** at `T0 + 400`: `bid = 1.12650, ask = 1.12652`.
       - `DEAL` at `T0 + 261` fills `7413` (`pos_id = 900000001`), queues close-by `(7403, 900000001)`.
       - Real `EXT` at `T0 + 300` marks `7403` closing in `g_rpl_true_book`.
       - `ONTICK` at `T0 + 400` sends close-by (`400 -> 694`), scheduling `RPL_TM_EV_CLOSEBY_DONE` at `T0 + 694`.
    3. **Tick 2** at `T0 + 1000`: `bid = 1.12650, ask = 1.12652`.
       - `CB_DONE` at `T0 + 694` sees `7403` still in `g_rpl_true_book`, so it **defers** `(7403, 900000001)` (`Rpl_ShortDepth() == 3`, S1 still held bare).
    4. **Tick 3** at `T0 + 1500`: `bid = 1.12650, ask = 1.12652`.
       - Real `OUT_BY` for `7403` at `T0 + 1500` runs the deferred `CB_DONE` completion at `T0 + 1500`: removes S2 (`7403`, depth `3 -> 2`), and `Grind_ExitQManageSide` inside `Grind_ProcessDeal` promotes S1 (`7402`) by placing `S` L1 `EXT` `BUY_LIMIT` at `1.12575` (`send_start = T0 + 1500 = 1791280801500` stamped into `g_rpl_orders[n].time_ms` at `ea/fxgrind_replay_core.mqh:747` via `line 770`, `send_end = T0 + 1500 + 287 = T0 + 1787 = 1791280801787`), registered in `g_rpl_bk` via `Rpl_BkPlace` (`line 772`) with `live_ms = T0 + 1787`.
       - Note: because `Grind_ExitQManageSide` already set `g_grind_short.layers[1].exit_order_ticket != 0` during the `OUT_BY` completion, `Grind_OnTickEngine` at `T0 + 1500` does NOT re-place it; therefore the order is in `g_rpl_bk` ONLY if the `OUT_BY` completion registered it via `Rpl_BkPlace`.
    5. **Tick 4** at `T0 + 2000` (after `live_ms = T0 + 1787`): `bid = 1.12573, ask = 1.12575` -> `Rpl_TmBrokerStep` touches S1's promoted exit (`1.12575`) at `T0 + 2000` and schedules `RPL_TM_EV_DEAL` at `T0 + 2000 + 261 = T0 + 2261`.
    6. **Tick 5** at `T0 + 2500`: `bid = 1.12590, ask = 1.12592` -> `Rpl_TmRunEventsUpTo(T0 + 2500)` executes `RPL_TM_EV_DEAL` at `T0 + 2261` (`1791280802261`).
- **Hand-derived expected values asserted:**
  - At `T0 + 1000` (after `CB_DONE` at `T0 + 694`, before `OUT_BY` at `T0 + 1500`): `Rpl_ShortDepth() == 3` and `Rpl_OrderExistsForLayer("S", 1, "EXT") == false`;
  - `DEAL_ENTRY_OUT_BY` deals for S2 (`7403`) == `2`, at `time_ms == 1791280801500` (`T0 + 1500`);
  - `S` L1 `EXT` `PLACE` in `g_rpl_orders` has `time_ms == 1791280801500` (`send_start = T0 + 1500`, stamped at `ea/fxgrind_replay_core.mqh:747` via `line 770`), `price == 1.12575`, and broker book `live_ms == 1791280801787` (`send_end = T0 + 1500 + 287`, `Rpl_BkPlace` at `line 772`);
  - `S` L1 `EXT` `DEAL_ENTRY_IN` deal count == `1`, with `time_ms == 1791280802261` (`T0 + 2000 + 261`) and `price == 1.12575`.
- **Expected at `B-0` (`efada62`):** **FAILS** --- at `efada62`, the `EXT` row at `T0 + 300` removes `7403` at `T0 + 400` (`Rpl_ShortDepth() == 2` at `T0 + 1000` instead of `3`, `0` `OUT_BY` deals at `T0 + 1500`, and S1's exit is placed at `send_start = T0 + 400 = 1791280800400` (`live_ms = send_end = T0 + 400 + 287 = 1791280800687`) instead of `send_start = 1791280801500` (`live_ms = 1791280801787`)).

---

## 3. Which Existing Tests (Python and RT) Each Change Is Expected to Affect, and Why

### 3.1 Existing Python Tests (`research/replay/test_*.py`)
- **A-1 (`build_real.py`):** **Affects 0 existing tests.** Existing `test_build_real.py` fixtures omit `seq` and `session_id` on their rows, and A-1 leaves rows without `seq` or `session_id` unchanged.
- **A-2 (`build_segments.py` / `build_inputs.py`):** **Affects 0 existing tests.** `sessions_file` defaults to `None`, producing byte-identical 23-column `run_<tag>.csv` output when omitted.
- **A-3 (`build_holdout.py`):** **Affects 0 existing tests.** All new flags (`--window-end-ms`, `--first-ids`, `--sessions`, `--sends-extra-b/-c/-d`) default to Plan 3's values.
- **A-4 (`sessions_eurusd_ic.csv`):** **Affects 0 existing tests.** Adds a new input file without modifying any existing file.

### 3.2 Existing MQL5 Tests (`RT1`--`RT63` in `ea/fxgrind_replay_tests.mq5`, 461 assertions)
- **F3 (`Rpl_SyncResetToTrueBook` lines 2534--2535):** **Affects 0 existing RTs.** None of the existing sync tests (`RT8`, `RT8b`, `RT25`, `RT26`, `RT41`, `RT45`, `RT46`, `RT47`, `RT50`) test a `< 2.0`-pip add-order reprice after a sync reset, and segment-start one-shot flags (`2803--2804`) are preserved.
- **F4 (stale-feed skip `> 5000 ms` strict):** **Affects 0 existing RTs.** Every existing multi-tick RT that expects `Grind_OnTickEngine` to place or modify orders after the first tick has inter-tick gaps `<= 5000 ms` (`1000 ms` in `RT2`--`RT53`/`RT62`, and at most `5000 ms` (`0 -> 5000`, not strictly `> 5000`) in `RT55`--`RT58`/`RT63`). The only existing RTs with tick gaps `> 5000 ms` are `RT9`/`RT15`/`RT46` (which assert rollover swap in `Rpl_ApplySwapRollover`, before `Grind_OnTickEngine`), `RT21` (which asserts `Rpl_GapReportCount()` in `Rpl_RecordGapIfNeeded`), and `RT60` (which asserts `TIMER` rows in `out_rt60_free_timing.csv`).
- **F1 (trade-session table):** **Affects 0 existing RTs.** No existing RT loads a `sessions_file` or populates the session table, and `Rpl_ResetAll()` clears the table before every test.
- **F2 (sync exit / close-by deferral):** **Affects 0 existing RTs.**
  - `RT8`, `RT25`, `RT26` use `OUT_BY` rows without `EXT` rows, so layers leave the book at `OUT_BY` as today.
  - `RT8b`, `RT45`, `RT46`, `RT47`, `RT50` use only `ENT`/`ROLL` or direct `Rpl_SyncResetToTrueBook()` with no `EXT`/`OUT_BY`.
  - `RT41` (`Test_RT41_SyncExtClosesLayer`) fills `S` L0 `EXT` at `T1 = RplMs(RPL_T0, 1)` and applies a real `EXT` row at `T2 + 300`; under F2, `5301` stays in `g_grind_short.layers` with `exit_position_ticket = 900000001 != 0` (deferred awaiting `OUT_BY`) so no second exit is placed on `T3..T5`, preserving `n == 1` `EXT` `DEAL_ENTRY_IN` deal and `ext_ms == RplMs(RPL_T0, 1)`.
