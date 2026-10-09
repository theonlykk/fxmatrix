This message has a line count at the bottom

# CURSOR PROMPT -- REPLAY HARNESS: THE RUNNER'S FIRST REAL RUN (EURUSD B / C / D, 29 SEGMENTS)

**Workspace: `D:\fxmatrix`. Branch `replay-harness`** (your branch; tip
`8cea613`, code `53fbe90`). Merge NOTHING; `main` only supplies the input
files (s4 step R2): `main` at the commit that carries THIS file (call
it M; report it). Written by Claude 9 Oct ~13:30Z from the branch at
`8cea613` and `main` at `efc7bb8`. Line numbers below are `53fbe90`'s.
Questions for Gemini are in s7; his rulings will be added in s8 before you
get this file.

The harness has passed its suite (267 run, 266 pass at `53fbe90`; the one
FAIL is RT15, a test defect, fixed here). Its runner
`ea/fxgrind_replay.mq5` has never read real input files. This prompt makes
it fit for a real run (fixes R1-R6, no behaviour change in the replay
rules) and then runs it.

## 0. RESTATE AND STOP (do this first, then wait)

1. `git checkout replay-harness`, `git pull`, and report `git log --oneline -1`
   (must be `8cea613`) and `git diff --stat 5bb5fdb origin/main -- ea/fxgrind.mq5`
   (must be EMPTY: the pin, base prompt s5 step 0).
2. Restate each of R1-R6 (s2) and T7-T11 (s3) in ONE line, quoting this
   prompt; give each test's assertion count and F / G tag.
3. Report anything in s1 you read differently in source, with file and line.
4. STOP. Edit nothing until the operator replies "go".

## 1. FINDINGS (Claude, at `53fbe90`)

| # | Finding | Where | Kind |
|---|---|---|---|
| F1 | `Rpl_LoadTicksCsv` grows `out` one element at a time (`ArrayResize(out, count + 1)`, no reserve): quadratic copying. The real tick file holds 476,821 ticks (`ticks_53077984_EURUSD_w2.csv`, 16,430,291 bytes) | core 1789-1823, resize 1814 | PERF (blocking) |
| F2 | `Rpl_PruneLattice` runs on EVERY tick and rebuilds the list through three local arrays grown one element at a time, then copies them back | core 834-861; called core 1359 | PERF |
| F3 | `Rpl_PreloadLatticeFromTicks` adds up to 24 h of ticks one by one through the EA seam `Grind_LatticeTestAddTick` (`ea/grind_engine.mqh` 723-732: `ArrayResize(n + 1)` per tick on three arrays). A seeded segment at cap preloads hours (C seg 11: from 1 Oct 06:01:24 server). The EA file may NOT change | core 691-703 | PERF |
| F4 | `Rpl_WriteDealOutput`, `Rpl_WriteEventOutput` and `Rpl_ReplayAppendDeal` grow by one element each call | core 718, 745-747, 763-766 | PERF (minor) |
| F5 | Output names are `out_<tag>_*` whatever `InpSync` is: a sync run and a free run of one tag overwrite each other | core 1850; runner 11-32 | DEFECT (real runs) |
| F6 | Nothing is printed between `RPL|SYMBOL_READY` and `RPL|DONE`: a long run cannot be followed in the log | runner; core 1941-2135 | OBSERVABILITY |
| F7 | RT15 "swap after first tick" is asserted after ALL three ticks (got -0.08067, the correct one-night value): a test defect (HANDOFF s71) | tests 634-672, line 670 | TEST |
| F8 | The suite WRITES `MQL5\Files\replay\swaps.csv` (RT19 784-785, others): running the suite after the real inputs are copied overwrites the real `swaps.csv` | tests 782-785 | RUN ORDER |

## 2. FIXES (commit 2; core and runner only)

