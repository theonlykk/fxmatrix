# Cursor Implementation Prompt 3 of 4
# Scope: Execution Engine — OnTradeTransaction, LIFO Array, Partial Fills
# Reference: ADR-002 v4 Sections 4, 6

This message has a line count at the bottom.
Read this entire prompt before writing a single line of code.
Do not begin implementation until you have read all sections.

---

## Context

You are implementing a native MQL5 Expert Advisor for a
3-currency FX mean-reversion pod (EUR, GBP, USD) on an FTMO
MT5 hedging account. This is Prompt 3 of 4.

Files already locked (do not modify):
- d:\fxmatrix\ea\LayerStruct.mqh
- d:\fxmatrix\ea\Globals.mqh
- d:\fxmatrix\ea\MathEngine.mqh

Full specification:
- d:\fxmatrix\adrs\ADR-002-matrix-driven-exits-v4.md
- d:\fxmatrix\adrs\ADR-003-carry-adjustment-v2.md

If anything in this prompt conflicts with the ADRs,
the ADRs take precedence.

---

## Deliverable

One file: `d:\fxmatrix\ea\ExecutionEngine.mqh`

This file contains:
1. PlaceEntryLimit() — places the first entry limit order
2. PlaceExitLimit() — places one exit limit for a given volume
3. PlaceNextEntryLimit() — places Layer N+1 entry limit
4. OnTradeTransaction() — fill handler, LIFO array management,
   partial fill tracking, MinFillThreshold trigger
5. LogLayerExit() — structured exit log per ADR-002 Section 6.2

No signal computation. No carry recalculation. No OnTick.
No circuit breaker logic. No OrderModify for nudging or carry.

---

## Section 1 — Order Placement Utilities

### PlaceEntryLimit()

Places the first passive entry limit order for the pod.
Called from OnTick() (Prompt 4) when signal fires and
inventory is empty.

```mql5
// Returns the order ticket on success, 0 on failure.
ulong PlaceEntryLimit(double price, int direction, string symbol) {

    // Step 1: Freeze level check
    if (!IsClearOfFreezeLevel(price, direction, symbol)) {
        Print("INFO: PlaceEntryLimit skipped — freeze level. ",
              "symbol=", symbol, " price=", DoubleToString(price,5));
        return 0;
    }

    // Step 2: Passivity check
    if (!IsPassive(price, direction, symbol)) {
        Print("INFO: PlaceEntryLimit skipped — passivity failure. ",
              "symbol=", symbol, " price=", DoubleToString(price,5));
        return 0;
    }

    // Step 3: Build request
    MqlTradeRequest  req = {};
    MqlTradeResult   res = {};

    req.action   = TRADE_ACTION_PENDING;
    req.symbol   = symbol;
    req.volume   = BaseLotSize;
    req.price    = price;
    req.type     = (direction == DIRECTION_BUY)
                   ? ORDER_TYPE_BUY_LIMIT
                   : ORDER_TYPE_SELL_LIMIT;
    req.type_filling = ORDER_FILLING_RETURN;
    req.type_time    = ORDER_TIME_GTC;
    req.comment      = "FXMatrix_Entry_L" +
                       IntegerToString(ArraySize(g_inventory) + 1);

    if (!OrderSend(req, res)) {
        Print("ERROR: PlaceEntryLimit OrderSend failed. ",
              "retcode=", res.retcode,
              " symbol=", symbol,
              " price=", DoubleToString(price,5));
        return 0;
    }

    Print("INFO: Entry limit placed. ticket=", res.order,
          " symbol=", symbol,
          " price=", DoubleToString(price,5),
          " direction=", direction);
    return res.order;
}
```

### PlaceExitLimit()

Places one passive exit limit for a specific volume tranche.
Called from OnTradeTransaction() on each partial or full fill.

