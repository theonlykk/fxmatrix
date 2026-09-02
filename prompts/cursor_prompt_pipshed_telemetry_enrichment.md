# Pipshed Telemetry Enrichment — Cursor Implementation Prompt
## DRAFT — Review after multi-timeframe architecture is locked
## Do NOT send to Cursor until Pipshed frontend is reviewed

This message has a line count at the bottom.

---

## Context

You are enriching the telemetry payload in `d:\fxmatrix\ea\TelemetryEngine.mqh`. This is a non-trading change — no execution logic is affected. The goal is to give the Pipshed dashboard enough data to show live positions, working orders, order commentary, and orphan detection.

**One file changes: `TelemetryEngine.mqh`. No other files are touched.**

---

## Current State

`SerializePodJSON()` currently sends per slot:
```json
{"layers": 2, "net_pnl": 0.32, "distance_to_target_pips": 3.1}
```

`BuildTelemetryPayload()` sends:
- Timestamp, instance_id, account metrics
- Engine state: execution_mode, quote_spread, daily_api_count, ldak_vratios, rollover_active
- active_pods: one SerializePodJSON per slot

Missing: entry prices, exit prices, add-next levels, working order tickets and prices, live market prices, cooldown_LDAK, layer-level commentary flags.

---

## What Is Being Built

### Change 1 — Enrich SerializePodJSON() with full layer detail

Replace the current `SerializePodJSON()` with a version that serializes each layer in the inventory:

```mql5
string SerializePodJSON(int slot) {
    int    pod_layers = 0;
    double pod_pnl    = 0.0;
    double pod_dist   = 0.0;
    GetPodMetrics(slot, pod_layers, pod_pnl, pod_dist);

    string dist_str = (pod_layers == 0) ? "null" : TelDoubleStr(pod_dist, 1);

    // Build layers array
    string layers_json = "[";
    int inv_size = (slot == 0) ? ArraySize(g_inventory_0)
                 : (slot == 1) ? ArraySize(g_inventory_1)
                 : ArraySize(g_inventory_2);

    for (int i = 0; i < inv_size; i++) {
        Layer L = (slot == 0) ? g_inventory_0[i]
                : (slot == 1) ? g_inventory_1[i]
                : g_inventory_2[i];

        // Commentary flags
        bool is_toxic        = (MathAbs(L.entry_spread_raw) < SkewFloor0);
        bool is_floor_clamped = (L.exit_price_fixed > 0 &&
                                  MathAbs(L.exit_price_fixed - L.entry_price)
                                  <= MinLayerExitPoints * SymbolInfoDouble(g_symbols[slot], SYMBOL_POINT) * 1.01);
        bool has_position    = (L.position_ticket > 0);

        string layer_str = StringFormat(
            "{"
            "\"layer_index\":%d,"
            "\"direction\":%d,"
            "\"entry_price\":%.5f,"
            "\"entry_spread_raw\":%.6f,"
            "\"exit_price_fixed\":%.5f,"
            "\"add_next\":%.5f,"
            "\"position_ticket\":%llu,"
            "\"has_exit_limit\":%s,"
            "\"is_toxic\":%s,"
            "\"is_floor_clamped\":%s"
            "}",
            L.layer_index,
            L.direction,
            L.entry_price,
            L.entry_spread_raw,
            L.exit_price_fixed,
            L.add_next,
            L.position_ticket,
            has_position ? "true" : "false",
            is_toxic ? "true" : "false",
            is_floor_clamped ? "true" : "false"
        );

        if (i > 0) layers_json += ",";
        layers_json += layer_str;
    }
    layers_json += "]";

    return StringFormat(
        "{"
        "\"layers\":%d,"
        "\"net_pnl\":%.2f,"
        "\"distance_to_target_pips\":%s,"
        "\"layer_detail\":%s"
        "}",
        pod_layers,
        pod_pnl,
        dist_str,
        layers_json
    );
}
```

### Change 2 — Add working orders and live market prices to BuildTelemetryPayload()

In `BuildTelemetryPayload()`, add a new `working_orders` block and `market_prices` block to the JSON payload:

```mql5
    // Working orders per slot
    string orders_json = StringFormat(
        "{"
        "\"%s\":{\"bid_ticket\":%llu,\"bid_price\":%.5f,\"offer_ticket\":%llu,\"offer_price\":%.5f},"
        "\"%s\":{\"bid_ticket\":%llu,\"bid_price\":%.5f,\"offer_ticket\":%llu,\"offer_price\":%.5f},"
        "\"%s\":{\"bid_ticket\":%llu,\"bid_price\":%.5f,\"offer_ticket\":%llu,\"offer_price\":%.5f}"
        "}",
        g_symbols[SLOT_AC],
        g_pending_bid[SLOT_AC],   GetPendingOrderPrice(g_pending_bid[SLOT_AC]),
        g_pending_offer[SLOT_AC], GetPendingOrderPrice(g_pending_offer[SLOT_AC]),
        g_symbols[SLOT_BC],
        g_pending_bid[SLOT_BC],   GetPendingOrderPrice(g_pending_bid[SLOT_BC]),
        g_pending_offer[SLOT_BC], GetPendingOrderPrice(g_pending_offer[SLOT_BC]),
        g_symbols[SLOT_AB],
        g_pending_bid[SLOT_AB],   GetPendingOrderPrice(g_pending_bid[SLOT_AB]),
        g_pending_offer[SLOT_AB], GetPendingOrderPrice(g_pending_offer[SLOT_AB])
    );

    // Live market prices
    string market_json = StringFormat(
        "{"
        "\"%s\":{\"bid\":%.5f,\"ask\":%.5f},"
        "\"%s\":{\"bid\":%.5f,\"ask\":%.5f},"
        "\"%s\":{\"bid\":%.5f,\"ask\":%.5f}"
        "}",
        g_symbols[SLOT_AC],
        SymbolInfoDouble(g_symbols[SLOT_AC], SYMBOL_BID),
        SymbolInfoDouble(g_symbols[SLOT_AC], SYMBOL_ASK),
        g_symbols[SLOT_BC],
        SymbolInfoDouble(g_symbols[SLOT_BC], SYMBOL_BID),
        SymbolInfoDouble(g_symbols[SLOT_BC], SYMBOL_ASK),
        g_symbols[SLOT_AB],
        SymbolInfoDouble(g_symbols[SLOT_AB], SYMBOL_BID),
        SymbolInfoDouble(g_symbols[SLOT_AB], SYMBOL_ASK)
    );

    // Cooldown LDAK per slot
    string cooldown_json = StringFormat(
        "{\"%s\":%.4f,\"%s\":%.4f,\"%s\":%.4f}",
        g_symbols[SLOT_AC], g_cooldown_LDAK[SLOT_AC],
        g_symbols[SLOT_BC], g_cooldown_LDAK[SLOT_BC],
        g_symbols[SLOT_AB], g_cooldown_LDAK[SLOT_AB]
    );
```

Then add these to the `return StringFormat(...)` block:
```json
"working_orders": <orders_json>,
"market_prices": <market_json>,
"cooldown_ldak": <cooldown_json>
```

### Change 3 — Orphan detection flags in SerializePodJSON()

Add an `orphan_detected` flag per slot — true if any layer has `position_ticket > 0` but `ArraySize(exit_tickets) == 0`:

```mql5
        bool orphan = (has_position && ArraySize(L.exit_tickets) == 0);
```

Include in layer JSON:
```json
"orphan_detected": true/false
```

---

## Negative Space — What NOT To Touch

- Do not modify any execution engine files
- Do not modify `EmitPodClose()` — that is correct as-is
- Do not modify `EmitTelemetry()` dispatch logic
- Do not add any new input parameters
- Do not change the telemetry URL or authentication

---

## Verification

1. `SerializePodJSON()` returns `layer_detail` array with per-layer objects
2. Each layer object includes: `layer_index`, `direction`, `entry_price`, `entry_spread_raw`, `exit_price_fixed`, `add_next`, `position_ticket`, `has_exit_limit`, `is_toxic`, `is_floor_clamped`, `orphan_detected`
3. `BuildTelemetryPayload()` includes `working_orders`, `market_prices`, `cooldown_ldak`
4. `working_orders` includes bid/offer ticket and price per slot
5. `market_prices` includes live bid/ask per symbol
6. Only `TelemetryEngine.mqh` modified

---

## Notes for Pipshed Frontend

The enriched payload enables:
- **Live positions panel:** render `active_pods[symbol].layer_detail[]` — entry price, exit target, direction per layer
- **Working orders panel:** render `working_orders[symbol]` — bid and offer tickets and prices
- **Distance to market:** compute from `market_prices[symbol].bid/ask` vs `working_orders[symbol].bid/offer_price`
- **Orphan alerts:** flag any layer where `orphan_detected=true`
- **Commentary column:** derive from `is_toxic`, `is_floor_clamped`, `cooldown_ldak` values
- **Live P&L:** `active_pods[symbol].net_pnl` (already present, now with layer breakdown)

Line count: 142
