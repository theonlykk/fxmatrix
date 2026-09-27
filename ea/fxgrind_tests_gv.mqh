//+------------------------------------------------------------------+
//| fxgrind_tests_gv.mqh — grind v2.0 per-side geometry (C47)      |
//+------------------------------------------------------------------+
#ifndef FXGRIND_TESTS_GV_MQH
#define FXGRIND_TESTS_GV_MQH

const ulong  GV_MAGIC = 22260101UL;
const datetime GV_T0    = D'2026.09.28 10:00';

//+------------------------------------------------------------------+
void GV_RestoreEngineGlobals(const double saved_add, const double saved_recon)
{
   g_grind_engine_add_pips = saved_add;
   g_grind_recon_exit_pips = saved_recon;
   g_grind_engine_add_pips_short = 0.0;
   g_grind_recon_exit_pips_short = 0.0;
}

//+------------------------------------------------------------------+
void GV_SeedShort8CarryPerSide(const double bid, const double ask)
{
   Grind_CarryTestReset();
   Adr162b_SeedShort8();
   F2_TestSeedCarryWindow(GV_MAGIC);
   Grind_CarryTestSeedTick(g_grind_carry_test_server_time, bid, ask);
   for(int i = 0; i < ArraySize(g_grind_short.layers); i++) {
      const ulong pos = g_grind_short.layers[i].position_ticket;
      if(pos == 0)
         continue;
      Grind_CarryTestSetPosition(pos, -0.10, 0.01, D'2026.09.01 12:00');
      Grind_PositionTestAdd(pos);
   }
   Grind_MarketTestSeed(bid, ask, 0, 0);
   g_grind_carry_eligible_magic = GV_MAGIC;
   Grind_CarryExitPassBegin(_Symbol, GV_MAGIC, 9.0, 5.0);
}

//+------------------------------------------------------------------+
void GV_FinishCarryPassPerSide()
{
   for(int i = 0; i < 10 && g_grind_carry_exit_pass_active; i++)
      Grind_CarryExitPassStep(_Symbol, GV_MAGIC, 9.0, g_grind_carry_test_server_time, 5.0);
}

//+------------------------------------------------------------------+
void GV_EjectFixtureShortDepth2()
{
   g_grind_order_test_active = true;
   g_grind_order_test_send_ok = true;
   ArrayResize(g_grind_short.layers, 2);
   g_grind_short.layers[0].entry_price = 1.24800;
   g_grind_short.layers[0].position_ticket = 1101UL;
   g_grind_short.layers[0].exit_order_ticket = 2101UL;
   g_grind_short.layers[0].exit_target = 1.24730;
   g_grind_short.layers[0].layer_index = 0;
   g_grind_short.layers[1].entry_price = 1.24900;
   g_grind_short.layers[1].position_ticket = 1102UL;
   g_grind_short.layers[1].exit_order_ticket = 2102UL;
   g_grind_short.layers[1].exit_target = 1.24830;
   g_grind_short.layers[1].layer_index = 1;
   Grind_OrderTestUpsert(2101UL, (long)GV_MAGIC,
                         GrindCommentBuild("OPT", "S", 0, "EXT"),
                         1.24730, (long)ORDER_TYPE_BUY_LIMIT);
   Grind_OrderTestUpsert(2102UL, (long)GV_MAGIC,
                         GrindCommentBuild("OPT", "S", 1, "EXT"),
                         1.24830, (long)ORDER_TYPE_BUY_LIMIT);
   Grind_MarketTestSeed(1.25000, 1.25010, 0, 0);
}

//+------------------------------------------------------------------+
void Test_GV1_SidePips()
{
   const double saved_add = g_grind_engine_add_pips;
   const double saved_recon = g_grind_recon_exit_pips;

   AssertNear("GV1 long takes long", Grind_SidePips(true, 10.0, 7.0), 10.0, 1e-9);
   AssertNear("GV1 short takes short", Grind_SidePips(false, 10.0, 7.0), 7.0, 1e-9);
   AssertNear("GV1 short unset inherits", Grind_SidePips(false, 10.0, 0.0), 10.0, 1e-9);
   AssertNear("GV1 short negative inherits", Grind_SidePips(false, 10.0, -1.0), 10.0, 1e-9);

   GV_RestoreEngineGlobals(saved_add, saved_recon);
}

