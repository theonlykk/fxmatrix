# Cursor Implementation Prompt 2 of 4
# Scope: Signal Computation + Six Inversion Cases
# Reference: ADR-002 v4 Sections 1, 3, 5

This message has a line count at the bottom.
Read this entire prompt before writing a single line of code.
Do not begin implementation until you have read all sections.

---

## Context

You are implementing a native MQL5 Expert Advisor for a
3-currency FX mean-reversion pod (EUR, GBP, USD) on an FTMO
MT5 hedging account. This is Prompt 2 of 4.

Files already locked (do not modify):
- d:\fxmatrix\ea\LayerStruct.mqh
- d:\fxmatrix\ea\Globals.mqh

Full specification:
- d:\fxmatrix\adrs\ADR-002-matrix-driven-exits-v4.md
- d:\fxmatrix\adrs\ADR-003-carry-adjustment-v2.md

If anything in this prompt conflicts with the ADRs, the ADRs
take precedence.

---

## Deliverable

One file: `d:\fxmatrix\ea\MathEngine.mqh`

This file contains:
1. The M5 bar close signal computation (matrix decomposition)
2. The IsPassive() utility function
3. The ComputeEntryPrice() function (six routing cases, entry anchor)
4. The ComputeExitPrice() function (six routing cases, exit anchor)
5. The ComputeExitSpreadTarget() function

No order placement. No OnTick. No OnTradeTransaction.
No carry recalculation. No array management.

---

## Critical Architectural Distinction — Read First

The six inversion cases (ADR-002 v4 Section 5) are used for
TWO distinct purposes with DIFFERENT historical anchors:

**For ENTRY price computation:**
- anchor_EU = g_EU_mid_12bars_ago  (live global, updated each M5 bar)
- anchor_GB = g_GB_mid_12bars_ago  (live global, updated each M5 bar)
- T = g_entry_spread

**For EXIT price computation:**
- anchor_EU = layer.EU_mid_12bars_ago_at_entry  (immutable, from fill)
- anchor_GB = layer.GB_mid_12bars_ago_at_entry  (immutable, from fill)
- T = layer.exit_spread_target

This distinction is the resolution of the F1 anchor drift finding
from the DeepSeek Round 4 audit. It is not optional. Any code
that uses live 12-bar-ago prices for exit computations is wrong.

---

## Section 1 — Signal Computation

### Function: RunSignalOnBarClose()

Called once per new M5 bar. Updates all g_XX globals.
Returns true if signal is active, false otherwise.

```mql5
bool RunSignalOnBarClose() {

    // Step 1: Fetch last 13 M5 closes for EURUSD and GBPUSD
    // (bar 0 = current closed bar, bar StrengthWindow = StrengthWindow bars ago)
    double eu_closes[], gb_closes[];

    // ArraySetAsSeries BEFORE CopyClose — ensures index 0 = most recent
    // close, index 12 = 12 bars ago. Without this, CopyClose fills
    // oldest-first and the log return computation would be inverted.
    ArraySetAsSeries(eu_closes, true);
    ArraySetAsSeries(gb_closes, true);

    if (CopyClose("EURUSD", PERIOD_M5, 0, StrengthWindow+1, eu_closes) < StrengthWindow+1) {
        Print("ERROR: CopyClose EURUSD failed");
        return false;
    }
    if (CopyClose("GBPUSD", PERIOD_M5, 0, StrengthWindow+1, gb_closes) < StrengthWindow+1) {
        Print("ERROR: CopyClose GBPUSD failed");
        return false;
    }
    // index 0 = most recent close, index StrengthWindow = 1 hour ago

    // Step 2: Compute 1-hour log returns (mid approximation from close)
    double eu_now  = eu_closes[0];
    double eu_1h   = eu_closes[StrengthWindow];
    double gb_now  = gb_closes[0];
    double gb_1h   = gb_closes[StrengthWindow];

    if (eu_1h <= 0 || gb_1h <= 0) {
        Print("ERROR: zero/negative close price");
        return false;
    }

    g_r_EU_signal       = MathLog(eu_now / eu_1h);
    g_r_GB_signal       = MathLog(gb_now / gb_1h);
    g_EU_mid_12bars_ago = eu_1h;   // entry inversion anchor (live)
    g_GB_mid_12bars_ago = gb_1h;   // entry inversion anchor (live)

    // Step 3: Matrix solution (3-currency sum-to-zero system)
    double usd = -(g_r_EU_signal + g_r_GB_signal) / 3.0;
    double eur =   g_r_EU_signal + usd;
    double gbp =   g_r_GB_signal + usd;

    // Step 4: Rank currencies
    // Build sortable array: [score, currency_id]
    // EUR=0, GBP=1, USD=2
    double scores[3];
    scores[0] = eur;
    scores[1] = gbp;
    scores[2] = usd;

    // Find strongest and weakest
    int strongest = 0, weakest = 0;
    for (int i = 1; i < 3; i++) {
        if (scores[i] > scores[strongest]) strongest = i;
        if (scores[i] < scores[weakest])   weakest   = i;
    }

    g_strongest = strongest;
    g_weakest   = weakest;

    // Step 5: Spread and entry condition
    double spread = scores[weakest] - scores[strongest]; // always negative
    g_entry_spread = spread;

    if (MathAbs(spread) > EntryThreshold) {
        g_signal_active = true;
        if (EnableVerboseLog)
            Print("Signal active: strongest=", strongest,
                  " weakest=", weakest,
                  " spread=", DoubleToString(spread, 6));
        return true;
    }

    g_signal_active = false;
    return false;
}
```

