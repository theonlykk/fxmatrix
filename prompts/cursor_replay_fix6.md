This message has a line count at the bottom

# CURSOR PROMPT -- REPLAY FIX 6: H1 THE CB_DONE PLACEMENT TIME; H2 THE BROKER'S AND THE EA'S TIMING (PLAN 2)

**Workspace: `D:\fxmatrix`, branch `replay-harness`** (tip `6972e16`; code
`90fbce4`). Written by Claude 10 Oct ~02:55Z from
`docs/research/replay-calibration-eurusd-2.md` (plan 2, RULED: s3 the timing
model R1-R5 and its constants, s5 H1 / H2, s6 the runs, s11 / s13 Gemini's
rulings) and the committed fix-5 outputs (`research/replay/runs/*_90fbce4/`).
Line numbers are `90fbce4`'s (core `ea/fxgrind_replay_core.mqh`; tests
`ea/fxgrind_replay_tests.mq5`). The earlier replay prompts govern what this
file does not change. Questions for Gemini are in s9. **Two parts, each with
its own STOP: Part A (H1) is built, run and read before Part B (H2) starts.**

## 0. RESTATE AND STOP (do this first, then wait)

1. Read this file from `main` at the commit that carries it (`git fetch`,
   `git show <that commit>:prompts/cursor_replay_fix6.md`) BEFORE switching
   branches; then `git checkout replay-harness`, `git pull`; report `git log
   --oneline -1` (must be `6972e16`) and the pin (`git diff --stat 5bb5fdb
   origin/main -- ea/fxgrind.mq5` EMPTY).
2. Restate H1 (s2) in ONE line and D1-D10 (s4) in one line each, quoting
   this prompt; give each test's assertion count (s3, s5) and how many fail
   at commit 1 and at commit 3.
3. Check assumptions A1-A5 (s5) in source and quote the lines you rely on.
   If one does not hold, say which and STOP.
4. Report anything in s1 you read differently in source.
5. STOP until the operator replies "go".

## 1. FINDINGS (Claude; core at `90fbce4` unless named)

| # | Finding | Where |
|---|---|---|
| K1 | The tick sequence: sync rows, intervals, the market seeded, `Rpl_FillsOnTick` (FILL), `Grind_ProcessCloseByQueues` (CLOSEBY), the lattice (LATTICE), `Grind_OnTickEngine` (ENGINE), `Rpl_ScanNewOrders`, `Rpl_ProcessCloseByDone` (CB_DONE), the carry timer once a minute (TIMER) | `Rpl_ProcessOneTick` 1706-1800 |
| K2 | **The CB_DONE defect.** `Rpl_ScanNewOrders` (1784) stamps placement times BEFORE `Rpl_ProcessCloseByDone` (1787) and the timer (1790-1796); `Rpl_FillsOnTick` skips an order whose placement time is 0 or not before the tick (1448-1449). So an order placed at CB_DONE or TIMER is stamped at the NEXT tick and can fill only from the tick after that | core |
| K3 | A fill is a deal on the touching tick, at the ORDER's price (`price = rec.price`, 1468), and the EA's deal handler runs in that tick (1490) | `Rpl_FillsOnTick` 1442-1493 |
| K4 | A close-by completes inside `Grind_ProcessCloseByQueues` (the queue task is gone); `Rpl_ProcessCloseByDone` then writes the two OUT_BY deals at the tick's time and runs the EA's handler for each (1362-1439) | core |
| K5 | What each stage placed in the six sync runs at `90fbce4` (the order logs): CB_DONE places only EXT orders (the exit queue after a close-by); every L0 is placed at ENGINE; an ENT fill makes three changes at FILL (REMOVE of an exit, PLACE EXT, PLACE ENT add); an EXT fill makes none | `research/replay/runs/eurusd_*_sync_90fbce4/out_*_orders.csv` |
| K6 | The exit queue: rank 0 is the DEEPEST layer (a short side: the highest entry; `Grind_ExitQEntryBeats`), K = 1, H = 0: a layer's exit rests when its rank is 0 or depth - 1, else it is held | `ea/grind_exitq.mqh` 41-75; `ea/grind_config.mqh` |
| K7 | The live EA: `OnTick` calls `Grind_ProcessCloseByQueues` first; deals reach `Grind_OnTradeTransactionEngine` in `OnTradeTransaction`; the carry step runs in `OnTimer` when the 60 s telemetry interval falls due | `ea/fxgrind.mq5` 438-440, 496-500, 419-430 |
| K8 | Plan 2's constants (s3) and sensitivities (s6) | plan 2 |

## 2. PART A, H1: THE CB_DONE PLACEMENT TIME (commit 2: core only)

