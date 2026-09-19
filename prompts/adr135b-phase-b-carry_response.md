This message has a line count at the bottom

# ADR-135b Phase B -- Carry-Aware Exit Queue

Branch: feat/adr135b-phase-b-carry (four commits, pushed, not merged)

## git diff --stat origin/main...feat/adr135b-phase-b-carry

 .../architecture/ADR-135b-carry-exit-adjustment.md |  15 +-
 docs/architecture/ADR-151-order-purgatory.md       |  14 +-
 ea/fxgrind.mq5                                     |   5 -
 ea/fxgrind_tests.mq5                               |   6 +
 ea/fxgrind_tests_adr151.mqh                        | 215 ++++++++++++++++++++-
 ea/fxgrind_tests_adr152.mqh                        |   2 +-
 ea/grind_engine.mqh                                |   3 +-
 ea/grind_exitq.mqh                                 |   8 +-
 ea/grind_recon.mqh                                 |   6 +-
 ea/presets/audcad_alt.set                          |   2 +-
 ea/presets/audcad_opt.set                          |   2 +-
 ea/presets/audchf_alt.set                          |   2 +-
 ea/presets/audchf_opt.set                          |   2 +-
 ea/presets/audnzd_alt.set                          |   2 +-
 ea/presets/audnzd_opt.set                          |   2 +-
 ea/presets/cadchf_alt.set                          |   2 +-
 ea/presets/cadchf_opt.set                          |   2 +-
 ea/presets/eurgbp_alt.set                          |   2 +-
 ea/presets/eurgbp_opt.set                          |   2 +-
 ea/presets/eurusd_alt.set                          |   2 +-
 ea/presets/eurusd_opt.set                          |   2 +-
 ea/presets/gbpusd_alt.set                          |   2 +-
 ea/presets/gbpusd_opt.set                          |   2 +-
 ea/presets/nzdcad_alt.set                          |   2 +-
 ea/presets/nzdcad_opt.set                          |   2 +-
 25 files changed, 268 insertions(+), 38 deletions(-)

## Grind_ExitQFormulaTarget (commit 2)

    double Grind_ExitQFormulaTarget(const double entry,
                                    const double exit_pips,
                                    const double point,
                                    const bool is_long,
                                    const ulong position_ticket)
    {
       const double shift = (position_ticket > 0)
                            ? Grind_CarryShiftGetForRecon(position_ticket)
                            : 0.0;
       return Grind_ExitPrice(entry, exit_pips, point, is_long ? 1 : -1) + shift;
    }

## Shift application -- queue vs recon (conventions match)

Queue (grind_exitq.mqh):

    return Grind_ExitPrice(entry, exit_pips, point, is_long ? 1 : -1) + shift;

Recon (grind_recon.mqh, Grind_ReconExitMatchesEntry):

    const int dir = is_long ? 1 : -1;
    const double expected = Grind_ExitPrice(entry, exit_pips, point, dir) + shift;

Both add shift in price space directly to Grind_ExitPrice. Neither uses
Grind_CarryShiftedExitPrice. Queue reads shift via Grind_CarryShiftGetForRecon;
recon I6 passes the same value from Grind_CarryShiftGetForRecon(position_id).
Conventions match.

## Updated callers (all pass position ticket)

| File | Line | Ticket source |
|------|------|---------------|
| ea/grind_engine.mqh | 1832-1834 | side.layers[i].position_ticket |
| ea/grind_recon.mqh | 1093-1094 | long_scratch[j].position_id |
| ea/grind_recon.mqh | 1109-1110 | short_scratch[j].position_id |
| ea/fxgrind_tests_adr151.mqh | 84 | position_ticket param |
| ea/fxgrind_tests_adr151.mqh | 300 | 7001UL |
| ea/fxgrind_tests_adr151.mqh | 335 | 7002UL |
| ea/fxgrind_tests_adr152.mqh | 515 | 5003UL |

No call site lacked a ticket. grind_recon.mqh: only the two
Grind_ExitQFormulaTarget call sites gained position_id arguments.
Grind_ReconExitMatchesEntry, I6 logic, and carry pass code were not edited.
grind_carry.mqh was not edited.

## Presets

Exactly 16 files changed (InpEnableCarryPass=false -> true):

audcad_alt, audcad_opt, audchf_alt, audchf_opt, audnzd_alt, audnzd_opt,
cadchf_alt, cadchf_opt, eurgbp_alt, eurgbp_opt, eurusd_alt, eurusd_opt,
gbpusd_alt, gbpusd_opt, nzdcad_alt, nzdcad_opt.

nzdchf_alt and nzdchf_opt unchanged (still false).

