# Cursor Implementation Prompt — ADR-024 Phase 1
# Scope: LayerStruct.mqh + Globals.mqh only
# This message has a line count at the bottom.

---

## MANDATORY FIRST STEP

Before making any edits, confirm the following anchor line numbers from
the CURRENT files on disk. Report each line number back to me before
proceeding. Do NOT begin editing until you have confirmed all anchors.

**LayerStruct.mqh — confirm line numbers of:**
1. `enum InstrumentType {` declaration
2. `EU_mid_12bars_ago_at_entry` field in Layer struct
3. `GB_mid_12bars_ago_at_entry` field in Layer struct
4. `r_EU_at_entry` field in Layer struct
5. `r_GB_at_entry` field in Layer struct
6. `entry_price_eurusd` field in Layer struct
7. `entry_price_gbpusd` field in Layer struct
8. `entry_price_eurusd_1h` field in Layer struct
9. `entry_price_gbpusd_1h` field in Layer struct
10. The IMMUTABILITY CONTRACT comment block start
11. `Layer InitLayer()` function start

**Globals.mqh — confirm line numbers of:**
12. `input double r_USD` line
13. `input double r_EUR` line
14. `input double r_GBP` line
15. `double g_r_EU_signal` line
16. `double g_r_GB_signal` line
17. `double g_EU_mid_12bars_ago` line
18. `double g_GB_mid_12bars_ago` line
19. `double g_score_eur` line
20. `double g_score_gbp` line
21. `double g_score_usd` line
22. `double g_r_EU_GU` line
23. `double g_vratio_EU` line
24. `Layer g_inventory_EURUSD[]` line
25. `ulong g_pending_bid_EURUSD` line
26. `ulong g_add_next_EURUSD` line
27. `datetime g_last_layer_time_EURUSD` line
28. `int InitGlobals()` function start

---

## CONTEXT

This is Phase 1 of the ADR-024 V3 Generic Triad Architecture refactor.
FXMatrix V2 is hardcoded to EUR/GBP/USD. V3 replaces all hardcoded
currency references with configurable inputs and slot-indexed arrays.

This prompt covers ONLY LayerStruct.mqh and Globals.mqh. No other files
are touched in this prompt. The remaining files (MathEngine, CarryEngine,
StateEngine, ExecutionEngine, FXMatrix.mq5, TelemetryEngine) will be
handled in subsequent prompts after F7 compile succeeds on these two.

---

## ARCHITECTURAL CONSTANTS (BINDING — DO NOT DEVIATE)

### Slot ordering — MANDATORY, enforced by Gemini ruling

The three pair slots MUST be assigned in this exact order:
- **Slot 0 = PairAC** (e.g. EURUSD when A=EUR, C=USD)
- **Slot 1 = PairBC** (e.g. GBPUSD when B=GBP, C=USD)
- **Slot 2 = PairAB** (e.g. EURGBP when A=EUR, B=GBP)

This ordering preserves the V2 LDAK correlation index mapping exactly.
It is NOT [AB, AC, BC]. It is [AC, BC, AB]. This is non-negotiable.

### Currency score slot assignment
- **scores[0] = score_A** (e.g. EUR)
- **scores[1] = score_B** (e.g. GBP)
- **scores[2] = score_C** (e.g. USD)

Currency slots (A/B/C) and pair slots (AC/BC/AB) are DIFFERENT indexing
schemes. Currency slot i != pair slot i. Do not conflate them.

---

## CHANGES TO LayerStruct.mqh

### 1. Remove InstrumentType enum — replace with slot constants

DELETE the entire enum:
```
enum InstrumentType {
    INSTRUMENT_EURUSD = 0,
    INSTRUMENT_GBPUSD = 1,
    INSTRUMENT_EURGBP = 2
};
```

