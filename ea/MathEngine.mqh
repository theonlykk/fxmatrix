#ifndef MATH_ENGINE_MQH
#define MATH_ENGINE_MQH

#include "Globals.mqh"

// Forward declaration — GetPodUnrealizedPnL() is defined in FXMatrix.mq5
// Required for Phase 3 stress multiplier in ComputeGridInterval()
double GetPodUnrealizedPnL(int instrument);

//------------------------------------------------------------------
// StdDev
// Returns population standard deviation of log-return array
// of length n. Returns 0.0 if degenerate.
//------------------------------------------------------------------
double StdDev(const double &a[], int n) {
    if (n < 2) return 0.0;

    double sum = 0.0;
    for (int i = 0; i < n; i++) sum += a[i];
    double mean = sum / n;

    double var = 0.0;
    for (int i = 0; i < n; i++) {
        double d = a[i] - mean;
        var += d * d;
    }
    return MathSqrt(var / n);
}

//------------------------------------------------------------------
// PearsonR
// Returns signed Pearson correlation coefficient r for two
// log-return arrays of length n. Returns 0.0 if degenerate.
//------------------------------------------------------------------
double PearsonR(const double &a[], const double &b[], int n) {
    if (n < 3) return 0.0;

    double sum_a = 0, sum_b = 0;
    for (int i = 0; i < n; i++) { sum_a += a[i]; sum_b += b[i]; }
    double mean_a = sum_a / n;
    double mean_b = sum_b / n;

    double cov = 0, var_a = 0, var_b = 0;
    for (int i = 0; i < n; i++) {
        double da = a[i] - mean_a;
        double db = b[i] - mean_b;
        cov   += da * db;
        var_a += da * da;
        var_b += db * db;
    }

    if (var_a < 1e-12 || var_b < 1e-12) return 0.0;
    return cov / MathSqrt(var_a * var_b);
}

//------------------------------------------------------------------
// MathMedianCentered
// Returns the median of a window of `width` elements centred on
// `center_index` in a series-ordered array (index 0 = most recent).
// Includes strict bounds checking to prevent ArrayOutOfRange fatal crashes.
// Gracefully degrades to single-bar arr[center_index] if window exceeds
// array bounds (e.g. StrengthWindow misconfiguration or insufficient history).
//------------------------------------------------------------------
double MathMedianCentered(const double &arr[], int center_index, int width) {
    if (width <= 0) return arr[center_index];

    int half  = width / 2;
    int count = 2 * half + 1;  // enforce odd window

    // DEFENSIVE GUARD: degrade to single close rather than crash EA
    if (center_index - half < 0 || center_index + half >= ArraySize(arr))
        return arr[center_index];

    double temp[];
    ArrayResize(temp, count);
    for (int i = 0; i < count; i++)
        temp[i] = arr[center_index - half + i];

    ArraySort(temp);
    return temp[half];
}