## Commit 1 tests vs stub (expected failures)

Hand maths: point=0.00001, pips_to_price = pips * point * 10.

CARRY-Q1 (PASS on stub): entry 1.10300, 3 pips, no GV.
  raw = 1.10300 + 0.00030 = 1.10330. Stub returns raw. Pass.

CARRY-Q2 (FAIL on stub): entry 1.10300, shift 0.00015 stored.
  expected = 1.10330 + 0.00015 = 1.10345.
  Stub returns 1.10330. AssertNear target fails; I6 pass fails.

CARRY-Q3 (FAIL on stub): short entry 1.09600, shift 0.00012.
  raw = 1.09600 - 0.00030 = 1.09570; expected = 1.09582.
  Stub returns 1.09570. AssertNear and I6 fail.

CARRY-Q4 (PASS on stub): ticket 0 and unknown 90004, no GV.
  Both return 1.10330. Pass.

CARRY-Q5 (FAIL on stub): rank-0 layer entry 1.10300, ticket 90005,
  shift 0.00020, expected place 1.10350.
  Stub places 1.10330. AssertNear price fails.

CARRY-Q6 (FAIL on stub): entry 1.25000, shift -0.00010, ask 1.25025.
  raw = 1.25030 (above ask+point, unclamped).
  shifted = 1.25020 (at/below ask+point, clamp to 1.25026).
  Stub clamps raw to 1.25030 (no clamp) or places 1.25030.
  AssertNear expected 1.25026 fails.

Four tests fail against the stub (Q2, Q3, Q5, Q6). Two pass (Q1, Q4).

## Commits

1. d8b0c91 -- tests + stub signature + caller ticket args
2. a0b4d84 -- Grind_ExitQFormulaTarget shift; remove OnInit FATAL guard
3. b0fd366 -- 16 presets InpEnableCarryPass=true
4. 2adeb0b -- ADR-135b Phase B section; ADR-151 Phase B enabled

## DIAGNOSTIC: CARRY-Q5

One Print inserted in Test_CARRY_Q5_held_promoted_places_shifted_target
immediately after Grind_ExitQManageSide:

    Print("CARRY-Q5 DIAG expected=", expected,
          " placed=", g_grind_order_test_last_placed_price,
          " formula=", Grind_ExitQFormulaTarget(entry, exit_pips, point, true, pos),
          " shift=", Grind_CarryShiftGetForRecon(pos),
          " bid=", Grind_MarketBid(), " ask=", Grind_MarketAsk(),
          " mindist=", Grind_CarryMinPassiveDistance(point, Grind_MarketStopsLevel(), 0),
          " places=", g_grind_order_test_place_calls);

No assertion, expected value, shift, layer setup, or position id was changed.
No market seed was added to Q5. No other file was edited.

Change since 4a295fe (this commit, ea/ only):

 ea/fxgrind_tests_adr151.mqh | 8 ++++++++
 1 file changed, 8 insertions(+)

git diff --stat origin/main...feat/adr135b-phase-b-carry:

 .../architecture/ADR-135b-carry-exit-adjustment.md |  15 +-
 docs/architecture/ADR-151-order-purgatory.md       |  14 +-
 ea/fxgrind.mq5                                     |   5 -
 ea/fxgrind_tests.mq5                               |   6 +
 ea/fxgrind_tests_adr151.mqh                        | 223 ++++++++++++++++++++-
 ea/fxgrind_tests_adr152.mqh                        |   2 +-
 ea/grind_engine.mqh                                |   3 +-
 ea/grind_exitq.mqh                                 |   8 +-
 ea/grind_recon.mqh                                 |   6 +-
 ea/presets/audcad_alt.set                          |   2 +-
 ea/presets/audcad_opt.set                          |   2 +-
 ea/presets/audchf_alt.set                          |   2 +-
 ea/presets/audchf_opt.set                          |   2 +-
 ea/presets/audnzd_alt.set                          |   2 +-
 ea/presets/audnzd_opt.set                          |   2 +-
 ea/presets/cadchf_alt.set                          |   2 +-
 ea/presets/cadchf_opt.set                          |   2 +-
 ea/presets/eurgbp_alt.set                          |   2 +-
 ea/presets/eurgbp_opt.set                          |   2 +-
 ea/presets/eurusd_alt.set                          |   2 +-
 ea/presets/eurusd_opt.set                          |   2 +-
 ea/presets/gbpusd_alt.set                          |   2 +-
 ea/presets/gbpusd_opt.set                          |   2 +-
 ea/presets/nzdcad_alt.set                          |   2 +-
 ea/presets/nzdcad_opt.set                          |   2 +-
 prompts/adr135b-phase-b-carry_response.md          | 154 ++++++++++++++
 26 files changed, 430 insertions(+), 38 deletions(-)

