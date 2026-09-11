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

ulong    g_grind_carry_eligible_magic = 0;

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
ENUM_SYMBOL_INFO_INTEGER Grind_CarrySwapMultiplierProperty(const int day_of_week)
{
   switch(day_of_week) {
      case 0: return SYMBOL_SWAP_MULTIPLIER_SUNDAY;
      case 1: return SYMBOL_SWAP_MULTIPLIER_MONDAY;
      case 2: return SYMBOL_SWAP_MULTIPLIER_TUESDAY;
      case 3: return SYMBOL_SWAP_MULTIPLIER_WEDNESDAY;
      case 4: return SYMBOL_SWAP_MULTIPLIER_THURSDAY;
      case 5: return SYMBOL_SWAP_MULTIPLIER_FRIDAY;
      case 6: return SYMBOL_SWAP_MULTIPLIER_SATURDAY;
   }
   return SYMBOL_SWAP_ROLLOVER3DAYS;
}

//+------------------------------------------------------------------+
int Grind_CarrySwapMultiplier(const int day_of_week)
{
   if(day_of_week < 0 || day_of_week > 6)
      return 1;

   const long per_day = SymbolInfoInteger(_Symbol,
                                          Grind_CarrySwapMultiplierProperty(day_of_week));
   if(per_day > 0)
      return (int)per_day;

   const int rollover = (int)SymbolInfoInteger(_Symbol, SYMBOL_SWAP_ROLLOVER3DAYS);
   if(rollover >= 0 && rollover <= 6 && day_of_week == rollover)
      return 3;
   return 1;
}

//+------------------------------------------------------------------+
double Grind_CarryShiftPips(const double swap_points,
                            const int multiplier,
                            const int digits)
{
   if(multiplier <= 0)
      return 0.0;
   const int pips_div = (digits == 3 || digits == 5) ? 10 : 1;
   return swap_points * (double)multiplier / (double)pips_div;
}

//+------------------------------------------------------------------+
bool Grind_CarryPositionOpenTime(const ulong ticket,
                                 const ulong magic,
                                 datetime &open_time)
{
   if(ticket == 0)
      return false;
   if(Grind_CarryTestGetOpenTime(ticket, open_time))
      return true;
   if(!PositionSelectByTicket(ticket))
      return false;
   if(!Grind_MagicMatches(PositionGetInteger(POSITION_MAGIC), magic))
      return false;
   open_time = (datetime)PositionGetInteger(POSITION_TIME);
   return true;
}

//+------------------------------------------------------------------+
int Grind_CarryEligibleLayers(const GrindSideState &side,
                              const datetime broker_midnight)
{
   int count = 0;
   for(int i = 0; i < ArraySize(side.layers); i++) {
      const ulong ticket = side.layers[i].position_ticket;
      if(ticket == 0)
         continue;
      datetime open_time = 0;
      if(!Grind_CarryPositionOpenTime(ticket, g_grind_carry_eligible_magic, open_time))
         continue;
      if(open_time < broker_midnight)
         count++;
   }
   return count;
}

//+------------------------------------------------------------------+
double Grind_CarryAccruedSwapSide(const GrindSideState &side, const ulong magic)
{
   double total = 0.0;
   for(int i = 0; i < ArraySize(side.layers); i++) {
      const ulong ticket = side.layers[i].position_ticket;
      if(ticket == 0)
         continue;
      datetime open_time = 0;
      if(!Grind_CarryPositionOpenTime(ticket, magic, open_time))
         continue;
      if(!PositionSelectByTicket(ticket))
         continue;
      total += PositionGetDouble(POSITION_SWAP);
   }
   return total;
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
   MqlDateTime dt;
   TimeToStruct(now, dt);
   return (dt.hour == 23 && dt.min >= 50);
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
   if(!Grind_CarryGateInWindow(now))
      return false;

   MqlDateTime dt;
   TimeToStruct(now, dt);
   const int stored = Grind_CarryGateStoredDay(magic);
   if(stored == dt.day_of_year)
      return false;

   GlobalVariableSet(Grind_CarryGateGvName(magic), (double)dt.day_of_year);
   return true;
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
   return "\"symbol\":" + Grind_ArchiveJsonStringOrNull(symbol) +
          ",\"swap_mode\":" + IntegerToString(swap_mode) +
          ",\"swap_long\":" + Grind_ArchiveJsonDouble(swap_long, 4) +
          ",\"swap_short\":" + Grind_ArchiveJsonDouble(swap_short, 4) +
          ",\"multiplier\":" + IntegerToString(multiplier) +
          ",\"day_of_week\":" + IntegerToString(day_of_week) +
          ",\"rollover3days\":" + IntegerToString(rollover3days) +
          ",\"digits\":" + IntegerToString(digits) +
          ",\"point\":" + Grind_ArchiveJsonDouble(point, 8) +
          ",\"tick_value\":" + Grind_ArchiveJsonDouble(tick_value, 8) +
          ",\"tick_size\":" + Grind_ArchiveJsonDouble(tick_size, 8) +
          ",\"stops_level\":" + IntegerToString((int)stops_level) +
          ",\"freeze_level\":" + IntegerToString((int)freeze_level) +
          ",\"long_pips\":" + Grind_ArchiveJsonDouble(long_pips, 3) +
          ",\"short_pips\":" + Grind_ArchiveJsonDouble(short_pips, 3) +
          ",\"eligible_long\":" + IntegerToString(eligible_long) +
          ",\"eligible_short\":" + IntegerToString(eligible_short) +
          ",\"trade_mode_full\":" + Grind_ArchiveJsonBool(trade_mode_full) +
          ",\"mult_today\":" + IntegerToString(mult_today) +
          ",\"mult_tomorrow\":" + IntegerToString(mult_tomorrow) +
          ",\"accrued_swap_long\":" + Grind_ArchiveJsonDouble(accrued_swap_long, 2) +
          ",\"accrued_swap_short\":" + Grind_ArchiveJsonDouble(accrued_swap_short, 2);
}

