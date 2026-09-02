# Phase 1 Round 6 — "Drain the Swamp": Can Anything Bypass a Halt Gate?

This round follows a different protocol than Rounds 1-5, per Gemini's
explicit ruling (2026-08-04). Read this framing carefully before
auditing v7 below — the acceptance criteria have changed.

## The rule change

**A halt is a PASS, not a failure.** This design is not required to
successfully reconstruct through every anomaly, manual intervention,
data gap, or broken execution chain. It is required to never silently
resume management on wrong or corrupted state. Every prior round found
real bugs by asking "does this design correctly reconstruct X" — that
question is now secondary. The question that matters for this round is
different and singular:

**Is there any edge case, race condition, or broker anomaly that can
BYPASS the halt gates below and cause the engine to silently resume on
wrong or corrupted state?**

Do not flag places where the design chooses to halt on a scenario it
could theoretically have reconstructed more cleverly. Halting is
correct behavior, not a gap. Only flag a finding if you can construct
a concrete state that:

1. Does not trigger any of the halt conditions listed in §4 (the full
   ambiguity checklist, 27 items) or any of §0/§2.4's specific
   conditions, AND
2. Produces a reconstruction that is actually wrong — different from
   what the pre-crash in-memory state genuinely was — not merely
   incomplete or conservative.

## What changed since Round 5, briefly, for context

Round 5 found two structural issues. Finding A (exit-order
misassignment via a legitimate placement-failure path) got a real
structural fix: global one-to-one assignment across all layers with
interval-bounded eligibility, replacing the independent per-layer
matching that allowed the misassignment. Finding B (orphaned hedge from
a non-standard entry closure) got a deliberate scope decision, not a
technical fix: any entry-magic position closed by anything other than
a verified CloseBy pairing — anywhere in the full bounded lookback, not
just since the anchor — now forces an unconditional halt. Gemini ruled
against building lineage-tracing to safely reconstruct through that
scenario; the design refuses to attempt it instead. Four smaller
corrections (temporal tolerance, rollover-tolerant exit_target, the
dual-zero anchor requirement, the sentinel's mechanism-level
specification) are also folded in below.

## The closure condition

If you cannot construct a state satisfying both criteria above — i.e.,
every state you can construct that would produce a wrong reconstruction
also hits one of the listed halt conditions — say so plainly. That
result closes this design for Gemini's final sign-off. This is not a
softer bar than prior rounds; it's a differently-shaped one. Prior
rounds asked you to find every way this could be more correct. This
round asks you to find the one way it could be silently wrong. Both are
real adversarial work — don't pull punches because the framing changed.

No implementation code in your response.

---

# State Reconstruction Engine — Design Sketch v7 (Round 5 fixes + Gemini's fail-closed simplification)

Status: REVISED per Round 5's BLOCKING verdict and Gemini's rulings
(2026-08-04): Finding A's global one-to-one assignment approved as
specified; Finding B's full lineage-tracing rejected in favor of a
broadened, unconditional fail-closed halt — halting is a pass, not a
failure, and this design does not attempt to safely resume through
non-standard position closures. Four straightforward Round 5
corrections folded in throughout. This is the last round under the
prior audit protocol — Round 6 shifts to Gemini's "Drain the Swamp"
directive (see the accompanying Round 6 memo): the design is closed
and approved if DeepSeek cannot prove a silent state-corruption path
through the halt gates below, full stop.

Changes from v6, at a glance: §1.2 is a structural rewrite — global
one-to-one assignment across all layers, not independent per-layer
matching. §2.2's anchor now requires zero managed positions of both
types. §2.4 replaces last round's narrow "ordinary close within
window" halt with a broadened, unconditional rule scanning the full
bounded lookback, and drops the lineage-tracing requirement DeepSeek
proposed — Gemini's fail-closed philosophy makes it unnecessary. §3's
sentinel check is now specified as an explicit, first-checked branch
at the mechanism level.

---

## 0. Pre-check — CloseBy remnant detection (fast path, unchanged)

Before any other logic: scan currently open positions for this side's
exit magic. If any exist, halt immediately.

## 1. Hot state reconstruction (Part A)

Applies only once §0 finds no exit-magic positions on this side.

**1.1 / 1.1a / 1.1b — Layer order, position-type checks.** Unchanged.

**1.2 — Exit ticket assignment (structural rewrite: global one-to-one
assignment, interval-bounded eligibility).**

Round 5 found that loosening price to a single-candidate exception
reopened a real, production-grounded failure: a layer whose exit
genuinely failed to place (a known path with its own `NEEDS_PLACE`
self-healing) can have a *different*, newer layer's real exit order
misassigned to it, since the newer order still passes every remaining
per-layer check. The fix is structural, not another field added to the
per-layer check:

