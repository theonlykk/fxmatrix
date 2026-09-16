This message has a line count at the bottom.

# DeepSeek Phase 1 -- Teardown: Order Purgatory REV 3 (exit queue)
# ADR-151 candidate. Full memo appended below this brief by the runner.
# Source baseline: fxmatrix origin/main at or after e83b52f. EA files appended below.

## Role
Phase 1 Red Team (adversarial). Write ZERO implementation code. Break the rev 3
design and its premise against the ACTUAL source appended below. You find; you
do not rule.

## Frame (do NOT retail-judge)
fxgrind is a passive limit-order market maker on MT5. Fourteen EA instances
share ONE FTMO demo account (hedging), separated by magic number. It never
crosses the spread and never uses stop losses. Per side an instance holds a
ladder of layers; each layer is one position plus one exit limit priced at
entry +/- exit_pips (+ a persisted carry shift) at fill time. L0 is placed once
when a side is flat (ADR-123); adds are priced from the deepest layer. An exit
fill opens an opposite position that the EA nets with CloseBy. Invariants
rebuild the book from broker tickets every tick; failure quarantines (3000 ms
minimum, 3 checks) then halts. Do NOT critique leverage, stops or signals.

## Background
The account limit (200) counts positions + pending orders. At 200 the exit
placed after a fill is refused (10040), the layer goes naked, the instance
halts. Rev 1 (flat slot reserve, fleet eviction) was torn down by you; see the
memo s7 for dispositions. Rev 3 changes the mechanism: most resting exits on a
ladder cannot fill until the nearer exits fill first, so only the K nearest
exits per side rest; the rest wait and are released as the front ones fill.

## GIVENS (source-verified; do NOT re-litigate without a source counterexample)
G1. `Grind_ReconCheckInvariants` (grind_recon.mqh ~394) requires, for EVERY
    layer: a position (I3 no_position), exit coverage via
    `Grind_ReconLayerHasExitCoverage` (~364, order OR filled exit position;
    I3 no_exit_coverage), an exit price matching entry +/- exit_pips + carry
    shift (I6; a favourable price is tolerated only when the exit is FILLED,
    `Grind_ReconExitMatchesEntry` ~343), and exactly one exit (I1 ~480-520).
    I7 depth > max_layers and I5 duplicate/negative indices are also here.
G2. `Grind_CheckBookInvariants` (~1108) rebuilds from broker tickets each
    tick; it never compares against the in-memory tracker.
G3. `Grind_HandleSideDealFill` (grind_engine.mqh ~833) places the exit for a
    layer immediately on its ENT fill; on an EXT fill it queues CloseBy;
    `OnTick` processes CloseBy queues first (fxgrind.mq5 ~228).
G4. `Grind_TryPlaceExitForLayer` (~514) places at `layer.exit_target` with no
    marketability clamp. Entries use ADR-013 clamps (`Grind_Adr013ClampBuy`,
    `Grind_Adr013ClampSell`).
G5. `Grind_CancelPendingOrder` (~356) returns true only on TRADE_RETCODE_DONE.
    `Grind_EnsureAddNext` clears its tracker only on true or confirmed-gone.
G6. `Grind_CarryShiftGetForRecon` (grind_carry.mqh ~547) returns a validated
    per-position shift from persisted state, keyed by position id.
G7. Halted instances ignore fills (`Grind_OnTradeTransactionEngine` ~1161).
    `OnTimer` (fxgrind.mq5 ~206) runs no trading logic.
G8. Quarantine: GRIND_QUARANTINE_MIN_MS 3000, MIN_CHECKS 3; I3 quarantinable,
    I7 and I5 not.

## The proposed design (ATTACK it)
D1. Per side, rank layers by exit target nearest to market (longs ascending,
    shorts descending), carry shift included. Recomputed from broker book
    every tick and after reinit; no held-exit state only in memory.
D2. Ranks 1..K MUST have a live exit; K+1..K+H MAY; beyond K+H MUST NOT.
D3. Release: when a layer reaches rank <= K without a live exit (front exit
    filled and netted, or a new deeper layer), place its exit in that event.
D4. Hold: when a live exit falls beyond K+H, cancel it; clear the tracker only
    on confirmed cancel or confirmed gone.
D5. Gap release: if the target is already through the market, clamp passive
    (long at max(target, bid+stops), short at min(target, ask-stops)); I6 must
    tolerate a favourable RESTING exit.
D6. Invariants: I3 exit coverage only for ranks 1..J, J = max(1, K-1); I1 only
    for layers that have an exit; I6 only for layers with an exit; new soft I9
    for a live exit beyond K+H (engine cancels, never halts).
D7. Guard: exits allowed when free >= 1; entries when free >= 2 + margin;
    blocked entries deferred with zero sends; ENT 10040 defers.
D8. Carried: retry missing exits before L0 placement; halt (both paths)
    cancels own ENT; no fleet flag.
D9. Transition: legacy books with every exit resting are legal (extra exits
    are ranks beyond K+H) and trimmed by the engine.
Capacity claim (memo s3): 2N x (P + K + H + 1) <= 200 - margin bounds the
fleet in the worst one-sided case.

## Threats (attack each)
T-1 INVARIANT RELAXATION. Can a genuinely lost exit hide under D6 (a near
    layer mis-ranked, carry shift reordering ranks, equal exit prices)?
T-2 RANKING. Ties, carry shifts that change order overnight, a layer whose
    exit filled but is not yet netted: is D1 well-defined every tick?
T-3 RELEASE TIMING. Front exit fills; CloseBy nets on a later tick. Between
    fill, netting and release, does any invariant fail beyond quarantine?
T-4 HOLD CANCEL. Cancel racing a fill of that exit; cancel non-DONE; release
    of a still-live exit producing two EXT orders for one layer (I2 halt?).
T-5 GAP CLAMP. Does D5 ever cross, get rejected, or leave I6 failing? Several
    exits released at one clamped price?
T-6 HYSTERESIS. Construct a price path that churns cancel/place despite H.
T-7 CARRY PASS. The nightly carry pass shifts exit prices. What happens to
    held exits, and to ranks, across a carry pass?
T-8 RECONSTRUCTION. Reinit on a legacy full-exit book, on a held book, and
    on a book where held exits' positions have closed manually.
T-9 CAPACITY FORMULA. Is P + K + H + 1 per instance a true worst case? Find
    a reachable state exceeding it (two-sided, halted instances, CloseBy lag,
    deferred releases).

## Negative space
No implementation code. No re-litigating G1-G8 without a concrete source
counterexample from the appended files. No retail judgment. Every
EXPLOIT-FOUND needs a concrete tick / fill / cancel / netting sequence. Do not
propose remedies the EA cannot execute.

## Required output format
For EACH threat T-1..T-9:
- VERDICT: EXPLOIT-FOUND / NO-EXPLOIT / DESIGN-UNSAFE
- LOAD-BEARING CLAIM: file : function : invariant (checkable in source)
- MINIMAL REPRO / MECHANISM: concrete sequence
- SEVERITY: fatal-to-premise / fixable-within-design / cosmetic
Then GIVENS CHECK: any of G1-G8 inaccurate, with file and function.
Then PREMISE VERDICT: does a K-nearest exit queue with the capacity formula
solve the observed failures?
OVERRIDE CHECK (last line): does any finding kill the premise, or are all
fixable within it?

Line count: 118
