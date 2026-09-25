//+------------------------------------------------------------------+
//| fxgrind_tests_c54.mqh — backlog C54 ADR-162 B1 post-audit (LB33+) |
//+------------------------------------------------------------------+
#ifndef FXGRIND_TESTS_C54_MQH
#define FXGRIND_TESTS_C54_MQH

//+------------------------------------------------------------------+
void C54_FinishCarryPass()
{
   for(int i = 0; i < 10 && g_grind_carry_exit_pass_active; i++)
      Grind_CarryExitPassStep(_Symbol, 22260101UL, 5.0, g_grind_carry_test_server_time);
}

//+------------------------------------------------------------------+
void C54_SeedLong8Carry(const double bid, const double ask)
{
   Grind_CarryTestReset();
   Adr162b_SeedLong8();
   F2_TestSeedCarryWindow(22260101UL);
   Grind_CarryTestSeedTick(g_grind_carry_test_server_time, bid, ask);
   for(int i = 0; i < ArraySize(g_grind_long.layers); i++) {
      const ulong pos = g_grind_long.layers[i].position_ticket;
      if(pos == 0)
         continue;
      Grind_CarryTestSetPosition(pos, -0.10, 0.01, D'2026.09.01 12:00');
      Grind_PositionTestAdd(pos);
   }
   Grind_MarketTestSeed(bid, ask, 0, 0);
   g_grind_carry_eligible_magic = 22260101UL;
   Grind_CarryExitPassBegin(_Symbol, 22260101UL, 5.0);
}

//+------------------------------------------------------------------+
bool C54_AllRestingI6Long()
{
   int n = 0;
   bool ok = true;
   for(int i = 0; i < ArraySize(g_grind_long.layers); i++) {
      if(g_grind_long.layers[i].exit_order_ticket == 0)
         continue;
      n++;
      const ulong pos = g_grind_long.layers[i].position_ticket;
      const double entry = g_grind_long.layers[i].entry_price;
      const ulong ot = g_grind_long.layers[i].exit_order_ticket;
      const double op = Grind_OrderGetPriceOpen(ot);
      if(!Grind_ReconExitMatchesEntry(entry, op, 5.0, _Point, true,
                                      Grind_CarryShiftGet(pos), false, pos))
         ok = false;
   }
   return ok && n == 2;
}

//+------------------------------------------------------------------+
bool C54_AllAccruedLong()
{
   for(int i = 0; i < ArraySize(g_grind_long.layers); i++) {
      const ulong pos = g_grind_long.layers[i].position_ticket;
      if(pos == 0)
         continue;
      if(MathAbs(Grind_CarryAccruedGet(pos)) <= 2.0 * _Point)
         return false;
   }
   return true;
}

//+------------------------------------------------------------------+
bool C54_I6Long(const int idx)
{
   const ulong pos = g_grind_long.layers[idx].position_ticket;
   const double entry = g_grind_long.layers[idx].entry_price;
   const ulong ot = g_grind_long.layers[idx].exit_order_ticket;
   const double op = Grind_OrderGetPriceOpen(ot);
   return Grind_ReconExitMatchesEntry(entry, op, 5.0, _Point, true,
                                      Grind_CarryShiftGet(pos), false, pos);
}

//+------------------------------------------------------------------+
void Test_LB33_OrderGoneNoBackoff()
{
   Adr162b_SeedLong8();
   Grind_OrderTestRemove(8001UL);
   Grind_MarketTestSeed(1.20590, 1.20600, 0, 0);
   const datetime now = D'2026.09.28 10:00';
   const int rc = Adr162b_TryLong(now);
   AssertEqInt("LB33 no roll", rc, 0);
   AssertFalse("LB33 no vl", Grind_VLHas(7001UL));
   AssertTrue("LB33 no broker call", g_grind_order_test_modify_calls == 0);
   AssertTrue("LB33 not refused", Adr162b_ArchiveFind("ROLL_REFUSED", 0) == "");
   AssertEqInt("LB33 no failure counted", g_grind_vl_fail_count_long, 0);
   AssertEqInt("LB33 no backoff", (int)g_grind_vl_backoff_long, 0);
   Adr162b_Reset();
}

