# Plan 4 F1-F4, Fix 1 --- Section 0 Restate (`prompts/cursor_plan4_f1f4_fix1.md` on `origin/main` at `72abbad`)

Prompt: `prompts/cursor_plan4_f1f4_fix1.md` (s83d, `72abbad`).
Part A base: `plan4-tools` at `bcfc305`. Part B base: `replay-plan4` at `7d8fa13`.
This file is s0 only. No test and no code is changed here.

Pip used below: `1 pip = 0.00010`, so `0.1 pip = 0.00001` and `2.0 pips = 0.00020`. `"base"` at `7d8fa13` (`Rpl_TmApplySens`): `d_place = 287`, `lam = 261`, `limit_price` false. `RPL_T0 = D'2026.10.06 10:00:00'`, `RplMs(RPL_T0, 0) = 1791280800000`.

---

## 1. One line per change in s2 and s3, quoting the prompt

### s2 Part A (Python, `plan4-tools` on `bcfc305`)

- **A-5.** "`build_inputs.py` gains `--sessions FILE` (optional, default none)." "Given: the file is copied into `--out` under its base name, read in text mode and written ASCII with `\n` line ends (as `build_holdout.py` 163-170), and its base name is passed as `sessions_file` to every `fleet_files` call, so each `run_<tag>.csv` gains the 24th column." "Not given: the output is byte-identical to today's."
- **A-6.** "`test_sessions_eurusd_ic_csv_file` reads the file and replaces `b"\r\n"` with `b"\n"` before its checks" "(then asserts no `\r` remains and the six lines of A-4)." "Do NOT change `.gitattributes`."

### s3 Part B (MQL5, `replay-plan4` on `7d8fa13`)

- **B-8.** "RT67, timing 0. The two open ticks assert `seam_cnt == 1 && ord_cnt == 1` (the long L0 only, A1) and keep the L0 price 1.09981 (mid 1.10001 - 2 pips). The closed ticks unchanged."
- **B-9.** "RT68. `ungated places 2 L0s` becomes `ungated places 1 L0`: `Rpl_OrderLogCount() == 1`."
- **B-10.** "RT72. The EXT deal price is 1.10452 (A3: the deal at T+261 takes the newest tick at or before it, T+100, ask 1.10452). Keep 1e-6."
- **B-11.** "RT64, redesigned so it tests F3." Add, after the two `Rpl_SeedLayer` calls and before the run, `Rpl_SeedOrder("S", 0, "ENT", 1.10051, 6412UL, ORDER_TYPE_SELL_LIMIT);`. "Assert: the PLACE at T0 at 1.09860 (new); `mod_n == 0` and the price 1.09860 (existing)."
- **B-14.** "RT69's first run also asserts ONE replay EXT IN deal for S L0 at T0 (the touched path, price 1.10400 at timing 0); RT73's T+1500 run also asserts ZERO `OUT_BY` deal rows (L2's real `OUT_BY` at T+600 had no replay close-by)."
- **RT75.** "As RT67's helper with `Rpl_SetTiming(1, "base")` (reset to 0 after)", one tick each, bid 1.10000 / ask 1.10002, the IC table. Tue 23:58:59.900 (`1791331139900`): "one `PLACE` of L L0 ENT, its row at `1791331139900` (send_start), price 1.09981." Tue 23:59:00.000 (`1791331140000`): "0 orders; both seams' `send_ok` true afterwards." Wed 00:01:00.000 (`1791331260000`): "one `PLACE` of L L0 ENT at 1.09981."
- **RT76.** "IC table, timing 1, `cfg.from_ms = t1`, `cfg.to_ms = t2 + 1000`" and `Rpl_SeedOrder("L", 0, "ENT", 1.11909, 7611UL, ORDER_TYPE_BUY_LIMIT)`. "Expected: ONE IN deal L L0 ENT at `1791331140000`, price 1.11903"; "ZERO `PLACE`, `MODIFY` or `REMOVE` rows at or after `1791331140000`"; "ONE `FILL` row for 7611 at `1791331140026`"; "both seams' `send_ok` true afterwards."
- **RT77.** "Unit test of `Rpl_SyncCompletionGateMs`, the IC table loaded, every call with `out_by_ms = 1791331098000`." "Timing 0: returns `1791331098000`." Then timing 1 and `g_rpl_tm_free_ms = 1791331140000`: "returns `1791331140000`, and `Rpl_SessionIsOpen(1791331140000)` is false while `Rpl_SessionIsOpen(1791331098000)` is true." "`g_rpl_tm_free_ms = 1791331000000`: returns `1791331098000`." After: "`Rpl_SetTiming(0, "base")` then `Rpl_ResetAll()`."
- **B-12.** "`long Rpl_SyncCompletionGateMs(const long out_by_ms)`: timed, `MathMax(out_by_ms, g_rpl_tm_free_ms)`; timing 0, `out_by_ms`. (Tests commit: a stub returning `out_by_ms`.)" "`Rpl_ProcessCloseByDone` gains a last parameter `const long gate_ms = -1`; its `Rpl_SessionSendGateBegin` uses `gate_ms` when `>= 0`, else `tick_ms` (its other callers unchanged). `Rpl_SyncCompleteCloseByAt` passes `Rpl_SyncCompletionGateMs(out_by_ms)`. The `OUT_BY` deal rows and `SCALP_CLOSED` keep the row's time."
- **B-13.** "`RplSendGateSnap.prev_cb_rc` becomes `int` (A8)."
- **The record (last commit).** "the header comment's range to RT77; `PENDING: operator compile and suite` where the figure goes."

