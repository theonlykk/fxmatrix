#ifndef EXECUTION_ENGINE_MQH
#define EXECUTION_ENGINE_MQH

#include "MathEngine.mqh"
#include "StateEngine.mqh"

void CancelAllPendingEntries();

//------------------------------------------------------------------
// GetInstrumentFromSymbol
// Resolves slot index (0=PairAC, 1=PairBC, 2=PairAB) from symbol.
// Used throughout ExecutionEngine to route to the correct inventory array.
//------------------------------------------------------------------
int GetInstrumentFromSymbol(string symbol) {
    for (int s = 0; s < 3; s++) {
        if (symbol == g_symbols[s]) return s;
    }
    // Unknown symbol — default to SLOT_AB (cross pair)
    Print("WARNING: GetInstrumentFromSymbol — unknown symbol ", symbol,
          " defaulting to SLOT_AB");
    return SLOT_AB;
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
        double min_dist    = MathMax(stops_level * point, point);

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
    req.magic        = EA_MAGIC;  // Layer 0 entries and resume-quoting
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
    req.magic        = EA_MAGIC + 2;  // Exit limits
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
    req.magic        = EA_MAGIC + 1;  // Add-next entries
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
    g_add_next[instrument] = res.order;

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

    string instrument_str = GetInstrumentSymbol(layer.instrument);

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

    // V3 generic strongest/weakest from slot and direction
    // Slot 0=PairAC: A vs C → scores[0] vs scores[2]
    // Slot 1=PairBC: B vs C → scores[1] vs scores[2]
    // Slot 2=PairAB: A vs B → scores[0] vs scores[1]
    int strongest = 0;
    int weakest   = 0;
    if (instrument == SLOT_AB) {
        if (direction == DIRECTION_BUY)  { strongest = 1; weakest = 0; }
        else                              { strongest = 0; weakest = 1; }
    } else if (instrument == SLOT_AC) {
        if (direction == DIRECTION_BUY)  { strongest = 2; weakest = 0; }
        else                              { strongest = 0; weakest = 2; }
    } else { // SLOT_BC
        if (direction == DIRECTION_BUY)  { strongest = 2; weakest = 1; }
        else                              { strongest = 1; weakest = 2; }
    }

    // Read entry_spread from the correct per-instrument array.
    // next_layer_idx is post-append ArraySize; filled layer is at index next_layer_idx-1.
    double entry_spread = (instrument == 0) ? g_inventory_0[next_layer_idx - 1].entry_spread_raw
                        : (instrument == 1) ? g_inventory_1[next_layer_idx - 1].entry_spread_raw
                        : g_inventory_2[next_layer_idx - 1].entry_spread_raw;

    // add_next = entry_spread - S - S*(1-skew)
    // Guarantees |add_next - entry| > |exit - entry| for all skew < 1.
    double add_next_spread = entry_spread - S - S * (1.0 - skew);

    double price_add_next = InvertSpreadToPrice(
        g_anchor[0],
        g_anchor[1],
        g_r_signal[0],
        g_r_signal[1],
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
    ulong cur_add_next = g_add_next[instrument];

    if (order_ticket == cur_add_next) {
        g_add_next[instrument] = 0;
        cur_add_next = 0;   // sync local variable
    }

    // Resolve correct per-instrument array reference via instrument
    // MQL5 does not allow array refs — use instrument enum throughout.

    int layer_idx = -1;

    // Search per-instrument array for existing layer with this ticket
    int inv_size_search = (instrument == 0) ? ArraySize(g_inventory_0)
                        : (instrument == 1) ? ArraySize(g_inventory_1)
                        : ArraySize(g_inventory_2);
    for (int i = 0; i < inv_size_search; i++) {
        ulong tkt = (instrument == 0) ? g_inventory_0[i].entry_ticket
                  : (instrument == 1) ? g_inventory_1[i].entry_ticket
                  : g_inventory_2[i].entry_ticket;
        if (tkt == order_ticket) { layer_idx = i; break; }
    }

    // Helper macro to get current array size for this instrument
    int inv_size = (instrument == 0) ? ArraySize(g_inventory_0)
                 : (instrument == 1) ? ArraySize(g_inventory_1)
                 : ArraySize(g_inventory_2);

    if (layer_idx == -1) {
        if (inv_size >= MaxLayers) {
            Print("WARNING: Entry fill received but MaxLayers reached. ",
                  "ticket=", order_ticket);
            return;
        }

        layer_idx = inv_size;

        // Alien fill guard — reject fills on wrong instrument for open pod
        if (layer_idx > 0) {
            string expected_symbol = g_symbols[instrument];
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

        // Signal pairs only (SLOT_AC and SLOT_BC) — NOT the filled instrument
        // Gemini ruling: score recomputation always uses the two signal pairs
        double ac_ask = SymbolInfoDouble(g_symbols[SLOT_AC], SYMBOL_ASK);
        double ac_bid = SymbolInfoDouble(g_symbols[SLOT_AC], SYMBOL_BID);
        double bc_ask = SymbolInfoDouble(g_symbols[SLOT_BC], SYMBOL_ASK);
        double bc_bid = SymbolInfoDouble(g_symbols[SLOT_BC], SYMBOL_BID);

        if (layer_idx == 0) {
            L.anchor_A_at_entry  = g_anchor[0];
            L.anchor_B_at_entry  = g_anchor[1];
            L.r_AC_at_entry      = g_r_signal[0];
            L.r_BC_at_entry      = g_r_signal[1];
            L.entry_price_AC_1h  = g_anchor[0];
            L.entry_price_BC_1h  = g_anchor[1];

            L.instrument = GetInstrumentFromSymbol(deal_symbol);
            if (L.instrument == SLOT_AB &&
                deal_symbol != g_symbols[SLOT_AB]) {
                // GetInstrumentFromSymbol returned default — symbol not in triad
                Print("SEV-1 ERROR: HandleEntryFill — unrecognised deal_symbol=",
                      deal_symbol, ". Halting.");
                g_halted = true;
                return;
            }

            L.direction = (deal_type == DEAL_TYPE_BUY)
                          ? DIRECTION_BUY : DIRECTION_SELL;

            if (L.instrument == SLOT_AB) {
                if (L.direction == DIRECTION_BUY)  { L.strongest_at_entry = 1; L.weakest_at_entry = 0; }
                else                               { L.strongest_at_entry = 0; L.weakest_at_entry = 1; }
            } else if (L.instrument == SLOT_AC) {
                if (L.direction == DIRECTION_BUY)  { L.strongest_at_entry = 2; L.weakest_at_entry = 0; }
                else                               { L.strongest_at_entry = 0; L.weakest_at_entry = 2; }
            } else { // SLOT_BC
                if (L.direction == DIRECTION_BUY)  { L.strongest_at_entry = 2; L.weakest_at_entry = 1; }
                else                               { L.strongest_at_entry = 1; L.weakest_at_entry = 2; }
            }

            {
                double ac_mid_l0 = (ac_ask + ac_bid) / 2.0;
                double bc_mid_l0 = (bc_ask + bc_bid) / 2.0;
                double r_AC_l0   = MathLog(ac_mid_l0 / L.anchor_A_at_entry);
                double r_BC_l0   = MathLog(bc_mid_l0 / L.anchor_B_at_entry);
                double score_C_l0 = -(r_AC_l0 + r_BC_l0) / 3.0;
                double score_A_l0 =   r_AC_l0 + score_C_l0;
                double score_B_l0 =   r_BC_l0 + score_C_l0;
                double scores_l0[3];
                scores_l0[0] = score_A_l0;
                scores_l0[1] = score_B_l0;
                scores_l0[2] = score_C_l0;
                L.entry_spread_raw      = scores_l0[L.weakest_at_entry]
                                        - scores_l0[L.strongest_at_entry];
                L.entry_spread_adjusted = L.entry_spread_raw;
            }
        } else {
            // Layer 1+: inherit from Layer 0 of same instrument
            Layer L0 = (instrument == 0) ? g_inventory_0[0]
                     : (instrument == 1) ? g_inventory_1[0]
                     : g_inventory_2[0];

            L.anchor_A_at_entry  = L0.anchor_A_at_entry;
            L.anchor_B_at_entry  = L0.anchor_B_at_entry;
            L.strongest_at_entry = L0.strongest_at_entry;
            L.weakest_at_entry   = L0.weakest_at_entry;
            L.r_AC_at_entry      = L0.r_AC_at_entry;
            L.r_BC_at_entry      = L0.r_BC_at_entry;
            L.entry_price_AC_1h  = L0.anchor_A_at_entry;
            L.entry_price_BC_1h  = L0.anchor_B_at_entry;

            // Score recomputation uses SLOT_AC and SLOT_BC (signal pairs only)
            double ac_mid_now = (ac_ask + ac_bid) / 2.0;
            double bc_mid_now = (bc_ask + bc_bid) / 2.0;
            double r_AC_now   = MathLog(ac_mid_now / L.anchor_A_at_entry);
            double r_BC_now   = MathLog(bc_mid_now / L.anchor_B_at_entry);
            double score_C_now = -(r_AC_now + r_BC_now) / 3.0;
            double score_A_now =   r_AC_now + score_C_now;
            double score_B_now =   r_BC_now + score_C_now;
            double scores_now[3];
            scores_now[0] = score_A_now;
            scores_now[1] = score_B_now;
            scores_now[2] = score_C_now;
            L.entry_spread_raw      = scores_now[L.weakest_at_entry]
                                    - scores_now[L.strongest_at_entry];
            L.entry_spread_adjusted = L.entry_spread_raw;

            L.instrument = L0.instrument;
            L.direction  = L0.direction;
        }

        L.entry_price_AC = (ac_ask + ac_bid) / 2.0;
        L.entry_price_BC = (bc_ask + bc_bid) / 2.0;

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
            int inv_size_ldak[3];
            inv_size_ldak[0] = ArraySize(g_inventory_0);
            inv_size_ldak[1] = ArraySize(g_inventory_1);
            inv_size_ldak[2] = ArraySize(g_inventory_2);

            for (int j = 0; j < 3; j++) {
                if (j == instrument) continue;
                if (inv_size_ldak[j] == 0) continue;
                int lo = MathMin(instrument, j);
                int hi = MathMax(instrument, j);
                int ci = (lo == 0 && hi == 1) ? 0
                       : (lo == 0 && hi == 2) ? 1 : 2;
                double v_eff = MathMax(g_vratio[instrument], g_vratio[j]);
                double S     = MathMax(g_corr[ci], 0.0) * MathMax(v_eff - 1.0, 0.0);
                S_eff = MathMax(S_eff, S);
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

        L.exit_spread_target = ComputeExitSpreadTarget(L);
        double exit_price    = ComputeExitPrice(L);
        L.exit_target        = exit_price;

        // Append to correct per-instrument array
        if (instrument == 0) {
            ArrayResize(g_inventory_0, layer_idx + 1);
            g_inventory_0[layer_idx] = L;
        } else if (instrument == 1) {
            ArrayResize(g_inventory_1, layer_idx + 1);
            g_inventory_1[layer_idx] = L;
        } else {
            ArrayResize(g_inventory_2, layer_idx + 1);
            g_inventory_2[layer_idx] = L;
        }

        // next_layer_idx: ArraySize AFTER current layer appended
        int next_layer_idx = (instrument == 0) ? ArraySize(g_inventory_0)
                           : (instrument == 1) ? ArraySize(g_inventory_1)
                           : ArraySize(g_inventory_2);

        double computed_next = ComputeNextLayerPrice(
            next_layer_idx,
            L.instrument,
            L.direction,
            deal_price);

        if (computed_next <= 0.0) {
            Print("SEV-2: HandleEntryFill — add_next sentinel (-1.0). ",
                  "Layering skipped. next_layer_idx=", next_layer_idx);
            if (instrument == 0)      g_inventory_0[layer_idx].add_next = 0.0;
            else if (instrument == 1) g_inventory_1[layer_idx].add_next = 0.0;
            else                      g_inventory_2[layer_idx].add_next = 0.0;
        } else if (MathAbs(computed_next - deal_price) > deal_price * 0.05) {
            Print("SEV-2: HandleEntryFill — add_next deviation > 5%. ",
                  "computed=", computed_next, " deal_price=", deal_price,
                  " Layering skipped.");
            if (instrument == 0)      g_inventory_0[layer_idx].add_next = 0.0;
            else if (instrument == 1) g_inventory_1[layer_idx].add_next = 0.0;
            else                      g_inventory_2[layer_idx].add_next = 0.0;
        } else {
            if (instrument == 0)      g_inventory_0[layer_idx].add_next = computed_next;
            else if (instrument == 1) g_inventory_1[layer_idx].add_next = computed_next;
            else                      g_inventory_2[layer_idx].add_next = computed_next;
        }

        // Clear matching bid/offer ticket on fill
        if (order_ticket == g_pending_bid[instrument])   g_pending_bid[instrument]   = 0;
        if (order_ticket == g_pending_offer[instrument]) g_pending_offer[instrument] = 0;

        // --- ADR-014 Phase 2: Quote Substitution ---
        // On Layer 0 fill only: cancel the opposing side quote.
        // Prevents MT5 hedging trap — we cannot hold both bid and offer
        // inventory on the same instrument simultaneously.
        // Note: The filled ticket was just zeroed out in the block above.
        // Therefore, any remaining ticket > 0 for this instrument is the opposing quote.
        if (layer_idx == 0) {
            ulong opposing_ticket = 0;

            if (g_pending_bid[instrument] > 0)   { opposing_ticket = g_pending_bid[instrument];   g_pending_bid[instrument]   = 0; }
            if (g_pending_offer[instrument] > 0) { opposing_ticket = g_pending_offer[instrument]; g_pending_offer[instrument] = 0; }

            if (opposing_ticket > 0) {
                MqlTradeRequest req = {};
                MqlTradeResult  res = {};
                req.action = TRADE_ACTION_REMOVE;
                req.order  = opposing_ticket;
                if (OrderSend(req, res)) {
                    Print("INFO: ADR-014 quote substitution — opposing quote cancelled. ",
                          "instrument=", deal_symbol,
                          " layer=0 opposing_ticket=", opposing_ticket);
                } else {
                    Print("WARNING: ADR-014 quote substitution — cancel failed. ",
                          "retcode=", res.retcode,
                          " opposing_ticket=", opposing_ticket,
                          " — possible race fill, HandleEntryFill will catch it");
                }
            }
        }
        // --- End ADR-014 Phase 2 ---

        SaveAllInventoryState();
    }

    // Decrement remaining entry volume on correct array
    if (instrument == 0)      g_inventory_0[layer_idx].remaining_entry_volume -= deal_volume;
    else if (instrument == 1) g_inventory_1[layer_idx].remaining_entry_volume -= deal_volume;
    else                      g_inventory_2[layer_idx].remaining_entry_volume -= deal_volume;

    // Arm exit volume when entry fully filled
    double rem_entry = (instrument == 0) ? g_inventory_0[layer_idx].remaining_entry_volume
                     : (instrument == 1) ? g_inventory_1[layer_idx].remaining_entry_volume
                     : g_inventory_2[layer_idx].remaining_entry_volume;
    double rem_exit  = (instrument == 0) ? g_inventory_0[layer_idx].remaining_exit_volume
                     : (instrument == 1) ? g_inventory_1[layer_idx].remaining_exit_volume
                     : g_inventory_2[layer_idx].remaining_exit_volume;

    if (rem_entry <= VOLUME_EPSILON && rem_exit == 0.0) {
        double lot = (instrument == 0) ? g_inventory_0[layer_idx].lot_size
                   : (instrument == 1) ? g_inventory_1[layer_idx].lot_size
                   : g_inventory_2[layer_idx].lot_size;
        if (instrument == 0)      g_inventory_0[layer_idx].remaining_exit_volume = lot;
        else if (instrument == 1) g_inventory_1[layer_idx].remaining_exit_volume = lot;
        else                      g_inventory_2[layer_idx].remaining_exit_volume = lot;
        Print("INFO: Entry complete — exit volume armed. Layer ", layer_idx,
              " instrument=", deal_symbol);
        EmitTelemetry(true);
    }

    // Resolve layer reference for exit placement
    Layer CurL = (instrument == 0) ? g_inventory_0[layer_idx]
               : (instrument == 1) ? g_inventory_1[layer_idx]
               : g_inventory_2[layer_idx];

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
        if (instrument == 0) {
            ArrayResize(g_inventory_0[layer_idx].exit_tickets, n + 1);
            g_inventory_0[layer_idx].exit_tickets[n] = res.order;
        } else if (instrument == 1) {
            ArrayResize(g_inventory_1[layer_idx].exit_tickets, n + 1);
            g_inventory_1[layer_idx].exit_tickets[n] = res.order;
        } else {
            ArrayResize(g_inventory_2[layer_idx].exit_tickets, n + 1);
            g_inventory_2[layer_idx].exit_tickets[n] = res.order;
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
        if (instrument == 0) {
            ArrayResize(g_inventory_0[layer_idx].exit_tickets, n + 1);
            g_inventory_0[layer_idx].exit_tickets[n] = exit_tkt;
        } else if (instrument == 1) {
            ArrayResize(g_inventory_1[layer_idx].exit_tickets, n + 1);
            g_inventory_1[layer_idx].exit_tickets[n] = exit_tkt;
        } else {
            ArrayResize(g_inventory_2[layer_idx].exit_tickets, n + 1);
            g_inventory_2[layer_idx].exit_tickets[n] = exit_tkt;
        }
        SaveAllInventoryState();
    }

    // Re-read CurL after modifications
    CurL = (instrument == 0) ? g_inventory_0[layer_idx]
         : (instrument == 1) ? g_inventory_1[layer_idx]
         : g_inventory_2[layer_idx];

    double filled_so_far = CurL.lot_size - CurL.remaining_entry_volume;
    bool threshold_met   = filled_so_far >= MinFillThreshold * CurL.lot_size;
    int  cur_inv_size    = (instrument == 0) ? ArraySize(g_inventory_0)
                         : (instrument == 1) ? ArraySize(g_inventory_1)
                         : ArraySize(g_inventory_2);
    bool next_not_placed = cur_inv_size == layer_idx + 1;
    bool capacity_ok     = cur_inv_size < MaxLayers;

    if (threshold_met && next_not_placed && capacity_ok && cur_add_next == 0) {
        // Phase 3: sleep gate — mandatory interval between layer adds
        datetime last_layer = g_last_layer_time[instrument];

        if (TimeCurrent() - last_layer < MinLayerIntervalSeconds) {
            Print("INFO: Layer interval sleep active. Skipping add_next. ",
                  "instrument=", deal_symbol,
                  " remaining=", MinLayerIntervalSeconds -
                  (int)(TimeCurrent() - last_layer), "s");
            // add_next NOT placed. OnTick re-arm will fire when sleep expires.
        } else {
            PlaceNextEntryLimit(CurL, deal_symbol);
            // Update last layer timestamp for this instrument
            g_last_layer_time[instrument] = TimeCurrent();
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
    for (int k = 0; k < 3; k++) {
        int inst = k;
        int inv_size = (inst == 0) ? ArraySize(g_inventory_0)
                     : (inst == 1) ? ArraySize(g_inventory_1)
                     : ArraySize(g_inventory_2);

        for (int i = 0; i < inv_size; i++) {
            Layer CurL = (inst == 0) ? g_inventory_0[i]
                       : (inst == 1) ? g_inventory_1[i]
                       : g_inventory_2[i];

            int n_tickets = ArraySize(CurL.exit_tickets);
            for (int j = 0; j < n_tickets; j++) {
                if (CurL.exit_tickets[j] != order_ticket) continue;

                // Found matching exit ticket
                if (hedge_position_ticket > 0 && CurL.position_ticket > 0) {
                    // ADR: Route ALL CloseBy tasks directly to queue.
                    // Never attempt CloseBy inline inside OnTradeTransaction —
                    // the broker may not have settled the hedge position on its
                    // server ledger yet, producing retcode=10013 (Invalid Request).
                    // ProcessCloseByQueue() on the next OnTick provides the
                    // natural async buffer for position settlement.
                    {
                        int q_idx = ArraySize(g_closeby_queue);
                        ArrayResize(g_closeby_queue, q_idx + 1);
                        g_closeby_queue[q_idx].ticket1 = CurL.position_ticket;
                        g_closeby_queue[q_idx].ticket2 = hedge_position_ticket;
                        g_closeby_queue[q_idx].retries = 0;
                        Print("INFO: CloseBy queued for next tick. ",
                              "position=", CurL.position_ticket,
                              " position_by=", hedge_position_ticket);
                    }
                }

                // Decrement remaining exit volume
                if (inst == 0)      g_inventory_0[i].remaining_exit_volume -= deal_volume;
                else if (inst == 1) g_inventory_1[i].remaining_exit_volume -= deal_volume;
                else                g_inventory_2[i].remaining_exit_volume -= deal_volume;

                // Remove the matched exit ticket
                if (inst == 0)      ArrayRemove(g_inventory_0[i].exit_tickets, j, 1);
                else if (inst == 1) ArrayRemove(g_inventory_1[i].exit_tickets, j, 1);
                else                ArrayRemove(g_inventory_2[i].exit_tickets, j, 1);

                // Re-read after modification
                CurL = (inst == 0) ? g_inventory_0[i]
                     : (inst == 1) ? g_inventory_1[i]
                     : g_inventory_2[i];

                if (CurL.remaining_exit_volume <= VOLUME_EPSILON) {
                    LogLayerExit(CurL, deal_time, deal_profit);
                    if (inst == 0)      ArrayRemove(g_inventory_0, i, 1);
                    else if (inst == 1) ArrayRemove(g_inventory_1, i, 1);
                    else                ArrayRemove(g_inventory_2, i, 1);
                    Print("INFO: Layer ", i, " fully closed. instrument=",
                          g_symbols[inst]);

                    // Check if this instrument's pod is now flat
                    int remaining = (inst == 0) ? ArraySize(g_inventory_0)
                                  : (inst == 1) ? ArraySize(g_inventory_1)
                                  : ArraySize(g_inventory_2);

                    if (remaining == 0) {
                        // Phase 3: capture add-next ticket BEFORE zeroing globals
                        ulong add_next_ticket = g_add_next[inst];
                        if (add_next_ticket > 0) {
                            MqlTradeRequest an_req = {};
                            MqlTradeResult  an_res = {};
                            an_req.action = TRADE_ACTION_REMOVE;
                            an_req.order  = add_next_ticket;
                            if (!OrderSend(an_req, an_res))
                                Print("WARNING: Phase 3 add-next cancel failed. ticket=",
                                      add_next_ticket, " retcode=", an_res.retcode);
                            else
                                Print("INFO: Phase 3 orphaned add-next cancelled. ticket=",
                                      add_next_ticket);
                        }

                        // Now safe to zero the globals
                        g_add_next[inst] = 0;

                        Print("INFO: Pod fully closed. All layers unwound.");
                        EmitTelemetry(true);

                        // Pipshed Phase 2: emit closed pod record
                        // Uses CurL (last closed Layer), deal_profit, inst — all in scope
                        // avg_entry_price = CurL.entry_price (Layer 0 entry as proxy)
                        // exit_price = CurL.exit_target (the LIFO unwind target price)
                        // hold_time_minutes derived from CurL.entry_time to now
                        // gross_pnl = deal_profit (passed directly, never recalculated from dead tickets)
                        {
                            string _pod_symbol    = GetInstrumentSymbol(inst);
                            string _pod_direction = (CurL.direction == DIRECTION_BUY) ? "LONG" : "SHORT";
                            double _pod_hold_mins = (double)(TimeCurrent() - CurL.entry_time) / 60.0;
                            EmitPodClose(
                                _pod_symbol,
                                _pod_direction,
                                1,
                                CurL.entry_price,
                                CurL.exit_target,
                                _pod_hold_mins,
                                deal_profit
                            );
                        }

                        // Phase 3: resume two-way quoting immediately (unconditional,
                        // no LDAK gate -- mirrors if (new_bar) flat-instrument logic exactly)
                        string resume_symbol = g_symbols[inst];

                        // V3 generic: derive strongest/weakest from slot and g_scores[]
                        int inst_strongest = 0, inst_weakest = 0;
                        if (inst == SLOT_AB) {
                            inst_strongest = (g_scores[0] > g_scores[1]) ? 0 : 1;
                            inst_weakest   = (g_scores[0] < g_scores[1]) ? 0 : 1;
                        } else if (inst == SLOT_AC) {
                            inst_strongest = (g_scores[0] > g_scores[2]) ? 0 : 2;
                            inst_weakest   = (g_scores[0] < g_scores[2]) ? 0 : 2;
                        } else { // SLOT_BC
                            inst_strongest = (g_scores[1] > g_scores[2]) ? 1 : 2;
                            inst_weakest   = (g_scores[1] < g_scores[2]) ? 1 : 2;
                        }

                        double inst_spread = g_scores[inst_weakest] - g_scores[inst_strongest];

                        // Determine correct bid/offer directions
                        int bid_direction, offer_direction;
                        if ((inst_strongest == 0 && inst_weakest == 1) ||
                            (inst_strongest == 0 && inst_weakest == 2) ||
                            (inst_strongest == 1 && inst_weakest == 2)) {
                            offer_direction = DIRECTION_SELL;
                            bid_direction   = DIRECTION_BUY;
                        } else {
                            offer_direction = DIRECTION_BUY;
                            bid_direction   = DIRECTION_SELL;
                        }

                        double bid_spread   = inst_spread + QuoteSpread;
                        double offer_spread = inst_spread - QuoteSpread;

                        double bid_price = InvertSpreadToPrice(
                            g_anchor[0], g_anchor[1],
                            g_r_signal[0], g_r_signal[1],
                            bid_spread, inst_strongest, inst_weakest,
                            false, false);

                        double offer_price = InvertSpreadToPrice(
                            g_anchor[0], g_anchor[1],
                            g_r_signal[0], g_r_signal[1],
                            offer_spread, inst_strongest, inst_weakest,
                            false, false);

                        if (bid_price > 0) {
                            ulong bid_tkt = PlaceEntryLimit(bid_price, bid_direction, resume_symbol);
                            if (bid_tkt > 0)   g_pending_bid[inst]   = bid_tkt;
                        }
                        if (offer_price > 0) {
                            ulong offer_tkt = PlaceEntryLimit(offer_price, offer_direction, resume_symbol);
                            if (offer_tkt > 0) g_pending_offer[inst] = offer_tkt;
                        }

                        Print("INFO: Phase 3 resume quoting. instrument=", resume_symbol,
                              " bid=", bid_price, " offer=", offer_price);
                    }
                    else {
                        // Phase 3: partial unwind -- cancel stale add-next, resubmit for
                        // new shallowest layer (index 0 after LIFO ArrayRemove)
                        ulong stale_ticket = g_add_next[inst];
                        if (stale_ticket > 0) {
                            MqlTradeRequest st_req = {};
                            MqlTradeResult  st_res = {};
                            st_req.action = TRADE_ACTION_REMOVE;
                            st_req.order  = stale_ticket;
                            if (!OrderSend(st_req, st_res))
                                Print("WARNING: Phase 3 stale add-next cancel failed. ticket=",
                                      stale_ticket, " retcode=", st_res.retcode);
                        }
                        // Zero regardless -- PlaceNextEntryLimit will resubmit
                        g_add_next[inst] = 0;

                        // Resubmit add-next for new shallowest layer (index 0)
                        Layer NewShallowest = (inst == 0) ? g_inventory_0[0]
                                            : (inst == 1) ? g_inventory_1[0]
                                            : g_inventory_2[0];
                        string sym = g_symbols[inst];

                        // remaining is the new inventory size after LIFO removal
                        double computed = ComputeNextLayerPrice(remaining, NewShallowest.instrument,
                                                                NewShallowest.direction,
                                                                NewShallowest.entry_price);
                        if (computed > 0.0) {
                            PlaceNextEntryLimit(NewShallowest, sym, computed);
                            Print("INFO: Phase 3 add-next resubmitted for new shallowest layer.",
                                  " instrument=", sym,
                                  " layer_price=", NewShallowest.entry_price,
                                  " add_next=", computed);
                        }
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
    for (int k = 0; k < 3; k++) {
        int inst = k;
        int inv_size = (inst == 0) ? ArraySize(g_inventory_0)
                     : (inst == 1) ? ArraySize(g_inventory_1)
                     : ArraySize(g_inventory_2);

        for (int i = 0; i < inv_size; i++) {
            Layer CurL = (inst == 0) ? g_inventory_0[i]
                       : (inst == 1) ? g_inventory_1[i]
                       : g_inventory_2[i];

            bool vol_match  = MathAbs(deal_volume - CurL.lot_size) < VOLUME_EPSILON;
            bool time_match = MathAbs((double)(deal_time - CurL.entry_time))
                              < FALLBACK_TIME_WINDOW;

            if (vol_match && time_match) {
                Print("WARNING: Fallback matched layer ", i, " instrument=",
                      g_symbols[inst]);

                if (inst == 0)      g_inventory_0[i].remaining_exit_volume -= deal_volume;
                else if (inst == 1) g_inventory_1[i].remaining_exit_volume -= deal_volume;
                else                g_inventory_2[i].remaining_exit_volume -= deal_volume;

                CurL = (inst == 0) ? g_inventory_0[i]
                     : (inst == 1) ? g_inventory_1[i]
                     : g_inventory_2[i];

                if (CurL.remaining_exit_volume <= VOLUME_EPSILON) {
                    LogLayerExit(CurL, deal_time, 0.0);
                    if (inst == 0)      ArrayRemove(g_inventory_0, i, 1);
                    else if (inst == 1) ArrayRemove(g_inventory_1, i, 1);
                    else                ArrayRemove(g_inventory_2, i, 1);
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
        long deal_magic = HistoryDealGetInteger(deal_ticket, DEAL_MAGIC);

        if (deal_magic == (long)(EA_MAGIC + 2)) {
            // Exit limit fill — deterministic magic number routing
            ulong new_hedge_position = (ulong)HistoryDealGetInteger(
                                           deal_ticket, DEAL_POSITION_ID);
            HandleExitFill(deal_ticket, order_ticket, deal_volume,
                           deal_time, deal_profit, new_hedge_position);
        } else if (deal_magic == (long)EA_MAGIC ||
                   deal_magic == (long)(EA_MAGIC + 1)) {
            // Entry fill (EA_MAGIC = Layer 0, EA_MAGIC+1 = add-next)
            HandleEntryFill(deal_ticket, order_ticket, deal_volume,
                            deal_price, deal_time, deal_symbol,
                            deal_type);
        } else {
            // Ignore manual trades (Magic 0) or other EA trades
            Print("INFO: Ignored DEAL_ENTRY_IN with unmanaged magic=",
                  deal_magic);
        }
        return;
    }

    if (deal_entry == DEAL_ENTRY_OUT) {
        long deal_magic = HistoryDealGetInteger(deal_ticket, DEAL_MAGIC);
        if (deal_magic == (long)(EA_MAGIC + 2)) {
            HandleExitFill(deal_ticket, order_ticket, deal_volume,
                           deal_time, deal_profit);
        } else {
            if (EnableVerboseLog) {
                Print("INFO: Ignored DEAL_ENTRY_OUT with unmanaged magic=",
                      deal_magic);
            }
        }
        return;
    }
}

#endif // EXECUTION_ENGINE_MQH
