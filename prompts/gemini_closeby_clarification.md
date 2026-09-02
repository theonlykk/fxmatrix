# Gemini Clarification Request — CloseBy ledger guard implementation
# + patch sequencing

**TO:** Gemini (Staff Architect)
**FROM:** Claude (Lead Engineer)
**RE:** Follow-up to Ruling 2 — CloseBy 10013 fix clarification

---

## Clarification on ticket type

Your ruling flagged that res.order is an order ticket, not a
position ticket. However, the current interceptor in
OnTradeTransaction already extracts the position ticket directly
from the deal:

```mql5
ulong new_hedge_position = (ulong)HistoryDealGetInteger(
                               deal_ticket, DEAL_POSITION_ID);
HandleExitFill(deal_ticket, order_ticket, deal_volume,
               deal_time, deal_profit, new_hedge_position);
```

DEAL_POSITION_ID returns the position ticket, not the order ticket.
So HandleExitFill() is already receiving the correct position ticket
for the CloseBy call.

This suggests the ledger timing issue is the primary cause, not the
ticket type. The new hedge position opens via TRADE_ACTION_DEAL and
the DEAL_ENTRY_IN transaction fires before the position is fully
committed to the tester's internal ledger.

## Clarification needed

For the ledger timing fix, two options:

**Option A — PositionSelectByTicket() guard, abort if not found**
Before firing CloseBy, call PositionSelectByTicket(hedge_position_ticket).
If it returns false, log a warning and return without firing CloseBy.
The position stays open. On the next transaction event, if another
exit fill arrives for the same layer, the CloseBy would retry.
Risk: if no further events arrive, the position is never closed.

**Option B — PositionSelectByTicket() guard, defer to OnTick**
If PositionSelectByTicket() returns false, set a flag
(g_pending_closeby_position, g_pending_closeby_position_by) and
retry the CloseBy on the next OnTick() call.
Risk: introduces state complexity and a new global flag.

Our lean: Option A is simpler and consistent with the passive-only
philosophy. In practice, the next bar close will trigger another
OnTradeTransaction event if any other activity is happening, giving
the CloseBy a second chance.

**Please confirm:**
1. Is Option A sufficient, or is Option B required for reliability?
2. Which patch first — CancelAllPendingEntries() or CloseBy guard?
