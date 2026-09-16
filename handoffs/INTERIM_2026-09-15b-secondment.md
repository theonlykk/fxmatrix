# INTERIM NOTE 2026-09-15b -- BMO SECONDMENT, AND A PROPERTY OF THE STRATEGY

Not a session handoff. This records a design conversation and one
architectural observation that has been lost once already. For Staff
Architect review.

Nothing here is ratified. No code has been written. The secondment is not
signed.

---

## 1. WHAT CHANGED COMMERCIALLY

The head of FX at BMO has chosen the secondment, not the preferred outcome.
One month on the desk, operator enters limit orders by hand, no development
work. Roughly 1mm per trade. Desk hours 07:00-17:00 London.

Constraints as described:

  - orders entered manually into the bank's trading system
  - entries can be added during the session; resting ENTRY orders must be
    pulled at the close
  - EXIT orders may be left working overnight
  - the bank's system will not carry our layer labels, so entry/exit pairing
    must be tracked outside it
  - four books requested: long and short for each of two strategy arms

Commercial note, recorded because it bears on what gets demonstrated: this
is the version where the method is proven at the bank's size on the bank's
book without the bank having bought anything. Worth establishing in writing
what the month is meant to trigger.

---

## 2. THE OBSERVATION -- THE STRATEGY NEEDS NO MARKET DATA

**Given one starting mid, every subsequent order level is derivable from
trade events alone.**

  - exit          = fill +/- exit_pips
  - next add      = fill +/- add_pips  (= 2 x width, ADR-125 decision 7)
  - opposite L0   = fill +/- 2 x width

The market tells us where it traded. We never need to ask where it is. A
continuous price feed is not required; an event stream is.

The operator raised this a week or two ago and it was not written down. It
is written down now.

Consequences that were previously just facts:

  - **ADR-123 place-once-and-wait was the strategy finding its natural
    form**, not a simplification. Nothing needs re-quoting because nothing
    depends on current mid.
  - **The manual version is viable because the trigger is an event, not a
    clock.** Ten hours a day is workable when you respond to fills rather
    than watch a screen.
  - **The reconciler and the entry app are the same object.** Given the fill
    list, derive the ladder. That is simultaneously "what should be resting"
    and "what did I do"; any divergence is the error.

### The one remaining dependency on live price

`Grind_TryRecenterOppositeL0` (ADR-124) prices the stranded opposite L0 at
`Grind_StraddleBuyPrice(current_mid, width_pips)` -- anchored to CURRENT MID,
not to the fill. Trigger is `Grind_StrandedDistMidPips(resting, mid) >
InpStrandedThreshPips` (= 2 x width), with `InpDeadbandPips` as a no-op
guard against trivial modifies.

That is the last thing in the engine that needs to know where the market is.

---

## 3. PROPOSED CHANGE -- FILL-ANCHORED OPPOSITE L0 WITH A PRICE CEILING

Operator proposal. Replace mid-anchoring with:

    place the opposite L0 at the arithmetic level (fill +/- 2 x width),
    and NEVER WORSE than that level -- for a bid, never higher; for an
    offer, never lower. If the market has already run past, take the
    better price.

Properties:

  - **Computable on paper.** The level is derivable from the fill list.
  - **Not a chase.** The computed level is a ceiling, not a target.
  - **Timing-insensitive.** "At or better than X" stays correct whether the
    order is placed in 3 seconds or 300, which matters when a human is the
    actuator.
  - **Reconciler-friendly.** The invariant is "at or better than computed",
    which is CHECKABLE regardless of when placement happened -- a stronger
    property for reconciliation than exact prediction.

### Claude's objection, and why it is withdrawn

Initial concern: mid-anchoring is what keeps the book two-sided in a trend.
If the long L0 fills and price keeps falling, a mid-anchored short L0
follows price down and can still fill; a purely fill-anchored one sits
stranded above and recedes, leaving the instance one-sided for the whole
move. The live book supports the concern -- GBPUSD_OPT currently holds three
long layers against four short, and that two-sidedness has to come from
somewhere.

The ceiling rule answers it. Under "at or better", the opposite L0 follows a
crashing market down and still fills. The arithmetic level becomes the
WORST acceptable price rather than the price. The objection does not survive
the amended proposal.

### What cannot evaluate this

`scripts/grid_sim_v7_real_signal.py` is SINGLE-SIDED by construction -- the
straddle is placed only inside `if not layers:`, that block ends in
`continue`, and adds inherit `cur.direction`. Once a pod opens the opposite
side is abandoned. **The simulator has never modelled the behaviour this
change would alter**, so a sweep comparing the two variants would report no
difference because neither exists in it.

