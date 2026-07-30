//+------------------------------------------------------------------+
//| fxmatrix_v2_carry.mqh — ADR-045 daily rollover exit drift (V2)    |
//| Direct broker swap passthrough on resting exit limits only.       |
//| ADR-101: bounded same-day retry for exit-modify failures.         |
//| Does NOT port RunCarryRecalculation() tri-pair geometry.        |
//+------------------------------------------------------------------+
#ifndef FXMATRIX_V2_CARRY_MQH
#define FXMATRIX_V2_CARRY_MQH

// Observability only — no hard cap. Exit drift is unbounded over many
// negative-carry nights (same as V1 ADR-045). ADD_PIPS_CEILING applies
// only to add spacing, not exit targets; no interaction.
#define V2_ROLLOVER_LOG_SHIFT_WARN_PIPS 15.0

//+------------------------------------------------------------------+
//| ADR-101 session-local retry state (not layer struct / not GV).    |
//+------------------------------------------------------------------+
struct V2RolloverSideRetryState
{
   ulong    pending_position_tickets[];
   int      retry_attempt_count;
   datetime next_retry_due;
};

struct V2RolloverLayerSlot
{
   ulong  position_ticket;
   double entry_price;
   double exit_target;
   ulong  exit_ticket;
   bool   position_live;
};

// Unit-test hook — disabled in production (g_v2_rollover_use_test_adjust=false).
bool     g_v2_rollover_use_test_adjust = false;
ulong    g_v2_rollover_test_adjust_calls[];
double   g_v2_rollover_test_shift_price = 0.0;
ulong    g_v2_rollover_test_success_tickets[];

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
void V2_RolloverRetryResetState(V2RolloverSideRetryState &state)
{
   ArrayResize(state.pending_position_tickets, 0);
   state.retry_attempt_count = 0;
   state.next_retry_due = 0;
}

