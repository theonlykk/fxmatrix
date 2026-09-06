//+------------------------------------------------------------------+
//| grind_recon.mqh — comment-only book rebuild (Spec B, no history) |
//+------------------------------------------------------------------+
#ifndef GRIND_RECON_MQH
#define GRIND_RECON_MQH

#include "grind_state.mqh"
#include "grind_comment.mqh"
#include "grind_pure.mqh"
#include "grind_telemetry.mqh"

#define GRIND_RECON_TICKET_POSITION 0
#define GRIND_RECON_TICKET_ORDER    1

struct GrindReconTicket
{
   ulong  ticket;
   ulong  magic;
   string comment;
   double price;
   int    kind;
};

struct GrindReconLayerScratch
{
   bool     has_position;
   double   entry_price;
   ulong    position_id;
   bool     has_exit;
   double   exit_target;
   ulong    exit_order_ticket;
   int      layer_index;
};

// Set by fxgrind OnInit before Grind_ReconstructState().
ulong  g_grind_recon_magic = 0;
string g_grind_recon_slot = "";
double g_grind_recon_exit_pips = 0.0;
int    g_grind_recon_max_layers = 0;
string g_grind_halt_reason = "";
bool   g_grind_last_invariant_ok = true;
bool   g_grind_recon_ok = false;

//+------------------------------------------------------------------+
void Grind_ReconResetSide(GrindSideState &side)
{
   ArrayResize(side.layers, 0);
   side.l0_pending_ticket = 0;
   side.add_pending_ticket = 0;
   side.cap_warn_emitted = false;
}

//+------------------------------------------------------------------+
void Grind_ReconResetCounters()
{
   g_grind_fill_count = 0;
   g_grind_scalp_count = 0;
}