```mql5
// Returns the exit order ticket on success, 0 on failure.
ulong PlaceExitLimit(double exit_price, double volume,
                     int direction, string symbol) {

    // Exit direction is opposite to entry direction
    int exit_dir = (direction == DIRECTION_BUY)
                   ? DIRECTION_SELL : DIRECTION_BUY;

    // Step 1: Freeze level check
    if (!IsClearOfFreezeLevel(exit_price, exit_dir, symbol)) {
        Print("INFO: PlaceExitLimit skipped — freeze level. ",
              "symbol=", symbol,
              " price=", DoubleToString(exit_price,5));
        return 0;
    }

    // Step 2: Passivity check
    if (!IsPassive(exit_price, exit_dir, symbol)) {
        Print("INFO: PlaceExitLimit skipped — passivity failure. ",
              "symbol=", symbol,
              " price=", DoubleToString(exit_price,5));
        return 0;
    }

    // Step 3: Build request
    MqlTradeRequest  req = {};
    MqlTradeResult   res = {};

    req.action   = TRADE_ACTION_PENDING;
    req.symbol   = symbol;
    req.volume   = volume;
    req.price    = exit_price;
    req.type     = (exit_dir == DIRECTION_BUY)
                   ? ORDER_TYPE_BUY_LIMIT
                   : ORDER_TYPE_SELL_LIMIT;
    req.type_filling = ORDER_FILLING_RETURN;
    req.type_time    = ORDER_TIME_GTC;
    req.comment      = "FXMatrix_Exit";

    if (!OrderSend(req, res)) {
        Print("ERROR: PlaceExitLimit OrderSend failed. ",
              "retcode=", res.retcode,
              " price=", DoubleToString(exit_price,5),
              " volume=", DoubleToString(volume,4));
        return 0;
    }

    return res.order;
}
```

### PlaceNextEntryLimit()

Places the entry limit for Layer N+1 at layer.add_next.
Called from OnTradeTransaction() when MinFillThreshold is met.

```mql5
// Returns the order ticket on success, 0 on failure.
ulong PlaceNextEntryLimit(const Layer &prev_layer, string symbol) {

    double price     = prev_layer.add_next;
    int    direction = prev_layer.direction;

    // Step 1: Freeze level check
    if (!IsClearOfFreezeLevel(price, direction, symbol)) {
        Print("INFO: PlaceNextEntryLimit skipped — freeze level. ",
              "add_next=", DoubleToString(price,5));
        return 0;
    }

    // Step 2: Passivity check
    if (!IsPassive(price, direction, symbol)) {
        Print("INFO: PlaceNextEntryLimit skipped — passivity. ",
              "add_next=", DoubleToString(price,5));
        return 0;
    }

    MqlTradeRequest  req = {};
    MqlTradeResult   res = {};

    req.action   = TRADE_ACTION_PENDING;
    req.symbol   = symbol;
    req.volume   = BaseLotSize;
    req.price    = price;
    req.type     = (direction == DIRECTION_BUY)
                   ? ORDER_TYPE_BUY_LIMIT
                   : ORDER_TYPE_SELL_LIMIT;
    req.type_filling = ORDER_FILLING_RETURN;
    req.type_time    = ORDER_TIME_GTC;
    req.comment      = "FXMatrix_Entry_L" +
                       IntegerToString(ArraySize(g_inventory) + 1);

    if (!OrderSend(req, res)) {
        Print("ERROR: PlaceNextEntryLimit failed. retcode=", res.retcode);
        return 0;
    }

    Print("INFO: Next entry limit placed. ticket=", res.order,
          " add_next=", DoubleToString(price,5));
    return res.order;
}
```

---

## Section 2 — Layer Exit Log

### LogLayerExit() — ADR-002 Section 6.2

