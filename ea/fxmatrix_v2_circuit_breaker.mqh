//+------------------------------------------------------------------+
//| fxmatrix_v2_circuit_breaker.mqh — account-wide equity-floor CB   |
//| Trigger B (Gemini V2 Operational Circuit Breaker): PAUSE-AND-HOLD|
//| only — never close, sweep, cancel, or flatten. Resume is MANUAL: |
//| operator clears GlobalVariableDel("V2CB_ACCT_HALT") after restart|
//| and state cleanup. No auto-resume anywhere in this module.       |
//+------------------------------------------------------------------+
#ifndef FXMATRIX_V2_CIRCUIT_BREAKER_MQH
#define FXMATRIX_V2_CIRCUIT_BREAKER_MQH

#define V2_CB_GV_HALT      "V2CB_ACCT_HALT"
#define V2_CB_GV_INIT_BAL   "V2CB_INIT_BAL"
#define V2_CB_GV_ANCHOR_PFX "V2CB_ANCHOR_"

//+------------------------------------------------------------------+
//| Unit-test hooks (no broker / GV side effects when active).       |
//+------------------------------------------------------------------+
bool   g_v2_cb_test_active = false;
bool   g_v2_cb_test_gv_halt = false;
bool   g_v2_cb_test_gv_halt_known = false;
double g_v2_cb_test_gv_init_bal = 0.0;
bool   g_v2_cb_test_gv_init_bal_known = false;
string g_v2_cb_test_anchor_day_key = "";
double g_v2_cb_test_anchor_val = 0.0;
bool   g_v2_cb_test_anchor_known = false;
double g_v2_cb_test_equity = 0.0;
double g_v2_cb_test_balance = 0.0;

void V2_Cb_TestReset()
{
   g_v2_cb_test_active = false;
   g_v2_cb_test_gv_halt = false;
   g_v2_cb_test_gv_halt_known = false;
   g_v2_cb_test_gv_init_bal = 0.0;
   g_v2_cb_test_gv_init_bal_known = false;
   g_v2_cb_test_anchor_day_key = "";
   g_v2_cb_test_anchor_val = 0.0;
   g_v2_cb_test_anchor_known = false;
   g_v2_cb_test_equity = 0.0;
   g_v2_cb_test_balance = 0.0;
}

//+------------------------------------------------------------------+
bool V2_CbDailyFloorBreached(const double equity,
                             const double daily_open_bal,
                             const double daily_frac)
{
   if(daily_open_bal <= 0.0 || daily_frac < 0.0)
      return false;
   const double floor = daily_open_bal * (1.0 - daily_frac);
   return equity < floor;
}

bool V2_CbAbsoluteFloorBreached(const double equity,
                                const double initial_bal,
                                const double absolute_frac)
{
   if(initial_bal <= 0.0 || absolute_frac < 0.0)
      return false;
   const double floor = initial_bal * (1.0 - absolute_frac);
   return equity < floor;
}

double V2_CbResolveDailyAnchor(const bool gv_present,
                               const double gv_anchor,
                               const double balance_if_absent)
{
   if(gv_present)
      return gv_anchor;
   return balance_if_absent;
}

bool V2_CbShouldHaltFromFloors(const bool enabled,
                               const bool daily_breach,
                               const bool absolute_breach)
{
   if(!enabled)
      return false;
   return daily_breach || absolute_breach;
}

void V2_CbHonorPeerHalt(const bool acct_halt_gv,
                        bool &long_halted,
                        bool &short_halted)
{
   if(acct_halt_gv) {
      long_halted = true;
      short_halted = true;
   }
}

//+------------------------------------------------------------------+
datetime V2_CbLastSundayUtc(const int year, const int month, const int hour_utc)
{
   for(int day = 31; day >= 1; day--) {
      MqlDateTime probe;
      probe.year = year;
      probe.mon = month;
      probe.day = day;
      probe.hour = 12;
      probe.min = 0;
      probe.sec = 0;
      const datetime candidate = StructToTime(probe);
      if(candidate <= 0)
         continue;
      MqlDateTime dt;
      TimeToStruct(candidate, dt);
      if(dt.day != day)
         continue;
      if(dt.day_of_week != 0)
         continue;
      dt.hour = hour_utc;
      dt.min = 0;
      dt.sec = 0;
      return StructToTime(dt);
   }
   return 0;
}

bool V2_CbUtcInCestPeriod(const datetime utc_gmt)
{
   MqlDateTime dt;
   TimeToStruct(utc_gmt, dt);
   const int year = dt.year;
   const datetime spring = V2_CbLastSundayUtc(year, 3, 1);
   const datetime autumn = V2_CbLastSundayUtc(year, 10, 1);
   if(spring <= 0 || autumn <= 0)
      return false;
   return (utc_gmt >= spring && utc_gmt < autumn);
}

int V2_CbCestOffsetSeconds(const datetime utc_gmt)
{
   return V2_CbUtcInCestPeriod(utc_gmt) ? 2 * 3600 : 3600;
}

string V2_CbCestDayKey(const datetime utc_gmt)
{
   const datetime local = utc_gmt + V2_CbCestOffsetSeconds(utc_gmt);
   MqlDateTime dt;
   TimeToStruct(local, dt);
   return StringFormat("%04d%02d%02d", dt.year, dt.mon, dt.day);
}

string V2_CbDailyAnchorGvKey(const string day_key)
{
   return V2_CB_GV_ANCHOR_PFX + day_key;
}

//+------------------------------------------------------------------+
bool V2_CbReadAcctHaltGv()
{
   if(g_v2_cb_test_active) {
      if(!g_v2_cb_test_gv_halt_known)
         return false;
      return g_v2_cb_test_gv_halt;
   }
   if(!GlobalVariableCheck(V2_CB_GV_HALT))
      return false;
   return GlobalVariableGet(V2_CB_GV_HALT) >= 0.5;
}

