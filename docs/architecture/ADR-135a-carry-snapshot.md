# ADR-135a: Daily Carry Snapshot + Rollover Day Gate (Observe Only)

**Status:** Proposed  
**Date:** 2026-09-11  
**Context:** FTMO EURUSD spec shows swap type "In points", swap long -8.76,
swap short +0.37, weekly multipliers Mon1 Tue1 Wed3 Thu1 Fri1. A layer held
overnight accrues swap but exit limits are not adjusted, so economics drift.
EURUSD long -8.76 points = -0.876 pips/night, about -6.13 pips over a week
against a 7-pip exit target. ADR-135b will adjust exits; 135a records the
landscape and proves the once-per-broker-day gate without modifying orders.

Operator ruling: the pass runs in the dead minutes BEFORE the daily/weekly
close (23:50-23:59 broker), not after broker midnight. A clamped exit at a
gapped open can lock in a loss; a missed fill in the dead minutes costs only
a little profit.

## Decision

### Module

`ea/grind_carry.mqh` (includes `grind_archive.mqh`, `grind_state.mqh`,
`grind_pure.mqh`). Included by `grind_telemetry.mqh` after archive flush.

### Swap multiplier

This build does not expose `SYMBOL_SWAP_MULTIPLIER_*`, so
`Grind_CarrySwapMultiplier(day_of_week)` derives the weekly table from
`SYMBOL_SWAP_ROLLOVER3DAYS`: multiplier 3 on that weekday, 1 on Mon-Fri
elsewhere, 0 on Saturday and Sunday (no broker charge row). Test override
`g_grind_carry_test_rollover_*` supplies the rollover day in CS4.

### Shift and eligibility

- `Grind_CarryShiftPips`: signed swap_points * multiplier / pip_div (10 for
  3/5-digit, 1 otherwise).
- `Grind_CarryEligibleLayers`: layers with position opened strictly before
  broker midnight (test hook injects open times).

### Day gate (GlobalVariable)

- Window: broker hour 23, minute >= 50.
- `Grind_CarryGateDue(magic, now)`: once per broker day-of-year inside window;
  persists `GRIND_CARRY_DAY_<magic>`.
- GV read/write only inside the window (except test Reset).

### Snapshot

`Grind_CarryEmitSnapshot` enqueues `CARRY_SNAPSHOT` ea_event with symbol swap
fields, shift pips, eligible layer counts, trade_mode_full,
mult_today/mult_tomorrow (to settle x3 convention empirically), and accrued
POSITION_SWAP sums per side. No flush, no OrderSend.

### Wiring (fxgrind.mq5 only)

- OnInit after INIT config_event: one snapshot (no gate).
- OnTimer inside `Grind_TimerTelemetryDue`, after heartbeat: gate + snapshot.

## Consequences

- **Positive:** Observe-only record of swap landscape for all pairs before
  135b exit adjustment.
- **Positive:** Gate proven in production before 135b modifies live orders.
- **Positive:** Pre-close window avoids gapped-open clamp risk from V2's
  post-midnight approach.
- **Negative:** Pre-close timing means swap is not yet charged; 135b must
  shift from quoted points plus cumulative shift, not POSITION_SWAP alone.
- **Negative:** Snapshots enqueue ea_events only; no broker requests beyond
  existing symbol/position reads during snapshot build.
- **Negative:** 512-ticket sent-price map and carry gate are independent
  concerns (ADR-134 vs 135a).

## Tests

CS1-CS8 in `ea/fxgrind_tests.mq5`: gate once per day, outside window,
GV persistence, swap multiplier, shift pips, eligible layers, emit snapshot,
mult_today/tomorrow fields.