| # | Fix |
|---|---|
| H1 | Call `Rpl_ScanNewOrders(t)` also right after `Rpl_ProcessCloseByDone(t, cb_before, cb_n)` (before its `Rpl_OrderLogDiff(t, "CB_DONE")`) and right after the carry-timer `if` block (before `Rpl_OrderLogDiff(t, "TIMER")`). Nothing else changes: an order placed at any stage of tick t then has placement time t and can fill from the next tick (the first plan's fill rule) |

## 3. PART A: COMMITS AND TESTS

**Commit 1: tests only** (`ea/fxgrind_replay_tests.mq5`).

- **T27 RT53 a held exit promoted at CB_DONE fills on the next tick (3
  assertions, F: 1 fails at commit 1).** Files in `replay\` as RT44 (the
  22-field run row, no orders file; `swaps.csv` and `intervals_rt53.csv` as
  RT44). `run_rt53.csv`: `1,GRIND_TEST,22260201,<RplMs(RPL_T0,0)>,
  <RplMs(RPL_T0,5)>,15,2,7,7,10,10,8,50,2,1,0,-1,0,1,8,seed_rt53.csv,
  ticks_rt53.csv` (width L 15, S 2; add 7 / 7; exit 10 / 10; cap 8;
  stranded 50; deadband 2; lattice 1; reroll 0; gate -1; carry 0; fill-time
  place 1; reserve 8). `seed_rt53.csv` (the seed header) with three short
  layers: `S,0,1.12605,<RplMs(RPL_T0,-3600)>,6601,0,0,0.01,0`,
  `S,1,1.12675,<RplMs(RPL_T0,-1800)>,6602,0,0,0.01,0`,
  `S,2,1.12745,<RplMs(RPL_T0,-900)>,6603,0,0,0.01,0`. Exits: L2 1.12645
  (rank 0, rests), L1 1.12575 (rank 1, held), L0 1.12505 (rank 2 = depth
  - 1, rests). `ticks_rt53.csv`, one per second from T0, prices as these
  strings: T0 bid `1.12698` ask `1.12700`; T1 `1.12643` / `1.12645` (L2's
  exit fills; its close-by completes; L1's exit is placed at CB_DONE); T2
  and T3 `1.12573` / `1.12575` (touch L1's exit only: L0's exit 1.12505 and
  the long L0 near 1.12549 are not reached); T4 `1.12590` / `1.12592`.
  `AssertTrue("RT53 run", Rpl_RunReplayFiles("rt53", false))`; with a new
  test helper `Rpl_TestFindDeal(path, role, side, layer, entry_type,
  &time_ms, &price)` (the first deals row that matches; false if none):
  `AssertTrue("RT53 L1 exit filled", <found ",EXT,S,1", entry_type 0>)`;
  `AssertTrue("RT53 next tick", time_ms == RplMs(RPL_T0, 2))`. At commit 1
  the exit is stamped at T2 and fills at T3: "RT53 next tick" fails.

Totals: **393 run** (390 + 3); commit 1 fails 1. **If "RT53 next tick"
passes at commit 1, STOP and report.**

**Commit 2: H1**, core only. Push after each commit. Do not compile. STOP
after commit 2: Claude reads it before "go run".

**Part A runs** (after "go run"; as fix 5 s4, through `tools\replay_run.ps1`
only): R0 pin, `-Mode Copy`, STOP for "compiled"; R1 `-Mode Suite -Tag
rt_<commit 2 sha7>`, predicted 393 / 393, any FAIL: STOP; R2 `-Mode Inputs
-Commit <the main commit that carries this file> -Set eurusd_20261008`; R4
the six runs (`-SwapsSha
dc7da509b35e6846f12f03692bf973632847ab3f2ad7dc865a93d91309f95b6c`); R5
commit the outputs to `research/replay/runs/<tag>_<free|sync>_<commit 2
sha7>/` with the `_rpl_*.txt` files; push; **STOP. Part B starts only after
Claude has read Part A's runs and the operator says "go B".**

## 4. PART B, H2: THE TIMING MODEL (plan 2 s3), BEHIND `timing`

With `timing = 0` (the default) the harness runs exactly as H1: no code
path of H1 changes, no output file changes, no new file is written. Every
rule below applies only with `timing = 1`. All times are server ms (the
tick file's).

| # | Design |
|---|---|
| D1 | **Inputs.** Globals NOT cleared by `Rpl_ResetAll`: `g_rpl_tm_on` (bool), `g_rpl_tm_sens` (string), and the constants `g_rpl_tm_d_place`, `_d_modify`, `_d_closeby`, `_d_remove`, `_lam` (ms, long), `g_rpl_tm_thru_pts` (int), `g_rpl_tm_limit_price` (bool). `bool Rpl_SetTiming(const int timing, const string sens)`: timing 0 requires sens "base" (sets off; returns true); timing 1 takes one of the tokens below and sets the constants; anything else returns false and changes nothing. Accessors `long Rpl_TmD(const string action)` ("PLACE", "MODIFY", "CLOSE_BY", "REMOVE", "LAM"). Tokens (plan 2 s3, s6): `base` 287 / 288 / 294 / 43 / 261, thru 0, market price; `limitpx` base with the deal at the order price; `thru01` base with thru 1 point; `lat250` place 537, modify 538, rest base; `lat1000` place 1287, modify 1288; `p10` 283 / 284 / 289 / 38 / 256; `p90` 294 / 301 / 302 / 52 / 281 |
| D2 | **The broker's book**, separate from the EA's (the order seam, which stays the EA's view). `struct RplBkOrder { ulong ticket; long type; double price; long live_ms; double new_price; long new_from_ms; long remove_ms; bool exec; }` and its array (cleared by `Rpl_ResetAll`). `Rpl_BkPlace(ticket, type, price, live_ms)`; `Rpl_BkModify(ticket, new_price, from_ms)` (the old price holds until from_ms); `Rpl_BkRemove(ticket, at_ms)`; `Rpl_BkSetExec(ticket)`; `double Rpl_BkPriceAt(ticket, t)`; `bool Rpl_BkTouched(ticket, t, bid, ask, thru_pts)`: true when live_ms <= t, remove_ms is 0 or > t, not exec, and at t (price = `Rpl_BkPriceAt`) ask <= price - thru x point for a buy limit, bid >= price + thru x point for a sell limit (prices on the grid, as P1 of fix 5); `Rpl_BkDrop(ticket)` |
| D3 | **The EA's clock.** `g_rpl_tm_free_ms` (the EA is free from then), `g_rpl_tm_busy_kind` ("ONTICK" or "HANDLER"), `g_rpl_tm_queued` (an `OnTick` is queued). A handler starts at `start = max(its time, free_ms)`; its sends advance a cursor from start; it ends at the cursor; `free_ms = end`. A handler with no send ends at its start (0 ms) |
| D4 | **Sends, counted per stage** from the existing order-log diff (`Rpl_OrderLogDiff`'s rows for that stage, in the order it writes them): each PLACE, MODIFY or REMOVE row is one send of its constant, starting at the cursor. A PLACE goes into the broker's book with live_ms = the send's end; a MODIFY sets its new price from the send's end; a REMOVE sets remove_ms = the send's START (R2). Each queue task that `Grind_ProcessCloseByQueues` completed (the queues before and after the call, as `Rpl_SnapshotQueues`) is one CLOSE_BY send of `_d_closeby`, sent before any other send of that stage, in queue order; its completion is an event at the send's end (D6). FILL rows are not sends. The order log's `time_ms` is the send's start |
| D5 | **What the EA sees.** Before each stage of a handler the market is re-seeded (`Grind_MarketTestSeed`, `Grind_MarketTestSeedTimeMsc`, `Grind_CarryTestSeedTick`, `g_grind_carry_test_server_time`) from the newest tick at or before (start + the cursor so far). The lattice's tick history keeps EVERY tick at its own time, as now (`Grind_LatticeTestAddTick` on every tick: the live EA reads it with `CopyTicksRange`) |
| D6 | **Events** (one queue, ordered by time, then by creation): DEAL (an order touched at t: at t + lam), CLOSEBY_DONE (a close-by: at its send's end), QUEUED_ONTICK (at the end of the handler it was queued in), TIMER (D9). A DEAL handler: remove the order from the seam (`Grind_OrderTestRemove`) and the broker's book; open the position at the deal price: the executable side (ask for a buy, bid for a sell) of the newest tick at or before the deal time (R1), or the order price with `limitpx`; write the IN deal with time = the deal time; run `Grind_ProcessDeal` (stage "DEAL"). A CLOSEBY_DONE handler: `Rpl_ProcessCloseByDone`'s body for that task, its two OUT_BY deals at the completion time (stage "CB_DONE"). A QUEUED_ONTICK handler runs `OnTick`'s stages (D7 c) with the newest tick at its start |
| D7 | **The tick loop** for tick t (replacing K1's sequence when `timing = 1`): (a) the rollover and gap checks as now; (b) run every event whose start (D3) is <= t, in order, each as a handler (D3); (c) the sync rows <= t and intervals as now; the lattice history gets tick t; (d) **the broker at t:** every broker order with `Rpl_BkTouched` true becomes exec and gets a DEAL event at t + lam; (e) **the EA at t:** if free_ms <= t, run `OnTick` as a handler at t: CLOSEBY, LATTICE, ENGINE (with the existing invariant / abort checks and the first-tick calls), each with D5's market and D4's sends; else if busy_kind is "ONTICK", the tick gets no `OnTick` (count it in that handler's `dropped`); else, if no `OnTick` is queued, queue one QUEUED_ONTICK at free_ms; (f) the carry timer as D9; (g) outputs and the lattice prune as now; (h) after the segment's last tick, every event whose start is before to_ms runs as in (b) (the rest are SEG_END's pending count). `Rpl_FillsOnTick`, `Rpl_ScanNewOrders` and the CB_DONE call in the tick are not used with `timing = 1` |
| D8 | **An order in execution** (exec, D2): the EA still sees it in the seam until its DEAL. If a stage's diff shows a MODIFY of it, restore the seam record's price to the broker's and count `exec_modify_reverted`; if a REMOVE, the DEAL still fills it (it is re-created in the seam for the DEAL handler) and count `exec_remove_overruled`. Every order in the seam when the tick loop starts (the SEED diff: the orders file's adopted orders and anything seeding placed) enters the broker's book with live_ms = from_ms. **Sync's own changes are the harness's, not the EA's sends:** an order the SYNC stage removes from the seam (its diff rows; in the six sync runs at `90fbce4` the SYNC stage only REMOVEs EXT orders: 159 / 176 / 186, and places none) and a ticket purged by `Rpl_PurgeTicketFromSeams` leave the broker's book at once (no send, no busy time) and drop any pending DEAL (count `sync_dropped_events`); a layer sync re-seeds gets its exit from the EA's own later stages, which D4 counts |
| D9 | **The carry timer on its own clock** (plan 2 R5 "as live": `OnTimer` does not wait for a tick): TIMER events at from_ms + 60000, + 120000, ... up to to_ms, independent of ticks (in w2 every Monday-Thursday night's 23:50-23:59 server has a tick gap of ~61-62 s, so a tick-driven timer could run a carry step a minute late); each TIMER handler runs `Grind_CarryOnTimerStep` (stage "TIMER") with D5's market (the newest tick at or before its start). `g_rpl_last_timer_ms` is not used with `timing = 1` |
| D10 | **The timing file** `out_<tag><suffix>_timing.csv` (only with `timing = 1`; opened, written and closed with the other outputs): header `seg_id,kind,event_ms,start_ms,end_ms,sends,market_ms,dropped`; one row per handler (kind ONTICK, QUEUED_ONTICK, DEAL, CLOSEBY_DONE, TIMER; event_ms = the tick's or the event's time; market_ms = the time of the tick D5 seeded at its start), each followed by one row per stage it ran (kind `STAGE:<name>`, e.g. `STAGE:LATTICE`; event_ms as its handler's; start_ms = the stage's start, start + the cursor; end_ms = its end; sends = its sends; market_ms = the tick D5 seeded for that stage; dropped 0); at each segment's end a row `SEG_END` whose `sends` = events still pending (dropped) and whose `dropped` = exec_modify_reverted + exec_remove_overruled + sync_dropped_events |

**The run script and the runner (commit 5).** `ea/fxgrind_replay.mq5`: `input
int InpTiming = 0;` and `input string InpSens = "base";`; before
`Rpl_RunReplayFiles`: if `!Rpl_SetTiming(InpTiming, InpSens)`, print
`RPL|ABORT|TIMING_INPUT` and return; print `RPL|TIMING|<timing>|<sens>|`
and the five constants and thru. `tools/replay_run.ps1`: `[ValidateSet(0, 1)]
[int]$Timing = 0` and `[string]$Sens = 'base'`; step 0 for Run: `$Sens
-cmatch '^(base|limitpx|thru01|lat250|lat1000|p10|p90)\z'` else throw;
`$Timing -eq 0` with `$Sens -ne 'base'` throws; the preset gains
`InpTiming=$Timing` and `InpSens=$Sens`. Nothing else in either file.

## 5. PART B: COMMITS AND TESTS

**Commit 3: tests only**, plus stubs in the core so the file compiles:
`Rpl_SetTiming` returns false; `Rpl_TmD` returns 0; the D2 functions do
nothing and `Rpl_BkTouched` returns false, `Rpl_BkPriceAt` 0.0 (none called
by the run path). Each test that sets timing restores `Rpl_SetTiming(0,
"base")` at its end.

**Assumptions (check in source at s0 and quote; any failing: STOP):** A1
an EXT fill's handler makes no send for a layer whose close-by it queues
(K5); A2 a queued close-by is sent by the first `OnTick` after the deal
(K7: the queue is OnTick's first call); A3 when a 3-layer short side loses
its rank-0 layer, the OUT_BY handlers place the held rank-1 layer's exit
(K5, K6); A4 the first tick's `OnTick` makes at most 10 sends (RT55's
first event is 5 s later); A5 in RT55 the `OnTick` at T + 5400 makes no
send but the close-by (read from its timing row: `sends` = 1; if not,
STOP and report the row).

- **T28 RT54 the broker's book (10 assertions, F: 6 fail at commit 3).**
  `Rpl_ResetAll()`. `Rpl_BkPlace(1, ORDER_TYPE_BUY_LIMIT, 1.10000, 1000)`:
  "RT54 not live before" `!Rpl_BkTouched(1, 999, 1.09990, 1.10000, 0)`;
  "RT54 live at end" `Rpl_BkTouched(1, 1000, 1.09990, 1.10000, 0)`.
  `Rpl_BkModify(1, 1.10010, 2000)`: "RT54 old price before"
  `Rpl_BkPriceAt(1, 1999)` near 1.10000; "RT54 new price from"
  `Rpl_BkPriceAt(1, 2000)` near 1.10010. `Rpl_BkRemove(1, 3000)`: "RT54
  rests until remove" `Rpl_BkTouched(1, 2999, 1.10000, 1.10010, 0)`; "RT54
  gone at remove" `!Rpl_BkTouched(1, 3000, 1.10000, 1.10010, 0)`.
  `Rpl_BkPlace(2, ORDER_TYPE_BUY_LIMIT, 1.10000, 0)`; `Rpl_BkSetExec(2)`:
  "RT54 exec not touchable" `!Rpl_BkTouched(2, 500, 1.09990, 1.10000, 0)`.
  `Rpl_BkPlace(3, ORDER_TYPE_BUY_LIMIT, 1.10000, 0)`: "RT54 thru exact no"
  `!Rpl_BkTouched(3, 10, 1.09990, 1.10000, 1)`; "RT54 thru one point"
  `Rpl_BkTouched(3, 10, 1.09989, 1.09999, 1)`. `Rpl_BkPlace(4,
  ORDER_TYPE_SELL_LIMIT, 1.10050, 0)`: "RT54 sell touch"
  `Rpl_BkTouched(4, 10, 1.10050, 1.10052, 0)`. Fail at commit 3: live at
  end, old price, new price, rests until remove, thru one point, sell
  touch; the four "not" assertions pass in both states (guards).
- **The RT55-RT58 files** (one set, written by RT55, reused): as RT53
  (`run_rt55.csv` with to_ms `<RplMs(RPL_T0,0)> + 10000`, `seed_rt55.csv` =
  RT53's three layers). `ticks_rt55.csv`, times T = RplMs(RPL_T0,0) plus the
  ms shown: +0 `1.12698` / `1.12700`; +5000 `1.12643` / `1.12645` (L2's exit
  touched); +5100 `1.12638` / `1.12640`; +5400 `1.12640` / `1.12642`; +5500
  `1.12641` / `1.12643`; +5900 `1.12573` / `1.12575` (L1's exit price, not
  yet live); +5950 `1.12580` / `1.12582`; +9000 `1.12573` / `1.12575` (L1's
  exit touched, live); +9100 `1.12568` / `1.12570`; +9500 `1.12590` /
  `1.12592`.
- **T29 RT55 the close-by chain, `base` (12 assertions, F: 8 fail at
  commit 3).** `Rpl_SetTiming(1, "base")`; run "rt55" free. The timeline by
  hand: L2's exit (1.12645) touched at +5000, its DEAL at +5261 priced at
  the newest tick at or before it (+5100: ask 1.12640); the EXT handler
  makes no send (A1); the first tick after +5261 is +5400: `OnTick` sends
  the close-by +5400 to +5694 (A2, A5); +5500 arrives inside it and gets no
  `OnTick`; the OUT_BY deals at +5694; CLOSEBY_DONE runs from +5694 and
  places L1's exit (A3; live from +5981 or later); +5900 and +5950 arrive
  inside that handler: ONE `OnTick` is queued and reads +5950; +5900 does
  not fill L1's exit (not live); +9000 touches it: DEAL at +9261 at the
  newest tick at or before it (+9100: ask 1.12570). Assertions: "RT55 run";
  "RT55 L2 exit" found (`EXT,S,2`, entry_type 0); "RT55 L2 time" == T +
  5261; "RT55 L2 price" near 1.12640; "RT55 OUT_BY at end of send": two
  OUT_BY rows (entry_type 3) with time T + 5694; "RT55 L1 exit" found;
  "RT55 L1 time" == T + 9261; "RT55 L1 price" near 1.12570; "RT55 no
  OnTick inside the close-by": no ONTICK or QUEUED_ONTICK row with event_ms
  T + 5500 in `out_rt55_free_timing.csv`; "RT55 queued reads newest": a
  QUEUED_ONTICK row with market_ms T + 5950; "RT55 one queued": exactly one
  QUEUED_ONTICK row with start_ms in [T + 5694, T + 9000); "RT55 lattice
  stage after the close-by reads +5500" (R4, D5): the `STAGE:LATTICE` row
  of the ONTICK handler with event_ms T + 5400 has start_ms T + 5694 and
  market_ms T + 5500 (the close-by's 294 ms passed; +5500 is the newest
  tick at or before +5694). At commit 3 (the instant model): run, L2
  found, L1 found and the "no OnTick" assertion pass (the last a guard);
  the other 8 fail.
- **T30 RT56 `limitpx` (5 assertions, F: 2 fail).** The same files,
  `Rpl_SetTiming(1, "limitpx")`: "RT56 run"; "RT56 L2 time" T + 5261; "RT56
  L2 price" near 1.12645; "RT56 L1 time" T + 9261; "RT56 L1 price" near
  1.12575. At commit 3 the two prices pass (guards), the two times fail.
- **T31 RT57 `thru01` (4 assertions, F: 3 fail).** `Rpl_SetTiming(1,
  "thru01")`: L2's exit needs ask <= 1.12644: first at +5100 (1.12640),
  DEAL at +5361 at the newest tick at or before it (+5100: 1.12640); L1's
  exit needs ask <= 1.12574: first at +9100 (1.12570), DEAL at +9361 at
  1.12570. "RT57 run"; "RT57 L2 time" T + 5361; "RT57 L2 price" near
  1.12640; "RT57 L1 time" T + 9361.
- **T32 RT58 `timing = 0` on the same files (5 assertions, F: 0; the
  off-switch: it must pass in BOTH states, report it).** `Rpl_SetTiming(0,
  "base")`: H1's instant model: L2's exit fills at +5000 at 1.12645, L1's
  exit (placed at CB_DONE, stamped +5000 by H1) fills at the first
  touching tick after it, +5900, at 1.12575. "RT58 run"; "RT58 L2 time" T +
  5000; "RT58 L2 price" near 1.12645; "RT58 L1 time" T + 5900; "RT58 no
  timing file" (`out_rt58_free_timing.csv` does not exist). RT58 writes its
  own `run_rt58.csv` and `intervals_rt58.csv` (as RT55's) naming
  `seed_rt55.csv` and `ticks_rt55.csv`.
- **T34 RT60 the timer's own clock (4 assertions, F: 3 fail).**
  `Rpl_SetTiming(1, "base")`; `run_rt60.csv` as RT53's row with from_ms T
  and to_ms T + 140000, carry 0, the seed `seed_rt53.csv`; `ticks_rt60.csv`
  with two ticks only: T + 0 `1.12698` / `1.12700` and T + 130000 `1.12699` /
  `1.12701`. "RT60 run"; "RT60 timer at +60 s": a TIMER row with event_ms T
  + 60000; "RT60 timer at +120 s": a TIMER row with event_ms T + 120000
  (both before the second tick); "RT60 timer reads the newest tick": the
  first of them has market_ms T + 0. At commit 3 the run passes, the other
  three fail.
- **T33 RT59 the inputs (12 assertions, F: 10 fail).** "RT59 p90 accepted"
  `Rpl_SetTiming(1, "p90")`; then `Rpl_TmD`: "RT59 p90 place" 294, "modify"
  301, "close-by" 302, "remove" 52, "lam" 281; "RT59 lat1000 accepted"; its
  "place" 1287 and "modify" 1288; "RT59 bogus refused"
  `!Rpl_SetTiming(1, "bogus")`; "RT59 off with a sens refused"
  `!Rpl_SetTiming(0, "lat250")`; "RT59 base remove" (after
  `Rpl_SetTiming(1, "base")`) 43. At commit 3 the two refusals pass
  (guards).

Totals: **445 run** (393 + 52); commit 3 fails 32 (RT54 6, RT55 8, RT56 2,
RT57 3, RT59 10, RT60 3). **If any assertion listed as failing at commit 3 passes,
STOP and report.**

**Commit 4: H2** (D1-D10), core only. **Commit 5:** the run script and the
runner (s4 end). Push after each. Do not compile. STOP after commit 5:
Claude reads all three commits (the runner against s4 line by line) before
"go run".

## 6. PART B: RUNNING (after "go run")

R0 pin, `-Mode Copy`, STOP for "compiled"; R1 `-Mode Suite -Tag rt_<commit
5 sha7>`, predicted **445 / 445**, any FAIL: STOP; R2 `-Mode Inputs` as Part
A; R4, in this order, each of the six (B, C, D x free, sync) with
`-SwapsSha` as Part A, and after each run R5's copy:
1. `-Timing 0` (the off-switch): folders `<tag>_<mode>_<commit 5 sha7>_t0`;
2. `-Timing 1 -Sens base` (DECIDING): folders `<tag>_<mode>_<commit 5 sha7>`;
3. `-Timing 1 -Sens <s>` for s = limitpx, thru01, lat250, lat1000, p10,
   p90: folders `<tag>_<mode>_<commit 5 sha7>_<s>`.
Report each `DONE`, any `RPL|ABORT`, every `ORDERS_KEPT` below seeded, and
each SEG_END row's two counts. **For step 1 report the sha256 of every
deals, events, book and orders file next to Part A's: they must be equal;
any difference: STOP.** R5: commit every folder and the `_rpl_*.txt` files;
push; STOP; do not analyse them.

## 7. NEGATIVE SPACE

- Change only `ea/fxgrind_replay_core.mqh`, `ea/fxgrind_replay_tests.mq5`,
  `ea/fxgrind_replay.mq5` (commit 5), `tools/replay_run.ps1` (commit 5) and
  `research/replay/runs/`. No EA file (the pin). With `timing = 0` no
  behaviour of H1 changes.
- Do not change the fill comparison (beyond D2's thru), seeding, sync's
  rules, the swap rollover, intervals, the order log's columns, the deals /
  events / book / summary files' formats, or `compare.py`.
- Do not compile; only `D:\mt5-replay`, only through the script. Do not
  check out `main`, merge, open a PR, `git stash`, check out files from
  other commits, `git add .` or `-u`. Do not commit tick files.

## 8. FAILURE MODES (STOP and report; do not improvise)

A test fails, or passes at commit 1 / commit 3 when listed as failing; an
assumption A1-A5 fails; any `RPL|ABORT`; a hash mismatch (above all step 1
against Part A); a run with no `DONE` line; a run's time over three times
Part A's for the same tag; any SEG_END count above 0 in the deciding runs
(report the rows; do not change code).

## 9. FOR GEMINI (attack the premises; say which fact is missing)

- **GTP-1.** D2 / D8: the broker's book is kept apart from the EA's (the
  seam). A send to an order in execution is undone and counted, not
  modelled as a failed send (the seam has no failure path; the pin forbids
  EA changes). Right, given the counts are reported per segment?
- **GTP-2.** D4: sends are counted from the order-log diff, in the order
  the diff writes them (book order: places and modifies, then removes),
  not the EA's own call order; close-bys first in their stage. Is the
  approximation acceptable, and where could it move a placement time by
  more than one send (~0.3 s)?
- **GTP-3.** D5: the market is re-read at stage boundaries only, not at each
  call inside a stage. Enough?
- **GTP-4.** D9: the timer event is created at the first tick at which it is
  due (as the harness does now), not on its own clock between ticks. Does
  that matter for R5?
- **GTP-5.** D7: events whose start is at or before t run before tick t's
  broker step and `OnTick`. Is that order right (a DEAL at exactly a tick's
  time; a queued `OnTick` and a tick at the same ms)?
- **GTP-6.** s5: RT55-RT57 rest on A1-A5, checked in source by Cursor at s0
  and by the timing rows. Are the hand-derived timelines right, and is a
  rule left untested (R4's per-stage market has no test of its own)?
- **GTP-7.** What fact is missing?

## 10. GEMINI'S RULINGS AND CLAUDE'S CHECK

Gemini 10 Oct ~03:25Z (Extended Thinking) on the file at `d2f30cc`;
checked by Claude the same night. Gemini: "Proceed with Part A execution."

- **GTP-1: ACCEPTED** (the risk he names, an EA variable updated on a
  modify the broker refused, is why the counts stop the deciding runs:
  s8, any SEG_END count above 0).
- **GTP-2: ACCEPTED** as an approximation (his example, 4 modifies, is
  the case: which one goes live first can move by up to 3 sends).
- **GTP-3: ACCEPTED; his premise NOT accepted.** He says `SymbolInfoTick`
  inside one handler "generally" returns the same cached tick. That is
  not measured here and not documented in what we hold; the terminal takes
  ticks on its own thread, so a call after a ~0.3 s send can see a newer
  one. The stage-boundary re-read stands as the approximation it was
  stated to be.
- **GTP-4: ACCEPTED that it matters; his premise WRONG; D9 CHANGED.** He
  says ticks are sub-second, so a tick-driven timer is within ms of its
  clock. In the carry window they are not: every Monday-Thursday night's
  23:50-23:59 server in w2 has a tick gap of 61-62 s (1 Oct 62.4 s, 5 Oct 61.1, 6 Oct
  61.9, 7 Oct 61.3, 8 Oct 62.3; Claude, from the tick file). The timer now
  runs on its own 60 s clock (D9, plan 2 R5 "as live"); RT60 added.
- **GTP-5: the order ACCEPTED; his reason NOT.** "Trade callbacks get
  higher thread priority than `OnTick`" is not documented in what we
  hold; a tie at the same ms is a choice, kept: events first.
- **GTP-6: ACCEPTED in part; two of his statements WRONG.** (1) "+5900 L1
  exit placement": +5900 is a TICK; L1's exit is placed by the
  CLOSEBY_DONE handler from +5694 and live from +5981. (2) "R4 is
  validated by L2's deal price from +5100": the deal price is R1's rule (the
  broker's), not R4 (what the EA sees in a handler). R4 is tested only at a
  handler's start (RT55 "queued reads newest", RT60 "timer reads the
  newest tick"); the per-stage re-read inside a handler has no test of its
  own: a known gap, reported.
- **GTP-7: the question ANSWERED from the order logs; D8 CLARIFIED.** In
  the six sync runs at `90fbce4` the SYNC stage only REMOVEs EXT orders
  (159 / 176 / 186) and places none; a re-seeded layer's exit comes from
  the EA's later stages, which D4 counts. D8 now says that sync's own
  removals are the harness's (at once, no send).
- **His sign-off** ("a masterclass", "mathematically flawless") came with
  four wrong premises: BOOT s1's tell.
- **A second reader (Copilot, operator, 10 Oct ~03:30Z, on the same file):**
  mostly hedged and general; two premises do not fit this code (sends
  "interleaved with other asynchronous handlers": MT5 runs one handler at
  a time, R3; close-bys "batched first" by the diff: the close-by is
  `OnTick`'s first call, so first by construction). It also endorsed the
  tick-driven timer. Its missing fact points at the gap GTP-6 leaves (when
  the EA reads the market inside a handler): ADOPTED as a test: D10 now
  writes one row per stage with its market, and RT55 asserts that the
  LATTICE stage after the 294 ms close-by reads +5500.
- The changes above (D8, D9, D10's stage rows, RT55's twelfth assertion,
  RT60) and D7 (h) (Claude, while adding D9: events after a segment's last
  tick were never run) are new since his reading: s11.

## 11. SECOND ROUND FOR GEMINI (check only what this section lists)

- **GTP2-1.** D9 (the timer on its own 60 s clock, from the segment's
  start), D7 (h) (events after a segment's last tick still run up to
  to_ms), D8's sync sentence, D10's per-stage rows with RT55's twelfth
  assertion, and RT60 (s5), all new since your reading:
  right? The live timer's phase (from the EA's init) is unknown to the
  harness; from_ms is the choice.


## 12. GEMINI'S SECOND-ROUND RULING (GTP2-1, 10 Oct ~03:36Z) AND CLAUDE'S CHECK

- **GTP2-1: ACCEPTED** (D9, D7 (h), D8, D10's stage rows, RT55's twelfth
  assertion, RT60). Nothing in s2-s6 changes: Cursor builds the file as it
  stands (445 run; 32 fail at commit 3).
- **His phase premise checked in source:** the live carry step runs when
  `OnTimer` (every 1 s, `ea/fxgrind.mq5` 391) finds the 60 s telemetry
  interval due, and `g_grind_last_telemetry_tick` is 0 at init (259; due
  at once when 0, `ea/grind_archive.mqh` 699-700), so live steps run at
  about init + 1 s, then every 60 s. A segment's from_ms IS its init time
  (the run rows; B seg 1 from_ms = 1 Oct 03:58:52.001Z + 3 h), so D9's steps
  (from_ms + 60 s, + 120 s, ...) run ~59 s after the live ones, at the same
  rate. No window init falls inside a 20:50-20:59Z carry window, so each
  window keeps its steps; recorded as a known offset, D9 unchanged.
- **Two statements NOT accepted.** (1) RT55's twelfth assertion proves that
  the HARNESS re-seeds the market at stage boundaries (D5), not that the
  live EA re-queries it. (2) His missing fact (a timer's sends in a 62 s
  gap reach the broker only at the next tick) is not a gap: fills happen
  only on ticks, so an order live from inside the gap is first evaluated at
  the next tick exactly as live, and D7 (b) runs the late handler before
  that tick's broker step (d).

Line count: 385
