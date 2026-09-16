This message has a line count at the bottom.

# DeepSeek Phase 1 -- Teardown: Order Purgatory (account slot budget, exit priority)
# ADR-151 candidate. Design memo: docs/architecture/MEMO_2026-09-16_order_purgatory.md
# Source baseline: fxmatrix origin/main (see courier for commit). You have READ access to ea/.

## Role
Phase 1 Red Team (adversarial). Write ZERO implementation code. Break the proposed
design and its premise against the ACTUAL source. Hunt mechanical failure modes in the
order lifecycle. You find; you do not rule.

## Frame (do NOT retail-judge)
fxgrind is a passive limit-order market maker on MT5. Fourteen EA instances share ONE
FTMO demo account (hedging), separated by magic number. It never crosses the spread and
never uses stop losses. Per side an instance holds a ladder of layers; each layer is one
position plus exactly one resting exit limit, priced at entry +/- exit_pips at fill time.
L0 is placed once when a side is flat (ADR-123); the flat side's L0 is re-centred only
while the other side holds layers (ADR-124). Adds are priced from the deepest layer at
add_pips. An exit fill opens an opposite position that the EA nets with CloseBy.
Invariants run every tick; a failure quarantines (3000 ms minimum, 3 checks) then halts.
A halted instance stops trading but keeps observing. Do NOT critique leverage, stops or
signals. (This frame supersedes ARCHITECT s1, whose L0 sentence is stale.)

## Background -- observed 2026-09-16
The account limit ACCOUNT_LIMIT_ORDERS=200 counts positions + pending orders combined
(read directly: positions=81 orders=113 at the first refusals). At 200 the terminal
refuses new orders locally (retcode 10040, duration_ms=0). Because a fill turns an
order into a position, the EXIT placed after a fill is the refused order. Result: I3
naked layer, quarantine cannot outlast the limit, halt. Twelve halt events in one
evening. Halted instances' resting entries kept filling as untracked positions. Refused
sends retried every tick drove the fleet request counter from 822 to 3,414 in 23 min.
Reinit into a full book re-halted within minutes (3 of 3).

## GIVENS (source-verified; do NOT re-litigate without a source counterexample)
G1. Entry gates: Grind_TryPlaceL0 (grind_engine.mqh ~449) and Grind_EnsureAddNext
    (~636, gates at ~677-679) check Grind_CanPlaceEntryLayer and Grind_CapAllowsEntry.
    Neither checks account capacity.
G2. Grind_HandleSideDealFill (~833): on an ENT fill, appends the layer and calls
    Grind_TryPlaceExitForLayer immediately. On an EXT fill it queues CloseBy.
G3. Grind_OnTickEngine (~1026) order: ReconcileStrayL0, L0 placement, ADR-124 recentre,
    cap transition, Grind_RetryMissingExits, then EnsureAddNext. A missing exit is
    retried AFTER L0 placement in the same tick.
G4. OnTick (fxgrind.mq5 ~226): ProcessCloseByQueues; if not halted, invariants +
    Grind_QuarantineStep; on HALT sets g_grind_halted directly. If quarantined, runs
    ONLY Grind_RetryMissingExits (when guards allow) and returns.
G5. Grind_HaltCritical (grind_engine.mqh ~376) is a second halt entry point. Neither
    halt path cancels orders.
G6. Grind_OrderSendCounted (grind_api_counter.mqh ~76) increments the request counter
    on every OrderSend, including locally refused sends.
G7. Grind_ReconCheckPendingAddCorrupt (grind_recon.mqh ~370): I8 halt if
    add_pending_ticket is non-zero and the order is not found as an order.
G8. Quarantine constants: GRIND_QUARANTINE_MIN_MS 3000, MIN_CHECKS 3
    (grind_quarantine.mqh ~13-14). I3 naked reasons are quarantinable; I7 is not.

## The proposed design (ATTACK it)
D1. Capacity read each decision: free = ACCOUNT_LIMIT_ORDERS - PositionsTotal() -
    OrdersTotal(). Terminal-local, no server request. Limit 0 disables the budget.
