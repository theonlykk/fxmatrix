This message has a line count at the bottom

# ADR-165 -- THE LATTICE NEVER STRANDS: CONTINUOUS RE-ROLL (GEMINI-REVIEWED, s9)

Status: DRAFT, written by Claude 1 Oct ~16:40Z on the operator's decision
(option B, 1 Oct ~16:14Z: "B seems simple - lets do with that"). Extends
ADR-162. Default-OFF input; v2.2 batch; deployed on B, C and D only AFTER
the D1 round 1 verdict (Mon 5 Oct 22:00Z), so round 1's roll economics do
not change mid-round. Cycle 3 (FTMO, ADR-157 ejection) is not touched.

## 0. WHY (1 OCT, THE CHF TREND)

CHF rallied ~14:00-16:00Z. On B, C and D the long sides of AUDCHF, CADCHF
and NZDCHF rolled all eight layers within ~35 minutes; seven sides then
raised `ROLL_STRANDED` (every layer rolled, market 2 add steps past the
lowest effective level: `grind_engine.mqh` 1127-1160) and stopped. The
operator unstranded five by commanded eject (ADR-155) by hand, one Global
Variable each: ~$38 realised, each filled within seconds except one that
trailed the market and needed a second command (fleet-d.md s7; 02_TRAPS
1 Oct afternoon). Operator: "with lattice - we dont stop rolling - we should
not have to do these manual rolls. i feel it will not cascade into
disaster." The account breaker (ADR-158) stays the backstop (ADR-162 s19).

## 1. THE RULE

When a capped side's market crosses its next lattice level and EVERY layer
on the side is already rolled, the EA re-rolls one rolled layer to that
level: its virtual level (VL) is re-labelled to the new level and its exit
moves to `level +/- exit + accrued` (clamped passive), exactly as a first
roll does. Nothing else changes:
- no position is opened or closed; exposure stays `cap` lots per pip;
- every exit stays a resting limit on the far side of the market (no
  market order, no spread crossing; unlike ADR-155/157 ejection);
- nothing is realised until price comes back by about one exit: the
  re-rolled layer's exit is then the nearest (rank 0) and fills, the side
  drops to `cap - 1`, and the existing add logic re-adds at the lattice;
- a gap through several levels re-rolls once per level, in order, bounded
  by `max_layers` per call (the existing loop, 1185).
ADR-162 s1's "the grid never stops" becomes literal: there is no stranded
state while the input is ON. This is C53's "roll here", automated.

## 2. WHICH LAYER IS RE-ROLLED (GR-1)

Proposed: the rolled layer with the HIGHEST effective entry for a long
(LOWEST for a short), i.e. the first rolled, whose VL is furthest from the
market. After the re-roll it holds the new lowest level, so the layers
rotate through the levels in roll order, as ADR-162's "the oldest layer
funds the next level" continued. Cost: the layer re-rolled is the one with
the largest true loss, so the first retrace fill realises the most (entry
far above). Alternative (GR-1): re-roll the rolled layer with the LOWEST
true entry (smallest loss per fill). Ruling wanted.

## 3. AUDIT TRAIL (verified in `main` = `0335f25` EA code)

| # | Fact | Where | Status |
|---|---|---|---|
| R1 | The lattice runs per side only at depth >= cap; the next level is `Grind_ComputeAddTarget` (anchored on the lowest effective entry once any VL exists) and fires when ask <= level (long) / bid >= level (short), with a tick-history extreme folded in | `grind_engine.mqh` 1163-1199, 2111-2140, 1255-1276 | VERIFIED |
| R2 | The roll candidate is the UNROLLED layer with the highest entry (long); rolled layers (VL present) are skipped; with none, `Grind_LatticeMaybeStranded` warns once per episode at `GRIND_VL_STRANDED_STEPS` (2) add steps past the level and the loop stops | 919-944, 1200-1204, 1127-1160; `grind_config.mqh` 21 | VERIFIED |
| R3 | `Grind_LatticeRollLayer` refuses a layer that already has a VL (`GRIND_ROLL_ALREADY_ROLLED`), refuses a closing layer (exit filled or unselectable), modifies the resting exit (or, with none resting, only re-prices the target for the queue), stores the VL, deletes the eject offset, records a clamp shift, reports `ROLL_ACCEPTED`, then runs the exit queue | 985-1051; `grind_pure.mqh` 414-417 | VERIFIED |
| R4 | The VL is one GV per position (`Grind_VLSet` overwrites); effective entry = VL when present; exit queue ranks, I6, the carry pass and reconstruction all price from the effective entry | `grind_carry.mqh` 588-655; ADR-162 s5, s13-s15 | VERIFIED (sites per ADR-162; VLSet overwrite read) |
| R5 | A modify failure backs off 60 s doubling to 1800 s per side; a closing layer stops the loop and feeds `ROLL_CLOSING_STUCK` | 1214-1240, 1077-1124 | VERIFIED |
| R6 | `InpVirtualLattice` requires `InpAutoEject=false` (fail closed) | `fxgrind.mq5` 34, 210-212 | VERIFIED |

