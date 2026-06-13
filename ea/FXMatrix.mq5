//+------------------------------------------------------------------+
//| FXMatrix.mq5                                                     |
//| 3-Currency FX Mean Reversion Pod — EUR/GBP/USD                   |
//| FTMO MT5 Hedging Account                                         |
//+------------------------------------------------------------------+
#property copyright "fxmatrix"
#property version   "1.00"
#property strict

#include "Globals.mqh"
#include "LayerStruct.mqh"
#include "MathEngine.mqh"
#include "ExecutionEngine.mqh"
#include "CarryEngine.mqh"
#include "StateEngine.mqh"

void CheckCircuitBreakers();
void CloseAllPositions();
void CancelAllPending();
void CancelAllPendingEntries();
void ProcessCloseByQueue();
double GetPendingOrderPrice(ulong ticket);

int OnInit() {
    int result = InitGlobals();
    if (result != INIT_SUCCEEDED) return result;

    Print("FXMatrix EA initialised. "
          "build=1da31ec "
          "NudgeThreshold=", g_NudgeThreshold, " points");

    LoadInventoryState(INSTRUMENT_EURUSD);
    LoadInventoryState(INSTRUMENT_GBPUSD);
    LoadInventoryState(INSTRUMENT_EURGBP);
    CheckForOrphans();
    if (g_halted) {
        Print("ERROR: OnInit halted — orphan positions detected. "
              "Resolve manually before reattaching EA.");
        return INIT_FAILED;
    }

    string parts[];
    if (StringSplit(CarryRecalcTime, ':', parts) == 2) {
        g_carry_hour   = (int)StringToInteger(parts[0]);
        g_carry_minute = (int)StringToInteger(parts[1]);
    } else {
        Print("ERROR: CarryRecalcTime format invalid. "
              "Expected HH:MM, got: ", CarryRecalcTime);
        return INIT_PARAMETERS_INCORRECT;
    }

    Print("INFO: Carry trigger set to ",
          g_carry_hour, ":",
          StringFormat("%02d", g_carry_minute),
          " broker server time.");

    return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) {
    Print("INFO: FXMatrix EA deinitialised. Reason=", reason);
}

void GetImpliedIndices(string sym, int dir,
                       int &out_strongest, int &out_weakest) {
    if (sym == "EURUSD") {
        if (dir == DIRECTION_BUY)
            { out_strongest = 2; out_weakest = 0; }
        else
            { out_strongest = 0; out_weakest = 2; }
    }
    else if (sym == "GBPUSD") {
        if (dir == DIRECTION_BUY)
            { out_strongest = 2; out_weakest = 1; }
        else
            { out_strongest = 1; out_weakest = 2; }
    }
    else if (sym == "EURGBP") {
        if (dir == DIRECTION_BUY)
            { out_strongest = 1; out_weakest = 0; }
        else
            { out_strongest = 0; out_weakest = 1; }
    }
}

