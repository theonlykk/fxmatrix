# Cursor Patch — ExecutionEngine.mqh + FXMatrix.mq5 (Pod Teardown Sweep)
# Gemini Ruling: APPROVED — cancel all pending entry orders when pod
# fully closes (ArraySize(g_inventory) == 0 after last layer removed)

This message has a line count at the bottom.
Read this entire prompt before writing a single line of code.

## Files to modify
- MODIFY: `d:\fxmatrix\ea\ExecutionEngine.mqh`
- MODIFY: `d:\fxmatrix\ea\FXMatrix.mq5`

## Do NOT modify StateEngine.mqh, LayerStruct.mqh, Globals.mqh,
## MathEngine.mqh, or CarryEngine.mqh.

---

## Background

When a pod closes (all layers exit), pending entry orders for that
pod remain live on the broker. When price revisits those levels days
or weeks later, they fill. HandleEntryFill() receives the fill with
no matching entry_ticket in g_inventory[] and either:

1. Treats it as a fresh Layer 0 using live globals — wrong routing
2. Hits MaxLayers and rejects it — but the position still opens on
   the broker as an untracked orphan

CheckForOrphans() then halts the EA on next reload. Gemini ruling:
when ArraySize(g_inventory) reaches 0 after the last layer is
removed, immediately cancel all pending orders on _Symbol.

---

## PART 1 — ADD CancelAllPendingEntries() to FXMatrix.mq5

### Change 1 — Add function declaration

Find the existing forward declarations at the top of FXMatrix.mq5:

#### BEFORE:
```mql5
bool CheckCircuitBreakers();
void CloseAllPositions();
void CancelAllPending();
string GetEntrySymbol();
int    GetEntryDirection();
double GetPendingOrderPrice(ulong ticket);
```

#### AFTER:
```mql5
bool CheckCircuitBreakers();
void CloseAllPositions();
void CancelAllPending();
void CancelAllPendingEntries();
string GetEntrySymbol();
int    GetEntryDirection();
double GetPendingOrderPrice(ulong ticket);
```

### Change 2 — Add function implementation

Add the following function immediately after the existing
`CancelAllPending()` function body:

```mql5
void CancelAllPendingEntries() {
    int cancelled = 0;
    for (int i = OrdersTotal() - 1; i >= 0; i--) {
        ulong ticket = OrderGetTicket(i);
        if (ticket == 0) continue;
        if (OrderGetString(ORDER_SYMBOL) != _Symbol) continue;

        MqlTradeRequest req = {};
        MqlTradeResult  res = {};
        req.action = TRADE_ACTION_REMOVE;
        req.order  = ticket;

        if (!OrderSend(req, res)) {
            Print("WARNING: CancelAllPendingEntries — cancel failed. ",
                  "ticket=", ticket,
                  " retcode=", res.retcode);
        } else {
            cancelled++;
        }
    }

    g_pending_entry_ticket = 0;
    SaveInventoryState();

    Print("INFO: CancelAllPendingEntries — cancelled ", cancelled,
          " pending orders on ", _Symbol);
}
```

---

## PART 2 — MODIFY ExecutionEngine.mqh

### Change 3 — Call CancelAllPendingEntries() when pod fully closes

Find this exact block in HandleExitFill():

#### BEFORE:
```mql5
                if (g_inventory[i].remaining_exit_volume <= VOLUME_EPSILON) {
                    LogLayerExit(g_inventory[i], deal_time, deal_profit);
                    ArrayRemove(g_inventory, i, 1);
                    Print("INFO: Layer ", i, " fully closed and removed.");
                }

                // Save unconditionally: captures both partial volume
                // decrements and full layer removals.
                SaveInventoryState();
                return;
```

#### AFTER:
```mql5
                if (g_inventory[i].remaining_exit_volume <= VOLUME_EPSILON) {
                    LogLayerExit(g_inventory[i], deal_time, deal_profit);
                    ArrayRemove(g_inventory, i, 1);
                    Print("INFO: Layer ", i, " fully closed and removed.");

                    // Pod fully closed — cancel all pending entry orders
                    // to prevent stale tickets filling as orphans.
                    if (ArraySize(g_inventory) == 0) {
                        Print("INFO: Pod fully closed. Initiating "
                              "pending entry teardown.");
                        CancelAllPendingEntries();
                    }
                }

                // Save unconditionally: captures both partial volume
                // decrements and full layer removals.
                // Note: if CancelAllPendingEntries() was called above,
                // it already saves state — this call is a no-op in
                // terms of correctness but harmless.
                SaveInventoryState();
                return;
```

---

## Negative Space

- Do NOT modify StateEngine.mqh, LayerStruct.mqh, Globals.mqh,
  MathEngine.mqh, or CarryEngine.mqh
- Do NOT modify CancelAllPending() — that is the circuit breaker
  sweep and cancels ALL pending orders regardless of symbol.
  CancelAllPendingEntries() is scoped to _Symbol only and is
  called only on pod teardown.
- Do NOT call CancelAllPendingEntries() anywhere other than the
  pod teardown path in HandleExitFill()
- Do NOT modify HandleEntryFill(), HandleExitFill() exit path,
  or the CloseBy intercept beyond the changes above
- This patch does NOT address the CloseBy queue — that is a
  separate patch

---

## Self-Review

Before submitting:
1. Confirm CancelAllPendingEntries() declared in forward declarations
2. Confirm CancelAllPendingEntries() implemented after CancelAllPending()
3. Confirm loop uses OrderGetString(ORDER_SYMBOL) != _Symbol filter
4. Confirm g_pending_entry_ticket = 0 set inside
   CancelAllPendingEntries()
5. Confirm SaveInventoryState() called inside
   CancelAllPendingEntries() after cancellations
6. Confirm CancelAllPendingEntries() called only when
   ArraySize(g_inventory) == 0 after ArrayRemove
7. Confirm existing SaveInventoryState() call after the if block
   is retained (unconditional save for partial fills)
8. Confirm CancelAllPending() (circuit breaker) is untouched
9. Confirm no other files modified

Line count: 109
