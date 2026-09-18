This message has a line count at the bottom

# ROLL-AT-CAP -- RESEARCH NOTES

Status: NOT RATIFIED. No ADR. No live setting depends on this.
Evidence route DECIDED (s6b): live OPT/ALT A/B, after ADR-152 Phase 2 settles.
BUILD also deferred behind Phase 2 (s6e). Nothing here starts before then.
Created 2026-09-18 from handoffs 17d s1, 17e s2/s6/s6a, the roll-mode sweeps
of 17-Sep, and Gemini's evidence ruling of 18-Sep.

This file exists because the ruling below must not decay into a handoff.

---

## 1. THE MECHANISM

At cap a ladder cannot add. Once price passes the deepest layer by one add
step the side is stranded: it cannot scalp until price returns. Stranding is
the NORMAL state of much of the fleet, not an edge case -- GBPUSD OPT has
held L07-L13 since 2026-09-16 21:00Z with L07 74 pips underwater, EURGBP ALT
has held 7 short layers since 15-Sep, AUDCAD is 8/8 short on both arms.

The idea is to free one slot by giving up the oldest, most underwater layer,
keeping a foothold at current price.

**Passive variant (operator, 17e s6, preferred).** Re-target the old layer's
exit to the passive side of the market -- for a long, a sell limit a tick
above bid -- and let it be lifted. Same slot freed, spread not crossed, so
ARCHITECT s1 and ADR-125 hold. A forced market close does cross the spread
and would need an ADR superseding both.

**The trader's framing.** Do not be stubborn about one layer; lean into what
the system is actually good at, which is scalping. The layer being given up
is the one LEAST likely to recover, which is what makes it the right one.
Section 3 makes that quantitative.

---

## 2. WHAT IS KNOWN FROM LIVE (17e s2, six manual rolls, 2026-09-17)

Market-close style, not passive. GBPUSD OPT and ALT.

| | |
|---|---|
| Rolls | 6 (ALT x4, OPT x2), 14:29Z to 16:27Z |
| Realised | about -$59.50 total, roughly -$10 per closed layer |
| Foothold exits by close | 2 confirmed, worth $1.73; a third put the total near $2.43 |
| Cost per roll | about $0.15 spread + commission |

**The -$10 per layer is NOT the cost of the roll.** It was already in MTM and
in the day's loss figure. The roll only converts unrealised to realised. The
real cost is $0.15 plus forgoing recovery of that one layer (s3).

Per roll: about $0.40 of foothold exits against $0.15 of spread and
commission. Marginally positive over that afternoon, IF price was never
coming back. That "if" is the whole question.

---

## 3. FIRST-PRINCIPLES BREAK-EVEN

A toy model. It cannot say whether rolling pays. What it does is show which
quantities the answer turns on, and it needs no simulator.

At 0.01 lots on a USD-quote pair, 1 pip = $0.10.

Let, per roll:
- `N`  = scalps the freed slot generates before the ladder re-caps
- `q`  = probability the foothold actually gets a guard slot (s5, D3)
- `p`  = probability price retraces far enough to have recovered the
         closed layer
- `R`  = pips from market back to the closed layer's exit target
- `E`  = exit_pips

Rolling pays when:

    q * N * E * 0.10   >   0.15   +   p * R * 0.10
    -----------------      ------------------------
    expected scalp         spread/commission, plus
    yield from the         the forgone recovery
    freed slot             option on the closed layer

**Worked, GBPUSD OPT as it stands today.** E = 7. The oldest long layer L07
entered 1.34450 with exit target 1.34520; market about 1.3367, so R is about
85 pips and the forgone recovery is about $8.50. Take q = 1 for the moment.

    N * 0.70  >  0.15 + p * 8.50

| p (chance price returns) | N needed to break even |
|---:|---:|
| 0.50 | 6.3 scalps |
| 0.20 | 2.6 scalps |
| 0.05 | 0.8 scalps |
| 0.00 | 0.2 scalps |

**This is the whole argument in one table.** The answer is dominated by `p`,
not by scalp yield. And `p` is precisely what makes the OLDEST layer the
right one to eject: it is the furthest away, so it has the lowest chance of
recovering, even though its nominal `R` is the largest. Rolling a recent
layer would be strictly worse -- smaller `R` but much higher `p`.

It also shows why stubbornness is expensive in a specific way. Holding L07
is buying a lottery ticket on an 85-pip retrace. Ejecting it converts that
ticket into a working slot. Whether that is a good trade is an empirical
question about `p` for this pair in this regime, and nothing in the sweeps
addresses it.

