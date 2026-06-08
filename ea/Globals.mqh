#ifndef GLOBALS_MQH
#define GLOBALS_MQH

#include "LayerStruct.mqh"

//--- Signal parameters
input int    StrengthWindow     = 12;      // M5 bars = 1 hour
input double EntryThreshold     = 0.0008;  // log-return units

//--- Exit parameters
input double ExitFraction       = 0.70;    // fraction of spread reversion to capture
input double MinFillThreshold   = 0.50;    // fraction of lot_size before next layer

//--- Layer mechanics
input int    MaxLayers          = 5;
input double BaseLotSize        = 0.01;
input double AddRatio           = 0.75;    // × H4 ATR for add_next spacing

//--- Nudging
input double NudgePips          = 0.5;     // pips; converted to points per symbol

//--- Risk controls
input double MaxPodDrawdown     = 0.02;    // 2% per pod
input double GlobalDrawdown     = 0.05;    // 5% global equity

//--- Carry adjustment (ADR-003)
input double r_USD              = 0.0533;  // SOFR annualised — update weekly
input double r_EUR              = 0.0390;  // ESTR annualised — update weekly
input double r_GBP              = 0.0520;  // SONIA annualised — update weekly
input string CarryRecalcTime    = "17:00"; // broker server time

//--- Logging
input bool   EnableVerboseLog   = true;

//--- Signal state (updated on each new M5 bar close)
double   g_r_EU_signal          = 0.0;
double   g_r_GB_signal          = 0.0;
double   g_EU_mid_12bars_ago    = 0.0;   // entry inversion anchor (live)
double   g_GB_mid_12bars_ago    = 0.0;   // entry inversion anchor (live)
int      g_strongest            = -1;    // 0=EUR, 1=GBP, 2=USD
int      g_weakest              = -1;
bool     g_signal_active        = false;
double   g_entry_spread         = 0.0;

//--- Bar tracking
datetime g_last_bar_time        = 0;

//--- Carry recalculation
datetime g_last_carry_recalc_date = 0;

//--- Pod state
bool     g_halted               = false;
double   g_peak_equity          = 0.0;
double   g_NudgeThreshold       = 0.0;   // computed at InitGlobals() from NudgePips

//--- Inventory
Layer    g_inventory[];                  // dynamic array of open layers

ulong    g_pending_entry_ticket = 0;   // ticket of pre-inventory entry limit
int      g_carry_hour           = 17;  // parsed from CarryRecalcTime in OnInit
int      g_carry_minute         = 0;   // parsed from CarryRecalcTime in OnInit

int InitGlobals() {
    g_NudgeThreshold = NudgePips
                       * SymbolInfoDouble(_Symbol, SYMBOL_POINT)
                       * 10.0;

    g_peak_equity = AccountInfoDouble(ACCOUNT_EQUITY);

    ArrayResize(g_inventory, 0);

    if (MaxLayers < 1 || MaxLayers > 10) {
        Print("ERROR: MaxLayers out of range");
        return INIT_PARAMETERS_INCORRECT;
    }
    if (BaseLotSize <= 0) {
        Print("ERROR: BaseLotSize must be positive");
        return INIT_PARAMETERS_INCORRECT;
    }
    if (ExitFraction <= 0 || ExitFraction >= 1.0) {
        Print("ERROR: ExitFraction must be between 0 and 1");
        return INIT_PARAMETERS_INCORRECT;
    }
    if (MinFillThreshold <= 0 || MinFillThreshold > 1.0) {
        Print("ERROR: MinFillThreshold must be between 0 and 1");
        return INIT_PARAMETERS_INCORRECT;
    }

    Print("FXMatrix EA initialised. NudgeThreshold=",
          g_NudgeThreshold, " points");
    return INIT_SUCCEEDED;
}

#endif // GLOBALS_MQH
