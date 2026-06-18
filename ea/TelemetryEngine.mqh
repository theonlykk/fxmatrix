//------------------------------------------------------------------
// TelemetryEngine.mqh
// FXMatrix Live Telemetry Emitter — Pipshed Phase 1
// Fires a JSON heartbeat to the Pipshed Flask API on a timed
// interval or immediately on state change.
//
// PREREQUISITES:
// MT5 → Tools → Options → Expert Advisors → Allow WebRequest
// must include the Pipshed API URL before this will fire.
//
// ADR-021 compliant: uses InstanceID from Globals.mqh
// Gemini review: timeout 200ms, symbol string injection,
//                bid/ask asymmetry fix
//------------------------------------------------------------------

#ifndef TELEMETRY_ENGINE_MQH
#define TELEMETRY_ENGINE_MQH

#include "Globals.mqh"
#include "LayerStruct.mqh"

//------------------------------------------------------------------
// Configuration inputs
//------------------------------------------------------------------

//------------------------------------------------------------------
// Internal state
//------------------------------------------------------------------
datetime g_last_telemetry_emit = 0;

//------------------------------------------------------------------
// Helper: escape a double to a fixed-precision string for JSON
//------------------------------------------------------------------
string TelDoubleStr(double val, int digits = 5) {
    if (MathAbs(val) < 1e-10) return "0.0";
    return DoubleToString(val, digits);
}

//------------------------------------------------------------------
// GetPodMetrics
// Pass physical symbol strings (e.g. "EURUSD", "EURUSD.pro") from
// the caller to avoid hardcoded broker-agnostic symbol failures.
// Fix: Bid/Ask asymmetry — exit distance uses correct price side.
//------------------------------------------------------------------
void GetPodMetrics(string symbol,
                   Layer& layers[], int layer_count,
                   int&    out_layers,
                   double& out_pnl,
                   double& out_dist_pips) {

    out_layers    = layer_count;
    out_pnl       = 0.0;
    out_dist_pips = 0.0;

    if (layer_count == 0) return;

    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    if (point == 0.0) return; // symbol not found — fail silently

    // Aggregate unrealised P&L across all layers
    for (int i = 0; i < layer_count; i++) {
        if (PositionSelectByTicket(layers[i].position_ticket)) {
            out_pnl += PositionGetDouble(POSITION_PROFIT);
        }
    }

    // Distance to target: shallowest layer (Layer 0) exit ticket
    // Fix: use ASK for buy limits, BID for sell limits
    if (layers[0].exit_ticket > 0 && OrderSelect(layers[0].exit_ticket)) {
        double exit_price  = OrderGetDouble(ORDER_PRICE_OPEN);
        ENUM_ORDER_TYPE ot = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);

        double reference_price = (ot == ORDER_TYPE_BUY_LIMIT)
            ? SymbolInfoDouble(symbol, SYMBOL_ASK)
            : SymbolInfoDouble(symbol, SYMBOL_BID);

        out_dist_pips = MathAbs(exit_price - reference_price) / point / 10.0;
    }
}

//------------------------------------------------------------------
// SerializePodJSON
// Returns a JSON object string for one instrument pod.
// Accepts physical symbol string from caller.
//------------------------------------------------------------------
string SerializePodJSON(string symbol, Layer& layers[], int layer_count) {
    int    pod_layers = 0;
    double pod_pnl    = 0.0;
    double pod_dist   = 0.0;

    GetPodMetrics(symbol, layers, layer_count,
                  pod_layers, pod_pnl, pod_dist);

    string dist_str = (pod_layers == 0)
        ? "null"
        : TelDoubleStr(pod_dist, 1);

    return StringFormat(
        "{\"layers\":%d,\"net_pnl\":%.2f,\"distance_to_target_pips\":%s}",
        pod_layers,
        pod_pnl,
        dist_str
    );
}

