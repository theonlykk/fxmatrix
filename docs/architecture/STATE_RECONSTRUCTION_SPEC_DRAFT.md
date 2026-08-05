# State Reconstruction Engine — Design Spec v8 (CONCEPTUALLY CLOSED)

Status: **CLOSED — APPROVED FOR IMPLEMENTATION**, per Gemini's ruling
(2026-08-04) after six Phase 1 DeepSeek audit rounds. Round 6 ("Drain
the Swamp" protocol — halt is a pass, only a silent-corruption bypass
counts as a finding) found two bypasses; both are resolved below.
Gemini ruled: skip a seventh audit round, proceed directly to this
closure. This document is the authoritative design; implementation
(Cursor, Phase 4) proceeds from here, not from any prior version.

History, briefly: v2 through v7 went through six DeepSeek rounds.
Rounds 1-2 found the original design's exit-matching and hedge-mapping
approach fundamentally underspecified. Round 3 (Option B, scope-limited
to CloseBy-free history) proved to have worthless real-world coverage
and was abandoned. Rounds 4-6 (Option A, full CloseBy `DEAL_ORDER`
pairing, empirically verified against 129 real CloseBy events on this
account) progressively closed real bugs — raw-magic anchor corruption,
missing reload-reset semantics, insufficient exit-order matching,
incomplete halt coverage for non-standard closures. Two policy
decisions were escalated to and ruled on by Gemini along the way:
absent-GV becomes deliberately non-permissive (fail-closed), and the
crash-without-restart cap-GV staleness gap is an accepted residual
risk, not solved. Round 6 found the last two gaps, both resolved below
with Gemini's sign-off.

---

## 0. Pre-check — CloseBy remnant detection (fast path)

Before any other logic: scan currently open positions for this side's
exit magic. If any exist, halt immediately.

## 1. Hot state reconstruction (Part A)

Applies only once §0 finds no exit-magic positions on this side.

**1.1 — Layer positions and order.** Enumerate open positions by entry
magic + symbol. Sort by `POSITION_TIME` ascending, ticket-ascending
tie-break. Assign as layer indices 0..n-1.

**1.1a — Position-type validation, open positions.** Verify
`POSITION_TYPE` matches the expected direction for this side's entry
magic. Mismatch halts (§4).

**1.1b — Position-type validation, pending orders.** Same check applies
to pending entry-magic orders (L0 and add/reload) — a wrong-direction
pending order can survive reconstruction and later fill into a
wrong-direction position. Mismatch halts (§4).

**1.2 — Exit ticket assignment (tiered matching — final fix, Round 6).**

Two prior attempts at this failed adversarial review: v6's four-field
match (direction/symbol/price/volume) allowed a stale order from an
already-closed position to be uniquely matched to an unrelated later
position; v7's fix (adding a temporal window, loosening price for
rollover tolerance) closed that but reopened a different
misassignment — a legitimately delayed exit placement (via the
production retry mechanism) could land after a newer layer opened,
making it eligible for the wrong layer once price stopped being a hard
gate.

Corrected, tiered:

- **Tier 1 (primary).** Required: direction, symbol, volume, price
  matching `entry_price + ExitPips` exactly (within live placement
  tolerance), and an eligibility interval of `[this layer's own open
  time, now)` — lower-bounded only, no upper bound. Assign whatever is
  globally unique across all layers and candidates under this full
  match.
- **Tier 2 (rollover fallback, only for positions left unmatched by
  Tier 1).** Among candidate orders *also* left unclaimed by Tier 1,
  relax the price requirement. Accept only if exactly one such
  candidate remains for that position. More than one: halt (§4).
- Removing the interval's upper bound does not reopen the original
  stale-order risk: a genuinely stale order from an already-closed
  different position was necessarily placed before the *current*
  position's own open time, and fails the lower bound outright,
  regardless of tier.
- `exit_ticket = 0` / `NEEDS_PLACE` remains valid only when a position
  has zero candidates across both tiers after full enumeration.

**1.2a — Unmatched exit orders.** Any pending exit-magic order with no
valid match to a currently open entry-magic position under either
tier is a halt trigger (§4) — not silently left resting.

**1.3 — Add/reload ticket.** No separate magic exists in source;
distinguish by comment (`"V2_Add"` / `"V2_Reload"`).

**1.4 — Pending entry-order consistency, full class.** Halt triggers
(§4): more than one pending L0 order on an empty stack; more than one
pending add/reload order on a non-empty stack; a pending L0 order while
non-empty; a pending add/reload order while empty; any pending
entry-magic order whose comment doesn't cleanly resolve given current
stack state.

**1.5 — Read-only discipline.** Reconstruction never calls
`AppendLayer`/`RemoveLayerAt` or any side-effecting function. Layer
arrays and state variables are built directly, in memory, read-only.
Cap GV publication and any live order actions happen only after full
validation (§5) passes. Confirmed clean across five audit rounds.

