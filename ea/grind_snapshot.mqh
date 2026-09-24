//+------------------------------------------------------------------+
//| grind_snapshot.mqh -- FTMO daily DAILY_SNAPSHOT (ADR-159)        |
//+------------------------------------------------------------------+
#ifndef GRIND_SNAPSHOT_MQH
#define GRIND_SNAPSHOT_MQH

#include "grind_pure.mqh"
#include "grind_carry.mqh"
#include "grind_telemetry.mqh"
#include "grind_archive.mqh"
#include "grind_archive_flush.mqh"
#include "grind_api_counter.mqh"

#define GRIND_SNAPSHOT_CLAIM       "GRIND_SNAPSHOT_CLAIM"
#define GRIND_SNAPSHOT_START_DAY   "GRIND_SNAPSHOT_START_DAY"
#define GRIND_SNAPSHOT_START_BAL   "GRIND_SNAPSHOT_START_BAL"
#define GRIND_SNAPSHOT_START_EQ    "GRIND_SNAPSHOT_START_EQ"
#define GRIND_SNAPSHOT_START_PSWAP  "GRIND_SNAPSHOT_START_PSWAP"
#define GRIND_SNAPSHOT_START_LOGIN  "GRIND_SNAPSHOT_START_LOGIN"

string g_grind_snapshot_day_key = "";
datetime g_grind_gate_last_add = 0;

void Grind_GateAccumulate(const string gv_name, const bool is_reporter,
                          const bool gated, const datetime now, const int cap)
{
}

struct GrindSnapshot
{
   long   account_login;
   string ftmo_day;
   double balance_start;
   double equity_start;
   double balance_end;
   double equity_end;
   double realised;
   double nontrade;
   double inventory_pnl;
   double total;
   double swap_day;
   int    positions_long;
   int    positions_short;
   int    orders;
   int    guard_total;
   int    guard_age_s;
   bool   breaker_tripped;
   bool   premidnight_seen;
   int    broker_utc_offset_s;
   bool   start_known;
   string balance_start_source;
   bool   guard_known;
   bool   history_ok;
   int    gated_seconds;
};

//+------------------------------------------------------------------+
bool Grind_SnapshotStartKnown(const bool day_exists,
                              const int stored_day,
                              const int ended_num,
                              const bool login_exists,
                              const long stored_login,
                              const long login_now)
{
   return (day_exists && stored_day == ended_num
           && login_exists && stored_login == login_now);
}

//+------------------------------------------------------------------+
bool Grind_SnapshotRollDue(const string last_key, const string key)
{
   return (last_key != "" && last_key != key);
}

//+------------------------------------------------------------------+
int Grind_FtmoDayNum(const string key)
{
   if(StringLen(key) != 10)
      return 0;
   if(StringGetCharacter(key, 4) != '.' || StringGetCharacter(key, 7) != '.')
      return 0;
   const string compact = StringSubstr(key, 0, 4)
                          + StringSubstr(key, 5, 2)
                          + StringSubstr(key, 8, 2);
   return (int)StringToInteger(compact);
}

//+------------------------------------------------------------------+
bool Grind_SnapshotClaim(const string gv_name, const int day_num)
{
   if(!GlobalVariableCheck(gv_name))
      GlobalVariableSet(gv_name, 0.0);
   const double v = GlobalVariableGet(gv_name);
   if(v >= (double)day_num)
      return false;
   if(!GlobalVariableSetOnCondition(gv_name, (double)day_num, v))
      return false;
   Grind_GvMarkDirty();
   return true;
}

//+------------------------------------------------------------------+
void Grind_SnapshotCompute(const bool start_known,
                           const double stored_bal_start,
                           const double stored_eq_start,
                           const double stored_pswap_start,
                           const double hist_bal_start,
                           const double bal_end,
                           const double eq_end,
                           const double pswap_now,
                           const double deal_swap_day,
                           GrindSnapshot &s)
{
   s.history_ok = true;
   s.start_known = start_known;
   if(start_known) {
      s.balance_start = stored_bal_start;
      s.balance_start_source = "stored";
   } else {
      s.balance_start = hist_bal_start;
      s.balance_start_source = "history";
   }
   s.balance_end = bal_end;
   s.equity_end = eq_end;
   s.realised = bal_end - s.balance_start;
   if(start_known) {
      s.equity_start = stored_eq_start;
      s.inventory_pnl = (eq_end - bal_end) - (stored_eq_start - s.balance_start);
      s.total = eq_end - stored_eq_start;
      s.swap_day = deal_swap_day + (pswap_now - stored_pswap_start);
   } else {
      s.equity_start = 0.0;
      s.inventory_pnl = 0.0;
      s.total = 0.0;
      s.swap_day = 0.0;
   }
}

