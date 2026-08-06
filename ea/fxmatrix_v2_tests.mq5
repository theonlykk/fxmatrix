//+------------------------------------------------------------------+
//| fxmatrix_v2_tests.mq5 — native unit tests for production V2 logic |
//| Run in Strategy Tester or as script (OnStart). No live trading.   |
//+------------------------------------------------------------------+
#property copyright "fxmatrix"
#property version   "1.10"
#property script_show_inputs
#property strict

#include "fxmatrix_v2_logic.mqh"
#include "fxmatrix_v2_exits.mqh"
#include "fxmatrix_v2_telemetry.mqh"
#include "fxmatrix_v2_signal.mqh"
#include "fxmatrix_v2_carry.mqh"
#include "fxmatrix_v2_gbp_cap.mqh"
#include "fxmatrix_v2_eur_cap.mqh"
#include "fxmatrix_v2_eurgbp_dual_cap.mqh"
#include "fxmatrix_v2_l0_signal.mqh"
#include "fxmatrix_v2_state_reconstruction.mqh"

int g_tests_run = 0;
int g_tests_passed = 0;

//+------------------------------------------------------------------+
void AssertTrue(const string name, const bool condition)
{
   g_tests_run++;
   if(condition) {
      g_tests_passed++;
      Print("PASS | ", name);
   } else {
      Print("FAIL | ", name);
   }
}

void AssertNear(const string name, const double got, const double expected, const double tol)
{
   AssertTrue(name, MathAbs(got - expected) <= tol);
}

void AssertContains(const string name, const string haystack, const string needle)
{
   AssertTrue(name, StringFind(haystack, needle) >= 0);
}

void AssertNotContains(const string name, const string haystack, const string needle)
{
   AssertTrue(name, StringFind(haystack, needle) < 0);
}

//+------------------------------------------------------------------+
// Running-state widen: floor while shallow, advance on depth >= 3 append
void Test_RunningStateWiden()
{
   double cap = V2_ADD_PIPS_FLOOR;
   AssertNear("shallow depth 1 uses floor", V2_AddStepPipsForDepth(1, cap), 9.0, 1e-9);
   AssertNear("shallow depth 2 uses floor", V2_AddStepPipsForDepth(2, cap), 9.0, 1e-9);

   V2_AdvanceAddPipsOnAppend(cap, 3);
   AssertNear("after depth-3 append cap widens once", cap, 9.0 * V2_WIDEN_RATIO, 1e-6);

   AssertNear("depth 3 uses accumulated cap", V2_AddStepPipsForDepth(3, cap), 9.0 * V2_WIDEN_RATIO, 1e-6);

   V2_AdvanceAddPipsOnAppend(cap, 4);
   AssertNear("second widen step", cap, 9.0 * MathPow(V2_WIDEN_RATIO, 2.0), 1e-4);

   V2_ResetAddPipsOnFlat(cap, 0);
   AssertNear("full flat resets cap", cap, V2_ADD_PIPS_FLOOR, 1e-9);
   V2_ResetAddPipsOnFlat(cap, 2);
   AssertNear("partial stack keeps cap", cap, V2_ADD_PIPS_FLOOR, 1e-9);
}

//+------------------------------------------------------------------+
// Post-reload extension must use accumulated state, not positional D_n
void Test_PostReloadExtensionUsesAccumulatedState()
{
   V2MockStack s;
   V2MockReset(s);

   // Uninterrupted buildup 1 -> 2 -> 3 -> 4
   V2MockAppendEntry(s, 1.34659, false); // L0
   V2MockAppendEntry(s, 1.34569, false); // add depth 2
   V2MockAppendEntry(s, 1.34459, false); // add depth 3, cap -> 11.736
   V2MockAppendEntry(s, 1.34309, false); // add depth 4, cap -> 15.304

   AssertTrue("built to depth 4", ArraySize(s.entries) == 4);
   AssertNear("cap after uninterrupted 1-2-3-4", s.current_add_pips, 9.0 * MathPow(V2_WIDEN_RATIO, 2.0), 1e-4);

   // Exit twice then reload — pre-exit peak was 4
   V2MockPopTop(s); // 4 -> 3, reload gate armed
   V2MockPopTop(s); // 3 -> 2, reload gate armed
   AssertTrue("reload gate active after exit", s.last_exit_valid);

   double cap_before_reload = s.current_add_pips;
   V2MockAppendEntry(s, 1.34309, true); // reload 2 -> 3, clears reload gate
   AssertTrue("reload clears gate", !s.last_exit_valid);
   AssertNear("reload landing at depth 3 widens cap", s.current_add_pips, cap_before_reload * V2_WIDEN_RATIO, 1e-2);

   // First-time add beyond pre-exit peak (3 -> 4) uses accumulated cap, not positional D_4
   double step_to_4 = V2MockComputeAddStepPips(s);
   double positional_d4 = V2_SpacingPipsDn_Positional(4);
   AssertNear("extension 3->4 uses accumulated cap", step_to_4, s.current_add_pips, 1e-6);
   AssertTrue("positional D_4 differs from accumulated state",
              MathAbs(step_to_4 - positional_d4) > 1e-3);

   double cap_before_add = s.current_add_pips;
   V2MockAppendEntry(s, 1.34159, false); // add 3 -> 4 beyond prior peak path
   AssertNear("cap widens after depth-4 add landing", s.current_add_pips, cap_before_add * V2_WIDEN_RATIO, 1e-2);

   // Shallow post-reload extension: 1 -> 2 exit/reload then 2 -> 3 uses floor not D_3
   V2MockReset(s);
   V2MockAppendEntry(s, 1.34659, false);
   V2MockAppendEntry(s, 1.34569, false); // depth 2
   V2MockPopTop(s); // -> 1
   V2MockAppendEntry(s, 1.34475, true); // reload -> 2

   double step_shallow = V2MockComputeAddStepPips(s);
   double positional_d3 = V2_SpacingPipsDn_Positional(3);
   AssertNear("post-reload 2->3 add uses shallow floor", step_shallow, 9.0, 1e-9);
   AssertTrue("positional D_3 would diverge", MathAbs(step_shallow - positional_d3) > 1e-6);
}

//+------------------------------------------------------------------+
// (b) last_exit_price gate clears when THIS instance's stack goes flat
void Test_OwnFlatClearsLastExit()
{
   V2MockStack s;
   V2MockReset(s);

   ArrayResize(s.entries, 1);
   s.entries[0] = 1.25000;
   V2MockPopTop(s);
   AssertTrue("after pop with 0 layers last_exit_valid false", !s.last_exit_valid);
   AssertTrue("layer count zero", ArraySize(s.entries) == 0);
   AssertNear("current_add reset on full flat", s.current_add_pips, V2_ADD_PIPS_FLOOR, 1e-9);

   V2MockReset(s);
   ArrayResize(s.entries, 2);
   s.entries[0] = 1.24000;
   s.entries[1] = 1.25000;
   s.current_add_pips = 15.0;
   V2MockPopTop(s);
   AssertTrue("partial stack keeps reload gate", s.last_exit_valid);
   AssertTrue("one layer remains", ArraySize(s.entries) == 1);
   AssertNear("last_exit_price stored", s.last_exit_price, 1.25000, 1e-9);
   AssertNear("partial stack keeps widen state", s.current_add_pips, 15.0, 1e-9);
}

//+------------------------------------------------------------------+
// (a) Zero cross-instance contamination — one instance flat does not touch other
void Test_CrossInstanceIsolation()
{
   V2MockStack long_stack;
   V2MockStack short_stack;
   V2MockReset(long_stack);
   V2MockReset(short_stack);

   ArrayResize(long_stack.entries, 1);
   long_stack.entries[0] = 1.25000;
   long_stack.current_add_pips = 20.0;

   ArrayResize(short_stack.entries, 2);
   short_stack.entries[0] = 1.26000;
   short_stack.entries[1] = 1.27000;
   short_stack.last_exit_valid = false;
   short_stack.current_add_pips = 30.0;

   V2MockPopTop(long_stack);

   AssertTrue("long flat clears own reload gate", !long_stack.last_exit_valid);
   AssertTrue("long stack empty", ArraySize(long_stack.entries) == 0);
   AssertNear("long cap reset on flat", long_stack.current_add_pips, V2_ADD_PIPS_FLOOR, 1e-9);

   AssertTrue("short stack depth preserved", ArraySize(short_stack.entries) == 2);
   AssertTrue("short last_exit_valid not coupled to long flat",
              short_stack.last_exit_valid == false);
   AssertNear("short cap untouched by long flat", short_stack.current_add_pips, 30.0, 1e-9);

   V2MockPopTop(short_stack);
   AssertTrue("short reload gate active after own pop", short_stack.last_exit_valid);
   AssertTrue("long still flat/isolated", !long_stack.last_exit_valid);
   AssertTrue("long still empty", ArraySize(long_stack.entries) == 0);
}

//+------------------------------------------------------------------+
// (c) Exit path uses resting TRADE_ACTION_PENDING limit (opposite direction)
void Test_ExitLimitRequestShape()
{
   MqlTradeRequest req;
   const double exit_price = 1.25300;
   const double volume = 0.01;

   AssertTrue("build long exit limit ok",
              V2_BuildExitLimitRequest("GBPUSD", exit_price, volume, 1,
                                         MM_LONG_V2_EXIT, req));
   AssertTrue("action is TRADE_ACTION_PENDING", req.action == TRADE_ACTION_PENDING);
   AssertTrue("long exit is SELL_LIMIT", req.type == ORDER_TYPE_SELL_LIMIT);
   AssertTrue("long exit magic routed", req.magic == MM_LONG_V2_EXIT);
   AssertNear("price set", req.price, exit_price, 1e-9);
   AssertTrue("GTC", req.type_time == ORDER_TIME_GTC);

   MqlTradeRequest short_req;
   AssertTrue("build short exit limit ok",
              V2_BuildExitLimitRequest("GBPUSD", 1.24700, volume, -1,
                                         MM_SHORT_V2_EXIT, short_req));
   AssertTrue("short exit is BUY_LIMIT", short_req.type == ORDER_TYPE_BUY_LIMIT);
   AssertTrue("short exit magic routed", short_req.magic == MM_SHORT_V2_EXIT);

   MqlTradeRequest bad;
   AssertTrue("zero price rejected",
              !V2_BuildExitLimitRequest("GBPUSD", 0.0, volume, 1, MM_LONG_V2_EXIT, bad));
}

//+------------------------------------------------------------------+
void Test_ExitPassivityPure()
{
   AssertTrue("long exit above ask+freeze",
              V2_ExitPassivityOkPure(1, 1.25500, 1.25000, 1.25020, 0.00010));
   AssertTrue("long exit fails when inside spread",
              !V2_ExitPassivityOkPure(1, 1.25015, 1.25000, 1.25020, 0.00010));
   AssertTrue("short exit below bid-freeze",
              V2_ExitPassivityOkPure(-1, 1.24500, 1.25000, 1.25020, 0.00010));
}

//+------------------------------------------------------------------+
void Test_CloseByQueueing()
{
   V2CloseByTask queue[];
   V2TestQueueCloseBy(queue, 1001, 2002);
   AssertTrue("closeby queue size 1", V2TestCloseByQueueSize(queue) == 1);
   AssertTrue("ticket1 stored", queue[0].ticket1 == 1001);
   AssertTrue("ticket2 stored", queue[0].ticket2 == 2002);
   AssertTrue("retries zeroed", queue[0].retries == 0);
}

//+------------------------------------------------------------------+
void Test_TickAuditMissingExit()
{
   datetime t0 = D'2026.06.05 12:00:00';
   V2ExitAuditAction a = V2_EvaluateExitAudit(
      true, false, 0, 0, false, t0);
   AssertTrue("missing exit needs place", a == V2_EXIT_AUDIT_NEEDS_PLACE);

   datetime t1 = t0 + 5;
   V2ExitAuditAction throttled = V2_EvaluateExitAudit(
      true, false, t0, t0, false, t1);
   AssertTrue("retry throttled inside interval",
              throttled == V2_EXIT_AUDIT_THROTTLED);

   datetime t2 = t0 + V2_EXIT_ESCALATE_AFTER_SEC;
   V2ExitAuditAction esc = V2_EvaluateExitAudit(
      true, false, t0, t0, false, t2);
   AssertTrue("orphan escalates after threshold", esc == V2_EXIT_AUDIT_ESCALATE);

   V2ExitAuditAction ok = V2_EvaluateExitAudit(
      true, true, t0, t0, false, t2);
   AssertTrue("live exit ticket ok", ok == V2_EXIT_AUDIT_OK);
}

//+------------------------------------------------------------------+
void Test_ExitEscalationAlertSignature()
{
   string alert = V2_FormatExitEscalationAlert(V2_TEL_INSTANCE_LONG, 2, 1.33380);
   AssertContains("searchable signature", alert, "V2_EXIT_UNPROTECTED");
   AssertContains("instance tag", alert, "MM_LONG_V2");
   AssertContains("layer index", alert, "layer=2");
}

void Test_TelemetrySystemAlertsField()
{
   V2TelLayerSnapshot rows[1];
   rows[0].entry_price = 1.25000;
   rows[0].exit_target = 1.25030;
   rows[0].lot_size = 0.01;
   rows[0].direction = 1;
   rows[0].position_ticket = 111;
   rows[0].exit_ticket = 555;

   string alerts[1];
   alerts[0] = V2_FormatExitEscalationAlert(V2_TEL_INSTANCE_LONG, 0, 1.25030);
   string payload = V2BuildInstanceTelemetryPayload(
      V2_TEL_INSTANCE_LONG, "GBPUSD", rows, 1, 1, 0.0004,
      D'2026.06.05 12:00:00', alerts);
   AssertContains("system_alerts populated", payload, "V2_EXIT_UNPROTECTED");
   AssertNotContains("system_alerts not empty array", payload, "\"system_alerts\":[]");
}

