# A. EXPECTATIONS, WRITTEN BEFORE ANY DATA

Written: 2026-11-10 23:57 America/Toronto (2026-11-11 04:57 UTC).

State of knowledge when written: I had read `MECHANICS.md`, `sim.py`, `test_sim.py`, `run_bars.py`,
`grind_tick_dump.mq5`, `fxgrind.mq5`, `grind_pure.mqh`, `grind_config.mqh`, `grind_exitq.mqh` and the lattice,
add, re-centre, deal and exit-queue parts of `grind_engine.mqh`. I had NOT opened any bar or tick file (only seen
their names and sizes in a directory listing), any result, any memory file or any past chat. One leak to declare:
the docstring of `run_bars.py` says that the simulator's "market" fill is flawed on bar data ("the flaw,
results.md s2"). That tells me a fill-model issue exists; it says nothing about performance.

All numbers in this file are prior guesses, not measurements.

## A1. What the strategy is, economically

Strip away the plumbing and each side is a **sliding ladder of fixed size**:

- Long side: once the ladder is built, the 7 layers sit (in effective-entry terms) on the 7 grid rungs, spaced
  `add` apart, that end at the running low. With price j rungs above that low the side holds 7 - j layers. Each
  rung up closes one layer for +`exit` (= `add`); each rung back down re-opens it; each NEW low at full depth
  drags the top rung down 7 rungs (a roll), which is a loss of 7 x `add` on that layer's cost basis, of which
  `exit` comes back if price then bounces one rung (net -6 x `add` on the rolled close, -13 x `add` after a
  second roll of the same layer, and so on).
- Short side: the mirror image off the running high.
- So position as a function of price is  q = clip(7 - (p - low)/add, 0, 7) - clip(7 - (high - p)/add, 0, 7).
  It buys every rung down and sells every rung up: a **mean-reversion grid, i.e. a short-gamma / short-realised-
  trend position** at the scale of `add`, with the usual quadratic grid loss replaced by a linear one beyond 7
  rungs (the lattice) and with no stop.
- In round numbers per side: P&L = `add` x (rung-reversals harvested) - 7 x `add` x (new extremes made at full
  depth) - costs, plus a bounded open mark (at most about 21 x `add` per side at the low).