**`q` is a multiplier on the entire benefit side**, which is why a
simulator that omits the guard cannot answer this at any magnitude (s5).

**Known unknowns in the model.** `N` is not a constant -- a freed slot that
fills and exits can be refilled, so `N` depends on how long price stays in
the neighbourhood. `p` is regime-dependent and has no estimate yet. The
stall side is treated as earning zero while stranded, which is nearly true
at cap with price beyond the deepest layer, but not exactly.

---

## 4. THE SWEEPS (17-Sep) -- UNUSABLE ON MAGNITUDE

`roll_modes_cal_2026_09_17` (192 cells, 2 windows x 8 pairs x 2 geometries
x 3 modes x 2 P) and `roll_modes_tail_chf_2026_09_17` (36 cells, 3 pairs).
Results are on the Surface, not in the repo.

Calibration showed rolling ahead of stall 3-4x. That number is an artefact.
`stranded_hours` reads 823-1142 per quarter for stall against roughly zero
for roll modes; a quarter is about 2160 hours, so the simulator has stall
dead 40-50% of the time. It is single-sided, so a capped ladder idles the
whole instance. Live it does not: GBPUSD OPT is capped long and still
working three short layers.

Three metric defects, all conceded:

**D1. `exits_per_forced_close` is misdefined, not merely noisy.** The
numerator counts ALL exits in the cell, so a mode that survives longer
scores higher on a ratio claiming to measure what the close bought. The
correct quantity is exits on the FREED SLOT after the close -- that is `N`
in s3. The tail P=8 cells also give 265 exits per close off 320 closes
across 16 cells, about 20 per cell per quarter, so the denominator is thin.

**D2. P=4 vs P=8 is circular in stall.** Cap depth controls how often a
ladder caps, which in stall controls idle time. The earlier claim that this
was the cleanest comparison in the run is RETRACTED.

**D3. No 200-limit and no commitment guard (17d s2).** In the sim a foothold
bid is free. Live it competes with 31 other sides under a guard that read
195 on 18-Sep; on 17-Sep footholds were repeatedly beaten to freed room by
other instances' far adds, and the operator had to detach instances and
delete their entry orders to get a bid down. This is `q` in s3.

---

## 5. THE ONE RESULT WORTH KEEPING

In the tail window, `roll_on_add` shows 368 and 260 stranded hours while
`roll_on_fill` shows zero.

Rolling only when an add level is passed leaves a ladder stranded in a
violent trend, because the level stops being reached. Keeping a bid resting
does not. This is a comparison between two roll modes rather than against
stall, so the single-sided bias does not obviously inflate it.

It supports the passive design specifically: the ejection frees the slot and
the bid follows the ladder automatically, so the mechanism self-times. If
the ejection fills, price ticked up, which is exactly when a fresh bid below
makes sense. If it does not fill, price is in free fall and we keep the deep
layer and do NOT add into the move.

---

## 6. GEMINI RULINGS, 2026-09-18 -- BINDING

Two rulings the same day. The first required a fleet simulator; the second
RESCINDED that in favour of a live A/B. Read them in order.

### 6a. First ruling -- simulator standard (superseded in part)

A guard-free simulator is structurally incapable of supporting a ruling on
rolling. D3 is fatal: the premise of rolling is paying spread and commission
to buy a foothold slot, and if the shared guard is saturated you pay the
ejection cost while the foothold is starved by other instances' far adds. A
simulation granting free slot availability hallucinates scalping yield the
broker will categorically refuse.

MT5 Strategy Tester REJECTED and still rejected: single-instance and
single-symbol, so the guard cannot appear at all.

### 6b. Second ruling -- live OPT/ALT A/B replaces the simulator

> The multi-symbol fleet simulator requirement is rescinded. Evidence for
> roll-at-cap will be derived from a live OPT/ALT A/B test on the FTMO demo
> account, with `exit_pips` matched across arms to isolate the mechanic.

Reasoning: the demo account enforces the broker constraint natively, so model
risk is eliminated. `q` and `p` are measured in actual market microstructure
rather than estimated. Financial risk is zero on a demo account; the
informational yield is absolute.

### 6c. Sequencing -- UNCHANGED, and the reason is not the obvious one

> The A/B test will commence only after ADR-152 Phase 2 has settled, to
> ensure rolling is evaluated against a healthy guard state.

The argument for a pre-Phase-2 baseline was rejected, correctly. Testing
roll-at-cap in a starving guard would ARTIFICIALLY INFLATE rolling, because
under saturation ordinary adds are suffocated too, so a freed slot looks
unusually valuable for a reason that disappears once Phase 2 lands. Measure
the mechanic against the target architecture, not the one being abandoned.