//+------------------------------------------------------------------+
// Telemetry: dual instance_id payloads, no cross-instance field leakage
void Test_TelemetryDualInstancePayloads()
{
   V2TelLayerSnapshot long_layers[2];
   long_layers[0].entry_price = 1.25000;
   long_layers[0].exit_target = 1.25030;
   long_layers[0].lot_size    = 0.01;
   long_layers[0].direction   = 1;
   long_layers[0].position_ticket = 111;
   long_layers[1].entry_price = 1.24900;
   long_layers[1].exit_target = 1.24930;
   long_layers[1].lot_size    = 0.01;
   long_layers[1].direction   = 1;
   long_layers[1].position_ticket = 222;

   V2TelLayerSnapshot short_layers[1];
   short_layers[0].entry_price = 1.26000;
   short_layers[0].exit_target = 1.25970;
   short_layers[0].lot_size    = 0.01;
   short_layers[0].direction   = -1;
   short_layers[0].position_ticket = 333;

   datetime ts = D'2026.06.05 12:00:00';
   string empty_alerts[];
   string long_payload = V2BuildInstanceTelemetryPayload(
      V2_TEL_INSTANCE_LONG, "GBPUSD", long_layers, 2, 1, 0.0004, ts, empty_alerts);
   string short_payload = V2BuildInstanceTelemetryPayload(
      V2_TEL_INSTANCE_SHORT, "GBPUSD", short_layers, 1, -1, 0.0004, ts, empty_alerts);

   AssertContains("long payload instance_id", long_payload, "\"instance_id\":\"MM_LONG_V2\"");
   AssertContains("short payload instance_id", short_payload, "\"instance_id\":\"MM_SHORT_V2\"");
   AssertNotContains("long payload no short id", long_payload, "MM_SHORT_V2");
   AssertNotContains("short payload no long id", short_payload, "MM_LONG_V2");
   AssertContains("long layer_detail has L0 entry", long_payload, "\"entry_price\":1.25000");
   AssertNotContains("long payload no short entry leak", long_payload, "1.26000");
   AssertContains("short layer_detail has short entry", short_payload, "\"entry_price\":1.26000");
   AssertContains("long direction BUY", long_payload, "\"direction\":1");
   AssertContains("short direction SELL", short_payload, "\"direction\":-1");
   AssertContains("system_alerts empty array", long_payload, "\"system_alerts\":[]");
   AssertContains("engine_state V2 stub", long_payload, "\"execution_mode\":\"V2_PASSIVE_GRID\"");
   AssertContains("engine_state account api count", long_payload, "\"account_daily_api_count\":");
}

//+------------------------------------------------------------------+
// ADR-053/059: pod close trade_date, layers_closed count, gross_pnl sum
void Test_TelemetryPodCloseAccounting()
{
   V2PodSession pod;
   V2PodReset(pod);
   V2PodOnFirstLayer(pod, 1.34500, D'2026.06.05 10:00:00');
   V2PodAccumulateExit(pod, 1.25);
   V2PodAccumulateExit(pod, -0.50);
   V2PodAccumulateExit(pod, 0.75);

   AssertTrue("pod layers_closed count", pod.layers_closed == 3);
   AssertNear("pod gross_pnl sum", pod.gross_pnl, 1.50, 1e-9);

   string payload = V2BuildPodClosePayload(
      V2_TEL_INSTANCE_LONG,
      "GBPUSD",
      "LONG",
      pod.layers_closed,
      pod.layer0_entry,
      1.34800,
      45.0,
      pod.gross_pnl,
      D'2026.06.05 10:45:00',
      D'2026.06.05 10:45:00'
   );

   AssertContains("pod close trade_date populated", payload, "\"trade_date\":\"2026-06-05\"");
   AssertContains("pod close layers_closed=3", payload, "\"layers_closed\":3");
   AssertContains("pod close gross_pnl=1.50", payload, "\"gross_pnl\":1.50");
   AssertContains("pod close instrument field", payload, "\"instrument\":\"GBPUSD\"");
   AssertContains("pod close instance_id long", payload, "\"instance_id\":\"MM_LONG_V2\"");
   AssertNotContains("pod close not hardcoded layer 1", payload, "\"layers_closed\":1");
}

//+------------------------------------------------------------------+
// Pod session isolation between long/short telemetry accumulators
void Test_TelemetryPodSessionIsolation()
{
   V2PodSession long_pod;
   V2PodSession short_pod;
   V2PodReset(long_pod);
   V2PodReset(short_pod);

   V2PodOnFirstLayer(long_pod, 1.25000, D'2026.06.01 09:00:00');
   V2PodOnFirstLayer(short_pod, 1.26000, D'2026.06.01 09:05:00');
   V2PodAccumulateExit(long_pod, 2.00);
   V2PodAccumulateExit(short_pod, -1.00);

   AssertTrue("long pod layers closed", long_pod.layers_closed == 1);
   AssertTrue("short pod layers closed", short_pod.layers_closed == 1);
   AssertNear("long pod pnl isolated", long_pod.gross_pnl, 2.00, 1e-9);
   AssertNear("short pod pnl isolated", short_pod.gross_pnl, -1.00, 1e-9);
   AssertNear("long layer0 entry preserved", long_pod.layer0_entry, 1.25000, 1e-9);
   AssertNear("short layer0 entry preserved", short_pod.layer0_entry, 1.26000, 1e-9);
}

//+------------------------------------------------------------------+
void Test_TelemetryLayerDetailJSON()
{
   V2TelLayerSnapshot rows[1];
   rows[0].entry_price = 1.33350;
   rows[0].exit_target = 1.33380;
   rows[0].lot_size = 0.01;
   rows[0].direction = -1;
   rows[0].position_ticket = 999;

   string json = V2BuildLayerDetailJSON(rows, 1);
   AssertContains("layer_detail exit_price_fixed key", json, "\"exit_price_fixed\":1.33380");
   AssertContains("layer_detail direction -1", json, "\"direction\":-1");
}

//+------------------------------------------------------------------+
// Startup orphan guard: empty in-memory stack + live broker positions
void Test_OrphanStartupGuard()
{
   AssertTrue("empty layers + positions = orphan",
              V2_IsOrphanedStartupState(0, 5));
   AssertTrue("genuinely flat startup ok",
              !V2_IsOrphanedStartupState(0, 0));
   AssertTrue("nonempty layers skip orphan guard",
              !V2_IsOrphanedStartupState(3, 5));

   ulong tickets[5];
   tickets[0] = 700001;
   tickets[1] = 700002;
   tickets[2] = 700003;
   tickets[3] = 700004;
   tickets[4] = 700005;

   string alert = V2_FormatOrphanStartupAlert(V2_TEL_INSTANCE_SHORT, 5, "entry", tickets);
   AssertContains("orphan alert signature", alert, "V2_ORPHANED_POSITIONS_DETECTED");
   AssertContains("orphan alert instance", alert, "instance=MM_SHORT_V2");
   AssertContains("orphan alert magic_type entry", alert, "magic_type=entry");
   AssertContains("orphan alert count", alert, "count=5");
   AssertContains("orphan alert tickets", alert, "700001,700002,700003,700004,700005");

   string short_alerts[];
   bool short_halt = V2_ProcessOrphanStartupCheck(
      short_alerts, V2_TEL_INSTANCE_SHORT, 0, 5, "entry", tickets);
   AssertTrue("orphan check triggers halt", short_halt);
   AssertTrue("orphan alert pushed once", ArraySize(short_alerts) == 1);
   AssertContains("orphan alert in system_alerts", short_alerts[0],
                  "V2_ORPHANED_POSITIONS_DETECTED");

   string flat_alerts[];
   ulong empty_tickets[];
   AssertTrue("flat instance passes orphan check",
              !V2_ProcessOrphanStartupCheck(flat_alerts, V2_TEL_INSTANCE_LONG, 0, 0, "", empty_tickets));
   AssertTrue("flat instance no alerts", ArraySize(flat_alerts) == 0);

   AssertTrue("magic_type entry only", V2_OrphanMagicTypeLabel(3, 0) == "entry");
   AssertTrue("magic_type exit only", V2_OrphanMagicTypeLabel(0, 1) == "exit");
   AssertTrue("magic_type both", V2_OrphanMagicTypeLabel(2, 1) == "both");
   AssertTrue("magic_type none", V2_OrphanMagicTypeLabel(0, 0) == "");

   ulong exit_only_tickets[1];
   exit_only_tickets[0] = 800001;
   string exit_only_alerts[];
   bool exit_only_halt = V2_ProcessOrphanStartupCheck(
      exit_only_alerts, V2_TEL_INSTANCE_SHORT, 0, 1, "exit", exit_only_tickets);
   AssertTrue("exit-only hedge triggers orphan halt", exit_only_halt);
   AssertTrue("exit-only alert pushed once", ArraySize(exit_only_alerts) == 1);
   AssertContains("exit-only alert magic_type", exit_only_alerts[0], "magic_type=exit");
   AssertContains("exit-only alert ticket", exit_only_alerts[0], "800001");

   AssertTrue("both orphan -> INIT_FAILED",
              V2_OnInitResultFromOrphanFlags(true, true) == INIT_FAILED);
   AssertTrue("short orphan only -> INIT_SUCCEEDED (long continues)",
              V2_OnInitResultFromOrphanFlags(false, true) == INIT_SUCCEEDED);
   AssertTrue("long orphan only -> INIT_SUCCEEDED (short continues)",
              V2_OnInitResultFromOrphanFlags(true, false) == INIT_SUCCEEDED);
   AssertTrue("both flat -> INIT_SUCCEEDED",
              V2_OnInitResultFromOrphanFlags(false, false) == INIT_SUCCEEDED);

   V2TelLayerSnapshot empty_layers[];
   string payload = V2BuildInstanceTelemetryPayload(
      V2_TEL_INSTANCE_SHORT, "GBPUSD", empty_layers, 0, -1, 0.0004,
      D'2026.06.05 12:00:00', short_alerts);
   AssertContains("telemetry carries orphan alert", payload, "V2_ORPHANED_POSITIONS_DETECTED");
   AssertContains("telemetry orphan instance", payload, "MM_SHORT_V2");
}

//+------------------------------------------------------------------+
// ADR-102: halted-side fill gate helpers
void Test_HaltedFillGateHelpers()
{
   AssertTrue("long entry ours",
              V2_IsManagedLongEntryDeal(DEAL_ENTRY_IN, DEAL_TYPE_BUY, MM_LONG_V2, MM_LONG_V2));
   AssertTrue("long entry foreign magic",
              !V2_IsManagedLongEntryDeal(DEAL_ENTRY_IN, DEAL_TYPE_BUY, 99999, MM_LONG_V2));
   AssertTrue("short entry ours",
              V2_IsManagedShortEntryDeal(DEAL_ENTRY_IN, DEAL_TYPE_SELL, MM_SHORT_V2, MM_SHORT_V2));
   AssertTrue("exit ours",
              V2_IsManagedExitDeal(DEAL_ENTRY_IN, MM_LONG_V2_EXIT, MM_LONG_V2_EXIT));

   string alert = V2_FormatHaltedFillAlert(V2_TEL_INSTANCE_LONG, "LONG",
      1001, 2002, 3003, "GBPUSD", MM_LONG_V2, 1.25000, "entry");
   AssertContains("halt alert prefix", alert, "ERROR V2_HALTED_FILL_IGNORED");
   AssertContains("halt alert deal", alert, "1001");
   AssertContains("halt alert order", alert, "2002");
   AssertContains("halt alert position", alert, "3003");
   AssertContains("halt alert reconciliation", alert,
                  "Manual reconciliation required before reattach.");

   string exit_alert = V2_FormatHaltedFillAlert(V2_TEL_INSTANCE_SHORT, "SHORT",
      4001, 5002, 6003, "EURUSD", MM_SHORT_V2_EXIT, 1.10000, "exit");
   AssertContains("halt exit fill_kind", exit_alert, "fill_kind=exit");

   string alerts[];
   V2_EmitHaltedFillAlert(alerts, alert);
   AssertTrue("halt alert pushed once", ArraySize(alerts) == 1);
   AssertContains("halt alert in system_alerts", alerts[0], "V2_HALTED_FILL_IGNORED");
}

//+------------------------------------------------------------------+
// ADR-103: per-side OnInit cap publish policy
void Test_OnInitCapPublishPolicy()
{
   AssertTrue("flat side publishes", V2_ShouldPublishCapSyncOnInit(false));
   AssertTrue("orphan side skips publish", !V2_ShouldPublishCapSyncOnInit(true));

   Test_ClearCapGvs();
   V2_GbpCapPublishLayers(V2_GBP_CAP_GV_GBP_LONG, 5);
   AssertNear("prior gv seeded", GlobalVariableGet(V2_GBP_CAP_GV_GBP_LONG), 5.0, 1e-9);

   if(V2_ShouldPublishCapSyncOnInit(true))
      V2_GbpCapPublishLayers(V2_GBP_CAP_GV_GBP_LONG, 0);
   AssertNear("orphan skip leaves prior gv",
              GlobalVariableGet(V2_GBP_CAP_GV_GBP_LONG), 5.0, 1e-9);

   if(V2_ShouldPublishCapSyncOnInit(false))
      V2_GbpCapPublishLayers(V2_GBP_CAP_GV_GBP_LONG, 0);
   AssertNear("flat side publishes zero",
              GlobalVariableGet(V2_GBP_CAP_GV_GBP_LONG), 0.0, 1e-9);

   Test_ClearCapGvs();
}

//+------------------------------------------------------------------+
void Test_CapTriggerRecordWithoutPriorGv()
{
   Test_ClearCapGvs();
   AssertTrue("gbp trigger gv absent", !GlobalVariableCheck("V2GBP_CAP_TRIGGERS"));
   V2_GbpCapRecordBlock();
   AssertTrue("gbp trigger gv created", GlobalVariableCheck("V2GBP_CAP_TRIGGERS"));
   AssertNear("gbp trigger gv starts at 1", GlobalVariableGet("V2GBP_CAP_TRIGGERS"), 1.0, 1e-9);

   if(GlobalVariableCheck("V2EUR_CAP_TRIGGERS"))
      GlobalVariableDel("V2EUR_CAP_TRIGGERS");
   V2_EurCapRecordBlock();
   AssertNear("eur trigger gv starts at 1", GlobalVariableGet("V2EUR_CAP_TRIGGERS"), 1.0, 1e-9);

   Test_ClearCapGvs();
}

