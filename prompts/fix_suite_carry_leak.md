This message has a line count at the bottom

# FIX THE SUITE: CARRY STATE LEAKS BETWEEN TESTS (backlog C12)

## AUDIT TRAIL

| item | detail | status |
|---|---|---|
| Symptom | IV5 pass, IV5 detail cleared, EF3 fourteen adverse fail -- fail on `main` (1377/1380) and every branch; green at `605bc85` in an earlier week | operator-run, 2026-09-20 |
| Cause | traced in source by Claude, see CONTEXT | not yet confirmed by a run |
| Baseline | fxmatrix `origin/main` at `c4b8ffb` | read by Claude |
| Scope | **test code only**: `ea/fxgrind_tests.mq5`. No `ea/grind_*.mqh`, no `fxgrind.mq5` | this spec |

## BRANCH

`fix/suite-carry-leak` from `origin/main`. Three commits. Push. Do NOT
merge. Do NOT open a PR.

1. **Tests and a stub.** New tests fail at this commit.
2. **The fix.** No test edited.
3. **Response document.**

## CONTEXT -- VERIFIED IN SOURCE AT c4b8ffb

- I6's expected exit includes a stored shift read by
  `Grind_CarryShiftGetForRecon(position)` (`grind_carry.mqh:589`), which
  calls `Grind_CarryShiftGetValidated`. **When `GRIND_CARRY_RELEASE_<pos>`
  exists, the stored shift is returned with no bound check**
  (`grind_carry.mqh:564-566`).
- `Grind_ExitQManageSide` (`grind_engine.mqh:~1847`): when an exit is
  CLAMPED it writes `GRIND_CARRY_SHIFT_<pos>` AND sets
  `GRIND_CARRY_RELEASE_<pos>` to 1.0.
- Whether it clamps depends on `Grind_MarketBid()` / `Grind_MarketAsk()`
  (`grind_engine.mqh:69-80`), which return the LIVE quote of the chart the
  tests run on unless `Grind_MarketTestSeed` was called.
- **Twelve tests reach exit placement on the position-1001 fixture WITHOUT
  seeding the market**, all running before IV5: T45, T46, T46b, T46c,
  T57b, S1, S1b, S3, S4, S5, S6, Q10. Depending on the live price, one
  clamps and leaves SHIFT_1001 + RELEASE_1001 behind.
- **`Grind_TestResetSideState()`** (`fxgrind_tests.mq5:2437`), the shared
  fixture reset called 255 times across the three test files, clears
  layers, tickets and counters but NOT carry state.
- **IV5 (`Test_IV5_InvariantDetailClearsOnPass`) and EF3
  (`Test_EF3_I6ShortFillMirror`) build scratch layers on position 1001 and
  never call the reset**, so they inherit the leak.
- Nine tests SET carry state and later call the reset
  (`Test_F1_4_...`, `Test_CV3_...`, `Test_CARRY_PROBE_...`,
  `Test_STALE3_...`, `Test_STALE5_...`, `Test_F2_2_...`, `Test_F2_3_...`,
  `Test_F2_6_...`, `Test_F2_7_...`, all in `fxgrind_tests_adr151.mqh`).
  Claude checked: in every one the later reset is END-OF-TEST cleanup with
  ZERO assertions after it. So clearing carry in the reset is safe.
- GV names: `"GRIND_CARRY_SHIFT_" + ticket`, `"GRIND_CARRY_ACCRUED_" +
  ticket`, `GRIND_CARRY_RELEASE_PREFIX` (`grind_config.mqh:17`,
  `"GRIND_CARRY_RELEASE_"`) + ticket.

## DESIGN

### D1. The helper -- `ea/fxgrind_tests.mq5`

    void Grind_TestClearCarryState()
    {
       GlobalVariablesDeleteAll("GRIND_CARRY_SHIFT_");
       GlobalVariablesDeleteAll("GRIND_CARRY_ACCRUED_");
       GlobalVariablesDeleteAll(GRIND_CARRY_RELEASE_PREFIX);
    }

Place it immediately ABOVE `Grind_TestResetSideState`. Commit 1 adds it
as a stub with an EMPTY body; commit 2 fills the body.

**Only these three prefixes.** Do NOT delete `GRIND_CARRY_DAY_`, the API
counter, slot/magic locks, or any other `GRIND_` variable.

### D2. Wire it in (COMMIT 2)

