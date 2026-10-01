//+------------------------------------------------------------------+
//| fxgrind_tests_adr165.mqh -- ADR-165 continuous re-roll (RR*)     |
//+------------------------------------------------------------------+
#ifndef FXGRIND_TESTS_ADR165_MQH
#define FXGRIND_TESTS_ADR165_MQH

const datetime ADR165_T0 = D'2026.09.28 10:00';

//+------------------------------------------------------------------+
void Adr165_Fixture()
{
   Adr162b_SeedLong8();
   for(int i = 0; i < 8; i++)
      Grind_VLSet(7001UL + (ulong)i, NormalizeDouble(1.20600 - 0.00100 * i, 5));
   Adr162b_RefreshExit(g_grind_long, true, 0, 8001UL);
   Adr162b_RefreshExit(g_grind_long, true, 7, 8008UL);
   Grind_MarketTestSeed(1.19000, 1.19010, 0, 0);
}

//+------------------------------------------------------------------+
int Adr165_TryLong(const datetime now, const bool reroll)
{
   return Grind_LatticeTrySide(g_grind_long, true, 22260101UL, "OPT", 0.01, 5.0, 10.0, 8,
                               true, false, now, 0.0, reroll);
}

//+------------------------------------------------------------------+
int Adr165_TryShort(const datetime now, const bool reroll)
{
   return Grind_LatticeTrySide(g_grind_short, false, 22260101UL, "OPT", 0.01, 5.0, 10.0, 8,
                               true, false, now, 0.0, reroll);
}

//+------------------------------------------------------------------+
void Test_RR1_ValidateRerollInputs()
{
   AssertTrue("RR1a (G)", Grind_ValidateRerollInputs(true, true));
   AssertFalse("RR1b (F)", Grind_ValidateRerollInputs(false, true));
   AssertTrue("RR1c (G)", Grind_ValidateRerollInputs(true, false));
   AssertTrue("RR1d (G)", Grind_ValidateRerollInputs(false, false));
   Adr162b_Reset();
}

//+------------------------------------------------------------------+
void Test_RR2_RerollIndex()
{
   Adr162b_SeedLong8();
   AssertEqInt("RR2a (G)", Grind_LatticeRerollIndex(g_grind_long, true), -1);
   Adr165_Fixture();
   AssertEqInt("RR2b (F)", Grind_LatticeRerollIndex(g_grind_long, true), 0);
   Grind_VLSet(7002UL, 1.20600);
   AssertEqInt("RR2c (F)", Grind_LatticeRerollIndex(g_grind_long, true), 0);
   Adr162b_SeedShort8();
   for(int i = 0; i < 8; i++)
      Grind_VLSet(7101UL + (ulong)i, NormalizeDouble(1.19400 + 0.00100 * i, 5));
   AssertEqInt("RR2d (F)", Grind_LatticeRerollIndex(g_grind_short, false), 0);
   Adr162b_Reset();
}

//+------------------------------------------------------------------+
void Test_RR3_RerollPaused()
{
   AssertFalse("RR3a (G)", Grind_LatticeRerollPaused(D'2026.09.28 23:49:59'));
   AssertTrue("RR3b (F)", Grind_LatticeRerollPaused(D'2026.09.28 23:50:00'));
   AssertTrue("RR3c (F)", Grind_LatticeRerollPaused(D'2026.09.29 00:00:00'));
   AssertTrue("RR3d (F)", Grind_LatticeRerollPaused(D'2026.09.29 00:14:59'));
   AssertFalse("RR3e (G)", Grind_LatticeRerollPaused(D'2026.09.29 00:15:00'));
   AssertFalse("RR3f (G)", Grind_LatticeRerollPaused(ADR165_T0));
   Adr162b_Reset();
}

