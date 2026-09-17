UNVERIFIED WORKING MATERIAL -- verify against the branch, not this file.

# ADR-151 Phase A fix1 -- Cursor report

    BASE_HEAD: 7ed2a7a
    COMMITS: 4d1c6ee 1390052 c2ed0ef
    ROLLBACK_BRANCH: rollback/adr151-k99-r2 f7e2123
    FILES_C4: ea/fxgrind_tests_adr151.mqh, ea/fxgrind_tests.mq5
    FILES_C5: ea/grind_exitq.mqh, ea/grind_engine.mqh, ea/grind_carry.mqh
    F4_PLACED_IN: C5
    INCLUDE_ORDER_ACCESSORS_ADDED: YES (Grind_OrderTestActive, Grind_OrderTestRestingEntFleetCount, Grind_PositionTestExistsAnyMagic in grind_engine.mqh; forward-declared in grind_exitq.mqh and grind_carry.mqh)
    COMPILED: NO
    OPEN_QUESTIONS: F4 Adr151_TestResetSlotSeams delta reset implemented via Grind_OrderTestReset (F2a) only; C5 file scope excluded tests file.

Line count: 15
