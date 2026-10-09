This message has a line count at the bottom

# CURSOR PROMPT -- REPLAY FIX 4: THE REPLAY'S OWN ORDER LOG (OBSERVABILITY ONLY)

**Workspace: `D:\fxmatrix`, branch `replay-harness`** (tip `a08fb0d`; code
`624a29b`, script `8a58547`). Written by Claude 9 Oct ~23:50Z from the
branch, the fix-3 outputs (`research/replay/runs/*_624a29b/`) and
`research/replay/results/eurusd_20261008_624a29b/` on `main`. Line numbers
are `624a29b`'s (core, `ea/fxgrind_replay_core.mqh`) and `438a00b`'s (tests,
`ea/fxgrind_replay_tests.mq5`). Questions for Gemini in s8; his rulings and
Claude's check are in s9. The earlier replay prompts
(first run, fixes 1-3) govern what this file does not change. **No replay
rule changes here:** the harness only WRITES what its order book does.

## 0. RESTATE AND STOP (do this first, then wait)

1. Read this file from `main` at the commit that carries it (`git fetch`,
   `git show <that commit>:prompts/cursor_replay_fix4.md`) BEFORE switching
   branches; then `git checkout replay-harness`, `git pull`; report `git log
   --oneline -1` (must be `a08fb0d`) and the pin (`git diff --stat 5bb5fdb
   origin/main -- ea/fxgrind.mq5` EMPTY).
2. Restate O1, O2 and O3 (s2) in ONE line each, quoting this prompt; give
   the assertion count of RT48 and RT49 (s3) and how many fail at commit 1.
3. Report anything in s1 you read differently in source.
4. STOP until the operator replies "go".

## 1. FINDINGS (Claude)

