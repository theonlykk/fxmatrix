This message has a line count at the bottom

# CURSOR PROMPT -- REPLAY FIRST RUN, FIX 1: LATTICE HISTORY ON DEMAND (THE FIVE LATTICE_HISTORY ABORTS)

**Workspace: `D:\fxmatrix`, branch `replay-harness`** (tip `c66db4e`, code
`86c1194`). Written by Claude 9 Oct ~16:10Z from the branch and the R4
outputs (`research/replay/runs/*_86c1194/`). Line numbers are `86c1194`'s.
Questions for Gemini in s6; his rulings will be added in s7 before you get
this file. The first-run prompt (`prompts/cursor_replay_first_run.md`) still
governs everything not changed here.

## 0. RESTATE AND STOP (do this first, then wait)

1. `git checkout replay-harness`, `git pull`; report `git log --oneline -1`
   (must be `c66db4e`) and the pin (`git diff --stat 5bb5fdb origin/main --
   ea/fxgrind.mq5` EMPTY).
2. Restate L1 (s2) and T12 (s3) in ONE line each, quoting this prompt; give
   T12's assertion count and how many fail at commit 1.
3. Report anything in s1 you read differently in source.
4. STOP until the operator replies "go".

## 1. FINDINGS (Claude, from the R4 logs, the seeds and source)

