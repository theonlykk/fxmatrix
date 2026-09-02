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
input double InpL0DeadbandPips    = 4.0;   // FTMO hotfix: absolute-pip L0 re-quote skip band (signal arm)
input int    InpL0RequoteCooldownSec = 60; // FTMO hotfix: min resting order age before signal re-quote
input double InpL0DeadbandMult    = 1.0;   // compile-compat no-op (superseded by InpL0DeadbandPips)
input bool   InpL0DeadbandVolScale = false; // compile-compat; preset.enabled gates behavior
input double InpSpreadMultiplier  = 0.500;
input int    InpEaseDepthStart      = 1;
input int    InpEaseDepthFull       = 3;
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
input bool   InpBccEnable         = true;  // ADR-BCC: passive book-consistency checker
input int    InpBccSweepSec       = 60;    // ADR-BCC: full C3/C4 sweep interval (sec)
input bool   InpCbEnable          = true;  // ADR-CB: account-wide equity-floor circuit breaker
input double InpCbDailyLossFrac   = 0.045; // ADR-CB: 4.5% daily floor (FTMO)
input double InpCbAbsoluteLossFrac = 0.090; // ADR-CB: 9% absolute floor (FTMO)
input double InpCbInitialBalance  = 0.0;   // ADR-CB: 0 => capture ACCOUNT_BALANCE once, persist
input bool   InpTaEnable          = true;  // ADR-TA: operational anomaly Trigger A
input V2EntryMode InpEntryMode    = ENTRY_SIGNAL;
input double InpDumbStraddlePips  = 9.0;
input double InpDumbRefBandPips   = 3.0;   // legacy input (unused post-ADR-123)
input int    InpFeedStaleMaxMs    = 10000;  // ADR-122: refuse straddle L0 when feed tick age exceeds this
input double InpStrandedThreshPips = 18.0;   // dumb arm: STRANDED flag when drift_from_mid exceeds this

//+------------------------------------------------------------------+
bool V2_Cap_CheckBlocks(const bool is_long)
{
   return V2_AnyCapBlocksNewAdd(g_preset.cap_namespace, is_long, InpGbpCapThreshold, InpEurCapThreshold);
}

void V2_Cap_RecordBlock(const bool is_long)
{
   // V2_AnyCapBlocksNewAdd records internally when blocking
}

void V2_Cap_Sync(const bool is_long, const int layer_count)
{
   V2_SyncAllCaps(g_preset.cap_namespace, is_long, layer_count);
}

#include "fxmatrix_v2_engine.mqh"
