# Phase 1 Round 5 — Do v6's Corrections Actually Close Round 4's Findings?

Round 5 of a Phase 1 audit sequence. Round 4 (v5) confirmed the core
`DEAL_ORDER` mapping approach as directionally correct and four of six
Round 3 fixes as clean, but returned BLOCKING on six new findings —
two of which were architectural judgment calls (cap-GV sentinel
semantics, residual staleness gap) since escalated to and ruled on by
Gemini, not re-litigated here. The other four are straightforward
technical corrections, folded into v6 below.

Gemini's rulings, for context: absent-GV now deliberately becomes
non-permissive (fail-closed), matching sentinel behavior, as explicit
policy rather than an implicit side effect — not something to
re-question here, only to verify is correctly specified. The residual
staleness gap is accepted as-is; a heartbeat mechanism was considered
and explicitly not pursued — also not something to re-litigate, only
to confirm is honestly documented as accepted rather than silently
minimized.

## What changed and where to check it

**§2.2 anchor-finding — real bug fix, not just a rewording.** Round 4
found that "entry-magic volume" was ambiguous because a CloseBy
request is sent with entry magic, so the deal closing the hedge leg
can also carry entry magic — corrupting the walk if tracked by raw
deal magic rather than position identity. v6 redefines the walk around
entry-magic *position IDs*, established once at a position's own
opening deal and looked up by `DEAL_POSITION_ID` thereafter. Check:
does this actually close the corruption path, or is there a deal
sequence where position-ID-based tracking still misattributes volume?

**§2.3 step 5 — `last_exit_valid` reload-reset added.** Round 4 found
v5's replay carried `last_exit_valid` through reload fills, which
doesn't match production (reload appends immediately reset it to
false). v6 adds this rule directly to the replay state machine. Check:
is this the complete fix, or are there other append/removal
interactions with `last_exit_valid` or `current_add_pips` that v6
still doesn't model correctly?

**§2.4 — two new halt conditions.** An entry-magic position closed by
an ordinary `DEAL_ENTRY_OUT` anywhere in the window (closing Round 4's
concrete wrong-mapping attack via an orphaned hedge later paired
against an unrelated position), and any `DEAL_ORDER` group of two
`DEAL_ENTRY_OUT_BY` deals that doesn't resolve to exactly one
entry-table and one hedge-table match. Check: do these two conditions
fully close the gaps Round 4 identified, or is there a variant of
either attack that still slips through?

