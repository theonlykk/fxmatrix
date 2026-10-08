This message has a line count at the bottom

# CURSOR PROMPT -- REPLAY HARNESS FIX 1 (branch `replay-harness`, on `a280736`)

**Workspace: `D:\fxmatrix`.** Continue on branch `replay-harness` at
`a280736` (your two commits `f0b2445` tests, `a280736` implementation).
Read `prompts/cursor_replay_harness.md` (the base prompt, at `8c5536b`) and
THIS file in full. This file amends the base prompt where it says so and
lists what Claude found reading `a280736` (8 Oct ~03:35Z). Line numbers are
`ea/fxgrind_replay_core.mqh` and `ea/fxgrind_replay_tests.mq5` at
`a280736`. Questions for Gemini are in s7.

Two of the findings come from gaps in the base prompt, not from your work:
s3.5 never said that real ENTRIES and real ROLL levels enter the true book,
and s3.3.3 did not say plainly that the preload is the REAL ticks before
the segment. Both are fixed below (A1, A2).

## 0. RESTATE AND STOP

1. `git log --oneline origin/main..HEAD` must list exactly `a280736` and
   `f0b2445`; `git diff --stat dc74051 HEAD -- ea/` must list only the three
   replay files. Otherwise STOP and report.
2. Restate each of F1-F15 and A1-A3 in ONE line, and list every test of s5
   (changed and new) with its assertion count and F / G tag at commit 1.
3. STOP until the operator replies "go".

## 1. FINDINGS (verified by Claude at `a280736`)

