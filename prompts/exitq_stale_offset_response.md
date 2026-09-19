This message has a line count at the bottom

# FIX: exit queue stale offset

Branch: fix/exitq-stale-offset (two commits from origin/main)

Commits:
1. 5c38224 -- STALE-1 through STALE-5 tests (must fail on unfixed code)
2. 9996c9b -- Clear offset on cancel and unclamped placement

## Grind_ExitQHoldCancelLayer (grind_engine.mqh)

    bool Grind_ExitQHoldCancelLayer(GrindLayer &layer,
                                    const bool is_long,
                                    const ulong magic)
    {
       if(layer.exit_order_ticket == 0)
          return true;

       const ulong ticket = layer.exit_order_ticket;
       if(Grind_CancelPendingOrder(ticket, magic)) {
          layer.exit_order_ticket = 0;
          Grind_CarryShiftDelete(layer.position_ticket);
          return true;
       }
       if(Grind_SelectOurOrder(ticket, magic))
          return false;

       ulong pos_out = 0;
       if(Grind_ExitQFindExitDealPosition(ticket, is_long, magic, pos_out) &&
          Grind_SelectOurPosition(pos_out, magic)) {
          layer.exit_position_ticket = pos_out;
          layer.exit_order_ticket = 0;
          if(is_long)
             Grind_QueueCloseBy(g_grind_long_closeby_queue, layer.position_ticket, pos_out);
          else
             Grind_QueueCloseBy(g_grind_short_closeby_queue, layer.position_ticket, pos_out);
       } else {
          layer.exit_order_ticket = 0;
          Grind_CarryShiftDelete(layer.position_ticket);
       }
       return true;
    }

## Placement loop tail (grind_engine.mqh)

      side.layers[i].exit_order_ticket = ticket;
      side.layers[i].exit_target = price;
      if(clamped || MathAbs(price - formula) > _Point * 0.5) {
         Grind_CarryShiftSet(side.layers[i].position_ticket, price - formula);
         GlobalVariableSet(Grind_CarryReleaseGvName(side.layers[i].position_ticket), 1.0);
      } else {
         Grind_CarryShiftDelete(side.layers[i].position_ticket);
      }

## Branches that clear the offset

1. **Successful cancel** (`Grind_CancelPendingOrder` returns true): order
   cancelled, ticket zeroed, offset deleted. Rank demotion uses this path.
2. **Abandoned order** (else branch): order gone without a fill deal,
   ticket zeroed, offset deleted. HC4-style path.

**Filled-exit branch excluded:** when `Grind_ExitQFindExitDealPosition` finds
a position and sets `exit_position_ticket`, no delete. Scalp close at
grind_engine.mqh:1413 owns clearing. STALE-5 asserts offset survives this path.

## Tests vs unfixed code (expected failures)

STALE-1:
- STALE-1 offset cleared -- FAIL (GV still present after demote trim)
- STALE-1 replace no offset -- FAIL (hand-seeded offset path via stale GV)
- STALE-1 i6 -- FAIL (I6_LONG_EXIT if replace places raw with stale GV)

STALE-2:
- STALE-2 offset gone -- FAIL (cancel does not delete GV)

STALE-3:
- STALE-3 offset cleared -- FAIL (unclamped place leaves hand-seeded GV)

STALE-4: PASS on unfixed (existing clamped write behaviour).

STALE-5: PASS on unfixed (filled branch never cleared offset).

Hand values: point=0.00001, 3 pips -> raw 1.25030. Clamped market ask 1.25100
-> placed 1.25101, shift 0.00071. Quiet market ask 1.25020 -> no clamp.

## git diff --stat origin/main...fix/exitq-stale-offset

 ea/fxgrind_tests.mq5        |   5 +
 ea/fxgrind_tests_adr151.mqh | 269 ++++++++++++++++++++++++++++++++++++++++++++
 ea/grind_engine.mqh         |   4 +
 3 files changed, 278 insertions(+)

Deleted assertions grep (must be empty):

    git diff origin/main -- ea/fxgrind_tests.mq5 ea/fxgrind_tests_adr151.mqh | grep "^-" | grep -i "Assert\|void Test_"

Result: empty.

