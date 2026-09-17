This message has a line count at the bottom.

# DeepSeek Phase 1 -- Teardown: ENTRY PURGATORY (proximity horizon for resting entries)
# ADR-152 candidate. Source baseline: origin/main @ d139933; EA at c39fb84.
# You have READ access to ea/ and docs/architecture/.

## Role
Phase 1 Red Team (adversarial quant). Write ZERO implementation code. Break the
proposal AND its premise against the ACTUAL source. Hunt mechanical failure modes.

## Frame (do NOT retail-judge)
fxgrind is a passive limit-order market maker on MT5. Sixteen instances (eight
symbols x two geometry arms, OPT and ALT) share one FTMO demo account, separated by
magic number. It NEVER crosses the spread and NEVER uses stop losses. Per side an
instance holds a ladder of layers; since ADR-151 only the nearest ranks hold a live
exit order (K=2 required, H=1 allowed), deeper exits are HELD as formula targets with
no broker order. Entries are different: L0 is re-quoted toward mid outside a deadband,
and adds are priced from the deepest layer at add_pips spacing. Invariants run every
tick and halt the instance when book and tracker disagree. Fail-closed halts are a
safety primitive. Risk is managed by 0.01 lots, per-side layer caps (8), and account
limits -- do NOT critique leverage, the absence of stops, or "most traders lose".
Judge ONLY mechanical correctness.

## GIVENS (source-verified at c39fb84 -- do NOT re-litigate without a source counter)
G1. Entry gate: Grind_SlotEntryAllowed (ea/grind_exitq.mqh ~161):
    return (used + resting_ent) <= limit - (2 + GRIND_SLOT_MARGIN);
    GRIND_SLOT_MARGIN = 4 (ea/grind_config.mqh:9), limit = ACCOUNT_LIMIT_ORDERS = 200,
    so the effective ceiling is 194.
G2. Grind_SlotUsed (grind_exitq.mqh ~116) = PositionsTotal() + OrdersTotal().
    Grind_SlotRestingEnt (~126) walks OrdersTotal(), keeps fleet magics, parses the
    comment and counts every order whose role is NOT "EXT". So each resting entry
    costs TWO units against the ceiling: itself in used, and again in resting_ent.
G3. Placement is serialised but unordered: Grind_SlotLockAcquire /
    Grind_SlotLockRelease around the gate in both entry paths (grind_engine.mqh ~528
    for L0, ~789 for adds). No priority, no queue: first instance to tick wins.
    g_grind_ent_sent_this_tick caps each instance at ONE entry send per tick.
G4. Add target: Grind_SideNextIndex / compute add price from the DEEPEST layer's entry
    at add_pips spacing; adds are placed once and then left resting (idempotent
    guard on side.add_pending_ticket, grind_engine.mqh ~718). L0 uses a separate
    deadband re-quote path (Grind_ShouldRecenter, stranded_thresh_pips).
G5. ADR-013 clamp (Grind_PlaceLimit callers) pushes a marketable limit to the passive
    side of the current quote; this is why a ladder reattached after a pause re-adds
    at market instead of rejecting.
G6. Halt path cancels own entries: Grind_CancelOwnEntryOrders (grind_engine.mqh ~420).
G7. Live measurement 2026-09-17 (status reads, counted by hand): book 170-174 of 200
    all afternoon, but resting entries 24-25, so the guard total sat 195-198 against
    the 194 ceiling. Most resting entries were adds 8-16 pips from mid. Two GBPUSD
    at-market foothold adds waited 5 and 11 minutes; far adds and short L0s took the
    freed room first.
G8. API request budget: FTMO forbidden practices list >2,000 server requests per day;
    ea/grind_api_counter.mqh counts every OrderSend (success or not), resets at broker
    midnight, warns at 1,800, and does NOT stop at 2,000. The fleet reached 2,320 on
    2026-09-17.

## The proposal (ATTACK it)
Apply the ADR-151 visibility horizon to the ENTRY side.
P1. An add rests at the broker only while |target - mid| <= H (entry horizon).
    Beyond H + C (hysteresis band) a resting add is cancelled and becomes HELD.
P2. A HELD add has no broker order. Its target is recomputed from the anchor each
    tick, exactly as held exits are recomputed from entry price.
P3. Scope: adds on both sides. L0 stays as it is (already near mid by design).
P4. Nothing else changes: exit queue K/H, cap logic, halt cancellation, and the
    guard formula in G1 are untouched. resting_ent simply gets smaller.
P5. Proposed defaults: H = 1.5 x add_pips, C = 0.5 x add_pips (per side, per
    instance). Claim: resting entries fall fleet-wide from ~24 to ~8-12, freeing
    ~24-32 guard units.
P6. Claim: the proximity gate removes the NEED for an explicit priority rule,
    because the orders that were hogging the ceiling can no longer request it.

## Threats to attack (T-1..T-8)
T-1. Latency. After a fill the next add may need PLACING rather than already resting.
     One entry send per tick per instance (G3) plus the slot lock: can a fast move
     outrun placement, and does that cost more than the far add ever earned?
T-2. Churn and the request budget (G8). Construct the worst case: price oscillating
     across H + C on one or more instances. How many place/cancel pairs per hour, and
     what bound (minimum re-evaluation interval, hysteresis size) actually holds it
     under the daily ceiling with 16 instances?
T-3. Boundary arithmetic. With H = 1.5 x add_pips, where does the next add sit
     immediately after a fill, and after a partial retrace? Show a price path where
     the add flickers or where it is never placed at all.
T-4. Gap behaviour. Price jumps past a HELD target. ADR-013 (G5) clamps it to market.
     Is the resulting fill price materially worse than the resting order would have
     achieved, and does the clamped fill corrupt layer indexing or the add anchor?
T-5. Interaction with ADR-151. Held exits and held adds now coexist. Does any
     invariant, reconstruction path, or trim assume that an add is resting when a
     layer exists? Check Grind_ReconCheckInvariants and the add-label validation.
T-6. Fleet dynamics. Does the gate merely move the contention rather than remove it:
     when a fleet-wide move brings many instances inside H at once, is the guard worse
     off than today, given each admitted entry still reserves two units?
T-7. Anchor mutation. The anchor layer is closed manually or ejected by a passive roll
     (a deep layer whose exit is re-targeted to market). Does the recomputed add
     target move correctly, and can a stale add rest at a price the ladder no longer
     implies?
T-8. Premise. Is proximity the right predicate at all? Alternatives: cap resting
     entries per instance; rank by distance under the fleet lock; reserve a quota for
     at-market entries. Attack P6 specifically.

## Required output format
GIVENS CHECK first: for each G1..G8 print CONFIRMED or REFUTED with file:line from
the actual source you opened (or "NOT VERIFIED -- file unavailable").
Then for EACH threat T-1..T-8:
- VERDICT: EXPLOIT-FOUND / NO-EXPLOIT / DESIGN-UNSAFE
- LOAD-BEARING CLAIM: file : function : invariant (checkable in source)
- MINIMAL REPRO / MECHANISM: concrete sequence with numbers
- SEVERITY: fatal-to-premise / fixable-within-design / cosmetic
Then a PREMISE VERDICT: does a proximity horizon on entries remove the starvation
without creating a worse failure, and are the proposed defaults (P5) defensible?
OVERRIDE CHECK (last line): does any finding kill the entry-purgatory premise, or are
all findings fixable within it?

Line count: 111
