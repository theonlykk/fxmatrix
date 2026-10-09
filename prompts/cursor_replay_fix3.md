This message has a line count at the bottom

# CURSOR PROMPT -- REPLAY FIX 3: THE CARRY LEDGER AT AN INIT, AND ONE RUN SCRIPT

**Workspace: `D:\fxmatrix`, branch `replay-harness`** (tip `b933a2f`; code
`b8adb15`, tests `e76c5af`). Written by Claude 9 Oct ~22:00Z from the
branch, the fix-2 outputs (`research/replay/runs/*_b8adb15/`) and
`research/replay/results/eurusd_20261008_b8adb15/` on `main`. Line numbers are
`b8adb15`'s (core) and `e76c5af`'s (tests). Questions for Gemini in s6; his
rulings and Claude's check are in s7 (they added A2, RT45 and P1's step 0).
The earlier replay prompts govern what this file does not change.

## 0. RESTATE AND STOP (do this first, then wait)

1. Read this file from `main` at the commit that carries it (`git fetch`,
   `git show <that commit>:prompts/cursor_replay_fix3.md`) BEFORE switching
   branches; then `git checkout replay-harness`, `git pull`; report `git log
   --oneline -1` (must be `b933a2f`) and the pin (`git diff --stat 5bb5fdb
   origin/main -- ea/fxgrind.mq5` EMPTY).
2. Restate A1, A2 and P1 (s2) in ONE line each, quoting this prompt; give the
   assertion count of RT43, RT44 and RT45 (s3) and how many fail at commit 1.
3. Report anything in s1 you read differently in source.
4. STOP until the operator replies "go".

## 1. FINDINGS (Claude)

