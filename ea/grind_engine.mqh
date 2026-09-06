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
#include "grind_telemetry.mqh"

//+------------------------------------------------------------------+
double Grind_Normalize(const double price)
{
   return NormalizeDouble(price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
}

//+------------------------------------------------------------------+
bool Grind_SelectOurOrder(const ulong ticket, const ulong magic)
{
   if(ticket == 0 || !OrderSelect(ticket))
      return false;
   return Grind_MagicMatches(OrderGetInteger(ORDER_MAGIC), magic);
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

   if(!Grind_OrderSendCounted(req, res))
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

   if(!Grind_OrderSendCounted(req, res))
      return 0;
   if(res.retcode == TRADE_RETCODE_DONE || res.retcode == TRADE_RETCODE_PLACED)
      return res.order;
   return 0;
}

//+------------------------------------------------------------------+
void Grind_HaltCritical(const string reason)
{
   g_grind_halted = true;
   Grind_TelemetryCritical(g_grind_telemetry_instance, reason);
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
      side.add_pending_ticket = 0;
      side.cap_warn_emitted = false;
   }
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
   }
   return -1;
}

//+------------------------------------------------------------------+
double Grind_ComputeAddTarget(const GrindSideState &side,
                              const bool is_long,
                              const double add_pips)
{
   const int n = Grind_SideDepth(side);
   if(n <= 0)
      return 0.0;
   const double anchor = side.layers[n - 1].entry_price;
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
   if(n <= 0 || !Grind_CanPlaceEntryLayer(n, max_layers))
      return;
   if(!Grind_CapAllowsEntry(is_long, lots))
      return;

   const int next_layer = n;
   double add_target = Grind_ComputeAddTarget(side, is_long, add_pips);
   if(add_target <= 0.0)
      return;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const long stops = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
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
      if(!Grind_SelectOurOrder(side.add_pending_ticket, magic)) {
         side.add_pending_ticket = 0;
      } else {
         const double resting = OrderGetDouble(ORDER_PRICE_OPEN);
         if(Grind_PriceWithinDeadband(resting, clamped, deadband_pips, _Point))
            return;
         Grind_ModifyPendingPrice(side.add_pending_ticket, clamped, magic);
         return;
      }
   }

   const string side_letter = is_long ? "L" : "S";
   const string comment = GrindCommentBuild(slot, side_letter, next_layer, "ENT");
   const ENUM_ORDER_TYPE otype = is_long ? ORDER_TYPE_BUY_LIMIT : ORDER_TYPE_SELL_LIMIT;
   side.add_pending_ticket = Grind_PlaceLimit(otype, clamped, lots, magic, comment);
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
   if(!HistoryDealSelect(deal_ticket))
      return;

   if(HistoryDealGetString(deal_ticket, DEAL_SYMBOL) != _Symbol)
      return;
   if(!Grind_MagicMatches(HistoryDealGetInteger(deal_ticket, DEAL_MAGIC), magic))
      return;

   const string deal_comment = HistoryDealGetString(deal_ticket, DEAL_COMMENT);
   string c_slot, c_side, c_role;
   int c_layer;
   if(!GrindCommentParse(deal_comment, c_slot, c_side, c_layer, c_role))
      return;
   if(is_long && c_side != "L")
      return;
   if(!is_long && c_side != "S")
      return;

   const long entry_type = HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
   const ulong order_ticket = (ulong)HistoryDealGetInteger(deal_ticket, DEAL_ORDER);
   const ulong position_id = (ulong)HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID);
   const double deal_price = HistoryDealGetDouble(deal_ticket, DEAL_PRICE);

   Grind_MarkDealProcessed(deal_ticket);

   if(c_role == "ENT") {
      if(order_ticket == side.l0_pending_ticket)
         side.l0_pending_ticket = 0;
      if(order_ticket == side.add_pending_ticket)
         side.add_pending_ticket = 0;

      Grind_AppendLayer(side, deal_price, position_id, c_layer, exit_pips, is_long);
      Grind_TryPlaceExitForLayer(side.layers[Grind_SideDepth(side) - 1], is_long, magic, slot, lots);
      return;
   }

   if(c_role == "EXT" && entry_type == DEAL_ENTRY_OUT) {
      int layer_idx = Grind_FindLayerByExitOrder(side, order_ticket);
      if(layer_idx < 0)
         layer_idx = Grind_FindLayerByPosition(side, position_id);
      if(layer_idx >= 0)
         Grind_RemoveLayerAt(side, layer_idx);
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

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const long stops = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
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

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double mid = Grind_MidPrice(bid, ask);
   const long stops = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);

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
      if(g_grind_long.layers[i].exit_order_ticket == 0)
         Grind_TryPlaceExitForLayer(g_grind_long.layers[i], true, magic, slot, lots);
   }
   for(int i = 0; i < Grind_SideDepth(g_grind_short); i++) {
      if(g_grind_short.layers[i].exit_order_ticket == 0)
         Grind_TryPlaceExitForLayer(g_grind_short.layers[i], false, magic, slot, lots);
   }

   if(Grind_SideDepth(g_grind_long) > 0)
      Grind_EnsureAddNext(g_grind_long, true, magic, slot, add_pips, deadband_pips, max_layers, lots);
   if(Grind_SideDepth(g_grind_short) > 0)
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
