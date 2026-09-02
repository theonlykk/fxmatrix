# DeepSeek Prompt — Monte Carlo Grid Simulation (Brownian Bridge)

## Context and why this is a different kind of ask than usual

Normally you operate as Red Team Prime — adversarial critique only, zero
implementation code, per ARCHITECT.md. **This request is explicitly an
exception**, made directly by the Lead Quant: this is a standalone
research/validation tool, not part of the core FXMatrix EA implementation
(MQL5) or its ADR pipeline. We want you to write the actual Python code
this time, specifically because getting the statistical calibration right
is the whole point, and that's your domain — not because we're asking you
to skip critique. Please still flag anything statistically unsound in
what we're proposing, even while writing the code.

## The problem we're trying to solve

FXMatrix (the live strategy this supports) is a grid/martingale-style FX
market-making system. This session's investigation has been limited by
having only a handful of real historical backtest windows (one full
quarter, one ~month-long "blowup" period) to test hypotheses against —
not enough to distinguish genuine structural patterns from small-sample
noise. We want a Monte Carlo simulation that can generate many
statistically plausible price paths and run simplified grid mechanics
against each, to get a real distribution of outcomes rather than a
handful of historical data points.

## What we already tried, and where it broke — please don't repeat this

We built a first attempt: given a series of real M5 close prices, we
generate a **Brownian bridge** between each pair of consecutive closes
(a random path pinned at both known endpoints), to simulate plausible
intra-bar tick movement we don't have real data for. We calibrated the
bridge's diffusion parameter (`sigma`) from the **historical standard
deviation of close-to-close log returns**.

**This calibration produced clearly unrealistic behavior.** For a
synthetic path with a modest ~240 pip total range, the simulated grid
built up to ~27 layers with only ~55-60 realized exits — close to the
theoretical maximum layer count implied by the raw price range, almost
no retracement relief along the way. This does not match what we've
observed in every real backtest this session: even in genuinely trending
months, hundreds of small exits happen (98%+ realized win rates) and max
layer depth rarely exceeds 6-8, not 27, for comparable price ranges.

**Our diagnosis, which you should verify or correct:** using close-to-
close volatility alone likely underestimates genuine intra-bar back-and-
forth relative to net directional movement. Real tick-level FX price
action has meaningfully more "wiggle per unit of net displacement" than
a naive Brownian bridge calibrated this way produces. We suspect this
needs either (a) M5 High/Low range as an additional calibration input,
not just Close, or (b) a fundamentally different noise model, or (c)
calibrating against known real-backtest statistics (e.g., "given this
real close series, tune sigma so realized-exit-frequency matches what
the real MT5 backtest showed") as a fitting target rather than an
independent volatility estimate. **Please think rigorously about this
specific problem before writing the simulation** — this is the one part
that actually needs to be right for the tool to be useful, and it's
exactly the kind of statistical-pathology-hunting you're suited for.

## Grid mechanics to implement (simplified from the real EA)

- **Add spacing: flat 9 pips** between consecutive layers (not the real
  EA's exponential `GridExpBase` formula — deliberately simplified here).
- **Exit: flat 3 pips** per layer, from that layer's own entry price.
- **Exit ordering: LIFO** — the most-recently-added layer's own exit
  target is checked/filled first, matching the real EA's restitution
  logic.
- **Bid/ask spread: fixed 0.4 pips.**
- Three modes to support:
  1. **BUY-only** (mirrors `MM_LONG`)
  2. **SELL-only** (mirrors `MM_SHORT`)
  3. **Flipping** (mirrors `BIAS_BOTH`) — goes flat, then re-enters in
     whichever direction a provided signal indicates. Propose a
     reasonable, clearly-stated simplification for what drives the flip
     if we don't supply an external signal series (e.g., some simple
     price-based rule), and flag it explicitly as a modeling choice, not
     something derived from the real EA's actual strength-ranking logic.

## Required outputs, and a specific mistake to avoid

Track **both realized (closed-trade) and unrealized (mark-to-market at
final price) P&L, separately and combined** — not just realized. We
made exactly this mistake early in the session with the real MT5 logs
(summing only closed-trade P&L, missing large force-closed/still-open
losses) and caught it late; don't reproduce it here.

Also report: max layer depth reached, number of realized trades, and
whether the simulated equity/drawdown would have crossed a 3%/4%
daily-drawdown threshold at any point (matching the real EA's kill-
switch levels) — that's the actual risk question this tool needs to
answer, not just an ending P&L number.

## Monte Carlo requirement

This needs to run **many random realizations** (different RNG seeds)
over the same real close-price series, to produce a distribution of
outcomes (P&L, max depth, drawdown-threshold breaches), not a single
path. Please make the number of realizations and all parameters
(add_pips, exit_pips, spread_pips, sub_steps_per_bar, sigma calibration
method) easily adjustable.

## What we're explicitly asking you to critique, not just implement

1. Is Brownian bridge the right tool for this at all, or is there a
   better-justified stochastic process for modeling FX intra-bar price
   action given only bar closes?
2. How would you calibrate the noise parameter properly, given the
   failure mode described above?
3. Are there other statistical pitfalls in this design — e.g., does
   checking add/exit conditions at every discrete sub-step (rather than
   continuously) introduce a resolution-dependent bias? We found that
   path length (and by extension, apparent crossing frequency) grows
   with the number of sub-steps used per bar, which seems like a real
   sensitivity, not a free parameter to ignore.
4. Any lookahead bias risk in how the bridge is constructed (it's
   pinned at the *next* real close, which is legitimate for pinning to
   real endpoints, but flag if there's a subtlety we're missing).

Please write working Python code (numpy is fine, no other special
dependencies needed) with the calibration approach you land on clearly
explained and justified, not just implemented.
