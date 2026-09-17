This message has a line count at the bottom

# TO GEMINI -- returning the Q4 ruling with evidence: ADR-152a should be folded
# into ADR-152, and the placement mechanism should change

Provenance: ADR-152a draft `7eb95a9`; DeepSeek R1 teardown of it, brief
`e0e9cf2`, response `bbdf464` (373 lines); Claude verified every load-bearing
claim below against EA source at `c39fb84`.

## 1. WHAT YOU RULED, AND WHY I AM COMING BACK

Q4 ruling: extract A3 (same-tick placement after a fill) into a prerequisite
ADR, prove it stable in production, then ship entry purgatory. The reasoning --
do not bundle a fill-path timing change with order-withholding logic -- is
sound, and I still accept it as a principle.

I drafted ADR-152a to that ruling. The teardown then showed the prerequisite
does not deliver the benefit it was extracted for, and introduces a new defect
of exactly the kind ADR-152 exists to remove. Both findings are verified.

## 2. FINDING 1 (fatal): the flag does not remove the latency

ADR-152a D1/D4: the fill handler sets a per-side due flag and sends nothing;
`Grind_OnTickEngine` services it first on the next tick.

That reorders work INSIDE the next tick. It does not remove the tick boundary.
The verified repro that motivated A3 is: add fills at 1.1000, next target
1.0990, price falls to 1.0985 BEFORE the next tick. With the flag, the add is
still placed after that move, and `Grind_Adr013ClampBuy`
(grind_pure.mqh:149-161) then prices it at `bid - min_dist` ~1.0984. The fill is
missed either way. ADR-152a fixes the ordering, not the latency.

## 3. FINDING 2 (fatal): servicing due adds first starves L0

ADR-152a D2 services due adds before L0 placement. Both paths share
`Grind_SlotEntryAllowed` (grind_exitq.mqh ~161) inside the same lock.

Repro: `used = 193`, `resting_ent = 0`. A long due add (far from market) is
serviced first: 193 <= 194, allowed; `used` becomes 194 and `resting_ent` 1. The
flat short side's L0, which is AT market, is then refused (195 > 194).

That is the purgatory defect reproduced inside the prerequisite: a far add
consuming the last guard units ahead of a near-market entry. It also contradicts
ADR-152a's own D6 claim that L0 is unchanged.

## 4. THE PREMISE THAT WAS WRONG IN MY DRAFT

D4 said "no OrderSend from `OnTradeTransaction`". **Exits are already sent from
there**: `Grind_HandleSideDealFill` calls `Grind_ExitQManageSide` in the same
event (grind_engine.mqh ~1008). So sending from the transaction handler is not a
new class of risk.

The real objection is narrower and specific: entries take
`Grind_SlotLockAcquire` (grind_exitq.mqh:173-198), which retries up to
`GRIND_SLOT_LOCK_MAX_RETRIES = 50` times with `Sleep(1)`. Blocking the
transaction thread for up to ~50 ms would delay exit placement for every other
deal in the same burst. Exits do not take the lock at all.

## 5. REVISED MECHANISM (proposed)

**Try once, non-blocking, in the fill handler; defer only on contention.**

    on ENT fill, after Grind_ExitQManageSide:
      if (single GlobalVariableSetOnCondition attempt succeeds)   // no Sleep
          evaluate Grind_SlotEntryAllowed; place the add; release
      else
          set the due flag; the next tick services it

- Places the add AT FILL TIME in the common case, which is what the repro needs.
- Adds one GV operation plus at most one OrderSend to a handler that already
  performs an OrderSend for the exit.
- Never blocks: contention costs one failed GV write, then the existing
  next-tick path.
- The guard is never bypassed; a refused add simply is not placed.
- L0 priority is preserved by ADR-152's reserved band (A2), not by ordering
  inside the tick, which removes Finding 2 entirely.

## 6. RECOMMENDATION

Fold A3 into ADR-152 with the revised mechanism, for three reasons:

1. **No standalone benefit.** Before purgatory, adds already rest; the only case
   ADR-152a improves is two entries contending in one tick, where it can also
   double per-tick sends (teardown T-2) and starve L0 (Finding 2). Held adds are
   what make fill-time placement matter, and they arrive with ADR-152.
2. **Shared safety argument.** The reserved band, the guard arithmetic, the flag
   lifecycle (quarantine, halt, reinit -- teardown T-3) and lock pressure under
   saturation (T-6) are one design problem. Splitting it produced a prerequisite
   whose ordering choice was wrong precisely because the band did not exist yet.
3. **Your isolation principle is preserved differently.** ADR-152 ships in two
   phases: Phase 1 = fill-time placement + reserved band + telemetry, no
   withholding (behaviour identical to today apart from placement timing);
   Phase 2 = the horizon itself. The fill-path change is still proven in
   production before any order is withheld, which was the point of Q4.

## 7. WHAT I NEED FROM YOU

Q4-bis. Accept the fold, with the two-phase rollout in s6.3 as the substitute
        for a separate ADR?
Q7.     Is the non-blocking single-attempt lock acceptable in the transaction
        handler, given exits already send there and the attempt cannot block?
Q8.     If you still want a separate ADR, it must either accept that the
        next-tick delay remains (in which case it buys almost nothing), or
        adopt s5 anyway -- in which case the fill-path risk is identical to
        folding it. Which do you prefer?

Line count: 107
