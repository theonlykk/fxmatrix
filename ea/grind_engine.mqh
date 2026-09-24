//+------------------------------------------------------------------+
//| grind_engine.mqh — fxgrind trading engine (dumb-only, no signal) |
//+------------------------------------------------------------------+
#ifndef GRIND_ENGINE_MQH
#define GRIND_ENGINE_MQH

#include "grind_pure.mqh"
#include "grind_state.mqh"
#include "grind_recon.mqh"
#include "grind_cap.mqh"
#include "grind_api_counter.mqh"
#include "grind_closeby.mqh"
#include "grind_telemetry.mqh"

// Live-market unit-test hooks (fxgrind_tests — off by default in production).
bool   g_grind_market_test_active = false;
double g_grind_market_test_bid = 0.0;
double g_grind_market_test_ask = 0.0;
long   g_grind_market_test_stops_level = 0;
long   g_grind_market_test_freeze_level = 0;
bool   g_grind_market_test_time_active = false;
long   g_grind_market_test_time_msc = 0;

bool   g_grind_fill_time_place = false;
double g_grind_engine_add_pips = 0.0;
double g_grind_engine_entry_horizon_pips = 0.0;

//+------------------------------------------------------------------+
void Grind_MarketTestReset()
{
   g_grind_market_test_active = false;
   g_grind_market_test_bid = 0.0;
   g_grind_market_test_ask = 0.0;
   g_grind_market_test_stops_level = 0;
   g_grind_market_test_freeze_level = 0;
   g_grind_market_test_time_active = false;
   g_grind_market_test_time_msc = 0;
}

//+------------------------------------------------------------------+
void Grind_MarketTestSeedTimeMsc(const long time_msc)
{
   g_grind_market_test_time_active = true;
   g_grind_market_test_time_msc = time_msc;
}

//+------------------------------------------------------------------+
long Grind_MarketTimeMsc()
{
   if(g_grind_market_test_time_active)
      return g_grind_market_test_time_msc;
   return (long)SymbolInfoInteger(_Symbol, SYMBOL_TIME_MSC);
}

//+------------------------------------------------------------------+
void Grind_MarketTestSeed(const double bid,
                          const double ask,
                          const long stops_level = 0,
                          const long freeze_level = 0)
{
   g_grind_market_test_active = true;
   g_grind_market_test_bid = bid;
   g_grind_market_test_ask = ask;
   g_grind_market_test_stops_level = stops_level;
   g_grind_market_test_freeze_level = freeze_level;
}

//+------------------------------------------------------------------+
double Grind_MarketBid()
{
   if(g_grind_market_test_active)
      return g_grind_market_test_bid;
   return SymbolInfoDouble(_Symbol, SYMBOL_BID);
}

//+------------------------------------------------------------------+
double Grind_MarketAsk()
{
   if(g_grind_market_test_active)
      return g_grind_market_test_ask;
   return SymbolInfoDouble(_Symbol, SYMBOL_ASK);
}

//+------------------------------------------------------------------+
long Grind_MarketStopsLevel()
{
   if(g_grind_market_test_active)
      return g_grind_market_test_stops_level;
   return (long)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
}

//+------------------------------------------------------------------+
long Grind_MarketFreezeLevel()
{
   if(g_grind_market_test_active)
      return g_grind_market_test_freeze_level;
   return (long)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
}

#include "grind_exitq.mqh"

// Order-operation unit-test hooks (fxgrind_tests A1–A8).
bool   g_grind_order_test_active = false;
bool   g_grind_order_test_send_ok = true;
uint   g_grind_order_test_send_retcode = TRADE_RETCODE_DONE;
int    g_grind_order_test_remove_calls = 0;
int    g_grind_order_test_modify_calls = 0;
int    g_grind_order_test_place_calls = 0;
ulong  g_grind_order_test_next_ticket = 9000;
ulong  g_grind_order_test_last_placed_ticket = 0;
string g_grind_order_test_last_placed_comment = "";
double g_grind_order_test_last_placed_price = 0.0;
string g_grind_order_test_last_critical = "";

struct GrindOrderTestRecord
{
   ulong  ticket;
   long   magic;
   string comment;
   double price;
   long   type;
};

GrindOrderTestRecord g_grind_order_test_records[];
int g_grind_order_test_count = 0;

ulong g_grind_position_test_tickets[];
int   g_grind_position_test_count = 0;

//+------------------------------------------------------------------+
bool Grind_OrderTestActive()
{
   return g_grind_order_test_active;
}

//+------------------------------------------------------------------+
int Grind_OrderTestRestingEntFleetCount()
{
   int resting_ent = 0;
   for(int i = 0; i < g_grind_order_test_count; i++) {
      const GrindOrderTestRecord rec = g_grind_order_test_records[i];
      if(!Grind_IsFleetMagic(rec.magic))
         continue;
      string slot, side, role;
      int layer_index;
      if(GrindCommentParse(rec.comment, slot, side, layer_index, role)) {
         if(role == "EXT")
            continue;
      }
      resting_ent++;
   }
   return resting_ent;
}

