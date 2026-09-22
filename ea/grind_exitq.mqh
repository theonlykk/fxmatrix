//+------------------------------------------------------------------+
//| grind_exitq.mqh — ADR-151 exit queue ranks, slot guard, fleet lock |
//+------------------------------------------------------------------+
#ifndef GRIND_EXITQ_MQH
#define GRIND_EXITQ_MQH

#include "grind_config.mqh"
#include "grind_cap.mqh"
#include "grind_comment.mqh"
#include "grind_carry.mqh"

// Market readers live in grind_engine.mqh (included before this file there).
// Forward declarations keep this header free of grind_engine (no circular include).
double Grind_MarketBid();
double Grind_MarketAsk();
long   Grind_MarketStopsLevel();
long   Grind_MarketFreezeLevel();

bool g_grind_ent_sent_this_tick = false;

bool g_grind_slot_test_active = false;
long g_grind_slot_test_limit = 0;
int  g_grind_slot_test_used = 0;
int  g_grind_slot_test_resting_ent = 0;
int  g_grind_slot_test_delta = 0;

bool Grind_OrderTestActive();
int  Grind_OrderTestRestingEntFleetCount();
bool Grind_PositionTestExistsAnyMagic(const ulong ticket);

int g_grind_exitq_test_k = -1;
int g_grind_slot_near_reserve = 0;

//+------------------------------------------------------------------+
int Grind_ExitQK()
{
   if(g_grind_exitq_test_k >= 0)
      return g_grind_exitq_test_k;
   return GRIND_EXITQ_K;
}

//+------------------------------------------------------------------+
bool Grind_ExitQRequired(const int rank, const int depth)
{
   if(rank < 0 || depth <= 0)
      return false;
   if(rank < Grind_ExitQK())
      return true;
   return (rank == depth - 1);
}

//+------------------------------------------------------------------+
bool Grind_ExitQAllowed(const int rank, const int depth)
{
   if(rank < 0 || depth <= 0)
      return false;
   if(rank < Grind_ExitQK() + GRIND_EXITQ_H)
      return true;
   return (rank == depth - 1);
}

//+------------------------------------------------------------------+
bool Grind_ExitQEntryBeats(const double entry_a,
                           const int layer_a,
                           const double entry_b,
                           const int layer_b,
                           const bool is_long)
{
   if(is_long) {
      if(entry_a < entry_b - GRIND_PRICE_EPS)
         return true;
      if(entry_b < entry_a - GRIND_PRICE_EPS)
         return false;
   } else {
      if(entry_a > entry_b + GRIND_PRICE_EPS)
         return true;
      if(entry_b > entry_a + GRIND_PRICE_EPS)
         return false;
   }
   return (layer_a < layer_b);
}

//+------------------------------------------------------------------+
void Grind_ExitQRanks(const double &entries[],
                      const int &layer_indices[],
                      const int n,
                      const bool is_long,
                      int &ranks_out[])
{
   ArrayResize(ranks_out, n);
   for(int i = 0; i < n; i++) {
      int rank = 0;
      for(int j = 0; j < n; j++) {
         if(j == i)
            continue;
         if(Grind_ExitQEntryBeats(entries[j], layer_indices[j],
                                  entries[i], layer_indices[i], is_long))
            rank++;
      }
      ranks_out[i] = rank;
   }
}