No change to Grind_ExitQFormulaTarget, grind_carry.mqh, grind_recon.mqh,
grind_exitq.mqh, presets, or ADR. Test_CARRY_PROBE_replace_after_cancel
unchanged; printed values should show gv_after_replace=0.0 and I6 ok=true
after fix.

Operator expected suite: 1258/1258 (1253 baseline + 5 STALE tests). MQ5
shift/release gv unchanged. CARRY-PROBE should pass with cleared offset.

Line count: 108

## DIAGNOSTIC: STALE-1 ranks

One Print inserted after the second Grind_ExitQManageSide, before
STALE-1 demoted bare:

   Grind_ExitQManageSide(g_grind_long, true, 22260101UL, "OPT", 0.01, exit_pips);

   const int stale1_n = ArraySize(g_grind_long.layers);
   double stale1_entries[];
   int stale1_layer_indices[];
   ArrayResize(stale1_entries, stale1_n);
   ArrayResize(stale1_layer_indices, stale1_n);
   for(int i = 0; i < stale1_n; i++) {
      stale1_entries[i] = g_grind_long.layers[i].entry_price;
      stale1_layer_indices[i] = g_grind_long.layers[i].layer_index;
   }
   int stale1_ranks[];
   Grind_ExitQRanks(stale1_entries, stale1_layer_indices, stale1_n, true, stale1_ranks);
   Print("STALE-1 DIAG rank0=", stale1_ranks[0], " rank1=", stale1_ranks[1],
         " l0_ticket=", g_grind_long.layers[0].exit_order_ticket,
         " l1_ticket=", g_grind_long.layers[1].exit_order_ticket,
         " places=", g_grind_order_test_place_calls,
         " l0_target=", g_grind_long.layers[0].exit_target,
         " l1_target=", g_grind_long.layers[1].exit_target,
         " bid=", Grind_MarketBid(), " ask=", Grind_MarketAsk());

   AssertTrue("STALE-1 demoted bare", ...);

Ranking helper: Grind_ExitQRanks (grind_exitq.mqh), included via
grind_exitq.mqh in fxgrind_tests_adr151.mqh:

    void Grind_ExitQRanks(const double &entries[],
                          const int &layer_indices[],
                          const int n,
                          const bool is_long,
                          int &ranks_out[]);

No production file changed. No assertion changed or moved.

git diff --stat origin/main...fix/exitq-stale-offset:

 ea/fxgrind_tests.mq5                   |   5 +
 ea/fxgrind_tests_adr151.mqh            | 288 +++++++++++++++++++++++++++++++++
 ea/grind_engine.mqh                    |   4 +
 prompts/exitq_stale_offset_response.md | 159 ++++++++++++++++++
 4 files changed, 456 insertions(+)

Operator must run suite and read STALE-1 DIAG line. No cause proposed.

## FIX: STALE-1 second layer

Root cause confirmed by operator diagnostic at 6bac4af: rank0=0 with layer 1 at
1.25100 above layer 0 at 1.25000. Long ExitQRanks sorts entry ASC; the deeper
layer never demoted layer 0. Test construction error, not production fix.

### Change summary

1. Layer 1 entry moved from 1.25100 to 1.24900 (10 pips below layer 0).
2. All offset assertions scoped to pos_far (93001) or pos_near (93002) by ticket.
3. pos_near offset asserted to survive after pos_far clear and after removal.
4. Grind_RemoveLayerAt(g_grind_long, 1) before step 3 -- ranking is by entry
   price; quiet market alone cannot restore layer 0 to rank 0 while layer 1
   remains. RemoveLayerAt is the engine scalp-close array shrink (grind_engine
   line 1414); it does NOT call Grind_CarryShiftDelete, so pos_near GV survives.
5. Diagnostic Print, stale1_* scratch arrays, and Grind_ExitQRanks call removed.
6. Quiet market seed for step 3 unchanged: Grind_MarketTestSeed(1.25000,
   1.25020, 0, 0) so raw_formula_far 1.25030 does not clamp.

### Hand-derived expectations

Constants: point=0.00001, exit_pips=3.0, pip price = pips * point * 10 = 0.00030.

