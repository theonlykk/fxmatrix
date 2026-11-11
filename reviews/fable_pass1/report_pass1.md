This message has a line count at the bottom

# PASS 1 (BLIND) -- AN INDEPENDENT LOOK AT THE fxgrind PASSIVE FX GRID

Written 2026-11-11 (America/Toronto) by Claude (Fable 5.2). Every table below is the literal output of a script in
this folder (section 8 says which); prose numbers are taken from those tables.

## 0. DECLARATIONS

- **Memory files and past chats: none opened.** I made no memory read and no past-chat search or read in this
  conversation.
- **Shown to me automatically, not asked for:** a short profile (name, city, professional background, that you run
  FXMatrix as its Lead Quant), a list of standing working preferences, and a listing of memory file names with
  one-line descriptions. I used none of it in the analysis. One item in it does touch results and you should know I
  saw it: a preference line saying research should anchor "on the actual episode (when the fleet started losing /
  the roll flurries)". So I knew, before writing A, that the live fleet has had a losing episode with roll
  flurries. A's reasoning is from the mechanics and would read the same without it, but I cannot prove that to you.
- **Hints inside the permitted files:** `run_bars.py`'s docstring says the simulator's market fill is flawed on bar
  data ("the flaw, results.md s2") and calls its own runs "descriptive, not pre-registered"; `sim.py` and
  `test_sim.py` name PREREG files and a "budget" variant. None says how anything performed.
- **Directory listings:** I listed `D:\fxmatrix\ea` (names only; it also holds compile logs, test files, an archive
  and preset folders, none opened), `bars_ftmo` and `ticks_ic`. Nothing else in either tree was listed or opened.
  Bars for GBPCHF and ticks for AUDNZD, NZDCAD, NZDCHF are there; I did not use them.
- **Outside source:** one web search on what MT5's bar "spread" field holds (MQL5 forum threads and the MQL5 book:
  it is the MINIMUM spread of the minute). Nothing about the project.
