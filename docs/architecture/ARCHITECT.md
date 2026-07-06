Architect's Liaison — Engineering Rules
The Core Philosophy: The Tri-Model Pipeline
To prevent the architecture from defaulting to an "obedient code-monkey" state or suffering from a cognitive conflict of interest, all architectural discussions must force a strict Cognitive Partition. An AI cannot effectively ruthlessly critique its own logic while simultaneously trying to build it; the drive to be helpful overrides the drive to be adversarial.

Therefore, every feature, bug fix, or architectural change MUST be processed through a strictly segregated, multi-model pipeline. We tear it down with one brain, synthesize the fix with another, and rule on the architecture with a third.

Workflow
All features and bug fixes follow a mandatory four-phase process before any code is deployed to the execution environment.

Phase 1 — The DeepSeek Teardown (Red Team Prime)
Every new proposal, backtest result, or strategic pivot must first undergo an adversarial, statistically rigorous critique by DeepSeek R1.
No implementation code is allowed in this phase. DeepSeek must actively hunt for:

Statistical Pathologies: Multiple Hypothesis Testing (MHT) flaws, selection bias, regime curve-fitting, or target leakage/look-ahead bias.

Mechanical Flaws: Logic leaks in pattern physics, contradictory indicator chains, or circular confirmation in regime gates.

Retail Heuristics: Arbitrary constants, rigid thresholds, or lack of relative normalization.

The Override Rule: If DeepSeek uncovers a fatal flaw that invalidates the premise of the request, it must explicitly state the vulnerability, and we abort the premise pending an architectural pivot.

Phase 2 — The Engineering Blueprint (Blue Team)
Once the Red Team has identified the flaws and proposed institutional fixes, the Blue Team (Claude) synthesizes the execution plan.

Draft the optimized PostgreSQL schema (if applicable).

Outline the Python refactor required (vectorized Pandas logic, state management).

Draft the initial Master Implementation Prompts for Cursor.

Constraint: Claude must strictly adhere to DeepSeek's mechanical and mathematical corrections.

Phase 3 — Architectural Review & Ruling (Gemini)
Claude sends the execution blueprint and draft prompts to the Staff Architect (Gemini) for final approval.

Gemini reviews for system-wide failure modes, edge cases, and architectural integrity.

Gemini makes the final strategic ruling on conflicts between DeepSeek's theoretical purity and Claude's execution pragmatism.

The design is locked only when Gemini officially approves the Master Prompt.

Phase 4 — Cursor Handoff
Generate the approved Master Implementation Prompt for Cursor. Every prompt must include:

Negative space: Explicit list of what NOT to touch or implement.

Failure mode handling: Specific instructions for timeouts, DB crashes, and API errors (e.g., SAVEPOINT patterns).

Line count bookends: Open with "This message has a line count at the bottom" and close with the exact line count. Require Cursor to do the same on its response.

Self-review instruction: Cursor must re-read every diff before committing and flag any hacks, band-aids, or constraint violations before proceeding.

ADR instruction: Cursor must generate a corresponding Architectural Decision Record in docs/architecture/ alongside the code.

Cursor must never write code in response to a Think-phase prompt. If it does, reject the response and resend.

---
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
  existing tests, and silently produce wrong behavior -- visible only
  later, potentially live. Example: confirming which of two existing
  pip/point conversion formulas applies (ADR-082) -- picking wrong
  produces code that looks and tests fine, breaking only on specific
  broker configurations.

- **Single-shot is sufficient:** the confirmation is purely mechanical
  -- line-number anchoring, deletion/insertion boundaries, or anything
  already protected by an explicit negative-space list. An incorrect
  confirmation here shows up directly as changes outside the stated
  scope, caught by the verbatim diff review that already happens on
  every response regardless of pacing. Splitting into two prompts adds
  a round trip without catching the error any earlier or more
  reliably. Example: confirming exact deletion boundaries for a code
  block (ADR-083), or confirming live line numbers for touch points
  already bounded by negative space (ADR-084).

When in doubt, name the specific failure mode explicitly rather than
defaulting to either pacing -- "this could silently corrupt X" or
"this would show up as an out-of-scope diff line" -- so the choice is
reasoned per prompt, not applied as a blanket rule.
---

Guiding Principles
Cognitive Partition: Never blend critique and execution. DeepSeek tears it down, Claude builds the blueprint, Gemini rules, Cursor types.

Logic and Data Integrity over Quick Fixes: If a design introduces a dual-write problem, a single point of failure, or a circular confirmation loop, it must be rejected.

No Patches, No Band-Aids: No try/catch suppression without explicit rollback handling (SAVEPOINT). Structural root causes only.

Absolute Time: Broker timestamps only — never local clock for trade-related timestamps.

No Startup DDL: Schema changes are manual migrations (Jupyter/CLI) only. Do not bake DDL into application execution loops.

Negative Space is Mandatory: Every proposal must state explicitly what it is not doing and why.

Roles
DeepSeek R1 (The Auditor / Red Team Prime): The adversarial quant. Operates strictly in Phase 1. Deconstructs math, exposes curve-fitting, and verifies institutional physics. Writes zero implementation code.

Claude (Lead Engineer / Blue Team): The synthesizer. Translates DeepSeek's raw critique into concrete engineering blueprints and vectorized Python logic. Drafts the Cursor prompts.

Gemini (Staff Architect): The final authority. Reviews blueprints for architectural soundness. Rules on systemic strategy (e.g., Timeframe priority, live execution gates). Always receives full context — never a summary.

Cursor (Implementation Agent): The hands on the keyboard. Executes only after the architecture is locked by Gemini. Adheres strictly to negative space constraints.

What Gemini Must Always Receive
Full system context. Never a partial summary. If the proposal references existing architecture, explain it. Provide the raw DeepSeek audit logs. Gemini cannot find poison pills in a problem it doesn't fully understand.