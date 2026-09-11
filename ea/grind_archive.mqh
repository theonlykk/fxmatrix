//+------------------------------------------------------------------+
//| grind_archive.mqh — archive event queue, clock, JSON helpers     |
//+------------------------------------------------------------------+
#ifndef GRIND_ARCHIVE_MQH
#define GRIND_ARCHIVE_MQH

#include "grind_comment.mqh"

bool   g_grind_archive_enabled = false;
string g_grind_archive_action_url = "";
string g_grind_archive_api_key = "";
string g_grind_archive_instance_id = "";
ulong  g_grind_archive_magic = 0;
string g_grind_archive_session_id = "";
long   g_grind_archive_anchor_ms = 0;
ulong  g_grind_archive_anchor_tick = 0;
int    g_grind_archive_seq = 0;
string g_grind_archive_queue[];
int    g_grind_archive_queue_max = 5000;
int    g_grind_archive_dropped = 0;
int    g_grind_archive_rejected = 0;
long   g_grind_archive_last_flush_ms = 0;
bool   g_grind_archive_verbose = false;

bool   g_grind_archive_test_tick_active = false;
ulong  g_grind_archive_test_tick = 0;

//+------------------------------------------------------------------+
void Grind_ArchiveTestReset()
{
   g_grind_archive_enabled = false;
   g_grind_archive_action_url = "";
   g_grind_archive_api_key = "";
   g_grind_archive_instance_id = "";
   g_grind_archive_magic = 0;
   g_grind_archive_session_id = "";
   g_grind_archive_anchor_ms = 0;
   g_grind_archive_anchor_tick = 0;
   g_grind_archive_seq = 0;
   ArrayResize(g_grind_archive_queue, 0);
   g_grind_archive_queue_max = 5000;
   g_grind_archive_dropped = 0;
   g_grind_archive_rejected = 0;
   g_grind_archive_last_flush_ms = 0;
   g_grind_archive_verbose = false;
   g_grind_archive_test_tick_active = false;
   g_grind_archive_test_tick = 0;
}

//+------------------------------------------------------------------+
void Grind_ArchiveConfigureAt(const bool enabled,
                              const string telemetry_url,
                              const string api_key,
                              const string instance,
                              const ulong magic,
                              const long anchor_ms,
                              const ulong anchor_tick,
                              const bool verbose)
{
   g_grind_archive_enabled = enabled;
   g_grind_archive_api_key = api_key;
   g_grind_archive_instance_id = instance;
   g_grind_archive_magic = magic;
   g_grind_archive_anchor_ms = anchor_ms;
   g_grind_archive_anchor_tick = anchor_tick;
   g_grind_archive_verbose = verbose;
   g_grind_archive_seq = 0;
   ArrayResize(g_grind_archive_queue, 0);
   g_grind_archive_dropped = 0;
   g_grind_archive_rejected = 0;
   g_grind_archive_last_flush_ms = 0;

   string action_url = telemetry_url;
   const int push_pos = StringFind(action_url, "/push");
   if(push_pos >= 0)
      action_url = StringSubstr(action_url, 0, push_pos) + "/action";
   else if(StringFind(action_url, "/action") < 0)
      action_url = action_url + "/action";
   g_grind_archive_action_url = action_url;

   g_grind_archive_session_id = IntegerToString((long)magic) + "-" +
                                IntegerToString(anchor_ms);
}

//+------------------------------------------------------------------+
void Grind_ArchiveConfigure(const bool enabled,
                            const string telemetry_url,
                            const string api_key,
                            const string instance,
                            const ulong magic,
                            const bool verbose)
{
   Grind_ArchiveConfigureAt(enabled,
                            telemetry_url,
                            api_key,
                            instance,
                            magic,
                            (long)((ulong)TimeGMT() * 1000),
                            GetTickCount64(),
                            verbose);
}

//+------------------------------------------------------------------+
ulong Grind_ArchiveTick()
{
   if(g_grind_archive_test_tick_active)
      return g_grind_archive_test_tick;
   return GetTickCount64();
}

