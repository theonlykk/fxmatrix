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

Line count: 88
