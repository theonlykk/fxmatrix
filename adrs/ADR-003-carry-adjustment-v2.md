# ADR-003: Carry Adjustment — Temporal Drift on Multi-Day Positions (v2)

**Date:** 2026-06-08
**Status:** Proposed — Pending Gemini Final Approval
**Repo:** theonlykk/fxmatrix
**Depends on:** ADR-001, ADR-002 v4
**Blocks:** MQL5 EA Implementation
**Supersedes:** ADR-003 v1 (2026-06-08)

---

## Changelog from v1

| Finding | Change |
|---------|--------|
| F1/F4 — Exit anchor cross-ADR inconsistency | Step 6 now explicitly uses entry-time anchor fields (EU_mid_12bars_ago_at_entry / GB_mid_12bars_ago_at_entry) for exit inversion, not live 12-bar-ago prices |
| F2 — Multiple exit tickets | Carry recalculation iterates exit_tickets[] dynamic array. Retry loop for TRADE_RETCODE_TOO_MANY_REQUESTS |
| F7 — Freeze level on exit OrderModify() | Applied to all exit ticket modifications with skip-and-retain |
| F9 — Weekend gap | Documented in negative space |
| F10 — Struct canonical | References LayerStruct.mqh |
| S4 — Calendar days simplification | Documented as V1 simplification |
| M3 — Carry timing | Documented broker server time dependency |

---

## Objective

Define the temporal mechanism by which the EA adjusts open layer
exit targets to account for interest rate carry drift on positions
held overnight or across multiple days. ADR-002 v4 establishes
spatial (price-space) exit targets at layer entry. ADR-003 v2
defines how those targets drift over time via forward price
adjustment, keeping the exit level economically equivalent to
the original signal in carry-adjusted terms.

---

## What This ADR Does

- Defines forward price formula for each currency pair in the pod
- Specifies carry recalculation frequency and trigger
- Defines how entry_spread_adjusted is updated in the Layer struct
- Defines how exit_target is updated via OrderModify() on all
  tickets in exit_tickets[] following each carry recalculation
- Specifies interest rates used and sourcing for V1
- Specifies same-day trade exemption
- Specifies exit inversion anchor for carry-adjusted exit prices

## What This ADR Does NOT Do

- Modify entry_spread_raw — immutable by ADR-002 ruling
- Change spatial inversion logic — owned by ADR-002
- Apply carry to add_next — fixed at entry, not carry-adjusted
- Implement volatility-scaled carry — V2
- Handle weekend swap roll — V2
- Handle Wednesday triple swap explicitly — V2 (documented below)
- Apply carry to signal layer — signal uses spot prices only
- Dynamic rate fetching — V2
- Intra-bar nudging of exit limits — not carry's domain

---

## Governing Rulings

| Decision | Ruling | Source |
|----------|--------|--------|
| ADR-003 scope | Temporal drift only, layered on ADR-002 spatial | Gemini |
| entry_spread_raw | Immutable after fill | Gemini |
| entry_spread_adjusted | Updated daily by carry recalculation | Gemini |
| exit_target | Updated via OrderModify() on all exit_tickets[] | Gemini (R4) |
| Exit inversion anchor | Entry-time anchor fields from Layer struct | Gemini (R4) |
| Same-day trades | No carry adjustment | Gemini |
| Forward price formula | Spot × (1 + r_base × t) / (1 + r_quote × t) | Gemini |
| Interest rates V1 | Hardcoded input parameters, updated manually | Gemini (R4) |
| Carry reference prices | entry_price_eurusd_1h and entry_price_gbpusd_1h | Gemini |
| Q3 — Multiple tranches | All exit_tickets[] modified on recalculation | Gemini |
| Weekend gap | V2 deferral | Gemini (R4) |
| Struct canonical | LayerStruct.mqh — both ADRs reference it | Gemini (R4) |

---

## Section 1 — The Carry Problem

At layer entry, the matrix spread is computed from spot prices.
The entry_spread_raw (e.g. 8.0) corresponds to specific EURUSD
and GBPUSD prices at fill time.

Plugging those same prices into the matrix one week later still
returns 8.0 — because the prices are unchanged in the record.
But those prices are stale. The fair value of each pair has
drifted due to interest rate differentials.

