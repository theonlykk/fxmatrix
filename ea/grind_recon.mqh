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
#include "grind_archive.mqh"

// Set by fxgrind OnInit before Grind_ReconstructState() — declared before closeby include.
ulong  g_grind_recon_magic = 0;
string g_grind_recon_slot = "";
double g_grind_recon_exit_pips = 0.0;
int    g_grind_recon_max_layers = 0;
string g_grind_halt_reason = "";
string g_grind_invariant_reason = "";
string g_grind_invariant_detail = "";
ulong  g_grind_invariant_marker_ticket = 0;
bool   g_grind_last_invariant_ok = true;
bool   g_grind_recon_ok = false;
bool   g_grind_recon_verbose = false;
int    g_grind_recon_exit_shortfall_long = 0;
int    g_grind_recon_exit_shortfall_short = 0;

#include "grind_closeby.mqh"
#include "grind_exitq.mqh"

#define GRIND_RECON_FAILURE_MAX_EMIT 40

void Grind_CancelOwnEntryOrders(const ulong magic, const string slot);

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

double Grind_CarryShiftGetForRecon(const ulong position_id);

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

//+------------------------------------------------------------------+
string Grind_InvariantJsonDouble(const double value, const int digits)
{
   return DoubleToString(value, digits);
}

//+------------------------------------------------------------------+
string Grind_InvariantJsonUlong(const ulong ticket)
{
   return IntegerToString((long)ticket);
}

//+------------------------------------------------------------------+
string Grind_InvariantJsonString(const string value)
{
   string out = "";
   for(int i = 0; i < StringLen(value); i++) {
      const ushort ch = StringGetCharacter(value, i);
      if(ch == '\\')
         out += "\\\\";
      else if(ch == '"')
         out += "\\\"";
      else
         out += ShortToString(ch);
   }
   return "\"" + out + "\"";
}

//+------------------------------------------------------------------+
int Grind_InvariantDiffPoints(const double diff, const double point)
{
   if(point <= 0.0)
      return 0;
   return (int)MathRound(diff / point);
}

//+------------------------------------------------------------------+
void Grind_InvariantDetailReset()
{
   g_grind_invariant_detail = "";
   g_grind_invariant_marker_ticket = 0;
}

//+------------------------------------------------------------------+
bool Grind_InvariantFail(string &reason_out,
                         const string reason,
                         const string detail,
                         const ulong marker_ticket = 0)
{
   reason_out = reason;
   g_grind_invariant_reason = reason;
   g_grind_invariant_detail = detail;
   g_grind_invariant_marker_ticket = marker_ticket;
   return false;
}

//+------------------------------------------------------------------+
string Grind_InvariantDetailI6(const GrindReconLayerScratch &layer,
                               const bool is_long,
                               const double exit_pips,
                               const double point,
                               const double carry_shift)
{
   const int dir = is_long ? 1 : -1;
   const double accrued = (layer.position_id > 0)
                          ? Grind_CarryAccruedGet(layer.position_id)
                          : 0.0;
   const double eject_offset = (layer.position_id > 0)
                               ? Grind_EjectOffsetGet(layer.position_id)
                               : 0.0;
   const double eff = Grind_EffectiveEntry(layer.entry_price, layer.position_id);
   const double expected = Grind_ExitPrice(eff, exit_pips, point, dir)
                           + accrued + eject_offset + carry_shift;
   const double diff = layer.exit_target - expected;
   string exit_is = "null";
   ulong exit_ticket = 0;
   if(layer.has_exit_position) {
      exit_is = "\"POSITION\"";
      exit_ticket = layer.exit_position_id;
   } else if(layer.has_exit_order) {
      exit_is = "\"ORDER\"";
      exit_ticket = layer.exit_order_ticket;
   }
   return StringFormat(
      "{\"layer_index\":%d,\"side\":\"%s\",\"entry\":%s,\"exit_target\":%s,"
      "\"expected\":%s,\"diff_points\":%d,\"tolerance_points\":2,"
      "\"accrued\":%s,\"eject_offset\":%s,"
      "\"carry_shift\":%s,\"exit_is\":%s,\"position_ticket\":%s,\"exit_ticket\":%s}",
      layer.layer_index,
      is_long ? "L" : "S",
      Grind_InvariantJsonDouble(layer.entry_price, 5),
      Grind_InvariantJsonDouble(layer.exit_target, 5),
      Grind_InvariantJsonDouble(expected, 5),
      Grind_InvariantDiffPoints(diff, point),
      Grind_InvariantJsonDouble(accrued, 5),
      Grind_InvariantJsonDouble(eject_offset, 5),
      Grind_InvariantJsonDouble(carry_shift, 5),
      exit_is,
      Grind_InvariantJsonUlong(layer.position_id),
      Grind_InvariantJsonUlong(exit_ticket));
}