//+------------------------------------------------------------------+
void Test_GV2_ResolveSideInput()
{
   const double saved_add = g_grind_engine_add_pips;
   const double saved_recon = g_grind_recon_exit_pips;
   const double base = 10.0;
   double out = 0.0;

   AssertTrue("GV2 inherit ok", Grind_ResolveSideInput(base, -1.0, out));
   AssertNear("GV2 inherit value", out, 10.0, 1e-9);
   AssertTrue("GV2 override ok", Grind_ResolveSideInput(base, 7.0, out));
   AssertNear("GV2 override value", out, 7.0, 1e-9);
   AssertFalse("GV2 zero refused", Grind_ResolveSideInput(base, 0.0, out));
   AssertFalse("GV2 negative refused", Grind_ResolveSideInput(base, -2.0, out));
   AssertFalse("GV2 minus half refused", Grind_ResolveSideInput(base, -0.5, out));

   GV_RestoreEngineGlobals(saved_add, saved_recon);
}

//+------------------------------------------------------------------+
void Test_GV3_RetryMissingExitsPerSide()
{
   const double saved_add = g_grind_engine_add_pips;
   const double saved_recon = g_grind_recon_exit_pips;

   Grind_OrderTestReset();
   Grind_TestResetSideState();
   Grind_CarryTestReset();
   g_grind_order_test_active = true;
   Adr151_TestSeedSlotSeams(200, 100, 0);
   Grind_MarketTestSeed(1.20000, 1.20010, 0, 0);

   Adr151_TestSetupLongLayer(g_grind_long, 0, 0, 1.20000, 5001UL, 0, 10.0);
   g_grind_long.layers[0].exit_order_ticket = 0;

   ArrayResize(g_grind_short.layers, 1);
   g_grind_short.layers[0].entry_price = 1.20000;
   g_grind_short.layers[0].layer_index = 0;
   g_grind_short.layers[0].position_ticket = 5101UL;
   g_grind_short.layers[0].exit_order_ticket = 0;
   g_grind_short.layers[0].exit_position_ticket = 0;
   g_grind_short.layers[0].exit_target =
      Grind_ExitQFormulaTarget(1.20000, 7.0, _Point, false, 5101UL);

   g_grind_recon_exit_pips = 10.0;
   g_grind_recon_exit_pips_short = 7.0;
   Grind_RetryMissingExits(GV_MAGIC, "OPT", 0.01);

   AssertTrue("GV3 long exit placed", g_grind_long.layers[0].exit_order_ticket != 0);
   AssertNear("GV3 long exit price",
              Grind_OrderGetPriceOpen(g_grind_long.layers[0].exit_order_ticket),
              1.20100, 1e-9);
   AssertTrue("GV3 short exit placed", g_grind_short.layers[0].exit_order_ticket != 0);
   AssertNear("GV3 short exit price",
              Grind_OrderGetPriceOpen(g_grind_short.layers[0].exit_order_ticket),
              1.19930, 1e-9);

   Grind_OrderTestReset();
   Grind_TestResetSideState();
   GV_RestoreEngineGlobals(saved_add, saved_recon);
}