//+------------------------------------------------------------------+
void Test_LB34_RollRefusals()
{
   Adr162b_SeedLong8();
   Grind_VLSet(7001UL, 1.20600);
   Grind_MarketTestSeed(1.20590, 1.20600, 0, 0);
   int rc = Grind_LatticeRollLayer(g_grind_long, true, 0, 22260101UL, "OPT", 0.01, 5.0, 1.20600,
                                   "auto");
   AssertTrue("LB34 already rolled",
              rc == GRIND_ROLL_ALREADY_ROLLED && g_grind_order_test_modify_calls == 0
              && MathAbs(Grind_VLGet(7001UL) - 1.20600) <= 1e-9);
   Adr162b_Reset();

   Adr162b_SeedLong8();
   g_grind_long.layers[0].exit_order_ticket = 0;
   g_grind_long.layers[0].exit_position_ticket = 9999UL;
   rc = Grind_LatticeRollLayer(g_grind_long, true, 0, 22260101UL, "OPT", 0.01, 5.0, 1.20600,
                               "auto");
   AssertEqInt("LB34 closing, deal processed", rc, GRIND_ROLL_CLOSING);
   Adr162b_Reset();

   Adr162b_SeedLong8();
   Grind_OrderTestRemove(8001UL);
   rc = Grind_LatticeRollLayer(g_grind_long, true, 0, 22260101UL, "OPT", 0.01, 5.0, 1.20600,
                               "auto");
   AssertEqInt("LB34 closing, order gone", rc, GRIND_ROLL_CLOSING);
   AssertTrue("LB34 order gone not refused", Adr162b_ArchiveFind("ROLL_REFUSED", 0) == "");
   AssertFalse("LB34 order gone no vl", Grind_VLHas(7001UL));
   Adr162b_Reset();
}

//+------------------------------------------------------------------+
void Test_LB35_FailCountReset()
{
   Adr162b_SeedLong8();
   Grind_MarketTestSeed(1.20590, 1.20600, 0, 0);
   g_grind_order_test_send_ok = false;
   const datetime now = D'2026.09.28 10:00';
   Adr162b_TryLong(now);
   AssertEqInt("LB35 failure counted", g_grind_vl_fail_count_long, 1);
   g_grind_order_test_send_ok = true;
   const int rc = Adr162b_TryLong(now + 61);
   AssertTrue("LB35 reset after success", rc == 1 && g_grind_vl_fail_count_long == 0);
   Adr162b_Reset();
}

//+------------------------------------------------------------------+
void Test_LB36_ShortGapFiresEveryLevel()
{
   Adr162b_SeedShort8();
   Grind_MarketTestSeed(1.19810, 1.19820, 0, 0);
   const datetime now = D'2026.09.28 10:00';
   const int rc = Adr162b_TryShort(now);
   AssertEqInt("LB36 five rolls", rc, 5);
   AssertNear("LB36 vl L0", Grind_VLGet(7101UL), 1.19400, 1e-9);
   AssertNear("LB36 vl L4", Grind_VLGet(7105UL), 1.19800, 1e-9);
   AssertFalse("LB36 L5 unrolled", Grind_VLHas(7106UL));
   AssertTrue("LB36 two resting", Adr151_TestCountRestingExits(g_grind_short) == 2);
   const int i4 = 4;
   AssertTrue("LB36 newest rolled rests",
              g_grind_short.layers[i4].exit_order_ticket != 0
              && MathAbs(Grind_OrderGetPriceOpen(g_grind_short.layers[i4].exit_order_ticket)
                         - 1.19750) <= 1e-9);
   const int i5 = 5;
   AssertTrue("LB36 oldest unrolled rests",
              g_grind_short.layers[i5].exit_order_ticket != 0
              && MathAbs(Grind_OrderGetPriceOpen(g_grind_short.layers[i5].exit_order_ticket)
                         - 1.19050) <= 1e-9);
   AssertTrue("LB36 calls",
              g_grind_order_test_modify_calls == 5 && g_grind_order_test_remove_calls == 5
              && g_grind_order_test_place_calls == 5);
   bool order_ok = true;
   for(int k = 0; k < 5; k++) {
      if(StringFind(Adr162b_ArchiveFind("ROLL_ACCEPTED", k), IntegerToString(7101 + k)) < 0)
         order_ok = false;
   }
   AssertTrue("LB36 in order", order_ok);
   Adr162b_Reset();
}

//+------------------------------------------------------------------+
void Test_LB37_PassThenRollBranchM()
{
   const datetime now = D'2026.09.28 10:00';
   C54_SeedLong8Carry(1.20590, 1.20600);
   Grind_CarryExitPassStep(_Symbol, 22260101UL, 5.0, g_grind_carry_test_server_time);
   AssertTrue("LB37 L0 accrued before roll",
              MathAbs(Grind_CarryAccruedGet(7001UL)) > 2.0 * _Point);
   const int rc = Adr162b_TryLong(now);
   AssertTrue("LB37 rolled mid-pass", rc == 1 && g_grind_carry_exit_pass_active);
   C54_FinishCarryPass();
   AssertTrue("LB37 pass completed",
              !g_grind_carry_exit_pass_active
              && Adr162b_ArchiveFind("CARRY_PASS_SUMMARY", 0) != "");
   const double p0 = Grind_OrderGetPriceOpen(8001UL);
   AssertTrue("LB37 L0 off bare level", MathAbs(p0 - 1.20650) > 2.0 * _Point);
   AssertTrue("LB37 L0 I6", C54_I6Long(0));
   AssertTrue("LB37 all resting I6", C54_AllRestingI6Long());
   AssertTrue("LB37 all accrued", C54_AllAccruedLong());
   Adr162b_Reset();
   Grind_CarryTestReset();
   Grind_CarryGateReset(22260101UL);
}

