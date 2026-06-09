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

bool CheckCircuitBreakers();
void CloseAllPositions();
void CancelAllPending();
void CancelAllPendingEntries();
string GetEntrySymbol();
int    GetEntryDirection();
double GetPendingOrderPrice(ulong ticket);

int OnInit() {
    int result = InitGlobals();
    if (result != INIT_SUCCEEDED) return result;

    LoadInventoryState();
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

void OnTick() {
    if (g_halted) return;

    if (CheckCircuitBreakers()) return;

    if (ArraySize(g_inventory) > 0)
        CheckCarryTrigger();

    datetime current_bar = iTime(_Symbol, PERIOD_M5, 0);
    bool new_bar = (current_bar != g_last_bar_time);

    if (new_bar) {
        g_last_bar_time = current_bar;

        RunSignalOnBarClose();

        if (g_signal_active && ArraySize(g_inventory) == 0) {
            if (g_pending_entry_ticket > 0) {
                // Existing limit is live — nudge logic in OnTick()
                // handles price updates. Do not place a new limit.
            } else {
                // No tracked pending limit. Pre-flight sweep: cancel
                // any ghost limits from prior reloads or missed nudges
                // before placing a fresh one. Highlander Rule:
                // there can be only one.
                CancelAllPendingEntries();

                double entry_price = ComputeEntryPrice();
                if (entry_price > 0) {
                    string symbol = GetEntrySymbol();
                    ulong  tkt    = PlaceEntryLimit(entry_price,
                                        GetEntryDirection(), symbol);
                    if (tkt > 0) {
                        g_pending_entry_ticket = tkt;
                        SaveInventoryState(); // Persist new Layer 0 ticket —
                                              // prevents reload loop where EA
                                              // cancels its own valid limit
                    }
                }
            }
        }
    }

    if (g_signal_active          &&
        ArraySize(g_inventory) == 0 &&
        g_pending_entry_ticket > 0) {

        double recomputed = ComputeEntryPrice();
        if (recomputed > 0) {
            double current_pending = GetPendingOrderPrice(
                                         g_pending_entry_ticket);
            if (current_pending > 0 &&
                MathAbs(recomputed - current_pending) > g_NudgeThreshold) {

                string symbol = GetEntrySymbol();
                int    dir    = GetEntryDirection();

                if (IsClearOfFreezeLevel(recomputed, dir, symbol) &&
                    IsPassive(recomputed, dir, symbol)) {

                    MqlTradeRequest req = {};
                    MqlTradeResult  res = {};
                    req.action = TRADE_ACTION_MODIFY;
                    req.order  = g_pending_entry_ticket;
                    req.price  = recomputed;
                    OrderSend(req, res);

                    if (res.retcode != TRADE_RETCODE_DONE &&
                        res.retcode != TRADE_RETCODE_PLACED)
                        Print("WARNING: Nudge OrderModify failed. ",
                              "retcode=", res.retcode);
                }
            }
        }
    }
}

bool CheckCircuitBreakers() {
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);

    if (equity > g_peak_equity) g_peak_equity = equity;

    if (equity < g_peak_equity * (1.0 - GlobalDrawdown)) {
        Print("CRITICAL: Global circuit breaker fired. ",
              "equity=", DoubleToString(equity, 2),
              " peak=",  DoubleToString(g_peak_equity, 2));
        CloseAllPositions();
        CancelAllPending();
        g_halted = true;
        return true;
    }

    double unrealised = AccountInfoDouble(ACCOUNT_PROFIT);
    double balance    = AccountInfoDouble(ACCOUNT_BALANCE);

    if (unrealised < -(balance * MaxPodDrawdown)) {
        Print("CRITICAL: Pod circuit breaker fired. ",
              "unrealised=", DoubleToString(unrealised, 2));
        CloseAllPositions();
        CancelAllPending();
        g_halted = true;
        return true;
    }

    return false;
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
    int cancelled = 0;
    for (int i = OrdersTotal() - 1; i >= 0; i--) {
        ulong ticket = OrderGetTicket(i);
        if (ticket == 0) continue;
        if (OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
        if (OrderGetInteger(ORDER_MAGIC) != (long)EA_MAGIC) continue;

        MqlTradeRequest req = {};
        MqlTradeResult  res = {};
        req.action = TRADE_ACTION_REMOVE;
        req.order  = ticket;

        if (!OrderSend(req, res)) {
            Print("WARNING: CancelAllPendingEntries — cancel failed. ",
                  "ticket=", ticket,
                  " retcode=", res.retcode);
        } else {
            cancelled++;
        }
    }

    g_pending_entry_ticket = 0;
    SaveInventoryState();

    Print("INFO: CancelAllPendingEntries — cancelled ", cancelled,
          " pending orders on ", _Symbol);
}

string GetEntrySymbol() {
    if (g_strongest == 0 && g_weakest == 1) return "EURGBP";
    if (g_strongest == 1 && g_weakest == 0) return "EURGBP";
    if (g_strongest == 0 && g_weakest == 2) return "EURUSD";
    if (g_strongest == 2 && g_weakest == 0) return "EURUSD";
    if (g_strongest == 1 && g_weakest == 2) return "GBPUSD";
    if (g_strongest == 2 && g_weakest == 1) return "GBPUSD";
    return _Symbol;
}

int GetEntryDirection() {
    if ((g_strongest == 0 && g_weakest == 1) ||
        (g_strongest == 0 && g_weakest == 2) ||
        (g_strongest == 1 && g_weakest == 2))
        return DIRECTION_SELL;
    return DIRECTION_BUY;
}

double GetPendingOrderPrice(ulong ticket) {
    if (OrderSelect(ticket))
        return OrderGetDouble(ORDER_PRICE_OPEN);
    return -1.0;
}
