# Cursor Implementation Prompt 4 of 4
# Scope: Carry Recalculation + OnTick Orchestration + Circuit Breakers
# Reference: ADR-002 v4 Section 8, ADR-003 v2 Section 3

This message has a line count at the bottom.
Read this entire prompt before writing a single line of code.
Do not begin implementation until you have read all sections.

---

## Context

You are implementing the final module of a native MQL5 Expert
Advisor for a 3-currency FX mean-reversion pod (EUR, GBP, USD)
on an FTMO MT5 hedging account. This is Prompt 4 of 4.

Files already locked (do not modify):
- d:\fxmatrix\ea\LayerStruct.mqh
- d:\fxmatrix\ea\Globals.mqh
- d:\fxmatrix\ea\MathEngine.mqh
- d:\fxmatrix\ea\ExecutionEngine.mqh

Full specification:
- d:\fxmatrix\adrs\ADR-002-matrix-driven-exits-v4.md
- d:\fxmatrix\adrs\ADR-003-carry-adjustment-v2.md

If anything in this prompt conflicts with the ADRs,
the ADRs take precedence.

---

## Deliverable

Two files:

1. `d:\fxmatrix\ea\CarryEngine.mqh`
   Daily carry recalculation logic per ADR-003 v2 Section 3.

2. `d:\fxmatrix\ea\FXMatrix.mq5`
   The main EA entry point. Includes all four .mqh files.
   Contains OnTick(), OnInit() (finalised), and OnDeinit().
   Does NOT duplicate OnInit() from Globals.mqh — calls it.

---

## Critical Constraints — Read Before Coding

1. **Broker server time only.** Never use TimeLocal().
   Always use TimeCurrent() for all timestamps.

2. **Exit limits are NOT nudged intra-bar.**
   OnTick() nudges ONLY the first entry limit (pre-inventory).
   Exit limits are updated ONLY by CarryEngine. Never both.

3. **OrderModify() only.** No cancel-and-replace anywhere.

4. **Date guard on carry recalculation.**
   g_last_carry_recalc_date prevents double-firing on EA restart.

5. **Retry loop on TRADE_RETCODE_TOO_MANY_REQUESTS.**
   Sleep(100) and retry once. Log WARNING on persistent failure.
   Log ERROR and halt pod on any other OrderModify error.

6. **InitGlobals() pattern — no OnInit() in Globals.mqh.**
   Globals.mqh must NOT define OnInit(). Rename the existing
   OnInit() in Globals.mqh to InitGlobals(). FXMatrix.mq5
   defines the single authoritative OnInit() which calls
   InitGlobals() plus any additional startup tasks (ATR handle
   initialisation, carry hour/minute parsing). This prevents
   MQL5 compiler duplicate definition errors.

---

## File 1: CarryEngine.mqh

### GetInstrumentSymbol() helper

```mql5
string GetInstrumentSymbol(int instrument) {
    if (instrument == INSTRUMENT_EURUSD) return "EURUSD";
    if (instrument == INSTRUMENT_GBPUSD) return "GBPUSD";
    return "EURGBP";
}
```

### RunCarryRecalculation()

Called once per day when broker server time crosses CarryRecalcTime.
Implements ADR-003 v2 Section 3.2 Steps 1–9 for every open layer.

