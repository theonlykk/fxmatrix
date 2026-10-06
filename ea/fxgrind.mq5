//+------------------------------------------------------------------+
//| fxgrind.mq5 — dumb-only market-making EA (Spec A/B)              |
//| One codebase, six .set presets, magic 2226xxxx namespace.        |
//+------------------------------------------------------------------+
#property copyright "fxmatrix"
#property version   "2.00"
#property strict

#include "grind_engine.mqh"
#include "grind_snapshot.mqh"
#include "grind_magic_lock.mqh"
#include "grind_config.mqh"

input ulong  InpMagic              = 0;
input string InpSlot               = "OPT";
input double InpWidthPips          = -1.0;
input double InpAddPips            = -1.0;
input double InpExitPips           = -1.0;
input double InpWidthPipsLong      = -1.0;  // v2: -1 = InpWidthPips
input double InpWidthPipsShort     = -1.0;  // v2: -1 = InpWidthPips
input double InpAddPipsLong        = -1.0;  // v2: -1 = InpAddPips
input double InpAddPipsShort       = -1.0;  // v2: -1 = InpAddPips
input double InpExitPipsLong       = -1.0;  // v2: -1 = InpExitPips
input double InpExitPipsShort      = -1.0;  // v2: -1 = InpExitPips
input int    InpMaxLayers          = -1;
input double InpLots               = 0.01;
input double InpStrandedThreshPips = -1.0;
input double InpDeadbandPips       = 4.0;
input bool   InpEnableCarryPass    = false;   // ADR-135b carry exit shift
input bool   InpEnableCommandedEject = false;   // ADR-155 operator ejection switch
input bool   InpAutoEject              = false;  // ADR-157 automatic passive ejection
input int    InpAutoEjectStableMinutes = 5;      // ADR-157 W: no new extreme for W of the last 2W minutes
input double InpAutoEjectSpreadMult    = 1.5;    // ADR-157 k: spread <= k x mean of last 60 M1 bars
input bool   InpVirtualLattice = false; // ADR-162 virtual lattice past cap
input bool   InpLatticeReroll = false; // ADR-165 continuous re-roll (requires lattice)
input int    InpRollGateOpposite = -1; // ADR-166: roll / re-roll only while the opposite side holds <= N layers (-1 = off; requires lattice)
input bool   InpBreakerEnable = true;   // ADR-158 account daily-loss breaker
input bool   InpSessionEnable = false;   // ADR-161 entry window 07:00-16:55 Toronto (Fleet B)
input bool   InpFillTimePlace      = false;   // D1 kill switch, preset opts in
input int    InpSlotNearReserve    = 0;       // preset opts in; Q = GRIND_SLOT_NEAR_RESERVE
input double InpEntryHorizonPips   = 0.0;   // D3 kill switch, 0 = off; preset opts in
input int    InpApiEntryStop       = 1000000; // C100: no new entries at this daily request count (terminal-wide counter; same value on every chart of a terminal)
input int    InpApiSoftWarn        = 999000;  // C100: WARN_API_SOFT_LIMIT and no empty-side L0 re-centre at this count
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

#define GRIND_EA_BUILD ("fxgrind " + TimeToString(__DATETIME__, TIME_DATE|TIME_SECONDS))

ulong g_grind_last_telemetry_tick = 0;

double g_geo_width_long  = 0.0;
double g_geo_width_short = 0.0;
double g_geo_add_long    = 0.0;
double g_geo_add_short   = 0.0;
double g_geo_exit_long   = 0.0;
double g_geo_exit_short  = 0.0;

