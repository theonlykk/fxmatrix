This message has a line count at the bottom

# REVIEW OF `docs/runbooks/plan4-window-export.md` AT `382622e`

Reviewer: Argon
Target: `docs/runbooks/plan4-window-export.md` at `382622e` (`main`)
Checked against:
- `docs/research/replay-calibration-eurusd-4.md` (plan 4, s2, s3, s4, s5, s7)
- `docs/runbooks/plan3-holdout-export.md` (run 13 Oct)
- `research/replay/inputs/eurusd_window_p4_raw.sha256`
- `research/replay/inputs/eurusd_holdout_raw.sha256`
- `research/replay/inputs/eurusd_holdout.sha256`
- `research/replay/inputs/eurusd_holdout_p4.sha256`
- `research/replay/inputs/eurusd_holdout_p4/run_eurusd_b.csv`
- `research/replay/inputs/eurusd_holdout_p4/sessions_eurusd_ic.csv`
- `research/replay/inputs/eurusd_holdout/swaps.csv`
- `scripts/grind_tick_dump.mq5`
- `research/replay/build_holdout.py`
- `research/replay/build_swaps.py`
- `research/replay/score_plan3.py`
- `research/replay/results/plan3/live_spread_n3.txt`
- `docs/research/replay-calibration-eurusd-3.md`
- `docs/runbooks/twoarm-build-d.md`
- `handoffs/Handover/02_TRAPS.md`
- `handoffs/HANDOFF_2026-09-24.md`

---

## 1. EXECUTIVE SUMMARY AND ANSWERS TO THE THREE QUESTIONS

1. **Is every name, time, span, input and STOP line right for plan 4's window?**
   **YES** for the Tuesday 20 Oct export steps (s0-s4, Steps 1-8):
   - **Names:** `sends_EURUSD_OPT{B,C,D}_2026-10-20_2210.jsonl`, `archive_EURUSD_OPT{B,C,D}_2026-10-20_2210.jsonl`, and `ticks_53077984_EURUSD_win.csv` (via `InpTag = win` on wine-d account `53077984`) are distinct from both the 13 Oct holdout files (`_2026-10-13_2210.jsonl`, `ticks_53077984_EURUSD_hold.csv`) and the 16 Oct insurance files (`_2026-10-17_ins.jsonl`, `ticks_53077984_EURUSD_win_ins.csv`), and Step 8 records them in `research/replay/inputs/eurusd_window_p4_raw.sha256` under `# THE WINDOW SET`.
   - **Times and spans:**
     - Window cut: `1792108800000` server ms = `2026-10-16 00:00:00` server (`Thu 15 Oct 2026 21:00:00Z`), matching `docs/research/replay-calibration-eurusd-4.md` lines `62-63`.
     - Window end: `1792544400000` server ms = `2026-10-21 01:00:00` server (`Tue 20 Oct 2026 22:00:00Z`), `435,600,000` ms (`121` hours = `3.0417` trading days of Fri + Mon + Tue + 1 h) after the cut, matching `docs/research/replay-calibration-eurusd-4.md` lines `62-64` and `81-82`.
     - Export clock gates: Steps 1-2 from `22:10Z` (`18:10` Toronto = `Wed 21 Oct 01:10` server, 10 minutes after the `22:00Z` window close so the archive worker has flushed); Step 3 from `22:30Z` (`18:30` Toronto = `Wed 21 Oct 01:30` server, at the exact `InpTo` boundary), matching `docs/research/replay-calibration-eurusd-4.md` lines `73-75` and `docs/runbooks/plan3-holdout-export.md` lines `7`, `42-44`, and `58`.
     - Tick dump span: `2026.10.14 01:30` to `2026.10.21 01:30` server (`168` hours = `168` chunks at `60` minutes). It meets `ticks_53077984_EURUSD_w2h.csv` (`to=2026.10.14 01:30:00.000`, `research/replay/inputs/eurusd_holdout.sha256` lines `2-3`) at the exact `2026.10.14 01:30:00.000` server seam (`1791941400000` server ms) and covers `30` minutes past the `2026.10.21 01:00` server window end.
   - **Inputs:** All seven `grind_tick_dump` inputs (`InpSymbols = EURUSD`, `InpFrom = 2026.10.14 01:30`, `InpTo = 2026.10.21 01:30`, `InpChunkMinutes = 60`, `InpRetries = 5`, `InpProbeOnly = false`, `InpTag = win`) match `scripts/grind_tick_dump.mq5` lines `18-24` and `docs/research/replay-calibration-eurusd-4.md` lines `73-75`.
   - **STOP lines:** Every STOP line in Step 2, Step 4, Step 7, and s4 is sound, including the single changed STOP threshold in `X3` / Step 4 / s4 (`bad_px` 1 expected, 2 or more a STOP, 0 reported and not a STOP; `time_back` > 0 a STOP). Because the 16 Oct insurance dump (`research/replay/inputs/eurusd_window_p4_raw.sha256` lines `12-17`) over `2026.10.14 01:30` to `2026.10.17 00:00` server already encountered `bad_px=1` (`first 2026.10.14 01:30:00.144`), and Tuesday's `win` dump starts at the same `2026.10.14 01:30` server boundary, `bad_px=1` is expected on `win`. (Minor citation note: `X3` on line `18` cites `scripts/grind_tick_dump.mq5` `129-133`; in `scripts/grind_tick_dump.mq5`, lines `129-130` are `int lines = 0;` and `for(int i = 0; i < n; i++) {`, while the `bad_px` drop block is lines `131-134`.)

