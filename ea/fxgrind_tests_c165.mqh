//+------------------------------------------------------------------+
//| fxgrind_tests_c165.mqh — C165 clamped-add hold (CH*, CE*)        |
//+------------------------------------------------------------------+
#ifndef FXGRIND_TESTS_C165_MQH
#define FXGRIND_TESTS_C165_MQH

const double C165_POINT = 0.00001;
const double C165_DEADBAND = 2.0;
const int C165_MAX_LAYERS = 7;

//+------------------------------------------------------------------+
void C165_RestoreGlobals(const double saved_add, const double saved_recon)
{
   g_grind_engine_add_pips = saved_add;
   g_grind_recon_exit_pips = saved_recon;
}

//+------------------------------------------------------------------+
void C165_BaseReset()
{
   RB_Reset();
   g_grind_order_test_active = true;
   Adr152_TestPrepareIsolation();
   Grind_EngineConfigureAdr152(true, 0);
   Adr152_TestSeedSlotSeams(200, 100, 0);
}

//+------------------------------------------------------------------+
void C165_SeedShort(const double resting_add_price)
{
   ArrayResize(g_grind_short.layers, 1);
   g_grind_short.layers[0].entry_price = 0.83832;
   g_grind_short.layers[0].layer_index = 0;
   g_grind_short.layers[0].position_ticket = 5101UL;
   g_grind_short.layers[0].exit_order_ticket = 6101UL;
   g_grind_short.layers[0].exit_target = 0.83782;
   Grind_OrderTestUpsert(6101UL, (long)RB_MAGIC,
                         GrindCommentBuild("OPT", "S", 0, "EXT"),
                         0.83782, (long)ORDER_TYPE_BUY_LIMIT);

   g_grind_short.add_pending_ticket = 6201UL;
   Grind_OrderTestUpsert(6201UL, (long)RB_MAGIC,
                         GrindCommentBuild("OPT", "S", 1, "ENT"),
                         resting_add_price, (long)ORDER_TYPE_SELL_LIMIT);
}

//+------------------------------------------------------------------+
void C165_SeedLong(const double resting_add_price)
{
   ArrayResize(g_grind_long.layers, 1);
   g_grind_long.layers[0].entry_price = 1.12070;
   g_grind_long.layers[0].layer_index = 0;
   g_grind_long.layers[0].position_ticket = 5201UL;
   g_grind_long.layers[0].exit_order_ticket = 6301UL;
   g_grind_long.layers[0].exit_target = 1.12140;
   Grind_OrderTestUpsert(6301UL, (long)RB_MAGIC,
                         GrindCommentBuild("OPT", "L", 0, "EXT"),
                         1.12140, (long)ORDER_TYPE_SELL_LIMIT);

   g_grind_long.add_pending_ticket = 6401UL;
   Grind_OrderTestUpsert(6401UL, (long)RB_MAGIC,
                         GrindCommentBuild("OPT", "L", 1, "ENT"),
                         resting_add_price, (long)ORDER_TYPE_BUY_LIMIT);
}

//+------------------------------------------------------------------+
void C165_CallEnsureShort(const double bid, const double ask)
{
   Grind_MarketTestSeed(bid, ask, 0);
   Grind_EnsureAddNext(g_grind_short, false, RB_MAGIC, "OPT",
                       5.0, C165_DEADBAND, C165_MAX_LAYERS, 0.01);
}

//+------------------------------------------------------------------+
void C165_CallEnsureLong(const double bid, const double ask)
{
   Grind_MarketTestSeed(bid, ask, 0);
   Grind_EnsureAddNext(g_grind_long, true, RB_MAGIC, "OPT",
                       7.0, C165_DEADBAND, C165_MAX_LAYERS, 0.01);
}

//+------------------------------------------------------------------+
void Test_CH1_SellHeld()
{
   AssertTrue("CH1 (F)", Grind_AddClampHold(false, 0.83882, 0.84010, 0.83975, C165_POINT));
}

//+------------------------------------------------------------------+
void Test_CH2_SellToward()
{
   AssertFalse("CH2 (G)", Grind_AddClampHold(false, 0.83882, 0.83915, 0.83975, C165_POINT));
}

