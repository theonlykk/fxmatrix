# Findings: Kinetic-Anchored Recomputation on Exit-Reset Events

## Status: UNDER REVIEW -- evidence being collected, no fix drafted yet

## Summary of Findings (added for navigation -- see full sections below)

This document traces a single, real, extended EURUSD/GBPUSD/EURGBP
backtest session investigating the exit-reset/kinetic-distance
interaction in FXMatrix's grid spacing logic. Eight findings plus one
resolved discussion, in logical (not chronological-discovery) order:

1. Midpoint proposal for exit-reset add recomputation (uses each
   layer's own stored add_next fields, no new tracking needed)
2. ADR-079 dynamic reanchor compounds with exit-reset delay; market
   drift dominates over kinetic width in all 11 observed co-occurrences
3. No decay mechanism exists for a stale, resting, unfilled add_next
   order during periods of no trade activity
4. Kinetic distance has no depth-awareness; quantified win-rate and
   crossover analysis against base_add across all logged layers
5. Confirmed evidence that add_next orders ARE modified post-placement,
   contradicting an earlier session anchor -- root cause unresolved
6. Kinetic gate correctly blocking an add can leave a deep layer
   temporarily unhedged with zero resting protection
7. Kinetic distance (shrinking) and reanchor drift (growing) move in
   opposite directions on repeated revisits to the same anchor --
   traced to a shared root cause (elapsed time since anchor creation)
8. Resolution: a market-making discipline argument (Khalid) resolves
   part of Finding 2/7's framing -- consistent behavior regardless of
   favorable/unfavorable market timing is correct discipline, not a
   flaw; the remaining kinetic-vs-drift asymmetry stays open
9. Proposal: replace the fixed 3-pip exit floor with a kinetic-distance-
   derived formula, tying exit sizing to the same real-time signal
   already used for add-side spacing -- explicitly dependent on
   ADR-080's unified spacing toggle being active

None of these findings have an approved fix yet. This document is
intended for Staff Architect (Gemini) review to establish sequencing
and rulings before any Cursor implementation work begins.

## Problem Statement

When a LIFO partial exit fires with DebugEnableExitResetDelay=true
(ADR-078), the deferred add-next recomputation (via ComputeNextLayerPrice)
anchors PURELY to the surviving layer's own entry_price and the current
kinetic_dist (volatility-derived distance). It has zero memory of:
- The previously-cancelled add level that was resting before the reset
  (itself a confirmed-untested boundary)
- The closing layer's own entry price (a CONFIRMED, already-traded price
  point -- direct market evidence of where the trading range extends to)

This conflates two different situations that should be handled
differently: kinetic_dist is designed to widen spacing when the market
is trending in one sustained direction (successive unexited adds). An
EXIT_RESET_ARMED event, by construction, can only occur when the
market has ALREADY traded back -- meaning the situation is a
back-and-forth trading range, not a one-directional trend. Applying
trend-widening logic at a range-bound decision point is a conceptual
mismatch, independent of how often or how severely it manifests.

## Evidence Collected This Session

### Confirmed via log data (real WINNER= diagnostic lines, real fills)

- 28 total EXIT_RESET_ARMED events found in the June 2026 backtest
  (all four spacing toggles active: DebugEnableGridMode,
  DebugEnableExitResetDelay, DebugEnableDynamicReanchor,
  DebugUseUnifiedAddNextSpacing)
- Of matched events (23-25 depending on pairing method), 100% were won
  by KINETIC(kinetic_dist) in the WINNER= diagnostic -- zero exceptions
- Sum of |divergence| between actual kinetic-computed price and a
  simple midpoint (0.5 * surviving_layer.add_next + closing_layer.add_next,
  both already-stored struct fields, no new tracking needed) across 23
  matched events: 176.00 pips, average 7.65 pips
- Direction of divergence is NOT one-sided in frequency (14/23 kinetic
  wider than midpoint, 9/23 narrower) -- but IS one-sided in SEVERITY:
  the four largest divergences (29.65, 23.65, 17.25, 16.85 pips) were
  ALL cases where kinetic was wider than midpoint, concentrated in the
  June 17 21:00-21:36 high-volatility window
- CONFIRMED WORST-CASE FAILURE MODE: 2 instances (both EURUSD SELL,
  2026.06.17 16:30:09 and 16:54:35, ~24 minutes apart, same underlying
  volatile stretch) where the newly-computed add price was WORSE than
  the last confirmed fill on the layer that just closed -- i.e. the
  system became willing to re-sell at a price BELOW where it had just
  proven selling was favorable. 5 and 16 pips worse respectively.
