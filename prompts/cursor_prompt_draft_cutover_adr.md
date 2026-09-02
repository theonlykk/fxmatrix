This message has a line count at the bottom.

TASK: Draft the Unified V2 Engine cutover ADR — proposed, explicitly
NOT authorizing execution yet, per Gemini's ruling.

CONTEXT
Gemini approved drafting this ADR in parallel with the two remaining
gates (vaccine_rally GUI verification, Layer 4 demo drill), but ruled
execution stays blocked until both complete. This ADR documents the
full journey and results, and must state its own non-execution status
clearly and prominently, not just in a footnote.

OBJECTIVE

Confirm the actual next sequential ADR number from docs/architecture/
directly. Draft the ADR covering:

- Background: why this work happened (the _ref branch was abandoned,
  Gemini ruled to rebuild from live production, per the parameterization
  scope-ruling memo).
- Architecture: the preset/dispatch/cap-bridge design, briefly,
  referencing the design spec rather than repeating it in full.
- Implementation: Phase A and Phase B, both reviewed against real
  production source on the highest-risk sections.
- The two bugs found and fixed during parity testing: BC bc_now guard
  reversion, AB path ArrayCopy removal — describe each with its root
  cause and how it was confirmed fixed.
- Parity gate results: full three-pair table (GBPUSD 4/5, EURUSD 5/5,
  EURGBP 4/4 all runnable, vaccine_rally status per pair).
- Outstanding items before execution, stated clearly and prominently:
  (1) Khalid's personal GUI Strategy Tester verification of
  vaccine_rally for GBPUSD and EURGBP, (2) a live/demo reattach drill
  proving the ADR-102 halt gate and ADR-103 cap-publish-skip sequencing
  under a genuine orphan condition — mandatory per Gemini's ruling,
  not optional.
- Explicit status line at the top of the ADR: "PROPOSED — EXECUTION
  BLOCKED pending the two items above. This ADR documents the
  implementation and verification work; it does not itself authorize
  replacing production."

NEGATIVE SPACE
This ADR does not authorize cutover. No production file changes. No
VPS interaction. Do not commit the unified-engine implementation files
in this task — that's the separate commit task already sent. Do not
commit or push the ADR itself yet either — return it for review first.

FAILURE MODES
If the real next ADR number has changed since last checked, use the
actual current one, don't assume.

SELF-REVIEW
Confirm: real next ADR number confirmed from directory; status line
stating execution is blocked appears prominently at the top, not
buried; both outstanding items stated clearly; full three-pair results
included; both bug fixes described with root cause; complete ADR
content returned verbatim for review; nothing committed.

Line count: 58
