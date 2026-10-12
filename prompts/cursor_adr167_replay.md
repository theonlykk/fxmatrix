This message has a line count at the bottom

# CURSOR PROMPT -- ADR-167 IN THE REPLAY HARNESS ONLY: THE LIGHT SIDE'S ADD BY DEPTH GAP (EXPERIMENT BUILD)

**Workspace: `D:\fxmatrix`.** Start a NEW Cursor chat. Create branch
`replay-adr167` from `origin/replay-harness` at `efada62`. Read
`docs/architecture/ADR-167-light-side-add-by-depth-gap.md` (sections 1-3 and
11) from `origin/main` at the commit that carries THIS file, and this prompt
in full. Written by Claude 12 Oct ~03:40Z from source at `efada62`
(`ea/grind_engine.mqh` and `ea/grind_pure.mqh` there are identical to EA code
`5bb5fdb`). Line numbers are that code.

**What this is.** The operator (12 Oct ~03:00Z): "I want to see the harness
results if we implement the layer equalizing logic on the data we download.
we have 8 weeks of data, let's see if it made a difference." This prompt
builds the rule into the ENGINE and lets the REPLAY HARNESS switch it on per
segment from the run file. It is an experiment build on its own branch:
- it is NOT the EA build (no EA input, no heartbeat field, no DeepSeek
  audit, no merge, no deploy: that is a later prompt, after plan 3);
- it must NOT change the frozen harness: branch `replay-harness` and its
  tip `efada62` are not touched, and plan 3's holdout runs are made from
  them (s8).

## AUDIT TRAIL (verified at `efada62`)

