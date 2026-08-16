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

**Source-Grounding Mandate for teardowns of EXISTING mechanisms (ratified
Gemini, 2026-08-14):** An adversarial teardown of an already-built
mechanism must either be provided with direct source excerpts of that
mechanism, or be explicitly constrained to assessing methodology,
statistical design, and specification consistency. A teardown of existing
code that runs without source will hallucinate attack vectors against
assumed (wrong) internals. Empirically demonstrated this session: the BCC
teardown was commissioned AFTER a source read and returned 4/4 valid
findings with zero over-flags; the earlier V2.5 mechanism teardown ran
spec-blind and produced largely invalid mechanism reds. Ground the
teardown in source, or scope it to methodology — never let it guess at
internals.

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
three production `.mq5` files plus 11 shared `.mqh` headers into
`MQL5\Experts\` (flat, no subfolder), and `fxmatrix_v2_tests.mq5` plus
that *same* 11-header set into `MQL5\Scripts\`. Both destinations are
independently SHA256-verified against the repo after copying.

Two destinations are required, not optional: MQL5 resolves a quoted
`#include` relative to the compiling file's own folder, so Scripts
needs its own physical copy of every header the test file depends on —
there is no way to share one copy across both folders via a normal
relative include.

The 11-header shared set is derived from the actual `#include`
dependency graph of all four build targets (direct + transitive
includes), not assumed or hand-edited. At HEAD `155324f` the union is:
`fxmatrix_v2_api_counter.mqh`, `fxmatrix_v2_carry.mqh`,
`fxmatrix_v2_eur_cap.mqh`, `fxmatrix_v2_eurgbp_dual_cap.mqh`,
`fxmatrix_v2_exits.mqh`, `fxmatrix_v2_gbp_cap.mqh`,
`fxmatrix_v2_logic.mqh`, `fxmatrix_v2_signal.mqh`,
`fxmatrix_v2_sre_oninit.mqh`, `fxmatrix_v2_state_reconstruction.mqh`,
`fxmatrix_v2_telemetry.mqh`. If any of the four files' includes change,
re-derive this list from source rather than hand-editing it from memory
— a stale assumed list is exactly what caused a 58-error compile
failure the first time this was attempted without it.

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

### Recompile / Reattach on a Live/Demo Instance (SRE era)

**Rule (SRE era, ratified Gemini 2026-08-14):** A recompile/reload/reattach
on a live or demo instance no longer requires the chart to be 100% flat. The
State Reconstruction Engine (SHIPPED — see Parked Backlog) reconstructs managed
layer state from broker deal history on OnInit, so a NON-FLAT reattach of a
RECONSTRUCTABLE side is normal and expected. However:

- Before any deploy, pair the live book by magic and confirm it is orphan-free
  (no exit without a justifying position, no naked position).
- Be aware a lone-position side with no dual-flat anchor in its deal history
  will HALT_09 by design on reattach (HALT_09_ANCHOR_NOT_FOUND /
  SITE2_NO_DUAL_FLAT, ADR-113), and this is NOT visible in a positions/orders
  blotter (it depends on deal-history dual-flat). Either accept the halt and
  reconcile that side after (close + cancel its exit hedge + reattach), or
  confirm via deal history first. "Orphan-free book" does NOT imply
  "reconstructs clean."
- After reattach, verify each side's `sre_oninit halt_reason_label=NONE` (or a
  known by-design HALT_09) before turning AlgoTrading on; and, since BCC v1.1,
  confirm the `BCC | sweep=OK` heartbeat in the log.
- A halted side is fail-closed (does not trade); clean sides continue. This is
  safe, not an emergency.

*(Historical note: prior to the SRE, OnInit did not rebuild layer state from
broker truth, so a non-flat reattach halted the instance and required manual
recovery. The strict "100% flat before reattach" rule was the operative
safeguard through 2026-08-13. The SRE replaced it; this section supersedes that
rule. See ADR-105..113 for the SRE, ADR-113 for the genesis-orphan HALT_09
boundary.)*

