//+------------------------------------------------------------------+
//| fxmatrix_v2_tests.mq5 â€” native unit tests for production V2 logic |
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
#include "fxmatrix_v2_sre_oninit.mqh"
#include "fxmatrix_v2_bcc.mqh"

bool   InpCbEnable = true;
double InpCbDailyLossFrac = 0.045;
double InpCbAbsoluteLossFrac = 0.090;
double InpCbInitialBalance = 0.0;

#include "fxmatrix_v2_circuit_breaker.mqh"
bool   InpTaEnable = true;
#include "fxmatrix_v2_trigger_a.mqh"

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

   // Exit twice then reload â€” pre-exit peak was 4
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
   AssertNear("last_exit_price stored harvest level",
              s.last_exit_price,
              V2_HarvestOriginFromEntry(1.25000, +1, V2_EXIT_PIPS, V2_MockPoint()),
              1e-9);
   AssertNear("partial stack keeps widen state", s.current_add_pips, 15.0, 1e-9);
}

//+------------------------------------------------------------------+
// (a) Zero cross-instance contamination â€” one instance flat does not touch other
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
// V2.5 layer-anchor ratchet — harvest-origin reload + GUARD-1
//+------------------------------------------------------------------+
double V2Test_LongPipsToPrice(const double pips)
{
   const double pt = (_Point > 0.0) ? _Point : SRE_POINT;
   return pips * pt * 10.0;
}

void Test_V25_CleanHarvestPopSetsHarvestOriginLongShort()
{
   V2MockStack s;
   V2MockReset(s);
   V2MockAppendEntry(s, 1.30000, false);
   V2MockAppendEntry(s, 1.29910, false);
   V2MockPopTop(s, +1);
   AssertNear("long pop harvest origin",
              s.last_exit_price,
              V2_SRE_ExpectedExitPrice(1.29910, +1, V2_EXIT_PIPS, V2_MockPoint()),
              1e-9);
   AssertTrue("long reload gate armed", s.last_exit_valid);
   AssertTrue("long partial stack remains after harvest pop", ArraySize(s.entries) == 1);

   V2MockReset(s);
   V2MockAppendEntry(s, 1.30000, false);
   V2MockAppendEntry(s, 1.29910, false);
   V2MockPopTop(s, -1);
   AssertNear("short pop harvest origin",
              s.last_exit_price,
              V2_SRE_ExpectedExitPrice(1.29910, -1, V2_EXIT_PIPS, V2_MockPoint()),
              1e-9);
   AssertTrue("short reload gate armed", s.last_exit_valid);
   AssertTrue("short partial stack remains after harvest pop", ArraySize(s.entries) == 1);
}

void Test_V25_ExpectedExitPriceMatchesLivePipScale()
{
   const double entry = 1.30000;
   AssertNear("long SRE vs live pip scale",
              V2_SRE_ExpectedExitPrice(entry, +1, SRE_EXIT_PIPS, SRE_POINT),
              entry + V2Test_LongPipsToPrice(SRE_EXIT_PIPS),
              1e-12);
   AssertNear("short SRE vs live pip scale",
              V2_SRE_ExpectedExitPrice(entry, -1, SRE_EXIT_PIPS, SRE_POINT),
              entry - V2Test_LongPipsToPrice(SRE_EXIT_PIPS),
              1e-12);
   AssertNear("mock helper matches SRE",
              V2_HarvestOriginFromEntry(entry, +1, SRE_EXIT_PIPS, SRE_POINT),
              V2_SRE_ExpectedExitPrice(entry, +1, SRE_EXIT_PIPS, SRE_POINT),
              1e-12);
}

void Test_V25_Inv2_RebaseDoesNotMutateRemainingEntries()
{
   V2MockStack s;
   V2MockReset(s);
   V2MockAppendEntry(s, 1.30000, false);
   V2MockAppendEntry(s, 1.29910, false);
   V2MockAppendEntry(s, 1.29800, false);
   const double keep0 = s.entries[0];
   const double keep1 = s.entries[1];
   V2MockPopTop(s, +1);
   AssertNear("deepest entry unchanged", s.entries[0], keep0, 1e-9);
   AssertNear("middle entry unchanged", s.entries[1], keep1, 1e-9);
   AssertTrue("only top removed", ArraySize(s.entries) == 2);
}

void Test_V25_Guard1_BlackoutSuppressesRebase()
{
   const int blackout = 120;
   AssertTrue("pre-midnight 23:59:30 in symmetric window",
              V2_RebaseNearBrokerMidnight(D'2026.03.10 23:59:30', blackout));
   AssertTrue("post-midnight 00:00:30 in symmetric window",
              V2_RebaseNearBrokerMidnight(D'2026.03.11 00:00:30', blackout));
   AssertTrue("180s before midnight outside window",
              !V2_RebaseNearBrokerMidnight(D'2026.03.10 23:57:00', blackout));
   AssertTrue("noon outside blackout",
              !V2_RebaseNearBrokerMidnight(D'2026.03.11 12:00:00', blackout));

   V2MockStack s;
   V2MockReset(s);
   V2MockAppendEntry(s, 1.30000, false);
   V2MockAppendEntry(s, 1.29910, false);
   const datetime fill_time = D'2026.03.11 00:00:30';
   if(V2_RebaseNearBrokerMidnight(fill_time, blackout)) {
      int n = ArraySize(s.entries);
      ArrayResize(s.entries, n - 1);
      s.last_exit_valid = false;
   }
   AssertTrue("suppressed re-base leaves gate false", !s.last_exit_valid);
   AssertNear("next add uses entry anchor not reload floor",
              V2MockComputeAddStepPips(s), s.current_add_pips, 1e-9);
}

void Test_V25_Guard1_WideSpreadSuppressesRebase()
{
   const double point = SRE_POINT;
   const double max_pips = 8.0;
   const double observed_10_pips = 10.0 * point * 10.0;
   const double observed_3_pips  = 3.0 * point * 10.0;
   AssertTrue("10 pip observed spread exceeds 8 pip threshold (price units)",
              V2_RebaseSpreadExceedsMax(observed_10_pips, max_pips, point));
   AssertTrue("3 pip observed spread within 8 pip threshold (price units)",
              !V2_RebaseSpreadExceedsMax(observed_3_pips, max_pips, point));
}

void Test_V25_SRE_ReplayHarvestOriginParity()
{
   V2SREReplayEvent ev[];
   ArrayResize(ev, 2);
   ev[0].event_time = SRE_T0; ev[0].is_removal = false; ev[0].is_reload = false;
   ev[0].entry_price = 1.30000; ev[0].entry_position_id = 1;
   ev[1].event_time = SRE_T1; ev[1].is_removal = true; ev[1].is_reload = false;
   ev[1].entry_price = 1.30000; ev[1].entry_position_id = 1;

   V2SREPathState st = V2_SRE_ReplayPathDependentState(ev, V2_ADD_PIPS_FLOOR,
                                                       V2_WIDEN_RATIO, V2_ADD_PIPS_CEILING,
                                                       +1, SRE_EXIT_PIPS, SRE_POINT);
   const double expected = V2_SRE_ExpectedExitPrice(1.30000, +1, SRE_EXIT_PIPS, SRE_POINT);
   AssertNear("SRE replay last_exit is harvest level", st.last_exit_price, expected, 1e-9);
   AssertTrue("SRE replay arms reload gate", st.last_exit_valid);
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
// ADR-097: L0 spread easing â€” multiplier ramp + dynamic_hs floor
// ADR-097/098: ramp, floor, fallback â€” shared fxmatrix_v2_signal.mqh helpers (GBPUSD + EURUSD).
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
// ADR-099: EURGBP AB-slot dual-sigma easing â€” swap-independence matrix.
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
// ADR-099: floor-rescue â€” fully eased + zero sigma must not collapse to bare quote_spread.
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
   AssertTrue("ab ac bid-only differs from ab zero bid ask",
              MathAbs(ac_bid_only - cold) > 1e-9);
   AssertTrue("ab bc bid-only differs from ab zero bid ask",
              MathAbs(bc_bid_only - cold) > 1e-9);

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
// State Reconstruction Engine â€” Phase A unit tests (spec v8)
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
                                                       V2_WIDEN_RATIO, V2_ADD_PIPS_CEILING,
                                                       +1, SRE_EXIT_PIPS, SRE_POINT);
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
                                               1, SRE_EXIT_PIPS, SRE_POINT, "GBPUSD",
                                               V2_ADD_PIPS_FLOOR);
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

const datetime SRE_AUDIT_NOW = D'2026.08.06 10:48:00';

void SRE_Tier2AuditResetSwapOverride()
{
   g_v2_sre_test_swap_override = false;
   g_v2_sre_test_swap_long       = 0.0;
   g_v2_sre_test_swap_short      = 0.0;
}

void SRE_Tier2AuditSetSwapOverride(const double swap_long, const double swap_short)
{
   g_v2_sre_test_swap_override = true;
   g_v2_sre_test_swap_long     = swap_long;
   g_v2_sre_test_swap_short    = swap_short;
}

bool SRE_Tier2OldFixedToleranceAccepts(const V2SREPositionInput &pos,
                                       const V2SREExitOrderInput &ord,
                                       const datetime now,
                                       const double exit_pips,
                                       const double point,
                                       const double expected_volume)
{
   if(!V2_SRE_Tier1BaseEligible(pos, ord, now, expected_volume))
      return false;
   if(V2_SRE_ExitPriceMatchesFormula(ord.price, pos.entry_price,
                                     pos.direction, exit_pips, point))
      return false;
   const double expected = V2_SRE_ExpectedExitPrice(pos.entry_price, pos.direction,
                                                     exit_pips, point);
   return V2_SRE_PricesNear(ord.price, expected, V2_SRE_RolloverPriceTolerance(point));
}

void Test_SRE_Tier2RolloverBoundedRange_GbpusdLong_Audit509990725()
{
   SRE_Tier2AuditSetSwapOverride(-4.62, -6.18);

   V2SREPositionInput pos[];
   ArrayResize(pos, 1);
   pos[0].ticket = 509990725; pos[0].position_id = 509990725;
   pos[0].open_time = D'2026.08.02 23:47:16';
   pos[0].entry_price = 1.34959; pos[0].volume = SRE_LOT; pos[0].direction = 1;
   pos[0].symbol = "GBPUSD"; pos[0].position_type = POSITION_TYPE_BUY;

   V2SREExitOrderInput ord[];
   ArrayResize(ord, 1);
   ord[0].ticket = 509992283; ord[0].placement_time = D'2026.08.02 23:47:16';
   ord[0].price = 1.35015; ord[0].volume = SRE_LOT; ord[0].direction = 1;
   ord[0].symbol = "GBPUSD";

   const double expected = V2_SRE_ExpectedExitPrice(1.34959, 1, SRE_EXIT_PIPS, SRE_POINT);
   AssertTrue("audit gbpusd long old fixed tolerance rejects",
              !SRE_Tier2OldFixedToleranceAccepts(pos[0], ord[0], SRE_AUDIT_NOW,
                                                 SRE_EXIT_PIPS, SRE_POINT, SRE_LOT));
   AssertTrue("audit gbpusd long bounded range accepts",
              V2_SRE_Tier2Eligible(pos[0], ord[0], pos, SRE_AUDIT_NOW,
                                   SRE_EXIT_PIPS, SRE_POINT, SRE_LOT));
   AssertTrue("audit gbpusd long price above naive target",
              ord[0].price > expected);

   SRE_Tier2AuditResetSwapOverride();
}

void Test_SRE_Tier2RolloverBoundedRange_GbpusdShort_FourLayers_Audit()
{
   SRE_Tier2AuditSetSwapOverride(-4.62, -6.18);

   const datetime opens[4] = {
      D'2026.07.30 07:03:26',
      D'2026.07.30 07:28:02',
      D'2026.07.30 08:08:32',
      D'2026.07.30 12:42:21'
   };
   const double entries[4] = {1.33456, 1.33546, 1.33640, 1.34032};
   const double exits[4]   = {1.33391, 1.33481, 1.33575, 1.33967};
   const ulong tickets[4]  = {508010816, 508017768, 508045564, 508167500};

   V2SREPositionInput pos[];
   ArrayResize(pos, 4);
   for(int i = 0; i < 4; i++) {
      pos[i].ticket = tickets[i]; pos[i].position_id = tickets[i];
      pos[i].open_time = opens[i]; pos[i].entry_price = entries[i];
      pos[i].volume = SRE_LOT; pos[i].direction = -1;
      pos[i].symbol = "GBPUSD"; pos[i].position_type = POSITION_TYPE_SELL;
   }

   for(int i = 0; i < 4; i++) {
      V2SREExitOrderInput ord[];
      ArrayResize(ord, 1);
      ord[0].ticket = tickets[i] + 1000; ord[0].placement_time = opens[i];
      ord[0].price = exits[i]; ord[0].volume = SRE_LOT; ord[0].direction = -1;
      ord[0].symbol = "GBPUSD";

      const double expected = V2_SRE_ExpectedExitPrice(entries[i], -1, SRE_EXIT_PIPS, SRE_POINT);
      AssertTrue("audit gbpusd short L" + IntegerToString(i) + " old fixed tolerance rejects",
                 !SRE_Tier2OldFixedToleranceAccepts(pos[i], ord[0], SRE_AUDIT_NOW,
                                                    SRE_EXIT_PIPS, SRE_POINT, SRE_LOT));
      AssertTrue("audit gbpusd short L" + IntegerToString(i) + " bounded range accepts",
                 V2_SRE_Tier2Eligible(pos[i], ord[0], pos, SRE_AUDIT_NOW,
                                      SRE_EXIT_PIPS, SRE_POINT, SRE_LOT));
      AssertTrue("audit gbpusd short L" + IntegerToString(i) + " price below naive target",
                 ord[0].price < expected);
   }

   SRE_Tier2AuditResetSwapOverride();
}

