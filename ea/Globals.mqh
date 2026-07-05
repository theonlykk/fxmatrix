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
input int    SkewMode           = 2;       // 0=constant 1=linear decrease 2=geometric decay (0.618^n+1)
input double SkewStart          = 0.618;   // starting capture fraction (Fibonacci golden ratio)
input double SkewStep           = 0.000;   // reduction per layer (0=disabled)
input double SkewMin            = 0.050;   // floor — avoids locking in transaction cost losses
input double SkewFloor0         = 0.0002; // ADR-037: Floor_0 at Layer 0 (2 bps, below QuoteSpread=0.0004)
input int    MinLayerExitPoints = 30;     // ADR-041: Hard minimum exit distance in broker points (30 pts = 3.0 pips)
input double RotationThreshold  = 0.0002;  // min edge to rotate signal

//--- Phase 3: drawdown-responsive stress parameters
input double LayerStressBase         = 1.0;  // exponential layer stress multiplier
input double K_spread                = 1.000;  // PnL stress multiplier aggressiveness
input double K_size                  = 0.500;  // lot size reduction aggressiveness
input int    MinLayerIntervalSeconds = 300;    // min seconds between layer adds (1 M5 bar)
    // ADR-057: Kinetic Entry Gate parameters
    input double KineticSigmaThreshold    = 50.0; // sigma_pts where grid doubles (Component 1)
    input int    KineticVelocityBars      = 5;    // rolling window in M5 bars (Component 2)
    input double KineticVelocityThreshold = 5.0;  // max pts/bar to permit add-next (Component 3)

//--- Layer fill
input double MinFillThreshold   = 0.50;    // fraction of lot_size before next layer

//--- Layer mechanics
input int    MaxLayers          = 20;
input double BaseLotSize        = 0.01;
input ulong   EA_MAGIC    = 20260000; // ADR-021: Instance base magic (MM=20260000, SNIPER=20260100)

//--- Nudging
input double NudgePips          = 0.5;     // pips; converted to points per symbol

//--- Risk controls
input double MaxPodDrawdown     = 0.03;    // 3% per pod
input double GlobalDrawdown     = 0.03;   // 4.5% global — front-runs FTMO 5% daily limit
input double InpSoftDrawdownLimit = 3.0; // Tier 2 Soft Warning (% of daily start balance)
input double InpHardDrawdownLimit = 4.0; // Tier 3 Hard Kill Switch (% of daily start balance)
input double InpLDAKDrawdownHealthyThreshold = 0.80; // ADR-061: size_mult above this = drawdown brake not engaged

//--- Carry adjustment (ADR-003)
input string CarryRecalcTime    = "17:00"; // broker server time

//--- ADR-024: V3 Generic Triad Configuration
input string CurrencyA  = "EUR";     // First currency of triad
input string CurrencyB  = "GBP";     // Second currency of triad
input string CurrencyC  = "USD";     // Third currency (base denominator)
input string PairAC     = "EURUSD";  // Slot 0: CurrencyA vs CurrencyC
input string PairBC     = "GBPUSD";  // Slot 1: CurrencyB vs CurrencyC
input string PairAB     = "EURGBP";  // Slot 2: CurrencyA vs CurrencyB

enum ENUM_EXECUTION_MODE  { MARKET_MAKER, SNIPER };
enum ENUM_DIRECTIONAL_BIAS { BIAS_BOTH, BIAS_LONG_ONLY, BIAS_SHORT_ONLY };  // ADR-058
input ENUM_EXECUTION_MODE  ExecutionMode    = MARKET_MAKER;
input ENUM_DIRECTIONAL_BIAS DirectionalBias = BIAS_BOTH;      // ADR-058: BIAS_BOTH/BIAS_LONG_ONLY/BIAS_SHORT_ONLY
input string  InstanceID  = "MM";     // ADR-021: Instance identifier for JSON state segregation
input double SniperThreshold = 0.0014; // ADR-019: Decoupled entry gate for SNIPER mode
input int    SniperExpiryBars = 1;     // ADR-051: Cancel unfilled SNIPER limit after N M5 bars (default 1)
input bool   DebugAddNextBarCloseOnly = false;
// TEMPORARY TEST TOGGLE -- isolates ADR-028's cadence change for backtest comparison only.
// false (default) = current live behavior, Option B evaluated every tick.
// true = pre-ADR-028 behavior, Option B evaluated only on new M5 bar close.
// DO NOT set true in any live/demo deployment -- backtest isolation only.

