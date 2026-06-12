#ifndef MATH_ENGINE_MQH
#define MATH_ENGINE_MQH

#include "Globals.mqh"

bool RunSignalOnBarClose() {
    double eu_closes[], gb_closes[];

    ArraySetAsSeries(eu_closes, true);
    ArraySetAsSeries(gb_closes, true);

    if (CopyClose("EURUSD", PERIOD_M5, 0, 13, eu_closes) < 13) {
        Print("ERROR: CopyClose EURUSD failed");
        return false;
    }
    if (CopyClose("GBPUSD", PERIOD_M5, 0, 13, gb_closes) < 13) {
        Print("ERROR: CopyClose GBPUSD failed");
        return false;
    }

    double eu_ask_live = SymbolInfoDouble("EURUSD", SYMBOL_ASK);
    double eu_bid_live = SymbolInfoDouble("EURUSD", SYMBOL_BID);
    double gb_ask_live = SymbolInfoDouble("GBPUSD", SYMBOL_ASK);
    double gb_bid_live = SymbolInfoDouble("GBPUSD", SYMBOL_BID);

    double eu_half = (eu_ask_live - eu_bid_live) / 2.0;
    double gb_half = (gb_ask_live - gb_bid_live) / 2.0;

    double eu_now = eu_closes[0]  + eu_half;  // bid close → mid
    double eu_1h  = eu_closes[12] + eu_half;  // bid close → mid
    double gb_now = gb_closes[0]  + gb_half;  // bid close → mid
    double gb_1h  = gb_closes[12] + gb_half;  // bid close → mid

    if (eu_1h <= 0 || gb_1h <= 0) {
        Print("ERROR: zero/negative close price");
        return false;
    }

    g_r_EU_signal       = MathLog(eu_now / eu_1h);
    g_r_GB_signal       = MathLog(gb_now / gb_1h);
    g_EU_mid_12bars_ago = eu_1h;
    g_GB_mid_12bars_ago = gb_1h;

    double usd = -(g_r_EU_signal + g_r_GB_signal) / 3.0;
    double eur =   g_r_EU_signal + usd;
    double gbp =   g_r_GB_signal + usd;

    double scores[3];
    scores[0] = eur;
    scores[1] = gbp;
    scores[2] = usd;

    g_score_eur = eur;
    g_score_gbp = gbp;
    g_score_usd = usd;

    int strongest = 0, weakest = 0;
    for (int i = 1; i < 3; i++) {
        if (scores[i] > scores[strongest]) strongest = i;
        if (scores[i] < scores[weakest])   weakest   = i;
    }

    g_strongest = strongest;
    g_weakest   = weakest;

    double spread = scores[weakest] - scores[strongest];
    g_entry_spread = spread;

    if (MathAbs(spread) > BaseThreshold) {
        g_signal_active = true;
    } else {
        g_signal_active = false;
    }

    if (EnableVerboseLog) {
        if (g_signal_active) {
            string inst = ((g_strongest == 0 && g_weakest == 1) ||
                           (g_strongest == 1 && g_weakest == 0)) ? "EURGBP" :
                          ((g_strongest == 0 && g_weakest == 2) ||
                           (g_strongest == 2 && g_weakest == 0)) ? "EURUSD" :
                          "GBPUSD";
            string dir  = ((g_strongest == 0 && g_weakest == 1) ||
                           (g_strongest == 0 && g_weakest == 2) ||
                           (g_strongest == 1 && g_weakest == 2))
                          ? "SELL" : "BUY";
            Print("INFO: Signal active: spread=",
                  DoubleToString(g_entry_spread, 6),
                  " threshold=", DoubleToString(BaseThreshold, 6),
                  " strongest=", g_strongest,
                  " weakest=", g_weakest,
                  " -> ", inst, " ", dir);
        } else {
            Print("INFO: No signal: spread=",
                  DoubleToString(g_entry_spread, 6),
                  " threshold=", DoubleToString(BaseThreshold, 6));
        }
    }

    return g_signal_active;
}

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

double ComputeExitSpreadTarget(const Layer &layer) {
    // V2 Phase 1: uses ComputeSkew(0) as safe approximation.
    // layer_index not yet in LayerStruct (Phase 2 addition).
    // When SkewStep=0 (default), ComputeSkew(0) == ComputeSkew(N)
    // for all N, so this is mathematically identical to Phase 0.
    // Phase 2 one-line patch: replace 0 with layer.layer_index.
    return layer.entry_spread_adjusted + GridBase * ComputeSkew(layer.layer_index);
}