void OnTick() {
    if (g_halted) return;

    CheckCircuitBreakers();
    if (g_halted) return;

    // Process pending CloseBy tasks before any signal logic.
    // Resolves MT5 ledger desync on market hedge fills.
    ProcessCloseByQueue();
    if (g_halted) return;

    if (ArraySize(g_inventory_EURUSD) > 0 ||
        ArraySize(g_inventory_GBPUSD) > 0 ||
        ArraySize(g_inventory_EURGBP) > 0)
        CheckCarryTrigger();

    datetime current_bar = iTime(_Symbol, PERIOD_M5, 0);
    bool new_bar = (current_bar != g_last_bar_time);

    if (new_bar) {
        g_last_bar_time = current_bar;

        RunSignalOnBarClose();

        // Per-instrument Option A deafness (Gemini Phase 2d ruling).
        // Each instrument evaluates independently. A pod open on EURGBP
        // does not suppress signal evaluation on EURUSD or GBPUSD.
        // Entry direction derived at point of use from instrument enum.

        double scores[3];
        scores[0] = g_score_eur;
        scores[1] = g_score_gbp;
        scores[2] = g_score_usd;

        int target_instruments[3] = {INSTRUMENT_EURUSD, INSTRUMENT_GBPUSD, INSTRUMENT_EURGBP};

        for (int k = 0; k < 3; k++) {
            int inst = target_instruments[k];

            // Derive symbol and direction for this instrument
            string inst_symbol = (inst == INSTRUMENT_EURUSD) ? "EURUSD"
                               : (inst == INSTRUMENT_GBPUSD) ? "GBPUSD"
                               : "EURGBP";

            // Derive strongest/weakest for this instrument's routing
            int inst_strongest = 0, inst_weakest = 0;
            if (inst == INSTRUMENT_EURUSD) {
                // EUR vs USD: compare scores[0] vs scores[2]
                inst_strongest = (scores[0] > scores[2]) ? 0 : 2;
                inst_weakest   = (scores[0] < scores[2]) ? 0 : 2;
            } else if (inst == INSTRUMENT_GBPUSD) {
                // GBP vs USD: compare scores[1] vs scores[2]
                inst_strongest = (scores[1] > scores[2]) ? 1 : 2;
                inst_weakest   = (scores[1] < scores[2]) ? 1 : 2;
            } else {
                // EUR vs GBP: compare scores[0] vs scores[1]
                inst_strongest = (scores[0] > scores[1]) ? 0 : 1;
                inst_weakest   = (scores[0] < scores[1]) ? 0 : 1;
            }

            double inst_spread = scores[inst_weakest] - scores[inst_strongest];
            bool   inst_signal = (inst_spread < -BaseThreshold);

            // Direction: SELL if strongest is EUR(0) or GBP(1) vs weaker,
            // BUY if strongest is USD(2) or GBP(1) vs EUR(0)
            int inst_direction;
            if ((inst_strongest == 0 && inst_weakest == 1) ||
                (inst_strongest == 0 && inst_weakest == 2) ||
                (inst_strongest == 1 && inst_weakest == 2))
                inst_direction = DIRECTION_SELL;
            else
                inst_direction = DIRECTION_BUY;

            // Per-instrument pending entry ticket
            ulong inst_pending = (inst == INSTRUMENT_EURUSD) ? g_pending_entry_EURUSD
                               : (inst == INSTRUMENT_GBPUSD) ? g_pending_entry_GBPUSD
                               : g_pending_entry_EURGBP;

            int inst_inv_size = (inst == INSTRUMENT_EURUSD) ? ArraySize(g_inventory_EURUSD)
                              : (inst == INSTRUMENT_GBPUSD) ? ArraySize(g_inventory_GBPUSD)
                              : ArraySize(g_inventory_EURGBP);

            ulong inst_add_next = (inst == INSTRUMENT_EURUSD) ? g_add_next_EURUSD
                                : (inst == INSTRUMENT_GBPUSD) ? g_add_next_GBPUSD
                                : g_add_next_EURGBP;

            // Phase 3: re-arm add_next after sleep expiry
            // Fires when pod is open but undefended (no live add_next)
            // and the sleep interval has elapsed
            if (inst_inv_size > 0 && inst_add_next == 0) {
                datetime last_layer = (inst == INSTRUMENT_EURUSD)
                                      ? g_last_layer_time_EURUSD
                                      : (inst == INSTRUMENT_GBPUSD)
                                      ? g_last_layer_time_GBPUSD
                                      : g_last_layer_time_EURGBP;

                if (TimeCurrent() - last_layer >= MinLayerIntervalSeconds) {
                    // Sleep expired — re-arm at current market conditions
                    int inv_size = inst_inv_size;

                    // Get deepest open layer
                    Layer deepest = (inst == INSTRUMENT_EURUSD)
                                    ? g_inventory_EURUSD[inv_size - 1]
                                    : (inst == INSTRUMENT_GBPUSD)
                                    ? g_inventory_GBPUSD[inv_size - 1]
                                    : g_inventory_EURGBP[inv_size - 1];

                    // Compute fresh add_next price
                    double computed = ComputeNextLayerPrice(
                        inv_size,
                        deepest.instrument,
                        deepest.direction,
                        deepest.entry_price);

                    if (computed > 0.0) {
                        // Use price_override so PlaceNextEntryLimit applies
                        // gap-aware MathMin/MathMax on top
                        PlaceNextEntryLimit(deepest, inst_symbol, computed);

                        // Update last layer timestamp
                        if (inst == INSTRUMENT_EURUSD)
                            g_last_layer_time_EURUSD = TimeCurrent();
                        else if (inst == INSTRUMENT_GBPUSD)
                            g_last_layer_time_GBPUSD = TimeCurrent();
                        else
                            g_last_layer_time_EURGBP = TimeCurrent();

                        Print("INFO: add_next re-armed after sleep. ",
                              "instrument=", inst_symbol,
                              " layer=", inv_size,
                              " computed=", DoubleToString(computed, 5));
                    }
                }
                // Sleep not yet expired — pod open but undefended. Fall through
                // to Option A deafness (continue) below.
            }

            // Option A: skip if this instrument has open inventory
            if (inst_inv_size > 0) continue;

            // Rotation and plain-matrix entry for this instrument
            if (inst_pending > 0) {
                string pending_symbol    = "";
                int    pending_direction = 0;
                bool   order_exists      = false;

                if (OrderSelect(inst_pending)) {
                    order_exists      = true;
                    pending_symbol    = OrderGetString(ORDER_SYMBOL);
                    pending_direction = (OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_LIMIT)
                                        ? DIRECTION_BUY : DIRECTION_SELL;
                }

                if (!order_exists) {
                    if (inst == INSTRUMENT_EURUSD)      g_pending_entry_EURUSD = 0;
                    else if (inst == INSTRUMENT_GBPUSD)  g_pending_entry_GBPUSD = 0;
                    else                                  g_pending_entry_EURGBP = 0;
                    SaveAllInventoryState();
                }
                else if (pending_symbol    != inst_symbol ||
                         pending_direction != inst_direction) {

                    // Compute live spread of pending order
                    int    p_strongest = 0, p_weakest = 0;
                    GetImpliedIndices(pending_symbol, pending_direction,
                                      p_strongest, p_weakest);

                    double pending_live_spread = MathAbs(
                        scores[p_weakest] - scores[p_strongest]);
                    double candidate_live_spread = MathAbs(inst_spread);

                    if (candidate_live_spread >
                            pending_live_spread + RotationThreshold) {
                        // Rotation approved
                        MqlTradeRequest req = {};
                        MqlTradeResult  res = {};
                        req.action = TRADE_ACTION_REMOVE;
                        req.order  = inst_pending;

                        if (OrderSend(req, res)) {
                            if (inst == INSTRUMENT_EURUSD)      g_pending_entry_EURUSD = 0;
                            else if (inst == INSTRUMENT_GBPUSD)  g_pending_entry_GBPUSD = 0;
                            else                                  g_pending_entry_EURGBP = 0;
                            SaveAllInventoryState();
                        } else {
                            Print("INFO: Pending cancel failed retcode=", res.retcode,
                                  " instrument=", inst_symbol,
                                  " — possible fill in race window, deferring");
                            continue;
                        }
                    }
                    // else: rotation rejected — retain pending, skip entry
                    else { continue; }
                }
                // else: same routing — fall through to nudge (handled below)
            }

            // Plain-matrix entry for this instrument
            if (inst_signal && inst_pending == 0) {
                double entry_price = InvertSpreadToPrice(
                    g_EU_mid_12bars_ago,
                    g_GB_mid_12bars_ago,
                    g_r_EU_signal,
                    g_r_GB_signal,
                    inst_spread,
                    inst_strongest,
                    inst_weakest,
                    false
                );

                if (entry_price > 0) {
                    ulong tkt = PlaceEntryLimit(entry_price, inst_direction, inst_symbol);
                    if (tkt > 0) {
                        if (inst == INSTRUMENT_EURUSD)      g_pending_entry_EURUSD = tkt;
                        else if (inst == INSTRUMENT_GBPUSD)  g_pending_entry_GBPUSD = tkt;
                        else                                  g_pending_entry_EURGBP = tkt;
                        SaveAllInventoryState();
                    }
                }
            }
        } // End per-instrument loop
    } // End new_bar block

    // Per-instrument nudge block
    double scores_nudge[3];
    scores_nudge[0] = g_score_eur;
    scores_nudge[1] = g_score_gbp;
    scores_nudge[2] = g_score_usd;

    int nudge_instruments[3] = {INSTRUMENT_EURUSD, INSTRUMENT_GBPUSD, INSTRUMENT_EURGBP};

    for (int k = 0; k < 3; k++) {
        int inst = nudge_instruments[k];

        ulong inst_pending = (inst == INSTRUMENT_EURUSD) ? g_pending_entry_EURUSD
                           : (inst == INSTRUMENT_GBPUSD) ? g_pending_entry_GBPUSD
                           : g_pending_entry_EURGBP;

        int inst_inv_size = (inst == INSTRUMENT_EURUSD) ? ArraySize(g_inventory_EURUSD)
                          : (inst == INSTRUMENT_GBPUSD) ? ArraySize(g_inventory_GBPUSD)
                          : ArraySize(g_inventory_EURGBP);

        if (inst_inv_size > 0 || inst_pending == 0) continue;

        // Derive signal for this instrument
        int inst_strongest = 0, inst_weakest = 0;
        if (inst == INSTRUMENT_EURUSD) {
            inst_strongest = (scores_nudge[0] > scores_nudge[2]) ? 0 : 2;
            inst_weakest   = (scores_nudge[0] < scores_nudge[2]) ? 0 : 2;
        } else if (inst == INSTRUMENT_GBPUSD) {
            inst_strongest = (scores_nudge[1] > scores_nudge[2]) ? 1 : 2;
            inst_weakest   = (scores_nudge[1] < scores_nudge[2]) ? 1 : 2;
        } else {
            inst_strongest = (scores_nudge[0] > scores_nudge[1]) ? 0 : 1;
            inst_weakest   = (scores_nudge[0] < scores_nudge[1]) ? 0 : 1;
        }

        double inst_spread = scores_nudge[inst_weakest] - scores_nudge[inst_strongest];
        bool   inst_signal = (inst_spread < -BaseThreshold);

        if (!inst_signal) continue;

        int inst_direction;
        if ((inst_strongest == 0 && inst_weakest == 1) ||
            (inst_strongest == 0 && inst_weakest == 2) ||
            (inst_strongest == 1 && inst_weakest == 2))
            inst_direction = DIRECTION_SELL;
        else
            inst_direction = DIRECTION_BUY;

        string inst_symbol = (inst == INSTRUMENT_EURUSD) ? "EURUSD"
                           : (inst == INSTRUMENT_GBPUSD) ? "GBPUSD"
                           : "EURGBP";

        double recomputed = InvertSpreadToPrice(
            g_EU_mid_12bars_ago,
            g_GB_mid_12bars_ago,
            g_r_EU_signal,
            g_r_GB_signal,
            inst_spread,
            inst_strongest,
            inst_weakest,
            false
        );

        if (recomputed <= 0) continue;

        double current_pending = GetPendingOrderPrice(inst_pending);
        if (current_pending > 0 &&
            MathAbs(recomputed - current_pending) > g_NudgeThreshold) {

            string sym = OrderSelect(inst_pending)
                         ? OrderGetString(ORDER_SYMBOL) : inst_symbol;
            int    dir = OrderSelect(inst_pending)
                         ? ((OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_LIMIT)
                            ? DIRECTION_BUY : DIRECTION_SELL)
                         : inst_direction;

            if (IsClearOfFreezeLevel(recomputed, dir, sym) &&
                IsPassive(recomputed, dir, sym)) {

                MqlTradeRequest req = {};
                MqlTradeResult  res = {};
                req.action = TRADE_ACTION_MODIFY;
                req.order  = inst_pending;
                req.price  = recomputed;

                if (!OrderSend(req, res)) {
                    if (res.retcode != TRADE_RETCODE_DONE &&
                        res.retcode != TRADE_RETCODE_PLACED)
                        Print("WARNING: Nudge OrderModify failed. ",
                              "retcode=", res.retcode,
                              " instrument=", inst_symbol);
                }
            }
        }
    }
}

