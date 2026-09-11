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
   g_grind_archive_enabled = enabled && telemetry_url != "" && api_key != "";
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
   MqlDateTime dt;
   TimeToStruct(broker_now, dt);
   return StringFormat("%04d-%02d-%02d %02d:%02d:%02d",
                       dt.year, dt.mon, dt.day, dt.hour, dt.min, dt.sec);
}

//+------------------------------------------------------------------+
string Grind_JsonEscapeChar(const ushort ch)
{
   if(ch == '\\')
      return "\\\\";
   if(ch == '"')
      return "\\\"";
   if(ch == '\n')
      return "\\n";
   if(ch == '\r')
      return "\\r";
   if(ch == '\t')
      return "\\t";
   if(ch < 32) {
      return StringFormat("\\u%04X", (int)ch);
   }
   return ShortToString(ch);
}

//+------------------------------------------------------------------+
string Grind_JsonEscape(const string text)
{
   string out = "";
   const int n = StringLen(text);
   for(int i = 0; i < n; i++) {
      out += Grind_JsonEscapeChar(StringGetCharacter(text, i));
   }
   return out;
}

//+------------------------------------------------------------------+
string Grind_ArchiveJsonDouble(const double value, const int digits)
{
   if(!MathIsValidNumber(value))
      return "null";
   return DoubleToString(value, digits);
}

//+------------------------------------------------------------------+
string Grind_ArchiveJsonBool(const bool value)
{
   return value ? "true" : "false";
}

//+------------------------------------------------------------------+
string Grind_ArchiveJsonUlong(const ulong value)
{
   if(value == 0)
      return "null";
   return IntegerToString((long)value);
}

//+------------------------------------------------------------------+
string Grind_ArchiveJsonLong(const long value)
{
   return IntegerToString(value);
}

//+------------------------------------------------------------------+
string Grind_ArchiveJsonStringOrNull(const string value)
{
   if(value == "")
      return "null";
   return "\"" + Grind_JsonEscape(value) + "\"";
}

//+------------------------------------------------------------------+
string Grind_ArchiveSendActionLabel(const ENUM_TRADE_REQUEST_ACTIONS action)
{
   if(action == TRADE_ACTION_PENDING)
      return "PENDING";
   if(action == TRADE_ACTION_MODIFY)
      return "MODIFY";
   if(action == TRADE_ACTION_REMOVE)
      return "REMOVE";
   if(action == TRADE_ACTION_CLOSE_BY)
      return "CLOSE_BY";
   if(action == TRADE_ACTION_DEAL)
      return "DEAL";
   return IntegerToString((int)action);
}

//+------------------------------------------------------------------+
string Grind_ArchiveEntryTypeLabel(const long entry_type)
{
   if(entry_type == DEAL_ENTRY_IN)
      return "IN";
   if(entry_type == DEAL_ENTRY_OUT)
      return "OUT";
   if(entry_type == DEAL_ENTRY_OUT_BY)
      return "OUT_BY";
   if(entry_type == DEAL_ENTRY_INOUT)
      return "INOUT";
   return IntegerToString((int)entry_type);
}

//+------------------------------------------------------------------+
string Grind_ArchiveDealTypeLabel(const long deal_type)
{
   if(deal_type == DEAL_TYPE_BUY)
      return "BUY";
   if(deal_type == DEAL_TYPE_SELL)
      return "SELL";
   return IntegerToString((int)deal_type);
}

//+------------------------------------------------------------------+
void Grind_ArchiveQueueRemoveFront(const int count)
{
   const int total = ArraySize(g_grind_archive_queue);
   if(count <= 0 || total <= 0)
      return;
   const int remove_n = MathMin(count, total);
   for(int i = 0; i < total - remove_n; i++)
      g_grind_archive_queue[i] = g_grind_archive_queue[i + remove_n];
   ArrayResize(g_grind_archive_queue, total - remove_n);
}

