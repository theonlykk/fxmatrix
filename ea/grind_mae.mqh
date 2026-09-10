//+------------------------------------------------------------------+
//| grind_mae.mqh — account figures + intraday equity MAE for grind  |
//| One designated reporter (time-based lease); equity low persisted |
//| via GlobalVariable keyed by TimeTradeServer() day.               |
//+------------------------------------------------------------------+
#ifndef GRIND_MAE_MQH
#define GRIND_MAE_MQH

#include "grind_pnl.mqh"

#define GRIND_MAE_REPORTER_HEARTBEAT_GV "GRIND_MAE_REPORTER_HEARTBEAT"
#define GRIND_MAE_REPORTER_MAGIC_GV     "GRIND_MAE_REPORTER_MAGIC"
#define GRIND_MAE_REPORTER_CLAIM_LOCK_GV "GRIND_MAE_REPORTER_CLAIM_LOCK"
#define GRIND_MAE_ANCHOR_PFX            "GRIND_MAE_ANCHOR_"
#define GRIND_MAE_EQUITY_LOW_PFX        "GRIND_MAE_EQUITY_LOW_"
#define GRIND_MAE_DAILY_LOSS_FRAC       0.045
#define GRIND_MAE_CLAIM_MAX_RETRIES     50

string   g_grind_mae_day_key                  = "";
double   g_grind_mae_equity_low               = 0.0;
double   g_grind_mae_equity_low_dist_to_floor = 0.0;
bool     g_grind_mae_is_reporter              = false;

bool     g_grind_mae_test_active              = false;
double   g_grind_mae_test_equity              = 0.0;
double   g_grind_mae_test_balance             = 0.0;
datetime g_grind_mae_test_server_time         = 0;
bool     g_grind_mae_test_lock_held           = false;

//+------------------------------------------------------------------+
void Grind_MaeReset()
{
   g_grind_mae_day_key = "";
   g_grind_mae_equity_low = 0.0;
   g_grind_mae_equity_low_dist_to_floor = 0.0;
   g_grind_mae_is_reporter = false;
   g_grind_mae_test_active = false;
   g_grind_mae_test_equity = 0.0;
   g_grind_mae_test_balance = 0.0;
   g_grind_mae_test_server_time = 0;
   g_grind_mae_test_lock_held = false;
}

//+------------------------------------------------------------------+
datetime Grind_MaeReadNow()
{
   if(g_grind_mae_test_active && g_grind_mae_test_server_time > 0)
      return g_grind_mae_test_server_time;
   return Grind_ReadServerTime();
}

//+------------------------------------------------------------------+
double Grind_MaeReadEquityLive()
{
   if(g_grind_mae_test_active)
      return g_grind_mae_test_equity;
   return AccountInfoDouble(ACCOUNT_EQUITY);
}

//+------------------------------------------------------------------+
double Grind_MaeReadBalanceLive()
{
   if(g_grind_mae_test_active)
      return g_grind_mae_test_balance;
   return AccountInfoDouble(ACCOUNT_BALANCE);
}

//+------------------------------------------------------------------+
string Grind_MaeAnchorGvKey(const string day_key)
{
   return GRIND_MAE_ANCHOR_PFX + day_key;
}

//+------------------------------------------------------------------+
string Grind_MaeEquityLowGvKey(const string day_key)
{
   return GRIND_MAE_EQUITY_LOW_PFX + day_key;
}

//+------------------------------------------------------------------+
double Grind_MaeDailyFloorValue(const double daily_anchor, const double daily_frac)
{
   if(daily_anchor <= 0.0 || daily_frac < 0.0)
      return 0.0;
   return daily_anchor * (1.0 - daily_frac);
}

//+------------------------------------------------------------------+
double Grind_MaeDistToFloor(const double equity_low,
                            const double daily_anchor,
                            const double daily_frac)
{
   return equity_low - Grind_MaeDailyFloorValue(daily_anchor, daily_frac);
}

//+------------------------------------------------------------------+
bool Grind_MaeAnchorGvPresent(const string day_key)
{
   return GlobalVariableCheck(Grind_MaeAnchorGvKey(day_key));
}

//+------------------------------------------------------------------+
double Grind_MaeReadDailyAnchorGv(const string day_key)
{
   const string key = Grind_MaeAnchorGvKey(day_key);
   if(!GlobalVariableCheck(key))
      return 0.0;
   return GlobalVariableGet(key);
}

//+------------------------------------------------------------------+
void Grind_MaeWriteDailyAnchorGv(const string day_key, const double balance)
{
   GlobalVariableSet(Grind_MaeAnchorGvKey(day_key), balance);
}

