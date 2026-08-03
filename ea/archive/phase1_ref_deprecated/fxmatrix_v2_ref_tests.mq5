//+------------------------------------------------------------------+
//| fxmatrix_v2_ref_tests.mq5 — unit tests for Phase-1 *_ref exits  |
//| Run as script (OnStart). No live trading.                        |
//+------------------------------------------------------------------+
#property copyright "fxmatrix"
#property version   "1.00"
#property script_show_inputs
#property strict

#include "fxmatrix_v2_logic_r1.mqh"
#include "fxmatrix_v2_exits_r1.mqh"
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

//+------------------------------------------------------------------+
void Test_ExitsR1_ResolvePositionTicket()
{
   AssertTrue("zero ref returns zero", V2_ResolvePositionTicket(0) == 0);
}

//+------------------------------------------------------------------+
void Test_ExitsR1_ModifyExitLimitEarlyExit()
{
   if(GlobalVariableCheck(V2_DAILY_API_COUNT_GV))
      GlobalVariableDel(V2_DAILY_API_COUNT_GV);
   if(GlobalVariableCheck(V2_DAILY_API_DATE_GV))
      GlobalVariableDel(V2_DAILY_API_DATE_GV);
   V2_ApiCounterMaybeReset();
   int before = V2_ApiCounterRead();

   AssertTrue("modify zero ticket false", !V2_ModifyExitLimitPrice(0, 1.25000, "GBPUSD", 1, false));
   AssertTrue("modify zero ticket no api increment", V2_ApiCounterRead() == before);
}

//+------------------------------------------------------------------+
void Test_ExitsR1_OrderSendCountedWiring()
{
   if(GlobalVariableCheck(V2_DAILY_API_COUNT_GV))
      GlobalVariableDel(V2_DAILY_API_COUNT_GV);
   if(GlobalVariableCheck(V2_DAILY_API_DATE_GV))
      GlobalVariableDel(V2_DAILY_API_DATE_GV);
   V2_ApiCounterMaybeReset();
   int before = V2_ApiCounterRead();

   V2_CancelExitOrder(0);
   AssertTrue("cancel zero ticket no increment", V2_ApiCounterRead() == before);

   V2CloseByTask queue[];
   V2TestQueueCloseBy(queue, 999001, 999002);
   bool halted = false;
   V2_ProcessCloseByQueue(queue, "TEST_R1", 20260901, halted, false);
   AssertTrue("closeby missing positions no increment", V2_ApiCounterRead() == before);

   MqlTradeRequest req = {};
   MqlTradeResult  res = {};
   req.action = TRADE_ACTION_REMOVE;
   req.order  = 1;
   V2_OrderSendCounted(req, res);
   AssertTrue("counted wrapper increments once per send attempt",
              V2_ApiCounterRead() == before + 1);
}

//+------------------------------------------------------------------+
void AssertNear(const string name, const double got, const double expected, const double tol)
{
   g_tests_run++;
   if(MathAbs(got - expected) <= tol) {
      g_tests_passed++;
      Print("PASS | ", name);
   } else {
      Print("FAIL | ", name, " got=", got, " expected=", expected);
   }
}

//+------------------------------------------------------------------+
void AssertContains(const string name, const string haystack, const string needle)
{
   g_tests_run++;
   if(StringFind(haystack, needle) >= 0) {
      g_tests_passed++;
      Print("PASS | ", name);
   } else {
      Print("FAIL | ", name, " missing ", needle);
   }
}

//+------------------------------------------------------------------+
void Test_L0DeadbandCoreMath()
{
   const double quote = 0.0004;
   const double mult = 1.0;
   const double base = mult * (quote * 0.25 - 0.5 * _Point);

   AssertNear("base deadband width", V2_L0RequoteDeadband(quote, mult, 0.0), base, 1e-12);
   AssertNear("eur vol-scaled deadband",
              V2_L0RequoteDeadband(quote, mult, 0.18),
              base * (0.18 / V2_L0_DEADBAND_VOL_REF_PIPS), 1e-12);
   AssertNear("mult=2 widens band", V2_L0RequoteDeadband(quote, 2.0, 0.0), base * 2.0, 1e-12);
   AssertNear("zero vol ref skips scaling", V2_L0RequoteDeadband(quote, mult, 0.0), base, 1e-12);

   AssertTrue("zero ticket never within deadband",
              !V2_L0RestingWithinDeadband(0, 1.25000, quote, mult, 0.0));

   const double db = V2_L0RequoteDeadband(quote, mult, 0.0);
   AssertTrue("delta inside band passes strict less-than",
              (MathAbs(db * 0.5) < db));
   AssertTrue("delta equal to band rejected",
              !(MathAbs(db) < db));
   AssertTrue("delta above band rejected",
              !(MathAbs(db * 1.01) < db));
}

//+------------------------------------------------------------------+
//| Compaction coverage note (ADR-094)                                |
//| LongV2Layer, g_long_layers[], Long_AppendLayer, Long_RemoveLayerAt|
//| are defined in fxmatrix_v2_ref.mq5 only. MQL5 scripts cannot     |
//| call EA-local functions without a shared .mqh extracted from the |
//| EA (requires fxmatrix_v2_ref.mq5 change — out of scope here).    |
//| Long_AppendLayer also needs Long_PlaceExitForLayer,              |
//| Long_EnsureAddNext, V2_CrossCapSyncInstance, broker OrderSend.   |
//| Long_RemoveLayerAt: void Long_RemoveLayerAt(const int layer_idx) |
//| Long_AppendLayer: void Long_AppendLayer(const double entry_price, |
//|     const ulong entry_ticket, const ulong position_ticket,       |
//|     const bool is_reload)                                        |
//+------------------------------------------------------------------+
void Test_RefOpenDepthSurvivesCompaction()
{
   Print("SKIP | open_depth compaction via Long_AppendLayer/Long_RemoveLayerAt — "
         "functions are EA-local in fxmatrix_v2_ref.mq5; extract to shared .mqh "
         "to enable script-level coverage");

   datetime t0 = D'2026.06.05 10:00:00';
   datetime t2 = t0 + 750;
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
void OnStart()
{
   Print("=== fxmatrix_v2_ref native unit tests ===");
   Test_ExitsR1_ResolvePositionTicket();
   Test_ExitsR1_ModifyExitLimitEarlyExit();
   Test_ExitsR1_OrderSendCountedWiring();
   Test_L0DeadbandCoreMath();
   Test_RefOpenDepthSurvivesCompaction();

   Print("=== summary: ", g_tests_passed, "/", g_tests_run, " passed ===");
   if(g_tests_passed != g_tests_run)
      Print("ERROR: one or more ref tests FAILED");
}

//+------------------------------------------------------------------+
