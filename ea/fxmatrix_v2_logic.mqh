//+------------------------------------------------------------------+
//| fxmatrix_v2_logic.mqh — shared V2 geometry + state helpers        |
//| Used by fxmatrix_v2.mq5 and fxmatrix_v2_tests.mq5                 |
//+------------------------------------------------------------------+
#ifndef FXMATRIX_V2_LOGIC_MQH
#define FXMATRIX_V2_LOGIC_MQH

#ifndef MM_LONG_V2
#define MM_LONG_V2   20260901
#endif
#ifndef MM_SHORT_V2
#define MM_SHORT_V2  20260902
#endif
#define V2_EXIT_MAGIC_OFFSET 2
#define MM_LONG_V2_EXIT   (MM_LONG_V2 + V2_EXIT_MAGIC_OFFSET)
#define MM_SHORT_V2_EXIT  (MM_SHORT_V2 + V2_EXIT_MAGIC_OFFSET)

#define V2_ADD_PIPS_FLOOR    9.0
#define V2_WIDEN_RATIO       1.304
#define V2_ADD_PIPS_CEILING  1000.0
#define V2_EXIT_PIPS         3.0

// Exit orphan retry: 15s throttle (broker-friendly, matches V1 ADR-081 interval).
// Escalate after 90s (~6 attempts) — well under old 5-minute bar retry gap.
// Harness may define overrides before include; production defaults unchanged.
#ifndef V2_EXIT_RETRY_INTERVAL_SEC
#define V2_EXIT_RETRY_INTERVAL_SEC 15
#endif
#ifndef V2_EXIT_ESCALATE_AFTER_SEC
#define V2_EXIT_ESCALATE_AFTER_SEC   90
#endif
#ifndef V2_CLOSEBY_MAX_RETRIES
#define V2_CLOSEBY_MAX_RETRIES       10
#endif

//+------------------------------------------------------------------+
struct V2CloseByTask
{
   ulong ticket1;
   ulong ticket2;
   int   retries;
   int   last_retcode;
};

//+------------------------------------------------------------------+
enum V2ExitAuditAction
{
   V2_EXIT_AUDIT_OK           = 0,
   V2_EXIT_AUDIT_NEEDS_PLACE  = 1,
   V2_EXIT_AUDIT_STALE_CLEAR  = 2,
   V2_EXIT_AUDIT_THROTTLED    = 3,
   V2_EXIT_AUDIT_ESCALATE     = 4
};

//+------------------------------------------------------------------+
//| Positional closed-form (NOT used in production — reference only). |
//+------------------------------------------------------------------+
double V2_SpacingPipsDn_Positional(const int n)
{
   if(n <= 2)
      return V2_ADD_PIPS_FLOOR;
   double raw = V2_ADD_PIPS_FLOOR * MathPow(V2_WIDEN_RATIO, n - 2);
   return MathMin(V2_ADD_PIPS_CEILING, raw);
}

//+------------------------------------------------------------------+
//| Validated running-state add spacing (depth_before = stack size).  |
//+------------------------------------------------------------------+
double V2_AddStepPipsForDepth(const int depth_before, const double current_add_pips)
{
   if(depth_before < 3)
      return V2_ADD_PIPS_FLOOR;
   return current_add_pips;
}

//+------------------------------------------------------------------+
void V2_AdvanceAddPipsOnAppend(double &current_add_pips, const int depth_after)
{
   if(depth_after >= 3)
      current_add_pips = MathMin(V2_ADD_PIPS_CEILING, current_add_pips * V2_WIDEN_RATIO);
}

//+------------------------------------------------------------------+
void V2_ResetAddPipsOnFlat(double &current_add_pips, const int layer_count)
{
   if(layer_count == 0)
      current_add_pips = V2_ADD_PIPS_FLOOR;
}

//+------------------------------------------------------------------+
void V2_OnOwnStackFlat(bool &last_exit_valid, const int layer_count)
{
   if(layer_count == 0)
      last_exit_valid = false;
}

