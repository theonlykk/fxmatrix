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

## 2a-bis. THREE LAYERS -- WHERE THE BARBELL FIRST DOES ANYTHING

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

**Three layers is the first depth at which rank 0 and the highest rank are
different layers.** At one or two layers there is no middle, so the barbell
and the prefix give the same answer.

Guard cost: 3 positions + 3 orders + 1 reserved for the add's exit = 7, against
6 under the prefix. One unit buys a working exit on the layer we would eject.

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

## 3. THE RULE, AND WHAT IT COSTS

    rest if  rank < K  OR  rank == depth - 1        // depth-1 = highest rank = most underwater

- **Depth 1:** rank 0 IS the highest rank. No change.
- **Depth 2:** both rest. One unit more than today. No middle exists yet.
- **Depth 3+:** rank 0 and the highest rank rest, everything between is held.
  One unit more than K=1 regardless of how deep the ladder goes. **Three
  layers is where the barbell first does anything.**

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

## 7. NOT YET DONE

Nothing. No ADR, no spec, no code, no ruling. This file exists so the idea
survives the weekend.

Line count: 341