### VPS Live Deployment Sequence

**Ratified Gemini 2026-08-14 (SRE era).**

1. Pair the live book by magic; confirm orphan-free and note any lone-position
   genesis sides (which will HALT_09 on reattach).
2. Turn AlgoTrading off.
3. (Only if intentionally flattening a side) delete that side's resting entry
   pending AND its exit hedge (9x3/9x4) — not a blanket step. Deleting the
   entry pending while leaving its resting exit hedge manufactures a HALT_21
   orphan state.
4. Detach the EA(s).
5. Run `deploy.ps1` (git pull + xcopy + SHA256 verify).
6. GUI-compile in MetaEditor (authoritative; CLI unreliable — see CLI/Headless
   Compile Reliability).
7. Reattach the EA(s); watch `sre_oninit` per side + the `BCC | sweep=OK`
   heartbeat.
8. Reconcile any by-design HALT_09 genesis sides if you want them live (close
   position + cancel its exit hedge + reattach that side).
9. Turn AlgoTrading on.

This sequence governs VPS/live-demo instances only — desktop compiling is
exempt (see Machine Topology; nothing on desktop is ever live).
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

#### CLI/Headless Compile Reliability

**Finding:** A real compile failure (24 errors, from an invalid
pointer-based parameter pattern in MQL5, which does not support
pointers to plain struct types) was silently missed by headless CLI
compile checks and only caught by Khalid's personal GUI compile.
Root causes, all confirmed directly:
- If MetaEditor's GUI is already open, a CLI `/compile:` invocation
  silently no-ops — exit code 0, no log written, no `.ex5` change —
  indistinguishable from success without checking further.
- MetaEditor's CLI exit codes are unreliable and can be inverted: a
  successful compile has been observed returning exit code 1, while a
  failed no-op returned exit code 0.
- A stale log file from an earlier successful run can be misread as
  the result of a current run if a fresh, uniquely-named log path
  isn't used each invocation.
- Unquoted paths containing spaces (e.g. a Windows user directory)
  can fail silently in process-invocation argument lists.

**Rule:** Any CLI/headless compile check must:
- Ensure no MetaEditor GUI instance is already running before
  invoking `/compile:` (kill the process first if needed).
- Use a fresh, uniquely-named log file per invocation, never reuse or
  assume a previous log path is current.
- Quote all paths containing spaces.
- Verify success by confirming the `.ex5` file's modification
  timestamp is newer than the newest included source file — never by
  trusting the exit code alone, and never by parsing a log without
  first confirming its own timestamp is current.

**Status:** Adopted following the 2026-08-03 incident. Khalid's
personal GUI compile remains the authoritative verification gate
regardless of any CLI/headless result — this finding does not change
that, it explains why it must stay that way.

#### Mandatory Calibration / Holdout Discipline

**Finding:** ADR-099's threshold lock-in selected a winning
configuration (1/3) across four stress windows and then treated
performance on those same four windows as verification — a classic
in-sample selection pattern. DeepSeek's audit of the EURGBP
native-sigma proposal identified this explicitly: with already-thin
margins (+1.7% exits, +0.7% aggregate P&L), in-sample selection risks
optimizing for window-specific noise rather than genuine structural
edge.

**Rule:** Any future parameter derivation, grid-spacing calibration, or
threshold selection must pre-register an explicit calibration/holdout
split before running the sweep:

- **In-sample calibration set:** at most half of the target stress
  windows, used to select candidate parameters.
- **Out-of-sample holdout set:** the remaining windows, evaluated strictly
  after the parameter is locked — never used to influence selection.
- **Acceptance gate:** if performance or ranking degrades materially on
  the holdout set, the parameter change is rejected, not re-tuned to
  fit.

**Status:** Adopted as a standing rule per Gemini's ruling, 2026-08-02.
Applies to future calibration work going forward — not retroactive.
ADR-097/098/099's already-locked thresholds are not reopened by this
rule alone.

#### Mandatory Refactoring Parity Gate

