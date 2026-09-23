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

#define GRIND_SNAPSHOT_CLAIM      "GRIND_SNAPSHOT_CLAIM"
#define GRIND_SNAPSHOT_START_DAY  "GRIND_SNAPSHOT_START_DAY"
#define GRIND_SNAPSHOT_START_BAL  "GRIND_SNAPSHOT_START_BAL"
#define GRIND_SNAPSHOT_START_EQ   "GRIND_SNAPSHOT_START_EQ"
#define GRIND_SNAPSHOT_START_PSWAP "GRIND_SNAPSHOT_START_PSWAP"

string g_grind_snapshot_day_key = "";

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
};

//+------------------------------------------------------------------+
bool Grind_SnapshotRollDue(const string last_key, const string key)
{
   return false;
}

//+------------------------------------------------------------------+
int Grind_FtmoDayNum(const string key)
{
   return 0;
}

//+------------------------------------------------------------------+
bool Grind_SnapshotClaim(const string gv_name, const int day_num)
{
   return false;
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
}

//+------------------------------------------------------------------+
string Grind_SnapshotJson(const GrindSnapshot &s)
{
   return "{}";
}

//+------------------------------------------------------------------+
void Grind_SnapshotEmit(const string ended_key)
{
}

//+------------------------------------------------------------------+
void Grind_SnapshotOnTimer()
{
}

#endif
