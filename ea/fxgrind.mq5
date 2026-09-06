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
input double InpExitPips           = -1.0;
input int    InpMaxLayers          = -1;
input double InpLots               = 0.01;
input double InpStrandedThreshPips = -1.0;
input double InpDeadbandPips       = 4.0;
input string InpCapLegA            = "";
input string InpCapLegB            = "";
input string InpTelemetryInstance  = "GRIND_UNKNOWN";
input bool   InpVerboseLog         = true;

//+------------------------------------------------------------------+
int OnInit()
{
   if(!Grind_ValidateGeometryInputs(InpWidthPips, InpExitPips,
                                    InpMaxLayers, InpStrandedThreshPips)) {
      Print("FATAL: geometry not configured — width/exit/max_layers/stranded must be > 0");
      return INIT_FAILED;
   }
   if(InpMagic == 0) {
      Print("FATAL: InpMagic must be set from preset");
      return INIT_FAILED;
   }

   g_grind_telemetry_instance = InpTelemetryInstance;
   g_grind_cap_leg_a = InpCapLegA;
   g_grind_cap_leg_b = InpCapLegB;
   g_grind_halted = false;
   g_grind_cap_blocked = false;

   if(!Grind_ReconstructState()) {
      g_grind_halted = true;
      Grind_TelemetryCritical(g_grind_telemetry_instance, "SPEC_B_RECON_STUB");
      Print("CRITICAL: Grind_ReconstructState stub fail-closed — halted in place");
   }

   if(InpVerboseLog) {
      Print("fxgrind init magic=", InpMagic, " slot=", InpSlot,
            " width=", InpWidthPips, " exit=", InpExitPips,
            " max_layers=", InpMaxLayers,
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
   if(g_grind_halted)
      return;

   Grind_OnTickEngine(InpMagic,
                      InpSlot,
                      InpWidthPips,
                      InpExitPips,
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
                                      g_grind_halted)
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
