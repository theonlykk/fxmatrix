//+------------------------------------------------------------------+
//| fxmatrix_v2_tests.mq5 — native unit tests for production V2 logic |
//| Run in Strategy Tester or as script (OnStart). No live trading.   |
//+------------------------------------------------------------------+
#property copyright "fxmatrix"
#property version   "1.01"
#property script_show_inputs
#property strict

#include "fxmatrix_v2_logic.mqh"

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
// (c) Exit path uses ticket-targeted TRADE_ACTION_SLTP (genuine position close)
void Test_ExitSltpRequestShape()
{
   MqlTradeRequest req;
   const ulong pos_ticket = 123456789;
   const double tp = 1.25300;

   AssertTrue("build sltp ok",
              V2_BuildExitSltpRequest("GBPUSD", pos_ticket, tp, req));
   AssertTrue("action is TRADE_ACTION_SLTP", req.action == TRADE_ACTION_SLTP);
   AssertTrue("position ticket targeted", req.position == pos_ticket);
   AssertTrue("tp set", MathAbs(req.tp - tp) < 1e-9);
   AssertTrue("no sl on exit-only modify", req.sl == 0.0);
   AssertTrue("symbol set", req.symbol == "GBPUSD");

   MqlTradeRequest bad;
   AssertTrue("zero ticket rejected", !V2_BuildExitSltpRequest("GBPUSD", 0, tp, bad));
}

//+------------------------------------------------------------------+
void OnStart()
{
   Print("=== fxmatrix_v2 native unit tests ===");
   Test_RunningStateWiden();
   Test_PostReloadExtensionUsesAccumulatedState();
   Test_OwnFlatClearsLastExit();
   Test_CrossInstanceIsolation();
   Test_ExitSltpRequestShape();

   Print("=== summary: ", g_tests_passed, "/", g_tests_run, " passed ===");
   if(g_tests_passed != g_tests_run)
      Print("ERROR: one or more tests FAILED");
}

//+------------------------------------------------------------------+