//------------------------------------------------------------------
// ComputeTermStructure
// ADR-052 Step A: Multi-timeframe fair value and dispersion.
// Computes FV_combined (weighted average of 3 anchor prices) and
// sigma_FV (dispersion across anchors, in points) for SLOT_AC and
// SLOT_BC using the close arrays already loaded by RunSignalOnBarClose.
// LOGGING ONLY — no globals mutated, no execution impact.
// Called from RunSignalOnBarClose() after close arrays are populated.
//------------------------------------------------------------------
void ComputeTermStructure(const double &ac_closes[],
                          const double &bc_closes[]) {
    // ── SLOT_AC (EURUSD) ─────────────────────────────────────────
    double ac_fv6  = ac_closes[6];
    double ac_fv12 = ac_closes[12];
    double ac_fv48 = ac_closes[48];

    double ac_fv_combined = ac_fv6 * 0.50 + ac_fv12 * 0.30 + ac_fv48 * 0.20;

    double ac_mean  = (ac_fv6 + ac_fv12 + ac_fv48) / 3.0;
    double ac_sigma = MathSqrt(
        ((ac_fv6 - ac_mean) * (ac_fv6 - ac_mean) +
         (ac_fv12 - ac_mean) * (ac_fv12 - ac_mean) +
         (ac_fv48 - ac_mean) * (ac_fv48 - ac_mean)) / 3.0
    );
    double ac_point        = SymbolInfoDouble(g_symbols[SLOT_AC], SYMBOL_POINT);
    double ac_sigma_points = (ac_point > 0) ? ac_sigma / ac_point : 0.0;

    // ── SLOT_BC (GBPUSD) ─────────────────────────────────────────
    double bc_fv6  = bc_closes[6];
    double bc_fv12 = bc_closes[12];
    double bc_fv48 = bc_closes[48];

    double bc_fv_combined = bc_fv6 * 0.50 + bc_fv12 * 0.30 + bc_fv48 * 0.20;

    double bc_mean  = (bc_fv6 + bc_fv12 + bc_fv48) / 3.0;
    double bc_sigma = MathSqrt(
        ((bc_fv6 - bc_mean) * (bc_fv6 - bc_mean) +
         (bc_fv12 - bc_mean) * (bc_fv12 - bc_mean) +
         (bc_fv48 - bc_mean) * (bc_fv48 - bc_mean)) / 3.0
    );
    double bc_point        = SymbolInfoDouble(g_symbols[SLOT_BC], SYMBOL_POINT);
    double bc_sigma_points = (bc_point > 0) ? bc_sigma / bc_point : 0.0;

    // Write to globals for downstream consumption (Step B wiring)
    g_fv_combined[0]  = ac_fv_combined;
    g_fv_combined[1]  = bc_fv_combined;
    g_sigma_fv[0]     = ac_sigma;
    g_sigma_fv[1]     = bc_sigma;
    g_sigma_fv_pts[0] = ac_sigma_points;
    g_sigma_fv_pts[1] = bc_sigma_points;

    // ── Logging ───────────────────────────────────────────────────
    if (EnableVerboseLog) {
        Print("DIAG [ADR-052] AC term structure:",
              " FV6=",  DoubleToString(ac_fv6, 5),
              " FV12=", DoubleToString(ac_fv12, 5),
              " FV48=", DoubleToString(ac_fv48, 5),
              " FV_combined=", DoubleToString(ac_fv_combined, 5),
              " sigma_pts=", DoubleToString(ac_sigma_points, 2));
        Print("DIAG [ADR-052] BC term structure:",
              " FV6=",  DoubleToString(bc_fv6, 5),
              " FV12=", DoubleToString(bc_fv12, 5),
              " FV48=", DoubleToString(bc_fv48, 5),
              " FV_combined=", DoubleToString(bc_fv_combined, 5),
              " sigma_pts=", DoubleToString(bc_sigma_points, 2));
    }
}

