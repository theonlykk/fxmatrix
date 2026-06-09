#ifndef EXECUTION_ENGINE_MQH
#define EXECUTION_ENGINE_MQH

#include "MathEngine.mqh"
#include "StateEngine.mqh"

void CancelAllPendingEntries();

ulong PlaceEntryLimit(double price, int direction, string symbol) {
    if (!IsClearOfFreezeLevel(price, direction, symbol)) {
        Print("INFO: PlaceEntryLimit skipped — freeze level. ",
              "symbol=", symbol, " price=", DoubleToString(price, 5));
        return 0;
    }

    if (!IsPassive(price, direction, symbol)) {
        Print("INFO: PlaceEntryLimit skipped — passivity failure. ",
              "symbol=", symbol, " price=", DoubleToString(price, 5));
        return 0;
    }

    MqlTradeRequest req = {};
    MqlTradeResult  res = {};

    req.action       = TRADE_ACTION_PENDING;
    req.symbol       = symbol;
    req.volume       = BaseLotSize;
    req.price        = price;
    req.magic        = EA_MAGIC;
    req.type         = (direction == DIRECTION_BUY)
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
              " price=", DoubleToString(price, 5));
        return 0;
    }

    Print("INFO: Entry limit placed. ticket=", res.order,
          " symbol=", symbol,
          " price=", DoubleToString(price, 5),
          " direction=", direction);
    return res.order;
}

ulong PlaceExitLimit(double exit_price, double volume,
                     int direction, string symbol) {
    int exit_dir = (direction == DIRECTION_BUY)
                   ? DIRECTION_SELL : DIRECTION_BUY;

    if (!IsClearOfFreezeLevel(exit_price, exit_dir, symbol)) {
        Print("INFO: PlaceExitLimit skipped — freeze level. ",
              "symbol=", symbol,
              " price=", DoubleToString(exit_price, 5));
        return 0;
    }

    if (!IsPassive(exit_price, exit_dir, symbol)) {
        Print("INFO: PlaceExitLimit skipped — passivity failure. ",
              "symbol=", symbol,
              " price=", DoubleToString(exit_price, 5));
        return 0;
    }

    MqlTradeRequest req = {};
    MqlTradeResult  res = {};

    req.action       = TRADE_ACTION_PENDING;
    req.symbol       = symbol;
    req.volume       = volume;
    req.price        = exit_price;
    req.magic        = EA_MAGIC;
    req.type         = (exit_dir == DIRECTION_BUY)
                       ? ORDER_TYPE_BUY_LIMIT
                       : ORDER_TYPE_SELL_LIMIT;
    req.type_filling = ORDER_FILLING_RETURN;
    req.type_time    = ORDER_TIME_GTC;
    req.comment      = "FXMatrix_Exit";

    if (!OrderSend(req, res)) {
        Print("ERROR: PlaceExitLimit OrderSend failed. ",
              "retcode=", res.retcode,
              " price=", DoubleToString(exit_price, 5),
              " volume=", DoubleToString(volume, 4));
        return 0;
    }

    return res.order;
}

ulong PlaceNextEntryLimit(const Layer &prev_layer, string symbol) {
    double price     = prev_layer.add_next;
    int    direction = prev_layer.direction;

    if (!IsClearOfFreezeLevel(price, direction, symbol)) {
        Print("INFO: PlaceNextEntryLimit skipped — freeze level. ",
              "add_next=", DoubleToString(price, 5));
        return 0;
    }

    if (!IsPassive(price, direction, symbol)) {
        Print("INFO: PlaceNextEntryLimit skipped — passivity. ",
              "add_next=", DoubleToString(price, 5));
        return 0;
    }

    MqlTradeRequest req = {};
    MqlTradeResult  res = {};

    req.action       = TRADE_ACTION_PENDING;
    req.symbol       = symbol;
    req.volume       = BaseLotSize;
    req.price        = price;
    req.magic        = EA_MAGIC;
    req.type         = (direction == DIRECTION_BUY)
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

    g_pending_entry_ticket = res.order;
    SaveInventoryState();
    Print("INFO: Next entry limit placed. ticket=", res.order,
          " add_next=", DoubleToString(price, 5));
    return res.order;
}

