# ADR-134: Reliable Limit Price on Fill Logs

**Status:** Proposed  
**Date:** 2026-09-11  
**Context:** Live fill_logs on 2026-09-11 showed IN deal 518265331 (18:23Z) with
order_price_open 0.85741, but IN deals 518301215 (19:55Z) and 518305646
(20:05Z) had 0.0. Slippage was null and a 0.1-pip-worse fill went unmeasured.
`Grind_ArchiveRecordFill` used history-only lookup; when DEAL_ADD arrives before
the filled order is in history, lookup fails and 0.0 was serialized as
"0.00000".

## Decision

### Sent-price map (grind_archive.mqh)

Bounded ring map (512 entries): ticket -> last price sent via OrderSend.

- `Grind_ArchiveRememberOrderPrice`: ignore ticket 0 or price <= 0; overwrite
  existing ticket; append if room; else evict oldest slot (ring index).
- `Grind_ArchiveLookupSentPrice`: stored price or 0.
- `Grind_ArchiveNoteSendResult`: on ok and retcode 10008/10009 only; PENDING
  remembers res.order + req.price; MODIFY remembers req.order + req.price.

### Resolve order (grind_engine.mqh)

`Grind_ArchiveResolveOrderPrice(order_ticket)`:

1. Return 0 if ticket is 0.
2. Unless order or deal test mode: HistoryOrderSelect + ORDER_PRICE_OPEN; if > 0
   return.
3. OrderSelect + ORDER_PRICE_OPEN; if > 0 return.
4. `Grind_ArchiveLookupSentPrice(order_ticket)`.

### Wiring

- `Grind_OrderSendCounted`: call `Grind_ArchiveNoteSendResult` before send_log
  enqueue when archive enabled.
- `Grind_ArchiveRecordFill`: use ResolveOrderPrice for live and test modes.
- `Grind_ArchiveFillLogFields`: order_price_open is JSON null when <= 0 (never
  "0.00000"). Existing slippage guard already requires order_price_open > 0.

## Consequences

- **Positive:** Fills recorded before history sync still get limit price from
  the sent-price map; slippage computed when IN and price known.
- **Positive:** null instead of misleading 0.0 in archive and Postgres.
- **Negative:** Orders placed before the current session rely on history/live
  order pool only (no map entry).
- **Negative:** Map is bounded at 512; oldest sent prices evicted under churn.
- **Negative:** Map holds requested price (resting limit for this passive MM),
  not broker-reported open after partial fills.

## Tests

FP1-FP7 in `ea/fxgrind_tests.mq5`:

- FP1: remember and lookup round trip.
- FP2: overwrite same ticket.
- FP3: absent ticket returns 0.
- FP4: ring eviction at max=3.
- FP5: NoteSendResult for PENDING/MODIFY; failed modify ignored.
- FP6: FillLogFields null order_price_open and slippage when price 0.
- FP7: deal test uses sent map when history unavailable.
