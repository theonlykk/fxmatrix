//+------------------------------------------------------------------+
//| grind_heartbeat_detail.mqh — per-layer price detail for heartbeat  |
//| Included from grind_engine.mqh after order-test hooks are defined. |
//+------------------------------------------------------------------+
#ifndef GRIND_HEARTBEAT_DETAIL_MQH
#define GRIND_HEARTBEAT_DETAIL_MQH

#include "grind_state.mqh"
#include "grind_comment.mqh"
#include "grind_pure.mqh"

// Unit-test hooks for position comment reads (no PositionSelectByTicket when active).
bool   g_grind_heartbeat_test_active = false;

struct GrindHeartbeatTestPosition
{
   ulong  ticket;
   long   magic;
   string comment;
};

GrindHeartbeatTestPosition g_grind_heartbeat_test_positions[];
int g_grind_heartbeat_test_position_count = 0;

//+------------------------------------------------------------------+
void Grind_HeartbeatTestReset()
{
   g_grind_heartbeat_test_active = false;
   ArrayResize(g_grind_heartbeat_test_positions, 0);
   g_grind_heartbeat_test_position_count = 0;
}

//+------------------------------------------------------------------+
void Grind_HeartbeatTestUpsertPosition(const ulong ticket,
                                       const long magic,
                                       const string comment)
{
   for(int i = 0; i < g_grind_heartbeat_test_position_count; i++) {
      if(g_grind_heartbeat_test_positions[i].ticket == ticket) {
         g_grind_heartbeat_test_positions[i].magic = magic;
         g_grind_heartbeat_test_positions[i].comment = comment;
         return;
      }
   }
   ArrayResize(g_grind_heartbeat_test_positions, g_grind_heartbeat_test_position_count + 1);
   g_grind_heartbeat_test_positions[g_grind_heartbeat_test_position_count].ticket = ticket;
   g_grind_heartbeat_test_positions[g_grind_heartbeat_test_position_count].magic = magic;
   g_grind_heartbeat_test_positions[g_grind_heartbeat_test_position_count].comment = comment;
   g_grind_heartbeat_test_position_count++;
}

//+------------------------------------------------------------------+
string Grind_HeartbeatJsonEscape(const string raw)
{
   string out = "";
   for(int i = 0; i < StringLen(raw); i++) {
      const ushort ch = StringGetCharacter(raw, i);
      if(ch == '\\')
         out += "\\\\";
      else if(ch == '"')
         out += "\\\"";
      else
         out += ShortToString(ch);
   }
   return out;
}

//+------------------------------------------------------------------+
string Grind_HeartbeatQuotedCommentJson(const string comment)
{
   return "\"" + Grind_HeartbeatJsonEscape(comment) + "\"";
}

//+------------------------------------------------------------------+
bool Grind_HeartbeatPositionComment(const ulong position_ticket,
                                    const ulong magic,
                                    string &comment_out)
{
   comment_out = "";
   if(position_ticket == 0)
      return false;

   if(g_grind_heartbeat_test_active) {
      for(int i = 0; i < g_grind_heartbeat_test_position_count; i++) {
         if(g_grind_heartbeat_test_positions[i].ticket != position_ticket)
            continue;
         if(!Grind_MagicMatches(g_grind_heartbeat_test_positions[i].magic, magic))
            return false;
         comment_out = g_grind_heartbeat_test_positions[i].comment;
         return true;
      }
      return false;
   }

   if(!PositionSelectByTicket(position_ticket))
      return false;
   if(!Grind_MagicMatches(PositionGetInteger(POSITION_MAGIC), magic))
      return false;
   comment_out = PositionGetString(POSITION_COMMENT);
   return true;
}

//+------------------------------------------------------------------+
bool Grind_HeartbeatOrderComment(const ulong ticket,
                                 const ulong magic,
                                 string &comment_out)
{
   comment_out = "";
   if(ticket == 0)
      return false;

   if(g_grind_order_test_active) {
      GrindOrderTestRecord rec;
      if(!Grind_OrderTestFind(ticket, rec))
         return false;
      if(!Grind_MagicMatches(rec.magic, magic))
         return false;
      comment_out = rec.comment;
      return true;
   }

   if(!OrderSelect(ticket))
      return false;
   if(!Grind_MagicMatches(OrderGetInteger(ORDER_MAGIC), magic))
      return false;
   comment_out = OrderGetString(ORDER_COMMENT);
   return true;
}