input bool DebugEnableGridMode     = false;
// TEMPORARY TEST TOGGLE -- ADR-077. false = today's live formula
// (QuoteSpread * (layer_idx+1)), unchanged. true = real GridMode
// branch (0=constant/1=linear/2=hybrid) via GridBase/GridLinearStep/
// GridInflection/GridExpBase. DO NOT enable in live/demo deployment
// without explicit backtest validation first.

input bool DebugEnableLayerStress  = false;
// TEMPORARY TEST TOGGLE -- ADR-077. false = neutral (1.0x). true =
// LayerStressBase^layer_idx multiplier (previously fully dormant,
// never applied to live spacing).

input bool DebugEnablePnLStress    = false;
// TEMPORARY TEST TOGGLE -- ADR-077. false = neutral (1.0x). true =
// live-drawdown-linked multiplier via GetPodUnrealizedPnL() and
// K_spread (previously fully dormant).

input bool DebugEnableLDAKDilation = false;
// TEMPORARY TEST TOGGLE -- ADR-077. false = neutral (1.0x). true =
// g_cooldown_LDAK[instrument] multiplier (previously fully dormant
// in this specific spacing context).

input bool DebugEnableExitResetDelay = false;
// TEMPORARY TEST TOGGLE -- ADR-078. false (default) = today's exact
// behavior: LIFO exit cancels stale add_next and resubmits
// IMMEDIATELY, inline, zero delay. true = defer resubmit via
// ExitResetDelaySeconds, letting the market show whether the
// scratched level still holds before re-committing. DO NOT enable
// in live/demo deployment without explicit backtest validation.

input int ExitResetDelaySeconds = 30;
// ADR-078: delay before re-arming add_next after a LIFO exit
// scratch, when DebugEnableExitResetDelay=true. Deliberately
// separate from MinLayerIntervalSeconds (deepening pace) --
// this governs re-engagement pace, a different decision.

input bool DebugEnableDynamicReanchor = false;
// TEMPORARY TEST TOGGLE -- ADR-079. false (default) = today's exact
// behavior: static-anchor theoretical price passed directly to the
// existing passivity clamp, accepting compression if the market has
// overrun the level. true = if the static-anchor price would violate
// passivity, discard it and recompute a new price from CURRENT
// market, preserving the theoretical DISTANCE (grid width) rather
// than the theoretical absolute level. The existing clamp (lines
// ~432-451) is NOT modified in any way -- it remains the final,
// unconditional safety check either way. DO NOT enable in live/demo
// deployment without explicit backtest validation.

input bool DebugUseUnifiedAddNextSpacing = false;
// TEMPORARY TEST TOGGLE -- ADR-080. false (default) = HandleEntryFill
// retains its legacy A_golden = E_n * 1.618 formula (2-way max,
// no kinetic) -- UNCHANGED from today's production behavior. true =
// HandleEntryFill delegates entirely to ComputeNextLayerPrice(),
// injecting full kinetic awareness into the fill-time add_next
// calculation for the first time. DO NOT enable in live/demo
// deployment without explicit backtest validation -- this changes
// stored add_next values at layer creation, not just downstream
// placement.