//+------------------------------------------------------------------+
bool Grind_IsFleetMagic(const long magic)
{
   for(int i = 0; i < GRIND_CAP_MAGIC_COUNT; i++) {
      if((long)GRIND_CAP_ALL_MAGICS[i] == magic)
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
long Grind_SlotAccountLimit()
{
   if(g_grind_slot_test_active)
      return g_grind_slot_test_limit;
   if(Grind_OrderTestActive())
      return 0;
   return AccountInfoInteger(ACCOUNT_LIMIT_ORDERS);
}

//+------------------------------------------------------------------+
int Grind_SlotUsed()
{
   if(g_grind_slot_test_active)
      return g_grind_slot_test_used + g_grind_slot_test_delta;
   if(Grind_OrderTestActive())
      return 0;
   return PositionsTotal() + OrdersTotal();
}

//+------------------------------------------------------------------+
int Grind_SlotRestingEnt()
{
   if(g_grind_slot_test_active)
      return g_grind_slot_test_resting_ent;
   if(Grind_OrderTestActive())
      return Grind_OrderTestRestingEntFleetCount();

   int resting_ent = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;

      const long magic = OrderGetInteger(ORDER_MAGIC);
      if(!Grind_IsFleetMagic(magic))
         continue;

      string slot, side, role;
      int layer_index;
      const string comment = OrderGetString(ORDER_COMMENT);
      if(GrindCommentParse(comment, slot, side, layer_index, role)) {
         if(role == "EXT")
            continue;
      }
      resting_ent++;
   }
   return resting_ent;
}

//+------------------------------------------------------------------+
bool Grind_SlotExitAllowed(const long limit, const int used)
{
   if(limit <= 0)
      return true;
   return ((long)used <= limit - 1);
}

//+------------------------------------------------------------------+
bool Grind_SlotEntryAllowed(const long limit,
                            const int used,
                            const int resting_ent,
                            const bool near_market)
{
   if(limit <= 0)
      return true;
   const long reserve = near_market ? 0 : (long)g_grind_slot_near_reserve;
   const long needed = 2 + GRIND_SLOT_MARGIN + reserve;
   return ((long)(used + resting_ent) <= limit - needed);
}

//+------------------------------------------------------------------+
bool Grind_SlotEntryAllowed(const long limit, const int used, const int resting_ent)
{
   return Grind_SlotEntryAllowed(limit, used, resting_ent, true);
}

//+------------------------------------------------------------------+
bool Grind_SlotLockTryAcquire(double &token_out)
{
   GlobalVariableTemp(GRIND_SLOT_LOCK_GV);
   double now = (double)GetTickCount64();
   if(now == 0.0)
      now = 1.0;
   if(GlobalVariableSetOnCondition(GRIND_SLOT_LOCK_GV, now, 0.0)) {
      token_out = now;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
bool Grind_SlotLockAcquire(double &token_out)
{
   GlobalVariableTemp(GRIND_SLOT_LOCK_GV);
   for(int attempt = 0; attempt < GRIND_SLOT_LOCK_MAX_RETRIES; attempt++) {
      double now = (double)GetTickCount64();
      if(now == 0.0)
         now = 1.0;

      if(GlobalVariableSetOnCondition(GRIND_SLOT_LOCK_GV, now, 0.0)) {
         token_out = now;
         return true;
      }

      const double held = GlobalVariableGet(GRIND_SLOT_LOCK_GV);
      if(held > 0.0 && now - held > (double)GRIND_SLOT_LOCK_STALE_MS) {
         if(GlobalVariableSetOnCondition(GRIND_SLOT_LOCK_GV, now, held)) {
            Print("WARN SLOT_LOCK_STOLEN ", GRIND_SLOT_LOCK_GV,
                  " stale_ms=", (long)(now - held));
            token_out = now;
            return true;
         }
      }

      Sleep(1);
   }
   return false;
}

//+------------------------------------------------------------------+
void Grind_SlotLockRelease(const double token)
{
   GlobalVariableSetOnCondition(GRIND_SLOT_LOCK_GV, 0.0, token);
}

//+------------------------------------------------------------------+
double Grind_ExitQFormulaTarget(const double entry,
                                const double exit_pips,
                                const double point,
                                const bool is_long,
                                const ulong position_ticket)
{
   const double accrued = (position_ticket > 0)
                          ? Grind_CarryAccruedGet(position_ticket)
                          : 0.0;
   const double eject_offset = (position_ticket > 0)
                               ? Grind_EjectOffsetGet(position_ticket)
                               : 0.0;
   return Grind_ExitPrice(entry, exit_pips, point, is_long ? 1 : -1) + accrued + eject_offset;
}

//+------------------------------------------------------------------+
bool Grind_ExitQClampPassive(const bool is_long,
                             const double target,
                             double &price_out)
{
   const double bid = Grind_MarketBid();
   const double ask = Grind_MarketAsk();
   const double point = _Point;
   const long stops = Grind_MarketStopsLevel();
   const long freeze = Grind_MarketFreezeLevel();

   if(is_long)
      return Grind_CarryClampLongExit(target, bid, ask, point, stops, freeze, price_out);
   return Grind_CarryClampShortExit(target, bid, ask, point, stops, freeze, price_out);
}

//+------------------------------------------------------------------+
string Grind_CarryReleaseGvName(const ulong position_ticket)
{
   return GRIND_CARRY_RELEASE_PREFIX + IntegerToString((long)position_ticket);
}

#endif // GRIND_EXITQ_MQH
