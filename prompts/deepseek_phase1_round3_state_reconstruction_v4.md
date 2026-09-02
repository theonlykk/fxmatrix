# Phase 1 Round 3 — Does v4 Correctly Implement Option B and the Five Universal Fixes?

Round 3 of a Phase 1 audit sequence. Round 1 (v2): BLOCKING, 8
findings. Round 2 (v3): BLOCKING again, narrower findings — most
significantly, that the historical hedge-to-layer mapping needed for
`current_add_pips`/`last_exit_valid` replay was unimplementable as
specified, because MT5 hedging-mode exit fills open a new hedge
position with no back-reference to the original layer, recoverable
only via correct CloseBy pairing.

Given that finding, Gemini ruled a scope decision (Option B): the
engine reconstructs with confidence only on CloseBy-free history since
the anchor. Any CloseBy-related deal in that window forces a halt via
the existing orphan guard, full stop — no attempt to reconstruct
through it. This is now a documented, deliberate scope boundary
(ARCHITECT.md Parked Backlog), not an open problem to keep solving.

v4, attached below, implements that scope boundary plus the five
"needed either way" fixes Round 2 identified as independent of the
scope question.

## What changed and where to check it

**Option B scope boundary (§2.1):** the entire two-track hedge-to-layer
mapping design from v3 is gone, replaced by a single rule: any
exit-magic-related deal encountered during the backward anchor-finding
walk halts the side immediately. Check: does this rule actually fire
correctly on every deal type that should trigger it? Does removing the
mapping logic entirely (rather than keeping a degraded version of it)
leave any gap in a CloseBy-free window that the mapping logic would
have caught but the simpler walk doesn't?

**Claim that this subsumes Round 2 finding #3:** v4 claims the new
§2.1 rule catches the "hedge already closed independently of CloseBy,
entry still open" remnant variant that Round 2 found — since that
scenario still produces an exit-magic `DEAL_ENTRY_IN` in history, which
the walk now halts on regardless of how the hedge was later closed.
Check specifically whether this claim holds, or whether there's a
sequence where that variant still slips through undetected.

**Five universal fixes, one each:**

1. §1.1a — position-type (BUY/SELL) validated against entry magic, not
   magic alone. Check whether this is sufficient or misses a case.
2. §1.4 — multiple pending L0 orders on an empty stack is now a
   trigger. Check whether "empty stack" is itself well-defined at the
   point this check runs.
3. §1.2 — resting order price added as a required match field for exit
   assignment, specifically to close the wrong-but-unique case Round 2
   found. Check whether price-consistency is sufficient, or whether a
   new wrong-but-unique case exists even with price included.
4. §1.6 — partial fills detected via counting `DEAL_ENTRY_IN` deals per
   `DEAL_POSITION_ID`. Check whether this correctly distinguishes a
   genuine partial-fill sequence from other deal patterns that might
   produce more than one entry deal per position for unrelated reasons.
5. §3 — cap-GV sentinel refined: reserved out-of-band value, written
   before reconstruction starts, cleared only after validation passes,
   read-side treats sentinel/absent as maximally restrictive. Check
   whether this actually closes the permissive-zero and multi-instance
   restart-ordering problems Round 2 flagged, or whether a gap remains
   in how existing cap-read functions would need to change to honor
   this correctly.

## What to actually check

Same standard as Round 2: does each fix actually close the gap, or
does it relocate the problem? In particular, given how much simpler
§2 became under Option B — is there a risk that the simplification
itself introduces a new gap, e.g., a state that's CloseBy-free by this
design's definition but still has some other path-dependency the
original two-track design would have caught incidentally?

No implementation code in your response. If v4 still shouldn't go to
Gemini for final sign-off, say so plainly and explain what's missing —
same standard as both prior rounds: a false "looks fixed" verdict here
is worse than a third BLOCKING result.

---

# State Reconstruction Engine — Design Sketch v4 (Option B scope + five universal fixes)

Status: REVISED per Gemini's ruling (2026-08-04): Option B approved
(CloseBy-history reconstruction parked, documented in ARCHITECT.md's
Parked Backlog with an explicit reopen condition), five universal
fixes from Round 2 folded in. Not yet audited. Not yet reviewed by
Gemini as a design.

Changes from v3, at a glance: §2's scope is now explicitly bounded to
CloseBy-free history (Option B) — this also subsumes Round 2 finding
#3 (the missed hedge-already-closed remnant variant), since the new
historical check catches it without needing special-casing. §1 and §4
carry the four hot-state universal fixes. §3 carries the cap-GV
sentinel refinement.

---

## 0. Pre-check — CloseBy remnant detection (fast path, unchanged from v3)

