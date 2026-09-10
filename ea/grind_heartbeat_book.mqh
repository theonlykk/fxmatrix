//+------------------------------------------------------------------+
//| grind_heartbeat_book.mqh — full broker book for heartbeat        |
//| Every position and pending order under this instance's magic.    |
//+------------------------------------------------------------------+
#ifndef GRIND_HEARTBEAT_BOOK_MQH
#define GRIND_HEARTBEAT_BOOK_MQH

#include "grind_state.mqh"
#include "grind_comment.mqh"
#include "grind_pure.mqh"

bool g_grind_book_test_active = false;

struct GrindBookTestPosition
{
   ulong  ticket;
   long   magic;
   string comment;
   double price;
   long   type;
   long   open_time_msc;
   double profit;
};

struct GrindBookTestOrder
{
   ulong  ticket;
   long   magic;
   string comment;
   double price;
   long   type;
   long   open_time_msc;
};

GrindBookTestPosition g_grind_book_test_positions[];
int g_grind_book_test_position_count = 0;
GrindBookTestOrder g_grind_book_test_orders[];
int g_grind_book_test_order_count = 0;

//+------------------------------------------------------------------+
void Grind_BookTestReset()
{
   g_grind_book_test_active = false;
   ArrayResize(g_grind_book_test_positions, 0);
   g_grind_book_test_position_count = 0;
   ArrayResize(g_grind_book_test_orders, 0);
   g_grind_book_test_order_count = 0;
}

//+------------------------------------------------------------------+
void Grind_BookTestUpsertPosition(const ulong ticket,
                                  const long magic,
                                  const string comment,
                                  const double price,
                                  const long type,
                                  const long open_time_msc,
                                  const double profit)
{
   for(int i = 0; i < g_grind_book_test_position_count; i++) {
      if(g_grind_book_test_positions[i].ticket == ticket) {
         g_grind_book_test_positions[i].magic = magic;
         g_grind_book_test_positions[i].comment = comment;
         g_grind_book_test_positions[i].price = price;
         g_grind_book_test_positions[i].type = type;
         g_grind_book_test_positions[i].open_time_msc = open_time_msc;
         g_grind_book_test_positions[i].profit = profit;
         return;
      }
   }
   ArrayResize(g_grind_book_test_positions, g_grind_book_test_position_count + 1);
   g_grind_book_test_positions[g_grind_book_test_position_count].ticket = ticket;
   g_grind_book_test_positions[g_grind_book_test_position_count].magic = magic;
   g_grind_book_test_positions[g_grind_book_test_position_count].comment = comment;
   g_grind_book_test_positions[g_grind_book_test_position_count].price = price;
   g_grind_book_test_positions[g_grind_book_test_position_count].type = type;
   g_grind_book_test_positions[g_grind_book_test_position_count].open_time_msc = open_time_msc;
   g_grind_book_test_positions[g_grind_book_test_position_count].profit = profit;
   g_grind_book_test_position_count++;
}

//+------------------------------------------------------------------+
void Grind_BookTestUpsertOrder(const ulong ticket,
                               const long magic,
                               const string comment,
                               const double price,
                               const long type,
                               const long open_time_msc)
{
   for(int i = 0; i < g_grind_book_test_order_count; i++) {
      if(g_grind_book_test_orders[i].ticket == ticket) {
         g_grind_book_test_orders[i].magic = magic;
         g_grind_book_test_orders[i].comment = comment;
         g_grind_book_test_orders[i].price = price;
         g_grind_book_test_orders[i].type = type;
         g_grind_book_test_orders[i].open_time_msc = open_time_msc;
         return;
      }
   }
   ArrayResize(g_grind_book_test_orders, g_grind_book_test_order_count + 1);
   g_grind_book_test_orders[g_grind_book_test_order_count].ticket = ticket;
   g_grind_book_test_orders[g_grind_book_test_order_count].magic = magic;
   g_grind_book_test_orders[g_grind_book_test_order_count].comment = comment;
   g_grind_book_test_orders[g_grind_book_test_order_count].price = price;
   g_grind_book_test_orders[g_grind_book_test_order_count].type = type;
   g_grind_book_test_orders[g_grind_book_test_order_count].open_time_msc = open_time_msc;
   g_grind_book_test_order_count++;
}

//+------------------------------------------------------------------+
string Grind_BookJsonEscape(const string raw)
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
string Grind_BookQuotedCommentJson(const string comment)
{
   return "\"" + Grind_BookJsonEscape(comment) + "\"";
}

//+------------------------------------------------------------------+
string Grind_BookFormatOpenTime(const long open_time_msc)
{
   if(open_time_msc <= 0)
      return "1970.01.01 00:00:00";
   const datetime sec = (datetime)(open_time_msc / 1000);
   return TimeToString(sec, TIME_DATE | TIME_MINUTES | TIME_SECONDS);
}

//+------------------------------------------------------------------+
string Grind_BookPositionTypeShort(const long pos_type)
{
   switch((int)pos_type) {
      case POSITION_TYPE_BUY:
         return "BUY";
      case POSITION_TYPE_SELL:
         return "SELL";
   }
   return "BUY";
}

