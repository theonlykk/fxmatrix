This message has a line count at the bottom

# CURSOR PROMPT: PLAN 4 F1-F4, FIX 1 -- WRONG TEST VALUES, TWO GAPS, ONE GATE TIME (TESTS FIRST)

| | |
|---|---|
| Written | 14-15 Oct 2026 (HANDOFF s83), Claude (Lead Engineer) |
| Why | The suite at `7d8fa13`: 556 run, 551 pass. The five FAILs are WRONG EXPECTED VALUES in the tests (s1 A1-A3), not code defects. The reviews of the commits found two gaps and one defect (Argon `review/argon-commits-f1f4` `35fa3d3`, C-1, C-2, Q4, Q8; DeepSeek `review/deepseek-f2` `da2dcb0`, T-8) |
| Base | Part A on `plan4-tools` at `bcfc305`; Part B on `replay-plan4` at `7d8fa13`. Add commits on top; never rewrite them |
| Prompt it amends | `prompts/cursor_plan4_f1f4.md` at `3738152` (F1-F4, A-1..A-4); everything there still holds unless this file says otherwise |
| Review | Grok 4.6 (in Cursor) on `a360c28`, `review/argon-fix1` `ce6f6ef`: every quote checked by Claude, exact; two defects in this prompt fixed here (RT76's FILL row; RT77's `out_by_ms` and timing reset); B-8..B-11, RT75 confirmed |

## 0. RESTATE AND STOP (do this first; write nothing else)

1. Restate each change of s2 and s3 in one line, quoting this prompt.
2. For every test you add or change: its name, and the expected values you will assert, with
   the arithmetic.
3. Say which tests fail at your tests commit and why, and which pass there (and why that is
   right).
4. STOP. Wait for the operator's "go".

## 1. AUDIT TRAIL (verified by Claude in source; file and line at the given commit)

| # | Fact | Where | Status |
|---|---|---|---|
| A1 | The EA sends at most ONE entry order per engine call: `Grind_TryPlaceL0` and `Grind_EnsureAddNext` return early once `g_grind_ent_sent_this_tick` is set; the long side is served first. On a fresh tick with both sides empty only the long L0 is placed | `ea/grind_engine.mqh` 2074-2075, 2579-2580, 3196, 3219-3222 @ `efada62` | READ; it makes RT67's and RT68's "places 2" wrong (1) |
| A2 | RT64 never has a resting add to reprice: at tick 0 the EMPTY short side places its L0 first (A1), so the long add is first placed at tick 1, already clamped to 1.09859, as a PLACE. RT64 does not test F3 | tests `7d8fa13` 2493-2528; engine 3219-3238 | READ (suite: "no add modify" passes and "stays at 1.09860" fails, at `19d8db6` AND at `7d8fa13`) |
| A3 | The timed deal fills at the quote of the NEWEST tick at or before the deal time (`limit_price` false in "base"): a buy limit fills at that tick's ask | core `7d8fa13` 1062-1069 (`Rpl_TmRunDealHandler`) | READ; RT72's deal at T+261 takes T+100's ask 1.10452, not 1.10400 |
| A4 | `build_inputs.py`'s CLI has no `--sessions`; only `fleet_files` takes `sessions_file`. `build_holdout.py` copies the sessions file (text mode, written LF) and names it | `build_inputs.py` 92-118, `build_holdout.py` 163-170 @ `bcfc305` | READ (Argon C-1) |
| A5 | `.gitattributes` has `* text=auto` and no `*.csv` rule: a Windows checkout gives `sessions_eurusd_ic.csv` CRLF, and `test_sessions_eurusd_ic_csv_file` (raw bytes, asserts no `\r`) fails on the desktop | `.gitattributes` 5; `test_build_holdout.py` 246-260 @ `bcfc305` | READ (Argon Q8) |
| A6 | The F2 completion gates F1 at the `OUT_BY` row's time (`Rpl_ProcessCloseByDone(out_by_ms, ...)`, whose gate is at its `tick_ms`) but, timed, registers its sends from `MathMax(out_by_ms, g_rpl_tm_free_ms)`. The timed `CB_DONE` handler gates at `start = MathMax(ev.start_ms, g_rpl_tm_free_ms)` | core `7d8fa13` 2706-2731, 2516-2517; 1107-1116 | READ (Argon Q4) |
| A7 | RT67 runs at timing 0 only; no test runs F1's send gate in the TIMED path or in the DEAL handler | tests `7d8fa13` 2681-2733 | READ (Argon C-2) |
| A8 | The compile at `7d8fa13` warns once: "possible loss of data due to type conversion from 'uint' to 'int'", core line 301 (`g_grind_closeby_test_send_retcode = snap.prev_cb_rc;`; `RplSendGateSnap.prev_cb_rc` is `uint`, the EA hook is `int`, `ea/grind_closeby.mqh` 31) | operator's GUI compile 14 Oct ~01:47Z | MEASURED |

## 2. PART A: PYTHON (branch `plan4-tools`, on `bcfc305`)

Tests first, in their own commit (`python -B -m unittest` from `research/replay`); then the code.
Report the new tests failing before the code and passing after, and any that pass in both.

