//+------------------------------------------------------------------+
//| fxgrind_tests.mq5 — unit tests (T1–T58, A1–A8, AccFigA1–AccFigA6, N1–N6, |
//| M1–M5, O1–O3, L1–L7, I5a–I5h, S1–S6, C1–C6, R1–R5, F1–F7)              |
//| Run in Strategy Tester or as script. No live trading.            |
//+------------------------------------------------------------------+
#property copyright "fxmatrix"
#property version   "1.00"
#property script_show_inputs
#property strict

#include "grind_comment.mqh"
#include "grind_engine.mqh"
#include "grind_pnl.mqh"
#include "grind_magic_lock.mqh"
#include "grind_config.mqh"

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

void AssertFalse(const string name, const bool condition)
{
   AssertTrue(name, !condition);
}

void AssertNear(const string name, const double got, const double expected, const double tol)
{
   AssertTrue(name, MathAbs(got - expected) <= tol);
}

void AssertEqStr(const string name, const string got, const string expected)
{
   AssertTrue(name, got == expected);
}

void AssertContains(const string name, const string haystack, const string needle)
{
   AssertTrue(name, StringFind(haystack, needle) >= 0);
}

void AssertNotContains(const string name, const string haystack, const string needle)
{
   AssertTrue(name, StringFind(haystack, needle) < 0);
}