//+------------------------------------------------------------------+
bool Grind_PositionTestExistsAnyMagic(const ulong ticket)
{
   if(ticket == 0)
      return false;
   for(int i = 0; i < g_grind_position_test_count; i++) {
      if(g_grind_position_test_tickets[i] == ticket)
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
void Grind_PositionTestAdd(const ulong ticket)
{
   ArrayResize(g_grind_position_test_tickets, g_grind_position_test_count + 1);
   g_grind_position_test_tickets[g_grind_position_test_count] = ticket;
   g_grind_position_test_count++;
}

//+------------------------------------------------------------------+
void Grind_OrderTestReset()
{
   Grind_MarketTestReset();
   g_grind_order_test_active = false;
   g_grind_order_test_send_ok = true;
   g_grind_order_test_send_retcode = TRADE_RETCODE_DONE;
   g_grind_order_test_remove_calls = 0;
   g_grind_order_test_modify_calls = 0;
   g_grind_order_test_place_calls = 0;
   g_grind_order_test_next_ticket = 9000;
   g_grind_order_test_last_placed_ticket = 0;
   g_grind_order_test_last_placed_comment = "";
   g_grind_order_test_last_placed_price = 0.0;
   g_grind_order_test_last_critical = "";
   ArrayResize(g_grind_order_test_records, 0);
   g_grind_order_test_count = 0;
   ArrayResize(g_grind_position_test_tickets, 0);
   g_grind_position_test_count = 0;
   g_grind_ent_sent_this_tick = false;
   g_grind_slot_test_delta = 0;
}

//+------------------------------------------------------------------+
bool Grind_OrderTestFind(const ulong ticket, GrindOrderTestRecord &out)
{
   for(int i = 0; i < g_grind_order_test_count; i++) {
      if(g_grind_order_test_records[i].ticket == ticket) {
         out = g_grind_order_test_records[i];
         return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
int Grind_OrderTestCountFleetEnt(const string side_letter)
{
   int n = 0;
   for(int i = 0; i < g_grind_order_test_count; i++) {
      string slot, side, role;
      int layer;
      if(!GrindCommentParse(g_grind_order_test_records[i].comment, slot, side, layer, role))
         continue;
      if(side == side_letter && role == "ENT")
         n++;
   }
   return n;
}

//+------------------------------------------------------------------+
void Grind_OrderTestUpsert(const ulong ticket,
                           const long magic,
                           const string comment,
                           const double price,
                           const long type)
{
   for(int i = 0; i < g_grind_order_test_count; i++) {
      if(g_grind_order_test_records[i].ticket == ticket) {
         g_grind_order_test_records[i].magic = magic;
         g_grind_order_test_records[i].comment = comment;
         g_grind_order_test_records[i].price = price;
         g_grind_order_test_records[i].type = type;
         return;
      }
   }
   ArrayResize(g_grind_order_test_records, g_grind_order_test_count + 1);
   g_grind_order_test_records[g_grind_order_test_count].ticket = ticket;
   g_grind_order_test_records[g_grind_order_test_count].magic = magic;
   g_grind_order_test_records[g_grind_order_test_count].comment = comment;
   g_grind_order_test_records[g_grind_order_test_count].price = price;
   g_grind_order_test_records[g_grind_order_test_count].type = type;
   g_grind_order_test_count++;
}

//+------------------------------------------------------------------+
void Grind_OrderTestRemove(const ulong ticket)
{
   for(int i = 0; i < g_grind_order_test_count; i++) {
      if(g_grind_order_test_records[i].ticket != ticket)
         continue;
      for(int j = i; j < g_grind_order_test_count - 1; j++)
         g_grind_order_test_records[j] = g_grind_order_test_records[j + 1];
      g_grind_order_test_count--;
      ArrayResize(g_grind_order_test_records, g_grind_order_test_count);
      return;
   }
}

//+------------------------------------------------------------------+
bool Grind_OrderEngineSend(MqlTradeRequest &request, MqlTradeResult &result)
{
   if(!g_grind_order_test_active)
      return Grind_OrderSendCounted(request, result);

   if(request.action == TRADE_ACTION_REMOVE) {
      g_grind_order_test_remove_calls++;
      result.retcode = g_grind_order_test_send_retcode;
      if(!g_grind_order_test_send_ok)
         return false;
      if(result.retcode == TRADE_RETCODE_DONE) {
         Grind_OrderTestRemove(request.order);
         g_grind_slot_test_delta--;
      }
      return true;
   }

   if(request.action == TRADE_ACTION_MODIFY) {
      g_grind_order_test_modify_calls++;
      result.retcode = g_grind_order_test_send_retcode;
      if(!g_grind_order_test_send_ok)
         return false;
      if(result.retcode == TRADE_RETCODE_DONE || result.retcode == TRADE_RETCODE_PLACED) {
         GrindOrderTestRecord rec;
         if(Grind_OrderTestFind(request.order, rec))
            Grind_OrderTestUpsert(request.order, rec.magic, rec.comment,
                                  request.price, rec.type);
      }
      return true;
   }

   if(request.action == TRADE_ACTION_PENDING) {
      g_grind_order_test_place_calls++;
      result.retcode = g_grind_order_test_send_retcode;
      if(!g_grind_order_test_send_ok)
         return false;
      if(result.retcode == TRADE_RETCODE_DONE || result.retcode == TRADE_RETCODE_PLACED) {
         const ulong ticket = g_grind_order_test_next_ticket++;
         result.order = ticket;
         g_grind_order_test_last_placed_ticket = ticket;
         g_grind_order_test_last_placed_comment = request.comment;
         g_grind_order_test_last_placed_price = request.price;
         Grind_OrderTestUpsert(ticket, (long)request.magic, request.comment,
                               request.price, (long)request.type);
         g_grind_slot_test_delta++;
      }
      return true;
   }

   return Grind_OrderSendCounted(request, result);
}

//+------------------------------------------------------------------+
bool Grind_SelectOurOrder(const ulong ticket, const ulong magic)
{
   if(ticket == 0)
      return false;
   if(g_grind_order_test_active) {
      GrindOrderTestRecord rec;
      if(!Grind_OrderTestFind(ticket, rec))
         return false;
      return Grind_MagicMatches(rec.magic, magic);
   }
   if(!OrderSelect(ticket))
      return false;
   return Grind_MagicMatches(OrderGetInteger(ORDER_MAGIC), magic);
}

//+------------------------------------------------------------------+
string Grind_OrderGetComment(const ulong ticket)
{
   if(g_grind_order_test_active) {
      GrindOrderTestRecord rec;
      if(Grind_OrderTestFind(ticket, rec))
         return rec.comment;
      return "";
   }
   if(ticket == 0 || !OrderSelect(ticket))
      return "";
   return OrderGetString(ORDER_COMMENT);
}

//+------------------------------------------------------------------+
double Grind_OrderGetPriceOpen(const ulong ticket)
{
   if(g_grind_order_test_active) {
      GrindOrderTestRecord rec;
      if(Grind_OrderTestFind(ticket, rec))
         return rec.price;
      return 0.0;
   }
   if(ticket == 0 || !OrderSelect(ticket))
      return 0.0;
   return OrderGetDouble(ORDER_PRICE_OPEN);
}

//+------------------------------------------------------------------+
bool Grind_SelectOurPosition(const ulong ticket, const ulong magic)
{
   if(g_grind_order_test_active) {
      if(ticket == 0)
         return false;
      for(int i = 0; i < g_grind_position_test_count; i++) {
         if(g_grind_position_test_tickets[i] == ticket)
            return true;
      }
      return false;
   }
   if(ticket == 0 || !PositionSelectByTicket(ticket))
      return false;
   return Grind_MagicMatches(PositionGetInteger(POSITION_MAGIC), magic);
}

//+------------------------------------------------------------------+
int Grind_EjectAcceptLayer(const bool is_long, const int idx, const ulong magic,
                           const double exit_pips, const string source)
{
   ulong position_ticket = 0;
   ulong exit_order_ticket = 0;
   double entry_price = 0.0;
   if(is_long) {
      position_ticket = g_grind_long.layers[idx].position_ticket;
      exit_order_ticket = g_grind_long.layers[idx].exit_order_ticket;
      entry_price = g_grind_long.layers[idx].entry_price;
   } else {
      position_ticket = g_grind_short.layers[idx].position_ticket;
      exit_order_ticket = g_grind_short.layers[idx].exit_order_ticket;
      entry_price = g_grind_short.layers[idx].entry_price;
   }

   const double target = Grind_EjectTargetPrice(is_long);

   if(!Grind_ModifyPendingPrice(exit_order_ticket, target, magic)) {
      const string detail =
         "{\"ticket\":" + IntegerToString((long)position_ticket) +
         ",\"reason\":\"MODIFY_FAILED\"" +
         ",\"source\":\"" + source + "\"}";
      Grind_EjectReport("EJECT_REFUSED", position_ticket, detail);
      Print("INFO: eject refused ticket=", position_ticket, " reason=MODIFY_FAILED");
      return GRIND_EJECT_MODIFY_FAILED;
   }

   const int dir = is_long ? 1 : -1;
   const double raw = Grind_ExitPrice(entry_price, exit_pips, _Point, dir);
   const double accrued = Grind_CarryAccruedGet(position_ticket);
   const double offset = Grind_EjectOffsetFor(target, raw, accrued);
   Grind_EjectOffsetSet(position_ticket, offset);
   Grind_CarryShiftDelete(position_ticket);
   if(is_long)
      g_grind_long.layers[idx].exit_target = target;
   else
      g_grind_short.layers[idx].exit_target = target;

   const string accepted =
      "{\"ticket\":" + IntegerToString((long)position_ticket) +
      ",\"entry\":" + Grind_ArchiveJsonDouble(entry_price, 5) +
      ",\"raw\":" + Grind_ArchiveJsonDouble(raw, 5) +
      ",\"accrued\":" + Grind_ArchiveJsonDouble(accrued, 5) +
      ",\"target\":" + Grind_ArchiveJsonDouble(target, 5) +
      ",\"offset\":" + Grind_ArchiveJsonDouble(offset, 5) +
      ",\"source\":\"" + source + "\"}";
   Grind_EjectReport("EJECT_ACCEPTED", position_ticket, accepted);
   Print("INFO: eject accepted ticket=", position_ticket,
         " target=", DoubleToString(target, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)));
   return GRIND_EJECT_OK;
}

//+------------------------------------------------------------------+
int Grind_EjectPollCommand(const ulong magic,
                           const bool enabled,
                           const double exit_pips,
                           const bool engine_blocked)
{
   const string cmd_name = Grind_EjectCommandName(magic);
   if(!GlobalVariableCheck(cmd_name))
      return -1;

   const ulong position_ticket = (ulong)GlobalVariableGet(cmd_name);
   GlobalVariableDel(cmd_name);

   bool found = false;
   bool is_long = true;
   int idx = -1;
   for(int i = 0; i < Grind_SideDepth(g_grind_long); i++) {
      if(g_grind_long.layers[i].position_ticket != 0
         && g_grind_long.layers[i].position_ticket == position_ticket) {
         found = true;
         is_long = true;
         idx = i;
         break;
      }
   }
   if(!found) {
      for(int i = 0; i < Grind_SideDepth(g_grind_short); i++) {
         if(g_grind_short.layers[i].position_ticket != 0
            && g_grind_short.layers[i].position_ticket == position_ticket) {
            found = true;
            is_long = false;
            idx = i;
            break;
         }
      }
   }

   const int depth = found
                       ? (is_long ? Grind_SideDepth(g_grind_long) : Grind_SideDepth(g_grind_short))
                       : 0;
   int rank = 0;
   bool has_exit_order = false;
   if(found && idx >= 0) {
      const int n = depth;
      double entries[];
      int layer_indices[];
      int ranks[];
      ArrayResize(entries, n);
      ArrayResize(layer_indices, n);
      if(is_long) {
         for(int i = 0; i < n; i++) {
            entries[i] = g_grind_long.layers[i].entry_price;
            layer_indices[i] = g_grind_long.layers[i].layer_index;
         }
         Grind_ExitQRanks(entries, layer_indices, n, true, ranks);
         rank = ranks[idx];
         has_exit_order = (g_grind_long.layers[idx].exit_order_ticket != 0);
      } else {
         for(int i = 0; i < n; i++) {
            entries[i] = g_grind_short.layers[i].entry_price;
            layer_indices[i] = g_grind_short.layers[i].layer_index;
         }
         Grind_ExitQRanks(entries, layer_indices, n, false, ranks);
         rank = ranks[idx];
         has_exit_order = (g_grind_short.layers[idx].exit_order_ticket != 0);
      }
   }

   const int code = Grind_EjectValidate(engine_blocked, enabled, found, depth, rank, has_exit_order);
   if(code != GRIND_EJECT_OK) {
      const string detail =
         "{\"ticket\":" + IntegerToString((long)position_ticket) +
         ",\"reason\":\"" + Grind_EjectReasonName(code) + "\"}";
      Grind_EjectReport("EJECT_REFUSED", position_ticket, detail);
      Print("INFO: eject refused ticket=", position_ticket,
            " reason=", Grind_EjectReasonName(code));
      return code;
   }

   return Grind_EjectAcceptLayer(is_long, idx, magic, exit_pips, "command");
}

//+------------------------------------------------------------------+
datetime g_grind_auto_eject_backoff_long  = 0;
datetime g_grind_auto_eject_backoff_short = 0;

void Grind_AutoEjectResetBackoff()
{
   g_grind_auto_eject_backoff_long  = 0;
   g_grind_auto_eject_backoff_short = 0;
}

//+------------------------------------------------------------------+
int Grind_AutoEjectTrySide(const bool is_long, const ulong magic,
                           const double exit_pips, const int max_layers,
                           const bool enabled, const bool blocked,
                           const datetime &times[], const double &vals[], const int n,
                           const double &spreads[], const int ns,
                           const double current_spread_points,
                           const datetime now, const int stable_minutes,
                           const double k)
{
   if(!enabled || blocked)
      return -1;
   if(now < (is_long ? g_grind_auto_eject_backoff_long : g_grind_auto_eject_backoff_short))
      return -1;

   const int depth = is_long ? Grind_SideDepth(g_grind_long) : Grind_SideDepth(g_grind_short);
   if(depth < max_layers)
      return -1;

   const int layer_count = depth;
   double entries[];
   int layer_indices[];
   int ranks[];
   ArrayResize(entries, layer_count);
   ArrayResize(layer_indices, layer_count);
   ArrayResize(ranks, layer_count);
   int idx = -1;
   if(is_long) {
      for(int i = 0; i < layer_count; i++) {
         entries[i] = g_grind_long.layers[i].entry_price;
         layer_indices[i] = g_grind_long.layers[i].layer_index;
      }
      Grind_ExitQRanks(entries, layer_indices, layer_count, true, ranks);
      for(int i = 0; i < layer_count; i++) {
         if(ranks[i] == depth - 1) {
            idx = i;
            break;
         }
      }
   } else {
      for(int i = 0; i < layer_count; i++) {
         entries[i] = g_grind_short.layers[i].entry_price;
         layer_indices[i] = g_grind_short.layers[i].layer_index;
      }
      Grind_ExitQRanks(entries, layer_indices, layer_count, false, ranks);
      for(int i = 0; i < layer_count; i++) {
         if(ranks[i] == depth - 1) {
            idx = i;
            break;
         }
      }
   }
   if(idx < 0)
      return -1;

   const int rank = depth - 1;
   const ulong exit_order_ticket = is_long
                                   ? g_grind_long.layers[idx].exit_order_ticket
                                   : g_grind_short.layers[idx].exit_order_ticket;
   const int code = Grind_EjectValidate(blocked, enabled, true, depth, rank, exit_order_ticket != 0);
   if(code != GRIND_EJECT_OK)
      return -1;

   if(!Grind_AutoEjectStable(times, vals, n, now, stable_minutes * 60, is_long))
      return -1;
   if(!Grind_AutoEjectSpreadOk(current_spread_points, spreads, ns, k))
      return -1;

   const ulong position_ticket = is_long
                                 ? g_grind_long.layers[idx].position_ticket
                                 : g_grind_short.layers[idx].position_ticket;
   if(Grind_EjectIsEjected(position_ticket)) {
      const double resting = Grind_OrderGetPriceOpen(exit_order_ticket);
      if(resting <= 0.0)
         return -1;
      const double min_dist = Grind_CarryMinPassiveDistance(_Point,
                                                            Grind_MarketStopsLevel(),
                                                            Grind_MarketFreezeLevel());
      const double new_target = Grind_EjectTargetPrice(is_long);
      if(!Grind_AutoEjectTargetWorse(is_long, new_target, resting, min_dist))
         return -1;
   }

   const int rc = Grind_EjectAcceptLayer(is_long, idx, magic, exit_pips, "auto");
   if(rc == GRIND_EJECT_MODIFY_FAILED) {
      if(is_long)
         g_grind_auto_eject_backoff_long = now + stable_minutes * 60;
      else
         g_grind_auto_eject_backoff_short = now + stable_minutes * 60;
   }
   return rc;
}

//+------------------------------------------------------------------+
void Grind_AutoEjectOnTick(const ulong magic, const bool enabled,
                           const double exit_pips, const int max_layers,
                           const bool blocked, const int stable_minutes,
                           const double k)
{
   if(!enabled || blocked)
      return;
   if(max_layers < 1 || stable_minutes < 1)
      return;
   if(Grind_SideDepth(g_grind_long) < max_layers
      && Grind_SideDepth(g_grind_short) < max_layers)
      return;

   const datetime now = TimeCurrent();

   MqlRates spread_rates[];
   const int ns = CopyRates(_Symbol, PERIOD_M1, 0, 60, spread_rates);
   if(ns <= 0)
      return;
   double spreads[];
   ArrayResize(spreads, ns);
   for(int i = 0; i < ns; i++)
      spreads[i] = spread_rates[i].spread;

   const int bar_count = 2 * stable_minutes;
   MqlRates rates[];
   const int copied = CopyRates(_Symbol, PERIOD_M1, 0, bar_count, rates);
   if(copied < bar_count)
      return;
   if(!Grind_AutoEjectWindowIntact(rates[0].time + 60, now, 2 * stable_minutes * 60))
      return;

   datetime times[];
   double vals_long[];
   double vals_short[];
   ArrayResize(times, copied);
   ArrayResize(vals_long, copied);
   ArrayResize(vals_short, copied);
   for(int i = 0; i < copied; i++) {
      times[i] = rates[i].time + 60;
      vals_long[i] = rates[i].low;
      vals_short[i] = rates[i].high + rates[i].spread * _Point;
   }

   const double current = (Grind_MarketAsk() - Grind_MarketBid()) / _Point;

   if(Grind_SideDepth(g_grind_long) >= max_layers) {
      Grind_AutoEjectTrySide(true, magic, exit_pips, max_layers, enabled, blocked,
                             times, vals_long, copied, spreads, ns, current, now,
                             stable_minutes, k);
   }
   if(Grind_SideDepth(g_grind_short) >= max_layers) {
      Grind_AutoEjectTrySide(false, magic, exit_pips, max_layers, enabled, blocked,
                             times, vals_short, copied, spreads, ns, current, now,
                             stable_minutes, k);
   }
}

//+------------------------------------------------------------------+
bool Grind_ModifyPendingPrice(const ulong ticket,
                              const double new_price,
                              const ulong magic)
{
   if(!Grind_SelectOurOrder(ticket, magic))
      return false;

   MqlTradeRequest req;
   MqlTradeResult  res;
   ZeroMemory(req);
   ZeroMemory(res);
   req.action   = TRADE_ACTION_MODIFY;
   req.order    = ticket;
   req.symbol   = _Symbol;
   req.price    = Grind_Normalize(new_price);
   req.type     = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
   req.volume   = OrderGetDouble(ORDER_VOLUME_CURRENT);

   if(!Grind_OrderEngineSend(req, res))
      return false;
   return (res.retcode == TRADE_RETCODE_DONE || res.retcode == TRADE_RETCODE_PLACED);
}

//+------------------------------------------------------------------+
ulong Grind_PlaceLimit(const ENUM_ORDER_TYPE type,
                       const double price,
                       const double lots,
                       const ulong magic,
                       const string comment)
{
   MqlTradeRequest req;
   MqlTradeResult  res;
   ZeroMemory(req);
   ZeroMemory(res);
   req.action       = TRADE_ACTION_PENDING;
   req.symbol       = _Symbol;
   req.volume       = lots;
   req.type         = type;
   req.price        = Grind_Normalize(price);
   req.deviation    = 10;
   req.magic        = magic;
   req.comment      = comment;
   req.type_filling = ORDER_FILLING_RETURN;
   req.type_time    = ORDER_TIME_GTC;

   if(!Grind_OrderEngineSend(req, res))
      return 0;
   if(res.retcode == TRADE_RETCODE_DONE || res.retcode == TRADE_RETCODE_PLACED)
      return res.order;
   return 0;
}

//+------------------------------------------------------------------+
bool Grind_CancelPendingOrder(const ulong ticket, const ulong magic)
{
   if(ticket == 0)
      return false;
   if(!Grind_SelectOurOrder(ticket, magic))
      return false;

   MqlTradeRequest req;
   MqlTradeResult  res;
   ZeroMemory(req);
   ZeroMemory(res);
   req.action = TRADE_ACTION_REMOVE;
   req.order  = ticket;

   if(!Grind_OrderEngineSend(req, res))
      return false;
   return (res.retcode == TRADE_RETCODE_DONE);
}

//+------------------------------------------------------------------+
void Grind_CancelOwnEntryOrders(const ulong magic, const string slot);
int  Grind_OwnRestingEntryCount(const ulong magic, const string slot);

//+------------------------------------------------------------------+
void Grind_EngineConfigureAdr152(const bool fill_time_place,
                                  const int slot_near_reserve,
                                  const double entry_horizon_pips = 0.0)
{
   g_grind_fill_time_place = fill_time_place;
   g_grind_slot_near_reserve = slot_near_reserve;
   g_grind_engine_entry_horizon_pips = entry_horizon_pips;
}

//+------------------------------------------------------------------+
bool Grind_EntryHorizonActive()
{
   return (g_grind_engine_entry_horizon_pips > 0.0);
}

//+------------------------------------------------------------------+
void Grind_Adr152AssertHeldPendingExclusive(const GrindSideState &side)
{
   if(side.add_held && side.add_pending_ticket != 0) {
      if(g_grind_order_test_active)
         g_grind_order_test_last_critical = "ADR152_HELD_PENDING_EXCLUSIVE";
   }
}

//+------------------------------------------------------------------+
bool Grind_EntryHorizonClampAddTarget(const bool is_long,
                                       const double add_target,
                                       double &clamped_out)
{
   const double bid = Grind_MarketBid();
   const double ask = Grind_MarketAsk();
   const long stops = Grind_MarketStopsLevel();
   if(is_long) {
      Grind_Adr013ClampBuy(add_target, bid, _Point, stops, clamped_out);
      return Grind_BuyLimitMarketable(clamped_out, ask);
   }
   Grind_Adr013ClampSell(add_target, bid, ask, _Point, stops, clamped_out);
   return Grind_SellLimitMarketable(clamped_out, bid);
}

//+------------------------------------------------------------------+
bool Grind_EntryTransitionTryConsume(GrindSideState &side)
{
   if(side.entry_transitions_used >= GRIND_ENTRY_TRANSITIONS_MAX) {
      side.entry_transitions_exhausted = true;
      return false;
   }
   side.entry_transitions_used++;
   side.entry_transitions_exhausted = false;
   return true;
}

//+------------------------------------------------------------------+
void Grind_EntryHorizonCheckGap(GrindSideState &side,
                                const bool is_long,
                                const double mid,
                                const double target)
{
   if(!side.add_held)
      return;
   const bool beyond = is_long ? (mid < target - GRIND_PRICE_EPS)
                               : (mid > target + GRIND_PRICE_EPS);
   if(beyond && !side.add_gap_beyond_target)
      side.add_gap_missed++;
   side.add_gap_beyond_target = beyond;
}

//+------------------------------------------------------------------+
bool g_grind_breaker_enabled     = false;
bool g_grind_breaker_tripped     = false;
bool g_grind_breaker_premidnight = false;
bool g_grind_breaker_gated       = false;

void Grind_BreakerGateTransition(const bool was_gated, const bool now_gated,
                                 const bool is_reporter, const double floating,
                                 const double allowance, const string key)
{
   if(was_gated == now_gated || !is_reporter)
      return;
   const string detail =
      "{\"floating\":" + Grind_ArchiveJsonDouble(floating, 2) +
      ",\"allowance\":" + Grind_ArchiveJsonDouble(allowance, 2) +
      ",\"day\":\"" + key + "\"}";
   Grind_ArchiveMarker("INFO", now_gated ? "BREAKER_GATE_ON" : "BREAKER_GATE_OFF",
                       key, 0, detail);
}

bool Grind_BreakerBlocksEntries()
{
   return g_grind_breaker_enabled
          && (g_grind_breaker_tripped || g_grind_breaker_premidnight
              || g_grind_breaker_gated);
}

bool     g_grind_session_enabled           = false;
bool     g_grind_session_closed            = false;
datetime g_grind_session_closed_since      = 0;
datetime g_grind_session_last_cancel       = 0;
bool     g_grind_session_stuck_warned      = false;

bool Grind_SessionBlocksEntries()
{
   // stub
   return false;
}

bool Grind_EntriesBlocked()
{
   return Grind_ApiCounterEntryStopped() || Grind_BreakerBlocksEntries();
}

//+------------------------------------------------------------------+
string   g_grind_breaker_day_key           = "";
double   g_grind_breaker_anchor_value      = 0.0;
double   g_grind_breaker_allowance         = 0.0;
bool     g_grind_breaker_cancel_done       = false;
bool     g_grind_breaker_initial_known     = false;
double   g_grind_breaker_initial_deposit   = 0.0;
datetime g_grind_breaker_initial_time      = 0;
bool     g_grind_breaker_no_basis_emitted  = false;

void Grind_BreakerLoadInitialDeposit()
{
   if(g_grind_breaker_initial_known)
      return;
   const datetime to = TimeTradeServer() + 60;
   if(!HistorySelect(0, to))
      return;
   const int total = HistoryDealsTotal();
   datetime best_time = 0;
   double best_amount = 0.0;
   bool found = false;
   for(int i = 0; i < total; i++) {
      const ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0)
         continue;
      if((ENUM_DEAL_TYPE)HistoryDealGetInteger(ticket, DEAL_TYPE) != DEAL_TYPE_BALANCE)
         continue;
      const datetime t = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
      const double amt = HistoryDealGetDouble(ticket, DEAL_PROFIT);
      if(!found || t < best_time) {
         best_time = t;
         best_amount = amt;
         found = true;
      }
   }
   if(found) {
      g_grind_breaker_initial_known = true;
      g_grind_breaker_initial_deposit = best_amount;
      g_grind_breaker_initial_time = best_time;
   }
}

void Grind_EjectReport(const string code, const ulong ticket, const string detail)
{
   Grind_TelemetryEmit(g_grind_telemetry_instance, code, detail);
   Grind_ArchiveMarker("INFO", code, "", ticket, detail);
}

//+------------------------------------------------------------------+
bool Grind_BreakerMarkPremidnight(const string key)
{
   const string gv = "GRIND_BREAKER_PREMID_" + key;
   if(GlobalVariableCheck(gv))
      return false;
   GlobalVariableSet(gv, 1.0);
   Grind_GvMarkDirty();
   Grind_ArchiveMarker("INFO", "BREAKER_PREMIDNIGHT", key, 0,
                       "{\"day\":\"" + key + "\"}");
   return true;
}

//+------------------------------------------------------------------+
void Grind_BreakerAdoptPeerTrip(const string key)
{
   if(!g_grind_breaker_tripped
      && GlobalVariableCheck("GRIND_BREAKER_TRIPPED_" + key))
      g_grind_breaker_tripped = true;
}

//+------------------------------------------------------------------+
void Grind_BreakerCollectDealHistory(const datetime from, const datetime to,
                                     double &amounts[], datetime &times[], int &n)
{
   n = 0;
   if(!HistorySelect(from, to))
      return;
   const int total = HistoryDealsTotal();
   ArrayResize(amounts, total);
   ArrayResize(times, total);
   for(int i = 0; i < total; i++) {
      const ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0)
         continue;
      amounts[n] = HistoryDealGetDouble(ticket, DEAL_PROFIT)
                   + HistoryDealGetDouble(ticket, DEAL_SWAP)
                   + HistoryDealGetDouble(ticket, DEAL_COMMISSION)
                   + HistoryDealGetDouble(ticket, DEAL_FEE);
      times[n] = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
      n++;
   }
}

void Grind_BreakerOnTick(const ulong magic, const string slot, const bool enabled)
{
   g_grind_breaker_enabled = enabled;
   if(!enabled)
      return;

   const datetime gmt = TimeGMT();
   const string key = Grind_FtmoDayKey(gmt);
   if(key != g_grind_breaker_day_key) {
      g_grind_breaker_day_key = key;
      g_grind_breaker_tripped = false;
      g_grind_breaker_premidnight = false;
      g_grind_breaker_cancel_done = false;

      Grind_BreakerLoadInitialDeposit();
      g_grind_breaker_allowance = 0.05 * g_grind_breaker_initial_deposit;
      if(g_grind_breaker_allowance <= 0.0) {
         if(!g_grind_breaker_no_basis_emitted) {
            Grind_TelemetryCritical(g_grind_telemetry_instance, "BREAKER_NO_BASIS", "{}");
            g_grind_breaker_no_basis_emitted = true;
         }
         return;
      }

      const datetime boundary = Grind_FtmoDayStartGmt(gmt)
                                + (TimeTradeServer() - TimeGMT());
      double amounts[];
      datetime times[];
      int n = 0;
      Grind_BreakerCollectDealHistory(boundary, TimeTradeServer() + 60, amounts, times, n);
      const double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      g_grind_breaker_anchor_value = Grind_BreakerDayAnchor(balance, amounts, times, n, boundary,
                                                            g_grind_breaker_initial_deposit,
                                                            g_grind_breaker_initial_time);
      g_grind_breaker_tripped = GlobalVariableCheck("GRIND_BREAKER_TRIPPED_" + key);
   }

   const double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   const double balance = AccountInfoDouble(ACCOUNT_BALANCE);

   Grind_BreakerAdoptPeerTrip(key);

   if(!g_grind_breaker_tripped
      && Grind_BreakerShouldTrip(equity, g_grind_breaker_anchor_value,
                                 g_grind_breaker_allowance, 0.8)) {
      g_grind_breaker_tripped = true;
      GlobalVariableSet("GRIND_BREAKER_TRIPPED_" + key, 1.0);
      Grind_GvMarkDirty();
      const string detail =
         "{\"anchor\":" + Grind_ArchiveJsonDouble(g_grind_breaker_anchor_value, 2) +
         ",\"equity\":" + Grind_ArchiveJsonDouble(equity, 2) +
         ",\"allowance\":" + Grind_ArchiveJsonDouble(g_grind_breaker_allowance, 2) +
         ",\"day\":\"" + key + "\"}";
      Grind_TelemetryCritical(g_grind_telemetry_instance, "BREAKER_TRIPPED", detail);
   }

   if(g_grind_breaker_tripped && !g_grind_breaker_cancel_done) {
      Grind_CancelOwnEntryOrders(magic, slot);
      g_grind_breaker_cancel_done = true;
   }

   g_grind_breaker_premidnight = Grind_BreakerPreMidnightHalt(Grind_FtmoSecondsIntoDay(gmt),
                                                             equity, balance,
                                                             g_grind_breaker_allowance);
   if(g_grind_breaker_premidnight)
      Grind_BreakerMarkPremidnight(key);

   const bool was_gated = g_grind_breaker_gated;
   g_grind_breaker_gated = Grind_BreakerFloatGate(was_gated, balance - equity,
                                                  g_grind_breaker_allowance);
   Grind_BreakerGateTransition(was_gated, g_grind_breaker_gated,
                             g_grind_mae_is_reporter, balance - equity,
                             g_grind_breaker_allowance, key);
}

//+------------------------------------------------------------------+
void Grind_SessionStep(const ulong magic, const string slot, const bool enabled,
                       const datetime gmt, const bool from_tick)
{
   // stub
}

//+------------------------------------------------------------------+
int Grind_ApplyEntryHorizon(GrindSideState &side,
                             const bool is_long,
                             const ulong magic,
                             const string slot,
                             const double add_pips,
                             const double deadband_pips,
                             const int max_layers,
                             const double lots)
{
   if(!Grind_EntryHorizonActive())
      return 0;

   const int n = Grind_SideDepth(side);
   if(n <= 0 || !Grind_CanPlaceEntryLayer(n, max_layers))
      return 0;
   if(!Grind_CapAllowsEntry(is_long, lots))
      return 0;
   if(Grind_EntriesBlocked())
      return 0;

   Grind_Adr152AssertHeldPendingExclusive(side);

   const double H_price = Grind_PipsToPrice(g_grind_engine_entry_horizon_pips, _Point);
   const double Hc_price = Grind_PipsToPrice(g_grind_engine_entry_horizon_pips
                                             * GRIND_ENTRY_HORIZON_CANCEL_X, _Point);
   const double floor_price = Grind_PipsToPrice(add_pips, _Point);

   double add_target = Grind_ComputeAddTarget(side, is_long, add_pips);
   if(add_target <= 0.0)
      return 0;

   if(side.add_held || side.add_pending_ticket != 0)
      side.add_held_target = add_target;

   double clamped = add_target;
   if(!Grind_EntryHorizonClampAddTarget(is_long, add_target, clamped))
      return 0;

   const double bid = Grind_MarketBid();
   const double ask = Grind_MarketAsk();
   const double mid = Grind_MidPrice(bid, ask);
   const double dist = MathAbs(add_target - mid);

   Grind_EntryHorizonCheckGap(side, is_long, mid, add_target);

   const bool in_floor = (dist <= floor_price + GRIND_PRICE_EPS);
   const bool in_place = in_floor || (dist <= H_price + GRIND_PRICE_EPS);
   const bool in_cancel = (dist > Hc_price + GRIND_PRICE_EPS);

   int transitions = 0;

   if(in_floor) {
      if(side.add_held)
         side.add_held = false;
      if(side.add_pending_ticket != 0) {
         const double resting = Grind_OrderGetPriceOpen(side.add_pending_ticket);
         if(!Grind_PriceWithinDeadband(resting, clamped, deadband_pips, _Point))
            Grind_ModifyPendingPrice(side.add_pending_ticket, clamped, magic);
         return transitions;
      }
      if(!g_grind_ent_sent_this_tick && Grind_EntryTransitionTryConsume(side)) {
         transitions++;
         if(!Grind_SendNextAddEnt(side, is_long, magic, slot, add_pips, max_layers, lots, false))
            side.entry_transitions_used--;
      }
      return transitions;
   }

   if(in_cancel) {
      if(side.add_pending_ticket != 0 && Grind_SelectOurOrder(side.add_pending_ticket, magic)) {
         if(Grind_EntryTransitionTryConsume(side)) {
            transitions++;
            if(Grind_CancelPendingOrder(side.add_pending_ticket, magic)) {
               side.add_pending_ticket = 0;
               side.add_held = true;
               side.add_held_target = add_target;
            } else {
               side.entry_transitions_used--;
               transitions--;
            }
         }
      } else if(side.add_pending_ticket == 0 && !side.add_held) {
         side.add_held = true;
         side.add_held_target = add_target;
      }
      return transitions;
   }

   if(in_place) {
      if(side.add_pending_ticket == 0 && !g_grind_ent_sent_this_tick) {
         const bool was_held = side.add_held;
         if(!was_held || Grind_EntryTransitionTryConsume(side)) {
            if(was_held)
               transitions++;
            if(Grind_SendNextAddEnt(side, is_long, magic, slot, add_pips, max_layers, lots, false)) {
               side.add_held = false;
            } else if(was_held) {
               side.entry_transitions_used--;
               transitions--;
            }
         }
      }
      if(side.add_pending_ticket != 0) {
         const double resting = Grind_OrderGetPriceOpen(side.add_pending_ticket);
         if(!Grind_PriceWithinDeadband(resting, clamped, deadband_pips, _Point))
            Grind_ModifyPendingPrice(side.add_pending_ticket, clamped, magic);
      }
      return transitions;
   }

   return transitions;
}

//+------------------------------------------------------------------+
void Grind_Adr152ResetDueFlags()
{
   g_grind_add_due_long = false;
   g_grind_add_due_short = false;
   g_grind_add_due_attempted_long = false;
   g_grind_add_due_attempted_short = false;
}

//+------------------------------------------------------------------+
void Grind_Adr152ClearDueForSide(const bool is_long)
{
   if(is_long)
      g_grind_add_due_long = false;
   else
      g_grind_add_due_short = false;
}

//+------------------------------------------------------------------+
void Grind_Adr152SetDueForSide(const bool is_long)
{
   if(is_long)
      g_grind_add_due_long = true;
   else
      g_grind_add_due_short = true;
}

//+------------------------------------------------------------------+
void Grind_HaltCritical(const string reason)
{
   g_grind_halted = true;
   if(g_grind_order_test_active)
      g_grind_order_test_last_critical = reason;
   Grind_TelemetryCritical(g_grind_telemetry_instance, reason);
   Grind_CancelOwnEntryOrders(g_grind_recon_magic, g_grind_recon_slot);
   Grind_Adr152ResetDueFlags();
}

//+------------------------------------------------------------------+
bool Grind_ValidateAddLabelIndex(const int computed_depth, const int label_index)
{
   if(computed_depth == label_index)
      return true;
   g_grind_halt_reason = "HALT_ADD_INDEX_MISMATCH";
   const string detail = StringFormat("computed=%d label=%d", computed_depth, label_index);
   Grind_HaltCritical("HALT_ADD_INDEX_MISMATCH " + detail);
   return false;
}

//+------------------------------------------------------------------+
bool Grind_GuardsAllowTrading(const ulong magic, const double lots)
{
   if(g_grind_halted || g_grind_api_counter_broken)
      return false;

   const long trade_mode = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE);
   if(!Grind_MarketTradeModeFull(trade_mode))
      return false;

   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick))
      return false;
   if(Grind_FeedStaleAfterTick(tick.time_msc, g_grind_last_feed_tick_msc))
      return false;

   return true;
}