//+------------------------------------------------------------------+
string Grind_HeartbeatNullableCommentJson(const ulong ticket,
                                          const ulong magic)
{
   string comment = "";
   if(!Grind_HeartbeatOrderComment(ticket, magic, comment))
      return "null";
   return Grind_HeartbeatQuotedCommentJson(comment);
}

//+------------------------------------------------------------------+
bool Grind_HeartbeatOrderPrice(const ulong ticket,
                               const ulong magic,
                               double &price_out)
{
   price_out = 0.0;
   if(ticket == 0)
      return false;

   if(g_grind_order_test_active) {
      GrindOrderTestRecord rec;
      if(!Grind_OrderTestFind(ticket, rec))
         return false;
      if(!Grind_MagicMatches(rec.magic, magic))
         return false;
      price_out = rec.price;
      return true;
   }

   if(!OrderSelect(ticket))
      return false;
   if(!Grind_MagicMatches(OrderGetInteger(ORDER_MAGIC), magic))
      return false;
   price_out = OrderGetDouble(ORDER_PRICE_OPEN);
   return true;
}

//+------------------------------------------------------------------+
string Grind_HeartbeatNullablePriceJson(const ulong ticket,
                                        const ulong magic,
                                        const int digits)
{
   double price = 0.0;
   if(!Grind_HeartbeatOrderPrice(ticket, magic, price))
      return "null";
   return DoubleToString(price, digits);
}

//+------------------------------------------------------------------+
int Grind_HeartbeatCountRestingEntries(const ulong magic,
                                       const string side_letter)
{
   int count = 0;

   if(g_grind_order_test_active) {
      for(int i = 0; i < g_grind_order_test_count; i++) {
         const GrindOrderTestRecord rec = g_grind_order_test_records[i];
         if(!Grind_MagicMatches(rec.magic, magic))
            continue;

         string slot = "";
         string side = "";
         string role = "";
         int layer_index = -1;
         if(!GrindCommentParse(rec.comment, slot, side, layer_index, role))
            continue;
         if(role != "ENT" || side != side_letter)
            continue;
         count++;
      }
      return count;
   }

   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if(!Grind_MagicMatches(OrderGetInteger(ORDER_MAGIC), magic))
         continue;

      string slot = "";
      string side = "";
      string role = "";
      int layer_index = -1;
      if(!GrindCommentParse(OrderGetString(ORDER_COMMENT), slot, side, layer_index, role))
         continue;
      if(role != "ENT" || side != side_letter)
         continue;
      count++;
   }

   return count;
}

//+------------------------------------------------------------------+
string Grind_HeartbeatLayersJson(const ulong magic, const int digits)
{
   string json = "[";
   bool first = true;

   for(int side_idx = 0; side_idx < 2; side_idx++) {
      const GrindSideState side = (side_idx == 0 ? g_grind_long : g_grind_short);
      const string side_letter = (side_idx == 0 ? "L" : "S");

      for(int i = 0; i < ArraySize(side.layers); i++) {
         const GrindLayer layer = side.layers[i];
         if(!first)
            json += ",";
         first = false;

         string comment_json = "null";
         string broker_comment = "";
         if(Grind_HeartbeatPositionComment(layer.position_ticket, magic, broker_comment))
            comment_json = Grind_HeartbeatQuotedCommentJson(broker_comment);

         json += StringFormat(
            "{\"layer_index\":%d,\"side\":\"%s\","
            "\"entry_price\":%s,\"exit_target\":%s,"
            "\"has_exit_order\":%s,\"has_exit_position\":%s,"
            "\"comment\":%s}",
            layer.layer_index,
            side_letter,
            DoubleToString(layer.entry_price, digits),
            DoubleToString(layer.exit_target, digits),
            (layer.exit_order_ticket != 0 ? "true" : "false"),
            (layer.exit_position_ticket != 0 ? "true" : "false"),
            comment_json
         );
      }
   }

   json += "]";
   return json;
}

