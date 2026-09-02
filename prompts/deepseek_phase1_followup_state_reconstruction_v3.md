# Phase 1 Follow-up — Does v3 Close the Blocking Findings?

This is a targeted follow-up to a Phase 1 audit that returned a
BLOCKING verdict on the previous version of this design (v2). This is
not a request to re-audit from scratch — you already found the real
problems. This is a request to verify whether v3, attached below,
actually closes each one, or whether the fixes introduce new gaps.

## Your own bottom-line list from the prior audit, and where v3 claims to address each

1. **Exit-order matching fallback could place duplicates** — v3 §1.2
   replaces timestamp-primary matching with a full enumerate-and-match
   requirement across all pending exit orders vs. all open positions;
   `exit_ticket = 0` / `NEEDS_PLACE` is now only valid when zero
   candidate orders exist at all, not when matching merely fails.

2. **L0 ticket reconstruction was missing entirely** — v3 §1.4 adds it,
   using comment-based identification (`"V2_L0"`) since there's no
   separate magic, per your finding.

3. **In-flight CloseBy states weren't handled** — v3 §0 adds a
   pre-check that runs before any other logic: any open position
   carrying exit magic forces an immediate halt on that side.

4. **`current_add_pips` isn't a pure function of depth; `last_exit_valid`
   isn't just "most recent close"** — v3 §2.2 and §2.3 replace the
   accumulator-only approach with explicit state-machine replay of
   append/removal events, tracking `WidenRatio` compounding and
   top-of-stack-only removal for `last_exit_valid`, per your findings.

5. **CloseBy/exit-magic handling needed two-track reconciliation** —
   v3 §2.1 splits anchor-finding (entry-magic volume only) from layer
   lifecycle tracking (closed at exit-magic `DEAL_ENTRY_IN`, not at
   `DEAL_ENTRY_OUT_BY`; matched via `DEAL_POSITION_ID` not `DEAL_MAGIC`).

6. **Ambiguity detection was a judgment call, not a checklist** — v3 §4
   is your ~11-item list, adopted directly, with one addition (item 7's
   explicit flag when the ticket-ascending tie-break itself feels
   insufficient rather than silently applying it).

7. **Reconstruction needed to be read-only until validated** — v3 §1.5
   states this explicitly: no calls to `AppendLayer`/`RemoveLayerAt`
   or any side-effecting function during reconstruction; cap GV
   publish and live order actions happen only after §5 validation
   passes.

8. **Partial fills and input drift weren't ambiguity triggers** — v3
   §1.6 and checklist item 8 add this.

Also addressed: Part C (cap GV publish sequencing, §3) now has
concrete proposed rules for the permissive-zero cross-instance risk
you flagged, explicitly marked as a proposal needing sign-off rather
than a settled answer — check whether the proposal itself is sound,
not just whether something was written there.

## What to actually check

For each of the 8 items above: does v3's fix actually close the gap,
or does it just relocate the problem? In particular:

- Does §1.2's "unique bijective assignment" requirement have its own
  failure mode you can find — some case where a wrong-but-unique
  assignment is possible?
- Does §2.1's two-track split correctly handle every CloseBy-related
  deal type, or is there a deal sequence that breaks the
  `DEAL_POSITION_ID` matching?
- Does §3's proposed "reserved sentinel GV state" for failed
  reconstruction actually solve the permissive-zero problem, or does
  it just move the race condition somewhere else?
- Is §4's checklist actually exhaustive now, or is there a broker
  state you can construct that satisfies none of the 11 triggers but
  still shouldn't be trusted?

No implementation code in your response. If v3 still shouldn't go to
Gemini, say so plainly and explain what's still missing — a
false-positive "looks fixed" verdict here is worse than another
BLOCKING result.

---

# State Reconstruction Engine — Design Sketch v3 (revised post-Phase-1)

Status: REVISED — addresses all 8 items from DeepSeek's Phase 1
blocking verdict plus the additional findings (L0 ticket omission,
in-flight CloseBy, read-only discipline, input drift). Not yet
re-audited. Not reviewed by Gemini yet.