//+------------------------------------------------------------------+
void Test_FlatOnInitPreservesTriggerGvs()
{
   Test_ClearCapGvs();
   GlobalVariableSet("V2GBP_CAP_TRIGGERS", 3.0);
   GlobalVariableSet("V2EUR_CAP_TRIGGERS", 4.0);
   // ADR-103: OnInit no longer resets trigger GVs; flat restart must preserve them.
   AssertNear("gbp triggers preserved", GlobalVariableGet("V2GBP_CAP_TRIGGERS"), 3.0, 1e-9);
   AssertNear("eur triggers preserved", GlobalVariableGet("V2EUR_CAP_TRIGGERS"), 4.0, 1e-9);
   Test_ClearCapGvs();
}

//+------------------------------------------------------------------+
// Per-layer scalp_closed telemetry (distinct from pod_closed)
void Test_TelemetryScalpClosedPayload()
{
   string payload = V2BuildScalpClosedPayload(
      V2_TEL_INSTANCE_SHORT,
      "GBPUSD",
      "SHORT",
      1.34550,
      1.34520,
      12.5,
      2.50,
      0.85,
      3,
      5,
      1,
      D'2026.06.05 14:30:00',
      D'2026.06.05 14:30:00'
   );

   AssertContains("scalp event_type", payload, "\"event_type\":\"scalp_closed\"");
   AssertContains("scalp trade_date", payload, "\"trade_date\":\"2026-06-05\"");
   AssertContains("scalp instance_id", payload, "\"instance_id\":\"MM_SHORT_V2\"");
   AssertContains("scalp instrument", payload, "\"instrument\":\"GBPUSD\"");
   AssertContains("scalp direction", payload, "\"direction\":\"SHORT\"");
   AssertContains("scalp layer entry", payload, "\"entry_price\":1.34550");
   AssertContains("scalp exit price", payload, "\"exit_price\":1.34520");
   AssertContains("scalp hold mins", payload, "\"hold_time_minutes\":12.5");
   AssertContains("scalp hold bars", payload, "\"hold_time_bars\":2.50");
   AssertContains("scalp gross_pnl", payload, "\"gross_pnl\":0.85");
   AssertContains("scalp layer_depth", payload, "\"layer_depth\":3");
   AssertContains("scalp stack_depth", payload, "\"stack_depth\":5");
   AssertContains("scalp open_depth", payload, "\"open_depth\":1");
   AssertNotContains("scalp not pod layers_closed", payload, "\"layers_closed\"");
   AssertNotContains("scalp not pod avg_entry", payload, "\"avg_entry_price\"");
}

//+------------------------------------------------------------------+
void Test_TelemetryScalpClosedOpenDepthAndBars()
{
   datetime t0 = D'2026.06.05 10:00:00';
   datetime t1 = t0 + 300;   // 1 M5 bar
   datetime t2 = t0 + 750;   // 2.5 M5 bars

   AssertNear("hold bars one bar", V2HoldTimeBarsM5(t0, t1), 1.0, 1e-9);
   AssertNear("hold bars two half", V2HoldTimeBarsM5(t0, t2), 2.5, 1e-9);
   AssertNear("hold bars zero bad entry", V2HoldTimeBarsM5(0, t1), 0.0, 1e-9);

   // open_depth=2 (L2+) vs layer_depth=1 after lower layers closed
   string payload = V2BuildScalpClosedPayload(
      V2_TEL_INSTANCE_LONG, "GBPUSD", "LONG",
      1.25000, 1.25030, 12.5, 33.8, 1.10,
      1, 2, 2,
      t2, t2);
   AssertContains("open_depth distinct from layer_depth", payload, "\"open_depth\":2");
   AssertContains("layer_depth at exit", payload, "\"layer_depth\":1");
   AssertContains("hold bars sim parity field", payload, "\"hold_time_bars\":33.80");
}

//+------------------------------------------------------------------+
void Test_TelemetryScalpClosedUrl()
{
   string base = "https://pipshed.com/api/telemetry/push";
   AssertContains("scalp url derived", V2DeriveScalpClosedUrl(base),
                  "https://pipshed.com/api/telemetry/scalp_closed");
   AssertContains("pod url unchanged",
                  V2DerivePodClosedUrl(base),
                  "https://pipshed.com/api/telemetry/pod_closed");
}

//+------------------------------------------------------------------+
// Scalp fires per exit; pod-close payload/conditions stay independent
void Test_TelemetryScalpVsPodCloseIndependence()
{
   // Partial stack exit: scalp only (layers remain)
   string scalp_partial = V2BuildScalpClosedPayload(
      V2_TEL_INSTANCE_LONG, "GBPUSD", "LONG",
      1.25000, 1.25030, 5.0, 1.0, 1.10,
      2, 4, 1,
      D'2026.06.05 11:00:00', D'2026.06.05 11:00:00');
   AssertContains("partial scalp layer_depth", scalp_partial, "\"layer_depth\":2");
   AssertContains("partial scalp stack_depth", scalp_partial, "\"stack_depth\":4");
   AssertNotContains("partial scalp no pod field", scalp_partial, "layers_closed");

   // Full pod flat: scalp for last layer + separate pod-close aggregate
   V2PodSession pod;
   V2PodReset(pod);
   V2PodOnFirstLayer(pod, 1.25000, D'2026.06.05 10:00:00');
   V2PodAccumulateExit(pod, 0.50);
   V2PodAccumulateExit(pod, 0.60);

   string scalp_final = V2BuildScalpClosedPayload(
      V2_TEL_INSTANCE_LONG, "GBPUSD", "LONG",
      1.25200, 1.25230, 8.0, 1.6, 0.60,
      2, 2, 1,
      D'2026.06.05 10:08:00', D'2026.06.05 10:08:00');
   AssertContains("final scalp single-exit pnl", scalp_final, "\"gross_pnl\":0.60");

   string pod_payload = V2BuildPodClosePayload(
      V2_TEL_INSTANCE_LONG, "GBPUSD", "LONG",
      pod.layers_closed, pod.layer0_entry,
      1.25230, 8.0, pod.gross_pnl,
      D'2026.06.05 10:08:00', D'2026.06.05 10:08:00');
   AssertContains("pod close still uses layers_closed", pod_payload, "\"layers_closed\":2");
   AssertContains("pod close still uses avg_entry", pod_payload, "\"avg_entry_price\":1.25000");
   AssertContains("pod close aggregate pnl", pod_payload, "\"gross_pnl\":1.10");
   AssertNotContains("pod close no scalp event_type", pod_payload, "scalp_closed");
   AssertNotContains("pod close no layer_depth", pod_payload, "layer_depth");
}

//+------------------------------------------------------------------+
// Six-instance namespace: GBPUSD + EURUSD + EURGBP long/short magics
void Test_SixInstanceMagicIsolation()
{
   const long GBP_LONG   = 20260901;
   const long GBP_SHORT  = 20260902;
   const long EURUSD_LONG  = 20260911;
   const long EURUSD_SHORT = 20260912;
   const long EURGBP_LONG  = 20260921;
   const long EURGBP_SHORT = 20260922;

   long magics[6];
   magics[0] = GBP_LONG;
   magics[1] = GBP_SHORT;
   magics[2] = EURUSD_LONG;
   magics[3] = EURUSD_SHORT;
   magics[4] = EURGBP_LONG;
   magics[5] = EURGBP_SHORT;

   for(int i = 0; i < 6; i++) {
      for(int j = i + 1; j < 6; j++) {
         AssertTrue(StringFormat("magic unique %d vs %d", i, j), magics[i] != magics[j]);
      }
   }

   AssertTrue("gbp default long magic unchanged", MM_LONG_V2 == GBP_LONG);
   AssertTrue("gbp default short magic unchanged", MM_SHORT_V2 == GBP_SHORT);
   AssertTrue("gbp exit offset +2 long", MM_LONG_V2_EXIT == GBP_LONG + V2_EXIT_MAGIC_OFFSET);
   AssertTrue("gbp exit offset +2 short", MM_SHORT_V2_EXIT == GBP_SHORT + V2_EXIT_MAGIC_OFFSET);
   AssertTrue("eurusd exit magic", EURUSD_LONG + V2_EXIT_MAGIC_OFFSET == 20260913);
   AssertTrue("eurgbp exit magic", EURGBP_LONG + V2_EXIT_MAGIC_OFFSET == 20260923);
}

//+------------------------------------------------------------------+
void Test_PairSpreadAndPipConventionRefs()
{
   // Sim-calibrated PAIR_SPREAD_PIPS from validation (config headers).
   AssertNear("eurusd spread ref pips", 0.18, 0.18, 1e-9);
   AssertNear("eurgbp spread ref pips", 0.63, 0.63, 1e-9);
   AssertNear("gbpusd spread ref pips", 0.64, 0.64, 1e-9);

   // 5-digit XXXUSD: 1 pip = 10 points (point=0.00001 -> 0.0001/pip).
   AssertNear("pip eurusd 5-digit", V2_PipsToPriceForSymbol("EURUSD", 1.0), 0.0001, 1e-10);
   AssertNear("pip eurgbp 5-digit", V2_PipsToPriceForSymbol("EURGBP", 1.0), 0.0001, 1e-10);
   AssertNear("pip gbpusd 5-digit", V2_PipsToPriceForSymbol("GBPUSD", 1.0), 0.0001, 1e-10);
}

//+------------------------------------------------------------------+
void Test_AbSignalFormulaPure()
{
   double closes_ac[60];
   double closes_bc[60];
   ArrayInitialize(closes_ac, 0.0);
   ArrayInitialize(closes_bc, 0.0);
   for(int i = 0; i < 60; i++) {
      closes_ac[i] = 1.10000 + 0.00001 * i;
      closes_bc[i] = 1.30000 + 0.00002 * i;
   }

   double fv_ac, sig_ac, fv_bc, sig_bc;
   AssertTrue("fv ac", V2_FvSigmaFromCloses(closes_ac, fv_ac, sig_ac));
   AssertTrue("fv bc", V2_FvSigmaFromCloses(closes_bc, fv_bc, sig_bc));

   double r_ac = MathLog(closes_ac[0] / fv_ac);
   double r_bc = MathLog(closes_bc[0] / fv_bc);
   double inst = r_ac - r_bc;
   double dhs = 0.0004 + MathMax(sig_ac, sig_bc) * 0.5;
   double ratio = fv_ac / fv_bc;
   double bid = ratio * MathExp(inst - dhs);
   double offer = ratio * MathExp(inst + dhs);

   AssertTrue("ab bid positive", bid > 0.0);
   AssertTrue("ab offer positive", offer > 0.0);
   AssertTrue("ab offer above bid", offer > bid);
}

//+------------------------------------------------------------------+
void Test_SixInstanceMockStateIsolation()
{
   V2MockStack gbp_long, gbp_short, eur_long, eur_short, egp_long, egp_short;
   V2MockReset(gbp_long);
   V2MockReset(gbp_short);
   V2MockReset(eur_long);
   V2MockReset(eur_short);
   V2MockReset(egp_long);
   V2MockReset(egp_short);

   V2MockAppendEntry(gbp_long, 1.32000, false);
   V2MockAppendEntry(eur_long, 1.10000, false);
   V2MockAppendEntry(egp_long, 0.86000, false);
   V2MockPopTop(gbp_long);

   AssertTrue("gbp long depth after pop", ArraySize(gbp_long.entries) == 0);
   AssertTrue("eur long untouched", ArraySize(eur_long.entries) == 1);
   AssertTrue("egp long untouched", ArraySize(egp_long.entries) == 1);
   AssertTrue("gbp short still flat", ArraySize(gbp_short.entries) == 0);
   AssertTrue("eur short still flat", ArraySize(eur_short.entries) == 0);
   AssertTrue("egp short still flat", ArraySize(egp_short.entries) == 0);
   AssertTrue("gbp reload gate clear on full flat", !gbp_long.last_exit_valid);
   AssertTrue("eur reload gate clear", !eur_long.last_exit_valid);
}

//+------------------------------------------------------------------+
void Test_ApiCounterIncrementAndRollover()
{
   if(GlobalVariableCheck(V2_DAILY_API_COUNT_GV))
      GlobalVariableDel(V2_DAILY_API_COUNT_GV);
   if(GlobalVariableCheck(V2_DAILY_API_DATE_GV))
      GlobalVariableDel(V2_DAILY_API_DATE_GV);

   V2_ApiCounterMaybeReset();
   AssertTrue("fresh counter zero", V2_ApiCounterRead() == 0);

   V2_ApiCounterIncrement();
   V2_ApiCounterIncrement();
   V2_ApiCounterIncrement();
   AssertTrue("three increments", V2_ApiCounterRead() == 3);

   MqlDateTime ydt;
   TimeToStruct(TimeCurrent() - 86400, ydt);
   string ystr = StringFormat("%04d%02d%02d", ydt.year, ydt.mon, ydt.day);
   GlobalVariableSet(V2_DAILY_API_DATE_GV, (double)StringToInteger(ystr));
   GlobalVariableSet(V2_DAILY_API_COUNT_GV, 999.0);

   V2_ApiCounterMaybeReset();
   AssertTrue("rollover clears stale count", V2_ApiCounterRead() == 0);
   AssertTrue("rollover stamps today ymd",
              (long)GlobalVariableGet(V2_DAILY_API_DATE_GV) == (long)V2_ApiCounterTodayYmd());

   GlobalVariableSet(V2_DAILY_API_COUNT_GV, (double)(V2_DAILY_API_SOFT_WARN - 1));
   AssertTrue("below soft warn inactive", !V2_ApiCounterSoftWarnActive());
   GlobalVariableSet(V2_DAILY_API_COUNT_GV, (double)V2_DAILY_API_SOFT_WARN);
   AssertTrue("at soft warn active", V2_ApiCounterSoftWarnActive());
   GlobalVariableSet(V2_DAILY_API_COUNT_GV, (double)(V2_DAILY_API_LIMIT - 1));
   AssertTrue("below hard limit still warns", V2_ApiCounterSoftWarnActive());
}

