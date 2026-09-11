# ADR-131: EA Archive Events Part 1 (Transport, Send/Fill/Config/Critical)

**Status:** Accepted (2026-09-11; DEINIT flush pending live verification)  
**Date:** 2026-09-11  
**Context:** pipshed ADR-130 (a34795d) exposes POST /api/telemetry/action
with idempotent Postgres shadow tables. Gemini rulings R1-R8 define five tables,
Redis queue transport, session/seq clock, batch flush, and no web-path Postgres.
Evidence mapping ties send_logs to OrderSend, fill_logs to deal adds,
config_events to INIT/DEINIT, ea_events to CRITICAL telemetry. Part 1 covers
transport plus send_log, fill_log, config_event, and CRITICAL ea_event only;
QUARANTINE / STRAY_L0 / CLOSEBY / RECON markers are deferred to Part 2.

## Decision

### Modules

- `ea/grind_archive.mqh` -- state, monotonic clock (R3), JSON helpers,
  field builders, bounded queue (R5). Includes only `grind_comment.mqh`.
  Included by `grind_api_counter.mqh`.
- `ea/grind_archive_flush.mqh` -- batch flush (R6). Included by
  `grind_telemetry.mqh` after `Grind_TelemetryWebPostStatus`.

### Clock and session

`Grind_ArchiveConfigureAt` derives action URL from telemetry push URL,
sets `session_id = <magic>-<anchor_ms>`, and anchors `ea_time_ms` to
`(anchor_ms + tick delta)` using GetTickCount64 (or test tick).

### Queue and flush

- Cap 5000 events; oldest dropped with WARN `TELEMETRY_QUEUE_DROPPED`.
- Flush at most every 2 s (unless forced), batch up to 200 events, one POST.
- 200: remove batch from queue front.
- 400: remove batch and count rejected; emit ERROR `TELEMETRY_BATCH_REJECTED`
  on next flush (poison batch must not retry forever).
- Other statuses: retain batch for retry.
- `Grind_TelemetryWebPostStatus` returns HTTP status; test hooks unchanged plus
  `g_grind_telemetry_test_force_status`.

### Wiring

1. `Grind_OrderSendCounted` -- send_log after OrderSend timing.
2. `Grind_ArchiveRecordFill` before halted return on DEAL_ADD (fills while halted
   are archived but engine still skips fill handling -- R2).
3. `Grind_TelemetryCritical` -- CRITICAL ea_event plus forced flush.
4. `OnInit` -- configure archive, enqueue config_event INIT after CONFIG print.
5. `OnDeinit` -- config_event DEINIT plus forced flush (best effort).
6. `OnTimer` -- archive flush each second; heartbeat and soft-warn only when
   `Grind_TimerTelemetryDue` (fixes static first_run timer drift, item 14).

### JSON rules

- Broker timestamps as `YYYY-MM-DD HH:MM:SS`.
- `Grind_JsonEscape` for strings; non-finite doubles emitted as null.
- Events array built with commas between elements, no trailing comma before `]`.

## Consequences

- **Positive:** Structured archive of sends, fills, config, and CRITICAL events
  without changing heartbeat or scalp_closed payloads.
- **Positive:** Poison batches (HTTP 400) are dropped and counted rather than
  blocking the queue indefinitely.
- **Positive:** Timer stays at 1 s; telemetry interval gating uses tick math.
- **Negative:** WebRequest blocks up to ~200 ms once per 2 s off the tick path.
- **Negative:** DEINIT flush is best effort: WebRequest during deinitialisation
  is not guaranteed to complete. Superseded for DEINIT by ADR-133.
- **Negative:** Part 2 markers (QUARANTINE, STRAY_L0, CLOSEBY, RECON) not yet
  emitted.

## Tests

AR1-AR19 in `ea/fxgrind_tests.mq5` cover clock, JSON, queue cap, flush batching,
throttle, retry, 400 rejection, send_log and fill_log builders, halted fill
recording, magic filter, config fields, critical flush, timer due, and NaN guard.
