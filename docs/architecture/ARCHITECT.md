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

---
## ADR Content Must Be Included in Full

Stating an ADR file's name and line count is not sufficient -- the
complete verbatim content must be included directly in the response,
the same way a full diff is required rather than a description of one.
"See repo for full content" is not acceptable; it defeats the purpose
of the review step, since the whole point is confirming what was
actually written before trusting it, not what Cursor says it wrote.

This applies to every response that creates or modifies an ADR file,
with no exception for length.
---

---
## Operational Safety Rules

### Content-Level Verification Before Every Compile

The repo (`d:\fxmatrix\ea`) and the MT5 terminal's compile folder are
two physically separate copies of the same source files, kept in sync
only by manual copy. They went out of sync repeatedly during
development — a stale terminal copy compiles cleanly (0 errors,
0 warnings) exactly like the correct one would, because a stale file
is still syntactically valid; it simply doesn't reflect the intended
change.

**Desktop vs VPS paths are not symmetric.** The desktop terminal uses
a flat `MQL5\Experts\` folder (no `fxmatrix\` subfolder). The VPS
uses `MQL5\Experts\fxmatrix\` as the deploy target (see `deploy.ps1`).
Unit tests live in `MQL5\Scripts\` on desktop, not in Experts.

**Note:** A prior example in this section referenced
`D:\MT5Data\81A933A9AFC5DE3C23B15CAB19C63850\MQL5\Experts`. That path
was never real on either machine — it was a phantom placeholder.

**Rule:** Before every compile that matters (any change intended to be
verified, tested, or deployed), confirm the repo and terminal copies
are byte-identical via content hash — never by file size or
modification timestamp, both of which have separately produced false
confidence during this project's history.

```powershell
$repo = "d:\fxmatrix\ea"

# Desktop (Khalid) — flat Experts, no fxmatrix subfolder
$termDesktop = "C:\Users\Khalid Khan\AppData\Roaming\MetaQuotes\Terminal\81A933A9AFC5DE3C23B15CAB19C63850\MQL5\Experts"

# VPS (Administrator) — deploy.ps1 writes into Experts\fxmatrix\
$termVps = "C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\81A933A9AFC5DE3C23B15CAB19C63850\MQL5\Experts\fxmatrix"

$term = $termDesktop   # or $termVps when on the VPS
foreach ($f in @("file1.mq5", "file2.mqh")) {
    $r = (Get-FileHash "$repo\$f" -Algorithm SHA256 -ErrorAction SilentlyContinue).Hash
    $t = (Get-FileHash "$term\$f" -Algorithm SHA256 -ErrorAction SilentlyContinue).Hash
    Write-Host "$f : match=$($r -eq $t)"
}
```

If mismatched, copy the repo version over before compiling, then
re-verify the hash before treating any subsequent compile or test
result as meaningful. A clean compile against a stale file is not
evidence of anything.

A related habit, same root cause: always use MetaEditor's **File →
Open** on the explicit terminal path before compiling. A tab left open
from an earlier session can silently compile old content even after
the underlying file has been correctly updated on disk.

### No Recompile or Reattach on a Live/Demo Instance Unless the Chart Is Confirmed Flat

**Finding:** `OnInit` does not rebuild an EA's internal layer-tracking
state from actual broker positions on restart. If an EA is
recompiled, reloaded, or reattached while it holds open positions, the
existing orphan-detection guard halts the instance outright rather
than reconstructing state from broker truth. This requires manual
intervention to recover — it is not a momentary accuracy gap, it is a
full stop of that instance's trading.

Every production deployment prior to this rule's adoption succeeded
only because the affected chart happened to be flat at the exact
moment of reattach — this was never a checked precondition, and
should not be relied upon as one.

**Rule:** No recompile, reload, or reattach cycle may be executed on
any live or demo trading instance unless the target chart is confirmed
**100% flat** — zero open positions AND zero pending orders — at the
time of the action. This applies regardless of how small or
"logic-free" the change being deployed is (a pure logging addition is
not exempt).

**Backlog reference:** A "State Reconstruction Engine" — replacing the
current halt-on-orphan behavior with genuine state rebuild from live
broker data on restart — has been identified as the eventual proper
fix for the underlying gap this rule works around. Until that exists,
the flat-chart precondition is the operative safeguard and should not
be skipped even under time pressure or for changes believed to be
low-risk.

### Cap-Enablement Gate: Cross-Instance Global Variable Reset

**Finding:** `fxmatrix_v2_eurgbp.mq5`'s `OnInit` unconditionally
resets the shared cross-instance global variables
`V2GBP_CAP_TRIGGERS` and `V2EUR_CAP_TRIGGERS` to zero. GBPUSD and
EURUSD run on the same terminal and depend on this state for the
cross-pair exposure caps (ADR-092 GBP cap, ADR-100 EUR cap). An
EURGBP restart while the caps are active would silently erase the
other two EAs' cap-trigger history — corrupting the exact risk
control the caps exist to provide.

**Rule:** `InpGbpCapThreshold` and `InpEurCapThreshold` must remain
at 0 (disabled) in every production and dry-run environment until
`OnInit` is refactored to remove the destructive reset of shared
cross-pair global variables. Raising either threshold above 0 before
that fix ships would silently defeat the cap the moment any EURGBP
restart occurs.

**Status:** Currently non-blocking — both thresholds already sit at
0 for unrelated calibration reasons. This rule exists so that stays
true on purpose once the caps are ready to be enabled, not by
coincidence.

**Ruling reference:** Gemini, architectural ruling on audit Finding
#4, 2026-07-31.

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