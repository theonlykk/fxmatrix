# Phase 1 `_ref` Branch — DEPRECATED / SUPERSEDED

**Status:** Archived 2026-08-02 per Gemini architectural ruling.

**Superseded by:** Unified V2 engine design (production-only reference).
See `docs/architecture/UNIFIED_V2_ENGINE_DESIGN_SPEC_DRAFT.md` when available.

## Why archived

The Phase 1 `_ref` effort (2026-07-18 baseline) was three near-duplicate
`.mq5` files with macro/dispatch scaffolding — not a shared engine.
It diverged from production and was missing ADR-097 through ADR-103
(spread easing, EUR dual cap, rollover retry, halt gate, cap GV ordering).

These files are preserved for historical reference only. **Do not compile,
deploy, or extend.**

## Contents

| File | Role (historical) |
|------|-------------------|
| `fxmatrix_v2_ref.mq5` | GBPUSD preset shell |
| `fxmatrix_v2_eurusd_ref.mq5` | EURUSD preset shell |
| `fxmatrix_v2_eurgbp_ref.mq5` | EURGBP preset shell |
| `fxmatrix_v2_logic_r1.mqh` | Fork of `logic.mqh` (missing ADR-102/103 helpers) |
| `fxmatrix_v2_exits_r1.mqh` | Fork of `exits.mqh` |
| `fxmatrix_v2_cross_exposure_cap.mqh` | Generic cap wrapper (replaced by production cap modules) |
| `fxmatrix_v2_pair_config.mqh` | Compile-time preset macros |
| `fxmatrix_v2_signal_dispatch.mqh` | BC/AB routing without easing |
| `fxmatrix_v2_ref_tests.mq5` | Ref-specific unit test harness |

## Recovery

Files remain in git history at their original paths prior to this move.
Current location: `ea/archive/phase1_ref_deprecated/`.
