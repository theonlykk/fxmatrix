# Unified V2 Engine — Design Specification (Revised)

**Status:** Approved for implementation (Gemini ruling, 2026-08-02). Supersedes the 2026-08-02 pre-DeepSeek draft. DeepSeek Phase 1 critique (`adrs/deepseek_audit_latest.md`) and Gemini rulings on four architectural decisions are integrated below. No further audit round required before implementation.

**Authority:** Build from **current production only**; Phase 1 `_ref` branch archived at `ea/archive/phase1_ref_deprecated/`.

**Scope:** Architecture refactor preserving **behavior-identical** output for GBPUSD, EURUSD, and EURGBP. No parameter recalibration. No trading-logic changes.

**Standing rules referenced:** Mandatory Refactoring Parity Gate (`docs/architecture/ARCHITECT.md` §Testing and Verification).

---

## 0. Problem statement

Production consists of three ~1,600-line `.mq5` files that are structurally identical except for:

- Pair-specific `#define` constants (magic numbers, telemetry labels)
- Signal path (BC native vs AB triad)
- Spread-easing thresholds (ADR-097: 1/3, ADR-098: 1/4, ADR-099: 1/3) — **shell `input` defaults only**, not preset fields
- Cap module wiring (GBP-only, EUR-only, dual) — **shell cap-bridge implementations**
- EURUSD-only L0 deadband vol-scale (explicit preset flag; EURGBP has a dead-code spread ref that must not imply scaling)

Every ADR since 2026-07-18 was applied three times (or inlined three times). The Phase 1 `_ref` branch did not solve this — it added macro/dispatch scaffolding but retained three full duplicates and fell 10 commits behind production.

**Goal:** One shared, pair-agnostic engine body + thin per-pair entry shells. Structural identity (magic, signal slot, cap profile, deadband enable flag) lives in a typed preset; all behavioral parameters live in shell `input` declarations only.

---

## 1. Target architecture (high level)

```
┌─────────────────────────────────────────────────────────────┐
│  fxmatrix_v2_gbpusd.mq5   (thin shell, ~60–120 lines)       │
│  fxmatrix_v2_eurusd.mq5   (thin shell)                      │
│  fxmatrix_v2_eurgbp.mq5   (thin shell)                      │
│    → defines V2_PAIR_PRESET (structural constants only)     │
│    → declares all behavioral inputs (production defaults)   │
│    → implements V2_Cap_CheckBlocks / Sync / Record (bridge) │
│    → #includes cap headers THIS shell needs only            │
│    → #includes fxmatrix_v2_engine.mqh                       │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  fxmatrix_v2_engine.mqh   (shared Long_/Short_ + OnInit/   │
│                            OnTick/OnTradeTransaction)       │
│    → pair-agnostic: NO pair-label literals, NO cap calls,   │
│      NO raw magic literals — preset + inputs + bridges only │
└─────────────────────────────────────────────────────────────┘
         │              │              │
         ▼              ▼              ▼
  fxmatrix_v2_logic.mqh   fxmatrix_v2_exits.mqh   fxmatrix_v2_telemetry.mqh
  fxmatrix_v2_signal.mqh  fxmatrix_v2_carry.mqh  fxmatrix_v2_api_counter.mqh
  fxmatrix_v2_l0_signal.mqh  (NEW — pure core + production wrapper)
```

**Why three shells remain:** MT5 attaches one EA binary per chart instance. Magic numbers, default inputs, cap-bridge implementations, and compile-time cap includes differ per pair. Shells are **deployment artifacts**, not logic duplicates.

**Production files during transition:** Existing `fxmatrix_v2.mq5`, `fxmatrix_v2_eurusd.mq5`, `fxmatrix_v2_eurgbp.mq5` remain untouched until parity is proven; new shells get distinct names (e.g. `fxmatrix_v2_unified_gbpusd.mq5`) or replace production only after gate (§7).

---

## 2. Pair preset mechanism — structural constants only (Gemini-ruled)

### 2.1 Single source of truth for behavioral parameters

**Rule:** `V2PairPreset` holds **only** structural, non-overridable constants. **No** behavioral default (easing thresholds, max layers, exit pips, cap thresholds, quote spread, passivity buffer, deadband multiplier, leg-symbol runtime overrides) may live in the preset struct.

