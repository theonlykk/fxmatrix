//+------------------------------------------------------------------+
//| fxgrind_tests_adr162.mqh — ADR-162 phase A unit tests (VL1–VL16) |
//+------------------------------------------------------------------+
#ifndef FXGRIND_TESTS_ADR162_MQH
#define FXGRIND_TESTS_ADR162_MQH

#include "grind_exitq.mqh"
#include "grind_comment.mqh"

//+------------------------------------------------------------------+
void Test_VL1_GvRoundTrip()
{
   Grind_TestClearCarryState();
   const ulong ticket = 1001UL;
   AssertFalse("VL1 absent", Grind_VLHas(ticket));
   AssertEqStr("VL1 name", Grind_VLName(ticket), "GRIND_VL_1001");
   g_grind_gv_dirty = false;
   Grind_VLSet(ticket, 1.10000);
   AssertTrue("VL1 has", Grind_VLHas(ticket));
   AssertNear("VL1 get", Grind_VLGet(ticket), 1.10000, 1e-9);
   AssertTrue("VL1 gv literal", GlobalVariableCheck("GRIND_VL_1001"));
   AssertTrue("VL1 dirty", g_grind_gv_dirty);
   Grind_VLDelete(ticket);
   AssertFalse("VL1 gone", GlobalVariableCheck("GRIND_VL_1001"));
}

//+------------------------------------------------------------------+
void Test_VL2_EffectiveEntry()
{
   Grind_TestClearCarryState();
   const ulong ticket = 1001UL;
   AssertNear("VL2 unrolled", Grind_EffectiveEntry(1.10500, ticket), 1.10500, 1e-9);
   Grind_VLSet(ticket, 1.10000);
   AssertNear("VL2 rolled", Grind_EffectiveEntry(1.10500, ticket), 1.10000, 1e-9);
   AssertNear("VL2 other ticket", Grind_EffectiveEntry(1.10400, 1002UL), 1.10400, 1e-9);
   GlobalVariableSet("GRIND_VL_0", 1.0);
   AssertNear("VL2 ticket 0", Grind_EffectiveEntry(1.10500, 0), 1.10500, 1e-9);
   GlobalVariableDel("GRIND_VL_0");
}

//+------------------------------------------------------------------+
void Test_VL3_FormulaTargetRolled()
{
   Grind_TestClearCarryState();
   const double point = 0.00001;
   const double exit_pips = 3.0;
   Grind_VLSet(1001UL, 1.10000);
   AssertNear("VL3 long",
              Grind_ExitQFormulaTarget(1.10500, exit_pips, point, true, 1001UL),
              1.10030, 1e-9);
   Grind_VLSet(1002UL, 1.11000);
   AssertNear("VL3 short",
              Grind_ExitQFormulaTarget(1.10500, exit_pips, point, false, 1002UL),
              1.10970, 1e-9);
   AssertNear("VL3 unrolled",
              Grind_ExitQFormulaTarget(1.10500, exit_pips, point, true, 1003UL),
              1.10530, 1e-9);
}

//+------------------------------------------------------------------+
void Test_VL4_FormulaTargetRolledAccrued()
{
   Grind_TestClearCarryState();
   const double point = 0.00001;
   const double exit_pips = 3.0;
   const ulong ticket = 1001UL;
   Grind_VLSet(ticket, 1.10000);
   Grind_CarryAccruedSet(ticket, 0.00010);
   AssertNear("VL4 target",
              Grind_ExitQFormulaTarget(1.10500, exit_pips, point, true, ticket),
              1.10040, 1e-9);
}

//+------------------------------------------------------------------+
void Test_VL5_I6AcceptsRolledExit()
{
   Grind_TestClearCarryState();
   const double point = 0.00001;
   const double exit_pips = 3.0;
   const ulong ticket = 1001UL;
   Grind_VLSet(ticket, 1.10000);
   AssertTrue("VL5 rolled ok",
              Grind_ReconExitMatchesEntry(1.10500, 1.10030, exit_pips, point, true, 0.0, false, ticket));
   AssertFalse("VL5 actual rejected",
               Grind_ReconExitMatchesEntry(1.10500, 1.10530, exit_pips, point, true, 0.0, false, ticket));
   Grind_VLDelete(ticket);
   AssertFalse("VL5 no vl",
               Grind_ReconExitMatchesEntry(1.10500, 1.10030, exit_pips, point, true, 0.0, false, ticket));
}

