//+------------------------------------------------------------------+
//| fxgrind_tests.mq5 — unit tests for fxgrind Spec A/B (T1–T58, A1–A8, N1–N6, M1–M5) |
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

void Test_T24_NonContiguousLayersHalts()
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
   AssertTrue("T24 halt", !Grind_RebuildBookFromTickets(tickets, 6, magic, "OPT",
                                                        3.0, 12, 0.00001,
                                                        long_out, short_out, reason));
   AssertTrue("T24 I5", StringFind(reason, "I5") >= 0);
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

void Test_T26_CasSpinlockTimeout()
{
   GlobalVariableSet(GRIND_CAP_LOCK_GV, 1.0);
   g_grind_cap_test_lock_held = true;
   AssertTrue("T26 timeout", !Grind_CapTryAcquireLock(GRIND_CAP_CAS_MAX_RETRIES));
   g_grind_cap_test_lock_held = false;
   GlobalVariableDel(GRIND_CAP_LOCK_GV);
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
   Grind_PnlReset();
}

void Grind_TestAppendDeal(const ulong deal_ticket,
                          const string comment,
                          const long entry_type,
                          const ulong order_ticket,
                          const ulong position_id,
                          const double profit,
                          const double swap,
                          const double commission)
{
   ArrayResize(g_grind_deal_test_records, g_grind_deal_test_count + 1);
   g_grind_deal_test_records[g_grind_deal_test_count].deal_ticket = deal_ticket;
   g_grind_deal_test_records[g_grind_deal_test_count].symbol = _Symbol;
   g_grind_deal_test_records[g_grind_deal_test_count].magic = (long)22260101UL;
   g_grind_deal_test_records[g_grind_deal_test_count].comment = comment;
   g_grind_deal_test_records[g_grind_deal_test_count].entry_type = entry_type;
   g_grind_deal_test_records[g_grind_deal_test_count].order_ticket = order_ticket;
   g_grind_deal_test_records[g_grind_deal_test_count].position_id = position_id;
   g_grind_deal_test_records[g_grind_deal_test_count].price = 1.25030;
   g_grind_deal_test_records[g_grind_deal_test_count].profit = profit;
   g_grind_deal_test_records[g_grind_deal_test_count].swap = swap;
   g_grind_deal_test_records[g_grind_deal_test_count].commission = commission;
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
   Test_T24_NonContiguousLayersHalts();
   Test_T25_ContaminatedCommentRebuilds();
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
   Test_N2_UnparseablePendingAddFailsInvariant();
   Test_N3_DuplicateRestingAddFailsAmbiguous();
   Test_N4_ReconstructionAdoptsMismatchedTicket();
   Test_N5_AdoptedStaleRemovedByReconciler();
   Test_M1_DepthZeroStaleAddRemoved();
   Test_M2_DepthZeroNoPendingNoOp();
   Test_M3_CapBlockedStillRemovesStaleAdd();
   Test_M4_LayerCapReachedStillRemovesStaleAdd();
   Test_M5_MatchingLabelAtDepthOneUnchanged();
   Print("SUMMARY: ", g_tests_passed, "/", g_tests_run, " passed");
}
