# ADR-129: Stale-state duplicate L0 and wrong-layer exit

Status: Proposed
Date: 2026-09-11

## Context

Two live incidents share the same mechanism (UTC):

**Incident A, EURUSD_OPT 2026-09-10**
- 14:25:45.174 short L0 #538969489 FILLS at 1.16231
- 14:26:09.431 NEW short L0 sent at 1.16277 (fill not yet processed)
- 14:35:50.738 stray #539592770 FILLS at 1.16282
- 14:35:50.739 exit sent at 1.16161 -- the FIRST layer's price; I5 halt

**Incident C, AUDCHF_OPT 2026-09-11**
- 12:30:11.996 short L0 #539601737 FILLS at 0.58431
- 12:30:14.255 NEW short L0 sent at 0.58501 (fill not yet processed)
- 12:30:17 exit for the 0.58431 layer placed (fill processed only now)
- 12:42:35.886 stray #540370366 FILLS at 0.58501
- 12:42:35 second exit at 0.58381 -- the FIRST layer's price; I5 halt

Source at d98804c:
- `Grind_TryPlaceL0`: if the tracked L0 cannot be selected, it zeroes the
  ticket and places a new L0. The order may simply have FILLED with its
  transaction not yet processed.
- `Grind_EnsureAddNext`: same pattern for the add pending.
- ENT branch of `Grind_HandleSideDealFill`: finds the layer with
  `Grind_FindLayerByIndex`, which returns the FIRST layer with that index;
  `Grind_TryPlaceExitForLayer` overwrites `exit_order_ticket` unconditionally.
- Nothing cancels an L0 pending on a side which already has layers.

## Decision

1. **P2 (narrowed) -- filled vs gone.** When a tracked pending (L0 or add)
   cannot be selected, check `Grind_SelectOurPosition(ticket, magic)`. In MT5
   a position's ticket equals the ticket of the order that opened it. If that
   position exists, the order FILLED and its transaction is pending: keep the
   ticket and place nothing this tick. Otherwise clear and proceed as today.
   **RULING 1:** This replaces order-history lookup with a bounded wait. No
   history call, no timer, no stall: if the transaction never arrives, the
   position has no exit, and I3 (quarantine, then halt) catches it. The
   remaining window (order gone and position not yet visible) falls back to
   today's behaviour and is covered by P4.

2. **P3 -- exit goes to the position that filled.** In the ENT branch, find
   the new layer with `Grind_FindLayerByPosition(side, position_id)`.
   `Grind_TryPlaceExitForLayer` returns false and places nothing if the layer
   already has an exit order or exit position.
   **RULING 2:** No explicit protective halt. If a duplicate index does fill,
   both positions now have their own exits, and the existing I5 invariant
   (non-quarantinable) halts on the next tick.

3. **P4 -- cancel a stray L0 on a side with layers.**
   (a) ENT branch: after placing the exit, if the fill is an L0 (`c_layer == 0`)
       and the side still tracks a DIFFERENT L0 pending, cancel that pending
       and clear the ticket on success. Exit first, because a cancel can block.
   (b) Engine: `Grind_ReconcileStrayL0` at the top of `Grind_OnTickEngine`
       after the guards. If depth is 0 or no L0 is tracked: do nothing. If the
       tracked L0 is selectable: cancel it, clear on success. If not selectable
       and a position with that ticket exists: keep the ticket. Otherwise clear.
   **RULING 3:** Reconstruction is NOT changed. A stray L0 adopted on reattach
   is cancelled by (b) on the first engine tick.
   **RULING 4:** DeepSeek's "cancel add pending on an empty side" is dropped;
   `Grind_EnsureAddNext` already cancels those through its stale-label check.

4. No new invariant targets a stray pending; P4 is a reconciler only, so it
   does not collide with any invariant.

## Alternatives considered

1. **Order-history lookup with bounded wait.** Rejected: adds history API
   coupling and stall risk; position-ticket check is immediate and bounded.

2. **Explicit protective halt after duplicate fill.** Rejected: I5 already
   halts non-quarantinably when duplicate indices exist; P3 ensures both
   positions are covered first.

3. **Changing reconstruction to reject stray L0 adoption.** Rejected: duplicates
   one code path; engine reconcile on first tick achieves the same outcome.

4. **Blind empty-side add cancel.** Rejected: conflicts with existing
   `Grind_EnsureAddNext` stale-label cleanup on flat sides.

## Consequences

- A stray L0 is still sent in the narrow window where the order has gone and
  the position is not yet visible, and is then cancelled by P4.
- A duplicate that fills before the cancel still halts on I5, but with both
  positions covered by their own exits.
- Operator recovery: close the later duplicate position and delete its exit,
  then reattach.
- P2-P4 do not change quarantine, reconstruction, or invariant definitions.

## Evidence

- EURUSD_OPT Incident A (2026-09-10): duplicate L0 at 1.16277, stray fill
  1.16282, wrong-layer exit at 1.16161.
- AUDCHF_OPT Incident C (2026-09-11): duplicate L0 at 0.58501, stray fill
  0.58501, wrong-layer exit at 0.58381.
- DeepSeek audit: P2 AMEND, P3 KEEP, P4 AMEND.

## Tests

SB1-SB9 in `fxgrind_tests.mq5`:
- SB1: TryPlaceL0 keeps ticket when position exists (filled, txn pending).
- SB2: TryPlaceL0 replaces gone ticket (regression).
- SB3: EnsureAddNext keeps ticket when add position exists.
- SB4: ENT exit goes to filled position, not first index match.
- SB5: ENT L0 fill cancels stray tracked L0 after exit placed.
- SB6: Reconcile cancels selectable stray L0 on side with layers.
- SB7: Reconcile keeps filled-position ticket; clears gone ticket.
- SB8: Reconcile leaves legitimate empty-side L0 (regression).
- SB9: TryPlaceExitForLayer refuses to overwrite existing exit.
