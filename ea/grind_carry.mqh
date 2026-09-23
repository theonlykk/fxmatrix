//+------------------------------------------------------------------+
//| grind_carry.mqh — ADR-135a carry snapshot + rollover day gate     |
//+------------------------------------------------------------------+
#ifndef GRIND_CARRY_MQH
#define GRIND_CARRY_MQH

#include "grind_archive.mqh"
#include "grind_state.mqh"
#include "grind_pure.mqh"
#include "grind_config.mqh"

bool Grind_OrderTestActive();
bool Grind_PositionTestExistsAnyMagic(const ulong ticket);

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

bool     g_grind_carry_test_rollover_active = false;
int      g_grind_carry_test_rollover_day = 3;

ulong    g_grind_carry_eligible_magic = 0;

#define GRIND_CARRY_PASS_CHUNK 2
#define GRIND_CARRY_RETRY_MAX  3
#define GRIND_CARRY_TICK_FRESH_SEC 120

datetime g_grind_carry_test_server_time = 0;
datetime g_grind_carry_test_tick_time = 0;
double   g_grind_carry_test_tick_bid = 0.0;
double   g_grind_carry_test_tick_ask = 0.0;
long     g_grind_carry_test_trade_mode = (long)SYMBOL_TRADE_MODE_FULL;
bool     g_grind_carry_test_tick_active = false;

ulong    g_grind_carry_test_pos_tickets[];
double   g_grind_carry_test_pos_swap[];
double   g_grind_carry_test_pos_volume[];
int      g_grind_carry_test_pos_count = 0;

bool     g_grind_carry_exit_pass_active = false;
bool     g_grind_carry_exit_snapshot_emitted = false;
int      g_grind_carry_exit_work_count = 0;
int      g_grind_carry_exit_work_cursor = 0;
int      g_grind_carry_exit_shifted = 0;
int      g_grind_carry_exit_clamped = 0;
int      g_grind_carry_exit_skipped = 0;
int      g_grind_carry_exit_failed = 0;

ulong    g_grind_carry_exit_retry_tickets[];
int      g_grind_carry_exit_retry_attempts[];
int      g_grind_carry_exit_retry_count = 0;

ulong    g_grind_carry_exit_work_pos[];
ulong    g_grind_carry_exit_work_exit[];
double   g_grind_carry_exit_work_entry[];
double   g_grind_carry_exit_work_formula[];
bool     g_grind_carry_exit_work_long[];
int      g_grind_carry_exit_work_layer[];
int      g_grind_carry_exit_work_done = 0;
int      g_grind_carry_exit_eligible = 0;
long     g_grind_carry_exit_last_tick_msc = 0;

bool     Grind_SelectOurPosition(const ulong ticket, const ulong magic);
bool     Grind_ModifyPendingPrice(const ulong ticket,
                                  const double new_price,
                                  const ulong magic);
double   Grind_OrderGetPriceOpen(const ulong ticket);

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
   g_grind_carry_test_rollover_active = false;
   g_grind_carry_test_rollover_day = 3;
   g_grind_carry_test_server_time = 0;
   g_grind_carry_test_tick_time = 0;
   g_grind_carry_test_tick_bid = 0.0;
   g_grind_carry_test_tick_ask = 0.0;
   g_grind_carry_test_trade_mode = (long)SYMBOL_TRADE_MODE_FULL;
   g_grind_carry_test_tick_active = false;
   ArrayResize(g_grind_carry_test_pos_tickets, 0);
   ArrayResize(g_grind_carry_test_pos_swap, 0);
   ArrayResize(g_grind_carry_test_pos_volume, 0);
   g_grind_carry_test_pos_count = 0;
   g_grind_carry_exit_pass_active = false;
   g_grind_carry_exit_snapshot_emitted = false;
   g_grind_carry_exit_work_count = 0;
   g_grind_carry_exit_work_cursor = 0;
   g_grind_carry_exit_shifted = 0;
   g_grind_carry_exit_clamped = 0;
   g_grind_carry_exit_skipped = 0;
   g_grind_carry_exit_failed = 0;
   ArrayResize(g_grind_carry_exit_retry_tickets, 0);
   ArrayResize(g_grind_carry_exit_retry_attempts, 0);
   g_grind_carry_exit_retry_count = 0;
   ArrayResize(g_grind_carry_exit_work_pos, 0);
   ArrayResize(g_grind_carry_exit_work_exit, 0);
   ArrayResize(g_grind_carry_exit_work_entry, 0);
   ArrayResize(g_grind_carry_exit_work_formula, 0);
   ArrayResize(g_grind_carry_exit_work_long, 0);
   ArrayResize(g_grind_carry_exit_work_layer, 0);
   g_grind_carry_exit_work_done = 0;
   g_grind_carry_exit_eligible = 0;
   g_grind_carry_exit_last_tick_msc = 0;
}