## 4. DESIGN

1. **Input** `InpLatticeReroll = false` (default OFF). `OnInit` refuses
   (FATAL, `INIT_FAILED`) `InpLatticeReroll=true` with
   `InpVirtualLattice=false`. Reported in the CONFIG line and the
   `LATTICE_CONFIG` record.
2. **Candidate** (new, pure, testable): `Grind_LatticeRerollIndex(side,
   is_long)` = the rolled layer with the highest (long) / lowest (short)
   effective entry, ties to the lowest `layer_index`. A closing layer is
   NOT skipped here: if the candidate's exit is filled or unselectable, the
   existing closing check STOPS the loop, exactly as for a first roll (R5;
   the side is about to drop below cap and needs no re-roll). Amended with
   the Cursor prompt (GC-1); the draft said "skipping".
3. **Trigger** in `Grind_LatticeTrySide`: where today `idx < 0` calls
   `Grind_LatticeMaybeStranded` and breaks (1201-1204), with the input ON
   take the re-roll candidate and roll it to `level` with `source
   "reroll"`; the loop continues to the next level as for a first roll.
   With no rolled layer to take, the input OFF, or the pause (s4.8):
   today's stranded WARN, unchanged.
4. **Roll**: `Grind_LatticeRollLayer` gains a parameter `allow_reroll`
   (default false) that skips the `ALREADY_ROLLED` refusal; everything
   else in it is unchanged (modify, VL overwrite, offset and shift
   hygiene, report, exit queue). Detail gains `"reroll":true` and the
   previous level (`"from_level"`).
5. **Stranded flag**: reset when a re-roll succeeds, so a later failure
   warns afresh.
6. **No new state**: the VL GV is overwritten in place; reconstruction,
   I6 and the carry pass already price from it (R4).
7. **Throttle (GR-3):** at most ONE re-roll per side per call of
   `Grind_LatticeTrySide` (one tick or timer pass); a gap's backlog clears
   on the following ticks. First rolls (ADR-162) are unchanged.
8. **Rollover pause (GR-4):** no re-roll while the broker clock is in
   23:50-00:15 server time (the carry pass window and the IC break, C87;
   20:50-21:15Z while EDT). Written in server time so it survives the
   November clock change. A side may raise `ROLL_STRANDED` there: expected.

## 5. COST AND BOUND

A first roll moves the oldest layer's exit by `cap x add - exit` from its
entry (ADR-162 s4). A re-roll moves an already-rolled exit by `cap x add`
further (it jumps from the furthest level to one past the nearest), so the
loss realised when that exit fills is `entry - (level + exit)` and grows by
`cap x add` per rotation through the side. Exposure is unchanged (cap lots;
no position is opened); what changes is where the exits sit: always within
about one add step and one exit of the market, so a retrace of about
`exit` realises the oldest layer and re-arms the side. In a trend that
never retraces, nothing is realised and the side carries cap lots: the
same exposure as today's stranded side, with exits near the market instead
of up to 2+ add steps away. The account breaker is the backstop.

## 6. TESTS TO WRITE (tests first, hand-derived; names in the Cursor prompt)

- input refusal: reroll ON with lattice OFF -> FATAL; both OFF and lattice
  ON alone unchanged;
- candidate: highest effective entry among rolled layers (long), lowest
  (short); ties by index; none -> -1; a closing candidate stops the loop
  (no roll, no stranded WARN) as a first roll does (s4.2);
- trigger: all rolled at cap, market through the next level -> one re-roll
  to that level, VL overwritten, exit = level + exit (+ accrued), detail
  `reroll:true` with `from_level`; input OFF -> `ROLL_STRANDED` as today and
  no modify;
- a gap through three levels -> three re-rolls in rotation order over
  three calls (one per call, s4.7);
- rank: after a re-roll the re-rolled layer is rank 0 (nearest) and the
  barbell (rank 0 + highest rank) rests;