---

## Section 2 — IsPassive() Utility

```mql5
bool IsPassive(double price, int direction, string symbol) {
    double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(symbol, SYMBOL_BID);

    if (ask <= 0 || bid <= 0) {
        Print("WARNING: IsPassive — zero bid/ask on ", symbol);
        return false;
    }

    if (direction == DIRECTION_SELL) return price > ask;
    if (direction == DIRECTION_BUY)  return price < bid;

    Print("ERROR: IsPassive — invalid direction ", direction);
    return false;
}
```

---

## Section 3 — Exit Spread Target

```mql5
double ComputeExitSpreadTarget(const Layer &layer) {
    // T_exit = entry_spread_adjusted × (1 - ExitFraction)
    // This is the spread level at which we exit —
    // capturing ExitFraction of the original dislocation.
    return layer.entry_spread_adjusted * (1.0 - ExitFraction);
}
```

---

## Section 4 — The Six Inversion Cases

### Design

Both ComputeEntryPrice() and ComputeExitPrice() call the same
internal routing function InvertSpreadToPrice(), which accepts
explicit anchor parameters. This enforces the entry/exit anchor
distinction at the call site.

### Internal routing function

```mql5
// Returns the computed limit price for the given routing case.
// Returns -1.0 on failure (passivity violation or liquidity guard).
//
// anchor_EU: EU_mid 12 bars ago (entry: live global; exit: immutable layer field)
// anchor_GB: GB_mid 12 bars ago (entry: live global; exit: immutable layer field)
// T:         target spread value (entry: g_entry_spread; exit: layer.exit_spread_target)
// strongest: currency index 0=EUR 1=GBP 2=USD
// weakest:   currency index 0=EUR 1=GBP 2=USD

double InvertSpreadToPrice(
    double anchor_EU,
    double anchor_GB,
    double r_EU_fixed,
    double r_GB_fixed,
    double T,
    int    strongest,
    int    weakest
) {
    // Determine instrument and direction from routing table
    string symbol    = "";
    int    direction = 0;
    double price     = -1.0;

    // Fetch live bid/ask for passivity buffer
    double eu_bid = SymbolInfoDouble("EURUSD", SYMBOL_BID);
    double eu_ask = SymbolInfoDouble("EURUSD", SYMBOL_ASK);
    double gb_bid = SymbolInfoDouble("GBPUSD", SYMBOL_BID);
    double gb_ask = SymbolInfoDouble("GBPUSD", SYMBOL_ASK);
    double eg_bid = SymbolInfoDouble("EURGBP", SYMBOL_BID);
    double eg_ask = SymbolInfoDouble("EURGBP", SYMBOL_ASK);

    // EURGBP liquidity guard (M6)
    if (eg_bid <= 0 || eg_ask <= 0) {
        Print("WARNING: EURGBP liquidity guard triggered");
        return -1.0;
    }

    double eu_half_spread = (eu_ask - eu_bid) / 2.0;
    double gb_half_spread = (gb_ask - gb_bid) / 2.0;
    double eg_half_spread = (eg_ask - eg_bid) / 2.0;

    // --- Case 1: S=EUR(0), W=GBP(1) → Sell EURGBP ---
    if (strongest == 0 && weakest == 1) {
        symbol    = "EURGBP";
        direction = DIRECTION_SELL;
        double EG_history = anchor_EU / anchor_GB;
        double EG_target  = EG_history * MathExp(-T);
        price = EG_target + eg_half_spread;
    }

    // --- Case 2: S=GBP(1), W=EUR(0) → Buy EURGBP ---
    else if (strongest == 1 && weakest == 0) {
        symbol    = "EURGBP";
        direction = DIRECTION_BUY;
        double EG_history = anchor_EU / anchor_GB;
        double EG_target  = EG_history * MathExp(-T);
        price = EG_target - eg_half_spread;
    }

    // --- Case 3: S=EUR(0), W=USD(2) → Sell EURUSD ---
    else if (strongest == 0 && weakest == 2) {
        symbol    = "EURUSD";
        direction = DIRECTION_SELL;
        double r_EU_target   = r_GB_fixed - T;  // fixed leg from parameter
        double EU_target_mid = anchor_EU * MathExp(r_EU_target);
        price = EU_target_mid + eu_half_spread;
    }

    // --- Case 4: S=USD(2), W=EUR(0) → Buy EURUSD ---
    else if (strongest == 2 && weakest == 0) {
        symbol    = "EURUSD";
        direction = DIRECTION_BUY;
        double r_EU_target   = r_GB_fixed - T;  // fixed leg from parameter
        double EU_target_mid = anchor_EU * MathExp(r_EU_target);
        price = EU_target_mid - eu_half_spread;
    }

    // --- Case 5: S=GBP(1), W=USD(2) → Sell GBPUSD ---
    else if (strongest == 1 && weakest == 2) {
        symbol    = "GBPUSD";
        direction = DIRECTION_SELL;
        double r_GB_target   = r_EU_fixed + T;  // fixed leg from parameter
        double GB_target_mid = anchor_GB * MathExp(r_GB_target);
        price = GB_target_mid + gb_half_spread;
    }

    // --- Case 6: S=USD(2), W=GBP(1) → Buy GBPUSD ---
    else if (strongest == 2 && weakest == 1) {
        symbol    = "GBPUSD";
        direction = DIRECTION_BUY;
        double r_GB_target   = r_EU_fixed + T;  // fixed leg from parameter
        double GB_target_mid = anchor_GB * MathExp(r_GB_target);
        price = GB_target_mid - gb_half_spread;
    }

    else {
        Print("ERROR: InvertSpreadToPrice — invalid routing: ",
              "strongest=", strongest, " weakest=", weakest);
        return -1.0;
    }

    // Passivity check — skip and log on failure (Option B)
    if (!IsPassive(price, direction, symbol)) {
        Print("INFO: Passivity failure — order skipped. ",
              "symbol=", symbol,
              " direction=", direction,
              " price=", DoubleToString(price, 5),
              " T=", DoubleToString(T, 6));
        return -1.0;
    }

    return price;
}
```

