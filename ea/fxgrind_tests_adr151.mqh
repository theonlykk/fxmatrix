//+------------------------------------------------------------------+
//| fxgrind_tests_adr151.mqh — ADR-151 phase A unit tests (41)       |
//+------------------------------------------------------------------+
#ifndef FXGRIND_TESTS_ADR151_MQH
#define FXGRIND_TESTS_ADR151_MQH

#include "grind_exitq.mqh"

// Commit 2 symbols (stubs allowed in commit 1).
void Grind_ExitQManageSide(GrindSideState &side,
                           const bool is_long,
                           const ulong magic,
                           const string slot,
                           const double lots,
                           const double exit_pips);
void Grind_CancelOwnEntryOrders(const ulong magic, const string slot);
bool Grind_ReconCheckInvariants(const GrindReconLayerScratch &long_layers[],
                                const int long_count,
                                const int &long_ranks[],
                                const GrindReconLayerScratch &short_layers[],
                                const int short_count,
                                const int &short_ranks[],
                                const double exit_pips,
                                const double point,
                                const int max_layers,
                                string &reason_out);

//+------------------------------------------------------------------+
void Adr151_TestResetSlotSeams()
{
   g_grind_slot_test_active = false;
   g_grind_slot_test_limit = 0;
   g_grind_slot_test_used = 0;
   g_grind_slot_test_resting_ent = 0;
}

//+------------------------------------------------------------------+
void Adr151_TestResetExitQ()
{
   g_grind_exitq_test_k = -1;
}

//+------------------------------------------------------------------+
void Adr151_TestResetLock()
{
   if(GlobalVariableCheck(GRIND_SLOT_LOCK_GV))
      GlobalVariableDel(GRIND_SLOT_LOCK_GV);
}

//+------------------------------------------------------------------+
void Adr151_TestResetAll()
{
   Adr151_TestResetSlotSeams();
   Adr151_TestResetExitQ();
   Adr151_TestResetLock();
   g_grind_ent_sent_this_tick = false;
}

//+------------------------------------------------------------------+
void Adr151_TestSetupLongLayer(GrindSideState &side,
                               const int array_idx,
                               const int layer_index,
                               const double entry_price,
                               const ulong position_ticket,
                               const ulong exit_order_ticket,
                               const double exit_pips = 3.0)
{
   const int need = array_idx + 1;
   if(ArraySize(side.layers) < need)
      ArrayResize(side.layers, need);
   side.layers[array_idx].entry_price = entry_price;
   side.layers[array_idx].layer_index = layer_index;
   side.layers[array_idx].position_ticket = position_ticket;
   side.layers[array_idx].exit_order_ticket = exit_order_ticket;
   side.layers[array_idx].exit_position_ticket = 0;
   side.layers[array_idx].exit_target =
      Grind_ExitQFormulaTarget(entry_price, exit_pips, _Point, true);
}

//+------------------------------------------------------------------+
void Adr151_TestSetupMq7Fixture(GrindSideState &side)
{
   ArrayResize(side.layers, 5);
   Adr151_TestSetupLongLayer(side, 0, 0, 1.10500, 5001, 6001);
   Adr151_TestSetupLongLayer(side, 1, 1, 1.10400, 5002, 6002);
   Adr151_TestSetupLongLayer(side, 2, 2, 1.10300, 5003, 0);
   Adr151_TestSetupLongLayer(side, 3, 3, 1.10200, 5004, 0);
   Adr151_TestSetupLongLayer(side, 4, 4, 1.10100, 5005, 0);
}

//+------------------------------------------------------------------+
void Adr151_TestSeedSlotSeams(const long limit,
                              const int used,
                              const int resting_ent = 0)
{
   g_grind_slot_test_active = true;
   g_grind_slot_test_limit = limit;
   g_grind_slot_test_used = used;
   g_grind_slot_test_resting_ent = resting_ent;
}