```mql5
void RunCarryRecalculation() {

    if (EnableVerboseLog)
        Print("INFO: Carry recalculation started. Layers=",
              ArraySize(g_inventory));

    for (int i = 0; i < ArraySize(g_inventory); i++) {

        // Step 1: Holding period in years
        double t = (double)(TimeCurrent() - g_inventory[i].entry_time)
                   / 86400.0 / 365.0;

        // Same-day exemption
        if (t < 1.0 / 365.0) {
            Print("INFO: Carry skip — same-day trade. Layer ", i);
            continue;
        }

        // Step 2: Forward prices for USD legs
        double EURUSD_fwd = g_inventory[i].entry_price_eurusd
                            * (1.0 + r_EUR * t)
                            / (1.0 + r_USD * t);
        double GBPUSD_fwd = g_inventory[i].entry_price_gbpusd
                            * (1.0 + r_GBP * t)
                            / (1.0 + r_USD * t);

        // Step 3: Log returns relative to entry-time 1h-prior
        double ref_eu = g_inventory[i].entry_price_eurusd_1h;
        double ref_gb = g_inventory[i].entry_price_gbpusd_1h;

        if (ref_eu <= 0 || ref_gb <= 0) {
            Print("ERROR: Carry recalc — zero reference price. Layer ", i,
                  " Skipping.");
            continue;
        }

        double r_EU_fwd = MathLog(EURUSD_fwd / ref_eu);
        double r_GB_fwd = MathLog(GBPUSD_fwd / ref_gb);

        // Matrix solution on forward-adjusted returns
        double usd_fwd = -(r_EU_fwd + r_GB_fwd) / 3.0;
        double eur_fwd =   r_EU_fwd + usd_fwd;
        double gbp_fwd =   r_GB_fwd + usd_fwd;

        // Step 4: New carry-adjusted spread
        double new_spread = gbp_fwd - eur_fwd;

        // Step 5: Update entry_spread_adjusted
        g_inventory[i].entry_spread_adjusted = new_spread;

        // Step 6: Recompute exit_spread_target
        g_inventory[i].exit_spread_target =
            ComputeExitSpreadTarget(g_inventory[i]);

        // Step 7: Recompute exit price using entry-time anchor
        // ComputeExitPrice() uses layer.EU_mid_12bars_ago_at_entry,
        // layer.GB_mid_12bars_ago_at_entry, layer.r_EU_at_entry,
        // layer.r_GB_at_entry, layer.strongest_at_entry,
        // layer.weakest_at_entry — all immutable.
        double new_exit_price = ComputeExitPrice(g_inventory[i]);

        if (new_exit_price < 0) {
            Print("INFO: Carry recalc — exit price passivity failure. ",
                  "Layer ", i, " Retaining existing exit limits.");
            continue;
        }

        // Step 8: Freeze level check on new exit price
        string symbol    = GetInstrumentSymbol(g_inventory[i].instrument);
        int    exit_dir  = (g_inventory[i].direction == DIRECTION_BUY)
                           ? DIRECTION_SELL : DIRECTION_BUY;

        if (!IsClearOfFreezeLevel(new_exit_price, exit_dir, symbol)) {
            Print("INFO: Carry recalc — exit modify skipped, freeze level. ",
                  "Layer ", i, " Retaining existing exit limits.");
            continue;
        }

        // Step 9: OrderModify all exit tickets for this layer
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
                    continue;  // leave this ticket at old price
                }
            }

            if (!ok) {
                Print("ERROR: Carry OrderModify failed. ",
                      "ticket=", tkt, " layer=", i,
                      " retcode=", res.retcode,
                      " Halting pod.");
                g_halted = true;
                return;
            }
        }

        // Update struct exit_target to new price
        g_inventory[i].exit_target = new_exit_price;

        if (EnableVerboseLog)
            Print("INFO: Carry recalc complete. Layer ", i,
                  " new_spread=", DoubleToString(new_spread, 6),
                  " new_exit=",   DoubleToString(new_exit_price, 5));
    }

    Print("INFO: Carry recalculation finished.");
}
```

### CheckCarryTrigger()

Called from OnTick(). Fires RunCarryRecalculation() once per day
when broker server time matches g_carry_hour and g_carry_minute.
Date guard prevents double-firing on EA restart.

g_carry_hour and g_carry_minute are parsed from CarryRecalcTime
input string ("HH:MM") once in OnInit() in FXMatrix.mq5.
Add to Globals.mqh:
```mql5
int g_carry_hour   = 17;   // parsed from CarryRecalcTime in OnInit
int g_carry_minute = 0;    // parsed from CarryRecalcTime in OnInit
```

```mql5
void CheckCarryTrigger() {

    datetime    now = TimeCurrent();
    MqlDateTime now_dt, last_dt;
    TimeToStruct(now,                      now_dt);
    TimeToStruct(g_last_carry_recalc_date, last_dt);

    // Time check: use integer comparison, not string matching
    if (now_dt.hour != g_carry_hour ||
        now_dt.min  != g_carry_minute) return;

    // Date guard: only fire once per calendar day
    if (now_dt.day  == last_dt.day  &&
        now_dt.mon  == last_dt.mon  &&
        now_dt.year == last_dt.year) return;

    // Fire recalculation
    RunCarryRecalculation();
    g_last_carry_recalc_date = now;
}
```

---

## File 2: FXMatrix.mq5

The main EA entry point. Ties all modules together.

### Header and includes

