//+------------------------------------------------------------------+
//| fxgrind_tests_adr166.mqh — ADR-166 roll gate opposite depth (RG*) |
//+------------------------------------------------------------------+
#ifndef FXGRIND_TESTS_ADR166_MQH
#define FXGRIND_TESTS_ADR166_MQH

const datetime ADR166_T0 = D'2026.09.28 10:00';

//+------------------------------------------------------------------+
void Adr166_OneShort()
{
   ArrayResize(g_grind_short.layers, 1);
   g_grind_short.layers[0].entry_price = 1.20800;
   g_grind_short.layers[0].layer_index = 0;
   g_grind_short.layers[0].position_ticket = 7101UL;
   g_grind_short.layers[0].exit_order_ticket = 0;
   g_grind_short.layers[0].exit_position_ticket = 0;
   g_grind_short.layers[0].exit_target =
      Grind_ExitQFormulaTarget(1.20800, 5.0, _Point, false, 7101UL);
}

//+------------------------------------------------------------------+
int Adr166_TryLong(const datetime now, const bool reroll, const int gate, const int opp)
{
   return Grind_LatticeTrySide(g_grind_long, true, 22260101UL, "OPT", 0.01, 5.0, 10.0, 8,
                               true, false, now, 0.0, reroll, gate, opp);
}

//+------------------------------------------------------------------+
int Adr166_TryShort(const datetime now, const bool reroll, const int gate, const int opp)
{
   return Grind_LatticeTrySide(g_grind_short, false, 22260101UL, "OPT", 0.01, 5.0, 10.0, 8,
                               true, false, now, 0.0, reroll, gate, opp);
}

//+------------------------------------------------------------------+
void Adr166_OnTick(const datetime now, const bool reroll, const int gate)
{
   Grind_LatticeOnTick(22260101UL, "OPT", 0.01, true, 5.0, 10.0, 8, false, now,
                       5.0, 10.0, reroll, gate);
}

//+------------------------------------------------------------------+
void Test_RG1_ValidateRollGateInputs()
{
   AssertTrue("RG1a (G)", Grind_ValidateRollGateInputs(true, -1));
   AssertTrue("RG1b (G)", Grind_ValidateRollGateInputs(false, -1));
   AssertTrue("RG1c (G)", Grind_ValidateRollGateInputs(true, 0));
   AssertFalse("RG1d (F)", Grind_ValidateRollGateInputs(false, 0));
   AssertFalse("RG1e (F)", Grind_ValidateRollGateInputs(true, -2));
   Adr162b_Reset();
}

//+------------------------------------------------------------------+
void Test_RG2_RollGateHolds()
{
   AssertFalse("RG2a (G)", Grind_RollGateHolds(-1, 8));
   AssertTrue("RG2b (F)", Grind_RollGateHolds(0, 1));
   AssertFalse("RG2c (G)", Grind_RollGateHolds(0, 0));
   AssertTrue("RG2d (F)", Grind_RollGateHolds(2, 3));
   AssertFalse("RG2e (G)", Grind_RollGateHolds(2, 2));
   Adr162b_Reset();
}

//+------------------------------------------------------------------+
void Test_RG3_FirstRollHeld()
{
   Adr162b_SeedLong8();
   Grind_MarketTestSeed(1.20590, 1.20600, 0, 0);
   AssertEqInt("RG3a (F)", Adr166_TryLong(ADR166_T0, false, 0, 1), 0);
   AssertFalse("RG3b (F)", Grind_VLHas(7001UL));
   AssertTrue("RG3c (F)", g_grind_order_test_modify_calls == 0);
   AssertTrue("RG3d (F)", Adr162b_ArchiveFind("ROLL_DEFERRED", 0) != "");
   AssertTrue("RG3e (G)", Adr162b_ArchiveFind("ROLL_STRANDED", 0) == "");
   AssertTrue("RG3f (F)", Adr162b_ArchiveFind("ROLL_ACCEPTED", 0) == "");
   Adr162b_Reset();
}

//+------------------------------------------------------------------+
void Test_RG4_GateOpenOrOff()
{
   Adr162b_SeedLong8();
   Grind_MarketTestSeed(1.20590, 1.20600, 0, 0);
   AssertEqInt("RG4a (G)", Adr166_TryLong(ADR166_T0, false, 0, 0), 1);
   AssertNear("RG4b (G)", Grind_VLGet(7001UL), 1.20600, 1e-9);
   AssertNear("RG4c (G)", Grind_OrderGetPriceOpen(8001UL), 1.20650, 1e-9);
   AssertTrue("RG4d (G)", Adr162b_ArchiveFind("ROLL_DEFERRED", 0) == "");
   AssertTrue("RG4e (G)", g_grind_order_test_modify_calls == 1);
   const string acc = Adr162b_ArchiveFind("ROLL_ACCEPTED", 0);
   AssertContains("RG4f (G)", acc, "\"auto\"");
   Adr162b_Reset();
   Adr162b_SeedLong8();
   Grind_MarketTestSeed(1.20590, 1.20600, 0, 0);
   AssertEqInt("RG4g (G)", Adr166_TryLong(ADR166_T0, false, -1, 5), 1);
   Adr162b_Reset();
}

