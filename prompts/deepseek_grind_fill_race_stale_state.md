This message has a line count at the bottom.

# DeepSeek Phase 1 -- Narrow Teardown: Fill-Transition Race and Stale-State Defects (fxgrind)

## Role

Phase 1 Red Team (adversarial). **Write ZERO implementation code.**
You have READ access to ea/ (main @ `0e5dbf1`). Open the cited source before answering.
Every claim you make must cite file and function; do not reason from this
description alone.

## Frame (do NOT retail-judge)

- fxgrind is a MARKET MAKER, not a directional strategy.
- It rests PASSIVE LIMIT ORDERS only. It never crosses the spread, never lifts
  offers or hits bids.
- There are NO STOP LOSSES. Inventory is managed by exit limits, CloseBy,
  per-side layer caps and an account-level daily loss gate.
- The edge is spread capture and mean reversion of inventory, not forecasting
  direction.
- Critiques of win rate, stop placement, risk:reward or signal quality are OUT
  OF SCOPE and will be discarded.
- Safety semantics: invariants FAIL CLOSED (halt in place). A halt is permanent
  until an operator reattaches the EA.
- Account is an FTMO demo, 0.01 lots per layer, twelve instances in one MT5
  terminal (hedging account).

## GIVENS (source-verified at `0e5dbf1` -- do NOT re-litigate)

G1. `OnTick` (ea/fxgrind.mq5 ~180) runs, in order: `Grind_ProcessCloseByQueues`;
    then, if not halted, `Grind_CheckBookInvariants` (halt on failure); then
    returns if halted; then `Grind_OnTickEngine`.
G2. `Grind_OnTradeTransactionEngine` (ea/grind_engine.mqh ~985) returns
    immediately when `g_grind_halted` is true. A halted EA therefore ignores
    every later fill, including exit fills that should queue a CloseBy.
G3. `Grind_CheckBookInvariants` rebuilds state from the BROKER BOOK ONLY
    (positions and orders, by comment). It never compares against the EA's
    in-memory tracker. I3 (ea/grind_recon.mqh ~215-245) fires when a layer has
    no entry position, or has neither an exit order nor an exit position.
G4. `OrderSend` is synchronous (ea/grind_api_counter.mqh
    `Grind_OrderSendCounted`). Journal "done in" times on 2026-09-10,
    14:16-14:36 UTC, across 13 sends: 9.9 s to 51.7 s. While a send blocks, no
    other event handler runs; ticks and trade transactions queue.
G5. `Grind_TryPlaceL0` (grind_engine.mqh ~415): if the tracked L0 pending cannot
    be selected, it zeroes the ticket and places a NEW L0 in the same call. It
    cannot distinguish filled from cancelled. `Grind_EnsureAddNext` (~569) does
    the same for the add pending.
G6. ENT branch of `Grind_HandleSideDealFill` (~841-852): clears
    `l0_pending_ticket` / `add_pending_ticket` only if the deal's order ticket
    matches; appends the layer; then looks the layer up with
    `Grind_FindLayerByIndex(side, c_layer)` and calls
    `Grind_TryPlaceExitForLayer`, which overwrites `exit_order_ticket`
    unconditionally (~449).
G7. Reconstruction (grind_recon.mqh ~655-690) adopts a single resting L0
    pending or add pending per side without checking the side's depth. Two of
    either halts with AMBIGUOUS_*.
G8. ADR-127 (e486bb9) fixed CloseBy OUT_BY deals being consumed by the wrong
    side. Confirmed live 2026-09-11. Out of scope here.
G9. On reattach, reconstruction derives CloseBy pairs for layers whose exit has
    filled (`Grind_DeriveCloseByQueueFromBook`, grind_closeby.mqh ~268; test
    T53). Confirmed live 2026-09-11 12:14:08 UTC.

## Motivating incidents (log evidence)

### Incident A -- duplicate L0 and duplicate exit, EURUSD_OPT, 2026-09-10 (UTC)

    14:25:17.708  EA sends modify on its long L0 #539505969
    14:25:45.174  short L0 #538969489 FILLS at 1.16231
    14:26:09.431  modify returns "done in 51722 ms"
    14:26:09.431  NEW short L0 sent at 1.16277 (same millisecond)
    14:26:34.920  exit for the 1.16231 layer sent
    14:26:46.073  L01 add sent at 1.16371
    14:31:57      recompile of all instances; stray L0 adopted by reconstruction
    14:35:50.738  stray #539592770 FILLS at 1.16282 (second S|L00|ENT)
    14:35:50.739  exit sent at 1.16161 -- the FIRST layer's price
    14:36:58      I5_SHORT_DUP halt; two S|L00|EXT orders at 1.16161, the
                  1.16282 position has no exit

