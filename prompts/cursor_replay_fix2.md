This message has a line count at the bottom

# CURSOR PROMPT -- REPLAY FIX 2: THE RESTING BOOK AT AN INIT, AND A REAL EXIT CLOSES ITS LAYER IN SYNC

**Workspace: `D:\fxmatrix`, branch `replay-harness`** (tip `b212e0b`, code
`32c90be`). Written by Claude 9 Oct ~19:30Z from the branch, the R4 outputs
(`research/replay/runs/*_32c90be/`) and the first comparison
(`research/replay/compare.py` on `main`). Line numbers are `32c90be`'s.
Questions for Gemini in s6; his rulings go in s7 before you get this file.
`prompts/cursor_replay_first_run.md` (s5, s6) and
`prompts/cursor_replay_first_run_fix1.md` (s4) still govern what this file
does not change.

## 0. RESTATE AND STOP (do this first, then wait)

1. Read this file from `main` at the commit that carries it (`git fetch`,
   `git show <that commit>:prompts/cursor_replay_fix2.md`) BEFORE switching
   branches; then `git checkout replay-harness`, `git pull`; report `git log
   --oneline -1` (must be `b212e0b`) and the pin (`git diff --stat 5bb5fdb
   origin/main -- ea/fxgrind.mq5` EMPTY).
2. Restate O1, O2, O3 and S1 (s2) in ONE line each, quoting this prompt; give the
   assertion count of each of RT39-RT42 (s3) and how many fail at commit 1.
3. Report anything in s1 you read differently in source.
4. STOP until the operator replies "go".

## 1. FINDINGS (Claude, from the comparison, send_logs and source)

The comparison (sync runs at `32c90be`, `compare.py` on `main`): T1 matched
on the touchable real deals B 88.5%, C 92.2%, D 91.1% (mark 95%);
replay-only deals B 28%, C 20%, D 11% (mark 5%). Most matched deals agree to
the point, ~0.26 s before the real fill. The causes found:

| # | Finding | Evidence | Kind |
|---|---|---|---|
| H1 | **The real EA keeps its resting orders across an init; the replay places new ones.** In send_logs (pipshed `--export-sends`, 9 Oct) no order is sent in the two minutes after 23 of the 29 window inits; of the other six, five send for a change the init itself made (breaker off: B seg 2, C seg 12; re-roll on: C seg 16; the flat attach: D seg 20; a rebuild: D seg 27, whose modifies carry the INIT row's own ms) and one trades (D seg 29, an exit fill at +115 s). 2-6 orders rest at an init (the exit queue holds the other exits). A resting exit carries the carry shifts applied before the restart (B 1 Oct: the L02-L05 exits 0.8 pip above the replay's; 2 Oct and 6 Oct 0.8 / 1.6 pip); the harness seeds layers with NO order (base s3.3 step 3, core `Rpl_SeedLayer` 674-700) and the engine places formula exits without that shift | send_logs; `research/replay/inputs/eurusd_20261008/orders_<seg_id>.csv` (28 inits; `build_orders.py`); the rebuilt book equals the order price, side, layer and role of every real fill (B 439, C 461, D 370) | DEFECT (base design) |
| H2 | **Sync re-opens a layer the replay has already exited.** The real close-by follows its EXT fill by 0.35-14 s (median 0.84 s, B); fix 1 A1 lets an EXT row change nothing, so the true book keeps the ENT position until its OUT_BY. The replay fills ~0.26 s earlier and completes its own close-by; the next sync (the real EXT row) finds the true position missing from the replay and seeds it again (core `Rpl_SyncResetToTrueBook` 1235-1298, step (b)); the engine places a fresh exit, already through the market, which fills again: 17 (B), 13 (C), 9 (D) replay-only exits, each 0.3-2 s after a matched one | `out_eurusd_*_sync_deals.csv`; e.g. B seg 1 S L04 EXT 15:26:04.434 matched, again 15:26:05.033 | DEFECT (fix 1 A1) |
| H3 | The 1 Oct ADR-160 entry gate (account float over 50% of the allowance) blocked entries on B and C from the CHF move until their breaker-off re-inits, and on D for half an hour; its marker is written only by an account's reporter instance and none was archived. From send_logs: each EA placed its short L00 with the gate check at 17:51:06 (B), 17:50:43 (C), 17:46:35 (D) server, then did NOT place the fill-time add after the short L00 filled at 18:36:5x; D placed again at 19:07:24. Now `BREAKER_GATED` intervals (inputs only, no harness change; RT24 covers the flag) | `intervals_eurusd_*.csv`; `build_inputs.py` INTERVALS | DATA |
| H4 | The engine adopts orders through the side state: `GrindLayer.exit_order_ticket` / `exit_target`, `GrindSideState.l0_pending_ticket` / `add_pending_ticket` (`ea/grind_state.mqh` 7-28); the order seam is `Grind_OrderTestUpsert(ticket, magic, comment, price, type)` (`ea/grind_engine.mqh` 229-252); the harness fills an order only once it has a placement time (`Rpl_OrderPlacedMs` > 0, core 1140-1142) | source | FACT |
| H5 | The run row reader already accepts more than 22 fields (core 2130); field 23 is the orders file (empty = none) | core 2130-2139; `run_eurusd_*.csv` on `main` | FACT |

