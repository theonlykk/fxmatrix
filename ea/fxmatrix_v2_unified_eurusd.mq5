//+------------------------------------------------------------------+
//| fxmatrix_v2_unified_eurusd.mq5 — thin EURUSD unified V2 shell    |
//| Production fxmatrix_v2_eurusd.mq5 remains untouched until gate.  |
//+------------------------------------------------------------------+
#property copyright "fxmatrix"
#property version   "1.01"
#property strict

#include "fxmatrix_v2_preset_eurusd.mqh"
#include "fxmatrix_v2_eur_cap.mqh"

input double InpQuoteSpread       = 0.0004;
input double InpL0DeadbandMult    = 1.0;   // ADR-017: 1.0=V1 parity; 2.0/3.0=wider L0 skip band
input bool   InpL0DeadbandVolScale = true;  // scale band by preset ref vs GBPUSD (0.64)
input double InpSpreadMultiplier  = 0.500;
input int    InpEaseDepthStart      = 1;
input int    InpEaseDepthFull       = 4;
input double InpSpreadMultiplierEased = 0.0;
input double InpPassivityBuffer     = 0.5;
input double InpAddPipsFloor      = 9.0;
input double InpExitPips          = 3.0;
input int    InpRebaseBlackoutSec  = 120;  // V2.5 GUARD-1: suppress re-base near broker midnight (sec)
input double InpRebaseMaxSpreadPips = 8.0; // V2.5 GUARD-1: max broker spread in PIPS at a harvest fill;
                                           // above this the re-base is suppressed as a possible rollover ghost.
                                           // Absolute bound, independent of InpQuoteSpread; editable per shell.
input double InpWidenRatio        = 1.304;
input double InpAddPipsCeiling    = 1000.0;
input double InpLotSize           = 0.01;
input int    InpMaxLayers         = 20;
input int    InpGbpCapThreshold   = 0;    // compile-compat; unused on EURUSD
input int    InpEurCapThreshold   = 0;    // 0=off; block widening adds when |net|>N
input int    InpRolloverRetryMinutes = 10;
input int    InpRolloverMaxRetries   = 15;
input bool   InpVerboseLog        = true;
input string InpLegAC             = "";   // compile-compat; unused on BC-native pairs
input string InpLegBC             = "";   // compile-compat; unused on BC-native pairs

input bool   EnableTelemetry      = false;
input string TelemetryURL         = "https://pipshed.com/api/telemetry/push";
input string TelemetryAPIKey      = "";
input int    TelemetryIntervalSec = 60;
input bool   InpBccEnable         = true;  // ADR-BCC: passive book-consistency checker
input int    InpBccSweepSec       = 60;    // ADR-BCC: full C3/C4 sweep interval (sec)
input bool   InpCbEnable          = true;  // ADR-CB: account-wide equity-floor circuit breaker
input double InpCbDailyLossFrac   = 0.045; // ADR-CB: 4.5% daily floor (FTMO)
input double InpCbAbsoluteLossFrac = 0.090; // ADR-CB: 9% absolute floor (FTMO)
input double InpCbInitialBalance  = 0.0;   // ADR-CB: 0 => capture ACCOUNT_BALANCE once, persist
input bool   InpTaEnable          = true;  // ADR-TA: operational anomaly Trigger A

//+------------------------------------------------------------------+
bool V2_Cap_CheckBlocks(const bool is_long)
{
   return V2_EurCapBlocksNewAdd(g_preset.chart_symbol, is_long, InpEurCapThreshold);
}

void V2_Cap_RecordBlock(const bool is_long)
{
   V2_EurCapRecordBlock();
}

void V2_Cap_Sync(const bool is_long, const int layer_count)
{
   V2_EurCapSyncInstance(g_preset.chart_symbol, is_long, layer_count);
}

#include "fxmatrix_v2_engine.mqh"
