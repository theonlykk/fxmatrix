# DeepSeek R1 Audit Report

## Internal Reasoning

We need answer audit task. We need verify implementation on branch feat/adr153-geometry-independence head c9997b2 matches ADR-153 rev 3 exactly, and none of ten findings survive. We have code and diff, prior audit. Need provide audit report. We must inspect. We have full code of grind_pure.mqh, fxgrind.mq5, grind_engine.mqh at head. Diff shows changes. Need check ADR rev3 requirements.

ADR rev3 decisions:
1. Remove fixed multiple. Keep range guard: width>0, add>0, 0.5 <= add/width <= 4.0.
2. InpStrandedThreshPips free design parameter. No floor, no fatal relationship to width/deadband.
3. OnInit fatal checks are SANITY checks only: reject if width<=0, add<=0, exit<=0, stranded<=0, deadband<0, add/width <0.5 or >4.0. Write as rejection.
4. Recentre respects API budget. GRIND_DAILY_API_ENTRY_STOP checked in five places, not recenter. Add early return when entry stop active. Recommended not required: lower re-quote-specific threshold e.g. 1800 soft-warn. Note: ADR says "returns early when the entry stop is active, exactly like the five paths above." But implementation diff shows:
```
+   if(Grind_ApiCounterSoftWarnActive())
+      return;
```
Wait, ADR says "returns early when the entry stop is active" (GRIND_DAILY_API_ENTRY_STOP, 1900). But code checks `Grind_ApiCounterSoftWarnActive()` which is 1800 soft-warn? Let's inspect. In diff, added:
```
+   if(Grind_ApiCounterSoftWarnActive())
+      return;
```
But ADR Decision 4 says: "Grind_TryRecenterOppositeL0 returns early when the entry stop is active, exactly like the five paths above. Recommended, not required: a lower re-quote-specific threshold (e.g. stop recentring at the 1,800 soft-warn level)". So the required behavior is to return when entry stop (1900) active. The recommended optional is to stop at 1800 soft-warn. The implementation used `Grind_ApiCounterSoftWarnActive()` which is the optional recommended, not the required. Is that acceptable? The ADR says recommended, not required. So using soft-warn is more conservative, but does it match ADR? It doesn't match "returns early when the entry stop is active" exactly. But since recommended, it's arguably okay, but we need check if it breaks any test or requirement. The test `Test_PO4c_RecenterBlockedAtSoftWarn` seeds `GRIND_DAILY_API_SOFT_WARN` and expects no modify. `Test_PO4d_RecenterAllowedBelowSoftWarn` seeds `GRIND_DAILY_API_SOFT_WARN - 1` and expects modify. So implementation follows the recommended soft-warn, not the required entry-stop. But ADR says required is entry stop. If the operator wants exact match, this is a deviation. However, the ADR says "Recommended, not required" for lower threshold, so implementing the lower threshold is allowed. But the required part "returns early when the entry stop is active" is not implemented? Wait, if it returns at soft-warn, it also returns at entry stop because entry stop > soft-warn? Let's check: `Grind_ApiCounterSoftWarnActive()` likely returns true when count >= soft warn (1800). The entry stop is 1900. If count >= 1900, soft-warn is also true, so it returns. So it does return when entry stop active, but also earlier. So the required behavior is satisfied (it returns when entry stop active) plus additional earlier return. That's allowed as recommended. So Decision 4 is met.

Now check other findings:
- Finding 1: inverted fatal check. ADR rev3 removed floor, so no stranded bound fatal. The new sanity checks are only positives and add/width ratio. So finding 1 is resolved? Wait, rev3 says no fatal relationship between stranded and width/deadband. So the previous inverted check is gone. The code's `Grind_ValidateGeometryInputs` checks stranded > 0 only. `Grind_ValidateAddWidthRatio` checks ratio. `Grind_ValidateDeadband` checks >=0. No stranded bound. So finding 1 gone.
- Finding 2: effective recentre threshold. ADR rev3 corrected to `max(D, S-W)` etc. Implementation: `Grind_TryRecenterOppositeL0` uses `Grind_ShouldRecenter(dist_pips, stranded)` where `dist_pips = |resting - mid|`. Deadband check `Grind_PriceWithinDeadband(resting, clamped, deadband)`. So the actual logic is unchanged from before except API gate. The ADR's corrected math is in documentation, but code logic is same. Does the code match the corrected math? The math describes the behavior of the code. The code still uses the same conditions. So the implementation is consistent with the corrected understanding. No code change needed for threshold because ADR only changed docs. So finding 2 resolved in docs, implementation unchanged.
- Finding 3: EURGBP preset contradiction. Rev3 removes floor, so no forced change. "Today's fleet passes every sanity check... No preset change is forced." EURGBP stranded 6 is allowed because no bound. Code: `Grind_ValidateGeometryInputs` only checks stranded >0. So EURGBP passes. Finding 3 resolved.
- Finding 4: floor not enforced. Rev3 removed floor entirely. So gone.
- Finding 5: Recentre test harness uses raw OrderGetDouble. ADR prerequisites said fix it. Diff shows change from `OrderGetDouble` to `Grind_OrderGetPriceOpen`. Implemented. Good.
- Finding 6: checked clear. No assumptions. Code diff doesn't add assumptions. Good.
- Finding 7: add > exit test. ADR testing says test that exit queue ranks correctly or narrow range. Diff shows no test for add > exit? Let's check tests added. `Test_ADR153_OnInitGeometry` checks G1-G5. G2 cycle3 ok: width 5, add 4, exit 10, stranded 10. G5 eurgbp ok: width 3, exit 8, stranded 6, add 6. No test for add > exit. The ADR testing section says: "The range permits add > exit (e.g. width 1, add 4, exit 2), where a new layer's exit target sits BELOW the previous layer's entry. Test that the exit queue ranks and places correctly there, or narrow the range (finding 7)." The implementation did not add such a test. Also no test for add/width ratio boundaries? Actually T17 checks ratio low/high. G1 checks ratio fail 20.05 vs width 5 -> 4.01. G2 checks cycle3. So ratio tests covered. But add > exit test missing. This is a finding that survives? The prior audit finding 7 was turned into a test requirement in ADR. The implementation did not add that test. So audit should flag that finding 7 is not fully resolved in implementation. However, the task says "none of the ten findings ... survive." We need check if finding 7's test requirement is implemented. It is not. So finding 7 survives as a missing test. But is it a code defect? The ADR said "Test that the exit queue ranks and places correctly there, or narrow the range." The code did not narrow the range (still 0.5-4.0) and did not add the test. So the requirement is unmet. We should report.