//+------------------------------------------------------------------+
void Test_GV4_I6PerSide()
{
   const double saved_add = g_grind_engine_add_pips;
   const double saved_recon = g_grind_recon_exit_pips;

   GrindReconLayerScratch l[1];
   Grind_TestInitLayerScratch(l[0], 0, 1.20000, 5001UL);
   l[0].has_exit_order = true;
   l[0].exit_order_ticket = 6001;
   l[0].exit_target = 1.20100;

   GrindReconLayerScratch s[1];
   Grind_TestInitLayerScratch(s[0], 0, 1.20000, 5101UL);
   s[0].has_exit_order = true;
   s[0].exit_order_ticket = 6101;
   s[0].exit_target = 1.19930;

   int long_ranks[1];
   long_ranks[0] = 0;
   int short_ranks[1];
   short_ranks[0] = 0;
   const double point = 0.00001;
   string reason = "";

   AssertFalse("GV4 symmetric 10 rejects short",
               Grind_ReconCheckInvariants(l, 1, long_ranks, s, 1, short_ranks,
                                          10.0, point, 8, reason));
   AssertEqStr("GV4 reason short", reason, "I6_SHORT_EXIT");

   reason = "";
   AssertTrue("GV4 per-side accepts",
              Grind_ReconCheckInvariants(l, 1, long_ranks, s, 1, short_ranks,
                                         10.0, point, 8, reason, false, 7.0));

   reason = "";
   AssertFalse("GV4 symmetric 7 rejects long",
               Grind_ReconCheckInvariants(l, 1, long_ranks, s, 1, short_ranks,
                                          7.0, point, 8, reason));
   AssertEqStr("GV4 reason long", reason, "I6_LONG_EXIT");

   reason = "";
   AssertFalse("GV4 wrong short rejects",
               Grind_ReconCheckInvariants(l, 1, long_ranks, s, 1, short_ranks,
                                          10.0, point, 8, reason, false, 12.0));
   AssertEqStr("GV4 reason wrong short", reason, "I6_SHORT_EXIT");

   GV_RestoreEngineGlobals(saved_add, saved_recon);
}

//+------------------------------------------------------------------+
void Test_GV5_RebuildPerSide()
{
   const double saved_add = g_grind_engine_add_pips;
   const double saved_recon = g_grind_recon_exit_pips;
   const double point = 0.00001;

   GrindReconTicket t[4];
   t[0].ticket = 1001; t[0].magic = GV_MAGIC;
   t[0].comment = GrindCommentBuild("OPT", "L", 0, "ENT");
   t[0].price = 1.20000; t[0].kind = GRIND_RECON_TICKET_POSITION;
   t[1].ticket = 2001; t[1].magic = GV_MAGIC;
   t[1].comment = GrindCommentBuild("OPT", "L", 0, "EXT");
   t[1].price = 1.20100; t[1].kind = GRIND_RECON_TICKET_ORDER;
   t[2].ticket = 1101; t[2].magic = GV_MAGIC;
   t[2].comment = GrindCommentBuild("OPT", "S", 0, "ENT");
   t[2].price = 1.20000; t[2].kind = GRIND_RECON_TICKET_POSITION;
   t[3].ticket = 2101; t[3].magic = GV_MAGIC;
   t[3].comment = GrindCommentBuild("OPT", "S", 0, "EXT");
   t[3].price = 1.19930; t[3].kind = GRIND_RECON_TICKET_ORDER;

   GrindSideState L;
   GrindSideState S;
   string reason = "";

   AssertFalse("GV5 symmetric rejects",
               Grind_RebuildBookFromTickets(t, 4, GV_MAGIC, "OPT", 10.0, 8, point, L, S, reason));
   AssertEqStr("GV5 reason", reason, "I6_SHORT_EXIT");

   GrindSideState L2;
   GrindSideState S2;
   reason = "";
   AssertTrue("GV5 per-side ok",
              Grind_RebuildBookFromTickets(t, 4, GV_MAGIC, "OPT", 10.0, 8, point,
                                           L2, S2, reason, false, 7.0));
   AssertTrue("GV5 short depth", ArraySize(S2.layers) == 1);
   AssertNear("GV5 short exit target",
              ArraySize(S2.layers) == 1 ? S2.layers[0].exit_target : 0.0,
              1.19930, 1e-10);

   GrindReconTicket t3[3];
   t3[0] = t[0];
   t3[1] = t[1];
   t3[2] = t[2];
   GrindSideState L3;
   GrindSideState S3;
   reason = "";
   AssertTrue("GV5c ok",
              Grind_RebuildBookFromTickets(t3, 3, GV_MAGIC, "OPT", 10.0, 8, point,
                                           L3, S3, reason, true, 7.0));
   AssertNear("GV5c short formula target",
              ArraySize(S3.layers) == 1 ? S3.layers[0].exit_target : 0.0,
              1.19930, 1e-10);

   GV_RestoreEngineGlobals(saved_add, saved_recon);
}

