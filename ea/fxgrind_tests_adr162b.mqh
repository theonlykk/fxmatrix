//+------------------------------------------------------------------+
//| fxgrind_tests_adr162b.mqh — ADR-162 phase B1 unit tests (LB*)    |
//+------------------------------------------------------------------+
#ifndef FXGRIND_TESTS_ADR162B_MQH
#define FXGRIND_TESTS_ADR162B_MQH

#include "grind_exitq.mqh"
#include "grind_comment.mqh"
#include "grind_archive.mqh"

//+------------------------------------------------------------------+
void Adr162b_Reset()
{
   Grind_TestEjectHarnessReset();
   Grind_ArchiveTestReset();
   Grind_LatticeResetBackoff();
   Adr151_TestResetAll();
   g_grind_order_test_send_ok = true;
}

//+------------------------------------------------------------------+
string Adr162b_ArchiveFind(const string code, const int nth)
{
   int seen = 0;
   for(int i = 0; i < Grind_ArchiveQueueCount(); i++) {
      const string e = Grind_ArchiveQueuePeek(i);
      if(StringFind(e, code) < 0)
         continue;
      if(seen == nth)
         return e;
      seen++;
   }
   return "";
}

//+------------------------------------------------------------------+
void Adr162b_RefreshExit(GrindSideState &side, const bool is_long, const int arr_idx,
                         const ulong order_ticket)
{
   const double entry = side.layers[arr_idx].entry_price;
   const ulong pos = side.layers[arr_idx].position_ticket;
   const double target = Grind_ExitQFormulaTarget(entry, 5.0, _Point, is_long, pos);
   side.layers[arr_idx].exit_target = target;
   side.layers[arr_idx].exit_order_ticket = order_ticket;
   Grind_OrderTestUpsert(order_ticket, (long)22260101UL,
                         GrindCommentBuild("OPT", is_long ? "L" : "S",
                                           side.layers[arr_idx].layer_index, "EXT"),
                         target,
                         (long)(is_long ? ORDER_TYPE_SELL_LIMIT : ORDER_TYPE_BUY_LIMIT));
}

//+------------------------------------------------------------------+
void Adr162b_SeedLong8()
{
   Adr162b_Reset();
   g_grind_order_test_active = true;
   Adr151_TestSeedSlotSeams(200, 100, 0);
   Grind_ArchiveTestConfigureCommon();
   ArrayResize(g_grind_long.layers, 8);
   for(int i = 0; i < 8; i++) {
      const double entry = NormalizeDouble(1.21400 - 0.00100 * i, 5);
      Adr151_TestSetupLongLayer(g_grind_long, i, i, entry, 7001UL + (ulong)i, 0, 5.0);
   }
   g_grind_long.layers[0].exit_order_ticket = 8001UL;
   g_grind_long.layers[0].exit_target = 1.21450;
   Grind_OrderTestUpsert(8001UL, (long)22260101UL, GrindCommentBuild("OPT", "L", 0, "EXT"),
                         1.21450, (long)ORDER_TYPE_SELL_LIMIT);
   g_grind_long.layers[7].exit_order_ticket = 8008UL;
   g_grind_long.layers[7].exit_target = 1.20750;
   Grind_OrderTestUpsert(8008UL, (long)22260101UL, GrindCommentBuild("OPT", "L", 7, "EXT"),
                         1.20750, (long)ORDER_TYPE_SELL_LIMIT);
}

//+------------------------------------------------------------------+
void Adr162b_SeedShort8()
{
   Adr162b_Reset();
   g_grind_order_test_active = true;
   Adr151_TestSeedSlotSeams(200, 100, 0);
   Grind_ArchiveTestConfigureCommon();
   ArrayResize(g_grind_short.layers, 8);
   for(int i = 0; i < 8; i++) {
      const double entry = NormalizeDouble(1.18600 + 0.00100 * i, 5);
      const ulong pos = 7101UL + (ulong)i;
      g_grind_short.layers[i].entry_price = entry;
      g_grind_short.layers[i].layer_index = i;
      g_grind_short.layers[i].position_ticket = pos;
      g_grind_short.layers[i].exit_order_ticket = 0;
      g_grind_short.layers[i].exit_position_ticket = 0;
      g_grind_short.layers[i].exit_target =
         Grind_ExitQFormulaTarget(entry, 5.0, _Point, false, pos);
   }
   g_grind_short.layers[0].exit_order_ticket = 8101UL;
   g_grind_short.layers[0].exit_target = 1.18550;
   Grind_OrderTestUpsert(8101UL, (long)22260101UL, GrindCommentBuild("OPT", "S", 0, "EXT"),
                         1.18550, (long)ORDER_TYPE_BUY_LIMIT);
   g_grind_short.layers[7].exit_order_ticket = 8108UL;
   g_grind_short.layers[7].exit_target = 1.19250;
   Grind_OrderTestUpsert(8108UL, (long)22260101UL, GrindCommentBuild("OPT", "S", 7, "EXT"),
                         1.19250, (long)ORDER_TYPE_BUY_LIMIT);
}