//+------------------------------------------------------------------+
void Grind_CarryTestSetPosition(const ulong ticket,
                                const double swap,
                                const double volume,
                                const datetime open_time)
{
   for(int i = 0; i < g_grind_carry_test_pos_count; i++) {
      if(g_grind_carry_test_pos_tickets[i] == ticket) {
         g_grind_carry_test_pos_swap[i] = swap;
         g_grind_carry_test_pos_volume[i] = volume;
         Grind_CarryTestSetOpenTime(ticket, open_time);
         return;
      }
   }
   ArrayResize(g_grind_carry_test_pos_tickets, g_grind_carry_test_pos_count + 1);
   ArrayResize(g_grind_carry_test_pos_swap, g_grind_carry_test_pos_count + 1);
   ArrayResize(g_grind_carry_test_pos_volume, g_grind_carry_test_pos_count + 1);
   g_grind_carry_test_pos_tickets[g_grind_carry_test_pos_count] = ticket;
   g_grind_carry_test_pos_swap[g_grind_carry_test_pos_count] = swap;
   g_grind_carry_test_pos_volume[g_grind_carry_test_pos_count] = volume;
   g_grind_carry_test_pos_count++;
   Grind_CarryTestSetOpenTime(ticket, open_time);
}

//+------------------------------------------------------------------+
void Grind_CarryTestSeedTick(const datetime tick_time,
                             const double bid,
                             const double ask)
{
   g_grind_carry_test_tick_active = true;
   g_grind_carry_test_tick_time = tick_time;
   g_grind_carry_test_tick_bid = bid;
   g_grind_carry_test_tick_ask = ask;
}

