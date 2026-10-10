This message has a line count at the bottom

# CONSULT FOR FABLE -- THE EURUSD REPLAY: WHERE WE ARE AND WHERE WE ARE STUCK

Written by Claude (Lead Engineer, the project's main chat) 10 Oct 2026
~17:10Z for a second opinion. Repo `https://github.com/theonlykk/fxmatrix`,
`main` at `be672e1`. Everything you need is in this file; the repo paths
are for checking, not required reading. Please say which of your points
you verified (in this file or in the repo) and which you inferred.

## 1. THE SYSTEM, IN ONE PARAGRAPH

FXMatrix runs `fxgrind`, an MQL5 Expert Advisor that makes markets with
passive limit orders in a grid, on IC Markets demo accounts: Fleet B
(anchor geometry), C (probes the add spacing) and D (probes the exit
distance), nine FX pairs each. Per side (long, short) it holds a stack of
layers: an L0 entry straddles the market at a width W; each fill adds a
deeper layer at the add spacing; each layer rests an exit at the exit
distance e. A filled exit closes against its entry (a "scalp", S). The
stack's corridor is D = cap x add; when price runs past it, a layer is
closed at a loss and the lattice re-anchors one step with the price (a
"roll", R; `docs/research/grid-as-variance-trade.md`). Nightly at 23:50
server a carry pass shifts exits by the accrued swap. The edge ratio we
watch is rho = (S + R) e / (R D) per pair and side (1 on a driftless
random walk at any geometry).

## 2. WHAT THE REPLAY IS FOR (operator's rulings; not open)

- Run the EA's OWN engine over IC's ticks so that, once trusted, we can
  replay ALTERNATIVE geometries (width, add, exit, cap) on the same ticks.
- It is "the veteran": it reports RANGES and week-to-week STABILITY of S,
  R and rho per pair and side, never an optimum.
- It is trusted only once it reproduces OUR OWN trades.
- No time-series analysis of price and no price signals: the ticks only
  drive our rules.

## 3. WHAT WAS BUILT

- **Engine:** an MQL5 harness that includes the EA's own source (the EA is
  pinned; no EA change for the replay) and simulates the broker. Branch
  `replay-harness`, never merged.
- **Data:** EURUSD, 1-8 Oct 2026, fleets B, C, D: 29 segments (a segment =
  one EA init to the next; the replay is seeded from the true book at each
  init); 1,052 real IN deals; IC tick dump (476,821 ticks); our own archive
  and send logs.
- **Two modes.** SYNC: after every real deal the replay's positions are
  reset to the true ones, so one miss cannot cascade (tests the rules one
  decision at a time). FREE: from each init the replay runs alone to the
  next init.
- **A broker timing model, measured from our own sends** (plan 2): sends
  take ~287 ms (remove 43 ms); a resting order touched by a tick fills, and
  the deal lands 261 ms later at the market price then; the EA's handlers
  run one at a time; a tick during a running OnTick gets none of its own.
  Constants fixed before any run.

## 4. THE MARKS (pre-registered, fixed before any run)

- **T0** (floor): a touching tick exists for >= 95% of real deals. Passes
  (1047 of 1052).
- **T1** (SYNC): >= 95% of touchable real deals matched by the replay (same
  side, role, layer; price within 0.2 pip; time within 60 s), and
  replay-only deals <= 5%, per fleet.
- **T2** (FREE): per fleet and side, summed over PRICED segments, scalps S,
  roll closes R and roll acceptances within 10% (or 1) of the real counts,
  and rho within 0.1. A segment whose own T1 is below 95% is UNPRICED and
  left out of T2's sums; **if UNPRICED segments hold more than 20% of a
  fleet's real deals, T2 FAILS for that fleet** (so T2 cannot pass by
  dropping its worst segments).
- **PASS** = T0, T1, T2 on all three fleets, then a holdout on unseen data.
- Every miss gets one category: M1 data, M2 fill model, M3 timing (order
  live later than the touch; ticks coalesced), M4-M10 the EA's rules (L0,
  add, exit queue, roll, gate, carry, init), M11 account-level, M13
  unexplained.
- **If it fails:** in M4-M10 (a rule): cause first, up to three attempts.
  In M1-M3 (timing): "a tick-level replay is not trusted; T2 decides
  count-level use". Plan 1 also has: "T1 passes, T2 fails: the rules are
  right but rare paths compound".

## 5. THE RESULT (harness `145f092`, the deciding run)

