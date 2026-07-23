//+------------------------------------------------------------------+
//| fxmatrix_v2_telemetry.mqh — Pipshed telemetry for production V2   |
//| Dual heartbeat: MM_LONG_V2 + MM_SHORT_V2 separate Redis keys.     |
//+------------------------------------------------------------------+
#ifndef FXMATRIX_V2_TELEMETRY_MQH
#define FXMATRIX_V2_TELEMETRY_MQH

#include "fxmatrix_v2_api_counter.mqh"

#ifndef V2_TEL_INSTANCE_LONG
#define V2_TEL_INSTANCE_LONG  "MM_LONG_V2"
#endif
#ifndef V2_TEL_INSTANCE_SHORT
#define V2_TEL_INSTANCE_SHORT "MM_SHORT_V2"
#endif

//+------------------------------------------------------------------+
struct V2TelLayerSnapshot
{
   double entry_price;
   double exit_target;
   double lot_size;
   int    direction;          // 1=BUY/LONG, -1=SELL/SHORT
   ulong  position_ticket;
   ulong  exit_ticket;
};

//+------------------------------------------------------------------+
struct V2PodSession
{
   bool     active;
   datetime start_time;
   double   layer0_entry;
   int      layers_closed;
   double   gross_pnl;
};

//+------------------------------------------------------------------+
void V2PodReset(V2PodSession &pod)
{
   pod.active         = false;
   pod.start_time     = 0;
   pod.layer0_entry   = 0.0;
   pod.layers_closed  = 0;
   pod.gross_pnl      = 0.0;
}

//+------------------------------------------------------------------+
void V2PodOnFirstLayer(V2PodSession &pod,
                      const double entry_price,
                      const datetime entry_time)
{
   pod.active        = true;
   pod.start_time    = entry_time;
   pod.layer0_entry  = entry_price;
   pod.layers_closed = 0;
   pod.gross_pnl     = 0.0;
}

//+------------------------------------------------------------------+
void V2PodAccumulateExit(V2PodSession &pod, const double realized_pnl)
{
   pod.layers_closed++;
   pod.gross_pnl += realized_pnl;
}

//+------------------------------------------------------------------+
string V2TelDoubleStr(const double val, const int digits = 5)
{
   if(MathAbs(val) < 1e-10)
      return "0.0";
   return DoubleToString(val, digits);
}

//+------------------------------------------------------------------+
string V2TelPriceOrNull(const double price)
{
   return (price > 0.0) ? V2TelDoubleStr(price, 5) : "null";
}

//+------------------------------------------------------------------+
string V2TelIsoUtc(const datetime when)
{
   MqlDateTime dt;
   TimeToStruct(when, dt);
   return StringFormat("%04d-%02d-%02dT%02d:%02d:%02dZ",
                       dt.year, dt.mon, dt.day, dt.hour, dt.min, dt.sec);
}

//+------------------------------------------------------------------+
string V2TelBrokerTradeDate(const datetime when)
{
   MqlDateTime dt;
   TimeToStruct(when, dt);
   return StringFormat("%04d-%02d-%02d", dt.year, dt.mon, dt.day);
}

//+------------------------------------------------------------------+
string V2BuildLayerDetailJSON(const V2TelLayerSnapshot &layers[],
                              const int layer_count)
{
   string json = "[";
   for(int i = 0; i < layer_count; i++) {
      if(i > 0)
         json += ",";
      json += StringFormat(
         "{"
         "\"layer_index\":%d,"
         "\"direction\":%d,"
         "\"entry_price\":%.5f,"
         "\"exit_price_fixed\":%.5f,"
         "\"lot_size\":%.2f,"
         "\"position_ticket\":%llu,"
         "\"has_exit_limit\":%s"
         "}",
         i,
         layers[i].direction,
         layers[i].entry_price,
         layers[i].exit_target,
         layers[i].lot_size,
         layers[i].position_ticket,
         (layers[i].exit_ticket > 0 ? "true" : "false")
      );
   }
   json += "]";
   return json;
}

//+------------------------------------------------------------------+
double V2ComputePodNetPnl(const V2TelLayerSnapshot &layers[],
                          const int layer_count)
{
   double net = 0.0;
   for(int i = 0; i < layer_count; i++) {
      if(layers[i].position_ticket == 0)
         continue;
      if(PositionSelectByTicket(layers[i].position_ticket))
         net += PositionGetDouble(POSITION_PROFIT);
   }
   return net;
}