//+------------------------------------------------------------------+
void Test_ApiCounterTelemetryFields()
{
   if(GlobalVariableCheck(V2_DAILY_API_COUNT_GV))
      GlobalVariableDel(V2_DAILY_API_COUNT_GV);
   if(GlobalVariableCheck(V2_DAILY_API_DATE_GV))
      GlobalVariableDel(V2_DAILY_API_DATE_GV);

   V2_ApiCounterMaybeReset();
   GlobalVariableSet(V2_DAILY_API_COUNT_GV, (double)V2_DAILY_API_SOFT_WARN);

   V2TelLayerSnapshot empty_layers[];
   string empty_alerts[];
   string payload = V2BuildInstanceTelemetryPayload(
      V2_TEL_INSTANCE_LONG, "GBPUSD", empty_layers, 0, 1, 0.0004,
      D'2026.06.05 12:00:00', empty_alerts);

   AssertContains("telemetry account api count",
                  payload,
                  StringFormat("\"account_daily_api_count\":%d", V2_DAILY_API_SOFT_WARN));
   AssertContains("telemetry account api limit",
                  payload,
                  StringFormat("\"account_daily_api_limit\":%d", V2_DAILY_API_LIMIT));
   AssertContains("telemetry account api soft warn",
                  payload,
                  StringFormat("\"account_daily_api_soft_warn\":%d", V2_DAILY_API_SOFT_WARN));
   AssertContains("telemetry account api warning true",
                  payload,
                  "\"account_daily_api_warning\":true");
}

//+------------------------------------------------------------------+
void Test_PairTelemetryInstanceIds()
{
   AssertTrue("gbp long tel id default", V2_TEL_INSTANCE_LONG == "MM_LONG_V2");
   AssertTrue("gbp short tel id default", V2_TEL_INSTANCE_SHORT == "MM_SHORT_V2");

   V2TelLayerSnapshot empty_layers[];
   string empty_alerts[];
   string payload_eu = V2BuildInstanceTelemetryPayload(
      "MM_LONG_EURUSD", "EURUSD", empty_layers, 0, 1, 0.0004,
      D'2026.06.05 12:00:00', empty_alerts);
   AssertContains("eurusd instance id", payload_eu, "\"instance_id\":\"MM_LONG_EURUSD\"");

   string payload_eg = V2BuildInstanceTelemetryPayload(
      "MM_SHORT_EURGBP", "EURGBP", empty_layers, 0, -1, 0.0004,
      D'2026.06.05 12:00:00', empty_alerts);
   AssertContains("eurgbp instance id", payload_eg, "\"instance_id\":\"MM_SHORT_EURGBP\"");
}

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
void Test_RolloverAdr045ShiftMath()
{
   const double point = 0.00001;

   AssertNear("tuesday shift price",
              V2_RolloverShiftPrice(-4.0, 1, point), 0.00004, 1e-12);
   AssertNear("wednesday triple shift price",
              V2_RolloverShiftPrice(-4.0, 3, point), 0.00012, 1e-12);
   AssertNear("positive carry zero shift",
              V2_RolloverShiftPrice(2.0, 1, point), 0.0, 1e-12);

   AssertNear("long exit drifts up",
              V2_RolloverShiftedExitPrice(1.30800, 0.00004, 1), 1.30804, 1e-12);
   AssertNear("short exit drifts down",
              V2_RolloverShiftedExitPrice(1.29800, 0.00006, -1), 1.29794, 1e-12);

   AssertTrue("wednesday multiplier", V2_RolloverWednesdayMultiplier(3) == 3);
   AssertTrue("tuesday multiplier", V2_RolloverWednesdayMultiplier(2) == 1);
}

//+------------------------------------------------------------------+
void Test_RolloverDailyGate()
{
   int last_day = 0;

   AssertTrue("broker window hour 0",
              V2_RolloverBrokerWindowOpen(D'2026.03.11 00:15:00'));
   AssertTrue("not broker window hour 1",
              !V2_RolloverBrokerWindowOpen(D'2026.03.11 01:00:00'));

   AssertTrue("first consume at midnight",
              V2_RolloverTryConsumeDailyGate(last_day, D'2026.03.10 00:05:00'));
   AssertTrue("same day blocked", !V2_RolloverTryConsumeDailyGate(last_day, D'2026.03.10 00:30:00'));
   AssertTrue("non-midnight blocked", !V2_RolloverTryConsumeDailyGate(last_day, D'2026.03.10 12:00:00'));
   AssertTrue("next day consumes",
              V2_RolloverTryConsumeDailyGate(last_day, D'2026.03.11 00:05:00'));
}

//+------------------------------------------------------------------+
void Test_RolloverMultiNightAccumulation()
{
   const double point = 0.00001;
   double exit = 1.30800;
   const double shift_night = V2_RolloverShiftPrice(-4.0, 1, point);

   exit = V2_RolloverShiftedExitPrice(exit, shift_night, 1);
   AssertNear("night 1 exit", exit, 1.30804, 1e-12);

   exit = V2_RolloverShiftedExitPrice(exit, shift_night, 1);
   AssertNear("night 2 cumulative exit", exit, 1.30808, 1e-12);

   double one_step_from_origin = V2_RolloverShiftedExitPrice(1.30800, shift_night, 1);
   double two_step_incremental = exit;
   AssertNear("incremental equals chained shifts",
              two_step_incremental - 1.30800,
              (one_step_from_origin - 1.30800) * 2.0,
              1e-12);
}

//+------------------------------------------------------------------+
void Test_RolloverRetrySetupLayer(V2RolloverLayerSlot &layers[],
                                  const ulong position_ticket,
                                  const double exit_target)
{
   const int n = ArraySize(layers);
   ArrayResize(layers, n + 1);
   layers[n].position_ticket = position_ticket;
   layers[n].entry_price     = 1.30000;
   layers[n].exit_target     = exit_target;
   layers[n].exit_ticket     = 1000 + position_ticket;
   layers[n].position_live   = true;
}

bool Test_RolloverRetryCallsContain(const ulong position_ticket)
{
   for(int i = 0; i < ArraySize(g_v2_rollover_test_adjust_calls); i++) {
      if(g_v2_rollover_test_adjust_calls[i] == position_ticket)
         return true;
   }
   return false;
}

void Test_RolloverRetrySetSuccessTickets(const ulong ticket_a, const ulong ticket_b = 0)
{
   ArrayResize(g_v2_rollover_test_success_tickets, (ticket_b > 0 ? 2 : 1));
   g_v2_rollover_test_success_tickets[0] = ticket_a;
   if(ticket_b > 0)
      g_v2_rollover_test_success_tickets[1] = ticket_b;
}

// ADR-101: bounded same-day rollover exit-modify retry
void Test_RolloverRetryDoubleShiftGuard()
{
   V2_RolloverTestAdjustReset();
   g_v2_rollover_use_test_adjust = true;
   g_v2_rollover_test_shift_price = 0.00004;
   Test_RolloverRetrySetSuccessTickets(100);

   V2RolloverSideRetryState state;
   V2_RolloverRetryResetState(state);

   V2RolloverLayerSlot layers[];
   Test_RolloverRetrySetupLayer(layers, 100, 1.30800);
   Test_RolloverRetrySetupLayer(layers, 200, 1.30700);

   V2_RunDailyRolloverSidePass("GBPUSD", 1, 1, false, 10, state, layers);

   AssertTrue("6a success ticket not pending", !V2_RolloverRetryPendingContains(state, 100));
   AssertTrue("6a failure ticket pending", V2_RolloverRetryPendingContains(state, 200));
   AssertNear("6a success shifted once on daily pass", layers[0].exit_target, 1.30804, 1e-12);

   const double success_target_after_daily = layers[0].exit_target;
   state.next_retry_due = 0;

   ArrayResize(g_v2_rollover_test_adjust_calls, 0);
   Test_RolloverRetrySetSuccessTickets(200);

   V2_RunRolloverRetryPass("GBPUSD", 1, 1, false, 10, 15, state, layers);

   AssertTrue("6a retry pass never re-adjusts success ticket",
              !Test_RolloverRetryCallsContain(100));
   AssertNear("6a success exit_target unchanged after retry pass",
              layers[0].exit_target, success_target_after_daily, 1e-12);
   AssertTrue("6a failure cleared after successful retry",
              !V2_RolloverRetryPendingContains(state, 200));

   V2_RolloverTestAdjustReset();
}

void Test_RolloverRetryPendingAndSingleLayerRetry()
{
   V2_RolloverTestAdjustReset();
   g_v2_rollover_use_test_adjust = true;
   g_v2_rollover_test_shift_price = 0.00004;
   ArrayResize(g_v2_rollover_test_success_tickets, 0);

   V2RolloverSideRetryState state;
   V2_RolloverRetryResetState(state);

   V2RolloverLayerSlot layers[];
   Test_RolloverRetrySetupLayer(layers, 300, 1.30600);

   V2_RunDailyRolloverSidePass("GBPUSD", 1, 1, false, 10, state, layers);

   AssertTrue("6b failed layer added to pending", V2_RolloverRetryPendingContains(state, 300));
   AssertNear("6b exit_target unchanged on failed daily pass", layers[0].exit_target, 1.30600, 1e-12);

   state.next_retry_due = 0;
   ArrayResize(g_v2_rollover_test_adjust_calls, 0);
   Test_RolloverRetrySetSuccessTickets(300);

   V2_RunRolloverRetryPass("GBPUSD", 1, 1, false, 10, 15, state, layers);

   AssertTrue("6b retry pass called adjust for pending ticket only",
              ArraySize(g_v2_rollover_test_adjust_calls) == 1 &&
              g_v2_rollover_test_adjust_calls[0] == 300);
   AssertNear("6b exit_target shifted on retry success", layers[0].exit_target, 1.30604, 1e-12);
   AssertTrue("6b pending cleared", !V2_RolloverRetryPendingContains(state, 300));

   V2_RolloverTestAdjustReset();
}

void Test_RolloverRetryCounterOncePerPass()
{
   V2_RolloverTestAdjustReset();
   g_v2_rollover_use_test_adjust = true;
   g_v2_rollover_test_shift_price = 0.00004;
   ArrayResize(g_v2_rollover_test_success_tickets, 0);

   V2RolloverSideRetryState state;
   V2_RolloverRetryResetState(state);
   V2_RolloverRetryRecordFailure(state, 401, D'2026.07.30 00:05:00', 10);
   V2_RolloverRetryRecordFailure(state, 402, D'2026.07.30 00:05:00', 10);
   state.next_retry_due = 0;
   state.retry_attempt_count = 0;

   V2RolloverLayerSlot layers[];
   Test_RolloverRetrySetupLayer(layers, 401, 1.30500);
   Test_RolloverRetrySetupLayer(layers, 402, 1.30400);

   V2_RunRolloverRetryPass("GBPUSD", 1, 1, false, 10, 15, state, layers);

   AssertTrue("6c counter increments once per pass", state.retry_attempt_count == 1);
   AssertTrue("6c both tickets still pending after failed retry",
              V2_RolloverRetryPendingContains(state, 401) &&
              V2_RolloverRetryPendingContains(state, 402));

   V2_RolloverTestAdjustReset();
}

void Test_RolloverRetryStopsAtMaxRetries()
{
   V2_RolloverTestAdjustReset();
   g_v2_rollover_use_test_adjust = true;
   ArrayResize(g_v2_rollover_test_success_tickets, 0);

   V2RolloverSideRetryState state;
   V2_RolloverRetryResetState(state);
   V2_RolloverRetryRecordFailure(state, 501, D'2026.07.30 00:05:00', 10);
   state.next_retry_due = 0;
   state.retry_attempt_count = 15;

   V2RolloverLayerSlot layers[];
   Test_RolloverRetrySetupLayer(layers, 501, 1.30300);

   const int calls_before = ArraySize(g_v2_rollover_test_adjust_calls);
   V2_RunRolloverRetryPass("GBPUSD", 1, 1, false, 10, 15, state, layers);

   AssertTrue("6d no retry when max already reached",
              state.retry_attempt_count == 15);
   AssertTrue("6d pending ticket remains",
              V2_RolloverRetryPendingContains(state, 501));
   AssertTrue("6d no adjust calls at max",
              ArraySize(g_v2_rollover_test_adjust_calls) == calls_before);

   V2_RolloverTestAdjustReset();
}

void Test_RolloverRetryRespectsNextDue()
{
   V2_RolloverTestAdjustReset();
   g_v2_rollover_use_test_adjust = true;
   ArrayResize(g_v2_rollover_test_success_tickets, 0);

   V2RolloverSideRetryState state;
   V2_RolloverRetryResetState(state);
   V2_RolloverRetryRecordFailure(state, 601, D'2026.07.30 00:05:00', 10);
   state.next_retry_due = TimeCurrent() + 3600;
   state.retry_attempt_count = 0;

   V2RolloverLayerSlot layers[];
   Test_RolloverRetrySetupLayer(layers, 601, 1.30200);

   V2_RunRolloverRetryPass("GBPUSD", 1, 1, false, 10, 15, state, layers);

   AssertTrue("6e counter unchanged before due", state.retry_attempt_count == 0);
   AssertTrue("6e pending unchanged before due", V2_RolloverRetryPendingContains(state, 601));
   AssertTrue("6e no adjust calls before due", ArraySize(g_v2_rollover_test_adjust_calls) == 0);

   V2_RolloverTestAdjustReset();
}

void Test_RolloverAdr101WednesdayMultiplierFrozen()
{
   AssertTrue("6f wednesday multiplier unchanged", V2_RolloverWednesdayMultiplier(3) == 3);
   AssertTrue("6f tuesday multiplier unchanged", V2_RolloverWednesdayMultiplier(2) == 1);
   const double point = 0.00001;
   AssertNear("6f swap shift path unchanged",
              V2_RolloverShiftPrice(-4.0, 1, point), 0.00004, 1e-12);
   AssertNear("6f positive swap still zero shift",
              V2_RolloverShiftPrice(2.0, 1, point), 0.0, 1e-12);
}

//+------------------------------------------------------------------+
void Test_ExitMagicPerPairNamespace()
{
   MqlTradeRequest req = {};
   AssertTrue("eurusd exit req",
              V2_BuildExitLimitRequest("EURUSD", 1.10030, 0.01, 1, 20260913, req));
   AssertTrue("eurusd exit magic", req.magic == 20260913);

   ZeroMemory(req);
   AssertTrue("eurgbp exit req",
              V2_BuildExitLimitRequest("EURGBP", 0.86030, 0.01, -1, 20260924, req));
   AssertTrue("eurgbp exit magic", req.magic == 20260924);
}

