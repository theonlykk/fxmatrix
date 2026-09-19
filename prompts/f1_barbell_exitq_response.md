This message has a line count at the bottom

# F1: Barbell exit queue -- response

Branch: feat/f1-barbell-exitq from origin/main.
K=1, H=0 unchanged; ranking unchanged.

## Commits

1. 4bc5f18 -- F1-1..F1-7, EQ4 rewrite, depth at engine/recon call sites,
   barbell predicates in grind_exitq.mqh
2. (ADR) -- ADR-151 barbell text

Note: predicate body and call sites landed in one commit so the tree compiles;
tests fail on prefix-only behaviour before barbell logic is present.

## Predicates (grind_exitq.mqh)

bool Grind_ExitQRequired(const int rank, const int depth)
{
   if(rank < Grind_ExitQK())
      return true;
   return (depth > 0 && rank == depth - 1);
}

bool Grind_ExitQAllowed(const int rank, const int depth)
{
   if(rank < Grind_ExitQK() + GRIND_EXITQ_H)
      return true;
   return (depth > 0 && rank == depth - 1);
}

At H=0, Required and Allowed are identical.

## Engine vs recon (coverage agreement)

Engine trim/release (grind_engine.mqh:1814, 1819):

  if(!Grind_ExitQAllowed(ranks[i], n) && ... exit_order ...)
  if(!Grind_ExitQRequired(ranks[i], n))

Recon I3 (grind_recon.mqh:493, 520):

  if(Grind_ExitQRequired(long_rank, long_count) && !HasExitCoverage(...))
  if(Grind_ExitQRequired(short_rank, short_count) && !HasExitCoverage(...))

Early rebuild loop (grind_recon.mqh:1036, 1053):

  Grind_ExitQRequired(rank, long_count) / short_count

Same predicate and same depth (side layer count) as ManageSide local n.
Explicit agreement on which ranks require coverage.

## All call sites changed

| File | Line | depth argument |
|------|------|----------------|
| ea/grind_engine.mqh | 1814 | n |
| ea/grind_engine.mqh | 1819 | n |
| ea/grind_recon.mqh | 493 | long_count |
| ea/grind_recon.mqh | 520 | short_count |
| ea/grind_recon.mqh | 1036 | long_count |
| ea/grind_recon.mqh | 1053 | short_count |
| ea/fxgrind_tests_adr151.mqh | EQ4, EQ5, F1-1, F1-2 | literal depths |

No other production call sites. Grind_ExitQAllowed is not used in recon.

## Expected failures on prefix-only (hypothetical commit 1 without barbell)

| Test | Failure |
|------|---------|
| F1-1 / EQ4 | d2 r1, d5 r4 required false |
| F1-2 | PASS (depth guard already safe on prefix) |
| F1-3 | one exit not two; rank4 bare |
| F1-4 | may differ if depth-2 never placed mid exit |
| F1-5 | high exit cancelled or never placed |
| F1-6 | I3 fail on rank 4 coverage or pass wrongly |
| F1-7 | PASS |

## Self-review

- No K/H constant changes. No Grind_ExitQRanks changes.
- EQ4 rewritten, not deleted.

Deleted-assert grep (EQ4 assertion text changed; no tests removed):

  git diff origin/main -- ea/fxgrind_tests.mq5 ea/fxgrind_tests_adr151.mqh | grep "^-" | grep -i "Assert\|void Test_"
  (shows EQ4 old asserts only)

git diff --stat origin/main...feat/f1-barbell-exitq:

 docs/architecture/ADR-151-order-purgatory.md |  32 ++--
 ea/fxgrind_tests.mq5                         |   7 +
 ea/fxgrind_tests_adr151.mqh                  | 217 +++++++++++++++++++++++++--
 ea/grind_engine.mqh                          |   4 +-
 ea/grind_exitq.mqh                           |  12 +-
 ea/grind_recon.mqh                           |   8 +-
 prompts/f1_barbell_exitq_response.md         | 100 ++++++++++++
 7 files changed, 345 insertions(+), 35 deletions(-)

Line count: 100

## STAGE 1: total predicates

Commit after 5ab91b9: validity guard on both predicates only. No test changes.

bool Grind_ExitQRequired(const int rank, const int depth)
{
   if(rank < 0 || depth <= 0)
      return false;
   if(rank < Grind_ExitQK())
      return true;
   return (rank == depth - 1);
}