//+------------------------------------------------------------------+
int Adr162b_TryLong(const datetime now)
{
   return Grind_LatticeTrySide(g_grind_long, true, 22260101UL, "OPT", 0.01, 5.0, 10.0, 8,
                               true, false, now);
}

int Adr162b_TryShort(const datetime now)
{
   return Grind_LatticeTrySide(g_grind_short, false, 22260101UL, "OPT", 0.01, 5.0, 10.0, 8,
                               true, false, now);
}

//+------------------------------------------------------------------+
void Test_LB1_ValidateInputs()
{
   AssertFalse("LB1 both on refused", Grind_ValidateLatticeInputs(true, true));
   AssertTrue("LB1 lattice only", Grind_ValidateLatticeInputs(true, false));
   AssertTrue("LB1 auto only", Grind_ValidateLatticeInputs(false, true));
   AssertTrue("LB1 both off", Grind_ValidateLatticeInputs(false, false));
}

void Test_LB2_LevelCrossed()
{
   AssertFalse("LB2 long above", Grind_LatticeLevelCrossed(true, 1.20640, 1.20600));
   AssertTrue("LB2 long at", Grind_LatticeLevelCrossed(true, 1.20600, 1.20600));
   AssertTrue("LB2 long through", Grind_LatticeLevelCrossed(true, 1.20190, 1.20600));
   AssertFalse("LB2 short below", Grind_LatticeLevelCrossed(false, 1.19390, 1.19400));
   AssertTrue("LB2 short at", Grind_LatticeLevelCrossed(false, 1.19400, 1.19400));
}

void Test_LB3_RollCost()
{
   AssertNear("LB3 long", Grind_LatticeRollCost(1.21400, 1.20600, 5.0, 0.00001, true),
              0.00750, 1e-9);
   AssertNear("LB3 short", Grind_LatticeRollCost(1.18600, 1.19400, 5.0, 0.00001, false),
              0.00750, 1e-9);
   AssertNear("LB3 non-uniform", Grind_LatticeRollCost(1.21350, 1.20600, 5.0, 0.00001, true),
              0.00700, 1e-9);
}

void Test_LB4_Candidate()
{
   Adr162b_SeedLong8();
   AssertEqInt("LB4 oldest", Grind_LatticeCandidateIndex(g_grind_long, true), 0);
   Grind_VLSet(7001UL, 1.20600);
   AssertEqInt("LB4 next unrolled", Grind_LatticeCandidateIndex(g_grind_long, true), 1);
   for(int i = 0; i < 8; i++)
      Grind_VLSet(7001UL + (ulong)i, NormalizeDouble(1.20600 - 0.00100 * i, 5));
   AssertEqInt("LB4 all rolled", Grind_LatticeCandidateIndex(g_grind_long, true), -1);
   Adr162b_SeedShort8();
   AssertEqInt("LB4 short oldest", Grind_LatticeCandidateIndex(g_grind_short, false), 0);
   Adr162b_Reset();
}

void Test_LB5_ThroughEntryNotExit()
{
   Adr162b_SeedLong8();
   Grind_MarketTestSeed(1.20630, 1.20640, 0, 0);
   const datetime now = D'2026.09.28 10:00';
   const int rc = Adr162b_TryLong(now);
   AssertEqInt("LB5 no roll", rc, 0);
   AssertFalse("LB5 no vl", Grind_VLHas(7001UL));
   AssertTrue("LB5 no modify", g_grind_order_test_modify_calls == 0);
   Adr162b_Reset();
}