//------------------------------------------------------------------
// GetPodUnrealizedPnL
// Returns the total unrealised P&L for all open positions belonging
// to a single instrument's inventory. Uses PositionSelectByTicket()
// to read live broker P&L per layer — strictly isolated per instrument.
//------------------------------------------------------------------
double GetPodUnrealizedPnL(int instrument) {
    double total   = 0.0;
    int    inv_size = (instrument == INSTRUMENT_EURUSD) ? ArraySize(g_inventory_EURUSD)
                    : (instrument == INSTRUMENT_GBPUSD) ? ArraySize(g_inventory_GBPUSD)
                    : ArraySize(g_inventory_EURGBP);

    for (int i = 0; i < inv_size; i++) {
        ulong ticket = (instrument == INSTRUMENT_EURUSD) ? g_inventory_EURUSD[i].position_ticket
                     : (instrument == INSTRUMENT_GBPUSD) ? g_inventory_GBPUSD[i].position_ticket
                     : g_inventory_EURGBP[i].position_ticket;

        if (PositionSelectByTicket(ticket))
            total += PositionGetDouble(POSITION_PROFIT);
    }
    return total;
}

//------------------------------------------------------------------
// ClosePodPositions
// Closes all open positions and cancels all pending orders for a
// single instrument only. Leaves other instruments completely
// untouched. Called by Tier 1 per-pod circuit breaker.
//------------------------------------------------------------------
void ClosePodPositions(int instrument) {
    string symbol = (instrument == INSTRUMENT_EURUSD) ? "EURUSD"
                  : (instrument == INSTRUMENT_GBPUSD) ? "GBPUSD"
                  : "EURGBP";

    Print("INFO: ClosePodPositions — amputating ", symbol, " pod.");

    // Close all open positions for this instrument
    int inv_size = (instrument == INSTRUMENT_EURUSD) ? ArraySize(g_inventory_EURUSD)
                 : (instrument == INSTRUMENT_GBPUSD) ? ArraySize(g_inventory_GBPUSD)
                 : ArraySize(g_inventory_EURGBP);

    for (int i = inv_size - 1; i >= 0; i--) {
        ulong ticket = (instrument == INSTRUMENT_EURUSD) ? g_inventory_EURUSD[i].position_ticket
                     : (instrument == INSTRUMENT_GBPUSD) ? g_inventory_GBPUSD[i].position_ticket
                     : g_inventory_EURGBP[i].position_ticket;

        if (!PositionSelectByTicket(ticket)) continue;

        MqlTradeRequest req = {};
        MqlTradeResult  res = {};
        req.action    = TRADE_ACTION_DEAL;
        req.symbol    = symbol;
        req.volume    = PositionGetDouble(POSITION_VOLUME);
        req.magic     = EA_MAGIC;
        req.type      = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
                        ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
        req.price     = (req.type == ORDER_TYPE_SELL)
                        ? SymbolInfoDouble(symbol, SYMBOL_BID)
                        : SymbolInfoDouble(symbol, SYMBOL_ASK);
        req.type_filling = ORDER_FILLING_IOC;
        req.deviation = 10;
        req.comment   = "FXMatrix_PodAmputation";

        if (!OrderSend(req, res))
            Print("WARNING: ClosePodPositions — close failed. ",
                  "ticket=", ticket, " retcode=", res.retcode);
    }

    // Cancel all pending orders for this instrument
    for (int i = OrdersTotal() - 1; i >= 0; i--) {
        ulong ticket = OrderGetTicket(i);
        if (ticket == 0) continue;
        if (OrderGetInteger(ORDER_MAGIC) != (long)EA_MAGIC) continue;
        if (OrderGetString(ORDER_SYMBOL) != symbol) continue;

        MqlTradeRequest req = {};
        MqlTradeResult  res = {};
        req.action = TRADE_ACTION_REMOVE;
        req.order  = ticket;
        OrderSend(req, res);
    }

    // Clear per-instrument globals
    if (instrument == INSTRUMENT_EURUSD) {
        g_pending_entry_EURUSD = 0;
        g_add_next_EURUSD      = 0;
        ArrayResize(g_inventory_EURUSD, 0);
    } else if (instrument == INSTRUMENT_GBPUSD) {
        g_pending_entry_GBPUSD = 0;
        g_add_next_GBPUSD      = 0;
        ArrayResize(g_inventory_GBPUSD, 0);
    } else {
        g_pending_entry_EURGBP = 0;
        g_add_next_EURGBP      = 0;
        ArrayResize(g_inventory_EURGBP, 0);
    }

    SaveAllInventoryState();
    Print("INFO: ClosePodPositions — ", symbol, " pod amputated.");
}

