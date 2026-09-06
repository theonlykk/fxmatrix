//+------------------------------------------------------------------+
//| grind_pnl.mqh — floating MTM, realised P&L, exit microstructure  |
//+------------------------------------------------------------------+
#ifndef GRIND_PNL_MQH
#define GRIND_PNL_MQH

#include "grind_pure.mqh"

// Maximum favourable excursion window after an exit fill (seconds).
// 30s captures immediate post-fill continuation without retaining tick state
// on the execution path; derived statelessly via CopyTicksRange on OnTimer.
#define GRIND_EXIT_PENETRATION_WINDOW_SEC 30

// Daily realised P&L and microstructure counters — reset at TimeServer() day
// boundary. NOT persisted across restarts (Gate 1 stateless property).
double g_grind_realised_pnl_today          = 0.0;
double g_grind_scalp_pnl_last              = 0.0;
string g_grind_pnl_day_key                 = "";
double g_grind_exit_penetration_pips_last  = 0.0;
double g_grind_exit_penetration_pips_sum   = 0.0;
int    g_grind_exit_penetration_count      = 0;
int    g_grind_exit_touch_revert_count     = 0;

struct GrindPendingExitMeasure
{
   datetime fill_time;
   long     fill_time_msc;
   double   exit_price;
   bool     is_long;
   double   spread_pips;
   bool     measured;
};

GrindPendingExitMeasure g_grind_pending_exit_measures[];
int g_grind_pending_exit_count = 0;

// Unit-test hooks (no PositionsTotal / TimeServer when active).
bool     g_grind_pnl_test_active           = false;
datetime g_grind_pnl_test_server_time      = 0;

struct GrindPnlTestPosition
{
   ulong  magic;
   double profit;
   double swap;
   double commission;
};

GrindPnlTestPosition g_grind_pnl_test_positions[];
int g_grind_pnl_test_position_count = 0;

//+------------------------------------------------------------------+
void Grind_PnlReset()
{
   g_grind_realised_pnl_today = 0.0;
   g_grind_scalp_pnl_last = 0.0;
   g_grind_pnl_day_key = "";
   g_grind_exit_penetration_pips_last = 0.0;
   g_grind_exit_penetration_pips_sum = 0.0;
   g_grind_exit_penetration_count = 0;
   g_grind_exit_touch_revert_count = 0;
   ArrayResize(g_grind_pending_exit_measures, 0);
   g_grind_pending_exit_count = 0;
   g_grind_pnl_test_active = false;
   g_grind_pnl_test_server_time = 0;
   ArrayResize(g_grind_pnl_test_positions, 0);
   g_grind_pnl_test_position_count = 0;
}

//+------------------------------------------------------------------+
datetime Grind_ReadServerTime()
{
   if(g_grind_pnl_test_active)
      return g_grind_pnl_test_server_time;
   return TimeServer();
}

//+------------------------------------------------------------------+
string Grind_ServerDayKey(const datetime server_time)
{
   MqlDateTime dt;
   TimeToStruct(server_time, dt);
   return StringFormat("%04d%02d%02d", dt.year, dt.mon, dt.day);
}

//+------------------------------------------------------------------+
string Grind_LocalDayKey(const datetime local_time)
{
   MqlDateTime dt;
   TimeToStruct(local_time, dt);
   return StringFormat("%04d%02d%02d", dt.year, dt.mon, dt.day);
}

//+------------------------------------------------------------------+
double Grind_PositionNetMtmParts(const double profit,
                               const double swap,
                               const double commission)
{
   // POSITION_PROFIT excludes swap and commission — sum all three for net floating MTM.
   return profit + swap + commission;
}

//+------------------------------------------------------------------+
double Grind_AccumulateNetMtmForMagic(const ulong expected_magic,
                                      const ulong pos_magic,
                                      const double profit,
                                      const double swap,
                                      const double commission,
                                      double running_sum)
{
   if(!Grind_MagicMatches((long)pos_magic, expected_magic))
      return running_sum;
   return running_sum + Grind_PositionNetMtmParts(profit, swap, commission);
}

//+------------------------------------------------------------------+
double Grind_ComputeNetFloatingMtm(const ulong magic)
{
   double sum = 0.0;

   if(g_grind_pnl_test_active) {
      for(int i = 0; i < g_grind_pnl_test_position_count; i++)
         sum = Grind_AccumulateNetMtmForMagic(magic,
                                              g_grind_pnl_test_positions[i].magic,
                                              g_grind_pnl_test_positions[i].profit,
                                              g_grind_pnl_test_positions[i].swap,
                                              g_grind_pnl_test_positions[i].commission,
                                              sum);
      return sum;
   }

   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if(!Grind_MagicMatches(PositionGetInteger(POSITION_MAGIC), magic))
         continue;
      // POSITION_PROFIT excludes swap and commission — sum all three for net floating MTM.
      sum += PositionGetDouble(POSITION_PROFIT)
           + PositionGetDouble(POSITION_SWAP)
           + PositionGetDouble(POSITION_COMMISSION);
   }
   return sum;
}

//+------------------------------------------------------------------+
void Grind_ResetDailyPnlCounters()
{
   g_grind_realised_pnl_today = 0.0;
   g_grind_scalp_pnl_last = 0.0;
   g_grind_exit_penetration_pips_last = 0.0;
   g_grind_exit_penetration_pips_sum = 0.0;
   g_grind_exit_penetration_count = 0;
   g_grind_exit_touch_revert_count = 0;
   ArrayResize(g_grind_pending_exit_measures, 0);
   g_grind_pending_exit_count = 0;
}

//+------------------------------------------------------------------+
void Grind_ResetDailyPnlIfNewDay()
{
   const string today = Grind_ServerDayKey(Grind_ReadServerTime());
   if(g_grind_pnl_day_key == today)
      return;
   g_grind_pnl_day_key = today;
   Grind_ResetDailyPnlCounters();
}