- **Their simulator:** I ran `sim.py` (with `run_bars.py`'s limit-fill patch) on two pairs as a cross-check
  (4.10). Those numbers are their model's output produced by me; I did not open `results.md` or any `out_*` folder.
- **Writes:** only `D:\fxmatrix-exports\fable_review\`. No MetaTrader, no broker account.

## 1. THE ANSWER IN SHORT

1. **What the strategy needs** is mean reversion of the mid price at the scale of its rung (`add`), persisting out
   to about 7 rungs, worth more per closed layer than commission plus spread. It is a capped, sliding
   mean-reversion grid; it does not earn the spread (a resting buy limit on MT5 fills when the ASK reaches it).
2. **At the rungs the small arms trade (5 to 10 pips) the data does not have it.** Over 46 months the rung-scale
   reversal rate on EURUSD and GBPUSD is 0.48 to 0.50 on the conservative reading of the bars and 0.51 to 0.54 on
   the optimistic one, against a random walk's 0.50; the small arms need about 0.55 to 0.56 to break even. On
   EURGBP and CADCHF there is a real but small excess (0.51 to 0.53), worth 0.1 to 0.6 pip per trade against 1.0
   to 1.6 pips of cost.
3. **At the live parameters the twelve arms together lose in every bar variant I ran** (January 2023 to October
   2026, FTMO bars, 0.01 lot per layer): -326 USD/month (t -3.9) in the variant that tracks the tick truth best,
   -40 USD/month (t -0.6) in the most favourable one. About 165 USD/month of it is commission. The loss sits in the
   small-rung arms: EURUSD OPT, GBPUSD OPT and EURGBP OPT lose in all four variants and in essentially every year.
4. **Three arms lean positive:** AUDCAD OPT (18), AUDCAD ALT (26) and EURGBP ALT (23), +7 to +21 USD/month each,
   t between 1.1 and 3.7 depending on the variant. AUDCAD is positive in 3 or 4 of the 4 calendar years; EURGBP
   ALT made all its money in 2023-24. By the criteria I fixed in advance that is "inconclusive, leaning positive"
   in the conservative variants and "present" for AUDCAD only in the optimistic ones.
5. **Could any parameter set of this design work?** Not at rungs under about 12 pips on any of the six pairs: more
   than half of all cells scanned have net t <= -2 and none at those rungs is significantly positive. The one
   region that approaches my pre-set bar is AUDCAD at rungs 17 to 26, best with exit = 2 x add (+18 to +23
   USD/month, t 3.0 to 3.6, positive in 3 or 4 of 4 years). It exists because AUDCAD reverted at the 40 to 150 pip
   scale in these four years (after a run of 2 to 4 rungs the reversal rate is 0.52 to 0.59). That is one pair,
   one four-year regime, and one cell of 612 reaching t 3.5. I would call it a hypothesis worth testing out of
   sample, not a finding.
6. **Two assumptions move the result by as much as the effect itself**, and I could not settle either from what I
   was given: whether a touched limit fills at its own price or at the (better) market price of the touching tick
   (worth 0.08 to 0.46 pip per fill; it moves the 12-arm tick-window result from -155 to +125 USD), and how a
   bid-only M1 bar is turned into a path (the intra-bar order alone flips the sign of the gross result on EURUSD
   and GBPUSD). Section 4 carries both through as ranges. Neither rescues the small arms.

## 2. A -- EXPECTATIONS, AS WRITTEN BEFORE THE DATA

Verbatim copy of `A_expectations.md`, which was saved to the review folder before any bar or tick file was copied.

---------------------------------------------------------------------------------------------------------------

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

---------------------------------------------------------------------------------------------------------------

### 2.1 How A held up (written after the results)

- **Right:** the sign and scaling for the small arms. Predicted about -43 USD/month for EURUSD OPT and GBPUSD OPT;
  measured -47 to -118 and -31 to -113. Predicted closes per day 25 / 20 / 15 for the EURUSD / GBPUSD / EURGBP OPT
  arms; measured 38 / 33 / 20. Win rate: 85% of EURUSD OPT closes are plain scalps, 15% rolled closes. The ALT
  arms on EURUSD, AUDCHF and CADCHF sit at about zero (|t| below 1 in every variant), as expected.
- **Wrong:** "gross about zero on every pair and arm". AUDCAD shows a gross edge of +2.9 to +4.4 pips per close
  (t 3.0 to 4.7) and EURGBP ALT +6.2 to +6.5 (t 2.2 to 2.6). I had allowed for a little reversion on the crosses in
  the quiet hours; what the data shows instead is reversion at wide scale (40 pips and up) on AUDCAD, which a
  7-rung ladder of 18 to 26 pip rungs harvests. My AUDCAD forecast (-6 USD/month) has the wrong sign.
- **Not anticipated at all:** that three measurement choices (intra-bar order, the rollover hour on bid-only bars,
  the fill-price convention) are each as large as the edge being looked for. Most of the work went there.

## 3. B -- THE PLAN, AS WRITTEN BEFORE RUNNING ANYTHING

Verbatim copy of `B_plan.md`, saved to the review folder before any data file was copied.

---------------------------------------------------------------------------------------------------------------

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

---------------------------------------------------------------------------------------------------------------

### 3.1 Departures from the plan (all forced by what the calibration or the data showed)

1. **T1's node rule on bars.** The plan reset the node to the sampled price. On bar pseudo-ticks that is badly
   biased: nodes land on bar highs and lows, and a pure random walk then shows r = 0.55 at a 7-pip rung (4.2). On
   bars I use grid nodes instead (the node moves by exactly one rung), which the same calibration shows to be exact
   whenever the bar is smaller than the rung. On ticks I report both rules.
2. **Rollover cleaning and "core hours".** After the first run I saw that on the crosses 10 to 12% of all 5-pip
   steps fell in server hours 23, 0 and 1 with r of 0.60 to 0.70 and recorded spreads of 7 to 11 pips (4.3). That
   is spread blow-out, not price movement, so I (a) built a "clean" path in which bars with a blown-out recorded
   spread are frozen at the last normal mid, and (b) quote T1 verdicts on entries in server hours 2 to 21. This
   was a choice made after seeing data; it lowers the measured reversion, so it works against the strategy.
3. **Fill models.** The plan had one idealised ladder. The cross-check against `sim.py` (4.10) differed by a
   factor of two on AUDCAD, which led to two fill models on bars ("every traversed level fills" and "one resting
   add") and, on ticks, a second fill-price convention (deal at the market of the touching tick). All are reported.
4. **The B4 reversal rule had a hole:** 2 <= t < 3 was not classified. I label it BORDERLINE.
5. **Additions not in the plan:** a grid-phase ensemble and a micro-perturbation test (4.10); the tick ladder for
   all 12 arms and rungs to 30 (the plan said 6 OPT arms and rungs to 10).
6. **Not done:** results by half-year (by calendar year only); the session table in 4.9 shows binomial standard
   errors (a lower bound), the by-hour CSV has the month-block bootstrap; `sim.py` cross-check on two pairs only.

## 4. RESULTS

Conventions. Pips are 0.0001 on all six pairs. USD is at 0.01 lot per layer, pip values and the 0.06 USD commission
per close as in `run_bars.py`. "std" and "alt" are the two possible orders of high and low inside a bar; std is
`run_bars.py`'s. t is always mean over standard error across calendar months (bars, 46 of them) or weeks (ticks).

### 4.1 The data (`00_data_summary.py`, `05_ticks_inventory.py`)

- **Bars:** 1.407 to 1.411 million M1 bars per pair, 2023-01-02 to 2026-10-23, 989 server days, no weekend bars,
  no inconsistent OHLC, 202 breaks longer than a day (weekends, holidays). Server minus GMT was +3 h at the
  dump; all hours below are server hours, and server 00:00 is New York 17:00.
- **The bar spread field is the minimum spread of the minute**, not the spread at any particular price in the
  bar. Its mean is 0.27 pip on EURUSD (19% of bars record zero) and 0.67 to 1.38 on the others. In server hour 0
  its median is 2.5 pips (EURUSD) to 8.3 pips (AUDCHF): on this feed the whole first hour after the New York
  close is a blow-out. I flag 3.3 to 4.2% of bars as blow-out bars (recorded spread above max(3 x median,
  median + 1 pip)); they are 89 to 98% of hour 0.
- **Ticks:** 3.4 to 6.0 million per pair, 2026-08-03 00:00 to 2026-10-21 01:30 (`__h8w` joined to `_oct`; EURUSD
  from `__h8w`, `_w2`, `_hold`, `_win`), no overlap, about 11.3 weeks. Time-weighted spread in hours 2 to 21:
  0.06 pip EURUSD, 0.18 GBPUSD, 0.20 EURGBP, 0.25 to 0.28 on the three crosses; in hour 0: 3.7 to 11.8 pips.
- **Two feeds, two cost levels.** Over the same dates the FTMO bars record 0.45 (EURGBP), 0.93 (AUDCAD), 0.63
  (AUDCHF), 0.83 (CADCHF) pips in core hours where the IC per-minute minimum is 0.08 to 0.14. FTMO's crosses are
  0.4 to 0.8 pip wider than IC's. Mean bar ranges agree within 8%, so it is the same market at different spreads.
  On IC the per-minute mean spread exceeds the per-minute minimum by 0.06 to 0.17 pip, which is how much a bar's
  spread field understates the spread actually paid.

### 4.2 Null calibration: what M1 bars can and cannot tell you (`01_null_calibration.py`, no real data)

A lattice random walk (steps of 0.1 pip, an exact martingale) is cut into M1 bars and pushed through the bar
pipeline. "fine" is the truth; under the null r = 0.5 and the ladder's gross is 0.

```
== sigma/bar 1.26 pips, 400000 bars, mean bar range 1.91 pips
   a | GRID-node r: fine  bar(std) bar(alt) | actual-node r: fine  bar(std) | grid steps fine/bar | ladder gross per close, rungs: fine  bar(std)  bar(alt) | closes fine/bar
    3 | 0.5032  0.5032  0.5462 | 0.5032  0.6030 |  71514/ 71514 | -0.0307  -0.0432  +0.0573 |  62848/ 62541
    4 | 0.5017  0.5017  0.5064 | 0.5017  0.5803 |  39848/ 39848 | -0.0382  -0.0518  -0.0197 |  35066/ 34501
    5 | 0.5045  0.5045  0.5047 | 0.5045  0.5670 |  25635/ 25635 | -0.0305  -0.0364  -0.0156 |  22400/ 22404
    7 | 0.5005  0.5005  0.5005 | 0.5005  0.5489 |  13014/ 13014 | -0.0456  -0.0643  -0.0486 |  11611/ 11557
    9 | 0.5045  0.5045  0.5045 | 0.5045  0.5404 |   7932/  7932 | -0.0859  -0.0958  -0.0834 |   6836/  6957
   10 | 0.4952  0.4952  0.4952 | 0.4952  0.5320 |   6320/  6320 | -0.0963  -0.1250  -0.0924 |   5642/  5459
   14 | 0.5008  0.5008  0.5008 | 0.5008  0.5317 |   3242/  3242 | -0.1139  -0.1082  -0.0849 |   2826/  2811
   18 | 0.4956  0.4956  0.4956 | 0.4956  0.5267 |   1954/  1954 | -0.0989  -0.1009  -0.1009 |   1684/  1681
   23 | 0.4881  0.4881  0.4881 | 0.4881  0.5229 |   1177/  1177 | -0.0709  -0.0778  -0.0778 |   1041/  1042
   30 | 0.4821  0.4821  0.4821 | 0.4821  0.4972 |    698/   698 | -0.1778  -0.1840  -0.1840 |    656/   640

== sigma/bar 3.8 pips, 60000 bars, mean bar range 5.95 pips
   a | GRID-node r: fine  bar(std) bar(alt) | actual-node r: fine  bar(std) | grid steps fine/bar | ladder gross per close, rungs: fine  bar(std)  bar(alt) | closes fine/bar
    3 | 0.4999  0.4471  0.5685 | 0.4999  0.7542 |  95784/ 86497 | -0.0248  -0.1930  +0.3541 |  85637/ 74468
    4 | 0.4985  0.4834  0.6573 | 0.4985  0.7237 |  53848/ 52277 | -0.0201  -0.0916  +0.3881 |  48015/ 45009
    5 | 0.5009  0.4974  0.6749 | 0.5009  0.6921 |  34428/ 34182 | -0.0144  -0.0454  +0.3588 |  30874/ 30382
    7 | 0.5037  0.5036  0.6167 | 0.5037  0.6448 |  17592/ 17588 | -0.0198  -0.0241  +0.2089 |  15158/ 15289
    9 | 0.5055  0.5055  0.5481 | 0.5055  0.6082 |  10771/ 10771 | -0.0094  -0.0311  +0.0867 |   9382/  9297
   10 | 0.4992  0.4992  0.5209 | 0.4992  0.5999 |   8552/  8552 | +0.0022  -0.0333  +0.0272 |   7615/  7347
   14 | 0.5022  0.5022  0.5024 | 0.5022  0.5722 |   4366/  4366 | +0.0455  +0.0384  +0.0679 |   3988/  3917
   18 | 0.5051  0.5051  0.5051 | 0.5051  0.5645 |   2660/  2660 | +0.0288  +0.0326  +0.0319 |   2193/  2237
   23 | 0.5238  0.5238  0.5238 | 0.5238  0.5475 |   1618/  1618 | -0.0176  +0.0096  +0.0818 |   1334/  1337
   30 | 0.5172  0.5172  0.5172 | 0.5172  0.5306 |    962/   962 | -0.1098  -0.0858  +0.0810 |    822/   834
```

- Resetting the node to the sampled price (my original T1) is useless on bars: 0.55 to 0.60 on a random walk.
- Grid nodes with the std order reproduce the truth exactly while bars are smaller than the rung, and read LOW
  when bars are large (0.447 at a 3-pip rung with 6-pip bars); the alt order reads HIGH (0.57 to 0.67).
- The ladder behaves the same way: std is conservative, alt optimistic, and the gap between them is the model
  uncertainty. With EURUSD-like bars it is a few percent of a rung from 5 pips up; in fast markets it is tens of
  percent at 3 to 7 pips. So every bar result below is a bracket [std, alt], and the ticks say where the truth is.

### 4.3 T1: the reversal rate (`02_reversal_bars.py`, `12_report_tables.py`, `06_ticks_tests.py`)

Reversal rate by rung, entries in server hours 2 to 21, clean path; r std (monthly t) / r alt:

```
(a) T1, FTMO bars 2023-01 .. 2026-10, clean path, entries in server hours 2-21: r std (monthly t) / r alt
pair   | a=3                 | a=5                 | a=7                 | a=10                | a=14                | a=20                | a=30                | a=40                | a=60               
EURUSD | 0.465 (-10.7) / 0.548 | 0.481 ( -6.5) / 0.527 | 0.489 ( -3.2) / 0.518 | 0.500 ( +0.3) / 0.518 | 0.494 ( -1.3) / 0.511 | 0.498 ( -0.0) / 0.518 | 0.494 ( -0.7) / 0.512 | 0.511 ( +0.3) / 0.520 | 0.497 ( -0.3) / 0.501
GBPUSD | 0.457 (-20.4) / 0.561 | 0.478 ( -8.8) / 0.537 | 0.487 ( -4.2) / 0.519 | 0.493 ( -2.6) / 0.511 | 0.502 ( +0.3) / 0.514 | 0.499 ( -0.5) / 0.512 | 0.497 ( -1.0) / 0.514 | 0.504 ( -0.3) / 0.519 | 0.491 ( -0.9) / 0.499
EURGBP | 0.505 ( +2.7) / 0.545 | 0.510 ( +2.8) / 0.527 | 0.513 ( +2.9) / 0.526 | 0.523 ( +3.2) / 0.534 | 0.522 ( +2.4) / 0.533 | 0.519 ( +1.4) / 0.529 | 0.520 ( +0.9) / 0.522 | 0.504 ( +0.2) / 0.504 | 0.510 ( -0.6) / 0.510
AUDCAD | 0.485 ( -3.8) / 0.549 | 0.492 ( -1.2) / 0.520 | 0.496 ( +0.0) / 0.514 | 0.499 ( +1.3) / 0.513 | 0.498 ( +0.3) / 0.516 | 0.495 ( -0.3) / 0.515 | 0.524 ( +1.8) / 0.540 | 0.542 ( +3.1) / 0.547 | 0.593 ( +3.6) / 0.593
AUDCHF | 0.483 ( -3.1) / 0.533 | 0.488 ( -1.2) / 0.512 | 0.486 ( -1.7) / 0.502 | 0.490 ( -0.6) / 0.503 | 0.490 ( -0.3) / 0.507 | 0.494 ( -0.5) / 0.508 | 0.488 ( -1.2) / 0.498 | 0.510 ( +0.3) / 0.512 | 0.508 ( -0.2) / 0.508
CADCHF | 0.489 ( -1.9) / 0.540 | 0.497 ( -0.1) / 0.518 | 0.509 ( +2.6) / 0.522 | 0.514 ( +2.7) / 0.528 | 0.504 ( +0.7) / 0.519 | 0.524 ( +1.9) / 0.535 | 0.516 ( +0.6) / 0.523 | 0.499 ( +0.6) / 0.499 | 0.531 ( -0.1) / 0.531
```

The same as money: gross pips per one-rung fade, against the cost per trade k:

```
(a2) the same as gross fade F = a(2r-1) in pips, std / alt, against k = commission + recorded spread (pips)
pair   | a=3             | a=5             | a=7             | a=10            | a=14            | a=20            | a=30            | a=40            | a=60            | k
EURUSD |  -0.21 /  +0.29 |  -0.19 /  +0.27 |  -0.15 /  +0.26 |  -0.00 /  +0.36 |  -0.17 /  +0.31 |  -0.08 /  +0.71 |  -0.37 /  +0.71 |  +0.87 /  +1.58 |  -0.32 /  +0.11 | 0.79
GBPUSD |  -0.26 /  +0.37 |  -0.22 /  +0.37 |  -0.19 /  +0.26 |  -0.14 /  +0.22 |  +0.07 /  +0.39 |  -0.06 /  +0.49 |  -0.20 /  +0.82 |  +0.29 /  +1.54 |  -1.09 /  -0.07 | 1.05
EURGBP |  +0.03 /  +0.27 |  +0.10 /  +0.27 |  +0.19 /  +0.37 |  +0.47 /  +0.68 |  +0.61 /  +0.93 |  +0.77 /  +1.16 |  +1.22 /  +1.32 |  +0.35 /  +0.35 |  +1.21 /  +1.21 | 1.01
AUDCAD |  -0.09 /  +0.29 |  -0.08 /  +0.20 |  -0.05 /  +0.20 |  -0.03 /  +0.26 |  -0.04 /  +0.45 |  -0.21 /  +0.60 |  +1.46 /  +2.39 |  +3.37 /  +3.77 | +11.11 / +11.11 | 1.80
AUDCHF |  -0.10 /  +0.20 |  -0.12 /  +0.12 |  -0.19 /  +0.03 |  -0.19 /  +0.06 |  -0.28 /  +0.19 |  -0.24 /  +0.32 |  -0.74 /  -0.12 |  +0.79 /  +0.93 |  +0.94 /  +0.94 | 1.24
CADCHF |  -0.06 /  +0.24 |  -0.03 /  +0.18 |  +0.13 /  +0.30 |  +0.29 /  +0.56 |  +0.12 /  +0.53 |  +0.96 /  +1.39 |  +0.99 /  +1.38 |  -0.10 /  -0.10 |  +3.77 /  +3.77 | 1.60
```

At the live rungs, with the pre-set verdicts and the tick values alongside:

```
S1. T1 at the live rungs. r = share of rung-sized steps of the mid that reverse the previous step; 0.5 = random walk.
    Bars: FTMO, 46 months, clean path, entries in server hours 2-21, limit convention (node on the grid line);
    std = conservative intra-bar order, alt = optimistic; SE and t across months. F = add x (2r - 1), gross pips per
    one-rung fade; k = commission + recorded spread. Ticks: IC, Aug-Oct 2026, same hours: grid = limit convention,
    act = node at the actual price of the crossing tick (market convention).
pair   arm add |  steps | r std  (SE)     t   | r alt   t   | F std   F alt |   k   | B4 verdict std / alt  | ticks: n   r grid  r act
EURUSD OPT   7 |  40911 | 0.4894 (0.0030)  -3.2 | 0.5183  +3.0 | -0.15  +0.26 | 0.79  | ABSENT     / WEAK       | a=7   1230  0.490   0.514
EURUSD ALT  23 |   3877 | 0.5055 (0.0088)  +1.0 | 0.5259  +3.6 | +0.26  +1.19 | 0.80  | ABSENT     / PRESENT    | a=23   124  0.508   0.477
GBPUSD OPT   9 |  37345 | 0.4904 (0.0030)  -3.1 | 0.5112  +2.3 | -0.17  +0.20 | 1.05  | ABSENT     / BORDERLINE | a=9   1087  0.508   0.542
GBPUSD ALT  15 |  13687 | 0.4986 (0.0049)  -0.5 | 0.5102  +1.8 | -0.04  +0.31 | 1.05  | ABSENT     / ABSENT     | a=14   434  0.502   0.530
EURGBP OPT   5 |  23382 | 0.5101 (0.0047)  +2.8 | 0.5275  +5.7 | +0.10  +0.27 | 1.00  | BORDERLINE / WEAK       | a=5    479  0.522   0.548
EURGBP ALT  23 |   1034 | 0.5058 (0.0165)  +1.1 | 0.5170  +1.6 | +0.27  +0.78 | 1.00  | ABSENT     / ABSENT     | a=23    23  0.435   0.476
AUDCAD OPT  18 |   4473 | 0.4963 (0.0075)  +0.4 | 0.5181  +3.6 | -0.13  +0.65 | 1.81  | ABSENT     / WEAK       | a=18   165  0.497   0.518
AUDCAD ALT  26 |   2183 | 0.5066 (0.0114)  +0.7 | 0.5226  +1.8 | +0.35  +1.18 | 1.81  | ABSENT     / ABSENT     | a=23   108  0.556   0.559
AUDCHF OPT  14 |   4497 | 0.4901 (0.0085)  -0.3 | 0.5069  +1.0 | -0.28  +0.19 | 1.24  | ABSENT     / ABSENT     | a=14   126  0.468   0.460
AUDCHF ALT  20 |   2221 | 0.4939 (0.0131)  -0.5 | 0.5081  +0.3 | -0.24  +0.32 | 1.23  | ABSENT     / ABSENT     | a=18    83  0.518   0.474
CADCHF OPT  10 |   7112 | 0.5143 (0.0070)  +2.7 | 0.5280  +4.2 | +0.29  +0.56 | 1.60  | BORDERLINE / WEAK       | a=10   186  0.511   0.548
CADCHF ALT  17 |   2390 | 0.5130 (0.0112)  +1.5 | 0.5251  +2.2 | +0.44  +0.85 | 1.61  | ABSENT     / BORDERLINE | a=18    52  0.519   0.462
```

Reading:

- **EURUSD, GBPUSD:** the bracket straddles 0.5 at every rung (std 0.46 to 0.50, alt 0.50 to 0.56). On eleven
  weeks of ticks at 3 to 7 pips EURUSD is 0.48 to 0.49 with the node on the grid line and 0.50 to 0.51 with the
  node at the actual price; GBPUSD 0.48 to 0.52 and 0.51 to 0.53 (standard error about 0.01 to 0.02). No reversion
  that I can distinguish from none. The best case for a one-rung fade is +0.2 to +0.4 pip gross against 0.8 to
  1.05 pips of cost.
- **EURGBP:** real and small. 0.505 to 0.523 (std, t 2.7 to 3.2 at rungs 3 to 10), 0.526 to 0.545 (alt). In money:
  +0.03 to +0.47 pip against 1.0 at rungs 3 to 10. Around 14 to 30 pips the fade is worth about its cost (+0.6 to
  +1.3 pips), with t at most 2.4.
- **CADCHF:** 0.509 to 0.514 at 7 to 10 pips (t 2.6 to 2.7), +0.13 to +0.29 pip against 1.6.
- **AUDCAD:** nothing from 5 to 20 pips (0.49 to 0.50 std), then 0.524 at 30, 0.542 at 40 (t 3.1), 0.593 at 60
  (t 3.6). The reversion is at scales two to three live rungs wide.
- **AUDCHF:** none at any rung.
- **By length of the run so far** (how many rungs price has already gone the same way):

```
(f) reversal rate by length of the run so far (number of consecutive same-direction rungs), all hours, clean path: std / alt (n std)
  EURUSD add  7 | 1: 0.487/0.518 (21303) | 2: 0.484/0.514 (10923) | 3: 0.502/0.527 (5633) | 4: 0.496/0.523 (2803) | 5: 0.479/0.522 (1413) | 6: 0.488/0.495 (736) | 7: 0.462/0.508 (377) | 8+: 0.430/0.454 (472)
  GBPUSD add  9 | 1: 0.489/0.512 (19314) | 2: 0.496/0.512 (9860) | 3: 0.495/0.516 (4973) | 4: 0.485/0.507 (2509) | 5: 0.480/0.498 (1292) | 6: 0.452/0.487 (672) | 7: 0.476/0.506 (368) | 8+: 0.472/0.528 (409)
  EURGBP add  5 | 1: 0.508/0.527 (12717) | 2: 0.524/0.536 (6253) | 3: 0.521/0.537 (2976) | 4: 0.512/0.533 (1426) | 5: 0.507/0.527 (696) | 6: 0.513/0.519 (343) | 7: 0.575/0.617 (167) | 8+: 0.423/0.476 (168)
  EURGBP add 23 | 1: 0.492/0.504 (559) | 2: 0.546/0.550 (284) | 3: 0.419/0.454 (129) | 4: 0.595/0.600 (74)
  AUDCAD add 18 | 1: 0.492/0.509 (2410) | 2: 0.485/0.513 (1225) | 3: 0.540/0.571 (631) | 4: 0.524/0.551 (290) | 5: 0.500/0.524 (138) | 6: 0.449/0.492 (69) | 7: 0.632/0.733 (38)
  AUDCAD add 26 | 1: 0.474/0.491 (1184) | 2: 0.531/0.547 (623) | 3: 0.568/0.586 (292) | 4: 0.516/0.566 (126) | 5: 0.508/0.528 (61)
  AUDCHF add 14 | 1: 0.479/0.490 (2355) | 2: 0.509/0.534 (1227) | 3: 0.484/0.498 (603) | 4: 0.506/0.520 (310) | 5: 0.497/0.527 (153) | 6: 0.506/0.522 (77) | 7: 0.474/0.515 (38) | 8+: 0.370/0.381 (54)
  CADCHF add 10 | 1: 0.511/0.522 (3940) | 2: 0.520/0.535 (1927) | 3: 0.541/0.559 (925) | 4: 0.474/0.477 (424) | 5: 0.507/0.537 (223) | 6: 0.473/0.535 (110) | 7: 0.586/0.596 (58) | 8+: 0.545/0.576 (44)
```

  On AUDCAD the reversal rate is highest after a run of 2 to 4 rungs (0.52 to 0.59, against 0.47 to 0.51 after
  one): that is what a ladder harvests, and why its P&L there is better than the one-rung fade suggests. On
  EURUSD the opposite: after 7 or more rungs r falls to 0.43 to 0.46 on the conservative order (0.45 to 0.51 on
  the other). Long runs keep going, which is exactly when the ladder is full and rolling.
- **The rollover on a raw bid-only path** (what a plain bar replay sees; rung 5; r / recorded spread by hour):

```
(b) raw bid-only path (blow-outs left in), rung 5: reversal rate r and mean recorded spread (pips) at the steps, by server hour
EURUSD: 22:0.49/0.2 23:0.52/0.4 0:0.50/3.9 1:0.47/0.4 2:0.46/0.2 3:0.50/0.2 | hours 2-21: 0.481 | all hours: 0.482 | share of steps in hours 23,0,1: 4.6%
GBPUSD: 22:0.52/0.5 23:0.54/1.0 0:0.64/8.3 1:0.50/1.2 2:0.49/0.7 3:0.50/0.6 | hours 2-21: 0.476 | all hours: 0.483 | share of steps in hours 23,0,1: 5.6%
EURGBP: 22:0.58/0.7 23:0.64/1.6 0:0.70/6.9 1:0.59/1.8 2:0.57/0.8 3:0.54/0.8 | hours 2-21: 0.511 | all hours: 0.527 | share of steps in hours 23,0,1: 9.9%
AUDCAD: 22:0.52/1.2 23:0.56/2.1 0:0.60/10.3 1:0.52/2.2 2:0.50/1.2 3:0.50/1.1 | hours 2-21: 0.495 | all hours: 0.503 | share of steps in hours 23,0,1: 10.2%
AUDCHF: 22:0.51/0.9 23:0.60/1.8 0:0.65/10.7 1:0.54/2.9 2:0.48/0.9 3:0.51/0.8 | hours 2-21: 0.490 | all hours: 0.505 | share of steps in hours 23,0,1: 11.7%
CADCHF: 22:0.53/1.2 23:0.62/1.9 0:0.67/10.5 1:0.56/3.8 2:0.45/1.3 3:0.50/1.2 | hours 2-21: 0.499 | all hours: 0.516 | share of steps in hours 23,0,1: 12.0%
```

  On the crosses the raw all-hours rate is 0.8 to 1.7 points above the core-hours rate purely because of hours
  23 to 1, where the "reversals" are the bid being pushed down and released by a 2 to 11 pip spread.
- **The US data hour** (server 15) is the strongest momentum hour: r = 0.44 at 5 pips on EURUSD, GBPUSD, AUDCAD.

```
(c) server hour 15 (US data, 08:30 New York in summer and winter alike), clean path, std order: r (bootstrap SE), n
EURUSD: a=5: 0.439 (0.006) n=9594 | a=7: 0.444 (0.006) n=5165 | a=10: 0.470 (0.010) n=2603
GBPUSD: a=5: 0.439 (0.005) n=13129 | a=7: 0.453 (0.006) n=7140 | a=10: 0.463 (0.007) n=3648
EURGBP: a=5: 0.540 (0.011) n=2526 | a=7: 0.571 (0.013) n=1288 | a=10: 0.580 (0.019) n=574
AUDCAD: a=5: 0.443 (0.007) n=5988 | a=7: 0.456 (0.009) n=3268 | a=10: 0.459 (0.011) n=1670
AUDCHF: a=5: 0.503 (0.009) n=2875 | a=7: 0.504 (0.013) n=1480 | a=10: 0.530 (0.013) n=722
CADCHF: a=5: 0.471 (0.009) n=3370 | a=7: 0.505 (0.011) n=1819 | a=10: 0.483 (0.013) n=894
```

### 4.4 T2: variance ratios (`03_variance_ratio.py`)

```
Variance ratio of the mid, monthly estimates, mean (SE) [t vs 1]. 1.00 = random walk; < 1 = reverting.

base 1 min   q=5 min                 q=15 min                q=60 min                q=240 min               q=1440 min              
EURUSD        0.982 (0.005) [ -3.2]    0.957 (0.009) [ -4.8]    0.933 (0.015) [ -4.5]    0.932 (0.024) [ -2.8]    0.890 (0.036) [ -3.1]    
GBPUSD        0.978 (0.005) [ -4.4]    0.955 (0.009) [ -5.1]    0.936 (0.013) [ -4.8]    0.937 (0.021) [ -3.0]    0.899 (0.033) [ -3.0]    
EURGBP        0.903 (0.006) [-15.9]    0.845 (0.010) [-16.0]    0.811 (0.015) [-13.1]    0.799 (0.025) [ -7.9]    0.729 (0.037) [ -7.4]    
AUDCAD        0.945 (0.006) [ -9.6]    0.908 (0.009) [-10.3]    0.872 (0.013) [ -9.7]    0.849 (0.019) [ -8.1]    0.795 (0.032) [ -6.4]    
AUDCHF        0.944 (0.008) [ -7.0]    0.918 (0.012) [ -6.6]    0.899 (0.019) [ -5.2]    0.887 (0.025) [ -4.6]    0.865 (0.042) [ -3.2]    
CADCHF        0.936 (0.007) [ -9.3]    0.901 (0.010) [ -9.6]    0.866 (0.015) [ -9.1]    0.839 (0.023) [ -7.1]    0.802 (0.041) [ -4.8]    

base 5 min   q=15 min                q=60 min                q=240 min               q=1440 min              
EURUSD        0.974 (0.005) [ -5.2]    0.948 (0.012) [ -4.2]    0.947 (0.023) [ -2.3]    0.906 (0.036) [ -2.6]    
GBPUSD        0.976 (0.005) [ -4.7]    0.956 (0.011) [ -4.2]    0.958 (0.020) [ -2.1]    0.920 (0.035) [ -2.3]    
EURGBP        0.935 (0.006) [-10.8]    0.896 (0.012) [ -8.3]    0.882 (0.025) [ -4.8]    0.803 (0.038) [ -5.2]    
AUDCAD        0.961 (0.005) [ -7.1]    0.922 (0.011) [ -7.4]    0.898 (0.018) [ -5.8]    0.841 (0.033) [ -4.8]    
AUDCHF        0.971 (0.006) [ -4.5]    0.949 (0.015) [ -3.3]    0.937 (0.023) [ -2.8]    0.916 (0.044) [ -1.9]    
CADCHF        0.962 (0.006) [ -6.4]    0.924 (0.012) [ -6.4]    0.894 (0.021) [ -5.1]    0.854 (0.042) [ -3.5]    
```

All below 1. With a 1-minute base most of the deficit is noise in the mid (it is built from a bid and a
minimum spread). With a 5-minute base the majors are at 0.95 to 0.96 at one hour and 0.91 to 0.92 at one day; the
crosses at 0.90 to 0.95 and 0.80 to 0.92. A ratio of 0.90 corresponds to r of about 0.526 if all of it sat at one
scale. This agrees with T1: a few percent of reversion that builds with horizon, strongest on EURGBP, AUDCAD and
CADCHF at the scale of a day. It is a real feature of these pairs in this period. It is small next to the costs
at 5 to 10 pips.

### 4.5 T3 at the live parameters, four years of bars (`04_ladder_bars.py cont|one`, `08_summary.py`)

Four bar variants: fill model "cont" (every add level a pseudo-tick has traversed fills at its limit) or "one"
(one resting add per side, the EA's rule, which on 15-second pseudo-ticks behaves like a very slow EA and gets
better entries in fast moves than a real one would), each with the std and the alt intra-bar order.

```
S2. T3 at the live parameters on FTMO bars (46 months, 0.01 lot), four bar variants:
    fill model cont (every traversed level fills) or one (one resting add, EA-like but slow on bars) x intra-bar order std or alt.
    All four fill at the limit price. Net = recorded bid/ask + 0.06 USD per close. yrs+ = calendar years of 4 with net > 0.
    B4 verdict per variant: A = ABSENT (no gross evidence, or net < 0 with t <= -2), I- / I+ = INCONCLUSIVE leaning -, +, P = PRESENT.
pair   arm add | gross pips/close, 4 variants     | cost/close FTMO (IC) | net USD/month (t), yrs+ : cont-std | cont-alt | one-std | one-alt                                   | verdicts
EURUSD OPT   7 | -0.65  +0.26  -0.42  +0.25     | 0.79 (0.71)          |  -118.1 ( -6.4) 0 |   -49.8 ( -4.7) 0 |   -96.2 ( -5.7) 0 |   -46.6 ( -4.5) 0 | A  A  A  A 
EURUSD ALT  23 | -0.26  +1.20  +0.76  +1.37     | 0.81 (0.74)          |    -8.5 ( -0.9) 1 |    +2.6 ( +0.3) 2 |    -1.1 ( -0.1) 2 |    +5.0 ( +0.5) 3 | A  A  A  A 
GBPUSD OPT   9 | -0.51  +0.42  -0.05  +0.65     | 1.05 (0.87)          |  -113.0 ( -7.1) 0 |   -44.6 ( -3.3) 0 |   -78.7 ( -5.5) 0 |   -31.0 ( -2.3) 1 | A  A  A  A 
GBPUSD ALT  15 | -0.59  +0.55  +0.28  +0.98     | 1.05 (0.86)          |   -40.8 ( -3.2) 0 |   -16.7 ( -1.3) 1 |   -17.8 ( -1.4) 0 |    +0.5 ( +0.0) 3 | A  A  A  I+
EURGBP OPT   5 | +0.33  +0.73  +0.53  +0.80     | 0.99 (0.74)          |   -34.2 ( -3.0) 0 |   -13.7 ( -1.4) 0 |   -25.9 ( -2.6) 0 |   -10.3 ( -1.2) 2 | A  I- A  I-
EURGBP ALT  23 | +6.23  +6.45  +6.24  +6.45     | 1.00 (0.98)          |   +14.7 ( +1.9) 2 |   +15.4 ( +2.2) 3 |   +14.6 ( +1.9) 2 |   +15.0 ( +2.1) 2 | I+ I+ I+ I+
AUDCAD OPT  18 | +2.86  +3.90  +3.75  +4.42     | 1.81 (1.51)          |    +6.8 ( +1.1) 3 |   +16.2 ( +2.7) 4 |   +13.1 ( +2.1) 3 |   +21.5 ( +3.7) 4 | I+ P  I+ P 
AUDCAD ALT  26 | +5.58  +6.46  +7.03  +7.39     | 1.82 (1.39)          |   +12.5 ( +1.8) 4 |   +15.8 ( +2.4) 4 |   +17.1 ( +2.4) 4 |   +20.7 ( +3.1) 4 | I+ I+ I+ P 
AUDCHF OPT  14 | -0.59  +0.32  -0.67  +0.37     | 1.25 (0.91)          |   -23.6 ( -2.0) 1 |   -12.0 ( -1.1) 1 |   -18.8 ( -1.7) 1 |   -14.9 ( -1.5) 1 | A  A  A  A 
AUDCHF ALT  20 | +0.27  +0.99  +0.76  +1.41     | 1.25 (0.79)          |    -5.9 ( -0.5) 2 |    +0.5 ( +0.0) 2 |    -3.8 ( -0.3) 2 |    +3.1 ( +0.3) 2 | A  A  A  A 
CADCHF OPT  10 | +0.19  +0.82  +0.58  +1.06     | 1.60 (0.90)          |   -19.9 ( -1.7) 1 |    -9.0 ( -0.9) 2 |   -14.9 ( -1.4) 1 |    -7.8 ( -0.8) 2 | A  A  A  I-
CADCHF ALT  17 | +1.98  +2.49  +2.24  +2.77     | 1.59 (1.13)          |    +3.7 ( +0.4) 2 |    +2.3 ( +0.3) 2 |    +4.9 ( +0.5) 2 |    +5.2 ( +0.6) 2 | A  A  A  A 

    fleet of 12 arms, cont-std:  -326.1 USD/month (SE 83.9, t -3.9); total -15002; by year: 2023 -4662  2024 -4659  2025 -4857  2026 -822
    fleet of 12 arms, cont-alt:   -93.0 USD/month (SE 64.9, t -1.4); total -4277; by year: 2023 -1319  2024 -2739  2025 -946  2026 +727
    fleet of 12 arms, one-std:  -207.5 USD/month (SE 76.8, t -2.7); total -9547; by year: 2023 -2914  2024 -3675  2025 -3162  2026 +204
    fleet of 12 arms, one-alt:   -39.5 USD/month (SE 63.4, t -0.6); total -1816; by year: 2023 -247  2024 -2224  2025 -530  2026 +1184
```

```
(e) closes and commission of the 12 live arms over 46 months at 0.01 lot, per bar variant
    cont-std: 126118 closes, commission 7567 USD = 165 USD/month
    cont-alt: 138363 closes, commission 8302 USD = 180 USD/month
    one-std: 125630 closes, commission 7538 USD = 164 USD/month
    one-alt: 131910 closes, commission 7915 USD = 172 USD/month
```

Reading:

- **EURUSD OPT, GBPUSD OPT:** net negative with |t| between 2.3 and 7.1 in all four variants, and no positive
  calendar year in any variant except one year of GBPUSD OPT in the most optimistic. The gross edge per close is
  between -0.65 and +0.65 pip and the cost is 0.8 to 1.05. In the conservative variant these two arms are about
  70% of the fleet's loss.
- **EURGBP OPT:** the gross edge is real (+0.33 to +0.80 pip per close, t 2.2 to 6.0) and smaller than the cost
  (0.99 at FTMO's spread, 0.74 at IC's). Net -10 to -34 USD/month; no positive year in three variants.
- **GBPUSD ALT, AUDCHF OPT, CADCHF OPT:** negative point estimates in all or all but one variant, t between
  -3.2 and 0.0. **EURUSD ALT, AUDCHF ALT, CADCHF ALT:** indistinguishable from zero.
- **EURGBP ALT, AUDCAD OPT, AUDCAD ALT:** positive in all four variants; see 4.8 and 4.9 for how solid.
- **The fleet:** negative in all four variants and in every full calendar year (2023, 2024, 2025) in all four;
  2026 to date is the least bad year (-822 to +1184 USD).
- **Rolled closes** are 9 to 15% of closes on every arm, each at -6 rungs or worse, as the mechanics imply.

### 4.6 Which bar variant to believe, and the fill-price convention (`06_ticks_tests.py`, `10_fill_improvement.py`)

Bars built from the IC ticks (bid OHLC and minimum spread, as MT5 stores them) were run through the same four
variants and compared with the ladder on the ticks themselves:

```
S3. Which bar variant is nearest the tick truth? IC ticks Aug-Oct 2026; truth = ladder on ticks, one resting add, real bid/ask,
    limit fills. Bar variants are built from the same ticks (bid OHLC + minimum spread). Sum of pips over scan rungs 3..10.
pair   | tick truth | bars cont-std  cont-alt | bars one-std  one-alt | nearest
EURUSD |     -9238  |     -9806      -736     |     -6982     -1308   | cont-std
GBPUSD |     +4600  |     -2013    +13798     |     +5123    +16726   | one-std
EURGBP |     -1272  |     -1129      -263     |      -552      -184   | cont-std
AUDCAD |     -6827  |     -6940     -1080     |     -3784      +564   | cont-std
AUDCHF |     -9067  |     -9401     -7101     |     -7466     -6067   | cont-std
CADCHF |      +446  |     +1054     +2622     |     +1998     +3093   | cont-std
```

In five pairs of six the most conservative variant (cont-std) is the nearest to the tick truth: within a few
percent of it on EURUSD, AUDCAD and AUDCHF, and the truth is below it on EURGBP and CADCHF. GBPUSD is the
exception (nearest one-std). So the cont-std column of 4.5 is my best estimate at limit-price fills, and the
other three columns lean optimistic.

There is a second convention to consider. MECHANICS s4 says the replay deals a touched limit "at the market" 261
ms later. On real ticks the market at the touching tick is on average better than the limit, because price
arrives in jumps:

```
Price improvement of touched limits under 'deal at the market of the touching tick' (IC ticks, 2026-08-03 .. 2026-10-21).
pair   cell  add | fills | mean improvement per fill (pips) | per close (x2) as % of commission | real bid/ask pips: limit fills -> market fills | net USD: limit -> market
EURUSD OPT    7 |  2363 | 0.252                            |  84%                              |    -639 ->    +102                             |  -132.2 ->   -60.3
EURUSD ALT   23 |   259 | 0.463                            | 154%                              |   -1189 ->    -941                             |  -125.9 ->  -101.5
EURUSD scan   5 |  4050 | 0.228                            |  76%                              |   -1341 ->    -587                             |  -258.3 ->  -179.9
EURUSD scan  10 |  1171 | 0.319                            | 106%                              |    -678 ->    -584                             |  -103.2 ->   -93.2
EURUSD scan  20 |   296 | 0.394                            | 131%                              |   -1514 ->   -1459                             |  -159.8 ->  -154.4
GBPUSD OPT    9 |  1859 | 0.312                            | 104%                              |    +685 ->   +1793                             |   +11.1 ->  +123.8
GBPUSD ALT   15 |   731 | 0.320                            | 107%                              |    -426 ->     -35                             |   -63.8 ->   -25.1
GBPUSD scan   5 |  6348 | 0.215                            |  72%                              |    +299 ->   +2122                             |  -158.5 ->   +22.1
GBPUSD scan  10 |  1564 | 0.304                            | 101%                              |    +961 ->   +1419                             |   +50.6 ->   +95.2
GBPUSD scan  20 |   398 | 0.355                            | 118%                              |    -520 ->    -683                             |   -64.0 ->   -80.0
EURGBP OPT    5 |   924 | 0.080                            |  36%                              |     -30 ->     +75                             |   -31.5 ->   -17.5
EURGBP ALT   23 |    56 | 0.111                            |  49%                              |    -380 ->    -371                             |   -52.3 ->   -51.2
EURGBP scan   5 |   945 | 0.084                            |  37%                              |     -93 ->     +38                             |   -41.0 ->   -23.0
EURGBP scan  10 |   222 | 0.076                            |  34%                              |    -281 ->    -252                             |   -44.3 ->   -40.1
EURGBP scan  20 |    74 | 0.112                            |  50%                              |    -296 ->    -329                             |   -41.8 ->   -46.1
AUDCAD OPT   18 |   363 | 0.266                            |  63%                              |   +1199 ->   +1300                             |   +75.0 ->   +82.2
AUDCAD ALT   26 |   174 | 0.206                            |  49%                              |   +1115 ->   +1253                             |   +75.0 ->   +84.5
AUDCAD scan   5 |  3686 | 0.156                            |  37%                              |   -1647 ->    -960                             |  -225.0 ->  -178.9
AUDCAD scan  10 |   942 | 0.178                            |  42%                              |    +556 ->    +602                             |   +11.2 ->   +14.9
AUDCAD scan  20 |   268 | 0.251                            |  60%                              |   +1429 ->   +1364                             |   +93.9 ->   +89.6
AUDCHF OPT   14 |   264 | 0.143                            |  58%                              |    -175 ->     -69                             |   -28.7 ->   -16.1
AUDCHF ALT   20 |   132 | 0.112                            |  45%                              |    +254 ->    +262                             |   +27.3 ->   +28.2
AUDCHF scan   5 |  1798 | 0.085                            |  35%                              |   -1265 ->   -1003                             |  -205.7 ->  -176.0
AUDCHF scan  10 |   472 | 0.094                            |  38%                              |    -870 ->    -806                             |  -119.7 ->  -112.3
AUDCHF scan  20 |   132 | 0.112                            |  45%                              |    +254 ->    +262                             |   +27.3 ->   +28.2
CADCHF OPT   10 |   370 | 0.079                            |  32%                              |    +295 ->    +190                             |   +24.3 ->   +12.3
CADCHF ALT   17 |   142 | 0.075                            |  31%                              |    +583 ->    +573                             |   +67.0 ->   +65.8
CADCHF scan   5 |  1282 | 0.085                            |  35%                              |     +15 ->     +14                             |   -37.9 ->   -36.5
CADCHF scan  10 |   370 | 0.079                            |  32%                              |    +295 ->    +190                             |   +24.3 ->   +12.3
CADCHF scan  20 |   104 | 0.112                            |  45%                              |    +494 ->    +506                             |   +57.4 ->   +58.9
all 12 live arms, net USD over the window: limit fills -155 ; market fills +125
```

A quarter to half a pip per fill on EURUSD and GBPUSD is the same size as the commission. Whether live fills
actually receive it is an execution fact about the broker that I cannot check in pass 1. Note also what it is
not: it is not an edge. With the node at the actual price the tick path is a random walk (r 0.50 to 0.51 on
EURUSD); the "improvement" only removes a penalty that the limit-price convention adds (being filled at L when
the market is already through L). Applied to the four-year bars as a first-order adjustment:

```
S2b. The same with the replay's fill convention approximated: a touched limit deals at the market, which on IC ticks is
     better than the limit by d pips per fill on average (10_fill_improvement.py). Bars cannot see this; first-order
     adjustment: net + 2 x d x closes x USD-per-pip. Range over the four bar variants. This assumes the broker passes the
     improvement on and that d on FTMO equals d on IC; neither is checked here.
pair   arm add |  d (pips/fill) | net USD/month at limit fills: min .. max | with market-fill adjustment: min .. max
EURUSD OPT   7 |  0.25          |  -118.1 ..   -46.6                       |   -76.9 ..    -2.9
EURUSD ALT  23 |  0.46          |    -8.5 ..    +5.0                       |    -1.1 ..   +12.9
GBPUSD OPT   9 |  0.31          |  -113.0 ..   -31.0                       |   -68.5 ..   +15.1
GBPUSD ALT  15 |  0.32          |   -40.8 ..    +0.5                       |   -24.2 ..   +18.1
EURGBP OPT   5 |  0.08          |   -34.2 ..   -10.3                       |   -25.2 ..    -0.9
EURGBP ALT  23 |  0.11          |   +14.6 ..   +15.4                       |   +15.2 ..   +16.1
AUDCAD OPT  18 |  0.27          |    +6.8 ..   +21.5                       |   +10.2 ..   +24.9
AUDCAD ALT  26 |  0.21          |   +12.5 ..   +20.7                       |   +13.8 ..   +22.1
AUDCHF OPT  14 |  0.14          |   -23.6 ..   -12.0                       |   -20.9 ..    -9.0
AUDCHF ALT  20 |  0.11          |    -5.9 ..    +3.1                       |    -4.7 ..    +4.2
CADCHF OPT  10 |  0.08          |   -19.9 ..    -7.8                       |   -17.3 ..    -5.1
CADCHF ALT  17 |  0.08          |    +2.3 ..    +5.2                       |    +3.1 ..    +6.0
    sum of the 12 arms (sum of per-arm minima .. sum of per-arm maxima): limit fills -328 .. -36 USD/month ; adjusted -196 .. +101 USD/month
```

Under the market convention the conservative end improves to about -77, -69 and -25 USD/month for the three
small OPT arms. They reach zero only if one also takes the most optimistic bar variant, which 4.6's first table
advises against.

### 4.7 T3 on real ticks, August to October 2026 (`06_ticks_tests.py`, `08_summary.py`)

```
S4. Live arms on IC ticks, 2026-08-03 .. 2026-10-21 (12 calendar weeks touched), one resting add, real bid/ask,
    0.06 USD per close. limit = touched limits fill at their price; market = at the touching tick's market when better.
pair   arm add | closes | gross pips (%/rung, weekly t) | spread at fills | net USD, limit fills (per week, t) | net USD, market fills
EURUSD OPT   7 |   1139 |    -529 (  -6.5, -0.6)       | 0.11            |  -132.2 (-11.02, -1.4)          |   -60.3 ( -5.03, -0.6)
EURUSD ALT  23 |    117 |   -1201 ( -44.3, -1.1)       | 0.14            |  -125.9 (-10.49, -1.2)          |  -101.5 ( -8.46, -0.9)
GBPUSD OPT   9 |    957 |   +1351 ( +15.5, +1.0)       | 0.27            |   +11.1 ( +0.92, +0.1)          |  +123.8 (+10.32, +0.9)
GBPUSD ALT  15 |    353 |    -143 (  -2.6, -0.1)       | 0.26            |   -63.8 ( -5.32, -0.5)          |   -25.1 ( -2.09, -0.2)
EURGBP OPT   5 |    458 |    +129 (  +5.0, +0.4)       | 0.29            |   -31.5 ( -2.62, -0.6)          |   -17.5 ( -1.46, -0.3)
EURGBP ALT  23 |     24 |    -377 ( -68.3, -1.3)       | 0.53            |   -52.3 ( -4.36, -1.4)          |   -51.2 ( -4.27, -1.4)
AUDCAD OPT  18 |    176 |   +1595 ( +48.2, +2.2)       | 0.67            |   +75.0 ( +6.25, +1.4)          |   +82.2 ( +6.85, +1.6)
AUDCAD ALT  26 |     78 |   +1393 ( +60.2, +2.3)       | 0.55            |   +75.0 ( +6.25, +1.8)          |   +84.5 ( +7.04, +1.9)
AUDCHF OPT  14 |    122 |    -297 ( -16.6, -0.6)       | 0.41            |   -28.7 ( -2.39, -0.4)          |   -16.1 ( -1.34, -0.2)
AUDCHF ALT  20 |     62 |    +377 ( +27.7, +0.6)       | 0.29            |   +27.3 ( +2.27, +0.4)          |   +28.2 ( +2.35, +0.4)
CADCHF OPT  10 |    194 |    +369 ( +18.4, +0.8)       | 0.41            |   +24.3 ( +2.03, +0.4)          |   +12.3 ( +1.02, +0.2)
CADCHF ALT  17 |     68 |    +594 ( +49.9, +1.1)       | 0.63            |   +67.0 ( +5.59, +1.1)          |   +65.8 ( +5.49, +1.0)
    all 12 arms: limit fills -155 USD ; market fills +125 USD
```

Eleven weeks cannot separate any arm from zero (every weekly |t| is under 2.3). For what the signs are worth,
they agree with the bars: EURUSD negative, AUDCAD positive, the fleet near zero and on either side of it
depending on the fill convention.

The same ticks show what the rollover does to a plain bar replay. "raw" is `run_bars.py`'s construction:

```
S5. What a plain bar replay sees at the rollover (bars built from the IC ticks, so the truth is known). Ladder, cap 7,
    width add/4, every traversed level fills, Aug-Oct 2026. raw = bid OHLC + minimum spread, blow-out bars left in
    (run_bars.py's construction); std = the same with blow-out bars frozen. Pips over the window.
pair   add | GROSS (mid): tick truth    raw    std | REAL BID/ASK: tick truth    raw    std | raw - truth, USD per year at 0.01 lot
EURUSD   5 |                -1416   -1422   -1477 |                 -1597   -1432   -1457 |    +76
EURUSD  10 |                 -770    -572    -712 |                  -870    -662    -602 |    +96
GBPUSD   5 |                +1054   +1545    +595 |                  -357     +53     -97 |   +190
GBPUSD  10 |                 +568    +424    +304 |                  +598    +244    +134 |   -164
EURGBP   5 |                 +208    +869     +18 |                  -113    +235     +54 |   +215
EURGBP  10 |                 -318      -4    -244 |                  -282    -159    -265 |    +76
AUDCAD   5 |                 -657    +230   -1165 |                 -1953   -1217   -1487 |   +243
AUDCAD  10 |                 +588    +961    +741 |                  +566    +500    +670 |    -22
AUDCHF   5 |                 -887      +8    -947 |                 -1472   -1041   -1381 |   +243
AUDCHF  10 |                 -897    -727   -1047 |                 -1031    -848    -958 |   +103
CADCHF   5 |                 +138    +672     +47 |                   -51    +106     -14 |    +89
CADCHF  10 |                 +369    +398    +268 |                  +279    +385    +305 |    +60
```

At a 5-pip rung the raw bar path overstates the gross result on every cross, by hundreds of pips in eleven
weeks, and the result at real bid/ask by 90 to 240 USD per year per 0.01-lot arm. At 10 pips the effect is
smaller and of mixed sign. Freezing the blow-out bars (std) removes half to most of it.

### 4.8 Could any parameter set work? The scans (`04_ladder_bars.py`, `12_report_tables.py`, `08_summary.py`)

Cap 7, exit = add, by rung; then the same with exit = 2 x add:

```
(d) scale scan, cap 7, exit = add, width = add/4, FTMO bars, recorded bid/ask + commission, limit fills:
    net USD/month at 0.01 lot, cont-std (t)  ..  one-alt (t)   [the most conservative and the most optimistic bar variant]
pair   | add 5                     | add 7                     | add 10                    | add 14                    | add 17                    | add 20                    | add 23                    | add 26                    | add 30                   
EURUSD |   -224 ( -7.2) ..   -90 (-6.3) |   -117 ( -6.4) ..   -45 (-4.5) |    -60 ( -5.1) ..   -16 (-1.6) |    -34 ( -3.6) ..    +2 (+0.2) |    -29 ( -2.5) ..    +6 (+0.5) |    -17 ( -1.7) ..    +4 (+0.4) |     -8 ( -0.8) ..    +3 (+0.3) |     -1 ( -0.1) ..    +8 (+0.8) |     +3 ( +0.3) ..    +6 (+0.6)
GBPUSD |   -348 (-11.8) ..  -142 (-7.2) |   -184 ( -9.8) ..   -66 (-4.5) |    -86 ( -6.3) ..   -19 (-1.5) |    -47 ( -3.6) ..    -6 (-0.5) |    -35 ( -2.9) ..    +2 (+0.1) |    -23 ( -1.6) ..    +2 (+0.1) |    -15 ( -1.1) ..    +9 (+0.7) |     -2 ( -0.1) ..   +13 (+0.9) |     -7 ( -0.5) ..   +12 (+0.8)
EURGBP |    -34 ( -3.0) ..   -10 (-1.2) |    -16 ( -2.0) ..    +0 (+0.0) |     -5 ( -0.8) ..    +7 (+1.0) |     +3 ( +0.4) ..   +11 (+1.5) |     +6 ( +0.8) ..   +10 (+1.3) |    +16 ( +2.1) ..   +18 (+2.4) |    +14 ( +1.7) ..   +13 (+1.8) |    +14 ( +2.0) ..   +15 (+2.1) |    +11 ( +1.6) ..   +13 (+1.8)
AUDCAD |   -141 ( -6.6) ..   -93 (-7.1) |    -74 ( -5.5) ..   -44 (-4.4) |    -25 ( -2.8) ..    -7 (-1.0) |     -5 ( -0.6) ..    +9 (+1.4) |    +10 ( +1.4) ..   +20 (+2.7) |    +15 ( +2.1) ..   +20 (+3.3) |    +15 ( +2.3) ..   +21 (+3.6) |    +13 ( +1.8) ..   +21 (+3.1) |    +12 ( +1.8) ..   +16 (+2.2)
AUDCHF |   -118 ( -4.0) ..   -76 (-4.2) |    -72 ( -3.2) ..   -41 (-2.9) |    -40 ( -2.6) ..   -16 (-1.4) |    -24 ( -2.0) ..   -15 (-1.5) |    -14 ( -1.1) ..    -1 (-0.1) |     -6 ( -0.5) ..    +3 (+0.3) |     -3 ( -0.3) ..    +1 (+0.1) |     -5 ( -0.5) ..    +2 (+0.3) |     +0 ( +0.0) ..    +2 (+0.3)
CADCHF |    -79 ( -5.4) ..   -52 (-4.6) |    -43 ( -3.5) ..   -27 (-2.7) |    -20 ( -1.7) ..    -8 (-0.8) |     -0 ( -0.0) ..    +5 (+0.5) |     +3 ( +0.3) ..    +6 (+0.6) |     +2 ( +0.2) ..    +5 (+0.6) |     +6 ( +0.8) ..   +10 (+1.2) |     +5 ( +0.6) ..    +9 (+1.1) |    +12 ( +1.5) ..   +12 (+1.5)

(d2) the same with exit = 2 x add
pair   | add 5                     | add 7                     | add 10                    | add 14                    | add 17                    | add 20                    | add 23                    | add 26                    | add 30                   
EURUSD |   -104 ( -5.4) ..   -81 (-4.9) |    -50 ( -3.9) ..   -40 (-3.5) |    -25 ( -2.4) ..   -20 (-1.8) |    -10 ( -0.9) ..    -4 (-0.3) |     -2 ( -0.2) ..    +1 (+0.1) |     -1 ( -0.1) ..    +1 (+0.1) |     -2 ( -0.2) ..    +0 (+0.0) |     +4 ( +0.4) ..    +6 (+0.6) |     +2 ( +0.2) ..    +6 (+0.6)
GBPUSD |   -159 ( -7.9) ..  -127 (-7.2) |    -77 ( -5.3) ..   -61 (-4.4) |    -25 ( -2.0) ..   -14 (-1.1) |     -7 ( -0.5) ..    -0 (-0.0) |     -2 ( -0.1) ..    +0 (+0.0) |     +6 ( +0.4) ..    +8 (+0.6) |     -8 ( -0.6) ..    -2 (-0.2) |     +1 ( +0.1) ..    +5 (+0.3) |     +0 ( +0.0) ..    +1 (+0.1)
EURGBP |    -10 ( -1.2) ..    -5 (-0.7) |     +1 ( +0.1) ..    +1 (+0.2) |     +6 ( +0.8) ..    +7 (+0.9) |    +10 ( +1.3) ..   +10 (+1.2) |    +11 ( +1.4) ..   +11 (+1.4) |    +13 ( +1.7) ..   +12 (+1.6) |    +15 ( +1.9) ..   +15 (+1.9) |    +16 ( +2.0) ..   +12 (+1.5) |    +13 ( +1.6) ..   +13 (+1.6)
AUDCAD |    -71 ( -5.3) ..   -61 (-4.6) |    -34 ( -3.4) ..   -29 (-3.1) |     +1 ( +0.2) ..    +3 (+0.4) |    +11 ( +1.4) ..   +15 (+2.1) |    +22 ( +3.2) ..   +22 (+3.3) |    +19 ( +3.0) ..   +22 (+3.3) |    +23 ( +3.5) ..   +22 (+3.6) |    +13 ( +1.9) ..   +14 (+2.0) |    +15 ( +2.1) ..   +15 (+2.2)
AUDCHF |    -59 ( -2.9) ..   -54 (-3.1) |    -35 ( -2.1) ..   -30 (-2.2) |    -21 ( -1.7) ..   -17 (-1.4) |    -14 ( -1.2) ..   -11 (-1.1) |    -10 ( -0.9) ..    -9 (-0.8) |     -7 ( -0.7) ..    -6 (-0.6) |     -6 ( -0.5) ..    -5 (-0.5) |    -11 ( -1.0) ..    -5 (-0.5) |     +4 ( +0.4) ..    +5 (+0.5)
CADCHF |    -27 ( -2.8) ..   -22 (-2.3) |    -20 ( -2.2) ..   -18 (-2.0) |     -8 ( -0.7) ..    -8 (-0.8) |     +3 ( +0.3) ..    +3 (+0.3) |    +10 ( +1.1) ..   +10 (+1.0) |     +4 ( +0.5) ..    +5 (+0.6) |     +8 ( +0.9) ..   +10 (+1.1) |     +5 ( +0.6) ..    +7 (+0.9) |    +10 ( +1.3) ..   +14 (+1.9)
    (here the two columns are cont-std and one-std; the design cells were run on the std path only)
```

```
S7. The best cells of the scans (FTMO bars, std path, recorded bid/ask + commission, limit fills), ranked by net t.
    6 pairs x 20 rungs x 6 designs = 720 cells per fill model; the largest t expected by chance alone is about 3.
  fill model cont, rungs 3..30
    AUDCAD exit2a   add  23 : net  +22.58 USD/month, t +3.5, years+ 4/4, closes/day 1.2, maxDD 2189 pips
    AUDCAD exit2a   add  18 : net  +18.28 USD/month, t +3.4, years+ 4/4, closes/day 1.8, maxDD 2179 pips
    AUDCAD exit2a   add  17 : net  +21.69 USD/month, t +3.2, years+ 3/4, closes/day 2.2, maxDD 2516 pips
    AUDCAD exit2a   add  20 : net  +19.22 USD/month, t +3.0, years+ 4/4, closes/day 1.5, maxDD 2058 pips
    AUDCAD cap7     add  23 : net  +14.93 USD/month, t +2.3, years+ 4/4, closes/day 2.6, maxDD 2430 pips
    AUDCAD exit2a   add  30 : net  +14.89 USD/month, t +2.1, years+ 4/4, closes/day 0.7, maxDD 2325 pips
    EURGBP cap7     add  20 : net  +15.53 USD/month, t +2.1, years+ 3/4, closes/day 1.2, maxDD 1754 pips
    AUDCAD cap7     add  20 : net  +14.54 USD/month, t +2.1, years+ 3/4, closes/day 3.4, maxDD 2270 pips
    cells with net t >= 3.5: 1 of 612 ; net t >= 2: 11 ; net t <= -2: 356 ; by pair, cells with net t >= 2: EURUSD 0 GBPUSD 0 EURGBP 2 AUDCAD 8 AUDCHF 0 CADCHF 1
  fill model cont, rungs 40..100 (context only)
    AUDCAD cap3     add  40 : net   +7.41 USD/month, t +2.6, years+ 3/4, closes/day 0.8, maxDD 1073 pips
    AUDCAD cap3     add  60 : net   +6.53 USD/month, t +2.4, years+ 4/4, closes/day 0.3, maxDD 990 pips
    CADCHF cap7     add  60 : net  +11.21 USD/month, t +2.0, years+ 4/4, closes/day 0.2, maxDD 1767 pips
    EURGBP cap15    add 100 : net  +12.24 USD/month, t +1.9, years+ 3/4, closes/day 0.1, maxDD 1080 pips
    EURGBP cap7     add 100 : net  +11.95 USD/month, t +1.9, years+ 3/4, closes/day 0.1, maxDD 1080 pips
    EURGBP cap3     add 100 : net   +5.59 USD/month, t +1.8, years+ 3/4, closes/day 0.1, maxDD 443 pips
    CADCHF exit2a   add  40 : net  +12.07 USD/month, t +1.8, years+ 4/4, closes/day 0.2, maxDD 2306 pips
    CADCHF exit2a   add  60 : net  +11.75 USD/month, t +1.8, years+ 4/4, closes/day 0.1, maxDD 1672 pips
    cells with net t >= 3.5: 0 of 108 ; net t >= 2: 3 ; net t <= -2: 3 ; by pair, cells with net t >= 2: EURUSD 0 GBPUSD 0 EURGBP 0 AUDCAD 2 AUDCHF 0 CADCHF 1
  fill model one, rungs 3..30
    AUDCAD exit2a   add  23 : net  +21.88 USD/month, t +3.6, years+ 4/4, closes/day 1.2, maxDD 2189 pips
    AUDCAD exit2a   add  18 : net  +19.56 USD/month, t +3.4, years+ 3/4, closes/day 1.8, maxDD 2002 pips
    AUDCAD exit2a   add  20 : net  +21.67 USD/month, t +3.3, years+ 4/4, closes/day 1.6, maxDD 2058 pips
    AUDCAD exit2a   add  17 : net  +22.34 USD/month, t +3.3, years+ 3/4, closes/day 2.2, maxDD 2466 pips
    AUDCAD cap7     add  23 : net  +17.53 USD/month, t +2.6, years+ 4/4, closes/day 2.6, maxDD 2409 pips
    AUDCAD cap7     add  20 : net  +15.79 USD/month, t +2.4, years+ 3/4, closes/day 3.4, maxDD 2212 pips
    AUDCAD cap7     add  26 : net  +17.07 USD/month, t +2.4, years+ 4/4, closes/day 2.0, maxDD 2538 pips
    AUDCAD exit2a   add  15 : net  +16.12 USD/month, t +2.2, years+ 3/4, closes/day 2.7, maxDD 3107 pips
    cells with net t >= 3.5: 1 of 612 ; net t >= 2: 15 ; net t <= -2: 325 ; by pair, cells with net t >= 2: EURUSD 0 GBPUSD 0 EURGBP 2 AUDCAD 12 AUDCHF 0 CADCHF 1
  fill model one, rungs 40..100 (context only)
    AUDCAD cap3     add  40 : net   +7.90 USD/month, t +2.8, years+ 3/4, closes/day 0.8, maxDD 1073 pips
    AUDCAD cap3     add  60 : net   +7.66 USD/month, t +2.8, years+ 4/4, closes/day 0.3, maxDD 955 pips
    CADCHF cap7     add  60 : net  +11.21 USD/month, t +2.0, years+ 4/4, closes/day 0.2, maxDD 1767 pips
    EURGBP cap15    add 100 : net  +12.24 USD/month, t +1.9, years+ 3/4, closes/day 0.1, maxDD 1080 pips
    EURGBP cap7     add 100 : net  +11.95 USD/month, t +1.9, years+ 3/4, closes/day 0.1, maxDD 1080 pips
    EURGBP cap3     add 100 : net   +5.59 USD/month, t +1.8, years+ 3/4, closes/day 0.1, maxDD 443 pips
    CADCHF exit2a   add  40 : net  +12.07 USD/month, t +1.8, years+ 4/4, closes/day 0.2, maxDD 2306 pips
    CADCHF exit2a   add  60 : net  +11.75 USD/month, t +1.8, years+ 4/4, closes/day 0.1, maxDD 1672 pips
    cells with net t >= 3.5: 0 of 108 ; net t >= 2: 3 ; net t <= -2: 3 ; by pair, cells with net t >= 2: EURUSD 0 GBPUSD 0 EURGBP 0 AUDCAD 2 AUDCHF 0 CADCHF 1
```

```
S8. By calendar year, the three arms that lean positive: NET USD at 0.01 lot, cont-std / cont-alt / one-std / one-alt.
  EURGBP ALT 23 : 2023  +513/ +531/ +509/ +521   2024  +192/ +216/ +192/ +216   2025   -21/  -52/  -24/  -35   2026    -5/  +16/   -5/  -10
  AUDCAD OPT 18 : 2023   +18/ +153/ +213/ +326   2024   -79/  +29/  -33/  +37   2025  +262/ +408/ +288/ +402   2026  +113/ +156/ +134/ +225
  AUDCAD ALT 26 : 2023  +132/ +217/ +265/ +351   2024   +18/  +30/  +31/  +50   2025  +215/ +248/ +223/ +253   2026  +211/ +231/ +267/ +299
```

Reading:

- **Small rungs lose everywhere.** At 5 and 7 pips every pair is negative in the conservative variant with t
  from -2.0 to -11.8, and only EURGBP gets to zero in the optimistic one. Across all 612 cells with rungs of 3 to
  30 pips, 325 to 356 have net t <= -2.
- **EURUSD and GBPUSD cross zero at about 20 to 26 pips and stay there:** no evidence of an edge at any rung,
  cap or exit; the cost simply stops mattering as trades become rare.
- **AUDCAD is positive from about 15 pips up,** peaking at 17 to 26: +10 to +21 USD/month with exit = add (t 1.4
  to 3.6 across variants), +19 to +23 with exit = 2 x add at 17 to 23 (t 3.0 to 3.6), positive in 3 or 4 of 4
  years, maximum drawdown about 2,000 to 2,500 pips (150 to 180 USD at 0.01). One cell reaches my pre-set t >= 3.5 in each fill
  model; its neighbours agree in sign. Eleven to fifteen cells at t >= 2 sound like a lot, but 8 to 12 of them are
  this one AUDCAD neighbourhood and are one finding, not twelve.
- **EURGBP at 20 to 26 pips:** +14 to +18 USD/month, t 1.7 to 2.4. By year (S8) it is 2023 and 2024 only; 2025
  and 2026 are zero. I would not count on it.
- **Caps:** cap 1 is negative at every rung from 3 to 30 pips on every pair, significantly so below 20 (it has
  almost no variance, so the cost shows plainly); cap 15 is like cap 7 with more noise; cap 3 is in between. Nothing in the design
  family changes the picture; the rung does.

### 4.9 Hour of day and period (`02_reversal_bars.py`, `08_summary.py`)

```
S6. Reversal rate by session (FTMO bars, clean path, std order; server hours; server 00:00 = New York 17:00).
    binomial SE in brackets (a lower bound on the true uncertainty). Fnet = a(2r-1) - commission - recorded spread.
  EURUSD a= 5 | 1-8 Asia: r=0.479 (0.004) n=13028 Fnet=-1.00 | 9-14 London: r=0.493 (0.003) n=24910 Fnet=-0.85 | 15-21 NY: r=0.473 (0.002) n=43053 Fnet=-1.07 | 22-23 late: r=0.494 (0.009) n=3186 Fnet=-0.92
  EURUSD a=10 | 1-8 Asia: r=0.494 (0.009) n=3347 Fnet=-0.91 | 9-14 London: r=0.499 (0.006) n=6164 Fnet=-0.79 | 15-21 NY: r=0.497 (0.005) n=11290 Fnet=-0.86 | 22-23 late: r=0.501 (0.017) n=821 Fnet=-0.84
  GBPUSD a= 5 | 1-8 Asia: r=0.491 (0.004) n=17171 Fnet=-1.24 | 9-14 London: r=0.480 (0.002) n=40188 Fnet=-1.22 | 15-21 NY: r=0.471 (0.002) n=61581 Fnet=-1.33 | 22-23 late: r=0.519 (0.008) n=4142 Fnet=-0.94
  GBPUSD a=10 | 1-8 Asia: r=0.500 (0.008) n=4266 Fnet=-1.16 | 9-14 London: r=0.490 (0.005) n=10359 Fnet=-1.23 | 15-21 NY: r=0.490 (0.004) n=16137 Fnet=-1.24 | 22-23 late: r=0.508 (0.016) n=996 Fnet=-0.97
  EURGBP a= 5 | 1-8 Asia: r=0.545 (0.009) n=2775 Fnet=-0.62 | 9-14 London: r=0.495 (0.005) n=10256 Fnet=-1.03 | 15-21 NY: r=0.518 (0.005) n=11011 Fnet=-0.83 | 22-23 late: r=0.577 (0.020) n=615 Fnet=-0.35
  EURGBP a=10 | 1-8 Asia: r=0.553 (0.020) n=600 Fnet=-0.00 | 9-14 London: r=0.499 (0.010) n=2578 Fnet=-1.01 | 15-21 NY: r=0.543 (0.010) n=2626 Fnet=-0.16 | 22-23 late: r=0.519 (0.040) n=158 Fnet=-0.73
  AUDCAD a= 5 | 1-8 Asia: r=0.485 (0.004) n=18249 Fnet=-2.04 | 9-14 London: r=0.510 (0.004) n=14190 Fnet=-1.65 | 15-21 NY: r=0.488 (0.003) n=27039 Fnet=-1.90 | 22-23 late: r=0.530 (0.010) n=2354 Fnet=-1.76
  AUDCAD a=10 | 1-8 Asia: r=0.486 (0.007) n=4660 Fnet=-2.16 | 9-14 London: r=0.501 (0.008) n=3496 Fnet=-1.74 | 15-21 NY: r=0.504 (0.006) n=6960 Fnet=-1.72 | 22-23 late: r=0.540 (0.021) n=585 Fnet=-1.23
  AUDCHF a= 5 | 1-8 Asia: r=0.471 (0.005) n=9971 Fnet=-1.58 | 9-14 London: r=0.491 (0.005) n=10403 Fnet=-1.28 | 15-21 NY: r=0.497 (0.004) n=14886 Fnet=-1.25 | 22-23 late: r=0.522 (0.014) n=1206 Fnet=-1.16
  AUDCHF a=10 | 1-8 Asia: r=0.468 (0.010) n=2575 Fnet=-1.92 | 9-14 London: r=0.483 (0.010) n=2605 Fnet=-1.53 | 15-21 NY: r=0.508 (0.008) n=3757 Fnet=-1.09 | 22-23 late: r=0.500 (0.029) n=302 Fnet=-1.36
  CADCHF a= 5 | 1-8 Asia: r=0.509 (0.008) n=4143 Fnet=-1.60 | 9-14 London: r=0.489 (0.005) n=9123 Fnet=-1.67 | 15-21 NY: r=0.499 (0.004) n=15669 Fnet=-1.60 | 22-23 late: r=0.532 (0.014) n=1332 Fnet=-1.43
  CADCHF a=10 | 1-8 Asia: r=0.505 (0.016) n=970 Fnet=-1.58 | 9-14 London: r=0.501 (0.010) n=2347 Fnet=-1.56 | 15-21 NY: r=0.522 (0.008) n=3996 Fnet=-1.17 | 22-23 late: r=0.537 (0.028) n=311 Fnet=-0.96
```

- No session makes the fade pay after costs at 5 or 10 pips on any pair (the best is EURGBP at 10 pips in Asia,
  r = 0.553, exactly break-even on 600 trades in four years).
- EURGBP reverts in Asia (0.545 to 0.553) and in the New York afternoon (0.52 to 0.54), not in the London
  morning (0.495 to 0.499). EURUSD and GBPUSD trend most in New York hours (0.47 at 5 pips).
- The EA has an entry window (07:00 to 16:55 Toronto, off in the mechanics I was given). For a fade on the
  majors that is the worst third of the day, not the best.
- By year: the small arms lose every year. The fleet is negative in 2023, 2024 and 2025 in all four variants.
  AUDCAD is weakest in 2024 (-79 to +50 USD per arm) and positive in the other three years.

### 4.10 Cross-check against the project's simulator, and how fragile a single run is

`sim.py` with `run_bars.py`'s limit patch, on exactly `run_bars.py`'s pseudo-ticks, against my ladder in both
fill models (`07_crosscheck_sim.py`):

```
Cross-check AUDCAD: project sim.py (--fill limit) vs core.ladder on run_bars.py's ticks (5642600 ticks, sim.py took 225 s)
OPT add 18 | sim.py:            closes=3946 rolled=426 rolls=488 scalp=+63578 rolled=-49230 open=-215 total=+14133 pips, net USD=+772
          | core.ladder one:  closes=3845 rolled=423 rolls=489 realised=+12077 (rolled part -49519) open=-333 total=+11745 pips, net USD=+608
          | core.ladder cont: closes=4076 rolled=491 rolls=556 realised=+7578 (rolled part -56952) open=-229 total=+7349 pips, net USD=+280
ALT add 26 | sim.py:            closes=1990 rolled=192 rolls=226 scalp=+46802 rolled=-30814 open=-2053 total=+13935 pips, net USD=+876
          | core.ladder one:  closes=2014 rolled=194 rolls=230 realised=+14981 (rolled part -32339) open=-1137 total=+13844 pips, net USD=+868
          | core.ladder cont: closes=1961 rolled=204 rolls=241 realised=+11778 (rolled part -33904) open=-1315 total=+10463 pips, net USD=+629
```

```
Cross-check EURUSD: project sim.py (--fill limit) vs core.ladder on run_bars.py's ticks (5630708 ticks, sim.py took 884 s)
OPT add 7 | sim.py:            closes=35949 rolled=4989 rolls=5871 scalp=+220961 rolled=-233142 open=-425 total=-12606 pips, net USD=-3418
          | core.ladder one:  closes=36003 rolled=4985 rolls=5953 realised=-20513 (rolled part -237639) open=-456 total=-20969 pips, net USD=-4257
          | core.ladder cont: closes=37808 rolled=5569 rolls=6530 realised=-31178 (rolled part -256851) open=-388 total=-31565 pips, net USD=-5425
ALT add 23 | sim.py:            closes=3806 rolled=484 rolls=560 scalp=+76729 rolled=-72355 open=-1004 total=+3370 pips, net USD=+109
          | core.ladder one:  closes=3776 rolled=485 rolls=560 realised=+3572 (rolled part -72121) open=-926 total=+2646 pips, net USD=+38
          | core.ladder cont: closes=3671 rolled=490 rolls=572 realised=-460 (rolled part -73623) open=-982 total=-1442 pips, net USD=-364
```

- My "one resting add" model reproduces `sim.py`'s trade counts: on AUDCAD OPT rolls 489 against 488 and rolled
  closes 423 against 426, ALT total +13,844 against +13,935 pips; on EURUSD OPT 36,003 closes against 35,949 and
  4,985 rolled closes against 4,989. A trade-by-trade comparison over the first 20,000 AUDCAD bars matches entry
  for entry until a half-point rounding difference lets one extra L0 fill in mine.
- `sim.py` on bars is at the optimistic end, for two reasons that both come from 15-second pseudo-ticks. With
  one entry order per pseudo-tick it cannot add into a fast move the way the live EA (about 0.3 s per order)
  can, so it carries fewer layers through exactly the moves that hurt. And its exit queue promotes the next exit
  two pseudo-ticks after a fill, by which time price has often passed the target, so the exit is priced at the
  market and sells above target: its EURUSD OPT scalps average 7.14 pips, not 7.00 (220,961 pips on 30,960
  scalps). On EURUSD OPT the three models give -3,418 USD (`sim.py`), -4,257 (my one-add) and -5,425 (every level
  fills) over the four years. 4.6 says the tick truth is nearest the last.
- A single run is fragile. Nudging width, stranded and deadband by 0.1 to 0.2 pip:

```
Micro-perturbation of (width, stranded, deadband): 45 runs per arm and fill model. Total pips over 46 months, real bid/ask.
pair   arm add | fill | base run | mean of 45 |   sd | min .. max | rolled closes min .. max
AUDCAD OPT  18 | cont |    +7833 |    +8319   |  626 |    +7693 ..    +9551 | 477 .. 489
AUDCAD OPT  18 | one |   +11808 |   +12316   |  479 |   +11682 ..   +13380 | 423 .. 444
AUDCAD ALT  26 | cont |    +9709 |    +9697   |  495 |    +9057 ..   +10538 | 204 .. 212
AUDCAD ALT  26 | one |   +12691 |   +12688   |  485 |   +11987 ..   +13555 | 196 .. 205
EURGBP ALT  23 | cont |    +5492 |    +5295   |  174 |    +4984 ..    +5538 | 85 .. 90
EURGBP ALT  23 | one |    +5444 |    +5285   |  147 |    +5030 ..    +5492 | 85 .. 90
EURUSD OPT   7 | cont |   -31761 |   -31419   |  851 |   -32728 ..   -30155 | 5474 .. 5554
EURUSD OPT   7 | one |   -22243 |   -21790   |  461 |   -22402 ..   -20801 | 5065 .. 5125
```

  and from eight different start times the totals barely move, because the ladders re-synchronise once both
  sides are flat:

```
all 12 arms, std: net USD mean -14949 [-15083 .. -14762]
all 12 arms, alt: net USD mean -4314 [-4532 .. -4247]
```

  The standard deviation from rule details that should not matter is 150 to 850 pips on these arms, and two
  faithful implementations (`sim.py` and my one-add model) still differ by 2,400 pips on AUDCAD OPT. The roll
  gate is the amplifier: whether the opposite side happens to be flat when price crosses a roll level decides
  whether a full stack rolls now or is carried for weeks (in my AUDCAD replay, longs from 0.93 to 0.95 were
  carried to 0.91 behind the gate in February-March 2023 and then rolled six at once, each closing about 216
  pips under its entry).

## 5. CONCLUSION, AGAINST THE CRITERIA FIXED IN B4

**Does the data have what the strategy needs, strongly enough to pay its costs?**

- **Reversal property at the live rungs (T1):** on the conservative order ABSENT at 10 of 12 arms and BORDERLINE
  at 2 (EURGBP OPT, CADCHF OPT). On the optimistic order PRESENT at 1 (EURUSD ALT), WEAK at 4, BORDERLINE at 2,
  ABSENT at 5. The ticks side with the conservative order. Nowhere is it PRESENT on both.
- **Live arms (T3):** ABSENT in all four bar variants for 6 arms (EURUSD OPT, EURUSD ALT, GBPUSD OPT, AUDCHF OPT,
  AUDCHF ALT, CADCHF ALT) and in three of four for 2 more (GBPUSD ALT, CADCHF OPT); EURGBP OPT is ABSENT in two
  and inconclusive-negative in two. That is 9 of 12. INCONCLUSIVE leaning positive in all four: EURGBP ALT.
  AUDCAD OPT: inconclusive-positive in two variants, PRESENT in two. AUDCAD ALT: inconclusive-positive in three,
  PRESENT in one.
- **Overall, by the rule I set: NO for a clear majority of the arms.** The exceptions are the two AUDCAD arms
  and, weakly, EURGBP ALT.

**Could any parameter set of this design plausibly work on these pairs, and where?**

- At rungs below about 12 pips: no, on any of the six. The costs are certain (0.7 to 1.8 pips per close) and the
  reversion is zero to a third of that.
- EURUSD, GBPUSD, AUDCHF at any rung: no evidence. Wide rungs there are a zero-edge, low-turnover position.
- AUDCAD at 17 to 26 pip rungs (and CADCHF, EURGBP more weakly at 20 to 60): plausibly, on this sample. The
  honest statement of strength is: net +7 to +21 USD/month per 0.01-lot arm, t 1.1 in the variant I trust most
  and 3.7 in the one I trust least, 3 to 4 positive years of 4, confirmed in sign by eleven weeks of ticks. At the
  conservative estimate it would take on the order of 4 to 16 more years of the same to reach t = 2.5; the bar
  data cannot settle it. What could: the same test on AUDCAD before 2023 and on similar crosses outside the six.
- The effect on AUDCAD is the pair having ranged. A grid is by construction long "the range holds". Whether
  it will is the whole question, and four years of one pair do not answer it.

## 6. C -- FREE COMMENT

### 6.1 Design

1. **"Passive" is not "earns the spread".** Every layer buys at the ask and sells at the bid. On EURUSD the
   commission (0.6 pip per close) is three to five times the spread, so the cost is mostly a fixed toll per trade,
   and a 7-pip rung pays 10% of itself per close before any spread. The small-rung arms would need a reversal rate
   of roughly 0.55 to 0.56 to break even; the data is centred on 0.50 (0.48 to 0.54 depending on the reading).
2. **OPT and ALT are the same bet at two rungs.** The small rung makes 5 to 20 times the trades for the same
   kind of exposure and pays the toll each time. The data gives no reason to run it.
3. **The roll gate (gate 0) postpones losses rather than avoiding them,** leaves a full stack unmanaged for as
   long as the other side holds one layer, and makes outcomes hypersensitive to details (4.10).
4. **The L0 logic enters on a pullback of about `width` to `width` + 2 pips.** That is a fade at 2 to 6 pips,
   the scale at which every pair is at or below 0.50 in core hours.
5. **Three of the six pairs are one triangle each** (EURUSD, GBPUSD, EURGBP; AUDCAD, AUDCHF, CADCHF). Twelve
   arms are about four independent bets, all short the same thing (a directional week), with no stop.
6. **If the design is kept at all,** the data points to wide rungs on the low-volatility crosses, exit at least
   as wide as the add, far fewer trades, and no small-rung arm.

### 6.2 Research method

1. **Bars are not good enough below about 10 pips, and each of three artefacts is as big as the effect:**
   the intra-bar order (flips the sign of gross on the majors), the rollover on bid-only bars (phantom reversion
   and phantom buy fills, +90 to +240 USD/year per small cross arm in a raw replay), and the simulator's
   one-order-per-pseudo-tick speed (worth 1,200 to 2,000 USD on EURUSD OPT). Four years of tick data would remove all
   three. Eleven weeks does not have the power: it cannot tell +75 from -75 USD on an arm.
2. **Measure the fill convention; do not assume it.** It is worth 30 to 150% of the commission. The EA already
   archives order price and deal price for every fill; the mean of (limit - deal) by pair is one query. Note that
   the replay's "deal at the market 261 ms later" can also fill worse than the limit, which a limit order cannot.
3. **Run every simulator and every metric on a random walk first.** Mine failed that test once (3.1, item 1) and
   I would not have known otherwise. A grid on a random walk shows an 85% win rate and months of steady gains.
4. **Measure the property before tuning the geometry.** The reversal rate by rung and by run length is two
   small tables per pair and says where a ladder can and cannot work. Searching (width, add, stranded, cap,
   gate, exit) without it is searching noise: 612 cells gave me one at t 3.5 and a dozen at t 2.
5. **Use months, and equity.** Realised P&L runs ahead of equity here by design; a few good weeks mean nothing.
6. **Never rely on one run.** Use an ensemble over small perturbations of width, stranded and deadband, and
   treat two implementations disagreeing by 2,000 pips as normal for this design.
7. **Swaps are not in my numbers.** Wide rungs hold layers for days to weeks; on the CHF crosses the two sides
   pay very different carry. It needs adding before the AUDCAD result is taken at face value.

### 6.3 Code (EA read: `fxgrind.mq5`, `grind_pure`, `grind_config`, `grind_exitq`, and the lattice, add,
re-centre, deal and exit-queue parts of `grind_engine`; not read: recon, carry pass, archive, telemetry, snapshot)

1. **`sim.py` and the EA clamp exits differently.** EA: a long's exit that is at or below the market goes to
   ASK + 1 point (`Grind_CarryClampLongExit`, `grind_carry.mqh` 443-458), a short's to BID - 1 point (461-471).
   `sim.py`: BID + 1 point and ASK - 1 point (`exit_passive`, 248-251). In the EA a clamped exit rests a whole
   spread further away. MECHANICS s2 ("1 point off market") does not say which.
2. **`sim.py` predates C165** (`Grind_AddClampHold`, `grind_pure.mqh` 229-243, used at `grind_engine.mqh` 2570):
   it still re-prices a resting add when the clamp moves it by a deadband. I patched a copy; on AUDCAD bars the
   effect was under 1 pip in 120,000 bars, so it is immaterial there, but MECHANICS s1 no longer describes the EA.
3. **`sim.py` keeps a stale add resting when a side goes flat** (`ensure_add` returns at depth 0, 305-309); the
   EA cancels it (label mismatch path, `grind_engine.mqh` 2495-2521). In a trace the old add is later modified
   into the new ladder's add; on a gap it could fill while the side is flat.
4. **`sim.py` has no re-roll pause** (EA: 23:50 to 00:15 server, `grind_pure.mqh` 448-454).
5. **`run_bars.py` takes ask = bid + the bar's spread,** which is the minute's minimum spread applied to a bid
   low that was set when the spread was wide. That is the phantom-fill mechanism of 4.7.
6. **`run_bars.py` drops holiday-short weeks,** which are the thin, gappy ones; harmless but it flatters a grid.
7. **EA entries are clamped outside the spread on the far side** (buy limits below the bid, sell limits above
   the ask; `grind_pure.mqh` 198-227). In a wide spread a re-placed order sits a spread further away than a
   passive order needs to. Probably deliberate (stops level); it costs fills at exactly the hours when spreads
   are wide.
8. **`Grind_HandleSideDealFill` checks symbol and magic twice** (`grind_engine.mqh` 2874-2882). Harmless.
9. **`test_sim.py` has no test with a gap, a wide spread or the roll gate holding,** which are the three places
   the simulators disagree.

I found nothing in the EA's trading logic that looks like a bug in the sense of doing something other than what
MECHANICS.md says, apart from the two places where MECHANICS.md has fallen behind the code (items 1 and 2).

## 7. WHAT I COULD NOT DO, AND WHAT THE ANSWERS REST ON

- **No live fills.** The fill-price convention (4.6) is unverified; it is the largest single unknown.
- **No FTMO ticks.** The bar approximations are validated on IC ticks for 11 weeks and applied to FTMO bars for
  four years. Different broker, same market, one quarter.
- **The recorded spread is a minimum.** Bar-based costs are understated by roughly 0.06 to 0.17 pip per round
  trip in normal hours (4.1), more at news. Net figures from bars are optimistic by that much.
- **Not modelled:** swaps and the carry pass, order latency, the two-resting-exits queue, slot and API guards, the
  breaker, the commanded and automatic eject, slippage on the close-by. My ladder is an idealisation written from
  MECHANICS.md; where it differs from `sim.py` is set out in 4.10.
- **Core hours and the blow-out rule** were chosen after seeing the first results (3.1).
- **One period.** Everything is 2023-01 to 2026-10. I have no earlier AUDCAD history to test the one positive
  result on.
- **The commission** (0.06 USD per close per 0.01 lot) and the pip values are taken as given.
- **Power.** For the wide arms four years is not enough to tell an edge equal to the cost from zero; that is why
  three arms end as "inconclusive" rather than yes or no.

## 8. FILES IN THIS FOLDER AND WHAT REPRODUCES WHAT

Needs Python 3 with numpy, pandas, numba. Paths come from the environment (see `common.py`): FR_BARS, FR_TICKS,
FR_CACHE, FR_OUT. Run in numeric order; `04_ladder_bars.py` takes about 20 minutes per fill model on two cores.

    common.py, ticks.py, core.py        loaders; the step and ladder routines (numba)
    test_core.py                        hand-checked tests of core.py, including the random-walk null
    00_data_summary.py                  4.1 bars                    -> out/00_data_summary.txt
    01_null_calibration.py              4.2                         -> out/01_null_calibration.txt
    02_reversal_bars.py                 4.3, 4.9 (T1, by hour, run length, year) -> out/02_*.csv, .txt
    03_variance_ratio.py                4.4                         -> out/03_variance_ratio.txt
    04_ladder_bars.py cont | one        4.5, 4.8 (T3 on bars)       -> out/04_ladder_cells_*.csv, _monthly_*.csv
    04b_ladder_tables.py cont | one     full T3 tables              -> out/04_ladder_tables_*.txt
    05_ticks_inventory.py               4.1 ticks                   -> out/05_ticks_inventory.txt
    06_ticks_tests.py                   4.3, 4.6, 4.7 (T5)          -> out/06_ticks_*.csv, out/06_ticks_tests.txt
    07_crosscheck_sim.py <sim.py> PAIR  4.10                        -> out/07_crosscheck_<PAIR>.txt
    08_summary.py                       tables S1-S9                -> out/08_summary.txt
    09_phase_ensemble.py                4.10                        -> out/09_phase_ensemble.txt
    10_fill_improvement.py              4.6                         -> out/10_fill_improvement.txt
    11_micro_perturbation.py            4.10                        -> out/11_micro_perturbation.txt
    12_report_tables.py                 compact tables (a)-(f)      -> out/12_report_tables.txt
    13_build_report.py, report_prose.md assemble this report from the prose and the tables above
    dbg_*.py                            the diagnostics behind 4.10 (trade-by-trade comparison with sim.py); three of
                                        them have the sim.py path of my sandbox hard-coded at the top
    A_expectations.md, B_plan.md        as written before the data

Line count: 1069