All behavioral parameters are `input` declarations in each shell, copied verbatim from current production defaults. All engine logic reads **exclusively** from those `input` variables — never from a preset-stored copy of the same value.

**Resolution order:** At runtime there is one authority for each behavioral parameter: the shell's live `input` value. The preset does not duplicate, shadow, or validate against a parallel copy of easing thresholds or cap thresholds. `OnInit` may validate input ranges (as production already does for ease-depth ordering) but must not compare inputs to preset behavioral fields — there are none.

**Shell pattern:**

```cpp
#property ...
#include "fxmatrix_v2_preset_gbpusd.mqh"   // g_preset structural only
#include "fxmatrix_v2_gbp_cap.mqh"         // cap headers for bridge impl

input double InpQuoteSpread = 0.0004;
input int    InpEaseDepthStart = 1;        // ADR-097 locked default — shell only
input int    InpEaseDepthFull = 3;
// ... all other inputs unchanged from production fxmatrix_v2.mq5 ...

// Cap bridge implementations (§4) — must appear BEFORE engine include
bool V2_Cap_CheckBlocks(const bool is_long) { ... }
void V2_Cap_Sync(const bool is_long, const int layer_count) { ... }
void V2_Cap_RecordBlock(const bool is_long) { ... }

#include "fxmatrix_v2_engine.mqh"
```

### 2.2 `V2PairPreset` struct (revised)

**New header:** `fxmatrix_v2_pair_preset.mqh`

```cpp
enum V2SignalSlot { V2_SIGNAL_BC_NATIVE, V2_SIGNAL_AB_TRIAD };
enum V2CapProfile  { V2_CAP_GBP_ONLY, V2_CAP_EUR_ONLY, V2_CAP_DUAL_GBP_EUR };

struct V2PairPreset {
   // Identity (non-overridable)
   string         chart_symbol;           // sanity check in OnInit
   string         tel_instance_long;
   string         tel_instance_short;
   string         ea_name;
   long           magic_long;
   long           magic_short;
   long           magic_long_exit;          // MM_*_EXIT from production
   long           magic_short_exit;

   // Signal routing (non-overridable)
   V2SignalSlot   signal_slot;
   string         leg_ac_symbol_default;  // AB only; empty for BC
   string         leg_bc_symbol_default;  // AB only; empty for BC

   // L0 deadband vol-scale (structural enable + ref when enabled — §6)
   bool           l0_deadband_vol_scale_enabled;
   double         l0_deadband_spread_ref_pips;  // used ONLY when enabled

   // Cap profile tag (telemetry/validation; dispatch is via bridge — §4)
   V2CapProfile   cap_profile;
};
```

**Explicitly excluded from preset:** `ease_depth_*`, `InpQuoteSpread`, cap thresholds, `InpMaxLayers`, `InpExitPips`, `InpL0DeadbandMult`, runtime leg overrides.

### 2.3 Per-pair preset fragment values (from production)

| Field | GBPUSD | EURUSD | EURGBP |
|-------|--------|--------|--------|
| `magic_long` / `magic_short` | 20260901 / 20260902 | 20260911 / 20260912 | 20260921 / 20260922 |
| `magic_long_exit` / `magic_short_exit` | per `logic.mqh` / shell `#define` | per shell | per shell |
| `signal_slot` | `V2_SIGNAL_BC_NATIVE` | `V2_SIGNAL_BC_NATIVE` | `V2_SIGNAL_AB_TRIAD` |
| `leg_*_default` | empty | empty | `"EURUSD"` / `"GBPUSD"` (production defaults) |
| `l0_deadband_vol_scale_enabled` | **false** | **true** | **false** |
| `l0_deadband_spread_ref_pips` | 0.0 (ignored) | **0.18** (`V2_PAIR_SPREAD_PIPS_REF`) | 0.0 (ignored — do **not** use dead-code 0.63 define) |
| `cap_profile` | `V2_CAP_GBP_ONLY` | `V2_CAP_EUR_ONLY` | `V2_CAP_DUAL_GBP_EUR` |

**OnInit sanity check:** assert `_Symbol == g_preset.chart_symbol` (or allowed alias).

