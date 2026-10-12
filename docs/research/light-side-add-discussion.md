This message has a line count at the bottom

# THE LIGHT SIDE'S ADD: ROLLS AT 8/0, THE EQUALISER IN NUMBERS, A SLOWER SHORT (DISCUSSION RECORD)

| | |
|---|---|
| Written | 12 Oct 2026 ~20:45Z (HANDOFF s80 continued 9), at the operator's request: "we should document this all" |
| What it is | A record of the operator's discussion with Claude after sweep6, 12 Oct ~19:30-20:40Z. Worked examples, a toy model and a proposal. NOTHING here is ruled unless it says "operator" |
| Evidence level | s1 is read from source. s2-s5 use a TOY model (`research/grid_thesis/light_side_toy.py`): an illustration on four hand-picked paths, not a test. The only data result is sweep6 (`research/replay/results/sweep_notes.md`) |
| Related | ADR-167 (`docs/architecture/ADR-167-light-side-add-by-depth-gap.md`); backlog C142, C145, C147, C149; sweep6 |

## 1. ROLLS HAPPEN ONLY AT 8/0 (ROLL GATE 0)

- **The rule in source.** `Grind_LatticeOnTick` (`ea/grind_engine.mqh`
  1404-1414) tries a roll on a side only when that side is at cap
  (`Grind_SideDepth >= max_layers`). `Grind_RollGateHolds` (`ea/grind_pure.mqh`
  444-447) holds the roll when `opposite_depth > gate`. With
  `InpRollGateOpposite = 0` on every IC fleet (ADR-166), a roll needs the
  heavy side at 8 AND the light side at 0 FILLED layers. **Every roll happens
  at exactly 8/0.** From 8/1 to 8/8 rolls are frozen; `ROLL_DEFERRED` is
  noted once per episode. The gate never undoes a roll already made.
- **What a roll is.** Virtual: no broker order. It is booked at the lattice
  level (virtual level = that level, exit = level + exit pips); the rolled
  layer's exit order rests at the broker.
- **The empty side's first order (L0).** It trails at mid + width (EURUSD
  width 2) and is re-centred when it is more than 3 pips from mid
  (`InpStrandedThreshPips`) and the shift is at least the 2-pip deadband. In
  a fall it therefore sits 2-4 pips above mid. C103 step 2 (a near-zero
  counter width) was never built.

**Worked example (the operator's, EURUSD-like units, pips on a line):** 8
longs at 200, 190, ..., 130 (add 10, exit 10); the market falls to 121.
- At 121 the book is 8/0 and down 352. The first short rests as a sell limit
  at about 123 (mid + 2).
- The market falls to 113. The sell limit is re-centred to about 115. At 120
  the long side ROLLED (8/0, cap): booked at the 120 level, its exit at 130.
  The next roll level is 110.
- If the market bounces and fills the 115 sell first, the book is 8/1 and the
  roll at 110 is DEFERRED (frozen until the short side is back to 0).
- **Operator (12 Oct):** "this doesnt seem awful - we are not cancelling
  rolls - we are just giving the market a chance to bounce and we are
  scalping while waiting for it". And: "the 8/0 to 8/1 move is an important
  one to 'moderate' the roll. it also creates a starting point for the short
  leg that i like as we have seen the mkt has scope to trend lower".

## 2. THE EQUALISER (ADR-167, LINEAR TABLE) IN NUMBERS

Same book, low 121, first short at 123, the market then rallies. The short
side's next add = 10 x fraction(gap), gap = longs - shorts (linear table:
gap 7 -> 0.5, 6 -> 0.57, 5 -> 0.64, 4 -> 0.71, 3 -> 0.79, 2 -> 0.86, 1 -> 0.93).

| Price | Event (equaliser) | Book | Today's rule (add 10) at the same point |
|---|---|---|---|
| 123 | first short | 8/1 | the same |
| 128 | short add (gap 7: 5 pips) | 8/2 | next short at 133 |
| 133.7 | short add (gap 6: 5.7) | 8/3 | 133: 8/2 |
| 140 | long 130 exits | 7/3 | 7/2 |
| 140.1 | short add (set at 8/3, gap 5: 6.4; after the long exit the new target 140.8 is inside the 2-pip deadband, so it stays) | 7/4 | 143: 7/3 |
| 148 | short add (gap 3: 7.9) | 7/5 | |
| 150 | long 140 exits | 6/5 | 6/3, then 153: 6/4 |
| 156.6 | short add (set at 7/5, gap 2: 8.6; 157.3 at gap 1 is inside the deadband) | 6/6 | |

