//+------------------------------------------------------------------+
//| grind_replay.mqh — ADR-164 missed-deal replay (commit 1: stubs)   |
//+------------------------------------------------------------------+
#ifndef GRIND_REPLAY_MQH
#define GRIND_REPLAY_MQH

#define GRIND_REPLAY_MARGIN_S       120
#define GRIND_REPLAY_TO_AHEAD_S     3600
#define GRIND_REPLAY_TICK_MIN_MS    1000
#define GRIND_REPLAY_EVENT_WAIT_MS  60000

struct GrindReplaySeen
{
   ulong ticket;
   long  deal_time_msc;
   bool  replayed;
   ulong replay_ms;
   bool  event_seen;
   bool  missed_reported;
};

GrindReplaySeen g_grind_replay_seen[];
int             g_grind_replay_seen_count = 0;

bool     g_grind_replay_ready = false;
datetime g_grind_replay_init_time = 0;
datetime g_grind_replay_last_sweep_time = 0;
ulong    g_grind_replay_last_tick_sweep_ms = 0;
bool     g_grind_replay_connected = false;
ulong    g_grind_replay_down_since_ms = 0;

bool     g_grind_replay_test_connected_active = false;
bool     g_grind_replay_test_connected = false;

bool     g_grind_replay_test_inv_active = false;
bool     g_grind_replay_test_inv_results[];
string   g_grind_replay_test_inv_reasons[];
int      g_grind_replay_test_inv_index = 0;
int      g_grind_replay_test_inv_calls = 0;

//+------------------------------------------------------------------+
void Grind_ReplayReset()
{
   ArrayResize(g_grind_replay_seen, 0);
   g_grind_replay_seen_count = 0;
   g_grind_replay_ready = false;
   g_grind_replay_init_time = 0;
   g_grind_replay_last_sweep_time = 0;
   g_grind_replay_last_tick_sweep_ms = 0;
   g_grind_replay_connected = false;
   g_grind_replay_down_since_ms = 0;
}

//+------------------------------------------------------------------+
void Grind_ReplayTestReset()
{
   Grind_ReplayReset();
   g_grind_replay_test_connected_active = false;
   g_grind_replay_test_connected = false;
   g_grind_replay_test_inv_active = false;
   ArrayResize(g_grind_replay_test_inv_results, 0);
   ArrayResize(g_grind_replay_test_inv_reasons, 0);
   g_grind_replay_test_inv_index = 0;
   g_grind_replay_test_inv_calls = 0;
}

//+------------------------------------------------------------------+
bool Grind_ReplayIsSeen(const ulong ticket)
{
   return false;
}

//+------------------------------------------------------------------+
bool Grind_ReplayWasReplayed(const ulong ticket)
{
   return false;
}

//+------------------------------------------------------------------+
int Grind_ReplaySeenCount()
{
   return 0;
}

//+------------------------------------------------------------------+
void Grind_ReplayMarkSeen(const ulong ticket, const long deal_time_msc)
{
}

//+------------------------------------------------------------------+
datetime Grind_ReplayWindowFrom(const datetime init_time,
                                const datetime last_sweep_time,
                                const int margin_s)
{
   return 0;
}

//+------------------------------------------------------------------+
bool Grind_ReplayTerminalConnected()
{
   if(g_grind_replay_test_connected_active)
      return g_grind_replay_test_connected;
   return (TerminalInfoInteger(TERMINAL_CONNECTED) != 0);
}

//+------------------------------------------------------------------+
int Grind_ReplayInit(const ulong magic, const ulong now_ms)
{
   return 0;
}

//+------------------------------------------------------------------+
int Grind_ReplaySweep(const ulong magic,
                      const string slot,
                      const double exit_pips,
                      const double add_pips,
                      const double deadband_pips,
                      const int max_layers,
                      const double lots,
                      const double exit_pips_short,
                      const double add_pips_short,
                      const string path,
                      const ulong now_ms)
{
   return 0;
}

//+------------------------------------------------------------------+
void Grind_ReplayOnTimer(const ulong magic,
                         const string slot,
                         const double exit_pips,
                         const double add_pips,
                         const double deadband_pips,
                         const int max_layers,
                         const double lots,
                         const double exit_pips_short,
                         const double add_pips_short,
                         const ulong now_ms)
{
}

//+------------------------------------------------------------------+
bool Grind_ReplayInvariantOk()
{
   return false;
}

//+------------------------------------------------------------------+
bool Grind_ReplayCheckInvariants(const ulong magic,
                                 const string slot,
                                 const double exit_pips,
                                 const double add_pips,
                                 const double deadband_pips,
                                 const int max_layers,
                                 const double lots,
                                 const double exit_pips_short,
                                 const double add_pips_short,
                                 const ulong now_ms)
{
   return false;
}

//+------------------------------------------------------------------+
bool Grind_ReplayConnectionStep(const bool connected, const ulong now_ms)
{
   return false;
}

//+------------------------------------------------------------------+
void Grind_ReplayCheckMissed(const ulong now_ms)
{
}

//+------------------------------------------------------------------+
void Grind_ReplayPrune(const datetime from)
{
}

//+------------------------------------------------------------------+
bool Grind_ReplayNoteEvent(const ulong ticket)
{
   return false;
}

//+------------------------------------------------------------------+
void Grind_ReplayMarkSeenIfOurs(const ulong ticket, const ulong magic)
{
}

#endif // GRIND_REPLAY_MQH
