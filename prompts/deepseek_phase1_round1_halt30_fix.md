This message has a line count at the bottom.

# DeepSeek Phase 1 — Targeted Audit: HALT_30 Historical False-Positive Fix (SRE)

## Round context

This is a **narrow, single-question audit**, not a full design round. The State Reconstruction Engine (SRE) itself already passed six rounds of your Phase 1 teardown during its original design (v2->v8) — this is not reopening that. What changed since: the SRE was implemented (ADR-106), and a new **Tier 1 real-data replay fixture** — the engine run against genuine, un-sanitized broker history from this account rather than synthetic scenarios — surfaced an emergent behavior that synthetic unit tests structurally could not have caught.

The finding: on a multi-day-old actively-trading book, `V2_SRE_HedgePriceIndicatesCrossPair()` fires `HALT_30_CLOSEBY_PRICE_INCONSISTENT` on **already-settled historical CloseBy pairs** that have nothing to do with the position currently being reconstructed. Confirmed not a fixture artifact: production's real deal-gathering (`V2_SRE_GatherDealHistory`) uses a 90-day lookback (`V2_SRE_DEFAULT_LOOKBACK_SEC`), and this account is ~9 days old — so a real restart today would gather the identical full history the fixture used. This is production-equivalent behavior, not an inflated test.

Gemini (Staff Architect) has diagnosed the root cause and authorized a fix, and has explicitly ruled that this does **not** need a full teardown. This audit exists because the fix touches a **security-relevant control** (HALT_30's stated original purpose is external-tampering / cross-pairing detection), and per ARCHITECT.md's cognitive-partition principle, loosening a security control should not go from proposal to implementation without one adversarial pass — however narrow. Your job here is one specific question, stated at the end.

## What HALT_30 currently does, and where

`V2_SRE_HedgePriceIndicatesCrossPair()` (fxmatrix_v2_state_reconstruction.mqh ~240-252). Single call site — the `MapHedgeToEntry` loop at ~934. For each historical CloseBy pair found after `anchor_time`, it compares the hedge leg's open price against a **naive** expected exit price (`entry_price +/- exit_pips`, no rollover term), with tolerance `point*2`. If the hedge price deviates beyond that, it flags cross-pairing -> HALT_30.

The flaw: a hedge leg opened against a position held across one or more broker midnights drifts by accumulated swap. That drift is real, physical, and already understood elsewhere in this exact file — the Tier 2 exit-order matcher (`V2_SRE_Tier2RolloverPriceInRange`, `V2_SRE_MaxPossibleRolloverShift`, ~399-422) already computes a bounded rollover range (swap rate x midnight count, direction-aware) for precisely this reason. The historical-pair check simply never had that correction applied. So genuine, normal, already-resolved trades held overnight trip a false tamper-positive.

## The proposed fix (Path A)

Replace the naive `expected +/- point*2` comparison in `V2_SRE_HedgePriceIndicatesCrossPair` with the same bounded-range rollover tolerance the Tier 2 matcher already uses: a hedge price is consistent if it falls within `[naive_expected, naive_expected + max_possible_rollover_shift]` (direction-adjusted, mirrored for SHORT). The pair's `open_time` and `now` are needed to compute the shift — both reachable at the call site (implementation to confirm exact field availability).

Intent preserved: a genuinely cross-paired hedge (wrong pair entirely) produces a price delta far larger than any plausible swap drift, so it still falls outside even the rollover-widened band and still halts. The fix only stops flagging drift explainable by real accumulated swap.

An alternative (Path B — skip HALT_30 entirely for fully-settled historical pairs) was considered and set aside as carrying a possible false-negative on the security control: the engine scans this history specifically to replay path-dependent state forward, so suppressing the check on those exact deals could replay a genuinely-corrupt pairing while silencing the alarm meant to catch it. Path A keeps the check active on every pair; it only widens the tolerance to physical reality. That is the whole reason Path A is preferred, and why the question below is about Path A specifically.

## The single question for this round

**Does Path A's rollover-widened tolerance reopen any cross-pairing / external-tampering gap that the current strict check closes?**

Concretely: can you construct a realistic mis-pairing (a hedge leg genuinely belonging to a different entry, or an externally-injected/tampered order) whose price delta from the naive expected would fall **inside** the rollover-widened band `[expected, expected + max_shift]` but **outside** the current strict `point*2` band — i.e. a genuine tamper that Path A would now wave through when the strict check would have caught it?

- If you can construct one: Path A needs a tighter bound or a supplementary discriminator, and you should specify the construction precisely.
- If you cannot: state why the rollover-bounded band cannot swallow a genuine mis-pairing (e.g. the minimum plausible cross-pair delta exceeds the maximum plausible swap drift for this instrument set), and Path A is cleared to implement.

Out of scope for this round: the SRE's overall design (already audited v2->v8), the Tier 2 matcher itself (already in production-candidate code), and the separate Case 7 mapping-output mismatch (a non-security correctness item being handled directly). Focus only on whether widening this specific tolerance creates a tamper-detection blind spot.

The full current fix blueprint follows below this memo.

--- BLUEPRINT ---

# Blueprint — HALT_30 Historical False-Positive Fix

For narrow DeepSeek Phase 1 review, then Cursor implementation. Grounded in actual source read at commit 21b2153.

## The exact mechanism (confirmed, not inferred)

`V2_SRE_HedgePriceIndicatesCrossPair()` (state_reconstruction.mqh ~240–252):

```
bool V2_SRE_HedgePriceIndicatesCrossPair(hedge_open_price, paired_entry_price,
                                         entry_direction, exit_pips, point) {
   if(V2_SRE_HedgePriceConsistentWithEntry(...)) return false;   // exact-match escape
   const double expected = V2_SRE_ExpectedExitPrice(paired_entry_price, entry_direction,
                                                    exit_pips, point);   // entry ± 3 pips, naive
   return (MathAbs(hedge_open_price - expected) > V2_SRE_ExitPriceTolerance(point) * 4.0);
}
```

The `expected` price is the naive formula: `entry_price + exit_pips` (LONG) or `entry_price − exit_pips` (SHORT), no rollover term. Tolerance is `point*0.5*4 = point*2`. A hedge leg that opened against a position held across one or more broker midnights will have drifted by accumulated swap — exactly the drift already characterized and handled elsewhere in this same file. When that drift exceeds `point*2`, this returns `true` → `HALT_30`. On historical, already-settled CloseBy pairs, that's a false tamper-positive. This is the identical unit/rollover blind spot ADR-101-adjacent work and the SRE Tier 2 matcher already fixed for open exit orders — it simply was never applied to this historical-pair check.

## Critical scoping fact, verified

`V2_SRE_HedgePriceIndicatesCrossPair` has exactly **one call site** — the `MapHedgeToEntry` loop at ~934. I grepped the file to confirm this before proposing a change to the function itself: no other code path depends on its current (stricter) behavior, so modifying it in place carries no collateral-surface risk to other checks. (Cursor to re-confirm against working tree before implementing — this was read at 21b2153.)

## The pattern to reuse already exists in-file

`V2_SRE_MaxPossibleRolloverShift()` (~399) and `V2_SRE_Tier2RolloverPriceInRange()` (~412) already implement exactly the bounded-range rollover tolerance Gemini's Path A describes — computed from real swap rate × midnight-count, direction-aware, `[expected, expected + max_shift]` for LONG and mirrored for SHORT. Path A is not new math; it's applying an existing, already-audited helper to a second call site.

## Path A (math fix) vs Path B (scope fix) — my recommendation, with the reasoning exposed

**Recommend Path A, and I'd flag Path B as carrying a subtle risk worth DeepSeek specifically pressure-testing.**

**Path A — extend bounded-rollover tolerance to the historical check.**
Replace the naive `expected ± point*2` comparison with the same bounded-range logic `V2_SRE_Tier2RolloverPriceInRange` already uses: a hedge price is consistent if it falls within `[naive_expected, naive_expected + max_possible_rollover_shift]` (direction-adjusted). Requires the pair's `open_time` and `now` to compute the shift — both available in the deal/table structures at the call site (needs Cursor to confirm the exact fields reachable there).
- *Preserves the anti-tampering intent:* a genuinely cross-paired hedge (wrong pair entirely) still falls outside even the rollover-widened band and still halts. It only stops flagging drift that's explainable by real accumulated swap.
- *Consistent with how the rest of the engine already reasons about held-position price drift.* No new concept introduced.

**Path B — bypass HALT_30 entirely for fully-settled historical CloseBy pairs.**
Skip the cross-pair check when both legs are already closed and neither involves a currently-open position.
- *The subtle risk:* HALT_30's original purpose (per Gemini's own memo) is detecting external tampering / cross-pairing. Path B assumes a fully-settled historical pair is "irrelevant to current active state" — but the reason the engine scans history at all is to replay path-dependent state (`current_add_pips`, `last_exit_valid`, `last_exit_price`) *forward* from those historical events. If a historical pair were genuinely mis-paired (the exact thing HALT_30 guards against), Path B would skip the check on precisely the deals whose correct interpretation the forward-replay depends on — potentially replaying corrupt state into the "current" reconstruction while suppressing the alarm designed to catch it. Path B trades a false-positive for a possible false-negative on a security control. That may be acceptable — but it's exactly the kind of trade that shouldn't be made without an adversarial pass, which is the whole reason this blueprint is going to DeepSeek rather than straight to Cursor.

