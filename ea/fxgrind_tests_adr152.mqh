//+------------------------------------------------------------------+
//| fxgrind_tests_adr152.mqh — ADR-152 phase 1+2 unit tests          |
//+------------------------------------------------------------------+
#ifndef FXGRIND_TESTS_ADR152_MQH
#define FXGRIND_TESTS_ADR152_MQH

#include "grind_exitq.mqh"

void Grind_EngineConfigureAdr152(const bool fill_time_place,
                                  const int slot_near_reserve,
                                  const double entry_horizon_pips = 0.0);
bool Grind_EntryHorizonActive();
int  Grind_ApplyEntryHorizon(GrindSideState &side,
                             const bool is_long,
                             const ulong magic,
                             const string slot,
                             const double add_pips,
                             const double deadband_pips,
                             const int max_layers,
                             const double lots);
void Grind_Adr152AssertHeldPendingExclusive(const GrindSideState &side);
bool Grind_ReconCheckPendingAddCorrupt(const GrindReconTicket &tickets[],
                                       const int ticket_count,
                                       const ulong add_pending_ticket,
                                       string &reason_out);
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
void Grind_EntryHorizonDailyReset();
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
   Grind_EntryHorizonDailyReset();
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
   Grind_EngineConfigureAdr152(false, 0, 0.0);
   Grind_Adr152ResetDueFlags();
   g_grind_ent_sent_this_tick = false;
   g_grind_engine_add_pips = 10.0;
}

//+------------------------------------------------------------------+
void Adr152_TestResetHorizonSide(GrindSideState &side)
{
   side.add_held = false;
   side.add_held_target = 0.0;
   side.entry_transitions_used = 0;
   side.add_gap_missed = 0;
   side.entry_transitions_exhausted = false;
   side.add_gap_beyond_target = false;
}

//+------------------------------------------------------------------+
void Adr152_TestSeedMid(const double mid, const double spread = 0.00002)
{
   Grind_MarketTestSeed(mid - spread * 0.5, mid + spread * 0.5, 0);
}

//+------------------------------------------------------------------+
void Adr152_TestHorizonSetupLong(const double anchor_entry,
                                 const double add_pips,
                                 const double mid,
                                 const double horizon_pips)
{
   Grind_OrderTestReset();
   Grind_TestResetSideState();
   Adr152_TestResetHorizonSide(g_grind_long);
   g_grind_order_test_active = true;
   g_grind_cap_thresh_a = 0.0;
   g_grind_cap_thresh_b = 0.0;
   Adr152_TestPrepareIsolation();
   Grind_EngineConfigureAdr152(true, 0, horizon_pips);
   Adr152_TestSeedSlotSeams(200, 100, 0);
   Adr152_TestSeedMid(mid);
   g_grind_engine_add_pips = add_pips;
   ArrayResize(g_grind_long.layers, 1);
   Adr151_TestSetupLongLayer(g_grind_long, 0, 0, anchor_entry, 5001, 6101);
}