void Test_LB6_SingleRoll()
{
   Adr162b_SeedLong8();
   Grind_MarketTestSeed(1.20590, 1.20600, 0, 0);
   const datetime now = D'2026.09.28 10:00';
   const int rc = Adr162b_TryLong(now);
   AssertEqInt("LB6 one roll", rc, 1);
   AssertNear("LB6 vl", Grind_VLGet(7001UL), 1.20600, 1e-9);
   const double p8001 = Grind_OrderGetPriceOpen(8001UL);
   AssertNear("LB6 exit price", p8001, 1.20650, 1e-9);
   AssertNear("LB6 exit_target", g_grind_long.layers[0].exit_target, 1.20650, 1e-9);
   AssertNear("LB6 formula agrees",
              Grind_ExitQFormulaTarget(1.21400, 5.0, _Point, true, 7001UL), p8001, 1e-9);
   AssertTrue("LB6 I6 ok",
              Grind_ReconExitMatchesEntry(1.21400, p8001, 5.0, _Point, true, 0.0, false, 7001UL));
   AssertFalse("LB6 no shift", GlobalVariableCheck(Grind_CarryShiftGvName(7001UL)));
   AssertTrue("LB6 old rank0 cancelled", g_grind_long.layers[7].exit_order_ticket == 0);
   AssertTrue("LB6 new highest placed", g_grind_long.layers[1].exit_order_ticket != 0);
   AssertTrue("LB6 calls",
              g_grind_order_test_modify_calls == 1 && g_grind_order_test_remove_calls == 1
              && g_grind_order_test_place_calls == 1);
   const string acc = Adr162b_ArchiveFind("ROLL_ACCEPTED", 0);
   AssertContains("LB6 accepted archived", acc, "7001");
   AssertContains("LB6 cost archived", acc, "0.00750");
   AssertContains("LB6 source archived", acc, "auto");
   Adr162b_Reset();
}

void Test_LB7_GapFiresEveryLevel()
{
   Adr162b_SeedLong8();
   Grind_MarketTestSeed(1.20180, 1.20190, 0, 0);
   const datetime now = D'2026.09.28 10:00';
   const int rc = Adr162b_TryLong(now);
   AssertEqInt("LB7 five rolls", rc, 5);
   AssertNear("LB7 vl L0", Grind_VLGet(7001UL), 1.20600, 1e-9);
   AssertNear("LB7 vl L4", Grind_VLGet(7005UL), 1.20200, 1e-9);
   AssertFalse("LB7 L5 unrolled", Grind_VLHas(7006UL));
   AssertTrue("LB7 two resting", Adr151_TestCountRestingExits(g_grind_long) == 2);
   const int i4 = 4;
   AssertTrue("LB7 newest rolled rests",
              g_grind_long.layers[i4].exit_order_ticket != 0
              && MathAbs(Grind_OrderGetPriceOpen(g_grind_long.layers[i4].exit_order_ticket) - 1.20250) <= 1e-9);
   const int i5 = 5;
   AssertTrue("LB7 oldest unrolled rests",
              g_grind_long.layers[i5].exit_order_ticket != 0
              && MathAbs(Grind_OrderGetPriceOpen(g_grind_long.layers[i5].exit_order_ticket) - 1.20950) <= 1e-9);
   AssertTrue("LB7 calls",
              g_grind_order_test_modify_calls == 5 && g_grind_order_test_remove_calls == 5
              && g_grind_order_test_place_calls == 5);
   bool order_ok = true;
   for(int k = 0; k < 5; k++) {
      if(StringFind(Adr162b_ArchiveFind("ROLL_ACCEPTED", k), IntegerToString(7001 + k)) < 0)
         order_ok = false;
   }
   AssertTrue("LB7 in order", order_ok);
   Adr162b_Reset();
}

void Test_LB8_NoReroll()
{
   Adr162b_SeedLong8();
   for(int i = 0; i < 8; i++)
      Grind_VLSet(7001UL + (ulong)i, NormalizeDouble(1.20600 - 0.00100 * i, 5));
   Adr162b_RefreshExit(g_grind_long, true, 0, 8001UL);
   Adr162b_RefreshExit(g_grind_long, true, 7, 8008UL);
   Grind_MarketTestSeed(1.19000, 1.19010, 0, 0);
   const datetime now = D'2026.09.28 10:00';
   AssertEqInt("LB8 no reroll", Adr162b_TryLong(now), 0);
   AssertTrue("LB8 no modify", g_grind_order_test_modify_calls == 0);
   AssertNear("LB8 L0 level kept", Grind_VLGet(7001UL), 1.20600, 1e-9);
   Adr162b_Reset();
}

void Test_LB9_BelowCap()
{
   Adr162b_SeedLong8();
   ArrayResize(g_grind_long.layers, 7);
   Adr162b_RefreshExit(g_grind_long, true, 6, 8007UL);
   Grind_MarketTestSeed(1.19000, 1.19010, 0, 0);
   const datetime now = D'2026.09.28 10:00';
   AssertEqInt("LB9 below cap no roll", Adr162b_TryLong(now), 0);
   AssertFalse("LB9 no vl", Grind_VLHas(7001UL));
   Adr162b_Reset();
}

void Test_LB10_EntryBlocksDoNotBlockRolls()
{
   Adr152_TestPrepareIsolation();
   Grind_ApiCounterTestSeed(GRIND_DAILY_API_ENTRY_STOP);
   Adr162b_SeedLong8();
   Grind_MarketTestSeed(1.20590, 1.20600, 0, 0);
   const datetime now = D'2026.09.28 10:00';
   AssertTrue("LB10 entries blocked", Grind_EntriesBlocked());
   const int rc = Adr162b_TryLong(now);
   AssertEqInt("LB10 rolls anyway", rc, 1);
   AssertTrue("LB10 vl", Grind_VLHas(7001UL));
   Adr152_TestResetAll();
   Adr162b_Reset();
}