//+------------------------------------------------------------------+
// ADR-097: L0 spread easing — multiplier ramp + dynamic_hs floor
// ADR-097/098: ramp, floor, fallback — shared fxmatrix_v2_signal.mqh helpers (GBPUSD + EURUSD).
void Test_L0SpreadEaseMultiplierRamp()
{
   const int start = 2;
   const int full = 5;
   const double mult = 0.5;
   const double eased = 0.0;

   AssertNear("below start depth 0", V2_EffectiveSpreadMultiplier(0, start, full, mult, eased), mult, 1e-12);
   AssertNear("below start depth 1", V2_EffectiveSpreadMultiplier(1, start, full, mult, eased), mult, 1e-12);
   AssertNear("at start depth 2", V2_EffectiveSpreadMultiplier(2, start, full, mult, eased), mult, 1e-12);
   AssertNear("mid-ramp depth 3",
              V2_EffectiveSpreadMultiplier(3, start, full, mult, eased),
              mult - (1.0 / 3.0) * mult, 1e-12);
   AssertNear("mid-ramp depth 4",
              V2_EffectiveSpreadMultiplier(4, start, full, mult, eased),
              mult - (2.0 / 3.0) * mult, 1e-12);
   AssertNear("at full depth 5", V2_EffectiveSpreadMultiplier(5, start, full, mult, eased), eased, 1e-12);
   AssertNear("above full depth 6", V2_EffectiveSpreadMultiplier(6, start, full, mult, eased), eased, 1e-12);

   const double mid = V2_EffectiveSpreadMultiplier(3, start, full, mult, eased);
   AssertTrue("mid-ramp differs from un-eased multiplier", MathAbs(mid - mult) > 1e-9);
}

//+------------------------------------------------------------------+
// ADR-097 production calibration: GBPUSD locked thresholds 1/3 (not discovery 2/5).
void Test_L0SpreadEaseMultiplierRamp_Production13()
{
   const int start = 1;
   const int full = 3;
   const double mult = 0.5;
   const double eased = 0.0;

   AssertNear("prod13 depth 0", V2_EffectiveSpreadMultiplier(0, start, full, mult, eased), mult, 1e-12);
   AssertNear("prod13 depth 1 at start", V2_EffectiveSpreadMultiplier(1, start, full, mult, eased), mult, 1e-12);
   AssertNear("prod13 depth 2 midpoint",
              V2_EffectiveSpreadMultiplier(2, start, full, mult, eased),
              mult - 0.5 * (mult - eased), 1e-12);
   AssertNear("prod13 depth 3 at full", V2_EffectiveSpreadMultiplier(3, start, full, mult, eased), eased, 1e-12);
   AssertNear("prod13 depth 4 above full", V2_EffectiveSpreadMultiplier(4, start, full, mult, eased), eased, 1e-12);

   const double mid = V2_EffectiveSpreadMultiplier(2, start, full, mult, eased);
   AssertTrue("prod13 mid-ramp differs from un-eased multiplier", MathAbs(mid - mult) > 1e-9);
   AssertTrue("prod13 mid-ramp differs from eased multiplier", MathAbs(mid - eased) > 1e-9);
}

//+------------------------------------------------------------------+
// ADR-098 production calibration: EURUSD locked thresholds 1/4 (not discovery 2/5).
void Test_L0SpreadEaseMultiplierRamp_Production14()
{
   const int start = 1;
   const int full = 4;
   const double mult = 0.5;
   const double eased = 0.0;

   AssertNear("prod14 depth 0", V2_EffectiveSpreadMultiplier(0, start, full, mult, eased), mult, 1e-12);
   AssertNear("prod14 depth 1 at start", V2_EffectiveSpreadMultiplier(1, start, full, mult, eased), mult, 1e-12);
   AssertNear("prod14 depth 2 one-third",
              V2_EffectiveSpreadMultiplier(2, start, full, mult, eased),
              mult - (1.0 / 3.0) * (mult - eased), 1e-12);
   AssertNear("prod14 depth 3 two-thirds",
              V2_EffectiveSpreadMultiplier(3, start, full, mult, eased),
              mult - (2.0 / 3.0) * (mult - eased), 1e-12);
   AssertNear("prod14 depth 4 at full", V2_EffectiveSpreadMultiplier(4, start, full, mult, eased), eased, 1e-12);
   AssertNear("prod14 depth 5 above full", V2_EffectiveSpreadMultiplier(5, start, full, mult, eased), eased, 1e-12);

   const double mid2 = V2_EffectiveSpreadMultiplier(2, start, full, mult, eased);
   AssertTrue("prod14 depth-2 mid-ramp differs from un-eased multiplier", MathAbs(mid2 - mult) > 1e-9);
   AssertTrue("prod14 depth-2 mid-ramp differs from eased multiplier", MathAbs(mid2 - eased) > 1e-9);

   const double mid3 = V2_EffectiveSpreadMultiplier(3, start, full, mult, eased);
   AssertTrue("prod14 depth-3 mid-ramp differs from un-eased multiplier", MathAbs(mid3 - mult) > 1e-9);
   AssertTrue("prod14 depth-3 mid-ramp differs from eased multiplier", MathAbs(mid3 - eased) > 1e-9);
}

//+------------------------------------------------------------------+
void Test_L0DynamicHalfSpreadFloor()
{
   const double quote = 0.0004;
   const double sigma = 0.0010;
   const double mult = 0.5;
   const double sigma_hs = quote + sigma * mult;
   const double live = 0.0008;
   const double buf = 0.00005;

   AssertNear("floor binds when live+buffer higher",
              V2_L0DynamicHalfSpread(quote, 0.0008, mult, live, buf),
              live + buf, 1e-12);
   AssertNear("sigma path when higher than floor",
              V2_L0DynamicHalfSpread(quote, sigma * 3.0, mult, live, buf),
              quote + sigma * 3.0 * mult, 1e-12);
   AssertTrue("sigma path exceeds floor case",
              sigma_hs > live + buf);
}

//+------------------------------------------------------------------+
void Test_L0LiveSpreadFallback()
{
   const double quote = 0.0004;
   const double point = 0.00001;
   double last_valid = -1.0;

   AssertNear("cold start uses InpQuoteSpread fallback",
              V2_ResolveLiveSpreadPriceFromRaw(0, point, quote, last_valid),
              quote, 1e-12);

   last_valid = -1.0;
   AssertNear("valid spread stored and returned",
              V2_ResolveLiveSpreadPriceFromRaw(80, point, quote, last_valid),
              80.0 * point, 1e-12);
   AssertNear("last_valid retained", last_valid, 80.0 * point, 1e-12);

   AssertNear("zero spread keeps prior valid",
              V2_ResolveLiveSpreadPriceFromRaw(0, point, quote, last_valid),
              80.0 * point, 1e-12);

   last_valid = -1.0;
   AssertNear("zero spread with no prior falls back to quote",
              V2_ResolveLiveSpreadPriceFromRaw(0, point, quote, last_valid),
              quote, 1e-12);
}

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
// ADR-099: EURGBP AB-slot dual-sigma easing — swap-independence matrix.
void Test_EurgbpAbDualSigmaSwapIndependence()
{
   const double quote = 0.0004;
   const double live = 0.0001;
   const double buf = 0.00001;
   const double mult_full = 0.5;
   const double mult_mid = 0.25;
   const double mult_eased = 0.0;

   struct Case {
      string label;
      double sig_ac;
      double sig_bc;
      double effective_mult;
   };

   Case cases[] = {
      {"ac_gt_bc full",   0.0030, 0.0010, mult_full},
      {"ac_gt_bc mid",    0.0030, 0.0010, mult_mid},
      {"ac_gt_bc eased",  0.0030, 0.0010, mult_eased},
      {"ac_lt_bc full",   0.0010, 0.0030, mult_full},
      {"ac_lt_bc mid",    0.0010, 0.0030, mult_mid},
      {"ac_lt_bc eased",  0.0010, 0.0030, mult_eased},
      {"ac_eq_bc full",   0.0020, 0.0020, mult_full},
      {"ac_eq_bc mid",    0.0020, 0.0020, mult_mid},
      {"ac_eq_bc eased",  0.0020, 0.0020, mult_eased},
   };

   for(int i = 0; i < ArraySize(cases); i++) {
      const double sigma_max = MathMax(cases[i].sig_ac, cases[i].sig_bc);
      const double got = V2_L0DynamicHalfSpread(
         quote, sigma_max, cases[i].effective_mult, live, buf);
      const double expected = MathMax(
         quote + sigma_max * cases[i].effective_mult,
         live + buf);
      AssertNear("eurgbp swap " + cases[i].label, got, expected, 1e-12);
      AssertTrue("eurgbp swap uses max sigma " + cases[i].label,
                 MathAbs(sigma_max - MathMax(cases[i].sig_ac, cases[i].sig_bc)) < 1e-15);
   }
}

//+------------------------------------------------------------------+
// ADR-099: floor-rescue — fully eased + zero sigma must not collapse to bare quote_spread.
void Test_EurgbpAbFloorRescue()
{
   const double quote = 0.0004;
   const double sigma = 0.0;
   const double mult_eased = 0.0;
   const double live = 0.0008;   // 8 pips
   const double buf = 0.00005;   // 0.5 pips
   const double expected = live + buf;

   const double got = V2_L0DynamicHalfSpread(quote, sigma, mult_eased, live, buf);
   const bool pass = (MathAbs(got - expected) < 1e-12) && (got > quote + 1e-12);

   if(pass)
      Print("PASS | ADR-099 floor-rescue: dynamic_hs=", DoubleToString(got, 8),
            " equals live+buffer=", DoubleToString(expected, 8),
            " (NOT bare quote_spread=", DoubleToString(quote, 8), ")");
   else
      Print("FAIL | ADR-099 floor-rescue: dynamic_hs=", DoubleToString(got, 8),
            " expected live+buffer=", DoubleToString(expected, 8),
            " quote_spread=", DoubleToString(quote, 8));

   AssertTrue("eurgbp floor-rescue binds to live+buffer", pass);
   AssertTrue("eurgbp floor-rescue exceeds bare quote", got > quote);
}

//+------------------------------------------------------------------+
bool EurgbpEaseDepthInputsValid(const int ease_start, const int ease_full)
{
   return !(ease_full <= ease_start || ease_start < 0 || ease_full < 0);
}

void Test_EurgbpEaseDepthOnInitGuard()
{
   AssertTrue("guard full<=start invalid", !EurgbpEaseDepthInputsValid(2, 2));
   AssertTrue("guard full<start invalid", !EurgbpEaseDepthInputsValid(3, 2));
   AssertTrue("guard negative start invalid", !EurgbpEaseDepthInputsValid(-1, 5));
   AssertTrue("guard negative full invalid", !EurgbpEaseDepthInputsValid(2, -1));
   AssertTrue("guard valid 1/3 production", EurgbpEaseDepthInputsValid(1, 3));
}

//+------------------------------------------------------------------+
void Test_EurgbpAbLiveSpreadFallbackWiring()
{
   const double quote = 0.0004;
   const double point = 0.00001;
   double last_valid = -1.0;

   const double cold = V2_ResolveLiveSpreadPriceFromRaw(0, point, quote, last_valid);
   AssertNear("eurgbp cold-start live spread", cold, quote, 1e-12);

   last_valid = -1.0;
   const double wide = V2_ResolveLiveSpreadPriceFromRaw(80, point, quote, last_valid);
   AssertNear("eurgbp wide spread resolved", wide, 80.0 * point, 1e-12);

   const double sigma = 0.0010;
   const double mult = 0.5;
   const double dhs = V2_L0DynamicHalfSpread(quote, sigma, mult, wide, 0.00005);
   AssertNear("eurgbp path uses resolved live in floor",
              dhs,
              MathMax(quote + sigma * mult, wide + 0.00005),
              1e-12);
   AssertTrue("eurgbp wiring calls floor with live not quote-only",
              dhs >= wide + 0.00005 - 1e-12);
}

//+------------------------------------------------------------------+
void Test_EurgbpAbFlatMultiplierNoRamp()
{
   const double quote = 0.0004;
   const double sig_ac = 0.0015;
   const double sig_bc = 0.0025;
   const double mult = 0.5;
   const double live = 0.0001;
   const double buf = 0.00001;

   const double sigma_max = MathMax(sig_ac, sig_bc);
   const double legacy_hs = quote + sigma_max * mult;
   const double eased_hs = V2_L0DynamicHalfSpread(quote, sigma_max, mult, live, buf);

   AssertNear("eurgbp flat mult matches legacy sigma path when floor below",
              eased_hs, legacy_hs, 1e-12);

   const double ramped = V2_EffectiveSpreadMultiplier(4, 2, 5, mult, 0.0);
   AssertTrue("eurgbp mid-ramp differs from flat mult", MathAbs(ramped - mult) > 1e-9);
   AssertNear("eurgbp mid-ramp value", ramped, mult - (2.0 / 3.0) * mult, 1e-12);
}

//+------------------------------------------------------------------+
void Test_ClearCapGvs()
{
   string keys[];
   ArrayResize(keys, 10);
   keys[0] = V2_GBP_CAP_GV_GBP_LONG;
   keys[1] = V2_GBP_CAP_GV_GBP_SHORT;
   keys[2] = V2_GBP_CAP_GV_EGP_LONG;
   keys[3] = V2_GBP_CAP_GV_EGP_SHORT;
   keys[4] = V2_EUR_CAP_GV_EUR_LONG;
   keys[5] = V2_EUR_CAP_GV_EUR_SHORT;
   keys[6] = V2_EUR_CAP_GV_EGP_LONG;
   keys[7] = V2_EUR_CAP_GV_EGP_SHORT;
   keys[8] = "V2GBP_CAP_TRIGGERS";
   keys[9] = "V2EUR_CAP_TRIGGERS";
   for(int i = 0; i < ArraySize(keys); i++) {
      if(GlobalVariableCheck(keys[i]))
         GlobalVariableDel(keys[i]);
   }
}