- Finding 8: `Grind_TestOnInitGeometryCheck` never calls `Grind_ValidateAddWidthRelationship` and takes no deadband. ADR prerequisites said fix. Diff shows it now takes `deadband_pips` and calls `Grind_ValidateAddWidthRatio` and `Grind_ValidateDeadband`. Implemented. Good.
- Finding 9: OnInit error message still names old equality. Diff shows error message updated to new ratio. Implemented.
- Finding 10: arithmetic inconsistency. ADR rev3 corrected. Implemented in docs? The ADR rev3 text we have includes corrected table. So docs fixed.

Also need check if implementation matches ADR exactly. Differences:
- API budget gate: ADR says "returns early when the entry stop is active" and "Recommended, not required: lower re-quote-specific threshold (e.g. stop recentring at 1,800 soft-warn level)". Implementation uses `Grind_ApiCounterSoftWarnActive()`. Let's check if `Grind_ApiCounterSoftWarnActive` is the 1800 soft-warn. In `grind_config.mqh` likely defines `GRIND_DAILY_API_SOFT_WARN` 1800. The test uses `GRIND_DAILY_API_SOFT_WARN` and expects block. So implementation chose the recommended option. That's allowed. But does it satisfy "returns early when the entry stop is active"? Yes, because if entry stop active (count >= 1900), soft warn is also active, so it returns. So required satisfied.

- New `Grind_ValidateDeadband` added and called in OnInit. ADR Decision 3 says deadband < 0 fatal. Implemented.

- Range check: code uses `GRIND_ADD_WIDTH_RATIO_MIN 0.5`, `MAX 4.0`, with epsilon 1e-9. ADR says 0.5 <= add/width <= 4.0. Testing says at 0.49 reject, 0.5 accept, 2.0 accept, 4.0 accept, 4.01 reject. Code: r < MIN - 1e-9 return false; r > MAX + 1e-9 return false. So 0.49 fails, 0.5 passes, 4.0 passes, 4.01 fails. Good.

- Sanity checks: `Grind_ValidateGeometryInputs` checks width>0, exit>0, max_layers>0, stranded>0, add>0. It does not check deadband; that's separate. ADR says deadband <0 fatal. Implemented.

- `Grind_TestOnInitGeometryCheck` now includes deadband and ratio. Good.

- Tests added: T17 updated, Test_ADR153_OnInitGeometry added, PO4b/c/d added. The operator suite says at commit 1 exactly intended 10 tests failed; at head all 10 pass. We can't run, but we can inspect.

Potential issues:
1. `Grind_ValidateDeadband` is in `grind_pure.mqh`, but `Grind_ValidateGeometryInputs` does not check deadband. The ADR says "OnInit returns INIT_FAILED if deadband_pips < 0". That is done in `OnInit` via separate call. Fine.

2. The ADR says "Write every check as a REJECTION". Code does that.

3. Does any code still reference `GRIND_ADD_WIDTH_MULTIPLE`? Diff removed it. Search in provided code: `grind_pure.mqh` no `GRIND_ADD_WIDTH_MULTIPLE`. `fxgrind.mq5` no. Good.

4. Does `Grind_ValidateAddWidthRelationship` still exist? It is renamed to `Grind_ValidateAddWidthRatio`. Diff shows old function removed. But are there any other callers? Tests updated. No other references in provided code. Good.

5. The ADR says "Decision 4 touches the same function as the test-mode fix above, so both land in one change." Diff shows both in same function. Good.

6. Check API counter functions: `Grind_ApiCounterSoftWarnActive()` exists? In diff, added call. We don't have `grind_api_counter.mqh`, but tests use it and operator says pass. Assume exists.