#include "grind_heartbeat_book.mqh"

//+------------------------------------------------------------------+
string Grind_HeartbeatBuildLayerDetailJson(const ulong magic, const int digits)
{
   return StringFormat(
      "\"layers\":%s,"
      "\"l0_pending_long\":%s,\"l0_pending_long_comment\":%s,"
      "\"l0_pending_short\":%s,\"l0_pending_short_comment\":%s,"
      "\"add_pending_long\":%s,\"add_pending_long_comment\":%s,"
      "\"add_pending_short\":%s,\"add_pending_short_comment\":%s,"
      "\"resting_entries_long\":%d,\"resting_entries_short\":%d",
      Grind_HeartbeatLayersJson(magic, digits),
      Grind_HeartbeatNullablePriceJson(g_grind_long.l0_pending_ticket, magic, digits),
      Grind_HeartbeatNullableCommentJson(g_grind_long.l0_pending_ticket, magic),
      Grind_HeartbeatNullablePriceJson(g_grind_short.l0_pending_ticket, magic, digits),
      Grind_HeartbeatNullableCommentJson(g_grind_short.l0_pending_ticket, magic),
      Grind_HeartbeatNullablePriceJson(g_grind_long.add_pending_ticket, magic, digits),
      Grind_HeartbeatNullableCommentJson(g_grind_long.add_pending_ticket, magic),
      Grind_HeartbeatNullablePriceJson(g_grind_short.add_pending_ticket, magic, digits),
      Grind_HeartbeatNullableCommentJson(g_grind_short.add_pending_ticket, magic),
      Grind_HeartbeatCountRestingEntries(magic, "L"),
      Grind_HeartbeatCountRestingEntries(magic, "S")
   );
}