void CheckCircuitBreakers() {
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    if (balance <= 0.0) return;

    // ── Tier 1: Per-Pod Isolation ─────────────────────────────────────────
    // If any single instrument's unrealised P&L breaches MaxPodDrawdown,
    // amputate that instrument only. Other instruments continue operating.
    int target_instruments[3] = {INSTRUMENT_EURUSD, INSTRUMENT_GBPUSD,
                                  INSTRUMENT_EURGBP};

    for (int k = 0; k < 3; k++) {
        int inst = target_instruments[k];

        int inv_size = (inst == INSTRUMENT_EURUSD) ? ArraySize(g_inventory_EURUSD)
                     : (inst == INSTRUMENT_GBPUSD) ? ArraySize(g_inventory_GBPUSD)
                     : ArraySize(g_inventory_EURGBP);

        if (inv_size == 0) continue;

        double pod_pnl = GetPodUnrealizedPnL(inst);

        if (pod_pnl < -(balance * MaxPodDrawdown)) {
            string symbol = (inst == INSTRUMENT_EURUSD) ? "EURUSD"
                          : (inst == INSTRUMENT_GBPUSD) ? "GBPUSD"
                          : "EURGBP";
            Print("CRITICAL: Per-pod circuit breaker fired. ",
                  "instrument=", symbol,
                  " unrealised=", DoubleToString(pod_pnl, 2),
                  " threshold=", DoubleToString(-(balance * MaxPodDrawdown), 2));
            ClosePodPositions(inst);
        }
    }

    // ── Tier 2: Global Nuclear Failsafe ───────────────────────────────────
    // If total account equity drops below GlobalDrawdown, hard halt
    // everything. This front-runs the FTMO 5% daily loss limit.
    double total_unrealised = AccountInfoDouble(ACCOUNT_PROFIT);

    if (total_unrealised < -(balance * GlobalDrawdown)) {
        Print("CRITICAL: Global nuclear failsafe fired. ",
              "total_unrealised=", DoubleToString(total_unrealised, 2),
              " threshold=", DoubleToString(-(balance * GlobalDrawdown), 2));
        CloseAllPositions();
        CancelAllPendingEntries();
        g_halted = true;
    }
}

