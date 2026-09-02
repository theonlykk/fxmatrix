# Phase 1 Audit Request — EURGBP Depth-Triggered Spread Easing Port

## Role reminder
Phase 1 Red Team submission per ARCHITECT.md. Mechanical/statistical
critique only — no implementation code. This is a resumed effort: a
prior audit on this same port was sent but its response was never
confirmed received or reviewed. Treat this as a fresh full audit
rather than assuming prior context carried over.

## Background

ADR-097 (GBPUSD) and ADR-098 (EURUSD) locked in a depth-triggered L0
spread easing mechanism: a linear ramp of the spread multiplier from
InpSpreadMultiplier down to InpSpreadMultiplierEased (0.0) as
opposite-side stack depth moves from InpEaseDepthStart (2) to
InpEaseDepthFull (5) layers, replacing the volatility term in that
regime.

The EURGBP port was previously stalled because EURGBP's quote-spread
calculation had an unresolved sigma question at the time: production
used MathMax(sig_ac, sig_bc) — the max of the EURUSD/GBPUSD leg
volatilities — which real-tick verification later confirmed
overstated EURGBP's real volatility by roughly 3.7x. That has since
been resolved: a native, return-based EURGBP sigma (computed from
EURGBP's own price history) was adopted instead, verified clean
against 5 real-tick stress windows with no quality degradation. That
specific ambiguity blocking the port should now be gone — this
submission is checking whether it actually is, and whether anything
else EURGBP-specific complicates a straightforward port.

## Proposed design (concept level — confirm against real source before
trusting any of this)

Apply the same InpEaseDepthStart/InpEaseDepthFull/
InpSpreadMultiplierEased ramp logic already locked for GBPUSD/EURUSD
to EURGBP's quote-spread calculation, with EURGBP's now-adopted native
sigma as the base spread input being eased. No new free parameters —
reuse the same input names/defaults already validated for the other
two pairs unless this audit surfaces a real reason EURGBP needs its
own calibration.

This design description is written from memory of prior session
context, not from reading current source. Before anything else,
confirm against the real files: the actual current EURGBP
quote-spread/sigma calculation, and the actual current GBPUSD/EURUSD
easing implementation (ADR-097/098) — flag any discrepancy from what's
described above rather than assuming this framing is accurate.

## Specific things to hammer on

1. **Depth-threshold pair-agnosticism.** Were InpEaseDepthStart=2 /
   InpEaseDepthFull=5 calibrated against GBPUSD/EURUSD's own native
   sigma scale specifically, or are these pure layer-count thresholds
   that are inherently pair-agnostic by design? If the former, reusing
   the same absolute thresholds for EURGBP (which has meaningfully
   lower realized volatility and a more grind-like regime than the USD
   legs, per prior real-tick findings) may not transfer cleanly. If
   the latter, this concern is moot — confirm which from actual source
   rather than assuming.

2. **Layer-depth profitability interaction.** A prior n=500 validation
   found L0-1 layers more profitable than L2+, with damage
   concentrating on the disfavored side during trend/stress regimes
   (L2+ taking 2.4x longer to resolve, 62% higher adverse-continuation
   rate). Easing loosens spread as opposite-side depth builds — does
   applying it at the same depth thresholds interact differently for
   EURGBP given its own different capital-velocity profile (EURGBP
   takes 2-5x longer to resolve than the USD legs, per prior live/
   backtest comparison)?

3. **Sigma migration completeness.** Verify there is no leftover
   reference to the old MathMax(sig_ac, sig_bc) borrowed-sigma approach
   anywhere in the easing-related code paths specifically — a partial
   migration that left the main spread calc on native sigma but the
   easing ramp still referencing the old borrowed value (or vice versa)
   would be a real, easy-to-miss defect given how easing and the base
   spread calc likely interact.

4. **Cross-instance/dual-cap interaction.** EURGBP is the only pair
   keyed into both the GBP cap and EUR cap simultaneously. Confirm
   "opposite-side depth" for the easing trigger is counted purely from
   EURGBP's own local layer array, with no path by which cross-instance
   exposure data could factor into it — should be true by design, but
   worth an explicit confirmation given EURGBP's cap complexity
   elsewhere.

5. **Verification path.** Given this project's standing practice of
   requiring real-tick MT5 verification (Model=4) over Python
   Monte Carlo before trusting a calibration question, does porting
   this mechanism to EURGBP need its own real-tick stress-window
   verification pass before being trusted, or is it low-risk enough
   (given GBPUSD/EURUSD's existing validation) to treat as a
   direct port pending only this mechanical audit?

No implementation code in your response. Flag anything above that
should block this from proceeding to Gemini, and any assumption in the
proposed design that doesn't hold once checked against real source.