```mql5
void LogLayerExit(const Layer &layer, datetime exit_time,
                  double gross_pnl) {

    double holding_days = (double)(exit_time - layer.entry_time)
                          / 86400.0;
    double carry_delta  = layer.entry_spread_raw
                          - layer.entry_spread_adjusted;

    string instrument_str = (layer.instrument == INSTRUMENT_EURUSD)
                            ? "EURUSD"
                            : (layer.instrument == INSTRUMENT_GBPUSD)
                              ? "GBPUSD" : "EURGBP";

    Print("LAYER_EXIT | ",
          "instrument=",         instrument_str,
          " | direction=",       layer.direction,
          " | entry_price=",     DoubleToString(layer.entry_price, 5),
          " | entry_spread_raw=",DoubleToString(layer.entry_spread_raw, 6),
          " | entry_spread_adj=",DoubleToString(layer.entry_spread_adjusted, 6),
          " | exit_spread_tgt=", DoubleToString(layer.exit_spread_target, 6),
          " | carry_delta=",     DoubleToString(carry_delta, 6),
          " | holding_days=",    DoubleToString(holding_days, 2),
          " | gross_pnl=",       DoubleToString(gross_pnl, 2),
          " | entry_time=",      TimeToString(layer.entry_time),
          " | exit_time=",       TimeToString(exit_time));
}
```

---

## Section 3 — OnTradeTransaction()

This is the core of the execution engine. It handles all fill
events, maintains the LIFO inventory array, and triggers next
layer placement when MinFillThreshold is met.

```mql5
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest     &request,
                        const MqlTradeResult      &result) {

    // Only process completed deal additions
    if (trans.type != TRADE_TRANSACTION_DEAL_ADD) return;

    // Fetch deal from history
    if (!HistoryDealSelect(trans.deal)) {
        Print("ERROR: HistoryDealSelect failed for deal ", trans.deal);
        return;
    }

    ulong    deal_ticket  = trans.deal;
    ulong    order_ticket = HistoryDealGetInteger(deal_ticket,
                                DEAL_ORDER);
    double   deal_volume  = HistoryDealGetDouble(deal_ticket,
                                DEAL_VOLUME);
    double   deal_price   = HistoryDealGetDouble(deal_ticket,
                                DEAL_PRICE);
    long     deal_entry   = HistoryDealGetInteger(deal_ticket,
                                DEAL_ENTRY);
    string   deal_symbol  = HistoryDealGetString(deal_ticket,
                                DEAL_SYMBOL);
    datetime deal_time    = (datetime)HistoryDealGetInteger(
                                deal_ticket, DEAL_TIME);
    double   deal_profit  = HistoryDealGetDouble(deal_ticket,
                                DEAL_PROFIT);

    // --- ENTRY FILL ---
    if (deal_entry == DEAL_ENTRY_IN) {
        HandleEntryFill(order_ticket, deal_volume, deal_price,
                        deal_time, deal_symbol);
        return;
    }

    // --- EXIT FILL ---
    if (deal_entry == DEAL_ENTRY_OUT) {
        HandleExitFill(order_ticket, deal_volume, deal_time,
                       deal_profit);
        return;
    }
}
```

### HandleEntryFill()