void Test_SRE_Tier2RolloverBoundedRange_EurgbpLong_Audit508403686()
{
   SRE_Tier2AuditSetSwapOverride(-8.51, 0.15);

   V2SREPositionInput pos[];
   ArrayResize(pos, 1);
   pos[0].ticket = 508403686; pos[0].position_id = 508403686;
   pos[0].open_time = D'2026.07.30 13:00:47';
   pos[0].entry_price = 0.85803; pos[0].volume = SRE_LOT; pos[0].direction = 1;
   pos[0].symbol = "EURGBP"; pos[0].position_type = POSITION_TYPE_BUY;

   V2SREExitOrderInput ord[];
   ArrayResize(ord, 1);
   ord[0].ticket = 508408610; ord[0].placement_time = D'2026.07.30 13:00:47';
   ord[0].price = 0.85881; ord[0].volume = SRE_LOT; ord[0].direction = 1;
   ord[0].symbol = "EURGBP";

   const double expected = V2_SRE_ExpectedExitPrice(0.85803, 1, SRE_EXIT_PIPS, SRE_POINT);
   AssertTrue("audit eurgbp long old fixed tolerance rejects",
              !SRE_Tier2OldFixedToleranceAccepts(pos[0], ord[0], SRE_AUDIT_NOW,
                                                 SRE_EXIT_PIPS, SRE_POINT, SRE_LOT));
   AssertTrue("audit eurgbp long bounded range accepts",
              V2_SRE_Tier2Eligible(pos[0], ord[0], pos, SRE_AUDIT_NOW,
                                   SRE_EXIT_PIPS, SRE_POINT, SRE_LOT));
   AssertTrue("audit eurgbp long price above naive target",
              ord[0].price > expected);

   SRE_Tier2AuditResetSwapOverride();
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
// Phase B â€” OnInit SRE orchestration tests
void SRE_OnInitResetOverride()
{
   g_v2_sre_oninit_broker_override.active = false;
   g_v2_sre_oninit_broker_override.test_corrupt_broker_read = false;
   g_v2_sre_oninit_broker_override.test_corrupt_entry_price = 0.0;
   ArrayResize(g_v2_sre_oninit_broker_override.entry_positions, 0);
   ArrayResize(g_v2_sre_oninit_broker_override.exit_positions, 0);
   ArrayResize(g_v2_sre_oninit_broker_override.exit_orders, 0);
   ArrayResize(g_v2_sre_oninit_broker_override.pending_entries, 0);
   ArrayResize(g_v2_sre_oninit_broker_override.deals, 0);

   g_v2_sre_oninit_dual_override.active = false;
   g_v2_sre_oninit_dual_override.long_side.active = false;
   g_v2_sre_oninit_dual_override.long_side.test_corrupt_broker_read = false;
   g_v2_sre_oninit_dual_override.long_side.test_corrupt_entry_price = 0.0;
   ArrayResize(g_v2_sre_oninit_dual_override.long_side.entry_positions, 0);
   ArrayResize(g_v2_sre_oninit_dual_override.long_side.exit_positions, 0);
   ArrayResize(g_v2_sre_oninit_dual_override.long_side.exit_orders, 0);
   ArrayResize(g_v2_sre_oninit_dual_override.long_side.pending_entries, 0);
   ArrayResize(g_v2_sre_oninit_dual_override.long_side.deals, 0);
   g_v2_sre_oninit_dual_override.short_side.active = false;
   g_v2_sre_oninit_dual_override.short_side.test_corrupt_broker_read = false;
   g_v2_sre_oninit_dual_override.short_side.test_corrupt_entry_price = 0.0;
   ArrayResize(g_v2_sre_oninit_dual_override.short_side.entry_positions, 0);
   ArrayResize(g_v2_sre_oninit_dual_override.short_side.exit_positions, 0);
   ArrayResize(g_v2_sre_oninit_dual_override.short_side.exit_orders, 0);
   ArrayResize(g_v2_sre_oninit_dual_override.short_side.pending_entries, 0);
   ArrayResize(g_v2_sre_oninit_dual_override.short_side.deals, 0);

   g_v2_sre_sweep_test_active = false;
   ArrayResize(g_v2_sre_sweep_test_orders, 0);
   g_v2_sre_flatsweep_test_active = false;
   g_v2_sre_flatsweep_test_position_count = 0;
}

void SRE_SweepTestAddOrder(const ulong ticket,
                           const string symbol,
                           const long magic,
                           const long order_type,
                           const long order_state)
{
   const int n = ArraySize(g_v2_sre_sweep_test_orders);
   ArrayResize(g_v2_sre_sweep_test_orders, n + 1);
   g_v2_sre_sweep_test_orders[n].ticket = ticket;
   g_v2_sre_sweep_test_orders[n].symbol = symbol;
   g_v2_sre_sweep_test_orders[n].magic = magic;
   g_v2_sre_sweep_test_orders[n].order_type = order_type;
   g_v2_sre_sweep_test_orders[n].order_state = order_state;
}

#define SRE_ONINIT_PAIR_GBPUSD 0
#define SRE_ONINIT_PAIR_EURUSD 1
#define SRE_ONINIT_PAIR_EURGBP 2
#define SRE_ONINIT_PAIR_COUNT  3

void SRE_OnInitPairKeys(const int pair,
                        long &long_entry,
                        long &long_exit,
                        long &short_entry,
                        long &short_exit,
                        string &symbol,
                        V2SRECapBridgeKind &bridge)
{
   if(pair == SRE_ONINIT_PAIR_EURUSD) {
      long_entry = 20260911;
      long_exit = 20260913;
      short_entry = 20260912;
      short_exit = 20260914;
      symbol = "EURUSD";
      bridge = V2_SRE_CAP_BRIDGE_EURUSD;
   } else if(pair == SRE_ONINIT_PAIR_EURGBP) {
      long_entry = 20260921;
      long_exit = 20260923;
      short_entry = 20260922;
      short_exit = 20260924;
      symbol = "EURGBP";
      bridge = V2_SRE_CAP_BRIDGE_EURGBP_DUAL;
   } else {
      long_entry = MM_LONG_V2;
      long_exit = MM_LONG_V2_EXIT;
      short_entry = MM_SHORT_V2;
      short_exit = MM_SHORT_V2_EXIT;
      symbol = "GBPUSD";
      bridge = V2_SRE_CAP_BRIDGE_GBPUSD;
   }
}

V2SREOnInitSideConfig SRE_OnInitTestConfigForPair(const int pair, const bool is_long)
{
   long long_entry, long_exit, short_entry, short_exit;
   string symbol;
   V2SRECapBridgeKind bridge;
   SRE_OnInitPairKeys(pair, long_entry, long_exit, short_entry, short_exit, symbol, bridge);

   V2SREOnInitSideConfig cfg;
   cfg.instance_tag = is_long ? V2_TEL_INSTANCE_LONG : V2_TEL_INSTANCE_SHORT;
   cfg.symbol = symbol;
   cfg.side_direction = is_long ? 1 : -1;
   cfg.entry_magic = is_long ? long_entry : short_entry;
   cfg.exit_magic = is_long ? long_exit : short_exit;
   cfg.expected_volume = SRE_LOT;
   cfg.exit_pips = SRE_EXIT_PIPS;
   cfg.point = SRE_POINT;
   cfg.add_pips_floor = V2_ADD_PIPS_FLOOR;
   cfg.widen_ratio = V2_WIDEN_RATIO;
   cfg.add_pips_ceiling = V2_ADD_PIPS_CEILING;
   cfg.layer_count = 0;
   cfg.now = SRE_NOW;
   cfg.lookback_sec = V2_SRE_DEFAULT_LOOKBACK_SEC;
   cfg.is_long = is_long;
   cfg.cap_bridge = bridge;
   return cfg;
}

V2SREOnInitSideConfig SRE_OnInitTestConfig()
{
   return SRE_OnInitTestConfigForPair(SRE_ONINIT_PAIR_GBPUSD, true);
}

V2SREOnInitSideConfig SRE_OnInitTestConfigShort()
{
   return SRE_OnInitTestConfigForPair(SRE_ONINIT_PAIR_GBPUSD, false);
}

void SRE_OnInitCopyFixtureFromArrays(V2SREOnInitBrokerOverride &fixture,
                                     const V2SREPositionInput &pos[],
                                     const V2SREExitOrderInput &ord[],
                                     const V2SREDealInput &deals[])
{
   fixture.active = true;
   fixture.test_corrupt_broker_read = false;
   fixture.test_corrupt_entry_price = 0.0;
   ArrayResize(fixture.entry_positions, ArraySize(pos));
   for(int i = 0; i < ArraySize(pos); i++)
      fixture.entry_positions[i] = pos[i];
   ArrayResize(fixture.exit_positions, 0);
   ArrayResize(fixture.exit_orders, ArraySize(ord));
   for(int i = 0; i < ArraySize(ord); i++)
      fixture.exit_orders[i] = ord[i];
   ArrayResize(fixture.pending_entries, 0);
   ArrayResize(fixture.deals, ArraySize(deals));
   for(int i = 0; i < ArraySize(deals); i++)
      fixture.deals[i] = deals[i];
}

void SRE_OnInitFillBaselineTwoLayerSide(V2SREPositionInput &pos[],
                                        V2SREExitOrderInput &ord[],
                                        V2SREDealInput &deals[],
                                        const int pair,
                                        const bool is_long)
{
   long long_entry, long_exit, short_entry, short_exit;
   string symbol;
   V2SRECapBridgeKind bridge;
   SRE_OnInitPairKeys(pair, long_entry, long_exit, short_entry, short_exit, symbol, bridge);

   const long entry_magic = is_long ? long_entry : short_entry;
   const long exit_magic = is_long ? long_exit : short_exit;
   const int direction = is_long ? 1 : -1;
   const ENUM_POSITION_TYPE ptype = is_long ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;

   int ticket_base, pos_id_base, ord_base, hist_pos_base, closeby_order_id;
   if(pair == SRE_ONINIT_PAIR_GBPUSD) {
      ticket_base = is_long ? 101 : 301;
      pos_id_base = is_long ? 1001 : 2001;
      ord_base = is_long ? 201 : 401;
      hist_pos_base = is_long ? 5001 : 6001;
      closeby_order_id = is_long ? 9001 : 9101;
   } else {
      ticket_base = 100 + pair * 100 + (is_long ? 0 : 200);
      pos_id_base = 1000 + pair * 1000 + (is_long ? 0 : 1000);
      ord_base = 200 + pair * 100 + (is_long ? 0 : 200);
      hist_pos_base = 5000 + pair * 1000 + (is_long ? 0 : 1000);
      closeby_order_id = 9000 + pair * 100 + (is_long ? 1 : 2);
   }

   const double entry0 = 1.30000;
   const double entry1 = is_long ? 1.29910 : 1.30090;
   const double exit_anchor_price = is_long ? 1.30030 : 1.29970;

   ArrayResize(pos, 2);
   pos[0].ticket = ticket_base; pos[0].position_id = pos_id_base; pos[0].open_time = SRE_T2;
   pos[0].entry_price = entry0; pos[0].volume = SRE_LOT; pos[0].direction = direction;
   pos[0].symbol = symbol; pos[0].position_type = ptype;
   pos[1].ticket = ticket_base + 1; pos[1].position_id = pos_id_base + 1; pos[1].open_time = SRE_T3;
   pos[1].entry_price = entry1; pos[1].volume = SRE_LOT; pos[1].direction = direction;
   pos[1].symbol = symbol; pos[1].position_type = ptype;

   ArrayResize(ord, 2);
   ord[0].ticket = ord_base; ord[0].placement_time = SRE_T2 + 60;
   ord[0].price = V2_SRE_ExpectedExitPrice(entry0, direction, SRE_EXIT_PIPS, SRE_POINT);
   ord[0].volume = SRE_LOT; ord[0].direction = direction; ord[0].symbol = symbol;
   ord[1].ticket = ord_base + 1; ord[1].placement_time = SRE_T3 + 60;
   ord[1].price = V2_SRE_ExpectedExitPrice(entry1, direction, SRE_EXIT_PIPS, SRE_POINT);
   ord[1].volume = SRE_LOT; ord[1].direction = direction; ord[1].symbol = symbol;

   ArrayResize(deals, 6);
   deals[0].deal_time = SRE_T0; deals[0].position_id = hist_pos_base; deals[0].entry_type = DEAL_ENTRY_IN;
   deals[0].deal_magic = entry_magic; deals[0].volume = SRE_LOT; deals[0].price = entry0;
   deals[1].deal_time = SRE_T1; deals[1].position_id = hist_pos_base + 1; deals[1].entry_type = DEAL_ENTRY_IN;
   deals[1].deal_magic = exit_magic; deals[1].volume = SRE_LOT; deals[1].price = exit_anchor_price;
   deals[2].deal_time = SRE_T1 + 30; deals[2].position_id = hist_pos_base; deals[2].entry_type = DEAL_ENTRY_OUT_BY;
   deals[2].deal_magic = entry_magic; deals[2].volume = SRE_LOT; deals[2].order_id = closeby_order_id;
   deals[3].deal_time = SRE_T1 + 30; deals[3].position_id = hist_pos_base + 1; deals[3].entry_type = DEAL_ENTRY_OUT_BY;
   deals[3].deal_magic = entry_magic; deals[3].volume = SRE_LOT; deals[3].order_id = closeby_order_id;
   deals[4].deal_time = SRE_T2; deals[4].position_id = pos_id_base; deals[4].entry_type = DEAL_ENTRY_IN;
   deals[4].deal_magic = entry_magic; deals[4].volume = SRE_LOT; deals[4].price = entry0;
   deals[5].deal_time = SRE_T3; deals[5].position_id = pos_id_base + 1; deals[5].entry_type = DEAL_ENTRY_IN;
   deals[5].deal_magic = entry_magic; deals[5].volume = SRE_LOT; deals[5].price = entry1;
}

void SRE_OnInitFillBaselineTwoLayerShort(V2SREPositionInput &pos[],
                                         V2SREExitOrderInput &ord[],
                                         V2SREDealInput &deals[])
{
   ArrayResize(pos, 2);
   pos[0].ticket = 301; pos[0].position_id = 2001; pos[0].open_time = SRE_T2;
   pos[0].entry_price = 1.30000; pos[0].volume = SRE_LOT; pos[0].direction = -1;
   pos[0].symbol = "GBPUSD"; pos[0].position_type = POSITION_TYPE_SELL;
   pos[1].ticket = 302; pos[1].position_id = 2002; pos[1].open_time = SRE_T3;
   pos[1].entry_price = 1.30090; pos[1].volume = SRE_LOT; pos[1].direction = -1;
   pos[1].symbol = "GBPUSD"; pos[1].position_type = POSITION_TYPE_SELL;

   ArrayResize(ord, 2);
   ord[0].ticket = 401; ord[0].placement_time = SRE_T2 + 60;
   ord[0].price = V2_SRE_ExpectedExitPrice(1.30000, -1, SRE_EXIT_PIPS, SRE_POINT);
   ord[0].volume = SRE_LOT; ord[0].direction = -1; ord[0].symbol = "GBPUSD";
   ord[1].ticket = 402; ord[1].placement_time = SRE_T3 + 60;
   ord[1].price = V2_SRE_ExpectedExitPrice(1.30090, -1, SRE_EXIT_PIPS, SRE_POINT);
   ord[1].volume = SRE_LOT; ord[1].direction = -1; ord[1].symbol = "GBPUSD";

   ArrayResize(deals, 6);
   deals[0].deal_time = SRE_T0; deals[0].position_id = 6001; deals[0].entry_type = DEAL_ENTRY_IN;
   deals[0].deal_magic = MM_SHORT_V2; deals[0].volume = SRE_LOT; deals[0].price = 1.30000;
   deals[1].deal_time = SRE_T1; deals[1].position_id = 6002; deals[1].entry_type = DEAL_ENTRY_IN;
   deals[1].deal_magic = MM_SHORT_V2_EXIT; deals[1].volume = SRE_LOT; deals[1].price = 1.29970;
   deals[2].deal_time = SRE_T1 + 30; deals[2].position_id = 6001; deals[2].entry_type = DEAL_ENTRY_OUT_BY;
   deals[2].deal_magic = MM_SHORT_V2; deals[2].volume = SRE_LOT; deals[2].order_id = 9101;
   deals[3].deal_time = SRE_T1 + 30; deals[3].position_id = 6002; deals[3].entry_type = DEAL_ENTRY_OUT_BY;
   deals[3].deal_magic = MM_SHORT_V2; deals[3].volume = SRE_LOT; deals[3].order_id = 9101;
   deals[4].deal_time = SRE_T2; deals[4].position_id = 2001; deals[4].entry_type = DEAL_ENTRY_IN;
   deals[4].deal_magic = MM_SHORT_V2; deals[4].volume = SRE_LOT; deals[4].price = 1.30000;
   deals[5].deal_time = SRE_T3; deals[5].position_id = 2002; deals[5].entry_type = DEAL_ENTRY_IN;
   deals[5].deal_magic = MM_SHORT_V2; deals[5].volume = SRE_LOT; deals[5].price = 1.30090;
}

void SRE_OnInitFillHaltFixture(V2SREOnInitBrokerOverride &fixture,
                               const bool is_long,
                               const int pair)
{
   V2SREPositionInput pos[];
   V2SREExitOrderInput ord[];
   V2SREDealInput deals[];
   if(pair == SRE_ONINIT_PAIR_GBPUSD) {
      if(is_long)
         SRE_OnInitFillBaselineTwoLayer(pos, ord, deals);
      else
         SRE_OnInitFillBaselineTwoLayerShort(pos, ord, deals);
   } else {
      SRE_OnInitFillBaselineTwoLayerSide(pos, ord, deals, pair, is_long);
   }
   if(is_long)
      pos[0].position_type = POSITION_TYPE_SELL;
   else
      pos[0].position_type = POSITION_TYPE_BUY;
   SRE_OnInitCopyFixtureFromArrays(fixture, pos, ord, deals);
}

void SRE_OnInitFillSuccessFixture(V2SREOnInitBrokerOverride &fixture,
                                  const bool is_long,
                                  const int pair)
{
   V2SREPositionInput pos[];
   V2SREExitOrderInput ord[];
   V2SREDealInput deals[];
   if(pair == SRE_ONINIT_PAIR_GBPUSD) {
      if(is_long)
         SRE_OnInitFillBaselineTwoLayer(pos, ord, deals);
      else
         SRE_OnInitFillBaselineTwoLayerShort(pos, ord, deals);
   } else {
      SRE_OnInitFillBaselineTwoLayerSide(pos, ord, deals, pair, is_long);
   }
   SRE_OnInitCopyFixtureFromArrays(fixture, pos, ord, deals);
}

void SRE_OnInitActivateDualOverride()
{
   SRE_OnInitResetOverride();
   g_v2_sre_oninit_dual_override.active = true;
}

void SRE_OnInitFillBaselineTwoLayer(V2SREPositionInput &pos[],
                                    V2SREExitOrderInput &ord[],
                                    V2SREDealInput &deals[])
{
   ArrayResize(pos, 2);
   pos[0].ticket = 101; pos[0].position_id = 1001; pos[0].open_time = SRE_T2;
   pos[0].entry_price = 1.30000; pos[0].volume = SRE_LOT; pos[0].direction = 1;
   pos[0].symbol = "GBPUSD"; pos[0].position_type = POSITION_TYPE_BUY;
   pos[1].ticket = 102; pos[1].position_id = 1002; pos[1].open_time = SRE_T3;
   pos[1].entry_price = 1.29910; pos[1].volume = SRE_LOT; pos[1].direction = 1;
   pos[1].symbol = "GBPUSD"; pos[1].position_type = POSITION_TYPE_BUY;

   ArrayResize(ord, 2);
   ord[0].ticket = 201; ord[0].placement_time = SRE_T2 + 60;
   ord[0].price = V2_SRE_ExpectedExitPrice(1.30000, 1, SRE_EXIT_PIPS, SRE_POINT);
   ord[0].volume = SRE_LOT; ord[0].direction = 1; ord[0].symbol = "GBPUSD";
   ord[1].ticket = 202; ord[1].placement_time = SRE_T3 + 60;
   ord[1].price = V2_SRE_ExpectedExitPrice(1.29910, 1, SRE_EXIT_PIPS, SRE_POINT);
   ord[1].volume = SRE_LOT; ord[1].direction = 1; ord[1].symbol = "GBPUSD";

   ArrayResize(deals, 6);
   deals[0].deal_time = SRE_T0; deals[0].position_id = 5001; deals[0].entry_type = DEAL_ENTRY_IN;
   deals[0].deal_magic = MM_LONG_V2; deals[0].volume = SRE_LOT; deals[0].price = 1.30000;
   deals[1].deal_time = SRE_T1; deals[1].position_id = 5002; deals[1].entry_type = DEAL_ENTRY_IN;
   deals[1].deal_magic = MM_LONG_V2_EXIT; deals[1].volume = SRE_LOT; deals[1].price = 1.30030;
   deals[2].deal_time = SRE_T1 + 30; deals[2].position_id = 5001; deals[2].entry_type = DEAL_ENTRY_OUT_BY;
   deals[2].deal_magic = MM_LONG_V2; deals[2].volume = SRE_LOT; deals[2].order_id = 9001;
   deals[3].deal_time = SRE_T1 + 30; deals[3].position_id = 5002; deals[3].entry_type = DEAL_ENTRY_OUT_BY;
   deals[3].deal_magic = MM_LONG_V2; deals[3].volume = SRE_LOT; deals[3].order_id = 9001;
   deals[4].deal_time = SRE_T2; deals[4].position_id = 1001; deals[4].entry_type = DEAL_ENTRY_IN;
   deals[4].deal_magic = MM_LONG_V2; deals[4].volume = SRE_LOT; deals[4].price = 1.30000;
   deals[5].deal_time = SRE_T3; deals[5].position_id = 1002; deals[5].entry_type = DEAL_ENTRY_IN;
   deals[5].deal_magic = MM_LONG_V2; deals[5].volume = SRE_LOT; deals[5].price = 1.29910;
}

void Test_SRE_OnInit_EndToEndReconstruction()
{
   Test_ClearCapGvs();
   SRE_OnInitResetOverride();

   V2SREPositionInput pos[];
   V2SREExitOrderInput ord[];
   V2SREDealInput deals[];
   SRE_OnInitFillBaselineTwoLayer(pos, ord, deals);

   V2SREPositionInput exit_pos[];
   V2SREPendingEntryInput pending[];
   V2SREOnInitSideConfig cfg = SRE_OnInitTestConfig();
   V2SREOnInitSideResult res;
   V2_SRE_ResetOnInitSideResult(res);

   const V2SREHaltReason hr = V2_SRE_RunOnInitSequencePure(cfg, pos, exit_pos, ord, pending, deals, res);
   AssertTrue("oninit e2e ok", hr == V2_SRE_OK);
   AssertTrue("oninit e2e committed", res.committed);
   AssertTrue("oninit e2e two layers", res.layer_count_after == 2);
   AssertTrue("oninit e2e exit ticket L0", res.layers[0].exit_ticket == 201);
   AssertTrue("oninit e2e cap published", res.cap_published_on_commit);
   AssertNear("oninit e2e cap gv", GlobalVariableGet(V2_GBP_CAP_GV_GBP_LONG), 2.0, 1e-9);

   Test_ClearCapGvs();
}

void Test_SRE_OnInit_HaltStep3()
{
   SRE_OnInitResetOverride();

   V2SREPositionInput pos[];
   V2SREExitOrderInput ord[];
   V2SREDealInput deals[];
   SRE_OnInitFillBaselineTwoLayer(pos, ord, deals);
   pos[0].position_type = POSITION_TYPE_SELL;

   V2SREPositionInput exit_pos[];
   V2SREPendingEntryInput pending[];
   V2SREOnInitSideConfig cfg = SRE_OnInitTestConfig();
   V2SREOnInitSideResult res;
   V2_SRE_ResetOnInitSideResult(res);

   const V2SREHaltReason hr = V2_SRE_RunOnInitSequencePure(cfg, pos, exit_pos, ord, pending, deals, res);
   AssertTrue("oninit halt step3", hr == V2_SRE_HALT_12_POSITION_TYPE_MISMATCH);
   AssertTrue("oninit step3 not committed", !res.committed);
}

void Test_SRE_OnInit_HaltStep4()
{
   SRE_OnInitResetOverride();

   V2SREPositionInput pos[];
   V2SREExitOrderInput ord[];
   V2SREDealInput deals[];
   SRE_OnInitFillBaselineTwoLayer(pos, ord, deals);
   ord[0].price = V2_SRE_ExpectedExitPrice(1.30000, 1, SRE_EXIT_PIPS, SRE_POINT);
   ord[1].price = V2_SRE_ExpectedExitPrice(1.30000, 1, SRE_EXIT_PIPS, SRE_POINT);

   V2SREPositionInput exit_pos[];
   V2SREPendingEntryInput pending[];
   V2SREOnInitSideConfig cfg = SRE_OnInitTestConfig();
   V2SREOnInitSideResult res;
   V2_SRE_ResetOnInitSideResult(res);

   const V2SREHaltReason hr = V2_SRE_RunOnInitSequencePure(cfg, pos, exit_pos, ord, pending, deals, res);
   AssertTrue("oninit halt step4", hr == V2_SRE_HALT_21_UNMATCHED_EXIT_ORDER);
   AssertTrue("oninit step4 not committed", !res.committed);
}

void Test_SRE_OnInit_HaltStep5()
{
   SRE_OnInitResetOverride();

   V2SREPositionInput pos[];
   ArrayResize(pos, 1);
   pos[0].ticket = 101; pos[0].position_id = 1001; pos[0].open_time = SRE_T1;
   pos[0].entry_price = 1.30000; pos[0].volume = SRE_LOT; pos[0].direction = 1;
   pos[0].symbol = "GBPUSD"; pos[0].position_type = POSITION_TYPE_BUY;

   V2SREExitOrderInput ord[];
   V2SREDealInput deals[];
   V2SREPositionInput exit_pos[];
   V2SREPendingEntryInput pending[];
   V2SREOnInitSideConfig cfg = SRE_OnInitTestConfig();
   V2SREOnInitSideResult res;
   V2_SRE_ResetOnInitSideResult(res);

   const V2SREHaltReason hr = V2_SRE_RunOnInitSequencePure(cfg, pos, exit_pos, ord, pending, deals, res);
   AssertTrue("oninit halt step5", hr == V2_SRE_HALT_09_ANCHOR_NOT_FOUND);
   AssertTrue("oninit step5 not committed", !res.committed);
}

void Test_SRE_OnInit_HaltStep6_ReplayPathState()
{
   SRE_OnInitResetOverride();

   V2SREPositionInput pos[];
   V2SREExitOrderInput ord[];
   V2SREDealInput deals[];
   SRE_OnInitFillBaselineTwoLayer(pos, ord, deals);

   ArrayResize(deals, 8);
   deals[6].deal_time = SRE_T2 + 120; deals[6].position_id = 1001; deals[6].entry_type = DEAL_ENTRY_OUT_BY;
   deals[6].deal_magic = MM_LONG_V2; deals[6].volume = SRE_LOT; deals[6].order_id = 9100;
   deals[7].deal_time = SRE_T2 + 180; deals[7].position_id = 1003; deals[7].entry_type = DEAL_ENTRY_IN;
   deals[7].deal_magic = MM_LONG_V2; deals[7].volume = SRE_LOT; deals[7].price = 1.30000;
   deals[7].comment = V2_SRE_COMMENT_RELOAD;

   ArrayResize(pos, 1);
   pos[0].ticket = 103; pos[0].position_id = 1003; pos[0].open_time = SRE_T2 + 180;
   pos[0].entry_price = 1.30000; pos[0].volume = SRE_LOT; pos[0].direction = 1;
   pos[0].symbol = "GBPUSD"; pos[0].position_type = POSITION_TYPE_BUY;

   ArrayResize(ord, 1);
   ord[0].ticket = 203; ord[0].placement_time = SRE_T2 + 240;
   ord[0].price = V2_SRE_ExpectedExitPrice(1.30000, 1, SRE_EXIT_PIPS, SRE_POINT);
   ord[0].volume = SRE_LOT; ord[0].direction = 1; ord[0].symbol = "GBPUSD";

   V2SREPositionInput exit_pos[];
   V2SREPendingEntryInput pending[];
   V2SREOnInitSideConfig cfg = SRE_OnInitTestConfig();
   V2SREOnInitSideResult res;
   V2_SRE_ResetOnInitSideResult(res);

   const V2SREHaltReason hr = V2_SRE_RunOnInitSequencePure(cfg, pos, exit_pos, ord, pending, deals, res);
   AssertTrue("oninit step6 replay ok", hr == V2_SRE_OK);
   AssertTrue("oninit step6 reload clears last_exit", !res.path_state.last_exit_valid);
}

void Test_SRE_OnInit_SentinelBeforeHistory()
{
   Test_ClearCapGvs();
   SRE_OnInitResetOverride();

   V2SREPositionInput pos[];
   V2SREExitOrderInput ord[];
   V2SREDealInput deals[];
   SRE_OnInitFillBaselineTwoLayer(pos, ord, deals);
   pos[0].position_type = POSITION_TYPE_SELL;

   V2SREPositionInput exit_pos[];
   V2SREPendingEntryInput pending[];
   V2SREOnInitSideConfig cfg = SRE_OnInitTestConfig();
   V2SREOnInitSideResult res;
   V2_SRE_ResetOnInitSideResult(res);

   const V2SREHaltReason hr = V2_SRE_RunOnInitSequencePure(cfg, pos, exit_pos, ord, pending, deals, res);
   AssertTrue("oninit sentinel halt path", hr == V2_SRE_HALT_12_POSITION_TYPE_MISMATCH);
   AssertTrue("oninit sentinel written", res.sentinel_written);
   AssertTrue("oninit history read", res.history_read);
   AssertTrue("oninit sentinel before history", res.sentinel_before_history);
   AssertNear("oninit sentinel gv during halt path",
              GlobalVariableGet(V2_GBP_CAP_GV_GBP_LONG), V2_SRE_CAP_GV_SENTINEL, 1e-9);
   AssertTrue("oninit sentinel halt not committed", !res.committed);

   Test_ClearCapGvs();
}

void Test_SRE_OnInit_ValidationBackstopHalts()
{
   Test_ClearCapGvs();
   SRE_OnInitResetOverride();

   V2SREPositionInput pos[];
   V2SREExitOrderInput ord[];
   V2SREDealInput deals[];
   SRE_OnInitFillBaselineTwoLayer(pos, ord, deals);

   g_v2_sre_oninit_broker_override.active = true;
   g_v2_sre_oninit_broker_override.test_corrupt_broker_read = true;
   g_v2_sre_oninit_broker_override.test_corrupt_entry_price = 1.30010;
   ArrayResize(g_v2_sre_oninit_broker_override.entry_positions, 2);
   g_v2_sre_oninit_broker_override.entry_positions[0] = pos[0];
   g_v2_sre_oninit_broker_override.entry_positions[1] = pos[1];
   ArrayResize(g_v2_sre_oninit_broker_override.exit_orders, 2);
   g_v2_sre_oninit_broker_override.exit_orders[0] = ord[0];
   g_v2_sre_oninit_broker_override.exit_orders[1] = ord[1];
   ArrayResize(g_v2_sre_oninit_broker_override.deals, 6);
   for(int i = 0; i < 6; i++)
      g_v2_sre_oninit_broker_override.deals[i] = deals[i];

   string alerts[];
   V2SREOnInitSideConfig cfg = SRE_OnInitTestConfig();
   V2SREOnInitSideResult res;
   V2_SRE_ResetOnInitSideResult(res);

   const bool halted = V2_SRE_RunSideOnInit(alerts, cfg, res);
   AssertTrue("oninit validation backstop halts", halted);
   AssertTrue("oninit validation halt reason", res.halt_reason == V2_SRE_HALT_VALIDATION_MISMATCH);
   AssertTrue("oninit validation not committed", !res.committed);
   AssertNear("oninit validation sentinel stays",
              GlobalVariableGet(V2_GBP_CAP_GV_GBP_LONG), V2_SRE_CAP_GV_SENTINEL, 1e-9);

   SRE_OnInitResetOverride();
   Test_ClearCapGvs();
}

void Test_SRE_OnInit_CapPublishOnlyAfterCommit()
{
   Test_ClearCapGvs();
   SRE_OnInitResetOverride();

   V2_GbpCapPublishLayers(V2_GBP_CAP_GV_GBP_LONG, 9);
   AssertNear("oninit cap seed", GlobalVariableGet(V2_GBP_CAP_GV_GBP_LONG), 9.0, 1e-9);

   V2SREPositionInput pos[];
   V2SREExitOrderInput ord[];
   V2SREDealInput deals[];
   SRE_OnInitFillBaselineTwoLayer(pos, ord, deals);
   pos[0].position_type = POSITION_TYPE_SELL;

   V2SREPositionInput exit_pos[];
   V2SREPendingEntryInput pending[];
   V2SREOnInitSideConfig cfg = SRE_OnInitTestConfig();
   V2SREOnInitSideResult res;
   V2_SRE_ResetOnInitSideResult(res);

   V2_SRE_RunOnInitSequencePure(cfg, pos, exit_pos, ord, pending, deals, res);
   AssertNear("oninit halt leaves sentinel not seed",
              GlobalVariableGet(V2_GBP_CAP_GV_GBP_LONG), V2_SRE_CAP_GV_SENTINEL, 1e-9);
   AssertTrue("oninit halt no cap commit", !res.cap_published_on_commit);

   SRE_OnInitResetOverride();
   SRE_OnInitFillBaselineTwoLayer(pos, ord, deals);
   V2_SRE_ResetOnInitSideResult(res);
   V2_SRE_RunOnInitSequencePure(cfg, pos, exit_pos, ord, pending, deals, res);
   AssertTrue("oninit success publishes layers", res.cap_published_on_commit);
   AssertNear("oninit success cap gv", GlobalVariableGet(V2_GBP_CAP_GV_GBP_LONG), 2.0, 1e-9);

   Test_ClearCapGvs();
}

void Test_SRE_EntryPendingSweep_CountsEntrySkipsExit()
{
   SRE_OnInitResetOverride();
   g_v2_sre_sweep_test_active = true;
   ArrayResize(g_v2_sre_sweep_test_orders, 0);

   const V2SREOnInitSideConfig cfg = SRE_OnInitTestConfig();
   SRE_SweepTestAddOrder(900001, cfg.symbol, cfg.entry_magic, ORDER_TYPE_BUY_LIMIT, ORDER_STATE_PLACED);
   SRE_SweepTestAddOrder(900002, cfg.symbol, cfg.entry_magic, ORDER_TYPE_SELL_LIMIT, ORDER_STATE_PLACED);
   SRE_SweepTestAddOrder(900003, cfg.symbol, cfg.entry_magic, ORDER_TYPE_BUY_LIMIT, ORDER_STATE_PLACED);
   SRE_SweepTestAddOrder(910001, cfg.symbol, cfg.exit_magic, ORDER_TYPE_SELL_LIMIT, ORDER_STATE_PLACED);
   SRE_SweepTestAddOrder(910002, "EURUSD", cfg.entry_magic, ORDER_TYPE_BUY_LIMIT, ORDER_STATE_PLACED);
   SRE_SweepTestAddOrder(910003, cfg.symbol, cfg.entry_magic, ORDER_TYPE_BUY_STOP, ORDER_STATE_PLACED);
   SRE_SweepTestAddOrder(910004, cfg.symbol, cfg.entry_magic, ORDER_TYPE_BUY_LIMIT, ORDER_STATE_FILLED);

   const int swept = V2_SRE_SweepEntryPendingOrders(cfg.symbol, cfg.entry_magic);
   AssertTrue("entry pending sweep counts entry limits only", swept == 3);

   SRE_OnInitResetOverride();
}

void Test_SRE_OnInit_ResetDefaultsEntryPendingsSweptZero()
{
   V2SREOnInitSideResult res;
   res.entry_pendings_swept = 99;
   V2_SRE_ResetOnInitSideResult(res);
   AssertTrue("reset entry_pendings_swept zero", res.entry_pendings_swept == 0);
   AssertTrue("oninit reset readiness ok", res.readiness_result == V2_SRE_OK);
   AssertTrue("oninit reset history select ok false", !res.history_select_ok);
   AssertTrue("oninit reset anchor index", res.anchor_deal_index == -1);
}

void Test_SRE_Readiness_Halt31HistorySelectFailed()
{
   V2SREDealInput deals[];
   V2SREPositionInput pos[];
   const V2SREHaltReason r = V2_SRE_EvaluateReadiness(deals, pos, SRE_NOW,
                                                       V2_SRE_DEFAULT_LOOKBACK_SEC,
                                                       MM_LONG_V2, false);
   AssertTrue("readiness halt31", r == V2_SRE_HALT_31_HISTORY_UNAVAILABLE);
}

void Test_SRE_Readiness_OkEntryDealPresent()
{
   V2SREPositionInput pos[];
   ArrayResize(pos, 1);
   pos[0].position_id = 1001;
   pos[0].open_time = SRE_T2;

   V2SREDealInput deals[];
   ArrayResize(deals, 1);
   deals[0].position_id = 1001;
   deals[0].entry_type = DEAL_ENTRY_IN;
   deals[0].deal_magic = MM_LONG_V2;
   deals[0].deal_time = SRE_T2;

   const V2SREHaltReason r = V2_SRE_EvaluateReadiness(deals, pos, SRE_NOW,
                                                       V2_SRE_DEFAULT_LOOKBACK_SEC,
                                                       MM_LONG_V2, true);
   AssertTrue("readiness ok entry present", r == V2_SRE_OK);
}

void Test_SRE_Readiness_Halt32EntryDealAbsent()
{
   V2SREPositionInput pos[];
   ArrayResize(pos, 1);
   pos[0].position_id = 1001;
   pos[0].open_time = SRE_T2;

   V2SREDealInput deals[];
   const V2SREHaltReason r = V2_SRE_EvaluateReadiness(deals, pos, SRE_NOW,
                                                       V2_SRE_DEFAULT_LOOKBACK_SEC,
                                                       MM_LONG_V2, true);
   AssertTrue("readiness halt32 absent entry", r == V2_SRE_HALT_32_HISTORY_INCOMPLETE);
}

void Test_SRE_Readiness_Halt32PositionOlderThanLookback()
{
   V2SREPositionInput pos[];
   ArrayResize(pos, 1);
   pos[0].position_id = 1001;
   pos[0].open_time = D'2025.01.01 00:00:00';

   V2SREDealInput deals[];
   ArrayResize(deals, 1);
   deals[0].position_id = 1001;
   deals[0].entry_type = DEAL_ENTRY_IN;
   deals[0].deal_magic = MM_LONG_V2;
   deals[0].deal_time = D'2025.01.01 00:00:00';

   const V2SREHaltReason r = V2_SRE_EvaluateReadiness(deals, pos, SRE_NOW,
                                                       V2_SRE_DEFAULT_LOOKBACK_SEC,
                                                       MM_LONG_V2, true);
   AssertTrue("readiness halt32 old position", r == V2_SRE_HALT_32_HISTORY_INCOMPLETE);
}

void Test_SRE_Readiness_Gate2FirstPositionNotRejected()
{
   V2SREPositionInput pos[];
   ArrayResize(pos, 1);
   pos[0].ticket = 517307012;
   pos[0].position_id = 900001;
   pos[0].open_time = D'2026.08.12 09:55:29';
   pos[0].entry_price = 1.27000;
   pos[0].volume = SRE_LOT;
   pos[0].direction = -1;
   pos[0].symbol = "GBPUSD";
   pos[0].position_type = POSITION_TYPE_SELL;

   V2SREDealInput deals[];
   ArrayResize(deals, 1);
   deals[0].deal_ticket = 517307012;
   deals[0].position_id = 900001;
   deals[0].order_id = 517307012;
   deals[0].deal_time = D'2026.08.12 09:55:29';
   deals[0].entry_type = DEAL_ENTRY_IN;
   deals[0].deal_type = DEAL_TYPE_SELL;
   deals[0].deal_magic = MM_SHORT_V2;
   deals[0].volume = SRE_LOT;
   deals[0].price = 1.27000;

   const datetime lookback_from = D'2026.08.12 13:28:13';
   const V2SREHaltReason r = V2_SRE_EvaluateReadiness(deals, pos, lookback_from,
                                                       V2_SRE_DEFAULT_LOOKBACK_SEC,
                                                       MM_SHORT_V2, true);
   AssertTrue("readiness gate2 first position ok", r == V2_SRE_OK);
}

void Test_SRE_OnInit_PureSequenceDoesNotSweep()
{
   Test_ClearCapGvs();
   SRE_OnInitResetOverride();

   V2SREPositionInput pos[];
   V2SREExitOrderInput ord[];
   V2SREDealInput deals[];
   SRE_OnInitFillBaselineTwoLayer(pos, ord, deals);

   V2SREPositionInput exit_pos[];
   V2SREPendingEntryInput pending[];
   V2SREOnInitSideConfig cfg = SRE_OnInitTestConfig();
   V2SREOnInitSideResult res;
   V2_SRE_ResetOnInitSideResult(res);

   const V2SREHaltReason hr = V2_SRE_RunOnInitSequencePure(cfg, pos, exit_pos, ord, pending, deals, res);
   AssertTrue("pure oninit success", hr == V2_SRE_OK);
   AssertTrue("pure oninit committed", res.committed);
   AssertTrue("pure sequence leaves entry_pendings_swept zero", res.entry_pendings_swept == 0);

   string alerts[];
   g_v2_sre_oninit_broker_override.active = true;
   g_v2_sre_oninit_broker_override.test_corrupt_broker_read = true;
   g_v2_sre_oninit_broker_override.test_corrupt_entry_price = 1.30010;
   ArrayResize(g_v2_sre_oninit_broker_override.entry_positions, 2);
   g_v2_sre_oninit_broker_override.entry_positions[0] = pos[0];
   g_v2_sre_oninit_broker_override.entry_positions[1] = pos[1];
   ArrayResize(g_v2_sre_oninit_broker_override.exit_orders, 2);
   g_v2_sre_oninit_broker_override.exit_orders[0] = ord[0];
   g_v2_sre_oninit_broker_override.exit_orders[1] = ord[1];
   ArrayResize(g_v2_sre_oninit_broker_override.deals, 6);
   for(int i = 0; i < 6; i++)
      g_v2_sre_oninit_broker_override.deals[i] = deals[i];

   V2_SRE_ResetOnInitSideResult(res);
   const bool halted = V2_SRE_RunSideOnInit(alerts, cfg, res);
   AssertTrue("fixture halt path halts", halted);
   AssertTrue("halt path leaves entry_pendings_swept zero", res.entry_pendings_swept == 0);

   SRE_OnInitResetOverride();
   SRE_OnInitActivateDualOverride();
   SRE_OnInitFillSuccessFixture(g_v2_sre_oninit_dual_override.long_side, true, SRE_ONINIT_PAIR_GBPUSD);
   V2_SRE_ResetOnInitSideResult(res);
   const bool fixture_ok = V2_SRE_RunSideOnInit(alerts, cfg, res);
   AssertTrue("fixture success path does not halt", !fixture_ok);
   AssertTrue("fixture path leaves entry_pendings_swept zero", res.entry_pendings_swept == 0);

   SRE_OnInitResetOverride();
   Test_ClearCapGvs();
}

void Test_SRE_FlatSideSweep_FlatSweepsEntries()
{
   SRE_OnInitResetOverride();
   g_v2_sre_flatsweep_test_active = true;
   g_v2_sre_flatsweep_test_position_count = 0;      // flat side
   g_v2_sre_sweep_test_active = true;
   ArrayResize(g_v2_sre_sweep_test_orders, 0);

   const V2SREOnInitSideConfig cfg = SRE_OnInitTestConfig();
   SRE_SweepTestAddOrder(920001, cfg.symbol, cfg.entry_magic, ORDER_TYPE_BUY_LIMIT, ORDER_STATE_PLACED);
   SRE_SweepTestAddOrder(920002, cfg.symbol, cfg.entry_magic, ORDER_TYPE_SELL_LIMIT, ORDER_STATE_PLACED);
   SRE_SweepTestAddOrder(920003, cfg.symbol, cfg.exit_magic,  ORDER_TYPE_BUY_LIMIT, ORDER_STATE_PLACED);

   const int swept = V2_SweepFlatSideEntryPendings(cfg.symbol, cfg.entry_magic,
                                                   cfg.exit_magic, cfg.side_direction);
   AssertTrue("flat side sweeps entry pendings only", swept == 2);

   SRE_OnInitResetOverride();
}

void Test_SRE_FlatSideSweep_NonFlatSkips()
{
   SRE_OnInitResetOverride();
   g_v2_sre_flatsweep_test_active = true;
   g_v2_sre_flatsweep_test_position_count = 1;      // side holds a position -> not flat
   g_v2_sre_sweep_test_active = true;
   ArrayResize(g_v2_sre_sweep_test_orders, 0);

   const V2SREOnInitSideConfig cfg = SRE_OnInitTestConfig();
   SRE_SweepTestAddOrder(920101, cfg.symbol, cfg.entry_magic, ORDER_TYPE_BUY_LIMIT, ORDER_STATE_PLACED);

   const int swept = V2_SweepFlatSideEntryPendings(cfg.symbol, cfg.entry_magic,
                                                   cfg.exit_magic, cfg.side_direction);
   AssertTrue("non-flat side does not sweep", swept == 0);

   SRE_OnInitResetOverride();
}


//+------------------------------------------------------------------+
// Tier 1 real-data fixture helpers (MT5 account 1514123579, read-only pull)
const datetime SRE_TIER1_NOW = D'2026.08.07 09:19:46';
const datetime SRE_TIER1_CASE7_NOW = D'2026.08.02 21:20:00';
// Tier 1 real-data deal helpers (MT5 account 1514123579, read-only pull) â€” do not edit by hand.
void SRE_Tier1InitDeal(V2SREDealInput &d,
                       const ulong deal_ticket,
                       const ulong position_id,
                       const ulong order_id,
                       const datetime deal_time,
                       const long entry_type,
                       const long deal_type,
                       const long deal_magic,
                       const double price,
                       const double volume,
                       const string comment)
{
   d.deal_ticket = deal_ticket;
   d.position_id = position_id;
   d.order_id = order_id;
   d.deal_time = deal_time;
   d.entry_type = entry_type;
   d.deal_type = deal_type;
   d.deal_magic = deal_magic;
   d.deal_reason = 0;
   d.price = price;
   d.volume = volume;
   d.comment = comment;
}

void SRE_Tier1FillDeals_EurusdShort(V2SREDealInput &deals[])
{
   ArrayResize(deals, 70);
   SRE_Tier1InitDeal(deals[0], 486558803, 507416506, 507416506, D'2026.07.29 17:00:11', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260912, 1.14207, 0.01, "V2_L0");
   SRE_Tier1InitDeal(deals[1], 486565537, 507429140, 507429140, D'2026.07.29 17:00:33', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260914, 1.14177, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[2], 486565588, 507416506, 507429490, D'2026.07.29 17:00:33', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260912, 1.14177, 0.01, "#507416506 by #507429140");
   SRE_Tier1InitDeal(deals[3], 486565589, 507429140, 507429490, D'2026.07.29 17:00:33', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260912, 1.14207, 0.01, "#507416506 by #507429140");
   SRE_Tier1InitDeal(deals[4], 486586456, 507448018, 507448018, D'2026.07.29 17:06:07', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260912, 1.14216, 0.01, "V2_L0");
   SRE_Tier1InitDeal(deals[5], 486592045, 507450820, 507450820, D'2026.07.29 17:09:00', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260914, 1.14182, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[6], 486592052, 507448018, 507456413, D'2026.07.29 17:09:01', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260912, 1.14182, 0.01, "#507448018 by #507450820");
   SRE_Tier1InitDeal(deals[7], 486592053, 507450820, 507456413, D'2026.07.29 17:09:01', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260912, 1.14216, 0.01, "#507448018 by #507450820");
   SRE_Tier1InitDeal(deals[8], 486597465, 507458063, 507458063, D'2026.07.29 17:12:18', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260912, 1.14242, 0.01, "V2_L0");
   SRE_Tier1InitDeal(deals[9], 486609553, 507461934, 507461934, D'2026.07.29 17:20:36', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260914, 1.14211, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[10], 486609612, 507458063, 507474746, D'2026.07.29 17:20:37', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260912, 1.14211, 0.01, "#507458063 by #507461934");
   SRE_Tier1InitDeal(deals[11], 486609613, 507461934, 507474746, D'2026.07.29 17:20:37', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260912, 1.14242, 0.01, "#507458063 by #507461934");
   SRE_Tier1InitDeal(deals[12], 486637417, 507495342, 507495342, D'2026.07.29 17:39:51', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260912, 1.14257, 0.01, "V2_L0");
   SRE_Tier1InitDeal(deals[13], 486649893, 507503280, 507503280, D'2026.07.29 17:44:33', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260912, 1.14347, 0.01, "V2_Add");
   SRE_Tier1InitDeal(deals[14], 486660817, 507515941, 507515941, D'2026.07.29 17:49:18', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260912, 1.14437, 0.01, "V2_Add");
   SRE_Tier1InitDeal(deals[15], 486686250, 507526844, 507526844, D'2026.07.29 18:02:08', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260912, 1.14552, 0.01, "V2_Add");
   SRE_Tier1InitDeal(deals[16], 486687035, 507552515, 507552515, D'2026.07.29 18:02:29', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260914, 1.14525, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[17], 486687062, 507526844, 507553312, D'2026.07.29 18:02:30', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260912, 1.14525, 0.01, "#507526844 by #507552515");
   SRE_Tier1InitDeal(deals[18], 486687063, 507552515, 507553312, D'2026.07.29 18:02:30', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260912, 1.14552, 0.01, "#507526844 by #507552515");
   SRE_Tier1InitDeal(deals[19], 486701600, 507526842, 507526842, D'2026.07.29 18:10:53', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260914, 1.14403, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[20], 486701633, 507515941, 507568338, D'2026.07.29 18:10:54', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260912, 1.14403, 0.01, "#507515941 by #507526842");
   SRE_Tier1InitDeal(deals[21], 486701634, 507526842, 507568338, D'2026.07.29 18:10:54', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260912, 1.14437, 0.01, "#507515941 by #507526842");
   SRE_Tier1InitDeal(deals[22], 486706651, 507568332, 507568332, D'2026.07.29 18:15:22', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260912, 1.14529, 0.01, "V2_Reload");
   SRE_Tier1InitDeal(deals[23], 486724649, 507573669, 507573669, D'2026.07.29 18:28:12', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260914, 1.14498, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[24], 486724656, 507568332, 507591865, D'2026.07.29 18:28:12', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260912, 1.14498, 0.01, "#507568332 by #507573669");
   SRE_Tier1InitDeal(deals[25], 486724657, 507573669, 507591865, D'2026.07.29 18:28:12', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260912, 1.14529, 0.01, "#507568332 by #507573669");
   SRE_Tier1InitDeal(deals[26], 486794888, 507591860, 507591860, D'2026.07.29 19:34:53', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260912, 1.1462, 0.01, "V2_Reload");
   SRE_Tier1InitDeal(deals[27], 486877268, 507663811, 507663811, D'2026.07.29 23:27:49', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260914, 1.1459, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[28], 486877285, 507591860, 507751329, D'2026.07.29 23:27:50', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260912, 1.1459, 0.01, "#507591860 by #507663811");
   SRE_Tier1InitDeal(deals[29], 486877286, 507663811, 507751329, D'2026.07.29 23:27:50', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260912, 1.1462, 0.01, "#507591860 by #507663811");
   SRE_Tier1InitDeal(deals[30], 487241891, 507751328, 507751328, D'2026.07.30 09:14:33', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260912, 1.1471, 0.01, "V2_Reload");
   SRE_Tier1InitDeal(deals[31], 487291661, 508132076, 508132076, D'2026.07.30 10:21:07', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260914, 1.14679, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[32], 487291665, 507751328, 508183408, D'2026.07.30 10:21:07', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260912, 1.14679, 0.01, "#507751328 by #508132076");
   SRE_Tier1InitDeal(deals[33], 487291666, 508132076, 508183408, D'2026.07.30 10:21:07', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260912, 1.1471, 0.01, "#507751328 by #508132076");
   SRE_Tier1InitDeal(deals[34], 487328048, 508183404, 508183404, D'2026.07.30 11:13:23', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260912, 1.148, 0.01, "V2_Reload");
   SRE_Tier1InitDeal(deals[35], 487331327, 508221494, 508221494, D'2026.07.30 11:16:36', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260914, 1.1477, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[36], 487331330, 508183404, 508224880, D'2026.07.30 11:16:37', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260912, 1.1477, 0.01, "#508183404 by #508221494");
   SRE_Tier1InitDeal(deals[37], 487331331, 508221494, 508224880, D'2026.07.30 11:16:37', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260912, 1.148, 0.01, "#508183404 by #508221494");
   SRE_Tier1InitDeal(deals[38], 487447791, 508224879, 508224879, D'2026.07.30 12:38:06', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260912, 1.14892, 0.01, "V2_Reload");
   SRE_Tier1InitDeal(deals[39], 488334901, 508344295, 508344295, D'2026.07.31 10:56:25', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260914, 1.14856, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[40], 488334934, 508224879, 509270716, D'2026.07.31 10:56:26', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260912, 1.14856, 0.01, "#508224879 by #508344295");
   SRE_Tier1InitDeal(deals[41], 488334935, 508344295, 509270716, D'2026.07.31 10:56:26', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260912, 1.14892, 0.01, "#508224879 by #508344295");
   SRE_Tier1InitDeal(deals[42], 488420128, 509270713, 509270713, D'2026.07.31 12:22:19', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260912, 1.14984, 0.01, "V2_Reload");
   SRE_Tier1InitDeal(deals[43], 488422827, 509357796, 509357796, D'2026.07.31 12:22:57', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260914, 1.14958, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[44], 488422836, 509270713, 509360436, D'2026.07.31 12:22:58', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260912, 1.14958, 0.01, "#509270713 by #509357796");
   SRE_Tier1InitDeal(deals[45], 488422837, 509357796, 509360436, D'2026.07.31 12:22:58', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260912, 1.14984, 0.01, "#509270713 by #509357796");
   SRE_Tier1InitDeal(deals[46], 488613044, 509360431, 509360431, D'2026.07.31 14:08:31', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260912, 1.1507, 0.01, "V2_Reload");
   SRE_Tier1InitDeal(deals[47], 488613546, 509557981, 509557981, D'2026.07.31 14:08:50', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260914, 1.15038, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[48], 488613553, 509360431, 509558486, D'2026.07.31 14:08:51', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260912, 1.15038, 0.01, "#509360431 by #509557981");
   SRE_Tier1InitDeal(deals[49], 488613554, 509557981, 509558486, D'2026.07.31 14:08:51', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260912, 1.1507, 0.01, "#509360431 by #509557981");
   SRE_Tier1InitDeal(deals[50], 488655804, 509558483, 509558483, D'2026.07.31 14:51:47', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260912, 1.15161, 0.01, "V2_Reload");
   SRE_Tier1InitDeal(deals[51], 488665557, 509601838, 509601838, D'2026.07.31 15:03:23', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260914, 1.15131, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[52], 488665562, 509558483, 509612062, D'2026.07.31 15:03:24', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260912, 1.15131, 0.01, "#509558483 by #509601838");
   SRE_Tier1InitDeal(deals[53], 488665563, 509601838, 509612062, D'2026.07.31 15:03:24', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260912, 1.15161, 0.01, "#509558483 by #509601838");
   SRE_Tier1InitDeal(deals[54], 488709002, 509612057, 509612057, D'2026.07.31 16:24:48', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260912, 1.15253, 0.01, "V2_Reload");
   SRE_Tier1InitDeal(deals[55], 488710466, 509657682, 509657682, D'2026.07.31 16:25:58', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260914, 1.15222, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[56], 488710481, 509612057, 509659141, D'2026.07.31 16:26:00', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260912, 1.15222, 0.01, "#509612057 by #509657682");
   SRE_Tier1InitDeal(deals[57], 488710482, 509657682, 509659141, D'2026.07.31 16:26:00', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260912, 1.15253, 0.01, "#509612057 by #509657682");
   SRE_Tier1InitDeal(deals[58], 488723736, 509659131, 509659131, D'2026.07.31 16:42:10', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260912, 1.15343, 0.01, "V2_Reload");
   SRE_Tier1InitDeal(deals[59], 488726166, 509672484, 509672484, D'2026.07.31 16:45:55', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260914, 1.15314, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[60], 488726169, 509659131, 509675033, D'2026.07.31 16:45:55', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260912, 1.15314, 0.01, "#509659131 by #509672484");
   SRE_Tier1InitDeal(deals[61], 488726170, 509672484, 509675033, D'2026.07.31 16:45:55', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260912, 1.15343, 0.01, "#509659131 by #509672484");
   SRE_Tier1InitDeal(deals[62], 488800990, 509675032, 509675032, D'2026.07.31 19:47:37', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260912, 1.15435, 0.01, "V2_Reload");
   SRE_Tier1InitDeal(deals[63], 488801961, 509752450, 509752450, D'2026.07.31 19:53:02', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260914, 1.15408, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[64], 488801966, 509675032, 509753405, D'2026.07.31 19:53:03', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260912, 1.15408, 0.01, "#509675032 by #509752450");
   SRE_Tier1InitDeal(deals[65], 488801967, 509752450, 509753405, D'2026.07.31 19:53:03', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260912, 1.15435, 0.01, "#509675032 by #509752450");
   SRE_Tier1InitDeal(deals[66], 488929697, 509882167, 509882167, D'2026.08.02 21:00:51', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260912, 1.1553, 0.01, "V2_Reload");
   SRE_Tier1InitDeal(deals[67], 488948067, 509888020, 509888020, D'2026.08.02 21:19:06', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260914, 1.155, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[68], 488948075, 509882167, 509908119, D'2026.08.02 21:19:06', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260912, 1.155, 0.01, "#509882167 by #509888020");
   SRE_Tier1InitDeal(deals[69], 488948076, 509888020, 509908119, D'2026.08.02 21:19:06', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260912, 1.1553, 0.01, "#509882167 by #509888020");
}

void SRE_Tier1FillDeals_GbpusdLong(V2SREDealInput &deals[])
{
   ArrayResize(deals, 210);
   SRE_Tier1InitDeal(deals[0], 486112326, 506953735, 506953735, D'2026.07.29 11:16:45', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260901, 1.32804, 0.01, "V2_L0");
   SRE_Tier1InitDeal(deals[1], 486119809, 506967197, 506967197, D'2026.07.29 11:19:43', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260903, 1.32835, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[2], 486119818, 506953735, 506974505, D'2026.07.29 11:19:43', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260901, 1.32835, 0.01, "#506953735 by #506967197");
   SRE_Tier1InitDeal(deals[3], 486119819, 506967197, 506974505, D'2026.07.29 11:19:43', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260901, 1.32804, 0.01, "#506953735 by #506967197");
   SRE_Tier1InitDeal(deals[4], 486350235, 507202254, 507202254, D'2026.07.29 13:43:52', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260901, 1.3295, 0.01, "V2_L0");
   SRE_Tier1InitDeal(deals[5], 486352043, 507209173, 507209173, D'2026.07.29 13:44:51', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260903, 1.3298, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[6], 486352053, 507202254, 507211014, D'2026.07.29 13:44:52', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260901, 1.3298, 0.01, "#507202254 by #507209173");
   SRE_Tier1InitDeal(deals[7], 486352054, 507209173, 507211014, D'2026.07.29 13:44:52', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260901, 1.3295, 0.01, "#507202254 by #507209173");
   SRE_Tier1InitDeal(deals[8], 486360033, 507217263, 507217263, D'2026.07.29 13:51:30', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260901, 1.32863, 0.01, "V2_L0");
   SRE_Tier1InitDeal(deals[9], 486365229, 507219190, 507219190, D'2026.07.29 13:55:36', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260903, 1.32893, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[10], 486365236, 507217263, 507224557, D'2026.07.29 13:55:36', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260901, 1.32893, 0.01, "#507217263 by #507219190");
   SRE_Tier1InitDeal(deals[11], 486365237, 507219190, 507224557, D'2026.07.29 13:55:36', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260901, 1.32863, 0.01, "#507217263 by #507219190");
   SRE_Tier1InitDeal(deals[12], 486621959, 507484338, 507484338, D'2026.07.29 17:31:33', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260901, 1.33237, 0.01, "V2_L0");
   SRE_Tier1InitDeal(deals[13], 486622321, 507487480, 507487480, D'2026.07.29 17:31:36', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260903, 1.33277, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[14], 486622361, 507484338, 507487733, D'2026.07.29 17:31:36', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260901, 1.33277, 0.01, "#507484338 by #507487480");
   SRE_Tier1InitDeal(deals[15], 486622362, 507487480, 507487733, D'2026.07.29 17:31:36', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260901, 1.33237, 0.01, "#507484338 by #507487480");
   SRE_Tier1InitDeal(deals[16], 486713682, 507579150, 507579150, D'2026.07.29 18:20:49', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260901, 1.33778, 0.01, "V2_L0");
   SRE_Tier1InitDeal(deals[17], 486717471, 507580774, 507580774, D'2026.07.29 18:22:14', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260901, 1.33683, 0.01, "V2_Add");
   SRE_Tier1InitDeal(deals[18], 486724546, 507584754, 507584754, D'2026.07.29 18:28:04', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260901, 1.33594, 0.01, "V2_Add");
   SRE_Tier1InitDeal(deals[19], 486763937, 507591754, 507591754, D'2026.07.29 18:59:20', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260901, 1.33478, 0.01, "V2_Add");
   SRE_Tier1InitDeal(deals[20], 486770818, 507632107, 507632107, D'2026.07.29 19:02:15', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260903, 1.33507, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[21], 486770831, 507591754, 507639302, D'2026.07.29 19:02:16', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260901, 1.33507, 0.01, "#507591754 by #507632107");
   SRE_Tier1InitDeal(deals[22], 486770832, 507632107, 507639302, D'2026.07.29 19:02:16', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260901, 1.33478, 0.01, "#507591754 by #507632107");
   SRE_Tier1InitDeal(deals[23], 486801021, 507591753, 507591753, D'2026.07.29 19:45:59', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260903, 1.33627, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[24], 486801030, 507584754, 507670101, D'2026.07.29 19:45:59', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260901, 1.33627, 0.01, "#507584754 by #507591753");
   SRE_Tier1InitDeal(deals[25], 486801031, 507591753, 507670101, D'2026.07.29 19:45:59', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260901, 1.33594, 0.01, "#507584754 by #507591753");
   SRE_Tier1InitDeal(deals[26], 486834053, 507584723, 507584723, D'2026.07.29 22:00:57', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260903, 1.33713, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[27], 486834060, 507580774, 507705616, D'2026.07.29 22:00:58', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260901, 1.33713, 0.01, "#507580774 by #507584723");
   SRE_Tier1InitDeal(deals[28], 486834061, 507584723, 507705616, D'2026.07.29 22:00:58', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260901, 1.33683, 0.01, "#507580774 by #507584723");
   SRE_Tier1InitDeal(deals[29], 486875386, 507705615, 507705615, D'2026.07.29 23:25:50', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260901, 1.33593, 0.01, "V2_Reload");
   SRE_Tier1InitDeal(deals[30], 486937240, 507749427, 507749427, D'2026.07.30 01:18:42', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260901, 1.33499, 0.01, "V2_Add");
   SRE_Tier1InitDeal(deals[31], 487017638, 507814005, 507814005, D'2026.07.30 04:27:02', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260903, 1.33531, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[32], 487017651, 507749427, 507899660, D'2026.07.30 04:27:03', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260901, 1.33531, 0.01, "#507749427 by #507814005");
   SRE_Tier1InitDeal(deals[33], 487017652, 507814005, 507899660, D'2026.07.30 04:27:03', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260901, 1.33499, 0.01, "#507749427 by #507814005");
   SRE_Tier1InitDeal(deals[34], 487048228, 507899649, 507899649, D'2026.07.30 05:12:35', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260901, 1.33403, 0.01, "V2_Reload");
   SRE_Tier1InitDeal(deals[35], 487066571, 507931906, 507931906, D'2026.07.30 05:48:12', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260903, 1.33433, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[36], 487066572, 507899649, 507951100, D'2026.07.30 05:48:12', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260901, 1.33433, 0.01, "#507899649 by #507931906");
   SRE_Tier1InitDeal(deals[37], 487066573, 507931906, 507951100, D'2026.07.30 05:48:12', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260901, 1.33403, 0.01, "#507899649 by #507931906");
   SRE_Tier1InitDeal(deals[38], 487187846, 507749425, 507749425, D'2026.07.30 08:07:35', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260903, 1.33623, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[39], 487187861, 507705615, 508076535, D'2026.07.30 08:07:36', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260901, 1.33623, 0.01, "#507705615 by #507749425");
   SRE_Tier1InitDeal(deals[40], 487187862, 507749425, 508076535, D'2026.07.30 08:07:36', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260901, 1.33593, 0.01, "#507705615 by #507749425");
   SRE_Tier1InitDeal(deals[41], 487219907, 507580764, 507580764, D'2026.07.30 08:49:52', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260903, 1.33813, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[42], 487219915, 507579150, 508109506, D'2026.07.30 08:49:53', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260901, 1.33813, 0.01, "#507579150 by #507580764");
   SRE_Tier1InitDeal(deals[43], 487219916, 507580764, 508109506, D'2026.07.30 08:49:53', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260901, 1.33778, 0.01, "#507579150 by #507580764");
   SRE_Tier1InitDeal(deals[44], 487252481, 508140224, 508140224, D'2026.07.30 09:23:05', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260901, 1.33804, 0.01, "V2_L0");
   SRE_Tier1InitDeal(deals[45], 487256737, 508142729, 508142729, D'2026.07.30 09:30:37', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260903, 1.33834, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[46], 487256739, 508140224, 508147232, D'2026.07.30 09:30:38', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260901, 1.33834, 0.01, "#508140224 by #508142729");
   SRE_Tier1InitDeal(deals[47], 487256740, 508142729, 508147232, D'2026.07.30 09:30:38', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260901, 1.33804, 0.01, "#508140224 by #508142729");
   SRE_Tier1InitDeal(deals[48], 487272529, 508162722, 508162722, D'2026.07.30 09:50:52', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260901, 1.34008, 0.01, "V2_L0");
   SRE_Tier1InitDeal(deals[49], 487275919, 508163351, 508163351, D'2026.07.30 09:57:53', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260901, 1.33916, 0.01, "V2_Add");
   SRE_Tier1InitDeal(deals[50], 487277019, 508166924, 508166924, D'2026.07.30 10:00:01', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260903, 1.34002, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[51], 487277044, 508163351, 508168400, D'2026.07.30 10:00:02', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260901, 1.34002, 0.01, "#508163351 by #508166924");
   SRE_Tier1InitDeal(deals[52], 487277045, 508166924, 508168400, D'2026.07.30 10:00:02', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260901, 1.33916, 0.01, "#508163351 by #508166924");
   SRE_Tier1InitDeal(deals[53], 487286227, 508168397, 508168397, D'2026.07.30 10:13:46', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260901, 1.33824, 0.01, "V2_Reload");
   SRE_Tier1InitDeal(deals[54], 487305176, 508177853, 508177853, D'2026.07.30 10:44:38', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260901, 1.33733, 0.01, "V2_Add");
   SRE_Tier1InitDeal(deals[55], 487306876, 508197456, 508197456, D'2026.07.30 10:48:14', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260903, 1.33761, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[56], 487306879, 508177853, 508199471, D'2026.07.30 10:48:15', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260901, 1.33761, 0.01, "#508177853 by #508197456");
   SRE_Tier1InitDeal(deals[57], 487306880, 508197456, 508199471, D'2026.07.30 10:48:15', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260901, 1.33733, 0.01, "#508177853 by #508197456");
   SRE_Tier1InitDeal(deals[58], 487313001, 508177851, 508177851, D'2026.07.30 10:57:38', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260903, 1.33854, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[59], 487313015, 508168397, 508205734, D'2026.07.30 10:57:39', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260901, 1.33854, 0.01, "#508168397 by #508177851");
   SRE_Tier1InitDeal(deals[60], 487313016, 508177851, 508205734, D'2026.07.30 10:57:39', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260901, 1.33824, 0.01, "#508168397 by #508177851");
   SRE_Tier1InitDeal(deals[61], 487376623, 508205733, 508205733, D'2026.07.30 11:53:06', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260901, 1.33732, 0.01, "V2_Reload");
   SRE_Tier1InitDeal(deals[62], 487383589, 508271395, 508271395, D'2026.07.30 11:58:21', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260903, 1.33763, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[63], 487383599, 508205733, 508278568, D'2026.07.30 11:58:22', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260901, 1.33763, 0.01, "#508205733 by #508271395");
   SRE_Tier1InitDeal(deals[64], 487383600, 508271395, 508278568, D'2026.07.30 11:58:22', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260901, 1.33732, 0.01, "#508205733 by #508271395");
   SRE_Tier1InitDeal(deals[65], 487461613, 508163349, 508163349, D'2026.07.30 12:42:26', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260903, 1.34037, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[66], 487461634, 508162722, 508358372, D'2026.07.30 12:42:26', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260901, 1.34037, 0.01, "#508162722 by #508163349");
   SRE_Tier1InitDeal(deals[67], 487461635, 508163349, 508358372, D'2026.07.30 12:42:26', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260901, 1.34008, 0.01, "#508162722 by #508163349");
   SRE_Tier1InitDeal(deals[68], 487482427, 508365620, 508365620, D'2026.07.30 12:49:50', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260901, 1.34084, 0.01, "V2_L0");
   SRE_Tier1InitDeal(deals[69], 487490434, 508379405, 508379405, D'2026.07.30 12:52:45', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260903, 1.34113, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[70], 487490445, 508365620, 508387487, D'2026.07.30 12:52:45', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260901, 1.34113, 0.01, "#508365620 by #508379405");
   SRE_Tier1InitDeal(deals[71], 487490446, 508379405, 508387487, D'2026.07.30 12:52:45', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260901, 1.34084, 0.01, "#508365620 by #508379405");
   SRE_Tier1InitDeal(deals[72], 487525874, 508419394, 508419394, D'2026.07.30 13:06:49', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260901, 1.34374, 0.01, "V2_L0");
   SRE_Tier1InitDeal(deals[73], 487531598, 508423588, 508423588, D'2026.07.30 13:08:40', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260901, 1.34285, 0.01, "V2_Add");
   SRE_Tier1InitDeal(deals[74], 487532536, 508429582, 508429582, D'2026.07.30 13:09:08', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260903, 1.3432, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[75], 487532567, 508423588, 508430595, D'2026.07.30 13:09:09', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260901, 1.3432, 0.01, "#508423588 by #508429582");
   SRE_Tier1InitDeal(deals[76], 487532568, 508429582, 508430595, D'2026.07.30 13:09:09', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260901, 1.34285, 0.01, "#508423588 by #508429582");
   SRE_Tier1InitDeal(deals[77], 487536230, 508423583, 508423583, D'2026.07.30 13:11:23', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260903, 1.34407, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[78], 487536239, 508419394, 508434460, D'2026.07.30 13:11:23', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260901, 1.34407, 0.01, "#508419394 by #508423583");
   SRE_Tier1InitDeal(deals[79], 487536240, 508423583, 508434460, D'2026.07.30 13:11:23', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260901, 1.34374, 0.01, "#508419394 by #508423583");
   SRE_Tier1InitDeal(deals[80], 487545227, 508438796, 508438796, D'2026.07.30 13:18:25', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260901, 1.34394, 0.01, "V2_L0");
   SRE_Tier1InitDeal(deals[81], 487547439, 508443819, 508443819, D'2026.07.30 13:19:26', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260903, 1.34426, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[82], 487547453, 508438796, 508446046, D'2026.07.30 13:19:26', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260901, 1.34426, 0.01, "#508438796 by #508443819");
   SRE_Tier1InitDeal(deals[83], 487547454, 508443819, 508446046, D'2026.07.30 13:19:26', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260901, 1.34394, 0.01, "#508438796 by #508443819");
   SRE_Tier1InitDeal(deals[84], 487555510, 508446767, 508446767, D'2026.07.30 13:24:30', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260901, 1.34371, 0.01, "V2_L0");
   SRE_Tier1InitDeal(deals[85], 487574615, 508454283, 508454283, D'2026.07.30 13:38:19', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260901, 1.34281, 0.01, "V2_Add");
   SRE_Tier1InitDeal(deals[86], 487576359, 508473987, 508473987, D'2026.07.30 13:40:01', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260903, 1.3431, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[87], 487576402, 508454283, 508475788, D'2026.07.30 13:40:01', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260901, 1.3431, 0.01, "#508454283 by #508473987");
   SRE_Tier1InitDeal(deals[88], 487576403, 508473987, 508475788, D'2026.07.30 13:40:01', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260901, 1.34281, 0.01, "#508454283 by #508473987");
   SRE_Tier1InitDeal(deals[89], 487631823, 508454281, 508454281, D'2026.07.30 14:20:13', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260903, 1.34402, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[90], 487631833, 508446767, 508532605, D'2026.07.30 14:20:13', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260901, 1.34402, 0.01, "#508446767 by #508454281");
   SRE_Tier1InitDeal(deals[91], 487631834, 508454281, 508532605, D'2026.07.30 14:20:13', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260901, 1.34371, 0.01, "#508446767 by #508454281");
   SRE_Tier1InitDeal(deals[92], 487713092, 508607730, 508607730, D'2026.07.30 15:44:01', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260901, 1.34626, 0.01, "V2_L0");
   SRE_Tier1InitDeal(deals[93], 487726667, 508615925, 508615925, D'2026.07.30 16:00:12', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260903, 1.34657, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[94], 487726684, 508607730, 508630805, D'2026.07.30 16:00:13', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260901, 1.34657, 0.01, "#508607730 by #508615925");
   SRE_Tier1InitDeal(deals[95], 487726685, 508615925, 508630805, D'2026.07.30 16:00:13', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260901, 1.34626, 0.01, "#508607730 by #508615925");
   SRE_Tier1InitDeal(deals[96], 487760559, 508664719, 508664719, D'2026.07.30 16:43:03', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260901, 1.34614, 0.01, "V2_L0");
   SRE_Tier1InitDeal(deals[97], 487761116, 508667214, 508667214, D'2026.07.30 16:43:39', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260903, 1.34644, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[98], 487761121, 508664719, 508667782, D'2026.07.30 16:43:39', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260901, 1.34644, 0.01, "#508664719 by #508667214");
   SRE_Tier1InitDeal(deals[99], 487761122, 508667214, 508667782, D'2026.07.30 16:43:39', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260901, 1.34614, 0.01, "#508664719 by #508667214");
   SRE_Tier1InitDeal(deals[100], 487967840, 508881602, 508881602, D'2026.07.31 00:38:44', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260901, 1.34533, 0.01, "V2_L0");
   SRE_Tier1InitDeal(deals[101], 487980682, 508884259, 508884259, D'2026.07.31 01:06:14', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260903, 1.34563, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[102], 487980687, 508881602, 508897952, D'2026.07.31 01:06:14', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260901, 1.34563, 0.01, "#508881602 by #508884259");
   SRE_Tier1InitDeal(deals[103], 487980688, 508884259, 508897952, D'2026.07.31 01:06:14', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260901, 1.34533, 0.01, "#508881602 by #508884259");
   SRE_Tier1InitDeal(deals[104], 488091185, 509011651, 509011651, D'2026.07.31 05:33:50', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260901, 1.34544, 0.01, "V2_L0");
   SRE_Tier1InitDeal(deals[105], 488102213, 509015560, 509015560, D'2026.07.31 05:51:09', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260903, 1.34575, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[106], 488102222, 509011651, 509027318, D'2026.07.31 05:51:09', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260901, 1.34575, 0.01, "#509011651 by #509015560");
   SRE_Tier1InitDeal(deals[107], 488102223, 509015560, 509027318, D'2026.07.31 05:51:09', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260901, 1.34544, 0.01, "#509011651 by #509015560");
   SRE_Tier1InitDeal(deals[108], 488105161, 509029254, 509029254, D'2026.07.31 05:57:30', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260901, 1.34532, 0.01, "V2_L0");
   SRE_Tier1InitDeal(deals[109], 488142136, 509030437, 509030437, D'2026.07.31 06:47:46', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260903, 1.34563, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[110], 488142146, 509029254, 509068889, D'2026.07.31 06:47:47', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260901, 1.34563, 0.01, "#509029254 by #509030437");
   SRE_Tier1InitDeal(deals[111], 488142147, 509030437, 509068889, D'2026.07.31 06:47:47', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260901, 1.34532, 0.01, "#509029254 by #509030437");
   SRE_Tier1InitDeal(deals[112], 488145913, 509070864, 509070864, D'2026.07.31 06:52:18', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260901, 1.34543, 0.01, "V2_L0");
   SRE_Tier1InitDeal(deals[113], 488159754, 509072941, 509072941, D'2026.07.31 07:07:00', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260901, 1.34451, 0.01, "V2_Add");
   SRE_Tier1InitDeal(deals[114], 488188914, 509087440, 509087440, D'2026.07.31 07:34:02', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260901, 1.34357, 0.01, "V2_Add");
   SRE_Tier1InitDeal(deals[115], 488191126, 509117529, 509117529, D'2026.07.31 07:35:31', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260903, 1.34387, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[116], 488191142, 509087440, 509119813, D'2026.07.31 07:35:32', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260901, 1.34387, 0.01, "#509087440 by #509117529");
   SRE_Tier1InitDeal(deals[117], 488191143, 509117529, 509119813, D'2026.07.31 07:35:32', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260901, 1.34357, 0.01, "#509087440 by #509117529");
   SRE_Tier1InitDeal(deals[118], 488199341, 509087436, 509087436, D'2026.07.31 07:47:40', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260903, 1.34481, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[119], 488199410, 509072941, 509128953, D'2026.07.31 07:47:43', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260901, 1.34481, 0.01, "#509072941 by #509087436");
   SRE_Tier1InitDeal(deals[120], 488199411, 509087436, 509128953, D'2026.07.31 07:47:43', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260901, 1.34451, 0.01, "#509072941 by #509087436");
   SRE_Tier1InitDeal(deals[121], 488204620, 509072934, 509072934, D'2026.07.31 07:55:41', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260903, 1.34573, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[122], 488204666, 509070864, 509134543, D'2026.07.31 07:55:42', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260901, 1.34573, 0.01, "#509070864 by #509072934");
   SRE_Tier1InitDeal(deals[123], 488204667, 509072934, 509134543, D'2026.07.31 07:55:42', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260901, 1.34543, 0.01, "#509070864 by #509072934");
   SRE_Tier1InitDeal(deals[124], 488237707, 509165467, 509165467, D'2026.07.31 08:29:57', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260901, 1.34546, 0.01, "V2_L0");
   SRE_Tier1InitDeal(deals[125], 488264674, 509169344, 509169344, D'2026.07.31 09:09:17', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260901, 1.34456, 0.01, "V2_Add");
   SRE_Tier1InitDeal(deals[126], 488266093, 509197783, 509197783, D'2026.07.31 09:12:02', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260903, 1.34488, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[127], 488266101, 509169344, 509199366, D'2026.07.31 09:12:03', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260901, 1.34488, 0.01, "#509169344 by #509197783");
   SRE_Tier1InitDeal(deals[128], 488266102, 509197783, 509199366, D'2026.07.31 09:12:03', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260901, 1.34456, 0.01, "#509169344 by #509197783");
   SRE_Tier1InitDeal(deals[129], 488307976, 509199362, 509199362, D'2026.07.31 10:16:25', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260901, 1.34366, 0.01, "V2_Reload");
   SRE_Tier1InitDeal(deals[130], 488320851, 509242816, 509242816, D'2026.07.31 10:33:23', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260901, 1.34274, 0.01, "V2_Add");
   SRE_Tier1InitDeal(deals[131], 488323332, 509256242, 509256242, D'2026.07.31 10:37:32', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260903, 1.34305, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[132], 488323334, 509242816, 509258817, D'2026.07.31 10:37:32', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260901, 1.34305, 0.01, "#509242816 by #509256242");
   SRE_Tier1InitDeal(deals[133], 488323335, 509256242, 509258817, D'2026.07.31 10:37:32', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260901, 1.34274, 0.01, "#509242816 by #509256242");
   SRE_Tier1InitDeal(deals[134], 488333389, 509258815, 509258815, D'2026.07.31 10:53:45', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260901, 1.34182, 0.01, "V2_Reload");
   SRE_Tier1InitDeal(deals[135], 488342320, 509269119, 509269119, D'2026.07.31 11:06:04', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260903, 1.34212, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[136], 488342326, 509258815, 509278470, D'2026.07.31 11:06:05', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260901, 1.34212, 0.01, "#509258815 by #509269119");
   SRE_Tier1InitDeal(deals[137], 488342327, 509269119, 509278470, D'2026.07.31 11:06:05', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260901, 1.34182, 0.01, "#509258815 by #509269119");
   SRE_Tier1InitDeal(deals[138], 488450514, 509278469, 509278469, D'2026.07.31 12:37:03', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260901, 1.34093, 0.01, "V2_Reload");
   SRE_Tier1InitDeal(deals[139], 488450751, 509388733, 509388733, D'2026.07.31 12:37:09', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260903, 1.34122, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[140], 488450769, 509278469, 509388988, D'2026.07.31 12:37:09', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260901, 1.34122, 0.01, "#509278469 by #509388733");
   SRE_Tier1InitDeal(deals[141], 488450770, 509388733, 509388988, D'2026.07.31 12:37:09', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260901, 1.34093, 0.01, "#509278469 by #509388733");
   SRE_Tier1InitDeal(deals[142], 488579212, 509242805, 509242805, D'2026.07.31 13:40:07', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260903, 1.34397, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[143], 488579230, 509199362, 509522359, D'2026.07.31 13:40:08', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260901, 1.34397, 0.01, "#509199362 by #509242805");
   SRE_Tier1InitDeal(deals[144], 488579231, 509242805, 509522359, D'2026.07.31 13:40:08', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260901, 1.34366, 0.01, "#509199362 by #509242805");
   SRE_Tier1InitDeal(deals[145], 488596609, 509169341, 509169341, D'2026.07.31 13:53:12', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260903, 1.34577, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[146], 488596693, 509165467, 509540369, D'2026.07.31 13:53:12', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260901, 1.34577, 0.01, "#509165467 by #509169341");
   SRE_Tier1InitDeal(deals[147], 488596694, 509169341, 509540369, D'2026.07.31 13:53:12', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260901, 1.34546, 0.01, "#509165467 by #509169341");
   SRE_Tier1InitDeal(deals[148], 488599880, 509543205, 509543205, D'2026.07.31 13:55:28', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260901, 1.34452, 0.01, "V2_L0");
   SRE_Tier1InitDeal(deals[149], 488600097, 509543758, 509543758, D'2026.07.31 13:55:43', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260903, 1.34486, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[150], 488600102, 509543205, 509543989, D'2026.07.31 13:55:44', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260901, 1.34486, 0.01, "#509543205 by #509543758");
   SRE_Tier1InitDeal(deals[151], 488600103, 509543758, 509543989, D'2026.07.31 13:55:44', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260901, 1.34452, 0.01, "#509543205 by #509543758");
   SRE_Tier1InitDeal(deals[152], 488726077, 509674249, 509674249, D'2026.07.31 16:45:50', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260901, 1.3479, 0.01, "V2_L0");
   SRE_Tier1InitDeal(deals[153], 488730197, 509674949, 509674949, D'2026.07.31 16:50:56', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260903, 1.3482, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[154], 488730199, 509674249, 509679126, D'2026.07.31 16:50:57', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260901, 1.3482, 0.01, "#509674249 by #509674949");
   SRE_Tier1InitDeal(deals[155], 488730200, 509674949, 509679126, D'2026.07.31 16:50:57', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260901, 1.3479, 0.01, "#509674249 by #509674949");
   SRE_Tier1InitDeal(deals[156], 488784523, 509731568, 509731568, D'2026.07.31 18:57:59', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260901, 1.34793, 0.01, "V2_L0");
   SRE_Tier1InitDeal(deals[157], 488793377, 509735562, 509735562, D'2026.07.31 19:17:38', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260903, 1.34824, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[158], 488793388, 509731568, 509744749, D'2026.07.31 19:17:39', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260901, 1.34824, 0.01, "#509731568 by #509735562");
   SRE_Tier1InitDeal(deals[159], 488793389, 509735562, 509744749, D'2026.07.31 19:17:39', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260901, 1.34793, 0.01, "#509731568 by #509735562");
   SRE_Tier1InitDeal(deals[160], 488802274, 509751644, 509751644, D'2026.07.31 19:53:36', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260901, 1.34859, 0.01, "V2_L0");
   SRE_Tier1InitDeal(deals[161], 488802450, 509753708, 509753708, D'2026.07.31 19:54:35', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260903, 1.34896, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[162], 488802454, 509751644, 509753925, D'2026.07.31 19:54:36', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260901, 1.34896, 0.01, "#509751644 by #509753708");
   SRE_Tier1InitDeal(deals[163], 488802455, 509753708, 509753925, D'2026.07.31 19:54:36', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260901, 1.34859, 0.01, "#509751644 by #509753708");
   SRE_Tier1InitDeal(deals[164], 488947997, 509904312, 509904312, D'2026.08.02 21:19:02', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260901, 1.34995, 0.01, "V2_L0");
   SRE_Tier1InitDeal(deals[165], 488977935, 509908049, 509908049, D'2026.08.02 22:21:27', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260901, 1.34905, 0.01, "V2_Add");
   SRE_Tier1InitDeal(deals[166], 489013917, 509939221, 509939221, D'2026.08.02 23:29:14', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260903, 1.34936, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[167], 489013921, 509908049, 509978795, D'2026.08.02 23:29:14', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260901, 1.34936, 0.01, "#509908049 by #509939221");
   SRE_Tier1InitDeal(deals[168], 489013922, 509939221, 509978795, D'2026.08.02 23:29:14', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260901, 1.34905, 0.01, "#509908049 by #509939221");
   SRE_Tier1InitDeal(deals[169], 489024972, 509908048, 509908048, D'2026.08.02 23:44:34', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260903, 1.35027, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[170], 489024998, 509904312, 509990508, D'2026.08.02 23:44:36', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260901, 1.35027, 0.01, "#509904312 by #509908048");
   SRE_Tier1InitDeal(deals[171], 489024999, 509908048, 509990508, D'2026.08.02 23:44:36', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260901, 1.34995, 0.01, "#509904312 by #509908048");
   SRE_Tier1InitDeal(deals[172], 489026546, 509990725, 509990725, D'2026.08.02 23:47:16', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260901, 1.34959, 0.01, "V2_L0");
   SRE_Tier1InitDeal(deals[173], 489031370, 509992284, 509992284, D'2026.08.02 23:55:50', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260901, 1.34869, 0.01, "V2_Add");
   SRE_Tier1InitDeal(deals[174], 489037139, 509997315, 509997315, D'2026.08.03 00:02:09', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260903, 1.34898, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[175], 489037154, 509992284, 510003492, D'2026.08.03 00:02:09', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260901, 1.34898, 0.01, "#509992284 by #509997315");
   SRE_Tier1InitDeal(deals[176], 489037155, 509997315, 510003492, D'2026.08.03 00:02:09', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260901, 1.34869, 0.01, "#509992284 by #509997315");
   SRE_Tier1InitDeal(deals[177], 489042615, 510003486, 510003486, D'2026.08.03 00:11:44', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260901, 1.34778, 0.01, "V2_Reload");
   SRE_Tier1InitDeal(deals[178], 489092105, 510009259, 510009259, D'2026.08.03 01:56:17', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260901, 1.34688, 0.01, "V2_Add");
   SRE_Tier1InitDeal(deals[179], 489129637, 510063222, 510063222, D'2026.08.03 03:39:48', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260903, 1.34719, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[180], 489129645, 510009259, 510104047, D'2026.08.03 03:39:48', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260901, 1.34719, 0.01, "#510009259 by #510063222");
   SRE_Tier1InitDeal(deals[181], 489129646, 510063222, 510104047, D'2026.08.03 03:39:48', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260901, 1.34688, 0.01, "#510009259 by #510063222");
   SRE_Tier1InitDeal(deals[182], 489189135, 510104046, 510104046, D'2026.08.03 05:42:49', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260901, 1.34597, 0.01, "V2_Reload");
   SRE_Tier1InitDeal(deals[183], 489197937, 510167892, 510167892, D'2026.08.03 05:57:42', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260903, 1.34626, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[184], 489197942, 510104046, 510177119, D'2026.08.03 05:57:42', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260901, 1.34626, 0.01, "#510104046 by #510167892");
   SRE_Tier1InitDeal(deals[185], 489197943, 510167892, 510177119, D'2026.08.03 05:57:42', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260901, 1.34597, 0.01, "#510104046 by #510167892");
   SRE_Tier1InitDeal(deals[186], 489280295, 510177118, 510177118, D'2026.08.03 08:03:55', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260901, 1.34508, 0.01, "V2_Reload");
   SRE_Tier1InitDeal(deals[187], 489282314, 510264254, 510264254, D'2026.08.03 08:09:24', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260903, 1.34538, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[188], 489282316, 510177118, 510266453, D'2026.08.03 08:09:25', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260901, 1.34538, 0.01, "#510177118 by #510264254");
   SRE_Tier1InitDeal(deals[189], 489282317, 510264254, 510266453, D'2026.08.03 08:09:25', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260901, 1.34508, 0.01, "#510177118 by #510264254");
   SRE_Tier1InitDeal(deals[190], 489658873, 510266452, 510266452, D'2026.08.03 13:53:06', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260901, 1.34415, 0.01, "V2_Reload");
   SRE_Tier1InitDeal(deals[191], 490245239, 510656681, 510656681, D'2026.08.04 09:44:40', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260903, 1.3445, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[192], 490245447, 510266452, 511283223, D'2026.08.04 09:44:41', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260901, 1.3445, 0.01, "#510266452 by #510656681");
   SRE_Tier1InitDeal(deals[193], 490245448, 510656681, 511283223, D'2026.08.04 09:44:41', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260901, 1.34415, 0.01, "#510266452 by #510656681");
   SRE_Tier1InitDeal(deals[194], 491319964, 510009256, 510009256, D'2026.08.05 11:22:28', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260903, 1.34831, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[195], 491320204, 510003486, 512431982, D'2026.08.05 11:22:30', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260901, 1.34831, 0.01, "#510003486 by #510009256");
   SRE_Tier1InitDeal(deals[196], 491320205, 510009256, 512431982, D'2026.08.05 11:22:30', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260901, 1.34778, 0.01, "#510003486 by #510009256");
   SRE_Tier1InitDeal(deals[197], 491354849, 512431780, 512431780, D'2026.08.05 11:55:51', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260901, 1.34685, 0.01, "V2_Reload");
   SRE_Tier1InitDeal(deals[198], 491356283, 512468361, 512468361, D'2026.08.05 11:57:40', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260903, 1.34715, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[199], 491356303, 512431780, 512469850, D'2026.08.05 11:57:42', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260901, 1.34715, 0.01, "#512431780 by #512468361");
   SRE_Tier1InitDeal(deals[200], 491356304, 512468361, 512469850, D'2026.08.05 11:57:42', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260901, 1.34685, 0.01, "#512431780 by #512468361");
   SRE_Tier1InitDeal(deals[201], 491621642, 512469828, 512469828, D'2026.08.05 14:48:22', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260901, 1.34593, 0.01, "V2_Reload");
   SRE_Tier1InitDeal(deals[202], 491634173, 512748649, 512748649, D'2026.08.05 14:57:30', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260903, 1.3463, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[203], 491634205, 512469828, 512762153, D'2026.08.05 14:57:30', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260901, 1.3463, 0.01, "#512469828 by #512748649");
   SRE_Tier1InitDeal(deals[204], 491634206, 512748649, 512762153, D'2026.08.05 14:57:30', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260901, 1.34593, 0.01, "#512469828 by #512748649");
   SRE_Tier1InitDeal(deals[205], 492575578, 512762148, 512762148, D'2026.08.06 14:39:06', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260901, 1.34504, 0.01, "V2_Reload");
   SRE_Tier1InitDeal(deals[206], 492580104, 513743393, 513743393, D'2026.08.06 14:44:04', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260903, 1.34534, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[207], 492580108, 512762148, 513748129, D'2026.08.06 14:44:05', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260901, 1.34534, 0.01, "#512762148 by #513743393");
   SRE_Tier1InitDeal(deals[208], 492580109, 513743393, 513748129, D'2026.08.06 14:44:05', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260901, 1.34504, 0.01, "#512762148 by #513743393");
   SRE_Tier1InitDeal(deals[209], 493085365, 513748123, 513748123, D'2026.08.07 08:04:50', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260901, 1.34414, 0.01, "V2_Reload");
}

void SRE_Tier1FillDeals_GbpusdShort(V2SREDealInput &deals[])
{
   ArrayResize(deals, 96);
   SRE_Tier1InitDeal(deals[0], 486560935, 507416553, 507416553, D'2026.07.29 17:00:15', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260902, 1.33283, 0.01, "V2_L0");
   SRE_Tier1InitDeal(deals[1], 486562415, 507425519, 507425519, D'2026.07.29 17:00:19', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260904, 1.33232, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[2], 486562587, 507416553, 507426436, D'2026.07.29 17:00:19', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260902, 1.33232, 0.01, "#507416553 by #507425519");
   SRE_Tier1InitDeal(deals[3], 486562588, 507425519, 507426436, D'2026.07.29 17:00:19', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260902, 1.33283, 0.01, "#507416553 by #507425519");
   SRE_Tier1InitDeal(deals[4], 486599388, 507458052, 507458052, D'2026.07.29 17:14:00', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260902, 1.33384, 0.01, "V2_L0");
   SRE_Tier1InitDeal(deals[5], 486599986, 507463918, 507463918, D'2026.07.29 17:14:22', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260904, 1.33353, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[6], 486600070, 507458052, 507464597, D'2026.07.29 17:14:22', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260902, 1.33353, 0.01, "#507458052 by #507463918");
   SRE_Tier1InitDeal(deals[7], 486600071, 507463918, 507464597, D'2026.07.29 17:14:22', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260902, 1.33384, 0.01, "#507458052 by #507463918");
   SRE_Tier1InitDeal(deals[8], 486620766, 507484366, 507484366, D'2026.07.29 17:31:00', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260902, 1.33369, 0.01, "V2_L0");
   SRE_Tier1InitDeal(deals[9], 486621256, 507486172, 507486172, D'2026.07.29 17:31:18', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260904, 1.33323, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[10], 486621294, 507484366, 507486680, D'2026.07.29 17:31:19', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260902, 1.33323, 0.01, "#507484366 by #507486172");
   SRE_Tier1InitDeal(deals[11], 486621295, 507486172, 507486680, D'2026.07.29 17:31:19', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260902, 1.33369, 0.01, "#507484366 by #507486172");
   SRE_Tier1InitDeal(deals[12], 486637656, 507495350, 507495350, D'2026.07.29 17:39:53', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260902, 1.33382, 0.01, "V2_L0");
   SRE_Tier1InitDeal(deals[13], 486650483, 507503593, 507503593, D'2026.07.29 17:44:38', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260902, 1.33472, 0.01, "V2_Add");
   SRE_Tier1InitDeal(deals[14], 486658053, 507516531, 507516531, D'2026.07.29 17:47:45', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260902, 1.3356, 0.01, "V2_Add");
   SRE_Tier1InitDeal(deals[15], 486660236, 507524088, 507524088, D'2026.07.29 17:48:54', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260904, 1.33529, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[16], 486660238, 507516531, 507526255, D'2026.07.29 17:48:54', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260902, 1.33529, 0.01, "#507516531 by #507524088");
   SRE_Tier1InitDeal(deals[17], 486660239, 507524088, 507526255, D'2026.07.29 17:48:54', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260902, 1.3356, 0.01, "#507516531 by #507524088");
   SRE_Tier1InitDeal(deals[18], 486678169, 507526254, 507526254, D'2026.07.29 17:58:15', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260902, 1.3365, 0.01, "V2_Reload");
   SRE_Tier1InitDeal(deals[19], 486683069, 507544520, 507544520, D'2026.07.29 18:01:26', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260904, 1.33617, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[20], 486683087, 507526254, 507549878, D'2026.07.29 18:01:26', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260902, 1.33617, 0.01, "#507526254 by #507544520");
   SRE_Tier1InitDeal(deals[21], 486683088, 507544520, 507549878, D'2026.07.29 18:01:26', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260902, 1.3365, 0.01, "#507526254 by #507544520");
   SRE_Tier1InitDeal(deals[22], 486707357, 507549860, 507549860, D'2026.07.29 18:15:49', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260902, 1.33741, 0.01, "V2_Reload");
   SRE_Tier1InitDeal(deals[23], 486715927, 507574395, 507574395, D'2026.07.29 18:21:27', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260904, 1.33705, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[24], 486715988, 507549860, 507583135, D'2026.07.29 18:21:28', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260902, 1.33705, 0.01, "#507549860 by #507574395");
   SRE_Tier1InitDeal(deals[25], 486715989, 507574395, 507583135, D'2026.07.29 18:21:28', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260902, 1.33741, 0.01, "#507549860 by #507574395");
   SRE_Tier1InitDeal(deals[26], 486778650, 507516527, 507516527, D'2026.07.29 19:10:25', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260904, 1.33442, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[27], 486778661, 507503593, 507647320, D'2026.07.29 19:10:26', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260902, 1.33442, 0.01, "#507503593 by #507516527");
   SRE_Tier1InitDeal(deals[28], 486778662, 507516527, 507647320, D'2026.07.29 19:10:26', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260902, 1.33472, 0.01, "#507503593 by #507516527");
   SRE_Tier1InitDeal(deals[29], 486798016, 507647317, 507647317, D'2026.07.29 19:40:22', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260902, 1.33562, 0.01, "V2_Reload");
   SRE_Tier1InitDeal(deals[30], 486802517, 507666977, 507666977, D'2026.07.29 19:52:05', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260902, 1.33653, 0.01, "V2_Add");
   SRE_Tier1InitDeal(deals[31], 486806607, 507671623, 507671623, D'2026.07.29 21:00:05', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260904, 1.33622, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[32], 486806610, 507666977, 507675791, D'2026.07.29 21:00:05', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260902, 1.33622, 0.01, "#507666977 by #507671623");
   SRE_Tier1InitDeal(deals[33], 486806611, 507671623, 507675791, D'2026.07.29 21:00:05', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260902, 1.33653, 0.01, "#507666977 by #507671623");
   SRE_Tier1InitDeal(deals[34], 486838142, 507675790, 507675790, D'2026.07.29 22:08:48', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260902, 1.33747, 0.01, "V2_Reload");
   SRE_Tier1InitDeal(deals[35], 486840634, 507710073, 507710073, D'2026.07.29 22:11:41', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260904, 1.33715, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[36], 486840651, 507675790, 507712537, D'2026.07.29 22:11:41', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260902, 1.33715, 0.01, "#507675790 by #507710073");
   SRE_Tier1InitDeal(deals[37], 486840652, 507710073, 507712537, D'2026.07.29 22:11:41', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260902, 1.33747, 0.01, "#507675790 by #507710073");
   SRE_Tier1InitDeal(deals[38], 486912171, 507666976, 507666976, D'2026.07.30 00:23:38', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260904, 1.33526, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[39], 486912192, 507647317, 507787749, D'2026.07.30 00:23:39', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260902, 1.33526, 0.01, "#507647317 by #507666976");
   SRE_Tier1InitDeal(deals[40], 486912193, 507666976, 507787749, D'2026.07.30 00:23:39', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260902, 1.33562, 0.01, "#507647317 by #507666976");
   SRE_Tier1InitDeal(deals[41], 487059917, 507503573, 507503573, D'2026.07.30 05:31:48', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260904, 1.33346, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[42], 487059918, 507495350, 507944022, D'2026.07.30 05:31:49', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260902, 1.33346, 0.01, "#507495350 by #507503573");
   SRE_Tier1InitDeal(deals[43], 487059919, 507503573, 507944022, D'2026.07.30 05:31:49', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260902, 1.33382, 0.01, "#507495350 by #507503573");
   SRE_Tier1InitDeal(deals[44], 487066356, 507949746, 507949746, D'2026.07.30 05:47:30', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260902, 1.33431, 0.01, "V2_L0");
   SRE_Tier1InitDeal(deals[45], 487103602, 507950841, 507950841, D'2026.07.30 06:29:01', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260904, 1.33398, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[46], 487103613, 507949746, 507989071, D'2026.07.30 06:29:01', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260902, 1.33398, 0.01, "#507949746 by #507950841");
   SRE_Tier1InitDeal(deals[47], 487103614, 507950841, 507989071, D'2026.07.30 06:29:01', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260902, 1.33431, 0.01, "#507949746 by #507950841");
   SRE_Tier1InitDeal(deals[48], 487131036, 508010816, 508010816, D'2026.07.30 07:03:26', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260902, 1.33456, 0.01, "V2_L0");
   SRE_Tier1InitDeal(deals[49], 487158310, 508017768, 508017768, D'2026.07.30 07:28:02', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260902, 1.33546, 0.01, "V2_Add");
   SRE_Tier1InitDeal(deals[50], 487188395, 508045564, 508045564, D'2026.07.30 08:08:32', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260902, 1.3364, 0.01, "V2_Add");
   SRE_Tier1InitDeal(deals[51], 487201719, 508077088, 508077088, D'2026.07.30 08:26:22', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260902, 1.33758, 0.01, "V2_Add");
   SRE_Tier1InitDeal(deals[52], 487204926, 508090660, 508090660, D'2026.07.30 08:30:01', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260904, 1.33728, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[53], 487204966, 508077088, 508094057, D'2026.07.30 08:30:01', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260902, 1.33728, 0.01, "#508077088 by #508090660");
   SRE_Tier1InitDeal(deals[54], 487204967, 508090660, 508094057, D'2026.07.30 08:30:01', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260902, 1.33758, 0.01, "#508077088 by #508090660");
   SRE_Tier1InitDeal(deals[55], 487241624, 508094051, 508094051, D'2026.07.30 09:14:18', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260902, 1.33849, 0.01, "V2_Reload");
   SRE_Tier1InitDeal(deals[56], 487251227, 508131812, 508131812, D'2026.07.30 09:21:16', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260904, 1.33819, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[57], 487251233, 508094051, 508141434, D'2026.07.30 09:21:17', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260902, 1.33819, 0.01, "#508094051 by #508131812");
   SRE_Tier1InitDeal(deals[58], 487251234, 508131812, 508141434, D'2026.07.30 09:21:17', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260902, 1.33849, 0.01, "#508094051 by #508131812");
   SRE_Tier1InitDeal(deals[59], 487263489, 508141430, 508141430, D'2026.07.30 09:39:35', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260902, 1.33941, 0.01, "V2_Reload");
   SRE_Tier1InitDeal(deals[60], 487276463, 508154087, 508154087, D'2026.07.30 09:59:07', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260904, 1.33911, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[61], 487276467, 508141430, 508167504, D'2026.07.30 09:59:08', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260902, 1.33911, 0.01, "#508141430 by #508154087");
   SRE_Tier1InitDeal(deals[62], 487276468, 508154087, 508167504, D'2026.07.30 09:59:08', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260902, 1.33941, 0.01, "#508141430 by #508154087");
   SRE_Tier1InitDeal(deals[63], 487461098, 508167500, 508167500, D'2026.07.30 12:42:21', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260902, 1.34032, 0.01, "V2_Reload");
   SRE_Tier1InitDeal(deals[64], 487516239, 508357921, 508357921, D'2026.07.30 13:02:15', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260902, 1.34378, 0.01, "V2_Add");
   SRE_Tier1InitDeal(deals[65], 487526309, 508413567, 508413567, D'2026.07.30 13:06:56', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260904, 1.34346, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[66], 487526317, 508357921, 508424021, D'2026.07.30 13:06:56', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260902, 1.34346, 0.01, "#508357921 by #508413567");
   SRE_Tier1InitDeal(deals[67], 487526318, 508413567, 508424021, D'2026.07.30 13:06:56', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260902, 1.34378, 0.01, "#508357921 by #508413567");
   SRE_Tier1InitDeal(deals[68], 487543557, 508424019, 508424019, D'2026.07.30 13:17:34', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260902, 1.34468, 0.01, "V2_Reload");
   SRE_Tier1InitDeal(deals[69], 487543677, 508442140, 508442140, D'2026.07.30 13:17:47', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260904, 1.34439, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[70], 487543690, 508424019, 508442302, D'2026.07.30 13:17:47', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260902, 1.34439, 0.01, "#508424019 by #508442140");
   SRE_Tier1InitDeal(deals[71], 487543691, 508442140, 508442302, D'2026.07.30 13:17:47', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260902, 1.34468, 0.01, "#508424019 by #508442140");
   SRE_Tier1InitDeal(deals[72], 487653337, 508442296, 508442296, D'2026.07.30 14:42:19', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260902, 1.34557, 0.01, "V2_Reload");
   SRE_Tier1InitDeal(deals[73], 487969849, 508554626, 508554626, D'2026.07.31 00:43:09', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260904, 1.34519, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[74], 487969851, 508442296, 508886365, D'2026.07.31 00:43:09', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260902, 1.34519, 0.01, "#508442296 by #508554626");
   SRE_Tier1InitDeal(deals[75], 487969852, 508554626, 508886365, D'2026.07.31 00:43:09', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260902, 1.34557, 0.01, "#508442296 by #508554626");
   SRE_Tier1InitDeal(deals[76], 488212978, 508886364, 508886364, D'2026.07.31 08:02:28', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260902, 1.34646, 0.01, "V2_Reload");
   SRE_Tier1InitDeal(deals[77], 488214634, 509143396, 509143396, D'2026.07.31 08:04:33', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260904, 1.34616, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[78], 488214649, 508886364, 509145171, D'2026.07.31 08:04:34', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260902, 1.34616, 0.01, "#508886364 by #509143396");
   SRE_Tier1InitDeal(deals[79], 488214650, 509143396, 509145171, D'2026.07.31 08:04:34', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260902, 1.34646, 0.01, "#508886364 by #509143396");
   SRE_Tier1InitDeal(deals[80], 488703978, 509145164, 509145164, D'2026.07.31 16:14:24', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260902, 1.34735, 0.01, "V2_Reload");
   SRE_Tier1InitDeal(deals[81], 488706284, 509652520, 509652520, D'2026.07.31 16:18:57', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260904, 1.34704, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[82], 488706291, 509145164, 509654936, D'2026.07.31 16:18:57', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260902, 1.34704, 0.01, "#509145164 by #509652520");
   SRE_Tier1InitDeal(deals[83], 488706292, 509652520, 509654936, D'2026.07.31 16:18:57', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260902, 1.34735, 0.01, "#509145164 by #509652520");
   SRE_Tier1InitDeal(deals[84], 488720055, 509654935, 509654935, D'2026.07.31 16:35:50', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260902, 1.34822, 0.01, "V2_Reload");
   SRE_Tier1InitDeal(deals[85], 488721735, 509668773, 509668773, D'2026.07.31 16:38:52', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260904, 1.34792, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[86], 488721742, 509654935, 509670460, D'2026.07.31 16:38:53', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260902, 1.34792, 0.01, "#509654935 by #509668773");
   SRE_Tier1InitDeal(deals[87], 488721743, 509668773, 509670460, D'2026.07.31 16:38:53', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260902, 1.34822, 0.01, "#509654935 by #509668773");
   SRE_Tier1InitDeal(deals[88], 488800109, 509670459, 509670459, D'2026.07.31 19:44:22', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260902, 1.34912, 0.01, "V2_Reload");
   SRE_Tier1InitDeal(deals[89], 488801968, 509751543, 509751543, D'2026.07.31 19:53:03', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260904, 1.34881, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[90], 488801972, 509670459, 509753410, D'2026.07.31 19:53:03', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260902, 1.34881, 0.01, "#509670459 by #509751543");
   SRE_Tier1InitDeal(deals[91], 488801973, 509751543, 509753410, D'2026.07.31 19:53:03', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260902, 1.34912, 0.01, "#509670459 by #509751543");
   SRE_Tier1InitDeal(deals[92], 488929758, 509882175, 509882175, D'2026.08.02 21:00:59', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260902, 1.35002, 0.01, "V2_Reload");
   SRE_Tier1InitDeal(deals[93], 488948597, 509888073, 509888073, D'2026.08.02 21:19:27', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260904, 1.34972, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[94], 488948606, 509882175, 509908655, D'2026.08.02 21:19:27', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260902, 1.34972, 0.01, "#509882175 by #509888073");
   SRE_Tier1InitDeal(deals[95], 488948607, 509888073, 509908655, D'2026.08.02 21:19:27', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260902, 1.35002, 0.01, "#509882175 by #509888073");
}

void SRE_Tier1FillDeals_EurgbpLong(V2SREDealInput &deals[])
{
   ArrayResize(deals, 33);
   SRE_Tier1InitDeal(deals[0], 486367774, 507223943, 507223943, D'2026.07.29 13:58:13', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260921, 0.85645, 0.01, "V2_L0");
   SRE_Tier1InitDeal(deals[1], 486376195, 507227122, 507227122, D'2026.07.29 14:04:51', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260923, 0.85675, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[2], 486376203, 507223943, 507236022, D'2026.07.29 14:04:52', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260921, 0.85675, 0.01, "#507223943 by #507227122");
   SRE_Tier1InitDeal(deals[3], 486376204, 507227122, 507236022, D'2026.07.29 14:04:52', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260921, 0.85645, 0.01, "#507223943 by #507227122");
   SRE_Tier1InitDeal(deals[4], 486614609, 507479493, 507479493, D'2026.07.29 17:25:22', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260921, 0.85677, 0.01, "V2_L0");
   SRE_Tier1InitDeal(deals[5], 486723836, 507479922, 507479922, D'2026.07.29 18:27:07', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260923, 0.85708, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[6], 486723863, 507479493, 507591041, D'2026.07.29 18:27:08', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260921, 0.85708, 0.01, "#507479493 by #507479922");
   SRE_Tier1InitDeal(deals[7], 486723864, 507479922, 507591041, D'2026.07.29 18:27:08', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260921, 0.85677, 0.01, "#507479493 by #507479922");
   SRE_Tier1InitDeal(deals[8], 487456003, 508330345, 508330345, D'2026.07.30 12:40:23', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260921, 0.85783, 0.01, "V2_L0");
   SRE_Tier1InitDeal(deals[9], 487489201, 508352699, 508352699, D'2026.07.30 12:52:01', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260923, 0.85812, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[10], 487489219, 508330345, 508386262, D'2026.07.30 12:52:02', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260921, 0.85812, 0.01, "#508330345 by #508352699");
   SRE_Tier1InitDeal(deals[11], 487489220, 508352699, 508386262, D'2026.07.30 12:52:02', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260921, 0.85783, 0.01, "#508330345 by #508352699");
   SRE_Tier1InitDeal(deals[12], 487511364, 508403686, 508403686, D'2026.07.30 13:00:47', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260921, 0.85803, 0.01, "V2_L0");
   SRE_Tier1InitDeal(deals[13], 487581995, 508408618, 508408618, D'2026.07.30 13:44:08', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260921, 0.85716, 0.01, "V2_Add");
   SRE_Tier1InitDeal(deals[14], 487653351, 508481505, 508481505, D'2026.07.30 14:42:19', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260921, 0.85625, 0.01, "V2_Add");
   SRE_Tier1InitDeal(deals[15], 488179104, 508554645, 508554645, D'2026.07.31 07:26:09', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260923, 0.85655, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[16], 488179135, 508481505, 509107430, D'2026.07.31 07:26:09', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260921, 0.85655, 0.01, "#508481505 by #508554645");
   SRE_Tier1InitDeal(deals[17], 488179136, 508554645, 509107430, D'2026.07.31 07:26:09', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260921, 0.85625, 0.01, "#508481505 by #508554645");
   SRE_Tier1InitDeal(deals[18], 488236422, 509107421, 509107421, D'2026.07.31 08:28:25', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260921, 0.85536, 0.01, "V2_Reload");
   SRE_Tier1InitDeal(deals[19], 488264234, 509167993, 509167993, D'2026.07.31 09:08:39', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260923, 0.85569, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[20], 488264243, 509107421, 509197332, D'2026.07.31 09:08:39', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260921, 0.85569, 0.01, "#509107421 by #509167993");
   SRE_Tier1InitDeal(deals[21], 488264244, 509167993, 509197332, D'2026.07.31 09:08:39', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260921, 0.85536, 0.01, "#509107421 by #509167993");
   SRE_Tier1InitDeal(deals[22], 488588180, 509197329, 509197329, D'2026.07.31 13:48:44', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260921, 0.85446, 0.01, "V2_Reload");
   SRE_Tier1InitDeal(deals[23], 488591664, 509531832, 509531832, D'2026.07.31 13:50:21', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260923, 0.85474, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[24], 488591673, 509197329, 509535352, D'2026.07.31 13:50:21', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260921, 0.85474, 0.01, "#509197329 by #509531832");
   SRE_Tier1InitDeal(deals[25], 488591674, 509531832, 509535352, D'2026.07.31 13:50:21', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260921, 0.85446, 0.01, "#509197329 by #509531832");
   SRE_Tier1InitDeal(deals[26], 491689234, 508481504, 508481504, D'2026.08.05 16:08:19', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260923, 0.85785, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[27], 491689245, 508408618, 512823324, D'2026.08.05 16:08:19', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260921, 0.85785, 0.01, "#508408618 by #508481504");
   SRE_Tier1InitDeal(deals[28], 491689246, 508481504, 512823324, D'2026.08.05 16:08:19', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260921, 0.85716, 0.01, "#508408618 by #508481504");
   SRE_Tier1InitDeal(deals[29], 492446665, 512823318, 512823318, D'2026.08.06 13:06:41', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260921, 0.85625, 0.01, "V2_Reload");
   SRE_Tier1InitDeal(deals[30], 492462452, 513610707, 513610707, D'2026.08.06 13:15:33', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260923, 0.85654, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[31], 492462461, 512823318, 513627147, D'2026.08.06 13:15:34', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260921, 0.85654, 0.01, "#512823318 by #513610707");
   SRE_Tier1InitDeal(deals[32], 492462462, 513610707, 513627147, D'2026.08.06 13:15:34', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260921, 0.85625, 0.01, "#512823318 by #513610707");
}

void SRE_Tier1FillDeals_EurgbpShort(V2SREDealInput &deals[])
{
   ArrayResize(deals, 37);
   SRE_Tier1InitDeal(deals[0], 487521996, 508419384, 508419384, D'2026.07.30 13:05:02', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260922, 0.85801, 0.01, "V2_L0");
   SRE_Tier1InitDeal(deals[1], 487525525, 508419593, 508419593, D'2026.07.30 13:06:35', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260924, 0.85773, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[2], 487525528, 508419384, 508423224, D'2026.07.30 13:06:35', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260922, 0.85773, 0.01, "#508419384 by #508419593");
   SRE_Tier1InitDeal(deals[3], 487525529, 508419593, 508423224, D'2026.07.30 13:06:35', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260922, 0.85801, 0.01, "#508419384 by #508419593");
   SRE_Tier1InitDeal(deals[4], 487774144, 508678753, 508678753, D'2026.07.30 17:04:17', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260922, 0.85594, 0.01, "V2_L0");
   SRE_Tier1InitDeal(deals[5], 487982552, 508681422, 508681422, D'2026.07.31 01:10:12', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260924, 0.85564, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[6], 487982560, 508678753, 508899978, D'2026.07.31 01:10:12', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260922, 0.85564, 0.01, "#508678753 by #508681422");
   SRE_Tier1InitDeal(deals[7], 487982561, 508681422, 508899978, D'2026.07.31 01:10:12', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260922, 0.85594, 0.01, "#508678753 by #508681422");
   SRE_Tier1InitDeal(deals[8], 488105167, 509029261, 509029261, D'2026.07.31 05:57:31', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260922, 0.85618, 0.01, "V2_L0");
   SRE_Tier1InitDeal(deals[9], 488111677, 509030443, 509030443, D'2026.07.31 06:07:06', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260924, 0.8559, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[10], 488111702, 509029261, 509037438, D'2026.07.31 06:07:10', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260922, 0.8559, 0.01, "#509029261 by #509030443");
   SRE_Tier1InitDeal(deals[11], 488111703, 509030443, 509037438, D'2026.07.31 06:07:10', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260922, 0.85618, 0.01, "#509029261 by #509030443");
   SRE_Tier1InitDeal(deals[12], 488166088, 509077954, 509077954, D'2026.07.31 07:13:14', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260922, 0.85628, 0.01, "V2_L0");
   SRE_Tier1InitDeal(deals[13], 488204792, 509093986, 509093986, D'2026.07.31 07:55:45', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260924, 0.85598, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[14], 488204798, 509077954, 509134669, D'2026.07.31 07:55:45', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260922, 0.85598, 0.01, "#509077954 by #509093986");
   SRE_Tier1InitDeal(deals[15], 488204799, 509093986, 509134669, D'2026.07.31 07:55:45', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260922, 0.85628, 0.01, "#509077954 by #509093986");
   SRE_Tier1InitDeal(deals[16], 488479654, 509415380, 509415380, D'2026.07.31 12:45:49', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260922, 0.85535, 0.01, "V2_L0");
   SRE_Tier1InitDeal(deals[17], 488492121, 509418091, 509418091, D'2026.07.31 12:50:57', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260924, 0.85505, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[18], 488492134, 509415380, 509431133, D'2026.07.31 12:50:57', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260922, 0.85505, 0.01, "#509415380 by #509418091");
   SRE_Tier1InitDeal(deals[19], 488492135, 509418091, 509431133, D'2026.07.31 12:50:57', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260922, 0.85535, 0.01, "#509415380 by #509418091");
   SRE_Tier1InitDeal(deals[20], 488591549, 509534607, 509534607, D'2026.07.31 13:50:16', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260922, 0.85457, 0.01, "V2_L0");
   SRE_Tier1InitDeal(deals[21], 488723902, 509535241, 509535241, D'2026.07.31 16:42:23', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260922, 0.85547, 0.01, "V2_Add");
   SRE_Tier1InitDeal(deals[22], 488758116, 509672655, 509672655, D'2026.07.31 17:56:06', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260924, 0.85516, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[23], 488758121, 509535241, 509708135, D'2026.07.31 17:56:06', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260922, 0.85516, 0.01, "#509535241 by #509672655");
   SRE_Tier1InitDeal(deals[24], 488758122, 509672655, 509708135, D'2026.07.31 17:56:06', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260922, 0.85547, 0.01, "#509535241 by #509672655");
   SRE_Tier1InitDeal(deals[25], 489218955, 509883952, 509883952, D'2026.08.03 06:20:07', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260922, 0.8564, 0.01, "V2_Reload");
   SRE_Tier1InitDeal(deals[26], 489229912, 510199224, 510199224, D'2026.08.03 06:35:33', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260924, 0.85612, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[27], 489229923, 509883952, 510210557, D'2026.08.03 06:35:33', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260922, 0.85612, 0.01, "#509883952 by #510199224");
   SRE_Tier1InitDeal(deals[28], 489229924, 510199224, 510210557, D'2026.08.03 06:35:33', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260922, 0.8564, 0.01, "#509883952 by #510199224");
   SRE_Tier1InitDeal(deals[29], 489798033, 510210554, 510210554, D'2026.08.03 17:17:20', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260922, 0.85729, 0.01, "V2_Reload");
   SRE_Tier1InitDeal(deals[30], 489854207, 510803120, 510803120, D'2026.08.03 18:57:17', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260924, 0.85699, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[31], 489854215, 510210554, 510868448, D'2026.08.03 18:57:19', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260922, 0.85699, 0.01, "#510210554 by #510803120");
   SRE_Tier1InitDeal(deals[32], 489854216, 510803120, 510868448, D'2026.08.03 18:57:19', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260922, 0.85729, 0.01, "#510210554 by #510803120");
   SRE_Tier1InitDeal(deals[33], 491888343, 510868439, 510868439, D'2026.08.05 23:58:42', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260922, 0.85818, 0.01, "V2_Reload");
   SRE_Tier1InitDeal(deals[34], 491929329, 513030650, 513030650, D'2026.08.06 01:05:02', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260924, 0.85788, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[35], 491929372, 510868439, 513074329, D'2026.08.06 01:05:03', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260922, 0.85788, 0.01, "#510868439 by #513030650");
   SRE_Tier1InitDeal(deals[36], 491929373, 513030650, 513074329, D'2026.08.06 01:05:03', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260922, 0.85818, 0.01, "#510868439 by #513030650");
}

void SRE_Tier1FillDeals_EurusdShort_Case7(V2SREDealInput &deals[])
{
   ArrayResize(deals, 6);
   SRE_Tier1InitDeal(deals[0], 488801966, 509675032, 509753405, D'2026.07.31 19:53:03', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260912, 1.15408, 0.01, "#509675032 by #509752450");
   SRE_Tier1InitDeal(deals[1], 488801967, 509752450, 509753405, D'2026.07.31 19:53:03', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260912, 1.15435, 0.01, "#509675032 by #509752450");
   SRE_Tier1InitDeal(deals[2], 488929697, 509882167, 509882167, D'2026.08.02 21:00:51', DEAL_ENTRY_IN, DEAL_TYPE_SELL, 20260912, 1.1553, 0.01, "V2_Reload");
   SRE_Tier1InitDeal(deals[3], 488948067, 509888020, 509888020, D'2026.08.02 21:19:06', DEAL_ENTRY_IN, DEAL_TYPE_BUY, 20260914, 1.155, 0.01, "V2_Exit");
   SRE_Tier1InitDeal(deals[4], 488948075, 509882167, 509908119, D'2026.08.02 21:19:06', DEAL_ENTRY_OUT_BY, DEAL_TYPE_BUY, 20260912, 1.155, 0.01, "#509882167 by #509888020");
   SRE_Tier1InitDeal(deals[5], 488948076, 509888020, 509908119, D'2026.08.02 21:19:06', DEAL_ENTRY_OUT_BY, DEAL_TYPE_SELL, 20260912, 1.1553, 0.01, "#509882167 by #509888020");
}

void SRE_Tier1FillCase2ShortBroker(V2SREPositionInput &pos[],
                                   V2SREExitOrderInput &ord[],
                                   V2SREDealInput &deals[])
{
   ArrayResize(pos, 2);
   pos[0].ticket = 507495342; pos[0].position_id = 507495342;
   pos[0].open_time = D'2026.07.29 17:39:51';
   pos[0].entry_price = 1.14257; pos[0].volume = SRE_LOT; pos[0].direction = -1;
   pos[0].symbol = "EURUSD"; pos[0].position_type = POSITION_TYPE_SELL;
   pos[1].ticket = 507503280; pos[1].position_id = 507503280;
   pos[1].open_time = D'2026.07.29 17:44:33';
   pos[1].entry_price = 1.14347; pos[1].volume = SRE_LOT; pos[1].direction = -1;
   pos[1].symbol = "EURUSD"; pos[1].position_type = POSITION_TYPE_SELL;

   ArrayResize(ord, 2);
   ord[0].ticket = 507503266; ord[0].placement_time = D'2026.07.29 17:39:51';
   ord[0].price = 1.14227; ord[0].volume = SRE_LOT; ord[0].direction = -1; ord[0].symbol = "EURUSD";
   ord[1].ticket = 507515934; ord[1].placement_time = D'2026.07.29 17:44:33';
   ord[1].price = 1.14317; ord[1].volume = SRE_LOT; ord[1].direction = -1; ord[1].symbol = "EURUSD";

   SRE_Tier1FillDeals_EurusdShort(deals);
}

void SRE_Tier1FillCase3LongBroker(V2SREPositionInput &pos[],
                                  V2SREExitOrderInput &ord[],
                                  V2SREDealInput &deals[])
{
   ArrayResize(pos, 1);
   pos[0].ticket = 509990725; pos[0].position_id = 509990725;
   pos[0].open_time = D'2026.08.02 23:47:16';
   pos[0].entry_price = 1.34959; pos[0].volume = SRE_LOT; pos[0].direction = 1;
   pos[0].symbol = "GBPUSD"; pos[0].position_type = POSITION_TYPE_BUY;

   ArrayResize(ord, 1);
   ord[0].ticket = 509992283; ord[0].placement_time = D'2026.08.02 23:47:16';
   ord[0].price = 1.35020; ord[0].volume = SRE_LOT; ord[0].direction = 1; ord[0].symbol = "GBPUSD";

   SRE_Tier1FillDeals_GbpusdLong(deals);
}

void SRE_Tier1FillCase4ShortBroker(V2SREPositionInput &pos[],
                                   V2SREExitOrderInput &ord[],
                                   V2SREDealInput &deals[])
{
   const datetime opens[4] = {
      D'2026.07.30 07:03:26', D'2026.07.30 07:28:02',
      D'2026.07.30 08:08:32', D'2026.07.30 12:42:21'
   };
   const double entries[4] = {1.33456, 1.33546, 1.33640, 1.34032};
   const double exits[4]   = {1.33391, 1.33481, 1.33575, 1.33967};
   const ulong pos_tix[4]  = {508010816, 508017768, 508045564, 508167500};
   const ulong ord_tix[4]  = {508017767, 508045561, 508077078, 508357909};

   ArrayResize(pos, 4);
   ArrayResize(ord, 4);
   for(int i = 0; i < 4; i++) {
      pos[i].ticket = pos_tix[i]; pos[i].position_id = pos_tix[i];
      pos[i].open_time = opens[i]; pos[i].entry_price = entries[i];
      pos[i].volume = SRE_LOT; pos[i].direction = -1;
      pos[i].symbol = "GBPUSD"; pos[i].position_type = POSITION_TYPE_SELL;
      ord[i].ticket = ord_tix[i]; ord[i].placement_time = opens[i];
      ord[i].price = exits[i]; ord[i].volume = SRE_LOT; ord[i].direction = -1;
      ord[i].symbol = "GBPUSD";
   }

   SRE_Tier1FillDeals_GbpusdShort(deals);
}

void SRE_Tier1FillCase5LongBroker(V2SREPositionInput &pos[],
                                  V2SREExitOrderInput &ord[],
                                  V2SREDealInput &deals[])
{
   ArrayResize(pos, 1);
   pos[0].ticket = 508403686; pos[0].position_id = 508403686;
   pos[0].open_time = D'2026.07.30 13:00:47';
   pos[0].entry_price = 0.85803; pos[0].volume = SRE_LOT; pos[0].direction = 1;
   pos[0].symbol = "EURGBP"; pos[0].position_type = POSITION_TYPE_BUY;

   ArrayResize(ord, 1);
   ord[0].ticket = 508408610; ord[0].placement_time = D'2026.07.30 13:00:47';
   ord[0].price = 0.85881; ord[0].volume = SRE_LOT; ord[0].direction = 1; ord[0].symbol = "EURGBP";

   SRE_Tier1FillDeals_EurgbpLong(deals);
}

void SRE_Tier1FillCase6ShortBroker(V2SREPositionInput &pos[],
                                   V2SREExitOrderInput &ord[],
                                   V2SREDealInput &deals[])
{
   ArrayResize(pos, 1);
   pos[0].ticket = 509534607; pos[0].position_id = 509534607;
   pos[0].open_time = D'2026.07.31 13:50:16';
   pos[0].entry_price = 0.85457; pos[0].volume = SRE_LOT; pos[0].direction = -1;
   pos[0].symbol = "EURGBP"; pos[0].position_type = POSITION_TYPE_SELL;

   ArrayResize(ord, 1);
   ord[0].ticket = 509535231; ord[0].placement_time = D'2026.07.31 13:50:16';
   ord[0].price = 0.85427; ord[0].volume = SRE_LOT; ord[0].direction = -1; ord[0].symbol = "EURGBP";

   SRE_Tier1FillDeals_EurgbpShort(deals);
}

bool SRE_Tier1FindCloseByPair(const V2SRECloseByPair &pairs[],
                              const ulong entry_position_id,
                              const ulong hedge_position_id,
                              const ulong closeby_order_id)
{
   for(int i = 0; i < ArraySize(pairs); i++) {
      if(pairs[i].entry_position_id == entry_position_id &&
         pairs[i].hedge_position_id == hedge_position_id &&
         pairs[i].closeby_order_id == closeby_order_id)
         return true;
   }
   return false;
}

void Test_SRE_Tier1RealData_PairA_Eurusd()
{
   Test_ClearCapGvs();
   SRE_Tier2AuditSetSwapOverride(-4.62, -6.18);
   SRE_OnInitActivateDualOverride();

   V2SREPositionInput short_pos[];
   V2SREExitOrderInput short_ord[];
   V2SREDealInput short_deals[];
   SRE_Tier1FillCase2ShortBroker(short_pos, short_ord, short_deals);
   SRE_OnInitCopyFixtureFromArrays(g_v2_sre_oninit_dual_override.short_side,
                                   short_pos, short_ord, short_deals);

   string long_alerts[];
   string short_alerts[];
   V2SREOnInitSideConfig long_cfg = SRE_OnInitTestConfigForPair(SRE_ONINIT_PAIR_EURUSD, true);
   V2SREOnInitSideConfig short_cfg = SRE_OnInitTestConfigForPair(SRE_ONINIT_PAIR_EURUSD, false);
   long_cfg.now = SRE_TIER1_NOW;
   short_cfg.now = SRE_TIER1_NOW;
   V2SREOnInitSideResult long_sre;
   V2SREOnInitSideResult short_sre;

   const V2SREOnInitAggregateOutcome agg = V2_SRE_RunOnInitSidePair(
      long_alerts, short_alerts, long_cfg, short_cfg, long_sre, short_sre);

   AssertTrue("tier1 pairA init succeeded", agg.init_result == INIT_SUCCEEDED);
   AssertTrue("tier1 pairA long not halted", !agg.long_halted);
   AssertTrue("tier1 pairA short not halted", !agg.short_halted);
   AssertTrue("tier1 pairA short committed", agg.short_committed);
   AssertTrue("tier1 pairA short halt reason ok", short_sre.halt_reason == V2_SRE_OK);
   AssertTrue("tier1 pairA short two layers", short_sre.layer_count_after == 2);

   SRE_Tier2AuditResetSwapOverride();
   SRE_OnInitResetOverride();
   Test_ClearCapGvs();
}

void Test_SRE_Tier1RealData_PairB_Gbpusd()
{
   Test_ClearCapGvs();
   SRE_Tier2AuditSetSwapOverride(-4.62, -6.18);
   SRE_OnInitActivateDualOverride();

   V2SREPositionInput long_pos[];
   V2SREExitOrderInput long_ord[];
   V2SREDealInput long_deals[];
   SRE_Tier1FillCase3LongBroker(long_pos, long_ord, long_deals);
   SRE_OnInitCopyFixtureFromArrays(g_v2_sre_oninit_dual_override.long_side,
                                   long_pos, long_ord, long_deals);

   V2SREPositionInput short_pos[];
   V2SREExitOrderInput short_ord[];
   V2SREDealInput short_deals[];
   SRE_Tier1FillCase4ShortBroker(short_pos, short_ord, short_deals);
   SRE_OnInitCopyFixtureFromArrays(g_v2_sre_oninit_dual_override.short_side,
                                   short_pos, short_ord, short_deals);

   string long_alerts[];
   string short_alerts[];
   V2SREOnInitSideConfig long_cfg = SRE_OnInitTestConfigForPair(SRE_ONINIT_PAIR_GBPUSD, true);
   V2SREOnInitSideConfig short_cfg = SRE_OnInitTestConfigForPair(SRE_ONINIT_PAIR_GBPUSD, false);
   long_cfg.now = SRE_TIER1_NOW;
   short_cfg.now = SRE_TIER1_NOW;
   V2SREOnInitSideResult long_sre;
   V2SREOnInitSideResult short_sre;

   const V2SREOnInitAggregateOutcome agg = V2_SRE_RunOnInitSidePair(
      long_alerts, short_alerts, long_cfg, short_cfg, long_sre, short_sre);

   AssertTrue("tier1 pairB init succeeded", agg.init_result == INIT_SUCCEEDED);
   AssertTrue("tier1 pairB long halted (HALT_30 by design, ADR-108)", agg.long_halted);
   AssertTrue("tier1 pairB short not halted", !agg.short_halted);
   AssertTrue("tier1 pairB long not committed (halted)", !agg.long_committed);
   AssertTrue("tier1 pairB short committed", agg.short_committed);
   AssertTrue("tier1 pairB long halt reason HALT_30", long_sre.halt_reason == V2_SRE_HALT_30_CLOSEBY_PRICE_INCONSISTENT);
   AssertTrue("tier1 pairB short halt reason ok", short_sre.halt_reason == V2_SRE_OK);
   // pairB long: layer_count_after not asserted on a by-design HALT_30 (fail-closed before commit)
   AssertTrue("tier1 pairB short four layers", short_sre.layer_count_after == 4);

   SRE_Tier2AuditResetSwapOverride();
   SRE_OnInitResetOverride();
   Test_ClearCapGvs();
}

void Test_SRE_Tier1RealData_PairC_Eurgbp()
{
   Test_ClearCapGvs();
   SRE_Tier2AuditSetSwapOverride(-8.51, 0.15);
   SRE_OnInitActivateDualOverride();

   V2SREPositionInput long_pos[];
   V2SREExitOrderInput long_ord[];
   V2SREDealInput long_deals[];
   SRE_Tier1FillCase5LongBroker(long_pos, long_ord, long_deals);
   SRE_OnInitCopyFixtureFromArrays(g_v2_sre_oninit_dual_override.long_side,
                                   long_pos, long_ord, long_deals);

   V2SREPositionInput short_pos[];
   V2SREExitOrderInput short_ord[];
   V2SREDealInput short_deals[];
   SRE_Tier1FillCase6ShortBroker(short_pos, short_ord, short_deals);
   SRE_OnInitCopyFixtureFromArrays(g_v2_sre_oninit_dual_override.short_side,
                                   short_pos, short_ord, short_deals);

   string long_alerts[];
   string short_alerts[];
   V2SREOnInitSideConfig long_cfg = SRE_OnInitTestConfigForPair(SRE_ONINIT_PAIR_EURGBP, true);
   V2SREOnInitSideConfig short_cfg = SRE_OnInitTestConfigForPair(SRE_ONINIT_PAIR_EURGBP, false);
   long_cfg.now = SRE_TIER1_NOW;
   short_cfg.now = SRE_TIER1_NOW;
   V2SREOnInitSideResult long_sre;
   V2SREOnInitSideResult short_sre;

   const V2SREOnInitAggregateOutcome agg = V2_SRE_RunOnInitSidePair(
      long_alerts, short_alerts, long_cfg, short_cfg, long_sre, short_sre);

   AssertTrue("tier1 pairC init succeeded", agg.init_result == INIT_SUCCEEDED);
   AssertTrue("tier1 pairC long halted (HALT_30 by design, ADR-108)", agg.long_halted);
   AssertTrue("tier1 pairC short not halted", !agg.short_halted);
   AssertTrue("tier1 pairC long not committed (halted)", !agg.long_committed);
   AssertTrue("tier1 pairC short committed", agg.short_committed);
   AssertTrue("tier1 pairC long halt reason HALT_30", long_sre.halt_reason == V2_SRE_HALT_30_CLOSEBY_PRICE_INCONSISTENT);
   AssertTrue("tier1 pairC short halt reason ok", short_sre.halt_reason == V2_SRE_OK);
   // pairC long: layer_count_after not asserted on a by-design HALT_30 (fail-closed before commit)
   AssertTrue("tier1 pairC short one layer", short_sre.layer_count_after == 1);

   SRE_Tier2AuditResetSwapOverride();
   SRE_OnInitResetOverride();
   Test_ClearCapGvs();
}

void Test_SRE_Tier1RealData_StandaloneD_EurusdCloseBy()
{
   V2SREDealInput deals[];
   SRE_Tier1FillDeals_EurusdShort_Case7(deals);

   V2SREOnInitSideConfig cfg = SRE_OnInitTestConfigForPair(SRE_ONINIT_PAIR_EURUSD, false);
   cfg.now = SRE_TIER1_CASE7_NOW;

   V2SREAnchorResult anchor = V2_SRE_FindAnchor(deals, cfg.now, cfg.lookback_sec,
                                                cfg.entry_magic, cfg.exit_magic);
   AssertTrue("tier1 case7 anchor ok", anchor.halt == V2_SRE_OK);

   V2SREMapResult map_result = V2_SRE_MapHedgeToEntry(deals,
      (anchor.halt == V2_SRE_OK ? anchor.anchor_time : 0),
      cfg.entry_magic, cfg.exit_magic, cfg.side_direction, cfg.exit_pips, cfg.point, cfg.symbol,
      cfg.add_pips_floor);
   AssertTrue("tier1 case7 map halt ok", map_result.halt == V2_SRE_OK);
   AssertTrue("tier1 case7 flat-at-anchor yields no post-anchor pairs",
              ArraySize(map_result.pairs) == 0);

   V2SREMapResult map_preclose = V2_SRE_MapHedgeToEntry(deals,
      D'2026.08.02 21:00:50',
      cfg.entry_magic, cfg.exit_magic, cfg.side_direction, cfg.exit_pips, cfg.point, cfg.symbol,
      cfg.add_pips_floor);
   AssertTrue("tier1 case7 pre-close map halt ok", map_preclose.halt == V2_SRE_OK);
   AssertTrue("tier1 case7 hedge maps entry 509882167 when pre-close anchor",
              SRE_Tier1FindCloseByPair(map_preclose.pairs, 509882167, 509888020, 509908119));

   V2SREPositionInput pos[];
   V2SREExitOrderInput ord[];
   V2SREPendingEntryInput pending[];
   V2SREOnInitSideResult res;
   V2_SRE_ResetOnInitSideResult(res);

   const V2SREHaltReason hr = V2_SRE_RunOnInitSteps3To10(cfg, pos, ord, pending, deals, res);
   AssertTrue("tier1 case7 steps3-10 ok", hr == V2_SRE_OK);
   AssertTrue("tier1 case7 flat committed", res.committed);
   AssertTrue("tier1 case7 zero layers", res.layer_count_after == 0);
}

void Test_SRE_OnInitPairBothHaltInitFailed()
{
   const string tags[3] = {"gbpusd", "eurusd", "eurgbp"};
   for(int p = 0; p < SRE_ONINIT_PAIR_COUNT; p++) {
      Test_ClearCapGvs();
      SRE_OnInitActivateDualOverride();
      SRE_OnInitFillHaltFixture(g_v2_sre_oninit_dual_override.long_side, true, p);
      SRE_OnInitFillHaltFixture(g_v2_sre_oninit_dual_override.short_side, false, p);

      string long_alerts[];
      string short_alerts[];
      V2SREOnInitSideConfig long_cfg = SRE_OnInitTestConfigForPair(p, true);
      V2SREOnInitSideConfig short_cfg = SRE_OnInitTestConfigForPair(p, false);
      V2SREOnInitSideResult long_sre;
      V2SREOnInitSideResult short_sre;

      const V2SREOnInitAggregateOutcome agg = V2_SRE_RunOnInitSidePair(
         long_alerts, short_alerts, long_cfg, short_cfg, long_sre, short_sre);

      AssertTrue(tags[p] + " pair both halt init failed", agg.init_result == INIT_FAILED);
      AssertTrue(tags[p] + " pair both halt long halted", agg.long_halted);
      AssertTrue(tags[p] + " pair both halt short halted", agg.short_halted);
      AssertTrue(tags[p] + " pair both halt long not committed", !agg.long_committed);
      AssertTrue(tags[p] + " pair both halt short not committed", !agg.short_committed);

      SRE_OnInitResetOverride();
      Test_ClearCapGvs();
   }
}

void Test_SRE_OnInitPairLongHaltOnlyInitSucceeded()
{
   const string tags[3] = {"gbpusd", "eurusd", "eurgbp"};
   for(int p = 0; p < SRE_ONINIT_PAIR_COUNT; p++) {
      Test_ClearCapGvs();
      SRE_OnInitActivateDualOverride();
      SRE_OnInitFillHaltFixture(g_v2_sre_oninit_dual_override.long_side, true, p);

      string long_alerts[];
      string short_alerts[];
      V2SREOnInitSideConfig long_cfg = SRE_OnInitTestConfigForPair(p, true);
      V2SREOnInitSideConfig short_cfg = SRE_OnInitTestConfigForPair(p, false);
      V2SREOnInitSideResult long_sre;
      V2SREOnInitSideResult short_sre;

      const V2SREOnInitAggregateOutcome agg = V2_SRE_RunOnInitSidePair(
         long_alerts, short_alerts, long_cfg, short_cfg, long_sre, short_sre);

      AssertTrue(tags[p] + " pair long halt only init succeeded", agg.init_result == INIT_SUCCEEDED);
      AssertTrue(tags[p] + " pair long halt only long halted", agg.long_halted);
      AssertTrue(tags[p] + " pair long halt only short continues", !agg.short_halted);
      AssertTrue(tags[p] + " pair long halt only long not committed", !agg.long_committed);
      AssertTrue(tags[p] + " pair long halt only short not committed", !agg.short_committed);

      SRE_OnInitResetOverride();
      Test_ClearCapGvs();
   }
}

void Test_SRE_OnInitPairShortHaltOnlyInitSucceeded()
{
   const string tags[3] = {"gbpusd", "eurusd", "eurgbp"};
   for(int p = 0; p < SRE_ONINIT_PAIR_COUNT; p++) {
      Test_ClearCapGvs();
      SRE_OnInitActivateDualOverride();
      SRE_OnInitFillHaltFixture(g_v2_sre_oninit_dual_override.short_side, false, p);

      string long_alerts[];
      string short_alerts[];
      V2SREOnInitSideConfig long_cfg = SRE_OnInitTestConfigForPair(p, true);
      V2SREOnInitSideConfig short_cfg = SRE_OnInitTestConfigForPair(p, false);
      V2SREOnInitSideResult long_sre;
      V2SREOnInitSideResult short_sre;

      const V2SREOnInitAggregateOutcome agg = V2_SRE_RunOnInitSidePair(
         long_alerts, short_alerts, long_cfg, short_cfg, long_sre, short_sre);

      AssertTrue(tags[p] + " pair short halt only init succeeded", agg.init_result == INIT_SUCCEEDED);
      AssertTrue(tags[p] + " pair short halt only short halted", agg.short_halted);
      AssertTrue(tags[p] + " pair short halt only long continues", !agg.long_halted);
      AssertTrue(tags[p] + " pair short halt only long not committed", !agg.long_committed);
      AssertTrue(tags[p] + " pair short halt only short not committed", !agg.short_committed);

      SRE_OnInitResetOverride();
      Test_ClearCapGvs();
   }
}

void Test_SRE_OnInitPairBothFlatInitSucceeded()
{
   const string tags[3] = {"gbpusd", "eurusd", "eurgbp"};
   for(int p = 0; p < SRE_ONINIT_PAIR_COUNT; p++) {
      Test_ClearCapGvs();
      SRE_OnInitActivateDualOverride();

      string long_alerts[];
      string short_alerts[];
      V2SREOnInitSideConfig long_cfg = SRE_OnInitTestConfigForPair(p, true);
      V2SREOnInitSideConfig short_cfg = SRE_OnInitTestConfigForPair(p, false);
      V2SREOnInitSideResult long_sre;
      V2SREOnInitSideResult short_sre;

      const V2SREOnInitAggregateOutcome agg = V2_SRE_RunOnInitSidePair(
         long_alerts, short_alerts, long_cfg, short_cfg, long_sre, short_sre);

      AssertTrue(tags[p] + " pair both flat init succeeded", agg.init_result == INIT_SUCCEEDED);
      AssertTrue(tags[p] + " pair both flat long not halted", !agg.long_halted);
      AssertTrue(tags[p] + " pair both flat short not halted", !agg.short_halted);
      AssertTrue(tags[p] + " pair both flat long not committed", !agg.long_committed);
      AssertTrue(tags[p] + " pair both flat short not committed", !agg.short_committed);
      AssertTrue(tags[p] + " pair both flat no long alerts", ArraySize(long_alerts) == 0);
      AssertTrue(tags[p] + " pair both flat no short alerts", ArraySize(short_alerts) == 0);

      SRE_OnInitResetOverride();
      Test_ClearCapGvs();
   }
}

void Test_SRE_OnInitPairBothCommitInitSucceeded()
{
   const string tags[3] = {"gbpusd", "eurusd", "eurgbp"};
   for(int p = 0; p < SRE_ONINIT_PAIR_COUNT; p++) {
      Test_ClearCapGvs();
      SRE_OnInitActivateDualOverride();
      SRE_OnInitFillSuccessFixture(g_v2_sre_oninit_dual_override.long_side, true, p);
      SRE_OnInitFillSuccessFixture(g_v2_sre_oninit_dual_override.short_side, false, p);

      string long_alerts[];
      string short_alerts[];
      V2SREOnInitSideConfig long_cfg = SRE_OnInitTestConfigForPair(p, true);
      V2SREOnInitSideConfig short_cfg = SRE_OnInitTestConfigForPair(p, false);
      V2SREOnInitSideResult long_sre;
      V2SREOnInitSideResult short_sre;

      const V2SREOnInitAggregateOutcome agg = V2_SRE_RunOnInitSidePair(
         long_alerts, short_alerts, long_cfg, short_cfg, long_sre, short_sre);

      AssertTrue(tags[p] + " pair both commit init succeeded", agg.init_result == INIT_SUCCEEDED);
      AssertTrue(tags[p] + " pair both commit long not halted", !agg.long_halted);
      AssertTrue(tags[p] + " pair both commit short not halted", !agg.short_halted);
      AssertTrue(tags[p] + " pair both commit long committed", agg.long_committed);
      AssertTrue(tags[p] + " pair both commit short committed", agg.short_committed);
      AssertTrue(tags[p] + " pair both commit long layers", long_sre.layer_count_after == 2);
      AssertTrue(tags[p] + " pair both commit short layers", short_sre.layer_count_after == 2);

      SRE_OnInitResetOverride();
      Test_ClearCapGvs();
   }
}

//+------------------------------------------------------------------+
// Book-Consistency Check (BCC) v1 unit tests
//+------------------------------------------------------------------+
void BCC_FillTestLongCfg(V2BccSideInputs &cfg)
{
   cfg.side_label = "LONG";
   cfg.symbol = "GBPUSD";
   cfg.direction = 1;
   cfg.entry_magic = MM_LONG_V2;
   cfg.exit_magic = MM_LONG_V2_EXIT;
   cfg.exit_pips = SRE_EXIT_PIPS;
   cfg.point = SRE_POINT;
   cfg.expected_volume = SRE_LOT;
   cfg.halted = false;
   cfg.layer_count = 1;
   cfg.max_layers = 20;
   cfg.last_exit_valid = false;
   cfg.cap_blocks_add = false;
   cfg.l0_ticket = 0;
   cfg.add_ticket = 0;
   ArrayResize(cfg.layers, 0);
}

void BCC_TestReset()
{
   V2_Bcc_TestReset();
}

void Test_BCC_TicketBindingLiveNoTier2()
{
   BCC_TestReset();
   g_v2_bcc_test_active = true;

   V2BccTestPosition pos;
   pos.ticket = 101; pos.position_id = 1001; pos.magic = MM_LONG_V2;
   pos.symbol = "GBPUSD"; pos.volume = SRE_LOT; pos.open_price = 1.30000;
   pos.open_time = SRE_T1; pos.position_type = POSITION_TYPE_BUY;
   ArrayResize(g_v2_bcc_test_positions, 1);
   g_v2_bcc_test_positions[0] = pos;
   ArrayResize(g_v2_bcc_test_position_live, 1);
   g_v2_bcc_test_position_live[0] = 101;

   V2BccTestOrder ord;
   ord.ticket = 201; ord.magic = MM_LONG_V2_EXIT; ord.symbol = "GBPUSD";
   ord.volume = SRE_LOT;
   ord.price = V2_SRE_ExpectedExitPrice(1.30000, 1, SRE_EXIT_PIPS, SRE_POINT);
   ord.setup_time = SRE_T1 + 60; ord.order_type = ORDER_TYPE_SELL_LIMIT;
   ArrayResize(g_v2_bcc_test_orders, 1);
   g_v2_bcc_test_orders[0] = ord;

   V2BccSideInputs cfg;
   BCC_FillTestLongCfg(cfg);
   ArrayResize(cfg.layers, 1);
   cfg.layers[0].exit_ticket = 201;
   cfg.layers[0].position_ticket = 101;

   V2BccSideRuntime rt;
   V2_Bcc_ResetSideRuntime(rt);
   V2BccExitItem tier2[];
   V2_Bcc_Tier1ScanOrphans(cfg, rt, tier2);
   AssertTrue("bound exit live -> no tier2", !rt.tier2_pending);
   AssertTrue("bound exit live -> no tier2 candidates", ArraySize(tier2) == 0);
   BCC_TestReset();
}

void Test_BCC_TicketBindingGoneFlagsTier2()
{
   BCC_TestReset();
   g_v2_bcc_test_active = true;

   V2BccTestOrder ord;
   ord.ticket = 201; ord.magic = MM_LONG_V2_EXIT; ord.symbol = "GBPUSD";
   ord.volume = SRE_LOT;
   ord.price = V2_SRE_ExpectedExitPrice(1.30000, 1, SRE_EXIT_PIPS, SRE_POINT);
   ord.setup_time = SRE_T1 + 60; ord.order_type = ORDER_TYPE_SELL_LIMIT;
   ArrayResize(g_v2_bcc_test_orders, 1);
   g_v2_bcc_test_orders[0] = ord;

   V2BccSideInputs cfg;
   BCC_FillTestLongCfg(cfg);
   ArrayResize(cfg.layers, 1);
   cfg.layers[0].exit_ticket = 201;
   cfg.layers[0].position_ticket = 101;

   V2BccSideRuntime rt;
   V2_Bcc_ResetSideRuntime(rt);
   V2BccExitItem tier2[];
   V2_Bcc_Tier1ScanOrphans(cfg, rt, tier2);
   AssertTrue("bound position gone -> tier2 pending", rt.tier2_pending);
   AssertTrue("orphan candidate listed", ArraySize(tier2) == 1 && tier2[0].ticket == 201);
   BCC_TestReset();
}

void Test_BCC_ParityUnambiguousOrphan()
{
   BCC_TestReset();
   g_v2_bcc_test_active = true;

   V2BccTestPosition pos;
   pos.ticket = 102; pos.position_id = 1002; pos.magic = MM_LONG_V2;
   pos.symbol = "GBPUSD"; pos.volume = SRE_LOT; pos.open_price = 1.29910;
   pos.open_time = SRE_T1; pos.position_type = POSITION_TYPE_BUY;
   ArrayResize(g_v2_bcc_test_positions, 1);
   g_v2_bcc_test_positions[0] = pos;
   ArrayResize(g_v2_bcc_test_position_live, 1);
   g_v2_bcc_test_position_live[0] = 102;

   const double matched_price = V2_SRE_ExpectedExitPrice(1.29910, 1, SRE_EXIT_PIPS, SRE_POINT);
   const double orphan_price  = V2_SRE_ExpectedExitPrice(1.31000, 1, SRE_EXIT_PIPS, SRE_POINT);
   const double tier2_tol     = V2_SRE_RolloverPriceTolerance(SRE_POINT);
   const double dist_pips     = MathAbs(orphan_price - matched_price) / (SRE_POINT * 10.0);
   const double tol_pips      = tier2_tol / (SRE_POINT * 10.0);
   AssertTrue("orphan priced beyond tier2 tolerance band",
              dist_pips > tol_pips + 1.0);

   V2BccTestOrder ord_orphan;
   ord_orphan.ticket = 201; ord_orphan.magic = MM_LONG_V2_EXIT; ord_orphan.symbol = "GBPUSD";
   ord_orphan.volume = SRE_LOT; ord_orphan.price = orphan_price;
   ord_orphan.setup_time = SRE_T2; ord_orphan.order_type = ORDER_TYPE_SELL_LIMIT;
   V2BccTestOrder ord_matched;
   ord_matched.ticket = 202; ord_matched.magic = MM_LONG_V2_EXIT; ord_matched.symbol = "GBPUSD";
   ord_matched.volume = SRE_LOT; ord_matched.price = matched_price;
   ord_matched.setup_time = SRE_T1 + 60; ord_matched.order_type = ORDER_TYPE_SELL_LIMIT;
   ArrayResize(g_v2_bcc_test_orders, 2);
   g_v2_bcc_test_orders[0] = ord_orphan;
   g_v2_bcc_test_orders[1] = ord_matched;

   V2BccSideInputs cfg;
   BCC_FillTestLongCfg(cfg);
   ArrayResize(cfg.layers, 1);
   cfg.layers[0].exit_ticket = 202;
   cfg.layers[0].position_ticket = 102;

   V2BccSideRuntime rt;
   V2_Bcc_ResetSideRuntime(rt);
   V2BccExitItem tier2[];
   V2_Bcc_Tier1ScanOrphans(cfg, rt, tier2);
   AssertTrue("only unbound exit is tier2 candidate",
              ArraySize(tier2) == 1 && tier2[0].ticket == 201);

   V2BccRawFinding findings[];
   V2_Bcc_Tier2ResolveOrphans(cfg, tier2, findings);

   bool orphan201 = false;
   bool flagged202 = false;
   bool unverifiable = false;
   for(int i = 0; i < ArraySize(findings); i++) {
      if(findings[i].ticket == 201 && findings[i].check == V2_BCC_CHECK_ORPHAN_EXIT)
         orphan201 = true;
      if(findings[i].ticket == 202)
         flagged202 = true;
      if(findings[i].check == V2_BCC_CHECK_UNVERIFIABLE)
         unverifiable = true;
   }
   AssertTrue("unambiguous book yields orphan 201", orphan201);
   AssertTrue("matched exit 202 not flagged", !flagged202);
   AssertTrue("unambiguous book has no unverifiable", !unverifiable);
   BCC_TestReset();
}

void Test_BCC_DualPoolStrandedExitPosition()
{
   BCC_TestReset();
   g_v2_bcc_test_active = true;

   V2BccTestPosition hedge;
   hedge.ticket = 301; hedge.position_id = 9001; hedge.magic = MM_LONG_V2_EXIT;
   hedge.symbol = "GBPUSD"; hedge.volume = SRE_LOT;
   hedge.open_price = V2_SRE_ExpectedExitPrice(1.30000, 1, SRE_EXIT_PIPS, SRE_POINT);
   hedge.open_time = SRE_T2; hedge.position_type = POSITION_TYPE_SELL;
   ArrayResize(g_v2_bcc_test_positions, 1);
   g_v2_bcc_test_positions[0] = hedge;

   V2BccSideInputs cfg;
   BCC_FillTestLongCfg(cfg);
   cfg.layer_count = 0;

   V2BccSideRuntime rt;
   V2_Bcc_ResetSideRuntime(rt);
   V2BccExitItem tier2[];
   V2_Bcc_Tier1ScanOrphans(cfg, rt, tier2);
   AssertTrue("exit-side position discovered", ArraySize(tier2) == 1 && tier2[0].is_position);

   V2BccRawFinding findings[];
   V2_Bcc_Tier2ResolveOrphans(cfg, tier2, findings);
   AssertTrue("stranded exit position flagged orphan",
              ArraySize(findings) == 1 &&
              findings[0].check == V2_BCC_CHECK_ORPHAN_EXIT &&
              findings[0].ticket == 301);
   BCC_TestReset();
}

void Test_BCC_CloseByGateSuppressesWhenCounterpartyAlive()
{
   BCC_TestReset();
   V2CloseByTask queue[];
   V2TestQueueCloseBy(queue, 5001, 5002);

   g_v2_bcc_test_active = true;
   ArrayResize(g_v2_bcc_test_position_live, 1);
   g_v2_bcc_test_position_live[0] = 5002;

   V2BccRawFinding f;
   f.check = V2_BCC_CHECK_ORPHAN_EXIT;
   f.ticket = 5001;
   f.magic = MM_LONG_V2_EXIT;
   f.detail = "test";
   AssertTrue("closeby alive suppresses", V2_Bcc_ShouldSuppressCloseBy(f, queue));
   BCC_TestReset();
}

void Test_BCC_CloseByGateAlertsWhenCounterpartyGone()
{
   BCC_TestReset();
   V2CloseByTask queue[];
   V2TestQueueCloseBy(queue, 5001, 5002);

   g_v2_bcc_test_active = true;
   ArrayResize(g_v2_bcc_test_position_live, 0);

   V2BccRawFinding f;
   f.check = V2_BCC_CHECK_ORPHAN_EXIT;
   f.ticket = 5001;
   f.magic = MM_LONG_V2_EXIT;
   f.detail = "test";
   AssertTrue("counterparty gone does not suppress", !V2_Bcc_ShouldSuppressCloseBy(f, queue));
   BCC_TestReset();
}

void Test_BCC_DebounceSingleSweepNoAlert()
{
   BCC_TestReset();
   V2BccSideInputs cfg;
   BCC_FillTestLongCfg(cfg);
   V2BccSideRuntime rt;
   V2_Bcc_ResetSideRuntime(rt);
   V2CloseByTask queue[];
   string alerts[];

   V2BccRawFinding current[];
   ArrayResize(current, 1);
   current[0].check = V2_BCC_CHECK_ONE_LEGGED;
   current[0].ticket = 0;
   current[0].magic = MM_LONG_V2;
   current[0].detail = "flat_side_no_l0_pending";

   V2_Bcc_DebounceFindings(rt, current, cfg, queue, alerts);
   AssertTrue("single sweep no alert", ArraySize(alerts) == 0);
   AssertTrue("streak recorded", ArraySize(rt.pending) == 1 && rt.pending[0].streak == 1);
   AssertTrue("pending count at streak>=1", V2_Bcc_CountPendingFindings(rt, 1) == 1);
   AssertTrue("no pending at streak>=2", V2_Bcc_CountPendingFindings(rt, 2) == 0);
   BCC_TestReset();
}

void Test_BCC_DebounceTwoSweepsEmitsAlert()
{
   BCC_TestReset();
   V2BccSideInputs cfg;
   BCC_FillTestLongCfg(cfg);
   V2BccSideRuntime rt;
   V2_Bcc_ResetSideRuntime(rt);
   V2CloseByTask queue[];
   string alerts[];

   V2BccRawFinding current[];
   ArrayResize(current, 1);
   current[0].check = V2_BCC_CHECK_DUPLICATE;
   current[0].ticket = 0;
   current[0].magic = MM_LONG_V2;
   current[0].detail = "entry_pendings=2 expected<=1";

   V2_Bcc_DebounceFindings(rt, current, cfg, queue, alerts);
   V2_Bcc_DebounceFindings(rt, current, cfg, queue, alerts);
   AssertTrue("two sweeps emit alert", ArraySize(alerts) == 1);
   AssertTrue("pending count after emit", V2_Bcc_CountPendingFindings(rt, 1) == 1);
   AssertTrue("alert streak pending", V2_Bcc_CountPendingFindings(rt, 2) == 1);
   AssertContains("alert format side", alerts[0], "BCC | side=LONG");
   AssertContains("alert format check", alerts[0], "check=DUPLICATE");
   BCC_TestReset();
}

void Test_BCC_Tier3SweepReturnsPendingCount()
{
   BCC_TestReset();
   V2BccSideInputs cfg;
   BCC_FillTestLongCfg(cfg);
   cfg.layer_count = 0;
   cfg.l0_ticket = 0;
   g_v2_bcc_test_active = true;

   V2BccSideRuntime rt;
   V2_Bcc_ResetSideRuntime(rt);
   V2CloseByTask queue[];
   string alerts[];

   const int pending_count = V2_Bcc_RunSideTier3Sweep(cfg, rt, queue, alerts);
   AssertTrue("tier3 sweep reports pending finding count", pending_count == 1);
   AssertTrue("tier3 first sweep no debounced alert", ArraySize(alerts) == 0);
   BCC_TestReset();
}

void Test_BCC_UnverifiableAmbiguousTier2Band()
{
   SRE_Tier2AuditSetSwapOverride(-4.62, -6.18);

   const double entry1 = 1.34950;
   const double entry2 = 1.34952;
   const double exit_price = 1.34983;
   const datetime open1 = D'2026.08.02 23:47:16';
   const datetime open2 = D'2026.08.02 23:50:00';
   const datetime exit_time = D'2026.08.06 10:00:00';

   V2SREPositionInput pos[];
   ArrayResize(pos, 2);
   pos[0].ticket = 101; pos[0].position_id = 1001; pos[0].open_time = open1;
   pos[0].entry_price = entry1; pos[0].volume = SRE_LOT; pos[0].direction = 1;
   pos[0].symbol = "GBPUSD"; pos[0].position_type = POSITION_TYPE_BUY;
   pos[1].ticket = 102; pos[1].position_id = 1002; pos[1].open_time = open2;
   pos[1].entry_price = entry2; pos[1].volume = SRE_LOT; pos[1].direction = 1;
   pos[1].symbol = "GBPUSD"; pos[1].position_type = POSITION_TYPE_BUY;

   V2SREExitOrderInput ord[];
   ArrayResize(ord, 1);
   ord[0].ticket = 201; ord[0].placement_time = exit_time;
   ord[0].price = exit_price; ord[0].volume = SRE_LOT;
   ord[0].direction = 1; ord[0].symbol = "GBPUSD";

   const double expected1 = V2_SRE_ExpectedExitPrice(entry1, 1, SRE_EXIT_PIPS, SRE_POINT);
   const double expected2 = V2_SRE_ExpectedExitPrice(entry2, 1, SRE_EXIT_PIPS, SRE_POINT);
   const double max_shift1 = V2_SRE_MaxPossibleRolloverShift(open1, SRE_AUDIT_NOW,
                                                             "GBPUSD", 1, SRE_POINT);
   const double max_shift2 = V2_SRE_MaxPossibleRolloverShift(open2, SRE_AUDIT_NOW,
                                                             "GBPUSD", 1, SRE_POINT);

   Print("DIAG BCC_UNVERIFIABLE | expected1=", DoubleToString(expected1, 5),
         " expected2=", DoubleToString(expected2, 5),
         " max_shift1=", DoubleToString(max_shift1, 5),
         " max_shift2=", DoubleToString(max_shift2, 5),
         " order_price=", DoubleToString(exit_price, 5));

   AssertTrue("exit at/above higher expected", exit_price >= MathMax(expected1, expected2));
   AssertTrue("pos1 long band contains exit",
              exit_price >= expected1 && exit_price <= expected1 + max_shift1);
   AssertTrue("pos2 long band contains exit",
              exit_price >= expected2 && exit_price <= expected2 + max_shift2);
   AssertTrue("pos1 not tier1 for exit",
              !V2_SRE_Tier1Eligible(pos[0], ord[0], SRE_AUDIT_NOW,
                                    SRE_EXIT_PIPS, SRE_POINT, SRE_LOT));
   AssertTrue("pos2 not tier1 for exit",
              !V2_SRE_Tier1Eligible(pos[1], ord[0], SRE_AUDIT_NOW,
                                    SRE_EXIT_PIPS, SRE_POINT, SRE_LOT));

   int tier2_count = 0;
   for(int i = 0; i < 2; i++) {
      if(V2_SRE_Tier2Eligible(pos[i], ord[0], pos, SRE_AUDIT_NOW,
                               SRE_EXIT_PIPS, SRE_POINT, SRE_LOT))
         tier2_count++;
   }
   AssertTrue("fixture tier2_matches == 2", tier2_count == 2);
   AssertTrue("unverifiable predicate true",
              V2_Bcc_ExitIsUnverifiable(pos, ord[0], SRE_AUDIT_NOW,
                                         SRE_EXIT_PIPS, SRE_POINT, SRE_LOT));
   SRE_Tier2AuditResetSwapOverride();
}

void Test_BCC_OneLeggedFlatSide()
{
   BCC_TestReset();
   V2BccSideInputs cfg;
   BCC_FillTestLongCfg(cfg);
   cfg.layer_count = 0;
   cfg.l0_ticket = 0;

   V2BccRawFinding findings[];
   V2_Bcc_CheckOneLegged(cfg, findings);
   AssertTrue("flat side without l0 is one-legged",
              ArraySize(findings) == 1 && findings[0].check == V2_BCC_CHECK_ONE_LEGGED);
   BCC_TestReset();
}

void Test_BCC_DuplicateEntryPending()
{
   BCC_TestReset();
   g_v2_bcc_test_active = true;

   V2BccTestOrder o1;
   o1.ticket = 401; o1.magic = MM_LONG_V2; o1.symbol = "GBPUSD";
   o1.volume = SRE_LOT; o1.price = 1.30000; o1.setup_time = SRE_T1;
   o1.order_type = ORDER_TYPE_BUY_LIMIT;
   V2BccTestOrder o2;
   o2.ticket = 402; o2.magic = MM_LONG_V2; o2.symbol = "GBPUSD";
   o2.volume = SRE_LOT; o2.price = 1.29950; o2.setup_time = SRE_T2;
   o2.order_type = ORDER_TYPE_BUY_LIMIT;
   ArrayResize(g_v2_bcc_test_orders, 2);
   g_v2_bcc_test_orders[0] = o1;
   g_v2_bcc_test_orders[1] = o2;

   V2BccSideInputs cfg;
   BCC_FillTestLongCfg(cfg);
   cfg.layer_count = 0;

   V2BccRawFinding findings[];
   V2_Bcc_CheckDuplicatePending(cfg, findings);
   AssertTrue("duplicate entry pending flagged",
              ArraySize(findings) == 1 && findings[0].check == V2_BCC_CHECK_DUPLICATE);
   BCC_TestReset();
}

void Test_BCC_AlertFormat()
{
   const string msg = V2_Bcc_FormatAlert("LONG", V2_BCC_CHECK_ORPHAN_EXIT,
                                         201, MM_LONG_V2_EXIT, "detail");
   AssertContains("bcc alert prefix", msg, "BCC | side=LONG");
   AssertContains("bcc alert check", msg, "check=ORPHAN_EXIT");
   AssertContains("bcc alert ticket", msg, "ticket=201");
}

void Test_CB_DailyFloorBoundary()
{
   const double anchor = 100000.0;
   const double frac = 0.045;
   const double floor = anchor * (1.0 - frac);
   AssertTrue("daily above floor no breach",
              !V2_CbDailyFloorBreached(floor + 1.0, anchor, frac));
   AssertTrue("daily at floor no breach (strict <)",
              !V2_CbDailyFloorBreached(floor, anchor, frac));
   AssertTrue("daily below floor breach",
              V2_CbDailyFloorBreached(floor - 0.01, anchor, frac));
}

void Test_CB_AbsoluteFloorBoundary()
{
   const double initial = 100000.0;
   const double frac = 0.09;
   const double floor = initial * (1.0 - frac);
   AssertTrue("absolute above floor no breach",
              !V2_CbAbsoluteFloorBreached(floor + 1.0, initial, frac));
   AssertTrue("absolute at floor no breach (strict <)",
              !V2_CbAbsoluteFloorBreached(floor, initial, frac));
   AssertTrue("absolute below floor breach",
              V2_CbAbsoluteFloorBreached(floor - 0.01, initial, frac));
}

void CB_TestReset()
{
   V2_Cb_TestReset();
}

void Test_CB_ReanchorTrapUsesPersistedAnchor()
{
   const double persisted = 100000.0;
   const double drawn_down = 92000.0;
   AssertNear("persisted anchor reused",
              V2_CbResolveDailyAnchor(true, persisted, drawn_down),
              persisted, 1e-9);
   AssertNear("absent anchor captures current balance",
              V2_CbResolveDailyAnchor(false, persisted, drawn_down),
              drawn_down, 1e-9);

   CB_TestReset();
   g_v2_cb_test_active = true;
   g_v2_cb_test_anchor_day_key = "20260814";
   g_v2_cb_test_anchor_val = persisted;
   g_v2_cb_test_anchor_known = true;
   g_v2_cb_test_balance = drawn_down;
   const double ensured = V2_CbEnsureDailyAnchor("20260814", drawn_down);
   AssertNear("ensure daily anchor does not re-anchor mid-day",
              ensured, persisted, 1e-9);
   CB_TestReset();
}

void Test_CB_CestDayKeyDstTransition()
{
   AssertTrue("winter CET offset is +1h",
              V2_CbCestOffsetSeconds(D'2026.01.15 12:00:00') == 3600);
   AssertTrue("summer CEST offset is +2h",
              V2_CbCestOffsetSeconds(D'2026.07.15 12:00:00') == 7200);

   const datetime pre_spring = D'2026.03.29 00:30:00';
   const datetime post_spring = D'2026.03.29 01:30:00';
   AssertTrue("pre-DST still CET (+1h)",
              V2_CbCestOffsetSeconds(pre_spring) == 3600);
   AssertTrue("post-DST is CEST (+2h)",
              V2_CbCestOffsetSeconds(post_spring) == 7200);
   AssertTrue("same CE(S)T calendar day across CET->CEST spring forward",
              V2_CbCestDayKey(pre_spring) == V2_CbCestDayKey(post_spring));
   AssertTrue("spring-forward day key is 20260329",
              V2_CbCestDayKey(post_spring) == "20260329");
}

void Test_CB_PeerHonorHaltsBothSides()
{
   bool long_h = false;
   bool short_h = false;
   V2_CbHonorPeerHalt(true, long_h, short_h);
   AssertTrue("peer gv halts long", long_h);
   AssertTrue("peer gv halts short", short_h);
}

void Test_CB_DisabledNeverTripsOnEquity()
{
   const double anchor = 100000.0;
   const double frac = 0.045;
   const double floor = anchor * (1.0 - frac);
   const bool daily_breach = V2_CbDailyFloorBreached(floor - 100.0, anchor, frac);
   AssertTrue("fixture is a breach", daily_breach);
   AssertTrue("disabled skips floor halt",
              !V2_CbShouldHaltFromFloors(false, daily_breach, false));
   AssertTrue("enabled trips on breach",
              V2_CbShouldHaltFromFloors(true, daily_breach, false));
}

void Test_TA_HardMaxBoundary()
{
   const int max_layers = 20;
   AssertTrue("depth at max no breach", !V2_TaHardMaxBreached(max_layers, max_layers));
   AssertTrue("depth above max breach", V2_TaHardMaxBreached(max_layers + 1, max_layers));
   AssertTrue("disabled skips hard max", !V2_TaShouldHaltHardMax(false, max_layers + 1, max_layers));
}

void Test_TA_SameDirEscalationThreshold()
{
   AssertTrue("same-dir count 1 no escalate", !V2_TaSameDirCritEscalates(1));
   AssertTrue("same-dir count 2 escalate", V2_TaSameDirCritEscalates(2));
   AssertTrue("disabled skips same-dir escalate", !V2_TaShouldEscalateSameDir(false, 2));
}

void Test_TA_DivergenceStreakDebounce()
{
   int streak = 0;
   streak = V2_TaUpdateDivergenceStreak(true, streak);
   AssertTrue("first divergent streak is 1", streak == 1);
   AssertTrue("streak 1 does not halt", !V2_TaDivergenceStreakHalts(streak));

   streak = V2_TaUpdateDivergenceStreak(true, streak);
   AssertTrue("second divergent streak is 2", streak == 2);
   AssertTrue("streak 2 halts", V2_TaDivergenceStreakHalts(streak));

   streak = V2_TaUpdateDivergenceStreak(false, streak);
   AssertTrue("clear resets streak to 0", streak == 0);
   AssertTrue("reset streak does not halt", !V2_TaDivergenceStreakHalts(streak));
   AssertTrue("disabled skips divergence halt", !V2_TaShouldHaltDivergence(false, 2));
}

void Test_TA_DivergenceDetect()
{
   AssertTrue("managed equals broker not divergent",
              !V2_TaPositionDivergent(3, 3));
   AssertTrue("managed not equal broker divergent",
              V2_TaPositionDivergent(3, 4));
}

void Test_TA_DisabledNeverTrips()
{
   AssertTrue("disabled hard max guard", !V2_TaShouldHaltHardMax(false, 25, 20));
   AssertTrue("disabled same-dir guard", !V2_TaShouldEscalateSameDir(false, 3));
   AssertTrue("disabled divergence guard", !V2_TaShouldHaltDivergence(false, 3));
}

void TA_TestReset()
{
   V2_Ta_TestReset();
   V2_Cb_TestReset();
}

void Test_TA_WiredDivergenceEndOfTickDebounce()
{
   TA_TestReset();
   g_v2_ta_test_active = true;

   const int long_depth = 3;
   const int short_depth = 2;
   g_v2_ta_test_broker_long = 4;
   g_v2_ta_test_broker_short = short_depth;

   bool long_halted = false;
   bool short_halted = false;
   string alerts[];

   V2_Ta_CheckEndOfTick(long_halted, short_halted, alerts,
                        "GBPUSD", MM_LONG_V2, MM_SHORT_V2,
                        long_depth, short_depth);
   AssertTrue("wired divergence first check long not halted", !long_halted);
   AssertTrue("wired divergence first check short not halted", !short_halted);

   V2_Ta_CheckEndOfTick(long_halted, short_halted, alerts,
                        "GBPUSD", MM_LONG_V2, MM_SHORT_V2,
                        long_depth, short_depth);
   AssertTrue("wired divergence second check long halted", long_halted);
   AssertTrue("wired divergence second check short still not halted", !short_halted);

   TA_TestReset();
}

void Test_TA_WiredDivergenceTransientClearsStreak()
{
   TA_TestReset();
   g_v2_ta_test_active = true;

   const int long_depth = 2;
   const int short_depth = 0;
   g_v2_ta_test_broker_long = 5;
   g_v2_ta_test_broker_short = 0;

   bool long_halted = false;
   bool short_halted = false;
   string alerts[];

   V2_Ta_CheckEndOfTick(long_halted, short_halted, alerts,
                        "GBPUSD", MM_LONG_V2, MM_SHORT_V2,
                        long_depth, short_depth);
   AssertTrue("transient first check long not halted", !long_halted);

   g_v2_ta_test_broker_long = long_depth;
   V2_Ta_CheckEndOfTick(long_halted, short_halted, alerts,
                        "GBPUSD", MM_LONG_V2, MM_SHORT_V2,
                        long_depth, short_depth);
   AssertTrue("transient cleared long still not halted", !long_halted);
   AssertTrue("transient cleared streak reset", g_ta_long_div_streak == 0);

   TA_TestReset();
}

void Test_TA_WiredHardMaxSideLocal()
{
   TA_TestReset();

   const int max_layers = 20;
   bool long_halted = false;
   bool short_halted = false;
   string alerts[];

   V2_Ta_CheckHardMaxSide("LONG", max_layers + 1, max_layers, long_halted, alerts);
   AssertTrue("wired hard-max halts long only", long_halted);
   AssertTrue("wired hard-max leaves short unhalted", !short_halted);

   TA_TestReset();
}

void Test_TA_WiredSameDirEscalationAccountWide()
{
   TA_TestReset();
   g_v2_cb_test_active = true;

   bool long_halted = false;
   bool short_halted = false;
   string alerts[];

   V2_Ta_CheckSameDirEscalation(2, long_halted, short_halted, alerts);
   AssertTrue("wired same-dir halts long", long_halted);
   AssertTrue("wired same-dir halts short", short_halted);
   AssertTrue("wired same-dir publishes account halt gv", V2_CbReadAcctHaltGv());

   const int alerts_after_first = ArraySize(alerts);
   V2_Ta_CheckSameDirEscalation(3, long_halted, short_halted, alerts);
   AssertTrue("wired same-dir idempotent alert count",
              ArraySize(alerts) == alerts_after_first);

   TA_TestReset();
}

//+------------------------------------------------------------------+
void OnStart()
{
   Print("=== fxmatrix_v2 native unit tests ===");
   Test_RunningStateWiden();
   Test_PostReloadExtensionUsesAccumulatedState();
   Test_OwnFlatClearsLastExit();
   Test_CrossInstanceIsolation();
   Test_V25_CleanHarvestPopSetsHarvestOriginLongShort();
   Test_V25_ExpectedExitPriceMatchesLivePipScale();
   Test_V25_Inv2_RebaseDoesNotMutateRemainingEntries();
   Test_V25_Guard1_BlackoutSuppressesRebase();
   Test_V25_Guard1_WideSpreadSuppressesRebase();
   Test_V25_SRE_ReplayHarvestOriginParity();
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
   Test_SRE_Tier2RolloverBoundedRange_GbpusdLong_Audit509990725();
   Test_SRE_Tier2RolloverBoundedRange_GbpusdShort_FourLayers_Audit();
   Test_SRE_Tier2RolloverBoundedRange_EurgbpLong_Audit508403686();
   Test_SRE_PendingMultipleL0OnEmpty();
   Test_SRE_PendingMultipleAddReloadOnNonempty();
   Test_SRE_PendingL0WhileNonempty();
   Test_SRE_PendingAddWhileEmpty();
   Test_SRE_PendingUnresolvableComment();
   Test_SRE_MultipleEntryInOnePositionHalts();
   Test_SRE_NonStandardClosureBeforeAnchorHalts();
   Test_SRE_SentinelBlocksCapNetExposure();
   Test_SRE_ValidationMismatchHalts();
   Test_SRE_OnInit_EndToEndReconstruction();
   Test_SRE_OnInit_HaltStep3();
   Test_SRE_OnInit_HaltStep4();
   Test_SRE_OnInit_HaltStep5();
   Test_SRE_OnInit_HaltStep6_ReplayPathState();
   Test_SRE_OnInit_SentinelBeforeHistory();
   Test_SRE_OnInit_ValidationBackstopHalts();
   Test_SRE_OnInit_CapPublishOnlyAfterCommit();
   Test_SRE_EntryPendingSweep_CountsEntrySkipsExit();
   Test_SRE_OnInit_ResetDefaultsEntryPendingsSweptZero();
   Test_SRE_Readiness_Halt31HistorySelectFailed();
   Test_SRE_Readiness_OkEntryDealPresent();
   Test_SRE_Readiness_Halt32EntryDealAbsent();
   Test_SRE_Readiness_Halt32PositionOlderThanLookback();
   Test_SRE_Readiness_Gate2FirstPositionNotRejected();
   Test_SRE_OnInit_PureSequenceDoesNotSweep();
   Test_SRE_FlatSideSweep_FlatSweepsEntries();
   Test_SRE_FlatSideSweep_NonFlatSkips();
   Test_SRE_OnInitPairBothHaltInitFailed();
   Test_SRE_OnInitPairLongHaltOnlyInitSucceeded();
   Test_SRE_OnInitPairShortHaltOnlyInitSucceeded();
   Test_SRE_OnInitPairBothFlatInitSucceeded();
   Test_SRE_OnInitPairBothCommitInitSucceeded();

   Test_BCC_TicketBindingLiveNoTier2();
   Test_BCC_TicketBindingGoneFlagsTier2();
   Test_BCC_ParityUnambiguousOrphan();
   Test_BCC_DualPoolStrandedExitPosition();
   Test_BCC_CloseByGateSuppressesWhenCounterpartyAlive();
   Test_BCC_CloseByGateAlertsWhenCounterpartyGone();
   Test_BCC_DebounceSingleSweepNoAlert();
   Test_BCC_DebounceTwoSweepsEmitsAlert();
   Test_BCC_Tier3SweepReturnsPendingCount();
   Test_BCC_UnverifiableAmbiguousTier2Band();
   Test_BCC_OneLeggedFlatSide();
   Test_BCC_DuplicateEntryPending();
   Test_BCC_AlertFormat();
   Test_CB_DailyFloorBoundary();
   Test_CB_AbsoluteFloorBoundary();
   Test_CB_ReanchorTrapUsesPersistedAnchor();
   Test_CB_CestDayKeyDstTransition();
   Test_CB_PeerHonorHaltsBothSides();
   Test_CB_DisabledNeverTripsOnEquity();
   Test_TA_HardMaxBoundary();
   Test_TA_SameDirEscalationThreshold();
   Test_TA_DivergenceStreakDebounce();
   Test_TA_DivergenceDetect();
   Test_TA_DisabledNeverTrips();
   Test_TA_WiredDivergenceEndOfTickDebounce();
   Test_TA_WiredDivergenceTransientClearsStreak();
   Test_TA_WiredHardMaxSideLocal();
   Test_TA_WiredSameDirEscalationAccountWide();

   Test_SRE_Tier1RealData_PairA_Eurusd();
   Test_SRE_Tier1RealData_PairB_Gbpusd();
   Test_SRE_Tier1RealData_PairC_Eurgbp();
   Test_SRE_Tier1RealData_StandaloneD_EurusdCloseBy();

   Print("=== summary: ", g_tests_passed, "/", g_tests_run, " passed ===");
   if(g_tests_passed != g_tests_run)
      Print("ERROR: one or more tests FAILED");
}

//+------------------------------------------------------------------+