- **A-5. `build_inputs.py` gains `--sessions FILE` (optional, default none).** Given: the file
  is copied into `--out` under its base name, read in text mode and written ASCII with `\n` line
  ends (as `build_holdout.py` 163-170), and its base name is passed as `sessions_file` to
  every `fleet_files` call, so each `run_<tag>.csv` gains the 24th column. Not given: the output
  is byte-identical to today's. Test on a synthetic archive (as `test_build_holdout.py`'s
  `test_build_defaults_byte_identical_and_plan4_flags` builds one): with `--sessions` pointing
  at a CRLF copy of the IC file, `run_eurusd_b.csv`'s header ends `,orders_file,sessions_file`,
  every data row ends `,sessions_eurusd_ic.csv`, and the copied file has no `\r` and equals
  the six lines of A-4; without it, the header has 23 fields.
- **A-6. `test_sessions_eurusd_ic_csv_file` reads the file and replaces `b"\r\n"` with `b"\n"`
  before its checks** (then asserts no `\r` remains and the six lines of A-4). Do NOT change
  `.gitattributes` (a repo-wide line-ending change is out of scope).

## 3. PART B: MQL5 (branch `replay-plan4`, on `7d8fa13`)

Files you may change: `ea/fxgrind_replay_core.mqh`, `ea/fxgrind_replay_tests.mq5`. Commits: (1) the
tests, with the one stub of s3 B-12 so they compile; (2) the code (B-12, B-13); (3) the record.

**Test corrections (wrong expected values; the code is right):**

- **B-8. RT67, timing 0.** The two open ticks assert `seam_cnt == 1 && ord_cnt == 1` (the long
  L0 only, A1) and keep the L0 price 1.09981 (mid 1.10001 - 2 pips). The closed ticks unchanged.
- **B-9. RT68.** "ungated places 2 L0s" becomes "ungated places 1 L0": `Rpl_OrderLogCount() == 1`.
- **B-10. RT72.** The EXT deal price is 1.10452 (A3: the deal at T+261 takes the newest tick at
  or before it, T+100, ask 1.10452). Keep 1e-6.
- **B-11. RT64, redesigned so it tests F3.** Add, after the two `Rpl_SeedLayer` calls and before
  the run, `Rpl_SeedOrder("S", 0, "ENT", 1.10051, 6412UL, ORDER_TYPE_SELL_LIMIT);` (the short L0
  resting at mid 1.09901 + 15 pips: no short entry is sent, so the long add is placed at tick 0).
  Hand values: tick 0 (bid 1.09900, ask 1.09902): the add target is L1 1.09930 - 7 pips =
  1.09860, below the bid, not clamped: ONE `PLACE` of L L2 ENT at T0, price 1.09860 (the
  segment-start one-shot flag is consumed here). The `ROLL` row at T0+500 resets the book.
  Tick 1 (bid 1.09860): the target 1.09860 clamps to 1.09859 (ADR-013 buy, 0.1 pip under the
  bid); 0.1 pip apart. Without F3 the reset re-arms the one-shot 0.05-pip deadband: MODIFY to
  1.09859. With F3 the deadband is 2.0 pips: no MODIFY. The short L0 is not recentered (15.0
  and 19.0 pips from mid at ticks 0 and 1, threshold 50). Assert: the PLACE at T0 at 1.09860
  (new); `mod_n == 0` and the price 1.09860 (existing).
- **B-14. Two guard assertions** (DeepSeek T-8): RT69's first run also asserts ONE replay EXT IN
  deal for S L0 at T0 (the touched path, price 1.10400 at timing 0); RT73's T+1500 run also
  asserts ZERO `OUT_BY` deal rows (L2's real `OUT_BY` at T+600 had no replay close-by).

**New tests:**

- **RT75 (F1, the timed ENGINE stage).** As RT67's helper with `Rpl_SetTiming(1, "base")` (reset to
  0 after), one tick each, bid 1.10000 / ask 1.10002, the IC table:
  - Tue 23:58:59.900 (`1791331139900`), OPEN at the stage start: one `PLACE` of L L0 ENT, its row
    at `1791331139900` (send_start), price 1.09981. Its send ends at 23:59:00.187, CLOSED: still
    allowed, F1 gates by the stage's START.
  - Tue 23:59:00.000 (`1791331140000`): 0 orders; both seams' `send_ok` true afterwards.
  - Wed 00:01:00.000 (`1791331260000`): one `PLACE` of L L0 ENT at 1.09981.
