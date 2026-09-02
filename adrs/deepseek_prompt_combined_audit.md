# DeepSeek R1 Adversarial Audit — Combined ADR-002 v3 + ADR-003

**TO:** DeepSeek (Red Team Adversarial Audit)
**FROM:** Claude (Lead Engineer)
**RE:** FX Matrix EA — Final Combined Audit (Round 4)

---

## What is already locked — do not re-audit

The following have been ruled by Gemini (Staff Architect) and are
not open for discussion:

- **FTMO account type:** Hedging by default. Multi-ticket LIFO valid.
- **Basis risk:** Zero, analytically proven. S = −r_EG.
- **Entry threshold:** Fixed 0.0008 log-return units for V1.
- **Layer spacing:** H4 ATR in price space (pips) for add_next only.
- **Exit targets:** Matrix-derived via ExitFraction, NOT ATR-fixed.
- **ExitFraction:** Default 0.70, tunable parameter.
- **Bid/ask convention:** Mid for signal, correct side for execution.
- **Historical anchor Cases 1–2:** EU_mid_12bars_ago / GB_mid_12bars_ago.
- **Cases 3–6 fixed leg:** g_r_XX_signal from M5 close, not live tick.
- **OrderModify():** Replaces cancel-and-replace throughout.
- **NudgeThreshold:** 0.5 pips confirmed.
- **Partial fill trigger:** First fill triggers next layer placement.
- **All outstanding exit tickets per layer:** All modified on carry
  recalculation, not just the most recent.
- **Interest rates V1:** Hardcoded input parameters. No dynamic fetch.
- **Carry reference prices:** entry_price_eurusd_1h and
  entry_price_gbpusd_1h from fill time — immutable, not today's prices.
- **entry_spread_raw:** Immutable after fill. Never modified.
- **MTF confluence:** Deferred to V2.

---

## What you are auditing

Two locked ADRs bundled together. Read both in full before auditing.
The primary audit target is the **interaction between them** —
specifically state management conflicts between the tick-level
OrderModify() nudging (ADR-002 Section 8) and the daily 17:00 EST
carry recalculation (ADR-003 Section 3).

---

**[INSERT ADR-002 v3 FULL TEXT HERE]**

---

**[INSERT ADR-003 FULL TEXT HERE]**

---

## Audit scope

### Priority 1 — ADR-002 / ADR-003 interaction (primary focus)

This is what Gemini has specifically asked you to hunt for.

**1a. State conflict between tick nudge and daily carry recalculation**

ADR-002 Section 8 nudges exit limit prices via OrderModify() on
every tick when delta > 0.5 pips. ADR-003 Section 3 also calls
OrderModify() on the same exit_ticket once per day at 17:00 EST.

- Can these two OrderModify() calls conflict? MT5 is single-threaded
  in OnTick() — does this guarantee safety, or are there edge cases
  (e.g. carry recalculation firing mid-tick processing)?
- After the daily carry recalculation updates exit_target in the
  Layer struct, does the tick-level nudge correctly pick up the new
  baseline, or could it revert the carry adjustment on the next tick?
- If the carry recalculation fires at exactly 17:00 EST and a fill
  event also arrives at the same tick, what is the processing order
  and is the inventory state guaranteed to be consistent?

**1b. Multiple exit tickets per layer during carry recalculation**

A single layer may have multiple outstanding exit limit orders (one
per partial fill tranche — ADR-002 Section 3.3). ADR-003 Section 3.2
Step 7 specifies that all outstanding exit tickets for a layer are
modified to the new exit_target on carry recalculation.

- Is iterating through all exit tickets for a layer and calling
  OrderModify() on each one within a single OnTick() call safe on
  FTMO MT5? Are there request throttling limits that could cause
  some modifications to fail silently?
- If one OrderModify() in the loop fails (e.g. TRADE_RETCODE_TOO_MANY_REQUESTS),
  the layer's exit tickets will be at inconsistent prices. What is
  the correct recovery logic?

**1c. Carry recalculation timing vs. broker server time**

ADR-003 triggers carry recalculation when broker server time crosses
17:00 EST. MT5's TimeCurrent() returns broker server time.

