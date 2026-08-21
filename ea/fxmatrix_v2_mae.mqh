//+------------------------------------------------------------------+
//| fxmatrix_v2_mae.mqh — intraday equity/MTM low-water (MAE)        |
//| Tick-level running minima since CE(S)T day boundary (CB-aligned).|
//| Local AccountInfoDouble / PositionGetDouble only — zero API cost.|
//+------------------------------------------------------------------+
#ifndef FXMATRIX_V2_MAE_MQH
#define FXMATRIX_V2_MAE_MQH

#include "fxmatrix_v2_circuit_breaker.mqh"

#define V2_MAE_PAIR_COUNT 3

// Shell input InpCbDailyLossFrac is declared by unified shells / tests (same as CB).

//+------------------------------------------------------------------+
string   g_v2_mae_day_key                  = "";
double   g_v2_mae_equity_low               = 0.0;
double   g_v2_mae_open_mtm_trough          = 0.0;
double   g_v2_mae_open_mtm_peak            = 0.0;
double   g_v2_mae_equity_low_dist_to_floor = 0.0;
double   g_v2_mae_pair_mtm_trough[V2_MAE_PAIR_COUNT];

// Unit-test injectors (no PositionsTotal / AccountInfo when active).
bool     g_v2_mae_test_active             = false;
double   g_v2_mae_test_equity             = 0.0;
double   g_v2_mae_test_balance            = 0.0;
double   g_v2_mae_test_pair_mtm[V2_MAE_PAIR_COUNT];

//+------------------------------------------------------------------+
int V2_MaePairIndex(const string symbol)
{
   if(symbol == "GBPUSD")
      return 0;
   if(symbol == "EURUSD")
      return 1;
   if(symbol == "EURGBP")
      return 2;
   return -1;
}

string V2_MaePairSymbol(const int idx)
{
   if(idx == 0)
      return "GBPUSD";
   if(idx == 1)
      return "EURUSD";
   if(idx == 2)
      return "EURGBP";
   return "";
}

//+------------------------------------------------------------------+
void V2_MaeReset()
{
   g_v2_mae_day_key = "";
   g_v2_mae_equity_low = 0.0;
   g_v2_mae_open_mtm_trough = 0.0;
   g_v2_mae_open_mtm_peak = 0.0;
   g_v2_mae_equity_low_dist_to_floor = 0.0;
   ArrayInitialize(g_v2_mae_pair_mtm_trough, 0.0);
   g_v2_mae_test_active = false;
   g_v2_mae_test_equity = 0.0;
   g_v2_mae_test_balance = 0.0;
   ArrayInitialize(g_v2_mae_test_pair_mtm, 0.0);
}

//+------------------------------------------------------------------+
double V2_MaeDailyFloorValue(const double daily_anchor, const double daily_frac)
{
   if(daily_anchor <= 0.0 || daily_frac < 0.0)
      return 0.0;
   return daily_anchor * (1.0 - daily_frac);
}

//+------------------------------------------------------------------+
double V2_MaeDistToFloor(const double equity_low,
                         const double daily_anchor,
                         const double daily_frac)
{
   return equity_low - V2_MaeDailyFloorValue(daily_anchor, daily_frac);
}

//+------------------------------------------------------------------+
double V2_MaeReadEquityLive()
{
   if(g_v2_mae_test_active)
      return g_v2_mae_test_equity;
   return AccountInfoDouble(ACCOUNT_EQUITY);
}

double V2_MaeReadBalanceLive()
{
   if(g_v2_mae_test_active)
      return g_v2_mae_test_balance;
   return AccountInfoDouble(ACCOUNT_BALANCE);
}

//+------------------------------------------------------------------+
double V2_MaeComputePairOpenMtm(const string symbol)
{
   if(g_v2_mae_test_active) {
      const int idx = V2_MaePairIndex(symbol);
      if(idx < 0)
         return 0.0;
      return g_v2_mae_test_pair_mtm[idx];
   }

   double sum = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != symbol)
         continue;
      sum += PositionGetDouble(POSITION_PROFIT);
   }
   return sum;
}

//+------------------------------------------------------------------+
void V2_MaeSeedCurrentDay(const string day_key,
                          const double equity,
                          const double open_mtm,
                          const double &pair_mtm[],
                          const double daily_anchor,
                          const double daily_loss_frac)
{
   g_v2_mae_day_key = day_key;
   g_v2_mae_equity_low = equity;
   g_v2_mae_open_mtm_trough = open_mtm;
   g_v2_mae_open_mtm_peak = open_mtm;
   g_v2_mae_equity_low_dist_to_floor = V2_MaeDistToFloor(equity, daily_anchor, daily_loss_frac);
   for(int i = 0; i < V2_MAE_PAIR_COUNT; i++)
      g_v2_mae_pair_mtm_trough[i] = pair_mtm[i];
}

//+------------------------------------------------------------------+
void V2_MaeCoreUpdate(const string day_key,
                      const double equity,
                      const double balance,
                      const double &pair_mtm[],
                      const double daily_anchor,
                      const double daily_loss_frac)
{
   const double open_mtm = equity - balance;

   if(g_v2_mae_day_key == "" || day_key != g_v2_mae_day_key) {
      V2_MaeSeedCurrentDay(day_key, equity, open_mtm, pair_mtm, daily_anchor, daily_loss_frac);
      return;
   }

   if(equity < g_v2_mae_equity_low) {
      g_v2_mae_equity_low = equity;
      g_v2_mae_equity_low_dist_to_floor = V2_MaeDistToFloor(equity, daily_anchor, daily_loss_frac);
   }

   if(open_mtm < g_v2_mae_open_mtm_trough)
      g_v2_mae_open_mtm_trough = open_mtm;
   if(open_mtm > g_v2_mae_open_mtm_peak)
      g_v2_mae_open_mtm_peak = open_mtm;

   for(int i = 0; i < V2_MAE_PAIR_COUNT; i++) {
      if(pair_mtm[i] < g_v2_mae_pair_mtm_trough[i])
         g_v2_mae_pair_mtm_trough[i] = pair_mtm[i];
   }
}

//+------------------------------------------------------------------+
void V2_MaeOnTick()
{
   const datetime utc_now = TimeGMT();
   const string day_key = V2_CbCestDayKey(utc_now);
   const double balance = V2_MaeReadBalanceLive();
   const double equity = V2_MaeReadEquityLive();
   const double daily_anchor = V2_CbEnsureDailyAnchor(day_key, balance);

   double pair_mtm[V2_MAE_PAIR_COUNT];
   for(int i = 0; i < V2_MAE_PAIR_COUNT; i++)
      pair_mtm[i] = V2_MaeComputePairOpenMtm(V2_MaePairSymbol(i));

   V2_MaeCoreUpdate(day_key, equity, balance, pair_mtm, daily_anchor, InpCbDailyLossFrac);
}

//+------------------------------------------------------------------+
double V2_MaeReadPairTrough(const int idx)
{
   if(idx < 0 || idx >= V2_MAE_PAIR_COUNT)
      return 0.0;
   return g_v2_mae_pair_mtm_trough[idx];
}

#endif // FXMATRIX_V2_MAE_MQH