//+------------------------------------------------------------------+
double Grind_AccumulateScalpPnl(const double profit,
                                const double swap,
                                const double commission)
{
   Grind_ResetDailyPnlIfNewDay();
   const double net = profit + swap + commission;
   g_grind_realised_pnl_today += net;
   g_grind_scalp_pnl_last = net;
   return net;
}

//+------------------------------------------------------------------+
double Grind_ExitPenetrationPipsMean()
{
   if(g_grind_exit_penetration_count <= 0)
      return 0.0;
   return g_grind_exit_penetration_pips_sum / (double)g_grind_exit_penetration_count;
}

//+------------------------------------------------------------------+
double Grind_ComputeMaxPenetrationPips(const double exit_price,
                                       const bool is_long_exit,
                                       const double &tick_prices[],
                                       const int tick_count,
                                       const double point)
{
   if(tick_count <= 0 || point <= 0.0)
      return 0.0;

   double max_pen = 0.0;
   for(int i = 0; i < tick_count; i++) {
      double pen = 0.0;
      if(is_long_exit)
         pen = (tick_prices[i] - exit_price) / (point * 10.0);
      else
         pen = (exit_price - tick_prices[i]) / (point * 10.0);
      if(pen > max_pen)
         max_pen = pen;
   }
   return MathMax(0.0, max_pen);
}

//+------------------------------------------------------------------+
bool Grind_IsTouchAndRevert(const double penetration_pips, const double spread_pips)
{
   return (penetration_pips >= 0.0 && penetration_pips < spread_pips);
}

//+------------------------------------------------------------------+
void Grind_RecordExitPenetration(const double penetration_pips,
                                 const double spread_pips)
{
   g_grind_exit_penetration_pips_last = penetration_pips;
   g_grind_exit_penetration_pips_sum += penetration_pips;
   g_grind_exit_penetration_count++;
   if(Grind_IsTouchAndRevert(penetration_pips, spread_pips))
      g_grind_exit_touch_revert_count++;
}

//+------------------------------------------------------------------+
double Grind_SpreadPipsLive(const double point)
{
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(point <= 0.0)
      return 0.0;
   return (ask - bid) / (point * 10.0);
}

//+------------------------------------------------------------------+
void Grind_QueueExitMicrostructureMeasure(const datetime fill_time,
                                          const long fill_time_msc,
                                          const double exit_price,
                                          const bool is_long,
                                          const double spread_pips)
{
   ArrayResize(g_grind_pending_exit_measures, g_grind_pending_exit_count + 1);
   g_grind_pending_exit_measures[g_grind_pending_exit_count].fill_time = fill_time;
   g_grind_pending_exit_measures[g_grind_pending_exit_count].fill_time_msc = fill_time_msc;
   g_grind_pending_exit_measures[g_grind_pending_exit_count].exit_price = exit_price;
   g_grind_pending_exit_measures[g_grind_pending_exit_count].is_long = is_long;
   g_grind_pending_exit_measures[g_grind_pending_exit_count].spread_pips = spread_pips;
   g_grind_pending_exit_measures[g_grind_pending_exit_count].measured = false;
   g_grind_pending_exit_count++;
}

//+------------------------------------------------------------------+
bool Grind_MeasureExitPenetrationFromTicks(const datetime fill_time,
                                           const double exit_price,
                                           const bool is_long,
                                           const double spread_pips,
                                           const double point,
                                           double &out_penetration_pips)
{
   const datetime window_end = fill_time + GRIND_EXIT_PENETRATION_WINDOW_SEC;
   MqlTick ticks[];
   const int copied = CopyTicksRange(_Symbol, ticks, COPY_TICKS_ALL,
                                     fill_time, window_end);
   if(copied <= 0) {
      out_penetration_pips = 0.0;
      return false;
   }

   double prices[];
   ArrayResize(prices, copied);
   for(int i = 0; i < copied; i++)
      prices[i] = ticks[i].last;

   out_penetration_pips = Grind_ComputeMaxPenetrationPips(exit_price, is_long,
                                                          prices, copied, point);
   Grind_RecordExitPenetration(out_penetration_pips, spread_pips);
   return true;
}

//+------------------------------------------------------------------+
void Grind_ProcessPendingExitMicrostructure()
{
   if(g_grind_pending_exit_count <= 0)
      return;

   const datetime now = Grind_ReadServerTime();
   const double point = _Point;
   int write_idx = 0;

   for(int i = 0; i < g_grind_pending_exit_count; i++) {
      if(g_grind_pending_exit_measures[i].measured)
         continue;

      const datetime measure_after = g_grind_pending_exit_measures[i].fill_time
                                   + GRIND_EXIT_PENETRATION_WINDOW_SEC;
      if(now < measure_after)
         continue;

      double penetration = 0.0;
      Grind_MeasureExitPenetrationFromTicks(
         g_grind_pending_exit_measures[i].fill_time,
         g_grind_pending_exit_measures[i].exit_price,
         g_grind_pending_exit_measures[i].is_long,
         g_grind_pending_exit_measures[i].spread_pips,
         point,
         penetration);
      g_grind_pending_exit_measures[i].measured = true;
   }

   for(int i = 0; i < g_grind_pending_exit_count; i++) {
      if(!g_grind_pending_exit_measures[i].measured) {
         if(write_idx != i)
            g_grind_pending_exit_measures[write_idx] = g_grind_pending_exit_measures[i];
         write_idx++;
      }
   }
   g_grind_pending_exit_count = write_idx;
   ArrayResize(g_grind_pending_exit_measures, g_grind_pending_exit_count);
}

#endif // GRIND_PNL_MQH