```mql5
void HandleEntryFill(ulong order_ticket, double deal_volume,
                     double deal_price, datetime deal_time,
                     string deal_symbol) {

    // Find matching layer by entry_ticket
    int layer_idx = -1;
    for (int i = 0; i < ArraySize(g_inventory); i++) {
        if (g_inventory[i].entry_ticket == order_ticket) {
            layer_idx = i;
            break;
        }
    }

    // --- NEW LAYER: no match means this is a first fill on a
    //     new entry limit (not yet in inventory) ---
    if (layer_idx == -1) {

        // Validate: must have capacity
        if (ArraySize(g_inventory) >= MaxLayers) {
            Print("WARNING: Entry fill received but MaxLayers reached. ",
                  "ticket=", order_ticket);
            return;
        }

        // Build new layer
        Layer L = InitLayer();
        L.entry_price                = deal_price;
        L.entry_spread_raw           = g_entry_spread;
        L.entry_spread_adjusted      = g_entry_spread;  // starts = raw
        L.entry_time                 = deal_time;
        L.EU_mid_12bars_ago_at_entry = g_EU_mid_12bars_ago;
        L.GB_mid_12bars_ago_at_entry = g_GB_mid_12bars_ago;
        L.r_EU_at_entry              = g_r_EU_signal;
        L.r_GB_at_entry              = g_r_GB_signal;
        L.strongest_at_entry         = g_strongest;
        L.weakest_at_entry           = g_weakest;

        // Carry recalculation reference prices (ADR-003)
        // Must be set here — ADR-003 will read these at daily recalc.
        // entry_price_eurusd_1h and entry_price_gbpusd_1h use the
        // signal-layer 12-bar-ago prices (already stored in globals).
        double eu_ask = SymbolInfoDouble("EURUSD", SYMBOL_ASK);
        double eu_bid = SymbolInfoDouble("EURUSD", SYMBOL_BID);
        double gb_ask = SymbolInfoDouble("GBPUSD", SYMBOL_ASK);
        double gb_bid = SymbolInfoDouble("GBPUSD", SYMBOL_BID);

        L.entry_price_eurusd    = (eu_ask + eu_bid) / 2.0;
        L.entry_price_gbpusd    = (gb_ask + gb_bid) / 2.0;
        L.entry_price_eurusd_1h = g_EU_mid_12bars_ago;
        L.entry_price_gbpusd_1h = g_GB_mid_12bars_ago;

        // Instrument routing — explicit six-case per ADR-002 v4 Section 5
        // Condensed ternary logic was incorrect for Case 2 (S=GBP,W=EUR)
        if ((g_strongest == 0 && g_weakest == 1) ||
            (g_strongest == 1 && g_weakest == 0))
            L.instrument = INSTRUMENT_EURGBP;
        else if ((g_strongest == 0 && g_weakest == 2) ||
                 (g_strongest == 2 && g_weakest == 0))
            L.instrument = INSTRUMENT_EURUSD;
        else
            L.instrument = INSTRUMENT_GBPUSD;

        // Direction routing — explicit six-case per ADR-002 v4 Section 5
        if ((g_strongest == 0 && g_weakest == 1) ||   // S=EUR W=GBP → Sell EURGBP
            (g_strongest == 0 && g_weakest == 2) ||   // S=EUR W=USD → Sell EURUSD
            (g_strongest == 1 && g_weakest == 2))     // S=GBP W=USD → Sell GBPUSD
            L.direction = DIRECTION_SELL;
        else
            L.direction = DIRECTION_BUY;
        L.lot_size                   = BaseLotSize;
        L.remaining_entry_volume     = BaseLotSize;  // entry fills decrement this
        L.remaining_exit_volume      = 0.0;          // set to lot_size when entry complete
        L.entry_ticket               = order_ticket;

        // Compute exit target using entry-time anchor (immutable)
        L.exit_spread_target = ComputeExitSpreadTarget(L);
        double exit_price    = ComputeExitPrice(L);
        L.exit_target        = exit_price;

        // Compute add_next (ATR-spaced, price space)
        double h4_atr = GetH4ATR(deal_symbol);
        if (L.direction == DIRECTION_BUY)
            L.add_next = deal_price - AddRatio * h4_atr;
        else
            L.add_next = deal_price + AddRatio * h4_atr;

        // Add to inventory
        int new_idx = ArraySize(g_inventory);
        ArrayResize(g_inventory, new_idx + 1);
        g_inventory[new_idx] = L;
        layer_idx = new_idx;

        // When entry fully filled, arm exit volume counter
        if (g_inventory[layer_idx].remaining_entry_volume <= VOLUME_EPSILON)
            g_inventory[layer_idx].remaining_exit_volume =
                g_inventory[layer_idx].lot_size;

        // Clear pending entry ticket — order is now a position,
        // no longer a pending limit. Prevents OnTick() from
        // attempting to nudge a non-existent pending order.
        g_pending_entry_ticket = 0;
    }

    // --- PARTIAL FILL on existing layer ---
    g_inventory[layer_idx].remaining_entry_volume -= deal_volume;

    // Place exit limit for this tranche
    double exit_price = g_inventory[layer_idx].exit_target;
    ulong  exit_tkt   = PlaceExitLimit(exit_price, deal_volume,
                                       g_inventory[layer_idx].direction,
                                       deal_symbol);
    if (exit_tkt > 0) {
        int n = ArraySize(g_inventory[layer_idx].exit_tickets);
        ArrayResize(g_inventory[layer_idx].exit_tickets, n + 1);
        g_inventory[layer_idx].exit_tickets[n] = exit_tkt;
    }

    // Check MinFillThreshold for next layer trigger
    double filled_so_far = g_inventory[layer_idx].lot_size
                         - g_inventory[layer_idx].remaining_entry_volume;
    bool   threshold_met = filled_so_far >=
                           MinFillThreshold * g_inventory[layer_idx].lot_size;
    bool   next_not_placed = ArraySize(g_inventory) == layer_idx + 1;
    bool   capacity_ok     = ArraySize(g_inventory) < MaxLayers;

    if (threshold_met && next_not_placed && capacity_ok) {
        PlaceNextEntryLimit(g_inventory[layer_idx], deal_symbol);
        Print("INFO: Next layer triggered at add_next=",
              DoubleToString(g_inventory[layer_idx].add_next, 5));
    }
}
```

