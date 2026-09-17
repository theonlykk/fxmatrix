//+------------------------------------------------------------------+
//| fxgrind_tests_adr152.mqh — ADR-152 phase 1 unit tests (20)       |
//+------------------------------------------------------------------+
#ifndef FXGRIND_TESTS_ADR152_MQH
#define FXGRIND_TESTS_ADR152_MQH

#include "grind_exitq.mqh"

void Grind_EngineConfigureAdr152(const bool fill_time_place, const int slot_near_reserve);
bool Grind_AddTargetNearMarket(const double target, const double mid, const double add_pips);
bool Grind_SendNextAddEnt(GrindSideState &side,
                          const bool is_long,
                          const ulong magic,
                          const string slot,
                          const double add_pips,
                          const int max_layers,
                          const double lots,
                          const bool use_try_lock,
                          const long fill_deal_time_msc = 0);
void Grind_MarketTestSeedTimeMsc(const long time_msc);
void Grind_ApiCounterTestReset();
void Grind_ApiCounterTestSeed(const int count);
int  Grind_OrderTestCountFleetEnt(const string side_letter);

extern long g_grind_entry_place_latency_ms;
extern bool g_grind_cap_test_lock_held;
void Grind_Adr152ResetDueFlags();
void Grind_TryPlaceAddAtFill(GrindSideState &side,
                             const bool is_long,
                             const ulong magic,
                             const string slot,
                             const double add_pips,
                             const double deadband_pips,
                             const int max_layers,
                             const double lots,
                             const ulong deal_ticket);
bool Grind_ApiCounterEntryStopped();
void Grind_OnTickEngine(const ulong magic,
                        const string slot,
                        const double width_pips,
                        const double exit_pips,
                        const double add_pips,
                        const double stranded_thresh_pips,
                        const double deadband_pips,
                        const int max_layers,
                        const double lots);

extern bool g_grind_add_due_long;
extern bool g_grind_add_due_short;
extern bool g_grind_add_due_attempted_long;
extern bool g_grind_add_due_attempted_short;
extern double g_grind_engine_add_pips;

//+------------------------------------------------------------------+
void Adr152_TestResetLock()
{
   if(GlobalVariableCheck(GRIND_SLOT_LOCK_GV))
      GlobalVariableDel(GRIND_SLOT_LOCK_GV);
}

//+------------------------------------------------------------------+
void Adr152_TestResetApiCounter()
{
   Grind_ApiCounterTestReset();
   g_grind_api_counter_broken = false;
}

//+------------------------------------------------------------------+
void Adr152_TestPrepareIsolation()
{
   Adr152_TestResetApiCounter();
   Grind_ApiCounterTestSeed(0);
   Adr151_TestResetLock();
   g_grind_cap_test_lock_held = false;
   g_grind_cap_thresh_a = 0.0;
   g_grind_cap_thresh_b = 0.0;
   g_grind_last_feed_tick_msc = 0; // CX11 leaves a synthetic msc that poisons the first OnTickEngine guard
}

//+------------------------------------------------------------------+
void Adr152_TestResetAll()
{
   Adr151_TestResetSlotSeams();
   Adr151_TestResetLock();
   Adr152_TestResetApiCounter();
   Grind_EngineConfigureAdr152(false, 0);
   Grind_Adr152ResetDueFlags();
   g_grind_ent_sent_this_tick = false;
   g_grind_engine_add_pips = 10.0;
}

//+------------------------------------------------------------------+
void Adr152_TestSeedSlotSeams(const long limit,
                              const int used,
                              const int resting_ent = 0)
{
   g_grind_slot_test_active = true;
   g_grind_slot_test_limit = limit;
   g_grind_slot_test_used = used;
   g_grind_slot_test_resting_ent = resting_ent;
}

