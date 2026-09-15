# ADR-149: Leg-Isolated Cap Exposure Sum

## Status

Accepted -- 2026-09-15.

## Context

The fxgrind currency cap (Spec B) aggregates per-instance leg exposure from
GlobalVariables before allowing new entries. Each instance publishes only
the two legs it carries; the fleet sum reads every peer's stored value for
the leg being checked.

### The defect

`Grind_CapReadStoredPeer` treats a missing GlobalVariable exactly like a
stale one: it returns `GRIND_CAP_MAXED_VALUE` (1.0e12) and sets
`failed_out = true`. Before this change, `Grind_CapSumLegExposure` iterated
all twelve magics in `GRIND_CAP_ALL_MAGICS` for every leg. Summing CHF, for
example, read `GRIND2226_<magic>_CHF` from eight instances that never
publish CHF. Each missing key contributed MAXED, `peer_failed_out` became
true, and the half-MAXED guard tripped independently. `Grind_CapAllowsEntry`
returned false for every entry on every instance.

This was invisible because all presets keep `InpCapLegAThresh` and
`InpCapLegBThresh` at 0.0, so `Grind_CapThresholdEnabled()` is false and
the sum is never reached. ADR-143 described the stale-GV surface as latent.
That characterisation was wrong: the permissive path has never worked.
Arming a threshold without leg isolation would block every instance
permanently from the first tick.

### Ruling implemented

Gemini memorandum 2026-09-15, R2 (leg-isolated fail-closed): a peer must
only contribute to, and only be able to fail, a leg it actually carries. A
stale GBPUSD peer must block new GBP and USD entries fleet-wide (aggregate
exposure on those legs is unknown). It must not block AUDCHF from trading
CHF.

## Decision

1. Add static `GRIND_CAP_MAGIC_LEG_A` and `GRIND_CAP_MAGIC_LEG_B` tables
   beside `GRIND_CAP_ALL_MAGICS`, same index order, derived from fleet
   presets (`InpCapLegA` / `InpCapLegB`).

2. Add `Grind_CapMagicCarriesLeg(idx, leg)` and skip non-carriers in
   `Grind_CapSumLegExposure` before reading peer GlobalVariables.

3. Do not change `Grind_CapReadStoredPeer`, `Grind_CapAllowsEntry`,
   `Grind_CapPublishOwnExposure`, stale seconds, or MAXED value.

4. Thresholds remain at 0.0 in all presets. Arming is a separate change.

### Why a static table

Leg membership lives in each instance's preset. The cap sum runs in-process
and cannot read a peer's inputs. The table MUST be updated whenever
`GRIND_CAP_ALL_MAGICS` changes. Test `CL4_LegMembershipTableMatchesMagics`
catches array-length drift; it cannot catch wrong currency strings.

### CHF threshold note (arming deferred)

When CHF is armed, Gemini set 0.40 lots: 4 CHF instances x 8 layers x
0.01 = 0.32 today; with NZDCHF (6 instances) x 0.08 = 0.48, so 0.40 binds
at five fully-loaded arms.

**0.40 is a chord-driven exception, not a constant.** The live fleet is
topologically uniform -- two closed triangles, six currencies, four
instances per currency -- so every leg carries identical worst-case exposure
and no per-currency threshold is needed. NZDCHF would be the first chord,
taking CHF to six instances while NZD sits at two. Under uniform topology
the threshold is derivable from structure (instances_per_currency x
max_layers x lots) and needs no risk-appetite call. A future uniform
topology should replace 0.40 with a derived constant.

## Consequences

- The cap becomes executable when thresholds are armed; CL1 is the s11
  failing ALLOW test that proves the old path blocked a healthy fleet.
- Stale/missing peer handling on unrelated legs no longer causes false
  fleet-wide halts.
- Operators must keep the leg table in sync with preset and magic-list
  changes (ADR-143 fleet table).
