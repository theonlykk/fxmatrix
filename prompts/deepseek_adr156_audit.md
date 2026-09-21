This message has a line count at the bottom

# DEEPSEEK R1 -- RED-TEAM ADR-156 (STARTUP EXIT SHORTFALL)

You are auditing a design BEFORE it is implemented. The design is attached
as `ADR-156-startup-exit-shortfall.md`. The source is attached in full:
`fxgrind.mq5`, `grind_recon.mqh`, `grind_quarantine.mqh`,
`grind_engine.mqh`, `grind_exitq.mqh`, `grind_pure.mqh`, at `main`
`5124bd2`. ADR-151 is attached for the exit-queue background.

**The system:** an MQL5 passive limit-order FX market maker. It never
crosses the spread and has no stop losses. Each side holds layers
(positions), and each layer may have a resting exit limit order at
entry +/- `InpExitPips`. F1, the "barbell" exit queue, requires resting
exits on rank 0 (nearest) and rank `depth - 1` (most underwater), and
holds the middle ones back. **Do not re-open whether the barbell is a
good idea. It is decided.** Attack only ADR-156.

## GIVENS -- verify each against the attached source, cite the line

- G1. `OnInit`: if `Grind_ReconstructState()` fails, the instance halts;
  `Grind_RetryMissingExits` runs only on success (`fxgrind.mq5:175-180`).
- G2. The rebuild assigns a formula `exit_target` to uncovered layers
  (`grind_recon.mqh:1091-1112`).
- G3. The I3 `no_exit_coverage` test is at four sites: `grind_recon.mqh`
  493-497, 520-524, 1033-1043, 1050-1060.
- G4. `Grind_RetryMissingExits` = `Grind_ExitQManageSide` on both sides
  (`grind_engine.mqh:1530-1536`).
- G5. OnTick: strict check, then `Grind_QuarantineStep`; I3 is
  quarantinable; while quarantined, retry runs only if
  `Grind_GuardsAllowTrading` (`fxgrind.mq5:280-301`,
  `grind_quarantine.mqh`). Escalation: >= 3000 ms AND >= 3 checks.
- G6. The feed-staleness guard blocks one tick only (`grind_pure.mqh:231-242`).

## THREATS -- give each a verdict: HOLDS / BREAKS / NEEDS-FIX

- **T-1 Escalation while a fix is impossible.** Quarantine counts checks
  whether or not a retry was ALLOWED. If `Grind_GuardsAllowTrading` is
  false for >= 3 s over >= 3 ticks (for example trade mode not FULL at a
  session edge), a startup shortfall becomes a halt. Is that reachable?
  Is it worse than today (a halt at `OnInit`)? Smallest fix?
- **T-2 Placement inside OnInit.** The existing retry runs before
  `Grind_MaeInit`, `Grind_CapPublishOwnExposure` and `EventSetTimer`.
  Does any state it reads (slot counts, API counter, ExitQ globals, carry
  GVs) depend on those? Any case where it places a DUPLICATE exit
  (I2 next tick)?
- **T-3 Marketable target.** After a large move while detached (for
  example during a manual roll), the formula target for the newly required
  exit may already be through the market. What does
  `Grind_ExitQManageSide` do: clamp, reject, or fill at once? Is the
  resulting state valid for the next strict check (I6 tolerance, carry
  shift GV)?
- **T-4 Masking.** Does tolerance hide any condition that is NOT a
  simple missing exit? For example: an exit order that exists but is not
  parsed as coverage, a `has_exit_position` edge, or a comment-parse
  miss. For each, would the strict OnTick check catch it within one tick?
- **T-5 Counting and control flow.** The shortfall is counted in the
  Inner loop only, and the Inner loop `continue`s past I3 (the later I4
  test needs `!has_position`). Any iteration where `continue` skips a
  needed check, or where the count is wrong?
- **T-6 Carry state.** Carry is OFF in all presets, but the
  `GRIND_CARRY_SHIFT_` / `_ACCRUED_` GVs are read by the formula and by
  I6. Can a stale GV for a reused ticket make the placed exit fail I6 on
  the first strict check?
- **T-7 Critical telemetry in OnInit.** Settled by ruling: no halt on a
  shortfall; `Grind_TelemetryCritical` fires when a side's shortfall is 2
  (ADR s3 item 4). Do not re-argue the threshold. Check only that
  calling `Grind_TelemetryCritical` (which enqueues and force-flushes the
  archive) at that point in `OnInit` is safe. Does it read or write any
  halt state that would mark the instance halted?

## RULES

- Cite `file:line` for every claim about the code. If a claim cannot be
  cited, label it INFERRED.
- For each BREAKS / NEEDS-FIX, give the SMALLEST fix. Do not propose a
  redesign.
- Do not raise issues about F1 itself, the quarantine design in general,
  or anything already recorded as out of scope in ADR-156 s4.

## OUTPUT FORMAT (exact headings)

```
GIVENS CHECK      -- G1..G6: CONFIRMED / WRONG (with line)
T-1 .. T-7        -- verdict, evidence, smallest fix
PREMISE VERDICT   -- does "place then check at startup" hold? one paragraph
TEST GAPS         -- tests missing from ADR-156 s6, with expected values
```

Line count: 90
