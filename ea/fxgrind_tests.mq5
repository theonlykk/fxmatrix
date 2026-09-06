//+------------------------------------------------------------------+
//| fxgrind_tests.mq5 — unit tests for fxgrind Spec A (T1–T17)      |
//| Run in Strategy Tester or as script. No live trading.            |
//+------------------------------------------------------------------+
#property copyright "fxmatrix"
#property version   "1.00"
#property script_show_inputs
#property strict

#include "grind_comment.mqh"
#include "grind_engine.mqh"

int g_tests_run = 0;
int g_tests_passed = 0;

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

void AssertEqStr(const string name, const string got, const string expected)
{
   AssertTrue(name, got == expected);
}

void Test_T1_CommentConstructor()
{
   AssertEqStr("T1 OPT L0 ENT", GrindCommentBuild("OPT", "L", 0, "ENT"), "GRIND|OPT|L|L00|ENT");
   AssertEqStr("T1 OPT L12 ENT", GrindCommentBuild("OPT", "L", 12, "ENT"), "GRIND|OPT|L|L12|ENT");
   AssertEqStr("T1 OPT S0 EXT", GrindCommentBuild("OPT", "S", 0, "EXT"), "GRIND|OPT|S|L00|EXT");
   AssertEqStr("T1 OPT S12 EXT", GrindCommentBuild("OPT", "S", 12, "EXT"), "GRIND|OPT|S|L12|EXT");
   AssertEqStr("T1 ALT L0 ENT", GrindCommentBuild("ALT", "L", 0, "ENT"), "GRIND|ALT|L|L00|ENT");
   AssertEqStr("T1 ALT L12 ENT", GrindCommentBuild("ALT", "L", 12, "ENT"), "GRIND|ALT|L|L12|ENT");
   AssertEqStr("T1 ALT S0 EXT", GrindCommentBuild("ALT", "S", 0, "EXT"), "GRIND|ALT|S|L00|EXT");
   AssertEqStr("T1 ALT S12 EXT", GrindCommentBuild("ALT", "S", 12, "EXT"), "GRIND|ALT|S|L12|EXT");
}

void Test_T2_CommentRoundTrip()
{
   string cases[8];
   cases[0] = GrindCommentBuild("OPT", "L", 0, "ENT");
   cases[1] = GrindCommentBuild("OPT", "L", 12, "ENT");
   cases[2] = GrindCommentBuild("OPT", "S", 0, "EXT");
   cases[3] = GrindCommentBuild("OPT", "S", 12, "EXT");
   cases[4] = GrindCommentBuild("ALT", "L", 0, "ENT");
   cases[5] = GrindCommentBuild("ALT", "L", 12, "ENT");
   cases[6] = GrindCommentBuild("ALT", "S", 0, "EXT");
   cases[7] = GrindCommentBuild("ALT", "S", 12, "EXT");

   for(int i = 0; i < 8; i++) {
      string slot, side, role;
      int layer;
      AssertTrue("T2 parse " + IntegerToString(i), GrindCommentParse(cases[i], slot, side, layer, role));
   }
}

void Test_T3_CommentLength()
{
   AssertTrue("T3 max layer", GrindCommentLengthForLayer(99, "OPT", "L", "EXT") <= GRIND_COMMENT_MAX_LEN);
}

void Test_T3b_ContaminatedRole()
{
   string slot, side, role;
   int layer;
   AssertTrue("T3b parse", GrindCommentParse("GRIND|OPT|L|L03|EXT[tp]", slot, side, layer, role));
   AssertEqStr("T3b role", role, "EXT");
}

void Test_T3c_MalformedComments()
{
   string slot, side, role;
   int layer;
   AssertTrue("T3c short", !GrindCommentParse("GRIND|OPT|L|L03", slot, side, layer, role));
   AssertTrue("T3c prefix", !GrindCommentParse("V2|OPT|L|L03|EXT", slot, side, layer, role));
}

void Test_T4_StraddlePrices()
{
   const double point = 0.00001;
   AssertNear("T4 buy", Grind_StraddleBuyPrice(1.25000, 9.0, point), 1.24910, 1e-10);
   AssertNear("T4 sell", Grind_StraddleSellPrice(1.25000, 9.0, point), 1.25090, 1e-10);
}

void Test_T5_ExitPrice()
{
   const double point = 0.00001;
   AssertNear("T5 long", Grind_ExitPrice(1.25000, 3.0, point, 1), 1.25030, 1e-10);
   AssertNear("T5 short", Grind_ExitPrice(1.25000, 3.0, point, -1), 1.24970, 1e-10);
}

void Test_T6_LayerCap()
{
   AssertTrue("T6 entry cap", !Grind_CanPlaceEntryLayer(12, 12));
   AssertTrue("T6 exit ok", Grind_CanPlaceExitLayer(12));
}