---

## 3. Unified L0 signal dispatch — pure core + production wrapper (DeepSeek Blocker 3)

### 3.1 Hard requirement

Easing (ramp + passivity floor) must be **inside** the dispatch layer. Production inlines eased half-spread in each file's `Long_/Short_ComputeBidSignal` — unified dispatch must lift that inlined production logic, **not** the pre-ADR helpers in `signal.mqh`.

### 3.2 Split: pure core (unit-testable) vs production wrapper

**New header:** `fxmatrix_v2_l0_signal.mqh`

#### Pure core — no broker calls

All functions below are **pure**: they accept explicit numeric/array inputs only. They must **not** call `CopyClose`, `SymbolInfoDouble`, `SymbolInfoInteger`, or any other terminal API.

```cpp
struct V2L0BcInputs {
   double closes[];          // ≥60 M5 closes, index 0 = most recent completed bar
   double bid;
   double ask;
   double quote_spread;      // InpQuoteSpread
   double spread_multiplier;
   double spread_multiplier_eased;
   int    ease_depth_start;
   int    ease_depth_full;
   double passivity_buffer_price;
   bool   quoting_side_flat;
   int    opposite_depth;
   bool   compute_bid;       // true → bid path; false → offer path (symmetric BC)
};

struct V2L0AbInputs {
   double ac_closes[];
   double bc_closes[];
   double ac_bid, ac_ask, bc_bid, bc_ask;
   double quote_spread;
   double spread_multiplier;
   double spread_multiplier_eased;
   int    ease_depth_start;
   int    ease_depth_full;
   double passivity_buffer_price;
   bool   quoting_side_flat;
   int    opposite_depth;
   bool   compute_bid;
};

bool V2_L0CoreComputeBc(const V2L0BcInputs &in, double &theoretical);
bool V2_L0CoreComputeAb(const V2L0AbInputs &in, double &theoretical);
```

**BC algorithm (pure):** mirrors production inlined logic — `V2_FvSigmaFromCloses` on `closes[]`, `now = closes[0] + (ask-bid)/2`, log return, easing via `V2_EffectiveSpreadMultiplier` when `quoting_side_flat`, `V2_L0ResolveLiveSpreadPrice(quote_spread)`, `V2_L0DynamicHalfSpread`, `fv * exp(r ± dynamic_hs)`.

**AB algorithm (pure):** dual-leg FV/sigma, `MathMax(sig_ac, sig_bc)`, same easing/floor, `ratio * exp(inst_spread ± dynamic_hs)`.

#### Production wrapper — fetches market data

```cpp
bool V2_L0ComputeBid(const V2PairPreset &preset,
                     const V2L0SignalContext &ctx,  // behavioral fields from inputs + layer state
                     double &bid_theoretical);

bool V2_L0ComputeOffer(const V2PairPreset &preset,
                       const V2L0SignalContext &ctx,
                       double &offer_theoretical);
```

Wrapper responsibilities only:

1. Branch on `preset.signal_slot` (BC vs AB).
2. `CopyClose` / `V2_CopyM5Closes` / `SymbolInfoDouble` for bid/ask.
3. Fill `V2L0BcInputs` or `V2L0AbInputs` from fetched data + `ctx`.
4. Call `V2_L0CoreComputeBc` or `V2_L0CoreComputeAb`.
5. For AB: leg symbols = `StringLen(InpLegAC) > 0 ? InpLegAC : preset.leg_ac_symbol_default` (same for BC leg).

**Unit tests** (`fxmatrix_v2_tests.mq5`) target **`V2_L0CoreComputeBc` / `V2_L0CoreComputeAb` only** — ramp, floor rescue, swap-independence matrix — using synthetic closes/bid/ask arrays. No broker mocking required.

### 3.3 `V2L0SignalContext` (wrapper layer)

Behavioral fields populated by engine wrappers from **`input` variables and layer arrays** (not preset):

```cpp
struct V2L0SignalContext {
   double quote_spread;              // InpQuoteSpread
   double spread_multiplier;         // InpSpreadMultiplier
   double spread_multiplier_eased;   // InpSpreadMultiplierEased
   int    ease_depth_start;          // InpEaseDepthStart
   int    ease_depth_full;           // InpEaseDepthFull
   double passivity_buffer_pips;     // InpPassivityBuffer → converted once
   int    opposite_depth;
   bool   quoting_side_flat;
   string leg_ac;                    // resolved runtime override
   string leg_bc;
};
```

