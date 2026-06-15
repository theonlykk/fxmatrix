# ADR-014 — Always-On Two-Sided Quoting Engine

**Date:** 2026-06-15
**Status:** PHASE 1 IMPLEMENTED
**Branch:** feature/adr-014-market-making
**Authors:** Claude (Lead Engineer), Gemini (Staff Architect)

## Context
FXMatrix was built as a threshold-triggered stat-arb engine. The intended
operating mode is continuous two-sided market making across all three
currency pairs simultaneously, always maintaining a minimum of 1 bid and
1 offer per instrument.

## Architecture
For each instrument (EURUSD, GBPUSD, EURGBP), always maintain:
- One bid: FairValue - BaseThreshold (or add-next when inventory open)
- One offer: FairValue + BaseThreshold (cancelled on first fill, replaced
  by exit limits as inventory accumulates)

On every bar close:
1. Cancel all stale flat quotes (both bid and offer)
2. Resubmit at new FairValue ± BaseThreshold
3. ADR-013 clamp applies: if calculated price worse than market, join book

On first fill (Layer 0):
- Cancel opposing quote immediately (handled in Phase 2 / HandleEntryFill)
- Arm exit limit, place add-next (existing HandleEntryFill logic)

On pod flat:
- Resume two-way quoting immediately (handled in Phase 3 / HandleExitFill)

## State Globals
Replace g_pending_entry_X (single ticket) with:
- g_pending_bid_X: tracks bid-side pending (initial quote or add-next)
- g_pending_offer_X: tracks offer-side pending (initial quote, cancelled on fill)

## Invariant
total_working_orders >= 6 at all times when no circuit breaker active
(1 bid + 1 offer per instrument when flat;
 1 bid + N offers per instrument when N layers open)

## Related
- ADR-013: gap-aware entry clamp (applies to quote placement)
- ADR-011: LDAK volatility gate (applies to add-next sizing)
- ADR-008: Phase 3 grid (applies to layer depth)
