# SRE → Unified V2 Engine — Merge Scoping Map

**Purpose:** concrete plan for merging the State Reconstruction Engine (SRE) into the Unified V2 Engine, per Gemini's approved 5-step integration sequence. Grounded in source read at commit `7ecfe96` (origin tip). Built as a resource for the integration work and for carry-over to a future chat.

**Status when written:** SRE deployed to VPS (14-file curated stack), Sunday Tier 2 drill pending. Unified engine implemented (`e76fbba`), Gate 1 parity complete, EXECUTION BLOCKED. This merge is Step 2 of the approved sequence and begins only after Sunday's SRE Tier 2 passes.

---

## The core finding: the merge is a KNOWN transplant, not open-ended surgery

Both `OnInit` structures were read side by side. They are nearly identical in shape — the unified engine's `OnInit` still contains the **pre-SRE orphan path** that SRE was built to replace. Production has already done exactly this transplant. So the merge is: take the SRE block that production's `OnInit` already uses, and graft it into the unified engine's `OnInit` in place of its old orphan path.

| | Production `fxmatrix_v2.mq5` `OnInit` (HAS SRE) | Unified `fxmatrix_v2_engine.mqh` `OnInit` (NO SRE) |
|---|---|---|
| Base init | `Long_OnInit()` + `Short_OnInit()` | `Long_OnInit()` + `Short_OnInit()` (same) |
| Orphan handling | SRE: `V2SREOnInitSideConfig` → `V2_RunSideOnInit` → `V2_ApplyLongSRECommit`/`V2_ApplyShortSRECommit` | **OLD PATH:** `V2_ShouldPublishCapSyncOnInit(long_orphan)` → `V2_OnInitResultFromOrphanFlags(long_orphan, short_orphan)` |
| Result | Reconstructs layer state, halts on tamper, adopts clean orphans | Halts both sides on any orphan (the ADR-102/103 guard SRE supersedes) |

**The delta to replace:** unified engine `OnInit` lines ~1448–1516 (the old orphan-flag path) get replaced with the SRE config-build + run + commit block from production `OnInit` lines ~1547–end.

---

## What must PORT into the unified engine (the SRE surface)

From `fxmatrix_v2_sre_oninit.mqh` (646 lines) + `fxmatrix_v2_state_reconstruction.mqh` (1,284 lines). The unified shells already `#include` neither; the merge adds both to the engine's include set, then wires the `OnInit`.

### Headers to add to the engine's includes
- `fxmatrix_v2_state_reconstruction.mqh` — the pure reconstruction logic (HALT_30, rollover point-estimate ADR-107, grid-boundary guard + zero-rollover gate ADR-108). **Ports UNCHANGED** — it's pure logic operating on input structs, no dependency on production vs unified structure.
- `fxmatrix_v2_sre_oninit.mqh` — the broker-read + orchestration layer.

### Functions/types in `sre_oninit.mqh` (the orchestration that touches EA structure)
| Symbol | Role | Merge risk |
|---|---|---|
| `V2SREOnInitSideConfig` / `SideResult` / `BrokerOverride` / `AggregateOutcome` | Config/result structs | LOW — pure data, port as-is |
| `V2_SRE_GatherOpenPositionsByMagic` | Reads broker positions by magic | LOW — uses MT5 API + magic, not EA internals |
| `V2_SRE_GatherPendingOrders` | Reads resting orders | LOW — same |
| `V2_SRE_GatherDealHistory` | Reads deal history (90-day lookback) | LOW — same |
| `V2_SRE_BuildBrokerReadSnapshots` | Assembles the input arrays | LOW |
| `V2_SRE_CapPublishLayers` / `CapWriteSentinel` | Cap-GV publish + sentinel lock | **MEDIUM — see cap-bridge note** |
| `V2_SRE_ProcessSideHalt` | Emits halt alert, sets halt state | LOW |
| `V2_SRE_RunOnInitSequencePure` / `RunOnInitSteps3To10` | The 10-step reconstruction core | LOW — pure, operates on config+snapshots |
| `V2_SRE_RunSideOnInit` | Top-level per-side entry (the call site) | **MEDIUM — wiring point** |
| `V2_SRE_RunSideOnInitFromFixture` | Test entry (Tier 1 uses this) | LOW — test-only, no runtime change |

---

## The three MEDIUM-risk wiring points (where real judgment is needed)

Everything else is a copy. These three are where the unified engine's *different structure* actually matters:

### 1. The config-build block references per-pair inputs
Production's `OnInit` builds `long_cfg`/`short_cfg` from `InpLotSize`, `InpExitPips`, `InpAddPipsFloor`, `InpWidenRatio`, `InpAddPipsCeiling`, `MM_LONG_V2`, `MM_LONG_V2_EXIT`, `_Symbol`, `_Point`, etc. In the unified engine these come from **`g_preset`** (the `V2PairPreset` struct) instead of per-pair `#define`/inputs. So the config-build block must be rewritten to source from `g_preset.*` rather than the hardcoded production names. **This is the single biggest merge task** — mechanical but must be exact, and every field must map correctly or the reconstruction runs against wrong parameters (→ false halts or missed tampers).

### 2. Cap-bridge kind selection
Production hardcodes `long_cfg.cap_bridge = V2_SRE_CAP_BRIDGE_GBPUSD` per file. The unified engine serves all three pairs from one body, so the cap-bridge kind must be selected from `g_preset` at runtime (the `V2SRECapBridgeKind` enum → driven by which pair the preset describes). The `cap_bridge` module already exists in the unified architecture (`fxmatrix_v2_cap_bridge.mqh`); the SRE cap-publish must route through it rather than the production per-pair cap headers.

### 3. `V2_ApplyLongSRECommit` / `V2_ApplyShortSRECommit` write to the layer arrays
These commit the reconstructed layers back into `g_long_layers`/`g_short_layers`. Confirm the unified engine's layer-array structure matches what SRE's commit writes (it should — parity proved identical position management — but this is the one place a structural difference would surface, so verify field-by-field during the merge).

---

## Validation after the merge (Steps 3–4, both desktop, no live market)

Per Gemini's ruling, the merge is proven on desktop before any live window:

**Step 3 — Re-run Gate 1 Parity on the integrated stack.** The integrated unified+SRE engine must still produce bit-exact parity vs production across all windows (GBPUSD/EURUSD/EURGBP, incl. vaccine_rally). This proves the SRE graft didn't alter trading behavior. *Note: parity runs in Strategy Tester, which initializes flat — so SRE's reconstruction path won't fire during parity (nothing to reconstruct). Parity validates the TRADING logic is untouched; it does NOT exercise SRE. That's expected and correct — SRE's validation is Step 4 + the live Gate 2.*

**Step 4 — Re-run SRE Tier 1 real-data fixture on the integrated stack.** The 7 real-data cases (2/3/4/5/6/7 + the flat case) must produce the same results as they do against the current production+SRE build: Cases 2/4/6/7 pass, Cases 3/5 remain the documented Problem-3 fail-closed reds. This proves the SRE logic survived the port into the unified structure. *If Cases 3/5 change behavior, or any passing case regresses, the port altered SRE — stop and diagnose.*

**Then — Step 5 (future live window):** Gate 2 on the integrated artifact (live orphan-reattach, ADR-102/103 behavior via SRE). Same drill shape as Sunday's SRE Tier 2, but on the unified binary.

---

## Firewall reminder (carried from the deployment)

The unified deployment, when it eventually happens, is a **different and larger curated set** than SRE's 14 files — it REPLACES the three production `.mq5` with the unified shells + `fxmatrix_v2_engine.mqh` + presets. That set needs its own `#include`-closure trace and hash table at merge time. Do NOT reuse the SRE 14-file deploy set for the unified cutover.

---

## Suggested merge order (for whoever picks this up)

1. Add both SRE headers to the engine's include set; confirm compile (will fail at the OnInit wiring — expected).
2. Port the SRE structs + pure functions (all LOW-risk) — should compile clean.
3. Rewrite the config-build block to source from `g_preset` (MEDIUM #1) — the main work.
4. Route cap-publish through `cap_bridge` (MEDIUM #2).
5. Replace the unified `OnInit` old-orphan path with the SRE run+commit block; verify layer-array commit (MEDIUM #3).
6. Compile clean (0/0, GUI).
7. Step 3 (re-parity) → Step 4 (re-Tier-1) → then Gemini sign-off before scheduling the live Gate 2.

**Estimated shape:** the port is ~80% mechanical copy (the pure reconstruction + gather functions), ~20% real work (the three `g_preset`-sourcing wiring points). No new algorithm design — SRE's logic is fixed and battle-tested; this is transplanting it into a parameterized host. The DeepSeek-hardened HALT_30 logic (ADR-107/108) ports unchanged, so no new adversarial audit is needed *unless the merge alters the reconstruction logic itself* (it shouldn't — only its inputs' sourcing changes).
