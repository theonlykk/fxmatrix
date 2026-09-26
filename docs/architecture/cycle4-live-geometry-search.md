This message has a line count at the bottom

# CYCLE 4 DESIGN NOTE -- LIVE PER-SIDE GEOMETRY SEARCH

**Status:** Draft idea, 2026-09-21, rev 2 after Gemini's critique (s7).
Not an ADR and not scheduled. Cycle 3
(pre-registered, one arm per pair) runs first and is untouched by this.
**Rev 3 (operator, 2026-09-26): s8.** The direction for cycle 4, still
not an ADR. Arms are FLEETS (same pairs, one account and box each), steps
by compass, the score is closed P&L; the live book is kept and rebuilt.
Where s8 differs from s2-s6 (Part A's reflect, R1, R2, R5, s5's slots),
s8 rules. The 24 Sep "rev 3 pending" (incremental steps on a live book,
C46-C48) is folded in.
**Origin:** the operator (Lead Quant), in conversation, written up by
Claude.

---

## 1. THE PROBLEM

We do not know what add and exit actually do. A wider exit may give more
pips per scalp and fewer scalps; a tighter add may give more scalps and a
deeper book. The balance depends on the price path, so it cannot be
derived from first principles. The simulator cannot settle it either: its
cost-model bugs made every sim-derived geometry conclusion provisional,
and it has never been reconciled to live fills.

Carry makes it worse. Long and short pay very different carry, but both
sides of an instance share one add and one exit today.

---

## 2. THE IDEA

**Part A -- live simplex search.** On each chosen pair, run THREE arms
(OPT, ALT, OTH), each at a different (add, exit) point. Three points in 2-D
form a simplex. After enough evidence, retire the worst arm and replace it
with a new point stepped away from it, through the other two (the
Nelder-Mead "reflect" move). Repeat. The fleet drifts towards better
geometry and keeps tracking it as volatility changes.

**Part B -- per-side geometry.** Each arm carries its own add/exit for the
LONG side and for the SHORT side. The sides are already separate books
(layers, ranks, exit queue and invariants are all per side), so each arm
yields two measurements, and the search becomes two 2-D searches run in
parallel rather than one 4-D search. This answers directly whether a
strongly negative-carry side does better with tighter or wider geometry.
It subsumes skewing: a skew is one special case of per-side geometry,
chosen by the data rather than by us.

---

## 3. WHAT IT BUYS

1. **Carry addressed properly.** Carry is scored from swap actually
   charged, per side, not assumed.
2. **The most information per trade.** Arms on the same pair see the same
   path, so every comparison is paired: trend and chop hit all three arms
   alike and most market noise cancels.
3. **No bias in choosing add and exit.** The data moves the points, not
   our hunches.
4. **A target for the backtest.** Each arm's live record (scalps, pips,
   depth, carry, on a known price path) is exactly what the simulator
   must reproduce. **Once the sim reconciles to these observations, the
   live search is no longer needed:** geometry can be chosen from price
   action directly, and changed instantly.

Item 4 is the end goal. The search is scaffolding that also produces the
calibration data.

---

## 4. DESIGN RULES

- **R1 Step on evidence, not time.** Replace the worst arm only when its
  paired per-scalp gap to the others exceeds that gap's own scatter. For
  scale: the signal-vs-dumb A/B needed ~190 scalps to call two EVs equal.
  The pip deadband governs step SIZE, not WHEN to step.
- **R2 Score completed scalps; police depth separately.** Score =
  completed scalps (pips, count) + swap charged, EXCLUDING ejections. No
  mark-to-market in the score: a snapshot of the open book is noise
  (Gemini, s7). Scalps alone would reward an arm that parks losses in a
  deep book, so depth is a separate yardstick: either a penalty on
  time-averaged depth or stranded layers, or a hard rule that an arm
  past a depth limit cannot win.
- **R3 Compare within a side, across arms.** Long against short on one pair
  mostly measures the week's trend. The carry test is: on the paying
  side, did the tighter arm beat the wider arm over the same nights?
- **R4 Two clocks.** Scalp results settle in days; carry needs weeks and
  must span a triple-swap Wednesday. Steer on scalps first, and fold carry
  into the score once enough nights have accrued.
- **R5 A replaced arm starts flat.** Exit is frozen on a live book (I6).
  Replacement means: the old arm stops adding, the new point starts on a
  fresh magic, and the old book is cleared by commanded ejection (C15 /
  ADR-155) rather than left to drain passively for weeks.
