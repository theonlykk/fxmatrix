This message has a line count at the bottom

# GEMINI -- STAFF ARCHITECT RULING REQUEST: ADR-151 PHASE A SPEC AMENDMENTS AND DEPLOY SAFETY

## YOUR ROLE
Staff architect. Rule; do not implement. Write no code. Claude (lead
engineer) verifies every amendment you make against source and records it
accepted or rejected with reasons. Keep your response under 120 lines.

## THE SYSTEM (fixed frame)
fxgrind is a passive limit-order market maker on MT5. Fourteen EA instances
share ONE FTMO demo account (hedging), separated by magic number. It never
crosses the spread and never uses stop losses. Per side an instance holds a
ladder of layers; today each layer is one position plus one exit limit at
entry +/- exit_pips. Adds are priced from the deepest layer. An exit fill
opens an opposite position that the EA nets with CloseBy. Invariants rebuild
the book from broker tickets every tick; a failure quarantines or halts. A
halted instance stops trading but its resting orders still fill.

## WHAT YOU ALREADY RULED
You approved ADR-151 (order purgatory: exit queue K=2, H=1; commitment guard
with margin 4 under a fleet GV lock, 10 s staleness) with amendments, on the
design memo rev 5. That ruling stands and is not reopened here.

## WHY THIS REQUEST EXISTS
After your ruling, the Phase A implementation spec was audited by DeepSeek R1
against source. Claude verified the findings and folded them into the spec as
amendments AM1-AM8 (section 11 of the spec below). You have NOT seen AM1-AM8.
Our process requires your ruling on a substantive spec before Cursor
implements it. The full spec follows, verbatim, 269 lines.

Separately, two deploy facts surfaced after the spec was written. Both are
verified against source at main. Either could require a spec change, which is
why they are here and not in a later runbook review.

## FACTS AS OF 2026-09-17 ~01:00Z (state, not a guarantee of current state)
- Nothing from ADR-151 is implemented or deployed. VPS runs the ADR-150 build.
- Book: 86 positions + 97 orders = 183 of 200 (status read 00:45Z).
- 6 instances running. 8 halted and PARKED (no resting entries, no position
  without an exit): GBPUSD OPT, EURUSD OPT, EURUSD ALT, AUDCHF OPT,
  AUDCHF ALT, NZDCAD OPT, AUDNZD OPT (flat). Every overnight halt was the
  same mechanism: a fill at 200/200, exit refused, I3 naked.
- F1. `OnInit` sets `g_grind_halted = false` (fxgrind.mq5:125); the halt flag
  is in memory only. Compiling fxgrind.mq5 reloads every chart. So deploying
  ADR-151 un-halts all 8 parked instances at the same instant it goes live.
- F2. The current (ADR-150) reconstruction and tick invariants require an
  exit on EVERY layer (grind_recon.mqh ~434-462, I3 no_exit_coverage). After
  ADR-151 trims held exits, restoring the ADR-150 .ex5 makes every instance
  with a held layer fail reconstruction and halt. The deploy plan's rollback
  ("restore the backed-up .ex5 and reinit") therefore does not work.
- Claude's estimate from the 00:45Z book: on reload ADR-151 trims about 31
  exits (GBPUSD ALT 9, GBPUSD OPT 7, EURUSD OPT 5, EURUSD ALT 4, EURGBP ALT 3,
  EURGBP OPT 2, CADCHF ALT 1) and nets one locked pair, book ~150. Estimate,
  not measurement.

## WHAT TO RULE ON

Q1. AM1-AM8. For EACH of AM1..AM8: APPROVE, AMEND (state the amendment), or
    REJECT (state why). Especially:
    - AM3: entry cancel at five halt sites including the reconstruction
      failure site, not at the test stub.
    - AM4: lock acquired only immediately around the send, after all
      validation; nothing that can halt or return early runs under the lock.
    - AM2: slots recomputed before each exit send in the release loop.

Q2. ROLLBACK. Claude proposes:
    (a) The rollback path is a SECOND build of the same ADR-151 code with
        `GRIND_EXITQ_K` set to a value >= every instance's max_layers (e.g.
        99). All ranks become required, trim cancels nothing, release
        re-places every held exit where a slot exists. The commitment guard
        and halt-cancel stay.
    (b) Only after that build shows zero held layers fleet-wide may the
        ADR-150 .ex5 be restored, if a true code rollback is still wanted.
    (c) Spec addition: a test that K >= layer count makes every layer
        required, trim cancels nothing, and release targets every exit-less
        layer; and a statement that no code may assume K is small.
    Rule on (a)-(c). If you prefer a different rollback, state it.