- First statement of `Grind_TestResetSideState()`:
  `Grind_TestClearCarryState();`
- That is the only change in commit 2 apart from filling the helper body.

### D3. Tests (COMMIT 1)

**Make IV5 and EF3 hermetic.** Add `Grind_TestClearCarryState();` as the
FIRST statement of `Test_IV5_InvariantDetailClearsOnPass` and of
`Test_EF3_I6ShortFillMirror`. Change nothing else in either.

**Add `Test_RESET1_SideResetClearsCarryState`:**

1. `GlobalVariableSet` all three kinds for ticket 1001 (SHIFT 0.00050,
   ACCRUED 0.00020, RELEASE 1.0) and for ticket 7777 (same values). 7777
   is in no layer: it proves orphaned state is cleared too.

   **Build every name with the EA's own functions**, never by string
   concatenation: `Grind_CarryShiftGvName(1001UL)`,
   `Grind_CarryAccruedGvName(1001UL)`, `Grind_CarryReleaseGvNameLocal(1001UL)`
   (`grind_carry.mqh:479`, `:513`, `:500`), and the same for `7777UL`. The
   tests then use exactly the names the code writes.
2. Call `Grind_TestResetSideState();`
3. `AssertFalse` for each of the six: `GlobalVariableCheck(...)`, with
   names `RESET1 shift 1001`, `RESET1 accrued 1001`, `RESET1 release
   1001`, and the same for 7777.

**Add `Test_RESET2_PoisonedShiftIsCleared`:**

1. Set SHIFT_1001 to 0.00050 and RELEASE_1001 to 1.0, names built as in
   RESET1.
2. Call `Grind_TestClearCarryState();`
3. `AssertTrue("RESET2 recon shift zero", Grind_CarryShiftGetForRecon(1001UL) == 0.0);`

Call both at the END of the test runner, after every existing test.

**Required failure pattern at commit 1:** all six RESET1 assertions and
RESET2 FAIL (stub does nothing). IV5 and EF3 may still fail at commit 1 --
the stub clears nothing -- which is expected. **If RESET1 or RESET2
passes at commit 1, STOP**: the test is not exercising the reset.

**At commit 2:** everything passes, including IV5 x2 and EF3. Expected
total: 1380 + 7 = **1387/1387**.

## NEGATIVE SPACE

- Test code ONLY. Do NOT touch any `ea/grind_*.mqh` or `ea/fxgrind.mq5`.
- Do NOT seed the market in the twelve unseeded tests. That is a separate
  item; this change removes the leak's EFFECT, not its source.
- Do NOT change any assertion in any existing test.
- `GlobalVariablesDeleteAll` appears ONLY inside
  `Grind_TestClearCarryState`, with ONLY the three prefixes above.
- Do NOT edit tests in commit 2.
- Do NOT CLI compile, launch MetaTrader or deploy.
- Stage by exact path. No merge, no PR, no stash. ASCII only.

## FAILURE MODES -- STOP AND REPORT

- `GRIND_CARRY_RELEASE_PREFIX` or `Grind_CarryShiftGetForRecon` is not
  visible from `fxgrind_tests.mq5`: STOP, report the include chain.
- Any test OTHER than IV5 and EF3 needs editing: STOP.
- Any of the nine carry-setting tests listed in CONTEXT turns out to
  assert after its final `Grind_TestResetSideState()`: STOP and name it.

## SELF-REVIEW

Grep the final tree: `GlobalVariablesDeleteAll` appears in exactly one
function, `Grind_TestClearCarryState`, and nowhere under `ea/grind_*`.

## RESPONSE FORMAT

`prompts/fix_suite_carry_leak_response.md`: the three hashes AS THEY EXIST
ON ORIGIN (verify after any amend), the diff stat, the self-review grep
output, and the true line count of the file in its footer. Open with
`This message has a line count at the bottom`.

Reply in chat with ONLY: the branch name, the three hashes on origin, and
one line saying the report is pushed.

## AFTER CURSOR (operator)

1. Commit 1: sync, compile, run. RESET1 (6) and RESET2 (1) fail.
2. Head: sync, compile, run. **1387/1387.**
3. **Run the head a second time on a DIFFERENT chart symbol** (e.g. once
   on EURUSD, once on GBPUSD). Both must be 1387/1387. That is what proves
   the suite no longer depends on the live price.
4. Always check the TOTAL, and that the terminal copy has the new test
   name before compiling.

Line count: 163
