This message has a line count at the bottom

# DESIGN MEMO -- ORDER PURGATORY: ACCOUNT SLOT BUDGET WITH EXIT PRIORITY

| | |
|---|---|
| Status | **DRAFT for review.** Not an ADR yet. Proposed number: ADR-151 |
| Author | Claude (lead engineer), 2026-09-16 |
| Operator | Khalid. Named the concept; accepts modestly more requests in exchange for no refusal storms |
| Evidence | `HANDOFF_2026-09-16.md` s1-2, `HANDOFF_2026-09-16b.md` (FOMC) |
| Source read | fxmatrix main `46b1749`, `ea/grind_engine.mqh`, `grind_api_counter.mqh`, `grind_quarantine.mqh` |
| Review path | Gemini ruling (design), then DeepSeek audit (order lifecycle, MANDATORY per ARCHITECT s2), then Cursor spec |

---

## 1. PROBLEM

The account allows **200 positions + pending orders combined**
(`ACCOUNT_LIMIT_ORDERS=200`, read 2026-09-16). The fleet has no concept of
this limit. Each instance places orders as if capacity were infinite.

When the book reaches 200, three failures follow, all observed on 2026-09-16:

1. **Exits are refused.** A fill converts an order into a position (count
   unchanged); the exit placed immediately after is the NEW order, so it is
   the one refused (retcode 10040, `duration_ms=0`). Layer goes I3_NAKED,
   quarantine cannot outlast the limit, instance halts. 12 halt events.
2. **Halted instances keep filling.** `Grind_HaltCritical` only sets a flag;
   resting entries stay at the broker and fill as untracked positions with
   no exit (two observed at 18:02Z).
3. **Refusals are retried every tick.** Entries and exits that fail are
   re-sent on the next tick with no backoff. Request counter 822 -> 3,414 in
   23 minutes.

Manual recovery showed the stable state: an instance with no resting
entries. Every reinit into a full book re-halted within minutes (3 of 3).

## 2. PRINCIPLE

**An exit must never be refused for want of a slot. An entry may always
wait.**

Entries are optional; missing one costs a possible scalp. Exits are not;
missing one halts the instance. So capacity is budgeted: entries only get a
slot when the account has headroom above a reserve kept for exits.
Entries that cannot be placed wait in memory -- "purgatory" -- and are
placed when room returns.

## 3. CURRENT BEHAVIOUR (from source)

  - Entry gates: `Grind_TryPlaceL0` (grind_engine.mqh ~449) and
    `Grind_EnsureAddNext` (~636) check `Grind_CanPlaceEntryLayer` (depth vs
    cap) and `Grind_CapAllowsEntry` (ADR-149 exposure cap). No capacity check.
  - Exit on fill: `Grind_HandleSideDealFill` (~833) places the exit
    immediately on an ENT fill. Good ordering, but no capacity awareness.
  - Tick order in `Grind_OnTickEngine` (~1026): L0 placement, then ADR-124
    recentre, then cap transition, **then** `Grind_RetryMissingExits`, then
    adds. **A missing exit is retried AFTER a new L0 has had the chance to
    take the slot in the same tick.**
  - `Grind_OrderSendCounted` (grind_api_counter.mqh ~76) increments the
    request counter on every `OrderSend`, including sends the terminal
    refuses locally. The fleet counter therefore over-states server
    requests during a storm.
  - Quarantine (grind_quarantine.mqh): 3000 ms and 3 checks, then halt.
    It has no notion of WHY the exit is missing.
  - Halt has TWO entry points, neither touching orders: the invariant path
    in `OnTick` (fxgrind.mq5 ~234) sets `g_grind_halted` directly after
    `Grind_QuarantineStep` returns HALT; `Grind_HaltCritical`
    (grind_engine.mqh ~376) sets it for engine-detected faults.
  - While QUARANTINED, `OnTick` (fxgrind.mq5 ~246) runs only
    `Grind_RetryMissingExits` and skips the engine: quarantine is already an
    exit-only mode. The budget generalises that idea to the whole fleet.
  - I8 (`Grind_ReconCheckPendingAddCorrupt`, grind_recon.mqh ~370) halts if
    `add_pending_ticket` is set but the order is gone. Any eviction must
    clear the tracker in the same pass as the cancel.

## 4. DESIGN

### 4.1 Reading capacity -- local, free, fleet-wide by construction

    free = AccountInfoInteger(ACCOUNT_LIMIT_ORDERS)
           - PositionsTotal() - OrdersTotal()

These are terminal-local calls: **no server request**. Every instance in the
terminal sees the same account totals, so no GlobalVariable coordination is
needed to know the count. If `ACCOUNT_LIMIT_ORDERS` returns 0 (unlimited),
the budget is disabled.

Race: several instances can read the same `free` in the same tick and all
act. The reserve (4.2) absorbs this; a refusal inside the reserve is handled
by 4.4, not by halting.

### 4.2 The budget rule

| Order class | Allowed when |
|---|---|
| Exit (EXT) | `free >= 1` |
| L0 or add (ENT) | `free > InpSlotReserve` |
| Modify / cancel / CloseBy | always (they do not consume a slot; CloseBy frees 2) |

`InpSlotReserve` is a new input. **Sizing is an open question (s7).**
Starting argument: one exit slot per instance that could fill in the same
burst. Tonight's worst burst was 5 halts in 3 minutes across 14 instances, so
a reserve between 10 and 16 is the plausible range.

The reserve is self-limiting: once entries stop being placed, fills slow,
exits keep slots, and scalps release capacity.

### 4.3 Purgatory -- deferred entries

When an entry is blocked by the budget, the instance does not send. It
records that the entry is deferred (side, layer index, target already
computed by existing logic) and re-evaluates on later ticks. Nothing about
the target calculation changes: L0 still follows ADR-123 place-once, adds
still follow `Grind_ComputeAddTarget`, recentre still follows ADR-124.