Q3. RESUMING THE 8 PARKED INSTANCES. Options:
    (i)  Compile with all 14 attached. All 8 resume at once; the commitment
         guard serialises entries (one send per instance per tick, fleet
         lock, free - resting_ent >= 6).
    (ii) Detach the 8 parked instances first (safe: no entries, every
         position has an exit; an exit that fills while detached leaves a
         locked pair, netted on reattach). Compile with the 6 running
         instances. Observe. Reattach the 8 one at a time, reading the book
         between each. Detaching frees no slots.
    Claude recommends (ii): the first live run of never-run code (trim,
    release, hold-cancel deal lookup, fleet lock) happens on 6 instances,
    and each reattach is an isolated observation. Does either option need a
    spec change? Rule on (i) vs (ii).

Q4. Anything in the spec below that contradicts your ADR-151 ruling.

## RESPONSE FORMAT
Q1: one line per AM (AM1: APPROVE | AMEND <text> | REJECT <reason>).
Q2, Q3, Q4: ruling, then reasons. No code. End with the line
`Line count: N` where N is the actual number of lines of your response.

## THE SPEC, VERBATIM (prompts/cursor_adr151_phaseA.md at 8d8bbce, 269 lines)
----- BEGIN SPEC -----
This message has a line count at the bottom.

# CURSOR PROMPT -- ADR-151 PHASE A: EXIT QUEUE + COMMITMENT GUARD (fxgrind EA)

## AUDIT TRAIL
| Item | Value |
|---|---|
| Repo | theonlykk/fxmatrix, `D:\fxmatrix` |
| Design | `docs/architecture/ADR-151-order-purgatory.md` (already on main) and memo rev 5 |
| Baseline | confirm `origin/main` HEAD before starting; EA source last changed at `9f67f0f` |
| Branch | `feat/adr151-exit-queue` from `main` |
| Compile / tests | You CANNOT compile MQL5. Never claim a compile or a test pass. The operator compiles `ea/fxgrind.mq5` and runs `ea/fxgrind_tests.mq5` on the VPS |

## ORIENTATION (source facts you will rely on; verify each before editing)
- `ea/grind_engine.mqh`: `Grind_TryPlaceL0` ~449, `Grind_TryPlaceExitForLayer` ~514, `Grind_AppendLayer` ~558, `Grind_RemoveLayerAt` ~578, `Grind_EnsureAddNext` ~636, `Grind_HandleSideDealFill` ~833, `Grind_RetryMissingExits` ~1009, `Grind_OnTickEngine` ~1026, `Grind_OnTradeTransactionEngine` ~1161, `Grind_CancelPendingOrder` ~356, `Grind_HaltCritical` ~376, test seams `g_grind_order_test_*`, `g_grind_position_test_*`, `g_grind_deal_test_*`.
- `ea/grind_recon.mqh`: `Grind_ReconEnsureLayer` ~310 (exit_target = 0.0), early I3/I4 loop in `Grind_RebuildBookFromTicketsInner` ~962-990, `Grind_ReconCheckInvariants` ~394 (I7, I5, I3, I6, I1), output copy ~1015.
- `ea/grind_carry.mqh`: `Grind_CarryShiftSet/Get/Delete` ~480-500, `Grind_CarryShiftWithinBound` ~502, `Grind_CarryShiftGetValidated` ~522, `Grind_CarryClampLongExit/ShortExit` ~439/~457, `Grind_CarryPruneShiftGvs` ~771.
- `ea/fxgrind.mq5`: `OnInit` ~78 (reconstruct ~130, prune ~135), `OnTick` ~226 (halt ~234, quarantine branch ~246).
- `ea/grind_cap.mqh` `Grind_CapTryAcquireLock` ~88: GlobalVariableTemp + GlobalVariableSetOnCondition pattern.
- `ea/grind_magic_lock.mqh` ~26: the 16 fleet magics.
If any anchor is wrong by more than 30 lines or a named function does not exist, STOP and report.

## SCOPE -- PHASE A (carry pass disabled fleet-wide)
Implement ADR-151 decisions 1-8 with exit target = formula (no carry ledger, no
promotion). Phase B items are OUT OF SCOPE.