D2. Budget: EXIT sends allowed when free >= 1. ENT sends (L0, add) allowed only when
    free > InpSlotReserve (new input, plausible 10-16). Modify, cancel, CloseBy always
    allowed.
D3. Purgatory: a budget-blocked entry is not sent; it is marked deferred and
    re-evaluated on later ticks using the existing target logic. Zero sends while
    deferred.
D4. Exit refused with 10040 anyway (race): cancel this instance's own resting ENT
    furthest from market (add before L0), clear its tracker ticket, re-send the exit.
    If the instance has no resting ENT, set GlobalVariable GRIND_SLOT_STARVED with a
    timestamp; every instance seeing a fresh flag withdraws its own furthest ENT and
    defers it; flag clears when free > InpSlotReserve.
D5. Quarantine unchanged (memo option (a)).
D6. On halt (BOTH entry points G4, G5): cancel own resting ENT orders, never EXT.
D7. Move Grind_RetryMissingExits before L0 placement in Grind_OnTickEngine.
D8. Reinit: no special path; entries after reconstruction pass the budget.
D9. Any 10040 on an ENT send marks it deferred instead of retrying next tick.
Claim: exits are never refused for capacity except in an unbounded simultaneous burst;
halts from capacity stop; request storms stop; reinit into a full book is stable.

## Threats (attack each)
T-1 RACE. Fourteen instances read the same free in the same tick. Construct the worst
    burst in which the reserve is exhausted and an exit is still refused. Is D4 enough?
T-2 COUNT CORRECTNESS. Can PositionsTotal()+OrdersTotal() disagree with what the
    terminal enforces (in-flight sends, orders being filled, the CloseBy transient,
    manual orders)? Does anything in D1 depend on ACCOUNT_LIMIT_ORDERS semantics that
    the MT5 docs describe differently (pending only)?
T-3 EVICTION STATE MACHINE. Cancelling an add or L0 mid-life: I8 (G7), stray-L0
    reconcile, ADR-124 recentre, EnsureAddNext re-place, cancel racing a fill. Find a
    sequence that halts, double-places, or leaves an untracked order.
T-4 FLEET FLAG. GRIND_SLOT_STARVED: staleness, crashed writer, oscillation (all
    withdraw, free rises, all re-place, free falls) and its request cost. Livelock?
T-5 HALT CANCELS ENTRIES. Cancel racing a fill on a halted instance; cancelling when
    the halt reason means the tracker is untrustworthy (I5, I8); effect on the next
    reconstruction.
T-6 TICK REORDER (D7). Any invariant, recentre or stray-L0 interaction broken by
    retrying exits first?
T-7 QUARANTINE TIMING. With D5 unchanged, can D4 eviction (cancel then re-send across
    ticks) land the exit inside 3000 ms / 3 checks on a slow symbol? If not, quantify.
T-8 DEFERRED ENTRY VS EXISTING LOGIC. Does any invariant, cap transition, telemetry
    field or reconstruction step assume an entry is resting whenever it "should" be?
T-9 REQUEST COST. Is D3 truly zero-send while deferred? Any path (recentre MODIFY,
    stray cancel) that still sends every tick at a full book?

## Negative space
No implementation code. No re-litigating G1-G8 without a concrete source counterexample
from ea/. No retail judgment. Every EXPLOIT-FOUND needs a concrete tick / fill /
refuse / cancel sequence, not an assertion. Do not propose remedies the EA cannot
execute (no databases, no external services).

## Required output format
For EACH threat T-1..T-9:
- VERDICT: EXPLOIT-FOUND / NO-EXPLOIT / DESIGN-UNSAFE
- LOAD-BEARING CLAIM: file : function : invariant (checkable in source)
- MINIMAL REPRO / MECHANISM: concrete sequence
- SEVERITY: fatal-to-premise / fixable-within-design / cosmetic
Then GIVENS CHECK: list any of G1-G8 you found inaccurate, with file and line.
Then PREMISE VERDICT: does an exit-priority slot budget solve the observed failures?
OVERRIDE CHECK (last line): does any finding kill the premise, or are all fixable
within it?

Line count: 118