//+------------------------------------------------------------------+
void Test_RG5_RerollHeld()
{
   Adr165_Fixture();
   AssertEqInt("RG5a (F)", Adr166_TryLong(ADR166_T0, true, 0, 1), 0);
   AssertNear("RG5b (F)", Grind_VLGet(7001UL), 1.20600, 1e-9);
   AssertTrue("RG5c (F)", Adr162b_ArchiveFind("ROLL_DEFERRED", 0) != "");
   AssertTrue("RG5d (G)", Adr162b_ArchiveFind("ROLL_STRANDED", 0) == "");
   Adr162b_Reset();
}

//+------------------------------------------------------------------+
void Test_RG6_ThresholdN2()
{
   Adr162b_SeedLong8();
   Grind_MarketTestSeed(1.20590, 1.20600, 0, 0);
   AssertEqInt("RG6a (G)", Adr166_TryLong(ADR166_T0, false, 2, 2), 1);
   Adr162b_Reset();
   Adr162b_SeedLong8();
   Grind_MarketTestSeed(1.20590, 1.20600, 0, 0);
   AssertEqInt("RG6b (F)", Adr166_TryLong(ADR166_T0, false, 2, 3), 0);
   Adr162b_Reset();
}

//+------------------------------------------------------------------+
void Test_RG7_ShortMirror()
{
   Adr162b_SeedShort8();
   Grind_MarketTestSeed(1.19400, 1.19410, 0, 0);
   AssertEqInt("RG7a (F)", Adr166_TryShort(ADR166_T0, false, 0, 1), 0);
   AssertFalse("RG7b (F)", Grind_VLHas(7101UL));
   AssertEqInt("RG7c (G)", Adr166_TryShort(ADR166_T0 + 1, false, 0, 0), 1);
   AssertNear("RG7d (G)", Grind_VLGet(7101UL), 1.19400, 1e-9);
   Adr162b_Reset();
}

//+------------------------------------------------------------------+
void Test_RG8_ExtremeRestartsWhileGated()
{
   Adr162b_SeedLong8();
   Grind_MarketTestSeed(1.20590, 1.20600, 0, 0);
   Grind_MarketTestSeedTimeMsc(1790000000000);
   g_grind_vl_extreme_long = 1.20190;
   g_grind_vl_tracking_long = false;
   g_grind_vl_from_msc_long = 1000;
   Grind_LatticeTrySide(g_grind_long, true, 22260101UL, "OPT", 0.01, 5.0, 10.0, 8,
                        true, false, ADR166_T0, 1.20190, false, 0, 1);
   AssertNear("RG8a (F)", g_grind_vl_extreme_long, 0.0, 1e-9);
   AssertTrue("RG8b (F)", g_grind_vl_tracking_long);
   AssertTrue("RG8c (F)", g_grind_vl_from_msc_long == 1790000000001);
   Grind_MarketTestReset();
   Adr162b_Reset();
}

//+------------------------------------------------------------------+
void Test_RG9_MarkerOncePerEpisode()
{
   Adr162b_SeedLong8();
   Grind_MarketTestSeed(1.20590, 1.20600, 0, 0);
   Adr166_TryLong(ADR166_T0, false, 0, 1);
   AssertTrue("RG9a (F)", Adr162b_ArchiveFind("ROLL_DEFERRED", 0) != "");
   Adr166_TryLong(ADR166_T0 + 1, false, 0, 1);
   AssertTrue("RG9b (G)", Adr162b_ArchiveFind("ROLL_DEFERRED", 1) == "");
   AssertEqInt("RG9c (F)", Adr166_TryLong(ADR166_T0 + 2, false, 0, 0), 1);
   Grind_MarketTestSeed(1.20490, 1.20500, 0, 0);
   Adr166_TryLong(ADR166_T0 + 3, false, 0, 1);
   AssertTrue("RG9d (F)", Adr162b_ArchiveFind("ROLL_DEFERRED", 1) != "");
   const string def0 = Adr162b_ArchiveFind("ROLL_DEFERRED", 0);
   AssertTrue("RG9e (F)",
              StringFind(def0, "\"opposite_depth\":1") >= 0 &&
              StringFind(def0, "\"gate\":0") >= 0);
   Adr162b_Reset();
}

