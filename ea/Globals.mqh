#ifndef GLOBALS_MQH
#define GLOBALS_MQH

#include "LayerStruct.mqh"

//--- Signal parameters
input int    StrengthWindow     = 12;      // M5 bars = 1 hour
input double BaseThreshold      = 0.0004;  // Layer 0 entry threshold
input double ThresholdStep      = 0.0002;  // per-layer threshold increment
input double GridBase           = 0.0008;  // grid interval between layers (8bps default)
input int    GridMode           = 0;       // 0=constant 1=linear 2=hybrid
input double GridLinearStep     = 0.0002;  // interval increment per layer (linear/hybrid)
input int    GridInflection     = 2;       // layer where linear switches to exponential
input double GridExpBase        = 1.500;   // exponential multiplier (hybrid mode)
input int    SkewMode           = 0;       // 0=constant 1=linear decrease
input double SkewStart          = 0.618;   // starting capture fraction (Fibonacci golden ratio)
input double SkewStep           = 0.000;   // reduction per layer (0=disabled)
input double SkewMin            = 0.050;   // floor — avoids locking in transaction cost losses
input double RotationThreshold  = 0.0002;  // min edge to rotate signal

//--- Phase 3: drawdown-responsive stress parameters
input double LayerStressBase         = 1.500;  // exponential layer stress multiplier
input double K_spread                = 1.000;  // PnL stress multiplier aggressiveness
input double K_size                  = 0.500;  // lot size reduction aggressiveness
input int    MinLayerIntervalSeconds = 300;    // min seconds between layer adds (1 M5 bar)

//--- Layer fill
input double MinFillThreshold   = 0.50;    // fraction of lot_size before next layer

//--- Layer mechanics
input int    MaxLayers          = 20;
input double BaseLotSize        = 0.01;
input ulong   EA_MAGIC    = 20260000; // ADR-021: Instance base magic (MM=20260000, SNIPER=20260100)

//--- Nudging
input double NudgePips          = 0.5;     // pips; converted to points per symbol

//--- Risk controls
input double MaxPodDrawdown     = 0.02;    // 2% per pod
input double GlobalDrawdown     = 0.045;   // 4.5% global — front-runs FTMO 5% daily limit

//--- Carry adjustment (ADR-003)
input double r_USD              = 0.0533;  // SOFR annualised — update weekly
input double r_EUR              = 0.0390;  // ESTR annualised — update weekly
input double r_GBP              = 0.0520;  // SONIA annualised — update weekly
input string CarryRecalcTime    = "17:00"; // broker server time

enum ENUM_EXECUTION_MODE { MARKET_MAKER, SNIPER };
input ENUM_EXECUTION_MODE ExecutionMode = MARKET_MAKER;
input string  InstanceID  = "MM";     // ADR-021: Instance identifier for JSON state segregation
input double SniperThreshold = 0.0008; // ADR-019: Decoupled entry gate for SNIPER mode

//--- Pipshed Telemetry
input string TelemetryURL         = "https://pipshed.theonlykhalid.com/api/telemetry/push";
input string TelemetryAPIKey      = "";
input int    TelemetryIntervalSec = 60;
input bool   EnableTelemetry      = true;

//--- Logging
input bool   EnableVerboseLog   = true;

//--- Phase 4: LDAK correlation penalty
input double LDAK_Dilation_Max = 3.000; // LDAK: max grid dilation multiplier

//--- Phase 5: FTMO equity failsafe
input double FTMO_Initial_Balance = 10000.000; // FTMO starting account balance
input double FTMO_Max_Loss_Pct    = 0.090;     // absolute loss buffer (9% — 1% below 10% limit)
input double FTMO_Daily_Loss_Pct  = 0.040;     // daily loss buffer (4% — 1% below 5% limit)

//--- ADR-017: Market making execution spread
input double QuoteSpread = 0.0008; // execution distance from FairValue to quote (8 bps default)

//--- Signal state (updated on each new M5 bar close)
double   g_r_EU_signal          = 0.0;
double   g_r_GB_signal          = 0.0;
double   g_EU_mid_12bars_ago    = 0.0;   // entry inversion anchor (live)
double   g_GB_mid_12bars_ago    = 0.0;   // entry inversion anchor (live)
int      g_strongest            = -1;    // 0=EUR, 1=GBP, 2=USD
int      g_weakest              = -1;
bool     g_signal_active        = false;
double   g_entry_spread         = 0.0;
double   g_score_eur            = 0.0;
double   g_score_gbp            = 0.0;
double   g_score_usd            = 0.0;