2. **What failure or fact is missing?**
   Six specific facts / failure modes are missing (`M1`-`M3` in `s5`'s post-export summary of plan 4 s7 step 4; `M4`-`M6` in the export steps `s2` / `s4`):
   - **M1 (`s5`, `docs/runbooks/plan4-window-export.md` lines `113-118`): `--sessions research/replay/inputs/sessions_eurusd_ic.csv` is omitted from the `build_holdout.py` invocation description.**
     `s5` names `--sends-extra-*` and `--window-end-ms 1792544400000`, copying the shorthand from `handoffs/HANDOFF_2026-09-24.md` lines `6455-6458` without its qualifier (`the rest of the command to be read from its source then`). On `plan4-tools` (`a335ef0`), running `build_holdout.py` without `--sessions` is valid and does not error (`handoffs/HANDOFF_2026-09-24.md` lines `6260-6265`, `6284-6289`; `research/replay/inputs/eurusd_holdout_p4.sha256` lines `3-8`), but it writes 23-column `run_eurusd_{b,c,d}.csv` files without `sessions_eurusd_ic.csv`, leaving the 24th column (`sessions_file`) absent and silently disabling **F1** (the trade-session gate at the Mon 19 Oct `00:00` server open).
   - **M2 (`s5`, `docs/runbooks/plan4-window-export.md` lines `113-118`): `build_swaps.py --from 2026-10-01 --to 2026-10-21` on the three `_2026-10-20_2210` archives is omitted.**
     `build_holdout.py` does not build `swaps.csv` (`research/replay/build_holdout.py` line `20`). In the s4 development gate on plan 3's 9-14 Oct holdout (`research/replay/inputs/eurusd_holdout_p4.sha256` line `7`), `swaps.csv` was copied from `eurusd_holdout`, which ends at `2026.10.14` (`research/replay/inputs/eurusd_holdout/swaps.csv` lines `14-16`). For plan 4's window (`to 2026.10.21 01:00` server), copying `eurusd_holdout/swaps.csv` instead of running `build_swaps.py --from 2026-10-01 --to 2026-10-21` would omit the seven server rollovers `2026.10.15` through `2026.10.21`.
   - **M3 (`s5`, `docs/runbooks/plan4-window-export.md` lines `113-118`): placing and hash-checking the joined tick file (`w2h` + `win`) in `D:\mt5-replay\MQL5\Files\replay\` is not stated.**
     As recorded in `handoffs/HANDOFF_2026-09-24.md` lines `5795-5799` and `5821-5824` and `handoffs/Handover/02_TRAPS.md` lines `2767-2768`, `-Mode Inputs` copies the git-tracked manifest files and `ticks_53077984_EURUSD_w2.csv` (from `Downloads`), not the joined tick file (`not in git`). The joined tick file (`w2h` + `win`) must be written directly to `D:\mt5-replay\MQL5\Files\replay\` under the exact filename passed to `build_holdout.py build --ticks` and verified by SHA-256 before the 12 runs.
   - **M4 (`Step 2` and `s4`, `docs/runbooks/plan4-window-export.md` lines `42-49`, `102`): cumulative archive size lower bound and mid-stream `railway ssh` disconnect check.**
     Step 2 states `each a size well above zero (the 16 Oct sends were about 1.0-1.1 MB)` and checks `Get-Content $_.FullName -TotalCount 1`. First, while `sends_*` is a 14-day rolling table (`~1.0-1.3 MB`), `archive_EURUSD_OPT{B,C,D}_2026-10-20_2210.jsonl` exports all rows of `config_events`, `ea_events`, `fill_logs`, and `scalp_history` (`docs/runbooks/plan3-holdout-export.md` line `17`) and is cumulative, so B, C, and D archives must be strictly larger than their 13 Oct sizes (`1,346,760`, `1,336,730`, and `1,107,000` bytes in `research/replay/inputs/eurusd_holdout_raw.sha256` lines `6-8`). Second, if `railway ssh` drops mid-stream after emitting line 1 (`_meta`), line 1 is valid and `.Length` is well above zero, while the last line is truncated mid-JSON.
   - **M5 (`Step 4` and `s5`, `docs/runbooks/plan4-window-export.md` lines `66-72`, `88-91`, `113-114`): `TICKS|BEGIN` and `chunks=168|empty_weekday_chunks=0` check in Step 4, re-run log mixing with `tail -5`, and post-Step-8 prefix verification against `win_ins`.**
     Step 4's `Expected` paragraph (`lines 70-72`) does not explicitly name `TICKS|BEGIN|probe_only=false|from=2026.10.14 01:30:00.000|to=2026.10.21 01:30:00.000` or `chunks=168|empty_weekday_chunks=0` (from `scripts/grind_tick_dump.mq5` lines `160-164`, `181-184`), even though Step 8 records `TICKS|BEGIN` (`research/replay/inputs/eurusd_window_p4_raw.sha256` lines `13-15`). Also, if Step 3 has to be run twice on 20 Oct, `grep -a -e TICKS | tail -5` (`line 68`) will include 2 `TICKS|` lines from the first run alongside the 3 `TICKS|` lines of the second run. And once Step 8's record is pushed, checking in `s5` that the first `239,495` tick rows of `ticks_53077984_EURUSD_win.csv` match `ticks_53077984_EURUSD_win_ins.csv` (`research/replay/inputs/eurusd_window_p4_raw.sha256` lines `12-15`) verifies that `bad_px=1` in `win` is the known `14-17 Oct` dropped tick and that `0` ticks were dropped in `17-21 Oct`.
   - **M6 (`s4`, `docs/runbooks/plan4-window-export.md` lines `106-110`): C150 fallback across the other logged-in `ICMarketsSC-Demo` terminals (`wine-test` / `wine-c`).**
     If `wine-d` is logged out of IC at `22:30Z` on Tue 20 Oct (`C150`), `s4` notes that `win_ins` does not cover Mon and Tue. Before treating Mon-Tue ticks as unavailable, `wine-test` (Fleet B) and `wine-c` (Fleet C) are also logged into `ICMarketsSC-Demo` (`GMT+3`), though using another IC demo login would require an operator ruling before reading any window file (`docs/research/replay-calibration-eurusd-3.md` line `27`, `P7`).

3. **Is anything in it a change to plan 4's marks, tolerances, match rule, window or code (none is allowed)?**
   **NO.** Nothing in `docs/runbooks/plan4-window-export.md` changes plan 4's marks (`T0`, `T1`, `C`, `B`, `D`), tolerances (`results/plan3/live_spread_n3.txt`), match rule (`compare.py --t0-price order`), scorer (`score_plan3.py --cut-ms 1792108800000`), window (`1792108800000` to `1792544400000`), or frozen code (`replay-plan4` `8044284` and `plan4-tools` `a335ef0`). The change in the runbook's Step 4 / s4 STOP line from `bad_px > 0` (`docs/runbooks/plan3-holdout-export.md` lines `79-80`, `111-112`) to `bad_px >= 2` (`docs/runbooks/plan4-window-export.md` lines `18-19`, `70-72`, `103`) is purely an operational log-check threshold on `grind_tick_dump.mq5`'s output for a pre-existing bad tick in the `14-17 Oct` sub-span (`research/replay/inputs/eurusd_window_p4_raw.sha256` lines `13-17`).

---

## 2. PREMISE-BY-PREMISE CHECK: NAMES, TIMES, SPANS, INPUTS AND STOP LINES (QUESTION 1)

### 2.1 Header Block and Audit Trail (`s0`, `X1`-`X7`, Worked Example, `s1`)

`docs/runbooks/plan4-window-export.md` lines `5-28`:
```5:28:docs/runbooks/plan4-window-export.md
| | |
|---|---|
| For | `docs/research/replay-calibration-eurusd-4.md` s3 ("The data") and s7 step 3: the window's data **exported and hashed ONLY**, then s7 step 4 |
| When | **Tue 20 Oct 2026.** Steps 1-2 from **22:10Z** (18:10 Toronto; the window ends 22:00Z = Wed 21 Oct 01:00 server, and the archive worker runs minutes behind). Step 3 from **22:30Z** (18:30 Toronto = 01:30 server) |
| Who | The operator runs every command. Claude gives ONE step per message, with the clock read first, and waits for its output |
| Writes | Seven files in `Downloads` (3 sends, 3 archives, 1 tick file) and their sha256 in git (`research/replay/inputs/eurusd_window_p4_raw.sha256`, under "THE WINDOW SET"). Nothing else |
| Status | DRAFT (Claude, 18 Oct ~06:10Z). From `docs/runbooks/plan3-holdout-export.md` (run clean 13 Oct) with plan 4's names, span and the one changed STOP line (X3) |

## 0. AUDIT TRAIL

| # | Fact | Where | Status |
|---|---|---|---|
| X1 | The window: Fri 16 Oct 00:00 server (cut `1792108800000`) to Wed 21 Oct 01:00 server (end `1792544400000` = Tue 20 Oct 22:00Z); the tick dump `2026.10.14 01:30` to `2026.10.21 01:30` server, joined to w2h at the 14 Oct 01:30 seam | plan 4 s3; the two stamps recomputed 18 Oct | VERIFIED |
| X2 | The export commands, the dump script's inputs (`InpTo` exclusive, `InpProbeOnly` default TRUE = no file) and the copy and hash steps are plan 3's, unchanged | `plan3-holdout-export.md` s2, X1-X8 | RECORDED (run 13 Oct) |
| X3 | **`bad_px=1` is EXPECTED** (the insurance dump over 14-17 Oct read 1: a tick with bid or ask <= 0, or ask < bid, dropped by the dumper, `scripts/grind_tick_dump.mq5` 129-133). Plan 3's runbook stops on any `bad_px` above 0; here **2 or more is a STOP**, and 0 is reported (not a STOP) | `eurusd_window_p4_raw.sha256` (the insurance); 02_TRAPS 16 Oct night and 18 Oct | RULED (plan 4 NEXT lists) |
| X4 | **No blind:** plan 4 froze before its window opened (02_TRAPS 16 Oct). "Exported and hashed ONLY" here means: nothing opens the seven files until their hashes are recorded; then s7 step 4 reads them | plan 4 s2; 02_TRAPS 16 Oct | RULED |
| X5 | The insurance copies (16 Oct, `_ins` names) stay as they are; Tuesday's names are new (`_2026-10-20_2210`, `win`), so no file in Downloads is overwritten (02_TRAPS: never reuse a name) | `eurusd_window_p4_raw.sha256` | VERIFIED (names) |
| X6 | wine-d's dump dialog shows the chunk input's OLD comment ("ticks read per CopyTicksRange call"): the input is minutes; read the rows back by order and value | 02_TRAPS 16 Oct night | RECORDED |
| X7 | B, C, D stay frozen until this export is done: D's two-arm build is Wed 21 Oct in market hours, after it | D's runbook "When" | RULED |

**One worked example.** The window ends 22:00Z; a EURUSD exit that fills at 21:59:58Z on C is archived by the
worker a minute or two later, so an export at 22:01Z could miss it while one at 22:10Z holds it. Plan 3 lost
nothing at 22:13Z; the early run at 21:45Z was short by 849 bytes on B (`eurusd_holdout_raw.sha256`).
```

Verification of every premise in `s0` / `X1`-`X7` / `s1`:
1. **Window cut (`1792108800000`), window end (`1792544400000`), export times (`22:10Z` / `22:30Z`), and tick dump span (`2026.10.14 01:30` to `2026.10.21 01:30` server):**
   Checked against `docs/research/replay-calibration-eurusd-4.md` lines `61-83` and `121-128`:
```61:83:docs/research/replay-calibration-eurusd-4.md
## 3. THE WINDOW (FIXED NOW)

- **Scored: EURUSD deals from Fri 16 Oct 00:00 server (Thu 15 21:00Z; cut `1792108800000`) to Wed
  21 Oct 01:00 server (Tue 20 22:00Z; end `1792544400000`).** Fri, Mon and Tue plus one hour: about
  3.04 server days. It opens after Thursday's burst (Q4) and contains the Mon 19 Oct open (00:00
  quotes, 00:01 trade), the test of F1 and F4.
