This message has a line count at the bottom

# WHERE THE GRID STANDS (12-13 OCT NIGHT): SCALPS, ROLLS, CHOP AND THE COST OF CROSSING

| | |
|---|---|
| Written | 13 Oct 2026 ~03:00Z (HANDOFF s81 continued 3), at the operator's request: "lets document this all" |
| What it is | The record of the discussion after sweep7, 13 Oct ~01:43Z-02:49Z: the operator's conclusions in his words, the arithmetic, two toys, a simulation, a correction to our chop measure, and Claude's reading. Nothing here changes a rule or a fleet |
| Evidence level | s3 and s7 from sweep7's outputs (replay, one eight-week path, `research/replay/results/sweep7/extras.py`, `extras.md`); s4-s6 toys and a simulation (`research/grid_thesis/varied_exits_toy.py`, `roll_breakeven_sim.py`, outputs beside them); s8 read in source. Claude's views are marked as such |
| Related | `research/replay/results/sweep_notes.md` (sweeps 1-7); `docs/research/grid-as-variance-trade.md` (s11's rho, corrected here in s7); `docs/research/light-side-add-discussion.md`; backlog C148, C151 |

## 1. THE OPERATOR'S CONCLUSIONS (his words, 13 Oct, times UTC)

- ~01:43Z: "these sweeps dont sound right to me ... the blowups were cos we had too much
  risk and there was an adverse move. even looking at fleet A now after a few days - yes it
  isnt making tons of money - but is it really on track to lose on every fx pair?"
- ~01:51Z: "even with an 8/8 book an adverse move loses money since we unwind one leg with 8 *e
  profit but the other leg takes 8 * 8 * a mtm losses".
- ~01:55Z: "i think that this is probably pointing at this effort being a unlikely one htat
  makes money".
- ~02:19Z: "it feels like we are taking profits at the earliest point and realising losses after
  every single chance has been taken. we can't layer up positions as the impact of rolling is
  always more than the gain from scalping in a linear move."
- ~02:34Z: "i find it hard to concede that the fx market is a random walk ... we live in various
  small trading ranges and migrate between them. is the evidence suggesting that model of the
  market is not true?"
- ~02:45Z: "it seems very unlikely we will ever hit the FTMO 1000 + 500 target to make the
  account validated."
- **~02:49Z (RULING): "fx is a difficult asset class. spot fx is probably the hardest to make
  money from. fortunately we have expertise in other fixed income markets! let keep going with
  the ftmo trial - but it does feel like we are exhausting options".** The FTMO trial (A) runs
  on, static, to its end (~21 Oct).

## 2. SWEEP7 IN ONE PARAGRAPH

One flat start a pair on 3 Aug, the book carried to 25 Sep (replay, live geometry): worse than
flat every Monday on 7 of 9 pairs (nine pairs -$309 against -$172 at 0.01 lots), about twice
the roll closes. Width 0.2 against the live width: -$261 against -$309, requests and roll
acceptances about the same. Detail: `sweep_notes.md`, sweep7.

## 3. LIVE A AGAINST THE REPLAY'S FIRST DAYS

- Live A (FTMO 1514878887, seven pairs, from 8 Oct): the operator ~01:51Z: realised +148.03,
  equity 34.31. (Claude first quoted -4.51 from the pipshed link pasted at 21:27Z: the link
  serves that moment's read; 02_TRAPS.)
- The replay on A's seven pairs, live geometry, carried from 3 Aug (`extras.md` (1)), dollars:

  | after | closed (realised - commission) | equity |
  |---|---|---|
  | 4 days (6 Aug) | +148 | +23 |
  | 8 days (12 Aug) | +198 | -39 |
  | 13 days (19 Aug) | +100 | -194 |
  | 22 days (2 Sep) | +21 | -376 |
  | 40 days (25 Sep) | -34 | -270 |

- The replay's first week looked like live A now. Three adverse stretches (19 Aug, 2 Sep,
  23 Sep) each took equity down in a day or two; the scalps after them did not win it back;
  rolls turned open losses into closed ones. Four-day equity changes on this path run from
  -$192 to +$131 (median -$26): a few live days cannot confirm or refute the replay.
- Follow EQUITY, not realised: realised P&L is the scalps; the losses wait in the open book.

## 4. WHY AN ADVERSE MOVE LOSES FROM 8/8 (the operator's point, made exact)

EURUSD-like, add 7, exit 10, an 8/8 book: the 8 longs above the price (at +5, +12 ... +54),
the 8 shorts below it. The price rallies 56 (`varied_exits_toy.py` (1)):

- the book starts net flat: small moves barely change equity;
- six longs reach their exit; counted from the start the longs gain +307;
- the 8 shorts all stay on: 8 x 56 = -448;
- equity -141; from there the book is 2 long against 8 short, about -6 a pip.

The grid takes its winning leg off one layer at a time, each for a fixed small profit, and keeps
its losing leg on at full size: net flat becomes net short as the move carries on. Gains grow
with the number of scalps; losses grow with the square of the net move (the lattice identity,
`grid-as-variance-trade.md`: P&L = a n / 2 - dP^2 / (2a)).

## 5. EXITS THAT WIDEN WITH DEPTH (the operator ~02:01Z: 10, 15, 20 ...)

One long ladder 200, 190 ... 130 (add 10, cap 8), each level buying again on a return; exits
10 + 5 x depth put every exit between 175 and 210 (`varied_exits_toy.py` (2)). Equity at the
end, pips (scalps):

| path | exits all 10 | exits 10, 15 ... 45 |
|---|---|---|
| A 200 -> 121 -> 200 | +70 (7) | +205 (6) |
| B chop 121 <-> 141 x3 | -322 (3) | -352 (0) |
| C bounce to 160 fails | -322 (3) | -352 (0) |
| D 200 -> 121 -> 100 | -520 (0) | -520 (0) |

It pays only on a full reversion, gives up the scalps at the bottom, and leaves the adverse case
unchanged: held layers that never reach their exit lose the same whatever the exit. Operator
~02:19Z: "this is not the solution - this is just another way of scaling adds".

## 6. HOW MANY SCALPS PAY FOR A ROLL (`roll_breakeven_sim.py`)

A roll step costs D = N x add (EURUSD-like: 8 x 7 = 56 pips) = 5.6 scalps of 10; 6.1 with 0.7
pip commission a close. A full roll of all 8 layers: 448 pips = 45 scalps (49 with costs).
One ladder, a 1-pip random walk, about 60 pips a day:

| market | scalps per roll | a day before costs | a day after costs |
|---|---|---|---|
| no drift, 2,000 days | 5.60 | +0.2 (se 7.1: zero) | -21.1 (the costs) |
| drift 18 a day against the stack | 3.70 | -126 | -147 |
| drift 36 a day against the stack | 2.82 | -229 | -252 |
| one straight move through the stack | 0 | -448 for 8 rolls | |

- On a market with no drift the scalps pay for the rolls EXACTLY (no rule can make or lose money
  on a driftless price before costs): the strategy then loses its costs. With drift against the
  stack the scalps per roll fall fast; with drift toward it they rise (9.9 and 31.9 in a first
  run whose drift sign was the other way).
- The shape the operator named: 58% of days up and a positive median day, a mean of minus the
  costs, the worst day about 2.4 times the best.

## 7. IS FX A RANDOM WALK AT OUR SCALE? A CORRECTION TO OUR CHOP MEASURE

- What matters for a grid is narrow: does the price come back over 7-60 pips more often than
  chance? Volatility clustering, fat tails and multi-week trends do not help a grid. The
  operator's model (small ranges, migrations between them) is exactly "more often than chance"
  if the ranges are stickier than chance; a random walk also LOOKS like ranges and migrations.
- **Correction (Claude, 13 Oct ~02:40Z).** rho as written in `grid-as-variance-trade.md` s11 and
  `compare.rho`, (S + R) e / (R D), counts roll CLOSES. Since re-roll (ADR-165) one ticket can
  be rolled several times and close once, carrying several steps of loss: sweep7's roll closes
  come in whole multiples of D (2x to 5x), as many as the re-rolls (EURUSD 13 and 13, NZDCHF 15
  and 15; `extras.md` (2)). Each roll step costs D and each rolled close gives back e, so on a
  random walk S e + R e = A D, with A the roll STEPS (ROLL_ACCEPTED): **rho by steps =
  (S + R) e / (A D)**. Counted by closes, rho reads too high whenever re-rolls happen.
- **Withdrawn:** Claude's table of ~02:36Z ("if every roll had cost the clean amount", e.g.
  AUDCHF +475) and its reading ("a tail of rolls that cost two to six times a clean one ... part
  of the loss looks self-inflicted"). Per STEP every roll cost the clean amount.
- **sweep7, rho by steps with the open book counted** (`extras.md` (3)): EURGBP 1.14, NZDCHF 1.08,
  CADCHF 0.97, AUDCAD 0.89, EURUSD 0.85, GBPUSD 0.81, AUDCHF 0.78, NZDCAD 0.78, AUDNZD 0.63; noise
  about +/-0.11. Only EURGBP is clearly above chance (as in sweep4, where it was the one steadily
  positive pair). On this path the range model does not hold at the grid's scale except on
  EURGBP. One path; the replay is checked against live trades on EURUSD only.
- How the range model and a losing grid fit together (Claude): ranges narrower than the stack's
  depth with migrations wider than it pay a little inside each range and the full squared cost
  on every migration.
- The occupancy histogram the operator asked about (~02:40Z) was NOT run: a single random-walk
  path's histogram is itself lumpy, so the test needs surrogate random walks of the same
  volatility beside it; and it is a price-series analysis (ruled out 10 Oct). Offered as a
  one-off diagnostic on the h8w ticks if the operator wants it.

## 8. THE ROLL GATE AT 0 IS NOT A HIDDEN COST (read in source)

Longs at 200, 193 ... 151; roll levels 144, 137, 130, 123. At 140 a short fills at 142 (8/1):
rolls are held. The market falls to 121; the short closes at 132 (+10); the book is 8/0. The EA
then catches up in one pass (`Grind_LatticeTrySide`, engine 1268 on: one lattice level a loop,
each roll booked at its own level): 144, 137, 130, 123, each costing 56, as if rolled on the
way down. The gate changes WHEN rolls happen (and lets a short scalp in between), and skips
rolls when the market bounces at 8/1; it does not make a roll dearer. Claude had named it as a
suspect (~02:36Z) before reading this; withdrawn.

## 9. THE FTMO TARGET (+10%, then +5%; 5% daily, 10% overall limits)

- Live A: equity about +$34 after four days. The replay of A's seven pairs peaked at +$36 in its
  first week and ended at -$270 (worst -$376): the target is about 30 times the best shown.
- Size does not help: target and limits scale together. Scaled 30 times (0.3 lots a layer), the
  replay's first week touches +$1,080 on 7 Aug, but the next Monday (10 Aug) loses about $990
  at the close, past the $500 daily limit: a lottery ticket, not a pass.
- With no edge, +10% before -10% is at best a coin flip; the 5% daily limit and losses that come
  in lumps put it well below. Operator: keep the trial running (s1).

## 10. WHAT IS LEFT (Claude's reading, not ruled)

- On a driftless market the grid loses its costs; it wins only where the price comes back over
  the grid's distances more often than chance. Measured by steps on one eight-week path, only
  EURGBP does.
- C148's four sources of a positive expectation each change who pays whom: a venue that pays the
  spread or a maker rebate; cheaper crossings; carry on the right side; pairs or hours that chop
  more than chance. None is a parameter of this retail setup.
- The infrastructure (the replay harness, the scoring, pipshed, the pipeline) is not specific to
  spot FX.

## 11. OPEN

- C151: rho by roll steps in `compare.rho`, the sweep reports and (to check) pipshed's S/R table
  (C137); `grid-as-variance-trade.md` s11 carries a pointer to s7 here.
- Plan 3's holdout export (Tue 13 from 22:10Z) and round 3's scoring go ahead as planned.

Line count: 180