//+------------------------------------------------------------------+
double V2ComputeDistanceToTargetPips(const string symbol,
                                     const V2TelLayerSnapshot &layers[],
                                     const int layer_count,
                                     const int direction)
{
   if(layer_count <= 0)
      return 0.0;

   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return 0.0;

   double exit_price = layers[0].exit_target;
   double reference  = (direction > 0)
                       ? SymbolInfoDouble(symbol, SYMBOL_ASK)
                       : SymbolInfoDouble(symbol, SYMBOL_BID);
   return MathAbs(exit_price - reference) / point / 10.0;
}

//+------------------------------------------------------------------+
string V2BuildPodJSON(const string symbol,
                      const V2TelLayerSnapshot &layers[],
                      const int layer_count,
                      const int direction)
{
   int    pod_layers = layer_count;
   double pod_pnl    = (layer_count > 0) ? V2ComputePodNetPnl(layers, layer_count) : 0.0;
   double pod_dist   = (layer_count > 0)
                       ? V2ComputeDistanceToTargetPips(symbol, layers, layer_count, direction)
                       : 0.0;
   string dist_str   = (layer_count == 0) ? "null" : V2TelDoubleStr(pod_dist, 1);
   string layers_json = V2BuildLayerDetailJSON(layers, layer_count);

   return StringFormat(
      "{"
      "\"layers\":%d,"
      "\"net_pnl\":%.2f,"
      "\"distance_to_target_pips\":%s,"
      "\"layer_detail\":%s,"
      "\"ldak_status\":\"n/a\","
      "\"ldak_size_mult\":1.0000,"
      "\"ldak_raw_vol\":0.000000"
      "}",
      pod_layers,
      pod_pnl,
      dist_str,
      layers_json
   );
}

//+------------------------------------------------------------------+
string V2BuildSystemAlertsJSON(string& alerts[])
{
   string json = "[";
   int n = ArraySize(alerts);
   for(int i = 0; i < n; i++) {
      if(i > 0)
         json += ",";
      json += StringFormat("\"%s\"", alerts[i]);
   }
   json += "]";
   return json;
}

//+------------------------------------------------------------------+
string V2BuildInstanceTelemetryPayload(const string instance_id,
                                       const string symbol,
                                       const V2TelLayerSnapshot &layers[],
                                       const int layer_count,
                                       const int direction,
                                       const double quote_spread,
                                       const datetime timestamp_utc,
                                       string& system_alerts[])
{
   string ts = V2TelIsoUtc(timestamp_utc);

   double balance     = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity      = AccountInfoDouble(ACCOUNT_EQUITY);
   double margin_used = AccountInfoDouble(ACCOUNT_MARGIN);
   double margin_lvl  = (margin_used > 0.0) ? (equity / margin_used) * 100.0 : 0.0;

   string pod_json = V2BuildPodJSON(symbol, layers, layer_count, direction);
   string pods_json = StringFormat("{\"%s\":%s}", symbol, pod_json);

   string market_json = StringFormat(
      "{\"%s\":{\"bid\":%.5f,\"ask\":%.5f}}",
      symbol,
      SymbolInfoDouble(symbol, SYMBOL_BID),
      SymbolInfoDouble(symbol, SYMBOL_ASK)
   );

   string alerts_json = V2BuildSystemAlertsJSON(system_alerts);
   int account_daily_api_count = V2_ApiCounterRead();
   bool account_daily_api_warning = V2_ApiCounterSoftWarnActive();

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
         "\"execution_mode\":\"V2_PASSIVE_GRID\","
         "\"quote_spread\":%.6f,"
         "\"daily_api_count\":0,"
         "\"account_daily_api_count\":%d,"
         "\"account_daily_api_limit\":%d,"
         "\"account_daily_api_soft_warn\":%d,"
         "\"account_daily_api_warning\":%s,"
         "\"ldak_vratios\":{},"
         "\"rollover_active\":false"
      "},"
      "\"active_pods\":%s,"
      "\"working_orders\":{},"
      "\"market_prices\":%s,"
      "\"cooldown_ldak\":{},"
      "\"bias_backstop_count\":0,"
      "\"system_alerts\":%s"
      "}",
      ts,
      instance_id,
      balance,
      equity,
      margin_lvl,
      quote_spread,
      account_daily_api_count,
      V2_DAILY_API_LIMIT,
      V2_DAILY_API_SOFT_WARN,
      (account_daily_api_warning ? "true" : "false"),
      pods_json,
      market_json,
      alerts_json
   );
}