//+------------------------------------------------------------------+
void Test_GV7_FillShortExitAndAdd()
{
   const double saved_add = g_grind_engine_add_pips;
   const double saved_recon = g_grind_recon_exit_pips;

   Grind_OrderTestReset();
   Grind_DealTestReset();
   Grind_TestResetSideState();
   g_grind_order_test_active = true;
   Adr152_TestPrepareIsolation();
   Grind_EngineConfigureAdr152(true, 0);
   Adr152_TestSeedSlotSeams(200, 100, 0);
   Grind_MarketTestSeed(1.20000, 1.20010, 0);
   g_grind_ent_sent_this_tick = false;
   g_grind_deal_test_active = true;
   Grind_TestAppendDeal(9701, GrindCommentBuild("OPT", "S", 0, "ENT"), DEAL_ENTRY_IN,
                        6701, 5101, 0.0, 0.0, 0.0, 1.20000);

   MqlTradeTransaction tr;
   ZeroMemory(tr);
   tr.type = TRADE_TRANSACTION_DEAL_ADD;
   tr.deal = 9701;
   Grind_OnTradeTransactionEngine(tr, GV_MAGIC, "OPT", 10.0, 10.0, 4.0, 8, 0.01, 7.0, 6.0);

   AssertTrue("GV7 short layer appended", ArraySize(g_grind_short.layers) == 1);
   AssertNear("GV7 short exit target",
              ArraySize(g_grind_short.layers) == 1 ? g_grind_short.layers[0].exit_target : 0.0,
              1.19930, 1e-9);
   const ulong short_ext = ArraySize(g_grind_short.layers) == 1
                           ? g_grind_short.layers[0].exit_order_ticket : 0;
   AssertNear("GV7 short exit order price", Grind_OrderGetPriceOpen(short_ext), 1.19930, 1e-9);
   AssertNear("GV7 short add stored", g_grind_engine_add_pips_short, 6.0, 1e-9);
   AssertTrue("GV7 short add placed", g_grind_short.add_pending_ticket != 0);
   AssertNear("GV7 short add at fill price",
              Grind_OrderGetPriceOpen(g_grind_short.add_pending_ticket), 1.20060, 1e-9);

   Grind_DealTestReset();
   Grind_OrderTestReset();
   Grind_TestResetSideState();
   Adr152_TestResetAll();
   GV_RestoreEngineGlobals(saved_add, saved_recon);
}

//+------------------------------------------------------------------+
void Test_GV8_FillLongControl()
{
   const double saved_add = g_grind_engine_add_pips;
   const double saved_recon = g_grind_recon_exit_pips;

   Grind_OrderTestReset();
   Grind_DealTestReset();
   Grind_TestResetSideState();
   g_grind_order_test_active = true;
   Adr152_TestPrepareIsolation();
   Grind_EngineConfigureAdr152(true, 0);
   Adr152_TestSeedSlotSeams(200, 100, 0);
   Grind_MarketTestSeed(1.20000, 1.20010, 0);
   g_grind_ent_sent_this_tick = false;
   g_grind_deal_test_active = true;
   Grind_TestAppendDeal(9702, GrindCommentBuild("OPT", "L", 0, "ENT"), DEAL_ENTRY_IN,
                        6702, 5001, 0.0, 0.0, 0.0, 1.20000);

   MqlTradeTransaction tr;
   ZeroMemory(tr);
   tr.type = TRADE_TRANSACTION_DEAL_ADD;
   tr.deal = 9702;
   Grind_OnTradeTransactionEngine(tr, GV_MAGIC, "OPT", 10.0, 10.0, 4.0, 8, 0.01, 7.0, 6.0);

   AssertNear("GV8 long exit target",
              ArraySize(g_grind_long.layers) == 1 ? g_grind_long.layers[0].exit_target : 0.0,
              1.20100, 1e-9);
   AssertNear("GV8 long add at fill price",
              Grind_OrderGetPriceOpen(g_grind_long.add_pending_ticket), 1.19900, 1e-9);

   Grind_DealTestReset();
   Grind_OrderTestReset();
   Grind_TestResetSideState();
   Adr152_TestResetAll();
   GV_RestoreEngineGlobals(saved_add, saved_recon);
}