| fleet | T1 matched | replay-only | T1 | UNPRICED segments (share of deals) | T2 |
|---|---|---|---|---|---|
| B | 96.0% | 2.8% | PASS | 2, 3 (18.6%) | PASS |
| C | 95.5% | 3.3% | PASS | 12, 13, 16, 19 (55.7%) | FAIL |
| D | 97.3% | 2.4% | PASS | 21, 23 (34.6%) | FAIL |

- T2's per-side sums over the PRICED segments pass on all six sides: S,
  R and roll acceptances equal or within 1, rho within 0.01 (e.g. D long
  S 38 / 38, R 18 / 17; C short S 46 / 45, rho 0.62 / 0.61).
- Every UNPRICED segment misses its own 95% by ONE OR TWO deals (C 12: 6 of
  7; C 16: 13 of 14; C 19: 109 of 115; D 21: 69 of 73 with 4 replay-only).
- Sensitivities: send / deal constants at the fleets' p10 and p90 give the
  same verdict; +250 ms latency prices C 19 but un-prices C 11; filling
  only 0.1 pip through collapses T1 to ~45% (IC fills on the exact touch).
- **Plan 2 closed under "fail in M1-M3":** EURUSD is not calibrated, a
  tick-level replay is not trusted, and count-level use is not allowed
  because T2 fails.

## 6. WHY IT MISSES (read by hand against the order logs)

The rules reproduce; the moment the EA reads the market does not, and a
grid amplifies that. Examples (all in `docs/research/replay-calibration-eurusd-2.md`
s15-s18):
- D 21, 1 Oct: live and the replay each placed the short L0 after a
  close-by, reading the market at slightly different moments: 1.13122
  live, 1.13125 replay. The L0 re-centres only when it sits MORE than 14
  pips from mid. Live's reached exactly 14.00; the replay's reached 14.05,
  re-centred, filled about 80 s later (a deal live never made), and the chain
  differs from there.
- C 19: the replay's L0 priced one point above live after the read moment;
  a trailing modify then fired 2.6 s early and the order missed its fill
  by one point.
- The 2 Oct US payrolls minute: several fills a second; the replay and
  live disagree on order.
- Measured over all sends: the timed replay places at live's exact price
  93.5-96.1% of the time (78.7-83.3% without the timing model).
- Small segments (5-20 deals) fail the per-segment 95% on a single miss, so
  which segments are UNPRICED is close to chance.

## 7. WHAT IS FIXED (constraints on any proposal)

- Pre-registration: marks fixed before any run; a mark changed after
  seeing a result is a NEW plan, judged on unseen data.
- **The holdout: EURUSD 9-13 Oct (B, C, D; ~3 trading days), exported and
  hashed on Tue 13 Oct, read by NOTHING until a plan allows it.** Please do
  not ask for it or for any statistic of it.
- No price statistics or signals; the EA is pinned; harness changes go
  through a written spec, review (Gemini), Cursor, a line-by-line read and
  the operator's GUI compile. No fleet action.
- Our data: our own trades, sends (14-day retention), archives, tick dumps.

## 8. WHERE WE ARE STUCK, AND WHAT WE ASK YOU

The replay looks right in the large and wrong in the small: deal-for-deal
it drifts because sub-second read moments are not deterministic from the
tick file; in totals it agrees where it was allowed to be scored. Our pass
rule was built for deal-level fidelity. Our purpose is ranges and
stability of S, R and rho. We may have the wrong test, or the wrong model
of timing, or both.

- **F1.** For the purpose in section 2, is deal-level matching the right
  gate? If not, what test would show the replay is FIT FOR THAT PURPOSE
  (e.g. agreement of S, R and rho per side over blocks), and how should its
  tolerances be derived so that it is a measurement, not a fit?
