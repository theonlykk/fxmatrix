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

## DIAGNOSIS: EQ-K1c

Test: Test_EQ_K1c_i3_requires_rank_zero_only (fxgrind_tests_adr151.mqh)
Operator failure: AssertTrue("EQ-K1c pass held", ...) at first call to
Grind_ReconCheckInvariants.

1. reason string: "I6_LONG_EXIT" (NOT I3_LONG_NAKED).

2. Branch: neither I3 no_position (~487) nor I3 no_exit_coverage (~492).
   The failure is I6 at grind_recon.mqh ~500-508, reached only because
   layers[2] has exit coverage and I3 passed for all three layers.
   Rank gate: rank 0 (layers[2]) is the sole required rank under K=1;
   ranks 1 and 2 correctly skipped for I3.

3. I6 root cause: exit_target mismatch against point=0.00001.
   layers[2]: entry 1.10300, exit_pips 3.0, exit_target 1.10330.
   Grind_ExitQFormulaTarget(1.10300, 3.0, 0.00001, true) = 1.10303.
   |1.10330 - 1.10303| = 0.00027 >> tolerance 2*point (0.00002).
   The test used a 5-digit-style target (1.10330) while passing point=0.00001
   to recon. max_layers=12 with 3 layers is not I7. No other invariant fires.

4. Grind_TestInitLayerScratch sets has_position = true (fxgrind_tests.mq5
   line 6033). has_position is not the defect.

Conclusion: I3 rank gate is working as designed for K=1. The K=1 safety
claim stands. EQ-K1c fails because the scratch exit_target is inconsistent
with the point argument -- a test setup error, not an I3 or recon defect.
Recommended fix (after operator read): set exit_target from
Grind_ExitQFormulaTarget(entry, exit_pips, point, true) using the same
point passed to Grind_ReconCheckInvariants. Do not edit grind_recon.mqh.

Line count: 115

## FIX: six stale K=2/H=1 assertions

Commit: (this commit) six stale assertion updates after EQ-K1c diagnosis.

git diff --stat origin/main...feat/adr151-exitq-k1-h0 (raw):

 docs/architecture/ADR-151-order-purgatory.md |  25 +++-
 docs/architecture/ADR-152-entry-purgatory.md |   8 +-
 ea/fxgrind.mq5                               |   7 +-
 ea/fxgrind_tests.mq5                         |   9 +-
 ea/fxgrind_tests_adr151.mqh                  | 200 +++++++++++++++++++++++++--
 ea/fxgrind_tests_adr152.mqh                  |   1 +
 ea/grind_api_counter.mqh                     |   2 +
 ea/grind_config.mqh                          |   4 +-
 ea/grind_engine.mqh                          |   2 +
 ea/grind_state.mqh                           |   1 +
 ea/presets/gbpusd_alt.set                    |   2 +-
 ea/presets/gbpusd_opt.set                    |   2 +-
 prompts/adr151-exitq-k1-h0_response.md       | 171 +++++++++++++++++++++++
 13 files changed, 412 insertions(+), 22 deletions(-)

grind_recon.mqh: NOT edited.

MQ1 cancel once -> cancel thrice
  Old: 1 cancel. K=2/H=1 Allowed rank<3; rank 3 (layer 0, farthest) trimmed.
  New: 3 cancels. K=1/H=0 Allowed rank<1; ranks 1,2,3 (layers 2,1,0) trimmed.
  rank 0 kept on layer 3 (1.10200 nearest). Still meaningful: trim band width.

MQ2 place twice -> place once; rank1 exit -> rank1 bare
  Old: 2 places (ranks 0 and 1 required under K=2).
  New: 1 place on rank 0 only (layer 2 at 1.10300). rank1 bare confirms
  K=1 does not release rank 1 -- meaningful, not vacuous inversion.