**1.6 — Partial-fill, input-drift, rollover-tolerant exit_target.**
Missing/unpopulated `DEAL_POSITION_ID` on entry deals is a halt
trigger. Multiple `DEAL_ENTRY_IN` deals mapping to one broker position
is a halt trigger. When a matched exit order's price doesn't equal the
naive formula (Tier 2 case), the reconstructed layer's `exit_target` is
set to the order's actual current price, not the formula result —
explicitly recorded as rollover-tolerant state. Input drift on
`InpWidenRatio`/`InpAddPipsFloor` without a broker-observable artifact
remains a hard trigger.

## 2. Path-dependent state via hedge-to-entry mapping (Part B)

**2.1 — The reframe.** Reconstruction runs on deal history that has
already fully happened by the time it's read. Hindsight is available:
the mapping doesn't need to know which layer a hedge belongs to as it
opens; it can wait for a later CloseBy event to reveal the pairing,
then retroactively place the removal at the hedge's actual opening
time, not the CloseBy's settlement time.

**2.2 — Anchor-finding.** Walk `HistoryDealSelect` backward per side,
tracking volume over entry-magic **position IDs** — established once
at a position's own opening deal, looked up by `DEAL_POSITION_ID`
thereafter, not by re-checking deal-level magic (a CloseBy request is
sent with entry magic, so the deal closing the hedge leg can also carry
entry magic; tracking by raw magic corrupts the walk). The anchor
requires zero managed positions of **both** types — entry-magic and
exit-magic — not entry-magic volume alone; an open exit-magic position
at what would otherwise read as the anchor point invalidates it.
Bounded lookback; "anchor not found within bound" halts (§4).

**2.3 — Hedge-to-entry mapping algorithm.**

1. From the anchor forward, build two tables: every entry-magic
   position-open (`DEAL_POSITION_ID` → open time, price, volume) and
   every exit-magic position-open (same fields — hedge legs).
2. Find every `DEAL_ENTRY_OUT_BY` deal in the window. Group by
   `DEAL_ORDER` — empirically confirmed (129/129 real CloseBy events,
   this account) that a single CloseBy operation produces exactly two
   such deals sharing one `DEAL_ORDER` value.
3. For each group: exactly one `DEAL_POSITION_ID` must match an
   entry-table position, the other a hedge-table position.
4. **New (Round 6, Finding 2 fix):** for each resolved pair, verify the
   hedge's own opening price is consistent with the paired entry
   position's expected exit target (`entry_price + ExitPips`,
   rollover-tolerant per §1.6). This is a fail-closed check against
   externally-caused cross-paired CloseBy execution — confirmed via
   direct source review to be unreachable through the EA's own
   queueing logic (entry-hedge pairing is captured atomically at fill
   time, before the layer is even removed from the array; no shared
   state could swap pairs across concurrent fills). External CloseBy
   action (manual, another script, or a broker-side defect) could still
   produce a well-formed but wrongly-paired group; this check catches
   it in the common case, where the crossed hedge's price reflects a
   *different* layer's target than the one it's paired with.
   Inconsistent pairing halts (§4).

   **Accepted residual risk, stated plainly:** this check is not a
   mathematical guarantee. On a tightly-spaced grid (this system's
   normal operating mode), a sufficiently constructed cross-pairing
   could produce prices close enough to pass reasonable tolerance. A
   fully airtight defense requires hedge-to-entry lineage tracing,
   which Gemini ruled disproportionate to a scenario that already
   requires external tampering to occur at all. This gap is accepted,
   not solved — documented here rather than discovered later.

5. The hedge's own opening deal gives the true removal moment — time
   and price — used for sequencing: top-of-stack determination for
   `last_exit_valid`, depth-at-that-moment for `current_add_pips`
   replay.
6. Replay forward from the anchor: `current_add_pips` compounds via
   `WidenRatio` on every append once post-append depth reaches 3+, no
   reduction on partial removal, reset only on full flat.
   `last_exit_valid` is true only on top-of-stack removal; **an append
   classified as a reload immediately resets it to false** at that
   append event (confirmed against production semantics, Round 4).

**2.4 — Halt conditions specific to this mapping (extends §4):**

- Any hedge-open with no discoverable CloseBy pairing within the
  bounded lookback.
- Any `DEAL_ORDER` group of `DEAL_ENTRY_OUT_BY` deals not sized exactly
  two.
- A hedge closed by an ordinary `DEAL_ENTRY_OUT` while its
  corresponding entry position remains open.
- Missing or zero `DEAL_POSITION_ID` or `DEAL_ORDER` on any deal this
  mapping depends on.
- Any `DEAL_ORDER` group of exactly two `DEAL_ENTRY_OUT_BY` deals not
  resolving to exactly one entry-table and one hedge-table position.
