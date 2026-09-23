This message has a line count at the bottom

# DEEPSEEK R1 -- RED-TEAM ADR-157 (AUTOMATIC PASSIVE EJECTION TRIGGER)

You are auditing an IMPLEMENTATION before it merges. It is tested (suite
1601/1601; 21 new-test failures predicted and seen on a stub). Find what
tests cannot see.

**The system:** an MQL5 passive limit-order FX market maker (no stops, no
market orders). Each side holds up to `InpMaxLayers` layers. ADR-155
(merged) can move a side's DEEPEST layer's resting exit to the best passive
price (ask + min passive distance for a long exit, bid - min for a short)
and write an offset so invariant I6 (`raw + accrued + eject_offset + shift`
== resting exit, 2-point tolerance; a plain failure HALTS) still holds.

**ADR-157** makes the EA fire that move itself, every tick, per side, when
ALL hold: at cap; STABLE (over the last 2W minutes the extreme -- lowest bid
for a long, highest ask for a short -- was set at least W minutes ago; most
recent tie wins; M1 bars dated at their CLOSE); spread <= k x mean spread of
the last 60 M1 bars; not already ejected, OR the new target is worse than
the resting one by >= min passive distance (trail an orphaned exit);
healthy; `InpAutoEject` true (default false). It calls the SAME accept path
as the operator command (`Grind_EjectAcceptLayer`). **Do not re-open the
trigger design** (operator decision: act, then tune W and k from the demo).
Attack the implementation.

Attached at branch `adr157-auto-eject` `c44ce0e`: `fxgrind.mq5`,
`grind_engine.mqh`, `grind_pure.mqh`, `grind_carry.mqh`,
`grind_exitq.mqh`, ADR-157, ADR-155.

## GIVENS -- verify each, cite the line

- G1. `Grind_EjectAcceptLayer` (`grind_engine.mqh:379`) is the former
  command accept branch, unchanged except a `source` field in telemetry;
  the command poll (`:433`) calls it with "command".
- G2. `Grind_AutoEjectTrySide` (`:515`) checks enabled/blocked, cap,
  deepest, validation, stability, spread, then the orphan test, then calls
  the accept path with "auto" (`:595`).
- G3. `Grind_AutoEjectOnTick` (`:599`) builds the series from
  `CopyRates(PERIOD_M1)`, dating bars at open + 60 s, long = bar low, short
  = bar high + bar spread; and is called after the command poll, before the
  halt return (`fxgrind.mq5:308`).
- G4. Pure helpers (`grind_pure.mqh:331-385`) implement most-recent-tie
  extreme, stability, spread gate and the orphan test as ADR-157 states.

## THREATS -- verdict each: HOLDS / BREAKS / NEEDS-FIX

- **T-1 Retry storm (Claude, suspected BREAKS).** If the accept path's
  modify FAILS (freeze level, invalid price, a persistent broker refusal),
  nothing changes: still capped, stable, spread fine, not ejected. The
  trigger retries on EVERY tick -- each an order request plus an
  `EJECT_REFUSED` event. Quantify requests per minute on a busy tick
  stream against the shared daily API budget (soft warn 1,800) and FTMO
  hyperactivity. Smallest fix? (Candidate: in-memory per-side backoff of W
  minutes after a MODIFY_FAILED.)
- **T-2 Stale `exit_target` (Claude, suspected NEEDS-FIX).** The carry pass
  modifies resting exits but never updates `layer.exit_target` in memory
  (no `exit_target` reference in `grind_carry.mqh`). The orphan test
  compares against `layer.exit_target`. After a carry move, can it wrongly
  re-eject or wrongly hold? Smallest fix? (Candidate: compare against the
  order's actual price, `Grind_OrderGetPriceOpen(exit_order_ticket)`.)
- **T-3 Bar series correctness.** Is `CopyRates` output oldest-first as
  used (no `ArraySetAsSeries`)? Can the forming bar ever count as stable?
  Behaviour right after a weekend/market-open gap, or when fewer than 2W
  bars exist?
- **T-4 Spread units.** Current spread = (ask - bid) / `_Point`; baseline
  = `MqlRates.spread` (points). Same units on 5-digit and 3-digit (JPY)
  symbols?
- **T-5 Per-tick cost.** `CopyRates` for 60 + 2W bars runs every tick while
  enabled, even with no side capped. Any risk beyond CPU (e.g. history
  not yet loaded returning fewer bars and silently disabling)?
- **T-6 Same-tick interactions.** Command poll then auto trigger in one
  tick; the carry pass at 23:50; the exit queue's own re-pricing
  afterwards. Can any combination double-modify or leave I6 inconsistent?
- **T-7 Both sides / blocked flags.** Both sides firing on one tick; a side
  becoming blocked (quarantine) mid-sequence.
- **T-8 Restart.** The trigger is stateless. After a restart with an
  ejected, unfilled layer, does the orphan test behave correctly (it reads
  the reconstructed state)?

## RULES

- Cite `file:line` for every claim; otherwise mark it INFERRED.
- For each BREAKS / NEEDS-FIX give the SMALLEST fix. No redesign.
- Stay inside ADR-157's implementation.

## OUTPUT FORMAT (exact headings)

```
GIVENS CHECK     -- G1..G4: CONFIRMED / WRONG (with line)
T-1 .. T-8       -- verdict, evidence, smallest fix
PREMISE VERDICT  -- safe to merge (switch default off)? one paragraph
TEST GAPS        -- tests missing, with expected values
```

Line count: 96