//+------------------------------------------------------------------+
int Grind_SideDepth(const GrindSideState &side)
{
   return ArraySize(side.layers);
}

//+------------------------------------------------------------------+
int Grind_SideNextIndex(const GrindSideState &side)
{
   const int n = Grind_SideDepth(side);
   if(n <= 0)
      return 0;
   int max_idx = side.layers[0].layer_index;
   for(int i = 1; i < n; i++) {
      if(side.layers[i].layer_index > max_idx)
         max_idx = side.layers[i].layer_index;
   }
   return max_idx + 1;
}

//+------------------------------------------------------------------+
int Grind_FindDeepestLayerArrayIndex(const GrindSideState &side)
{
   const int n = Grind_SideDepth(side);
   if(n <= 0)
      return -1;
   int best = 0;
   for(int i = 1; i < n; i++) {
      if(side.layers[i].layer_index > side.layers[best].layer_index)
         best = i;
   }
   return best;
}

//+------------------------------------------------------------------+
bool Grind_TryPlaceL0(GrindSideState &side,
                      const bool is_long,
                      const double target_price,
                      const ulong magic,
                      const string slot,
                      const int max_layers,
                      const double lots)
{
   if(!Grind_CanPlaceEntryLayer(Grind_SideDepth(side), max_layers))
      return false;
   if(!Grind_CapAllowsEntry(is_long, lots))
      return false;

   if(side.l0_pending_ticket != 0) {
      if(!Grind_SelectOurOrder(side.l0_pending_ticket, magic)) {
         if(Grind_SelectOurPosition(side.l0_pending_ticket, magic))
            return false;
         side.l0_pending_ticket = 0;
      } else {
         // ADR-123 place-once: our L0 is resting; leave it untouched.
         // Re-centering is ADR-124's job and is fill-triggered.
         return false;
      }
   }

   if(g_grind_ent_sent_this_tick)
      return false;
   if(Grind_EntriesBlocked())
      return false;

   double slot_token = 0.0;
   if(!Grind_SlotLockAcquire(slot_token))
      return false;

   const long limit = Grind_SlotAccountLimit();
   const int used = Grind_SlotUsed();
   const int resting_ent = Grind_SlotRestingEnt();
   g_grind_last_guard_total = used + resting_ent;
   g_grind_last_guard_time = TimeGMT();
   if(!Grind_SlotEntryAllowed(limit, used, resting_ent, true)) {
      Grind_SlotLockRelease(slot_token);
      return false;
   }

   const string side_letter = is_long ? "L" : "S";
   const string comment = GrindCommentBuild(slot, side_letter, 0, "ENT");
   const ENUM_ORDER_TYPE otype = is_long ? ORDER_TYPE_BUY_LIMIT : ORDER_TYPE_SELL_LIMIT;
   side.l0_pending_ticket = Grind_PlaceLimit(otype, target_price, lots, magic, comment);
   Grind_SlotLockRelease(slot_token);
   if(side.l0_pending_ticket > 0)
      g_grind_ent_sent_this_tick = true;
   return (side.l0_pending_ticket > 0);
}