| # | Finding | Evidence | Kind |
|---|---|---|---|
| G1 | **Free runs abort on a segment's FIRST tick when the side at cap is not the side with the newest open.** `Rpl_PreloadLatticeFromTicks` starts at the newest open across BOTH sides (core 700-725, `g_rpl_newest_seed_open_ms`); the EA tracks a capped side from ITS OWN newest open + 1 s (`ea/grind_engine.mqh` 825-846, 858-879). D seg 24: short S0-S7 at cap, newest short open 2 Oct 16:59:05.544 server; one long layer opened 17:11:22.868 = the preload start = `retained`; tracking needs 16:59:06 -> `RPL|ABORT|LATTICE_HISTORY|start_ms=1790960346000|retained=1790961082868`. C seg 14 the same (short cap, newest 17:04:14.697; long L3 17:11:23.663). The base prompt's preload rule (Claude's) is wrong when the sides differ; RT14 seeds one side only | `research/replay/inputs/eurusd_20261008/seed_24.csv`, `seed_14.csv`; R4 logs | DEFECT (base design) |
| G2 | **Sync runs abort mid-segment when a real deal brings the TRUE book's side to cap whose newest true layer opened long ago.** The sync reset (A1) gives the replay that capped side; the EA starts tracking from its newest open; the harness has pruned its tick list to 300 s (core 858-884). D seg 21 sync: tracking needs 1 Oct 17:46:57 server, `retained` 18:32:09.708 (= the prune cutoff 300 s before the tick); C seg 11 sync: 17:46:47 vs 18:32:36; B seg 1 sync: 08:01:25 vs 12:16:40 | R4 logs | DEFECT (sync) |
| G3 | The EA reads ticks older than the current tick ONLY when a side with depth >= cap is not yet tracking: it then reads from max(newest open + 1 s, now - `GRIND_VL_CATCHUP_MAX_SEC`) and advances `from_msc` to the last tick + 1 (`ea/grind_engine.mqh` 800-892). A side below cap resets tracking (800-822). The roll gate's hold and the init restart set tracking with `from_msc = now + 1` (1207-1220, 1223-1231), reading no history. So history is needed once per capped episode, at its start | source | FACT |
| G4 | Every tick of the file is in memory during a run (`g_rpl_all_ticks`, sorted, copied per segment by `Rpl_RunTicks`) | core (Rpl_RunTicks) | FACT |
| G5 | `Rpl_PruneLattice` drops by the STORED msc (whole seconds) against a cutoff that is not a whole second (`tick_ms - 300000`, core 860-865) and sets `retained` to that cutoff (876-877). A tick whose raw ms is at or after the cutoff but in the cutoff's second is dropped while `retained` says it is kept. So a backfill keyed on raw ms `< retained` would lose that second; L1 keys on the stored second against the oldest stored entry instead (`Rpl_OldestLatticeMs`, core 815-823). The current tick is in the array before the call (`Grind_LatticeTestAddTick`, core 1324), so it is never empty there | source | FACT |

## 2. FIX (commit 2; core only)

| # | Fix |
|---|---|
| L1 | New `void Rpl_EnsureLatticeHistory(const long t)` called in `Rpl_ProcessOneTick` IMMEDIATELY BEFORE `Grind_LatticeOnTick` (core 1349; after `Grind_ProcessCloseByQueues` and its seam check). For each side (long, short): skip unless `ArraySize(<side>.layers) >= g_rpl_cfg.cap` AND that side's `g_grind_vl_tracking_*` is false. Then `newest` = the latest open time over the side's layers with a non-zero `position_ticket`, read with the EA's own `Grind_CarryPositionOpenTime(pos, g_rpl_cfg.magic, ot)` (as `ea/grind_engine.mqh` 831-834; skip the side if it returns false); `need = MathMax((long)(newest + 1) * 1000, (long)((datetime)(t / 1000) - GRIND_VL_CATCHUP_MAX_SEC) * 1000)` (the EA's formula, 841-842). If `need < g_rpl_retained_from_ms`: let `front = Rpl_OldestLatticeMs()` and, for each tick of `g_rpl_all_ticks`, `s = (long)((datetime)(time_msc / 1000)) * 1000` (the seam's stored value); insert at the FRONT of the three lattice arrays, in time order, every tick with `need <= s < front` (G5: by stored second, NOT raw ms against `retained`), stored as the seam stores it (`s`, bid, ask; count first, then one resize with `RPL_LATTICE_RESERVE`, shift the existing entries back, fill the front); then set `g_rpl_retained_from_ms = MathMax(need, g_rpl_all_ticks[0].time_msc)` (never earlier than the file reaches: a history the file does not hold must still abort, RT14); increment a global `int g_rpl_lattice_backfills` (reset to 0 in `Rpl_ResetAll`); print `RPL|LATTICE_BACKFILL|<L or S>|need=<ms>|count=<n>`. Nothing else changes: the preload, the prune, `Rpl_LatticeHistoryCheck` (now a guard that should never fire on real data) and every EA call stay as they are |

## 3. COMMITS AND TESTS

**Commit 1: tests only** (`ea/fxgrind_replay_tests.mq5`), plus the global
`int g_rpl_lattice_backfills = 0;` and an EMPTY stub of
`Rpl_EnsureLatticeHistory` in the core (not yet called) so the file compiles.

- **T12 RT38 two sides, the capped side's history older than the other
  side's newest open (4 assertions, F: 3 fail at commit 1).**
  `Rpl_ResetAll()`; `Rpl_DefaultConfig(cfg)`; `cfg.cap = 2`; gate -1 (the
  default); `cfg.from_ms = RplMs(RPL_T0, 0)`, `cfg.to_ms = RplMs(RPL_T0, 3)`;
  `Rpl_ConfigureEngine(cfg)`. Seed short S0 1.10500 opened `RplMs(RPL_T0, -900)`
  ticket 9101, short S1 1.10570 opened `RplMs(RPL_T0, -600)` ticket 9102
  (short at cap 2), long L0 1.09900 opened `RplMs(RPL_T0, -60)` ticket 9103
  (the newest open: the preload starts at T-60 s). Ticks: one a second from
  T-900 s to T+2 s inclusive (903 ticks), bid 1.10000 except at T-300 s bid
  1.10300, ask = bid + 0.00002. `Rpl_RunTicks(ticks, 903, cfg)`. Expect:
  `AssertFalse("RT38 no abort", Rpl_WasAborted())`;
  `AssertTrue("RT38 short tracking", g_grind_vl_tracking_short)`;
  `AssertNear("RT38 short extreme", g_grind_vl_extreme_short, 1.10300, 1e-9)`
  (the highest bid since T-599 s, read from the backfilled history; the
  short level is 1.10570 + 7 pips = 1.10640, so no roll);
  `AssertTrue("RT38 one backfill", g_rpl_lattice_backfills == 1)` (three
  ticks, one episode). At commit 1 the first three fail (the run aborts,
  the extreme folds only from T-60 s, no backfill); the tracking flag is set
  by the EA either way.

Totals: **295 run** (291 + 4). RT14 is unchanged and must still pass (its
second half's file starts at T: L1 cannot lower `retained` below it).

**Commit 2: L1**, core only; the tests file is NOT touched. If a test fails
and you believe its expected value is wrong, STOP and report with source
lines; never change an expected value.

Push after each. Do not compile.

## 4. RUNNING (after the operator compiles BOTH replay files in `D:\mt5-replay` and says "compiled")

- **R0** Pin, copy `ea\*` to `D:\mt5-replay\MQL5\Scripts\fxmatrix\`, SHA-256 count.
- **R1** The suite (tag `rt_<commit 2 sha7>`). Predicted **295 run, 295
  pass**. Report every `RPL|` and `FAIL |` line. Any FAIL: STOP.
- **R2** The suite overwrote `swaps.csv` (first-run F8): copy the 41 input
  files again from `main` at M = `2ec35db` exactly as the first run's R2,
  and check all 41 SHA-256 against the manifest, and w2's
  (`db2ea941...bd28`, still in place).
- **R4** The six runs in the first run's order (`eurusd_d` free, sync;
  `eurusd_c` free, sync; `eurusd_b` free, sync), `swaps.csv`'s SHA-256
  re-checked before each. Report every `RPL|` line (including each
  `LATTICE_BACKFILL`) and each summary.
- **R5** Commit each run's outputs to `research/replay/runs/<tag>_<free|sync>_<commit 2 sha7>/`
  as the first run's R5. Push. STOP.

Negative space, failure modes and the hash rules: the first-run prompt s5
and s6, unchanged. Do not analyse the outputs: Claude reads them.

## 5. NOT IN THIS FIX

The replay-versus-archive comparison (T1, T2, the miss table) is Claude's,
in Python, after R5. C seg 11's free run being hotter than the record
(73 fills against 45) is for that comparison, not for this fix.

## 6. FOR GEMINI (attack the premises; say which fact is missing)

- **GF1-1.** G3: the EA reads history only when a capped side starts
  tracking (`ea/grind_engine.mqh` 825-846, 858-879); the gate hold and the
  init restart set `from_msc = now + 1`. So L1 runs at most once per capped
  episode and the 300 s prune then drops the old ticks. Is there another EA
  path that reads ticks older than the current one?
- **GF1-2.** L1 lowers `retained` only to `max(need, the file's first
  tick)`: a capped side whose history predates the tick file still aborts
  (RT14's second half). Right rule, or should the replay start such a side
  from the file's first tick?
- **GF1-3.** L1 fixes both G1 (a preload that started too late) and G2 (sync)
  with one mechanism instead of changing the preload rule. Any case the
  preload covered that L1 does not?
- **GF1-4.** What fact is missing?

## 7. GEMINI'S RULINGS AND CLAUDE'S CHECK

(To be added before this file goes to Cursor.)

Line count: 118
