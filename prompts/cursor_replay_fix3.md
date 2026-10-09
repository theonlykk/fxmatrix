This message has a line count at the bottom

# CURSOR PROMPT -- REPLAY FIX 3: THE CARRY LEDGER AT AN INIT, AND ONE RUN SCRIPT

**Workspace: `D:\fxmatrix`, branch `replay-harness`** (tip `b933a2f`; code
`b8adb15`, tests `e76c5af`). Written by Claude 9 Oct ~22:00Z from the
branch, the fix-2 outputs (`research/replay/runs/*_b8adb15/`) and
`research/replay/results/eurusd_20261008_b8adb15/` on `main`. Line numbers are
`b8adb15`'s (core) and `e76c5af`'s (tests). Questions for Gemini in s6; his
rulings and Claude's check are in s7 (they added A2, RT45 and P1's step 0).
s8 is his second round: what changed after his first reading, and the
corrections of 9 Oct ~23:00Z (K1, K2, P1 steps 0, 3 and 5); his rulings and
Claude's check are in s9 (GF3b-4 added A3, RT46 and RT47). s10 is his third
round. The earlier replay prompts govern what this file does not change.

## 0. RESTATE AND STOP (do this first, then wait)

1. Read this file from `main` at the commit that carries it (`git fetch`,
   `git show <that commit>:prompts/cursor_replay_fix3.md`) BEFORE switching
   branches; then `git checkout replay-harness`, `git pull`; report `git log
   --oneline -1` (must be `b933a2f`) and the pin (`git diff --stat 5bb5fdb
   origin/main -- ea/fxgrind.mq5` EMPTY).
2. Restate A1, A2, A3 and P1 (s2) in ONE line each, quoting this prompt; give
   the assertion count of RT43-RT47 (s3) and how many fail at commit 1.
3. Report anything in s1 you read differently in source.
4. STOP until the operator replies "go".

## 1. FINDINGS (Claude)