### 6d. Contamination -- asymmetric, and the asymmetry is binding

> Due to shared-guard slot cannibalization, a loss by the rolling arm in the
> A/B test is decisive and terminal. A win by the rolling arm is directional
> only, and will require a second validation phase (e.g. a fleet-wide toggle
> on/off over matched periods) before full architectural adoption.

The rolling arm cannibalises slots from the stall arm, so the test is biased
FOR rolling. A loss under a favourable bias kills the idea permanently. A win
is magnitude-compromised, and ARCHITECT s1 is not rewritten on a contaminated
win.

### 6e. Build is deferred too, not only measurement

Asked whether the deferral governed BUILD as well as MEASUREMENT, i.e.
whether the mechanism could be implemented behind an OFF-by-default input
before Phase 2. Ruled NO, on both counts.

> Both the implementation and the A/B measurement of the passive-roll
> mechanism are deferred until after ADR-152 Phase 2 is fully deployed and
> stable. This sequential execution prevents code collision in the engine's
> core slot accounting and reconstruction modules.

The reasoning is code collision, not measurement validity. Passive-roll
touches the exit queue, reconstruction and slot accounting (K + H + 1).
Phase 2 is actively tearing open those same modules to build order
withholding. Branching a complex `EJECTED` state concurrently invites merge
conflict, architectural drift and subtle regressions in guard arithmetic.
Finish Phase 2, stabilise, then build passive-roll against the finalised
architecture.

**Consequence: Phase 2 is the critical path for roll-at-cap, not a detour
around it.**

### 6f. Standing condition on any result (Claude, not ruled)

The demo account enforces the BROKER's 200 limit natively. What actually
binds day to day is ADR-151's commitment guard at 194, which is OURS, and
Phase 2 changes it again. So the A/B measures `q` under whichever guard is
running at the time, not under a fixed constraint. Any finding therefore
carries an expiry: a `q` measured after Phase 2 stops being valid if the
band, the reserve `Q`, or the entry horizon is later changed. Record the
guard configuration alongside the result, and re-open the question if that
configuration moves.

---

## 7. WHAT HAPPENS NEXT, AND WHY

**Live stranding instrumentation runs BEFORE Phase 2.** Per side: time at cap
with price beyond the deepest layer by more than one add step, plus a count
of stranded episodes.

Gemini called for this to calibrate the fleet simulator. By his own Q2
reasoning that justification is weak -- stranding measured now describes
pre-Phase 2 dynamics and would be obsolete as calibration input for a model
built after Phase 2. The instruction survives with a better reason: it is a
BEFORE-AND-AFTER measurement of Phase 2's own effect on stranding, which
nothing else provides and for which ADR-152 specifies no metric. That only
works if the baseline is captured before Phase 2 lands.

It needs an EA change and therefore a compile, which reinitialises all 16
instances. Bundle it with the two telemetry fixes already queued -- the
ADR-152 inputs missing from `Grind_ConfigDumpString`, and the `guard_total`
peak latch -- so all three cost one compile. Do it after the Phase 1 pilot
gate is read, not during the 48-hour window.

**Then, in order, with NOTHING starting before Phase 2 is stable (s6e):**
Phase 2 deploy and settle; passive-roll ADR written and built; the
live OPT/ALT A/B with `exit_pips` matched across arms. The fleet simulator is
no longer required (s6b). The simulator's exit-attribution defect (D1) still
matters if the Python sim is ever used again for anything, but it is off the
critical path.

**Undecided, for the ADR, not settled by any ruling.** WHICH ARM ROLLS. It is
not neutral: ALT is the wider-exit arm on every pair (s4 table), and matching
`exit_pips` means moving one arm onto the other's value. Match at the OPT
value and both arms scalp faster than either does now; match at the ALT value
and both slow down. Either choice changes the fleet's aggregate behaviour for
the duration of the test, and the geometry A/B stops while it runs.

**Open questions for that ADR, from 17e s6a.** An explicit `EJECTED` state
that ranking and trimming skip, or the next fill cancels the ejected exit.
Slot accounting becomes K + H + 1 per side. Reconstruction must accept a
non-formula exit or I6 fails. An un-eject rule, and at most one ejection per
side at a time. `MEMO_2026-09-16_order_purgatory.md` and ADR-151 both state
that only the nearest ranks hold live exits and will need correcting.

**Standing caution.** Boring is best. Things that seem obviously helpful have
had adverse effects on this system before. The mechanism here is appealing
and may still be wrong; s3 says the answer turns on `p` and `q`, and neither
has an estimate.

Line count: 303
