# ADR-092 Addendum: Refined Add-Delay Asymmetry (First-Time Depth vs. Reload)

**Status: PROPOSED REFINEMENT to a just-locked design (Gemini Phase 3 cleared ADR-092 without this).** This is a genuine behavioral change to the production build spec, not an implicit part of what was already validated — flagged explicitly so it doesn't get folded into Stage A silently.

**Author:** Khalid (concept), written up by Claude.
**Date:** 2026-07-14

---

## 1. What's already confirmed to exist (not this proposal)

Source-verified against `fxmatrix_v2_long.mq5` during the duplicate-fill diagnostic:

- **L0 (flat-state entry)** only re-quotes via `OnNewBar()` — gated to once per real 5-minute bar, and only when the stack is completely empty.
- **`EnsureAddNext()`** (both first-time adds and reload adds) fires **immediately** on any qualifying event — no bar-cadence delay at all, on either path.

So today, the only delay anywhere in the system is the L0-from-fully-flat case. Both first-time adds *and* reloads currently fire without any deliberate pause.

## 2. What's actually being proposed — new behavior, not a restatement of the above

**Introduce a deliberate delay specifically before a first-time add that extends the stack to a depth it has never reached before in the current pod's lifecycle** — while leaving reload adds (re-establishing a layer via `last_exit_price` after an exit) exactly as fast as they are today.

**Rationale, in Khalid's framing:** reaching a new maximum depth for the first time (e.g., layer 3 being touched for the first time) is evidence the market has been running with some persistence in one direction — worth pausing to confirm that persistence before deepening further into it, rather than committing to layer 4 immediately. An **exit**, by contrast — even an exit of a layer at that same depth — is evidence of a favorable bounce, consistent with range-bound/choppy conditions where fast re-engagement is exactly the right behavior, not a risk to guard against.

## 3. Why this needs a precise trigger definition, not just "flat vs. not-flat"

This is **not** the same distinction as the currently-confirmed L0-gating rule. The relevant question is event-type, not stack-emptiness:

- **First-time depth extension** (the pod has never before reached this depth level) → apply the new delay.
- **Reload** (re-establishing a layer via the `last_exit_price` path, following an exit) → no delay, as today.

**Open implementation question, not yet resolved:** the code's `last_exit_price` state clears immediately after a successful reload fill — it does not persist as a durable "this pod has been through a reload cycle" flag. This means distinguishing "first time reaching depth N" from "reload back to a depth previously visited" may require new state (e.g., tracking the pod's maximum depth reached so far, separate from current depth) rather than something that falls out of the existing `last_exit_price` gate for free. **This needs to be confirmed against source, not assumed**, before any implementation.

## 4. Open design questions

1. **What form does the delay take?** A fixed time duration (e.g., wait N seconds/bars after crossing into a new max depth before allowing the *next* add)? Or some confirmation condition (e.g., require price to hold beyond the new depth's entry level for some duration)? Not yet decided.
2. **Does the delay apply once per pod (only the very first time any new max depth is reached) or every time a new max depth is reached** (i.e., also delay before layer 5 if layer 5 is also a first-time depth, even if layer 3â†’4 already had its delay)? Most consistent reading of the rationale is the latter — every genuine deepening gets paused, not just the first one — but worth confirming.
3. **What's the actual state representation needed** to distinguish "first-time depth extension" from "reload," given `last_exit_price`'s existing clear-after-one-use behavior (Section 3)?

## 5. Process note

This changes behavior in a design Gemini just formally cleared for MQL5 implementation (ADR-092, Phase 3 lock). Recommend a quick sanity pass — not necessarily a full DeepSeek Phase 1 given the scope is narrow, but at minimum flagging to Gemini directly that this is being added, given the "unvalidated complexity" thesis ADR-092's whole premise rests on. Should not be silently folded into Stage A's build spec without that acknowledgment.

## 6. Next steps

- [ ] Confirm exact code-level mechanism for tracking "max depth reached this pod" against source (Section 3's open question).
- [ ] Decide delay form and per-pod-vs-per-depth-extension scope (Section 4, items 1–2).
- [ ] Flag to Gemini as an amendment to the just-cleared ADR-092 design before Stage A implementation proceeds with this included.
