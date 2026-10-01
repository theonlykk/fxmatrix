This message has a line count at the bottom

# THE GRID THESIS -- ROOM, CLUSTERS AND THE DRAWDOWN BUDGET

Written by Claude from a conversation with the operator, 30 Sep
~02:00-03:00Z (29 Sep evening ET). A research note, not a design: no EA,
preset or pipshed change follows from it until its measurements (s6)
have been read. The thesis is the operator's; the arithmetic and the
measurement plan are Claude's. For Gemini's review (s9).

## AUDIT TRAIL

| # | Fact used | Where | Status |
|---|---|---|---|
| T1 | Every live geometry has exit >= add (e.g. NZDCHF 3/10, AUDCHF 4/10, GBPUSD 9/10, EURGBP 3/5); cap 8 everywhere | `10_GEOMETRY_REGISTER.md` | VERIFIED |
| T2 | A roll realises a fixed `cap x add - exit` on a uniform ladder, whatever the depth | ADR-162 s4 | VERIFIED |
| T3 | Auto-eject takes the most underwater layer (usually L0); 28 Sep ejections realised $3.00-5.49 each | `grind_engine.mqh` 559-585; ejection study s0, s8 | VERIFIED |
| T4 | Early B1 read: halving NZDCHF's add (6 -> 3) and cutting AUDCHF's (6 -> 4) each roughly doubled scalps, with more ejections | pipshed card, 29 Sep | INFERRED (a first look, not counted) |
| T5 | Cycle 2 ended on the FTMO daily-loss limit on a day that STARTED about -$330 from carried positions | `09_EVENT_LOG.md` 23 Sep | VERIFIED |
| T6 | Account limit 200 positions + orders; the EA's slot guard at 194 | `09_EVENT_LOG.md` 16 Sep; C78 | VERIFIED |
| T7 | Loss-based limits already exist: ADR-160 entry gate (floating loss 50% on / 40% off); a currency-exposure cap, disabled at thresholds 0 (C32) | `01_BOOT.md` | VERIFIED |
| T8 | pipshed deletes `send_logs` after 14 days and `ea_events` after 90; NO job deletes `fill_logs`. The ejection study's "fill_logs 14 days" and the event log's "~8 Oct" expiry are wrong | pipshed `archive_worker.py` 899-930 at `15ddeb7` | VERIFIED in source; the live table's oldest row not yet checked |
| T9 | FX take-profit orders cluster at round numbers and stop-losses just beyond them (Osler, NY Fed / J. Finance, early 2000s) | Claude's recall | UNVERIFIED: check the papers before leaning on it |

## 1. THE THESIS (operator)

A trend against a side is not a loss to recover: it is how the ladder
buys inventory at a new range. The money is made where price then
revisits a few levels over and over, "like 1 or 2 unwinds for most
layers, but layer 3 adds and unwinds 10 times and layer 7 also adds and
unwinds 10 times". Those are points where a lot of risk changed hands and
the market "cares about": holders afraid of giving up gains, or stopping
out at break-even. "The key thing is we have faith these clusters exist -
we want the capital to be able to visit them." Price never has to come
back: the scalps at the new range pay for the inventory carried there.
The operator dislikes the "half retrace to break even" framing (true, but
not the point). An ejection is a realised loss in every case; the room
(add x layers) is the range in which nothing is realised at a loss.
**No magic distance** (operator, 30 Sep ~03:05Z): "there is no magic
distance number that will work all the time. In fact finding that there
isn't one frees us up to not worry about the theater of entry." The
ladder does not forecast where a range will form; it is present at every
level the budget can afford, and the clusters come to it.

## 2. THE ARITHMETIC (uniform ladder, one lot per layer; "pip-lots" = pips x layers)

Layer k fills at `k x add` from L0. With price at the newest of n layers:

    open loss = add x n(n-1)/2        (5 layers: 10 add-units; 10: 45)

The loss grows with the SQUARE of the move: each new layer is cheap, but
every layer already held loses on every further pip (slope: n lots/pip).
- At the moment the cap-th layer fills: `add x cap(cap-1)/2` -- 28
  add-units at cap 8, 45 at cap 10 (+25% layers, +61% loss).
- When price has used the whole room `R = cap x add` (the first level
  past cap): `add x cap(cap+1)/2 = R(cap+1)/2`. GBPUSD today (9 x 8):
  252 pip-lots at cap, 324 at full room ($25.20 and $32.40 at 0.01 lots).