//+------------------------------------------------------------------+
bool Grind_ReconFindLayerIdx(const int &layer_indices[],
                             const int count,
                             const int layer_index,
                             int &idx_out)
{
   for(int i = 0; i < count; i++) {
      if(layer_indices[i] == layer_index) {
         idx_out = i;
         return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
bool Grind_ReconEnsureLayer(GrindReconLayerScratch &layers[],
                            int &layer_indices[],
                            int &layer_count,
                            const int layer_index,
                            int &idx_out)
{
   if(Grind_ReconFindLayerIdx(layer_indices, layer_count, layer_index, idx_out))
      return true;

   idx_out = layer_count;
   const int new_size = layer_count + 1;

   ResetLastError();
   if(ArrayResize(layer_indices, new_size, 20) < 0) {
      PrintFormat("FATAL: ArrayResize failed for layer_indices, Error: %d",
                  GetLastError());
      return false;
   }

   ResetLastError();
   if(ArrayResize(layers, new_size, 20) < 0) {
      PrintFormat("FATAL: ArrayResize failed for layers scratch, Error: %d",
                  GetLastError());
      return false;
   }

   layer_indices[layer_count] = layer_index;
   layers[layer_count].layer_index = layer_index;
   layers[layer_count].has_position = false;
   layers[layer_count].has_exit = false;
   layers[layer_count].entry_price = 0.0;
   layers[layer_count].exit_target = 0.0;
   layers[layer_count].position_id = 0;
   layers[layer_count].exit_order_ticket = 0;
   layer_count++;
   return true;
}

//+------------------------------------------------------------------+
bool Grind_ReconLayerIndicesContiguous(const int &layer_indices[], const int layer_count)
{
   if(layer_count == 0)
      return true;

   int sorted[];
   ArrayResize(sorted, layer_count);
   for(int i = 0; i < layer_count; i++)
      sorted[i] = layer_indices[i];

   for(int i = 0; i < layer_count - 1; i++) {
      for(int j = i + 1; j < layer_count; j++) {
         if(sorted[j] < sorted[i]) {
            const int tmp = sorted[i];
            sorted[i] = sorted[j];
            sorted[j] = tmp;
         }
      }
   }

   for(int i = 0; i < layer_count; i++) {
      if(sorted[i] != i)
         return false;
   }
   return true;
}

//+------------------------------------------------------------------+
bool Grind_ReconExitMatchesEntry(const double entry,
                                 const double exit_target,
                                 const double exit_pips,
                                 const double point,
                                 const bool is_long)
{
   const int dir = is_long ? 1 : -1;
   const double expected = Grind_ExitPrice(entry, exit_pips, point, dir);
   return (MathAbs(exit_target - expected) <= 2.0 * point);
}

//+------------------------------------------------------------------+
bool Grind_ReconCheckInvariants(const GrindReconLayerScratch &long_layers[],
                                const int long_count,
                                const GrindReconLayerScratch &short_layers[],
                                const int short_count,
                                const double exit_pips,
                                const double point,
                                const int max_layers,
                                string &reason_out)
{
   reason_out = "";

   if(long_count > max_layers) {
      reason_out = "I7_LONG_DEPTH";
      return false;
   }
   if(short_count > max_layers) {
      reason_out = "I7_SHORT_DEPTH";
      return false;
   }

   int long_indices[];
   int short_indices[];
   ArrayResize(long_indices, long_count);
   ArrayResize(short_indices, short_count);
   for(int i = 0; i < long_count; i++)
      long_indices[i] = long_layers[i].layer_index;
   for(int i = 0; i < short_count; i++)
      short_indices[i] = short_layers[i].layer_index;

   if(!Grind_ReconLayerIndicesContiguous(long_indices, long_count)) {
      reason_out = "I5_LONG_INDICES";
      return false;
   }
   if(!Grind_ReconLayerIndicesContiguous(short_indices, short_count)) {
      reason_out = "I5_SHORT_INDICES";
      return false;
   }

   for(int i = 0; i < long_count; i++) {
      if(!long_layers[i].has_position) {
         reason_out = "I3_LONG_NAKED";
         return false;
      }
      if(!long_layers[i].has_exit) {
         reason_out = "I3_LONG_NAKED";
         return false;
      }
      if(!Grind_ReconExitMatchesEntry(long_layers[i].entry_price,
                                     long_layers[i].exit_target,
                                     exit_pips, point, true)) {
         reason_out = "I6_LONG_EXIT";
         return false;
      }
   }

   for(int i = 0; i < short_count; i++) {
      if(!short_layers[i].has_position) {
         reason_out = "I3_SHORT_NAKED";
         return false;
      }
      if(!short_layers[i].has_exit) {
         reason_out = "I3_SHORT_NAKED";
         return false;
      }
      if(!Grind_ReconExitMatchesEntry(short_layers[i].entry_price,
                                     short_layers[i].exit_target,
                                     exit_pips, point, false)) {
         reason_out = "I6_SHORT_EXIT";
         return false;
      }
   }

   for(int i = 0; i < long_count; i++) {
      int exit_count = 0;
      for(int j = 0; j < long_count; j++) {
         if(long_layers[j].has_exit
            && long_layers[j].exit_order_ticket == long_layers[i].exit_order_ticket)
            exit_count++;
      }
      if(exit_count != 1) {
         reason_out = "I1_LONG_EXIT_COUNT";
         return false;
      }
   }

   for(int i = 0; i < short_count; i++) {
      int exit_count = 0;
      for(int j = 0; j < short_count; j++) {
         if(short_layers[j].has_exit
            && short_layers[j].exit_order_ticket == short_layers[i].exit_order_ticket)
            exit_count++;
      }
      if(exit_count != 1) {
         reason_out = "I1_SHORT_EXIT_COUNT";
         return false;
      }
   }

   return true;
}

//+------------------------------------------------------------------+
bool Grind_RebuildBookFromTickets(const GrindReconTicket &tickets[],
                                  const int ticket_count,
                                  const ulong magic,
                                  const string slot,
                                  const double exit_pips,
                                  const int max_layers,
                                  const double point,
                                  GrindSideState &long_out,
                                  GrindSideState &short_out,
                                  string &reason_out)
{
   reason_out = "";
   Grind_ReconResetSide(long_out);
   Grind_ReconResetSide(short_out);

   GrindReconLayerScratch long_scratch[];
   GrindReconLayerScratch short_scratch[];
   int long_indices[];
   int short_indices[];
   int long_count = 0;
   int short_count = 0;

   for(int i = 0; i < ticket_count; i++) {
      if(tickets[i].magic != magic)
         continue;

      string c_slot, c_side, c_role;
      int c_layer;
      if(!GrindCommentParse(tickets[i].comment, c_slot, c_side, c_layer, c_role)) {
         reason_out = "UNPARSEABLE_COMMENT";
         return false;
      }

      const bool is_long = (c_side == "L");

      if(c_role == "ENT" && tickets[i].kind == GRIND_RECON_TICKET_POSITION) {
         int idx = -1;
         if(is_long) {
            if(!Grind_ReconEnsureLayer(long_scratch, long_indices, long_count, c_layer, idx))
               return false;
            if(long_scratch[idx].has_position) {
               reason_out = "I5_LONG_DUP";
               return false;
            }
            long_scratch[idx].has_position = true;
            long_scratch[idx].entry_price = tickets[i].price;
            long_scratch[idx].position_id = tickets[i].ticket;
         } else {
            if(!Grind_ReconEnsureLayer(short_scratch, short_indices, short_count, c_layer, idx))
               return false;
            if(short_scratch[idx].has_position) {
               reason_out = "I5_SHORT_DUP";
               return false;
            }
            short_scratch[idx].has_position = true;
            short_scratch[idx].entry_price = tickets[i].price;
            short_scratch[idx].position_id = tickets[i].ticket;
         }
         continue;
      }

      if(c_role == "EXT" && tickets[i].kind == GRIND_RECON_TICKET_ORDER) {
         int idx = -1;
         if(is_long) {
            if(!Grind_ReconEnsureLayer(long_scratch, long_indices, long_count, c_layer, idx))
               return false;
            if(long_scratch[idx].has_exit) {
               reason_out = "I2_LONG_EXIT_DUP";
               return false;
            }
            long_scratch[idx].has_exit = true;
            long_scratch[idx].exit_target = tickets[i].price;
            long_scratch[idx].exit_order_ticket = tickets[i].ticket;
         } else {
            if(!Grind_ReconEnsureLayer(short_scratch, short_indices, short_count, c_layer, idx))
               return false;
            if(short_scratch[idx].has_exit) {
               reason_out = "I2_SHORT_EXIT_DUP";
               return false;
            }
            short_scratch[idx].has_exit = true;
            short_scratch[idx].exit_target = tickets[i].price;
            short_scratch[idx].exit_order_ticket = tickets[i].ticket;
         }
         continue;
      }

      if(c_role == "ENT" && tickets[i].kind == GRIND_RECON_TICKET_ORDER) {
         if(c_layer == 0) {
            if(is_long) {
               if(long_out.l0_pending_ticket != 0) {
                  reason_out = "AMBIGUOUS_L0_LONG";
                  return false;
               }
               long_out.l0_pending_ticket = tickets[i].ticket;
            } else {
               if(short_out.l0_pending_ticket != 0) {
                  reason_out = "AMBIGUOUS_L0_SHORT";
                  return false;
               }
               short_out.l0_pending_ticket = tickets[i].ticket;
            }
         } else {
            if(is_long) {
               if(long_out.add_pending_ticket != 0) {
                  reason_out = "AMBIGUOUS_ADD_LONG";
                  return false;
               }
               long_out.add_pending_ticket = tickets[i].ticket;
            } else {
               if(short_out.add_pending_ticket != 0) {
                  reason_out = "AMBIGUOUS_ADD_SHORT";
                  return false;
               }
               short_out.add_pending_ticket = tickets[i].ticket;
            }
         }
         continue;
      }
   }

   for(int i = 0; i < long_count; i++) {
      if(long_scratch[i].has_position && !long_scratch[i].has_exit) {
         reason_out = "I3_LONG_NAKED";
         return false;
      }
      if(!long_scratch[i].has_position && long_scratch[i].has_exit) {
         reason_out = "I4_LONG_ORPHAN_EXIT";
         return false;
      }
   }
   for(int i = 0; i < short_count; i++) {
      if(short_scratch[i].has_position && !short_scratch[i].has_exit) {
         reason_out = "I3_SHORT_NAKED";
         return false;
      }
      if(!short_scratch[i].has_position && short_scratch[i].has_exit) {
         reason_out = "I4_SHORT_ORPHAN_EXIT";
         return false;
      }
   }

   if(!Grind_ReconCheckInvariants(long_scratch, long_count,
                                 short_scratch, short_count,
                                 exit_pips, point, max_layers, reason_out))
      return false;

   for(int i = 0; i < long_count; i++) {
      int idx = -1;
      for(int j = 0; j < long_count; j++) {
         if(long_scratch[j].layer_index == i) {
            idx = j;
            break;
         }
      }
      if(idx < 0)
         continue;

      const int n = ArraySize(long_out.layers);
      ArrayResize(long_out.layers, n + 1);
      long_out.layers[n].entry_price = long_scratch[idx].entry_price;
      long_out.layers[n].exit_target = long_scratch[idx].exit_target;
      long_out.layers[n].position_ticket = long_scratch[idx].position_id;
      long_out.layers[n].exit_order_ticket = long_scratch[idx].exit_order_ticket;
      long_out.layers[n].layer_index = long_scratch[idx].layer_index;
   }

   for(int i = 0; i < short_count; i++) {
      int idx = -1;
      for(int j = 0; j < short_count; j++) {
         if(short_scratch[j].layer_index == i) {
            idx = j;
            break;
         }
      }
      if(idx < 0)
         continue;

      const int n = ArraySize(short_out.layers);
      ArrayResize(short_out.layers, n + 1);
      short_out.layers[n].entry_price = short_scratch[idx].entry_price;
      short_out.layers[n].exit_target = short_scratch[idx].exit_target;
      short_out.layers[n].position_ticket = short_scratch[idx].position_id;
      short_out.layers[n].exit_order_ticket = short_scratch[idx].exit_order_ticket;
      short_out.layers[n].layer_index = short_scratch[idx].layer_index;
   }

   return true;
}

//+------------------------------------------------------------------+
int Grind_ReconCollectBrokerTickets(GrindReconTicket &tickets[])
{
   int count = 0;

   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if(!Grind_MagicMatches(PositionGetInteger(POSITION_MAGIC), g_grind_recon_magic))
         continue;

      ArrayResize(tickets, count + 1);
      tickets[count].ticket = (ulong)PositionGetInteger(POSITION_IDENTIFIER);
      tickets[count].magic = g_grind_recon_magic;
      tickets[count].comment = PositionGetString(POSITION_COMMENT);
      tickets[count].price = PositionGetDouble(POSITION_PRICE_OPEN);
      tickets[count].kind = GRIND_RECON_TICKET_POSITION;
      count++;
   }

   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if(!Grind_MagicMatches(OrderGetInteger(ORDER_MAGIC), g_grind_recon_magic))
         continue;

      ArrayResize(tickets, count + 1);
      tickets[count].ticket = ticket;
      tickets[count].magic = g_grind_recon_magic;
      tickets[count].comment = OrderGetString(ORDER_COMMENT);
      tickets[count].price = OrderGetDouble(ORDER_PRICE_OPEN);
      tickets[count].kind = GRIND_RECON_TICKET_ORDER;
      count++;
   }

   return count;
}

//+------------------------------------------------------------------+
bool Grind_CheckBookInvariants()
{
   GrindReconTicket tickets[];
   const int count = Grind_ReconCollectBrokerTickets(tickets);
   GrindSideState long_tmp;
   GrindSideState short_tmp;
   string reason = "";

   const bool ok = Grind_RebuildBookFromTickets(tickets, count,
                                                g_grind_recon_magic,
                                                g_grind_recon_slot,
                                                g_grind_recon_exit_pips,
                                                g_grind_recon_max_layers,
                                                _Point,
                                                long_tmp, short_tmp, reason);
   g_grind_last_invariant_ok = ok;
   if(!ok)
      g_grind_halt_reason = reason;
   return ok;
}

//+------------------------------------------------------------------+
bool Grind_ReconstructState()
{
   g_grind_halt_reason = "";
   Grind_ReconResetSide(g_grind_long);
   Grind_ReconResetSide(g_grind_short);
   Grind_ReconResetCounters();

   GrindReconTicket tickets[];
   const int count = Grind_ReconCollectBrokerTickets(tickets);
   string reason = "";

   const bool ok = Grind_RebuildBookFromTickets(tickets, count,
                                                g_grind_recon_magic,
                                                g_grind_recon_slot,
                                                g_grind_recon_exit_pips,
                                                g_grind_recon_max_layers,
                                                _Point,
                                                g_grind_long,
                                                g_grind_short,
                                                reason);
   g_grind_recon_ok = ok;
   g_grind_last_invariant_ok = ok;

   if(!ok) {
      g_grind_halted = true;
      g_grind_halt_reason = reason;
      Grind_TelemetryCritical(g_grind_telemetry_instance, "RECON_FAIL", reason);
      return false;
   }

   return true;
}

#endif // GRIND_RECON_MQH