//+------------------------------------------------------------------+
void Grind_ReconcileStrayL0(GrindSideState &side,
                            const bool is_long,
                            const ulong magic)
{
   if(Grind_SideDepth(side) == 0)
      return;
   if(side.l0_pending_ticket == 0)
      return;

   if(Grind_SelectOurOrder(side.l0_pending_ticket, magic)) {
      Grind_ArchiveMarker("WARN", "STRAY_L0_CANCEL", "", side.l0_pending_ticket,
                          StringFormat("{\"side\":\"%s\",\"depth\":%d}",
                                       is_long ? "L" : "S", Grind_SideDepth(side)));
      Print(Grind_LogTag(), "WARN GRIND_STRAY_L0 cancel side=", is_long ? "L" : "S",
            " ticket=", side.l0_pending_ticket,
            " depth=", Grind_SideDepth(side));
      if(Grind_CancelPendingOrder(side.l0_pending_ticket, magic))
         side.l0_pending_ticket = 0;
      return;
   }

   if(Grind_SelectOurPosition(side.l0_pending_ticket, magic))
      return;

   Grind_ArchiveMarker("INFO", "STRAY_L0_CLEARED_GONE", "", side.l0_pending_ticket,
                       StringFormat("{\"side\":\"%s\"}", is_long ? "L" : "S"));
   Print(Grind_LogTag(), "INFO GRIND_STRAY_L0 cleared-gone side=", is_long ? "L" : "S",
         " ticket=", side.l0_pending_ticket);
   side.l0_pending_ticket = 0;
}

