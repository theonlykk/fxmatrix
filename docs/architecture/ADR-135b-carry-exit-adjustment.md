# ADR-135b: Carry Exit Adjustment (Act)

**Status:** Proposed  
**Date:** 2026-09-13  
**Context:** ADR-135a (observe phase) has been live since 2026-09-11. Daily
CARRY_SNAPSHOT events record swap fields, eligible layer counts, mult_today /
mult_tomorrow, and POSITION_SWAP sums per side. Three live findings from 135a
motivate this act phase:

1. **Clock.** Gate and snapshot use `TimeTradeServer()`, not `TimeCurrent()`.
2. **Eligibility.** Pre-close window counts all open position-backed layers
   (`Grind_CarryOpenLayers`), not midnight-straddled subsets.
3. **Economics.** Exit limits are fixed at fill time; overnight swap accrues on
   the position but the resting exit price is unchanged, so a 5-pip exit on a
   layer that paid 1.5 pips nets 3.5. This ADR moves exit limits to preserve
   financial equivalence.

Wednesday x3 convention was settled empirically from consecutive CARRY_SNAPSHOT
accrued-swap rows on 2026-09-16; no hardcoded multiplier.

## Decision

### Scope (D2)

Adjust resting **exit** limits only when anchored to a position basis:

| State | Order            | Anchor | Action    |
|-------|------------------|--------|-----------|
| Long  | exit sell limit  | basis  | ADJUST    |
| Long  | add buy limit    | basis  | NO CHANGE |
| Short | exit buy limit   | basis  | ADJUST    |
| Short | add sell limit   | basis  | NO CHANGE |
| Flat  | L0 buy/sell      | mid    | NEVER     |

### When (D1)

Once per broker day inside the existing 23:50-23:59 window
(`Grind_CarryGateInWindow`), 16:50-16:59 New York -- dead minutes before the
daily close.

### Amount (D3)

Each pass recomputes from scratch (idempotent):

```
accrued_pips = ledger_pips + pending_pips

ledger_pips  = POSITION_SWAP converted account ccy -> quote pips
pending_pips = swap_points * mult_tomorrow / pip_div   (not mult_today)
```

Ledger conversion:

```
price_delta = swap_account * tick_size / (tick_value * volume)
ledger_pips = price_delta / pip_size
```

Guard every divisor; skip layer on failure.

### Direction (D4)

```
new_exit = formula_exit - direction * accrued_pips * pip_size
```

direction +1 long, -1 short; cost negative, credit positive.

### Sign guard (D6)

Before clamp: skip modify if adjustment would place exit on wrong side of
entry (long exit at/below entry, short exit at/above entry).

### Clamp (D5)

Shift toward market clamped passive by `max(point, stops*point, freeze*point)`.
Long exits use sell-limit clamp (at/above ask + distance); short exits use
buy-limit clamp (at/below bid - distance). Place at clamp; flag `clamped` in
telemetry.

### Accrued carry store (F2, 2026-09-19)

Overnight carry accrues on every open position-backed layer, including held
layers with no resting exit order (`exit_order_ticket == 0`). Accrual is stored
per position in `GRIND_CARRY_ACCRUED_<position_ticket>` (price units, signed).
Only the carry pass writes this GV; the exit queue reads it via
`Grind_ExitQFormulaTarget` when placing exits. It is cleared on scalp close
only (not on cancel or rank demotion).

Intended exit price is `raw_formula + accrued`. When an order exists, the pass
also modifies it and stores clamp delta in `GRIND_CARRY_SHIFT_<ticket>` as
`actual - intended` (not `actual - raw`). I6 expects
`raw_formula + accrued + shift == actual`.

### I6 tolerance (D7)

Store cumulative applied shift per position ticket in GV
`GRIND_CARRY_SHIFT_<position_ticket>` (signed, price units).

`Grind_ReconExitMatchesEntry` accepts
`|exit - (expected + accrued + shift)| <= 2*point` where `accrued` comes from
`GRIND_CARRY_ACCRUED_<position_ticket>` when present.

Bound stored shift: if `|shift|` exceeds age-derived nightly maximum, treat GV
as corrupt, delete it, and I6 halts on mismatch.

### Gate (D9)

`Grind_CarryGateDue` is a pure predicate (no write).
`Grind_CarryGateMarkDone` persists day-of-year only after pass completion.
Snapshot emits once per window; gate marks done when exit pass finishes.

### Session guard (D10)

Before any modify, require SymbolInfoTick success, bid > 0, ask >= bid,
`TimeTradeServer() - tick.time < 120 s`, and SYMBOL_TRADE_MODE_FULL.
Carry module keeps a local last-tick timestamp; does not call
`Grind_FeedStaleAfterTick`.

### Chunking (D11)

Process at most 2 layers per timer call; no `Sleep()`. Window close with
unprocessed layers emits `CARRY_PASS_INCOMPLETE` and does not mark gate done.

### Retry (D12)

Failed modify enqueues position ticket for same-day retry (max 3 attempts).

### Telemetry (D13)

`CARRY_EXIT_SHIFT` per layer: position_ticket, side, layer_index,
accrued_ledger_pips, pending_pips, accrued_pips_total, old_price, new_price,
clamped, sign_guard_skipped, retcode, points_native_pips.

`CARRY_PASS_SUMMARY` / `CARRY_PASS_INCOMPLETE` once per pass with eligible,
shifted, clamped, skipped, failed counts.

### Module

`ea/grind_carry.mqh` extended; wired from `fxgrind.mq5` OnTimer after heartbeat.
I6 shift wired through `grind_recon.mqh`.

## Consequences

- I6 is carry-aware and depends on a per-position GlobalVariable; corrupt or
  stale GVs fail closed (delete + halt).
- Add-side limits and L0 mid-anchored quotes are deliberately unchanged.
- Pass is idempotent because shift amount recomputes from POSITION_SWAP ledger
  plus tonight pending term each day.
- Gate no longer burns the day on partial failure; incomplete passes retry while
  the window is open.

## Tests

CX1-CX14 in `ea/fxgrind_tests.mq5` (38 assertions):

- CX1 direction maths (D4)
- CX2 ledger conversion
- CX3 pending uses mult_tomorrow
- CX4 sign guard
- CX5 long exit clamp
- CX6 I6 shift tolerance
- CX7 GV lifecycle
- CX8 corrupt GV bound
- CX9 gate-after-completion
- CX10 session guard
- CX11 feed tick unchanged (no Grind_FeedStaleAfterTick mutation)
- CX12 chunking (2 per call)
- CX13 incomplete pass
- CX14 telemetry JSON shape

Suite target: 894/894 (856 baseline + 38).

F2-1 through F2-7 in `ea/fxgrind_tests_adr151.mqh`: held-layer accrual,
carry-aware queue placement, clamp with two-store arithmetic, resting regression,
accrual survives cancel, accrual cleared on scalp close.