```mql5
//+------------------------------------------------------------------+
//| FXMatrix.mq5                                                     |
//| 3-Currency FX Mean Reversion Pod — EUR/GBP/USD                   |
//| FTMO MT5 Hedging Account                                         |
//+------------------------------------------------------------------+
#property copyright "fxmatrix"
#property version   "1.00"
#property strict

#include "Globals.mqh"          // inputs, globals, OnInit()
#include "LayerStruct.mqh"      // Layer struct, enums, InitLayer()
#include "MathEngine.mqh"       // signal, inversion, IsPassive()
#include "ExecutionEngine.mqh"  // OnTradeTransaction, order placement
#include "CarryEngine.mqh"      // carry recalculation
```

### OnTick()

```mql5
void OnTick() {

    // Pod halted — do nothing
    if (g_halted) return;

    // Step 1: Circuit breakers
    if (CheckCircuitBreakers()) return;

    // Step 2: Carry recalculation trigger (once per day at 17:00)
    if (ArraySize(g_inventory) > 0)
        CheckCarryTrigger();

    // Step 3: New M5 bar detection
    datetime current_bar = iTime(_Symbol, PERIOD_M5, 0);
    bool new_bar = (current_bar != g_last_bar_time);

    if (new_bar) {
        g_last_bar_time = current_bar;

        // Run signal computation on bar close
        RunSignalOnBarClose();

        // If signal active and no open inventory:
        // compute and place first entry limit
        if (g_signal_active && ArraySize(g_inventory) == 0) {
            double entry_price = ComputeEntryPrice();
            if (entry_price > 0) {
                string symbol = GetEntrySymbol();
                ulong  tkt    = PlaceEntryLimit(entry_price,
                                    GetEntryDirection(), symbol);
                if (tkt > 0)
                    g_pending_entry_ticket = tkt;
            }
        }
    }

    // Step 4: Nudge first entry limit (pre-inventory only)
    // Exit limits are NOT nudged — ADR-002 v4 Section 8.1
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
```

### Circuit breakers

```mql5
// Returns true if a circuit breaker fired (caller should return).
bool CheckCircuitBreakers() {

    double equity = AccountInfoDouble(ACCOUNT_EQUITY);

    // Update peak equity
    if (equity > g_peak_equity) g_peak_equity = equity;

    // Global circuit breaker: 5% equity drawdown from peak
    if (equity < g_peak_equity * (1.0 - GlobalDrawdown)) {
        Print("CRITICAL: Global circuit breaker fired. ",
              "equity=", DoubleToString(equity, 2),
              " peak=",  DoubleToString(g_peak_equity, 2));
        CloseAllPositions();
        CancelAllPending();
        g_halted = true;
        return true;
    }

    // Per-pod circuit breaker: unrealised loss > MaxPodDrawdown
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
```

### CloseAllPositions() and CancelAllPending()

```mql5
void CloseAllPositions() {
    for (int i = PositionsTotal() - 1; i >= 0; i--) {
        ulong ticket = PositionGetTicket(i);
        if (ticket == 0) continue;

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

        MqlTradeRequest req = {};
        MqlTradeResult  res = {};
        req.action = TRADE_ACTION_REMOVE;
        req.order  = ticket;

        if (!OrderSend(req, res))
            Print("ERROR: CancelAllPending failed. ticket=", ticket,
                  " retcode=", res.retcode);
    }
}
```

### Helper functions for OnTick()

```mql5
// Returns the entry symbol based on current signal routing
string GetEntrySymbol() {
    if (g_strongest == 0 && g_weakest == 1) return "EURGBP";
    if (g_strongest == 1 && g_weakest == 0) return "EURGBP";
    if (g_strongest == 0 && g_weakest == 2) return "EURUSD";
    if (g_strongest == 2 && g_weakest == 0) return "EURUSD";
    if (g_strongest == 1 && g_weakest == 2) return "GBPUSD";
    if (g_strongest == 2 && g_weakest == 1) return "GBPUSD";
    return _Symbol;
}

// Returns the entry direction based on current signal routing
int GetEntryDirection() {
    // Sell the strongest/weakest cross if strongest index > weakest
    // Full routing per ADR-002 v4 Section 5:
    // S=EUR(0),W=GBP(1) → SELL; S=GBP(1),W=EUR(0) → BUY
    // S=EUR(0),W=USD(2) → SELL; S=USD(2),W=EUR(0) → BUY
    // S=GBP(1),W=USD(2) → SELL; S=USD(2),W=GBP(1) → BUY
    if ((g_strongest == 0 && g_weakest == 1) ||
        (g_strongest == 0 && g_weakest == 2) ||
        (g_strongest == 1 && g_weakest == 2))
        return DIRECTION_SELL;
    return DIRECTION_BUY;
}

// Returns the current price of a pending order by ticket.
// Returns -1 if not found.
double GetPendingOrderPrice(ulong ticket) {
    if (OrderSelect(ticket))
        return OrderGetDouble(ORDER_PRICE_OPEN);
    return -1.0;
}
```

