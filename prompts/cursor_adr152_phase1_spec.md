This message has a line count at the bottom

# CURSOR SPEC -- ADR-152 PHASE 1: fill-time placement, priority band, entry stop
# No withholding in this phase. Baseline: main @ ec364a3, EA at c39fb84.
# ADR: docs/architecture/ADR-152-entry-purgatory.md (166 lines, `cdb95f4`).

## SCOPE
Phase 1 changes WHEN and IN WHAT ORDER entries are placed, plus a hard request
stop. Every add still rests exactly as today. Phase 2 (the entry horizon) is NOT
in this spec -- do not implement D3, D4's transition budget, or D6.

Touch ONLY: `ea/grind_config.mqh`, `ea/grind_exitq.mqh`, `ea/grind_engine.mqh`,
`ea/grind_state.mqh`, `ea/grind_api_counter.mqh`, `ea/fxgrind.mq5`,
`ea/fxgrind_tests_adr152.mqh` (new), `ea/fxgrind_tests.mq5` (include + calls).
Do NOT touch pipshed, presets, deploy.ps1, or any other ea/ file.

## COMMIT 1 -- tests first (they must FAIL before commit 2)

New file `ea/fxgrind_tests_adr152.mqh`, same shape as
`fxgrind_tests_adr151.mqh` (forward-declare symbols, `Adr152_TestResetAll()`,
helpers that seed the slot seams `g_grind_slot_test_*`). Wire it into
`fxgrind_tests.mq5` with an include next to the ADR-151 one and calls from
`OnStart()`. Use the existing `AssertTrue` / `AssertFalse` / `AssertNear`.

Tests required (names exactly as given):

    T1_single_attempt_lock_has_no_retry_loop
    T1b_single_attempt_lock_returns_false_when_held
    T1c_single_attempt_lock_releases_only_own_token
    T2_near_entry_allowed_at_ceiling
    T2b_far_entry_refused_inside_reserve
    T2c_far_entry_allowed_below_reserve
    T2d_reserve_zero_reproduces_today
    T3_entry_stop_blocks_entry_at_threshold
    T3b_entry_stop_does_not_block_exit
    T3c_entry_stop_resets_with_broker_day
    T4_due_flag_set_on_ent_fill_only
    T4b_due_flag_cleared_on_place
    T4c_due_flag_cleared_at_cap
    T4d_due_flag_cleared_on_label_mismatch
    T4e_due_flag_cleared_on_init
    T4f_due_flag_not_retried_twice_in_one_tick
    T5_no_double_send_due_plus_ensure

T1 is a STRUCTURAL test: assert that the new single-attempt helper's source
contains no `Sleep(` and no loop keyword. Implement it by reading
`grind_exitq.mqh` at test time via `FileOpen`/`FileReadString` over the function
body between its opening and closing brace, and failing on `Sleep(`, `for(`,
`while(`. This is deliberate: Gemini's amendment is a hard requirement and must
be enforced mechanically, not by review.

## COMMIT 2 -- implementation

### 2.1 `grind_config.mqh`
    #define GRIND_SLOT_NEAR_RESERVE        8     // Q, guard units reserved
    #define GRIND_DAILY_API_ENTRY_STOP  1900     // hard stop, entries only

### 2.2 `grind_exitq.mqh`
Add, next to `Grind_SlotLockAcquire`:

    bool Grind_SlotLockTryAcquire(double &token_out)