| # | Finding | Where | Kind |
|---|---|---|---|
| F1 | `Rpl_ReplayAppendDeal` writes to `g_rpl_deal_test_records` / `g_rpl_deal_test_count`, which are never declared; the engine reads `g_grind_deal_test_records` / `g_grind_deal_test_count` (`ea/grind_engine.mqh` 2587-2589), so even compiled no fill would ever reach `Grind_ProcessDeal` | core 554-580 | COMPILE + DEFECT |
| F2 | `Rpl_FindOrderByRoleLayer` reads `g_rpl_order_test_records` (never declared) for price and ticket | core 1133-1134 | COMPILE |
| F3 | `const MqlDateTime dt;` then `TimeToStruct(..., dt)` (writes a const) | core 685, 949 | COMPILE |
| F4 | `GrindSideState side = (cond) ? g_grind_long : g_grind_short;` copies a struct holding dynamic arrays through a ternary | core 893 | COMPILE (likely) |
| F5 | `Rpl_RunReplayScript` is a stub (`RPL|STUB_RUN`, returns false): no input files read, no segment loop, no output files, no intervals (base s3.2, s3.3, s3.4 step 2, s3.6) | core 1183-1187 | MISSING |
| F6 | `Rpl_PreloadLattice` adds SYNTHETIC ticks (1.09900 / 1.09902 every second for up to 24 h) instead of the real ticks before the segment | core 541-552 | DEFECT (A2) |
| F7 | Sync mode applies only OUT_BY rows; real ENT rows never enter the true book, and no real roll level does (A1) | core 915-940 | DEFECT (spec gap) |
| F8 | `static long last_day` in `Rpl_ProcessOneTick` survives across tests, segments and fleets: the first tick of a segment on another day than the previous segment's last tick applies a rollover | core 947-954 | DEFECT |
| F9 | `GRIND_CARRY_DAY_<magic>` (the carry gate's day, `ea/grind_carry.mqh` 288-319) is never deleted between tests or segments: after the first pass every later segment, fleet or test run on that replay date skips its carry pass | core 251-258 | DEFECT |
| F10 | `Rpl_SafeToRun` compares paths case-sensitively (RT13 expects `d:\MT5-Replay` true) | core 175-186 | DEFECT |
| F11 | Output `deal_type` is BUY for every IN deal and SELL for every OUT_BY; OUT_BY rows always carry layer 0 and role EXT | core 583-610, 795-799 | DEFECT |
| F12 | `Rpl_FillsOnTick` walks the live seam book by index while `Grind_ProcessDeal` can cancel orders inside the loop (`i--` only covers the removed fill), so an order touched on the same tick can be skipped | core 810-844 | DEFECT |
| F13 | The S3 seam check runs before the tick sequence only, not before the `Grind_ProcessDeal` calls in fills and close-by (base s3.1 S3: "before EVERY engine call") | core 810-844, 765-808, 974 | DEFECT |
| F14 | Tests: RT5 asserts L00's rolled exit still rests AFTER tick 5, the tick on which it must fill; RT5 / RT7 count `>= 1` where the prompt says one; RT10 tolerance 0.5 pip (prompt 0.05); RT8's `sync_idx` check runs only `if(Rpl_DealsCount() > 0)` and there are none; RT12 asserts `Rpl_OrderSeamCount() >= 0` (always true); RT3 / RT11 never check deal contents, order or the file header; commit 2 edited the tests file (same value) | tests 196-231 (227), 287, 389, 331, 430, 133-164, 392-420 | TESTS |
| F15 | The loud lattice check (base s3.4 step 9, Claude's design) compares the side's `from_msc` with the OLDEST TICK PRESENT; in a quiet market the first tick after the newest layer's open can come seconds after `from_msc` (= open + 1 s), so a correct preload would abort. The check must compare with the time the harness RETAINS ticks from, not with the oldest tick | core 631-650 | DEFECT (base design) |

## 2. AMENDMENTS TO THE BASE PROMPT

- **A1 (base s3.2 real deals, s3.5 sync):** the real-deals file becomes
  `real_<tag>.csv` with columns `time_ms,kind,side,layer,price,position_id,level`,
  kind one of `ENT` (a real entry fill: opens a true layer `side`,
  `layer`, entry `price`, ticket `position_id`, open time `time_ms`), `EXT`
  (a real exit fill: no change to the true book), `OUT_BY` (removes
  `position_id` from the true book if present), `ROLL` (sets the true VL of
  `position_id` to `level`). Rows in time order. After any row is applied,
  the replay's positions become EXACTLY the true book: every replay layer
  whose ticket is not in the true book is removed with its exit order;
  every true layer missing is seeded (s3.3.3) with its true VL; every true
  layer present gets its VL set to the true VL (or deleted when none). Add
  and L0 orders are kept. (Base s3.5 (c) is dropped: exits of removed
  layers are deleted, and the engine re-places exits for true layers by its
  own rules on the same tick.)
- **A2 (base s3.3.3 preload):** the preload is the REAL ticks of the
  segment's tick file with `max(newest seeded open, from_ms - 86400 s) <=
  time < from_ms`. `Rpl_RunTicks` takes ticks starting before `from_ms`:
  those are used for the preload only, never processed. Nothing synthetic.
- **A3 (base s3.4 step 1):** the rollover detector is per segment: the
  first processed tick of a segment never applies a rollover; after it, a
  change of server date applies one for the new date.

## 3. FIXES (commit 2)

| # | Fix |
|---|---|
| X1 | F1: `Rpl_ReplayAppendDeal` appends to `g_grind_deal_test_records` and increments `g_grind_deal_test_count` (the suite's `Grind_TestAppendDeal` pattern, `ea/fxgrind_tests.mq5` 2425-2450); remove the `g_rpl_deal_test_*` names |
| X2 | F2: read `g_grind_order_test_records[i].price` / `.ticket` |
| X3 | F3: `MqlDateTime dt;` (not const) in both places |
| X4 | F4: no struct copy; search `g_grind_long` or `g_grind_short` directly by side |
| X5 | F5: implement `Rpl_RunReplayFiles(tag, sync)` (rename the stub; `fxgrind_replay.mq5` calls it): read `run_<tag>.csv`, `swaps.csv`, `intervals_<tag>.csv` (may be empty), and per segment its seed and tick files (base s3.2, A1); for each segment: `Rpl_ResetAll`, `Rpl_ConfigureEngine`, seed, `Rpl_RunTicks` over the ticks from `from_ms - 86400 s` to `to_ms` (A2); interval flags at each tick (base s3.4 step 2); write `out_<tag>_deals.csv`, `out_<tag>_events.csv`, `out_<tag>_book.csv` (headers exactly as base s3.6) and `out_<tag>_summary.txt`; return false and print `RPL|ABORT|<reason>` on any missing or unreadable file. A tick file is read ONCE per run and shared by segments that name it |
| X6 | F6, A2: preload from the real ticks; delete the synthetic preload |
| X7 | F7, A1: true book from ENT / OUT_BY / ROLL rows; the reset of A1 |
| X8 | F8, A3: the last-day value is a global reset by `Rpl_ResetAll` and set (without a rollover) by a segment's first processed tick |
| X9 | F9: `Rpl_ClearCarryGvs` also deletes `GRIND_CARRY_DAY_` |
| X10 | F10: compare the normalised paths in lower case |
| X11 | F11: keep each position's side, layer and role (from its ENT / EXT comment) in its meta; IN rows take `deal_type` from the order type (BUY_LIMIT -> BUY, SELL_LIMIT -> SELL); each OUT_BY row carries its own position's layer and role, and `deal_type` = the closing direction (a long position closes SELL, a short one BUY) |
| X12 | F12: at each tick first COLLECT the tickets of orders placed before the tick and touched by its prices, in placement order; then process them one by one, skipping any that is no longer in the seam book |
| X13 | F13: `Rpl_CheckSeams()` before every `Grind_ProcessDeal`, `Grind_ProcessCloseByQueues`, `Grind_LatticeOnTick`, `Grind_OnTickEngine` and `Grind_CarryOnTimerStep` call; abort `SEAMS` otherwise |
| X15 | F15: keep `g_rpl_retained_from_ms`: set to the preload start (A2) at a seed, else to the segment's first processed tick; raised to the prune cutoff at each prune. `Rpl_LatticeHistoryCheck` aborts only if `from_msc < g_rpl_retained_from_ms` |
| X14 | Accessor `int Rpl_CurrentSyncIdx()`; `bool Rpl_HasPosition(const ulong ticket)` (in a side's layers) |

## 4. COMMITS

1. **Tests first** (s5), against `a280736` with ONLY the compile fixes X1-X4
   applied (so the suite can compile and the failures are behavioural).
   Commit message: each new or changed test, F / G, and the predicted count
   of failing assertions at this commit.
2. **X5-X15.** No test changes. If a test fails and you believe its expected
   value is wrong, STOP and report with source lines; never change one.

Push the branch after each. Do not compile (the operator compiles in the
replay terminal's MetaEditor when it exists; until then the operator may
compile the two scripts on the desktop for syntax only, NOT run them).

## 5. TESTS (changes to `ea/fxgrind_replay_tests.mq5`; values hand-derived from base s6)

- **RT3** (changed): after the 4 ticks, deal rows exactly: row 0 IN BUY ENT
  L layer 0 price 1.09981 time t2; row 1 IN SELL EXT L layer 0 price 1.10081
  time t3; rows 2-3 OUT_BY time t3 (one role ENT layer 0, one role EXT
  layer 0, both side L, deal_type SELL for the ENT position and BUY for the
  EXT position). (F)
- **RT3b** (new): ticks 0-2 only: EXT L00 rests at 1.10081 and ENT L01 at
  1.09911; long depth 1. (G at commit 1 if it passes; report)
- **RT5** (changed into two): **RT5a** ticks 0-4: `ROLL_ACCEPTED` count == 1;
  its event json contains `"level":1.09841` and `"target":1.09941`; L00 EXT
  rests at 1.09941; long depth 2; no deal at t4. **RT5b** ticks 0-5: a deal
  IN SELL EXT L layer 0 price 1.09941 time t5; one scalp event containing
  `"rolled":true`, `1.09981` and `1.09941`; NO L00 EXT order; long depth 1. (F)
- **RT7** (changed): `ROLL_DEFERRED` count == 1. (F or G: report)
- **RT8** (changed, A1 format): one real row `OUT_BY` for 7003 at t2 - 1 ms.
  Assert `Rpl_HasPosition(7003)` false and long depth 2 after tick 2;
  `Rpl_CurrentSyncIdx() == 0`; L02 EXT gone; EXT L01 1.10011; add L02 at
  1.09841 after tick 3. (F)
- **RT8b** (new, A1): seed L00 1.09981 (7001), L01 1.09911 (7002), cap 8,
  sync; real rows at t1 - 1 ms: `ENT,L,2,1.09841,7003,`, `ROLL,L,0,,7001,1.09771`.
  Ticks 0-2 at bid 1.09900 / ask 1.09902. After tick 2: long depth 3 with
  tickets 7001, 7002, 7003 and no other; `Grind_VLGet(7001)` = 1.09771;
  `Rpl_CurrentSyncIdx() == 1`. (F)
- **RT10** (changed): tolerance 0.05 pip. (F)
- **RT11** (changed): through the file writer used by X5 (tag `rt11`),
  read back `out_rt11_deals.csv`: first line equals the base s3.6 deals
  header; 4 data rows with non-decreasing `time_ms`; row 0 `deal_type` BUY
  role ENT, row 1 SELL EXT. (F)
- **RT12** (changed): drop `Rpl_OrderSeamCount() >= 0`; keep the API delta
  == 0 and close-by sends > 0. (G)
- **RT15** (new, A3): swaps rows `2026.10.06,-8.111,1.409,1` and
  `2026.10.07,-8.067,1.364,1`. Segment 1: ticks on 2026.10.07 10:00:00 and
  10:00:01. `Rpl_ResetAll`; segment 2: seed long 6101 (swap 0) and ticks
  2026.10.06 10:00:00, 23:59:59, 2026.10.07 00:00:00. After segment 2's
  first tick the swap of 6101 is 0; after its last tick it is
  `-8.067 * 1 * tick_value * 0.01` (the 10.07 night only). (F)
- **RT16** (new, F9): run RT10's segment twice in a row (with
  `Rpl_ResetAll` between); both runs give the RT10 exit within 0.05 pip. (F)
- **RT17** (new, A2): cap 2; seed long L00 1.09981 and L01 1.09911, both
  opened at `T0 - 3600 s`; the tick array holds a tick at `T0 - 3600 s`
  and one at `T0 - 60 s` with bid 1.09839 / ask 1.09841 (both before
  `from_ms` = T0), then ticks at T0 and T0 + 1 s, all others at bid
  1.09900 / ask 1.09902. After tick T0: exactly one
  `ROLL_ACCEPTED` with `"level":1.09841` (the dip is in the preload; the
  lattice probes min(market, extreme)). (F)
- **RT18** (new, X12): seed nothing; place via the engine flow of RT3 to
  tick 2, then a tick that touches BOTH the resting EXT 1.10081 and the
  short L0 1.10151 (bid 1.10151, ask 1.10153): both fill on that tick (two
  IN deals at the same time; the short `S00 ENT` first, placed at tick 1,
  then the `L00 EXT`, placed at tick 2: placement order). (F)
- **RT20** (new, F15): as RT17 but the first preload tick is at
  `T0 - 3597 s` (3 s after the newest open; no tick in between) and no dip:
  NO `RPL|ABORT`. (F)
- **RT14** (unchanged): still aborts (no preload: retention starts at the
  first processed tick, after `from_msc`). (G)
- **RT19** (new, X5): the test writes a tiny input set to
  `MQL5\Files\replay\` (tag `rt19`: one segment with RT3's four ticks in a
  tick file, no seed, empty intervals, one swaps row) and calls
  `Rpl_RunReplayFiles("rt19", false)`: returns true; `out_rt19_deals.csv`
  has the header and 4 rows; `out_rt19_summary.txt` exists. (F)

## 6. NEGATIVE SPACE AND FAILURE MODES

As the base prompt s7 and s8, plus: do not touch `ea/fxgrind_replay.mq5`
beyond the call rename of X5; do not add inputs to it; do not change any
expected value of an unchanged test. STOP if a fix needs an engine symbol
not in base s1, or if a test you add passes at commit 1 without a G tag.

## 7. FOR GEMINI (attack the premises; say which fact is missing)

- **GHF-1.** A1: after each real deal the replay's positions become exactly
  the true book, including true VLs from real `ROLL` rows, and exits of
  removed replay layers are deleted (the engine re-places exits for true
  layers on the same tick). Is anything lost by dropping base s3.5 (c)?
- **GHF-2.** A2: the preload is the real ticks back to the newest seeded
  layer's open, at most 24 h. Enough?
- **GHF-2b.** F15 / X15: the loud check compares with the harness's
  retention start, not the oldest tick present. Any case it now misses?
- **GHF-3.** F12 / X12: same-tick fills collected first, then processed in
  placement order, skipping any cancelled in between. Right rule?
- **GHF-4.** What fact is missing?

Line count: 187