- Is broker server time guaranteed to be stable at 17:00 EST, or
  can DST transitions cause the trigger to fire at 16:00 or 18:00?
- If the EA restarts (crash, VPS reboot) after 17:00 EST but before
  midnight, will it re-fire the carry recalculation on restart?
  What prevents double-application of carry on the same day?

### Priority 2 — ADR-002 v3 specific changes

**2a. Cases 1 & 2 historical anchor fix**

The anchor is now EG_history = EU_mid_12bars_ago / GB_mid_12bars_ago.
This requires storing EU_mid_12bars_ago and GB_mid_12bars_ago as
global state on each M5 bar close.

- Is there any scenario where these stored values could be stale or
  incorrect — e.g. if CopyClose() returns fewer than 13 bars, or if
  the EA restarts mid-bar?
- The master inversion formula states EG_t = EG_0 × exp(-T), where
  EG_0 is the historical anchor. Verify that for Cases 1 and 2,
  with T negative (sell signal), exp(-T) > 1, so EG_target >
  EG_history. For a sell limit this means the target price is above
  the historical anchor. Is this directionally correct given that
  EUR is strongest and EURGBP should be sold?

**2b. Structural uniformity across all six cases**

All six cases now follow the same three-step structure:
  1. Historical anchor (mid, M5-bar-close)
  2. Inversion (exp formula)
  3. Passivity buffer (live bid/ask)

Verify that the sign of exp(-T) is correct for each case given the
sign convention of T (negative for sell signals, positive for buy
signals). Flag any case where the sign could produce a limit price
on the wrong side of the historical anchor.

### Priority 3 — ADR-003 carry math

**3a. Forward price formula correctness**

```
Forward(t) = Spot × (1 + r_base × t) / (1 + r_quote × t)
```

- Is this the correct simple interest approximation for FX forward
  pricing? Or should it use continuous compounding:
  Forward(t) = Spot × exp((r_base - r_quote) × t)?
- For holding periods of 1–30 days (V1 practice account), is the
  difference between simple and continuous compounding material?

**3b. Log return reconstruction in Step 3**

ADR-003 Section 3.2 Step 3 computes:

```
r_EU_fwd = log(EURUSD_fwd / EURUSD_ref)
r_GB_fwd = log(GBPUSD_fwd / GBPUSD_ref)
```

Where EURUSD_ref = entry_price_eurusd_1h (the 1h-prior price at
fill time, immutable).

- Is this the correct reference for reconstructing the log return?
  The original signal log return was log(EURUSD_now / EURUSD_1h_ago).
  The carry recalculation substitutes EURUSD_fwd for EURUSD_now and
  EURUSD_ref (= EURUSD_1h_ago at fill time) for the denominator.
  Is the denominator correctly anchored?
- If a position has been held for 7 days, the forward price
  EURUSD_fwd is computed from the original entry spot. The log
  return r_EU_fwd = log(EURUSD_fwd / EURUSD_ref) is then a pure
  function of the interest rate differential and holding period,
  with no new market information. Is this the intended behaviour?

**3c. Same-day exemption boundary**

ADR-003 exempts same-day trades from carry adjustment. The first
carry recalculation fires at 17:00 EST on the day of entry if the
position is still open. This covers the first overnight period.

- For a position opened at 16:55 EST, the first carry recalculation
  fires 5 minutes later. t = 5/(60×24×365) ≈ 0.0000095 years.
  The carry adjustment is essentially zero. Is this correct, or
  should there be a minimum holding period (e.g. t > 1 day) before
  carry adjustment activates?

### The existential question

Given the full combined specification of ADR-002 v3 and ADR-003:
is there any structural flaw — in the carry math, the state
management, or the interaction between the two ADRs — that would
cause the EA to systematically corrupt its inventory state, apply
carry incorrectly, or place exit limit orders at wrong prices?

---

## Output requested

For each finding: area, severity (critical / moderate / low),
recommended resolution. Explicitly state if a finding touches a
locked ruling — do not reopen locked items, just note the conflict.

Flag anything that requires an architectural change before Cursor
implementation begins.