| # | Fix |
|---|---|
| R1 | F1: in `Rpl_LoadTicksCsv` grow with a reserve: `ArrayResize(out, count + 1, 65536)`. Nothing else changes |
| R2 | F2: `Rpl_PruneLattice` compacts IN PLACE: one pass with a write index `j` over `g_grind_vl_test_tick_msc / _bid / _ask`, keeping `msc[i] >= cutoff` in their existing ORDER (do NOT assume the list is sorted), then `ArrayResize(<each>, j, RPL_LATTICE_RESERVE)` with `#define RPL_LATTICE_RESERVE 200000`. No local arrays. The `g_rpl_retained_from_ms` update stays as it is |
| R3 | F3: `Rpl_PreloadLatticeFromTicks` writes the preload into the three EA arrays DIRECTLY instead of calling the seam per tick: count the ticks `k` with `start_ms <= ms < cfg.from_ms`; resize each array ONCE to `n0 + k` (n0 = its current size; reserve `RPL_LATTICE_RESERVE`); fill in tick order with exactly what the seam stores: `msc = (long)((datetime)(ms / 1000)) * 1000` (whole seconds), `bid`, `ask`. `g_rpl_retained_from_ms` as now. The per-tick add in `Rpl_ProcessOneTick` (core 1308) stays the EA seam |
| R4 | F4: the three appenders grow with a reserve of 4096 (`ArrayResize(<arr>, n + 1, 4096)`) |
| R5 | F5: a global `string g_rpl_out_suffix = ""` and `void Rpl_SetOutputSuffix(const string s)`; `Rpl_OpenRunOutputs` uses `"replay\\out_" + tag + g_rpl_out_suffix + "_"`. `Rpl_ResetAll` does NOT touch it. The runner calls `Rpl_SetOutputSuffix(InpSync ? "_sync" : "_free")` before `Rpl_RunReplayFiles` (input files are still found by the plain tag) |
| R6 | F6: prints (no behaviour): the runner `RPL|RUN|<tag>|sync=<0/1>|out=<tag><suffix>` after `RPL|SYMBOL_READY`; `Rpl_RunReplayFiles` prints `RPL|TICKS_LOADED|<file>|count=<n>|load_ms=<ms>` after each tick-file load, `RPL|SEG|<seg_id>|from=<ms>|to=<ms>|seed=<file or empty>` at each segment start, and after each segment `RPL|SEG_DONE|` + the same fields as its summary line |

## 3. COMMITS AND TESTS (`ea/fxgrind_replay_tests.mq5`; F = fails at commit 1, G = guard)

**Commit 1: tests only**, plus a STUB `Rpl_SetOutputSuffix` in the core
(empty body) so the file compiles. Message: each changed or new test with
its EXACT assertion count, and the total.

- **T7 (RT15, F7; 2 assertions, G):** before the full run (line 669), run
  the same seeded segment with `to_ms = RplMs(D'2026.10.06 23:59:59', 0) + 1`
  (ticks 0 and 1 only), assert `"RT15 swap before midnight"` = 0.0 (1e-9);
  then `Rpl_ResetAll()`, `Rpl_ConfigureEngine(cfg2)`, the same
  `Rpl_SeedLayer(...)` (line 658), the full run (line 669) and the
  existing `"RT15 swap 10.07 night"` = -0.08067. Delete line 670. (The test
  swaps of 636-637 survive `Rpl_ResetAll`: the current test relies on it.)
- **T8 RT34 prune (8 assertions, G):** `Rpl_ResetAll()`; T =
  `D'2026.10.06 10:00:00'`; add through `Grind_LatticeTestAddTick` in THIS
  order: (T-10 s, 1.10000, 1.10002), (T-400 s, 1.20000, 1.20002), (T-300 s,
  1.30000, 1.30002), (T-301 s, 1.40000, 1.40002); `Rpl_PruneLattice((long)T * 1000)`.
  Expect: size 2; msc[0] = (T-10)*1000, msc[1] = (T-300)*1000; bid 1.10000,
  1.30000; ask 1.10002, 1.30002; `g_rpl_retained_from_ms` = (T-300)*1000.