//+------------------------------------------------------------------+
void Test_T1_try_lock_does_not_block()
{
   Adr152_TestResetLock();
   GlobalVariableTemp(GRIND_SLOT_LOCK_GV);
   GlobalVariableSet(GRIND_SLOT_LOCK_GV, 12345.0);
   double token = 0.0;
   const ulong t0 = GetTickCount64();
   const bool ok = Grind_SlotLockTryAcquire(token);
   const ulong elapsed = GetTickCount64() - t0;
   AssertFalse("T1 try blocked", ok);
   AssertTrue("T1 elapsed under 5ms", elapsed < 5);
   GlobalVariableDel(GRIND_SLOT_LOCK_GV);
   Adr152_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_T1b_single_attempt_lock_returns_false_when_held()
{
   Adr152_TestResetLock();
   double token = 0.0;
   AssertTrue("T1b first acquire", Grind_SlotLockAcquire(token));
   double try_token = 0.0;
   AssertFalse("T1b try blocked", Grind_SlotLockTryAcquire(try_token));
   Grind_SlotLockRelease(token);
   Adr152_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_T1c_single_attempt_lock_releases_only_own_token()
{
   Adr152_TestResetLock();
   double token = 0.0;
   AssertTrue("T1c acquire", Grind_SlotLockTryAcquire(token));
   Grind_SlotLockRelease(token + 1.0);
   double blocked = 0.0;
   AssertFalse("T1c still held", Grind_SlotLockTryAcquire(blocked));
   Grind_SlotLockRelease(token);
   double free = 0.0;
   AssertTrue("T1c released", Grind_SlotLockTryAcquire(free));
   Grind_SlotLockRelease(free);
   Adr152_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_T2_near_entry_allowed_at_ceiling()
{
   Grind_EngineConfigureAdr152(false, GRIND_SLOT_NEAR_RESERVE);
   Adr152_TestSeedSlotSeams(200, 100, 94);
   AssertTrue("T2 near at ceiling",
              Grind_SlotEntryAllowed(Grind_SlotAccountLimit(),
                                     Grind_SlotUsed(),
                                     Grind_SlotRestingEnt(),
                                     true));
   Adr152_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_T2b_far_entry_refused_inside_reserve()
{
   Grind_EngineConfigureAdr152(false, GRIND_SLOT_NEAR_RESERVE);
   Adr152_TestSeedSlotSeams(200, 100, 87);
   AssertFalse("T2b far inside reserve",
               Grind_SlotEntryAllowed(Grind_SlotAccountLimit(),
                                      Grind_SlotUsed(),
                                      Grind_SlotRestingEnt(),
                                      false));
   Adr152_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_T2c_far_entry_allowed_below_reserve()
{
   Grind_EngineConfigureAdr152(false, GRIND_SLOT_NEAR_RESERVE);
   Adr152_TestSeedSlotSeams(200, 100, 86);
   AssertTrue("T2c far below reserve",
              Grind_SlotEntryAllowed(Grind_SlotAccountLimit(),
                                     Grind_SlotUsed(),
                                     Grind_SlotRestingEnt(),
                                     false));
   Adr152_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_T2d_reserve_zero_reproduces_today()
{
   Grind_EngineConfigureAdr152(false, 0);
   Adr152_TestSeedSlotSeams(200, 100, 94);
   AssertTrue("T2d far same as near",
              Grind_SlotEntryAllowed(Grind_SlotAccountLimit(),
                                     Grind_SlotUsed(),
                                     Grind_SlotRestingEnt(),
                                     false));
   AssertTrue("T2d wrapper unchanged",
              Grind_SlotEntryAllowed(Grind_SlotAccountLimit(),
                                     Grind_SlotUsed(),
                                     Grind_SlotRestingEnt()));
   Adr152_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_T2e_near_band_uses_pip_conversion()
{
   const double add_pips = 10.0;
   const double mid = 1.10500;
   const double one_step = Grind_PipsToPrice(add_pips, _Point);
   const double one_pip = Grind_PipsToPrice(1.0, _Point);
   const double near_target = mid - one_step;
   const double far_target = mid - one_step - one_pip;

   AssertTrue("T2e one add step is near",
              Grind_AddTargetNearMarket(near_target, mid, add_pips));
   AssertFalse("T2e one add step plus one pip is far",
               Grind_AddTargetNearMarket(far_target, mid, add_pips));
   Adr152_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_T3_entry_stop_blocks_entry_at_threshold()
{
   Grind_OrderTestReset();
   Grind_TestResetSideState();
   g_grind_order_test_active = true;
   g_grind_cap_thresh_a = 0.0;
   g_grind_cap_thresh_b = 0.0;
   Adr152_TestPrepareIsolation();
   Adr152_TestSeedSlotSeams(200, 100, 0);
   Grind_MarketTestSeed(1.24950, 1.24952, 0);
   Grind_ApiCounterTestSeed(GRIND_DAILY_API_ENTRY_STOP);

   const ulong magic = 22260101UL;
   Grind_TryPlaceL0(g_grind_long, true, 1.24900, magic, "OPT", 12, 0.01);

   AssertTrue("T3 entry blocked", g_grind_order_test_place_calls == 0);
   AssertTrue("T3 stop active", Grind_ApiCounterEntryStopped());

   Grind_MarketTestReset();
   Grind_OrderTestReset();
   Grind_TestResetSideState();
   Adr152_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_T3b_entry_stop_does_not_block_exit()
{
   Adr152_TestPrepareIsolation();
   Adr152_TestSeedSlotSeams(200, 199, 0);
   Grind_ApiCounterTestSeed(GRIND_DAILY_API_ENTRY_STOP);
   AssertTrue("T3b stop active", Grind_ApiCounterEntryStopped());
   AssertTrue("T3b exit ok", Grind_SlotExitAllowed(Grind_SlotAccountLimit(),
                                                   Grind_SlotUsed()));
   Adr152_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_T3c_entry_stop_resets_with_broker_day()
{
   Adr152_TestPrepareIsolation();
   GlobalVariableSet(GRIND_DAILY_API_DATE_GV, Grind_ApiCounterTodayYmd() - 1.0);
   GlobalVariableSet(GRIND_DAILY_API_COUNT_GV, (double)GRIND_DAILY_API_ENTRY_STOP);
   g_grind_api_counter_test_active = false;
   Grind_ApiCounterMaybeReset();
   AssertFalse("T3c stop cleared on rollover", Grind_ApiCounterEntryStopped());
   AssertTrue("T3c count reset", Grind_ApiCounterRead() == 0);
   Adr152_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_T3d_latency_uses_server_clock()
{
   Grind_OrderTestReset();
   Grind_TestResetSideState();
   g_grind_order_test_active = true;
   g_grind_cap_thresh_a = 0.0;
   g_grind_cap_thresh_b = 0.0;
   Adr152_TestSeedSlotSeams(200, 100, 0);
   Grind_MarketTestSeed(1.10450, 1.10452, 0);
   g_grind_ent_sent_this_tick = false;
   g_grind_entry_place_latency_ms = 0;

   ArrayResize(g_grind_long.layers, 1);
   Adr151_TestSetupLongLayer(g_grind_long, 0, 0, 1.10500, 5001, 6101);

   const long deal_msc = 1000000;
   const ulong magic = 22260101UL;
   Grind_MarketTestSeedTimeMsc(deal_msc + 250);
   AssertTrue("T3d placed",
              Grind_SendNextAddEnt(g_grind_long, true, magic, "OPT", 10.0, 12, 0.01,
                                   false, deal_msc));
   AssertTrue("T3d latency 250", g_grind_entry_place_latency_ms == 250);

   Grind_OrderTestReset();
   Grind_TestResetSideState();
   g_grind_order_test_active = true;
   g_grind_cap_thresh_a = 0.0;
   g_grind_cap_thresh_b = 0.0;
   Adr152_TestSeedSlotSeams(200, 100, 0);
   Grind_MarketTestSeed(1.10450, 1.10452, 0);
   g_grind_ent_sent_this_tick = false;
   ArrayResize(g_grind_long.layers, 1);
   Adr151_TestSetupLongLayer(g_grind_long, 0, 0, 1.10500, 5001, 6101);

   Grind_MarketTestSeedTimeMsc(deal_msc - 100);
   AssertTrue("T3d placed again",
              Grind_SendNextAddEnt(g_grind_long, true, magic, "OPT", 10.0, 12, 0.01,
                                   false, deal_msc));
   AssertTrue("T3d latency 0 when clock behind", g_grind_entry_place_latency_ms == 0);

   Grind_MarketTestReset();
   Grind_OrderTestReset();
   Grind_TestResetSideState();
   Adr152_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_T4_due_flag_set_on_ent_fill_only()
{
   Grind_OrderTestReset();
   Grind_DealTestReset();
   Grind_TestResetSideState();
   g_grind_order_test_active = true;
   g_grind_cap_thresh_a = 0.0;
   g_grind_cap_thresh_b = 0.0;
   Grind_EngineConfigureAdr152(true, 0);
   Adr152_TestSeedSlotSeams(200, 100, 0);
   Adr152_TestResetLock();
   double token = 0.0;
   AssertTrue("T4 lock held", Grind_SlotLockAcquire(token));

   ArrayResize(g_grind_long.layers, 1);
   Adr151_TestSetupLongLayer(g_grind_long, 0, 0, 1.10500, 5001, 6101);
   g_grind_deal_test_active = true;
   Grind_TestAppendDeal(9601,
                        GrindCommentBuild("OPT", "L", 1, "ENT"),
                        DEAL_ENTRY_IN,
                        6201,
                        7201,
                        0.0, 0.0, 0.0,
                        1.10400);

   Grind_HandleSideDealFill(g_grind_long, true, 9601, 22260101UL, "OPT",
                            3.0, 4.0, 12, 0.01);

   AssertTrue("T4 due on ent fill", g_grind_add_due_long);
   AssertFalse("T4 short due clear", g_grind_add_due_short);

   Grind_SlotLockRelease(token);

   Grind_TestResetSideState();
   g_grind_deal_test_active = true;
   Grind_TestAppendDeal(9602,
                        GrindCommentBuild("OPT", "L", 0, "EXT"),
                        DEAL_ENTRY_IN,
                        6101,
                        7101,
                        0.0, 0.0, 0.0,
                        1.10530);
   g_grind_add_due_long = false;
   Grind_HandleSideDealFill(g_grind_long, true, 9602, 22260101UL, "OPT",
                            3.0, 4.0, 12, 0.01);
   AssertFalse("T4 ext no due", g_grind_add_due_long);

   Grind_DealTestReset();
   Grind_OrderTestReset();
   Grind_TestResetSideState();
   Adr152_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_T4g_due_flag_set_when_tick_budget_consumed()
{
   Grind_OrderTestReset();
   Grind_DealTestReset();
   Grind_TestResetSideState();
   g_grind_order_test_active = true;
   g_grind_cap_thresh_a = 0.0;
   g_grind_cap_thresh_b = 0.0;
   Grind_EngineConfigureAdr152(true, 0);
   Adr152_TestSeedSlotSeams(200, 100, 0);
   g_grind_ent_sent_this_tick = true;

   ArrayResize(g_grind_long.layers, 1);
   Adr151_TestSetupLongLayer(g_grind_long, 0, 0, 1.10500, 5001, 6101);
   g_grind_deal_test_active = true;
   Grind_TestAppendDeal(9603,
                        GrindCommentBuild("OPT", "L", 1, "ENT"),
                        DEAL_ENTRY_IN,
                        6203,
                        7203,
                        0.0, 0.0, 0.0,
                        1.10400);

   Grind_HandleSideDealFill(g_grind_long, true, 9603, 22260101UL, "OPT",
                            3.0, 4.0, 12, 0.01);

   AssertTrue("T4g due on ent budget consumed", g_grind_add_due_long);

   Grind_DealTestReset();
   Grind_OrderTestReset();
   Grind_TestResetSideState();
   Adr152_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_T4b_due_flag_cleared_on_place()
{
   Grind_OrderTestReset();
   Grind_TestResetSideState();
   g_grind_order_test_active = true;
   Adr152_TestPrepareIsolation();
   Grind_EngineConfigureAdr152(true, 0);
   Adr152_TestSeedSlotSeams(200, 100, 0);
   Grind_MarketTestSeed(1.10450, 1.10452, 0);
   g_grind_add_due_long = true;
   g_grind_engine_add_pips = 10.0;

   ArrayResize(g_grind_long.layers, 1);
   Adr151_TestSetupLongLayer(g_grind_long, 0, 0, 1.10500, 5001, 6101);

   const ulong magic = 22260101UL;
   Grind_OnTickEngine(magic, "OPT", 20.0, 3.0, 10.0, 30.0, 4.0, 12, 0.01);

   AssertTrue("T4b placed", g_grind_order_test_place_calls >= 1);
   AssertFalse("T4b due cleared", g_grind_add_due_long);

   Grind_MarketTestReset();
   Grind_OrderTestReset();
   Grind_TestResetSideState();
   Adr152_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_T4c_due_flag_cleared_at_cap()
{
   Grind_OrderTestReset();
   Grind_TestResetSideState();
   g_grind_order_test_active = true;
   Adr152_TestPrepareIsolation();
   Grind_EngineConfigureAdr152(true, 0);
   g_grind_add_due_long = true;

   ArrayResize(g_grind_long.layers, 2);
   Adr151_TestSetupLongLayer(g_grind_long, 0, 0, 1.10500, 5001, 6101);
   Adr151_TestSetupLongLayer(g_grind_long, 1, 1, 1.10400, 5002, 6102);
   ArrayResize(g_grind_short.layers, 1);
   Adr151_TestSetupLongLayer(g_grind_short, 0, 0, 1.10400, 5003, 6103);
   g_grind_short.layers[0].exit_target =
      Grind_ExitQFormulaTarget(1.10400, 3.0, _Point, false);

   const ulong magic = 22260101UL;
   Grind_OnTickEngine(magic, "OPT", 20.0, 3.0, 10.0, 30.0, 4.0, 2, 0.01);

   AssertFalse("T4c due cleared at cap", g_grind_add_due_long);
   AssertTrue("T4c no long add", Grind_OrderTestCountFleetEnt("L") == 0);

   Grind_OrderTestReset();
   Grind_TestResetSideState();
   Adr152_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_T4d_due_flag_cleared_on_label_mismatch()
{
   Grind_OrderTestReset();
   Grind_TestResetSideState();
   g_grind_order_test_active = true;
   g_grind_cap_thresh_a = 0.0;
   g_grind_cap_thresh_b = 0.0;
   Grind_EngineConfigureAdr152(true, 0);
   Adr152_TestSeedSlotSeams(200, 100, 0);
   Grind_MarketTestSeed(1.10450, 1.10452, 0);
   g_grind_add_due_long = true;

   ArrayResize(g_grind_long.layers, 1);
   Adr151_TestSetupLongLayer(g_grind_long, 0, 0, 1.10500, 5001, 6101);
   g_grind_long.add_pending_ticket = 8801;
   Grind_OrderTestUpsert(8801, (long)22260101UL,
                          GrindCommentBuild("OPT", "L", 9, "ENT"),
                          1.10300, (long)ORDER_TYPE_BUY_LIMIT);

   const ulong magic = 22260101UL;
   Grind_OnTickEngine(magic, "OPT", 20.0, 3.0, 10.0, 30.0, 4.0, 12, 0.01);

   AssertFalse("T4d due cleared on label mismatch", g_grind_add_due_long);

   Grind_MarketTestReset();
   Grind_OrderTestReset();
   Grind_TestResetSideState();
   Adr152_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_T4e_due_flag_cleared_on_init()
{
   g_grind_add_due_long = true;
   g_grind_add_due_short = true;
   g_grind_add_due_attempted_long = true;
   g_grind_add_due_attempted_short = true;
   Grind_Adr152ResetDueFlags();
   AssertFalse("T4e long cleared", g_grind_add_due_long);
   AssertFalse("T4e short cleared", g_grind_add_due_short);
   AssertFalse("T4e attempted long cleared", g_grind_add_due_attempted_long);
   AssertFalse("T4e attempted short cleared", g_grind_add_due_attempted_short);
   Adr152_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_T4f_due_flag_not_retried_twice_in_one_tick()
{
   Grind_OrderTestReset();
   Grind_TestResetSideState();
   g_grind_order_test_active = true;
   g_grind_cap_thresh_a = 0.0;
   g_grind_cap_thresh_b = 0.0;
   Grind_EngineConfigureAdr152(true, 0);
   Adr152_TestSeedSlotSeams(200, 100, 95);
   Grind_MarketTestSeed(1.10450, 1.10452, 0);
   g_grind_add_due_long = true;

   ArrayResize(g_grind_long.layers, 1);
   Adr151_TestSetupLongLayer(g_grind_long, 0, 0, 1.10500, 5001, 6101);

   const ulong magic = 22260101UL;
   Grind_OnTickEngine(magic, "OPT", 20.0, 3.0, 10.0, 30.0, 4.0, 12, 0.01);

   AssertTrue("T4f attempted set", g_grind_add_due_attempted_long);
   AssertFalse("T4f due cleared after one try", g_grind_add_due_long);
   AssertTrue("T4f no place", g_grind_order_test_place_calls == 0);

   Grind_MarketTestReset();
   Grind_OrderTestReset();
   Grind_TestResetSideState();
   Adr152_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_T5_no_double_send_due_plus_ensure()
{
   Grind_OrderTestReset();
   Grind_TestResetSideState();
   g_grind_order_test_active = true;
   g_grind_cap_thresh_a = 0.0;
   g_grind_cap_thresh_b = 0.0;
   Grind_EngineConfigureAdr152(true, 0);
   Adr152_TestSeedSlotSeams(200, 100, 0);
   Grind_MarketTestSeed(1.10450, 1.10452, 0);
   g_grind_add_due_long = true;

   ArrayResize(g_grind_long.layers, 1);
   Adr151_TestSetupLongLayer(g_grind_long, 0, 0, 1.10500, 5001, 6101);

   const ulong magic = 22260101UL;
   Grind_OnTickEngine(magic, "OPT", 20.0, 3.0, 10.0, 30.0, 4.0, 12, 0.01);

   AssertTrue("T5 one ent send", g_grind_order_test_place_calls == 1);

   Grind_MarketTestReset();
   Grind_OrderTestReset();
   Grind_TestResetSideState();
   Adr152_TestResetAll();
}

#endif // FXGRIND_TESTS_ADR152_MQH