A deferred entry costs **zero requests** while waiting, because the check is
local. This is what ends the storm.

Telemetry: heartbeat gains `slots_free`, `entries_deferred_long`,
`entries_deferred_short`. Dashboard shows purgatory explicitly rather than
as a missing order.

### 4.4 Exit refused anyway (race inside the reserve)

If an exit send returns 10040:

  1. **Evict locally.** Cancel this instance's own resting ENT order that is
     furthest from market (an add before an L0). That frees one slot.
     Re-send the exit in the same pass.
  2. **If the instance has no resting ENT to evict**, raise a fleet flag
     (GlobalVariable `GRIND_SLOT_STARVED`, timestamped). Every instance that
     sees a fresh flag withdraws its own furthest ENT order and defers it.
     Cleared when `free > InpSlotReserve`.
  3. Record `SLOT_REFUSED` / `SLOT_EVICT` to ea_events.

Step 2 is the only new cross-instance mechanism. It uses the existing GV
pattern from the cap (ADR-149) and must obey ARCHITECT s13 (TimeTradeServer
for staleness).

Request cost of an eviction: 1 cancel + 1 later re-place. Tonight's
alternative was hundreds of refused sends per minute.

### 4.5 Quarantine interaction -- NEEDS A RULING

Today a slot-refused exit and a genuinely lost exit look identical to
quarantine (I3_NAKED). Options:

  - **(a) Unchanged.** Eviction usually wins inside 3000 ms; if not, halt as
    today. Simplest; keeps "halt, don't repair" pure.
  - **(b) Extended window only when the last send for that layer's exit
    returned 10040** (e.g. up to 60 s while eviction runs), then halt.

Recommendation: **(a) first**, measure, revisit. (b) weakens an invariant and
should not be adopted on reasoning alone.

### 4.6 Halt cancels own entries

On any halt -- BOTH entry points in s3 -- the instance cancels its own resting
ENT orders (never EXT).
This removes the untracked-fill failure (F2 of 16b) and turns every halt into
the "parked" state automatically. Exits stay; locked pairs net on reinit as
observed.

Open point: cancelling during a halt is a trading action by a halted
instance. It is narrow (cancel only, own ENT only) but it is a change to the
halt contract.

### 4.7 Tick ordering

Move `Grind_RetryMissingExits` to run **before** L0 placement, recentre and
adds in `Grind_OnTickEngine`. Independent of the budget, this stops an
instance's own entry from beating its own exit to a slot.

### 4.8 Reinit

No special path. Reconstruction runs as today; entries then pass through the
budget like any other. A reinit into a full book comes back running with
entries in purgatory, instead of placing them and re-halting.

### 4.9 Backoff on refusals

Any 10040 on an ENT send marks that entry deferred (4.3); it is not
re-sent until the budget allows. Any other refusal keeps existing behaviour.

## 5. WHAT DOES NOT CHANGE

  - Geometry, targets, exit distances, ADR-123/124 behaviour.
  - The ADR-149 exposure cap. Cap = how much exposure; budget = how many
    tickets. Both gate entries; the budget check sits beside
    `Grind_CapAllowsEntry`.
  - Invariants and reconstruction (unless 4.5(b) is ruled in).
  - Exit placement on fill.

## 6. TESTS (outline for the Cursor spec)

The order test harness (`g_grind_order_test_*`) needs a mocked slot count and
a mocked 10040 retcode.

  1. Entry blocked at `free <= reserve`; no send recorded; deferred flag set.
  2. Entry placed when `free` rises above reserve; deferred flag cleared.
  3. Exit placed at `free == 1` while entries are blocked.
  4. Exit 10040 with a resting add: add cancelled, exit re-sent, one of each.
  5. Exit 10040 with no resting ENT: `GRIND_SLOT_STARVED` set; peer instance
     withdraws its furthest ENT.
  6. Halt cancels own ENT orders, leaves EXT orders.
  7. Tick order: missing exit retried before L0 on the same tick.
  8. `ACCOUNT_LIMIT_ORDERS == 0` disables the budget.
  9. No send storm: 1,000 ticks at a full book produce zero ENT sends.
 10. Suite baseline count reported (02_TRAPS: count is a baseline).

## 7. OPEN QUESTIONS FOR THE RULING

  1. `InpSlotReserve` value and whether it is fleet-wide or scales with
     instance count.
  2. Fleet eviction (4.4 step 2): adopt now, or local eviction only in v1?
  3. Quarantine: (a) unchanged or (b) extended window on 10040 (4.5).
  4. Halt contract change (4.6): acceptable?
  5. **Fairness.** Deep ladders hold many exit slots; the budget protects
     them. Shallow crosses will be the instances whose entries wait. Is that
     acceptable, or should the reserve be shared per instance?
  6. Should the request counter distinguish local refusals from server
     requests (s3), given FTMO's daily limit?

## 8. RISKS

  - Deferred entries reduce harvest when the book is full. Accepted by the
    operator: trading at reduced capacity beats halting.
  - GV flag staleness or a crashed instance could leave `GRIND_SLOT_STARVED`
    set. Mitigation: timestamp and expiry.
  - Eviction races between two instances cancelling for the same slot.
    Cost is one extra cancel; no correctness risk.
  - Budget reads `OrdersTotal()`, which includes any manual orders the
    operator places. Correct by design: they consume real slots.

## 9. NOT IN SCOPE

  - Lowering `max_layers` (HANDOFF_2026-09-16 s7). Complementary: it reduces
    how fast the book fills; this memo handles what happens when it does.
  - Closing or resetting deep layers.
  - Retiring or adding instances.

Line count: 243
