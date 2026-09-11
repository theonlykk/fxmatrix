# ADR-133: Deferred DEINIT Recording via GlobalVariables

**Status:** Proposed  
**Date:** 2026-09-11  
**Context:** Live evidence on 2026-09-11 19:37Z: after recompile, config_events
count doubled (12 to 24) with INIT rows only. ADR-131 OnDeinit enqueued a DEINIT
config_event and called `Grind_ArchiveFlush(true)`, but WebRequest does not
complete while MT5 unloads the EA. DEINIT events never reached Postgres.

## Decision

### OnDeinit (synchronous GlobalVariable write)

Replace DEINIT enqueue and force-flush with:

`Grind_ArchiveRecordDeinit(InpMagic, reason, TimeCurrent(), g_grind_archive_anchor_ms)`

GlobalVariable names (per magic):

- `GRIND_DEINIT_REASON_<magic>`
- `GRIND_DEINIT_TIME_<magic>`
- `GRIND_DEINIT_ANCHOR_<magic>`

Reason, broker datetime, and anchor_ms are stored as double (exact below 2^53).
EventKillTimer, MagicLockRelease, and verbose Print unchanged.

### OnInit (deferred DEINIT before INIT)

Immediately before the existing INIT enqueue, if
`Grind_ArchiveReadPendingDeinit` returns true:

1. Build DEINIT config_event with `Grind_ArchiveConfigFields("DEINIT", prev_reason,
   ...same geometry args as INIT...)` plus
   `Grind_ArchiveDeinitExtraFields(prev_time, InpMagic, prev_anchor)`.
2. Enqueue config_event (DEINIT row precedes INIT of the new session).
3. `Grind_ArchiveClearPendingDeinit(InpMagic)` always (even when archive disabled).

Extra fields (stored in pipshed `inputs` jsonb):

- `deinit_time_broker`: broker timestamp via `Grind_ArchiveBrokerTime`, or null
- `prev_session_id`: `<magic>-<anchor_ms>`, or null

Geometry columns on the DEINIT row reflect the NEW session inputs; the ended
session is identified by `prev_session_id`.

### Interpretation

An INIT with no preceding DEINIT (after the first attach) means the prior session
ended without OnDeinit: crash, kill, or VPS power loss.

## Consequences

- **Positive:** DEINIT reliably arrives at the next attach when OnDeinit ran.
- **Positive:** No WebRequest during EA unload for config DEINIT.
- **Positive:** `deinit_reason` remains a real column; prev session metadata in
  `inputs`.
- **Negative:** DEINIT geometry reflects the new session, not the ended one
  (prev_session_id carries session identity).
- **Negative:** Unclean stops leave no DEINIT until the next clean deinit chain.
- **Negative:** ADR-131 OnDeinit flush path removed (superseded).

## Tests

DI1-DI5 in `ea/fxgrind_tests.mq5`:

- DI1: Record and read round-trip (reason, broker time, anchor_ms).
- DI2: Clear removes GlobalVariables; read returns false.
- DI3: Absent magic returns false without touching outputs.
- DI4: ExtraFields JSON for deinit_time_broker and prev_session_id.
- DI5: Anchor_ms exact round trip through double GlobalVariable.