//+------------------------------------------------------------------+
void Grind_HeartbeatMeasureWorstCasePayload(const int max_layers_cap,
                                            const int digits,
                                            const ulong magic,
                                            int &detail_chars_out,
                                            int &full_chars_out,
                                            string &detail_json_out,
                                            string &full_json_out)
{
   detail_chars_out = 0;
   full_chars_out = 0;
   detail_json_out = "";
   full_json_out = "";

   GrindSideState saved_long = g_grind_long;
   GrindSideState saved_short = g_grind_short;
   const bool saved_heartbeat_test = g_grind_heartbeat_test_active;
   const int saved_heartbeat_count = g_grind_heartbeat_test_position_count;
   GrindHeartbeatTestPosition saved_positions[];
   ArrayResize(saved_positions, saved_heartbeat_count);
   for(int i = 0; i < saved_heartbeat_count; i++)
      saved_positions[i] = g_grind_heartbeat_test_positions[i];

   const bool saved_order_test = g_grind_order_test_active;
   const int saved_order_count = g_grind_order_test_count;
   GrindOrderTestRecord saved_orders[];
   ArrayResize(saved_orders, saved_order_count);
   for(int i = 0; i < saved_order_count; i++)
      saved_orders[i] = g_grind_order_test_records[i];

   Grind_HeartbeatTestReset();
   g_grind_heartbeat_test_active = true;
   g_grind_order_test_active = true;
   ArrayResize(g_grind_order_test_records, 0);
   g_grind_order_test_count = 0;

   ArrayResize(g_grind_long.layers, 0);
   ArrayResize(g_grind_short.layers, 0);
   g_grind_long.l0_pending_ticket = 0;
   g_grind_long.add_pending_ticket = 0;
   g_grind_short.l0_pending_ticket = 0;
   g_grind_short.add_pending_ticket = 0;

   const int per_side = max_layers_cap;
   ArrayResize(g_grind_long.layers, per_side);
   for(int i = 0; i < per_side; i++) {
      const ulong pos_ticket = 8000UL + (ulong)i;
      const string comment = GrindCommentBuild("OPT", "L", i, "ENT");
      g_grind_long.layers[i].layer_index = i;
      g_grind_long.layers[i].entry_price = 1.25000 + i * 0.00010;
      g_grind_long.layers[i].exit_target = 1.25050 + i * 0.00010;
      g_grind_long.layers[i].position_ticket = pos_ticket;
      g_grind_long.layers[i].exit_order_ticket = 1;
      g_grind_long.layers[i].exit_position_ticket = 1;
      Grind_HeartbeatTestUpsertPosition(pos_ticket, (long)magic, comment);
   }

   ArrayResize(g_grind_short.layers, per_side);
   for(int i = 0; i < per_side; i++) {
      const ulong pos_ticket = 9000UL + (ulong)i;
      const string comment = GrindCommentBuild("OPT", "S", i, "ENT");
      g_grind_short.layers[i].layer_index = i;
      g_grind_short.layers[i].entry_price = 1.26000 + i * 0.00010;
      g_grind_short.layers[i].exit_target = 1.26050 + i * 0.00010;
      g_grind_short.layers[i].position_ticket = pos_ticket;
      g_grind_short.layers[i].exit_order_ticket = 1;
      g_grind_short.layers[i].exit_position_ticket = 0;
      Grind_HeartbeatTestUpsertPosition(pos_ticket, (long)magic, comment);
   }

   g_grind_long.l0_pending_ticket = 9101UL;
   g_grind_long.add_pending_ticket = 9102UL;
   g_grind_short.l0_pending_ticket = 9103UL;
   g_grind_short.add_pending_ticket = 9104UL;
   Grind_OrderTestUpsert(9101UL, (long)magic, GrindCommentBuild("OPT", "L", 0, "ENT"),
                         1.24910, ORDER_TYPE_BUY_LIMIT);
   Grind_OrderTestUpsert(9102UL, (long)magic, GrindCommentBuild("OPT", "L", 11, "ENT"),
                         1.24810, ORDER_TYPE_BUY_LIMIT);
   Grind_OrderTestUpsert(9103UL, (long)magic, GrindCommentBuild("OPT", "S", 0, "ENT"),
                         1.26110, ORDER_TYPE_SELL_LIMIT);
   Grind_OrderTestUpsert(9104UL, (long)magic, GrindCommentBuild("OPT", "S", 11, "ENT"),
                         1.26210, ORDER_TYPE_SELL_LIMIT);

   const bool saved_book_test = g_grind_book_test_active;
   const int saved_book_pos_count = g_grind_book_test_position_count;
   const int saved_book_ord_count = g_grind_book_test_order_count;
   GrindBookTestPosition saved_book_positions[];
   GrindBookTestOrder saved_book_orders[];
   ArrayResize(saved_book_positions, saved_book_pos_count);
   ArrayResize(saved_book_orders, saved_book_ord_count);
   for(int i = 0; i < saved_book_pos_count; i++)
      saved_book_positions[i] = g_grind_book_test_positions[i];
   for(int i = 0; i < saved_book_ord_count; i++)
      saved_book_orders[i] = g_grind_book_test_orders[i];

   Grind_BookTestReset();
   g_grind_book_test_active = true;
   const int book_positions = per_side * 2 + 2;
   const int book_orders = per_side * 2 + 2;
   const long base_msc = (long)StringToTime("2026.09.10 12:00:00") * 1000L;
   for(int i = 0; i < book_positions; i++) {
      const string side = (i % 2 == 0 ? "L" : "S");
      const int layer = i % per_side;
      Grind_BookTestUpsertPosition(
         10000UL + (ulong)i,
         (long)magic,
         GrindCommentBuild("OPT", side, layer, "ENT"),
         1.25000 + i * 0.00010,
         (i % 2 == 0 ? POSITION_TYPE_BUY : POSITION_TYPE_SELL),
         base_msc + (long)i,
         -0.50 - i * 0.01);
   }
   for(int i = 0; i < book_orders; i++) {
      const string side = (i % 2 == 0 ? "L" : "S");
      const int layer = i % per_side;
      Grind_BookTestUpsertOrder(
         20000UL + (ulong)i,
         (long)magic,
         GrindCommentBuild("OPT", side, layer, "ENT"),
         1.24900 - i * 0.00010,
         (i % 2 == 0 ? ORDER_TYPE_BUY_LIMIT : ORDER_TYPE_SELL_LIMIT),
         base_msc + 5000L + (long)i * 2L);
   }

   detail_json_out = Grind_HeartbeatBuildLayerDetailJson(magic, digits);
   detail_chars_out = StringLen(detail_json_out);

   // Full heartbeat while the 24-layer book is still populated — same window as detail.
   full_json_out = Grind_TelemetryHeartbeatJson(
      "GRIND_GBPUSD_OPT", per_side, per_side, 3, 4,
      false, false, "", true, true,
      0.1, 0.2, 0.3, 0.4, false,
      magic, "OPT", 5.0, 10.0, 5.0, max_layers_cap, "GBP", "USD");
   full_chars_out = StringLen(full_json_out);

   g_grind_long = saved_long;
   g_grind_short = saved_short;
   Grind_HeartbeatTestReset();
   g_grind_heartbeat_test_active = saved_heartbeat_test;
   ArrayResize(g_grind_heartbeat_test_positions, saved_heartbeat_count);
   g_grind_heartbeat_test_position_count = saved_heartbeat_count;
   for(int i = 0; i < saved_heartbeat_count; i++)
      g_grind_heartbeat_test_positions[i] = saved_positions[i];

   g_grind_order_test_active = saved_order_test;
   ArrayResize(g_grind_order_test_records, saved_order_count);
   g_grind_order_test_count = saved_order_count;
   for(int i = 0; i < saved_order_count; i++)
      g_grind_order_test_records[i] = saved_orders[i];

   Grind_BookTestReset();
   g_grind_book_test_active = saved_book_test;
   ArrayResize(g_grind_book_test_positions, saved_book_pos_count);
   g_grind_book_test_position_count = saved_book_pos_count;
   for(int i = 0; i < saved_book_pos_count; i++)
      g_grind_book_test_positions[i] = saved_book_positions[i];
   ArrayResize(g_grind_book_test_orders, saved_book_ord_count);
   g_grind_book_test_order_count = saved_book_ord_count;
   for(int i = 0; i < saved_book_ord_count; i++)
      g_grind_book_test_orders[i] = saved_book_orders[i];
}