| # | Finding | Where | Status |
|---|---|---|---|
| C1 | `Grind_ComputeAddTarget(side, is_long, add_pips)`: next add = anchor -/+ add | `ea/grind_engine.mqh` 2250-2287 | VERIFIED |
| C2 | `Grind_SendNextAddEnt` uses the add twice: the target (2327) and the near-market test (2357) | 2298-2402 | VERIFIED |
| C3 | `Grind_EnsureAddNext` uses the add once itself (the target, 2543) and passes it on to `Grind_ApplyEntryHorizon` (2535) and `Grind_SendNextAddEnt` (2582) | 2483-2583 | VERIFIED |
| C4 | `Grind_ApplyEntryHorizon` uses the add twice itself (`floor_price` 1858, the target 1860) and passes it on to `Grind_SendNextAddEnt` (1895, 1927) | 1833-1945 | VERIFIED |
| C5 | The lattice uses the add for its level and stranded mark (`Grind_LatticeTrySide` 1306, `Grind_LatticeMaybeStranded` 1185, `Grind_LatticeRollDeferredNote` 1246). NOT to be changed (ADR-167 A5: a side at the cap never has a positive gap) | 1172-1388 | VERIFIED |
| C6 | `Grind_SideDepth(side)` = `ArraySize(side.layers)`; the sides are the globals `g_grind_long`, `g_grind_short` | 2015-2018 | VERIFIED |
| C7 | One ENT send per tick (`g_grind_ent_sent_this_tick`, 2350, 2389): with both sides needing an add, the long side's goes first (`Grind_OnTickEngine` 3235-3238) and the short side's on the NEXT tick | 3183-3239 | VERIFIED |
| C8 | `Grind_PriceWithinDeadband` is a strict `<`: a resting add is modified when its target has moved by the deadband or more | `ea/grind_pure.mqh` 164-171; engine 2568-2573 | VERIFIED |
| C9 | A fill appends the layer BEFORE the fill-time add is placed | engine 2972, 2978 | VERIFIED |
| C10 | `RplSegmentConfig` (22 members), `Rpl_SegmentConfigDefaults` (add 7 / 7, exit 10 / 10, width 2 / 15, cap 8, deadband 2, gate -1, reroll off, carry off, fill-time place on) | `ea/fxgrind_replay_core.mqh` 40-64, 1548-1573 | VERIFIED |
| C11 | A run row is read by POSITION: `fields[0]`..`[19]`, `[20]` seed_file, `[21]` ticks_file, `[22]` orders_file (optional); rows with fewer than 22 fields abort `BAD_RUN_ROW`; then `Rpl_ResetAll()`, `g_rpl_cfg = cfg`, `Rpl_ConfigureEngine(cfg)` | core 3495-3549 | VERIFIED |
| C12 | `Rpl_ConfigureEngine(cfg)` sets the engine's globals for a segment (`Grind_EngineConfigureAdr152` at 1604); `Rpl_ResetAll()` starts at 1325 | core 1596-1612, 1325 | VERIFIED |
| C13 | Test helpers: `Rpl_ResetAll`, `Rpl_DefaultConfig`, `Rpl_ConfigureEngine`, `Rpl_SeedLayer(side, layer, entry, open_ms, ticket, vl, swap, volume)`, `Rpl_SeedOrder(side, layer, role, price, ticket, type)`, `Rpl_RunTicks(ticks, n, cfg)`, `Rpl_GetOrderLogRow(i, row)` (`row.action`, `row.ticket`), `Rpl_RunReplayFiles(tag, sync)`, `Rpl_ReadWholeFile`; `RPL_T0`, `RplMs`, `RPL_SPREAD` 0.00002 | core 1775, 1831, 2789, 1528; `ea/fxgrind_replay_tests.mq5` 49-61 | VERIFIED |
| C14 | RT40 is the model: short L0 at 1.10500 (ticket 5201), its EXT at 1.10400 (5211), a short add seeded at 1.10570 (5212) fills at bid 1.10570 | tests 1667-1690 | VERIFIED |
| C15 | Suite at `252aae5` / `efada62`: 461 / 461; the tests are called from the list ending `Test_RT63_EventsAtHandlerStart();` (2564) | tests; BOOT s6 | VERIFIED (operator's run) |
| C17 | A seeded segment starts with a ONE-SHOT add re-price: `Rpl_RunTicks` sets `g_grind_start_add_reprice_long / _short` when seeded (as the EA's init does, `fxgrind.mq5` 291-292), and the first `Grind_EnsureAddNext` then uses a 0.05-pip deadband (engine 2561-2566). So deadband tests call `Grind_EnsureAddNext` directly with the flag cleared | core 2800-2805; engine 2561-2573 | VERIFIED |
| C16 | The committed runs at `145f092`: `research/replay/runs/eurusd_{b,c,d}_{free,sync}_145f092_t0/` and `..._145f092/` (deals, orders, events, book, summary; no `timing.csv`) | `origin/replay-harness` | VERIFIED |

## 0. RESTATE AND STOP (do this first, then wait)

1. Run `git diff --stat efada62 HEAD -- ea tools`. It must be EMPTY. If
   not, STOP and report it.
2. Restate each change in s2 in ONE line each, quoting this prompt's words,
   and list every test in s4 with its assertion count and its F / G tags.
3. Then STOP. Do not edit anything until the operator replies "go".

## 1. THE RULE

For a side with at least one layer:

    gap = (opposite side's layers) - (this side's layers)
    effective add = configured add x fraction(gap)

`fraction(gap)` is 1 for gap <= 0 or an empty table; otherwise entry
`min(gap, n)` of the table (entry 1 is gap 1; the last entry holds for
larger gaps). An empty table = OFF: every result of the engine and the
harness must then be identical to `efada62`.

## 2. THE CHANGES

**P (pure, `ea/grind_pure.mqh`):**

    bool   Grind_LightAddParse(const string table, double &out[]);
    double Grind_LightAddFraction(const double &fr[], const int gap);

- `Grind_LightAddParse`: `""` (after trimming spaces) -> `out` size 0, true.
  Otherwise `;` and `,` are both separators; 1 to 16 entries; each entry a
  plain decimal number (digits and at most one `.`), in (0, 1]; no entry
  larger than the one before it. Anything else: `out` size 0, false.
- `Grind_LightAddFraction`: 1.0 when `ArraySize(fr) == 0` or `gap <= 0`;
  else `fr[min(gap, ArraySize(fr)) - 1]`.

**E (engine, `ea/grind_engine.mqh`):**

    double g_grind_light_add_frac[];
    bool   Grind_LightAddConfigure(const string table);
    double Grind_LightAddPips(const GrindSideState &side, const bool is_long,
                              const double add_pips);

- `Grind_LightAddConfigure`: parses into the global; on failure the global
  is left EMPTY (off) and it returns false.
- `Grind_LightAddPips`: `own = Grind_SideDepth(side)`; if `own <= 0` return
  `add_pips`; `opp = Grind_SideDepth(is_long ? g_grind_short : g_grind_long)`;
  return `add_pips * Grind_LightAddFraction(g_grind_light_add_frac, opp - own)`.
- In EXACTLY three functions, compute once, after the early returns that
  need no add, `const double eff_add = Grind_LightAddPips(side, is_long, add_pips);`
  and use `eff_add` where the function ITSELF uses the add (C2-C4):
  - `Grind_SendNextAddEnt`: the target (2327) and the near-market test
    (2357);
  - `Grind_EnsureAddNext`: the target (2543);
  - `Grind_ApplyEntryHorizon`: `floor_price` (1858) and the target (1860).
- Every call that PASSES the add on (1895, 1927, 2423, 2426, 2454, 2458,
  2472, 2476, 2535, 2582 and all others) keeps passing `add_pips`, the
  configured value: the callee scales it once.

**H (harness, `ea/fxgrind_replay_core.mqh`):**

- `RplSegmentConfig` gains `string light_add;` (default `""`).
- The run row: `cfg.light_add = (ArraySize(fields) > 23) ? fields[23] : "";`
  (an OPTIONAL 24th column `light_add`; in a file the table is written with
  `;`). If `Grind_LightAddParse` rejects it: `Print("RPL|ABORT|BAD_LIGHT_ADD|seg_line=", seg_line);`
  and the same clean-up and `return false` as `BAD_RUN_ROW`, BEFORE
  `Rpl_ResetAll()`.
- `Rpl_ConfigureEngine(cfg)` calls `Grind_LightAddConfigure(cfg.light_add)`;
  `Rpl_ResetAll()` calls `Grind_LightAddConfigure("")`.
- When a segment's table is not empty: one `Print("RPL|LIGHT_ADD|seg=", cfg.seg_id, "|", cfg.light_add);`
  at its start. NO new row and NO new field in any output file.

Nothing else. `ea/fxgrind.mq5` is not touched (the EA gets its input in the
later build). `RPL_MIRRORS_EA` stays `"5bb5fdb"`.

## 3. COMMITS (branch `replay-adr167`; never `replay-harness`, never `main`)

1. **Tests first:** s4's tests in `ea/fxgrind_replay_tests.mq5` (called after
   `Test_RT63_EventsAtHandlerStart();`), with STUBS so that it compiles:
   `Grind_LightAddParse` sets `out` size 0 and returns false;
   `Grind_LightAddFraction` returns 1.0; `Grind_LightAddConfigure` returns
   false; `Grind_LightAddPips` returns `add_pips`; the struct member exists
   and is ignored (no row parsing yet). Predicted when the operator has
   compiled: **493 run, 478 pass, 15 FAIL** (exactly the F assertions of
   s4). Do NOT run the suite yourself before the operator says "compiled"
   (s5).
2. P (the two pure functions).
3. E (the globals, the two engine functions, the three call-site changes).
4. H (the harness column, configure, reset, print). Predicted: **493 / 493**.

## 4. TESTS (`ea/fxgrind_replay_tests.mq5`; F = fails at commit 1, G = guard, passes at both)

Expected values are derived by hand below. Never change an expected value
to match an output: if a G fails or an F passes at commit 1, STOP and
report it.

Table B = `"1;1;0.9;0.8;0.7;0.6;0.5"`. Prices: 1 pip = 0.00010.

Fixture `Rt167_Book(table)` (used by RT66-RT69): `Rpl_ResetAll()`; default
config with `cfg.light_add = table` and `cfg.to_ms = RplMs(RPL_T0, 10)`;
`Rpl_ConfigureEngine(cfg)`; then seed
- short: `Rpl_SeedLayer("S", 0, 1.10500, RplMs(RPL_T0, -3600), 5201UL, 0.0, 0.0, RPL_LOTS_DEFAULT)`
  and `Rpl_SeedOrder("S", 0, "EXT", 1.10400, 5211UL, ORDER_TYPE_BUY_LIMIT)`;
- long, six layers `i = 0..5`: entry `1.10480 - i * 0.00070` (1.10480,
  1.10410, 1.10340, 1.10270, 1.10200, 1.10130), tickets `5301UL + i`, same
  open time, no seeded orders.
So short depth 1, long depth 6: the short side's gap is 5, the long side's
-5. The long exits (entry + 10 pips, nearest 1.10580) and the long add
(1.10130 - 7 pips = 1.10060) stay clear of every test price. Ticks are
`bid`, `ask = bid + RPL_SPREAD`, one second apart from `RPL_T0`.

Fixture `Rt167_Direct(table)` (RT68, RT69; C17): `Rt167_Book(table)`, then
`Rpl_SeedOrder("S", 1, "ENT", 1.10570, 5212UL, ORDER_TYPE_SELL_LIMIT)`,
`g_grind_start_add_reprice_short = false`,
`Grind_MarketTestSeed(1.10500, 1.10502, 0)`, `m0 = g_grind_order_test_modify_calls`,
then TWICE `Grind_EnsureAddNext(g_grind_short, false, RPL_MAGIC_DEFAULT, RPL_SLOT_DEFAULT, 7.0, 2.0, 8, RPL_LOTS_DEFAULT)`.

| Test | Assertions (tag) |
|---|---|
| **RT64 parse and fraction** (15) | a `Parse("")` true and size 0 (F). b `Parse(B)` true and size 7 (F). c `Parse("0.5")` true and size 1 (F). d `Parse("1,1,1,0.5")` true and size 4 (F). e `Parse("0.5;0.6")` false (G). f `Parse("0;0.5")` false (G). g `Parse("1.1")` false (G). h `Parse("abc")` false (G). With `fr` = the result of b: i `Fraction(fr, 0)` = 1.0 (G). j `Fraction(fr, -3)` = 1.0 (G). k `Fraction(fr, 1)` = 1.0 (G). l `Fraction(fr, 5)` = 0.7 (F). m `Fraction(fr, 7)` = 0.5 (F). n `Fraction(fr, 12)` = 0.5 (F). o with an empty array, `Fraction(empty, 5)` = 1.0 (G). Tolerance 1e-12. F 7, G 8 |
| **RT65 the effective add** (5) | `Rt167_Book(B)`: a `Grind_LightAddPips(g_grind_short, false, 7.0)` = 4.9 (F). b `Grind_LightAddPips(g_grind_long, true, 7.0)` = 7.0 (G). `Rt167_Book("")`: c short = 7.0 (G). `Rt167_Book(B)` then `ArrayResize(g_grind_short.layers, 0)`: d short = 7.0, an empty side (G). `Rt167_Book(B)` then two more long layers (1.10060, 1.10000; tickets 5307, 5308) so long is 8: e long = 7.0 (G). Tolerance 1e-9. F 1, G 4 |
| **RT66 the placed add** (2) | `Rt167_Book(B)`; 3 ticks at bid 1.10500; `Rpl_RunTicks`. a `g_grind_short.add_pending_ticket != 0` and its `Grind_OrderGetPriceOpen` = **1.10549** (1.10500 + 0.7 x 7 pips) (F: the stub gives 1.10570). b `g_grind_long.add_pending_ticket != 0` and its price = **1.10060** (the heavy side keeps 7 pips) (G). Tolerance 1e-9. F 1, G 1 |
| **RT67 the fill and the next add** (3) | `Rt167_Book(B)`; ticks bid 1.10500, 1.10500, **1.10549**, 1.10545; `Rpl_RunTicks`. a `Grind_SideDepth(g_grind_short) == 2 && MathAbs(g_grind_short.layers[1].entry_price - 1.10549) < 1e-9` (F). b the short add now pending at **1.10605** (gap 4 -> 0.8 x 7 = 5.6 pips above 1.10549) (F). c `Grind_SideDepth(g_grind_long) == 6` (G). F 2, G 1 |
| **RT68 one re-quote at the deadband** (2) | `Rt167_Direct(B)`. The target is 1.10549, 2.1 pips from the resting 1.10570; deadband 2.0. a `Grind_OrderGetPriceOpen(5212UL)` = 1.10549 (F). b `g_grind_order_test_modify_calls == m0 + 1`: one modify, none on the second call (F). F 2 |
| **RT69 no re-quote under the deadband** (2) | `Rt167_Direct("1;1;1;1;0.9")`. The target is 1.10563 (0.9 x 7 = 6.3 pips), 0.7 pip away. a price of 5212 = 1.10570 (G). b `g_grind_order_test_modify_calls == m0` (G). G 2 |
| **RT70 the run file's column** (3) | Files as RT51 writes them (`ticks_rt70.csv` with bids 1.10500, 1.10500, 1.10549, 1.10545; `seed_rt70.csv` with the fixture's seven layers, header `side,layer_index,entry,open_ms,ticket,vl,swap,volume,accrued`; `swaps.csv`; `intervals_rt70.csv`). `run_rt70.csv`: RT42's 23-column header plus `,light_add`; the row `1,GRIND_TEST,22260201,<RplMs(RPL_T0,0)>,<RplMs(RPL_T0,5)>,2,15,7,7,10,10,8,50,2,1,0,-1,0,1,8,seed_rt70.csv,ticks_rt70.csv,,1;1;0.9;0.8;0.7;0.6;0.5`. a `Rpl_RunReplayFiles("rt70", false)` true (G). b `out_rt70_deals.csv` contains `,ENT,S,1,1.10549` (F). Then `run_rt70b.csv`, the same row with the table `0.5;0.9`, and `intervals_rt70b.csv`: c `Rpl_RunReplayFiles("rt70b", false)` false (F). F 2, G 1 |

