This message has a line count at the bottom

# DEEPSEEK R1 -- RED-TEAM ADR-160 (ALL-DAY FLOATING-LOSS ENTRY GATE)

You are auditing an IMPLEMENTATION before it merges. It is tested (suite
1766/1766; the stub commit failed exactly as predicted, 16 named
assertions). Find what tests cannot see.

**The system:** an MQL5 passive limit-order FX market maker (no stops, no
market orders), many instances on one FTMO account sharing terminal
global variables (GVs). FTMO's daily limit is measured from the day-start
BALANCE, and equity includes open MTM, so open losses carried overnight
count against the new day in full. ADR-158 (merged) has an 80% breaker
that latches for the day and cancels resting entries, and a pre-midnight
halt (from 23:00 Prague, floating loss >= 50% of the allowance).

**ADR-160** (attached at branch `adr160-gate` `6c57830`) adds an ALL-DAY
gate: no NEW entries while floating loss (balance - equity) >= 50% of the
daily allowance; clear only when it recovers to 40% (hysteresis). It is
not latched and cancels nothing: exits, the carry pass and ejection must
keep working so the stack can unwind. The instance holding the MAE
reporter lease archives gate on/off transitions and counts gated seconds
into a per-day GV for the daily snapshot. **Do not re-open the design**
(ruled: Gemini G1-G5, ADR-160 sections 8-9). Attack the implementation.

## GIVENS -- verify each, cite the line

- G1. `Grind_BreakerFloatGate` (`grind_pure.mqh:508`) returns false when
  the allowance is <= 0; engages at >= 50%; once gated, stays while > 40%.
- G2. `Grind_BreakerBlocksEntries` (`grind_engine.mqh:840`) ORs
  `g_grind_breaker_gated` (`:824`) with the trip and pre-midnight flags,
  all behind `g_grind_breaker_enabled`.
- G3. The gate is updated at the END of `Grind_BreakerOnTick` (`:944`,
  update at `:1011`), after the pre-midnight lines; `Grind_BreakerOnTick`
  runs in `OnTick` (`fxgrind.mq5:317`) before the engine and before the
  halted and quarantined returns.
- G4. The five entry sites (`grind_engine.mqh:1037`, `:1263`, `:1472`,
  `:1576`, `:1687`) only `return` when `Grind_EntriesBlocked()` is true;
  nothing cancels resting entries because of the gate.
- G5. `Grind_GateAccumulate` (`grind_snapshot.mqh:24`) runs once per
  telemetry interval (`fxgrind.mq5:279`), adds only when this instance is
  the reporter and gated, caps each addition at twice the interval
  (`Grind_GateAddSeconds`, `grind_pure.mqh:519`), and resets its clock
  when the lease is lost.

## THREATS -- verdict each: HOLDS / BREAKS / NEEDS-FIX

- **T-1 Unwind paths stay open.** Confirm that NOTHING in exits, the exit
  queue, the carry pass, manual ejection or automatic ejection (ADR-157,
  including any `engine_blocked` or similar argument to its validation)
  consults `Grind_EntriesBlocked` or `Grind_BreakerBlocksEntries`. If any
  does, the gate would freeze the unwind it exists to allow.
- **T-2 Growth while gated.** The gate blocks NEW placement only. Count,
  from source, how many entry orders a side can have resting at once
  (adds, L0, anything held back by the exit queue or purgatory), so the
  worst-case layers a side can still gain while gated is known exactly.
- **T-3 Stale or skipped evaluation.** The gate is evaluated only on
  ticks, and only when `Grind_BreakerOnTick` reaches its end: it returns
  early when the breaker is disabled and on a no-basis day-key tick. Can
  the gate be left stuck ON (blocking entries while floating has
  recovered) or stuck OFF? Consider a quiet symbol, the weekend, a
  restart (the global starts false), and an FTMO day change (the trip
  and pre-midnight flags reset there; the gate deliberately does not).
- **T-4 Floating definition.** `balance - equity`: correct sign? Does it
  include open swaps and commissions as FTMO's equity does? Any case
  (deposit, credit) where it misstates the loss?
- **T-5 Gated-seconds accuracy.** The reporter uses ITS OWN
  `g_grind_breaker_gated`. What if the reporter instance's breaker is
  disabled, or its symbol is quiet so its gate state lags the others, or
  the lease moves mid-day (two holders briefly)? Bound the error.
- **T-6 Transition events.** Emitted only by the reporter, on its own
  flips. Can the archive miss a gated episode entirely, or record ON
  without OFF (lease change, restart, day change)? Is that acceptable for
  a reporting-only stream?
- **T-7 Interactions.** Gate with the 80% trip, D9 adoption (ADR-159), the
  pre-midnight halt, and the API entry stop: any ordering in which one
  path clears another's block, or double-cancels?

## RULES

- Cite `file:line` for every claim; otherwise mark it INFERRED.
- For each BREAKS / NEEDS-FIX give the SMALLEST fix. No redesign.
- Stay inside ADR-160's implementation and the code it touches.

## OUTPUT FORMAT (exact headings)

```
GIVENS CHECK     -- G1..G5: CONFIRMED / WRONG (with line)
T-1 .. T-7       -- verdict, evidence, smallest fix
PREMISE VERDICT  -- safe to merge? one paragraph
TEST GAPS        -- tests missing, with expected values
```

Line count: 94