void LogLayerExit(const Layer &layer, datetime exit_time,
                  double gross_pnl) {
    double holding_days = (double)(exit_time - layer.entry_time) / 86400.0;
    double carry_delta  = layer.entry_spread_raw - layer.entry_spread_adjusted;

    string instrument_str = (layer.instrument == INSTRUMENT_EURUSD)
                            ? "EURUSD"
                            : (layer.instrument == INSTRUMENT_GBPUSD)
                              ? "GBPUSD" : "EURGBP";

    Print("LAYER_EXIT | ",
          "instrument=",          instrument_str,
          " | direction=",        layer.direction,
          " | entry_price=",      DoubleToString(layer.entry_price, 5),
          " | entry_spread_raw=", DoubleToString(layer.entry_spread_raw, 6),
          " | entry_spread_adj=", DoubleToString(layer.entry_spread_adjusted, 6),
          " | exit_spread_tgt=",  DoubleToString(layer.exit_spread_target, 6),
          " | carry_delta=",      DoubleToString(carry_delta, 6),
          " | holding_days=",     DoubleToString(holding_days, 2),
          " | gross_pnl=",        DoubleToString(gross_pnl, 2),
          " | entry_time=",       TimeToString(layer.entry_time),
          " | exit_time=",        TimeToString(exit_time));
}

double GetH4ATR(string symbol) {
    double atr_buf[];
    ArraySetAsSeries(atr_buf, true);
    int handle = iATR(symbol, PERIOD_H4, 14);
    if (handle == INVALID_HANDLE) {
        Print("ERROR: GetH4ATR — iATR handle invalid for ", symbol);
        return 0.001;
    }
    if (CopyBuffer(handle, 0, 0, 1, atr_buf) < 1) {
        Print("ERROR: GetH4ATR — CopyBuffer failed for ", symbol);
        IndicatorRelease(handle);
        return 0.001;
    }
    IndicatorRelease(handle);
    return atr_buf[0];
}

void HandleUnmatchedFill(ulong order_ticket, double deal_volume,
                         datetime deal_time);