---

## 2. Tests added or changed: name, expected values, arithmetic

The six lines of A-4, asserted by A-5 and A-6 after LF normalization:

```
day_of_week,trade_from,trade_to
1,00:01,23:59
2,00:01,23:59
3,00:01,23:59
4,00:01,23:59
5,00:01,23:57
```

### Part A

1. **`test_build_inputs.py::test_sessions_cli_crlf_copy_and_column` (new, A-5).** Synthetic archive built the way `test_build_defaults_byte_identical_and_plan4_flags` builds one. A CRLF copy of the six A-4 lines, base name `sessions_eurusd_ic.csv`, passed as `--sessions`.
   - With the flag: `run_eurusd_b.csv` header ends `,orders_file,sessions_file` (24th column). Every data row ends `,sessions_eurusd_ic.csv`. The copied file in `--out` has no `\r` and equals the six lines above (text mode in, ASCII `\n` out).
   - Without the flag: the header has 23 fields.
   - Not asserted: byte-identical output against today's files.

2. **`test_build_holdout.py::test_sessions_eurusd_ic_csv_file` (changed, A-6).** Read the raw bytes of `research/replay/inputs/sessions_eurusd_ic.csv`, replace `b"\r\n"` with `b"\n"`, then assert no `b"\r"` remains and the text equals the six lines above. `.gitattributes` is not changed.

### Part B

3. **`Test_RT67_SessionSendsAndBoundaries` (changed, B-8), timing 0.** Helper already uses bid `1.10000`, ask `1.10002`. Mid `(1.10000 + 1.10002) / 2 = 1.10001`. Long L0 is `1.10001 - 2 pips = 1.10001 - 0.00020 = 1.09981`.
   - Open `D'2026.10.06 23:58:59'`: `seam_cnt == 1 && ord_cnt == 1`, L0 price `1.09981` (`1e-6`).
   - Open `D'2026.10.07 00:01:00'`: `seam_cnt == 1 && ord_cnt == 1`, L0 price `1.09981` (`1e-6`).
   - Closed ticks unchanged: `23:59:00`, `23:59:30`, `00:00:30`, and Fri `23:57:30` each stay `seam_cnt == 0 && ord_cnt == 0 && restored`.

4. **`Test_RT68_SessionsFileLoadAndAbort` (changed, B-9).** The ungated run (`run_rt68n.csv`, no `sessions_file`) asserts `Rpl_OrderLogCount() == 1`. The other RT68 assertions stay as they are (`SessionsCount() == 5`, closed tick `OrderLogCount() == 0`, missing file aborts, absent file `SessionsCount() == 0`).

5. **`Test_RT72_TimedInFlightExitAtRealExt` (changed, B-10).** Deal time stays `T + 261 = 1791280800261`. Newest tick at or before that time is `T + 100` (ask `1.10452`); the next tick is `T + 300`. `"base"` fills a buy at that tick's ask, so the EXT IN price is `1.10452` (`1e-6`). The count and time assertion stays `ext_in == 1 && ext_ms == T + 261`.