- **T9 RT35 loader (6 assertions, G):** write `replay\\rt35_ticks.csv`: a `#`
  line, the header `time_msc_server,bid,ask,flags`, then 200,000 rows i =
  0..199999: time = 1790812800000 + 500 i, bid = 1.10000 + (i % 100) x
  0.00001 (5 decimals), ask = bid + 0.00002, flags 6. `Rpl_LoadTicksCsv`:
  returns true; count 200000; out[0].time_msc 1790812800000; out[199999]
  .time_msc 1790912799500; out[199999].bid 1.10099; out[199999].ask
  1.10101 (1e-9). Print `RT35-LOAD-MS|<ms>`.
- **T10 RT36 output suffix (3 assertions, F: 2 fail at commit 1):** RT19's
  setup with the tag `rt36` (its own files); `Rpl_SetOutputSuffix("_free")`;
  `Rpl_RunReplayFiles("rt36", false)` true; `FileIsExist("replay\\out_rt36_free_deals.csv")`
  true; `FileIsExist("replay\\out_rt36_free_summary.txt")` true; then
  `Rpl_SetOutputSuffix("")`.
- **T11 RT37 preload content (7 assertions, G):** `Rpl_ResetAll()`; seed one
  long layer opened at T-1 h (`Rpl_SeedLayer`); fill `g_rpl_all_ticks` /
  `g_rpl_all_tick_count` with three ticks at T+250 ms (1.10000 / 1.10002),
  T+1999 ms (1.10010 / 1.10012), T+2000 ms (1.10020 / 1.10022); a config
  with `from_ms` = T+5 s; `Rpl_PreloadLatticeFromTicks(cfg)`. Expect size 3;
  msc T*1000, (T+1)*1000, (T+2)*1000 (whole seconds); bid 1.10000, 1.10010,
  1.10020.

Totals: **291 run** (267 + RT34 8 + RT35 6 + RT36 3 + RT37 7; RT15 stays 2).
At commit 1 RT36's two file checks fail; nothing else is predicted to fail.

**Commit 2: R1-R6**, core and runner only. The tests file is NOT touched.
If a test fails and you believe its expected value is wrong, STOP and
report with source lines; never change an expected value.

Push after each commit. Do not compile.

## 4. RUNNING (after commit 2; the operator compiles BOTH replay files in `D:\mt5-replay`'s MetaEditor and says "compiled")

