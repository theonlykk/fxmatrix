//+------------------------------------------------------------------+
//| fxgrind_tests.mq5 — unit tests for fxgrind Spec A/B (T1–T44)    |
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

void Test_OrderBudgetArithmetic()
{
   AssertTrue("budget 12 side", Grind_RestingOrderBudgetPerSide(12) == 13);
   AssertTrue("budget inst", Grind_RestingOrderBudgetInstance(12, 12) == 26);
   AssertTrue("budget eurgbp", Grind_RestingOrderBudgetInstance(8, 8) == 18);
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
   Test_OrderBudgetArithmetic();
   Print("SUMMARY: ", g_tests_passed, "/", g_tests_run, " passed");
}