- **RT76 (F1, the timed DEAL handler).** IC table, timing 1, `cfg.from_ms = t1`, `cfg.to_ms = t2 + 1000`
  (no timer event falls inside). `Rpl_SeedOrder("L", 0, "ENT", 1.11909,
  7611UL, ORDER_TYPE_BUY_LIMIT)`. Ticks: t1 = Tue 23:58:59.739 (`1791331139739`), bid 1.11847, ask
  1.11903; t2 = Tue 23:59:30.000 (`1791331170000`), same quote. At t1 (OPEN) the broker touches
  the order (ask <= 1.11909): its deal is due at t1 + 261 = `1791331140000` (23:59:00.000,
  CLOSED); the t1 ONTICK places the short L0 (mid 1.11875 + 15 pips = 1.12025, send_start t1,
  ends `1791331140026`). At t2 the deal runs: handler start = max(`1791331140000`,
  `1791331140026`) = `1791331140026`, CLOSED. Expected: ONE IN deal L L0 ENT at `1791331140000`,
  price 1.11903 (t1's ask, A3); ZERO `PLACE`, `MODIFY` or `REMOVE` rows at or after
  `1791331140000` (the exit at 1.12003, any add or recenter: all refused); ONE `FILL` row for
  7611 at `1791331140026` (the DEAL handler logs the filled order at its cursor, core
  `7d8fa13` 947-961: a log row, not a send); both seams' `send_ok` true afterwards.
- **RT77 (B-12, the completion's gate time).** Unit test of `Rpl_SyncCompletionGateMs`, the IC
  table loaded, every call with `out_by_ms = 1791331098000` (Tue 23:58:18.000). Timing 0
  (`Rpl_SetTiming(0, "base")`): returns `1791331098000`. Then `Rpl_SetTiming(1, "base")` and
  `g_rpl_tm_free_ms = 1791331140000`: returns `1791331140000`, and `Rpl_SessionIsOpen(1791331140000)`
  is false while `Rpl_SessionIsOpen(1791331098000)` is true. `g_rpl_tm_free_ms = 1791331000000`:
  returns `1791331098000`. After: `Rpl_SetTiming(0, "base")` then `Rpl_ResetAll()`
  (`Rpl_ResetAll` does not clear `g_rpl_tm_on`, core `7d8fa13` 338, 498-509, 1450-1537).

**Code:**

- **B-12.** `long Rpl_SyncCompletionGateMs(const long out_by_ms)`: timed, `MathMax(out_by_ms,
  g_rpl_tm_free_ms)`; timing 0, `out_by_ms`. (Tests commit: a stub returning `out_by_ms`.)
  `Rpl_ProcessCloseByDone` gains a last parameter `const long gate_ms = -1`; its
  `Rpl_SessionSendGateBegin` uses `gate_ms` when `>= 0`, else `tick_ms` (its other callers
  unchanged). `Rpl_SyncCompleteCloseByAt` passes `Rpl_SyncCompletionGateMs(out_by_ms)`. The
  `OUT_BY` deal rows and `SCALP_CLOSED` keep the row's time.
- **B-13.** `RplSendGateSnap.prev_cb_rc` becomes `int` (A8).
- **The record (last commit):** the header comment's range to RT77; `PENDING: operator compile
  and suite` where the figure goes.

**Expected at the end:** 573 assertions (556 + RT64 1 + RT69 1 + RT73 1 + RT75 4 + RT76 5 + RT77 5;
restate your own count and say if it differs), all passing; at the tests commit only RT77's
timed `free_ms` later case fails. RT64, RT75, RT76 and B-14 test code already at `7d8fa13`, so
they pass at both commits of this fix: say so in the restate (expected, not a finding).

## 4. NEGATIVE SPACE

- Do not deploy, do not CLI compile, do not launch MetaTrader, do not run the MQL5 suite, do not
  `git stash`, do not check out files from other commits, do not merge, no PR, no `git add .` or
  `-u`, do not push to `main` or `replay-harness`, do not rewrite or amend existing commits.
- Do not change any EA file (`ea/grind_*.mqh`, `ea/fxgrind.mq5`, `ea/fxgrind_tests*.mq5`),
  `.gitattributes`, any preset, `compare.py`, `score_plan3.py`, `live_spread.py`, any input set,
  manifest or result.
- Do not change any other existing test's expected value; do not touch RT1-RT63.
- Nothing beyond s2-s3 (DeepSeek T-3 and T-5 are recorded limits, not changes).
- Python: standard library only; ASCII; LF. MQL5: declare before first use.
- When done: push both branches, `git checkout main` in `D:\fxmatrix`, STOP with the SHAs.

## 5. FAILURE MODES: STOP AND REPORT

- A hand value here disagrees with the code as you read it: quote both, do not pick one.
- RT64 as redesigned would not place the add at tick 0, or the short L0 would be sent or moved.
- Any change seems to need an EA file or a seam that does not exist.

## 6. QUESTIONS FOR THE REVIEWER (Argon: answer inside the review; do not edit this file)

Quote every line you cite as `<commit>:<path>:<line>` and its text, or write "not read".

- **Q1.** Check each hand value of B-8 .. B-11 and RT75-RT77 against the code at `7d8fa13` and
  `efada62` (engine). Any wrong?
- **Q2.** RT64 redesigned: does anything else at tick 0 or tick 1 send, move or block the long
  add (exits, the stray-L0 reconcile, a recenter, `Grind_ServiceDueAddFlags`, the lattice)?
- **Q3.** RT76: does the t1 ONTICK, the DEAL event at t2 and the t2 ONTICK run in that order, and
  is every order row the EA tries after `1791331140000` refused?
- **Q4.** What fact is missing?

Line count: 157
