#ifndef CARRY_ENGINE_MQH
#define CARRY_ENGINE_MQH

#include "MathEngine.mqh"

string GetInstrumentSymbol(int instrument) {
    if (instrument == INSTRUMENT_EURUSD) return "EURUSD";
    if (instrument == INSTRUMENT_GBPUSD) return "GBPUSD";
    return "EURGBP";
}

void RunCarryRecalculation() {
    int total = ArraySize(g_inventory_EURUSD) +
                ArraySize(g_inventory_GBPUSD) +
                ArraySize(g_inventory_EURGBP);
    if (total == 0) return;

    if (EnableVerboseLog)
        Print("INFO: Carry recalculation started. Layers=", total);

    int instruments[3] = {INSTRUMENT_EURUSD, INSTRUMENT_GBPUSD, INSTRUMENT_EURGBP};
    for (int k = 0; k < 3; k++) {
        int inst = instruments[k];
        int inv_size = (inst == INSTRUMENT_EURUSD) ? ArraySize(g_inventory_EURUSD)
                     : (inst == INSTRUMENT_GBPUSD) ? ArraySize(g_inventory_GBPUSD)
                     : ArraySize(g_inventory_EURGBP);

        for (int i = 0; i < inv_size; i++) {
            Layer L = (inst == INSTRUMENT_EURUSD) ? g_inventory_EURUSD[i]
                    : (inst == INSTRUMENT_GBPUSD) ? g_inventory_GBPUSD[i]
                    : g_inventory_EURGBP[i];

            double t = (double)(TimeCurrent() - L.entry_time)
                       / 86400.0 / 365.0;

            if (t < 1.0 / 365.0) {
                Print("INFO: Carry skip — same-day trade. Instrument ", inst,
                      " layer ", i);
                continue;
            }

            double EURUSD_fwd = L.entry_price_eurusd
                                * (1.0 + r_EUR * t)
                                / (1.0 + r_USD * t);
            double GBPUSD_fwd = L.entry_price_gbpusd
                                * (1.0 + r_GBP * t)
                                / (1.0 + r_USD * t);

            double ref_eu = L.entry_price_eurusd_1h;
            double ref_gb = L.entry_price_gbpusd_1h;

            if (ref_eu <= 0 || ref_gb <= 0) {
                Print("ERROR: Carry recalc — zero reference price. Instrument ",
                      inst, " layer ", i, " Skipping.");
                continue;
            }

            double r_EU_fwd = MathLog(EURUSD_fwd / ref_eu);
            double r_GB_fwd = MathLog(GBPUSD_fwd / ref_gb);

            double usd_fwd = -(r_EU_fwd + r_GB_fwd) / 3.0;
            double eur_fwd =   r_EU_fwd + usd_fwd;
            double gbp_fwd =   r_GB_fwd + usd_fwd;

            double scores_fwd[3];
            scores_fwd[0] = eur_fwd;
            scores_fwd[1] = gbp_fwd;
            scores_fwd[2] = usd_fwd;
            double new_spread = scores_fwd[L.weakest_at_entry]
                              - scores_fwd[L.strongest_at_entry];

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
                    Print("ERROR: Carry OrderModify failed. ",
                          "ticket=", tkt, " instrument=", inst,
                          " layer=", i, " retcode=", res.retcode,
                          " Halting pod.");
                    g_halted = true;
                    return;
                }
            }

            L.exit_target = new_exit_price;

            if (inst == INSTRUMENT_EURUSD)      g_inventory_EURUSD[i] = L;
            else if (inst == INSTRUMENT_GBPUSD)  g_inventory_GBPUSD[i] = L;
            else                                 g_inventory_EURGBP[i] = L;

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