**Finding:** Bare "exact equality" as a refactor-verification bar is
unreliable — IEEE 754 floating-point differences can arise from a
purely mechanical refactor (different call structure, identical math)
without representing any real behavioral change. DeepSeek's audit of
the Unified V2 Engine specification defined a dual-tolerance framework
to distinguish real regressions from harmless floating-point noise.

**Rule:** Any refactor claiming behavioral equivalence to existing
production code must pass a dual-tolerance real-tick backtest:
- Exact match required: order counts, exit counts, max layers, peak
  net lots, and normalized order prices (tick-rounded).
- Tolerance match allowed (~1e-9 relative): internal unrounded
  floating-point state (e.g. raw sigma, log returns) that can shift by
  a bit across a refactor without being a real bug.
- P&L match: exact if the underlying deal sequence is identical;
  bounded by explicit broker-currency-rounding tolerance otherwise —
  the tolerance must be stated, not left implicit.

**Status:** Adopted as a standing rule per Gemini's ruling, 2026-08-02.
Applies to the Unified V2 Engine parity gate and to any future refactor
claiming behavioral equivalence, not just this one.

---

## Parked Backlog

Items intentionally deferred after real investigation, not simply
undone or forgotten. Each entry states why it's parked and what would
need to be true to reopen it.

### State Reconstruction Engine — SHIPPED (no longer parked)

**Status update (2026-08-14): this entry is superseded. The SRE was
built, adversarially audited, ruled, implemented, and deployed. It is
live on the VPS.** The original narrow-form rejection (Gemini, 2026-08-02)
was itself later superseded: full CloseBy-history mapping (Option A) was
proven feasible against this account's real deal history and pursued as a
dedicated initiative, exactly the condition this entry named for reopening.

The engine reconstructs managed layer state from live broker deal history
on restart (OnInit), replacing halt-on-orphan for reconstructable sides.
It emits structured `sre_oninit` DIAG telemetry per side with a
`halt_reason_label` (NONE on clean reconstruction).

Shipped across ADR-105 through ADR-113 (SRE design through unified-engine
merge), with ADR-114 (V2.5 carry-corrected exits) and ADR-115/116 (BCC —
the exit-first book-consistency checker that reuses the SRE matcher)
built on top. Verified live: crash-recovery drills adopted cleanly, and
multiple non-flat reattaches this session reconstructed to
`halt_reason_label=NONE`.

**Remaining known limitation (by design, NOT a bug):** a side holding a
lone position with no prior dual-flat anchor in its deal history halts
with `HALT_09_ANCHOR_NOT_FOUND / SITE2_NO_DUAL_FLAT` (the genesis-orphan
case, ADR-113). This is fail-closed and correct — it is not visible in a
positions/orders blotter (it depends on deal-history dual-flat), so
"orphan-free book" does NOT imply "reconstructs clean." See the
flat-chart precondition note below, which the SRE substantially (but not
entirely) lifts.

### SRE 90-Day Lookback Ceiling (Known Limitation)

The State Reconstruction Engine cannot reconstruct a managed position
older than `V2_SRE_DEFAULT_LOOKBACK_SEC` (90 days,
`state_reconstruction.mqh:18`; used at lines 803, 828, 1074). Any open
managed position whose history falls outside that window fails
reconstruction. This is operationally acceptable for a
mean-reversion/statistical-arbitrage holding profile but is a real
ceiling — it must not become a silent trap.

**Reopen trigger:** Revisit if average position hold times approach the
90-day threshold or if the lookback constant
(`V2_SRE_DEFAULT_LOOKBACK_SEC`) requires extension.

### EURGBP Native Sigma Migration + Easing Recalibration