input double ExitKineticDivisor = 3.0;
// ADR-082: divisor applied to kinetic_dist (in pips) to derive
// exit distance when DebugUseUnifiedAddNextSpacing=true. Ensures
// exit distance stays smaller than add distance using the SAME
// underlying signal (verified this session across the full
// observed kinetic_dist range 3-79.9 pips).

input double ExitKineticCapPips = 8.0;
// ADR-082: upper cap on kinetic-derived exit distance, in pips.
// Confirmed this session to sit near the 75th percentile of real
// observed kinetic_dist values (24.6 pips / 3 ≈ 8.2) -- engages
// specifically during the upper quartile of real conditions, not
// only rare extremes.

input int ExitRetryIntervalSeconds = 15;
// ADR-081: minimum seconds between PlaceExitLimit retry attempts
// for an orphaned exit. Throttles the tick-rate retry storm that
// caused unconditional passivity-fail logging on every tick.
// Does NOT change the eventual exit price or outcome.

input int ExitRetryMaxSeconds = 300;
// ADR-081: wall-clock ceiling. If an orphaned exit has failed
// placement continuously for this long, fire a ONE-SHOT critical
// alert. Defense against a permanently-stuck layer.

//--- Pipshed Telemetry
input string TelemetryURL         = "https://pipshed.com/api/telemetry/push";
input string TelemetryAPIKey      = "G_o9MVJgWSGVS0CuTX7_1LiR76qbtwJMMwBjb_ncT7A";
input int    TelemetryIntervalSec = 60;
input bool   EnableTelemetry      = true;

//--- Logging
input bool   EnableVerboseLog   = true;

//--- Phase 4: LDAK correlation penalty
input double LDAK_Dilation_Max = 3.000; // LDAK: max grid dilation multiplier
input double CooldownDecayRate = 0.025; // ADR-046: fractional decay per M5 bar (2.5% default)

//--- ADR-052 Step C: Dynamic Spread & Confidence Sizing
input double SpreadMultiplier  = 0.500; // ADR-052: adds (sigma_FV * multiplier) to base half-spread
input double SigmoidMaxScale   = 3.000; // ADR-052: maximum lot multiplier when timeframes agree (σ≈0)
input double SigmoidMidpoint   = 50.0;  // ADR-052: dispersion in points where lot multiplier halves
input double SigmoidSteepness  = 0.150; // ADR-052: rate of lot size decay with dispersion (k)

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
double   g_anchor[2]            = {0.0, 0.0};  // StrengthWindow-bar-ago mids [AC, BC]

int      g_strongest            = -1;    // 0=EUR, 1=GBP, 2=USD
int      g_weakest              = -1;
bool     g_signal_active        = false;
double   g_entry_spread         = 0.0;
// ADR-024: V3 slot-indexed currency scores
// scores[0]=score_A, scores[1]=score_B, scores[2]=score_C
double g_scores[3]            = {0.0, 0.0, 0.0};

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
// When A=EUR, B=GBP, C=USD: g_corr[0]=corr(AC,BC), g_corr[1]=corr(AC,AB), g_corr[2]=corr(BC,AB)
double g_corr[3]  = {0.0, 0.0, 0.0};

// ADR-024: V3 LDAK volatility ratio array [slot 0, 1, 2]
double g_vratio[3] = {1.0, 1.0, 1.0};

// ADR-046: viscous LDAK high-water mark per slot — decays toward 1.0 at CooldownDecayRate per bar
double g_cooldown_LDAK[3] = {1.0, 1.0, 1.0};

enum ENUM_LDAK_GATE_OUTCOME {
    LDAK_GATE_PASS   = 0,
    LDAK_GATE_CLAMP  = 1,
    LDAK_GATE_REFUSE = 2
};

// ADR-061 telemetry capture: last ComputeLDAKLotSize() snapshot per slot [0, 1, 2]
double g_ldak_last_size_mult[3] = {0.0, 0.0, 0.0};
double g_ldak_last_S_eff[3]     = {0.0, 0.0, 0.0};
double g_ldak_last_w[3]         = {0.0, 0.0, 0.0};
double g_ldak_last_raw_vol[3]   = {0.0, 0.0, 0.0};
int    g_ldak_last_gate[3]      = {LDAK_GATE_PASS, LDAK_GATE_PASS, LDAK_GATE_PASS};

