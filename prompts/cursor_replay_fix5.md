This message has a line count at the bottom

# CURSOR PROMPT -- REPLAY FIX 5: PRICES ON ONE GRID, AND SYNC KEEPS THE REPLAY'S OWN ROLLS

**Workspace: `D:\fxmatrix`, branch `replay-harness`** (tip `7fd02d3`; code
`298d9c1`). Written by Claude 10 Oct ~01:00Z from the fix-4 order logs
(`research/replay/runs/*_298d9c1/out_*_orders.csv`), the real send_logs and
`research/replay/results/eurusd_20261008_624a29b/orders_reading.csv` on
`main` (`research/replay/read_orders.py`). Line numbers are `298d9c1`'s
(core, `ea/fxgrind_replay_core.mqh`; tests, `ea/fxgrind_replay_tests.mq5`).
Questions for Gemini in s8; his rulings and Claude's check are in s9. The earlier replay prompts govern what this file does not
change. Both fixes correct the harness, not a trading rule (GO4-3).

## 0. RESTATE AND STOP (do this first, then wait)

1. Read this file from `main` at the commit that carries it (`git fetch`,
   `git show <that commit>:prompts/cursor_replay_fix5.md`) BEFORE switching
   branches; then `git checkout replay-harness`, `git pull`; report `git log
   --oneline -1` (must be `7fd02d3`) and the pin (`git diff --stat 5bb5fdb
   origin/main -- ea/fxgrind.mq5` EMPTY).
2. Restate P1 and S2 (s2) in ONE line each, quoting this prompt; give the
   assertion count of RT50, RT51 and RT52 (s3) and how many fail at commit 1.
3. Report anything in s1 you read differently in source.
4. STOP until the operator replies "go".

## 1. FINDINGS (Claude, from the fix-4 order logs)

| # | Finding | Evidence | Kind |
|---|---|---|---|
| K1 | **Exact touches never fill at 14 price values.** Across all six runs at `298d9c1`, a replay order whose price a tick reached EXACTLY (buy limit: ask == price; sell limit: bid == price) filled at that tick for 600 price values and never for 14 (84 exact touches, no value both): 1.11739 b, 1.11861 b, 1.12095 s, 1.12322 b, 1.12383 b, 1.12434 s, 1.12444 b, 1.12505 b, 1.12532 b, 1.12566 b, 1.12834 s, 1.12871 b, 1.13044 s, 1.13078 s (b = buy limit, s = sell limit). A rule cannot depend on the price's last digit; a double's representation can. Order prices are `NormalizeDouble`d at the send (`Grind_PlaceLimit`, `ea/grind_engine.mqh` 1456; the modify, 1432); tick prices are `StringToDouble` of the file (`Rpl_LoadTicksCsv`, core 2254-2255); `Rpl_FillsOnTick` compares the two raw (core 1448, 1450). 14 sync misses at `624a29b` had a replay order resting at the real price, touched, unfilled (B 5, C 5, D 4) | `read_orders.py` output; `orders_reading.csv` (reading `AT_PRICE_TOUCHED`) | DEFECT (harness) |
| K2 | **Sync marks a layer rolled before the replay's own lattice can roll it.** `Rpl_SyncResetToTrueBook`'s last loop (core 1595-1600) sets the VL GV of EVERY true-book entry (or deletes it when the true VL is 0), layers the replay still holds included. A real `ROLL` row carries the EA's clock (`build_real.py`: ROLL_ACCEPTED `ea_time_ms`), which runs ahead of the broker's ticks: B 6 Oct S L01 roll row 10:50:52.607, first crossing tick 10:50:53.206; S L02 10:57:35.594 against 10:57:36.160 (server). So the row is applied first, the layer reads as rolled, the replay's lattice skips it and its resting exit keeps the unrolled price. `ROLL_ACCEPTED` in sync against free runs, same segments: B seg 4 0 / 10, seg 7 0 / 7; C seg 11 0 / 13, seg 17 0 / 7; D seg 24 0 / 10, seg 27 0 / 7. 16 sync exit misses follow a real roll of that layer the replay did not make. The same loop also DELETES a VL the replay rolled itself when the real row has not come yet | `out_*_summary.txt` (sync / free); `orders_reading.csv` (reading `OTHER_PRICE_ROLLED`); core 1595-1600 | DEFECT (harness, sync) |
| K3 | `Rpl_SeedLayer` already sets the VL GV when `vl > 0` (core, in `Rpl_SeedLayer`), so a re-seeded layer gets the true book's VL without the last loop. The engine's close deletes a layer's VL GV (`ea/grind_engine.mqh` 2925-2940) | source | FACT |
| K4 | Every other price the harness reads from a file is also `StringToDouble`: seed `entry` and `vl` (core 2577, 2580), the orders file's `price` (core 975), the real file's `price` and `level` (`Rpl_ParseSyncFields`, core 2119, 2121). Seeded orders are not re-normalised by the EA (`Rpl_SeedOrder` upserts the parsed price) | source | FACT |