//+------------------------------------------------------------------+
string Grind_SnapshotJsonFieldMoney(const double v, const bool known)
{
   if(!known)
      return "null";
   return Grind_ArchiveJsonDouble(v, 2);
}

//+------------------------------------------------------------------+
string Grind_SnapshotJson(const GrindSnapshot &s)
{
   const string eq_start = Grind_SnapshotJsonFieldMoney(s.equity_start, s.start_known);
   const string inv = Grind_SnapshotJsonFieldMoney(s.inventory_pnl, s.start_known);
   const string total = Grind_SnapshotJsonFieldMoney(s.total, s.start_known);
   const bool swap_known = s.start_known && s.history_ok;
   const string swap_day = Grind_SnapshotJsonFieldMoney(s.swap_day, swap_known);
   const bool bal_real_known = s.start_known || s.history_ok;
   const string balance_start = Grind_SnapshotJsonFieldMoney(s.balance_start, bal_real_known);
   const string realised = Grind_SnapshotJsonFieldMoney(s.realised, bal_real_known);
   const string nontrade = Grind_SnapshotJsonFieldMoney(s.nontrade, s.history_ok);
   const string guard_age = s.guard_known
                            ? IntegerToString(s.guard_age_s)
                            : "null";
   return StringFormat(
      "{"
      "\"account_login\":%I64d,"
      "\"ftmo_day\":\"%s\","
      "\"balance_start\":%s,"
      "\"equity_start\":%s,"
      "\"balance_end\":%s,"
      "\"equity_end\":%s,"
      "\"realised\":%s,"
      "\"nontrade\":%s,"
      "\"inventory_pnl\":%s,"
      "\"total\":%s,"
      "\"swap_day\":%s,"
      "\"positions_long\":%d,"
      "\"positions_short\":%d,"
      "\"orders\":%d,"
      "\"guard_total\":%d,"
      "\"guard_age_s\":%s,"
      "\"breaker_tripped\":%s,"
      "\"premidnight_seen\":%s,"
      "\"broker_utc_offset_s\":%d,"
      "\"start_known\":%s,"
      "\"balance_start_source\":\"%s\","
      "\"history_ok\":%s"
      "}",
      s.account_login,
      s.ftmo_day,
      balance_start,
      eq_start,
      Grind_ArchiveJsonDouble(s.balance_end, 2),
      Grind_ArchiveJsonDouble(s.equity_end, 2),
      realised,
      nontrade,
      inv,
      total,
      swap_day,
      s.positions_long,
      s.positions_short,
      s.orders,
      s.guard_total,
      guard_age,
      s.breaker_tripped ? "true" : "false",
      s.premidnight_seen ? "true" : "false",
      s.broker_utc_offset_s,
      s.start_known ? "true" : "false",
      s.balance_start_source,
      s.history_ok ? "true" : "false"
   );
}

//+------------------------------------------------------------------+
double Grind_SnapshotSumPositionSwap()
{
   double sum = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      sum += PositionGetDouble(POSITION_SWAP);
   }
   return sum;
}

//+------------------------------------------------------------------+
void Grind_SnapshotCountPositions(int &positions_long, int &positions_short)
{
   positions_long = 0;
   positions_short = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)
         positions_long++;
      else if(ptype == POSITION_TYPE_SELL)
         positions_short++;
   }
}

