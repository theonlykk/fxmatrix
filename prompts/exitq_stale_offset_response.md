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

Line count: 159
