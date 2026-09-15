# ADR-145: Heartbeat Book Test Isolation

## Status

Accepted -- 2026-09-14.

## Context

The MQL5 suite had one persistent failure: R1 (`R1 not reconstructed L01`).
`HANDOFF_2026-09-14b` and `01_BOOT.md` recorded that this meant "the
broker-comment lookup fell back to the reconstructed form". That diagnosis
was wrong. No such fallback exists.

`Grind_HeartbeatLayersJson` initialises `comment_json` to the literal `"null"`
and overwrites it only when `Grind_HeartbeatPositionComment` returns true,
emitting the stored string verbatim. There is no reconstruct-from-layer_index
path. `GrindCommentBuild` has exactly three production call sites, all order
placement in `grind_engine.mqh`. A lookup failure yields `"comment":null`,
never `"comment":"GRIND|OPT|L|L01|ENT"`.

**Real mechanism:** `Grind_TelemetryHeartbeatJson` returns `core + detail + book`.
The `detail` half honours `g_grind_heartbeat_test_active`. The `book` half is
built by `Grind_HeartbeatBuildBookJson` and honours a different flag,
`g_grind_book_test_active`. When that flag is false,
`Grind_BookBuildPositionsJson` and `Grind_BookBuildOrdersJson` enumerate the
real `PositionsTotal()` / `OrdersTotal()`, filtered by exact magic match.

`Test_R1_LayerCommentRawFromBroker` opens with `Grind_TestResetLayerDetailState()`,
which calls `Grind_BookTestReset()` and sets `g_grind_book_test_active = false`.
R1 then asserts via `AssertNotContains` that `GRIND|OPT|L|L01|ENT` is absent
from the whole heartbeat string -- including that live book section.

**Empirical confirmation:** Pipshed status at `generated_at 2026-09-14T22:29:16Z`
showed GBPUSD_OPT, magic 22260101, position ticket 541050954 with comment
`GRIND|OPT|L|L01|ENT`, opened 06:18:17 broker time. The desktop terminal running
the suite is logged into the same account (1514582088), so `PositionsTotal()`
returned the VPS fleet book. R1 failed consistently while that position was
open. Earlier flakiness at `fc46d2f` was the same mechanism sampled when no
L01 layer happened to be open -- correlated with the GV isolation fix, not
caused by it. The apparent determinism was a stable live book, not a
deterministic test.

**Scope:** About twenty tests assert against the full string from
`Grind_TestSampleHeartbeatJson()`. Only the seven `Test_B*` sites ever set
`g_grind_book_test_active = true`. Every other heartbeat assertion ran with
the live fleet book as part of its haystack. R1 was the collision;
`Test_D5_NoTicketNumbersInJson` (asserting ticket numbers 555001-555005 absent
from the whole string) was the next candidate.

This is a test-isolation defect, not a production one. Nothing in
`grind_heartbeat_detail.mqh` misbehaves.

## Decision

After `Grind_BookTestReset()` inside `Grind_TestResetLayerDetailState`, set
`g_grind_book_test_active = true`. `Grind_BookTestReset()` already empties
both harness arrays and zeroes both counts, so the harness is active and empty.
The book section then emits deterministic empty arrays instead of falling
through to the terminal.

The seven `Test_B*` sites set the flag true themselves and populate via
`Grind_BookTestUpsertPosition` / `Grind_BookTestUpsertOrder`; idempotent.

Add BI1-BI3 tests:
- BI1: shared reset leaves book harness active (fails before fix, passes after).
- BI2: shared reset leaves book empty (passes at both commits).
- BI3: `Grind_HeartbeatOrderComment(0, ...)` returns false with order harness
  inactive (passes at both commits).

## Consequences

Commit 2 is the first fully green suite (989/989). R1 passes unchanged:
the book arrays are empty so `GRIND|OPT|L|L01|ENT` cannot appear; the injected
layer still emits raw `L03` and R1's other assertions are untouched.

**Deliberate residual:** `Grind_HeartbeatOrderComment` has the same fall-through
when `g_grind_order_test_active` is false -- it calls `OrderSelect(ticket)`
against the live terminal. It is currently unreachable because of the
`if(ticket == 0) return false;` guard and because heartbeat tests leave
pending tickets at zero. Do NOT set `g_grind_order_test_active = true` in the
shared reset: that flag gates real branches in `grind_engine.mqh` and
`grind_carry.mqh`. BI3 pins the zero-ticket guard.

`Grind_HeartbeatMeasureWorstCasePayload` saves and restores
`g_grind_book_test_active` around itself and continues to work unchanged.
