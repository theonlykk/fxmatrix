This message has a line count at the bottom

Branch: feat/adr151-exitq-k1-h0 (from origin/main at 927034a)
Commits (in order):
  1088de5 commit 1: tests against K=2 stub (must fail)
  a10770e commit 2: GRIND_EXITQ_K=1, GRIND_EXITQ_H=0, clamp telemetry
  6b01c6b commit 3: GBPUSD presets InpEntryHorizonPips=0
  7b41e1c commit 4: ADR-151 and ADR-152 text
Not merged. Branch pushed.

SELF-REVIEW

git diff --stat origin/main...feat/adr151-exitq-k1-h0 (raw):

 docs/architecture/ADR-151-order-purgatory.md |  25 +++-
 docs/architecture/ADR-152-entry-purgatory.md |   8 +-
 ea/fxgrind.mq5                               |   7 +-
 ea/fxgrind_tests.mq5                         |   5 +
 ea/fxgrind_tests_adr151.mqh                  | 185 ++++++++++++++++++++++++++-
 ea/fxgrind_tests_adr152.mqh                  |   1 +
 ea/grind_api_counter.mqh                     |   2 +
 ea/grind_config.mqh                          |   4 +-
 ea/grind_engine.mqh                          |   2 +
 ea/grind_state.mqh                           |   1 +
 ea/presets/gbpusd_alt.set                    |   2 +-
 ea/presets/gbpusd_opt.set                    |   2 +-
 12 files changed, 230 insertions(+), 14 deletions(-)

Constants (grind_config.mqh):

  #define GRIND_EXITQ_K                 1
  #define GRIND_EXITQ_H                 0

Telemetry increment site (grind_engine.mqh lines 1835-1837):

      const bool clamped = Grind_ExitQClampPassive(is_long, formula, price);
      if(clamped)
         side.exit_clamped_promotions++;

Reset: grind_api_counter.mqh Grind_ApiCounterMaybeReset broker-date block,
alongside g_grind_near_reserve_blocks = 0. Heartbeat emits
exit_clamped_promotions_long / _short in fxgrind.mq5.

I3 verified, NOT edited: grind_recon.mqh line 491 gates exit coverage on
Grind_ExitQRequired(long_rank). Narrowing K to 1 narrows I3 automatically.

Rewritten EQ4 assertions (K=1/H=0):

  req0 true, req1 false
  allow0 true, allow1 false
  ranks 0..4: Required == Allowed at every rank

EQ5: still passes with K override (k99) and default req2 false unchanged.

Commit 1 failures against K=2/H=1 stub (before commit 2):

  EQ4 req1          FAIL: true (expected false)
  EQ4 allow1        FAIL: true (expected false)
  EQ4 allow2        FAIL: true (expected false)
  EQ4 agree r2      FAIL: req false, allow true
  EQ4 agree r3      FAIL: req false, allow false (agree but wrong band)
  EQ-K1a one resting FAIL: 2 resting exits (K=2 places rank 0 and 1)
  EQ-K1b one place  FAIL: 0 places on churn tick (rank 1 still allowed)
  EQ-K1b one cancel FAIL: 0 cancels
  EQ-K1c pass held  FAIL: I3_LONG_NAKED (rank 1 uncovered under K=2)
  EQ-CLAMP1 counter FAIL: field absent / always 0 without increment site
  EQ-CLAMP2 counter PASS in both states (always 0 pre-telemetry; price
    assertions still discriminate once compiled)

Preset files changed: exactly 2 (gbpusd_opt.set, gbpusd_alt.set).

Anything else changed: Adr152_TestResetHorizonSide resets
exit_clamped_promotions for test isolation (fxgrind_tests_adr152.mqh).
Grind_ExitQRequired, Grind_ExitQAllowed, Grind_EntryHorizonCheckGap,
Grind_ExitQClampPassive, grind_recon I3 logic, and all non-GBPUSD presets
untouched. MQ1/MQ2/MQ7 default-path assertions still encode K=2/H=1 counts;
operator should expect those to fail until updated separately.

Suite figure observed: not run (no MetaEditor in this session). Baseline
before change: 1226/1226 operator-run 2026-09-18.

Line count: 82