void CloseAllPositions() {
    for (int i = PositionsTotal() - 1; i >= 0; i--) {
        ulong ticket = PositionGetTicket(i);
        if (ticket == 0) continue;
        if (PositionGetInteger(POSITION_MAGIC) != (long)EA_MAGIC) continue;

        MqlTradeRequest req = {};
        MqlTradeResult  res = {};
        req.action   = TRADE_ACTION_DEAL;
        req.position = ticket;
        req.symbol   = PositionGetString(POSITION_SYMBOL);
        req.volume   = PositionGetDouble(POSITION_VOLUME);
        req.type     = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
                       ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
        req.price    = (req.type == ORDER_TYPE_SELL)
                       ? SymbolInfoDouble(req.symbol, SYMBOL_BID)
                       : SymbolInfoDouble(req.symbol, SYMBOL_ASK);
        req.type_filling = ORDER_FILLING_IOC;
        req.comment  = "FXMatrix_CircuitBreaker";

        if (!OrderSend(req, res))
            Print("ERROR: CloseAllPositions failed. ticket=", ticket,
                  " retcode=", res.retcode);
    }
}

void CancelAllPending() {
    for (int i = OrdersTotal() - 1; i >= 0; i--) {
        ulong ticket = OrderGetTicket(i);
        if (ticket == 0) continue;
        if (OrderGetInteger(ORDER_MAGIC) != (long)EA_MAGIC) continue;

        MqlTradeRequest req = {};
        MqlTradeResult  res = {};
        req.action = TRADE_ACTION_REMOVE;
        req.order  = ticket;

        if (!OrderSend(req, res))
            Print("ERROR: CancelAllPending failed. ticket=", ticket,
                  " retcode=", res.retcode);
    }
}

