# DeepSeek Phase 1 Follow-Up — Verification of `last_exit_price` Fix (ADR-091)

**This is NOT a new full audit.** This is a narrow verification request on your own Section 2b finding from the original Phase 1 audit. A quick yes/no-with-reasoning on the two questions below is sufficient — you do not need to re-examine the rest of the ADR or repeat prior findings.

---

## 1. Your original finding (Section 2b, quoted from your own report)

> **Stale-state bug (FATAL):** The simulation (`grid_sim_v7_real_signal.py`) clears `last_exit_price = None` only when a reload add fires. It does not clear `last_exit_price` when a new Layer 0 is entered from flat after a full pod exit. This means that after a complete pod closure, the next pod's first add(s) will incorrectly use the reload path (flat 9-pip or depth-scaled) instead of the first-time widening curve.

> **Circular confirmation risk:** The state variable `last_exit_price` is set after any exit, and cleared after a successful reload. If an adverse sequence of fills/exits causes a reload to be attempted but never filled (price runs away), `last_exit_price` stays set. This could compound through multiple exit cycles without a successful reload, leading to persistent misclassification as reloads for first-time adds. The simulation does not stress-test this.

This was independently confirmed against source by Cursor (direct code trace, not inference), and measured empirically: the new-pod-after-full-exit case fires in roughly 9-16% of pod restarts across both historical windows and all three bias modes (seeds 0-4 sample). Not a rare edge case.

---

## 2. The fix as applied

One line added to the flat-entry block (`grid_sim_v7_real_signal.py`, lines 177-183):

```
if filled_dir is not None:
    layers.append(Layer(entry_price=fill_price, direction=filled_dir,
                          exit_target_raw=fill_price + filled_dir * exit_price_dist))
    current_add_pips = ADD_PIPS_FLOOR
    last_exit_price = None   # NEW: clears stale anchor from any previous pod
    total_trades += 1
    max_layers = max(max_layers, 1)
```

The two pre-existing assignment points are unchanged:
- `last_exit_price = closed.entry_price` set on any layer exit (unchanged)
- `last_exit_price = None` cleared on a successful reload-add fill (unchanged)

Two unit tests were added and pass: one constructing the exact full-pod-exit then new-L0-entry then first-add scenario, asserting first-time widening logic is used, not the reload branch; one asserting the production flat-entry block literally contains the new reset line.

The complete current file is attached below (`grid_sim_v7_real_signal.py`) for direct inspection, not a diff summary.

---

## 3. Two questions

**Question 1 - does this fix correctly and fully close the specific defect you identified?**
Does clearing `last_exit_price = None` at the point of a new Layer-0 fill (shown above) fully address the new-pod-after-full-exit mechanism you described, or does something about that mechanism remain unaddressed by this specific fix?

**Question 2 - does this fix also address the separate "circular confirmation risk" you flagged?**
You described a distinct scenario: a reload is attempted (state still shows `last_exit_price is not None`, `layers` non-empty) but never actually fills, price runs away before reaching the reload target, potentially compounding across multiple subsequent exit cycles without ever successfully reloading. Does the applied fix (which only resets `last_exit_price` on a new Layer-0 entry from flat) address this scenario at all, given it's a different trigger condition (partial-stack reload-never-fills, not full-pod-exit-to-flat)? If this remains open:
- Is it a distinct defect requiring its own fix before the next full n=500 rerun can be trusted, or
- Is it a lower-priority, non-fatal concern that doesn't invalidate a rerun based on today's fix alone?

---

## 4. Files provided

Deliberately a lean package for this narrow verification, not the full original file set. The two documents below are sufficient to answer both questions; nothing else was needed, to avoid diluting focus on the specific claim being checked.

- Your own original Phase 1 audit report in full (attached under DOCUMENTATION) so you can check your own prior reasoning directly, not our paraphrase of it.
- `grid_sim_v7_real_signal.py`, current/fixed version, in full (attached under CODE TO AUDIT).