//+------------------------------------------------------------------+
//| Resting exit limit request (opposite-direction, exit magic).      |
//+------------------------------------------------------------------+
bool V2_BuildExitLimitRequest(const string symbol,
                              const double exit_price,
                              const double volume,
                              const int entry_direction,
                              const ulong exit_magic,
                              MqlTradeRequest &req)
{
   if(exit_price <= 0.0 || volume <= 0.0)
      return false;

   int exit_dir = -entry_direction;
   ZeroMemory(req);
   req.action       = TRADE_ACTION_PENDING;
   req.symbol       = symbol;
   req.volume       = volume;
   req.price        = exit_price;
   req.magic        = exit_magic;
   req.type         = (exit_dir > 0) ? ORDER_TYPE_BUY_LIMIT : ORDER_TYPE_SELL_LIMIT;
   req.type_filling = ORDER_FILLING_RETURN;
   req.type_time    = ORDER_TIME_GTC;
   req.comment      = "V2_Exit";
   return true;
}

//+------------------------------------------------------------------+
bool V2_ExitPassivityOkPure(const int entry_direction,
                           const double exit_price,
                           const double bid,
                           const double ask,
                           const double freeze)
{
   if(entry_direction > 0)
      return (exit_price > ask + freeze);
   return (exit_price < bid - freeze);
}

//+------------------------------------------------------------------+
string V2_FormatExitEscalationAlert(const string instance_tag,
                                    const int layer_idx,
                                    const double exit_price)
{
   return StringFormat(
      "ALERT V2_EXIT_UNPROTECTED | instance=%s layer=%d exit_price=%.5f "
      "stuck>%ds signature=V2_EXIT_UNPROTECTED",
      instance_tag, layer_idx, exit_price, V2_EXIT_ESCALATE_AFTER_SEC);
}

//+------------------------------------------------------------------+
//| Pure audit state machine (tests + production throttle logic).     |
//+------------------------------------------------------------------+
V2ExitAuditAction V2_EvaluateExitAudit(const bool position_live,
                                       const bool exit_ticket_live_or_filled,
                                       const datetime last_retry_time,
                                       const datetime first_retry_time,
                                       const bool escalated,
                                       const datetime now)
{
   if(!position_live)
      return V2_EXIT_AUDIT_OK;

   if(exit_ticket_live_or_filled)
      return V2_EXIT_AUDIT_OK;

   if(last_retry_time > 0 &&
      (now - last_retry_time) < V2_EXIT_RETRY_INTERVAL_SEC)
      return V2_EXIT_AUDIT_THROTTLED;

   datetime first = first_retry_time;
   if(first == 0)
      first = now;

   if(!escalated && (now - first) >= V2_EXIT_ESCALATE_AFTER_SEC)
      return V2_EXIT_AUDIT_ESCALATE;

   if(!exit_ticket_live_or_filled)
      return V2_EXIT_AUDIT_NEEDS_PLACE;

   return V2_EXIT_AUDIT_OK;
}

//+------------------------------------------------------------------+
//| Startup orphan guard — layers are never rebuilt from broker scan. |
//+------------------------------------------------------------------+
bool V2_IsOrphanedStartupState(const int layer_count, const int broker_position_count)
{
   return (layer_count == 0 && broker_position_count > 0);
}

string V2_FormatOrphanStartupAlert(const string instance_tag,
                                   const int count,
                                   const string magic_type,
                                   const ulong &tickets[])
{
   string ticket_str = "";
   for(int i = 0; i < ArraySize(tickets); i++) {
      if(i > 0)
         ticket_str += ",";
      ticket_str += IntegerToString((long)tickets[i]);
   }
   return StringFormat("ALERT V2_ORPHANED_POSITIONS_DETECTED | instance=%s magic_type=%s count=%d tickets=%s",
                       instance_tag, magic_type, count, ticket_str);
}

string V2_OrphanMagicTypeLabel(const int entry_count, const int exit_count)
{
   if(entry_count > 0 && exit_count > 0)
      return "both";
   if(exit_count > 0)
      return "exit";
   if(entry_count > 0)
      return "entry";
   return "";
}