REPLACE with:
```
// ADR-024: V3 Generic Triad — pair slot indices
// Slot ordering is BINDING per Gemini ruling:
//   Slot 0 = PairAC (signal pair 1, e.g. EURUSD)
//   Slot 1 = PairBC (signal pair 2, e.g. GBPUSD)
//   Slot 2 = PairAB (cross pair,   e.g. EURGBP)
// DO NOT REORDER. LDAK correlation indices depend on this ordering.
#define SLOT_AC  0   // PairAC — first signal pair
#define SLOT_BC  1   // PairBC — second signal pair
#define SLOT_AB  2   // PairAB — cross pair

// Legacy aliases — used in files not yet migrated to V3.
// Remove these aliases once all files are migrated in subsequent prompts.
#define INSTRUMENT_EURUSD  SLOT_AC
#define INSTRUMENT_GBPUSD  SLOT_BC
#define INSTRUMENT_EURGBP  SLOT_AB
```

The legacy aliases allow the remaining V2 files (MathEngine, ExecutionEngine
etc.) to continue compiling unchanged until their migration prompts run.
This is intentional. Do NOT remove the aliases in this prompt.

### 2. Rename EUR/GBP-named Layer struct fields

In the `Layer` struct, make the following renames. Field types and
positions in the struct do NOT change — rename only:

| Old name | New name |
|---|---|
| `EU_mid_12bars_ago_at_entry` | `anchor_A_at_entry` |
| `GB_mid_12bars_ago_at_entry` | `anchor_B_at_entry` |
| `r_EU_at_entry` | `r_AC_at_entry` |
| `r_GB_at_entry` | `r_BC_at_entry` |
| `entry_price_eurusd` | `entry_price_AC` |
| `entry_price_gbpusd` | `entry_price_BC` |
| `entry_price_eurusd_1h` | `entry_price_AC_1h` |
| `entry_price_gbpusd_1h` | `entry_price_BC_1h` |

### 3. Update the IMMUTABILITY CONTRACT comment block

In the IMMUTABILITY CONTRACT comment, update the field name list to use
the new names. Replace all eight old names with the new names exactly as
in the table above. The contract text otherwise stays identical.

### 4. Update InitLayer() zero-initialisation

In `InitLayer()`, rename the corresponding field assignments to match
the new names:

| Old assignment | New assignment |
|---|---|
| `L.EU_mid_12bars_ago_at_entry = 0.0;` | `L.anchor_A_at_entry = 0.0;` |
| `L.GB_mid_12bars_ago_at_entry = 0.0;` | `L.anchor_B_at_entry = 0.0;` |
| `L.r_EU_at_entry = 0.0;` | `L.r_AC_at_entry = 0.0;` |
| `L.r_GB_at_entry = 0.0;` | `L.r_BC_at_entry = 0.0;` |
| `L.entry_price_eurusd = 0.0;` | `L.entry_price_AC = 0.0;` |
| `L.entry_price_gbpusd = 0.0;` | `L.entry_price_BC = 0.0;` |
| `L.entry_price_eurusd_1h = 0.0;` | `L.entry_price_AC_1h = 0.0;` |
| `L.entry_price_gbpusd_1h = 0.0;` | `L.entry_price_BC_1h = 0.0;` |

### 5. Update InitLayer() instrument default

Change:
```
L.instrument = INSTRUMENT_EURUSD;
```
To:
```
L.instrument = SLOT_AC;
```

---

## CHANGES TO Globals.mqh

### 1. Add V3 configurable triad inputs

AFTER the existing `input string CarryRecalcTime` line, ADD the following
new input block. Do NOT remove any existing inputs yet — the legacy inputs
will be removed in subsequent migration prompts once all files are updated.

```mql5
//--- ADR-024: V3 Generic Triad Configuration
input string CurrencyA  = "EUR";     // First currency of triad
input string CurrencyB  = "GBP";     // Second currency of triad
input string CurrencyC  = "USD";     // Third currency (base denominator)
input string PairAC     = "EURUSD";  // Slot 0: CurrencyA vs CurrencyC
input string PairBC     = "GBPUSD";  // Slot 1: CurrencyB vs CurrencyC
input string PairAB     = "EURGBP";  // Slot 2: CurrencyA vs CurrencyB
```