bool Grind_ExitQAllowed(const int rank, const int depth)
{
   if(rank < 0 || depth <= 0)
      return false;
   if(rank < Grind_ExitQK() + GRIND_EXITQ_H)
      return true;
   return (rank == depth - 1);
}

Redundant depth > 0 on the second clause removed; top guard covers it.

This commit: ea/grind_exitq.mqh and this response section only. No test file
changed.

Expectation (inference, not measured): F1-2 and any other failure that
depended on Required/Allowed(0,0) or negative depth being true should
resolve. The bulk of the prior 28 failures (EQ-K1*, MQ*, stale cancel class
expecting prefix-only one exit or highest-rank exit cancelled) likely remain
until stage 2 re-derives assertions. Operator re-run required to confirm
count.

Line count: 137

## STAGE 2: re-derived assertions

Commit: test files and this section only. Cause for all 25: barbell keeps
exit on rank depth-1; short ladders made the demoted layer the highest rank.

Hand derivations use exit_pips=3, point=0.00001, pip=10 points so
Grind_ExitPrice adds 0.00030 on long exits. Long rank: lower entry = rank 0.
Array idx0 = highest entry = rank depth-1 on long fixtures.

| Assertion | (a)/(b) | Reason |
|-----------|---------|--------|
| Q10 layer1 trimmed | (a) | Depth 3: 1.247 r0, 1.248 r1, 1.249 r2. layers[1] is rank 2 = depth-1; exit 7001 must survive. Renamed Q10 rank2 exit survives. |
| SB4 old exit trimmed | (a) | Short depth 2: 1.26000 r1, 1.26050 r0. layers[0] is rank 1 = depth-1; ticket 3001 survives. Renamed SB4 old exit survives. |
| EQ-K1a one resting | (a) | Depth 3 barbell: rank 0 (idx2) + rank 2 (idx0) resting; count 2 not 1. Renamed EQ-K1a two resting. |
| EQ-K1a rank2 bare | (a) | idx0 entry 1.10500 is rank 2 = depth-1; must have exit. Renamed EQ-K1a rank2 exit. |
| EQ-K1c pass held | (b) | I3 now requires rank 0 and rank depth-1. Five-layer scratch: exits on rank 0 (1.10100) and rank 4 (1.10500) only; ranks 1-3 bare. |
| MQ1 cancel thrice | (a) | Only ranks 1 and 2 trimmed at depth 4; two removes not three. Renamed MQ1 cancel twice. |
| MQ1 rank3 bare | (a) | idx0 is rank 3 = depth-1; exit must remain. Renamed MQ1 rank4 exit (idx0 highest entry). |
| MQ3 cancel first | (a) | One remove on rank 1 only; rank 3 (idx0) survives. Renamed MQ3 cancel middle; count 2 with rank 2 trim. |
| MQ3 release after trim | (a) | Unchanged: one place on rank 0 after trim. |
| MQ3 nearest exit | (a) | Unchanged: layers[3] rank 0 has exit. |
| MQ7 k1 cancels | (a) | K=1 depth 5: one middle trim; far rank 4 (idx0) survives. Renamed count 1; MQ7 k1 far exit. |
| HC1 cleared | (a) | Depth 4 idx0 rank 3 protected. Renamed HC1 far exit survives ticket 6101. |
| HC3 cleared | (b) | Five layers: idx3 entry 1.10200 rank 1 middle. Exit only on idx3; hold-cancel clears idx3 not idx0. |
| HC3 exit pos | (b) | Same fixture: exit_position_ticket 7101 on idx3 after deal on 6104. |
| HC3 closeby | (b) | Same fixture: closeby queue 1 for idx3 fill. |
| HC4 cleared | (b) | Same 5-layer ladder, no deal: idx3 rank 1 bare without exit pos. |
| HC5 cleared | (a) | Wrong-side deal does not clear barbell far rank; idx0 keeps 6101. Renamed HC5 far exit survives. |
| RI5 ok | (b) | Rebuild I3 needs rank 0 and rank 2 exits at depth 3. Added EXT order L\|0 at 1.25030 = 1.25000+3p. |
| RI5 layer found | (b) | Same ticket set; layer_index 0 row gets exit_target 1.25030. |
| STALE-1 demoted bare | (b) | Depth 3: ultra 1.252 r2 idx0, far 1.250 r1 idx1, near 1.249 r0 idx2. Middle idx1 cancelled. |
| STALE-1 far offset cleared | (b) | Hold-cancel on middle pos_far clears shift GV; ultra barbell exit unrelated. |
| STALE-1 far release cleared | (b) | Same cancel clears release GV on pos_far. |
| STALE-1 replace placed | (b) | Places: 1 far alone, +2 on triple manage (near+ultra), +1 quiet replace = 4 cumulative. |
| STALE-1 replace raw | (b) | raw_formula_far = 1.25000+0.00030 = 1.25030; quiet market replace uses raw. |
| STALE-1 far replace no offset | (b) | Replace on solo far after removes; no shift GV on pos_far. |

