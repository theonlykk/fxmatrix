//+------------------------------------------------------------------+
//| fxgrind_tests_rb.mqh — grind v2.1 rebuild at start (C69)         |
//+------------------------------------------------------------------+
#ifndef FXGRIND_TESTS_RB_MQH
#define FXGRIND_TESTS_RB_MQH

const ulong RB_MAGIC = 22260101UL;

//+------------------------------------------------------------------+
void RB_RestoreGlobals(const double saved_add, const double saved_recon)
{
   g_grind_engine_add_pips = saved_add;
   g_grind_recon_exit_pips = saved_recon;
   g_grind_recon_exit_pips_short = 0.0;
}

//+------------------------------------------------------------------+
void RB_Reset()
{
   Adr151_TestResetAll();
   Grind_OrderTestReset();
   Grind_TestResetSideState();
   Grind_CarryTestReset();
   Grind_MarketTestReset();
   GlobalVariableDel(Grind_GeoExitGvName(RB_MAGIC, true));
   GlobalVariableDel(Grind_GeoExitGvName(RB_MAGIC, false));
   g_grind_rebuild_long = false;
   g_grind_rebuild_short = false;
   g_grind_start_add_reprice_long = false;
   g_grind_start_add_reprice_short = false;
   g_grind_recon_exit_pips_short = 0.0;
}

//+------------------------------------------------------------------+
void RB_Layer(GrindSideState &side,
              const int i,
              const int index,
              const double entry,
              const ulong pos,
              const ulong ext,
              const double ext_price,
              const bool is_long)
{
   const int need = i + 1;
   if(ArraySize(side.layers) < need)
      ArrayResize(side.layers, need);
   side.layers[i].entry_price = entry;
   side.layers[i].layer_index = index;
   side.layers[i].position_ticket = pos;
   side.layers[i].exit_order_ticket = ext;
   side.layers[i].exit_position_ticket = 0;
   side.layers[i].exit_target = (ext != 0) ? ext_price : 0.0;
   if(ext != 0) {
      const ENUM_ORDER_TYPE otype = is_long ? ORDER_TYPE_SELL_LIMIT : ORDER_TYPE_BUY_LIMIT;
      Grind_OrderTestUpsert(ext, (long)RB_MAGIC,
                            GrindCommentBuild("OPT", is_long ? "L" : "S", index, "EXT"),
                            ext_price, (long)otype);
   }
}

//+------------------------------------------------------------------+
void RB_BookL3()
{
   g_grind_order_test_active = true;
   Grind_MarketTestSeed(1.20000, 1.20010, 0, 0);
   RB_Layer(g_grind_long, 0, 0, 1.20500, 7001UL, 8001UL, 1.20600, true);
   RB_Layer(g_grind_long, 1, 1, 1.20400, 7002UL, 0, 0.0, true);
   RB_Layer(g_grind_long, 2, 2, 1.20300, 7003UL, 8003UL, 1.20400, true);
}

//+------------------------------------------------------------------+
void RB_BookS3()
{
   g_grind_order_test_active = true;
   Grind_MarketTestSeed(1.20000, 1.20010, 0, 0);
   RB_Layer(g_grind_short, 0, 0, 1.19500, 7101UL, 8101UL, 1.19400, false);
   RB_Layer(g_grind_short, 1, 1, 1.19600, 7102UL, 0, 0.0, false);
   RB_Layer(g_grind_short, 2, 2, 1.19700, 7103UL, 8103UL, 1.19600, false);
}

//+------------------------------------------------------------------+
bool RB_I6(const double entry,
           const double ticket_price,
           const double exit,
           const bool is_long,
           const ulong pos)
{
   return Grind_ReconExitMatchesEntry(entry, ticket_price, exit, 0.00001, is_long,
                                      Grind_CarryShiftGetForRecon(pos), false, pos);
}