//+------------------------------------------------------------------+
void Test_GV9_L0WidthPerSide()
{
   const double saved_add = g_grind_engine_add_pips;
   const double saved_recon = g_grind_recon_exit_pips;

   Grind_OrderTestReset();
   Grind_TestResetSideState();
   g_grind_order_test_active = true;
   Adr152_TestPrepareIsolation();
   Grind_EngineConfigureAdr152(true, 0);
   Adr152_TestSeedSlotSeams(200, 100, 0);
   Grind_MarketTestSeed(1.20000, 1.20010, 0);

   Grind_OnTickEngine(GV_MAGIC, "OPT", 5.0, 10.0, 10.0, 10.0, 4.0, 8, 0.01, 3.0, 10.0);
   Grind_OnTickEngine(GV_MAGIC, "OPT", 5.0, 10.0, 10.0, 10.0, 4.0, 8, 0.01, 3.0, 10.0);

   AssertNear("GV9 long L0 price",
              Grind_OrderGetPriceOpen(g_grind_long.l0_pending_ticket), 1.19955, 1e-9);
   AssertTrue("GV9 short L0 placed", g_grind_short.l0_pending_ticket != 0);
   AssertNear("GV9 short L0 price",
              Grind_OrderGetPriceOpen(g_grind_short.l0_pending_ticket), 1.20035, 1e-9);

   Grind_MarketTestReset();
   Grind_OrderTestReset();
   Grind_TestResetSideState();
   Adr152_TestResetAll();
   GV_RestoreEngineGlobals(saved_add, saved_recon);
}

//+------------------------------------------------------------------+
void Test_GV10_AddNextPerSide()
{
   const double saved_add = g_grind_engine_add_pips;
   const double saved_recon = g_grind_recon_exit_pips;

   Grind_OrderTestReset();
   Grind_TestResetSideState();
   g_grind_order_test_active = true;
   Adr152_TestPrepareIsolation();
   Grind_EngineConfigureAdr152(true, 0);
   Adr152_TestSeedSlotSeams(200, 100, 0);
   Grind_MarketTestSeed(1.20000, 1.20010, 0);

   Grind_OnTickEngine(GV_MAGIC, "OPT", 5.0, 10.0, 10.0, 10.0, 4.0, 8, 0.01, 3.0, 10.0);
   Grind_OnTickEngine(GV_MAGIC, "OPT", 5.0, 10.0, 10.0, 10.0, 4.0, 8, 0.01, 3.0, 10.0);

   ArrayResize(g_grind_short.layers, 1);
   g_grind_short.layers[0].entry_price = 1.20000;
   g_grind_short.layers[0].layer_index = 0;
   g_grind_short.layers[0].position_ticket = 5101UL;
   g_grind_short.layers[0].exit_order_ticket = 6101UL;
   g_grind_short.layers[0].exit_position_ticket = 0;
   g_grind_short.layers[0].exit_target =
      Grind_ExitQFormulaTarget(1.20000, 7.0, _Point, false, 5101UL);
   Grind_OrderTestUpsert(6101UL, (long)GV_MAGIC,
                         GrindCommentBuild("OPT", "S", 0, "EXT"),
                         1.19930, (long)ORDER_TYPE_BUY_LIMIT);

   g_grind_recon_exit_pips = 10.0;
   g_grind_recon_exit_pips_short = 7.0;

   Grind_OnTickEngine(GV_MAGIC, "OPT", 5.0, 10.0, 10.0, 10.0, 4.0, 8, 0.01, 5.0, 6.0);
   Grind_OnTickEngine(GV_MAGIC, "OPT", 5.0, 10.0, 10.0, 10.0, 4.0, 8, 0.01, 5.0, 6.0);

   AssertTrue("GV10 short add placed", g_grind_short.add_pending_ticket != 0);
   AssertNear("GV10 short add price",
              Grind_OrderGetPriceOpen(g_grind_short.add_pending_ticket), 1.20060, 1e-9);

   Grind_MarketTestReset();
   Grind_OrderTestReset();
   Grind_TestResetSideState();
   Adr152_TestResetAll();
   GV_RestoreEngineGlobals(saved_add, saved_recon);
}

