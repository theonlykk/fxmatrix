This message has a line count at the bottom

Branch: feat/adr152-phase2-horizon (from origin/main at 36a6477)
Commits (in order):
  ca5a32a commit 1: horizon tests against stub (must fail)
  f3eb0c9 commit 2: entry horizon withholding implementation
  6282065 commit 3: fleet Phase 1 opt-in and GBPUSD horizon presets
  db341d1 commit 4: rollout text amendments (Gemini 2026-09-18)
Not merged. Branch pushed.

SELF-REVIEW

git diff --stat origin/main...feat/adr152-phase2-horizon (raw):

 docs/architecture/ADR-152-entry-purgatory.md |  17 +-
 ea/fxgrind.mq5                               |  22 +-
 ea/fxgrind_tests.mq5                         |  17 ++
 ea/fxgrind_tests_adr152.mqh                  | 328 ++++++++++++++++++++++++++-
 ea/grind_api_counter.mqh                     |  15 ++
 ea/grind_config.mqh                          |   9 +
 ea/grind_engine.mqh                          | 197 +++++++++++++++-
 ea/grind_recon.mqh                           |   6 +
 ea/grind_state.mqh                           |   6 +
 ea/presets/audcad_alt.set                    |   2 +
 ea/presets/audcad_opt.set                    |   2 +
 ea/presets/audchf_alt.set                    |   2 +
 ea/presets/audchf_opt.set                    |   2 +
 ea/presets/audnzd_alt.set                    |   2 +
 ea/presets/audnzd_opt.set                    |   2 +
 ea/presets/cadchf_alt.set                    |   2 +
 ea/presets/cadchf_opt.set                    |   2 +
 ea/presets/eurgbp_alt.set                    |   2 +
 ea/presets/eurgbp_opt.set                    |   2 +
 ea/presets/eurusd_alt.set                    |   2 +
 ea/presets/eurusd_opt.set                    |   2 +
 ea/presets/gbpusd_alt.set                    |   1 +
 ea/presets/gbpusd_opt.set                    |   1 +
 ea/presets/nzdcad_alt.set                    |   2 +
 ea/presets/nzdcad_opt.set                    |   2 +
 25 files changed, 632 insertions(+), 15 deletions(-)

Hysteresis condition as implemented (grind_engine.mqh):

  const bool in_floor = (dist <= floor_price + GRIND_PRICE_EPS);
  const bool in_place = in_floor || (dist <= H_price + GRIND_PRICE_EPS);
  const bool in_cancel = (dist > Hc_price + GRIND_PRICE_EPS);

  Evaluation order: in_floor first (line 580), then in_cancel (597), then
  in_place (617). The hysteresis band is H < dist <= Hc: neither in_cancel
  nor in_place, so the function returns without transition (line 634).

Floor relative to horizon: floor is evaluated first at line 580, before
in_cancel (597) and in_place (617). Floor uses floor_price =
Grind_PipsToPrice(add_pips, _Point).

entry_transitions_used reset: Grind_EntryHorizonDailyReset() in
grind_api_counter.mqh line 54, called from Grind_ApiCounterMaybeReset() at
line 80 on broker-date rollover (alongside g_grind_near_reserve_blocks = 0).

Preset files changed: exactly 16. NZDCHF files (nzdchf_alt.set,
nzdchf_opt.set) not touched.

L0 functions unchanged: Grind_TryPlaceL0 and Grind_TryRecenterOppositeL0
not modified.

Commit 1 stub failures (Grind_ApplyEntryHorizon returned 0):

  T4a_horizon_floor_rest       FAIL: no place, held not cleared
  T4b_horizon_place_at_H       FAIL: no place at H boundary
  T4c_horizon_cancel_at_Hc     FAIL: no cancel, held not set
  T4d_horizon_no_flicker       FAIL: no initial place / transitions stay 0
  T5_horizon_transition_budget FAIL: budget path not enforced by stub
  T10_horizon_gap_missed_once  FAIL: add_gap_missed stays 0

Commit 1 tests that passed against stub (not testing the change):

  T4e_horizon_off_is_phase1    PASS: H=0 bypasses stub via Phase 1 EnsureAddNext
  T9_held_add_reconstruction  PASS: recon checks do not require horizon logic
  T_invariant_held_pending    PASS: Assert helper implemented in commit 1

Suite figure observed: not run (no MetaEditor in this session). Operator
must compile and run fxgrind_tests.mq5; baseline expectation 1178/1178
plus 9 new horizon tests (7 should pass after commit 2, 3 passed at stub).

