//+------------------------------------------------------------------+
//| fxgrind_tests_c55.mqh — backlog C55 ADR-162 phase B2 (VC/VS/VCS/LB40+) |
//+------------------------------------------------------------------+
#ifndef FXGRIND_TESTS_C55_MQH
#define FXGRIND_TESTS_C55_MQH

//+------------------------------------------------------------------+
void C55_Reset()
{
   Adr162b_Reset();
   Grind_CarryTestReset();
   Grind_CarryGateReset(22260101UL);
   Grind_LatticeTestTicksReset();
}

//+------------------------------------------------------------------+
void C55_OpenTimes(const bool is_long, const datetime first)
{
   GrindSideState side = is_long ? g_grind_long : g_grind_short;
   for(int i = 0; i < ArraySize(side.layers); i++) {
      const ulong pos = side.layers[i].position_ticket;
      if(pos == 0)
         continue;
      Grind_CarryTestSetOpenTime(pos, first + 60 * i);
   }
}

//+------------------------------------------------------------------+
void C55_OnTick(const datetime now)
{
   Grind_LatticeOnTick(22260101UL, "OPT", 0.01, true, 5.0, 10.0, 8, false, now);
}

//+------------------------------------------------------------------+
void C55_SeedShort8Carry(const double bid, const double ask)
{
   Grind_CarryTestReset();
   Adr162b_SeedShort8();
   F2_TestSeedCarryWindow(22260101UL);
   Grind_CarryTestSeedTick(g_grind_carry_test_server_time, bid, ask);
   for(int i = 0; i < ArraySize(g_grind_short.layers); i++) {
      const ulong pos = g_grind_short.layers[i].position_ticket;
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
bool C55_I6Short(const int idx)
{
   const ulong pos = g_grind_short.layers[idx].position_ticket;
   const double entry = g_grind_short.layers[idx].entry_price;
   const ulong ot = g_grind_short.layers[idx].exit_order_ticket;
   const double op = Grind_OrderGetPriceOpen(ot);
   return Grind_ReconExitMatchesEntry(entry, op, 5.0, _Point, false,
                                      Grind_CarryShiftGet(pos), false, pos);
}

//+------------------------------------------------------------------+
bool C55_AllRestingI6Short()
{
   int n = 0;
   bool ok = true;
   for(int i = 0; i < ArraySize(g_grind_short.layers); i++) {
      if(g_grind_short.layers[i].exit_order_ticket == 0)
         continue;
      n++;
      const ulong pos = g_grind_short.layers[i].position_ticket;
      const double entry = g_grind_short.layers[i].entry_price;
      const ulong ot = g_grind_short.layers[i].exit_order_ticket;
      const double op = Grind_OrderGetPriceOpen(ot);
      if(!Grind_ReconExitMatchesEntry(entry, op, 5.0, _Point, false,
                                      Grind_CarryShiftGet(pos), false, pos))
         ok = false;
   }
   return ok && n == 2;
}

//+------------------------------------------------------------------+
bool C55_AllAccruedShort()
{
   for(int i = 0; i < ArraySize(g_grind_short.layers); i++) {
      const ulong pos = g_grind_short.layers[i].position_ticket;
      if(pos == 0)
         continue;
      if(MathAbs(Grind_CarryAccruedGet(pos)) <= 2.0 * _Point)
         return false;
   }
   return true;
}

//+------------------------------------------------------------------+
void Test_VC1_TickExtremeLong()
{
   C55_Reset();
   long msc[3] = {1000, 2000, 3000};
   double bid[3] = {1.20000, 1.19980, 1.19900};
   double ask[3] = {1.20010, 1.19990, 0.0};
   double x = 0.0;
   AssertTrue("VC1 found", Grind_LatticeTickExtreme(msc, bid, ask, 3, 1500, true, x));
   AssertNear("VC1 min ask", x, 1.19990, 1e-9);
   AssertFalse("VC1 nothing in range", Grind_LatticeTickExtreme(msc, bid, ask, 3, 2500, true, x));
   C55_Reset();
}

//+------------------------------------------------------------------+
void Test_VC2_TickExtremeShort()
{
   C55_Reset();
   long msc[3] = {1000, 2000, 3000};
   double bid[3] = {1.20000, 1.19980, 1.19900};
   double ask[3] = {1.20010, 1.19990, 0.0};
   double x = 0.0;
   AssertTrue("VC2 found", Grind_LatticeTickExtreme(msc, bid, ask, 3, 0, false, x));
   AssertNear("VC2 max bid", x, 1.20000, 1e-9);
   C55_Reset();
}

//+------------------------------------------------------------------+
void Test_VC3_MissedDipRolls()
{
   C55_Reset();
   Adr162b_SeedLong8();
   C55_OpenTimes(true, D'2026.09.28 09:00');
   Grind_MarketTestSeed(1.20690, 1.20700, 0, 0);
   Grind_LatticeTestAddTick(D'2026.09.28 09:30', 1.20580, 1.20590);
   C55_OnTick(D'2026.09.28 10:00');
   AssertNear("VC3 rolled L0", Grind_VLGet(7001UL), 1.20600, 1e-9);
   AssertFalse("VC3 one level only", Grind_VLHas(7002UL));
   const double p = Grind_OrderGetPriceOpen(8001UL);
   AssertTrue("VC3 exit clamped passive", p >= 1.20700 - 1e-9 && p <= 1.20720 + 1e-9);
   C55_Reset();
}

//+------------------------------------------------------------------+
void Test_VC4_DipBeforeNewestOpen()
{
   C55_Reset();
   Adr162b_SeedLong8();
   C55_OpenTimes(true, D'2026.09.28 09:00');
   Grind_MarketTestSeed(1.20690, 1.20700, 0, 0);
   Grind_LatticeTestAddTick(D'2026.09.28 09:05', 1.20580, 1.20590);
   C55_OnTick(D'2026.09.28 10:00');
   AssertFalse("VC4 no roll", Grind_VLHas(7001UL));
   C55_Reset();
}

//+------------------------------------------------------------------+
void Test_VC5_BidDipIsNotAskDip()
{
   C55_Reset();
   Adr162b_SeedLong8();
   C55_OpenTimes(true, D'2026.09.28 09:00');
   Grind_MarketTestSeed(1.20690, 1.20700, 0, 0);
   Grind_LatticeTestAddTick(D'2026.09.28 09:30', 1.20580, 1.20610);
   C55_OnTick(D'2026.09.28 10:00');
   AssertFalse("VC5 no roll", Grind_VLHas(7001UL));
   C55_Reset();
}

//+------------------------------------------------------------------+
void Test_VC6_ShortMissedSpike()
{
   C55_Reset();
   Adr162b_SeedShort8();
   C55_OpenTimes(false, D'2026.09.28 09:00');
   Grind_MarketTestSeed(1.19290, 1.19300, 0, 0);
   Grind_LatticeTestAddTick(D'2026.09.28 09:30', 1.19410, 1.19420);
   C55_OnTick(D'2026.09.28 10:00');
   AssertNear("VC6 rolled S0", Grind_VLGet(7101UL), 1.19400, 1e-9);
   C55_Reset();
}

//+------------------------------------------------------------------+
void Test_VC7_GapFromHistory()
{
   C55_Reset();
   Adr162b_SeedLong8();
   C55_OpenTimes(true, D'2026.09.28 09:00');
   Grind_MarketTestSeed(1.20690, 1.20700, 0, 0);
   Grind_LatticeTestAddTick(D'2026.09.28 09:30', 1.20580, 1.20590);
   Grind_LatticeTestAddTick(D'2026.09.28 09:31', 1.20480, 1.20490);
   C55_OnTick(D'2026.09.28 10:00');
   AssertNear("VC7 L0 rolled", Grind_VLGet(7001UL), 1.20600, 1e-9);
   AssertNear("VC7 L1 rolled", Grind_VLGet(7002UL), 1.20500, 1e-9);
   AssertFalse("VC7 L2 not rolled", Grind_VLHas(7003UL));
   C55_Reset();
}

//+------------------------------------------------------------------+
void Test_VC8_ExtremeAcrossTicks()
{
   C55_Reset();
   Adr162b_SeedLong8();
   C55_OpenTimes(true, D'2026.09.28 09:00');
   Grind_MarketTestSeed(1.20690, 1.20700, 0, 0);
   Grind_LatticeTestAddTick(D'2026.09.28 09:30', 1.20640, 1.20650);
   C55_OnTick(D'2026.09.28 09:35');
   AssertFalse("VC8 no roll yet", Grind_VLHas(7001UL));
   AssertNear("VC8 extreme tracked", g_grind_vl_extreme_long, 1.20650, 1e-9);
   Grind_LatticeTestAddTick(D'2026.09.28 09:40', 1.20585, 1.20595);
   C55_OnTick(D'2026.09.28 09:45');
   AssertNear("VC8 rolled on the later tick", Grind_VLGet(7001UL), 1.20600, 1e-9);
   C55_Reset();
}

//+------------------------------------------------------------------+
void Test_VC9_CopyFailureRetries()
{
   C55_Reset();
   Adr162b_SeedLong8();
   C55_OpenTimes(true, D'2026.09.28 09:00');
   Grind_MarketTestSeed(1.20690, 1.20700, 0, 0);
   Grind_LatticeTestAddTick(D'2026.09.28 09:30', 1.20580, 1.20590);
   g_grind_vl_test_ticks_fail = true;
   C55_OnTick(D'2026.09.28 10:00');
   AssertFalse("VC9 no roll while unavailable", Grind_VLHas(7001UL));
   g_grind_vl_test_ticks_fail = false;
   C55_OnTick(D'2026.09.28 10:00' + 1);
   AssertNear("VC9 rolled after retry", Grind_VLGet(7001UL), 1.20600, 1e-9);
   C55_Reset();
}

//+------------------------------------------------------------------+
void Test_VC10_LookbackCap()
{
   C55_Reset();
   Adr162b_SeedLong8();
   C55_OpenTimes(true, D'2026.09.26 09:00');
   Grind_MarketTestSeed(1.20690, 1.20700, 0, 0);
   Grind_LatticeTestAddTick(D'2026.09.27 09:30', 1.20580, 1.20590);
   C55_OnTick(D'2026.09.28 10:00');
   AssertFalse("VC10 older than 24 h ignored", Grind_VLHas(7001UL));
   C55_Reset();
   Adr162b_SeedLong8();
   C55_OpenTimes(true, D'2026.09.26 09:00');
   Grind_MarketTestSeed(1.20690, 1.20700, 0, 0);
   Grind_LatticeTestAddTick(D'2026.09.27 11:00', 1.20580, 1.20590);
   C55_OnTick(D'2026.09.28 10:00');
   AssertNear("VC10 inside 24 h rolls", Grind_VLGet(7001UL), 1.20600, 1e-9);
   C55_Reset();
}

//+------------------------------------------------------------------+
void Test_VC11_BelowCapResets()
{
   C55_Reset();
   Adr162b_SeedLong8();
   C55_OpenTimes(true, D'2026.09.28 09:00');
   Grind_MarketTestSeed(1.20690, 1.20700, 0, 0);
   Grind_LatticeTestAddTick(D'2026.09.28 09:30', 1.20640, 1.20650);
   C55_OnTick(D'2026.09.28 09:35');
   AssertNear("VC11 tracked at cap", g_grind_vl_extreme_long, 1.20650, 1e-9);
   ArrayResize(g_grind_long.layers, 7);
   C55_OnTick(D'2026.09.28 09:36');
   AssertTrue("VC11 reset below cap",
              !g_grind_vl_tracking_long && g_grind_vl_extreme_long == 0.0);
   Adr151_TestSetupLongLayer(g_grind_long, 7, 7, 1.20700, 7009UL, 0, 5.0);
   Grind_CarryTestSetOpenTime(7009UL, D'2026.09.28 09:50');
   Grind_LatticeTestAddTick(D'2026.09.28 09:45', 1.20580, 1.20590);
   C55_OnTick(D'2026.09.28 09:55');
   AssertFalse("VC11 dip before re-cap ignored", Grind_VLHas(7001UL));
   C55_Reset();
}

//+------------------------------------------------------------------+
void Test_VC12_BackoffKeepsExtreme()
{
   C55_Reset();
   Adr162b_SeedLong8();
   C55_OpenTimes(true, D'2026.09.28 09:00');
   Grind_MarketTestSeed(1.20690, 1.20700, 0, 0);
   Grind_LatticeTestAddTick(D'2026.09.28 09:30', 1.20580, 1.20590);
   g_grind_order_test_send_ok = false;
   C55_OnTick(D'2026.09.28 10:00');
   AssertTrue("VC12 first attempt failed",
              g_grind_order_test_modify_calls == 1 && !Grind_VLHas(7001UL));
   g_grind_order_test_send_ok = true;
   C55_OnTick(D'2026.09.28 10:00' + 61);
   AssertNear("VC12 rolled after backoff", Grind_VLGet(7001UL), 1.20600, 1e-9);
   C55_Reset();
}

//+------------------------------------------------------------------+
void Test_VS1_StrandedWarnOnce()
{
   C55_Reset();
   Adr162b_SeedLong8();
   for(int i = 0; i < 8; i++)
      Grind_VLSet(7001UL + (ulong)i, NormalizeDouble(1.20600 - 0.00100 * i, 5));
   Adr162b_RefreshExit(g_grind_long, true, 0, 8001UL);
   Adr162b_RefreshExit(g_grind_long, true, 7, 8008UL);
   Grind_MarketTestSeed(1.19780, 1.19790, 0, 0);
   Adr162b_TryLong(D'2026.09.28 10:00');
   AssertTrue("VS1 one step no warn", Adr162b_ArchiveFind("ROLL_STRANDED", 0) == "");
   Grind_MarketTestSeed(1.19690, 1.19700, 0, 0);
   Adr162b_TryLong(D'2026.09.28 10:00' + 1);
   AssertTrue("VS1 two steps warn", Adr162b_ArchiveFind("ROLL_STRANDED", 0) != "");
   AssertTrue("VS1 latch set", g_grind_vl_stranded_warned_long);
   Adr162b_TryLong(D'2026.09.28 10:00' + 2);
   AssertTrue("VS1 warned once", Adr162b_ArchiveFind("ROLL_STRANDED", 1) == "");
   ArrayResize(g_grind_long.layers, 7);
   C55_OnTick(D'2026.09.28 10:00' + 3);
   AssertFalse("VS1 latch reset below cap", g_grind_vl_stranded_warned_long);
   C55_Reset();
}

//+------------------------------------------------------------------+
void Test_VS2_StrandedShort()
{
   C55_Reset();
   Adr162b_SeedShort8();
   for(int i = 0; i < 8; i++)
      Grind_VLSet(7101UL + (ulong)i, NormalizeDouble(1.19400 + 0.00100 * i, 5));
   Adr162b_RefreshExit(g_grind_short, false, 0, 8101UL);
   Adr162b_RefreshExit(g_grind_short, false, 7, 8108UL);
   Grind_MarketTestSeed(1.20300, 1.20310, 0, 0);
   Adr162b_TryShort(D'2026.09.28 10:00');
   AssertTrue("VS2 short warn", Adr162b_ArchiveFind("ROLL_STRANDED", 0) != "");
   C55_Reset();
}

//+------------------------------------------------------------------+
void Test_VCS1_ClosingStuckWarn()
{
   C55_Reset();
   Adr162b_SeedLong8();
   g_grind_long.layers[0].exit_order_ticket = 0;
   g_grind_long.layers[0].exit_position_ticket = 9999UL;
   Grind_MarketTestSeed(1.20590, 1.20600, 0, 0);
   Adr162b_TryLong(D'2026.09.28 10:00');
   AssertTrue("VCS1 none at 0 s", Adr162b_ArchiveFind("ROLL_CLOSING_STUCK", 0) == "");
   Adr162b_TryLong(D'2026.09.28 10:00' + 59);
   AssertTrue("VCS1 none at 59 s", Adr162b_ArchiveFind("ROLL_CLOSING_STUCK", 0) == "");
   Adr162b_TryLong(D'2026.09.28 10:00' + 60);
   AssertTrue("VCS1 warn at 60 s", Adr162b_ArchiveFind("ROLL_CLOSING_STUCK", 0) != "");
   Adr162b_TryLong(D'2026.09.28 10:00' + 120);
   AssertTrue("VCS1 once", Adr162b_ArchiveFind("ROLL_CLOSING_STUCK", 1) == "");
   g_grind_long.layers[0].exit_position_ticket = 0;
   g_grind_long.layers[0].exit_order_ticket = 8001UL;
   const int rc = Adr162b_TryLong(D'2026.09.28 10:00' + 121);
   AssertEqInt("VCS1 rolls when clear", rc, 1);
   C55_Reset();
}

//+------------------------------------------------------------------+
void Test_VCS2_OrderGoneStuckWarn()
{
   C55_Reset();
   Adr162b_SeedLong8();
   Grind_OrderTestRemove(8001UL);
   Grind_MarketTestSeed(1.20590, 1.20600, 0, 0);
   Adr162b_TryLong(D'2026.09.28 10:00');
   Adr162b_TryLong(D'2026.09.28 10:00' + 60);
   AssertTrue("VCS2 warn at 60 s", Adr162b_ArchiveFind("ROLL_CLOSING_STUCK", 0) != "");
   C55_Reset();
}

//+------------------------------------------------------------------+
void Test_LB40_ShortRollThenPass()
{
   C55_Reset();
   C55_SeedShort8Carry(1.19400, 1.19410);
   const int rc = Adr162b_TryShort(D'2026.09.28 10:00');
   AssertTrue("LB40 rolled before first step", rc == 1 && g_grind_carry_exit_work_cursor == 0);
   C54_FinishCarryPass();
   AssertTrue("LB40 pass completed",
              !g_grind_carry_exit_pass_active
              && Adr162b_ArchiveFind("CARRY_PASS_SUMMARY", 0) != "");
   const double p0 = Grind_OrderGetPriceOpen(8101UL);
   AssertTrue("LB40 S0 off bare level", MathAbs(p0 - 1.19350) > 2.0 * _Point);
   AssertTrue("LB40 S0 I6", C55_I6Short(0));
   AssertTrue("LB40 all resting I6", C55_AllRestingI6Short());
   AssertTrue("LB40 all accrued", C55_AllAccruedShort());
   C55_Reset();
}

//+------------------------------------------------------------------+
void Test_LB41_GapLoopDuringPass()
{
   C55_Reset();
   C54_SeedLong8Carry(1.20180, 1.20190);
   const int rc = Adr162b_TryLong(D'2026.09.28 10:00');
   AssertTrue("LB41 five rolls mid-pass", rc == 5 && g_grind_carry_exit_pass_active);
   C54_FinishCarryPass();
   AssertTrue("LB41 pass completed",
              !g_grind_carry_exit_pass_active
              && Adr162b_ArchiveFind("CARRY_PASS_SUMMARY", 0) != "");
   AssertTrue("LB41 all resting I6", C54_AllRestingI6Long());
   AssertTrue("LB41 all accrued", C54_AllAccruedLong());
   C55_Reset();
}

//+------------------------------------------------------------------+
void Test_LB42_ClampedCatchupRollThenPass()
{
   C55_Reset();
   C54_SeedLong8Carry(1.20690, 1.20700);
   Grind_LatticeTestAddTick(D'2026.09.28 09:30', 1.20580, 1.20590);
   C55_OnTick(D'2026.09.28 10:00');
   AssertNear("LB42 rolled via catch-up", Grind_VLGet(7001UL), 1.20600, 1e-9);
   AssertTrue("LB42 shift recorded", GlobalVariableCheck(Grind_CarryShiftGvName(7001UL)));
   C54_FinishCarryPass();
   AssertTrue("LB42 pass completed",
              !g_grind_carry_exit_pass_active
              && Adr162b_ArchiveFind("CARRY_PASS_SUMMARY", 0) != "");
   AssertTrue("LB42 L0 I6", C54_I6Long(0));
   AssertTrue("LB42 all accrued", C54_AllAccruedLong());
   C55_Reset();
}

//+------------------------------------------------------------------+
void Test_LB43_SignGuardAfterRoll()
{
   C55_Reset();
   C54_SeedLong8Carry(1.20590, 1.20600);
   Grind_CarryTestSetPosition(7001UL, 1.00, 0.01, D'2026.09.01 12:00');
   const int rc = Adr162b_TryLong(D'2026.09.28 10:00');
   C54_FinishCarryPass();
   AssertContains("LB43 sign guard skipped",
                  Adr162b_ArchiveFind("CARRY_PASS_SUMMARY", 0), "\"skipped\":1");
   AssertTrue("LB43 accrual not committed", MathAbs(Grind_CarryAccruedGet(7001UL)) <= 1e-12);
   AssertNear("LB43 exit at rolled price", Grind_OrderGetPriceOpen(8001UL), 1.20650, 1e-9);
   AssertTrue("LB43 L0 I6", C54_I6Long(0));
   C55_Reset();
}

#endif // FXGRIND_TESTS_C55_MQH