ONE `GlobalVariableSetOnCondition` attempt. No retry, no `Sleep`, no stale-lock
steal (a stale lock is the blocking path's problem, not this one). Returns false
immediately on contention.

Change the entry gate to take distance:

    bool Grind_SlotEntryAllowed(const long limit,
                                const int used,
                                const int resting_ent,
                                const bool near_market)   // NEW

    needed = 2 + GRIND_SLOT_MARGIN + (near_market ? 0 : GRIND_SLOT_NEAR_RESERVE)

`near_market` is computed by the CALLER as
`MathAbs(target - mid) <= add_pips + GRIND_PRICE_EPS` for adds, and TRUE for L0
(L0 is near mid by construction). Keep the existing 3-argument signature as a
thin wrapper passing `near_market = true` so no other call site changes
behaviour unexpectedly -- but update both real call sites to pass the flag.

### 2.3 `grind_api_counter.mqh`
    bool Grind_ApiCounterEntryStopped()   // read >= GRIND_DAILY_API_ENTRY_STOP
Reuses the existing broker-day reset. Emits `WARN_API_ENTRY_STOP` once per day
via the existing archive/marker path when it first trips.

### 2.4 `grind_state.mqh`
    bool g_grind_add_due_long  = false;
    bool g_grind_add_due_short = false;
    bool g_grind_add_due_attempted_long  = false;   // per-tick, T4f
    bool g_grind_add_due_attempted_short = false;
All four cleared in the engine's init/reset path alongside existing state.

### 2.5 `grind_engine.mqh`
(a) Both entry paths (`Grind_TryPlaceL0` ~528, `Grind_EnsureAddNext` ~789):
    - refuse immediately if `Grind_ApiCounterEntryStopped()`;
    - pass `near_market` into `Grind_SlotEntryAllowed`.
(b) New `Grind_TryPlaceAddAtFill(GrindSideState &side, const bool is_long, ...)`:
    - `Grind_SlotLockTryAcquire`; on failure set the due flag and RETURN;
    - on success: guard check, then the SAME add computation and placement as
      `Grind_EnsureAddNext` (extract the shared body into a helper rather than
      duplicating it), then release.
(c) In `Grind_HandleSideDealFill`, `c_role == "ENT"` branch, AFTER
    `Grind_ExitQManageSide`: call `Grind_TryPlaceAddAtFill` for that side.
    This is the only new call in the transaction handler. It must not block.
(d) In `Grind_OnTickEngine`, immediately after
    `g_grind_ent_sent_this_tick = false;` and the existing
    `Grind_RetryMissingExits` call (exits keep absolute priority), service due
    flags: for each side with a due flag not yet attempted this tick, call the
    shared add helper once, set `attempted`, clear the due flag per D5. Clear
    both `attempted` flags at the top of each tick.

### 2.6 `fxgrind.mq5`
    input bool InpFillTimePlace = true;    // D1 kill switch
    input int  InpSlotNearReserve = GRIND_SLOT_NEAR_RESERVE;   // 0 = off
Both threaded through to the engine. With `InpFillTimePlace = false` and
`InpSlotNearReserve = 0`, behaviour must be byte-identical to `c39fb84`.

## COMMIT 3 -- telemetry
Add to the heartbeat payload, per instance: `add_due_long`, `add_due_short`,
`entry_stopped` (bool), `near_reserve_blocks` (counter, resets with the API
counter), `guard_total` (`used + resting_ent` at send time), and
`entry_place_latency_ms` (fill deal time to add placement, 0 when no add).
Do NOT change pipshed in this commit; the fields must simply be present in the
JSON.

## VERIFICATION (report all of it)
1. `git log --oneline -3` and `git status --short` after each commit.
2. Full MQL5 suite: total run/passed. Baseline is 1136/1136; expect 1136 + 17.
3. Compile in MetaEditor: errors AND warnings, verbatim. **Never report a
   compile as clean from CLI output alone.**
4. Print the body of `Grind_SlotLockTryAcquire` verbatim.
5. Confirm by grep that `Grind_HandleSideDealFill` contains exactly one call to
   `Grind_TryPlaceAddAtFill` and no `Sleep(`.

## NEGATIVE SPACE
- No withholding of any order. No horizon. No transition budget.
- Do not modify `Grind_SlotLockAcquire` itself.
- Do not change exit placement, the exit queue, cap logic or recon.
- Do not deploy, do not touch the VPS, do not compile to the terminal folder.
- If any test cannot be written as specified, STOP and report; do not weaken it.

Line count: 143