//+------------------------------------------------------------------+
void Test_VL6_I6DetailExpected()
{
   Grind_TestClearCarryState();
   const ulong ticket = 1001UL;
   const double exit_pips = 3.0;
   const double point = 0.00001;
   Grind_VLSet(ticket, 1.10000);
   GrindReconLayerScratch layer;
   Grind_TestInitLayerScratch(layer, 0, 1.10500, ticket);
   layer.has_exit_order = true;
   layer.exit_order_ticket = 2001;
   layer.exit_target = 1.10030;
   const string detail = Grind_InvariantDetailI6(layer, true, exit_pips, point, 0.0);
   AssertContains("VL6 expected", detail, "\"expected\":1.10030");
   AssertContains("VL6 entry actual", detail, "\"entry\":1.10500");
}

//+------------------------------------------------------------------+
void Test_VL7_QueueRanksByEffective()
{
   Grind_OrderTestReset();
   Grind_TestResetSideState();
   Grind_CarryTestReset();
   g_grind_order_test_active = true;
   Adr151_TestSeedSlotSeams(200, 100, 0);
   Grind_MarketTestSeed(1.09998, 1.10000, 0, 0);
   ArrayResize(g_grind_long.layers, 4);
   Adr151_TestSetupLongLayer(g_grind_long, 0, 0, 1.10500, 5301UL, 0);
   Adr151_TestSetupLongLayer(g_grind_long, 1, 1, 1.10400, 5302UL, 0);
   Adr151_TestSetupLongLayer(g_grind_long, 2, 2, 1.10300, 5303UL, 0);
   Adr151_TestSetupLongLayer(g_grind_long, 3, 3, 1.10200, 5304UL, 0);
   Grind_VLSet(5301UL, 1.10000);
   Grind_ExitQManageSide(g_grind_long, true, 22260101UL, "OPT", 0.01, 3.0);
   AssertTrue("VL7 two resting", Adr151_TestCountRestingExits(g_grind_long) == 2);
   AssertTrue("VL7 rolled L0 rests", g_grind_long.layers[0].exit_order_ticket != 0);
   AssertTrue("VL7 oldest unrolled L1 rests", g_grind_long.layers[1].exit_order_ticket != 0);
   AssertTrue("VL7 deepest real L3 bare", g_grind_long.layers[3].exit_order_ticket == 0);
   AssertNear("VL7 rolled exit price", g_grind_long.layers[0].exit_target, 1.10030, 1e-9);
   Grind_MarketTestReset();
   Grind_OrderTestReset();
   Grind_TestResetSideState();
   Grind_CarryTestReset();
   Adr151_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_VL8_RebuildRolledBook()
{
   Grind_ReconFailureClear();
   Grind_TestClearCarryState();
   const ulong magic = 22260101UL;
   const double point = 0.00001;
   const double exit_pips = 3.0;
   Grind_VLSet(1001UL, 1.10000);
   GrindReconTicket tickets[6];
   tickets[0].ticket = 1001; tickets[0].magic = magic;
   tickets[0].comment = GrindCommentBuild("OPT", "L", 0, "ENT");
   tickets[0].price = 1.10500; tickets[0].kind = GRIND_RECON_TICKET_POSITION;
   tickets[1].ticket = 2001; tickets[1].magic = magic;
   tickets[1].comment = GrindCommentBuild("OPT", "L", 0, "EXT");
   tickets[1].price = 1.10030; tickets[1].kind = GRIND_RECON_TICKET_ORDER;
   tickets[2].ticket = 1002; tickets[2].magic = magic;
   tickets[2].comment = GrindCommentBuild("OPT", "L", 1, "ENT");
   tickets[2].price = 1.10400; tickets[2].kind = GRIND_RECON_TICKET_POSITION;
   tickets[3].ticket = 2002; tickets[3].magic = magic;
   tickets[3].comment = GrindCommentBuild("OPT", "L", 1, "EXT");
   tickets[3].price = 1.10430; tickets[3].kind = GRIND_RECON_TICKET_ORDER;
   tickets[4].ticket = 1003; tickets[4].magic = magic;
   tickets[4].comment = GrindCommentBuild("OPT", "L", 2, "ENT");
   tickets[4].price = 1.10300; tickets[4].kind = GRIND_RECON_TICKET_POSITION;
   tickets[5].ticket = 1004; tickets[5].magic = magic;
   tickets[5].comment = GrindCommentBuild("OPT", "L", 3, "ENT");
   tickets[5].price = 1.10200; tickets[5].kind = GRIND_RECON_TICKET_POSITION;
   GrindSideState long_out;
   GrindSideState short_out;
   string reason = "";
   AssertTrue("VL8 with vl",
              Grind_RebuildBookFromTickets(tickets, 6, magic, "OPT", exit_pips, 12, point,
                                           long_out, short_out, reason));
   Grind_VLDelete(1001UL);
   AssertFalse("VL8 without vl",
               Grind_RebuildBookFromTickets(tickets, 6, magic, "OPT", exit_pips, 12, point,
                                            long_out, short_out, reason));
   Grind_ReconFailureClear();
}

//+------------------------------------------------------------------+
void Adr162_TestSeedVL9LongBook(GrindSideState &side)
{
   ArrayResize(side.layers, 7);
   Adr151_TestSetupLongLayer(side, 0, 0, 1.21400, 9001UL, 0, 3.0);
   Adr151_TestSetupLongLayer(side, 1, 1, 1.21300, 9002UL, 0, 3.0);
   Adr151_TestSetupLongLayer(side, 2, 2, 1.21200, 9003UL, 0, 3.0);
   Adr151_TestSetupLongLayer(side, 3, 3, 1.21100, 9004UL, 0, 3.0);
   Adr151_TestSetupLongLayer(side, 4, 5, 1.20900, 9005UL, 0, 3.0);
   Adr151_TestSetupLongLayer(side, 5, 6, 1.20800, 9006UL, 0, 3.0);
   Adr151_TestSetupLongLayer(side, 6, 7, 1.20700, 9007UL, 0, 3.0);
}

//+------------------------------------------------------------------+
void Test_VL9_AddAnchor()
{
   Grind_TestResetSideState();
   Adr162_TestSeedVL9LongBook(g_grind_long);
   Grind_VLSet(9001UL, 1.20600);
   Grind_VLSet(9002UL, 1.20500);
   Grind_VLSet(9003UL, 1.20400);
   Grind_VLSet(9004UL, 1.20300);
   AssertNear("VL9 s3 re-add", Grind_ComputeAddTarget(g_grind_long, true, 10.0), 1.20200, 1e-9);
   Grind_VLDelete(9001UL);
   Grind_VLDelete(9002UL);
   Grind_VLDelete(9003UL);
   Grind_VLDelete(9004UL);
   AssertNear("VL9 unrolled", Grind_ComputeAddTarget(g_grind_long, true, 10.0), 1.20600, 1e-9);
   Grind_TestResetSideState();
   ArrayResize(g_grind_long.layers, 3);
   Adr151_TestSetupLongLayer(g_grind_long, 0, 0, 1.10500, 9101UL, 0, 3.0);
   Adr151_TestSetupLongLayer(g_grind_long, 1, 1, 1.10300, 9102UL, 0, 3.0);
   Adr151_TestSetupLongLayer(g_grind_long, 2, 2, 1.10400, 9103UL, 0, 3.0);
   AssertNear("VL9 index anchor kept", Grind_ComputeAddTarget(g_grind_long, true, 10.0), 1.10300, 1e-9);
   Grind_TestResetSideState();
}

//+------------------------------------------------------------------+
void Test_VL10_CarryPassBaseRolled()
{
   Grind_TestClearCarryState();
   Grind_TestResetSideState();
   ArrayResize(g_grind_long.layers, 1);
   g_grind_long.layers[0].entry_price = 1.10500;
   g_grind_long.layers[0].position_ticket = 1001UL;
   g_grind_long.layers[0].exit_order_ticket = 2001UL;
   g_grind_long.layers[0].layer_index = 0;
   Grind_VLSet(1001UL, 1.10000);
   Grind_CarryExitPassBegin(_Symbol, 22260101UL, 3.0);
   AssertTrue("VL10 one work item", g_grind_carry_exit_work_count == 1);
   AssertNear("VL10 base", g_grind_carry_exit_work_formula[0], 1.10030, 1e-9);
   Grind_CarryExitPassReset();
   Grind_TestResetSideState();
}

//+------------------------------------------------------------------+
void Test_VL11_SignGuardEffective()
{
   Grind_TestClearCarryState();
   const ulong ticket = 1001UL;
   Grind_VLSet(ticket, 1.10000);
   AssertFalse("VL11 rolled not blocked",
               Grind_CarrySignGuardAppliesAtShift(ticket, 1.10500, 1.10030, true));
   AssertTrue("VL11 rolled below vl blocked",
              Grind_CarrySignGuardAppliesAtShift(ticket, 1.10500, 1.09990, true));
   AssertTrue("VL11 ordinary blocked",
              Grind_CarrySignGuardAppliesAtShift(1002UL, 1.10500, 1.10030, true));
}

//+------------------------------------------------------------------+
void Test_VL12_PruneOrphanVL()
{
   Grind_TestClearCarryState();
   g_grind_order_test_active = true;
   GlobalVariableSet("GRIND_VL_8888", 1.10000);
   Grind_CarryPruneShiftGvs(22260101UL);
   AssertFalse("VL12 orphan pruned", GlobalVariableCheck("GRIND_VL_8888"));
   g_grind_order_test_active = false;
}

//+------------------------------------------------------------------+
void Test_VL13_CloseDeletesVL()
{
   Grind_DealTestReset();
   Grind_TestResetSideState();
   const ulong pos = 99207UL;
   const ulong exit_pos = 99217UL;
   F2_TestClearPositionCarry(pos);
   GlobalVariableSet("GRIND_VL_99207", 1.10000);
   ArrayResize(g_grind_long.layers, 1);
   g_grind_long.layers[0].entry_price = 1.25000;
   g_grind_long.layers[0].position_ticket = pos;
   g_grind_long.layers[0].exit_position_ticket = exit_pos;
   g_grind_long.layers[0].layer_index = 0;
   g_grind_deal_test_active = true;
   Grind_TestAppendDeal(99207UL, "#99207 by #99217", DEAL_ENTRY_OUT_BY, 0, pos, 2.50, -0.30, -0.20);
   Grind_HandleSideDealFill(g_grind_long, true, 99207UL, 22260101UL, "OPT", 3.0, 4.0, 12, 0.01);
   AssertFalse("VL13 vl gone", GlobalVariableCheck("GRIND_VL_99207"));
   Grind_DealTestReset();
   Grind_TestResetSideState();
   Adr151_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_VL14_HeartbeatVirtualLevel()
{
   Grind_TestResetLayerDetailState();
   const ulong magic = 22260101UL;
   const int digits = 5;
   ArrayResize(g_grind_long.layers, 1);
   g_grind_long.layers[0].layer_index = 0;
   g_grind_long.layers[0].entry_price = 1.25010;
   g_grind_long.layers[0].exit_target = 1.25060;
   g_grind_long.layers[0].position_ticket = 8000UL;
   g_grind_long.layers[0].exit_order_ticket = 1;
   g_grind_long.layers[0].exit_position_ticket = 0;
   g_grind_heartbeat_test_active = true;
   Grind_HeartbeatTestUpsertPosition(8000UL, (long)magic, GrindCommentBuild("OPT", "L", 0, "ENT"));
   string layers_json = Grind_HeartbeatLayersJson(magic, digits);
   AssertNotContains("VL14 absent when unrolled", layers_json, "virtual_level");
   GlobalVariableSet("GRIND_VL_8000", 1.24000);
   layers_json = Grind_HeartbeatLayersJson(magic, digits);
   AssertContains("VL14 present", layers_json, "\"virtual_level\":1.24000");
   int count = 0;
   int pos = 0;
   while(true) {
      const int found = StringFind(layers_json, "virtual_level", pos);
      if(found < 0)
         break;
      count++;
      pos = found + 1;
   }
   AssertTrue("VL14 once", count == 1);
   GlobalVariableDel("GRIND_VL_8000");
   Grind_TestResetLayerDetailState();
}

//+------------------------------------------------------------------+
void Test_VL15_EjectRolledOffset()
{
   Grind_TestEjectHarnessReset();
   const ulong magic = 22260101UL;
   g_grind_order_test_active = true;
   g_grind_order_test_send_ok = true;
   ArrayResize(g_grind_long.layers, 1);
   g_grind_long.layers[0].entry_price = 1.10500;
   g_grind_long.layers[0].position_ticket = 1001UL;
   g_grind_long.layers[0].exit_order_ticket = 2001UL;
   g_grind_long.layers[0].exit_target = 1.10530;
   g_grind_long.layers[0].layer_index = 0;
   Grind_OrderTestUpsert(2001UL, (long)magic,
                         GrindCommentBuild("OPT", "L", 0, "EXT"),
                         1.10530, (long)ORDER_TYPE_SELL_LIMIT);
   Grind_MarketTestSeed(1.24800, 1.24810, 0, 0);
   Grind_VLSet(1001UL, 1.10000);
   const int rc = Grind_EjectAcceptLayer(true, 0, magic, 3.0, "TEST");
   AssertEqInt("VL15 accept", rc, GRIND_EJECT_OK);
   const double T = Grind_OrderGetPriceOpen(2001UL);
   AssertNear("VL15 offset", Grind_EjectOffsetGet(1001UL), T - 1.10030, 1e-9);
   Grind_TestEjectHarnessReset();
}

//+------------------------------------------------------------------+
void Test_VL16_ParseL100()
{
   string slot, side, role;
   int layer = -1;
   AssertTrue("VL16 parses", GrindCommentParse("GRIND|OPT|L|L100|EXT", slot, side, layer, role));
   AssertEqInt("VL16 index", layer, 100);
}

#endif // FXGRIND_TESTS_ADR162_MQH
