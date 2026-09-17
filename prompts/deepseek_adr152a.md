This message has a line count at the bottom.

# DeepSeek Phase 1 -- Teardown: ADR-152a, fill-driven add placement
# Prerequisite to entry purgatory (ADR-152). Source baseline: main @ 7eb95a9,
# EA at c39fb84. You have READ access to ea/ and docs/architecture/.

## Role
Phase 1 Red Team (adversarial quant). Write ZERO implementation code. Break the
ADR AND its premise against the ACTUAL source. Hunt mechanical failure modes.

## Frame (do NOT retail-judge)
fxgrind is a passive limit-order market maker on MT5. Sixteen instances (eight
symbols x two geometry arms) share one FTMO demo account, separated by magic.
It NEVER crosses the spread and NEVER uses stop losses. Per side an instance
holds a ladder of layers; ADR-151 keeps live exits only on the nearest ranks and
holds deeper ones as formula targets. Invariants run every tick and halt the
instance when book and tracker disagree; fail-closed halts are a safety
primitive. Risk is 0.01 lots, per-side caps (8), and account limits. Do NOT
critique leverage, the absence of stops, or "most traders lose". Judge ONLY
mechanical correctness, especially around the trade-transaction path.

## GIVENS (source-verified at c39fb84 -- do NOT re-litigate without a source counter)
G1. `Grind_HandleSideDealFill` (grind_engine.mqh ~921) handles deals. In the
    `c_role == "ENT"` branch (~1001) it clears the matching pending ticket,
    calls `Grind_AppendLayer`, then `Grind_ExitQManageSide` (exit placed in the
    same event), then returns. It never calls `Grind_EnsureAddNext`.
G2. `Grind_EnsureAddNext` is called ONLY at the end of `Grind_OnTickEngine`
    (~1150-1154), after L0 placement, opposite-L0 recentring, and cap
    transitions.
G3. `g_grind_ent_sent_this_tick` (grind_exitq.mqh:19) is cleared at
    grind_engine.mqh:1119 and set after a successful entry send in BOTH entry
    paths (~543 L0, ~804 add). One entry send per instance per tick, shared
    across sides and paths.
G4. `Grind_EnsureAddNext` is not place-once: with a pending add whose clamped
    target has left the deadband (`InpDeadbandPips = 4.0`) it calls
    `Grind_ModifyPendingPrice` (~776) and returns.
G5. `Grind_Adr013ClampBuy` (grind_pure.mqh:149-161) returns
    `min(theoretical, bid - min_dist)`; `Grind_BuyLimitMarketable` (:137) is
    misnamed and returns TRUE when the limit is PASSIVE. A clamped add rests
    below the bid; it never reaches the market.
G6. The entry gate `Grind_SlotEntryAllowed` (grind_exitq.mqh ~161) is evaluated
    inside `Grind_SlotLockAcquire` / `Grind_SlotLockRelease`, which retries with
    `Sleep(1)` up to `GRIND_SLOT_LOCK_MAX_RETRIES` and can steal a stale lock.
G7. `Grind_RetryMissingExits` runs at the TOP of `Grind_OnTickEngine` (~1120),
    before any entry work. Exits have absolute priority today.
G8. Reconstruction, invariants and `Grind_ValidateAddLabelIndex` are as in
    ADR-151; no invariant asserts that a layer has a resting entry order.

## The ADR (ATTACK it) -- full text at docs/architecture/ADR-152a-fill-driven-add-placement.md
D1. The ENT branch of the fill handler sets a per-side flag
    (`g_grind_add_due_long` / `g_grind_add_due_short`) after
    `Grind_ExitQManageSide`. It sends nothing.
D2. `Grind_OnTickEngine` services due adds FIRST, before L0 placement,
    recentring and the ordinary `Grind_EnsureAddNext` calls.
D3. A due add may bypass `g_grind_ent_sent_this_tick` once per side. It does NOT
    bypass the commitment guard; a refused due add stays due and retries.
D4. No OrderSend from `OnTradeTransaction` (lock sleeps; re-entrancy).
D5. Idempotent: the flag is cleared once serviced, placed, re-priced or refused
    by cap/label validation; `add_pending_ticket` still short-circuits.
D6. Scope: adds only. No withholding of orders (that is ADR-152).

## Threats to attack (T-1..T-8)
T-1. Is the flag genuinely equivalent to same-tick? Construct a price path where
     flag-plus-next-tick still misses the fill that motivated the ADR, given
     MT5's OnTick / OnTradeTransaction ordering and tick granularity.
T-2. Bypassing `g_grind_ent_sent_this_tick` (D3): what did that budget protect
     against? Show a burst where one bypass per side per tick produces a request
     rate or an ordering the original budget was there to prevent.
T-3. Flag lifecycle. Enumerate every path that sets, clears or should clear the
     flag: cap reached, halt, quarantine, reinit, recon failure, manual close,
     label mismatch, guard refusal. Find one where the flag survives and later
     fires an add against a ladder that no longer implies it.
T-4. Ordering. Servicing due adds before L0 and before recentring: find a state
     where this starves a flat opposite side, or where an add placed before
     recentring produces a worse book than today's order.
T-5. Interaction with G4 re-pricing: a due flag when an add is already pending
     and outside the deadband. Does D5 collapse the modify path, double-send, or
     leave the flag stuck?
T-6. Guard refusal loop (D3 + G6): a due add refused every tick while the guard
     is saturated. Bound the retry cost in OrderSend attempts and lock
     acquisitions per minute; is the lock itself a contention risk at 16
     instances?
T-7. Transaction-path safety: does setting a flag inside `Grind_HandleSideDealFill`
     interact with `Grind_DealWasProcessed` / `Grind_MarkDealProcessed`, the
     CloseBy queue, or the OUT_BY branch in any way that can lose or duplicate
     the flag under a multi-deal burst?
T-8. Premise. Is the latency real enough to justify touching the fill path at
     all? Attack with source: given ticks arrive in milliseconds and adds today
     already rest, quantify what D1-D3 actually buys BEFORE ADR-152 ships, and
     whether the ADR should simply be folded into ADR-152 instead.

## Required output format
GIVENS CHECK first: for each G1..G8 print CONFIRMED or REFUTED with file:line
from the actual source you opened (or "NOT VERIFIED -- file unavailable").
Then for EACH threat T-1..T-8:
- VERDICT: EXPLOIT-FOUND / NO-EXPLOIT / DESIGN-UNSAFE
- LOAD-BEARING CLAIM: file : function : invariant (checkable in source)
- MINIMAL REPRO / MECHANISM: concrete sequence with numbers
- SEVERITY: fatal-to-premise / fixable-within-design / cosmetic
Then a PREMISE VERDICT: is fill-driven add placement worth the fill-path risk as
its own ADR, and are D1-D6 mechanically safe as written?
OVERRIDE CHECK (last line): does any finding kill the ADR-152a premise, or are
all findings fixable within it?

Line count: 105
