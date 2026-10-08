This message has a line count at the bottom

# CURSOR PROMPT -- REPLAY HARNESS FIX 5 (branch `replay-harness`, on `6a3dfc0`)

**Workspace: `D:\fxmatrix`.** Continue on branch `replay-harness` at
`6a3dfc0` (`802b6c3` fix-4 tests, `7d10bc9` fix-4 core, `6a3dfc0` the second
RT run's log). Read the base prompt, fixes 1-4 and THIS file. Line numbers
are `ea/fxgrind_replay_core.mqh` and `ea/fxgrind_replay_tests.mq5` at
`7d10bc9`. Questions for Gemini in s5; his rulings and Claude's check in s6.

**The second RT run (rt_7d10bc9, 8 Oct ~18:50Z): 266 run, 261 pass.** H1-H3
work (RT3 `exit px`, RT5b, RT14's abort with `start_ms=1791277201000`
against `retained=1791280800000`, RT33). The five failures (RT3 `scalp
pnl` x2, RT10 `exit shifted` x3) have ONE cause, shown by fix 4's D2:

    RT10-EVENT | CARRY_SNAPSHOT | {... "tick_value":0.00000000, "tick_size":0.00001000, ...}
    RT10-EVENT | CARRY_PASS_SUMMARY | {"eligible":1,"shifted":0,"clamped":0,"skipped":1,...}
    RT10-ORDER | found=true | price=1.10081000

## 0. RESTATE AND STOP

1. `git log --oneline origin/main..HEAD` starts `6a3dfc0`, `7d10bc9`,
   `802b6c3`; otherwise STOP.
2. Restate F1-F2, H4 and T6 in one line each; every changed test with its
   EXACT assertion count; the suite total (run) after commit 1.
3. STOP until "go".

## 1. FINDINGS

| # | Finding | Where | Kind |
|---|---|---|---|
| F1 | In the replay terminal `SYMBOL_TRADE_TICK_VALUE` read 0 for EURUSD while the suite ran (the script starts seconds after the terminal, by `[StartUp]`). The live EA on IC reads 1.0 in every `CARRY_SNAPSHOT` (D's EURUSD archive, 15 of 15, 1-7 Oct). With 0: the carry pass cannot convert the ledger swap (`Grind_CarryLedgerToPips` fails, `ea/grind_carry.mqh` 1117-1120) and skips (RT10); the close-by profit is 0 (core 960-962; RT3 `gross_pnl`); the rollover swap adds 0 (core 855-858). Cause not proven: symbol trade properties not yet synced at start (likely), or an investor-mode quirk. H4 makes the run wait for them and fail loudly if they never come | core; environment | HARNESS (no guard) |
| F2 | RT9 (448) and RT15 (670-671) build their expected swap from the same live tick value, so they PASS with 0 = 0: vacuous. Base RT9 gave the hand value (`-8.111 x 1 x 1.0 x 0.01 = -0.08111`, "with IC's EURUSD tick value 1.0") | tests 432-449, 670-671 | TEST |

## 2. FIXES

| # | Fix |
|---|---|
| H4 | Core: `bool Rpl_WaitSymbolReady(const int timeout_ms)`: `SymbolSelect(_Symbol, true)`; then every 500 ms (`Sleep(500)`) read `SYMBOL_TRADE_TICK_VALUE`, `SYMBOL_TRADE_TICK_SIZE` and `SymbolInfoTick`; when tick value > 0, tick size > 0 and the tick call succeeds, print `RPL|SYMBOL_READY|tick_value=<v>|tick_size=<s>|waited_ms=<ms>` and return true. Every 5 s while waiting print `RPL|SYMBOL_WAIT|tick_value=<v>|tick_size=<s>|tick_ok=<0/1>|waited_ms=<ms>`. At `timeout_ms` print `RPL|ABORT|NO_TICK_VALUE|tick_value=<v>|tick_size=<s>|tick_ok=<0/1>` and return false. Call it with 60000: in `fxgrind_replay.mq5` right after `Rpl_CheckSafetyForRun()` succeeds (false -> return, as the safety abort); in `fxgrind_replay_tests.mq5` `OnStart` right after the `RPL|MIRRORS_EA` line (false -> print `RPL|SUMMARY|run=0|pass=0` and return: no test runs on a symbol without a tick value) |
| T6 | Tests (F2): RT9: after `tick_val` is read (432) add `AssertNear("RT9 tick value 1.0", tick_val, 1.0, 1e-9);` (IC's EURUSD on a USD account, live 15 of 15) and set `expected` (448) to the hand value `-0.08111`. RT15: line 671's expected becomes the hand value `-0.08067` (`-8.067 x 1 x 1.0 x 0.01`); line 670 stays (unused) or is removed if the compiler warns |

## 3. COMMITS

1. **T6** (tests file only, plus the one-line `Rpl_WaitSymbolReady` call in
   its `OnStart` and an empty stub of `Rpl_WaitSymbolReady` in the core
   returning true, so the file compiles). Message: per changed test its
   EXACT assertion count; total run **267** (266 + RT9's tick-value
   assertion). Fails at this commit depend on the terminal's tick value,
   so none are predicted.
2. **H4** (the function body and the runner's call), core and
   `fxgrind_replay.mq5` only. The tests file is NOT touched.

Push after each. Do not compile; the operator compiles both replay files in
`D:\mt5-replay`'s MetaEditor; then you run the suite as before (base s5
steps 0-4, tag `rt_<commit 2 sha7>`) and report every `RPL|` line
(`SYMBOL_WAIT`, `SYMBOL_READY`, any `ABORT`), every `FAIL |` and
`FAIL-DETAIL |` line, and the `RT10-EVENT |` / `RT10-ORDER |` lines,
verbatim. **Predicted after commit 2:** `RPL|SYMBOL_READY|tick_value=1...`,
then **267 run, 267 pass**. If the wait times out instead, that is the
answer to F1 (investor mode): STOP and report.

## 4. NEGATIVE SPACE

As before: no change to any expected value other than T6's three; no
change to the carry path or any engine call; nothing outside H4 / T6.

## 5. FOR GEMINI (attack the premises; say which fact is missing)

- **GH5-1.** F1's cause is inferred, not proven: tick value 0 at a
  scripted start (sync) or in investor mode. H4 waits 60 s and aborts
  loudly either way. Is a wait the right guard, or must the harness take
  the tick value from the archive (the EA reads it live, unseamed, base
  s1 A13, so it cannot be injected without an EA change)?
- **GH5-2.** T6 hard-codes IC's EURUSD tick value 1.0 in RT9 and RT15. Any
  case where the replay terminal's tick value is legitimately not 1.0 for
  EURUSD on this account?
- **GH5-3.** What fact is missing?

## 6. GEMINI'S RULINGS (8 OCT ~19:00Z) AND CLAUDE'S CHECK

- **GH5-1 ACCEPTED** (a wait, not injected data). His aside that the live
  EA "genuinely skips" the carry pass at 0 does not apply: the live EA
  read 1.0 in 15 of 15 snapshots; the 0 is the replay terminal's.
- **GH5-2 ACCEPTED; his condition holds:** the IC client portal shows
  Currency USD for 53077984 (and 53066709, 53071896), so 1.0 is the
  constant.
- **GH5-3 NOTED, no change.** The Strategy Tester is not used (plan K21,
  engine (a) out). The harness's dependence on a live IC connection for
  symbol properties is by design and already ruled (base GH-4): the
  offline engine is the Python port (C118), which takes swap rates and
  tick values from the archive.
- **Correction to his T6 check:** -0.08111 and -0.08067 come from the
  tests' own swap rows (-8.111, -8.067), not from the live
  `SYMBOL_SWAP_LONG`. The values stand.

Line count: 96
