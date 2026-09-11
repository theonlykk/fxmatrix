# ADR-132: EA Archive Events Part 2 (State-Machine Markers + Slippage Fix)

**Status:** Proposed  
**Date:** 2026-09-11  
**Context:** ADR-131 (Part 1) ships transport, send_log, fill_log, config_event,
and CRITICAL ea_event via `Grind_TelemetryCritical`. Live archive on 2026-09-11
showed send_logs and fill_logs flowing; OUT_BY fill_logs carried meaningless
slippage_pips (e.g. 7.9 = entry-to-exit distance, not limit slippage). Several
state-machine transitions still emit Print-only diagnostics: quarantine enter/
release/halt, stray L0 cancel/clear, stray cancel on ENT fill, derived CloseBy
pairs (verbose-gated Print), and CloseBy symbol mismatch (halt with no reason
or CRITICAL telemetry).

## Decision

### Grind_ArchiveMarker

Add to `ea/grind_archive.mqh`:

`void Grind_ArchiveMarker(level, code, reason, ticket, detail_json)` enqueues
an `ea_event` built by `Grind_ArchiveEaEventFields`. No flush (callers that
need immediate delivery use existing `Grind_TelemetryCritical`).

### Markers (ea_event, enqueued next to unchanged Prints)

| Where | code | level | reason | ticket | detail |
|---|---|---|---|---|---|
| QuarantineStep enter | QUARANTINE_ENTER | WARN | invariant reason | 0 | none |
| QuarantineStep release | QUARANTINE_RELEASE | INFO | quarantine reason | 0 | `{"ms":<ms>,"checks":<n>}` |
| QuarantineStep halt | QUARANTINE_HALT | CRITICAL | reason | 0 | `{"ms":<ms>,"checks":<n>}` |
| ReconcileStrayL0 cancel | STRAY_L0_CANCEL | WARN | "" | stray ticket | `{"side":"L\|S","depth":<n>}` |
| ReconcileStrayL0 cleared | STRAY_L0_CLEARED_GONE | INFO | "" | ticket | `{"side":"L\|S"}` |
| ENT branch stray cancel | STRAY_L0_CANCEL_ON_FILL | WARN | "" | stray ticket | `{"side":"L\|S","filled_order":<order>}` |
| DeriveCloseByQueueFromBook (every pair) | RECON_DERIVED_CLOSEBY | INFO | slot | 0 | `{"side":"L\|S","layer":<i>,"position":<ent>,"position_by":<ext>}` |

Each marker is emitted immediately before its Print (and before cancel sends
where applicable). QUARANTINE_HALT relies on the subsequent OnTick
`Grind_TelemetryCritical(INVARIANT_FAIL)` for flush.

### CloseBy symbol mismatch

Before `g_grind_halted = true`, set `g_grind_halt_reason = "CLOSEBY_SYMBOL_MISMATCH"`.
After halt, call `Grind_TelemetryCritical` with code `CLOSEBY_SYMBOL_MISMATCH`
and detail `ticket1=<t1> ticket2=<t2>`.

### Slippage fix

`Grind_ArchiveFillLogFields`: `slippage_pips` is null unless `entry_type` is
exactly `"IN"` (in addition to existing BUY/SELL and order_price_open checks).
OUT_BY CloseBy fills no longer emit misleading slippage.

### Includes

`ea/grind_quarantine.mqh` includes `grind_archive.mqh` (no cycle: archive
includes only `grind_comment.mqh`).

## Consequences

- **Positive:** Operators can correlate quarantine, stray L0, recon-derived
  CloseBy, and symbol-mismatch halts in the ea_events archive table.
- **Positive:** OUT_BY fill_logs no longer carry meaningless slippage_pips.
- **Positive:** Derived CloseBy pairs are archived even when verbose is off.
- **Negative:** More ea_events enqueued per session (bounded by queue cap).
- **Negative:** CloseBy mismatch now force-flushes via CRITICAL (intended).

## Tests

PM1-PM7 in `ea/fxgrind_tests.mq5`:

- PM1: quarantine enter, release, re-enter, halt markers (4 events).
- PM2: STRAY_L0_CANCEL on reconcile with selectable order.
- PM3: STRAY_L0_CLEARED_GONE when order/position gone.
- PM4: STRAY_L0_CANCEL_ON_FILL after ENT fill (fill_log + marker).
- PM5: RECON_DERIVED_CLOSEBY with verbose false.
- PM6: slippage null for OUT_BY; -0.1 for IN BUY.
- PM7: symbol mismatch sets halted and CRITICAL CLOSEBY_SYMBOL_MISMATCH flush.
