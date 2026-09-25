//+------------------------------------------------------------------+
//| grind_pure.mqh — pure geometry, guards, cap/deadband helpers     |
//+------------------------------------------------------------------+
#ifndef GRIND_PURE_MQH
#define GRIND_PURE_MQH

#include "grind_comment.mqh"

#define GRIND_ADD_WIDTH_RATIO_MIN 0.5
#define GRIND_ADD_WIDTH_RATIO_MAX 4.0
#define GRIND_FEED_STALE_MS      5000

// Absolute price epsilon for boundary comparisons. A difference of
// exactly N * point can evaluate as marginally greater in binary
// (0.58481 - 0.58479 = 2.0000000000020002e-05 vs 2e-05), which halted
// an instance on 2026-09-14. 1e-9 is far below one point on any symbol
// we trade (smallest point = 0.00001) so it cannot mask a real breach.
#define GRIND_PRICE_EPS          1e-9

//+------------------------------------------------------------------+
bool Grind_ValidateGeometryInputs(const double width_pips,
                                  const double exit_pips,
                                  const int max_layers,
                                  const double stranded_thresh_pips,
                                  const double add_pips)
{
   if(width_pips <= 0.0)
      return false;
   if(exit_pips <= 0.0)
      return false;
   if(max_layers <= 0)
      return false;
   if(stranded_thresh_pips <= 0.0)
      return false;
   if(add_pips <= 0.0)
      return false;
   return true;
}

//+------------------------------------------------------------------+
bool Grind_ValidateAddWidthRatio(const double width_pips,
                                 const double add_pips)
{
   if(width_pips <= 0.0 || add_pips <= 0.0)
      return false;
   const double r = add_pips / width_pips;
   if(r < GRIND_ADD_WIDTH_RATIO_MIN - 1e-9)
      return false;
   if(r > GRIND_ADD_WIDTH_RATIO_MAX + 1e-9)
      return false;
   return true;
}

//+------------------------------------------------------------------+
bool Grind_ValidateDeadband(const double deadband_pips)
{
   return (deadband_pips >= 0.0);
}

