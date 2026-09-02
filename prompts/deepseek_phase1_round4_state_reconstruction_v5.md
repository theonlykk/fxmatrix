# Phase 1 Round 4 — Does v5's Full CloseBy Mapping Actually Work?

Round 4 of a Phase 1 audit sequence. Round 1 (v2): BLOCKING, 8
findings. Round 2 (v3): BLOCKING, narrower findings, most importantly
that the historical hedge-to-layer mapping was unimplementable as
specified. Round 3 (v4, Option B): BLOCKING again — the scope-down
itself worked as designed, but empirically covered almost nothing
useful, since every managed exit in this system opens a hedge
position, meaning any exit at all since last-flat triggered Option B's
halt.

Gemini ruled: abandon Option B, pursue full CloseBy-history mapping
(Option A) instead. Before drafting this, the core mechanical
assumption was verified empirically against this account's real deal
history: 129 real CloseBy events over 90 days, zero exceptions — every
one produced exactly two `DEAL_ENTRY_OUT_BY` deals sharing a single
`DEAL_ORDER` value, with distinct `DEAL_POSITION_ID`s identifying the
entry leg and the hedge leg. That empirical result is the foundation
v5's Part B mapping algorithm is built on.

v5, attached below, replaces Part B entirely with that mapping
algorithm, and folds in all six fixes Gemini authorized from Round 3.

## What changed and where to check it

**Part B is a full replacement, not a revision (§2).** The CloseBy-
gated halt from v4 is gone. In its place: build a table of entry-magic
position opens and a table of exit-magic (hedge) position opens since
the anchor, group `DEAL_ENTRY_OUT_BY` deals by `DEAL_ORDER`, use each
pair's distinct `DEAL_POSITION_ID`s to determine which entry position
was closed against which hedge, and use the hedge's own opening
deal — not the later CloseBy settlement — as the true removal moment
for sequencing `current_add_pips` and `last_exit_valid` replay.

Check specifically:
- Is grouping by `DEAL_ORDER` actually sufficient, or is there a
  deal pattern (this account's 129 samples aside) where it could group
  incorrectly — e.g., broker-side reuse of order tickets, or a
  CloseBy that somehow doesn't conform to the two-deal shape found
  empirically here?
- Does using the hedge's own opening deal (rather than the CloseBy
  settlement) as the removal moment correctly handle every ordering of
  events relative to other appends/removals in the same window?
- §2.4 lists four new halt conditions specific to this mapping — are
  they sufficient, or is there a state that produces a *wrong* mapping
  (not caught by any of the four) rather than an *absent* one?

**Six fixes, one each — Gemini's exact list from the Round 3 ruling:**

1. §1.2 — exit-order assignment now requires both price and volume,
   closing the wrong-but-unique case from mismatched volume.
2. §1.2a — unmatched exit orders are now an explicit halt trigger, not
   silently left resting.
3. §1.4 — pending-order consistency checks now cover the full
   add/reload class, not just L0-on-empty-stack.
4. §1.1b — pending orders now get the same direction-vs-magic check
   as open positions.
5. §3 — the cap-GV sentinel is checked via an explicit branch before
   any arithmetic, rather than being fed into the existing net-
   exposure formula as a number.
6. §1.6 — missing/unpopulated `DEAL_POSITION_ID` on entry deals is now
   an explicit halt trigger rather than a silently-skipped check.

Check each: does it actually close the gap Round 3 found, or does it
relocate the problem again — same standard as every prior round.

**Also worth checking:** §3 explicitly states a residual gap (the
crash-without-terminal-restart stale-GV window) as accepted rather
than solved. Is that honest framing correct, or is there a way to
actually close it that the design is missing?

## What to actually check

Same standard as every round before this: does this design survive
contact with the real production source in the files attached, or
does it fail somewhere v5's authors didn't anticipate? If v5 still
shouldn't go to Gemini for final sign-off, say so plainly. Four rounds
of BLOCKING verdicts have been more valuable than a false pass would
have been — that standard doesn't change now that the design has
gotten harder to find fault with.