void CancelAllPendingEntries() {
    // Skip sweep if no tracked tickets AND no EA orders on book
    bool any_pending = (g_pending_entry_EURUSD > 0 ||
                        g_pending_entry_GBPUSD > 0 ||
                        g_pending_entry_EURGBP > 0);
    if (!any_pending && OrdersTotal() == 0) return;

    int cancelled = 0;
    for (int i = OrdersTotal() - 1; i >= 0; i--) {
        ulong ticket = OrderGetTicket(i);
        if (ticket == 0) continue;
        if (OrderGetInteger(ORDER_MAGIC) != (long)EA_MAGIC) continue;

        // Skip all three protected add_next tickets (Gemini ruling)
        if (ticket == g_add_next_EURUSD ||
            ticket == g_add_next_GBPUSD ||
            ticket == g_add_next_EURGBP) {
            if (EnableVerboseLog)
                Print("INFO: CancelAllPendingEntries — skipping protected "
                      "add_next ticket=", ticket);
            continue;
        }

        MqlTradeRequest req = {};
        MqlTradeResult  res = {};
        req.action = TRADE_ACTION_REMOVE;
        req.order  = ticket;

        if (!OrderSend(req, res)) {
            Print("WARNING: CancelAllPendingEntries — cancel failed. ",
                  "ticket=", ticket, " retcode=", res.retcode);
        } else {
            cancelled++;
            if (ticket == g_pending_entry_EURUSD) g_pending_entry_EURUSD = 0;
            else if (ticket == g_pending_entry_GBPUSD) g_pending_entry_GBPUSD = 0;
            else if (ticket == g_pending_entry_EURGBP) g_pending_entry_EURGBP = 0;
        }
    }

    g_pending_entry_EURUSD = 0;
    g_pending_entry_GBPUSD = 0;
    g_pending_entry_EURGBP = 0;
    SaveAllInventoryState();

    Print("INFO: CancelAllPendingEntries — cancelled ", cancelled,
          " pending orders");
}