//+------------------------------------------------------------------+
int Adr152_TestHorizonTick(const ulong magic = 22260101UL)
{
   g_grind_ent_sent_this_tick = false;
   return Grind_ApplyEntryHorizon(g_grind_long, true, magic, "OPT",
                                  g_grind_engine_add_pips, 4.0, 12, 0.01);
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

//+------------------------------------------------------------------+
// ADR-152 Phase 2 horizon tests (written against stub; must fail until commit 2)
//+------------------------------------------------------------------+
void Test_T4a_horizon_floor_rest()
{
   const double add_pips = 10.0;
   const double H = 20.0;
   const double anchor = 1.10500;
   const double target = Grind_AddTargetPrice(anchor, add_pips, _Point, 1);
   const double floor_dist = Grind_PipsToPrice(add_pips, _Point);
   const double Hc_dist = Grind_PipsToPrice(H * 2.0, _Point);
   AssertTrue("T4a floor inside Hc", floor_dist + GRIND_PRICE_EPS < Hc_dist);
   const double mid = target + floor_dist - GRIND_PRICE_EPS * 0.5;

   Adr152_TestHorizonSetupLong(anchor, add_pips, mid, H);
   g_grind_long.add_held = true;
   g_grind_long.add_pending_ticket = 0;

   Adr152_TestHorizonTick();
   AssertTrue("T4a floor places", g_grind_order_test_place_calls >= 1);
   AssertFalse("T4a floor clears held", g_grind_long.add_held);

   Grind_MarketTestReset();
   Grind_OrderTestReset();
   Grind_TestResetSideState();
   Adr152_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_T4b_horizon_place_at_H()
{
   const double add_pips = 10.0;
   const double H = 20.0;
   const double anchor = 1.10500;
   const double target = Grind_AddTargetPrice(anchor, add_pips, _Point, 1);
   const double H_dist = Grind_PipsToPrice(H, _Point);
   const double mid = target + H_dist;

   Adr152_TestHorizonSetupLong(anchor, add_pips, mid, H);
   Adr152_TestHorizonTick();
   AssertTrue("T4b place at H", g_grind_order_test_place_calls >= 1);
   AssertFalse("T4b not held", g_grind_long.add_held);

   Grind_MarketTestReset();
   Grind_OrderTestReset();
   Grind_TestResetSideState();
   Adr152_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_T4c_horizon_cancel_at_Hc()
{
   const double add_pips = 10.0;
   const double H = 20.0;
   const double anchor = 1.10500;
   const double target = Grind_AddTargetPrice(anchor, add_pips, _Point, 1);
   const double Hc_dist = Grind_PipsToPrice(H * 2.0, _Point);
   const double mid = target + Hc_dist + _Point;

   Adr152_TestHorizonSetupLong(anchor, add_pips, mid, H);
   g_grind_long.add_pending_ticket = 8801;
   Grind_OrderTestUpsert(8801, (long)22260101UL,
                          GrindCommentBuild("OPT", "L", 1, "ENT"),
                          target, (long)ORDER_TYPE_BUY_LIMIT);

   Adr152_TestHorizonTick();
   AssertTrue("T4c cancel removes", g_grind_order_test_remove_calls >= 1);
   AssertTrue("T4c sets held", g_grind_long.add_held);
   AssertTrue("T4c pending cleared", g_grind_long.add_pending_ticket == 0);

   Grind_MarketTestReset();
   Grind_OrderTestReset();
   Grind_TestResetSideState();
   Adr152_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_T4d_horizon_no_flicker()
{
   const double add_pips = 10.0;
   const double H = 20.0;
   const double anchor = 1.10500;
   const double target = Grind_AddTargetPrice(anchor, add_pips, _Point, 1);
   const double H_dist = Grind_PipsToPrice(H, _Point);
   const double Hc_dist = Grind_PipsToPrice(H * 2.0, _Point);
   const double mid_place = target + H_dist * 0.5;
   const double mid_hyst = target + (H_dist + Hc_dist) * 0.5;

   Adr152_TestHorizonSetupLong(anchor, add_pips, mid_place, H);
   Adr152_TestHorizonTick();
   const int transitions_after_place = g_grind_long.entry_transitions_used;
   AssertTrue("T4d initial place", g_grind_order_test_place_calls >= 1);
   AssertTrue("T4d one transition on place", transitions_after_place == 1);

   Adr152_TestSeedMid(mid_hyst);
   Adr152_TestHorizonTick();
   AssertTrue("T4d hysteresis no extra", g_grind_long.entry_transitions_used == transitions_after_place);
   AssertTrue("T4d still resting", g_grind_long.add_pending_ticket != 0);

   Adr152_TestSeedMid(mid_place);
   Adr152_TestHorizonTick();
   AssertTrue("T4d return no extra", g_grind_long.entry_transitions_used == transitions_after_place);
   AssertTrue("T4d still one place call", g_grind_order_test_place_calls == 1);

   Grind_MarketTestReset();
   Grind_OrderTestReset();
   Grind_TestResetSideState();
   Adr152_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_T4e_horizon_off_is_phase1()
{
   const double add_pips = 10.0;
   const double anchor = 1.10500;
   const double target = Grind_AddTargetPrice(anchor, add_pips, _Point, 1);
   const double Hc_dist = Grind_PipsToPrice(40.0, _Point);
   const double mid = target + Hc_dist + _Point;

   Adr152_TestHorizonSetupLong(anchor, add_pips, mid, 0.0);
   AssertFalse("T4e horizon off", Grind_EntryHorizonActive());
   Grind_EnsureAddNext(g_grind_long, true, 22260101UL, "OPT",
                       add_pips, 4.0, 12, 0.01);
   AssertTrue("T4e phase1 places far", g_grind_order_test_place_calls >= 1);
   AssertFalse("T4e never held", g_grind_long.add_held);

   Grind_MarketTestReset();
   Grind_OrderTestReset();
   Grind_TestResetSideState();
   Adr152_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_T5_horizon_transition_budget_exhausted()
{
   const double add_pips = 10.0;
   const double H = 20.0;
   const double anchor = 1.10500;
   const double target = Grind_AddTargetPrice(anchor, add_pips, _Point, 1);
   const double Hc_dist = Grind_PipsToPrice(H * 2.0, _Point);
   const double mid = target + Hc_dist + _Point;

   Adr152_TestHorizonSetupLong(anchor, add_pips, mid, H);
   g_grind_long.add_pending_ticket = 8802;
   g_grind_long.entry_transitions_used = 20;
   Grind_OrderTestUpsert(8802, (long)22260101UL,
                          GrindCommentBuild("OPT", "L", 1, "ENT"),
                          target, (long)ORDER_TYPE_BUY_LIMIT);

   Adr152_TestHorizonTick();
   AssertTrue("T5 stays resting", g_grind_long.add_pending_ticket != 0);
   AssertFalse("T5 not held", g_grind_long.add_held);
   AssertTrue("T5 exhausted flag", g_grind_long.entry_transitions_exhausted);
   AssertTrue("T5 no cancel", g_grind_order_test_remove_calls == 0);

   Grind_MarketTestReset();
   Grind_OrderTestReset();
   Grind_TestResetSideState();
   Adr152_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_T9_held_add_reconstruction()
{
   GrindReconTicket tickets[1];
   tickets[0].ticket = 6101;
   tickets[0].magic = 22260101UL;
   tickets[0].comment = GrindCommentBuild("OPT", "L", 0, "EXT");
   tickets[0].price = 1.10530;
   tickets[0].kind = GRIND_RECON_TICKET_ORDER;

   string reason = "";
   AssertTrue("T9 pending add ok at zero",
              Grind_ReconCheckPendingAddCorrupt(tickets, 1, 0, reason));
   AssertTrue("T9 reason empty", reason == "");

   GrindReconLayerScratch long_scratch[1];
   long_scratch[0].layer_index = 0;
   long_scratch[0].entry_price = 1.10500;
   long_scratch[0].has_position = true;
   long_scratch[0].position_id = 5001;
   long_scratch[0].has_exit_order = true;
   long_scratch[0].has_exit_position = false;
   long_scratch[0].exit_target = 1.10530;
   long_scratch[0].exit_order_ticket = 6101;
   long_scratch[0].exit_position_id = 0;

   int long_ranks[1];
   long_ranks[0] = 0;
   int short_ranks[];
   ArrayResize(short_ranks, 0);

   g_grind_long.add_held = true;
   g_grind_long.add_pending_ticket = 0;
   g_grind_long.add_held_target = 1.10400;
   AssertTrue("T9 invariants with held add",
              Grind_ReconCheckInvariants(long_scratch, 1, long_ranks,
                                         long_scratch, 0, short_ranks,
                                         3.0, _Point, 12, reason));
   AssertTrue("T9 no I-marker", reason == "");

   Grind_TestResetSideState();
   Adr152_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_T10_horizon_gap_missed_once()
{
   const double add_pips = 10.0;
   const double H = 20.0;
   const double anchor = 1.10500;
   const double target = Grind_AddTargetPrice(anchor, add_pips, _Point, 1);

   Adr152_TestHorizonSetupLong(anchor, add_pips, target + Grind_PipsToPrice(H * 2.0, _Point), H);
   g_grind_long.add_held = true;
   g_grind_long.add_held_target = target;
   g_grind_long.add_gap_beyond_target = false;

   Adr152_TestSeedMid(target + Grind_PipsToPrice(1.0, _Point));
   Adr152_TestHorizonTick();
   AssertTrue("T10 gap still zero above", g_grind_long.add_gap_missed == 0);

   Adr152_TestSeedMid(target - Grind_PipsToPrice(1.0, _Point));
   Adr152_TestHorizonTick();
   AssertTrue("T10 gap once below", g_grind_long.add_gap_missed == 1);

   Adr152_TestSeedMid(target - Grind_PipsToPrice(2.0, _Point));
   Adr152_TestHorizonTick();
   AssertTrue("T10 gap still one", g_grind_long.add_gap_missed == 1);

   Grind_MarketTestReset();
   Grind_OrderTestReset();
   Grind_TestResetSideState();
   Adr152_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_T_invariant_held_pending_exclusive()
{
   g_grind_order_test_active = true;
   g_grind_order_test_last_critical = "";
   g_grind_long.add_held = true;
   g_grind_long.add_pending_ticket = 8803;
   Grind_Adr152AssertHeldPendingExclusive(g_grind_long);
   AssertTrue("T-inv violation recorded",
              g_grind_order_test_last_critical == "ADR152_HELD_PENDING_EXCLUSIVE");

   g_grind_order_test_active = true;
   g_grind_order_test_last_critical = "";
   g_grind_long.add_held = false;
   g_grind_long.add_pending_ticket = 0;
   Grind_Adr152AssertHeldPendingExclusive(g_grind_long);
   AssertTrue("T-inv clean silent", g_grind_order_test_last_critical == "");

   Grind_TestResetSideState();
   Adr152_TestResetAll();
}

#endif // FXGRIND_TESTS_ADR152_MQH
