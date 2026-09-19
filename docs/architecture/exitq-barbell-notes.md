This message has a line count at the bottom

# EXIT QUEUE: BARBELL, NOT PREFIX

Status: NOT RATIFIED. No ADR. No code. Not put to Gemini.
Raised by the operator 2026-09-18 evening, worked through 2026-09-19 morning.

Companion to `docs/architecture/roll-at-cap-notes.md` s7, where the idea
first appears as a line item.

---

## 1. THE IDEA

ADR-151's exit queue is a PREFIX: rest ranks `0 .. K-1`, hold everything
deeper. At `K=1, H=0` that is exactly one resting exit per side, the one
nearest market.

**The MOST UNDERWATER layer is therefore the FIRST thing dropped**, because
rank is ordered nearest-to-market and the most underwater layer is furthest
away -- it carries the HIGHEST rank, not the lowest.

That is the layer we most want reachable. It is the ejection candidate, and
it is the one that will sit unexited longest.

**Proposal: rest rank 0 PLUS the highest rank. Drop the middle.** A barbell
rather than a prefix.

### Terminology, because it is easy to get backwards

On a long ladder built downward, the layer with the DEEPEST INDEX (L2, L3...)
has the LOWEST entry price and is NEAREST market -- it is rank 0 and the
LEAST underwater. The layer with the LOWEST index (L0) has the HIGHEST entry
price, is FURTHEST from market, and is the MOST UNDERWATER -- it carries the
HIGHEST rank.

**"Deepest" is ambiguous and should not be used.** Say "most underwater" or
"highest rank" for the ejection candidate, and "rank 0" or "nearest market"
for the front of the queue.

## 2. WORKED EXAMPLE -- WHY IT MATTERS AT SMALL DEPTHS

Long ladder, two layers:

    L0 entered 100, exit 102, next add 95
    L1 entered  95, exit  98, next add 90

Rank is nearest-to-market first, so L1 (95) is rank 0 and L0 (100) is rank 1.

**Today, K=1/H=0:**

| order | price | what |
|---|---:|---|
| sell limit | 98 | L1 exit, rank 0 |
| buy limit | 90 | next add |

L0's exit at 102 is HELD -- no broker order.

**Under the barbell:**

| order | price | what |
|---|---:|---|
| sell limit | 98 | L1 exit, rank 0 |
| sell limit | 102 | L0 exit, most underwater |
| buy limit | 90 | next add |

**The operator's point: at this depth we are not remotely constrained.** Two
positions, two or three orders. Holding L0's exit saves one unit we do not
need, and costs us the order we would most want working.

## 2a. WHAT HAPPENS WHEN THE FRONT EXIT FILLS

Continuing the same example. The sell limit at 98 is lifted.

**The add does NOT stay at 90.** An add is anchored to the MOST RECENT layer
-- the one nearest market -- not to the market itself. L1 at 95 has just
closed, so L0 at 100 is all that remains, and the next add belongs one
`add_pips` step below it -- at 95.

So the 90 order is cancelled and a 95 placed (or modified up to 95).

**State after the fill:**

| | |
|---|---|
| positions | 1 long at 100 |
| sell limit 102 | L0's exit, now rank 0 |
| buy limit 95 | next add, re-anchored |
| realised | +3 on the closed layer |

Guard cost 4: one position, two orders, one reserved for the add's future
exit.

**This is why an add appears to track the market without ever being priced
off it.** The ladder shortens from the deep end and the anchor climbs with
it. Nothing re-quotes toward mid -- only L0 does that, and only when a side
is flat.

**And the barbell is a no-op again at depth 1**: rank 0 IS the highest rank,
so one exit rests either way.