- **Segments:** as plan 3 s7: one a fleet from its last init (B 7 Oct 02:21:20Z, C 7 Oct
  02:12:36Z, D 9 Oct 04:24:14.290Z) to the end, unless an init happens before the end (it cuts a
  segment, plan 1 s2). Tags `eurusd_b / c / d`.
- **Tolerances:** plan 3 s3's table unchanged (`live_spread_n3.txt`, n = 3): the window is about
  3.04 server days, so n = 3 fits as pre-registered for plan 3. **Not** rebuilt with the holdout's
  days (an R2-5 proposal of round 2, rejected: it would change a mark after a failure).
- **The data:** Tue 20 Oct from 22:10Z (18:10 ET), by `docs/runbooks/plan3-holdout-export.md` with
  new names: `send_logs` and archives for B, C, D; one tick dump on wine-d from `2026.10.14 01:30`
  to `2026.10.21 01:30` server, joined to w2h at the 14 Oct 01:30 seam. Exported and hashed ONLY.
  Insurance (C150): a tick dump and a `send_logs` export after Friday's close (Sat 17 Oct),
  copied and hashed only.
- **The builder joins the sends (G5-6).** `send_logs` keep 14 days (Q6): the 20 Oct export starts
  about 6 Oct 22:10Z, after orders resting at B's and C's 7 Oct inits were placed
  (`orders_31.csv`, `orders_41.csv`). The window's inputs are built from the `_2210` sends joined
  with the new export (rows deduplicated by `send_logs.id`), and the window's end set to
  `1792544400000`: a change to `build_holdout.py` (or a copy for plan 4), tests first, committed
  before the export is opened.
```
```121:128:docs/research/replay-calibration-eurusd-4.md
## 7. ORDER OF WORK

1. This file reviewed; the rulings checked in source; committed before Thu 15 Oct 21:00Z.
2. The F1-F4 prompt; review; Cursor; the suite; the development check (s4); the freeze (s2's
   amendment).
3. Sat 17 Oct: the insurance copies. Tue 20 Oct from 22:10Z: the export, hashed only.
4. As plan 3 s7: the inputs (manifest), T0, the twelve runs, `compare.py --t0-price order`,
   `score_plan3.py` with the new cut and the same tolerances; the verdict.
```
   Epoch arithmetic check (using `server_ms` convention where server clock `GMT+3` is read as UTC epoch ms, `research/replay/build_holdout.py` lines `41-44`):
   - `2026-10-16 00:00:00` server = `20,742` days * `86,400,000` ms/day = `1,792,108,800,000` ms (`1792108800000`). Subtracting `SERVER_OFFSET_MS = 10,800,000` ms (`3` h) gives `1,792,098,000,000` ms UTC = `Thu 15 Oct 2026 21:00:00Z`.
   - `2026-10-21 01:00:00` server = `1,792,108,800,000` + `(5 * 86,400 + 3,600) * 1,000` = `1,792,108,800,000` + `435,600,000` = `1,792,544,400,000` ms (`1792544400000`), which is `5 * 86,400,000 = 432,000,000` ms (`5` days) after plan 3's `WINDOW_END_SERVER_MS = 1791939600000` (`2026.10.14 01:00:00` server) plus `2 * 86,400,000 = 172,800,000` ms (`2` days), i.e. `7` days after `1791939600000` (`1791939600000 + 7 * 86400000 = 1792544400000`). Subtracting `10,800,000` ms gives `1,792,533,600,000` ms UTC = `Tue 20 Oct 2026 22:00:00Z` (`18:00` Toronto EDT).
   - `22:10Z` on `Tue 20 Oct 2026` = `18:10` Toronto EDT = `Wed 21 Oct 2026 01:10` server.
   - `22:30Z` on `Tue 20 Oct 2026` = `18:30` Toronto EDT = `Wed 21 Oct 2026 01:30` server = `2026.10.21 01:30` server (`InpTo`).
   - Seam with `ticks_53077984_EURUSD_w2h.csv`: `research/replay/inputs/eurusd_holdout.sha256` lines `2-3`:
```2:3:research/replay/inputs/eurusd_holdout.sha256
#   w2 + hold joined at 2026.10.09 01:30 server (no gap, no overlap): ticks_53077984_EURUSD_w2h.csv,
#   651,120 ticks, 22,397,330 bytes, sha256 fe37e42aa569689248296c3a06c3f1953abd413670bde9cd4e6530b7fb550392 (not in git)
```
   and `research/replay/inputs/eurusd_holdout_raw.sha256` lines `12-15`:
```12:15:research/replay/inputs/eurusd_holdout_raw.sha256
da4776f45106947270efdac814749a1af150774382e257f70371b1b51debe812  ticks_53077984_EURUSD_hold.csv  5967213
#   ticks: TICKS|BEGIN 22:32:43Z, from 2026.10.09 01:30 to 2026.10.14 01:30 server; TICKS|EURUSD ticks=174299
#   bad_px=0 time_back=0 chunks=120 empty_weekday_chunks=0 first 2026.10.09 01:30:00.171 last 2026.10.14 01:29:41.414;
#   TICKS|END. Equal hash on wine-d (sha256sum) and on the desktop.
```
   Because `hold` (and therefore `w2h`) has header `to=2026.10.14 01:30:00.000` and last tick `2026.10.14 01:29:41.414` (`< 2026.10.14 01:30:00.000`), and `win` has `InpFrom = 2026.10.14 01:30` (`from=2026.10.14 01:30:00.000`) and first tick `2026.10.14 01:30:00.144` (`>= 2026.10.14 01:30:00.000`), `w2h` and `win` meet at `2026.10.14 01:30:00.000` server with zero overlap and an `18.730` s gap across the seam.

2. **Worked example (`849` bytes on B between `~21:45Z` and `22:13Z` on 13 Oct):**
   Checked against `research/replay/inputs/eurusd_holdout_raw.sha256` lines `6` and `17-20`:
```6:6:research/replay/inputs/eurusd_holdout_raw.sha256
01cc483f7eb59958ec396ebe900854348a171f3aa4cc0cd563ea0e65bbee82b5  archive_EURUSD_OPTB_2026-10-13_2210.jsonl  1346760
```
```17:20:research/replay/inputs/eurusd_holdout_raw.sha256
# SUPERSEDED: the same six exports run early by mistake (~21:43Z, then again ~21:45Z), before the runbook's 22:10Z;
# hashes of the ~21:45Z run. Five equal the 2210 set byte for byte (no EURUSD send on B, C, D and no new archive row
# on C, D between ~21:45Z and 22:13Z); archive B grew by 849 bytes.
1dc8e51e163fe40328a395a126009c835ce139aba37a298bef8132ce1559be4d  archive_EURUSD_OPTB_2026-10-13.jsonl  1345911
```
   `1,346,760 - 1,345,911 = 849` bytes. Exact.

3. **`X3` (`bad_px=1` expected; `bad_px >= 2` a STOP; `0` reported) and line-number check in `scripts/grind_tick_dump.mq5`:**
   Checked against `research/replay/inputs/eurusd_window_p4_raw.sha256` lines `12-17`, `handoffs/Handover/02_TRAPS.md` lines `2795-2799` and `2854-2855`, and `scripts/grind_tick_dump.mq5` lines `128-136`:
```12:17:research/replay/inputs/eurusd_window_p4_raw.sha256
adba7ab82df92bcc58cb484ff3f63e689c85b08af92eab9b4e64af8fc1778fa2  ticks_53077984_EURUSD_win_ins.csv  8205995
#   TICKS|BEGIN 22:39:59Z, probe_only=false, from 2026.10.14 01:30 to 2026.10.17 00:00 server, account 53077984,
#   ICMarketsSC-Demo, server_minus_gmt_s=10800; TICKS|EURUSD ticks=239495 bad_px=1 time_back=0 chunks=71
#   empty_weekday_chunks=0 first 2026.10.14 01:30:00.144 last 2026.10.16 23:56:59.965; TICKS|END.
#   Equal hash on wine-d (sha256sum; 8205995 bytes by stat) and on the desktop.
#   bad_px=1: one tick with bid or ask <= 0, or ask < bid, counted and NOT written (grind_tick_dump.mq5 lines 129-133).
```
```2795:2799:handoffs/Handover/02_TRAPS.md
- **`bad_px` counts ticks the dump DROPPED** (bid or ask <= 0, or ask < bid; `scripts/grind_tick_dump.mq5`
  lines 129-133); every other tick is in the file. Plan 4's insurance dump (14 Oct 01:30 to 17 Oct 00:00
  server) read `bad_px=1`, the first ever. Tuesday's window dump covers the same span: expect 1; more is a
  stop to report. Whatever the count, do not open the file to find the tick before the export is hashed.