Before any other logic: scan currently open positions for this side's
exit magic. If any exist, halt immediately. This remains a cheap,
direct broker read that can short-circuit before any history walk
starts — kept as a fast path even though §2.1's revised anchor-finding
walk (below) would also catch this case via history, just not as
cheaply.

## 1. Hot state reconstruction (Part A)

Applies only once §0 finds no exit-magic positions on this side.

**1.1 — Layer positions and order.** Unchanged from v3: enumerate
open positions by entry magic + symbol, sort by `POSITION_TIME`
ascending with ticket-ascending tie-break, assign as layer indices
0..n-1.

**1.1a — Position-type validation (universal fix #3, new).** For each
enumerated position, verify `POSITION_TYPE` (BUY/SELL) matches the
expected direction for this side's entry magic — not magic alone.
Magic filtering alone doesn't rule out a position with the right magic
but the wrong direction, which would indicate either a real bug
elsewhere or an inconsistency reconstruction shouldn't paper over.
Mismatch is an ambiguity trigger (§4).

**1.2 — Exit ticket assignment (universal fix #1, price-matching
added).** v3's matching criteria (direction, symbol, volume) were
insufficient — every layer shares `InpLotSize`, so volume doesn't
discriminate between candidates, and DeepSeek found a concrete
wrong-but-unique case: a stale, uncancelled exit order from an
unrelated closed position getting matched to an unrelated open
position purely by elimination. Corrected procedure:

- Enumerate all pending exit-magic orders and all open entry-magic
  positions for this side (from 1.1).
- Required match fields: correct direction, correct symbol, **and the
  resting order's price must be consistent with that position's entry
  price plus `ExitPips`** (within the same tolerance the live exit
  placement logic itself would use). Price is now a required
  consistency check, not an optional detail.
- Attempt a unique assignment under these criteria. If exactly one
  valid pairing exists per position and per order: assign.
- If assignment is not unique, or a price-consistency check fails for
  every candidate: ambiguity trigger (§4) — halt.
- `exit_ticket = 0` / `NEEDS_PLACE` fallback remains valid **only**
  when a position has zero candidate exit orders at all after full
  enumeration — unchanged from v3's fix, still correct.

**1.3 — Add/reload ticket.** Unchanged from v3: no separate magic
exists in source; distinguish by comment (`"V2_Add"` / `"V2_Reload"`),
not a nonexistent add magic.

**1.4 — L0 ticket, multiple-order check (universal fix #2, new).** If
the stack is empty and exactly one pending entry-magic order with
comment `"V2_L0"` exists, reconstruct it. If **more than one** such
order exists — a legitimate possible state, since an unreconstructed
L0 ticket is exactly the bug this section exists to prevent, and could
have already occurred once before a prior crash — this is now an
explicit ambiguity trigger (§4), not silently resolved by picking one.

**1.5 — Read-only discipline.** Unchanged from v3 — confirmed clean by
Round 2, no changes needed.

**1.6 — Input drift and partial-fill detection (universal fix #4,
expanded).** v3 only checked open-position volume against expected
per-layer lot size. That misses the case where a single broker
position resulted from **more than one `DEAL_ENTRY_IN` deal** (a
partially-filled order completing in stages) — broker-reported volume
can equal `InpLotSize` in total while the live layer stack, pre-crash,
actually contained multiple layers for what's now one position.
Added: for each open entry-magic position, check the count of
entry-magic `DEAL_ENTRY_IN` deals with matching `DEAL_POSITION_ID`. If
more than one, this is an ambiguity trigger (§4) — do not assume one
position equals one layer. Input drift affecting `InpWidenRatio` /
`InpAddPipsFloor` without a broker-observable artifact to read instead
remains a hard trigger, unchanged from v3.

## 2. Cumulative and path-dependent state (Part B) — scope bounded by Option B

**2.1 — Anchor-finding, now CloseBy-gated (revised for Option B).**
Walk `HistoryDealSelect` backward per side, tracking entry-magic
open volume as in v3. **New rule, replacing v3's two-track design:**
if, at any point during this backward walk, an **exit-magic-related
deal** is encountered — an exit-magic `DEAL_ENTRY_IN` (a hedge
opening) or any `DEAL_ENTRY_OUT_BY` — **stop the walk immediately and
halt this side.** Do not attempt to pair, map, or reconstruct through
it. This is Option B's scope boundary, applied directly: Part B only
ever completes for a side whose deal history since it was last flat
contains no CloseBy activity at all.

This single rule replaces v3's entire two-track hedge-to-layer mapping
design (§2.1's Track 2, the `DEAL_POSITION_ID` pairing logic) — none
of that is needed anymore, because Part B simply never runs in a
history window where it would have been required. It also subsumes
Round 2 finding #3 (the hedge-already-closed-independently remnant
variant that §0's live-position check alone couldn't see): if a hedge
opened and was later closed by any means, that's still an exit-magic
`DEAL_ENTRY_IN` in history, and the new rule halts on it regardless of
how the hedge was eventually closed.

Bounding: unchanged from v3 — cap the walk at a maximum lookback;
"anchor not found within bound" is a hard failure requiring halt.

**2.2 — `current_add_pips` replay (simplified under Option B).** In a
confirmed CloseBy-free window, every removal event is an ordinary
entry-magic close with no hedge involved, so the append/remove
sequence is unambiguous. Replay forward from the anchor, applying
`WidenRatio` on every append once post-append depth reaches 3+, no
reduction on non-flat removal, reset only on full-flat — the semantics
DeepSeek confirmed correct in Round 2. No hedge-to-layer mapping is
needed, because there are no hedge events in this window by
construction.

**2.3 — `last_exit_valid` / `last_exit_price` replay (simplified under
Option B).** Same simplification: in a CloseBy-free window, each
removal event is an ordinary close directly attributable to a specific
layer (no ambiguity about which position a hedge corresponds to, since
there are no hedges). Track whether each removal was top-of-stack at
that moment, per v3's corrected semantics — now actually implementable
as written, since the blocking gap (identifying which layer a
historical exit closed) doesn't arise when there's no hedge to
disambiguate.

**2.4 — Rollover retry state.** Unchanged — still flagged as a
distinct, unsolved hard problem, not addressed by this revision.

## 3. Cap GV publish sequencing (Part C) — sentinel refinement (universal fix #5)

Gemini's ruling calls for tightening this; concrete proposal below,
flagged for DeepSeek Round 3 verification rather than treated as
settled, since Round 2 found the original sentinel idea incomplete on
several specific points:

- The sentinel is a reserved out-of-band value, not a valid layer
  count (e.g., a value outside any real layer-count range), so cap-read
  functions can distinguish it from an actual exposure number rather
  than accidentally arithmetic-ing with it.
- Written **before** reconstruction begins, as the very first action
  in `OnInit` for a side with open positions — so a crash mid-
  reconstruction leaves the sentinel in place rather than a stale
  pre-crash value lingering.
- Cleared and overwritten with the real reconstructed count only after
  §5 validation fully passes — never written speculatively mid-process.
- Cap-read functions in sibling instances must treat a sentinel as
  maximally restrictive (block new adds referencing that side) rather
  than as zero exposure — this is the specific permissive-zero problem
  Round 2 flagged, addressed directly by making the sentinel a distinct
  state the read side must explicitly handle, not an absence to
  default around.
- Multi-instance restart ordering (all GVs cleared by a terminal
  restart, first instance to reconstruct successfully publishing while
  others are still mid-reconstruction) is addressed by the same rule:
  an absent or sentinel GV from a sibling is read as maximally
  restrictive by definition, so there's no permissive window regardless
  of restart order — no separate startup barrier or handshake needed
  beyond this read-side rule.
- Trigger GVs unaffected, unchanged from ADR-103.

Flagged explicitly: this still needs verification that the "maximally
restrictive" read-side interpretation is actually correctly specified
everywhere cap-read functions exist, not just described in principle.

## 4. Ambiguity checklist (updated)

Unchanged items 1-11 from v3, plus:

12. Position type inconsistent with entry magic (§1.1a).
13. More than one pending L0 order while the stack is empty (§1.4).
14. Exit order price inconsistent with entry price + `ExitPips` for
    every candidate match (§1.2).
15. More than one entry-magic `DEAL_ENTRY_IN` deal mapping to a single
    open position (§1.6).
16. Any exit-magic-related deal (hedge open or `DEAL_ENTRY_OUT_BY`)
    encountered during the anchor-finding walk (§2.1) — this is
    Option B's scope boundary, listed here for completeness though
    it's really an absolute precondition on Part B running at all,
    not a judgment-call trigger like the others.

## 5. Validation

Unchanged in principle from v3: reconstructed layer count, tickets,
and entry prices must match direct broker reads exactly; any mismatch
or any §4 trigger halts rather than partially resuming.

## 6. Scope (routine sharing)

Unchanged from v3.

## 7. Verification path

Unchanged from v3, with one addition: the live/demo drill needs a
scenario confirming the engine correctly halts (not attempts
reconstruction) when a CloseBy has genuinely occurred in a side's
history since it was last flat — a negative-path test, not just the
positive-path "reconstruction succeeds" cases.

## 8. What this revision does not resolve

CloseBy-history reconstruction is now a documented, deliberate scope
boundary (Gemini's ruling, Option B) rather than an open problem —
see ARCHITECT.md's Parked Backlog entry for the explicit reopen
condition. Rollover-interruption detection (§2.4) remains a distinct,
separately-unsolved problem, unchanged from v2/v3.