**The asymmetry worth naming.** The layer that closes is always the one
NEAREST market, for a profit. What remains is always the one furthest from
it. Sell high, buy back lower, repeat -- and the inventory that lingers is
always the worst of what is held. That is precisely why the most
underwater layer is the one worth keeping reachable, and why dropping it
first (today's prefix rule) is backwards.

## 2a-bis. THREE LAYERS -- WHERE A MIDDLE FIRST EXISTS

Trade log:

    L0 buy 100   -> next add 95,  exit 103
    L1 buy  95   -> next add 90,  exit  98
    L2 buy  90   -> next add 85,  exit  93

Ranks are nearest-market first, so the NEWEST layer is rank 0 and the MOST
UNDERWATER is the highest rank:

| layer | entry | exit | rank | note |
|---|---:|---:|---:|---|
| L2 | 90 | 93 | 0 | newest, nearest market, least underwater |
| L1 | 95 | 98 | 1 | the middle |
| L0 | 100 | 103 | 2 | oldest, furthest from market, MOST UNDERWATER |

### The blotter, today (K=1/H=0, prefix)

    POSITIONS
      BUY  1.00  @ 100        L0
      BUY  1.00  @  95        L1
      BUY  1.00  @  90        L2

    WORKING ORDERS
      SELL LIMIT  @  93       L2 exit   (rank 0)
      BUY  LIMIT  @  85       next add

    HELD (no broker order)
      L1 exit 98   (rank 1)
      L0 exit 103  (rank 2)  <-- the ejection candidate, not on the book

### The blotter, under the barbell

    POSITIONS
      BUY  1.00  @ 100        L0
      BUY  1.00  @  95        L1
      BUY  1.00  @  90        L2

    WORKING ORDERS
      SELL LIMIT  @  93       L2 exit   (rank 0)
      SELL LIMIT  @ 103       L0 exit   (highest rank, most underwater)
      BUY  LIMIT  @  85       next add

    HELD (no broker order)
      L1 exit 98   (rank 1)  <-- the middle, which is what we meant to drop

**Correction, 2026-09-19.** An earlier draft said three layers is where the
barbell first does anything. That is wrong. At depth 2 rank 0 and rank 1 are
already different layers, so the barbell rests BOTH where the prefix rests
one -- it differs from depth 2 onward.

**What first appears at depth 3 is a MIDDLE**: a layer that is neither rank 0
nor the highest rank, and is therefore held. Below that there is nothing to
drop.

Guard cost: 3 positions + 3 orders + 1 reserved for the add's exit = 7, against
6 under the prefix. One unit buys a working exit on the layer we would eject.

## 2a-ter. FOUR LAYERS -- THE MIDDLE GROWS, THE COST DOES NOT

Trade log continues:

    L0 buy 100   -> next add 95,  exit 103
    L1 buy  95   -> next add 90,  exit  98
    L2 buy  90   -> next add 85,  exit  93
    L3 buy  85   -> next add 80,  exit  88

| layer | entry | exit | rank | note |
|---|---:|---:|---:|---|
| L3 | 85 | 88 | 0 | newest, nearest market |
| L2 | 90 | 93 | 1 | middle |
| L1 | 95 | 98 | 2 | middle |
| L0 | 100 | 103 | 3 | MOST UNDERWATER |

### The blotter, under the barbell

    POSITIONS
      BUY  1.00  @ 100        L0
      BUY  1.00  @  95        L1
      BUY  1.00  @  90        L2
      BUY  1.00  @  85        L3

    WORKING ORDERS
      SELL LIMIT  @  88       L3 exit   (rank 0)
      SELL LIMIT  @ 103       L0 exit   (highest rank, most underwater)
      BUY  LIMIT  @  80       next add

    HELD (no broker order)
      L2 exit 93   (rank 1)
      L1 exit 98   (rank 2)

**The middle is now two layers rather than one, and the working-order count
is unchanged at three.** Guard cost 9 -- four positions, three orders, one
reserved for the add's future exit -- against 8 under today's prefix.

**The barbell's extra unit stays at exactly one however deep the ladder
goes.** Every new layer arrives at rank 0, pushing the previous rank 0 into
the middle where it is held. Only the two ends ever rest.

That is the property that makes it affordable: the cost does not scale with
depth, while the benefit -- a working exit on the ejection candidate --
matters MORE as the ladder deepens and that layer gets further underwater.

## 2a-quater. THE FRONT EXIT FILLS ON A FOUR-LAYER LADDER

Continuing from 2a-ter. The sell limit at 88 is lifted, so L3 closes for +3.

**Positions** -- three longs remain: 100, 95, 90.

Ranks re-form:

| layer | entry | exit | rank | note |
|---|---:|---:|---:|---|
| L2 | 90 | 93 | 0 | promoted from rank 1 |
| L1 | 95 | 98 | 1 | middle |
| L0 | 100 | 103 | 2 | MOST UNDERWATER, unchanged |

### The blotter after the fill

    POSITIONS
      BUY  1.00  @ 100        L0
      BUY  1.00  @  95        L1
      BUY  1.00  @  90        L2

    WORKING ORDERS
      SELL LIMIT  @  93       L2 exit   (rank 0)      <- newly PLACED
      SELL LIMIT  @ 103       L0 exit   (highest rank) <- UNTOUCHED
      BUY  LIMIT  @  85       next add                 <- RE-PRICED from 80

    HELD (no broker order)
      L1 exit 98   (rank 1)

    REALISED
      +3 on L3

### Four distinct engine actions, worth separating

1. **L3's exit FILLED** -- the layer closes and is removed from the side.
2. **L2's exit is PLACED.** It was held at rank 1; promotion to rank 0 makes
   it required, so a new sell limit goes on at 93.
3. **L0's exit at 103 is UNTOUCHED.** It was the highest rank before the fill
   and still is. No cancel, no re-place. **That matters: it is the order a
   passive ejection would modify, and it stays continuously live.**
4. **The add is RE-PRICED from 80 to 85.** Anchored to the layer nearest
   market, which is now L2 at 90, so one `add_pips` step below.

Net on the terminal: one order filled, one placed, one re-priced, one left
alone.

**Contrast with the prefix rule**, where L0's exit is never on the book at
all -- an ejection would have to `OrderSend` a fresh order at the moment the
guard is most likely to refuse it (`roll-at-cap-notes.md` s3a, the 73-minute
measurement).

## 2a-quinquies. THE ADD FILLS -- THE ROTATION COMPLETES

Continuing from 2a-quater. Price falls and the buy limit at 85 is hit. It
becomes a new layer with exit 88, and the next add moves to 80.

**Positions** -- four longs: 100, 95, 90, 85.

| layer | entry | exit | rank | note |
|---|---:|---:|---:|---|
| L4 | 85 | 88 | 0 | just filled |
| L2 | 90 | 93 | 1 | DEMOTED from rank 0 |
| L1 | 95 | 98 | 2 | middle |
| L0 | 100 | 103 | 3 | MOST UNDERWATER, still untouched |

### The blotter

    POSITIONS
      BUY  1.00  @ 100        L0
      BUY  1.00  @  95        L1
      BUY  1.00  @  90        L2
      BUY  1.00  @  85        L4

    WORKING ORDERS
      SELL LIMIT  @  88       L4 exit   (rank 0)       <- newly PLACED
      SELL LIMIT  @ 103       L0 exit   (highest rank) <- UNTOUCHED
      BUY  LIMIT  @  80       next add                 <- RE-PRICED from 85

    HELD (no broker order)
      L2 exit 93   (rank 1)   <- CANCELLED on demotion
      L1 exit 98   (rank 2)

### Engine actions

1. **The add at 85 FILLED** and became a layer.
2. **L4's exit is PLACED** at 88.
3. **L2's exit at 93 is CANCELLED** -- it drops from rank 0 to rank 1 and is
   no longer required.
4. **A new add is PLACED at 80**, one step below the new nearest-market
   layer.
5. **L0's exit at 103 is UNTOUCHED** for the second rotation running.

### The rotation, and why the barbell survives it

The ladder is now the same shape as 2a-ter with a different index on the
newest layer. **One full cycle -- front exit fills, add fills -- and L0's
exit has never been cancelled or re-placed.**

That is the whole argument. Under K=1/H=0 the front of the queue churns on
every fill: one cancel and one place per rotation. The barbell adds a second
resting order that sits completely still through all of it, because the most
underwater layer only changes when it finally exits or is ejected.

**Note step 3 is exactly the path the stale-offset bug lived on** (`02_TRAPS`,
fixed in `241a905`): a cancelled exit whose stored offset was never cleared,
then re-placed later at the raw formula. Under the barbell that path is
unchanged for the middle, so the fix remains load-bearing.

## 2b. THE SAME LADDER, WITH CARRY APPLIED

Two layers -- L0 at 100, L1 at 95 -- with the barbell resting both exits.
The most recent layer is 95, so the add sits one `add_pips` step below at 90.

Starting state: positions long 100 and long 95; sell limits at 102 and 98;
buy limit at 90.

### Case 1 -- negative carry of 2

We paid it, so each exit moves FURTHER from entry. For a long that is up.

| order | type | before | after |
|---|---|---:|---:|
| L0 exit | sell limit | 102 | **104** |
| L1 exit | sell limit | 98 | **100** |
| next add | buy limit | 90 | 90 |

Positions unchanged: long 100, long 95.

### Case 2 -- positive carry of 2

We received it, so each exit moves CLOSER to entry.

| order | type | before | after |
|---|---|---:|---:|
| L0 exit | sell limit | 102 | **100** |
| L1 exit | sell limit | 98 | **96** |
| next add | buy limit | 90 | 90 |

Positions unchanged: long 100, long 95.

### What the two cases show

**The add never moves.** Carry applies to inventory, not to unfilled quotes.
There is no position behind a buy limit, so nothing has accrued. ARCHITECT
s1, and pipshed's carry audit already skips ENT rows with exactly that
reason.

**Both exits shift by the same amount** because both layers are long, same
size, same pair, same number of nights held. They diverge once held for
different numbers of nights -- a layer opened three nights ago carries three
nights of accrual, one opened last night carries one. **In a real ladder the
shifts are per-layer and unequal, which is why the adjustment must be stored
per position ticket rather than per side.**

## 2b-bis. CARRY WITH TWO EXITS IN PURGATORY -- AND A GAP

Four layers as in 2a-quinquies: long 100, 95, 90, 85. Two exits resting (L4
rank 0 at 88, L0 highest rank at 103), two held (L2 at 93, L1 at 98). Add at
80.

**Carry accrues on all four positions.** A held exit is still a position
paying or receiving swap. The difference is only WHERE the adjustment lands:
a broker order for the resting two, the tracker's formula target for the held
two.

### Case 1 -- negative carry of 2

| layer | rank | exit before | exit after | where |
|---|---:|---:|---:|---|
| L4 | 0 | 88 | **90** | terminal -- order modified |
| L2 | 1 | 93 | **95** | held -- tracker only |
| L1 | 2 | 98 | **100** | held -- tracker only |
| L0 | 3 | 103 | **105** | terminal -- order modified |
| add | -- | 80 | 80 | unchanged |

### Case 2 -- positive carry of 2

| layer | rank | exit before | exit after | where |
|---|---:|---:|---:|---|
| L4 | 0 | 88 | **86** | terminal -- order modified |
| L2 | 1 | 93 | **91** | held -- tracker only |
| L1 | 2 | 98 | **96** | held -- tracker only |
| L0 | 3 | 103 | **101** | terminal -- order modified |
| add | -- | 80 | 80 | unchanged |

Positions unchanged in both cases.

**Two order modifies, two tracker updates, nothing to the add.** That is the
economy of purgatory: four layers accrue, only two cost an API call.

### THE GAP -- this is not what the code does

**The carry pass never sees a held layer.** `grind_carry.mqh:767` and `:775`:

    if(layer.position_ticket == 0 || layer.exit_order_ticket == 0)
       continue;

A held layer has `exit_order_ticket == 0`, so it is skipped when the work list
is built. It accrues nothing.

The tables above are what SHOULD happen. Under the current implementation L2
and L1 accrue carry with nothing recorded against them, and when either is
later promoted to rank 0 the queue places its exit at the RAW formula --
losing every night of carry it accumulated while off the book.

**This is worse under K=1/H=0 than it was under K=2/H=1**, because more
layers sit held at any moment. The barbell does not fix it either: the middle
is still held.

## 2c. THE EXTREME CASE -- CARRY OF 6, AND NOTHING SHOULD PREVENT IT

Same ladder: positions long 100 and long 95; sell limits at 102 and 98; buy
limit at 90.

### Case 1 -- negative carry of 6

| order | type | before | after |
|---|---|---:|---:|
| L0 exit | sell limit | 102 | **108** |
| L1 exit | sell limit | 98 | **104** |
| next add | buy limit | 90 | 90 |

Positions unchanged: long 100, long 95.

### Case 2 -- positive carry of 6

| order | type | before | after |
|---|---|---:|---:|
| L0 exit | sell limit | 102 | **96** |
| L1 exit | sell limit | 98 | **92** |
| next add | buy limit | 90 | 90 |

Positions unchanged: long 100, long 95.

### Why case 2 is the one to stare at

Both exits are now BELOW their own entries, and the levels interleave:

| level | what |
|---:|---|
| 100 | L0 entry |
| 96 | L0 exit -- 4 below its own entry |
| 95 | L1 entry |
| 92 | L1 exit -- 3 below its own entry |
| 90 | next add |

**L1 closes for a 3-point loss on price against 6 collected in carry -- net
+3, exactly what the original exit at 98 was worth.** The trade earns what it
was priced to earn. An exit below entry is a correct outcome, not an error.

The exits are interleaved with the entries rather than sitting above them in
order. Also fine: independent positions, independent accrual.

**There should be no logic preventing any of this, and as far as we can see
there is none.** `Grind_CarryShiftedExitPrice` applies the shift
arithmetically with no floor at entry price and no ordering constraint
between layers. A guard that refused to move an exit past its entry would
silently break the economics ADR-135b exists to preserve.

### The one real consequence

Once a long's exit is pushed BELOW the market it cannot rest as a sell limit,
and `Grind_ExitQClampPassive` moves it to `ask + min_dist`. **That is the
carry-plus-clamp interaction that nothing currently tests** -- recorded as
the open unknown in `02_TRAPS`.

With the ladder above, market would have to be at or near 92 for L1's exit to
be unrestable -- 3 above its own entry, on a pair that has rallied while
paying you to be long. Carry of 6 is many nights at typical rates, but it is
exactly what a deep layer held for a fortnight looks like, and the deep
layers are the ones that sit longest.

## 2d. THE GAP-THROUGH CASE -- WHAT PURGATORY ACTUALLY COSTS

Five layers: long 100, 95, 90, 85, 80. Ranks by exit price ascending, so the
newest layer is rank 0 and the most underwater is the highest rank.

| layer | entry | exit | rank | on book? |
|---|---:|---:|---:|---|
| L4 | 80 | 83 | 0 | **resting** |
| L3 | 85 | 88 | 1 | held |
| L2 | 90 | 93 | 2 | held |
| L1 | 95 | 98 | 3 | held |
| L0 | 100 | 103 | 4 | **resting** (barbell) |

**Market jumps to 95 and stays there.** Three exits -- 83, 88, 93 -- are now
below market. Only ONE of them was on the book.

**L4's exit at 83 fills** at 95 or better: a sell limit below market executes
at market. That layer earns about 15 instead of the 3 it was priced for.

**L3's exit at 88 and L2's at 93 do not fill. They did not exist.** Price
traded straight through both levels with nothing there.

### What follows is a cascade, not a simultaneous exit

1. L4 closes. L3 becomes rank 0, so its exit is placed -- but 88 is below
   market, so `Grind_ExitQClampPassive` moves it to `ask + min_dist`, about
   95.001. It fills on the next tick that reaches it.
2. L3 closes. L2 becomes rank 0. Same clamp, same wait.
3. L2 closes. L1 becomes rank 0. Its exit at 98 is ABOVE market, so it rests
   normally and waits for price to come to it.
4. L0's exit at 103 sits untouched above market throughout.

So the three deep layers exit near 95 rather than at 83, 88 and 93 -- BETTER
prices, because the market came to them.

**The cost is serialisation, not price.** Three layers that should have
exited in one sweep instead exit one per tick, each waiting its turn at rank
0. On a jump that holds, that is seconds. On a jump that REVERSES, you may
get only the first and the rest go back underwater.

### The honest failure case

**If the high prints exactly 95 and 95.001 never trades, none of them fill.**
Three layers that were deep in profit at the high end up underwater again,
and the tick chart shows you were there. That is strictly worse than the
resting case, where all three would have filled at 95.

Two qualifiers, neither of which makes it go away:

- `min_dist` is typically ONE POINT, not one pip -- 95.001 on a 5-digit pair,
  not 95.01. The window is a tenth of a pip. Narrow, but an exact-high print
  is exactly when a tenth matters.
- **The clamp is not a choice.** A sell limit at or below the ask is rejected
  by the broker. The alternatives are crossing the spread, forbidden by
  ARCHITECT s1, or leaving the position open until price returns. The clamp
  is the least-bad legal option.

### What this says about the design

**This cost exists only for HELD exits.** A resting exit at 93 fills at 95
with no clamp involved. So every layer in purgatory is a layer exposed to
this, and the most exposed are the middle -- which both the prefix rule and
the barbell hold.

**It is insurance paid continuously and claimed in violent moves.** Purgatory
saves guard units on every ordinary tick and costs you only when several
exits are crossed at once.

**And it argues for the barbell.** Under the prefix rule L0's exit at 103 is
also held, so a jump to 105 would miss EVERY exit and unwind the whole ladder
one tick at a time. The barbell guarantees the two extremes are always
covered; only the middle serialises.

**Measurable, not yet measured.** `exit_clamped_promotions_long` / `_short`
counts exactly this event -- a promoted exit arriving with its target already
passed. Added 2026-09-18, on `main`, never read.

## 2e. THE GRADUAL CASE -- WHAT PURGATORY COSTS IN ORDINARY CONDITIONS

Same five layers as 2d: long 100, 95, 90, 85, 80. Exits 103, 98, 93, 88, 83.
Add at 75. Two exits resting under the barbell (83 and 103), three held.

**Market marches up gradually to 95. No gap.**

### The cascade, with headroom

| event | market | what happens |
|---|---:|---|
| L4 exit fills at 83 | 83 | resting order, fills at its price. +3 |
| L3 promoted to rank 0 | ~83 | exit placed at 88 -- safely ABOVE market, no clamp |
| L3 exit fills at 88 | 88 | +3 |
| L2 promoted | ~88 | exit placed at 93, above market, no clamp |
| L2 exit fills at 93 | 93 | +3 |
| L1 promoted | ~93 | exit placed at 98, above market |
| price stalls at 95 | 95 | 98 does not fill |

**Every promotion had enough headroom to place its exit normally**, because
promotion happens the moment the layer below closes -- which is at a LOWER
price than the next exit. The market moves through the levels slower than the
engine reacts to a fill.

### Final state at 95

    POSITIONS
      BUY  1.00  @ 100        L0
      BUY  1.00  @  95        L1

    WORKING ORDERS
      SELL LIMIT  @  98       L1 exit   (rank 0)
      SELL LIMIT  @ 103       L0 exit   (highest rank)
      BUY  LIMIT  @  90       next add

    REALISED
      +9 from three scalps, each at its intended price

**Nothing clamped, nothing serialised, nothing lost.**

### What the buy limit does throughout

One add per side, re-priced as the ladder shortens:

| after | nearest-market layer | add moves to |
|---|---|---:|
| start | L4 at 80 | 75 |
| L4 exits | L3 at 85 | **80** |
| L3 exits | L2 at 90 | **85** |
| L2 exits | L1 at 95 | **90** |

So the bid walks 75 -> 80 -> 85 -> 90, one modify per closed layer.

Three things to be clear about:

- **It is anchored to the LAYER, not the market.** At the end price is 95 and
  the bid is at 90, five below. It tracks the lowest remaining entry, not the
  price.
- **Only ONE ever works.** A single `add_pending_ticket` per side -- there is
  never a stack of bids underneath. That is why entries cost the guard far
  less than the exit side does.
- **It never carries.** No position behind it, so no accrual (s2b).

**The asymmetry worth naming:** exits are CREATED one per layer and held in
purgatory; the add is a SINGLE order that gets RE-PRICED. Different
lifecycles, which is why the carry pass touches one and not the other.

### The bet, stated plainly

In ordinary conditions purgatory costs NOTHING -- every exit is placed before
the market reaches it -- and saves guard units on every tick. It only bites
when price moves faster than the promotion cascade, which is 2d.

## 2f. A QUIET ROLLOVER ON A FIVE-LAYER LADDER

Same five layers as 2d and 2e: long 100, 95, 90, 85, 80. Exits 103, 98, 93,
88, 83. Add at 75. Two exits resting under the barbell, three held.

**Nothing trades. We roll to the next day.** All five layers accrue one
night.

### Case 1 -- negative carry of 2

| layer | entry | exit before | exit after | where |
|---|---:|---:|---:|---|
| L4 | 80 | 83 | **85** | terminal -- order modified |
| L3 | 85 | 88 | **90** | held -- tracker only |
| L2 | 90 | 93 | **95** | held -- tracker only |
| L1 | 95 | 98 | **100** | held -- tracker only |
| L0 | 100 | 103 | **105** | terminal -- order modified |
| add | -- | 75 | 75 | unchanged |

### Case 2 -- positive carry of 2

| layer | entry | exit before | exit after | where |
|---|---:|---:|---:|---|
| L4 | 80 | 83 | **81** | terminal -- order modified |
| L3 | 85 | 88 | **86** | held -- tracker only |
| L2 | 90 | 93 | **91** | held -- tracker only |
| L1 | 95 | 98 | **96** | held -- tracker only |
| L0 | 100 | 103 | **101** | terminal -- order modified |
| add | -- | 75 | 75 | unchanged |

Positions unchanged in both: long 100, 95, 90, 85, 80.

**Two order modifies, three tracker updates, add untouched.** Five layers
accrue; only two cost an API call.

### The converging ladder

Look at case 1. L4's exit moves to 85 -- which is L3's ENTRY price. L3's exit
moves to 90, which is L2's entry. **With negative carry the exits march up
into the entries above them.** Another night at this rate and they cross.

Nothing prevents that and nothing should (s2c). Each layer's exit is priced
off its own entry and its own accrual; the layers are independent positions
that happen to sit in a ladder.

It does mean the exit ORDER in price terms stops matching the layer order --
which is worth remembering when reading a blotter, and worth testing, because
ranking is by exit price ascending.

### This is F2 in action

**The three tracker updates do not currently happen.** `grind_carry.mqh:767`
and `:775` skip any layer with `exit_order_ticket == 0`, so L3, L2 and L1
accrue nothing. On a five-layer ladder under K=1/H=0 that is THREE FIFTHS of
the book silently missing its adjustment, every night, and the layers that
sit held longest are the ones that lose the most.

## 2g. AT CAP -- THE BEST STATEMENT OF PASSIVE EJECTION SO FAR

Eight layers, at cap: long 100, 95, 90, 85, 80, 75, 70, 65. Exits 103, 98,
93, 88, 83, 78, 73, 68.

| layer | entry | exit | rank | on book |
|---|---:|---:|---:|---|
| L7 | 65 | 68 | 0 | **resting** |
| L6 | 70 | 73 | 1 | held |
| L5 | 75 | 78 | 2 | held |
| L4 | 80 | 83 | 3 | held |
| L3 | 85 | 88 | 4 | held |
| L2 | 90 | 93 | 5 | held |
| L1 | 95 | 98 | 6 | held |
| L0 | 100 | 103 | 7 | **resting** (barbell) |

**On the fill at 65:** L7's exit is placed at 68. **No add is placed** -- the
side is at 8 of 8 and the cap refuses it. Every previous fill re-anchored the
buy limit one step lower; this one cannot.

Working orders: two sell limits, 68 and 103. **No buy limit at all.** Guard
cost 10 -- eight positions, two orders, nothing reserved.

### Doing nothing is not a position. It is the absence of a strategy.

Market drops to 62. The instinct is to hold and wait for recovery, and the
arithmetic in `roll-at-cap-notes.md` s3b supports that: ejecting the most
underwater layer at the low costs $17.76 against a ladder earning $12.90 on a
full recovery.

**But that prices ejection against the WRONG baseline.** Holding at cap is
not a position with an expected return. It is eight frozen layers, one live
exit at 68, and exactly ONE winning path: a 38-point rally. Meanwhile the
thing the system is actually good at -- harvesting oscillation -- is switched
off entirely. If price goes to 50 instead, we watch.

### The operator's sequence

    eject L0, sell limit at 62.003   -> lifted
    new bid at 60                    -> hit
    sell at 58.003                   -> lifted      (+2 scalped)
    new bid at 55                    -> ...

Each cycle is small. It is also LIVE, and it happens in the range the market
is actually in rather than the one it left.

**The bad case, accounted honestly.** If 55 never fills, L0 exited at 58
rather than 62 -- worse by 2 -- but the 62-to-60 scalp collected 2 in
between. Roughly flat, and we traded the whole way down instead of watching.

**The residual objection, which is real but weaker.** Those scalps exist only
because we keep rebuilding a ladder into a falling market, and each new layer
can itself get stranded. Being long at 55 in a market going to 50 is the same
problem one rung lower. **The mechanism does not stop the bleed -- it
converts a frozen loss into a working one.** That is still better than one
path to success.

### The ejection PRICE is a parameter, not a given

`ask + min_dist` is the worst available price, bought for near-certain
execution. The order can rest anywhere above market, and every point higher
is a point less realised on a 38-point loss.

| where | fills | price |
|---|---|---|
| `ask + min_dist` (62.003) | near-certain, now | worst |
| a few points above (64.503) | on a small bounce | 2.5 better, slot still freed |
| near the old target (103) | that is not ejecting | -- |

**At 64.503 the same ejection costs 35.5 instead of 38, and the difference is
free if you are willing to wait for a tick.** The natural setting is neither
extreme: somewhere the market plausibly reaches within the horizon that
matters, which for a ladder at cap is hours, not days.

**This is the self-timing property**, stated properly. If the ejection fills,
price ticked up and a fresh bid below makes sense. If it does not fill, price
is falling and we keep the deep layer rather than adding into the move. **The
ejection completes only when the market says the slot is worth having.**

### What it implies for implementation -- less than first thought

An earlier draft of this section claimed a parameterised ejection needs to
remember where it placed the order, as a third kind of offset alongside carry
and clamp. **That is wrong.**

**I6 already handles it.** The invariant compares the resting order's price
against the layer's `exit_target`. If the ejection sets `exit_target` to
64.503 when it modifies the order, the two agree. No new offset, no new
store -- the existing field carries it.

**And ejection is not a persistent mode.** It is one order modification. The
moment a layer closes the side is under cap and the normal EA logic resumes:
ranks re-form, the add is placed, the ladder rebuilds. If the ejection order
fills, that happens. If it does not, the order simply sits there like any
other exit.

**The only thing worth recording is observability.** A flag saying "this
layer is in ejection" so a status read shows the mechanism ARMED AND WAITING
rather than broken -- otherwise an unfilled ejection at 62.003 looks
identical to nothing having happened. That is a telemetry field, not state
the engine depends on.

### And this is why the barbell matters here

L0's exit at 103 is on the book, 35 above market, on a layer underwater since
the ladder began. Ejecting it is an `OrderModify` of an existing order -- no
new guard unit at the moment the guard is most likely saturated
(`roll-at-cap-notes.md` s3a, the 73-minute measurement).

**Under the prefix rule that order does not exist**, and the ejection would
have to `OrderSend` into a full book.

## 2h. PASSIVE EJECTION -- WHERE WE ACTUALLY LANDED

Worked through 2026-09-19. **Not finished, not ratified.** The honest summary
is that the positives are few and the negatives accumulated as we went.

### The positives

**P1. It is the only lever that reaches the position side.** Entries closed by
operator ruling, exits protected, and no configuration change frees position
units (`02_TRAPS`, Gemini 2026-09-18). Inventory can only be reduced by
closing something.

**P2. Holding at cap is not a position -- it is the absence of a strategy.**
Eight frozen layers, one live exit, exactly one winning path: a rally the
width of the ladder. Meanwhile the thing the system is good at, harvesting
path, is switched off. If price falls further, we watch.

**P3. It is passive.** Re-target the exit to `ask + min_dist` and be lifted.
No spread crossed, ARCHITECT s1 intact.

**P4. It self-times.** If the ejection fills, price ticked up and a fresh bid
below makes sense. If it does not fill, price is falling and we keep the deep
layer rather than adding into the move.

**P5. Under the barbell it is an `OrderModify`, not an `OrderSend`** -- no new
guard unit at the moment the guard is most likely saturated.

### The negatives

**N1. It locks in a loss, and recovery is all-or-nothing in the ladder's
favour.** Price can only reach the worst layer's exit by passing every
shallower exit first, so if the ladder recovers it recovers completely.
Measured (`roll-at-cap-notes.md` s3b): ejecting at the low cost $17.76
against $12.90 the whole ladder earns on a full recovery. **One ejection
wipes out fifteen scalps.**

**N2. The timing trade is brutal at both ends.**
- Eject at cap (65.002 when the eighth layer fills at 65): best price, but
  the trade is a wash -- buy 65, sell 65.002 -- and you have paid the full
  distance from the worst layer, 35 points, to swap it for one at market.
- Eject late, in free fall: the ejection fills near the low and the refill
  bid clamps to just under market, a coin-flip re-entry.
- Leave it unfilled at 62.002 while the market trades 50: **the worst of
  all.** You have made the ejection, got none of the benefit, and the side is
  still capped and frozen with an order 12 points away.

**N3. Revising the ejection lower as price falls is a trailing stop.** Passive
execution does not change what it is -- a mechanism realising progressively
more loss the further price runs against you, triggered by nothing but time.
It also destroys P4.

**N4. Ejection at cap makes every eighth fill a forced give-up.** Take a
layer, give up a layer, and the one given up is always the worst. Either a
conveyor belt that keeps us at market (and costs the full ladder width each
rotation), or an expensive way to avoid deciding not to add at all.

**N5. The refill is not guaranteed.** Eject at 50.002, bid clamps to 49.998,
and if that never fills you have stopped out at the low with no re-entry.
Worst outcome available.

**N6. It converts a frozen loss into a working one -- it does not stop the
bleed.** Each rebuilt layer can strand again one rung lower. Being long at 55
in a market going to 50 is the same problem, cheaper.

**N7. It is a patch for a geometry problem.** Eight layers at 10-pip spacing
spans 80. GBPUSD's median daily RANGE is 95 (`roll-at-cap-notes.md` s3d). A
single day's move can strand the whole ladder. Ejection is the expensive fix
for a ladder that is undersized for the market it trades.

**N8. Both arms strand simultaneously.** Within each pair `width` and
`add_pips` are IDENTICAL across OPT and ALT -- only `exit_pips` differs. That
is a harvest-rate difference, not a regime one. **If the intent was one arm
for chop and one for stress, the presets do not deliver it**, and on 17-Sep
both GBPUSD arms capped on the same side within hours and needed the same
manual intervention.

### The trigger question, unresolved

Not "at cap". Cap is a threshold, not a signal. Candidate: **at cap AND the
worst layer is far enough that its recovery is implausible** -- which is `p`
again, still unmeasured.

The operator's refinement, which is better than anything else proposed:
**if the ejection does not fill, revise only into a STABILISED market.** Not
elapsed time, not distance travelled. A range that has held for a while means
a bid one `add_pips` step below has been inside the traded range recently --
so the refill is plausible. **The stability is what makes the ejection worth
completing.** Needs a definition; measurable from the same M5 data as the
path study.

### What must happen before any of this is specced

1. **Redo the sweeps.** `roll_modes_cal_2026_09_17` covered 2 of 5
   pre-registered windows, the simulator is single-sided and has no guard
   model, and `exits_per_forced_close` was misdefined
   (`roll-at-cap-notes.md` s4). The results informed nothing and should not
   be cited.
2. **Settle the geometry question first (N7, N8).** If the ladder is the
   wrong shape for the market, ejection is treating a symptom. Test whether
   the arms should differ in `add_pips` or `InpMaxLayers` rather than only
   `exit_pips`.
3. **Measure `p`** -- conditioned on a ladder at cap, not unconditionally
   (the cancelled study, `roll-at-cap-notes.md` s3d).

### Current position

**Passive ejection is not ready to spec, and the case for it is weaker than
it looked on 2026-09-18.** It remains the only position-side lever, which is
why it survives at all. Gemini's deferral behind ADR-152 Phase 2 stands and
now has better reasons than the one it was given.

## 3. THE RULE, AND WHAT IT COSTS

    rest if  rank < K  OR  rank == depth - 1        // depth-1 = highest rank = most underwater

- **Depth 1:** rank 0 IS the highest rank. No change.
- **Depth 2:** both rest. One unit more than today. No middle exists yet.
- **Depth 3+:** rank 0 and the highest rank rest, everything between is held.
  One unit more than K=1 regardless of how deep the ladder goes. **Three
  layers is where a MIDDLE first exists to drop.**

So the cost is **at most one extra resting exit per side with depth >= 2**,
and it does not grow with depth. On the 2026-09-18 fleet that is roughly 8-10
units across all sides, against the ~31 that K=1 freed. Most of the K=1
benefit is kept.

## 4. THE SECOND BENEFIT -- EJECTION BECOMES A MODIFY

From `roll-at-cap-notes.md` s6a, an ejection's slot accounting is `K + H + 1`
per side: the `+1` is the NEW exit order created for the ejected layer.

**If the most underwater layer's exit is already resting, ejection is an
`OrderModify` of an existing order, not an `OrderSend` of a new one.** The
`+1` disappears and the guard cost is pre-paid.

That matters because of the 73-minute measurement (`roll-at-cap-notes.md`
s3a): an ejection that cannot obtain a guard unit does not happen. Pre-paying
guarantees the mechanism can fire at the moment it is wanted, which is
exactly when the guard is most likely to be saturated.

## 5. WHY IT IS NOT A ONE-LINE CHANGE

Today the predicates take a rank and return a boolean:

    bool Grind_ExitQRequired(const int rank) { return rank < Grind_ExitQK(); }
    bool Grind_ExitQAllowed(const int rank)  { return rank < Grind_ExitQK() + GRIND_EXITQ_H; }

They have no notion of the side's depth. The barbell needs `depth` as well as
`rank`, so both signatures change and so does every call site.

**And `Grind_ExitQRequired` is what I6 gates on** (`grind_recon.mqh:491`).
The queue and the invariant must agree on which ranks require coverage or
reconstruction halts the instance. They have to move together.

Same shape as the carry problem: the arithmetic is trivial, the care is in
keeping the queue and the invariant saying the same thing.

## 6. OPEN QUESTIONS

- **Does the barbell apply at every depth, or only above a threshold?** At
  depth 2 it means resting both, which is just K=2 for that side. Possibly
  fine; possibly it should engage only at depth >= 3 where a middle exists to
  drop.
- **What does I6 assert for the middle ranks?** Today coverage is required
  for `rank < K`. Under the barbell it must be required for rank 0 and the
  highest rank, and forbidden in between -- a two-sided condition rather than a
  prefix.
- **Interaction with the stale-offset fix** (merged `241a905`): a held middle
  layer that later becomes the highest rank would need its exit placed. That is
  the cancel/re-place path, which now clears its offset correctly, but the
  transition should be tested.
- **Does it change the K=1 decision at all?** K=1 was ruled on the basis that
  only rank 1 is forfeited. The barbell changes what is forfeited to "the
  middle", which is a different trade and may warrant re-stating to Gemini.

## 6a. FIXES NEEDED -- THE RUNNING LIST

Nothing here is specced or ratified. This is the list of things that must be
true before the barbell, or carry, can ship.

### F1. The most underwater layer's exit is not on the book

**What.** Today's prefix rule rests ranks `0 .. K-1`. At `K=1` that is the
layer NEAREST market. The MOST UNDERWATER layer carries the HIGHEST rank and
is the first thing dropped -- exactly the layer a passive ejection would act
on.

**Why it matters.** An ejection would have to `OrderSend` a fresh order at
the moment the guard is most likely to refuse it. On 2026-09-18 a
near-market entry waited 73 minutes for a guard unit
(`roll-at-cap-notes.md` s3a). An ejection that cannot obtain a unit does not
happen.

**Fix.** The barbell: `rest if rank < K OR rank == depth - 1`. Cost is at
most one extra resting exit per side at **depth >= 2**, and it does not grow
with depth (s3, s2a-ter). A middle to drop first exists at depth 3.

**Not a one-liner.** `Grind_ExitQRequired` and `Grind_ExitQAllowed` take a
rank and nothing else; they need depth. And `Grind_ExitQRequired` is what I6
gates on (`grind_recon.mqh:491`), so the queue and the invariant must change
together or reconstruction halts the instance (s5).

### F2. Held layers never accrue carry

**What.** `grind_carry.mqh:767` and `:775` skip any layer with
`exit_order_ticket == 0` when building the pass's work list. A layer in
purgatory is therefore never adjusted.

**Why it matters.** The layers that sit held longest are the ones that
accrue the most. When a held layer is promoted to rank 0 its exit is placed
at the raw formula, silently discarding every night of accrual. The economics
ADR-135b exists to preserve are lost precisely where they matter most.

**Fix shape, not yet specced.** The pass must iterate LAYERS, not resting
orders, and record the accrual per position ticket whether or not a broker
order exists. Placement must then read that store. **That is the same store
question as `carry-plan-gemini` step 2** -- Gemini ruled Option B, a separate
GV written only by the carry pass, and this makes that ruling more clearly
right: the store has to exist independently of any order.

### F3. Carry rates are zero

**What.** pipshed's carry table reads 0.000 for all eight symbols, long and
short, per night and per week, with `MULT` 0. Updated 2026-09-18 20:50, so
the mechanism runs and applies nothing.

**Why it matters.** Until the rates are populated the pass computes zero and
F2 is untestable in production.

**Fix.** Find where the rates are meant to be sourced and why they are empty.
Independent of F1 and F2, and the smallest of the three.

### Already fixed, for the record

The stale-offset defect -- an exit's stored offset surviving a cancel, and
the write guard failing to clear it on an unclamped re-place -- was measured
and fixed in `241a905` (`02_TRAPS`). It is on `main`, NOT yet deployed to the
VPS.

### Ordering

F3 first: it is independent, cheap, and tells us whether carry is worth
building at all. Then F2, because Gemini has already ruled its store design.
F1 last -- it is the least urgent and touches the invariant.

## 7. NOT YET DONE

Nothing. No ADR, no spec, no code, no ruling. This file exists so the idea
survives the weekend.

Line count: 1054