- (5 of 28 total EXIT_RESET_ARMED events remain unmatched by current
  pairing scripts -- likely additional instances of the same pattern,
  not yet confirmed)

## Finding 1: Midpoint Proposal for Exit-Reset Add Recomputation

### Proposed fix direction (not yet implemented, not yet reviewed by
Staff Architect)

Replace the kinetic-driven recomputation, specifically at this decision
point only, with: new_add = 0.5 * (surviving_layer.add_next +
closing_layer.add_next) -- using each layer's own already-stored
add_next struct field (set at creation/last placement, never
overwritten until this recompute), requiring no new tracking or
lookups. This directly uses confirmed market information (levels
already traded through or already resting) rather than a volatility
proxy that doesn't apply to this specific situation.

Open questions, not yet resolved:
- Should this replace kinetic entirely at this decision point, or
  should kinetic still act as a floor/ceiling in some combination?
- Confirm whether add_next is genuinely never overwritten between a
  layer's creation and this recompute (needs a fresh anchor check
  before implementation, separate from this document)
- Investigate the 5 unmatched EXIT_RESET_ARMED events for additional
  worst-case instances

## Finding 2: ADR-079 Dynamic Reanchor Compounds with Exit-Reset,
and Drift Dominates Over Kinetic Width

### Discovery

Of the 28 total EXIT_RESET_ARMED events, 11 (39%) ALSO triggered
ADR-079's dynamic reanchor at the moment of placement -- confirmed via
direct log evidence ("INFO [ADR-079] Dynamic re-anchor..." lines
co-occurring with "Exit-reset add_next placed after delay" at the
same timestamp).

### Mechanism (confirmed via log trace, e.g. 2026.06.16 22:56:30,
EURUSD)

ADR-079's reanchor formula is: actual_placed_price = current_market +/-
distance, where distance = |static_theoretical_price -
surviving_layer.entry_price|. Since static_theoretical_price itself
equals surviving_layer.entry_price +/- kinetic_dist, the kinetic term
cancels algebraically in the reanchor. What remains as the dominant
variable is: actual_placed_price - static_theoretical_price =
current_market - surviving_layer.entry_price -- i.e. simply how far
price has moved since the SURVIVING layer's entry, which may have
been created hours earlier, not "30 seconds ago" (an earlier
mischaracterization corrected during this session's review).

### Quantified across all 11 cases

| Metric | Value |
|---|---|
| Cases where market-drift component EXCEEDED the kinetic-width component | 11 / 11 (100%) |
| Average drift (current_market vs surviving_layer.entry) | 38.1 pips |
| Average kinetic component (unaffected by reanchor) | ~20 pips |
| Largest single drift observed | 97.7 pips (2026.06.19, EURUSD) |

### Interpretation

In every observed case where both mechanisms co-occurred, the
dominant contributor to the FINAL placed distance was not the
volatility-scaled kinetic formula at all -- it was simply how stale
the surviving layer's anchor had become relative to current price.
Both ADR-078 (exit-reset delay) and ADR-079 (dynamic reanchor) are
individually functioning exactly as designed and validated earlier
this session; this finding is about their COMPOUND interaction
producing a placed level that reflects anchor staleness far more than
genuine volatility, with zero connection to confirmed trading range
(the concern underlying the first finding in this document).

## Finding 3: No Decay Mechanism for Stale Resting add_next

### Problem

Once an add_next order is placed and resting (unfilled), NOTHING
re-evaluates or adjusts it based on elapsed time or changing market
conditions. It only changes via five event-driven triggers (entry
fill, OnTick Option B re-arm on an empty slot, broker-drop detection,
LIFO partial exit, or the order's own fill) -- confirmed exhaustively
via anchor. If none of these fire, a level computed during a violent
moment (e.g. wide kinetic-driven spacing during a shock) remains fixed
indefinitely even after the market has fully settled into a calm,
narrow range for hours.

### Concrete scenario (Khalid, verbal walkthrough)

Sell at 1.3000, exit fixed at 1.2997 (standard 3-pip floor). During
genuine volatility, add_next correctly widens to e.g. 1.3107 --
appropriate protection against catching a falling knife in the
moment. But if price then settles into a calm 1.3020-centered range
for 15 hours, neither the exit nor the wide add ever adapts. The
position generates no further activity -- effectively "stuck in the
doldrums" -- despite the system having clear internal evidence
(rolling sigma/volatility measures) that conditions have calmed
significantly since the level was set.

### Relevant existing infrastructure (confirmed via anchor, NOT
currently applicable to this problem)

g_cooldown_LDAK (ADR-046) already implements almost exactly the
decay behavior this scenario calls for: instant snap-up on shock,
gradual multiplicative decay (default 2.5% per M5 bar, floor 1.0)
toward calm, evaluated every bar close independent of trade activity.

However, confirmed via anchor: this mechanism is applied ONLY to
resting Layer-0 (flat-state, EA_MAGIC) quotes via
RunSpreadCooldownReconciliation(). It has been EXPLICITLY excluded
from add_next (EA_MAGIC+1) orders since ADR-060. It is not currently
wired to affect any resting order on an already-open position.

### Distinction from the other two findings in this document

- Midpoint-on-exit finding: applies only when a LIFO exit event fires
- Reanchor-drift finding: applies only when ADR-079 fires (a
  passivity violation at placement time)
- THIS finding: applies during a period of NO trade activity at all --
  a genuinely different trigger condition (absence of an event, not
  presence of one)

### Open questions, not yet resolved

- Should decay directly reuse g_cooldown_LDAK's existing HWM/decay
  logic (extending its scope to add_next), or does add_next warrant
  a separate, dedicated decay mechanism given the different
  consequence of being wrong (a resting order price, not a flat quote)?
- What should decay actually DO to a resting add_next order in MQL5 --
  OrderModify the existing ticket's price directly? Cancel and
  replace (same mechanism already used elsewhere, e.g. LIFO
  resubmit)?
- What should trigger reconsideration -- same M5-bar cadence as
  g_cooldown_LDAK, or something else?
- Should this only narrow a level (decay toward calm) or also be
  capable of widening again if volatility reasserts before decay
  completes?

## Finding 4: Kinetic Distance Has No Depth-Awareness (and a
Directly Relevant Prior Precedent Exists)