### HandleExitFill()

```mql5
void HandleExitFill(ulong order_ticket, double deal_volume,
                    datetime deal_time, double deal_profit) {

    // Search all layers for matching exit ticket
    for (int i = 0; i < ArraySize(g_inventory); i++) {
        int n_tickets = ArraySize(g_inventory[i].exit_tickets);
        for (int j = 0; j < n_tickets; j++) {
            if (g_inventory[i].exit_tickets[j] == order_ticket) {

                // Decrement exit volume counter
                g_inventory[i].remaining_exit_volume -= deal_volume;

                // Remove this ticket from exit_tickets[]
                ArrayRemove(g_inventory[i].exit_tickets, j, 1);

                // Check if layer is fully closed
                if (g_inventory[i].remaining_exit_volume <= VOLUME_EPSILON) {
                    LogLayerExit(g_inventory[i], deal_time, deal_profit);
                    ArrayRemove(g_inventory, i, 1);
                    Print("INFO: Layer ", i, " fully closed and removed.");
                }
                return;
            }
        }
    }

    // Ticket not found in any layer — attempt fallback
    HandleUnmatchedFill(order_ticket, deal_volume, deal_time);
}
```

### HandleUnmatchedFill() — fallback (ADR-002 Section 6.3)

```mql5
void HandleUnmatchedFill(ulong order_ticket, double deal_volume,
                         datetime deal_time) {

    Print("WARNING: Exit fill not matched by ticket. ",
          "ticket=", order_ticket,
          " volume=", DoubleToString(deal_volume, 4),
          " Attempting fallback match...");

    for (int i = 0; i < ArraySize(g_inventory); i++) {
        string symbol = (g_inventory[i].instrument == INSTRUMENT_EURUSD)
                        ? "EURUSD"
                        : (g_inventory[i].instrument == INSTRUMENT_GBPUSD)
                          ? "GBPUSD" : "EURGBP";

        bool vol_match  = MathAbs(deal_volume - g_inventory[i].lot_size)
                          < VOLUME_EPSILON;
        bool time_match = MathAbs((double)(deal_time
                          - g_inventory[i].entry_time))
                          < FALLBACK_TIME_WINDOW;

        if (vol_match && time_match) {
            Print("WARNING: Fallback matched layer ", i,
                  ". Processing as exit fill.");
            g_inventory[i].remaining_exit_volume -= deal_volume;
            if (g_inventory[i].remaining_exit_volume <= VOLUME_EPSILON) {
                LogLayerExit(g_inventory[i], deal_time, 0.0);
                ArrayRemove(g_inventory, i, 1);
            }
            return;
        }
    }

    // No match found — halt pod
    Print("ERROR: Unmatched fill — no fallback match found. ",
          "ticket=", order_ticket,
          " Halting pod.");
    g_halted = true;
}
```

