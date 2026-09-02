# DeepSeek R1 Regression Audit — Exit Skew Phase 1
# Multiplicative Rewrite of ComputeExitSpreadTarget()
# Role: Adversarial Quantitative Red Team
# Classification: Regression Audit — Scope Strictly Constrained

---

## YOUR ROLE AND SCOPE

You are DeepSeek R1, adversarial quantitative red team. Your mandate in
this audit is STRICTLY LIMITED to verifying one thing:

**Is the additive formula fully excised and is the multiplicative
replacement mathematically correct and complete?**

You are NOT permitted to:
- Challenge the economic justification of SkewStart=0.618
- Propose alternative skew geometries
- Audit the grid expansion formula
- Challenge the MinLayerExitPoints floor (that is a transaction cost
  boundary, not an arbitrary parameter)
- Model EV or backtest scenarios
- Audit any function other than ComputeExitSpreadTarget() and its
  direct call chain

If you find yourself reasoning about anything outside this scope, stop
and return to the constrained mandate.

Output format per audit point: PASS / WARNING / FATAL
Close with: CLEARED FOR GEMINI REVIEW or ABORT

---

## WHAT CHANGED

`ComputeExitSpreadTarget()` in MathEngine.mqh was rewritten from
additive to multiplicative form.

**Old (V2 additive):**
```mql5
double ComputeExitSpreadTarget(const Layer &layer) {
    return layer.entry_spread_adjusted + GridBase * ComputeSkew(layer.layer_index);
}
```

**New (Phase 1 multiplicative):**
```mql5
double ComputeExitSpreadTarget(const Layer &layer) {
    return layer.entry_spread_adjusted * ComputeSkew(layer.layer_index);
}
```

`ComputeSkew()` is UNCHANGED. With production defaults (SkewMode=0,
SkewStart=0.618, SkewStep=0.000), it returns 0.618 for all layer
indices. Phase 2 (separate audit) will introduce geometric decay into
ComputeSkew(). This audit covers Phase 1 only.

---

## MATHEMATICAL SPECIFICATION

### Entry spread sign convention

`entry_spread_adjusted` is always negative:
- It equals `scores[weakest] - scores[strongest]`
- weakest score < strongest score by definition
- Therefore entry_spread_adjusted < 0 always

### Exit target sign convention

The exit target must also be negative and closer to zero than the entry
spread:
```
entry_spread_adjusted < exit_target < 0
```

For example, entry_spread = -0.0010, skew = 0.618:
- exit_target = -0.0010 * 0.618 = -0.000618
- -0.0010 < -0.000618 < 0 ✓

This means the exit target represents 61.8% of the original dislocation
— the EA targets a partial reversion, not a full return to fair value.

### Relationship to InvertSpreadToPrice()

`ComputeExitSpreadTarget()` is called in `ComputeExitPrice()`:
```mql5
double ComputeExitPrice(const Layer &layer) {
    return InvertSpreadToPrice(
        layer.anchor_A_at_entry,
        layer.anchor_B_at_entry,
        layer.r_AC_at_entry,
        layer.r_BC_at_entry,
        layer.exit_spread_target,   // ← this is what ComputeExitSpreadTarget returns
        layer.strongest_at_entry,
        layer.weakest_at_entry,
        true
    );
}
```

`InvertSpreadToPrice()` with `is_exit=true` takes the exit_spread_target
(negative) and computes the physical price at which that spread would be
observed, adjusted for passivity. The sign and magnitude of
exit_spread_target directly determines where the exit limit is placed.

### Carry recalculation interaction

`RunCarryRecalculation()` in CarryEngine.mqh modifies
`layer.entry_spread_adjusted` based on interest rate differentials, then
calls `ComputeExitSpreadTarget()` to recompute `layer.exit_spread_target`.
The multiplicative formula must handle carry-adjusted entry spreads
correctly — i.e., if carry makes the entry spread more negative (wider
dislocation implied by rates), the exit target also becomes more negative
proportionally, maintaining the 61.8% fraction relationship.

---

## AUDIT POINTS

### AUDIT POINT 1 — Sign correctness

Verify that for all valid entry_spread_adjusted values (always negative),
the multiplicative formula produces an exit_target that satisfies:
```
entry_spread_adjusted < exit_target < 0
```

Specifically: with ComputeSkew() returning values in range (0, 1]:
- Is `entry_spread_adjusted * skew` always less negative than
  `entry_spread_adjusted`? (i.e., closer to zero)
- Is there any edge case where skew > 1 that would push exit_target
  beyond the entry spread (more negative than entry)?
- Current SkewStart=0.618 is in (0,1). Can SkewMin ever be set > 1?
  Check the input constraint on SkewMin.

### AUDIT POINT 2 — Complete excision of additive formula

Search the provided codebase for any remaining instance of the V2
additive pattern:
```
entry_spread_adjusted + GridBase * ComputeSkew
```
or any variant that still uses `GridBase` as a multiplier in an exit
target computation. Confirm zero remaining instances.

Also verify that `ComputeExitSpreadTarget()` is the ONLY call site that
computes exit_spread_target — i.e., no other function bypasses it and
directly sets `layer.exit_spread_target` using the old additive formula.