### Discovery

Traced a single EURUSD pod (2026.06.16, layer 0 opened 17:35:03,
layer 1 opened 18:50:57) where the DEEPER layer received a TIGHTER
add distance than the SHALLOWER layer:

| Layer | Anchor entry | sigma_pts | kinetic_dist |
|---|---|---|---|
| 0 | 1.15897 | 71.5 | 19.44 pips |
| 1 | 1.16091 | 17.9 | 10.86 pips |

Both values independently verified against the confirmed formula
kinetic_dist = GridBase * (1 + sigma_pts/50) -- predicted 19.44 and
10.86 pips respectively, matching logged output to within 0.01 pips.
sigma_pts genuinely dropped (market genuinely calmed) between the two
moments -- this is NOT a bug in kinetic_dist's own calculation, which
performed exactly as designed.

### The structural gap

base_add (GridMode/hybrid formula) is explicitly, confirmedly
monotonic with depth -- verified this session as 8, 10, 12, 18, 27,
40.5 pips for layers 0-5, always increasing. This encodes a
deliberate design principle: deeper layers carry more risk and should
require more room.

kinetic_dist has NO depth term at all -- it is a pure function of
current market conditions (sigma_pts), with zero memory of layer
index. Since kinetic_dist wins the max(base_add, E_n+10pt,
kinetic_dist) in effectively every observed case this session, the
"deeper must mean wider" principle that base_add was designed to
enforce is NOT actually preserved in practice -- it can be silently
overridden whenever volatility happens to decline between one layer's
creation and the next.

### Directly relevant prior precedent (found via conversation search)

ADR-057's original design (this session confirmed via search of
prior conversations) explicitly established "heavier bag demands
more, not less" as a validated principle -- Component 3,
"Inventory-Weighted Patience": effective_velocity_threshold =
VelocityThreshold / inv_size, meaning deeper inventory requires
progressively stricter (near-zero) velocity before the GATE permits
an add to fire at all.

CRITICAL DISTINCTION: this inventory-weighting applies ONLY to
KineticGateOpen() -- the PERMISSION decision (may an add fire at
all). It has never been applied to ComputeKineticDistance() /
kinetic_dist -- the MAGNITUDE decision (how far away, once
permitted). These are separate functions in the codebase. The
principle "heavier bag demands more" was implemented once, for
permission, and never extended to magnitude -- which is precisely
where this session's finding shows the gap.

### Historical caution (found via conversation search) -- do NOT
naively reactivate layer_stress

