# Cursor Patch — LayerStruct.mqh + ExecutionEngine.mqh (CloseBy Fix)
# Gemini Ruling: 2026-06-08
# Root cause: Exit limit fills open new opposing positions in MT5 hedging
#             mode. Fix: intercept exit fill in OnTradeTransaction and
#             immediately fire TRADE_ACTION_CLOSE_BY to merge positions.

This message has a line count at the bottom.
Read this entire prompt before writing a single line of code.

## Files to patch
1. `d:\fxmatrix\ea\LayerStruct.mqh`
2. `d:\fxmatrix\ea\ExecutionEngine.mqh`

Do NOT modify any other file.

---

## File 1: LayerStruct.mqh

### Change 1A — Add position_ticket to struct

In the `// --- Entry state (immutable after first fill) ---` section,
add `position_ticket` immediately after `entry_ticket`:

### BEFORE:
```mql5
    // --- Order tracking ---
    ulong    entry_ticket;                 // filled entry order ticket
    ulong    exit_tickets[];              // dynamic array — one per partial fill tranche
```

### AFTER:
```mql5
    // --- Order tracking ---
    ulong    entry_ticket;                 // filled entry order ticket
    ulong    position_ticket;              // MT5 position ticket (hedging mode) — IMMUTABLE
    ulong    exit_tickets[];              // dynamic array — one per partial fill tranche
```

### Change 1B — Add to InitLayer()

Add initialisation of position_ticket to zero in InitLayer():

### BEFORE:
```mql5
    L.entry_ticket                 = 0;
    ArrayResize(L.exit_tickets, 0);
```

### AFTER:
```mql5
    L.entry_ticket                 = 0;
    L.position_ticket              = 0;
    ArrayResize(L.exit_tickets, 0);
```

### Change 1C — Add to Immutability Contract

In the immutability contract comment block, add position_ticket
to the list of fields that must NEVER be modified outside
OnTradeTransaction:

### BEFORE:
```mql5
//   entry_ticket
//
// The following fields are modified ONLY by ADR-003 carry logic:
```

### AFTER:
```mql5
//   entry_ticket
//   position_ticket
//
// The following fields are modified ONLY by ADR-003 carry logic:
```

---

## File 2: ExecutionEngine.mqh

### Change 2A — Set position_ticket in HandleEntryFill()

In the `if (layer_idx == -1)` block where the new Layer L is
initialised, add position_ticket assignment immediately after
entry_ticket is set:

### BEFORE:
```mql5
        L.entry_ticket               = order_ticket;
```

### AFTER:
```mql5
        L.entry_ticket               = order_ticket;
        L.position_ticket            = (ulong)HistoryDealGetInteger(
                                           deal_ticket,
                                           DEAL_POSITION_ID);
```

### Change 2B — Add CloseBy logic in HandleExitFill()

When an exit limit fills in MT5 hedging mode, it opens a new
opposing position. We must immediately fire TRADE_ACTION_CLOSE_BY
to merge the original position with the new opposing position.

In HandleExitFill(), after finding the matching exit ticket and
before decrementing remaining_exit_volume, add the CloseBy block:

### BEFORE:
```mql5
                // Decrement exit volume counter
                g_inventory[i].remaining_exit_volume -= deal_volume;
```

### AFTER:
```mql5
                // In MT5 hedging mode, exit limit fills open a new
                // opposing position. Use TRADE_ACTION_CLOSE_BY to
                // merge the original position with the new opposing
                // position at zero spread cost.
                ulong exit_position_id = (ulong)HistoryDealGetInteger(
                                             deal_ticket,
                                             DEAL_POSITION_ID);

                if (exit_position_id > 0 &&
                    g_inventory[i].position_ticket > 0 &&
                    exit_position_id != g_inventory[i].position_ticket) {

                    MqlTradeRequest close_req = {};
                    MqlTradeResult  close_res = {};
                    close_req.action      = TRADE_ACTION_CLOSE_BY;
                    close_req.position    = g_inventory[i].position_ticket;
                    close_req.position_by = exit_position_id;

                    if (!OrderSend(close_req, close_res)) {
                        Print("ERROR: CloseBy failed. ",
                              "position=",    g_inventory[i].position_ticket,
                              " position_by=", exit_position_id,
                              " retcode=",    close_res.retcode);
                        g_halted = true;
                        return;
                    }

                    Print("INFO: CloseBy executed. ",
                          "position=",    g_inventory[i].position_ticket,
                          " position_by=", exit_position_id,
                          " volume=",     DoubleToString(deal_volume, 4));
                }

                // Decrement exit volume counter
                g_inventory[i].remaining_exit_volume -= deal_volume;
```

### Change 2C — Pass deal_ticket to HandleExitFill()

The CloseBy block needs `deal_ticket` to retrieve the exit
position ID. Update the HandleExitFill() signature and its
call site in OnTradeTransaction().

### BEFORE (function signature):
```mql5
void HandleExitFill(ulong order_ticket, double deal_volume,
                    datetime deal_time, double deal_profit) {
```

### AFTER (function signature):
```mql5
void HandleExitFill(ulong deal_ticket, ulong order_ticket,
                    double deal_volume, datetime deal_time,
                    double deal_profit) {
```

### BEFORE (call site in OnTradeTransaction):
```mql5
    if (deal_entry == DEAL_ENTRY_OUT) {
        HandleExitFill(order_ticket, deal_volume, deal_time,
                       deal_profit);
        return;
    }
```

### AFTER (call site in OnTradeTransaction):
```mql5
    if (deal_entry == DEAL_ENTRY_OUT) {
        HandleExitFill(deal_ticket, order_ticket, deal_volume,
                       deal_time, deal_profit);
        return;
    }
```

---

## Negative Space

- Do NOT modify MathEngine.mqh, Globals.mqh, CarryEngine.mqh,
  or FXMatrix.mq5
- Do NOT change the exit limit placement logic in PlaceExitLimit()
  — passive limit orders continue to be placed as before
- Do NOT switch to market orders for exits
- Do NOT change the LIFO array management logic beyond what is
  specified above
- Do NOT add position_ticket to any section other than entry state

---

## Self-Review

Before submitting:
1. Confirm position_ticket field added to LayerStruct.mqh struct,
   InitLayer(), and immutability contract
2. Confirm position_ticket set via DEAL_POSITION_ID in
   HandleEntryFill()
3. Confirm HandleExitFill() signature now includes deal_ticket
   as first parameter
4. Confirm call site in OnTradeTransaction passes deal_ticket
5. Confirm CloseBy block fires when exit_position_id !=
   position_ticket (i.e. a new opposing position was opened)
6. Confirm CloseBy uses TRADE_ACTION_CLOSE_BY with position
   and position_by fields
7. Confirm g_halted = true on CloseBy failure
8. No other files modified

Line count: 156