//+------------------------------------------------------------------+
void Grind_ArchiveEnqueue(const string event_type, const string fields_json)
{
   if(!g_grind_archive_enabled)
      return;

   string event = "{\"type\":\"" + event_type + "\",\"seq\":" +
                  IntegerToString(g_grind_archive_seq) + ",\"ea_time_ms\":" +
                  IntegerToString(Grind_ArchiveNowMs());
   if(fields_json != "")
      event += "," + fields_json;
   event += "}";

   g_grind_archive_seq++;

   const int count = ArraySize(g_grind_archive_queue);
   if(count >= g_grind_archive_queue_max) {
      Grind_ArchiveQueueRemoveFront(1);
      g_grind_archive_dropped++;
   }
   ArrayResize(g_grind_archive_queue, ArraySize(g_grind_archive_queue) + 1);
   g_grind_archive_queue[ArraySize(g_grind_archive_queue) - 1] = event;
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
   string slot = "null";
   string side = "null";
   string role = "null";
   string layer_index = "null";
   string c_slot, c_side, c_role;
   int c_layer;
   if(GrindCommentParse(req.comment, c_slot, c_side, c_layer, c_role)) {
      slot = "\"" + Grind_JsonEscape(c_slot) + "\"";
      side = "\"" + Grind_JsonEscape(c_side) + "\"";
      role = "\"" + Grind_JsonEscape(c_role) + "\"";
      layer_index = IntegerToString(c_layer);
   }

   string order_type = "null";
   if(req.action == TRADE_ACTION_PENDING || req.action == TRADE_ACTION_DEAL)
      order_type = Grind_ArchiveJsonStringOrNull(EnumToString(req.type));

   const ulong magic_val = (req.magic > 0 ? req.magic : fallback_magic);

   return "\"magic\":" + IntegerToString((long)magic_val) +
          ",\"action\":\"" + Grind_ArchiveSendActionLabel(req.action) + "\"" +
          ",\"order_type\":" + order_type +
          ",\"side\":" + side +
          ",\"layer_index\":" + layer_index +
          ",\"role\":" + role +
          ",\"requested_price\":" + (req.price > 0 ? Grind_ArchiveJsonDouble(req.price, 5) : "null") +
          ",\"volume\":" + (req.volume > 0 ? Grind_ArchiveJsonDouble(req.volume, 2) : "null") +
          ",\"order_ticket\":" + Grind_ArchiveJsonUlong(req.order) +
          ",\"position_ticket\":" + Grind_ArchiveJsonUlong(req.position) +
          ",\"position_by_ticket\":" + Grind_ArchiveJsonUlong(req.position_by) +
          ",\"comment\":" + Grind_ArchiveJsonStringOrNull(req.comment) +
          ",\"ok\":" + Grind_ArchiveJsonBool(ok) +
          ",\"retcode\":" + IntegerToString((int)res.retcode) +
          ",\"result_order\":" + Grind_ArchiveJsonUlong(res.order) +
          ",\"result_deal\":" + Grind_ArchiveJsonUlong(res.deal) +
          ",\"duration_ms\":" + IntegerToString((int)duration_ms) +
          ",\"broker_time\":" + Grind_ArchiveJsonStringOrNull(Grind_ArchiveBrokerTime(broker_now));
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
   string slot = "null";
   string side = "null";
   string role = "null";
   string layer_index = "null";
   string c_slot, c_side, c_role;
   int c_layer;
   if(GrindCommentParse(comment, c_slot, c_side, c_layer, c_role)) {
      slot = "\"" + Grind_JsonEscape(c_slot) + "\"";
      side = "\"" + Grind_JsonEscape(c_side) + "\"";
      role = "\"" + Grind_JsonEscape(c_role) + "\"";
      layer_index = IntegerToString(c_layer);
   }

   string slippage = "null";
   if(entry_type == "IN" && order_price_open > 0.0 && point > 0.0 &&
      (deal_type == "BUY" || deal_type == "SELL")) {
      double raw = 0.0;
      if(deal_type == "BUY")
         raw = (order_price_open - deal_price) / (point * 10.0);
      else
         raw = (deal_price - order_price_open) / (point * 10.0);
      slippage = Grind_ArchiveJsonDouble(raw, 1);
   }

   return "\"magic\":" + IntegerToString((long)magic) +
          ",\"deal_ticket\":" + IntegerToString((long)deal) +
          ",\"order_ticket\":" + Grind_ArchiveJsonUlong(order) +
          ",\"position_id\":" + Grind_ArchiveJsonUlong(position_id) +
          ",\"entry_type\":" + Grind_ArchiveJsonStringOrNull(entry_type) +
          ",\"deal_type\":" + Grind_ArchiveJsonStringOrNull(deal_type) +
          ",\"side\":" + side +
          ",\"layer_index\":" + layer_index +
          ",\"role\":" + role +
          ",\"deal_price\":" + Grind_ArchiveJsonDouble(deal_price, 5) +
          ",\"order_price_open\":" + Grind_ArchiveJsonDouble(order_price_open > 0 ? order_price_open : 0.0, 5) +
          ",\"slippage_pips\":" + slippage +
          ",\"volume\":" + Grind_ArchiveJsonDouble(volume > 0 ? volume : 0.0, 2) +
          ",\"profit\":" + Grind_ArchiveJsonDouble(profit, 2) +
          ",\"swap\":" + Grind_ArchiveJsonDouble(swap, 2) +
          ",\"commission\":" + Grind_ArchiveJsonDouble(commission, 2) +
          ",\"deal_time_broker\":" + Grind_ArchiveJsonStringOrNull(Grind_ArchiveBrokerTime(deal_time)) +
          ",\"deal_time_broker_msc\":" + (deal_time_msc > 0 ? IntegerToString(deal_time_msc) : "null") +
          ",\"halted_at_receipt\":" + Grind_ArchiveJsonBool(halted) +
          ",\"quarantined_at_receipt\":" + Grind_ArchiveJsonBool(quarantined);
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
   string deinit = "null";
   if(deinit_reason != 0)
      deinit = IntegerToString(deinit_reason);

   return "\"magic\":" + Grind_ArchiveJsonUlong(g_grind_archive_magic) +
          ",\"event\":" + Grind_ArchiveJsonStringOrNull(event) +
          ",\"deinit_reason\":" + deinit +
          ",\"symbol\":" + Grind_ArchiveJsonStringOrNull(symbol) +
          ",\"slot\":" + Grind_ArchiveJsonStringOrNull(slot) +
          ",\"ea_build\":" + Grind_ArchiveJsonStringOrNull(ea_build) +
          ",\"account_login\":" + (account_login > 0 ? IntegerToString(account_login) : "null") +
          ",\"width_pips\":" + Grind_ArchiveJsonDouble(width_pips, 4) +
          ",\"add_pips\":" + Grind_ArchiveJsonDouble(add_pips, 4) +
          ",\"exit_pips\":" + Grind_ArchiveJsonDouble(exit_pips, 4) +
          ",\"max_layers\":" + IntegerToString(max_layers) +
          ",\"lots\":" + Grind_ArchiveJsonDouble(lots, 2) +
          ",\"deadband_pips\":" + Grind_ArchiveJsonDouble(deadband_pips, 4) +
          ",\"stranded_thresh_pips\":" + Grind_ArchiveJsonDouble(stranded_thresh_pips, 4) +
          ",\"cap_leg_a\":" + Grind_ArchiveJsonStringOrNull(cap_leg_a) +
          ",\"cap_leg_b\":" + Grind_ArchiveJsonStringOrNull(cap_leg_b) +
          ",\"cap_leg_a_thresh\":" + Grind_ArchiveJsonDouble(cap_leg_a_thresh, 4) +
          ",\"cap_leg_b_thresh\":" + Grind_ArchiveJsonDouble(cap_leg_b_thresh, 4) +
          ",\"telemetry_instance\":" + Grind_ArchiveJsonStringOrNull(telemetry_instance) +
          ",\"verbose_log\":" + Grind_ArchiveJsonBool(verbose_log) +
          ",\"config_warning\":" + Grind_ArchiveJsonStringOrNull(config_warning) +
          ",\"enable_telemetry\":" + Grind_ArchiveJsonBool(enable_telemetry) +
          ",\"telemetry_interval_sec\":" + IntegerToString(telemetry_interval_sec);
}