//------------------------------------------------------------------
// BuildTelemetryPayload
// Constructs the full JSON string per Gemini Phase 1 spec.
// Caller passes physical symbol strings for broker-suffix safety.
//------------------------------------------------------------------
string BuildTelemetryPayload(
    string eu_symbol, Layer& eu_layers[], int eu_count,
    string gu_symbol, Layer& gu_layers[], int gu_count,
    string eg_symbol, Layer& eg_layers[], int eg_count)
{
    // Timestamp in ISO 8601 UTC
    MqlDateTime dt;
    TimeToStruct(TimeGMT(), dt);
    string ts = StringFormat("%04d-%02d-%02dT%02d:%02d:%02dZ",
        dt.year, dt.mon, dt.day, dt.hour, dt.min, dt.sec);

    // Account metrics
    double balance     = AccountInfoDouble(ACCOUNT_BALANCE);
    double equity      = AccountInfoDouble(ACCOUNT_EQUITY);
    double margin_used = AccountInfoDouble(ACCOUNT_MARGIN);
    double margin_lvl  = (margin_used > 0.0)
        ? (equity / margin_used) * 100.0
        : 0.0;

    // Engine state
    string exec_mode_str = (ExecutionMode == MARKET_MAKER)
        ? "PASSIVE_QUOTING"
        : "SNIPER";

    // Pod JSON blocks — pass physical symbol strings
    string eu_pod = SerializePodJSON(eu_symbol, eu_layers, eu_count);
    string gu_pod = SerializePodJSON(gu_symbol, gu_layers, gu_count);
    string eg_pod = SerializePodJSON(eg_symbol, eg_layers, eg_count);

    return StringFormat(
        "{"
        "\"timestamp\":\"%s\","
        "\"environment\":\"FTMO_10K\","
        "\"instance_id\":\"%s\","
        "\"account_metrics\":{"
            "\"balance\":%.2f,"
            "\"equity\":%.2f,"
            "\"margin_level_pct\":%.2f"
        "},"
        "\"engine_state\":{"
            "\"execution_mode\":\"%s\","
            "\"quote_spread\":%.6f,"
            "\"daily_api_count\":%d"
        "},"
        "\"active_pods\":{"
            "\"EURUSD\":%s,"
            "\"GBPUSD\":%s,"
            "\"EURGBP\":%s"
        "}"
        "}",
        ts,
        InstanceID,
        balance,
        equity,
        margin_lvl,
        exec_mode_str,
        QuoteSpread,
        g_daily_api_count,
        eu_pod,
        gu_pod,
        eg_pod
    );
}

//------------------------------------------------------------------
// EmitTelemetry
// Call from OnTick (throttled) or on state change (force=true).
//
// CRITICAL (Gemini ruling): timeout = 200ms only.
// WebRequest is synchronous and blocks the EA thread.
// Telemetry is non-critical — dropped payloads catch on next
// heartbeat. Never let telemetry stall the market maker.
//
// Future: replace with FileWrite + Python daemon for async decoupling.
//------------------------------------------------------------------
void EmitTelemetry(
    string eu_symbol, Layer& eu_layers[], int eu_count,
    string gu_symbol, Layer& gu_layers[], int gu_count,
    string eg_symbol, Layer& eg_layers[], int eg_count,
    bool force = false)
{
    if (!EnableTelemetry) return;
    if (TelemetryURL == "" || TelemetryAPIKey == "") return;

    datetime now = TimeCurrent();
    if (!force && (now - g_last_telemetry_emit) < TelemetryIntervalSec) return;

    string payload = BuildTelemetryPayload(
        eu_symbol, eu_layers, eu_count,
        gu_symbol, gu_layers, gu_count,
        eg_symbol, eg_layers, eg_count
    );

    string headers = "Content-Type: application/json\r\n"
                   + "Authorization: Bearer " + TelemetryAPIKey + "\r\n";

    char   post_data[];
    char   result_data[];
    string result_headers;

    StringToCharArray(payload, post_data, 0, StringLen(payload));

    // 200ms timeout — telemetry must never block the market maker
    int http_status = WebRequest(
        "POST",
        TelemetryURL,
        headers,
        200,
        post_data,
        result_data,
        result_headers
    );

    if (http_status == 200) {
        g_last_telemetry_emit = now;
        if (EnableVerboseLog)
            Print("INFO: Telemetry emitted. instance=", InstanceID,
                  " eu=", eu_count, " gu=", gu_count, " eg=", eg_count);
    } else {
        if (EnableVerboseLog)
            Print("INFO: Telemetry dropped. status=", http_status,
                  " — will retry next heartbeat.");
    }
}

#endif // TELEMETRY_ENGINE_MQH