Two honest routes if evidence is wanted before superseding ADR-124:

  a. **Live A/B on one demo pair.** Cheap, and it is how signal-vs-dumb was
     settled (N~190).
  b. **Replay `fill_logs`.** Compute where each rule would have placed the
     opposite order and how often it would have filled. No simulator change
     needed; uses data already archived.

Note the manual version can adopt the ceiling rule from day one regardless,
since it is a new system rather than a change to a running one.

---

## 4. THE MANUAL TOOL -- SHAPE, NOT SPEC

Twelve squares, one per pair, four columns per square (one per book). Each
column shows the price range with entry, add and exit levels marked. Clicking
an entry marks it filled and assigns it a label; exits get labels too,
reusing the `GRIND|OPT|L|L03|ENT` notation so screen and reconciler share one
vocabulary. A check mark records "confirmed working with the broker". An
action log runs alongside.

Design points settled in conversation:

  - **The log is the system of record, not a sidebar.** There is no broker
    book carrying our layer labels to rebuild from, so the append-only fill
    list IS the truth and the grid is derived from it. A card that
    "disappears" on exit should record a close event and move to a completed
    state, not vanish -- otherwise a missed click silently desyncs
    everything.
  - **Detect, do not self-heal.** If a fill price is corrected after an exit
    is already working, the recomputed level no longer matches the resting
    order. The tool must distinguish CALCULATED from WORKING and flag the
    mismatch, exactly as the invariants halt rather than repair.
  - **No market connection required** (section 2). The tool can be built and
    tested from a fill list alone, and validated by replaying `fill_logs`
    through its arithmetic and comparing against what the EA actually placed.
    Divergences should be exactly the ADR-124 re-centres.

Open: whether partial fills need modelling. MT5 fills a limit whole or not at
all, so the EA has no concept of a partially-filled layer, and everything
from ADR-120 onward assumes whole layers. Introducing partials changes layer
indexing, exit sizing and CloseBy pairing. Worth establishing whether
partials are actually common at 1mm on their franchise before building for
them.

---

## 5. CLAUDE WAS WRONG TWICE, RECORDED

**Cadence.** Claude claimed manual operation of the full twelve-instance
fleet was impractical, from "43 scalps in 13 hours". The better measure is
`api_count`, which counts every broker interaction and read 233 fleet-wide
over ~15 hours -- about **16 actions per hour across all twelve**, one every
four minutes. Manual operation of the full fleet is tractable. The estimate
was wrong.

Caveat that stands: 16/hour is a mean over a day including the dead Asian
session. The number that matters is the worst minute during London.
`send_logs` carries `action` and `broker_time` and can answer it.

**Deadband.** Claude twice described L0 as chasing mid against a deadband.
That behaviour was REMOVED by ADR-123 and ADR-124 exists because a
regression had reintroduced it; the `deadband_pips` parameter was removed
from `Grind_TryPlaceL0` and PO1-PO4 guard it. Claude was reasoning from a
stale model and the operator was right to push.

---

## 6. WHAT SHOULD HAPPEN NEXT, IN ORDER

1. **Drill it on the demo.** Add a manual instance on a pair the fleet does
   not run (AUDNZD and NZDCAD are both under sweep and would collide with
   nothing). Work it by hand for a week on the FTMO demo: same broker, same
   feed, same order types, real fills. A spreadsheet suffices; the tool
   should be built from what is actually reached for. This is the highest-
   value item and it requires no development.

2. **Session measurement.** What fraction of entries fall outside 07:00-17:00
   London, and what share of realised P&L traces to them. `fill_logs` has
   `entry_type` (IN / OUT_BY) and `received_at` in UTC. **`scalp_history`
   cannot answer this** -- it has `close_time_broker` but no entry timestamp
   and no layer index. Note `fill_logs` holds ~701 rows, roughly five days,
   so coverage is thin. London is BST now, so the mask is 06:00-16:00 UTC and
   must be timezone-aware or it drifts an hour in late October.

3. **Book depth at 17:00.** What would actually be carried overnight. Same
   data source.

4. Only then: tool specification.

---

## 7. NOT RAISED BEFORE, WORTH KNOWING

Connecting trade events across pairs -- not needed now, but the machinery
exists and is switched off. The cross-instance exposure cap publishes each
instance's signed position per currency leg to GlobalVariables every tick.
That is already a cross-pair event stream. It is inert at zero thresholds
and, as of ADR-149, executable for the first time.