//+------------------------------------------------------------------+
void Test_CH3_SellUnclamped()
{
   AssertFalse("CH3 (G)", Grind_AddClampHold(false, 0.83882, 0.83882, 0.83975, C165_POINT));
}

//+------------------------------------------------------------------+
void Test_CH4_SellWorse()
{
   AssertFalse("CH4 (G)", Grind_AddClampHold(false, 0.83882, 0.83901, 0.83870, C165_POINT));
}

//+------------------------------------------------------------------+
void Test_CH5_SellAtTarget()
{
   AssertTrue("CH5 (F)", Grind_AddClampHold(false, 0.83882, 0.84010, 0.83882, C165_POINT));
}

//+------------------------------------------------------------------+
void Test_CH6_BuyHeld()
{
   AssertTrue("CH6 (F)", Grind_AddClampHold(true, 1.12000, 1.11899, 1.11930, C165_POINT));
}

//+------------------------------------------------------------------+
void Test_CH7_BuyToward()
{
   AssertFalse("CH7 (G)", Grind_AddClampHold(true, 1.12000, 1.11960, 1.11894, C165_POINT));
}

//+------------------------------------------------------------------+
void Test_CH8_BuyWorse()
{
   AssertFalse("CH8 (G)", Grind_AddClampHold(true, 1.12000, 1.11960, 1.12010, C165_POINT));
}

//+------------------------------------------------------------------+
void Test_CE1_ShortHeld()
{
   const double saved_add = g_grind_engine_add_pips;
   const double saved_recon = g_grind_recon_exit_pips;
   C165_BaseReset();
   C165_SeedShort(0.83975);
   const int mods_before = g_grind_order_test_modify_calls;
   C165_CallEnsureShort(0.83960, 0.84009);
   AssertTrue("CE1 mods (F)", g_grind_order_test_modify_calls == mods_before);
   AssertNear("CE1 price (F)", Grind_OrderGetPriceOpen(6201UL), 0.83975, 1e-9);
   Adr152_TestResetAll();
   RB_Reset();
   C165_RestoreGlobals(saved_add, saved_recon);
}

//+------------------------------------------------------------------+
void Test_CE2_ShortToward()
{
   const double saved_add = g_grind_engine_add_pips;
   const double saved_recon = g_grind_recon_exit_pips;
   C165_BaseReset();
   C165_SeedShort(0.83975);
   const int mods_before = g_grind_order_test_modify_calls;
   C165_CallEnsureShort(0.83900, 0.83914);
   AssertTrue("CE2 mods (G)", g_grind_order_test_modify_calls == mods_before + 1);
   AssertNear("CE2 price (G)", Grind_OrderGetPriceOpen(6201UL), 0.83915, 1e-9);
   Adr152_TestResetAll();
   RB_Reset();
   C165_RestoreGlobals(saved_add, saved_recon);
}

//+------------------------------------------------------------------+
void Test_CE3_ShortUnclamped()
{
   const double saved_add = g_grind_engine_add_pips;
   const double saved_recon = g_grind_recon_exit_pips;
   C165_BaseReset();
   C165_SeedShort(0.83975);
   const int mods_before = g_grind_order_test_modify_calls;
   C165_CallEnsureShort(0.83800, 0.83814);
   AssertTrue("CE3 mods (G)", g_grind_order_test_modify_calls == mods_before + 1);
   AssertNear("CE3 price (G)", Grind_OrderGetPriceOpen(6201UL), 0.83882, 1e-9);
   Adr152_TestResetAll();
   RB_Reset();
   C165_RestoreGlobals(saved_add, saved_recon);
}

//+------------------------------------------------------------------+
void Test_CE4_ShortWorse()
{
   const double saved_add = g_grind_engine_add_pips;
   const double saved_recon = g_grind_recon_exit_pips;
   C165_BaseReset();
   C165_SeedShort(0.83870);
   const int mods_before = g_grind_order_test_modify_calls;
   C165_CallEnsureShort(0.83860, 0.83900);
   AssertTrue("CE4 mods (G)", g_grind_order_test_modify_calls == mods_before + 1);
   AssertNear("CE4 price (G)", Grind_OrderGetPriceOpen(6201UL), 0.83901, 1e-9);
   Adr152_TestResetAll();
   RB_Reset();
   C165_RestoreGlobals(saved_add, saved_recon);
}

