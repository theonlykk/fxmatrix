This message has a line count at the bottom

# ADR-167 -- THE LIGHT SIDE'S ADD BY DEPTH GAP (DESIGN RULED BY GEMINI s11; NOTHING BUILT)

Status: **PARKED (operator 12 Oct ~21:52Z-21:55Z: "we decided that boring was best on the entry
... now we are developing some elaborate adding model for the opposite leg - it isnt
consistent"; "trying to guess the type of bounce back we see is not a useful direction").
Not built in the EA; the replay build stays on `replay-adr167`, unmerged. O-1..4 lapse.**
Before: DESIGN RULED (Gemini GA-1..8, 12 Oct ~02:52Z, checked by Claude:
section 11); O-1..4 open with the operator; no code. **Operator 12 Oct
~03:00Z: the rule is to be tried in the replay harness on the eight weeks of
ticks now, on its own branch (`prompts/cursor_adr167_replay.md`); the EA
build still waits for plan 3.** **sweep6 (12 Oct ~19:10Z, replay, eight weeks, pre-registered): NO VERDICT for all three
tables; 0 of 9 pairs better with any table, 1-2 worse; the summed effect negative (-540 to -699 pips over nine
pairs, AUDCAD the largest share at 46-59%); scalps +10-14%, roll closes +9-15%; a slightly steadier week on most pairs, a worse worst
week (`research/replay/results/sweep_notes.md`, sweep6).** **12 Oct discussion
(`docs/research/light-side-add-discussion.md`): the equaliser helps only when a bounce fails at about 6/6; on a
rally back to the top it sells the same shorts lower. Claude's lean: park. Operator's decision open (O-A); O-1..4 (section 9) matter only if O-A keeps it.** Written by Claude 12 Oct ~02:15Z, revised ~02:45Z (no pip
floor; the operator's rulings of section 9), from the operator's design
idea (backlog C142; 8 Oct ~15:16Z, 10 Oct ~23:41Z to 11 Oct ~00:14Z, 11 Oct
backlog review: "one inventory-control ADR"). No code exists. The EA build
waits until plan 3 is scored (the replay harness is frozen at `145f092`) and
no live EA changes mid-cycle. Default OFF: with the new input empty the EA
must trade exactly as `5bb5fdb`.

Verified in source at `main` `49d6888` (EA code `5bb5fdb`). Each line of
section 2 says VERIFIED (read in source), DERIVED (follows from verified
lines), or NOT MEASURED. Section 9 lists what is the operator's judgement.

## 0. WHY

- The sweeps (10-11 Oct, `research/replay/results/sweep_notes.md`): add,
  exit and layers move the break-even with the scalps; no setting makes an
  edge; the pair matters more than the setting. Exploratory, not plan 3.
- Operator (10 Oct ~23:41Z): "regime detection is impossible, but reacting to
  inventory is very plausible"; "if we have 8 layers vs 1 layer, we have a
  clear signal to correct and as we correct it, the signal decreases".
- Operator (8 Oct): "the first day of an ea is always great - because we have
  so much space for scalps and no need to roll deep layers"; "would it be
  awful to get 6/2 to 6/4? ... the impact of roll would be less if we had
  8/6". Flattening every day was tested and has no edge (sweep5).
- The idea: when one side is much deeper than the other, the LIGHT side adds
  at a smaller step, so a bounce builds it faster and the NET position
  shrinks. The exit is unchanged. The heavy side is unchanged.

## 1. THE RULE (PROPOSED)

For each side, on every add decision:

    gap = (opposite side's filled layers) - (this side's filled layers)

- gap <= 0 (this side is the heavy side, or the book is level): the add is
  the side's configured add, as today.
- gap >= 1 (this side is the light side): the add is the configured add
  scaled by a TABLE indexed by the gap.
- Nothing else changes: the exit, the width, the cap, the lot, the lattice,
  the roll, the roll gate, the carry pass and the exit queue are untouched.

One new input holds the table. Step, linear and dead-zone shapes are table
values, so changing shape is a preset change, not a code change.

## 2. AUDIT TRAIL

| # | Fact | Where | Status |
|---|---|---|---|
| A1 | The next add's price is `anchor -/+ add`: the anchor is the deepest layer's entry, or, once any layer on the side has a virtual level, the lowest effective entry (long; highest, short) | `grind_engine.mqh` 2250-2287 (`Grind_ComputeAddTarget`); `grind_pure.mqh` 149-155 | VERIFIED |
| A2 | The add is already per side: `InpAddPipsLong` / `InpAddPipsShort` (-1 = inherit `InpAddPips`), resolved once at init into `g_geo_add_long` / `g_geo_add_short` and passed down on every call | `fxgrind.mq5` 17-22, 155-162, 466-509 | VERIFIED |
| A3 | A side's depth is the number of its layers (filled positions); a resting add is not a layer | `grind_engine.mqh` 2015-2018 | VERIFIED |
| A4 | The cap always blocks adds: `Grind_CanPlaceEntryLayer` is `current < max` | `grind_pure.mqh` 229-232; engine 2309, 2525 | VERIFIED |
| A5 | A side at the cap can never be the light side: its depth is the cap and the other side's cannot exceed the cap (A4), so its gap is <= 0. The lattice and the roll (which run only at depth >= cap, engine 1404-1414) therefore always see the configured add | A3, A4 | DERIVED |
| A6 | Live presets (all 34: the 27 IC `_r3` and A's 7 `_opt_a_r2`): `InpFillTimePlace=true`, `InpEntryHorizonPips=0`, `InpDeadbandPips=2.0`, `InpRollGateOpposite=0`, `InpSlotNearReserve=8`. The add is placed when the previous layer fills (`Grind_TryPlaceAddAtFill` -> `Grind_SendNextAddEnt`) | `ea/presets_{b,c,d}/*_r3.set`, `ea/presets/*_opt_a_r2.set` (grep, 34 of 34 each); engine 2405-2429, 2298-2402 | VERIFIED |
| A7 | Every tick, `Grind_EnsureAddNext` recomputes the add target and MODIFIES the resting add when its price differs from the target by more than the deadband | engine 3235-3238 (`Grind_OnTickEngine`), 2543-2573 | VERIFIED |
| A8 | So a target that moves with the gap re-quotes the resting add through EXISTING code, bounded by the deadband. No new send path is needed for a "live" target | A7 | DERIVED |
| A9 | The empty side (depth 0) has no add: its first order is the L0 at mid -/+ width, re-centred by `Grind_TryRecenterOppositeL0`. The rule of section 1 starts at depth 1 | engine 3211-3229, 3026-3067 | VERIFIED |
| A10 | The roll gate: a capped side rolls only while the opposite side holds <= N layers; live N = 0, so a capped side is frozen (no add, no roll) while the other side holds any layer | `grind_pure.mqh` 444-447; engine 1278-1282; presets | VERIFIED |
| A11 | The add / width guard (ratio within 0.5 to 4.0) is checked at init only, per side, on the configured add | `grind_pure.mqh` 9-10, 41-52; `fxgrind.mq5` 178-205 | VERIFIED |
| A12 | The slot guard treats an add as "near market" when its target is within one add of mid; a far add must leave `InpSlotNearReserve` (8) units free | engine 2290-2295, 2356-2381; `grind_exitq.mqh` 173-183 | VERIFIED |
| A13 | No add value is read in `grind_recon.mqh`, `grind_exitq.mqh` or `grind_carry.mqh` (0 matches for `add_pips`): no invariant, exit price or carry shift depends on the add spacing. Exits are effective entry (or the rolled level) -/+ exit, + accrued | grep; engine 411-412, 1057 | VERIFIED |
| A14 | The heartbeat sends the CONFIGURED add per side (`add_pips_long`, `add_pips_short`); pipshed computes each side's next level from it (C123) | `fxgrind.mq5` 100-110; pipshed `app.py` 1641-1665 | VERIFIED |
| A15 | The deal-replay sweep (ADR-164) and the replay harness pass the add through the same engine calls | `grind_replay.mqh` 191-196, 269-270, 313-329 | VERIFIED |
| A16 | Live adds (B's anchors, pips): GBPUSD 9, EURUSD 7, NZDCAD 8, AUDNZD 8, AUDCAD 6, AUDCHF 4, CADCHF 4, EURGBP 3, NZDCHF 3; widths 2.5, 2, 2, 2, 1.5, 1.5, 1, 1, 1 | `10_GEOMETRY_REGISTER.md` LIVE NOW | RECORDED |
| A17 | Fleet guard on 12 Oct 01:25Z: B 154, C 159, D 153 of 194 | HANDOFF s80 continued | READ |
| A18 | How often books are skewed, by how much, and what the light side then did: NOT MEASURED (backlog C145) | - | NOT MEASURED |

## 3. DESIGN

### 3.1 The input

    input string InpLightAddByGap = "";   // ADR-167: "" = off

- Empty = OFF: every add is the configured add; the EA trades as `5bb5fdb`.
- Otherwise a comma-separated list of numbers. Entry k (k = 1, 2, ...) is
  the value for gap k; the LAST entry holds for every larger gap. Gap 0 and
  negative gaps always use the configured add.
- Applies to both sides alike (each side reads its own gap and its own
  configured add, A2).

### 3.2 Units: FRACTIONS of the side's add, no floor (GA-1, O-1)

Proposed: each entry is a fraction in (0, 1]; the effective add is

    eff_add = fraction x configured add

Why fractions and not pips: the live adds run 3 to 9 pips (A16), a pair's
add changes with the compass, and long and short can differ (A2). One
fraction table then serves every pair and every round; a pips table would
have to be regenerated per pair, side and round. The operator spoke in pips
("a default add of 10 pips, and a signal triggered add of 5 pips"): that is
the fraction 0.5.

**No floor in pips (operator 12 Oct ~02:25Z).** A first draft carried a
3-pip floor from a remark the operator made in passing ("I don't see why we
have promoted it to a rule"); it also made the rule inert on EURGBP and
NZDCHF. It is removed: the table alone sets the smallest add. The only lower
bound is the existing add / width guard (A11: add >= 0.5 x width), checked
at init on the smallest effective add (3.6).

The half add per pair (fraction 0.5; hand arithmetic from A16), with its
add / width ratio (the guard allows 0.5 to 4.0):

| pair | add | half add | width | ratio |
|---|---|---|---|---|
| GBPUSD | 9 | 4.5 | 2.5 | 1.8 |
| NZDCAD, AUDNZD | 8 | 4 | 2 | 2.0 |
| EURUSD | 7 | 3.5 | 2 | 1.75 |
| AUDCAD | 6 | 3 | 1.5 | 2.0 |
| AUDCHF | 4 | 2 | 1.5 | 1.33 |
| CADCHF | 4 | 2 | 1 | 2.0 |
| EURGBP, NZDCHF | 3 | 1.5 | 1 | 1.5 |

On the tight pairs a half add is 1.5 to 2 pips: layers that close together
can fill in one burst, which behaves like a larger order at one price
(GA-1).

### 3.3 Shapes (all are table values)

For gaps 1..7 at cap 8:

| shape | table | note |
|---|---|---|
| step (operator's first form) | `1,1,1,0.5` | half the add from gap 4 |
| linear (operator's second form) | `0.93,0.86,0.79,0.71,0.64,0.57,0.5` | his 10 -> 5 over gaps 0..7 |
| dead zone + linear | `1,1,0.9,0.8,0.7,0.6,0.5` | nothing for gaps 1-2 |

A worked case (EURUSD, add 7, exit 10; long 6 layers, short 1 layer at
1.10000, gap 5; hand arithmetic). The bounce needed above the short's entry
to take the book from 6/1 to 6/3:

| | 2nd short | 3rd short | bounce to 6/3 |
|---|---|---|---|
| today | 1.10070 | 1.10140 | 14.0 pips |
| dead zone + linear | 1.10049 (0.7) | 1.10105 (0.8) | 10.5 pips |
| linear | 1.10045 (0.64) | 1.10095 (0.71) | 9.5 pips |
| step | 1.10035 (0.5) | 1.10070 (0.5) | 7.0 pips |

The case holds the long side at 6 for clarity; in a real bounce its nearest
layers also scalp out, which narrows the gap sooner. The effect is modest
unless the table is aggressive: the choice of shape is the choice of how
strongly to correct (O-2).

### 3.4 Where the effective add is used

One pure function (`grind_pure.mqh`) parses and validates the table once at
init and returns the fraction for a gap; one engine helper returns a side's
effective add from the two depths. It replaces the configured add in every
place that prices or classifies a SUB-CAP add:

- `Grind_SendNextAddEnt` (the target, and the near-market test of A12);
- `Grind_EnsureAddNext` (the target the resting add is compared with);
- `Grind_ApplyEntryHorizon` (off live; kept consistent: the target and its
  in-range test).

It is NOT used in the lattice or the roll (`Grind_LatticeTrySide`, the
stranded mark): by A5 those always see gap <= 0, and the Cursor prompt will
say so explicitly so that nobody "completes" the change there.

### 3.5 A live target or a latched one (GA-2)

- **(a) Live (proposed).** The target follows the current gap. By A7 / A8 the
  resting add is modified when the target has moved more than the deadband
  (2 pips live). No new state, no new send path. Cost: requests. A linear
  table moves the target by about 0.07 x add per gap change (0.5 pip on
  EURUSD), so several gap changes pass before one modify; a STEP table moves
  it by half an add at its threshold, and a heavy side that scalps and
  re-adds one layer around the threshold would cost up to two modifies per
  scalp. That is an argument against the step shape, or for (b).
- **(b) Latched.** The fraction is fixed when the add is placed and kept
  until that order fills or is removed. No extra requests. Cost: one value
  of state per side (lost at a restart: recomputed at init), and the
  correction arrives one fill late.

In both, a restart recomputes from the live depths: nothing is persisted.

### 3.6 Validation at init (fail closed)

- A table that does not parse, has an entry outside (0, 1], or rises with the
  gap (entry k+1 > entry k): FATAL at init, as the other geometry inputs.
- For each side, the SMALLEST effective add the table can give must pass the
  add / width guard (A11): FATAL otherwise.
- The table is printed at init and carried in the INIT `config_event`.

### 3.7 Telemetry

- The heartbeat gains the EFFECTIVE add per side and the gap (A14: pipshed's
  next-level cell would otherwise be wrong on a light side). pipshed follows
  in its own patch, after the EA.
- No archive marker per change (it would fire on every fill). The archive
  can rebuild the effective add from depths and the table.

## 4. WHAT IT DOES TO THE BOOK (mechanics, not measured)

- **Net exposure:** a bounce builds the light side sooner (section 3.3), so
  the net position is smaller during and after the bounce. If the trend then
  resumes, the light side's extra layers scalp out at their unchanged exits.
- **The light side reaches the cap sooner.** Its ladder is shorter than
  today's by up to the table's smallest fraction (at 0.5 throughout, EURUSD's
  eight layers would span about 28 pips, not 56; less extreme in practice
  because the fraction rises as the gap closes). A bounce of that size can
  end at 8/8.
- **The roll gate (A10).** With the gate at 0 the capped heavy side is frozen
  while the light side holds ANY layer. A faster light side means the heavy
  side spends more time frozen and rolls later. At 8/8 both sides are
  frozen (no add, no roll) while their nearest layers still scalp; a side
  rolls again only once the other is flat. That is the gate as ruled
  (ADR-166, operator 6-7 Oct), now reached more often. **Operator, 12 Oct
  ~02:40Z, accepts it:** "rolling when we have 8/0 makes sense. massive mkt
  move, and we have nothing against it. however, we try very hard to put
  positions on in line with momentum and we take our foot off the gas as we
  balance. the full scaled opposite direction will not retrace back up to
  the point where the gap down happened, but that is fine and it might mean
  we fade the dead cat bounce." (spelling tidied)
- **A shorter ladder afterwards.** If the former light side becomes the heavy
  side, its layers sit closer together, so its lattice starts nearer the
  market and its first rolls come sooner. On a random walk that trades
  recovery for insurance: lower variance of the book, not more edge.
- **Slots (A17).** Each extra layer is one more position plus its exit. The
  per-instance maximum is unchanged (the cap), but more books will sit near
  8/8, and the fleet guard (194) is the binding constraint: nine instances
  near 8/8 cannot all fit. A first probe on a few pairs, not nine.
- **Requests:** one placement per extra layer and its exit; under 3.5 (a),
  the extra modifies described there.
- **Commission and carry:** more closes on the light side at the same exit
  (each pays the same commission as any scalp); more inventory held on both
  sides overnight.

## 5. WHAT IS IN AND OUT OF v1

In: the light side's add by gap (sections 1-3).

Out, each its own later decision (the operator folded them into this ADR as
options, 11 Oct; they are listed so that Gemini can say if one belongs in):

- **The empty side's L0 width (C103).** A9: the rule starts at depth 1. A
  tighter first order while the other side holds layers is a second input
  and needs the width guard re-derived. It is the natural v2.
- **A cap or pre-emptive roll on the heavy side (C146).** It realises losses
  and contradicts the roll gate as ruled.
- **A larger lot on the counter side (C127).** Needs partial-fill handling
  (C14). Note: a light-side add near zero approximates it (several 0.01
  layers at almost one price).
- **Widening the HEAVY side's add** (operator: a separate test). The table
  format could later take negative gaps; not in v1.
- **Rolling on the gap instead of the cap (C147 (1)).** A different rule.

## 6. EVIDENCE AND ORDER OF WORK

1. **This document to Gemini** (section 10). His rulings checked in source.
2. **From our own trades, before any build (C145; no price statistic):** the
   one-minute `state_snapshots` (depth per side since 8 Oct) joined to
   `scalp_history` and `ROLL_ACCEPTED`: time spent at each gap, per pair and
   fleet; what the light side's next fills were; how long the heavy side was
   gated. Predictions written down before the result. It sizes the rule
   (how often would it act at all) and gives 3.5 (a)'s request count.
3. **The Cursor prompt** (RESTATE AND STOP; tests first; the off-switch test:
   with the input empty every add target equals today's), Gemini, Cursor,
   DeepSeek (it prices orders), the operator's GUI compile, the suite.
4. **A live probe, pre-registered before its Load:** one IC fleet with the
   table against B without it, on the same geometry (O-3). Decided on the
   cohort's equity; reported: time at each gap, net exposure, S, R,
   `ROLL_DEFERRED`, requests, the guard.
5. **The replay:** the harness can take the input only after plan 3 is
   scored. A pass licenses count-level use for geometries bracketed by the
   live fleets; a gap table is outside that bracket, so a replay of it is
   indicative only and the live probe decides.

## 7. TESTS TO WRITE (outline; names and hand-derived values in the Cursor prompt)

- Parse and validate: empty, one entry, the three shapes of 3.3; each FATAL
  case of 3.6.
- The fraction for gaps -2, 0, 1, k, beyond the table's length.
- The effective add for each fraction; the configured add is never exceeded;
  the guard's FATAL when the smallest effective add is under half the width.
- OFF: with the input empty, the add targets of the existing add tests are
  unchanged (the whole existing suite must pass untouched).
- A light side at depth 1 with the other side at 6: the placed add's price
  (the worked case of 3.3).
- A gap change with a resting add: under the deadband no modify; at or
  beyond it exactly ONE modify to the new target, and none on the ticks
  that follow (GA-8, section 11).
- A side at the cap: the lattice level and the stranded mark use the
  configured add (A5).
- Both sides at once (long light, then short light after a flip).

## 8. NEGATIVE SPACE

- No change to the exit, the width, the cap, the lot, the lattice, the roll,
  the roll gate, the exit queue, the carry pass, reconciliation or any
  invariant.
- No new send path and no market order.
- No persisted state.
- No use of price history, volatility or any signal: the only inputs are the
  two depths.
- Not mid-cycle: no build before plan 3 is scored; no Load on A before its
  trial ends (~21 Oct).

## 9. FOR THE OPERATOR (judgement, not measurement)

- **RULED 12 Oct ~02:25Z-02:40Z:** no pip floor (3.2); the cap stays 8
  ("we have some limited evidence that it doesn't really matter if we use 6,
  8 or 10 layers. we also have seen there is an issue when we get large
  positions and abrupt market moves. perhaps we leave as is"); the gate's
  consequence accepted (section 4).
- **O-1.** Units: fractions of the pair's own add (3.2), or a table in pips
  per pair?
- **O-2.** The first shape to try live: step, linear, or dead zone + linear
  (3.3)? Claude's lean: linear, because a step re-quotes at its threshold
  (3.5) and a dead zone delays the correction the signal asks for.
- **O-3.** The first live probe: which fleet carries the table, against B,
  and on which pairs (section 4: not all nine at once)? This replaces a
  compass round on that fleet.
- **O-4.** If plan 3 does not pass: does the EA build go ahead on the live
  probe alone?

## 10. FOR GEMINI (attack the premises; say which fact is missing)

- **GA-1.** Fractions with no floor (3.2) against a table in pips. Is there
  a failure of the fraction form we have not seen (per-side adds, half-pip
  adds such as EURGBP's 2.5 on C)? Is the add / width guard enough of a
  lower bound when a half add is 1.5 pips, or is a bound against the spread
  needed?
- **GA-2.** A live target through the existing deadband re-quote, or a
  latched one (3.5)? Which is safer for the order path, given A7?
- **GA-3.** A5: is it right that the lattice and the roll can never see a
  shrunk add? Name any path where a side at or above the cap could read a
  positive gap.
- **GA-4.** The roll gate at 0 with a faster light side (section 4): more
  time frozen, and 8/8 more often. The operator accepts it (section 4).
  Is there a failure in it we have not seen (not: should the gate change;
  the gate is his ruling and is not open)?
- **GA-5.** Validation (3.6): FATAL at init for a bad table, and the guard
  checked on the smallest effective add. Anything that must also be checked
  at run time?
- **GA-6.** The near-market test and the slot reserve (A12) with the
  effective add: correct, or should the reserve keep the configured add?
- **GA-7.** v1's scope (section 5): should the empty side's L0 (C103) be in
  the same build, or stay a second step?
- **GA-8.** Which fact is missing, and which premise of ours is wrong?

## 11. GEMINI'S RULINGS (GA-1..8, 12 Oct ~02:52Z) AND CLAUDE'S CHECK

**No design change. One test sharpened (section 7). Five premises corrected.**

- **GA-1: ACCEPTED** (fractions, no floor; no spread bound). His reason
  holds: a resting limit is passive, the spread delays a fill and does not
  move the target. Premise corrected: the add / width guard is ADR-153's
  typo catcher, not an "engineered geometric limit"; it is simply the only
  lower bound left.
- **GA-2: ACCEPTED (the live target), two premises corrected.**
  - He says a latched add "creates state desynchronization (the EA wants X,
    the broker holds Y)". Not so: latched, the EA would want what rests. The
    ruling does not depend on it.
  - He says the cost is "safely bounded by the 2-pip deadband". The deadband
    bounds WHEN a modify happens, not HOW MANY: a step table crosses it at
    every threshold crossing (3.5).
  - **Found in the check (source):** `Grind_PriceWithinDeadband` is a strict
    `<` (`grind_pure.mqh` 164-171), so a resting add moves only when its
    target has shifted by 2.0 pips or more. The LARGEST shift a 0.5 table
    can make is half the add: 1.5 pips on EURGBP and NZDCHF (never
    re-quoted: the gap acts only when the next add is placed), 2.0 on
    AUDCHF and CADCHF (at the limit), 3 to 4.5 on the other five. On
    EURUSD a re-quote needs the fraction to change by 0.29 or more. So the
    "live" target is mostly a placement-time rule with an occasional
    re-quote on the wide pairs. Accepted as is; recorded for the probe.
- **GA-3: ACCEPTED** (A5 stands; his arithmetic is the document's).
- **GA-4: ACCEPTED (no unseen failure), premise corrected.** He writes "full
  lock until balance returns". 8/8 IS balance: the lock on a capped side
  ends when the OTHER side is flat (A10), and meanwhile the nearest layers
  still scalp. "rank-7 exits" is not a thing here (the exit queue rests the
  nearest exit per side).
- **GA-5: ACCEPTED.**
- **GA-6: "AMENDED", but no change: the effective add stays in the
  near-market test. Two premises corrected.**
  - `InpSlotNearReserve` does not "protect API quotas". It keeps 8 of the
    account's 200 position-and-order slots free for near-market entries
    (`grind_exitq.mqh` 173-183: a far add needs used + resting <= 186, a
    near add 194).
  - The direction is the opposite of his worry: a smaller add makes the
    near-market band NARROWER (target within one effective add of mid), so
    the test gets stricter, not looser. At a fill the next add sits one
    effective add from the anchor, inside the band either way, so behaviour
    at fill time is unchanged.
  - His "monitor slot consumption" is already in the probe's report
    (section 6 step 4: the guard).
- **GA-7: v1's scope stands** (C103 stays out). His reason overstates the
  work ("completely rewriting" the re-centre) and calls the L0 "entry-horizon
  compression" (the entry horizon is ADR-152's held adds, off live). The
  ruling itself is the document's lean: one variable in the probe.
- **GA-8: ANSWERED in source; a test sharpened.** His attack: a heavy-side
  fill in flight changes the gap just after the light side placed a tight
  add, and "API settlement latency" could make the gap oscillate and
  hyper-trigger modifies.
  - Depth changes ONCE per fill, when the EA processes the deal:
    `Grind_AppendLayer` (engine 2972) and, on a close, `Grind_RemoveLayerAt`
    (2940). There is no state in which it flickers back; "touch + lam" is
    the replay's timing model, not the EA.
  - The layer is appended BEFORE the fill-time add is placed (2972, then
    2978), so a side's own new add already sees its new depth.
  - After a modify the resting price equals the target, so the following
    ticks do nothing (2568-2573).
  - So each gap change costs at most one modify, and only when the shift
    is 2.0 pips or more. Section 7 now asks for exactly one modify and none
    on the following ticks.
- **His sign-off has no questions for us**, though the covering note asked
  for them (BOOT s1's tell); every ruling above was checked against the
  code. Not checked by him and still open: A18 (how often books are skewed)
  and the operator's O-1..4.

Line count: 428