7. Check `Test_PO4b_RecenterSkipsFreshL0`: It sets stranded=10, width=5, mid=1.25000, fresh sell L0 at mid+5 = 1.25050? Wait `Grind_StraddleSellPrice(mid, width_pips, _Point)` with mid=1.25000, width=5 pips. On EURUSD, 1 pip = 0.0001? Actually point=0.00001, pips=10*point=0.0001. So 5 pips = 0.0005. So sell price = 1.25050. Test upserts order at `fresh` = 1.25050. Then calls recenter with current_mid=1.25000. `resting=1.25050`. `dist_pips = |1.25050 - 1.25000| / 0.0001 = 5.0`. `stranded=10`. `Grind_ShouldRecenter(5,10)` false, so no modify. Test expects no modify. Good.

8. `Test_PO4c_RecenterBlockedAtSoftWarn`: seeds API counter to soft warn, expects no modify. Good.

9. `Test_PO4d_RecenterAllowedBelowSoftWarn`: seeds soft warn -1, expects modify. Good.

Potential problem: In `Grind_TryRecenterOppositeL0`, the API gate is `if(Grind_ApiCounterSoftWarnActive()) return;`. But the ADR says "returns early when the entry stop is active". The soft warn is 1800, entry stop 1900. If the counter is at 1850, it returns early, which is more aggressive. That's allowed as recommended. But does it violate any test? The operator says all pass. So fine.

10. Does the code still have any retired `GRIND_ADD_WIDTH_MULTIPLE` in other files? The diff only shows ea/ files. We have full `grind_pure.mqh` and `fxgrind.mq5`. No. `grind_engine.mqh` no. Good.

11. Check `Grind_ValidateGeometryInputs` signature: It still takes `stranded_thresh_pips` and `add_pips`. No deadband. ADR says deadband fatal check separate. Fine.

12. Check `Grind_TestOnInitGeometryCheck` now takes deadband and calls ratio and deadband. Good.

13. Check `Test_T11_PoisonedDefaults`: updated calls with extra 4.0 arg. Good.

14. Check `Test_T17_AddWidthRelationship`: updated to test ratio boundaries. Good.

15. Check `Test_ADR153_OnInitGeometry`: G1 ratio fail: width 5, add 20.05 -> ratio 4.01 >4.0, should fail. G2 cycle3: width 5, add 4, exit 10, stranded 10, deadband 4 -> ratio 0.8, within [0.5,4.0], positives, deadband>=0, magic !=0 -> succeed. G3 stranded eq width: width 5, add 10, exit 10, stranded 5, deadband 6 -> ratio 2.0, stranded 5 >0, deadband 6 >=0 -> succeed. G4 deadband fail: deadband -1 -> fail. G5 eurgbp ok: width 3, add 6, exit 8, stranded 6, deadband 4 -> ratio 2.0, all positive, deadband ok -> succeed. Good.

16. Check G3: stranded=5, width=5, deadband=6. ADR says `stranded = width` starts clean. Here stranded=5, width=5, deadband=6. Code: `Grind_ValidateGeometryInputs` only checks stranded>0. `Grind_ValidateAddWidthRatio` checks add/width = 10/5=2.0. `Grind_ValidateDeadband` 6>=0. So succeeds. Good.

17. Missing test for add > exit. ADR testing says test that. Not present. This is a surviving requirement from finding 7. We should flag.

18. Also, ADR testing says "The range permits add > exit (e.g. width 1, add 4, exit 2), where a new layer's exit target sits BELOW the previous layer's entry. Test that the exit queue ranks and places correctly there, or narrow the range (finding 7)." No such test. Also no code change to restrict add vs exit. So this remains an open risk. The audit should state finding 7 not fully resolved.

19. Check if any other findings survive. Prior audit finding 6: "nothing in grind_recon, grind_exitq, grind_cap or grind_state assumes add == 2 x width". ADR says checked and clear. We don't have those files, but diff doesn't touch them. The task says we have full codebase? Actually we only have provided snippets. The audit should mention cannot independently verify those files. But the ADR claims checked clear. The implementation didn't change them. So likely still clear. But we should note we couldn't inspect.

20. Check if the code matches ADR exactly regarding "InpStrandedThreshPips is a free design parameter. No floor, no fatal relationship to width or deadband." Code: `Grind_ValidateGeometryInputs` checks `stranded_thresh_pips <= 0.0` only. No relation to width or deadband. Good.

21. Check if `Grind_ValidateDeadband` is used in `OnInit`. Yes.

22. Check if `Grind_ValidateAddWidthRatio` uses epsilon correctly. ADR says at 0.49 reject, 0.5 accept, 4.0 accept, 4.01 reject. Code: `if(r < 0.5 - 1e-9) return false; if(r > 4.0 + 1e-9) return false;`. For r=0.5, 0.5 < 0.5 - 1e-9 is false, so accept. For r=4.0, 4.0 > 4.0 + 1e-9 false, accept. For r=4.01, 4.01 > 4.0 + 1e-9 true, reject. Good.

23. Check if `Grind_ValidateGeometryInputs` checks `exit_pips <= 0` return false. Yes.

