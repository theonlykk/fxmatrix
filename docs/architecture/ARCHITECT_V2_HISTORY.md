# ARCHITECT_V2_HISTORY.md -- V2-era engineering rules (archived)
Extracted verbatim from docs/architecture/ARCHITECT.md as it stood at
commit 3aaec11, when ARCHITECT.md was rewritten for the fxgrind era.
Nothing here is edited. Sections describe the V2 stack
(fxmatrix_v2_*.mqh, the SRE, HALT_09, the EURGBP caps, the BCC sweep)
and remain the reference for ADRs that cite them. For current rules
see ARCHITECT.md.

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
#### Running `fxmatrix_v2_tests.mq5`

This is a genuine MT5 **Script** (`#property script_show_inputs`,
`OnStart()`), not an Expert Advisor. **Do not attempt to run it through
Strategy Tester** — the tester only tests EAs; Scripts have no
`OnInit`/`OnTick` handlers for it to call. To run it: drag or
double-click it onto any open chart (a chart window must be focused
first), confirm the Script Properties popup that appears, and check
the Toolbox's **Experts tab** (not the tester) for PASS/FAIL lines per
test plus a final summary count.
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

## INCIDENT FIRST-RESPONSE DOCTRINE (Manual Levers)

**Governing Principle:** Under uncertainty, take the MINIMAL reversible action that stops NEW risk, then diagnose. Do not reach for heavy, irreversible levers (bulk-closes, rollbacks) to resolve symptoms you do not yet understand. Heavy levers are for shedding real risk, not dispelling confusion.

**The "L1 Always First" Standing Rule:**
For ANY anomaly, disabling Algo Trading (L1) is the mandatory first action. It freezes the state machine, preserves resting exit limits (protecting inventory), and stops new risk while buying unlimited time for forensics.

**The Manual Lever Ladder (Ordered by Reversibility & Risk)**

1. **L1: Algo OFF (Master Stop):** Stops new actions. Preserves exits. Zero side effects.
2. **L2: Delete a resting ENTRY limit:** Sheds potential future risk. Reversible. *(CAUTION: Deleting an EXIT limit leaves a position naked and should only be done if L1 is active, and must remain off until a new exit is established.)*
3. **L3: Restart the terminal:** Forces feed reconnection and SRE OnInit rebuild. Safe/trivial when FLAT. Exercises complex reconstruction logic when LOADED.
4. **L4: Close position(s):** Irreversible (realizes P&L). Surgical closes are preferred. Bulk-closes feed magic-0 deals into the SRE and should be reserved for genuine risk-shedding, not bug-clearing.
5. **L5: Add a manual limit/market order:** Creates a direct conflict with Trigger A and BCC (manually adding an order WILL trigger a halt). Functionally incompatible with automated mode. The EA must remain in L1 (Algo Off, monitor-only) until the manual order is cleared.

**Symptom Pairing & Triage**

* **Runaway loop / Order spam:** L1 (Algo Off) -> Save Journal/Experts logs FIRST -> Do NOT restart until logs are secured (a restart wipes terminal RAM and destroys the evidence of why it looped).
* **Quotes not appearing / Book looks wrong / Frozen state:** L1 (Algo Off) -> If FLAT, use L3 (Restart) immediately as triage. If it clears, the feed was stale. If it persists, diagnose the code.
* **Holding unwanted risk / Margin pressure:** L1 (Algo Off) -> L4 (Surgical close).
* **Stray/Orphaned resting order:** L1 (Algo Off) -> L2 (Delete specific order).

This document has a line count of 736 lines at the bottom.
