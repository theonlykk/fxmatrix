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
#define V2_INST_API_COUNT_PREFIX "V2_INST_API_"
#define V2_DAILY_API_LIMIT       2000
#define V2_DAILY_API_SOFT_WARN   1800   // ADR-021 combined ceiling (900 x 2 instances)

// Set by engine before side-local OrderSend paths (empty => skip inst tally).
extern string g_v2_inst_api_tag;

//+------------------------------------------------------------------+
string V2_InstApiCounterGvKey(const string instance_id)
{
   return V2_INST_API_COUNT_PREFIX + instance_id;
}

//+------------------------------------------------------------------+
void V2_InstApiCounterMaybeReset()
{
   if(g_v2_inst_api_tag == "")
      return;
   const string count_gv = V2_InstApiCounterGvKey(g_v2_inst_api_tag);
   const string date_gv  = count_gv + "_DATE";
   const double today_val = V2_ApiCounterTodayYmd();
   const double stored = GlobalVariableCheck(date_gv) ? GlobalVariableGet(date_gv) : 0.0;
   if(!GlobalVariableCheck(date_gv) || stored != today_val) {
      GlobalVariableSet(date_gv, today_val);
      GlobalVariableSet(count_gv, 0.0);
   }
}

//+------------------------------------------------------------------+
void V2_InstApiCounterIncrement()
{
   if(g_v2_inst_api_tag == "")
      return;
   V2_InstApiCounterMaybeReset();
   const string count_gv = V2_InstApiCounterGvKey(g_v2_inst_api_tag);
   const double n = GlobalVariableCheck(count_gv) ? GlobalVariableGet(count_gv) : 0.0;
   GlobalVariableSet(count_gv, n + 1.0);
}

//+------------------------------------------------------------------+
int V2_InstApiCounterRead(const string instance_id)
{
   if(instance_id == "")
      return 0;
   const string count_gv = V2_InstApiCounterGvKey(instance_id);
   const string date_gv  = count_gv + "_DATE";
   const double today_val = V2_ApiCounterTodayYmd();
   const double stored = GlobalVariableCheck(date_gv) ? GlobalVariableGet(date_gv) : 0.0;
   if(!GlobalVariableCheck(date_gv) || stored != today_val)
      return 0;
   if(!GlobalVariableCheck(count_gv))
      return 0;
   return (int)GlobalVariableGet(count_gv);
}

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
   V2_InstApiCounterIncrement();
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