### Entry price (uses live anchor)

```mql5
// Returns computed entry limit price, or -1.0 on failure.
double ComputeEntryPrice() {
    return InvertSpreadToPrice(
        g_EU_mid_12bars_ago,   // live anchor — updated each M5 bar
        g_GB_mid_12bars_ago,   // live anchor — updated each M5 bar
        g_r_EU_signal,         // fixed leg — M5 close value
        g_r_GB_signal,         // fixed leg — M5 close value
        g_entry_spread,
        g_strongest,
        g_weakest
    );
}
```

### Exit price (uses entry-time immutable anchor)

```mql5
// Returns computed exit limit price, or -1.0 on failure.
// Uses the immutable entry-time anchor from the Layer struct.
double ComputeExitPrice(const Layer &layer) {
    return InvertSpreadToPrice(
        layer.EU_mid_12bars_ago_at_entry,  // immutable — set at fill
        layer.GB_mid_12bars_ago_at_entry,  // immutable — set at fill
        layer.r_EU_at_entry,               // immutable fixed leg — set at fill
        layer.r_GB_at_entry,               // immutable fixed leg — set at fill
        layer.exit_spread_target,
        layer.strongest_at_entry,          // immutable routing — set at fill
        layer.weakest_at_entry             // immutable routing — set at fill
    );
}
```