## 1. CONSTANTS (`ea/grind_config.mqh`)
    #define GRIND_EXITQ_K                 2
    #define GRIND_EXITQ_H                 1
    #define GRIND_SLOT_MARGIN             4
    #define GRIND_SLOT_LOCK_GV            "GRIND_SLOT_LOCK"
    #define GRIND_SLOT_LOCK_STALE_MS      10000
    #define GRIND_SLOT_LOCK_MAX_RETRIES   50
    #define GRIND_CARRY_RELEASE_PREFIX    "GRIND_CARRY_RELEASE_"
If `grind_config.mqh` is not included where needed, include it; do not duplicate.

## 2. NEW FILE `ea/grind_exitq.mqh` (pure where possible; include guard)
2a. Ranking:
    void Grind_ExitQRanks(const double &entries[], const int &layer_indices[],
                          const int n, const bool is_long, int &ranks_out[]);
  rank 0 = nearest to market. Longs: ascending entry. Shorts: descending entry.
  Ties: lower layer_index ranks first. Deterministic O(n^2) acceptable.
    bool Grind_ExitQRequired(const int rank)  // rank < GRIND_EXITQ_K
    bool Grind_ExitQAllowed(const int rank)   // rank < GRIND_EXITQ_K + GRIND_EXITQ_H
2b. Fleet magic: `bool Grind_IsFleetMagic(const long magic)` using the same 16
  magics as grind_magic_lock.mqh. Refactor to ONE shared constant array used by
  both files; do not keep two copies.
2c. Slot accounting (seams for tests):
    long Grind_SlotAccountLimit();   // AccountInfoInteger(ACCOUNT_LIMIT_ORDERS); test override
    int  Grind_SlotUsed();           // PositionsTotal() + OrdersTotal(); test override
    int  Grind_SlotRestingEnt();     // pending orders, any symbol, Grind_IsFleetMagic(magic),
                                     // whose comment does NOT parse with role "EXT"
                                     // (unparseable fleet order counts); test override
    bool Grind_SlotExitAllowed(const long limit, const int used);              // limit<=0 || limit-used >= 1
    bool Grind_SlotEntryAllowed(const long limit, const int used, const int resting_ent);
                                     // limit<=0 || limit-used-resting_ent >= 2 + GRIND_SLOT_MARGIN
  Test overrides: `g_grind_slot_test_active`, `g_grind_slot_test_limit`,
  `g_grind_slot_test_used`, `g_grind_slot_test_resting_ent`.
2d. Fleet lock:
    bool Grind_SlotLockAcquire(double &token_out);
    void Grind_SlotLockRelease(const double token);
  Acquire: `GlobalVariableTemp(GRIND_SLOT_LOCK_GV)`; loop up to
  GRIND_SLOT_LOCK_MAX_RETRIES: now = (double)GetTickCount64() (use `now+1` if
  now == 0); if `GlobalVariableSetOnCondition(name, now, 0.0)` -> token=now,
  true. Else v = GlobalVariableGet(name); if v > 0 and now - v >
  GRIND_SLOT_LOCK_STALE_MS and `GlobalVariableSetOnCondition(name, now, v)` ->
  print WARN SLOT_LOCK_STOLEN, token=now, true. Sleep(1). After retries: false.
  Release: `GlobalVariableSetOnCondition(name, 0.0, token)` (only if still ours).
2e. Release pricing:
    double Grind_ExitQFormulaTarget(const double entry, const double exit_pips,
                                    const double point, const bool is_long);
    bool   Grind_ExitQClampPassive(const bool is_long, const double target,
                                   double &price_out);   // uses Grind_CarryClampLongExit/ShortExit
                                                         // with live bid/ask/stops/freeze; returns clamped?
    string Grind_CarryReleaseGvName(const ulong position_ticket);
  When a placed exit price differs from the formula target by more than half a
  point: `Grind_CarryShiftSet(position_ticket, price - formula)` AND
  `GlobalVariableSet(Grind_CarryReleaseGvName(position_ticket), 1.0)`.

## 3. CARRY FILE CHANGES (`ea/grind_carry.mqh`)
3a. `Grind_CarryShiftGetValidated`: if the release GV exists for the position,
  return the stored shift WITHOUT calling `Grind_CarryShiftWithinBound`.
