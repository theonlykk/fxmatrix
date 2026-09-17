This message has a line count at the bottom

# CURSOR PROMPT -- ADR-151 PHASE A FIX 1: TEST ISOLATION, SEAMS, TWO WRONG TESTS

## AUDIT TRAIL
| Item | Value |
|---|---|
| Repo | theonlykk/fxmatrix, `D:\fxmatrix` |
| Branch | `feat/adr151-exit-queue`, currently at `7ed2a7a` (commits 51d9be7, 568ac58, 7ed2a7a) |
| Parent spec | `prompts/cursor_adr151_phaseA.md` rev 2 (315 lines) -- still binding |
| Operator suite, desktop, `main` 6cc2899 | SUMMARY 1038/1038 |
| Operator suite, desktop, `568ac58` | SUMMARY 1113/1134, 21 FAIL (listed below) |
| Operator compile, `51d9be7` | FAILED: `function 'Grind_ReconCheckInvariants' must have a body` (fxgrind_tests_adr151.mqh:17). Recorded; NOT fixed here |
| Diagnosis | Claude, read against committed source at 568ac58. Every failure below has a stated cause |
| Expected after this fix | SUMMARY 1136/1136, zero FAIL |

## THE 21 FAILURES AND THEIR CAUSES (verified)
| Assertions | Cause | Fixed by |
|---|---|---|
| A8 tick2 place, A8 label L01, A8 price, SB2 r, SB2 place once, SB2 new ticket, PO3 place once, PO3 ticket set | `g_grind_ent_sent_this_tick` is reset only in `Grind_OnTickEngine`. Test_A3 (runs earlier) sends an add and leaves it true; later direct calls to `Grind_TryPlaceL0` / `Grind_EnsureAddNext` are blocked | F2 |
| SG5 count, SG6 count | `Grind_SlotRestingEnt` reads live `OrdersTotal()` when the slot seam is off; the tests use the order seam | F1c |
| MQ3 release after trim, MQ3 nearest exit, MQ6 one send | slot seam `used` is a constant; a successful cancel/place does not change it, so AM2 cannot be observed | F1a, F1b, F2 |
| CV3 shift kept, CV3 release kept | prune calls live `PositionSelectByTicket`; the test registers a seam position and never activates the order seam | F3, T4 |
| EQ2 nearest, EQ2 farthest | TEST ERROR. Shorts rank by DESCENDING entry (spec 2a, ADR-151 decision 1). The test expects ascending | T1 |
| RI5 ok, RI5 layer found (and 2 loop assertions never ran: 1134 not 1136) | TEST ERROR. Fixture has 2 long positions, both ranks < K, neither has an exit, so I3 correctly fails reconstruction. No held layer exists | T2 |
| Q10 place once, Q10 layer0 exit | Existing test broken by intended behaviour: layer0 (1.25000) is rank 2 of 3 (allowed, not required) so it is not released. Fixture must place the exit-less layer at rank 0 | T3 |

## BRANCH INSTRUCTION
Work on `feat/adr151-exit-queue`. `git fetch` first and confirm HEAD is `7ed2a7a`; if not,
STOP. Add exactly THREE commits on top, in this order:
  C4. `ADR-151 fix1: correct EQ2, RI5, Q10 fixtures and CV3 seam activation (tests only)`
      -- touches ONLY `ea/fxgrind_tests_adr151.mqh` and `ea/fxgrind_tests.mq5`.
  C5. `ADR-151 fix1: test seams for slot accounting, per-tick flag reset, prune position lookup`
      -- touches ONLY `ea/grind_exitq.mqh`, `ea/grind_engine.mqh`, `ea/grind_carry.mqh`.
  C6. report file only (see RESPONSE FORMAT).
Then create `rollback/adr151-k99-r2` from C5 with the one-line K change (R1 below).
Push both branches. Do NOT merge. Do NOT open a PR. Do NOT touch or force-push
`rollback/adr151-k99` (leave it as is).

## C5 -- SEAM CHANGES (production files; test branches only)
Production behaviour when `g_grind_order_test_active == false` AND
`g_grind_slot_test_active == false` MUST be unchanged: same live calls, same order.