//+------------------------------------------------------------------+
void Grind_HeartbeatSplitBookArrayRows(const string array_inner, string &rows_out[])
{
   ArrayResize(rows_out, 0);
   if(array_inner == "")
      return;

   int start = 0;
   for(int i = 0; i < StringLen(array_inner) - 2; i++) {
      if(StringGetCharacter(array_inner, i) == '}' &&
         StringGetCharacter(array_inner, i + 1) == ',' &&
         StringGetCharacter(array_inner, i + 2) == '{') {
         const int n = ArraySize(rows_out);
         ArrayResize(rows_out, n + 1);
         rows_out[n] = StringSubstr(array_inner, start, i - start + 1);
         start = i + 2;
         i += 2;
      }
   }

   const int n = ArraySize(rows_out);
   ArrayResize(rows_out, n + 1);
   rows_out[n] = StringSubstr(array_inner, start);
}

//+------------------------------------------------------------------+
string Grind_HeartbeatBookArrayInnerJson(const string array_key, const string rows_json)
{
   return "\"" + array_key + "\":[" + rows_json + "]";
}

//+------------------------------------------------------------------+
int Grind_HeartbeatBookArrayJournalLineChars(const string instance_name,
                                             const string event_tag,
                                             const string array_key,
                                             const string rows_json)
{
   const string prefix = "TELEM|" + instance_name + "|" + event_tag + "|";
   const string body = Grind_HeartbeatBookArrayInnerJson(array_key, rows_json);
   return StringLen(prefix) + StringLen("{" + body + "}");
}