No implementation code in your response.

---

# State Reconstruction Engine — Design Sketch v5 (Option A: full CloseBy-history mapping)

Status: REVISED per Gemini's ruling (2026-08-04): Option B abandoned
after Round 3 showed its real coverage was worthless in practice
(excluded any side with even one exit since last flat). Option A
authorized — full hedge-to-entry mapping via CloseBy `DEAL_ORDER`
pairing, empirically verified against this account's real deal
history (129 CloseBy events, zero exceptions) before this draft was
written. Six fixes from Round 3 folded in throughout. Not yet audited
as a whole design — this is Round 4's subject.

Changes from v4, at a glance: §2 is a full replacement, not a
revision — the CloseBy-gated halt rule is gone, replaced by the
hedge-to-entry mapping algorithm Gemini approved. §1 and §4 carry all
six Round 3 fixes, not five. §3's sentinel design is tightened per
Round 3's finding that the original proposal would have been defeated
by existing cap-read arithmetic. §7 changes from testing a halt to
testing successful reconstruction through real CloseBy history.

---

## 0. Pre-check — CloseBy remnant detection (fast path, unchanged)

Before any other logic: scan currently open positions for this side's
exit magic. If any exist, halt immediately. Cheap, direct broker read,
kept as a fast path ahead of any history walk.

## 1. Hot state reconstruction (Part A)

Applies only once §0 finds no exit-magic positions on this side.

**1.1 — Layer positions and order.** Unchanged: enumerate open
positions by entry magic + symbol, sort by `POSITION_TIME` ascending
with ticket-ascending tie-break, assign as layer indices 0..n-1.

**1.1a — Position-type validation, open positions.** Unchanged from
v4: verify `POSITION_TYPE` against the expected direction for this
side's entry magic. Mismatch halts (§4).

