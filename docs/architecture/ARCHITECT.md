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

### Machine Topology

Three machines, three distinct roles. Do not assume capabilities or
safety rules transfer between them without checking this section.

#### Desktop
Repo lives at `d:\fxmatrix`, edited directly by Khalid or Cursor — this
IS the working copy, not a clone that needs pulling. The MT5 terminal
here is used for compiling and Strategy Tester only; it is never
attached to a live or demo trading chart. Because nothing here is ever
live, **the flat-chart rule does not apply to desktop compiles** — they
are safe to run at any time regardless of what the VPS account is
doing.

#### VPS
Separate git clone at `C:\fxmatrix` (see Infrastructure Constants for
host details). Runs the actual live/demo trading instances. Cursor does
not have execution access to the VPS — deliberately, to keep the one
machine with real trading consequences off the automated-agent surface.
Code reaches the VPS only via `deploy.ps1` pulling from git; the VPS
never pushes.

#### Surface
Separate machine, used for longer-running Python compute. No MT5
installed currently — Python only. Connected via a mounted network
share (`S:\`, readable from desktop). Cursor does not currently have
execution access to the Surface; pulling results via `S:\` is a
desired capability, not yet built. Installing MT5 there has been
discussed as a future option, not current practice.

### Sync Scripts

#### `deploy.ps1` (VPS)
`git pull origin main`, then `xcopy` into `MQL5\Experts\fxmatrix\`,
then a post-copy SHA256 verification confirming every copied file
matches the just-pulled repo content — added after identifying the
xcopy step could silently fail or partially fail on a locked file with
no error surfaced. Only destination: Experts, since only the three
production EAs run on the VPS.

#### `desktop_sync.ps1` (desktop)
No git pull — the desktop repo is already the working copy. Copies the
three production `.mq5` files plus 9 shared `.mqh` headers into
`MQL5\Experts\` (flat, no subfolder), and `fxmatrix_v2_tests.mq5` plus
that *same* 9-header set into `MQL5\Scripts\`. Both destinations are
independently SHA256-verified against the repo after copying.

Two destinations are required, not optional: MQL5 resolves a quoted
`#include` relative to the compiling file's own folder, so Scripts
needs its own physical copy of every header the test file depends on —
there is no way to share one copy across both folders via a normal
relative include.

The 9-header shared set was derived from the actual `#include`
dependency graph of all four source files (direct + transitive
includes), not assumed. If any of the four files' includes change in
the future, re-derive this list from source rather than hand-editing it
from memory — a stale assumed list is exactly what caused a 58-error
compile failure the first time this was attempted without it.

#### Desktop/VPS folder structure is NOT symmetric
See **Content-Level Verification Before Every Compile** below for the
full desktop vs VPS path layout (flat `Experts`/`Scripts` on desktop
vs `Experts\fxmatrix\` on VPS).

### Content-Level Verification Before Every Compile

The repo (`d:\fxmatrix\ea`) and the MT5 terminal's compile folder are
two physically separate copies of the same source files, kept in sync
only by manual copy. They went out of sync repeatedly during
development — a stale terminal copy compiles cleanly (0 errors,
0 warnings) exactly like the correct one would, because a stale file
is still syntactically valid; it simply doesn't reflect the intended
change.

**Desktop vs VPS paths are not symmetric.** The desktop terminal uses
a flat layout — all fxmatrix files sit directly in `MQL5\Experts\` and
`MQL5\Scripts\` root (no `fxmatrix\` subfolder), alongside many
unrelated files from other projects. The VPS uses
`MQL5\Experts\fxmatrix\` as the deploy target (see `deploy.ps1`).
Unit tests live in `MQL5\Scripts\` on desktop, not in Experts. Do not
assume one layout when reasoning about the other.

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

### VPS Live Deployment Sequence

1. Confirm the account is 100% flat — zero open positions, zero
   pending orders, across all three instances.
2. Turn AlgoTrading off.
3. Delete any resting limit orders manually if present.
4. Detach the EA(s) from their chart(s).
5. Run `deploy.ps1`.
6. Compile in MetaEditor.
7. Turn AlgoTrading back on.
8. Reattach the EA(s).

This sequence, and the flat-chart precondition specifically, governs
VPS/live-demo instances only — see Machine Topology above for why
desktop compiling is exempt.

### Cap-Enablement Gate: Cross-Instance Global Variable Reset

The original finding (EURGBP's `OnInit` unconditionally resetting
shared cross-instance trigger GVs) was fixed by ADR-103, which removes
that reset entirely rather than conditionally gating it.

However, DeepSeek's Phase 1 audit of that fix surfaced a **separate,
still-open reason** the gate must remain in place: when a halted
instance skips its own GV publish, the resulting value can be either
stale in direction/magnitude (positions changed while the instance was
down) or, if no prior value ever existed, a genuinely missing key —
which the cap modules currently read as a permissive zero. Both are
unsafe for an active exposure cap.

**Rule stands unchanged** — `InpGbpCapThreshold` and
`InpEurCapThreshold` must remain at 0 — but for an updated reason: the
destructive-reset defect is fixed; the stale/missing-GV-reads-as-zero
problem is not.

**Traceability:** Original gate ruling — Gemini, architectural ruling
on audit Finding #4, 2026-07-31. Destructive trigger-reset fix —
ADR-103 (2026-08-02). Remaining stale/missing-GV limitation — ADR-103
§Known deferred limitations; DeepSeek Phase 1 mechanical audit of the
ADR-102/103 halt-gate and cap-GV fixes, 2026-08-02 (see ADR-102).

### Testing and Verification

#### Running `fxmatrix_v2_tests.mq5`

This is a genuine MT5 **Script** (`#property script_show_inputs`,
`OnStart()`), not an Expert Advisor. **Do not attempt to run it through
Strategy Tester** — the tester only tests EAs; Scripts have no
`OnInit`/`OnTick` handlers for it to call. To run it: drag or
double-click it onto any open chart (a chart window must be focused
first), confirm the Script Properties popup that appears, and check
the Toolbox's **Experts tab** (not the tester) for PASS/FAIL lines per
test plus a final summary count.

#### `analyze_mt5_report()` — what it actually is

A Python helper that parses an MT5 Strategy Tester HTML export and
prints a structured summary: in-test vs. full P&L (excluding forced
end-of-test closures), trade counts by side (correctly handling the
V2_Exit direction inversion — a sell-tagged V2_Exit closes a LONG, a
buy-tagged one closes a SHORT), net exposure tracking, and a settings
sanity-check extraction. **It is a summarizer/comparison tool, not an
automated pass/fail gate** — a human reads and judges the printed
output. Do not describe backtest verification as automated because
this tool exists.

#### Push / Commit Workflow

The desktop repo's working tree accumulates a large volume of
experimental/temp files over time — `git status` can run into the
thousands of lines. Standing practice: before staging anything broad,
produce a categorized status report — group (a) files clearly part of
the specific work being pushed, group (b) everything else, explicitly
enumerated rather than summarized away — and get explicit scope
confirmation before staging anything. **Never `git add .` or blind
`git add -u`.** Stage only the confirmed file list, by exact name.

Either Khalid or Cursor may perform the push — no fixed rule on who; in
practice Cursor does it more often, given how large `git status`
typically runs. The VPS never pushes; it only pulls via `deploy.ps1`.

#### Cursor-Driven Backtesting

Cursor can run Strategy Tester backtests headlessly and this is
generally reliable. One resolved historical gotcha: headless runs
could fail or misbehave if the MT5 terminal was also open on the
desktop at the same time — keep the terminal closed during a
Cursor-headless run. One open minor wrinkle: very old backtest date
ranges occasionally have data availability issues.

Two-tier verification model: Cursor's headless runs are trusted for
exploratory/preliminary work. Khalid's own hands-on desktop compile
and Strategy Tester run remains the final personal verification gate
before anything is treated as ready to push or deploy.

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
