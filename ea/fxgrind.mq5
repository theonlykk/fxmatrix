//+------------------------------------------------------------------+
//| fxgrind.mq5 — dumb-only market-making EA (Spec A/B)              |
//| One codebase, six .set presets, magic 2226xxxx namespace.        |
//+------------------------------------------------------------------+
#property copyright "fxmatrix"
#property version   "1.00"
#property strict

#include "grind_engine.mqh"
#include "grind_magic_lock.mqh"
#include "grind_config.mqh"

input ulong  InpMagic              = 0;
input string InpSlot               = "OPT";
input double InpWidthPips          = -1.0;
input double InpAddPips            = -1.0;
input double InpExitPips           = -1.0;
input int    InpMaxLayers          = -1;
input double InpLots               = 0.01;
input double InpStrandedThreshPips = -1.0;
input double InpDeadbandPips       = 4.0;
input string InpCapLegA            = "";
input string InpCapLegB            = "";
input double InpCapLegAThresh      = 0.0;
input double InpCapLegBThresh      = 0.0;
input string InpTelemetryInstance  = "GRIND_UNKNOWN";
input bool   InpVerboseLog         = true;
input string InpConfigWarning      = "GEOMETRY UNSET - DO NOT TRADE";
input bool   EnableTelemetry      = false;
input string TelemetryURL         = "https://pipshed.com/api/telemetry/push";
input string TelemetryAPIKey      = "";
input int    TelemetryIntervalSec = 60;

//+------------------------------------------------------------------+
string Grind_BuildHeartbeatJson()
{
   return Grind_TelemetryHeartbeatJson(g_grind_telemetry_instance,
                                       Grind_SideDepth(g_grind_long),
                                       Grind_SideDepth(g_grind_short),
                                       g_grind_fill_count,
                                       g_grind_scalp_count,
                                       g_grind_cap_blocked,
                                       g_grind_halted,
                                       g_grind_halt_reason,
                                       g_grind_recon_ok,
                                       g_grind_last_invariant_ok,
                                       g_grind_cap_own_leg_a,
                                       g_grind_cap_own_leg_b,
                                       g_grind_cap_total_leg_a,
                                       g_grind_cap_total_leg_b,
                                       g_grind_cap_peer_read_failed,
                                       InpMagic,
                                       InpSlot,
                                       InpWidthPips,
                                       InpAddPips,
                                       InpExitPips,
                                       InpMaxLayers,
                                       InpCapLegA,
                                       InpCapLegB);
}

//+------------------------------------------------------------------+
void Grind_EmitHeartbeat()
{
   const string hb_json = Grind_BuildHeartbeatJson();
   Grind_TelemetryEmit(g_grind_telemetry_instance, "HEARTBEAT", hb_json);
   if(EnableTelemetry && TelemetryURL != "" && TelemetryAPIKey != "")
      Grind_TelemetryWebPost(TelemetryURL, TelemetryAPIKey, hb_json, InpVerboseLog);
}

//+------------------------------------------------------------------+
int OnInit()
{
   if(!Grind_ValidateGeometryInputs(InpWidthPips, InpExitPips,
                                    InpMaxLayers, InpStrandedThreshPips,
                                    InpAddPips)) {
      Print("FATAL: geometry not configured — width/add/exit/max_layers/stranded must be > 0");
      return INIT_FAILED;
   }
   if(!Grind_ValidateAddWidthRelationship(InpWidthPips, InpAddPips)) {
      Print("FATAL: InpAddPips (", InpAddPips, ") != ",
            GRIND_ADD_WIDTH_MULTIPLE, " x InpWidthPips (", InpWidthPips, ")");
      return INIT_FAILED;
   }
   if(InpMagic == 0) {
      Print("FATAL: InpMagic must be set from preset");
      return INIT_FAILED;
   }

   if(!Grind_MagicLockClaim(InpMagic)) {
      Print("FATAL: duplicate magic ", InpMagic,
            " — another fxgrind instance is already running on this magic");
      Grind_TelemetryCritical(InpTelemetryInstance, "DUPLICATE_MAGIC",
                              IntegerToString((long)InpMagic));
      return INIT_FAILED;
   }

   g_grind_telemetry_instance = InpTelemetryInstance;
   g_grind_cap_leg_a = InpCapLegA;
   g_grind_cap_leg_b = InpCapLegB;
   g_grind_cap_thresh_a = InpCapLegAThresh;
   g_grind_cap_thresh_b = InpCapLegBThresh;
   g_grind_recon_magic = InpMagic;
   g_grind_recon_slot = InpSlot;
   g_grind_recon_exit_pips = InpExitPips;
   g_grind_recon_max_layers = InpMaxLayers;
   g_grind_halted = false;
   g_grind_cap_blocked = false;
   g_grind_halt_reason = "";

   if(!Grind_ReconstructState()) {
      Print("CRITICAL: Grind_ReconstructState failed — halted in place (",
            g_grind_halt_reason, ")");
   }

   Grind_CapPublishOwnExposure(InpMagic, InpCapLegA, InpCapLegB);

   Print(Grind_ConfigDumpString(InpMagic,
                                InpSlot,
                                _Symbol,
                                InpWidthPips,
                                InpAddPips,
                                InpExitPips,
                                InpMaxLayers,
                                InpStrandedThreshPips,
                                InpDeadbandPips,
                                InpLots,
                                InpCapLegA,
                                InpCapLegB,
                                InpCapLegAThresh,
                                InpCapLegBThresh,
                                InpTelemetryInstance,
                                InpVerboseLog,
                                InpConfigWarning,
                                EnableTelemetry,
                                TelemetryURL,
                                TelemetryAPIKey,
                                TelemetryIntervalSec));

   EventSetTimer(1);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   Grind_MagicLockRelease(InpMagic);
   if(InpVerboseLog)
      Print("fxgrind deinit reason=", reason);
}

//+------------------------------------------------------------------+
void OnTimer()
{
   static bool first_run = true;
   if(first_run) {
      first_run = false;
      EventSetTimer(TelemetryIntervalSec);
   }

   Grind_ResetDailyPnlIfNewDay();
   Grind_ProcessPendingExitMicrostructure();
   Grind_EmitHeartbeat();

   if(Grind_ApiCounterSoftWarnActive())
      Grind_TelemetryEmit(g_grind_telemetry_instance, "WARN_API_SOFT_LIMIT", "{}");
}

//+------------------------------------------------------------------+
void OnTick()
{
   if(!g_grind_halted) {
      Grind_CapPublishOwnExposure(InpMagic, InpCapLegA, InpCapLegB);
      if(!Grind_CheckBookInvariants()) {
         g_grind_halted = true;
         Grind_TelemetryCritical(g_grind_telemetry_instance, "INVARIANT_FAIL",
                                 g_grind_halt_reason);
      }
   }

   if(g_grind_halted)
      return;

   Grind_OnTickEngine(InpMagic,
                      InpSlot,
                      InpWidthPips,
                      InpExitPips,
                      InpAddPips,
                      InpStrandedThreshPips,
                      InpDeadbandPips,
                      InpMaxLayers,
                      InpLots);
}

//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
   Grind_OnTradeTransactionEngine(trans,
                                  InpMagic,
                                  InpSlot,
                                  InpExitPips,
                                  InpDeadbandPips,
                                  InpMaxLayers,
                                  InpLots);
}

//+------------------------------------------------------------------+
bool Grind_TestStubHaltPath()
{
   g_grind_halted = false;
   if(!Grind_ReconstructState()) {
      g_grind_halted = true;
      return true;
   }
   return false;
}
