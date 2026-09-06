//+------------------------------------------------------------------+
//| grind_pure.mqh — pure geometry, guards, cap/deadband helpers     |
//+------------------------------------------------------------------+
#ifndef GRIND_PURE_MQH
#define GRIND_PURE_MQH

#include "grind_comment.mqh"

#define GRIND_ADD_PIPS_FLOOR 9.0
#define GRIND_FEED_STALE_MS  5000

//+------------------------------------------------------------------+
bool Grind_ValidateGeometryInputs(const double width_pips,
                                  const double exit_pips,
                                  const int max_layers,
                                  const double stranded_thresh_pips)
{
   if(width_pips <= 0.0)
      return false;
   if(exit_pips <= 0.0)
      return false;
   if(max_layers <= 0)
      return false;
   if(stranded_thresh_pips <= 0.0)
      return false;
   return true;
}

//+------------------------------------------------------------------+
int Grind_TestOnInitGeometryCheck(const double width_pips,
                                  const double exit_pips,
                                  const int max_layers,
                                  const double stranded_thresh_pips,
                                  const ulong magic)
{
   if(!Grind_ValidateGeometryInputs(width_pips, exit_pips, max_layers, stranded_thresh_pips))
      return INIT_FAILED;
   if(magic == 0)
      return INIT_FAILED;
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
double Grind_PipsToPrice(const double pips, const double point)
{
   return pips * point * 10.0;
}

//+------------------------------------------------------------------+
double Grind_MidPrice(const double bid, const double ask)
{
   return (bid + ask) * 0.5;
}

//+------------------------------------------------------------------+
double Grind_StraddleBuyPrice(const double mid,
                              const double width_pips,
                              const double point)
{
   return mid - Grind_PipsToPrice(width_pips, point);
}

//+------------------------------------------------------------------+
double Grind_StraddleSellPrice(const double mid,
                               const double width_pips,
                               const double point)
{
   return mid + Grind_PipsToPrice(width_pips, point);
}

//+------------------------------------------------------------------+
double Grind_ExitPrice(const double entry,
                       const double exit_pips,
                       const double point,
                       const int direction)
{
   return entry + (double)direction * Grind_PipsToPrice(exit_pips, point);
}

//+------------------------------------------------------------------+
double Grind_AddTargetPrice(const double anchor_entry,
                            const double add_pips,
                            const double point,
                            const int direction)
{
   return anchor_entry - (double)direction * Grind_PipsToPrice(add_pips, point);
}

//+------------------------------------------------------------------+
double Grind_DeadbandPrice(const double deadband_pips, const double point)
{
   return deadband_pips * point * 10.0;
}

//+------------------------------------------------------------------+
bool Grind_PriceWithinDeadband(const double resting_price,
                               const double target_price,
                               const double deadband_pips,
                               const double point)
{
   const double band = Grind_DeadbandPrice(deadband_pips, point);
   return (MathAbs(target_price - resting_price) < band);
}

//+------------------------------------------------------------------+
bool Grind_MagicMatches(const long ticket_magic, const ulong expected_magic)
{
   return ((ulong)ticket_magic == expected_magic);
}

//+------------------------------------------------------------------+
bool Grind_MarketTradeModeFull(const long trade_mode)
{
   return (trade_mode == (long)SYMBOL_TRADE_MODE_FULL);
}

//+------------------------------------------------------------------+
bool Grind_BuyLimitMarketable(const double buy_limit, const double ask)
{
   return (buy_limit < ask);
}

//+------------------------------------------------------------------+
bool Grind_SellLimitMarketable(const double sell_limit, const double bid)
{
   return (sell_limit > bid);
}

//+------------------------------------------------------------------+
bool Grind_Adr013ClampBuy(const double theoretical,
                          const double bid,
                          const double point,
                          const long stops_level_points,
                          double &out_price)
{
   const double min_dist = MathMax(point, stops_level_points * point);
   if(theoretical >= bid)
      out_price = MathMin(theoretical, bid - min_dist);
   else
      out_price = theoretical;
   return (MathAbs(out_price - theoretical) > point * 0.1);
}

//+------------------------------------------------------------------+
bool Grind_Adr013ClampSell(const double theoretical,
                           const double bid,
                           const double ask,
                           const double point,
                           const long stops_level_points,
                           double &out_price)
{
   const double min_dist = MathMax(point, stops_level_points * point);
   if(theoretical <= ask)
      out_price = MathMax(theoretical, ask + min_dist);
   else
      out_price = theoretical;
   return (MathAbs(out_price - theoretical) > point * 0.1);
}

//+------------------------------------------------------------------+
bool Grind_CanPlaceEntryLayer(const int current_layers, const int max_layers)
{
   return (current_layers < max_layers);
}

//+------------------------------------------------------------------+
bool Grind_CanPlaceExitLayer(const int current_layers)
{
   return (current_layers > 0);
}

//+------------------------------------------------------------------+
double Grind_StrandedDistMidPips(const double resting_price,
                                 const double current_mid,
                                 const double point)
{
   return MathAbs(resting_price - current_mid) / (point * 10.0);
}

//+------------------------------------------------------------------+
bool Grind_ShouldRecenter(const double dist_mid_pips, const double thresh_pips)
{
   return (dist_mid_pips > thresh_pips);
}

//+------------------------------------------------------------------+
bool Grind_FeedStaleAfterTick(const long tick_msc,
                              long &last_feed_tick_msc,
                              const long max_age_ms = GRIND_FEED_STALE_MS)
{
   if(last_feed_tick_msc <= 0) {
      last_feed_tick_msc = tick_msc;
      return false;
   }
   const bool stale = ((tick_msc - last_feed_tick_msc) > max_age_ms);
   last_feed_tick_msc = tick_msc;
   return stale;
}

//+------------------------------------------------------------------+
int Grind_RestingOrderBudgetPerSide(const int depth_layers)
{
   return depth_layers + 1;
}

//+------------------------------------------------------------------+
int Grind_RestingOrderBudgetInstance(const int depth_long,
                                     const int depth_short)
{
   return Grind_RestingOrderBudgetPerSide(depth_long)
        + Grind_RestingOrderBudgetPerSide(depth_short);
}

#endif // GRIND_PURE_MQH
