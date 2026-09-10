//+------------------------------------------------------------------+
//| grind_recon.mqh — comment-only book rebuild (Spec B, no history) |
//+------------------------------------------------------------------+
#ifndef GRIND_RECON_MQH
#define GRIND_RECON_MQH

#include "grind_state.mqh"
#include "grind_comment.mqh"
#include "grind_pure.mqh"
#include "grind_recon_failure.mqh"
#include "grind_telemetry.mqh"
#include "grind_closeby.mqh"

#define GRIND_RECON_FAILURE_MAX_EMIT 40

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
   bool     has_exit_order;
   bool     has_exit_position;
   double   exit_target;
   ulong    exit_order_ticket;
   ulong    exit_position_id;
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
bool   g_grind_recon_verbose = false;

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
   layers[layer_count].has_exit_order = false;
   layers[layer_count].has_exit_position = false;
   layers[layer_count].entry_price = 0.0;
   layers[layer_count].exit_target = 0.0;
   layers[layer_count].position_id = 0;
   layers[layer_count].exit_order_ticket = 0;
   layers[layer_count].exit_position_id = 0;
   layer_count++;
   return true;
}

//+------------------------------------------------------------------+
bool Grind_ReconLayerIndicesValid(const int &layer_indices[], const int layer_count)
{
   for(int i = 0; i < layer_count; i++) {
      if(layer_indices[i] < 0)
         return false;
      for(int j = i + 1; j < layer_count; j++) {
         if(layer_indices[i] == layer_indices[j])
            return false;
      }
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
bool Grind_ReconLayerHasExitCoverage(const GrindReconLayerScratch &layer)
{
   return layer.has_exit_order || layer.has_exit_position;
}

//+------------------------------------------------------------------+
bool Grind_ReconCheckPendingAddCorrupt(const GrindReconTicket &tickets[],
                                       const int ticket_count,
                                       const ulong add_pending_ticket,
                                       string &reason_out)
{
   if(add_pending_ticket == 0)
      return true;

   for(int i = 0; i < ticket_count; i++) {
      if(tickets[i].ticket != add_pending_ticket)
         continue;
      if(tickets[i].kind != GRIND_RECON_TICKET_ORDER) {
         reason_out = "I8_CORRUPT_PENDING_ADD";
         return false;
      }
      return true;
   }

   reason_out = "I8_CORRUPT_PENDING_ADD";
   return false;
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

   if(!Grind_ReconLayerIndicesValid(long_indices, long_count)) {
      reason_out = "I5_LONG_CORRUPT_LAYER_INDICES";
      return false;
   }
   if(!Grind_ReconLayerIndicesValid(short_indices, short_count)) {
      reason_out = "I5_SHORT_CORRUPT_LAYER_INDICES";
      return false;
   }

   for(int i = 0; i < long_count; i++) {
      if(!long_layers[i].has_position) {
         reason_out = "I3_LONG_NAKED";
         return false;
      }
      if(!Grind_ReconLayerHasExitCoverage(long_layers[i])) {
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
      if(!Grind_ReconLayerHasExitCoverage(short_layers[i])) {
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
      if(long_layers[i].has_exit_order) {
         for(int j = 0; j < long_count; j++) {
            if(long_layers[j].has_exit_order
               && long_layers[j].exit_order_ticket == long_layers[i].exit_order_ticket)
               exit_count++;
         }
      } else if(long_layers[i].has_exit_position) {
         for(int j = 0; j < long_count; j++) {
            if(long_layers[j].has_exit_position
               && long_layers[j].exit_position_id == long_layers[i].exit_position_id)
               exit_count++;
         }
      }
      if(exit_count != 1) {
         reason_out = "I1_LONG_EXIT_COUNT";
         return false;
      }
   }

   for(int i = 0; i < short_count; i++) {
      int exit_count = 0;
      if(short_layers[i].has_exit_order) {
         for(int j = 0; j < short_count; j++) {
            if(short_layers[j].has_exit_order
               && short_layers[j].exit_order_ticket == short_layers[i].exit_order_ticket)
               exit_count++;
         }
      } else if(short_layers[i].has_exit_position) {
         for(int j = 0; j < short_count; j++) {
            if(short_layers[j].has_exit_position
               && short_layers[j].exit_position_id == short_layers[i].exit_position_id)
               exit_count++;
         }
      }
      if(exit_count != 1) {
         reason_out = "I1_SHORT_EXIT_COUNT";
         return false;
      }
   }

   return true;
}

//+------------------------------------------------------------------+
string Grind_ReconFailureJsonEscape(const string raw)
{
   string out = "";
   for(int i = 0; i < StringLen(raw); i++) {
      const ushort ch = StringGetCharacter(raw, i);
      if(ch == '\\')
         out += "\\\\";
      else if(ch == '"')
         out += "\\\"";
      else
         out += ShortToString(ch);
   }
   return out;
}

//+------------------------------------------------------------------+
string Grind_ReconFailureSideHintJson(const string comment)
{
   string slot = "";
   string side = "";
   string role = "";
   int layer = 0;
   if(!GrindCommentParse(comment, slot, side, layer, role))
      return "null";
   return "\"" + side + "\"";
}

//+------------------------------------------------------------------+
string Grind_ReconFailureKindLabel(const int kind)
{
   if(kind == GRIND_RECON_TICKET_POSITION)
      return "POSITION";
   return "ORDER";
}

//+------------------------------------------------------------------+
string Grind_ReconFailureFindTicketComment(const GrindReconTicket &tickets[],
                                           const int ticket_count,
                                           const ulong ticket_id)
{
   for(int i = 0; i < ticket_count; i++) {
      if(tickets[i].ticket == ticket_id)
         return tickets[i].comment;
   }
   return "";
}

//+------------------------------------------------------------------+
void Grind_ReconFailureCapture(const GrindReconTicket &tickets[],
                               const int ticket_count,
                               const string reason,
                               const string offending_comment = "")
{
   const int emit_count = MathMin(ticket_count, GRIND_RECON_FAILURE_MAX_EMIT);
   const bool truncated = (ticket_count > GRIND_RECON_FAILURE_MAX_EMIT);

   string json = StringFormat(
      "{\"reason\":\"%s\",\"ticket_count\":%d,\"truncated\":%s",
      Grind_ReconFailureJsonEscape(reason),
      ticket_count,
      truncated ? "true" : "false");

   if(offending_comment != "")
      json += StringFormat(",\"offending_comment\":\"%s\"",
                           Grind_ReconFailureJsonEscape(offending_comment));

   json += ",\"tickets\":[";
   for(int i = 0; i < emit_count; i++) {
      if(i > 0)
         json += ",";
      json += StringFormat(
         "{\"kind\":\"%s\",\"comment\":\"%s\",\"price\":%.5f,\"side_hint\":%s}",
         Grind_ReconFailureKindLabel(tickets[i].kind),
         Grind_ReconFailureJsonEscape(tickets[i].comment),
         tickets[i].price,
         Grind_ReconFailureSideHintJson(tickets[i].comment)
      );
   }
   json += "]}";

   g_grind_recon_failure_json = json;
}

//+------------------------------------------------------------------+
string Grind_ReconFailureOffendingForReason(const GrindReconTicket &tickets[],
                                            const int ticket_count,
                                            const string reason,
                                            const GrindReconLayerScratch &long_layers[],
                                            const int long_count,
                                            const GrindReconLayerScratch &short_layers[],
                                            const int short_count)
{
   if(reason == "I3_LONG_NAKED" || reason == "I6_LONG_EXIT") {
      for(int i = 0; i < long_count; i++) {
         if(!long_layers[i].has_position)
            continue;
         if(reason == "I3_LONG_NAKED" && Grind_ReconLayerHasExitCoverage(long_layers[i]))
            continue;
         const string found = Grind_ReconFailureFindTicketComment(
            tickets, ticket_count, long_layers[i].position_id);
         if(found != "")
            return found;
      }
   }

   if(reason == "I3_SHORT_NAKED" || reason == "I6_SHORT_EXIT") {
      for(int i = 0; i < short_count; i++) {
         if(!short_layers[i].has_position)
            continue;
         if(reason == "I3_SHORT_NAKED" && Grind_ReconLayerHasExitCoverage(short_layers[i]))
            continue;
         const string found = Grind_ReconFailureFindTicketComment(
            tickets, ticket_count, short_layers[i].position_id);
         if(found != "")
            return found;
      }
   }

   if(reason == "I4_LONG_ORPHAN_EXIT") {
      for(int i = 0; i < long_count; i++) {
         if(long_layers[i].has_position || !Grind_ReconLayerHasExitCoverage(long_layers[i]))
            continue;
         if(long_layers[i].has_exit_order)
            return Grind_ReconFailureFindTicketComment(
               tickets, ticket_count, long_layers[i].exit_order_ticket);
         return Grind_ReconFailureFindTicketComment(
            tickets, ticket_count, long_layers[i].exit_position_id);
      }
   }

   if(reason == "I4_SHORT_ORPHAN_EXIT") {
      for(int i = 0; i < short_count; i++) {
         if(short_layers[i].has_position || !Grind_ReconLayerHasExitCoverage(short_layers[i]))
            continue;
         if(short_layers[i].has_exit_order)
            return Grind_ReconFailureFindTicketComment(
               tickets, ticket_count, short_layers[i].exit_order_ticket);
         return Grind_ReconFailureFindTicketComment(
            tickets, ticket_count, short_layers[i].exit_position_id);
      }
   }

   return "";
}

//+------------------------------------------------------------------+
void Grind_ReconFailureMeasureWorstCase(const int ticket_count,
                                        int &json_chars_out)
{
   json_chars_out = 0;

   GrindReconTicket tickets[];
   ArrayResize(tickets, ticket_count);
   for(int i = 0; i < ticket_count; i++) {
      tickets[i].ticket = 10000UL + (ulong)i;
      tickets[i].magic = 22260101UL;
      tickets[i].comment = GrindCommentBuild("OPT", (i % 2 == 0 ? "L" : "S"), i % 12, "ENT");
      tickets[i].price = 1.25000 + i * 0.00001;
      tickets[i].kind = (i % 3 == 0 ? GRIND_RECON_TICKET_ORDER : GRIND_RECON_TICKET_POSITION);
   }

   Grind_ReconFailureCapture(tickets, ticket_count, "I3_LONG_NAKED",
                             GrindCommentBuild("OPT", "L", 0, "ENT"));
   json_chars_out = StringLen(g_grind_recon_failure_json);
   Grind_ReconFailureClear();
}

//+------------------------------------------------------------------+
void Grind_ReconFailureMeasureWorstCaseCombined(const int ticket_count,
                                                const int max_layers_cap,
                                                const int digits,
                                                const ulong magic,
                                                const string instance_name,
                                                int &recon_failure_chars_out,
                                                int &full_heartbeat_chars_out,
                                                int &journal_unsplit_chars_out,
                                                int &journal_scalar_line_chars_out,
                                                int &journal_detail_line_chars_out,
                                                bool &split_would_fire_out,
                                                string &full_json_out)
{
   recon_failure_chars_out = 0;
   full_heartbeat_chars_out = 0;
   journal_unsplit_chars_out = 0;
   journal_scalar_line_chars_out = 0;
   journal_detail_line_chars_out = 0;
   split_would_fire_out = false;
   full_json_out = "";

   GrindReconTicket tickets[];
   ArrayResize(tickets, ticket_count);
   for(int i = 0; i < ticket_count; i++) {
      tickets[i].ticket = 10000UL + (ulong)i;
      tickets[i].magic = magic;
      tickets[i].comment = GrindCommentBuild("OPT", (i % 2 == 0 ? "L" : "S"), i % 12, "ENT");
      tickets[i].price = 1.25000 + i * 0.00001;
      tickets[i].kind = (i % 3 == 0 ? GRIND_RECON_TICKET_ORDER : GRIND_RECON_TICKET_POSITION);
   }

   Grind_ReconFailureCapture(tickets, ticket_count, "I3_LONG_NAKED",
                             GrindCommentBuild("OPT", "L", 0, "ENT"));
   recon_failure_chars_out = StringLen(g_grind_recon_failure_json);

   int detail_chars = 0;
   string detail_json = "";
   Grind_HeartbeatMeasureWorstCasePayload(max_layers_cap, digits, magic,
                                          detail_chars, full_heartbeat_chars_out,
                                          detail_json, full_json_out);

   int journal_book_line_chars = 0;
   Grind_HeartbeatJournalSplitLineLengths(instance_name, full_json_out,
                                          journal_unsplit_chars_out,
                                          journal_scalar_line_chars_out,
                                          journal_detail_line_chars_out,
                                          split_would_fire_out,
                                          journal_book_line_chars);

   Grind_ReconFailureClear();
}

//+------------------------------------------------------------------+
bool Grind_RebuildBookFromTicketsInner(const GrindReconTicket &tickets[],
                                       const int ticket_count,
                                       const ulong magic,
                                       const string slot,
                                       const double exit_pips,
                                       const int max_layers,
                                       const double point,
                                       GrindSideState &long_out,
                                       GrindSideState &short_out,
                                       string &reason_out,
                                       string &offending_comment_out)
{
   reason_out = "";
   offending_comment_out = "";
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
         offending_comment_out = tickets[i].comment;
         return false;
      }
      if(c_slot != slot)
         continue;

      const bool is_long = (c_side == "L");

      if(c_role == "ENT" && tickets[i].kind == GRIND_RECON_TICKET_POSITION) {
         int idx = -1;
         if(is_long) {
            if(!Grind_ReconEnsureLayer(long_scratch, long_indices, long_count, c_layer, idx)) {
               reason_out = "FATAL_LAYER_RESIZE";
               return false;
            }
            if(long_scratch[idx].has_position) {
               reason_out = "I5_LONG_DUP";
               offending_comment_out = tickets[i].comment;
               return false;
            }
            long_scratch[idx].has_position = true;
            long_scratch[idx].entry_price = tickets[i].price;
            long_scratch[idx].position_id = tickets[i].ticket;
         } else {
            if(!Grind_ReconEnsureLayer(short_scratch, short_indices, short_count, c_layer, idx)) {
               reason_out = "FATAL_LAYER_RESIZE";
               return false;
            }
            if(short_scratch[idx].has_position) {
               reason_out = "I5_SHORT_DUP";
               offending_comment_out = tickets[i].comment;
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
            if(!Grind_ReconEnsureLayer(long_scratch, long_indices, long_count, c_layer, idx)) {
               reason_out = "FATAL_LAYER_RESIZE";
               return false;
            }
            if(long_scratch[idx].has_exit_order || long_scratch[idx].has_exit_position) {
               reason_out = "I2_LONG_EXIT_DUP";
               return false;
            }
            long_scratch[idx].has_exit_order = true;
            long_scratch[idx].exit_target = tickets[i].price;
            long_scratch[idx].exit_order_ticket = tickets[i].ticket;
         } else {
            if(!Grind_ReconEnsureLayer(short_scratch, short_indices, short_count, c_layer, idx)) {
               reason_out = "FATAL_LAYER_RESIZE";
               return false;
            }
            if(short_scratch[idx].has_exit_order || short_scratch[idx].has_exit_position) {
               reason_out = "I2_SHORT_EXIT_DUP";
               return false;
            }
            short_scratch[idx].has_exit_order = true;
            short_scratch[idx].exit_target = tickets[i].price;
            short_scratch[idx].exit_order_ticket = tickets[i].ticket;
         }
         continue;
      }

      if(c_role == "EXT" && tickets[i].kind == GRIND_RECON_TICKET_POSITION) {
         int idx = -1;
         if(is_long) {
            if(!Grind_ReconEnsureLayer(long_scratch, long_indices, long_count, c_layer, idx)) {
               reason_out = "FATAL_LAYER_RESIZE";
               return false;
            }
            if(long_scratch[idx].has_exit_position) {
               reason_out = "I2_LONG_EXIT_DUP";
               return false;
            }
            if(long_scratch[idx].has_exit_order) {
               long_scratch[idx].has_exit_order = false;
               long_scratch[idx].exit_order_ticket = 0;
            }
            long_scratch[idx].has_exit_position = true;
            long_scratch[idx].exit_target = tickets[i].price;
            long_scratch[idx].exit_position_id = tickets[i].ticket;
         } else {
            if(!Grind_ReconEnsureLayer(short_scratch, short_indices, short_count, c_layer, idx)) {
               reason_out = "FATAL_LAYER_RESIZE";
               return false;
            }
            if(short_scratch[idx].has_exit_position) {
               reason_out = "I2_SHORT_EXIT_DUP";
               return false;
            }
            if(short_scratch[idx].has_exit_order) {
               short_scratch[idx].has_exit_order = false;
               short_scratch[idx].exit_order_ticket = 0;
            }
            short_scratch[idx].has_exit_position = true;
            short_scratch[idx].exit_target = tickets[i].price;
            short_scratch[idx].exit_position_id = tickets[i].ticket;
         }
         continue;
      }

      if(c_role == "ENT" && tickets[i].kind == GRIND_RECON_TICKET_ORDER) {
         if(c_layer == 0) {
            if(is_long) {
               if(long_out.l0_pending_ticket != 0) {
                  reason_out = "AMBIGUOUS_L0_LONG";
                  offending_comment_out = tickets[i].comment;
                  return false;
               }
               long_out.l0_pending_ticket = tickets[i].ticket;
            } else {
               if(short_out.l0_pending_ticket != 0) {
                  reason_out = "AMBIGUOUS_L0_SHORT";
                  offending_comment_out = tickets[i].comment;
                  return false;
               }
               short_out.l0_pending_ticket = tickets[i].ticket;
            }
         } else {
            if(is_long) {
               if(long_out.add_pending_ticket != 0) {
                  reason_out = "AMBIGUOUS_ADD_LONG";
                  offending_comment_out = tickets[i].comment;
                  return false;
               }
               long_out.add_pending_ticket = tickets[i].ticket;
            } else {
               if(short_out.add_pending_ticket != 0) {
                  reason_out = "AMBIGUOUS_ADD_SHORT";
                  offending_comment_out = tickets[i].comment;
                  return false;
               }
               short_out.add_pending_ticket = tickets[i].ticket;
            }
         }
         continue;
      }
   }

   for(int i = 0; i < long_count; i++) {
      if(long_scratch[i].has_position && !Grind_ReconLayerHasExitCoverage(long_scratch[i])) {
         reason_out = "I3_LONG_NAKED";
         offending_comment_out = Grind_ReconFailureFindTicketComment(
            tickets, ticket_count, long_scratch[i].position_id);
         return false;
      }
      if(!long_scratch[i].has_position && Grind_ReconLayerHasExitCoverage(long_scratch[i])) {
         reason_out = "I4_LONG_ORPHAN_EXIT";
         return false;
      }
   }
   for(int i = 0; i < short_count; i++) {
      if(short_scratch[i].has_position && !Grind_ReconLayerHasExitCoverage(short_scratch[i])) {
         reason_out = "I3_SHORT_NAKED";
         offending_comment_out = Grind_ReconFailureFindTicketComment(
            tickets, ticket_count, short_scratch[i].position_id);
         return false;
      }
      if(!short_scratch[i].has_position && Grind_ReconLayerHasExitCoverage(short_scratch[i])) {
         reason_out = "I4_SHORT_ORPHAN_EXIT";
         return false;
      }
   }

   if(!Grind_ReconCheckInvariants(long_scratch, long_count,
                                 short_scratch, short_count,
                                 exit_pips, point, max_layers, reason_out)) {
      if(offending_comment_out == "")
         offending_comment_out = Grind_ReconFailureOffendingForReason(
            tickets, ticket_count, reason_out,
            long_scratch, long_count, short_scratch, short_count);
      return false;
   }

   if(!Grind_ReconCheckPendingAddCorrupt(tickets, ticket_count,
                                         long_out.add_pending_ticket,
                                         reason_out))
      return false;
   if(!Grind_ReconCheckPendingAddCorrupt(tickets, ticket_count,
                                         short_out.add_pending_ticket,
                                         reason_out))
      return false;

   for(int j = 0; j < long_count; j++) {
      const int n = ArraySize(long_out.layers);
      ArrayResize(long_out.layers, n + 1);
      long_out.layers[n].entry_price = long_scratch[j].entry_price;
      long_out.layers[n].exit_target = long_scratch[j].exit_target;
      long_out.layers[n].position_ticket = long_scratch[j].position_id;
      long_out.layers[n].exit_order_ticket = long_scratch[j].exit_order_ticket;
      long_out.layers[n].exit_position_ticket = long_scratch[j].exit_position_id;
      long_out.layers[n].layer_index = long_scratch[j].layer_index;
   }

   for(int j = 0; j < short_count; j++) {
      const int n = ArraySize(short_out.layers);
      ArrayResize(short_out.layers, n + 1);
      short_out.layers[n].entry_price = short_scratch[j].entry_price;
      short_out.layers[n].exit_target = short_scratch[j].exit_target;
      short_out.layers[n].position_ticket = short_scratch[j].position_id;
      short_out.layers[n].exit_order_ticket = short_scratch[j].exit_order_ticket;
      short_out.layers[n].exit_position_ticket = short_scratch[j].exit_position_id;
      short_out.layers[n].layer_index = short_scratch[j].layer_index;
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
   string offending = "";
   const bool ok = Grind_RebuildBookFromTicketsInner(tickets, ticket_count,
                                                     magic, slot,
                                                     exit_pips, max_layers, point,
                                                     long_out, short_out,
                                                     reason_out, offending);
   if(ok) {
      Grind_ReconFailureClear();
      return true;
   }

   Grind_ReconFailureCapture(tickets, ticket_count, reason_out, offending);
   return false;
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
   ArrayResize(g_grind_long_closeby_queue, 0);
   ArrayResize(g_grind_short_closeby_queue, 0);

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

   Grind_DeriveCloseByQueueFromBook(g_grind_recon_slot, g_grind_recon_verbose);
   return true;
}

#endif // GRIND_RECON_MQH
