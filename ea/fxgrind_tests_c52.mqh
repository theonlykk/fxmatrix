//+------------------------------------------------------------------+
//| fxgrind_tests_c52.mqh — backlog C52 carry pass exit-ticket race  |
//+------------------------------------------------------------------+
#ifndef FXGRIND_TESTS_C52_MQH
#define FXGRIND_TESTS_C52_MQH

//+------------------------------------------------------------------+
void C52_TestTeardown(const ulong magic, const ulong pos)
{
   F2_TestClearPositionCarry(pos);
   Grind_CarryTestReset();
   Grind_ArchiveTestReset();
   Grind_OrderTestReset();
   Grind_TestResetSideState();
   Grind_CarryGateReset(magic);
   Adr151_TestResetAll();
}

//+------------------------------------------------------------------+
void Test_CR1_ReleasedMidPass()
{
   const ulong magic = 99993201UL;
   const ulong pos = 99301UL;
   const ulong exit_ticket = 99311UL;
   const double entry = 1.25000;
   const double exit_pips = 3.0;
   const double point = 0.00001;
   const double formula = 1.25030;

   Grind_CarryTestReset();
   Grind_ArchiveTestReset();
   Grind_OrderTestReset();
   Grind_TestResetSideState();
   F2_TestClearPositionCarry(pos);
   F2_TestSeedCarryWindow(magic);
   g_grind_order_test_active = true;
   Grind_CarryTestSetPosition(pos, -0.10, 0.01, D'2026.09.01 12:00');
   Grind_PositionTestAdd(pos);
   Adr151_TestSetupLongLayer(g_grind_long, 0, 0, entry, pos, 0, exit_pips);
   g_grind_carry_eligible_magic = magic;
   Grind_CarryExitPassBegin(_Symbol, magic, exit_pips);

   g_grind_long.layers[0].exit_order_ticket = exit_ticket;
   Grind_OrderTestUpsert(exit_ticket, (long)magic, GrindCommentBuild("OPT", "L", 0, "EXT"),
                         formula, (long)ORDER_TYPE_SELL_LIMIT);

   Grind_CarryExitPassStep(_Symbol, magic, exit_pips, g_grind_carry_test_server_time);

   AssertTrue("CR1 accrued", MathAbs(Grind_CarryAccruedGet(pos)) > 1e-12);
   AssertTrue("CR1 accrued beyond I6 tolerance",
              MathAbs(Grind_CarryAccruedGet(pos)) > 2.0 * point);
   const double order_price = Grind_OrderGetPriceOpen(exit_ticket);
   AssertTrue("CR1 exit moved", MathAbs(order_price - formula) > 1e-9);
   AssertTrue("CR1 I6 holds",
              Grind_ReconExitMatchesEntry(entry, order_price, exit_pips, point, true,
                                          Grind_CarryShiftGet(pos), false, pos));
   C52_TestTeardown(magic, pos);
}

//+------------------------------------------------------------------+
void Test_CR2_DemotedMidPass()
{
   const ulong magic = 99993202UL;
   const ulong pos = 99302UL;
   const ulong exit_ticket = 99312UL;
   const double entry = 1.25000;
   const double exit_pips = 3.0;
   const double formula = 1.25030;

   Grind_CarryTestReset();
   Grind_ArchiveTestReset();
   Grind_OrderTestReset();
   Grind_TestResetSideState();
   F2_TestClearPositionCarry(pos);
   F2_TestSeedCarryWindow(magic);
   g_grind_order_test_active = true;
   Grind_CarryTestSetPosition(pos, -0.10, 0.01, D'2026.09.01 12:00');
   Grind_PositionTestAdd(pos);
   Adr151_TestSetupLongLayer(g_grind_long, 0, 0, entry, pos, exit_ticket, exit_pips);
   Grind_OrderTestUpsert(exit_ticket, (long)magic, GrindCommentBuild("OPT", "L", 0, "EXT"),
                         formula, (long)ORDER_TYPE_SELL_LIMIT);
   g_grind_carry_eligible_magic = magic;
   Grind_CarryExitPassBegin(_Symbol, magic, exit_pips);

   Grind_ExitQHoldCancelLayer(g_grind_long.layers[0], true, magic);
   GrindOrderTestRecord rec;
   AssertTrue("CR2 cancelled",
              g_grind_long.layers[0].exit_order_ticket == 0 && !Grind_OrderTestFind(exit_ticket, rec));

   Grind_CarryExitPassStep(_Symbol, magic, exit_pips, g_grind_carry_test_server_time);

   AssertTrue("CR2 accrual committed", MathAbs(Grind_CarryAccruedGet(pos)) > 1e-12);
   C52_TestTeardown(magic, pos);
}

//+------------------------------------------------------------------+
void Test_CR3_ClosingMidPass()
{
   const ulong magic = 99993203UL;
   const ulong pos = 99303UL;
   const ulong exit_ticket = 99313UL;
   const ulong exit_pos = 99323UL;
   const double entry = 1.25000;
   const double exit_pips = 3.0;
   const double formula = 1.25030;

   Grind_CarryTestReset();
   Grind_ArchiveTestReset();
   Grind_OrderTestReset();
   Grind_TestResetSideState();
   F2_TestClearPositionCarry(pos);
   F2_TestSeedCarryWindow(magic);
   g_grind_order_test_active = true;
   Grind_CarryTestSetPosition(pos, -0.10, 0.01, D'2026.09.01 12:00');
   Grind_PositionTestAdd(pos);
   Adr151_TestSetupLongLayer(g_grind_long, 0, 0, entry, pos, exit_ticket, exit_pips);
   Grind_OrderTestUpsert(exit_ticket, (long)magic, GrindCommentBuild("OPT", "L", 0, "EXT"),
                         formula, (long)ORDER_TYPE_SELL_LIMIT);
   g_grind_carry_eligible_magic = magic;
   Grind_CarryExitPassBegin(_Symbol, magic, exit_pips);

   Grind_OrderTestRemove(exit_ticket);
   g_grind_long.layers[0].exit_order_ticket = 0;
   g_grind_long.layers[0].exit_position_ticket = exit_pos;

   Grind_CarryExitPassStep(_Symbol, magic, exit_pips, g_grind_carry_test_server_time);

   AssertTrue("CR3 closing not shifted", MathAbs(Grind_CarryAccruedGet(pos)) <= 1e-12);
   C52_TestTeardown(magic, pos);
}

#endif // FXGRIND_TESTS_C52_MQH