//+------------------------------------------------------------------+
int Grind_HeartbeatBookArrayJournalMaxLineChars(const string instance_name,
                                                const string event_tag,
                                                const string array_key,
                                                const string array_body)
{
   const int open_bracket = StringFind(array_body, "[");
   const int close_bracket = StringFind(array_body, "]", open_bracket + 1);
   if(open_bracket < 0 || close_bracket <= open_bracket)
      return Grind_HeartbeatBookArrayJournalLineChars(instance_name, event_tag,
                                                      array_key, "");

   const string array_inner = StringSubstr(array_body, open_bracket + 1,
                                           close_bracket - open_bracket - 1);
   string rows[];
   Grind_HeartbeatSplitBookArrayRows(array_inner, rows);
   const int row_count = ArraySize(rows);
   if(row_count == 0)
      return Grind_HeartbeatBookArrayJournalLineChars(instance_name, event_tag,
                                                      array_key, "");

   const int chunk_rows = 20;
   int max_line = 0;
   for(int start_row = 0; start_row < row_count; start_row += chunk_rows) {
      string batch = rows[start_row];
      for(int j = start_row + 1; j < start_row + chunk_rows && j < row_count; j++)
         batch += "," + rows[j];
      const int line = Grind_HeartbeatBookArrayJournalLineChars(
         instance_name, event_tag, array_key, batch);
      if(line > max_line)
         max_line = line;
   }
   return max_line;
}

//+------------------------------------------------------------------+
void Grind_HeartbeatPrintBookArrayJournal(const string instance_name,
                                          const string event_tag,
                                          const string array_key,
                                          const string array_body)
{
   const int open_bracket = StringFind(array_body, "[");
   const int close_bracket = StringFind(array_body, "]", open_bracket + 1);
   if(open_bracket < 0 || close_bracket <= open_bracket) {
      const string prefix = "TELEM|" + instance_name + "|" + event_tag + "|";
      Print(prefix, "{" + array_body + "}");
      return;
   }

   const string array_inner = StringSubstr(array_body, open_bracket + 1,
                                           close_bracket - open_bracket - 1);
   string rows[];
   Grind_HeartbeatSplitBookArrayRows(array_inner, rows);
   const int row_count = ArraySize(rows);
   const string prefix = "TELEM|" + instance_name + "|" + event_tag + "|";
   if(row_count == 0) {
      Print(prefix, "{" + Grind_HeartbeatBookArrayInnerJson(array_key, "") + "}");
      return;
   }

   const int chunk_rows = 20;
   int chunk = 1;
   for(int start_row = 0; start_row < row_count; start_row += chunk_rows) {
      string batch = rows[start_row];
      for(int j = start_row + 1; j < start_row + chunk_rows && j < row_count; j++)
         batch += "," + rows[j];
      const string tag = (chunk == 1 ? event_tag : event_tag + "_" + IntegerToString(chunk));
      Print("TELEM|", instance_name, "|", tag, "|",
            "{" + Grind_HeartbeatBookArrayInnerJson(array_key, batch) + "}");
      chunk++;
   }
}

//+------------------------------------------------------------------+
int Grind_HeartbeatBookJournalMaxLineChars(const string instance_name,
                                           const string book_value)
{
   const string book_prefix = "TELEM|" + instance_name + "|HEARTBEAT_BOOK|";
   const string book_json = "{" + book_value + "}";
   const int combined = StringLen(book_prefix) + StringLen(book_json);
   if(combined < 4096)
      return combined;

   const int pos_key = StringFind(book_value, "\"positions\":");
   const int ord_key = StringFind(book_value, "\"orders\":");
   if(pos_key < 0 || ord_key < 0 || ord_key <= pos_key)
      return combined;

   string positions_body = StringSubstr(book_value, pos_key, ord_key - pos_key);
   while(StringLen(positions_body) > 0 &&
         StringGetCharacter(positions_body, StringLen(positions_body) - 1) == ',')
      positions_body = StringSubstr(positions_body, 0, StringLen(positions_body) - 1);
   const string orders_body = StringSubstr(book_value, ord_key);
   const int pos_line = Grind_HeartbeatBookArrayJournalMaxLineChars(
      instance_name, "HEARTBEAT_BOOK_POS", "positions", positions_body);
   const int ord_line = Grind_HeartbeatBookArrayJournalMaxLineChars(
      instance_name, "HEARTBEAT_BOOK_ORD", "orders", orders_body);
   return (pos_line > ord_line ? pos_line : ord_line);
}

