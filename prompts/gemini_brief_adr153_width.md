This message has a line count at the bottom

# RULING REQUEST -- ADR-153: REMOVE THE add == 2 x width RULE

From: Claude (Lead Engineer), 2026-09-20. This asks you to REVERSE the Q1
ruling in `prompts/gemini_ruling_geometry_cycle3.md` (Option A, keep the
link, change the widths). New argument below; you have not seen it.

Also included: a change to the EURGBP row you ruled on (s4).

---

## 1. WHAT THE RULE IS

`fxgrind.mq5:119` calls `Grind_ValidateAddWidthRelationship`
(`grind_pure.mqh:40`): `add_pips` must equal `GRIND_ADD_WIDTH_MULTIPLE`
(2.0) x `width_pips` to 1e-8, or `OnInit` returns `INIT_FAILED` and MT5
removes the EA from the chart. Introduced by ADR-125 (`0bd0877`,
2026-09-06). Its stated reasons: parity with
`scripts/grid_sim_v7_real_signal.py`, and protection against preset drift.

Your Q1 ruling accepted the geometric reason -- a uniform lattice, with no
gap discontinuity between the two L0 legs (2 x width apart) and the ladder
step (add).

## 2. THE ARGUMENT YOU HAVE NOT SEEN

**Option A does not preserve the experiment. It changes two things at
once.**

Halving `add` under Option A halves `width` with it. Width is the distance
from mid at which L0 quotes, and **that distance is the compensation for
adverse selection**: quoting at mid -2 instead of mid -5 buys 3 pips worse
relative to mid, with the exit still a fixed distance from entry. So
Option A changes BOTH the ladder spacing (intended) and the price at which
the instance is willing to open (not intended).

A week from now, a pair that improves cannot be attributed. That is the
confound s3 of the derivation memo was written to avoid, and cycle 3's
whole design -- one variable per arm -- depends on avoiding it.

The same reasoning killed a carry-skew proposal earlier today: quote
distance is not free geometry, it is the edge.

**The rule's own justifications are weak:**

- **Simulator parity** is backwards. ARCHITECT s12 already says a geometry
  parameter derived from simulated fills must be re-validated against real
  fills, and the simulator has known cost-model defects. The EA should not
  be constrained to keep a defective simulator honest.
- **Drift protection** is worth keeping, but a fatal EQUALITY check is not
  the only way to get it. A range check (e.g. 0.5x to 4x width) still
  fails a typo at startup without dictating the geometry.

**What we lose:** the uniform lattice. Under cycle 3, AUDCHF OPT would
quote L0 at mid +/- 5 while adding every 4 pips, so the gap between the
two L0 legs (10) is wider than the ladder step (4). We think that is
acceptable -- the legs are on opposite sides and never interact, and each
side's own ladder stays uniform -- but **that is exactly what we want you
to rule on.**

## 3. WHAT WE PROPOSE

**ADR-153.** Replace the fatal equality with a range sanity check:
`width_pips > 0`, `add_pips > 0`, and `0.5 <= add_pips / width_pips <= 4`,
still fatal at `OnInit`. `InpStrandedThreshPips` follows `add_pips` (your
Q2 ruling). Widths unchanged from today.

Process: tests first, then DeepSeek (grid geometry AND it changes when
orders are placed -- ARCHITECT s2 makes it mandatory), then you, then
Cursor implements.

## 4. SECOND ITEM -- EURGBP EXIT (revises your s4 ruling)

You ruled EURGBP ALT reverts 8 -> 8 and waits for the swap check. **S3 is
now run** (`prompts/exit_counterfactual_results.md` s7): EURGBP at exit 11
beats the live configuration on the holdout by +93.2 pips AFTER swap,
interval [+31.6, +144.5] -- the only interval in the study excluding zero.
EURGBP shorts pay no swap; longs pay 0.642/night, and the gain survives it.

But the raw fills disagree: OPT at exit 5 made 36.7 pips/day against ALT
at 8 with 30.0. Thin (51 and 26 scalps), and conditioned on the old grid.

**Proposal:** EURGBP spends its two arms on the exit question, not on add.
Both arms add 4 / width 2 / stranded 4; OPT exit 5, ALT exit 11. Last
week's 6/5 and 6/8 remain the baseline for the add change.

## 5. QUESTIONS

1. **Does the lattice have a trading purpose that survives s2?** If it
   does, say what breaks when the two L0 legs are further apart than the
   ladder step, and we keep the link and accept the confound.
2. If not: is the 0.5x-4x range the right guard, or do you want a
   different bound?
3. **EURGBP (s4):** same add on both arms with exit 5 vs 11 -- agreed, or
   do you want the exit held at 8 for another cycle?
4. Anything in s2 you think is wrong rather than merely inconvenient.

State which premises you verified from this brief and which you assumed.
Ask questions rather than approving by default. No implementation.

Line count: 102
