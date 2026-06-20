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

            // F6: count actual 00:00 server time rollovers, not 24h fractions.
            // MT5 charges swap strictly at midnight server time (17:00 ET).
            // A 10-min hold crossing midnight costs 1 full day of swap.
            datetime now        = TimeCurrent();
            int      days_held  = 0;

            // Align to 00:00 of entry day
            MqlDateTime entry_dt;
            TimeToStruct(L.entry_time, entry_dt);
            entry_dt.hour = 0; entry_dt.min = 0; entry_dt.sec = 0;
            datetime cursor_midnight = StructToTime(entry_dt);

            // First rollover occurs at midnight following entry
            datetime rollover_time = cursor_midnight + 86400;

            while (rollover_time <= now) {
                MqlDateTime r_dt;
                TimeToStruct(rollover_time, r_dt);
                // Skip Saturday (6) and Sunday (0) server midnights — no swap
                // Triple swap triggered at Thursday 00:00 (Wednesday 17:00 ET)
                if (r_dt.day_of_week != 0 && r_dt.day_of_week != 6) {
                    days_held += (r_dt.day_of_week == 4) ? 3 : 1;
                }
                rollover_time += 86400;
            }

            if (days_held == 0) {
                if (EnableVerboseLog)
                    Print("INFO: Carry skip — no 00:00 rollover crossed yet. ",
                          "slot=", inst, " layer=", i);
                continue;
            }

            // F6: live swap accumulation — replaces static CIP formula.
            // Broker swap already encapsulates interbank rate + markup.
            // Negative swap = position bleeds per day = exit must move
            // further in our favour to break even.
            string sym_AC = g_symbols[SLOT_AC];
            string sym_BC = g_symbols[SLOT_BC];

            double ref_AC = L.entry_price_AC_1h;
            double ref_BC = L.entry_price_BC_1h;

            if (ref_AC <= 0.0 || ref_BC <= 0.0) {
                Print("ERROR: Carry recalc — zero reference price. slot=", inst,
                      " layer=", i, " Skipping.");
                continue;
            }

            double pt_AC = SymbolInfoDouble(sym_AC, SYMBOL_POINT);
            double pt_BC = SymbolInfoDouble(sym_BC, SYMBOL_POINT);
            if (pt_AC <= 0.0 || pt_BC <= 0.0) continue;

            // Poll live swap in points, convert to price delta
            // Direction: if layer is BUY on PairAC, pay SWAP_LONG for PairAC
            // Negative swap means position bleeds — price must rise more to cover
            double swap_AC_pts = (L.direction == DIRECTION_BUY)
                ? SymbolInfoDouble(sym_AC, SYMBOL_SWAP_LONG)
                : SymbolInfoDouble(sym_AC, SYMBOL_SWAP_SHORT);
            double swap_BC_pts = (L.direction == DIRECTION_BUY)
                ? SymbolInfoDouble(sym_BC, SYMBOL_SWAP_LONG)
                : SymbolInfoDouble(sym_BC, SYMBOL_SWAP_SHORT);

            // Accumulate swap over days_held rollovers
            double swap_AC_price = swap_AC_pts * pt_AC * days_held;
            double swap_BC_price = swap_BC_pts * pt_BC * days_held;

            // Forward price = entry price adjusted by accumulated swap
            // Negative swap reduces forward (need more move to break even)
            double PairAC_fwd = L.entry_price_AC + swap_AC_price;
            double PairBC_fwd = L.entry_price_BC + swap_BC_price;

            if (PairAC_fwd <= 0.0 || PairBC_fwd <= 0.0) {
                Print("ERROR: Carry recalc — invalid forward price. slot=", inst,
                      " layer=", i, " Skipping.");
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