// ADR-062 telemetry capture: execution-layer DirectionalBias backstop fire count
int g_bias_backstop_count = 0;

// ADR-063 Ruling 5 (Gemini): persistent circular buffer of critical
// alert messages. NEVER cleared on read -- clear-on-read risks
// losing a real alert if a telemetry HTTP push fails to reach
// Pipshed. Oldest entries silently overwritten once full.
#define CRITICAL_ALERT_BUFFER_SIZE 10
string g_critical_alerts[CRITICAL_ALERT_BUFFER_SIZE];
int    g_critical_alert_write_idx = 0;

// ADR-052 Step B: Multi-timeframe term structure outputs
double g_fv_combined[2]  = {0.0, 0.0};  // [SLOT_AC, SLOT_BC] weighted blended anchor
double g_sigma_fv[2]     = {0.0, 0.0};  // [SLOT_AC, SLOT_BC] dispersion in price units
double g_sigma_fv_pts[2] = {0.0, 0.0};  // [SLOT_AC, SLOT_BC] dispersion in points

//--- Bar tracking
datetime g_last_bar_time        = 0;

//--- Carry recalculation
datetime g_last_carry_recalc_date = 0;
int      g_last_rollover_day_of_year = 0; // ADR-045 fix: broker window gate, stores dt.day_of_year

//--- Pod state
bool     g_halted               = false;
double   g_peak_equity          = 0.0;
double   g_daily_start_balance  = 0.0; // balance at midnight CET rollover
int      g_current_day          = -1;  // tracks day for midnight reset
bool     g_warning_sent         = false; // Phase 3.A: soft warning gate (one-time per day)
string   g_daily_start_date     = "";    // Phase 3.A: YYYYMMDD string for reboot shield
double   g_NudgeThreshold       = 0.0;   // computed at InitGlobals() from NudgePips

//--- Shared queue
CloseByTask  g_closeby_queue[];          // pending CloseBy retry tasks

// ADR-024: V3 slot-indexed inventory — g_inventory[slot][layer]
// slot 0=PairAC, slot 1=PairBC, slot 2=PairAB
// MQL5 requires fixed first dimension for 2D arrays declared globally.
// We use three flat arrays named by slot for compiler compatibility.
Layer        g_inventory_0[];   // PairAC inventory
Layer        g_inventory_1[];   // PairBC inventory
Layer        g_inventory_2[];   // PairAB inventory

// ADR-024: V3 slot-indexed pending ticket arrays
ulong    g_pending_bid[3]   = {0, 0, 0};
ulong    g_pending_offer[3] = {0, 0, 0};
ulong    g_add_next[3]      = {0, 0, 0};

// ADR-024: V3 slot-indexed last layer timestamps
datetime g_last_layer_time[3] = {0, 0, 0};
// ADR-078: non-zero = exit-triggered reset pending resubmit via
// OnTick Option B, gated by ExitResetDelaySeconds. Zero = no
// pending exit-reset (normal deepen-cycle path, unaffected).
datetime g_last_exit_reset_time[3] = {0, 0, 0};
int      g_carry_hour           = 17;  // parsed from CarryRecalcTime in OnInit
int      g_carry_minute         = 0;   // parsed from CarryRecalcTime in OnInit

//--- ADR-017: Hard API request counter
int  g_daily_api_count = 0;    // resets at broker midnight with g_daily_start_balance
bool g_api_halt        = false; // true when g_daily_api_count >= 1800

bool g_reconciliation_pending = false;

// ADR-081: schema version loaded from global state file (0 = absent/legacy)
int g_loaded_schema_version = 0;

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