F1. `ea/grind_exitq.mqh`
  a. Add `int g_grind_slot_test_delta = 0;` beside the other slot seams.
  b. `Grind_SlotUsed()`:
       if(g_grind_slot_test_active) return g_grind_slot_test_used + g_grind_slot_test_delta;
       if(g_grind_order_test_active) return 0;
       return PositionsTotal() + OrdersTotal();
  c. `Grind_SlotRestingEnt()`:
       if(g_grind_slot_test_active) return g_grind_slot_test_resting_ent;   (unchanged)
       if(g_grind_order_test_active): count over `g_grind_order_test_records[0..g_grind_order_test_count-1]`
         with exactly the live filter: `Grind_IsFleetMagic(rec.magic)`, and skip only
         when the comment parses with role "EXT". Unparseable fleet order counts.
       else: existing live loop, unchanged.
  d. `Grind_SlotAccountLimit()`:
       if(g_grind_slot_test_active) return g_grind_slot_test_limit;   (unchanged)
       if(g_grind_order_test_active) return 0;   (guard disabled: existing tests never read the live account)
       return AccountInfoInteger(ACCOUNT_LIMIT_ORDERS);
  If `g_grind_order_test_active` / `g_grind_order_test_records` / `GrindOrderTestRecord`
  are not visible in grind_exitq.mqh because of include order, move the three functions'
  test branches behind forward-declared helpers defined in grind_engine.mqh
  (e.g. `bool Grind_OrderTestActive(); int Grind_OrderTestRestingEnt();`). If that still
  cannot compile without a circular include, STOP and report.

F2. `ea/grind_engine.mqh`, test hooks only:
  a. `Grind_OrderTestReset()`: add `g_grind_ent_sent_this_tick = false;` and
     `g_grind_slot_test_delta = 0;`.
  b. `Grind_OrderEngineSend` test branch, `TRADE_ACTION_PENDING`: inside the existing
     success block (retcode DONE or PLACED, after the upsert) add `g_grind_slot_test_delta++;`.
  c. Same function, `TRADE_ACTION_REMOVE`: inside `if(result.retcode == TRADE_RETCODE_DONE)`
     after `Grind_OrderTestRemove`, add `g_grind_slot_test_delta--;`.
  d. Add `bool Grind_PositionTestExistsAnyMagic(const ulong ticket)`: returns true iff
     `ticket != 0` and `ticket` is in `g_grind_position_test_tickets[0..count-1]`.

F3. `ea/grind_carry.mqh`, `Grind_CarryPruneShiftGvs`:
  replace `if(!PositionSelectByTicket(ticket))` with
      const bool exists = g_grind_order_test_active
                          ? Grind_PositionTestExistsAnyMagic(ticket)
                          : PositionSelectByTicket(ticket);
      if(!exists) GlobalVariableDel(name);
  using a forward declaration of `Grind_PositionTestExistsAnyMagic` (and of the flag's
  accessor if the variable is not visible, as in F1). Nothing else in the function changes.

F4. `Adr151_TestResetSlotSeams` (tests file, commit C4): also set `g_grind_slot_test_delta = 0;`.
  (This line references a symbol added in C5. If C4 must compile on its own, put this one
  line in C5 instead and say so in the report.)

## C4 -- TEST CORRECTIONS (tests only; hand-derived values)
T1. Test_EQ2_RanksShortDescendingEntry. Entries {1.09500, 1.09600, 1.09700}, shorts,
    descending: 1.09700 nearest. Replace the three rank assertions (names unchanged):
      AssertTrue("EQ2 nearest",  ranks[2] == 0);
      AssertTrue("EQ2 mid",      ranks[1] == 1);
      AssertTrue("EQ2 farthest", ranks[0] == 2);
    Add comment `// fix1: shorts rank by descending entry; 1.09700 is nearest.`