- **Any entry-magic position within the full bounded lookback — not
  just since the anchor — closed by anything other than the standard,
  verified CloseBy pairing sequence** (ordinary `DEAL_ENTRY_OUT`,
  manual close, or stop-out/`DEAL_REASON_SO`). Deliberately
  unconditional; does not attempt to determine whether the irregular
  closure is safe to reconstruct through. Scans the full bounded
  lookback because the attack this closes can predate the anchor while
  its hedge remnant survives into the current window.
- **New (Round 6, Finding 2):** a resolved CloseBy pair whose hedge
  opening price is inconsistent with the paired entry position's
  expected exit target (§2.3 step 4).

**2.5 — Rollover retry state.** Distinct, unsolved problem. Its effect
on exit-order prices is tolerated by §1.2/§1.6; the retry mechanism
itself remains unmodeled.

## 3. Cap GV publish sequencing — sentinel

- Every cap-read function checks, as its first operation, before any
  other logic including threshold checks: is this side's GV the
  reserved sentinel value or absent? If yes, block any add referencing
  that side and return immediately — no net-exposure arithmetic.
- Deliberate policy change from today's behavior (absent GV previously
  permissive, now blocking) — Gemini's ruling, explicit, not an
  implicit side effect. Rationale: in a distributed, cross-instance
  risk architecture, unverifiable peer exposure is an unknown risk
  state, and treating unknown risk as zero risk is the actual
  structural hazard.
- Sentinel written as the very first action in `OnInit` for a side
  with open positions, before reconstruction begins. Cleared and
  replaced with the real reconstructed count only after full
  validation (§5) passes.
- Trigger GVs unaffected, unchanged from ADR-103.
- **Accepted residual risk:** the window between a crash-without-
  terminal-restart and the next successful `OnInit` — where a
  previously-published valid numeric GV can remain stale — is not
  eliminated by this design, only minimized by writing the sentinel as
  early as possible on every reattach. A heartbeat/timestamp mechanism
  was considered and explicitly not pursued; the blast radius
  (touching every instance's `OnTick`/cap-read paths) was ruled
  disproportionate to this specific edge case.

## 4. Ambiguity checklist (final, v8)

1-22: unchanged since v3-v5.
23: superseded — see §2.4's broadened unconditional rule.
24-25: unchanged since v6.
26: superseded — see items 28-29 below (tiered matching replaces
    single-tier global assignment).
27: unchanged since v7 (anchor reaching zero entry-magic volume while
    an exit-magic position remains open).

New in v8:

28. Tier 1 global assignment (direction+symbol+volume+price+interval)
    is not unique across all layers and candidates (§1.2).
29. Tier 2 fallback assignment (among Tier-1-unclaimed candidates,
    price relaxed) is not unique for a given position (§1.2).
30. A resolved CloseBy pair's hedge opening price is inconsistent with
    the paired entry position's expected exit target (§2.3 step 4).

## 5. Validation

Reconstructed layer count, tickets, and entry prices must match direct
broker reads exactly. Any mismatch, or any §4 trigger, halts — no
partial resume. This validates positions and tickets; it does not and
cannot validate `last_exit_valid`, `current_add_pips`, or exit-order
assignment correctness against any independent source — correctness
there depends entirely on §1.2 and §2.3's logic being right, which is
why six rounds of adversarial pressure concentrated there.

## 6. Scope

A single, side-parameterized reconstruction routine (side direction,
entry magic, exit magic, pair label, cap-publish callback injected) is
used across all three production files, rather than three
near-duplicates. Reconstruction doesn't touch the signal path, so the
BC/AB difference across pairs isn't a risk; the real risk is macro
leakage across per-file constants, covered by extending the existing
magic-literal linter to the reconstruction code path.

## 7. Verification path

Strategy Tester cannot exercise this by construction. The live/demo
drill (Gate 2's category) must prove: successful reconstruction through
real CloseBy history including a reload-fill scenario (confirming the
`last_exit_valid` reset behaves as replayed); correct halting (not
attempted reconstruction) when a manual or stop-out closure is
deliberately introduced into history; and correct halting when a
deliberately mismatched-price CloseBy pairing is introduced, to confirm
§2.3 step 4's check actually fires in practice, not just on paper.

## 8. What this design does not resolve — accepted, not hidden

- Rollover retry state itself (§2.5) — only its effect on exit-order
  prices is tolerated.
- Cap-GV staleness window between a crash-without-restart and the next
  successful reattach (§3) — minimized, not eliminated.
- Tight-grid cross-pairing spoofing resistant to the price-consistency
  check (§2.3 step 4) — narrowed substantially, not mathematically
  closed; full closure requires lineage tracing, ruled disproportionate
  to an already-external-only threat.
- CloseBy-history reconstruction more broadly was never in question —
  it is this design's actual subject, not a parked scope boundary (see
  ARCHITECT.md's Parked Backlog entry for the full history of that
  earlier, abandoned Option B).

This design is closed on Gemini's authority (2026-08-04). Implementation
proceeds from this document, not from any earlier draft version.
