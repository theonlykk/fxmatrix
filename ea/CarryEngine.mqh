#ifndef CARRY_ENGINE_MQH
#define CARRY_ENGINE_MQH

#include "MathEngine.mqh"

string GetInstrumentSymbol(int instrument) {
    if (instrument >= 0 && instrument < 3) return g_symbols[instrument];
    Print("ERROR: GetInstrumentSymbol — invalid slot ", instrument);
    return "";
}

void RunCarryRecalculation() {
    int total = ArraySize(g_inventory_0) +
                ArraySize(g_inventory_1) +
                ArraySize(g_inventory_2);
    if (total == 0) return;

    if (EnableVerboseLog)
        Print("INFO: Carry recalculation started. Layers=", total);

    for (int k = 0; k < 3; k++) {
        int inst = k;   // slot index: 0=PairAC, 1=PairBC, 2=PairAB
        int inv_size = (inst == 0) ? ArraySize(g_inventory_0)
                     : (inst == 1) ? ArraySize(g_inventory_1)
                     : ArraySize(g_inventory_2);

        for (int i = 0; i < inv_size; i++) {
            Layer L = (inst == 0) ? g_inventory_0[i]
                    : (inst == 1) ? g_inventory_1[i]
                    : g_inventory_2[i];

            double t = (double)(TimeCurrent() - L.entry_time)
                       / 86400.0 / 365.0;

            if (t < 1.0 / 365.0) {
                Print("INFO: Carry skip — same-day trade. Instrument ", inst,
                      " layer ", i);
                continue;
            }

            // V3 generic carry forward — PairAC and PairBC only (slot 0 and 1)
            // RateA = rate for CurrencyA, RateB = rate for CurrencyB,
            // RateC = rate for CurrencyC (base denominator in both pairs)
            double PairAC_fwd = L.entry_price_AC
                                * (1.0 + RateA * t)
                                / (1.0 + RateC * t);
            double PairBC_fwd = L.entry_price_BC
                                * (1.0 + RateB * t)
                                / (1.0 + RateC * t);

            double ref_AC = L.entry_price_AC_1h;
            double ref_BC = L.entry_price_BC_1h;

            if (ref_AC <= 0 || ref_BC <= 0) {
                Print("ERROR: Carry recalc — zero reference price. Instrument ",
                      inst, " layer ", i, " Skipping.");
                continue;
            }

            double r_AC_fwd = MathLog(PairAC_fwd / ref_AC);
            double r_BC_fwd = MathLog(PairBC_fwd / ref_BC);

            // V3 generic score decomposition — zero-sum constraint
            double score_C_fwd = -(r_AC_fwd + r_BC_fwd) / 3.0;
            double score_A_fwd =   r_AC_fwd + score_C_fwd;
            double score_B_fwd =   r_BC_fwd + score_C_fwd;

            double scores_fwd[3];
            scores_fwd[0] = score_A_fwd;
            scores_fwd[1] = score_B_fwd;
            scores_fwd[2] = score_C_fwd;
            double new_spread = scores_fwd[L.weakest_at_entry]
                              - scores_fwd[L.strongest_at_entry];

            // O2 guard: entry_spread_adjusted must remain negative.
            // If carry fully offsets the dislocation (new_spread >= 0),
            // the geometric routing assumptions break — exit limit would
            // move to the wrong side of the market. Skip carry update and
            // hold the current adjusted spread (locks exit deep in profit).
            if (new_spread >= 0.0) {
                Print("WARNING: Carry flipped entry_spread_adjusted sign. ",
                      "Skipping carry update. layer=", i,
                      " new_spread=", DoubleToString(new_spread, 6));
                continue;
            }
            L.entry_spread_adjusted = new_spread;
            L.exit_spread_target = ComputeExitSpreadTarget(L);

            double new_exit_price = ComputeExitPrice(L);

            if (new_exit_price < 0) {
                Print("INFO: Carry recalc — exit price passivity failure. ",
                      "Instrument ", inst, " layer ", i,
                      " Retaining existing exit limits.");
                continue;
            }

            string symbol   = GetInstrumentSymbol(L.instrument);
            int    exit_dir = (L.direction == DIRECTION_BUY)
                              ? DIRECTION_SELL : DIRECTION_BUY;

            if (!IsClearOfFreezeLevel(new_exit_price, exit_dir, symbol)) {
                Print("INFO: Carry recalc — exit modify skipped, freeze level. ",
                      "Instrument ", inst, " layer ", i,
                      " Retaining existing exit limits.");
                continue;
            }

            // F5 fix: check stops level before OrderModify.
            // During rollover, spreads blow out and stops distances expand.
            // A stops-level reject triggers a bare halt — catastrophic per F1.
            // Skip gracefully instead of halting.
            double stops_pts = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL)
                               * SymbolInfoDouble(symbol, SYMBOL_POINT);
            double ask        = SymbolInfoDouble(symbol, SYMBOL_ASK);
            double bid        = SymbolInfoDouble(symbol, SYMBOL_BID);
            double ref_price  = (exit_dir == DIRECTION_BUY) ? ask : bid;
            if (MathAbs(new_exit_price - ref_price) < stops_pts) {
                if (EnableVerboseLog)
                    Print("INFO: Carry OrderModify skipped — stops level. ",
                          "symbol=", symbol,
                          " new_exit=", DoubleToString(new_exit_price, 5),
                          " stops_pts=", DoubleToString(stops_pts, 5));
                continue;
            }

            int n_tickets = ArraySize(L.exit_tickets);
            for (int j = 0; j < n_tickets; j++) {
                ulong tkt = L.exit_tickets[j];

                if (!OrderSelect(tkt)) {
                    Print("INFO: Carry Engine skip — ticket ", tkt,
                          " missing from order book.");
                    continue;
                }

                MqlTradeRequest req = {};
                MqlTradeResult  res = {};
                req.action = TRADE_ACTION_MODIFY;
                req.order  = tkt;
                req.price  = new_exit_price;

                bool ok = OrderSend(req, res);

                if (!ok && res.retcode == TRADE_RETCODE_TOO_MANY_REQUESTS) {
                    Sleep(100);
                    ok = OrderSend(req, res);
                    if (!ok) {
                        Print("WARNING: Carry OrderModify throttled. ",
                              "ticket=", tkt, " instrument=", inst,
                              " layer=", i, " retcode=", res.retcode);
                        continue;
                    }
                }

                if (!ok && res.retcode != TRADE_RETCODE_NO_CHANGES) {
                    Print("WARNING: Carry OrderModify failed. ",
                          "symbol=", symbol,
                          " retcode=", res.retcode,
                          " — skipping carry update, old exit retained.");
                    continue;
                }
            }

            L.exit_target = new_exit_price;

            if (inst == 0)      g_inventory_0[i] = L;
            else if (inst == 1) g_inventory_1[i] = L;
            else                g_inventory_2[i] = L;

            if (EnableVerboseLog)
                Print("INFO: Carry recalc complete. Instrument ", inst,
                      " layer ", i,
                      " new_spread=", DoubleToString(new_spread, 6),
                      " new_exit=",   DoubleToString(new_exit_price, 5));
        }
    }

    SaveAllInventoryState();
    Print("INFO: Carry recalculation finished.");
}

void CheckCarryTrigger() {
    datetime    now = TimeCurrent();
    MqlDateTime now_dt, last_dt;
    TimeToStruct(now, now_dt);
    TimeToStruct(g_last_carry_recalc_date, last_dt);

    if (now_dt.hour != g_carry_hour ||
        now_dt.min  != g_carry_minute) return;

    if (now_dt.day  == last_dt.day  &&
        now_dt.mon  == last_dt.mon  &&
        now_dt.year == last_dt.year) return;

    RunCarryRecalculation();
    g_last_carry_recalc_date = now;
}

#endif // CARRY_ENGINE_MQH
