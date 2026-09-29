//+------------------------------------------------------------------+
//| fxgrind_tests_adr164.mqh -- ADR-164 missed-deal replay (DR*, EQH*) |
//+------------------------------------------------------------------+
#ifndef FXGRIND_TESTS_ADR164_MQH
#define FXGRIND_TESTS_ADR164_MQH

const ulong    DR164_MAGIC = 22260101UL;
const datetime DR164_INIT_I = D'2026.09.28 19:27:00';
const datetime DR164_AFTER_INIT = D'2026.09.28 19:27:35';

const ulong DR164_ENT_S = 1583979787UL;
const ulong DR164_EXT_L = 1583980820UL;
const ulong DR164_POS_ENT_S = 1970173871UL;
const ulong DR164_POS_L00 = 1968628021UL;
const ulong DR164_EXIT_ORD_L00 = 1968639465UL;
const ulong DR164_POS_EXT_L = 1968639465UL;

//+------------------------------------------------------------------+
void Adr164_ResetHarness(const double saved_add, const double saved_recon)
{
   Grind_ReplayTestReset();
   Grind_HistTestReset();
   Grind_DealTestReset();
   Grind_OrderTestReset();
   Grind_CloseByTestReset();
   Grind_TestResetSideState();
   Grind_ArchiveTestReset();
   Grind_QuarantineReset();
   g_grind_halted = false;
   g_grind_engine_add_pips = saved_add;
   g_grind_recon_exit_pips = saved_recon;
}

//+------------------------------------------------------------------+
void Adr164_SeedEntHarness()
{
   g_grind_order_test_active = true;
   Adr152_TestPrepareIsolation();
   Grind_EngineConfigureAdr152(true, 0);
   Adr152_TestSeedSlotSeams(200, 100, 0);
   Grind_MarketTestSeed(1.32781, 1.32791, 0);
   g_grind_ent_sent_this_tick = false;
   g_grind_deal_test_active = true;
   g_grind_hist_test_active = true;
}

//+------------------------------------------------------------------+
void Adr164_ReplayInitAtI()
{
   g_grind_hist_test_now = DR164_INIT_I;
   Grind_ReplayInit(DR164_MAGIC, 1000);
   g_grind_hist_test_now = DR164_AFTER_INIT;
}

//+------------------------------------------------------------------+
int Adr164_ArchiveCountSubstr(const string needle)
{
   int n = 0;
   for(int i = 0; i < Grind_ArchiveQueueCount(); i++) {
      if(StringFind(Grind_ArchiveQueuePeek(i), needle) >= 0)
         n++;
   }
   return n;
}

//+------------------------------------------------------------------+
string Adr164_ArchiveMarkerNth(const string code, const int nth)
{
   int seen = 0;
   for(int i = 0; i < Grind_ArchiveQueueCount(); i++) {
      const string e = Grind_ArchiveQueuePeek(i);
      if(StringFind(e, "\"type\":\"ea_event\"") < 0)
         continue;
      if(StringFind(e, code) < 0)
         continue;
      if(seen == nth)
         return e;
      seen++;
   }
   return "";
}

//+------------------------------------------------------------------+
void Adr164_SetupLayerL00()
{
   ArrayResize(g_grind_long.layers, 1);
   Adr151_TestSetupLongLayer(g_grind_long, 0, 0, 1.32686, DR164_POS_L00, DR164_EXIT_ORD_L00, 10.0);
   Grind_OrderTestUpsert(DR164_EXIT_ORD_L00, (long)DR164_MAGIC,
                         GrindCommentBuild("OPT", "L", 0, "EXT"),
                         1.32786, (long)ORDER_TYPE_SELL_LIMIT);
}

//+------------------------------------------------------------------+
void Adr164_AppendEntS(const int layer_index, const datetime deal_time)
{
   Grind_TestAppendDeal(DR164_ENT_S,
                        GrindCommentBuild("OPT", "S", layer_index, "ENT"),
                        DEAL_ENTRY_IN,
                        DR164_POS_ENT_S,
                        DR164_POS_ENT_S,
                        0.0, 0.0, 0.0,
                        1.32781,
                        deal_time);
}

//+------------------------------------------------------------------+
void Adr164_AppendExtL(const datetime deal_time)
{
   Grind_TestAppendDeal(DR164_EXT_L,
                        GrindCommentBuild("OPT", "L", 0, "EXT"),
                        DEAL_ENTRY_IN,
                        DR164_POS_EXT_L,
                        DR164_POS_EXT_L,
                        0.0, 0.0, 0.0,
                        1.32785,
                        deal_time);
}

//+------------------------------------------------------------------+
int Adr164_SweepTimer()
{
   return Grind_ReplaySweep(DR164_MAGIC, "OPT", 10.0, 10.0, 4.0, 8, 0.01, 7.0, 6.0,
                            "timer", 1000);
}