//+------------------------------------------------------------------+
void Test_RB1_LongRebuild()
{
   const double saved_add = g_grind_engine_add_pips;
   const double saved_recon = g_grind_recon_exit_pips;
   RB_Reset();

   RB_BookL3();
   g_grind_recon_exit_pips = 7.0;
   g_grind_rebuild_long = true;
   const bool ok = Grind_RebuildExitsAtStart(RB_MAGIC);

   AssertTrue("RB1 ok", ok);
   AssertNear("RB1 L0 price", Grind_OrderGetPriceOpen(8001UL), 1.20570, 1e-9);
   AssertNear("RB1 L2 price", Grind_OrderGetPriceOpen(8003UL), 1.20370, 1e-9);
   AssertTrue("RB1 two modifies", g_grind_order_test_modify_calls == 2);
   AssertNear("RB1 L0 target",
              ArraySize(g_grind_long.layers) > 0 ? g_grind_long.layers[0].exit_target : 0.0,
              1.20570, 1e-9);
   AssertTrue("RB1 held untouched", g_grind_long.layers[1].exit_order_ticket == 0);
   AssertTrue("RB1 I6 at 7",
              RB_I6(1.20500, Grind_OrderGetPriceOpen(8001UL), 7.0, true, 7001UL));

   Grind_RebuildExitsAtStart(RB_MAGIC);
   AssertTrue("RB1 second run no modify", g_grind_order_test_modify_calls == 2);

   RB_Reset();
   RB_RestoreGlobals(saved_add, saved_recon);
}

//+------------------------------------------------------------------+
void Test_RB2_ShortRebuild()
{
   const double saved_add = g_grind_engine_add_pips;
   const double saved_recon = g_grind_recon_exit_pips;
   RB_Reset();

   RB_BookS3();
   g_grind_recon_exit_pips = 10.0;
   g_grind_recon_exit_pips_short = 7.0;
   g_grind_rebuild_short = true;
   Grind_RebuildExitsAtStart(RB_MAGIC);

   AssertNear("RB2 S0 price", Grind_OrderGetPriceOpen(8101UL), 1.19430, 1e-9);
   AssertNear("RB2 S2 price", Grind_OrderGetPriceOpen(8103UL), 1.19630, 1e-9);
   AssertTrue("RB2 two modifies", g_grind_order_test_modify_calls == 2);
   AssertTrue("RB2 I6 at 7",
              RB_I6(1.19500, Grind_OrderGetPriceOpen(8101UL), 7.0, false, 7101UL));

   RB_Reset();
   RB_RestoreGlobals(saved_add, saved_recon);
}

//+------------------------------------------------------------------+
void Test_RB3_EjectedKeepsPrice()
{
   const double saved_add = g_grind_engine_add_pips;
   const double saved_recon = g_grind_recon_exit_pips;
   RB_Reset();

   g_grind_order_test_active = true;
   Grind_MarketTestSeed(1.20000, 1.20010, 0, 0);
   RB_Layer(g_grind_long, 0, 0, 1.20500, 7001UL, 8001UL, 1.20011, true);
   Grind_EjectOffsetSet(7001UL, -0.00589);
   RB_Layer(g_grind_long, 1, 1, 1.20400, 7002UL, 8002UL, 1.20500, true);
   g_grind_recon_exit_pips = 7.0;
   g_grind_rebuild_long = true;
   const bool ok = Grind_RebuildExitsAtStart(RB_MAGIC);

   AssertTrue("RB3 ok", ok);
   AssertNear("RB3 eject order kept", Grind_OrderGetPriceOpen(8001UL), 1.20011, 1e-9);
   AssertNear("RB3 offset re-derived", Grind_EjectOffsetGet(7001UL), -0.00559, 1e-9);
   AssertNear("RB3 L1 price", Grind_OrderGetPriceOpen(8002UL), 1.20470, 1e-9);
   AssertTrue("RB3 one modify", g_grind_order_test_modify_calls == 1);
   AssertTrue("RB3 I6 at 7", RB_I6(1.20500, 1.20011, 7.0, true, 7001UL));

   RB_Reset();
   RB_RestoreGlobals(saved_add, saved_recon);
}