(Each row is the toy's own fill log, `run(..., log=[])`.)

- **Back down from 156.6 to 121:** equaliser -283 (8/2), today -300 (8/1).
  The equaliser's extra shorts scalp on the way down.
- **On to 200 instead:** equaliser -357 (1/8), today -266 (1/8). The
  equaliser has the same eight shorts but sold them LOWER.
- **Operator:** "the layer equaliser needs a very specific thing to happen
  for it to appear beneficial" (in the toy: a bounce that fails at about 6/6); "my
  motivation is that we really want the mkt to return back to 200".
- **sweep6 agrees in data** (eight weeks, nine pairs, pre-registered): NO
  VERDICT for all three tables, 0 pairs better, summed -540 to -699 pips;
  scalps +10-14%, roll closes +9-15%. The light side builds faster, unwinds
  to 0 faster, so deferred rolls are released sooner: more rolls.

## 3. A TWO-SIDED GRID DOES NOT COLLECT A FULL REVERSION

- Holding the eight longs from 121 back to 200 makes +280 (0 + 10 + ... + 70).
- Today's grid on the same straight rally ends at -266: seven long scalps
  (+70) and eight shorts sold from 123 to 193, all under water at 200.
- **The grid gives back about 550 pips of the reversion** to the short leg it
  builds on the way up. Symmetric adds are not neutral on a path: they are a
  small bet AGAINST the bounce carrying on.

## 4. THE OPERATOR'S QUESTION

"what would a framework for a slower short add look like? i confess it is
harder to choose this over the current symmetrical approach - although it
now seems like that symmetry isnt neutral. what would an add structure look
like that got us back to flat at 200?"

**Flat at 200 is reachable only one way.** On the straight rally the long
side scalps +70 and the long at 200 is flat. The first short (123) alone is
-77 at 200. So the best any rule can do with that first short is -7: put on
the first short and add NO further short until the short side holds as many
layers as the long side (here, only at about 200).

## 5. THE TOY'S RESULTS (corrected 12 Oct ~20:40Z)

Start 121, equity -352. Equity at the path's end (book at the end):

| Rule | A 121->200 | B 121->156.6->121 | C chop 121-131 x3 | D 121->200->121 |
|---|---|---|---|---|
| today (add 10) | -266 (1/8) | -300 (8/1) | -350 (8/1) | -210 (8/1) |
| equaliser (linear) | -357 (1/8) | -283 (8/2) | -343 (8/2) | -213 (8/2) |
| inverse 10 x (1 + gap/4) | -130 (1/6) | -320 (8/1) | -350 (8/1) | -230 (8/1) |
| geometric 10, 20, 40 ... | -128 (1/4) | -310 (8/1) | -350 (8/1) | -250 (8/1) |
| x2 while gap >= 4 | -164 (1/7) | -320 (8/1) | -350 (8/1) | -220 (8/1) |
| pause while gap >= 3 | -37 (1/4) | -330 (8/1) | -350 (8/1) | -250 (8/1) |
| pause while gap >= 1 | -7 (1/1) | -330 (8/1) | -350 (8/1) | -280 (8/1) |

Against today's rule: pause gap >= 1 is +259 on A, -30 on B, 0 on C, -70 on
D; pause gap >= 3 is +229 / -30 / 0 / -40; inverse +136 / -20 / 0 / -20;
equaliser -91 / +17 / +7 / -3.

- **The correction.** The first version of the toy (produced ~20:30Z and
  caught before it was reported: the operator saw only the corrected
  rows; s80's answer, 12 Oct ~21:15Z) left a short add's sell limit
  BELOW the market when a rule's target narrowed, and filled it there later
  at the stale, worse price. The
  EA moves such a limit to the market (ADR-013 clamp, `Grind_Adr013ClampSell`
  in `Grind_SendNextAddEnt`). Fixed: the pause rows went from -266 to -37
  (gap >= 3) on path A; the other rows did not change.
- **What the table shows.**
  - Slower shorts change only the shorts; the long book is the same under
    every rule.
  - Their cost is the short scalps given up when the bounce fails: B's 30
    is today's shorts at 133, 143, 153 scalping back down; D's 40-70 is the
    shorts near the top.
  - After a failed bounce every rule is back at 8/1 at 121 (the equaliser
    at 8/2), so the risk of new lows from there is the same.
  - A 10-pip chop at the low hardly reaches a second short under any rule.

## 6. A FRAMEWORK FOR A SLOWER LIGHT SIDE (CLAUDE'S PROPOSAL, NOT RULED)

Three settings, applied to whichever side is light (after a big rally the
heavy side is short and the rule slows the LONG adds):
1. **The moderator (keep).** The 8/0 -> 8/1 first order at mid + width stays
   as it is: it slows the roll and starts the light leg.
2. **When later light adds start.** No light-side add while gap >=
   threshold. Threshold 1 = flat at 200 in the toy; 3 = a middle setting.
3. **How far apart once they start.** Configured add x multiplier(gap),
   the multiplier rising with the gap: ADR-167 turned round (multiply, not
   shrink).

**What it is.** A bet that a bounce carries on, which the heavy side's grid
already makes: it doubles that bet, it does not hedge it. Today's symmetric
rule is a smaller bet the other way. Not neutral either way on a path; the
toy cannot say which pays on our pairs.

**Limits of the toy:** no rolls (no path below 120), no spread, no
commission, no carry, four paths chosen by hand, one geometry.

## 7. SWEEP7 (OPERATOR 12 OCT ~20:43Z: "we might do a sweep 7")

The operator's words: "we might do a sweep 7 - both to test the slower short
add and our accessibility to IC markets". Not pre-registered; nothing built.

- **(a) The slower light side on the eight weeks.** The replay build on
  `replay-adr167` (`ed5d052`) has the table input, but
  `Grind_LightAddTokenOk` accepts only 0 < value <= 1 and
  `Grind_LightAddParse` rejects a table that RISES. A test needs a small
  change through the pipeline (prompt -> Gemini -> Cursor -> the operator's
  compile -> suite): values above 1 allowed, a table that never falls.
  Candidates (gap 1, 2, ...; the last entry holds for larger gaps):
  - inverse: `1.25;1.5;1.75;2;2.25;2.5;2.75`;
  - stepped: `1;1;1.5;2;3;4`;
  - a pause stand-in: `1;1;10` (x10 = 100 pips on EURUSD, never reached in
    a normal bounce). A true pause would be a separate input.
  Then sweep7 pre-registered like sweep6 (C0 off rows = sweep4; E1 / E2;
  `analyse.py` first).
- **(b) "Our accessibility to IC markets".** Since 12 Oct ~19:06Z IC has
  said its service is not available in Ontario (HANDOFF s80 continued 9);
  the web dashboard refuses the login, the terminals are still logged in.
  The replay terminal (`D:\mt5-replay`) starts on IC 53077984's read-only
  login. Claude's reading (to confirm with the operator): sweep7's runs
  double as a check that the replay terminal can still start, log in and
  run. Sweep7 needs no new IC data: it reuses sweep4's eight weeks of ticks.
- **Order:** after plan 3's holdout export (Tue 13) and the restore of
  `replay-harness` for plan 3's runs, or on a separate terminal copy, so the
  plan 3 harness is never left on a sweep build.

## 8. OPEN FOR THE OPERATOR

- O-A: ADR-167 on, changed or parked, given sweep6 and s2-s3 (Claude's lean:
  park). ADR-167's O-1..4 matter only if O-A keeps it (s80, 12 Oct ~21:15Z).
- O-B: sweep7 (a): go ahead with the parser change and pre-registration?
  Which candidate tables?
- O-C: sweep7 (b): is the reading in s7 (b) what was meant? (The reading is
  Claude's alone; the operator's only words are the one line in s7.)

**ANSWERED (operator 12 Oct ~21:52Z-21:55Z):** O-A PARKED, O-B DROPPED: "we decided
that boring was best on the entry - on the initial path that gives us 8/0 - now we
are developing some elaborate adding model for the opposite leg - it isnt
consistent"; "trying to guess the type of bounce back we see is not a useful
direction". Every rule in s5 is a bet on the path (the equaliser that a bounce
fails, a slower short that it carries on); symmetric adds are the simplest bet, not
a neutral one (s3). O-C: the replay terminal's IC login was tested 21:47Z and
works (HANDOFF s81 continued). Kept: symmetric adds, cap 8, rolls only at 8/0, the
8/0 -> 8/1 first short. The name sweep7 now belongs to the operator's eight-week
carried run (`research/replay/results/sweep_notes.md`, sweep7).

Line count: 204