6. **`Test_RT64_SyncResetNoStartupAddReprice` (changed, B-11).** After the two `Rpl_SeedLayer` calls and before the run, seed `Rpl_SeedOrder("S", 0, "ENT", 1.10051, 6412UL, ORDER_TYPE_SELL_LIMIT)`.
   - Short L0 price: tick 0 mid `(1.09900 + 1.09902) / 2 = 1.09901`, plus 15 pips `0.00150` = `1.10051`.
   - Tick 0 (bid `1.09900`, ask `1.09902`): L2 target is L1 `1.09930 - 7 pips = 1.09930 - 0.00070 = 1.09860`. Buy clamp ceiling is `1.09900 - 0.00001 = 1.09899`. `1.09860` is below that ceiling, so it is not clamped. One `PLACE` of L L2 ENT at T0 (`1791280800000`), price `1.09860` (`1e-6`). That place consumes the segment-start one-shot.
   - The `ROLL` row stays at `T0 + 500 = 1791280800500`.
   - Tick 1 (bid `1.09860`, ask `1.09862`, as the test already has): target `1.09860` clamps to `1.09860 - 0.00001 = 1.09859`. Distance `0.00001` (0.1 pip). With F3 the deadband is 2.0 pips (`0.00020`); `0.00001 < 0.00020`, so `mod_n == 0` and the resting price stays `1.09860` (`1e-6`).
   - Short L0 distance from mid: tick 0 `1.10051 - 1.09901 = 0.00150` = 15.0 pips; tick 1 mid `(1.09860 + 1.09862) / 2 = 1.09861`, `1.10051 - 1.09861 = 0.00190` = 19.0 pips. Both are under the 50-pip recenter threshold, so the short L0 is not moved. It is a seed, so no short entry is sent.
   - New assertion (one): the `PLACE` of L L2 ENT at T0 at `1.09860`. Existing assertions kept: `mod_n == 0`, and the price `1.09860`.

7. **`Test_RT69_SyncDeferCloseByToRealOutBy` (changed, B-14).** On the first run (`to_ms = T + 600`, timing 0), one more assertion: one replay EXT IN deal for S L0 at T0 (`1791280800000`), price `1.10400` (`1e-6`). Tick 0 is bid `1.10398`, ask `1.10400`, and the seeded buy limit is `1.10400`, so the touch is at T0. Timing 0 fills at the limit price `1.10400`.

8. **`Test_RT73_SyncHeldExitAtRealExt` (changed, B-14).** On the `T + 1500` run (`Rpl_TestRunRt73UpTo(3, T + 1500)`), one more assertion: zero `OUT_BY` deal rows. L2's real `OUT_BY` is at `T + 600`.

9. **`Test_RT75_TimedEngineStageGate` (new).** Same one-tick helper as RT67, with `Rpl_SetTiming(1, "base")` and `Rpl_SetTiming(0, "base")` after. Bid `1.10000`, ask `1.10002`, IC table. Four assertions:
   - Tue 23:58:59.900 = `1791331139900` (OPEN: Tuesday `00:01 <= 23:58:59.900 < 23:59`). One `PLACE` of L L0 ENT, row time `1791331139900` (send start), price `1.09981` (`1e-6`). Price arithmetic is the same as B-8: mid `1.10001 - 0.00020 = 1.09981`. The send ends at `1791331139900 + 287 = 1791331140187` (23:59:00.187, CLOSED). The place is still allowed because F1 gates on the stage start.
   - Tue 23:59:00.000 = `1791331140000` (CLOSED: not `< 23:59`). Order count `0`.
   - After that closed tick, both seams' `send_ok` are true.
   - Wed 00:01:00.000 = `1791331260000` (`1791331140000 + 120000`). OPEN (`00:01` on Wednesday). One `PLACE` of L L0 ENT at `1.09981` (`1e-6`).

