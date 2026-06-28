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
#include "TelemetryEngine.mqh"

void CheckCircuitBreakers();
void CloseAllPositions();
void CancelAllPending();
void CancelAllPendingEntries();
void AuditExitLimits();
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

    LoadGlobalState();             // ADR-045: global scalars before inventory hydration
    LoadInventoryState(SLOT_AC);
    LoadInventoryState(SLOT_BC);
    LoadInventoryState(SLOT_AB);
    CheckForOrphans();
    if (g_halted) {
        Print("ERROR: OnInit halted — orphan positions detected. "
              "Resolve manually before reattaching EA.");
        return INIT_FAILED;
    }

    // ADR-040: Reconciliation pass — recompute exit_price_fixed for any sentinel layer
    int rearm_count = 0;
    for (int s = 0; s < 3; s++) {
        int inv_size = (s == 0) ? ArraySize(g_inventory_0)
                     : (s == 1) ? ArraySize(g_inventory_1)
                     : ArraySize(g_inventory_2);
        for (int i = 0; i < inv_size; i++) {
            double epf = (s == 0) ? g_inventory_0[i].exit_price_fixed
                       : (s == 1) ? g_inventory_1[i].exit_price_fixed
                       : g_inventory_2[i].exit_price_fixed;
            if (epf >= 0.0) continue;

            string sym = g_symbols[s];
            double pt  = SymbolInfoDouble(sym, SYMBOL_POINT);
            double entry_price = (s == 0) ? g_inventory_0[i].entry_price
                               : (s == 1) ? g_inventory_1[i].entry_price
                               : g_inventory_2[i].entry_price;
            double entry_spread_raw = (s == 0) ? g_inventory_0[i].entry_spread_raw
                                    : (s == 1) ? g_inventory_1[i].entry_spread_raw
                                    : g_inventory_2[i].entry_spread_raw;
            int layer_index = (s == 0) ? g_inventory_0[i].layer_index
                            : (s == 1) ? g_inventory_1[i].layer_index
                            : g_inventory_2[i].layer_index;
            int direction = (s == 0) ? g_inventory_0[i].direction
                          : (s == 1) ? g_inventory_1[i].direction
                          : g_inventory_2[i].direction;
            ulong entry_ticket = (s == 0) ? g_inventory_0[i].entry_ticket
                               : (s == 1) ? g_inventory_1[i].entry_ticket
                               : g_inventory_2[i].entry_ticket;

            double new_epf = ComputeExitPriceDeterministic(
                entry_price,
                entry_spread_raw,
                layer_index,
                direction,
                0.0,
                MinLayerExitPoints,
                pt);

            if (s == 0) {
                g_inventory_0[i].exit_price_fixed = new_epf;
                g_inventory_0[i].exit_target      = new_epf;
            } else if (s == 1) {
                g_inventory_1[i].exit_price_fixed = new_epf;
                g_inventory_1[i].exit_target      = new_epf;
            } else {
                g_inventory_2[i].exit_price_fixed = new_epf;
                g_inventory_2[i].exit_target      = new_epf;
            }

            PrintFormat("INFO [ADR-040] Reconciliation: recomputed exit_price_fixed=%.5f "
                        "for slot=%d layer=%d ticket=%d",
                        new_epf, s, layer_index, entry_ticket);
            rearm_count++;
        }
    }
    if (rearm_count > 0) {
        g_reconciliation_pending = true;
        PrintFormat("INFO [ADR-040] Reconciliation pass complete. %d layer(s) pending re-arm on first tick.",
                    rearm_count);
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
    int slot = GetInstrumentFromSymbol(sym);
    if (slot == SLOT_AC) {
        if (dir == DIRECTION_BUY) { out_strongest = 2; out_weakest = 0; }
        else                       { out_strongest = 0; out_weakest = 2; }
    } else if (slot == SLOT_BC) {
        if (dir == DIRECTION_BUY) { out_strongest = 2; out_weakest = 1; }
        else                       { out_strongest = 1; out_weakest = 2; }
    } else { // SLOT_AB
        if (dir == DIRECTION_BUY) { out_strongest = 1; out_weakest = 0; }
        else                       { out_strongest = 0; out_weakest = 1; }
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
    // F1 fix: CheckCircuitBreakers runs unconditionally — even when halted.
    // The FTMO equity failsafe must never be disabled by an internal halt.
    // Circuit breakers close positions and cancel orders before re-halting.
    CheckCircuitBreakers();
    if (g_halted) return;

    // ADR-040: Execute reconciliation re-arm on first live tick after reattach
    if (g_reconciliation_pending) {
        for (int s = 0; s < 3; s++) {
            int inv_size = (s == 0) ? ArraySize(g_inventory_0)
                         : (s == 1) ? ArraySize(g_inventory_1)
                         : ArraySize(g_inventory_2);
            for (int i = 0; i < inv_size; i++) {
                Layer L = (s == 0) ? g_inventory_0[i]
                        : (s == 1) ? g_inventory_1[i]
                        : g_inventory_2[i];
                if (L.exit_price_fixed <= 0.0) continue;
                if (ArraySize(L.exit_tickets) > 0) continue;
                if (L.remaining_exit_volume <= VOLUME_EPSILON) continue;

                string sym = g_symbols[s];
                ulong exit_tkt = PlaceExitLimit(L.exit_price_fixed,
                                                L.remaining_exit_volume,
                                                L.direction,
                                                sym);
                if (exit_tkt > 0) {
                    int n = ArraySize(L.exit_tickets);
                    if (s == 0) {
                        ArrayResize(g_inventory_0[i].exit_tickets, n + 1);
                        g_inventory_0[i].exit_tickets[n] = exit_tkt;
                    } else if (s == 1) {
                        ArrayResize(g_inventory_1[i].exit_tickets, n + 1);
                        g_inventory_1[i].exit_tickets[n] = exit_tkt;
                    } else {
                        ArrayResize(g_inventory_2[i].exit_tickets, n + 1);
                        g_inventory_2[i].exit_tickets[n] = exit_tkt;
                    }
                }
            }
        }
        g_reconciliation_pending = false;
        SaveAllInventoryState();
        Print("INFO [ADR-040] Reconciliation re-arm complete. g_reconciliation_pending cleared.");
    }

    // Process pending CloseBy tasks before any signal logic.
    // Resolves MT5 ledger desync on market hedge fills.
    AuditExitLimits();
    ProcessCloseByQueue();
    if (g_halted) return;

    if (ArraySize(g_inventory_0) > 0 ||
        ArraySize(g_inventory_1) > 0 ||
        ArraySize(g_inventory_2) > 0)
        CheckCarryTrigger();

    RunDailyRolloverReconciliation();

    datetime current_bar = iTime(_Symbol, PERIOD_M5, 0);
    bool new_bar = (current_bar != g_last_bar_time);

    // ── Option B: add_next grid layering (every tick) ──────────────────
    {
        int target_instruments[3] = {SLOT_AC, SLOT_BC, SLOT_AB};
        for (int k = 0; k < 3; k++) {
            int inst        = target_instruments[k];
            string inst_symbol = g_symbols[inst];

            int inst_inv_size = (inst == 0) ? ArraySize(g_inventory_0)
                              : (inst == 1) ? ArraySize(g_inventory_1)
                              : ArraySize(g_inventory_2);

            ulong inst_add_next = g_add_next[inst];

            // F3 fix: distinguish filled from dropped for add_next tickets.
            if (inst_add_next != 0 && !OrderSelect(inst_add_next)) {
                bool is_filled = false;
                if (HistoryOrderSelect(inst_add_next)) {
                    long state = HistoryOrderGetInteger(inst_add_next, ORDER_STATE);
                    is_filled  = (state == ORDER_STATE_FILLED ||
                                  state == ORDER_STATE_PARTIAL);
                }
                if (!is_filled) {
                    Print("WARNING: add_next stale — broker dropped order. ",
                          "instrument=", inst_symbol,
                          " ticket=", inst_add_next);
                    g_add_next[inst] = 0;
                    inst_add_next    = 0;
                }
            }

            if (inst_inv_size > 0 && inst_add_next == 0) {
                datetime last_layer = g_last_layer_time[inst];
                if (TimeCurrent() - last_layer >= MinLayerIntervalSeconds) {
                    int inv_size = inst_inv_size;
                    Layer deepest = (inst == 0) ? g_inventory_0[inv_size - 1]
                                  : (inst == 1) ? g_inventory_1[inv_size - 1]
                                  : g_inventory_2[inv_size - 1];
                    double computed = ComputeNextLayerPrice(
                        inv_size, deepest.instrument,
                        deepest.direction, deepest.entry_price);
                    if (computed > 0.0) {
                        if (!g_api_halt) {
                            PlaceNextEntryLimit(deepest, inst_symbol, computed);
                            g_daily_api_count++;
                            if (g_daily_api_count >= 900) {
                                g_api_halt = true;
                                Print("WARNING: ADR-017 API halt tripped. ",
                                      "g_daily_api_count=", g_daily_api_count);
                            }
                            g_last_layer_time[inst] = TimeCurrent();
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
        }
    }

    if (new_bar) {
        g_last_bar_time = current_bar;

        RunSignalOnBarClose();

        RunSpreadCooldownReconciliation();

        // Per-instrument Option A deafness (Gemini Phase 2d ruling).
        // Each instrument evaluates independently. A pod open on EURGBP
        // does not suppress signal evaluation on EURUSD or GBPUSD.
        // Entry direction derived at point of use from instrument enum.

        // V3: use g_scores[] directly — already slot-indexed
        int target_instruments[3] = {SLOT_AC, SLOT_BC, SLOT_AB};

        for (int k = 0; k < 3; k++) {
            int inst = target_instruments[k];

            string inst_symbol = g_symbols[inst];

            // ADR: Structural slot routing fix.
            // Replace score-dependent strongest/weakest derivation with
            // direction-based structural mapping. Score comparisons collapse
            // to inst_strongest == inst_weakest when scores are equal,
            // inverting bid/offer directions and causing machine-gun fills.
            //
            // inst_spread magnitude still derived from signal scores (correct).
            // Only the INDEX pair passed to InvertSpreadToPrice is structural.

            double inst_spread = 0.0;
            int bid_strongest, bid_weakest, offer_strongest, offer_weakest;
            int bid_direction, offer_direction;

            if (inst == SLOT_AC) {
                // PairAC: A vs C
                // BUY:  A strongest (0), C weakest (2) — buy A
                // SELL: C strongest (2), A weakest (0) — sell A
                bid_strongest   = 2; bid_weakest   = 0;
                offer_strongest = 0; offer_weakest = 2;
                bid_direction   = DIRECTION_BUY;
                offer_direction = DIRECTION_SELL;
                inst_spread     = g_scores[0] - g_scores[2]; // A score - C score
            } else if (inst == SLOT_BC) {
                // PairBC: B vs C
                // BUY:  B strongest (1), C weakest (2) — buy B
                // SELL: C strongest (2), B weakest (1) — sell B
                bid_strongest   = 2; bid_weakest   = 1;
                offer_strongest = 1; offer_weakest = 2;
                bid_direction   = DIRECTION_BUY;
                offer_direction = DIRECTION_SELL;
                inst_spread     = g_scores[1] - g_scores[2]; // B score - C score
            } else {
                // SLOT_AB: PairAB: A vs B
                // BUY:  A strongest (0), B weakest (1) — buy A
                // SELL: B strongest (1), A weakest (0) — sell A
                bid_strongest   = 1; bid_weakest   = 0;
                offer_strongest = 0; offer_weakest = 1;
                bid_direction   = DIRECTION_BUY;
                offer_direction = DIRECTION_SELL;
                inst_spread     = g_scores[0] - g_scores[1]; // A score - B score
            }

            int inst_inv_size = (inst == 0) ? ArraySize(g_inventory_0)
                              : (inst == 1) ? ArraySize(g_inventory_1)
                              : ArraySize(g_inventory_2);

            ulong inst_bid      = g_pending_bid[inst];
            ulong inst_offer    = g_pending_offer[inst];

            // Option A: skip quoting if inventory open OR pending orders exist on this instrument
            if (inst_inv_size > 0 || inst_bid > 0 || inst_offer > 0) continue;

            // ── ADR-017: Compute fair-value prices ───────────────────────
            // ADR-052 Step C: Dynamic half-spread expands with term structure dispersion
            double dynamic_hs   = ComputeDynamicHalfSpread(inst);
            double bid_spread   = inst_spread - dynamic_hs;
            double offer_spread = inst_spread + dynamic_hs;

            double bid_price = InvertSpreadToPrice(
                g_anchor[0], g_anchor[1],
                g_r_signal[0], g_r_signal[1],
                bid_spread, bid_strongest, bid_weakest,
                false, false);

            double offer_price = InvertSpreadToPrice(
                g_anchor[0], g_anchor[1],
                g_r_signal[0], g_r_signal[1],
                offer_spread, offer_strongest, offer_weakest,
                false, false);

            // ── ADR-019: Mode fork ───────────────────────────────────────
            if (ExecutionMode == MARKET_MAKER) {

                // ADR-037: gate Option A if signal too weak to support exit floor
                double phi     = 0.6180339887;
                double point   = SymbolInfoDouble(inst_symbol, SYMBOL_POINT);
                double floor_n = MathMax(SkewFloor0 * MathPow(phi, 0), MinLayerExitPoints * point);
                if (MathAbs(inst_spread) <= floor_n) {
                    Print("INFO: ADR-037 weak signal — baseline bracket fallback. ",
                          "instrument=", inst_symbol,
                          " abs_spread=", DoubleToString(MathAbs(inst_spread), 6),
                          " floor_n=", DoubleToString(floor_n, 6),
                          " SkewFloor0=", DoubleToString(SkewFloor0, 6),
                          " MinLayerExitPoints=", MinLayerExitPoints);
                    bid_spread   = -QuoteSpread;
                    offer_spread =  QuoteSpread;
                    bid_price = InvertSpreadToPrice(
                        g_anchor[0], g_anchor[1],
                        g_r_signal[0], g_r_signal[1],
                        bid_spread, bid_strongest, bid_weakest,
                        false, false);
                    offer_price = InvertSpreadToPrice(
                        g_anchor[0], g_anchor[1],
                        g_r_signal[0], g_r_signal[1],
                        offer_spread, offer_strongest, offer_weakest,
                        false, false);
                }

                // ── ADR-017: Spatial deadband (two-sided) ────────────────
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
                    continue;
                }

                // ── ADR-017: g_api_halt gate ─────────────────────────────
                if (g_api_halt) {
                    Print("INFO: API halt active. Flat quoting blocked. ",
                          "instrument=", inst_symbol);
                    continue;
                }

                // ── Cancel stale bid ─────────────────────────────────────
                if (inst_bid > 0) {
                    MqlTradeRequest req = {}; MqlTradeResult res = {};
                    req.action = TRADE_ACTION_REMOVE;
                    req.order  = inst_bid;
                    if (OrderSend(req, res)) {
                        g_daily_api_count++;
                        if (g_daily_api_count >= 900) {
                            g_api_halt = true;
                            Print("WARNING: ADR-017 API halt tripped. g_daily_api_count=",
                                  g_daily_api_count);
                        }
                        g_pending_bid[inst] = 0;
                    } else {
                        Print("INFO: Stale bid cancel failed retcode=", res.retcode,
                              " instrument=", inst_symbol,
                              " — possible fill in race window");
                    }
                }

                // ── Cancel stale offer ───────────────────────────────────
                if (inst_offer > 0) {
                    MqlTradeRequest req = {}; MqlTradeResult res = {};
                    req.action = TRADE_ACTION_REMOVE;
                    req.order  = inst_offer;
                    if (OrderSend(req, res)) {
                        g_daily_api_count++;
                        if (g_daily_api_count >= 900) {
                            g_api_halt = true;
                            Print("WARNING: ADR-017 API halt tripped. g_daily_api_count=",
                                  g_daily_api_count);
                        }
                        g_pending_offer[inst] = 0;
                    } else {
                        Print("INFO: Stale offer cancel failed retcode=", res.retcode,
                              " instrument=", inst_symbol,
                              " — possible fill in race window");
                    }
                }

                // ── ADR-042 Fix: Slot-level LDAK suppression gate ────────
                // Evaluated once per slot before placing either bid or offer.
                // Symmetric: either both limits are placed or neither is.
                if (IsSlotSuppressedByLDAK(inst)) {
                    Print("INFO [LDAK] Slot suppressed — both directions blocked.",
                          " instrument=", inst_symbol);
                    continue;
                }

                // ── Place bid and offer (gated by rollover window) ───────
                if (!IsRolloverWindow(TimeCurrent())) {
                    if (bid_price > 0) {
                        ulong tkt = PlaceEntryLimit(bid_price, bid_direction, inst_symbol, inst);
                        if (tkt > 0) {
                            g_daily_api_count++;
                            if (g_daily_api_count >= 900) {
                                g_api_halt = true;
                                Print("WARNING: ADR-017 API halt tripped. g_daily_api_count=",
                                      g_daily_api_count);
                            }
                            g_pending_bid[inst] = tkt;
                            Print("INFO: ADR-014 bid placed. symbol=", inst_symbol,
                                  " price=", DoubleToString(bid_price, 5),
                                  " spread=", DoubleToString(bid_spread, 6));
                        }
                    }

                    if (offer_price > 0) {
                        ulong tkt = PlaceEntryLimit(offer_price, offer_direction, inst_symbol, inst);
                        if (tkt > 0) {
                            g_daily_api_count++;
                            if (g_daily_api_count >= 900) {
                                g_api_halt = true;
                                Print("WARNING: ADR-017 API halt tripped. g_daily_api_count=",
                                      g_daily_api_count);
                            }
                            g_pending_offer[inst] = tkt;
                            Print("INFO: ADR-014 offer placed. symbol=", inst_symbol,
                                  " price=", DoubleToString(offer_price, 5),
                                  " spread=", DoubleToString(offer_spread, 6));
                        }
                    }
                } else {
                    Print("INFO: ADR-018 rollover window active. Placement suspended. ",
                          "instrument=", inst_symbol);
                }

            } else { // SNIPER mode

                // ── ADR-019: Sniper — determine active direction ─────────
                bool signal_is_bid   = (inst_spread > 0);
                double signal_mag    = MathAbs(inst_spread);
                ulong  active_ticket = signal_is_bid ? inst_bid : inst_offer;
                double active_price  = signal_is_bid ? bid_price : offer_price;
                int    active_dir    = signal_is_bid ? bid_direction : offer_direction;

                // ── ADR-019: Cancel opposite-side order (direction flip) ──
                ulong opposite_ticket = signal_is_bid ? inst_offer : inst_bid;
                if (opposite_ticket > 0) {
                    MqlTradeRequest req = {}; MqlTradeResult res = {};
                    req.action = TRADE_ACTION_REMOVE;
                    req.order  = opposite_ticket;
                    if (OrderSend(req, res)) {
                        g_daily_api_count++;
                        if (g_daily_api_count >= 900) {
                            g_api_halt = true;
                            Print("WARNING: ADR-017 API halt tripped. g_daily_api_count=",
                                  g_daily_api_count);
                        }
                        if (signal_is_bid)
                            g_pending_offer[inst] = 0;
                        else
                            g_pending_bid[inst] = 0;
                        Print("INFO: ADR-019 Sniper — opposite-side order cancelled on direction flip. ",
                              "instrument=", inst_symbol);
                    }
                }

                if (signal_mag <= SniperThreshold) {
                    // Signal below gate — cancel active resting order, place nothing
                    if (active_ticket > 0) {
                        MqlTradeRequest req = {}; MqlTradeResult res = {};
                        req.action = TRADE_ACTION_REMOVE;
                        req.order  = active_ticket;
                        if (OrderSend(req, res)) {
                            g_daily_api_count++;
                            if (g_daily_api_count >= 900) {
                                g_api_halt = true;
                                Print("WARNING: ADR-017 API halt tripped. g_daily_api_count=",
                                      g_daily_api_count);
                            }
                            if (signal_is_bid)
                                g_pending_bid[inst] = 0;
                            else
                                g_pending_offer[inst] = 0;
                            Print("INFO: ADR-019 Sniper — signal below threshold, order cancelled. ",
                                  "instrument=", inst_symbol,
                                  " signal_mag=", DoubleToString(signal_mag, 6));
                        }
                    }

                } else {
                    // Signal active — single-sided deadband then place
                    // ADR-051: SNIPER order expiry — cancel if unfilled after SniperExpiryBars bars.
                    // Uses ORDER_TIME_SETUP from MT5 broker — stateless, survives VPS reboots.
                    if (active_ticket > 0) {
                        if (OrderSelect(active_ticket)) {
                            datetime setup_time  = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
                            int      bars_elapsed = (int)((TimeCurrent() - setup_time) / 300);
                            if (bars_elapsed >= SniperExpiryBars) {
                                MqlTradeRequest req = {}; MqlTradeResult res = {};
                                req.action = TRADE_ACTION_REMOVE;
                                req.order  = active_ticket;
                                if (OrderSend(req, res)) {
                                    g_daily_api_count++;
                                    if (g_daily_api_count >= 900) {
                                        g_api_halt = true;
                                        Print("WARNING: ADR-017 API halt tripped. g_daily_api_count=",
                                              g_daily_api_count);
                                    }
                                    if (signal_is_bid)
                                        g_pending_bid[inst] = 0;
                                    else
                                        g_pending_offer[inst] = 0;
                                    active_ticket = 0;
                                    Print("INFO [ADR-051] SNIPER order expired and cancelled.",
                                          " symbol=", inst_symbol,
                                          " bars_elapsed=", bars_elapsed,
                                          " ticket=", req.order);
                                } else {
                                    Print("WARNING [ADR-051] SNIPER expiry cancel failed.",
                                          " retcode=", res.retcode,
                                          " ticket=", active_ticket);
                                }
                            }
                        }
                    }
                    double deadband = QuoteSpread * 0.25 - 0.5 * _Point;
                    double current_active_price = (active_ticket > 0)
                                                  ? GetPendingOrderPrice(active_ticket) : -1;

                    if (!IsRolloverWindow(TimeCurrent()) &&
                        current_active_price > 0 &&
                        MathAbs(active_price - current_active_price) < deadband) {
                        // Resting order within deadband — skip cancel+resubmit
                    } else {
                        if (g_api_halt) {
                            Print("INFO: API halt active. Sniper placement blocked. ",
                                  "instrument=", inst_symbol);
                        } else {
                            // Cancel stale active order
                            if (active_ticket > 0) {
                                MqlTradeRequest req = {}; MqlTradeResult res = {};
                                req.action = TRADE_ACTION_REMOVE;
                                req.order  = active_ticket;
                                if (OrderSend(req, res)) {
                                    g_daily_api_count++;
                                    if (g_daily_api_count >= 900) {
                                        g_api_halt = true;
                                        Print("WARNING: ADR-017 API halt tripped. g_daily_api_count=",
                                              g_daily_api_count);
                                    }
                                    if (signal_is_bid)
                                        g_pending_bid[inst] = 0;
                                    else
                                        g_pending_offer[inst] = 0;
                                }
                            }

                            // Place single-sided limit
                            if (!IsRolloverWindow(TimeCurrent()) && active_price > 0) {
                                ulong tkt = PlaceEntryLimit(active_price, active_dir, inst_symbol, inst);
                                if (tkt > 0) {
                                    g_daily_api_count++;
                                    if (g_daily_api_count >= 900) {
                                        g_api_halt = true;
                                        Print("WARNING: ADR-017 API halt tripped. g_daily_api_count=",
                                              g_daily_api_count);
                                    }
                                    if (signal_is_bid)
                                        g_pending_bid[inst] = tkt;
                                    else
                                        g_pending_offer[inst] = tkt;
                                    Print("INFO: ADR-019 Sniper order placed. symbol=", inst_symbol,
                                          " direction=", (signal_is_bid ? "BID" : "OFFER"),
                                          " price=", DoubleToString(active_price, 5),
                                          " signal_mag=", DoubleToString(signal_mag, 6));
                                }
                            } else {
                                Print("INFO: ADR-018 rollover window active. Sniper placement suspended. ",
                                      "instrument=", inst_symbol);
                            }
                        }
                    }
                }

            } // end SNIPER mode

            SaveAllInventoryState();
            // ── End ADR-014/ADR-017/ADR-019 quoting ─────────────────────

        } // End per-instrument loop
    } // End new_bar block

    // ── Pipshed telemetry heartbeat ──────────────────────────────
    EmitTelemetry();
}

//------------------------------------------------------------------
// GetPodUnrealizedPnL
// Returns the total unrealised P&L for all open positions belonging
// to a single instrument's inventory. Uses PositionSelectByTicket()
// to read live broker P&L per layer — strictly isolated per instrument.
//------------------------------------------------------------------
double GetPodUnrealizedPnL(int instrument) {
    double total   = 0.0;
    int    inv_size = (instrument == 0) ? ArraySize(g_inventory_0)
                    : (instrument == 1) ? ArraySize(g_inventory_1)
                    : ArraySize(g_inventory_2);

    for (int i = 0; i < inv_size; i++) {
        ulong ticket = (instrument == 0) ? g_inventory_0[i].position_ticket
                     : (instrument == 1) ? g_inventory_1[i].position_ticket
                     : g_inventory_2[i].position_ticket;

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
    string symbol = g_symbols[instrument];

    Print("INFO: ClosePodPositions — amputating ", symbol, " pod.");

    int inv_size = (instrument == 0) ? ArraySize(g_inventory_0)
                 : (instrument == 1) ? ArraySize(g_inventory_1)
                 : ArraySize(g_inventory_2);

    for (int i = inv_size - 1; i >= 0; i--) {
        ulong ticket = (instrument == 0) ? g_inventory_0[i].position_ticket
                     : (instrument == 1) ? g_inventory_1[i].position_ticket
                     : g_inventory_2[i].position_ticket;

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

    // Clear slot globals
    g_pending_bid[instrument]   = 0;
    g_pending_offer[instrument] = 0;
    g_add_next[instrument]      = 0;
    if (instrument == 0)      ArrayResize(g_inventory_0, 0);
    else if (instrument == 1) ArrayResize(g_inventory_1, 0);
    else                      ArrayResize(g_inventory_2, 0);

    SaveAllInventoryState();
    Print("INFO: ClosePodPositions — ", symbol, " pod amputated.");
}

void CheckCircuitBreakers() {
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    if (balance <= 0.0) return;

    // ── Tier 1: Per-Pod Isolation ─────────────────────────────────────────
    // If any single instrument's unrealised P&L breaches MaxPodDrawdown,
    // amputate that instrument only. Other instruments continue operating.
    for (int k = 0; k < 3; k++) {
        int inst = k;

        int inv_size = (inst == 0) ? ArraySize(g_inventory_0)
                     : (inst == 1) ? ArraySize(g_inventory_1)
                     : ArraySize(g_inventory_2);

        if (inv_size == 0) continue;

        double pod_pnl = GetPodUnrealizedPnL(inst);

        if (pod_pnl < -(balance * MaxPodDrawdown)) {
            Print("CRITICAL: Per-pod circuit breaker fired. ",
                  "instrument=", g_symbols[inst],
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
        // F1 fix: cancel ALL orders across all EA magic variants
        // Exit limits (EA_MAGIC+2) and add_next (EA_MAGIC+1) are not
        // touched by CancelAllPendingEntries — cancel them explicitly here
        // to prevent GTC exit limits from filling against closed positions.
        for (int _i = OrdersTotal() - 1; _i >= 0; _i--) {
            ulong _tkt = OrderGetTicket(_i);
            if (_tkt == 0) continue;
            long _m = OrderGetInteger(ORDER_MAGIC);
            if (_m != (long)EA_MAGIC &&
                _m != (long)(EA_MAGIC + 1) &&
                _m != (long)(EA_MAGIC + 2)) continue;
            MqlTradeRequest _req = {};
            MqlTradeResult  _res = {};
            _req.action = TRADE_ACTION_REMOVE;
            _req.order  = _tkt;
            if (!OrderSend(_req, _res))
                Print("WARNING: F1 failsafe — cancel failed. ticket=", _tkt,
                      " retcode=", _res.retcode);
        }
        // Clear all inventory arrays and persist clean state
        ArrayResize(g_inventory_0, 0);
        ArrayResize(g_inventory_1, 0);
        ArrayResize(g_inventory_2, 0);
        SaveAllInventoryState();
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
    bool any_pending = (g_pending_bid[0] > 0 || g_pending_offer[0] > 0 ||
                        g_pending_bid[1] > 0 || g_pending_offer[1] > 0 ||
                        g_pending_bid[2] > 0 || g_pending_offer[2] > 0);
    if (!any_pending && OrdersTotal() == 0) return;

    int cancelled = 0;
    for (int i = OrdersTotal() - 1; i >= 0; i--) {
        ulong ticket = OrderGetTicket(i);
        if (ticket == 0) continue;
        if (OrderGetInteger(ORDER_MAGIC) != (long)EA_MAGIC) continue;

        // Skip all three protected add_next tickets (Gemini ruling)
        if (ticket == g_add_next[0] ||
            ticket == g_add_next[1] ||
            ticket == g_add_next[2]) {
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
            for (int s = 0; s < 3; s++) {
                if (ticket == g_pending_bid[s])   { g_pending_bid[s]   = 0; break; }
                if (ticket == g_pending_offer[s]) { g_pending_offer[s] = 0; break; }
            }
        }
    }

    for (int s = 0; s < 3; s++) {
        g_pending_bid[s]   = 0;
        g_pending_offer[s] = 0;
    }
    SaveAllInventoryState();

    Print("INFO: CancelAllPendingEntries — cancelled ", cancelled,
          " pending orders");
}

//------------------------------------------------------------------
// AuditExitLimits
// Continuous state reconciliation — runs every OnTick.
// Scans all open layers across all three slots. If any layer is
// fully filled (remaining_entry_volume <= VOLUME_EPSILON) but has
// no physical exit ticket (ArraySize(exit_tickets) == 0), attempts
// to place the exit limit again via PlaceExitLimit().
//
// This resolves the fire-and-forget blind spot in HandleEntryFill:
// if PlaceExitLimit() fails at fill time due to broker freeze level
// or passivity failure, the exit is orphaned. AuditExitLimits()
// retries every tick until market conditions allow placement.
//------------------------------------------------------------------
void AuditExitLimits() {
    for (int slot = 0; slot < 3; slot++) {
        int inv_size = (slot == 0) ? ArraySize(g_inventory_0)
                     : (slot == 1) ? ArraySize(g_inventory_1)
                     : ArraySize(g_inventory_2);

        for (int i = 0; i < inv_size; i++) {
            Layer L = (slot == 0) ? g_inventory_0[i]
                    : (slot == 1) ? g_inventory_1[i]
                    : g_inventory_2[i];

            // Skip if entry not fully filled yet
            if (L.remaining_entry_volume > VOLUME_EPSILON) continue;

            // Skip if exit already placed and at least one ticket is still live
            if (ArraySize(L.exit_tickets) > 0) {
                // F3 fix: distinguish filled from dropped for exit tickets.
                // A filled ticket that hasn't been processed by OnTradeTransaction
                // yet will fail OrderSelect — must not re-place on top of it.
                bool any_live_or_filled = false;
                for (int t = 0; t < ArraySize(L.exit_tickets); t++) {
                    ulong tkt = L.exit_tickets[t];
                    if (OrderSelect(tkt)) {
                        // Still resting on book
                        any_live_or_filled = true;
                        break;
                    }
                    // Not in live book — check history
                    if (HistoryOrderSelect(tkt)) {
                        long state = HistoryOrderGetInteger(tkt, ORDER_STATE);
                        if (state == ORDER_STATE_FILLED ||
                            state == ORDER_STATE_PARTIAL) {
                            // Filled but not yet processed — leave it
                            any_live_or_filled = true;
                            break;
                        }
                        // Cancelled/rejected/expired — genuinely dropped, fall through
                    }
                    // Not in live book or history — also genuinely dropped
                }
                if (any_live_or_filled) continue;
                // All tickets stale — clear inventory array directly (L is a value copy)
                if (slot == 0)      ArrayResize(g_inventory_0[i].exit_tickets, 0);
                else if (slot == 1) ArrayResize(g_inventory_1[i].exit_tickets, 0);
                else                ArrayResize(g_inventory_2[i].exit_tickets, 0);
                // Re-read L so downstream ArraySize(L.exit_tickets) == 0
                L = (slot == 0) ? g_inventory_0[i]
                  : (slot == 1) ? g_inventory_1[i]
                  : g_inventory_2[i];
                Print("WARNING: AuditExitLimits — stale exit ticket(s) cleared. ",
                      "slot=", slot, " layer=", i, " — re-placing.");
            }

            // Skip if exit volume not armed yet
            if (L.remaining_exit_volume <= VOLUME_EPSILON) continue;

            // Layer is fully filled but missing exit — attempt placement
            // ADR-040: read deterministic exit price locked at fill time.
            string symbol    = g_symbols[slot];
            double exit_price = L.exit_price_fixed;

            if (exit_price < 0.0) {
                // Sentinel — retry next tick after reconciliation or fill
                continue;
            }

            // Silently attempt placement — no pre-placement log to avoid
            // flooding journal at 100x/second during freeze level conditions
            ulong exit_tkt = PlaceExitLimit(exit_price,
                                            L.remaining_exit_volume,
                                            L.direction,
                                            symbol);
            if (exit_tkt > 0) {
                int n = ArraySize(L.exit_tickets);
                if (slot == 0) {
                    ArrayResize(g_inventory_0[i].exit_tickets, n + 1);
                    g_inventory_0[i].exit_tickets[n] = exit_tkt;
                } else if (slot == 1) {
                    ArrayResize(g_inventory_1[i].exit_tickets, n + 1);
                    g_inventory_1[i].exit_tickets[n] = exit_tkt;
                } else {
                    ArrayResize(g_inventory_2[i].exit_tickets, n + 1);
                    g_inventory_2[i].exit_tickets[n] = exit_tkt;
                }
                SaveAllInventoryState();
                Print("INFO: AuditExitLimits — successfully recovered orphaned exit. ",
                      "slot=", slot, " layer=", i,
                      " ticket=", exit_tkt,
                      " price=", DoubleToString(exit_price, 5));
            }
            // If placement fails again, no action — retry next tick
        }
    }
}

void ProcessCloseByQueue() {
    int q_size = ArraySize(g_closeby_queue);
    if (q_size == 0) return;

    for (int i = q_size - 1; i >= 0; i--) {
        g_closeby_queue[i].retries++;

        if (g_closeby_queue[i].retries >= 10) {
            // ADR: Downgrade from SEV-1 halt to WARNING.
            // Two offsetting positions on the same instrument are delta-neutral.
            // They pose zero directional risk — LIFO exit machinery will sweep
            // them when the exit limit fills on mean reversion.
            // Halting the entire EA for a cosmetic execution inefficiency
            // is disproportionate. Log and discard the task.
            Print("WARNING: CloseBy queue exhausted after 10 retries. ",
                  "Positions are delta-neutral — LIFO exit machinery will handle. ",
                  "position=", g_closeby_queue[i].ticket1,
                  " position_by=", g_closeby_queue[i].ticket2);
            ArrayRemove(g_closeby_queue, i, 1);
            // Do NOT set g_halted = true
            continue;
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
