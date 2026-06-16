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

    g_daily_start_balance = AccountInfoDouble(ACCOUNT_BALANCE);
    g_current_day         = 0; // force reset on first tick
    Print("INFO: FTMO failsafe initialised. ",
          "daily_start_balance=", DoubleToString(g_daily_start_balance, 2));

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

// --- ADR-018: NY Rollover Dead Zone Defense ---
// FTMO Server Time is UTC+3 (summer). NY Time is UTC-4 (summer).
// Delta: +7 hours. NY Dead Zone 5:00 PM to 7:00 PM ET
// translates to Broker Time 23:55 to 02:05 (with +/- 5 min buffer).
bool IsRolloverWindow(datetime current_time) {
    MqlDateTime dt;
    TimeToStruct(current_time, dt);
    if (dt.hour == 23 && dt.min >= 55) return true;
    if (dt.hour == 0 || dt.hour == 1)  return true;
    if (dt.hour == 2 && dt.min <= 5)   return true;
    return false;
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

            string inst_symbol = (inst == INSTRUMENT_EURUSD) ? "EURUSD"
                               : (inst == INSTRUMENT_GBPUSD) ? "GBPUSD"
                               : "EURGBP";

            // Derive strongest/weakest for this instrument
            int inst_strongest = 0, inst_weakest = 0;
            if (inst == INSTRUMENT_EURUSD) {
                inst_strongest = (scores[0] > scores[2]) ? 0 : 2;
                inst_weakest   = (scores[0] < scores[2]) ? 0 : 2;
            } else if (inst == INSTRUMENT_GBPUSD) {
                inst_strongest = (scores[1] > scores[2]) ? 1 : 2;
                inst_weakest   = (scores[1] < scores[2]) ? 1 : 2;
            } else {
                inst_strongest = (scores[0] > scores[1]) ? 0 : 1;
                inst_weakest   = (scores[0] < scores[1]) ? 0 : 1;
            }

            double inst_spread = scores[inst_weakest] - scores[inst_strongest];

            // Bid direction: buy the weak currency
            // Offer direction: sell the strong currency
            int bid_direction, offer_direction;
            if ((inst_strongest == 0 && inst_weakest == 1) ||
                (inst_strongest == 0 && inst_weakest == 2) ||
                (inst_strongest == 1 && inst_weakest == 2)) {
                // strongest is EUR or GBP vs weaker → SELL is offer, BUY is bid
                offer_direction = DIRECTION_SELL;
                bid_direction   = DIRECTION_BUY;
            } else {
                offer_direction = DIRECTION_BUY;
                bid_direction   = DIRECTION_SELL;
            }

            int inst_inv_size = (inst == INSTRUMENT_EURUSD) ? ArraySize(g_inventory_EURUSD)
                              : (inst == INSTRUMENT_GBPUSD) ? ArraySize(g_inventory_GBPUSD)
                              : ArraySize(g_inventory_EURGBP);

            ulong inst_bid   = (inst == INSTRUMENT_EURUSD) ? g_pending_bid_EURUSD
                             : (inst == INSTRUMENT_GBPUSD) ? g_pending_bid_GBPUSD
                             : g_pending_bid_EURGBP;
            ulong inst_offer = (inst == INSTRUMENT_EURUSD) ? g_pending_offer_EURUSD
                             : (inst == INSTRUMENT_GBPUSD) ? g_pending_offer_GBPUSD
                             : g_pending_offer_EURGBP;

            // ── Phase 3: re-arm add_next after sleep expiry ──────────────
            ulong inst_add_next = (inst == INSTRUMENT_EURUSD) ? g_add_next_EURUSD
                                : (inst == INSTRUMENT_GBPUSD) ? g_add_next_GBPUSD
                                : g_add_next_EURGBP;

            if (inst_inv_size > 0 && inst_add_next == 0) {
                datetime last_layer = (inst == INSTRUMENT_EURUSD)
                                      ? g_last_layer_time_EURUSD
                                      : (inst == INSTRUMENT_GBPUSD)
                                      ? g_last_layer_time_GBPUSD
                                      : g_last_layer_time_EURGBP;

                if (TimeCurrent() - last_layer >= MinLayerIntervalSeconds) {
                    int inv_size = inst_inv_size;
                    Layer deepest = (inst == INSTRUMENT_EURUSD)
                                    ? g_inventory_EURUSD[inv_size - 1]
                                    : (inst == INSTRUMENT_GBPUSD)
                                    ? g_inventory_GBPUSD[inv_size - 1]
                                    : g_inventory_EURGBP[inv_size - 1];

                    double computed = ComputeNextLayerPrice(
                        inv_size, deepest.instrument,
                        deepest.direction, deepest.entry_price);

                    if (computed > 0.0) {
                        if (!g_api_halt) {
                            PlaceNextEntryLimit(deepest, inst_symbol, computed);
                            g_daily_api_count++;
                            if (g_daily_api_count >= 1800) {
                                g_api_halt = true;
                                Print("WARNING: ADR-017 API halt tripped. g_daily_api_count=",
                                      g_daily_api_count);
                            }
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
                        } else {
                            Print("INFO: API halt active. Add-next re-arm blocked. ",
                                  "instrument=", inst_symbol);
                        }
                    }
                }
            }

            // Option A: skip quoting if inventory open on this instrument
            if (inst_inv_size > 0) continue;

            // ── ADR-017: Compute fair-value prices ───────────────────────
            double bid_spread   = inst_spread + QuoteSpread;
            double offer_spread = inst_spread - QuoteSpread;

            double bid_price = InvertSpreadToPrice(
                g_EU_mid_12bars_ago, g_GB_mid_12bars_ago,
                g_r_EU_signal, g_r_GB_signal,
                bid_spread, inst_strongest, inst_weakest,
                false, false);

            double offer_price = InvertSpreadToPrice(
                g_EU_mid_12bars_ago, g_GB_mid_12bars_ago,
                g_r_EU_signal, g_r_GB_signal,
                offer_spread, inst_strongest, inst_weakest,
                false, false);

            // ── ADR-017: Spatial deadband ────────────────────────────────
            double deadband = QuoteSpread * 0.25 - 0.5 * _Point;
            double current_bid_price   = (inst_bid   > 0)
                                         ? GetPendingOrderPrice(inst_bid)   : -1;
            double current_offer_price = (inst_offer > 0)
                                         ? GetPendingOrderPrice(inst_offer) : -1;

            if (!IsRolloverWindow(TimeCurrent()) &&
                current_bid_price   > 0 &&
                current_offer_price > 0 &&
                MathAbs(bid_price   - current_bid_price)   < deadband &&
                MathAbs(offer_price - current_offer_price) < deadband) {
                continue; // normal market hours: skip cancel+resubmit if valid
            }

            // ── ADR-017: g_api_halt gate ─────────────────────────────────
            if (g_api_halt) {
                Print("INFO: API halt active. Flat quoting blocked. ",
                      "instrument=", inst_symbol);
                continue;
            }

            // ── Cancel stale bid ─────────────────────────────────────────
            if (inst_bid > 0) {
                MqlTradeRequest req = {}; MqlTradeResult res = {};
                req.action = TRADE_ACTION_REMOVE;
                req.order  = inst_bid;
                if (OrderSend(req, res)) {
                    g_daily_api_count++;
                    if (g_daily_api_count >= 1800) {
                        g_api_halt = true;
                        Print("WARNING: ADR-017 API halt tripped. g_daily_api_count=",
                              g_daily_api_count);
                    }
                    if (inst == INSTRUMENT_EURUSD)      g_pending_bid_EURUSD   = 0;
                    else if (inst == INSTRUMENT_GBPUSD)  g_pending_bid_GBPUSD   = 0;
                    else                                  g_pending_bid_EURGBP   = 0;
                } else {
                    Print("INFO: Stale bid cancel failed retcode=", res.retcode,
                          " instrument=", inst_symbol,
                          " — possible fill in race window");
                }
            }

            // ── Cancel stale offer ───────────────────────────────────────
            if (inst_offer > 0) {
                MqlTradeRequest req = {}; MqlTradeResult res = {};
                req.action = TRADE_ACTION_REMOVE;
                req.order  = inst_offer;
                if (OrderSend(req, res)) {
                    g_daily_api_count++;
                    if (g_daily_api_count >= 1800) {
                        g_api_halt = true;
                        Print("WARNING: ADR-017 API halt tripped. g_daily_api_count=",
                              g_daily_api_count);
                    }
                    if (inst == INSTRUMENT_EURUSD)      g_pending_offer_EURUSD = 0;
                    else if (inst == INSTRUMENT_GBPUSD)  g_pending_offer_GBPUSD = 0;
                    else                                  g_pending_offer_EURGBP = 0;
                } else {
                    Print("INFO: Stale offer cancel failed retcode=", res.retcode,
                          " instrument=", inst_symbol,
                          " — possible fill in race window");
                }
            }

            // ── Place bid and offer (gated by rollover window) ───────────
            if (!IsRolloverWindow(TimeCurrent())) {
                if (bid_price > 0) {
                    ulong tkt = PlaceEntryLimit(bid_price, bid_direction, inst_symbol);
                    if (tkt > 0) {
                        g_daily_api_count++;
                        if (g_daily_api_count >= 1800) {
                            g_api_halt = true;
                            Print("WARNING: ADR-017 API halt tripped. g_daily_api_count=",
                                  g_daily_api_count);
                        }
                        if (inst == INSTRUMENT_EURUSD)      g_pending_bid_EURUSD   = tkt;
                        else if (inst == INSTRUMENT_GBPUSD)  g_pending_bid_GBPUSD   = tkt;
                        else                                  g_pending_bid_EURGBP   = tkt;
                        Print("INFO: ADR-014 bid placed. symbol=", inst_symbol,
                              " price=", DoubleToString(bid_price, 5),
                              " spread=", DoubleToString(bid_spread, 6));
                    }
                }

                if (offer_price > 0) {
                    ulong tkt = PlaceEntryLimit(offer_price, offer_direction, inst_symbol);
                    if (tkt > 0) {
                        g_daily_api_count++;
                        if (g_daily_api_count >= 1800) {
                            g_api_halt = true;
                            Print("WARNING: ADR-017 API halt tripped. g_daily_api_count=",
                                  g_daily_api_count);
                        }
                        if (inst == INSTRUMENT_EURUSD)      g_pending_offer_EURUSD = tkt;
                        else if (inst == INSTRUMENT_GBPUSD)  g_pending_offer_GBPUSD = tkt;
                        else                                  g_pending_offer_EURGBP = tkt;
                        Print("INFO: ADR-014 offer placed. symbol=", inst_symbol,
                              " price=", DoubleToString(offer_price, 5),
                              " spread=", DoubleToString(offer_spread, 6));
                    }
                }
            } else {
                Print("INFO: ADR-018 rollover window active. Placement suspended. ",
                      "instrument=", inst_symbol);
            }

            SaveAllInventoryState();
            // ── End ADR-014/ADR-017 quoting ──────────────────────────────

        } // End per-instrument loop
    } // End new_bar block
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
        if (!OrderSend(req, res))
            Print("WARNING: ClosePodPositions cancel failed. ticket=", ticket,
                  " retcode=", res.retcode);
    }

    // Clear per-instrument globals
    if (instrument == INSTRUMENT_EURUSD) {
        g_pending_bid_EURUSD   = 0;
        g_pending_offer_EURUSD = 0;
        g_add_next_EURUSD      = 0;
        ArrayResize(g_inventory_EURUSD, 0);
    } else if (instrument == INSTRUMENT_GBPUSD) {
        g_pending_bid_GBPUSD   = 0;
        g_pending_offer_GBPUSD = 0;
        g_add_next_GBPUSD      = 0;
        ArrayResize(g_inventory_GBPUSD, 0);
    } else {
        g_pending_bid_EURGBP   = 0;
        g_pending_offer_EURGBP = 0;
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

    // ── Tier 3: FTMO Equity Failsafe ─────────────────────────────────────
    // Enforces FTMO's two static equity floors on every tick.
    // State is broker-held — VPS restart safe.
    double current_equity  = AccountInfoDouble(ACCOUNT_EQUITY);
    double current_balance = AccountInfoDouble(ACCOUNT_BALANCE);

    // Midnight CET rollover — reset daily start balance
    MqlDateTime dt;
    TimeCurrent(dt);
    if (dt.day != g_current_day) {
        g_daily_start_balance = current_balance;
        g_current_day         = dt.day;
        g_daily_api_count = 0;
        g_api_halt        = false;
        Print("INFO: ADR-017 API counter reset. New day=", dt.day);
        Print("INFO: FTMO daily floor reset. ",
              "daily_start_balance=", DoubleToString(g_daily_start_balance, 2),
              " day=", g_current_day);
    }

    // FTMO hard floors
    double absolute_floor = FTMO_Initial_Balance * (1.0 - FTMO_Max_Loss_Pct);
    double daily_floor    = g_daily_start_balance
                            - (FTMO_Initial_Balance * FTMO_Daily_Loss_Pct);
    double active_floor   = MathMax(absolute_floor, daily_floor);

    if (current_equity <= active_floor) {
        Print("CRITICAL: FTMO equity failsafe fired. ",
              "equity=",        DoubleToString(current_equity, 2),
              " active_floor=", DoubleToString(active_floor, 2),
              " abs_floor=",    DoubleToString(absolute_floor, 2),
              " daily_floor=",  DoubleToString(daily_floor, 2));
        CloseAllPositions();
        CancelAllPendingEntries();
        g_halted = true;
    }
    // ── End Tier 3 ───────────────────────────────────────────────────────
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
    bool any_pending = (g_pending_bid_EURUSD > 0   || g_pending_offer_EURUSD > 0 ||
                        g_pending_bid_GBPUSD > 0   || g_pending_offer_GBPUSD > 0 ||
                        g_pending_bid_EURGBP > 0   || g_pending_offer_EURGBP > 0);
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
            if (ticket == g_pending_bid_EURUSD)        g_pending_bid_EURUSD   = 0;
            else if (ticket == g_pending_offer_EURUSD) g_pending_offer_EURUSD = 0;
            else if (ticket == g_pending_bid_GBPUSD)   g_pending_bid_GBPUSD   = 0;
            else if (ticket == g_pending_offer_GBPUSD) g_pending_offer_GBPUSD = 0;
            else if (ticket == g_pending_bid_EURGBP)   g_pending_bid_EURGBP   = 0;
            else if (ticket == g_pending_offer_EURGBP) g_pending_offer_EURGBP = 0;
        }
    }

    g_pending_bid_EURUSD   = 0;
    g_pending_offer_EURUSD = 0;
    g_pending_bid_GBPUSD   = 0;
    g_pending_offer_GBPUSD = 0;
    g_pending_bid_EURGBP   = 0;
    g_pending_offer_EURGBP = 0;
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