int V2_OnInitResultFromOrphanFlags(const bool long_orphan, const bool short_orphan)
{
   if(long_orphan && short_orphan)
      return INIT_FAILED;
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Test helpers — lightweight mock stacks (no PositionsTotal).       |
//+------------------------------------------------------------------+
struct V2MockStack
{
   double entries[];
   double last_exit_price;
   bool   last_exit_valid;
   double current_add_pips;
};

void V2MockReset(V2MockStack &s)
{
   ArrayResize(s.entries, 0);
   s.last_exit_price = 0.0;
   s.last_exit_valid = false;
   s.current_add_pips = V2_ADD_PIPS_FLOOR;
}

void V2MockPopTop(V2MockStack &s)
{
   int n = ArraySize(s.entries);
   if(n <= 0)
      return;

   s.last_exit_price = s.entries[n - 1];
   s.last_exit_valid = true;
   ArrayResize(s.entries, n - 1);
   V2_OnOwnStackFlat(s.last_exit_valid, ArraySize(s.entries));
   V2_ResetAddPipsOnFlat(s.current_add_pips, ArraySize(s.entries));
}

void V2MockAppendEntry(V2MockStack &s, const double price, const bool is_reload)
{
   int n = ArraySize(s.entries);
   ArrayResize(s.entries, n + 1);
   s.entries[n] = price;
   if(is_reload)
      s.last_exit_valid = false;
   V2_AdvanceAddPipsOnAppend(s.current_add_pips, ArraySize(s.entries));
}

double V2MockComputeAddStepPips(const V2MockStack &s)
{
   if(s.last_exit_valid)
      return V2_ADD_PIPS_FLOOR;
   int depth_before = ArraySize(s.entries);
   if(depth_before <= 0)
      return 0.0;
   return V2_AddStepPipsForDepth(depth_before, s.current_add_pips);
}

//+------------------------------------------------------------------+
//| CloseBy queue test helpers (no OrderSend).                        |
//+------------------------------------------------------------------+
void V2TestQueueCloseBy(V2CloseByTask &queue[],
                        const ulong ticket1,
                        const ulong ticket2)
{
   int idx = ArraySize(queue);
   ArrayResize(queue, idx + 1);
   queue[idx].ticket1      = ticket1;
   queue[idx].ticket2      = ticket2;
   queue[idx].retries      = 0;
   queue[idx].last_retcode = 0;
}

int V2TestCloseByQueueSize(const V2CloseByTask &queue[])
{
   return ArraySize(queue);
}

//+------------------------------------------------------------------+
//| ADR-017 flat L0 spatial deadband (V1 FXMatrix.mq5 parity).        |
//| QuoteSpread * 0.25 - 0.5 * _Point — L0 requote only, not add/reload.|
//| Optional pair_spread_pips_ref scales width vs GBPUSD anchor (0.64). |
//+------------------------------------------------------------------+
#define V2_L0_DEADBAND_VOL_REF_PIPS 0.64

double V2_L0RequoteDeadband(const double quote_spread,
                            const double multiplier = 1.0,
                            const double pair_spread_pips_ref = 0.0)
{
   double db = multiplier * (quote_spread * 0.25 - 0.5 * _Point);
   if(pair_spread_pips_ref > 0.0)
      db *= (pair_spread_pips_ref / V2_L0_DEADBAND_VOL_REF_PIPS);
   return db;
}

double V2_GetPendingOrderPrice(const ulong ticket)
{
   if(ticket == 0 || !OrderSelect(ticket))
      return -1.0;
   return OrderGetDouble(ORDER_PRICE_OPEN);
}

bool V2_L0RestingWithinDeadband(const ulong resting_ticket,
                                const double new_price,
                                const double quote_spread,
                                const double multiplier = 1.0,
                                const double pair_spread_pips_ref = 0.0)
{
   if(resting_ticket == 0)
      return false;
   const double current = V2_GetPendingOrderPrice(resting_ticket);
   if(current <= 0.0)
      return false;
   const double deadband = V2_L0RequoteDeadband(quote_spread, multiplier, pair_spread_pips_ref);
   return (MathAbs(new_price - current) < deadband);
}

#endif // FXMATRIX_V2_LOGIC_MQH
