# Cursor Implementation Prompt 1 of 4
# Scope: LayerStruct.mqh + Global State Definitions
# Reference: ADR-002 v4 Section 2, Section 8.2

This message has a line count at the bottom.
Read this entire prompt before writing a single line of code.
Do not begin implementation until you have read all sections.

---

## Context

You are implementing a native MQL5 Expert Advisor for a
3-currency FX mean-reversion pod (EUR, GBP, USD) running on
an FTMO MT5 hedging account. This is Prompt 1 of 4. You are
building the state definition layer only. No execution logic.
No order placement. No OnTick. No OnTradeTransaction.

The full specification lives in:
- d:\fxmatrix\adrs\ADR-002-matrix-driven-exits-v4.md
- d:\fxmatrix\adrs\ADR-003-carry-adjustment-v2.md

Read both before starting. This prompt is a precise subset of
those documents. If anything in this prompt conflicts with the
ADRs, the ADRs take precedence.

---

## Deliverable

Two files:

1. `d:\fxmatrix\ea\LayerStruct.mqh`
   The canonical Layer struct and associated constants.

2. `d:\fxmatrix\ea\Globals.mqh`
   All global signal state variables used across the EA.

No other files. No EA entry point. No includes beyond what
these two files define internally.

---

## File 1: LayerStruct.mqh

### Required content

#### Constants

```mql5
#define VOLUME_EPSILON     0.0001   // minimum volume for remaining_volume == 0 check
#define FALLBACK_TIME_WINDOW 30     // seconds, for ticket fallback matching
#define MAX_EXIT_TICKETS   20       // maximum exit ticket slots per layer
```

#### The Layer struct

Implement EXACTLY this struct. Field names, types, and order
are canonical. Do not add fields. Do not remove fields.
Do not rename fields.

```mql5
struct Layer {
    // --- Entry state (immutable after first fill) ---
    double   entry_price;
    double   entry_spread_raw;
    datetime entry_time;
    double   EU_mid_12bars_ago_at_entry;
    double   GB_mid_12bars_ago_at_entry;
    double   r_EU_at_entry;
    double   r_GB_at_entry;
    int      strongest_at_entry;
    int      weakest_at_entry;

    // --- Carry recalculation inputs (immutable) ---
    double   entry_price_eurusd;
    double   entry_price_gbpusd;
    double   entry_price_eurusd_1h;
    double   entry_price_gbpusd_1h;
    int      instrument;
    int      direction;

    // --- Carry-adjusted state (ADR-003 updates only) ---
    double   entry_spread_adjusted;
    double   entry_price_forward;

    // --- Exit targets (ADR-003 OrderModify only) ---
    double   exit_spread_target;
    double   exit_target;

    // --- Layer mechanics ---
    double   add_next;
    double   lot_size;
    double   remaining_entry_volume;        // decrements on entry fills; 0 = entry complete
    double   remaining_exit_volume;         // set to lot_size when entry complete; decrements on exits

    // --- Order tracking ---
    ulong    entry_ticket;
    ulong    exit_tickets[];
};
```

#### Instrument and direction enums

```mql5
enum InstrumentType {
    INSTRUMENT_EURUSD = 0,
    INSTRUMENT_GBPUSD = 1,
    INSTRUMENT_EURGBP = 2
};

enum DirectionType {
    DIRECTION_BUY  =  1,
    DIRECTION_SELL = -1
};
```

#### Layer initialisation function

Write a function `InitLayer()` that returns a zeroed Layer
with exit_tickets[] initialised as an empty dynamic array:

```mql5
Layer InitLayer() {
    Layer L;
    // zero all scalar fields
    L.entry_price                  = 0.0;
    L.entry_spread_raw             = 0.0;
    L.entry_time                   = 0;
    L.EU_mid_12bars_ago_at_entry   = 0.0;
    L.GB_mid_12bars_ago_at_entry   = 0.0;
    L.r_EU_at_entry                = 0.0;
    L.r_GB_at_entry                = 0.0;
    L.strongest_at_entry           = 0;
    L.weakest_at_entry             = 0;
    L.entry_price_eurusd           = 0.0;
    L.entry_price_gbpusd           = 0.0;
    L.entry_price_eurusd_1h        = 0.0;
    L.entry_price_gbpusd_1h        = 0.0;
    L.instrument                   = INSTRUMENT_EURUSD;
    L.direction                    = DIRECTION_BUY;
    L.entry_spread_adjusted        = 0.0;
    L.entry_price_forward          = 0.0;
    L.exit_spread_target           = 0.0;
    L.exit_target                  = 0.0;
    L.add_next                     = 0.0;
    L.lot_size                     = 0.0;
    L.remaining_entry_volume        = 0.0;
    L.remaining_exit_volume         = 0.0;
    L.entry_ticket                 = 0;
    ArrayResize(L.exit_tickets, 0);
    return L;
}
```

#### Immutability enforcement comment block

Immediately after the struct definition, insert this comment
block verbatim. It is the contract for all future Cursor
prompts:

```mql5
//--- IMMUTABILITY CONTRACT (DO NOT MODIFY IN ANY OTHER FILE) ---
// The following Layer fields are set ONCE at first fill and
// must NEVER be modified by any function outside OnTradeTransaction:
//   entry_price
//   entry_spread_raw
//   entry_time
//   EU_mid_12bars_ago_at_entry
//   GB_mid_12bars_ago_at_entry
//   r_EU_at_entry
//   r_GB_at_entry
//   strongest_at_entry
//   weakest_at_entry
//   entry_price_eurusd
//   entry_price_gbpusd
//   entry_price_eurusd_1h
//   entry_price_gbpusd_1h
//   instrument
//   direction
//
// The following fields are modified ONLY by ADR-003 carry logic:
//   entry_spread_adjusted
//   entry_price_forward
//   exit_spread_target
//   exit_target
//   exit_tickets[] contents (OrderModify targets)
//
// remaining_entry_volume is decremented ONLY by HandleEntryFill().
// remaining_exit_volume is set by HandleEntryFill() when entry complete,
//   then decremented ONLY by HandleExitFill().
// exit_tickets[] array is appended ONLY by OnTradeTransaction.
// exit_tickets[] elements are removed ONLY by OnTradeTransaction.
//----------------------------------------------------------------
```

---

## File 2: Globals.mqh

### EA input parameters

```mql5
//--- Signal parameters
input int    StrengthWindow     = 12;      // M5 bars = 1 hour
input double EntryThreshold     = 0.0008;  // log-return units

//--- Exit parameters
input double ExitFraction       = 0.70;    // fraction of spread reversion to capture
input double MinFillThreshold   = 0.50;    // fraction of lot_size before next layer

//--- Layer mechanics
input int    MaxLayers          = 5;
input double BaseLotSize        = 0.01;
input double AddRatio           = 0.75;    // × H4 ATR for add_next spacing

//--- Nudging
input double NudgePips          = 0.5;     // pips; converted to points per symbol

//--- Risk controls
input double MaxPodDrawdown     = 0.02;    // 2% per pod
input double GlobalDrawdown     = 0.05;    // 5% global equity

//--- Carry adjustment (ADR-003)
input double r_USD              = 0.0533;  // SOFR annualised — update weekly
input double r_EUR              = 0.0390;  // ESTR annualised — update weekly
input double r_GBP              = 0.0520;  // SONIA annualised — update weekly
input string CarryRecalcTime    = "17:00"; // broker server time

//--- Logging
input bool   EnableVerboseLog   = true;
```

### Global signal state variables

