//+------------------------------------------------------------------+
//| grind_carry.mqh — ADR-135a carry snapshot + rollover day gate     |
//+------------------------------------------------------------------+
#ifndef GRIND_CARRY_MQH
#define GRIND_CARRY_MQH

#include "grind_archive.mqh"
#include "grind_state.mqh"
#include "grind_pure.mqh"

ulong    g_grind_carry_test_tickets[];
datetime g_grind_carry_test_open_times[];
int      g_grind_carry_test_open_count = 0;

bool     g_grind_carry_test_snapshot_active = false;
double   g_grind_carry_test_swap_long = 0.0;
double   g_grind_carry_test_swap_short = 0.0;
int      g_grind_carry_test_multiplier = 0;
int      g_grind_carry_test_digits = 0;
int      g_grind_carry_test_mult_today = 0;
int      g_grind_carry_test_mult_tomorrow = 0;

//+------------------------------------------------------------------+
void Grind_CarryTestReset()
{
   ArrayResize(g_grind_carry_test_tickets, 0);
   ArrayResize(g_grind_carry_test_open_times, 0);
   g_grind_carry_test_open_count = 0;
   g_grind_carry_test_snapshot_active = false;
   g_grind_carry_test_swap_long = 0.0;
   g_grind_carry_test_swap_short = 0.0;
   g_grind_carry_test_multiplier = 0;
   g_grind_carry_test_digits = 0;
   g_grind_carry_test_mult_today = 0;
   g_grind_carry_test_mult_tomorrow = 0;
}

//+------------------------------------------------------------------+
void Grind_CarryTestSetOpenTime(const ulong ticket, const datetime open_time)
{
   for(int i = 0; i < g_grind_carry_test_open_count; i++) {
      if(g_grind_carry_test_tickets[i] == ticket) {
         g_grind_carry_test_open_times[i] = open_time;
         return;
      }
   }
   ArrayResize(g_grind_carry_test_tickets, g_grind_carry_test_open_count + 1);
   ArrayResize(g_grind_carry_test_open_times, g_grind_carry_test_open_count + 1);
   g_grind_carry_test_tickets[g_grind_carry_test_open_count] = ticket;
   g_grind_carry_test_open_times[g_grind_carry_test_open_count] = open_time;
   g_grind_carry_test_open_count++;
}

//+------------------------------------------------------------------+
bool Grind_CarryTestGetOpenTime(const ulong ticket, datetime &open_time)
{
   for(int i = 0; i < g_grind_carry_test_open_count; i++) {
      if(g_grind_carry_test_tickets[i] == ticket) {
         open_time = g_grind_carry_test_open_times[i];
         return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
int Grind_CarrySwapMultiplier(const int day_of_week)
{
   return 0;
}

//+------------------------------------------------------------------+
double Grind_CarryShiftPips(const double swap_points,
                            const int multiplier,
                            const int digits)
{
   return 0.0;
}

//+------------------------------------------------------------------+
int Grind_CarryEligibleLayers(const GrindSideState &side,
                              const datetime broker_midnight)
{
   return 0;
}

//+------------------------------------------------------------------+
datetime Grind_CarryBrokerMidnight(const datetime now)
{
   MqlDateTime dt;
   TimeToStruct(now, dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   return StructToTime(dt);
}

//+------------------------------------------------------------------+
bool Grind_CarryGateInWindow(const datetime now)
{
   return false;
}

//+------------------------------------------------------------------+
string Grind_CarryGateGvName(const ulong magic)
{
   return "GRIND_CARRY_DAY_" + IntegerToString((long)magic);
}

//+------------------------------------------------------------------+
int Grind_CarryGateStoredDay(const ulong magic)
{
   const string name = Grind_CarryGateGvName(magic);
   if(!GlobalVariableCheck(name))
      return -1;
   return (int)GlobalVariableGet(name);
}

//+------------------------------------------------------------------+
void Grind_CarryGateReset(const ulong magic)
{
   GlobalVariableDel(Grind_CarryGateGvName(magic));
}

//+------------------------------------------------------------------+
bool Grind_CarryGateDue(const ulong magic, const datetime now)
{
   return false;
}

//+------------------------------------------------------------------+
string Grind_CarrySnapshotFields(const string symbol,
                                 const int swap_mode,
                                 const double swap_long,
                                 const double swap_short,
                                 const int multiplier,
                                 const int day_of_week,
                                 const int rollover3days,
                                 const int digits,
                                 const double point,
                                 const double tick_value,
                                 const double tick_size,
                                 const long stops_level,
                                 const long freeze_level,
                                 const double long_pips,
                                 const double short_pips,
                                 const int eligible_long,
                                 const int eligible_short,
                                 const bool trade_mode_full,
                                 const int mult_today,
                                 const int mult_tomorrow,
                                 const double accrued_swap_long,
                                 const double accrued_swap_short)
{
   return "";
}

//+------------------------------------------------------------------+
void Grind_CarryEmitSnapshot(const string symbol, const ulong magic)
{
}

#endif // GRIND_CARRY_MQH