//+------------------------------------------------------------------+
void Test_LB38_RollThenPassBranchM()
{
   const datetime now = D'2026.09.28 10:00';
   C54_SeedLong8Carry(1.20590, 1.20600);
   const int rc = Adr162b_TryLong(now);
   AssertTrue("LB38 rolled before first step", rc == 1 && g_grind_carry_exit_work_cursor == 0);
   C54_FinishCarryPass();
   AssertTrue("LB38 pass completed",
              !g_grind_carry_exit_pass_active
              && Adr162b_ArchiveFind("CARRY_PASS_SUMMARY", 0) != "");
   const double p0 = Grind_OrderGetPriceOpen(8001UL);
   AssertTrue("LB38 L0 off bare level", MathAbs(p0 - 1.20650) > 2.0 * _Point);
   AssertTrue("LB38 L0 I6", C54_I6Long(0));
   AssertTrue("LB38 all resting I6", C54_AllRestingI6Long());
   AssertTrue("LB38 all accrued", C54_AllAccruedLong());
   Adr162b_Reset();
   Grind_CarryTestReset();
   Grind_CarryGateReset(22260101UL);
}

//+------------------------------------------------------------------+
void Test_LB39_RollMidPassBranchS()
{
   const datetime now = D'2026.09.28 10:00';
   const double bid = 1.19790;
   const double ask = 1.19800;
   Grind_CarryTestReset();
   Adr162b_SeedLong8();
   for(int i = 0; i < 6; i++)
      Grind_VLSet(7001UL + (ulong)i, NormalizeDouble(1.20600 - 0.00100 * i, 5));
   Adr151_TestSetupLongLayer(g_grind_long, 6, 8, 1.20000, 7009UL, 0, 5.0);
   Adr151_TestSetupLongLayer(g_grind_long, 7, 9, 1.19900, 7010UL, 0, 5.0);
   Adr162b_RefreshExit(g_grind_long, true, 0, 8001UL);
   Adr162b_RefreshExit(g_grind_long, true, 7, 8010UL);
   F2_TestSeedCarryWindow(22260101UL);
   Grind_CarryTestSeedTick(g_grind_carry_test_server_time, bid, ask);
   const ulong pos_list[8] = {7001UL, 7002UL, 7003UL, 7004UL, 7005UL, 7006UL, 7009UL, 7010UL};
   for(int j = 0; j < 8; j++) {
      Grind_CarryTestSetPosition(pos_list[j], -0.10, 0.01, D'2026.09.01 12:00');
      Grind_PositionTestAdd(pos_list[j]);
   }
   Grind_MarketTestSeed(bid, ask, 0, 0);
   g_grind_carry_eligible_magic = 22260101UL;
   Grind_CarryExitPassBegin(_Symbol, 22260101UL, 5.0);
   const int rc = Adr162b_TryLong(now);
   AssertTrue("LB39 one roll, branch S",
              rc == 1 && MathAbs(Grind_VLGet(7009UL) - 1.19800) <= 1e-9
              && g_grind_order_test_modify_calls == 0);
   AssertTrue("LB39 rolled layer has an exit", g_grind_long.layers[6].exit_order_ticket != 0);
   C54_FinishCarryPass();
   AssertTrue("LB39 pass completed",
              !g_grind_carry_exit_pass_active
              && Adr162b_ArchiveFind("CARRY_PASS_SUMMARY", 0) != "");
   const ulong ex6 = g_grind_long.layers[6].exit_order_ticket;
   const double p6 = Grind_OrderGetPriceOpen(ex6);
   AssertTrue("LB39 rolled exit off bare level", MathAbs(p6 - 1.19850) > 2.0 * _Point);
   AssertTrue("LB39 rolled exit I6", C54_I6Long(6));
   AssertTrue("LB39 all resting I6", C54_AllRestingI6Long());
   bool all_acc = true;
   for(int j = 0; j < 8; j++) {
      if(MathAbs(Grind_CarryAccruedGet(pos_list[j])) <= 2.0 * _Point)
         all_acc = false;
   }
   AssertTrue("LB39 all accrued", all_acc);
   Adr162b_Reset();
   Grind_CarryTestReset();
   Grind_CarryGateReset(22260101UL);
}

#endif // FXGRIND_TESTS_C54_MQH
