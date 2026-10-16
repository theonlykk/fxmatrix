This message has a line count at the bottom

# ROLLS, RINGS AND THE ADD: NOTES FROM 15 OCT (FOR THE AUTOPSY, C153)

| | |
|---|---|
| Status | NOTES. Ideas and arithmetic from the operator's discussion with Claude, 15 Oct ~21:08Z to 16 Oct ~03:30Z (17:08-23:30 ET); the operator's words quoted with spelling corrected. **s7-s8 added 16 Oct ~16:50Z** (the rolled exit as a trailing stop, measured on B's GBPUSD and EURGBP; ALT or one geometry per fleet). **Nothing here is ruled.** No geometry change during the FTMO trial (to ~21 Oct) or plan 4's window; the work below is for the autopsy after them |
| Prompted by | The operator, 15 Oct ~21:08Z (17:08 ET): "pnl was brutal today in line with the last few days - but the fact is - we are still making 2 ways around the current market - so there is scope to trade more. the conflict is that rolls are awful - but we can't just hold underwater positions and we can't keep increasing them to an unlimited level. rolling is the only option - but clearly we are not doing it in a profitable way" |
| Standing rulings it respects | Work from our own trades, no price signals; the static trial runs to its end (A's breaker excepted: OFF from 16 Oct ~13:45Z); plan 4's blind period was empty (the freeze preceded the window; s6's correction, 16 Oct) |
| Links | backlog C153 (the autopsy), C151 (count roll STEPS), C32 (the currency cap), C49 (the add delay); `docs/research/grid-edge-assessment-2026-10-12.md` s7 (rho); `docs/research/replay-calibration-eurusd.md` s8 (what the replay is for); ADR-091, ADR-097, ADR-105 (the fxmatrix_v2 backtests) |

## 0. SOURCES

| # | Fact | Where | Status |
|---|---|---|---|
| R1 | 15 Oct (q19, 17:03Z): EURUSD long sides 16-28 scalps each for +164 to +258 pips (about +10 a scalp, exit 10); EURUSD short sides 5-8 rolls; each roll 45-52 pips after taking out ~10 a scalp | pipshed `/fleets/q19`, read by Claude (HANDOFF s84 continued 2) | MEASURED |
| R2 | 15 Oct: the AUD longs carried the day's loss on every fleet: AUDCHF, AUDNZD, AUDCAD long 6-12 rolls a side, -370 to -755 pips a side; A's two AUD legs AUDCHF L -639.9, AUDNZD L -632.8 | q19 | MEASURED |
| R3 | A (FTMO) runs 7 pairs: EURUSD, GBPUSD, EURGBP, AUDCHF, CADCHF, NZDCAD, AUDNZD: each of the 7 currencies exactly twice (the EUR / GBP / USD triangle and the AUD / CHF / CAD / NZD square) | q19; `MEMO_2026-10-03_post_once_execution.md` s8 | MEASURED |
| R4 | B, C, D (IC) run 9 pairs: A's 7 plus AUDCAD and NZDCHF (all six AUD / CAD / CHF / NZD pairs): AUD, CAD, CHF and NZD three times each, so NOT a ring | q19 | MEASURED |
| R5 | The operator, 16 Oct ~03:30Z (23:30 ET on 15 Oct): "we know that the ic fleets are not true rings, we have them as we want to collect more data on the fx pairs. ftmo is always a perfect ring" | this conversation | STATED |
| R6 | fxmatrix_v2 `vaccine_rally` (2020.10.15-2021.03.15, real ticks): GBPUSD in-test +$230.08, 7 EOT closures -$505.61, full net **-$275.53**; EURGBP in-test +$176.91, 4 EOT closures -$287.68, full net **-$110.77**. Every other v2 window figure in ADR-105 is in-test, EOT excluded | ADR-105 Gate 1 and "Per-window detail" | READ |
| R7 | fxmatrix_v2: `InpMaxLayers` 20; max depth 5-9 on every tested window (never reached 20); max drawdown read 0.00% everywhere because only realised balance was tracked | ADR-091 s5d-5e; `adr097_phase2_findings_initial.md` s6 | READ |
| R8 | The MT5 Strategy Tester judged unable to simulate delete-and-replace of a limit ladder or queue priority; the tester A/B dropped ("statistical theater") | ADR-114 | READ |

## 1. WHAT A ROLL COSTS (ONE WORKED EXAMPLE IN PRICES)

EURUSD, add 7 pips, cap 8, exit 10. A short side fills at 1.1000, 1.1007, ... 1.1049 as price rises. At
cap, each further 7-pip step makes a roll: the furthest layer is about 7 steps under water, so one roll
costs about **(cap - 1) x add = 7 x 7 = 49 pips**. Measured on 15 Oct: 45-52 pips a roll (R1). A scalp
books about the exit, +10 pips. **One roll needs about five scalps** (49 / 10 = 4.9).

- **Rolling books the inventory's loss; it does not make it.** Holding instead of rolling leaves the
  same 49 pips in MTM, and the next step adds to it; rolling keeps the exposure at 8 layers.
- In the rolling regime every further pip of trend costs about 8 layers' worth, whatever the add. The
  add decides WHEN the regime starts: at 7 x add from the first fill.
- So no way of rolling is profitable in a one-way market. What decides the result is how much chop the
  market gives per unit of trend (rho, C151: count roll STEPS, not closes).

## 2. THE RINGS, AND 15 OCT'S AUD DAY

- **A (FTMO) is always a perfect ring:** each currency exactly twice (R3, R5).
- **The IC fleets B, C, D are deliberately NOT rings:** nine pairs, AUD / CAD / CHF / NZD three times
  each, run to collect data on more FX pairs (R4, R5). Read their results as data, not as a ring.
- On 15 Oct one AUD move loaded every AUD long at once: three legs on IC (AUDCHF, AUDCAD, AUDNZD), two
  on A (AUDCHF, AUDNZD). **A ring limits how many legs share a currency; it does not stop one currency's
  move hitting both of its legs** (A's two AUD legs lost -640 and -633 pips, R2).
- The tool aimed at that is the currency cap, which exists in the EA but is disabled (thresholds 0.0;
  BOOT: cannot be enabled on a partial fleet, C32).

## 3. THE fxmatrix_v2 BACKTESTS: NO MAGIC

The best-looking backtests on record (ADR-105, 3 Aug: 5 windows x GBPUSD / EURUSD / EURGBP, all
positive, $7-$233 a window on $10k at 0.04-0.05 max net lots) are **in-test figures with the positions
still open at the end of the test left out.** The one window where both were written down:

| vaccine_rally | In-test | End-of-test closures | Full net |
|---|---|---|---|
| GBPUSD | +$230.08 | 7: -$505.61 | **-$275.53** |
| EURGBP | +$176.91 | 4: -$287.68 | **-$110.77** |

- v2 never rolled: cap 20, max depth 5-9 (R7). It held underwater positions and the bill arrived at the
  end of the window instead of as rolls. **v2 and fxgrind are the same trade with the bill paid at
  different times.**
- Full net is recorded for those two runs only, both negative, in a trending window (GBPUSD +907 pips,
  v2 short on the losing side). The choppier windows were never reported with their end-of-test
  closures. Drawdown was never measured (R7); the tester itself was later judged unfit (R8).
- The operator, 15 Oct ~22:41Z: "hearing that we got to 20 layers - and conveniently avoided the end of period
  evaluation means there is no magic here." (Correction recorded: v2 had room for 20 and used 5-9.)
- If C153's third idea is pursued: first get full net INCLUDING end-of-test closures for all 15 runs (the
  tester's own report has it, if saved on the desktop; otherwise re-run).

## 4. PATH AGAINST RANGE: MEAN REVERSION OR MOMENTUM?

The operator, 15 Oct ~22:45Z (18:45 ET): "perhaps there is something to be said for the fact that the total path
travelled is not significantly longer than the trading range. maybe it is momentum and not mean reversion
that should be the focus." And: "we keep focus on getting replay harness correct. wrt the strategy - we
just have to watch it."

- This is rho in words. A EURUSD day that ends 50 pips lower: got there in 300 pips of back-and-forth,
  the grid scalps the surplus both ways and pays one stretch of inventory (a good day); got there in 80
  pips of travel, there is little to scalp and the whole move lands on the inventory (a bad day).
- **The mirror image is not free.** The grid earns partly as a passive maker (it collects the spread); a
  momentum strategy takes liquidity and pays the spread on every entry. A week the grid lost to trend
  does not mean a momentum book made the same amount; both can lose, with costs in between.
- **A momentum strategy is a price signal:** it conflicts with the standing ruling ("no time-series
  analysis or price signals"). The ruling is the operator's to change, explicitly.
- **The replay is the instrument for the question:** path against range at grid scale is what the S, R
  and A counts per pair, side and week measure (plan 1 s8: "ranges and their week-to-week stability").
  If plan 4 passes, many weeks of EURUSD decide whether path / range is reliably above what the grid
  needs, not one bad week.

## 5. THE PROPOSAL: SET THE ADD SO PAIRS ROLL EQUALLY (CAP 8, EXIT = ADD)

The operator, 16 Oct ~03:21Z (23:21 ET on 15 Oct): "could we use that info to adjust the add distance so we
normalise the number of rolls rather than optimise pnl? ... if roll is layers * add - and we keep layers
at 8 - then we tweak the add distance - perhaps keep exit = add and move in the direction of equal rolls
over the period."

**What the dial does (rough; cap 8, exit = add, one 80-pip move against a side; loss in pips summed over
layers: 28 x add on the full stack when it reaches cap, then 8 a pip beyond):**

| Add | Pips before cap | Rolls | Loss |
|---|---|---|---|
| 4 | 28 | 52 / 4 = 13 | 112 + 8 x 52 = ~530 |
| 8 | 56 | 24 / 8 = 3 | 224 + 8 x 24 = ~420 |
| 10 | 70 | 10 / 10 = 1 | 280 + 8 x 10 = ~360 |

Doubling the add cuts rolls from 13 to 3 but the loss only by about a fifth; in chop, scalp income falls
roughly as 1 / add (round trips as 1 / add squared, each worth the exit = add). **Roll count is a
sensitive dial; money is not.** Equal rolls equalise **how deep each pair's stack is against that pair's
own typical one-way move** (how rarely it is overwhelmed), not risk or P&L.

**The hurdle (from the geometry, not chosen):** a roll costs about (cap - 1) x add, a scalp earns the
exit, so a side breaks even when

    scalps per roll step  >=  (cap - 1) x add / exit

- 15 Oct's EURUSD: 7 x 7 / 10 = 4.9. **With exit = add the add cancels: the hurdle is cap - 1 = 7 scalps
  a roll step for every pair and every add.**
- Sanity check, A's EURUSD on 15 Oct: 26 scalps against 5 rolls = 5.2 against 4.9: about +1.5 scalps
  (~+15 pips); pipshed +37 (same sign; rolls there are closes, not steps).
- **The target:** per pair and side, the add at which scalps per roll step clear the hurdle, over a long
  lookback. A wider add cuts scalps (fewer round trips) and cuts rolls sharply once the stack is deep
  against the pair's moves; where, or whether, the ratio crosses the hurdle is measured per pair. A pair
  that clears it at no add is an answer too. (An earlier "80th percentile of excursions" was Claude's
  placeholder; the percentile the stack covers is an OUTPUT of the hurdle, not an input.)

**Why equal rolls (the operator: "it isnt obvious to me what benefit having each ccy roll roughly the
same amount is - but i think it is a reasonable exercise in trying to understand the geometry more
fully. perhaps it is a better way to distribute risk better"):**

1. A calibration check: a pair that rolls far more than the rest has an add too tight for how it moves.
2. It spreads the losses: on 15 Oct the AUD crosses (adds 4-8) entered the rolling regime sooner than
   the others; at equal depth no single pair turns a normal day into its own bad day.
3. It makes the pairs comparable on edge: with exit = add every pair faces the same hurdle, so scalp
   counts show directly which pairs have chop to harvest.

**Cautions:**

- **Updating it period by period chases the market** (rolls cluster: this week AUD). Long lookback, small
  steps, geometry changed only between test windows.
- **Exit = add changes the scalp size;** most pairs run exit 10 against adds 3-9. At add 4, exit 4,
  commission is a larger share of each scalp: check before adopting.
- **It does not fix correlation:** three AUD crosses rolling at equal rates still roll together on an
  AUD day (section 2; the currency cap).
- **Volatility moves together across pairs** (the operator: "the volatility of fx pairs ... rises and
  falls at the same time - albeit perhaps different amounts"). That helps: RELATIVE movement is more
  stable than its level, so a per-pair add set on relative movement can hold across regimes. It does not
  fix time: in a high-volatility week every pair rolls more at once; that is fleet-level sizing (total
  layers, the currency cap), separate from the per-pair add.

## 6. THE ANALYSIS (AFTER THE TRIAL; C153)

From our own archives, per fleet, pair and side, over the cycle and per week:

1. add, exit, cap; scalps S; roll STEPS A (`ROLL_ACCEPTED`, C151) and roll closes R; scalp pips; roll pips.
2. scalps per roll step against the hurdle (cap - 1) x add / exit.
3. each excursion's depth (layers reached x add): the distribution per pair and side.
4. the stability check: rank the pairs by roll steps a week; does the ranking hold week to week?
5. the add at which each side would clear the hurdle (first-order from 1-3; then the replay on EURUSD
   if plan 4 passes: S, R, A at add 6, 7, 8, 9 on the same weeks).

Timing: the non-EURUSD pairs any time (they are not blind); EURUSD of B, C, D only after plan 4's export
is hashed (Tue 20 Oct from 22:10Z). Geometry stays frozen until the trial and the plan 4 window end.
(Correction, 16 Oct: plan 4's blind period was empty, the freeze having come first; EURUSD can be read any time.)

## 7. THE ROLLED EXIT IS A TRAILING STOP: MEASURED ON B'S GBPUSD AND EURGBP (16 OCT)

The operator, 16 Oct ~16:32Z: "i still am struggling to comprehend why we are just taking loss after
loss - the market had a big move down then up - it is not repriced miles away - one might even say it
is still range trading and that mean reversion would be ideal - but the fleets are bleeding money ...
it was working for a few days - why does it feel so hopeless?"

**The mechanism (ADR-162 / ADR-165).** A roll never closes the position: it moves the layer's exit to
`level +/- exit` at each new lattice level, following the market. The loss is realised on the first
retracement of ONE EXIT (10 pips; 5 on EURGBP) from the extreme. **So a rolled layer's exit is a trailing
stop one exit behind the extreme.** In a range whose swings exceed the stack (7 x add), it fires at every
turn, just before the move pays back. Worked example from the archive: B's short opened 1.31631 was
re-rolled up the 16 Oct rally and closed on a 10-pip dip during it, at **1.33324: -169.3 pips** (12:45Z);
after the high (near 1.3371, ~14:30Z) three more closed at -143 to -169 between 15:00Z and 16:36Z as price
came off it.

**Holding versus rolling in a V (EURUSD, add 7, exit 10, cap 8; down 100 pips and back 100):** 8 layers
to -49; ~7 roll steps to -100, each layer ~45 under water; the first 10-pip bounce realises ~7 x -45 =
-315 near the bottom; the climb back scalps ~10-14 x 10 = +100-140; **price back where it began, about
-200 pips.** Holding (a stack deep enough not to roll) ends near flat plus the scalps. In a one-way move
rolling and holding cost about the same; **in a range wider than the stack, rolling is strictly worse.**

**Measured** (`research/roll_recovery/rolled_recovery.py`, tests `test_rolled_recovery.py`; output
`results_2026-10-16.md`; inputs `inputs.sha256`, the two exports of 16 Oct ~16:40Z / ~16:50Z): for each
rolled close (`scalp_history.rolled`), did the instance's own MARKET fills (IN / OUT; never OUT_BY, whose
price is the other position's entry) later come back through the layer's ORIGINAL entry?

| B fleet | Stack (7 x add) | Rolled closes | Back through the entry | Hours (median / 25% / 75% / max) | Within 24 h | Never back, older than 48 h |
|---|---|---|---|---|---|---|
| GBPUSD (add 9, exit 10) | 63 pips | 26, -1,970 pips | 18 | 18.4 / 8.2 / 124.5 / 358.5 | 10 | 0 (8 younger than 48 h) |
| EURGBP (add 3, exit 5) | 21 pips | 45, -1,046 pips | 24 | 20.8 / 14.5 / 25.1 / 93.9 | 17 | 18 |

- **Most rolled losses were on positions the market later repaid, typically within a day** (about two
  thirds on GBPUSD, about half on EURGBP).
- **Not all:** 18 of EURGBP's 45 never came back (mostly early-October longs in a real down leg): there the
  roll stopped a trend. Rolling is not wrong in itself; **its trigger is too eager** for how these pairs
  range.
- **Quiet days were steady; roll days wipe them out.** GBPUSD 9-13 Oct: no rolls, +20 to +96 pips a day;
  14 Oct +278 scalps / -455 rolled; 16 Oct (to 16:40Z) +111 / -650. EURGBP's 21-pip stack is smaller than
  an ordinary EURGBP day: it rolls even on quiet days (one rolled close on each of 9, 12, 13 Oct).
- **Caveats:** hindsight. "Back through the entry" says the realised loss was avoidable, not that a hold
  policy makes money: holding keeps the stack full (no new near-market scalps on that side), carries the
  MTM about a day typically and far longer in the tail, and the third to half that never recover keep
  growing. Two pairs, one fleet. The replay (if plan 4 passes) scores the alternatives over the same weeks.

**A lever considered and REJECTED: a "lazier" rolled exit** (Claude, 16 Oct ~16:47-17:01Z). The idea:
put a rolled layer's exit further away, by k x exit (say 30 pips), at the layer's original target, or the
target with a time / distance backstop, so the loss is not realised on the first one-exit retracement.
Worked on the 16 Oct short (entry 1.31631): today's rule closed it on a 10-pip dip at 1.33324 (-169); a
30-pip trail would have held through that dip and closed ~30 below the later high (~1.3341, about -178:
WORSE); the original target (~1.3153) waits for ~180 pips more. **The operator, 16 Oct ~18:45Z: "lazy roll
does not sound great. it seems like you are placing exit orders where we likely already are working
exits, the 3* exit seems like to are trying to predict the size of the bounce. it introduces an
inconsistency in the way we treat some potential scalps and it delays the execution of the decision we
took to roll and hence commence new scalps."** RULED: dropped. Recorded reasons: (1) a held-to-target
rolled exit rests at nearly the same price as the deeper layers' exits (duplicate exits); (2) k x exit is
a forecast of the bounce; (3) rolled layers would close on terms unlike every other potential scalp;
(4) rolling is a decision to realise, free the slot and restart scalping near the market; a lazy exit
defers it. Also: carried losses count against FTMO's next day from its first second (ADR-160 s1).

**What stands is the diagnosis, and the question it leaves:** in a range wider than the stack, rolls
realise at the turns; within the operator's framework (roll promptly, every exit alike), the test is
whether the scalps restarted after a roll repay it: scalps per roll step against the hurdle
(cap - 1) x add / exit (s5). The levers left: **ALT with wider adds** (s8; a live experiment on one IC
fleet after the trial), the stack (add x cap, s5, with the operator's caution against pricing off recent
weeks), the currency cap (s2).

## 8. ALT BACK, OR ONE GEOMETRY PER FLEET? (16 OCT)

The operator, 16 Oct ~16:38Z: "perhaps we need ALT back? OPT has wide ranges that would work in these
current markets and ALT in the previous week's markets."

- The instinct is sound: hold a geometry for each regime instead of forecasting one.
- **Two arms on one pair diversify the regime bet, not the inventory:** in a big move both arms load (the
  wide one more slowly), so combined exposure exceeds one arm, and lots cannot go below 0.01. ADR-160 s4
  recorded cycle 3's OPT and ALT "held near-identical stacks, so every move was paid twice" (closer
  geometries than a narrow / wide pair would be).
- **Two arms average the edge; they do not create it:** it pays only if each arm wins clearly in its
  regime and loses little in the other: measurable, but it is the bet. FTMO's request budget and $500
  limit make a second arm on A expensive; the IC fleets have slot room (~140 / 194).
- **A cheaper form: one geometry per IC fleet** (B narrow as last week, C as now, D wide): one arm per
  pair per account, compared side by side on pipshed. Close to the compass rounds the operator stopped on
  13 Oct: his call whether that reopens them. After the trial and plan 4's window; the replay (if plan 4
  passes) scores narrow against wide on the same weeks.

Line count: 252
