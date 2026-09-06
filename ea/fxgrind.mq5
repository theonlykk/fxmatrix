//+------------------------------------------------------------------+
//| fxgrind.mq5 — dumb-only market-making EA (Spec A)                |
//| One codebase, per-pair preset headers, magic 2226xxxx namespace. |
//+------------------------------------------------------------------+
#property copyright "fxmatrix"
#property version   "1.00"
#property strict

#include "grind_engine.mqh"

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

   if(InpVerboseLog) {
      Print("fxgrind init magic=", InpMagic, " slot=", InpSlot,
            " width=", InpWidthPips, " add=", InpAddPips,
            " exit=", InpExitPips, " max_layers=", InpMaxLayers,
            " halted=", g_grind_halted);
   }
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(InpVerboseLog)
      Print("fxgrind deinit reason=", reason);
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

   static datetime last_hb = 0;
   if(TimeCurrent() - last_hb >= 60) {
      last_hb = TimeCurrent();
      Grind_TelemetryEmit(
         g_grind_telemetry_instance,
         "HEARTBEAT",
         Grind_TelemetryHeartbeatJson(g_grind_telemetry_instance,
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
                                      g_grind_cap_peer_read_failed)
      );
      if(Grind_ApiCounterSoftWarnActive())
         Grind_TelemetryEmit(g_grind_telemetry_instance, "WARN_API_SOFT_LIMIT", "{}");
   }
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