//+------------------------------------------------------------------+
string Grind_InvariantDetailI3(const GrindReconLayerScratch &layer,
                               const bool is_long,
                               const string failed_test)
{
   string entry_json = "null";
   if(layer.has_position)
      entry_json = Grind_InvariantJsonDouble(layer.entry_price, 5);
   return StringFormat(
      "{\"layer_index\":%d,\"side\":\"%s\",\"entry\":%s,\"position_ticket\":%s,"
      "\"failed_test\":%s}",
      layer.layer_index,
      is_long ? "L" : "S",
      entry_json,
      Grind_InvariantJsonUlong(layer.position_id),
      Grind_InvariantJsonString(failed_test));
}

//+------------------------------------------------------------------+
string Grind_InvariantDetailI7(const bool is_long,
                               const int depth_found,
                               const int max_layers)
{
   return StringFormat("{\"side\":\"%s\",\"depth_found\":%d,\"max_layers\":%d}",
                       is_long ? "L" : "S", depth_found, max_layers);
}

//+------------------------------------------------------------------+
string Grind_InvariantDetailI5Corrupt(const bool is_long,
                                      const int &indices[],
                                      const int count)
{
   string arr = "[";
   for(int i = 0; i < count; i++) {
      if(i > 0)
         arr += ",";
      arr += IntegerToString(indices[i]);
   }
   arr += "]";
   return StringFormat("{\"side\":\"%s\",\"layer_indices\":%s}",
                       is_long ? "L" : "S", arr);
}

//+------------------------------------------------------------------+
string Grind_InvariantDetailI5Dup(const bool is_long,
                                  const int layer_index,
                                  const ulong existing_ticket,
                                  const ulong new_ticket)
{
   return StringFormat(
      "{\"side\":\"%s\",\"layer_index\":%d,\"existing_ticket\":%s,\"new_ticket\":%s}",
      is_long ? "L" : "S",
      layer_index,
      Grind_InvariantJsonUlong(existing_ticket),
      Grind_InvariantJsonUlong(new_ticket));
}

//+------------------------------------------------------------------+
string Grind_InvariantDetailI2Dup(const bool is_long,
                                  const int layer_index,
                                  const ulong incoming_ticket,
                                  const ulong held_ticket,
                                  const string dup_site)
{
   return StringFormat(
      "{\"layer_index\":%d,\"side\":\"%s\",\"incoming_ticket\":%s,"
      "\"held_ticket\":%s,\"dup_site\":%s}",
      layer_index,
      is_long ? "L" : "S",
      Grind_InvariantJsonUlong(incoming_ticket),
      Grind_InvariantJsonUlong(held_ticket),
      Grind_InvariantJsonString(dup_site));
}

//+------------------------------------------------------------------+
string Grind_InvariantDetailI1(const int layer_index,
                               const bool is_long,
                               const int exit_count)
{
   return StringFormat("{\"layer_index\":%d,\"side\":\"%s\",\"exit_count\":%d,\"expected\":1}",
                       layer_index, is_long ? "L" : "S", exit_count);
}

//+------------------------------------------------------------------+
string Grind_InvariantDetailI4(const int layer_index, const bool is_long)
{
   return StringFormat("{\"layer_index\":%d,\"side\":\"%s\",\"failed_test\":\"orphan_exit\"}",
                       layer_index, is_long ? "L" : "S");
}

//+------------------------------------------------------------------+
string Grind_InvariantDetailI8(const ulong pending_ticket, const string failure_kind)
{
   return StringFormat("{\"pending_add_ticket\":%s,\"failure_kind\":%s}",
                       Grind_InvariantJsonUlong(pending_ticket),
                       Grind_InvariantJsonString(failure_kind));
}

