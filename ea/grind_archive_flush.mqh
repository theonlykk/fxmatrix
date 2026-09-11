//+------------------------------------------------------------------+
//| grind_archive_flush.mqh — archive queue HTTP flush               |
//+------------------------------------------------------------------+
#ifndef GRIND_ARCHIVE_FLUSH_MQH
#define GRIND_ARCHIVE_FLUSH_MQH

#include "grind_archive.mqh"

//+------------------------------------------------------------------+
void Grind_ArchiveFlush(const bool force)
{
   if(!g_grind_archive_enabled)
      return;

   if(g_grind_archive_dropped > 0) {
      const string dropped_detail = "{\"dropped\":" +
                                    IntegerToString(g_grind_archive_dropped) + "}";
      const string dropped_fields = Grind_ArchiveEaEventFields(
         "WARN", "TELEMETRY_QUEUE_DROPPED", "", 0, dropped_detail);
      Grind_ArchiveEnqueue("ea_event", dropped_fields);
      g_grind_archive_dropped = 0;
   }

   if(g_grind_archive_rejected > 0) {
      const string rejected_detail = "{\"rejected\":" +
                                     IntegerToString(g_grind_archive_rejected) +
                                     ",\"types\":\"" +
                                     Grind_JsonEscape(g_grind_archive_rejected_types) + "\"}";
      const string rejected_fields = Grind_ArchiveEaEventFields(
         "ERROR", "TELEMETRY_BATCH_REJECTED", "", 0, rejected_detail);
      Grind_ArchiveEnqueue("ea_event", rejected_fields);
      g_grind_archive_rejected = 0;
      g_grind_archive_rejected_types = "";
   }

   const int count = Grind_ArchiveQueueCount();
   if(count <= 0)
      return;

   const long now_ms = Grind_ArchiveNowMs();
   if(!force && g_grind_archive_last_flush_ms != 0 &&
      now_ms - g_grind_archive_last_flush_ms < 2000)
      return;

   const int batch = MathMin(200, count);
   string events_json = "[";
   for(int i = 0; i < batch; i++) {
      if(i > 0)
         events_json += ",";
      events_json += g_grind_archive_queue[i];
   }
   events_json += "]";

   const string payload = "{\"instance_id\":\"" +
                          Grind_JsonEscape(g_grind_archive_instance_id) +
                          "\",\"session_id\":\"" +
                          Grind_JsonEscape(g_grind_archive_session_id) +
                          "\",\"events\":" + events_json + "}";

   g_grind_archive_last_flush_ms = now_ms;

   const int status = Grind_TelemetryWebPostStatus(g_grind_archive_action_url,
                                                   g_grind_archive_api_key,
                                                   payload,
                                                   g_grind_archive_verbose);

   if(status == 200) {
      Grind_ArchiveQueueRemoveFront(batch);
      return;
   }

   if(status == 400) {
      for(int i = 0; i < batch; i++)
         Grind_ArchiveAppendRejectedType(g_grind_archive_queue[i]);
      Grind_ArchiveQueueRemoveFront(batch);
      g_grind_archive_rejected += batch;
      Print("ERROR: archive batch rejected by server count=", batch,
            " status=400");
      return;
   }
}

#endif // GRIND_ARCHIVE_FLUSH_MQH
