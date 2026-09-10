//+------------------------------------------------------------------+
//| grind_scalp_events.mqh — queued scalp_closed POSTs for pipshed    |
//+------------------------------------------------------------------+
#ifndef GRIND_SCALP_EVENTS_MQH
#define GRIND_SCALP_EVENTS_MQH

#define GRIND_SCALP_EVENT_QUEUE_MAX 64

string g_grind_scalp_event_queue[];
int    g_grind_scalp_event_queue_count = 0;

bool   g_grind_scalp_telemetry_enabled = false;
string g_grind_scalp_telemetry_url = "";
string g_grind_scalp_telemetry_api_key = "";
bool   g_grind_scalp_telemetry_verbose = false;

//+------------------------------------------------------------------+
void Grind_ScalpEventReset()
{
   ArrayResize(g_grind_scalp_event_queue, 0);
   g_grind_scalp_event_queue_count = 0;
}

//+------------------------------------------------------------------+
void Grind_ScalpTelemetryConfigure(const bool enabled,
                                   const string url,
                                   const string api_key,
                                   const bool verbose)
{
   g_grind_scalp_telemetry_enabled = enabled;
   g_grind_scalp_telemetry_url = url;
   g_grind_scalp_telemetry_api_key = api_key;
   g_grind_scalp_telemetry_verbose = verbose;
}

//+------------------------------------------------------------------+
string Grind_IsoUtc(const datetime when)
{
   MqlDateTime dt;
   TimeToStruct(when, dt);
   return StringFormat("%04d-%02d-%02dT%02d:%02d:%02dZ",
                       dt.year, dt.mon, dt.day, dt.hour, dt.min, dt.sec);
}

//+------------------------------------------------------------------+
string Grind_DeriveScalpClosedUrl(const string telemetry_url)
{
   const int push_pos = StringFind(telemetry_url, "/push");
   if(push_pos >= 0)
      return StringSubstr(telemetry_url, 0, push_pos) + "/scalp_closed";
   return telemetry_url + "/scalp_closed";
}

//+------------------------------------------------------------------+
string Grind_BuildScalpClosedPayload(const string instance_id,
                                     const string instrument,
                                     const string direction,
                                     const double entry_price,
                                     const double exit_price,
                                     const int layer_depth,
                                     const int stack_depth,
                                     const double gross_pnl,
                                     const datetime close_time)
{
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   return StringFormat(
      "{"
      "\"close_time\":\"%s\","
      "\"instrument\":\"%s\","
      "\"direction\":\"%s\","
      "\"entry_price\":%.5f,"
      "\"exit_price\":%.5f,"
      "\"layer_depth\":%d,"
      "\"stack_depth\":%d,"
      "\"gross_pnl\":%.2f,"
      "\"instance_id\":\"%s\""
      "}",
      Grind_IsoUtc(close_time),
      instrument,
      direction,
      NormalizeDouble(entry_price, digits),
      NormalizeDouble(exit_price, digits),
      layer_depth,
      stack_depth,
      gross_pnl,
      instance_id
   );
}

//+------------------------------------------------------------------+
void Grind_QueueScalpClosedEvent(const string instance_id,
                                 const string instrument,
                                 const string direction,
                                 const double entry_price,
                                 const double exit_price,
                                 const int layer_depth,
                                 const int stack_depth,
                                 const double gross_pnl,
                                 const datetime close_time)
{
   const string payload = Grind_BuildScalpClosedPayload(
      instance_id,
      instrument,
      direction,
      entry_price,
      exit_price,
      layer_depth,
      stack_depth,
      gross_pnl,
      close_time
   );

   if(g_grind_scalp_event_queue_count >= GRIND_SCALP_EVENT_QUEUE_MAX) {
      for(int i = 1; i < g_grind_scalp_event_queue_count; i++)
         g_grind_scalp_event_queue[i - 1] = g_grind_scalp_event_queue[i];
      g_grind_scalp_event_queue_count--;
   }

   ArrayResize(g_grind_scalp_event_queue, g_grind_scalp_event_queue_count + 1);
   g_grind_scalp_event_queue[g_grind_scalp_event_queue_count++] = payload;
}

//+------------------------------------------------------------------+
int Grind_ScalpEventQueueSize()
{
   return g_grind_scalp_event_queue_count;
}

//+------------------------------------------------------------------+
string Grind_ScalpEventQueuePeek()
{
   if(g_grind_scalp_event_queue_count <= 0)
      return "";
   return g_grind_scalp_event_queue[0];
}

//+------------------------------------------------------------------+
void Grind_DrainScalpEventQueue()
{
   if(!g_grind_scalp_telemetry_enabled)
      return;
   if(g_grind_scalp_telemetry_url == "" || g_grind_scalp_telemetry_api_key == "")
      return;

   const string url = Grind_DeriveScalpClosedUrl(g_grind_scalp_telemetry_url);
   while(g_grind_scalp_event_queue_count > 0) {
      const string payload = g_grind_scalp_event_queue[0];
      for(int i = 1; i < g_grind_scalp_event_queue_count; i++)
         g_grind_scalp_event_queue[i - 1] = g_grind_scalp_event_queue[i];
      g_grind_scalp_event_queue_count--;
      ArrayResize(g_grind_scalp_event_queue, g_grind_scalp_event_queue_count);

      Grind_TelemetryWebPost(url,
                             g_grind_scalp_telemetry_api_key,
                             payload,
                             g_grind_scalp_telemetry_verbose);
   }
}

#endif // GRIND_SCALP_EVENTS_MQH