```
```2854:2855:handoffs/Handover/02_TRAPS.md
- **`docs/runbooks/plan3-holdout-export.md` stops on any `bad_px` above 0** (step 4, s4); plan 4's window
  dump expects 1 (16 Oct night). Run Tuesday's export from its own runbook, not plan 3's "with new names".
```
```128:136:scripts/grind_tick_dump.mq5
      string buf = "";
      int lines = 0;
      for(int i = 0; i < n; i++) {
         if(t[i].bid <= 0.0 || t[i].ask <= 0.0 || t[i].ask < t[i].bid) {
            bad++;
            continue;
         }
         if(last_ms > 0 && t[i].time_msc < last_ms)
            back++;
```
   Note: `X3` (`docs/runbooks/plan4-window-export.md` line `18`), `research/replay/inputs/eurusd_window_p4_raw.sha256` line `17`, and `handoffs/Handover/02_TRAPS.md` line `2796` cite `scripts/grind_tick_dump.mq5` `129-133`; in `scripts/grind_tick_dump.mq5`, line `129` is `int lines = 0;`, line `130` is `for(int i = 0; i < n; i++) {`, and the `if(t[i].bid <= 0.0 || t[i].ask <= 0.0 || t[i].ask < t[i].bid)` block is lines `131-134`. The behavioral claim in `X3` is completely right.

4. **`X4` (No blind: plan 4 froze before its window opened):**
   Checked against `docs/research/replay-calibration-eurusd-4.md` lines `46-59` and `handoffs/Handover/02_TRAPS.md` lines `2791-2792`:
```46:59:docs/research/replay-calibration-eurusd-4.md
- **AMENDMENT (the freeze; 15 Oct ~17:00Z, the operator agreed): s2: harness = `8044284`
  (`replay-plan4`: `145f092` + F1-F4 + fix 1; suite 573 / 573, GUI compile 0 errors 0 warnings);
  builders = `a335ef0` (`plan4-tools`: F2's clock fix in `build_real.py`, `--sessions`, and
  `build_holdout.py`'s sends join and `--window-end-ms`, s3).** The builders are named because F2 is
  partly theirs (this section) and the window's inputs are built by them (s3). The pair passed s4's gate
  at timing 1 on both seen windows: holdout T1 100.0% x 3 (`results/plan4/holdout_score_8044284.md`),
  calibration T1 98.8 / 98.3 / 97.3% (`results/plan4/cal_score_8044284.md`). Nothing else in this file
  changes; no mark, tolerance, match rule or window.
- No code change once the first window run starts.
- **Blind until the freeze (G5-2).** From the window's open (Fri 16 Oct 00:00 server) until s2's
  amendment is committed, nobody looks at any EURUSD fill, send, scalp, roll or journal line of B, C
  or D after the cut, on pipshed or on a box. Allowed: fleet-level status (live, alerts, equity,
  balance, carry pass summaries), the IC login lines (C150), other pairs, and the export's own
  checks (copy, size, sha256, first line, `TICKS|` lines; runbook lines 30-32).
```
```2791:2792:handoffs/Handover/02_TRAPS.md
- **A blind is the plan's, word for word:** plan 4 s2 blinds "until s2's amendment is committed"; with
  the freeze in first, there is no blind. Do not carry a stricter rule into NEXT lists (s84b, s84c did).
```

5. **`X5` (Insurance names vs Tuesday's `_2026-10-20_2210` and `win` names):**
   Checked against `research/replay/inputs/eurusd_window_p4_raw.sha256` lines `8-12`:
```8:12:research/replay/inputs/eurusd_window_p4_raw.sha256
e7b2ce3cf8b48baf97c4c2069b65737c17a4bab8f810d34c04431d30f464f82f  sends_EURUSD_OPTB_2026-10-17_ins.jsonl  983030
8763ec262d1d6a2edb4c42a31c3bfd3856d3cfcaee191cf32fba0410c8aec259  sends_EURUSD_OPTC_2026-10-17_ins.jsonl  1105560
47b3fc9aeca60846807738583cfbd6325108f60f545f1ee3cbbc05845888a8af  sends_EURUSD_OPTD_2026-10-17_ins.jsonl  1023775
# The tick dump on wine-d (a fresh EURUSD chart; inputs typed and read back; no preset).
adba7ab82df92bcc58cb484ff3f63e689c85b08af92eab9b4e64af8fc1778fa2  ticks_53077984_EURUSD_win_ins.csv  8205995
```

6. **`X6` (Old input label on wine-d's dump dialog):**
   Checked against `handoffs/Handover/02_TRAPS.md` lines `2800-2802`:
```2800:2802:handoffs/Handover/02_TRAPS.md
- **wine-d's script dialog labels `InpChunkMinutes` "ticks read per CopyTicksRange call"**: the comment
  from before `dc74051`; the input is minutes and the code is the same. Read the dialog's rows back by
  order and value.
```

7. **`X7` (B, C, D frozen until export is done; D's two-arm build is Wed 21 Oct in market hours, after it):**
   Checked against `docs/runbooks/twoarm-build-d.md` line `8`:
```8:8:docs/runbooks/twoarm-build-d.md
| When | **Wed 21 Oct 2026**, in market hours, **after** plan 4's window is exported and hashed (Tue 20 Oct from 22:10Z). Not between 20:50Z and 21:15Z (the carry window) |
```

---

### 2.2 Steps 1-8 (`s2`), Negative Space (`s3`), and Failure Modes (`s4`)

`docs/runbooks/plan4-window-export.md` lines `36-91`:
```36:91:docs/runbooks/plan4-window-export.md
## 2. STEPS

**Step 1 (desktop, PowerShell in `D:\pipshed`, from 22:10Z): the sends and the archives.** Six files.

    foreach ($f in 'B','C','D') { railway ssh --service archive-worker -i "$HOME\.ssh\id_ed25519" python scripts/archive_counts.py --export-sends --instance "GRIND_EURUSD_OPT$f" | Set-Content -Encoding utf8 "$HOME\Downloads\sends_EURUSD_OPT${f}_2026-10-20_2210.jsonl"; railway ssh --service archive-worker -i "$HOME\.ssh\id_ed25519" python scripts/archive_counts.py --export-archive --instance "GRIND_EURUSD_OPT$f" | Set-Content -Encoding utf8 "$HOME\Downloads\archive_EURUSD_OPT${f}_2026-10-20_2210.jsonl" }

**Step 2 (desktop): sizes, hashes and first lines.**

    Get-ChildItem "$HOME\Downloads\*_EURUSD_OPT?_2026-10-20_2210.jsonl" | ForEach-Object { '{0} {1} {2}' -f $_.Name, $_.Length, (Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLower(); Get-Content $_.FullName -TotalCount 1 }

Expected: six names, each a size well above zero (the 16 Oct sends were about 1.0-1.1 MB) and a 64-character
hash, each followed by its `_meta` line (`{"table": "_meta", ... "instance": "GRIND_EURUSD_OPT<f>"}`, with
`"sends": true` or `"archive": true`). STOP on a missing file, a size of a few bytes, or a first line that is an
error text: re-run step 1 for that file only, under the same name.

**Step 3 (wine-d, VNC, from 22:30Z = 01:30 server): the EURUSD tick dump.** On a FRESH EURUSD chart (never an EA
chart), drag `grind_tick_dump` from Scripts and TYPE these in the inputs dialog (VNC takes typing, not paste).
Read every row back before OK (X6: the chunk row's label is old; its value is minutes):

    InpSymbols      EURUSD
    InpFrom         2026.10.14 01:30
    InpTo           2026.10.21 01:30
    InpChunkMinutes 60
    InpRetries      5
    InpProbeOnly    false
    InpTag          win

`InpTo` must NOT be empty and `InpProbeOnly` must be false. The file will be `ticks_53077984_EURUSD_win.csv`.
Close the chart afterwards.

**Step 4 (desktop): the dump's log lines.**

    ssh root@216.128.158.33 'iconv -f UTF-16LE -t UTF-8 /home/khalid/.mt5/drive_c/Program*Files/MetaTrader*5/MQL5/logs/20261020.log | grep -a -e TICKS | tail -5'

Expected: one `TICKS|EURUSD|ticks=...|bad_px=1|time_back=0|...` line, no EMPTY, FAILED or DELETED line, then
`TICKS|END`; `first=2026.10.14 01:30:00.144` (the insurance's first tick, the same span start) and `last` before
`2026.10.21 01:30`. **`bad_px` 2 or more, or `time_back` above 0: STOP** (X3). `bad_px=0`: report it and go on.

**Step 5 (desktop): the hash on the box.**

    ssh root@216.128.158.33 'sha256sum /home/khalid/.mt5/drive_c/Program*Files/MetaTrader*5/MQL5/Files/ticks_53077984_EURUSD_win.csv; stat -c %s /home/khalid/.mt5/drive_c/Program*Files/MetaTrader*5/MQL5/Files/ticks_53077984_EURUSD_win.csv'

**Step 6 (desktop): copy it to Downloads.**

    scp "root@216.128.158.33:/home/khalid/.mt5/drive_c/Program*Files/MetaTrader*5/MQL5/Files/ticks_53077984_EURUSD_win.csv" "$HOME\Downloads"

**Step 7 (desktop): the hash on the desktop.**

    Get-ChildItem "$HOME\Downloads\ticks_53077984_EURUSD_win.csv" | ForEach-Object { '{0} {1} {2}' -f $_.Name, $_.Length, (Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLower() }

It must equal step 5's hash and size. STOP if not: copy again.

**Step 8 (Claude): the record.** The seven names, sizes and hashes, and step 4's `TICKS|` lines, go into
`research/replay/inputs/eurusd_window_p4_raw.sha256` under "THE WINDOW SET", and the handoff, as one docs
patch. Claude does not stage or open the files for this. Once the operator has pushed it, plan 4 s7 step 4
(s5 below) may read them.
```

Comparison against `docs/runbooks/plan3-holdout-export.md` lines `40-98` and `scripts/grind_tick_dump.mq5`:
- **Step 1 & Step 2:** Identical to `docs/runbooks/plan3-holdout-export.md` lines `46` and `50`, except the output filenames change from `*_EURUSD_OPT${f}_2026-10-13.jsonl` to `*_EURUSD_OPT${f}_2026-10-20_2210.jsonl` (incorporating `_2210` in the initial name, as used in `research/replay/inputs/eurusd_holdout_raw.sha256` lines `6-11`).
- **Step 3:** Compared with `docs/runbooks/plan3-holdout-export.md` lines `63-69`:
  - `InpFrom` changes from `2026.10.09 01:30` to `2026.10.14 01:30` (the end of `hold` / `w2h`).
  - `InpTo` changes from `2026.10.14 01:30` to `2026.10.21 01:30`.
  - `InpTag` changes from `hold` to `win`.
  - In `scripts/grind_tick_dump.mq5` lines `18-24` and `89-91`:
```18:24:scripts/grind_tick_dump.mq5
input string InpSymbols      = "EURUSD";
input string InpFrom         = "2026.10.01 06:30";   // server time, inclusive
input string InpTo           = "";                   // server time, exclusive; empty = now
input int    InpChunkMinutes = 60;                   // minutes of ticks per CopyTicksRange call
input int    InpRetries      = 5;                    // retries per chunk while history syncs
input bool   InpProbeOnly    = true;                 // true: print the earliest tick only, no file
input string InpTag          = "";                   // added to the file name (e.g. t0b_a)
```
```89:91:scripts/grind_tick_dump.mq5
   const long login = AccountInfoInteger(ACCOUNT_LOGIN);
   const string tag = (InpTag == "") ? "" : "_" + InpTag;
   const string fname = StringFormat("ticks_%I64d_%s%s.csv", login, sym, tag);
```
  On wine-d (`login = 53077984`, `sym = "EURUSD"`, `InpTag = "win"`), `fname` is `ticks_53077984_EURUSD_win.csv`.
  Furthermore, in `scripts/grind_tick_dump.mq5` lines `109-126`:
```109:126:scripts/grind_tick_dump.mq5
   for(long a = from_ms; a < to_ms; a += chunk_ms) {
      const long b = ((a + chunk_ms < to_ms) ? a + chunk_ms : to_ms) - 1;   // inclusive; no overlap
      MqlTick t[];
      const int n = TdCopy(sym, a, b, t);
      if(n < 0) {
         failed = true;
         break;
      }
      chunks++;
      if(n == 0) {
         MqlDateTime dt;
         TimeToStruct((datetime)(a / 1000), dt);
         if(dt.day_of_week >= 1 && dt.day_of_week <= 5) {
            empty_weekday++;
            if(empty_weekday <= 20)
               PrintFormat("TICKS|%s|EMPTY_WEEKDAY_CHUNK|from=%s", sym, TdTime(a));
         }
         continue;
      }
```
  Because `from_ms` is at `:30` (`2026.10.14 01:30:00.000`) and `chunk_ms = 3,600,000` (`60` min):
  - Total chunks across `7` days (`168` hours): `chunks = 168`.
  - Friday's last chunk on `2026.10.16` starts at `2026.10.16 23:30:00.000` (`dt.day_of_week == 5`) and covers `[23:30:00.000, 2026.10.17 00:29:59.999]`, which contains Friday's quotes up to `23:56:59.965` (`research/replay/inputs/eurusd_window_p4_raw.sha256` line `15`), so `n > 0`.
  - Every empty weekend chunk between `2026.10.17 00:30:00.000` and `2026.10.18 22:30:00.000` starts on Saturday (`dt.day_of_week == 6`) or Sunday (`dt.day_of_week == 0`), and the `2026.10.18 23:30:00.000` chunk (`dt.day_of_week == 0`) covers `[Sun 23:30:00.000, Mon 00:29:59.999]` (which also starts on Sunday and contains Monday's `00:00` quotes).
  - Thus `empty_weekday_chunks = 0` unless an actual Mon-Fri trading hour has zero ticks.
- **Step 4:** Log file path `/home/khalid/.mt5/drive_c/Program*Files/MetaTrader*5/MQL5/logs/20261020.log` matches the UTC date `Tue 20 Oct 2026` at `22:30Z` (`docs/runbooks/plan3-holdout-export.md` line `24`: `the MQL5 log is UTF-16LE, named by the UTC day`).
- **Step 5, Step 6, Step 7:** Step 5 improves on `docs/runbooks/plan3-holdout-export.md` line `84` by adding `; stat -c %s /home/khalid/.mt5/drive_c/Program*Files/MetaTrader*5/MQL5/Files/ticks_53077984_EURUSD_win.csv` alongside `sha256sum` (matching the insurance dump check in `research/replay/inputs/eurusd_window_p4_raw.sha256` line `16`), and Step 7 checks both hash and byte length (`$_.Length`).
- **Step 8:** Targets `research/replay/inputs/eurusd_window_p4_raw.sha256` under `# THE WINDOW SET`, which already has the placeholder at line `23`:
```23:23:research/replay/inputs/eurusd_window_p4_raw.sha256
# THE WINDOW SET (Tue 20 Oct from 22:10Z): to be added below.
```

---

## 3. MISSING FACTS AND FAILURE MODES (QUESTION 2: M1-M6)

### M1 (`s5`, Critical): `s5` omits `--sessions research/replay/inputs/sessions_eurusd_ic.csv` from the `build_holdout.py` invocation description

In `docs/runbooks/plan4-window-export.md` lines `111-119`:
```111:119:docs/runbooks/plan4-window-export.md
## 5. AFTER THE RECORD: PLAN 4 s7 STEP 4 (Claude, on `8044284` / `a335ef0`; NOT this runbook's steps)

In order, as plan 3 s7, each through its own message: the join of w2h and `win` at `2026.10.14 01:30` server
(the seam checked: no gap, no overlap); `build_holdout.py` from `plan4-tools` `a335ef0` with the `_2210` sends of
13 Oct as `--sends-extra-*` (rows deduplicated by `send_logs.id`, plan 4 s3) and `--window-end-ms
1792544400000`; the manifest; T0; the twelve runs on `D:\mt5-replay` (`replay-plan4` `8044284`); `compare.py
--t0-price order`; `score_plan3.py --cut-ms 1792108800000 --tol results/plan3/live_spread_n3.txt`; the verdict
by plan 4 s5 (from the T0 / T1 table and the counts verdict, not the report's last line).
```

Compare `s5` with `docs/research/replay-calibration-eurusd-4.md` lines `46-50`, `research/replay/inputs/eurusd_holdout_p4.sha256` lines `1-8`, `research/replay/inputs/eurusd_holdout_p4/run_eurusd_b.csv` lines `1-2`, and `handoffs/HANDOFF_2026-09-24.md` lines `6284-6297` and `6455-6458`:
```1:8:research/replay/inputs/eurusd_holdout_p4.sha256
# Plan 4 s4 development gate: plan 3's HOLDOUT window (9-14 Oct; cut 1791531120000), rebuilt with the fixed builders
# (plan4-tools a335ef0) from the _2026-10-13_2210 set (eurusd_holdout_raw.sha256; all seven raw files hash equal), by Claude
# 15 Oct ~15:20Z: build_holdout.py build --out DIR --ticks ticks_53077984_EURUSD_w2h.csv --sessions inputs/sessions_eurusd_ic.csv
#   --b/--c/--d archive_*_2210.jsonl --sends-b/c/d sends_*_2210.jsonl (window end and first ids at plan 3's defaults).
# Check first (no --sessions): 12 of 12 seed / orders / run / intervals files equal eurusd_holdout.sha256; real_*.csv differ
# only by 14 ROLL rows moved onto their session's OUT_BY time (B 10, C 3, D 1; 18-1,959 ms: A11's 12 plus two rolls the EA
# host's clock stamped before both the EXT and the close-by). swaps.csv copied from eurusd_holdout. Ticks NOT in git:
# ticks_53077984_EURUSD_w2h.csv (fe37e42a...0392). New: sessions_eurusd_ic.csv; the run files' 24th column.
```
```1:2:research/replay/inputs/eurusd_holdout_p4/run_eurusd_b.csv
seg_id,instance,magic,from_ms,to_ms,width_l,width_s,add_l,add_s,exit_l,exit_s,cap,stranded,deadband,lattice,reroll,gate,carry,fill_time_place,reserve,seed_file,ticks_file,orders_file,sessions_file
31,GRIND_EURUSD_OPTB,22260201,1791350480000,1791939600000,2.0,2.0,7.0,7.0,10.0,10.0,8,3.0,2.0,1,1,0,1,1,8,seed_31.csv,ticks_53077984_EURUSD_w2h.csv,orders_31.csv,sessions_eurusd_ic.csv
```
```6284:6297:handoffs/HANDOFF_2026-09-24.md
- **Check (a), plan 3's holdout rebuilt with NO new flags:** 12 of 12 seed / orders / run / intervals
  files equal `eurusd_holdout.sha256`; the `real_*.csv` differ ONLY by 14 ROLL rows moved onto their
  session's `OUT_BY` time (B 10, C 3, D 1; 18-1,959 ms). The prompt's A11 counted 12 (rolls host-
  stamped between an EXT and its close-by); the two more (B L2 +1,959 ms, C L7 +459 ms) were host-
  stamped before BOTH the EXT and the close-by: the same rule, the same host-clock lag (consult s10).
- **Check (b), the calibration rebuilt from the `_2210` set with `build_inputs.py`, no new flags:**
  62 of 62 seed / orders / run / intervals files equal `eurusd_20261008.sha256` (the `_2210` export
  carries 1-9 Oct whole); the `real_*.csv` differ only by 15 ROLL rows (B 7, C 3, D 5; 18-459 ms),
  each now on an `OUT_BY` time; every non-ROLL row identical.
- **The gate's sets (this patch):** `research/replay/inputs/eurusd_20261008_p4/` (67 files) and
  `eurusd_holdout_p4/` (17), each with `--sessions inputs/sessions_eurusd_ic.csv` (the file in the
  folder and the manifest; run files 24 columns), `swaps.csv` copied from the old sets (calibration
  `dc7da509...6c`, holdout `dbd8ee4a...d0`); manifests `*_p4.sha256` with the build notes.
```
```6455:6458:handoffs/HANDOFF_2026-09-24.md
5. Plan 4 s7 step 4 after the export: the window's inputs (`build_holdout.py` at `a335ef0`: it has
   `--sends-extra-*` (the `_2210` sends joined with the new export, plan 4 s3) and `--window-end-ms`
   (`1792544400000`); the rest of the command to be read from its source then), manifest, T0, the 12
   runs, compare, score (`--cut-ms 1792108800000`, `live_spread_n3.txt`).
```

**Why this matters:** In `build_holdout.py` on `plan4-tools` (`a335ef0`), `--sessions` is optional (`default=None`) so that Check (a) (`no --sessions`) could reproduce plan 3's 23-column `run_*.csv` files (`research/replay/inputs/eurusd_holdout_p4.sha256` lines `5-8`). If `build_holdout.py build` is run in `s5` with only `--sends-extra-*` and `--window-end-ms 1792544400000` and without `--sessions research/replay/inputs/sessions_eurusd_ic.csv`, `sessions_eurusd_ic.csv` (`research/replay/inputs/eurusd_holdout_p4/sessions_eurusd_ic.csv` lines `1-6`):
```1:6:research/replay/inputs/eurusd_holdout_p4/sessions_eurusd_ic.csv
day_of_week,trade_from,trade_to
1,00:01,23:59
2,00:01,23:59
3,00:01,23:59
4,00:01,23:59
5,00:01,23:57
```
is not copied into the output directory, `run_eurusd_{b,c,d}.csv` has 23 columns instead of 24, and the harness logs `RPL|SESSIONS|none` instead of `RPL|SESSIONS|sessions_eurusd_ic.csv|5` (`handoffs/HANDOFF_2026-09-24.md` line `6328`), silently disabling **F1** across the Mon 19 Oct `00:00` server open (`docs/research/replay-calibration-eurusd-4.md` lines `33-37`, `62-65`).

---

### M2 (`s5`, Critical): `s5` omits `build_swaps.py --from 2026-10-01 --to 2026-10-21` on the three new `_2026-10-20_2210` archives

In `research/replay/build_holdout.py` lines `13-21`:
```13:21:research/replay/build_holdout.py
    python -B research/replay/build_holdout.py join --w2 W2.csv --hold HOLD.csv --out JOINED.csv
    python -B research/replay/build_holdout.py build --out DIR --ticks JOINED.csv \
        --b ARCHIVE_B --c ARCHIVE_C --d ARCHIVE_D --sends-b S_B --sends-c S_C --sends-d S_D

swaps.csv: build_swaps.py (--from 2026-10-01 --to 2026-10-14) on the three holdout archives.
Standard library only; ascii, LF (run files), CRLF kept in the tick file, no BOM.
"""
```
And in `research/replay/build_swaps.py` lines `24-26` and `104-115`:
```24:26:research/replay/build_swaps.py
    python -B research/replay/build_swaps.py --from 2026-10-01 --to 2026-10-09 \
        --out swaps.csv archive_A.jsonl [archive_B.jsonl ...]
```
```104:115:research/replay/build_swaps.py
def build_rows(snaps, first, last):
    """One row per server date first..last inclusive; ValueError if a date has no rate."""
    rows = []
    d = first
    while d <= last:
        r = rate_for(snaps, d)
        if r is None:
            raise ValueError("no CARRY_SNAPSHOT before %s 00:00 server" % d.isoformat())
        m = multiplier(d)
        rows.append((d.strftime("%Y.%m.%d"), effective_points(r[0], m), effective_points(r[1], m), m))
        d += dt.timedelta(days=1)
    return rows
```
And in `research/replay/inputs/eurusd_holdout/swaps.csv` lines `1-16`:
```1:16:research/replay/inputs/eurusd_holdout/swaps.csv
# points are EFFECTIVE: each night's broker charge at 0.01 lot and tick value 1.0 rounded to the cent / (mult x 0.01); mult 0 rows keep the raw rate (HANDOFF s73)
server_date,points_long,points_short,mult
2026.10.01,-8.333333333333334,1.3333333333333335,3
2026.10.02,-8.0,1.0,1
2026.10.03,-8.232,1.508,0
2026.10.04,-8.232,1.508,0
2026.10.05,-8.0,2.0,1
2026.10.06,-8.0,1.0,1
2026.10.07,-8.0,1.0,1
2026.10.08,-8.0,1.3333333333333335,3
2026.10.09,-8.0,1.0,1
2026.10.10,-7.99,1.31,0
2026.10.11,-7.99,1.31,0
2026.10.12,-8.0,1.0,1
2026.10.13,-8.0,1.0,1
2026.10.14,-8.0,1.0,1
```

**Why this matters:** `build_holdout.py` does not write `swaps.csv`. In the s4 development gate (`research/replay/inputs/eurusd_holdout_p4.sha256` line `7`), `swaps.csv` could be copied from `eurusd_holdout` because that window ended at `2026.10.14 01:00` server. Plan 4's window runs through `2026.10.21 01:00` server (`1792544400000`), crossing the `00:00` server rollovers into `2026.10.15` through `2026.10.21`. `build_swaps.py --from 2026-10-01 --to 2026-10-21 --out <DIR>/swaps.csv` must be run on the three `archive_EURUSD_OPT{B,C,D}_2026-10-20_2210.jsonl` files (and its new SHA-256 passed as `-SwapsSha` to `replay_run.ps1`).

---

### M3 (`s5`, Important): Placing and hash-checking the joined tick file (`w2h` + `win`) in `D:\mt5-replay\MQL5\Files\replay\`

In `handoffs/HANDOFF_2026-09-24.md` lines `5795-5799` and `5821-5824`:
```5795:5799:handoffs/HANDOFF_2026-09-24.md
- **The ticks:** `ticks_53077984_EURUSD_w2h.csv` = `build_holdout.py join` of w2 and hold at
  9 Oct 01:30 server (headers meet; 44.9 s from the last w2 tick to the first hold tick), 651,120
  ticks, 22,397,330 bytes, sha256 `fe37e42aa569689248296c3a06c3f1953abd413670bde9cd4e6530b7fb550392`.
  NOT in git (hash in the manifest's comments). Claude wrote it straight into
  `D:\mt5-replay\MQL5\Files\replay` through the bridge and read it back equal.
```
```5821:5824:handoffs/HANDOFF_2026-09-24.md
   c. `& D:\fxmatrix\tools\replay_run.ps1 -Mode Inputs -Set eurusd_holdout -Commit 6734ee5`
      (expect `INPUTS 16/16 ok`; it also re-checks w2), then
      `(Get-FileHash D:\mt5-replay\MQL5\Files\replay\ticks_53077984_EURUSD_w2h.csv -Algorithm SHA256).Hash.ToLower()`
      = `fe37e42a...0392`. Do NOT run the suite after this (it rewrites swaps.csv).
```
And in `handoffs/Handover/02_TRAPS.md` lines `2767-2768`:
```2767:2768:handoffs/Handover/02_TRAPS.md
- **`-Mode Inputs` copies w2 from Downloads only if it is there;** otherwise it keeps `Files\replay`'s
  copy and still checks its sha256. "INPUTS n/n ok" with no w2 in Downloads is normal.
```

**Why this matters:** Because the joined tick file (`w2h` + `win`) is not tracked in git and `replay_run.ps1 -Mode Inputs` only stages the git-tracked manifest files and checks `ticks_53077984_EURUSD_w2.csv`, the joined tick file (`w2h` + `win`) must be written into `D:\mt5-replay\MQL5\Files\replay\` under the exact `--ticks` filename referenced in `run_eurusd_{b,c,d}.csv` and hash-checked there before running the 12 replays.

---

### M4 (`Step 2` and `s4`, Important): Archive size lower bound (`> 1.34 MB` / `> 1.10 MB`) and mid-stream `railway ssh` truncation

In `docs/runbooks/plan4-window-export.md` lines `42-49` and `102`:
```42:49:docs/runbooks/plan4-window-export.md
**Step 2 (desktop): sizes, hashes and first lines.**

    Get-ChildItem "$HOME\Downloads\*_EURUSD_OPT?_2026-10-20_2210.jsonl" | ForEach-Object { '{0} {1} {2}' -f $_.Name, $_.Length, (Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLower(); Get-Content $_.FullName -TotalCount 1 }

Expected: six names, each a size well above zero (the 16 Oct sends were about 1.0-1.1 MB) and a 64-character
hash, each followed by its `_meta` line (`{"table": "_meta", ... "instance": "GRIND_EURUSD_OPT<f>"}`, with
`"sends": true` or `"archive": true`). STOP on a missing file, a size of a few bytes, or a first line that is an
error text: re-run step 1 for that file only, under the same name.
```
```102:102:docs/runbooks/plan4-window-export.md
- `railway ssh` fails or a file is a few bytes long: report its first line.
```

Compare with `docs/runbooks/plan3-holdout-export.md` lines `16-18` and `research/replay/inputs/eurusd_holdout_raw.sha256` lines `6-11`:
```16:18:docs/runbooks/plan3-holdout-export.md
| X1 | `--export-sends --instance X`: every send_logs row of one instance, a `_meta` line first; refuses without `--instance` | pipshed `scripts/archive_counts.py` (`6ea487e`) | READ |
| X2 | `--export-archive --instance X`: every row of config_events, ea_events, fill_logs, scalp_history for that instance | same file, `export_archive(cur, instance)` | READ |
| X3 | send_logs keep 14 days: 9 Oct's rows go on 23 Oct. The 9 Oct export already holds B's and C's sends back to their 7 Oct inits | 03_COOKBOOK retention; 02_TRAPS 2026-10-09 | RECORDED |
```
```6:11:research/replay/inputs/eurusd_holdout_raw.sha256
01cc483f7eb59958ec396ebe900854348a171f3aa4cc0cd563ea0e65bbee82b5  archive_EURUSD_OPTB_2026-10-13_2210.jsonl  1346760
d74edad154442da6eccbddd4150bcd72449220aef6bbb9aa1854189b4e621a4f  archive_EURUSD_OPTC_2026-10-13_2210.jsonl  1336730
fd2275fbf82e57eeb69f3526ba7d2029114b9305a171e4815afc3a6098158c67  archive_EURUSD_OPTD_2026-10-13_2210.jsonl  1107000
3dd8cd53bb3d139cf52ca32574f19e534fdbee3bd27bc27bc7a988c5ed7e00d5  sends_EURUSD_OPTB_2026-10-13_2210.jsonl  959335
55983207a37d977823af7e536c507a33ab09c0559f79bfeeb112939ad8ae5b94  sends_EURUSD_OPTC_2026-10-13_2210.jsonl  1062719
9aac9caa845147ebb4d1d1d766b7d2427b12d31b5f73e31884f7c6ddb0d915d9  sends_EURUSD_OPTD_2026-10-13_2210.jsonl  952751
```

Two facts to note for Step 2:
1. While `sends_*` is a 14-day rolling window (`983,030`, `1,105,560`, and `1,023,775` bytes on 16 Oct in `research/replay/inputs/eurusd_window_p4_raw.sha256` lines `8-10`), `--export-archive` exports every row of `config_events`, `ea_events`, `fill_logs`, and `scalp_history` with no 14-day purge (`docs/runbooks/plan3-holdout-export.md` line `17`). Therefore each `archive_EURUSD_OPT{B,C,D}_2026-10-20_2210.jsonl` must be **strictly larger** than its 13 Oct size (`1,346,760` bytes for B, `1,336,730` bytes for C, `1,107,000` bytes for D; expect `~1.5-2.0 MB` after 5 additional trading days of heartbeats, fills, and scalps). Any `archive_*` smaller than its 13 Oct size is truncated and is a STOP.
2. Because `archive_counts.py` prints the `_meta` line first (`docs/runbooks/plan3-holdout-export.md` line `16`), a `railway ssh` session that disconnects mid-stream produces a file whose first line is a valid `_meta` JSON object and whose size is hundreds of KB, but whose final line is cut off mid-JSON (`_load` in `research/replay/build_holdout.py` lines `99-101` will then fail in `s5` with `json.decoder.JSONDecodeError`).

---

### M5 (`Step 4` and `s5`, Operational): `TICKS|BEGIN` and `chunks=168|empty_weekday_chunks=0` in Step 4, `tail -5` on a re-run, and post-Step-8 prefix check against `win_ins`

In `docs/runbooks/plan4-window-export.md` lines `66-72`:
```66:72:docs/runbooks/plan4-window-export.md
**Step 4 (desktop): the dump's log lines.**

    ssh root@216.128.158.33 'iconv -f UTF-16LE -t UTF-8 /home/khalid/.mt5/drive_c/Program*Files/MetaTrader*5/MQL5/logs/20261020.log | grep -a -e TICKS | tail -5'

Expected: one `TICKS|EURUSD|ticks=...|bad_px=1|time_back=0|...` line, no EMPTY, FAILED or DELETED line, then
`TICKS|END`; `first=2026.10.14 01:30:00.144` (the insurance's first tick, the same span start) and `last` before
`2026.10.21 01:30`. **`bad_px` 2 or more, or `time_back` above 0: STOP** (X3). `bad_px=0`: report it and go on.
```
And in `scripts/grind_tick_dump.mq5` lines `160-164` and `181-194`:
```160:164:scripts/grind_tick_dump.mq5
   PrintFormat("TICKS|%s|ticks=%I64d|bad_px=%I64d|time_back=%I64d|chunks=%I64d|"
               "empty_weekday_chunks=%I64d|first=%s|last=%s|file=%s",
               sym, ticks, bad, back, chunks, empty_weekday,
               (first_ms > 0 ? TdTime(first_ms) : "-"), (last_ms > 0 ? TdTime(last_ms) : "-"),
               fname);
```
```181:194:scripts/grind_tick_dump.mq5
   PrintFormat("TICKS|BEGIN|probe_only=%s|from=%s|to=%s|account=%I64d|server=%s|"
               "server_minus_gmt_s=%I64d",
               InpProbeOnly ? "true" : "false", TdTime(from_ms), TdTime(to_ms),
               AccountInfoInteger(ACCOUNT_LOGIN), AccountInfoString(ACCOUNT_SERVER), offset_s);
   string syms[];
   const int k = StringSplit(InpSymbols, ',', syms);
   for(int i = 0; i < k; i++) {
      StringTrimLeft(syms[i]);
      StringTrimRight(syms[i]);
      if(syms[i] != "")
         TdSymbol(syms[i], from_ms, to_ms, chunk_ms, offset_s);
   }
   Print("TICKS|END");
}
```

Three operational points on Step 4 / `s5`:
1. A clean run of `grind_tick_dump` emits three `TICKS|` lines: `TICKS|BEGIN|...`, `TICKS|EURUSD|...`, and `TICKS|END`. Step 4's `Expected` text (`lines 70-72`) should also check that `TICKS|BEGIN` shows `probe_only=false|from=2026.10.14 01:30:00.000|to=2026.10.21 01:30:00.000|account=53077984|server=ICMarketsSC-Demo|server_minus_gmt_s=10800` and that `TICKS|EURUSD` shows `chunks=168|empty_weekday_chunks=0|...|file=ticks_53077984_EURUSD_win.csv` and `ticks > 239495` (strictly greater than the 16 Oct insurance dump's `ticks=239495`, `research/replay/inputs/eurusd_window_p4_raw.sha256` line `14`).
2. If Step 3 is run more than once on `20261020.log` (for instance, after fixing a typed input), `grep -a -e TICKS | tail -5` returns the last 2 `TICKS|` lines of the prior run followed by the 3 `TICKS|` lines of the new run; only the lines from the final `TICKS|BEGIN` to `TICKS|END` belong to the current run.
3. Once Step 8's hash record is pushed (`s5`), comparing the first `239,495` tick rows of `ticks_53077984_EURUSD_win.csv` against the `239,495` tick rows of `ticks_53077984_EURUSD_win_ins.csv` (`research/replay/inputs/eurusd_window_p4_raw.sha256` lines `12-15`) confirms whether the single `bad_px=1` in `win` is the exact same `14-17 Oct` dropped tick (and that `0` ticks were dropped in `17-21 Oct`).

---

### M6 (`s4`, Operational): C150 fallback across `wine-test` and `wine-c` if `wine-d` is logged out

In `docs/runbooks/plan4-window-export.md` lines `106-110`:
```106:110:docs/runbooks/plan4-window-export.md
- **wine-d is logged out of IC, or the dump cannot reach the server (C150):** never log in again with other
  details. Steps 1-2 still run (pipshed, not IC). The insurance dump (`win_ins`, 14 Oct 01:30 to 17 Oct 00:00
  server) does NOT cover the window's Mon and Tue: whether plan 4 can be scored then is a plan 4 note BEFORE
  any window file is read (the operator's call).
```
And in `docs/research/replay-calibration-eurusd-3.md` line `27`:
```27:27:docs/research/replay-calibration-eurusd-3.md
| P7 | T0b (s4.1 of plan 1, run 11 Oct on B / C / D): 99.66-99.91% of ticks within 100 ms across boxes, 99.98-100% same spread; B missed 90 of 1,353 fills in a 2-minute dead gap on 2 Oct. D's w2 stream is the reference; other boxes' fills are scored against it with this known limit | HANDOFF s79 | MEASURED |
```

If `wine-d` is logged out at `22:30Z` (`C150`), stopping and taking the operator's call before reading any window file (`lines 106-110`) is the right rule; in making that call, note that `wine-test` (Fleet B) and `wine-c` (Fleet C) are also on `ICMarketsSC-Demo` (`GMT+3`), so if either remains logged in, a dump from `2026.10.14 01:30` to `2026.10.21 01:30` server can still be taken there (subject to `P7` in `docs/research/replay-calibration-eurusd-3.md` line `27` and an explicit plan 4 note before any window file is read).

---

## 4. AUDIT OF PLAN 4 INVARIANTS: MARKS, TOLERANCES, MATCH RULE, WINDOW AND CODE (QUESTION 3)

1. **Marks (`T0`, `T1`, `C`, `B`, `D`) and Verdict Rule (`plan 4 s5`):**
   - `docs/runbooks/plan4-window-export.md` line `99` and lines `116-118`:
```99:99:docs/runbooks/plan4-window-export.md
- No change to any mark, tolerance, match rule, window or code of plan 4; `8044284` / `a335ef0` unchanged.
```
```116:118:docs/runbooks/plan4-window-export.md
--t0-price order`; `score_plan3.py --cut-ms 1792108800000 --tol results/plan3/live_spread_n3.txt`; the verdict
by plan 4 s5 (from the T0 / T1 table and the counts verdict, not the report's last line).
```
   - Checked against `docs/research/replay-calibration-eurusd-4.md` lines `8-9` and `101-109`:
```8:9:docs/research/replay-calibration-eurusd-4.md
| Rules it keeps | Plan 3 entire, except where this file says otherwise: the question (s1), the marks, match rule and tolerances (plan 3 s3), what a result means (plan 3 s4), its known limits (plan 3 s5), seeding at an init, T0 on the order price, the scorer `score_plan3.py` unchanged |
```
```101:109:docs/research/replay-calibration-eurusd-4.md
## 5. WHAT A RESULT MEANS

Plan 3 s4, word for word: PASS = fit for count-level use on EURUSD in markets without a
scheduled-release burst (geometries bracketed by the live fleets; rankings confirmed live); FAIL =
not fit, the cause read and recorded, any next step a new plan; INCONCLUSIVE = recorded, a further
window needs a new pre-registration. The reading of plan 3 s7 holds: a T1 fail is FAIL whatever
the scoreable count. `score_plan3.py` (unchanged) prints INCONCLUSIVE ahead of a T0 / T1 FAIL
(lines 213-216): the verdict is read by this rule from the report's T0 / T1 table and its counts
verdict, not from its last line (G5-6).
```
   - Checked against `research/replay/score_plan3.py` lines `213-220`:
```213:220:research/replay/score_plan3.py
    if len(scoreable) < MIN_SCOREABLE_SIDES:
        verdict = "INCONCLUSIVE (fewer than %d scoreable sides: %d)" % (MIN_SCOREABLE_SIDES, len(scoreable))
    elif not (t0_pass and t1_pass):
        verdict = "FAIL (T0/T1 gate)"
    elif counts_pass and bias_pass and diff_pass:
        verdict = "PASS"
    else:
        verdict = "FAIL"
```
   Exact match.

2. **Tolerances (`results/plan3/live_spread_n3.txt`):**
   - `docs/research/replay-calibration-eurusd-4.md` lines `70-72` and `research/replay/results/plan3/live_spread_n3.txt` lines `1-19`:
```1:19:research/replay/results/plan3/live_spread_n3.txt
=== 3. PAIR x SIDE (EURUSD; round 1 n = 6 days, round 2 n = 3 days; k = 2.5, floors 3 / 2 / 3) ===
EURUSD L S: pairs=3 mean_sd_day=2.5790 -> n=6 tol=15.79, n=3 tol=11.17
EURUSD L R: pairs=3 mean_sd_day=0.4536 -> n=6 tol=2.78, n=3 tol=2.00
EURUSD L A: pairs=3 mean_sd_day=0.4536 -> n=6 tol=3.00, n=3 tol=3.00
EURUSD S S: pairs=3 mean_sd_day=1.1674 -> n=6 tol=7.15, n=3 tol=5.06
EURUSD S R: pairs=3 mean_sd_day=0.2546 -> n=6 tol=2.00, n=3 tol=2.00
EURUSD S A: pairs=3 mean_sd_day=0.2546 -> n=6 tol=3.00, n=3 tol=3.00

=== 4. BIAS (Signed sum of 6 fleet x side errors; k = 2.5, floor = 3 * single-side floor) ===
S: sqrt(sum mean_var_day) = 2.8309 -> n=6 tol=17.34, n=3 tol=12.26
R: sqrt(sum mean_var_day) = 0.5202 -> n=6 tol=6.00, n=3 tol=6.00
A: sqrt(sum mean_var_day) = 0.5202 -> n=6 tol=9.00, n=3 tol=9.00

=== 5. DIFFERENCES ((f1 - f2) replay vs live;sd_diff = sqrt(2) * sd_single; k = 2.5, floor = 4) ===
EURUSD L S: sd_diff_day=3.6473 -> n=6 tol=22.33, n=3 tol=15.79
EURUSD S S: sd_diff_day=1.6510 -> n=6 tol=10.11, n=3 tol=7.15

=== 6. FLOORS USED ===
Counts: S >= 3, R >= 2, A >= 3. Bias: 3x count floor (9 / 6 / 9). Differences: S >= 4.
```
   Unchanged.

3. **Match Rule (`compare.py --t0-price order`), Window (`1792108800000` to `1792544400000`), and Code (`8044284` / `a335ef0`):**
   - `compare.py --t0-price order`, `--cut-ms 1792108800000`, `--window-end-ms 1792544400000`, harness `8044284` (`replay-plan4`), and builders `a335ef0` (`plan4-tools`) in `docs/runbooks/plan4-window-export.md` lines `17`, `99`, and `111-118` match `docs/research/replay-calibration-eurusd-4.md` lines `46-53`, `62-63`, `78-83`, and `126-127` with zero changes.
   - The `bad_px` STOP threshold change in `docs/runbooks/plan4-window-export.md` lines `18-19`, `70-72`, and `103` applies only to the operator's inspection of the `TICKS|EURUSD` log line from `scripts/grind_tick_dump.mq5` (because `ticks_53077984_EURUSD_win_ins.csv` over `2026.10.14 01:30` to `2026.10.17 00:00` server already recorded `bad_px=1`, `research/replay/inputs/eurusd_window_p4_raw.sha256` lines `13-17`); it does not alter any mark, tolerance, match rule, window, or code of plan 4.

Line count: 353
