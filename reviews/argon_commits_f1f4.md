# Argon review of Cursor's Plan 4 F1-F4 commits

SHAs read: `db94402` (this prompt), `3738152` (Plan 4 prompt + calibration note + Part A base + `.gitattributes` + compare/score/manifests), `e4d96f4` (agreed restate), `2193b6b` (Part A tests; subject only), `bcfc305` (Part A code + sessions CSV + holdout/real/segments/inputs tests), `efada62` (replay-harness base: core EXT path, engine/closeby/pure/state, `fxgrind.mq5` OnInit, `replay_run.ps1`), `19d8db6` (B-0 stubs + commit message), `538b15e` / `68fe443` / `acc93fd` / `9748480` (subjects only), `7d8fa13` (record / final core+tests).

`python -B -m unittest` from `research/replay` on `plan4-tools` (`bcfc305`): not run (working tree is `db94402`). Prompt R4 already measured 195 OK. On a Windows tree with `core.autocrlf=true` I expect `test_sessions_eurusd_ic_csv_file` to fail: see Q8.

Verdict words: DEFECT / CONFIRMED / NOT A DEFECT / NOT READ.

Quote rule: `<commit>:<path>:<line>` then the exact line. Lines that themselves contain backticks are given as a one-line fenced block so the text is not truncated.

---

## C-1

**CONFIRMED** (and a **DEFECT** against the development gate).

`fleet_files` already takes `sessions_file` and forwards it:

`bcfc305:research/replay/build_inputs.py:45` `def fleet_files(rows, tag, window_from_ms, window_to_ms, first_id, ticks_file, snaps, intervals,`

`bcfc305:research/replay/build_inputs.py:46` `                sends=None, sessions_file=None):`

`bcfc305:research/replay/build_inputs.py:69` `    files["run_%s.csv" % tag] = build_segments.to_run_csv(`

`bcfc305:research/replay/build_inputs.py:70` `        segs, ticks_file, names, first_id, order_names, sessions_file=sessions_file)`

`main` has no `--sessions` and never passes the name (or copies the file):

`bcfc305:research/replay/build_inputs.py:92` `def main(argv=None):`

`bcfc305:research/replay/build_inputs.py:97` `    ap.add_argument("--end-ms", type=int, default=WINDOW_END_SERVER_MS)`

`bcfc305:research/replay/build_inputs.py:98` `    for k, _t, _w, _f in FLEETS:`

`bcfc305:research/replay/build_inputs.py:109` `        files = fleet_files(rows, tag, start, a.end_ms, first, a.ticks, snaps, INTERVALS.get(tag, []),`

`bcfc305:research/replay/build_inputs.py:110` `                            sends=sends[k])`

`build_holdout.py` already has the flag and the copy:

`bcfc305:research/replay/build_holdout.py:163` `    sessions_path = getattr(a, "sessions", None)`

`bcfc305:research/replay/build_holdout.py:164` `    sessions_name = None`

`bcfc305:research/replay/build_holdout.py:165` `    if sessions_path:`

`bcfc305:research/replay/build_holdout.py:166` `        sessions_name = os.path.basename(sessions_path)`

`bcfc305:research/replay/build_holdout.py:205` `    b.add_argument("--sessions", default=None)`

The gate rebuilds both windows first:

`3738152:docs/research/replay-calibration-eurusd-4.md:79` `The fixed harness runs on the two windows already seen: the calibration (1-9 Oct, 29 segments) and`

`3738152:docs/research/replay-calibration-eurusd-4.md:82`
```
- **The gate (G5-3):** `score_plan3.py` passes every mark (T0, T1, C, B, D) on both: the
```

`3738152:docs/research/replay-calibration-eurusd-4.md:86`
```
- **The inputs are rebuilt first** for both windows (`real_*.csv` by the fixed `build_real.py`, new
```

`3738152:docs/research/replay-calibration-eurusd-4.md:87` `  manifests), so F2's clock fix is what is tested.`

A-2 only adds the column when a name is given:

`3738152:prompts/cursor_plan4_f1f4.md:54`
```
- **A-2. `build_segments.py` / `build_inputs.py`: an optional `sessions_file` column.** When a
```

`3738152:prompts/cursor_plan4_f1f4.md:55`
```
  sessions file name is given, the run header gains `,sessions_file` after `orders_file` and every
```

`3738152:prompts/cursor_plan4_f1f4.md:56` `  row carries the name; when not given, the output is byte-identical to today's (test it).`

So the calibration CLI (`build_inputs.py`) cannot switch F1 on. That is right.

**What else is missing for the gate.** `tools/replay_run.ps1 -Mode Inputs` copies only the files the manifest lists, from git at `${Commit}`:

`efada62:tools/replay_run.ps1:127` `if ($Mode -eq 'Inputs') {`

`efada62:tools/replay_run.ps1:128` `   $manifestPath = "research/replay/inputs/$Set.sha256"`

`efada62:tools/replay_run.ps1:129` `   $manifest = git -C $RepoRoot show "${Commit}:$manifestPath" 2>&1`

`efada62:tools/replay_run.ps1:144` `      $gitPath = "research/replay/inputs/$Set/$($e.Name)"`

`efada62:tools/replay_run.ps1:145`
```
      cmd /c "git -C `"$RepoRoot`" show ${Commit}:$gitPath > `"$path`"" | Out-Null
