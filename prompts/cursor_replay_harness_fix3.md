This message has a line count at the bottom

# CURSOR PROMPT -- REPLAY HARNESS FIX 3 (branch `replay-harness`, on `fc0fb26`)

**Workspace: `D:\fxmatrix`.** Continue on branch `replay-harness` at
`fc0fb26` (`22aa998` fix-2 tests, `fc0fb26` fix-2 implementation). Read
`prompts/cursor_replay_harness.md`, `..._fix1.md`, `..._fix2.md` and THIS
file. Claude read `fc0fb26` (8 Oct ~04:10Z; E1-E7) and again (~04:50Z;
E8-E11). Line numbers are `ea/fxgrind_replay_core.mqh` and
`ea/fxgrind_replay_tests.mq5` at `fc0fb26`. Defects only, no design change.
**The operator's desktop syntax compile at `fc0fb26` (8 Oct ~04:42Z):
`fxgrind_replay_tests.mq5` 0 errors, 0 warnings; `fxgrind_replay.mq5`
(its first compile; `desktop_sync.ps1` puts it in `MQL5\Experts\`) 0
errors, 0 warnings.** One question for Gemini in s5.

Fix 2's Y4-Y8 are in and correct (outputs opened once per run; intervals
applied after the sync rows and before the market seeds; real rows
partitioned per segment after the seed; a removed layer purges both
tickets from the position seam, close-by seam, metas and queue; one summary
line per segment; GV deletion only in `fxgrind_replay.mq5`). Moving the
config defaults into the core (`Rpl_SegmentConfigDefaults`) was right: at
`8a92e22` the core called the tests file's `Rpl_DefaultConfig`, so
`fxgrind_replay.mq5` could not have compiled. But the commit message did not
say so (E7).

## 0. RESTATE AND STOP

1. `git log --oneline origin/main..HEAD` starts `fc0fb26`, `22aa998`,
   `8a92e22`; otherwise STOP.
2. Restate E1-E11, Z1-Z5 and every test change of s3 in one line each, with
   each test's EXACT assertion count and the number that FAIL at commit 1.
3. STOP until "go".

## 1. FINDINGS (verified at `fc0fb26`)

| # | Finding | Where |
|---|---|---|
| E1 | `Rpl_CsvReadLineFields` tests `FileIsLineEnding(h)` BEFORE its first read. MQL5 sets that flag when a read reaches a line end and it stays set until the next read, so after line 1 every later call returns no fields and the loop ends: every reader (ticks, swaps, run, seed, real, intervals) would load the first line only, i.e. nothing. RT22 would catch it; the do-while form in Z1 is right whichever way the flag behaves. A blank line would also become a row with time 0. `Rpl_CsvSkipLine` has the same flaw and is unused | core 1572-1594 |
| E2 | A file with no header line loses its first data row silently (the first non-`#` line is skipped as the header whatever it holds). RT25 shows it: `real_rt25.csv` has no header, so its one `OUT_BY` row is dropped | core readers; tests 929-931 |
| E3 | A run row with fewer than 22 fields is skipped silently (`if(ArraySize(fields) < 22) continue;`): a segment would vanish from the run | core 1898 |
| E4 | Tests read a header with ONE `FileReadString` on a `FILE_CSV` handle, which returns one field (fix 2's D3, in the tests): RT11 (532-533) and RT19 (792-793) compare `"seg_id"` with the full header and always fail; RT25 (944) then reads the book seven fields at a time one field out of step, so `side` is never `"L"` and it always fails. Claude approved these tests | tests 532, 792, 944 |
| E5 | RT24 calls `Rpl_SetTestIntervals` BEFORE `Rpl_ResetAll`, which (rightly) now clears the test intervals: the first run is not gated and its first assertion fails | tests 887-888 |
| E6 | RT23's segment checks (`",1,"`, `",2,"` anywhere in the file) match layer or flag columns; data lines start with `seg_id` | tests 868-869 |
| E7 | Process: `22aa998`'s counts are not exact (RT24 has 3 assertions and is given 4 F; at that commit its tick-1 assertions pass). `fc0fb26` changed things outside Y3-Y8 (`Rpl_SegmentConfigDefaults`, `RPL_T0_DEFAULT`) without saying so | commit messages |
| E8 | A missing `swaps.csv` is silent: `Rpl_RunReplayFiles` opens it and, when the handle is invalid, carries on with NO swap rows, so every rollover adds 0 swap. Every other input file aborts when missing. (Base s3.2 did not say; Claude's gap, ruled 8 Oct ~04:30Z: abort) | core 1848-1868 |
| E9 | RT18 reads the LAST two deal rows, but tick 3 also closes L00 by close-by (base s3.4 step 6, same tick), so the last two rows are the OUT_BY pair (side L), not the two IN fills: "RT18 first S00" fails against a correct harness. The rows are: 0 IN BUY ENT L 0 1.09981 t2; 1 IN SELL ENT S 0 1.10151 t3 (placed at tick 1); 2 IN SELL EXT L 0 1.10081 t3 (placed at tick 2); 3-4 OUT_BY. `>= 2` where the count is exact (5) | tests 757-763 |
| E10 | RT19 "four rows" counts FIELDS (one `FileReadString` per field on a `FILE_CSV` handle) and asserts `rows >= 5`: true for any non-empty file. Fix 1's RT19 says the header and 4 rows | tests 794-800 |
| E11 | RT23 asserts `nl >= 2` where fix 2's RT23 says exactly 2 summary lines | tests 874 |

## 2. FIXES (commit 2, core only)

| # | Fix |
|---|---|
| Z1 | E1: `Rpl_CsvReadLineFields` returns false only at file end; otherwise it reads in a do-while: `do { fields[n++] = FileReadString(h); } while(!FileIsLineEnding(h) && !FileIsEnding(h));` (array grown as now). Every reader `continue`s on a line whose fields are all empty. Delete `Rpl_CsvSkipLine` |
| Z2 | E2: in every reader the first line that is not blank and not `#` must have `fields[0]` equal to its first column name (`time_msc_server` ticks, `time_ms` real, `kind` intervals, `server_date` swaps, `seg_id` run, `side` seed); otherwise print `RPL|BAD_HEADER|<file>|<fields[0]>` and fail: `Rpl_LoadTicksCsv` and `Rpl_LoadRealCsvFile` return false (callers abort as now), `Rpl_LoadIntervalsFile` becomes `bool` (missing file = true with no intervals; bad header = false -> `RPL|ABORT|BAD_INTERVALS`), swaps and seed abort `BAD_SWAPS` / `BAD_SEED`, the run file `BAD_RUN` |
| Z3 | E3: a run row with fewer than 22 fields -> `RPL|ABORT|BAD_RUN_ROW|seg_line=<n>|fields=<k>`, close files, return false |
| Z4 | On every return from `Rpl_RunReplayFiles`, clear the file intervals and the real file rows, so a later `Rpl_RunTicks` inherits neither |
| Z5 | E8: `swaps.csv` missing -> print `RPL|ABORT|MISSING_SWAPS` and return false, BEFORE the run file is opened and before any output file is opened |

## 3. COMMITS AND TEST CHANGES

1. **Tests**, exactly these changes (Claude authorises them; nothing else
   in the tests file). The message gives, for each changed or new test, its
   EXACT assertion count and how many FAIL at this commit, and the total.
   - `Rpl_DefaultConfig` (55-79): body becomes `Rpl_SegmentConfigDefaults(cfg);`
     (same values; one source).
   - RT11 (532) and RT19 (792): after `string hdr = FileReadString(h);` add
     `for(int k = 1; k < 12; k++) hdr += "," + FileReadString(h);`
   - RT25 (944): `FileReadString(h);` becomes
     `for(int k = 0; k < 7; k++) FileReadString(h);`
   - RT25 (929-931): write `time_ms,kind,side,layer,price,position_id,level`
     before the `OUT_BY` row.
   - RT24 (887-888): `Rpl_ResetAll();` first, then `Rpl_SetTestIntervals(...)`.
   - RT23 (868-869): `",1,"` -> `"\n1,"` and `",2,"` -> `"\n2,"` (all four).
   - **RT28** (new; Z1, Z2): write `replay\ticks_rt28.csv` (`FILE_TXT`) as one
     line `<T0 ms>,1.10000,1.10002,6`: `Rpl_LoadTicksCsv` returns false.
     Write `replay\ticks_rt28b.csv` as `time_msc_server,bid,ask,flags`,
     `<T0 ms>,1.10000,1.10002,6`, an empty line, `<T0+1 s ms>,1.10010,1.10012,2`:
     returns true, count 2, tick 1 bid 1.10010. (4 assertions)
   - **RT29** (new; Z3): `run_rt29.csv` = the RT11 header and RT11's row
     with its last field (`ticks_file`) removed (21 fields):
     `Rpl_RunReplayFiles("rt29", false)` returns false. (1 assertion)
   - RT18 (E9; 757-763): replace the `AssertTrue("RT18 two IN same tick", ...)`
     line and the six lines after it (`RplDealRow a, b;` through
     `AssertEqStr("RT18 second EXT", ...)`) with exactly these six:
     `const long t2 = RplMs(RPL_T0, 2);`
     `const long t3 = RplMs(RPL_T0, 3);`
     `AssertTrue("RT18 deals count 5", Rpl_DealsCount() == 5);`
     `AssertDealRow("RT18 row0", 0, DEAL_TYPE_BUY, "ENT", "L", 0, 1.09981, t2);`
     `AssertDealRow("RT18 row1", 1, DEAL_TYPE_SELL, "ENT", "S", 0, 1.10151, t3);`
     `AssertDealRow("RT18 row2", 2, DEAL_TYPE_SELL, "EXT", "L", 0, 1.10081, t3);`
     (22 assertions: `AssertDealRow` makes 7.)
   - RT19 (E10; 800): `AssertTrue("RT19 four rows", rows >= 5);` becomes
     `string l19[];` and
     `AssertTrue("RT19 five lines", StringSplit(Rpl_ReadWholeFile(dir + "out_rt19_deals.csv"), '\n', l19) == 5);`
     (the header and 4 rows; `Rpl_ReadWholeFile` adds no trailing newline).
     If the compiler wants it declared first, add the one line
     `string Rpl_ReadWholeFile(const string rel_path);` directly above
     `void Test_RT19_ReplayFiles()`; nothing else.
   - RT23 (E11; 874): `nl >= 2` -> `nl == 2`.
   - **RT30** (new; Z5): write `replay\run_rt30.csv` with RT19's header and
     RT19's row (its `ticks_file` stays `ticks_rt19.csv`, written by RT19
     and RT27 earlier in the runner); `FileDelete("replay\\swaps.csv")`;
     assert `Rpl_RunReplayFiles("rt30", false)` is false and
     `FileIsExist("replay\\out_rt30_deals.csv")` is false (2 assertions);
     then write `replay\swaps.csv` again exactly as RT19 does (header and
     the `2026.10.06` row), so later tests find it.
   - Register RT28, RT29 and RT30, in that order, after `Test_RT27_SummaryCounts();`
     in `OnStart`.
2. **Z1-Z5**, core only. The tests file is NOT touched. If a test cannot
   pass as written, STOP and report.

Push after each. Do not compile; the operator compiles BOTH
`fxgrind_replay_tests.mq5` and `fxgrind_replay.mq5` on the desktop.

## 4. NEGATIVE SPACE

As before: no new inputs; no change to any expected value; nothing outside
Z1-Z5 in commit 2, and anything you find you must change is named in the
message with its reason.

## 5. FOR GEMINI (attack the premises; say which fact is missing)

- **GH3-1.** E9 rests on the close-by completing on the SAME tick as the
  exit fill (base s3.4 steps 4-6; fix 2 s7), so RT18's OUT_BY pair follows
  its two IN rows. E1-E11 are defects against the base prompt and fixes 1-2
  as ruled; Z1-Z5 change no design. What fact is missing?

Line count: 129