//+------------------------------------------------------------------+
bool Grind_TryPlaceExitForLayer(GrindLayer &layer,
                                const bool is_long,
                                const ulong magic,
                                const string slot,
                                const double lots)
{
   if(layer.exit_order_ticket != 0 || layer.exit_position_ticket != 0)
      return false;
   const long limit = Grind_SlotAccountLimit();
   const int used = Grind_SlotUsed();
   if(!Grind_SlotExitAllowed(limit, used))
      return false;
   const string side_letter = is_long ? "L" : "S";
   const string comment = GrindCommentBuild(slot, side_letter, layer.layer_index, "EXT");
   const ENUM_ORDER_TYPE otype = is_long ? ORDER_TYPE_SELL_LIMIT : ORDER_TYPE_BUY_LIMIT;
   layer.exit_order_ticket = Grind_PlaceLimit(otype, layer.exit_target, lots, magic, comment);
   return (layer.exit_order_ticket > 0);
}

//+------------------------------------------------------------------+
void Grind_OnSideCapTransition(GrindSideState &side, const int depth, const int max_layers)
{
   if(depth >= max_layers && !side.cap_warn_emitted) {
      side.cap_warn_emitted = true;
      Grind_TelemetryEmit(g_grind_telemetry_instance, "WARN_LAYER_CAP_REACHED",
                          StringFormat("{\"depth\":%d}", depth));
   }
}

//+------------------------------------------------------------------+
bool Grind_DealWasProcessed(const ulong deal_ticket)
{
   for(int i = 0; i < g_grind_processed_deal_count; i++)
      if(g_grind_processed_deals[i] == deal_ticket)
         return true;
   return false;
}

//+------------------------------------------------------------------+
void Grind_MarkDealProcessed(const ulong deal_ticket)
{
   if(Grind_DealWasProcessed(deal_ticket))
      return;
   ArrayResize(g_grind_processed_deals, g_grind_processed_deal_count + 1);
   g_grind_processed_deals[g_grind_processed_deal_count++] = deal_ticket;
}

//+------------------------------------------------------------------+
void Grind_AppendLayer(GrindSideState &side,
                       const double entry_price,
                       const ulong position_ticket,
                       const int layer_index,
                       const double exit_pips,
                       const bool is_long)
{
   const int n = Grind_SideDepth(side);
   ArrayResize(side.layers, n + 1);
   side.layers[n].entry_price = Grind_Normalize(entry_price);
   side.layers[n].position_ticket = position_ticket;
   side.layers[n].layer_index = layer_index;
   side.layers[n].exit_order_ticket = 0;
   side.layers[n].exit_position_ticket = 0;
   side.layers[n].exit_target = Grind_ExitQFormulaTarget(entry_price, exit_pips, _Point, is_long,
                                                         position_ticket);
   g_grind_fill_count++;
}

//+------------------------------------------------------------------+
void Grind_RemoveLayerAt(GrindSideState &side, const int layer_idx)
{
   const int n = Grind_SideDepth(side);
   if(layer_idx < 0 || layer_idx >= n)
      return;
   for(int i = layer_idx; i < n - 1; i++)
      side.layers[i] = side.layers[i + 1];
   ArrayResize(side.layers, n - 1);
   g_grind_scalp_count++;
   if(Grind_SideDepth(side) == 0) {
      side.cap_warn_emitted = false;
   }
}

//+------------------------------------------------------------------+
int Grind_FindLayerByIndex(GrindSideState &side, const int layer_index)
{
   for(int i = 0; i < Grind_SideDepth(side); i++) {
      if(side.layers[i].layer_index == layer_index)
         return i;
   }
   return -1;
}

//+------------------------------------------------------------------+
int Grind_FindLayerByExitOrder(GrindSideState &side, const ulong exit_order_ticket)
{
   for(int i = 0; i < Grind_SideDepth(side); i++)
      if(side.layers[i].exit_order_ticket == exit_order_ticket)
         return i;
   return -1;
}

//+------------------------------------------------------------------+
int Grind_FindLayerByPosition(GrindSideState &side, const ulong position_id)
{
   for(int i = 0; i < Grind_SideDepth(side); i++) {
      if(side.layers[i].position_ticket == position_id)
         return i;
      if(side.layers[i].exit_position_ticket == position_id)
         return i;
   }
   return -1;
}

//+------------------------------------------------------------------+
double Grind_ComputeAddTarget(const GrindSideState &side,
                              const bool is_long,
                              const double add_pips)
{
   const int depth_idx = Grind_FindDeepestLayerArrayIndex(side);
   if(depth_idx < 0)
      return 0.0;
   const double anchor = side.layers[depth_idx].entry_price;
   return Grind_AddTargetPrice(anchor, add_pips, _Point, is_long ? 1 : -1);
}

//+------------------------------------------------------------------+
bool Grind_AddTargetNearMarket(const double target,
                               const double mid,
                               const double add_pips)
{
   return (MathAbs(target - mid) <= Grind_PipsToPrice(add_pips, _Point) + GRIND_PRICE_EPS);
}