//+------------------------------------------------------------------+
string Grind_ArchiveEaEventFields(const string level,
                                  const string code,
                                  const string reason,
                                  const ulong ticket,
                                  const string detail_json)
{
   string detail = "null";
   if(detail_json != "")
      detail = detail_json;

   return "\"magic\":" + Grind_ArchiveJsonUlong(g_grind_archive_magic) +
          ",\"level\":" + Grind_ArchiveJsonStringOrNull(level) +
          ",\"code\":" + Grind_ArchiveJsonStringOrNull(code) +
          ",\"reason\":" + Grind_ArchiveJsonStringOrNull(reason) +
          ",\"ticket\":" + Grind_ArchiveJsonUlong(ticket) +
          ",\"detail\":" + detail;
}

//+------------------------------------------------------------------+
void Grind_ArchiveMarker(const string level,
                         const string code,
                         const string reason,
                         const ulong ticket,
                         const string detail_json)
{
   const string fields = Grind_ArchiveEaEventFields(level, code, reason, ticket, detail_json);
   Grind_ArchiveEnqueue("ea_event", fields);
}

//+------------------------------------------------------------------+
void Grind_ArchiveRecordDeinit(const ulong magic,
                               const int reason,
                               const datetime broker_now,
                               const long anchor_ms)
{
}

//+------------------------------------------------------------------+
bool Grind_ArchiveReadPendingDeinit(const ulong magic,
                                    int &reason,
                                    datetime &broker_time,
                                    long &anchor_ms)
{
   return false;
}

//+------------------------------------------------------------------+
void Grind_ArchiveClearPendingDeinit(const ulong magic)
{
}

//+------------------------------------------------------------------+
string Grind_ArchiveDeinitExtraFields(const datetime broker_time,
                                      const ulong magic,
                                      const long anchor_ms)
{
   return "";
}

//+------------------------------------------------------------------+
bool Grind_TimerTelemetryDue(const ulong now_tick,
                             const ulong last_tick,
                             const int interval_sec)
{
   if(last_tick == 0)
      return true;
   return (now_tick >= last_tick + (ulong)interval_sec * 1000);
}

#endif // GRIND_ARCHIVE_MQH