//+------------------------------------------------------------------+
string Grind_BookOrderTypeShort(const long order_type)
{
   switch((int)order_type) {
      case ORDER_TYPE_BUY:
         return "BUY";
      case ORDER_TYPE_SELL:
         return "SELL";
      case ORDER_TYPE_BUY_LIMIT:
         return "BUY_LIMIT";
      case ORDER_TYPE_SELL_LIMIT:
         return "SELL_LIMIT";
   }
   return "BUY_LIMIT";
}

//+------------------------------------------------------------------+
string Grind_BookPositionRowJson(const ulong ticket,
                                 const string type,
                                 const double price,
                                 const int digits,
                                 const long open_time_msc,
                                 const string comment,
                                 const double profit)
{
   return StringFormat(
      "{\"ticket\":%s,\"type\":\"%s\",\"price\":%s,"
      "\"open_time\":\"%s\",\"open_time_msc\":%s,"
      "\"comment\":%s,\"profit\":%s}",
      IntegerToString((long)ticket),
      type,
      DoubleToString(price, digits),
      Grind_BookFormatOpenTime(open_time_msc),
      IntegerToString(open_time_msc),
      Grind_BookQuotedCommentJson(comment),
      DoubleToString(profit, 2));
}

//+------------------------------------------------------------------+
string Grind_BookOrderRowJson(const ulong ticket,
                              const string type,
                              const double price,
                              const int digits,
                              const long open_time_msc,
                              const string comment)
{
   return StringFormat(
      "{\"ticket\":%s,\"type\":\"%s\",\"price\":%s,"
      "\"open_time\":\"%s\",\"open_time_msc\":%s,"
      "\"comment\":%s}",
      IntegerToString((long)ticket),
      type,
      DoubleToString(price, digits),
      Grind_BookFormatOpenTime(open_time_msc),
      IntegerToString(open_time_msc),
      Grind_BookQuotedCommentJson(comment));
}

//+------------------------------------------------------------------+
string Grind_BookBuildPositionsJson(const ulong magic, const int digits)
{
   string json = "[";
   bool first = true;

   if(g_grind_book_test_active) {
      for(int i = 0; i < g_grind_book_test_position_count; i++) {
         if(!Grind_MagicMatches(g_grind_book_test_positions[i].magic, magic))
            continue;
         if(!first)
            json += ",";
         first = false;
         json += Grind_BookPositionRowJson(
            g_grind_book_test_positions[i].ticket,
            Grind_BookPositionTypeShort(g_grind_book_test_positions[i].type),
            g_grind_book_test_positions[i].price,
            digits,
            g_grind_book_test_positions[i].open_time_msc,
            g_grind_book_test_positions[i].comment,
            g_grind_book_test_positions[i].profit);
      }
      json += "]";
      return json;
   }

   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(!Grind_MagicMatches(PositionGetInteger(POSITION_MAGIC), magic))
         continue;

      if(!first)
         json += ",";
      first = false;

      json += Grind_BookPositionRowJson(
         ticket,
         Grind_BookPositionTypeShort(PositionGetInteger(POSITION_TYPE)),
         PositionGetDouble(POSITION_PRICE_OPEN),
         digits,
         PositionGetInteger(POSITION_TIME_MSC),
         PositionGetString(POSITION_COMMENT),
         PositionGetDouble(POSITION_PROFIT));
   }

   json += "]";
   return json;
}

//+------------------------------------------------------------------+
string Grind_BookBuildOrdersJson(const ulong magic, const int digits)
{
   string json = "[";
   bool first = true;

   if(g_grind_book_test_active) {
      for(int i = 0; i < g_grind_book_test_order_count; i++) {
         if(!Grind_MagicMatches(g_grind_book_test_orders[i].magic, magic))
            continue;
         if(!first)
            json += ",";
         first = false;
         json += Grind_BookOrderRowJson(
            g_grind_book_test_orders[i].ticket,
            Grind_BookOrderTypeShort(g_grind_book_test_orders[i].type),
            g_grind_book_test_orders[i].price,
            digits,
            g_grind_book_test_orders[i].open_time_msc,
            g_grind_book_test_orders[i].comment);
      }
      json += "]";
      return json;
   }

   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(!Grind_MagicMatches(OrderGetInteger(ORDER_MAGIC), magic))
         continue;

      if(!first)
         json += ",";
      first = false;

      json += Grind_BookOrderRowJson(
         ticket,
         Grind_BookOrderTypeShort(OrderGetInteger(ORDER_TYPE)),
         OrderGetDouble(ORDER_PRICE_OPEN),
         digits,
         OrderGetInteger(ORDER_TIME_SETUP_MSC),
         OrderGetString(ORDER_COMMENT));
   }

   json += "]";
   return json;
}

//+------------------------------------------------------------------+
string Grind_HeartbeatBuildBookJson(const ulong magic, const int digits)
{
   return StringFormat(
      "\"book\":{\"positions\":%s,\"orders\":%s}",
      Grind_BookBuildPositionsJson(magic, digits),
      Grind_BookBuildOrdersJson(magic, digits));
}

#endif // GRIND_HEARTBEAT_BOOK_MQH