//+------------------------------------------------------------------+
void Test_CE5_Flicker()
{
   const double saved_add = g_grind_engine_add_pips;
   const double saved_recon = g_grind_recon_exit_pips;
   C165_BaseReset();
   C165_SeedShort(0.83975);
   const int mods_before = g_grind_order_test_modify_calls;
   for(int i = 0; i < 50; i++) {
      C165_CallEnsureShort(0.83960, 0.84009);
      C165_CallEnsureShort(0.83960, 0.83974);
   }
   AssertTrue("CE5 mods (F)", g_grind_order_test_modify_calls == mods_before);
   AssertNear("CE5 price (G)", Grind_OrderGetPriceOpen(6201UL), 0.83975, 1e-9);
   Adr152_TestResetAll();
   RB_Reset();
   C165_RestoreGlobals(saved_add, saved_recon);
}

//+------------------------------------------------------------------+
void Test_CE6_LongHeld()
{
   const double saved_add = g_grind_engine_add_pips;
   const double saved_recon = g_grind_recon_exit_pips;
   C165_BaseReset();
   C165_SeedLong(1.11930);
   const int mods_before = g_grind_order_test_modify_calls;
   C165_CallEnsureLong(1.11900, 1.11940);
   AssertTrue("CE6 mods (F)", g_grind_order_test_modify_calls == mods_before);
   AssertNear("CE6 price (F)", Grind_OrderGetPriceOpen(6401UL), 1.11930, 1e-9);
   Adr152_TestResetAll();
   RB_Reset();
   C165_RestoreGlobals(saved_add, saved_recon);
}

//+------------------------------------------------------------------+
void Test_CE7_LongToward()
{
   const double saved_add = g_grind_engine_add_pips;
   const double saved_recon = g_grind_recon_exit_pips;
   C165_BaseReset();
   C165_SeedLong(1.11894);
   const int mods_before = g_grind_order_test_modify_calls;
   C165_CallEnsureLong(1.11961, 1.11971);
   AssertTrue("CE7 mods (G)", g_grind_order_test_modify_calls == mods_before + 1);
   AssertNear("CE7 price (G)", Grind_OrderGetPriceOpen(6401UL), 1.11960, 1e-9);
   Adr152_TestResetAll();
   RB_Reset();
   C165_RestoreGlobals(saved_add, saved_recon);
}

//+------------------------------------------------------------------+
void Test_CE8_OneShotHeld()
{
   const double saved_add = g_grind_engine_add_pips;
   const double saved_recon = g_grind_recon_exit_pips;
   C165_BaseReset();
   C165_SeedShort(0.83975);
   g_grind_start_add_reprice_short = true;
   const int mods_before = g_grind_order_test_modify_calls;
   C165_CallEnsureShort(0.83960, 0.84009);
   AssertTrue("CE8 mods (F)", g_grind_order_test_modify_calls == mods_before);
   AssertNear("CE8 price (F)", Grind_OrderGetPriceOpen(6201UL), 0.83975, 1e-9);
   AssertTrue("CE8 flag (G)", !g_grind_start_add_reprice_short);
   Adr152_TestResetAll();
   RB_Reset();
   C165_RestoreGlobals(saved_add, saved_recon);
}

//+------------------------------------------------------------------+
void Test_CE9_ShortAtTarget()
{
   const double saved_add = g_grind_engine_add_pips;
   const double saved_recon = g_grind_recon_exit_pips;
   C165_BaseReset();
   C165_SeedShort(0.83882);
   const int mods_before = g_grind_order_test_modify_calls;
   C165_CallEnsureShort(0.83870, 0.83910);
   AssertTrue("CE9 mods (F)", g_grind_order_test_modify_calls == mods_before);
   AssertNear("CE9 price (F)", Grind_OrderGetPriceOpen(6201UL), 0.83882, 1e-9);
   Adr152_TestResetAll();
   RB_Reset();
   C165_RestoreGlobals(saved_add, saved_recon);
}

#endif
