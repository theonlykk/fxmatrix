This message has a line count at the bottom

# ADR-151 -- Order purgatory: exit queue and commitment guard

| | |
|---|---|
| Status | **ACCEPTED** (Gemini: approved with amendments, 2026-09-16). Phase A implemented under this ADR; Phase B deferred |
| Date | 2026-09-16 |
| Design record | `docs/architecture/MEMO_2026-09-16_order_purgatory.md` (rev 5, `38c358e`) |
| Red team | DeepSeek R1: rev 1 `e83b52f`, rev 3 `9f67f0f`, rev 4 `96af7b1` (premise survives) |
| Ruling | Gemini response to `prompts/gemini_order_purgatory_rev5.md`, 75 lines, approved with amendments |
| Supersedes | nothing; amends invariant I3/I1/I6 scope and halt behaviour |

## Context

The FTMO account allows 200 positions + pending orders combined. At 200 the
terminal refuses the exit placed after a fill (10040); the layer goes I3 naked
and the instance halts. 2026-09-16 FOMC: 14+ halts, untracked fills on halted
instances, 822 -> 3,414 requests in 23 minutes, reinits that re-halted.

Operator insight: on a ladder, most resting exits cannot fill until nearer
exits fill first. They hold slots and do no work.

## Decision

1. **Exit queue.** Per side, layers ranked by entry price nearest to market
   (longs ascending, shorts descending, ties lower layer_index). Ranks
   0..K-1 MUST have a live exit; K..K+H-1 MAY; beyond MUST NOT. Held exits are
   released as front exits fill and CloseBy nets them.
2. **Commitment guard.** Exits allowed at `free >= 1`. Entries allowed at
   `free - resting_ent >= 2 + margin`, evaluated and sent inside a fleet-wide
   GlobalVariable lock with staleness recovery. One entry send per instance
   per tick.
3. **Release pricing.** Released and retried exits are recomputed from the
   exit formula and clamped passive with the existing carry clamps. A clamped
   price stores its applied shift with `Grind_CarryShiftSet` and a release
   marker GV that exempts it from `Grind_CarryShiftWithinBound`. I6 stays
   strict.
4. **Missed exit fill on a hold cancel** is resolved from deal history by
   order ticket (`DEAL_ORDER`) with a direction check. No comment search.
5. **Trim before protect.** Excess live exits are cancelled in `OnInit` after
   reconstruction, in the quarantined branch of `OnTick`, and first in the
   engine tick.
6. **Halt cancels own entry orders** (never exits), on every halt path.
7. **Invariants.** I3 exit coverage only for ranks < K. I1 and I6 only for
   layers that have an exit. Held layers' `exit_target` is populated from the
   formula, never 0.0.
8. **Shift GV hygiene.** Shift and release-marker GVs are deleted only when
   their position no longer exists (fleet-safe), and when a layer is netted.

## Constants (compiled, fleet-wide; Gemini Q1 amended)

| Constant | Value | Source |
|---|---|---|
| `GRIND_EXITQ_K` | 2 | Gemini Q1 |
| `GRIND_EXITQ_H` | 1 | Gemini Q1 |
| `GRIND_SLOT_MARGIN` | 4 | Gemini Q1 |
| `GRIND_SLOT_LOCK_STALE_MS` | 10000 | Gemini Q3 required staleness; 1000 ms rejected (lock spans an OrderSend) |

Compiled constants, not inputs: an input is per chart and cannot be enforced
fleet-wide.

## Phases

**Phase A (this ADR, implemented now): carry pass disabled.** All 18 presets
set `InpEnableCarryPass=false`. Exit target = formula. `OnInit` refuses to
start if the carry pass is enabled.

**Phase B (deferred, before carry is ever enabled):** carry-aware target from
the swap ledger; target promotion with `InpRankDeadbandPips` (Gemini Q1: 10);
reconstruction of carry-shifted held targets.

## Gemini amendments -- disposition

| Item | Ruling | Disposition |
|---|---|---|
| Q1 values fleet-wide | K=2, H=1, margin 4, deadband 10 | Accepted; compiled constants (inputs cannot be fleet-enforced); deadband Phase B |
| Q2 release marker | Marker, I6 strict | Accepted |
| Q3 lock staleness, 1000 ms | Required | Staleness accepted; 1000 ms rejected -- the lock is held across a synchronous OrderSend that can exceed 1 s, and stealing mid-send breaks mutual exclusion. 10000 ms, lock value = holder's `GetTickCount64()`, steal by CAS on the observed value |
| Q4 cancel ENT on halt | Yes | Accepted |
| Q5 trim outside engine | Acceptable | Accepted |
| Q6 P 12 -> 8 | Follow-on ADR | Accepted |
| Q7 ~28-slot reservation | Accept | Accepted |
| R5 marker serialisation | Specify | Accepted: separate GV `GRIND_CARRY_RELEASE_<position_ticket>` = 1.0 |

## Found during ruling verification

`Grind_CarryPruneShiftGvs` (grind_carry.mqh ~771), called in `OnInit`
(fxgrind.mq5 ~135) and at carry pass begin, deletes every
`GRIND_CARRY_SHIFT_` GV whose position is not in THIS instance's book --
including other instances'. Dormant while no shift GVs exist; fatal once
release shifts exist (any reinit would delete peers' shifts and I6 would halt
them). Fixed in Phase A (decision 8).

## Consequences

  - Exits no longer refused for capacity except in exit-timing races beyond
    the margin.
  - Entries wait when the account is committed; harvest reduced at high usage.
  - About one extra cancel per add fill beyond K+H.
  - A dead lock holder blocks fleet entries for at most 10 s.
  - Residual: an entry can fill between a halt and its cancel; halted
    instances ignore fills; that position needs a manual close.

## Follow-ons

  - Layer cap P: majors 12 -> 8 (separate ADR, I7 migration).
  - Phase B carry-aware queue.
  - Heartbeat fields for slots and held exits (pipshed).

Line count: 111
