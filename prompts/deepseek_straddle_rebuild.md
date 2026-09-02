This message has a line count at the bottom.

# DeepSeek Phase 1 -- Teardown: Rebuild the Dumb Straddle on Proven Deadband Placement
# ADR-123 candidate. Replaces the g_straddle_ref_mid state machine (regressed twice).
# Source baseline: origin/main @ c7791af. You have READ access to ea/.

## Role
Phase 1 Red Team (adversarial quant). Write ZERO implementation code. Break the
proposed rebuild AND its premise against the ACTUAL source. Hunt mechanical failure
modes; you synthesize nothing.

## Frame (do NOT retail-judge)
Automated per-side market-maker on FTMO. Fail-closed halts are a safety primitive, not
a defect. No stop-losses; structural lot sizing IS the risk model. Do NOT critique
leverage, "most traders lose," or the absence of predictive signals. Judge ONLY the
mechanical correctness of L0 order placement.

## Background
The Dumb straddle (ENTRY_STRADDLE) posts a 2-leg L0 when flat: buy = mid - width,
sell = mid + width. Its bespoke placement state machine (g_straddle_ref_mid + band +
goalpost + cooldown) has regressed TWICE live: one-legged persistence (ADR-121) and
perpetual cancel/replace churn of the resting leg (ADR-122 patch). The SIGNAL arm and
the grid add/reload path ran 500+ trades over two weeks without churning, using a
DIFFERENT, proven mechanism. Proposal: delete the ref_mid machine and rebuild the
straddle on that proven mechanism.

## GIVENS (source-verified at c7791af -- do NOT re-litigate without a source counter)
G1. Proven anti-churn = per-ORDER DEADBAND. V2_L0RestingWithinDeadband
    (logic.mqh:521): true iff a resting order exists AND
    |new_price - resting_price| < deadband. Deadband = V2_L0RequoteDeadband =
    multiplier * (quote_spread*0.25 - 0.5*point), vol-scaled by pair spread. When
    true the caller SKIPS the re-quote (leaves the resting order).
G2. The guard is gated to ENTRY_SIGNAL ONLY. Long_ReplacePendingBuy:
    if(InpEntryMode == ENTRY_SIGNAL && V2_L0RestingWithinDeadband(...)) return false;
    then Long_CancelTicket + Long_PlaceBuyLimit. So ENTRY_STRADDLE BYPASSES the
    deadband -> unconditional cancel-then-place on every call. This bypass is the root
    of both straddle regressions.
G3. Proven idempotent placement: Long_EnsureAddNext -- if(add_ticket != 0 &&
    OrderSelect(add_ticket)) return; -- an already-resting order is left untouched.
G4. Current straddle machine (post-ADR-122 V2_StraddleL0OnTick): staleness guard ->
    flat checks -> mid + V2_DumbShouldRePlace(g_straddle_ref_mid) -> ref_established ->
    per-leg V2_StraddleLegShouldAttempt(live, drifted, ref_established) -> cooldown ->
    marketability -> Long/Short_ReplacePendingBuy/Sell -> goalpost advances ref_mid
    only when both legs live.
G5. g_straddle_ref_mid has NO consumer outside V2_StraddleL0OnTick (engine.mqh: decl
    :24; uses :110/:112/:171). Safe to drop.
G6. KEPT in the rebuild: the ADR-122 feed staleness guard (V2_IsFeedStale at the top
    of the tick) and the pre-send marketability skip (buy < ask / sell > bid).

## The proposed rebuild (ATTACK it)
Replace the ref_mid state machine with proven per-order deadband placement:
- Remove the `InpEntryMode == ENTRY_SIGNAL &&` gate so the deadband applies to the
  straddle too (signal arm unchanged -- it already had it).
- V2_StraddleL0OnTick, per FLAT leg each tick: compute the target (mid +/- width,
  Adr013-clamped); call the Replace helper, which now internally SKIPS when the resting
  order is within deadband (no churn) and places when missing or drifted beyond it.
- DROP g_straddle_ref_mid, V2_DumbShouldRePlace usage, V2_StraddleLegShouldAttempt, the
  goalpost, ref_established, and the per-side cooldown (deadband subsumes anti-churn).
- KEEP the staleness guard and the marketability skip.
Claim: idempotent per-leg placement fixes BOTH one-legged persistence (a missing leg
is always placed) AND churn (a resting leg within deadband is left alone), reusing code
proven over 500+ trades.

## Threats (spend effort here)
### T-1 [PRIMARY] -- Leg symmetry / warp
Attack the concern that per-leg placement lets the legs drift off a shared anchor.
Construct a tick sequence where buy and sell end up asymmetric beyond the deadband
(e.g. one leg re-quotes on drift while its partner sits within deadband). Is asymmetry
bounded by the deadband, or can it accumulate / walk over many ticks?
### T-2 -- Rejection retry interaction
On a live feed a transiently-rejected leg leaves ticket=0. Next tick deadband(0)=not
within -> attempt again. Does this retry churn the GOOD leg, spam the broker, or
interact badly with the marketability skip? Is a retry backoff still required once the
ref_mid cooldown is dropped?
### T-3 -- Deadband sizing vs straddle width
Deadband = quote_spread*0.25*mult (vol-scaled); width = InpDumbStraddlePips. Attack the
regimes: width small vs deadband (never re-quotes, straddle frozen wide) and deadband
tiny (churn returns). Where does the sizing break?
### T-4 -- Removing the ENTRY_SIGNAL gate
Prove or refute that dropping `InpEntryMode == ENTRY_SIGNAL &&` is ZERO behavior change
for the signal arm and that no path depends on the straddle bypassing the deadband.
### T-5 -- flat -> filled grid handoff
When an L0 leg FILLS (side no longer flat), the straddle stops quoting that side and
the grid (Long_EnsureAddNext / adds) takes over. Attack the transition under the new
placement: stale l0_ticket, double-management, orphaned pending, exit-ticket confusion.
### T-6 -- Feed recovery
After the staleness guard lifts (feed returns live), does the deadband placement
re-sync cleanly, or burst-churn reconciling resting orders against the jumped mid?

## Negative space
No implementation code. No re-litigating G1-G6 without a concrete source-grounded
counterexample from ea/. No retail judgment. Every claimed exploit needs a minimal
concrete tick / fill / reject / reattach sequence, not an assertion.

## Required output format
For EACH threat T-1..T-6:
- VERDICT: EXPLOIT-FOUND / NO-EXPLOIT / DESIGN-UNSAFE
- LOAD-BEARING CLAIM: file : function : invariant (checkable in source)
- MINIMAL REPRO / MECHANISM: concrete sequence
- SEVERITY: fatal-to-premise / fixable-within-design / cosmetic
Then a PREMISE VERDICT: does the proven deadband pattern port cleanly to the 2-leg
straddle, or does the straddle need something the signal arm did not?
OVERRIDE CHECK (last line): does any finding kill the deadband-rebuild premise, or are
all findings fixable within it?

Line count: 106