---

## 0. Pre-check — CloseBy remnant detection (runs before anything else)

New, per Phase 1 finding: if an exit limit already filled but the
CloseBy retry hasn't yet succeeded, broker state shows an open
entry-magic position *and* an open exit-magic hedge position
simultaneously, with no pending exit order for that layer (it already
filled). Part A as originally written would misread the entry-magic
position as a normal live layer and place a redundant exit against it.

**Rule:** before any other reconstruction logic runs, scan open
positions for this side's **exit magic**. If any exist, halt this
side immediately via the existing orphan guard. This is a hard
pre-condition, not folded into the general ambiguity checklist below
— it must be checked first because it changes the meaning of
everything else on the book. Dedicated CloseBy-remnant reconstruction
is out of scope for this revision; halting is the correct conservative
behavior until that's built separately.

## 1. Hot state reconstruction (Part A, revised)

Applies only once Section 0 finds no exit-magic positions on this
side.

**1.1 — Layer positions and order.** Enumerate open positions by
entry magic + symbol. Sort by `POSITION_TIME` ascending; ticket
ascending as the deterministic tie-break for identical timestamps.
Assign as layer array indices 0..n-1. Original `open_depth` (the
depth at which a layer was first filled) is not recoverable from
current state and is telemetry-only — acknowledged as an accepted
gap, not a blocker.

**1.2 — Exit ticket assignment (corrected).** Timestamp matching
alone is unreliable — retries and cancel-and-replace paths produce
exit orders with later setup timestamps than their position's open
time, so "no timestamp match" does not mean "no exit order exists."
Corrected procedure:

- Enumerate all pending exit-magic orders for this side.
- Enumerate all open entry-magic positions for this side (from 1.1).
- Attempt a unique, unambiguous bijective assignment between them —
  not primarily by timestamp, but requiring each exit order to
  plausibly belong to exactly one position (correct direction,
  correct symbol, and where volume is available, matching volume).
- If every open position gets exactly one exit order and every exit
  order matches exactly one position: assign and proceed.
- If assignment is not unique (any position could pair with more than
  one order, or vice versa): this is now an explicit ambiguity trigger
  (§4) — halt, do not guess.
- **Only** if a position has genuinely zero candidate exit orders at
  all (not "zero after failing to match" — zero after enumerating
  everything) is `exit_ticket = 0` with `NEEDS_PLACE` fallback
  appropriate. This was the actual bug in v2: leaving `exit_ticket = 0`
  when a real, valid exit order existed but wasn't timestamp-matched
  caused `NEEDS_PLACE` to place a duplicate.

**1.3 — Add/reload ticket (corrected).** There is no separate
add/reload magic in the source — v2's design was factually wrong on
this point. All entry-side pending orders share the entry magic;
they're distinguished by comment: `"V2_L0"` for the L0 order,
`"V2_Add"` / `"V2_Reload"` for the add/reload order. Reconstruct by
scanning pending entry-magic orders and matching on comment, not a
nonexistent magic value.

**1.4 — L0 ticket (new — omitted entirely in v2).** If the stack is
empty (no open layers) and a pending entry-magic order with comment
`"V2_L0"` exists, reconstruct it as `g_long_l0_ticket` /
`g_short_l0_ticket`. Leaving this unreconstructed causes `OnNewBar` to
place a second L0 order without cancelling the first — the same class
of duplicate-order bug as 1.2, just on the entry side instead of exit.
A pending L0 order found while the stack is *non-empty*, or a pending
add/reload order found while the stack is *empty*, is not a
reconstruction target — it's an ambiguity trigger (§4).

**1.5 — Read-only discipline (new).** `AppendLayer` / `RemoveLayerAt`
in the live code have side effects beyond array updates: placing exit
orders, cancelling tickets, publishing cap GVs, pushing telemetry.
Reconstruction must **not** call these functions. It builds the layer
array and ticket state directly, in memory, read-only. Cap GV
publication and any live order actions happen only after full
validation (§5) passes — not during the reconstruction pass itself.
Calling live-mutation functions mid-reconstruction risks publishing
cap GVs at intermediate/partial layer counts and placing orders before
validation is complete.

