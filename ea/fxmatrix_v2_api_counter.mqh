//+------------------------------------------------------------------+
//| fxmatrix_v2_api_counter.mqh — account-wide daily OrderSend tally |
//| Shared MT5 Global Variables across all V2 instances (6 charts).   |
//| Counts every OrderSend() invocation (placement, cancel, CloseBy). |
//|                                                                   |
//| RESET BOUNDARY (documented uncertainty):                          |
//| - FTMO FAQ confirms ~2,000 server requests/day (opens/modifies/   |
//|   closes) but does NOT publish when that counter resets.          |
//| - FTMO daily *loss* rules reset at 00:00 CE(S)T (official); they  |
//|   note platform/server clock may differ from CE(S)T.                |
//| - This project (V1 ADR-017, FXMatrix.mq5) has always reset its    |
//|   internal counter at broker server midnight via TimeCurrent().   |
//| - We keep that convention here for parity with V1 and because the |
//|   counter tracks broker-side OrderSend volume in terminal time.    |
//| - CANNOT confirm from available sources that FTMO's enforcement   |
//|   boundary matches broker midnight vs CE(S)T midnight.            |
//+------------------------------------------------------------------+
#ifndef FXMATRIX_V2_API_COUNTER_MQH
#define FXMATRIX_V2_API_COUNTER_MQH

#define V2_DAILY_API_COUNT_GV "V2_DAILY_API_COUNT"
#define V2_DAILY_API_DATE_GV  "V2_DAILY_API_DATE"
#define V2_DAILY_API_LIMIT       2000
#define V2_DAILY_API_SOFT_WARN   1800   // ADR-021 combined ceiling (900 x 2 instances)

//+------------------------------------------------------------------+
double V2_ApiCounterTodayYmd()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   string today_str = StringFormat("%04d%02d%02d", dt.year, dt.mon, dt.day);
   return (double)StringToInteger(today_str);
}

//+------------------------------------------------------------------+
void V2_ApiCounterMaybeReset()
{
   double today_val = V2_ApiCounterTodayYmd();
   double stored = GlobalVariableCheck(V2_DAILY_API_DATE_GV)
                   ? GlobalVariableGet(V2_DAILY_API_DATE_GV)
                   : 0.0;

   if(!GlobalVariableCheck(V2_DAILY_API_DATE_GV) || stored != today_val) {
      GlobalVariableSet(V2_DAILY_API_DATE_GV, today_val);
      GlobalVariableSet(V2_DAILY_API_COUNT_GV, 0.0);
      Print("INFO: V2 account daily API counter reset. broker_date=",
            (long)today_val);
   }
}

//+------------------------------------------------------------------+
void V2_ApiCounterIncrement()
{
   V2_ApiCounterMaybeReset();
   double n = GlobalVariableCheck(V2_DAILY_API_COUNT_GV)
              ? GlobalVariableGet(V2_DAILY_API_COUNT_GV)
              : 0.0;
   GlobalVariableSet(V2_DAILY_API_COUNT_GV, n + 1.0);
}

//+------------------------------------------------------------------+
int V2_ApiCounterRead()
{
   V2_ApiCounterMaybeReset();
   if(!GlobalVariableCheck(V2_DAILY_API_COUNT_GV))
      return 0;
   return (int)GlobalVariableGet(V2_DAILY_API_COUNT_GV);
}

//+------------------------------------------------------------------+
bool V2_ApiCounterSoftWarnActive()
{
   return (V2_ApiCounterRead() >= V2_DAILY_API_SOFT_WARN);
}

//+------------------------------------------------------------------+
bool V2_OrderSendCounted(MqlTradeRequest &request, MqlTradeResult &result)
{
   bool ok = OrderSend(request, result);
   V2_ApiCounterIncrement();
   return ok;
}

#endif // FXMATRIX_V2_API_COUNTER_MQH