## 2. FIX (commit 2: core only)

| # | Fix |
|---|---|
| P1 | **Every price read from an input file on the symbol's grid.** New `double Rpl_FilePrice(const string s)` = `NormalizeDouble(StringToDouble(s), (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS))`. Use it, and only it, for: the tick `bid` and `ask` in `Rpl_LoadTicksCsv` (core 2254-2255); the seed `entry` and `vl` (core 2577, 2580); the orders file's `price` (core 975); the real file's `price` and `level` in `Rpl_ParseSyncFields` (core 2119, 2121). NOT for swap, volume, accrued, the swaps file or the run row (not prices). Nothing else changes: `Rpl_FillsOnTick`'s comparison stays as it is |
| S2 | **Sync keeps the replay's own rolls.** Delete the last loop of `Rpl_SyncResetToTrueBook` (core 1595-1600: the `Grind_VLSet` / `Grind_VLDelete` over the whole true book). A re-seeded layer still gets the true book's VL through `Rpl_SeedLayer` (K3); a layer the replay holds keeps whatever VL its own lattice gave it. The true book keeps taking `ROLL` rows as now (`Rpl_ApplySyncDealsUpTo`), for re-seeds |

## 3. COMMITS AND TESTS

**Commit 1: tests only** (`ea/fxgrind_replay_tests.mq5`), plus an EMPTY-body
stub `double Rpl_FilePrice(const string s) { return StringToDouble(s); }` in
the core (not called) so the file compiles.

- **T24 RT50 a sync reset leaves a held layer's VL alone (4 assertions, F:
  2 fail at commit 1).** `Rpl_ResetAll()`; default config, `cfg.sync =
  true`; `Rpl_ConfigureEngine(cfg)`; `Rpl_SeedLayer("L", 0, 1.10000,
  RplMs(RPL_T0, -3600), 6301UL, 0.0, 0.0, RPL_LOTS_DEFAULT)`;
  `Rpl_SeedLayer("L", 1, 1.09930, RplMs(RPL_T0, -1800), 6302UL, 0.0, 0.0,
  RPL_LOTS_DEFAULT)`. As a real ROLL row would: set the true-book entry of
  6301 to `vl = 1.09500` (loop over `g_rpl_true_book`). As the replay's own
  lattice would: `Grind_VLSet(6302UL, 1.09400)`. `Rpl_SyncResetToTrueBook()`
  (both held: nothing re-seeded). `AssertTrue("RT50 held not marked",
  !Grind_VLHas(6301UL))`; `AssertNear("RT50 own roll kept",
  Grind_VLGet(6302UL), 1.09400, 1e-9)`. Then as a replay exit would:
  `Rpl_RemoveLayerByTicket(g_grind_long, 6301UL)`; `Rpl_SyncResetToTrueBook()`.
  `AssertTrue("RT50 reseeded", ArraySize(g_grind_long.layers) == 2)`;
  `AssertNear("RT50 reseed takes true vl", Grind_VLGet(6301UL), 1.09500,
  1e-9)`. At commit 1 the last loop sets 6301 (fails "held not marked") and
  deletes 6302's (fails "own roll kept"); the other two pass (guards).
