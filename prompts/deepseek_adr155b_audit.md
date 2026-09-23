This message has a line count at the bottom

# DEEPSEEK R1 -- RED-TEAM ADR-155 PART B (COMMANDED PASSIVE EJECTION)

You are auditing an IMPLEMENTATION before it merges. It is already
tested (suite 1524/1524; the 33 new-test failures were predicted and seen
on a stub). Your job is what the tests cannot see.

**The system:** an MQL5 passive limit-order FX market maker. It never
crosses the spread and has no stop losses. Each side holds layers
(positions); required layers have a resting exit limit at entry +/-
`InpExitPips`, shifted by accrued swap (`GRIND_CARRY_ACCRUED_<pos>`),
by a broker-clamp residual (`GRIND_CARRY_SHIFT_<pos>`), and now by an
ejection offset (`GRIND_EJECT_OFFSET_<pos>`, Part A, merged). The
invariant I6 checks every resting exit equals
`raw + accrued + eject_offset + shift` within 2 points; a plain I6
failure HALTS the instance (not quarantinable).

**Part B** adds an operator command: a script writes
`GRIND_EJECT_<magic> = <position ticket>`; the EA polls it each tick and
moves the DEEPEST layer's resting exit to the best passive price at the
market. **Do not re-open whether ejection should exist, the offset
design, or carry.** Attack only Part B.

Attached, at branch `adr155-eject-command` `835c001`: `fxgrind.mq5`,
`grind_engine.mqh`, `grind_carry.mqh`, `grind_pure.mqh`,
`grind_exitq.mqh`, `grind_recon.mqh`, `scripts/grind_eject.mq5`, and
ADR-155 rev 4.

## GIVENS -- verify each against source, cite the line

- G1. The poll runs in `OnTick` after the invariant/quarantine step and
  before `if(g_grind_halted) return;` (`fxgrind.mq5:306`), with
  `engine_blocked = g_grind_halted || g_grind_quarantined`.
- G2. `Grind_EjectPollCommand` (`grind_engine.mqh:380`) deletes the
  command variable BEFORE validating, so every command is acted on once.
- G3. Validation order (`grind_pure.mqh:284`): blocked, switch, found,
  depth >= 2, rank == depth - 1, has exit order. Ranks come from ENTRY
  prices only (`Grind_ExitQRanks`).
- G4. Target (`grind_carry.mqh:552`): long = ask + min passive distance,
  short = bid - min passive distance, via the existing clamps.
- G5. On a failed modify, nothing is written. On success only: offset =
  target - raw - accrued; carry shift deleted; layer `exit_target` =
  target.
- G6. On the ejected layer's close, `EJECT_FILLED` is emitted before the
  Part A deletes (`grind_engine.mqh:1530`).

## THREATS -- verdict each: HOLDS / BREAKS / NEEDS-FIX

- **T-1 Zero ticket.** The script refuses 0; the poll does not. Can a
  layer carry `position_ticket == 0` (the carry pass skips such layers),
  so a hand-set `GRIND_EJECT_<magic> = 0` ejects it? Smallest fix?
- **T-2 Target stale in flight.** The target is computed from the
  current tick; if the market moves past it before the modify lands, what
  does the broker return, and does every such path leave NO state
  written?
- **T-3 Same-tick engine.** After an accepted ejection the same tick
  runs `Grind_OnTickEngine` and the exit queue. Can the stale-offset
  re-price, a trim, or a re-release move the ejected order away from
  `raw + accrued + offset`? Cite the path.
- **T-4 Event ordering.** Between the successful modify and the offset
  write, can `OnTradeTransaction` or an invariant check observe the
  order at the new price with the OLD state? (MQL5 handlers are
  sequential -- confirm or refute.)
- **T-5 Carry after ejection.** At the next rollover the carry pass
  builds from `raw + offset` and recomputes accrual. Show the exit moves
  by exactly the swap accrued SINCE the ejection, and I6 still holds.
- **T-6 Re-ejection.** A second command on an already-ejected layer
  overwrites the offset and deletes the shift. Any state it leaves
  inconsistent?
- **T-7 Restart after ejection.** Reconstruction (`OnInit`, ADR-156
  tolerant startup) with an ejected layer: does I6 pass, and does the
  rebuilt `exit_target` equal the resting price?
- **T-8 Halted/quarantined refusal.** A command arriving while blocked is
  deleted with `HALTED`. Any path where a blocked instance still moves an
  order?
- **T-9 Precision.** The ticket is stored as a double in a
  GlobalVariable. Safe for all realistic tickets?

## RULES

- Cite `file:line` for every claim about the code; otherwise label it
  INFERRED.
- For each BREAKS / NEEDS-FIX give the SMALLEST fix. No redesign.
- Stay inside Part B.

## OUTPUT FORMAT (exact headings)

```
GIVENS CHECK     -- G1..G6: CONFIRMED / WRONG (with line)
T-1 .. T-9       -- verdict, evidence, smallest fix
PREMISE VERDICT  -- is Part B safe to merge? one paragraph
TEST GAPS        -- tests missing from Z1-Z16, with expected values
```

Line count: 96