**1.6 — Input drift.** If `InpExitPips`, `InpAddPipsFloor`,
`InpWidenRatio`, `InpLotSize`, or `InpMaxLayers` changed between the
session that opened these positions and this restart, reconstructed
targets cannot be assumed to match current inputs. Use actual resting
order prices/volumes where available; do not recompute an exit price
from current `InpExitPips` and assume it matches an already-resting
order. Any open position volume that doesn't match the expected
per-layer lot size is an ambiguity trigger (§4), since it may indicate
a partial fill, manual intervention, or exactly this kind of input
drift.

## 2. Cumulative and path-dependent state (Part B, rewritten)

v2 treated this as "walk history, accumulate pod totals." That's
insufficient — two state variables here are genuinely
sequence-dependent, not just cumulative-sum-dependent, and need a real
state-machine replay, not a running total.

**2.1 — Anchor-finding, two-track (corrected).** The exit mechanism
opens an exit-magic hedge position on fill, then a later `CloseBy`
action produces two `DEAL_ENTRY_OUT_BY` deals closing both legs. This
means volume tracking and lifecycle tracking are different problems
and must be tracked separately:

- **Track 1 (pod-boundary / anchor detection):** running volume
  counter using **entry-magic deals only**. Exit-magic `DEAL_ENTRY_IN`
  deals (hedge opens) must be excluded from this counter entirely —
  including them corrupts the anchor point. The anchor is the most
  recent point, walking backward, where entry-magic open volume last
  read zero before increasing again.
- **Track 2 (layer lifecycle):** a layer is considered closed at the
  time of its **exit-magic `DEAL_ENTRY_IN`** (the hedge opening),
  *not* at the later `DEAL_ENTRY_OUT_BY` reconciliation deal. The
  `OUT_BY` deals only reconcile volume; using them as the close event
  shifts pod timing and corrupts `layers_closed`, `gross_pnl`,
  `start_time`, and hold-time telemetry. Match `DEAL_ENTRY_OUT_BY`
  deals to specific positions via `DEAL_POSITION_ID`, not `DEAL_MAGIC`
  — both legs of a CloseBy can carry the same magic, so magic alone is
  not a reliable match key.

Bounding: cap the backward walk at a maximum lookback; "anchor not
found within bound" is a hard failure requiring halt, not an
assumption of flatness beyond the bound.