void Test_LB11_BlockedAndOff()
{
   Adr162b_SeedLong8();
   Grind_MarketTestSeed(1.20590, 1.20600, 0, 0);
   const datetime now = D'2026.09.28 10:00';
   AssertEqInt("LB11 blocked",
               Grind_LatticeTrySide(g_grind_long, true, 22260101UL, "OPT", 0.01, 5.0, 10.0, 8,
                                    true, true, now), 0);
   AssertEqInt("LB11 switch off",
               Grind_LatticeTrySide(g_grind_long, true, 22260101UL, "OPT", 0.01, 5.0, 10.0, 8,
                                    false, false, now), 0);
   AssertTrue("LB11 inert", g_grind_order_test_modify_calls == 0 && !Grind_VLHas(7001UL));
   Adr162b_Reset();
}

void Test_LB12_ClampRecordsShift()
{
   Adr162b_SeedLong8();
   Grind_MarketTestSeed(1.20590, 1.20600, 100, 0);
   const datetime now = D'2026.09.28 10:00';
   Adr162b_TryLong(now);
   const double p = Grind_OrderGetPriceOpen(8001UL);
   AssertNear("LB12 clamped price", p, 1.20700, 1e-9);
   AssertNear("LB12 shift", Grind_CarryShiftGet(7001UL), 0.00050, 1e-9);
   AssertTrue("LB12 release marker",
              GlobalVariableCheck(Grind_CarryReleaseGvName(7001UL)));
   AssertTrue("LB12 I6 ok",
              Grind_ReconExitMatchesEntry(1.21400, 1.20700, 5.0, _Point, true,
                                          Grind_CarryShiftGet(7001UL), false, 7001UL));
   Adr162b_Reset();
}

void Test_LB13_AccruedCarried()
{
   Adr162b_SeedLong8();
   Grind_CarryAccruedSet(7001UL, 0.00010);
   Adr162b_RefreshExit(g_grind_long, true, 0, 8001UL);
   Grind_MarketTestSeed(1.20590, 1.20600, 0, 0);
   Adr162b_TryLong(D'2026.09.28 10:00');
   const double p = Grind_OrderGetPriceOpen(8001UL);
   AssertNear("LB13 target", p, 1.20660, 1e-9);
   AssertNear("LB13 accrued kept", Grind_CarryAccruedGet(7001UL), 0.00010, 1e-9);
   AssertNear("LB13 formula agrees",
              Grind_ExitQFormulaTarget(1.21400, 5.0, _Point, true, 7001UL), 1.20660, 1e-9);
   Adr162b_Reset();
}

void Test_LB14_EjectedCandidate()
{
   Adr162b_SeedLong8();
   Grind_EjectOffsetSet(7001UL, 0.00200);
   Grind_CarryShiftSet(7001UL, 0.00003);
   Adr162b_RefreshExit(g_grind_long, true, 0, 8001UL);
   Grind_MarketTestSeed(1.20590, 1.20600, 0, 0);
   Adr162b_TryLong(D'2026.09.28 10:00');
   AssertNear("LB14 target", Grind_OrderGetPriceOpen(8001UL), 1.20650, 1e-9);
   AssertFalse("LB14 offset gone", Grind_EjectIsEjected(7001UL));
   AssertFalse("LB14 shift gone", GlobalVariableCheck(Grind_CarryShiftGvName(7001UL)));
   Adr162b_Reset();
}

void Test_LB15_ModifyFailBackoff()
{
   Adr162b_SeedLong8();
   Grind_MarketTestSeed(1.20590, 1.20600, 0, 0);
   g_grind_order_test_send_ok = false;
   const datetime now = D'2026.09.28 10:00';
   const int rc1 = Adr162b_TryLong(now);
   AssertEqInt("LB15 first no roll", rc1, 0);
   AssertTrue("LB15 attempted once", g_grind_order_test_modify_calls == 1);
   AssertFalse("LB15 no vl", Grind_VLHas(7001UL));
   AssertNear("LB15 exit unchanged", Grind_OrderGetPriceOpen(8001UL), 1.21450, 1e-9);
   AssertContains("LB15 refused archived", Adr162b_ArchiveFind("ROLL_REFUSED", 0), "MODIFY_FAILED");
   Adr162b_TryLong(now + 30);
   AssertTrue("LB15 backoff holds", g_grind_order_test_modify_calls == 1);
   Adr162b_TryLong(now + 61);
   AssertTrue("LB15 second attempt", g_grind_order_test_modify_calls == 2);
   Adr162b_TryLong(now + 180);
   AssertTrue("LB15 doubled backoff holds", g_grind_order_test_modify_calls == 2);
   g_grind_order_test_send_ok = true;
   const int rc3 = Adr162b_TryLong(now + 181);
   AssertEqInt("LB15 retry after backoff", rc3, 1);
   Adr162b_Reset();
}