//+------------------------------------------------------------------+
string V2BuildPodClosePayload(const string instance_id,
                              const string instrument,
                              const string direction,
                              const int layers_closed,
                              const double avg_entry_price,
                              const double exit_price,
                              const double hold_time_minutes,
                              const double gross_pnl,
                              const datetime close_time_utc,
                              const datetime close_time_local)
{
   string ts         = V2TelIsoUtc(close_time_utc);
   string trade_date = V2TelBrokerTradeDate(close_time_local);

   return StringFormat(
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
      ts,
      trade_date,
      instrument,
      direction,
      layers_closed,
      avg_entry_price,
      exit_price,
      hold_time_minutes,
      gross_pnl,
      instance_id
   );
}

//+------------------------------------------------------------------+
bool V2TelemetryWebPost(const string url,
                        const string api_key,
                        const string payload,
                        const bool verbose_log)
{
   if(url == "" || api_key == "")
      return false;

   string headers = "Content-Type: application/json\r\n"
                  + "Authorization: Bearer " + api_key + "\r\n";

   char post_data[];
   char result_data[];
   string result_headers;
   StringToCharArray(payload, post_data, 0, StringLen(payload));

   int http_status = WebRequest(
      "POST",
      url,
      headers,
      200,
      post_data,
      result_data,
      result_headers
   );

   if(verbose_log) {
      if(http_status == 200)
         Print("INFO: V2 telemetry POST ok url=", url);
      else
         Print("INFO: V2 telemetry dropped status=", http_status, " url=", url);
   }

   return (http_status == 200);
}

//+------------------------------------------------------------------+
string V2DerivePodClosedUrl(const string telemetry_url)
{
   int push_pos = StringFind(telemetry_url, "/push");
   if(push_pos >= 0)
      return StringSubstr(telemetry_url, 0, push_pos) + "/pod_closed";
   return telemetry_url + "/pod_closed";
}

//+------------------------------------------------------------------+
//| M5 bar hold from open→close (Python layer-depth TTR parity).      |
//+------------------------------------------------------------------+
double V2HoldTimeBarsM5(const datetime entry_time, const datetime exit_time)
{
   if(entry_time <= 0 || exit_time < entry_time)
      return 0.0;
   int bar_sec = PeriodSeconds(PERIOD_M5);
   if(bar_sec <= 0)
      bar_sec = 300;
   return (double)(exit_time - entry_time) / (double)bar_sec;
}

//+------------------------------------------------------------------+
string V2BuildScalpClosedPayload(const string instance_id,
                                 const string instrument,
                                 const string direction,
                                 const double entry_price,
                                 const double exit_price,
                                 const double hold_time_minutes,
                                 const double hold_time_bars,
                                 const double gross_pnl,
                                 const int layer_depth,
                                 const int stack_depth,
                                 const int open_depth,
                                 const datetime close_time_utc,
                                 const datetime close_time_local)
{
   string ts         = V2TelIsoUtc(close_time_utc);
   string trade_date = V2TelBrokerTradeDate(close_time_local);

   return StringFormat(
      "{"
      "\"event_type\":\"scalp_closed\","
      "\"close_time\":\"%s\","
      "\"trade_date\":\"%s\","
      "\"instrument\":\"%s\","
      "\"direction\":\"%s\","
      "\"entry_price\":%.5f,"
      "\"exit_price\":%.5f,"
      "\"hold_time_minutes\":%.1f,"
      "\"hold_time_bars\":%.2f,"
      "\"gross_pnl\":%.2f,"
      "\"layer_depth\":%d,"
      "\"stack_depth\":%d,"
      "\"open_depth\":%d,"
      "\"instance_id\":\"%s\""
      "}",
      ts,
      trade_date,
      instrument,
      direction,
      entry_price,
      exit_price,
      hold_time_minutes,
      hold_time_bars,
      gross_pnl,
      layer_depth,
      stack_depth,
      open_depth,
      instance_id
   );
}

//+------------------------------------------------------------------+
string V2DeriveScalpClosedUrl(const string telemetry_url)
{
   int push_pos = StringFind(telemetry_url, "/push");
   if(push_pos >= 0)
      return StringSubstr(telemetry_url, 0, push_pos) + "/scalp_closed";
   return telemetry_url + "/scalp_closed";
}

#endif // FXMATRIX_V2_TELEMETRY_MQH