STALE-1 ladder after triple manage (before removes):

  idx0 1.25200 pos_ultra rank 2
  idx1 1.25000 pos_far   rank 1  (demoted bare; offset cleared)
  idx2 1.24900 pos_near  rank 0  (clamp near_shift = clamp_expected_near - 1.24930)

Removes idx2 then idx0 leave solo far 1.25000 for replace phase.

HC/RI5 checked separately: HC hold-cancel middle vs RI5 recon coverage; same
barbell cause, different fixtures (HC (b) middle, RI5 (b) extra EXT ticket).

None left failing for a different cause.

git diff --stat origin/main...feat/f1-barbell-exitq (after this commit; run locally):

 docs/architecture/ADR-151-order-purgatory.md |  32 ++--
 ea/fxgrind_tests.mq5                         |  11 +-
 ea/fxgrind_tests_adr151.mqh                  | 280 +++++++++++++++++++++------
 ea/grind_engine.mqh                          |   4 +-
 ea/grind_exitq.mqh                           |  12 +-
 ea/grind_recon.mqh                           |   8 +-
 prompts/f1_barbell_exitq_response.md         | 200 ++++++++++++++++++++

Deleted-void-Test grep (must be empty):

  git diff origin/main -- ea/fxgrind_tests.mq5 ea/fxgrind_tests_adr151.mqh | grep "^-" | grep -i "void Test_"

Line count: 203

## FIX: fixture array sizes

Commit: ea/fxgrind_tests_adr151.mqh and this section only. No assertion or
production changes.

RI5: GrindReconTicket tickets[6]; (was [5]). Six count++ after declaration
(indices 0..5), count=6 at RebuildBookFromTickets call.

Audit of stage-2 tests (3401c53) for fixed-size fixture arrays:

| Test | Array | Declared | Written | Status |
|------|-------|----------|---------|--------|
| Q10 | (none fixed) | ArrayResize layers 3 | 3 | OK |
| SB4 | (none fixed) | ArrayResize layers | 2 | OK |
| EQ-K1a | (none fixed) | ArrayResize layers 3 | 3 | OK |
| EQ-K1c | layers | 5 | 5 idx 0..4 | OK |
| EQ-K1c | long_ranks | 5 | 5 | OK |
| MQ1 | (none fixed) | ArrayResize layers 4 | 4 | OK |
| MQ3 | (none fixed) | ArrayResize layers 4 | 4 | OK |
| MQ7 | (none fixed) | ArrayResize layers 5 via fixture | 5 | OK |
| HC1 | (none fixed) | ArrayResize layers 4 | 4 | OK |
| HC3 | (none fixed) | ArrayResize layers 5 | 5 | OK |
| HC4 | (none fixed) | ArrayResize layers 5 | 5 | OK |
| HC5 | (none fixed) | ArrayResize layers 4 | 4 | OK |
| RI5 | tickets | 6 | 6 | FIXED |
| STALE-1 | layers scratch | 1 | 1 at I6 check | OK |
| STALE-1 | long_ranks | 1 | 1 | OK |
| STALE-1 | g_grind_long.layers | ArrayResize 1/2/3 | max 3 | OK |

No other undersized fixed arrays in touched tests.