//+------------------------------------------------------------------+
bool V2_RolloverRetryPendingContains(const V2RolloverSideRetryState &state,
                                     const ulong position_ticket)
{
   for(int i = 0; i < ArraySize(state.pending_position_tickets); i++) {
      if(state.pending_position_tickets[i] == position_ticket)
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
void V2_RolloverRetryRecordFailure(V2RolloverSideRetryState &state,
                                   const ulong position_ticket,
                                   const datetime now,
                                   const int retry_minutes)
{
   if(V2_RolloverRetryPendingContains(state, position_ticket))
      return;

   const int n = ArraySize(state.pending_position_tickets);
   ArrayResize(state.pending_position_tickets, n + 1);
   state.pending_position_tickets[n] = position_ticket;
   state.next_retry_due = now + retry_minutes * 60;
}

//+------------------------------------------------------------------+
void V2_RolloverRetryRemovePendingAt(V2RolloverSideRetryState &state,
                                     const int index)
{
   const int n = ArraySize(state.pending_position_tickets);
   if(index < 0 || index >= n)
      return;

   for(int i = index; i < n - 1; i++)
      state.pending_position_tickets[i] = state.pending_position_tickets[i + 1];
   ArrayResize(state.pending_position_tickets, n - 1);
}

//+------------------------------------------------------------------+
void V2_RolloverRetryRemovePending(V2RolloverSideRetryState &state,
                                   const ulong position_ticket)
{
   for(int i = ArraySize(state.pending_position_tickets) - 1; i >= 0; i--) {
      if(state.pending_position_tickets[i] == position_ticket)
         V2_RolloverRetryRemovePendingAt(state, i);
   }
}

//+------------------------------------------------------------------+
int V2_RolloverFindLayerIndex(const V2RolloverLayerSlot &layers[],
                              const ulong position_ticket)
{
   for(int i = 0; i < ArraySize(layers); i++) {
      if(layers[i].position_ticket == position_ticket)
         return i;
   }
   return -1;
}

//+------------------------------------------------------------------+
bool V2_RolloverTestAdjustShouldSucceed(const ulong position_ticket)
{
   for(int i = 0; i < ArraySize(g_v2_rollover_test_success_tickets); i++) {
      if(g_v2_rollover_test_success_tickets[i] == position_ticket)
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
void V2_RolloverTestAdjustRecordCall(const ulong position_ticket)
{
   const int n = ArraySize(g_v2_rollover_test_adjust_calls);
   ArrayResize(g_v2_rollover_test_adjust_calls, n + 1);
   g_v2_rollover_test_adjust_calls[n] = position_ticket;
}

//+------------------------------------------------------------------+
void V2_RolloverTestAdjustReset()
{
   g_v2_rollover_use_test_adjust = false;
   ArrayResize(g_v2_rollover_test_adjust_calls, 0);
   ArrayResize(g_v2_rollover_test_success_tickets, 0);
   g_v2_rollover_test_shift_price = 0.0;
}

//+------------------------------------------------------------------+
bool V2_RolloverAdjustOneLayerForRetry(const string symbol,
                                       const int entry_direction,
                                       const int multiplier,
                                       const bool verbose_log,
                                       const double entry_price,
                                       double &exit_target,
                                       ulong &exit_ticket,
                                       const ulong position_ticket)
{
   if(g_v2_rollover_use_test_adjust) {
      V2_RolloverTestAdjustRecordCall(position_ticket);
      if(!V2_RolloverTestAdjustShouldSucceed(position_ticket))
         return false;

      const double shift = g_v2_rollover_test_shift_price;
      exit_target = V2_RolloverNormalizePrice(
         symbol,
         V2_RolloverShiftedExitPrice(exit_target, shift, entry_direction));
      return true;
   }

   return V2_RolloverAdjustOneLayer(symbol, entry_direction, multiplier, verbose_log,
                                    entry_price, exit_target, exit_ticket);
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

//+------------------------------------------------------------------+
void V2_RunDailyRolloverSidePass(const string symbol,
                                 const int entry_direction,
                                 const int multiplier,
                                 const bool verbose_log,
                                 const int retry_minutes,
                                 V2RolloverSideRetryState &retry_state,
                                 V2RolloverLayerSlot &layers[])
{
   const datetime now = TimeCurrent();

   for(int i = 0; i < ArraySize(layers); i++) {
      if(!layers[i].position_live)
         continue;

      const bool ok = V2_RolloverAdjustOneLayerForRetry(
         symbol, entry_direction, multiplier, verbose_log,
         layers[i].entry_price, layers[i].exit_target, layers[i].exit_ticket,
         layers[i].position_ticket);

      if(!ok)
         V2_RolloverRetryRecordFailure(retry_state, layers[i].position_ticket,
                                       now, retry_minutes);
   }
}

//+------------------------------------------------------------------+
void V2_RunRolloverRetryPass(const string symbol,
                             const int entry_direction,
                             const int multiplier,
                             const bool verbose_log,
                             const int retry_minutes,
                             const int max_retries,
                             V2RolloverSideRetryState &retry_state,
                             V2RolloverLayerSlot &layers[])
{
   if(ArraySize(retry_state.pending_position_tickets) == 0)
      return;

   const datetime now = TimeCurrent();
   if(now < retry_state.next_retry_due)
      return;
   if(retry_state.retry_attempt_count >= max_retries)
      return;

   for(int p = ArraySize(retry_state.pending_position_tickets) - 1; p >= 0; p--) {
      const ulong position_ticket = retry_state.pending_position_tickets[p];
      const int layer_idx = V2_RolloverFindLayerIndex(layers, position_ticket);
      if(layer_idx < 0 || !layers[layer_idx].position_live)
         continue;

      const bool ok = V2_RolloverAdjustOneLayerForRetry(
         symbol, entry_direction, multiplier, verbose_log,
         layers[layer_idx].entry_price, layers[layer_idx].exit_target,
         layers[layer_idx].exit_ticket, position_ticket);

      if(ok)
         V2_RolloverRetryRemovePendingAt(retry_state, p);
   }

   retry_state.retry_attempt_count++;
   retry_state.next_retry_due = now + retry_minutes * 60;

   if(retry_state.retry_attempt_count >= max_retries &&
      ArraySize(retry_state.pending_position_tickets) > 0) {
      string pending_list = "";
      for(int i = 0; i < ArraySize(retry_state.pending_position_tickets); i++) {
         if(i > 0)
            pending_list += ",";
         pending_list += IntegerToString((long)retry_state.pending_position_tickets[i]);
      }
      Print("ERROR [V2-ADR-101] Rollover exit-modify failed for the day.",
            " symbol=", symbol,
            " dir=", entry_direction,
            " pending_position_tickets=", pending_list,
            " retry_attempts=", retry_state.retry_attempt_count);
   }
}

#endif // FXMATRIX_V2_CARRY_MQH
