//+------------------------------------------------------------------+
//| grind_state.mqh — shared side/layer state for fxgrind            |
//+------------------------------------------------------------------+
#ifndef GRIND_STATE_MQH
#define GRIND_STATE_MQH

struct GrindLayer
{
   double   entry_price;
   double   exit_target;
   ulong    position_ticket;
   ulong    exit_order_ticket;
   ulong    exit_position_ticket;
   int      layer_index;
};

struct GrindSideState
{
   GrindLayer layers[];
   ulong    l0_pending_ticket;
   ulong    add_pending_ticket;
   bool     add_held;
   double   add_held_target;
   int      entry_transitions_used;
   int      add_gap_missed;
   bool     entry_transitions_exhausted;
   bool     add_gap_beyond_target;
   bool     cap_warn_emitted;
};

GrindSideState g_grind_long;
GrindSideState g_grind_short;
bool           g_grind_halted = false;
bool           g_grind_cap_blocked = false;
long           g_grind_last_feed_tick_msc = 0;
int            g_grind_fill_count = 0;
int            g_grind_scalp_count = 0;
string         g_grind_telemetry_instance = "GRIND_UNKNOWN";

string Grind_LogTag()
{
   return "[" + g_grind_telemetry_instance + "] ";
}
string         g_grind_cap_leg_a = "";
string         g_grind_cap_leg_b = "";
ulong          g_grind_processed_deals[];
int            g_grind_processed_deal_count = 0;

bool g_grind_add_due_long  = false;
bool g_grind_add_due_short = false;
bool g_grind_add_due_attempted_long  = false;
bool g_grind_add_due_attempted_short = false;

#endif // GRIND_STATE_MQH