- **Eligibility interval, not just "after."** A candidate exit order is
  eligible for a given layer only if its placement time falls within
  `[this layer's open time, the next layer's open time)` — the next
  layer in open-time order, or "now" if this is the most recently
  opened layer. This alone prevents a newer layer's order from ever
  being eligible for an older layer, closing the specific path Round 5
  found.
- **Global one-to-one assignment, not per-layer independent matching.**
  Solve assignment across all currently-open layers and all candidate
  exit orders simultaneously: each order assignable to at most one
  layer, each layer to at most one order, matching on direction,
  symbol, volume, and interval eligibility. If more than one valid
  complete assignment exists — i.e., the solution isn't unique when
  considered globally, not just checked one layer at a time — halt
  (§4). Two layers independently appearing to "uniquely" match the same
  order is exactly the case this catches that per-layer checking
  cannot.
- Layers with zero eligible candidates after the global solve remain
  valid for `exit_ticket = 0` / `NEEDS_PLACE`, per existing fix #2
  (unmatched-order handling is unaffected by this change).
- Price is no longer a hard gate (unchanged reasoning from v6 —
  rollover can legitimately modify it), but is no longer needed as a
  disambiguator either, since the interval + global-uniqueness
  combination is what actually closes the ambiguity, not price
  proximity guessing between rollover-modified and stale candidates.

**1.2a — Unmatched exit orders.** Unchanged.

**1.3 — Add/reload ticket.** Unchanged.

**1.4 — Pending entry-order consistency.** Unchanged.

**1.5 — Read-only discipline.** Unchanged — confirmed clean across
four audit rounds now.

**1.6 — Partial-fill, input-drift, and rollover-tolerant exit_target
(new sub-item).**

Round 5 found v6 didn't specify what a reconstructed layer's
`exit_target` should be when its matched exit order's price doesn't
match the naive `entry_price + ExitPips` formula (a legitimate rollover
modification). If the reconstructed layer keeps the naive target while
`exit_ticket` points to the modified order, a later replace-on-loss by
the audit loop would silently undo the rollover adjustment. Corrected:
when a matched exit order's price doesn't equal the naive formula, the
reconstructed layer's `exit_target` is set to the **order's actual
current price**, not the formula result — explicitly recorded as
rollover-tolerant state, not a discrepancy to paper over.

Partial-fill and input-drift triggers otherwise unchanged from v6.

## 2. Path-dependent state via hedge-to-entry mapping (Part B)

**2.1 — The reframe.** Unchanged.

**2.2 — Anchor-finding (corrected: zero positions of both types
required).**

v6 corrected the volume-tracking definition to entry-magic position
IDs, closing the raw-magic corruption Round 4 found. Round 5 found a
further gap: the anchor walk could read "zero entry-magic volume"
while an orphaned exit-magic (hedge) position is still open — that is
not a true flat state, and treating it as one is wrong. Corrected: the
anchor requires zero **managed positions of both types** — zero
entry-magic and zero exit-magic — not entry-magic volume alone. An
open exit-magic position at what would otherwise read as the anchor
point invalidates that anchor; the walk continues further back, or
fails within the bound (§4) if no genuine dual-zero point is found.

**2.3 — Hedge-to-entry mapping algorithm.** Steps 1-5 unchanged from
v6 (build entry/hedge tables, group by `DEAL_ORDER`, resolve pairs, use
hedge open time for sequencing, reload-reset rule in replay — all
confirmed correct by Round 5 with no further changes).