REPLACE the three legacy rate inputs:
```mql5
input double r_USD  = 0.0533;
input double r_EUR  = 0.0390;
input double r_GBP  = 0.0520;
```
WITH:
```mql5
input double RateA  = 0.0390;  // Interest rate for CurrencyA (e.g. ESTR for EUR)
input double RateB  = 0.0520;  // Interest rate for CurrencyB (e.g. SONIA for GBP)
input double RateC  = 0.0533;  // Interest rate for CurrencyC (e.g. SOFR for USD)
```

ADD legacy aliases immediately after the new rate inputs so that
CarryEngine.mqh (not yet migrated) continues to compile:
```mql5
// Legacy carry rate aliases — remove once CarryEngine.mqh is migrated
#define r_EUR  RateA
#define r_GBP  RateB
#define r_USD  RateC
```

### 2. Add g_symbols[] global array

AFTER the `double g_score_usd` line, ADD:
```mql5
// ADR-024: V3 canonical symbol array — slot ordering BINDING
// g_symbols[SLOT_AC] = PairAC, g_symbols[SLOT_BC] = PairBC,
// g_symbols[SLOT_AB] = PairAB
// Populated in InitGlobals(). Read-only after that.
string g_symbols[3];
```

### 3. Replace named signal globals with slot-indexed arrays

REPLACE:
```mql5
double   g_r_EU_signal          = 0.0;
double   g_r_GB_signal          = 0.0;
double   g_EU_mid_12bars_ago    = 0.0;
double   g_GB_mid_12bars_ago    = 0.0;
```
WITH:
```mql5
// ADR-024: V3 slot-indexed signal globals
// Index 0 = PairAC signal, Index 1 = PairBC signal
double   g_r_signal[2]          = {0.0, 0.0};  // log returns [AC, BC]
double   g_anchor[2]            = {0.0, 0.0};  // 12-bar-ago mids [AC, BC]

// Legacy aliases — remove once MathEngine.mqh and ExecutionEngine.mqh migrated
#define g_r_EU_signal        g_r_signal[0]
#define g_r_GB_signal        g_r_signal[1]
#define g_EU_mid_12bars_ago  g_anchor[0]
#define g_GB_mid_12bars_ago  g_anchor[1]
```

### 4. Replace named score globals with slot-indexed array

REPLACE:
```mql5
double g_score_eur            = 0.0;
double g_score_gbp            = 0.0;
double g_score_usd            = 0.0;
```
WITH:
```mql5
// ADR-024: V3 slot-indexed currency scores
// scores[0]=score_A, scores[1]=score_B, scores[2]=score_C
double g_scores[3]            = {0.0, 0.0, 0.0};

// Legacy aliases — remove once all files migrated
#define g_score_eur  g_scores[0]
#define g_score_gbp  g_scores[1]
#define g_score_usd  g_scores[2]
```

### 5. Replace named LDAK correlation globals with slot-indexed array

REPLACE:
```mql5
double g_r_EU_GU = 0.0;
double g_r_EU_EG = 0.0;
double g_r_GU_EG = 0.0;
```
WITH:
```mql5
// ADR-024: V3 LDAK pairwise correlation array
// Slot ordering BINDING [AC, BC, AB]:
//   g_corr[0] = corr(slot0, slot1) = corr(PairAC, PairBC)
//   g_corr[1] = corr(slot0, slot2) = corr(PairAC, PairAB)
//   g_corr[2] = corr(slot1, slot2) = corr(PairBC, PairAB)
// When A=EUR, B=GBP, C=USD:
//   g_corr[0] = g_r_EU_GU, g_corr[1] = g_r_EU_EG, g_corr[2] = g_r_GU_EG
double g_corr[3]  = {0.0, 0.0, 0.0};

// Legacy aliases — remove once MathEngine.mqh migrated
#define g_r_EU_GU  g_corr[0]
#define g_r_EU_EG  g_corr[1]
#define g_r_GU_EG  g_corr[2]
```

### 6. Replace named LDAK vratio globals with slot-indexed array

REPLACE:
```mql5
double g_vratio_EU = 1.0;
double g_vratio_GU = 1.0;
double g_vratio_EG = 1.0;
```
WITH:
```mql5
// ADR-024: V3 LDAK volatility ratio array [slot 0, 1, 2]
double g_vratio[3] = {1.0, 1.0, 1.0};

// Legacy aliases — remove once MathEngine.mqh migrated
#define g_vratio_EU  g_vratio[0]
#define g_vratio_GU  g_vratio[1]
#define g_vratio_EG  g_vratio[2]
```

