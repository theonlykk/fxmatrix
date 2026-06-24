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

bool RunSignalOnBarClose() {
    double ac_closes[], bc_closes[];

    if (CopyClose(g_symbols[SLOT_AC], PERIOD_M5, 0, 289, ac_closes) < 289) {
        Print("ERROR: CopyClose ", g_symbols[SLOT_AC], " failed");
        return false;
    }
    ArraySetAsSeries(ac_closes, true);
    if (CopyClose(g_symbols[SLOT_BC], PERIOD_M5, 0, 289, bc_closes) < 289) {
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

    double ac_now = ac_closes[0]  + ac_half;  // bid close → mid
    double ac_1h  = ac_closes[12] + ac_half;  // bid close → mid
    double bc_now = bc_closes[0]  + bc_half;  // bid close → mid
    double bc_1h  = bc_closes[12] + bc_half;  // bid close → mid

    if (ac_1h <= 0 || bc_1h <= 0) {
        Print("ERROR: zero/negative close price");
        return false;
    }

    g_r_signal[0] = MathLog(ac_now / ac_1h);   // r_AC: PairAC log return
    g_r_signal[1] = MathLog(bc_now / bc_1h);   // r_BC: PairBC log return
    g_anchor[0]   = ac_1h;                      // PairAC 12-bar-ago mid
    g_anchor[1]   = bc_1h;                      // PairBC 12-bar-ago mid

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

    // ── LDAK: pairwise correlation update ────────────────────────
    // LDAK: slot ordering BINDING — [SLOT_AC, SLOT_BC, SLOT_AB]
    // g_corr[0]=corr(AC,BC), g_corr[1]=corr(AC,AB), g_corr[2]=corr(BC,AB)
    double ab_closes[];
    ArraySetAsSeries(ab_closes, true);
    if (CopyClose(g_symbols[SLOT_AB], PERIOD_M5, 0, 289, ab_closes) >= 289) {
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
// ComputeGridInterval
// Returns the grid spacing S for a given layer index.
// GridMode 0: constant S = GridBase
// GridMode 1: linear S = GridBase + layer_idx * GridLinearStep
// GridMode 2: hybrid — linear up to GridInflection, then exponential
//------------------------------------------------------------------
double ComputeGridInterval(int layer_idx, int instrument = -1) {
    // Base interval from existing grid mode logic
    double base_interval = 0.0;

    if (GridMode == 0) {
        base_interval = GridBase;
    }
    else if (GridMode == 1) {
        base_interval = GridBase + layer_idx * GridLinearStep;
    }
    else { // GridMode == 2: hybrid
        if (layer_idx <= GridInflection) {
            base_interval = GridBase + layer_idx * GridLinearStep;
        }
        else {
            double S_at_inflection = GridBase + GridInflection * GridLinearStep;
            base_interval = S_at_inflection * MathPow(GridExpBase,
                                                       layer_idx - GridInflection);
        }
    }

    // Phase 3: dual stress multiplier
    // Layer count stress (leading indicator) — fires immediately on each fill
    double layer_stress = MathPow(LayerStressBase, layer_idx);

    // PnL stress (lagging amplifier) — grows as pod bleeds
    double pnl_stress = 1.0;
    if (instrument >= 0) {
        double balance  = AccountInfoDouble(ACCOUNT_BALANCE);
        double pod_pnl  = GetPodUnrealizedPnL(instrument);
        if (balance > 0.0 && MaxPodDrawdown > 0.0)
            pnl_stress = 1.0 + K_spread *
                         (MathAbs(pod_pnl) / (balance * MaxPodDrawdown));
    }

    // LDAK: volatility-gated grid dilation
    if (instrument >= 0) {
        double S_eff = 0.0;
        int inv_size[3];
        inv_size[0] = ArraySize(g_inventory_0);
        inv_size[1] = ArraySize(g_inventory_1);
        inv_size[2] = ArraySize(g_inventory_2);

        // Generic LDAK loop — slot ordering [AC, BC, AB] is binding
        for (int j = 0; j < 3; j++) {
            if (j == instrument) continue;
            if (inv_size[j] == 0) continue;

            // corr_index: symmetric lookup for pair (instrument, j)
            int ci;
            int lo = MathMin(instrument, j);
            int hi = MathMax(instrument, j);
            if      (lo == 0 && hi == 1) ci = 0;
            else if (lo == 0 && hi == 2) ci = 1;
            else                          ci = 2;  // lo==1, hi==2

            double v_eff = MathMax(g_vratio[instrument], g_vratio[j]);
            double S     = MathMax(g_corr[ci], 0.0) * MathMax(v_eff - 1.0, 0.0);
            S_eff = MathMax(S_eff, S);
        }

        double dilation = MathMin(1.0 + S_eff * S_eff, LDAK_Dilation_Max);
        base_interval  *= layer_stress * pnl_stress * dilation;
        if (EnableVerboseLog) Print("DIAG GridInterval: layer=", layer_idx,
              " base=", DoubleToString(base_interval / (layer_stress * pnl_stress * dilation), 6),
              " layer_stress=", DoubleToString(layer_stress, 6),
              " pnl_stress=", DoubleToString(pnl_stress, 6),
              " dilation=", DoubleToString(dilation, 6),
              " result=", DoubleToString(base_interval, 6));
        return base_interval;
    }

    if (EnableVerboseLog) Print("DIAG GridInterval: layer=", layer_idx,
          " base=", DoubleToString(base_interval / (layer_stress * pnl_stress), 6),
          " layer_stress=", DoubleToString(layer_stress, 6),
          " pnl_stress=", DoubleToString(pnl_stress, 6),
          " dilation=N/A",
          " result=", DoubleToString(base_interval * layer_stress * pnl_stress, 6));
    return base_interval * layer_stress * pnl_stress;
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
        // Floor and 0.99 ceiling applied in ComputeExitSpreadTarget()
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

// ADR-039: Sentinel value returned by JIT functions when anchor or spread is invalid.
// Consistent with InvertSpreadToPrice contract (returns -1.0 on failure).
// Callers must treat any return value < 0.0 as a silent skip.
#define INVALID_EXIT_SPREAD (-1.0)

//------------------------------------------------------------------
// ComputeExitSpreadJIT
// ADR-039 Phase 1: stateless pure function. No cached state written.
//
// Reads cached bar-close anchor (g_anchor[0/1]) — anchor is a bar-level
// signal and correctly stays on the bar-close path (RunSignalOnBarClose).
// Reads LIVE bid/ask for SLOT_AC and SLOT_BC to compute inst_spread at
// the moment of placement, not at fill time.
//
// Eliminates Bugs 1 and 3: stale exit_spread_target cached at fill time
// with an invalid anchor (Bug 1) or transient sign inversion (Bug 3)
// can no longer freeze the exit engine. Each tick gets fresh computation.
//
// Eliminates Bug 2: positive inst_spread guard detects transient inversion
// and skips the tick rather than writing a wrong-side exit permanently.
//
// Returns INVALID_EXIT_SPREAD (-1.0) if:
//   - Either cached anchor <= 0 (session-open race / anchor not yet populated)
//   - Any bid/ask is zero (liquidity gap)
//   - MathAbs(inst_spread) <= DBL_EPSILON (degenerate spread)
//   - inst_spread > 0 (transient inversion — skip tick, retry next)
//------------------------------------------------------------------
double ComputeExitSpreadJIT(const Layer &layer) {
    // Anchor guard: catches session-open race (Bug 1)
    if (g_anchor[0] <= 0.0 || g_anchor[1] <= 0.0) {
        if (EnableVerboseLog)
            Print("DIAG ExitSpreadJIT: anchor invalid — skipping. ",
                  "anchor_A=", DoubleToString(g_anchor[0], 5),
                  " anchor_B=", DoubleToString(g_anchor[1], 5));
        return INVALID_EXIT_SPREAD;
    }

    // Read live mid prices — convention matches RunSignalOnBarClose exactly
    double ac_ask = SymbolInfoDouble(g_symbols[SLOT_AC], SYMBOL_ASK);
    double ac_bid = SymbolInfoDouble(g_symbols[SLOT_AC], SYMBOL_BID);
    double bc_ask = SymbolInfoDouble(g_symbols[SLOT_BC], SYMBOL_ASK);
    double bc_bid = SymbolInfoDouble(g_symbols[SLOT_BC], SYMBOL_BID);

    if (ac_ask <= 0.0 || ac_bid <= 0.0 || bc_ask <= 0.0 || bc_bid <= 0.0) {
        Print("WARNING: ComputeExitSpreadJIT — zero bid/ask on signal pair");
        return INVALID_EXIT_SPREAD;
    }

    double ac_mid = (ac_ask + ac_bid) / 2.0;
    double bc_mid = (bc_ask + bc_bid) / 2.0;

    // JIT log return against cached anchor
    double r_AC = MathLog(ac_mid / g_anchor[0]);
    double r_BC = MathLog(bc_mid / g_anchor[1]);

    // Zero-sum score decomposition — identical to RunSignalOnBarClose
    double score_C = -(r_AC + r_BC) / 3.0;
    double score_A =   r_AC + score_C;
    double score_B =   r_BC + score_C;
    double scores[3];
    scores[0] = score_A;
    scores[1] = score_B;
    scores[2] = score_C;

    // inst_spread = scores[weakest] - scores[strongest]
    // Normal invariant: weakest < strongest → negative result
    double inst_spread = scores[layer.weakest_at_entry] - scores[layer.strongest_at_entry];

    // Degenerate spread guard
    if (MathAbs(inst_spread) <= DBL_EPSILON) {
        if (EnableVerboseLog)
            Print("DIAG ExitSpreadJIT: degenerate inst_spread — skipping. ",
                  "weakest=", layer.weakest_at_entry,
                  " strongest=", layer.strongest_at_entry,
                  " inst_spread=", DoubleToString(inst_spread, 8));
        return INVALID_EXIT_SPREAD;
    }

    // Bug 2 / sign guard: positive inst_spread = transient inversion.
    // Exit price would land on wrong side of anchor. Skip tick, retry next.
    if (inst_spread > 0.0) {
        if (EnableVerboseLog)
            Print("DIAG ExitSpreadJIT: transient inversion — skipping tick. ",
                  "inst_spread=", DoubleToString(inst_spread, 8),
                  " weakest=", layer.weakest_at_entry,
                  " strongest=", layer.strongest_at_entry);
        return INVALID_EXIT_SPREAD;
    }

    // Apply skew and floor — identical logic to ComputeExitSpreadTarget
    double raw_skew = ComputeSkew(layer.layer_index);

    if (SkewMode != 2) {
        double result = inst_spread * raw_skew;
        if (EnableVerboseLog)
            Print("DIAG ExitSpreadJIT: mode=", SkewMode,
                  " layer=", layer.layer_index,
                  " inst_spread=", DoubleToString(inst_spread, 6),
                  " raw_skew=", DoubleToString(raw_skew, 6),
                  " exit_spread=", DoubleToString(result, 6));
        return result;
    }

    // SkewMode=2: layer-decaying floor (ADR-038)
    string symbol  = g_symbols[layer.instrument];
    double pt      = SymbolInfoDouble(symbol, SYMBOL_POINT);
    double phi     = 0.6180339887;
    double floor_n = MathMax(
        SkewFloor0 * MathPow(phi, layer.layer_index),
        MinLayerExitPoints * pt
    );

    double abs_entry      = MathAbs(inst_spread);
    double floor_skew     = (abs_entry > 1e-10) ? floor_n / abs_entry : raw_skew;
    double effective_skew = MathMin(MathMax(raw_skew, floor_skew), 0.99);
    double result         = inst_spread * effective_skew;

    if (EnableVerboseLog)
        Print("DIAG ExitSpreadJIT: layer=", layer.layer_index,
              " inst_spread=", DoubleToString(inst_spread, 6),
              " raw_skew=", DoubleToString(raw_skew, 6),
              " floor_n=", DoubleToString(floor_n, 6),
              " floor_skew=", DoubleToString(floor_skew, 6),
              " effective_skew=", DoubleToString(effective_skew, 6),
              " exit_spread=", DoubleToString(result, 6));

    return result;
}

//------------------------------------------------------------------
// ComputeExitPriceJIT
// ADR-039 Phase 1+2: JIT exit price via ComputeExitSpreadJIT.
//
// Sign contract (Phase 2):
//   ComputeExitSpreadJIT guarantees a strictly negative return value
//   (sign guard returns INVALID_EXIT_SPREAD if inst_spread >= 0).
//   InvertSpreadToPrice internally does `if (is_exit) T = -T` on its
//   first line, negating to positive before anchor * MathExp(T).
//   This places the exit above anchor for BUY (sell limit) and below
//   anchor for SELL (buy limit) — correct for both cases.
//   No MathAbs() needed: the contract is pass negative spread, function
//   inverts internally via the is_exit flag.
//
// Returns INVALID_EXIT_SPREAD (-1.0) if JIT spread is invalid.
// Callers use existing `if (exit_price < 0.0)` guards unchanged.
//------------------------------------------------------------------
double ComputeExitPriceJIT(const Layer &layer) {
    double exit_spread = ComputeExitSpreadJIT(layer);
    if (exit_spread == INVALID_EXIT_SPREAD)
        return INVALID_EXIT_SPREAD;

    return InvertSpreadToPrice(
        layer.anchor_A_at_entry,
        layer.anchor_B_at_entry,
        layer.r_AC_at_entry,
        layer.r_BC_at_entry,
        exit_spread,
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