//+------------------------------------------------------------------+
void Test_RB4_RolledFromVL()
{
   const double saved_add = g_grind_engine_add_pips;
   const double saved_recon = g_grind_recon_exit_pips;
   RB_Reset();

   g_grind_order_test_active = true;
   Grind_MarketTestSeed(1.19500, 1.19510, 0, 0);
   RB_Layer(g_grind_long, 0, 0, 1.20500, 7001UL, 8001UL, 1.20000, true);
   Grind_VLSet(7001UL, 1.19900);
   RB_Layer(g_grind_long, 1, 1, 1.20400, 7002UL, 8002UL, 1.20500, true);
   g_grind_recon_exit_pips = 7.0;
   g_grind_rebuild_long = true;
   Grind_RebuildExitsAtStart(RB_MAGIC);

   AssertNear("RB4 rolled price", Grind_OrderGetPriceOpen(8001UL), 1.19970, 1e-9);
   AssertNear("RB4 L1 price", Grind_OrderGetPriceOpen(8002UL), 1.20470, 1e-9);
   AssertTrue("RB4 I6 at 7",
              RB_I6(1.20500, Grind_OrderGetPriceOpen(8001UL), 7.0, true, 7001UL));

   RB_Reset();
   RB_RestoreGlobals(saved_add, saved_recon);
}

//+------------------------------------------------------------------+
void Test_RB5_AccruedKept()
{
   const double saved_add = g_grind_engine_add_pips;
   const double saved_recon = g_grind_recon_exit_pips;
   RB_Reset();

   g_grind_order_test_active = true;
   Grind_MarketTestSeed(1.20000, 1.20010, 0, 0);
   RB_Layer(g_grind_long, 0, 0, 1.20500, 7001UL, 8001UL, 1.20612, true);
   Grind_CarryAccruedSet(7001UL, 0.00012);
   g_grind_recon_exit_pips = 7.0;
   g_grind_rebuild_long = true;
   Grind_RebuildExitsAtStart(RB_MAGIC);

   AssertNear("RB5 price", Grind_OrderGetPriceOpen(8001UL), 1.20582, 1e-9);
   AssertNear("RB5 accrued unchanged", Grind_CarryAccruedGet(7001UL), 0.00012, 1e-9);

   RB_Reset();
   RB_RestoreGlobals(saved_add, saved_recon);
}

//+------------------------------------------------------------------+
void Test_RB6_ClampRecordsShift()
{
   const double saved_add = g_grind_engine_add_pips;
   const double saved_recon = g_grind_recon_exit_pips;
   RB_Reset();

   g_grind_order_test_active = true;
   Grind_MarketTestSeed(1.20060, 1.20070, 0, 0);
   RB_Layer(g_grind_long, 0, 0, 1.20000, 7001UL, 8001UL, 1.20100, true);
   g_grind_recon_exit_pips = 5.0;
   g_grind_rebuild_long = true;
   Grind_RebuildExitsAtStart(RB_MAGIC);

   AssertNear("RB6 clamped price", Grind_OrderGetPriceOpen(8001UL), 1.20071, 1e-9);
   AssertNear("RB6 shift", Grind_CarryShiftGet(7001UL), 0.00021, 1e-9);
   AssertTrue("RB6 release marker", GlobalVariableCheck(Grind_CarryReleaseGvNameLocal(7001UL)));
   AssertTrue("RB6 I6 at 5", RB_I6(1.20000, 1.20071, 5.0, true, 7001UL));

   RB_Reset();
   RB_RestoreGlobals(saved_add, saved_recon);
}