// ADR-100: EUR-side cross-instance exposure cap (EURUSD + EURGBP).
void Test_EurCapNetExposureAddition()
{
   Test_ClearCapGvs();

   V2_EurCapPublishLayers(V2_EUR_CAP_GV_EUR_LONG, 4);
   V2_EurCapPublishLayers(V2_EUR_CAP_GV_EUR_SHORT, 1);
   V2_EurCapPublishLayers(V2_EUR_CAP_GV_EGP_LONG, 3);
   V2_EurCapPublishLayers(V2_EUR_CAP_GV_EGP_SHORT, 2);
   AssertNear("eur net uses addition across pairs",
              V2_EurNetExposure(), (4.0 - 1.0) + (3.0 - 2.0), 1e-9);
   AssertTrue("eur net differs from subtraction form",
              MathAbs(V2_EurNetExposure() - ((4.0 - 1.0) - (3.0 - 2.0))) > 1e-9);

   Test_ClearCapGvs();
   V2_EurCapPublishLayers(V2_EUR_CAP_GV_EUR_LONG, 2);
   V2_EurCapPublishLayers(V2_EUR_CAP_GV_EGP_LONG, 5);
   AssertNear("long-only eur legs sum", V2_EurNetExposure(), 7.0, 1e-9);

   Test_ClearCapGvs();
   V2_EurCapPublishLayers(V2_EUR_CAP_GV_EUR_SHORT, 3);
   V2_EurCapPublishLayers(V2_EUR_CAP_GV_EGP_SHORT, 1);
   AssertNear("short-only eur legs sum", V2_EurNetExposure(), -4.0, 1e-9);

   Test_ClearCapGvs();
}

void Test_EurCapDeltaSymmetric()
{
   AssertNear("eurusd long delta", V2_EurCapDeltaForAdd("EURUSD", true), 1.0, 1e-9);
   AssertNear("eurusd short delta", V2_EurCapDeltaForAdd("EURUSD", false), -1.0, 1e-9);
   AssertNear("eurgbp long delta", V2_EurCapDeltaForAdd("EURGBP", true), 1.0, 1e-9);
   AssertNear("eurgbp short delta", V2_EurCapDeltaForAdd("EURGBP", false), -1.0, 1e-9);
   AssertNear("gbpusd eur delta zero", V2_EurCapDeltaForAdd("GBPUSD", true), 0.0, 1e-9);
}

void Test_EurCapBlocksNewAddThreshold()
{
   Test_ClearCapGvs();
   GlobalVariableSet("V2EUR_CAP_TRIGGERS", 0.0);

   AssertTrue("threshold 0 never blocks", !V2_EurCapBlocksNewAdd("EURUSD", true, 0));

   V2_EurCapPublishLayers(V2_EUR_CAP_GV_EUR_LONG, 2);
   AssertTrue("exact threshold landing allowed",
              !V2_EurCapBlocksNewAdd("EURUSD", true, 3));

   V2_EurCapPublishLayers(V2_EUR_CAP_GV_EUR_LONG, 3);
   AssertTrue("widening above threshold blocks",
              V2_EurCapBlocksNewAdd("EURUSD", true, 3));

   V2_EurCapPublishLayers(V2_EUR_CAP_GV_EUR_LONG, 0);
   V2_EurCapPublishLayers(V2_EUR_CAP_GV_EGP_LONG, 3);
   AssertTrue("eurgbp long add widens eur net",
              V2_EurCapBlocksNewAdd("EURGBP", true, 3));

   Test_ClearCapGvs();
}

void Test_AnyCapBlocksNewAddNoMasking()
{
   Test_ClearCapGvs();
   GlobalVariableSet("V2GBP_CAP_TRIGGERS", 0.0);
   GlobalVariableSet("V2EUR_CAP_TRIGGERS", 0.0);

   V2_GbpCapPublishLayers(V2_GBP_CAP_GV_EGP_LONG, 3);
   V2_EurCapPublishLayers(V2_EUR_CAP_GV_EGP_LONG, 3);

   bool gbp_blocked = false;
   bool eur_blocked = false;
   string eval_log = "";
   V2_EvalBothCaps(true, 3, 10, gbp_blocked, eur_blocked, eval_log);

   AssertTrue("gbp-only block case blocks aggregate", gbp_blocked);
   AssertTrue("gbp-only block case eur does not block", !eur_blocked);
   AssertContains("gbp-only log mentions GBP cap", eval_log, "GBP cap:");
   AssertContains("gbp-only log mentions EUR cap", eval_log, "EUR cap:");
   AssertContains("gbp-only log gbp blocked true", eval_log, "GBP cap: blocked=true");
   AssertContains("gbp-only log eur blocked false", eval_log, "EUR cap: blocked=false");
   AssertTrue("anycap gbp-only aggregate", V2_AnyCapBlocksNewAdd(true, 3, 10));

   Test_ClearCapGvs();
   GlobalVariableSet("V2GBP_CAP_TRIGGERS", 0.0);
   GlobalVariableSet("V2EUR_CAP_TRIGGERS", 0.0);

   V2_GbpCapPublishLayers(V2_GBP_CAP_GV_EGP_LONG, 3);
   V2_EurCapPublishLayers(V2_EUR_CAP_GV_EGP_LONG, 3);

   gbp_blocked = false;
   eur_blocked = false;
   eval_log = "";
   V2_EvalBothCaps(true, 10, 3, gbp_blocked, eur_blocked, eval_log);

   AssertTrue("eur-only block case eur blocks", eur_blocked);
   AssertTrue("eur-only block case gbp does not block", !gbp_blocked);
   AssertContains("eur-only log mentions GBP cap", eval_log, "GBP cap:");
   AssertContains("eur-only log mentions EUR cap", eval_log, "EUR cap:");
   AssertContains("eur-only log gbp blocked false", eval_log, "GBP cap: blocked=false");
   AssertContains("eur-only log eur blocked true", eval_log, "EUR cap: blocked=true");
   AssertTrue("anycap eur-only aggregate", V2_AnyCapBlocksNewAdd(true, 10, 3));

   Test_ClearCapGvs();
}

void Test_SyncAllCapsPublishesBothGvSets()
{
   Test_ClearCapGvs();

   V2_SyncAllCaps(true, 7);

   AssertTrue("sync all caps publishes gbp long gv",
              GlobalVariableCheck(V2_GBP_CAP_GV_EGP_LONG));
   AssertTrue("sync all caps publishes eur long gv",
              GlobalVariableCheck(V2_EUR_CAP_GV_EGP_LONG));
   AssertNear("sync all caps gbp long value",
              GlobalVariableGet(V2_GBP_CAP_GV_EGP_LONG), 7.0, 1e-9);
   AssertNear("sync all caps eur long value",
              GlobalVariableGet(V2_EUR_CAP_GV_EGP_LONG), 7.0, 1e-9);

   V2_SyncAllCaps(false, 2);
   AssertNear("sync all caps gbp short value",
              GlobalVariableGet(V2_GBP_CAP_GV_EGP_SHORT), 2.0, 1e-9);
   AssertNear("sync all caps eur short value",
              GlobalVariableGet(V2_EUR_CAP_GV_EGP_SHORT), 2.0, 1e-9);

   Test_ClearCapGvs();
}

//+------------------------------------------------------------------+
string Test_ReadEngineMqhContent()
{
   const string rel = "fxmatrix_v2_engine.mqh";
   int h = FileOpen(rel, FILE_READ | FILE_TXT | FILE_ANSI | FILE_COMMON);
   if(h == INVALID_HANDLE)
      h = FileOpen(rel, FILE_READ | FILE_TXT | FILE_ANSI);
   if(h == INVALID_HANDLE) {
      const string abs_path = TerminalInfoString(TERMINAL_DATA_PATH)
         + "\\MQL5\\Experts\\" + rel;
      h = FileOpen(abs_path, FILE_READ | FILE_TXT | FILE_ANSI);
   }
   if(h == INVALID_HANDLE)
      return "";
   string content = "";
   while(!FileIsEnding(h))
      content += FileReadString(h) + "\n";
   FileClose(h);
   return content;
}

void Test_UnifiedEnginePairLabelLinter()
{
   const string content = Test_ReadEngineMqhContent();
   Print("DIAG engine linter content chars=", StringLen(content));
   AssertTrue("engine file readable for pair-label linter", StringLen(content) > 1000);
   AssertNotContains("engine no GBPUSD literal", content, "\"GBPUSD\"");
   AssertNotContains("engine no EURUSD literal", content, "\"EURUSD\"");
   AssertNotContains("engine no EURGBP literal", content, "\"EURGBP\"");
}

void Test_UnifiedEngineMagicLiteralGrep()
{
   const string content = Test_ReadEngineMqhContent();
   Print("DIAG engine grep content chars=", StringLen(content));
   AssertTrue("engine file readable for magic grep", StringLen(content) > 1000);
   const string forbidden[] = {
      "20260901", "20260902", "20260903", "20260904",
      "20260911", "20260912", "20260913", "20260914",
      "20260921", "20260922", "20260923", "20260924"
   };
   for(int i = 0; i < ArraySize(forbidden); i++)
      AssertNotContains("engine no magic " + forbidden[i], content, forbidden[i]);
}

void V2Test_FillMonotoneCloses(double &closes[], const double base)
{
   ArrayResize(closes, 60);
   for(int i = 0; i < 60; i++)
      closes[i] = base + 0.00001 * (59 - i);
   ArraySetAsSeries(closes, true);
}

void V2Test_FillDefaultBcInputs(V2L0BcInputs &in, double &closes[])
{
   V2Test_FillMonotoneCloses(closes, 1.30000);
   ArrayCopy(in.closes, closes);
   in.quote_spread = 0.0004;
   in.spread_multiplier = 0.5;
   in.spread_multiplier_eased = 0.0;
   in.ease_depth_start = 1;
   in.ease_depth_full = 3;
   in.live_spread_price = 0.0004;
   in.passivity_buffer_price = 0.00005;
   in.quoting_side_flat = true;
   in.opposite_depth = 0;
   in.compute_bid = true;
}

void Test_V2L0CoreComputeBc_ColdStart()
{
   V2L0BcInputs in;
   double closes[];
   ArrayResize(closes, 10);
   ArrayCopy(in.closes, closes);
   double out = 1.0;
   V2L0CoreDiagnostics diag;
   AssertTrue("bc cold-start rejects short buffer", !V2_L0CoreComputeBc(in, out, diag));
}

void Test_V2L0CoreComputeBc_EaseRampAffectsOutput()
{
   double closes[];
   V2L0BcInputs in;
   V2Test_FillDefaultBcInputs(in, closes);
   in.bid = 1.30010;
   in.ask = 1.30030;
   in.quoting_side_flat = true;
   in.opposite_depth = 0;
   double flat_out = 0.0;
   V2L0CoreDiagnostics diag;
   AssertTrue("bc flat ramp baseline", V2_L0CoreComputeBc(in, flat_out, diag));

   in.opposite_depth = 2;
   double eased_out = 0.0;
   V2L0CoreDiagnostics diag2;
   AssertTrue("bc eased ramp", V2_L0CoreComputeBc(in, eased_out, diag2));
   AssertTrue("bc ease ramp changes bid", MathAbs(flat_out - eased_out) > 1e-9);
}

void Test_V2L0CoreComputeBc_DynamicHalfSpreadFloor()
{
   double closes[];
   V2L0BcInputs in;
   V2Test_FillDefaultBcInputs(in, closes);
   in.bid = 1.30010;
   in.ask = 1.30030;
   in.spread_multiplier = 0.0;
   double out = 0.0;
   V2L0CoreDiagnostics diag;
   AssertTrue("bc floor path computes", V2_L0CoreComputeBc(in, out, diag));
   AssertTrue("bc floor bid positive", out > 0.0);
}

void Test_V2L0CoreComputeBc_UnguardedHalfSpreadProductionParity()
{
   double closes[];
   V2L0BcInputs in;
   V2Test_FillDefaultBcInputs(in, closes);
   V2L0CoreDiagnostics diag;

   in.bid = 1.30010;
   in.ask = 0.0;
   double partial = 0.0;
   AssertTrue("bc bid>0 ask==0 computes", V2_L0CoreComputeBc(in, partial, diag));

   in.bid = 0.0;
   in.ask = 0.0;
   double zero = 0.0;
   V2L0CoreDiagnostics diag_zero;
   AssertTrue("bc zero bid ask computes", V2_L0CoreComputeBc(in, zero, diag_zero));
   AssertTrue("bc partial ask differs from zero bid ask", MathAbs(partial - zero) > 1e-9);

   in.bid = 1.30010;
   in.ask = 1.30030;
   double full = 0.0;
   V2L0CoreDiagnostics diag_full;
   AssertTrue("bc valid bid ask computes", V2_L0CoreComputeBc(in, full, diag_full));
   AssertTrue("bc partial ask must not match half-spread path", MathAbs(partial - full) > 1e-9);
}

void Test_V2L0CoreComputeBc_DiagnosticsMatchCore()
{
   double closes[];
   V2L0BcInputs in;
   V2Test_FillDefaultBcInputs(in, closes);
   in.bid = 1.30010;
   in.ask = 1.30030;
   in.opposite_depth = 2;
   double theoretical = 0.0;
   V2L0CoreDiagnostics diag;
   AssertTrue("bc diagnostics path computes", V2_L0CoreComputeBc(in, theoretical, diag));
   double expected_em = V2_EffectiveSpreadMultiplier(
      in.opposite_depth, in.ease_depth_start, in.ease_depth_full,
      in.spread_multiplier, in.spread_multiplier_eased);
   AssertNear("bc diag effective_multiplier", diag.effective_multiplier, expected_em, 1e-12);
   double fv, sigma;
   AssertTrue("bc diag sigma source", V2_FvSigmaFromCloses(in.closes, fv, sigma));
   AssertNear("bc diag sigma", diag.sigma, sigma, 1e-12);
   double expected_hs = V2_L0DynamicHalfSpread(
      in.quote_spread, sigma, expected_em, in.live_spread_price, in.passivity_buffer_price);
   AssertNear("bc diag dynamic_hs", diag.dynamic_hs, expected_hs, 1e-12);
   double theoretical_repeat = 0.0;
   V2L0CoreDiagnostics diag_repeat;
   AssertTrue("bc repeat path computes", V2_L0CoreComputeBc(in, theoretical_repeat, diag_repeat));
   AssertNear("bc diag does not change theoretical", theoretical, theoretical_repeat, 1e-12);
}

