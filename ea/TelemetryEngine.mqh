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
// ADR-024 T2: slot-indexed — reads g_inventory_0/1/2 from globals.
// Fix: Bid/Ask asymmetry — exit distance uses correct price side.
//------------------------------------------------------------------
// ADR-024 T2: reads slot inventory directly from globals
// slot: 0=PairAC, 1=PairBC, 2=PairAB
void GetPodMetrics(int slot,
                   int&    out_layers,
                   double& out_pnl,
                   double& out_dist_pips) {

    int layer_count = (slot == 0) ? ArraySize(g_inventory_0)
                    : (slot == 1) ? ArraySize(g_inventory_1)
                    : ArraySize(g_inventory_2);

    out_layers    = layer_count;
    out_pnl       = 0.0;
    out_dist_pips = 0.0;

    if (layer_count == 0) return;

    string symbol = g_symbols[slot];
    double point  = SymbolInfoDouble(symbol, SYMBOL_POINT);
    if (point == 0.0) return;

    for (int i = 0; i < layer_count; i++) {
        ulong pos_tkt = (slot == 0) ? g_inventory_0[i].position_ticket
                      : (slot == 1) ? g_inventory_1[i].position_ticket
                      : g_inventory_2[i].position_ticket;
        if (PositionSelectByTicket(pos_tkt))
            out_pnl += PositionGetDouble(POSITION_PROFIT);
    }

    // Distance to target: shallowest layer (index 0) exit ticket
    ulong first_exit = 0;
    int   n_exits    = 0;
    if (slot == 0) {
        n_exits    = ArraySize(g_inventory_0[0].exit_tickets);
        if (n_exits > 0) first_exit = g_inventory_0[0].exit_tickets[0];
    } else if (slot == 1) {
        n_exits    = ArraySize(g_inventory_1[0].exit_tickets);
        if (n_exits > 0) first_exit = g_inventory_1[0].exit_tickets[0];
    } else {
        n_exits    = ArraySize(g_inventory_2[0].exit_tickets);
        if (n_exits > 0) first_exit = g_inventory_2[0].exit_tickets[0];
    }

    if (first_exit > 0 && OrderSelect(first_exit)) {
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
// Returns a JSON object string for one instrument pod (slot-indexed).
//------------------------------------------------------------------
string SerializePodJSON(int slot) {
    int    pod_layers = 0;
    double pod_pnl    = 0.0;
    double pod_dist   = 0.0;

    GetPodMetrics(slot, pod_layers, pod_pnl, pod_dist);

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
// ADR-024 T2: constructs full JSON from globals; dynamic symbol keys.
//------------------------------------------------------------------
// ADR-024 T2: reads all state from globals directly
// Dynamic JSON keys per Gemini Q2 ruling — dashboard uses Object.keys()
string BuildTelemetryPayload() {
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

    // Dynamic ldak_vratios — keyed by physical symbol string
    string ldak_json = StringFormat(
        "{\"%s\":%.3f,\"%s\":%.3f,\"%s\":%.3f}",
        g_symbols[SLOT_AC], g_vratio[SLOT_AC],
        g_symbols[SLOT_BC], g_vratio[SLOT_BC],
        g_symbols[SLOT_AB], g_vratio[SLOT_AB]);

    // Pod JSON blocks — slot-indexed
    string pod0 = SerializePodJSON(SLOT_AC);
    string pod1 = SerializePodJSON(SLOT_BC);
    string pod2 = SerializePodJSON(SLOT_AB);

    // Dynamic active_pods — keyed by physical symbol string
    string pods_json = StringFormat(
        "{\"%s\":%s,\"%s\":%s,\"%s\":%s}",
        g_symbols[SLOT_AC], pod0,
        g_symbols[SLOT_BC], pod1,
        g_symbols[SLOT_AB], pod2);

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
            "\"daily_api_count\":%d,"
            "\"ldak_vratios\":%s,"
            "\"rollover_active\":%s"
        "},"
        "\"active_pods\":%s"
        "}",
        ts,
        InstanceID,
        balance,
        equity,
        margin_lvl,
        exec_mode_str,
        QuoteSpread,
        g_daily_api_count,
        ldak_json,
        IsRolloverWindow(TimeGMT()) ? "true" : "false",
        pods_json
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
// ADR-024 T2: no array arguments — reads g_inventory_0/1/2 via globals
void EmitTelemetry(bool force = false) {
    if (!EnableTelemetry) return;
    if (TelemetryURL == "" || TelemetryAPIKey == "") return;

    datetime now = TimeCurrent();
    if (!force && (now - g_last_telemetry_emit) < TelemetryIntervalSec) return;

    string payload = BuildTelemetryPayload();

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
                  " slots=[", ArraySize(g_inventory_0), ",",
                  ArraySize(g_inventory_1), ",",
                  ArraySize(g_inventory_2), "]");
    } else {
        if (EnableVerboseLog)
            Print("INFO: Telemetry dropped. status=", http_status,
                  " — will retry next heartbeat.");
    }
}

//------------------------------------------------------------------
// EmitPodClose
// Fires a single closed pod record to POST /api/telemetry/pod_closed.
// Called from HandleExitFill() after full LIFO unwind confirmed.
// P&L passed directly from deal_profit — never recalculated from
// dead tickets (positions are already closed at call time).
//------------------------------------------------------------------
void EmitPodClose(string   symbol,
                  string   direction,
                  int      layers_closed,
                  double   avg_entry_price,
                  double   exit_price,
                  double   hold_time_minutes,
                  double   gross_pnl)
{
    if (!EnableTelemetry) return;
    if (TelemetryURL == "" || TelemetryAPIKey == "") return;

    MqlDateTime dt;
    TimeToStruct(TimeGMT(), dt);
    string ts = StringFormat("%04d-%02d-%02dT%02d:%02d:%02dZ",
        dt.year, dt.mon, dt.day, dt.hour, dt.min, dt.sec);

    // ADR-053: broker local trade date for frontend date filtering
    // Uses TimeCurrent() (broker local) not TimeGMT() -- trades belong
    // to the broker session date, not UTC calendar date.
    MqlDateTime dtLocal;
    TimeToStruct(TimeCurrent(), dtLocal);
    string trade_date = StringFormat("%04d-%02d-%02d",
                                     dtLocal.year, dtLocal.mon, dtLocal.day);

    string payload = StringFormat(
        "{"
        "\"close_time\":\"%s\","
        "\"trade_date\":\"%s\","
        "\"instrument\":\"%s\","
        "\"direction\":\"%s\","
        "\"layers_closed\":%d,"
        "\"avg_entry_price\":%.5f,"
        "\"exit_price\":%.5f,"
        "\"hold_time_minutes\":%.1f,"
        "\"gross_pnl\":%.2f,"
        "\"instance_id\":\"%s\""
        "}",
        ts, trade_date, symbol, direction, layers_closed,
        avg_entry_price, exit_price, hold_time_minutes,
        gross_pnl, InstanceID
    );

    // Derive pod_closed URL from TelemetryURL by replacing /push with /pod_closed
    string pod_closed_url = "";
    int push_pos = StringFind(TelemetryURL, "/push");
    if (push_pos >= 0)
        pod_closed_url = StringSubstr(TelemetryURL, 0, push_pos) + "/pod_closed";
    else
        pod_closed_url = TelemetryURL + "/pod_closed";

    string headers = "Content-Type: application/json\r\n"
                   + "Authorization: Bearer " + TelemetryAPIKey + "\r\n";

    char   post_data[];
    char   result_data[];
    string result_headers;
    StringToCharArray(payload, post_data, 0, StringLen(payload));

    int http_status = WebRequest(
        "POST", pod_closed_url, headers, 200,
        post_data, result_data, result_headers
    );

    if (EnableVerboseLog) {
        if (http_status == 200)
            Print("INFO: Pod close telemetry emitted. symbol=", symbol,
                  " direction=", direction, " pnl=", DoubleToString(gross_pnl, 2));
        else
            Print("INFO: Pod close telemetry dropped. status=", http_status);
    }
}

#endif // TELEMETRY_ENGINE_MQH