- I6 / reconstruction after a re-roll: exit matches the formula from the
  new VL; a restart rebuilds the same book;
- carry pass prices the re-rolled layer from its new VL;
- modify failure on a re-roll -> `ROLL_REFUSED`, backoff, VL NOT
  overwritten;
- the existing ADR-162 suite unchanged with the input OFF.
- throttle: all rolled, a gap through three levels -> ONE re-roll on this
  call, the next on the following call (s4.7);
- pause: server time 23:55 -> no re-roll (stranded WARN as today); 00:16
  -> re-roll; boundaries 23:50:00 (paused) and 00:15:00 (resumes) (s4.8);
- a re-roll of a layer with a recorded clamp shift and an accrual: the
  shift is deleted or re-recorded (never compounded), the accrual KEPT in
  the formula (s9 on Gemini's carry point).

## 7. NEGATIVE SPACE

No market orders; no position opened or closed by this path; no change
to ADR-157/155 ejection, the breaker, the gate, cap, add, exit or width;
no change with the input OFF (byte-identical behaviour, suite green); not
on the FTMO VPS; no deploy before the D1 round 1 verdict.

## 8. FOR GEMINI

Attack the premises; name a missing fact.
- **GR-1** Which rolled layer to re-roll: the first rolled (highest
  effective entry; largest loss per retrace fill) or the lowest true entry
  (smallest loss per fill)? Effect on realised P&L in a trend that
  retraces in steps?
- **GR-2** Trigger exactly when the next level is crossed with nothing
  unrolled (no `GRIND_VL_STRANDED_STEPS` delay), as for a first roll?
- **GR-3** Any bound on re-rolls per side or per episode? The operator
  rules out a wind-down brake (ADR-162 s19); is there a failure mode where
  re-rolls churn requests (API budget, C87's IC rollover stall)?
- **GR-4** Interaction with the nightly carry pass (it prices rolled layers
  from the VL; a re-roll during 20:50-21:00Z), with C87's rollover window,
  and with a commanded eject (ADR-155 validates the most underwater layer
  by effective entry: re-rolls reorder that).
- **GR-5** Is `ROLL_STRANDED` still needed with the input ON (only for a
  side whose every layer is closing or whose re-roll keeps failing)?

## 9. GEMINI'S RULINGS (1 OCT ~16:40Z) AND CLAUDE'S CHECK

His answers pasted by the operator; checked in source by Claude.
- **GR-1 ACCEPTED:** re-roll the highest effective entry (long; lowest for
  a short), as proposed. His "uniform cost structure" is not what a re-roll
  keeps (s5: the realised loss grows by `cap x add` per rotation); the
  point that stands is continuity with ADR-162's oldest-first order.
- **GR-2 ACCEPTED:** re-roll the moment the next level is crossed.
- **GR-3 ACCEPTED with the premise corrected:** a throttle is right (a big
  gap would send a burst: each re-roll is about three requests -- one
  modify, and the exit queue's remove and place as the resting pair
  shifts -- against the 2,000-a-day budget), but C87 was IC holding
  requests across its rollover, not an "API ban". Rule s4.7.
- **GR-4 ACCEPTED with the reason corrected:** his mechanism is backwards.
  A long rolls on the ASK reaching the level and a spread spike lifts the
  ask; a short rolls on the BID and a spike lowers it
  (`Grind_LatticeLevelCrossed`, `grind_pure.mqh` 426-431; `TrySide` passes
  the ask for longs, `grind_engine.mqh` 1193); exits are passive limits a
  spike moves away from. The reasons to pause are the nightly carry pass
  (it re-prices rolled exits in the same window) and IC's rollover
  rejecting or holding requests (C87). Rule s4.8. His line that a
  commanded eject then targets "the most recently re-rolled (furthest)"
  layer is wrong: after a re-roll that layer is the NEAREST; ADR-155 still
  takes the most underwater by effective entry, so it is safe.
- **GR-5 ACCEPTED:** keep `ROLL_STRANDED` as the failure signal (every
  layer closing, or re-rolls failing / paused).
- **His s4 "design flaw" (carry shift compounding) REJECTED: already
  handled.** `Grind_LatticeRollLayer` deletes or re-records the layer's
  clamp shift on every roll (`grind_engine.mqh` 1033-1036, 1040) and prices
  from the new level + the ACCRUED swap (1013-1014). The accrual is the
  position's real financing paid and must NOT be zeroed "as a fresh entry
  would" (that would mis-price the exit by the swap already booked). A
  test pins both (s6).

Line count: 203