### 7. Replace named inventory arrays with slot-indexed 2D array

REPLACE:
```mql5
Layer        g_inventory_EURUSD[];
Layer        g_inventory_GBPUSD[];
Layer        g_inventory_EURGBP[];
```
WITH:
```mql5
// ADR-024: V3 slot-indexed inventory — g_inventory[slot][layer]
// slot 0=PairAC, slot 1=PairBC, slot 2=PairAB
// MQL5 requires fixed first dimension for 2D arrays declared globally.
// We use three flat arrays named by slot for compiler compatibility,
// accessed via slot index through helper macros below.
Layer        g_inventory_0[];   // PairAC inventory
Layer        g_inventory_1[];   // PairBC inventory
Layer        g_inventory_2[];   // PairAB inventory

// Legacy aliases — remove once all files migrated
#define g_inventory_EURUSD  g_inventory_0
#define g_inventory_GBPUSD  g_inventory_1
#define g_inventory_EURGBP  g_inventory_2
```

NOTE ON MQL5 2D ARRAYS: MQL5 does not support dynamic 2D arrays passed
by reference as function arguments. We use three named flat arrays with
slot-indexed access via a helper macro rather than a true 2D array. This
is the Gemini-approved T2 approach for TelemetryEngine compatibility.

### 8. Replace named pending ticket globals with slot-indexed arrays

REPLACE:
```mql5
ulong    g_pending_bid_EURUSD   = 0;
ulong    g_pending_offer_EURUSD = 0;
ulong    g_pending_bid_GBPUSD   = 0;
ulong    g_pending_offer_GBPUSD = 0;
ulong    g_pending_bid_EURGBP   = 0;
ulong    g_pending_offer_EURGBP = 0;

ulong    g_add_next_EURUSD = 0;
ulong    g_add_next_GBPUSD = 0;
ulong    g_add_next_EURGBP = 0;
```
WITH:
```mql5
// ADR-024: V3 slot-indexed pending ticket arrays
ulong    g_pending_bid[3]   = {0, 0, 0};
ulong    g_pending_offer[3] = {0, 0, 0};
ulong    g_add_next[3]      = {0, 0, 0};

// Legacy aliases — remove once ExecutionEngine.mqh and FXMatrix.mq5 migrated
#define g_pending_bid_EURUSD    g_pending_bid[0]
#define g_pending_offer_EURUSD  g_pending_offer[0]
#define g_pending_bid_GBPUSD    g_pending_bid[1]
#define g_pending_offer_GBPUSD  g_pending_offer[1]
#define g_pending_bid_EURGBP    g_pending_bid[2]
#define g_pending_offer_EURGBP  g_pending_offer[2]
#define g_add_next_EURUSD       g_add_next[0]
#define g_add_next_GBPUSD       g_add_next[1]
#define g_add_next_EURGBP       g_add_next[2]
```

### 9. Replace named last-layer-time globals with slot-indexed array

REPLACE:
```mql5
datetime g_last_layer_time_EURUSD = 0;
datetime g_last_layer_time_GBPUSD = 0;
datetime g_last_layer_time_EURGBP = 0;
```
WITH:
```mql5
// ADR-024: V3 slot-indexed last layer timestamps
datetime g_last_layer_time[3] = {0, 0, 0};

// Legacy aliases — remove once FXMatrix.mq5 migrated
#define g_last_layer_time_EURUSD  g_last_layer_time[0]
#define g_last_layer_time_GBPUSD  g_last_layer_time[1]
#define g_last_layer_time_EURGBP  g_last_layer_time[2]
```

### 10. Update InitGlobals() to populate g_symbols[] and resize slot arrays

In the `InitGlobals()` function body, ADD the following BEFORE the
existing ArrayResize calls:

```mql5
    // ADR-024: V3 — populate canonical symbol array from inputs
    // Slot ordering BINDING: [AC, BC, AB]
    g_symbols[SLOT_AC] = PairAC;
    g_symbols[SLOT_BC] = PairBC;
    g_symbols[SLOT_AB] = PairAB;
```