3b. `Grind_CarryShiftDelete`: also delete the release GV.
3c. `Grind_CarryPruneShiftGvs` (FLEET-SAFETY FIX): delete a
  `GRIND_CARRY_SHIFT_<t>` or `GRIND_CARRY_RELEASE_<t>` GV ONLY if position `t`
  does not exist (`PositionSelectByTicket(t)` false). Never delete a GV whose
  position exists under another magic. Keep the function name and call sites.

## 4. ENGINE CHANGES (`ea/grind_engine.mqh`)
4a. `Grind_ExitQManageSide(GrindSideState &side, const bool is_long, const ulong magic,
    const string slot, const double lots, const double exit_pips)`:
   1. Compute ranks over `side.layers` with `Grind_ExitQRanks`.
   2. TRIM: for each layer with `!Grind_ExitQAllowed(rank)` and
      `exit_order_ticket != 0`: hold-cancel (4b).
   3. RELEASE/RETRY: for each layer with `Grind_ExitQRequired(rank)`,
      `exit_order_ticket == 0`, `exit_position_ticket == 0`:
      target = formula; clamp passive (2e); if
      `Grind_SlotExitAllowed(limit, used)` place with `Grind_PlaceLimit`
      (existing comment format EXT, existing lots/magic); on success set
      `exit_order_ticket`, `exit_target = price`, and store shift+release GV
      when clamped (2e). Never place from a stored stale price.
   Trim always runs before release.
4b. Hold-cancel for a layer:
   - `Grind_CancelPendingOrder` true -> `exit_order_ticket = 0`.
   - false and `Grind_SelectOurOrder(ticket, magic)` still true -> leave; retry next call.
   - false and order gone -> `Grind_ExitQFindExitDealPosition(order_ticket, is_long, magic, pos_out)`:
     search deals (history over the last 30 days; test seam: `g_grind_deal_test_records`)
     for `order_ticket` match with `entry_type == DEAL_ENTRY_IN`, magic == magic, and
     deal comment side letter equal to the layer's side. If found and
     `Grind_SelectOurPosition(pos_out, magic)`: set `exit_position_ticket = pos_out`,
     `exit_order_ticket = 0`, queue CloseBy exactly as `Grind_HandleSideDealFill`
     does for an EXT fill. If not found: `exit_order_ticket = 0`.
4c. `Grind_TryPlaceExitForLayer`: before sending, require
  `Grind_SlotExitAllowed`; if not allowed return false without sending.
4d. `Grind_HandleSideDealFill`, ENT branch: replace the direct
  `Grind_TryPlaceExitForLayer` call with `Grind_ExitQManageSide` for that side
  (the new layer is rank 0 and gets its exit; a pushed-back exit may be trimmed).
4e. `Grind_HandleSideDealFill`, OUT_BY branch: before `Grind_RemoveLayerAt`,
  call `Grind_CarryShiftDelete(layer.position_ticket)`; after removal call
  `Grind_ExitQManageSide` for that side (release).
4f. `Grind_RetryMissingExits`: body becomes `Grind_ExitQManageSide` for long
  then short. Keep the function name (called from fxgrind.mq5).
4g. `Grind_OnTickEngine`: after guards, reset `g_grind_ent_sent_this_tick =
  false`, call `Grind_RetryMissingExits` FIRST (before stray-L0 reconcile, L0,
  recentre, cap transition, adds). Remove the later call.
4h. Entry guard in `Grind_TryPlaceL0` and in `Grind_EnsureAddNext` at the
  point each sends a NEW ENT order (not modifies, not cancels):
    if(g_grind_ent_sent_this_tick) return (no send);
    if(!Grind_SlotLockAcquire(token)) return (defer);
    recompute limit/used/resting_ent; if !Grind_SlotEntryAllowed -> release lock, return (defer);
    send; release lock; if sent set g_grind_ent_sent_this_tick = true.
  Deferral sends nothing and changes no tracker.
4i. `Grind_CancelOwnEntryOrders(const ulong magic, const string slot)`: scan
  broker orders for this symbol and magic whose comment parses with role ENT
  and this slot; cancel each with `Grind_CancelPendingOrder`; clear
  `l0_pending_ticket` / `add_pending_ticket` only for tickets confirmed gone.
  Never touch EXT orders.
4j. `Grind_HaltCritical`: call `Grind_CancelOwnEntryOrders` after setting the flag.

## 5. RECON CHANGES (`ea/grind_recon.mqh`)
5a. After scanning tickets, for each side compute ranks over scratch layers
  with `has_position` using `Grind_ExitQRanks`.