//+------------------------------------------------------------------+
long Grind_ArchiveNowMs()
{
   const ulong tick = Grind_ArchiveTick();
   if(tick >= g_grind_archive_anchor_tick)
      return g_grind_archive_anchor_ms + (long)(tick - g_grind_archive_anchor_tick);
   return g_grind_archive_anchor_ms;
}

//+------------------------------------------------------------------+
string Grind_ArchiveBrokerTime(const datetime broker_now)
{
   return "";
}

//+------------------------------------------------------------------+
string Grind_JsonEscape(const string text)
{
   return "";
}

//+------------------------------------------------------------------+
string Grind_ArchiveJsonDouble(const double value, const int digits)
{
   return "null";
}

//+------------------------------------------------------------------+
string Grind_ArchiveJsonBool(const bool value)
{
   return "false";
}

//+------------------------------------------------------------------+
string Grind_ArchiveJsonUlong(const ulong value)
{
   return "null";
}

//+------------------------------------------------------------------+
string Grind_ArchiveJsonLong(const long value)
{
   return "null";
}

//+------------------------------------------------------------------+
string Grind_ArchiveJsonStringOrNull(const string value)
{
   return "null";
}

//+------------------------------------------------------------------+
void Grind_ArchiveEnqueue(const string event_type, const string fields_json)
{
   return;
}

//+------------------------------------------------------------------+
int Grind_ArchiveQueueCount()
{
   return ArraySize(g_grind_archive_queue);
}

//+------------------------------------------------------------------+
string Grind_ArchiveQueuePeek(const int index)
{
   if(index < 0 || index >= ArraySize(g_grind_archive_queue))
      return "";
   return g_grind_archive_queue[index];
}

//+------------------------------------------------------------------+
int Grind_ArchiveDropped()
{
   return g_grind_archive_dropped;
}

//+------------------------------------------------------------------+
int Grind_ArchiveRejected()
{
   return g_grind_archive_rejected;
}

//+------------------------------------------------------------------+
string Grind_ArchiveSendLogFields(MqlTradeRequest &req,
                                  MqlTradeResult &res,
                                  const bool ok,
                                  const long duration_ms,
                                  const datetime broker_now,
                                  const ulong fallback_magic)
{
   return "";
}

//+------------------------------------------------------------------+
string Grind_ArchiveFillLogFields(const ulong deal,
                                  const ulong order,
                                  const ulong position_id,
                                  const string entry_type,
                                  const string deal_type,
                                  const string comment,
                                  const double deal_price,
                                  const double order_price_open,
                                  const double volume,
                                  const double profit,
                                  const double swap,
                                  const double commission,
                                  const datetime deal_time,
                                  const long deal_time_msc,
                                  const bool halted,
                                  const bool quarantined,
                                  const double point,
                                  const ulong magic)
{
   return "";
}

//+------------------------------------------------------------------+
string Grind_ArchiveConfigFields(const string event,
                                 const int deinit_reason,
                                 const string symbol,
                                 const string slot,
                                 const string ea_build,
                                 const long account_login,
                                 const double width_pips,
                                 const double add_pips,
                                 const double exit_pips,
                                 const int max_layers,
                                 const double lots,
                                 const double deadband_pips,
                                 const double stranded_thresh_pips,
                                 const string cap_leg_a,
                                 const string cap_leg_b,
                                 const double cap_leg_a_thresh,
                                 const double cap_leg_b_thresh,
                                 const string telemetry_instance,
                                 const bool verbose_log,
                                 const string config_warning,
                                 const bool enable_telemetry,
                                 const int telemetry_interval_sec)
{
   return "";
}

//+------------------------------------------------------------------+
string Grind_ArchiveEaEventFields(const string level,
                                  const string code,
                                  const string reason,
                                  const ulong ticket,
                                  const string detail_json)
{
   return "";
}

//+------------------------------------------------------------------+
bool Grind_TimerTelemetryDue(const ulong now_tick,
                             const ulong last_tick,
                             const int interval_sec)
{
   return false;
}

#endif // GRIND_ARCHIVE_MQH