double InvertSpreadToPrice(
    double anchor_EU,
    double anchor_GB,
    double r_EU_fixed,
    double r_GB_fixed,
    double T,
    int    strongest,
    int    weakest,
    bool   is_exit,
    bool   enforce_passivity = true
) {
    string symbol    = "";
    int    direction = 0;
    double price     = -1.0;

    double eu_bid = SymbolInfoDouble("EURUSD", SYMBOL_BID);
    double eu_ask = SymbolInfoDouble("EURUSD", SYMBOL_ASK);
    double gb_bid = SymbolInfoDouble("GBPUSD", SYMBOL_BID);
    double gb_ask = SymbolInfoDouble("GBPUSD", SYMBOL_ASK);
    double eg_bid = SymbolInfoDouble("EURGBP", SYMBOL_BID);
    double eg_ask = SymbolInfoDouble("EURGBP", SYMBOL_ASK);

    if (eg_bid <= 0 || eg_ask <= 0) {
        Print("WARNING: EURGBP liquidity guard triggered");
        return -1.0;
    }

    double eu_half_spread = (eu_ask - eu_bid) / 2.0;
    double gb_half_spread = (gb_ask - gb_bid) / 2.0;
    double eg_half_spread = (eg_ask - eg_bid) / 2.0;

    if (strongest == 0 && weakest == 1) {
        symbol    = "EURGBP";
        direction = DIRECTION_SELL;
        double EG_history = anchor_EU / anchor_GB;
        double EG_target  = EG_history * MathExp(-T); // SELL: unchanged
        price = EG_target;
    }
    else if (strongest == 1 && weakest == 0) {
        symbol    = "EURGBP";
        direction = DIRECTION_BUY;
        double EG_history = anchor_EU / anchor_GB;
        double EG_target  = EG_history * MathExp(T);  // BUY: fixed T not -T
        price = EG_target;
    }
    else if (strongest == 0 && weakest == 2) {
        symbol    = "EURUSD";
        direction = DIRECTION_SELL;
        double r_EU_target   = -T;  // T = usd-eur = -r_EU, so -T = r_EU
        double EU_target_mid = anchor_EU * MathExp(r_EU_target);
        price = EU_target_mid;
    }
    else if (strongest == 2 && weakest == 0) {
        symbol    = "EURUSD";
        direction = DIRECTION_BUY;
        double r_EU_target   = T;   // T = eur-usd = r_EU (negative for BUY)
        double EU_target_mid = anchor_EU * MathExp(r_EU_target);
        price = EU_target_mid;
    }
    else if (strongest == 1 && weakest == 2) {
        symbol    = "GBPUSD";
        direction = DIRECTION_SELL;
        double r_GB_target   = -T;  // T = usd-gbp = -r_GB, so -T = r_GB
        double GB_target_mid = anchor_GB * MathExp(r_GB_target);
        price = GB_target_mid;
    }
    else if (strongest == 2 && weakest == 1) {
        symbol    = "GBPUSD";
        direction = DIRECTION_BUY;
        double r_GB_target   = T;   // T = gbp-usd = r_GB (negative for BUY)
        double GB_target_mid = anchor_GB * MathExp(r_GB_target);
        price = GB_target_mid;
    }
    else {
        Print("ERROR: InvertSpreadToPrice — invalid routing: ",
              "strongest=", strongest, " weakest=", weakest);
        return -1.0;
    }

    if (is_exit) {
        direction = (direction == DIRECTION_BUY)
                    ? DIRECTION_SELL : DIRECTION_BUY;
    }

    double half_spread = 0.0;
    if      (symbol == "EURGBP") half_spread = eg_half_spread;
    else if (symbol == "EURUSD") half_spread = eu_half_spread;
    else                         half_spread = gb_half_spread;

    if (direction == DIRECTION_SELL)
        price = price + half_spread;
    else
        price = price - half_spread;

    if (enforce_passivity && !IsPassive(price, direction, symbol)) {
        Print("INFO: Passivity failure — order skipped. ",
              "symbol=", symbol,
              " direction=", direction,
              " price=", DoubleToString(price, 5),
              " T=", DoubleToString(T, 6));
        return -1.0;
    }

    return price;
}

//------------------------------------------------------------------
// ComputeGridInterval
// Returns the grid spacing S for a given layer index.
// GridMode 0: constant S = GridBase
// GridMode 1: linear S = GridBase + layer_idx * GridLinearStep
// GridMode 2: hybrid — linear up to GridInflection, then exponential
//------------------------------------------------------------------
double ComputeGridInterval(int layer_idx) {
    if (GridMode == 0) {
        return GridBase;
    }
    else if (GridMode == 1) {
        return GridBase + layer_idx * GridLinearStep;
    }
    else { // GridMode == 2: hybrid
        if (layer_idx <= GridInflection) {
            return GridBase + layer_idx * GridLinearStep;
        }
        else {
            double S_at_inflection = GridBase + GridInflection * GridLinearStep;
            return S_at_inflection * MathPow(GridExpBase,
                                             layer_idx - GridInflection);
        }
    }
}

//------------------------------------------------------------------
// ComputeSkew
// Returns the exit capture fraction for a given layer index.
// SkewMode 0: constant skew = SkewStart
// SkewMode 1: linear decrease floored at SkewMin
//------------------------------------------------------------------
double ComputeSkew(int layer_idx) {
    if (SkewMode == 0) {
        return SkewStart;
    }
    else {
        return MathMax(SkewStart - layer_idx * SkewStep, SkewMin);
    }
}

double ComputeEntryPrice() {
    return InvertSpreadToPrice(
        g_EU_mid_12bars_ago,
        g_GB_mid_12bars_ago,
        g_r_EU_signal,
        g_r_GB_signal,
        g_entry_spread,
        g_strongest,
        g_weakest,
        false
    );
}

double ComputeExitPrice(const Layer &layer) {
    return InvertSpreadToPrice(
        layer.EU_mid_12bars_ago_at_entry,
        layer.GB_mid_12bars_ago_at_entry,
        layer.r_EU_at_entry,
        layer.r_GB_at_entry,
        layer.exit_spread_target,
        layer.strongest_at_entry,
        layer.weakest_at_entry,
        true
    );
}

bool IsClearOfFreezeLevel(double price, int direction, string symbol) {
    long    freeze_pts    = SymbolInfoInteger(symbol, SYMBOL_TRADE_FREEZE_LEVEL);
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

#endif // MATH_ENGINE_MQH