bool RunSignalOnBarClose() {
    double ac_closes[], bc_closes[];

    int min_bars = MathMax(289, StrengthWindow + 25);
    if (CopyClose(g_symbols[SLOT_AC], PERIOD_M5, 0, min_bars, ac_closes) < min_bars) {
        Print("ERROR: CopyClose ", g_symbols[SLOT_AC], " failed");
        return false;
    }
    ArraySetAsSeries(ac_closes, true);
    min_bars = MathMax(289, StrengthWindow + 25);
    if (CopyClose(g_symbols[SLOT_BC], PERIOD_M5, 0, min_bars, bc_closes) < min_bars) {
        Print("ERROR: CopyClose ", g_symbols[SLOT_BC], " failed");
        return false;
    }
    ArraySetAsSeries(bc_closes, true);

    if (EnableVerboseLog) Print("DIAG Signal: ac_close_0=", DoubleToString(ac_closes[0], 5),
          " ac_close_12=", DoubleToString(ac_closes[12], 5),
          " bc_close_0=", DoubleToString(bc_closes[0], 5),
          " bc_close_12=", DoubleToString(bc_closes[12], 5));

    double ac_ask_live = SymbolInfoDouble(g_symbols[SLOT_AC], SYMBOL_ASK);
    double ac_bid_live = SymbolInfoDouble(g_symbols[SLOT_AC], SYMBOL_BID);
    double bc_ask_live = SymbolInfoDouble(g_symbols[SLOT_BC], SYMBOL_ASK);
    double bc_bid_live = SymbolInfoDouble(g_symbols[SLOT_BC], SYMBOL_BID);

    double ac_half = (ac_ask_live - ac_bid_live) / 2.0;
    double bc_half = (bc_ask_live - bc_bid_live) / 2.0;

    double ac_now = ac_closes[0]                                    + ac_half;
    double ac_1h  = MathMedianCentered(ac_closes, StrengthWindow, 5) + ac_half;
    double bc_now = bc_closes[0]                                    + bc_half;
    double bc_1h  = MathMedianCentered(bc_closes, StrengthWindow, 5) + bc_half;

    if (ac_1h <= 0 || bc_1h <= 0) {
        Print("ERROR: zero/negative close price");
        return false;
    }

    // ── LDAK: pairwise correlation update ────────────────────────
    // LDAK: slot ordering BINDING — [SLOT_AC, SLOT_BC, SLOT_AB]
    // g_corr[0]=corr(AC,BC), g_corr[1]=corr(AC,AB), g_corr[2]=corr(BC,AB)
    double ab_closes[];
    ArraySetAsSeries(ab_closes, true);
    min_bars = MathMax(289, StrengthWindow + 25);
    if (CopyClose(g_symbols[SLOT_AB], PERIOD_M5, 0, min_bars, ab_closes) >= min_bars) {
        // 24-bar log returns per slot
        double r_slot0[24], r_slot1[24], r_slot2[24];
        for (int i = 0; i < 24; i++) {
            r_slot0[i] = (ac_closes[i+1] > 0) ? MathLog(ac_closes[i] / ac_closes[i+1]) : 0.0;
            r_slot1[i] = (bc_closes[i+1] > 0) ? MathLog(bc_closes[i] / bc_closes[i+1]) : 0.0;
            r_slot2[i] = (ab_closes[i+1] > 0) ? MathLog(ab_closes[i] / ab_closes[i+1]) : 0.0;
        }
        // g_corr indices match slot ordering [AC, BC, AB]
        g_corr[0] = PearsonR(r_slot0, r_slot1, 24);  // corr(AC, BC)
        g_corr[1] = PearsonR(r_slot0, r_slot2, 24);  // corr(AC, AB)
        g_corr[2] = PearsonR(r_slot1, r_slot2, 24);  // corr(BC, AB)

        if (EnableVerboseLog)
            Print("INFO: LDAK r — [AC/BC]=", DoubleToString(g_corr[0], 4),
                  " [AC/AB]=", DoubleToString(g_corr[1], 4),
                  " [BC/AB]=", DoubleToString(g_corr[2], 4));

        // 288-bar slow window
        double r_slot0_slow[288], r_slot1_slow[288], r_slot2_slow[288];
        for (int i = 0; i < 288; i++) {
            r_slot0_slow[i] = (ac_closes[i+1] > 0) ? MathLog(ac_closes[i] / ac_closes[i+1]) : 0.0;
            r_slot1_slow[i] = (bc_closes[i+1] > 0) ? MathLog(bc_closes[i] / bc_closes[i+1]) : 0.0;
            r_slot2_slow[i] = (ab_closes[i+1] > 0) ? MathLog(ab_closes[i] / ab_closes[i+1]) : 0.0;
        }

        double sd0_fast = StdDev(r_slot0, 24);
        double sd1_fast = StdDev(r_slot1, 24);
        double sd2_fast = StdDev(r_slot2, 24);

        double sd0_slow = StdDev(r_slot0_slow, 288);
        double sd1_slow = StdDev(r_slot1_slow, 288);
        double sd2_slow = StdDev(r_slot2_slow, 288);

        g_vratio[0] = (sd0_slow > 1e-12) ? sd0_fast / sd0_slow : 1.0;  // PairAC
        g_vratio[1] = (sd1_slow > 1e-12) ? sd1_fast / sd1_slow : 1.0;  // PairBC
        g_vratio[2] = (sd2_slow > 1e-12) ? sd2_fast / sd2_slow : 1.0;  // PairAB

        if (EnableVerboseLog)
            Print("INFO: LDAK V_ratio — [AC]=", DoubleToString(g_vratio[0], 3),
                  " [BC]=", DoubleToString(g_vratio[1], 3),
                  " [AB]=", DoubleToString(g_vratio[2], 3));
    }
    // ── End LDAK ─────────────────────────────────────────────────

    // ── ADR-046: Viscous cooldown LDAK update ────────────────────
    // Compute live dilation per slot and update high-water mark.
    // Instant dilation on shock; viscous decay toward 1.0 on calm.
    for (int slot = 0; slot < 3; slot++) {
        double S_eff_slot = 0.0;
        for (int j = 0; j < 3; j++) {
            if (j == slot) continue;
            int lo = MathMin(slot, j);
            int hi = MathMax(slot, j);
            int ci = (lo == 0 && hi == 1) ? 0
                   : (lo == 0 && hi == 2) ? 1 : 2;
            double v_eff = MathMax(g_vratio[slot], g_vratio[j]);
            double S     = MathMax(g_corr[ci], 0.0) * MathMax(v_eff - 1.0, 0.0);
            S_eff_slot   = MathMax(S_eff_slot, S);
        }
        double live_dilation = MathMin(1.0 + S_eff_slot * S_eff_slot, LDAK_Dilation_Max);

        if (live_dilation > g_cooldown_LDAK[slot]) {
            // Instant snap to new high-water mark
            g_cooldown_LDAK[slot] = live_dilation;
        } else {
            // Viscous decay — floor at 1.0
            g_cooldown_LDAK[slot] = MathMax(1.0,
                g_cooldown_LDAK[slot] * (1.0 - CooldownDecayRate));
        }
    }
    if (EnableVerboseLog)
        Print("DIAG [ADR-046] cooldown_LDAK=[",
              DoubleToString(g_cooldown_LDAK[0], 4), ",",
              DoubleToString(g_cooldown_LDAK[1], 4), ",",
              DoubleToString(g_cooldown_LDAK[2], 4), "]");
    // ── End ADR-046 cooldown update ──────────────────────────────

    // ── ADR-052: Compute term structure before anchor assignment ──
    ComputeTermStructure(ac_closes, bc_closes);
    // ── End ADR-052 term structure ────────────────────────────────

    // ADR-052 Step B: Use blended multi-timeframe anchor instead of single StrengthWindow bar.
    // g_fv_combined[] populated by ComputeTermStructure() above.
    g_r_signal[0] = MathLog(ac_now / g_fv_combined[0]);  // r_AC vs blended anchor
    g_r_signal[1] = MathLog(bc_now / g_fv_combined[1]);  // r_BC vs blended anchor
    g_anchor[0]   = g_fv_combined[0];                     // blended AC anchor
    g_anchor[1]   = g_fv_combined[1];                     // blended BC anchor

    // V3 generic score decomposition — zero-sum constraint
    // scores[2] = score_C (base currency), scores[0] = score_A, scores[1] = score_B
    double score_C = -(g_r_signal[0] + g_r_signal[1]) / 3.0;
    double score_A =   g_r_signal[0] + score_C;
    double score_B =   g_r_signal[1] + score_C;

    g_scores[0] = score_A;
    g_scores[1] = score_B;
    g_scores[2] = score_C;

    if (EnableVerboseLog) Print("DIAG Signal: anchor_A=", DoubleToString(g_anchor[0], 5),
          " anchor_B=", DoubleToString(g_anchor[1], 5));
    if (EnableVerboseLog) Print("DIAG Signal: scores=[",
          DoubleToString(g_scores[0], 6), ",",
          DoubleToString(g_scores[1], 6), ",",
          DoubleToString(g_scores[2], 6), "]");
    if (EnableVerboseLog) Print("DIAG Signal: r_signal=[",
          DoubleToString(g_r_signal[0], 6), ",",
          DoubleToString(g_r_signal[1], 6), "]");
    if (EnableVerboseLog) Print("DIAG Signal: inst_spread AC=",
          DoubleToString(g_scores[0] - g_scores[2], 6),
          " BC=", DoubleToString(g_scores[1] - g_scores[2], 6),
          " AB=", DoubleToString(g_scores[0] - g_scores[1], 6));

    int strongest = 0, weakest = 0;
    for (int i = 1; i < 3; i++) {
        if (g_scores[i] > g_scores[strongest]) strongest = i;
        if (g_scores[i] < g_scores[weakest])   weakest   = i;
    }

    g_strongest = strongest;
    g_weakest   = weakest;

    double spread = g_scores[weakest] - g_scores[strongest];
    g_entry_spread = spread;

    if (MathAbs(spread) > BaseThreshold) {
        g_signal_active = true;
    } else {
        g_signal_active = false;
    }

    if (EnableVerboseLog) {
        if (g_signal_active) {
            string inst = ((g_strongest == 0 && g_weakest == 1) ||
                           (g_strongest == 1 && g_weakest == 0))
                          ? g_symbols[SLOT_AB] :
                          ((g_strongest == 0 && g_weakest == 2) ||
                           (g_strongest == 2 && g_weakest == 0))
                          ? g_symbols[SLOT_AC] :
                          g_symbols[SLOT_BC];
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

double InvertSpreadToPrice(
    double anchor_A,
    double anchor_B,
    double r_AC_fixed,
    double r_BC_fixed,
    double T,
    int    strongest,
    int    weakest,
    bool   is_exit,
    bool   enforce_passivity = true
) {
    if (is_exit) T = -T;   // ADR-034: invert spread sign before routing
    string symbol    = "";
    int    direction = 0;
    double price     = -1.0;

    double ac_bid = SymbolInfoDouble(g_symbols[SLOT_AC], SYMBOL_BID);
    double ac_ask = SymbolInfoDouble(g_symbols[SLOT_AC], SYMBOL_ASK);
    double bc_bid = SymbolInfoDouble(g_symbols[SLOT_BC], SYMBOL_BID);
    double bc_ask = SymbolInfoDouble(g_symbols[SLOT_BC], SYMBOL_ASK);
    double ab_bid = SymbolInfoDouble(g_symbols[SLOT_AB], SYMBOL_BID);
    double ab_ask = SymbolInfoDouble(g_symbols[SLOT_AB], SYMBOL_ASK);

    if (ab_bid <= 0 || ab_ask <= 0) {
        Print("WARNING: ", g_symbols[SLOT_AB], " liquidity guard triggered");
        if (EnableVerboseLog) Print("DIAG Invert: LIQUIDITY GUARD fired symbol=", g_symbols[SLOT_AB]);
        return -1.0;
    }

    double ac_half_spread = (ac_ask - ac_bid) / 2.0;
    double bc_half_spread = (bc_ask - bc_bid) / 2.0;
    double ab_half_spread = (ab_ask - ab_bid) / 2.0;

    if (EnableVerboseLog) Print("DIAG Invert: T=", DoubleToString(T, 6),
          " strongest=", strongest, " weakest=", weakest,
          " is_exit=", is_exit);

    if (strongest == 0 && weakest == 1) {
        // A strongest, B weakest → sell PairAB (sell A, buy B)
        symbol    = g_symbols[SLOT_AB];
        direction = DIRECTION_SELL;
        double AB_history = anchor_A / anchor_B;
        price = AB_history * MathExp(T);
    }
    else if (strongest == 1 && weakest == 0) {
        // B strongest, A weakest → buy PairAB (buy A, sell B)
        symbol    = g_symbols[SLOT_AB];
        direction = DIRECTION_BUY;
        double AB_history = anchor_A / anchor_B;
        price = AB_history * MathExp(T);
    }
    else if (strongest == 0 && weakest == 2) {
        // A strongest, C weakest → sell PairAC (sell A, buy C)
        symbol    = g_symbols[SLOT_AC];
        direction = DIRECTION_SELL;
        price = anchor_A * MathExp(T);
    }
    else if (strongest == 2 && weakest == 0) {
        // C strongest, A weakest → buy PairAC (buy A, sell C)
        symbol    = g_symbols[SLOT_AC];
        direction = DIRECTION_BUY;
        price = anchor_A * MathExp(T);
    }
    else if (strongest == 1 && weakest == 2) {
        // B strongest, C weakest → sell PairBC (sell B, buy C)
        symbol    = g_symbols[SLOT_BC];
        direction = DIRECTION_SELL;
        price = anchor_B * MathExp(T);
    }
    else if (strongest == 2 && weakest == 1) {
        // C strongest, B weakest → buy PairBC (buy B, sell C)
        symbol    = g_symbols[SLOT_BC];
        direction = DIRECTION_BUY;
        price = anchor_B * MathExp(T);
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
    if      (symbol == g_symbols[SLOT_AB]) half_spread = ab_half_spread;
    else if (symbol == g_symbols[SLOT_AC]) half_spread = ac_half_spread;
    else                                   half_spread = bc_half_spread;

    if (EnableVerboseLog) Print("DIAG Invert: price_raw=", DoubleToString(price, 5),
          " half_spread=", DoubleToString(half_spread, 6),
          " direction=", direction);

    if (direction == DIRECTION_SELL)
        price = price + half_spread;
    else
        price = price - half_spread;

    if (EnableVerboseLog) Print("DIAG Invert: final_price=", DoubleToString(price, 5),
          " symbol=", symbol);

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
// RunSpreadCooldownReconciliation
// ADR-046: Runs on new M5 bar close only. Walks resting entry limits
// closer to spot as g_cooldown_LDAK decays. Only drags orders toward
// market — never away (dilation is handled by ping-pong replacement).
// Uses IsClearOfFreezeLevel() before every OrderModify.
//------------------------------------------------------------------
void RunSpreadCooldownReconciliation() {
    for (int slot = 0; slot < 3; slot++) {
        if (g_cooldown_LDAK[slot] <= 1.0) continue;  // no dilation — nothing to drag

        string symbol = g_symbols[slot];

        // Recompute ideal entry prices using current cooled-down spread
        // bid and offer spreads derived from g_scores (already updated this bar)
        double inst_spread;
        if (slot == SLOT_AC)      inst_spread = g_scores[0] - g_scores[2];
        else if (slot == SLOT_BC) inst_spread = g_scores[1] - g_scores[2];
        else                      inst_spread = g_scores[0] - g_scores[1];

        // Determine bid/offer directions per slot (binding slot ordering)
        int bid_strongest, bid_weakest, offer_strongest, offer_weakest;
        int bid_dir, offer_dir;
        if (slot == SLOT_AC) {
            bid_strongest = 2; bid_weakest = 0; bid_dir = DIRECTION_BUY;
            offer_strongest = 0; offer_weakest = 2; offer_dir = DIRECTION_SELL;
        } else if (slot == SLOT_BC) {
            bid_strongest = 2; bid_weakest = 1; bid_dir = DIRECTION_BUY;
            offer_strongest = 1; offer_weakest = 2; offer_dir = DIRECTION_SELL;
        } else {
            bid_strongest = 1; bid_weakest = 0; bid_dir = DIRECTION_BUY;
            offer_strongest = 0; offer_weakest = 1; offer_dir = DIRECTION_SELL;
        }

        double bid_spread   = inst_spread + QuoteSpread;
        double offer_spread = inst_spread - QuoteSpread;

        double ideal_bid = InvertSpreadToPrice(
            g_anchor[0], g_anchor[1], g_r_signal[0], g_r_signal[1],
            bid_spread, bid_strongest, bid_weakest, false, false);
        double ideal_offer = InvertSpreadToPrice(
            g_anchor[0], g_anchor[1], g_r_signal[0], g_r_signal[1],
            offer_spread, offer_strongest, offer_weakest, false, false);

        // Loop pending entry orders for this slot — drag toward market if cooled
        for (int i = OrdersTotal() - 1; i >= 0; i--) {
            ulong ticket = OrderGetTicket(i);
            if (ticket == 0) continue;
            if (OrderGetString(ORDER_SYMBOL) != symbol) continue;

            ulong magic = OrderGetInteger(ORDER_MAGIC);
            // ADR-060: Cooldown drag restricted to Layer 0 (EA_MAGIC) only.
            // add_next layers (EA_MAGIC+1) are structural grid defense nodes
            // and must hold their kinetic-computed spacing (ADR-057) until
            // filled or restituted (ADR-056). Dragging them toward market
            // as volatility cools collapses the grid spacing entirely --
            // observed 2026-06-30: four EURUSD layers spread across 107
            // pips collapsed to within 2.7 pips after repeated drags.
            if (magic != EA_MAGIC) continue;  // Layer 0 entries only

            ENUM_ORDER_TYPE otype       = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
            double          cur_price   = OrderGetDouble(ORDER_PRICE_OPEN);
            double          ideal_price = 0.0;
            int             direction   = -1;

            if (otype == ORDER_TYPE_BUY_LIMIT) {
                ideal_price = ideal_bid;
                direction   = DIRECTION_BUY;
                // Only drag UP — closer to market for a buy limit
                if (ideal_price <= cur_price) continue;
            } else if (otype == ORDER_TYPE_SELL_LIMIT) {
                ideal_price = ideal_offer;
                direction   = DIRECTION_SELL;
                // Only drag DOWN — closer to market for a sell limit
                if (ideal_price >= cur_price) continue;
            } else {
                continue;
            }

            if (ideal_price <= 0) continue;

            // ── ADR-048: Freeze Level Clamp ────────────────────────────
            // Instead of skipping when ideal_price is inside the freeze zone,
            // clamp it to the minimum legally permitted distance from market.
            // 2-point safety buffer prevents microsecond-tick rejections.
            {
                long   freeze_pts  = SymbolInfoInteger(symbol, SYMBOL_TRADE_FREEZE_LEVEL);
                double freeze_dist = freeze_pts * SymbolInfoDouble(symbol, SYMBOL_POINT);
                double ask_now     = SymbolInfoDouble(symbol, SYMBOL_ASK);
                double bid_now     = SymbolInfoDouble(symbol, SYMBOL_BID);
                double pt          = SymbolInfoDouble(symbol, SYMBOL_POINT);

                if (direction == DIRECTION_BUY) {
                    double min_dist = freeze_dist + (2.0 * pt);
                    if (bid_now - ideal_price < min_dist)
                        ideal_price = bid_now - min_dist;
                } else {
                    double min_dist = freeze_dist + (2.0 * pt);
                    if (ideal_price - ask_now < min_dist)
                        ideal_price = ask_now + min_dist;
                }
            }
            // ── End ADR-048 Clamp ──────────────────────────────────────

            // After clamp: verify we are still dragging TOWARD market, not away
            if (direction == DIRECTION_BUY  && ideal_price <= cur_price) continue;
            if (direction == DIRECTION_SELL && ideal_price >= cur_price) continue;

            // Final safety gate (defence in depth — post-clamp validation)
            if (!IsClearOfFreezeLevel(ideal_price, direction, symbol)) {
                if (EnableVerboseLog)
                    Print("INFO [ADR-048] Cooldown drag aborted — freeze level check failed post-clamp.",
                          " ticket=", ticket, " symbol=", symbol);
                continue;
            }

            MqlTradeRequest req = {};
            MqlTradeResult  res = {};
            req.action     = TRADE_ACTION_MODIFY;
            req.order      = ticket;
            req.price      = ideal_price;
            req.sl         = OrderGetDouble(ORDER_SL);
            req.tp         = OrderGetDouble(ORDER_TP);
            req.type_time  = (ENUM_ORDER_TYPE_TIME)OrderGetInteger(ORDER_TYPE_TIME);
            req.expiration = (datetime)OrderGetInteger(ORDER_TIME_EXPIRATION);

            if (OrderSend(req, res)) {
                if (EnableVerboseLog)
                    Print("INFO [ADR-046] Cooldown drag applied.",
                          " symbol=", symbol, " ticket=", ticket,
                          " old=", DoubleToString(cur_price, 5),
                          " new=", DoubleToString(ideal_price, 5),
                          " cooldown_LDAK=", DoubleToString(g_cooldown_LDAK[slot], 4));
            } else {
                Print("ERROR [ADR-046] Cooldown drag OrderModify failed.",
                      " ticket=", ticket, " retcode=", res.retcode);
            }
        }
    }
}

//------------------------------------------------------------------
// ComputeDynamicHalfSpread
// ADR-052 Step C: Returns the half-spread expanded by term structure
// dispersion. Low dispersion = tight spread. High dispersion = wide.
// slot: SLOT_AC=0, SLOT_BC=1, SLOT_AB=2 (AB uses min of AC/BC sigma)
//------------------------------------------------------------------
double ComputeDynamicHalfSpread(int slot) {
    double sigma;
    if (slot == SLOT_AB)
        // ADR-052: Synthetic cross inherits dispersion of most volatile leg.
        // Prevents triangular arbitrage during asymmetric shocks (weakest-link survival).
        sigma = MathMax(g_sigma_fv[0], g_sigma_fv[1]);
    else
        sigma = g_sigma_fv[slot];
    return QuoteSpread + (sigma * SpreadMultiplier);
}

//------------------------------------------------------------------
// ComputeSigmoidLotMultiplier
// ADR-052 Step C: Maps term structure dispersion to a lot size
// multiplier via mirrored logistic function. High agreement → MaxScale.
// High dispersion → 1.0 (baseline). Never below 1.0 or above MaxScale.
// slot: SLOT_AC=0, SLOT_BC=1, SLOT_AB=2 (AB uses min of AC/BC sigma)
//------------------------------------------------------------------
double ComputeSigmoidLotMultiplier(int slot) {
    double sigma_pts;
    if (slot == SLOT_AB)
        // ADR-052: Synthetic cross inherits dispersion of most volatile leg.
        // Prevents triangular arbitrage during asymmetric shocks (weakest-link survival).
        sigma_pts = MathMax(g_sigma_fv_pts[0], g_sigma_fv_pts[1]);
    else
        sigma_pts = g_sigma_fv_pts[slot];

    double multiplier = 1.0 + (SigmoidMaxScale - 1.0) /
                        (1.0 + MathExp(SigmoidSteepness * (sigma_pts - SigmoidMidpoint)));
    return MathMax(1.0, MathMin(SigmoidMaxScale, multiplier));
}

//------------------------------------------------------------------
// ComputeGridInterval
// ADR-077: four independently toggleable spacing mechanisms.
// All toggles false (default) = QuoteSpread * (layer_idx + 1) exactly.
//------------------------------------------------------------------
double ComputeGridInterval(int layer_idx, int instrument = -1) {
    double base_interval;

    if (DebugEnableGridMode) {
        if (GridMode == 0) {
            base_interval = GridBase;
        }
        else if (GridMode == 1) {
            base_interval = GridBase + layer_idx * GridLinearStep;
        }
        else {
            if (layer_idx <= GridInflection) {
                base_interval = GridBase + layer_idx * GridLinearStep;
            } else {
                double S_at_inflection = GridBase + GridInflection * GridLinearStep;
                base_interval = S_at_inflection * MathPow(GridExpBase,
                                                           layer_idx - GridInflection);
            }
        }
    } else {
        // Today's exact live formula -- unchanged when toggle is off.
        // NOT GridMode's own constant-mode branch (GridBase alone) --
        // that would silently differ from current production behavior.
        base_interval = QuoteSpread * (layer_idx + 1);
    }

    double layer_stress = DebugEnableLayerStress
                          ? MathPow(LayerStressBase, layer_idx)
                          : 1.0;

    double pnl_stress = 1.0;
    if (DebugEnablePnLStress && instrument >= 0) {
        double balance = AccountInfoDouble(ACCOUNT_BALANCE);
        double pod_pnl = GetPodUnrealizedPnL(instrument);
        if (balance > 0.0 && MaxPodDrawdown > 0.0)
            pnl_stress = 1.0 + K_spread *
                         (MathAbs(pod_pnl) / (balance * MaxPodDrawdown));
    }

    double dilation = (DebugEnableLDAKDilation && instrument >= 0)
                      ? g_cooldown_LDAK[instrument]
                      : 1.0;

    double result = base_interval * layer_stress * pnl_stress * dilation;

    if (EnableVerboseLog)
        Print("DIAG GridInterval: layer=", layer_idx,
              " gridmode=", DebugEnableGridMode,
              " base=", DoubleToString(base_interval, 6),
              " layer_stress=", DoubleToString(layer_stress, 6),
              " pnl_stress=", DoubleToString(pnl_stress, 6),
              " dilation=", DoubleToString(dilation, 6),
              " result=", DoubleToString(result, 6));
    return result;
}

//------------------------------------------------------------------
// ComputeSkew
// Returns the exit capture fraction for a given layer index.
// SkewMode 0: constant skew = SkewStart
// SkewMode 1: linear decrease floored at SkewMin
//------------------------------------------------------------------
double ComputeSkew(int layer_idx) {
    if (SkewMode == 0) {
        // Constant fraction — MM production default
        double result = MathMin(SkewStart, 1.0);
        if (EnableVerboseLog) Print("DIAG ComputeSkew: mode=0 layer=", layer_idx,
              " result=", DoubleToString(result, 6));
        return result;
    }
    else if (SkewMode == 1) {
        // Linear decrease per layer, floored at SkewMin
        double result = MathMax(MathMin(SkewStart - layer_idx * SkewStep, 1.0), SkewMin);
        if (EnableVerboseLog) Print("DIAG ComputeSkew: mode=1 layer=", layer_idx,
              " result=", DoubleToString(result, 6));
        return result;
    }
    else {
        // ADR-025 Phase 2: geometric decay — raw fraction only
        // phi = golden ratio conjugate = 0.618...
        double phi = 0.6180339887;
        double result = MathPow(phi, layer_idx + 1);
        if (EnableVerboseLog) Print("DIAG ComputeSkew: mode=2 layer=", layer_idx,
              " phi^(n+1)=", DoubleToString(result, 6));
        return result;
    }
}

double ComputeEntryPrice() {
    return InvertSpreadToPrice(
        g_anchor[0],
        g_anchor[1],
        g_r_signal[0],
        g_r_signal[1],
        g_entry_spread,
        g_strongest,
        g_weakest,
        false
    );
}

//------------------------------------------------------------------
// ComputeExitPriceDeterministic
// ADR-040: grid exit price — computed once at fill, never from live prices.
//------------------------------------------------------------------
double ComputeExitPriceDeterministic(
    double entry_price,
    double entry_spread_raw,
    int    layer_index,
    int    direction,
    double half_spread,
    int    min_layer_exit_points,
    double point_value)
{
    // ADR-046 Exit Decoupling: cap entry spread at structural baseline.
    // Prevents LDAK macro-dilation from stranding exit targets.
    // A 35bps dilated entry is treated as 8bps for exit geometry.
    double effective_spread = MathMin(MathAbs(entry_spread_raw), MathAbs(BaseThreshold));

    double E_n = effective_spread * MathPow(0.618, layer_index + 1);

    double raw_target;
    if (direction == DIRECTION_BUY)
        raw_target = entry_price + E_n - half_spread;
    else
        raw_target = entry_price - E_n + half_spread;

    double floor_dist = min_layer_exit_points * point_value;

    double exit_price;
    if (direction == DIRECTION_BUY)
        exit_price = MathMax(raw_target, entry_price + floor_dist);
    else
        exit_price = MathMin(raw_target, entry_price - floor_dist);

    return exit_price;
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

    if (distance < freeze_price) {
        if (EnableVerboseLog)
            Print("INFO: Freeze level skip — symbol=", symbol,
                  " distance=", DoubleToString(distance, 5),
                  " freeze=", DoubleToString(freeze_price, 5));
        return false;
    }
    return true;
}

#endif // MATH_ENGINE_MQH