git diff --stat origin/main...feat/f1-barbell-exitq:

 docs/architecture/ADR-151-order-purgatory.md |  32 +--
 ea/fxgrind_tests.mq5                         |  11 +-
 ea/fxgrind_tests_adr151.mqh                  | 348 ++++++++++++++++++++++-----
 ea/grind_engine.mqh                          |   4 +-
 ea/grind_exitq.mqh                           |  16 +-
 ea/grind_recon.mqh                           |   8 +-
 prompts/f1_barbell_exitq_response.md         | 238 ++++++++++++++++++

 7 files changed, 576 insertions(+), 81 deletions(-)

This commit: no assertion text changed; no production file changed.

Line count: 250

## DIAGNOSTIC: HC3 and MQ3

Commit: two Print blocks in ea/fxgrind_tests_adr151.mqh and this section.
No assertion, fixture, or production change.

HC3 (between ManageSide and first assertion):

   Grind_ExitQManageSide(g_grind_long, true, 22260101UL, "OPT", 0.01, 3.0);

   double hc3_entries[]; int hc3_idx[]; int hc3_ranks[];
   const int hc3_n = ArraySize(g_grind_long.layers);
   ArrayResize(hc3_entries, hc3_n); ArrayResize(hc3_idx, hc3_n);
   for(int z = 0; z < hc3_n; z++) {
      hc3_entries[z] = g_grind_long.layers[z].entry_price;
      hc3_idx[z] = g_grind_long.layers[z].layer_index;
   }
   Grind_ExitQRanks(hc3_entries, hc3_idx, hc3_n, true, hc3_ranks);
   Print("HC3 DIAG n=", hc3_n,
         " r0=", (hc3_n > 0 ? IntegerToString(hc3_ranks[0]) : "N/A"),
         " r1=", (hc3_n > 1 ? IntegerToString(hc3_ranks[1]) : "N/A"),
         " r2=", (hc3_n > 2 ? IntegerToString(hc3_ranks[2]) : "N/A"),
         " r3=", (hc3_n > 3 ? IntegerToString(hc3_ranks[3]) : "N/A"),
         " r4=", (hc3_n > 4 ? IntegerToString(hc3_ranks[4]) : "N/A"),
         " req3=", (hc3_n > 3 ? (Grind_ExitQRequired(hc3_ranks[3], hc3_n) ? "true" : "false") : "N/A"),
         " allow3=", (hc3_n > 3 ? (Grind_ExitQAllowed(hc3_ranks[3], hc3_n) ? "true" : "false") : "N/A"),
         " l3_order=", (hc3_n > 3 ? IntegerToString((long)g_grind_long.layers[3].exit_order_ticket) : "N/A"),
         " l3_exitpos=", (hc3_n > 3 ? IntegerToString((long)g_grind_long.layers[3].exit_position_ticket) : "N/A"),
         " removes=", g_grind_order_test_remove_calls,
         " places=", g_grind_order_test_place_calls);

   AssertTrue("HC3 cleared", g_grind_long.layers[3].exit_order_ticket == 0);

MQ3 (between ManageSide and first assertion):

   Grind_ExitQManageSide(g_grind_long, true, 22260101UL, "OPT", 0.01, 3.0);

   double mq3_entries[]; int mq3_idx[]; int mq3_ranks[];
   const int mq3_n = ArraySize(g_grind_long.layers);
   ArrayResize(mq3_entries, mq3_n); ArrayResize(mq3_idx, mq3_n);
   for(int z = 0; z < mq3_n; z++) {
      mq3_entries[z] = g_grind_long.layers[z].entry_price;
      mq3_idx[z] = g_grind_long.layers[z].layer_index;
   }
   Grind_ExitQRanks(mq3_entries, mq3_idx, mq3_n, true, mq3_ranks);
   Print("MQ3 DIAG n=", mq3_n,
         " r0=", (mq3_n > 0 ? IntegerToString(mq3_ranks[0]) : "N/A"),
         " r1=", (mq3_n > 1 ? IntegerToString(mq3_ranks[1]) : "N/A"),
         " r2=", (mq3_n > 2 ? IntegerToString(mq3_ranks[2]) : "N/A"),
         " r3=", (mq3_n > 3 ? IntegerToString(mq3_ranks[3]) : "N/A"),
         " req1=", (mq3_n > 1 ? (Grind_ExitQRequired(mq3_ranks[1], mq3_n) ? "true" : "false") : "N/A"),
         " allow1=", (mq3_n > 1 ? (Grind_ExitQAllowed(mq3_ranks[1], mq3_n) ? "true" : "false") : "N/A"),
         " l1_order=", (mq3_n > 1 ? IntegerToString((long)g_grind_long.layers[1].exit_order_ticket) : "N/A"),
         " req2=", (mq3_n > 2 ? (Grind_ExitQRequired(mq3_ranks[2], mq3_n) ? "true" : "false") : "N/A"),
         " allow2=", (mq3_n > 2 ? (Grind_ExitQAllowed(mq3_ranks[2], mq3_n) ? "true" : "false") : "N/A"),
         " l2_order=", (mq3_n > 2 ? IntegerToString((long)g_grind_long.layers[2].exit_order_ticket) : "N/A"),
         " req3=", (mq3_n > 3 ? (Grind_ExitQRequired(mq3_ranks[3], mq3_n) ? "true" : "false") : "N/A"),
         " allow3=", (mq3_n > 3 ? (Grind_ExitQAllowed(mq3_ranks[3], mq3_n) ? "true" : "false") : "N/A"),
         " l3_order=", (mq3_n > 3 ? IntegerToString((long)g_grind_long.layers[3].exit_order_ticket) : "N/A"),
         " removes=", g_grind_order_test_remove_calls,
         " places=", g_grind_order_test_place_calls);

   AssertTrue("MQ3 cancel middle", g_grind_order_test_remove_calls == 2);

