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

Line count: 133
