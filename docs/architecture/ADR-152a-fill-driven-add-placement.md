This message has a line count at the bottom

# ADR-152a -- Fill-driven add placement (prerequisite to entry purgatory)

| | |
|---|---|
| Status | **DRAFT** -- for DeepSeek teardown, then Gemini ruling |
| Date | 2026-09-17 |
| Design record | `prompts/entry_purgatory_memo_rev2.md` amendment A3 (`40c4f27`) |
| Red team | DeepSeek R1 on entry purgatory rev 1, T-1 (`prompts/deepseek_entry_purgatory_response.md`, `f3ebc31`); claim verified in source by Claude |
| Ruling | Gemini 2026-09-17: extract A3 into a prerequisite ADR; prove stable in production before ADR-152 |
| Source baseline | EA `c39fb84` |
| Supersedes | nothing; amends the entry-placement timing established in ADR-151 s2 |

## Context

After an entry (ENT) deal fills, the layer is appended and its exit is placed
immediately inside the fill handler:

    Grind_HandleSideDealFill (grind_engine.mqh ~1001-1020)
      Grind_AppendLayer(...)
      Grind_ExitQManageSide(...)       <- exit placed here, same event
      return

The NEXT add is not placed here. It is placed later, by
`Grind_EnsureAddNext`, which is only called at the end of
`Grind_OnTickEngine` (grind_engine.mqh ~1150-1154). Two delays follow:

1. **One tick minimum.** The add waits for the next `OnTick` after the fill.
2. **Possibly more than one tick.** `g_grind_ent_sent_this_tick`
   (grind_exitq.mqh:19, cleared at grind_engine.mqh:1119) allows ONE entry send
   per instance per tick, shared across both sides and both L0 and add paths.
   If the L0 path or the other side consumes that tick's allowance, the add
   waits again.

Today this is usually invisible: a resting add is already in the book, so the
delay only affects the NEXT add after a fill, and ticks arrive in milliseconds.
Under entry purgatory (ADR-152) it stops being invisible: far adds are held, so
after each fill the next add must be PLACED, and the delay lands exactly on the
case that matters.

**Verified repro (DeepSeek T-1, re-checked in source).** Long side, add_pips 10.
An add fills at 1.1000, mid ~1.1000, next target 1.0990. Before
`Grind_EnsureAddNext` runs, price drops to 1.0985. A resting order at 1.0990
would have filled. Placed late, the theoretical 1.0990 is now above the bid, so
`Grind_Adr013ClampBuy` (grind_pure.mqh:149-161) prices it at bid - min_dist
~1.0984: the ladder misses the fill and rests one tick lower.

## Decision

**D1. A fill schedules the next add for that side, at highest priority.**
In the `c_role == "ENT"` branch of `Grind_HandleSideDealFill`, after
`Grind_ExitQManageSide`, set a per-side flag:

    g_grind_add_due_long  = true;   // or g_grind_add_due_short
    g_grind_add_due_deal  = deal_ticket;   // for telemetry only

**D2. `Grind_OnTickEngine` services due adds FIRST**, before L0 placement,
recentring, or the ordinary `Grind_EnsureAddNext` calls, and before
`g_grind_ent_sent_this_tick` can be consumed by another path:

    g_grind_ent_sent_this_tick = false;
    Grind_ServiceDueAdds(...);        // new: long then short, flag-driven
    ... existing L0 / recenter / cap / EnsureAddNext work ...

**D3. A due add bypasses the per-tick allowance once.** `Grind_ServiceDueAdds`
may place one entry per side even if `g_grind_ent_sent_this_tick` is already
set, and clears the flag it consumed. The commitment guard
(`Grind_SlotEntryAllowed`, under `Grind_SlotLockAcquire`) is NOT bypassed: a due
add that the guard refuses stays due and is retried next tick.

**D4. No order is sent from `OnTradeTransaction`.** The fill handler only sets a
flag. Reasons: `Grind_SlotLockAcquire` sleeps up to `GRIND_SLOT_LOCK_MAX_RETRIES`
milliseconds, and blocking the transaction thread would delay exit placement for
every other deal in the same burst; and an `OrderSend` issued from a transaction
handler generates further transactions, risking re-entrancy.

**D5. Idempotence.** `Grind_ServiceDueAdds` clears the due flag once it has
either placed, re-priced, or been refused by cap/label validation. An existing
`add_pending_ticket` still short-circuits placement inside
`Grind_EnsureAddNext`, so a due flag can never create a second add.

**D6. Scope.** Adds only. L0 placement, the straddle, recentring, exits, the
guard formula and the exit queue are unchanged. This ADR does not introduce any
withholding of orders; that is ADR-152.

## Consequences

- The next add is placed on the first tick after the fill, ahead of every other
  entry on that instance, instead of after them or one tick later.
- Request cost: **zero additional sends in steady state.** The same add is sent,
  earlier in the tick. The only new sends are those that today are skipped
  because another path consumed the tick allowance and price then moved away.
- The fill path gains one boolean assignment and no I/O.
- ADR-152 (entry purgatory) assumes this is live.

## Risks

R1. **Priority inversion against exits.** Due adds are serviced before other
    entries but still after `Grind_RetryMissingExits`, which runs first in
    `Grind_OnTickEngine` (~1120). Exits keep absolute priority. MUST be kept in
    that order.
R2. **Flag leak across reinit.** `g_grind_add_due_*` are globals; they must be
    cleared in `OnInit` with the rest of engine state, or a stale due flag could
    fire an add before reconstruction completes.
R3. **Burst of fills.** Several ENT fills on one side in one transaction burst
    set the flag repeatedly; D5 makes that idempotent (one add per side).
R4. **Cap interaction.** A fill that takes the side to `max_layers` leaves a due
    flag with no legal add. `Grind_EnsureAddNext` already returns early at cap;
    the flag is cleared by D5 without a send.

## Tests (MQL5 suite, all pure/unit-level)

T1. Fill handler sets the due flag for the filled side only, and does not send.
T2. `Grind_ServiceDueAdds` places the add when the guard allows, with the
    correct layer label, and clears the flag.
T3. Due add places even when `g_grind_ent_sent_this_tick` is already true; the
    ordinary `EnsureAddNext` path in the same tick does not then double-send.
T4. Guard refusal leaves the flag set; the next tick retries.
T5. At cap, the flag is cleared with no send.
T6. Two fills on the same side in one burst produce one add.
T7. Exit retry still runs before due adds (ordering assertion in the tick path).
T8. Reinit clears due flags.

## Rollout

Phase 1: merge, deploy to one pair (GBPUSD OPT + ALT), monitor 48 h for
STRAY/quarantine/halt markers and for add placement latency in the archive.
Phase 2: fleet. ADR-152 spec begins only after Phase 2 is stable.

## Open questions for the teardown

Q1. Is a flag-plus-service-next-tick genuinely equivalent to "same tick" for
    the purgatory case, or does the held-add case require placement inside the
    transaction handler despite D4?
Q2. Should the due flag carry the intended layer index, so a late service with a
    changed anchor is rejected rather than re-derived?
Q3. Does servicing due adds before L0 placement starve a flat opposite side in a
    fast market, and does that matter?

Line count: 141
