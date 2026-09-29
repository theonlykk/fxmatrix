//+------------------------------------------------------------------+
//| grind_replay.mqh -- ADR-164 missed-deal replay                    |
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
int Grind_ReplayFindSeenIdx(const ulong ticket)
{
   for(int i = 0; i < g_grind_replay_seen_count; i++) {
      if(g_grind_replay_seen[i].ticket == ticket)
         return i;
   }
   return -1;
}

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
   return (Grind_ReplayFindSeenIdx(ticket) >= 0);
}

//+------------------------------------------------------------------+
bool Grind_ReplayWasReplayed(const ulong ticket)
{
   const int idx = Grind_ReplayFindSeenIdx(ticket);
   if(idx < 0)
      return false;
   return g_grind_replay_seen[idx].replayed;
}

//+------------------------------------------------------------------+
int Grind_ReplaySeenCount()
{
   return g_grind_replay_seen_count;
}

//+------------------------------------------------------------------+
void Grind_ReplayMarkSeen(const ulong ticket, const long deal_time_msc)
{
   if(Grind_ReplayFindSeenIdx(ticket) >= 0)
      return;
   ArrayResize(g_grind_replay_seen, g_grind_replay_seen_count + 1);
   g_grind_replay_seen[g_grind_replay_seen_count].ticket = ticket;
   g_grind_replay_seen[g_grind_replay_seen_count].deal_time_msc = deal_time_msc;
   g_grind_replay_seen[g_grind_replay_seen_count].replayed = false;
   g_grind_replay_seen[g_grind_replay_seen_count].replay_ms = 0;
   g_grind_replay_seen[g_grind_replay_seen_count].event_seen = false;
   g_grind_replay_seen[g_grind_replay_seen_count].missed_reported = false;
   g_grind_replay_seen_count++;
}

//+------------------------------------------------------------------+
void Grind_ReplayMarkReplayed(const ulong ticket, const long deal_time_msc, const ulong now_ms)
{
   int idx = Grind_ReplayFindSeenIdx(ticket);
   if(idx < 0) {
      Grind_ReplayMarkSeen(ticket, deal_time_msc);
      idx = Grind_ReplayFindSeenIdx(ticket);
   }
   if(idx < 0)
      return;
   g_grind_replay_seen[idx].replayed = true;
   g_grind_replay_seen[idx].replay_ms = now_ms;
}