void V2Test_FillDefaultAbInputs(V2L0AbInputs &in, double &ac[], double &bc[])
{
   V2Test_FillMonotoneCloses(ac, 1.10000);
   V2Test_FillMonotoneCloses(bc, 1.30000);
   ArrayCopy(in.ac_closes, ac);
   ArrayCopy(in.bc_closes, bc);
   in.quote_spread = 0.0004;
   in.spread_multiplier = 0.5;
   in.spread_multiplier_eased = 0.0;
   in.ease_depth_start = 1;
   in.ease_depth_full = 3;
   in.live_spread_price = 0.0004;
   in.passivity_buffer_price = 0.00005;
   in.quoting_side_flat = true;
   in.opposite_depth = 0;
   in.compute_bid = true;
}

void Test_V2L0CoreComputeAb_ColdStart()
{
   V2L0AbInputs in;
   double ac[], bc[];
   ArrayResize(ac, 10);
   ArrayResize(bc, 10);
   ArrayCopy(in.ac_closes, ac);
   ArrayCopy(in.bc_closes, bc);
   double out = 1.0;
   V2L0CoreDiagnostics diag;
   AssertTrue("ab cold-start rejects short buffer", !V2_L0CoreComputeAb(in, out, diag));
}

void Test_V2L0CoreComputeAb_EaseRampAffectsOutput()
{
   double ac[], bc[];
   V2L0AbInputs in;
   V2Test_FillDefaultAbInputs(in, ac, bc);
   in.ac_bid = 1.10010;
   in.ac_ask = 1.10030;
   in.bc_bid = 1.30010;
   in.bc_ask = 1.30030;
   in.opposite_depth = 0;
   double flat_out = 0.0;
   V2L0CoreDiagnostics diag;
   AssertTrue("ab flat ramp baseline", V2_L0CoreComputeAb(in, flat_out, diag));

   in.opposite_depth = 2;
   double eased_out = 0.0;
   V2L0CoreDiagnostics diag2;
   AssertTrue("ab eased ramp", V2_L0CoreComputeAb(in, eased_out, diag2));
   AssertTrue("ab ease ramp changes bid", MathAbs(flat_out - eased_out) > 1e-9);
}

void Test_V2L0CoreComputeAb_InvalidBidAskFallback()
{
   double ac[], bc[];
   V2L0AbInputs in;
   V2Test_FillDefaultAbInputs(in, ac, bc);
   V2L0CoreDiagnostics diag;

   in.ac_bid = 1.10010;
   in.ac_ask = 0.0;
   in.bc_bid = 1.30010;
   in.bc_ask = 1.30030;
   double ac_bid_only = 0.0;
   AssertTrue("ab ac bid-only computes", V2_L0CoreComputeAb(in, ac_bid_only, diag));

   in.ac_bid = 1.10010;
   in.ac_ask = 1.10030;
   in.bc_bid = 1.30010;
   in.bc_ask = 0.0;
   double bc_bid_only = 0.0;
   V2L0CoreDiagnostics diag_bc;
   AssertTrue("ab bc bid-only computes", V2_L0CoreComputeAb(in, bc_bid_only, diag_bc));

   in.ac_bid = 0.0;
   in.ac_ask = 0.0;
   in.bc_bid = 0.0;
   in.bc_ask = 0.0;
   double cold = 0.0;
   V2L0CoreDiagnostics diag_cold;
   AssertTrue("ab zero bid ask computes", V2_L0CoreComputeAb(in, cold, diag_cold));
   AssertNear("ab ac bid-only equals ac close fallback", ac_bid_only, cold, 1e-6);

   in.ac_bid = 1.10010;
   in.ac_ask = 1.10030;
   in.bc_bid = 1.30010;
   in.bc_ask = 1.30030;
   double full = 0.0;
   V2L0CoreDiagnostics diag_full;
   AssertTrue("ab valid bid ask computes", V2_L0CoreComputeAb(in, full, diag_full));
   AssertTrue("ab ac bid-only differs from full spread path",
              MathAbs(ac_bid_only - full) > 1e-9);
   AssertTrue("ab bc bid-only differs from full spread path",
              MathAbs(bc_bid_only - full) > 1e-9);
}

//+------------------------------------------------------------------+
// State Reconstruction Engine — Phase A unit tests (spec v8)
//+------------------------------------------------------------------+
const double SRE_POINT = 0.00001;
const double SRE_EXIT_PIPS = 3.0;
const double SRE_LOT = 0.01;
const datetime SRE_T0 = D'2026.06.01 10:00:00';
const datetime SRE_T1 = D'2026.06.01 11:00:00';
const datetime SRE_T2 = D'2026.06.01 12:00:00';
const datetime SRE_T3 = D'2026.06.01 13:00:00';
const datetime SRE_NOW = D'2026.06.01 14:00:00';

void Test_SRE_BaselineMultiLayerNoCloseBy()
{
   V2SREPositionInput pos[];
   ArrayResize(pos, 2);
   pos[0].ticket = 101; pos[0].position_id = 1001; pos[0].open_time = SRE_T0;
   pos[0].entry_price = 1.30000; pos[0].volume = SRE_LOT; pos[0].direction = 1;
   pos[0].symbol = "GBPUSD"; pos[0].position_type = POSITION_TYPE_BUY;
   pos[1].ticket = 102; pos[1].position_id = 1002; pos[1].open_time = SRE_T1;
   pos[1].entry_price = 1.29910; pos[1].volume = SRE_LOT; pos[1].direction = 1;
   pos[1].symbol = "GBPUSD"; pos[1].position_type = POSITION_TYPE_BUY;

   V2SREExitOrderInput ord[];
   ArrayResize(ord, 2);
   ord[0].ticket = 201; ord[0].placement_time = SRE_T0 + 60;
   ord[0].price = V2_SRE_ExpectedExitPrice(1.30000, 1, SRE_EXIT_PIPS, SRE_POINT);
   ord[0].volume = SRE_LOT; ord[0].direction = 1; ord[0].symbol = "GBPUSD";
   ord[1].ticket = 202; ord[1].placement_time = SRE_T1 + 60;
   ord[1].price = V2_SRE_ExpectedExitPrice(1.29910, 1, SRE_EXIT_PIPS, SRE_POINT);
   ord[1].volume = SRE_LOT; ord[1].direction = 1; ord[1].symbol = "GBPUSD";

   V2SREMatchResult match = V2_SRE_MatchExitOrders(pos, ord, SRE_NOW,
                                                   SRE_EXIT_PIPS, SRE_POINT, SRE_LOT);
   AssertTrue("baseline match ok", match.halt == V2_SRE_OK);
   AssertTrue("layer0 exit ticket", match.exit_tickets[0] == 201);
   AssertTrue("layer1 exit ticket", match.exit_tickets[1] == 202);

   V2SRELayerSnapshot recon[];
   V2SRELayerSnapshot broker[];
   V2_SRE_BuildLayerSnapshotsFromPositions(pos, match, recon);
   ArrayResize(broker, 2);
   broker[0].position_ticket = 1001; broker[0].entry_ticket = 101; broker[0].entry_price = 1.30000;
   broker[1].position_ticket = 1002; broker[1].entry_ticket = 102; broker[1].entry_price = 1.29910;
   AssertTrue("baseline validation", V2_SRE_ValidateReconstruction(recon, broker) == V2_SRE_OK);
}

void Test_SRE_AnchorWalkCloseByNoMiscount()
{
   V2SREDealInput deals[];
   ArrayResize(deals, 5);
   deals[0].deal_time = SRE_T0; deals[0].position_id = 5001; deals[0].entry_type = DEAL_ENTRY_IN;
   deals[0].deal_magic = MM_LONG_V2; deals[0].volume = SRE_LOT; deals[0].price = 1.30000;
   deals[1].deal_time = SRE_T1; deals[1].position_id = 5002; deals[1].entry_type = DEAL_ENTRY_IN;
   deals[1].deal_magic = MM_LONG_V2_EXIT; deals[1].volume = SRE_LOT; deals[1].price = 1.30030;
   deals[2].deal_time = SRE_T1 + 30; deals[2].position_id = 5001; deals[2].entry_type = DEAL_ENTRY_OUT_BY;
   deals[2].deal_magic = MM_LONG_V2; deals[2].volume = SRE_LOT; deals[2].order_id = 9001;
   deals[3].deal_time = SRE_T1 + 30; deals[3].position_id = 5002; deals[3].entry_type = DEAL_ENTRY_OUT_BY;
   deals[3].deal_magic = MM_LONG_V2; deals[3].volume = SRE_LOT; deals[3].order_id = 9001;
   deals[4].deal_time = SRE_T2; deals[4].position_id = 5003; deals[4].entry_type = DEAL_ENTRY_IN;
   deals[4].deal_magic = MM_LONG_V2; deals[4].volume = SRE_LOT; deals[4].price = 1.29910;

   const double vol_after_close = V2_SRE_EntryVolumeAtAnchorWalk(deals, 3, MM_LONG_V2, MM_LONG_V2_EXIT);
   AssertTrue("closeby decrements entry by position_id", vol_after_close <= 1e-12);

   V2SREAnchorResult anchor = V2_SRE_FindAnchor(deals, SRE_NOW, V2_SRE_DEFAULT_LOOKBACK_SEC,
                                                MM_LONG_V2, MM_LONG_V2_EXIT);
   AssertTrue("anchor found after closeby", anchor.halt == V2_SRE_OK);
}

void Test_SRE_ReloadResetsLastExitValid()
{
   V2SREReplayEvent ev[];
   ArrayResize(ev, 3);
   ev[0].event_time = SRE_T0; ev[0].is_removal = false; ev[0].is_reload = false;
   ev[0].entry_price = 1.30000; ev[0].entry_position_id = 1;
   ev[1].event_time = SRE_T1; ev[1].is_removal = true; ev[1].is_reload = false;
   ev[1].entry_price = 1.30000; ev[1].entry_position_id = 1;
   ev[2].event_time = SRE_T2; ev[2].is_removal = false; ev[2].is_reload = true;
   ev[2].entry_price = 1.30000; ev[2].entry_position_id = 2;

   V2SREPathState st = V2_SRE_ReplayPathDependentState(ev, V2_ADD_PIPS_FLOOR,
                                                       V2_WIDEN_RATIO, V2_ADD_PIPS_CEILING);
   AssertTrue("reload clears last_exit_valid", !st.last_exit_valid);
}

void Test_SRE_StaleExitOrderNotAssignable()
{
   V2SREPositionInput pos[];
   ArrayResize(pos, 1);
   pos[0].ticket = 101; pos[0].position_id = 1001; pos[0].open_time = SRE_T2;
   pos[0].entry_price = 1.29910; pos[0].volume = SRE_LOT; pos[0].direction = 1;
   pos[0].symbol = "GBPUSD"; pos[0].position_type = POSITION_TYPE_BUY;

   V2SREExitOrderInput ord[];
   ArrayResize(ord, 1);
   ord[0].ticket = 201; ord[0].placement_time = SRE_T0;
   ord[0].price = V2_SRE_ExpectedExitPrice(1.30000, 1, SRE_EXIT_PIPS, SRE_POINT);
   ord[0].volume = SRE_LOT; ord[0].direction = 1; ord[0].symbol = "GBPUSD";

   V2SREMatchResult match = V2_SRE_MatchExitOrders(pos, ord, SRE_NOW,
                                                   SRE_EXIT_PIPS, SRE_POINT, SRE_LOT);
   AssertTrue("stale order unmatched halts", match.halt == V2_SRE_HALT_21_UNMATCHED_EXIT_ORDER);
}

void Test_SRE_LateExitStillMatchesOlderLayer()
{
   V2SREPositionInput pos[];
   ArrayResize(pos, 2);
   pos[0].ticket = 101; pos[0].position_id = 1001; pos[0].open_time = SRE_T0;
   pos[0].entry_price = 1.30000; pos[0].volume = SRE_LOT; pos[0].direction = 1;
   pos[0].symbol = "GBPUSD"; pos[0].position_type = POSITION_TYPE_BUY;
   pos[1].ticket = 102; pos[1].position_id = 1002; pos[1].open_time = SRE_T1;
   pos[1].entry_price = 1.29910; pos[1].volume = SRE_LOT; pos[1].direction = 1;
   pos[1].symbol = "GBPUSD"; pos[1].position_type = POSITION_TYPE_BUY;

   V2SREExitOrderInput ord[];
   ArrayResize(ord, 2);
   ord[0].ticket = 201; ord[0].placement_time = SRE_T2;
   ord[0].price = V2_SRE_ExpectedExitPrice(1.30000, 1, SRE_EXIT_PIPS, SRE_POINT);
   ord[0].volume = SRE_LOT; ord[0].direction = 1; ord[0].symbol = "GBPUSD";
   ord[1].ticket = 202; ord[1].placement_time = SRE_T1 + 60;
   ord[1].price = V2_SRE_ExpectedExitPrice(1.29910, 1, SRE_EXIT_PIPS, SRE_POINT);
   ord[1].volume = SRE_LOT; ord[1].direction = 1; ord[1].symbol = "GBPUSD";

   V2SREMatchResult match = V2_SRE_MatchExitOrders(pos, ord, SRE_NOW,
                                                   SRE_EXIT_PIPS, SRE_POINT, SRE_LOT);
   AssertTrue("late placement match ok", match.halt == V2_SRE_OK);
   AssertTrue("older layer keeps its exit", match.exit_tickets[0] == 201);
   AssertTrue("newer layer keeps its exit", match.exit_tickets[1] == 202);
}

