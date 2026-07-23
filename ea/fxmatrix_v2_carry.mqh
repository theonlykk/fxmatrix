//+------------------------------------------------------------------+
//| fxmatrix_v2_carry.mqh — ADR-045 daily rollover exit drift (V2)    |
//| Direct broker swap passthrough on resting exit limits only.       |
//| Does NOT port RunCarryRecalculation() tri-pair geometry.        |
//+------------------------------------------------------------------+
#ifndef FXMATRIX_V2_CARRY_MQH
#define FXMATRIX_V2_CARRY_MQH

#include "fxmatrix_v2_exits.mqh"

// Observability only — no hard cap. Exit drift is unbounded over many
// negative-carry nights (same as V1 ADR-045). ADD_PIPS_CEILING applies
// only to add spacing, not exit targets; no interaction.
#define V2_ROLLOVER_LOG_SHIFT_WARN_PIPS 15.0

//+------------------------------------------------------------------+
int V2_RolloverWednesdayMultiplier(const int day_of_week)
{
   // ADR-045 convention: Wednesday broker midnight (day_of_week==3).
   return (day_of_week == 3) ? 3 : 1;
}

//+------------------------------------------------------------------+
bool V2_RolloverBrokerWindowOpen(const datetime now)
{
   MqlDateTime dt;
   TimeToStruct(now, dt);
   return (dt.hour == 0);
}

//+------------------------------------------------------------------+
bool V2_RolloverTryConsumeDailyGate(int &last_rollover_day_of_year,
                                    const datetime now)
{
   MqlDateTime dt;
   TimeToStruct(now, dt);
   if(dt.hour != 0)
      return false;
   if(last_rollover_day_of_year == dt.day_of_year)
      return false;
   last_rollover_day_of_year = dt.day_of_year;
   return true;
}

//+------------------------------------------------------------------+
double V2_RolloverShiftPrice(const double swap_pts,
                             const int multiplier,
                             const double point)
{
   if(swap_pts >= 0.0 || point <= 0.0 || multiplier <= 0)
      return 0.0;
   return MathAbs(swap_pts) * (double)multiplier * point;
}

//+------------------------------------------------------------------+
double V2_RolloverShiftedExitPrice(const double current_exit,
                                   const double shift,
                                   const int entry_direction)
{
   if(entry_direction > 0)
      return current_exit + shift;
   return current_exit - shift;
}

//+------------------------------------------------------------------+
double V2_RolloverNormalizePrice(const string symbol, const double price)
{
   return NormalizeDouble(price, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));
}

//+------------------------------------------------------------------+
//| Incremental multi-night: shift from live order price when present.|
//+------------------------------------------------------------------+
bool V2_RolloverAdjustOneLayer(const string symbol,
                               const int entry_direction,
                               const int multiplier,
                               const bool verbose_log,
                               const double entry_price,
                               double &exit_target,
                               ulong &exit_ticket)
{
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;

   if(SymbolInfoInteger(symbol, SYMBOL_SWAP_MODE) != SYMBOL_SWAP_MODE_POINTS) {
      if(verbose_log)
         Print("WARNING [V2-ADR-045] Swap mode not POINTS — skipping. symbol=", symbol);
      return false;
   }

   double swap_long  = SymbolInfoDouble(symbol, SYMBOL_SWAP_LONG);
   double swap_short = SymbolInfoDouble(symbol, SYMBOL_SWAP_SHORT);
   double swap       = (entry_direction > 0) ? swap_long : swap_short;
   if(swap >= 0.0)
      return false;

   double shift = V2_RolloverShiftPrice(swap, multiplier, point);
   if(shift <= 0.0)
      return false;

   double current_exit = exit_target;
   if(exit_ticket != 0 && OrderSelect(exit_ticket))
      current_exit = OrderGetDouble(ORDER_PRICE_OPEN);

   double new_exit = V2_RolloverNormalizePrice(
      symbol,
      V2_RolloverShiftedExitPrice(current_exit, shift, entry_direction));

   if(MathAbs(new_exit - current_exit) < point * 0.5)
      return false;

   if(exit_ticket != 0 && OrderSelect(exit_ticket)) {
      if(!V2_ModifyExitLimitPrice(exit_ticket, new_exit, symbol, entry_direction, verbose_log))
         return false;
   }

   exit_target = new_exit;

   double drift_pips = 0.0;
   if(entry_price > 0.0 && point > 0.0) {
      drift_pips = MathAbs(new_exit - entry_price) / (point * 10.0);
      if(drift_pips >= V2_ROLLOVER_LOG_SHIFT_WARN_PIPS && verbose_log)
         Print("INFO [V2-ADR-045] exit drift from entry exceeds ",
               DoubleToString(V2_ROLLOVER_LOG_SHIFT_WARN_PIPS, 1),
               " pips (no hard cap). symbol=", symbol,
               " drift_pips=", DoubleToString(drift_pips, 2));
   }

   if(verbose_log)
      Print("INFO [V2-ADR-045] Exit adjusted.",
            " symbol=", symbol,
            " dir=", entry_direction,
            " ticket=", exit_ticket,
            " old=", DoubleToString(current_exit, 5),
            " new=", DoubleToString(new_exit, 5),
            " shift=", DoubleToString(shift, 5),
            " multiplier=", multiplier);

   return true;
}

#endif // FXMATRIX_V2_CARRY_MQH