//+------------------------------------------------------------------+
double Grind_MaeEnsureDailyAnchor(const string day_key, const double balance_now)
{
   if(Grind_MaeAnchorGvPresent(day_key))
      return Grind_MaeReadDailyAnchorGv(day_key);
   Grind_MaeWriteDailyAnchorGv(day_key, balance_now);
   return balance_now;
}

//+------------------------------------------------------------------+
bool Grind_MaeEquityLowGvPresent(const string day_key)
{
   return GlobalVariableCheck(Grind_MaeEquityLowGvKey(day_key));
}

//+------------------------------------------------------------------+
double Grind_MaeReadEquityLowGv(const string day_key)
{
   const string key = Grind_MaeEquityLowGvKey(day_key);
   if(!GlobalVariableCheck(key))
      return -1.0;
   return GlobalVariableGet(key);
}

//+------------------------------------------------------------------+
void Grind_MaeWriteEquityLowGv(const string day_key, const double equity_low)
{
   GlobalVariableSet(Grind_MaeEquityLowGvKey(day_key), equity_low);
}

//+------------------------------------------------------------------+
void Grind_MaeRefreshDistToFloor(const string day_key)
{
   const double daily_anchor = Grind_MaeEnsureDailyAnchor(day_key,
                                                          Grind_MaeReadBalanceLive());
   g_grind_mae_equity_low_dist_to_floor = Grind_MaeDistToFloor(
      g_grind_mae_equity_low, daily_anchor, GRIND_MAE_DAILY_LOSS_FRAC);
}

//+------------------------------------------------------------------+
void Grind_MaeSeedCurrentDay(const string day_key,
                             const double equity,
                             const double balance)
{
   g_grind_mae_day_key = day_key;
   const double daily_anchor = Grind_MaeEnsureDailyAnchor(day_key, balance);
   g_grind_mae_equity_low = equity;
   g_grind_mae_equity_low_dist_to_floor = Grind_MaeDistToFloor(
      equity, daily_anchor, GRIND_MAE_DAILY_LOSS_FRAC);
   Grind_MaeWriteEquityLowGv(day_key, g_grind_mae_equity_low);
}

//+------------------------------------------------------------------+
void Grind_MaeCoreUpdate(const string day_key,
                         const double equity,
                         const double balance)
{
   if(g_grind_mae_day_key == "" || day_key != g_grind_mae_day_key) {
      Grind_MaeSeedCurrentDay(day_key, equity, balance);
      return;
   }

   if(equity < g_grind_mae_equity_low) {
      g_grind_mae_equity_low = equity;
      Grind_MaeRefreshDistToFloor(day_key);
      Grind_MaeWriteEquityLowGv(day_key, g_grind_mae_equity_low);
   }
}

//+------------------------------------------------------------------+
void Grind_MaeInit()
{
   const string day_key = Grind_ServerDayKey(Grind_MaeReadNow());
   const double balance = Grind_MaeReadBalanceLive();
   const double equity = Grind_MaeReadEquityLive();
   g_grind_mae_day_key = day_key;

   const double loaded_low = Grind_MaeReadEquityLowGv(day_key);
   if(loaded_low >= 0.0) {
      g_grind_mae_equity_low = loaded_low;
      Grind_MaeRefreshDistToFloor(day_key);
   } else {
      Grind_MaeSeedCurrentDay(day_key, equity, balance);
   }
}

//+------------------------------------------------------------------+
void Grind_MaeOnTimer()
{
   const string day_key = Grind_ServerDayKey(Grind_MaeReadNow());
   const double balance = Grind_MaeReadBalanceLive();
   const double equity = Grind_MaeReadEquityLive();
   Grind_MaeCoreUpdate(day_key, equity, balance);
}

//+------------------------------------------------------------------+
bool Grind_MaeTryAcquireClaimLock(const int max_retries)
{
   GlobalVariableTemp(GRIND_MAE_REPORTER_CLAIM_LOCK_GV);
   int retries = 0;
   while(!GlobalVariableSetOnCondition(GRIND_MAE_REPORTER_CLAIM_LOCK_GV, 1.0, 0.0)) {
      if(g_grind_mae_test_lock_held) {
         Sleep(1);
         if(++retries > max_retries) {
            Print("ERROR: MAE reporter claim lock timeout ", GRIND_MAE_REPORTER_CLAIM_LOCK_GV);
            return false;
         }
         continue;
      }
      Sleep(1);
      if(++retries > max_retries) {
         Print("ERROR: MAE reporter claim lock timeout ", GRIND_MAE_REPORTER_CLAIM_LOCK_GV);
         return false;
      }
   }
   return true;
}

