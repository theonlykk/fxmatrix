This message has a line count at the bottom

# CURSOR PROMPT -- REPLAY HARNESS FIX 4 (branch `replay-harness`, on `da81664`)

**Workspace: `D:\fxmatrix`.** Continue on branch `replay-harness` at
`da81664` (`6e63d50` fix-3 core, `da81664` the first RT run's log). Read
`prompts/cursor_replay_harness.md`, `..._fix1.md`, `..._fix2.md`,
`..._fix3.md` and THIS file. Line numbers are `ea/fxgrind_replay_core.mqh`
and `ea/fxgrind_replay_tests.mq5` at `6e63d50`. Questions for Gemini in s6; his rulings and Claude's check in s7.

**The first RT run (8 Oct ~18:00Z, `D:\mt5-replay`, investor login,
`research/replay/runs/rt_6e63d50/script_log_excerpt.txt`): 259 run, 246
pass, 13 FAIL.** Claude's read of each failure against source and against
our real close-bys is s1. Three are harness defects (H1-H3; H3 found while
reading for H2, not by a failing test), five are test
defects (T1-T5), and one (RT10, 3 assertions) is not yet explained: fix 4
adds diagnostics for it (D1, D2) and changes nothing in the carry path.
H1, H2, H3, T2 and T4 are Claude's spec or audit errors, not your work.

## 0. RESTATE AND STOP

1. `git log --oneline origin/main..HEAD` starts `da81664`, `6e63d50`,
   `3a4b699`; otherwise STOP.
2. Restate H1-H3, T1-T5, D1-D2 in one line each; for every changed or new
   test give its EXACT assertion count and how many FAIL at commit 1; and
   the suite total (run) after commit 1.
3. STOP until "go".

## 1. FINDINGS (verified at `6e63d50` and in the archive)

| # | Failure(s) | Cause | Kind |
|---|---|---|---|
| H1 | RT5b `exit px` (x2: RT12 re-runs RT5b) | The harness writes each OUT_BY deal at its OWN position's open price, profit half on each leg, swap HALF of each position's (core 940-951; base s3.4 step 6 said "price = each position's open price", Claude's error). Real MT5 close-by, measured on every EURUSD pair of B, C and D since 1 Oct (148 + 166 + 175 = 489 of 489): each OUT_BY deal carries the OPPOSITE position's open price; the WHOLE pair profit is on the leg of the position the close-by closes (the task's first ticket, `t1`, the ENT position), 0 on the other; each leg carries its OWN position's full swap (non-zero swap only ever on the ENT leg: 100 of 100). The EA takes the scalp's `exit_price` and P&L from the ENT position's OUT_BY deal (`ea/grind_engine.mqh` 2884-2922), so the harness reports every scalp's exit at its entry and half its P&L | HARNESS |
| H2 | RT14 `lattice abort`, `abort reason` | The loud lattice check (base s3.4 step 9; fix 1 X15) reads `g_grind_vl_from_msc_*` AFTER `Grind_LatticeOnTick` returned, but the same call that starts tracking also folds the copied ticks and moves `from_msc` past the last one (`ea/grind_engine.mqh` 825-856). The check therefore sees "now + 1 ms" and never fires. Tracking also starts a second way: while the roll gate holds, `Grind_LatticeRollGateRestartExtreme` sets tracking true from the current tick with the extreme 0.0 (1208-1220, called from 1278-1279), which needs no history | HARNESS (Claude's design) |
| H3 | none yet (no test covers it) | **The EA's `OnInit` calls `Grind_LatticeRollGateInitRestart(InpRollGateOpposite)` (`ea/fxgrind.mq5` 365; `ea/grind_engine.mqh` 1223-1231): with the gate on (>= 0) BOTH sides' tracking restarts at the init's tick, so a crossing between a side's newest open and the init never rolls.** The harness never calls it (base s1 A4 missed it, Claude's audit), so every gate-0 segment (from 7 Oct 02:01-02:21Z) would track from the newest open instead, and could roll where the live EA did not | HARNESS (Claude's audit) |
| T1 | RT5b `ext fill deal_type` (x2) | RT5b reads the LAST deal row (tests 292); tick 5 also closes L00 by close-by, so the last row is the EXT position's OUT_BY (closing BUY). Fix 3's E9 again | TEST |
| T2 | (after H1) RT3 `row2 price`, `row3 price` | Fix 1's RT3 (Claude) gives the OUT_BY rows their own open prices (tests 165-166); with H1 row 2 (the ENT position's OUT_BY) is 1.10081 and row 3 (the EXT position's) 1.09981 | TEST (Claude's spec) |
| T3 | RT12 `closeby sends` | Each called test begins with `Rpl_ResetAll`, which zeroes `g_grind_closeby_test_send_calls`; RT8 runs last and sends no close-by (tests 549-553) | TEST |
| T4 | RT21 `one gap` | The 10:02:00 -> 23:55:00 jump is itself a 13.9 h weekday gap whose midpoint is outside 23:50-00:15, so the harness rightly reports two (log: `RPL|GAP|...830000|90`, `RPL|GAP|...920000|49980`). Fix 1's RT21 (Claude) put two cases in one segment | TEST (Claude's spec) |
| T5 | RT23 `seg1 present`, `seg2 present` | Neither segment writes a deal or event row (segment 1: L0 placement; segment 2 starts flat and fills nothing by its end), so no line starts `1,` or `2,`. The summary assertions (`sum seg1`, `sum seg2`) already prove both segments ran | TEST |
| D | RT10 `exit shifted` (x3: RT10, RT16 twice) | Not explained by reading. Checked and consistent with RT10's expected value: the pass uses TOMORROW's multiplier (`ea/grind_carry.mqh` 1114; Tue 6 Oct -> Wed = 3), ledger -0.08 -> 0.8 pips, pending from the live `SYMBOL_SWAP_LONG`, shifted exit = formula - direction x accrued (385-391). The log prints only the assertion name, so the got value is unknown | NEEDS DATA |

## 2. FIXES (commit 2, core only)

| # | Fix |
|---|---|
| H1 | In `Rpl_ProcessCloseByDone` (core 897-975), for each completed task (`t1` = the position the EA closes, `t2` = the one it closes by): deal `d1` (position `t1`) price = `t2`'s open price (`ext.entry`), profit = the whole pair profit (`profit`, not halved), swap = `t1`'s swap in full (`ent.swap`); deal `d2` (position `t2`) price = `t1`'s open price (`ent.entry`), profit 0, swap = `t2`'s swap in full (`ext.swap`). The deals output rows (`Rpl_WriteDealOutput`, 953-958) carry the same two prices. Nothing else in the function changes (deal types, order ticket, removal, the `Grind_ProcessDeal` calls and their order) |
| H2 | `Rpl_LatticeHistoryCheck(is_long)` (called exactly where it is now, core 1287-1290) checks only when the side's extreme is NON-zero after the call (`g_grind_vl_extreme_long` / `_short`): the normal start folded ticks; an extreme of 0.0 means the gate restart ran (H2 row, s1) or no stored tick was at or after the start, and neither needs history. It then computes the start the EA used: `start_ms = max((newest open second of that side's layers + 1) * 1000, (now_s - GRIND_VL_CATCHUP_MAX_SEC) * 1000)` (`ea/grind_engine.mqh` 826-843; use the EA's macro from `ea/grind_config.mqh` 20, never the literal 86400, so a change to the cap reaches the check; GH4-2), the newest open being the largest `open_ms / 1000` among that side's layers' position metas and `now_s` the tick's second; abort `LATTICE_HISTORY` (printing `start_ms` and `g_rpl_retained_from_ms`) when `g_rpl_retained_from_ms > 0 && start_ms < g_rpl_retained_from_ms` |
| H3 | On a segment's FIRST processed tick, after the market seeds (core 1251-1256) and BEFORE `Rpl_FillsOnTick` (1261; the live EA runs it in `OnInit`, before any tick), call `Grind_LatticeRollGateInitRestart(g_rpl_cfg.gate)` once (it returns at once for gate -1; it needs `Grind_MarketTimeMsc() > 0`, which the seed provides). Every segment starts at an init (plan s3), seeded or flat |

## 3. COMMITS AND TEST CHANGES

1. **Tests and diagnostics** (exactly these; nothing else in the tests
   file). The message gives, per changed or new test, its EXACT assertion
   count and how many FAIL at this commit, and the suite total (run).
   - **D1** `AssertNear` (30-33): on failure, before `AssertTrue`, also
     `Print("FAIL-DETAIL | ", name, " | got=", DoubleToString(got, 8),
     " | expected=", DoubleToString(expected, 8), " | tol=",
     DoubleToString(tol, 8));`. No change to counts.
   - **D2** `Test_RT10_ExitPrice` (after `Rpl_RunTicks`, 466): print every
     event row whose `code` starts `CARRY_` as
     `Print("RT10-EVENT | ", ev.code, " | ", ev.json);` (the
     `Rpl_EventsCount` / `Rpl_GetEventRow` loop of RT5a, 241-249), then
     `Print("RT10-ORDER | found=", ..., " | price=", DoubleToString(p, 8));`
     with the result of `Rpl_FindOrderByRoleLayer` kept in a bool. No new
     assertion.
   - **T2** RT3 (165-166): row 2 price `1.09981` -> `1.10081`, row 3 price
     `1.10081` -> `1.09981`. After the `rolled false` line (168) add
     `AssertContains("RT3 scalp exit px", Rpl_ScalpEventPeek(), "\"exit_price\":1.10081");`
     and `AssertContains("RT3 scalp pnl", Rpl_ScalpEventPeek(), "\"gross_pnl\":1.00");`
     (10 pips x 0.01 lot at IC's EURUSD tick value 1.0, as RT9).
   - **T1** RT5b (292): before it add
     `AssertTrue("RT5b deals count 5", Rpl_DealsCount() == 5);` and change
     the row index `Rpl_DealsCount() - 1` to `2` (rows: 0 IN L00 t2, 1 IN
     L01 t3, 2 IN EXT L00 t5, 3-4 OUT_BY t5).
   - **T3** RT12 (548-553): after `Test_RT3_Scalp();` add
     `const int s3 = g_grind_closeby_test_send_calls;`, after
     `Test_RT5b_RollScalp();` add `const int s5 = g_grind_closeby_test_send_calls;`;
     replace `AssertTrue("RT12 closeby sends", ...)` with
     `AssertTrue("RT12 closeby sends RT3", s3 > 0);` and
     `AssertTrue("RT12 closeby sends RT5b", s5 > 0);`.
   - **T4** RT21 (1074-1103): part A = ticks 10:00:00, 10:00:30, 10:02:00
     only (`cfg.to_ms` = 10:02:00 + 1 s); its four assertions unchanged.
     Part B: `Rpl_ResetAll();`, a new config with `from_ms` 23:55:00 and
     `to_ms` 23:57:00 + 1 s (2026.10.06), ticks 23:55:00 and 23:57:00 (a
     120 s gap inside 23:50-00:15): `AssertTrue("RT21 window gap not reported", Rpl_GapReportCount() == 0);`.
   - **T5** RT23 (849-850): delete the two `seg1 present` / `seg2 present`
     assertions (and the then unused `ev` read if the compiler warns).
   - **RT33** (new; H3): RT17 exactly (seed, preload with the T0 - 60 s dip,
     ticks T0 and T0 + 1 s) but `cfg.gate = 0` (no short layer, so the gate
     never holds): after the run `AssertTrue("RT33 init restart no roll", Rpl_CountEventsWithCode("ROLL_ACCEPTED") == 0);`
     (the live EA restarts tracking at the init and ignores the pre-init
     dip; RT17, gate -1, rolls on it). Register it after RT31b.
2. **H1-H3**, core only. The tests file is NOT touched. If a test cannot
   pass as written, STOP and report.

**Predicted (Claude; to be confirmed in your restate):** totals count RT3
and RT5b twice (RT12 calls them). Run after commit 1 = 259 + 4 (RT3 +2,
twice) + 2 (RT5b +1, twice) + 1 (RT12) + 1 (RT21) - 2 (RT23) + 1 (RT33) =
**266**. FAIL at commit 1 = RT3 4 (row2 price, row3 price, exit px, pnl)
x 2 + RT5b `exit px` x 2 + RT14 2 + RT10 3 + RT33 1 = **16**. After commit
2: **266 run, 263 pass** (RT10's 3 remain until D2's output is read), or
266 if RT10 passes.

Push after each commit. Do not compile; the operator compiles both replay
files on the desktop for syntax, then in `D:\mt5-replay`; then you run the
suite as before (base s5 steps 0-4, tag `rt_<commit 2 sha7>`), reporting
every `FAIL |`, `FAIL-DETAIL |`, `RT10-EVENT |` and `RT10-ORDER |` line
verbatim.

## 4. NEGATIVE SPACE

As before: no new inputs; no change to any expected value other than
T2's two prices; nothing outside H1-H3 in commit 2; no change to the carry
path (RT10 waits for D2's data); anything you find you must change is
named in the message with its reason.

## 5. EVIDENCE (Claude, from `--export-archive` of `GRIND_EURUSD_OPTB` /
`OPTC` / `OPTD`, 8 Oct ~16:35Z; fill_logs since 1 Oct)

Every OUT_BY pair (two OUT_BY rows with one order ticket, both positions'
IN rows present): B 148, C 166, D 175. In all 489: the ENT position's
OUT_BY price = the EXT position's open price and vice versa; profit
non-zero on the ENT leg and 0.00 on the EXT leg (e.g. ENT BUY 1.13092 ->
OUT_BY 1.13182 profit 0.90; EXT SELL 1.13182 -> OUT_BY 1.13092 profit
0.00); every non-zero swap (B 32, C 35, D 33) on the ENT leg.

## 6. FOR GEMINI (attack the premises; say which fact is missing)

- **GH4-1.** H1 rests on our own 489 close-bys, not on documentation: is
  "whole profit on the closed position's leg, each leg its own swap" the
  rule, or an artefact of IC's server? Does any EA path read the OUT_BY
  deal's PRICE or PROFIT other than the scalp event (`ea/grind_engine.mqh`
  2884-2922)?
- **GH4-2.** H2 recomputes the EA's tracking start in the harness and
  tells the two start paths apart by the extreme (non-zero after a fold,
  0.0 after the gate restart or an empty read). Is that discriminator
  sound against `ea/grind_engine.mqh` 825-891 and 1208-1279, and is
  duplicating the start formula acceptable for a check whose only output
  is an abort?
- **GH4-2b.** H3 calls the init restart on each segment's first tick, not
  "at OnInit" (the harness has no OnInit; the live EA runs it before its
  first OnTick, on the live tick time). Any difference that matters?
- **GH4-3.** What fact is missing?

## 7. GEMINI'S RULINGS (8 OCT ~18:20Z) AND CLAUDE'S CHECK

- **GH4-1 ACCEPTED (H1).** His premise (the EA "expects" this structure)
  is not the evidence; the evidence is the 489 measured pairs. Claude
  answered the part he did not: no other EA path acts on an OUT_BY deal's
  price or profit. The scalp event (`ea/grind_engine.mqh` 2884-2922) is the
  only decision-side reader; 3290 is the fill-log archive (telemetry);
  1634 / 1689 read BALANCE deals and the day's history for the breaker (off
  in the harness, live history not seamed).
- **GH4-2 ACCEPTED, his maintenance point taken:** H2 now uses the EA's
  `GRIND_VL_CATCHUP_MAX_SEC` (the harness includes the EA headers) instead
  of 86400, so the cap cannot decouple. The newest-open half stays a
  duplicate of `ea/grind_engine.mqh` 826-843, recorded here as a
  maintenance liability: the pin (base s5 step 0) covers `fxgrind.mq5`
  only, so a change to the lattice start in `grind_engine.mqh` must be
  re-checked against H2 by hand.
- **GH4-2b ACCEPTED** (H3 on each segment's first tick, before the fills).
- **GH4-3 REJECTED, measured.** Close-by deal order cannot matter: the
  EA's OUT_BY branch acts only on a deal whose position is a layer's ENT
  position and returns after its layer loop (`ea/grind_engine.mqh`
  2888-2944), so the EXT leg's deal is a no-op in either order. And the
  broker numbers the ENT leg first in 489 of 489 real pairs (B 148, C
  166, D 175, lower `deal_ticket` = ENT), the harness's order (`d1`
  before `d2`, core 945-970).

Line count: 171