//+------------------------------------------------------------------+
string Grind_BuildHeartbeatJson()
{
   string hb = Grind_TelemetryHeartbeatJson(g_grind_telemetry_instance,
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
                                            g_geo_width_long,
                                            g_geo_add_long,
                                            g_geo_exit_long,
                                            InpMaxLayers,
                                            InpCapLegA,
                                            InpCapLegB);
   const int len = StringLen(hb);
   if(len < 2 || StringGetCharacter(hb, len - 1) != '}')
      return hb;
   hb = StringSubstr(hb, 0, len - 1);
   hb += StringFormat(
      ",\"add_due_long\":%s,\"add_due_short\":%s,"
      "\"entry_stopped\":%s,\"near_reserve_blocks\":%d,"
      "\"guard_total\":%d,\"entry_place_latency_ms\":%d,"
      "\"add_held_long\":%s,\"add_held_short\":%s,"
      "\"add_held_target_long\":%s,\"add_held_target_short\":%s,"
      "\"entry_transitions_used_long\":%d,\"entry_transitions_used_short\":%d,"
      "\"add_gap_missed_long\":%d,\"add_gap_missed_short\":%d,"
      "\"exit_clamped_promotions_long\":%d,\"exit_clamped_promotions_short\":%d,"
      "\"width_pips_long\":%.4f,\"width_pips_short\":%.4f,"
      "\"add_pips_long\":%.4f,\"add_pips_short\":%.4f,"
      "\"exit_pips_long\":%.4f,\"exit_pips_short\":%.4f}",
      g_grind_add_due_long ? "true" : "false",
      g_grind_add_due_short ? "true" : "false",
      Grind_ApiCounterEntryStopped() ? "true" : "false",
      g_grind_near_reserve_blocks,
      g_grind_last_guard_total,
      (int)g_grind_entry_place_latency_ms,
      g_grind_long.add_held ? "true" : "false",
      g_grind_short.add_held ? "true" : "false",
      g_grind_long.add_held ? DoubleToString(g_grind_long.add_held_target, 5) : "null",
      g_grind_short.add_held ? DoubleToString(g_grind_short.add_held_target, 5) : "null",
      g_grind_long.entry_transitions_used,
      g_grind_short.entry_transitions_used,
      g_grind_long.add_gap_missed,
      g_grind_short.add_gap_missed,
      g_grind_long.exit_clamped_promotions,
      g_grind_short.exit_clamped_promotions,
      g_geo_width_long,
      g_geo_width_short,
      g_geo_add_long,
      g_geo_add_short,
      g_geo_exit_long,
      g_geo_exit_short);
   return hb;
}

//+------------------------------------------------------------------+
void Grind_EmitHeartbeat()
{
   Grind_MaeClaimReporterForHeartbeat(InpMagic, TelemetryIntervalSec);
   const string hb_json = Grind_BuildHeartbeatJson();
   Grind_TelemetryEmitHeartbeat(g_grind_telemetry_instance, hb_json);
   if(EnableTelemetry && TelemetryURL != "" && TelemetryAPIKey != "")
      Grind_TelemetryWebPost(TelemetryURL, TelemetryAPIKey, hb_json, InpVerboseLog);
}

