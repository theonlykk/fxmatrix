//+------------------------------------------------------------------+
//| grind_api_counter.mqh — daily OrderSend tally with self-verify   |
//+------------------------------------------------------------------+
#ifndef GRIND_API_COUNTER_MQH
#define GRIND_API_COUNTER_MQH

#define GRIND_DAILY_API_COUNT_GV "GRIND_DAILY_API_COUNT"
#define GRIND_DAILY_API_DATE_GV  "GRIND_DAILY_API_DATE"
#define GRIND_DAILY_API_LIMIT    2000
#define GRIND_DAILY_API_SOFT_WARN 1800

bool g_grind_api_counter_broken = false;

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
bool Grind_OrderSendCounted(MqlTradeRequest &request, MqlTradeResult &result)
{
   const bool ok = OrderSend(request, result);
   Grind_ApiCounterIncrement();
   return ok;
}

#endif // GRIND_API_COUNTER_MQH
