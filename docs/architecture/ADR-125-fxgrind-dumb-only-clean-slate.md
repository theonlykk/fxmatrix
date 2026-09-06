# ADR-125: fxgrind — Dumb-Only Clean-Slate Market-Making EA Family

## Status

Proposed — 2026-09-06. Spec A of B (engine, presets, placement, caps) and
Spec B (comment-only state reconstruction + CAS currency cap) implemented.
Not committed until Khalid clears the two-step commit gate.

## Context

The retired `fxmatrix_v2_*` family combined signal-driven quoting with dumb
straddle arms, path-dependent add-spacing ratchets, and fragmented cost/risk
logic. Simulation work (ADR-126) centralised P&L accounting; live deployment
requires a **clean-slate** dumb-only engine with no fair-value machinery.

fxgrind replaces two retired families (signal 2026xxxx, old-dumb 2126xxxx) with
a single parameterised codebase using magic namespace **2226xxxx** only. Six
concurrent instances deploy: OPT and ALT slots on GBPUSD, EURUSD, EURGBP.

### Mental model

Automated market maker on FTMO Swing $10k: resting limits on both sides, never
crossing the spread. Adverse selection is expected raw material, not a defect.
No stop-losses. Risk via 0.01 lots, per-pair layer caps, and account currency cap
(Spec B). Layered inventory is inventory, not realised loss.

## Decision

1. **Single engine** `ea/fxgrind.mq5` with poisoned defaults (`InpWidthPips=-1.0`,
   `InpAddPips=-1.0`, `InpExitPips=-1.0`, etc.). OnInit returns `INIT_FAILED` if
   geometry or caps are not explicitly configured — unconfigured instances must
   never trade. Add spacing must satisfy `InpAddPips == GRIND_ADD_WIDTH_MULTIPLE
   × InpWidthPips` (2.0 × straddle half-width, matching
   `scripts/grid_sim_v7_real_signal.py`); a preset whose add spacing has drifted
   from its width fails at init.

2. **Comment-as-state contract** for Spec B:
   `GRIND|<slot>|<side>|L<nn>|<role>` (≤31 chars). Parser uses `StringSplit` and
   prefix-matches role field for broker suffix contamination (e.g. `EXT[tp]`).

3. **No re-center flag in comment.** Re-centering uses `OrderModify`
   (TRADE_ACTION_MODIFY), which cannot alter comments. Re-centered L0 remains L0;
   Spec B reads prices from broker, never infers layer identity from price geometry.

4. **Per-pair layer caps (ratified):** GBPUSD 12, EURUSD 12, EURGBP 8. Cap stops
   **new entry** placement only; exits and re-centering continue; no auto-close.

5. **Order-count arithmetic:** per side at depth n → n resting exits + at most one
   resting entry → 2n+2 per instance. Ratified caps → GBPUSD 26 + EURUSD 26 +
   EURGBP 18 = 70 per slot, **140 across both slots**. FTMO hard limit 200;
   project soft gate 180.

6. **Halt-in-place.** On unparseable comments or invariant violations the EA
   sets `g_grind_halted`, places nothing, emits CRITICAL telemetry naming the
   specific failure, stays attached. **Never** `ExpertRemove()`.

7. **Configurable add spacing** via `InpAddPips` (poisoned default `-1.0`).
   Fixed spacing at `GRIND_ADD_WIDTH_MULTIPLE` (2.0) × straddle half-width — no
   widen ratchet. The retired v2 `GRIND_ADD_PIPS_FLOOR` (9.0) is removed.
   **Add anchor:** previous layer's entry price (stateless, recoverable from open
   positions). The Python simulator was conformed to this EA anchor, not the
   reverse. Place-once straddle (ADR-123). Fill-triggered re-center (ADR-124) via
   OrderModify. Absolute-pip deadband (ADR-121/122). Offline-market guard.
   Exact magic equality.

8. **Spec B — comment-only state reconstruction.** OnInit rebuilds from open
   **positions** and resting **orders** with exact magic equality only. No deal
   history, no 90-day lookback, no CloseBy pairing, no price-geometry inference.
   The retired `fxmatrix_v2_sre_oninit.mqh` / `fxmatrix_v2_state_reconstruction.mqh`
   (~2,420 lines) are explicitly rejected. `GrindCommentParse` is the sole layer
   identity source; unparseable tickets halt. Entry prices and exit targets are
   read from the broker, never recomputed. Telemetry counters reset to zero.
   Empty book is valid (genesis / Complete Purge).