//+------------------------------------------------------------------+
void Grind_InvariantEmitArchive(const string reason)
{
   string archive_detail = "";
   if(g_grind_invariant_detail != "")
      archive_detail = "{\"info\":" + g_grind_invariant_detail + "}";
   Grind_ArchiveMarker("CRITICAL", "INVARIANT_FAIL", reason,
                       g_grind_invariant_marker_ticket, archive_detail);
}

//+------------------------------------------------------------------+
void Grind_ReconResetSide(GrindSideState &side)
{
   ArrayResize(side.layers, 0);
   side.l0_pending_ticket = 0;
   side.add_pending_ticket = 0;
   side.add_held = false;
   side.add_held_target = 0.0;
   side.entry_transitions_used = 0;
   side.add_gap_missed = 0;
   side.entry_transitions_exhausted = false;
   side.add_gap_beyond_target = false;
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
                                 const bool is_long,
                                 const double shift = 0.0,
                                 const bool exit_is_filled = false,
                                 const ulong position_id = 0)
{
   const int dir = is_long ? 1 : -1;
   const double accrued = (position_id > 0) ? Grind_CarryAccruedGet(position_id) : 0.0;
   const double eject_offset = (position_id > 0) ? Grind_EjectOffsetGet(position_id) : 0.0;
   const double eff = Grind_EffectiveEntry(entry, position_id);
   const double expected = Grind_ExitPrice(eff, exit_pips, point, dir) + accrued + eject_offset + shift;
   const double diff = exit_target - expected;
   if(exit_is_filled) {
      if(is_long && diff >= 0.0)
         return true;
      if(!is_long && diff <= 0.0)
         return true;
   }
   return (MathAbs(diff) <= 2.0 * point + GRIND_PRICE_EPS);
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
         return Grind_InvariantFail(reason_out, "I8_CORRUPT_PENDING_ADD",
                                    Grind_InvariantDetailI8(add_pending_ticket, "not_order"));
      }
      return true;
   }

   return Grind_InvariantFail(reason_out, "I8_CORRUPT_PENDING_ADD",
                              Grind_InvariantDetailI8(add_pending_ticket, "ticket_not_found"));
}

//+------------------------------------------------------------------+
void Grind_ReconComputeRanks(const GrindReconLayerScratch &layers[],
                             const int layer_count,
                             const bool is_long,
                             int &ranks_out[])
{
   ArrayResize(ranks_out, layer_count);
   int pos_count = 0;
   for(int i = 0; i < layer_count; i++) {
      if(layers[i].has_position)
         pos_count++;
   }
   if(pos_count == 0) {
      for(int i = 0; i < layer_count; i++)
         ranks_out[i] = 999;
      return;
   }

   double entries[];
   int indices[];
   int map_back[];
   ArrayResize(entries, pos_count);
   ArrayResize(indices, pos_count);
   ArrayResize(map_back, pos_count);
   int k = 0;
   for(int i = 0; i < layer_count; i++) {
      if(!layers[i].has_position)
         continue;
      entries[k] = Grind_EffectiveEntry(layers[i].entry_price, layers[i].position_id);
      indices[k] = layers[i].layer_index;
      map_back[k] = i;
      k++;
   }
   int sub_ranks[];
   Grind_ExitQRanks(entries, indices, pos_count, is_long, sub_ranks);
   for(int i = 0; i < layer_count; i++)
      ranks_out[i] = 999;
   for(int j = 0; j < pos_count; j++)
      ranks_out[map_back[j]] = sub_ranks[j];
}

