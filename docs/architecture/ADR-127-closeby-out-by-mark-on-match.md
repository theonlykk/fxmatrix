# ADR-127: Mark CloseBy OUT_BY deals processed only on layer match

Status: Proposed (pending operator verification)
Date: 2026-09-11

## Context
Grind_OnTradeTransactionEngine offers every DEAL_ADD to the long handler and
then the short handler. The OUT_BY branch of Grind_HandleSideDealFill marked
the deal processed before checking whether a layer on that side owned it, and
the processed set is shared by both sides. Every short-side CloseBy was
therefore consumed by the long pass: no scalp_closed event, and the short
layer was never removed. Introduced in 1b9e255 (2026-09-07); the V2 engine
used separate per-side processed sets.

## Decision
Mark an OUT_BY deal processed only inside the loop, once a layer on the
current side is found whose position_ticket equals the deal's position_id and
whose exit_position_ticket is set.

## Alternatives considered
1. Separate long and short processed sets, as in V2. Same effect, larger change
   to shared state and test resets.
2. Route OUT_BY deals by side in the dispatcher. Adds a side-derivation rule
   that can itself be wrong; the ownership check already exists.

## Consequences
- The non-owning OUT_BY leg of each CloseBy (the exit position's deal) is never
  marked. Harmless: it matches no layer on either side.
- Repeat delivery of the owning deal is still rejected by the processed set.
- Not addressed here: stale-state duplicate L0 and duplicate exit after a
  blocking send; the missing-exit race; P&L read from one OUT_BY deal only;
  close_time labelled Z while carrying broker time.

## Evidence
- 2026-09-10: all 13 SHORT scalps absent from live emission (backfilled).
- 2026-09-11 03:11Z: four phantom short layers on EURUSD_OPT, EURUSD_ALT and
  GBPUSD_ALT, each matching a short CloseBy with no emitted event.

## Tests
CB1-CB4 in fxgrind_tests.mq5 drive CloseBy pairs through
Grind_OnTradeTransactionEngine. Before the fix: CB1, CB3, CB4 fail; CB2 passes.
After: all pass.
