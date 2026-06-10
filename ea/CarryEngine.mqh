#ifndef CARRY_ENGINE_MQH
#define CARRY_ENGINE_MQH

#include "MathEngine.mqh"

string GetInstrumentSymbol(int instrument) {
    if (instrument == INSTRUMENT_EURUSD) return "EURUSD";
    if (instrument == INSTRUMENT_GBPUSD) return "GBPUSD";
    return "EURGBP";
}

void RunCarryRecalculation() {
    if (ArraySize(g_inventory) == 0) return;

    if (EnableVerboseLog)
        Print("INFO: Carry recalculation started. Layers=",
              ArraySize(g_inventory));

    for (int i = 0; i < ArraySize(g_inventory); i++) {
        double t = (double)(TimeCurrent() - g_inventory[i].entry_time)
                   / 86400.0 / 365.0;

        if (t < 1.0 / 365.0) {
            Print("INFO: Carry skip — same-day trade. Layer ", i);
            continue;
        }

        double EURUSD_fwd = g_inventory[i].entry_price_eurusd
                            * (1.0 + r_EUR * t)
                            / (1.0 + r_USD * t);
        double GBPUSD_fwd = g_inventory[i].entry_price_gbpusd
                            * (1.0 + r_GBP * t)
                            / (1.0 + r_USD * t);

        double ref_eu = g_inventory[i].entry_price_eurusd_1h;
        double ref_gb = g_inventory[i].entry_price_gbpusd_1h;

        if (ref_eu <= 0 || ref_gb <= 0) {
            Print("ERROR: Carry recalc — zero reference price. Layer ", i,
                  " Skipping.");
            continue;
        }

        double r_EU_fwd = MathLog(EURUSD_fwd / ref_eu);
        double r_GB_fwd = MathLog(GBPUSD_fwd / ref_gb);

        double usd_fwd = -(r_EU_fwd + r_GB_fwd) / 3.0;
        double eur_fwd =   r_EU_fwd + usd_fwd;
        double gbp_fwd =   r_GB_fwd + usd_fwd;

        // Dynamic spread: route through layer's weakest/strongest indices
        // Index mapping (Gemini-confirmed): 0=EUR, 1=GBP, 2=USD
        // spread = scores[weakest] - scores[strongest] (always negative
        // by construction for a valid mean-reversion dislocation)
        double scores_fwd[3];
        scores_fwd[0] = eur_fwd;
        scores_fwd[1] = gbp_fwd;
        scores_fwd[2] = usd_fwd;
        double new_spread = scores_fwd[g_inventory[i].weakest_at_entry]
                          - scores_fwd[g_inventory[i].strongest_at_entry];

        g_inventory[i].entry_spread_adjusted = new_spread;

        g_inventory[i].exit_spread_target =
            ComputeExitSpreadTarget(g_inventory[i]);

        double new_exit_price = ComputeExitPrice(g_inventory[i]);

        if (new_exit_price < 0) {
            Print("INFO: Carry recalc — exit price passivity failure. ",
                  "Layer ", i, " Retaining existing exit limits.");
            continue;
        }

        string symbol   = GetInstrumentSymbol(g_inventory[i].instrument);
        int    exit_dir = (g_inventory[i].direction == DIRECTION_BUY)
                          ? DIRECTION_SELL : DIRECTION_BUY;

        if (!IsClearOfFreezeLevel(new_exit_price, exit_dir, symbol)) {
            Print("INFO: Carry recalc — exit modify skipped, freeze level. ",
                  "Layer ", i, " Retaining existing exit limits.");
            continue;
        }

        int n_tickets = ArraySize(g_inventory[i].exit_tickets);
        for (int j = 0; j < n_tickets; j++) {
            ulong tkt = g_inventory[i].exit_tickets[j];

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
                          "ticket=", tkt, " layer=", i,
                          " retcode=", res.retcode);
                    continue;
                }
            }

            if (!ok && res.retcode != TRADE_RETCODE_NO_CHANGES) {
                Print("ERROR: Carry OrderModify failed. ",
                      "ticket=", tkt, " layer=", i,
                      " retcode=", res.retcode,
                      " Halting pod.");
                g_halted = true;
                return;
            }
        }

        g_inventory[i].exit_target = new_exit_price;

        if (EnableVerboseLog)
            Print("INFO: Carry recalc complete. Layer ", i,
                  " new_spread=", DoubleToString(new_spread, 6),
                  " new_exit=",   DoubleToString(new_exit_price, 5));
    }

    SaveInventoryState();
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