24. Check if `OnInit` checks all sanity conditions. It calls `Grind_ValidateGeometryInputs` (width, exit, max_layers, stranded, add), then `Grind_ValidateAddWidthRatio`, then `Grind_ValidateDeadband`, then magic. So all ADR checks covered. Good.

25. Check if `Grind_TryRecenterOppositeL0` API gate is before or after other early returns? Diff shows it's after `if(Grind_SideDepth(opposite_side) != 0) return;` and before `if(opposite_side.l0_pending_ticket == 0) return;`. That's fine.

26. Check if `Grind_TryRecenterOppositeL0` uses `Grind_OrderGetPriceOpen`. Yes.

27. Check if `Test_PO4b_RecenterSkipsFreshL0` uses `Grind_OrderGetPriceOpen` indirectly. It upserts order at `fresh` price. The function now uses `Grind_OrderGetPriceOpen`, which in test mode reads the test record. So test works.

28. Check if `Test_PO4d` expects modify once. It seeds API counter below soft warn. `Grind_TryRecenterOppositeL0` will not early return. It computes `resting` from test record (1.26050). `mid=1.25000`. `dist_pips = |1.26050 - 1.25000| / 0.0001 = 105`. `stranded=10`. Gate open. Target = sell straddle at mid+5 pips = 1.25050. Deadband 4: |1.25050 - 1.26050| = 0.0010 = 10 pips >=4, so modify. It calls `Grind_ModifyPendingPrice` which increments modify calls. Test expects 1. Good.

29. Check if any of the ten findings are still present in code:
- Finding 1 (inverted fatal check): Rev3 removed that check entirely. Not present.
- Finding 2 (threshold derivation): Rev3 corrected in docs. Code logic unchanged, but now documented correctly. The implementation doesn't need code change. However, does the code's `Grind_ShouldRecenter` and deadband logic match the corrected math? Yes, the math describes the code. So no code defect.
- Finding 3 (EURGBP preset contradiction): Rev3 removes floor, so no contradiction. Code allows stranded 6.
- Finding 4 (floor not enforced): Rev3 removed floor.
- Finding 5 (test harness raw OrderGetDouble): Fixed.
- Finding 6 (assumptions in other files): Claimed clear, not changed.
- Finding 7 (add > exit test): Not implemented. This is a surviving requirement.
- Finding 8 (test stub): Fixed.
- Finding 9 (error message): Fixed.
- Finding 10 (arithmetic inconsistency): Fixed in docs.

So only finding 7 (test requirement) is not implemented. Also, we should check if the ADR's test plan includes all items:
- add/width ratio at 0.49, 0.5, 2.0, 4.0, 4.01: T17 covers 4.9/10? T17a: ratio low 10.0, 4.9 -> 0.49 reject. T17b: ratio min 10.0, 5.0 -> 0.5 accept. T17c: ratio mid 5.0, 10.0 -> 2.0 accept. T17d: ratio max 5.0, 20.0 -> 4.0 accept. T17e: ratio high 5.0, 20.05 -> 4.01 reject. Good.
- Each sanity check: zero/negative width, add, exit, stranded (reject); negative deadband (reject); deadband 0 (accept). T11 checks width/exit. G4 checks deadband negative. G3 checks stranded=width (positive). But do they test zero/negative add, exit, stranded? G1 tests ratio fail, not zero. T11 tests width negative, exit negative. T17h tests deadband negative. T17g tests deadband zero. There is no explicit test for add <=0, exit <=0, stranded <=0. `Grind_ValidateGeometryInputs` checks add<=0, exit<=0, stranded<=0. But tests? T12 maybe? Let's check diff: T12 UnconfiguredAddPips? Not shown in diff. The ADR testing says "Each sanity check: zero or negative width, add, exit, stranded (reject); negative deadband (reject); deadband 0 (accept)." The implementation's tests: T11 checks width negative, exit negative. T17 checks deadband. G4 checks deadband negative. G3 checks stranded=width (not negative). No test for add<=0, exit<=0, stranded<=0. However, the operator suite says "at commit 1 exactly the intended 10 tests failed; at head all 10 pass." The 10 tests likely include the new ones. But we need verify if all ADR tests are present. The diff shows added tests: Test_ADR153_OnInitGeometry (5 asserts), Test_PO4b, PO4c, PO4d, plus T17 updates. That's not 10 tests? Let's count: T17 has 9 asserts but it's one test function. Test_ADR153 has 5 asserts. PO4b, PO4c, PO4d = 3 tests. That's 1+1+3=5 new test functions? Actually T17 was modified, not new. The operator says "exactly the intended 10 tests failed" at commit 1. Maybe there were 10 test functions that failed before implementation. The diff shows tests added. We don't have the full test file. But we can infer that the ADR test plan might not be fully covered. Specifically, no test for add > exit. The ADR explicitly says "Test that the exit queue ranks and places correctly there, or narrow the range (finding 7)." This is a test requirement, not just a code change. Since no such test exists in diff, finding 7 survives as an untested requirement. Also, no test for zero/negative add/exit/stranded. But maybe they are in existing tests not shown? The diff only shows changes. Existing tests might already cover some. For example, T12 UnconfiguredAddPips might test add=-1. Let's check diff context: T12 is mentioned but not changed. It might already test add <=0. But the ADR testing plan says "Tests first, and they must fail before the change". If existing tests already covered, they wouldn't fail. The operator says at commit 1 exactly 10 tests failed. So the 10 tests were likely newly added or modified to test the new behavior. The diff shows only some. We can't be sure. But the missing add > exit test is explicitly called out in ADR as a test requirement. The diff does not show it. So we should flag that.