ComputeGridInterval() already contains a depth-multiplier term
(layer_stress = LayerStressBase^layer_idx) that could superficially
seem like the fix. CONFIRMED via prior session history: this was
ONCE set to LayerStressBase=1.5, and when combined multiplicatively
with hybrid mode's own GridExpBase=1.5, produced a severe
double-exponential bug -- layer 4+ intervals reached ~136bps,
"essentially unreachable," causing severe backtest regression.
Setting LayerStressBase=1.0 (a complete no-op) was the DELIBERATE FIX
that resolved this and produced the best backtest result of that
entire development series. Any new depth-based floor must be
designed fresh and tested in isolation -- simply restoring
LayerStressBase to a nonzero value would very likely reintroduce this
exact confirmed failure mode.

### Relationship to other findings in this document

NOT a restatement of the decay/cooldown finding. Decay concerns a
SINGLE STATIONARY order adapting over TIME with no new trade activity
(temporal staleness correction on one order). THIS finding concerns
whether REQUIRED distance should ever be permitted to shrink as DEPTH
increases, independent of what any point-in-time volatility reading
says (a structural floor tied to risk accumulation, not time). The
two are compatible, addressing different axes, not competing
proposals.

### Open questions, not yet resolved

- Should depth-awareness be added directly to kinetic_dist's own
  formula, or as a separate floor applied after the max() resolves?
- Given the confirmed historical failure mode, what functional form
  (if any) can add depth-scaling without recreating multiplicative
  double-exponential blowup when combined with GridMode's own
  exponential phase?
- Should this connect to Component 3's existing inv_size-based
  scaling logic (reusing a proven pattern), or warrant an entirely
  separate mechanism?

### Quantified Extension

### Per-layer win-rate, full dataset (not just isolated examples)

| Layer | base_add (confirmed formula) | N observations | Hybrid wins | Kinetic wins | Decay wins | Median A_n when kinetic won |
|---|---|---|---|---|---|---|
| 0 | 8.0 pips | 85 | 0.0% | 100.0% | 0.0% | 13.5 pips |
| 1 | 10.0 pips | 31 | 3.2% | 96.8% | 0.0% | 14.8 pips |
| 2 | 12.0 pips | 10 | 0.0% | 90.0% | 10.0% | 41.4 pips |
| 3 | 18.0 pips | 10 | 0.0% | 100.0% | 0.0% | 34.0 pips |
| 4 | 27.0 pips | 5 | 40.0% | 60.0% | 0.0% | 57.1 pips |

Sample sizes shrink sharply with depth (85 at layer 0 down to 5 at
layer 4) -- percentages at layers 2-4 should be treated as
directionally suggestive, not statistically firm.

CONFIRMS Finding Four quantitatively: base_add's own progression is
correctly monotonic (8/10/12/18/27), but kinetic wins the max() at
90-100% of observations across every layer depth 0-3, and even 60% at
layer 4 (smallest sample). The designed "deeper = structurally wider"
principle is real in the code but rarely load-bearing in practice.

### Crossover analysis: at what layer does base_add alone exceed a
"typical" kinetic distance?