void Test_LB16_ShortSingleRoll()
{
   Adr162b_SeedShort8();
   const datetime now = D'2026.09.28 10:00';
   Grind_MarketTestSeed(1.19390, 1.19400, 0, 0);
   AssertEqInt("LB16 below level", Adr162b_TryShort(now), 0);
   Grind_MarketTestSeed(1.19400, 1.19410, 0, 0);
   AssertEqInt("LB16 one roll", Adr162b_TryShort(now), 1);
   AssertNear("LB16 vl", Grind_VLGet(7101UL), 1.19400, 1e-9);
   AssertNear("LB16 exit price", Grind_OrderGetPriceOpen(8101UL), 1.19350, 1e-9);
   AssertTrue("LB16 old rank0 cancelled", g_grind_short.layers[7].exit_order_ticket == 0);
   AssertTrue("LB16 new highest placed", g_grind_short.layers[1].exit_order_ticket != 0);
   Adr162b_Reset();
}

void Test_LB17_ClosingCandidate()
{
   Adr162b_SeedLong8();
   g_grind_long.layers[0].exit_order_ticket = 0;
   g_grind_long.layers[0].exit_position_ticket = 9999UL;
   Grind_MarketTestSeed(1.20590, 1.20600, 0, 0);
   AssertEqInt("LB17 closing no roll", Adr162b_TryLong(D'2026.09.28 10:00'), 0);
   AssertTrue("LB17 no vl anywhere", !Grind_VLHas(7001UL) && !Grind_VLHas(7002UL));
   Adr162b_Reset();
}

void Test_LB18_CandidateWithoutExit()
{
   Adr162b_SeedLong8();
   for(int i = 0; i < 6; i++)
      Grind_VLSet(7001UL + (ulong)i, NormalizeDouble(1.20600 - 0.00100 * i, 5));
   Adr151_TestSetupLongLayer(g_grind_long, 6, 8, 1.20000, 7009UL, 0, 5.0);
   Adr151_TestSetupLongLayer(g_grind_long, 7, 9, 1.19900, 7010UL, 0, 5.0);
   Adr162b_RefreshExit(g_grind_long, true, 0, 8001UL);
   Adr162b_RefreshExit(g_grind_long, true, 7, 8010UL);
   Grind_MarketTestSeed(1.19790, 1.19800, 0, 0);
   AssertEqInt("LB18 one roll", Adr162b_TryLong(D'2026.09.28 10:00'), 1);
   AssertNear("LB18 vl", Grind_VLGet(7009UL), 1.19800, 1e-9);
   AssertTrue("LB18 no modify", g_grind_order_test_modify_calls == 0);
   AssertTrue("LB18 exit placed",
              g_grind_long.layers[6].exit_order_ticket != 0
              && MathAbs(Grind_OrderGetPriceOpen(g_grind_long.layers[6].exit_order_ticket) - 1.19850) <= 1e-9);
   AssertTrue("LB18 old rank0 cancelled", g_grind_long.layers[7].exit_order_ticket == 0);
   Adr162b_Reset();
}

void Test_LB19_OnTickWiring()
{
   Adr162b_SeedLong8();
   Grind_MarketTestSeed(1.20590, 1.20600, 0, 0);
   const datetime now = D'2026.09.28 10:00';
   Grind_LatticeOnTick(22260101UL, "OPT", 0.01, false, 5.0, 10.0, 8, false, now);
   AssertFalse("LB19 off inert", Grind_VLHas(7001UL));
   Grind_LatticeOnTick(22260101UL, "OPT", 0.01, true, 5.0, 10.0, 8, false, now);
   AssertTrue("LB19 on rolls long", Grind_VLHas(7001UL));
   Adr162b_Reset();
}

void Test_LB20_VLHasTicketZero()
{
   Grind_TestResetSideState();
   GlobalVariableSet("GRIND_VL_0", 1.0);
   AssertFalse("LB20 ticket 0", Grind_VLHas(0));
   Adr151_TestSetupLongLayer(g_grind_long, 0, 2, 1.10400, 0UL, 0, 5.0);
   Adr151_TestSetupLongLayer(g_grind_long, 1, 1, 1.10300, 5002UL, 0, 5.0);
   AssertNear("LB20 anchor", Grind_ComputeAddTarget(g_grind_long, true, 10.0), 1.10300, 1e-9);
   GlobalVariableDel("GRIND_VL_0");
   Grind_TestResetSideState();
}