### Globals.mqh additions required

Three additions to Globals.mqh. Do not modify anything else:

```mql5
ulong    g_pending_entry_ticket = 0;   // ticket of pre-inventory entry limit
int      g_carry_hour           = 17;  // parsed from CarryRecalcTime in OnInit
int      g_carry_minute         = 0;   // parsed from CarryRecalcTime in OnInit
```

Additionally, rename OnInit() in Globals.mqh to InitGlobals().
The function signature and body are unchanged — only the name changes.
Return type remains int. FXMatrix.mq5 calls InitGlobals() from
its own OnInit().

### OnInit() in FXMatrix.mq5

```mql5
int OnInit() {

    // Initialise all globals (renamed from OnInit in Globals.mqh)
    int result = InitGlobals();
    if (result != INIT_SUCCEEDED) return result;

    // Parse CarryRecalcTime string "HH:MM" into integers
    // Prevents fragile string matching in CheckCarryTrigger()
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
```

### OnDeinit()

```mql5
void OnDeinit(const int reason) {
    Print("INFO: FXMatrix EA deinitialised. Reason=", reason);
    // Do not close positions on deinit — let existing orders stand.
    // Circuit breakers handle emergency closes during operation.
}
```

---

## Negative Space — What You Must NOT Do

- Do NOT modify LayerStruct.mqh, Globals.mqh, MathEngine.mqh,
  or ExecutionEngine.mqh
- Do NOT define OnInit() in Globals.mqh — it must be renamed
  InitGlobals(). OnInit() lives exclusively in FXMatrix.mq5
- Do NOT nudge exit limits in OnTick() — exit limits are updated
  exclusively by CarryEngine
- Do NOT use cancel-and-replace anywhere — OrderModify() only
- Do NOT use TimeLocal() — TimeCurrent() only
- Do NOT implement volatility-scaled carry — V2
- Do NOT implement dynamic rate fetching — V2
- Do NOT implement weekend swap handling — V2
- Do NOT implement multi-timeframe confluence — V2
- Do NOT add a 4th currency to the pod — V2
- Do NOT implement cross-pod correlation — V2
- Do NOT close positions on OnDeinit — circuit breakers only
- Do NOT use market orders for entry — passive limits only

---

## Self-Review Instructions

Before submitting your response:
1. Confirm CarryEngine.mqh implements all 9 steps of ADR-003
   v2 Section 3.2 in order.
2. Confirm RunCarryRecalculation() uses layer.EU_mid_12bars_ago_at_entry
   and layer.GB_mid_12bars_ago_at_entry (via ComputeExitPrice())
   — NOT live g_EU_mid_12bars_ago.
3. Confirm CheckCarryTrigger() uses MqlDateTime struct comparison
   for date guard — not just timestamp subtraction.
4. Confirm OnTick() nudges ONLY g_pending_entry_ticket (pre-
   inventory). Confirm zero references to exit limit nudging.
5. Confirm CheckCircuitBreakers() updates g_peak_equity on every
   tick before checking drawdown.
6. Confirm CloseAllPositions() uses TRADE_ACTION_DEAL with
   IOC filling and correct bid/ask for direction.
7. Confirm CancelAllPending() iterates OrdersTotal() in reverse.
8. Confirm GetEntryDirection() covers all six routing cases
   explicitly — no index arithmetic.
9. Confirm FXMatrix.mq5 includes all five files in the correct
   dependency order (Globals first, LayerStruct second).
10. Confirm g_pending_entry_ticket is added to Globals.mqh and
    initialised to 0 in OnInit().
11. Flag any assumptions, ambiguities, or constraint violations.

---

## Output Format

Respond with:
1. Complete contents of CarryEngine.mqh
2. Complete contents of FXMatrix.mq5
3. The single line to add to Globals.mqh
4. Self-review confirming each of the 11 checks above
5. Any flagged assumptions or concerns

Do not summarise. Do not explain the strategy. Write the files.

Line count: 322