//+------------------------------------------------------------------+
void Test_EQ1_RanksLongAscendingEntry()
{
   const double entries[3] = {1.10500, 1.10400, 1.10300};
   const int layer_indices[3] = {0, 1, 2};
   int ranks[];
   Grind_ExitQRanks(entries, layer_indices, 3, true, ranks);
   AssertTrue("EQ1 size", ArraySize(ranks) == 3);
   AssertTrue("EQ1 nearest", ranks[2] == 0);
   AssertTrue("EQ1 mid", ranks[1] == 1);
   AssertTrue("EQ1 farthest", ranks[0] == 2);
   Adr151_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_EQ2_RanksShortDescendingEntry()
{
   const double entries[3] = {1.09500, 1.09600, 1.09700};
   const int layer_indices[3] = {0, 1, 2};
   int ranks[];
   Grind_ExitQRanks(entries, layer_indices, 3, false, ranks);
   AssertTrue("EQ2 size", ArraySize(ranks) == 3);
   // fix1: shorts rank by descending entry; 1.09700 is nearest.
   AssertTrue("EQ2 nearest", ranks[2] == 0);
   AssertTrue("EQ2 mid", ranks[1] == 1);
   AssertTrue("EQ2 farthest", ranks[0] == 2);
   Adr151_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_EQ3_RankTieByLayerIndex()
{
   const double entries[2] = {1.10400, 1.10400};
   const int layer_indices[2] = {3, 1};
   int ranks[];
   Grind_ExitQRanks(entries, layer_indices, 2, true, ranks);
   AssertTrue("EQ3 lower idx wins", ranks[1] == 0);
   AssertTrue("EQ3 higher idx loses", ranks[0] == 1);
   Adr151_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_EQ4_RequiredAllowedBands()
{
   Adr151_TestResetExitQ();
   AssertTrue("EQ4 req0", Grind_ExitQRequired(0));
   AssertFalse("EQ4 req1", Grind_ExitQRequired(1));
   AssertTrue("EQ4 allow0", Grind_ExitQAllowed(0));
   AssertFalse("EQ4 allow1", Grind_ExitQAllowed(1));
   for(int rank = 0; rank <= 4; rank++) {
      const bool req = Grind_ExitQRequired(rank);
      const bool allow = Grind_ExitQAllowed(rank);
      AssertTrue(StringFormat("EQ4 agree r%d", rank), req == allow);
   }
   Adr151_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_EQ5_KOverrideAllRanksRequired()
{
   g_grind_exitq_test_k = 99;
   AssertTrue("EQ5 req0 k99", Grind_ExitQRequired(0));
   AssertTrue("EQ5 req11 k99", Grind_ExitQRequired(11));
   AssertTrue("EQ5 allow11 k99", Grind_ExitQAllowed(11));
   g_grind_exitq_test_k = -1;
   AssertFalse("EQ5 req2 default", Grind_ExitQRequired(2));
   Adr151_TestResetAll();
}

//+------------------------------------------------------------------+
int Adr151_TestCountRestingExits(const GrindSideState &side)
{
   int resting = 0;
   for(int i = 0; i < ArraySize(side.layers); i++) {
      if(side.layers[i].exit_order_ticket != 0)
         resting++;
   }
   return resting;
}

//+------------------------------------------------------------------+
void Test_EQ_K1a_one_resting_exit_at_rank_zero()
{
   Grind_OrderTestReset();
   Grind_TestResetSideState();
   g_grind_order_test_active = true;
   Adr151_TestSeedSlotSeams(200, 100, 0);

   ArrayResize(g_grind_long.layers, 3);
   Adr151_TestSetupLongLayer(g_grind_long, 0, 0, 1.10500, 5001, 0);
   Adr151_TestSetupLongLayer(g_grind_long, 1, 1, 1.10400, 5002, 0);
   Adr151_TestSetupLongLayer(g_grind_long, 2, 2, 1.10300, 5003, 0);

   Grind_ExitQManageSide(g_grind_long, true, 22260101UL, "OPT", 0.01, 3.0);

   AssertTrue("EQ-K1a one resting", Adr151_TestCountRestingExits(g_grind_long) == 1);
   AssertTrue("EQ-K1a rank0 exit", g_grind_long.layers[2].exit_order_ticket != 0);
   AssertTrue("EQ-K1a rank1 bare", g_grind_long.layers[1].exit_order_ticket == 0);
   AssertTrue("EQ-K1a rank2 bare", g_grind_long.layers[0].exit_order_ticket == 0);

   Grind_OrderTestReset();
   Grind_TestResetSideState();
   Adr151_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_EQ_K1b_one_cancel_per_add_fill_not_per_tick()
{
   Grind_OrderTestReset();
   Grind_TestResetSideState();
   g_grind_order_test_active = true;
   Adr151_TestSeedSlotSeams(200, 100, 0);

   ArrayResize(g_grind_long.layers, 3);
   Adr151_TestSetupLongLayer(g_grind_long, 0, 0, 1.10500, 5001, 0);
   Adr151_TestSetupLongLayer(g_grind_long, 1, 1, 1.10400, 5002, 0);
   Adr151_TestSetupLongLayer(g_grind_long, 2, 2, 1.10300, 5003, 0);
   Grind_ExitQManageSide(g_grind_long, true, 22260101UL, "OPT", 0.01, 3.0);

   ArrayResize(g_grind_long.layers, 4);
   Adr151_TestSetupLongLayer(g_grind_long, 3, 3, 1.10200, 5004, 0);

   g_grind_order_test_place_calls = 0;
   g_grind_order_test_remove_calls = 0;
   Grind_ExitQManageSide(g_grind_long, true, 22260101UL, "OPT", 0.01, 3.0);

   AssertTrue("EQ-K1b one place", g_grind_order_test_place_calls == 1);
   AssertTrue("EQ-K1b one cancel", g_grind_order_test_remove_calls == 1);
   AssertTrue("EQ-K1b new rank0 exit", g_grind_long.layers[3].exit_order_ticket != 0);
   AssertTrue("EQ-K1b old rank0 bare", g_grind_long.layers[2].exit_order_ticket == 0);

   g_grind_order_test_place_calls = 0;
   g_grind_order_test_remove_calls = 0;
   Grind_ExitQManageSide(g_grind_long, true, 22260101UL, "OPT", 0.01, 3.0);
   AssertTrue("EQ-K1b no churn tick2", g_grind_order_test_place_calls == 0);
   AssertTrue("EQ-K1b no cancel tick2", g_grind_order_test_remove_calls == 0);

   Grind_OrderTestReset();
   Grind_TestResetSideState();
   Adr151_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_EQ_K1c_i3_requires_rank_zero_only()
{
   Grind_CarryTestReset();
   GrindReconLayerScratch layers[3];
   Grind_TestInitLayerScratch(layers[0], 0, 1.10500, 5001UL);
   layers[0].has_exit_order = false;
   Grind_TestInitLayerScratch(layers[1], 1, 1.10400, 5002UL);
   layers[1].has_exit_order = false;
   Grind_TestInitLayerScratch(layers[2], 2, 1.10300, 5003UL);
   layers[2].has_exit_order = true;
   layers[2].exit_order_ticket = 6103;
   layers[2].exit_target = 1.10330;

   int long_ranks[3];
   long_ranks[0] = 2;
   long_ranks[1] = 1;
   long_ranks[2] = 0;
   GrindReconLayerScratch empty[];
   int short_ranks[];
   string reason = "";
   AssertTrue("EQ-K1c pass held",
              Grind_ReconCheckInvariants(layers, 3, long_ranks, empty, 0, short_ranks,
                                         3.0, 0.00001, 12, reason));
   Print("EQ-K1c DIAG reason=", reason,
         " shift=", Grind_CarryShiftGetForRecon(5003UL),
         " expected=", Grind_ExitQFormulaTarget(1.10300, 3.0, 0.00001, true),
         " target=", layers[2].exit_target,
         " cover2=", Grind_ReconLayerHasExitCoverage(layers[2]),
         " req0=", Grind_ExitQRequired(0),
         " req1=", Grind_ExitQRequired(1));

   layers[2].has_exit_order = false;
   AssertFalse("EQ-K1c fail rank0",
               Grind_ReconCheckInvariants(layers, 3, long_ranks, empty, 0, short_ranks,
                                          3.0, 0.00001, 12, reason));
   AssertEqStr("EQ-K1c reason", reason, "I3_LONG_NAKED");

   Adr151_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_EQ_CLAMP1_passed_target_increments_counter()
{
   Grind_OrderTestReset();
   Grind_TestResetSideState();
   Grind_CarryTestReset();
   g_grind_order_test_active = true;
   Adr151_TestSeedSlotSeams(200, 100, 0);
   Grind_MarketTestSeed(1.25098, 1.25100, 0, 0);

   const double entry = 1.25000;
   const double exit_pips = 3.0;
   const double formula = Grind_ExitQFormulaTarget(entry, exit_pips, _Point, true);
   const double min_dist = Grind_CarryMinPassiveDistance(_Point, 0, 0);
   const double expected = 1.25100 + min_dist;
   const int prom_before = g_grind_long.exit_clamped_promotions;

   ArrayResize(g_grind_long.layers, 1);
   Adr151_TestSetupLongLayer(g_grind_long, 0, 0, entry, 7001, 0);

   Grind_ExitQManageSide(g_grind_long, true, 22260101UL, "OPT", 0.01, exit_pips);

   AssertTrue("EQ-CLAMP1 placed", g_grind_order_test_place_calls == 1);
   AssertNear("EQ-CLAMP1 price", g_grind_order_test_last_placed_price, expected, 1e-12);
   AssertTrue("EQ-CLAMP1 better", g_grind_order_test_last_placed_price > formula);
   AssertTrue("EQ-CLAMP1 counter",
              g_grind_long.exit_clamped_promotions == prom_before + 1);

   Grind_CarryTestReset();
   Grind_MarketTestReset();
   Grind_OrderTestReset();
   Grind_TestResetSideState();
   Adr151_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_EQ_CLAMP2_unpassed_target_no_counter()
{
   Grind_OrderTestReset();
   Grind_TestResetSideState();
   Grind_CarryTestReset();
   g_grind_order_test_active = true;
   Adr151_TestSeedSlotSeams(200, 100, 0);
   Grind_MarketTestSeed(1.24998, 1.25000, 0, 0);

   const double entry = 1.25000;
   const double exit_pips = 3.0;
   const double formula = Grind_ExitQFormulaTarget(entry, exit_pips, _Point, true);
   const int prom_before = g_grind_long.exit_clamped_promotions;

   ArrayResize(g_grind_long.layers, 1);
   Adr151_TestSetupLongLayer(g_grind_long, 0, 0, entry, 7002, 0);

   Grind_ExitQManageSide(g_grind_long, true, 22260101UL, "OPT", 0.01, exit_pips);

   AssertTrue("EQ-CLAMP2 placed", g_grind_order_test_place_calls == 1);
   AssertNear("EQ-CLAMP2 formula", g_grind_order_test_last_placed_price, formula, 1e-12);
   AssertTrue("EQ-CLAMP2 counter",
              g_grind_long.exit_clamped_promotions == prom_before);

   Grind_CarryTestReset();
   Grind_MarketTestReset();
   Grind_OrderTestReset();
   Grind_TestResetSideState();
   Adr151_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_SG1_ExitAllowedAtOneFree()
{
   Adr151_TestSeedSlotSeams(200, 199);
   AssertTrue("SG1 exit ok", Grind_SlotExitAllowed(Grind_SlotAccountLimit(),
                                                   Grind_SlotUsed()));
   Adr151_TestSeedSlotSeams(200, 200);
   AssertFalse("SG1 exit full", Grind_SlotExitAllowed(Grind_SlotAccountLimit(),
                                                       Grind_SlotUsed()));
   Adr151_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_SG2_EntryBlockedBelowMargin()
{
   Adr151_TestSeedSlotSeams(200, 100, 95);
   AssertFalse("SG2 entry blocked",
               Grind_SlotEntryAllowed(Grind_SlotAccountLimit(),
                                      Grind_SlotUsed(),
                                      Grind_SlotRestingEnt()));
   Adr151_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_SG3_EntryAllowedAtMargin()
{
   Adr151_TestSeedSlotSeams(200, 100, 94);
   AssertTrue("SG3 entry ok",
              Grind_SlotEntryAllowed(Grind_SlotAccountLimit(),
                                     Grind_SlotUsed(),
                                     Grind_SlotRestingEnt()));
   Adr151_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_SG4_LimitZeroDisablesGuard()
{
   Adr151_TestSeedSlotSeams(0, 999, 999);
   AssertTrue("SG4 exit", Grind_SlotExitAllowed(Grind_SlotAccountLimit(),
                                                Grind_SlotUsed()));
   AssertTrue("SG4 entry", Grind_SlotEntryAllowed(Grind_SlotAccountLimit(),
                                                  Grind_SlotUsed(),
                                                  Grind_SlotRestingEnt()));
   Adr151_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_SG5_RestingEntCountsUnparseableFleetOrder()
{
   Grind_OrderTestReset();
   g_grind_order_test_active = true;
   Grind_OrderTestUpsert(8101, (long)22260101UL, "GRIND|OPT|L|BAD",
                         1.25000, (long)ORDER_TYPE_BUY_LIMIT);
   Grind_OrderTestUpsert(8102, (long)22260101UL,
                         GrindCommentBuild("OPT", "L", 0, "EXT"),
                         1.25030, (long)ORDER_TYPE_SELL_LIMIT);
   AssertTrue("SG5 count", Grind_SlotRestingEnt() == 1);
   Grind_OrderTestReset();
   Adr151_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_SG6_RestingEntIgnoresExtAndNonFleet()
{
   Grind_OrderTestReset();
   g_grind_order_test_active = true;
   Grind_OrderTestUpsert(8201, (long)22260101UL,
                         GrindCommentBuild("OPT", "L", 1, "ENT"),
                         1.24900, (long)ORDER_TYPE_BUY_LIMIT);
   Grind_OrderTestUpsert(8202, (long)22260101UL,
                         GrindCommentBuild("OPT", "L", 0, "EXT"),
                         1.25030, (long)ORDER_TYPE_SELL_LIMIT);
   Grind_OrderTestUpsert(8203, (long)99999999UL,
                         GrindCommentBuild("OPT", "L", 2, "ENT"),
                         1.24800, (long)ORDER_TYPE_BUY_LIMIT);
   AssertTrue("SG6 count", Grind_SlotRestingEnt() == 1);
   Grind_OrderTestReset();
   Adr151_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_LK1_AcquireReleaseRoundTrip()
{
   Adr151_TestResetLock();
   double token = 0.0;
   AssertTrue("LK1 acquire", Grind_SlotLockAcquire(token));
   AssertTrue("LK1 held", GlobalVariableGet(GRIND_SLOT_LOCK_GV) == token);
   Grind_SlotLockRelease(token);
   AssertTrue("LK1 released", GlobalVariableGet(GRIND_SLOT_LOCK_GV) == 0.0);
   Adr151_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_LK2_SecondAcquireFailsWhileHeld()
{
   Adr151_TestResetLock();
   double token = 0.0;
   AssertTrue("LK2 first", Grind_SlotLockAcquire(token));
   AssertFalse("LK2 second", Grind_SlotLockAcquire(token));
   Grind_SlotLockRelease(token);
   Adr151_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_LK3_StaleLockStolen()
{
   Adr151_TestResetLock();
   GlobalVariableTemp(GRIND_SLOT_LOCK_GV);
   const double stale = (double)GetTickCount64() - (double)GRIND_SLOT_LOCK_STALE_MS - 1000.0;
   GlobalVariableSet(GRIND_SLOT_LOCK_GV, stale);
   double token = 0.0;
   AssertTrue("LK3 steal", Grind_SlotLockAcquire(token));
   AssertTrue("LK3 new token", token != stale);
   Grind_SlotLockRelease(token);
   Adr151_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_LK4_ReleaseOnlyIfTokenMatches()
{
   Adr151_TestResetLock();
   double token = 0.0;
   AssertTrue("LK4 acquire", Grind_SlotLockAcquire(token));
   Grind_SlotLockRelease(token + 1.0);
   AssertTrue("LK4 still held", GlobalVariableGet(GRIND_SLOT_LOCK_GV) == token);
   Grind_SlotLockRelease(token);
   AssertTrue("LK4 released", GlobalVariableGet(GRIND_SLOT_LOCK_GV) == 0.0);
   Adr151_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_MQ1_TrimCancelsBeyondAllowedBand()
{
   Grind_OrderTestReset();
   Grind_TestResetSideState();
   g_grind_order_test_active = true;
   Adr151_TestSeedSlotSeams(200, 100, 0);

   ArrayResize(g_grind_long.layers, 4);
   Adr151_TestSetupLongLayer(g_grind_long, 0, 0, 1.10500, 5001, 6101);
   Adr151_TestSetupLongLayer(g_grind_long, 1, 1, 1.10400, 5002, 6102);
   Adr151_TestSetupLongLayer(g_grind_long, 2, 2, 1.10300, 5003, 6103);
   Adr151_TestSetupLongLayer(g_grind_long, 3, 3, 1.10200, 5004, 6104);
   Grind_OrderTestUpsert(6101, (long)22260101UL,
                         GrindCommentBuild("OPT", "L", 0, "EXT"),
                         1.10530, (long)ORDER_TYPE_SELL_LIMIT);
   Grind_OrderTestUpsert(6102, (long)22260101UL,
                         GrindCommentBuild("OPT", "L", 1, "EXT"),
                         1.10430, (long)ORDER_TYPE_SELL_LIMIT);
   Grind_OrderTestUpsert(6103, (long)22260101UL,
                         GrindCommentBuild("OPT", "L", 2, "EXT"),
                         1.10330, (long)ORDER_TYPE_SELL_LIMIT);
   Grind_OrderTestUpsert(6104, (long)22260101UL,
                         GrindCommentBuild("OPT", "L", 3, "EXT"),
                         1.10230, (long)ORDER_TYPE_SELL_LIMIT);

   Grind_ExitQManageSide(g_grind_long, true, 22260101UL, "OPT", 0.01, 3.0);

   AssertTrue("MQ1 cancel thrice", g_grind_order_test_remove_calls == 3);
   AssertTrue("MQ1 rank0 kept", g_grind_long.layers[3].exit_order_ticket != 0);
   AssertTrue("MQ1 rank1 bare", g_grind_long.layers[2].exit_order_ticket == 0);
   AssertTrue("MQ1 rank2 bare", g_grind_long.layers[1].exit_order_ticket == 0);
   AssertTrue("MQ1 rank3 bare", g_grind_long.layers[0].exit_order_ticket == 0);
   AssertTrue("MQ1 no place", g_grind_order_test_place_calls == 0);

   Grind_OrderTestReset();
   Grind_TestResetSideState();
   Adr151_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_MQ2_ReleasePlacesRequiredMissing()
{
   Grind_OrderTestReset();
   Grind_TestResetSideState();
   g_grind_order_test_active = true;
   Adr151_TestSeedSlotSeams(200, 100, 0);

   ArrayResize(g_grind_long.layers, 3);
   Adr151_TestSetupLongLayer(g_grind_long, 0, 0, 1.10500, 5001, 6101);
   Adr151_TestSetupLongLayer(g_grind_long, 1, 1, 1.10400, 5002, 0);
   Adr151_TestSetupLongLayer(g_grind_long, 2, 2, 1.10300, 5003, 0);

   Grind_ExitQManageSide(g_grind_long, true, 22260101UL, "OPT", 0.01, 3.0);

   AssertTrue("MQ2 place once", g_grind_order_test_place_calls == 1);
   AssertTrue("MQ2 rank0 exit", g_grind_long.layers[2].exit_order_ticket != 0);
   AssertTrue("MQ2 rank1 bare", g_grind_long.layers[1].exit_order_ticket == 0);
   AssertTrue("MQ2 no cancel", g_grind_order_test_remove_calls == 0);

   Grind_OrderTestReset();
   Grind_TestResetSideState();
   Adr151_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_MQ3_TrimRunsBeforeRelease()
{
   Grind_OrderTestReset();
   Grind_TestResetSideState();
   g_grind_order_test_active = true;
   Adr151_TestSeedSlotSeams(200, 200, 0);

   ArrayResize(g_grind_long.layers, 4);
   Adr151_TestSetupLongLayer(g_grind_long, 0, 0, 1.10500, 5001, 6101);
   Adr151_TestSetupLongLayer(g_grind_long, 1, 1, 1.10400, 5002, 6102);
   Adr151_TestSetupLongLayer(g_grind_long, 2, 2, 1.10300, 5003, 6103);
   Adr151_TestSetupLongLayer(g_grind_long, 3, 3, 1.10200, 5004, 0);
   Grind_OrderTestUpsert(6101, (long)22260101UL,
                         GrindCommentBuild("OPT", "L", 0, "EXT"),
                         1.10530, (long)ORDER_TYPE_SELL_LIMIT);

   Grind_ExitQManageSide(g_grind_long, true, 22260101UL, "OPT", 0.01, 3.0);

   AssertTrue("MQ3 cancel first", g_grind_order_test_remove_calls == 1);
   AssertTrue("MQ3 release after trim", g_grind_order_test_place_calls == 1);
   AssertTrue("MQ3 nearest exit", g_grind_long.layers[3].exit_order_ticket != 0);

   Grind_OrderTestReset();
   Grind_TestResetSideState();
   Adr151_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_MQ4_NoSendWhenExitNotAllowed()
{
   Grind_OrderTestReset();
   Grind_TestResetSideState();
   g_grind_order_test_active = true;
   Adr151_TestSeedSlotSeams(200, 200, 0);

   ArrayResize(g_grind_long.layers, 1);
   Adr151_TestSetupLongLayer(g_grind_long, 0, 0, 1.10200, 5001, 0);

   Grind_ExitQManageSide(g_grind_long, true, 22260101UL, "OPT", 0.01, 3.0);

   AssertTrue("MQ4 no place", g_grind_order_test_place_calls == 0);
   AssertTrue("MQ4 no cancel", g_grind_order_test_remove_calls == 0);

   Grind_OrderTestReset();
   Grind_TestResetSideState();
   Adr151_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_MQ5_ClampStoresShiftAndReleaseMarker()
{
   Grind_OrderTestReset();
   Grind_TestResetSideState();
   Grind_CarryTestReset();
   g_grind_order_test_active = true;
   Adr151_TestSeedSlotSeams(200, 100, 0);
   Grind_MarketTestSeed(1.25000, 1.25050, 0, 0);

   ArrayResize(g_grind_long.layers, 1);
   Adr151_TestSetupLongLayer(g_grind_long, 0, 0, 1.25000, 7001, 0);
   Grind_CarryShiftDelete(7001);
   GlobalVariableDel(Grind_CarryReleaseGvName(7001));

   Grind_ExitQManageSide(g_grind_long, true, 22260101UL, "OPT", 0.01, 3.0);

   AssertTrue("MQ5 placed", g_grind_order_test_place_calls == 1);
   AssertTrue("MQ5 shift gv", GlobalVariableCheck(Grind_CarryShiftGvName(7001)));
   AssertTrue("MQ5 release gv", GlobalVariableCheck(Grind_CarryReleaseGvName(7001)));

   Grind_CarryShiftDelete(7001);
   GlobalVariableDel(Grind_CarryReleaseGvName(7001));
   Grind_MarketTestReset();
   Grind_OrderTestReset();
   Grind_TestResetSideState();
   Adr151_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_MQ6_UsedRecomputedBeforeEachExitSend()
{
   Grind_OrderTestReset();
   Grind_TestResetSideState();
   g_grind_order_test_active = true;
   Adr151_TestSeedSlotSeams(200, 199, 0);

   ArrayResize(g_grind_long.layers, 2);
   Adr151_TestSetupLongLayer(g_grind_long, 0, 0, 1.10400, 5001, 0);
   Adr151_TestSetupLongLayer(g_grind_long, 1, 1, 1.10300, 5002, 0);

   Grind_ExitQManageSide(g_grind_long, true, 22260101UL, "OPT", 0.01, 3.0);

   AssertTrue("MQ6 one send", g_grind_order_test_place_calls == 1);

   Grind_OrderTestReset();
   Grind_TestResetSideState();
   Adr151_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_MQ7_KOverrideTrimsNothingReleasesAll()
{
   const ulong magic = 22260101UL;
   const double lots = 0.01;
   const double exit_pips = 3.0;

   Grind_OrderTestReset();
   Grind_TestResetSideState();
   g_grind_order_test_active = true;
   Adr151_TestSeedSlotSeams(200, 100, 0);
   g_grind_exitq_test_k = 99;
   Adr151_TestSetupMq7Fixture(g_grind_long);
   Grind_OrderTestUpsert(6001, (long)magic,
                         GrindCommentBuild("OPT", "L", 0, "EXT"),
                         1.10530, (long)ORDER_TYPE_SELL_LIMIT);
   Grind_OrderTestUpsert(6002, (long)magic,
                         GrindCommentBuild("OPT", "L", 1, "EXT"),
                         1.10430, (long)ORDER_TYPE_SELL_LIMIT);

   Grind_ExitQManageSide(g_grind_long, true, magic, "OPT", lots, exit_pips);

   AssertTrue("MQ7 k99 cancels", g_grind_order_test_remove_calls == 0);
   AssertTrue("MQ7 k99 sends", g_grind_order_test_place_calls == 3);
   AssertTrue("MQ7 k99 L2", g_grind_long.layers[2].exit_order_ticket != 0);
   AssertTrue("MQ7 k99 L3", g_grind_long.layers[3].exit_order_ticket != 0);
   AssertTrue("MQ7 k99 L4", g_grind_long.layers[4].exit_order_ticket != 0);

   Grind_OrderTestReset();
   Grind_TestResetSideState();
   g_grind_order_test_active = true;
   Adr151_TestSeedSlotSeams(200, 100, 0);
   g_grind_exitq_test_k = -1;
   Adr151_TestSetupMq7Fixture(g_grind_long);
   Grind_OrderTestUpsert(6001, (long)magic,
                         GrindCommentBuild("OPT", "L", 0, "EXT"),
                         1.10530, (long)ORDER_TYPE_SELL_LIMIT);
   Grind_OrderTestUpsert(6002, (long)magic,
                         GrindCommentBuild("OPT", "L", 1, "EXT"),
                         1.10430, (long)ORDER_TYPE_SELL_LIMIT);

   Grind_ExitQManageSide(g_grind_long, true, magic, "OPT", lots, exit_pips);

   AssertTrue("MQ7 k1 cancels", g_grind_order_test_remove_calls == 2);
   AssertTrue("MQ7 k1 sends", g_grind_order_test_place_calls == 1);

   Grind_OrderTestReset();
   Grind_TestResetSideState();
   Adr151_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_HC1_CancelDoneClearsTracker()
{
   Grind_OrderTestReset();
   Grind_TestResetSideState();
   g_grind_order_test_active = true;
   Adr151_TestSeedSlotSeams(200, 100, 0);

   ArrayResize(g_grind_long.layers, 4);
   Adr151_TestSetupLongLayer(g_grind_long, 0, 0, 1.10500, 5001, 6101);
   Adr151_TestSetupLongLayer(g_grind_long, 1, 1, 1.10400, 5002, 6102);
   Adr151_TestSetupLongLayer(g_grind_long, 2, 2, 1.10300, 5003, 6103);
   Adr151_TestSetupLongLayer(g_grind_long, 3, 3, 1.10200, 5004, 6104);
   Grind_OrderTestUpsert(6101, (long)22260101UL,
                         GrindCommentBuild("OPT", "L", 0, "EXT"),
                         1.10530, (long)ORDER_TYPE_SELL_LIMIT);

   Grind_ExitQManageSide(g_grind_long, true, 22260101UL, "OPT", 0.01, 3.0);

   AssertTrue("HC1 cleared", g_grind_long.layers[0].exit_order_ticket == 0);

   Grind_OrderTestReset();
   Grind_TestResetSideState();
   Adr151_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_HC2_CancelFailedOrderLiveKeepsTracker()
{
   Grind_OrderTestReset();
   Grind_TestResetSideState();
   g_grind_order_test_active = true;
   g_grind_order_test_send_ok = false;
   g_grind_order_test_send_retcode = TRADE_RETCODE_REJECT;
   Adr151_TestSeedSlotSeams(200, 100, 0);

   ArrayResize(g_grind_long.layers, 4);
   Adr151_TestSetupLongLayer(g_grind_long, 0, 0, 1.10500, 5001, 6101);
   Adr151_TestSetupLongLayer(g_grind_long, 1, 1, 1.10400, 5002, 6102);
   Adr151_TestSetupLongLayer(g_grind_long, 2, 2, 1.10300, 5003, 6103);
   Adr151_TestSetupLongLayer(g_grind_long, 3, 3, 1.10200, 5004, 6104);
   Grind_OrderTestUpsert(6101, (long)22260101UL,
                         GrindCommentBuild("OPT", "L", 0, "EXT"),
                         1.10530, (long)ORDER_TYPE_SELL_LIMIT);

   Grind_ExitQManageSide(g_grind_long, true, 22260101UL, "OPT", 0.01, 3.0);

   AssertTrue("HC2 kept", g_grind_long.layers[0].exit_order_ticket == 6101);

   Grind_OrderTestReset();
   Grind_TestResetSideState();
   Adr151_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_HC3_GoneWithDealQueuesCloseBy()
{
   Grind_OrderTestReset();
   Grind_DealTestReset();
   Grind_CloseByTestReset();
   Grind_TestResetSideState();
   g_grind_order_test_active = true;
   g_grind_order_test_send_ok = false;
   g_grind_order_test_send_retcode = TRADE_RETCODE_REJECT;
   Adr151_TestSeedSlotSeams(200, 100, 0);

   ArrayResize(g_grind_long.layers, 4);
   Adr151_TestSetupLongLayer(g_grind_long, 0, 0, 1.10500, 5001, 6101);
   Adr151_TestSetupLongLayer(g_grind_long, 1, 1, 1.10400, 5002, 6102);
   Adr151_TestSetupLongLayer(g_grind_long, 2, 2, 1.10300, 5003, 6103);
   Adr151_TestSetupLongLayer(g_grind_long, 3, 3, 1.10200, 5004, 6104);

   g_grind_deal_test_active = true;
   Grind_PositionTestAdd(5001);
   Grind_TestAppendDeal(9401,
                        GrindCommentBuild("OPT", "L", 0, "EXT"),
                        DEAL_ENTRY_IN,
                        6101,
                        7101,
                        0.0, 0.0, 0.0);
   Grind_PositionTestAdd(7101);

   Grind_ExitQManageSide(g_grind_long, true, 22260101UL, "OPT", 0.01, 3.0);

   AssertTrue("HC3 cleared", g_grind_long.layers[0].exit_order_ticket == 0);
   AssertTrue("HC3 exit pos", g_grind_long.layers[0].exit_position_ticket == 7101);
   AssertTrue("HC3 closeby", Grind_CloseByQueueSize(g_grind_long_closeby_queue) == 1);

   Grind_CloseByTestReset();
   Grind_DealTestReset();
   Grind_OrderTestReset();
   Grind_TestResetSideState();
   Adr151_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_HC4_GoneWithoutDealClearsTracker()
{
   Grind_OrderTestReset();
   Grind_DealTestReset();
   Grind_TestResetSideState();
   g_grind_order_test_active = true;
   g_grind_order_test_send_ok = false;
   g_grind_order_test_send_retcode = TRADE_RETCODE_REJECT;
   Adr151_TestSeedSlotSeams(200, 100, 0);

   ArrayResize(g_grind_long.layers, 4);
   Adr151_TestSetupLongLayer(g_grind_long, 0, 0, 1.10500, 5001, 6101);
   Adr151_TestSetupLongLayer(g_grind_long, 1, 1, 1.10400, 5002, 6102);
   Adr151_TestSetupLongLayer(g_grind_long, 2, 2, 1.10300, 5003, 6103);
   Adr151_TestSetupLongLayer(g_grind_long, 3, 3, 1.10200, 5004, 6104);

   Grind_ExitQManageSide(g_grind_long, true, 22260101UL, "OPT", 0.01, 3.0);

   AssertTrue("HC4 cleared", g_grind_long.layers[0].exit_order_ticket == 0);
   AssertTrue("HC4 no exit pos", g_grind_long.layers[0].exit_position_ticket == 0);
   AssertTrue("HC4 no closeby", Grind_CloseByQueueSize(g_grind_long_closeby_queue) == 0);

   Grind_DealTestReset();
   Grind_OrderTestReset();
   Grind_TestResetSideState();
   Adr151_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_HC5_DealOnOtherSideIgnored()
{
   Grind_OrderTestReset();
   Grind_DealTestReset();
   Grind_CloseByTestReset();
   Grind_TestResetSideState();
   g_grind_order_test_active = true;
   g_grind_order_test_send_ok = false;
   g_grind_order_test_send_retcode = TRADE_RETCODE_REJECT;
   Adr151_TestSeedSlotSeams(200, 100, 0);

   ArrayResize(g_grind_long.layers, 4);
   Adr151_TestSetupLongLayer(g_grind_long, 0, 0, 1.10500, 5001, 6101);
   Adr151_TestSetupLongLayer(g_grind_long, 1, 1, 1.10400, 5002, 6102);
   Adr151_TestSetupLongLayer(g_grind_long, 2, 2, 1.10300, 5003, 6103);
   Adr151_TestSetupLongLayer(g_grind_long, 3, 3, 1.10200, 5004, 6104);

   g_grind_deal_test_active = true;
   Grind_TestAppendDeal(9402,
                        GrindCommentBuild("OPT", "S", 0, "EXT"),
                        DEAL_ENTRY_IN,
                        6101,
                        7102,
                        0.0, 0.0, 0.0);

   Grind_ExitQManageSide(g_grind_long, true, 22260101UL, "OPT", 0.01, 3.0);

   AssertTrue("HC5 cleared", g_grind_long.layers[0].exit_order_ticket == 0);
   AssertTrue("HC5 no exit pos", g_grind_long.layers[0].exit_position_ticket == 0);
   AssertTrue("HC5 no closeby", Grind_CloseByQueueSize(g_grind_long_closeby_queue) == 0);

   Grind_CloseByTestReset();
   Grind_DealTestReset();
   Grind_OrderTestReset();
   Grind_TestResetSideState();
   Adr151_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_CV1_ReleaseMarkerSkipsBound()
{
   Grind_CarryTestReset();
   const ulong pos = 88010UL;
   const datetime open_time = D'2026.08.01 12:00';
   const double nightly_max = 3.0;
   Grind_CarryShiftDelete(pos);
   GlobalVariableDel(Grind_CarryReleaseGvName(pos));
   Grind_CarryShiftSet(pos, 5.0);
   GlobalVariableSet(Grind_CarryReleaseGvName(pos), 1.0);
   const double shift = Grind_CarryShiftGetValidated(pos, open_time, nightly_max);
   AssertNear("CV1 kept", shift, 5.0, 1e-12);
   Grind_CarryShiftDelete(pos);
   GlobalVariableDel(Grind_CarryReleaseGvName(pos));
   Grind_CarryTestReset();
   Adr151_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_CV2_ShiftDeleteRemovesMarker()
{
   Grind_CarryTestReset();
   const ulong pos = 88011UL;
   Grind_CarryShiftDelete(pos);
   GlobalVariableDel(Grind_CarryReleaseGvName(pos));
   Grind_CarryShiftSet(pos, 0.00040);
   GlobalVariableSet(Grind_CarryReleaseGvName(pos), 1.0);
   Grind_CarryShiftDelete(pos);
   AssertFalse("CV2 shift gone", GlobalVariableCheck(Grind_CarryShiftGvName(pos)));
   AssertFalse("CV2 release gone", GlobalVariableCheck(Grind_CarryReleaseGvName(pos)));
   Grind_CarryTestReset();
   Adr151_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_CV3_PruneKeepsExistingPositionGvs()
{
   Grind_CarryTestReset();
   Grind_TestResetSideState();
   const ulong magic = 22260101UL;
   const ulong pos = 88012UL;
   Grind_CarryShiftDelete(pos);
   GlobalVariableDel(Grind_CarryReleaseGvName(pos));
   Grind_CarryShiftSet(pos, 0.00030);
   GlobalVariableSet(Grind_CarryReleaseGvName(pos), 1.0);
   g_grind_order_test_active = true;
   Grind_PositionTestAdd(pos);
   Grind_CarryPruneShiftGvs(magic);
   AssertTrue("CV3 shift kept", GlobalVariableCheck(Grind_CarryShiftGvName(pos)));
   AssertTrue("CV3 release kept", GlobalVariableCheck(Grind_CarryReleaseGvName(pos)));
   Grind_CarryShiftDelete(pos);
   GlobalVariableDel(Grind_CarryReleaseGvName(pos));
   Grind_OrderTestReset();
   Grind_CarryTestReset();
   Grind_TestResetSideState();
   Adr151_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_RI1_HeldLayerBeyondKPassesI3()
{
   GrindReconLayerScratch layers[1];
   Grind_TestInitLayerScratch(layers[0], 4, 1.25000, 1001UL);
   layers[0].has_exit_order = false;
   int long_ranks[1];
   long_ranks[0] = 3;
   GrindReconLayerScratch empty[];
   int short_ranks[];
   string reason = "";
   AssertTrue("RI1 pass",
              Grind_ReconCheckInvariants(layers, 1, long_ranks, empty, 0, short_ranks,
                                         3.0, 0.00001, 12, reason));
   Adr151_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_RI2_MissingExitAtRequiredRankFailsI3()
{
   GrindReconLayerScratch layers[1];
   Grind_TestInitLayerScratch(layers[0], 0, 1.25000, 1001UL);
   layers[0].has_exit_order = false;
   int long_ranks[1];
   long_ranks[0] = 0;
   GrindReconLayerScratch empty[];
   int short_ranks[];
   string reason = "";
   AssertFalse("RI2 fail",
               Grind_ReconCheckInvariants(layers, 1, long_ranks, empty, 0, short_ranks,
                                          3.0, 0.00001, 12, reason));
   AssertEqStr("RI2 reason", reason, "I3_LONG_NAKED");
   Adr151_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_RI3_I1SkipsLayersWithoutExit()
{
   GrindReconLayerScratch layers[1];
   Grind_TestInitLayerScratch(layers[0], 2, 1.25000, 1001UL);
   layers[0].has_exit_order = false;
   int long_ranks[1];
   long_ranks[0] = 5;
   GrindReconLayerScratch empty[];
   int short_ranks[];
   string reason = "";
   AssertTrue("RI3 pass",
              Grind_ReconCheckInvariants(layers, 1, long_ranks, empty, 0, short_ranks,
                                         3.0, 0.00001, 12, reason));
   Adr151_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_RI4_I6SkipsLayersWithoutExit()
{
   GrindReconLayerScratch layers[1];
   Grind_TestInitLayerScratch(layers[0], 2, 1.25000, 1001UL);
   layers[0].has_exit_order = false;
   layers[0].exit_target = 9.99999;
   int long_ranks[1];
   long_ranks[0] = 5;
   GrindReconLayerScratch empty[];
   int short_ranks[];
   string reason = "";
   AssertTrue("RI4 pass",
              Grind_ReconCheckInvariants(layers, 1, long_ranks, empty, 0, short_ranks,
                                         3.0, 0.00001, 12, reason));
   Adr151_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_RI5_HeldLayerExitTargetFormulaNotZero()
{
   const ulong magic = 22260101UL;
   const double exit_pips = 3.0;
   GrindReconTicket tickets[5];
   int count = 0;
   tickets[count].ticket = 1001;
   tickets[count].magic = magic;
   tickets[count].comment = GrindCommentBuild("OPT", "L", 0, "ENT");
   tickets[count].price = 1.25000;
   tickets[count].kind = GRIND_RECON_TICKET_POSITION;
   count++;
   tickets[count].ticket = 1002;
   tickets[count].magic = magic;
   tickets[count].comment = GrindCommentBuild("OPT", "L", 1, "ENT");
   tickets[count].price = 1.24900;
   tickets[count].kind = GRIND_RECON_TICKET_POSITION;
   count++;
   tickets[count].ticket = 1003;
   tickets[count].magic = magic;
   tickets[count].comment = GrindCommentBuild("OPT", "L", 2, "ENT");
   tickets[count].price = 1.24800;
   tickets[count].kind = GRIND_RECON_TICKET_POSITION;
   count++;
   tickets[count].ticket = 2002;
   tickets[count].magic = magic;
   tickets[count].comment = GrindCommentBuild("OPT", "L", 1, "EXT");
   tickets[count].price = 1.24930;
   tickets[count].kind = GRIND_RECON_TICKET_ORDER;
   count++;
   tickets[count].ticket = 2003;
   tickets[count].magic = magic;
   tickets[count].comment = GrindCommentBuild("OPT", "L", 2, "EXT");
   tickets[count].price = 1.24830;
   tickets[count].kind = GRIND_RECON_TICKET_ORDER;
   count++;
   GrindSideState long_out;
   GrindSideState short_out;
   string reason = "";
   AssertTrue("RI5 ok", Grind_RebuildBookFromTickets(tickets, count, magic, "OPT",
                                                     exit_pips, 12, _Point,
                                                     long_out, short_out, reason));
   bool found = false;
   for(int i = 0; i < ArraySize(long_out.layers); i++) {
      if(long_out.layers[i].layer_index != 0)
         continue;
      found = true;
      AssertNear("RI5 formula", long_out.layers[i].exit_target, 1.25030, 0.000001);
      AssertTrue("RI5 not zero", long_out.layers[i].exit_target > 0.0);
   }
   AssertTrue("RI5 layer found", found);
   Adr151_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_EG1_EntryDeferredNoSendWhenBlocked()
{
   Grind_OrderTestReset();
   Grind_TestResetSideState();
   g_grind_order_test_active = true;
   g_grind_cap_thresh_a = 0.0;
   g_grind_cap_thresh_b = 0.0;
   Adr151_TestSeedSlotSeams(200, 100, 95);
   Grind_MarketTestSeed(1.24950, 1.24952, 0);

   const ulong magic = 22260101UL;
   Grind_TryPlaceL0(g_grind_long, true, 1.24900, magic, "OPT", 12, 0.01);

   AssertTrue("EG1 no place", g_grind_order_test_place_calls == 0);

   Grind_MarketTestReset();
   Grind_OrderTestReset();
   Grind_TestResetSideState();
   Adr151_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_EG2_OneEntSendPerTick()
{
   Grind_OrderTestReset();
   Grind_TestResetSideState();
   g_grind_order_test_active = true;
   g_grind_cap_thresh_a = 0.0;
   g_grind_cap_thresh_b = 0.0;
   Adr151_TestSeedSlotSeams(200, 100, 0);
   Grind_MarketTestSeed(1.24950, 1.24952, 0);
   g_grind_ent_sent_this_tick = false;

   const ulong magic = 22260101UL;
   Grind_TestSetupLongDepth1(1.25000);
   Grind_TryPlaceL0(g_grind_short, false, 1.26050, magic, "OPT", 12, 0.01);
   Grind_EnsureAddNext(g_grind_long, true, magic, "OPT", 10.0, 4.0, 12, 0.01);

   AssertTrue("EG2 one send", g_grind_order_test_place_calls == 1);

   Grind_MarketTestReset();
   Grind_OrderTestReset();
   Grind_TestResetSideState();
   Adr151_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_EG3_LockReleasedWhenSendFails()
{
   Grind_OrderTestReset();
   Grind_TestResetSideState();
   Adr151_TestResetLock();
   g_grind_order_test_active = true;
   g_grind_order_test_send_ok = false;
   g_grind_order_test_send_retcode = TRADE_RETCODE_REJECT;
   g_grind_cap_thresh_a = 0.0;
   g_grind_cap_thresh_b = 0.0;
   Adr151_TestSeedSlotSeams(200, 100, 0);
   Grind_MarketTestSeed(1.24950, 1.24952, 0);

   const ulong magic = 22260101UL;
   Grind_TryPlaceL0(g_grind_long, true, 1.24900, magic, "OPT", 12, 0.01);

   double token = 0.0;
   AssertTrue("EG3 lock free", Grind_SlotLockAcquire(token));
   Grind_SlotLockRelease(token);

   Grind_MarketTestReset();
   Grind_OrderTestReset();
   Grind_TestResetSideState();
   Adr151_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_HT1_HaltCriticalCancelsOwnEntOnly()
{
   Grind_OrderTestReset();
   Grind_TestResetSideState();
   g_grind_order_test_active = true;
   g_grind_recon_magic = 22260101UL;
   g_grind_recon_slot = "OPT";

   Grind_OrderTestUpsert(8301, (long)g_grind_recon_magic,
                         GrindCommentBuild("OPT", "L", 0, "ENT"),
                         1.24900, (long)ORDER_TYPE_BUY_LIMIT);
   Grind_OrderTestUpsert(8302, (long)g_grind_recon_magic,
                         GrindCommentBuild("OPT", "L", 0, "EXT"),
                         1.25030, (long)ORDER_TYPE_SELL_LIMIT);
   g_grind_long.l0_pending_ticket = 8301;

   Grind_HaltCritical("TEST_HALT");

   GrindOrderTestRecord ht1_rec;
   AssertTrue("HT1 ent removed", g_grind_order_test_remove_calls == 1);
   AssertTrue("HT1 ext kept", Grind_OrderTestFind(8302, ht1_rec));

   Grind_OrderTestReset();
   Grind_TestResetSideState();
   Adr151_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_HT2_CloseByExhaustedHaltCancelsOwnEnt()
{
   Grind_CloseByTestReset();
   Grind_OrderTestReset();
   Grind_TestResetSideState();
   g_grind_order_test_active = true;
   g_grind_recon_magic = 22260101UL;
   g_grind_recon_slot = "OPT";

   Grind_OrderTestUpsert(8401, (long)g_grind_recon_magic,
                         GrindCommentBuild("OPT", "L", 0, "ENT"),
                         1.24900, (long)ORDER_TYPE_BUY_LIMIT);
   Grind_OrderTestUpsert(8402, (long)g_grind_recon_magic,
                         GrindCommentBuild("OPT", "L", 0, "EXT"),
                         1.25030, (long)ORDER_TYPE_SELL_LIMIT);
   g_grind_long.l0_pending_ticket = 8401;

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
      Grind_ProcessCloseByQueue(g_grind_long_closeby_queue, g_grind_recon_magic, false);

   GrindOrderTestRecord ht2_rec;
   AssertTrue("HT2 halted", g_grind_halted);
   AssertTrue("HT2 ent removed", g_grind_order_test_remove_calls == 1);
   AssertTrue("HT2 ext kept", Grind_OrderTestFind(8402, ht2_rec));

   Grind_CloseByTestReset();
   Grind_OrderTestReset();
   Grind_TestResetSideState();
   Adr151_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_FL1_EntFillPlacesRankZeroExitAndTrims()
{
   Grind_OrderTestReset();
   Grind_DealTestReset();
   Grind_TestResetSideState();
   g_grind_order_test_active = true;
   g_grind_cap_thresh_a = 0.0;
   g_grind_cap_thresh_b = 0.0;
   Adr151_TestSeedSlotSeams(200, 100, 0);

   ArrayResize(g_grind_long.layers, 3);
   Adr151_TestSetupLongLayer(g_grind_long, 0, 0, 1.10500, 5001, 6101);
   Adr151_TestSetupLongLayer(g_grind_long, 1, 1, 1.10400, 5002, 6102);
   Adr151_TestSetupLongLayer(g_grind_long, 2, 2, 1.10300, 5003, 6103);
   Grind_OrderTestUpsert(6101, (long)22260101UL,
                         GrindCommentBuild("OPT", "L", 0, "EXT"),
                         1.10530, (long)ORDER_TYPE_SELL_LIMIT);
   Grind_OrderTestUpsert(6102, (long)22260101UL,
                         GrindCommentBuild("OPT", "L", 1, "EXT"),
                         1.10430, (long)ORDER_TYPE_SELL_LIMIT);
   Grind_OrderTestUpsert(6103, (long)22260101UL,
                         GrindCommentBuild("OPT", "L", 2, "EXT"),
                         1.10330, (long)ORDER_TYPE_SELL_LIMIT);

   g_grind_deal_test_active = true;
   Grind_TestAppendDeal(9501,
                        GrindCommentBuild("OPT", "L", 3, "ENT"),
                        DEAL_ENTRY_IN,
                        6201,
                        7201,
                        0.0, 0.0, 0.0,
                        1.10200);

   Grind_HandleSideDealFill(g_grind_long, true, 9501, 22260101UL, "OPT",
                            3.0, 4.0, 12, 0.01);

   AssertTrue("FL1 trim", g_grind_order_test_remove_calls >= 1);
   AssertTrue("FL1 new exit", g_grind_order_test_place_calls >= 1);
   AssertTrue("FL1 depth", Grind_SideDepth(g_grind_long) == 4);

   Grind_DealTestReset();
   Grind_OrderTestReset();
   Grind_TestResetSideState();
   Adr151_TestResetAll();
}

#endif // FXGRIND_TESTS_ADR151_MQH
