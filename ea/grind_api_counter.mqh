//+------------------------------------------------------------------+
//| grind_api_counter.mqh — daily OrderSend tally with self-verify   |
//+------------------------------------------------------------------+
#ifndef GRIND_API_COUNTER_MQH
#define GRIND_API_COUNTER_MQH

#include "grind_archive.mqh"

#define GRIND_DAILY_API_COUNT_GV "GRIND_DAILY_API_COUNT"
#define GRIND_DAILY_API_DATE_GV  "GRIND_DAILY_API_DATE"
#define GRIND_DAILY_API_LIMIT    2000
#define GRIND_DAILY_API_SOFT_WARN 1800

bool g_grind_api_counter_broken = false;
bool g_grind_api_entry_stop_warn_emitted = false;
int  g_grind_near_reserve_blocks = 0;
int  g_grind_last_guard_total = 0;
long g_grind_entry_place_latency_ms = 0;

//+------------------------------------------------------------------+
double Grind_ApiCounterTodayYmd()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   string today_str = StringFormat("%04d%02d%02d", dt.year, dt.mon, dt.day);
   return (double)StringToInteger(today_str);
}

//+------------------------------------------------------------------+
void Grind_ApiCounterMaybeReset()
{
   const double today_val = Grind_ApiCounterTodayYmd();
   const double stored = GlobalVariableCheck(GRIND_DAILY_API_DATE_GV)
                         ? GlobalVariableGet(GRIND_DAILY_API_DATE_GV)
                         : 0.0;
   if(!GlobalVariableCheck(GRIND_DAILY_API_DATE_GV) || stored != today_val) {
      GlobalVariableSet(GRIND_DAILY_API_DATE_GV, today_val);
      GlobalVariableSet(GRIND_DAILY_API_COUNT_GV, 0.0);
      g_grind_api_entry_stop_warn_emitted = false;
      g_grind_near_reserve_blocks = 0;
   }
}

//+------------------------------------------------------------------+
bool Grind_ApiCounterSelfVerify(const double before, const double after)
{
   return (after == before + 1.0);
}

//+------------------------------------------------------------------+
void Grind_ApiCounterIncrement()
{
   Grind_ApiCounterMaybeReset();
   const double before = GlobalVariableCheck(GRIND_DAILY_API_COUNT_GV)
                         ? GlobalVariableGet(GRIND_DAILY_API_COUNT_GV)
                         : 0.0;
   GlobalVariableSet(GRIND_DAILY_API_COUNT_GV, before + 1.0);
   const double after = GlobalVariableGet(GRIND_DAILY_API_COUNT_GV);
   if(!Grind_ApiCounterSelfVerify(before, after)) {
      g_grind_api_counter_broken = true;
      Print("CRITICAL: GRIND API counter self-verify failed before=", before,
            " after=", after);
   }
}

//+------------------------------------------------------------------+
int Grind_ApiCounterRead()
{
   Grind_ApiCounterMaybeReset();
   if(!GlobalVariableCheck(GRIND_DAILY_API_COUNT_GV))
      return 0;
   return (int)GlobalVariableGet(GRIND_DAILY_API_COUNT_GV);
}

//+------------------------------------------------------------------+
bool Grind_ApiCounterSoftWarnActive()
{
   return (Grind_ApiCounterRead() >= GRIND_DAILY_API_SOFT_WARN);
}

//+------------------------------------------------------------------+
bool Grind_ApiCounterEntryStopped()
{
   Grind_ApiCounterMaybeReset();
   const int count = Grind_ApiCounterRead();
   if(count < GRIND_DAILY_API_ENTRY_STOP)
      return false;
   if(!g_grind_api_entry_stop_warn_emitted) {
      g_grind_api_entry_stop_warn_emitted = true;
      Grind_ArchiveMarker("WARN", "WARN_API_ENTRY_STOP", "",
                          0,
                          StringFormat("{\"count\":%d}", count));
      Print("WARN WARN_API_ENTRY_STOP count=", count);
   }
   return true;
}

//+------------------------------------------------------------------+
bool Grind_OrderSendCounted(MqlTradeRequest &request, MqlTradeResult &result)
{
   const ulong t0 = GetTickCount64();
   const bool ok = OrderSend(request, result);
   const long duration_ms = (long)(GetTickCount64() - t0);
   Grind_ApiCounterIncrement();
   if(g_grind_archive_enabled) {
      Grind_ArchiveNoteSendResult(request, result, ok);
      const string fields = Grind_ArchiveSendLogFields(request,
                                                       result,
                                                       ok,
                                                       duration_ms,
                                                       TimeCurrent(),
                                                       g_grind_archive_magic);
      Grind_ArchiveEnqueue("send_log", fields);
   }
   return ok;
}

#endif // GRIND_API_COUNTER_MQH
