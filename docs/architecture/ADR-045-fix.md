# ADR-045 Fix — Broker Window Gate & Global State Persistence

**Status:** Committed

## Problem

Three defects in the original ADR-045 rollover gate:

1. **Mid-day reattach fires carry before midnight.** The old gate blocked only the first minute of hour 0 (`dt.hour == 0 && dt.min < 1`), then allowed rollover reconciliation on the first tick after 00:01 — or on any tick later in the day if `g_last_rollover_date` was still 0 (clean start / reboot). A VPS reattach at e.g. 14:00 would run carry drift immediately, stamp today's date, and block the actual midnight rollover.

2. **`g_last_rollover_date` was `datetime` compared to calendar-day truncation.** The variable stored a midnight-normalized `datetime` but the comparison path was fragile; the gate did not use a native day discriminator.

3. **Variable never serialized to disk.** `g_last_rollover_date` lived only in RAM. On VPS reboot within the same calendar day, the gate reset to 0 and rollover could fire again — double-carry on all parked limits.

## Decision

- **Broker window gate:** `RunDailyRolloverReconciliation()` returns immediately unless `dt.hour == 0`. No state read or write outside the 00:00–00:59 broker window.

- **Day discriminator:** Retype gate to `int g_last_rollover_day_of_year`, compared against `dt.day_of_year`. Fires at most once per calendar day within the window. Month-end and year-end handled natively (Jan 1 resets to day 1).

- **Global state file:** New flat JSON `fxmatrix_global_state_<InstanceID>.json` with key `"last_rollover_day_of_year"`. `LoadGlobalState()` called in `OnInit()` before all `LoadInventoryState()` calls. `SaveGlobalState()` called at end of `SaveAllInventoryState()`.

## Consequences

- Double-carry on VPS reboot eliminated — persisted day-of-year survives terminal restart.
- Mid-day reattach no longer triggers spatial drift — rollover only runs during broker hour 0.
- `fxmatrix_global_state_<InstanceID>.json` established as extension point for Phase 3 globals (daily drawdown counters, correlated exposure limits).
- Per-instrument inventory JSON schema unchanged — global scalars are not duplicated into slot files.

## Negative Space

- Swap math, shift direction, Wednesday multiplier, and OrderModify loops in `RunDailyRolloverReconciliation()` unchanged.
- `SaveInventoryState()` / `LoadInventoryState()` bodies unchanged.
- No new `.mqh` file; no nested JSON structure in global state file.