//+------------------------------------------------------------------+
void Test_GV11_LatticeShortPerSide()
{
   const double saved_add = g_grind_engine_add_pips;
   const double saved_recon = g_grind_recon_exit_pips;

   Adr162b_SeedShort8();
   Grind_MarketTestSeed(1.19400, 1.19410, 0, 0);
   Grind_LatticeOnTick(GV_MAGIC, "OPT", 0.01, true, 9.0, 3.0, 8, false, GV_T0, 5.0, 10.0);

   AssertTrue("GV11 S0 rolled at short level",
              Grind_VLHas(7101UL) && MathAbs(Grind_VLGet(7101UL) - 1.19400) <= 1e-9);
   AssertFalse("GV11 one level only", Grind_VLHas(7102UL));
   const double rolled_exit = Grind_OrderGetPriceOpen(8101UL);
   AssertNear("GV11 rolled exit at short exit", rolled_exit, 1.19350, 1e-9);

   Adr162b_Reset();
   Grind_MarketTestReset();
   GV_RestoreEngineGlobals(saved_add, saved_recon);
}

//+------------------------------------------------------------------+
void Test_GV12_CarryPerSide()
{
   const double saved_add = g_grind_engine_add_pips;
   const double saved_recon = g_grind_recon_exit_pips;

   Grind_CarryTestReset();
   Grind_TestResetSideState();

   ArrayResize(g_grind_long.layers, 1);
   g_grind_long.layers[0].entry_price = 1.20000;
   g_grind_long.layers[0].layer_index = 0;
   g_grind_long.layers[0].position_ticket = 7201UL;
   g_grind_long.layers[0].exit_order_ticket = 0;

   ArrayResize(g_grind_short.layers, 1);
   g_grind_short.layers[0].entry_price = 1.20000;
   g_grind_short.layers[0].layer_index = 0;
   g_grind_short.layers[0].position_ticket = 7301UL;
   g_grind_short.layers[0].exit_order_ticket = 0;
   g_grind_short.layers[0].exit_position_ticket = 0;
   g_grind_short.layers[0].exit_target =
      Grind_ExitQFormulaTarget(1.20000, 7.0, _Point, false, 7301UL);

   Grind_CarryExitPassBegin(_Symbol, GV_MAGIC, 10.0, 7.0);

   AssertTrue("GV12 two work items", g_grind_carry_exit_work_count == 2);
   AssertNear("GV12 long base",
              Grind_CarryWorkBase(0, 10.0, 0.00001, 7.0), 1.20100, 1e-9);
   AssertNear("GV12 short base",
              Grind_CarryWorkBase(1, 10.0, 0.00001, 7.0), 1.19930, 1e-9);
   AssertNear("GV12 short base old arity",
              Grind_CarryWorkBase(1, 10.0, 0.00001), 1.19900, 1e-9);

   Grind_CarryTestReset();
   GV_SeedShort8CarryPerSide(1.19400, 1.19410);
   GV_FinishCarryPassPerSide();

   AssertTrue("GV12b all resting I6 at 5", C55_AllRestingI6Short());
   AssertTrue("GV12b all accrued", C55_AllAccruedShort());

   C55_Reset();
   GV_RestoreEngineGlobals(saved_add, saved_recon);
}

//+------------------------------------------------------------------+
void Test_GV13_EjectShortPerSide()
{
   const double saved_add = g_grind_engine_add_pips;
   const double saved_recon = g_grind_recon_exit_pips;

   Grind_TestEjectHarnessReset();
   GV_EjectFixtureShortDepth2();
   GlobalVariableSet(Grind_EjectCommandName(GV_MAGIC), (double)1101UL);
   const int rc = Grind_EjectPollCommand(GV_MAGIC, true, 3.0, false, 7.0);

   AssertEqInt("GV13 ok", rc, GRIND_EJECT_OK);
   AssertNear("GV13 order price", Grind_OrderGetPriceOpen(2101UL), 1.24999, 1e-9);
   AssertNear("GV13 offset", Grind_EjectOffsetGet(1101UL), 0.00269, 1e-9);

   Grind_EjectOffsetDelete(1101UL);
   Grind_TestEjectHarnessReset();
   GV_RestoreEngineGlobals(saved_add, saved_recon);
}

#endif