void ProcessCloseByQueue() {
    int q_size = ArraySize(g_closeby_queue);
    if (q_size == 0) return;

    for (int i = q_size - 1; i >= 0; i--) {
        g_closeby_queue[i].retries++;

        if (g_closeby_queue[i].retries >= 10) {
            Print("SEV-1 ERROR: CloseBy queue task failed after 10 retries. ",
                  "position=", g_closeby_queue[i].ticket1,
                  " position_by=", g_closeby_queue[i].ticket2,
                  " — halting EA for human review.");
            ArrayRemove(g_closeby_queue, i, 1);
            g_halted = true;
            return;
        }

        if (!PositionSelectByTicket(g_closeby_queue[i].ticket1) ||
            !PositionSelectByTicket(g_closeby_queue[i].ticket2)) {
            // Check if broker already netted the position
            if (HistorySelectByPosition(g_closeby_queue[i].ticket1) ||
                HistorySelectByPosition(g_closeby_queue[i].ticket2)) {
                Print("INFO: CloseBy position already closed in history. "
                      "Discarding task gracefully.");
                ArrayRemove(g_closeby_queue, i, 1);
                continue;
            }
            // Genuine delay — retry
            Print("INFO: CloseBy queue retry ",
                  g_closeby_queue[i].retries, "/10 — positions not yet "
                  "on ledger. Waiting.");
            continue;
        }

        PositionSelectByTicket(g_closeby_queue[i].ticket1);
        string sym = PositionGetString(POSITION_SYMBOL);

        PositionSelectByTicket(g_closeby_queue[i].ticket2);
        string sym2 = PositionGetString(POSITION_SYMBOL);

        if (sym != sym2) {
            Print("ERROR: Inconsistent symbols in CloseBy queue. ",
                  "ticket1=", g_closeby_queue[i].ticket1,
                  " sym1=", sym,
                  " ticket2=", g_closeby_queue[i].ticket2,
                  " sym2=", sym2,
                  " — removing task and halting.");
            ArrayRemove(g_closeby_queue, i, 1);
            g_halted = true;
            return;
        }

        MqlTradeRequest req = {};
        MqlTradeResult  res = {};
        req.action      = TRADE_ACTION_CLOSE_BY;
        req.position    = g_closeby_queue[i].ticket1;
        req.position_by = g_closeby_queue[i].ticket2;
        req.symbol      = sym;
        req.magic       = EA_MAGIC;

        if (OrderSend(req, res)) {
            Print("INFO: CloseBy queue success on retry ",
                  g_closeby_queue[i].retries,
                  ". position=", g_closeby_queue[i].ticket1,
                  " position_by=", g_closeby_queue[i].ticket2);
            ArrayRemove(g_closeby_queue, i, 1);
        } else {
            Print("WARNING: CloseBy queue retry ", g_closeby_queue[i].retries,
                  "/10 failed. retcode=", res.retcode,
                  " position=", g_closeby_queue[i].ticket1,
                  " position_by=", g_closeby_queue[i].ticket2);
        }
    }
}

double GetPendingOrderPrice(ulong ticket) {
    if (OrderSelect(ticket))
        return OrderGetDouble(ORDER_PRICE_OPEN);
    return -1.0;
}
