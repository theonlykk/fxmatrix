This message has a line count at the bottom

# fix/suite-carry-leak -- response

Spec read at commit `b251576` (`prompts/fix_suite_carry_leak.md`, footer `Line count: 163` verified).

## Commits on origin

| # | role | hash |
|---|---|---|
| 1 | tests + stub | `7b72ab0` |
| 2 | fix | `4a2bd71` |
| 3 | this file | `e9cbf5e` |

## git diff --stat origin/main...fix/suite-carry-leak

```
 ea/fxgrind_tests.mq5                     | 37 +++++++++++++++++++++++++++
 prompts/fix_suite_carry_leak_response.md | 43 ++++++++++++++++++++++++++++++++
 2 files changed, 80 insertions(+)
```

## Self-review grep

```
 git grep GlobalVariablesDeleteAll ea/
 ea/fxgrind_tests.mq5:2439:   GlobalVariablesDeleteAll("GRIND_CARRY_SHIFT_");
 ea/fxgrind_tests.mq5:2440:   GlobalVariablesDeleteAll("GRIND_CARRY_ACCRUED_");
 ea/fxgrind_tests.mq5:2441:   GlobalVariablesDeleteAll(GRIND_CARRY_RELEASE_PREFIX);

 git grep GlobalVariablesDeleteAll ea/grind_
 (no matches)
```

All three calls appear only inside `Grind_TestClearCarryState` in `fxgrind_tests.mq5`.

## Expected failures at commit 1 (`7b72ab0`)

- `Test_RESET1_SideResetClearsCarryState`: all six assertions (stub clears nothing)
- `Test_RESET2_PoisonedShiftIsCleared`: recon shift still poisoned

IV5 and EF3 may still fail (environment leak); not required to fail at commit 1.

Line count: 44