Pooled across all 137 kinetic-win observations in the dataset (not
averaged per-layer, to avoid giving small-sample deep layers equal
weight to layer 0's 85 observations):

- Pooled mean A_n: 21.20 pips
- Pooled median A_n: 14.81 pips (meaningfully lower than the mean --
  distribution is right-skewed by a minority of violent-event
  outliers, confirmed max=79.88 pips)

Computed crossover, holding kinetic constant at each reference point:

| Layer | base_add | Exceeds median (14.81)? | Exceeds mean (21.20)? |
|---|---|---|---|
| 0 | 8.00 | No | No |
| 1 | 10.00 | No | No |
| 2 | 12.00 | No | No |
| 3 | 18.00 | Yes | No |
| 4 | 27.00 | Yes | Yes |

Using the median (the more representative reference point, less
distorted by outliers): base_add does not become the binding
constraint until LAYER 3. Before that, kinetic distance is
essentially always going to be equal to or wider than what pure
depth-based widening alone would demand.

### Important caveat

This is a STATIC comparison against a fixed reference value, not a
live backtest result. In practice kinetic distance is NOT constant --
it is recomputed fresh from CURRENT sigma_pts at every evaluation, so
the real, moment-to-moment crossover point shifts continuously with
live market conditions. This analysis establishes where the two
mechanisms are comparable "on average" across the dataset, not a
guarantee for any specific future trade.

## Finding 5: add_next Orders ARE Being Modified Post-Placement --
Directly Contradicts Prior Anchor

### Discovery

Direct log evidence, confirmed twice in a single 36-hour EURUSD trace
(2026.06.17 21:00 - 2026.06.19 09:00):

- Ticket #364 (add_next, EA_MAGIC+1): placed at 1.14631
  (2026.06.17 22:46:44, confirmed via matching "DIAG TRADE |
  event=add_next... ticket=364" line). Modified to 1.14642 at
  2026.06.18 00:06:01 via "order modified [#364 buy limit 0.01
  EURUSD at 1.14642]".
- Ticket #371 (add_next, EA_MAGIC+1): placed at 1.14294
  (2026.06.18 13:15:01, confirmed via matching add_next event).
  Modified to 1.14305 at 2026.06.19 00:05:00 via "order modified
  [#371 buy limit 0.01 EURUSD at 1.14305]".

Both are ~1.1 pip modifications, both timestamped within one minute
of midnight (00:06:01 and 00:05:00 respectively, roughly 24 hours
apart from each other).

### Direct contradiction of prior confirmed anchor

An anchor investigation earlier this session (into decay/cooldown
mechanisms) explicitly and specifically confirmed: "No OrderModify on
EA_MAGIC+1 / g_add_next tickets anywhere... Once placed, add_next
holds its price until filled, cancelled, or broker-dropped." This
log evidence directly contradicts that finding. Either the prior
anchor was incomplete (missed a code path), or a DIFFERENT mechanism
than anything previously anchored is responsible.

### Ruled out as the cause

ADR-046 Cooldown drag (RunSpreadCooldownReconciliation) was
separately confirmed via the SAME prior anchor to explicitly SKIP any
instrument with open inventory (inst_inv_size > 0). This trace shows
3-4 concurrent open layers throughout both modification events -- so
if cooldown drag were responsible, it would ALSO contradict its own
previously-confirmed inventory-skip behavior. This needs to be
resolved, not assumed either way.

### Hypothesis, NOT confirmed -- flagging for anchor investigation

Both modifications occur within one minute of midnight. Session
context elsewhere shows a confirmed daily rollover mechanism
(SaveGlobalState logs "last_rollover_day_of_year" and
"daily_start_balance", tied to a "daily_start_date" field). Whether
this rollover routine incidentally touches add_next order prices is
UNCONFIRMED and should not be assumed -- but the timing correlation
is specific enough to warrant checking as the first hypothesis.

### Open questions, not yet resolved

- What code path actually performs these OrderModify calls on
  EA_MAGIC+1 tickets? (Requires fresh anchor -- prior anchor missed
  this entirely.)
- Is this tied to daily rollover specifically, or coincidental timing?
- Does this happen consistently at rollover, or only under certain
  conditions (e.g. does it require open inventory, contradicting
  cooldown drag's own skip logic; or does it use separate logic that
  doesn't check inventory state at all)?
- Is the ~1.1 pip modification magnitude meaningful/computed, or
  arbitrary?

## Finding 6: Kinetic Gate Blocking add_next Leaves Deep Layers
Unhedged With No Resting Protection

### Discovery

Direct log trace, EURUSD, 2026.06.17 22:35:09-22:36:19 (70-second
window). At the moment layer 3 (the deepest layer in this pod) filled
at 1.14833, ComputeNextLayerPrice computed a theoretical next-add
price (1.14258) -- but the add was never actually placed. Confirmed
directly: "INFO [ADR-057] Kinetic gate blocked add_next.
instrument=EURUSD" fired immediately after the fill. No DIAG TRADE
add_next event exists for this computation because
PlaceNextEntryLimit() was never called -- KineticGateOpen() denied
permission before that point.

### Mechanism

This is ADR-057 Component 3 (Inventory-Weighted Patience, previously
surfaced in Finding Four via conversation search) working exactly as
designed: effective_velocity_threshold = VelocityThreshold / inv_size.
At inv_size=4 (this trace's deepest observed layer), the threshold is
at its tightest, correctly refusing to add further given elevated
velocity at that moment.

### The gap this exposes

For the full 70 seconds until this layer's own exit fired (a
successful scratch), the position had ZERO resting add order -- no
downside catch mechanism beyond the layer's own fixed exit target.
This is not a bug in the gate itself (its job is specifically to
prevent adding, not to protect an existing layer), but it is a real
structural fact worth surfacing: the gate is most likely to block
precisely when depth and velocity are both high simultaneously --
meaning the position can be at its MOST exposed (deepest, most
capital committed) at exactly the moment it has the THINNEST
additional safety net, by design.

### Relationship to other findings

Distinguish clearly from Finding Four (kinetic DISTANCE lacks
depth-awareness -- a magnitude question) -- this finding is about the
GATE correctly exercising depth-awareness (permission), but that
correct gate behavior has a side effect of temporarily removing all
add-side protection, which is a different, orthogonal consequence
worth tracking separately.

### Open questions, not yet resolved

- Is this an accepted, understood tradeoff of the current design, or
  worth mitigating (e.g. should the EXIT side compensate somehow when
  the gate blocks the add side)?
- How often does this occur across the full dataset -- is 70 seconds
  typical, or was this an unusually quick resolution?

## Finding 7: Kinetic Distance and Reanchor Drift Move in
Opposite Directions on Repeated Revisits to the Same Anchor

### Discovery

Traced three genuine revisits to the SAME anchor layer (EURUSD,
anchor entry 1.15283, created 2026.06.17 21:30:00) across a 36-hour
span:

| Revisit | Timestamp | Kinetic component | Reanchor drift | Total placed distance |
|---|---|---|---|---|
| 1st | 2026.06.17 22:46:44 | 65.2 pips | 0.0 pips (no reanchor fired) | 65.2 pips |
| 2nd | 2026.06.18 13:15:01 | 41.4 pips | 57.5 pips | 98.9 pips |
| 3rd | 2026.06.19 09:00:01 | 29.3 pips | 97.7 pips | 127.0 pips |

Kinetic component: monotonically DECREASING (65.2 -> 41.4 -> 29.3).
Reanchor drift: monotonically INCREASING (0.0 -> 57.5 -> 97.7). Total
placed distance still grows overall since drift dominates.

Note: a separate, superficially similar figure (23.6 pips) observed
in the same trace belongs to a DIFFERENT layer entirely (layer 3's
own fresh entry, 1.14305) -- not a fourth revisit to this anchor.
Care must be taken not to conflate genuine same-anchor revisits with
fresh-layer computations when analyzing this pattern.

### Mechanism -- single root cause, two opposite effects

Both trends share an identical root cause: elapsed time since the
anchor (1.15283) was created. They pull in opposite directions purely
because they are measuring different things:

- Kinetic component shrinks because sigma_pts (a rolling volatility
  window) naturally decays as the initial shock recedes further into
  the past -- a genuine, correctly-functioning measurement.
- Reanchor drift grows because the anchor's entry price itself NEVER
  updates -- confirmed via Findings Two and Five, add_next/entry
  prices are static once set (aside from the still-unexplained
  midnight OrderModify events in Finding Five). The longer the anchor
  survives, the more time live price has had to wander away from it,
  and ADR-079's reanchor mechanism exposes exactly this gap whenever
  it fires.

### Emergent "trading superstition" pattern (Khalid's framing)

This produces, without any deliberate design intent, a pattern
resembling a real trading heuristic: the first return to a level is
treated with modest caution, but each SUBSEQUENT return demands
progressively more distance before re-committing. No code explicitly
implements "be more cautious on the third visit" -- the asymmetry is
entirely emergent: a brand-new layer's anchor is inherently protected
from drift simply because it hasn't existed long enough to accumulate
any, while a surviving, revisited anchor accumulates more potential
drift purely as a function of how long it has remained open.

### Relationship to other findings

This is a SYNTHESIS of Finding Two (ADR-079 reanchor mechanism) and
Finding Four (kinetic distance lacks depth-awareness) -- showing
precisely how they interact over repeated revisits to reproduce a
real, quantifiable, unintended behavioral pattern. Also directly
supports Finding Three's proposed direction (decay of stale resting
levels over elapsed time) as the more principled fix, versus letting
this asymmetry emerge as an uncontrolled side effect of two unrelated
mechanisms.

### Open questions, not yet resolved

- Should the anchor entry price itself be periodically refreshed
  (connects directly to Finding Three's decay proposal), removing the
  root cause of drift growth entirely?
- Is the current NET behavior (distances growing on revisit)
  actually desirable as a risk-reduction heuristic, even if arrived
  at unintentionally -- or does it need correcting regardless of
  whether the net effect happens to resemble sound trading
  discipline?

## Finding 8 (Resolution): Market-Making Discipline Argument
Resolves Part of Findings 2 and 7

### Context

Following discussion of Finding Two (reanchor drift) and Finding
Seven (opposing kinetic/drift trends on revisits), a direct
philosophical objection was raised against the ORIGINAL framing of
these findings: "why does the system demand the full theoretical
distance from current price, rather than simply accepting the
already-favorable price the market delivered relative to the
original theoretical target?"

### Resolution: the objection was itself flawed, and this PARTIALLY
resolves Findings Two/Seven

Argument (Khalid): market making requires consistent, systematic
commitment -- "all in or all out." A rule that discounts required
distance specifically WHEN the market happens to deliver a favorable
price is a form of hindsight-adjusted, results-based rule-bending --
exactly the kind of inconsistency a disciplined systematic strategy
must avoid. The market can and does drift a long way against any
position; controlling PnL requires continuing to trade through that
drift, not redrawing risk requirements after the fact because a
particular instance happened to move favorably first. Accepted: this
directly undermines the original critique that reanchor "unfairly"
demands more after an already-good price -- consistent behavior
regardless of how the theoretical target was reached (overshot vs.
undershot) is the philosophically correct stance for a committed
market-making system, not a flaw.

### What this resolution does NOT resolve

Finding Seven's core mechanism is NOT about discounting for favorable
outcomes -- it is that the KINETIC component (cushion required)
shrinks as an anchor ages (sigma_pts decaying), while the DRIFT
component (price displacement from that same aging anchor) grows,
for reasons unrelated to any deliberate risk stance in either
direction. This is not "consistently demand full cushion" -- it is
"demand a shrinking cushion against a growing displacement," which
is not obviously principled in either direction and may simply be an
unintended interaction between two mechanisms (ComputeKineticDistance
and ADR-079's reanchor) never designed with each other in mind. This
remains open.

### Forward-looking structural point (Khalid)

The entire failure mode traced in Findings Two, Five, Six, and Seven
is structurally tied to a SINGLE bidirectional instance holding one
aging, unrefreshed anchor through a violent drift. Once the
already-approved dual-instance architecture (BIAS_LONG_ONLY /
BIAS_SHORT_ONLY, replacing the current single BIAS_BOTH instance) is
live, a violent one-directional drift would no longer mean "our
existing position's anchor gets worse" -- it would mean "a brand-new
entry for the OPPOSITE-biased instance," with a genuinely fresh
anchor. Per Finding Seven's own mechanics, fresh anchors carry modest
kinetic distances with zero accumulated drift. This suggests the
dual-instance design may not merely add market coverage as originally
scoped -- it may structurally eliminate the specific mechanism traced
across this entire document, for the instance capturing the retrace
side of the move. Should be treated as a genuine, additional
justification for prioritizing the dual-instance rollout, not just a
side benefit.

### Updated status of open questions

- Finding Two's original framing ("reanchor drift is a problem to
  fix") should be softened -- the consistency argument above suggests
  the CURRENT behavior may be closer to correct than originally
  assessed, at least for the "demand full distance regardless of
  overshoot" aspect specifically.
- Finding Seven's asymmetric kinetic-vs-drift trend remains
  genuinely open and unresolved by this argument.
- The dual-instance architecture's potential to structurally resolve
  this class of finding should be raised explicitly when this
  document is eventually sent to the Staff Architect, as a
  consideration for SEQUENCING (may reduce urgency of a dedicated fix
  to Findings Two/Seven if the dual-instance rollout is imminent
  anyway).

## Finding 9 (Proposal): Replace Fixed 3-Pip Exit Floor With
Kinetic-Distance-Derived Exit Sizing

### Motivation (Khalid)

The current fixed exit distance (MinLayerExitPoints, 3 pips) is
arbitrary, justified only as a floor to avoid a round-trip losing
money to commission. Separately, GridBase (8 pips) exists as the
add-side floor, itself also an arbitrary starting constant. Rather
than introducing a THIRD arbitrary number to "fix" the exit, tie exit
sizing to the SAME real-time kinetic_dist signal already validated
and trusted for the add side. This removes an independent constant
rather than replacing one guess with another -- explicitly NOT
curve-fitting, since the formula is proposed on structural grounds
(shared signal, preserved ordering) before seeing whether it improves
backtest P&L, not fitted to match a desired historical outcome.

Explicitly supersedes the old 0.618^(n+1) decay-based exit formula,
confirmed in ADR-080 to have been miscalibrated for this use (the
0.618 x 1.618 near-cancellation identified that session). No attempt
to preserve or repair that formula -- full replacement.

### Proposed formula

exit_distance_pips = max(3, min(kinetic_dist_pips / 3, 8))

- 3-pip floor: preserves the original commission-cost justification
- 8-pip cap: linked to kinetic_dist=24 pips, confirmed via this
  session's own data to sit almost exactly at the 75th percentile of
  real observed kinetic_dist values (24.6) across 137 logged
  observations -- i.e. the cap engages specifically in the upper
  quartile of real conditions, not only in rare extreme events
- Division by 3 (not a separately-tuned constant): ensures exit
  distance stays smaller than add distance using the SAME underlying
  signal, by construction (verified numerically across the full
  observed range 3-79.9 pips: exit < add in every case except the
  single boundary point where kinetic_dist itself equals exactly the
  3-pip floor, where they become equal rather than strictly ordered --
  a minor edge case needing explicit handling, not a broad failure)

### Empirical simulation against this session's real dataset (137
kinetic-win observations)

| Percentile of real kinetic_dist | Value |
|---|---|
| 10th | 11.0 pips |
| 25th | 12.1 pips |
| 50th (median) | 14.8 pips |
| 75th | 24.6 pips |
| 90th | 39.4 pips |
| 95th | 57.1 pips |
| Max | 79.9 pips |

Applying the proposed formula to every real observation:
- Hits 3-pip floor: 1.5% of observations (rare, as intended)
- Hits 8-pip cap: 26.3% of observations (engages for the upper
  quartile of conditions, consistent with the 24-pip trigger point
  landing near the 75th percentile)
- Scales smoothly in between: 72.3% of observations
- Mean proposed exit: 5.58 pips, vs. today's flat 3.0 pips -- a
  substantial increase, not a minor tuning adjustment

### Expected consequence, not yet backtested

Given this session's own prior finding that trade frequency dropped
sharply once spacing fixes (ADR-077-081) were validated, a near-doubling
of average exit distance would very plausibly reduce trade frequency
further and increase average hold time per layer. This is a genuine
behavioral tradeoff to validate via backtest, not assume as purely
beneficial.

### Open question requiring anchor confirmation BEFORE implementation

Does ComputeExitPriceDeterministic() (exit lock, in HandleEntryFill)
and ComputeNextLayerPrice() (add computation, same function, same
layer-creation event) use the IDENTICAL kinetic_dist snapshot, or
could each independently recompute it and potentially diverge (even
by a small amount, if computed at slightly different points in
execution)? The "preserves ordering by construction" argument depends
on both sides referencing the SAME value for a given layer -- this
needs verification, not assumption, before any implementation prompt
is drafted.

### Anchor confirmation received

Confirmed via anchor: ComputeExitPriceDeterministic() does NOT
currently use kinetic_dist at all (uses a separate 0.618 decay
formula) -- a kinetic-based exit would be a genuinely new code path,
not an extension. ComputeKineticDistance() is directly callable from
HandleEntryFill() at the exit-lock point with no restructuring
required for basic access.

CRITICAL DEPENDENCY SURFACED: the "preserves exit<add ordering by
construction" argument only holds when DebugUseUnifiedAddNextSpacing
is TRUE. In production default (false), the add side runs the legacy
E_n*1.618 golden-ratio path and does not call ComputeKineticDistance()
at all -- meaning a kinetic-derived exit would be measured against an
add-side distance computed by an entirely different formula, breaking
the clean ratio guarantee verified numerically earlier in this
section. This proposal is therefore NOT independent of ADR-080 -- it
should be scoped and tested as a combined change alongside
DebugUseUnifiedAddNextSpacing=true, not standalone.

Also confirmed: two independent calls to ComputeKineticDistance(instrument)
within one HandleEntryFill() execution are FUNCTIONALLY equivalent
today (same g_sigma_fv_pts snapshot, no bar-close refresh possible
mid-call) but NOT an enforced architectural guarantee -- a future
change refreshing that global mid-function would silently break the
ordering property. Recommended implementation pattern: compute
kinetic_dist ONCE locally in HandleEntryFill, pass the same value
explicitly into both the exit formula and the add computation, rather
than relying on two independent calls to coincidentally agree.

**[SUPERSEDED]** This specific recommendation (compute once, pass by
reference/new parameter) was explicitly put to the Staff Architect as
a binary choice during Step 1 planning and OVERRULED in favor of
independent calls with no signature change to ComputeNextLayerPrice(),
citing the same single-threaded execution invariant identified in this
anchor. See Ruling 1 (Step 1, Unified Geometric Engine planning). The
"not an enforced architectural guarantee" fragility noted above is
accepted as a documented tradeoff, not eliminated -- ADR-082 is
required to explicitly note this invariant dependency.

## Next Steps

This document will be appended to as review continues. Once evidence
collection is complete, this becomes the basis for a memo to the Staff
Architect (Gemini) for a design ruling before any Cursor
implementation prompt is drafted.
