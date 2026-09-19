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

## 3a. FIRST EMPIRICAL OBSERVATION OF `q` -- 2026-09-18

The break-even in s3 treats `q` as a probability: does a foothold get a guard
slot or not. The first real measurement says that is the wrong shape.

GBPUSD ALT, 2026-09-18, from the VPS terminal log (times UTC):

| | |
|---|---|
| 10:38:55.714 | L14 entry fills. Its exit rests 1 ms later at 1.33714 |
| 10:38:55.x | add to L15 is due. Cap allows it (6 of 8). Guard refuses it |
| 11:51:59.702 | buy limit 1.33436 finally reaches the market |
| 11:52:40.986 | it fills |

**73 minutes** from due to placed. Then 41 seconds from placed to filled.

Guard total was pinned at 195 for the whole of that day -- 195 at 05:01Z,
195 at 05:11Z, 195 at 13:07Z -- while the book underneath moved (180 then
178) and resting entries moved (15 then 17). A binding constraint being sat
against, saturated for eight hours.

**Consequences for the model in s3.**

`q` is not a probability, it is a WAITING-TIME DISTRIBUTION. The slot
arrived; it arrived 73 minutes late. A foothold's value decays while it
waits, because the price level it was aimed at moves away. This one nearly
expired: price reached 1.33436 forty-one seconds after the order landed, so
a few more minutes of blocking and that layer would not exist. It is now the
only long layer on either GBPUSD arm that is not underwater.

So the benefit side of the break-even needs a decay term, not just a
multiplier. Ejecting a layer to free a slot is worth much less if the
foothold then queues for an hour behind other instances' entries.

**How to measure it properly**: fill-to-placement gap per add, from the
terminal log's Trades lines -- the interval between a layer's fill and the
next layer's entry order reaching the market. That is a direct read of `q`
and costs nothing but a grep. `near_reserve_blocks` does NOT measure this
(see D1 and s4): it increments per tick while a far add is pending, so it
reports blocked TIME in ticks, not refused entries. GBPUSD ALT read 22,309
and OPT 7,930 over eight hours, which is roughly one per second.

**This single observation is worth more than the 192-cell sweep**, because it
measures the quantity the sweep structurally cannot model.

---

## 3b. THE GBPUSD CASE -- FIRST REAL `p` AND `R`, AND A TENSION THE MODEL MISSED

On 2026-09-17 the operator force-closed 15 GBPUSD longs by hand (market
close, not passive). Reconciled from the deal dump in
`prompts/cycle_pnl_reconciliation.md`. This is the closest thing to a live
ejection we have, and it gives s3 its first real numbers.

**The ladder.** 8 ALT layers 1.35112 down to 1.34301; 7 OPT layers 1.35169
down to 1.34571. Roughly 87 pips of ladder on each arm, built 14-Sep to
16-Sep as price fell. Realised on the closes: **-176.35**.

**What happened next.** GBPUSD traded 1.334-1.339 for two days. The high was
1.33914. The nearest exit target of the whole ladder -- ALT L08 at 1.34401 --
was **49 pips short**. Not one of the 15 would have exited.

| | MTM on the 15 |
|---|---:|
| at the 2-day low 1.33436 | -203.06 |
| at 1.33955 (end of window) | -125.21 |
| **actually realised** | **-176.35** |

So against holding to the end of the window the closes cost about $51;
against the low they saved about $27. **On P&L alone it is a wash.** What
they bought was a ladder sitting INSIDE the trading range instead of 90 pips
above it -- the rebuilt ladder from 1.33436 up took 22 scalps for $18.69 on
18-Sep, the best per-scalp figure in the fleet.

### The operator's objection, and it is the strongest one against ejection

**Recovery is all-or-nothing in the ladder's favour.** Price can only reach
the WORST layer's exit target by passing through every shallower layer's exit
on the way. So if the ladder recovers at all, it recovers completely.

Which means ejecting the worst layer and then getting a recovery is the
maximum-regret case. Measured, for ALT L00 ejected at the low:

| | outcome on full recovery |
|---|---:|
| hold all 15, price reaches 1.35212 | **+12.90** |
| eject ALT L00 at 1.33436, hold the rest | -16.76 + 11.90 = **-4.86** |
| **cost of the ejection** | **17.76** |

**One ejection costs more than the entire ladder earns on a full recovery.**
That is a far worse ratio than s3's toy model suggested, because s3 never had
a real `R`.

### The tension s3 does not state

`R` is the distance from market back to the ejected layer's exit target, and
it **grows as the ladder deepens** -- which is exactly the situation where a
freed slot is wanted. So ejection gets more expensive precisely when it
becomes more attractive.

Re-running the s3 break-even with the real `R = 177.6` pips and ALT's
`E = 10`:

| p (chance of recovery) | N (scalps the freed slot must generate) |
|---:|---:|
| 0.50 | 9.0 |
| 0.20 | 3.7 |
| 0.05 | 1.0 |

Compare s3's table, which used `R = 85` and needed 6.3 / 2.6 / 0.8. Doubling
the ladder depth roughly doubles the hurdle.

**Counterweight, and it is not small.** In the case that actually occurred --
no recovery -- holding all 15 earns exactly zero, both arms stay capped, and
the ladder sits above the entire trading range indefinitely. The GBPUSD arms
were at or near 8 of 8 before the closes.

### Where this leaves the decision

Not "ejection is wrong". **Ejection is expensive insurance, and it cannot be
priced without an estimate of `p`.** The operator's instinct after seeing
these numbers was that locking in a loss is not something he wants to do,
and the $17.76-against-$12.90 ratio supports that unless `p` is low.

`p` remains unmeasured. It is now the single number the whole question turns
on, and it is estimable from history: for a ladder of depth D at cap, how
often does price return to the worst layer's exit target within some horizon?
That is a study on existing data, not a simulator and not a live A/B.

**Do that before the ADR.**

---

## 3c. PATH VS DISPLACEMENT -- AND AN ARGUMENT FOR FLATTENING (operator, 2026-09-18)

This section is a line of thinking, not a decision. It is recorded because it
reframes roll-at-cap as a special case of something larger, and because it
arrived from first principles rather than from the data.

### The premise the current design rests on, stated plainly

The ladder assumes: the market lives in a range, gaps to another range, lives
there, gaps again -- and one day returns to the original range, where our
inventory is waiting.

**The operator's objection: at cap we get no range-trading value from the new
range at all.** Every layer sits back in the old one. We cannot trade the
range we are actually in. We can only hope for a return to the range we are
no longer in.

### Path, not displacement

> "The distance travelled from 1 to 10 direct is orders of magnitude shorter
> than 1 to 3, back to 2, then to 5, then to 2, then to 7, then 1, 9, then 8
> then 10."

A market maker earns from PATH LENGTH -- the sum of the oscillation. Net
DISPLACEMENT is what the ladder's MTM tracks, and it is the component the
strategy has no edge in.

Stranded at cap, a side stops harvesting path entirely and is left holding
pure displacement risk. **The strategy converts from path-harvesting to a
directional bet on mean reversion, involuntarily, at the moment its capacity
is exhausted.**

GBPUSD, 16-18 Sep, is exactly that. Displacement 1.352 -> 1.334, about 180
pips. Path inside 1.334-1.339 over the following two days was many multiples
of that, and the REBUILT ladder harvested 22 scalps for $18.69 from it. The
old ladder -- holding all the displacement, participating in none of the path
-- earned zero.

**Important qualifier: it is half a book, not a whole one.** The opposite
side keeps working. GBPUSD OPT was capped long and still scalping three short
layers. That is why the fleet kept earning through the week, and it is why
this is a drag rather than a stop.

### Which means `p` may be the wrong headline number

`p` (s3, s3b) prices what ejection GIVES UP. It does not price what holding
COSTS. The cost of not ejecting is not the forgone retrace -- it is every
scalp the new range offers that a capped side cannot take, and unlike the
retrace, that accrues continuously.

**Suggested measurement, same data as the `p` study:** path-to-displacement
ratio per pair per day -- sum of absolute bar-to-bar moves divided by net
change over the window. That is a direct estimate of how much scalping a
range offers, hence what a capped side forgoes per day.

### The larger idea: periodic flattening

If inventory is the risk we are not paid for, and capacity at current price
is what lets us harvest path, then the standard market-maker answer applies:
**flatten periodically.** A flat book at current price is maximum capacity
exactly where the path is.

**Not black and white.** The operator's framing is that some risk can be held
overnight. The tractable version is a rule about how much DISPLACEMENT to
carry -- keep layers within N pips of market, retire the rest. Near layers
have real recovery probability and sit in the current path; far layers are
pure displacement.

**Three things to establish before believing any of it:**

1. **What flattening costs.** Every retired layer realises its loss. The week
   of 10-18 Sep ran 81 manual closes for **-284.86**
   (`prompts/cycle_pnl_reconciliation.md`). That is the fee for the reset and
   it is not small -- it consumed 68% of the scalp engine's +419.10.
2. **What the reset buys.** Path harvested per day by a ladder anchored AT
   market versus one anchored 90 pips away. The measurement above, applied
   per ladder rather than per pair.
3. **The trigger.** A time interval is arbitrary. A DISPLACEMENT threshold --
   retire what is more than N pips from market -- is the same idea with a
   trigger that tracks the actual condition, and it is closer to what
   ejection was reaching for.

### Scope note