Not in this fix (s5): the 2 Oct 12:30Z news spike (several fills inside one
second), a few L0 placements and touch-without-fill cases, and the comparator
itself (Claude's).

## 2. FIX (commit 2; core only)

| # | Fix |
|---|---|
| O1 | New `void Rpl_SeedOrder(const string side, const int layer, const string role, const double price, const ulong ticket, const long otype)`: `Grind_OrderTestUpsert(ticket, g_rpl_cfg.magic, GrindCommentBuild(RPL_SLOT_DEFAULT, side, layer, role), price, otype)`; `Rpl_TrackOrderPlaced(ticket, 1)` (placed before any tick); then link it: role `EXT` -> the layer of that side with `layer_index == layer` gets `exit_order_ticket = ticket` and `exit_target = price` (no such layer: `Rpl_Abort("SEED_ORDER_NO_LAYER")`); role `ENT` -> that side's `l0_pending_ticket = ticket` when the side has no layer, else its `add_pending_ticket = ticket`. Call it only after every seed layer is in. Nothing else about the order: the engine treats it as its own |
| O2 | `Rpl_RunReplayFiles`: field 23 (`fields[22]`, when `ArraySize(fields) > 22` and non-empty) names `orders_<seg_id>.csv`, read right after the seed file (core 2226) and before `Rpl_LoadSegmentSyncFromFile` (2229): header first field `side` (else `RPL|ABORT|BAD_ORDERS`); rows `side,layer,role,price,ticket,type`, type `BUY_LIMIT` / `SELL_LIMIT` -> `ORDER_TYPE_BUY_LIMIT` / `ORDER_TYPE_SELL_LIMIT`; each row -> `Rpl_SeedOrder`; a missing file -> `RPL|ABORT|MISSING_ORDERS` (return false, as `MISSING_SEED`); print `RPL|ORDERS|<seg_id>|count=<n>`. A 22-field row runs exactly as before |
| O3 | (s7, GF2-5) A guard, print only: `Rpl_SeedOrder` also appends the ticket to a global list (reset in `Rpl_ResetAll`); in `Rpl_ProcessOneTick`, on the segment's first tick (`seg_first_tick`) right after `Rpl_ScanNewOrders(t)` (core 1453), when the list is not empty print `RPL|ORDERS_KEPT|<seg_id>|<kept>/<seeded>`, kept = the listed tickets still in the order seam (`Grind_OrderTestFind`). No test: R4 reports the lines |
| S1 | `Rpl_ApplySyncDealsUpTo` (core 1300-1340): a new branch for `rd.kind == "EXT"`: remove from the true book the newest entry with `side == rd.side` and `layer == rd.layer` (the layer whose exit filled; none: nothing). The ENT position's later `OUT_BY` then finds nothing, as today for an unknown position. `changed` is set as for every row |

## 3. COMMITS AND TESTS

**Commit 1: tests only** (`ea/fxgrind_replay_tests.mq5`), plus an EMPTY stub
of `Rpl_SeedOrder` in the core (not called) so the file compiles. Tickets
5xxx (not the seam's 9000 range). `RPL_T0` as in the suite.

- **T13 RT39 a seeded resting exit is kept (8 assertions, F: 3 fail at
  commit 1).** `Rpl_ResetAll()`; default config; `cfg.to_ms = RplMs(RPL_T0,
  4)`; `Rpl_ConfigureEngine(cfg)`; `Rpl_SeedLayer("L", 0, 1.10000,
  RplMs(RPL_T0, -3600), 5101UL, 0.0, 0.0, RPL_LOTS_DEFAULT)`;
  `Rpl_SeedOrder("L", 0, "EXT", 1.10108, 5111UL, ORDER_TYPE_SELL_LIMIT)`.
  `AssertTrue("RT39 exit linked", g_grind_long.layers[0].exit_order_ticket ==
  5111UL)`. Ticks T0..T3: bid 1.10050, 1.10100, 1.10108, 1.10050, ask = bid +
  `RPL_SPREAD`. `Rpl_RunTicks`. `AssertDealRow("RT39 ext", 0, DEAL_TYPE_SELL,
  "EXT", "L", 0, 1.10108, RplMs(RPL_T0, 2))` (7). The formula exit (1.10100)
  would fill at T1; the kept one fills at T2. At commit 1: the link, the price
  and the time fail.
- **T14 RT40 a seeded add and L00 are linked and fill (10 assertions, F: 3
  fail).** Reset, default config, `to_ms` T+3, configure; seed short S0 entry
  1.10500, open T-3600 s, ticket 5201; `Rpl_SeedOrder("S", 0, "EXT", 1.10400,
  5211UL, ORDER_TYPE_BUY_LIMIT)`, `("S", 1, "ENT", 1.10570, 5212UL,
  ORDER_TYPE_SELL_LIMIT)`, `("L", 0, "ENT", 1.10481, 5213UL,
  ORDER_TYPE_BUY_LIMIT)` (the long side is flat; mid 1.10501 - 2 pips, so no
  re-centre). Assert `g_grind_short.layers[0].exit_order_ticket == 5211UL`,
  `g_grind_short.add_pending_ticket == 5212UL`, `g_grind_long.l0_pending_ticket
  == 5213UL` (3). Ticks T0 bid 1.10500, T1 bid 1.10570, T2 bid 1.10500 (ask =
  bid + spread). `AssertDealRow("RT40 add", 0, DEAL_TYPE_SELL, "ENT", "S", 1,
  1.10570, RplMs(RPL_T0, 1))` (7; the engine's own add has the same price, so
  these pass at commit 1).
- **T15 RT41 a real exit closes its layer in sync (2 assertions, F: 1 fails).**
  Reset, default config, `cfg.sync = true`, `to_ms` T+6, configure; seed
  short S0 entry 1.10500, open T-3600 s, ticket 5301 (no order: the engine
  places its exit, 1.10400). Real rows (`Rpl_SetSyncRealKindRows`):
  `<RplMs(T0,2)+300>,EXT,S,0,1.10400,5302,` only. Ticks T0 bid 1.10450, T1-T5
  bid 1.10398 (ask = bid + spread: the replay's exit fills at T1, its close-by
  completes by T2). Count the deal rows with role `EXT` and side `S`:
  `AssertTrue("RT41 one exit", n == 1)`; `AssertTrue("RT41 exit at T1",
  <that row's time_ms> == RplMs(RPL_T0, 1))`. At commit 1 the EXT row at T3
  seeds 5301 again and its new exit fills at T4: two rows. If "RT41 one exit"
  PASSES at commit 1 (the replay's close-by not done by T3), STOP and report
  the deal rows: the test does not show H2.
- **T16 RT42 the orders file (3 assertions, F: 2 fail).** As RT25 (files in
  `replay\`): `ticks_rt42.csv` = RT39's four ticks; `seed_rt42.csv` = RT39's
  layer; `orders_rt42.csv` = `side,layer,role,price,ticket,type` and
  `L,0,EXT,1.10108,5111,SELL_LIMIT`; `swaps.csv` as RT25; `intervals_rt42.csv`
  header only; `run_rt42.csv` = RT25's header and row with `,orders_file` /
  `,orders_rt42.csv` appended (23 fields), seed `seed_rt42.csv`, ticks
  `ticks_rt42.csv`, from T to T+4. `AssertTrue("RT42 run",
  Rpl_RunReplayFiles("rt42", false))`; `AssertTrue("RT42 kept exit",
  StringFind(Rpl_ReadWholeFile(dir + "out_rt42_deals.csv"), ",EXT,L,0,1.10108")
  >= 0)`; then `run_rt42m.csv` (and `intervals_rt42m.csv`, header only), the
  same row naming `orders_none.csv`, which does not exist:
  `AssertFalse("RT42 missing orders", Rpl_RunReplayFiles("rt42m", false))`.

Totals: **318 run** (295 + 23); commit 1 fails 9. Every other test unchanged
(22-field rows still run).

**Commit 2: O1, O2, O3, S1**, core only; the tests file is NOT touched. If a test
fails and you believe its expected value is wrong, STOP and report with
source lines; never change an expected value. Push after each. Do not compile.

## 4. RUNNING (in this order; ask the operator for each step that is his)

- **R0** Pin; copy `ea\*.mq5` and `ea\*.mqh` to
  `D:\mt5-replay\MQL5\Scripts\fxmatrix\` and check the SHA-256 of every file
  (count). THEN STOP: the operator closes the replay terminal if open,
  compiles BOTH replay files in its MetaEditor and replies "compiled".
- **R1** The suite (tag `rt_<commit 2 sha7>`): predicted **318 run, 318
  pass**. Report every `RPL|` and `FAIL |` line. Any FAIL: STOP.
- **R2** Copy the 66 input files of `research/replay/inputs/eurusd_20261008/`
  from `main` at the commit that carries this file (`git show <commit>:<path>`,
  never a checkout of `main`) to `D:\mt5-replay\MQL5\Files\replay\`; check all
  66 against `research/replay/inputs/eurusd_20261008.sha256` from the same
  commit, and w2's SHA-256 (`db2ea941...bd28`).
- **R4** The six runs (`eurusd_d` free, sync; `eurusd_c` free, sync;
  `eurusd_b` free, sync), `swaps.csv`'s SHA-256 checked before each. Report
  every `RPL|` line (`ORDERS`, `LATTICE_BACKFILL`, any `ABORT`) and each
  summary. Every `ORDERS_KEPT` line (O3) whose kept is below seeded: list it
  first.
- **R5** Commit each run's outputs to `research/replay/runs/<tag>_<free|sync>_<commit 2 sha7>/`
  as before. Push. STOP. Do not analyse the outputs.

## 5. NOT IN THIS FIX

The comparison and the miss table (Claude's, `compare.py`). The 2 Oct news
spike, L0 placement and touch-without-fill misses: classified after this run.

## 6. FOR GEMINI (attack the premises; say which fact is missing)

- **GF2-1.** H1 / O1: the replay adopts the real resting book at each init
  instead of letting the engine place its own (no send after 27 of 29
  inits). Is there EA state at a real init that this misses (e.g. the exit
  queue's held exits, the carry ledger, the one-shot add reprice) that would
  make the adopted orders move on the first ticks when the real ones did not?
- **GF2-2.** S1: the EA removes a layer at its OUT_BY (`Grind_HandleSideDealFill`,
  `ea/grind_engine.mqh` 2885-2945), not at its EXT. Is dropping it from the
  TRUE book at the EXT row right for sync, or should sync model the
  exit-filled layer (`exit_position_ticket` set) until the OUT_BY?
- **GF2-3.** H3: the gate's ON time is unknown between the last gate-checked
  entry (17:5x) and the add it did not place (18:36:5x); the inputs take the
  EARLIEST. Sync is indifferent (no gated action in between on any fleet);
  free runs may differ. Right choice?
- **GF2-4.** The comparison matches on the ORDER price: IC's fills carry price
  improvement (D: 237 of 370 deals not at the order price, up to 2.3 pips),
  which the fixed fill rule (GRC-5) does not model. T1 on the deal price is
  reported beside it (B 71%, C 76%, D 71%). Is the order price the right
  reading of s6's "the price"?
- **GF2-5.** What fact is missing?

## 7. GEMINI'S RULINGS AND CLAUDE'S CHECK

Gemini 9 Oct ~18:58Z; checked by Claude against `5bb5fdb` / `32c90be`.
Gemini: "The modifications are sound. Proceed with Cursor execution."

| # | Gemini | Claude's check | Result |
|---|---|---|---|
| GF2-1 | Safe: no EA state desynchronises from adopted orders | Agreed, with two corrections. `Grind_RebuildExitsAtStartSide` (`ea/grind_engine.mqh` 3074-3142) reprices RESTING exits at a rebuild init; the harness does not run it, and it is not what holds exits: the exit queue's ranks do (`ea/grind_exitq.mqh` 43-60, K = 1, H = 0, `ea/grind_config.mqh` 7-8: rank 0 and the deepest rest). The carry ledger is recomputed from the position's swap at each nightly pass (`ea/grind_carry.mqh` 1080-1169), not kept incrementally | ACCEPTED; no change |
| GF2-2 | Drop the layer at the EXT row | Agreed, correcting the mechanism: the replay's close-by completes on a LATER tick (the queue's DONE, base s3.4 step 6), and the sync reset runs only when a real row is applied (core 1300-1340), not before every tick; the re-seed happens at the real EXT row itself | ACCEPTED; no change |
| GF2-3 | The earliest ON time | Agreed. (Actions did happen in the gap: exits, rolls, the short L00's re-centre; none checks the gate) | ACCEPTED; no change |
| GF2-4 | The order price is the measure of T1 | Agreed; the deal-price T1 stays in the report | ACCEPTED |
| GF2-5 | Will the exit queue cancel an adopted exit that is not rank 0 or the deepest? | A fair question. The adopted set IS the queue's own output at the init (the real EA ran the same ranks on the same layers), and the real EA sent nothing after 23 of 29 inits, so the same queue keeps it. A guard costs little: | ACCEPTED; **O3 added** (a print, no test; totals unchanged, 318) |

Line count: 176