MQ7 k2 sends -> k1 sends (k1 cancels unchanged at 2)
  Old: 2 cancels 2 sends. K=2 required ranks 0,1; fixture exits on ranks 3,4
  cancelled; ranks 0,1 placed.
  New: 2 cancels 1 send. K=1 cancels ranks 3,4 exits; places rank 0 only.
  k99 override section unchanged. Still meaningful.

Q10 layer1 unchanged -> layer1 trimmed
  Old: layer1 keeps ticket 7001. K=2/H=1 rank 2 allowed in may band.
  New: layer1 ticket 0. Ranks: L0 1.247=0, L2 1.248=1, L1 1.249=2; rank 2
  exit not Allowed at K=1/H=0. Still tests retry places rank 0 only.

SB4 old exit -> old exit trimmed
  Old: layer0 keeps 3001 after ent fill. K=2/H=1 rank 1 exit allowed.
  New: layer0 ticket 0. New fill at 1.26050 is rank 0; old layer rank 1 exit
  trimmed under K=1. Still tests ent fill promotes new rank 0 exit.

EQ-K1c: not changed in this commit (diagnosis pending operator ack).

Anything else changed: nothing beyond the six assertions above and this
response file.

Line count: 171

## FIX: EQ-K1c carry reset

Prior diagnosis correction: Grind_PipsToPrice is pips * point * 10.0
(grind_pure.mqh:65). exit_target 1.10330 matches
Grind_ExitQFormulaTarget(1.10300, 3.0, 0.00001, true) exactly. The I6
failure was a stale carry shift on position id 5003, not a target mismatch.

Fix: one line in Test_EQ_K1c_i3_requires_rank_zero_only setup:

  Grind_CarryTestReset();

