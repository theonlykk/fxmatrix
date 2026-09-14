# ADR-143: Extend Fleet Magic Lists from Six to Twelve

## Status

Accepted -- 2026-09-14.

## Context

The live fxgrind fleet runs twelve instances (six currency pairs, OPT and ALT
arms each). Two hardcoded magic-number lists still enumerated only the original
six triangle instances (GBPUSD, EURUSD, EURGBP):

1. `GRIND_CAP_ALL_MAGICS` in `ea/grind_cap.mqh` -- drives peer exposure
   summation in `Grind_CapSumLegExposure` and cap-related test GV seeding.
2. The local `magics` array inside `Grind_MagicLockReleaseAllKnown` in
   `ea/grind_magic_lock.mqh` -- releases duplicate-magic boot locks on shutdown.

Both arrays omitted the AUD/CAD/CHF ring magics (22260401 through 22260602).
Each loop used a hardcoded literal `6` as the bound instead of `ArraySize`,
so the array length and iteration count could drift apart without a compile
error or test failure while the cap remained disabled.

**Latent, not active:** All twelve presets carry `InpCapLegAThresh=0.0` and
`InpCapLegBThresh=0.0`. `Grind_CapThresholdEnabled()` returns false when both
are zero, and `Grind_CapAllowsEntry` returns true before
`GRIND_CAP_ALL_MAGICS` is read. Nothing was being mis-capped on the live fleet.
This change does not enable the cap; thresholds stay at zero per ARCHITECT.md
section 11 until a failing ALLOW test exists.

**Stale-GV surface:** `Grind_CapPublishOwnExposure` runs unconditionally on
init and tick. A halted or detached instance stops publishing; its GlobalVariable
goes stale after `GRIND_CAP_STALE_SECONDS` (300), reads as MAXED, and sets
`peer_read_failed`. That property already existed with six magics; widening the
list to twelve widens the peer-read surface once thresholds are ever raised.
No change to staleness semantics is attempted here.

**NZDCHF excluded:** Magics 22260701 and 22260702 are not live; NZDCHF
`max_layers` remains RESEARCH ONLY per `scripts/sim_costs.py`. Adding those
magics requires separate ratification. Test magic 22269901 stays released
explicitly after the fleet loop in `Grind_MagicLockReleaseAllKnown`.

## Decision

1. Extend `GRIND_CAP_ALL_MAGICS` to twelve entries in fleet table order
   (22260101 through 22260602).
2. Extend the `Grind_MagicLockReleaseAllKnown` local array to the same twelve
   magics in the same order.
3. Replace every literal-`6` loop bound over either array with
   `ArraySize(...)`, including cap-related GV seed loops in `ea/fxgrind_tests.mq5`.
4. Add CM1-CM3 tests asserting array coverage, full peer sum iteration, and
   magic-lock release for all fleet magics.

## Consequences

- Cap peer summation and magic-lock teardown cover the full live fleet when
  thresholds are eventually enabled.
- Future fleet expansion must update both lists (or refactor to a single
  shared source) and add corresponding tests.
- NZDCHF magics remain deliberately absent until a dedicated change is ratified.