//+------------------------------------------------------------------+
void Test_DR1_ReplayMissedEnt()
{
   const double saved_add = g_grind_engine_add_pips;
   const double saved_recon = g_grind_recon_exit_pips;
   Adr164_ResetHarness(saved_add, saved_recon);
   Adr164_SeedEntHarness();
   Grind_ArchiveTestConfigureCommon();
   Adr164_ReplayInitAtI();
   Adr164_AppendEntS(0, D'2026.09.28 19:27:19');

   // stub Grind_ReplaySweep returns 0
   AssertTrue("DR1 sweep returns 1", Adr164_SweepTimer() == 1);
   AssertTrue("DR1 short depth 1", Grind_SideDepth(g_grind_short) == 1);
   AssertTrue("DR1 short position",
              ArraySize(g_grind_short.layers) == 1 &&
              g_grind_short.layers[0].position_ticket == DR164_POS_ENT_S);
   AssertTrue("DR1 short layer index 0",
              ArraySize(g_grind_short.layers) == 1 &&
              g_grind_short.layers[0].layer_index == 0);
   AssertNear("DR1 short exit target",
              ArraySize(g_grind_short.layers) == 1 ? g_grind_short.layers[0].exit_target : 0.0,
              1.32711, 1e-9);
   const ulong ext = ArraySize(g_grind_short.layers) == 1
                     ? g_grind_short.layers[0].exit_order_ticket : 0;
   AssertNear("DR1 short exit order price", Grind_OrderGetPriceOpen(ext), 1.32711, 1e-9);
   AssertNear("DR1 short add pending price",
              Grind_OrderGetPriceOpen(g_grind_short.add_pending_ticket), 1.32841, 1e-9);
   AssertTrue("DR1 one fill_log", Adr164_ArchiveCountSubstr("\"type\":\"fill_log\"") == 1);
   AssertTrue("DR1 one DEAL_REPLAYED", Adr164_ArchiveCountSubstr("DEAL_REPLAYED") == 1);
   const string m0 = Adr164_ArchiveMarkerNth("DEAL_REPLAYED", 0);
   AssertContains("DR1 marker role ENT", m0, "\"role\":\"ENT\"");
   AssertContains("DR1 marker side S", m0, "\"side\":\"S\"");
   AssertContains("DR1 marker layer 0", m0, "\"layer\":0");
   AssertContains("DR1 marker path timer", m0, "\"path\":\"timer\"");
   AssertContains("DR1 marker owned true", m0, "\"owned\":true");
   AssertTrue("DR1 was replayed", Grind_ReplayWasReplayed(DR164_ENT_S));

   Adr164_ResetHarness(saved_add, saved_recon);
   Adr152_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_DR2_ReplayMissedExt()
{
   const double saved_add = g_grind_engine_add_pips;
   const double saved_recon = g_grind_recon_exit_pips;
   Adr164_ResetHarness(saved_add, saved_recon);
   Adr164_SeedEntHarness();
   Grind_ArchiveTestConfigureCommon();
   g_grind_order_test_active = true;
   Adr164_SetupLayerL00();
   Adr164_ReplayInitAtI();
   Adr164_AppendExtL(D'2026.09.28 19:27:22');

   AssertTrue("DR2 sweep returns 1", Adr164_SweepTimer() == 1);
   AssertTrue("DR2 exit order cleared", g_grind_long.layers[0].exit_order_ticket == 0);
   AssertTrue("DR2 exit position set", g_grind_long.layers[0].exit_position_ticket == DR164_POS_EXT_L);
   AssertTrue("DR2 closeby queued", Grind_CloseByQueueSize(g_grind_long_closeby_queue) == 1);
   AssertTrue("DR2 closeby pair",
              Grind_CloseByQueueSize(g_grind_long_closeby_queue) == 1 &&
              g_grind_long_closeby_queue[0].ticket1 == DR164_POS_L00 &&
              g_grind_long_closeby_queue[0].ticket2 == DR164_POS_EXT_L);
   AssertTrue("DR2 one fill_log", Adr164_ArchiveCountSubstr("\"type\":\"fill_log\"") == 1);
   const string m0 = Adr164_ArchiveMarkerNth("DEAL_REPLAYED", 0);
   AssertContains("DR2 marker role EXT", m0, "\"role\":\"EXT\"");
   AssertContains("DR2 marker side L", m0, "\"side\":\"L\"");

   Adr164_ResetHarness(saved_add, saved_recon);
   Adr152_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_DR3_ReplayMissedOutBy()
{
   const double saved_add = g_grind_engine_add_pips;
   const double saved_recon = g_grind_recon_exit_pips;
   Adr164_ResetHarness(saved_add, saved_recon);
   Adr164_SeedEntHarness();
   Grind_ArchiveTestConfigureCommon();
   g_grind_order_test_active = true;
   Adr164_SetupLayerL00();
   g_grind_long.layers[0].exit_order_ticket = 0;
   g_grind_long.layers[0].exit_position_ticket = DR164_POS_EXT_L;
   const int scalp_before = g_grind_scalp_count;
   const int ev_before = g_grind_scalp_event_queue_count;
   Adr164_ReplayInitAtI();
   const ulong cb_ord = 1970190001UL;
   Grind_TestAppendDeal(1583981001UL, "#1968628021 by #1968639465", DEAL_ENTRY_OUT_BY,
                        cb_ord, DR164_POS_L00, 0.99, 0.0, -0.04, 1.32785,
                        D'2026.09.28 19:27:25');
   Grind_TestAppendDeal(1583981002UL, "#1968628021 by #1968639465", DEAL_ENTRY_OUT_BY,
                        cb_ord, DR164_POS_EXT_L, 0.0, 0.0, -0.04, 1.32686,
                        D'2026.09.28 19:27:25');

   AssertTrue("DR3 sweep returns 2", Adr164_SweepTimer() == 2);
   AssertTrue("DR3 long depth 0", Grind_SideDepth(g_grind_long) == 0);
   AssertTrue("DR3 scalp count plus one", g_grind_scalp_count == scalp_before + 1);
   AssertTrue("DR3 scalp event plus one", g_grind_scalp_event_queue_count == ev_before + 1);
   const string m0 = Adr164_ArchiveMarkerNth("DEAL_REPLAYED", 0);
   const string m1 = Adr164_ArchiveMarkerNth("DEAL_REPLAYED", 1);
   AssertContains("DR3 first owned true", m0, "\"owned\":true");
   AssertContains("DR3 second owned false", m1, "\"owned\":false");
   AssertContains("DR3 first role empty", m0, "\"role\":\"\"");
   AssertContains("DR3 first layer -1", m0, "\"layer\":-1");

   Adr164_ResetHarness(saved_add, saved_recon);
   Adr152_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_DR4_EventThenSweep()
{
   const double saved_add = g_grind_engine_add_pips;
   const double saved_recon = g_grind_recon_exit_pips;
   Adr164_ResetHarness(saved_add, saved_recon);
   Adr164_SeedEntHarness();
   Grind_ArchiveTestConfigureCommon();
   Adr164_ReplayInitAtI();
   Adr164_AppendEntS(0, D'2026.09.28 19:27:19');
   MqlTradeTransaction tr;
   ZeroMemory(tr);
   tr.type = TRADE_TRANSACTION_DEAL_ADD;
   tr.deal = DR164_ENT_S;
   Grind_OnTradeTransactionEngine(tr, DR164_MAGIC, "OPT", 10.0, 10.0, 4.0, 8, 0.01, 7.0, 6.0);

   // stub IsSeen always false
   AssertTrue("DR4 is seen", Grind_ReplayIsSeen(DR164_ENT_S));
   // stub sweep returns 0
   AssertTrue("DR4 sweep returns 0 (guard)", Adr164_SweepTimer() == 0);
   // event path appended layer
   AssertTrue("DR4 depth 1 (guard)", Grind_SideDepth(g_grind_short) == 1);
   AssertTrue("DR4 fill_log 1 (guard)", Adr164_ArchiveCountSubstr("\"type\":\"fill_log\"") == 1);
   AssertTrue("DR4 no DEAL_REPLAYED (guard)", Adr164_ArchiveCountSubstr("DEAL_REPLAYED") == 0);

   Adr164_ResetHarness(saved_add, saved_recon);
   Adr152_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_DR4b_SweepThenEvent()
{
   const double saved_add = g_grind_engine_add_pips;
   const double saved_recon = g_grind_recon_exit_pips;
   Adr164_ResetHarness(saved_add, saved_recon);
   Adr164_SeedEntHarness();
   Grind_ArchiveTestConfigureCommon();
   Adr164_ReplayInitAtI();
   Adr164_AppendEntS(0, D'2026.09.28 19:27:19');
   AssertTrue("DR4b sweep returns 1", Adr164_SweepTimer() == 1);
   MqlTradeTransaction tr;
   ZeroMemory(tr);
   tr.type = TRADE_TRANSACTION_DEAL_ADD;
   tr.deal = DR164_ENT_S;
   Grind_OnTradeTransactionEngine(tr, DR164_MAGIC, "OPT", 10.0, 10.0, 4.0, 8, 0.01, 7.0, 6.0);
   AssertTrue("DR4b one AFTER_REPLAY", Adr164_ArchiveCountSubstr("DEAL_EVENT_AFTER_REPLAY") == 1);
   AssertTrue("DR4b depth 1 (guard)", Grind_SideDepth(g_grind_short) == 1);
   AssertTrue("DR4b fill_log 1 (guard)", Adr164_ArchiveCountSubstr("\"type\":\"fill_log\"") == 1);

   Adr164_ResetHarness(saved_add, saved_recon);
   Adr152_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_DR5_InitSeedAndWindow()
{
   const double saved_add = g_grind_engine_add_pips;
   const double saved_recon = g_grind_recon_exit_pips;
   Adr164_ResetHarness(saved_add, saved_recon);
   Adr164_SeedEntHarness();
   Grind_ArchiveTestConfigureCommon();
   Grind_TestAppendDeal(1583979001UL, GrindCommentBuild("OPT", "S", 0, "ENT"), DEAL_ENTRY_IN,
                        1970173001UL, 1970173001UL, 0.0, 0.0, 0.0, 1.32700,
                        D'2026.09.28 19:26:10');
   Grind_TestAppendDeal(1583979002UL, GrindCommentBuild("OPT", "S", 0, "ENT"), DEAL_ENTRY_IN,
                        1970173002UL, 1970173002UL, 0.0, 0.0, 0.0, 1.32700,
                        D'2026.09.28 19:24:00');
   g_grind_hist_test_now = DR164_INIT_I;
   const int seeded = Grind_ReplayInit(DR164_MAGIC, 1000);
   g_grind_hist_test_now = DR164_AFTER_INIT;
   Adr164_AppendEntS(0, D'2026.09.28 19:27:19');

   AssertTrue("DR5 init returns 1", seeded == 1);
   AssertTrue("DR5 sweep returns 1", Adr164_SweepTimer() == 1);
   AssertTrue("DR5 19:27:19 replayed", Grind_ReplayWasReplayed(DR164_ENT_S));
   // stub WasReplayed false for seeded deals
   AssertFalse("DR5 19:26:10 not replayed (guard)", Grind_ReplayWasReplayed(1583979001UL));
   AssertFalse("DR5 19:24:00 not replayed (guard)", Grind_ReplayWasReplayed(1583979002UL));

   Adr164_ResetHarness(saved_add, saved_recon);
   Adr152_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_DR6_HaltedArchivesOnly()
{
   const double saved_add = g_grind_engine_add_pips;
   const double saved_recon = g_grind_recon_exit_pips;
   Adr164_ResetHarness(saved_add, saved_recon);
   Adr164_SeedEntHarness();
   Grind_ArchiveTestConfigureCommon();
   g_grind_halted = true;
   Adr164_ReplayInitAtI();
   Adr164_AppendEntS(0, D'2026.09.28 19:27:19');
   const int place0 = g_grind_order_test_place_calls;

   AssertTrue("DR6 sweep returns 1", Adr164_SweepTimer() == 1);
   AssertTrue("DR6 one fill_log", Adr164_ArchiveCountSubstr("\"type\":\"fill_log\"") == 1);
   AssertTrue("DR6 short depth 0 (guard)", Grind_SideDepth(g_grind_short) == 0);
   AssertTrue("DR6 no order sent (guard)",
              g_grind_order_test_place_calls == place0 &&
              g_grind_order_test_modify_calls == 0 &&
              g_grind_order_test_remove_calls == 0);
   const string m0 = Adr164_ArchiveMarkerNth("DEAL_REPLAYED", 0);
   AssertContains("DR6 halted true", m0, "\"halted\":true");
   AssertContains("DR6 owned false", m0, "\"owned\":false");
   AssertTrue("DR6 replayed flag", Grind_ReplayWasReplayed(DR164_ENT_S));

   Adr164_ResetHarness(saved_add, saved_recon);
   Adr152_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_DR7_OtherMagicOrSymbolIgnored()
{
   const double saved_add = g_grind_engine_add_pips;
   const double saved_recon = g_grind_recon_exit_pips;
   Adr164_ResetHarness(saved_add, saved_recon);
   Adr164_SeedEntHarness();
   Grind_ArchiveTestConfigureCommon();
   Adr164_ReplayInitAtI();
   Adr164_AppendEntS(0, D'2026.09.28 19:27:19');
   Grind_TestAppendDeal(1583979901UL, GrindCommentBuild("OPT", "S", 0, "ENT"), DEAL_ENTRY_IN,
                        1970173901UL, 1970173901UL, 0.0, 0.0, 0.0, 1.32781,
                        D'2026.09.28 19:27:19');
   g_grind_deal_test_records[g_grind_deal_test_count - 1].magic = (long)22260102UL;
   Grind_TestAppendDeal(1583979902UL, GrindCommentBuild("OPT", "S", 0, "ENT"), DEAL_ENTRY_IN,
                        1970173902UL, 1970173902UL, 0.0, 0.0, 0.0, 1.32781,
                        D'2026.09.28 19:27:19');
   g_grind_deal_test_records[g_grind_deal_test_count - 1].symbol = "XAUUSD";

   AssertTrue("DR7 sweep returns 1", Adr164_SweepTimer() == 1);
   AssertTrue("DR7 ENT_S replayed", Grind_ReplayWasReplayed(DR164_ENT_S));
   AssertFalse("DR7 wrong magic not replayed (guard)", Grind_ReplayWasReplayed(1583979901UL));
   AssertFalse("DR7 wrong magic not seen (guard)", Grind_ReplayIsSeen(1583979901UL));
   AssertFalse("DR7 wrong symbol not replayed (guard)", Grind_ReplayWasReplayed(1583979902UL));
   AssertFalse("DR7 wrong symbol not seen (guard)", Grind_ReplayIsSeen(1583979902UL));

   Adr164_ResetHarness(saved_add, saved_recon);
   Adr152_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_DR8_Resync0928TimeOrder()
{
   const double saved_add = g_grind_engine_add_pips;
   const double saved_recon = g_grind_recon_exit_pips;
   Adr164_ResetHarness(saved_add, saved_recon);
   Adr164_SeedEntHarness();
   Grind_ArchiveTestConfigureCommon();
   g_grind_order_test_active = true;
   ArrayResize(g_grind_short.layers, 1);
   const ulong pos_l04 = 1970132860UL;
   g_grind_short.layers[0].entry_price = 1.32689;
   g_grind_short.layers[0].layer_index = 4;
   g_grind_short.layers[0].position_ticket = pos_l04;
   g_grind_short.layers[0].exit_order_ticket = 1970140001UL;
   g_grind_short.layers[0].exit_position_ticket = 0;
   g_grind_short.layers[0].exit_target = 1.32619;
   Grind_OrderTestUpsert(1970140001UL, (long)DR164_MAGIC,
                         GrindCommentBuild("OPT", "S", 4, "EXT"),
                         1.32619, (long)ORDER_TYPE_BUY_LIMIT);
   Adr164_SetupLayerL00();
   Adr164_ReplayInitAtI();
   Adr164_AppendExtL(D'2026.09.28 19:27:22');
   Grind_TestAppendDeal(DR164_ENT_S,
                        GrindCommentBuild("OPT", "S", 5, "ENT"),
                        DEAL_ENTRY_IN,
                        DR164_POS_ENT_S,
                        DR164_POS_ENT_S,
                        0.0, 0.0, 0.0,
                        1.32781,
                        D'2026.09.28 19:27:19');

   AssertTrue("DR8 sweep returns 2", Adr164_SweepTimer() == 2);
   AssertTrue("DR8 short depth 2", Grind_SideDepth(g_grind_short) == 2);
   bool found_l05 = false;
   for(int i = 0; i < ArraySize(g_grind_short.layers); i++) {
      if(g_grind_short.layers[i].position_ticket == DR164_POS_ENT_S &&
         g_grind_short.layers[i].layer_index == 5 &&
         g_grind_short.layers[i].exit_order_ticket != 0)
         found_l05 = true;
   }
   AssertTrue("DR8 L05 layer", found_l05);
   AssertTrue("DR8 L00 exit pos", g_grind_long.layers[0].exit_position_ticket == DR164_POS_EXT_L);
   AssertTrue("DR8 closeby queued", Grind_CloseByQueueSize(g_grind_long_closeby_queue) == 1);
   const string m0 = Adr164_ArchiveMarkerNth("DEAL_REPLAYED", 0);
   const string m1 = Adr164_ArchiveMarkerNth("DEAL_REPLAYED", 1);
   AssertTrue("DR8 marker order ENT before EXT",
              StringFind(m0, IntegerToString((long)DR164_ENT_S)) >= 0 &&
              StringFind(m1, IntegerToString((long)DR164_EXT_L)) >= 0);

   Adr164_ResetHarness(saved_add, saved_recon);
   Adr152_TestResetAll();
}

//+------------------------------------------------------------------+
void Adr164_ScriptInv(const int count,
                      const bool r0,
                      const string reason0,
                      const bool r1 = false,
                      const string reason1 = "")
{
   g_grind_replay_test_inv_active = true;
   g_grind_replay_test_inv_index = 0;
   g_grind_replay_test_inv_calls = 0;
   if(count == 1) {
      ArrayResize(g_grind_replay_test_inv_results, 1);
      ArrayResize(g_grind_replay_test_inv_reasons, 1);
      g_grind_replay_test_inv_results[0] = r0;
      g_grind_replay_test_inv_reasons[0] = reason0;
   } else {
      ArrayResize(g_grind_replay_test_inv_results, 2);
      ArrayResize(g_grind_replay_test_inv_reasons, 2);
      g_grind_replay_test_inv_results[0] = r0;
      g_grind_replay_test_inv_reasons[0] = reason0;
      g_grind_replay_test_inv_results[1] = r1;
      g_grind_replay_test_inv_reasons[1] = reason1;
   }
}

//+------------------------------------------------------------------+
void Test_DR9_TickSweepBeforeQuarantine()
{
   const double saved_add = g_grind_engine_add_pips;
   const double saved_recon = g_grind_recon_exit_pips;
   Adr164_ResetHarness(saved_add, saved_recon);
   Adr164_SeedEntHarness();
   Grind_ArchiveTestConfigureCommon();
   Adr164_ReplayInitAtI();
   Adr164_AppendEntS(0, D'2026.09.28 19:27:19');
   g_grind_invariant_reason = "I3_SHORT_NAKED";
   Adr164_ScriptInv(2, false, "I3_SHORT_NAKED", true, "");
   const int inv0 = g_grind_replay_test_inv_calls;
   const bool ok = Grind_ReplayCheckInvariants(DR164_MAGIC, "OPT", 10.0, 10.0, 4.0, 8, 0.01, 7.0, 6.0, 10000);
   const int action = Grind_QuarantineStep(ok, g_grind_invariant_reason, 10000);

   AssertTrue("DR9 check returns true", ok);
   AssertTrue("DR9 inv seam calls 2", g_grind_replay_test_inv_calls - inv0 == 2);
   AssertTrue("DR9 quarantine ok", action == GRIND_INV_OK);
   AssertTrue("DR9 no QUARANTINE_ENTER", Adr164_ArchiveCountSubstr("QUARANTINE_ENTER") == 0);
   AssertTrue("DR9 one DEAL_REPLAYED tick",
              Adr164_ArchiveCountSubstr("DEAL_REPLAYED") == 1 &&
              Adr164_ArchiveCountSubstr("\"path\":\"tick\"") == 1);

   Adr164_ResetHarness(saved_add, saved_recon);
   Adr152_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_DR9b_TickThrottle()
{
   const double saved_add = g_grind_engine_add_pips;
   const double saved_recon = g_grind_recon_exit_pips;
   Adr164_ResetHarness(saved_add, saved_recon);
   Adr164_SeedEntHarness();
   Grind_ArchiveTestConfigureCommon();
   Adr164_ReplayInitAtI();
   Adr164_AppendEntS(0, D'2026.09.28 19:27:19');
   g_grind_invariant_reason = "I3_SHORT_NAKED";
   Adr164_ScriptInv(2, false, "I3_SHORT_NAKED", true, "");
   Grind_ReplayCheckInvariants(DR164_MAGIC, "OPT", 10.0, 10.0, 4.0, 8, 0.01, 7.0, 6.0, 10000);

   Adr164_SetupLayerL00();
   Adr164_AppendExtL(D'2026.09.28 19:27:22');
   Adr164_ScriptInv(1, false, "I3_SHORT_NAKED");
   const int inv0 = g_grind_replay_test_inv_calls;
   const bool ok1 = Grind_ReplayCheckInvariants(DR164_MAGIC, "OPT", 10.0, 10.0, 4.0, 8, 0.01, 7.0, 6.0, 10500);
   AssertTrue("DR9b returns false (guard)", !ok1);
   AssertTrue("DR9b seam calls 1", g_grind_replay_test_inv_calls - inv0 == 1);
   AssertFalse("DR9b EXT not replayed (guard)", Grind_ReplayWasReplayed(DR164_EXT_L));

   Adr164_ScriptInv(2, false, "I3_SHORT_NAKED", true, "");
   const bool ok2 = Grind_ReplayCheckInvariants(DR164_MAGIC, "OPT", 10.0, 10.0, 4.0, 8, 0.01, 7.0, 6.0, 11000);
   AssertTrue("DR9b second returns true", ok2);
   AssertTrue("DR9b EXT replayed", Grind_ReplayWasReplayed(DR164_EXT_L));

   Adr164_ResetHarness(saved_add, saved_recon);
   Adr152_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_DR9c_NothingToReplayNoRecheck()
{
   const double saved_add = g_grind_engine_add_pips;
   const double saved_recon = g_grind_recon_exit_pips;
   Adr164_ResetHarness(saved_add, saved_recon);
   Adr164_SeedEntHarness();
   Grind_ArchiveTestConfigureCommon();
   Adr164_ReplayInitAtI();
   Adr164_ScriptInv(1, false, "I3_SHORT_NAKED");
   const int inv0 = g_grind_replay_test_inv_calls;
   const bool ok = Grind_ReplayCheckInvariants(DR164_MAGIC, "OPT", 10.0, 10.0, 4.0, 8, 0.01, 7.0, 6.0, 20000);

   AssertTrue("DR9c returns false (guard)", !ok);
   AssertTrue("DR9c seam calls 1", g_grind_replay_test_inv_calls - inv0 == 1);
   AssertTrue("DR9c last tick sweep ms", g_grind_replay_last_tick_sweep_ms == 20000);

   Adr164_ResetHarness(saved_add, saved_recon);
   Adr152_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_DR10_WindowFrom()
{
   const datetime I = DR164_INIT_I;
   AssertTrue("DR10 case1", Grind_ReplayWindowFrom(I, I, 120) == I);
   AssertTrue("DR10 case2",
              Grind_ReplayWindowFrom(D'2026.09.28 10:00:00', D'2026.09.28 19:30:00', 120) ==
              D'2026.09.28 19:28:00');
   AssertTrue("DR10 case3",
              Grind_ReplayWindowFrom(D'2026.09.28 19:29:30', D'2026.09.28 19:30:00', 120) ==
              D'2026.09.28 19:29:30');
   AssertTrue("DR10 init zero",
              Grind_ReplayWindowFrom(0, D'2026.09.28 19:30:00', 120) == 0);
}

//+------------------------------------------------------------------+
void Test_DR11_ListReplacedMidSweep()
{
   const double saved_add = g_grind_engine_add_pips;
   const double saved_recon = g_grind_recon_exit_pips;
   Adr164_ResetHarness(saved_add, saved_recon);
   Adr164_SeedEntHarness();
   Grind_ArchiveTestConfigureCommon();
   g_grind_order_test_active = true;
   Adr164_SetupLayerL00();
   Adr164_ReplayInitAtI();
   Grind_TestAppendDeal(1583990101UL, GrindCommentBuild("OPT", "L", 1, "ENT"), DEAL_ENTRY_IN,
                        1970190101UL, 1970190101UL, 0.0, 0.0, 0.0, 1.32586,
                        D'2026.09.28 19:27:20');
   Adr164_AppendEntS(0, D'2026.09.28 19:27:19');
   Adr164_AppendExtL(D'2026.09.28 19:27:22');

   AssertTrue("DR11 sweep returns 3", Adr164_SweepTimer() == 3);
   AssertTrue("DR11 all replayed",
              Grind_ReplayWasReplayed(1583990101UL) &&
              Grind_ReplayWasReplayed(DR164_ENT_S) &&
              Grind_ReplayWasReplayed(DR164_EXT_L));
   AssertTrue("DR11 long depth 2", Grind_SideDepth(g_grind_long) == 2);
   AssertTrue("DR11 short depth 1", Grind_SideDepth(g_grind_short) == 1);
   AssertTrue("DR11 L00 exit pos", g_grind_long.layers[0].exit_position_ticket == DR164_POS_EXT_L);
   AssertTrue("DR11 closeby queued", Grind_CloseByQueueSize(g_grind_long_closeby_queue) == 1);

   Adr164_ResetHarness(saved_add, saved_recon);
   Adr152_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_DR12_HandlerGuards()
{
   const double saved_add = g_grind_engine_add_pips;
   const double saved_recon = g_grind_recon_exit_pips;
   Adr164_ResetHarness(saved_add, saved_recon);
   Adr164_SeedEntHarness();
   g_grind_order_test_active = true;
   Adr164_SetupLayerL00();
   g_grind_engine_add_pips = 10.0;
   const int place0 = g_grind_order_test_place_calls;
   Grind_TestAppendDeal(1583990102UL, GrindCommentBuild("OPT", "L", 0, "ENT"), DEAL_ENTRY_IN,
                        DR164_POS_L00, DR164_POS_L00, 0.0, 0.0, 0.0, 1.32686,
                        D'2026.09.28 19:27:10');
   Grind_HandleSideDealFill(g_grind_long, true, 1583990102UL, DR164_MAGIC, "OPT",
                            10.0, 4.0, 8, 0.01);
   AssertTrue("DR12a long depth 1", Grind_SideDepth(g_grind_long) == 1);
   AssertTrue("DR12a no order sent",
              g_grind_order_test_place_calls == place0 &&
              g_grind_order_test_modify_calls == 0 &&
              g_grind_order_test_remove_calls == 0);

   Adr164_ResetHarness(saved_add, saved_recon);
   Adr164_SeedEntHarness();
   g_grind_order_test_active = true;
   Adr164_SetupLayerL00();
   g_grind_long.layers[0].exit_order_ticket = 0;
   g_grind_long.layers[0].exit_position_ticket = DR164_POS_EXT_L;
   ArrayResize(g_grind_long_closeby_queue, 0);
   const int pend0 = g_grind_pending_exit_count;
   Adr164_AppendExtL(D'2026.09.28 19:27:22');
   Grind_HandleSideDealFill(g_grind_long, true, DR164_EXT_L, DR164_MAGIC, "OPT",
                            10.0, 4.0, 8, 0.01);
   AssertTrue("DR12b closeby size 0", Grind_CloseByQueueSize(g_grind_long_closeby_queue) == 0);
   AssertTrue("DR12b pending exit unchanged", g_grind_pending_exit_count == pend0);

   g_grind_engine_add_pips = saved_add;
   Adr164_ResetHarness(saved_add, saved_recon);
   Adr152_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_DR13_EventMissedDetector()
{
   const double saved_add = g_grind_engine_add_pips;
   const double saved_recon = g_grind_recon_exit_pips;
   Adr164_ResetHarness(saved_add, saved_recon);
   Adr164_SeedEntHarness();
   Grind_ArchiveTestConfigureCommon();
   g_grind_order_test_active = true;
   Adr164_SetupLayerL00();
   Adr164_ReplayInitAtI();
   Adr164_AppendEntS(0, D'2026.09.28 19:27:19');
   Adr164_AppendExtL(D'2026.09.28 19:27:22');
   Adr164_SweepTimer();
   MqlTradeTransaction tr;
   ZeroMemory(tr);
   tr.type = TRADE_TRANSACTION_DEAL_ADD;
   tr.deal = DR164_EXT_L;
   Grind_OnTradeTransactionEngine(tr, DR164_MAGIC, "OPT", 10.0, 10.0, 4.0, 8, 0.01, 7.0, 6.0);

   Grind_ReplayCheckMissed(60999);
   AssertTrue("DR13 no miss at 60999 (guard)", Adr164_ArchiveCountSubstr("DEAL_EVENT_MISSED") == 0);
   Grind_ReplayCheckMissed(61000);
   AssertTrue("DR13 one miss at 61000", Adr164_ArchiveCountSubstr("DEAL_EVENT_MISSED") == 1);
   Grind_ReplayCheckMissed(70000);
   AssertTrue("DR13 still one at 70000", Adr164_ArchiveCountSubstr("DEAL_EVENT_MISSED") == 1);
   AssertTrue("DR13 none for EXT at 70000 (guard)",
              StringFind(Adr164_ArchiveMarkerNth("DEAL_EVENT_MISSED", 0),
                         IntegerToString((long)DR164_EXT_L)) < 0);

   Adr164_ResetHarness(saved_add, saved_recon);
   Adr152_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_DR14_ConnectionEdge()
{
   const double saved_add = g_grind_engine_add_pips;
   const double saved_recon = g_grind_recon_exit_pips;
   Adr164_ResetHarness(saved_add, saved_recon);
   Adr164_SeedEntHarness();
   Grind_ArchiveTestConfigureCommon();
   g_grind_replay_test_connected_active = true;
   g_grind_replay_test_connected = true;
   Adr164_ReplayInitAtI();

   AssertFalse("DR14 step false 5000 (guard)", Grind_ReplayConnectionStep(false, 5000));
   AssertFalse("DR14 step false 6000 (guard)", Grind_ReplayConnectionStep(false, 6000));
   AssertTrue("DR14 step true 9500", Grind_ReplayConnectionStep(true, 9500));
   const string m0 = Adr164_ArchiveMarkerNth("CONNECTION_RESTORED", 0);
   AssertContains("DR14 down_ms 4500", m0, "\"down_ms\":4500");
   AssertFalse("DR14 step true 10000 (guard)", Grind_ReplayConnectionStep(true, 10000));
   AssertTrue("DR14 still one marker", Adr164_ArchiveCountSubstr("CONNECTION_RESTORED") == 1);

   Adr164_ResetHarness(saved_add, saved_recon);
   Adr152_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_DR15_NotReady()
{
   const double saved_add = g_grind_engine_add_pips;
   const double saved_recon = g_grind_recon_exit_pips;
   Adr164_ResetHarness(saved_add, saved_recon);
   Adr164_SeedEntHarness();
   Grind_ArchiveTestConfigureCommon();
   Adr164_AppendEntS(0, D'2026.09.28 19:27:19');
   Grind_ReplayReset();
   Adr164_ScriptInv(1, false, "I3_SHORT_NAKED");
   const int inv0 = g_grind_replay_test_inv_calls;
   const bool ok = Grind_ReplayCheckInvariants(DR164_MAGIC, "OPT", 10.0, 10.0, 4.0, 8, 0.01, 7.0, 6.0, 10000);

   AssertTrue("DR15 sweep 0 (guard)", Adr164_SweepTimer() == 0);
   AssertFalse("DR15 nothing replayed (guard)", Grind_ReplayWasReplayed(DR164_ENT_S));
   AssertTrue("DR15 check false (guard)", !ok);
   AssertTrue("DR15 seam once", g_grind_replay_test_inv_calls - inv0 == 1);

   g_grind_hist_test_now = DR164_INIT_I;
   Grind_ReplayInit(DR164_MAGIC, 1000);
   g_grind_hist_test_now = DR164_AFTER_INIT;
   g_grind_order_test_active = true;
   Adr164_SetupLayerL00();
   Adr164_AppendExtL(D'2026.09.28 19:27:22');
   AssertTrue("DR15 post-init sweep 1", Adr164_SweepTimer() == 1);

   Adr164_ResetHarness(saved_add, saved_recon);
   Adr152_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_DR16_SeenOnlyAfterSelect()
{
   const double saved_add = g_grind_engine_add_pips;
   const double saved_recon = g_grind_recon_exit_pips;
   Adr164_ResetHarness(saved_add, saved_recon);
   Adr164_SeedEntHarness();
   Grind_ArchiveTestConfigureCommon();
   Adr164_ReplayInitAtI();
   Adr164_AppendEntS(0, D'2026.09.28 19:27:19');
   g_grind_hist_test_select_fail_ticket = DR164_ENT_S;

   AssertTrue("DR16 sweep 0 (guard)", Adr164_SweepTimer() == 0);
   AssertFalse("DR16 not seen (guard)", Grind_ReplayIsSeen(DR164_ENT_S));
   AssertTrue("DR16 depth 0 (guard)", Grind_SideDepth(g_grind_short) == 0);
   g_grind_hist_test_select_fail_ticket = 0;
   AssertTrue("DR16 sweep 1", Adr164_SweepTimer() == 1);
   AssertTrue("DR16 depth 1", Grind_SideDepth(g_grind_short) == 1);

   Adr164_ResetHarness(saved_add, saved_recon);
   Adr152_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_DR19_EventSeenOnlyAfterProcess()
{
   const double saved_add = g_grind_engine_add_pips;
   const double saved_recon = g_grind_recon_exit_pips;
   Adr164_ResetHarness(saved_add, saved_recon);
   Adr164_SeedEntHarness();
   Grind_ArchiveTestConfigureCommon();
   Adr164_ReplayInitAtI();
   Adr164_AppendEntS(0, D'2026.09.28 19:27:19');
   g_grind_hist_test_select_fail_on_call = 4;
   g_grind_hist_test_select_fail_ticket = DR164_ENT_S;
   MqlTradeTransaction tr;
   ZeroMemory(tr);
   tr.type = TRADE_TRANSACTION_DEAL_ADD;
   tr.deal = DR164_ENT_S;
   Grind_OnTradeTransactionEngine(tr, DR164_MAGIC, "OPT", 10.0, 10.0, 4.0, 8, 0.01, 7.0, 6.0);

   AssertFalse("DR19 not seen on handler select fail", Grind_ReplayIsSeen(DR164_ENT_S));
   AssertTrue("DR19 depth 0 (guard)", Grind_SideDepth(g_grind_short) == 0);
   g_grind_hist_test_select_fail_on_call = 0;
   g_grind_hist_test_select_fail_ticket = 0;
   AssertTrue("DR19 sweep 1", Adr164_SweepTimer() == 1);
   AssertTrue("DR19 depth 1", Grind_SideDepth(g_grind_short) == 1);

   Adr164_ResetHarness(saved_add, saved_recon);
   Adr152_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_DR20_EventMarkSeenAfterProcess()
{
   const double saved_add = g_grind_engine_add_pips;
   const double saved_recon = g_grind_recon_exit_pips;
   Adr164_ResetHarness(saved_add, saved_recon);
   Adr164_SeedEntHarness();
   Grind_ArchiveTestConfigureCommon();
   Adr164_ReplayInitAtI();
   Adr164_AppendEntS(0, D'2026.09.28 19:27:19');
   g_grind_hist_test_select_fail_on_call = 1;
   g_grind_hist_test_select_fail_ticket = DR164_ENT_S;
   MqlTradeTransaction tr;
   ZeroMemory(tr);
   tr.type = TRADE_TRANSACTION_DEAL_ADD;
   tr.deal = DR164_ENT_S;
   Grind_OnTradeTransactionEngine(tr, DR164_MAGIC, "OPT", 10.0, 10.0, 4.0, 8, 0.01, 7.0, 6.0);

   AssertTrue("DR20 seen after ProcessDeal", Grind_ReplayIsSeen(DR164_ENT_S));
   AssertTrue("DR20 depth 1", Grind_SideDepth(g_grind_short) == 1);
   AssertTrue("DR20 sweep 0", Adr164_SweepTimer() == 0);

   Adr164_ResetHarness(saved_add, saved_recon);
   Adr152_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_DR21_MarkSeenWithoutReselect()
{
   const double saved_add = g_grind_engine_add_pips;
   const double saved_recon = g_grind_recon_exit_pips;
   Adr164_ResetHarness(saved_add, saved_recon);
   Adr164_SeedEntHarness();
   Grind_ArchiveTestConfigureCommon();
   Adr164_ReplayInitAtI();
   Adr164_AppendEntS(0, D'2026.09.28 19:27:19');
   g_grind_hist_test_select_fail_on_call = 5;
   g_grind_hist_test_select_fail_ticket = DR164_ENT_S;
   MqlTradeTransaction tr;
   ZeroMemory(tr);
   tr.type = TRADE_TRANSACTION_DEAL_ADD;
   tr.deal = DR164_ENT_S;
   Grind_OnTradeTransactionEngine(tr, DR164_MAGIC, "OPT", 10.0, 10.0, 4.0, 8, 0.01, 7.0, 6.0);

   AssertTrue("DR21 seen without mark reselect", Grind_ReplayIsSeen(DR164_ENT_S));
   AssertTrue("DR21 depth 1 (guard)", Grind_SideDepth(g_grind_short) == 1);

   Adr164_ResetHarness(saved_add, saved_recon);
   Adr152_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_DR22_NoDuplicateFillLogOnReplay()
{
   const double saved_add = g_grind_engine_add_pips;
   const double saved_recon = g_grind_recon_exit_pips;
   Adr164_ResetHarness(saved_add, saved_recon);
   Adr164_SeedEntHarness();
   Grind_ArchiveTestConfigureCommon();
   Adr164_ReplayInitAtI();
   Adr164_AppendEntS(0, D'2026.09.28 19:27:19');
   g_grind_hist_test_select_fail_on_call = 5;
   g_grind_hist_test_select_fail_ticket = DR164_ENT_S;
   MqlTradeTransaction tr;
   ZeroMemory(tr);
   tr.type = TRADE_TRANSACTION_DEAL_ADD;
   tr.deal = DR164_ENT_S;
   Grind_OnTradeTransactionEngine(tr, DR164_MAGIC, "OPT", 10.0, 10.0, 4.0, 8, 0.01, 7.0, 6.0);

   AssertTrue("DR22 one fill_log after event (guard)",
              Adr164_ArchiveCountSubstr("\"type\":\"fill_log\"") == 1);
   AssertTrue("DR22 sweep 1", Adr164_SweepTimer() == 1);
   AssertTrue("DR22 one fill_log after sweep",
              Adr164_ArchiveCountSubstr("\"type\":\"fill_log\"") == 1);

   Adr164_ResetHarness(saved_add, saved_recon);
   Adr152_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_DR17_Prune()
{
   const double saved_add = g_grind_engine_add_pips;
   const double saved_recon = g_grind_recon_exit_pips;
   Adr164_ResetHarness(saved_add, saved_recon);
   Adr164_SeedEntHarness();
   Grind_ArchiveTestConfigureCommon();
   Adr164_ReplayInitAtI();
   Grind_ReplayMarkSeen(DR164_EXT_L, (long)D'2026.09.28 19:27:22' * 1000);
   Adr164_AppendEntS(0, D'2026.09.28 19:27:19');
   Adr164_SweepTimer();
   g_grind_hist_test_now = D'2026.09.28 19:37:00';
   g_grind_replay_last_sweep_time = D'2026.09.28 19:35:00';
   Adr164_SweepTimer();

   AssertFalse("DR17 plain seen gone (guard)", Grind_ReplayIsSeen(DR164_EXT_L));
   AssertTrue("DR17 waiting replay kept", Grind_ReplayWasReplayed(DR164_ENT_S));
   AssertTrue("DR17 seen count 1", Grind_ReplaySeenCount() == 1);

   Adr164_ResetHarness(saved_add, saved_recon);
   Adr152_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_DR18_SeedBeforeReconGuardAbsorbs()
{
   const double saved_add = g_grind_engine_add_pips;
   const double saved_recon = g_grind_recon_exit_pips;
   Adr164_ResetHarness(saved_add, saved_recon);
   Adr164_SeedEntHarness();
   Grind_ArchiveTestConfigureCommon();
   g_grind_order_test_active = true;
   Adr164_ReplayInitAtI();
   Adr164_SetupLayerL00();
   const int place0 = g_grind_order_test_place_calls;
   Grind_TestAppendDeal(1583970001UL, GrindCommentBuild("OPT", "L", 0, "ENT"), DEAL_ENTRY_IN,
                        DR164_POS_L00, DR164_POS_L00, 0.0, 0.0, 0.0, 1.32686,
                        D'2026.09.28 19:27:05');

   AssertTrue("DR18 sweep returns 1", Adr164_SweepTimer() == 1);
   AssertTrue("DR18 long depth 1 (guard)", Grind_SideDepth(g_grind_long) == 1);
   AssertTrue("DR18 exit order kept (guard)", g_grind_long.layers[0].exit_order_ticket == DR164_EXIT_ORD_L00);
   AssertTrue("DR18 no order sent (guard)",
              g_grind_order_test_place_calls == place0 &&
              g_grind_order_test_modify_calls == 0 &&
              g_grind_order_test_remove_calls == 0);
   AssertTrue("DR18 one fill_log", Adr164_ArchiveCountSubstr("\"type\":\"fill_log\"") == 1);
   const string m0 = Adr164_ArchiveMarkerNth("DEAL_REPLAYED", 0);
   AssertContains("DR18 role ENT", m0, "\"role\":\"ENT\"");
   AssertContains("DR18 side L", m0, "\"side\":\"L\"");
   AssertContains("DR18 owned true", m0, "\"owned\":true");

   Adr164_ResetHarness(saved_add, saved_recon);
   Adr152_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_EQH1_FoundWhenNotNewest()
{
   const double saved_add = g_grind_engine_add_pips;
   const double saved_recon = g_grind_recon_exit_pips;
   Adr164_ResetHarness(saved_add, saved_recon);
   g_grind_deal_test_active = false;
   g_grind_hist_test_active = true;
   g_grind_order_test_active = true;
   ArrayResize(g_grind_long.layers, 1);
   Adr151_TestSetupLongLayer(g_grind_long, 0, 0, 1.10500, 5001UL, 6101UL, 10.0);
   Grind_PositionTestAdd(7101UL);
   g_grind_hist_test_now = TimeCurrent();
   Grind_TestAppendDeal(9801UL, GrindCommentBuild("OPT", "L", 0, "EXT"), DEAL_ENTRY_IN,
                        6101UL, 7101UL, 0.0, 0.0, 0.0, 1.10530,
                        g_grind_hist_test_now - 60);
   Grind_TestAppendDeal(9802UL, "OTHER", DEAL_ENTRY_IN,
                        6999UL, 7999UL, 0.0, 0.0, 0.0, 1.10500,
                        g_grind_hist_test_now - 30);

   AssertTrue("EQH1 returns true (guard)",
              Grind_ExitQHoldCancelLayer(g_grind_long.layers[0], true, DR164_MAGIC));
   AssertTrue("EQH1 exit position 7101", g_grind_long.layers[0].exit_position_ticket == 7101UL);
   AssertTrue("EQH1 exit order 0 (guard)", g_grind_long.layers[0].exit_order_ticket == 0);
   AssertTrue("EQH1 closeby queued",
              Grind_CloseByQueueSize(g_grind_long_closeby_queue) == 1 &&
              g_grind_long_closeby_queue[0].ticket1 == 5001UL &&
              g_grind_long_closeby_queue[0].ticket2 == 7101UL);

   Adr164_ResetHarness(saved_add, saved_recon);
   Adr152_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_EQH2_MissZeroesThenLateExtAttaches()
{
   const double saved_add = g_grind_engine_add_pips;
   const double saved_recon = g_grind_recon_exit_pips;
   Adr164_ResetHarness(saved_add, saved_recon);
   g_grind_deal_test_active = false;
   g_grind_hist_test_active = true;
   g_grind_order_test_active = true;
   ArrayResize(g_grind_long.layers, 1);
   Adr151_TestSetupLongLayer(g_grind_long, 0, 0, 1.10500, 5001UL, 6101UL, 10.0);
   Grind_PositionTestAdd(7101UL);
   Grind_CarryShiftSet(5001UL, 0.00010);
   g_grind_hist_test_now = TimeCurrent();
   Grind_TestAppendDeal(9802UL, "OTHER", DEAL_ENTRY_IN,
                        6999UL, 7999UL, 0.0, 0.0, 0.0, 1.10500,
                        g_grind_hist_test_now - 30);

   AssertTrue("EQH2 returns true (guard)",
              Grind_ExitQHoldCancelLayer(g_grind_long.layers[0], true, DR164_MAGIC));
   AssertTrue("EQH2 exit order 0 (guard)", g_grind_long.layers[0].exit_order_ticket == 0);
   AssertNear("EQH2 carry shift 0 (guard)", Grind_CarryShiftGet(5001UL), 0.0, 1e-12);

   g_grind_deal_test_active = true;
   Grind_TestAppendDeal(9803UL, GrindCommentBuild("OPT", "L", 0, "EXT"), DEAL_ENTRY_IN,
                        6101UL, 7101UL, 0.0, 0.0, 0.0, 1.10530,
                        g_grind_hist_test_now - 10);
   MqlTradeTransaction tr;
   ZeroMemory(tr);
   tr.type = TRADE_TRANSACTION_DEAL_ADD;
   tr.deal = 9803UL;
   Grind_OnTradeTransactionEngine(tr, DR164_MAGIC, "OPT", 10.0, 10.0, 4.0, 8, 0.01, 7.0, 6.0);
   AssertTrue("EQH2 exit position 7101 (guard)", g_grind_long.layers[0].exit_position_ticket == 7101UL);
   AssertTrue("EQH2 closeby queued (guard)",
              Grind_CloseByQueueSize(g_grind_long_closeby_queue) == 1 &&
              g_grind_long_closeby_queue[0].ticket1 == 5001UL &&
              g_grind_long_closeby_queue[0].ticket2 == 7101UL);

   Adr164_ResetHarness(saved_add, saved_recon);
   Adr152_TestResetAll();
}

#endif // FXGRIND_TESTS_ADR164_MQH