Also, the ADR says "The ADR-124 recentre is unchanged when stranded = 2 x width: same modify count as today on a fixture where mid drifts. Requires the test-mode fix in Prerequisites first." Is there a test for that? `Test_PO4_RecenterOppositeL0StillWorks` exists (mentioned in diff context). That might be the test. It likely checks modify count. The diff doesn't modify it, but the prerequisite fix (OrderGetPriceOpen) would make it pass. So that's covered.

Let's check if `Grind_TryRecenterOppositeL0` still has the API gate after `Grind_SideDepth` check. The ADR says "returns early when the entry stop is active, exactly like the five paths above." The five paths check `if(Grind_ApiCounterEntryStopped()) return;` or similar. The recenter now checks `Grind_ApiCounterSoftWarnActive()`. Is that exactly like? The five paths check entry stop (1900). The recenter checks soft warn (1800). That's not "exactly like". But as noted, it's allowed by the recommended option. However, the ADR text says "returns early when the entry stop is active" which is a requirement. The implementation returns early at soft warn, which includes entry stop. So it satisfies the requirement (it returns when entry stop active) but also earlier. So it's fine.

One more thing: The ADR says "Decision 4 touches the same function as the test-mode fix above, so both land in one change." The diff shows both changes in `Grind_TryRecenterOppositeL0`. Good.

Now, check if any silent failures or schema mismatches introduced. The new `Grind_ValidateAddWidthRatio` uses epsilon. The old `Grind_ValidateAddWidthRelationship` was removed. Are there any other callers? Diff shows `fxgrind.mq5` updated. Tests updated. No other. Good.

Check if `Grind_ValidateDeadband` is declared before use in `fxgrind.mq5`. `grind_pure.mqh` included via `grind_engine.mqh`? `fxgrind.mq5` includes `grind_engine.mqh` which includes `grind_pure.mqh`. So yes.

Check if `GRIND_ADD_WIDTH_RATIO_MIN` and MAX are defined in `grind_pure.mqh`. Yes.

Check if `GRIND_DAILY_API_SOFT_WARN` is available in tests. They use it. Probably defined in `grind_config.mqh` included by engine. Good.

Now, let's consider the prior audit finding 7: "The range permits add > exit ... Test that the exit queue ranks and places correctly there, or narrow the range." The implementation did not narrow the range. It also did not add a test. So this is an open risk. Is there any code change that prevents add > exit? No. The range check only constrains add/width. So add > exit is still allowed. The exit queue may break. The ADR says "Test that ... or narrow the range". The implementation did neither. So finding 7 survives.

Also, prior audit finding 2: the effective threshold. The ADR rev3 corrected the math in the documentation. But does the code's behavior match the corrected math? Yes, the code logic is unchanged. So no code defect. However, the ADR's "Evidence" section now has a table with correct thresholds. So the documentation is fixed. So finding 2 resolved.

Prior audit finding 3: "Nothing changes for today's fleet" was false. Rev3 removes floor, so no preset change. The ADR now says "Today's fleet passes every sanity check... No preset change is forced." This is true because the sanity checks don't constrain stranded vs width. EURGBP stranded 6 passes because stranded>0. So finding 3 resolved.

Prior audit finding 4: floor not enforced. Floor removed.

Prior audit finding 5: test harness. Fixed.

Prior audit finding 6: assumptions in other files. ADR says checked clear. We can't verify but no changes.

Prior audit finding 8: test stub. Fixed.

Prior audit finding 9: error message. Fixed.

Prior audit finding 10: arithmetic inconsistency. Fixed in docs.

So the only surviving finding is 7's test requirement.

But wait, the audit task says "none of the ten findings ... survive." So we must check if finding 7 is truly not implemented. Could the existing `Grind_ExitQ` tests cover add > exit? The diff doesn't show new test. But maybe `Test_T19c_AppendUpToMaxLayersParallel` or others cover exit queue with various geometries. However, the ADR specifically says "Test that the exit queue ranks and places correctly there, or narrow the range (finding 7)." Since the range is not narrowed, a test is required. If no test was added, the finding survives as an untested requirement. We should state that the implementation does not satisfy this test requirement. The operator's suite results mention "at commit 1 exactly the intended 10 tests failed; at head all 10 pass." The 10 tests might not include the add > exit test. If the ADR required a test that was not written, then the 10 tests could all pass without it. So finding 7 is not addressed.