Bounds: HC3 fixture n=5; all hc3_ranks[k] and layers[k] reads guarded with
hc3_n > k. MQ3 fixture n=4; ranks r0..r3 guarded; no r4 term. mq3_* names
distinct from hc3_*.

No cause stated here; operator run required to read Experts log lines HC3 DIAG
and MQ3 DIAG.

git diff --stat origin/main...feat/f1-barbell-exitq:

 docs/architecture/ADR-151-order-purgatory.md |  32 ++--
 ea/fxgrind_tests.mq5                         |  11 +-
 ea/fxgrind_tests_adr151.mqh                  | 394 +++++++++++++++++++++++----
 ea/grind_engine.mqh                          |   4 +-
 ea/grind_exitq.mqh                           |  16 +-
 ea/grind_recon.mqh                           |   8 +-
 prompts/f1_barbell_exitq_response.md         | 324 ++++++++++++++++++++++

 7 files changed, 708 insertions(+), 81 deletions(-)

This commit: no assertion, fixture, or production file changed.

Line count: 336

## FIX: HC3 and MQ3 fixtures

Measured cause: engine correct; stage 2 fixture errors. Diagnostics removed.
Assertions unchanged. No production changes.

HC3: removed Grind_OrderTestUpsert(6104) only. Five-layer ladder, deal on
6104->7101, PositionTestAdd(5004/7101), and three assertions unchanged.
Filled exit must not also live in order store.

HC4: stage 2 added the same upsert with no deal. Rejected cancel plus
SelectOurOrder(6104) blocks HoldCancelLayer clear (same branch, not filled
contradiction). Removed upsert; layer still carries ticket 6104 on idx3.

MQ3: const mq3_exit_far/mid2/mid1; layer and store bound per ticket.
Three upserts for far and both middles; idx3 rank 0 starts bare for release.

MQ3 ladder (depth 4, long ranks by entry):

  idx  entry    rank  ticket var        assertion target
  0    1.10500  3     mq3_exit_far      MQ3 far exit survives (not in fail set)
  1    1.10400  2     mq3_exit_mid2     MQ3 cancel middle
  2    1.10300  1     mq3_exit_mid1     MQ3 cancel middle
  3    1.10200  0     (placed)          MQ3 nearest exit; MQ3 release after trim

git diff --stat origin/main...feat/f1-barbell-exitq:

 docs/architecture/ADR-151-order-purgatory.md |  32 ++--
 ea/fxgrind_tests.mq5                         |  11 +-
 ea/fxgrind_tests_adr151.mqh                  | 360 +++++++++++++++++++++-----
 ea/grind_engine.mqh                          |   4 +-
 ea/grind_exitq.mqh                           |  16 +-
 ea/grind_recon.mqh                           |   8 +-
 prompts/f1_barbell_exitq_response.md         | 368 +++++++++++++++++++++++++++

 7 files changed, 714 insertions(+), 85 deletions(-)

This commit: fixtures and doc only; no assertion or production change.

Line count: 376