//+------------------------------------------------------------------+
void Test_RR4_SingleRerollLong()
{
   Adr165_Fixture();
   AssertEqInt("RR4a (F)", Adr165_TryLong(ADR165_T0, true), 1);
   AssertNear("RR4b (F)", Grind_VLGet(7001UL), 1.19800, 1e-9);
   AssertNear("RR4c (F)", Grind_OrderGetPriceOpen(8001UL), 1.19850, 1e-9);
   AssertNear("RR4d (F)", g_grind_long.layers[0].exit_target, 1.19850, 1e-9);
   AssertTrue("RR4e (F)",
              Grind_ReconExitMatchesEntry(1.21400, 1.19850, 5.0, _Point, true, 0.0, false, 7001UL));
   AssertNear("RR4f (G)", Grind_VLGet(7002UL), 1.20500, 1e-9);
   AssertTrue("RR4g (F)", g_grind_long.layers[7].exit_order_ticket == 0);
   AssertTrue("RR4h (F)", g_grind_long.layers[1].exit_order_ticket != 0);
   AssertTrue("RR4i (F)",
              g_grind_order_test_modify_calls == 1 &&
              g_grind_order_test_remove_calls == 1 &&
              g_grind_order_test_place_calls == 1);
   const string acc0 = Adr162b_ArchiveFind("ROLL_ACCEPTED", 0);
   AssertContains("RR4j (F)", acc0, "\"reroll\":true");
   AssertContains("RR4k (F)", acc0, "\"from_level\":1.20600");
   AssertContains("RR4l (F)", acc0, "\"source\":\"reroll\"");
   AssertTrue("RR4m (F)", Adr162b_ArchiveFind("ROLL_STRANDED", 0) == "");
   Adr162b_Reset();
}

//+------------------------------------------------------------------+
void Test_RR5_InputOff()
{
   Adr165_Fixture();
   AssertEqInt("RR5a (G)", Adr165_TryLong(ADR165_T0, false), 0);
   AssertTrue("RR5b (G)", g_grind_order_test_modify_calls == 0);
   AssertNear("RR5c (G)", Grind_VLGet(7001UL), 1.20600, 1e-9);
   AssertTrue("RR5d (G)", Adr162b_ArchiveFind("ROLL_STRANDED", 0) != "");
   Adr162b_Reset();
}

//+------------------------------------------------------------------+
void Test_RR6_ThrottleOnePerCall()
{
   Adr165_Fixture();
   AssertEqInt("RR6a (F)", Adr165_TryLong(ADR165_T0, true), 1);
   AssertNear("RR6b (G)", Grind_VLGet(7002UL), 1.20500, 1e-9);
   AssertEqInt("RR6c (F)", Adr165_TryLong(ADR165_T0 + 1, true), 1);
   AssertNear("RR6d (F)", Grind_VLGet(7002UL), 1.19700, 1e-9);
   AssertEqInt("RR6e (F)", Adr165_TryLong(ADR165_T0 + 2, true), 1);
   AssertNear("RR6f (F)", Grind_VLGet(7003UL), 1.19600, 1e-9);
   AssertTrue("RR6g (F)", g_grind_order_test_modify_calls == 3);
   AssertTrue("RR6h (F)", Adr162b_ArchiveFind("ROLL_STRANDED", 0) == "");
   Adr162b_Reset();
}

//+------------------------------------------------------------------+
void Test_RR7_Pause()
{
   Adr165_Fixture();
   AssertEqInt("RR7a (G)", Adr165_TryLong(D'2026.09.28 23:55', true), 0);
   AssertNear("RR7b (G)", Grind_VLGet(7001UL), 1.20600, 1e-9);
   AssertTrue("RR7c (G)", Adr162b_ArchiveFind("ROLL_STRANDED", 0) != "");
   Adr162b_Reset();
   Adr165_Fixture();
   AssertEqInt("RR7d (F)", Adr165_TryLong(D'2026.09.29 00:16', true), 1);
   Adr162b_Reset();
}