//+------------------------------------------------------------------+
void Test_RB7_UnflaggedNoop()
{
   const double saved_add = g_grind_engine_add_pips;
   const double saved_recon = g_grind_recon_exit_pips;
   RB_Reset();

   RB_BookL3();
   g_grind_recon_exit_pips = 7.0;
   Grind_RebuildExitsAtStart(RB_MAGIC);

   AssertTrue("RB7 no modify", g_grind_order_test_modify_calls == 0);

   RB_Reset();
   RB_RestoreGlobals(saved_add, saved_recon);
}

//+------------------------------------------------------------------+
void Test_RB8_FailClosed()
{
   const double saved_add = g_grind_engine_add_pips;
   const double saved_recon = g_grind_recon_exit_pips;
   RB_Reset();

   RB_BookL3();
   g_grind_recon_exit_pips = 7.0;
   g_grind_rebuild_long = true;
   g_grind_order_test_send_ok = false;
   const bool ok = Grind_RebuildExitsAtStart(RB_MAGIC);

   AssertFalse("RB8 fails closed", ok);
   AssertNear("RB8 L0 untouched", Grind_OrderGetPriceOpen(8001UL), 1.20600, 1e-9);

   g_grind_order_test_send_ok = true;
   Grind_RebuildExitsAtStart(RB_MAGIC);
   AssertNear("RB8 retry moves L0", Grind_OrderGetPriceOpen(8001UL), 1.20570, 1e-9);

   RB_Reset();
   RB_RestoreGlobals(saved_add, saved_recon);
}

//+------------------------------------------------------------------+
void Test_RB10_ReconTolerance()
{
   const double saved_add = g_grind_engine_add_pips;
   const double saved_recon = g_grind_recon_exit_pips;
   RB_Reset();

   GrindReconLayerScratch l[1];
   Grind_TestInitLayerScratch(l[0], 0, 1.20000, 7001UL);
   l[0].has_exit_order = true;
   l[0].exit_order_ticket = 8001;
   l[0].exit_target = 1.20100;
   GrindReconLayerScratch s[];
   int lr[1];
   lr[0] = 0;
   int sr[];
   const double point = 0.00001;
   string reason = "";

   AssertFalse("RB10 strict fails",
               Grind_ReconCheckInvariants(l, 1, lr, s, 0, sr, 7.0, point, 8, reason));
   AssertEqStr("RB10 strict reason", reason, "I6_LONG_EXIT");

   reason = "";
   AssertTrue("RB10 long tolerant ok",
              Grind_ReconCheckInvariants(l, 1, lr, s, 0, sr, 7.0, point, 8, reason,
                                         false, 0.0, true, false));

   reason = "";
   AssertFalse("RB10 short flag keeps long strict",
               Grind_ReconCheckInvariants(l, 1, lr, s, 0, sr, 7.0, point, 8, reason,
                                          false, 0.0, false, true));
   AssertEqStr("RB10 short flag reason", reason, "I6_LONG_EXIT");

   l[0].has_exit_order = false;
   l[0].has_exit_position = true;
   l[0].exit_target = 1.20060;
   reason = "";
   AssertFalse("RB10 filled adverse strict",
               Grind_ReconCheckInvariants(l, 1, lr, s, 0, sr, 7.0, point, 8, reason,
                                          false, 0.0, true, false));
   AssertEqStr("RB10 filled reason", reason, "I6_LONG_EXIT_FILL_ADVERSE");

   RB_Reset();
   RB_RestoreGlobals(saved_add, saved_recon);
}