Totals: 32 assertions, **15 F, 17 G**. Suite: 461 + 32 = **493**.

## 5. RUNNING (after "go run"; through `tools\replay_run.ps1` only)

- R0: `git checkout replay-adr167`, `-Mode Copy`, then STOP for "compiled"
  (the OPERATOR compiles both scripts in the MetaEditor GUI; if the `.ex5`
  is stale, STOP and ask; a suite from a command-line build does not count).
- R1: `-Mode Suite -Tag rt_<commit sha7>`. At commit 1: 493 run, 478 pass;
  report the 15 failing names. At commit 4: **493 / 493**, 0 errors and 0
  warnings at the compile. On any other count or any other failure STOP
  and report, do not fix.
- R2: `-Mode Inputs -Commit <the main commit that carries this file> -Set eurusd_20261008`
  (after the last suite run: the suite rewrites `swaps.csv`).
- R3, THE OFF-SWITCH, twelve runs with the committed calibration files (no
  `light_add` column): B, C, D x free, sync at `-Timing 0` (labels
  `<tag>_<mode>_<commit 4 sha7>_t0`) and at `-Timing 1 -Sens base` (labels
  `<tag>_<mode>_<commit 4 sha7>`). Report the sha256 of every deals, orders
  and book file next to the same file in `research/replay/runs/` at
  `145f092` (C16). **All must be equal. Any difference: STOP.** Events files
  are compared by Claude with `ea_time_ms` masked.