10. **`Test_RT76_TimedDealHandlerGate` (new).** IC table, `Rpl_SetTiming(1, "base")` (reset to 0 after). `cfg.from_ms = t1`, `cfg.to_ms = t2 + 1000 = 1791331171000`. Seed `Rpl_SeedOrder("L", 0, "ENT", 1.11909, 7611UL, ORDER_TYPE_BUY_LIMIT)`. Ticks: t1 = `1791331139739` (Tue 23:58:59.739), bid `1.11847`, ask `1.11903`; t2 = `1791331170000` (Tue 23:59:30.000), same quote. Five assertions:
    - One IN deal, L L0 ENT, at `1791331140000`. Touch at t1 because `1.11903 <= 1.11909`. Deal due `1791331139739 + 261 = 1791331140000` (23:59:00.000, CLOSED).
    - Deal price `1.11903` (`1e-6`), t1's ask. The newest tick at or before `1791331140000` is t1; t2 is later. `"base"` does not fill at the limit `1.11909`.
    - Zero `PLACE`, `MODIFY`, or `REMOVE` rows at or after `1791331140000`. The t1 ONTICK's short L0 is a `PLACE` at send start `1791331139739`, which is before that cut: mid `(1.11847 + 1.11903) / 2 = 1.11875`, plus 15 pips `0.00150` = `1.12025`, and that send ends at `1791331139739 + 287 = 1791331140026`. At t2 the deal handler starts at `max(1791331140000, 1791331140026) = 1791331140026` (23:59:00.026, CLOSED), so the exit at `1.11903 + 10 pips = 1.11903 + 0.00100 = 1.12003`, and any add or recenter, are refused.
    - One `FILL` row for ticket `7611` at `1791331140026` (the handler's cursor). A log row, not a send, so it is not one of the refused order rows.
    - Both seams' `send_ok` true afterwards.

11. **`Test_RT77_SyncCompletionGateMs` (new).** IC table loaded. Every call uses `out_by_ms = 1791331098000` (Tue 23:58:18.000: `1791331139900 - 41900`). Five assertions:
    - `Rpl_SetTiming(0, "base")`: returns `1791331098000`.
    - `Rpl_SetTiming(1, "base")` and `g_rpl_tm_free_ms = 1791331140000`: returns `MathMax(1791331098000, 1791331140000) = 1791331140000`.
    - `Rpl_SessionIsOpen(1791331140000)` is false (Tue 23:59:00.000, not `< 23:59`).
    - `Rpl_SessionIsOpen(1791331098000)` is true (Tue 23:58:18.000, inside `00:01` to `23:59`).
    - `g_rpl_tm_free_ms = 1791331000000`: returns `MathMax(1791331098000, 1791331000000) = 1791331098000`.
    - After the asserts: `Rpl_SetTiming(0, "base")` then `Rpl_ResetAll()`.

---

## 3. At the tests commit: what fails, what passes

MQL5 assertion count I will add: RT64 1 + RT69 1 + RT73 1 + RT75 4 + RT76 5 + RT77 5 = 17. `556 + 17 = 573`. The prompt's 573 does not differ.

**Fails at the MQL5 tests commit (the stub of B-12 returns `out_by_ms`).** Only RT77's timed `free_ms` later case: `g_rpl_tm_free_ms = 1791331140000` expects `1791331140000`, and the stub returns `1791331098000`. That case passes in the code commit, when the function is `MathMax(out_by_ms, g_rpl_tm_free_ms)`.

**Passes at the MQL5 tests commit, and why that is right.**

- RT77 timing 0 returns `out_by_ms`, which is what the stub returns.
- RT77's two `Rpl_SessionIsOpen` checks read the IC table already loaded at `7d8fa13`. They do not call the new function.
- RT77 with `g_rpl_tm_free_ms = 1791331000000` expects `1791331098000`, and `MathMax` of an earlier `free_ms` is `out_by_ms`, so the stub matches.
- B-8, B-9, and B-10 pass at the tests commit because they only correct expected values. The code at `7d8fa13` already places one L0 (A1) and already fills RT72 at T+100's ask `1.10452` (A3). The five FAILs at `7d8fa13` are those wrong expected values: RT67's two open ticks (`seam_cnt == 2 && ord_cnt == 2`), RT68's ungated `== 2`, RT64's `1.09860`, and RT72's `1.10400`. After the correction they pass with no engine change, and they still pass after B-12 and B-13.
- RT64 as redesigned, RT75, RT76, and B-14 pass at both commits of this fix. F3, F1, the timing-0 touched EXT fill, and "no replay close-by on L2's `OUT_BY`" are already in `7d8fa13`. That is expected, not a finding.

**Python, its own tests commit** (`python -B -m unittest` from `research/replay`).

- Fails before the code: `test_sessions_cli_crlf_copy_and_column`. `build_inputs.py` has no `--sessions` (A4). Passes after A-5 copies the CRLF file as LF and passes its base name into `fleet_files`.
- Passes in both: `test_sessions_eurusd_ic_csv_file` once it strips `b"\r\n"`. The six lines are already the file; a Windows checkout fails today only because the raw bytes contain `\r` (A5). The A-5 code is not required for this test.

---

## 4. STOP

s0 only. Waiting for the operator's "go".