// LDAK pairwise correlation globals (signed Pearson r, updated on bar close)
double g_r_EU_GU = 0.0; // EURUSD vs GBPUSD
double g_r_EU_EG = 0.0; // EURUSD vs EURGBP
double g_r_GU_EG = 0.0; // GBPUSD vs EURGBP

// LDAK volatility ratio globals (sigma_24 / sigma_288, updated on bar close)
double g_vratio_EU = 1.0; // EURUSD volatility ratio
double g_vratio_GU = 1.0; // GBPUSD volatility ratio
double g_vratio_EG = 1.0; // EURGBP volatility ratio

//--- Bar tracking
datetime g_last_bar_time        = 0;

//--- Carry recalculation
datetime g_last_carry_recalc_date = 0;

//--- Pod state
bool     g_halted               = false;
double   g_peak_equity          = 0.0;
double   g_daily_start_balance  = 0.0; // balance at midnight CET rollover
int      g_current_day          = -1;  // tracks day for midnight reset
double   g_NudgeThreshold       = 0.0;   // computed at InitGlobals() from NudgePips

//--- Shared queue
CloseByTask  g_closeby_queue[];          // pending CloseBy retry tasks

Layer        g_inventory_EURUSD[];
Layer        g_inventory_GBPUSD[];
Layer        g_inventory_EURGBP[];

// ADR-014: two-sided quote tracking (bid + offer per instrument)
ulong    g_pending_bid_EURUSD   = 0;  // bid-side: initial quote or add-next
ulong    g_pending_offer_EURUSD = 0;  // offer-side: initial quote (cancelled on Layer 0 fill)
ulong    g_pending_bid_GBPUSD   = 0;
ulong    g_pending_offer_GBPUSD = 0;
ulong    g_pending_bid_EURGBP   = 0;
ulong    g_pending_offer_EURGBP = 0;

ulong    g_add_next_EURUSD = 0;
ulong    g_add_next_GBPUSD = 0;
ulong    g_add_next_EURGBP = 0;

//--- Per-instrument last layer fill timestamps (Phase 3 sleep interval)
datetime g_last_layer_time_EURUSD = 0;
datetime g_last_layer_time_GBPUSD = 0;
datetime g_last_layer_time_EURGBP = 0;
int      g_carry_hour           = 17;  // parsed from CarryRecalcTime in OnInit
int      g_carry_minute         = 0;   // parsed from CarryRecalcTime in OnInit

//--- ADR-017: Hard API request counter
int  g_daily_api_count = 0;    // resets at broker midnight with g_daily_start_balance
bool g_api_halt        = false; // true when g_daily_api_count >= 1800

int InitGlobals() {
    g_NudgeThreshold = NudgePips
                       * SymbolInfoDouble(_Symbol, SYMBOL_POINT)
                       * 10.0;

    g_peak_equity = AccountInfoDouble(ACCOUNT_EQUITY);

    ArrayResize(g_inventory_EURUSD, 0);
    ArrayResize(g_inventory_GBPUSD, 0);
    ArrayResize(g_inventory_EURGBP, 0);

    g_last_layer_time_EURUSD = 0;
    g_last_layer_time_GBPUSD = 0;
    g_last_layer_time_EURGBP = 0;

    if (MaxLayers < 1 || MaxLayers > 20) {
        Print("ERROR: MaxLayers out of range");
        return INIT_PARAMETERS_INCORRECT;
    }
    if (BaseLotSize <= 0) {
        Print("ERROR: BaseLotSize must be positive");
        return INIT_PARAMETERS_INCORRECT;
    }
    if (SkewStart <= 0.0 || SkewStart >= 1.0) {
        Print("ERROR: SkewStart must be between 0 and 1");
        return INIT_PARAMETERS_INCORRECT;
    }
    if (SkewMin <= 0.0) {
        Print("FATAL: SkewMin must be > 0.0");
        return INIT_PARAMETERS_INCORRECT;
    }
    if (GridBase <= 0.0) {
        Print("FATAL: GridBase must be > 0.0");
        return INIT_PARAMETERS_INCORRECT;
    }
    if (GridExpBase <= 1.0 && GridMode == 2) {
        Print("FATAL: GridExpBase must be > 1.0 in hybrid mode");
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
