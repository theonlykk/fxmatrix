This message has a line count at the bottom

# CARRY-PROBE: replace after cancel measurement

Branch: research/carry-replace-probe (cut from origin/main)
Scope: one new test only. No production file changed.

## Test in full

    void Test_CARRY_PROBE_replace_after_cancel()
    {
       Grind_OrderTestReset();
       Grind_TestResetSideState();
       Grind_CarryTestReset();
       g_grind_order_test_active = true;
       Adr151_TestSeedSlotSeams(200, 100, 0);

       const ulong pos = 92001UL;
       Grind_CarryShiftDelete(pos);
       GlobalVariableDel(Grind_CarryReleaseGvName(pos));

       const double entry = 1.25000;
       const double exit_pips = 3.0;
       const double point = 0.00001;
       const double raw_formula = Grind_ExitPrice(entry, exit_pips, point, 1);
       const double carry_shift = 0.00020;
       const double carry_target = raw_formula + carry_shift;

       Grind_MarketTestSeed(1.25000, 1.25020, 0, 0);
       const double min_dist = Grind_CarryMinPassiveDistance(point, 0, 0);
       AssertTrue("CARRY-PROBE precnd", raw_formula > 1.25020 + min_dist - 1e-12);

       ArrayResize(g_grind_long.layers, 1);
       Adr151_TestSetupLongLayer(g_grind_long, 0, 0, entry, pos, 0);

       Grind_ExitQManageSide(g_grind_long, true, 22260101UL, "OPT", 0.01, exit_pips);

       Grind_CarryShiftSet(pos, carry_shift);
       GlobalVariableSet(Grind_CarryReleaseGvName(pos), 1.0);
       g_grind_long.layers[0].exit_target = carry_target;

       g_grind_long.layers[0].exit_order_ticket = 0;
       g_grind_long.layers[0].exit_position_ticket = 0;

       Grind_ExitQManageSide(g_grind_long, true, 22260101UL, "OPT", 0.01, exit_pips);

       AssertTrue("CARRY-PROBE two places", g_grind_order_test_place_calls == 2);

       Print("CARRY-PROBE re_placed=", g_grind_order_test_last_placed_price,
             " raw_formula=", raw_formula,
             " carry_target=", carry_target,
             " gv_before_replace=", carry_shift,
             " gv_after_replace=", Grind_CarryShiftGet(pos),
             " relexists=", GlobalVariableCheck(Grind_CarryReleaseGvName(pos)),
             " exit_target=", g_grind_long.layers[0].exit_target);

       GrindReconLayerScratch layers[1];
       Grind_TestInitLayerScratch(layers[0], 0, entry, pos);
       layers[0].has_exit_order = (g_grind_long.layers[0].exit_order_ticket != 0);
       layers[0].exit_order_ticket = g_grind_long.layers[0].exit_order_ticket;
       layers[0].exit_target = g_grind_long.layers[0].exit_target;
       int long_ranks[1];
       long_ranks[0] = 0;
       GrindReconLayerScratch empty[];
       int short_ranks[];
       string reason = "";
       const bool ok = Grind_ReconCheckInvariants(layers, 1, long_ranks, empty, 0, short_ranks,
                                                  exit_pips, point, 12, reason);
       Print("CARRY-PROBE I6 ok=", ok, " reason=", reason);

       Grind_CarryShiftDelete(pos);
       GlobalVariableDel(Grind_CarryReleaseGvName(pos));
       Grind_MarketTestReset();
       Grind_OrderTestReset();
       Grind_TestResetSideState();
       Grind_CarryTestReset();
       Adr151_TestResetAll();
    }

Hand values: raw_formula = 1.25030 (1.25000 + 3 pips * 0.00001 * 10).
carry_target = 1.25050. Market bid/ask = 1.25000/1.25020; min_dist = 0.00001;
precnd: 1.25030 > 1.25021.

Grind_ReconCheckInvariants signature (from fxgrind_tests_adr151.mqh):

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

Test builds GrindReconLayerScratch from g_grind_long post-replace state; it
does not pass g_grind_long.layers directly.

## git diff --stat origin/main...research/carry-replace-probe

 ea/fxgrind_tests.mq5           |   1 +
 ea/fxgrind_tests_adr151.mqh    |  71 ++++++++++++++++++++++++
 prompts/carry_replace_probe.md | 119 ++++++++++++++++++++++++++++++++++++++++
 3 files changed, 191 insertions(+)

Deleted assertions / tests grep (must be empty):

    git diff origin/main -- ea/fxgrind_tests.mq5 ea/fxgrind_tests_adr151.mqh | grep "^-" | grep -i "Assert\|void Test_"

Result: empty (no deleted Assert or Test_ lines).

No production file changed. grind_engine.mqh, grind_exitq.mqh,
grind_carry.mqh, grind_recon.mqh untouched.

Operator must compile and run. Read CARRY-PROBE re_placed and CARRY-PROBE I6
lines from the log. No result claimed here.

Line count: 119