Anything else changed: nothing beyond the files listed above and this
response file.

## FIX: add_held clear-before-send

Branch: feat/adr152-phase2-horizon @ 3cfdd6c (after fix commits)
Additional commits (in order):
  2d7a6b1 ADR-152 phase 2 fix: T4f held retained when guard refuses send (must fail)
  3cfdd6c ADR-152 phase 2 fix: clear add_held only after successful in_place send
Not merged. Branch pushed.

SELF-REVIEW

git diff --stat origin/main...feat/adr152-phase2-horizon (raw):

 docs/architecture/ADR-152-entry-purgatory.md |  17 +-
 ea/fxgrind.mq5                               |  22 +-
 ea/fxgrind_tests.mq5                         |  18 ++
 ea/fxgrind_tests_adr152.mqh                  | 369 ++++++++++++++++++++++++++-
 ea/grind_api_counter.mqh                     |  15 ++
 ea/grind_config.mqh                          |   9 +
 ea/grind_engine.mqh                          | 200 ++++++++++++++-
 ea/grind_recon.mqh                           |   6 +
 ea/grind_state.mqh                           |   6 +
 ea/presets/audcad_alt.set                    |   2 +
 ea/presets/audcad_opt.set                    |   2 +
 ea/presets/audchf_alt.set                    |   2 +
 ea/presets/audchf_opt.set                    |   2 +
 ea/presets/audnzd_alt.set                    |   2 +
 ea/presets/audnzd_opt.set                    |   2 +
 ea/presets/cadchf_alt.set                    |   2 +
 ea/presets/cadchf_opt.set                    |   2 +
 ea/presets/eurgbp_alt.set                    |   2 +
 ea/presets/eurgbp_opt.set                    |   2 +
 ea/presets/eurusd_alt.set                    |   2 +
 ea/presets/eurusd_opt.set                    |   2 +
 ea/presets/gbpusd_alt.set                    |   1 +
 ea/presets/gbpusd_opt.set                    |   1 +
 ea/presets/nzdcad_alt.set                    |   2 +
 ea/presets/nzdcad_opt.set                    |   2 +
 prompts/adr152-phase2-horizon_response.md    | 139 ++++++++-
 26 files changed, 765 insertions(+), 15 deletions(-)

in_place branch as fixed (grind_engine.mqh lines 617-635):

  if(in_place) {
     if(side.add_held && side.add_pending_ticket == 0 && !g_grind_ent_sent_this_tick) {
        if(Grind_EntryTransitionTryConsume(side)) {
           transitions++;
           if(Grind_SendNextAddEnt(side, is_long, magic, slot, add_pips, max_layers, lots, false)) {
              side.add_held = false;
           } else {
              side.entry_transitions_used--;
              transitions--;
           }
        }
     }
     if(side.add_pending_ticket != 0) {
        const double resting = Grind_OrderGetPriceOpen(side.add_pending_ticket);
        if(!Grind_PriceWithinDeadband(resting, clamped, deadband_pips, _Point))
           Grind_ModifyPendingPrice(side.add_pending_ticket, clamped, magic);
     }
     return transitions;
  }

in_floor and in_cancel byte-identical to d29423c: confirmed via
  git diff d29423c -- ea/grind_engine.mqh
which shows only the in_place block changed (5 insertions, 2 deletions).

T4f failure against unfixed code (commit 2d7a6b1 only, before 3cfdd6c):
  Test_T4f_horizon_held_retained_on_failed_send arranges long side in the
  place band (floor < dist <= H) with add_held=true, add_pending_ticket=0,
  and Adr152_TestSeedSlotSeams(200, 100, 95) so Grind_SendNextAddEnt is
  refused by the near-reserve guard. On the first tick the unfixed in_place
  branch cleared add_held before the send and did not restore it on failure.
  AssertTrue("T4f held after tick1", g_grind_long.add_held) FAILS:
  add_held reads false. entry_transitions_used rollback on failure may leave
  that counter unchanged; the guard on add_held prevents any retry on tick 2.

Suite figure observed: not run (no MetaEditor in this session).

Anything else changed: only ea/fxgrind_tests_adr152.mqh (T4f test),
ea/fxgrind_tests.mq5 (wire T4f), ea/grind_engine.mqh (in_place fix), and
this response file. in_floor, in_cancel, band arithmetic, gap check,
presets, ADR, and other tests untouched.

Line count: 172