//+------------------------------------------------------------------+
void Grind_SnapshotEmit(const string ended_key)
{
   const datetime now_gmt = TimeGMT();
   const int off = (int)(TimeTradeServer() - TimeGMT());
   const datetime start_next = Grind_FtmoDayStartGmt(now_gmt);
   const datetime start_ended = Grind_FtmoDayStartGmt(start_next - 1);
   const datetime win_from = start_ended + off;
   const datetime win_to = start_next + off - 1;

   double deal_swap_day = 0.0;
   double nontrade = 0.0;
   const bool history_ok = HistorySelect(win_from, win_to);
   if(history_ok) {
      const int total = HistoryDealsTotal();
      for(int i = 0; i < total; i++) {
         const ulong ticket = HistoryDealGetTicket(i);
         if(ticket == 0)
            continue;
         deal_swap_day += HistoryDealGetDouble(ticket, DEAL_SWAP);
         const long dtype = HistoryDealGetInteger(ticket, DEAL_TYPE);
         if(dtype != DEAL_TYPE_BUY && dtype != DEAL_TYPE_SELL) {
            nontrade += HistoryDealGetDouble(ticket, DEAL_PROFIT)
                        + HistoryDealGetDouble(ticket, DEAL_SWAP)
                        + HistoryDealGetDouble(ticket, DEAL_COMMISSION)
                        + HistoryDealGetDouble(ticket, DEAL_FEE);
         }
      }
   }

   const double pswap_now = Grind_SnapshotSumPositionSwap();
   const int ended_num = Grind_FtmoDayNum(ended_key);
   const long login_now = AccountInfoInteger(ACCOUNT_LOGIN);
   const bool day_exists = GlobalVariableCheck(GRIND_SNAPSHOT_START_DAY);
   const int stored_day = day_exists ? (int)GlobalVariableGet(GRIND_SNAPSHOT_START_DAY) : 0;
   const bool login_exists = GlobalVariableCheck(GRIND_SNAPSHOT_START_LOGIN);
   const long stored_login = login_exists ? (long)GlobalVariableGet(GRIND_SNAPSHOT_START_LOGIN) : 0;
   const bool start_known = Grind_SnapshotStartKnown(day_exists, stored_day, ended_num,
                                                     login_exists, stored_login, login_now);
   double stored_bal = 0.0;
   double stored_eq = 0.0;
   double stored_pswap = 0.0;
   if(start_known) {
      stored_bal = GlobalVariableGet(GRIND_SNAPSHOT_START_BAL);
      stored_eq = GlobalVariableGet(GRIND_SNAPSHOT_START_EQ);
      stored_pswap = GlobalVariableGet(GRIND_SNAPSHOT_START_PSWAP);
   }

   Grind_BreakerLoadInitialDeposit();
   double amounts[];
   datetime times[];
   int n = 0;
   Grind_BreakerCollectDealHistory(start_ended + off, TimeTradeServer() + 60,
                                   amounts, times, n);
   const double balance_now = AccountInfoDouble(ACCOUNT_BALANCE);
   const double hist_bal_start = Grind_BreakerDayAnchor(balance_now, amounts, times, n,
                                                        start_ended + off,
                                                        g_grind_breaker_initial_deposit,
                                                        g_grind_breaker_initial_time);
   const double bal_end = balance_now;
   const double eq_end = AccountInfoDouble(ACCOUNT_EQUITY);

   GrindSnapshot s;
   Grind_SnapshotCompute(start_known, stored_bal, stored_eq, stored_pswap,
                         hist_bal_start, bal_end, eq_end, pswap_now, deal_swap_day, s);
   s.history_ok = history_ok;
   s.nontrade = nontrade;
   s.ftmo_day = ended_key;
   s.account_login = AccountInfoInteger(ACCOUNT_LOGIN);
   s.broker_utc_offset_s = off;
   Grind_SnapshotCountPositions(s.positions_long, s.positions_short);
   s.orders = OrdersTotal();
   s.guard_total = g_grind_last_guard_total;
   s.guard_known = (g_grind_last_guard_time > 0);
   s.guard_age_s = s.guard_known ? (int)(now_gmt - g_grind_last_guard_time) : 0;
   s.breaker_tripped = GlobalVariableCheck("GRIND_BREAKER_TRIPPED_" + ended_key);
   s.premidnight_seen = GlobalVariableCheck("GRIND_BREAKER_PREMID_" + ended_key);

   const string current_key = Grind_FtmoDayKey(now_gmt);
   const int current_num = Grind_FtmoDayNum(current_key);
   GlobalVariableSet(GRIND_SNAPSHOT_START_DAY, (double)current_num);
   GlobalVariableSet(GRIND_SNAPSHOT_START_BAL, bal_end);
   GlobalVariableSet(GRIND_SNAPSHOT_START_EQ, eq_end);
   GlobalVariableSet(GRIND_SNAPSHOT_START_PSWAP, pswap_now);
   GlobalVariableSet(GRIND_SNAPSHOT_START_LOGIN, (double)login_now);
   Grind_GvMarkDirty();

   const string json = Grind_SnapshotJson(s);
   Grind_TelemetryEmit(g_grind_telemetry_instance, "DAILY_SNAPSHOT", json);
   Grind_ArchiveMarker("INFO", "DAILY_SNAPSHOT", ended_key, 0, json);
   Grind_ArchiveFlush(true);
}

//+------------------------------------------------------------------+
void Grind_SnapshotOnTimer()
{
   const string key = Grind_FtmoDayKey(TimeGMT());
   if(g_grind_snapshot_day_key == "") {
      g_grind_snapshot_day_key = key;
      return;
   }
   if(!Grind_SnapshotRollDue(g_grind_snapshot_day_key, key))
      return;
   const string ended = g_grind_snapshot_day_key;
   g_grind_snapshot_day_key = key;
   if(Grind_SnapshotClaim(GRIND_SNAPSHOT_CLAIM, Grind_FtmoDayNum(key)))
      Grind_SnapshotEmit(ended);
}

#endif
