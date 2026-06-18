#ifndef GLOBALS_MQH
#define GLOBALS_MQH

#include "LayerStruct.mqh"

//--- Signal parameters
input int    StrengthWindow     = 12;      // M5 bars = 1 hour
input double BaseThreshold      = 0.0004;  // Layer 0 entry threshold
input double ThresholdStep      = 0.0002;  // per-layer threshold increment
input double GridBase           = 0.0008;  // grid interval between layers (8bps default)
input int    GridMode           = 2;       // 0=constant 1=linear 2=hybrid
input double GridLinearStep     = 0.0002;  // interval increment per layer (linear/hybrid)
input int    GridInflection     = 2;       // layer where linear switches to exponential
input double GridExpBase        = 1.500;   // exponential multiplier (hybrid mode)
input int    SkewMode           = 0;       // 0=constant 1=linear decrease
input double SkewStart          = 0.618;   // starting capture fraction (Fibonacci golden ratio)
input double SkewStep           = 0.000;   // reduction per layer (0=disabled)
input double SkewMin            = 0.050;   // floor — avoids locking in transaction cost losses
input double RotationThreshold  = 0.0002;  // min edge to rotate signal

//--- Phase 3: drawdown-responsive stress parameters
input double LayerStressBase         = 1.0;  // exponential layer stress multiplier
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
input double MaxPodDrawdown     = 0.03;    // 2% per pod
input double GlobalDrawdown     = 0.03;   // 4.5% global — front-runs FTMO 5% daily limit

//--- Carry adjustment (ADR-003)
input double RateA              = 0.0390;  // Interest rate for CurrencyA (e.g. ESTR for EUR)
input double RateB              = 0.0520;  // Interest rate for CurrencyB (e.g. SONIA for GBP)
input double RateC              = 0.0533;  // Interest rate for CurrencyC (e.g. SOFR for USD)
// Legacy carry rate aliases — remove once CarryEngine.mqh is migrated
#define r_EUR  RateA
#define r_GBP  RateB
#define r_USD  RateC
input string CarryRecalcTime    = "17:00"; // broker server time

//--- ADR-024: V3 Generic Triad Configuration
input string CurrencyA  = "EUR";     // First currency of triad
input string CurrencyB  = "GBP";     // Second currency of triad
input string CurrencyC  = "USD";     // Third currency (base denominator)
input string PairAC     = "EURUSD";  // Slot 0: CurrencyA vs CurrencyC
input string PairBC     = "GBPUSD";  // Slot 1: CurrencyB vs CurrencyC
input string PairAB     = "EURGBP";  // Slot 2: CurrencyA vs CurrencyB

enum ENUM_EXECUTION_MODE { MARKET_MAKER, SNIPER };
input ENUM_EXECUTION_MODE ExecutionMode = MARKET_MAKER;
input string  InstanceID  = "MM";     // ADR-021: Instance identifier for JSON state segregation
input double SniperThreshold = 0.0014; // ADR-019: Decoupled entry gate for SNIPER mode

//--- Pipshed Telemetry
input string TelemetryURL         = "https://pipshed.com/api/telemetry/push";
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
input double QuoteSpread = 0.0004; // execution distance from FairValue to quote (8 bps default)

//--- Signal state (updated on each new M5 bar close)
// ADR-024: V3 slot-indexed signal globals
// Index 0 = PairAC signal, Index 1 = PairBC signal
double   g_r_signal[2]          = {0.0, 0.0};  // log returns [AC, BC]
double   g_anchor[2]            = {0.0, 0.0};  // 12-bar-ago mids [AC, BC]

// Legacy aliases — remove once MathEngine.mqh and ExecutionEngine.mqh migrated
#define g_r_EU_signal        g_r_signal[0]
#define g_r_GB_signal        g_r_signal[1]
#define g_EU_mid_12bars_ago  g_anchor[0]
#define g_GB_mid_12bars_ago  g_anchor[1]
int      g_strongest            = -1;    // 0=EUR, 1=GBP, 2=USD
int      g_weakest              = -1;
bool     g_signal_active        = false;
double   g_entry_spread         = 0.0;
// ADR-024: V3 slot-indexed currency scores
// scores[0]=score_A, scores[1]=score_B, scores[2]=score_C
double g_scores[3]            = {0.0, 0.0, 0.0};

// Legacy aliases — remove once all files migrated
#define g_score_eur  g_scores[0]
#define g_score_gbp  g_scores[1]
#define g_score_usd  g_scores[2]