5b. Early loop (~962-990): I3 no_exit_coverage ONLY when
  `Grind_ExitQRequired(rank)`. I4 unchanged.
5c. `Grind_ReconCheckInvariants`: add rank arrays as parameters (update all
  callers and tests). I3 no_exit_coverage ONLY for required ranks. I6 ONLY for
  layers with `Grind_ReconLayerHasExitCoverage`. I1 exit_count ONLY for layers
  with coverage. I3 no_position, I5, I7 unchanged.
5d. Output copy (~1015): for a layer without coverage set `exit_target =
  Grind_ExitQFormulaTarget(entry, exit_pips, point, is_long)`, never 0.0.

## 6. EA ENTRY POINTS (`ea/fxgrind.mq5`)
6a. `OnInit`: if `InpEnableCarryPass` is true -> Print FATAL "ADR-151 phase A
  requires InpEnableCarryPass=false" and `return INIT_FAILED` (before magic lock).
6b. `OnInit`, after `Grind_ReconstructState()` returns true: call
  `Grind_RetryMissingExits(InpMagic, InpSlot, InpLots)` once (trim first,
  release where allowed).
6c. `OnTick` invariant halt branch (~234): after setting halted, call
  `Grind_CancelOwnEntryOrders(InpMagic, InpSlot)`.
6d. `OnTick` quarantined branch (~246): keep calling `Grind_RetryMissingExits`
  (which now trims before release); guards as today.
6e. (Superseded by AM3: the cancel lives at the reconstruction failure site.)

## 7. TESTS (`ea/fxgrind_tests.mq5`) -- commit 1, before implementation
Add these (names exact), registered in `OnStart` before the SUMMARY line:
  EQ1_RanksLongAscendingEntry, EQ2_RanksShortDescendingEntry, EQ3_RankTieByLayerIndex,
  EQ4_RequiredAllowedBands,
  SG1_ExitAllowedAtOneFree, SG2_EntryBlockedBelowMargin, SG3_EntryAllowedAtMargin,
  SG4_LimitZeroDisablesGuard, SG5_RestingEntCountsUnparseableFleetOrder,
  SG6_RestingEntIgnoresExtAndNonFleet,
  LK1_AcquireReleaseRoundTrip, LK2_SecondAcquireFailsWhileHeld, LK3_StaleLockStolen,
  LK4_ReleaseOnlyIfTokenMatches,
  MQ1_TrimCancelsBeyondAllowedBand, MQ2_ReleasePlacesRequiredMissing,
  MQ3_TrimRunsBeforeRelease, MQ4_NoSendWhenExitNotAllowed,
  MQ5_ClampStoresShiftAndReleaseMarker,
  HC1_CancelDoneClearsTracker, HC2_CancelFailedOrderLiveKeepsTracker,
  HC3_GoneWithDealQueuesCloseBy, HC4_GoneWithoutDealClearsTracker,
  HC5_DealOnOtherSideIgnored,
  CV1_ReleaseMarkerSkipsBound, CV2_ShiftDeleteRemovesMarker,
  CV3_PruneKeepsExistingPositionGvs,
  RI1_HeldLayerBeyondKPassesI3, RI2_MissingExitAtRequiredRankFailsI3,
  RI3_I1SkipsLayersWithoutExit, RI4_I6SkipsLayersWithoutExit,
  RI5_HeldLayerExitTargetFormulaNotZero,
  EG1_EntryDeferredNoSendWhenBlocked, EG2_OneEntSendPerTick,
  HT1_HaltCriticalCancelsOwnEntOnly,
  FL1_EntFillPlacesRankZeroExitAndTrims.
Commit 1 contains ONLY tests and the minimal seams/constants needed for them to
reference symbols (stubs returning neutral values are allowed so the suite
compiles and the new tests FAIL).
Existing tests broken by the intended behaviour change (I3 on every layer,
direct exit on ENT fill, retry order): update each in commit 2 with a one-line
comment `// ADR-151: <reason>`. Do not delete any existing test. List every
modified existing test in the report.

## 8. COMMITS
  1. `ADR-151: tests and seams for exit queue and commitment guard (failing)`
  2. `ADR-151: exit queue, commitment guard, fleet lock, trim, halt-cancel (phase A)`
Push the branch. Do NOT merge. Do not edit the ADR or the memo.

