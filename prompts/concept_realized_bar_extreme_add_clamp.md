# CONCEPT: Realized M5 Bar-Extreme Clamp for Add/Reload Levels

**Status: PARKED — a later iteration, not connected to the current V2.1 imbalance-easing work. Separate mechanism, separate axis (add/reload geometry, not L0 spread).**

**Author:** Khalid, written up by Claude from a live design discussion.
**Date:** 2026-07-27 (early morning, end of a long session)

---

## 1. The core idea, in one sentence

For Add/Reload layers specifically (not L0), after each completed M5 bar, check whether that bar's realized low (for `MM_LONG`) or high (for `MM_SHORT`) extended further in the adverse direction than the already-scheduled next-add level — if so, extend the add level out to match; if not, leave the originally-scheduled level unchanged. The adjustment is **strictly one-directional**: it can only make the next add level *more* favorable to the position (lower for `MM_LONG`'s buy-side add, higher for `MM_SHORT`'s sell-side add), never pull it back toward current price.

**Explicitly not connected to the existing anchor mechanism.** Whatever `Long_ComputeAddTarget` / `Short_ComputeAddTarget` currently compute as the baseline add level (confirmed elsewhere this session to use an "anchor ± step_pips" formula) is untouched by this proposal — this is a separate, subsequent check applied on top of that existing output, not a replacement or modification of the anchor logic itself.

## 2. Motivation

For a flat-state L0 quote, volatility is used explicitly: `dynamic_hs = quote_spread + sigma × SpreadMultiplier`. For every Add/Reload layer beyond L0, there is no explicit volatility term at all — the geometry is fixed arithmetic (`InpWidenRatio`, step pips), and the only thing that lets the system implicitly account for market conditions is the passage of time itself: waiting for the next M5 bar before evaluating whether to add gives the market room to move, but doesn't actually look at *how far* it moved during that wait.

This proposal makes that implicit allowance explicit. Rather than relying purely on elapsed time as an indirect volatility proxy, directly check the realized bar extreme — the actual, already-known outcome of that 5-minute wait — and use it to push the add level out if the market moved further than the fixed geometry alone anticipated. The stated aim: a more timely, evidence-based way of placing the add at the edge of what looks like an emerging mini trading range, rather than a fixed distance decided in advance regardless of what actually happened during the interval.

## 3. Proposed mechanism

- After each M5 bar close, for a stack with a pending next-add level:
  - **`MM_LONG`:** if `bar_low < scheduled_add_level`, extend the add level down to `bar_low` (adjusted for whatever tail-trim rule is settled on, see Section 5). If `bar_low >= scheduled_add_level`, leave the level unchanged.
  - **`MM_SHORT`:** mirrored — if `bar_high > scheduled_add_level`, extend up to `bar_high`; otherwise unchanged.
- The adjustment only ever moves the add level in the direction that requires a larger adverse move before the add fills — it never tightens the level or brings it closer to current price.
- This sits downstream of, and independent from, whatever the anchor formula already computes as the starting scheduled level.

## 4. What this is not

- Not a change to L0 quoting — L0's volatility handling (`sigma`, `SpreadMultiplier`) is untouched.
- Not a replacement for the anchor calculation in `Long_/Short_ComputeAddTarget` — those functions' actual current logic has not yet been read in full; this proposal assumes it sits as a check applied after that computation, but this needs confirming against real source before any implementation.
- Not connected to the V2.1 imbalance-easing work currently being tested — different mechanism, different part of the system (add/reload geometry vs. flat-state spread), deliberately kept separate.

## 5. Open questions, explicitly flagged, needs data before deciding

**Tail-trimming rule, not yet defined.** "Snip the tail off to avoid wild prints" was raised directly by Khalid as a necessary safeguard, but no concrete rule has been specified yet. A single spurious tick spike setting a bar's extreme, with price immediately reverting, could otherwise anchor the add level to a point that never gets genuinely revisited — making the grid *less* responsive than the fixed-geometry baseline, the opposite of the intent. Candidate approaches to evaluate empirically, not chosen yet: trimming by some percentile of the bar's own tick/price distribution if available, or rejecting the extension if the bar's range exceeds some multiple of recent average true range. Needs real data before deciding, same discipline as every other threshold this project has set.

**Anchor stickiness risk, not yet tested.** Related to the above: does extending the add level based on a single bar's extreme create a level that's overly sticky and rarely revisited, versus one that's genuinely more responsive to real, sustained movement? This is an empirical question, not something to reason out on paper.

**Verification standard, given this project's own history.** M5 bar High/Low in the existing OOS CSVs is itself an aggregate derived from real ticks. Using it to drive a decision (not just observe it) is exactly the category of thing that needs genuine real-tick MT5 verification before being trusted — the same lesson this project already paid for once with the SpreadMultiplier=0.125 finding, where a Python-only signal showed a false improvement that real-tick verification directly overturned. Any Python-only test of this mechanism should be treated as a first-pass filter only, never sufficient on its own.

## 6. Explicit scope and status

Parked, later iteration. Not connected to the current V2.1 imbalance-easing effort — that work continues on its own track (currently: testing whether the combined-book netting benefit shows up naturally in historical data, before any implementation is scoped). This concept should be picked up separately, once V2.1's own arc is further along, starting with confirming the actual current `Long_/Short_ComputeAddTarget` source (not yet read this session) before any design work proceeds.