void Test_LB21_PruneScope()
{
   Grind_TestClearCarryState();
   g_grind_order_test_active = true;
   GlobalVariableSet("GRIND_EJECT_OFFSET_8889", 0.00100);
   Grind_CarryPruneShiftGvs(22260101UL);
   AssertFalse("LB21 offset still pruned", GlobalVariableCheck("GRIND_EJECT_OFFSET_8889"));
   g_grind_order_test_active = false;
}

void Test_LB22_CommandRanksRolled()
{
   Grind_TestEjectHarnessReset();
   g_grind_order_test_active = true;
   g_grind_order_test_send_ok = true;
   ArrayResize(g_grind_long.layers, 3);
   Adr151_TestSetupLongLayer(g_grind_long, 0, 0, 1.10500, 1001UL, 2001UL, 3.0);
   Adr151_TestSetupLongLayer(g_grind_long, 1, 1, 1.10400, 1002UL, 2002UL, 3.0);
   Adr151_TestSetupLongLayer(g_grind_long, 2, 2, 1.10300, 1003UL, 0, 3.0);
   Grind_VLSet(1001UL, 1.10000);
   Grind_OrderTestUpsert(2001UL, (long)22260101UL, GrindCommentBuild("OPT", "L", 0, "EXT"),
                         1.10030, (long)ORDER_TYPE_SELL_LIMIT);
   Grind_OrderTestUpsert(2002UL, (long)22260101UL, GrindCommentBuild("OPT", "L", 1, "EXT"),
                         1.10430, (long)ORDER_TYPE_SELL_LIMIT);
   Grind_MarketTestSeed(1.10100, 1.10110, 0, 0);
   GlobalVariableSet(Grind_EjectCommandName(22260101UL), (double)1001UL);
   AssertEqInt("LB22 rolled not deepest",
               Grind_EjectPollCommand(22260101UL, true, 3.0, false), GRIND_EJECT_NOT_DEEPEST);
   GlobalVariableSet(Grind_EjectCommandName(22260101UL), (double)1002UL);
   AssertEqInt("LB22 oldest unrolled ejectable",
               Grind_EjectPollCommand(22260101UL, true, 3.0, false), GRIND_EJECT_OK);
   Grind_TestEjectHarnessReset();
}

void Test_LB23_AutoRanksRolled()
{
   Grind_TestEjectHarnessReset();
   Grind_TestEjectFixtureDepth2();
   g_grind_order_test_modify_calls = 0;
   Grind_VLSet(1001UL, 1.24800);
   const datetime now = D'2026.09.23 10:00';
   datetime times[];
   double vals[];
   Grind_TestAutoEjectSeriesA(times, vals, now);
   vals[2] = 1.2400;
   double spreads[4] = {10, 10, 10, 10};
   const int rc = Grind_AutoEjectTrySide(true, 22260101UL, 3.0, 2, true, false,
                                         times, vals, 10, spreads, 4, 10.0, now, 5, 1.5);
   AssertEqInt("LB23 rc", rc, GRIND_EJECT_OK);
   AssertNear("LB23 picks by effective", Grind_OrderGetPriceOpen(2002UL), 1.24811, 1e-9);
   AssertNear("LB23 picks by effective", Grind_OrderGetPriceOpen(2001UL), 1.25030, 1e-9);
   Grind_TestEjectHarnessReset();
}

void Test_LB24_I6ShortRolled()
{
   Grind_TestClearCarryState();
   Grind_VLSet(1002UL, 1.11000);
   AssertTrue("LB24 short rolled ok",
              Grind_ReconExitMatchesEntry(1.10500, 1.10970, 3.0, 0.00001, false, 0.0, false, 1002UL));
   AssertFalse("LB24 short actual rejected",
               Grind_ReconExitMatchesEntry(1.10500, 1.10470, 3.0, 0.00001, false, 0.0, false, 1002UL));
}