T2. Test_RI5_HeldLayerExitTargetFormulaNotZero. New fixture, 5 tickets, magic 22260101,
    exit_pips 3.0 (3 pips = 0.00030, as Test_T50 uses):
      1001 POSITION  GRIND|OPT|L|L00|ENT  1.25000
      1002 POSITION  GRIND|OPT|L|L01|ENT  1.24900
      1003 POSITION  GRIND|OPT|L|L02|ENT  1.24800
      2002 ORDER     GRIND|OPT|L|L01|EXT  1.24930
      2003 ORDER     GRIND|OPT|L|L02|EXT  1.24830
    (build comments with GrindCommentBuild; kinds GRIND_RECON_TICKET_POSITION / _ORDER).
    Long ranks by ascending entry: L02 = 0, L01 = 1, L00 = 2. K = 2, H = 1: L02 and L01
    are required and have exits; L00 is allowed, has no exit, and must PASS I3.
    Keep exactly four assertions, names unchanged:
      "RI5 ok"          Grind_RebuildBookFromTickets(...) returns true
      "RI5 formula"     the layer with layer_index 0 has exit_target within 0.000001 of 1.25030
      "RI5 not zero"    that layer's exit_target > 0.0
      "RI5 layer found" a layer with layer_index 0 was found
    Use the literal 1.25030, not a call to the formula function.
    If "RI5 ok" fails with this fixture, STOP and report the reason string verbatim.

T3. Test_Q10_RetryMissingExitsOnlyUncovered. Change ONLY layer 0's fixture:
    `entry_price = 1.24700`, `exit_target = 1.24750`. Ranks then: layer0 1.24700 = 0
    (no exit, required -> released), layer2 1.24800 = 1 (exit position, covered),
    layer1 1.24900 = 2 (exit order 7001, allowed, not trimmed). All four existing
    assertions stay exactly as they are. Replace the ADR-151 comment with:
    `// ADR-151 fix1: exit-less layer moved to rank 0 so the retry-only-uncovered intent still holds.`

T4. Test_CV3_PruneKeepsExistingPositionGvs: add `g_grind_order_test_active = true;`
    immediately before `Grind_PositionTestAdd(pos);`. It is already reset by
    `Grind_OrderTestReset()` at the end.

Do NOT change any other test, assertion, name or expected value. A8, SB2, PO3, SG5,
SG6, MQ3, MQ6 are fixed by C5 alone.

## ROLLBACK
R1. `rollback/adr151-k99-r2` from C5: change only the value on the `GRIND_EXITQ_K`
    define line in `ea/grind_config.mqh` from 2 to 99, keeping spacing. Commit
    `ADR-151 rollback build r2: GRIND_EXITQ_K 99 (on fix1)`. Push. Do not merge.

## NEGATIVE SPACE
- No change to any live (non-test) code path. Grep your C5 diff: it must add no
  `OrderSend`, `TRADE_ACTION`, `PositionSelect`, `OrderSelect` call outside a test branch
  or the F3 ternary.
- No change to ranking, the guard formulas, the lock, trim/release, halt-cancel, recon.
- Do not fix the commit-1 compile defect (51d9be7). Do not rewrite history.
- Do not deploy, do not CLI compile, do not launch MetaTrader, do not `git stash`, do not
  check out files from other commits, no `git add .` / `git add -u`, no merge, no PR,
  no force-push.
- ASCII only in every line you add.

## STOP CONDITIONS
- HEAD is not 7ed2a7a after fetch.
- Any F-change needs a circular include that forward declarations cannot resolve.
- T2 "RI5 ok" cannot pass with the stated fixture by your reading of the recon code.
- Any change beyond the files named for C4 / C5.

## RESPONSE FORMAT
Write `prompts/cursor_adr151_phaseA_fix1_response.md` as commit C6 (only that file).
First line: `UNVERIFIED WORKING MATERIAL -- verify against the branch, not this file.`
Contents:
    BASE_HEAD: 7ed2a7a
    COMMITS: <C4> <C5> <C6>
    ROLLBACK_BRANCH: rollback/adr151-k99-r2 <hash>
    FILES_C4: <list>
    FILES_C5: <list>
    F4_PLACED_IN: C4 | C5
    INCLUDE_ORDER_ACCESSORS_ADDED: YES|NO (list)
    COMPILED: NO
    OPEN_QUESTIONS: <any, or none>
Last line: `Line count: N` (mechanical count of that file).
Push both branches. Reply in chat with ONLY: branch names, every commit hash AS IT
EXISTS ON ORIGIN, and one line saying the report is pushed.

Line count: 168
