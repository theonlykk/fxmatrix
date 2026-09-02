# Phase 1 Audit Request — EURGBP Native Sigma Migration + Easing Recalibration (Combined)

## Role reminder
Phase 1 Red Team submission per ARCHITECT.md. Mechanical/statistical
critique only — no implementation code. This proposal combines two
previously-separate threads (native sigma migration, easing
recalibration) into one submission, since today's earlier audit
established they are mathematically coupled, not independent.

## Background — full, verified chronology (not prior-session inference)

Production `fxmatrix_v2_eurgbp.mq5` computes its half-spread as:

    dynamic_hs = MathMax(
        quote_spread + MathMax(sig_ac, sig_bc) * effective_multiplier,
        live_spread_price + passivity_buffer_price
    )

`MathMax(sig_ac, sig_bc)` — the dominant-leg-as-sigma-stand-in approach
— originates in `fxmatrix_v2_signal.mqh` (created 2026-07-17,
`ee2ae59`), shared across all three pairs via delegation.

ADR-099 (2026-07-29, `a1cdd58`) locked EURGBP's depth-triggered spread
easing at `InpEaseDepthStart=1, InpEaseDepthFull=3`, via a 24-run
sweep, explicitly assuming `MathMax(sig_ac, sig_bc)` throughout — this
is stated directly in the ADR text and its unit tests
(`Test_EurgbpAbDualSigmaSwapIndependence`). The winning margin over the
runner-up (1/4) was thin: 1.7% on exit count, 0.7% on aggregate P&L,
accepted by Gemini as the correct tie-breaker given no config dominated
across all four test windows.

Separately, a native return-based EURGBP sigma
(`V2_ReturnSigmaFromCloses()`) was real-tick verified this session as
performing cleanly with no quality degradation across 5 canonical
stress windows. It was never merged into production. It exists only in
an untracked, uncommitted file (`fxmatrix_v2_signal_experimental.mqh`,
marked TEMP ONLY) and an untracked experimental EA
(`fxmatrix_v2_eurgbp_experimental_instrumented.mq5`) that already
combines native sigma with the 1/3 easing thresholds — but this
combination was never taken through DeepSeek/Gemini review, never
re-verified, and never committed.

No ADR documents native sigma's adoption. Confirmed directly against
`docs/architecture/` — no matches for native/return-based sigma
anywhere outside the untracked experimental files.

**Open question motivating this submission:** would migrating EURGBP
to native sigma increase trade frequency (tighter quotes, since
verification suggests native sigma runs meaningfully smaller than the
current `MathMax` value), and if so, at what cost to EURGBP's currently
observed per-trade quality advantage over the USD legs (higher avg
P&L/exit, lower adverse excursion, attributed partly to trading less)?

## Proposed design (concept level — no implementation code)

1. Replace `MathMax(sig_ac, sig_bc)` with native return-based sigma in
   EURGBP's half-spread calculation, scoped to EURGBP only — must not
   alter `fxmatrix_v2_signal.mqh`'s shared behavior for GBPUSD/EURUSD.
2. Re-run ADR-099's calibration sweep (or an equivalent one) with
   native sigma as the base, across the same threshold candidates
   (1/3, 1/4, others as warranted), to determine whether 1/3 remains
   correct or a different threshold is now optimal under the new
   sigma scale.
3. Real-tick MT5 verification (Model=4, the same canonical stress
   windows used throughout this project) of the combined
   sigma-plus-easing change — not Python/Monte Carlo as deciding
   evidence, given the `SpreadMultiplier` precedent below.

## Specific things to hammer on

1. **Does the prior native-sigma real-tick verification actually cover
   this combined case?** ADR-099's easing has been live in production
   since July 29. If the native-sigma verification session tested
   sigma in isolation (a simplified harness, or a build predating
   ADR-099's inlined easing), it does not constitute prior validation
   of native-sigma-plus-easing together. Confirm from source what
   exactly was held constant during that verification, and state
   plainly if this is unknown/unconfirmable from available records.

2. **Is ADR-099's threshold ranking sigma-scale-invariant?** The
   absolute easing effect at full ease is `sigma * (spread_multiplier
   − spread_multiplier_eased)`. If native sigma is meaningfully smaller
   than `MathMax(sig_ac, sig_bc)`, does rescaling preserve the relative
   ranking between 1/3 and 1/4 (and other candidates), or can a smaller
   sigma amplify or dampen the already-thin 1.7%/0.7% margin enough to
   flip which threshold wins? This is a checkable mathematical
   question, not a matter of opinion — work through it explicitly
   rather than asserting an answer.

3. **Floor-dominance risk.** If native sigma substantially shrinks the
   `quote_spread + sigma*effective_multiplier` term, does
   `live_spread_price + passivity_buffer_price` become the binding
   floor far more often than today? If the floor dominates in a larger
   fraction of cases, the easing ramp itself becomes inert in exactly
   those cases (easing only touches the first term). This would mean
   the real behavioral change from this migration is smaller and more
   regime-concentrated than a naive reading suggests — quantify this
   if possible from the formula structure, flag as unquantifiable from
   static analysis alone if it requires live data.

4. **Is this the same simulation-vs-real-tick trap as `SpreadMultiplier`?**
   That investigation found Python/Monte Carlo predicted tighter
   quoting would increase fills, but real-tick verification across 5
   stress windows overturned it — the Brownian-bridge engine credited
   fills real ticks didn't reward. Is there a structural reason to
   expect this migration is subject to the same risk (tighter native
   sigma → predicted more fills in simulation, unconfirmed in reality),
   and should real-tick verification be treated as the only acceptable
   deciding evidence, with no simulation result trusted as sufficient
   on its own?

5. **Quality-erosion hypothesis.** EURGBP's currently-better per-trade
   quality (vs. GBPUSD/EURUSD) has been attributed partly to lower
   trade frequency. If native sigma increases fill rate via tighter
   quotes, is there a first-principles reason to expect degraded
   per-trade quality (less edge captured per fill), and does this
   interact with the already-flagged concern that easing fires exactly
   when opposite-side depth accumulates — precisely the regime where
   L2+ layers were found to underperform, resolve slower, and show
   higher adverse-continuation? Could increased native-sigma-driven
   fill rate concentrate disproportionately in that already-disfavored
   regime rather than spreading evenly?

6. **Scope containment.** Confirm the migration can be implemented as
   an EURGBP-only branch without modifying `fxmatrix_v2_signal.mqh`'s
   shared `MathMax(sig_ac, sig_bc)` path — GBPUSD and EURUSD's sigma
   must be completely unaffected. Flag if the current code structure
   (shared header, delegation pattern) makes this harder to isolate
   than it appears.

7. **Verification scope required.** ADR-099's original lock-in required
   a 24-run sweep, Gemini's ruling on the tie-breaker, and Khalid's
   independent Strategy Tester verification against two named stress
   windows (Truss Crisis, Vaccine Rally). Does a native-sigma
   recalibration need the full equivalent of that process repeated, or
   is any part of the original sweep/verification reusable given the
   sigma source is what's changing, not the ramp mechanism itself?

No implementation code in your response. Flag anything above that
should block this from proceeding to Gemini, and any assumption in the
proposed design that doesn't hold once checked against real source.