- **F2.** Timing noise: should the replay be stochastic (draw read moments
  and latencies from our measured send distributions, run N seeds, and ask
  whether the real outcome lies inside the replay's envelope)? What would
  make that test weak or circular?
- **F3.** The small-segment problem: a better gate than "each segment
  >= 95%" (pooling, a binomial bound, weighting)? Without it becoming a
  way to hide misses.
- **F4.** Power: is a ~3-day, three-fleet holdout enough to falsify "fit
  for purpose"? What would a fail look like, written down now?
- **F5.** Are we missing a different approach entirely (a Python port with
  a stochastic broker; or no replay: learn from the live A/B rounds the
  fleets already run)?
- **F6.** Which fact is missing, and which premise of ours is wrong?

Please answer F1-F6 in order, briefly, with what you would pre-register.
Your answer goes back to the main chat, which checks it in source before
anything is built.

## 9. FABLE'S ANSWER (10 Oct ~17:20Z) AND CLAUDE'S CHECK

Fable read the repo at `d5e976d` and recomputed from the committed results;
it ran nothing in the harness. Claude re-ran its three findings from
`results/eurusd_20261008_145f092/report.md` and `misses.csv`: all three hold.

- **Finding 1 (VERIFIED): the payrolls segments are not chance.** B 3, C 13
  and D 23 are the same minute (2 Oct 12:30Z); replay-only 7, 5 and 4
  against 2, 3 and 2 allowed. Section 5's "every UNPRICED segment misses
  by one or two deals" is WRONG for B 3. Free-run scalps there, real /
  replay: long 4 / 8, 5 / 10, 7 / 11; short 9 / 11, 9 / 13, 10 / 11.
- **Finding 2 (VERIFIED): free-run totals over ALL 29 segments, nothing
  excluded.** S real 384, replay 401 (+4.4%): five sides over, one equal,
  none under. R 108 / 107, roll acceptances 124 / 123. The payrolls
  segments carry +20 of S; the other 26 net -3 (340 / 337). Under the 10%
  mark only B long fails (35 / 39).
- **Finding 3 (VERIFIED): misses are shared across fleets.** 6 of B's 23
  miss / extra rows recur on C within 10 ms (same kind, side, role); B on
  D 2, C on D 1. One feed (plan 1 s4.1).
- **Also verified:** the live fleet differences in S are reproduced (long
  C - B +8 / +8, D - B +24 / +24; short +4 / +5, 0 / -2): on the seen
  window, so not evidence for a new plan. C 19 free: 70 of 115 deals
  matched, yet S 20 / 19 and 29 / 29, R 8 / 8.
- **F1 (its proposal):** keep pooled SYNC T1 (the rules reproduce); gate
  the purpose on FREE-run S, R and roll acceptances per fleet and side
  over ALL deals; tolerances from the LIVE day-to-day spread of each count
  (its suggestion: error <= one third of it, the operator to set the
  fraction from the smallest difference that would change a decision); a
  BIAS mark (fail if the signed S error has one sign on all six sides and
  sums past 5%); a DIFFERENCE mark (the replay reproduces live C - B and
  D - B: the use closest to ranking geometries).
- **F2:** not yet stochastic: p10 and p90 equal base (verified, s18), so
  the send distributions alone give no spread; what moves outcomes is the
  read moment and bursts (inferred). Its conditions if built later: offset
  estimated from calibration sends only and frozen; draws shared across
  fleets; N fixed; pass inside the central 90% with a half-width within
  F1's tolerance.
- **F3:** drop the per-segment gate; a binomial bound would price C 13 and
  D 23 and hide the burst bias. Report S, R and misses per server day.
- **F4:** the holdout can falsify gross failure, not confirm fit (one
  segment per fleet; one feed; R in single figures; no burst unless the
  calendar holds one). A pre-registered fail; an "inconclusive" outcome
  (fewer than 5 real rolls on a side: no rho score; fewer than four
  scoreable sides: not falsified, not confirmed); a pass licenses
  QUIET-MARKET count-level use only. It suggests extending the verdict
  window to 20 Oct before anything is read.
- **F5:** no Python port (it discards the engine that passes T1); live A/B
  rounds are the ground truth; use the replay only for geometries
  bracketed by live fleets and confirm rankings live.
- **F6, missing facts:** why the replay over-fills in the payrolls minute
  (the 2 Oct 12:30-12:31Z send logs: slow or refused live sends, orders not
  yet live); whether the dump is the stream each terminal saw (T0b passed;
  one feed, s4.1); the smallest S / R / rho difference that would change a
  decision (the operator); the live day-to-day spread of S and R per side.
  **Wrong premises:** "UNPRICED is close to chance" (false for 3, 13, 23);
  "right in the large" (biased up in scalps in a burst, which should grow
  with tighter exits); three fleets as three tests (one feed); rho within
  0.1 where rho is 0.08-0.11.
- **Claude's view:** the facts stand; the gate it proposes fits the
  replay's purpose better than the one we pre-registered, and plan 3 may
  need NO harness change (scoring only), so the harness stays at
  `145f092`. Two reads come first, both on seen data and allowed: the
  payrolls over-fill's cause, and the live day-to-day spread of S and R.

Line count: 227