- R4: commit the twelve folders and `_rpl_*.txt` (no `timing.csv`), push the
  branch, STOP. Do not analyse.
- The eight-week runs (sweep6) come AFTER R3, from run files Claude writes
  and pre-registers on `main` first. They are not part of this prompt.

## 6. NEGATIVE SPACE

- Do not touch `ea/fxgrind.mq5`, the EA's test suite, any preset, the
  lattice, the roll, the roll gate, reconciliation, the exit queue or the
  carry pass.
- Do not change any output file's columns or add any output row.
- Do not commit to, rebase, merge into or force-push `replay-harness` or
  `main`. No PR. No `git stash`. No `git add .` or `-u`. No checkout of
  files from other commits.
- Do not compile from the command line. Do not launch a terminal other than
  through `tools\replay_run.ps1`. Do not touch the VPS, the Linux boxes or
  any live chart.
- Do not read, copy or open any file dated 2026-10-13 in Downloads (plan
  3's holdout).
- Do not run anything on the holdout or score anything.

## 7. FAILURE MODES: STOP AND REPORT

- s0's diff is not empty.
- A G assertion fails or an F assertion passes at commit 1; any count other
  than s3's.
- A line number in s2 does not hold the code C2-C4 describe.
- Any R3 hash differs from `145f092`'s.
- The operator's compile shows an error or a warning.

## 8. PLAN 3 IS NOT TOUCHED (for the operator and Gemini)

- Plan 3's harness stays `145f092` on `replay-harness` (`efada62`). This
  build lives on `replay-adr167` only.
- `D:\mt5-replay` holds ONE compiled copy. Before plan 3's holdout runs
  (after Tue 13): `git checkout replay-harness`, `-Mode Copy`, the
  operator's GUI compile, `-Mode Suite`: **461 / 461**. Only then the
  holdout's runs. This restore is the first step of plan 3 s7's runs.
- With the table empty the engine must be identical (R3): the twelve hash
  comparisons are the proof, on the calibration window plan 3 already saw.

## 9. FOR GEMINI (attack the premises; say which fact is missing)

- **G167-1.** Is a side branch with a restore step (s8) enough to keep plan
  3's "harness frozen at `145f092`" true, or is there a way this build
  leaks into the holdout runs?
- **G167-2.** The effective add is computed inside the three functions that
  use it, never passed down (s2 E). Is there a fourth place that prices or
  classifies a sub-cap add (C1-C5)?
- **G167-3.** R3 as the off-switch proof (twelve byte-equal runs) in place
  of the EA's own suite, which this experiment build does not run. Enough
  for an experiment that is never deployed?
- **G167-4.** The tests of s4: is there an assertion that passes for the
  wrong reason, or a state in which an F cannot fail?
- **G167-5.** What fact is missing?

Line count: 247