Also, check if any other ADR requirements are missing:
- ADR says "The `OnInit` error message still names the old equality and is rewritten with it (finding 9)." Diff shows rewritten.
- ADR says "The `OnInit` fatal checks are SANITY checks only... Write every check as a REJECTION". Code does.
- ADR says "Decision 4 ... returns early when the entry stop is active". Code does via soft warn.
- ADR says "Recommended, not required: a lower re-quote-specific threshold (e.g. stop recentring at the 1,800 soft-warn level)". Code uses soft warn. That's the recommended, so allowed.

Now, let's check if the code has any new issues:
- `Grind_ValidateAddWidthRatio` uses `r < MIN - 1e-9` and `r > MAX + 1e-9`. This is fine.
- `Grind_ValidateDeadband` returns `deadband_pips >= 0.0`. Fine.
- `Grind_TestOnInitGeometryCheck` now takes `deadband_pips`. All callers updated? Diff shows T11 updated. Are there other callers? Search in provided code: only T11 and Test_ADR153. Good.
- `Grind_ValidateAddWidthRelationship` removed. Any other references? Search in provided code: none. Good.

Potential subtle bug: In `Grind_TryRecenterOppositeL0`, the API gate is `if(Grind_ApiCounterSoftWarnActive()) return;`. But the ADR says "returns early when the entry stop is active". The soft warn is 1800, entry stop 1900. If the counter is at 1850, it returns early. But the five paths check `Grind_ApiCounterEntryStopped()` which likely returns true at 1900. So the recenter now stops at 1800, while entries continue until 1900. That means recenter stops before entries, which is the intent (re-quotes yield to entries). So it's correct.

Now, check if the tests for API stop are correct. `Test_PO4c_RecenterBlockedAtSoftWarn` seeds `GRIND_DAILY_API_SOFT_WARN`. `Grind_ApiCounterSoftWarnActive()` should return true. Then recenter returns early, no modify. Test expects 0. Good. `Test_PO4d_RecenterAllowedBelowSoftWarn` seeds `GRIND_DAILY_API_SOFT_WARN - 1`. Soft warn false. Recenter proceeds. Test expects 1 modify. Good.

One issue: `Test_PO4b_RecenterSkipsFreshL0` does not seed API counter, so soft warn false. It tests fresh L0 no modify. Good.

Now, let's consider if the implementation of `Grind_ValidateAddWidthRatio` correctly handles the case where width is negative. It checks `width_pips <= 0.0 || add_pips <= 0.0` return false. So negative width fails. Good.

Now, final audit report structure:
- Summary: Implementation largely matches ADR-153 rev3. All ten prior findings are addressed except finding 7's test requirement (add > exit) which remains unimplemented. Also note that finding 6's verification in other files could not be independently confirmed from provided snippets.
- Detailed verification of each finding 1-10.
- Check of ADR decisions.
- Check of tests.
- Recommendations: add the missing add > exit test or narrow range; verify other files; consider whether soft-warn gate is acceptable (it is, as recommended).

We should also mention that the code's behavior for recenter threshold matches the corrected math in ADR rev3, so finding 2 is resolved.

Let's write the final answer.

We need be exhaustive. Include specific file/line references where possible.

Let's produce a structured report.

**Audit Report: ADR-153 rev3 implementation at c9997b2**

**Verdict:** Implementation matches ADR rev3 except for one outstanding test requirement from finding 7. No surviving code defects from findings 1-6, 8-10. Finding 7 (add > exit geometry) is not tested and the range is not narrowed.

**Detailed findings:**

1. **Finding 1 (inverted fatal check): resolved.** The fatal check on `stranded > width+deadband` is removed entirely. Rev3 made stranded a free parameter. `Grind_ValidateGeometryInputs` only checks `stranded_thresh_pips > 0.0`. No width/deadband relationship is enforced.

2. **Finding 2 (effective threshold): resolved in documentation, code unchanged.** The ADR rev3 now correctly documents direction-dependent thresholds `max(D, S-W)` and `S+W`. The code's `Grind_TryRecenterOppositeL0` uses the same gate and deadband logic, so its behavior is consistent with the corrected math. No code change needed.

3. **Finding 3 (EURGBP preset): resolved.** Rev3 removes the floor. `Grind_ValidateGeometryInputs` accepts `stranded=6` with `width=3, deadband=4`. The ADR now says "No preset change is forced." Test G5 confirms EURGBP geometry starts clean.

4. **Finding 4 (floor not enforced): resolved.** Floor removed.

5. **Finding 5 (test harness raw OrderGetDouble): resolved.** `Grind_TryRecenterOppositeL0` now uses `Grind_OrderGetPriceOpen` (diff line). This is the prerequisite fix.

6. **Finding 6 (other files assume add==2*width): claimed clear, not independently verified.** The ADR states `grind_recon`, `grind_exitq`, `grind_cap`, `grind_state` are clear. The provided diff does not touch them. We cannot confirm from the provided snippets, but no evidence of violation.

7. **Finding 7 (add > exit test): NOT RESOLVED.** The ADR testing section requires: "The range permits `add > exit` (e.g. width 1, add 4, exit 2), where a new layer's exit target sits BELOW the previous layer's entry. Test that the exit queue ranks and places correctly there, or narrow the range (finding 7)." The implementation neither narrows the range (still 0.5–4.0) nor adds such a test. The new tests `Test_ADR153_OnInitGeometry` and `Test_PO4b/c/d` do not cover `add > exit`. This is an open risk for exit queue rank inversions.

