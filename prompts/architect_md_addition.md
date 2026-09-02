## Prompt Pacing: The Silent Error Test

Every Cursor prompt that pairs a confirmation step with implementation
instructions must be evaluated against one test before deciding whether
they can share a single response or require a strict two-step split
(confirmation sent alone, implementation withheld until reviewed):

**Would an incorrect confirmation produce output that still looks
correct under normal diff and negative-space review, or would it be
self-evidently wrong the moment the diff is read?**

- **Mandatory two-step (strict halt):** the confirmation involves
  mathematical conversions, unit assumptions, or hidden scope/state
  variables where an incorrect assumption would compile cleanly, pass
  existing tests, and silently produce wrong behavior — visible only
  later, potentially live. Example: confirming which of two existing
  pip/point conversion formulas applies (ADR-082) — picking wrong
  produces code that looks and tests fine, breaking only on specific
  broker configurations.

- **Single-shot is sufficient:** the confirmation is purely mechanical
  — line-number anchoring, deletion/insertion boundaries, or anything
  already protected by an explicit negative-space list. An incorrect
  confirmation here shows up directly as changes outside the stated
  scope, caught by the verbatim diff review that already happens on
  every response regardless of pacing. Splitting into two prompts adds
  a round trip without catching the error any earlier or more
  reliably. Example: confirming exact deletion boundaries for a code
  block (ADR-083), or confirming live line numbers for touch points
  already bounded by negative space (ADR-084).

When in doubt, name the specific failure mode explicitly rather than
defaulting to either pacing — "this could silently corrupt X" or "this
would show up as an out-of-scope diff line" — so the choice is
reasoned per prompt, not applied as a blanket rule.