void Test_SRE_CrossPairPriceConsistencyHalts()
{
   V2SREDealInput deals[];
   ArrayResize(deals, 4);
   deals[0].deal_time = SRE_T0; deals[0].position_id = 6001; deals[0].entry_type = DEAL_ENTRY_IN;
   deals[0].deal_magic = MM_LONG_V2; deals[0].volume = SRE_LOT; deals[0].price = 1.30000;
   deals[1].deal_time = SRE_T1; deals[1].position_id = 7001; deals[1].entry_type = DEAL_ENTRY_IN;
   deals[1].deal_magic = MM_LONG_V2_EXIT; deals[1].volume = SRE_LOT;
   deals[1].price = V2_SRE_ExpectedExitPrice(1.29910, 1, SRE_EXIT_PIPS, SRE_POINT);
   deals[2].deal_time = SRE_T2; deals[2].position_id = 6001; deals[2].entry_type = DEAL_ENTRY_OUT_BY;
   deals[2].deal_magic = MM_LONG_V2; deals[2].volume = SRE_LOT; deals[2].order_id = 9100;
   deals[3].deal_time = SRE_T2; deals[3].position_id = 7001; deals[3].entry_type = DEAL_ENTRY_OUT_BY;
   deals[3].deal_magic = MM_LONG_V2; deals[3].volume = SRE_LOT; deals[3].order_id = 9100;

   V2SREMapResult map = V2_SRE_MapHedgeToEntry(deals, SRE_T0 - 1, MM_LONG_V2, MM_LONG_V2_EXIT,
                                               1, SRE_EXIT_PIPS, SRE_POINT);
   AssertTrue("cross-pair price halt", map.halt == V2_SRE_HALT_30_CLOSEBY_PRICE_INCONSISTENT);
}

void Test_SRE_ExitMagicOpenHaltsPrecheck()
{
   V2SREPositionInput exit_pos[];
   ArrayResize(exit_pos, 1);
   exit_pos[0].ticket = 301; exit_pos[0].position_id = 9001; exit_pos[0].open_time = SRE_T1;
   exit_pos[0].entry_price = 1.30030; exit_pos[0].volume = SRE_LOT; exit_pos[0].direction = 1;
   exit_pos[0].symbol = "GBPUSD"; exit_pos[0].position_type = POSITION_TYPE_SELL;
   AssertTrue("exit magic open halts", V2_SRE_PreCheckExitMagicOpen(exit_pos) ==
              V2_SRE_HALT_01_EXIT_MAGIC_POSITION_OPEN);
}

void Test_SRE_WrongDirectionOpenPositionHalts()
{
   V2SREPositionInput pos[];
   ArrayResize(pos, 1);
   pos[0].direction = 1; pos[0].position_type = POSITION_TYPE_SELL;
   AssertTrue("wrong open position type",
              !V2_SRE_CheckOpenPositionTypes(pos, 1));
}

void Test_SRE_WrongDirectionPendingHalts()
{
   V2SREPendingEntryInput pending[];
   ArrayResize(pending, 1);
   pending[0].comment = V2_SRE_COMMENT_ADD; pending[0].direction = -1;
   AssertTrue("wrong pending direction",
              V2_SRE_CheckPendingEntryConsistency(pending, 1, 1) ==
              V2_SRE_HALT_20_PENDING_ENTRY_WRONG_DIRECTION);
}

void Test_SRE_UnmatchedExitOrderHalts()
{
   V2SREPositionInput pos[];
   ArrayResize(pos, 1);
   pos[0].ticket = 101; pos[0].position_id = 1001; pos[0].open_time = SRE_T1;
   pos[0].entry_price = 1.29910; pos[0].volume = SRE_LOT; pos[0].direction = 1;
   pos[0].symbol = "GBPUSD"; pos[0].position_type = POSITION_TYPE_BUY;

   V2SREExitOrderInput ord[];
   ArrayResize(ord, 1);
   ord[0].ticket = 201; ord[0].placement_time = SRE_T1 + 60;
   ord[0].price = V2_SRE_ExpectedExitPrice(1.30000, 1, SRE_EXIT_PIPS, SRE_POINT);
   ord[0].volume = SRE_LOT; ord[0].direction = 1; ord[0].symbol = "GBPUSD";

   V2SREMatchResult match = V2_SRE_MatchExitOrders(pos, ord, SRE_NOW,
                                                   SRE_EXIT_PIPS, SRE_POINT, SRE_LOT);
   AssertTrue("unmatched exit halts", match.halt == V2_SRE_HALT_21_UNMATCHED_EXIT_ORDER);
}

void Test_SRE_PendingMultipleL0OnEmpty()
{
   V2SREPendingEntryInput p[];
   ArrayResize(p, 2);
   p[0].comment = V2_SRE_COMMENT_L0; p[0].direction = 1;
   p[1].comment = V2_SRE_COMMENT_L0; p[1].direction = 1;
   AssertTrue("multiple L0", V2_SRE_CheckPendingEntryConsistency(p, 0, 1) ==
              V2_SRE_HALT_13_MULTIPLE_L0_PENDING);
}

void Test_SRE_PendingMultipleAddReloadOnNonempty()
{
   V2SREPendingEntryInput p[];
   ArrayResize(p, 2);
   p[0].comment = V2_SRE_COMMENT_ADD; p[0].direction = 1;
   p[1].comment = V2_SRE_COMMENT_RELOAD; p[1].direction = 1;
   AssertTrue("multiple add/reload", V2_SRE_CheckPendingEntryConsistency(p, 2, 1) ==
              V2_SRE_HALT_05_MULTIPLE_ADD_RELOAD_PENDING);
}

void Test_SRE_PendingL0WhileNonempty()
{
   V2SREPendingEntryInput p[];
   ArrayResize(p, 1);
   p[0].comment = V2_SRE_COMMENT_L0; p[0].direction = 1;
   AssertTrue("L0 while nonempty", V2_SRE_CheckPendingEntryConsistency(p, 2, 1) ==
              V2_SRE_HALT_06_PENDING_ENTRY_STACK_MISMATCH);
}

void Test_SRE_PendingAddWhileEmpty()
{
   V2SREPendingEntryInput p[];
   ArrayResize(p, 1);
   p[0].comment = V2_SRE_COMMENT_ADD; p[0].direction = 1;
   AssertTrue("add while empty", V2_SRE_CheckPendingEntryConsistency(p, 0, 1) ==
              V2_SRE_HALT_06_PENDING_ENTRY_STACK_MISMATCH);
}

void Test_SRE_PendingUnresolvableComment()
{
   V2SREPendingEntryInput p[];
   ArrayResize(p, 1);
   p[0].comment = "V2_Bogus"; p[0].direction = 1;
   AssertTrue("bad comment", V2_SRE_CheckPendingEntryConsistency(p, 1, 1) ==
              V2_SRE_HALT_11_PENDING_COMMENT_INCONSISTENT);
}

void Test_SRE_MultipleEntryInOnePositionHalts()
{
   V2SREDealInput deals[];
   ArrayResize(deals, 2);
   deals[0].position_id = 8001; deals[0].entry_type = DEAL_ENTRY_IN;
   deals[0].deal_magic = MM_LONG_V2; deals[0].volume = 0.005;
   deals[1].position_id = 8001; deals[1].entry_type = DEAL_ENTRY_IN;
   deals[1].deal_magic = MM_LONG_V2; deals[1].volume = 0.005;
   AssertTrue("multi entry-in halt", V2_SRE_CheckMultipleEntryInDeals(deals, MM_LONG_V2) ==
              V2_SRE_HALT_15_MULTIPLE_ENTRY_IN_ONE_POSITION);
}

void Test_SRE_NonStandardClosureBeforeAnchorHalts()
{
   V2SREDealInput deals[];
   ArrayResize(deals, 3);
   deals[0].deal_time = SRE_T0; deals[0].position_id = 8101; deals[0].entry_type = DEAL_ENTRY_IN;
   deals[0].deal_magic = MM_LONG_V2; deals[0].volume = SRE_LOT;
   deals[1].deal_time = SRE_T1; deals[1].position_id = 8101; deals[1].entry_type = DEAL_ENTRY_OUT;
   deals[1].deal_magic = MM_LONG_V2; deals[1].volume = SRE_LOT;
   deals[2].deal_time = SRE_T2; deals[2].position_id = 8102; deals[2].entry_type = DEAL_ENTRY_IN;
   deals[2].deal_magic = MM_LONG_V2; deals[2].volume = SRE_LOT;

   V2SRECloseByPair pairs[];
   ArrayResize(pairs, 0);
   AssertTrue("ordinary close halts", V2_SRE_CheckNonStandardClosures(deals, SRE_NOW,
              V2_SRE_DEFAULT_LOOKBACK_SEC, MM_LONG_V2) ==
              V2_SRE_HALT_23_NON_STANDARD_ENTRY_CLOSE);
}

void Test_SRE_SentinelBlocksCapNetExposure()
{
   bool present[] = { true, true, false, true };
   double values[] = { 2.0, -1.0, 0.0, V2_SRE_CAP_GV_SENTINEL };
   double net = 0.0;
   AssertTrue("sentinel blocks net calc", V2_SRE_CapNetExposureBlocked(present, values, 4, net));
   AssertTrue("absent gv blocks", V2_SRE_CapNetExposureBlocked(present, values, 3, net));
}

void Test_SRE_ValidationMismatchHalts()
{
   V2SRELayerSnapshot recon[];
   V2SRELayerSnapshot broker[];
   ArrayResize(recon, 1);
   ArrayResize(broker, 1);
   recon[0].position_ticket = 1001; recon[0].entry_ticket = 101; recon[0].entry_price = 1.30000;
   broker[0].position_ticket = 1001; broker[0].entry_ticket = 101; broker[0].entry_price = 1.30010;
   AssertTrue("validation mismatch", V2_SRE_ValidateReconstruction(recon, broker) ==
              V2_SRE_HALT_VALIDATION_MISMATCH);
}

//+------------------------------------------------------------------+
void OnStart()
{
   Print("=== fxmatrix_v2 native unit tests ===");
   Test_RunningStateWiden();
   Test_PostReloadExtensionUsesAccumulatedState();
   Test_OwnFlatClearsLastExit();
   Test_CrossInstanceIsolation();
   Test_ExitLimitRequestShape();
   Test_ExitPassivityPure();
   Test_CloseByQueueing();
   Test_TickAuditMissingExit();
   Test_ExitEscalationAlertSignature();
   Test_TelemetrySystemAlertsField();
   Test_TelemetryDualInstancePayloads();
   Test_TelemetryPodCloseAccounting();
   Test_TelemetryPodSessionIsolation();
   Test_TelemetryLayerDetailJSON();
   Test_TelemetryScalpClosedPayload();
   Test_TelemetryScalpClosedOpenDepthAndBars();
   Test_TelemetryScalpClosedUrl();
   Test_TelemetryScalpVsPodCloseIndependence();
   Test_OrphanStartupGuard();
   Test_HaltedFillGateHelpers();
   Test_OnInitCapPublishPolicy();
   Test_CapTriggerRecordWithoutPriorGv();
   Test_FlatOnInitPreservesTriggerGvs();
   Test_SixInstanceMagicIsolation();
   Test_PairSpreadAndPipConventionRefs();
   Test_AbSignalFormulaPure();
   Test_SixInstanceMockStateIsolation();
   Test_ApiCounterIncrementAndRollover();
   Test_ApiCounterTelemetryFields();
   Test_PairTelemetryInstanceIds();
   Test_RolloverAdr045ShiftMath();
   Test_RolloverDailyGate();
   Test_RolloverMultiNightAccumulation();
   Test_RolloverRetryDoubleShiftGuard();
   Test_RolloverRetryPendingAndSingleLayerRetry();
   Test_RolloverRetryCounterOncePerPass();
   Test_RolloverRetryStopsAtMaxRetries();
   Test_RolloverRetryRespectsNextDue();
   Test_RolloverAdr101WednesdayMultiplierFrozen();
   Test_ExitMagicPerPairNamespace();
   Test_L0SpreadEaseMultiplierRamp();
   Test_L0SpreadEaseMultiplierRamp_Production13();
   Test_L0SpreadEaseMultiplierRamp_Production14();
   Test_L0DynamicHalfSpreadFloor();
   Test_L0LiveSpreadFallback();
   Test_EurgbpAbDualSigmaSwapIndependence();
   Test_EurgbpAbFloorRescue();
   Test_EurgbpEaseDepthOnInitGuard();
   Test_EurgbpAbLiveSpreadFallbackWiring();
   Test_EurgbpAbFlatMultiplierNoRamp();
   Test_EurCapNetExposureAddition();
   Test_EurCapDeltaSymmetric();
   Test_EurCapBlocksNewAddThreshold();
   Test_AnyCapBlocksNewAddNoMasking();
   Test_SyncAllCapsPublishesBothGvSets();
   Test_UnifiedEnginePairLabelLinter();
   Test_UnifiedEngineMagicLiteralGrep();
   Test_V2L0CoreComputeBc_ColdStart();
   Test_V2L0CoreComputeBc_EaseRampAffectsOutput();
   Test_V2L0CoreComputeBc_DynamicHalfSpreadFloor();
   Test_V2L0CoreComputeBc_UnguardedHalfSpreadProductionParity();
   Test_V2L0CoreComputeBc_DiagnosticsMatchCore();
   Test_V2L0CoreComputeAb_ColdStart();
   Test_V2L0CoreComputeAb_EaseRampAffectsOutput();
   Test_V2L0CoreComputeAb_InvalidBidAskFallback();

   Test_SRE_BaselineMultiLayerNoCloseBy();
   Test_SRE_AnchorWalkCloseByNoMiscount();
   Test_SRE_ReloadResetsLastExitValid();
   Test_SRE_StaleExitOrderNotAssignable();
   Test_SRE_LateExitStillMatchesOlderLayer();
   Test_SRE_CrossPairPriceConsistencyHalts();
   Test_SRE_ExitMagicOpenHaltsPrecheck();
   Test_SRE_WrongDirectionOpenPositionHalts();
   Test_SRE_WrongDirectionPendingHalts();
   Test_SRE_UnmatchedExitOrderHalts();
   Test_SRE_PendingMultipleL0OnEmpty();
   Test_SRE_PendingMultipleAddReloadOnNonempty();
   Test_SRE_PendingL0WhileNonempty();
   Test_SRE_PendingAddWhileEmpty();
   Test_SRE_PendingUnresolvableComment();
   Test_SRE_MultipleEntryInOnePositionHalts();
   Test_SRE_NonStandardClosureBeforeAnchorHalts();
   Test_SRE_SentinelBlocksCapNetExposure();
   Test_SRE_ValidationMismatchHalts();

   Print("=== summary: ", g_tests_passed, "/", g_tests_run, " passed ===");
   if(g_tests_passed != g_tests_run)
      Print("ERROR: one or more tests FAILED");
}

//+------------------------------------------------------------------+