void HandleEntryFill(ulong deal_ticket, ulong order_ticket,
                     double deal_volume, double deal_price,
                     datetime deal_time, string deal_symbol) {
    int layer_idx = -1;
    for (int i = 0; i < ArraySize(g_inventory); i++) {
        if (g_inventory[i].entry_ticket == order_ticket) {
            layer_idx = i;
            break;
        }
    }

    if (layer_idx == -1) {
        if (ArraySize(g_inventory) >= MaxLayers) {
            Print("WARNING: Entry fill received but MaxLayers reached. ",
                  "ticket=", order_ticket);
            return;
        }

        Layer L = InitLayer();
        L.entry_price = deal_price;
        L.entry_time  = deal_time;

        double eu_ask = SymbolInfoDouble("EURUSD", SYMBOL_ASK);
        double eu_bid = SymbolInfoDouble("EURUSD", SYMBOL_BID);
        double gb_ask = SymbolInfoDouble("GBPUSD", SYMBOL_ASK);
        double gb_bid = SymbolInfoDouble("GBPUSD", SYMBOL_BID);

        if (ArraySize(g_inventory) == 0) {
            L.EU_mid_12bars_ago_at_entry = g_EU_mid_12bars_ago;
            L.GB_mid_12bars_ago_at_entry = g_GB_mid_12bars_ago;
            L.r_EU_at_entry              = g_r_EU_signal;
            L.r_GB_at_entry              = g_r_GB_signal;
            L.strongest_at_entry         = g_strongest;
            L.weakest_at_entry           = g_weakest;
            L.entry_price_eurusd_1h      = g_EU_mid_12bars_ago;
            L.entry_price_gbpusd_1h      = g_GB_mid_12bars_ago;
            {
                double eu_mid_l0 = (eu_ask + eu_bid) / 2.0;
                double gb_mid_l0 = (gb_ask + gb_bid) / 2.0;
                double r_EU_l0   = MathLog(eu_mid_l0
                                   / L.EU_mid_12bars_ago_at_entry);
                double r_GB_l0   = MathLog(gb_mid_l0
                                   / L.GB_mid_12bars_ago_at_entry);
                double usd_l0    = -(r_EU_l0 + r_GB_l0) / 3.0;
                double eur_l0    =   r_EU_l0 + usd_l0;
                double gbp_l0    =   r_GB_l0 + usd_l0;
                double scores_l0[3];
                scores_l0[0] = eur_l0;
                scores_l0[1] = gbp_l0;
                scores_l0[2] = usd_l0;
                L.entry_spread_raw      = scores_l0[L.weakest_at_entry]
                                        - scores_l0[L.strongest_at_entry];
                L.entry_spread_adjusted = L.entry_spread_raw;
            }
        } else {
            L.EU_mid_12bars_ago_at_entry = g_inventory[0].EU_mid_12bars_ago_at_entry;
            L.GB_mid_12bars_ago_at_entry = g_inventory[0].GB_mid_12bars_ago_at_entry;
            L.strongest_at_entry         = g_inventory[0].strongest_at_entry;
            L.weakest_at_entry           = g_inventory[0].weakest_at_entry;

            L.r_EU_at_entry = g_inventory[0].r_EU_at_entry;
            L.r_GB_at_entry = g_inventory[0].r_GB_at_entry;

            // 3. Inherit carry references from Layer 0 (Option A — Gemini ruling)
            //    All layers in the pod share the same carry baseline:
            //    the 1h-prior price at the time of the original pod signal.
            //    This keeps the RunCarryRecalculation() reference frame
            //    identical across all tranches, preserving parallel grid
            //    geometry. Slight carry overstatement for later layers is
            //    an accepted V1 approximation.
            L.entry_price_eurusd_1h = L.EU_mid_12bars_ago_at_entry;
            L.entry_price_gbpusd_1h = L.GB_mid_12bars_ago_at_entry;

            double eu_mid_now = (eu_ask + eu_bid) / 2.0;
            double gb_mid_now = (gb_ask + gb_bid) / 2.0;

            double r_EU_now = MathLog(eu_mid_now
                              / L.EU_mid_12bars_ago_at_entry);
            double r_GB_now = MathLog(gb_mid_now
                              / L.GB_mid_12bars_ago_at_entry);
            double usd_now  = -(r_EU_now + r_GB_now) / 3.0;
            double eur_now  =   r_EU_now + usd_now;
            double gbp_now  =   r_GB_now + usd_now;

            double scores_now[3];
            scores_now[0] = eur_now;
            scores_now[1] = gbp_now;
            scores_now[2] = usd_now;

            L.entry_spread_raw      = scores_now[L.weakest_at_entry]
                                    - scores_now[L.strongest_at_entry];
            L.entry_spread_adjusted = L.entry_spread_raw;
        }

        L.entry_price_eurusd = (eu_ask + eu_bid) / 2.0;
        L.entry_price_gbpusd = (gb_ask + gb_bid) / 2.0;

        if ((L.strongest_at_entry == 0 && L.weakest_at_entry == 1) ||
            (L.strongest_at_entry == 1 && L.weakest_at_entry == 0))
            L.instrument = INSTRUMENT_EURGBP;
        else if ((L.strongest_at_entry == 0 && L.weakest_at_entry == 2) ||
                 (L.strongest_at_entry == 2 && L.weakest_at_entry == 0))
            L.instrument = INSTRUMENT_EURUSD;
        else
            L.instrument = INSTRUMENT_GBPUSD;

        if ((L.strongest_at_entry == 0 && L.weakest_at_entry == 1) ||
            (L.strongest_at_entry == 0 && L.weakest_at_entry == 2) ||
            (L.strongest_at_entry == 1 && L.weakest_at_entry == 2))
            L.direction = DIRECTION_SELL;
        else
            L.direction = DIRECTION_BUY;
        L.lot_size               = BaseLotSize;
        L.remaining_entry_volume = BaseLotSize;
        L.remaining_exit_volume  = 0.0;
        L.entry_ticket    = order_ticket;
        L.position_ticket = (ulong)HistoryDealGetInteger(deal_ticket,
                                                         DEAL_POSITION_ID);

        L.exit_spread_target = ComputeExitSpreadTarget(L);
        double exit_price    = ComputeExitPrice(L);
        L.exit_target        = exit_price;

        double h4_atr = GetH4ATR(deal_symbol);
        if (L.direction == DIRECTION_BUY)
            L.add_next = deal_price - AddRatio * h4_atr;
        else
            L.add_next = deal_price + AddRatio * h4_atr;

        int new_idx = ArraySize(g_inventory);
        ArrayResize(g_inventory, new_idx + 1);
        g_inventory[new_idx] = L;
        layer_idx = new_idx;

        g_pending_entry_ticket = 0;
        SaveInventoryState();
    }

    g_inventory[layer_idx].remaining_entry_volume -= deal_volume;

    // Arm exit volume counter when entry is fully filled.
    // Runs on every entry fill — not just the first.
    // Double-arm guard: only fires once when crossing zero.
    if (g_inventory[layer_idx].remaining_entry_volume <= VOLUME_EPSILON &&
        g_inventory[layer_idx].remaining_exit_volume  == 0.0) {
        g_inventory[layer_idx].remaining_exit_volume =
            g_inventory[layer_idx].lot_size;
        Print("INFO: Entry complete — exit volume armed. Layer ",
              layer_idx);
    }

    double exit_price = g_inventory[layer_idx].exit_target;

    string exit_symbol = (g_inventory[layer_idx].instrument == INSTRUMENT_EURUSD)
                         ? "EURUSD"
                         : (g_inventory[layer_idx].instrument == INSTRUMENT_GBPUSD)
                           ? "GBPUSD" : "EURGBP";

    if (exit_price < 0.0) {
        Print("INFO: Marketable Reversion Exception. Exit target through "
              "market. Executing market hedge for Layer ", layer_idx);

        MqlTradeRequest req = {};
        MqlTradeResult  res = {};
        req.action   = TRADE_ACTION_DEAL;
        req.symbol   = exit_symbol;
        req.volume   = deal_volume;
        req.magic    = EA_MAGIC;
        req.type     = (g_inventory[layer_idx].direction == DIRECTION_BUY)
                       ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
        req.price    = (req.type == ORDER_TYPE_SELL)
                       ? SymbolInfoDouble(exit_symbol, SYMBOL_BID)
                       : SymbolInfoDouble(exit_symbol, SYMBOL_ASK);
        req.type_filling = ORDER_FILLING_IOC;
        req.comment  = "FXMatrix_Market_Hedge";

        if (!OrderSend(req, res)) {
            req.type_filling = ORDER_FILLING_FOK;
            if (!OrderSend(req, res)) {
                Print("ERROR: Market hedge OrderSend failed. retcode=",
                      res.retcode);
                g_halted = true;
                return;
            }
        }

        int n = ArraySize(g_inventory[layer_idx].exit_tickets);
        ArrayResize(g_inventory[layer_idx].exit_tickets, n + 1);
        g_inventory[layer_idx].exit_tickets[n] = res.order;
        SaveInventoryState();

        Print("INFO: Market hedge placed. ticket=", res.order,
              ". Awaiting CloseBy intercept.");
        return;
    }

    ulong exit_tkt = PlaceExitLimit(exit_price, deal_volume,
                                    g_inventory[layer_idx].direction,
                                    exit_symbol);
    if (exit_tkt > 0) {
        int n = ArraySize(g_inventory[layer_idx].exit_tickets);
        ArrayResize(g_inventory[layer_idx].exit_tickets, n + 1);
        g_inventory[layer_idx].exit_tickets[n] = exit_tkt;
        SaveInventoryState();
    }

    double filled_so_far   = g_inventory[layer_idx].lot_size
                           - g_inventory[layer_idx].remaining_entry_volume;
    bool   threshold_met   = filled_so_far >=
                             MinFillThreshold * g_inventory[layer_idx].lot_size;
    bool   next_not_placed = ArraySize(g_inventory) == layer_idx + 1;
    bool   capacity_ok     = ArraySize(g_inventory) < MaxLayers;

    if (threshold_met && next_not_placed && capacity_ok) {
        PlaceNextEntryLimit(g_inventory[layer_idx], deal_symbol);
        Print("INFO: Next layer triggered at add_next=",
              DoubleToString(g_inventory[layer_idx].add_next, 5));
    }
}

