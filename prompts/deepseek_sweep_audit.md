This message has a line count at the bottom.

# DeepSeek Narrow Audit — SRE Entry-Pending-Order Sweep (single question)

## Scope — narrow, NOT a reconstruction re-audit

(Gemini-mandated narrow Phase 1 audit; scope is order-sweep side-effect safety ONLY.)

This is NOT a re-audit of the SRE reconstruction, HALT_30, ADR-107/108 geometry, or the consistency checks — those are unchanged and upstream of this change. ONE new thing is added: a broker side-effect (order deletion) on the reconstruction SUCCESS path. Audit ONLY whether that deletion can ever remove an order it should not.

## Context

Tier 2 live drill found: SRE reconstructs in-memory layer state from open POSITIONS + matched exit orders + deal replay, but pre-existing ENTRY-side pending quotes (L0/Add/Reload, entry magic) are consistency-checked and then left on the broker. The tick loop, seeing no L0 quote in its rebuilt state, places a fresh one -> DUPLICATE resting quotes (observed across all 3 instances).

Fix: after a SUCCESSFUL reconstruction (seq == V2_SRE_OK), in the live caller V2_SRE_RunSideOnInit, sweep pre-existing entry-magic pending limit orders so the tick loop places exactly one fresh pair.

## The fix as written

```mql5
int V2_SRE_SweepEntryPendingOrders(const string symbol, const long entry_magic)
{
   int swept = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0)                                   continue;
      if(!OrderSelect(ticket))                          continue;
      if(OrderGetString(ORDER_SYMBOL) != symbol)        continue;
      if(OrderGetInteger(ORDER_MAGIC) != entry_magic)   continue;
      long otype = OrderGetInteger(ORDER_TYPE);
      if(otype != ORDER_TYPE_BUY_LIMIT && otype != ORDER_TYPE_SELL_LIMIT) continue;
      MqlTradeRequest req = {}; MqlTradeResult res = {};
      req.action = TRADE_ACTION_REMOVE; req.order = ticket;
      if(V2_OrderSendCounted(req, res)) swept++;
   }
   return swept;
}
```
Called once, on the success path only (after the halt-path early-return), with cfg.symbol and cfg.entry_magic.

## THE SINGLE QUESTION

Can this sweep, as written, EVER delete an order that the reconstructed state still needs, or otherwise cause harm? Pressure-test specifically:

1. Exit-hedge orders carry the EXIT magic (e.g. ...904), NOT entry_magic. The filter is `magic != entry_magic -> skip`. Confirm the exit-hedge (which MatchExitOrders adopts) can NEVER match entry_magic and so is never swept. Is there any config where entry_magic == exit_magic, or where an exit order carries the entry magic?
2. entry_magic is per-side (long ...901 vs short ...902). The caller runs per-side. Could the long-side sweep delete the short-side's pending entries or vice versa, given both are buy_limit/sell_limit? (i.e. is the magic filter sufficient to isolate sides, or could a same-magic cross-side order exist?)
3. Multi-instance: three EAs on one account (GBPUSD/EURUSD/EURGBP), distinct magics AND distinct symbols. The filter requires symbol==cfg.symbol AND magic==entry_magic. Confirm no cross-instance deletion is possible.
4. Timing/state: is there any window where a pending entry order is mid-transition (partially filled, or about to fill) such that deleting it after a successful reconstruction loses a real fill or corrupts state? The reconstruction already ran on the gathered snapshot; the sweep runs after. Could an order fill BETWEEN the gather and the sweep, so we delete something that just became a position?
5. Does deleting entry pendings on the success path ever strand the reconstructed positions without their intended next-layer quote in a way the tick loop does NOT then correctly re-place? (i.e. is "delete-then-let-tick-loop-requote" actually safe, or is there a layer whose quote the tick loop won't re-place?)


6. RECONNECTION DELAY (Gemini-flagged): OnInit can run while the terminal is still synchronizing with the broker after a reconnect. Is there a window where OrdersTotal()/OrderSelect returns a STALE or PARTIAL view of the order book -- such that the sweep either (a) misses an entry pending that IS there (leaving a duplicate -- benign, tick loop recovers), or worse (b) sees an order in a transitional state and deletes something mid-sync that shouldn't be deleted? The drill showed `terminal synchronized: 1 positions, 7 orders` logged BEFORE the EA OnInit ran -- does OnInit reliably run only AFTER full sync, or can it fire mid-sync? If mid-sync is possible, does the sweep need to gate on a sync-complete condition?

Question 4 (fill-between-gather-and-sweep race) and Question 6 (mid-sync stale order book) are the two I most want broken. If that race can lose a fill, the sweep needs a re-check or a guard.

Out of scope: reconstruction logic, HALT_30, geometry, consistency checks. ONLY the sweep's deletion safety.

If safe: confirm, and confirm whether any guard (e.g. re-select and verify still-pending before delete) is warranted for the Q4 race. If not safe: specify the exact failing construction.