- **R6 Never stop exploring.** Keep a minimum step and re-test retained
  points now and then, because the optimum moves with volatility. Do not
  let noise collapse the simplex onto one point.
- **R7 Cadence.** Steps come every few days or after N completed scalps,
  never intraday.

---

## 5. CONSTRAINTS TO SOLVE BEFORE IT BECOMES AN ADR

- **Slots.** Rough arithmetic, to be verified against the commitment-guard
  formula. Per side: up to 8 positions + 2 barbell exits + 1 resting add =
  11. Three pairs x three arms x two sides = 18 sides, x 11 = ~198. That is
  above the ~194 guard (Gemini confirmed the arithmetic). Operator's
  choice: **cap 6, done right, over cap 8 done wrong** -- tune at cap 6 AND
  trade at cap 6 (18 x 9 = 162, leaving room for an arm being ejected).
  Fewer pairs is the other lever.
- **Per-side inputs are real engineering.** The I6 exit check, the ADR-153
  ratio guard, presets, telemetry, pipshed and the simulator all assume
  one add and one exit per instance. The exit queue and F1 are
  unaffected.
- **Shared budgets.** Slots and the API budget are shared by both sides,
  so a churning side can crowd out the other. Watch slot and API use per
  side as a guard; it does not require a 4-D search.
- **Half the scalps per side.** Each per-side comparison takes longer to
  mature. R1's gate must account for it.
- **Currency exposure.** The ring structure (each currency in two pairs)
  still applies; the choice of pairs should respect it.
- **Carry data.** Swap per position is available; attribution per side
  and per arm needs a telemetry/pipshed view (links to backlog C10).

---

## 6. OPEN QUESTIONS

- Q1. Which three pairs? Candidates: one strongly negative-carry pair (the
  carry test), one quiet cross, one major.
- Q2. The depth yardstick (R2): a time-averaged penalty or a hard limit?
  What weight on carry?
- Q3. Minimum step and deadband in pips, per pair?
- Q4. Can the simulator be run in parallel on the same paths from day one,
  so reconciliation (item 4) starts immediately rather than at the end?

---

## 7. GEMINI CRITIQUE (2026-09-21) AND RESPONSE

| # | Gemini | response |
|---|---|---|
| 1 | Nelder-Mead is fragile on noisy objectives; use Bayesian optimisation (Gaussian process + expected improvement) | **Declined.** Three points define a plane whose tilt says which way is up: a sound local model when stepping every few days (R7). BO adds a surrogate with its own tuning and assumes a stationary surface, which ours is not. The noise concern is covered by R1 and R6 |
| 2 | Sides are not independent: they share slots and the API budget | **Partly accepted.** True, but that coupling exists today. Added a per-side slot/API watch (s5); the two 2-D searches stand |
| 3 | Fewer pairs beats cap 6, because the optimal add depends on ladder depth | **Answered.** The objection bites only if we tune at 6 and trade at 8. Tuned and traded at cap 6, the optimum found is the one used |
| 4 | The sim must match micro-structure, not just totals; offsetting errors can fake agreement | **Agreed on the point, not the standard.** The target is trade-level reconciliation, which is what defeats offsetting errors. Tick-for-tick identity is neither achievable nor needed |
| 5 | Mark-to-market in the score steps on noise; draining losers hog slots for weeks | **Accepted, and fixed.** R2 now scores completed scalps (ejections excluded) with depth policed separately; R5 clears retired arms by ejection |

## 8. REV 3 (2026-09-26, operator) -- ARMS AS FLEETS, COMPASS STEPS, CLOSED P&L

Decided in conversation 2026-09-26 (HANDOFF s17), written up by Claude.

**8.1 Objective.** Maximise CLOSED P&L: every closed trade (scalps, rolls,
ejections) with commission and swap. Open P&L is the drag, handled by
passive ejection (ADR-162); reported, never scored. Replaces R2 (scalps
only, depth policed separately): with the lattice on, depth becomes
realised roll cost, so the closed score polices depth itself. A tighter
add books more scalps but shortens the breathing room (cap x add: 40 pips
at add 5, 24 at add 3), so rolls come sooner and cheaper; the score, not
a rule, decides whether that pays.

**8.2 The new EA (C47).** Four levers: add and exit for the long side, add
and exit for the short side. Width follows add (rule OPEN; the operator
favours a very tight L0 to start trading at once; the ADR-153 add/width
guard is re-derived, not inherited, since add 5 on width 1 breaks it).
Everything that prices an add or an exit is per side: add targets, exits,
the lattice's virtual levels and roll cost, the carry pass, the stranded
threshold. Note on width: a resting limit is an option WE give the market;
a closer one is worth more to it. The case for tight is getting into
positions at once, not the option.