- Past the room the loss grows in a straight line (cap lots per pip);
  ejection or roll realise it in steps (T2, T3).
So the cap does nothing for moves inside the room; it only sets the slope
of the tail. That is why it is hard to tune from a few days of data.

**Harvest condition.** A layer scalps only when price rises its full exit
above its entry. A swing of amplitude S harvests about
`(S - exit)/add + 1` layers when S >= exit, and NOTHING when S < exit.
With exit >= add on every live geometry (T1), a range between two
adjacent layers books nothing. First order: the exit queue places exits
one at a time (ADR-151), which matters only in a fast swing.

**Payback, about 7 layers deep** (price near L6-L7; carried loss ~24.5
add-units): GBPUSD 9/10 carries ~220 pips; a range just over 10 pips
harvests ~1 layer per swing, so 15 swings ~150 pips: not paid. NZDCHF
3/10 carries ~75 pips; a 12-pip range harvests 1-2 layers per swing, so
15 swings ~150-300 pips: paid. The thesis favours a tight add AND an
exit sized to the ranges that follow trends.

## 3. ADD IS PARTLY LEVERAGE

To first order a tighter add raises scalps (layers cycling in a range ~
range / add) and inventory (one layer per add pips of adverse move) by
the same factor: add 3 at 0.01 lots behaves much like add 6 at 0.02.
Crediting a tighter add with "more scalps" and charging it "less room"
describes one thing twice. What add changes beyond leverage is
RESOLUTION: a finer ladder harvests swings a coarse one never fills.
T4 fits: NZDCHF's doubled scalps is what pure leverage predicts;
AUDCHF's doubling on 1.5x the inventory may be resolution. Consequences:
- The compass (cycle-4 note s8) scores raw closed P&L at one lot size,
  so a tighter add partly wins by leverage; over a calm two-day round,
  leverage looks like skill. Compare per unit of inventory (e.g. per
  lot-hour of open layers) or at equal leverage (add 6 at 0.02 vs add 3
  at 0.01; 0.01 cannot be halved). A change to the compass score is its
  own document for Gemini, after the study reads.
- "One ejection costs about six scalps" is not a constant: its cost
  scales with the room (T3).

## 4. THE DESIGN RECIPE

- **D**: the distance between clusters (the trend leg), per pair, as a
  distribution. Use a high percentile: a room sized to the mean leg is
  overrun by about half the journeys.
- **B**: the open-loss budget per side = the share of the $500 the
  operator will have open, divided by **k**, the sides that tend to be
  deep together (USD majors; CHF crosses), measured from history.
- Room `R >= D`. Layers from the budget: `R(n+1)/2 x v <= B`, so
  `n <= 2B/(R x v) - 1` (v = dollars per pip per layer). `add = R / n`.
