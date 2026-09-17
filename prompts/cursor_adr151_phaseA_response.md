UNVERIFIED WORKING MATERIAL -- verify against the branch, not this file.

# ADR-151 Phase A — Cursor implementation report

    BASELINE_HEAD: 6cc2899
    BRANCH: feat/adr151-exit-queue
    COMMITS: 51d9be7 568ac58
    FILES_CHANGED: ea/grind_config.mqh (+8), ea/grind_exitq.mqh (+227), ea/grind_engine.mqh (+289/-), ea/grind_recon.mqh (+119/-), ea/grind_carry.mqh (+41/-), ea/grind_closeby.mqh (+4), ea/grind_magic_lock.mqh (+17/-), ea/fxgrind.mq5 (+8), ea/fxgrind_tests.mq5 (+101/-), ea/fxgrind_tests_adr151.mqh (+1033)
    ROLLBACK_BRANCH: rollback/adr151-k99 (pending)
    ROLLBACK_DIFF_LINES: 1 (expect 1 changed line)
    NEW_TESTS: 41
    EXISTING_TESTS_MODIFIED: 3 -- Q10_RetryMissingExitsOnlyUncovered, T51_InvariantNeitherExitStillHalts, SB4_EntExitGoesToFilledPosition (plus Grind_TestReconCheckInvariants helper for ranked I3/I6/I1)
    ANCHORS_VERIFIED: YES
    COMPILED: NO (operator compiles on VPS)
    OPEN_QUESTIONS: none

Line count: 17