```mql5
//--- Signal state (updated on each new M5 bar close)
double   g_r_EU_signal          = 0.0;
double   g_r_GB_signal          = 0.0;
double   g_EU_mid_12bars_ago    = 0.0;   // entry inversion anchor (live)
double   g_GB_mid_12bars_ago    = 0.0;   // entry inversion anchor (live)
int      g_strongest            = -1;    // 0=EUR, 1=GBP, 2=USD
int      g_weakest              = -1;
bool     g_signal_active        = false;
double   g_entry_spread         = 0.0;

//--- Bar tracking
datetime g_last_bar_time        = 0;

//--- Carry recalculation
datetime g_last_carry_recalc_date = 0;

//--- Pod state
bool     g_halted               = false;
double   g_peak_equity          = 0.0;
double   g_NudgeThreshold       = 0.0;   // computed at InitGlobals() from NudgePips

//--- Inventory
Layer    g_inventory[];                  // dynamic array of open layers
```

### InitGlobals() skeleton (globals initialisation only)

```mql5
int InitGlobals() {
    // Compute nudge threshold in points for current symbol
    g_NudgeThreshold = NudgePips
                       * SymbolInfoDouble(_Symbol, SYMBOL_POINT)
                       * 10.0;

    // Record starting equity as peak
    g_peak_equity = AccountInfoDouble(ACCOUNT_EQUITY);

    // Initialise inventory as empty
    ArrayResize(g_inventory, 0);

    // Validate inputs
    if (MaxLayers < 1 || MaxLayers > 10) {
        Print("ERROR: MaxLayers out of range");
        return INIT_PARAMETERS_INCORRECT;
    }
    if (BaseLotSize <= 0) {
        Print("ERROR: BaseLotSize must be positive");
        return INIT_PARAMETERS_INCORRECT;
    }
    if (ExitFraction <= 0 || ExitFraction >= 1.0) {
        Print("ERROR: ExitFraction must be between 0 and 1");
        return INIT_PARAMETERS_INCORRECT;
    }
    if (MinFillThreshold <= 0 || MinFillThreshold > 1.0) {
        Print("ERROR: MinFillThreshold must be between 0 and 1");
        return INIT_PARAMETERS_INCORRECT;
    }

    Print("FXMatrix EA initialised. NudgeThreshold=",
          g_NudgeThreshold, " points");
    return INIT_SUCCEEDED;
}
```

---

## Negative Space — What You Must NOT Do

- Do NOT write OnTick() — that is Prompt 4
- Do NOT write OnTradeTransaction() — that is Prompt 3
- Do NOT write any signal computation logic — that is Prompt 2
- Do NOT write any inversion formulas — that is Prompt 2
- Do NOT write any order placement logic — that is Prompt 3
- Do NOT write any carry recalculation logic — that is Prompt 4
- Do NOT write any circuit breaker logic — that is Prompt 4
- Do NOT add fields to the Layer struct not defined above
- Do NOT define a second Layer struct anywhere
- Do NOT use localStorage, global variables beyond Globals.mqh
- Do NOT include any third-party libraries
- Do NOT use scipy, QuantLib, or any external quant library
- Do NOT write DDL or schema migration logic
- Do NOT use local clock for any timestamp — broker server time only

---

## Self-Review Instructions

Before submitting your response:
1. Re-read every field in the Layer struct against ADR-002 v4
   Section 2. Confirm all 25 fields are present and correctly typed
   (20 original scalars + r_EU_at_entry, r_GB_at_entry,
   strongest_at_entry, weakest_at_entry + dual volume counters
   remaining_entry_volume, remaining_exit_volume replacing
   single remaining_volume).
2. Confirm exit_tickets[] is declared as a dynamic array (not
   a fixed-size array).
3. Confirm the immutability comment block is present verbatim.
4. Confirm Globals.mqh contains all input parameters and all
   global state variables listed above.
5. Confirm InitGlobals() initialises g_NudgeThreshold from NudgePips
   using SYMBOL_POINT × 10.
6. Confirm you have NOT written any logic beyond what is scoped
   to this prompt.
7. Flag any assumptions, ambiguities, or constraint violations
   before proceeding.

---

## Output Format

Respond with:
1. The complete contents of LayerStruct.mqh
2. The complete contents of Globals.mqh
3. A brief self-review confirming each of the 7 checks above
4. Any flagged assumptions or concerns

Do not summarise. Do not explain the strategy. Write the files.

Line count: 198