**2.2 — `current_add_pips` replay (new — v2 incorrectly assumed this
was derivable from depth alone).** Confirmed false: it initializes at
the floor value, is multiplied by `WidenRatio` on every append once
post-append depth reaches 3+, and is **not reduced** when depth
decreases via a non-flat removal — only reset to floor when the stack
returns fully to zero. Two stacks at identical current depth can carry
different values depending on append/removal history. Replay must
walk the append/remove event sequence forward from the anchor (using
Track 2's lifecycle events) and recompute this value step by step, not
derive it from current depth.

**2.3 — `last_exit_valid` / `last_exit_price` replay (corrected — v2
oversimplified this as "most recent close").** Confirmed: this is set
true only when the removed layer was the **top index** of the stack
at the moment of removal, with lower layers still remaining. Removal
of a lower layer does not change it. It resets to false when the stack
becomes fully flat. Replay must track, at each Track-2 removal event,
whether the removed layer was the top index at that moment — not
simply take the most recent close deal of any kind.

**2.4 — Rollover retry state.** Unchanged from v2: flagged as a
distinct hard problem, not solved in this revision. A crash mid-ADR-101
sequence needs its own detection logic and its own conservative
fallback, not folded into the general replay path.

## 3. Cap GV publish sequencing (Part C, elaborated)

v2 left this fully open. Proposing concrete rules here — **flagged as
a real design choice needing explicit sign-off, not a settled
answer:**

- "Orphan" under reconstruction means "this side's reconstruction did
  not complete successfully" — not "open positions were found at
  startup." A side that reconstructs successfully is not orphaned even
  though it started with open positions.
- A side publishes its own GV layer count only after its own
  reconstruction passes full validation (§5), and before that side
  processes any new trade action.
- If both sides of an instance reconstruct successfully, publish both
  before either is allowed to trade — a long-only publish at
  intermediate state temporarily skews net exposure that other
  instances read.
- If a side fails reconstruction, it remains halted and does not
  publish. **Unresolved risk, needs an explicit answer:** other
  instances reading a missing GV as 0 is permissive and could allow an
  add that should have been blocked. Proposed direction — not yet a
  final answer — is a distinct GV state (e.g., a reserved sentinel
  value) meaning "reconstruction in progress / failed," which other
  instances treat as maximally restrictive rather than absent-equals-
  zero. This needs explicit review, not silent adoption.
- Multi-instance restart ordering: if all GVs are cleared by a
  terminal restart, the first instance to reattach and publish alone
  creates a partial-view window for the others. Needs either a startup
  barrier, a publish-after-all-reconstructed handshake, or a
  documented operator restart-ordering procedure. Not resolved here.
- Trigger GVs (`V2GBP_CAP_TRIGGERS` / `V2EUR_CAP_TRIGGERS`) are
  unaffected — confirmed correct not to reset on `OnInit`, unchanged
  from ADR-103.

## 4. Ambiguity checklist (new — replaces v2's vague fallback trigger)

Any of the following forces a halt on that side, full stop — no
partial resume, no best-effort continuation:

1. Open position carrying exit magic (§0 — checked first, separately).
2. Pending exit-magic order not uniquely assignable to exactly one
   open entry-magic position (§1.2).
3. More pending exit-magic orders than open entry-magic positions.
4. A pending exit-magic order with no matching entry-magic position
   (dangling exit order).
5. More than one pending add/reload order on a side.
6. A pending add/reload order while the stack is empty, or a pending
   L0 order while the stack is non-empty (§1.3, §1.4).
7. Multiple open positions with identical `POSITION_TIME` where the
   ticket-ascending tie-break (§1.1) still can't produce a confident
   ordering — flag explicitly rather than silently applying the
   tie-break in a case that looks otherwise ambiguous.
8. Open position volume not matching the expected per-layer lot size
   (§1.6 — partial fill, manual intervention, or input drift signal).
9. No anchor found within the bounded lookback (§2.1).
10. A historical exit or CloseBy deal that can't be matched to a known
    layer during replay (§2.1).
11. Any pending order whose comment/magic combination is inconsistent
    with the reconstructed stack state.

## 5. Validation (unchanged in spirit from v2, restated with §0-§4's corrections)

Before releasing a side from halt state: reconstructed open layer
count, tickets, and entry prices must match direct broker reads
exactly (not within tolerance). Any mismatch, or any trigger from §4,
means halt — do not guess, do not partially resume. This is unchanged
as a principle from v2; what changed is that §4 now makes "any
mismatch" concrete and enumerable instead of a judgment call.

## 6. Scope (unchanged from v2)

A single shared, side-parameterized reconstruction routine (side
direction, entry magic, exit magic, pair label, cap-publish callback
injected) is preferable to three near-duplicates, per Phase 1's
finding. Reconstruction doesn't touch the signal path, so the BC/AB
difference across pairs isn't a real risk — the actual risk is macro
leakage across per-file constants, which the existing magic-literal
linter should be extended to cover for the reconstruction code path.

## 7. Verification path (unchanged from v2)

Confirmed by Phase 1: Strategy Tester cannot exercise this feature by
construction. Unit-testable at the pure-logic level against synthetic
position/order/deal arrays; end-to-end behavior requires the same live/
demo drill category as Gate 2, expanded to also cover a restart while
a CloseBy is in-flight (exercising §0's pre-check).

## 8. What this revision does not resolve

Stated plainly, not buried: rollover-interruption detection (§2.4) and
CloseBy-remnant reconstruction (§0 forces a halt rather than solving
it) are both still open. This revision closes the gaps Phase 1 found
in Parts A/B/C as originally scoped; it does not expand scope to solve
either of those two harder problems.