REPLACE the three named ArrayResize calls:
```mql5
    ArrayResize(g_inventory_EURUSD, 0);
    ArrayResize(g_inventory_GBPUSD, 0);
    ArrayResize(g_inventory_EURGBP, 0);
```
WITH:
```mql5
    ArrayResize(g_inventory_0, 0);
    ArrayResize(g_inventory_1, 0);
    ArrayResize(g_inventory_2, 0);
```

REPLACE the three named last-layer-time resets:
```mql5
    g_last_layer_time_EURUSD = 0;
    g_last_layer_time_GBPUSD = 0;
    g_last_layer_time_EURGBP = 0;
```
WITH:
```mql5
    g_last_layer_time[0] = 0;
    g_last_layer_time[1] = 0;
    g_last_layer_time[2] = 0;
```

Also update the Print() at the end of InitGlobals() to include the
configured triad:
```mql5
    Print("FXMatrix V3 EA initialised. Triad=",
          CurrencyA, "/", CurrencyB, "/", CurrencyC,
          " Pairs=[", PairAC, ",", PairBC, ",", PairAB, "]",
          " NudgeThreshold=", g_NudgeThreshold, " points");
```

---

## WHAT NOT TO TOUCH

- Do NOT modify MathEngine.mqh, CarryEngine.mqh, StateEngine.mqh,
  ExecutionEngine.mqh, FXMatrix.mq5, or TelemetryEngine.mqh.
  Those files are covered in subsequent prompts.
- Do NOT remove any legacy #define aliases. They are intentional
  scaffolding to keep unmigrated files compiling.
- Do NOT change the DirectionType enum — it is already generic.
- Do NOT change any input parameters other than those explicitly
  listed above (carry rates and new triad inputs).
- Do NOT change any validation logic in InitGlobals().
- Do NOT change the CloseByTask struct.
- Do NOT add any new functions.

---

## SELF-REVIEW CHECKLIST

Before responding, verify every item:

- [ ] Anchor line numbers confirmed and reported before any edits
- [ ] `InstrumentType` enum removed and replaced with `#define` slot constants
- [ ] Legacy `INSTRUMENT_*` aliases present and pointing to correct slot values
- [ ] All 8 Layer struct field renames applied
- [ ] IMMUTABILITY CONTRACT comment updated with new field names
- [ ] `InitLayer()` updated with new field names and `SLOT_AC` default
- [ ] `g_symbols[3]` declared and populated in `InitGlobals()`
- [ ] `g_r_signal[2]` and `g_anchor[2]` declared with legacy aliases
- [ ] `g_scores[3]` declared with legacy aliases
- [ ] `g_corr[3]` declared with LDAK slot ordering comment and legacy aliases
- [ ] `g_vratio[3]` declared with legacy aliases
- [ ] Three named inventory arrays replaced with `g_inventory_0/1/2[]`
  with legacy aliases
- [ ] `g_pending_bid[3]`, `g_pending_offer[3]`, `g_add_next[3]` declared
  with legacy aliases
- [ ] `g_last_layer_time[3]` declared with legacy aliases
- [ ] `RateA`, `RateB`, `RateC` inputs added, old `r_EUR/GBP/USD` replaced,
  legacy `#define` aliases present
- [ ] `CurrencyA/B/C` and `PairAC/BC/AB` inputs added
- [ ] `InitGlobals()` populates `g_symbols[]` from inputs
- [ ] `InitGlobals()` uses `g_inventory_0/1/2` in ArrayResize calls
- [ ] `InitGlobals()` uses `g_last_layer_time[0/1/2]` in reset
- [ ] F7 compile in MetaEditor produces ZERO errors and ZERO warnings
- [ ] No other files modified

---

## EXPECTED COMPILE RESULT

Because all legacy `#define` aliases are in place, all other EA files
(MathEngine, ExecutionEngine, etc.) should continue to resolve their
named references through the aliases. F7 compile must report zero errors
and zero warnings before this prompt is considered complete.

If any warning or error appears, report it in full before attempting
any fix.

---

Line count: 161