8. **Finding 8 (test stub): resolved.** `Grind_TestOnInitGeometryCheck` now takes `deadband_pips` and calls `Grind_ValidateAddWidthRatio` and `Grind_ValidateDeadband`. Diff shows the change.

9. **Finding 9 (error message): resolved.** `fxgrind.mq5` error message now reports ratio outside `[0.5, 4.0]` instead of old equality.

10. **Finding 10 (arithmetic inconsistency): resolved.** ADR rev3 table corrects the threshold values (e.g., EURGBP 4.0, others 5.0). Documentation fixed.

**ADR decision compliance:**

- **Decision 1 (range guard):** Implemented. `GRIND_ADD_WIDTH_RATIO_MIN 0.5`, `GRIND_ADD_WIDTH_RATIO_MAX 4.0`. `Grind_ValidateAddWidthRatio` checks with 1e-9 epsilon. Tests T17a-e cover boundaries.
- **Decision 2 (free stranded):** Implemented. No floor, no fatal width/deadband relation.
- **Decision 3 (sanity checks):** Implemented. `OnInit` checks width>0, exit>0, max_layers>0, stranded>0, add>0 via `Grind_ValidateGeometryInputs`; ratio via `Grind_ValidateAddWidthRatio`; deadband>=0 via `Grind_ValidateDeadband`. All are rejection checks.
- **Decision 4 (API budget):** Implemented with recommended soft-warn gate. `Grind_TryRecenterOppositeL0` now returns early if `Grind_ApiCounterSoftWarnActive()`. This satisfies the required entry-stop return (since soft warn is a lower threshold) and implements the recommended option. Tests PO4c/d cover.

**Test coverage check:**

- Ratio boundaries: T17a-e.
- Sanity checks: T11 (width, exit), G4 (deadband negative), T17g/h (deadband zero/negative). But note: no explicit test for zero/negative `add`, `exit`, `stranded`? T11 tests width and exit. T12 likely tests add? Not shown. G3 tests stranded=width (positive). The ADR test plan says "zero or negative width, add, exit, stranded (reject)". The implementation may lack explicit tests for negative add/exit/stranded. However, the operator says exactly 10 intended tests failed and pass, so likely covered elsewhere. We can't confirm from diff.
- `stranded = width` starts clean: G3.
- Recentre + API stop: PO4c/d.
- Cycle-3 geometry: G2.
- Add > exit: NOT covered.
- Every current preset: not directly tested, but G5 covers EURGBP.
- ADR-124 recentre unchanged: PO4 exists (not modified) and now uses fixed `Grind_OrderGetPriceOpen`.

**Recommendations:**

1. Add the missing `add > exit` test or narrow the range guard to prevent `add > exit` (e.g., add a sanity check `add <= exit` or test the exit queue with that geometry).
2. Independently verify `grind_recon`, `grind_exitq`, `grind_cap`, `grind_state` for any latent `add == 2*width` assumptions, as the ADR claims clear but the audit packet did not include those files.
3. Consider documenting that the recentre now uses the soft-warn threshold (1800) rather than the entry-stop (1900), as this is an intentional deviation from the literal Decision 4 wording (though permitted by the "recommended" clause).

**Conclusion:** The implementation is faithful to ADR-153 rev3 and resolves nine of the ten prior findings. Finding 7's test requirement is unmet. The branch head c9997b2 is not fully complete until that test is added or the range narrowed.

Let's write this up.

## Final Report

## Audit Report: ADR-153 rev3 implementation at `c9997b2`

**Verdict:** The branch **largely matches ADR-153 rev3**. Nine of the ten prior DeepSeek findings are resolved. **Finding 7 survives**: the ADR’s testing requirement for `add > exit` geometry was neither implemented as a test nor avoided by narrowing the range guard. The recentre API gate uses the recommended soft-warn threshold (1,800) rather than the literal entry-stop (1,900), which is permitted by the ADR’s “Recommended, not required” clause, but it is a deviation from the exact wording of Decision 4.

---

## 1. Mapping of the ten prior findings to the implementation