//+------------------------------------------------------------------+
bool Grind_ReconCheckInvariants(const GrindReconLayerScratch &long_layers[],
                                const int long_count,
                                const int &long_ranks[],
                                const GrindReconLayerScratch &short_layers[],
                                const int short_count,
                                const int &short_ranks[],
                                const double exit_pips,
                                const double point,
                                const int max_layers,
                                string &reason_out,
                                const bool tolerate_exit_shortfall = false)
{
   reason_out = "";
   Grind_InvariantDetailReset();

   if(long_count > max_layers) {
      return Grind_InvariantFail(reason_out, "I7_LONG_DEPTH",
                                 Grind_InvariantDetailI7(true, long_count, max_layers));
   }
   if(short_count > max_layers) {
      return Grind_InvariantFail(reason_out, "I7_SHORT_DEPTH",
                                 Grind_InvariantDetailI7(false, short_count, max_layers));
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
      return Grind_InvariantFail(reason_out, "I5_LONG_CORRUPT_LAYER_INDICES",
                                 Grind_InvariantDetailI5Corrupt(true, long_indices, long_count));
   }
   if(!Grind_ReconLayerIndicesValid(short_indices, short_count)) {
      return Grind_InvariantFail(reason_out, "I5_SHORT_CORRUPT_LAYER_INDICES",
                                 Grind_InvariantDetailI5Corrupt(false, short_indices, short_count));
   }

   for(int i = 0; i < long_count; i++) {
      if(!long_layers[i].has_position) {
         return Grind_InvariantFail(reason_out, "I3_LONG_NAKED",
                                    Grind_InvariantDetailI3(long_layers[i], true, "no_position"));
      }
      const int long_rank = (i < ArraySize(long_ranks)) ? long_ranks[i] : 0;
      if(Grind_ExitQRequired(long_rank, long_count) && !Grind_ReconLayerHasExitCoverage(long_layers[i])) {
         if(tolerate_exit_shortfall)
            continue;
         return Grind_InvariantFail(reason_out, "I3_LONG_NAKED",
                                    Grind_InvariantDetailI3(long_layers[i], true, "no_exit_coverage"),
                                    long_layers[i].position_id);
      }
      if(!Grind_ReconLayerHasExitCoverage(long_layers[i]))
         continue;
      const double long_shift = Grind_CarryShiftGetForRecon(long_layers[i].position_id);
      const bool long_exit_filled = long_layers[i].has_exit_position;
      if(!Grind_ReconExitMatchesEntry(long_layers[i].entry_price,
                                     long_layers[i].exit_target,
                                     exit_pips, point, true, long_shift,
                                     long_exit_filled, long_layers[i].position_id)) {
         const string i6_reason = long_exit_filled ? "I6_LONG_EXIT_FILL_ADVERSE" : "I6_LONG_EXIT";
         return Grind_InvariantFail(reason_out, i6_reason,
                                    Grind_InvariantDetailI6(long_layers[i], true, exit_pips, point,
                                                            long_shift),
                                    long_layers[i].position_id);
      }
   }

   for(int i = 0; i < short_count; i++) {
      if(!short_layers[i].has_position) {
         return Grind_InvariantFail(reason_out, "I3_SHORT_NAKED",
                                    Grind_InvariantDetailI3(short_layers[i], false, "no_position"));
      }
      const int short_rank = (i < ArraySize(short_ranks)) ? short_ranks[i] : 0;
      if(Grind_ExitQRequired(short_rank, short_count) && !Grind_ReconLayerHasExitCoverage(short_layers[i])) {
         if(tolerate_exit_shortfall)
            continue;
         return Grind_InvariantFail(reason_out, "I3_SHORT_NAKED",
                                    Grind_InvariantDetailI3(short_layers[i], false,
                                                             "no_exit_coverage"),
                                    short_layers[i].position_id);
      }
      if(!Grind_ReconLayerHasExitCoverage(short_layers[i]))
         continue;
      const double short_shift = Grind_CarryShiftGetForRecon(short_layers[i].position_id);
      const bool short_exit_filled = short_layers[i].has_exit_position;
      if(!Grind_ReconExitMatchesEntry(short_layers[i].entry_price,
                                     short_layers[i].exit_target,
                                     exit_pips, point, false, short_shift,
                                     short_exit_filled, short_layers[i].position_id)) {
         const string i6_reason = short_exit_filled ? "I6_SHORT_EXIT_FILL_ADVERSE" : "I6_SHORT_EXIT";
         return Grind_InvariantFail(reason_out, i6_reason,
                                    Grind_InvariantDetailI6(short_layers[i], false, exit_pips, point,
                                                            short_shift),
                                    short_layers[i].position_id);
      }
   }

   for(int i = 0; i < long_count; i++) {
      if(!Grind_ReconLayerHasExitCoverage(long_layers[i]))
         continue;
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
         return Grind_InvariantFail(reason_out, "I1_LONG_EXIT_COUNT",
                                    Grind_InvariantDetailI1(long_layers[i].layer_index, true,
                                                            exit_count),
                                    long_layers[i].position_id);
      }
   }

   for(int i = 0; i < short_count; i++) {
      if(!Grind_ReconLayerHasExitCoverage(short_layers[i]))
         continue;
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
         return Grind_InvariantFail(reason_out, "I1_SHORT_EXIT_COUNT",
                                    Grind_InvariantDetailI1(short_layers[i].layer_index, false,
                                                            exit_count),
                                    short_layers[i].position_id);
      }
   }

   Grind_InvariantDetailReset();
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
                                       string &offending_comment_out,
                                       const bool tolerate_exit_shortfall = false)
{
   reason_out = "";
   offending_comment_out = "";
   g_grind_recon_exit_shortfall_long = 0;
   g_grind_recon_exit_shortfall_short = 0;
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
               offending_comment_out = tickets[i].comment;
               return Grind_InvariantFail(reason_out, "I5_LONG_DUP",
                                          Grind_InvariantDetailI5Dup(true, c_layer,
                                                                     long_scratch[idx].position_id,
                                                                     tickets[i].ticket),
                                          long_scratch[idx].position_id);
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
               offending_comment_out = tickets[i].comment;
               return Grind_InvariantFail(reason_out, "I5_SHORT_DUP",
                                          Grind_InvariantDetailI5Dup(false, c_layer,
                                                                     short_scratch[idx].position_id,
                                                                     tickets[i].ticket),
                                          short_scratch[idx].position_id);
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
               ulong held_ticket = 0;
               if(long_scratch[idx].has_exit_order)
                  held_ticket = long_scratch[idx].exit_order_ticket;
               else
                  held_ticket = long_scratch[idx].exit_position_id;
               return Grind_InvariantFail(reason_out, "I2_LONG_EXIT_DUP",
                                          Grind_InvariantDetailI2Dup(true, c_layer,
                                                                     tickets[i].ticket,
                                                                     held_ticket,
                                                                     "order_scan"),
                                          long_scratch[idx].position_id);
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
               ulong held_ticket = 0;
               if(short_scratch[idx].has_exit_order)
                  held_ticket = short_scratch[idx].exit_order_ticket;
               else
                  held_ticket = short_scratch[idx].exit_position_id;
               return Grind_InvariantFail(reason_out, "I2_SHORT_EXIT_DUP",
                                          Grind_InvariantDetailI2Dup(false, c_layer,
                                                                     tickets[i].ticket,
                                                                     held_ticket,
                                                                     "order_scan"),
                                          short_scratch[idx].position_id);
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
               return Grind_InvariantFail(reason_out, "I2_LONG_EXIT_DUP",
                                          Grind_InvariantDetailI2Dup(true, c_layer,
                                                                     tickets[i].ticket,
                                                                     long_scratch[idx].exit_position_id,
                                                                     "position_scan"),
                                          long_scratch[idx].position_id);
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
               return Grind_InvariantFail(reason_out, "I2_SHORT_EXIT_DUP",
                                          Grind_InvariantDetailI2Dup(false, c_layer,
                                                                     tickets[i].ticket,
                                                                     short_scratch[idx].exit_position_id,
                                                                     "position_scan"),
                                          short_scratch[idx].position_id);
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

   int long_ranks[];
   int short_ranks[];
   Grind_ReconComputeRanks(long_scratch, long_count, true, long_ranks);
   Grind_ReconComputeRanks(short_scratch, short_count, false, short_ranks);

   for(int i = 0; i < long_count; i++) {
      const int rank = (i < ArraySize(long_ranks)) ? long_ranks[i] : 0;
      if(long_scratch[i].has_position &&
         Grind_ExitQRequired(rank, long_count) &&
         !Grind_ReconLayerHasExitCoverage(long_scratch[i])) {
         if(tolerate_exit_shortfall) {
            g_grind_recon_exit_shortfall_long++;
            continue;
         }
         offending_comment_out = Grind_ReconFailureFindTicketComment(
            tickets, ticket_count, long_scratch[i].position_id);
         return Grind_InvariantFail(reason_out, "I3_LONG_NAKED",
                                    Grind_InvariantDetailI3(long_scratch[i], true,
                                                            "no_exit_coverage"),
                                    long_scratch[i].position_id);
      }
      if(!long_scratch[i].has_position && Grind_ReconLayerHasExitCoverage(long_scratch[i])) {
         return Grind_InvariantFail(reason_out, "I4_LONG_ORPHAN_EXIT",
                                    Grind_InvariantDetailI4(long_scratch[i].layer_index, true));
      }
   }
   for(int i = 0; i < short_count; i++) {
      const int rank = (i < ArraySize(short_ranks)) ? short_ranks[i] : 0;
      if(short_scratch[i].has_position &&
         Grind_ExitQRequired(rank, short_count) &&
         !Grind_ReconLayerHasExitCoverage(short_scratch[i])) {
         if(tolerate_exit_shortfall) {
            g_grind_recon_exit_shortfall_short++;
            continue;
         }
         offending_comment_out = Grind_ReconFailureFindTicketComment(
            tickets, ticket_count, short_scratch[i].position_id);
         return Grind_InvariantFail(reason_out, "I3_SHORT_NAKED",
                                    Grind_InvariantDetailI3(short_scratch[i], false,
                                                            "no_exit_coverage"),
                                    short_scratch[i].position_id);
      }
      if(!short_scratch[i].has_position && Grind_ReconLayerHasExitCoverage(short_scratch[i])) {
         return Grind_InvariantFail(reason_out, "I4_SHORT_ORPHAN_EXIT",
                                    Grind_InvariantDetailI4(short_scratch[i].layer_index, false));
      }
   }

   if(!Grind_ReconCheckInvariants(long_scratch, long_count, long_ranks,
                                 short_scratch, short_count, short_ranks,
                                 exit_pips, point, max_layers, reason_out,
                                 tolerate_exit_shortfall)) {
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
      if(Grind_ReconLayerHasExitCoverage(long_scratch[j]))
         long_out.layers[n].exit_target = long_scratch[j].exit_target;
      else
         long_out.layers[n].exit_target =
            Grind_ExitQFormulaTarget(long_scratch[j].entry_price, exit_pips, point, true,
                                     long_scratch[j].position_id);
      long_out.layers[n].position_ticket = long_scratch[j].position_id;
      long_out.layers[n].exit_order_ticket = long_scratch[j].exit_order_ticket;
      long_out.layers[n].exit_position_ticket = long_scratch[j].exit_position_id;
      long_out.layers[n].layer_index = long_scratch[j].layer_index;
   }

   for(int j = 0; j < short_count; j++) {
      const int n = ArraySize(short_out.layers);
      ArrayResize(short_out.layers, n + 1);
      short_out.layers[n].entry_price = short_scratch[j].entry_price;
      if(Grind_ReconLayerHasExitCoverage(short_scratch[j]))
         short_out.layers[n].exit_target = short_scratch[j].exit_target;
      else
         short_out.layers[n].exit_target =
            Grind_ExitQFormulaTarget(short_scratch[j].entry_price, exit_pips, point, false,
                                     short_scratch[j].position_id);
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
                                  string &reason_out,
                                  const bool tolerate_exit_shortfall = false)
{
   string offending = "";
   const bool ok = Grind_RebuildBookFromTicketsInner(tickets, ticket_count,
                                                     magic, slot,
                                                     exit_pips, max_layers, point,
                                                     long_out, short_out,
                                                     reason_out, offending,
                                                     tolerate_exit_shortfall);
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
   if(!ok) {
      g_grind_invariant_reason = reason;
   } else {
      g_grind_invariant_reason = "";
      Grind_InvariantDetailReset();
   }
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
                                                reason,
                                                true);
   g_grind_recon_ok = ok;
   g_grind_last_invariant_ok = ok;

   if(!ok) {
      g_grind_halted = true;
      g_grind_halt_reason = reason;
      Grind_TelemetryCritical(g_grind_telemetry_instance, "RECON_FAIL", reason);
      Grind_CancelOwnEntryOrders(g_grind_recon_magic, g_grind_recon_slot);
      return false;
   }

   Grind_DeriveCloseByQueueFromBook(g_grind_recon_slot, g_grind_recon_verbose);
   return true;
}

#endif // GRIND_RECON_MQH
