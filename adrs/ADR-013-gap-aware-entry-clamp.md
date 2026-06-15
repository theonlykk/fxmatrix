# ADR-013 — Gap-Aware Entry Price Clamp

**Date:** 2026-06-15
**Status:** IMPLEMENTED
**Authors:** Claude (Lead Engineer), Gemini (Staff Architect)

## Context
During live forward testing, repeated passivity failures were observed on
EURUSD and GBPUSD BUY entries during fast-moving Asian session signals.
Root cause: InvertSpreadToPrice() computes entry as anchor_12bars_ago *
exp(T). During a fast move, the market overshoots the theoretical entry,
leaving the computed price above current market. IsPassive() correctly
rejects this as it would cross the spread.

## The Opportunity
If the market has already moved past the theoretical entry, it is offering
a better entry than the signal required. Rejecting it wastes a valid signal
and leaves the EA deaf during fast moves.

## Fix: Gap-Aware Entry Price Clamp in PlaceEntryLimit()
After InvertSpreadToPrice() returns the theoretical price, clamp to the
safe side of the current spread before OrderSend():

BUY:  entry_price = NormalizeDouble(MathMin(computed, current_bid - min_dist), digits)
SELL: entry_price = NormalizeDouble(MathMax(computed, current_ask + min_dist), digits)

Where min_dist = SYMBOL_TRADE_STOPS_LEVEL * SYMBOL_POINT (dynamic).
NormalizeDouble prevents floating-point anomalies causing ERR_TRADE_INVALID_PRICE.
On FTMO ECN stops_level = 0 — joins top of book passively.

## Key Properties
- InvertSpreadToPrice() remains a pure math function — unchanged
- Clamp lives exclusively in PlaceEntryLimit() — separation of concerns
- IsPassive() check retained after clamp as final pre-flight guard
- Price improvement delta logged for forward testing analysis
- Mirrors gap-aware logic already approved for PlaceNextEntryLimit() (Phase 3)

## Related
- ADR-004: Bid/offer invariant (passivity architecture)
- ADR-008: Phase 3 gap-aware pricing in PlaceNextEntryLimit()