//+------------------------------------------------------------------+
int Grind_TestOnInitGeometryCheck(const double width_pips,
                                  const double exit_pips,
                                  const int max_layers,
                                  const double stranded_thresh_pips,
                                  const double add_pips,
                                  const double deadband_pips,
                                  const ulong magic)
{
   if(!Grind_ValidateGeometryInputs(width_pips, exit_pips, max_layers,
                                    stranded_thresh_pips, add_pips))
      return INIT_FAILED;
   if(!Grind_ValidateAddWidthRatio(width_pips, add_pips))
      return INIT_FAILED;
   if(!Grind_ValidateDeadband(deadband_pips))
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
double Grind_Normalize(const double price)
{
   return NormalizeDouble(price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
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

//+------------------------------------------------------------------+
bool Grind_StartupShortfallCritical(const int long_n, const int short_n)
{
   return (long_n >= 2 || short_n >= 2);
}

//+------------------------------------------------------------------+
bool Grind_CarryShouldCommitAccrual(const bool has_exit_order,
                                    const bool guard_blocked,
                                    const bool modify_ok)
{
   if(!has_exit_order)
      return true;
   return (!guard_blocked && modify_ok);
}

#define GRIND_EJECT_OK             0
#define GRIND_EJECT_SWITCH_OFF     1
#define GRIND_EJECT_NOT_FOUND      2
#define GRIND_EJECT_DEPTH_LT_2     3
#define GRIND_EJECT_NOT_DEEPEST    4
#define GRIND_EJECT_NO_EXIT_ORDER  5
#define GRIND_EJECT_MODIFY_FAILED  6
#define GRIND_EJECT_HALTED         7

//+------------------------------------------------------------------+
int Grind_EjectValidate(const bool engine_blocked,
                        const bool switch_on,
                        const bool found,
                        const int depth,
                        const int rank,
                        const bool has_exit_order)
{
   if(engine_blocked)
      return GRIND_EJECT_HALTED;
   if(!switch_on)
      return GRIND_EJECT_SWITCH_OFF;
   if(!found)
      return GRIND_EJECT_NOT_FOUND;
   if(depth < 2)
      return GRIND_EJECT_DEPTH_LT_2;
   if(rank != depth - 1)
      return GRIND_EJECT_NOT_DEEPEST;
   if(!has_exit_order)
      return GRIND_EJECT_NO_EXIT_ORDER;
   return GRIND_EJECT_OK;
}

//+------------------------------------------------------------------+
string Grind_EjectReasonName(const int code)
{
   switch(code) {
      case GRIND_EJECT_OK:             return "OK";
      case GRIND_EJECT_SWITCH_OFF:     return "SWITCH_OFF";
      case GRIND_EJECT_NOT_FOUND:      return "NOT_FOUND";
      case GRIND_EJECT_DEPTH_LT_2:     return "DEPTH_LT_2";
      case GRIND_EJECT_NOT_DEEPEST:    return "NOT_DEEPEST";
      case GRIND_EJECT_NO_EXIT_ORDER:  return "NO_EXIT_ORDER";
      case GRIND_EJECT_MODIFY_FAILED:  return "MODIFY_FAILED";
      case GRIND_EJECT_HALTED:         return "HALTED";
   }
   return "UNKNOWN";
}

//+------------------------------------------------------------------+
double Grind_EjectOffsetFor(const double target,
                            const double raw,
                            const double accrued)
{
   return target - raw - accrued;
}

//+------------------------------------------------------------------+
int Grind_ExtremeIndexMostRecent(const double &vals[], const int n,
                                 const bool want_min)
{
   if(n <= 0)
      return -1;
   int best = 0;
   for(int i = 1; i < n; i++) {
      if(want_min) {
         if(vals[i] < vals[best] || (vals[i] == vals[best] && i > best))
            best = i;
      } else {
         if(vals[i] > vals[best] || (vals[i] == vals[best] && i > best))
            best = i;
      }
   }
   return best;
}

//+------------------------------------------------------------------+
bool Grind_AutoEjectStable(const datetime &times[], const double &vals[],
                           const int n, const datetime now,
                           const int window_sec, const bool want_min)
{
   const int idx = Grind_ExtremeIndexMostRecent(vals, n, want_min);
   if(idx < 0)
      return false;
   return ((int)(now - times[idx]) >= window_sec);
}

//+------------------------------------------------------------------+
bool Grind_AutoEjectSpreadOk(const double current_points,
                             const double &baseline[], const int n,
                             const double k)
{
   if(n <= 0)
      return false;
   double sum = 0.0;
   for(int i = 0; i < n; i++)
      sum += baseline[i];
   const double mean = sum / (double)n;
   return (current_points <= k * mean);
}

//+------------------------------------------------------------------+
bool Grind_AutoEjectTargetWorse(const bool is_long, const double new_target,
                                const double resting, const double min_dist)
{
   if(is_long)
      return (resting - new_target >= min_dist);
   return (new_target - resting >= min_dist);
}

//+------------------------------------------------------------------+
bool Grind_AutoEjectWindowIntact(const datetime oldest_close,
                                 const datetime now, const int window_sec)
{
   return ((int)(now - oldest_close) <= window_sec);
}

#define GRIND_ROLL_OK             0
#define GRIND_ROLL_MODIFY_FAILED  1
#define GRIND_ROLL_CLOSING        2
#define GRIND_ROLL_ALREADY_ROLLED 3

bool   Grind_ValidateLatticeInputs(const bool lattice, const bool auto_eject) { return true; }
bool   Grind_LatticeLevelCrossed(const bool is_long, const double price,
                                 const double level) { return false; }
double Grind_LatticeRollCost(const double entry, const double level,
                             const double exit_pips, const double point,
                             const bool is_long) { return 0.0; }

//+------------------------------------------------------------------+
datetime Grind_LastSundayMonthUtc(const int year, const int month)
{
   MqlDateTime dt;
   dt.year = year;
   dt.mon = month;
   dt.day = 31;
   dt.hour = 1;
   dt.min = 0;
   dt.sec = 0;
   datetime t = StructToTime(dt);
   while(true) {
      TimeToStruct(t, dt);
      if(dt.mon != month) {
         t -= 86400;
         continue;
      }
      if(dt.day_of_week == 0)
         return t;
      t -= 86400;
   }
   return 0;
}

//+------------------------------------------------------------------+
int Grind_PragueUtcOffset(const datetime gmt)
{
   MqlDateTime dt;
   TimeToStruct(gmt, dt);
   const datetime dst_start = Grind_LastSundayMonthUtc(dt.year, 3);
   const datetime dst_end = Grind_LastSundayMonthUtc(dt.year, 10);
   if(gmt >= dst_start && gmt < dst_end)
      return 2;
   return 1;
}

//+------------------------------------------------------------------+
datetime Grind_FtmoDayStartGmt(const datetime gmt)
{
   const int off = Grind_PragueUtcOffset(gmt);
   const long local = (long)gmt + (long)off * 3600L;
   const long day_start_local = local - (local % 86400L);
   return (datetime)(day_start_local - (long)off * 3600L);
}

//+------------------------------------------------------------------+
string Grind_FtmoDayKey(const datetime gmt)
{
   const int off = Grind_PragueUtcOffset(gmt);
   return TimeToString(gmt + off * 3600, TIME_DATE);
}

//+------------------------------------------------------------------+
int Grind_FtmoSecondsIntoDay(const datetime gmt)
{
   const int off = Grind_PragueUtcOffset(gmt);
   const long local = (long)gmt + (long)off * 3600L;
   return (int)(local % 86400L);
}

#define GRIND_SESSION_OPEN_SEC          25200
#define GRIND_SESSION_CLOSE_SEC         60900
#define GRIND_SESSION_CANCEL_RETRY_SEC  10
#define GRIND_SESSION_STUCK_WARN_SEC    300

//+------------------------------------------------------------------+
datetime Grind_NthSundayMonthUtc(const int year, const int month,
                                 const int n, const int hour_utc)
{
   MqlDateTime dt;
   dt.year = year;
   dt.mon = month;
   dt.day = 1;
   dt.hour = hour_utc;
   dt.min = 0;
   dt.sec = 0;
   datetime t = StructToTime(dt);
   while(true) {
      TimeToStruct(t, dt);
      if(dt.day_of_week == 0)
         break;
      t += 86400;
   }
   if(n > 1)
      t += (n - 1) * 7 * 86400;
   return t;
}

//+------------------------------------------------------------------+
int Grind_TorontoUtcOffset(const datetime gmt)
{
   MqlDateTime dt;
   TimeToStruct(gmt, dt);
   const datetime dst_start = Grind_NthSundayMonthUtc(dt.year, 3, 2, 7);
   const datetime dst_end = Grind_NthSundayMonthUtc(dt.year, 11, 1, 6);
   if(gmt >= dst_start && gmt < dst_end)
      return -4;
   return -5;
}

//+------------------------------------------------------------------+
bool Grind_SessionOpenAt(const datetime gmt)
{
   const int off = Grind_TorontoUtcOffset(gmt);
   const datetime local_stamp = gmt + off * 3600;
   MqlDateTime dt;
   TimeToStruct(local_stamp, dt);
   if(dt.day_of_week < 1 || dt.day_of_week > 5)
      return false;
   const long local = (long)gmt + (long)off * 3600L;
   const int sec = (int)(local % 86400L);
   return (sec >= GRIND_SESSION_OPEN_SEC && sec < GRIND_SESSION_CLOSE_SEC);
}

//+------------------------------------------------------------------+
double Grind_BreakerAnchor(const double balance_now,
                           const double &amounts[], const datetime &times[],
                           const int n, const datetime boundary)
{
   double sum = 0.0;
   for(int i = 0; i < n; i++) {
      if(times[i] >= boundary)
         sum += amounts[i];
   }
   return balance_now - sum;
}

//+------------------------------------------------------------------+
double Grind_BreakerInitialDeposit(const double &amounts[],
                                   const datetime &times[], const int n)
{
   if(n <= 0)
      return 0.0;
   int best = 0;
   for(int i = 1; i < n; i++) {
      if(times[i] < times[best])
         best = i;
   }
   return amounts[best];
}

//+------------------------------------------------------------------+
double Grind_BreakerDayAnchor(const double balance_now,
                              const double &amounts[], const datetime &times[],
                              const int n, const datetime boundary,
                              const double initial_deposit,
                              const datetime initial_time)
{
   if(initial_time >= boundary)
      return initial_deposit;
   return Grind_BreakerAnchor(balance_now, amounts, times, n, boundary);
}

//+------------------------------------------------------------------+
bool Grind_BreakerShouldTrip(const double equity, const double anchor,
                             const double allowance, const double frac)
{
   if(anchor <= 0.0 || allowance <= 0.0)
      return false;
   return (equity <= anchor - frac * allowance);
}

//+------------------------------------------------------------------+
bool Grind_BreakerPreMidnightHalt(const int sec_into_day, const double equity,
                                  const double balance, const double allowance)
{
   if(sec_into_day < 82800)
      return false;
   return ((balance - equity) >= 0.5 * allowance);
}

//+------------------------------------------------------------------+
bool Grind_BreakerFloatGate(const bool was_gated, const double floating,
                            const double allowance)
{
   if(allowance <= 0.0)
      return false;
   if(!was_gated)
      return (floating >= 0.5 * allowance);
   return (floating > 0.4 * allowance);
}

//+------------------------------------------------------------------+
int Grind_GateAddSeconds(const datetime last, const datetime now, const int cap)
{
   if(last <= 0 || now <= last)
      return 0;
   return MathMin((int)(now - last), cap);
}

#endif // GRIND_PURE_MQH