void V2_CbPublishAcctHaltGv()
{
   if(g_v2_cb_test_active) {
      g_v2_cb_test_gv_halt = true;
      g_v2_cb_test_gv_halt_known = true;
      return;
   }
   GlobalVariableSet(V2_CB_GV_HALT, 1.0);
}

double V2_CbReadInitialBalanceGv()
{
   if(g_v2_cb_test_active) {
      if(!g_v2_cb_test_gv_init_bal_known)
         return 0.0;
      return g_v2_cb_test_gv_init_bal;
   }
   if(!GlobalVariableCheck(V2_CB_GV_INIT_BAL))
      return 0.0;
   return GlobalVariableGet(V2_CB_GV_INIT_BAL);
}

void V2_CbWriteInitialBalanceGv(const double bal)
{
   if(g_v2_cb_test_active) {
      g_v2_cb_test_gv_init_bal = bal;
      g_v2_cb_test_gv_init_bal_known = true;
      return;
   }
   GlobalVariableSet(V2_CB_GV_INIT_BAL, bal);
}

bool V2_CbDailyAnchorGvPresent(const string day_key)
{
   const string key = V2_CbDailyAnchorGvKey(day_key);
   if(g_v2_cb_test_active)
      return (g_v2_cb_test_anchor_known && g_v2_cb_test_anchor_day_key == day_key);
   return GlobalVariableCheck(key);
}

double V2_CbReadDailyAnchorGv(const string day_key)
{
   const string key = V2_CbDailyAnchorGvKey(day_key);
   if(g_v2_cb_test_active) {
      if(g_v2_cb_test_anchor_known && g_v2_cb_test_anchor_day_key == day_key)
         return g_v2_cb_test_anchor_val;
      return 0.0;
   }
   if(!GlobalVariableCheck(key))
      return 0.0;
   return GlobalVariableGet(key);
}

void V2_CbWriteDailyAnchorGv(const string day_key, const double bal)
{
   if(g_v2_cb_test_active) {
      g_v2_cb_test_anchor_day_key = day_key;
      g_v2_cb_test_anchor_val = bal;
      g_v2_cb_test_anchor_known = true;
      return;
   }
   GlobalVariableSet(V2_CbDailyAnchorGvKey(day_key), bal);
}

double V2_CbEnsureDailyAnchor(const string day_key, const double balance_now)
{
   if(V2_CbDailyAnchorGvPresent(day_key))
      return V2_CbReadDailyAnchorGv(day_key);
   V2_CbWriteDailyAnchorGv(day_key, balance_now);
   return balance_now;
}

double V2_CbEnsureInitialBalance(const double inp_initial_balance,
                                 const double balance_now)
{
   if(inp_initial_balance > 0.0)
      return inp_initial_balance;
   if(g_v2_cb_test_active) {
      if(g_v2_cb_test_gv_init_bal_known)
         return g_v2_cb_test_gv_init_bal;
   } else if(GlobalVariableCheck(V2_CB_GV_INIT_BAL)) {
      return GlobalVariableGet(V2_CB_GV_INIT_BAL);
   }
   V2_CbWriteInitialBalanceGv(balance_now);
   return balance_now;
}

double V2_CbReadEquity()
{
   if(g_v2_cb_test_active)
      return g_v2_cb_test_equity;
   return AccountInfoDouble(ACCOUNT_EQUITY);
}

double V2_CbReadBalance()
{
   if(g_v2_cb_test_active)
      return g_v2_cb_test_balance;
   return AccountInfoDouble(ACCOUNT_BALANCE);
}

string V2_CbFormatTripAlert(const string floor_label,
                            const double equity,
                            const double floor_value)
{
   return StringFormat("CB | CRITICAL | floor=%s | equity=%.2f | limit=%.2f",
                       floor_label, equity, floor_value);
}

//+------------------------------------------------------------------+
void V2_Cb_CheckAndMaybeHalt(bool &long_halted,
                             bool &short_halted,
                             string &system_alerts[])
{
   const bool peer_halt = V2_CbReadAcctHaltGv();
   V2_CbHonorPeerHalt(peer_halt, long_halted, short_halted);

   if(!InpCbEnable)
      return;

   const datetime utc_now = TimeGMT();
   const string day_key = V2_CbCestDayKey(utc_now);
   const double balance = V2_CbReadBalance();
   const double equity = V2_CbReadEquity();

   const double daily_anchor = V2_CbEnsureDailyAnchor(day_key, balance);
   const double initial_bal = V2_CbEnsureInitialBalance(InpCbInitialBalance, balance);

   const bool daily_breach = V2_CbDailyFloorBreached(equity, daily_anchor,
                                                     InpCbDailyLossFrac);
   const bool abs_breach = V2_CbAbsoluteFloorBreached(equity, initial_bal,
                                                      InpCbAbsoluteLossFrac);

   if(!V2_CbShouldHaltFromFloors(true, daily_breach, abs_breach))
      return;

   if(!peer_halt) {
      V2_CbPublishAcctHaltGv();
      string floor_label = "daily";
      double floor_value = daily_anchor * (1.0 - InpCbDailyLossFrac);
      if(abs_breach) {
         floor_label = "absolute";
         floor_value = initial_bal * (1.0 - InpCbAbsoluteLossFrac);
      }
      const string msg = V2_CbFormatTripAlert(floor_label, equity, floor_value);
      Print("CRITICAL ", msg);
      V2_PushSystemAlert(system_alerts, msg);
   }

   long_halted = true;
   short_halted = true;
}

#endif // FXMATRIX_V2_CIRCUIT_BREAKER_MQH