//+------------------------------------------------------------------+
datetime Grind_ReplayWindowFrom(const datetime init_time,
                                const datetime last_sweep_time,
                                const int margin_s)
{
   if(init_time <= 0)
      return 0;
   if(last_sweep_time <= (datetime)margin_s)
      return init_time;
   const datetime margin_back = last_sweep_time - margin_s;
   return (init_time > margin_back ? init_time : margin_back);
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
   Grind_ReplayReset();
   g_grind_replay_init_time = Grind_HistNow();
   g_grind_replay_last_sweep_time = g_grind_replay_init_time;
   g_grind_replay_connected = Grind_ReplayTerminalConnected();

   const datetime init = g_grind_replay_init_time;
   int seeded = 0;
   if(!Grind_HistSelect(init - GRIND_REPLAY_MARGIN_S, init + GRIND_REPLAY_TO_AHEAD_S)) {
      Grind_ArchiveMarker("WARN", "REPLAY_SEED_FAILED", "", 0, "{}");
   } else {
      const int total = Grind_HistDealsTotal();
      for(int i = 0; i < total; i++) {
         const ulong t = Grind_HistDealTicket(i);
         if(t == 0)
            continue;
         if(Grind_DealGetString(t, DEAL_SYMBOL) != _Symbol)
            continue;
         if(!Grind_MagicMatches(Grind_DealGetInteger(t, DEAL_MAGIC), magic))
            continue;
         const long msc = Grind_DealGetInteger(t, DEAL_TIME_MSC);
         Grind_ReplayMarkSeen(t, msc);
         seeded++;
      }
   }

   g_grind_replay_ready = true;
   Print(Grind_LogTag(), "GRIND_REPLAY ready seeded=", seeded);
   return seeded;
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
   if(!g_grind_replay_ready)
      return 0;

   const datetime now = Grind_HistNow();
   const datetime from = Grind_ReplayWindowFrom(g_grind_replay_init_time,
                                                g_grind_replay_last_sweep_time,
                                                GRIND_REPLAY_MARGIN_S);
   if(!Grind_HistSelect(from, now + GRIND_REPLAY_TO_AHEAD_S))
      return 0;

   ulong snap_tickets[];
   long  snap_msc[];
   int snap_count = 0;
   const int total = Grind_HistDealsTotal();
   for(int i = 0; i < total; i++) {
      const ulong t = Grind_HistDealTicket(i);
      if(t == 0)
         continue;
      if(Grind_DealGetString(t, DEAL_SYMBOL) != _Symbol)
         continue;
      if(!Grind_MagicMatches(Grind_DealGetInteger(t, DEAL_MAGIC), magic))
         continue;
      if(Grind_ReplayIsSeen(t))
         continue;
      const long msc = Grind_DealGetInteger(t, DEAL_TIME_MSC);
      ArrayResize(snap_tickets, snap_count + 1);
      ArrayResize(snap_msc, snap_count + 1);
      snap_tickets[snap_count] = t;
      snap_msc[snap_count] = msc;
      snap_count++;
   }

   for(int a = 0; a < snap_count - 1; a++) {
      for(int b = a + 1; b < snap_count; b++) {
         bool swap = false;
         if(snap_msc[a] > snap_msc[b])
            swap = true;
         else if(snap_msc[a] == snap_msc[b] && snap_tickets[a] > snap_tickets[b])
            swap = true;
         if(swap) {
            const ulong tt = snap_tickets[a];
            snap_tickets[a] = snap_tickets[b];
            snap_tickets[b] = tt;
            const long tm = snap_msc[a];
            snap_msc[a] = snap_msc[b];
            snap_msc[b] = tm;
         }
      }
   }

   int replayed = 0;
   for(int i = 0; i < snap_count; i++) {
      const ulong t = snap_tickets[i];
      if(!Grind_DealSelect(t))
         continue;

      const long entry_type = Grind_DealGetInteger(t, DEAL_ENTRY);
      const string comment = Grind_DealGetString(t, DEAL_COMMENT);
      string role = "";
      string side = "";
      int layer = -1;
      string c_slot, c_side, c_role;
      int c_layer;
      if(GrindCommentParse(comment, c_slot, c_side, c_layer, c_role)) {
         role = c_role;
         side = c_side;
         layer = c_layer;
      }

      if(!Grind_ProcessDeal(t, magic, slot, exit_pips, add_pips, deadband_pips,
                            max_layers, lots, exit_pips_short, add_pips_short))
         continue;

      Grind_ReplayMarkReplayed(t, snap_msc[i], now_ms);

      const string entry_label = Grind_ArchiveEntryTypeLabel(entry_type);
      const bool owned = Grind_DealWasProcessed(t);
      const string detail =
         StringFormat("{\"path\":\"%s\",\"entry\":\"%s\",\"role\":\"%s\",\"side\":\"%s\",\"layer\":%d,"
                      "\"deal_time_msc\":%I64d,\"owned\":%s,\"halted\":%s}",
                      path, entry_label, role, side, layer, snap_msc[i],
                      owned ? "true" : "false",
                      g_grind_halted ? "true" : "false");
      Grind_ArchiveMarker("INFO", "DEAL_REPLAYED", "", t, detail);
      Print(Grind_LogTag(), "WARN GRIND_REPLAY deal=", t, " path=", path,
            " role=", role, " side=", side, " layer=", layer);
      replayed++;
   }

   g_grind_replay_last_sweep_time = now;
   Grind_ReplayPrune(from);
   return replayed;
}

//+------------------------------------------------------------------+
bool Grind_ReplayInvariantOk()
{
   if(g_grind_replay_test_inv_active) {
      g_grind_replay_test_inv_calls++;
      if(g_grind_replay_test_inv_index >= ArraySize(g_grind_replay_test_inv_results))
         return Grind_CheckBookInvariants();
      const bool r = g_grind_replay_test_inv_results[g_grind_replay_test_inv_index];
      g_grind_invariant_reason = g_grind_replay_test_inv_reasons[g_grind_replay_test_inv_index];
      g_grind_replay_test_inv_index++;
      return r;
   }
   return Grind_CheckBookInvariants();
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
   bool ok = Grind_ReplayInvariantOk();
   if(ok || !g_grind_replay_ready || g_grind_halted)
      return ok;
   if(g_grind_replay_last_tick_sweep_ms != 0 &&
      now_ms - g_grind_replay_last_tick_sweep_ms < GRIND_REPLAY_TICK_MIN_MS)
      return ok;
   g_grind_replay_last_tick_sweep_ms = now_ms;
   if(Grind_ReplaySweep(magic, slot, exit_pips, add_pips, deadband_pips, max_layers, lots,
                        exit_pips_short, add_pips_short, "tick", now_ms) == 0)
      return ok;
   return Grind_ReplayInvariantOk();
}