**§1.2 — temporal window added; price requirement loosened for
rollover tolerance.** This is the one most worth adversarial attention.
v6 adds a temporal-window requirement (exit order placed after the
matched position's open time) to close the stale-reassignment case
Round 4 found. But it also *loosens* the price-consistency requirement
specifically to tolerate legitimately rollover-modified exit prices —
accepting a single candidate that passes direction/symbol/volume/
temporal-window even if its price doesn't match
`entry_price + ExitPips`. Check specifically: does loosening this
check reopen the wrong-but-unique risk Round 3 first found, via a
different path than the one already closed? Is the temporal window
alone sufficient to prevent a stale order from being accepted once
price is no longer a hard gate?

## What to actually check

Same standard as every round: does this survive contact with the real
production source, or fail somewhere v6's authors didn't anticipate?
If v6 still shouldn't go to Gemini for final sign-off, say so plainly
and explain what's missing.

No implementation code in your response.

---

# State Reconstruction Engine — Design Sketch v6 (Round 4 corrections + Gemini's rulings on findings 7-8)

Status: REVISED per Round 4's BLOCKING verdict (core approach confirmed
directionally correct) and Gemini's rulings (2026-08-04) on the two
judgment calls: Option (a) for cap-GV sentinel behavior (absent-GV
becomes non-permissive, fail-closed, deliberate policy), and the
residual staleness gap accepted as-is (heartbeat GV not pursued in
v6). Four of six Round 3 fixes were confirmed clean by Round 4 with no
further changes needed (#2 unmatched-exit halt, #3 pending-order
consistency, #4 pending direction check, #6 missing-ID halt) — not
revisited below. Not yet audited as a whole design — this is Round 5's
subject.

Changes from v5, at a glance: §1.2 gets a temporal-window requirement
and explicit tolerance for rollover-modified exit prices. §2.3's
replay semantics gets the missing reload reset rule. §2.4 gets two new
halt conditions. §2.2's anchor-finding is redefined around entry-magic
position IDs rather than raw deal magic, closing a real corruption
path Round 4 found in data we already had. §3 is reworded to state
Option (a) as deliberate policy, not an implicit side effect.

---

## 0. Pre-check — CloseBy remnant detection (fast path, unchanged)

Before any other logic: scan currently open positions for this side's
exit magic. If any exist, halt immediately.

## 1. Hot state reconstruction (Part A)

Applies only once §0 finds no exit-magic positions on this side.

**1.1 / 1.1a / 1.1b — Layer order, position-type checks.** Unchanged
from v5.

**1.2 — Exit ticket assignment (temporal window + rollover tolerance,
both new).**

Round 4 found two remaining gaps in the four-field match
(direction/symbol/price/volume): a stale exit order from an already-
closed position can still be the unique four-field match for a later
position with the same entry price; and a legitimately rollover-
modified exit price can fail the price check on a normal, valid stack,
since ADR-101's retry mechanism can modify a resting exit order's price
away from the naive `entry_price + ExitPips` formula.

Corrected procedure:

- Required fields: direction, symbol, volume — unchanged, hard
  requirements.
- **Temporal window (new):** the candidate exit order's placement time
  must fall after the matched position's open time. A stale order from
  an already-closed position, by construction, was placed before some
  *different* position's open time that it shouldn't be matched to —
  this closes the stale-reassignment case directly.
- **Price (loosened, not removed):** if exactly one candidate satisfies
  direction/symbol/volume/temporal-window, accept it regardless of
  whether its price matches `entry_price + ExitPips` exactly — a
  mismatch may simply reflect a legitimate rollover modification, and
  rollover state is explicitly out of scope for this design to
  interpret further. If **more than one** candidate satisfies those
  four criteria, price proximity to `entry_price + ExitPips` is used to
  attempt disambiguation; if that still doesn't produce a unique match,
  halt (§4) — don't guess between rollover-modified and stale
  candidates.
- `exit_ticket = 0` / `NEEDS_PLACE` remains valid only when zero
  candidates exist after full enumeration.

Flagged for Round 5: this loosens a check that was tightened only last
round, specifically to tolerate a state (rollover modification) this
design doesn't otherwise model. Worth explicit adversarial attention —
does this reopen the wrong-but-unique risk Round 3 first found, just
via a different path?

**1.2a — Unmatched exit orders.** Unchanged from v5.

**1.3 — Add/reload ticket.** Unchanged.

**1.4 — Pending entry-order consistency.** Unchanged from v5.

**1.5 — Read-only discipline.** Unchanged — confirmed clean across
three audit rounds now.

**1.6 — Partial-fill and input-drift detection.** Unchanged from v5.

## 2. Path-dependent state via hedge-to-entry mapping (Part B)

**2.1 — The reframe.** Unchanged from v5.

**2.2 — Anchor-finding (corrected — real bug found in Round 4).**

v5 defined the anchor walk as tracking "entry-magic volume," which
Round 4 found ambiguous in a way that corrupts the result: a CloseBy
request is sent *with entry magic*, so both resulting
`DEAL_ENTRY_OUT_BY` deals — including the one closing the **hedge**
leg — can carry entry magic. If the walk treats "entry-magic volume"
as "any deal whose own magic equals entry magic," it will incorrectly
count the hedge's closing deal as an entry-volume decrement, producing
a false anchor. This was visible in the empirical verification data
already gathered (every sampled CloseBy pair shared one magic value
across both legs) — the connection to the anchor walk wasn't drawn
until Round 4 pointed it out.

Corrected definition: the walk tracks volume over **entry-magic
position IDs** — a position counts as entry-side based on whether
*its own opening deal* carried entry magic, established once and
looked up by `DEAL_POSITION_ID` for every subsequent deal referencing
it, not by re-checking deal-level magic on each closing deal
encountered during the walk. Bounding and the "anchor not found within
bound" halt condition are unchanged from v5.

**2.3 — Hedge-to-entry mapping algorithm (steps 1-4 unchanged from
v5; step 5 corrected for the missing reload-reset rule).**

Steps 1-4 (build entry/hedge position tables, group `DEAL_ENTRY_OUT_BY`
by `DEAL_ORDER`, resolve pairs, use the hedge's own opening deal as the
true removal moment) are unchanged from v5.

Step 5, replay forward from the anchor, corrected: in addition to
`current_add_pips` (`WidenRatio` compounding on append, no reduction on
partial removal, reset only on full flat) and `last_exit_valid`
(true only on top-of-stack removal, reset on full flat) — **an append
classified as a reload must immediately reset `last_exit_valid` to
false at that append event.** v5's replay carried `last_exit_valid`
through reload fills, which Round 4 confirmed doesn't match production
and is a direct replay-semantics bug, not a coverage gap: it can
misclassify the next fill's reload-vs-add status and compute the next
add target from the wrong anchor, producing a latent error that §5's
layer-level validation doesn't catch because it only checks positions
and tickets, not this internal state.

**2.4 — Halt conditions specific to this mapping (extends §4, two new
conditions added):**

Unchanged from v5:
- Any hedge-open with no discoverable CloseBy pairing within the
  bounded lookback.
- Any `DEAL_ORDER` group of `DEAL_ENTRY_OUT_BY` deals that isn't
  exactly two.
- A hedge closed by an ordinary `DEAL_ENTRY_OUT` while its
  corresponding entry position remains open.
- Missing or zero `DEAL_POSITION_ID` or `DEAL_ORDER` on any deal this
  mapping depends on.

New, per Round 4:

- **An entry-magic position closed by an ordinary `DEAL_ENTRY_OUT`**
  (not part of a resolved CloseBy pair) anywhere in the reconstruction
  window. Round 4's concrete attack: an entry position closes via
  ordinary means after its exit already filled (opening a hedge) but
  before the queued CloseBy settles; the orphaned hedge later pairs via
  CloseBy against a *different*, still-open entry position; every
  existing §2.4 check passes, but the mapping is false. This halt
  closes that path directly.
- **Any `DEAL_ORDER` group of exactly two `DEAL_ENTRY_OUT_BY` deals
  that does not resolve to exactly one entry-table position and
  exactly one hedge-table position** — e.g. both deals reference
  entry-table positions, both reference hedge-table positions, or
  either references a position outside both tables. v5 implied this
  resolution was required but never listed failure to resolve as an
  explicit halt condition, leaving undefined behavior for a reachable
  state.

**2.5 — Rollover retry state.** Unchanged — still a distinct, unsolved
problem. Its *effect* on exit-order prices is now tolerated by §1.2's
loosened check; the retry mechanism itself remains unmodelled.

## 3. Cap GV publish sequencing — sentinel, Option (a) confirmed as deliberate policy

Gemini's ruling: absent-GV becomes non-permissive, matching sentinel
behavior, as a deliberate fail-closed policy — not an implicit side
effect of the reconstruction design, as it read in v5. Restated
explicitly:

- An absent peer GV and an explicit reconstruction-pending sentinel are
  now, by policy, treated identically: both block any add referencing
  that side. This is a genuine change from today's production
  behavior, where a missing GV reads as layer count 0 (permissive) —
  made deliberately, not as a side effect of this initiative. Rationale
  (Gemini's ruling): in a distributed, cross-instance risk architecture,
  an unverifiable peer exposure is an unknown risk state, and treating
  unknown risk as zero risk is the actual structural hazard. If a peer
  EA is intentionally not attached, or attaches later than a sibling,
  this can block that sibling's adds until the peer attaches — accepted
  explicitly as the correct behavior, not a bug.
- Sentinel written as the very first action in `OnInit` for a side with
  open positions, before reconstruction begins. Cleared and replaced
  with the real reconstructed count only after full validation (§5)
  passes.
- Trigger GVs unaffected, unchanged from ADR-103.

**Residual staleness gap — accepted, per Gemini's ruling.** DeepSeek's
proposed heartbeat/timestamp-GV mechanism would close the window
between a crash-without-terminal-restart and the next successful
`OnInit`, where a stale numeric GV could still be read as valid by
peers. Gemini ruled against implementing it in this initiative: it
would require modifying `OnTick`/cap-read paths across every instance,
a blast radius disproportionate to this specific edge case. Documented
here as a deliberately accepted residual risk, not an oversight — a
dedicated Heartbeat/Watchdog initiative remains a possible future
addition to ARCHITECT.md's Parked Backlog if this risk materializes in
practice, not something being opened now.

## 4. Ambiguity checklist (updated for v6)

Items 1-22 from v3/v4/v5, plus:

23. An entry-magic position closed by an ordinary `DEAL_ENTRY_OUT`
    anywhere in the reconstruction window, not part of a resolved
    CloseBy pair (§2.4).
24. A `DEAL_ORDER` group of exactly two `DEAL_ENTRY_OUT_BY` deals that
    doesn't resolve to exactly one entry-table and one hedge-table
    position (§2.4).
25. More than one exit-order candidate remains after temporal-window
    filtering and price-proximity disambiguation both fail to produce
    a unique match (§1.2).

## 5. Validation

Unchanged in principle from v3-v5. Worth restating given Round 4's
finding: this validates layer positions, tickets, and entry prices —
it does **not** validate `last_exit_valid` or `current_add_pips`
against any independent source, since none exists. Correctness of
those two values depends entirely on the replay logic in §2.3 being
right, which is exactly why Round 4's semantic bug there passed §5
undetected. No new validation mechanism proposed here — flagging the
limitation explicitly rather than implying §5 catches more than it
does.

## 6. Scope (routine sharing)

Unchanged from v3-v5.

## 7. Verification path

Unchanged from v5 — the live/demo drill needs to prove successful
reconstruction through real CloseBy history, including now a scenario
exercising a reload fill specifically, to confirm §2.3's corrected
`last_exit_valid` reset actually behaves as replayed.

## 8. What this revision does not resolve

Rollover retry state itself (§2.5) remains unsolved — only its effect
on exit-order prices is now tolerated. The cap-GV staleness gap (§3)
is an explicitly accepted residual risk per Gemini's ruling, not
solved. A heartbeat/watchdog mechanism was considered and deliberately
not pursued in this initiative.