- **R0** Pin (base s5 step 0) and copy `ea\*.mq5`, `ea\*.mqh` to
  `D:\mt5-replay\MQL5\Scripts\fxmatrix\`, confirmed by SHA-256 (count).
- **R1 The suite** (tag `rt_<commit 2 sha7>`, as before). Predicted: 291
  run, 291 pass. Report every `RPL|` line, every `FAIL |` line and
  `RT35-LOAD-MS`. Any FAIL: STOP.
- **R2 The inputs** (only AFTER R1: F8). From `main` at M (`git show
  M:<path>`, never a checkout of `main`) copy the 40 files of
  `research/replay/inputs/eurusd_20261008/` to `D:\mt5-replay\MQL5\Files\replay\`,
  and `C:\Users\Khalid Khan\Downloads\ticks_53077984_EURUSD_w2.csv` there
  too. Check: w2's SHA-256 is
  `db2ea94173a4d0c8746c7fecc972c8950da79c803910a25e0bbc522bc63abd28`;
  each input file's SHA-256 equals the matching line of
  `research/replay/inputs/eurusd_20261008.sha256` (the LF bytes `git show`
  gives; report any mismatch, do not "fix" one).
- **R3 The smoke run:** `fxgrind_replay` with `InpRunTag=eurusd_d_smoke`,
  `InpSync=false` (a preset in `MQL5\Presets` passed by `ScriptParameters`;
  the `.ini` UTF-16 LE). Expected log: `RPL|RUN|eurusd_d_smoke|sync=0|out=eurusd_d_smoke_free`,
  `TICKS_LOADED` 476821, two `SEG` / `SEG_DONE` (20 and 21), `RPL|DONE`.
  Report every `RPL|` line verbatim and `out_eurusd_d_smoke_free_summary.txt`.
  STOP after R3 and wait for "go" (Claude reads the outputs first).
- **R4 The six runs** (after "go"), one at a time, in this order:
  `eurusd_d` free, `eurusd_d` sync, `eurusd_c` free, `eurusd_c` sync,
  `eurusd_b` free, `eurusd_b` sync. Before each, re-check `swaps.csv`'s
  SHA-256 (R2). After each: every `RPL|` line verbatim and the summary file.
- **R5 Commit** each run's outputs to `research/replay/runs/<tag>_<free|sync>_<commit 2 sha7>/`
  (`out_*` files and the `RPL|` lines as `log_excerpt.txt`); a file over 5
  MB is NOT committed: report its size and SHA-256 instead. Push.

Do not analyse or compare the outputs: Claude reads them.

## 5. NEGATIVE SPACE

- Change ONLY `ea/fxgrind_replay_core.mqh`, `ea/fxgrind_replay.mq5`,
  `ea/fxgrind_replay_tests.mq5` (and `research/replay/runs/`). No EA file
  (`ea/fxgrind.mq5`, `ea/grind_*.mqh`), no change to any replay RULE
  (fills, sync, seeding, rollover, close-by, timer, intervals).
- R3 writes the EA's arrays only in the preload, with the seam's exact
  values; nowhere else.
- Do not compile; do not run anything on the desktop's main terminal, the
  VPS or the Linux boxes; only `D:\mt5-replay`.
- Do not check out `main`, merge, open a PR, `git stash`, check out files
  from other commits (`git show M:<path>` to copy is allowed in R2), `git add .`
  or `-u`.
- Do not commit tick files or any file over 5 MB.

## 6. FAILURE MODES (STOP and report; do not improvise)

- Any `RPL|ABORT` (including `MISSING_*`, `BAD_*`, `LATTICE_HISTORY`,
  `SEAMS`, `NO_TICK_VALUE`). An abort naming `calib` means the inputs
  were not applied (the preset did not reach the script).
- A run that has printed no new `RPL|SEG` line for 30 minutes, or any
  single run over 2 hours: report the last `RPL|` line.
- A hash mismatch in R2 or before a run.
- A test that fails, or passes when predicted to fail.

## 7. FOR GEMINI (attack the premises; say which fact is missing)

- **GH6-1.** R1-R4 claim no behaviour change: reserve-only growth, an
  in-place prune that keeps order and the `>= cutoff` rule, and a preload
  that writes the seam's exact values (whole seconds) directly. RT34 and
  RT37 guard the last two. Is any EA read path sensitive to the arrays'
  CAPACITY rather than their size, or to the preload being written in one
  resize?
- **GH6-2.** Run order: the suite first, then the inputs (F8: the suite
  overwrites `swaps.csv`); a two-segment smoke run (D's flat start and 15 h
  from a seed, with D's API soft-warn interval) before the six real runs.
  Enough, or should the smoke also cover a segment seeded AT CAP (C seg 11)?
- **GH6-3.** `swaps.csv` carries EFFECTIVE points (each night's broker
  charge at 0.01 lot rounded to the cent / (mult x 0.01); a `#` line says
  so): the harness's unrounded `points x mult x tick_value x volume`
  (base s3.4 step 1) then books the broker's cent exactly. Measured: 626
  of 626 closed EURUSD positions and 69 of 69 EA carry ledgers match the
  per-night-rounded model exactly. Any harness path that reads the points
  as a RATE (e.g. the carry pass's pending part, which reads the LIVE
  `SYMBOL_SWAP_LONG`, base s1 A13) and would now disagree?
- **GH6-4.** Free runs (T2) and sync runs (T1) write separate outputs (R5).
  Claude compares them with the archive afterwards (plan s6 marks, fixed).
  What fact is missing before the first comparison?

## 8. GEMINI'S RULINGS AND CLAUDE'S CHECK

(To be added before this file goes to Cursor.)

Line count: 186