Ejection retires ONE layer to free ONE slot. Flattening retires inventory to
reposition the WHOLE ladder. Same principle, different scope.

**If this holds up, the passive-roll ADR is a special case rather than the
main event**, and the sequencing in s7 may be wrong. Do not act on that
until items 1-3 are measured. Nothing here is ratified and nothing here has
been put to Gemini.

---

## 3d. PATH VS DISPLACEMENT, MEASURED -- 2026-09-18

s3c argued the point; this measures it. Script
`scripts/measure_path_vs_displacement.py`, full report
`prompts/path_vs_displacement.md`. M5 bars, 2015-2026, ~3,035 trading days
per symbol.

**A typical day offers roughly 19 times more PATH than DISPLACEMENT.**

GBPUSD, n=3035 days, pips:

| stat | path | displacement | ratio | range |
|------|-----:|-------------:|------:|------:|
| q25 | 622 | 18.9 | 10.4 | 72 |
| **median** | **743** | **41.8** | **17.8** | **95** |
| q75 | 919 | 74.3 | 37.0 | 128 |

Median daily path across the fleet runs 408 (EURGBP) to 743 (GBPUSD) pips.
Pooled median ratio about 19:1.

**That ratio is the business.** Path is what a market maker harvests;
displacement is what a ladder's MTM tracks and the component the strategy has
no edge in. A side stranded at cap stops harvesting the 19 and keeps the 1.

### The capacity gap

Crude upper bound, `median_daily_path / (2 * E)` round trips per day per side:

| symbol | E OPT/ALT | median path | OPT rt/day | ALT rt/day |
|--------|-----------|------------:|-----------:|-----------:|
| GBPUSD | 7 / 10 | 743 | 53.0 | 37.1 |
| EURUSD | 7 / 10 | 559 | 39.9 | 27.9 |
| EURGBP | 5 / 8 | 408 | 40.8 | 25.5 |
| AUDCAD | 5 / 10 | 527 | 52.7 | 26.3 |
| AUDCHF | 5 / 10 | 454 | 45.4 | 22.7 |
| CADCHF | 5 / 10 | 414 | 41.4 | 20.7 |
| NZDCAD | 5 / 7 | 529 | 52.9 | 37.8 |
| AUDNZD | 5 / 7 | 486 | 48.6 | 34.7 |

**The fleet did 102 scalps on 2026-09-18, its best day of the cycle.** The
per-symbol-per-side ceiling above is 27-53. Across 8 symbols, 2 arms and 2
sides the theoretical fleet ceiling is in the high hundreds.

The bound is crude and ignores guard, cap, spread and the fact that only one
side faces each move -- but the gap is large enough that it is worth knowing
which part of it is structural and which is removable. Most of it is
structural: capturing a round trip needs inventory at that level, and a
ladder only holds levels price has already visited. Guard saturation,
layer caps and stranded sides are the removable part.

### Two limits on this, both stated by the analysis itself

**It is unconditional**, pooled over 2015-2026. A ladder at cap is a
conditioned case -- a sustained move is already underway -- and that
population likely shows path LOWER relative to displacement than the pooled
median. So 19:1 is the optimistic end.

**The week that matters is not in the data.** The M5 files on the desktop end
between 2026-09-07 (AUDCAD) and 2026-09-11 (GBPUSD, EURUSD, EURGBP). The
operator week 14-18 Sep, and specifically GBPUSD on 17-18 Sep -- how much
path fell inside 1.334-1.339 where the rebuilt ladder traded, versus above
1.34301 where the old one sat -- **could not be measured.** That was the
single most valuable cut. It needs fresher M5 exports from the Surface and
should be the first thing run when they exist.

### Cancelled

The `p` / retrace-probability study was abandoned. It was specified as a
first-passage probability per bar per threshold, which is quadratic and drove
Cursor to install numba; and more importantly unconditional `p` is a long-run
average applied to a tail case, so it would have read too high. Spec error,
recorded in case anyone is tempted to revive it.

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

**Design idea for the ADR (operator, 2026-09-18).** Keep the MOST UNDERWATER
layer's exit resting, alongside the nearest ranks that ADR-151 already rests.
ADR-151 is a prefix (ranks 0-2); this makes it a barbell. The reason is the
K + H + 1 in s6a item 2: that +1 is the new exit order created for the ejected
layer. If the deepest exit is already resting, ejection becomes an
`OrderModify` of an existing order rather than an `OrderSend` of a new one, so
the +1 disappears and the guard cost is pre-paid. Pay-on-use looks cheaper --
one unit per ejection rather than one held permanently on each deep side --
but an ejection that cannot obtain a guard unit does not happen, and on
2026-09-18 a near-market entry waited 73 minutes for one (s3a). Pre-paying
guarantees the mechanism can fire.

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

Line count: 617