//+------------------------------------------------------------------+
bool Grind_SendNextAddEnt(GrindSideState &side,
                          const bool is_long,
                          const ulong magic,
                          const string slot,
                          const double add_pips,
                          const int max_layers,
                          const double lots,
                          const bool use_try_lock,
                          const long fill_deal_time_msc = 0)
{
   const int n = Grind_SideDepth(side);
   if(n <= 0 || !Grind_CanPlaceEntryLayer(n, max_layers))
      return false;
   if(!Grind_CapAllowsEntry(is_long, lots))
      return false;
   if(Grind_EntriesBlocked())
      return false;

   if(side.add_pending_ticket != 0) {
      if(Grind_SelectOurOrder(side.add_pending_ticket, magic))
         return false;
      if(Grind_SelectOurPosition(side.add_pending_ticket, magic))
         return false;
      side.add_pending_ticket = 0;
   }

   const int required_index = Grind_SideNextIndex(side);
   const int next_layer = required_index;

   double add_target = Grind_ComputeAddTarget(side, is_long, add_pips);
   if(add_target <= 0.0)
      return false;

   const double bid = Grind_MarketBid();
   const double ask = Grind_MarketAsk();
   const long stops = Grind_MarketStopsLevel();
   double clamped = add_target;
   if(is_long)
      Grind_Adr013ClampBuy(add_target, bid, _Point, stops, clamped);
   else
      Grind_Adr013ClampSell(add_target, bid, ask, _Point, stops, clamped);

   if(is_long && !Grind_BuyLimitMarketable(clamped, ask))
      return false;
   if(!is_long && !Grind_SellLimitMarketable(clamped, bid))
      return false;

   if(!Grind_ValidateAddLabelIndex(required_index, next_layer)) {
      Grind_Adr152ClearDueForSide(is_long);
      return false;
   }

   if(g_grind_ent_sent_this_tick) {
      if(use_try_lock)
         Grind_Adr152SetDueForSide(is_long);
      return false;
   }

   const double mid = Grind_MidPrice(bid, ask);
   const bool near_market = Grind_AddTargetNearMarket(clamped, mid, add_pips);

   double slot_token = 0.0;
   if(use_try_lock) {
      if(!Grind_SlotLockTryAcquire(slot_token)) {
         Grind_Adr152SetDueForSide(is_long);
         return false;
      }
   } else {
      if(!Grind_SlotLockAcquire(slot_token))
         return false;
   }

   const long limit = Grind_SlotAccountLimit();
   const int used = Grind_SlotUsed();
   const int resting_ent = Grind_SlotRestingEnt();
   g_grind_last_guard_total = used + resting_ent;
   g_grind_last_guard_time = TimeGMT();
   if(!Grind_SlotEntryAllowed(limit, used, resting_ent, near_market)) {
      if(!near_market)
         g_grind_near_reserve_blocks++;
      Grind_SlotLockRelease(slot_token);
      Grind_Adr152ClearDueForSide(is_long);
      return false;
   }

   const string side_letter = is_long ? "L" : "S";
   const string comment = GrindCommentBuild(slot, side_letter, next_layer, "ENT");
   const ENUM_ORDER_TYPE otype = is_long ? ORDER_TYPE_BUY_LIMIT : ORDER_TYPE_SELL_LIMIT;
   side.add_pending_ticket = Grind_PlaceLimit(otype, clamped, lots, magic, comment);
   Grind_SlotLockRelease(slot_token);
   if(side.add_pending_ticket > 0) {
      g_grind_ent_sent_this_tick = true;
      if(fill_deal_time_msc > 0) {
         const long now_msc = Grind_MarketTimeMsc();
         g_grind_entry_place_latency_ms = (now_msc > fill_deal_time_msc)
                                          ? (now_msc - fill_deal_time_msc)
                                          : 0;
      } else {
         g_grind_entry_place_latency_ms = 0;
      }
      Grind_Adr152ClearDueForSide(is_long);
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
void Grind_TryPlaceAddAtFill(GrindSideState &side,
                              const bool is_long,
                              const ulong magic,
                              const string slot,
                              const double add_pips,
                              const double deadband_pips,
                              const int max_layers,
                              const double lots,
                              const ulong deal_ticket)
{
   if(!g_grind_fill_time_place)
      return;
   if(Grind_EntriesBlocked())
      return;

   g_grind_entry_place_latency_ms = 0;
   const long fill_deal_time_msc = (long)Grind_DealGetInteger(deal_ticket, DEAL_TIME_MSC);
   if(Grind_EntryHorizonActive()) {
      Grind_ApplyEntryHorizon(side, is_long, magic, slot, add_pips, deadband_pips,
                              max_layers, lots);
   } else {
      Grind_SendNextAddEnt(side, is_long, magic, slot, add_pips, max_layers, lots,
                           true, fill_deal_time_msc);
   }
}

//+------------------------------------------------------------------+
void Grind_ServiceDueAddFlags(const ulong magic,
                              const string slot,
                              const double add_pips,
                              const double deadband_pips,
                              const int max_layers,
                              const double lots)
{
   if(!g_grind_fill_time_place)
      return;

   if(g_grind_add_due_long && !g_grind_add_due_attempted_long) {
      g_grind_add_due_attempted_long = true;
      const int depth = Grind_SideDepth(g_grind_long);
      if(depth <= 0 || !Grind_CanPlaceEntryLayer(depth, max_layers)) {
         g_grind_add_due_long = false;
      } else if(g_grind_long.add_pending_ticket != 0 &&
                Grind_SelectOurOrder(g_grind_long.add_pending_ticket, magic)) {
         // defer stale-label handling to Grind_EnsureAddNext
      } else if(Grind_EntryHorizonActive()) {
         Grind_EnsureAddNext(g_grind_long, true, magic, slot, add_pips, deadband_pips,
                             max_layers, lots);
         g_grind_add_due_long = false;
      } else {
         Grind_SendNextAddEnt(g_grind_long, true, magic, slot, add_pips, max_layers, lots, false);
         g_grind_add_due_long = false;
      }
   }

   if(g_grind_add_due_short && !g_grind_add_due_attempted_short) {
      g_grind_add_due_attempted_short = true;
      const int depth = Grind_SideDepth(g_grind_short);
      if(depth <= 0 || !Grind_CanPlaceEntryLayer(depth, max_layers)) {
         g_grind_add_due_short = false;
      } else if(g_grind_short.add_pending_ticket != 0 &&
                Grind_SelectOurOrder(g_grind_short.add_pending_ticket, magic)) {
         // defer stale-label handling to Grind_EnsureAddNext
      } else if(Grind_EntryHorizonActive()) {
         Grind_EnsureAddNext(g_grind_short, false, magic, slot, add_pips, deadband_pips,
                             max_layers, lots);
         g_grind_add_due_short = false;
      } else {
         Grind_SendNextAddEnt(g_grind_short, false, magic, slot, add_pips, max_layers, lots, false);
         g_grind_add_due_short = false;
      }
   }
}

//+------------------------------------------------------------------+
void Grind_EnsureAddNext(GrindSideState &side,
                         const bool is_long,
                         const ulong magic,
                         const string slot,
                         const double add_pips,
                         const double deadband_pips,
                         const int max_layers,
                         const double lots)
{
   const int n = Grind_SideDepth(side);
   const int required_index = Grind_SideNextIndex(side);

   if(side.add_pending_ticket != 0) {
      if(!Grind_SelectOurOrder(side.add_pending_ticket, magic)) {
         if(Grind_SelectOurPosition(side.add_pending_ticket, magic))
            return;
         side.add_pending_ticket = 0;
      } else {
         const string resting_comment = Grind_OrderGetComment(side.add_pending_ticket);
         string c_slot, c_side, c_role;
         int parsed_layer = -1;
         const bool label_ok = GrindCommentParse(resting_comment, c_slot, c_side,
                                                 parsed_layer, c_role)
                               && parsed_layer == required_index;
         if(!label_ok) {
            Grind_Adr152ClearDueForSide(is_long);
            if(g_grind_recon_verbose) {
               string label_txt = "UNPARSEABLE";
               if(GrindCommentParse(resting_comment, c_slot, c_side, parsed_layer, c_role))
                  label_txt = StringFormat("L%02d", parsed_layer);
               Print(Grind_LogTag(), "INFO: grind reconcile remove stale add ticket=",
                     side.add_pending_ticket,
                     " label=", label_txt,
                     " depth=", required_index);
            }
            if(Grind_CancelPendingOrder(side.add_pending_ticket, magic))
               side.add_pending_ticket = 0;
            return;
         }
      }
   }

   if(n <= 0 || !Grind_CanPlaceEntryLayer(n, max_layers)) {
      Grind_Adr152ClearDueForSide(is_long);
      return;
   }
   if(!Grind_CapAllowsEntry(is_long, lots))
      return;
   if(Grind_EntriesBlocked())
      return;

   if(Grind_EntryHorizonActive()) {
      Grind_ApplyEntryHorizon(side, is_long, magic, slot, add_pips, deadband_pips,
                              max_layers, lots);
      Grind_Adr152AssertHeldPendingExclusive(side);
      return;
   }

   const int next_layer = required_index;

   double add_target = Grind_ComputeAddTarget(side, is_long, add_pips);
   if(add_target <= 0.0)
      return;

   const double bid = Grind_MarketBid();
   const double ask = Grind_MarketAsk();
   const long stops = Grind_MarketStopsLevel();
   double clamped = add_target;
   if(is_long)
      Grind_Adr013ClampBuy(add_target, bid, _Point, stops, clamped);
   else
      Grind_Adr013ClampSell(add_target, bid, ask, _Point, stops, clamped);

   if(is_long && !Grind_BuyLimitMarketable(clamped, ask))
      return;
   if(!is_long && !Grind_SellLimitMarketable(clamped, bid))
      return;

   if(side.add_pending_ticket != 0) {
      const double resting = Grind_OrderGetPriceOpen(side.add_pending_ticket);
      if(Grind_PriceWithinDeadband(resting, clamped, deadband_pips, _Point))
         return;
      Grind_ModifyPendingPrice(side.add_pending_ticket, clamped, magic);
      return;
   }

   if(!Grind_ValidateAddLabelIndex(required_index, next_layer))
      return;

   if(g_grind_ent_sent_this_tick)
      return;

   Grind_SendNextAddEnt(side, is_long, magic, slot, add_pips, max_layers, lots, false);
}

//+------------------------------------------------------------------+
// Unit-test hooks for deal fill processing (no HistoryDealSelect when active).
bool   g_grind_deal_test_active = false;

struct GrindDealTestRecord
{
   ulong  deal_ticket;
   string symbol;
   long   magic;
   string comment;
   long   entry_type;
   ulong  order_ticket;
   ulong  position_id;
   double price;
   double profit;
   double swap;
   double commission;
   datetime deal_time;
};

GrindDealTestRecord g_grind_deal_test_records[];
int g_grind_deal_test_count = 0;

//+------------------------------------------------------------------+
void Grind_DealTestReset()
{
   g_grind_deal_test_active = false;
   ArrayResize(g_grind_deal_test_records, 0);
   g_grind_deal_test_count = 0;
}

//+------------------------------------------------------------------+
bool Grind_DealTestFind(const ulong deal_ticket, GrindDealTestRecord &out)
{
   for(int i = 0; i < g_grind_deal_test_count; i++) {
      if(g_grind_deal_test_records[i].deal_ticket == deal_ticket) {
         out = g_grind_deal_test_records[i];
         return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
bool Grind_DealSelect(const ulong deal_ticket)
{
   if(g_grind_deal_test_active) {
      GrindDealTestRecord rec;
      return Grind_DealTestFind(deal_ticket, rec);
   }
   return HistoryDealSelect(deal_ticket);
}

//+------------------------------------------------------------------+
string Grind_DealGetString(const ulong deal_ticket, const ENUM_DEAL_PROPERTY_STRING prop)
{
   if(g_grind_deal_test_active) {
      GrindDealTestRecord rec;
      if(!Grind_DealTestFind(deal_ticket, rec))
         return "";
      if(prop == DEAL_SYMBOL)
         return rec.symbol;
      if(prop == DEAL_COMMENT)
         return rec.comment;
      return "";
   }
   return HistoryDealGetString(deal_ticket, prop);
}

//+------------------------------------------------------------------+
long Grind_DealGetInteger(const ulong deal_ticket, const ENUM_DEAL_PROPERTY_INTEGER prop)
{
   if(g_grind_deal_test_active) {
      GrindDealTestRecord rec;
      if(!Grind_DealTestFind(deal_ticket, rec))
         return 0;
      if(prop == DEAL_MAGIC)
         return rec.magic;
      if(prop == DEAL_ENTRY)
         return rec.entry_type;
      if(prop == DEAL_ORDER)
         return (long)rec.order_ticket;
      if(prop == DEAL_POSITION_ID)
         return (long)rec.position_id;
      if(prop == DEAL_TIME)
         return (long)rec.deal_time;
      if(prop == DEAL_TIME_MSC)
         return (long)rec.deal_time * 1000;
      return 0;
   }
   return HistoryDealGetInteger(deal_ticket, prop);
}

//+------------------------------------------------------------------+
double Grind_DealGetDouble(const ulong deal_ticket, const ENUM_DEAL_PROPERTY_DOUBLE prop)
{
   if(g_grind_deal_test_active) {
      GrindDealTestRecord rec;
      if(!Grind_DealTestFind(deal_ticket, rec))
         return 0.0;
      if(prop == DEAL_PRICE)
         return rec.price;
      if(prop == DEAL_PROFIT)
         return rec.profit;
      if(prop == DEAL_SWAP)
         return rec.swap;
      if(prop == DEAL_COMMISSION)
         return rec.commission;
      return 0.0;
   }
   return HistoryDealGetDouble(deal_ticket, prop);
}

//+------------------------------------------------------------------+
void Grind_HandleSideDealFill(GrindSideState &side,
                              const bool is_long,
                              const ulong deal_ticket,
                              const ulong magic,
                              const string slot,
                              const double exit_pips,
                              const double deadband_pips,
                              const int max_layers,
                              const double lots)
{
   if(Grind_DealWasProcessed(deal_ticket))
      return;
   if(!Grind_DealSelect(deal_ticket))
      return;

   if(Grind_DealGetString(deal_ticket, DEAL_SYMBOL) != _Symbol)
      return;
   if(!Grind_MagicMatches(Grind_DealGetInteger(deal_ticket, DEAL_MAGIC), magic))
      return;

   if(Grind_DealGetString(deal_ticket, DEAL_SYMBOL) != _Symbol)
      return;
   if(!Grind_MagicMatches(Grind_DealGetInteger(deal_ticket, DEAL_MAGIC), magic))
      return;

   const long entry_type = Grind_DealGetInteger(deal_ticket, DEAL_ENTRY);
   const ulong order_ticket = (ulong)Grind_DealGetInteger(deal_ticket, DEAL_ORDER);
   const ulong position_id = (ulong)Grind_DealGetInteger(deal_ticket, DEAL_POSITION_ID);
   const double deal_price = Grind_DealGetDouble(deal_ticket, DEAL_PRICE);

   if(entry_type == DEAL_ENTRY_OUT_BY) {
      // Both sides see every deal. Only the side whose layer owns this deal's
      // position marks it processed and completes the scalp.
      for(int i = 0; i < Grind_SideDepth(side); i++) {
         if(side.layers[i].position_ticket != position_id)
            continue;
         if(side.layers[i].exit_position_ticket == 0)
            continue;

         Grind_MarkDealProcessed(deal_ticket);

         const double deal_profit = Grind_DealGetDouble(deal_ticket, DEAL_PROFIT);
         const double deal_swap = Grind_DealGetDouble(deal_ticket, DEAL_SWAP);
         const double deal_commission = Grind_DealGetDouble(deal_ticket, DEAL_COMMISSION);
         const double net_pnl = Grind_AccumulateScalpPnl(deal_profit, deal_swap, deal_commission);
         const int stack_depth = Grind_SideDepth(side);
         const int layer_depth = side.layers[i].layer_index;
         const double entry_price = side.layers[i].entry_price;
         const datetime close_time = (datetime)Grind_DealGetInteger(deal_ticket, DEAL_TIME);
         const ulong closed_position = side.layers[i].position_ticket;
         const bool was_ejected = Grind_EjectIsEjected(closed_position);
         Grind_QueueScalpClosedEvent(g_grind_telemetry_instance,
                                     _Symbol,
                                     is_long ? "LONG" : "SHORT",
                                     entry_price,
                                     deal_price,
                                     layer_depth,
                                     stack_depth,
                                     net_pnl,
                                     close_time,
                                     was_ejected,
                                     (long)(TimeTradeServer() - TimeGMT()),
                                     AccountInfoInteger(ACCOUNT_LOGIN));
         if(was_ejected) {
            const double eject_off = Grind_EjectOffsetGet(closed_position);
            const string filled_detail =
               "{\"ticket\":" + IntegerToString((long)closed_position) +
               ",\"offset\":" + Grind_ArchiveJsonDouble(eject_off, 5) + "}";
            Grind_EjectReport("EJECT_FILLED", closed_position, filled_detail);
         }
         Grind_CarryShiftDelete(closed_position);
         Grind_CarryAccruedDelete(closed_position);
         Grind_EjectOffsetDelete(closed_position);
         Grind_RemoveLayerAt(side, i);
         Grind_ExitQManageSide(side, is_long, magic, slot, lots, exit_pips);
         return;
      }
      return;
   }

   const string deal_comment = Grind_DealGetString(deal_ticket, DEAL_COMMENT);
   string c_slot, c_side, c_role;
   int c_layer;
   if(!GrindCommentParse(deal_comment, c_slot, c_side, c_layer, c_role))
      return;
   if(c_slot != slot)
      return;
   if(is_long && c_side != "L")
      return;
   if(!is_long && c_side != "S")
      return;

   Grind_MarkDealProcessed(deal_ticket);

   if(c_role == "ENT") {
      if(order_ticket == side.l0_pending_ticket)
         side.l0_pending_ticket = 0;
      if(order_ticket == side.add_pending_ticket)
         side.add_pending_ticket = 0;

      Grind_AppendLayer(side, deal_price, position_id, c_layer, exit_pips, is_long);
      Grind_ExitQManageSide(side, is_long, magic, slot, lots, exit_pips);
      Grind_TryPlaceAddAtFill(side, is_long, magic, slot, g_grind_engine_add_pips,
                              deadband_pips, max_layers, lots, deal_ticket);

      if(c_layer == 0 && side.l0_pending_ticket != 0 &&
         side.l0_pending_ticket != order_ticket) {
         Grind_ArchiveMarker("WARN", "STRAY_L0_CANCEL_ON_FILL", "", side.l0_pending_ticket,
                             StringFormat("{\"side\":\"%s\",\"filled_order\":%I64u}",
                                          is_long ? "L" : "S", order_ticket));
         Print(Grind_LogTag(), "WARN GRIND_STRAY_L0 cancel on fill side=", is_long ? "L" : "S",
               " stray=", side.l0_pending_ticket, " filled_order=", order_ticket);
         if(Grind_CancelPendingOrder(side.l0_pending_ticket, magic))
            side.l0_pending_ticket = 0;
      }
      return;
   }

   if(c_role == "EXT" && entry_type == DEAL_ENTRY_IN) {
      int layer_idx = Grind_FindLayerByExitOrder(side, order_ticket);
      if(layer_idx < 0)
         layer_idx = Grind_FindLayerByIndex(side, c_layer);
      if(layer_idx < 0)
         return;

      const ulong orig_pos = side.layers[layer_idx].position_ticket;
      side.layers[layer_idx].exit_order_ticket = 0;
      side.layers[layer_idx].exit_position_ticket = position_id;

      if(orig_pos > 0 && position_id > 0) {
         if(is_long)
            Grind_QueueCloseBy(g_grind_long_closeby_queue, orig_pos, position_id);
         else
            Grind_QueueCloseBy(g_grind_short_closeby_queue, orig_pos, position_id);
      }

      const datetime fill_time = (datetime)Grind_DealGetInteger(deal_ticket, DEAL_TIME);
      const long fill_time_msc = Grind_DealGetInteger(deal_ticket, DEAL_TIME_MSC);
      const double spread_pips = Grind_SpreadPipsLive(_Point);
      Grind_QueueExitMicrostructureMeasure(fill_time, fill_time_msc, deal_price,
                                           is_long, spread_pips);
      return;
   }
}

//+------------------------------------------------------------------+
void Grind_TryRecenterOppositeL0(GrindSideState &opposite_side,
                                 const bool opposite_is_long,
                                 const double current_mid,
                                 const ulong magic,
                                 const string slot,
                                 const double width_pips,
                                 const double stranded_thresh_pips,
                                 const double deadband_pips)
{
   if(Grind_SideDepth(opposite_side) != 0)
      return;
   if(Grind_ApiCounterSoftWarnActive())
      return;
   if(opposite_side.l0_pending_ticket == 0)
      return;
   if(!Grind_SelectOurOrder(opposite_side.l0_pending_ticket, magic))
      return;

   const double resting = Grind_OrderGetPriceOpen(opposite_side.l0_pending_ticket);
   const double dist_pips = Grind_StrandedDistMidPips(resting, current_mid, _Point);
   if(!Grind_ShouldRecenter(dist_pips, stranded_thresh_pips))
      return;

   double target = opposite_is_long
                   ? Grind_StraddleBuyPrice(current_mid, width_pips, _Point)
                   : Grind_StraddleSellPrice(current_mid, width_pips, _Point);

   const double bid = Grind_MarketBid();
   const double ask = Grind_MarketAsk();
   const long stops = Grind_MarketStopsLevel();
   double clamped = target;
   if(opposite_is_long)
      Grind_Adr013ClampBuy(target, bid, _Point, stops, clamped);
   else
      Grind_Adr013ClampSell(target, bid, ask, _Point, stops, clamped);

   if(opposite_is_long && !Grind_BuyLimitMarketable(clamped, ask))
      return;
   if(!opposite_is_long && !Grind_SellLimitMarketable(clamped, bid))
      return;

   if(Grind_PriceWithinDeadband(resting, clamped, deadband_pips, _Point))
      return;

   Grind_ModifyPendingPrice(opposite_side.l0_pending_ticket, clamped, magic);
}

//+------------------------------------------------------------------+
void Grind_RetryMissingExits(const ulong magic,
                             const string slot,
                             const double lots)
{
   Grind_ExitQManageSide(g_grind_long, true, magic, slot, lots, g_grind_recon_exit_pips);
   Grind_ExitQManageSide(g_grind_short, false, magic, slot, lots, g_grind_recon_exit_pips);
}

//+------------------------------------------------------------------+
void Grind_OnTickEngine(const ulong magic,
                        const string slot,
                        const double width_pips,
                        const double exit_pips,
                        const double add_pips,
                        const double stranded_thresh_pips,
                        const double deadband_pips,
                        const int max_layers,
                        const double lots)
{
   if(!Grind_GuardsAllowTrading(magic, lots))
      return;

   g_grind_ent_sent_this_tick = false;
   g_grind_add_due_attempted_long = false;
   g_grind_add_due_attempted_short = false;
   g_grind_engine_add_pips = add_pips;
   Grind_RetryMissingExits(magic, slot, lots);
   Grind_ServiceDueAddFlags(magic, slot, add_pips, deadband_pips, max_layers, lots);

   Grind_ReconcileStrayL0(g_grind_long, true, magic);
   Grind_ReconcileStrayL0(g_grind_short, false, magic);

   const double bid = Grind_MarketBid();
   const double ask = Grind_MarketAsk();
   const double mid = Grind_MidPrice(bid, ask);
   const long stops = Grind_MarketStopsLevel();

   double buy_target = Grind_StraddleBuyPrice(mid, width_pips, _Point);
   double sell_target = Grind_StraddleSellPrice(mid, width_pips, _Point);
   Grind_Adr013ClampBuy(buy_target, bid, _Point, stops, buy_target);
   Grind_Adr013ClampSell(sell_target, bid, ask, _Point, stops, sell_target);

   if(Grind_SideDepth(g_grind_long) == 0 && Grind_BuyLimitMarketable(buy_target, ask))
      Grind_TryPlaceL0(g_grind_long, true, buy_target, magic, slot, max_layers, lots);
   if(Grind_SideDepth(g_grind_short) == 0 && Grind_SellLimitMarketable(sell_target, bid))
      Grind_TryPlaceL0(g_grind_short, false, sell_target, magic, slot, max_layers, lots);

   if(Grind_SideDepth(g_grind_long) > 0 && Grind_SideDepth(g_grind_short) == 0)
      Grind_TryRecenterOppositeL0(g_grind_short, false, mid, magic, slot,
                                  width_pips, stranded_thresh_pips, deadband_pips);
   if(Grind_SideDepth(g_grind_short) > 0 && Grind_SideDepth(g_grind_long) == 0)
      Grind_TryRecenterOppositeL0(g_grind_long, true, mid, magic, slot,
                                  width_pips, stranded_thresh_pips, deadband_pips);

   Grind_OnSideCapTransition(g_grind_long, Grind_SideDepth(g_grind_long), max_layers);
   Grind_OnSideCapTransition(g_grind_short, Grind_SideDepth(g_grind_short), max_layers);

   if(Grind_SideDepth(g_grind_long) > 0 || g_grind_long.add_pending_ticket != 0)
      Grind_EnsureAddNext(g_grind_long, true, magic, slot, add_pips, deadband_pips, max_layers, lots);
   if(Grind_SideDepth(g_grind_short) > 0 || g_grind_short.add_pending_ticket != 0)
      Grind_EnsureAddNext(g_grind_short, false, magic, slot, add_pips, deadband_pips, max_layers, lots);
}

//+------------------------------------------------------------------+
double Grind_ArchiveResolveOrderPrice(const ulong order_ticket)
{
   if(order_ticket == 0)
      return 0.0;

   if(!g_grind_order_test_active && !g_grind_deal_test_active) {
      if(HistoryOrderSelect(order_ticket)) {
         const double history_price = HistoryOrderGetDouble(order_ticket, ORDER_PRICE_OPEN);
         if(history_price > 0.0)
            return history_price;
      }
      if(OrderSelect(order_ticket)) {
         const double live_price = OrderGetDouble(ORDER_PRICE_OPEN);
         if(live_price > 0.0)
            return live_price;
      }
   }

   return Grind_ArchiveLookupSentPrice(order_ticket);
}

//+------------------------------------------------------------------+
void Grind_ArchiveRecordFill(const ulong deal_ticket, const ulong magic)
{
   if(!g_grind_archive_enabled)
      return;
   if(!Grind_DealSelect(deal_ticket))
      return;
   if(Grind_DealGetString(deal_ticket, DEAL_SYMBOL) != _Symbol)
      return;
   if(!Grind_MagicMatches(Grind_DealGetInteger(deal_ticket, DEAL_MAGIC), magic))
      return;

   const ulong order_ticket = (ulong)Grind_DealGetInteger(deal_ticket, DEAL_ORDER);
   const ulong position_id = (ulong)Grind_DealGetInteger(deal_ticket, DEAL_POSITION_ID);
   const long entry_type = Grind_DealGetInteger(deal_ticket, DEAL_ENTRY);
   const string comment = Grind_DealGetString(deal_ticket, DEAL_COMMENT);

   string deal_type_str = "SELL";
   if(g_grind_deal_test_active) {
      string c_slot, c_side, c_role;
      int c_layer;
      if(GrindCommentParse(comment, c_slot, c_side, c_layer, c_role))
         deal_type_str = (c_side == "L") ? "BUY" : "SELL";
   } else {
      deal_type_str = Grind_ArchiveDealTypeLabel(
         HistoryDealGetInteger(deal_ticket, DEAL_TYPE));
   }

   const double deal_price = Grind_DealGetDouble(deal_ticket, DEAL_PRICE);
   const double profit = Grind_DealGetDouble(deal_ticket, DEAL_PROFIT);
   const double swap = Grind_DealGetDouble(deal_ticket, DEAL_SWAP);
   const double commission = Grind_DealGetDouble(deal_ticket, DEAL_COMMISSION);
   const datetime deal_time = (datetime)Grind_DealGetInteger(deal_ticket, DEAL_TIME);
   const long deal_time_msc = Grind_DealGetInteger(deal_ticket, DEAL_TIME_MSC);
   double volume = 0.0;
   if(!g_grind_deal_test_active)
      volume = HistoryDealGetDouble(deal_ticket, DEAL_VOLUME);

   const double order_price_open = Grind_ArchiveResolveOrderPrice(order_ticket);

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const string fields = Grind_ArchiveFillLogFields(
      deal_ticket,
      order_ticket,
      position_id,
      Grind_ArchiveEntryTypeLabel(entry_type),
      deal_type_str,
      comment,
      deal_price,
      order_price_open,
      volume,
      profit,
      swap,
      commission,
      deal_time,
      deal_time_msc,
      g_grind_halted,
      g_grind_quarantined,
      point,
      magic);
   Grind_ArchiveEnqueue("fill_log", fields);
}

//+------------------------------------------------------------------+
void Grind_OnTradeTransactionEngine(const MqlTradeTransaction &trans,
                                    const ulong magic,
                                    const string slot,
                                    const double exit_pips,
                                    const double add_pips,
                                    const double deadband_pips,
                                    const int max_layers,
                                    const double lots)
{
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
      Grind_ArchiveRecordFill(trans.deal, magic);
   if(g_grind_halted)
      return;
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD)
      return;

   g_grind_engine_add_pips = add_pips;
   Grind_HandleSideDealFill(g_grind_long, true, trans.deal, magic, slot,
                            exit_pips, deadband_pips, max_layers, lots);
   Grind_HandleSideDealFill(g_grind_short, false, trans.deal, magic, slot,
                            exit_pips, deadband_pips, max_layers, lots);
}

bool Grind_ExitQFindExitDealPosition(const ulong order_ticket,
                                     const bool is_long,
                                     const ulong magic,
                                     ulong &position_out)
{
   position_out = 0;
   const string want_side = is_long ? "L" : "S";

   if(g_grind_deal_test_active) {
      for(int i = 0; i < g_grind_deal_test_count; i++) {
         const GrindDealTestRecord rec = g_grind_deal_test_records[i];
         if(rec.order_ticket != order_ticket)
            continue;
         if(rec.entry_type != DEAL_ENTRY_IN)
            continue;
         if(!Grind_MagicMatches(rec.magic, magic))
            continue;
         string c_slot, c_side, c_role;
         int c_layer;
         if(!GrindCommentParse(rec.comment, c_slot, c_side, c_layer, c_role))
            continue;
         if(c_side != want_side)
            continue;
         position_out = rec.position_id;
         return (position_out > 0);
      }
      return false;
   }

   const datetime from = TimeCurrent() - 30 * 86400;
   if(!HistorySelect(from, TimeCurrent()))
      return false;
   const int total = HistoryDealsTotal();
   for(int i = total - 1; i >= 0; i--) {
      const ulong deal_ticket = HistoryDealGetTicket(i);
      if(deal_ticket == 0 || !HistoryDealSelect(deal_ticket))
         continue;
      if((ulong)HistoryDealGetInteger(deal_ticket, DEAL_ORDER) != order_ticket)
         continue;
      if(HistoryDealGetInteger(deal_ticket, DEAL_ENTRY) != DEAL_ENTRY_IN)
         continue;
      if(!Grind_MagicMatches(HistoryDealGetInteger(deal_ticket, DEAL_MAGIC), magic))
         continue;
      string c_slot, c_side, c_role;
      int c_layer;
      const string comment = HistoryDealGetString(deal_ticket, DEAL_COMMENT);
      if(!GrindCommentParse(comment, c_slot, c_side, c_layer, c_role))
         continue;
      if(c_side != want_side)
         continue;
      position_out = (ulong)HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID);
      return (position_out > 0);
   }
   return false;
}

//+------------------------------------------------------------------+
bool Grind_ExitQHoldCancelLayer(GrindLayer &layer,
                                const bool is_long,
                                const ulong magic)
{
   if(layer.exit_order_ticket == 0)
      return true;

   const ulong ticket = layer.exit_order_ticket;
   if(Grind_CancelPendingOrder(ticket, magic)) {
      layer.exit_order_ticket = 0;
      Grind_CarryShiftDelete(layer.position_ticket);
      return true;
   }
   if(Grind_SelectOurOrder(ticket, magic))
      return false;

   ulong pos_out = 0;
   if(Grind_ExitQFindExitDealPosition(ticket, is_long, magic, pos_out) &&
      Grind_SelectOurPosition(pos_out, magic)) {
      layer.exit_position_ticket = pos_out;
      layer.exit_order_ticket = 0;
      if(is_long)
         Grind_QueueCloseBy(g_grind_long_closeby_queue, layer.position_ticket, pos_out);
      else
         Grind_QueueCloseBy(g_grind_short_closeby_queue, layer.position_ticket, pos_out);
   } else {
      layer.exit_order_ticket = 0;
      Grind_CarryShiftDelete(layer.position_ticket);
   }
   return true;
}

//+------------------------------------------------------------------+
void Grind_ExitQManageSide(GrindSideState &side,
                           const bool is_long,
                           const ulong magic,
                           const string slot,
                           const double lots,
                           const double exit_pips)
{
   const int n = Grind_SideDepth(side);
   if(n <= 0)
      return;

   double entries[];
   int layer_indices[];
   ArrayResize(entries, n);
   ArrayResize(layer_indices, n);
   for(int i = 0; i < n; i++) {
      entries[i] = side.layers[i].entry_price;
      layer_indices[i] = side.layers[i].layer_index;
   }

   int ranks[];
   Grind_ExitQRanks(entries, layer_indices, n, is_long, ranks);

   for(int i = 0; i < n; i++) {
      if(!Grind_ExitQAllowed(ranks[i], n) && side.layers[i].exit_order_ticket != 0)
         Grind_ExitQHoldCancelLayer(side.layers[i], is_long, magic);
   }

   for(int i = 0; i < n; i++) {
      if(!Grind_ExitQRequired(ranks[i], n))
         continue;
      if(side.layers[i].exit_order_ticket != 0 || side.layers[i].exit_position_ticket != 0)
         continue;

      const long limit = Grind_SlotAccountLimit();
      const int used = Grind_SlotUsed();
      if(!Grind_SlotExitAllowed(limit, used))
         continue;

      const double formula = Grind_ExitQFormulaTarget(side.layers[i].entry_price,
                                                      exit_pips, _Point, is_long,
                                                      side.layers[i].position_ticket);
      double price = formula;
      const bool clamped = Grind_ExitQClampPassive(is_long, formula, price);
      if(clamped)
         side.exit_clamped_promotions++;
      const string side_letter = is_long ? "L" : "S";
      const string comment = GrindCommentBuild(slot, side_letter, side.layers[i].layer_index, "EXT");
      const ENUM_ORDER_TYPE otype = is_long ? ORDER_TYPE_SELL_LIMIT : ORDER_TYPE_BUY_LIMIT;
      const ulong ticket = Grind_PlaceLimit(otype, price, lots, magic, comment);
      if(ticket == 0)
         continue;
      side.layers[i].exit_order_ticket = ticket;
      side.layers[i].exit_target = price;
      if(clamped || MathAbs(price - formula) > _Point * 0.5) {
         Grind_CarryRecordShift(side.layers[i].position_ticket, price - formula, true);
      } else {
         Grind_CarryShiftDelete(side.layers[i].position_ticket);
      }
   }
}

//+------------------------------------------------------------------+
void Grind_CancelOwnEntryOrders(const ulong magic, const string slot)
{
   if(g_grind_order_test_active) {
      for(int i = 0; i < g_grind_order_test_count; i++) {
         const GrindOrderTestRecord rec = g_grind_order_test_records[i];
         if(!Grind_MagicMatches(rec.magic, magic))
            continue;
         string c_slot, c_side, c_role;
         int c_layer;
         if(!GrindCommentParse(rec.comment, c_slot, c_side, c_layer, c_role))
            continue;
         if(c_role != "ENT" || c_slot != slot)
            continue;
         if(Grind_CancelPendingOrder(rec.ticket, magic)) {
            if(g_grind_long.l0_pending_ticket == rec.ticket)
               g_grind_long.l0_pending_ticket = 0;
            if(g_grind_long.add_pending_ticket == rec.ticket)
               g_grind_long.add_pending_ticket = 0;
            if(g_grind_short.l0_pending_ticket == rec.ticket)
               g_grind_short.l0_pending_ticket = 0;
            if(g_grind_short.add_pending_ticket == rec.ticket)
               g_grind_short.add_pending_ticket = 0;
         } else if(!Grind_SelectOurOrder(rec.ticket, magic)) {
            if(g_grind_long.l0_pending_ticket == rec.ticket)
               g_grind_long.l0_pending_ticket = 0;
            if(g_grind_long.add_pending_ticket == rec.ticket)
               g_grind_long.add_pending_ticket = 0;
            if(g_grind_short.l0_pending_ticket == rec.ticket)
               g_grind_short.l0_pending_ticket = 0;
            if(g_grind_short.add_pending_ticket == rec.ticket)
               g_grind_short.add_pending_ticket = 0;
         }
      }
      return;
   }

   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if(!Grind_MagicMatches(OrderGetInteger(ORDER_MAGIC), magic))
         continue;
      string c_slot, c_side, c_role;
      int c_layer;
      const string comment = OrderGetString(ORDER_COMMENT);
      if(!GrindCommentParse(comment, c_slot, c_side, c_layer, c_role))
         continue;
      if(c_role != "ENT" || c_slot != slot)
         continue;
      if(Grind_CancelPendingOrder(ticket, magic)) {
         if(g_grind_long.l0_pending_ticket == ticket)
            g_grind_long.l0_pending_ticket = 0;
         if(g_grind_long.add_pending_ticket == ticket)
            g_grind_long.add_pending_ticket = 0;
         if(g_grind_short.l0_pending_ticket == ticket)
            g_grind_short.l0_pending_ticket = 0;
         if(g_grind_short.add_pending_ticket == ticket)
            g_grind_short.add_pending_ticket = 0;
      } else if(!Grind_SelectOurOrder(ticket, magic)) {
         if(g_grind_long.l0_pending_ticket == ticket)
            g_grind_long.l0_pending_ticket = 0;
         if(g_grind_long.add_pending_ticket == ticket)
            g_grind_long.add_pending_ticket = 0;
         if(g_grind_short.l0_pending_ticket == ticket)
            g_grind_short.l0_pending_ticket = 0;
         if(g_grind_short.add_pending_ticket == ticket)
            g_grind_short.add_pending_ticket = 0;
      }
   }
}

//+------------------------------------------------------------------+
int Grind_OwnRestingEntryCount(const ulong magic, const string slot)
{
   // stub
   return 0;
}

#include "grind_heartbeat_detail.mqh"

#endif // GRIND_ENGINE_MQH