void Test_T7_Deadband()
{
   const double point = 0.00001;
   AssertTrue("T7 inside", Grind_PriceWithinDeadband(1.25000, 1.25003, 4.0, point));
   AssertTrue("T7 outside", !Grind_PriceWithinDeadband(1.25000, 1.25050, 4.0, point));
}

void Test_T8_ExactMagic()
{
   const ulong magic = 22260101UL;
   AssertTrue("T8 match", Grind_MagicMatches((long)magic, magic));
   AssertTrue("T8 plus1", !Grind_MagicMatches((long)(magic + 1), magic));
}

void Test_T9_OfflineMarket()
{
   AssertTrue("T9 disabled", !Grind_MarketTradeModeFull((long)SYMBOL_TRADE_MODE_DISABLED));
   AssertTrue("T9 full", Grind_MarketTradeModeFull((long)SYMBOL_TRADE_MODE_FULL));
}

void Test_T10_FailClosedStub()
{
   g_grind_halted = false;
   if(!Grind_ReconstructState())
      g_grind_halted = true;
   AssertTrue("T10 halted", g_grind_halted);
}

void Test_T11_PoisonedDefaults()
{
   AssertTrue("T11 width validate", !Grind_ValidateGeometryInputs(-1.0, 3.0, 12, 18.0, 10.0));
   AssertTrue("T11 exit validate", !Grind_ValidateGeometryInputs(9.0, -1.0, 12, 18.0, 10.0));
   AssertTrue("T11 width OnInit", Grind_TestOnInitGeometryCheck(-1.0, 3.0, 12, 18.0, 10.0, 22260101UL) == INIT_FAILED);
   AssertTrue("T11 exit OnInit", Grind_TestOnInitGeometryCheck(9.0, -1.0, 12, 18.0, 10.0, 22260101UL) == INIT_FAILED);
}

void Test_T12_UnconfiguredAddPips()
{
   AssertTrue("T12 add validate", !Grind_ValidateGeometryInputs(9.0, 3.0, 12, 18.0, -1.0));
}

void Test_T13_LongAddTarget()
{
   const double point = 0.00001;
   AssertNear("T13 long add", Grind_AddTargetPrice(1.25000, 10.0, point, 1), 1.24900, 1e-10);
}

void Test_T14_ShortAddTarget()
{
   const double point = 0.00001;
   AssertNear("T14 short add", Grind_AddTargetPrice(1.25000, 10.0, point, -1), 1.25100, 1e-10);
}

void Test_T15_IdenticalSpacingAtDepth()
{
   const double add_pips = 10.0;
   const double anchor = 1.25000;
   const double expected = 1.24900;
   int depths[3] = {1, 4, 11};
   for(int d = 0; d < 3; d++) {
      GrindSideState side;
      ArrayResize(side.layers, depths[d]);
      for(int i = 0; i < depths[d]; i++)
         side.layers[i].entry_price = anchor;
      const double target = Grind_ComputeAddTarget(side, true, add_pips);
      AssertNear("T15 depth " + IntegerToString(depths[d]), target, expected, 1e-10);
   }
}

void Test_T16_SimulatorParity()
{
   const double point = 0.00001;
   AssertNear("T16 width5", Grind_AddTargetPrice(1.25000, 10.0, point, 1), 1.24900, 1e-10);
   AssertNear("T16 width2.5", Grind_AddTargetPrice(1.25000, 5.0, point, 1), 1.24950, 1e-10);
}

void Test_T17_AddWidthRelationship()
{
   AssertTrue("T17 mismatch", !Grind_ValidateAddWidthRelationship(5.0, 9.0));
   AssertTrue("T17 match", Grind_ValidateAddWidthRelationship(5.0, 10.0));
}

void Test_OrderBudgetArithmetic()
{
   AssertTrue("budget 12 side", Grind_RestingOrderBudgetPerSide(12) == 13);
   AssertTrue("budget inst", Grind_RestingOrderBudgetInstance(12, 12) == 26);
   AssertTrue("budget eurgbp", Grind_RestingOrderBudgetInstance(8, 8) == 18);
}

void OnStart()
{
   Test_T1_CommentConstructor();
   Test_T2_CommentRoundTrip();
   Test_T3_CommentLength();
   Test_T3b_ContaminatedRole();
   Test_T3c_MalformedComments();
   Test_T4_StraddlePrices();
   Test_T5_ExitPrice();
   Test_T6_LayerCap();
   Test_T7_Deadband();
   Test_T8_ExactMagic();
   Test_T9_OfflineMarket();
   Test_T10_FailClosedStub();
   Test_T11_PoisonedDefaults();
   Test_T12_UnconfiguredAddPips();
   Test_T13_LongAddTarget();
   Test_T14_ShortAddTarget();
   Test_T15_IdenticalSpacingAtDepth();
   Test_T16_SimulatorParity();
   Test_T17_AddWidthRelationship();
   Test_OrderBudgetArithmetic();
   Print("SUMMARY: ", g_tests_passed, "/", g_tests_run, " passed");
}
