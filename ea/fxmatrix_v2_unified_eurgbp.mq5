//+------------------------------------------------------------------+
//| fxmatrix_v2_unified_eurgbp.mq5 — thin EURGBP unified V2 shell    |
//| Production fxmatrix_v2_eurgbp.mq5 remains untouched until gate.  |
//+------------------------------------------------------------------+
#property copyright "fxmatrix"
#property version   "1.02"
#property strict

#include "fxmatrix_v2_preset_eurgbp.mqh"
#include "fxmatrix_v2_gbp_cap.mqh"
#include "fxmatrix_v2_eur_cap.mqh"
#include "fxmatrix_v2_eurgbp_dual_cap.mqh"

input double InpQuoteSpread       = 0.0004;
input double InpL0DeadbandMult    = 1.0;   // ADR-017: 1.0=V1 parity; 2.0/3.0=wider L0 skip band
input bool   InpL0DeadbandVolScale = false; // compile-compat; preset.enabled gates behavior
input double InpSpreadMultiplier  = 0.500;
input int    InpEaseDepthStart      = 1;
input int    InpEaseDepthFull       = 3;
input double InpSpreadMultiplierEased = 0.0;
input double InpPassivityBuffer     = 0.5;
input double InpAddPipsFloor      = 9.0;
input double InpExitPips          = 3.0;
input double InpWidenRatio        = 1.304;
input double InpAddPipsCeiling    = 1000.0;
input double InpLotSize           = 0.01;
input int    InpMaxLayers         = 20;
input int    InpGbpCapThreshold   = 0;
input int    InpEurCapThreshold   = 0;
input int    InpRolloverRetryMinutes = 10;
input int    InpRolloverMaxRetries   = 15;
input bool   InpVerboseLog        = true;
input string InpLegAC             = "";   // empty = preset leg_ac_symbol_default (EURUSD)
input string InpLegBC             = "";   // empty = preset leg_bc_symbol_default (GBPUSD)

input bool   EnableTelemetry      = false;
input string TelemetryURL         = "https://pipshed.com/api/telemetry/push";
input string TelemetryAPIKey      = "";
input int    TelemetryIntervalSec = 60;

//+------------------------------------------------------------------+
bool V2_Cap_CheckBlocks(const bool is_long)
{
   return V2_AnyCapBlocksNewAdd(is_long, InpGbpCapThreshold, InpEurCapThreshold);
}

void V2_Cap_RecordBlock(const bool is_long)
{
   // V2_AnyCapBlocksNewAdd records internally when blocking
}

void V2_Cap_Sync(const bool is_long, const int layer_count)
{
   V2_SyncAllCaps(is_long, layer_count);
}

#include "fxmatrix_v2_engine.mqh"
