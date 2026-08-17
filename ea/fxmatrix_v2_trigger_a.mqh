//+------------------------------------------------------------------+
//| fxmatrix_v2_trigger_a.mqh — operational anomaly Trigger A v1      |
//| Three deterministic signals: hard-max depth, repeated same-dir    |
//| CRITICAL, position-vs-managed divergence (2-check debounce).      |
//| PAUSE-AND-HOLD only — never close, sweep, cancel, or flatten.    |
//| S2 account-wide escalation reuses V2CB_ACCT_HALT via CB module. |
//+------------------------------------------------------------------+
#ifndef FXMATRIX_V2_TRIGGER_A_MQH
#define FXMATRIX_V2_TRIGGER_A_MQH

int g_ta_long_div_streak = 0;
int g_ta_short_div_streak = 0;

bool g_v2_ta_test_active = false;
int  g_v2_ta_test_broker_long = 0;
int  g_v2_ta_test_broker_short = 0;

void V2_Ta_TestReset()
{
   g_ta_long_div_streak = 0;
   g_ta_short_div_streak = 0;
   g_v2_ta_test_active = false;
   g_v2_ta_test_broker_long = 0;
   g_v2_ta_test_broker_short = 0;
}

//+------------------------------------------------------------------+
bool V2_TaHardMaxBreached(const int depth, const int max_layers)
{
   return depth > max_layers;
}

bool V2_TaSameDirCritEscalates(const int cumulative_count)
{
   return cumulative_count >= 2;
}

int V2_TaUpdateDivergenceStreak(const bool divergent_now, const int prev_streak)
{
   if(divergent_now)
      return prev_streak + 1;
   return 0;
}

bool V2_TaDivergenceStreakHalts(const int streak)
{
   return streak >= 2;
}

bool V2_TaPositionDivergent(const int managed_depth, const int broker_count)
{
   return managed_depth != broker_count;
}

bool V2_TaShouldHaltHardMax(const bool enabled, const int depth, const int max_layers)
{
   if(!enabled)
      return false;
   return V2_TaHardMaxBreached(depth, max_layers);
}

bool V2_TaShouldHaltDivergence(const bool enabled, const int streak)
{
   if(!enabled)
      return false;
   return V2_TaDivergenceStreakHalts(streak);
}

bool V2_TaShouldEscalateSameDir(const bool enabled, const int cumulative_count)
{
   if(!enabled)
      return false;
   return V2_TaSameDirCritEscalates(cumulative_count);
}

int V2_Ta_BrokerEntryCountForSide(const bool is_long,
                                  const string symbol,
                                  const long entry_magic)
{
   if(g_v2_ta_test_active)
      return is_long ? g_v2_ta_test_broker_long : g_v2_ta_test_broker_short;
   ulong tickets[];
   return V2_ScanOpenPositionsByMagic(symbol, entry_magic, tickets);
}

void V2_Ta_CheckHardMaxSide(const string side_label,
                            const int depth,
                            const int max_layers,
                            bool &side_halted,
                            string &system_alerts[])
{
   if(side_halted)
      return;
   if(!V2_TaHardMaxBreached(depth, max_layers))
      return;

   side_halted = true;
   const string msg = StringFormat("TA | CRITICAL | signal=HARD_MAX | side=%s | depth=%d | max=%d",
                                   side_label, depth, max_layers);
   Print("CRITICAL ", msg);
   V2_PushSystemAlert(system_alerts, msg);
}

void V2_Ta_CheckSameDirEscalation(const int cumulative_count,
                                  bool &long_halted,
                                  bool &short_halted,
                                  string &system_alerts[])
{
   if(!V2_TaSameDirCritEscalates(cumulative_count))
      return;

   if(!V2_CbReadAcctHaltGv()) {
      V2_CbPublishAcctHaltGv();
      const string msg = StringFormat("TA | CRITICAL | signal=SAME_DIR_CRIT | count=%d",
                                    cumulative_count);
      Print("CRITICAL ", msg);
      V2_PushSystemAlert(system_alerts, msg);
   }

   long_halted = true;
   short_halted = true;
}

void V2_Ta_CheckDivergenceSide(const string side_label,
                               const int managed_depth,
                               const int broker_count,
                               int &div_streak,
                               bool &side_halted,
                               string &system_alerts[])
{
   const bool divergent = V2_TaPositionDivergent(managed_depth, broker_count);
   div_streak = V2_TaUpdateDivergenceStreak(divergent, div_streak);

   if(side_halted)
      return;
   if(!V2_TaDivergenceStreakHalts(div_streak))
      return;

   side_halted = true;
   const string msg = StringFormat("TA | CRITICAL | signal=DIVERGENCE | side=%s | managed=%d | broker=%d | streak=%d",
                                   side_label, managed_depth, broker_count, div_streak);
   Print("CRITICAL ", msg);
   V2_PushSystemAlert(system_alerts, msg);
}

void V2_Ta_CheckStartOfTick(bool &long_halted,
                            bool &short_halted,
                            string &system_alerts[],
                            const int long_depth,
                            const int short_depth,
                            const int max_layers,
                            const int samedir_crit_count)
{
   if(!InpTaEnable)
      return;

   V2_Ta_CheckHardMaxSide("LONG", long_depth, max_layers, long_halted, system_alerts);
   V2_Ta_CheckHardMaxSide("SHORT", short_depth, max_layers, short_halted, system_alerts);
   V2_Ta_CheckSameDirEscalation(samedir_crit_count, long_halted, short_halted, system_alerts);
}

void V2_Ta_CheckEndOfTick(bool &long_halted,
                          bool &short_halted,
                          string &system_alerts[],
                          const string symbol,
                          const long long_entry_magic,
                          const long short_entry_magic,
                          const int long_depth,
                          const int short_depth)
{
   if(!InpTaEnable)
      return;

   const int broker_long = V2_Ta_BrokerEntryCountForSide(true, symbol, long_entry_magic);
   V2_Ta_CheckDivergenceSide("LONG", long_depth, broker_long,
                               g_ta_long_div_streak, long_halted, system_alerts);

   const int broker_short = V2_Ta_BrokerEntryCountForSide(false, symbol, short_entry_magic);
   V2_Ta_CheckDivergenceSide("SHORT", short_depth, broker_short,
                             g_ta_short_div_streak, short_halted, system_alerts);
}

#endif // FXMATRIX_V2_TRIGGER_A_MQH
