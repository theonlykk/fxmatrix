This message has a line count at the bottom

# CURSOR PROMPT -- REPLAY HARNESS FIX 2 (branch `replay-harness`, on `8a92e22`)

**Workspace: `D:\fxmatrix`.** Continue on branch `replay-harness` at
`8a92e22` (`0c3d5ef` fix-1 tests, `8a92e22` fix-1 implementation). Read
`prompts/cursor_replay_harness.md`, `prompts/cursor_replay_harness_fix1.md`
and THIS file. Claude read `8a92e22` (8 Oct ~03:50Z); the operator compiled
`ea/fxgrind_replay_tests.mq5` on the desktop for syntax only (8 Oct
03:51Z): **1 error, 1 warning** (D1, D2). Line numbers are
`ea/fxgrind_replay_core.mqh` at `8a92e22`. Questions for Gemini in s6; his
rulings and Claude's check in s7 (8 Oct ~03:58Z): no change to s1-s5.

Fix 1's X1-X4, X6-X16 are in and correct; what is left is below. D7 is a
gap in fix 1's A1 wording (Claude's), not your work.

## 0. RESTATE AND STOP

1. `git log --oneline origin/main..HEAD` = `8a92e22`, `0c3d5ef`, `a280736`,
   `f0b2445`; otherwise STOP.
2. Restate D1-D9 and every test of s4 in one line each, with its EXACT
   assertion count and F / G tag at commit 1.
3. STOP until "go".

## 1. FINDINGS (verified at `8a92e22`)

| # | Finding | Where |
|---|---|---|
| D1 | COMPILE ERROR "arrays are passed by reference only": `Rpl_SetSyncRealKindRows(const string csv_rows[], ...)` | core 1376 |
| D2 | WARNING "possible loss of data due to type conversion from 'long' to 'datetime'": `Grind_CarryTestSeedTick(t / 1000, ...)` | core 1162-1163 |
| D3 | Every CSV reader skips only the FIRST FIELD of a header line (`FileReadString` in `FILE_CSV` mode reads one field, not one line), so every later field is shifted: run, seed, swaps and tick files written with a full header parse wrongly (RT11, RT19). The wine-d dump parses only by luck (its `#` comment line has no comma) | core 1450-1451 (ticks), 1534-1535 (swaps), 1552-1553 (run), 1603-1604 (seed) |
| D4 | `Rpl_WriteSegmentOutputs` reopens every output file with `FILE_WRITE` after EACH segment and the rows are reset per segment: a run keeps only its last segment | core 1469-1526, 1621 |
| D5 | The intervals file (`intervals_<tag>.csv`: `BREAKER_GATED`, `API_SOFT_WARN`) is never read and never applied (base s3.2, s3.4 step 2; fix 1 X5) | core 1528-1626 |
| D6 | `real_<tag>.csv` (fix 1 A1) is never read by the run; only the test helper `Rpl_SetSyncRealKindRows` loads real rows, so sync cannot run from files | core 1376-1393, 1528-1626 |
| D7 | A sync removal (`Rpl_RemoveLayerByTicket`) deletes the layer and its exit ORDER but leaves its position (and an exit position awaiting close-by) in the position seam, the close-by seam, the position metas and any close-by queue task: ghost close-bys and swap on ghost positions | core 975-988, 990-1052 |
| D8 | `summary.txt` has no per-segment counts (base s3.6: ticks, fills, scalps, roll closes, `ROLL_ACCEPTED`, aborts, run time) and its writer calls `Rpl_DeleteGrindGlobalVariables()` (a side effect inside an output) | core 1517-1525 |
| D9 | Process: fix-1 commit 2 edited the tests file (RT11 and RT15 setup) against "no test changes"; commit 1 gave "~120F", not an exact count | `0c3d5ef..8a92e22` |

## 2. FIXES (commit 2)

