//+------------------------------------------------------------------+
//| fxmatrix_v2_tests.mq5 — native unit tests for production V2 logic |
//| Run in Strategy Tester or as script (OnStart). No live trading.   |
//+------------------------------------------------------------------+
#property copyright "fxmatrix"
#property version   "1.08"
#property script_show_inputs
#property strict

#include "fxmatrix_v2_logic.mqh"
#include "fxmatrix_v2_exits.mqh"
#include "fxmatrix_v2_telemetry.mqh"
#include "fxmatrix_v2_signal.mqh"
#include "fxmatrix_v2_carry.mqh"

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
   Test_ExitMagicPerPairNamespace();

   Print("=== summary: ", g_tests_passed, "/", g_tests_run, " passed ===");
   if(g_tests_passed != g_tests_run)
      Print("ERROR: one or more tests FAILED");
}

//+------------------------------------------------------------------+