//+------------------------------------------------------------------+
void Test_RR8_Short()
{
   Adr162b_SeedShort8();
   for(int i = 0; i < 8; i++)
      Grind_VLSet(7101UL + (ulong)i, NormalizeDouble(1.19400 + 0.00100 * i, 5));
   Adr162b_RefreshExit(g_grind_short, false, 0, 8101UL);
   Adr162b_RefreshExit(g_grind_short, false, 7, 8108UL);
   Grind_MarketTestSeed(1.21000, 1.21010, 0, 0);
   AssertEqInt("RR8a (F)", Adr165_TryShort(ADR165_T0, true), 1);
   AssertNear("RR8b (F)", Grind_VLGet(7101UL), 1.20200, 1e-9);
   AssertNear("RR8c (F)", Grind_OrderGetPriceOpen(8101UL), 1.20150, 1e-9);
   AssertNear("RR8d (G)", Grind_VLGet(7102UL), 1.19500, 1e-9);
   Adr162b_Reset();
}

//+------------------------------------------------------------------+
void Test_RR9_AccrualKeptShiftNotCompounded()
{
   Adr165_Fixture();
   Grind_CarryAccruedSet(7001UL, 0.00010);
   Grind_CarryShiftSet(7001UL, 0.00003);
   Adr162b_RefreshExit(g_grind_long, true, 0, 8001UL);
   Adr165_TryLong(ADR165_T0, true);
   AssertNear("RR9a (F)", Grind_OrderGetPriceOpen(8001UL), 1.19860, 1e-9);
   AssertNear("RR9b (G)", Grind_CarryAccruedGet(7001UL), 0.00010, 1e-9);
   AssertFalse("RR9c (F)", GlobalVariableCheck(Grind_CarryShiftGvName(7001UL)));
   Adr162b_Reset();
}

//+------------------------------------------------------------------+
void Test_RR10_ModifyFails()
{
   Adr165_Fixture();
   g_grind_order_test_send_ok = false;
   AssertEqInt("RR10a (G)", Adr165_TryLong(ADR165_T0, true), 0);
   AssertTrue("RR10b (F)", g_grind_order_test_modify_calls == 1);
   AssertNear("RR10c (G)", Grind_VLGet(7001UL), 1.20600, 1e-9);
   AssertContains("RR10d (F)", Adr162b_ArchiveFind("ROLL_REFUSED", 0), "MODIFY_FAILED");
   AssertNear("RR10e (G)", Grind_OrderGetPriceOpen(8001UL), 1.20650, 1e-9);
   g_grind_order_test_send_ok = true;
   Adr162b_Reset();
}

//+------------------------------------------------------------------+
void Test_RR11_ClosingCandidateStops()
{
   Adr165_Fixture();
   g_grind_long.layers[0].exit_order_ticket = 0;
   g_grind_long.layers[0].exit_position_ticket = 9999UL;
   AssertEqInt("RR11a (G)", Adr165_TryLong(ADR165_T0, true), 0);
   AssertTrue("RR11b (G)",
              MathAbs(Grind_VLGet(7001UL) - 1.20600) <= 1e-9 &&
              MathAbs(Grind_VLGet(7002UL) - 1.20500) <= 1e-9);
   AssertTrue("RR11c (G)", g_grind_order_test_modify_calls == 0);
   AssertTrue("RR11d (F)", Adr162b_ArchiveFind("ROLL_STRANDED", 0) == "");
   AssertEqInt("RR11e (F)", (int)g_grind_vl_closing_ticket_long, 7001);
   Adr162b_Reset();
}

//+------------------------------------------------------------------+
void Test_RR12_OnTickWiring()
{
   Adr165_Fixture();
   Grind_LatticeOnTick(22260101UL, "OPT", 0.01, true, 5.0, 10.0, 8, false, ADR165_T0,
                       5.0, 10.0, false);
   AssertNear("RR12a (G)", Grind_VLGet(7001UL), 1.20600, 1e-9);
   Grind_LatticeOnTick(22260101UL, "OPT", 0.01, true, 5.0, 10.0, 8, false, ADR165_T0,
                       5.0, 10.0, true);
   AssertNear("RR12b (F)", Grind_VLGet(7001UL), 1.19800, 1e-9);
   Adr162b_Reset();
}