**2.4 — Halt conditions specific to this mapping (revised: v6's
narrow ordinary-close halt replaced by Gemini's broadened, unconditional
rule; lineage-tracing not implemented, per Gemini's ruling).**

Unchanged from v5/v6:
- Any hedge-open with no discoverable CloseBy pairing within the
  bounded lookback.
- Any `DEAL_ORDER` group of `DEAL_ENTRY_OUT_BY` deals that isn't
  exactly two.
- A hedge closed by an ordinary `DEAL_ENTRY_OUT` while its
  corresponding entry position remains open.
- Missing or zero `DEAL_POSITION_ID` or `DEAL_ORDER` on any deal this
  mapping depends on.
- Any `DEAL_ORDER` group of exactly two `DEAL_ENTRY_OUT_BY` deals that
  doesn't resolve to exactly one entry-table position and one
  hedge-table position (v6, unchanged).

**Replaced (broadened, per Gemini's ruling — supersedes v6's narrower
"ordinary close within window" condition):**

- **Any entry-magic position within the full bounded lookback — not
  just since the anchor — that was closed by anything other than the
  standard, verified CloseBy pairing sequence** (an ordinary
  `DEAL_ENTRY_OUT`, a manual close, or a stop-out/margin-call closure,
  `DEAL_REASON_SO`) forces an immediate halt. This is deliberately
  unconditional and does not attempt to determine whether the
  irregular closure is actually safe to reconstruct through — per
  Gemini's ruling, an externally-tampered-with position means the
  operational state is no longer trusted, full stop. Scanning the full
  bounded lookback (not only since the current anchor) is deliberate:
  the attack this closes involves an irregular closure that can predate
  the anchor while its hedge remnant survives into the current window,
  so the scan must cover the same range the anchor-finding walk itself
  is bounded by.

This replaces the lineage-tracing approach DeepSeek proposed in Round
5 (verifying each hedge's opening deal traces back to a matching exit
order belonging to its paired entry position). Gemini's ruling: that
engineering investment is disproportionate to a scenario involving
external tampering or broker-side liquidation, which this design
should refuse to reconstruct through at all, not attempt to safely
resolve.

**2.5 — Rollover retry state.** Unchanged — still a distinct, unsolved
problem. Its effect on exit-order prices is tolerated by §1.2/§1.6;
the retry mechanism itself remains unmodelled.

## 3. Cap GV publish sequencing — sentinel, specified at mechanism level

Round 5 found v6's sentinel policy correct in principle but
underspecified: production cap modules compute net exposure via plain
arithmetic on numeric GVs, so a sentinel value fed into that same
arithmetic unmodified can still produce a permissive result (two
sentinels on opposite sides cancelling to a false net of zero, or a
sentinel small enough to fall under a configured threshold). Corrected,
specified explicitly:

- Every cap-read function must check, as its **first operation, before
  any other logic including threshold checks**: is this side's GV
  either the reserved sentinel value or absent? If yes, block any add
  referencing that side and return immediately — do not proceed to any
  net-exposure arithmetic, and do not evaluate this check after or
  alongside a cap-threshold-disabled short-circuit that might otherwise
  skip it.
- This is a genuine, deliberate change to today's absent-GV behavior
  (previously permissive, now blocking) — Gemini's ruling, stated
  explicitly, not an implicit side effect.
- Sentinel written as the very first action in `OnInit` for a side with
  open positions, before reconstruction begins; cleared and replaced
  with the real reconstructed count only after full validation (§5)
  passes.
- Trigger GVs unaffected, unchanged from ADR-103.
- Residual staleness gap (crash without terminal restart) remains an
  explicitly accepted risk, per Gemini's earlier ruling — not
  addressed by a heartbeat mechanism in this design.

## 4. Ambiguity checklist (updated for v7)

Items 1-22 from v3/v4/v5 unchanged. Item 23 (v6) is superseded — see
§2.4's broadened replacement above, which is the new operative rule for
irregular entry-magic closures. Items 24-25 unchanged. New:

26. Global exit-order assignment across all layers is not unique — more
    than one valid complete matching exists under the interval and
    field constraints (§1.2).
27. The anchor-finding walk reaches a point of zero entry-magic volume
    while an exit-magic (hedge) position remains open — not a genuine
    flat state (§2.2).

## 5. Validation

Unchanged in principle. Restated: this validates layer positions,
tickets, and entry prices against direct broker reads — it does not
and cannot validate `last_exit_valid`, `current_add_pips`, or the
correctness of the exit-order assignment itself against any
independent source. Correctness there depends entirely on §1.2 and
§2.3's logic being right, which is why adversarial pressure on those
sections specifically has mattered more than on the parts §5 directly
checks.

## 6. Scope (routine sharing)

Unchanged.

## 7. Verification path

Unchanged from v5/v6 — the live/demo drill needs to prove successful
reconstruction through real CloseBy history, including a reload-fill
scenario. Given §2.4's broadened halt, worth adding a scenario
confirming the engine correctly halts (does not attempt reconstruction)
when a manual or stop-out closure is deliberately introduced into a
side's history within the drill.

## 8. What this revision does not resolve, and the new closure criterion

Rollover retry state itself (§2.5) remains unsolved — only its effect
on exit-order prices is tolerated. The cap-GV staleness gap (§3) is an
accepted residual risk. This design does not attempt to reconstruct
through manual intervention, forced liquidation, or any other
non-standard position closure — it halts on all of them, by design,
per Gemini's fail-closed ruling.

Per Gemini's ruling on audit trajectory: this design is considered
closed and approved if Round 6 cannot demonstrate a path by which any
of the above states — or any other broker anomaly, race condition, or
edge case — bypasses a halt gate and causes silent resumption on
wrong or corrupted state. A halt is a pass. This design is not required
to safely recover from every anomaly; it is required to never
mismanage capital while believing it has.