Engine's `Long_ComputeBidSignal` / `Short_ComputeOfferSignal` fill context and call `V2_L0ComputeBid/Offer`.

**DIAG hooks (`l0_ease`, `l0_lag`):** remain in engine wrappers, gated on `InpVerboseLog`.

---

## 4. Cap dispatch — shell bridge pattern (Gemini-ruled)

### 4.1 Abstract interface (declared in shared header, implemented in shells)

**New header:** `fxmatrix_v2_cap_bridge.mqh` — **declarations only:**

```cpp
bool V2_Cap_CheckBlocks(const bool is_long);
void V2_Cap_Sync(const bool is_long, const int layer_count);
void V2_Cap_RecordBlock(const bool is_long);   // if needed by profile
```

Each thin shell **implements** these three functions **before** `#include "fxmatrix_v2_engine.mqh"`, calling only the cap headers that shell includes:

| Shell | Includes | Bridge calls |
|-------|----------|--------------|
| GBPUSD | `gbp_cap.mqh` | `V2_GbpCapBlocksNewAdd`, `V2_GbpCapSyncInstance`, `V2_GbpCapRecordBlock` |
| EURUSD | `eur_cap.mqh` | `V2_EurCapBlocksNewAdd`, `V2_EurCapSyncInstance`, … |
| EURGBP | `gbp_cap.mqh` + `eur_cap.mqh` + `eurgbp_dual_cap.mqh` | `V2_AnyCapBlocksNewAdd`, `V2_SyncAllCaps`, … |

**Hard rule:** `fxmatrix_v2_engine.mqh` calls **`V2_Cap_CheckBlocks` / `V2_Cap_Sync` / `V2_Cap_RecordBlock` exclusively**. It must **never** reference `V2_GbpCap*`, `V2_EurCap*`, `V2_AnyCap*`, or `V2_SyncAllCaps` directly, and must **never** `#include` cap module headers.

`g_preset.cap_profile` remains for telemetry and `OnInit` validation only — **not** for compile-time switch dispatch inside the engine.

### 4.2 Engine integration (four call sites)

Replace direct cap calls in shared `EnsureAddNext`, `RemoveLayerAt`, and `OnInit` with bridge calls. Threshold values come from shell `input` (`InpGbpCapThreshold`, `InpEurCapThreshold`) inside the bridge implementation, not the engine.

### 4.3 ADR-103 orphan-aware publish (exact sequencing)

`OnInit` order in engine (unchanged from production):

1. `Long_OnInit()` / `Short_OnInit()` (layer restore, pending order scan).
2. Orphan scan → set `g_long_halted` / `g_short_halted`.
3. **Only if** `V2_ShouldPublishCapSyncOnInit(!long_orphan)`: `V2_Cap_Sync(true, long_layer_count)`.
4. Same for short side.
5. **No** `GlobalVariableSet("V2GBP_CAP_TRIGGERS", 0)` or EUR trigger reset (ADR-103).

### 4.4 ADR-102 halt gate (exact sequencing)

In `Long_HandleDealFill` / `Short_HandleDealFill` (engine):

1. Dedup / `HistoryDealSelect`.
2. Symbol + magic ownership via `V2_IsManagedLongEntryDeal` / `V2_IsManagedExitDeal` (using `g_preset.magic_*`).
3. `V2_MarkDealProcessed`.
4. **Then** per-side halt gate: if `(entry || exit) && g_*_halted` → alert and **return** (no CloseBy queue).

Gate is **after** deal-ownership validation, **not** before.

---

## 5. Build-time enforcement tests (Gemini-ruled + DeepSeek Blocker 5)

### 5.1 Pair-label linter (Gemini-ruled)

**Test:** scan `fxmatrix_v2_engine.mqh` for literal strings `"GBPUSD"`, `"EURUSD"`, `"EURGBP"`. **Fail the build** if any appear in the engine body.

**Rationale:** the shared engine must be pair-agnostic. All pair-specific routing lives in:

- a shell's cap-bridge implementation, or
- `V2_L0Compute*` wrapper leg-symbol resolution / `preset.signal_slot` branch (in `l0_signal.mqh`, not engine), or
- preset fragment constants (magic, default leg symbols).

**Implementation options:** extend `fxmatrix_v2_tests.mq5` with a file-read assertion, or a small Python pre-commit script invoked before compile. Either way, the test is mandatory before parity gate sign-off.

### 5.2 Magic-literal grep test (DeepSeek Blocker 5)

**Production audit (GBPUSD `fxmatrix_v2.mq5` — raw literals bypassing macros):**

| Location | Literal | Purpose |
|----------|---------|---------|
| `Long_EnsureAddNext` | `20260901` | `Long_PlaceBuyLimit` magic |
| `Long_ReplacePendingBuy` / L0 | `20260901` | pending replace magic |
| `Long_HandleDealFill` | `(long)20260901` | entry deal classification |
| `Long_OnInit` print | `20260901` | diagnostic |
| Short-side analogs | `20260902` | same pattern |

EURUSD/EURGBP use `#define MM_LONG_V2` / `MM_SHORT_V2` in the shell (20260911/12, 20260921/22) — no raw literals in deal/order paths, but unified engine must use **`g_preset.magic_*` everywhere**, including GBPUSD paths.

**Rule:** unified engine routes **every** magic-number reference through `g_preset.magic_long`, `g_preset.magic_short`, `g_preset.magic_long_exit`, `g_preset.magic_short_exit`. **No raw magic literals** in `fxmatrix_v2_engine.mqh`, `fxmatrix_v2_l0_signal.mqh`, or any shared header.

**Test:** static grep (Python or test harness) fails if any of `{20260901, 20260902, 20260911, 20260912, 20260921, 20260922}` or exit-magic literals appear outside `fxmatrix_v2_preset_*.mqh` fragment files.

---

## 6. EURGBP deadband flag (DeepSeek Blocker 6)

Production behavior:

| Pair | `l0_deadband_vol_scale_enabled` | Deadband call |
|------|--------------------------------|---------------|
| GBPUSD | false | `V2_L0RestingWithinDeadband(..., InpL0DeadbandMult)` — 4-arg, no spread ref |
| EURUSD | true (preset) | `V2_L0RestingWithinDeadband(..., InpL0DeadbandMult, spread_ref)` where `spread_ref = (g_preset.l0_deadband_vol_scale_enabled && InpL0DeadbandVolScale) ? g_preset.l0_deadband_spread_ref_pips : 0.0`. **`InpL0DeadbandVolScale` is a shell `input` on EURUSD only** (production default `true`). |
| EURGBP | **false** | 4-arg call only — **`V2_PAIR_SPREAD_PIPS_REF 0.63` exists but is unused**; must not imply scaling |

Engine L0 replace path:

```cpp
double spread_ref = 0.0;
if(g_preset.l0_deadband_vol_scale_enabled)
   spread_ref = InpL0DeadbandVolScale ? g_preset.l0_deadband_spread_ref_pips : 0.0;
// GBPUSD/EURGBP shells: declare `input bool InpL0DeadbandVolScale = false;` for compile
// compatibility (engine references the input; preset.enabled gates behavior)
// pass spread_ref into V2_L0RestingWithinDeadband / ShouldRequoteL0
```

Vol-scale is **orthogonal** to `V2_L0CoreCompute*` signal dispatch.

---

## 7. Shared engine body

### 7.1 What moves into `fxmatrix_v2_engine.mqh`

Single copy of all logic currently duplicated across three production files:

- Global state structs, stats counters, halt flags, rollover retry (ADR-101), pods, telemetry
- `Long_*` / `Short_*` function bodies
- Chart-level `OnInit`, `OnTick`, `OnDeinit`, `OnTradeTransaction`
- ADR-102 halt gate, ADR-103 cap-publish ordering (§4.3–4.4)
- Telemetry emit, API counter reset

### 7.2 Pair-specific routing summary

