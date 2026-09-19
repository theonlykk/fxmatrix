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

**The deepest layer is therefore the FIRST thing dropped**, because rank is
ordered nearest-to-market and the deepest layer is furthest away.

That is the layer we most want reachable. It is the ejection candidate, and
it is the one that will sit unexited longest.

**Proposal: rest rank 0 PLUS the deepest layer. Drop the middle.** A barbell
rather than a prefix.

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
| sell limit | 102 | L0 exit, deepest layer |
| buy limit | 90 | next add |

**The operator's point: at this depth we are not remotely constrained.** Two
positions, two or three orders. Holding L0's exit saves one unit we do not
need, and costs us the order we would most want working.

## 3. THE RULE, AND WHAT IT COSTS

    rest if  rank < K  OR  rank == depth - 1

- **Depth 1:** rank 0 is also the deepest. No change.
- **Depth 2:** both rest. One unit more than today.
- **Depth 3+:** rank 0 and the deepest rest, middle held. One unit more than
  K=1 regardless of how deep the ladder goes.

So the cost is **at most one extra resting exit per side with depth >= 2**,
and it does not grow with depth. On the 2026-09-18 fleet that is roughly 8-10
units across all sides, against the ~31 that K=1 freed. Most of the K=1
benefit is kept.

## 4. THE SECOND BENEFIT -- EJECTION BECOMES A MODIFY

From `roll-at-cap-notes.md` s6a, an ejection's slot accounting is `K + H + 1`
per side: the `+1` is the NEW exit order created for the ejected layer.

**If the deepest layer's exit is already resting, ejection is an
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
  deepest, and forbidden in between -- a two-sided condition rather than a
  prefix.
- **Interaction with the stale-offset fix** (merged `241a905`): a held middle
  layer that later becomes the deepest would need its exit placed. That is
  the cancel/re-place path, which now clears its offset correctly, but the
  transition should be tested.
- **Does it change the K=1 decision at all?** K=1 was ruled on the basis that
  only rank 1 is forfeited. The barbell changes what is forfeited to "the
  middle", which is a different trade and may warrant re-stating to Gemini.

## 7. NOT YET DONE

Nothing. No ADR, no spec, no code, no ruling. This file exists so the idea
survives the weekend.

Line count: 126