//+------------------------------------------------------------------+
void Test_RB11_Labels()
{
   const double saved_add = g_grind_engine_add_pips;
   const double saved_recon = g_grind_recon_exit_pips;
   RB_Reset();

   AssertTrue("RB11 absent unchanged", !Grind_GeoExitChanged(RB_MAGIC, true, 7.0));

   Grind_GeoExitSet(RB_MAGIC, true, 10.0);
   AssertTrue("RB11 differs changed", Grind_GeoExitChanged(RB_MAGIC, true, 7.0));
   AssertTrue("RB11 equal unchanged", !Grind_GeoExitChanged(RB_MAGIC, true, 10.0));
   AssertTrue("RB11 short independent", !Grind_GeoExitChanged(RB_MAGIC, false, 7.0));

   double x = 0.0;
   Grind_GeoExitWriteLabels(RB_MAGIC, 7.0, 5.0);
   AssertTrue("RB11 long written", Grind_GeoExitGet(RB_MAGIC, true, x) && MathAbs(x - 7.0) <= 1e-9);
   AssertTrue("RB11 short written", Grind_GeoExitGet(RB_MAGIC, false, x) && MathAbs(x - 5.0) <= 1e-9);

   RB_Reset();
   RB_RestoreGlobals(saved_add, saved_recon);
}

//+------------------------------------------------------------------+
void Test_RB12_AddOneShot()
{
   const double saved_add = g_grind_engine_add_pips;
   const double saved_recon = g_grind_recon_exit_pips;
   RB_Reset();

   Grind_OrderTestReset();
   Grind_TestResetSideState();
   g_grind_order_test_active = true;
   Adr152_TestPrepareIsolation();
   Grind_EngineConfigureAdr152(true, 0);
   Adr152_TestSeedSlotSeams(200, 100, 0);
   Grind_MarketTestSeed(1.20000, 1.20010, 0);

   ArrayResize(g_grind_short.layers, 1);
   g_grind_short.layers[0].entry_price = 1.20000;
   g_grind_short.layers[0].layer_index = 0;
   g_grind_short.layers[0].position_ticket = 5101UL;
   g_grind_short.layers[0].exit_order_ticket = 6101UL;
   g_grind_short.layers[0].exit_target = 1.19930;
   Grind_OrderTestUpsert(6101UL, (long)RB_MAGIC,
                         GrindCommentBuild("OPT", "S", 0, "EXT"),
                         1.19930, (long)ORDER_TYPE_BUY_LIMIT);

   g_grind_short.add_pending_ticket = 6201UL;
   Grind_OrderTestUpsert(6201UL, (long)RB_MAGIC,
                         GrindCommentBuild("OPT", "S", 1, "ENT"),
                         1.20060, (long)ORDER_TYPE_SELL_LIMIT);
   g_grind_start_add_reprice_short = true;

   const int mods_before = g_grind_order_test_modify_calls;
   Grind_EnsureAddNext(g_grind_short, false, RB_MAGIC, "OPT", 5.0, 4.0, 8, 0.01);

   AssertNear("RB12 moved once", Grind_OrderGetPriceOpen(6201UL), 1.20050, 1e-9);
   AssertTrue("RB12 flag cleared", !g_grind_start_add_reprice_short);

   Grind_EnsureAddNext(g_grind_short, false, RB_MAGIC, "OPT", 5.1, 4.0, 8, 0.01);
   AssertTrue("RB12 deadband back", g_grind_order_test_modify_calls == mods_before + 1);

   Adr152_TestResetAll();
   RB_Reset();
   RB_RestoreGlobals(saved_add, saved_recon);
}