### Incident B -- transient I3 halt, AUDCHF_ALT, 2026-09-11 (UTC)

    10:35:40.980  CRITICAL invariant fail, I3_LONG_NAKED, instance halts
    10:35:41.071  Journal logs the long L00 exit fill (deal #517766886, sell
                  0.58451, order #539366231) -- 91 ms AFTER the halt
    later         no CloseBy (G2); a short L03 fill at 11:17:15 UTC ignored,
                  left with no exit

Four earlier I3 halts (2026-09-10) share this signature: fills in dense-tick
periods, twin instances filling the same price in the same second with only
one halting.

## The proposal to attack

**P1 -- Invariant quarantine before halt.**
When `Grind_CheckBookInvariants` fails with I3_* (and possibly I4_*), do not
halt. Enter QUARANTINE: skip `Grind_OnTickEngine` (no new orders, modifies or
cancels) but keep processing trade transactions and the CloseBy queue.
Re-check on every tick. If the book passes, leave quarantine. If the same
failure persists for at least GRACE_MS (proposed 3000 ms, measured with a
local monotonic clock) AND at least one trade-transaction or timer cycle has
run since it was first seen, halt as today. All other invariants halt
immediately, unchanged.

**P2 -- Filled vs cancelled before re-quoting.**
In `Grind_TryPlaceL0` and `Grind_EnsureAddNext`, when the tracked pending
cannot be selected: look it up in order history.
- FILLED or PARTIAL: keep the ticket, place nothing; the fill's transaction
  will append the layer and clear it.
- CANCELED, EXPIRED or REJECTED: clear and proceed as today.
- Not yet in history: keep the ticket and place nothing this tick; retry on
  later ticks. (Bound and fallback to be determined.)

**P3 -- Exit placement targets the new position, not the index.**
In the ENT branch, place the exit for the layer just appended (by position
ticket or its array slot), never via `Grind_FindLayerByIndex`.
`Grind_TryPlaceExitForLayer` refuses to overwrite a non-zero
`exit_order_ticket`. If an ENT fill carries a layer index already present on
that side, first place a protective exit for the NEW position, then halt with
I5_*_DUP (so the halt leaves no naked position).

**P4 -- Stray pending reconciliation.**
- Engine: a side with depth > 0 must not hold an L0 pending; cancel it. A side
  with depth 0 must not hold an add pending; cancel it.
- ENT branch: an L0 fill on a side whose tracked `l0_pending_ticket` is a
  different ticket cancels that tracked pending immediately.
- Reconstruction: do not adopt an L0 pending on a side with layers, or an add
  pending on an empty side; cancel instead.

## Threats / questions (spend effort here)

### T-1 -- PRIMARY: does P1 mask a real naked position or fail to absorb transients?

(a) Construct a sequence where a GENUINELY naked position (exit OrderSend
failed, or was never attempted) stays in quarantine indefinitely and is never
halted. Consider repeated flip-flopping between pass and fail.
(b) Construct a sequence where a legitimate transition still halts despite
P1. Consider: a 50 s blocking send (G4) followed by a burst of queued events;
a CloseBy where the terminal removes one leg before the other (I3 via
"no entry position"); ENT visible before its transaction.
(c) Is GRACE_MS the right primitive, or should the release condition be
event-based (e.g. "a DEAL_ADD for the offending ticket has been processed")?
(d) Should quarantine freeze only the affected side, or the whole instance?

### T-2 -- P2 history lookup

(a) Can "not yet in history" persist long enough to stall quoting on a side?
What bound and fallback avoid both a stall and a duplicate?
(b) Partial fills: is a PARTIAL state reachable at 0.01 lots, and if so what
does P2 do?
(c) Incident A's L0 #538969489 was modified to 1.16244, completed at
14:17:21 UTC, and filled at 1.16231 at 14:25:45 UTC: a sell limit filling
1.3 pips BELOW its price. Does any modify-versus-fill race undermine P2's
state classification?

### T-3 -- P3 and P4 under racing fills

(a) Construct a sequence where P4's cancel races the stray order's own fill.
What state results, and do P3's protective exit and halt leave the book
covered?
(b) After P3 places a protective exit and halts, does reconstruction on
reattach accept that book, or halt again (I5_*_DUP on reload)? What should the
operator do?

### T-4 -- legitimate states P4 would destroy

Search the source for any legitimate path where an L0 pending coexists with
layers on the same side, or an add pending exists on an empty side (for
example `Grind_TryRecenterOppositeL0`, cap transitions, stranded threshold,
the moment between a fill and its transaction). If one exists, P4 as written
is unsafe.

### T-5 -- governance rule

Standing rule: an invariant and a reconciler must never target the same
condition. Do P1 (quarantine on I3) and P4 (reconciling pendings) violate it,
directly or through I8_CORRUPT_PENDING_ADD?

## Negative space

- Do NOT write implementation code.
- Do NOT re-litigate G1-G9 without citing source that contradicts them.
- Do NOT judge by retail metrics (see Frame).
- Do NOT propose asynchronous order sending as the fix for this round; you may
  state whether P1-P4 remain sound if sends later become asynchronous.
- Every exploit needs a minimal repro: an ordered sequence of ticks, trade
  transactions, broker events and handler calls.

## Required output format

For EACH threat T-N:
- **VERDICT:** EXPLOIT-FOUND / NO-EXPLOIT / DESIGN-UNSAFE
- **LOAD-BEARING CLAIM:** file / function / line range (checkable in source)
- **MINIMAL REPRO / MECHANISM:** concrete ordered sequence
- **SEVERITY:** fatal-to-premise / fixable-within-design / cosmetic
- **RECOMMENDED AMENDMENT:** one or two sentences, no code

Then a single table summarising P1-P4: KEEP / AMEND / REJECT, with one line
of reason each.

**OVERRIDE CHECK (last line before the count):** Does any finding invalidate
the premise, or are all findings fixable within the design?

## Sequencing (post-audit)

1. This prompt -> DeepSeek.
2. Claude synthesises the verdicts into a design and a Cursor spec.
3. Gemini review loop.
4. Cursor: tests first (commit 1, predicted failures), fix (commit 2), ADR-128.
5. Operator GUI runs at both commits; deploy.

Line count: 210