| Concern | Mechanism |
|---------|-----------|
| Magic numbers | `g_preset.magic_*` only |
| Telemetry labels | `g_preset.tel_instance_*` |
| Signal BC vs AB | `preset.signal_slot` → wrapper in `l0_signal.mqh` |
| Easing / spread / exit params | shell `input` only |
| Cap block/sync | shell `V2_Cap_*` bridge |
| L0 deadband vol-scale | `g_preset.l0_deadband_vol_scale_enabled` + ref pips |
| EURGBP leg symbols | preset defaults + `InpLegAC` / `InpLegBC` inputs |

### 7.3 Estimated size reduction

~1,500 lines × 3 → ~1,500 lines engine + ~60–120 lines × 3 shells + ~250 lines dispatch/preset/bridge headers.

---

## 8. Equivalence / parity verification plan

### 8.1 Gate principle

**No production replacement** until behavioral parity passes on all three pairs. Refactor gate only — inputs and locked ADR thresholds match production `.set` / defaults exactly.

**Tolerance policy:** per ARCHITECT.md Mandatory Refactoring Parity Gate (dual-tolerance real-tick backtest):

| Category | Bar |
|----------|-----|
| Order counts, exit counts, max layers, peak net lots | **Exact match** |
| Normalized order prices (tick-rounded) | **Exact match** at symbol precision |
| Raw internal doubles (sigma, log returns, pre-normalize dynamic_hs) | **~1e-9 relative** tolerance allowed |
| P&L | **Exact** if deal sequence identical; else **±$0.01 USD** explicit rounding tolerance (FTMO demo account currency) |

Discrete outcomes are the primary pass/fail; raw-float tolerance is diagnostic-only and must not excuse normalized-price or deal-sequence divergence.

### 8.2 Canonical windows — verified from repo configs

Source of truth: `temp/run_adr097_threshold_sweep_verify.py` `WINDOWS` dict, matching `temp/sm0_gbpusd_*.ini`, `temp/v2_*_truss_crisis_six.ini`, and ADR-097/098/099 sweep scripts.

All dates are **inclusive FromDate, exclusive ToDate** (MT5 tester convention as used in project INI files).

| Window | FromDate (UTC) | ToDate (UTC) | Primary use |
|--------|----------------|--------------|-------------|
| `truss_crisis` | 2022.08.01 | 2022.11.01 | ADR calibration + parity (all pairs) |
| `q1_2024_chop` | 2023.12.15 | 2024.04.15 | ADR calibration + parity |
| `vaccine_rally` | 2020.10.15 | 2021.03.15 | ADR calibration + parity |
| `full_quarter` | 2026.03.09 | 2026.06.06 | ADR calibration + parity |
| `june_blowup` | 2026.06.05 | 2026.06.10 | EURGBP holdout / passive-fill stress (`temp/sm0_gbpusd_june_blowup.ini`, `temp/eurgbp_inst_prod_june_blowup.ini`) |

**Minimum parity matrix:**

- **GBPUSD / EURUSD:** all five windows above.
- **EURGBP:** all five (june_blowup mandatory — known passive-limit stress case).

### 8.3 Tester configuration — verified from repo INI files

Values below copied from production verification INI templates (`temp/sm0_gbpusd_truss_crisis.ini`, `temp/v2_eurusd_truss_crisis_six.ini`, `temp/v2_eurgbp_truss_crisis_six.ini`, and siblings). **Do not invent alternatives.**

| Parameter | Value | Source field |
|-----------|-------|--------------|
| **Model (INI)** | `Model=4` | `[Tester]` |
| **ENUM_TESTING_MODEL** | `TESTING_MODEL_EXCHANGE` (numeric **4**) | MT5 API name for "Every tick based on real ticks" |
| **Report label** | "100% real ticks" / History Quality 100% | Verified in `temp/gbpusd_inst_clamp_truss_crisis.htm` |
| **Period** | M5 | `[Tester] Period=M5` |
| **Symbol** | GBPUSD / EURUSD / EURGBP per shell | `[Tester] Symbol=` |
| **Deposit** | 10 000 | `[Tester] Deposit=10000` |
| **Currency** | USD | `[Tester] Currency=USD` |
| **Leverage** | 1:30 (`Leverage=30`) | `[Tester] Leverage=30` |
| **ExecutionMode** | 0 (normal instant execution in tester) | `[Tester] ExecutionMode=0` |
| **ForwardMode** | 0 | `[Tester] ForwardMode=0` |
| **Server (data source)** | FTMO-Demo | `[Common] Server=FTMO-Demo` |
| **Spread model** | Real tick replay + EA `InpQuoteSpread=0.0004` input | No separate tester spread override on Model=4; quote spread via EA input |
| **Commission** | Broker default (zero in FTMO-Demo reports reviewed) | HTML reports show Commission column; no custom commission INI key in project templates |