void Test_LB25_QueueShortRolled()
{
   Grind_OrderTestReset();
   Grind_TestResetSideState();
   g_grind_order_test_active = true;
   Adr151_TestSeedSlotSeams(200, 100, 0);
   Grind_MarketTestSeed(1.11010, 1.11012, 0, 0);
   ArrayResize(g_grind_short.layers, 4);
   g_grind_short.layers[0].entry_price = 1.10500;
   g_grind_short.layers[0].layer_index = 0;
   g_grind_short.layers[0].position_ticket = 5401UL;
   g_grind_short.layers[0].exit_order_ticket = 0;
   g_grind_short.layers[0].exit_position_ticket = 0;
   g_grind_short.layers[0].exit_target = 0.0;
   g_grind_short.layers[1].entry_price = 1.10600;
   g_grind_short.layers[1].layer_index = 1;
   g_grind_short.layers[1].position_ticket = 5402UL;
   g_grind_short.layers[1].exit_order_ticket = 0;
   g_grind_short.layers[1].exit_position_ticket = 0;
   g_grind_short.layers[1].exit_target = 0.0;
   g_grind_short.layers[2].entry_price = 1.10700;
   g_grind_short.layers[2].layer_index = 2;
   g_grind_short.layers[2].position_ticket = 5403UL;
   g_grind_short.layers[2].exit_order_ticket = 0;
   g_grind_short.layers[2].exit_position_ticket = 0;
   g_grind_short.layers[2].exit_target = 0.0;
   g_grind_short.layers[3].entry_price = 1.10800;
   g_grind_short.layers[3].layer_index = 3;
   g_grind_short.layers[3].position_ticket = 5404UL;
   g_grind_short.layers[3].exit_order_ticket = 0;
   g_grind_short.layers[3].exit_position_ticket = 0;
   g_grind_short.layers[3].exit_target = 0.0;
   Grind_VLSet(5401UL, 1.11000);
   Grind_ExitQManageSide(g_grind_short, false, 22260101UL, "OPT", 0.01, 3.0);
   AssertTrue("LB25 rolled S0 rests", g_grind_short.layers[0].exit_order_ticket != 0);
   AssertTrue("LB25 oldest unrolled S1 rests", g_grind_short.layers[1].exit_order_ticket != 0);
   AssertTrue("LB25 S3 bare", g_grind_short.layers[3].exit_order_ticket == 0);
   AssertNear("LB25 rolled exit price", g_grind_short.layers[0].exit_target, 1.10970, 1e-9);
   Grind_OrderTestReset();
   Grind_TestResetSideState();
}

void Test_LB26_CarryBaseShortRolled()
{
   Grind_TestClearCarryState();
   Grind_TestResetSideState();
   ArrayResize(g_grind_short.layers, 1);
   g_grind_short.layers[0].entry_price = 1.10500;
   g_grind_short.layers[0].position_ticket = 1001UL;
   g_grind_short.layers[0].exit_order_ticket = 2001UL;
   g_grind_short.layers[0].layer_index = 0;
   Grind_VLSet(1001UL, 1.11000);
   Grind_CarryExitPassBegin(_Symbol, 22260101UL, 3.0);
   Grind_VLSet(1001UL, 1.11000);
   AssertTrue("LB26 one work item", g_grind_carry_exit_work_count == 1);
   AssertNear("LB26 base", g_grind_carry_exit_work_formula[0], 1.10970, 1e-9);
   AssertNear("LB26 shift base", Grind_CarryWorkBase(0, 3.0, 0.00001), 1.10970, 1e-9);
   Grind_CarryExitPassReset();
   Grind_TestResetSideState();
}

void Test_LB27_SignGuardShort()
{
   Grind_TestClearCarryState();
   Grind_VLSet(1001UL, 1.11000);
   AssertFalse("LB27 short rolled not blocked",
               Grind_CarrySignGuardAppliesAtShift(1001UL, 1.10500, 1.10970, false));
   AssertTrue("LB27 short ordinary blocked",
              Grind_CarrySignGuardAppliesAtShift(1002UL, 1.10500, 1.10970, false));
}

void Test_LB28_AnchorShort()
{
   Grind_TestResetSideState();
   ArrayResize(g_grind_short.layers, 2);
   g_grind_short.layers[0].entry_price = 1.10500;
   g_grind_short.layers[0].layer_index = 0;
   g_grind_short.layers[0].position_ticket = 5501UL;
   g_grind_short.layers[1].entry_price = 1.10600;
   g_grind_short.layers[1].layer_index = 1;
   g_grind_short.layers[1].position_ticket = 5502UL;
   AssertNear("LB28 unrolled", Grind_ComputeAddTarget(g_grind_short, false, 10.0), 1.10700, 1e-9);
   Grind_VLSet(5501UL, 1.11000);
   AssertNear("LB28 rolled", Grind_ComputeAddTarget(g_grind_short, false, 10.0), 1.11100, 1e-9);
   Grind_TestResetSideState();
}