//+------------------------------------------------------------------+
bool Grind_ReplayConnectionStep(const bool connected, const ulong now_ms)
{
   const bool was = g_grind_replay_connected;
   g_grind_replay_connected = connected;
   if(was && !connected) {
      g_grind_replay_down_since_ms = now_ms;
      return false;
   }
   if(!was && connected) {
      long down_ms = -1;
      if(g_grind_replay_down_since_ms != 0)
         down_ms = (long)(now_ms - g_grind_replay_down_since_ms);
      const string detail = StringFormat("{\"down_ms\":%I64d}", down_ms);
      Grind_ArchiveMarker("INFO", "CONNECTION_RESTORED", "", 0, detail);
      Print(Grind_LogTag(), "INFO GRIND_REPLAY connection restored down_ms=", down_ms);
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
void Grind_ReplayCheckMissed(const ulong now_ms)
{
   for(int i = 0; i < g_grind_replay_seen_count; i++) {
      if(!g_grind_replay_seen[i].replayed)
         continue;
      if(g_grind_replay_seen[i].event_seen)
         continue;
      if(g_grind_replay_seen[i].missed_reported)
         continue;
      if(now_ms - g_grind_replay_seen[i].replay_ms < GRIND_REPLAY_EVENT_WAIT_MS)
         continue;
      const ulong ticket = g_grind_replay_seen[i].ticket;
      const long msc = g_grind_replay_seen[i].deal_time_msc;
      const string detail = StringFormat("{\"deal_time_msc\":%I64d}", msc);
      Grind_ArchiveMarker("WARN", "DEAL_EVENT_MISSED", "", ticket, detail);
      Print(Grind_LogTag(), "WARN GRIND_REPLAY DEAL_EVENT_MISSED deal=", ticket);
      g_grind_replay_seen[i].missed_reported = true;
   }
}

//+------------------------------------------------------------------+
void Grind_ReplayPrune(const datetime from)
{
   const long cutoff = (long)from * 1000;
   int write = 0;
   for(int i = 0; i < g_grind_replay_seen_count; i++) {
      const GrindReplaySeen e = g_grind_replay_seen[i];
      if(e.deal_time_msc < cutoff) {
         if(e.replayed && !e.event_seen && !e.missed_reported)
            g_grind_replay_seen[write++] = e;
         continue;
      }
      g_grind_replay_seen[write++] = e;
   }
   g_grind_replay_seen_count = write;
   ArrayResize(g_grind_replay_seen, g_grind_replay_seen_count);
}

//+------------------------------------------------------------------+
bool Grind_ReplayNoteEvent(const ulong ticket)
{
   const int idx = Grind_ReplayFindSeenIdx(ticket);
   if(idx < 0)
      return false;
   if(!g_grind_replay_seen[idx].replayed)
      return false;
   g_grind_replay_seen[idx].event_seen = true;
   return true;
}

//+------------------------------------------------------------------+
void Grind_ReplayMarkSeenIfOurs(const ulong ticket, const ulong magic)
{
   if(!Grind_DealSelect(ticket))
      return;
   if(Grind_DealGetString(ticket, DEAL_SYMBOL) != _Symbol)
      return;
   if(!Grind_MagicMatches(Grind_DealGetInteger(ticket, DEAL_MAGIC), magic))
      return;
   Grind_ReplayMarkSeen(ticket, Grind_DealGetInteger(ticket, DEAL_TIME_MSC));
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
   Grind_ReplayConnectionStep(Grind_ReplayTerminalConnected(), now_ms);
   Grind_ReplaySweep(magic, slot, exit_pips, add_pips, deadband_pips, max_layers, lots,
                     exit_pips_short, add_pips_short, "timer", now_ms);
   Grind_ReplayCheckMissed(now_ms);
}

#endif // GRIND_REPLAY_MQH