void Test_SuiteCleanupMagicLocks()
{
   Grind_MagicLockReleaseAllKnown();
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

void Test_T10_EmptyBookReconOk()
{
   GrindReconTicket tickets[];
   GrindSideState long_out;
   GrindSideState short_out;
   string reason = "";
   const bool ok = Grind_RebuildBookFromTickets(tickets, 0,
                                                22260101UL, "OPT",
                                                3.0, 12, 0.00001,
                                                long_out, short_out, reason);
   AssertTrue("T10 empty ok", ok);
   AssertTrue("T10 no halt reason", reason == "");
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

void Test_T18_EmptyBookGenesis()
{
   GrindReconTicket tickets[];
   GrindSideState long_out;
   GrindSideState short_out;
   string reason = "";
   const bool ok = Grind_RebuildBookFromTickets(tickets, 0,
                                                22260101UL, "OPT",
                                                3.0, 12, 0.00001,
                                                long_out, short_out, reason);
   AssertTrue("T18 ok", ok);
   AssertTrue("T18 long depth", ArraySize(long_out.layers) == 0);
   AssertTrue("T18 short depth", ArraySize(short_out.layers) == 0);
}

void Test_T19b_SingleLayerAppend()
{
   GrindReconLayerScratch scratch[];
   int indices[];
   int count = 0;
   int idx = -1;
   const bool ok = Grind_ReconEnsureLayer(scratch, indices, count, 0, idx);
   AssertTrue("T19b append ok", ok);
   AssertTrue("T19b count", count == 1);
   AssertTrue("T19b scratch size", ArraySize(scratch) == 1);
   AssertTrue("T19b indices size", ArraySize(indices) == 1);
}

void Test_T19c_AppendUpToMaxLayersParallel()
{
   GrindReconLayerScratch scratch[];
   int indices[];
   int count = 0;
   for(int layer = 0; layer < 12; layer++) {
      int idx = -1;
      const bool ok = Grind_ReconEnsureLayer(scratch, indices, count, layer, idx);
      AssertTrue("T19c append " + IntegerToString(layer), ok);
      AssertTrue("T19c count " + IntegerToString(layer), count == layer + 1);
      AssertTrue("T19c scratch " + IntegerToString(layer), ArraySize(scratch) == count);
      AssertTrue("T19c indices " + IntegerToString(layer), ArraySize(indices) == count);
   }
}

void Test_T19_ThreeLongLayersRebuild()
{
   const ulong magic = 22260101UL;
   const double point = 0.00001;
   GrindReconTicket tickets[6];
   tickets[0].ticket = 1001; tickets[0].magic = magic;
   tickets[0].comment = GrindCommentBuild("OPT", "L", 0, "ENT");
   tickets[0].price = 1.25000; tickets[0].kind = GRIND_RECON_TICKET_POSITION;
   tickets[1].ticket = 2001; tickets[1].magic = magic;
   tickets[1].comment = GrindCommentBuild("OPT", "L", 0, "EXT");
   tickets[1].price = 1.25030; tickets[1].kind = GRIND_RECON_TICKET_ORDER;
   tickets[2].ticket = 1002; tickets[2].magic = magic;
   tickets[2].comment = GrindCommentBuild("OPT", "L", 1, "ENT");
   tickets[2].price = 1.24900; tickets[2].kind = GRIND_RECON_TICKET_POSITION;
   tickets[3].ticket = 2002; tickets[3].magic = magic;
   tickets[3].comment = GrindCommentBuild("OPT", "L", 1, "EXT");
   tickets[3].price = 1.24930; tickets[3].kind = GRIND_RECON_TICKET_ORDER;
   tickets[4].ticket = 1003; tickets[4].magic = magic;
   tickets[4].comment = GrindCommentBuild("OPT", "L", 2, "ENT");
   tickets[4].price = 1.24800; tickets[4].kind = GRIND_RECON_TICKET_POSITION;
   tickets[5].ticket = 2003; tickets[5].magic = magic;
   tickets[5].comment = GrindCommentBuild("OPT", "L", 2, "EXT");
   tickets[5].price = 1.24830; tickets[5].kind = GRIND_RECON_TICKET_ORDER;

   GrindSideState long_out;
   GrindSideState short_out;
   string reason = "";
   const bool ok = Grind_RebuildBookFromTickets(tickets, 6, magic, "OPT",
                                                3.0, 12, point,
                                                long_out, short_out, reason);
   AssertTrue("T19 ok", ok);
   AssertTrue("T19 depth", ArraySize(long_out.layers) == 3);
   AssertNear("T19 L0 entry", long_out.layers[0].entry_price, 1.25000, 1e-10);
   AssertNear("T19 L1 entry", long_out.layers[1].entry_price, 1.24900, 1e-10);
   AssertNear("T19 L2 entry", long_out.layers[2].entry_price, 1.24800, 1e-10);
   AssertNear("T19 L0 exit", long_out.layers[0].exit_target, 1.25030, 1e-10);
   AssertNear("T19 L1 exit", long_out.layers[1].exit_target, 1.24930, 1e-10);
   AssertNear("T19 L2 exit", long_out.layers[2].exit_target, 1.24830, 1e-10);
   AssertTrue("T19 L0 idx", long_out.layers[0].layer_index == 0);
   AssertTrue("T19 L2 idx", long_out.layers[2].layer_index == 2);
}

void Test_T20_UnparseableCommentHalts()
{
   GrindReconTicket tickets[1];
   tickets[0].ticket = 9001;
   tickets[0].magic = 22260101UL;
   tickets[0].comment = "GRIND|OPT|L|L03|BADROLE";
   tickets[0].price = 1.25000;
   tickets[0].kind = GRIND_RECON_TICKET_POSITION;
   GrindSideState long_out;
   GrindSideState short_out;
   string reason = "";
   AssertTrue("T20 halt", !Grind_RebuildBookFromTickets(tickets, 1,
                                                        22260101UL, "OPT",
                                                        3.0, 12, 0.00001,
                                                        long_out, short_out, reason));
   AssertEqStr("T20 reason", reason, "UNPARSEABLE_COMMENT");
}

void Test_T21_NeighbourMagicIgnored()
{
   GrindReconTicket tickets[1];
   tickets[0].ticket = 9002;
   tickets[0].magic = 22260102UL;
   tickets[0].comment = GrindCommentBuild("OPT", "L", 0, "ENT");
   tickets[0].price = 1.25000;
   tickets[0].kind = GRIND_RECON_TICKET_POSITION;
   GrindSideState long_out;
   GrindSideState short_out;
   string reason = "";
   AssertTrue("T21 ok", Grind_RebuildBookFromTickets(tickets, 1,
                                                     22260101UL, "OPT",
                                                     3.0, 12, 0.00001,
                                                     long_out, short_out, reason));
   AssertTrue("T21 empty", ArraySize(long_out.layers) == 0);
}

void Test_T22_NakedPositionHalts()
{
   GrindReconTicket tickets[1];
   tickets[0].ticket = 1001;
   tickets[0].magic = 22260101UL;
   tickets[0].comment = GrindCommentBuild("OPT", "L", 0, "ENT");
   tickets[0].price = 1.25000;
   tickets[0].kind = GRIND_RECON_TICKET_POSITION;
   GrindSideState long_out;
   GrindSideState short_out;
   string reason = "";
   AssertTrue("T22 halt", !Grind_RebuildBookFromTickets(tickets, 1,
                                                        22260101UL, "OPT",
                                                        3.0, 12, 0.00001,
                                                        long_out, short_out, reason));
   AssertTrue("T22 I3", StringFind(reason, "I3") >= 0);
}

void Test_T23_OrphanExitHalts()
{
   GrindReconTicket tickets[1];
   tickets[0].ticket = 2001;
   tickets[0].magic = 22260101UL;
   tickets[0].comment = GrindCommentBuild("OPT", "L", 0, "EXT");
   tickets[0].price = 1.25030;
   tickets[0].kind = GRIND_RECON_TICKET_ORDER;
   GrindSideState long_out;
   GrindSideState short_out;
   string reason = "";
   AssertTrue("T23 halt", !Grind_RebuildBookFromTickets(tickets, 1,
                                                        22260101UL, "OPT",
                                                        3.0, 12, 0.00001,
                                                        long_out, short_out, reason));
   AssertTrue("T23 I4", StringFind(reason, "I4") >= 0);
}

void Test_T24_GapIndicesRebuild()
{
   const ulong magic = 22260101UL;
   GrindReconTicket tickets[6];
   tickets[0].ticket = 1001; tickets[0].magic = magic;
   tickets[0].comment = GrindCommentBuild("OPT", "L", 0, "ENT");
   tickets[0].price = 1.25000; tickets[0].kind = GRIND_RECON_TICKET_POSITION;
   tickets[1].ticket = 2001; tickets[1].magic = magic;
   tickets[1].comment = GrindCommentBuild("OPT", "L", 0, "EXT");
   tickets[1].price = 1.25030; tickets[1].kind = GRIND_RECON_TICKET_ORDER;
   tickets[2].ticket = 1002; tickets[2].magic = magic;
   tickets[2].comment = GrindCommentBuild("OPT", "L", 1, "ENT");
   tickets[2].price = 1.24900; tickets[2].kind = GRIND_RECON_TICKET_POSITION;
   tickets[3].ticket = 2002; tickets[3].magic = magic;
   tickets[3].comment = GrindCommentBuild("OPT", "L", 1, "EXT");
   tickets[3].price = 1.24930; tickets[3].kind = GRIND_RECON_TICKET_ORDER;
   tickets[4].ticket = 1003; tickets[4].magic = magic;
   tickets[4].comment = GrindCommentBuild("OPT", "L", 3, "ENT");
   tickets[4].price = 1.24700; tickets[4].kind = GRIND_RECON_TICKET_POSITION;
   tickets[5].ticket = 2003; tickets[5].magic = magic;
   tickets[5].comment = GrindCommentBuild("OPT", "L", 3, "EXT");
   tickets[5].price = 1.24730; tickets[5].kind = GRIND_RECON_TICKET_ORDER;
   GrindSideState long_out;
   GrindSideState short_out;
   string reason = "";
   AssertTrue("T24 ok", Grind_RebuildBookFromTickets(tickets, 6, magic, "OPT",
                                                     3.0, 12, 0.00001,
                                                     long_out, short_out, reason));
   AssertTrue("T24 depth", ArraySize(long_out.layers) == 3);
}

void Test_T25_ContaminatedCommentRebuilds()
{
   const ulong magic = 22260101UL;
   GrindReconTicket tickets[2];
   tickets[0].ticket = 1001; tickets[0].magic = magic;
   tickets[0].comment = GrindCommentBuild("OPT", "L", 0, "ENT");
   tickets[0].price = 1.25000; tickets[0].kind = GRIND_RECON_TICKET_POSITION;
   tickets[1].ticket = 2001; tickets[1].magic = magic;
   tickets[1].comment = "GRIND|OPT|L|L00|EXT[tp]";
   tickets[1].price = 1.25030; tickets[1].kind = GRIND_RECON_TICKET_ORDER;
   GrindSideState long_out;
   GrindSideState short_out;
   string reason = "";
   AssertTrue("T25 ok", Grind_RebuildBookFromTickets(tickets, 2, magic, "OPT",
                                                     3.0, 12, 0.00001,
                                                     long_out, short_out, reason));
   AssertTrue("T25 depth", ArraySize(long_out.layers) == 1);
}

void Grind_TestCapLockCleanup()
{
   if(GlobalVariableCheck(GRIND_CAP_LOCK_GV))
      GlobalVariableDel(GRIND_CAP_LOCK_GV);
   g_grind_cap_test_lock_held = false;
}

void Test_C1_CasLockAcquireWhenAbsent()
{
   Grind_TestCapLockCleanup();
   AssertTrue("C1 acquire absent", Grind_CapTryAcquireLock(GRIND_CAP_CAS_MAX_RETRIES));
   AssertTrue("C1 lock held", GlobalVariableGet(GRIND_CAP_LOCK_GV) == 1.0);
   Grind_CapReleaseLock();
   Grind_TestCapLockCleanup();
}

void Test_C2_CasLockAcquireWhenZero()
{
   Grind_TestCapLockCleanup();
   AssertTrue("C2 temp bootstrap", GlobalVariableTemp(GRIND_CAP_LOCK_GV));
   AssertTrue("C2 starts zero", GlobalVariableGet(GRIND_CAP_LOCK_GV) == 0.0);
   AssertTrue("C2 acquire", Grind_CapTryAcquireLock(GRIND_CAP_CAS_MAX_RETRIES));
   Grind_CapReleaseLock();
   Grind_TestCapLockCleanup();
}

void Test_C3_CasLockHeldTimesOutWithoutReset()
{
   Grind_TestCapLockCleanup();
   GlobalVariableTemp(GRIND_CAP_LOCK_GV);
   GlobalVariableSet(GRIND_CAP_LOCK_GV, 1.0);
   AssertTrue("C3 timeout", !Grind_CapTryAcquireLock(GRIND_CAP_CAS_MAX_RETRIES));
   AssertTrue("C3 still held", GlobalVariableGet(GRIND_CAP_LOCK_GV) == 1.0);
   Grind_TestCapLockCleanup();
}

void Test_C4_CasLockAcquireReleaseLeavesZero()
{
   Grind_TestCapLockCleanup();
   AssertTrue("C4 acquire", Grind_CapTryAcquireLock(GRIND_CAP_CAS_MAX_RETRIES));
   Grind_CapReleaseLock();
   AssertTrue("C4 released zero", GlobalVariableGet(GRIND_CAP_LOCK_GV) == 0.0);
   Grind_TestCapLockCleanup();
}

void Test_C5_CasLockDoubleAcquireFails()
{
   Grind_TestCapLockCleanup();
   AssertTrue("C5 first acquire", Grind_CapTryAcquireLock(GRIND_CAP_CAS_MAX_RETRIES));
   AssertTrue("C5 second fails", !Grind_CapTryAcquireLock(0));
   Grind_CapReleaseLock();
   Grind_TestCapLockCleanup();
}

void Test_C6_CasLockTempPreservesHeldValue()
{
   Grind_TestCapLockCleanup();
   GlobalVariableTemp(GRIND_CAP_LOCK_GV);
   GlobalVariableSet(GRIND_CAP_LOCK_GV, 1.0);
   GlobalVariableTemp(GRIND_CAP_LOCK_GV);
   AssertTrue("C6 held lock not reset", GlobalVariableGet(GRIND_CAP_LOCK_GV) == 1.0);
   Grind_TestCapLockCleanup();
}

void Test_T26_CasSpinlockTimeout()
{
   Grind_TestCapLockCleanup();
   GlobalVariableTemp(GRIND_CAP_LOCK_GV);
   GlobalVariableSet(GRIND_CAP_LOCK_GV, 1.0);
   g_grind_cap_test_lock_held = true;
   AssertTrue("T26 timeout", !Grind_CapTryAcquireLock(GRIND_CAP_CAS_MAX_RETRIES));
   Grind_TestCapLockCleanup();
}

void Test_T27_MissingPeerReadsAsMaxed()
{
   g_grind_cap_thresh_a = 1.0;
   g_grind_cap_thresh_b = 0.0;
   g_grind_recon_magic = 22260101UL;
   g_grind_cap_leg_a = "EUR";
   g_grind_cap_leg_b = "USD";
   Grind_CapPublishOwnExposure(g_grind_recon_magic, "EUR", "USD");
   AssertTrue("T27 block entry", !Grind_CapAllowsEntry(true, 0.01));
   g_grind_cap_thresh_a = 0.0;
}

void Test_T28_StalePeerBoundary()
{
   const string key = Grind_CapExposureKey(22260102UL, "EUR");
   const string time_key = Grind_CapTimestampKey(key);
   GlobalVariableSet(key, 0.5);
   GlobalVariableSet(time_key, (double)(TimeCurrent() - 301));
   double value = 0.0;
   bool failed = false;
   Grind_CapAcquireLock();
   Grind_CapReadStoredPeer(key, value, failed);
   Grind_CapReleaseLock();
   AssertTrue("T28 stale maxed", failed);
   AssertTrue("T28 stale value", value >= GRIND_CAP_MAXED_VALUE * 0.5);

   GlobalVariableSet(time_key, (double)(TimeCurrent() - 299));
   value = 0.0;
   failed = false;
   Grind_CapAcquireLock();
   Grind_CapReadStoredPeer(key, value, failed);
   Grind_CapReleaseLock();
   AssertTrue("T28 fresh live", !failed);
   AssertNear("T28 fresh value", value, 0.5, 1e-10);

   GlobalVariableDel(key);
   GlobalVariableDel(time_key);
}

void Test_T28b_MissingTimestampMaxed()
{
   const string key = Grind_CapExposureKey(22260201UL, "GBP");
   GlobalVariableSet(key, 0.25);
   double value = 0.0;
   bool failed = false;
   Grind_CapAcquireLock();
   Grind_CapReadStoredPeer(key, value, failed);
   Grind_CapReleaseLock();
   AssertTrue("T28b maxed", failed);
   AssertTrue("T28b value", value >= GRIND_CAP_MAXED_VALUE * 0.5);
   GlobalVariableDel(key);
}

void Test_T29_CapBlocksNewEntry()
{
   g_grind_cap_thresh_a = 1.0;
   g_grind_cap_thresh_b = 0.0;
   g_grind_recon_magic = 22260101UL;
   g_grind_cap_leg_a = "EUR";
   g_grind_cap_leg_b = "USD";

   for(int i = 0; i < 6; i++) {
      const ulong magic = GRIND_CAP_ALL_MAGICS[i];
      const string key = Grind_CapExposureKey(magic, "EUR");
      const string time_key = Grind_CapTimestampKey(key);
      GlobalVariableSet(key, 0.0);
      GlobalVariableSet(time_key, (double)TimeCurrent());
   }
   const string own_key = Grind_CapExposureKey(22260101UL, "EUR");
   GlobalVariableSet(own_key, 0.99);
   GlobalVariableSet(Grind_CapTimestampKey(own_key), (double)TimeCurrent());

   AssertTrue("T29 block", !Grind_CapAllowsEntry(true, 0.02));
   g_grind_cap_thresh_a = 0.0;
}

void Test_T30_CapDoesNotBlockNonEntry()
{
   g_grind_cap_thresh_a = 1.0;
   g_grind_recon_magic = 22260101UL;
   g_grind_cap_leg_a = "EUR";
   g_grind_cap_leg_b = "USD";
   AssertTrue("T30 entry blocked", !Grind_CapAllowsEntry(true, 0.01));
   AssertTrue("T30 exit ok", Grind_CapPermitsNonEntryActions());
   g_grind_cap_thresh_a = 0.0;
}

void Test_T31_ThresholdZeroOffStillPublishes()
{
   g_grind_cap_thresh_a = 0.0;
   g_grind_cap_thresh_b = 0.0;
   g_grind_recon_magic = 22260301UL;
   g_grind_cap_leg_a = "EUR";
   g_grind_cap_leg_b = "GBP";
   GlobalVariableDel(Grind_CapExposureKey(22260301UL, "EUR"));
   AssertTrue("T31 allow entry", Grind_CapAllowsEntry(true, 0.01));
   AssertTrue("T31 publish", Grind_CapPublishOwnExposure(22260301UL, "EUR", "GBP"));
   AssertTrue("T31 gv exists",
              GlobalVariableCheck(Grind_CapExposureKey(22260301UL, "EUR")));
}

void Test_T32_DuplicateMagicFails()
{
   const ulong test_magic = 22269901UL;
   bool first_claim = false;
   bool duplicate_blocked = false;
   Grind_MagicLockRelease(test_magic);
   first_claim = Grind_MagicLockClaim(test_magic);
   duplicate_blocked = !Grind_MagicLockClaim(test_magic);
   Grind_MagicLockRelease(test_magic);
   AssertTrue("T32 first claim", first_claim);
   AssertTrue("T32 duplicate blocked", duplicate_blocked);
}

void Test_T33_FreeMagicClaimSucceeds()
{
   const ulong test_magic = 22269901UL;
   bool claim_ok = false;
   bool key_present = false;
   Grind_MagicLockRelease(test_magic);
   claim_ok = Grind_MagicLockClaim(test_magic);
   key_present = Grind_MagicLockIsClaimed(test_magic);
   Grind_MagicLockRelease(test_magic);
   AssertTrue("T33 claim ok", claim_ok);
   AssertTrue("T33 key present", key_present);
}

void Test_T34_ReleaseAllowsReclaim()
{
   const ulong test_magic = 22269901UL;
   bool first_claim = false;
   bool released = false;
   bool second_claim = false;
   Grind_MagicLockRelease(test_magic);
   first_claim = Grind_MagicLockClaim(test_magic);
   Grind_MagicLockRelease(test_magic);
   released = !Grind_MagicLockIsClaimed(test_magic);
   second_claim = Grind_MagicLockClaim(test_magic);
   Grind_MagicLockRelease(test_magic);
   AssertTrue("T34 first claim", first_claim);
   AssertTrue("T34 released", released);
   AssertTrue("T34 reclaim ok", second_claim);
}

void Test_T35_ConfigDumpCoversAllInputs()
{
   const string dump = Grind_ConfigDumpString(
      22260101UL, "OPT", "GBPUSD",
      5.0, 10.0, 5.0, 12,
      10.0, 4.0, 0.01,
      "GBP", "USD", 0.0, 0.0,
      "GRIND_GBPUSD_OPT", true,
      "GBPUSD OPT 5/5 sweep ac19a9f",
      true,
      "https://pipshed.com/api/telemetry/push",
      "",
      60);
   AssertContains("T35 InpMagic", dump, "InpMagic=");
   AssertContains("T35 InpSlot", dump, "InpSlot=");
   AssertContains("T35 symbol", dump, "symbol=");
   AssertContains("T35 InpWidthPips", dump, "InpWidthPips=");
   AssertContains("T35 InpAddPips", dump, "InpAddPips=");
   AssertContains("T35 InpExitPips", dump, "InpExitPips=");
   AssertContains("T35 InpMaxLayers", dump, "InpMaxLayers=");
   AssertContains("T35 InpStrandedThreshPips", dump, "InpStrandedThreshPips=");
   AssertContains("T35 InpDeadbandPips", dump, "InpDeadbandPips=");
   AssertContains("T35 InpLots", dump, "InpLots=");
   AssertContains("T35 InpCapLegA", dump, "InpCapLegA=");
   AssertContains("T35 InpCapLegB", dump, "InpCapLegB=");
   AssertContains("T35 InpCapLegAThresh", dump, "InpCapLegAThresh=");
   AssertContains("T35 InpCapLegBThresh", dump, "InpCapLegBThresh=");
   AssertContains("T35 InpTelemetryInstance", dump, "InpTelemetryInstance=");
   AssertContains("T35 InpVerboseLog", dump, "InpVerboseLog=");
   AssertContains("T35 InpConfigWarning", dump, "InpConfigWarning=");
   AssertContains("T35 telemetry", dump, "telemetry=");
   AssertContains("T35 url", dump, "url=");
   AssertContains("T35 key", dump, "key=");
   AssertContains("T35 interval", dump, "interval=");
}

void Test_T36_TelemetryWebPostEmptyGate()
{
   AssertTrue("T36 empty url", !Grind_TelemetryWebPost("", "key", "{}", false));
   AssertTrue("T36 empty key", !Grind_TelemetryWebPost("https://example.com", "", "{}", false));
}

void Test_T37_ConfigDumpKeyNotLeaked()
{
   const string secret = "supersecret-test-key-xyz";
   const string dump_set = Grind_ConfigDumpString(
      22260101UL, "OPT", "GBPUSD",
      5.0, 10.0, 5.0, 12,
      10.0, 4.0, 0.01,
      "GBP", "USD", 0.0, 0.0,
      "GRIND_GBPUSD_OPT", true,
      "GBPUSD OPT 5/5 sweep ac19a9f",
      true,
      "https://pipshed.com/api/telemetry/push",
      secret,
      60);
   const string dump_missing = Grind_ConfigDumpString(
      22260101UL, "OPT", "GBPUSD",
      5.0, 10.0, 5.0, 12,
      10.0, 4.0, 0.01,
      "GBP", "USD", 0.0, 0.0,
      "GRIND_GBPUSD_OPT", true,
      "GBPUSD OPT 5/5 sweep ac19a9f",
      true,
      "https://pipshed.com/api/telemetry/push",
      "",
      60);
   AssertContains("T37 set status", dump_set, "key=SET");
   AssertContains("T37 missing status", dump_missing, "key=MISSING");
   AssertTrue("T37 secret absent set", StringFind(dump_set, secret) < 0);
   AssertTrue("T37 secret absent missing", StringFind(dump_missing, secret) < 0);
}

void Test_T38_HeartbeatSchemaUnchanged()
{
   const string hb = Grind_TelemetryHeartbeatJson(
      "GRIND_GBPUSD_OPT", 1, 2, 3, 4,
      false, false, "", true, true,
      0.1, 0.2, 0.3, 0.4, false,
      22260101UL, "OPT", 5.0, 10.0, 5.0, 12, "GBP", "USD");
   AssertContains("T38 instance_id", hb, "\"instance_id\":");
   AssertTrue("T38 no instance key", StringFind(hb, "\"instance\":") < 0);
   AssertContains("T38 open_layers_long", hb, "\"open_layers_long\":");
   AssertContains("T38 open_layers_short", hb, "\"open_layers_short\":");
   AssertContains("T38 fills", hb, "\"fills\":");
   AssertContains("T38 scalps", hb, "\"scalps\":");
   AssertContains("T38 api_count", hb, "\"api_count\":");
   AssertContains("T38 api_counter_broken", hb, "\"api_counter_broken\":");
   AssertContains("T38 cap_blocked", hb, "\"cap_blocked\":");
   AssertContains("T38 halted", hb, "\"halted\":");
   AssertContains("T38 halt_reason", hb, "\"halt_reason\":");
   AssertContains("T38 recon_ok", hb, "\"recon_ok\":");
   AssertContains("T38 invariant_ok", hb, "\"invariant_ok\":");
   AssertContains("T38 cap_leg_a", hb, "\"cap_leg_a\":");
   AssertContains("T38 cap_leg_b", hb, "\"cap_leg_b\":");
   AssertContains("T38 cap_total_leg_a", hb, "\"cap_total_leg_a\":");
   AssertContains("T38 cap_total_leg_b", hb, "\"cap_total_leg_b\":");
   AssertContains("T38 peer_read_failed", hb, "\"peer_read_failed\":");
   AssertContains("T38 magic", hb, "\"magic\":");
   AssertContains("T38 slot", hb, "\"slot\":");
   AssertContains("T38 width_pips", hb, "\"width_pips\":");
   AssertContains("T38 add_pips", hb, "\"add_pips\":");
   AssertContains("T38 exit_pips", hb, "\"exit_pips\":");
   AssertContains("T38 max_layers", hb, "\"max_layers\":");
   AssertContains("T38 cap_leg_a_name", hb, "\"cap_leg_a_name\":");
   AssertContains("T38 cap_leg_b_name", hb, "\"cap_leg_b_name\":");
   AssertContains("T38 layers", hb, "\"layers\":");
   AssertContains("T38 resting_entries_long", hb, "\"resting_entries_long\":");
}

void Test_T39_ConfigDumpTwentyInputs()
{
   AssertTrue("T39 key helper set", Grind_ConfigTelemetryKeyStatus("abc") == "SET");
   AssertTrue("T39 key helper missing", Grind_ConfigTelemetryKeyStatus("") == "MISSING");
}

void Test_T40_NetMtmExactMagic()
{
   Grind_PnlReset();
   g_grind_pnl_test_active = true;
   g_grind_pnl_test_position_count = 2;
   ArrayResize(g_grind_pnl_test_positions, 2);
   g_grind_pnl_test_positions[0].magic = 22260101UL;
   g_grind_pnl_test_positions[0].profit = 1.50;
   g_grind_pnl_test_positions[0].swap = -0.10;
   g_grind_pnl_test_positions[1].magic = 22260102UL;
   g_grind_pnl_test_positions[1].profit = 99.00;
   g_grind_pnl_test_positions[1].swap = 0.0;

   const double mtm = Grind_ComputeNetFloatingMtm(22260101UL);
   AssertNear("T40 net_mtm ours only", mtm, 1.40, 1e-8);
   Grind_PnlReset();
}

void Test_T41_RealisedPnlNetAccumulation()
{
   Grind_PnlReset();
   g_grind_pnl_test_active = true;
   g_grind_pnl_test_server_time = D'2026.09.06 12:00:00';

   Grind_AccumulateScalpPnl(2.50, -0.30, -0.20);
   AssertNear("T41 first scalp net", g_grind_scalp_pnl_last, 2.00, 1e-8);
   AssertNear("T41 daily total", g_grind_realised_pnl_today, 2.00, 1e-8);

   Grind_AccumulateScalpPnl(1.00, 0.10, -0.05);
   AssertNear("T41 second scalp net", g_grind_scalp_pnl_last, 1.05, 1e-8);
   AssertNear("T41 daily sum", g_grind_realised_pnl_today, 3.05, 1e-8);
   Grind_PnlReset();
}

void Test_T42_DailyResetFollowsServerTime()
{
   Grind_PnlReset();
   g_grind_pnl_test_active = true;
   g_grind_pnl_test_server_time = D'2026.09.06 23:30:00';

   Grind_AccumulateScalpPnl(4.00, 0.0, 0.0);
   AssertNear("T42 pre-reset total", g_grind_realised_pnl_today, 4.00, 1e-8);

   const datetime server_new_day = D'2026.09.07 01:00:00';
   const string server_day = Grind_ServerDayKey(server_new_day);
   const datetime simulated_us_eastern = server_new_day - 6 * 3600;
   const string local_day = Grind_LocalDayKey(simulated_us_eastern);
   AssertTrue("T42 server/local day differ", server_day != local_day);
   AssertEqStr("T42 server day", server_day, "20260907");
   AssertEqStr("T42 local day", local_day, "20260906");

   g_grind_pnl_test_server_time = server_new_day;
   Grind_ResetDailyPnlIfNewDay();
   AssertNear("T42 reset on server day", g_grind_realised_pnl_today, 0.0, 1e-8);
   AssertNear("T42 scalp last reset", g_grind_scalp_pnl_last, 0.0, 1e-8);
   AssertEqStr("T42 day key server", g_grind_pnl_day_key, "20260907");
   Grind_PnlReset();
}

void Test_T43_TouchRevertThreshold()
{
   Grind_PnlReset();
   const double spread = 1.5;

   Grind_RecordExitPenetration(0.8, spread);
   AssertTrue("T43 below spread counts", g_grind_exit_touch_revert_count == 1);

   Grind_RecordExitPenetration(1.5, spread);
   AssertTrue("T43 at spread excluded", g_grind_exit_touch_revert_count == 1);

   Grind_RecordExitPenetration(2.0, spread);
   AssertTrue("T43 above spread excluded", g_grind_exit_touch_revert_count == 1);
   Grind_PnlReset();
}

void Test_T44_HeartbeatSchemaAppendOnly()
{
   Grind_PnlReset();
   g_grind_pnl_test_active = true;
   g_grind_pnl_test_server_time = D'2026.09.06 12:00:00';
   // Heartbeat calls Grind_ResetDailyPnlIfNewDay(); seed day key so seeded
   // accumulator values survive (empty key would trigger a counter wipe).
   g_grind_pnl_day_key = Grind_ServerDayKey(g_grind_pnl_test_server_time);
   g_grind_realised_pnl_today = 1.23;
   g_grind_scalp_pnl_last = 0.45;
   g_grind_exit_penetration_pips_last = 0.7;
   g_grind_exit_penetration_pips_sum = 1.4;
   g_grind_exit_penetration_count = 2;
   g_grind_exit_touch_revert_count = 1;

   const string hb = Grind_TelemetryHeartbeatJson(
      "GRIND_GBPUSD_OPT", 1, 2, 3, 4,
      false, false, "", true, true,
      0.1, 0.2, 0.3, 0.4, false,
      22260101UL, "OPT", 5.0, 10.0, 5.0, 12, "GBP", "USD");

   AssertTrue("T44 instance_id first",
              StringFind(hb, "\"instance_id\":") == 1);
   AssertContains("T44 net_mtm", hb, "\"net_mtm\":");
   AssertContains("T44 realised_pnl_today", hb, "\"realised_pnl_today\":");
   AssertContains("T44 scalp_pnl_last", hb, "\"scalp_pnl_last\":");
   AssertContains("T44 exit_penetration_pips_last", hb, "\"exit_penetration_pips_last\":");
   AssertContains("T44 exit_penetration_pips_mean", hb, "\"exit_penetration_pips_mean\":");
   AssertContains("T44 exit_touch_revert_count", hb, "\"exit_touch_revert_count\":");
   AssertContains("T44 realised value", hb, "\"realised_pnl_today\":1.2300");
   AssertContains("T44 touch revert value", hb, "\"exit_touch_revert_count\":1");
   AssertContains("T44 cap_leg_b_name preserved", hb, "\"cap_leg_b_name\":\"USD\"");
   AssertContains("T44 fills preserved", hb, "\"fills\":3");
   AssertContains("T44 layers appended", hb, "\"layers\":");
   AssertTrue("T44 layers after touch revert",
              StringFind(hb, "\"exit_touch_revert_count\":")
              < StringFind(hb, "\"layers\":"));
   Grind_PnlReset();
}

string Grind_TestSampleHeartbeatJson()
{
   return Grind_TelemetryHeartbeatJson(
      "GRIND_GBPUSD_OPT", 1, 2, 3, 4,
      false, false, "", true, true,
      0.1, 0.2, 0.3, 0.4, false,
      22260101UL, "OPT", 5.0, 10.0, 5.0, 12, "GBP", "USD");
}

void Grind_TestResetLayerDetailState()
{
   Grind_TestResetSideState();
   Grind_OrderTestReset();
   Grind_HeartbeatTestReset();
}

void Test_D1_ThreeLayersEmitDetail()
{
   Grind_TestResetLayerDetailState();
   ArrayResize(g_grind_long.layers, 3);
   g_grind_long.layers[0].layer_index = 0;
   g_grind_long.layers[0].entry_price = 1.25010;
   g_grind_long.layers[0].exit_target = 1.25060;
   g_grind_long.layers[0].exit_order_ticket = 1;
   g_grind_long.layers[0].exit_position_ticket = 0;
   g_grind_long.layers[1].layer_index = 1;
   g_grind_long.layers[1].entry_price = 1.24910;
   g_grind_long.layers[1].exit_target = 1.24960;
   g_grind_long.layers[1].exit_order_ticket = 0;
   g_grind_long.layers[1].exit_position_ticket = 1;
   g_grind_long.layers[2].layer_index = 2;
   g_grind_long.layers[2].entry_price = 1.24810;
   g_grind_long.layers[2].exit_target = 1.24860;
   g_grind_long.layers[2].exit_order_ticket = 1;
   g_grind_long.layers[2].exit_position_ticket = 1;

   const string hb = Grind_TestSampleHeartbeatJson();
   AssertContains("D1 layer 0", hb, "\"layer_index\":0");
   AssertContains("D1 layer 1", hb, "\"layer_index\":1");
   AssertContains("D1 layer 2", hb, "\"layer_index\":2");
   AssertContains("D1 side L", hb, "\"side\":\"L\"");
   AssertContains("D1 entry price", hb, "\"entry_price\":1.25010");
   AssertContains("D1 exit target", hb, "\"exit_target\":1.25060");
   AssertContains("D1 has_exit_order true", hb, "\"has_exit_order\":true");
   AssertContains("D1 has_exit_position false", hb, "\"has_exit_position\":false");
   Grind_TestResetLayerDetailState();
}

void Test_D2_NonContiguousLayerIndices()
{
   Grind_TestResetLayerDetailState();
   ArrayResize(g_grind_long.layers, 2);
   g_grind_long.layers[0].layer_index = 0;
   g_grind_long.layers[0].entry_price = 1.25000;
   g_grind_long.layers[0].exit_target = 1.25050;
   g_grind_long.layers[1].layer_index = 2;
   g_grind_long.layers[1].entry_price = 1.24800;
   g_grind_long.layers[1].exit_target = 1.24850;

   const string hb = Grind_TestSampleHeartbeatJson();
   AssertContains("D2 index 0", hb, "\"layer_index\":0");
   AssertContains("D2 index 2", hb, "\"layer_index\":2");
   AssertTrue("D2 no index 1", StringFind(hb, "\"layer_index\":1") < 0);
   Grind_TestResetLayerDetailState();
}

void Test_D3_EmptySideEmitsEmptyArray()
{
   Grind_TestResetLayerDetailState();
   const string hb = Grind_TestSampleHeartbeatJson();
   AssertContains("D3 empty layers", hb, "\"layers\":[]");
   Grind_TestResetLayerDetailState();
}

void Test_D4_PendingLevelsNullWhenAbsent()
{
   Grind_TestResetLayerDetailState();
   const string hb = Grind_TestSampleHeartbeatJson();
   AssertContains("D4 l0 long null", hb, "\"l0_pending_long\":null");
   AssertContains("D4 l0 short null", hb, "\"l0_pending_short\":null");
   AssertContains("D4 add long null", hb, "\"add_pending_long\":null");
   AssertContains("D4 add short null", hb, "\"add_pending_short\":null");
   Grind_TestResetLayerDetailState();
}

void Test_D5_NoTicketNumbersInJson()
{
   Grind_TestResetLayerDetailState();
   ArrayResize(g_grind_long.layers, 1);
   g_grind_long.layers[0].layer_index = 0;
   g_grind_long.layers[0].entry_price = 1.25000;
   g_grind_long.layers[0].exit_target = 1.25050;
   g_grind_long.layers[0].position_ticket = 555001UL;
   g_grind_long.layers[0].exit_order_ticket = 555002UL;
   g_grind_long.layers[0].exit_position_ticket = 555003UL;
   g_grind_long.l0_pending_ticket = 555004UL;
   g_grind_long.add_pending_ticket = 555005UL;

   const string hb = Grind_TestSampleHeartbeatJson();
   AssertTrue("D5 no position ticket", StringFind(hb, "555001") < 0);
   AssertTrue("D5 no exit order ticket", StringFind(hb, "555002") < 0);
   AssertTrue("D5 no exit position ticket", StringFind(hb, "555003") < 0);
   AssertTrue("D5 no l0 pending ticket", StringFind(hb, "555004") < 0);
   AssertTrue("D5 no add pending ticket", StringFind(hb, "555005") < 0);
   Grind_TestResetLayerDetailState();
}

void Test_D6_InstanceIdFirstSchemaAppendOnly()
{
   Grind_TestResetLayerDetailState();
   const string hb = Grind_TestSampleHeartbeatJson();
   AssertTrue("D6 instance_id first", StringFind(hb, "\"instance_id\":") == 1);
   AssertContains("D6 open_layers_long preserved", hb, "\"open_layers_long\":");
   AssertContains("D6 magic preserved", hb, "\"magic\":22260101");
   AssertContains("D6 exit_touch_revert preserved", hb, "\"exit_touch_revert_count\":");
   AssertContains("D6 layers appended", hb, "\"layers\":");
   Grind_TestResetLayerDetailState();
}

void Test_D7_WorstCasePayloadMeasured()
{
   Grind_TestResetLayerDetailState();
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   int detail_chars = 0;
   int full_chars = 0;
   string detail_json = "";
   string full_json = "";
   Grind_HeartbeatMeasureWorstCasePayload(12, digits, 22260101UL,
                                         detail_chars, full_chars,
                                         detail_json, full_json);
   const int journal_chars = StringLen("TELEM|GRIND_GBPUSD_OPT|HEARTBEAT|") + full_chars;

   Print("D7 worst-case detail field chars=", detail_chars,
         " full heartbeat chars=", full_chars,
         " journal line chars=", journal_chars,
         " (4096 Print limit; split when line >= 4096)");

   AssertTrue("D7 detail non-empty", detail_chars > 0);
   AssertTrue("D7 full heartbeat longer than detail block", full_chars > detail_chars);
   AssertTrue("D7 journal line length recorded", journal_chars > 0);
   Grind_TestResetLayerDetailState();
}

void Test_R1_LayerCommentRawFromBroker()
{
   Grind_TestResetLayerDetailState();
   g_grind_heartbeat_test_active = true;
   const string broker_comment = GrindCommentBuild("OPT", "L", 3, "ENT");
   Grind_HeartbeatTestUpsertPosition(7001UL, (long)22260101UL, broker_comment);

   ArrayResize(g_grind_long.layers, 1);
   g_grind_long.layers[0].layer_index = 1;
   g_grind_long.layers[0].position_ticket = 7001UL;
   g_grind_long.layers[0].entry_price = 1.25000;
   g_grind_long.layers[0].exit_target = 1.25050;

   const string hb = Grind_TestSampleHeartbeatJson();
   AssertContains("R1 structured index", hb, "\"layer_index\":1");
   AssertContains("R1 raw broker comment", hb, "\"comment\":\"GRIND|OPT|L|L03|ENT\"");
   AssertNotContains("R1 not reconstructed L01", hb, "\"comment\":\"GRIND|OPT|L|L01|ENT\"");
   Grind_TestResetLayerDetailState();
}

void Test_R2_PendingCommentsNullWhenAbsent()
{
   Grind_TestResetLayerDetailState();
   const string hb = Grind_TestSampleHeartbeatJson();
   AssertContains("R2 l0 long comment null", hb, "\"l0_pending_long_comment\":null");
   AssertContains("R2 l0 short comment null", hb, "\"l0_pending_short_comment\":null");
   AssertContains("R2 add long comment null", hb, "\"add_pending_long_comment\":null");
   AssertContains("R2 add short comment null", hb, "\"add_pending_short_comment\":null");
   Grind_TestResetLayerDetailState();
}

void Test_R3_NoTicketsInCommentHeartbeatJson()
{
   Grind_TestResetLayerDetailState();
   g_grind_heartbeat_test_active = true;
   g_grind_order_test_active = true;
   Grind_HeartbeatTestUpsertPosition(555001UL, (long)22260101UL,
                                    GrindCommentBuild("OPT", "L", 0, "ENT"));
   Grind_OrderTestUpsert(555004UL, (long)22260101UL,
                         GrindCommentBuild("OPT", "L", 0, "ENT"),
                         1.25000, ORDER_TYPE_BUY_LIMIT);
   Grind_OrderTestUpsert(555005UL, (long)22260101UL,
                         GrindCommentBuild("OPT", "L", 1, "ENT"),
                         1.24900, ORDER_TYPE_BUY_LIMIT);

   ArrayResize(g_grind_long.layers, 1);
   g_grind_long.layers[0].layer_index = 0;
   g_grind_long.layers[0].entry_price = 1.25000;
   g_grind_long.layers[0].exit_target = 1.25050;
   g_grind_long.layers[0].position_ticket = 555001UL;
   g_grind_long.layers[0].exit_order_ticket = 555002UL;
   g_grind_long.layers[0].exit_position_ticket = 555003UL;
   g_grind_long.l0_pending_ticket = 555004UL;
   g_grind_long.add_pending_ticket = 555005UL;

   const string hb = Grind_TestSampleHeartbeatJson();
   AssertTrue("R3 no position ticket", StringFind(hb, "555001") < 0);
   AssertTrue("R3 no exit order ticket", StringFind(hb, "555002") < 0);
   AssertTrue("R3 no exit position ticket", StringFind(hb, "555003") < 0);
   AssertTrue("R3 no l0 pending ticket", StringFind(hb, "555004") < 0);
   AssertTrue("R3 no add pending ticket", StringFind(hb, "555005") < 0);
   AssertContains("R3 comment field present", hb, "\"comment\":\"GRIND|OPT|L|L00|ENT\"");
   Grind_TestResetLayerDetailState();
}

void Test_R4_WorstCaseCommentsTriggerJournalSplit()
{
   Grind_TestResetLayerDetailState();
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   int detail_chars = 0;
   int full_chars = 0;
   string detail_json = "";
   string full_json = "";
   Grind_HeartbeatMeasureWorstCasePayload(12, digits, 22260101UL,
                                         detail_chars, full_chars,
                                         detail_json, full_json);
   const string instance = "GRIND_GBPUSD_OPT";
   const int journal_chars = StringLen("TELEM|" + instance + "|HEARTBEAT|") + full_chars;

   Print("R4 worst-case detail chars=", detail_chars,
         " full heartbeat chars=", full_chars,
         " journal line chars=", journal_chars);

   AssertTrue("R4 layer comments present", StringFind(full_json, "\"comment\":\"GRIND|") >= 0);
   AssertTrue("R4 pending comments present", StringFind(full_json, "\"l0_pending_long_comment\":") >= 0);
   AssertTrue("R4 journal exceeds Print limit", journal_chars >= 4096);
   AssertTrue("R4 split would fire", Grind_HeartbeatWouldJournalSplit(instance, full_json));
   AssertTrue("R4 POST body complete", StringFind(full_json, ",\"layers\":") >= 0);
   AssertTrue("R4 POST body has pending comments",
              StringFind(full_json, "\"add_pending_short_comment\":") >= 0);
   Grind_TestResetLayerDetailState();
}

void Test_R4b_FailedPositionSelectEmitsNullComment()
{
   Grind_TestResetLayerDetailState();
   ArrayResize(g_grind_long.layers, 1);
   g_grind_long.layers[0].layer_index = 0;
   g_grind_long.layers[0].position_ticket = 999999UL;
   g_grind_long.layers[0].entry_price = 1.25000;
   g_grind_long.layers[0].exit_target = 1.25050;

   const string hb = Grind_TestSampleHeartbeatJson();
   AssertContains("R4b phantom comment null", hb, "\"comment\":null");
   Grind_TestResetLayerDetailState();
}

void Grind_TestAppendReconTicket(GrindReconTicket &tickets[],
                                 int &count,
                                 const ulong magic,
                                 const ulong ticket,
                                 const int kind,
                                 const string comment,
                                 const double price)
{
   ArrayResize(tickets, count + 1);
   tickets[count].ticket = ticket;
   tickets[count].magic = magic;
   tickets[count].comment = comment;
   tickets[count].price = price;
   tickets[count].kind = kind;
   count++;
}

int Grind_TestCountJsonSubstrings(const string haystack, const string needle)
{
   int found = 0;
   int pos = 0;
   while((pos = StringFind(haystack, needle, pos)) >= 0) {
      found++;
      pos += StringLen(needle);
   }
   return found;
}

void Test_F1_I3RejectionEmitsReconFailureWithAllTickets()
{
   Grind_ReconFailureClear();
   Grind_TestResetSideState();
   const ulong magic = 22260101UL;
   GrindReconTicket tickets[];
   int count = 0;
   Grind_TestAppendReconTicket(tickets, count, magic, 1001UL, GRIND_RECON_TICKET_POSITION,
                               GrindCommentBuild("OPT", "L", 0, "ENT"), 1.25000);
   Grind_TestAppendReconTicket(tickets, count, magic, 9001UL, GRIND_RECON_TICKET_ORDER,
                               GrindCommentBuild("OPT", "S", 0, "ENT"), 1.24000);
   Grind_TestAppendReconTicket(tickets, count, magic, 9002UL, GRIND_RECON_TICKET_ORDER,
                               GrindCommentBuild("OPT", "S", 1, "ENT"), 1.23900);
   Grind_TestAppendReconTicket(tickets, count, magic, 9101UL, GRIND_RECON_TICKET_ORDER,
                               GrindCommentBuild("OPT", "L", 1, "ENT"), 1.24900);

   GrindSideState long_out;
   GrindSideState short_out;
   string reason = "";
   AssertFalse("F1 fails",
               Grind_RebuildBookFromTickets(tickets, count, magic, "OPT",
                                            3.0, 12, 0.00001,
                                            long_out, short_out, reason));
   AssertEqStr("F1 reason", reason, "I3_LONG_NAKED");
   AssertTrue("F1 json set", g_grind_recon_failure_json != "");
   AssertContains("F1 reason in json", g_grind_recon_failure_json, "\"reason\":\"I3_LONG_NAKED\"");
   AssertContains("F1 ticket count", g_grind_recon_failure_json, "\"ticket_count\":4");
   AssertContains("F1 truncated false", g_grind_recon_failure_json, "\"truncated\":false");
   AssertContains("F1 long ent comment", g_grind_recon_failure_json,
                  GrindCommentBuild("OPT", "L", 0, "ENT"));
   AssertContains("F1 short ent 0", g_grind_recon_failure_json,
                  GrindCommentBuild("OPT", "S", 0, "ENT"));
   AssertContains("F1 short ent 1", g_grind_recon_failure_json,
                  GrindCommentBuild("OPT", "S", 1, "ENT"));
   const string hb = Grind_TestSampleHeartbeatJson();
   AssertContains("F1 heartbeat recon_failure", hb, "\"recon_failure\":{");
   AssertContains("F1 heartbeat reason", hb, "\"reason\":\"I3_LONG_NAKED\"");
   Grind_ReconFailureClear();
}

void Test_F2_MorningFailureScenario()
{
   Grind_ReconFailureClear();
   const ulong magic = 22260401UL;
   GrindReconTicket tickets[];
   int count = 0;
   Grind_TestAppendReconTicket(tickets, count, magic, 2001UL, GRIND_RECON_TICKET_POSITION,
                               GrindCommentBuild("OPT", "L", 0, "ENT"), 1.00080);
   Grind_TestAppendReconTicket(tickets, count, magic, 9001UL, GRIND_RECON_TICKET_ORDER,
                               GrindCommentBuild("OPT", "S", 0, "ENT"), 0.99971);
   Grind_TestAppendReconTicket(tickets, count, magic, 9002UL, GRIND_RECON_TICKET_ORDER,
                               GrindCommentBuild("OPT", "S", 1, "ENT"), 0.99862);

   GrindSideState long_out;
   GrindSideState short_out;
   string reason = "";
   AssertFalse("F2 fails",
               Grind_RebuildBookFromTickets(tickets, count, magic, "OPT",
                                            5.0, 8, 0.00001,
                                            long_out, short_out, reason));
   AssertEqStr("F2 reason", reason, "I3_LONG_NAKED");
   AssertContains("F2 ticket count", g_grind_recon_failure_json, "\"ticket_count\":3");
   AssertContains("F2 offending long ent", g_grind_recon_failure_json,
                  "\"offending_comment\":\"" + GrindCommentBuild("OPT", "L", 0, "ENT") + "\"");
   AssertContains("F2 long ent row", g_grind_recon_failure_json,
                  GrindCommentBuild("OPT", "L", 0, "ENT"));
   AssertContains("F2 short ent 0", g_grind_recon_failure_json,
                  GrindCommentBuild("OPT", "S", 0, "ENT"));
   AssertContains("F2 short ent 1", g_grind_recon_failure_json,
                  GrindCommentBuild("OPT", "S", 1, "ENT"));
   AssertContains("F2 price long", g_grind_recon_failure_json, "\"price\":1.00080");
   AssertContains("F2 price short0", g_grind_recon_failure_json, "\"price\":0.99971");
   AssertContains("F2 price short1", g_grind_recon_failure_json, "\"price\":0.99862");
   Grind_ReconFailureClear();
}

void Test_F3_SuccessClearsReconFailure()
{
   g_grind_recon_failure_json = "{\"reason\":\"STALE\"}";
   const ulong magic = 22260101UL;
   GrindReconTicket tickets[2];
   int count = 0;
   Grind_TestAppendReconLayerPair(tickets, count, magic, 0, 1.25000, 1.25030);
   GrindSideState long_out;
   GrindSideState short_out;
   string reason = "";
   AssertTrue("F3 ok",
              Grind_RebuildBookFromTickets(tickets, count, magic, "OPT",
                                           3.0, 12, 0.00001,
                                           long_out, short_out, reason));
   AssertEqStr("F3 json cleared", g_grind_recon_failure_json, "");
   const string hb = Grind_TestSampleHeartbeatJson();
   AssertContains("F3 heartbeat null", hb, "\"recon_failure\":null");
}

void Test_F3b_FailThenSuccessClearsGlobal()
{
   Grind_ReconFailureClear();
   const ulong magic = 22260101UL;
   GrindReconTicket bad[1];
   bad[0].ticket = 1001UL;
   bad[0].magic = magic;
   bad[0].comment = GrindCommentBuild("OPT", "L", 0, "ENT");
   bad[0].price = 1.25000;
   bad[0].kind = GRIND_RECON_TICKET_POSITION;
   GrindSideState long_out;
   GrindSideState short_out;
   string reason = "";
   AssertFalse("F3b fail",
               Grind_RebuildBookFromTickets(bad, 1, magic, "OPT",
                                            3.0, 12, 0.00001,
                                            long_out, short_out, reason));
   AssertTrue("F3b json after fail", StringLen(g_grind_recon_failure_json) > 0);

   GrindReconTicket good[2];
   int count = 0;
   Grind_TestAppendReconLayerPair(good, count, magic, 0, 1.25000, 1.25030);
   AssertTrue("F3b ok",
              Grind_RebuildBookFromTickets(good, count, magic, "OPT",
                                           3.0, 12, 0.00001,
                                           long_out, short_out, reason));
   AssertEqStr("F3b json empty", g_grind_recon_failure_json, "");
   AssertTrue("F3b strlen zero", StringLen(g_grind_recon_failure_json) == 0);
}

void Test_F3c_CaptureSurvivesSeparateHeartbeat()
{
   Grind_ReconFailureClear();
   const ulong magic = 22260101UL;
   GrindReconTicket bad[1];
   bad[0].ticket = 1001UL;
   bad[0].magic = magic;
   bad[0].comment = GrindCommentBuild("OPT", "L", 0, "ENT");
   bad[0].price = 1.25000;
   bad[0].kind = GRIND_RECON_TICKET_POSITION;
   GrindSideState long_out;
   GrindSideState short_out;
   string reason = "";
   AssertFalse("F3c fail",
               Grind_RebuildBookFromTickets(bad, 1, magic, "OPT",
                                            3.0, 12, 0.00001,
                                            long_out, short_out, reason));
   const string captured = g_grind_recon_failure_json;
   AssertTrue("F3c captured", captured != "");
   const string hb = Grind_TestSampleHeartbeatJson();
   AssertContains("F3c heartbeat has failure", hb, "\"recon_failure\":{");
   AssertContains("F3c heartbeat reason", hb, "\"reason\":\"I3_LONG_NAKED\"");
   Grind_ReconFailureClear();
}

void Test_F4_NoTicketNumbersInJson()
{
   Grind_ReconFailureClear();
   const ulong magic = 22260101UL;
   const ulong secret_ticket = 87654321UL;
   GrindReconTicket tickets[1];
   tickets[0].ticket = secret_ticket;
   tickets[0].magic = magic;
   tickets[0].comment = GrindCommentBuild("OPT", "L", 0, "ENT");
   tickets[0].price = 1.25000;
   tickets[0].kind = GRIND_RECON_TICKET_POSITION;
   GrindSideState long_out;
   GrindSideState short_out;
   string reason = "";
   AssertFalse("F4 fails",
               Grind_RebuildBookFromTickets(tickets, 1, magic, "OPT",
                                            3.0, 12, 0.00001,
                                            long_out, short_out, reason));
   AssertNotContains("F4 global no ticket", g_grind_recon_failure_json, "87654321");
   AssertNotContains("F4 no ticket key", g_grind_recon_failure_json, "\"ticket\":");
   const string hb = Grind_TestSampleHeartbeatJson();
   AssertNotContains("F4 heartbeat no ticket", hb, "87654321");
   Grind_ReconFailureClear();
}

void Test_F5_UnparseableCommentVerbatimSideHintNull()
{
   Grind_ReconFailureClear();
   const ulong magic = 22260101UL;
   const string bad_comment = "BROKEN|NOT|GRIND";
   GrindReconTicket tickets[1];
   tickets[0].ticket = 5001UL;
   tickets[0].magic = magic;
   tickets[0].comment = bad_comment;
   tickets[0].price = 1.25000;
   tickets[0].kind = GRIND_RECON_TICKET_POSITION;
   GrindSideState long_out;
   GrindSideState short_out;
   string reason = "";
   AssertFalse("F5 fails",
               Grind_RebuildBookFromTickets(tickets, 1, magic, "OPT",
                                            3.0, 12, 0.00001,
                                            long_out, short_out, reason));
   AssertEqStr("F5 reason", reason, "UNPARSEABLE_COMMENT");
   AssertContains("F5 verbatim", g_grind_recon_failure_json, bad_comment);
   AssertContains("F5 side_hint null", g_grind_recon_failure_json, "\"side_hint\":null");
   AssertContains("F5 offending", g_grind_recon_failure_json,
                  "\"offending_comment\":\"" + bad_comment + "\"");
   Grind_ReconFailureClear();
}

void Test_F6_TruncationAtFortyPlusTickets()
{
   Grind_ReconFailureClear();
   const ulong magic = 22260101UL;
   GrindReconTicket tickets[];
   int count = 0;
   Grind_TestAppendReconTicket(tickets, count, magic, 1001UL, GRIND_RECON_TICKET_POSITION,
                               GrindCommentBuild("OPT", "L", 0, "ENT"), 1.25000);
   for(int i = 0; i < 40; i++) {
      Grind_TestAppendReconTicket(tickets, count, magic,
                                  9000UL + (ulong)i,
                                  GRIND_RECON_TICKET_ORDER,
                                  GrindCommentBuild("OPT", "S", i, "ENT"),
                                  1.24000 - i * 0.00010);
   }

   GrindSideState long_out;
   GrindSideState short_out;
   string reason = "";
   AssertFalse("F6 fails",
               Grind_RebuildBookFromTickets(tickets, count, magic, "OPT",
                                            3.0, 12, 0.00001,
                                            long_out, short_out, reason));
   AssertContains("F6 truncated true", g_grind_recon_failure_json, "\"truncated\":true");
   AssertContains("F6 ticket count 41", g_grind_recon_failure_json, "\"ticket_count\":41");
   AssertTrue("F6 emit 40 rows",
              Grind_TestCountJsonSubstrings(g_grind_recon_failure_json, "\"kind\":") == 40);
   Grind_ReconFailureClear();
}

void Test_F7_WorstCaseSizeMeasured()
{
   Grind_ReconFailureClear();
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const string instance = "GRIND_GBPUSD_OPT";
   const ulong magic = 22260101UL;

   int recon_only = 0;
   Grind_ReconFailureMeasureWorstCase(41, recon_only);

   int recon_chars = 0;
   int full_chars = 0;
   int journal_unsplit = 0;
   int journal_scalar = 0;
   int journal_detail = 0;
   bool split = false;
   string detail_json = "";
   string full_json = "";
   int detail_chars = 0;
   int full_no_recon = 0;
   string full_with_recon = "";

   Grind_ReconFailureMeasureWorstCaseCombined(41, 12, digits, magic, instance,
                                              recon_chars, full_chars,
                                              journal_unsplit, journal_scalar,
                                              journal_detail, split,
                                              full_with_recon);

   Grind_HeartbeatMeasureWorstCasePayload(12, digits, magic,
                                          detail_chars, full_no_recon,
                                          detail_json, full_json);

   Print("F7 recon_failure field chars=", recon_chars,
         " (41 tickets, 40 emitted, truncated=true)",
         " full heartbeat chars=", full_chars,
         " delta vs no-recon=", full_chars - full_no_recon,
         " journal unsplit chars=", journal_unsplit,
         " journal scalar line chars=", journal_scalar,
         " journal detail line chars=", journal_detail,
         " scalar exceeds Print limit=", journal_scalar >= 4096 ? "yes" : "no",
         " split=", split ? "yes" : "no",
         " (4096 MQL5 Print limit)");

   AssertTrue("F7 recon_failure chars positive", recon_chars > 0);
   AssertTrue("F7 recon isolate matches combined", recon_chars == recon_only);
   AssertTrue("F7 heartbeat grows with recon", full_chars > full_no_recon);
   AssertTrue("F7 unsplit exceeds Print limit", journal_unsplit >= 4096);
   AssertTrue("F7 split fires", split);
   AssertTrue("F7 detail line under Print limit", journal_detail < 4096);
   AssertTrue("F7 scalar line measured", journal_scalar > journal_detail);
   AssertContains("F7 recon_failure in heartbeat", full_with_recon, "\"recon_failure\":{");
   AssertContains("F7 layers in heartbeat", full_with_recon, ",\"layers\":");
   AssertEqStr("F7 cleared after measure", g_grind_recon_failure_json, "");
}

void Grind_TestResetMaeState()
{
   Grind_MaeReset();
   GlobalVariableDel(GRIND_MAE_REPORTER_HEARTBEAT_GV);
   GlobalVariableDel(GRIND_MAE_REPORTER_MAGIC_GV);
   GlobalVariableDel(GRIND_MAE_REPORTER_CLAIM_LOCK_GV);
   GlobalVariableDel(Grind_MaeAnchorGvKey("20260909"));
   GlobalVariableDel(Grind_MaeAnchorGvKey("20260910"));
   GlobalVariableDel(Grind_MaeEquityLowGvKey("20260909"));
   GlobalVariableDel(Grind_MaeEquityLowGvKey("20260910"));
}

void Test_AccFigA1_DesignatedEmitsBalanceEquity()
{
   Grind_TestResetMaeState();
   g_grind_mae_test_active = true;
   g_grind_mae_test_balance = 10000.0;
   g_grind_mae_test_equity = 10050.0;
   g_grind_mae_test_server_time = StringToTime("2026.09.10 12:00:00");
   Grind_MaeInit();
   Grind_MaeOnTimer();

   AssertTrue("AccFigA1 designated claims",
              Grind_MaeClaimReporterForHeartbeat(22260101UL, 60));
   const string hb_designated = Grind_TestSampleHeartbeatJson();
   AssertContains("AccFigA1 balance", hb_designated, "\"account_balance\":10000.00");
   AssertContains("AccFigA1 equity", hb_designated, "\"account_equity\":10050.00");
   AssertContains("AccFigA1 mae day key", hb_designated, "\"mae_day_key\":\"20260910\"");

   AssertFalse("AccFigA1 non-designated blocked",
               Grind_MaeClaimReporterForHeartbeat(22260102UL, 60));
   const string hb_other = Grind_TestSampleHeartbeatJson();
   AssertContains("AccFigA1 other balance null", hb_other, "\"account_balance\":null");
   AssertContains("AccFigA1 other equity null", hb_other, "\"account_equity\":null");
   AssertContains("AccFigA1 other mae null", hb_other, "\"mae_equity_low\":null");
   Grind_TestResetMaeState();
}

void Test_AccFigA2_ExactlyOneLeaseHolder()
{
   Grind_TestResetMaeState();
   g_grind_mae_test_active = true;
   g_grind_mae_test_server_time = StringToTime("2026.09.10 12:00:00");
   GlobalVariableTemp(GRIND_MAE_REPORTER_HEARTBEAT_GV);
   GlobalVariableTemp(GRIND_MAE_REPORTER_MAGIC_GV);
   GlobalVariableSet(GRIND_MAE_REPORTER_HEARTBEAT_GV,
                     (double)(g_grind_mae_test_server_time - 200));

   AssertTrue("AccFigA2 first claims", Grind_MaeClaimReporterForHeartbeat(22260101UL, 60));
   AssertFalse("AccFigA2 second blocked", Grind_MaeClaimReporterForHeartbeat(22260102UL, 60));
   AssertTrue("AccFigA2 holder magic",
              (ulong)GlobalVariableGet(GRIND_MAE_REPORTER_MAGIC_GV) == 22260101UL);
   Grind_TestResetMaeState();
}

void Test_AccFigA2b_LeaseTakeoverAfterStale()
{
   Grind_TestResetMaeState();
   g_grind_mae_test_active = true;
   g_grind_mae_test_balance = 10000.0;
   g_grind_mae_test_equity = 10000.0;
   const datetime start = StringToTime("2026.09.10 12:00:00");
   g_grind_mae_test_server_time = start;
   Grind_MaeInit();

   AssertTrue("AccFigA2b first holder", Grind_MaeClaimReporterForHeartbeat(22260101UL, 60));
   g_grind_mae_test_server_time = start + 100;
   AssertTrue("AccFigA2b takeover claims", Grind_MaeClaimReporterForHeartbeat(22260201UL, 60));
   AssertTrue("AccFigA2b new holder magic",
              (ulong)GlobalVariableGet(GRIND_MAE_REPORTER_MAGIC_GV) == 22260201UL);
   const string hb = Grind_TestSampleHeartbeatJson();
   AssertContains("AccFigA2b reports balance", hb, "\"account_balance\":10000.00");
   Grind_TestResetMaeState();
}

void Test_AccFigA2c_FreshLeaseForcesNull()
{
   Grind_TestResetMaeState();
   g_grind_mae_test_active = true;
   g_grind_mae_test_server_time = StringToTime("2026.09.10 12:00:00");
   AssertTrue("AccFigA2c holder claims", Grind_MaeClaimReporterForHeartbeat(22260101UL, 60));
   AssertFalse("AccFigA2c challenger blocked", Grind_MaeClaimReporterForHeartbeat(22260102UL, 60));
   AssertFalse("AccFigA2c challenger not reporter", g_grind_mae_is_reporter);
   Grind_TestResetMaeState();
}

void Test_AccFigA3_EquityLowTracksDownOnly()
{
   Grind_TestResetMaeState();
   g_grind_mae_test_active = true;
   Grind_MaeCoreUpdate("20260910", 10050.0, 10000.0);
   Grind_MaeCoreUpdate("20260910", 10020.0, 10000.0);
   AssertTrue("AccFigA3 low holds min", g_grind_mae_equity_low == 10020.0);
   Grind_MaeCoreUpdate("20260910", 10080.0, 10000.0);
   AssertTrue("AccFigA3 higher equity ignored", g_grind_mae_equity_low == 10020.0);
   Grind_TestResetMaeState();
}

void Test_AccFigA4_DayKeyRollsOnServerTime()
{
   Grind_TestResetMaeState();
   g_grind_mae_test_active = true;
   g_grind_pnl_test_active = true;
   g_grind_pnl_test_server_time = StringToTime("2026.09.09 23:59:00");
   g_grind_mae_test_server_time = g_grind_pnl_test_server_time;

   Grind_MaeCoreUpdate("20260909", 9900.0, 10000.0);
   AssertTrue("AccFigA4 prior day low tracked", g_grind_mae_equity_low == 9900.0);

   g_grind_pnl_test_server_time = StringToTime("2026.09.10 00:05:00");
   g_grind_mae_test_server_time = g_grind_pnl_test_server_time;
   Grind_MaeCoreUpdate(Grind_ServerDayKey(g_grind_mae_test_server_time),
                       10100.0, 10100.0);
   AssertTrue("AccFigA4 new day resets low", g_grind_mae_equity_low == 10100.0);
   AssertEqStr("AccFigA4 new day key", g_grind_mae_day_key, "20260910");
   Grind_TestResetMaeState();
   g_grind_pnl_test_active = false;
}

void Test_AccFigA5_ReloadPreservesEquityLow()
{
   Grind_TestResetMaeState();
   g_grind_mae_test_active = true;
   g_grind_mae_test_server_time = StringToTime("2026.09.10 12:00:00");
   Grind_MaeCoreUpdate("20260910", 9920.0, 10000.0);
   AssertTrue("AccFigA5 persisted gv", Grind_MaeEquityLowGvPresent("20260910"));

   g_grind_mae_day_key = "";
   g_grind_mae_equity_low = 0.0;
   Grind_MaeInit();
   AssertTrue("AccFigA5 reload recovers low", g_grind_mae_equity_low == 9920.0);
   Grind_TestResetMaeState();
}

void Test_AccFigA6_DistToFloorMatchesV2Logic()
{
   const double anchor = 10000.0;
   const double frac = 0.045;
   const double floor = Grind_MaeDailyFloorValue(anchor, frac);
   AssertTrue("AccFigA6 floor value", MathAbs(floor - 9550.0) < 0.01);
   const double dist = Grind_MaeDistToFloor(9600.0, anchor, frac);
   AssertTrue("AccFigA6 dist to floor", MathAbs(dist - 50.0) < 0.01);
   AssertTrue("AccFigA6 matches v2 formula",
              MathAbs(dist - (9600.0 - anchor * (1.0 - frac))) < 0.01);

   Grind_TestResetMaeState();
   g_grind_mae_test_active = true;
   g_grind_mae_test_balance = 10000.0;
   g_grind_mae_test_equity = 9990.0;
   g_grind_mae_test_server_time = StringToTime("2026.09.10 12:00:00");
   Grind_MaeInit();
   Grind_MaeOnTimer();
   Grind_MaeClaimReporterForHeartbeat(22260101UL, 60);
   const string hb = Grind_TestSampleHeartbeatJson();
   AssertContains("AccFigA6 mae equity low", hb, "\"mae_equity_low\":9990.00");
   AssertContains("AccFigA6 mae dist", hb, "\"mae_equity_low_dist_to_floor\":");
   Grind_TestResetMaeState();
}

void Test_D8_RestingEntriesFromBrokerEnumeration()
{
   Grind_TestResetLayerDetailState();
   g_grind_order_test_active = true;
   Grind_OrderTestUpsert(9101UL, (long)22260101UL,
                         GrindCommentBuild("OPT", "L", 0, "ENT"),
                         1.25000, ORDER_TYPE_BUY_LIMIT);
   Grind_OrderTestUpsert(9102UL, (long)22260101UL,
                         GrindCommentBuild("OPT", "L", 1, "ENT"),
                         1.24900, ORDER_TYPE_BUY_LIMIT);
   g_grind_long.add_pending_ticket = 9101UL;

   const int broker_count = Grind_HeartbeatCountRestingEntries(22260101UL, "L");
   AssertTrue("D8 duplicate resting entries visible", broker_count == 2);

   const string hb = Grind_TestSampleHeartbeatJson();
   AssertContains("D8 resting_entries_long field", hb, "\"resting_entries_long\":2");
   Grind_TestResetLayerDetailState();
}

void Test_D9_PricesUseDoubleToString()
{
   Grind_TestResetLayerDetailState();
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const int max_price_chars = digits + 2;

   ArrayResize(g_grind_long.layers, 1);
   g_grind_long.layers[0].layer_index = 0;
   g_grind_long.layers[0].entry_price = 0.85871;
   g_grind_long.layers[0].exit_target = 0.85851;

   const string hb = Grind_TestSampleHeartbeatJson();
   const string expected_entry = DoubleToString(0.85871, digits);
   const string expected_exit = DoubleToString(0.85851, digits);
   AssertContains("D9 entry formatted", hb, "\"entry_price\":" + expected_entry);
   AssertContains("D9 exit formatted", hb, "\"exit_target\":" + expected_exit);
   AssertTrue("D9 entry not overlong",
              StringLen(expected_entry) <= max_price_chars);
   AssertTrue("D9 no float artifact tail",
              StringFind(hb, "8587100000000001") < 0);
   Grind_TestResetLayerDetailState();
}

void Grind_TestAppendDeal(const ulong deal_ticket,
                          const string comment,
                          const long entry_type,
                          const ulong order_ticket,
                          const ulong position_id,
                          const double profit,
                          const double swap,
                          const double commission,
                          const double price = 1.25030,
                          const datetime deal_time = D'2026.09.06 14:30:00')
{
   ArrayResize(g_grind_deal_test_records, g_grind_deal_test_count + 1);
   g_grind_deal_test_records[g_grind_deal_test_count].deal_ticket = deal_ticket;
   g_grind_deal_test_records[g_grind_deal_test_count].symbol = _Symbol;
   g_grind_deal_test_records[g_grind_deal_test_count].magic = (long)22260101UL;
   g_grind_deal_test_records[g_grind_deal_test_count].comment = comment;
   g_grind_deal_test_records[g_grind_deal_test_count].entry_type = entry_type;
   g_grind_deal_test_records[g_grind_deal_test_count].order_ticket = order_ticket;
   g_grind_deal_test_records[g_grind_deal_test_count].position_id = position_id;
   g_grind_deal_test_records[g_grind_deal_test_count].price = price;
   g_grind_deal_test_records[g_grind_deal_test_count].profit = profit;
   g_grind_deal_test_records[g_grind_deal_test_count].swap = swap;
   g_grind_deal_test_records[g_grind_deal_test_count].commission = commission;
   g_grind_deal_test_records[g_grind_deal_test_count].deal_time = deal_time;
   g_grind_deal_test_count++;
}

void Grind_TestResetSideState()
{
   ArrayResize(g_grind_long.layers, 0);
   ArrayResize(g_grind_short.layers, 0);
   g_grind_long.l0_pending_ticket = 0;
   g_grind_long.add_pending_ticket = 0;
   g_grind_short.l0_pending_ticket = 0;
   g_grind_short.add_pending_ticket = 0;
   g_grind_fill_count = 0;
   g_grind_scalp_count = 0;
   g_grind_halted = false;
   ArrayResize(g_grind_processed_deals, 0);
   g_grind_processed_deal_count = 0;
   Grind_ScalpEventReset();
}

void Grind_TestSetupScalpCloseLongLayer(const ulong entry_pos,
                                        const ulong exit_pos,
                                        const int layer_index,
                                        const double entry_price,
                                        const double exit_price)
{
   Grind_TestResetSideState();
   ArrayResize(g_grind_long.layers, 1);
   g_grind_long.layers[0].entry_price = entry_price;
   g_grind_long.layers[0].exit_target = exit_price;
   g_grind_long.layers[0].position_ticket = entry_pos;
   g_grind_long.layers[0].exit_position_ticket = exit_pos;
   g_grind_long.layers[0].layer_index = layer_index;
   g_grind_telemetry_instance = "GRIND_TEST_OPT";
}

void Test_T45_ExitFillQueuesCloseByPair()
{
   Grind_CloseByTestReset();
   Grind_DealTestReset();
   Grind_TestResetSideState();

   ArrayResize(g_grind_long.layers, 1);
   g_grind_long.layers[0].entry_price = 1.25000;
   g_grind_long.layers[0].exit_target = 1.25030;
   g_grind_long.layers[0].position_ticket = 1001;
   g_grind_long.layers[0].exit_order_ticket = 2001;
   g_grind_long.layers[0].exit_position_ticket = 0;
   g_grind_long.layers[0].layer_index = 0;

   g_grind_deal_test_active = true;
   Grind_TestAppendDeal(9001,
                        GrindCommentBuild("OPT", "L", 0, "EXT"),
                        DEAL_ENTRY_IN,
                        2001,
                        3002,
                        0.0, 0.0, 0.0);

   Grind_HandleSideDealFill(g_grind_long, true, 9001, 22260101UL, "OPT",
                            3.0, 4.0, 12, 0.01);

   AssertTrue("T45 queue size", Grind_CloseByQueueSize(g_grind_long_closeby_queue) == 1);
   AssertTrue("T45 ticket1 orig", g_grind_long_closeby_queue[0].ticket1 == 1001);
   AssertTrue("T45 ticket2 hedge", g_grind_long_closeby_queue[0].ticket2 == 3002);
   AssertTrue("T45 exit position tracked", g_grind_long.layers[0].exit_position_ticket == 3002);

   Grind_CloseByTestReset();
   Grind_DealTestReset();
   Grind_TestResetSideState();
}

void Test_T46_CloseBySuccessRemovesTaskAndIncrementsScalpOnce()
{
   Grind_CloseByTestReset();
   Grind_DealTestReset();
   Grind_PnlReset();
   Grind_TestResetSideState();

   g_grind_closeby_test_active = true;
   g_grind_closeby_test_send_ok = true;
   g_grind_closeby_test_send_retcode = TRADE_RETCODE_DONE;
   g_grind_closeby_test_position_count = 2;
   ArrayResize(g_grind_closeby_test_positions, 2);
   g_grind_closeby_test_positions[0].ticket = 1001;
   g_grind_closeby_test_positions[0].symbol = _Symbol;
   g_grind_closeby_test_positions[0].type = POSITION_TYPE_BUY;
   g_grind_closeby_test_positions[1].ticket = 3002;
   g_grind_closeby_test_positions[1].symbol = _Symbol;
   g_grind_closeby_test_positions[1].type = POSITION_TYPE_SELL;

   Grind_QueueCloseBy(g_grind_long_closeby_queue, 1001, 3002);
   Grind_ProcessCloseByQueue(g_grind_long_closeby_queue, 22260101UL, false);
   AssertTrue("T46 queue empty", Grind_CloseByQueueSize(g_grind_long_closeby_queue) == 0);
   AssertTrue("T46 send counted", g_grind_closeby_test_send_calls == 1);

   ArrayResize(g_grind_long.layers, 1);
   g_grind_long.layers[0].position_ticket = 1001;
   g_grind_long.layers[0].exit_position_ticket = 3002;
   g_grind_long.layers[0].layer_index = 0;

   g_grind_deal_test_active = true;
   Grind_TestAppendDeal(9101, "#1001 by #3002", DEAL_ENTRY_OUT_BY, 0, 1001, 2.50, -0.30, -0.20);
   const int scalps_before = g_grind_scalp_count;
   Grind_HandleSideDealFill(g_grind_long, true, 9101, 22260101UL, "OPT",
                            3.0, 4.0, 12, 0.01);
   AssertTrue("T46 scalp once", g_grind_scalp_count == scalps_before + 1);
   AssertTrue("T46 layer removed", Grind_SideDepth(g_grind_long) == 0);

   Grind_CloseByTestReset();
   Grind_DealTestReset();
   Grind_PnlReset();
   Grind_TestResetSideState();
}

void Test_T46b_OutByDealAccumulatesRealisedPnl()
{
   Grind_DealTestReset();
   Grind_PnlReset();
   Grind_TestResetSideState();

   ArrayResize(g_grind_long.layers, 1);
   g_grind_long.layers[0].position_ticket = 1001;
   g_grind_long.layers[0].exit_position_ticket = 3002;
   g_grind_long.layers[0].layer_index = 0;

   g_grind_pnl_test_active = true;
   g_grind_pnl_test_server_time = D'2026.09.06 12:00:00';
   g_grind_deal_test_active = true;
   Grind_TestAppendDeal(9201, "#1001 by #3002", DEAL_ENTRY_OUT_BY, 0, 1001, 2.50, -0.30, -0.20);

   Grind_HandleSideDealFill(g_grind_long, true, 9201, 22260101UL, "OPT",
                            3.0, 4.0, 12, 0.01);
   AssertNear("T46b realised net", g_grind_realised_pnl_today, 2.00, 1e-8);

   Grind_DealTestReset();
   Grind_PnlReset();
   Grind_TestResetSideState();
}

void Test_T46c_ExitInDoesNotCountScalpOrPnl()
{
   Grind_DealTestReset();
   Grind_PnlReset();
   Grind_TestResetSideState();

   ArrayResize(g_grind_long.layers, 1);
   g_grind_long.layers[0].position_ticket = 1001;
   g_grind_long.layers[0].exit_order_ticket = 2001;
   g_grind_long.layers[0].layer_index = 0;

   g_grind_pnl_test_active = true;
   g_grind_pnl_test_server_time = D'2026.09.06 12:00:00';
   g_grind_deal_test_active = true;
   Grind_TestAppendDeal(9301,
                        GrindCommentBuild("OPT", "L", 0, "EXT"),
                        DEAL_ENTRY_IN,
                        2001,
                        3002,
                        5.00, 0.0, 0.0);

   const int scalps_before = g_grind_scalp_count;
   Grind_HandleSideDealFill(g_grind_long, true, 9301, 22260101UL, "OPT",
                            3.0, 4.0, 12, 0.01);
   AssertTrue("T46c no scalp", g_grind_scalp_count == scalps_before);
   AssertNear("T46c no pnl", g_grind_realised_pnl_today, 0.0, 1e-8);
   AssertTrue("T46c layer kept", Grind_SideDepth(g_grind_long) == 1);

   Grind_DealTestReset();
   Grind_PnlReset();
   Grind_TestResetSideState();
   Grind_CloseByTestReset();
}

void Test_T47_CloseByExhaustionHaltsCritical()
{
   Grind_CloseByTestReset();
   Grind_TestResetSideState();

   g_grind_closeby_test_active = true;
   g_grind_closeby_test_send_ok = false;
   g_grind_closeby_test_send_retcode = TRADE_RETCODE_REJECT;
   g_grind_closeby_test_position_count = 2;
   ArrayResize(g_grind_closeby_test_positions, 2);
   g_grind_closeby_test_positions[0].ticket = 5001;
   g_grind_closeby_test_positions[0].symbol = _Symbol;
   g_grind_closeby_test_positions[0].type = POSITION_TYPE_BUY;
   g_grind_closeby_test_positions[1].ticket = 5002;
   g_grind_closeby_test_positions[1].symbol = _Symbol;
   g_grind_closeby_test_positions[1].type = POSITION_TYPE_SELL;

   Grind_QueueCloseBy(g_grind_long_closeby_queue, 5001, 5002);
   for(int i = 0; i < GRIND_CLOSEBY_MAX_RETRIES; i++)
      Grind_ProcessCloseByQueue(g_grind_long_closeby_queue, 22260101UL, false);

   AssertTrue("T47 halted", g_grind_halted);
   AssertTrue("T47 queue drained", Grind_CloseByQueueSize(g_grind_long_closeby_queue) == 0);
   AssertContains("T47 critical", g_grind_closeby_test_last_critical, "5001");
   AssertContains("T47 critical by", g_grind_closeby_test_last_critical, "5002");

   Grind_CloseByTestReset();
   Grind_TestResetSideState();
}

void Test_T48_BackwardIterationProcessesAllThree()
{
   Grind_CloseByTestReset();

   g_grind_closeby_test_active = true;
   g_grind_closeby_test_send_ok = true;
   g_grind_closeby_test_send_retcode = TRADE_RETCODE_DONE;
   g_grind_closeby_test_position_count = 6;
   ArrayResize(g_grind_closeby_test_positions, 6);
   for(int i = 0; i < 6; i++) {
      g_grind_closeby_test_positions[i].ticket = 6000 + (ulong)i;
      g_grind_closeby_test_positions[i].symbol = _Symbol;
      g_grind_closeby_test_positions[i].type = (i % 2 == 0)
                                               ? POSITION_TYPE_BUY
                                               : POSITION_TYPE_SELL;
   }

   Grind_QueueCloseBy(g_grind_long_closeby_queue, 6000, 6001);
   Grind_QueueCloseBy(g_grind_long_closeby_queue, 6002, 6003);
   Grind_QueueCloseBy(g_grind_long_closeby_queue, 6004, 6005);

   g_grind_closeby_test_success_ticket1 = 6002;
   g_grind_closeby_test_success_ticket2 = 6003;
   Grind_ProcessCloseByQueue(g_grind_long_closeby_queue, 22260101UL, false);

   AssertTrue("T48 middle removed", Grind_CloseByQueueSize(g_grind_long_closeby_queue) == 2);
   AssertTrue("T48 first remains", g_grind_long_closeby_queue[0].ticket1 == 6000);
   AssertTrue("T48 last remains", g_grind_long_closeby_queue[1].ticket1 == 6004);
   AssertTrue("T48 all three attempted", g_grind_closeby_test_send_calls == 3);

   g_grind_closeby_test_success_ticket1 = 0;
   g_grind_closeby_test_success_ticket2 = 0;
   Grind_ProcessCloseByQueue(g_grind_long_closeby_queue, 22260101UL, false);
   AssertTrue("T48 remainder cleared", Grind_CloseByQueueSize(g_grind_long_closeby_queue) == 0);

   Grind_CloseByTestReset();
}

void Test_T49_InvariantRestingExtOrderPasses()
{
   const ulong magic = 22260101UL;
   GrindReconTicket tickets[2];
   tickets[0].ticket = 1001; tickets[0].magic = magic;
   tickets[0].comment = GrindCommentBuild("OPT", "L", 0, "ENT");
   tickets[0].price = 1.25000; tickets[0].kind = GRIND_RECON_TICKET_POSITION;
   tickets[1].ticket = 2001; tickets[1].magic = magic;
   tickets[1].comment = GrindCommentBuild("OPT", "L", 0, "EXT");
   tickets[1].price = 1.25030; tickets[1].kind = GRIND_RECON_TICKET_ORDER;
   GrindSideState long_out;
   GrindSideState short_out;
   string reason = "";
   AssertTrue("T49 ok", Grind_RebuildBookFromTickets(tickets, 2, magic, "OPT",
                                                     3.0, 12, 0.00001,
                                                     long_out, short_out, reason));
}

void Test_T50_InvariantOpenExtPositionPasses()
{
   const ulong magic = 22260101UL;
   GrindReconTicket tickets[2];
   tickets[0].ticket = 1001; tickets[0].magic = magic;
   tickets[0].comment = GrindCommentBuild("OPT", "L", 0, "ENT");
   tickets[0].price = 1.25000; tickets[0].kind = GRIND_RECON_TICKET_POSITION;
   tickets[1].ticket = 3002; tickets[1].magic = magic;
   tickets[1].comment = GrindCommentBuild("OPT", "L", 0, "EXT");
   tickets[1].price = 1.25030; tickets[1].kind = GRIND_RECON_TICKET_POSITION;
   GrindSideState long_out;
   GrindSideState short_out;
   string reason = "";
   AssertTrue("T50 ok", Grind_RebuildBookFromTickets(tickets, 2, magic, "OPT",
                                                     3.0, 12, 0.00001,
                                                     long_out, short_out, reason));
}

void Test_T51_InvariantNeitherExitStillHalts()
{
   const ulong magic = 22260101UL;
   GrindReconTicket tickets[1];
   tickets[0].ticket = 1001; tickets[0].magic = magic;
   tickets[0].comment = GrindCommentBuild("OPT", "L", 0, "ENT");
   tickets[0].price = 1.25000; tickets[0].kind = GRIND_RECON_TICKET_POSITION;
   GrindSideState long_out;
   GrindSideState short_out;
   string reason = "";
   AssertTrue("T51 halt", !Grind_RebuildBookFromTickets(tickets, 1, magic, "OPT",
                                                        3.0, 12, 0.00001,
                                                        long_out, short_out, reason));
   AssertTrue("T51 I3", StringFind(reason, "I3") >= 0);
}

void Test_T52_InvariantExtPositionWithEntNotOrphan()
{
   const ulong magic = 22260101UL;
   GrindReconTicket tickets[2];
   tickets[0].ticket = 1001; tickets[0].magic = magic;
   tickets[0].comment = GrindCommentBuild("OPT", "L", 0, "ENT");
   tickets[0].price = 1.25000; tickets[0].kind = GRIND_RECON_TICKET_POSITION;
   tickets[1].ticket = 3002; tickets[1].magic = magic;
   tickets[1].comment = GrindCommentBuild("OPT", "L", 0, "EXT");
   tickets[1].price = 1.25030; tickets[1].kind = GRIND_RECON_TICKET_POSITION;
   GrindSideState long_out;
   GrindSideState short_out;
   string reason = "";
   AssertTrue("T52 ok", Grind_RebuildBookFromTickets(tickets, 2, magic, "OPT",
                                                     3.0, 12, 0.00001,
                                                     long_out, short_out, reason));
   AssertTrue("T52 not I4", StringFind(reason, "I4") < 0);
}

void Test_T53_ReconDerivesCloseByPair()
{
   Grind_CloseByTestReset();
   Grind_TestResetSideState();

   const ulong magic = 22260101UL;
   GrindReconTicket tickets[2];
   tickets[0].ticket = 1001; tickets[0].magic = magic;
   tickets[0].comment = GrindCommentBuild("OPT", "L", 0, "ENT");
   tickets[0].price = 1.25000; tickets[0].kind = GRIND_RECON_TICKET_POSITION;
   tickets[1].ticket = 3002; tickets[1].magic = magic;
   tickets[1].comment = GrindCommentBuild("OPT", "L", 0, "EXT");
   tickets[1].price = 1.25030; tickets[1].kind = GRIND_RECON_TICKET_POSITION;

   string reason = "";
   AssertTrue("T53 rebuild ok", Grind_RebuildBookFromTickets(tickets, 2, magic, "OPT",
                                                             3.0, 12, 0.00001,
                                                             g_grind_long, g_grind_short,
                                                             reason));
   Grind_DeriveCloseByQueueFromBook("OPT", false);

   AssertTrue("T53 one task", Grind_CloseByQueueSize(g_grind_long_closeby_queue) == 1);
   AssertTrue("T53 short empty", Grind_CloseByQueueSize(g_grind_short_closeby_queue) == 0);
   AssertTrue("T53 ticket1 entry", g_grind_long_closeby_queue[0].ticket1 == 1001);
   AssertTrue("T53 ticket2 exit", g_grind_long_closeby_queue[0].ticket2 == 3002);

   Grind_CloseByTestReset();
   Grind_TestResetSideState();
}

void Test_T54_RestingExtOrderQueuesNothing()
{
   Grind_CloseByTestReset();
   Grind_TestResetSideState();

   const ulong magic = 22260101UL;
   GrindReconTicket tickets[2];
   tickets[0].ticket = 1001; tickets[0].magic = magic;
   tickets[0].comment = GrindCommentBuild("OPT", "L", 0, "ENT");
   tickets[0].price = 1.25000; tickets[0].kind = GRIND_RECON_TICKET_POSITION;
   tickets[1].ticket = 2001; tickets[1].magic = magic;
   tickets[1].comment = GrindCommentBuild("OPT", "L", 0, "EXT");
   tickets[1].price = 1.25030; tickets[1].kind = GRIND_RECON_TICKET_ORDER;

   string reason = "";
   AssertTrue("T54 rebuild ok", Grind_RebuildBookFromTickets(tickets, 2, magic, "OPT",
                                                             3.0, 12, 0.00001,
                                                             g_grind_long, g_grind_short,
                                                             reason));
   Grind_DeriveCloseByQueueFromBook("OPT", false);

   AssertTrue("T54 no long queue", Grind_CloseByQueueSize(g_grind_long_closeby_queue) == 0);
   AssertTrue("T54 no short queue", Grind_CloseByQueueSize(g_grind_short_closeby_queue) == 0);

   Grind_CloseByTestReset();
   Grind_TestResetSideState();
}

void Test_T55_TwoPendingClosePairsQueueTwoTasks()
{
   Grind_CloseByTestReset();
   Grind_TestResetSideState();

   const ulong magic = 22260101UL;
   GrindReconTicket tickets[4];
   tickets[0].ticket = 1001; tickets[0].magic = magic;
   tickets[0].comment = GrindCommentBuild("OPT", "L", 0, "ENT");
   tickets[0].price = 1.25000; tickets[0].kind = GRIND_RECON_TICKET_POSITION;
   tickets[1].ticket = 3002; tickets[1].magic = magic;
   tickets[1].comment = GrindCommentBuild("OPT", "L", 0, "EXT");
   tickets[1].price = 1.25030; tickets[1].kind = GRIND_RECON_TICKET_POSITION;
   tickets[2].ticket = 4001; tickets[2].magic = magic;
   tickets[2].comment = GrindCommentBuild("OPT", "S", 0, "ENT");
   tickets[2].price = 1.25100; tickets[2].kind = GRIND_RECON_TICKET_POSITION;
   tickets[3].ticket = 5002; tickets[3].magic = magic;
   tickets[3].comment = GrindCommentBuild("OPT", "S", 0, "EXT");
   tickets[3].price = 1.25070; tickets[3].kind = GRIND_RECON_TICKET_POSITION;

   string reason = "";
   AssertTrue("T55 rebuild ok", Grind_RebuildBookFromTickets(tickets, 4, magic, "OPT",
                                                             3.0, 12, 0.00001,
                                                             g_grind_long, g_grind_short,
                                                             reason));
   Grind_DeriveCloseByQueueFromBook("OPT", false);

   AssertTrue("T55 long one", Grind_CloseByQueueSize(g_grind_long_closeby_queue) == 1);
   AssertTrue("T55 short one", Grind_CloseByQueueSize(g_grind_short_closeby_queue) == 1);
   AssertTrue("T55 long pair", g_grind_long_closeby_queue[0].ticket1 == 1001
                                && g_grind_long_closeby_queue[0].ticket2 == 3002);
   AssertTrue("T55 short pair", g_grind_short_closeby_queue[0].ticket1 == 4001
                                 && g_grind_short_closeby_queue[0].ticket2 == 5002);

   Grind_CloseByTestReset();
   Grind_TestResetSideState();
}

void Test_T56_InvariantFailQueuesNothing()
{
   Grind_CloseByTestReset();
   Grind_TestResetSideState();

   const ulong magic = 22260101UL;
   GrindReconTicket tickets[1];
   tickets[0].ticket = 1001; tickets[0].magic = magic;
   tickets[0].comment = GrindCommentBuild("OPT", "L", 0, "ENT");
   tickets[0].price = 1.25000; tickets[0].kind = GRIND_RECON_TICKET_POSITION;

   string reason = "";
   AssertTrue("T56 halt", !Grind_RebuildBookFromTickets(tickets, 1, magic, "OPT",
                                                        3.0, 12, 0.00001,
                                                        g_grind_long, g_grind_short,
                                                        reason));
   AssertTrue("T56 no long queue", Grind_CloseByQueueSize(g_grind_long_closeby_queue) == 0);
   AssertTrue("T56 no short queue", Grind_CloseByQueueSize(g_grind_short_closeby_queue) == 0);

   Grind_CloseByTestReset();
   Grind_TestResetSideState();
}

void Test_T57_QueueCloseByIdempotent()
{
   Grind_CloseByTestReset();

   Grind_QueueCloseBy(g_grind_long_closeby_queue, 1001, 3002);
   Grind_QueueCloseBy(g_grind_long_closeby_queue, 1001, 3002);

   AssertTrue("T57 one task", Grind_CloseByQueueSize(g_grind_long_closeby_queue) == 1);
   AssertTrue("T57 ticket1", g_grind_long_closeby_queue[0].ticket1 == 1001);
   AssertTrue("T57 ticket2", g_grind_long_closeby_queue[0].ticket2 == 3002);

   Grind_CloseByTestReset();
}

void Test_T57b_RestartSequenceSingleTask()
{
   Grind_CloseByTestReset();
   Grind_DealTestReset();
   Grind_TestResetSideState();

   const ulong magic = 22260101UL;
   GrindReconTicket tickets[2];
   tickets[0].ticket = 1001; tickets[0].magic = magic;
   tickets[0].comment = GrindCommentBuild("OPT", "L", 0, "ENT");
   tickets[0].price = 1.25000; tickets[0].kind = GRIND_RECON_TICKET_POSITION;
   tickets[1].ticket = 3002; tickets[1].magic = magic;
   tickets[1].comment = GrindCommentBuild("OPT", "L", 0, "EXT");
   tickets[1].price = 1.25030; tickets[1].kind = GRIND_RECON_TICKET_POSITION;

   string reason = "";
   AssertTrue("T57b rebuild ok", Grind_RebuildBookFromTickets(tickets, 2, magic, "OPT",
                                                               3.0, 12, 0.00001,
                                                               g_grind_long, g_grind_short,
                                                               reason));
   Grind_DeriveCloseByQueueFromBook("OPT", false);
   AssertTrue("T57b derived one", Grind_CloseByQueueSize(g_grind_long_closeby_queue) == 1);

   g_grind_deal_test_active = true;
   Grind_TestAppendDeal(9701,
                        GrindCommentBuild("OPT", "L", 0, "EXT"),
                        DEAL_ENTRY_IN,
                        2001,
                        3002,
                        0.0, 0.0, 0.0);

   Grind_HandleSideDealFill(g_grind_long, true, 9701, magic, "OPT",
                            3.0, 4.0, 12, 0.01);

   AssertTrue("T57b still one", Grind_CloseByQueueSize(g_grind_long_closeby_queue) == 1);

   Grind_CloseByTestReset();
   Grind_DealTestReset();
   Grind_TestResetSideState();
}

void Test_T58_EmptyBookQueuesNothing()
{
   Grind_CloseByTestReset();
   Grind_TestResetSideState();

   GrindReconTicket tickets[];
   string reason = "";
   AssertTrue("T58 rebuild ok", Grind_RebuildBookFromTickets(tickets, 0,
                                                             22260101UL, "OPT",
                                                             3.0, 12, 0.00001,
                                                             g_grind_long, g_grind_short,
                                                             reason));
   Grind_DeriveCloseByQueueFromBook("OPT", false);

   AssertTrue("T58 no long queue", Grind_CloseByQueueSize(g_grind_long_closeby_queue) == 0);
   AssertTrue("T58 no short queue", Grind_CloseByQueueSize(g_grind_short_closeby_queue) == 0);

   Grind_CloseByTestReset();
   Grind_TestResetSideState();
}

void Test_OrderBudgetArithmetic()
{
   AssertTrue("budget 12 side", Grind_RestingOrderBudgetPerSide(12) == 13);
   AssertTrue("budget inst", Grind_RestingOrderBudgetInstance(12, 12) == 26);
   AssertTrue("budget eurgbp", Grind_RestingOrderBudgetInstance(8, 8) == 18);
}

void Grind_TestSetupLongDepth1(const double entry_price)
{
   Grind_TestResetSideState();
   ArrayResize(g_grind_long.layers, 1);
   g_grind_long.layers[0].entry_price = entry_price;
   g_grind_long.layers[0].layer_index = 0;
   g_grind_long.layers[0].position_ticket = 1001;
   g_grind_long.layers[0].exit_order_ticket = 0;
   g_grind_long.layers[0].exit_position_ticket = 0;
   g_grind_long.layers[0].exit_target = Grind_ExitPrice(entry_price, 3.0, _Point, 1);
}

void Grind_TestSetupShortDepth1(const double entry_price)
{
   Grind_TestResetSideState();
   ArrayResize(g_grind_short.layers, 1);
   g_grind_short.layers[0].entry_price = entry_price;
   g_grind_short.layers[0].layer_index = 0;
   g_grind_short.layers[0].position_ticket = 1001;
   g_grind_short.layers[0].exit_order_ticket = 0;
   g_grind_short.layers[0].exit_position_ticket = 0;
   g_grind_short.layers[0].exit_target = Grind_ExitPrice(entry_price, 5.0, _Point, -1);
}

void Grind_TestSeedPendingAdd(const ulong ticket,
                              const ulong magic,
                              const string comment,
                              const double price,
                              const long type)
{
   g_grind_order_test_active = true;
   Grind_OrderTestUpsert(ticket, (long)magic, comment, price, type);
}

double Grind_TestEngineClampedAddPrice(const GrindSideState &side,
                                       const bool is_long,
                                       const double add_pips)
{
   const double add_target = Grind_ComputeAddTarget(side, is_long, add_pips);
   const double bid = Grind_MarketBid();
   const double ask = Grind_MarketAsk();
   const long stops = Grind_MarketStopsLevel();
   double clamped = add_target;
   if(is_long)
      Grind_Adr013ClampBuy(add_target, bid, _Point, stops, clamped);
   else
      Grind_Adr013ClampSell(add_target, bid, ask, _Point, stops, clamped);
   return Grind_Normalize(clamped);
}

void Test_A1_StaleLabelDeletesNoPlaceSameTick()
{
   Grind_OrderTestReset();
   Grind_TestSetupLongDepth1(1.25000);
   g_grind_cap_thresh_a = 0.0;
   g_grind_cap_thresh_b = 0.0;

   const ulong magic = 22260101UL;
   const ulong stale_ticket = 8101;
   g_grind_long.add_pending_ticket = stale_ticket;
   Grind_TestSeedPendingAdd(stale_ticket, magic,
                            GrindCommentBuild("OPT", "L", 3, "ENT"),
                            1.24900, (long)ORDER_TYPE_BUY_LIMIT);

   Grind_EnsureAddNext(g_grind_long, true, magic, "OPT",
                       10.0, 4.0, 12, 0.01);

   AssertTrue("A1 remove once", g_grind_order_test_remove_calls == 1);
   AssertTrue("A1 no place", g_grind_order_test_place_calls == 0);
   AssertTrue("A1 ticket cleared", g_grind_long.add_pending_ticket == 0);

   Grind_OrderTestReset();
   Grind_TestResetSideState();
   g_grind_cap_thresh_a = 0.0;
   g_grind_cap_thresh_b = 0.0;
}

void Test_A2_MatchingLabelDeadbandUnchanged()
{
   Grind_OrderTestReset();
   Grind_TestSetupLongDepth1(1.25000);
   g_grind_cap_thresh_a = 0.0;
   g_grind_cap_thresh_b = 0.0;

   const ulong magic = 22260101UL;
   Grind_MarketTestSeed(1.24950, 1.24952, 0);
   const double engine_price = Grind_TestEngineClampedAddPrice(g_grind_long, true, 10.0);
   const ulong ticket = 8102;
   g_grind_long.add_pending_ticket = ticket;
   Grind_TestSeedPendingAdd(ticket, magic,
                            GrindCommentBuild("OPT", "L", 1, "ENT"),
                            engine_price, (long)ORDER_TYPE_BUY_LIMIT);

   Grind_EnsureAddNext(g_grind_long, true, magic, "OPT",
                       10.0, 4.0, 12, 0.01);

   AssertTrue("A2 no remove", g_grind_order_test_remove_calls == 0);
   AssertTrue("A2 no modify", g_grind_order_test_modify_calls == 0);
   AssertTrue("A2 no place", g_grind_order_test_place_calls == 0);
   AssertTrue("A2 ticket kept", g_grind_long.add_pending_ticket == ticket);

   Grind_OrderTestReset();
   Grind_TestResetSideState();
   g_grind_cap_thresh_a = 0.0;
   g_grind_cap_thresh_b = 0.0;
}

void Test_A3_NextTickPlacesFreshAdd()
{
   Grind_OrderTestReset();
   Grind_TestSetupLongDepth1(1.25000);
   g_grind_cap_thresh_a = 0.0;
   g_grind_cap_thresh_b = 0.0;

   const ulong magic = 22260101UL;
   Grind_MarketTestSeed(1.24950, 1.24952, 0);
   const ulong stale_ticket = 8103;
   g_grind_long.add_pending_ticket = stale_ticket;
   Grind_TestSeedPendingAdd(stale_ticket, magic,
                            GrindCommentBuild("OPT", "L", 3, "ENT"),
                            1.24900, (long)ORDER_TYPE_BUY_LIMIT);

   Grind_EnsureAddNext(g_grind_long, true, magic, "OPT",
                       10.0, 4.0, 12, 0.01);
   Grind_EnsureAddNext(g_grind_long, true, magic, "OPT",
                       10.0, 4.0, 12, 0.01);

   const double engine_price = Grind_TestEngineClampedAddPrice(g_grind_long, true, 10.0);
   AssertTrue("A3 placed once", g_grind_order_test_place_calls == 1);
   AssertTrue("A3 label L01",
              g_grind_order_test_last_placed_comment
              == GrindCommentBuild("OPT", "L", 1, "ENT"));
   AssertNear("A3 price", g_grind_order_test_last_placed_price, engine_price, _Point);

   Grind_OrderTestReset();
   Grind_TestResetSideState();
   g_grind_cap_thresh_a = 0.0;
   g_grind_cap_thresh_b = 0.0;
}

void Test_A4_UnparseableCommentRemoved()
{
   Grind_OrderTestReset();
   Grind_TestSetupLongDepth1(1.25000);
   g_grind_cap_thresh_a = 0.0;
   g_grind_cap_thresh_b = 0.0;

   const ulong magic = 22260101UL;
   const ulong stale_ticket = 8104;
   g_grind_long.add_pending_ticket = stale_ticket;
   Grind_TestSeedPendingAdd(stale_ticket, magic,
                            "GRIND|OPT|L|BAD",
                            1.24900, (long)ORDER_TYPE_BUY_LIMIT);

   Grind_EnsureAddNext(g_grind_long, true, magic, "OPT",
                       10.0, 4.0, 12, 0.01);

   AssertTrue("A4 remove once", g_grind_order_test_remove_calls == 1);
   AssertTrue("A4 ticket cleared", g_grind_long.add_pending_ticket == 0);

   Grind_OrderTestReset();
   Grind_TestResetSideState();
   g_grind_cap_thresh_a = 0.0;
   g_grind_cap_thresh_b = 0.0;
}

void Test_A4b_FailedRemovalKeepsTicket()
{
   Grind_OrderTestReset();
   Grind_TestSetupLongDepth1(1.25000);
   g_grind_cap_thresh_a = 0.0;
   g_grind_cap_thresh_b = 0.0;

   const ulong magic = 22260101UL;
   const ulong stale_ticket = 8105;
   g_grind_long.add_pending_ticket = stale_ticket;
   Grind_TestSeedPendingAdd(stale_ticket, magic,
                            GrindCommentBuild("OPT", "L", 3, "ENT"),
                            1.24900, (long)ORDER_TYPE_BUY_LIMIT);
   g_grind_order_test_send_ok = false;
   g_grind_order_test_send_retcode = TRADE_RETCODE_REJECT;

   Grind_EnsureAddNext(g_grind_long, true, magic, "OPT",
                       10.0, 4.0, 12, 0.01);

   AssertTrue("A4b remove attempted", g_grind_order_test_remove_calls == 1);
   AssertTrue("A4b ticket kept", g_grind_long.add_pending_ticket == stale_ticket);
   AssertTrue("A4b no place", g_grind_order_test_place_calls == 0);

   Grind_OrderTestReset();
   Grind_TestResetSideState();
   g_grind_cap_thresh_a = 0.0;
   g_grind_cap_thresh_b = 0.0;
}

void Test_A5_PlacementGuardHaltsInPlace()
{
   Grind_OrderTestReset();
   Grind_TestResetSideState();
   g_grind_halted = false;
   g_grind_halt_reason = "";
   g_grind_order_test_active = true;

   AssertTrue("A5 guard fails", !Grind_ValidateAddLabelIndex(1, 3));
   AssertTrue("A5 halted", g_grind_halted);
   AssertEqStr("A5 reason", g_grind_halt_reason, "HALT_ADD_INDEX_MISMATCH");
   AssertContains("A5 critical computed",
                  g_grind_order_test_last_critical, "computed=1");
   AssertContains("A5 critical label",
                  g_grind_order_test_last_critical, "label=3");
   AssertTrue("A5 no place", g_grind_order_test_place_calls == 0);

   Grind_OrderTestReset();
   Grind_TestResetSideState();
   g_grind_cap_thresh_a = 0.0;
   g_grind_cap_thresh_b = 0.0;
}

void Test_A6_StaleIndexAdoptedNotInvariant()
{
   const ulong magic = 22260101UL;
   GrindReconTicket tickets[3];
   tickets[0].ticket = 1001;
   tickets[0].magic = magic;
   tickets[0].comment = GrindCommentBuild("OPT", "S", 0, "ENT");
   tickets[0].price = 1.35666;
   tickets[0].kind = GRIND_RECON_TICKET_POSITION;
   tickets[1].ticket = 2001;
   tickets[1].magic = magic;
   tickets[1].comment = GrindCommentBuild("OPT", "S", 0, "EXT");
   tickets[1].price = Grind_ExitPrice(1.35666, 5.0, 0.00001, -1);
   tickets[1].kind = GRIND_RECON_TICKET_ORDER;
   tickets[2].ticket = 9001;
   tickets[2].magic = magic;
   tickets[2].comment = GrindCommentBuild("OPT", "S", 3, "ENT");
   tickets[2].price = 1.35642;
   tickets[2].kind = GRIND_RECON_TICKET_ORDER;

   GrindSideState long_out;
   GrindSideState short_out;
   string reason = "";
   AssertTrue("A6 ok",
              Grind_RebuildBookFromTickets(tickets, 3, magic, "OPT",
                                           5.0, 12, 0.00001,
                                           long_out, short_out, reason));
   AssertTrue("A6 no reason", reason == "");
   AssertTrue("A6 adopts stale ticket", short_out.add_pending_ticket == 9001);
   Grind_TestResetSideState();
}

void Test_A7_InvariantMatchingPendingAddPasses()
{
   const ulong magic = 22260101UL;
   GrindReconTicket tickets[3];
   tickets[0].ticket = 1001;
   tickets[0].magic = magic;
   tickets[0].comment = GrindCommentBuild("OPT", "L", 0, "ENT");
   tickets[0].price = 1.25000;
   tickets[0].kind = GRIND_RECON_TICKET_POSITION;
   tickets[1].ticket = 2001;
   tickets[1].magic = magic;
   tickets[1].comment = GrindCommentBuild("OPT", "L", 0, "EXT");
   tickets[1].price = 1.25030;
   tickets[1].kind = GRIND_RECON_TICKET_ORDER;
   tickets[2].ticket = 9002;
   tickets[2].magic = magic;
   tickets[2].comment = GrindCommentBuild("OPT", "L", 1, "ENT");
   tickets[2].price = 1.24900;
   tickets[2].kind = GRIND_RECON_TICKET_ORDER;

   string reason = "";
   AssertTrue("A7 ok",
              Grind_RebuildBookFromTickets(tickets, 3, magic, "OPT",
                                           3.0, 12, 0.00001,
                                           g_grind_long, g_grind_short,
                                           reason));
   AssertTrue("A7 no reason", reason == "");
   Grind_TestResetSideState();
}

void Test_A8_ObservedFailureReproAndFix()
{
   Grind_OrderTestReset();
   Grind_TestSetupShortDepth1(1.35666);
   g_grind_cap_thresh_a = 0.0;
   g_grind_cap_thresh_b = 0.0;

   const ulong magic = 22260101UL;
   Grind_MarketTestSeed(1.35650, 1.35670, 0);
   const ulong stale_ticket = 8108;
   g_grind_short.add_pending_ticket = stale_ticket;
   Grind_TestSeedPendingAdd(stale_ticket, magic,
                            GrindCommentBuild("OPT", "S", 3, "ENT"),
                            1.35642, (long)ORDER_TYPE_SELL_LIMIT);

   Grind_EnsureAddNext(g_grind_short, false, magic, "OPT",
                       10.0, 4.0, 12, 0.01);
   AssertTrue("A8 tick1 remove", g_grind_order_test_remove_calls == 1);
   AssertTrue("A8 tick1 no place", g_grind_order_test_place_calls == 0);

   Grind_EnsureAddNext(g_grind_short, false, magic, "OPT",
                       10.0, 4.0, 12, 0.01);
   const double engine_price = Grind_TestEngineClampedAddPrice(g_grind_short, false, 10.0);
   AssertTrue("A8 tick2 place", g_grind_order_test_place_calls == 1);
   AssertTrue("A8 label L01",
              g_grind_order_test_last_placed_comment
              == GrindCommentBuild("OPT", "S", 1, "ENT"));
   AssertNear("A8 price", g_grind_order_test_last_placed_price, engine_price, _Point);

   Grind_OrderTestReset();
   Grind_TestResetSideState();
   g_grind_cap_thresh_a = 0.0;
   g_grind_cap_thresh_b = 0.0;
}

void Test_N1_DepthZeroStaleLabelPassesInvariant()
{
   const ulong magic = 22260101UL;
   GrindReconTicket tickets[1];
   tickets[0].ticket = 9001;
   tickets[0].magic = magic;
   tickets[0].comment = GrindCommentBuild("OPT", "L", 1, "ENT");
   tickets[0].price = 0.85774;
   tickets[0].kind = GRIND_RECON_TICKET_ORDER;

   GrindSideState long_out;
   GrindSideState short_out;
   string reason = "";
   AssertTrue("N1 ok",
              Grind_RebuildBookFromTickets(tickets, 1, magic, "OPT",
                                           3.0, 12, 0.00001,
                                           long_out, short_out, reason));
   AssertTrue("N1 no reason", reason == "");
   AssertTrue("N1 adopts ticket", long_out.add_pending_ticket == 9001);
   Grind_TestResetSideState();
}

void Test_N2_PendingAddWrongKindFailsI8()
{
   GrindReconTicket tickets[1];
   tickets[0].ticket = 9002;
   tickets[0].magic = 22260101UL;
   tickets[0].comment = GrindCommentBuild("OPT", "L", 1, "ENT");
   tickets[0].price = 1.24900;
   tickets[0].kind = GRIND_RECON_TICKET_POSITION;

   string reason = "";
   AssertTrue("N2 halt",
              !Grind_ReconCheckPendingAddCorrupt(tickets, 1, 9002, reason));
   AssertEqStr("N2 reason", reason, "I8_CORRUPT_PENDING_ADD");
}

void Test_N3_DuplicateRestingAddFailsAmbiguous()
{
   const ulong magic = 22260101UL;
   GrindReconTicket tickets[2];
   tickets[0].ticket = 9003;
   tickets[0].magic = magic;
   tickets[0].comment = GrindCommentBuild("OPT", "L", 1, "ENT");
   tickets[0].price = 0.85774;
   tickets[0].kind = GRIND_RECON_TICKET_ORDER;
   tickets[1].ticket = 9004;
   tickets[1].magic = magic;
   tickets[1].comment = GrindCommentBuild("OPT", "L", 1, "ENT");
   tickets[1].price = 0.85780;
   tickets[1].kind = GRIND_RECON_TICKET_ORDER;

   GrindSideState long_out;
   GrindSideState short_out;
   string reason = "";
   AssertTrue("N3 halt",
              !Grind_RebuildBookFromTickets(tickets, 2, magic, "OPT",
                                            3.0, 12, 0.00001,
                                            long_out, short_out, reason));
   AssertEqStr("N3 reason", reason, "AMBIGUOUS_ADD_LONG");
   Grind_TestResetSideState();
}

void Test_N4_ReconstructionAdoptsMismatchedTicket()
{
   const ulong magic = 22260101UL;
   GrindReconTicket tickets[3];
   tickets[0].ticket = 1001;
   tickets[0].magic = magic;
   tickets[0].comment = GrindCommentBuild("OPT", "L", 0, "ENT");
   tickets[0].price = 1.25000;
   tickets[0].kind = GRIND_RECON_TICKET_POSITION;
   tickets[1].ticket = 2001;
   tickets[1].magic = magic;
   tickets[1].comment = GrindCommentBuild("OPT", "L", 0, "EXT");
   tickets[1].price = 1.25030;
   tickets[1].kind = GRIND_RECON_TICKET_ORDER;
   tickets[2].ticket = 9010;
   tickets[2].magic = magic;
   tickets[2].comment = GrindCommentBuild("OPT", "L", 3, "ENT");
   tickets[2].price = 1.24900;
   tickets[2].kind = GRIND_RECON_TICKET_ORDER;

   GrindSideState long_out;
   GrindSideState short_out;
   string reason = "";
   AssertTrue("N4 ok",
              Grind_RebuildBookFromTickets(tickets, 3, magic, "OPT",
                                           3.0, 12, 0.00001,
                                           long_out, short_out, reason));
   AssertTrue("N4 adopts ticket", long_out.add_pending_ticket == 9010);
   Grind_TestResetSideState();
}

void Test_N5_AdoptedStaleRemovedByReconciler()
{
   Grind_OrderTestReset();
   Grind_TestResetSideState();
   g_grind_cap_thresh_a = 0.0;
   g_grind_cap_thresh_b = 0.0;

   const ulong magic = 22260101UL;
   GrindReconTicket tickets[3];
   tickets[0].ticket = 1001;
   tickets[0].magic = magic;
   tickets[0].comment = GrindCommentBuild("OPT", "L", 0, "ENT");
   tickets[0].price = 1.25000;
   tickets[0].kind = GRIND_RECON_TICKET_POSITION;
   tickets[1].ticket = 2001;
   tickets[1].magic = magic;
   tickets[1].comment = GrindCommentBuild("OPT", "L", 0, "EXT");
   tickets[1].price = 1.25030;
   tickets[1].kind = GRIND_RECON_TICKET_ORDER;
   tickets[2].ticket = 9011;
   tickets[2].magic = magic;
   tickets[2].comment = GrindCommentBuild("OPT", "L", 3, "ENT");
   tickets[2].price = 1.24900;
   tickets[2].kind = GRIND_RECON_TICKET_ORDER;

   string reason = "";
   AssertTrue("N5 rebuild ok",
              Grind_RebuildBookFromTickets(tickets, 3, magic, "OPT",
                                           3.0, 12, 0.00001,
                                           g_grind_long, g_grind_short,
                                           reason));
   AssertTrue("N5 adopted", g_grind_long.add_pending_ticket == 9011);

   Grind_MarketTestSeed(1.24950, 1.24952, 0);
   Grind_TestSeedPendingAdd(9011, magic,
                            GrindCommentBuild("OPT", "L", 3, "ENT"),
                            1.24900, (long)ORDER_TYPE_BUY_LIMIT);

   Grind_EnsureAddNext(g_grind_long, true, magic, "OPT",
                       10.0, 4.0, 12, 0.01);

   AssertTrue("N5 remove once", g_grind_order_test_remove_calls == 1);
   AssertTrue("N5 no place", g_grind_order_test_place_calls == 0);
   AssertTrue("N5 ticket cleared", g_grind_long.add_pending_ticket == 0);

   Grind_OrderTestReset();
   Grind_TestResetSideState();
   g_grind_cap_thresh_a = 0.0;
   g_grind_cap_thresh_b = 0.0;
}

void Test_M1_DepthZeroStaleAddRemoved()
{
   Grind_OrderTestReset();
   Grind_TestResetSideState();
   g_grind_cap_thresh_a = 0.0;
   g_grind_cap_thresh_b = 0.0;

   const ulong magic = 22260101UL;
   const ulong stale_ticket = 9201;
   g_grind_long.add_pending_ticket = stale_ticket;
   Grind_TestSeedPendingAdd(stale_ticket, magic,
                            GrindCommentBuild("OPT", "L", 1, "ENT"),
                            0.85774, (long)ORDER_TYPE_BUY_LIMIT);

   Grind_EnsureAddNext(g_grind_long, true, magic, "OPT",
                       10.0, 4.0, 12, 0.01);

   AssertTrue("M1 remove once", g_grind_order_test_remove_calls == 1);
   AssertTrue("M1 no place", g_grind_order_test_place_calls == 0);
   AssertTrue("M1 ticket cleared", g_grind_long.add_pending_ticket == 0);

   Grind_OrderTestReset();
   Grind_TestResetSideState();
}

void Test_M2_DepthZeroNoPendingNoOp()
{
   Grind_OrderTestReset();
   Grind_TestResetSideState();

   Grind_EnsureAddNext(g_grind_long, true, 22260101UL, "OPT",
                       10.0, 4.0, 12, 0.01);

   AssertTrue("M2 no remove", g_grind_order_test_remove_calls == 0);
   AssertTrue("M2 no place", g_grind_order_test_place_calls == 0);
   AssertTrue("M2 no pending", g_grind_long.add_pending_ticket == 0);

   Grind_OrderTestReset();
   Grind_TestResetSideState();
}

void Test_M3_CapBlockedStillRemovesStaleAdd()
{
   Grind_OrderTestReset();
   Grind_TestSetupLongDepth1(1.25000);
   g_grind_cap_thresh_a = 1.0;
   g_grind_cap_thresh_b = 0.0;
   g_grind_recon_magic = 22260101UL;
   g_grind_cap_leg_a = "EUR";
   g_grind_cap_leg_b = "USD";

   for(int i = 0; i < 6; i++) {
      const ulong magic = GRIND_CAP_ALL_MAGICS[i];
      const string key = Grind_CapExposureKey(magic, "EUR");
      GlobalVariableSet(key, 0.0);
      GlobalVariableSet(Grind_CapTimestampKey(key), (double)TimeCurrent());
   }
   const string own_key = Grind_CapExposureKey(22260101UL, "EUR");
   GlobalVariableSet(own_key, 0.99);
   GlobalVariableSet(Grind_CapTimestampKey(own_key), (double)TimeCurrent());

   const ulong magic = 22260101UL;
   const ulong stale_ticket = 9203;
   g_grind_long.add_pending_ticket = stale_ticket;
   Grind_TestSeedPendingAdd(stale_ticket, magic,
                            GrindCommentBuild("OPT", "L", 3, "ENT"),
                            1.24900, (long)ORDER_TYPE_BUY_LIMIT);

   Grind_EnsureAddNext(g_grind_long, true, magic, "OPT",
                       10.0, 4.0, 12, 0.01);

   AssertTrue("M3 cap blocked", !Grind_CapAllowsEntry(true, 0.01));
   AssertTrue("M3 remove once", g_grind_order_test_remove_calls == 1);
   AssertTrue("M3 no place", g_grind_order_test_place_calls == 0);

   g_grind_cap_thresh_a = 0.0;
   Grind_OrderTestReset();
   Grind_TestResetSideState();
}

void Test_M4_LayerCapReachedStillRemovesStaleAdd()
{
   Grind_OrderTestReset();
   Grind_TestResetSideState();
   g_grind_cap_thresh_a = 0.0;
   g_grind_cap_thresh_b = 0.0;

   const int max_layers = 2;
   ArrayResize(g_grind_long.layers, max_layers);
   for(int i = 0; i < max_layers; i++) {
      g_grind_long.layers[i].entry_price = 1.25000 - (double)i * 0.00100;
      g_grind_long.layers[i].layer_index = i;
      g_grind_long.layers[i].position_ticket = 1100 + (ulong)i;
      g_grind_long.layers[i].exit_order_ticket = 0;
      g_grind_long.layers[i].exit_position_ticket = 0;
      g_grind_long.layers[i].exit_target = Grind_ExitPrice(g_grind_long.layers[i].entry_price,
                                                           3.0, _Point, 1);
   }

   const ulong magic = 22260101UL;
   const ulong stale_ticket = 9204;
   g_grind_long.add_pending_ticket = stale_ticket;
   Grind_TestSeedPendingAdd(stale_ticket, magic,
                            GrindCommentBuild("OPT", "L", 0, "ENT"),
                            1.24800, (long)ORDER_TYPE_BUY_LIMIT);

   AssertTrue("M4 cap reached", !Grind_CanPlaceEntryLayer(max_layers, max_layers));

   Grind_EnsureAddNext(g_grind_long, true, magic, "OPT",
                       10.0, 4.0, max_layers, 0.01);

   AssertTrue("M4 remove once", g_grind_order_test_remove_calls == 1);
   AssertTrue("M4 no place", g_grind_order_test_place_calls == 0);

   Grind_OrderTestReset();
   Grind_TestResetSideState();
}

void Test_M5_MatchingLabelAtDepthOneUnchanged()
{
   Grind_OrderTestReset();
   Grind_TestSetupLongDepth1(1.25000);
   g_grind_cap_thresh_a = 0.0;
   g_grind_cap_thresh_b = 0.0;

   const ulong magic = 22260101UL;
   Grind_MarketTestSeed(1.24950, 1.24952, 0);
   const double engine_price = Grind_TestEngineClampedAddPrice(g_grind_long, true, 10.0);
   const ulong ticket = 9205;
   g_grind_long.add_pending_ticket = ticket;
   Grind_TestSeedPendingAdd(ticket, magic,
                            GrindCommentBuild("OPT", "L", 1, "ENT"),
                            engine_price, (long)ORDER_TYPE_BUY_LIMIT);

   Grind_EnsureAddNext(g_grind_long, true, magic, "OPT",
                       10.0, 4.0, 12, 0.01);

   AssertTrue("M5 no remove", g_grind_order_test_remove_calls == 0);
   AssertTrue("M5 no place", g_grind_order_test_place_calls == 0);
   AssertTrue("M5 ticket kept", g_grind_long.add_pending_ticket == ticket);

   Grind_OrderTestReset();
   Grind_TestResetSideState();
}

void Test_O1_UnwindToFlatKeepsAddPendingTracker()
{
   Grind_TestSetupLongDepth1(1.25000);
   const ulong ticket = 9301;
   g_grind_long.add_pending_ticket = ticket;

   Grind_RemoveLayerAt(g_grind_long, 0);

   AssertTrue("O1 depth 0", Grind_SideDepth(g_grind_long) == 0);
   AssertTrue("O1 tracker kept", g_grind_long.add_pending_ticket == ticket);

   Grind_TestResetSideState();
}

void Test_O2_ReconcilerClearsTrackerAfterFlatUnwind()
{
   Grind_OrderTestReset();
   Grind_TestSetupLongDepth1(1.25000);
   const ulong magic = 22260101UL;
   const ulong ticket = 9302;
   g_grind_long.add_pending_ticket = ticket;
   Grind_RemoveLayerAt(g_grind_long, 0);

   Grind_TestSeedPendingAdd(ticket, magic,
                            GrindCommentBuild("OPT", "L", 1, "ENT"),
                            1.24900, (long)ORDER_TYPE_BUY_LIMIT);

   Grind_EnsureAddNext(g_grind_long, true, magic, "OPT",
                       10.0, 4.0, 12, 0.01);

   AssertTrue("O2 remove once", g_grind_order_test_remove_calls == 1);
   AssertTrue("O2 tracker cleared", g_grind_long.add_pending_ticket == 0);

   Grind_OrderTestReset();
   Grind_TestResetSideState();
}

void Test_O3_CapWarnResetOnFlatUnwind()
{
   Grind_TestResetSideState();
   ArrayResize(g_grind_long.layers, 1);
   g_grind_long.layers[0].entry_price = 1.25000;
   g_grind_long.layers[0].layer_index = 0;
   g_grind_long.layers[0].position_ticket = 1001;
   g_grind_long.cap_warn_emitted = true;

   Grind_RemoveLayerAt(g_grind_long, 0);

   AssertTrue("O3 depth 0", Grind_SideDepth(g_grind_long) == 0);
   AssertTrue("O3 cap warn reset", !g_grind_long.cap_warn_emitted);

   Grind_TestResetSideState();
}

void Grind_TestSetupLongLayers012()
{
   Grind_TestResetSideState();
   ArrayResize(g_grind_long.layers, 3);
   g_grind_long.layers[0].entry_price = 1.25000;
   g_grind_long.layers[0].layer_index = 0;
   g_grind_long.layers[0].position_ticket = 1001;
   g_grind_long.layers[1].entry_price = 1.24900;
   g_grind_long.layers[1].layer_index = 1;
   g_grind_long.layers[1].position_ticket = 1002;
   g_grind_long.layers[2].entry_price = 1.24800;
   g_grind_long.layers[2].layer_index = 2;
   g_grind_long.layers[2].position_ticket = 1003;
}

void Test_L1_FillLayerCarriesCommentIndex()
{
   Grind_TestResetSideState();
   Grind_AppendLayer(g_grind_long, 1.24700, 1003, 3, 3.0, true);
   AssertTrue("L1 one layer", Grind_SideDepth(g_grind_long) == 1);
   AssertTrue("L1 index from comment", g_grind_long.layers[0].layer_index == 3);
   Grind_TestResetSideState();
}

void Test_L2_ReconstructionCarriesCommentIndex()
{
   const ulong magic = 22260101UL;
   GrindReconTicket tickets[2];
   tickets[0].ticket = 1003;
   tickets[0].magic = magic;
   tickets[0].comment = GrindCommentBuild("OPT", "L", 3, "ENT");
   tickets[0].price = 1.24700;
   tickets[0].kind = GRIND_RECON_TICKET_POSITION;
   tickets[1].ticket = 2003;
   tickets[1].magic = magic;
   tickets[1].comment = GrindCommentBuild("OPT", "L", 3, "EXT");
   tickets[1].price = 1.24730;
   tickets[1].kind = GRIND_RECON_TICKET_ORDER;

   GrindSideState long_out;
   GrindSideState short_out;
   string reason = "";
   const bool ok = Grind_RebuildBookFromTickets(tickets, 2, magic, "OPT",
                                                3.0, 12, 0.00001,
                                                long_out, short_out, reason);
   AssertTrue("L2 ok", ok);
   if(ok)
      AssertTrue("L2 index", long_out.layers[0].layer_index == 3);
   Grind_TestResetSideState();
}

void Test_L3_RemoveMiddlePreservesIntrinsicIndices()
{
   Grind_TestSetupLongLayers012();
   Grind_RemoveLayerAt(g_grind_long, 1);
   AssertTrue("L3 count", Grind_SideDepth(g_grind_long) == 2);
   AssertTrue("L3 idx0", g_grind_long.layers[0].layer_index == 0);
   AssertTrue("L3 idx2", g_grind_long.layers[1].layer_index == 2);
   Grind_TestResetSideState();
}

void Test_L4_SideNextIndexWithGap()
{
   Grind_TestResetSideState();
   ArrayResize(g_grind_long.layers, 3);
   g_grind_long.layers[0].layer_index = 0;
   g_grind_long.layers[1].layer_index = 1;
   g_grind_long.layers[2].layer_index = 4;
   AssertTrue("L4 next", Grind_SideNextIndex(g_grind_long) == 5);
   Grind_TestResetSideState();
}

void Test_L5_SideNextIndexEmpty()
{
   Grind_TestResetSideState();
   AssertTrue("L5 empty", Grind_SideNextIndex(g_grind_long) == 0);
}

void Test_L6_CapUsesCountNotMaxIndex()
{
   Grind_TestResetSideState();
   ArrayResize(g_grind_long.layers, 3);
   g_grind_long.layers[0].layer_index = 0;
   g_grind_long.layers[1].layer_index = 1;
   g_grind_long.layers[2].layer_index = 4;
   AssertTrue("L6 count", Grind_SideDepth(g_grind_long) == 3);
   AssertTrue("L6 cap allows", Grind_CanPlaceEntryLayer(3, 5));
   Grind_TestResetSideState();
}

void Test_L7_DeepestLayerArrayIndexOutOfOrder()
{
   Grind_TestResetSideState();
   ArrayResize(g_grind_long.layers, 3);
   g_grind_long.layers[0].layer_index = 4;
   g_grind_long.layers[0].entry_price = 1.24600;
   g_grind_long.layers[1].layer_index = 0;
   g_grind_long.layers[1].entry_price = 1.25000;
   g_grind_long.layers[2].layer_index = 1;
   g_grind_long.layers[2].entry_price = 1.24900;
   AssertTrue("L7 deepest slot", Grind_FindDeepestLayerArrayIndex(g_grind_long) == 0);
   AssertNear("L7 anchor",
              Grind_ComputeAddTarget(g_grind_long, true, 10.0),
              Grind_AddTargetPrice(1.24600, 10.0, _Point, 1),
              1e-10);
   Grind_TestResetSideState();
   AssertTrue("L7 empty", Grind_FindDeepestLayerArrayIndex(g_grind_long) == -1);
}

void Test_L7b_FindLayerByIntrinsicIndex()
{
   Grind_TestResetSideState();
   ArrayResize(g_grind_long.layers, 3);
   g_grind_long.layers[0].layer_index = 4;
   g_grind_long.layers[0].position_ticket = 1004;
   g_grind_long.layers[1].layer_index = 0;
   g_grind_long.layers[1].position_ticket = 1000;
   g_grind_long.layers[2].layer_index = 1;
   g_grind_long.layers[2].position_ticket = 1001;
   AssertTrue("L7b find 0", Grind_FindLayerByIndex(g_grind_long, 0) == 1);
   AssertTrue("L7b find 4", Grind_FindLayerByIndex(g_grind_long, 4) == 0);
   AssertTrue("L7b missing", Grind_FindLayerByIndex(g_grind_long, 2) == -1);
   Grind_TestResetSideState();
}

void Grind_TestAppendReconLayerPair(GrindReconTicket &tickets[],
                                    int &count,
                                    const ulong magic,
                                    const int layer_index,
                                    const double entry_price,
                                    const double exit_price)
{
   tickets[count].ticket = (ulong)(1000 + layer_index);
   tickets[count].magic = magic;
   tickets[count].comment = GrindCommentBuild("OPT", "L", layer_index, "ENT");
   tickets[count].price = entry_price;
   tickets[count].kind = GRIND_RECON_TICKET_POSITION;
   count++;
   tickets[count].ticket = (ulong)(2000 + layer_index);
   tickets[count].magic = magic;
   tickets[count].comment = GrindCommentBuild("OPT", "L", layer_index, "EXT");
   tickets[count].price = exit_price;
   tickets[count].kind = GRIND_RECON_TICKET_ORDER;
   count++;
}

bool Grind_TestRebuildLongBook(GrindReconTicket &tickets[],
                               const int count,
                               GrindSideState &long_out,
                               string &reason,
                               const int max_layers = 12)
{
   GrindSideState short_out;
   return Grind_RebuildBookFromTickets(tickets, count, 22260101UL, "OPT",
                                       3.0, max_layers, 0.00001,
                                       long_out, short_out, reason);
}

void Test_I5a_GapIndices02Pass()
{
   const ulong magic = 22260101UL;
   GrindReconTicket tickets[4];
   int count = 0;
   Grind_TestAppendReconLayerPair(tickets, count, magic, 0, 1.25000, 1.25030);
   Grind_TestAppendReconLayerPair(tickets, count, magic, 2, 1.24800, 1.24830);
   GrindSideState long_out;
   string reason = "";
   AssertTrue("I5a ok", Grind_TestRebuildLongBook(tickets, count, long_out, reason));
   AssertTrue("I5a depth", ArraySize(long_out.layers) == 2);
}

void Test_I5b_SoleIndex3Pass()
{
   const ulong magic = 22260101UL;
   GrindReconTicket tickets[2];
   int count = 0;
   Grind_TestAppendReconLayerPair(tickets, count, magic, 3, 1.24700, 1.24730);
   GrindSideState long_out;
   string reason = "";
   AssertTrue("I5b ok", Grind_TestRebuildLongBook(tickets, count, long_out, reason));
   AssertTrue("I5b depth", ArraySize(long_out.layers) == 1);
   AssertTrue("I5b index", long_out.layers[0].layer_index == 3);
}

void Test_I5c_DuplicateIndicesFail()
{
   GrindReconLayerScratch layers[2];
   layers[0].layer_index = 1;
   layers[1].layer_index = 1;
   GrindReconLayerScratch empty[];
   string reason = "";
   AssertTrue("I5c fail",
              !Grind_ReconCheckInvariants(layers, 2, empty, 0,
                                         3.0, 0.00001, 12, reason));
   AssertEqStr("I5c reason", reason, "I5_LONG_CORRUPT_LAYER_INDICES");
}

void Test_I5d_NegativeIndexFails()
{
   GrindReconLayerScratch layers[1];
   layers[0].layer_index = -1;
   GrindReconLayerScratch empty[];
   string reason = "";
   AssertTrue("I5d fail",
              !Grind_ReconCheckInvariants(layers, 1, empty, 0,
                                         3.0, 0.00001, 12, reason));
   AssertEqStr("I5d reason", reason, "I5_LONG_CORRUPT_LAYER_INDICES");
}

void Test_I5e_HighIndicesNotBoundedByMaxLayers()
{
   const ulong magic = 22260101UL;
   GrindReconTicket tickets[4];
   int count = 0;
   Grind_TestAppendReconLayerPair(tickets, count, magic, 3, 1.24700, 1.24730);
   Grind_TestAppendReconLayerPair(tickets, count, magic, 4, 1.24600, 1.24630);
   GrindSideState long_out;
   string reason = "";
   AssertTrue("I5e 34 ok", Grind_TestRebuildLongBook(tickets, count, long_out, reason, 5));

   count = 0;
   Grind_TestAppendReconLayerPair(tickets, count, magic, 5, 1.24500, 1.24530);
   Grind_TestAppendReconLayerPair(tickets, count, magic, 6, 1.24400, 1.24430);
   AssertTrue("I5e 56 ok", Grind_TestRebuildLongBook(tickets, count, long_out, reason, 5));
}

void Test_I5f_OutOfOrderTicketProcessingPass()
{
   const ulong magic = 22260101UL;
   GrindReconTicket tickets[4];
   int count = 0;
   Grind_TestAppendReconLayerPair(tickets, count, magic, 2, 1.24800, 1.24830);
   Grind_TestAppendReconLayerPair(tickets, count, magic, 0, 1.25000, 1.25030);
   GrindSideState long_out;
   string reason = "";
   AssertTrue("I5f ok", Grind_TestRebuildLongBook(tickets, count, long_out, reason));
   AssertTrue("I5f depth", ArraySize(long_out.layers) == 2);
}

void Test_I5g_L2ReconstructionPasses()
{
   Test_L2_ReconstructionCarriesCommentIndex();
}

void Test_S1_CloseByPairEmitsOneScalpEvent()
{
   Grind_DealTestReset();
   Grind_PnlReset();
   Grind_TelemetryTestReset();
   Grind_ScalpTelemetryConfigure(true,
                                 "https://pipshed.com/api/telemetry/push",
                                 "test-key",
                                 false);
   Grind_TestSetupScalpCloseLongLayer(1001, 3002, 0, 1.25000, 1.25030);

   g_grind_deal_test_active = true;
   Grind_TestAppendDeal(9101, "#1001 by #3002", DEAL_ENTRY_OUT_BY, 0, 1001,
                        2.50, -0.30, -0.20, 1.25030);
   Grind_TestAppendDeal(9102, "#1001 by #3002", DEAL_ENTRY_OUT_BY, 0, 3002,
                        0.00, 0.00, 0.00, 1.25030);

   Grind_HandleSideDealFill(g_grind_long, true, 9101, 22260101UL, "OPT",
                            3.0, 4.0, 12, 0.01);
   Grind_HandleSideDealFill(g_grind_long, true, 9102, 22260101UL, "OPT",
                            3.0, 4.0, 12, 0.01);
   Grind_HandleSideDealFill(g_grind_short, false, 9101, 22260101UL, "OPT",
                            3.0, 4.0, 12, 0.01);
   Grind_HandleSideDealFill(g_grind_short, false, 9102, 22260101UL, "OPT",
                            3.0, 4.0, 12, 0.01);

   AssertTrue("S1 one queued", Grind_ScalpEventQueueSize() == 1);
   AssertTrue("S1 no post yet", g_grind_telemetry_test_post_calls == 0);

   Grind_DealTestReset();
   Grind_PnlReset();
   Grind_TelemetryTestReset();
   Grind_ScalpEventReset();
   Grind_TestResetSideState();
}

void Test_S1b_DealHandlerQueuesWithoutWebRequest()
{
   Grind_DealTestReset();
   Grind_TelemetryTestReset();
   g_grind_telemetry_test_active = true;
   Grind_ScalpTelemetryConfigure(true,
                                 "https://pipshed.com/api/telemetry/push",
                                 "test-key",
                                 false);
   Grind_TestSetupScalpCloseLongLayer(1001, 3002, 0, 1.25000, 1.25030);

   g_grind_deal_test_active = true;
   Grind_TestAppendDeal(9201, "#1001 by #3002", DEAL_ENTRY_OUT_BY, 0, 1001,
                        1.00, 0.0, 0.0, 1.25030);

   Grind_HandleSideDealFill(g_grind_long, true, 9201, 22260101UL, "OPT",
                            3.0, 4.0, 12, 0.01);

   AssertTrue("S1b queue grew", Grind_ScalpEventQueueSize() == 1);
   AssertTrue("S1b no send on deal path", g_grind_telemetry_test_post_calls == 0);

   Grind_DrainScalpEventQueue();
   AssertTrue("S1b queue drained", Grind_ScalpEventQueueSize() == 0);
   AssertTrue("S1b send on timer drain", g_grind_telemetry_test_post_calls == 1);

   Grind_DealTestReset();
   Grind_TelemetryTestReset();
   Grind_ScalpEventReset();
   Grind_TestResetSideState();
}

void Test_S2_ScalpPayloadNineFields()
{
   const datetime close_time = D'2026.09.06 14:30:00';
   const string payload = Grind_BuildScalpClosedPayload(
      "GRIND_GBPUSD_OPT",
      "GBPUSD",
      "LONG",
      1.25000,
      1.25030,
      2,
      3,
      2.00,
      close_time
   );

   AssertContains("S2 close_time", payload, "\"close_time\":\"2026-09-06T14:30:00Z\"");
   AssertContains("S2 instrument", payload, "\"instrument\":\"GBPUSD\"");
   AssertContains("S2 direction", payload, "\"direction\":\"LONG\"");
   AssertContains("S2 entry_price", payload, "\"entry_price\":1.25000");
   AssertContains("S2 exit_price", payload, "\"exit_price\":1.25030");
   AssertContains("S2 layer_depth", payload, "\"layer_depth\":2");
   AssertContains("S2 stack_depth", payload, "\"stack_depth\":3");
   AssertContains("S2 gross_pnl", payload, "\"gross_pnl\":2.00");
   AssertContains("S2 instance_id", payload, "\"instance_id\":\"GRIND_GBPUSD_OPT\"");
   AssertNotContains("S2 no pips", payload, "\"pips\"");
}

void Test_S3_DirectionIsEntrySide()
{
   Grind_DealTestReset();
   Grind_TestSetupScalpCloseLongLayer(1001, 3002, 0, 1.25000, 1.25030);

   g_grind_deal_test_active = true;
   Grind_TestAppendDeal(9301, "#1001 by #3002", DEAL_ENTRY_OUT_BY, 0, 1001,
                        1.00, 0.0, 0.0, 1.25030);

   Grind_HandleSideDealFill(g_grind_long, true, 9301, 22260101UL, "OPT",
                            3.0, 4.0, 12, 0.01);
   AssertContains("S3 long entry side", Grind_ScalpEventQueuePeek(), "\"direction\":\"LONG\"");

   Grind_DealTestReset();
   Grind_ScalpEventReset();
   Grind_TestResetSideState();

   ArrayResize(g_grind_short.layers, 1);
   g_grind_short.layers[0].entry_price = 1.26000;
   g_grind_short.layers[0].position_ticket = 2001;
   g_grind_short.layers[0].exit_position_ticket = 4002;
   g_grind_short.layers[0].layer_index = 0;

   g_grind_deal_test_active = true;
   Grind_TestAppendDeal(9302, "#2001 by #4002", DEAL_ENTRY_OUT_BY, 0, 2001,
                        1.00, 0.0, 0.0, 1.25970);

   Grind_HandleSideDealFill(g_grind_short, false, 9302, 22260101UL, "OPT",
                            3.0, 4.0, 12, 0.01);
   AssertContains("S3 short entry side", Grind_ScalpEventQueuePeek(), "\"direction\":\"SHORT\"");

   Grind_DealTestReset();
   Grind_ScalpEventReset();
   Grind_TestResetSideState();
}

void Test_S4_LayerDepthUsesIntrinsicIndex()
{
   Grind_DealTestReset();
   Grind_TestResetSideState();
   ArrayResize(g_grind_long.layers, 2);
   g_grind_long.layers[0].entry_price = 1.25000;
   g_grind_long.layers[0].position_ticket = 1001;
   g_grind_long.layers[0].exit_position_ticket = 0;
   g_grind_long.layers[0].layer_index = 0;
   g_grind_long.layers[1].entry_price = 1.24800;
   g_grind_long.layers[1].position_ticket = 1003;
   g_grind_long.layers[1].exit_position_ticket = 3004;
   g_grind_long.layers[1].layer_index = 2;

   g_grind_deal_test_active = true;
   Grind_TestAppendDeal(9401, "#1003 by #3004", DEAL_ENTRY_OUT_BY, 0, 1003,
                        1.00, 0.0, 0.0, 1.24830);

   Grind_HandleSideDealFill(g_grind_long, true, 9401, 22260101UL, "OPT",
                            3.0, 4.0, 12, 0.01);
   AssertContains("S4 intrinsic layer_depth", Grind_ScalpEventQueuePeek(), "\"layer_depth\":2");
   AssertContains("S4 stack before removal", Grind_ScalpEventQueuePeek(), "\"stack_depth\":2");

   Grind_DealTestReset();
   Grind_ScalpEventReset();
   Grind_TestResetSideState();
}

void Test_S5_FailedPostDoesNotBlockScalpAccounting()
{
   Grind_DealTestReset();
   Grind_PnlReset();
   Grind_TelemetryTestReset();
   g_grind_telemetry_test_active = true;
   g_grind_telemetry_test_force_fail = true;
   Grind_ScalpTelemetryConfigure(true,
                                 "https://pipshed.com/api/telemetry/push",
                                 "test-key",
                                 false);
   Grind_TestSetupScalpCloseLongLayer(1001, 3002, 0, 1.25000, 1.25030);

   g_grind_pnl_test_active = true;
   g_grind_pnl_test_server_time = D'2026.09.06 12:00:00';
   g_grind_deal_test_active = true;
   Grind_TestAppendDeal(9501, "#1001 by #3002", DEAL_ENTRY_OUT_BY, 0, 1001,
                        2.50, -0.30, -0.20, 1.25030);

   const int scalps_before = g_grind_scalp_count;
   Grind_HandleSideDealFill(g_grind_long, true, 9501, 22260101UL, "OPT",
                            3.0, 4.0, 12, 0.01);
   AssertTrue("S5 scalp incremented", g_grind_scalp_count == scalps_before + 1);
   AssertNear("S5 realised pnl kept", g_grind_realised_pnl_today, 2.00, 1e-8);
   AssertTrue("S5 event queued", Grind_ScalpEventQueueSize() == 1);

   Grind_DrainScalpEventQueue();
   AssertTrue("S5 failed post logged not thrown", g_grind_telemetry_test_post_calls == 1);
   AssertTrue("S5 not halted", !g_grind_halted);

   Grind_DealTestReset();
   Grind_PnlReset();
   Grind_TelemetryTestReset();
   Grind_ScalpEventReset();
   Grind_TestResetSideState();
}

void Test_S6_GrossPnlMatchesRealisedPnlToday()
{
   Grind_DealTestReset();
   Grind_PnlReset();
   Grind_TestSetupScalpCloseLongLayer(1001, 3002, 0, 1.25000, 1.25030);

   g_grind_pnl_test_active = true;
   g_grind_pnl_test_server_time = D'2026.09.06 12:00:00';
   g_grind_deal_test_active = true;
   Grind_TestAppendDeal(9601, "#1001 by #3002", DEAL_ENTRY_OUT_BY, 0, 1001,
                        2.50, -0.30, -0.20, 1.25030);

   Grind_HandleSideDealFill(g_grind_long, true, 9601, 22260101UL, "OPT",
                            3.0, 4.0, 12, 0.01);

   AssertContains("S6 gross_pnl net", Grind_ScalpEventQueuePeek(), "\"gross_pnl\":2.00");
   AssertNear("S6 matches realised", g_grind_realised_pnl_today, 2.00, 1e-8);

   Grind_DealTestReset();
   Grind_PnlReset();
   Grind_ScalpEventReset();
   Grind_TestResetSideState();
}

void OnStart()
{
   Test_SuiteCleanupMagicLocks();
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
   Test_T10_EmptyBookReconOk();
   Test_T11_PoisonedDefaults();
   Test_T12_UnconfiguredAddPips();
   Test_T13_LongAddTarget();
   Test_T14_ShortAddTarget();
   Test_T15_IdenticalSpacingAtDepth();
   Test_T16_SimulatorParity();
   Test_T17_AddWidthRelationship();
   Test_T18_EmptyBookGenesis();
   Test_T19b_SingleLayerAppend();
   Test_T19c_AppendUpToMaxLayersParallel();
   Test_T19_ThreeLongLayersRebuild();
   Test_T20_UnparseableCommentHalts();
   Test_T21_NeighbourMagicIgnored();
   Test_T22_NakedPositionHalts();
   Test_T23_OrphanExitHalts();
   Test_T24_GapIndicesRebuild();
   Test_T25_ContaminatedCommentRebuilds();
   Test_C1_CasLockAcquireWhenAbsent();
   Test_C2_CasLockAcquireWhenZero();
   Test_C3_CasLockHeldTimesOutWithoutReset();
   Test_C4_CasLockAcquireReleaseLeavesZero();
   Test_C5_CasLockDoubleAcquireFails();
   Test_C6_CasLockTempPreservesHeldValue();
   Test_T26_CasSpinlockTimeout();
   Test_T27_MissingPeerReadsAsMaxed();
   Test_T28_StalePeerBoundary();
   Test_T28b_MissingTimestampMaxed();
   Test_T29_CapBlocksNewEntry();
   Test_T30_CapDoesNotBlockNonEntry();
   Test_T31_ThresholdZeroOffStillPublishes();
   Test_T32_DuplicateMagicFails();
   Test_T33_FreeMagicClaimSucceeds();
   Test_T34_ReleaseAllowsReclaim();
   Test_T35_ConfigDumpCoversAllInputs();
   Test_T36_TelemetryWebPostEmptyGate();
   Test_T37_ConfigDumpKeyNotLeaked();
   Test_T38_HeartbeatSchemaUnchanged();
   Test_T39_ConfigDumpTwentyInputs();
   Test_T40_NetMtmExactMagic();
   Test_T41_RealisedPnlNetAccumulation();
   Test_T42_DailyResetFollowsServerTime();
   Test_T43_TouchRevertThreshold();
   Test_T44_HeartbeatSchemaAppendOnly();
   Test_D1_ThreeLayersEmitDetail();
   Test_D2_NonContiguousLayerIndices();
   Test_D3_EmptySideEmitsEmptyArray();
   Test_D4_PendingLevelsNullWhenAbsent();
   Test_D5_NoTicketNumbersInJson();
   Test_D6_InstanceIdFirstSchemaAppendOnly();
   Test_D7_WorstCasePayloadMeasured();
   Test_D8_RestingEntriesFromBrokerEnumeration();
   Test_D9_PricesUseDoubleToString();
   Test_T45_ExitFillQueuesCloseByPair();
   Test_T46_CloseBySuccessRemovesTaskAndIncrementsScalpOnce();
   Test_T46b_OutByDealAccumulatesRealisedPnl();
   Test_T46c_ExitInDoesNotCountScalpOrPnl();
   Test_T47_CloseByExhaustionHaltsCritical();
   Test_T48_BackwardIterationProcessesAllThree();
   Test_T49_InvariantRestingExtOrderPasses();
   Test_T50_InvariantOpenExtPositionPasses();
   Test_T51_InvariantNeitherExitStillHalts();
   Test_T52_InvariantExtPositionWithEntNotOrphan();
   Test_T53_ReconDerivesCloseByPair();
   Test_T54_RestingExtOrderQueuesNothing();
   Test_T55_TwoPendingClosePairsQueueTwoTasks();
   Test_T56_InvariantFailQueuesNothing();
   Test_T57_QueueCloseByIdempotent();
   Test_T57b_RestartSequenceSingleTask();
   Test_T58_EmptyBookQueuesNothing();
   Test_OrderBudgetArithmetic();
   Test_A1_StaleLabelDeletesNoPlaceSameTick();
   Test_A2_MatchingLabelDeadbandUnchanged();
   Test_A3_NextTickPlacesFreshAdd();
   Test_A4_UnparseableCommentRemoved();
   Test_A4b_FailedRemovalKeepsTicket();
   Test_A5_PlacementGuardHaltsInPlace();
   Test_A6_StaleIndexAdoptedNotInvariant();
   Test_A7_InvariantMatchingPendingAddPasses();
   Test_A8_ObservedFailureReproAndFix();
   Test_N1_DepthZeroStaleLabelPassesInvariant();
   Test_N2_PendingAddWrongKindFailsI8();
   Test_N3_DuplicateRestingAddFailsAmbiguous();
   Test_N4_ReconstructionAdoptsMismatchedTicket();
   Test_N5_AdoptedStaleRemovedByReconciler();
   Test_M1_DepthZeroStaleAddRemoved();
   Test_M2_DepthZeroNoPendingNoOp();
   Test_M3_CapBlockedStillRemovesStaleAdd();
   Test_M4_LayerCapReachedStillRemovesStaleAdd();
   Test_M5_MatchingLabelAtDepthOneUnchanged();
   Test_O1_UnwindToFlatKeepsAddPendingTracker();
   Test_O2_ReconcilerClearsTrackerAfterFlatUnwind();
   Test_O3_CapWarnResetOnFlatUnwind();
   Test_L1_FillLayerCarriesCommentIndex();
   Test_L2_ReconstructionCarriesCommentIndex();
   Test_L3_RemoveMiddlePreservesIntrinsicIndices();
   Test_L4_SideNextIndexWithGap();
   Test_L5_SideNextIndexEmpty();
   Test_L6_CapUsesCountNotMaxIndex();
   Test_L7_DeepestLayerArrayIndexOutOfOrder();
   Test_L7b_FindLayerByIntrinsicIndex();
   Test_I5a_GapIndices02Pass();
   Test_I5b_SoleIndex3Pass();
   Test_I5c_DuplicateIndicesFail();
   Test_I5d_NegativeIndexFails();
   Test_I5e_HighIndicesNotBoundedByMaxLayers();
   Test_I5f_OutOfOrderTicketProcessingPass();
   Test_I5g_L2ReconstructionPasses();
   Test_S1_CloseByPairEmitsOneScalpEvent();
   Test_S1b_DealHandlerQueuesWithoutWebRequest();
   Test_S2_ScalpPayloadNineFields();
   Test_S3_DirectionIsEntrySide();
   Test_S4_LayerDepthUsesIntrinsicIndex();
   Test_S5_FailedPostDoesNotBlockScalpAccounting();
   Test_S6_GrossPnlMatchesRealisedPnlToday();
   Test_R1_LayerCommentRawFromBroker();
   Test_R2_PendingCommentsNullWhenAbsent();
   Test_R3_NoTicketsInCommentHeartbeatJson();
   Test_R4_WorstCaseCommentsTriggerJournalSplit();
   Test_R4b_FailedPositionSelectEmitsNullComment();
   Test_F1_I3RejectionEmitsReconFailureWithAllTickets();
   Test_F2_MorningFailureScenario();
   Test_F3_SuccessClearsReconFailure();
   Test_F3b_FailThenSuccessClearsGlobal();
   Test_F3c_CaptureSurvivesSeparateHeartbeat();
   Test_F4_NoTicketNumbersInJson();
   Test_F5_UnparseableCommentVerbatimSideHintNull();
   Test_F6_TruncationAtFortyPlusTickets();
   Test_F7_WorstCaseSizeMeasured();
   Test_AccFigA1_DesignatedEmitsBalanceEquity();
   Test_AccFigA2_ExactlyOneLeaseHolder();
   Test_AccFigA2b_LeaseTakeoverAfterStale();
   Test_AccFigA2c_FreshLeaseForcesNull();
   Test_AccFigA3_EquityLowTracksDownOnly();
   Test_AccFigA4_DayKeyRollsOnServerTime();
   Test_AccFigA5_ReloadPreservesEquityLow();
   Test_AccFigA6_DistToFloorMatchesV2Logic();
   Print("SUMMARY: ", g_tests_passed, "/", g_tests_run, " passed");
}