| # | Finding | Evidence | Kind |
|---|---|---|---|
| K1 | **The EA's carry ledger survives a restart; the replay's does not.** The exit formula adds `Grind_CarryAccruedGet(pos)` (`ea/grind_exitq.mqh` 241-255), read from the terminal Global Variable `GRIND_CARRY_ACCRUED_<ticket>` (`ea/grind_carry.mqh` 703-729), which the nightly carry pass sets for EVERY layer, resting or held (1080-1130). The harness deletes these GVs per segment (`Rpl_ClearCarryGvs`, core 355-364) and seeds only the VL. So an exit the queue places later in a segment (it was held at the init) lacks its accrued carry: after fix 2, 15 exit misses paired with a replay exit 0.8-1.6 pips lower (B 9, C 4, D 2), and what follows them | `research/replay/results/eurusd_20261008_b8adb15/misses.csv`; send_logs | DEFECT (base design) |
| K2 | The value at an init is computable: the last weekday pass (23:50 server) before the init set it to (the position's swap so far + the pass snapshot's points x the EA's multiplier for TOMORROW) in pips, as a price, -direction x pips x 0.0001 (0 when opened after that pass). `research/replay/build_seeds.py` `accrued_price` (tests first) matches the exit placements in send_logs for 174 of 174 seeded positions that have one; it is now seed column 9 `accrued` (price units, e.g. `0.00008192`) in all 28 seed files | `research/replay/inputs/eurusd_20261008/seed_*.csv` on `main` | DATA |
| K3 | The seed reader takes fields by index (core 2358-2367); a 9th field is ignored today. `Grind_CarryAccruedSet(ticket, price)` writes the GV (`ea/grind_carry.mqh` 717-721) | source | FACT |
| K4 | Each run needs several approvals in Cursor (copies, hashes, starts, log reads), and the allowlisted `taskkill /IM terminal64.exe /F` closes EVERY MT5 on the desktop. One reviewed script with fixed paths can do all of it | operator 9 Oct | PROCESS |

## 2. FIX (commit 2: core, A1 and A2; commit 3: the script)

| # | Fix |
|---|---|
| A1 | New `void Rpl_SeedAccrued(const ulong ticket, const double accrued)`: `Grind_CarryAccruedSet(ticket, accrued)`. In `Rpl_RunReplayFiles`' seed loop (core 2358-2367), read field 9 (`seed_fields[8]`, when `ArraySize(seed_fields) > 8`; else 0.0) and, right after `Rpl_SeedLayer`, call `Rpl_SeedAccrued` when it is not 0. An 8-field seed runs exactly as before |
| A2 | The sync true book keeps it (GF3-4). `RplTrueLayer` (core 145-155) gains `double accrued`; `Rpl_TrueBookAdd` (core 662-675) sets it to 0.0 (signature unchanged). `Rpl_SeedAccrued` also sets `accrued` on the true-book entry with that ticket, if there is one. In `Rpl_SyncResetToTrueBook`, inside `if(!present)` (core 1402-1408), right after `Rpl_SeedLayer`, call `Grind_CarryAccruedSet(ticket, accrued)` when that entry's `accrued` is not 0. Only re-seeded layers: a layer the replay still holds keeps its GV (a carry pass in the segment may have updated it) |
| P1 | New `tools/replay_run.ps1` (PowerShell 5, `$ErrorActionPreference = 'Stop'`), one of four modes. **Step 0 (every mode, before anything else)**: `-Tag`, `-Label` and `-Set` must match `^[A-Za-z0-9_]+$`, `-Commit` `^[0-9a-f]{7,40}$`, `-SwapsSha` `^[0-9a-f]{64}$`, and in `Inputs` every file name in the list `^[A-Za-z0-9_.]+$` with no `..`; else throw before writing anything. Fixed paths: `$Root = 'D:\mt5-replay'`, the repo is the script's parent folder. It never stops a process whose `Path` is not under `$Root\`, never deletes anything, writes only under `$Root\` and `research\replay\runs\`, and calls `git` only in `Inputs` (read only, `git show`). **`-Mode Copy`**: copy `ea\*.mq5` and `ea\*.mqh` to `$Root\MQL5\Scripts\fxmatrix\`, compare every pair by SHA-256, print `COPY <n>/<n> identical` and throw on any difference. **`-Mode Inputs -Commit <sha> -Set eurusd_20261008`**: for each line of `git show <sha>:research/replay/inputs/<set>.sha256`, write `git show <sha>:research/replay/inputs/<set>/<file>` BYTE FOR BYTE (no re-encoding: e.g. `cmd /c "git show ... > <path>"` or `System.Diagnostics.Process` with raw output) to `$Root\MQL5\Files\replay\<file>`, check its SHA-256 against the line; check `ticks_53077984_EURUSD_w2.csv` there against `db2ea94173a4d0c8746c7fecc972c8950da79c803910a25e0bbc522bc63abd28`; print `INPUTS <n>/<n> ok` and throw on any mismatch. **`-Mode Suite -Tag rt_<sha7>`** and **`-Mode Run -Tag <eurusd_b|c|d> [-Sync] -SwapsSha <hex> -Label <out label>`**: (1) stop `terminal64` processes whose `Path` starts with `$Root\` (a process whose `Path` cannot be read is NOT stopped) (wait until none, 30 s, else throw); (2) Run only: `swaps.csv`'s SHA-256 must equal `-SwapsSha`; (3) write the `.ini` (and for Run the preset with `InpRunTag` / `InpSync`) EXACTLY as your previous suite and run starts did (same keys, UTF-16 LE), named `replay_<label>.ini`; (4) start `$Root\terminal64.exe /portable /config:<ini>`, wait at most `-TimeoutSec` (default 1800), on timeout stop only that process and throw; (5) copy every line containing `RPL|`, `FAIL |` or `RT35-LOAD-MS` that the run wrote to `$Root\MQL5\Logs\<yyyymmdd>.log` (UTF-16; only lines after the start) to `research\replay\runs\_rpl_<label>.txt`; (6) print `DONE <label> exit=<code> sec=<s> lines=<n>` |

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

Totals: **332 run** (318 + 14); commit 1 fails 5.

**Commit 2: A1 and A2**, core only; the tests file is NOT touched. If a test fails
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
- **R1** `-Mode Suite -Tag rt_<commit 2 sha7>`: predicted **332 run, 332
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
Known and left (sync runs only): a re-seed after a carry pass inside the
segment restores the pre-pass value until the next pass, and the true book's
`swap` is the seed's (`Rpl_ApplySwapRollover`, core 1095-1123, rolls `g_rpl_pos_meta`
only), so that next pass reads a swap short by the nights since the init.

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

Line count: 164