//+------------------------------------------------------------------+
void Grind_MaeReleaseClaimLock()
{
   GlobalVariableSet(GRIND_MAE_REPORTER_CLAIM_LOCK_GV, 0.0);
}

//+------------------------------------------------------------------+
bool Grind_MaeLeaseIsStale(const datetime now,
                           const double lease_time,
                           const int telemetry_interval_sec)
{
   if(lease_time <= 0.0)
      return true;
   const double stale_sec = telemetry_interval_sec * 1.5;
   return ((double)(now - (datetime)lease_time) > stale_sec);
}

//+------------------------------------------------------------------+
bool Grind_MaeClaimReporterForHeartbeat(const ulong magic,
                                        const int telemetry_interval_sec)
{
   GlobalVariableTemp(GRIND_MAE_REPORTER_HEARTBEAT_GV);
   GlobalVariableTemp(GRIND_MAE_REPORTER_MAGIC_GV);

   const datetime now = Grind_MaeReadNow();
   const double lease_time = GlobalVariableGet(GRIND_MAE_REPORTER_HEARTBEAT_GV);
   const ulong holder = (ulong)GlobalVariableGet(GRIND_MAE_REPORTER_MAGIC_GV);
   const bool stale = Grind_MaeLeaseIsStale(now, lease_time, telemetry_interval_sec);

   if(!stale && holder == magic) {
      GlobalVariableSet(GRIND_MAE_REPORTER_HEARTBEAT_GV, (double)now);
      g_grind_mae_is_reporter = true;
      return true;
   }

   if(!stale) {
      g_grind_mae_is_reporter = false;
      return false;
   }

   if(!Grind_MaeTryAcquireClaimLock(GRIND_MAE_CLAIM_MAX_RETRIES)) {
      g_grind_mae_is_reporter = false;
      return false;
   }

   const double lease_time2 = GlobalVariableGet(GRIND_MAE_REPORTER_HEARTBEAT_GV);
   const ulong holder2 = (ulong)GlobalVariableGet(GRIND_MAE_REPORTER_MAGIC_GV);
   const bool stale2 = Grind_MaeLeaseIsStale(now, lease_time2, telemetry_interval_sec);

   if(stale2 || holder2 == magic) {
      GlobalVariableSet(GRIND_MAE_REPORTER_HEARTBEAT_GV, (double)now);
      GlobalVariableSet(GRIND_MAE_REPORTER_MAGIC_GV, (double)magic);
      Grind_MaeReleaseClaimLock();
      g_grind_mae_is_reporter = true;
      return true;
   }

   Grind_MaeReleaseClaimLock();
   g_grind_mae_is_reporter = (holder2 == magic);
   return g_grind_mae_is_reporter;
}

//+------------------------------------------------------------------+
string Grind_MaeJsonDoubleOrNull(const double value, const bool emit)
{
   if(!emit)
      return "null";
   return DoubleToString(value, 2);
}

//+------------------------------------------------------------------+
string Grind_MaeJsonStringOrNull(const string value, const bool emit)
{
   if(!emit)
      return "null";
   return "\"" + value + "\"";
}

//+------------------------------------------------------------------+
string Grind_MaeAccountBalanceJson()
{
   if(!g_grind_mae_is_reporter)
      return "null";
   return Grind_MaeJsonDoubleOrNull(Grind_MaeReadBalanceLive(), true);
}

//+------------------------------------------------------------------+
string Grind_MaeAccountEquityJson()
{
   if(!g_grind_mae_is_reporter)
      return "null";
   return Grind_MaeJsonDoubleOrNull(Grind_MaeReadEquityLive(), true);
}

//+------------------------------------------------------------------+
string Grind_MaeIntradayMaeJson(const string instance_name)
{
   if(!g_grind_mae_is_reporter) {
      return "{\"mae_day_key\":null,\"mae_equity_low\":null,"
             "\"mae_equity_low_dist_to_floor\":null,\"source_instance\":null}";
   }

   return StringFormat(
      "{\"mae_day_key\":\"%s\",\"mae_equity_low\":%s,"
      "\"mae_equity_low_dist_to_floor\":%s,\"source_instance\":\"%s\"}",
      g_grind_mae_day_key,
      DoubleToString(g_grind_mae_equity_low, 2),
      DoubleToString(g_grind_mae_equity_low_dist_to_floor, 2),
      instance_name);
}

#endif // GRIND_MAE_MQH