Diagnostic is in place. Operator must run the suite to obtain values. No
cause is stated here -- inference without a run is not evidence.

## DIAGNOSTIC 2: CARRY-Q5

First measurement (7de491d): expected=1.1035 placed=1.14863 formula=1.14843
shift=0.04513 bid=1.14856 ask=1.14862 mindist=0.00001 places=1.

Print A inserted immediately after Grind_CarryShiftSet(pos, shift), before
GlobalVariableSet(Grind_CarryReleaseGvName(pos), 1.0):

    Grind_CarryShiftSet(pos, shift);
    Print("CARRY-Q5 BEFORE set=", shift,
          " gvraw=", GlobalVariableGet(Grind_CarryShiftGvName(pos)),
          " getraw=", Grind_CarryShiftGet(pos),
          " getforrecon=", Grind_CarryShiftGetForRecon(pos),
          " relexists=", GlobalVariableCheck(Grind_CarryReleaseGvName(pos)));
    GlobalVariableSet(Grind_CarryReleaseGvName(pos), 1.0);

Print B replaces the prior CARRY-Q5 DIAG line, immediately after
Grind_ExitQManageSide(...):

    Grind_ExitQManageSide(g_grind_long, true, 22260101UL, "OPT", 0.01, exit_pips);

    Print("CARRY-Q5 AFTER set=", shift,
          " gvname=", Grind_CarryShiftGvName(pos),
          " gvexists=", GlobalVariableCheck(Grind_CarryShiftGvName(pos)),
          " gvraw=", GlobalVariableGet(Grind_CarryShiftGvName(pos)),
          " relname=", Grind_CarryReleaseGvName(pos),
          " relexists=", GlobalVariableCheck(Grind_CarryReleaseGvName(pos)),
          " getraw=", Grind_CarryShiftGet(pos),
          " getvalidated=", Grind_CarryShiftGetValidated(pos, 0, Grind_CarryNightlyMaxPips(_Symbol)),
          " getforrecon=", Grind_CarryShiftGetForRecon(pos),
          " nightly=", Grind_CarryNightlyMaxPips(_Symbol),
          " symbol=", _Symbol);

All helpers used match grind_carry.mqh signatures as-is; none omitted.

No assertion, expected, shift value, layer setup, or position id changed.
No market seed added. No cause proposed.

Change since 7de491d (ea/ only):

 ea/fxgrind_tests_adr151.mqh | 23 ++++++---
 1 file changed, 17 insertions(+), 6 deletions(-)

git diff --stat origin/main...feat/adr135b-phase-b-carry:

 .../architecture/ADR-135b-carry-exit-adjustment.md |  15 +-
 docs/architecture/ADR-151-order-purgatory.md       |  14 +-
 ea/fxgrind.mq5                                     |   5 -
 ea/fxgrind_tests.mq5                               |   6 +
 ea/fxgrind_tests_adr151.mqh                        | 232 +++++++++++++++++-
 ea/fxgrind_tests_adr152.mqh                        |   2 +-
 ea/grind_engine.mqh                                |   3 +-
 ea/grind_exitq.mqh                                 |   8 +-
 ea/grind_recon.mqh                                 |   6 +-
 ea/presets/audcad_alt.set                          |   2 +-
 ea/presets/audcad_opt.set                          |   2 +-
 ea/presets/audchf_alt.set                          |   2 +-
 ea/presets/audchf_opt.set                          |   2 +-
 ea/presets/audnzd_alt.set                          |   2 +-
 ea/presets/audnzd_opt.set                          |   2 +-
 ea/presets/cadchf_alt.set                          |   2 +-
 ea/presets/cadchf_opt.set                          |   2 +-
 ea/presets/eurgbp_alt.set                          |   2 +-
 ea/presets/eurgbp_opt.set                          |   2 +-
 ea/presets/eurusd_alt.set                          |   2 +-
 ea/presets/eurusd_opt.set                          |   2 +-
 ea/presets/gbpusd_alt.set                          |   2 +-
 ea/presets/gbpusd_opt.set                          |   2 +-
 ea/presets/nzdcad_alt.set                          |   2 +-
 ea/presets/nzdcad_opt.set                          |   2 +-
 prompts/adr135b-phase-b-carry_response.md          | 259 +++++++++++++++++++++
 26 files changed, 544 insertions(+), 38 deletions(-)

Operator must run the suite to obtain BEFORE/AFTER values.

Line count: 259