**Path A doesn't carry that risk** — it keeps the check active on every historical pair, only widening the tolerance to match physical reality (swap drift), so it can't create a false-negative that Path B's skip-entirely approach can.

## The narrow question for DeepSeek

Not a full re-audit. Just: **does Path A's rollover-widened tolerance reopen any cross-pairing / external-tampering gap that the current strict check closes?** Specifically — is there a real-world mis-pairing whose price delta would fall *inside* the rollover-widened band but *outside* the current `point*2` band, i.e. a genuine tamper that Path A would now wave through? If DeepSeek can construct one, Path A needs a tighter bound or a supplementary check. If it can't, Path A is clear to implement.

## Case 7 mapping mismatch — separate, folded in per Gemini's ruling

Gemini's read (successful pairing but pairs not appended to the output array, or flushed because positions are closed) is plausible and matches the symptom (flat state correct, `map_result.pairs` empty). This is a lower-stakes correctness fix, not a security-relevant one — no DeepSeek needed, straight to Cursor: trace the output-array population in `V2_SRE_MapHedgeToEntry` for the closed-pair case, ensure resolved pairs populate the output struct so `last_exit_price`/`last_exit_valid` ordering is complete. One caveat to hand Cursor: confirm whether the assertion itself was correct — it's possible the *test* over-specified (asserting a mapping output that the engine legitimately doesn't populate for fully-closed pairs). Investigate-before-fix applies: determine whether the engine or the assertion is wrong before changing either.

## Sequencing

1. This blueprint → DeepSeek, narrow question above only.
2. On clear: Cursor implements Path A + Case 7 trace, real GUI compile, full 552+ suite plus the 7 Tier 1 cases must reach `V2_SRE_OK` on all applicable cases.
3. Re-run Tier 1 as the regression gate.
4. ADR recording the finding + fix, one commit.
5. Then Tier 2 live drill, Tuesday.
