//+------------------------------------------------------------------+
//| fxgrind_replay_core.mqh — replay harness broker + event loop     |
//+------------------------------------------------------------------+
#ifndef FXGRIND_REPLAY_CORE_MQH
#define FXGRIND_REPLAY_CORE_MQH

#include "grind_engine.mqh"
#include "grind_archive.mqh"
#include "grind_pnl.mqh"

#define RPL_STUBS 1

const string RPL_MIRRORS_EA = "5bb5fdb";
const ulong  RPL_MAGIC_DEFAULT = 22260201UL;
const string RPL_SLOT_DEFAULT = "OPT";
const double RPL_LOTS_DEFAULT = 0.01;

struct RplTick
{
   long   time_msc;
   double bid;
   double ask;
};

struct RplRealDeal
{
   long   time_ms;
   long   entry_type;
   long   deal_type;
   string role;
   string side;
   int    layer;
   double price;
   ulong  position_id;
};

struct RplSegmentConfig
{
   int    seg_id;
   string instance;
   ulong  magic;
   long   from_ms;
   long   to_ms;
   double width_l;
   double width_s;
   double add_l;
   double add_s;
   double exit_l;
   double exit_s;
   int    cap;
   double stranded;
   double deadband;
   bool   lattice;
   bool   reroll;
   int    gate;
   bool   carry;
   bool   fill_time_place;
   int    reserve;
   bool   sync;
   bool   skip_lattice_preload;
};

struct RplDealRow
{
   int    seg_id;
   int    sync_idx;
   long   time_ms;
   ulong  deal;
   ulong  order;
   ulong  position;
   long   entry_type;
   long   deal_type;
   string role;
   string side;
   int    layer;
   double price;
};

struct RplEventRow
{
   int    seg_id;
   int    sync_idx;
   long   time_ms;
   string kind;
   string code;
   string json;
};

#if RPL_STUBS

bool Rpl_SafeToRun(const string data_path, const bool trade_allowed, const long login, const string server)
{
   return false;
}

int Rpl_DeleteGrindGlobalVariables()
{
   return 0;
}

void Rpl_ResetAll() {}

void Rpl_ConfigureEngine(RplSegmentConfig &cfg) {}

void Rpl_SeedLayer(const string side,
                   const int layer_index,
                   const double entry,
                   const long open_ms,
                   const ulong ticket,
                   const double vl,
                   const double swap,
                   const double volume) {}

bool Rpl_RunTicks(const RplTick &ticks[], const int tick_count, RplSegmentConfig &cfg)
{
   return false;
}

void Rpl_BrokerReset() {}

ulong Rpl_BrokerPlaceLimit(const long type, const double price, const string comment, const long placed_ms)
{
   return 0;
}

bool Rpl_BrokerFillOnTick(const long time_msc, const double bid, const double ask,
                          bool &filled, double &fill_price, long &fill_time_msc)
{
   filled = false;
   return false;
}

int Rpl_DealsCount() { return 0; }

bool Rpl_GetDealRow(const int index, RplDealRow &out)
{
   return false;
}

int Rpl_EventsCount() { return 0; }

bool Rpl_GetEventRow(const int index, RplEventRow &out)
{
   return false;
}

int Rpl_CountEventsWithCode(const string code) { return 0; }

int Rpl_OrderSeamCount() { return 0; }

bool Rpl_FindOrderByRoleLayer(const string side_letter, const int layer, const string role,
                              double &price_out, ulong &ticket_out)
{
   return false;
}

bool Rpl_OrderExistsForLayer(const string side_letter, const int layer, const string role)
{
   return false;
}

int Rpl_LongDepth() { return 0; }

int Rpl_ShortDepth() { return 0; }

bool Rpl_WasAborted() { return false; }

string Rpl_AbortReason() { return ""; }

bool Rpl_RunReplayScript(const string tag, const bool sync_mode) { return false; }

void Rpl_SetRealDeals(const RplRealDeal &deals[], const int count) {}

int Rpl_ScalpEventsQueued() { return 0; }

string Rpl_ScalpEventPeek() { return ""; }

bool Rpl_CheckSafetyForRun() { return false; }

void Rpl_SetTestSwaps(const string date, const double pl, const double ps, const double mult) {}

double Rpl_GetPositionSwap(const ulong ticket) { return 0.0; }

#else
// Implementation in commit 2 (RPL_STUBS off).
#endif

#endif // FXGRIND_REPLAY_CORE_MQH