void HandleExitFill(ulong deal_ticket, ulong order_ticket,
                    double deal_volume, datetime deal_time,
                    double deal_profit,
                    ulong hedge_position_ticket = 0) {
    for (int i = 0; i < ArraySize(g_inventory); i++) {
        int n_tickets = ArraySize(g_inventory[i].exit_tickets);
        for (int j = 0; j < n_tickets; j++) {
            if (g_inventory[i].exit_tickets[j] == order_ticket) {
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

                g_inventory[i].remaining_exit_volume -= deal_volume;

                ArrayRemove(g_inventory[i].exit_tickets, j, 1);

                if (g_inventory[i].remaining_exit_volume <= VOLUME_EPSILON) {
                    LogLayerExit(g_inventory[i], deal_time, deal_profit);
                    ArrayRemove(g_inventory, i, 1);
                    Print("INFO: Layer ", i, " fully closed and removed.");

                    if (ArraySize(g_inventory) == 0) {
                        Print("INFO: Pod fully closed. Initiating "
                              "pending entry teardown.");
                        CancelAllPendingEntries();
                    }
                }

                // Save unconditionally: captures both partial volume
                // decrements and full layer removals.
                // Note: if CancelAllPendingEntries() was called above,
                // it already saves state — this is a no-op in terms
                // of correctness but harmless.
                SaveInventoryState();
                return;
            }
        }
    }

    HandleUnmatchedFill(order_ticket, deal_volume, deal_time);
}