| # | Finding | Evidence | Kind |
|---|---|---|---|
| K1 | **37 of the 73 sync misses at `624a29b` cannot be read**: 22 exits of held or rolled layers, 14 deep adds, 1 L00 exit. The real side is in send_logs (every PENDING, MODIFY, REMOVE with its price); the replay writes its deals and the EA's events, not its orders, so where the replay's order sat, and when it moved, is unknown | `results/eurusd_20261008_624a29b/classified.csv` (category `open`) on `main` | OBSERVABILITY |
| K2 | The replay's orders live in the EA's order seam: `g_grind_order_test_records[]` (`ticket`, `magic`, `comment`, `price`, `type`) and `g_grind_order_test_count` (`ea/grind_engine.mqh` 118-128); the EA writes it through `Grind_OrderTestUpsert` (229-252) / `Grind_OrderTestRemove` (254 on); the comment parses with `GrindCommentParse` (`ea/grind_comment.mqh` 33). `Rpl_ScanNewOrders` (core 544-550) reads it once per tick to stamp placement times | source | FACT |
| K3 | In `Rpl_ProcessOneTick` (core 1546-1635) the order book can change at seven points: the sync rows (`Rpl_ApplySyncDealsUpTo`, 1571: re-seeds, removed layers' exits), the fills (`Rpl_FillsOnTick`, 1587: a filled order leaves the book and `Grind_ProcessDeal` reacts, e.g. a fill-time exit), the close-by queues (1601), the lattice (1605, rolls), the engine (1610: L0, re-centre, adds, missing exits), the close-by completion (`Rpl_ProcessCloseByDone`, 1622) and the carry timer (1627-1629, exit shifts). Fills write a deal row with the ORDER ticket (`Rpl_WriteDealOutput`, 1320) | source | FACT |
| K4 | The first pass found a timing difference it could not prove without K1: the replay's close-by completes at once (B 1 Oct 11:12:11.208: EXT and both close-by legs on one tick), the real one ~1 s later (OUT_BY 11:12:12.497), so the replay may place the next L0 at another mid (plan s12, M3). An order log shows the replay's L0 price and the tick it was placed | plan s12 record | DATA |

## 2. FIX (commit 2: core only)

| # | Fix |
|---|---|
| O1 | **The order log.** New `struct RplOrderRow { int seg_id; int sync_idx; long time_ms; string stage; string action; ulong ticket; long type; string side; int layer; string role; double price; double old_price; }`, a global `RplOrderRow g_rpl_orders[]`, and a snapshot of the seam book `RplOrderSnap g_rpl_order_snap[]` (`ticket`, `type`, `comment`, `price`) with its count. New `void Rpl_OrderLogDiff(const long t, const string stage)`: compare the seam book with the snapshot; (a) a ticket in the book and not in the snapshot -> a row `PLACE` (old_price 0); (b) in both with a different price (`MathAbs(new - old) > _Point / 2`) -> `MODIFY` (price = new, old_price = old); (c) in the snapshot and not in the book -> `FILL` when `g_rpl_deals` holds a row with `order == ticket` and `time_ms == t` (search from the end), else `REMOVE` (price = the last price, old_price 0); then copy the book into the snapshot. Rows in the order: every (a) and (b) in the book's order, then every (c) in the snapshot's order. side / layer / role from `GrindCommentParse` (empty / -1 / empty when it fails); seg_id = `g_rpl_cfg.seg_id`, sync_idx = `g_rpl_sync_idx`. New accessors `int Rpl_OrderLogCount()` and `bool Rpl_GetOrderLogRow(const int i, RplOrderRow &out)`: it FIRST sets every field of `out` to 0 / "" / 0.0, then returns false when `i` is out of range, else copies row `i` and returns true. `Rpl_ResetAll` (core 387-452) empties `g_rpl_orders` and the snapshot |
| O2 | **Where it runs.** In `Rpl_ProcessOneTick`, call `Rpl_OrderLogDiff(t, <stage>)` right after each of: `Rpl_ApplySyncDealsUpTo(t)` (1571) `"SYNC"`; `Rpl_FillsOnTick(...)` and its abort check (1587-1589) `"FILL"`; `Grind_ProcessCloseByQueues(...)` (1601) `"CLOSEBY"`; the `Grind_LatticeOnTick(...)` call (1605-1607) `"LATTICE"`; the `Grind_OnTickEngine(...)` call (1610-1612) `"ENGINE"`; `Rpl_ProcessCloseByDone(...)` (1622) `"CB_DONE"`; and after the carry-timer `if` block (after 1630) `"TIMER"`. In `Rpl_RunTicks` (1637-1664), once, right before the tick loop: `Rpl_OrderLogDiff(cfg.from_ms, "SEED")` (the orders the segment starts with). Nothing else in the tick changes; no early return is added |
| O3 | **The output file.** `RplRunOutputHandles` (core 222-229) gains `int orders`; `Rpl_OpenRunOutputs` (2122-2139) opens `prefix + "orders.csv"` like the others (CSV, ANSI, ','), counts it in `open`, and writes the header `seg_id,sync_idx,time_ms,stage,action,ticket,type,side,layer,role,price,old_price`; `Rpl_CloseRunOutputs` closes it; `Rpl_AppendSegmentOutputs` (2155-2215) writes every `g_rpl_orders` row after the events, `type` as `BUY_LIMIT` / `SELL_LIMIT` (else the number), `price` and `old_price` with the symbol's digits (as the deals). No other output changes |

## 3. COMMITS AND TESTS

**Commit 1: tests only** (`ea/fxgrind_replay_tests.mq5`), plus in the core:
the two structs, the two globals, an EMPTY `Rpl_OrderLogDiff`, `Rpl_OrderLogCount`
returning 0 and `Rpl_GetOrderLogRow` with O1's zeroing and `return false`
(not called anywhere else) so the file compiles. A helper in the tests file:
`AssertOrderRow(prefix, index, time_ms, stage, action, ticket, price)`: 6
assertions (`" get"` = the accessor's result, `" time"`, `" stage"`,
`" action"`, `" ticket"`, `" price"` within 1e-9), as `AssertDealRow`.

- **T22 RT48 the diff, one action at a time (36 assertions, F: 36 fail at
  commit 1).** `Rpl_ResetAll()`; `c1 = GrindCommentBuild(RPL_SLOT_DEFAULT,
  "L", 2, "EXT")`; `Grind_OrderTestUpsert(5901UL, (long)RPL_MAGIC_DEFAULT,
  c1, 1.10100, ORDER_TYPE_SELL_LIMIT)`; `Rpl_OrderLogDiff(1000, "A")`;
  `Grind_OrderTestUpsert(5901UL, (long)RPL_MAGIC_DEFAULT, c1, 1.10108,
  ORDER_TYPE_SELL_LIMIT)`; `Rpl_OrderLogDiff(2000, "B")`;
  `Rpl_OrderLogDiff(2500, "B2")` (no change: no row); `Grind_OrderTestRemove(5901UL)`;
  `Rpl_OrderLogDiff(3000, "C")`; `c2 = GrindCommentBuild(RPL_SLOT_DEFAULT,
  "S", 1, "ENT")`; `Grind_OrderTestUpsert(5902UL, (long)RPL_MAGIC_DEFAULT,
  c2, 1.10570, ORDER_TYPE_SELL_LIMIT)`; `Rpl_OrderLogDiff(3500, "D")`;
  `Grind_OrderTestRemove(5902UL)`; `Rpl_WriteDealOutput(4000, 7001UL,
  5902UL, 7101UL, DEAL_ENTRY_IN, DEAL_TYPE_SELL, "ENT", "S", 1, 1.10570)`;
  `Rpl_OrderLogDiff(4000, "E")`. Expect: `AssertTrue("RT48 count",
  Rpl_OrderLogCount() == 5)`; `AssertOrderRow("RT48 r0", 0, 1000, "A",
  "PLACE", 5901UL, 1.10100)`; row 0's `side == "L"`, `layer == 2`, `role ==
  "EXT"`, `type == ORDER_TYPE_SELL_LIMIT` (4: `"RT48 r0 side"`, `" layer"`,
  `" role"`, `" type"`); `AssertOrderRow("RT48 r1", 1, 2000, "B", "MODIFY",
  5901UL, 1.10108)` and row 1's `old_price` 1.10100 (1: `"RT48 r1 old"`);
  `AssertOrderRow("RT48 r2", 2, 3000, "C", "REMOVE", 5901UL, 1.10108)`;
  `AssertOrderRow("RT48 r3", 3, 3500, "D", "PLACE", 5902UL, 1.10570)`;
  `AssertOrderRow("RT48 r4", 4, 4000, "E", "FILL", 5902UL, 1.10570)`.
  1 + 30 + 4 + 1 = 36. At commit 1 nothing is logged and every row reads
  zeroed (no expected value is 0 or ""): all 36 fail.
- **T23 RT49 a seeded layer's exit, placed and filled, in a run (7
  assertions, F: 7 fail).** As RT43 without the accrued carry:
  `Rpl_ResetAll()`; default config; `cfg.to_ms = RplMs(RPL_T0, 4)`;
  `Rpl_ConfigureEngine(cfg)`; `Rpl_SeedLayer("L", 0, 1.10000, RplMs(RPL_T0,
  -3600), 5951UL, 0.0, 0.0, RPL_LOTS_DEFAULT)`; RT43's four ticks (bid
  1.10050, 1.10100, 1.10108, 1.10050; ask = bid + `RPL_SPREAD`);
  `Rpl_RunTicks`. Find `i` = the first row with action `PLACE`, side `L`,
  layer 0, role `EXT` (-1 if none) and read it with
  `Rpl_GetOrderLogRow(i, r)`; `AssertTrue("RT49 placed", i >= 0)`;
  `AssertTrue("RT49 at T0", r.time_ms == RplMs(RPL_T0, 0))`;
  `AssertEqStr("RT49 stage", r.stage, "ENGINE")` (the engine places the
  missing exit, `Grind_RetryMissingExits`, `ea/grind_engine.mqh` 3203);
  `AssertNear("RT49 price", r.price, 1.10100, 1e-9)`; find `j` = the first
  row with action `FILL` and `ticket == r.ticket` (-1 if none), read it into
  `q`; `AssertTrue("RT49 filled", j >= 0)`; `AssertTrue("RT49 fill at T1",
  q.time_ms == RplMs(RPL_T0, 1))`; `AssertEqStr("RT49 fill stage", q.stage,
  "FILL")`. At commit 1 the log is empty: all 7 fail.

Totals: **381 run** (338 + 43); commit 1 fails 43.

**Commit 2: O1, O2 and O3**, core only; the tests file is NOT touched. If a
test fails and you believe its expected value or its counting is wrong
(RT49's stage or times included), STOP and report the order rows and the
source lines; do not edit it. Push after each commit. Do not compile. STOP
after commit 2: Claude reads it before "go run".

## 4. RUNNING (after Claude has read commit 2 and the operator says "go run")

Every step through `powershell -NoProfile -ExecutionPolicy Bypass -File
tools\replay_run.ps1 ...` as in fix 3 (the script is unchanged).

- **R0** Pin; `-Mode Copy`. STOP: the operator closes the replay terminal,
  compiles BOTH replay files in its MetaEditor and replies "compiled".
- **R1** `-Mode Suite -Tag rt_<commit 2 sha7>`: predicted **381 run, 381
  pass**. Report every `FAIL |` line and the `RPL|SUMMARY` line. Any FAIL:
  STOP.
- **R2** `-Mode Inputs -Commit <the main commit that carries this file>
  -Set eurusd_20261008`: 66 files (the suite overwrote `swaps.csv`).
- **R4** Six `-Mode Run` calls in the usual order (`eurusd_d` free, sync;
  `eurusd_c`; `eurusd_b`), `-SwapsSha
  dc7da509b35e6846f12f03692bf973632847ab3f2ad7dc865a93d91309f95b6c`, `-Label
  <tag>_<free|sync>`. Report each `DONE` line, any `RPL|ABORT`, every
  `ORDERS_KEPT` below seeded, and the row count of each
  `out_<tag>_<free|sync>_orders.csv`.
- **R5** Commit each run's outputs (the five `out_*` files, the orders file
  included) to `research/replay/runs/<tag>_<free|sync>_<commit 2 sha7>/` as
  before, with the `_rpl_*.txt` files. A file over 5 MB is NOT committed:
  report its size and SHA-256. Push. STOP. Do not analyse them.

## 5. NEGATIVE SPACE

- Change only `ea/fxgrind_replay_core.mqh` and `ea/fxgrind_replay_tests.mq5`
  (and `research/replay/runs/`). No EA file, no runner change, no script
  change, no change to any replay rule (fills, sync, seeding, rollover,
  close-by, timer, intervals): the diff READS the seam book and writes rows.
- Do not compile; do not run anything on the desktop's main terminal, the
  VPS or the Linux boxes; only `D:\mt5-replay`, only through the script.
- Do not check out `main`, merge, open a PR, `git stash`, check out files
  from other commits, `git add .` or `-u`. Do not commit tick files.

## 6. FAILURE MODES (STOP and report; do not improvise)

- A test fails, or passes at commit 1 when predicted to fail.
- Any `RPL|ABORT`, a hash mismatch, a run with no `DONE` line.
- A run whose total `run_ms` is more than twice fix 3's for the same tag
  (`research/replay/runs/<tag>_<mode>_624a29b/out_*_summary.txt`): report
  both.

## 7. NOT IN THIS FIX

Reading the order logs against send_logs (Claude's, in Python, after R5).
Any model of the broker's close-by latency (K4): see GO4-2.

## 8. FOR GEMINI (attack the premises; say which fact is missing)

- **GO4-1.** O1-O2 observe the order book at seven points per tick and at a
  segment's start, by difference. An order placed and removed between two
  points (inside one engine call) leaves no row. Enough for reading the
  misses against send_logs (which logs every send), or is a point missing?
- **GO4-2.** The close-by latency (K4): the harness completes a close-by at
  once; the broker's follows its EXT by 0.35-14 s (median 0.84 s on B, fix 2
  H2). Plan s6 pre-registered placement-latency SENSITIVITIES (250 ms, 1 s),
  reported and never deciding; plan s8 reads a fail in M1-M3 as "a
  tick-level replay cannot be trusted". Should a close-by latency become a
  harness input (a later fix, its value fixed in advance from send_logs), or
  stay a reported sensitivity?
- **GO4-3.** Plan s8 allows at most three attempts on this window for a
  RULE's model (M4-M10), then back to you. Fixes 1-3 corrected the
  harness's own state (the lattice history, the resting book at an init,
  the carry ledger GVs), not a rule's model. Do they count as attempts?
- **GO4-4.** What fact is missing?

## 9. GEMINI'S RULINGS AND CLAUDE'S CHECK

Gemini 9 Oct ~23:40Z on the file at `5e32484` (attached); checked by Claude
the same evening. Gemini: "Proceed with Cursor execution." Nothing here
changes s2 or s3: Cursor builds O1-O3 and RT48-RT49 as written (381 run, 43
fail at commit 1).

- **GO4-1. Accepted.** A place and remove inside one engine call leaves no
  row; send_logs would show both. The comparison after R5 reads the replay
  log as the book's state at each point, not as a list of sends, and a real
  send pair with no replay row is read as such. No EA hook is possible here
  (the pin: no EA file changes).
- **GO4-2. Ruled: the close-by latency stays a REPORTED SENSITIVITY; no
  latency model in the harness.** His premise is corrected: a value fixed in
  advance from send_logs would be a measurement, not a fit, and GRC-5 fixed
  the FILL rule, not the close-by. The ruling stands on the plan itself: the
  broker model (s6) was fixed before any run, and changing it after seeing
  results would be a new pre-registration. So M3 misses stay counted in T1,
  and s8 applies as written: a fail in M1-M3 means a tick-level replay is not
  trusted and T2 alone decides count-level use.
- **GO4-3. Ruled: fixes 1-3 do not count toward s8's three attempts**
  (harness state, not a rule's model: fix 1 the lattice history start, fix 2
  the resting book at an init, fix 3 the carry ledger GVs and the sync true
  book). Claude agrees. The count starts with the first fix to a rule's
  model (M4-M10).
- **GO4-4. Not a missing fact: his own reasoning shows O1 handles it.** Each
  diff copies the book into the snapshot, so a second MODIFY on the same
  tick (e.g. a re-seed at SYNC, a carry shift at TIMER) carries the price the
  first one left as its old_price. (Sync re-seeds and removes; it does not
  shift an exit.) No change.


Line count: 201