The carry adjustment: take the recorded entry prices, compute
their forward equivalents using the interest rate differential
for the holding period, feed those forward prices into the matrix.
The result is entry_spread_adjusted — the true economic equivalent
of the position as of today.

---

## Section 2 — Forward Price Formula

### 2.1 — Formula

```
Forward(t) = Spot × (1 + r_base × t) / (1 + r_quote × t)
```

Where:
- Spot = entry price at fill time
- r_base = annualised overnight rate for base currency
- r_quote = annualised overnight rate for quote currency
- t = holding period in years (days_held / 365)

V1 simplification: simple interest approximation. For holding
periods of 1–30 days the difference vs continuous compounding
is immaterial. Continuous compounding deferred to V2.

### 2.2 — Applied to EUR/GBP/USD pod

```
EURUSD_fwd = entry_price_eurusd × (1 + r_EUR × t) / (1 + r_USD × t)
GBPUSD_fwd = entry_price_gbpusd × (1 + r_GBP × t) / (1 + r_USD × t)
EURGBP_fwd = EURUSD_fwd / GBPUSD_fwd   // synthetic identity
```

### 2.3 — Interest rates

| Currency | Rate | Benchmark |
|----------|------|-----------|
| USD | r_USD | SOFR (NY Fed) |
| EUR | r_EUR | €STR (ECB) |
| GBP | r_GBP | SONIA (Bank of England) |

```mql5
input double r_USD = 0.0533;  // update weekly in MT5 EA Properties
input double r_EUR = 0.0390;
input double r_GBP = 0.0520;
```

Manual weekly update is acceptable for V1 practice account.
Central bank overnight rates move slowly. Dynamic fetching: V2.

### 2.4 — Holding period

```
t = (broker_server_days_elapsed) / 365.0
```

V1 simplification: uses calendar days. Known limitation: weekend
days are included in the count, but overnight swap is not applied
on weekends (except Wednesday triple swap). This creates a small
systematic overcount on multi-day positions. Error is approximately
2/7 × daily_carry × number_of_weekends_held. Documented; V2 fix.

Broker server time used throughout — never local clock.
Per ARCHITECT.md absolute time constraint.

---

## Section 3 — Carry Recalculation

### 3.1 — Trigger

Once per day when broker server time crosses 17:00 EST.
Implemented via time comparison in OnTick().

```mql5
input string CarryRecalcTime = "17:00";  // broker server time
```

Note: broker server time may differ from 17:00 EST due to DST
transitions. Document and monitor in V1. If broker uses UTC,
adjust to "22:00". V2: query broker DST offset programmatically.

Guard against double-application on same day:
```mql5
datetime g_last_carry_recalc_date = 0;  // global

if TimeDay(TimeCurrent()) != TimeDay(g_last_carry_recalc_date):
    run_carry_recalculation()
    g_last_carry_recalc_date = TimeCurrent()
```

If EA restarts after 17:00 EST but before midnight: the date
guard prevents re-firing on the same calendar day.

### 3.2 — Recalculation sequence for each open layer

For each layer in inventory[]:

```
Step 1: Holding period
  t = (broker_server_date - layer.entry_time) / 86400.0 / 365.0
  if t < 1.0/365.0: skip (same-day trade)

Step 2: Forward prices for USD legs
  EURUSD_fwd = layer.entry_price_eurusd
               × (1 + r_EUR × t) / (1 + r_USD × t)
  GBPUSD_fwd = layer.entry_price_gbpusd
               × (1 + r_GBP × t) / (1 + r_USD × t)

Step 3: Feed forward prices into matrix
  // Reference prices: entry-time 1h-prior (immutable)
  r_EU_fwd = log(EURUSD_fwd / layer.entry_price_eurusd_1h)
  r_GB_fwd = log(GBPUSD_fwd / layer.entry_price_gbpusd_1h)

  USD_fwd = -(r_EU_fwd + r_GB_fwd) / 3
  EUR_fwd =  r_EU_fwd + USD_fwd
  GBP_fwd =  r_GB_fwd + USD_fwd

  new_spread = GBP_fwd - EUR_fwd

Step 4: Update entry_spread_adjusted
  layer.entry_spread_adjusted = new_spread
  // entry_spread_raw never touched

Step 5: Recompute exit_spread_target
  layer.exit_spread_target = layer.entry_spread_adjusted
                             × (1 - ExitFraction)

Step 6: Recompute exit_target using entry-time anchor
  // CRITICAL: use entry-time anchor, not live 12-bar-ago prices
  // anchor_EU = layer.EU_mid_12bars_ago_at_entry  (immutable)
  // anchor_GB = layer.GB_mid_12bars_ago_at_entry  (immutable)

  Apply Section 5 inversion from ADR-002 v4 at T = layer.exit_spread_target
  using anchor_EU and anchor_GB from layer struct.
  Half-spread buffer uses live bid/ask for passivity only.

  new_exit_price = invert(layer.exit_spread_target,
                          layer.EU_mid_12bars_ago_at_entry,
                          layer.GB_mid_12bars_ago_at_entry,
                          current_bid_ask,
                          layer.direction,
                          layer.instrument)

Step 7: Apply freeze level check
  compute distance from new_exit_price to relevant market side
  if distance <= freeze_price:
      log "carry recalc: exit modify skipped — freeze level"
      retain existing exit limits unchanged
      return  // retry on next recalculation cycle

Step 8: Apply IsPassive() check
  if !IsPassive(new_exit_price, layer.direction, symbol):
      log "carry recalc: exit modify skipped — passivity failure"
      retain existing exit limits
      return

Step 9: OrderModify() all exit tickets with retry
  for each ticket in layer.exit_tickets[]:
      attempt OrderModify(ticket, new_exit_price)
      if TRADE_RETCODE_TOO_MANY_REQUESTS:
          Sleep(100ms) and retry once
          if still fails: log WARNING, continue to next ticket
      if any other error: log ERROR, halt pod

  layer.exit_target = new_exit_price
```

### 3.3 — Interaction with ADR-002 intra-bar nudging

ADR-002 Section 8 nudges the FIRST ENTRY LIMIT only (pre-inventory).
It does not touch exit limits.

ADR-003 carry recalculation updates exit limits via OrderModify()
once per day.

No conflict: the two mechanisms operate on different orders.
MT5 is single-threaded in OnTick() — carry recalculation runs
to completion before next tick is processed.

---

## Section 4 — Same-Day Trade Exemption

t < 1/365 (position opened and carry check triggered same day):
no carry adjustment performed. entry_spread_adjusted remains
equal to entry_spread_raw.

The first carry recalculation for a position opened today fires
at 17:00 EST. If t at that moment is < 1/365, skip. The position
will receive its first adjustment at the next day's 17:00 EST.

---

## Section 5 — Negative Space (Explicit Exclusions)

| Exclusion | Rationale |
|-----------|-----------|
| Modifying entry_spread_raw | Immutable |
| Carry on add_next | Fixed at entry |
| Carry on signal layer | Signal uses spot only |
| Dynamic rate fetching | V2 |
| Weekend swap roll | V2 — creates ~2/7 systematic overcount |
| Wednesday triple swap | V2 |
| Volatility-scaled carry | V2 |
| Carry on entry limit orders | Exit targets only |
| Modifying entry_price or entry_time | Immutable |
| Intra-bar exit limit nudging | Not carry's domain |
| Continuous compounding | V2 — simple interest for V1 |
| Broker DST offset handling | V2 — monitor in V1 |
| Friday 17:00 position close circuit | V2 — weekend gap risk accepted |

---

## Section 6 — Sequencing

1. ADR-001 — Accepted ✅
2. DeepSeek audits R1–R4 — Complete ✅
3. ADR-002 v4 — Pending Gemini approval (parallel) ⬅
4. **ADR-003 v2 (this document)** — Pending Gemini approval ⬅
5. Cursor Prompt 1: LayerStruct.mqh + Globals
6. Cursor Prompt 2: Signal + Inversion
7. Cursor Prompt 3: Execution Engine
8. Cursor Prompt 4: Carry + Orchestration
9. MT5 strategy tester validation
10. Practice account deployment
11. Live deployment
