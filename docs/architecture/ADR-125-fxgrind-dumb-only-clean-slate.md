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

## Consequences

- Spec B enables trading after successful reconstruction on a valid book; invalid
  or unparseable books halt in place.
- Geometry width/exit/add injected from confirmation sweep before deploy;
  presets carry placeholders only (`InpAddPips` must be recomputed as 2.0 × width
  whenever width is injected).
- MetaEditor GUI compile required; CLI compile not trusted in this project.
- `desktop_sync.ps1` / `deploy.ps1` header lists must be re-derived from fxgrind
  include graph in a separate task.

## References

- ADR-123 (place-once straddle), ADR-124 (re-centering — reserved write-up)
- ADR-126 (simulation cost model — separate branch)
- `ea/fxmatrix_v2_engine.mqh` :1396-1462 (re-center reference behaviour)
- `ea/fxgrind.mq5`, `ea/grind_*.mqh` (incl. `grind_recon.mqh`, `grind_cap.mqh`),
  `ea/fxgrind_tests.mq5`