- The L0 logic (first order `width` from mid; the flat side's L0 trailing the mid at `width`..`width`+2 pips) only
  decides where a new ladder starts: it starts a new ladder on a counter-move of roughly `width` pips. It does
  not change the nature of the bet.
- OPT and ALT on a pair are the same bet at two rung sizes. Twelve arms are not twelve independent strategies.

It is **not** market making in the sense of earning the spread. On MT5 a resting buy limit is filled when the
quoted ASK comes down to it, and a sell limit when the BID comes up to it. In mid-price terms every layer buys at
mid + spread/2 and sells at mid - spread/2. "Passive" here avoids slippage beyond the limit; it does not earn the
spread, it pays one full spread per round trip (in the sense that mid must travel `exit` + spread to deliver
`exit`), plus commission.

## A2. What the price path must do for it to make money

For a driftless martingale mid-price, any rule that sets position from the past has zero expected P&L before
costs, however many of its trades are winners. This design is no exception: the many +`add` scalps are paid for,
in expectation exactly, by the rolled closes and the open stack. So:

1. **Gross edge can only come from mean reversion at the rung scale.** After price has moved one `add` to a new
   local extreme, it must come back one `add` before going on one `add` more often than a random walk does
   (more than 50% on an `add`-spaced grid). Equivalent statements: the mean zig-zag leg at threshold `add` is
   shorter than 2 x `add` (Pastukhov's H below 2); the variance of returns over the time it takes to travel
   several rungs is less than proportional to the variance at one rung (variance ratio below 1).
2. **It must persist from 1 rung out to about 7 to 14 rungs**, because the income is collected one rung at a
   time and the losses are paid on travel beyond 7 rungs. Reversion only at 1-2 pips (quote flicker) is useless
   to a 7-pip rung, and reversion at 500 pips is useless to a 7-rung ladder that has already rolled.
3. **The edge must exceed the cost per close.** Cost per close k = spread at the two fills + commission.
   Commission alone is 0.06 USD per close = 0.6 pip on EURUSD/GBPUSD, about 0.45 on EURGBP, 0.84 on AUDCAD,
   0.49 on AUDCHF/CADCHF. With my spread guesses the cost is this share of the rung:

       pair     arm  add   comm(pip)  spread guess(pip)   k/add
       EURUSD   OPT    7     0.60        0.2              ~11%
       EURUSD   ALT   23     0.60        0.2              ~3.5%
       GBPUSD   OPT    9     0.60        0.4              ~11%
       GBPUSD   ALT   15     0.60        0.4              ~7%
       EURGBP   OPT    5     0.45        0.4              ~17%
       EURGBP   ALT   23     0.45        0.4              ~4%
       AUDCAD   OPT   18     0.84        0.8              ~9%
       AUDCAD   ALT   26     0.84        0.8              ~6%
       AUDCHF   OPT   14     0.49        0.8              ~9%
       AUDCHF   ALT   20     0.49        0.8              ~6.5%
       CADCHF   OPT   10     0.49        0.9              ~14%
       CADCHF   ALT   17     0.49        0.9              ~8%

   So the path has to be more reverting than a random walk by an amount worth roughly 4% to 17% of a rung per
   closed layer, and it has to be that reverting on average over all conditions, trends included.
4. Fills must happen at the limit when touched and not be systematically followed by adverse moves beyond what
   the mid-path statistics already contain (spreads widening exactly when the ladder is filling would add to k).

## A3. What I expect it to earn after costs, and why

- **Gross (before spread and commission): about zero**, within noise, on every pair and arm. Liquid FX at 5 to
  25 pips is, to a first approximation, a martingale. Known departures are small: quote-level negative
  autocorrelation below about a pip (too small for these rungs), and some intraday range-bound behaviour in the
  quiet hours around the New York close / early Asia, most visible in low-volatility crosses (EURGBP, AUDCAD,
  the CHF crosses) and exactly where spreads are widest. I would not be surprised by a small positive gross edge
  on the crosses in those hours and a small negative one (momentum) on EURUSD/GBPUSD in London/New York hours.
- **Net: negative on all twelve arms in expectation**, at roughly (closes per day) x k. Rough guesses at 0.01
  lot, taking closes/day as about 0.6 x (daily sigma / add)^2:

       EURUSD OPT (7):   ~25 closes/day, ~ -2 USD/day      EURUSD ALT (23): ~2/day, ~ -0.2 USD/day
       GBPUSD OPT (9):   ~20 closes/day, ~ -2 USD/day      GBPUSD ALT (15): ~8/day, ~ -0.8 USD/day
       EURGBP OPT (5):   ~15 closes/day, ~ -1.7 USD/day    EURGBP ALT (23): <1/day, ~ -0.1 USD/day
       AUDCAD OPT (18):  ~3 closes/day,  ~ -0.3 USD/day    AUDCAD ALT (26): ~1.5/day, ~ -0.2 USD/day
       AUDCHF OPT (14):  ~5 closes/day,  ~ -0.8 USD/day    AUDCHF ALT (20): ~2.5/day, ~ -0.4 USD/day
       CADCHF OPT (10):  ~9 closes/day,  ~ -1.5 USD/day    CADCHF ALT (17): ~3/day, ~ -0.5 USD/day

  These are order-of-magnitude numbers (my sigma and spread guesses could each be off by 30%+). The point is the
  sign and the scaling: the small-rung OPT arms trade most and so should lose most; the wide ALT arms should sit
  near zero with a slightly negative drift that four years of data may not distinguish from zero.
- **Shape of the equity curve:** win rate by trade count high (I would guess 85% or more: seven-ish +`add`
  scalps for every -6 x `add` rolled close), long calm stretches of steady gains while a pair ranges, then
  sharp give-backs in directional moves, when the stack is full, rolls fire and rolled closes of -6 x `add` and
  worse are realised. Negative skew. Realised P&L will run ahead of equity because losers are held (and with
  roll gate 0, a capped side whose opposite side holds layers neither adds nor rolls: it just carries the loss).
  The danger of this shape is that a few good weeks or months look like an edge.
- **Tail:** bounded per arm by the 7-layer cap (0.07 lot per side), so a 300-pip one-way move costs on the order
  of 7 x 300 pips = about 210 USD per EURUSD arm at 0.01, not a blow-up; but there is no stop, and all arms on
  USD or CHF pairs take the same side of a broad move together.
- **Stated probabilities (prior):** that a given small-rung OPT arm is net profitable over the whole 2023-2026
  bar history: under 10%. That a given wide ALT arm is: perhaps 20-30% (mostly noise). That the data shows a
  gross reversion edge large enough to cover k at the live OPT rungs on any pair, robustly across years: about
  10%. I would be changing my mind if the per-rung reversal rate came out several percentage points above 50%
  with tight month-to-month uncertainty, on mid prices, at rungs where k/add is small.

## A4. What would change this view

- A measured `add`-scale reversal probability, on mid prices, whose excess over 50% is worth more than k/add
  for that pair and rung, stable across years and not confined to hours when the spread is several times normal.
- Evidence that fills are better than touch-at-ask (true resting liquidity that earns spread). I see nothing in
  the code that would produce that on these account types.