//+------------------------------------------------------------------+
void Test_GV14_DueAddShort()
{
   const double saved_add = g_grind_engine_add_pips;
   const double saved_recon = g_grind_recon_exit_pips;
   RB_Reset();

   Grind_OrderTestReset();
   Grind_TestResetSideState();
   g_grind_order_test_active = true;
   Adr152_TestPrepareIsolation();
   Grind_EngineConfigureAdr152(true, 0);
   Adr152_TestSeedSlotSeams(200, 100, 0);
   Grind_MarketTestSeed(1.20000, 1.20010, 0);

   ArrayResize(g_grind_short.layers, 1);
   g_grind_short.layers[0].entry_price = 1.20000;
   g_grind_short.layers[0].layer_index = 0;
   g_grind_short.layers[0].position_ticket = 5101UL;
   g_grind_short.layers[0].exit_order_ticket = 6101UL;
   g_grind_short.layers[0].exit_target = 1.19930;
   Grind_OrderTestUpsert(6101UL, (long)RB_MAGIC,
                         GrindCommentBuild("OPT", "S", 0, "EXT"),
                         1.19930, (long)ORDER_TYPE_BUY_LIMIT);

   g_grind_recon_exit_pips = 10.0;
   g_grind_recon_exit_pips_short = 7.0;
   g_grind_add_due_short = true;

   Grind_OnTickEngine(RB_MAGIC, "OPT", 5.0, 10.0, 10.0, 10.0, 4.0, 8, 0.01, 5.0, 6.0);

   AssertNear("GV14 due add price",
              Grind_OrderGetPriceOpen(g_grind_short.add_pending_ticket), 1.20060, 1e-9);
   AssertTrue("GV14 due cleared", !g_grind_add_due_short);

   Adr152_TestResetAll();
   RB_Reset();
   RB_RestoreGlobals(saved_add, saved_recon);
}

//+------------------------------------------------------------------+
void Test_GV15_RecenterShortWidth()
{
   const double saved_add = g_grind_engine_add_pips;
   const double saved_recon = g_grind_recon_exit_pips;
   RB_Reset();

   Grind_OrderTestReset();
   Grind_TestResetSideState();
   g_grind_order_test_active = true;
   Adr152_TestPrepareIsolation();
   Grind_EngineConfigureAdr152(true, 0);
   Adr152_TestSeedSlotSeams(200, 100, 0);
   Grind_MarketTestSeed(1.20000, 1.20010, 0);

   ArrayResize(g_grind_long.layers, 1);
   g_grind_long.layers[0].entry_price = 1.20000;
   g_grind_long.layers[0].layer_index = 0;
   g_grind_long.layers[0].position_ticket = 5001UL;
   g_grind_long.layers[0].exit_order_ticket = 6001UL;
   g_grind_long.layers[0].exit_target = 1.20100;
   Grind_OrderTestUpsert(6001UL, (long)RB_MAGIC,
                         GrindCommentBuild("OPT", "L", 0, "EXT"),
                         1.20100, (long)ORDER_TYPE_SELL_LIMIT);

   g_grind_short.l0_pending_ticket = 6301UL;
   Grind_OrderTestUpsert(6301UL, (long)RB_MAGIC,
                         GrindCommentBuild("OPT", "S", 0, "ENT"),
                         1.20300, (long)ORDER_TYPE_SELL_LIMIT);
   g_grind_recon_exit_pips = 10.0;

   Grind_OnTickEngine(RB_MAGIC, "OPT", 5.0, 10.0, 10.0, 10.0, 4.0, 8, 0.01, 3.0, 10.0);

   AssertNear("GV15 short L0 recentred", Grind_OrderGetPriceOpen(6301UL), 1.20035, 1e-9);

   Adr152_TestResetAll();
   RB_Reset();
   RB_RestoreGlobals(saved_add, saved_recon);
}

//+------------------------------------------------------------------+
void Test_RB13_UnreadableExitFailsClosed()
{
   const double saved_add = g_grind_engine_add_pips;
   const double saved_recon = g_grind_recon_exit_pips;
   RB_Reset();

   RB_BookL3();
   g_grind_recon_exit_pips = 7.0;
   g_grind_rebuild_long = true;
   Grind_OrderTestRemove(8003UL);
   const bool ok = Grind_RebuildExitsAtStart(RB_MAGIC);

   AssertFalse("RB13 fails closed", ok);
   AssertNear("RB13 L0 moved before the failure", Grind_OrderGetPriceOpen(8001UL), 1.20570, 1e-9);

   RB_Reset();
   RB_RestoreGlobals(saved_add, saved_recon);
}

#endif