---

## Section 4 — H4 ATR Helper

Required by HandleEntryFill() for add_next computation.

```mql5
// Returns H4 ATR in price units (pips equivalent).
// Uses 14-period ATR on H4 timeframe.
double GetH4ATR(string symbol) {
    double atr_buf[];
    ArraySetAsSeries(atr_buf, true);
    int handle = iATR(symbol, PERIOD_H4, 14);
    if (handle == INVALID_HANDLE) {
        Print("ERROR: GetH4ATR — iATR handle invalid for ", symbol);
        return 0.001;  // safe fallback — 10 pips
    }
    if (CopyBuffer(handle, 0, 0, 1, atr_buf) < 1) {
        Print("ERROR: GetH4ATR — CopyBuffer failed for ", symbol);
        IndicatorRelease(handle);
        return 0.001;
    }
    IndicatorRelease(handle);
    return atr_buf[0];
}
```

---

## Negative Space — What You Must NOT Do

- Do NOT write OnTick() — Prompt 4
- Do NOT write carry recalculation logic — Prompt 4
- Do NOT write circuit breaker logic — Prompt 4
- Do NOT write OrderModify for nudging — Prompt 4
- Do NOT write OrderModify for carry — Prompt 4
- Do NOT modify LayerStruct.mqh, Globals.mqh, or MathEngine.mqh
- Do NOT use stack-position popping (ArrayRemove by index only
  after finding matching ticket)
- Do NOT trigger next layer before MinFillThreshold is met
- Do NOT place market orders — passive limits only
- Do NOT attach native SL/TP to any order
- Do NOT implement cancel-and-replace — OrderModify only
  (but OrderModify is Prompt 4's domain)
- Do NOT use local clock for timestamps — broker server time only
- Do NOT define a second Layer struct or duplicate globals
- Do NOT implement volatility-scaled threshold — V2
- Do NOT implement multi-timeframe confluence — V2

---

## Self-Review Instructions

Before submitting your response:
1. Confirm PlaceEntryLimit() calls IsClearOfFreezeLevel() and
   IsPassive() before OrderSend().
2. Confirm PlaceExitLimit() calls IsClearOfFreezeLevel() and
   IsPassive() on the exit direction (opposite to entry direction).
3. Confirm OnTradeTransaction() dispatches to HandleEntryFill()
   and HandleExitFill() based on DEAL_ENTRY_IN / DEAL_ENTRY_OUT.
4. Confirm HandleEntryFill() sets ALL immutable Layer fields on
   first fill: entry_price, entry_spread_raw, entry_time,
   EU_mid_12bars_ago_at_entry, GB_mid_12bars_ago_at_entry,
   r_EU_at_entry, r_GB_at_entry, strongest_at_entry,
   weakest_at_entry. AND all four carry reference fields:
   entry_price_eurusd, entry_price_gbpusd,
   entry_price_eurusd_1h, entry_price_gbpusd_1h.
5. Confirm exit tickets are appended to exit_tickets[] dynamic
   array (not overwriting a single field).
6. Confirm MinFillThreshold check uses cumulative filled volume
   (lot_size - remaining_entry_volume), not per-fill volume.
7. Confirm HandleExitFill() searches exit_tickets[] by ticket
   match, not by stack position.
8. Confirm HandleUnmatchedFill() sets g_halted = true on
   no-match and logs ERROR before halting.
9. Confirm GetH4ATR() uses ArraySetAsSeries and releases the
   indicator handle after use.
10. Flag any assumptions, ambiguities, or constraint violations.

---

## Output Format

Respond with:
1. Complete contents of ExecutionEngine.mqh
2. Self-review confirming each of the 10 checks above
3. Any flagged assumptions or concerns

Do not summarise. Do not explain the strategy. Write the file.

Line count: 316
