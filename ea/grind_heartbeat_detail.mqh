//+------------------------------------------------------------------+
//| grind_heartbeat_detail.mqh — per-layer price detail for heartbeat  |
//| Included from grind_engine.mqh after order-test hooks are defined. |
//+------------------------------------------------------------------+
#ifndef GRIND_HEARTBEAT_DETAIL_MQH
#define GRIND_HEARTBEAT_DETAIL_MQH

#include "grind_state.mqh"
#include "grind_comment.mqh"
#include "grind_pure.mqh"

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
string Grind_HeartbeatLayersJson(const int digits)
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

         json += StringFormat(
            "{\"layer_index\":%d,\"side\":\"%s\","
            "\"entry_price\":%s,\"exit_target\":%s,"
            "\"has_exit_order\":%s,\"has_exit_position\":%s}",
            layer.layer_index,
            side_letter,
            DoubleToString(layer.entry_price, digits),
            DoubleToString(layer.exit_target, digits),
            (layer.exit_order_ticket != 0 ? "true" : "false"),
            (layer.exit_position_ticket != 0 ? "true" : "false")
         );
      }
   }

   json += "]";
   return json;
}

//+------------------------------------------------------------------+
string Grind_HeartbeatBuildLayerDetailJson(const ulong magic, const int digits)
{
   return StringFormat(
      "\"layers\":%s,"
      "\"l0_pending_long\":%s,\"l0_pending_short\":%s,"
      "\"add_pending_long\":%s,\"add_pending_short\":%s,"
      "\"resting_entries_long\":%d,\"resting_entries_short\":%d",
      Grind_HeartbeatLayersJson(digits),
      Grind_HeartbeatNullablePriceJson(g_grind_long.l0_pending_ticket, magic, digits),
      Grind_HeartbeatNullablePriceJson(g_grind_short.l0_pending_ticket, magic, digits),
      Grind_HeartbeatNullablePriceJson(g_grind_long.add_pending_ticket, magic, digits),
      Grind_HeartbeatNullablePriceJson(g_grind_short.add_pending_ticket, magic, digits),
      Grind_HeartbeatCountRestingEntries(magic, "L"),
      Grind_HeartbeatCountRestingEntries(magic, "S")
   );
}

//+------------------------------------------------------------------+
void Grind_HeartbeatMeasureWorstCasePayload(const int max_layers_cap,
                                            const int digits,
                                            const ulong magic,
                                            int &detail_chars_out,
                                            int &full_chars_out)
{
   detail_chars_out = 0;
   full_chars_out = 0;

   GrindSideState saved_long = g_grind_long;
   GrindSideState saved_short = g_grind_short;

   ArrayResize(g_grind_long.layers, 0);
   ArrayResize(g_grind_short.layers, 0);
   g_grind_long.l0_pending_ticket = 0;
   g_grind_long.add_pending_ticket = 0;
   g_grind_short.l0_pending_ticket = 0;
   g_grind_short.add_pending_ticket = 0;

   const int per_side = max_layers_cap;
   ArrayResize(g_grind_long.layers, per_side);
   for(int i = 0; i < per_side; i++) {
      g_grind_long.layers[i].layer_index = i;
      g_grind_long.layers[i].entry_price = 1.25000 + i * 0.00010;
      g_grind_long.layers[i].exit_target = 1.25050 + i * 0.00010;
      g_grind_long.layers[i].exit_order_ticket = 1;
      g_grind_long.layers[i].exit_position_ticket = 1;
   }

   ArrayResize(g_grind_short.layers, per_side);
   for(int i = 0; i < per_side; i++) {
      g_grind_short.layers[i].layer_index = i;
      g_grind_short.layers[i].entry_price = 1.26000 + i * 0.00010;
      g_grind_short.layers[i].exit_target = 1.26050 + i * 0.00010;
      g_grind_short.layers[i].exit_order_ticket = 1;
      g_grind_short.layers[i].exit_position_ticket = 0;
   }

   const string detail = Grind_HeartbeatBuildLayerDetailJson(magic, digits);
   detail_chars_out = StringLen(detail);

   // Full heartbeat while the 24-layer book is still populated — same window as detail.
   const string full = Grind_TelemetryHeartbeatJson(
      "GRIND_GBPUSD_OPT", per_side, per_side, 3, 4,
      false, false, "", true, true,
      0.1, 0.2, 0.3, 0.4, false,
      magic, "OPT", 5.0, 10.0, 5.0, max_layers_cap, "GBP", "USD");
   full_chars_out = StringLen(full);

   g_grind_long = saved_long;
   g_grind_short = saved_short;
}

#endif // GRIND_HEARTBEAT_DETAIL_MQH
