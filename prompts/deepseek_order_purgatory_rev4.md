This message has a line count at the bottom.

# DeepSeek Phase 1 -- Focused teardown: Order Purgatory REV 4
# ADR-151 candidate. Full rev 4 memo and EA source appended below by the runner.
# You tore down rev 1 and rev 3; memo s7 records how each finding was handled.

## Role
Phase 1 Red Team (adversarial). Write ZERO implementation code. Attack ONLY
what changed in rev 4 (listed below) against the ACTUAL appended source. Do
not re-raise a rev 1 or rev 3 finding unless rev 4's fix for it fails; if so,
say which fix and why.

## Frame (do NOT retail-judge)
fxgrind is a passive limit-order market maker on MT5. Fourteen EA instances
share ONE FTMO demo account (hedging), separated by magic. Never crosses the
spread; no stop losses. Per side a ladder of layers; each layer is one position
plus one exit limit at entry +/- exit_pips, optionally shifted by accrued carry.
An exit fill opens an opposite position netted by CloseBy. Invariants rebuild
the book from broker tickets every tick; failure quarantines (3000 ms, 3
checks) then halts. Do NOT critique leverage, stops or signals.

## Rev 4 in brief
Only the K nearest exits per side rest (ranked by ENTRY price, longs ascending,
shorts descending, ties by layer_index); ranks K+1..K+H may rest; beyond K+H
are held and released as front exits fill and net. Exits are allowed at
free >= 1; entries only at free - resting_ENT >= 2 + margin.

## GIVENS (source-verified at 9f67f0f; do NOT re-litigate without a source counterexample)
G1. `Grind_ReconEnsureLayer` (grind_recon.mqh ~310-325) initialises
    `exit_target = 0.0`; the rebuild copies `exit_target` from the exit
    order or exit position price (~852-919) and into the output (~1015).
G2. `Grind_AppendLayer` (grind_engine.mqh ~558) stores
    `Grind_ExitPrice(entry, exit_pips, _Point, dir)` (grind_pure.mqh ~91),
    no carry.
G3. `Grind_CarryExitShiftLayer` (grind_carry.mqh ~800): reads the position's
    swap ledger, computes accrued pips and a theoretical price via
    `Grind_CarryShiftedExitPrice` (~381), applies `Grind_CarrySignGuardBlocks`
    (~421), clamps with `Grind_CarryClampLongExit`/`ShortExit` (~439/~457:
    long to ask + min passive distance, short to bid - min), modifies the
    exit order, then stores `applied = new_exit - formula` with
    `Grind_CarryShiftSet` (~490).
G4. `Grind_CarryShiftGetValidated` (~522) deletes and returns 0 for a stored
    shift that fails `Grind_CarryShiftWithinBound`.
    `Grind_CarryShiftGetForRecon` (~547) calls it for I6.
G5. `Grind_CarryExitPassBegin` (~736) includes only layers with
    `exit_order_ticket != 0` (~752, ~760).
G6. `Grind_ReconExitMatchesEntry` (grind_recon.mqh ~343) tolerates a
    favourable price only when the exit is FILLED.
G7. `Grind_CancelPendingOrder` (grind_engine.mqh ~356) returns true only on
    TRADE_RETCODE_DONE. `Grind_HandleSideDealFill` (~833) queues CloseBy on
    an EXT fill; halted instances skip it (~1161).
G8. I3 is quarantinable; I5 and I7 are not (grind_quarantine.mqh).

## What changed in rev 4 (ATTACK these)
C1. One exit-price function `target(layer)`: formula + carry computed from the
    position's swap ledger as G3 does, sign guard applied. Reconstruction must
    populate `exit_target` for held layers from it (never 0.0).
C2. On release at price X, store applied shift X - formula via
    `Grind_CarryShiftSet`, so I6 validates against it.
C3. Ranking by entry price with index tie-break (carry never reorders).
C4. Hold cancel: DONE -> clear; not-DONE and live -> keep, retry; not-DONE
    and gone -> find an EXT position for this magic and layer index -> set
    exit_position_ticket and queue CloseBy; else clear.
C5. Gap release clamp against target(layer) with the G3 clamps; open point:
    a large clamp may store a shift that fails the G4 bound.
C6. Carry pass unchanged; held layers get carry at release from the ledger.
C7. I3 coverage for ranks 1..K, rank K hard; I1 and I6 only for layers with
    an exit; soft I9 for live exits beyond K+H.
C8. Commitment guard: exits at free >= 1; entries at free - resting_ENT >= 2 +
    margin; one ENT send per instance per tick; resting_ENT counts parsed ENT
    comments of any magic.

## Threats (attack each)
T-1 TARGET PARITY. Can `target()` at release differ from what I6 later
    expects (ledger changes between release and next rebuild, sign guard
    flips, validated-shift deletion per G4)? Construct the halt.
T-2 SHIFT BOUND. With C2 and C5, find a reachable release whose stored shift
    fails `Grind_CarryShiftWithinBound`. What does I6 then do? Is it fatal or
    fixable by exempting release shifts or relaxing I6 for resting exits?
T-3 RANK BY ENTRY. Can entry order disagree with live exit price order in a
    way that makes a held exit fillable-but-absent, or a live exit unreachable
    for long periods, beyond memo s10's stated risk?
T-4 RECON FOR HELD LAYERS. Reinit: does populating exit_target from C1 need
    data not available at reconstruction (position swap unavailable, symbol
    info not ready, magic lock)? Any path that still yields 0.0?
T-5 HOLD CANCEL (C4). Does the confirmed-gone search mis-identify the EXT
    position (OPT/ALT arms on the same symbol, CloseBy already done, comment
    truncation)? Double CloseBy? 
T-6 RANK-K HARD (C7). Front exit fills; netting on next OnTick; release in
    which event exactly? Construct a sequence where rank K stays uncovered
    past 3000 ms / 3 checks on a quiet symbol (OnTimer does no trading).
T-7 COMMITMENT GUARD (C8). Conservation through place / fill / exit / fill /
    CloseBy / release / hold / halt-cancel. Find a transition that breaks it,
    or a race larger than a plausible margin (6-14) given one ENT send per
    instance per tick.
T-8 TRANSITION. First deploy on today's book (every exit live, 200 used,
    ~20 ENT resting). Trimming order, guard state, any halt during trim.

## Negative space
No implementation code. No re-litigating G1-G8 without a source
counterexample. No retail judgment. Every EXPLOIT-FOUND needs a concrete
tick / fill / cancel / netting sequence. Do not propose remedies the EA cannot
execute. Do not declare the premise dead for an issue you rate
fixable-within-design.

## Required output format
For EACH threat T-1..T-8:
- VERDICT: EXPLOIT-FOUND / NO-EXPLOIT / DESIGN-UNSAFE
- LOAD-BEARING CLAIM: file : function : invariant (checkable in source)
- MINIMAL REPRO / MECHANISM: concrete sequence
- SEVERITY: fatal-to-premise / fixable-within-design / cosmetic
- IF FIXABLE: the smallest change that fixes it (design level, no code)
Then GIVENS CHECK: any of G1-G8 inaccurate, with file and function.
Then REV 3 FIXES CHECK: for rev 3 T-1, T-2/T-8, T-4, T-5, T-6, T-7, T-9 --
does rev 4's fix hold? One line each.
Then PREMISE VERDICT.
OVERRIDE CHECK (last line): does any finding kill the premise, or are all
fixable within it?

Line count: 120
