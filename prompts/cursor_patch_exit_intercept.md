# Cursor Patch — ExecutionEngine.mqh (Exit Fill Intercept)
# Gemini Ruling: 2026-06-08
# Root cause: DEAL_ENTRY_IN fills from exit limit orders are blindly
#             routed to HandleEntryFill(). Must intercept and reroute
#             to HandleExitFill() with CloseBy execution.

This message has a line count at the bottom.
Read this entire prompt before writing a single line of code.

## File to patch
`d:\fxmatrix\ea\ExecutionEngine.mqh`

## Do NOT modify any other file.

---

## Change 1 — Update OnTradeTransaction() routing logic

Find the `if (deal_entry == DEAL_ENTRY_IN)` block in
`OnTradeTransaction()` and replace it entirely with:

### BEFORE:
```mql5
    if (deal_entry == DEAL_ENTRY_IN) {
        HandleEntryFill(order_ticket, deal_volume, deal_price,
                        deal_time, deal_symbol);
        return;
    }
```

### AFTER:
```mql5
    if (deal_entry == DEAL_ENTRY_IN) {

        // INTERCEPT: Check if this fill belongs to an exit ticket.
        // In MT5 hedging mode, exit limit fills open new opposing
        // positions (DEAL_ENTRY_IN) instead of closing existing ones.
        // We must detect these and route to HandleExitFill, not
        // HandleEntryFill.
        bool is_exit_limit_fill = false;
        for (int i = 0; i < ArraySize(g_inventory); i++) {
            for (int j = 0; j < ArraySize(g_inventory[i].exit_tickets); j++) {
                if (g_inventory[i].exit_tickets[j] == order_ticket) {
                    is_exit_limit_fill = true;
                    break;
                }
            }
            if (is_exit_limit_fill) break;
        }

        if (is_exit_limit_fill) {
            // Exit limit filled — opened a new hedge position.
            // Pass the new hedge position ticket to HandleExitFill
            // so CloseBy can collapse the pair immediately.
            ulong new_hedge_position = (ulong)HistoryDealGetInteger(
                                           deal_ticket, DEAL_POSITION_ID);
            HandleExitFill(deal_ticket, order_ticket, deal_volume,
                           deal_time, deal_profit, new_hedge_position);
        } else {
            // Genuine new layer entry
            HandleEntryFill(deal_ticket, order_ticket, deal_volume,
                            deal_price, deal_time, deal_symbol);
        }
        return;
    }
```

---

## Change 2 — Update HandleExitFill() signature and CloseBy logic

### BEFORE (signature):
```mql5
void HandleExitFill(ulong deal_ticket, ulong order_ticket,
                    double deal_volume, datetime deal_time,
                    double deal_profit) {
```

### AFTER (signature):
```mql5
void HandleExitFill(ulong deal_ticket, ulong order_ticket,
                    double deal_volume, datetime deal_time,
                    double deal_profit,
                    ulong hedge_position_ticket = 0) {
```

The `hedge_position_ticket` parameter defaults to 0 so existing
calls from the DEAL_ENTRY_OUT path (if any) still compile.

### Inside HandleExitFill(), find the block that matches the ticket
and replace the CloseBy section:

### BEFORE (inside the matching block):
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
```

### AFTER (replace with):
```mql5
                // Fire CloseBy to collapse the hedge pair.
                // hedge_position_ticket is the new short opened by
                // the exit limit fill (passed from OnTradeTransaction
                // intercept). position_ticket is the original long.
                if (hedge_position_ticket > 0 &&
                    g_inventory[i].position_ticket > 0) {

                    MqlTradeRequest close_req = {};
                    MqlTradeResult  close_res = {};
                    close_req.action      = TRADE_ACTION_CLOSE_BY;
                    close_req.position    = g_inventory[i].position_ticket;
                    close_req.position_by = hedge_position_ticket;

                    if (!OrderSend(close_req, close_res)) {
                        Print("ERROR: CloseBy failed. ",
                              "position=",    g_inventory[i].position_ticket,
                              " position_by=", hedge_position_ticket,
                              " retcode=",    close_res.retcode);
                        g_halted = true;
                        return;
                    }

                    Print("INFO: CloseBy successful. Layer ", i,
                          " position=",    g_inventory[i].position_ticket,
                          " position_by=", hedge_position_ticket,
                          " volume=",      DoubleToString(deal_volume, 4));
                }
```

---

## Negative Space

- Do NOT modify LayerStruct.mqh, Globals.mqh, MathEngine.mqh,
  CarryEngine.mqh, or FXMatrix.mq5
- Do NOT change HandleEntryFill() logic
- Do NOT change PlaceExitLimit() — passive limits continue as before
- Do NOT remove the DEAL_ENTRY_OUT path from OnTradeTransaction
- This is a targeted patch to routing logic only

---

## Self-Review

Before submitting:
1. Confirm OnTradeTransaction() checks exit_tickets[] before routing
   DEAL_ENTRY_IN fills
2. Confirm is_exit_limit_fill = true routes to HandleExitFill()
   with hedge_position_ticket from DEAL_POSITION_ID
3. Confirm is_exit_limit_fill = false routes to HandleEntryFill()
   (unchanged)
4. Confirm HandleExitFill() signature has hedge_position_ticket
   as final parameter with default = 0
5. Confirm CloseBy uses hedge_position_ticket (not DEAL_POSITION_ID
   lookup inside the function)
6. Confirm g_halted = true on CloseBy failure
7. No other files modified

Line count: 130