EQ-K1c setup as committed:

  void Test_EQ_K1c_i3_requires_rank_zero_only()
  {
     Grind_CarryTestReset();
     GrindReconLayerScratch layers[3];
     Grind_TestInitLayerScratch(layers[0], 0, 1.10500, 5001UL);
     layers[0].has_exit_order = false;
     Grind_TestInitLayerScratch(layers[1], 1, 1.10400, 5002UL);
     layers[1].has_exit_order = false;
     Grind_TestInitLayerScratch(layers[2], 2, 1.10300, 5003UL);
     layers[2].has_exit_order = true;
     layers[2].exit_order_ticket = 6103;
     layers[2].exit_target = 1.10330;
     ...

exit_target still 1.10330. Both assertions unchanged. No file outside
fxgrind_tests_adr151.mqh touched.

Other tests calling Grind_ReconCheckInvariants without Grind_CarryTestReset
(not fixed this commit):

  fxgrind_tests_adr151.mqh:
    Test_RI1_HeldLayerBeyondKPassesI3 (no exit coverage; I6 not reached)
    Test_RI2_MissingExitAtRequiredRankFailsI3 (no exit coverage)
    Test_RI3_I1SkipsLayersWithoutExit (no exit coverage)
    Test_RI4_I6SkipsLayersWithoutExit (no exit coverage)

  fxgrind_tests_adr152.mqh:
    Test_T9_held_add_reconstruction (exit coverage, position 5001)

  fxgrind_tests.mq5:
    Test_I5c_DuplicateIndicesFail (no exit coverage)
    Test_I5d_NegativeIndexFails (no exit coverage)
    Test_IV1_I6LongExitOrderDetail (exit coverage, pos 541545776)
    Test_IV2_I6LongExitPositionLiveCase (exit coverage, pos 541545776)
    Test_IV3_I3LongNakedDetail (no exit coverage)
    Test_IV4_I7LongDepthDetail (exit coverage; fails I7 before I6)
    Test_IV5_InvariantDetailClearsOnPass (exit coverage, pos 1001)
    Test_IV6_JsonShapeAndArchiveInfo (exit coverage, pos 541545776)
    Test_EF1_I6LiveFavourableFillLong (exit coverage, pos 541545776)
    Test_EF2_I6LargeFavourableFillLong (exit coverage, pos 541545776)
    Test_EF3_I6ShortFillMirror (exit coverage, pos 1001)
    Test_EF4_I6AdverseFillQuarantinable (exit coverage, pos 541545776)
    Test_EF5_I6RestingMismatchHardHalt (exit coverage, pos 541545776)

  Grind_ReconExitMatchesEntry direct calls without carry reset (FB1-FB4)
  pass shift inline or default 0; they do not read carry GVs.

git diff --stat origin/main...feat/adr151-exitq-k1-h0 (raw):

 docs/architecture/ADR-151-order-purgatory.md |  25 +++-
 docs/architecture/ADR-152-entry-purgatory.md |   8 +-
 ea/fxgrind.mq5                               |   7 +-
 ea/fxgrind_tests.mq5                         |   9 +-
 ea/fxgrind_tests_adr151.mqh                  | 201 +++++++++++++++++++++++--
 ea/fxgrind_tests_adr152.mqh                  |   1 +
 ea/grind_api_counter.mqh                     |   2 +
 ea/grind_config.mqh                          |   4 +-
 ea/grind_engine.mqh                          |   2 +
 ea/grind_state.mqh                           |   1 +
 ea/presets/gbpusd_alt.set                    |   2 +-
 ea/presets/gbpusd_opt.set                    |   2 +-
 prompts/adr151-exitq-k1-h0_response.md       | 237 +++++++++++++++++++++++++++++
 13 files changed, 479 insertions(+), 22 deletions(-)

Line count: 250

## DIAGNOSTIC: EQ-K1c instrumentation

One temporary Print after the first AssertTrue in Test_EQ_K1c_i3_requires_rank_zero_only.
No assertion, setup, or carry-reset change. No cause proposed; operator must
compile, run, and read the log line.

Print statement as inserted:

   Print("EQ-K1c DIAG reason=", reason,
         " shift=", Grind_CarryShiftGetForRecon(5003UL),
         " expected=", Grind_ExitQFormulaTarget(1.10300, 3.0, 0.00001, true),
         " target=", layers[2].exit_target,
         " cover2=", Grind_ReconLayerHasExitCoverage(layers[2]),
         " req0=", Grind_ExitQRequired(0),
         " req1=", Grind_ExitQRequired(1));

Helper visibility: Grind_ExitQFormulaTarget and Grind_ExitQRequired are in
grind_exitq.mqh (included by this file). Grind_CarryShiftGetForRecon and
Grind_ReconLayerHasExitCoverage are in grind_recon.mqh, visible when
fxgrind_tests.mq5 includes grind_engine.mqh before fxgrind_tests_adr151.mqh.
All terms included.

git diff --stat origin/main...feat/adr151-exitq-k1-h0 (raw):

 docs/architecture/ADR-151-order-purgatory.md |  25 +++-
 docs/architecture/ADR-152-entry-purgatory.md |   8 +-
 ea/fxgrind.mq5                               |   7 +-
 ea/fxgrind_tests.mq5                         |   9 +-
 ea/fxgrind_tests_adr151.mqh                  | 208 ++++++++++++++++++--
 ea/fxgrind_tests_adr152.mqh                  |   1 +
 ea/grind_api_counter.mqh                     |   2 +
 ea/grind_config.mqh                          |   4 +-
 ea/grind_engine.mqh                          |   2 +
 ea/grind_state.mqh                           |   1 +
 ea/presets/gbpusd_alt.set                    |   2 +-
 ea/presets/gbpusd_opt.set                    |   2 +-
 prompts/adr151-exitq-k1-h0_response.md       | 284 +++++++++++++++++++++++++++
 13 files changed, 533 insertions(+), 22 deletions(-)

git diff --stat f3acf67..HEAD (this commit only):

 ea/fxgrind_tests_adr151.mqh            |  7 +++++++
 prompts/adr151-exitq-k1-h0_response.md | 34 ++++++++++++++++++++++++++++++++++
 2 files changed, 41 insertions(+)

No cause proposed. No assertion changed.

Line count: PLACEHOLDER
