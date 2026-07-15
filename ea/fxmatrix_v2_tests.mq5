//+------------------------------------------------------------------+
//| fxmatrix_v2_tests.mq5 — native unit tests for production V2 logic |
//| Run in Strategy Tester or as script (OnStart). No live trading.   |
//+------------------------------------------------------------------+
#property copyright "fxmatrix"
#property version   "1.03"
#property script_show_inputs
#property strict

#include "fxmatrix_v2_logic.mqh"
#include "fxmatrix_v2_telemetry.mqh"

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

   Print("=== summary: ", g_tests_passed, "/", g_tests_run, " passed ===");
   if(g_tests_passed != g_tests_run)
      Print("ERROR: one or more tests FAILED");
}

//+------------------------------------------------------------------+
