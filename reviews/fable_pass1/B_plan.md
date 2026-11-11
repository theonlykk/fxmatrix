# B. TEST PLAN, WRITTEN BEFORE RUNNING ANYTHING ON THE DATA

Written: 2026-11-11 00:10 America/Toronto (05:10 UTC), after `A_expectations.md` was saved to
`D:\fxmatrix-exports\fable_review\`, and before any bar or tick file was copied or opened. Nothing in this file
was tuned on the data. Any departure from it forced by the data (file format, gaps, runtime) will be listed in
the report under "Departures from the plan".

## B1. The property the strategy needs (derived from the mechanics)

Per side the EA is a 7-rung ladder sliding with the running extreme (A1). Its gross P&L is a functional of the
mid path sampled on an `add`-spaced grid: +`add` for each rung-reversal harvested, -7 x `add` of cost basis for
each new extreme made at full depth. For a martingale mid the expectation is exactly zero. Hence:

**P (needed property): at rung scale a, the mid price reverses more often than a random walk -- after moving a
to a new node it retraces a before extending a with probability r(a) > 1/2 -- strongly enough, and from 1 rung
out to ~7 rungs, that the reversion income exceeds the cost per close k(a) = commission + spread paid.**

## B2. Tests

Scales (rung a, pips): 3, 4, 5, 6, 7, 8, 9, 10, 12, 14, 15, 17, 18, 20, 23, 26, 30 (the brief's 3-30, containing
every live add), plus 40, 60, 100 for context only. Pairs: the six live pairs. Mid = bid + spread/2.

**T1. Reversal rate r(a) (model-free, the cleanest form of P).** Walk the mid path; start a node at the first
price; each time |mid - node| >= a, record one step (its direction, time, and the spread then) and move the node
to the ACTUAL mid at that sample (not to the grid line; that way a gap or a coarse sample counts as one step and
the null value is exactly 0.5 for any symmetric martingale, sampled however coarsely). r(a) = share of steps
whose direction is opposite to the previous step. Also r by current run length (1, 2, ..., 7+ same-direction
steps so far), since the ladder needs reversion to persist to 7 rungs.
 - Derived effect size: the **one-rung fade expectancy** F(a) = a(2r - 1) pips per trade gross (enter against
   the last step, +a if it reverses, -a if it extends; this is the cap-1 member of the design family), and
   F(a) - k(a) net.

**T2. Variance ratio (model-free, standard).** VR(q) = Var(q-minute mid return) / (q x Var(1-minute return)), and
the same with a 5-minute base, for horizons 5, 15, 60, 240, 1440 minutes, weekends excluded. VR < 1 = reversion.
Descriptive; no pass/fail threshold of its own.

**T3. The ladder functional (the strategy's own payoff, idealised).** My own simulator (independent of `sim.py`,
written from MECHANICS.md): two sides, L0 at mid -/+ width placed once, flat-side re-centre beyond `stranded`
with the deadband, adds every a to cap, exits at effective entry + a, lattice rolls and re-rolls at cap with
roll gate 0, re-roll pause 23:50-00:15. Idealisations: zero latency; a touched limit fills at its own price
(never better); every exit rests (the two-resting-exits queue is equivalent on a continuous path); no carry, no
breaker, no slot/API guards. Three modes:
 - gross: bid = ask = mid, no commission (isolates P);
 - spread: real bid/ask (buy limit fills when ask <= limit, sell limit when bid >= limit), no commission;
 - net: spread mode minus 0.06 USD per close per 0.01 lot, USD per pip from `run_bars.py`.
 Runs: (i) the 12 live arms with their exact (width, add, stranded), cap 7, deadband 2;
 (ii) the scale scan: every a above, width = a/4, stranded = width + 1, deadband 2, cap 7;
 (iii) design scan for "could ANY parameter set work": caps 1, 3, 7, 15 at every a (exit = a), and at cap 7 also
 exit = a/2 and exit = 2a.
 Output per cell: monthly change in equity (realised + open mark, pips and USD at 0.01), closes, rolled closes,
 gross edge per close as % of rung, cost per close as % of rung.

**T4. Hour of day and period.** r(a) and F(a) - k by server hour of the entry step (FTMO server midnight = New
York 17:00); spread by hour; r(a) and the ladder's monthly equity change by calendar year (2023, 2024, 2025,
2026 to date) and by half-year.

**T5. Ticks (IC Markets raw bid/ask; all six pairs; `__h8w` joined to `_oct` without overlap).**
 - r(a) on the tick mid at a = 1, 2, 3, 4, 5, 7, 9, 10, 14, 18, 23 (below 3 only to show where quote-level
   reversion stops);
 - the spread actually paid: spread at the instants of fills against the time-weighted mean spread, by hour;
 - T3 on real ticks (gross / spread / net) for the six live OPT arms and the small-scale scan (a <= 10), weekly;
 - bar-method validation: build M1 bid OHLC + spread from the same ticks, run the bar pipeline on them, and
   compare r(a) and ladder P&L with the tick truth, per scale. This measures how far M1 bars can be trusted at
   small rungs (the order of high and low inside a bar is unknown; I will also run the bars with the opposite
   intra-bar order and report the share of steps that fall inside bars whose range is >= a).

**Bars -> pseudo-ticks:** as `run_bars.py`: open, then low and high in the bar's direction (low first when
close >= open), then close; ask = bid + the bar's spread. Assumption to flag: I do not know whether MT5's bar
"spread" field is the spread at the bar's open, its minimum or its close; costs from bars rest on it, and T5
checks its level against real ticks (another broker, so only roughly).

**Cross-check (if runtime allows):** `sim.py` with the `--fill limit` patch of `run_bars.py` on one or two pairs
at the live parameters, to confirm my simulator and the project's agree on closes and P&L to within the
idealisations.

## B3. Uncertainty

Unit of replication = calendar month for bars (about 46), ISO week for ticks (about 11; expect wide intervals).
Per cell: mean of the monthly (weekly) values, standard error = sd / sqrt(n), t = mean / SE. For pooled rates by
hour: month-block bootstrap (resample whole months, 1000 draws). Never per-tick or per-trade standard errors.

## B4. What counts as "present" and "absent" (fixed now)

Costs used: commission in pips = 0.06 / USD-per-pip; spread = the spread recorded at the fills.

- **Reversal property at (pair, a):**
  PRESENT if monthly mean r(a) - 0.5 has t >= 3 AND F(a) - k(a) > 0 (the fade pays its costs at the point
  estimate). WEAK if t >= 3 but F(a) - k(a) <= 0 (statistically real, economically too small).
  ABSENT if |t| < 2 (no detectable departure from a random walk) or r(a) < 0.5.
- **Live arm (T3 at live parameters):**
  PRESENT if net monthly equity change has mean > 0, t >= 2.5, and is positive in at least 3 of the 4 calendar
  years. ABSENT if the GROSS monthly mean is not above zero with t >= 2 (then there is no evidence of P and the
  expected net is minus the costs), or if net mean < 0 with t <= -2. Otherwise INCONCLUSIVE, and I will say
  which way the point estimate leans and how many more months would be needed to tell.
- **"Anywhere" (the scans; many cells, so a stricter bar):** a cell counts as a candidate only if net t >= 3.5,
  its neighbours in a have the same sign, and it is positive in at least 3 of 4 years. With roughly 6 pairs x 20
  scales x 6 designs, a handful of cells at t ~ 2 are expected by chance and will be reported as such, not as
  findings. A candidate from the bars must not be contradicted by the ticks (same sign of gross edge).
- **Overall answer to "does the data have what the strategy needs":** YES only if the live-arm criterion is
  PRESENT for a clear majority of the 12 arms; NO if it is ABSENT for a clear majority; otherwise MIXED, stated
  per arm.

## B5. Things that would make me distrust my own result

- The bar-method validation (T5) showing a bias in r(a) or ladder P&L at small a that is as large as the effect.
- Results that flip sign with the intra-bar order assumption.
- My simulator and `sim.py` disagreeing by more than the idealisations explain.
- A positive result that lives only in the hours when the recorded spread is several times its median.