| Finding | Status at `c9997b2` | Evidence |
|---|---|---|
| **1. Inverted fatal check** | **Resolved** | Rev3 removed the stranded floor and the `stranded > width+deadband` check entirely. `Grind_ValidateGeometryInputs` only checks `stranded_thresh_pips > 0.0`. No width/deadband relationship is fatal. |
| **2. Wrong effective threshold** | **Resolved in docs; code unchanged** | ADR rev3 now correctly documents direction-dependent thresholds `max(D, S−W)` and `S+W`. `Grind_TryRecenterOppositeL0` uses the same gate/deadband logic as before, so its behaviour is consistent with the corrected math. |
| **3. EURGBP preset contradiction** | **Resolved** | Rev3 removes the floor. `Grind_ValidateGeometryInputs` accepts `width=3, stranded=6, deadband=4`. ADR now says “No preset change is forced.” Test `G5` confirms EURGBP geometry starts clean. |
| **4. Floor not enforced** | **Resolved** | Floor removed entirely. No code enforces `stranded >= max(2*width, width+deadband+1)`. |
| **5. Recentre test harness raw `OrderGetDouble`** | **Resolved** | Diff changes `Grind_TryRecenterOppositeL0` to use `Grind_OrderGetPriceOpen(opposite_side.l0_pending_ticket)`. This is the prerequisite fix. |
| **6. Other files assume `add == 2*width`** | **Claimed clear; not independently verified** | ADR states `grind_recon`, `grind_exitq`, `grind_cap`, `grind_state` are clear. The provided diff does not touch them. The audit packet did not include those files, so this remains an unverified claim. |
| **7. `add > exit` test requirement** | **NOT RESOLVED** | ADR testing says: “The range permits `add > exit` … Test that the exit queue ranks and places correctly there, or narrow the range (finding 7).” The implementation **neither narrows the range** (still `0.5 ≤ add/width ≤ 4.0`) **nor adds such a test**. No new test covers `add > exit`. |
| **8. Test stub missing checks** | **Resolved** | `Grind_TestOnInitGeometryCheck` now takes `deadband_pips` and calls `Grind_ValidateAddWidthRatio` and `Grind_ValidateDeadband`. Diff confirms. |
| **9. Stale error message** | **Resolved** | `fxgrind.mq5` error now prints the ratio and `[0.5, 4.0]` band, not the old equality. |
| **10. Arithmetic inconsistency** | **Resolved in docs** | ADR rev3 table corrects values (EURGBP 4.0, others 5.0, etc.). Documentation fixed. |

---

## 2. ADR Decision compliance

### Decision 1 — Range guard
Implemented exactly:
- `GRIND_ADD_WIDTH_RATIO_MIN 0.5`, `GRIND_ADD_WIDTH_RATIO_MAX 4.0` in `grind_pure.mqh`.
- `Grind_ValidateAddWidthRatio` checks `r < 0.5 − 1e-9` and `r > 4.0 + 1e-9`.
- Tests `T17a–e` cover 0.49 reject, 0.5 accept, 2.0 accept, 4.0 accept, 4.01 reject.

### Decision 2 — Free `InpStrandedThreshPips`
Implemented. No floor, no fatal relationship to width or deadband. `Grind_ValidateGeometryInputs` only requires `stranded_thresh_pips > 0.0`.

### Decision 3 — Sanity checks only
`OnInit` now checks:
- `Grind_ValidateGeometryInputs`: `width > 0`, `exit > 0`, `max_layers > 0`, `stranded > 0`, `add > 0`.
- `Grind_ValidateAddWidthRatio`: ratio in `[0.5, 4.0]`.
- `Grind_ValidateDeadband`: `deadband >= 0`.
All are written as rejections. The old `Grind_ValidateAddWidthRelationship` is removed.

### Decision 4 — Recentre API budget
`Grind_TryRecenterOppositeL0` now returns early if `Grind_ApiCounterSoftWarnActive()`. This satisfies the required “returns when entry stop is active” because the soft-warn threshold (1,800) is lower than the entry stop (1,900). It also implements the ADR’s **recommended** option to stop recentring at the soft-warn level. Tests `PO4c` (blocked at soft-warn) and `PO4d` (allowed below soft-warn) confirm.

---

## 3. Testing gaps

The following ADR testing items are **not fully covered** by the diff:

1. **`add > exit` geometry** — explicitly required by ADR testing and prior finding 7. No test exists. The range still permits `add > exit` (e.g. `width=1, add=4, exit=2`). This can place a new layer’s exit target below the previous layer’s entry, potentially breaking exit-queue rank ordering. **This is the one surviving finding.**
2. **Zero/negative `add`, `exit`, `stranded`** — ADR testing says they must be rejected. The diff shows `T11` covers negative width and exit, and `T17g/h` cover deadband. No new test explicitly covers `add <= 0`, `exit <= 0`, or `stranded <= 0`. They may be covered by existing tests (e.g. `T12`), but the diff does not show it.
3. **Every current preset passes** — not directly tested; `G5` covers EURGBP only.

---

## 4. Recommendations

1. **Add the missing `add > exit` test** or **narrow the range guard** to forbid `add > exit`. Until then, finding 7 remains open.
2. **Independently verify** `grind_recon.mqh`, `grind_exitq.mqh`, `grind_cap.mqh`, `grind_state.mqh` for latent `add == 2*width` assumptions. The ADR claims clear, but the audit packet did not include those files.
3. **Document the soft-warn choice** in the ADR or code comment, since Decision 4 literally says “returns early when the entry stop is active” while the implementation stops earlier at the recommended soft-warn threshold.

---

## 5. Conclusion

At `c9997b2`, the implementation is faithful to ADR-153 rev3 and resolves findings **1, 2, 3, 4, 5, 8, 9, 10**. Finding **6** is claimed clear but unverified in the provided packet. Finding **7** is **not resolved**: the `add > exit` test requirement is unmet and the range is not narrowed. The branch is not fully complete until that test is added or the range is constrained.

<!-- finish_reason=stop -->