//+------------------------------------------------------------------+
void Grind_HeartbeatPrintBookJournal(const string instance_name,
                                     const string book_value)
{
   const string book_prefix = "TELEM|" + instance_name + "|HEARTBEAT_BOOK|";
   const string book_json = "{" + book_value + "}";
   if(StringLen(book_prefix) + StringLen(book_json) < 4096) {
      Print(book_prefix, book_json);
      return;
   }

   const int pos_key = StringFind(book_value, "\"positions\":");
   const int ord_key = StringFind(book_value, "\"orders\":");
   if(pos_key < 0 || ord_key < 0 || ord_key <= pos_key) {
      Print(book_prefix, book_json);
      return;
   }

   string positions_body = StringSubstr(book_value, pos_key, ord_key - pos_key);
   while(StringLen(positions_body) > 0 &&
         StringGetCharacter(positions_body, StringLen(positions_body) - 1) == ',')
      positions_body = StringSubstr(positions_body, 0, StringLen(positions_body) - 1);
   const string orders_body = StringSubstr(book_value, ord_key);
   Grind_HeartbeatPrintBookArrayJournal(instance_name, "HEARTBEAT_BOOK_POS",
                                        "positions", positions_body);
   Grind_HeartbeatPrintBookArrayJournal(instance_name, "HEARTBEAT_BOOK_ORD",
                                        "orders", orders_body);
}

//+------------------------------------------------------------------+
bool Grind_HeartbeatWouldJournalSplit(const string instance_name,
                                      const string full_json)
{
   const string prefix = "TELEM|" + instance_name + "|HEARTBEAT|";
   if(StringLen(prefix) + StringLen(full_json) < 4096)
      return false;
   return (StringFind(full_json, ",\"layers\":") >= 0);
}

//+------------------------------------------------------------------+
void Grind_HeartbeatJournalSplitLineLengths(const string instance_name,
                                            const string full_json,
                                            int &unsplit_line_chars_out,
                                            int &scalar_line_chars_out,
                                            int &detail_line_chars_out,
                                            bool &split_would_fire_out,
                                            int &book_line_chars_out)
{
   const string hb_prefix = "TELEM|" + instance_name + "|HEARTBEAT|";
   unsplit_line_chars_out = StringLen(hb_prefix) + StringLen(full_json);
   split_would_fire_out = Grind_HeartbeatWouldJournalSplit(instance_name, full_json);
   scalar_line_chars_out = unsplit_line_chars_out;
   detail_line_chars_out = 0;
   book_line_chars_out = 0;
   if(!split_would_fire_out)
      return;

   const int layers_pos = StringFind(full_json, ",\"layers\":");
   if(layers_pos < 0)
      return;

   const int book_pos = StringFind(full_json, ",\"book\":");
   const string scalar_json = StringSubstr(full_json, 0, layers_pos) + "}";
   scalar_line_chars_out = StringLen(hb_prefix) + StringLen(scalar_json);

   if(book_pos < 0) {
      const string detail_json = "{" + StringSubstr(full_json, layers_pos + 1);
      detail_line_chars_out = StringLen("TELEM|" + instance_name + "|HEARTBEAT_DETAIL|")
                              + StringLen(detail_json);
      return;
   }

   const string detail_body = StringSubstr(full_json, layers_pos + 1, book_pos - layers_pos - 1);
   const string detail_json = "{" + detail_body + "}";
   detail_line_chars_out = StringLen("TELEM|" + instance_name + "|HEARTBEAT_DETAIL|")
                           + StringLen(detail_json);
   const int book_key_pos = StringFind(full_json, "\"book\":");
   const string book_value = StringSubstr(full_json, book_key_pos,
                                          StringLen(full_json) - book_key_pos - 1);
   book_line_chars_out = Grind_HeartbeatBookJournalMaxLineChars(instance_name, book_value);
}

#endif // GRIND_HEARTBEAT_DETAIL_MQH