```

`efada62:tools/replay_run.ps1:148` `      if ($got -ne $e.Want) { throw "INPUT hash mismatch $($e.Name)" }`

The committed calibration manifest at `3738152` (`eurusd_20261008.sha256`, 66 lines) has no `sessions_eurusd_ic.csv` (names I opened: intervals, orders_*, then `real_eurusd_{b,c,d}.csv` / `run_eurusd_{b,c,d}.csv`). The harness loads the run row's name and aborts if the file is missing:

`7d8fa13:ea/fxgrind_replay_core.mqh:3896` `      const string sessions_file = (ArraySize(fields) > 23) ? fields[23] : "";`

`7d8fa13:ea/fxgrind_replay_core.mqh:3897` `      if(StringLen(sessions_file) > 0) {`

`7d8fa13:ea/fxgrind_replay_core.mqh:3898` `         if(!Rpl_LoadSessionsFile(sessions_file, seg_line == 1)) {`

`7d8fa13:ea/fxgrind_replay_core.mqh:3707`
```
   const int sh = FileOpen("replay\\" + fname, FILE_READ | FILE_CSV | FILE_ANSI, ',');
```

`7d8fa13:ea/fxgrind_replay_core.mqh:3708` `   if(sh == INVALID_HANDLE) {`

`7d8fa13:ea/fxgrind_replay_core.mqh:3709` `      Print("RPL|ABORT|MISSING_SESSIONS|file=", fname);`

**Smallest fix.** In `build_inputs.main`, add `--sessions` (default None). If set: copy `os.path.basename(a.sessions)` into `a.out` with `newline="\n"` (same as `build_holdout.py` 167-170) and pass `sessions_file=sessions_name` into `fleet_files`. Rebuild `eurusd_20261008` and `eurusd_holdout`: commit the new `real_eurusd_{b,c,d}.csv`, the 24-column `run_eurusd_{b,c,d}.csv` that name `sessions_eurusd_ic.csv`, a copy of `sessions_eurusd_ic.csv` in each set folder, and the updated `.sha256` manifests. Without those committed blobs, `-Mode Inputs` never stages the sessions file (or fails `INPUT hash mismatch` on the changed `real_*` / `run_*`).

Hand-derived values for a test that would catch the CLI gap: `python -B research/replay/build_inputs.py --out DIR ... --sessions research/replay/inputs/sessions_eurusd_ic.csv`; `run_eurusd_b.csv` header field 24 is `sessions_file`; every data row ends `,sessions_eurusd_ic.csv`; `DIR/sessions_eurusd_ic.csv` equals

`bcfc305:research/replay/inputs/sessions_eurusd_ic.csv:1` `day_of_week,trade_from,trade_to`

`bcfc305:research/replay/inputs/sessions_eurusd_ic.csv:2` `1,00:01,23:59`

`bcfc305:research/replay/inputs/sessions_eurusd_ic.csv:6` `5,00:01,23:57`

bytes, LF only. Without `--sessions`, `run_eurusd_b.csv` stays 23 columns (A-2 invariance).

---

## C-2

**CONFIRMED.**

`Rpl_TestRunRt67Tick` never calls `Rpl_SetTiming`. `Rpl_ResetAll` leaves `g_rpl_tm_on` false (declaration default):

`7d8fa13:ea/fxgrind_replay_core.mqh:338` `bool   g_rpl_tm_on = false;`

`7d8fa13:ea/fxgrind_replay_tests.mq5:2687` `   Rpl_ResetAll();`

`7d8fa13:ea/fxgrind_replay_tests.mq5:2698` `   Rpl_RunTicks(ticks, 1, cfg);`

So RT67 only hits timing-0 `Rpl_ProcessOneTickInstant` (session gate around CLOSEBY / LATTICE / ENGINE / TIMER at 2966-3012). It does not run:

`7d8fa13:ea/fxgrind_replay_core.mqh:995` `   RplSendGateSnap gate_snap;`

`7d8fa13:ea/fxgrind_replay_core.mqh:996` `   Rpl_SessionSendGateBegin(stage_start, gate_snap);`

`7d8fa13:ea/fxgrind_replay_core.mqh:1027` `   Rpl_SessionSendGateEnd(gate_snap);`

`7d8fa13:ea/fxgrind_replay_core.mqh:1091` `      RplSendGateSnap gate_snap;`

`7d8fa13:ea/fxgrind_replay_core.mqh:1092` `      Rpl_SessionSendGateBegin(start, gate_snap);`

`7d8fa13:ea/fxgrind_replay_core.mqh:1116` `   Rpl_ProcessCloseByDone(start, one, 1);`

RT66 is timed, but it only asserts broker fills (`Rpl_TmBrokerStep`), not send-gate refusals. RT68 is file load at timing 0.

Prompt C-2's "core 346-352" are the `g_rpl_tm_*` declarations at `7d8fa13`; the base durations are:

`7d8fa13:ea/fxgrind_replay_core.mqh:434` `   if(sens == "base") {`

`7d8fa13:ea/fxgrind_replay_core.mqh:435` `      g_rpl_tm_d_place = 287;`

`7d8fa13:ea/fxgrind_replay_core.mqh:436` `      g_rpl_tm_d_modify = 288;`

`7d8fa13:ea/fxgrind_replay_core.mqh:437` `      g_rpl_tm_d_closeby = 294;`

`7d8fa13:ea/fxgrind_replay_core.mqh:438` `      g_rpl_tm_d_remove = 43;`

`7d8fa13:ea/fxgrind_replay_core.mqh:439` `      g_rpl_tm_lam = 261;`

(Agreed restate still cites the old numbers:)

`e4d96f4:reviews/cursor_restate_f1f4.md:53`
```
- Timed `"base"` profile (`Rpl_TmApplySens("base")`, `ea/fxgrind_replay_core.mqh:346-352`): `d_place = 287` ms, `d_modify = 288` ms, `d_closeby = 294` ms, `d_remove = 43` ms, `lam = 261` ms, `thru_pts = 0`, `limit_price = false`.
```

**Smallest test (timed send gate), hand values.** IC table via `Rpl_TestSetIcSessions` (Tue `day_of_week=2`, `00:01`..`23:59`). `Rpl_SetTiming(1, "base")`. Tuesday 2026.10.06 10:00:00 = `1791280800000`:

`e4d96f4:reviews/cursor_restate_f1f4.md:50`
```
- `RPL_T0 = D'2026.10.06 10:00:00'` = `1791280800` s = `1791280800000` ms (Tuesday, `day_of_week = 2`).
```

Then 23:58:00 = `1791280800000 + 50280000` = `1791331080000`. Engine places long L0 then short S0 (`efada62:ea/grind_engine.mqh` 3219-3222). Order-log times are send_start:

`e4d96f4:reviews/cursor_restate_f1f4.md:56`
```
  - In timed mode (`timing = 1`), `Rpl_TmDiffStageSends` computes `const long send_start = cursor; cursor += dur;` (**lines 877--878**) and calls `Rpl_TmApplySendRow(stage, send_start, cursor, ...)` (**line 880**), which calls `Rpl_OrderLogAppendRowAt(send_start, ...)` at **line 770** --- so `g_rpl_orders[n].time_ms` is `send_start` (not `send_end`), while `Rpl_BkPlace(ticket, otype, price, send_end)` (**line 772**) and `Rpl_BkModify(ticket, price, send_end)` (**line 780**) set the broker book's `live_ms` / `from_ms` to `send_end = cursor`, and `Rpl_TmWriteTimingRow` (**lines 936, 1077**) writes `end_ms = cursor`.
```

- `t_open  = 1791331080000` (23:58:00). bid `1.10000`, ask `1.10002`. OPEN (`m=1438`, `to_min=1439`). `STAGE:ENGINE` start `1791331080000`. Two PLACE: L0 ENT at `1791331080000` price `1.09981`; S0 ENT at `1791331080287` price `1.10151`. Broker `live_ms` = send_end: L0 `1791331080287`, S0 `1791331080574`. `g_rpl_tm_free_ms` ends `1791331080574`.
- `t_closed = 1791331140000` (23:59:00). bid `1.09950`, ask `1.09952`. CLOSED (`m=1439`, `m < to_min` is false). `STAGE:ENGINE` start `1791331140000`. Gate: `send_ok=false`, `retcode=10018`. 0 MODIFY. After the stage, `g_grind_order_test_send_ok && g_grind_closeby_test_send_ok` restored true. L0 price still `1.09981`.
- `t_reopen = 1791331260000` (Wed 00:01:00). OPEN. ENGINE may MODIFY; first send_start `1791331260000`.

**DEAL handler (still untested).** Seed L0 ENT BUY_LIMIT `1.11909` ticket `6611` (RT66). One tick `t_touch = 1791331139739` (23:58:59.739) bid `1.11847` ask `1.11903`. Broker touches, DEAL at `t_touch+261 = 1791331140000` (23:59:00.000) CLOSED. `Rpl_TmRunDealHandler` `start = 1791331140000`. IN deal at `1791331140000` price `1.11903` (`limit_price` false). `Grind_ProcessDeal` under the gate: 0 EXT PLACE. Seams restored.

**CB_DONE handler (still untested).** Same table. A CLOSEBY send that finishes at `t_closed` (`start = MathMax(ev.start_ms, g_rpl_tm_free_ms) = 1791331140000`) must run `Rpl_ProcessCloseByDone` with `tick_ms=1791331140000` CLOSED: `send_ok=false` / `10018` around both `Grind_ProcessDeal` calls (2516-2526); 0 new PLACE from that completion; seams restored.

---

## C-3

**CONFIRMED.**

Default `build_holdout.py build` now always runs `join_sends` (second file None) and A-1's ROLL key is `(t, 1, seq)` instead of `(t, 1, 0)`:

`bcfc305:research/replay/build_holdout.py:104` `def join_sends(first, second=None):`

`bcfc305:research/replay/build_holdout.py:109` `        if "_meta" in r or r.get("table") != "send_logs":`

`bcfc305:research/replay/build_holdout.py:120` `    return sorted(kept, key=lambda r: (int(r["ea_time_ms"]), int(r.get("seq") or 0),`

`bcfc305:research/replay/build_holdout.py:121` `                                       int(r.get("id") or 0)))`

`bcfc305:research/replay/build_holdout.py:157` `        sends[k] = join_sends(_load(getattr(a, "sends_" + k)),`

`bcfc305:research/replay/build_holdout.py:158` `                              _load(extra) if extra else None)`

The old path loaded one file and did not join:

`3738152:research/replay/build_holdout.py:126` `    sends = {k: _load(getattr(a, "sends_" + k)) for k, _t, _w, _f in FLEETS}`

`build_orders._events` already skips non-`ok` sends and sorts by `(time, input index)`:

`3738152:research/replay/build_orders.py:32` `        if tab == "send_logs":`

`3738152:research/replay/build_orders.py:33` `            if not r.get("ok"):`

`3738152:research/replay/build_orders.py:34` `                continue`

`3738152:research/replay/build_orders.py:40` `    ev.sort(key=lambda e: (e[0], e[1]))`

`_meta` rows were already ignored (no `table == "send_logs"`). After `join_sends(first, None)` the remaining `ok` send_logs are in `(ea_time_ms, seq, id)` order, which is the exporter order the prompt names:

`3738152:prompts/cursor_plan4_f1f4.md:63`
```
  by (`ea_time_ms`, `seq`, `id`) as the exporter writes them; `_meta` lines dropped from the join.
```

Input-index sort then preserves that order. `orders_31.csv` / `orders_41.csv` / `orders_51.csv` stay byte-identical. `run_*.csv` stay 23 columns because `--sessions` is omitted (`sessions_name is None`). Seeds, intervals, swaps unchanged.

ROLL clock (A-1), applied before the window filter:

`3738152:research/replay/build_real.py:69` `        t = int(r["ea_time_ms"]) + SERVER_OFFSET_MS`

`3738152:research/replay/build_real.py:70` `        if not (from_ms <= t < to_ms):`

`3738152:research/replay/build_real.py:73` `        keyed.append(((t, 1, 0), (t, "ROLL", d["side"], int(d["layer_index"]), 0.0,`

`bcfc305:research/replay/build_real.py:70` `        sid = r.get("session_id")`

`bcfc305:research/replay/build_real.py:75` `                    if f.get("session_id") == sid and f.get("seq") is not None`

`bcfc305:research/replay/build_real.py:78` `                t = max(t, max(prev))`

`bcfc305:research/replay/build_real.py:79` `        if not (from_ms <= t < to_ms):`

`bcfc305:research/replay/build_real.py:82` `        keyed.append(((t, 1, int(rseq) if rseq is not None else 0),`

Same-ms ROLLs now sort by `seq` instead of a constant `0`. That only reorders two ROLL rows of one ms; Claude's "exporter writes increasing seq" makes that a no-op. A ROLL can be pulled across `from_ms` (test `test_roll_before_from_ms_moved_into_window_is_kept`). Each holdout window starts at an INIT; a new INIT is a new `session_id`, so a pre-window ROLL does not see in-window fills of the new session. I did **not** read `research/replay/inputs/eurusd_holdout/real_eurusd_{b,c,d}.csv`, so the claim "exactly 12 ROLL rows" is **not read**. From the code, the only files that *can* differ on a no-flag rebuild are `real_eurusd_b.csv`, `real_eurusd_c.csv`, `real_eurusd_d.csv`, and only at ROLL rows whose time or same-ms order changed. Everything else in

`3738152:research/replay/inputs/eurusd_holdout.sha256:4` `434edc6671e6daee72bdacaf61645f412c91dcae7e31e3bb53c6fdf348cdf928  intervals_eurusd_b.csv`

through

`3738152:research/replay/inputs/eurusd_holdout.sha256:19` `dbd8ee4a19876108868a370475574284e155499ac7bb9b335636caa5534e01d0  swaps.csv`

should hash-equal except those three `real_*` lines (10-12). Sound; nothing else on the default path writes a different byte.

---

## C-4

**CONFIRMED** (B-0 message does not state expected failures; at least one assertion fails in each of RT64-RT74; one nuance on RT69).

B-0 message (`git log -1 --format=%B 19d8db6`):

```
replay/tests: add plan 4 RT64-RT74 (B-0)

Adds RT64 (F3), RT65 (F4), RT66-RT68 (F1), and RT69-RT74 (F2) before implementing F1-F4.
```

Prompt required the expected failures:

`3738152:prompts/cursor_plan4_f1f4.md:73`
```
`5bb5fdb`: `RPL_MIRRORS_EA` stays). Commits: B-0 the tests (all new RTs, against the current code;
```

`3738152:prompts/cursor_plan4_f1f4.md:74` `state which you EXPECT to fail there, and why: you cannot run them); then one commit for each of`

B-0 stubs (F1 not present):

`19d8db6:ea/fxgrind_replay_core.mqh:1203` `void Rpl_AddTestSession(const int day_of_week, const string trade_from, const string trade_to)`

`19d8db6:ea/fxgrind_replay_core.mqh:1204` `{`

`19d8db6:ea/fxgrind_replay_core.mqh:1205` `}`

`19d8db6:ea/fxgrind_replay_core.mqh:1208` `int Rpl_SessionsCount()`

`19d8db6:ea/fxgrind_replay_core.mqh:1210` `   return 0;`

F3 not present at B-0 (still the two lines):

`19d8db6:ea/fxgrind_replay_core.mqh:2545` `   g_grind_start_add_reprice_long = true;`

`19d8db6:ea/fxgrind_replay_core.mqh:2546` `   g_grind_start_add_reprice_short = true;`

Removed at `7d8fa13` (reset ends at the keep_* assignments):

`7d8fa13:ea/fxgrind_replay_core.mqh:2799` `   g_grind_short.l0_pending_ticket = keep_l0s;`

`7d8fa13:ea/fxgrind_replay_core.mqh:2800` `   g_grind_short.add_pending_ticket = keep_adds;`

`7d8fa13:ea/fxgrind_replay_core.mqh:2801` `}`

Per RT, quoting the assertion that fails at B-0 (tests at `7d8fa13` = B-0 additions; `git diff efada62 origin/replay-plan4 -- ea/fxgrind_replay_tests.mq5` is two header comment lines plus the RT64-RT74 insertion and their `OnStart` calls):

- **RT64.** After the ROLL at `t0+500`, Tick 1 `bid=1.09860` reclamps the add to `1.09859`. With the startup flag forced true, deadband is the 0.05-pip reprice threshold:

`e4d96f4:reviews/cursor_restate_f1f4.md:79`
```
- **Expected at `B-0` (`efada62`):** **FAILS** --- `Rpl_SyncResetToTrueBook` sets `g_grind_start_add_reprice_long = true` (core 2534), using the `0.05`-pip (`0.000005`) threshold so `0.00001 >= 0.000005` modifies `L` L2 `ENT` to `1.09859` (`MODIFY` count = `1`, price = `1.09859`).
```

  Fails:
  `7d8fa13:ea/fxgrind_replay_tests.mq5:2523` `   AssertTrue("RT64 no add modify after sync reset", mod_n == 0);`
  and then 2527 (`px` is `1.09859`, not `1.09860`).

- **RT65 (both modes).** No `g_rpl_last_engine_attempt_tick_ms` skip. Tick at `T+7000` still sends. Fails:
  `7d8fa13:ea/fxgrind_replay_tests.mq5:2569` `   AssertTrue(label + " 0 sends on stale tick t2", t2_sends == 0);`
  then 2570 (`l1_n == 5`, not `4`). Helper runs twice (2593-2594).

- **RT66.** `Rpl_AddTestSession` is a no-op, so `with_sessions=true` has no table (`Rpl_SessionIsOpen` is not even at B-0; broker always fills). Gated cases fill at the 00:00 tick. Fails:
  `7d8fa13:ea/fxgrind_replay_tests.mq5:2664` `   AssertTrue("RT66 gated timed fill at 00:01:00.431", ms == t_open + 261);`
  `7d8fa13:ea/fxgrind_replay_tests.mq5:2669` `   AssertTrue("RT66 gated t0 fill at 00:01:00.170", ms == t_open);`
  Ungated 2673 and 2677 pass.

- **RT67.** No sessions. Closed ticks place 2. Fails:
  `7d8fa13:ea/fxgrind_replay_tests.mq5:2719` `   AssertTrue("RT67 23:59:00 closed refuses", seam_cnt == 0 && ord_cnt == 0 && restored);`
  same for 2722, 2725, 2732. Open 2715 and 2728 pass.

- **RT68.** No `Rpl_LoadSessionsFile` at B-0. `Rpl_SessionsCount` returns 0. Extra CSV column is ignored. Fails:
  `7d8fa13:ea/fxgrind_replay_tests.mq5:2773` `   AssertTrue("RT68 loaded 5 session rows", Rpl_SessionsCount() == 5);`
  2774 (places 2, not gated), 2780 (`AssertFalse` missing-file: run succeeds). No-column 2786-2788 pass.

- **RT69.** F2 not present: EXT still removes the true-book layer

`efada62:ea/fxgrind_replay_core.mqh:2555` `      } else if(rd.kind == "EXT") {`

`efada62:ea/fxgrind_replay_core.mqh:2566` `         if(remove_i >= 0) {`

`efada62:ea/fxgrind_replay_core.mqh:2569` `            g_rpl_true_book_count--;`

  and reset drops it. Seeded EXT has `placed_ms=1`:

`efada62:ea/fxgrind_replay_core.mqh:1841` `   Rpl_TrackOrderPlaced(ticket, 1);`

  so at `T+0` (`ask=1.10400` <= BUY_LIMIT `1.10400`) timing 0 fills and `Rpl_ProcessCloseByDone` completes at once (no deferral). First failing assert can be either
  `7d8fa13:ea/fxgrind_replay_tests.mq5:2839` `   AssertTrue("RT69 layer stays before OUT_BY", Rpl_ShortDepth() == 1 && Rpl_HasPosition(6901UL));`
  (layer already gone) or 2840 (`pre_outby == 0`) if the replay CB_DONE already wrote OUT_BY deals at `T+0`. Claude's "layer leaves at the replay's own CB_DONE" is the right reason. I do **not** confirm that 2840 passes. Full-run asserts 2861, 2863-2866, 2878 also fail (completion time is not `T+1000`).

- **RT70.** At B-0 EXT at `T+500` removes the layer. Fails:
  `7d8fa13:ea/fxgrind_replay_tests.mq5:2911` `   AssertTrue("RT70 depth 1 at T0+1000", Rpl_ShortDepth() == 1 && Rpl_HasPosition(7001UL));`

- **RT71.** Replay completes close-by at its own fill/CB_DONE (`T+261` EXT, then its own OUT_BY), not at `T+450`. Fails:
  `7d8fa13:ea/fxgrind_replay_tests.mq5:2981` `   AssertTrue("RT71 2 OUT_BY deals at T0+450 only", outby_450 == 2 && outby_other == 0);`

- **RT72.** Same: in-flight path at B-0 still removes on EXT (`efada62` EXT branch). Fails at least
  `7d8fa13:ea/fxgrind_replay_tests.mq5:3040` `   AssertTrue("RT72 2 OUT_BY deals at T0+1000", outby_1000 == 2);`
  (OUT_BY time is the replay's, or the layer is already gone).

- **RT73.** Held L1 is removed at EXT `T+500`. Fails:
  `7d8fa13:ea/fxgrind_replay_tests.mq5:3082` `   AssertTrue("RT73 t1 L1 kept at EXT with exit_pos 7304",`

- **RT74.** S2 gone at EXT `T+300`; no completion-at-`T+1500` promotion. Fails:
  `7d8fa13:ea/fxgrind_replay_tests.mq5:3138` `   AssertTrue("RT74 depth 3 and S1 held before OUT_BY",`

At `7d8fa13` the new asserts are written to pass (461 existing + the new ones; RT65 helper twice: 12 timing-0 + 16 timed). I did not run the MQL5 suite.

---

## C-5

**CONFIRMED** (none of the four is a defect for the gate).

`compare.py` / `score_plan3.py` read `run_*.csv`, `real_*.csv`, `out_*_{deals,orders,events,book}.csv`. They never open `*timing.csv`. `orders` is used only for `action == "FILL"`:

`3738152:research/replay/compare.py:149` `    for o in order_rows or []:`

`3738152:research/replay/compare.py:150` `        if o.get("action") == "FILL":`

`3738152:research/replay/compare.py:399` `        p = os.path.join(runs, "%s_%s_%s" % (tag, mode, harness), "out_%s_%s_orders.csv" % (tag, mode))`

`3738152:research/replay/compare.py:406` `    sync_deals = replay_deals(out("sync", "deals"), out_orders("sync"))`

`3738152:research/replay/score_plan3.py:172` `    sync = cp.replay_deals(out("sync", "deals"), out("sync", "orders"))`

`3738152:research/replay/score_plan3.py:175` `    ev = cp.read_events(os.path.join(runs, "%s_free_%s" % (tag, harness), "out_%s_free_events.csv" % tag))`

1. **No `timing.csv` row for the F2 completion.** `Rpl_SyncCompleteCloseByAt` calls `Rpl_TmDiffStageSends` / `Rpl_OrderLogDiff` / `Rpl_DrainOutputs` and does not call `Rpl_TmWriteTimingRow` (2706-2731). Score does not read timing. Minor.

2. **Order rows at the OUT_BY time can follow the tick's SYNC rows at the tick.** Completion stamps at `out_by_ms` (2727-2728); the later `Rpl_TmProcessSyncRemovals(t)` / `Rpl_OrderLogDiff(t, "SYNC")` uses the tick (3050-3051). Those extra rows are PLACE/REMOVE/SYNC, not FILL. Score ignores them.

3. **Market seeded at the OUT_BY time even if `g_rpl_tm_free_ms` is later.** Prompt requires that:

`3738152:prompts/cursor_plan4_f1f4.md:125`
```
    (the `CB_DONE` path, core 1005-1024; timing 0, core 2716), at the `OUT_BY` row's time: the
```

`3738152:prompts/cursor_plan4_f1f4.md:126` `    market seeded at that time; any order the EA places in it (an exit promoted by the exit queue,`

`7d8fa13:ea/fxgrind_replay_core.mqh:2712` `   const long mkt_ms = Rpl_TmMarketMsAt(out_by_ms);`

`7d8fa13:ea/fxgrind_replay_core.mqh:2713` `   Rpl_TmSeedMarketAt(mkt_ms);`

Intended. Does not change a score input except through the completion's own deals/events (which the gate wants).

4. **`g_rpl_sync_idx` set at the start of each sync row.**

`7d8fa13:ea/fxgrind_replay_core.mqh:2812` `      g_rpl_sync_idx = g_rpl_sync_real_applied;`

Final value after the loop is the last applied index, same as setting it at the end. Order-log `sync_idx` is not read by compare/score.

None of the four changes an output those two scripts read. Not a gate defect.

---

## Q1

**NOT A DEFECT.**

Prompt "How the completion runs":

`3738152:prompts/cursor_plan4_f1f4.md:124` `  - **How the completion runs (all of these hold):** it runs as a close-by completion does today`

`Rpl_SyncCompleteCloseByAt`:

`7d8fa13:ea/fxgrind_replay_core.mqh:2708` `   if(g_rpl_tm_on)`

`7d8fa13:ea/fxgrind_replay_core.mqh:2709` `      Rpl_TmProcessSyncRemovals(sync_tick_ms);`

`7d8fa13:ea/fxgrind_replay_core.mqh:2710` `   else`

`7d8fa13:ea/fxgrind_replay_core.mqh:2711` `      Rpl_OrderLogDiff(sync_tick_ms, "SYNC");`

`7d8fa13:ea/fxgrind_replay_core.mqh:2717` `   g_rpl_sync_completing_out_by = true;`

`7d8fa13:ea/fxgrind_replay_core.mqh:2718` `   Rpl_ProcessCloseByDone(out_by_ms, one, 1);`

`7d8fa13:ea/fxgrind_replay_core.mqh:2721` `      long cb_cursor = MathMax(out_by_ms, g_rpl_tm_free_ms);`

`7d8fa13:ea/fxgrind_replay_core.mqh:2724` `      Rpl_TmDiffStageSends("CB_DONE", cb_cursor, cb_sends, false, cb_empty, 0, cb_empty, 0);`

`7d8fa13:ea/fxgrind_replay_core.mqh:2727` `      Rpl_ScanNewOrders(out_by_ms);`

`7d8fa13:ea/fxgrind_replay_core.mqh:2728` `      Rpl_OrderLogDiff(out_by_ms, "CB_DONE");`

`7d8fa13:ea/fxgrind_replay_core.mqh:2730` `   Rpl_DrainOutputs(out_by_ms);`

- Market seeded at the row's time: 2712-2713.
- Timed: `Rpl_TmDiffStageSends` registers PLACE via `Rpl_TmApplySendRow` / `Rpl_BkPlace` (same path as a CB_DONE stage). Timing 0: `Rpl_ScanNewOrders` + `Rpl_OrderLogDiff`.
- Outputs drained at the row's time: 2730 (`Rpl_DrainOutputs` writes `ea_event` / `SCALP_CLOSED` at `tick_ms`).
- Queued pair taken off first: `Rpl_SyncPopCloseByForEntTicket` walks deferred list, pending `RPL_TM_EV_CLOSEBY_DONE`, then EA queues and calls `Rpl_RemoveCloseByQueueTicket` (2684-2699) *before* `Rpl_SyncCompleteCloseByAt`.
- Only those three sources: if `Pop` returns false, `ApplySyncDealsUpTo` does not call Complete (2842-2845). Case b never synthesises a pair.

Calling `Rpl_TmProcessSyncRemovals(sync_tick_ms)` / `Rpl_OrderLogDiff(..., "SYNC")` **before** the completion is right. `Rpl_ApplySyncDealsUpTo` may have already changed the book on earlier rows of the same `while` (ENT/EXT/ROLL). Those removals must be snapshotted as SYNC at the *tick*, so `Rpl_TmDiffStageSends("CB_DONE")` / `Rpl_OrderLogDiff(..., "CB_DONE")` sees only the completion's own sends. Otherwise a SYNC REMOVE would be stamped CB_DONE and, timed, charged `g_rpl_tm_d_remove` (43 ms) on the EA clock. The prompt's "its own sends" reading is the reason this exists.

---

## Q2

**NOT A DEFECT.**

`touched`:

`7d8fa13:ea/fxgrind_replay_core.mqh:2646` `      const ulong ord_tk = side.layers[i].exit_order_ticket;`

`7d8fa13:ea/fxgrind_replay_core.mqh:2647` `      const bool touched = (side.layers[i].exit_position_ticket != 0)`

`7d8fa13:ea/fxgrind_replay_core.mqh:2648` `                           || (g_rpl_tm_on && ord_tk != 0 && Rpl_BkIsExec(ord_tk));`

1. **Timing 0, same-tick fill.** Instant path applies sync *before* fills:

`7d8fa13:ea/fxgrind_replay_core.mqh:2934` `   Rpl_ApplySyncDealsUpTo(t);`

`7d8fa13:ea/fxgrind_replay_core.mqh:2951` `   Rpl_FillsOnTick(t, tick.bid, tick.ask);`

If the exit has not filled on an earlier tick, `exit_position_ticket == 0` and `g_rpl_tm_on` is false, so `touched` is false. F2 b removes the resting exit *before* `Rpl_FillsOnTick` can fill it. That is the prompt: "an exit order not executing … OR no exit order". A same-tick touch is not "has touched" yet. If it *already* filled earlier,

`efada62:ea/grind_engine.mqh:3007` `      side.layers[layer_idx].exit_position_ticket = position_id;`

and the order is left alone.

2. **Timed, reset between touch and DEAL.** `Rpl_TmBrokerStep` sets `g_rpl_bk[i].exec = true` (1225) and enqueues DEAL at `t+261`. A later EXT in the same `ApplySyncDealsUpTo` calls `SyncResetToTrueBook`. The ENT is still in `g_rpl_true_book` (`EXT` only sets `exit_pos`, 2835), so `present == true` (2776-2778) and the layer is not re-seeded. `Rpl_BkIsExec(ord_tk)` stays true. `touched` is true. Reset does not invent a miss.

3. **Stale `exit_position_ticket` from an earlier exit of the same number.** On OUT_BY the EA removes the layer:

`efada62:ea/grind_engine.mqh:2940` `         Grind_RemoveLayerAt(side, i);`

A later ENT of that number is a new `GrindLayer` (append), `exit_position_ticket = 0`. Re-running `Rpl_SyncApplyRealExtToSide` when the field already equals `real_exit_pos` is a no-op (`!touched` writes the same value; `touched` returns). No case where the test reads touched but the replay made no exit of *this* layer.

---

## Q3

**NOT A DEFECT.**

Every live queue site puts the ENT position in `ticket1`:

`efada62:ea/grind_engine.mqh:3005` `      const ulong orig_pos = side.layers[layer_idx].position_ticket;`

`efada62:ea/grind_engine.mqh:3011` `            Grind_QueueCloseBy(g_grind_long_closeby_queue, orig_pos, position_id);`

`efada62:ea/grind_engine.mqh:3013` `            Grind_QueueCloseBy(g_grind_short_closeby_queue, orig_pos, position_id);`

`efada62:ea/grind_engine.mqh:3440` `         Grind_QueueCloseBy(g_grind_long_closeby_queue, layer.position_ticket, pos_out);`

`efada62:ea/grind_engine.mqh:3442` `         Grind_QueueCloseBy(g_grind_short_closeby_queue, layer.position_ticket, pos_out);`

`efada62:ea/grind_closeby.mqh:113` `   queue[idx].ticket1 = ticket1;`

`efada62:ea/grind_closeby.mqh:114` `   queue[idx].ticket2 = ticket2;`

Snapshot copies that as `t1`:

`7d8fa13:ea/fxgrind_replay_core.mqh:2405` `         out[count].t1 = (q == 0) ? g_grind_long_closeby_queue[i].ticket1 : g_grind_short_closeby_queue[i].ticket1;`

Deferral key:

`7d8fa13:ea/fxgrind_replay_core.mqh:2456` `      if(g_rpl_cfg.sync && !g_rpl_sync_completing_out_by && Rpl_TrueBookHasEntTicket(before[i].t1)) {`

A replay-only layer is not in `g_rpl_true_book`, so `Rpl_TrueBookHasEntTicket` is false and the pair completes at once (today's CB_DONE). Correct: there is no real ENT `OUT_BY` to wait for. Prompt c,d only delays pairs whose ENT is still in the true book.

---

## Q4

**DEFECT** (one edge: F2 completion gates on `out_by_ms` but stamps timed sends at `cb_cursor`).

Prompt:

`3738152:prompts/cursor_plan4_f1f4.md:95`
```
  - **Sends:** every EA stage or handler whose start is CLOSED (timed: `STAGE:CLOSEBY`, `LATTICE`,
```

`3738152:prompts/cursor_plan4_f1f4.md:96`
```
    `ENGINE`, `TIMER`, the `DEAL` and `CB_DONE` handlers; timing 0: the same calls in
```

`3738152:prompts/cursor_plan4_f1f4.md:97`
```
    `Rpl_ProcessOneTickInstant`) runs with both send seams refusing:
```

| Path | Gated? | Should be? |
|---|---|---|
| Timed TIMER | Yes: `Rpl_TmRunTimerHandler` -> `Rpl_TmRunStage("TIMER")` gates at `stage_start=cursor` (1136, 996) | Yes (listed) |
| Queued OnTick | Yes: `Rpl_TmRunOntickHandler` -> `Rpl_TmRunStage` CLOSEBY/LATTICE/ENGINE, each at its `cursor` (1162-1169) | Yes (those stages) |
| F2 completion / CB_DONE | Partial: `Rpl_ProcessCloseByDone` gates at `tick_ms` (2517). Timed completion passes `out_by_ms` (2718) but then diffs at `cb_cursor = MathMax(out_by_ms, g_rpl_tm_free_ms)` (2721) | Yes (CB_DONE handler). Gate time must be the handler/send start, not a cheaper clock |
| `Rpl_TmProcessSyncRemovals` | No. It only `Rpl_OrderLogDiff` + `Rpl_BkDrop` + cancel DEAL events (1204-1214). No OrderSend | No (not a send) |
| DEAL already pending when the session closes | Yes: handler `start = MathMax(ev.start_ms, g_rpl_tm_free_ms)` (1039), gate at `start` (1092). New touches while CLOSED never enqueue (`Rpl_TmBrokerStep` 1219-1220) | Yes (listed) |

The regular timed CB_DONE handler already gates at `start = MathMax(ev.start_ms, g_rpl_tm_free_ms)` (1108, then 1116). The F2 completion does not.

**The defect.** If `out_by_ms` is OPEN (23:58:18.000) and the EA is still busy so `g_rpl_tm_free_ms = 1791331140000` (23:59:00.000 CLOSED), `Rpl_SessionSendGateBegin(out_by_ms)` sees OPEN and allows the send; `Rpl_TmDiffStageSends` stamps it at `cb_cursor` CLOSED. Reverse: `out_by_ms` CLOSED, `cb_cursor` later OPEN, gate refuses a send that would start OPEN.

**Smallest fix.** In `Rpl_SyncCompleteCloseByAt`, compute `const long gate_ms = g_rpl_tm_on ? MathMax(out_by_ms, g_rpl_tm_free_ms) : out_by_ms;` and pass `gate_ms` into `Rpl_ProcessCloseByDone` (keep deal/output timestamps at `out_by_ms` as the prompt's "at that row's time"). Same `gate_ms` is already `cb_cursor`.

**Test values.** IC Tue table. Sync. Layer S0 ENT `6901` entry `1.10500`. Arithmetic from `RPL_T0 = 1791280800000` (10:00:00): 23:58:00 = `1791331080000`.

- real EXT at `1791331070000` (23:57:50) pos `6902`
- OUT_BY at `1791331098000` (23:58:18, OPEN = 23:58:00 + 18000)
- Force `g_rpl_tm_free_ms = 1791331140000` before the OUT_BY row (a prior ENGINE that placed until 23:59:00)

Today: S0 L0 ENT PLACE allowed, order time `1791331140000` while CLOSED. After the fix: 0 PLACE, seams restored, OUT_BY deals still at `1791331098000`.

---

## Q5

**NOT A DEFECT.**

Live guard:

`efada62:ea/grind_engine.mqh:2005` `   MqlTick tick;`

`efada62:ea/grind_engine.mqh:2008` `   if(Grind_FeedStaleAfterTick(tick.time_msc, g_grind_last_feed_tick_msc))`

`efada62:ea/grind_pure.mqh:259` `   if(last_feed_tick_msc <= 0) {`

`efada62:ea/grind_pure.mqh:260` `      last_feed_tick_msc = tick_msc;`

`efada62:ea/grind_pure.mqh:261` `      return false;`

`efada62:ea/grind_pure.mqh:263` `   const bool stale = ((tick_msc - last_feed_tick_msc) > max_age_ms);`

`efada62:ea/grind_state.mqh:36` `long           g_grind_last_feed_tick_msc = 0;`

`OnInit` in `efada62:ea/fxgrind.mq5` (I opened 190-340) sets `g_grind_start_add_reprice_long / _short` and never assigns `g_grind_last_feed_tick_msc`. After a process start it is 0, so the first `Grind_GuardsAllowTrading` is never stale. F4:

`7d8fa13:ea/fxgrind_replay_core.mqh:1493` `   g_rpl_last_engine_attempt_tick_ms = 0;`

`7d8fa13:ea/fxgrind_replay_core.mqh:3082` `   g_rpl_last_engine_attempt_tick_ms = 0;`

`7d8fa13:ea/fxgrind_replay_core.mqh:1014` `      const bool stale_skip = (g_rpl_last_engine_attempt_tick_ms > 0`

`7d8fa13:ea/fxgrind_replay_core.mqh:1015` `                               && (stage_market_ms - g_rpl_last_engine_attempt_tick_ms) > 5000);`

`7d8fa13:ea/fxgrind_replay_core.mqh:1016` `      g_rpl_last_engine_attempt_tick_ms = stage_market_ms;`

First attempt of a segment is never stale (prompt F4). That matches live's first attempt after a cold start. A live *re*-init without unloading would keep the old `last_feed`; F4 zeros every segment (every INIT). The prompt asked for the segment rule, not that live quirk.

Timed: `stage_market_ms = Rpl_TmMarketMsAt(stage_start)` (990) is the newest tick at the stage start — the quote `Grind_GuardsAllowTrading` would read from `SymbolInfoTick` after `Rpl_TmSeedMarketAt`. Yes.

Live's own guard stays inert (A7): replay still seeds `g_grind_last_feed_tick_msc` from the *terminal* tick (2944-2946, 3056-3058), not from the replay tape, so the EA guard does not fire on tape gaps. F4 is the harness stand-in.

---

## Q6

**NOT A DEFECT.**

Opened `7d8fa13:ea/fxgrind_replay_core.mqh` 220-320, 330-445, 970-1225, 1475-1500, 2395-2868, 2925-3110, 3695-3760, 3888-3910. No declaration-after-use in the new F1-F4 blocks (`RplSessionWindow` / `RplSendGateSnap` / `Rpl_ParseHHMM` are defined before first use). Structs with `string` already existed (`RplOrderRow`, `RplTmPendingEv.deal_comment`); F1/F2 add the same kind of copies the harness already compiles. `Rpl_AddTestSession` / `Rpl_LoadSessionsFile` / `Rpl_SessionSendGateBegin` all `return` on the failure paths I opened.

`int` / `uint` mix:

`efada62:ea/grind_closeby.mqh:31` `int    g_grind_closeby_test_send_retcode = TRADE_RETCODE_DONE;`

`7d8fa13:ea/fxgrind_replay_core.mqh:237` `   uint prev_cb_rc;`

`7d8fa13:ea/fxgrind_replay_core.mqh:287` `   snap.prev_cb_rc = g_grind_closeby_test_send_retcode;`

`7d8fa13:ea/fxgrind_replay_core.mqh:301` `   g_grind_closeby_test_send_retcode = snap.prev_cb_rc;`

10018 / `TRADE_RETCODE_DONE` fit in both. Implicit conversion under `#property strict` is the same class of mix the file already had for order retcodes (`prev_ord_rc` is `uint`, `g_grind_order_test_send_retcode` is the existing EA hook). Names are `g_rpl_*` / `Rpl_*`; no clash with `g_grind_*`. I did not compile.

---

## Q7

**NOT A DEFECT.**

**RT64 ROLL and L2's add target.** Row:

`7d8fa13:ea/fxgrind_replay_tests.mq5:2505` `   rows[0] = IntegerToString(RplMs(RPL_T0, 0) + 500) + ",ROLL,L,0,,6401,1.09800";`

ROLL writes only the true-book VL:

`7d8fa13:ea/fxgrind_replay_core.mqh:2857` `            if(g_rpl_true_book[i].ticket == rd.position_id) {`

`7d8fa13:ea/fxgrind_replay_core.mqh:2858` `               g_rpl_true_book[i].vl = rd.level;`

`Rpl_SyncResetToTrueBook` re-seeds only when `!present` (2781-2785). `6401` is already a live layer, so `Grind_VLGet(6401)` is unchanged (still no VL). Add anchor stays L1 entry `1.09930`:

`efada62:ea/grind_engine.mqh:2268` `      const int depth_idx = Grind_FindDeepestLayerArrayIndex(side);`

`efada62:ea/grind_engine.mqh:2271` `      anchor = side.layers[depth_idx].entry_price;`

when `!any_vl`, target `1.09930 - 0.00070 = 1.09860`. The ROLL does **not** move L2's add target away from `1.09860` at `7d8fa13`. Tick 1 `bid=1.09860` still clamps to `1.09859`; F3 is what prevents the MODIFY. The assert is for the right reason.

**RT65 `if(l1_n == 4)`.** The count is asserted *first*:

`7d8fa13:ea/fxgrind_replay_tests.mq5:2569` `   AssertTrue(label + " 0 sends on stale tick t2", t2_sends == 0);`

`7d8fa13:ea/fxgrind_replay_tests.mq5:2570` `   AssertTrue(label + " 4 L1 ENT order rows", l1_n == 4);`

`7d8fa13:ea/fxgrind_replay_tests.mq5:2571` `   if(l1_n == 4) {`

The `if` only skips the price/time detail if the count already failed. It cannot make a wrong `l1_n` look like a pass.

No other new RT I opened has an `if` that skips its only assert.

---

## Q8

**DEFECT** (two facts missing from the prompt/commits that affect running the tests and the development gate on this Windows box).

1. **Working-tree CRLF on `sessions_eurusd_ic.csv`.** The file is LF in git (`bcfc305` lines 1-6, no `\r` in the blob). The test reads the working tree as bytes:

`bcfc305:research/replay/test_build_holdout.py:249` `        with open(path, "rb") as f:`

`bcfc305:research/replay/test_build_holdout.py:250` `            raw = f.read()`

`bcfc305:research/replay/test_build_holdout.py:251` `        self.assertNotIn(b"\r", raw)`

`.gitattributes` pins `*.mqh` / `*.mq5` / `*.py` to LF, not `*.csv`:

`3738152:.gitattributes:5` `* text=auto`

`3738152:.gitattributes:21` `*.py    text eol=lf`

On Windows `core.autocrlf=true`, checkout writes `\r\n`. `python -B -m unittest` then fails `test_sessions_eurusd_ic_csv_file` (`AssertionError: b'\r' unexpectedly found`). Smallest fix: add `*.csv   text eol=lf` (and `*.sha256 text eol=lf`) to `.gitattributes`. Hand check: after checkout, `research/replay/inputs/sessions_eurusd_ic.csv` is 102 bytes, SHA-256 of the git blob, no `0x0d`.

2. **`-Mode Inputs` only stages committed manifest entries** (see C-1 quotes `efada62:tools/replay_run.ps1:128-148`). Plan 4's "rebuild the inputs, new manifests" (`3738152:docs/research/replay-calibration-eurusd-4.md:86-87`) is not a local `build_*.py` write: the operator's `replay_run.ps1 -Mode Inputs -Set eurusd_20261008` will not copy `sessions_eurusd_ic.csv` and will hash-mismatch the rebuilt `real_*.csv` / `run_*.csv` until those files and both `.sha256` manifests are committed. That fact is missing from Part A's commit list and from B's record.

---

## Files and line ranges opened

- `db94402:prompts/argon_commits_f1f4.md` 1-135
- `3738152:prompts/cursor_plan4_f1f4.md` 1-215 (full)
- `e4d96f4:reviews/cursor_restate_f1f4.md` 1-80
- `3738152:docs/research/replay-calibration-eurusd-4.md` 70-110
- `3738152:.gitattributes` 1-40
- `3738152:research/replay/build_real.py` 60-85
- `3738152:research/replay/build_holdout.py` 1-172 (full; old `cmd_build`)
- `3738152:research/replay/build_orders.py` 25-50
- `3738152:research/replay/compare.py` 145-160, 390-410
- `3738152:research/replay/score_plan3.py` 165-180
- `3738152:research/replay/inputs/eurusd_holdout.sha256` 1-19
- `3738152:research/replay/inputs/eurusd_20261008.sha256` 1-30 plus name scan
- `bcfc305:research/replay/build_real.py` 60-90
- `bcfc305:research/replay/build_segments.py` `to_run_csv` / `sessions_file`
- `bcfc305:research/replay/build_inputs.py` 1-124 (full)
- `bcfc305:research/replay/build_holdout.py` 1-215 (full)
- `bcfc305:research/replay/inputs/sessions_eurusd_ic.csv` 1-6
- `bcfc305:research/replay/test_build_holdout.py` 240-260
- `2193b6b` commit subject only (not the tree)
- `efada62:tools/replay_run.ps1` 125-155
- `efada62:ea/fxgrind_replay_core.mqh` 1835-1850, 2545-2585
- `efada62:ea/grind_engine.mqh` 1995-2015, 2260-2275, 2935-3020, 3435-3445, 3219-3222
- `efada62:ea/grind_closeby.mqh` 25-40, 108-120
- `efada62:ea/grind_pure.mqh` 250-270
- `efada62:ea/grind_state.mqh` 30-42
- `efada62:ea/fxgrind.mq5` 190-340 (OnInit; no `g_grind_last_feed_tick_msc` assign)
- `19d8db6:ea/fxgrind_replay_core.mqh` 1198-1215, 2538-2550
- `19d8db6` commit message
- `538b15e`, `68fe443`, `acc93fd`, `9748480` commit subjects only
- `7d8fa13:ea/fxgrind_replay_core.mqh` 220-320, 330-445, 970-1225, 1475-1500, 2395-2868, 2925-3110, 3695-3760, 3888-3910
- `7d8fa13:ea/fxgrind_replay_tests.mq5` 2490-3190 and OnStart tail (RT64-RT74 calls)
- `git diff --stat efada62 origin/replay-plan4` (core + tests only)
- `git log efada62..origin/replay-plan4` and `3738152..origin/plan4-tools`