void HandleUnmatchedFill(ulong order_ticket, double deal_volume,
                         datetime deal_time) {
    Print("WARNING: Exit fill not matched by ticket. ",
          "ticket=", order_ticket,
          " volume=", DoubleToString(deal_volume, 4),
          " Attempting fallback match...");

    for (int i = 0; i < ArraySize(g_inventory); i++) {
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

    Print("ERROR: Unmatched fill — no fallback match found. ",
          "ticket=", order_ticket,
          " Halting pod.");
    g_halted = true;
}

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest     &request,
                        const MqlTradeResult      &result) {
    if (trans.type != TRADE_TRANSACTION_DEAL_ADD) return;

    if (!HistoryDealSelect(trans.deal)) {
        Print("ERROR: HistoryDealSelect failed for deal ", trans.deal);
        return;
    }

    ulong    deal_ticket  = trans.deal;
    ulong    order_ticket = HistoryDealGetInteger(deal_ticket, DEAL_ORDER);
    double   deal_volume  = HistoryDealGetDouble(deal_ticket, DEAL_VOLUME);
    double   deal_price   = HistoryDealGetDouble(deal_ticket, DEAL_PRICE);
    long     deal_entry   = HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
    string   deal_symbol  = HistoryDealGetString(deal_ticket, DEAL_SYMBOL);
    datetime deal_time    = (datetime)HistoryDealGetInteger(deal_ticket,
                                                            DEAL_TIME);
    double   deal_profit  = HistoryDealGetDouble(deal_ticket, DEAL_PROFIT);

    if (deal_entry == DEAL_ENTRY_IN) {
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
            ulong new_hedge_position = (ulong)HistoryDealGetInteger(
                                           deal_ticket, DEAL_POSITION_ID);
            HandleExitFill(deal_ticket, order_ticket, deal_volume,
                           deal_time, deal_profit, new_hedge_position);
        } else {
            HandleEntryFill(deal_ticket, order_ticket, deal_volume,
                            deal_price, deal_time, deal_symbol);
        }
        return;
    }

    if (deal_entry == DEAL_ENTRY_OUT) {
        HandleExitFill(deal_ticket, order_ticket, deal_volume,
                       deal_time, deal_profit);
        return;
    }
}

#endif // EXECUTION_ENGINE_MQH