Would replace EURGBP's `MathMax(sig_ac, sig_bc)` half-spread sigma with
a native, EURGBP-return-based sigma, and recalibrate ADR-099's easing
thresholds under it. Parked (Gemini's ruling, 2026-08-02) due to: a
dimensional/unit mismatch in the native sigma implementation
(log-return sigma fed directly into a price-unit formula slot, ~19%
scale distortion for EURGBP); floor-dominance nonlinearity that can
make the easing ramp inert in more states than under the old sigma;
and an already-thin original calibration margin that a full
recalibration sweep isn't worth committing to before the above is
resolved.

**Reopen sequence, if ever revisited (Gate 0 per Gemini's ruling):**

1. Fix the unit conversion (native sigma must be price-consistent, not
   raw log-return dispersion).
2. Run a single minimal sanity check against `june_blowup` and
   `full_quarter` only, to check whether floor dominance consumes the
   native signal before committing further.
3. If the floor renders easing inert, stop — do not run the full
   recalibration sweep.

The underlying economic rationale (EURUSD/GBPUSD's shared USD-leg
correlation means `MathMax` overstates true EURGBP cross volatility)
was independently confirmed sound by DeepSeek; only the implementation
and verification are unresolved.

### EURGBP AddPipsFloor=2.3 (Derived Grid Geometry)

Would replace EURGBP's inherited GBPUSD `AddPipsFloor=9.0` with a
pair-derived `AddPipsFloor=2.3`, based on a DeepSeek-audited Monte
Carlo finding (n=500, zero-slippage Strategy Tester conditions)
showing +46.1% uplift. Parked after failing its own required real-tick
stress test (Gemini's Prerequisite 2) — a materially tighter grid is
mechanically far more exposed to slippage as a fraction of its own
target than the wider production geometry, and the original +46.1%
finding ran under zero-slippage, zero-latency assumptions.

**Stress test result (real MT5 Strategy Tester, Model=4, five
canonical windows, production `AddPipsFloor=9.0` vs. derived `2.3`,
exit count and direction of change):**

- truss_crisis: 436 -> 604 exits (+31%)
- q1_2024_chop: 160 -> 257 exits (+54%)
- vaccine_rally: 434 -> 380 exits (-19%)
- full_quarter: 98 -> 180 exits (+76%)
- june_blowup: 0/0 exits both geometries (inactive window)

Aggregate: +16.0% total P&L under real ticks (down sharply from the
original +46.1% zero-slippage estimate); per-scalp edge came out
worse for the derived geometry ($0.330 vs $0.359); max layer depth
increased substantially (4-5 -> 7-9) in every active window;
vaccine_rally was outright negative. DeepSeek's critique of the
stress test agreed with parking it.

**Status:** clean negative result under real execution conditions, not
a data gap or an implementation gap. No reopen condition is currently
established, unlike the other two entries in this section — revisit
only if a materially different geometry candidate or a genuine
slippage-mitigation mechanism changes the underlying tradeoff.

### CloseBy-History Layer State Replay

Parked as an explicit scope boundary of the State Reconstruction
Engine (Gemini's ruling, 2026-08-04, Option B): the engine reconstructs
layer state with confidence only on CloseBy-free history since the
anchor. The moment any CloseBy-related deal (an exit-magic position
open, or a `DEAL_ENTRY_OUT_BY`) is found in that window, the engine
halts via the existing, already-safe orphan-guard behavior rather than
attempting to reconstruct through it — it does not guess.

Scope Boundary: CloseBy-History Layer State Replay is parked. The
State Reconstruction Engine operates strictly on CloseBy-free history
windows.

Reopen Condition: Reopen full CloseBy-History Replay only if
post-deployment telemetry proves that mid-session restarts on
post-CloseBy stacks occur frequently enough to justify the engineering
complexity of historical deal-pairing.

Rationale (Gemini's ruling): building a full historical CloseBy
deal-pairing engine was assessed as a structural failure-surface risk
disproportionate to its value — MT5 hedging-mode exit fills open a new
hedge position whose own opening deal carries no reference back to the
original layer, so the mapping can only be recovered via correct
CloseBy pairing across deal history, which introduces significant edge
cases (missing/unpopulated position IDs, near-simultaneous CloseBys,
a hedge leg closed by something other than CloseBy). Option B still
eliminates the flat-chart deployment precondition for the majority of
real restarts — any stack that hasn't had a position cycle through a
CloseBy exit since it was last flat.

**Superseded 2026-08-04:** reopened via direct architectural ruling,
not the telemetry-based reopen condition specified above — that
condition never triggered. Round 3 of the Phase 1 audit sequence
found Option B's actual coverage excluded any side with even a single
exit since it was last fully flat, since every managed exit in this
system opens a hedge position, which is exactly the deal type Option
B's halt condition triggers on. Given this system's design intent is
frequent small scalp exits, that meant Option B eliminated the
flat-chart precondition only for a side that had never closed a
single layer since last flat — a narrow, likely uncommon case, not
"most restarts" as originally framed when this was approved. Gemini
ruled to abandon Option B and pursue full CloseBy-history mapping
(Option A) instead, empirically verified feasible via this account's
real deal history (129 CloseBy events, zero exceptions to the
DEAL_ORDER pairing assumption the mapping strategy depends on). See
the State Reconstruction Engine design (v5 and later) for current
status — this entry is retained as the record of Option B's
evaluation and rejection, not as an accurate description of current
scope.

### Rollover/Carry Missed-Night Investigation

The live audit that surfaced the SRE Tier 2 tolerance gap also found
that naively counting every calendar midnight since a position's open
date, at the current swap rate, over-predicts actual accumulated
rollover drift by 2-3 pips on positions opened 2026-07-30. This implies
`fxmatrix_v2_carry.mqh`'s daily rollover mechanism did not successfully
apply a shift on every eligible night that week — the mechanism only
fires if the EA is attached and the modify succeeds at that exact
broker midnight, with no cross-day catch-up (ADR-101's known
limitation). Root cause not yet investigated — candidates include EA
downtime, a recompile/reattach window coinciding with a midnight, or
`OrderModify` failures beyond ADR-101's same-day retry window.

Reopen Condition: Investigate via Pipshed/telemetry review once
sufficient rollover-cycle data has accumulated to distinguish these
candidates — not urgent, decoupled from the State Reconstruction
Engine work that surfaced it. Per Gemini's ruling (2026-08-06): log
and defer, do not block on this.

### Problem 3 — HALT_30 Overnight Fill-Noise Availability Constraint

**Finding (DeepSeek R2 + Tier 1 verification, 2026-08-07):** ADR-108's
zero-rollover spread gate fixes Problem 2 (0-midnight execution-noise
false positives — Case 2 cleared) but deliberately excludes overnight
and long-hold pairs where `rollover_units > 0`. Those pairs retain
the strict 2pt HALT_30 band. Tier 1 Cases 3 (GBPUSD LONG) and 5
(EURGBP LONG) remain fail-closed on historical CloseBy pairs with
genuine 2–7pt execution-noise residuals that span at least one broker
midnight — not tampering, not a security issue, an availability
constraint.

**Examples (authorized red, post-ADR-108):**
- Case 3: order `510003492`, 1-midnight, 5.6pt residual
- Case 5: order `509107430`, 1-midnight, 8.5pt residual; long-hold
  outlier `512823324` (508408618/508481504), 8-midnight, 29pt — model
  overshoot, correctly still halts

**Why not widen the band for overnight pairs:** DeepSeek R2 proved
unconditional spread allowance compounds with ADR-107 rollover drift
to reopen the grid-cancellation vector (`rollover(82) + spread(8) =
90pt = one grid step`). The zero-rollover gate is the mandated safe
form; overnight fill-noise requires a separate Problem 3 design.

**Status:** Blocked-on-Problem-3, fail-closed, documented. Cases 3/5
long Tier 1 assertions remain red until Problem 3 is ruled and
implemented. Not a deployment blocker for sides that pass Tier 1.

**Reopen condition:** Gemini rules on a Problem 3 fix approach (e.g.
actual-vs-max rollover shift, separate halt reason, or other constraint
that does not compound spread + rollover near grid boundaries).

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

This document has a line count of 714 lines at the bottom.