9. **Spec B — book invariants (read-only, no auto-repair).** I1–I7 checked at
   rebuild and on heartbeat: paired exits, no naked positions, no orphan exits,
   contiguous layer indices, exit within `2 × _Point` of entry ± `InpExitPips`,
   depth ≤ `InpMaxLayers`. Violations halt with named CRITICAL reason.

10. **Spec B — CAS currency cap.** Cross-instance exposure via MT5 GlobalVariables
    under `GRIND2226_<magic>_<LEG>` plus companion `GRIND2226_<magic>_<LEG>_time`
    (never packed into one double). Lock `GRIND2226_CAS_LOCK` with backoff/timeout.
    **Phase 1 (OnInit):** each instance publishes own exposure unconditionally; no
    peer reads. **Phase 2 (OnTick):** peer reads before new entry placement only.
    Missing companion timestamp, missing peer key, or timestamp older than 300s
    reads as MAXED — reversing the retired v2 permissive-zero default. Threshold
    ≤ 0 means cap **off** (machinery runs, nothing blocked); threshold > 0 arms
    the limit. Cap gates **new entries only** — never exits, re-center, or close.

11. **Deploy configuration via MT5 .set files.** The unreachable `grind_preset_*.mqh`
    headers are deleted. Six committed presets live in `ea/presets/` (GBPUSD/EURUSD/
    EURGBP × OPT/ALT). `InpConfigWarning` is a dummy string input serialised into
    each .set so configuration identity survives MT5 GUI round-trips (not `;`
    comments). OnInit prints the full resolved configuration. Duplicate-magic guard:
    `GRIND2226_MAGIC_LOCK_<magic>` via `GlobalVariableTemp` (session-scoped, not
    persistent — survives terminal crash without blocking reattach). Claimed after
    geometry validation, **before** cap Phase-1 publish; released in OnDeinit.
    Heartbeat telemetry appends magic, slot, geometry, layer cap and cap-leg names
    at the end of the existing JSON schema.

12. **Ratified deploy geometry (confirmation sweep, n=50 seeds, substeps=100,
    cost model ac19a9f, entry-anchored adds).** All six cells gate-verified clear
    on FTMO Gate A (daily equity drawdown < $500) and Gate B (peak-to-trough <
    $1000), 0% breach rate; worst mean max drawdown $433.3 vs $500 daily limit:

    | Instance | Width | Exit | Add | Stranded |
    |----------|-------|------|-----|----------|
    | GBPUSD OPT | 5 | 5 | 10 | 10 |
    | GBPUSD ALT | 5 | 7 | 10 | 10 |
    | EURUSD OPT | **7** | 5 | 14 | 14 |
    | EURUSD ALT | 7 | 7 | 14 | 14 |
    | EURGBP OPT | 3 | 2 | 6 | 6 |
    | EURGBP ALT | 3 | 5 | 6 | 6 |

    Add and stranded threshold are always `2.0 × width` (`GRIND_ADD_WIDTH_MULTIPLE`).
    **EURUSD override:** sweep harvest optimum was 5/5 (mean max DD $473.9, 5%
    margin on $500 daily limit). Staff Architect ratified **7/5** ($322.8 DD) —
    a touch-fill Brownian-bridge simulator cannot model gap risk or sustained
    unidirectional prints, so 5% simulated buffer is not a real buffer; ~34%
    simulated harvest traded for margin. **Width-3 majors disqualified:** width-3
    was highest-harvest on both GBPUSD and EURUSD surfaces but breached Gate A on
    62% of EURUSD seeds ($932 mean max DD vs $1000 limit) — gate-then-optimise
    earns its place; do not revert to width-3 on majors without re-running gates.

## Consequences

- Spec B enables trading after successful reconstruction on a valid book; invalid
  or unparseable books halt in place.
- Geometry ratified in `ea/presets/*.set` (confirmation sweep complete); EA source
  retains poisoned defaults for unattached instances. `InpAddPips` must remain
  `2.0 × width` in every preset — init asserts the relationship.
- MetaEditor GUI compile required; CLI compile not trusted in this project.
- `desktop_sync.ps1` / `deploy.ps1` header lists must be re-derived from fxgrind
  include graph in a separate task.

## References

- ADR-123 (place-once straddle), ADR-124 (re-centering — reserved write-up)
- ADR-126 (simulation cost model — separate branch)
- `ea/fxmatrix_v2_engine.mqh` :1396-1462 (re-center reference behaviour)
- `ea/fxgrind.mq5`, `ea/grind_*.mqh`, `ea/presets/*.set`, `ea/fxgrind_tests.mq5`
