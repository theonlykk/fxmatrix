This message has a line count at the bottom

# ADR-153 implementation response

Prompt read at commit `da7c790` (`prompts/adr153_implementation.md`, footer `Line count: 247`).

## Commits on origin

| # | role | hash |
|---|---|---|
| 1 | tests + stubs | `bca6a56` |
| 2 | implementation | `93c3bf7` |
| 3 | ADR status + this file | `ceb8c31` |

(Push updates `origin/feat/adr153-geometry-independence` to the same hashes.)

## Diff stat

```
 git diff --stat origin/main...feat/adr153-geometry-independence
 docs/architecture/ADR-153-geometry-independence.md |   5 +-
 ea/fxgrind.mq5                                     |  11 +-
 ea/fxgrind_tests.mq5                               | 117 ++++++++++++++++++++-
 ea/grind_engine.mqh                                |   4 +-
 ea/grind_pure.mqh                                  |  27 ++++-
 prompts/adr153_implementation_response.md          |  56 ++++++++++
 6 files changed, 206 insertions(+), 14 deletions(-)
```

## Self-review greps (final tree)

```
 git grep GRIND_ADD_WIDTH_MULTIPLE ea/
 (exit 1, no output)

 git grep ValidateAddWidthRelationship ea/
 (exit 1, no output)

 git grep OrderGetDouble(ORDER_PRICE_OPEN) ea/grind_engine.mqh
 ea/grind_engine.mqh:358:   return OrderGetDouble(ORDER_PRICE_OPEN);
 ea/grind_engine.mqh:1606:         const double live_price = OrderGetDouble(ORDER_PRICE_OPEN);
```

`Grind_TryRecenterOppositeL0` uses `Grind_OrderGetPriceOpen(opposite_side.l0_pending_ticket)` only.

## Expected failures at commit 1 (`bca6a56`)

Required pattern from the implementation prompt:

- T17b, T17c, T17d, T17f, T17g, T17i (expect true; stubs return false)
- T17a, T17e, T17h (expect false; stubs return false — may pass if `AssertFalse` accepts a false return)
- G1, G4 (`Grind_TestOnInitGeometryCheck` stub does not call ratio/deadband validators yet)
- PO4b, PO4c (recentre still uses raw `OrderGetDouble` until commit 2)

May pass at commit 1: G2, G3, G5, PO4, PO4d.

If PO4b or PO4c pass at commit 1, stop — harness not exercising recentre correctly.

Line count: 52