Layer 0 (pos_far, entry 1.25000):
  raw_formula_far = 1.25000 + 0.00030 = 1.25030
  clamp market ask=1.25100, min_dist=Grind_CarryMinPassiveDistance(0.00001,0,0)
  With stops_level=0, min_dist=point=0.00001, threshold=1.25101
  1.25030 <= 1.25101 -> clamps to clamp_expected_far = 1.25101
  offset = 1.25101 - 1.25030 = 0.00071 stored under pos_far
  places after first ManageSide = 1

Layer 1 (pos_near, entry 1.24900):
  raw_formula_near = 1.24900 + 0.00030 = 1.24930
  1.24930 <= 1.25101 -> clamps to clamp_expected_near = 1.25101
  near_shift = 1.25101 - 1.24930 = 0.00171 stored under pos_near
  Entry 1.24900 ranks ahead of 1.25000 -> layer 1 rank 0, layer 0 rank 1
  Rank>0 cancel clears pos_far exit and pos_far offset/release GVs
  Layer 1 exit placed at 1.25101; pos_near offset remains
  places after second ManageSide = 2

Layer removal (before step 3):
  Grind_RemoveLayerAt(g_grind_long, 1) evicts pos_near from side array
  pos_far sole layer, rank 0 by default (only entry)
  pos_near GV intentionally survives (RemoveLayerAt does not delete carry GVs)

Step 3 quiet market bid=1.25000 ask=1.25020:
  1.25030 > 1.25020 + 0.00001 = 1.25021 -> no clamp
  ManageSide places pos_far exit at raw 1.25030
  Unclamped else branch: Grind_CarryShiftDelete(pos_far) -- no offset stored
  places after third ManageSide = 3
  I6 recon on pos_far at rank 0 with exit at raw formula passes

Market seed decision: clamp seed (1.25098/1.25100) kept for steps 1-2 so both
layers clamp and store distinct offsets; quiet seed only for step 3 re-place.
This matches test purpose: clamp+offset, demote+clear, remove blocker, re-place
at raw without offset, I6 pass.

### Full STALE-1 test as committed

