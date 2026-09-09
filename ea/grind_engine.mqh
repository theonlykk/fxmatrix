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

//+------------------------------------------------------------------+
double Grind_Normalize(const double price)
{
   return NormalizeDouble(price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
}

// Live-market unit-test hooks (fxgrind_tests — off by default in production).
bool   g_grind_market_test_active = false;
double g_grind_market_test_bid = 0.0;
double g_grind_market_test_ask = 0.0;
long   g_grind_market_test_stops_level = 0;

//+------------------------------------------------------------------+
void Grind_MarketTestReset()
{
   g_grind_market_test_active = false;
   g_grind_market_test_bid = 0.0;
   g_grind_market_test_ask = 0.0;
   g_grind_market_test_stops_level = 0;
}

//+------------------------------------------------------------------+
void Grind_MarketTestSeed(const double bid,
                          const double ask,
                          const long stops_level = 0)
{
   g_grind_market_test_active = true;
   g_grind_market_test_bid = bid;
   g_grind_market_test_ask = ask;
   g_grind_market_test_stops_level = stops_level;
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
      if(result.retcode == TRADE_RETCODE_DONE)
         Grind_OrderTestRemove(request.order);
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
   if(ticket == 0 || !PositionSelectByTicket(ticket))
      return false;
   return Grind_MagicMatches(PositionGetInteger(POSITION_MAGIC), magic);
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
void Grind_HaltCritical(const string reason)
{
   g_grind_halted = true;
   if(g_grind_order_test_active)
      g_grind_order_test_last_critical = reason;
   Grind_TelemetryCritical(g_grind_telemetry_instance, reason);
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
                      const double deadband_pips,
                      const int max_layers,
                      const double lots)
{
   if(!Grind_CanPlaceEntryLayer(Grind_SideDepth(side), max_layers))
      return false;
   if(!Grind_CapAllowsEntry(is_long, lots))
      return false;

   if(side.l0_pending_ticket != 0) {
      if(!Grind_SelectOurOrder(side.l0_pending_ticket, magic)) {
         side.l0_pending_ticket = 0;
      } else {
         const double resting = OrderGetDouble(ORDER_PRICE_OPEN);
         if(Grind_PriceWithinDeadband(resting, target_price, deadband_pips, _Point))
            return false;
         Grind_ModifyPendingPrice(side.l0_pending_ticket, target_price, magic);
         return true;
      }
   }

   const string side_letter = is_long ? "L" : "S";
   const string comment = GrindCommentBuild(slot, side_letter, 0, "ENT");
   const ENUM_ORDER_TYPE otype = is_long ? ORDER_TYPE_BUY_LIMIT : ORDER_TYPE_SELL_LIMIT;
   side.l0_pending_ticket = Grind_PlaceLimit(otype, target_price, lots, magic, comment);
   return (side.l0_pending_ticket > 0);
}

//+------------------------------------------------------------------+
bool Grind_TryPlaceExitForLayer(GrindLayer &layer,
                                const bool is_long,
                                const ulong magic,
                                const string slot,
                                const double lots)
{
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
   const int dir = is_long ? 1 : -1;
   side.layers[n].exit_target = Grind_ExitPrice(entry_price, exit_pips, _Point, dir);
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
         side.add_pending_ticket = 0;
      } else {
         const string resting_comment = Grind_OrderGetComment(side.add_pending_ticket);
         string c_slot, c_side, c_role;
         int parsed_layer = -1;
         const bool label_ok = GrindCommentParse(resting_comment, c_slot, c_side,
                                                 parsed_layer, c_role)
                               && parsed_layer == required_index;
         if(!label_ok) {
            if(g_grind_recon_verbose) {
               string label_txt = "UNPARSEABLE";
               if(GrindCommentParse(resting_comment, c_slot, c_side, parsed_layer, c_role))
                  label_txt = StringFormat("L%02d", parsed_layer);
               Print("INFO: grind reconcile remove stale add ticket=",
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

   if(n <= 0 || !Grind_CanPlaceEntryLayer(n, max_layers))
      return;
   if(!Grind_CapAllowsEntry(is_long, lots))
      return;

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

   const string side_letter = is_long ? "L" : "S";
   const string comment = GrindCommentBuild(slot, side_letter, next_layer, "ENT");
   const ENUM_ORDER_TYPE otype = is_long ? ORDER_TYPE_BUY_LIMIT : ORDER_TYPE_SELL_LIMIT;
   side.add_pending_ticket = Grind_PlaceLimit(otype, clamped, lots, magic, comment);
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
         return (long)rec.deal_ticket;
      if(prop == DEAL_TIME_MSC)
         return (long)rec.deal_ticket * 1000;
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
      Grind_MarkDealProcessed(deal_ticket);

      for(int i = 0; i < Grind_SideDepth(side); i++) {
         if(side.layers[i].position_ticket != position_id)
            continue;
         if(side.layers[i].exit_position_ticket == 0)
            continue;

         const double deal_profit = Grind_DealGetDouble(deal_ticket, DEAL_PROFIT);
         const double deal_swap = Grind_DealGetDouble(deal_ticket, DEAL_SWAP);
         const double deal_commission = Grind_DealGetDouble(deal_ticket, DEAL_COMMISSION);
         Grind_AccumulateScalpPnl(deal_profit, deal_swap, deal_commission);
         Grind_RemoveLayerAt(side, i);
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
      const int layer_idx = Grind_FindLayerByIndex(side, c_layer);
      if(layer_idx >= 0)
         Grind_TryPlaceExitForLayer(side.layers[layer_idx], is_long, magic, slot, lots);
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
   if(opposite_side.l0_pending_ticket == 0)
      return;
   if(!Grind_SelectOurOrder(opposite_side.l0_pending_ticket, magic))
      return;

   const double resting = OrderGetDouble(ORDER_PRICE_OPEN);
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

   const double bid = Grind_MarketBid();
   const double ask = Grind_MarketAsk();
   const double mid = Grind_MidPrice(bid, ask);
   const long stops = Grind_MarketStopsLevel();

   double buy_target = Grind_StraddleBuyPrice(mid, width_pips, _Point);
   double sell_target = Grind_StraddleSellPrice(mid, width_pips, _Point);
   Grind_Adr013ClampBuy(buy_target, bid, _Point, stops, buy_target);
   Grind_Adr013ClampSell(sell_target, bid, ask, _Point, stops, sell_target);

   if(Grind_SideDepth(g_grind_long) == 0 && Grind_BuyLimitMarketable(buy_target, ask))
      Grind_TryPlaceL0(g_grind_long, true, buy_target, magic, slot, deadband_pips, max_layers, lots);
   if(Grind_SideDepth(g_grind_short) == 0 && Grind_SellLimitMarketable(sell_target, bid))
      Grind_TryPlaceL0(g_grind_short, false, sell_target, magic, slot, deadband_pips, max_layers, lots);

   if(Grind_SideDepth(g_grind_long) > 0 && Grind_SideDepth(g_grind_short) == 0)
      Grind_TryRecenterOppositeL0(g_grind_short, false, mid, magic, slot,
                                  width_pips, stranded_thresh_pips, deadband_pips);
   if(Grind_SideDepth(g_grind_short) > 0 && Grind_SideDepth(g_grind_long) == 0)
      Grind_TryRecenterOppositeL0(g_grind_long, true, mid, magic, slot,
                                  width_pips, stranded_thresh_pips, deadband_pips);

   Grind_OnSideCapTransition(g_grind_long, Grind_SideDepth(g_grind_long), max_layers);
   Grind_OnSideCapTransition(g_grind_short, Grind_SideDepth(g_grind_short), max_layers);

   for(int i = 0; i < Grind_SideDepth(g_grind_long); i++) {
      if(g_grind_long.layers[i].exit_order_ticket == 0 &&
         g_grind_long.layers[i].exit_position_ticket == 0)
         Grind_TryPlaceExitForLayer(g_grind_long.layers[i], true, magic, slot, lots);
   }
   for(int i = 0; i < Grind_SideDepth(g_grind_short); i++) {
      if(g_grind_short.layers[i].exit_order_ticket == 0 &&
         g_grind_short.layers[i].exit_position_ticket == 0)
         Grind_TryPlaceExitForLayer(g_grind_short.layers[i], false, magic, slot, lots);
   }

   if(Grind_SideDepth(g_grind_long) > 0 || g_grind_long.add_pending_ticket != 0)
      Grind_EnsureAddNext(g_grind_long, true, magic, slot, add_pips, deadband_pips, max_layers, lots);
   if(Grind_SideDepth(g_grind_short) > 0 || g_grind_short.add_pending_ticket != 0)
      Grind_EnsureAddNext(g_grind_short, false, magic, slot, add_pips, deadband_pips, max_layers, lots);
}

//+------------------------------------------------------------------+
void Grind_OnTradeTransactionEngine(const MqlTradeTransaction &trans,
                                    const ulong magic,
                                    const string slot,
                                    const double exit_pips,
                                    const double deadband_pips,
                                    const int max_layers,
                                    const double lots)
{
   if(g_grind_halted)
      return;
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD)
      return;

   Grind_HandleSideDealFill(g_grind_long, true, trans.deal, magic, slot,
                            exit_pips, deadband_pips, max_layers, lots);
   Grind_HandleSideDealFill(g_grind_short, false, trans.deal, magic, slot,
                            exit_pips, deadband_pips, max_layers, lots);
}

#endif // GRIND_ENGINE_MQH