**1.1b — Position-type validation, pending orders (fix #4, new).**
Round 3 found v4 only checked direction on *open* positions. The same
check now applies to *pending* entry-magic orders (L0 and add/reload):
a wrong-direction pending order with the correct magic can survive
reconstruction undetected and later fill into a wrong-direction
position — the reconstruction would have "succeeded" while leaving the
exact inconsistency the check exists to catch, one fill away. Any
pending entry-magic order whose implied direction doesn't match this
side is a halt trigger (§4).

**1.2 — Exit ticket assignment (fix #1, price AND volume required).**
v4 added price as a required match field; Round 3 found that alone
still insufficient — a stale exit order at the right price but the
*wrong volume* (e.g. a leftover 0.02-lot order) can still be the
unique match for a 0.01-lot layer, producing an oversized hedge on
fill. Corrected procedure:

- Enumerate all pending exit-magic orders and all open entry-magic
  positions for this side.
- Required match fields: correct direction, correct symbol, price
  consistent with entry price + `ExitPips` (within live placement
  tolerance), **and volume matching the position's own volume exactly**.
- Unique assignment required across all four fields. Ambiguity on any
  field, or no valid candidate: halt (§4).
- `exit_ticket = 0` / `NEEDS_PLACE` remains valid only when a position
  has zero candidate exit orders after full enumeration.

**1.2a — Unmatched exit orders (fix #2, new).** Round 3's sharper
finding: v4 never specified what happens to an exit-magic order that
matches *no* open position. Left resting, it can fill later, open an
orphaned hedge with no owning layer, and go unnoticed until the next
restart — after real exposure has already been distorted. Any pending
exit-magic order with no valid match to a currently open entry-magic
position is now an explicit halt trigger (§4), not a silently-ignored
leftover.

**1.3 — Add/reload ticket.** Unchanged: distinguish by comment
(`"V2_Add"` / `"V2_Reload"`), no separate magic exists in source.

**1.4 — Pending entry-order consistency, full class (fix #3,
expanded).** v4 only checked "multiple L0 orders on an empty stack."
Round 3 identified the full class this belongs to, all now explicit
halt triggers (§4):

- More than one pending L0 order while the stack is empty (v4,
  unchanged).
- More than one pending add/reload order on a non-empty stack.
- A pending L0 order while the stack is non-empty.
- A pending add/reload order while the stack is empty.
- Any pending entry-magic order whose comment doesn't cleanly resolve
  to `"V2_L0"` or `"V2_Add"`/`"V2_Reload"` given current stack state.

**1.5 — Read-only discipline.** Unchanged — confirmed clean across two
audit rounds, no changes.

**1.6 — Partial-fill and input-drift detection (fix #6, hardened).**
Round 3 found two gaps: missing/unpopulated `DEAL_POSITION_ID` on
entry deals makes the multiple-`DEAL_ENTRY_IN`-per-position count
impossible to perform, and v4 didn't say what to do then — **now an
explicit halt trigger** rather than silently skipping the check. The
other gap (partial fills manifesting as multiple *positions* rather
than multiple deals on one position) is already covered by the
existing per-layer volume-mismatch trigger (§4, unchanged from v3) —
noted here as a cross-reference, not re-implemented. Input drift on
`InpWidenRatio`/`InpAddPipsFloor` without a broker-observable artifact
remains a hard trigger, unchanged.

## 2. Path-dependent state via hedge-to-entry mapping (Part B — full replacement)

Replaces v4's CloseBy-gated halt entirely. Confirmed empirically
feasible: 129 real CloseBy events on this account, zero exceptions to
the pairing assumption below.

**2.1 — The reframe.** Reconstruction runs on deal history that has
already fully happened by the time it's read — it isn't a live
decision made at the instant a hedge opens. That means hindsight is
available: the mapping doesn't need to know which layer a hedge
belongs to *as it opens*; it can wait until a later CloseBy event
reveals the pairing, then retroactively place the removal at the
hedge's actual opening time (not the CloseBy's settlement time, which
can be delayed by retries). The only case requiring real-time
knowledge — a currently-open hedge at restart — is already excluded by
§0 before this section ever runs.

**2.2 — Anchor-finding.** Unchanged in spirit from v3: walk
`HistoryDealSelect` backward per side using entry-magic volume only,
to the most recent point this side had zero open entry-magic volume.
Bounded lookback; "anchor not found within bound" halts (§4).

**2.3 — Hedge-to-entry mapping algorithm.**

1. From the anchor forward, build two tables from deal history: every
   entry-magic position-open (`DEAL_POSITION_ID` → open time, price,
   volume) and every exit-magic position-open (`DEAL_POSITION_ID` →
   same fields — these are hedge legs).
2. Find every `DEAL_ENTRY_OUT_BY` deal in the window. Group by
   `DEAL_ORDER` — empirically confirmed (129/129, this account) that a
   single CloseBy operation produces exactly two such deals sharing
   one `DEAL_ORDER` value.
3. For each group: exactly one `DEAL_POSITION_ID` must match an
   entry-magic position from table 1, the other an exit-magic/hedge
   position from table 2 — confirmed empirically distinct in all 129
   verification samples.
4. This tells us which entry position was closed against which hedge.
   The hedge's own opening deal (table 2) gives the true removal
   moment — its time and price — used for sequencing: was this
   removal top-of-stack at that moment (`last_exit_valid`), and what
   was the depth immediately before it (`current_add_pips` replay).
5. Replay forward from the anchor using these resolved removal events
   plus ordinary append events, recomputing `current_add_pips`
   (`WidenRatio` compounding on every append once post-append depth
   reaches 3+, no reduction on partial removal, reset only on full
   flat) and `last_exit_valid`/`last_exit_price` (true only on
   top-of-stack removal, reset on full flat) — the semantics DeepSeek
   already confirmed correct against source in Round 2.

**2.4 — Halt conditions specific to this mapping (extends §4):**

- Any hedge-open (exit-magic entry deal) in history with no
  discoverable CloseBy pairing within the bounded lookback —
  unresolved hedge.
- Any `DEAL_ORDER` group of `DEAL_ENTRY_OUT_BY` deals that isn't
  exactly two.
- A hedge closed by an ordinary `DEAL_ENTRY_OUT` (not a CloseBy pair)
  while its corresponding entry position is still open — the
  "independently closed hedge" hazard Round 2/3 both flagged.
- Missing or zero `DEAL_POSITION_ID` or `DEAL_ORDER` on any deal this
  mapping depends on.

**2.5 — Rollover retry state.** Unchanged — still flagged as a
distinct, unsolved hard problem, not addressed by this design.

## 3. Cap GV publish sequencing — sentinel, tightened (fix #5)

Round 3 found the original sentinel proposal incomplete: existing
cap-read functions perform plain numeric arithmetic on GV values, so
a sentinel fed into that arithmetic unmodified can produce exactly the
permissive result it's meant to prevent (e.g., a sentinel of `-1` on
one side making a new add on the other side look like it *reduces*
net exposure). Corrected design:

- The sentinel remains a reserved out-of-band value, but cap-read
  functions must check for it **explicitly, before any arithmetic** —
  a distinct code branch, not a number fed into the existing
  net-exposure formula. On detecting a sentinel (or an absent GV,
  treated identically), the read side blocks any add referencing that
  side categorically. It is never treated as a numeric layer count.
- Written as the very first action in `OnInit` for a side with open
  positions, before reconstruction begins. Cleared and replaced with
  the real reconstructed count only after full validation (§5) passes.
- **Residual gap, stated plainly rather than claimed solved:** if an
  instance crashes without a full terminal restart, a previously
  published valid numeric GV can remain stale until the *next*
  successful `OnInit` writes the sentinel. That window — between a
  crash and the next reattach — is not eliminated by this design, only
  minimized by writing the sentinel as early as possible on every
  reattach. This is a known, accepted residual risk, not a closed gap.
- Trigger GVs unaffected, unchanged from ADR-103.

## 4. Ambiguity checklist (updated for v5)

Items 1-11 from v3, plus 12-15 from v4, plus:

16. Any exit-magic-related deal with no discoverable CloseBy pairing
    within the bounded lookback (§2.4).
17. Any `DEAL_ORDER` group of `DEAL_ENTRY_OUT_BY` deals not sized
    exactly 2 (§2.4).
18. A hedge closed by an ordinary `DEAL_ENTRY_OUT` while its entry
    position remains open (§2.4).
19. Missing/zero `DEAL_POSITION_ID` or `DEAL_ORDER` on any deal the
    mapping depends on (§2.4, §1.6).
20. Pending entry-magic order with wrong-direction `POSITION_TYPE`
    implication (§1.1b).
21. Pending exit-magic order matching no open position (§1.2a).
22. Any pending-order-count inconsistency per the full class in §1.4.

## 5. Validation

Unchanged in principle: reconstructed layer count, tickets, entry
prices must match direct broker reads exactly; any mismatch or any §4
trigger halts, no partial resume.

## 6. Scope (routine sharing)

Unchanged from v3/v4.

## 7. Verification path (changed — now tests successful reconstruction, not just halting)

Strategy Tester still cannot exercise this by construction. The
live/demo drill (same category as Gate 2) now needs a scenario proving
**successful** reconstruction through a real CloseBy-containing
history — not just correctly halting on one, which was v4's ask. This
means seeding a demo account with a stack that has genuinely closed at
least one layer via the live CloseBy mechanism before the restart, and
confirming the mapping in §2.3 correctly recovers `current_add_pips`
and `last_exit_valid` against known-good pre-restart values.

## 8. What this revision does not resolve

CloseBy-history reconstruction is no longer a parked scope boundary —
it's the subject of this design. Rollover-interruption detection
(§2.5) remains a distinct, unsolved problem, unchanged since v2. The
cap-GV sentinel's crash-without-restart window (§3) is an accepted
residual risk, not solved by this design — minimized, not eliminated.