- **T25 RT51 an exact touch fills a buy limit at 1.12505 (2 assertions, F:
  1 fails).** Files in `replay\` as RT44 (22-field run row, no orders file,
  RT44's run-row values): `seed_rt51.csv` header
  `side,layer_index,entry,open_ms,ticket,vl,swap,volume,accrued` and
  `S,0,1.12605,<RplMs(RPL_T0,-3600)>,6401,0,0,0.01,0`; `ticks_rt51.csv`
  (header as RT44) with four rows, prices written as these exact strings:
  T0 bid `1.12550` ask `1.12552`; T1 bid `1.12505` ask `1.12505`; T2 and T3
  bid `1.12520` ask `1.12522`; `swaps.csv` and `intervals_rt51.csv` as
  RT44; `run_rt51.csv` naming them, from T to T+4. `AssertTrue("RT51 run",
  Rpl_RunReplayFiles("rt51", false))`; `AssertTrue("RT51 exact touch
  fills", StringFind(Rpl_ReadWholeFile(dir + "out_rt51_deals.csv"),
  ",EXT,S,0,1.12505") >= 0)` (the short exit, 1.12605 - 10 pips, can fill
  only at T1). At commit 1 it does not fill (K1: 1.12505 b never filled).
- **T26 RT52 an exact touch fills a sell limit at 1.12434 (2 assertions, F:
  1 fails).** As RT51 with `seed_rt52.csv` row
  `L,0,1.12334,<RplMs(RPL_T0,-3600)>,6501,0,0,0.01,0` and `ticks_rt52.csv`:
  T0 bid `1.12390` ask `1.12392`; T1 bid `1.12434` ask `1.12434`; T2 and T3
  bid `1.12410` ask `1.12412`; `AssertTrue("RT52 run", ...("rt52", false))`;
  `AssertTrue("RT52 exact touch fills", StringFind(..."out_rt52_deals.csv"),
  ",EXT,L,0,1.12434") >= 0)`. At commit 1 it does not fill (K1: 1.12434 s).

**If RT51 or RT52 "exact touch fills" PASSES at commit 1, STOP and report:
K1's cause is then not the representation.**

Totals: **389 run** (381 + 8); commit 1 fails 4.

**Commit 2: P1 and S2**, core only; the tests file is NOT touched. If a test
fails and you believe its expected value or counting is wrong, STOP and
report with source lines; do not edit it. Push after each commit. Do not
compile. STOP after commit 2: Claude reads it before "go run".

## 4. RUNNING (after Claude has read commit 2 and the operator says "go run")

As fix 4 s4, through `tools\replay_run.ps1` only: **R0** pin, `-Mode Copy`,
STOP for "compiled"; **R1** `-Mode Suite -Tag rt_<commit 2 sha7>`, predicted
**389 run, 389 pass**, any FAIL: STOP; **R2** `-Mode Inputs -Commit <the main
commit that carries this file> -Set eurusd_20261008` (66 files); **R4** the
six runs (`-SwapsSha
dc7da509b35e6846f12f03692bf973632847ab3f2ad7dc865a93d91309f95b6c`), report
each `DONE`, any `RPL|ABORT`, every `ORDERS_KEPT` below seeded and each
summary's `roll_accepted` per segment; **R5** commit the outputs to
`research/replay/runs/<tag>_<free|sync>_<commit 2 sha7>/` with the
`_rpl_*.txt` files; push; STOP; do not analyse them.

## 5. NEGATIVE SPACE

- Change only `ea/fxgrind_replay_core.mqh` and `ea/fxgrind_replay_tests.mq5`
  (and `research/replay/runs/`). No EA file, no runner or script change, no
  change to the fill rule's comparison, the order log, seeding, rollover,
  close-by, timer or intervals beyond P1 and S2.
- Do not compile; only `D:\mt5-replay`, only through the script. Do not
  check out `main`, merge, open a PR, `git stash`, check out files from
  other commits, `git add .` or `-u`. Do not commit tick files.

## 6. FAILURE MODES (STOP and report; do not improvise)

A test fails, or passes at commit 1 when predicted to fail (above all RT51 /
RT52); any `RPL|ABORT`; a hash mismatch; a run with no `DONE` line; a run's
total time over twice fix 4's for the same tag.

## 7. NOT IN THIS FIX

The L00 placement timing (M3: the harness's instant close-by; GO4-2 ruled it
a reported sensitivity). The ROLL rows' clock (K2) for re-seeds: a re-seed
after a real roll still takes the true VL. Reading the new runs (Claude's,
after R5).

## 8. FOR GEMINI (attack the premises; say which fact is missing)

- **GF5-1.** P1 puts every file price on the symbol's grid with the same
  `NormalizeDouble` the EA's sends use, so a tick at a limit price equals it.
  Is normalising the INPUTS right, or should only the fill comparison work
  in whole points? (Live, the EA compares the terminal's prices with its own
  normalised ones; the replay cannot know their representation.)
- **GF5-2.** S2 lets a held layer keep the replay's own VL. Is there a case
  where the real EA's VL must be pushed onto a layer the replay holds (a hand
  roll or a commanded eject: none in the window, plan K20)?
- **GF5-3.** K2: ROLL rows carry the EA's clock, ENT / EXT / OUT_BY rows the
  broker's deal time; the 1 Oct `BREAKER_GATED` interval is also from the
  EA's clock (send_logs). Any other place where mixing the two clocks moves
  a sync decision?
- **GF5-4.** What fact is missing?

## 9. GEMINI'S RULINGS AND CLAUDE'S CHECK

Gemini 10 Oct ~00:20Z on the file at `1965577` (attached); checked by Claude
the same night. Gemini: "Proceed with Cursor execution." Nothing here
changes s2 or s3: Cursor builds P1 and S2 and RT50-RT52 as written (389 run,
4 fail at commit 1; RT51 / RT52 must fail at commit 1, else STOP).

- **GF5-1. Accepted: normalise the inputs (P1), leave the fill comparison
  as it is.** His "the broker matches on grid ticks" is inferred, not
  measured here; the ruling stands on the EA side, which is verified: every
  order price is `NormalizeDouble`d at the send (`ea/grind_engine.mqh` 1432,
  1456), so file prices through the same call give the same doubles.
- **GF5-2. Accepted.** No hand roll or commanded eject in the window (plan
  K20), so a held layer's VL can only come from the replay's own lattice.
- **GF5-3. Accepted, his clock premise corrected.** The 0.57-0.60 s lead of
  the ROLL rows over the crossing tick is measured (K2), not a property of
  `TimeCurrent()` / `TimeLocal()` that he names; it reaches only re-seeded
  layers after S2. Recorded as a sync residue (s7).
- **GF5-4. Not a missing fact.** `NormalizeDouble(0.0, 5)` is 0.0, and every
  VL use tests `vl > 0.0` (`Rpl_SeedLayer`; the true book). No change.



## 10. AMENDMENT AFTER R1 (10 Oct ~00:45Z): RT8b

**R1 at `58e3c0f`: 389 run, 388 pass; `FAIL | RT8b VL7001`.** RT51 and RT52
pass (P1's cause confirmed). RT8b (base harness, `0c3d5ef`;
`Test_RT8b_SyncEntRoll`, tests `58e3c0f`) feeds a sync `ROLL` row for layer
7001 while the replay HOLDS that layer, then asserts `AssertNear("RT8b
VL7001", Grind_VLGet(7001UL), 1.09771, 1e-9)`: the held layer takes the
real VL. That is the behaviour S2 removes on purpose (K2). Claude's spec
missed it: s3 should have named RT8b. Cursor stopped as s6 says.

**Change (commit 3: the tests file only).** In `Test_RT8b_SyncEntRoll`
replace that one assertion with: find the true-book entry of ticket 7001
(loop over `g_rpl_true_book`, as RT50 does) and `AssertNear("RT8b true
VL7001", <that entry>.vl, 1.09771, 1e-9)`: the ROLL row still reaches the
true book, which re-seeds read (K3); and right after it add
`AssertTrue("RT8b held 7001 not rolled", !Grind_VLHas(7001UL))` (GF5b-1:
depth 3 is below cap 8, so the replay's lattice cannot roll it, and S2 no
longer marks it). Nothing else in RT8b changes. **Totals: 390 run** (389 +
1). Push, then R0 (copy), STOP for "compiled", R1 again with `-Tag
rt_<commit 3 sha7>` (predicted 390 / 390), then R2-R5 as s4 with the run folders named for
commit 3 (`<tag>_<free|sync>_<commit 3 sha7>`).

- **GF5b-1.** Is the rewrite right (the held layer's VL is the replay's own;
  the real row's VL lives in the true book), or should RT8b also assert that
  7001 has no VL after the reset (`!Grind_VLHas(7001UL)`; depth 3 is below
  cap 8, so the replay cannot have rolled it)?


**Gemini GF5b-1 (10 Oct ~00:50Z), checked by Claude: accepted.** He requires
the second assertion; in RT8b 7001 stays held (depth 3 after the ENT row,
cap 8), so no lattice roll and no re-seed can give it a VL after S2: the
assertion is derived, not observed. Added above; 390 run.

Line count: 203