| # | Finding | Evidence | Kind |
|---|---|---|---|
| K1 | **The EA's carry ledger survives a restart; the replay's does not.** The exit formula adds `Grind_CarryAccruedGet(pos)` (`ea/grind_exitq.mqh` 241-255), read from the terminal Global Variable `GRIND_CARRY_ACCRUED_<ticket>` (`ea/grind_carry.mqh` 703-729), which the nightly carry pass sets for EVERY layer, resting or held (1080-1130). The harness deletes these GVs per segment (`Rpl_ClearCarryGvs`, core 355-364) and seeds only the VL. So an exit the queue places later in a segment (it was held at the init) lacks its accrued carry: after fix 2 the sync misses hold 14 real exits with a replay exit of the same layer 0.8-1.6 pips lower within 60 s (B 8, C 4, D 2; 18 at any distance in time: B 11, C 4, D 3; s8), and what follows them | `research/replay/results/eurusd_20261008_b8adb15/misses.csv`; send_logs | DEFECT (base design) |
| K2 | The value at an init is computable: the last weekday pass (23:50 server) before the init set it to (the position's swap so far + the pass snapshot's points x the EA's multiplier for TOMORROW) in pips, as a price, -direction x pips x 0.0001 (0 when opened after that pass). `research/replay/build_seeds.py` `accrued_price` (tests first) agrees with the exit placements in send_logs by two explicit rules (s8, `research/replay/check_accrued.py`): rule N 108 of the 118 seed rows that have a placement, rule W 217 of 241; every row that differs has a cause other than the carry value; it is now seed column 9 `accrued` (price units, e.g. `0.00008192`) in all 28 seed files | `research/replay/inputs/eurusd_20261008/seed_*.csv` on `main` | DATA |
| K3 | The seed reader takes fields by index (core 2358-2367); a 9th field is ignored today. `Grind_CarryAccruedSet(ticket, price)` writes the GV (`ea/grind_carry.mqh` 717-721) | source | FACT |
| K5 | **The sync true book never rolls its swap and never learns a pass's accrued** (GF3b-4, s9). A real ENT row enters it with swap 0 and accrued 0 (`Rpl_ApplySyncDealsUpTo`, core 1434); a seeded entry keeps the seed's swap; `Rpl_ApplySwapRollover` (core 1095-1123) rolls only `g_rpl_pos_meta`, the positions the replay holds. A layer the replay exits early and sync re-seeds later comes back with the old swap (`Rpl_SeedLayer` -> `Rpl_AddPosMeta`) and accrued, and every later pass in the segment reads a swap short by the nights it missed. From the real files: layers opened inside a segment and still held across a 23:50 pass in it, B 35, C 37, D 38; seeded layers held across one, B 19, C 17, D 11 | `real_eurusd_*.csv`, `run_eurusd_*.csv` on `main`; core | DEFECT (sync) |
| K4 | Each run needs several approvals in Cursor (copies, hashes, starts, log reads), and the allowlisted `taskkill /IM terminal64.exe /F` closes EVERY MT5 on the desktop. One reviewed script with fixed paths can do all of it | operator 9 Oct | PROCESS |

## 2. FIX (commit 2: core, A1, A2 and A3; commit 3: the script)

| # | Fix |
|---|---|
| A1 | New `void Rpl_SeedAccrued(const ulong ticket, const double accrued)`: `Grind_CarryAccruedSet(ticket, accrued)`. In `Rpl_RunReplayFiles`' seed loop (core 2358-2367), read field 9 (`seed_fields[8]`, when `ArraySize(seed_fields) > 8`; else 0.0) and, right after `Rpl_SeedLayer`, call `Rpl_SeedAccrued` when it is not 0. An 8-field seed runs exactly as before |
| A2 | The sync true book keeps it (GF3-4). `RplTrueLayer` (core 145-155) gains `double accrued`; `Rpl_TrueBookAdd` (core 662-675) sets it to 0.0 (signature unchanged). `Rpl_SeedAccrued` also sets `accrued` on the true-book entry with that ticket, if there is one. In `Rpl_SyncResetToTrueBook`, inside `if(!present)` (core 1402-1408), right after `Rpl_SeedLayer`, call `Grind_CarryAccruedSet(ticket, accrued)` when that entry's `accrued` is not 0. Only re-seeded layers: a layer the replay still holds keeps its GV (a carry pass in the segment may have updated it) |
| A3 | The sync true book follows the real positions (K5). (a) In `Rpl_ApplySwapRollover`, after the `g_rpl_pos_meta` loop (only when the night was found, as now), add the same night to every true-book entry: `g_rpl_true_book[i].swap += (side == "L" ? pl : ps) * mult * tick_val * g_rpl_true_book[i].volume` (the broker charges every open real position, whatever the replay holds). (b) In `Rpl_SyncResetToTrueBook`, FIRST (before the two removal loops): for each true-book entry whose ticket has an accrued GV (`GlobalVariableCheck(Grind_CarryAccruedGvName(ticket))`), copy `Grind_CarryAccruedGet(ticket)` into its `accrued` (the GV exists only while the replay holds the layer: a carry pass in the segment may have set it). A2's restore then brings back the latest value. Nothing else changes |
| P1 | New `tools/replay_run.ps1` (PowerShell 5, `$ErrorActionPreference = 'Stop'`), one of four modes. **Step 0 (every mode, before anything else)**: `-Tag`, `-Label` and `-Set` must match `^[A-Za-z0-9_]+$`, `-Commit` `^[0-9a-f]{7,40}$`, `-SwapsSha` `^[0-9a-f]{64}$`, `-TimeoutSec` an `[int]` from 60 to 7200, and in `Inputs` every file name in the list `^[A-Za-z0-9_.]+$` with no `..`; else throw before writing anything. Fixed paths: `$Root = 'D:\mt5-replay'`, the repo is the script's parent folder. It never stops a process whose `Path` is not under `$Root\`, never deletes anything, writes only under `$Root\` and `research\replay\runs\`, and calls `git` only in `Inputs` (read only, `git show`). **`-Mode Copy`**: copy `ea\*.mq5` and `ea\*.mqh` to `$Root\MQL5\Scripts\fxmatrix\`, compare every pair by SHA-256, print `COPY <n>/<n> identical` and throw on any difference. **`-Mode Inputs -Commit <sha> -Set eurusd_20261008`**: for each line of `git show <sha>:research/replay/inputs/<set>.sha256`, write `git show <sha>:research/replay/inputs/<set>/<file>` BYTE FOR BYTE (no re-encoding: e.g. `cmd /c "git show ... > <path>"` or `System.Diagnostics.Process` with raw output) to `$Root\MQL5\Files\replay\<file>`, check its SHA-256 against the line; check `ticks_53077984_EURUSD_w2.csv` there against `db2ea94173a4d0c8746c7fecc972c8950da79c803910a25e0bbc522bc63abd28`; print `INPUTS <n>/<n> ok` and throw on any mismatch. **`-Mode Suite -Tag rt_<sha7>`** and **`-Mode Run -Tag <eurusd_b|c|d> [-Sync] -SwapsSha <hex> -Label <out label>`**: (1) stop `terminal64` processes whose `Path` starts with `$Root\` (a process whose `Path` cannot be read is NOT stopped) (wait until none, 30 s, else throw); (2) Run only: `swaps.csv`'s SHA-256 must equal `-SwapsSha`; (3) Run only: write `$Root\MQL5\Presets\fxgrind_replay_<label>.set` (UTF-8 without BOM, CRLF line ends) with exactly the lines `; fxgrind_replay`, `InpRunTag=<tag>`, `InpSync=true` (with `-Sync`) or `InpSync=false`; then (Suite and Run) write `$Root\replay_<label>.ini` (Suite: `<label>` = `-Tag`) in UTF-16 LE with BOM and LF line ends, with exactly these lines in this order: `[StartUp]`; `Script=fxmatrix\fxgrind_replay_tests` (Suite) or `Script=fxmatrix\fxgrind_replay` then `ScriptParameters=fxgrind_replay_<label>.set` (Run); `Symbol=EURUSD`; `Period=M1`; `ShutdownTerminal=1` (the form of 9 Oct's `replay_r4_eurusd_d_free.ini`, `replay_rt_e76c5af.ini` and `fxgrind_replay_eurusd_d_free.set`; never `Expert=` / `ExpertParameters=`, s8); (4) start `$Root\terminal64.exe /portable /config:<ini>`, wait at most `-TimeoutSec` (default 1800), on timeout stop only that process and throw; (5) copy every line containing `RPL|`, `FAIL |` or `RT35-LOAD-MS` that the run wrote to `$Root\MQL5\Logs\<yyyymmdd>.log` (UTF-16; only lines after the start; the file is named by the desktop's LOCAL date and its times are LOCAL: 9 Oct's last B sync run reads 16:45:40, i.e. 20:45:40Z, so take the date and the start time from the local clock, and read the next day's file too if the run crosses local midnight) to `research\replay\runs\_rpl_<label>.txt`; (6) print `DONE <label> exit=<code> sec=<s> lines=<n>` |

## 3. COMMITS AND TESTS

**Commit 1: tests only** (`ea/fxgrind_replay_tests.mq5`), plus an EMPTY stub
of `Rpl_SeedAccrued` in the core (not called) so the file compiles.

- **T17 RT43 a seeded accrued carry moves a held exit (8 assertions, F: 3 fail
  at commit 1).** `Rpl_ResetAll()`; default config; `cfg.to_ms =
  RplMs(RPL_T0, 4)`; `Rpl_ConfigureEngine(cfg)`; `Rpl_SeedLayer("L", 0,
  1.10000, RplMs(RPL_T0, -3600), 5401UL, 0.0, 0.0, RPL_LOTS_DEFAULT)`;
  `Rpl_SeedAccrued(5401UL, 0.00008)`. `AssertNear("RT43 accrued",
  Grind_CarryAccruedGet(5401UL), 0.00008, 1e-12)`. No order is seeded: the
  engine places the exit itself, at the formula 1.10100 + 0.00008. Ticks
  T0..T3: bid 1.10050, 1.10100, 1.10108, 1.10050 (ask = bid + `RPL_SPREAD`).
  `Rpl_RunTicks`. `AssertDealRow("RT43 ext", 0, DEAL_TYPE_SELL, "EXT", "L",
  0, 1.10108, RplMs(RPL_T0, 2))` (7). At commit 1 the GV is 0, the exit
  rests at 1.10100 and fills at T1: the GV, the price and the time fail.
- **T18 RT44 seed field 9 (2 assertions, F: 1 fails).** As RT42 (files in
  `replay\`, 22-field run row, no orders file): `seed_rt44.csv` header
  `side,layer_index,entry,open_ms,ticket,vl,swap,volume,accrued` and
  `L,0,1.10000,<RplMs(RPL_T0,-3600)>,5401,0,0,0.01,0.00008000`;
  `ticks_rt44.csv` = RT43's ticks; `swaps.csv`, `intervals_rt44.csv` as
  RT42; `run_rt44.csv` naming them. `AssertTrue("RT44 run",
  Rpl_RunReplayFiles("rt44", false))`; `AssertTrue("RT44 shifted exit",
  StringFind(Rpl_ReadWholeFile(dir + "out_rt44_deals.csv"), ",EXT,L,0,1.10108")
  >= 0)`. At commit 1 field 9 is ignored: the exit fills at 1.10100.
- **T19 RT45 a sync re-seed restores the seed's accrued (4 assertions, F: 1
  fails).** `Rpl_ResetAll()`; default config, `cfg.sync = true`;
  `Rpl_ConfigureEngine(cfg)`; `Rpl_SeedLayer("L", 0, 1.10000, RplMs(RPL_T0,
  -3600), 5401UL, 0.0, 0.0, RPL_LOTS_DEFAULT)`, `Rpl_SeedAccrued(5401UL,
  0.00008)`; `Rpl_SeedLayer("L", 1, 1.09900, RplMs(RPL_T0, -1800), 5402UL,
  0.0, 0.0, RPL_LOTS_DEFAULT)`, `Rpl_SeedAccrued(5402UL, 0.00008)`. As a replay
  exit would: `Rpl_RemoveLayerByTicket(g_grind_long, 5401UL)`,
  `Grind_CarryAccruedDelete(5401UL)`; as a carry pass would:
  `Grind_CarryAccruedSet(5402UL, 0.00011)`. `AssertTrue("RT45 removed",
  ArraySize(g_grind_long.layers) == 1)`. `Rpl_SyncResetToTrueBook()`.
  `AssertTrue("RT45 reseeded", ArraySize(g_grind_long.layers) == 2)`;
  `AssertNear("RT45 restored", Grind_CarryAccruedGet(5401UL), 0.00008,
  1e-12)`; `AssertNear("RT45 held kept", Grind_CarryAccruedGet(5402UL),
  0.00011, 1e-12)`. At commit 1 the stub records nothing: "restored" fails.
- **T20 RT46 the true book rolls its swap (3 assertions, F: 2 fail).** As RT15's
  second run, in sync: `Rpl_AppendTestSwap("2026.10.07", -8.067, 1.364, 1.0)`;
  `Rpl_ResetAll()`; default config, `cfg.sync = true`, `cfg.from_ms =
  RplMs(D'2026.10.06 10:00:00', 0)`, `cfg.to_ms = RplMs(D'2026.10.07 00:00:00',
  0) + 1000`; `Rpl_ConfigureEngine(cfg)`; `Rpl_SeedLayer("L", 0, 1.10000,
  RplMs(D'2026.10.06 09:00:00', 0), 6201UL, 0.0, 0.0, RPL_LOTS_DEFAULT)` (into
  the true book too, sync); as a real ENT the replay does not hold:
  `Rpl_TrueBookAdd("L", 1, 1.09900, 6202UL, 0.0, RPL_LOTS_DEFAULT,
  RplMs(D'2026.10.06 12:00:00', 0), 0.0)`. RT15's three ticks (10:00:00,
  23:59:59, 10.07 00:00:00; bid 1.10000, ask 1.10002); `Rpl_RunTicks`. A local
  helper in the tests file, `double Rpl_TestTrueBookSwap(const ulong ticket)`
  (the entry's `swap`, or -999.0 when none). `AssertNear("RT46 held swap",
  Rpl_GetPositionSwap(6201UL), -0.08067, 1e-9)` (G: as RT15);
  `AssertNear("RT46 true seeded", Rpl_TestTrueBookSwap(6201UL), -0.08067,
  1e-9)`; `AssertNear("RT46 true only", Rpl_TestTrueBookSwap(6202UL),
  -0.08067, 1e-9)`. At commit 1 both true-book swaps stay 0.0.
- **T21 RT47 a re-seed restores the latest accrued (3 assertions, F: 1
  fails).** `Rpl_ResetAll()`; default config, `cfg.sync = true`;
  `Rpl_ConfigureEngine(cfg)`; `Rpl_SeedLayer("L", 0, 1.10000, RplMs(RPL_T0,
  -3600), 5701UL, 0.0, 0.0, RPL_LOTS_DEFAULT)`, `Rpl_SeedAccrued(5701UL,
  0.00008)`; as a carry pass would: `Grind_CarryAccruedSet(5701UL, 0.00011)`;
  `Rpl_SyncResetToTrueBook()` (the replay holds it: nothing removed).
  `AssertNear("RT47 held", Grind_CarryAccruedGet(5701UL), 0.00011, 1e-12)`
  (G). As a replay exit would: `Rpl_RemoveLayerByTicket(g_grind_long,
  5701UL)`, `Grind_CarryAccruedDelete(5701UL)`; `Rpl_SyncResetToTrueBook()`.
  `AssertTrue("RT47 reseeded", ArraySize(g_grind_long.layers) == 1)` (G);
  `AssertNear("RT47 latest", Grind_CarryAccruedGet(5701UL), 0.00011, 1e-12)`.
  At commit 1 nothing is restored (0.0); with A2 alone it would be 0.00008:
  only A3 (b) passes it.

Do not read `RplTrueLayer.accrued` in a test: the field does not exist at
commit 1 (assert through the GV, as RT45 and RT47 do).

Totals: **338 run** (318 + 20); commit 1 fails 8.

**Commit 2: A1, A2 and A3**, core only; the tests file is NOT touched. If a test fails
and you believe its expected value or its counting is wrong, STOP and report
with source lines; do not edit it (fix 2's RT41 was edited without stopping:
the edit was right, the stop was required). **Commit 3: P1**,
`tools/replay_run.ps1` only. Push after each. Do not compile. STOP after
commit 3: Claude reads the script before it runs.

## 4. RUNNING (after Claude has read the script and the operator says "go run")

From here on every step runs ONLY through `powershell -NoProfile
-ExecutionPolicy Bypass -File tools\replay_run.ps1 ...` (no other command
touches `D:\mt5-replay`), so the operator can allowlist that one command.

- **R0** Pin; `-Mode Copy`. STOP: the operator closes the replay terminal,
  compiles BOTH replay files in its MetaEditor and replies "compiled".
- **R1** `-Mode Suite -Tag rt_<commit 2 sha7>`: predicted **338 run, 338
  pass**. Report every `RPL|` and `FAIL |` line. Any FAIL: STOP.
- **R2** `-Mode Inputs -Commit <the main commit that carries this file>
  -Set eurusd_20261008`: 66 files.
- **R4** Six `-Mode Run` calls in the usual order (`eurusd_d` free, sync;
  `eurusd_c`; `eurusd_b`), `-SwapsSha` = swaps.csv's line in the sha256 list,
  `-Label <tag>_<free|sync>`. Report every `RPL|` line (`ORDERS`,
  `ORDERS_KEPT` below seeded first, any `ABORT`) and each summary.
- **R5** Commit each run's outputs to `research/replay/runs/<tag>_<free|sync>_<commit 2 sha7>/`
  as before (the `_rpl_*.txt` files too). Push. STOP. Do not analyse them.

## 5. NOT IN THIS FIX

The other open misses (1 Oct short L00s, the 2 Oct 12:30Z news burst, B's L07
exits on 5 Oct, C's 6 Oct re-roll reload): classified after this run.
Known and left (sync runs only, after A3): a carry pass that falls between
the replay's own exit of a layer and the sync reset that re-seeds it (the
next real row, usually seconds) leaves the pre-pass accrued on that layer
until the next pass. (Before A3 this paragraph said the true book's swap
stayed the seed's: A3 (a) removes that.)

## 6. FOR GEMINI (attack the premises; say which fact is missing)

- **GF3-1.** K1 / K2: is `GRIND_CARRY_ACCRUED_` the only carry state a real
  restart keeps that the exit price depends on? (`GRIND_CARRY_SHIFT_` is
  read by `Grind_CarryShiftGetForRecon` for ejected layers only; no EURUSD
  layer was ejected in the window; `GRIND_CARRY_DAY_` matters only for an
  init inside 23:50-23:59, and none is.)
- **GF3-2.** K2: the model takes the LAST weekday pass and assumes it set every
  open layer. A pass that skipped a layer (sign guard on a resting exit, a
  failed modify, the 2-layers-a-minute chunk running out of window) would
  leave an older value. 174 of 174 checked agree; 24 seeded positions have no
  exit placement to check against. Enough, or should the replay read the GV
  value some other way?
- **GF3-3.** P1: anything in the script's limits (paths, no deletes, `git
  show` only) that still lets an allowlisted call do harm?
- **GF3-4.** What fact is missing?

## 7. GEMINI'S RULINGS AND CLAUDE'S CHECK

Gemini 9 Oct ~21:30Z; Claude checked each against source the same evening.

- **GF3-1. Accepted.** `GRIND_CARRY_SHIFT_` is read for ejected layers only
  (`Grind_CarryShiftGetValidated`, `ea/grind_carry.mqh` 752 on); no EURUSD
  layer was ejected in the window. The VL GV is already seeded (column 6).
- **GF3-2. Accepted, for a narrower reason.** The 24 seeded positions without
  an exit placement are not "bound by the same logic"; they are unchecked.
  The replay places their exits from the seeded value, so a wrong value shows
  as an exit miss at its price, and the comparison after this run reads it.
- **GF3-3. Accepted, with step 0 added (P1).** The limits hold for fixed
  paths, but `-Label`, `-Tag`, `-Set` and the list's file names are joined
  into paths (`replay_<label>.ini`, `_rpl_<label>.txt`, `...\<file>`) and
  `-Commit` into a `cmd /c` line: an argument with `..\`, `&` or a quote
  would leave the limits. Step 0 checks every argument first. A process
  whose `Path` cannot be read is not stopped (it is not provably under
  `$Root`).
- **GF3-4. Real; mechanism corrected; A2 and RT45 added.** A replay exit that
  fills deletes the GV (`ea/grind_engine.mqh` 2937, `Grind_CarryAccruedDelete`
  on close). If the real layer is still open, the next sync reset re-seeds it
  from the true book (core 1402-1408) with no accrued. Gemini says the next
  carry pass then "adds that night's swap to 0" and the history is "erased":
  not so. The pass recomputes from the position's swap (`ea/grind_carry.mqh`
  1080-1130, `Grind_CarryExitShiftLayer`: ledger from swap, plus pending), so the gap lasts until the next
  pass. A2 restores the seed's value at the re-seed; the residue (s5) is
  sync-only.

## 8. SECOND ROUND FOR GEMINI (check only what this section lists)

Your first reading was of `24cf8fd`. Claude's check of your rulings (s7)
then added rows you have not seen, and Claude's new chat (9 Oct ~23:00Z)
corrected three facts. Check these and nothing else:

1. From s7 (after your first reading): **A2** (s2: the sync true book keeps
   each seed's accrued; restored on a re-seed only, never over a layer the
   replay still holds), **T19 RT45** (s3: 4 assertions, 1 fails at commit 1;
   totals 332 run, 5 fail at commit 1), **P1 step 0** (every argument checked
   before any path or command line is built; a process whose `Path` cannot be
   read is not stopped), and the **s5 residue** (sync only).
2. **K1's count, corrected.** "15 (B 9, C 4, D 2)" was a miscount (the
   previous chat cannot reproduce it). From the committed
   `results/eurusd_20261008_b8adb15/misses.csv` (sync runs): real EXT misses
   with a replay exit of the same layer 0.8-1.6 pips lower (near_dpts -8 to
   -16) within 60 s: B 8, C 4, D 2 = 14; at any distance in time B 11, C 4,
   D 3 = 18 (the B rows past 60 s: 1 Oct 13:27:04 L05, 6 Oct 10:53:19 L05,
   11:43:12 L03, server).
3. **K2's check, re-derived with two explicit rules** (the previous chat
   cannot reproduce "174 of 174" either). `research/replay/check_accrued.py`
   reads every EXT placement (PENDING, and the MODIFYs of the orders those
   created) for each seed row's side and layer; expected = round(eff + dir x
   exit x 0.0001 + accrued, 5), eff = the latest ROLL_ACCEPTED level up to 5 s
   after the placement (a roll's modify is sent just before its event row),
   else the entry; exit = the pips of the segment holding the placement. 274
   seed rows (127 positions).
   - **Rule N** (from the init to the next 23:50 pass, the next init or the
     position's close): 118 rows have a placement (99 positions, 239
     placements); **108 agree to the point**. The 10 that differ: C seg 16, 7
     rows (the 6 Oct 02:01-02:24 server re-roll burst after the Monday-build
     Load: re-rolled levels, exits next to the touch); D seg 26, 2 rows (the
     round-2 rebuild at 06:20:20 with the new exit pips, 0.7 s before seg 27's
     init row); D seg 29 L02, 1 row (a PENDING 0.3 s before its own roll: the
     check's 5 s lag gives it the new level). Rows with accrued not 0: 90
     checked, 81 agree, the other 9 among those 10.
   - **Rule W** (the GV holds from one pass to the next: from the last pass
     before the init + 10 min, or the open, to the next pass or the close):
     241 rows (110 positions, 553 placements); **217 agree**. The 24 that
     differ: C segs 15 / 16, 14 rows (the same re-roll burst); D's two
     rebuilds with new exit pips, 8 rows (1 Oct 09:21:27 D1, 6 Oct 06:20:20
     round 2); D segs 28 / 29 L02, 2 rows (the check's lag, as above).
     Placements inside 23:50-23:59 are left out: the pass reaches each layer
     over minutes, so an exit placed there before the pass reached it carries
     the previous value (B 5 Oct 23:50:01 L05, 1.6 pips).
   - Unchecked: rule N 156 rows, rule W 33 rows (17 positions). By GF3-2 a
     wrong value there shows as an exit miss at its price in the comparison.
4. **P1 step 3, made explicit.** "EXACTLY as your previous ... starts did"
   cannot be followed: the files 9 Oct's fix-2 runs left in `D:\mt5-replay`
   disagree. `replay_r4_eurusd_b_*.ini` and `_c_*.ini` read
   `Expert=fxmatrix\fxgrind_replay` / `ExpertParameters=...`;
   `replay_r4_eurusd_d_*.ini`, the suite's `replay_rt_e76c5af.ini` and the
   base prompt (s5) read `Script=` / `ScriptParameters=`. All six runs printed
   the script's lines in the log; which ini started the B and C runs is not
   established. P1 now writes the `Script=` form, byte for byte as the D files
   (UTF-16 LE BOM, LF), and the preset as the D preset (UTF-8 no BOM, CRLF).
5. **P1 step 5:** the replay terminal's log is named and stamped in the
   desktop's local time (EDT), not UTC.
6. **P1 step 0** now also checks `-TimeoutSec` (an `[int]`, 60-7200): it was
   the one argument without a check.

- **GF3b-1.** A2 and RT45 (item 1): is restoring the seed's value only on a
  re-seed right, and is the s5 residue acceptable for T1?
- **GF3b-2.** P1 (items 1, 4, 5, 6): anything left that an allowlisted call
  could do outside `D:\mt5-replay` and `research\replay\runs\`, or a step
  Cursor would still have to guess?
- **GF3b-3.** K2 (item 3): rule N checks fewer rows, rule W more; every row
  that differs has a non-carry cause. Enough to seed the runs from column 9?
- **GF3b-4.** What fact is missing?

## 9. GEMINI'S SECOND-ROUND RULINGS AND CLAUDE'S CHECK

Gemini 9 Oct ~22:30Z on the file at `ddd5e99` (attached); checked by Claude
against `b8adb15` the same evening. Operator ~22:40Z: A3 now, through Gemini.

- **GF3b-1. Accepted** (A2 restores on a re-seed only; the residue is
  acceptable for T1). A3 below narrows that residue.
- **GF3b-2. Accepted; his "watertight" is not a check.** Claude reads the
  script line by line against P1 after commit 3, as s3 says.
- **GF3b-3. Accepted, his premise corrected again.** "The unchecked rows are
  bound by the same physical GV mechanics" is the premise s7 GF3-2 rejected:
  they are unchecked, and the comparison reads them.
- **GF3b-4. Real, and wider than stated; A3, RT46 and RT47 added.** A real
  ENT enters the true book with swap 0 and accrued 0 (core 1434), and nothing
  updates either: `Rpl_ApplySwapRollover` rolls only the positions the replay
  holds (core 1095-1123). His case (a layer opened in the segment, re-seeded
  days later) is one of two: a SEEDED entry's swap is also frozen at the
  seed's. His "permanently erasing" is close: the pass recomputes from the
  position's swap, but after a re-seed that swap is the true book's frozen
  one, so the shortfall lasts while the layer is held in that segment, not
  "until the next pass" as s5 said. Exposure (K5): ~110 layers opened in a
  segment and ~47 seeded ones are held across a pass in their segment; how
  many are re-seeded after it is not known before the runs. A3 (a) rolls
  the true book's swap nightly; A3 (b) copies each held layer's accrued GV
  into the true book at every sync reset, so A2 restores the latest value.

## 10. THIRD ROUND FOR GEMINI (check only A3, K5, RT46, RT47, the totals and s5)

- **GF3c-1.** A3 (a): the true book's swap rolls with the same night and
  formula as the replay's positions. Any case where a true-book entry should
  NOT be charged that night (an entry applied at the first tick after
  midnight whose real time was before it; a position the broker closed
  before the rollover)?
- **GF3c-2.** A3 (b): the copy is keyed on the GV existing (the replay holds
  the layer). After every sync reset the replay's layers carry the true
  book's tickets (the first loops remove any other). Is there a path where a
  stale GV for a true-book ticket survives a replay exit and is copied?
  (`Rpl_RemoveLayerByTicket` does not delete the GV; the engine's close does,
  `ea/grind_engine.mqh` 2937.)
- **GF3c-3.** RT46 and RT47: do they test A3 and only A3 (RT47 "latest"
  fails with A2 alone; RT46's two true-book swaps fail before A3 (a))?
- **GF3c-4.** What fact is missing?

## 11. GEMINI'S THIRD-ROUND RULINGS AND CLAUDE'S CHECK

Gemini 9 Oct ~22:45Z on the file at `6304dfc` (attached); checked by Claude
against `b8adb15` and the inputs the same evening. Gemini: "Proceed with
Cursor execution." Nothing in this section changes s2 or s3: Cursor builds
A1, A2, A3 and P1 and the tests RT43-RT47 as written (338 run, 8 fail at
commit 1).

- **GF3c-1. Accepted; his mechanism is backwards, the case is empty.** He
  says sync rows with `time_ms <= t` are applied before the rollover. In
  `Rpl_ProcessOneTick` the rollover runs FIRST (core 1539), then
  `Rpl_ApplySyncDealsUpTo(t)` (1546). So a real row timed before midnight
  but first applied at the first tick after it is charged after the rollover: a
  late ENT would miss that night in the true book (a late close's extra
  night is moot: the entry is removed on the same tick). In the inputs no
  real row of B, C or D falls in 23:55-24:00 server (0 / 0 / 0): no change.
- **GF3c-2. Accepted.** The first loops of the sync reset remove only replay
  layers whose ticket is NOT in the true book, and a ticket never re-enters
  it; the engine's own close deletes the GV (`ea/grind_engine.mqh` 2937).
- **GF3c-3. Accepted.** 318 + 8 + 2 + 4 + 3 + 3 = 338; 3 + 1 + 1 + 2 + 1 = 8
  fail at commit 1.
- **GF3c-4. Rejected as stated: its premise is the one s73 already
  removed.** `swaps.csv` carries EFFECTIVE points (operator 8 Oct ~20:37Z;
  replay plan s12): each night's points are the broker's cent at 0.01 lot /
  (mult x 0.01), so the harness's unrounded `points x mult x tick_value x
  volume` IS the broker's cent (e.g. 2 Oct: -8.0 x 1 x 1.0 x 0.01 = -0.08);
  booked that way it reproduced every closed position whose nights fall in
  1-8 Oct (116 of 116). A3 (a) uses the same formula and the same rows, so
  the true book books the same cents; what is left is double-precision
  epsilon (about 1e-17 a night), far below a cent and below the 0.00001
  price step at which exits are placed. T1 matches the order price within
  0.2 pip, not P&L.


Line count: 349