void Test_LB29_CloseRolledFlag()
{
   Grind_DealTestReset();
   Grind_TestResetSideState();
   Grind_ArchiveTestConfigureCommon();
   const ulong pos = 99207UL;
   const ulong exit_pos = 99217UL;
   GlobalVariableSet("GRIND_VL_99207", 1.10000);
   ArrayResize(g_grind_long.layers, 1);
   g_grind_long.layers[0].entry_price = 1.25000;
   g_grind_long.layers[0].position_ticket = pos;
   g_grind_long.layers[0].exit_position_ticket = exit_pos;
   g_grind_long.layers[0].layer_index = 0;
   g_grind_deal_test_active = true;
   Grind_TestAppendDeal(99207UL, "#99207 by #99217", DEAL_ENTRY_OUT_BY, 0, pos, 2.50, -0.30, -0.20);
   Grind_HandleSideDealFill(g_grind_long, true, 99207UL, 22260101UL, "OPT", 3.0, 4.0, 12, 0.01);
   AssertContains("LB29 rolled true", Grind_ScalpEventQueuePeek(), "\"rolled\":true");
   AssertContains("LB29 ejected false", Grind_ScalpEventQueuePeek(), "\"ejected\":false");
   AssertContains("LB29 roll filled archived", Adr162b_ArchiveFind("ROLL_FILLED", 0), "99207");
   const string unrolled = Grind_BuildScalpClosedPayload(
      "GRIND_GBPUSD_OPT", "GBPUSD", "LONG", 1.25000, 1.25030, 2, 3, 2.00,
      D'2026.09.06 14:30:00', false, 10800, 1514582088);
   AssertContains("LB29 unrolled payload", unrolled, "\"rolled\":false");
   Grind_DealTestReset();
   Grind_TestResetSideState();
   Adr151_TestResetAll();
}

void Test_LB30_RestartRolledStartup()
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
   AssertTrue("LB30 startup ok",
              Grind_RebuildBookFromTickets(tickets, 6, magic, "OPT", exit_pips, 12, point,
                                           long_out, short_out, reason, true));
   for(int i = 0; i < Grind_SideDepth(long_out); i++) {
      if(long_out.layers[i].position_ticket == 1001UL) {
         AssertNear("LB30 rolled target", long_out.layers[i].exit_target, 1.10030, 1e-9);
         break;
      }
   }
   // five = VL8's tickets minus 2001 (index 1): the rolled L0's exit is missing
   GrindReconTicket five[5];
   int k = 0;
   for(int j = 0; j < 6; j++) {
      if(j == 1)
         continue;
      five[k] = tickets[j];
      k++;
   }
   g_grind_recon_exit_shortfall_long = 0;
   AssertTrue("LB30 shortfall tolerated",
              Grind_RebuildBookFromTickets(five, 5, magic, "OPT", exit_pips, 12, point,
                                           long_out, short_out, reason, true)
              && g_grind_recon_exit_shortfall_long == 1);
   AssertFalse("LB30 strict fails",
               Grind_RebuildBookFromTickets(five, 5, magic, "OPT", exit_pips, 12, point,
                                            long_out, short_out, reason, false));
   Grind_ReconFailureClear();
}

void Test_LB31_RollDetail()
{
   const string d = Grind_LatticeRollDetail(7001UL, true, 0, 1.21400, 1.20600, 1.20650, 0.0,
                                            false, 0.00750, 1, true, "auto");
   AssertContains("LB31 ticket", d, "\"ticket\":7001");
   AssertContains("LB31 side", d, "\"side\":\"L\"");
   AssertContains("LB31 level", d, "\"level\":1.20600");
   AssertContains("LB31 target", d, "\"target\":1.20650");
   AssertContains("LB31 cost", d, "\"cost\":0.00750");
   AssertContains("LB31 cost pips", d, "\"cost_pips\":75.0");
   AssertContains("LB31 rolled", d, "\"rolled\":1");
   AssertContains("LB31 was ejected", d, "\"was_ejected\":true");
   AssertContains("LB31 source", d, "\"source\":\"auto\"");
}

//+------------------------------------------------------------------+
// LB32: the doubling backoff must stay capped at 1800 s however many
// failures have accumulated (60 * 2^(n-1) overflows int from n = 27).
void Test_LB32_BackoffCapNoOverflow()
{
   Adr162b_SeedLong8();
   Grind_MarketTestSeed(1.20590, 1.20600, 0, 0);
   g_grind_order_test_send_ok = false;
   g_grind_vl_fail_count_long = 40;
   const datetime now = D'2026.09.28 10:00';
   Adr162b_TryLong(now);
   AssertTrue("LB32 attempted", g_grind_order_test_modify_calls == 1);
   Adr162b_TryLong(now + 1799);
   AssertTrue("LB32 capped wait holds", g_grind_order_test_modify_calls == 1);
   Adr162b_TryLong(now + 1800);
   AssertTrue("LB32 retry at cap", g_grind_order_test_modify_calls == 2);
   Adr162b_Reset();
}

#endif // FXGRIND_TESTS_ADR162B_MQH