//+------------------------------------------------------------------+
int OnInit()
{
   if(!Grind_ResolveSideInput(InpWidthPips, InpWidthPipsLong, g_geo_width_long)) {
      Print("FATAL: InpWidthPipsLong must be -1 (inherit) or > 0");
      return INIT_FAILED;
   }
   if(!Grind_ResolveSideInput(InpWidthPips, InpWidthPipsShort, g_geo_width_short)) {
      Print("FATAL: InpWidthPipsShort must be -1 (inherit) or > 0");
      return INIT_FAILED;
   }
   if(!Grind_ResolveSideInput(InpAddPips, InpAddPipsLong, g_geo_add_long)) {
      Print("FATAL: InpAddPipsLong must be -1 (inherit) or > 0");
      return INIT_FAILED;
   }
   if(!Grind_ResolveSideInput(InpAddPips, InpAddPipsShort, g_geo_add_short)) {
      Print("FATAL: InpAddPipsShort must be -1 (inherit) or > 0");
      return INIT_FAILED;
   }
   if(!Grind_ResolveSideInput(InpExitPips, InpExitPipsLong, g_geo_exit_long)) {
      Print("FATAL: InpExitPipsLong must be -1 (inherit) or > 0");
      return INIT_FAILED;
   }
   if(!Grind_ResolveSideInput(InpExitPips, InpExitPipsShort, g_geo_exit_short)) {
      Print("FATAL: InpExitPipsShort must be -1 (inherit) or > 0");
      return INIT_FAILED;
   }

   if(!Grind_ValidateGeometryInputs(InpWidthPips, InpExitPips,
                                    InpMaxLayers, InpStrandedThreshPips,
                                    InpAddPips)) {
      Print("FATAL: geometry not configured — width/add/exit/max_layers/stranded must be > 0");
      return INIT_FAILED;
   }
   if(!Grind_ValidateAddWidthRatio(InpWidthPips, InpAddPips)) {
      Print("FATAL: InpAddPips / InpWidthPips = ", InpAddPips / InpWidthPips,
            " is outside [", GRIND_ADD_WIDTH_RATIO_MIN, ", ",
            GRIND_ADD_WIDTH_RATIO_MAX, "] -- typo guard, ADR-153");
      return INIT_FAILED;
   }
   if(!Grind_ValidateGeometryInputs(g_geo_width_long, g_geo_exit_long,
                                    InpMaxLayers, InpStrandedThreshPips,
                                    g_geo_add_long)) {
      Print("FATAL: long geometry not configured — width/add/exit/max_layers/stranded must be > 0");
      return INIT_FAILED;
   }
   if(!Grind_ValidateAddWidthRatio(g_geo_width_long, g_geo_add_long)) {
      Print("FATAL: long add/width ratio outside [", GRIND_ADD_WIDTH_RATIO_MIN, ", ",
            GRIND_ADD_WIDTH_RATIO_MAX, "] -- typo guard, ADR-153");
      return INIT_FAILED;
   }
   if(!Grind_ValidateGeometryInputs(g_geo_width_short, g_geo_exit_short,
                                    InpMaxLayers, InpStrandedThreshPips,
                                    g_geo_add_short)) {
      Print("FATAL: short geometry not configured — width/add/exit/max_layers/stranded must be > 0");
      return INIT_FAILED;
   }
   if(!Grind_ValidateAddWidthRatio(g_geo_width_short, g_geo_add_short)) {
      Print("FATAL: short add/width ratio outside [", GRIND_ADD_WIDTH_RATIO_MIN, ", ",
            GRIND_ADD_WIDTH_RATIO_MAX, "] -- typo guard, ADR-153");
      return INIT_FAILED;
   }
   if(!Grind_ValidateDeadband(InpDeadbandPips)) {
      Print("FATAL: InpDeadbandPips must be >= 0");
      return INIT_FAILED;
   }
   if(InpMagic == 0) {
      Print("FATAL: InpMagic must be set from preset");
      return INIT_FAILED;
   }
   if(!Grind_ValidateLatticeInputs(InpVirtualLattice, InpAutoEject)) {
      Print("FATAL: InpVirtualLattice requires InpAutoEject=false (ADR-162 s7)");
      return INIT_FAILED;
   }
   if(!Grind_ValidateRerollInputs(InpVirtualLattice, InpLatticeReroll)) {
      Print("FATAL: InpLatticeReroll requires InpVirtualLattice=true (ADR-165 s4.1)");
      return INIT_FAILED;
   }
   if(!Grind_ValidateRollGateInputs(InpVirtualLattice, InpRollGateOpposite)) {
      Print("FATAL: InpRollGateOpposite must be -1, or >= 0 with InpVirtualLattice=true (ADR-166)");
      return INIT_FAILED;
   }
   const bool api_inputs_ok = Grind_ApiLimitsApplyInputs(InpApiEntryStop, InpApiSoftWarn);

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
   g_grind_recon_exit_pips = g_geo_exit_long;
   g_grind_recon_exit_pips_short = g_geo_exit_short;
   g_grind_recon_max_layers = InpMaxLayers;
   g_grind_recon_verbose = InpVerboseLog;
   Grind_EngineConfigureAdr152(InpFillTimePlace, InpSlotNearReserve, InpEntryHorizonPips);
   Grind_Adr152ResetDueFlags();
   Grind_ScalpTelemetryConfigure(EnableTelemetry,
                                 TelemetryURL,
                                 TelemetryAPIKey,
                                 InpVerboseLog);
   Grind_ArchiveConfigure(EnableTelemetry,
                          TelemetryURL,
                          TelemetryAPIKey,
                          InpTelemetryInstance,
                          InpMagic,
                          InpVerboseLog);
   g_grind_last_telemetry_tick = 0;
   g_grind_halted = false;
   g_grind_cap_blocked = false;
   g_grind_halt_reason = "";
   Grind_QuarantineReset();

   Grind_ReplayInit(InpMagic, GetTickCount64());

   if(!Grind_ReconstructState()) {
      Print("CRITICAL: Grind_ReconstructState failed — halted in place (",
            g_grind_halt_reason, ")");
   } else {
      const int a = g_grind_recon_exit_shortfall_long;
      const int b = g_grind_recon_exit_shortfall_short;
      if(a + b > 0) {
         Print("WARN STARTUP_EXIT_SHORTFALL long=", a, " short=", b);
         Grind_ArchiveMarker("WARN", "STARTUP_EXIT_SHORTFALL", "", 0,
                             StringFormat("{\"long\":%d,\"short\":%d}", a, b));
         if(Grind_StartupShortfallCritical(a, b))
            Grind_TelemetryCritical(g_grind_telemetry_instance,
                                    "STARTUP_EXIT_SHORTFALL_SIDE",
                                    StringFormat("long=%d short=%d", a, b));
      }
      Grind_RetryMissingExits(InpMagic, InpSlot, InpLots);
      if(!Grind_RebuildExitsAtStart(InpMagic)) {
         g_grind_halted = true;
         g_grind_halt_reason = "REBUILD_EXIT_FAILED";
         Grind_TelemetryCritical(g_grind_telemetry_instance, "REBUILD_EXIT_FAILED", "");
         Grind_CancelOwnEntryOrders(InpMagic, InpSlot);
         Print("CRITICAL: REBUILD_EXIT_FAILED -- halted in place");
      } else {
         Grind_GeoExitWriteLabels(InpMagic, g_geo_exit_long, g_geo_exit_short);
         g_grind_start_add_reprice_long = true;
         g_grind_start_add_reprice_short = true;
      }
   }

   Grind_CarryPruneShiftGvs(InpMagic);
   Grind_MaeInit();
   Grind_CapPublishOwnExposure(InpMagic, InpCapLegA, InpCapLegB);

   Print(Grind_ConfigDumpString(InpMagic,
                                InpSlot,
                                _Symbol,
                                g_geo_width_long,
                                g_geo_add_long,
                                g_geo_exit_long,
                                InpMaxLayers,
                                InpStrandedThreshPips,
                                InpDeadbandPips,
                                InpLots,
                                InpFillTimePlace,
                                InpSlotNearReserve,
                                InpEntryHorizonPips,
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

   int prev_reason = -1;
   datetime prev_time = 0;
   long prev_anchor = 0;
   if(Grind_ArchiveReadPendingDeinit(InpMagic, prev_reason, prev_time, prev_anchor)) {
      const string deinit_fields = Grind_ArchiveConfigFields(
         "DEINIT", prev_reason, _Symbol, InpSlot, GRIND_EA_BUILD,
         (long)AccountInfoInteger(ACCOUNT_LOGIN),
         g_geo_width_long, g_geo_add_long, g_geo_exit_long, InpMaxLayers, InpLots,
         InpDeadbandPips, InpStrandedThreshPips,
         InpCapLegA, InpCapLegB, InpCapLegAThresh, InpCapLegBThresh,
         InpTelemetryInstance, InpVerboseLog, InpConfigWarning,
         EnableTelemetry, TelemetryIntervalSec, InpEnableCarryPass) +
         "," + Grind_ArchiveGeometryFields(g_geo_width_long, g_geo_add_long, g_geo_exit_long,
                                           g_geo_width_short, g_geo_add_short, g_geo_exit_short) +
         "," + Grind_ArchiveDeinitExtraFields(prev_time, InpMagic, prev_anchor);
      Grind_ArchiveEnqueue("config_event", deinit_fields);
      Grind_ArchiveClearPendingDeinit(InpMagic);
   }

   const string init_fields = Grind_ArchiveConfigFields(
      "INIT", 0, _Symbol, InpSlot, GRIND_EA_BUILD,
      (long)AccountInfoInteger(ACCOUNT_LOGIN),
      g_geo_width_long, g_geo_add_long, g_geo_exit_long, InpMaxLayers, InpLots,
      InpDeadbandPips, InpStrandedThreshPips,
      InpCapLegA, InpCapLegB, InpCapLegAThresh, InpCapLegBThresh,
      InpTelemetryInstance, InpVerboseLog, InpConfigWarning,
      EnableTelemetry, TelemetryIntervalSec, InpEnableCarryPass) +
      "," + Grind_ArchiveGeometryFields(g_geo_width_long, g_geo_add_long, g_geo_exit_long,
                                        g_geo_width_short, g_geo_add_short, g_geo_exit_short);
   Grind_ArchiveEnqueue("config_event", init_fields);

   Grind_CarryEmitSnapshot(_Symbol, InpMagic);

   Grind_SessionStep(InpMagic, InpSlot, InpSessionEnable, TimeGMT(), false);
   Print("GRIND_SESSION enable=", InpSessionEnable,
         " toronto_utc_offset=", Grind_TorontoUtcOffset(TimeGMT()),
         " open_now=", Grind_SessionOpenAt(TimeGMT()));
   Print("GRIND_LATTICE enable=", InpVirtualLattice);
   Print("GRIND_REROLL enable=", InpLatticeReroll);
   Print("GRIND_ROLL_GATE opposite_max=", InpRollGateOpposite);
   Grind_LatticeRollGateInitRestart(InpRollGateOpposite);
   Print("GRIND_API_LIMITS entry_stop=", g_grind_api_entry_stop, " soft_warn=", g_grind_api_soft_warn);
   Print("GRIND_GEOMETRY long width=", DoubleToString(g_geo_width_long, 4),
         " add=", DoubleToString(g_geo_add_long, 4),
         " exit=", DoubleToString(g_geo_exit_long, 4),
         " short width=", DoubleToString(g_geo_width_short, 4),
         " add=", DoubleToString(g_geo_add_short, 4),
         " exit=", DoubleToString(g_geo_exit_short, 4));
   Print("GRIND_REBUILD long=", g_grind_rebuild_long ? "true" : "false",
         " short=", g_grind_rebuild_short ? "true" : "false");
   Grind_ArchiveMarker("INFO", "LATTICE_CONFIG", "", 0,
                       StringFormat("{\"enable\":%s,\"reroll\":%s,\"roll_gate\":%d}",
                                    InpVirtualLattice ? "true" : "false",
                                    InpLatticeReroll ? "true" : "false",
                                    InpRollGateOpposite));
   if(!api_inputs_ok) {
      const string bad = StringFormat("{\"input_entry_stop\":%d,\"input_soft_warn\":%d,\"using_entry_stop\":%d,\"using_soft_warn\":%d}",
                                      InpApiEntryStop, InpApiSoftWarn,
                                      g_grind_api_entry_stop, g_grind_api_soft_warn);
      Grind_ArchiveMarker("WARN", "API_LIMITS_INVALID", "", 0, bad);
      Print("WARN API_LIMITS_INVALID ", bad);
   }
   Grind_ArchiveMarker("INFO", "API_LIMITS_CONFIG", "", 0,
                       StringFormat("{\"entry_stop\":%d,\"soft_warn\":%d}",
                                    g_grind_api_entry_stop, g_grind_api_soft_warn));
   Grind_ApiLimitsPublishAndCheck();
   EventSetTimer(1);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Grind_ArchiveRecordDeinit(InpMagic, reason, TimeCurrent(), g_grind_archive_anchor_ms);

   GlobalVariablesFlush();
   EventKillTimer();
   Grind_MagicLockRelease(InpMagic);
   if(InpVerboseLog)
      Print("fxgrind deinit reason=", reason);
}

//+------------------------------------------------------------------+
void OnTimer()
{
   Grind_ReplayOnTimer(InpMagic, InpSlot, g_geo_exit_long, g_geo_add_long, InpDeadbandPips,
                       InpMaxLayers, InpLots, g_geo_exit_short, g_geo_add_short,
                       GetTickCount64());
   Grind_GvFlushIfDirty();
   Grind_SnapshotOnTimer();
   Grind_ArchiveFlush(false);
   Grind_SessionStep(InpMagic, InpSlot, InpSessionEnable, TimeGMT(), false);

   const ulong now_tick = GetTickCount64();
   if(Grind_TimerTelemetryDue(now_tick, g_grind_last_telemetry_tick, TelemetryIntervalSec)) {
      Grind_ResetDailyPnlIfNewDay();
      Grind_MaeOnTimer();
      Grind_GateAccumulate("GRIND_SNAPSHOT_GATED_S_" + Grind_FtmoDayKey(TimeGMT()),
                            g_grind_mae_is_reporter, g_grind_breaker_gated, TimeGMT(),
                            2 * TelemetryIntervalSec);
      Grind_ProcessPendingExitMicrostructure();
      Grind_DrainScalpEventQueue();
      Grind_EmitHeartbeat();
      const datetime carry_now = TimeTradeServer();
      Grind_CarryOnTimerStep(_Symbol, InpMagic, g_geo_exit_long, InpEnableCarryPass, carry_now,
                             g_geo_exit_short);
      if(Grind_ApiCounterSoftWarnActive())
         Grind_TelemetryEmit(g_grind_telemetry_instance, "WARN_API_SOFT_LIMIT", "{}");
      g_grind_last_telemetry_tick = now_tick;
   }
}

//+------------------------------------------------------------------+
void OnTick()
{
   Grind_ProcessCloseByQueues(InpMagic, InpVerboseLog);

   if(!g_grind_halted) {
      Grind_CapPublishOwnExposure(InpMagic, InpCapLegA, InpCapLegB);
      const bool ok = Grind_ReplayCheckInvariants(InpMagic, InpSlot, g_geo_exit_long, g_geo_add_long,
                                                  InpDeadbandPips, InpMaxLayers, InpLots,
                                                  g_geo_exit_short, g_geo_add_short,
                                                  GetTickCount64());
      const int action = Grind_QuarantineStep(ok, g_grind_invariant_reason, GetTickCount64());
      if(action == GRIND_INV_HALT) {
         g_grind_halted = true;
         g_grind_halt_reason = g_grind_invariant_reason;
         Grind_TelemetryCritical(g_grind_telemetry_instance, "INVARIANT_FAIL",
                                 g_grind_halt_reason, g_grind_invariant_detail);
         Grind_InvariantEmitArchive(g_grind_halt_reason);
         Grind_CancelOwnEntryOrders(InpMagic, InpSlot);
      }
   }

   Grind_EjectPollCommand(InpMagic, InpEnableCommandedEject, g_geo_exit_long,
                          g_grind_halted || g_grind_quarantined, g_geo_exit_short);
   Grind_AutoEjectOnTick(InpMagic, InpAutoEject, g_geo_exit_long, InpMaxLayers,
                         g_grind_halted || g_grind_quarantined,
                         InpAutoEjectStableMinutes, InpAutoEjectSpreadMult,
                         g_geo_exit_short);
   Grind_LatticeOnTick(InpMagic, InpSlot, InpLots, InpVirtualLattice,
                       g_geo_exit_long, g_geo_add_long,
                       InpMaxLayers, g_grind_halted || g_grind_quarantined, TimeCurrent(),
                       g_geo_exit_short, g_geo_add_short, InpLatticeReroll,
                       InpRollGateOpposite);
   Grind_SessionStep(InpMagic, InpSlot, InpSessionEnable, TimeGMT(), true);
   Grind_BreakerOnTick(InpMagic, InpSlot, InpBreakerEnable);

   if(g_grind_halted)
      return;

   if(g_grind_quarantined) {
      if(Grind_GuardsAllowTrading(InpMagic, InpLots))
         Grind_RetryMissingExits(InpMagic, InpSlot, InpLots);
      return;
   }

   Grind_OnTickEngine(InpMagic,
                      InpSlot,
                      g_geo_width_long,
                      g_geo_exit_long,
                      g_geo_add_long,
                      InpStrandedThreshPips,
                      InpDeadbandPips,
                      InpMaxLayers,
                      InpLots,
                      g_geo_width_short,
                      g_geo_add_short);
}

//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
   Grind_OnTradeTransactionEngine(trans,
                                  InpMagic,
                                  InpSlot,
                                  g_geo_exit_long,
                                  g_geo_add_long,
                                  InpDeadbandPips,
                                  InpMaxLayers,
                                  InpLots,
                                  g_geo_exit_short,
                                  g_geo_add_short);
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