//+------------------------------------------------------------------+
void Grind_CarryEmitSnapshot(const string symbol, const ulong magic)
{
   const datetime now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(now, dt);

   int swap_mode = 0;
   double swap_long = 0.0;
   double swap_short = 0.0;
   int multiplier = 1;
   int digits = 5;
   int rollover3days = 3;
   double point = 0.0;
   double tick_value = 0.0;
   double tick_size = 0.0;
   long stops_level = 0;
   long freeze_level = 0;
   int mult_today = 1;
   int mult_tomorrow = 1;

   if(g_grind_carry_test_snapshot_active) {
      swap_long = g_grind_carry_test_swap_long;
      swap_short = g_grind_carry_test_swap_short;
      multiplier = g_grind_carry_test_multiplier;
      digits = g_grind_carry_test_digits;
      mult_today = g_grind_carry_test_mult_today;
      mult_tomorrow = g_grind_carry_test_mult_tomorrow;
   } else {
      swap_mode = (int)SymbolInfoInteger(symbol, SYMBOL_SWAP_MODE);
      swap_long = SymbolInfoDouble(symbol, SYMBOL_SWAP_LONG);
      swap_short = SymbolInfoDouble(symbol, SYMBOL_SWAP_SHORT);
      rollover3days = (int)SymbolInfoInteger(symbol, SYMBOL_SWAP_ROLLOVER3DAYS);
      multiplier = Grind_CarrySwapMultiplier(dt.day_of_week);
      digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
      point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      tick_value = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
      tick_size = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
      stops_level = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
      freeze_level = SymbolInfoInteger(symbol, SYMBOL_TRADE_FREEZE_LEVEL);
      mult_today = Grind_CarrySwapMultiplier(dt.day_of_week);
      mult_tomorrow = Grind_CarrySwapMultiplier((dt.day_of_week + 1) % 7);
   }

   const double long_pips = Grind_CarryShiftPips(swap_long, multiplier, digits);
   const double short_pips = Grind_CarryShiftPips(swap_short, multiplier, digits);
   const datetime broker_midnight = Grind_CarryBrokerMidnight(now);
   g_grind_carry_eligible_magic = magic;
   const int eligible_long = Grind_CarryEligibleLayers(g_grind_long, broker_midnight);
   const int eligible_short = Grind_CarryEligibleLayers(g_grind_short, broker_midnight);
   const bool trade_mode_full = Grind_MarketTradeModeFull(
      SymbolInfoInteger(symbol, SYMBOL_TRADE_MODE));
   const double accrued_swap_long = Grind_CarryAccruedSwapSide(g_grind_long, magic);
   const double accrued_swap_short = Grind_CarryAccruedSwapSide(g_grind_short, magic);

   const string fields = Grind_CarrySnapshotFields(
      symbol,
      swap_mode,
      swap_long,
      swap_short,
      multiplier,
      dt.day_of_week,
      rollover3days,
      digits,
      point,
      tick_value,
      tick_size,
      stops_level,
      freeze_level,
      long_pips,
      short_pips,
      eligible_long,
      eligible_short,
      trade_mode_full,
      mult_today,
      mult_tomorrow,
      accrued_swap_long,
      accrued_swap_short);

   Grind_ArchiveMarker("INFO", "CARRY_SNAPSHOT", symbol, 0, fields);
}

#endif // GRIND_CARRY_MQH