| # | Fix |
|---|---|
| Y1 | D1: `const string &csv_rows[]` |
| Y2 | D2: `(datetime)(t / 1000)` at that call and at every other `long` -> `datetime` call |
| Y3 | D3: one helper `bool Rpl_CsvSkipLine(const int h)` that reads fields until `FileIsLineEnding(h)` or `FileIsEnding(h)`; every reader skips `#` lines and the header LINE with it, and reads data rows field by field to the line end (extra fields consumed, missing ones = empty) |
| Y4 | D4: open the four output files ONCE per run (header once), append each segment's rows after the segment, close at the end of the run |
| Y5 | D5: read `intervals_<tag>.csv` once per run (missing file = no intervals); at each tick, before the market seeds: `BREAKER_GATED` active -> `g_grind_breaker_enabled = true; g_grind_breaker_gated = true;` else both false; `API_SOFT_WARN` active -> `Grind_ApiLimitsSet(1000000, 1)` else `Grind_ApiLimitsSet(1000000, 999000)`. Test setter `Rpl_SetTestIntervals(kind[], from[], to[], n)` |
| Y6 | D6: when `sync` is true, read `real_<tag>.csv` once per run (fix 1 A1 columns; missing file = abort `MISSING_REAL`); each segment loads the rows with `from_ms <= time_ms < to_ms` after its `Rpl_ResetAll` and seed |
| Y7 | D7: removing a layer also removes its position ticket and, if non-zero, its `exit_position_ticket` from the position seam, the close-by seam, the position metas and any close-by queue task that names either |
| Y8 | D8: one summary line per segment: `seg_id=,ticks=,fills=,scalps=,roll_closes=,roll_accepted=,gaps=,aborted=,run_ms=` (ticks = processed ticks; fills = IN deals; scalps and roll_closes from the scalp events' `rolled` flag); GV deletion stays in `fxgrind_replay.mq5` only |

## 3. COMMITS

1. **Tests first** with Y1-Y2 applied (so the file compiles); the commit
   message gives, for each new or changed test, the EXACT number of
   assertions that fail at this commit, and the total.
2. **Y3-Y8.** The tests file is NOT touched in this commit, not even its
   setup. If a test cannot pass as written, STOP and report.

Push after each. Do not compile; the operator compiles on the desktop for
syntax and reports.

## 4. TESTS (new; existing tests unchanged)

- **RT22** (Y3): the test writes `replay\ticks_rt22.csv` as three lines
  `# comment, with, commas`, `time_msc_server,bid,ask,flags`,
  `<T0 ms>,1.10000,1.10002,6` and a fourth `<T0+1 s ms>,1.10010,1.10012,2`;
  `Rpl_LoadTicksCsv` returns 2 ticks; tick 0 = T0, 1.10000, 1.10002; tick 1
  = T0 + 1 s, 1.10010, 1.10012. (F)
- **RT23** (Y4): a run file with TWO segments (RT3's ticks: segment 1
  ticks 0-1, segment 2 ticks 2-3, both flat); `out_rt23_deals.csv` has ONE
  header line, and `seg_id` 1 and 2 both appear in `out_rt23_events.csv`
  or `_deals.csv`; `out_rt23_summary.txt` has exactly 2 lines starting
  `seg_id=1` and `seg_id=2`. (F)
- **RT24** (Y5): RT2's two ticks with `BREAKER_GATED` from T0 to T0 + 1 s
  (end exclusive) via `Rpl_SetTestIntervals`; run tick 0 alone: NO `L00 ENT`
  order; then tick 1 (not gated): `L00 ENT` at 1.09981 (mid 1.10001 - 2
  pips). (F)
- **RT25** (Y6): files for RT8 (seed 7001-7003, one `real_rt25.csv` row
  `<t2 - 1 ms>,OUT_BY,L,2,1.09841,7003,`) run with sync: `out_rt25_book.csv`
  has exactly two long rows, layers 0 and 1. (F)
- **RT26** (Y7): seed L00 7001, L01 7002, sync; real row `OUT_BY` for 7002
  before tick 1; after tick 1: `Rpl_HasPosition(7002)` false, and new
  accessors `Rpl_PositionSeamHas(7002)`, `Rpl_CloseBySeamHas(7002)`,
  `Rpl_PosMetaHas(7002)` all false. (F)
- **RT27** (Y8): RT19's run: `out_rt19_summary.txt` line 1 starts
  `seg_id=1,ticks=` and contains `fills=2,` and `scalps=1,`. (F)

## 5. NEGATIVE SPACE

As the base prompt s7 / s8 and fix 1 s6. Also: no new inputs on
`fxgrind_replay.mq5`; no change to any expected value; no test edit in
commit 2.

## 6. FOR GEMINI

- **GH2-1.** Y6: sync rows are partitioned by segment (each segment applies
  the real rows inside its own window, after its seed). Right, given that
  every segment starts from the TRUE book at an init?
- **GH2-2.** Y7: a removed layer takes its exit position with it even if
  that exit filled and its close-by is still queued. Anything lost?
- **GH2-3.** What fact is missing?

## 7. GEMINI'S RULINGS (8 OCT ~03:58Z) AND CLAUDE'S CHECK

- **GH2-1 ACCEPTED** (each segment starts from the true book at an init, so
  only the rows inside its own window apply).
- **GH2-2 REJECTED; Y7 stands.** His premise: removing a replay layer's
  exit position and queued close-by loses scalps and roll closes from T2.
  But SYNC runs only for T1; T2 runs free, without sync (calibration plan
  s6), so no sync removal ever touches a T2 count. T1 counts IN deals only;
  OUT_BY rows are bookkeeping (plan s6), and the replay's EXT IN deal is
  already written when it fills. The pending case is also near-empty: a
  close-by queued by a fill is sent and completed in the SAME tick (base
  s3.4 steps 4-6), before the next tick's sync rows apply; it can carry
  over only if a send fails, which the close-by seam does not do in the
  harness. And the layers sync removes are the replay's OWN (their tickets
  are never true tickets): nothing true is removed.
- **GH2-3 NOTED, no change.** The real rows are one EA instance's own deals
  (EURUSD's magic); no hand action or other EA closed a EURUSD position in
  the window (plan K20). The live EA learns a deal milliseconds after the
  broker's deal time (plan T0: deal times a median 260 ms after the
  touch), and T1 by design resets to the truth after every real deal to
  test one decision at a time; any head start is under one tick, inside
  T1's 60 s.

Line count: 127