---

## Section 5 — Freeze Level Utility

Used by both entry placement (Prompt 3) and carry recalculation
(Prompt 4). Defined here so all math is in one file.

```mql5
// Returns true if the order placement is safe (outside freeze zone).
// Returns false if too close — caller must skip and retain.
bool IsClearOfFreezeLevel(double price, int direction, string symbol) {
    long   freeze_pts   = SymbolInfoInteger(symbol, SYMBOL_FREEZE_LEVEL);
    double freeze_price = freeze_pts
                          * SymbolInfoDouble(symbol, SYMBOL_POINT);

    double ask      = SymbolInfoDouble(symbol, SYMBOL_ASK);
    double bid      = SymbolInfoDouble(symbol, SYMBOL_BID);
    double distance = 0.0;

    if (direction == DIRECTION_SELL) distance = price - ask;
    else                             distance = bid - price;

    if (distance <= freeze_price) {
        if (EnableVerboseLog)
            Print("INFO: Freeze level skip — symbol=", symbol,
                  " distance=", DoubleToString(distance, 5),
                  " freeze=", DoubleToString(freeze_price, 5));
        return false;
    }
    return true;
}
```

---

## Negative Space — What You Must NOT Do

- Do NOT write OnTick() — Prompt 4
- Do NOT write OnTradeTransaction() — Prompt 3
- Do NOT write order placement logic — Prompt 3
- Do NOT write carry recalculation — Prompt 4
- Do NOT write circuit breaker logic — Prompt 4
- Do NOT modify LayerStruct.mqh or Globals.mqh
- Do NOT use live 12-bar-ago prices for exit computations —
  exit computations MUST use layer.EU_mid_12bars_ago_at_entry
  and layer.GB_mid_12bars_ago_at_entry
- Do NOT implement volatility-scaled threshold — V2
- Do NOT implement multi-timeframe confluence — V2
- Do NOT use any external quant libraries
- Do NOT use local clock for timestamps
- Do NOT define a second Layer struct or duplicate globals

---

## Self-Review Instructions

Before submitting your response:
1. Confirm RunSignalOnBarClose() updates all six g_XX globals:
   g_r_EU_signal, g_r_GB_signal, g_EU_mid_12bars_ago,
   g_GB_mid_12bars_ago, g_strongest, g_weakest, g_entry_spread,
   g_signal_active.
2. Confirm InvertSpreadToPrice() accepts explicit anchor_EU and
   anchor_GB parameters — it does NOT read g_EU_mid_12bars_ago
   directly.
3. Confirm ComputeEntryPrice() passes g_EU_mid_12bars_ago and
   g_GB_mid_12bars_ago as anchors.
4. Confirm ComputeExitPrice() passes layer.EU_mid_12bars_ago_at_entry
   and layer.GB_mid_12bars_ago_at_entry as anchors.
5. Confirm all six routing cases are present and the sign of
   the half-spread offset is correct:
   - Sell limits: + half_spread (moves above Ask)
   - Buy limits:  - half_spread (moves below Bid)
6. Confirm IsPassive() is called on the computed price for all
   six cases before returning.
7. Confirm IsClearOfFreezeLevel() is defined and uses Ask
   for sell limits and Bid for buy limits.
8. Flag any assumptions, ambiguities, or constraint violations.

---

## Output Format

Respond with:
1. Complete contents of MathEngine.mqh
2. Self-review confirming each of the 8 checks above
3. Any flagged assumptions or concerns

Do not summarise. Do not explain the strategy. Write the file.

Line count: 244