//+------------------------------------------------------------------+
void Test_RG10_NoMarkerWhenNoRollDue()
{
   Adr162b_SeedLong8();
   Grind_MarketTestSeed(1.20690, 1.20700, 0, 0);
   AssertEqInt("RG10a (G)", Adr166_TryLong(ADR166_T0, false, 0, 1), 0);
   AssertTrue("RG10b (G)", Adr162b_ArchiveFind("ROLL_DEFERRED", 0) == "");
   Adr162b_Reset();
}

//+------------------------------------------------------------------+
void Test_RG11_GatedSideNotStranded()
{
   Adr165_Fixture();
   Adr166_TryLong(ADR166_T0, false, 0, 1);
   AssertTrue("RG11a (F)", Adr162b_ArchiveFind("ROLL_STRANDED", 0) == "");
   AssertFalse("RG11b (F)", g_grind_vl_stranded_warned_long);
   Adr162b_Reset();
}

//+------------------------------------------------------------------+
void Test_RG12_OnTickPassesOppositeDepth()
{
   Adr165_Fixture();
   Adr166_OneShort();
   Adr166_OnTick(ADR166_T0, true, 0);
   AssertNear("RG12a (F)", Grind_VLGet(7001UL), 1.20600, 1e-9);
   Adr166_OnTick(ADR166_T0 + 1, true, -1);
   AssertNear("RG12b (G)", Grind_VLGet(7001UL), 1.19800, 1e-9);
   Adr162b_Reset();
   Adr162b_SeedShort8();
   Adr151_TestSetupLongLayer(g_grind_long, 0, 0, 1.18000, 7001UL, 0, 5.0);
   Grind_MarketTestSeed(1.19400, 1.19410, 0, 0);
   Adr166_OnTick(ADR166_T0, false, 0);
   AssertFalse("RG12c (F)", Grind_VLHas(7101UL));
   Adr162b_Reset();
}

//+------------------------------------------------------------------+
void Test_RG13_DipNotReplayedAtRelease()
{
   C55_Reset();
   Adr162b_SeedLong8();
   C55_OpenTimes(true, D'2026.09.28 09:00');
   Adr166_OneShort();
   Grind_MarketTestSeed(1.20690, 1.20700, 0, 0);
   Grind_LatticeTestAddTick(D'2026.09.28 09:30', 1.20580, 1.20590);
   Grind_MarketTestSeedTimeMsc((long)D'2026.09.28 10:00' * 1000);
   Adr166_OnTick(D'2026.09.28 10:00', false, 0);
   AssertFalse("RG13a (F)", Grind_VLHas(7001UL));
   ArrayResize(g_grind_short.layers, 0);
   Grind_MarketTestSeedTimeMsc((long)D'2026.09.28 10:01' * 1000);
   Adr166_OnTick(D'2026.09.28 10:01', false, 0);
   AssertFalse("RG13b (F)", Grind_VLHas(7001UL));
   Grind_MarketTestSeed(1.20590, 1.20600, 0, 0);
   Grind_MarketTestSeedTimeMsc((long)D'2026.09.28 10:02' * 1000);
   Adr166_OnTick(D'2026.09.28 10:02', false, 0);
   AssertNear("RG13c (G)", Grind_VLGet(7001UL), 1.20600, 1e-9);
   Grind_MarketTestReset();
   C55_Reset();
}

//+------------------------------------------------------------------+
void Test_RG14_GatedPathLeavesClosingAndBackoff()
{
   Adr162b_SeedLong8();
   Grind_MarketTestSeed(1.20590, 1.20600, 0, 0);
   g_grind_vl_closing_ticket_long = 7001UL;
   g_grind_vl_closing_since_long = ADR166_T0 - 30;
   g_grind_vl_closing_warned_long = false;
   g_grind_vl_fail_count_long = 2;
   Adr166_TryLong(ADR166_T0, false, 0, 1);
   AssertTrue("RG14a (F)", g_grind_vl_closing_ticket_long == 7001UL);
   AssertTrue("RG14b (F)", g_grind_vl_closing_since_long == ADR166_T0 - 30);
   AssertEqInt("RG14c (F)", g_grind_vl_fail_count_long, 2);
   AssertTrue("RG14d (G)", Adr162b_ArchiveFind("ROLL_CLOSING_STUCK", 0) == "");
   Adr162b_Reset();
}

#endif