// ADR-024: V3 canonical symbol array — slot ordering BINDING
// g_symbols[SLOT_AC] = PairAC, g_symbols[SLOT_BC] = PairBC,
// g_symbols[SLOT_AB] = PairAB
// Populated in InitGlobals(). Read-only after that.
string g_symbols[3];

// ADR-024: V3 LDAK pairwise correlation array
// Slot ordering BINDING [AC, BC, AB]:
//   g_corr[0] = corr(slot0, slot1) = corr(PairAC, PairBC)
//   g_corr[1] = corr(slot0, slot2) = corr(PairAC, PairAB)
//   g_corr[2] = corr(slot1, slot2) = corr(PairBC, PairAB)
// When A=EUR, B=GBP, C=USD:
//   g_corr[0] = g_r_EU_GU, g_corr[1] = g_r_EU_EG, g_corr[2] = g_r_GU_EG
double g_corr[3]  = {0.0, 0.0, 0.0};

// Legacy aliases — remove once MathEngine.mqh migrated
#define g_r_EU_GU  g_corr[0]
#define g_r_EU_EG  g_corr[1]
#define g_r_GU_EG  g_corr[2]

// ADR-024: V3 LDAK volatility ratio array [slot 0, 1, 2]
double g_vratio[3] = {1.0, 1.0, 1.0};

// Legacy aliases — remove once MathEngine.mqh migrated
#define g_vratio_EU  g_vratio[0]
#define g_vratio_GU  g_vratio[1]
#define g_vratio_EG  g_vratio[2]

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

// ADR-024: V3 slot-indexed inventory — g_inventory[slot][layer]
// slot 0=PairAC, slot 1=PairBC, slot 2=PairAB
// MQL5 requires fixed first dimension for 2D arrays declared globally.
// We use three flat arrays named by slot for compiler compatibility,
// accessed via slot index through helper macros below.
Layer        g_inventory_0[];   // PairAC inventory
Layer        g_inventory_1[];   // PairBC inventory
Layer        g_inventory_2[];   // PairAB inventory

// Legacy aliases — remove once all files migrated
#define g_inventory_EURUSD  g_inventory_0
#define g_inventory_GBPUSD  g_inventory_1
#define g_inventory_EURGBP  g_inventory_2

// ADR-024: V3 slot-indexed pending ticket arrays
ulong    g_pending_bid[3]   = {0, 0, 0};
ulong    g_pending_offer[3] = {0, 0, 0};
ulong    g_add_next[3]      = {0, 0, 0};

// Legacy aliases — remove once ExecutionEngine.mqh and FXMatrix.mq5 migrated
#define g_pending_bid_EURUSD    g_pending_bid[0]
#define g_pending_offer_EURUSD  g_pending_offer[0]
#define g_pending_bid_GBPUSD    g_pending_bid[1]
#define g_pending_offer_GBPUSD  g_pending_offer[1]
#define g_pending_bid_EURGBP    g_pending_bid[2]
#define g_pending_offer_EURGBP  g_pending_offer[2]
#define g_add_next_EURUSD       g_add_next[0]
#define g_add_next_GBPUSD       g_add_next[1]
#define g_add_next_EURGBP       g_add_next[2]

// ADR-024: V3 slot-indexed last layer timestamps
datetime g_last_layer_time[3] = {0, 0, 0};

// Legacy aliases — remove once FXMatrix.mq5 migrated
#define g_last_layer_time_EURUSD  g_last_layer_time[0]
#define g_last_layer_time_GBPUSD  g_last_layer_time[1]
#define g_last_layer_time_EURGBP  g_last_layer_time[2]
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

    // ADR-024: V3 — populate canonical symbol array from inputs
    // Slot ordering BINDING: [AC, BC, AB]
    g_symbols[SLOT_AC] = PairAC;
    g_symbols[SLOT_BC] = PairBC;
    g_symbols[SLOT_AB] = PairAB;

    ArrayResize(g_inventory_0, 0);
    ArrayResize(g_inventory_1, 0);
    ArrayResize(g_inventory_2, 0);

    g_last_layer_time[0] = 0;
    g_last_layer_time[1] = 0;
    g_last_layer_time[2] = 0;

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

    Print("FXMatrix V3 EA initialised. Triad=",
          CurrencyA, "/", CurrencyB, "/", CurrencyC,
          " Pairs=[", PairAC, ",", PairBC, ",", PairAB, "]",
          " NudgeThreshold=", g_NudgeThreshold, " points");
    return INIT_SUCCEEDED;
}

#endif // GLOBALS_MQH
