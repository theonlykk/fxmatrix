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

{{A}}

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

{{B}}

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

{{NULL}}

- Resetting the node to the sampled price (my original T1) is useless on bars: 0.55 to 0.60 on a random walk.
- Grid nodes with the std order reproduce the truth exactly while bars are smaller than the rung, and read LOW
  when bars are large (0.447 at a 3-pip rung with 6-pip bars); the alt order reads HIGH (0.57 to 0.67).
- The ladder behaves the same way: std is conservative, alt optimistic, and the gap between them is the model
  uncertainty. With EURUSD-like bars it is a few percent of a rung from 5 pips up; in fast markets it is tens of
  percent at 3 to 7 pips. So every bar result below is a bracket [std, alt], and the ticks say where the truth is.

### 4.3 T1: the reversal rate (`02_reversal_bars.py`, `12_report_tables.py`, `06_ticks_tests.py`)

Reversal rate by rung, entries in server hours 2 to 21, clean path; r std (monthly t) / r alt:

{{Ta}}

The same as money: gross pips per one-rung fade, against the cost per trade k:

{{Ta2}}

At the live rungs, with the pre-set verdicts and the tick values alongside:

{{S1}}

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

{{Tf}}

  On AUDCAD the reversal rate is highest after a run of 2 to 4 rungs (0.52 to 0.59, against 0.47 to 0.51 after
  one): that is what a ladder harvests, and why its P&L there is better than the one-rung fade suggests. On
  EURUSD the opposite: after 7 or more rungs r falls to 0.43 to 0.46 on the conservative order (0.45 to 0.51 on
  the other). Long runs keep going, which is exactly when the ladder is full and rolling.
- **The rollover on a raw bid-only path** (what a plain bar replay sees; rung 5; r / recorded spread by hour):

{{Tb}}

  On the crosses the raw all-hours rate is 0.8 to 1.7 points above the core-hours rate purely because of hours
  23 to 1, where the "reversals" are the bid being pushed down and released by a 2 to 11 pip spread.
- **The US data hour** (server 15) is the strongest momentum hour: r = 0.44 at 5 pips on EURUSD, GBPUSD, AUDCAD.

{{Tc}}

### 4.4 T2: variance ratios (`03_variance_ratio.py`)

{{VR}}

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

{{S2}}

{{Te}}

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

{{S3}}

In five pairs of six the most conservative variant (cont-std) is the nearest to the tick truth: within a few
percent of it on EURUSD, AUDCAD and AUDCHF, and the truth is below it on EURGBP and CADCHF. GBPUSD is the
exception (nearest one-std). So the cont-std column of 4.5 is my best estimate at limit-price fills, and the
other three columns lean optimistic.

There is a second convention to consider. MECHANICS s4 says the replay deals a touched limit "at the market" 261
ms later. On real ticks the market at the touching tick is on average better than the limit, because price
arrives in jumps:

{{FILL}}

A quarter to half a pip per fill on EURUSD and GBPUSD is the same size as the commission. Whether live fills
actually receive it is an execution fact about the broker that I cannot check in pass 1. Note also what it is
not: it is not an edge. With the node at the actual price the tick path is a random walk (r 0.50 to 0.51 on
EURUSD); the "improvement" only removes a penalty that the limit-price convention adds (being filled at L when
the market is already through L). Applied to the four-year bars as a first-order adjustment:

{{S2b}}

Under the market convention the conservative end improves to about -77, -69 and -25 USD/month for the three
small OPT arms. They reach zero only if one also takes the most optimistic bar variant, which 4.6's first table
advises against.

### 4.7 T3 on real ticks, August to October 2026 (`06_ticks_tests.py`, `08_summary.py`)

{{S4}}

Eleven weeks cannot separate any arm from zero (every weekly |t| is under 2.3). For what the signs are worth,
they agree with the bars: EURUSD negative, AUDCAD positive, the fleet near zero and on either side of it
depending on the fill convention.

The same ticks show what the rollover does to a plain bar replay. "raw" is `run_bars.py`'s construction:

{{S5}}

At a 5-pip rung the raw bar path overstates the gross result on every cross, by hundreds of pips in eleven
weeks, and the result at real bid/ask by 90 to 240 USD per year per 0.01-lot arm. At 10 pips the effect is
smaller and of mixed sign. Freezing the blow-out bars (std) removes half to most of it.

### 4.8 Could any parameter set work? The scans (`04_ladder_bars.py`, `12_report_tables.py`, `08_summary.py`)

Cap 7, exit = add, by rung; then the same with exit = 2 x add:

{{Td}}

{{S7}}

{{S8}}

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

{{S6}}

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

{{X_AUDCAD}}

{{X_EURUSD}}

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

{{MICRO}}

  and from eight different start times the totals barely move, because the ladders re-synchronise once both
  sides are flat:

{{PHASE}}

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