//+------------------------------------------------------------------+
void Test_RR13_FirstRollsThenOneReroll()
{
   Adr162b_SeedLong8();
   for(int i = 0; i < 6; i++)
      Grind_VLSet(7001UL + (ulong)i, NormalizeDouble(1.20600 - 0.00100 * i, 5));
   Adr151_TestSetupLongLayer(g_grind_long, 6, 8, 1.20000, 7009UL, 0, 5.0);
   Adr151_TestSetupLongLayer(g_grind_long, 7, 9, 1.19900, 7010UL, 0, 5.0);
   Adr162b_RefreshExit(g_grind_long, true, 0, 8001UL);
   Adr162b_RefreshExit(g_grind_long, true, 7, 8010UL);
   Grind_MarketTestSeed(1.19000, 1.19010, 0, 0);
   AssertEqInt("RR13a (F)", Adr165_TryLong(ADR165_T0, true), 3);
   AssertNear("RR13b (G)", Grind_VLGet(7009UL), 1.19800, 1e-9);
   AssertNear("RR13c (G)", Grind_VLGet(7010UL), 1.19700, 1e-9);
   AssertNear("RR13d (F)", Grind_VLGet(7001UL), 1.19600, 1e-9);
   Adr162b_Reset();
}

//+------------------------------------------------------------------+
void Test_RR14_RerollIndexSkipsEjected()
{
   Adr165_Fixture();
   Grind_EjectOffsetSet(7001UL, -0.00300);
   AssertEqInt("RR14a (F)", Grind_LatticeRerollIndex(g_grind_long, true), 1);
   for(int i = 1; i < 8; i++)
      Grind_EjectOffsetSet(7001UL + (ulong)i, -0.00300);
   AssertEqInt("RR14b (F)", Grind_LatticeRerollIndex(g_grind_long, true), -1);
   Adr162b_Reset();
   Adr165_Fixture();
   Grind_EjectOffsetSet(7008UL, -0.00300);
   AssertEqInt("RR14c (G)", Grind_LatticeRerollIndex(g_grind_long, true), 0);
   Adr162b_Reset();
}

//+------------------------------------------------------------------+
void Test_RR15_EjectedCandidateKept()
{
   Adr165_Fixture();
   Grind_EjectOffsetSet(7001UL, -0.00300);
   AssertEqInt("RR15a (G)", Adr165_TryLong(ADR165_T0, true), 1);
   AssertNear("RR15b (F)", Grind_VLGet(7001UL), 1.20600, 1e-9);
   AssertNear("RR15c (F)", Grind_VLGet(7002UL), 1.19800, 1e-9);
   AssertTrue("RR15d (F)", Grind_EjectIsEjected(7001UL));
   AssertContains("RR15e (F)", Adr162b_ArchiveFind("ROLL_ACCEPTED", 0), "\"ticket\":7002");
   AssertTrue("RR15f (G)", Adr162b_ArchiveFind("ROLL_STRANDED", 0) == "");
   Adr162b_Reset();
}

//+------------------------------------------------------------------+
void Test_RR16_LatchClearedThenRearmed()
{
   Adr165_Fixture();
   g_grind_vl_stranded_warned_long = true;
   AssertEqInt("RR16a (G)", Adr165_TryLong(ADR165_T0, true), 1);
   AssertFalse("RR16b (G)", g_grind_vl_stranded_warned_long);
   AssertEqInt("RR16c (G)", Adr165_TryLong(D'2026.09.28 23:55', true), 0);
   AssertTrue("RR16d (G)", Adr162b_ArchiveFind("ROLL_STRANDED", 0) != "");
   Adr162b_Reset();
}

#endif // FXGRIND_TESTS_ADR165_MQH