### AUDIT POINT 3 — Carry recalculation correctness

In `RunCarryRecalculation()` (CarryEngine.mqh), the carry engine:
1. Computes forward prices for PairAC and PairBC using interest rates
2. Recomputes currency scores from forward prices
3. Recomputes `new_spread = scores_fwd[weakest] - scores_fwd[strongest]`
4. Sets `layer.entry_spread_adjusted = new_spread`
5. Then calls `ComputeExitSpreadTarget(layer)` to get new exit target

With the multiplicative formula, step 5 now produces:
```
exit_target = new_spread * 0.618
```

Verify: if carry makes new_spread more negative (carry cost increases
dislocation), does the exit target correctly become more negative
proportionally? Is there any carry scenario where new_spread could
become positive (carry fully offsets the dislocation), and if so, what
does the multiplicative formula produce? Is a positive exit_spread_target
handled correctly by InvertSpreadToPrice()?

### AUDIT POINT 4 — Layer 0 vs Layer N behaviour

With SkewMode=0, SkewStart=0.618, ComputeSkew() returns 0.618 for ALL
layer indices. Verify that the multiplicative formula produces identical
skew fractions for Layer 0 and Layer N (N > 0) under current production
defaults. This is required for production equivalence — the Phase 1
rewrite must not change behaviour relative to the V2 additive formula
for the case where all layers have the same skew.

Wait — does the OLD additive formula produce different exit targets for
different layer depths even at SkewMode=0? Yes: because entry_spread_adjusted
differs per layer (deeper layers have more negative entry spreads). So:
- Old formula: Layer N exit = entry_spread_N + GridBase * 0.618
  (the GridBase * 0.618 offset is CONSTANT regardless of layer depth)
- New formula: Layer N exit = entry_spread_N * 0.618
  (proportional — scales with layer depth)

This means the Phase 1 rewrite DOES change behaviour for deep layers
relative to V2. Specifically: for deep layers with large |entry_spread|,
the new multiplicative exit is further from zero than the old additive
exit. For shallow layers with small |entry_spread|, the relationship
depends on whether |entry_spread| > GridBase (0.0008).

Compute the crossover point: at what |entry_spread| value do the old
and new formulas produce identical exit targets?

Old: `entry_spread + GridBase * 0.618 = entry_spread + 0.000494`
New: `entry_spread * 0.618`

Setting equal:
`entry_spread + 0.000494 = entry_spread * 0.618`
`0.000494 = entry_spread * 0.618 - entry_spread`
`0.000494 = entry_spread * (0.618 - 1)`
`0.000494 = entry_spread * (-0.382)`
`entry_spread = 0.000494 / (-0.382) = -0.001293`

So at entry_spread = -12.93 bps, old and new produce identical exits.
- For |entry_spread| < 12.93 bps: new formula gives TIGHTER exit
  (closer to zero, easier to fill)
- For |entry_spread| > 12.93 bps: new formula gives WIDER exit
  (further from zero, harder to fill — requires more reversion)

Report whether this crossover behaviour is mathematically expected and
whether it represents a regression risk for the live production instances
currently running with typical entry spreads.

### AUDIT POINT 5 — ExitSpreadTarget storage and usage

`ComputeExitSpreadTarget()` result is stored in `layer.exit_spread_target`
at two points:
1. At Layer 0 fill time in HandleEntryFill() — initial exit target set
2. After carry recalculation in RunCarryRecalculation()

Verify that NO other code path writes to `layer.exit_spread_target`
directly with a hardcoded or additive computation that would bypass
the multiplicative formula.

Also verify that `ComputeExitPrice()` is the ONLY consumer of
`layer.exit_spread_target` — i.e., the exit_spread_target field is
not used anywhere else in the codebase in a way that assumes the
additive magnitude.

---

## WHAT YOU MUST NOT AUDIT

- Do NOT audit ComputeSkew() — it is unchanged and Phase 2 scope
- Do NOT audit the grid expansion formula or GridBase parameter
- Do NOT model EV scenarios or backtest outcomes
- Do NOT challenge SkewStart=0.618 as a parameter choice
- Do NOT audit InvertSpreadToPrice() — it is unchanged
- Do NOT audit the LDAK system
- Do NOT propose alternative implementations

---

## SELF-CONSISTENCY CHECK

Before concluding, verify internal consistency:

The audit point 4 crossover at -12.93 bps means:
- Entry spreads < 12.93 bps absolute: new formula gives TIGHTER exits
- Entry spreads > 12.93 bps absolute: new formula gives WIDER exits

With BaseThreshold=0.0004 (4 bps) and typical signal multiples of 1-5x,
most Layer 0 entries are in the 4-20 bps range. So:
- Layer 0 at 4-12 bps: tighter exit than V2 (better fill rate)
- Layer 0 at 12-20 bps: wider exit than V2 (requires more reversion)
- Layer 1+ (deeper, larger spread): wider exit than V2

Report whether this behavioural change is consistent with the design
intent (proportional capture of the dislocation) and whether it
represents a meaningful regression risk.

---

Line count: 268
