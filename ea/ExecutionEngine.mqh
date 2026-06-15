#ifndef EXECUTION_ENGINE_MQH
#define EXECUTION_ENGINE_MQH

#include "MathEngine.mqh"
#include "StateEngine.mqh"

void CancelAllPendingEntries();

//------------------------------------------------------------------
// GetInstrumentFromSymbol
// Resolves the InstrumentType enum from a broker symbol string.
// Used throughout ExecutionEngine to route to the correct
// per-instrument inventory array.
//------------------------------------------------------------------
int GetInstrumentFromSymbol(string symbol) {
    if (symbol == "EURUSD") return INSTRUMENT_EURUSD;
    if (symbol == "GBPUSD") return INSTRUMENT_GBPUSD;
    return INSTRUMENT_EURGBP;
}

ulong PlaceEntryLimit(double price, int direction, string symbol) {
    double entry_price = price;

    // --- ADR-013: Gap-Aware Entry Price Clamp ---
    // If market has moved past theoretical entry (price improvement),
    // clamp to top of book passively rather than rejecting the signal.
    // Mirrors PlaceNextEntryLimit() gap-aware logic from Phase 3.
    if (entry_price > 0.0) {
        int    stops_level = (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
        int    digits      = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
        double point       = SymbolInfoDouble(symbol, SYMBOL_POINT);
        double min_dist    = stops_level * point;

        double theoretical = entry_price;

        if (direction == DIRECTION_BUY) {
            double current_bid = SymbolInfoDouble(symbol, SYMBOL_BID);
            if (current_bid > 0.0)
                entry_price = NormalizeDouble(
                    MathMin(theoretical, current_bid - min_dist), digits);
        } else {
            double current_ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
            if (current_ask > 0.0)
                entry_price = NormalizeDouble(
                    MathMax(theoretical, current_ask + min_dist), digits);
        }

        if (MathAbs(entry_price - theoretical) > point) {
            Print("INFO: ADR-013 entry clamp applied. ",
                  "symbol=", symbol,
                  " theoretical=", DoubleToString(theoretical, digits),
                  " clamped=",     DoubleToString(entry_price, digits),
                  " improvement=", DoubleToString(
                      MathAbs(entry_price - theoretical) / point, 1), " pts");
        }
    }
    // --- End ADR-013 ---

    if (!IsClearOfFreezeLevel(entry_price, direction, symbol)) {
        Print("INFO: PlaceEntryLimit skipped — freeze level. ",
              "symbol=", symbol, " price=", DoubleToString(entry_price, 5));
        return 0;
    }

    if (!IsPassive(entry_price, direction, symbol)) {
        Print("INFO: PlaceEntryLimit skipped — passivity failure. ",
              "symbol=", symbol, " price=", DoubleToString(entry_price, 5));
        return 0;
    }

    MqlTradeRequest req = {};
    MqlTradeResult  res = {};

    req.action       = TRADE_ACTION_PENDING;
    req.symbol       = symbol;
    req.volume       = BaseLotSize;
    req.price        = entry_price;
    req.magic        = EA_MAGIC;
    req.type         = (direction == DIRECTION_BUY)
                       ? ORDER_TYPE_BUY_LIMIT
                       : ORDER_TYPE_SELL_LIMIT;
    req.type_filling = ORDER_FILLING_RETURN;
    req.type_time    = ORDER_TIME_GTC;
    req.comment      = "FXMatrix_Entry";

    if (!OrderSend(req, res)) {
        Print("ERROR: PlaceEntryLimit OrderSend failed. ",
              "retcode=", res.retcode,
              " symbol=", symbol,
              " price=", DoubleToString(entry_price, 5));
        return 0;
    }

    Print("INFO: Entry limit placed. ticket=", res.order,
          " symbol=", symbol,
          " price=", DoubleToString(entry_price, 5),
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

ulong PlaceNextEntryLimit(const Layer &prev_layer, string symbol,
                          double price_override = -1.0) {
    // Gap-aware passive pricing (Gemini Phase 3 ruling Q4/Q5).
    // Always passive — never cross the spread regardless of gaps.
    // Applied universally to all add_next placements.
    double price = (price_override > 0.0) ? price_override : prev_layer.add_next;

    if (prev_layer.direction == DIRECTION_BUY) {
        // BUY limit: use minimum of computed level and current bid
        // If market gapped below computed level, join top of book passively
        double current_bid = SymbolInfoDouble(symbol, SYMBOL_BID);
        if (current_bid > 0.0)
            price = MathMin(price, current_bid);
    } else {
        // SELL limit: use maximum of computed level and current ask
        // If market gapped above computed level, join top of book passively
        double current_ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
        if (current_ask > 0.0)
            price = MathMax(price, current_ask);
    }

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
    req.comment      = "FXMatrix_AddNext";

    if (!OrderSend(req, res)) {
        Print("ERROR: PlaceNextEntryLimit failed. retcode=", res.retcode);
        return 0;
    }

    int instrument = GetInstrumentFromSymbol(symbol);
    if (instrument == INSTRUMENT_EURUSD)      g_add_next_EURUSD = res.order;
    else if (instrument == INSTRUMENT_GBPUSD)  g_add_next_GBPUSD = res.order;
    else                                        g_add_next_EURGBP = res.order;

    SaveAllInventoryState();
    Print("INFO: Next entry limit placed (add_next). ticket=", res.order,
          " symbol=", symbol,
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

//------------------------------------------------------------------
// ComputeNextLayerPrice
// Returns the physical broker price at which the spread model
// will cross layer_threshold(next_layer_idx).
// Uses a differential approach anchored to deal_price at fill
// time — eliminates anchor-drift staleness risk.
// Directionality is implicit: InvertSpreadToPrice() returns
// prices below deal_price for BUY (add_next must be lower)
// and above deal_price for SELL (add_next must be higher).
//------------------------------------------------------------------
double ComputeNextLayerPrice(int    next_layer_idx,
                             int    instrument,
                             int    direction,
                             double deal_price) {

    // V2 Phase 1: parameterised grid interval and skew.
    // S = ComputeGridInterval(next_layer_idx) — varies by layer and GridMode.
    // skew = ComputeSkew(next_layer_idx) — varies by layer and SkewMode.
    // Invariant: |add_next - entry| > |exit - entry| holds for skew < 1.

    double S    = ComputeGridInterval(next_layer_idx, instrument);
    double skew = ComputeSkew(next_layer_idx);

    if (S <= 0.0) {
        Print("SEV-2: ComputeNextLayerPrice — S <= 0. ",
              "next_layer_idx=", next_layer_idx,
              " GridMode=", GridMode);
        return -1.0;
    }

    int strongest = 0;
    int weakest   = 0;
    if (instrument == INSTRUMENT_EURGBP) {
        if (direction == DIRECTION_BUY)  { strongest = 1; weakest = 0; }
        else                              { strongest = 0; weakest = 1; }
    } else if (instrument == INSTRUMENT_EURUSD) {
        if (direction == DIRECTION_BUY)  { strongest = 2; weakest = 0; }
        else                              { strongest = 0; weakest = 2; }
    } else {
        if (direction == DIRECTION_BUY)  { strongest = 2; weakest = 1; }
        else                              { strongest = 1; weakest = 2; }
    }

    // Read entry_spread from the correct per-instrument array.
    // next_layer_idx is post-append ArraySize; filled layer is at index next_layer_idx-1.
    double entry_spread = 0.0;
    if (instrument == INSTRUMENT_EURUSD)
        entry_spread = g_inventory_EURUSD[next_layer_idx - 1].entry_spread_raw;
    else if (instrument == INSTRUMENT_GBPUSD)
        entry_spread = g_inventory_GBPUSD[next_layer_idx - 1].entry_spread_raw;
    else
        entry_spread = g_inventory_EURGBP[next_layer_idx - 1].entry_spread_raw;

    // add_next = entry_spread - S - S*(1-skew)
    // Guarantees |add_next - entry| > |exit - entry| for all skew < 1.
    double add_next_spread = entry_spread - S - S * (1.0 - skew);

    double price_add_next = InvertSpreadToPrice(
        g_EU_mid_12bars_ago,
        g_GB_mid_12bars_ago,
        g_r_EU_signal,
        g_r_GB_signal,
        add_next_spread,
        strongest,
        weakest,
        false,
        false);   // enforce_passivity=false — pure math inversion

    if (price_add_next <= 0.0) {
        Print("SEV-2: ComputeNextLayerPrice — inversion returned sentinel. ",
              "add_next_spread=", DoubleToString(add_next_spread, 8),
              " S=", DoubleToString(S, 8),
              " skew=", DoubleToString(skew, 4),
              " next_layer_idx=", next_layer_idx);
        return -1.0;
    }

    return price_add_next;
}

void HandleUnmatchedFill(ulong order_ticket, double deal_volume,
                         datetime deal_time);

void HandleEntryFill(ulong deal_ticket, ulong order_ticket,
                     double deal_volume, double deal_price,
                     datetime deal_time, string deal_symbol,
                     long deal_type) {

    // Resolve instrument from physical fill symbol
    int instrument = GetInstrumentFromSymbol(deal_symbol);

    // If the filling ticket IS the resting add_next limit, it is now off
    // the book. Clear the global before any further logic runs.
    // This prevents the deadlock where cur_add_next stays non-zero and
    // blocks PlaceNextEntryLimit() from firing on the new layer.
    ulong cur_add_next = (instrument == INSTRUMENT_EURUSD) ? g_add_next_EURUSD
                       : (instrument == INSTRUMENT_GBPUSD) ? g_add_next_GBPUSD
                       : g_add_next_EURGBP;

    if (order_ticket == cur_add_next) {
        if (instrument == INSTRUMENT_EURUSD)      g_add_next_EURUSD = 0;
        else if (instrument == INSTRUMENT_GBPUSD)  g_add_next_GBPUSD = 0;
        else                                        g_add_next_EURGBP = 0;
        cur_add_next = 0;   // sync local variable
    }

    // Resolve correct per-instrument array reference via instrument
    // MQL5 does not allow array refs — use instrument enum throughout.

    int layer_idx = -1;

    // Search per-instrument array for existing layer with this ticket
    if (instrument == INSTRUMENT_EURUSD) {
        for (int i = 0; i < ArraySize(g_inventory_EURUSD); i++) {
            if (g_inventory_EURUSD[i].entry_ticket == order_ticket) {
                layer_idx = i; break;
            }
        }
    } else if (instrument == INSTRUMENT_GBPUSD) {
        for (int i = 0; i < ArraySize(g_inventory_GBPUSD); i++) {
            if (g_inventory_GBPUSD[i].entry_ticket == order_ticket) {
                layer_idx = i; break;
            }
        }
    } else {
        for (int i = 0; i < ArraySize(g_inventory_EURGBP); i++) {
            if (g_inventory_EURGBP[i].entry_ticket == order_ticket) {
                layer_idx = i; break;
            }
        }
    }

    // Helper macro to get current array size for this instrument
    int inv_size = (instrument == INSTRUMENT_EURUSD) ? ArraySize(g_inventory_EURUSD)
                 : (instrument == INSTRUMENT_GBPUSD) ? ArraySize(g_inventory_GBPUSD)
                 : ArraySize(g_inventory_EURGBP);

    if (layer_idx == -1) {
        if (inv_size >= MaxLayers) {
            Print("WARNING: Entry fill received but MaxLayers reached. ",
                  "ticket=", order_ticket);
            return;
        }

        layer_idx = inv_size;

        // Alien fill guard — reject fills on wrong instrument for open pod
        if (layer_idx > 0) {
            int pod_instrument = INSTRUMENT_EURGBP;
            if (instrument == INSTRUMENT_EURUSD && ArraySize(g_inventory_EURUSD) > 0)
                pod_instrument = INSTRUMENT_EURUSD;
            else if (instrument == INSTRUMENT_GBPUSD && ArraySize(g_inventory_GBPUSD) > 0)
                pod_instrument = INSTRUMENT_GBPUSD;
            else if (instrument == INSTRUMENT_EURGBP && ArraySize(g_inventory_EURGBP) > 0)
                pod_instrument = INSTRUMENT_EURGBP;

            string expected_symbol = (instrument == INSTRUMENT_EURUSD) ? "EURUSD"
                                   : (instrument == INSTRUMENT_GBPUSD) ? "GBPUSD"
                                   : "EURGBP";
            if (deal_symbol != expected_symbol) {
                Print("SEV-1: ALIEN FILL REJECTED. deal_symbol=", deal_symbol,
                      " expected=", expected_symbol,
                      " ticket=", deal_ticket);
                g_halted = true;
                return;
            }
        }

        Layer L = InitLayer();
        L.entry_price = deal_price;
        L.entry_time  = deal_time;

        // Set layer_index — mandatory Phase 2 addition
        L.layer_index = layer_idx;

        double eu_ask = SymbolInfoDouble("EURUSD", SYMBOL_ASK);
        double eu_bid = SymbolInfoDouble("EURUSD", SYMBOL_BID);
        double gb_ask = SymbolInfoDouble("GBPUSD", SYMBOL_ASK);
        double gb_bid = SymbolInfoDouble("GBPUSD", SYMBOL_BID);

        if (layer_idx == 0) {
            L.EU_mid_12bars_ago_at_entry = g_EU_mid_12bars_ago;
            L.GB_mid_12bars_ago_at_entry = g_GB_mid_12bars_ago;
            L.r_EU_at_entry              = g_r_EU_signal;
            L.r_GB_at_entry              = g_r_GB_signal;
            L.entry_price_eurusd_1h      = g_EU_mid_12bars_ago;
            L.entry_price_gbpusd_1h      = g_GB_mid_12bars_ago;

            if      (deal_symbol == "EURUSD") L.instrument = INSTRUMENT_EURUSD;
            else if (deal_symbol == "GBPUSD") L.instrument = INSTRUMENT_GBPUSD;
            else if (deal_symbol == "EURGBP") L.instrument = INSTRUMENT_EURGBP;
            else {
                Print("SEV-1 ERROR: HandleEntryFill — unrecognised deal_symbol=",
                      deal_symbol, ". Halting.");
                g_halted = true;
                return;
            }

            L.direction = (deal_type == DEAL_TYPE_BUY)
                          ? DIRECTION_BUY : DIRECTION_SELL;

            if (L.instrument == INSTRUMENT_EURGBP) {
                if (L.direction == DIRECTION_BUY)  { L.strongest_at_entry = 1; L.weakest_at_entry = 0; }
                else                               { L.strongest_at_entry = 0; L.weakest_at_entry = 1; }
            } else if (L.instrument == INSTRUMENT_EURUSD) {
                if (L.direction == DIRECTION_BUY)  { L.strongest_at_entry = 2; L.weakest_at_entry = 0; }
                else                               { L.strongest_at_entry = 0; L.weakest_at_entry = 2; }
            } else {
                if (L.direction == DIRECTION_BUY)  { L.strongest_at_entry = 2; L.weakest_at_entry = 1; }
                else                               { L.strongest_at_entry = 1; L.weakest_at_entry = 2; }
            }

            {
                double eu_mid_l0 = (eu_ask + eu_bid) / 2.0;
                double gb_mid_l0 = (gb_ask + gb_bid) / 2.0;
                double r_EU_l0   = MathLog(eu_mid_l0 / L.EU_mid_12bars_ago_at_entry);
                double r_GB_l0   = MathLog(gb_mid_l0 / L.GB_mid_12bars_ago_at_entry);
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
            // Layer 1+: inherit from Layer 0 of same instrument
            Layer L0;
            if (instrument == INSTRUMENT_EURUSD)      L0 = g_inventory_EURUSD[0];
            else if (instrument == INSTRUMENT_GBPUSD)  L0 = g_inventory_GBPUSD[0];
            else                                        L0 = g_inventory_EURGBP[0];

            L.EU_mid_12bars_ago_at_entry = L0.EU_mid_12bars_ago_at_entry;
            L.GB_mid_12bars_ago_at_entry = L0.GB_mid_12bars_ago_at_entry;
            L.strongest_at_entry         = L0.strongest_at_entry;
            L.weakest_at_entry           = L0.weakest_at_entry;
            L.r_EU_at_entry              = L0.r_EU_at_entry;
            L.r_GB_at_entry              = L0.r_GB_at_entry;
            L.entry_price_eurusd_1h      = L0.EU_mid_12bars_ago_at_entry;
            L.entry_price_gbpusd_1h      = L0.GB_mid_12bars_ago_at_entry;

            double eu_mid_now = (eu_ask + eu_bid) / 2.0;
            double gb_mid_now = (gb_ask + gb_bid) / 2.0;
            double r_EU_now   = MathLog(eu_mid_now / L.EU_mid_12bars_ago_at_entry);
            double r_GB_now   = MathLog(gb_mid_now / L.GB_mid_12bars_ago_at_entry);
            double usd_now    = -(r_EU_now + r_GB_now) / 3.0;
            double eur_now    =   r_EU_now + usd_now;
            double gbp_now    =   r_GB_now + usd_now;
            double scores_now[3];
            scores_now[0] = eur_now;
            scores_now[1] = gbp_now;
            scores_now[2] = usd_now;
            L.entry_spread_raw      = scores_now[L.weakest_at_entry]
                                    - scores_now[L.strongest_at_entry];
            L.entry_spread_adjusted = L.entry_spread_raw;

            // Instrument and direction from Layer 0
            L.instrument = L0.instrument;
            L.direction  = L0.direction;
        }

        L.entry_price_eurusd = (eu_ask + eu_bid) / 2.0;
        L.entry_price_gbpusd = (gb_ask + gb_bid) / 2.0;

        // Phase 3: dynamic lot sizing — reduces capital deployed as pod bleeds
        double balance   = AccountInfoDouble(ACCOUNT_BALANCE);
        double pod_pnl   = GetPodUnrealizedPnL(instrument);
        double size_mult = 1.0;
        if (balance > 0.0 && MaxPodDrawdown > 0.0)
            size_mult = MathMax(1.0 - K_size *
                                (MathAbs(pod_pnl) / (balance * MaxPodDrawdown)),
                                0.0);
        double min_vol   = SymbolInfoDouble(deal_symbol, SYMBOL_VOLUME_MIN);
        double lot_size  = MathMax(BaseLotSize * size_mult, min_vol);

        // LDAK: volatility-gated lot size penalty
        {
            double S_eff = 0.0;
            int    inv_eu = ArraySize(g_inventory_EURUSD);
            int    inv_gu = ArraySize(g_inventory_GBPUSD);
            int    inv_eg = ArraySize(g_inventory_EURGBP);

            if (instrument == INSTRUMENT_EURUSD) {
                if (inv_gu > 0) {
                    double v_eff = MathMax(g_vratio_EU, g_vratio_GU);
                    double S = MathMax(g_r_EU_GU, 0.0) * MathMax(v_eff - 1.0, 0.0);
                    S_eff = MathMax(S_eff, S);
                }
                if (inv_eg > 0) {
                    double v_eff = MathMax(g_vratio_EU, g_vratio_EG);
                    double S = MathMax(g_r_EU_EG, 0.0) * MathMax(v_eff - 1.0, 0.0);
                    S_eff = MathMax(S_eff, S);
                }
            } else if (instrument == INSTRUMENT_GBPUSD) {
                if (inv_eu > 0) {
                    double v_eff = MathMax(g_vratio_GU, g_vratio_EU);
                    double S = MathMax(g_r_EU_GU, 0.0) * MathMax(v_eff - 1.0, 0.0);
                    S_eff = MathMax(S_eff, S);
                }
                if (inv_eg > 0) {
                    double v_eff = MathMax(g_vratio_GU, g_vratio_EG);
                    double S = MathMax(g_r_GU_EG, 0.0) * MathMax(v_eff - 1.0, 0.0);
                    S_eff = MathMax(S_eff, S);
                }
            } else {
                if (inv_eu > 0) {
                    double v_eff = MathMax(g_vratio_EG, g_vratio_EU);
                    double S = MathMax(g_r_EU_EG, 0.0) * MathMax(v_eff - 1.0, 0.0);
                    S_eff = MathMax(S_eff, S);
                }
                if (inv_gu > 0) {
                    double v_eff = MathMax(g_vratio_EG, g_vratio_GU);
                    double S = MathMax(g_r_GU_EG, 0.0) * MathMax(v_eff - 1.0, 0.0);
                    S_eff = MathMax(S_eff, S);
                }
            }

            double w = 1.0 / (1.0 + S_eff * S_eff);
            lot_size = MathMax(lot_size * w, SymbolInfoDouble(deal_symbol, SYMBOL_VOLUME_MIN));

            if (EnableVerboseLog && S_eff > 0.0)
                Print("INFO: LDAK S_eff=", DoubleToString(S_eff, 4),
                      " w=", DoubleToString(w, 4),
                      " lot_size=", DoubleToString(lot_size, 2),
                      " instrument=", deal_symbol);
        }

        L.lot_size               = lot_size;
        L.remaining_entry_volume = lot_size;
        L.remaining_exit_volume  = 0.0;
        L.entry_ticket    = order_ticket;
        L.position_ticket = (ulong)HistoryDealGetInteger(deal_ticket,
                                                         DEAL_POSITION_ID);

        double S    = ComputeGridInterval(layer_idx);
        double skew = ComputeSkew(layer_idx);
        L.exit_spread_target = L.entry_spread_adjusted + S * skew;
        double exit_price    = ComputeExitPrice(L);
        L.exit_target        = exit_price;

        // Append to correct per-instrument array
        if (instrument == INSTRUMENT_EURUSD) {
            ArrayResize(g_inventory_EURUSD, layer_idx + 1);
            g_inventory_EURUSD[layer_idx] = L;
        } else if (instrument == INSTRUMENT_GBPUSD) {
            ArrayResize(g_inventory_GBPUSD, layer_idx + 1);
            g_inventory_GBPUSD[layer_idx] = L;
        } else {
            ArrayResize(g_inventory_EURGBP, layer_idx + 1);
            g_inventory_EURGBP[layer_idx] = L;
        }

        // next_layer_idx: ArraySize AFTER current layer appended
        int next_layer_idx = (instrument == INSTRUMENT_EURUSD) ? ArraySize(g_inventory_EURUSD)
                           : (instrument == INSTRUMENT_GBPUSD) ? ArraySize(g_inventory_GBPUSD)
                           : ArraySize(g_inventory_EURGBP);

        double computed_next = ComputeNextLayerPrice(
            next_layer_idx,
            L.instrument,
            L.direction,
            deal_price);

        if (computed_next <= 0.0) {
            Print("SEV-2: HandleEntryFill — add_next sentinel (-1.0). ",
                  "Layering skipped. next_layer_idx=", next_layer_idx);
            if (instrument == INSTRUMENT_EURUSD)      g_inventory_EURUSD[layer_idx].add_next = 0.0;
            else if (instrument == INSTRUMENT_GBPUSD)  g_inventory_GBPUSD[layer_idx].add_next = 0.0;
            else                                        g_inventory_EURGBP[layer_idx].add_next = 0.0;
        } else if (MathAbs(computed_next - deal_price) > deal_price * 0.05) {
            Print("SEV-2: HandleEntryFill — add_next deviation > 5%. ",
                  "computed=", computed_next, " deal_price=", deal_price,
                  " Layering skipped.");
            if (instrument == INSTRUMENT_EURUSD)      g_inventory_EURUSD[layer_idx].add_next = 0.0;
            else if (instrument == INSTRUMENT_GBPUSD)  g_inventory_GBPUSD[layer_idx].add_next = 0.0;
            else                                        g_inventory_EURGBP[layer_idx].add_next = 0.0;
        } else {
            if (instrument == INSTRUMENT_EURUSD)      g_inventory_EURUSD[layer_idx].add_next = computed_next;
            else if (instrument == INSTRUMENT_GBPUSD)  g_inventory_GBPUSD[layer_idx].add_next = computed_next;
            else                                        g_inventory_EURGBP[layer_idx].add_next = computed_next;
        }

        // Clear per-instrument pending entry ticket
        if (instrument == INSTRUMENT_EURUSD)      g_pending_entry_EURUSD = 0;
        else if (instrument == INSTRUMENT_GBPUSD)  g_pending_entry_GBPUSD = 0;
        else                                        g_pending_entry_EURGBP = 0;

        SaveAllInventoryState();
    }

    // Decrement remaining entry volume on correct array
    if (instrument == INSTRUMENT_EURUSD)
        g_inventory_EURUSD[layer_idx].remaining_entry_volume -= deal_volume;
    else if (instrument == INSTRUMENT_GBPUSD)
        g_inventory_GBPUSD[layer_idx].remaining_entry_volume -= deal_volume;
    else
        g_inventory_EURGBP[layer_idx].remaining_entry_volume -= deal_volume;

    // Arm exit volume when entry fully filled
    double rem_entry = (instrument == INSTRUMENT_EURUSD) ? g_inventory_EURUSD[layer_idx].remaining_entry_volume
                     : (instrument == INSTRUMENT_GBPUSD) ? g_inventory_GBPUSD[layer_idx].remaining_entry_volume
                     : g_inventory_EURGBP[layer_idx].remaining_entry_volume;
    double rem_exit  = (instrument == INSTRUMENT_EURUSD) ? g_inventory_EURUSD[layer_idx].remaining_exit_volume
                     : (instrument == INSTRUMENT_GBPUSD) ? g_inventory_GBPUSD[layer_idx].remaining_exit_volume
                     : g_inventory_EURGBP[layer_idx].remaining_exit_volume;

    if (rem_entry <= VOLUME_EPSILON && rem_exit == 0.0) {
        double lot = (instrument == INSTRUMENT_EURUSD) ? g_inventory_EURUSD[layer_idx].lot_size
                   : (instrument == INSTRUMENT_GBPUSD) ? g_inventory_GBPUSD[layer_idx].lot_size
                   : g_inventory_EURGBP[layer_idx].lot_size;
        if (instrument == INSTRUMENT_EURUSD)      g_inventory_EURUSD[layer_idx].remaining_exit_volume = lot;
        else if (instrument == INSTRUMENT_GBPUSD)  g_inventory_GBPUSD[layer_idx].remaining_exit_volume = lot;
        else                                        g_inventory_EURGBP[layer_idx].remaining_exit_volume = lot;
        Print("INFO: Entry complete — exit volume armed. Layer ", layer_idx,
              " instrument=", deal_symbol);
    }

    // Resolve layer reference for exit placement
    Layer CurL = (instrument == INSTRUMENT_EURUSD) ? g_inventory_EURUSD[layer_idx]
               : (instrument == INSTRUMENT_GBPUSD) ? g_inventory_GBPUSD[layer_idx]
               : g_inventory_EURGBP[layer_idx];

    double exit_price = CurL.exit_target;
    string exit_symbol = deal_symbol;

    if (exit_price < 0.0) {
        Print("INFO: Marketable Reversion Exception. Layer ", layer_idx);

        MqlTradeRequest req = {};
        MqlTradeResult  res = {};
        req.action   = TRADE_ACTION_DEAL;
        req.symbol   = exit_symbol;
        req.volume   = deal_volume;
        req.magic    = EA_MAGIC;
        req.type     = (CurL.direction == DIRECTION_BUY)
                       ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
        req.price    = (req.type == ORDER_TYPE_SELL)
                       ? SymbolInfoDouble(exit_symbol, SYMBOL_BID)
                       : SymbolInfoDouble(exit_symbol, SYMBOL_ASK);
        req.type_filling = ORDER_FILLING_IOC;
        req.comment  = "FXMatrix_Market_Hedge";

        if (!OrderSend(req, res)) {
            req.type_filling = ORDER_FILLING_FOK;
            if (!OrderSend(req, res)) {
                Print("ERROR: Market hedge OrderSend failed. retcode=", res.retcode);
                g_halted = true;
                return;
            }
        }

        int n = ArraySize(CurL.exit_tickets);
        if (instrument == INSTRUMENT_EURUSD) {
            ArrayResize(g_inventory_EURUSD[layer_idx].exit_tickets, n + 1);
            g_inventory_EURUSD[layer_idx].exit_tickets[n] = res.order;
        } else if (instrument == INSTRUMENT_GBPUSD) {
            ArrayResize(g_inventory_GBPUSD[layer_idx].exit_tickets, n + 1);
            g_inventory_GBPUSD[layer_idx].exit_tickets[n] = res.order;
        } else {
            ArrayResize(g_inventory_EURGBP[layer_idx].exit_tickets, n + 1);
            g_inventory_EURGBP[layer_idx].exit_tickets[n] = res.order;
        }
        SaveAllInventoryState();
        Print("INFO: Market hedge placed. ticket=", res.order,
              ". Awaiting CloseBy intercept.");
        return;
    }

    ulong exit_tkt = PlaceExitLimit(exit_price, deal_volume,
                                    CurL.direction, exit_symbol);
    if (exit_tkt > 0) {
        int n = ArraySize(CurL.exit_tickets);
        if (instrument == INSTRUMENT_EURUSD) {
            ArrayResize(g_inventory_EURUSD[layer_idx].exit_tickets, n + 1);
            g_inventory_EURUSD[layer_idx].exit_tickets[n] = exit_tkt;
        } else if (instrument == INSTRUMENT_GBPUSD) {
            ArrayResize(g_inventory_GBPUSD[layer_idx].exit_tickets, n + 1);
            g_inventory_GBPUSD[layer_idx].exit_tickets[n] = exit_tkt;
        } else {
            ArrayResize(g_inventory_EURGBP[layer_idx].exit_tickets, n + 1);
            g_inventory_EURGBP[layer_idx].exit_tickets[n] = exit_tkt;
        }
        SaveAllInventoryState();
    }

    // Re-read CurL after modifications
    CurL = (instrument == INSTRUMENT_EURUSD) ? g_inventory_EURUSD[layer_idx]
         : (instrument == INSTRUMENT_GBPUSD) ? g_inventory_GBPUSD[layer_idx]
         : g_inventory_EURGBP[layer_idx];

    double filled_so_far = CurL.lot_size - CurL.remaining_entry_volume;
    bool threshold_met   = filled_so_far >= MinFillThreshold * CurL.lot_size;
    int  cur_inv_size    = (instrument == INSTRUMENT_EURUSD) ? ArraySize(g_inventory_EURUSD)
                         : (instrument == INSTRUMENT_GBPUSD) ? ArraySize(g_inventory_GBPUSD)
                         : ArraySize(g_inventory_EURGBP);
    bool next_not_placed = cur_inv_size == layer_idx + 1;
    bool capacity_ok     = cur_inv_size < MaxLayers;

    if (threshold_met && next_not_placed && capacity_ok && cur_add_next == 0) {
        // Phase 3: sleep gate — mandatory interval between layer adds
        datetime last_layer = (instrument == INSTRUMENT_EURUSD)
                              ? g_last_layer_time_EURUSD
                              : (instrument == INSTRUMENT_GBPUSD)
                              ? g_last_layer_time_GBPUSD
                              : g_last_layer_time_EURGBP;

        if (TimeCurrent() - last_layer < MinLayerIntervalSeconds) {
            Print("INFO: Layer interval sleep active. Skipping add_next. ",
                  "instrument=", deal_symbol,
                  " remaining=", MinLayerIntervalSeconds -
                  (int)(TimeCurrent() - last_layer), "s");
            // add_next NOT placed. OnTick re-arm will fire when sleep expires.
        } else {
            PlaceNextEntryLimit(CurL, deal_symbol);
            // Update last layer timestamp for this instrument
            if (instrument == INSTRUMENT_EURUSD)
                g_last_layer_time_EURUSD = TimeCurrent();
            else if (instrument == INSTRUMENT_GBPUSD)
                g_last_layer_time_GBPUSD = TimeCurrent();
            else
                g_last_layer_time_EURGBP = TimeCurrent();
            Print("INFO: Next layer triggered at add_next=",
                  DoubleToString(CurL.add_next, 5));
        }
    }
}

void HandleExitFill(ulong deal_ticket, ulong order_ticket,
                    double deal_volume, datetime deal_time,
                    double deal_profit,
                    ulong hedge_position_ticket = 0) {

    // Search all three per-instrument arrays for the matching exit ticket
    // Use explicit array to decouple from enum integer values (Gemini ruling)
    int target_instruments[3] = {INSTRUMENT_EURUSD, INSTRUMENT_GBPUSD, INSTRUMENT_EURGBP};

    for (int k = 0; k < 3; k++) {
        int inst = target_instruments[k];
        int inv_size = (inst == INSTRUMENT_EURUSD) ? ArraySize(g_inventory_EURUSD)
                     : (inst == INSTRUMENT_GBPUSD) ? ArraySize(g_inventory_GBPUSD)
                     : ArraySize(g_inventory_EURGBP);

        for (int i = 0; i < inv_size; i++) {
            Layer CurL = (inst == INSTRUMENT_EURUSD) ? g_inventory_EURUSD[i]
                       : (inst == INSTRUMENT_GBPUSD) ? g_inventory_GBPUSD[i]
                       : g_inventory_EURGBP[i];

            int n_tickets = ArraySize(CurL.exit_tickets);
            for (int j = 0; j < n_tickets; j++) {
                if (CurL.exit_tickets[j] != order_ticket) continue;

                // Found matching exit ticket
                if (hedge_position_ticket > 0 && CurL.position_ticket > 0) {
                    string exit_symbol = (inst == INSTRUMENT_EURUSD) ? "EURUSD"
                                       : (inst == INSTRUMENT_GBPUSD) ? "GBPUSD"
                                       : "EURGBP";

                    if (!PositionSelectByTicket(hedge_position_ticket)) {
                        int q_idx = ArraySize(g_closeby_queue);
                        ArrayResize(g_closeby_queue, q_idx + 1);
                        g_closeby_queue[q_idx].ticket1 = CurL.position_ticket;
                        g_closeby_queue[q_idx].ticket2 = hedge_position_ticket;
                        g_closeby_queue[q_idx].retries = 0;
                        Print("INFO: Ledger desync detected. CloseBy queued. ",
                              "position=", CurL.position_ticket,
                              " position_by=", hedge_position_ticket);
                    } else {
                        MqlTradeRequest close_req = {};
                        MqlTradeResult  close_res = {};
                        close_req.action      = TRADE_ACTION_CLOSE_BY;
                        close_req.position    = CurL.position_ticket;
                        close_req.position_by = hedge_position_ticket;
                        close_req.symbol      = exit_symbol;
                        close_req.magic       = EA_MAGIC;

                        if (!OrderSend(close_req, close_res)) {
                            if (close_res.retcode == 10013) {
                                int q_idx = ArraySize(g_closeby_queue);
                                ArrayResize(g_closeby_queue, q_idx + 1);
                                g_closeby_queue[q_idx].ticket1 = CurL.position_ticket;
                                g_closeby_queue[q_idx].ticket2 = hedge_position_ticket;
                                g_closeby_queue[q_idx].retries = 0;
                                Print("INFO: CloseBy retcode=10013. Queued. ",
                                      "position=", CurL.position_ticket,
                                      " position_by=", hedge_position_ticket);
                            } else {
                                Print("ERROR: CloseBy failed. position=",
                                      CurL.position_ticket,
                                      " position_by=", hedge_position_ticket,
                                      " retcode=", close_res.retcode);
                            }
                        }
                    }
                }

                // Decrement remaining exit volume
                if (inst == INSTRUMENT_EURUSD)
                    g_inventory_EURUSD[i].remaining_exit_volume -= deal_volume;
                else if (inst == INSTRUMENT_GBPUSD)
                    g_inventory_GBPUSD[i].remaining_exit_volume -= deal_volume;
                else
                    g_inventory_EURGBP[i].remaining_exit_volume -= deal_volume;

                // Remove the matched exit ticket
                if (inst == INSTRUMENT_EURUSD)
                    ArrayRemove(g_inventory_EURUSD[i].exit_tickets, j, 1);
                else if (inst == INSTRUMENT_GBPUSD)
                    ArrayRemove(g_inventory_GBPUSD[i].exit_tickets, j, 1);
                else
                    ArrayRemove(g_inventory_EURGBP[i].exit_tickets, j, 1);

                // Re-read after modification
                CurL = (inst == INSTRUMENT_EURUSD) ? g_inventory_EURUSD[i]
                     : (inst == INSTRUMENT_GBPUSD) ? g_inventory_GBPUSD[i]
                     : g_inventory_EURGBP[i];

                if (CurL.remaining_exit_volume <= VOLUME_EPSILON) {
                    LogLayerExit(CurL, deal_time, deal_profit);
                    if (inst == INSTRUMENT_EURUSD)      ArrayRemove(g_inventory_EURUSD, i, 1);
                    else if (inst == INSTRUMENT_GBPUSD)  ArrayRemove(g_inventory_GBPUSD, i, 1);
                    else                                  ArrayRemove(g_inventory_EURGBP, i, 1);
                    Print("INFO: Layer ", i, " fully closed. instrument=",
                          (inst == INSTRUMENT_EURUSD) ? "EURUSD"
                          : (inst == INSTRUMENT_GBPUSD) ? "GBPUSD" : "EURGBP");

                    // Check if this instrument's pod is now flat
                    int remaining = (inst == INSTRUMENT_EURUSD) ? ArraySize(g_inventory_EURUSD)
                                  : (inst == INSTRUMENT_GBPUSD) ? ArraySize(g_inventory_GBPUSD)
                                  : ArraySize(g_inventory_EURGBP);

                    if (remaining == 0) {
                        Print("INFO: Pod fully closed. instrument=",
                              (inst == INSTRUMENT_EURUSD) ? "EURUSD"
                              : (inst == INSTRUMENT_GBPUSD) ? "GBPUSD" : "EURGBP");
                        // Clear per-instrument add_next ticket
                        if (inst == INSTRUMENT_EURUSD)      g_add_next_EURUSD = 0;
                        else if (inst == INSTRUMENT_GBPUSD)  g_add_next_GBPUSD = 0;
                        else                                  g_add_next_EURGBP = 0;
                        // Note: CancelAllPendingEntries() scoping handled in Phase 2d
                    }
                }

                SaveAllInventoryState();
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

    // Search all three per-instrument arrays
    // Use explicit array to decouple from enum integer values (Gemini ruling)
    int target_instruments[3] = {INSTRUMENT_EURUSD, INSTRUMENT_GBPUSD, INSTRUMENT_EURGBP};

    for (int k = 0; k < 3; k++) {
        int inst = target_instruments[k];
        int inv_size = (inst == INSTRUMENT_EURUSD) ? ArraySize(g_inventory_EURUSD)
                     : (inst == INSTRUMENT_GBPUSD) ? ArraySize(g_inventory_GBPUSD)
                     : ArraySize(g_inventory_EURGBP);

        for (int i = 0; i < inv_size; i++) {
            Layer CurL = (inst == INSTRUMENT_EURUSD) ? g_inventory_EURUSD[i]
                       : (inst == INSTRUMENT_GBPUSD) ? g_inventory_GBPUSD[i]
                       : g_inventory_EURGBP[i];

            bool vol_match  = MathAbs(deal_volume - CurL.lot_size) < VOLUME_EPSILON;
            bool time_match = MathAbs((double)(deal_time - CurL.entry_time))
                              < FALLBACK_TIME_WINDOW;

            if (vol_match && time_match) {
                Print("WARNING: Fallback matched layer ", i, " instrument=",
                      (inst == INSTRUMENT_EURUSD) ? "EURUSD"
                      : (inst == INSTRUMENT_GBPUSD) ? "GBPUSD" : "EURGBP");

                if (inst == INSTRUMENT_EURUSD)
                    g_inventory_EURUSD[i].remaining_exit_volume -= deal_volume;
                else if (inst == INSTRUMENT_GBPUSD)
                    g_inventory_GBPUSD[i].remaining_exit_volume -= deal_volume;
                else
                    g_inventory_EURGBP[i].remaining_exit_volume -= deal_volume;

                CurL = (inst == INSTRUMENT_EURUSD) ? g_inventory_EURUSD[i]
                     : (inst == INSTRUMENT_GBPUSD) ? g_inventory_GBPUSD[i]
                     : g_inventory_EURGBP[i];

                if (CurL.remaining_exit_volume <= VOLUME_EPSILON) {
                    LogLayerExit(CurL, deal_time, 0.0);
                    if (inst == INSTRUMENT_EURUSD)      ArrayRemove(g_inventory_EURUSD, i, 1);
                    else if (inst == INSTRUMENT_GBPUSD)  ArrayRemove(g_inventory_GBPUSD, i, 1);
                    else                                  ArrayRemove(g_inventory_EURGBP, i, 1);
                }
                return;
            }
        }
    }

    Print("ERROR: Unmatched fill — no fallback match found. ",
          "ticket=", order_ticket, " Halting pod.");
    g_halted = true;
}
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest     &request,
                        const MqlTradeResult      &result) {
    if (g_halted) {
        Print("WARNING: OnTradeTransaction fired while EA is halted. "
              "Event dropped.");
        return;
    }

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
    long     deal_type    = HistoryDealGetInteger(deal_ticket, DEAL_TYPE);
    string   deal_symbol  = HistoryDealGetString(deal_ticket, DEAL_SYMBOL);
    datetime deal_time    = (datetime)HistoryDealGetInteger(deal_ticket,
                                                            DEAL_TIME);
    double   deal_profit  = HistoryDealGetDouble(deal_ticket, DEAL_PROFIT);

    if (deal_entry == DEAL_ENTRY_IN) {
        bool is_exit_limit_fill = false;
        int target_instruments[3] = {INSTRUMENT_EURUSD, INSTRUMENT_GBPUSD, INSTRUMENT_EURGBP};
        for (int k = 0; k < 3 && !is_exit_limit_fill; k++) {
            int inst = target_instruments[k];
            int inv_size = (inst == INSTRUMENT_EURUSD) ? ArraySize(g_inventory_EURUSD)
                         : (inst == INSTRUMENT_GBPUSD) ? ArraySize(g_inventory_GBPUSD)
                         : ArraySize(g_inventory_EURGBP);
            for (int i = 0; i < inv_size && !is_exit_limit_fill; i++) {
                Layer CurL = (inst == INSTRUMENT_EURUSD) ? g_inventory_EURUSD[i]
                           : (inst == INSTRUMENT_GBPUSD) ? g_inventory_GBPUSD[i]
                           : g_inventory_EURGBP[i];
                for (int j = 0; j < ArraySize(CurL.exit_tickets); j++) {
                    if (CurL.exit_tickets[j] == order_ticket) {
                        is_exit_limit_fill = true;
                        break;
                    }
                }
            }
        }

        if (is_exit_limit_fill) {
            ulong new_hedge_position = (ulong)HistoryDealGetInteger(
                                           deal_ticket, DEAL_POSITION_ID);
            HandleExitFill(deal_ticket, order_ticket, deal_volume,
                           deal_time, deal_profit, new_hedge_position);
        } else {
            HandleEntryFill(deal_ticket, order_ticket, deal_volume,
                            deal_price, deal_time, deal_symbol,
                            deal_type);
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