void Test_STALE1_measured_sequence_cleared_on_redo()
{
   Grind_OrderTestReset();
   Grind_TestResetSideState();
   Grind_CarryTestReset();
   g_grind_order_test_active = true;
   Adr151_TestSeedSlotSeams(200, 100, 0);

   const ulong pos_far = 93001UL;
   const ulong pos_near = 93002UL;
   Grind_CarryShiftDelete(pos_far);
   GlobalVariableDel(Grind_CarryReleaseGvName(pos_far));
   Grind_CarryShiftDelete(pos_near);
   GlobalVariableDel(Grind_CarryReleaseGvName(pos_near));

   const double entry_far = 1.25000;
   const double entry_near = 1.24900;
   const double exit_pips = 3.0;
   const double point = 0.00001;
   const double raw_formula_far = Grind_ExitPrice(entry_far, exit_pips, point, 1);
   const double raw_formula_near = Grind_ExitPrice(entry_near, exit_pips, point, 1);

   Grind_MarketTestSeed(1.25098, 1.25100, 0, 0);
   const double min_dist = Grind_CarryMinPassiveDistance(point, 0, 0);
   const double clamp_expected_far = 1.25100 + min_dist;
   const double clamp_expected_near = 1.25100 + min_dist;
   const double near_shift = clamp_expected_near - raw_formula_near;
   AssertTrue("STALE-1 precnd far clamp", raw_formula_far <= 1.25100 + min_dist - 1e-12);
   AssertTrue("STALE-1 precnd near clamp", raw_formula_near <= 1.25100 + min_dist - 1e-12);

   ArrayResize(g_grind_long.layers, 1);
   Adr151_TestSetupLongLayer(g_grind_long, 0, 0, entry_far, pos_far, 0);
   Grind_ExitQManageSide(g_grind_long, true, 22260101UL, "OPT", 0.01, exit_pips);

   AssertTrue("STALE-1 clamp placed", g_grind_order_test_place_calls == 1);
   AssertNear("STALE-1 clamp price", g_grind_order_test_last_placed_price, clamp_expected_far, 1e-12);
   AssertTrue("STALE-1 far offset stored", GlobalVariableCheck(Grind_CarryShiftGvName(pos_far)));

   ArrayResize(g_grind_long.layers, 2);
   Adr151_TestSetupLongLayer(g_grind_long, 1, 1, entry_near, pos_near, 0);
   Grind_ExitQManageSide(g_grind_long, true, 22260101UL, "OPT", 0.01, exit_pips);

   AssertTrue("STALE-1 demoted bare", g_grind_long.layers[0].exit_order_ticket == 0);
   AssertTrue("STALE-1 near exit placed", g_grind_long.layers[1].exit_order_ticket != 0);
   AssertTrue("STALE-1 two places", g_grind_order_test_place_calls == 2);
   AssertNear("STALE-1 near price", g_grind_long.layers[1].exit_target, clamp_expected_near, 1e-12);
   AssertFalse("STALE-1 far offset cleared", GlobalVariableCheck(Grind_CarryShiftGvName(pos_far)));
   AssertFalse("STALE-1 far release cleared", GlobalVariableCheck(Grind_CarryReleaseGvName(pos_far)));
   AssertTrue("STALE-1 near offset stored", GlobalVariableCheck(Grind_CarryShiftGvName(pos_near)));
   AssertNear("STALE-1 near shift val", Grind_CarryShiftGet(pos_near), near_shift, 1e-12);

   Grind_RemoveLayerAt(g_grind_long, 1);
   AssertTrue("STALE-1 one layer", ArraySize(g_grind_long.layers) == 1);
   AssertTrue("STALE-1 far remains", g_grind_long.layers[0].position_ticket == pos_far);
   AssertTrue("STALE-1 near offset survives", GlobalVariableCheck(Grind_CarryShiftGvName(pos_near)));

   Grind_MarketTestSeed(1.25000, 1.25020, 0, 0);
   AssertTrue("STALE-1 quiet precnd", raw_formula_far > 1.25020 + min_dist - 1e-12);
   Grind_ExitQManageSide(g_grind_long, true, 22260101UL, "OPT", 0.01, exit_pips);

   AssertTrue("STALE-1 replace placed", g_grind_order_test_place_calls == 3);
   AssertNear("STALE-1 replace raw", g_grind_order_test_last_placed_price, raw_formula_far, 1e-12);
   AssertFalse("STALE-1 far replace no offset", GlobalVariableCheck(Grind_CarryShiftGvName(pos_far)));

   GrindReconLayerScratch layers[1];
   Grind_TestInitLayerScratch(layers[0], 0, entry_far, pos_far);
   layers[0].has_exit_order = (g_grind_long.layers[0].exit_order_ticket != 0);
   layers[0].exit_order_ticket = g_grind_long.layers[0].exit_order_ticket;
   layers[0].exit_target = g_grind_long.layers[0].exit_target;
   int long_ranks[1];
   long_ranks[0] = 0;
   GrindReconLayerScratch empty[];
   int short_ranks[];
   string reason = "";
   AssertTrue("STALE-1 i6",
              Grind_ReconCheckInvariants(layers, 1, long_ranks, empty, 0, short_ranks,
                                         exit_pips, point, 12, reason));

   Grind_CarryShiftDelete(pos_far);
   GlobalVariableDel(Grind_CarryReleaseGvName(pos_far));
   Grind_CarryShiftDelete(pos_near);
   GlobalVariableDel(Grind_CarryReleaseGvName(pos_near));
   Grind_MarketTestReset();
   Grind_OrderTestReset();
   Grind_TestResetSideState();
   Grind_CarryTestReset();
   Adr151_TestResetAll();
}

### Self-review checklist

- Every offset assertion names pos_far or pos_near via Grind_CarryShiftGvName(ticket).
- pos_near offset asserted stored after demotion and survives after RemoveLayerAt.
- Diagnostic Print and stale1_* scratch removed.
- No production file changed in this commit.

Deleted-assert grep (must be empty):

  git diff origin/main -- ea/fxgrind_tests.mq5 ea/fxgrind_tests_adr151.mqh | grep "^-" | grep -i "Assert\|void Test_"
  (empty)

git diff --stat origin/main...fix/exitq-stale-offset (after this commit):

 ea/fxgrind_tests.mq5                   |   5 +
 ea/fxgrind_tests_adr151.mqh            | 278 ++++++++++++++++++++++++++++
 ea/grind_engine.mqh                    |   4 +
 prompts/exitq_stale_offset_response.md | 327 +++++++++++++++++++++++++++++++++
 4 files changed, 614 insertions(+)

Line count: 327