- Exit from the swing sizes at the clusters (s6 M5).
Made-up example, not our numbers: legs up to 80 pips, B = $20 at 0.01
lots ($0.10/pip, 200 pip-lots): n <= 2 x 200/80 - 1 = 4, add 20; exit 10
< add, so swings between adjacent layers would scalp. (The chat's rough
version said 5 x 16.) The budget is daily, but journeys cross days: set
B against the worst day-roll (T5), not an average hour. If D is stable
in volatility units (e.g. multiples of the day's range) but not in pips,
the room should move with volatility: the "dynamic cap" (s7).
The compass then fine-tunes around these starting values.
**Reading D (operator's principle, s1):** D is a distribution to size a
budget against, never a number to predict. Choosing its percentile is a
choice of how often to pay for an overrun (ejection or roll: the priced
tail), not a forecast. If M5 finds no stable D, even in volatility units,
that is a RESULT: it confirms even spacing (the "we don't know where"
prior) and rules out timing entries, placing layers at predicted levels,
and a volatility-driven cap.

## 5. THE CAP (Gemini asked blind, 30 Sep ~02:20Z)

Claude withheld its view; Gemini, from facts only, also rejected the
compass for cap (closed P&L rewards a higher cap by burying losses in
open MTM), proposed scoring closed P&L minus a penalty x carried MTM at
the FTMO day roll, an offline test at caps 6/8/10, and flagged 14 days
as thin for tails. Claude's check: agreed on the compass and the
day-roll point (the cycle-2 fact in the question pointed there).
New from him: test ABOVE 8; a loss realised before the day roll resets
the next day, carried open it eats tomorrow's room (suggests a separate
"de-risk before the roll" lever). Claude disagrees: the penalty factor
is arbitrary (report a frontier; his own "under 40% of the limit" rule
is a constraint); cap 10 must pass the slot limit (T6), which he did not
know; ejection slippage is smaller than he fears (T3: 0-2 min fills);
he missed that cap and add act as their product and that cap is a fleet
lever; his frame is ejection, but B and C roll from C63.
Operator: "the cap means we are never prevented from trading": below cap
we trade deeper levels, at cap we recycle at once. Any dynamic cap must
only limit NEW layers, never force existing ones out mid-move.

## 6. WHAT WE MEASURE

**Rule: trade history is the gold standard** (operator: "our aim should
be to get as much trade data that is not publicly available or requires
hard work"). Tick data describes price, not our fills: gap fills 6-13
pips better than the limit (27 Sep), the exit queue, quarantine, slots,
resyncs. A simulator or counterfactual is trusted only once it
reproduces our own fills on days we traded; until then its results are
labelled "first-order, not reconciled".

**Thursday interim (ejection study, added scope):** caps 5-10 per pair
and per fleet, scored on closed P&L, carried MTM at the FTMO day roll and
worst intraday equity against $500, shown as a frontier; caps above 8
with a slot check; ejection and roll scored separately.

**By the weekend (own analysis, trade history first):**
- M1 deepest layer reached per side per episode (headroom used).
- M2 scalps per ejection, and the worst cluster (most ejection cost in
  any few hours against $500).
- M3 closed P&L per unit of inventory beside raw closed P&L (s3).
- M4 payback per deep episode: scalps by the deep layers before the
  episode ends vs its peak carried loss; the amplitude of the range that
  followed vs the exit.
- M5 swing amplitudes per pair (the exit's harvest curve: exit x swings
  >= exit, net of spread and commission) and trend excursions (D), at a
  few swing thresholds.
- M6 THE CLUSTER TEST: fills and unwinds per price level per deep
  episode. Clustering means a few levels cycle far more than the rest,
  judged against a null at the same volatility (a random walk also
  revisits some levels by chance), then checked against round numbers
  and prior-day highs and lows.
- M7 dollars of open loss at each depth per pair (s2) and the
  frequency with which the largest adverse move exceeded the room.
Caveats: 14 days is thin for tails; swing definitions move the answers;
regimes change, so these give starting values, not answers.

## 7. THE DATA ASSET AND IDEAS PARKED

- Keep everything: `fill_logs` are kept (T8); `ea_events` (ejections,
  rolls, quarantine markers) are deleted at 90 days: export or extend.
- Export each account's full deal history from MT5 periodically (a
  closed account may take its history with it: check cycle 2's).
- Richer fills: bid and ask at the fill, limit-vs-fill slippage (C73),
  order-to-fill time.
- More fleets as experiments (box 3); eventually a small real-money
  account: FTMO and the IC demos fill in simulation, real fills may not.
- Parked, no design until M1/M7 read: DYNAMIC CAP (by volatility, by
  time to the day roll, or a fleet-wide exposure budget, cf. C32) and
  SPACING SHAPE (a per-layer add schedule; wider deep spacing grows the
  loss more slowly but needs a bigger retrace; bigger lots with depth,
  martingale, never). Layer placement at measured cluster levels only if
  M6 beats its null.

## 8. WHAT IS NOT CLAIMED

That any single distance works all the time (s1: the thesis says it
does not), that clusters exist (M6 decides), that the recipe's numbers are right
for any pair (no D, k or B is measured yet), or that any live setting
should change before s6 reads.

## 9. FOR GEMINI

Attack the premises, not only the conclusions; say which fact you would
need if one is missing.
- **GT-1.** s3: add scales scalps and inventory together to first order.
  Where does that break? Is "per lot-hour of inventory" the right
  normaliser, or equal-leverage comparisons, or neither?
- **GT-2.** s2: the harvest condition (S >= exit) and its consequence
  that, with exit >= add, a range between adjacent layers books nothing.
  Correct? What else decides which ranges a ladder can harvest?
- **GT-3.** s4: the recipe `n <= 2B/(R x v) - 1`, `add = R/n`. What is
  missing from it?
- **GT-4.** M6: what null model? A random walk at the same volatility
  ignores volatility clustering; a block bootstrap of returns keeps it
  but may keep the clusters too. Propose one and say what it cannot
  detect.
- **GT-5.** s5: a penalised score or a reported frontier for cap?

## 10. GEMINI'S ANSWERS (30 SEP ~03:12Z) AND CLAUDE'S CHECK

- **GT-5 AGREED:** report a frontier, not a penalised score.
- **GT-2 ACCEPTED in part:** the harvest condition is `S >= exit +
  spread` (entry fills on the ask, exit on the bid). His "deadband" is
  wrong: the EA's deadband moves resting adds; a limit fills on touch.
  He adds spread widening off-hours: measure it in M5.
- **GT-3 ACCEPTED:** realised losses earlier in the day shrink B; the
  expected cost of overruns (journeys longer than R) belongs in the
  recipe. Both go into M5/M7.
- **GT-1 PARTLY:** right that the leverage equivalence holds only inside
  the room (saturation). His "equal leverage" example is not equal: add
  6 at 0.02 cap 8 has a 48-pip room, add 3 at 0.01 cap 8 has 24; matching
  room and tail slope needs cap 16 on the add-3 side, which the slots
  forbid (T6). His case against per-lot-hour is weak (a lot loses the
  same per pip at any depth). Both normalisers stay; neither is clean.
- **GT-4 PARTLY:** right that the null must keep the pair's trending or
  mean-reverting character; his reasoning is back to front (a
  mean-reverting pair revisits levels anyway, so a random-walk null
  would make clusters look real). "Hurst by pair type" is asserted, not
  shown; ARFIMA fitted to 14 days of M1 is noisy. Claude adds a
  model-free test for "these levels are special": keep the real path
  and compare activity at the actual levels with the same ladder shifted
  by random offsets. M6 uses both.

## 11. FIRST MEASUREMENTS (30 SEP EVENING; C82 M1-M5, M7; M6 NOT YET)

Written by Claude 30 Sep ~23:45Z from the evening export (24 Sep 01:13Z
to 30 Sep 22:01Z; current accounts only, by session) and the bid/ask
dumps of the ejection study (s12 there). Trade history first (s6):
episodes, depths and money come from the broker ledger (`ev_book`
layers: ENT position + close-by); prices only for open-loss paths and M5.
One week, trend-heavy (the 29-30 Sep GBP and AUD days): starting values,
not answers. Code: `research/grid_thesis/gt_report.py`; the counts cross-check with
the fleet cards (A 603 scalps / 33 ejections, B 679 / 61, C 479 / 51)
and the ledger total equals `scalp_history` (A closed $330.66 both ways).

An EPISODE is one side of one instance from leaving flat to flat again
(or open at the window end). 358 episodes (A 121, B 141, C 96).

**M1 deepest layer per episode.** Most episodes stay shallow: depth 1-2
in 52% (A), 55% (B), 52% (C). Depth 5 or more in 23% / 23% / 30%; cap
(8) in 9% / 11% / 14%. Per pair (all fleets): at cap most often AUDCHF
(32% of 19 episodes), NZDCHF (17%), GBPUSD (14%); least NZDCAD (2% of
47). The B1 dial (smaller adds) shows as more capped episodes on B and C.

**M2 scalps per ejection and the worst cluster.** A 18.3 scalps per
ejection, B 11.1, C 9.4 (the smaller adds eject more). The worst 4-hour
run of ejection losses: A -$33.39 (7% of $500), B -$63.65 (13%), C
-$62.17 (12%), all on the 30 Sep 10:00-14:00Z GBP/AUD trend.

**M3 closed P&L per unit of inventory** ($ per layer-day = closed net /
layer-days held): fleet A 0.71, B 0.67, C 0.91. By pair it ranks as the
swings do (M5): GBPUSD 1.2-1.8, NZDCAD 1.0-1.4, AUDNZD, AUDCAD, EURUSD
0.75-1.0; AUDCHF and CADCHF 0.3-0.4 on A and B (1.0 on C, a shorter
window), NZDCHF 0.24-0.30 everywhere; EURGBP negative on all three
(-0.03 to -0.24).

**M4 payback of deep episodes (max depth >= 6): 73, of which 34 closed.**
The 34 closed ones netted +$318.20 in total after passing through a
combined peak open loss of -$570.36; 23 of them ended with no ejection
at all (the deep layers scalped back out). The 39 still open include
the week's losers: EURGBP long on all three fleets (closed -$24.77 to
-$32.81 with 11-15 ejections each), GBPUSD short from 29 Sep 15:32Z
(peak open -$34 to -$39), the AUD longs of 29 Sep.

**M5 swings (FTMO mid, 24 Sep -> 1 Oct, ~5 trading days).** Zigzag legs
per day at 5 / 10 / 20 pips: GBPUSD 82 / 23 / 4.0, AUDNZD 63 / 20 / 5.8,
AUDCAD 53 / 14 / 5.4, NZDCAD 47 / 15 / 4.6, EURUSD 44 / 12 / 2.6, AUDCHF
24 / 7 / 1.6, NZDCHF 19 / 3.6 / 0.6, CADCHF 18 / 4.4 / 0.8, EURGBP 14 /
3.0 / 0.4. A 10-pip exit has at most ~3-7 swings a day to harvest on the
CHF crosses and EURGBP against 12-23 on the majors and the AUD/NZD pairs:
the M3 ranking follows. The longest leg without a 10-pip retrace: AUDNZD
96 pips, AUDCAD 58, EURGBP 48, EURUSD 46, the rest 39-41 -- against a
room to cap (add x 7) of 21 pips (EURGBP, NZDCHF on B/C) to 70 (AUDNZD
A).

**M7 open loss by depth** (peak open loss of an episode by its deepest
layer; median / worst, USD at 0.01): depth 4 about -$4 to -$6.5 / -$8.6;
depth 6 about -$12 to -$13 / -$15; depth 8 (cap) -$22.5 to -$23.4 / -$38.8.
The adverse move from the first entry exceeded the room to cap in 47 of
358 episodes (13%); the median episode used a third of it (0.34).

**Reading (first-order, one week):**
- The ladder mostly works shallow: half the episodes never pass depth 2,
  and deep episodes usually pay back (23 of 34 closed deep episodes
  ended without an ejection, +$318 net).
- What costs money is a few long directional runs (EURGBP long, GBPUSD
  short, AUD longs), each several times a 10-pip retrace: the room was
  exceeded in 13% of episodes and those carry the losses.
- Pairs that swing little per day (CHF crosses, EURGBP) earn least per
  unit of inventory; this is the first number to use when choosing
  pairs and adds, before any cap change.
- M6 below: no clustering detected in this week.

**M6 THE CLUSTER TEST (1 Oct ~01:15Z).** Two looks, both one week.
- **Trade history.** In the 61 episodes with depth >= 5 and >= 10
  scalps, the busiest entry level carried a median 20% of the episode's
  scalps (top two 38%; median 9 levels). If every level were equally
  likely, the busiest of 9 levels would carry 25-27% by chance alone
  (simulated, 12-15 scalps): the real books are LESS concentrated than
  chance. The most any level cycled was 6 times (NZDCAD short, 17
  scalps on 9 levels), not the 10 of the thesis's example.
- **Price path (FTMO bid/ask, 24 Sep -> 1 Oct).** Each level of a ladder
  at A's add and exit cycles independently (buy at the level on the ask,
  sell at level + exit on the bid in a later minute; and the short
  mirror). Concentration (share of cycles at the busiest tenth of
  levels) on the real path vs 40 surrogate paths made by shuffling
  60-minute blocks of the real minutes (keeps intra-hour volatility and
  spreads, removes level memory across hours): real not above
  surrogate on 8 of 9 pairs (p 0.10-0.62); NZDCAD alone p = 0.03 (one in
  nine at 5% is what chance gives). Total cycles on the real path are
  equal to or BELOW the surrogates' (the CHF crosses and AUDNZD 10-40%
  below: the week trended more than a shuffled path). Levels within 2
  pips of a 00 or 50 cycled 0.47-1.63x the rest: no consistent round-
  number effect.
- **Reading:** this week shows no levels that the market revisited more
  than a path with the same hourly volatility would. That does not
  refute the thesis (one trend-heavy week, 10-21 levels per pair, low
  power); it means no layer placement or geometry should be built on
  clusters yet. Rerun on the holdout week (C84) and on each weekly
  export: `research/grid_thesis/gt_report.py` reproduces every number in
  this section from the 30 Sep evening files (seeded; README there).

Line count: 345