## 9. NEGATIVE SPACE
- No Phase B: no swap-ledger target, no promotion, no deadband input.
- No change to geometry, add targets, exit_pips rule, ADR-123/124 logic,
  ADR-149 cap, telemetry JSON shape, pipshed.
- No new inputs. Constants only.
- Do not touch `ea/presets/`.
- Do not claim compile success or test results.

## 10. STOP CONDITIONS
- Any orientation anchor wrong by >30 lines or missing.
- A required change would alter an existing invariant OTHER than I3 coverage
  scope, I1 scope, I6 scope.
- The deal history API needed for 4b is unavailable in the harness and cannot
  be seamed with the existing `g_grind_deal_test_*` records.
- More than 40 existing tests need modification.

## 11. AUDIT AMENDMENTS (DeepSeek spec audit `17838db`, verified by Claude)
These SUPERSEDE earlier sections where they conflict.

AM1. `Grind_RetryMissingExits(magic, slot, lots)` keeps its signature (called
  from fxgrind.mq5 ~248 and 6b). It passes `g_grind_recon_exit_pips` (set in
  OnInit before reconstruction) to `Grind_ExitQManageSide`.
AM2. Release loop (4a step 3): recompute `limit` and `used` IMMEDIATELY before
  EACH exit send; never reuse values from before an earlier send in the loop.
AM3. Halt cancels entries on EVERY halt site. Call
  `Grind_CancelOwnEntryOrders(g_grind_recon_magic, g_grind_recon_slot)`
  directly after each `g_grind_halted = true` at:
    grind_engine.mqh ~378 (`Grind_HaltCritical`),
    grind_closeby.mqh ~167 (CLOSEBY_EXHAUSTED) and ~226 (CLOSEBY_SYMBOL_MISMATCH),
    grind_recon.mqh ~1160 (`Grind_ReconstructState` failure; this REPLACES 6e),
    fxgrind.mq5 ~235 (invariant halt; this is 6c).
  NOT at fxgrind.mq5 ~282 (`Grind_TestStubHaltPath`, a test stub).
  Add a forward declaration of `Grind_CancelOwnEntryOrders` where needed by
  include order (as grind_recon.mqh already forward-declares
  `Grind_CarryShiftGetForRecon`). If a file cannot reach it without a circular
  include, STOP and report.
AM4. Lock scope (4h): acquire the slot lock immediately before the
  `Grind_PlaceLimit` call in `Grind_TryPlaceL0` (~477) and in
  `Grind_EnsureAddNext` (~716), AFTER all existing validation including
  `Grind_ValidateAddLabelIndex` (~710), cap and marketability checks. Release
  on every path after acquisition. Nothing that can halt or return early may
  run while the lock is held.
AM5. Fleet magic table: reuse the existing `GRIND_CAP_ALL_MAGICS` (grind_cap.mqh
  ~18) as the ONE table. `Grind_MagicLockReleaseAllKnown` and
  `Grind_IsFleetMagic` both iterate it. Keep 22269901 handling in the magic
  lock unchanged. If include order prevents this, STOP and report.
AM6. Declare `g_grind_ent_sent_this_tick` and all `g_grind_slot_test_*` in
  `grind_exitq.mqh`. `Grind_ExitQRanks` resizes `ranks_out` to n.
AM7. 4d: the new layer receives an exit if its rank is required; do not assume
  rank 0.
AM8. Additional tests (add to commit 1; NEW_TESTS becomes 39):
  HT2_CloseByExhaustedHaltCancelsOwnEnt, MQ6_UsedRecomputedBeforeEachExitSend,
  EG3_LockReleasedWhenSendFails.
Known residual (no test possible in the script harness): the live
`HistorySelect` deal lookup in 4b. The operator smoke-checks it on deploy.

## 12. REPORT (print in chat)
    BASELINE_HEAD: <hash>
    BRANCH: feat/adr151-exit-queue
    COMMITS: <hash1> <hash2>
    FILES_CHANGED: <list with +/- lines>
    NEW_TESTS: <count> (expect 39)
    EXISTING_TESTS_MODIFIED: <count> -- <names>
    ANCHORS_VERIFIED: YES|NO (list deviations)
    COMPILED: NO (operator compiles on VPS)
    OPEN_QUESTIONS: <any, or none>
End your response with the line `Line count: N`, where N is the mechanical
line count of your full response.

Line count: 269
----- END SPEC -----

Line count: 373