**Known data caveat (document, do not hide):** `temp/spread_mult_0125_vaccine_rally_download_steps.txt` records that **vaccine_rally** (2020 dates) on Model=4 may fall back to **generated ticks** when broker real-tick history begins after 2020 (log strings: "real ticks discarded … every tick generation used"). Parity runs on vaccine_rally must capture tester log and note whether the window used 100% real ticks or generated fill for the pre-history segment. This is a **reporting requirement**, not a reason to skip the window.

### 8.4 Layer 1 — Unit tests (necessary, not sufficient)

Extend `fxmatrix_v2_tests.mq5`:

- `V2_L0CoreComputeBc` / `V2_L0CoreComputeAb`: ramp, floor, cold-start — ADR-097/098/099 vectors against **pure core**.
- Pair-label linter (§5.1) and magic-literal grep (§5.2) as PASS/FAIL tests.
- Cap bridge: optional `#ifdef` test doubles if needed; primary cap parity is Layer 2.

### 8.5 Layer 2 — Side-by-side Strategy Tester (deciding evidence)

For each pair × window, run **production EA vs unified shell**:

- Identical `[Tester]` block per §8.3 (Model=4, dates, deposit, leverage, symbol).
- Identical `.set` / `[TesterInputs]` — production locked defaults; delete stale tester profile first.
- `InpVerboseLog=true` on at least one window per pair for DIAG extraction.

Compare via `analyze_mt5_report()` (human-read; not automated pass/fail). Apply dual-tolerance policy (§8.1).

### 8.6 Layer 3 — DIAG spot checks

One window per pair: diff `event=l0_ease` and `event=l0_lag` lines — `effective_multiplier`, `dynamic_hs`, `opposite_depth` must match bar-for-bar when logs enabled.

### 8.7 Layer 4 — Halt / cap edge cases

Dedicated scenarios:

- Orphan one side → ADR-102 halt gate + ADR-103 cap publish skip.
- EURGBP dual-cap block logging (ADR-100).

### 8.8 Rollout sequence

1. Implement behind **new shell names** (production untouched).
2. Layers 1–4 pass.
3. ADR documenting unified engine cutover.
4. Khalid GUI compile + personal Tester verification.
5. Replace production filenames only after ADR acceptance.

---

## 9. Production structure surprises (retained)

1. **Inlined signal** in `.mq5` bodies — extract to pure core from production, not `signal.mqh` stubs.
2. **EURUSD vol-scale deadband** is orthogonal to signal dispatch (§6).
3. **EURGBP leg runtime overrides** — preset defaults + `InpLegAC`/`InpLegBC`.
4. **MQL5 `#include` order** — cap headers before engine; bridge impl before engine include.
5. **Three `.ex5` binaries** still required for VPS.
6. **`logic.mqh` / `exits.mqh`** stay production — no `_r1` fork.

---

## 10. Out of scope

- Native EURGBP sigma migration (parked — ARCHITECT.md).
- Parameter/threshold recalibration.
- VPS deployment procedure changes.
- Production filename swap before parity gate passes.

---

## 11. Resolved questions (formerly open)

| Question | Resolution |
|----------|------------|
| Preset vs input resolution | Behavioral params shell-`input` only; preset structural only (§2). |
| Cap include strategy | Shell bridge pattern; engine never includes cap headers (§4). |
| Unit-testable L0 | Pure core + wrapper split (§3.2). |
| Parity tolerance | ARCHITECT.md dual-tolerance + §8.1; concrete tester params §8.2–8.3. |
| Pair-label branching in engine | Forbidden — linter test §5.1. |
| Magic literals | Preset-only; grep test §5.2. |
| EURGBP deadband | Explicit `l0_deadband_vol_scale_enabled=false` (§6). |

---

*End of revised specification.*