**8.3 Arms are fleets.** Three IC Markets Raw demo accounts, one box each,
the SAME pairs (today's eleven instances), different settings per fleet.
Fleet 1 always holds the ANCHOR (best settings so far), fleets 2 and 3
the PROBES; roles stay with the fleet. Per side, the three fleets are
three points on that side's (add, exit) plane, on the same ticks.
Replaces three arms per pair on one account: s5's slot arithmetic goes
(eleven instances per account, as today; no cap-6 compromise), and each
arm has its own breaker and daily limit (a reckless probe trips only its
own fleet). Every fleet carries the whole book (portfolio effect).

**8.4 The compass** (replaces s2's Nelder-Mead reflect; straight lines,
modest steps). Per pair and side, after each round:
- the best of the three becomes the anchor if it beats the anchor by more
  than $1/day; otherwise the anchor stays;
- two new probes, one pip from the anchor, one per lever, on the side the
  evidence points to (a losing probe flips across the anchor);
- explore OUTWARD while the anchor keeps losing on one side; once it beats
  both sides of a lever, the peak is bracketed: refine INWARD (half pips).
Example (long): anchor 5/5, probes 5/7 and 7/5, ranking 1 > 2 > 3: both
wider steps lost, so next 5/5, 5/4, 4/5 (under a straight line, 6 cannot
beat 5; beyond the anchor is the only place a line says "better").

**8.5 Rounds.** Two full FTMO days; margin $1/day per pair per side (about
one or two scalps a day). Replaces R1's ~190-scalp gate: the operator
judges scalp volume high enough, the margin guards against noise. The
inherited book is "part of the territory": no flat restarts (R5 is
withdrawn, as the 24 Sep note said).

**8.6 Changing settings on a live book: rebuild on start.** At every start
(and nightly, as the carry pass does now) each exit is recomputed:
`ExitPrice(effective entry, that side's CURRENT exit) + eject offset`,
shifted by carry from the broker's own swap ledger (at start: ledger
only; the nightly pass keeps adding tonight's pending swap). Resting adds
move to the new distance at start, IGNORING the deadband (operator:
absolutely; the deadband is for noise, not settings). Only two labels are
stored: the lattice VL and the eject offset; all else is derived. The
operator's delta alternative (add new - old to the resting exit) gives
the same price in the clean case but needs the old value stored and
carries forward clamped, skipped or queued exits' errors; the rebuild
does neither and reuses the carry pass's formula.
**BLOCKER TODAY -- I6.** Reconstruction checks every resting exit
against the CURRENT `InpExitPips` within 2 points and halts on a mismatch
(`Grind_ReconExitMatchesEntry`, `grind_recon.mqh` 366-388). A reattach
with a new exit HALTS the instance today. The new EA must rebuild before
enforcing I6, or check against each layer's own recorded exit (C46). An
ADD change is safe today (geometry-cycle3 A6).

**8.7 pipshed recommends; the operator deploys.** Per pair, side, fleet and
FTMO day: closed P&L (and its parts); the compass's next settings; the
next `.set` files. Deploy by reattach during the session.

**8.8 Live.** One real FTMO fleet runs ANCHORS only. Promotion: an anchor
held for several rounds (N OPEN) whose worst intraday closed P&L in the
lab fits FTMO's daily limit (a lab scalper that ejects every ten minutes
may earn and still breach $500 on a bad afternoon). The live fleet keeps
being compared with its lab anchor (broker drift).

**8.9 Unchanged from rev 2:** s3 (paired comparisons; the simulator
reconciled to these arms is still the end goal), R3 (compare within a
side, across arms; one side on one day mostly measures the trend), R4
(carry needs weeks), R6 (never stop exploring), R7 (never intraday).

**8.10 Parked or withdrawn.** Fleet Reduced Hours (ADR-161) with the
window-aware lattice (both ejection paths act only at cap; outside the
window a side below cap never gets there). The 26 Sep ~02:30Z plan (IC
Control / Reduced Hours / Improve Adds) was withdrawn before push.

**8.11 OPEN.** Width rule; first probe directions per pair and side; the
two duplicates' role; N for promotion; the half-pip floor; the smallest
exit worth its commission; box size; the new EA's name.

Line count: 245