//+------------------------------------------------------------------+
datetime Grind_CarryServerTime()
{
   if(g_grind_carry_test_server_time > 0)
      return g_grind_carry_test_server_time;
   return TimeTradeServer();
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
   if(day_of_week < 0 || day_of_week > 6)
      return 1;

   int rollover3days;
   if(g_grind_carry_test_rollover_active)
      rollover3days = g_grind_carry_test_rollover_day;
   else
      rollover3days = (int)SymbolInfoInteger(_Symbol, SYMBOL_SWAP_ROLLOVER3DAYS);

   if(day_of_week == 0 || day_of_week == 6)
      return 0;
   if(day_of_week == rollover3days)
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
int Grind_CarryOpenLayers(const GrindSideState &side)
{
   int count = 0;
   for(int i = 0; i < ArraySize(side.layers); i++) {
      const ulong ticket = side.layers[i].position_ticket;
      if(ticket == 0)
         continue;
      datetime open_time = 0;
      if(Grind_CarryTestGetOpenTime(ticket, open_time)) {
         count++;
         continue;
      }
      if(Grind_SelectOurPosition(ticket, g_grind_carry_eligible_magic))
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

   return true;
}

//+------------------------------------------------------------------+
void Grind_CarryGateMarkDone(const ulong magic, const datetime now)
{
   if(!Grind_CarryGateInWindow(now))
      return;

   MqlDateTime dt;
   TimeToStruct(now, dt);
   GlobalVariableSet(Grind_CarryGateGvName(magic), (double)dt.day_of_year);
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
   return "{" +
          "\"symbol\":" + Grind_ArchiveJsonStringOrNull(symbol) +
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
          ",\"accrued_swap_short\":" + Grind_ArchiveJsonDouble(accrued_swap_short, 2) +
          "}";
}

//+------------------------------------------------------------------+
double Grind_CarryShiftedExitPrice(const double formula_exit,
                                   const int direction,
                                   const double accrued_pips,
                                   const double pip_size)
{
   return formula_exit - (double)direction * accrued_pips * pip_size;
}

//+------------------------------------------------------------------+
bool Grind_CarryLedgerToPips(const double swap_account,
                             const double volume,
                             const double tick_value,
                             const double tick_size,
                             const double pip_size,
                             double &pips_out)
{
   if(tick_size <= 0.0 || tick_value <= 0.0 || pip_size <= 0.0 || volume <= 0.0)
      return false;
   const double price_delta = swap_account * tick_size / (tick_value * volume);
   pips_out = price_delta / pip_size;
   return true;
}

//+------------------------------------------------------------------+
double Grind_CarryPendingPips(const double swap_points,
                              const int mult_tomorrow,
                              const int digits)
{
   return Grind_CarryShiftPips(swap_points, mult_tomorrow, digits);
}

//+------------------------------------------------------------------+
double Grind_CarryPipSize(const int digits, const double point)
{
   if(digits == 3 || digits == 5)
      return 10.0 * point;
   return point;
}

//+------------------------------------------------------------------+
bool Grind_CarrySignGuardBlocks(const double entry,
                                const double new_exit,
                                const bool is_long)
{
   if(is_long)
      return (new_exit <= entry);
   return (new_exit >= entry);
}

//+------------------------------------------------------------------+
double Grind_CarryMinPassiveDistance(const double point,
                                     const long stops_level,
                                     const long freeze_level)
{
   return MathMax(point, MathMax(stops_level * point, freeze_level * point));
}

//+------------------------------------------------------------------+
bool Grind_CarryClampLongExit(const double theoretical,
                              const double bid,
                              const double ask,
                              const double point,
                              const long stops_level,
                              const long freeze_level,
                              double &out_price)
{
   const double min_dist = Grind_CarryMinPassiveDistance(point, stops_level, freeze_level);
   out_price = theoretical;
   if(theoretical <= ask + min_dist - 1e-12) {
      out_price = ask + min_dist;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
bool Grind_CarryClampShortExit(const double theoretical,
                               const double bid,
                               const double ask,
                               const double point,
                               const long stops_level,
                               const long freeze_level,
                               double &out_price)
{
   const double min_dist = Grind_CarryMinPassiveDistance(point, stops_level, freeze_level);
   out_price = theoretical;
   if(theoretical >= bid - min_dist + 1e-12) {
      out_price = bid - min_dist;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
string Grind_CarryShiftGvName(const ulong position_ticket)
{
   return "GRIND_CARRY_SHIFT_" + IntegerToString((long)position_ticket);
}

//+------------------------------------------------------------------+
double Grind_CarryShiftGet(const ulong position_ticket)
{
   const string name = Grind_CarryShiftGvName(position_ticket);
   if(!GlobalVariableCheck(name))
      return 0.0;
   return GlobalVariableGet(name);
}

//+------------------------------------------------------------------+
void Grind_CarryShiftSet(const ulong position_ticket, const double shift_price)
{
   GlobalVariableSet(Grind_CarryShiftGvName(position_ticket), shift_price);
}

//+------------------------------------------------------------------+
string Grind_CarryReleaseGvNameLocal(const ulong position_ticket)
{
   return GRIND_CARRY_RELEASE_PREFIX + IntegerToString((long)position_ticket);
}

//+------------------------------------------------------------------+
void Grind_CarryShiftDelete(const ulong position_ticket)
{
   GlobalVariableDel(Grind_CarryShiftGvName(position_ticket));
   GlobalVariableDel(Grind_CarryReleaseGvNameLocal(position_ticket));
}

//+------------------------------------------------------------------+
void Grind_CarryRecordShift(const ulong position_ticket,
                            const double applied_shift,
                            const bool clamped)
{
   // C25 stub: today's behaviour -- store the shift, no release marker
   Grind_CarryShiftSet(position_ticket, applied_shift);
}

//+------------------------------------------------------------------+
string Grind_EjectOffsetName(const ulong position_ticket)
{
   return "GRIND_EJECT_OFFSET_" + IntegerToString((long)position_ticket);
}

//+------------------------------------------------------------------+
double Grind_EjectOffsetGet(const ulong position_ticket)
{
   const string name = Grind_EjectOffsetName(position_ticket);
   if(!GlobalVariableCheck(name))
      return 0.0;
   return GlobalVariableGet(name);
}

//+------------------------------------------------------------------+
void Grind_EjectOffsetSet(const ulong position_ticket, const double offset_price)
{
   GlobalVariableSet(Grind_EjectOffsetName(position_ticket), offset_price);
}

//+------------------------------------------------------------------+
void Grind_EjectOffsetDelete(const ulong position_ticket)
{
   GlobalVariableDel(Grind_EjectOffsetName(position_ticket));
}

//+------------------------------------------------------------------+
bool Grind_EjectIsEjected(const ulong position_ticket)
{
   return (Grind_EjectOffsetGet(position_ticket) != 0.0);
}

//+------------------------------------------------------------------+
string Grind_EjectCommandName(const ulong magic)
{
   return "GRIND_EJECT_" + IntegerToString((long)magic);
}

//+------------------------------------------------------------------+
double Grind_EjectTargetPrice(const bool is_long)
{
   const double bid = Grind_MarketBid();
   const double ask = Grind_MarketAsk();
   const double point = _Point;
   const long stops = Grind_MarketStopsLevel();
   const long freeze = Grind_MarketFreezeLevel();
   double out = 0.0;
   if(is_long) {
      Grind_CarryClampLongExit(bid, bid, ask, point, stops, freeze, out);
      return out;
   }
   Grind_CarryClampShortExit(ask, bid, ask, point, stops, freeze, out);
   return out;
}

//+------------------------------------------------------------------+
bool Grind_CarrySignGuardAppliesAtShift(const ulong position_ticket,
                                        const double entry,
                                        const double new_exit,
                                        const bool is_long)
{
   if(Grind_EjectIsEjected(position_ticket))
      return false;
   return Grind_CarrySignGuardBlocks(entry, new_exit, is_long);
}

//+------------------------------------------------------------------+
string Grind_CarryAccruedGvName(const ulong position_ticket)
{
   return "GRIND_CARRY_ACCRUED_" + IntegerToString((long)position_ticket);
}

//+------------------------------------------------------------------+
double Grind_CarryAccruedGet(const ulong position_ticket)
{
   const string name = Grind_CarryAccruedGvName(position_ticket);
   if(!GlobalVariableCheck(name))
      return 0.0;
   return GlobalVariableGet(name);
}

//+------------------------------------------------------------------+
void Grind_CarryAccruedSet(const ulong position_ticket, const double accrued_price)
{
   GlobalVariableSet(Grind_CarryAccruedGvName(position_ticket), accrued_price);
}

//+------------------------------------------------------------------+
void Grind_CarryAccruedDelete(const ulong position_ticket)
{
   GlobalVariableDel(Grind_CarryAccruedGvName(position_ticket));
}

//+------------------------------------------------------------------+
bool Grind_CarryShiftWithinBound(const ulong position_ticket,
                                 const double shift_price,
                                 const datetime open_time,
                                 const double nightly_max_pips)
{
   if(open_time <= 0 || nightly_max_pips <= 0.0)
      return true;
   const datetime now = Grind_CarryServerTime();
   int nights = (int)((now - open_time) / 86400);
   if(nights < 0)
      nights = 0;
   const int max_nights = nights + 7;
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double pip_size = Grind_CarryPipSize(digits, point);
   const double max_price = (double)max_nights * nightly_max_pips * pip_size * 2.0;
   return (MathAbs(shift_price) <= max_price);
}

//+------------------------------------------------------------------+
double Grind_CarryShiftGetValidated(const ulong position_ticket,
                                    const datetime open_time,
                                    const double nightly_max_pips)
{
   const string release_gv = Grind_CarryReleaseGvNameLocal(position_ticket);
   if(GlobalVariableCheck(release_gv))
      return Grind_CarryShiftGet(position_ticket);

   // ADR-155: an ejected exit sits at the market; a clamp residual on it
   // (e.g. rollover spread) is legitimate and must not be bound-deleted.
   if(Grind_EjectIsEjected(position_ticket))
      return Grind_CarryShiftGet(position_ticket);

   const double shift = Grind_CarryShiftGet(position_ticket);
   if(shift == 0.0)
      return 0.0;
   if(!Grind_CarryShiftWithinBound(position_ticket, shift, open_time, nightly_max_pips)) {
      Grind_CarryShiftDelete(position_ticket);
      return 0.0;
   }
   return shift;
}

//+------------------------------------------------------------------+
double Grind_CarryNightlyMaxPips(const string symbol)
{
   const double swap_long = MathAbs(SymbolInfoDouble(symbol, SYMBOL_SWAP_LONG));
   const double swap_short = MathAbs(SymbolInfoDouble(symbol, SYMBOL_SWAP_SHORT));
   const double swap_points = MathMax(swap_long, swap_short);
   const int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   return MathAbs(Grind_CarryShiftPips(swap_points, 3, digits));
}

//+------------------------------------------------------------------+
double Grind_CarryShiftGetForRecon(const ulong position_id)
{
   datetime open_time = 0;
   if(!Grind_CarryTestGetOpenTime(position_id, open_time)) {
      if(PositionSelectByTicket(position_id))
         open_time = (datetime)PositionGetInteger(POSITION_TIME);
   }
   const double nightly = Grind_CarryNightlyMaxPips(_Symbol);
   return Grind_CarryShiftGetValidated(position_id, open_time, nightly);
}

//+------------------------------------------------------------------+
bool Grind_CarrySessionReady(const string symbol)
{
   MqlTick tick;
   if(g_grind_carry_test_tick_active) {
      tick.bid = g_grind_carry_test_tick_bid;
      tick.ask = g_grind_carry_test_tick_ask;
      tick.time = g_grind_carry_test_tick_time;
      tick.time_msc = (long)tick.time * 1000;
   } else {
      if(!SymbolInfoTick(symbol, tick))
         return false;
   }
   if(tick.bid <= 0.0 || tick.ask < tick.bid)
      return false;
   const datetime server = Grind_CarryServerTime();
   if((int)(server - tick.time) >= GRIND_CARRY_TICK_FRESH_SEC)
      return false;
   long trade_mode;
   if(g_grind_carry_test_tick_active)
      trade_mode = g_grind_carry_test_trade_mode;
   else
      trade_mode = SymbolInfoInteger(symbol, SYMBOL_TRADE_MODE);
   if(!Grind_MarketTradeModeFull(trade_mode))
      return false;
   g_grind_carry_exit_last_tick_msc = tick.time_msc;
   return true;
}

//+------------------------------------------------------------------+
int Grind_CarryRolloversCrossed(const datetime open_time, const datetime now)
{
   if(open_time <= 0 || now <= open_time)
      return 0;
   int nights = (int)((now - open_time) / 86400);
   if(nights < 1)
      nights = 1;
   return nights;
}

//+------------------------------------------------------------------+
double Grind_CarryPointsNativePips(const double swap_points,
                                   const int rollovers_crossed,
                                   const int digits)
{
   return Grind_CarryShiftPips(swap_points, rollovers_crossed, digits);
}

//+------------------------------------------------------------------+
bool Grind_CarryPositionSwapVolume(const ulong ticket,
                                   const ulong magic,
                                   double &swap_out,
                                   double &volume_out,
                                   datetime &open_time_out)
{
   for(int i = 0; i < g_grind_carry_test_pos_count; i++) {
      if(g_grind_carry_test_pos_tickets[i] != ticket)
         continue;
      swap_out = g_grind_carry_test_pos_swap[i];
      volume_out = g_grind_carry_test_pos_volume[i];
      Grind_CarryTestGetOpenTime(ticket, open_time_out);
      return true;
   }
   if(!Grind_SelectOurPosition(ticket, magic))
      return false;
   if(!PositionSelectByTicket(ticket))
      return false;
   swap_out = PositionGetDouble(POSITION_SWAP);
   volume_out = PositionGetDouble(POSITION_VOLUME);
   open_time_out = (datetime)PositionGetInteger(POSITION_TIME);
   return true;
}

//+------------------------------------------------------------------+
void Grind_CarryEmitExitShiftEvent(const string symbol,
                                   const ulong position_ticket,
                                   const string side,
                                   const int layer_index,
                                   const double ledger_pips,
                                   const double pending_pips,
                                   const double total_pips,
                                   const double old_price,
                                   const double new_price,
                                   const bool clamped,
                                   const bool sign_guard_skipped,
                                   const uint retcode,
                                   const double points_native_pips)
{
   const string fields =
      "{" +
      "\"position_ticket\":" + IntegerToString((long)position_ticket) +
      ",\"side\":" + Grind_ArchiveJsonStringOrNull(side) +
      ",\"layer_index\":" + IntegerToString(layer_index) +
      ",\"accrued_ledger_pips\":" + Grind_ArchiveJsonDouble(ledger_pips, 3) +
      ",\"pending_pips\":" + Grind_ArchiveJsonDouble(pending_pips, 3) +
      ",\"accrued_pips_total\":" + Grind_ArchiveJsonDouble(total_pips, 3) +
      ",\"old_price\":" + Grind_ArchiveJsonDouble(old_price, 5) +
      ",\"new_price\":" + Grind_ArchiveJsonDouble(new_price, 5) +
      ",\"clamped\":" + Grind_ArchiveJsonBool(clamped) +
      ",\"sign_guard_skipped\":" + Grind_ArchiveJsonBool(sign_guard_skipped) +
      ",\"retcode\":" + IntegerToString((int)retcode) +
      ",\"points_native_pips\":" + Grind_ArchiveJsonDouble(points_native_pips, 3) +
      "}";
   Grind_ArchiveMarker("INFO", "CARRY_EXIT_SHIFT", symbol, 0, fields);
}

//+------------------------------------------------------------------+
void Grind_CarryEmitPassSummary(const string symbol,
                                const int eligible,
                                const int shifted,
                                const int clamped,
                                const int skipped,
                                const int failed,
                                const bool incomplete)
{
   const string fields =
      "{" +
      "\"eligible\":" + IntegerToString(eligible) +
      ",\"shifted\":" + IntegerToString(shifted) +
      ",\"clamped\":" + IntegerToString(clamped) +
      ",\"skipped\":" + IntegerToString(skipped) +
      ",\"failed\":" + IntegerToString(failed) +
      ",\"incomplete\":" + Grind_ArchiveJsonBool(incomplete) +
      "}";
   const string code = incomplete ? "CARRY_PASS_INCOMPLETE" : "CARRY_PASS_SUMMARY";
   Grind_ArchiveMarker("INFO", code, symbol, 0, fields);
}

//+------------------------------------------------------------------+
void Grind_CarryExitPassReset(const bool full_reset = true)
{
   g_grind_carry_exit_pass_active = false;
   if(full_reset)
      g_grind_carry_exit_snapshot_emitted = false;
   g_grind_carry_exit_work_count = 0;
   g_grind_carry_exit_work_cursor = 0;
   g_grind_carry_exit_shifted = 0;
   g_grind_carry_exit_clamped = 0;
   g_grind_carry_exit_skipped = 0;
   g_grind_carry_exit_failed = 0;
   g_grind_carry_exit_work_done = 0;
   g_grind_carry_exit_eligible = 0;
   ArrayResize(g_grind_carry_exit_retry_tickets, 0);
   ArrayResize(g_grind_carry_exit_retry_attempts, 0);
   g_grind_carry_exit_retry_count = 0;
   ArrayResize(g_grind_carry_exit_work_pos, 0);
   ArrayResize(g_grind_carry_exit_work_exit, 0);
   ArrayResize(g_grind_carry_exit_work_entry, 0);
   ArrayResize(g_grind_carry_exit_work_formula, 0);
   ArrayResize(g_grind_carry_exit_work_long, 0);
   ArrayResize(g_grind_carry_exit_work_layer, 0);
}

//+------------------------------------------------------------------+
void Grind_CarryExitPassAppendWork(const ulong position_ticket,
                                   const ulong exit_order_ticket,
                                   const double entry_price,
                                   const double formula_exit,
                                   const bool is_long,
                                   const int layer_index)
{
   const int n = g_grind_carry_exit_work_count;
   ArrayResize(g_grind_carry_exit_work_pos, n + 1);
   ArrayResize(g_grind_carry_exit_work_exit, n + 1);
   ArrayResize(g_grind_carry_exit_work_entry, n + 1);
   ArrayResize(g_grind_carry_exit_work_formula, n + 1);
   ArrayResize(g_grind_carry_exit_work_long, n + 1);
   ArrayResize(g_grind_carry_exit_work_layer, n + 1);
   g_grind_carry_exit_work_pos[n] = position_ticket;
   g_grind_carry_exit_work_exit[n] = exit_order_ticket;
   g_grind_carry_exit_work_entry[n] = entry_price;
   g_grind_carry_exit_work_formula[n] = formula_exit;
   g_grind_carry_exit_work_long[n] = is_long;
   g_grind_carry_exit_work_layer[n] = layer_index;
   g_grind_carry_exit_work_count = n + 1;
}

//+------------------------------------------------------------------+
void Grind_CarryExitPassBegin(const string symbol,
                              const ulong magic,
                              const double exit_pips)
{
   g_grind_carry_exit_pass_active = true;
   g_grind_carry_exit_work_count = 0;
   g_grind_carry_exit_work_cursor = 0;
   g_grind_carry_exit_shifted = 0;
   g_grind_carry_exit_clamped = 0;
   g_grind_carry_exit_skipped = 0;
   g_grind_carry_exit_failed = 0;
   g_grind_carry_exit_work_done = 0;
   g_grind_carry_eligible_magic = magic;
   const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   for(int i = 0; i < ArraySize(g_grind_long.layers); i++) {
      const GrindLayer layer = g_grind_long.layers[i];
      if(layer.position_ticket == 0)
         continue;
      const double formula = Grind_ExitPrice(layer.entry_price, exit_pips, point, 1)
                             + Grind_EjectOffsetGet(layer.position_ticket);
      Grind_CarryExitPassAppendWork(layer.position_ticket, layer.exit_order_ticket,
                                    layer.entry_price, formula, true, layer.layer_index);
   }
   for(int i = 0; i < ArraySize(g_grind_short.layers); i++) {
      const GrindLayer layer = g_grind_short.layers[i];
      if(layer.position_ticket == 0)
         continue;
      const double formula = Grind_ExitPrice(layer.entry_price, exit_pips, point, -1)
                             + Grind_EjectOffsetGet(layer.position_ticket);
      Grind_CarryExitPassAppendWork(layer.position_ticket, layer.exit_order_ticket,
                                    layer.entry_price, formula, false, layer.layer_index);
   }
   g_grind_carry_exit_eligible = g_grind_carry_exit_work_count;
   Grind_CarryPruneShiftGvs(magic);
}

//+------------------------------------------------------------------+
void Grind_CarryPruneShiftGvs(const ulong magic)
{
   for(int g = GlobalVariablesTotal() - 1; g >= 0; g--) {
      const string name = GlobalVariableName(g);
      ulong ticket = 0;
      if(StringFind(name, "GRIND_CARRY_SHIFT_") == 0) {
         const string suffix = StringSubstr(name, StringLen("GRIND_CARRY_SHIFT_"));
         ticket = (ulong)StringToInteger(suffix);
      } else if(StringFind(name, GRIND_CARRY_RELEASE_PREFIX) == 0) {
         const string suffix = StringSubstr(name, StringLen(GRIND_CARRY_RELEASE_PREFIX));
         ticket = (ulong)StringToInteger(suffix);
      } else if(StringFind(name, "GRIND_EJECT_OFFSET_") == 0) {
         const string suffix = StringSubstr(name, StringLen("GRIND_EJECT_OFFSET_"));
         ticket = (ulong)StringToInteger(suffix);
      } else {
         continue;
      }
      if(ticket == 0)
         continue;
      const bool exists = Grind_OrderTestActive()
                          ? Grind_PositionTestExistsAnyMagic(ticket)
                          : PositionSelectByTicket(ticket);
      if(!exists)
         GlobalVariableDel(name);
   }
}

//+------------------------------------------------------------------+
bool Grind_CarryExitShiftLayer(const ulong position_ticket,
                               const ulong exit_order_ticket,
                               const double entry_price,
                               const double formula_exit,
                               const bool is_long,
                               const int layer_index,
                               const ulong magic,
                               const string symbol,
                               const double exit_pips,
                               bool &clamped_out,
                               bool &sign_guard_skipped_out,
                               uint &retcode_out)
{
   clamped_out = false;
   sign_guard_skipped_out = false;
   retcode_out = 0;

   double swap = 0.0;
   double volume = 0.0;
   datetime open_time = 0;
   if(!Grind_CarryPositionSwapVolume(position_ticket, magic, swap, volume, open_time))
      return false;

   const int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   const double pip_size = Grind_CarryPipSize(digits, point);
   const double tick_value = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   const double tick_size = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   const double swap_points = is_long
      ? SymbolInfoDouble(symbol, SYMBOL_SWAP_LONG)
      : SymbolInfoDouble(symbol, SYMBOL_SWAP_SHORT);

   MqlDateTime dt;
   TimeToStruct(Grind_CarryServerTime(), dt);
   const int mult_tomorrow = Grind_CarrySwapMultiplier((dt.day_of_week + 1) % 7);

   double ledger_pips = 0.0;
   if(!Grind_CarryLedgerToPips(swap, volume, tick_value, tick_size, pip_size, ledger_pips)) {
      g_grind_carry_exit_skipped++;
      return false;
   }
   const double pending_pips = Grind_CarryPendingPips(swap_points, mult_tomorrow, digits);
   const double accrued_pips = ledger_pips + pending_pips;
   const int direction = is_long ? 1 : -1;
   const double theoretical = Grind_CarryShiftedExitPrice(formula_exit, direction,
                                                        accrued_pips, pip_size);
   const double accrued_price = theoretical - formula_exit;

   if(exit_order_ticket == 0) {
      if(Grind_CarryShouldCommitAccrual(false, false, true))
         Grind_CarryAccruedSet(position_ticket, accrued_price);
      return true;
   }

   if(Grind_CarrySignGuardAppliesAtShift(position_ticket, entry_price, theoretical, is_long)) {
      sign_guard_skipped_out = true;
      g_grind_carry_exit_skipped++;
      Grind_CarryEmitExitShiftEvent(symbol, position_ticket, is_long ? "long" : "short",
                                   layer_index, ledger_pips, pending_pips, accrued_pips,
                                   formula_exit, formula_exit, false, true, 0,
                                   Grind_CarryPointsNativePips(swap_points,
                                      Grind_CarryRolloversCrossed(open_time, Grind_CarryServerTime()),
                                      digits));
      return false;
   }

   double bid = g_grind_carry_test_tick_active
      ? g_grind_carry_test_tick_bid
      : SymbolInfoDouble(symbol, SYMBOL_BID);
   double ask = g_grind_carry_test_tick_active
      ? g_grind_carry_test_tick_ask
      : SymbolInfoDouble(symbol, SYMBOL_ASK);
   long stops = (long)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
   long freeze = (long)SymbolInfoInteger(symbol, SYMBOL_TRADE_FREEZE_LEVEL);

   double new_exit = theoretical;
   if(is_long)
      clamped_out = Grind_CarryClampLongExit(theoretical, bid, ask, point, stops, freeze, new_exit);
   else
      clamped_out = Grind_CarryClampShortExit(theoretical, bid, ask, point, stops, freeze, new_exit);

   const double old_price = Grind_OrderGetPriceOpen(exit_order_ticket);
   if(!Grind_ModifyPendingPrice(exit_order_ticket, new_exit, magic)) {
      g_grind_carry_exit_failed++;
      retcode_out = g_grind_order_test_active ? g_grind_order_test_send_retcode : 0;
      return false;
   }

   if(Grind_CarryShouldCommitAccrual(true, false, true))
      Grind_CarryAccruedSet(position_ticket, accrued_price);

   const double intended = formula_exit + accrued_price;
   const double applied_shift = Grind_Normalize(new_exit) - intended;
   Grind_CarryShiftSet(position_ticket, applied_shift);
   if(clamped_out)
      g_grind_carry_exit_clamped++;
   g_grind_carry_exit_shifted++;
   retcode_out = TRADE_RETCODE_DONE;
   Grind_CarryEmitExitShiftEvent(symbol, position_ticket, is_long ? "long" : "short",
                                 layer_index, ledger_pips, pending_pips, accrued_pips,
                                 old_price > 0.0 ? old_price : formula_exit, new_exit,
                                 clamped_out, false, retcode_out,
                                 Grind_CarryPointsNativePips(swap_points,
                                    Grind_CarryRolloversCrossed(open_time, Grind_CarryServerTime()),
                                    digits));
   return true;
}

//+------------------------------------------------------------------+
void Grind_CarryOnTimerStep(const string symbol,
                            const ulong magic,
                            const double exit_pips,
                            const bool enable_carry_pass,
                            const datetime carry_now)
{
   if(Grind_CarryGateDue(magic, carry_now)) {
      if(!g_grind_carry_exit_snapshot_emitted) {
         Grind_CarryEmitSnapshot(symbol, magic);
         g_grind_carry_exit_snapshot_emitted = true;
      }
   }
   if(enable_carry_pass)
      Grind_CarryExitPassStep(symbol, magic, exit_pips, carry_now);
}

//+------------------------------------------------------------------+
int Grind_CarryExitPassStep(const string symbol,
                            const ulong magic,
                            const double exit_pips,
                            const datetime now)
{
   if(!Grind_CarryGateInWindow(now)) {
      if(g_grind_carry_exit_pass_active)
         Grind_CarryExitPassOnWindowClose(symbol, magic, now);
      return 0;
   }

   if(Grind_CarryGateDue(magic, now) && !g_grind_carry_exit_pass_active)
      Grind_CarryExitPassBegin(symbol, magic, exit_pips);

   if(!g_grind_carry_exit_pass_active)
      return 0;
   if(!Grind_CarrySessionReady(symbol))
      return 0;

   int processed = 0;
   while(processed < GRIND_CARRY_PASS_CHUNK
         && g_grind_carry_exit_work_cursor < g_grind_carry_exit_work_count) {
      const int idx = g_grind_carry_exit_work_cursor;
      g_grind_carry_exit_work_cursor++;
      bool clamped = false;
      bool sign_skip = false;
      uint retcode = 0;
      if(Grind_CarryExitShiftLayer(g_grind_carry_exit_work_pos[idx],
                                   g_grind_carry_exit_work_exit[idx],
                                   g_grind_carry_exit_work_entry[idx],
                                   g_grind_carry_exit_work_formula[idx],
                                   g_grind_carry_exit_work_long[idx],
                                   g_grind_carry_exit_work_layer[idx],
                                   magic, symbol, exit_pips,
                                   clamped, sign_skip, retcode))
         g_grind_carry_exit_work_done++;
      processed++;
   }

   if(g_grind_carry_exit_work_cursor >= g_grind_carry_exit_work_count
      && g_grind_carry_exit_retry_count == 0) {
      Grind_CarryEmitPassSummary(symbol, g_grind_carry_exit_eligible,
                                 g_grind_carry_exit_shifted, g_grind_carry_exit_clamped,
                                 g_grind_carry_exit_skipped, g_grind_carry_exit_failed, false);
      Grind_CarryGateMarkDone(magic, now);
      Grind_CarryExitPassReset(true);
   }
   return processed;
}

//+------------------------------------------------------------------+
void Grind_CarryExitPassOnWindowClose(const string symbol,
                                      const ulong magic,
                                      const datetime now)
{
   if(!g_grind_carry_exit_pass_active)
      return;
   const bool incomplete = (g_grind_carry_exit_work_cursor < g_grind_carry_exit_work_count
                            || g_grind_carry_exit_retry_count > 0);
   if(incomplete) {
      Grind_CarryEmitPassSummary(symbol, g_grind_carry_exit_eligible,
                                 g_grind_carry_exit_shifted, g_grind_carry_exit_clamped,
                                 g_grind_carry_exit_skipped, g_grind_carry_exit_failed, true);
   }
   Grind_CarryExitPassReset(false);
}

//+------------------------------------------------------------------+
void Grind_CarryEmitSnapshot(const string symbol, const ulong magic)
{
   const datetime now = Grind_CarryServerTime();
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
   g_grind_carry_eligible_magic = magic;
   const int eligible_long = Grind_CarryOpenLayers(g_grind_long);
   const int eligible_short = Grind_CarryOpenLayers(g_grind_short);
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
