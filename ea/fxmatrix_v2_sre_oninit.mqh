//+------------------------------------------------------------------+
//| fxmatrix_v2_sre_oninit.mqh — Phase B OnInit SRE orchestration     |
//| Spec: docs/architecture/STATE_RECONSTRUCTION_SPEC_DRAFT.md (v8) |
//| Calls Phase A pure logic only; does not modify it.               |
//+------------------------------------------------------------------+
#ifndef FXMATRIX_V2_SRE_ONINIT_MQH
#define FXMATRIX_V2_SRE_ONINIT_MQH

#include "fxmatrix_v2_state_reconstruction.mqh"
#include "fxmatrix_v2_exits.mqh"
#include "fxmatrix_v2_gbp_cap.mqh"
#include "fxmatrix_v2_eur_cap.mqh"

enum V2SRECapBridgeKind
{
   V2_SRE_CAP_BRIDGE_GBPUSD = 0,
   V2_SRE_CAP_BRIDGE_EURUSD = 1,
   V2_SRE_CAP_BRIDGE_EURGBP_DUAL = 2
};

struct V2SREOnInitSideConfig
{
   string              instance_tag;
   string              symbol;
   int                 side_direction;
   long                entry_magic;
   long                exit_magic;
   double              expected_volume;
   double              exit_pips;
   double              point;
   double              add_pips_floor;
   double              widen_ratio;
   double              add_pips_ceiling;
   int                 layer_count;
   datetime            now;
   int                 lookback_sec;
   bool                is_long;
   V2SRECapBridgeKind  cap_bridge;
};

struct V2SREOnInitSideResult
{
   bool             side_halted;
   bool             attempted_reconstruction;
   bool             committed;
   V2SREHaltReason  halt_reason;
   V2SRELayerSnapshot layers[];
   V2SREPathState   path_state;
   int              layer_count_after;
   bool             sentinel_written;
   bool             history_read;
   bool             sentinel_before_history;
   bool             cap_published_on_commit;
   int              cap_published_layers;
   int              entry_pendings_swept;
};

struct V2SREOnInitBrokerOverride
{
   bool                    active;
   V2SREPositionInput      entry_positions[];
   V2SREPositionInput      exit_positions[];
   V2SREExitOrderInput     exit_orders[];
   V2SREPendingEntryInput  pending_entries[];
   V2SREDealInput          deals[];
   bool                    test_corrupt_broker_read;
   double                  test_corrupt_entry_price;
};

V2SREOnInitBrokerOverride g_v2_sre_oninit_broker_override;

struct V2SREOnInitDualBrokerOverride
{
   bool                      active;
   V2SREOnInitBrokerOverride   long_side;
   V2SREOnInitBrokerOverride   short_side;
};

V2SREOnInitDualBrokerOverride g_v2_sre_oninit_dual_override;

struct V2SRESweepTestOrderInput
{
   ulong  ticket;
   string symbol;
   long   magic;
   long   order_type;
   long   order_state;
};

bool g_v2_sre_sweep_test_active = false;
V2SRESweepTestOrderInput g_v2_sre_sweep_test_orders[];

struct V2SREOnInitAggregateOutcome
{
   bool long_halted;
   bool short_halted;
   bool long_committed;
   bool short_committed;
   int  init_result;
};

//+------------------------------------------------------------------+
string V2_SRE_HaltReasonLabel(const V2SREHaltReason reason)
{
   switch(reason) {
      case V2_SRE_HALT_01_EXIT_MAGIC_POSITION_OPEN: return "HALT_01_EXIT_MAGIC_POSITION_OPEN";
      case V2_SRE_HALT_02_EXIT_ORDER_ASSIGNMENT_AMBIGUOUS: return "HALT_02_EXIT_ORDER_ASSIGNMENT_AMBIGUOUS";
      case V2_SRE_HALT_03_TOO_MANY_EXIT_ORDERS: return "HALT_03_TOO_MANY_EXIT_ORDERS";
      case V2_SRE_HALT_04_DANGLING_EXIT_ORDER: return "HALT_04_DANGLING_EXIT_ORDER";
      case V2_SRE_HALT_05_MULTIPLE_ADD_RELOAD_PENDING: return "HALT_05_MULTIPLE_ADD_RELOAD_PENDING";
      case V2_SRE_HALT_06_PENDING_ENTRY_STACK_MISMATCH: return "HALT_06_PENDING_ENTRY_STACK_MISMATCH";
      case V2_SRE_HALT_07_POSITION_TIME_ORDER_AMBIGUOUS: return "HALT_07_POSITION_TIME_ORDER_AMBIGUOUS";
      case V2_SRE_HALT_08_POSITION_VOLUME_MISMATCH: return "HALT_08_POSITION_VOLUME_MISMATCH";
      case V2_SRE_HALT_09_ANCHOR_NOT_FOUND: return "HALT_09_ANCHOR_NOT_FOUND";
      case V2_SRE_HALT_10_UNMATCHED_HISTORICAL_DEAL: return "HALT_10_UNMATCHED_HISTORICAL_DEAL";
      case V2_SRE_HALT_11_PENDING_COMMENT_INCONSISTENT: return "HALT_11_PENDING_COMMENT_INCONSISTENT";
      case V2_SRE_HALT_12_POSITION_TYPE_MISMATCH: return "HALT_12_POSITION_TYPE_MISMATCH";
      case V2_SRE_HALT_13_MULTIPLE_L0_PENDING: return "HALT_13_MULTIPLE_L0_PENDING";
      case V2_SRE_HALT_14_EXIT_PRICE_NO_CANDIDATE: return "HALT_14_EXIT_PRICE_NO_CANDIDATE";
      case V2_SRE_HALT_15_MULTIPLE_ENTRY_IN_ONE_POSITION: return "HALT_15_MULTIPLE_ENTRY_IN_ONE_POSITION";
      case V2_SRE_HALT_16_UNRESOLVED_HEDGE: return "HALT_16_UNRESOLVED_HEDGE";
      case V2_SRE_HALT_17_CLOSEBY_GROUP_SIZE: return "HALT_17_CLOSEBY_GROUP_SIZE";
      case V2_SRE_HALT_18_HEDGE_ORDINARY_CLOSE: return "HALT_18_HEDGE_ORDINARY_CLOSE";
      case V2_SRE_HALT_19_MISSING_DEAL_ID: return "HALT_19_MISSING_DEAL_ID";
      case V2_SRE_HALT_20_PENDING_ENTRY_WRONG_DIRECTION: return "HALT_20_PENDING_ENTRY_WRONG_DIRECTION";
      case V2_SRE_HALT_21_UNMATCHED_EXIT_ORDER: return "HALT_21_UNMATCHED_EXIT_ORDER";
      case V2_SRE_HALT_22_PENDING_ORDER_CLASS: return "HALT_22_PENDING_ORDER_CLASS";
      case V2_SRE_HALT_23_NON_STANDARD_ENTRY_CLOSE: return "HALT_23_NON_STANDARD_ENTRY_CLOSE";
      case V2_SRE_HALT_24_CLOSEBY_RESOLUTION: return "HALT_24_CLOSEBY_RESOLUTION";
      case V2_SRE_HALT_27_ANCHOR_EXIT_MAGIC_REMNANT: return "HALT_27_ANCHOR_EXIT_MAGIC_REMNANT";
      case V2_SRE_HALT_28_TIER1_NOT_UNIQUE: return "HALT_28_TIER1_NOT_UNIQUE";
      case V2_SRE_HALT_29_TIER2_NOT_UNIQUE: return "HALT_29_TIER2_NOT_UNIQUE";
      case V2_SRE_HALT_30_CLOSEBY_PRICE_INCONSISTENT: return "HALT_30_CLOSEBY_PRICE_INCONSISTENT";
      case V2_SRE_HALT_VALIDATION_MISMATCH: return "HALT_VALIDATION_MISMATCH";
      default: return "HALT_UNKNOWN";
   }
}

//+------------------------------------------------------------------+
string V2_SRE_FormatHaltAlert(const string instance_tag,
                              const V2SREHaltReason reason,
                              const ulong &tickets[])
{
   string ticket_str = "";
   for(int i = 0; i < ArraySize(tickets); i++) {
      if(i > 0)
         ticket_str += ",";
      ticket_str += IntegerToString((long)tickets[i]);
   }
   return StringFormat("ALERT V2_STATE_RECONSTRUCTION_HALT | instance=%s reason=%s count=%d tickets=%s",
                       instance_tag,
                       V2_SRE_HaltReasonLabel(reason),
                       ArraySize(tickets),
                       ticket_str);
}

//+------------------------------------------------------------------+
void V2_SRE_CollectPositionTickets(const V2SREPositionInput &positions[],
                                   ulong &tickets[])
{
   ArrayResize(tickets, 0);
   for(int i = 0; i < ArraySize(positions); i++) {
      int n = ArraySize(tickets);
      ArrayResize(tickets, n + 1);
      tickets[n] = positions[i].ticket;
   }
}

//+------------------------------------------------------------------+
void V2_SRE_CapWriteSentinelKey(const string gv_key)
{
   if(gv_key != "")
      GlobalVariableSet(gv_key, V2_SRE_CAP_GV_SENTINEL);
}

//+------------------------------------------------------------------+
void V2_SRE_CapWriteSentinel(const V2SRECapBridgeKind kind, const bool is_long)
{
   if(kind == V2_SRE_CAP_BRIDGE_GBPUSD) {
      string key = V2_GbpCapGvKey("GBPUSD", is_long);
      V2_SRE_CapWriteSentinelKey(key);
   } else if(kind == V2_SRE_CAP_BRIDGE_EURUSD) {
      string key = V2_EurCapGvKey("EURUSD", is_long);
      V2_SRE_CapWriteSentinelKey(key);
   } else if(kind == V2_SRE_CAP_BRIDGE_EURGBP_DUAL) {
      V2_SRE_CapWriteSentinelKey(V2_GbpCapGvKey("EURGBP", is_long));
      V2_SRE_CapWriteSentinelKey(V2_EurCapGvKey("EURGBP", is_long));
   }
}

//+------------------------------------------------------------------+
void V2_SRE_CapPublishLayers(const V2SRECapBridgeKind kind,
                             const bool is_long,
                             const int layer_count)
{
   if(kind == V2_SRE_CAP_BRIDGE_GBPUSD)
      V2_GbpCapSyncInstance("GBPUSD", is_long, layer_count);
   else if(kind == V2_SRE_CAP_BRIDGE_EURUSD)
      V2_EurCapSyncInstance("EURUSD", is_long, layer_count);
   else if(kind == V2_SRE_CAP_BRIDGE_EURGBP_DUAL) {
      V2_GbpCapSyncInstance("EURGBP", is_long, layer_count);
      V2_EurCapSyncInstance("EURGBP", is_long, layer_count);
   }
}

//+------------------------------------------------------------------+
int V2_SRE_GatherOpenPositionsByMagic(const string symbol,
                                      const long magic,
                                      const int side_direction,
                                      V2SREPositionInput &out[])
{
   ArrayResize(out, 0);
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != symbol)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      int n = ArraySize(out);
      ArrayResize(out, n + 1);
      out[n].ticket = ticket;
      out[n].position_id = (ulong)PositionGetInteger(POSITION_IDENTIFIER);
      out[n].open_time = (datetime)PositionGetInteger(POSITION_TIME);
      out[n].entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
      out[n].volume = PositionGetDouble(POSITION_VOLUME);
      out[n].symbol = symbol;
      out[n].position_type = (int)PositionGetInteger(POSITION_TYPE);
      out[n].direction = side_direction;
   }
   return ArraySize(out);
}

//+------------------------------------------------------------------+
void V2_SRE_GatherPendingOrders(const string symbol,
                                const long entry_magic,
                                const long exit_magic,
                                const int side_direction,
                                V2SREExitOrderInput &exit_orders[],
                                V2SREPendingEntryInput &pending_entries[])
{
   ArrayResize(exit_orders, 0);
   ArrayResize(pending_entries, 0);
   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      ulong ticket = OrderGetTicket(i);
      if(!OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != symbol)
         continue;
      long omagic = OrderGetInteger(ORDER_MAGIC);
      if(omagic == exit_magic) {
         int n = ArraySize(exit_orders);
         ArrayResize(exit_orders, n + 1);
         exit_orders[n].ticket = ticket;
         exit_orders[n].placement_time = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
         exit_orders[n].price = OrderGetDouble(ORDER_PRICE_OPEN);
         exit_orders[n].volume = OrderGetDouble(ORDER_VOLUME_CURRENT);
         exit_orders[n].direction = side_direction;
         exit_orders[n].symbol = symbol;
      } else if(omagic == entry_magic) {
         int n = ArraySize(pending_entries);
         ArrayResize(pending_entries, n + 1);
         pending_entries[n].ticket = ticket;
         pending_entries[n].setup_time = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
         pending_entries[n].price = OrderGetDouble(ORDER_PRICE_OPEN);
         pending_entries[n].volume = OrderGetDouble(ORDER_VOLUME_CURRENT);
         pending_entries[n].direction = side_direction;
         pending_entries[n].symbol = symbol;
         pending_entries[n].comment = OrderGetString(ORDER_COMMENT);
         pending_entries[n].magic = omagic;
      }
   }
}

//+------------------------------------------------------------------+
void V2_SRE_GatherDealHistory(const string symbol,
                              const long entry_magic,
                              const long exit_magic,
                              const datetime lookback_from,
                              const int lookback_sec,
                              V2SREDealInput &deals[])
{
   ArrayResize(deals, 0);
   datetime from = lookback_from - lookback_sec;
   if(!HistorySelect(from, lookback_from + 86400))
      return;

   const int total = HistoryDealsTotal();
   for(int i = 0; i < total; i++) {
      ulong deal_ticket = HistoryDealGetTicket(i);
      if(deal_ticket == 0)
         continue;
      if(HistoryDealGetString(deal_ticket, DEAL_SYMBOL) != symbol)
         continue;
      long dmagic = HistoryDealGetInteger(deal_ticket, DEAL_MAGIC);
      if(dmagic != entry_magic && dmagic != exit_magic)
         continue;

      V2SREDealInput d;
      d.deal_ticket = deal_ticket;
      d.position_id = (ulong)HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID);
      d.order_id = (ulong)HistoryDealGetInteger(deal_ticket, DEAL_ORDER);
      d.deal_time = (datetime)HistoryDealGetInteger(deal_ticket, DEAL_TIME);
      d.entry_type = HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
      d.deal_type = HistoryDealGetInteger(deal_ticket, DEAL_TYPE);
      d.deal_magic = dmagic;
      d.deal_reason = HistoryDealGetInteger(deal_ticket, DEAL_REASON);
      d.price = HistoryDealGetDouble(deal_ticket, DEAL_PRICE);
      d.volume = HistoryDealGetDouble(deal_ticket, DEAL_VOLUME);
      d.comment = HistoryDealGetString(deal_ticket, DEAL_COMMENT);
      int n = ArraySize(deals);
      ArrayResize(deals, n + 1);
      deals[n] = d;
   }
}

//+------------------------------------------------------------------+
void V2_SRE_BuildBrokerReadSnapshots(const V2SREPositionInput &positions[],
                                     V2SRELayerSnapshot &layers[])
{
   V2SREPositionInput sorted[];
   const int n = ArraySize(positions);
   ArrayResize(sorted, n);
   for(int i = 0; i < n; i++)
      sorted[i] = positions[i];
   V2_SRE_SortPositionsByOpenTime(sorted);

   ArrayResize(layers, n);
   for(int i = 0; i < n; i++) {
      layers[i].position_ticket = sorted[i].position_id;
      layers[i].entry_ticket = sorted[i].ticket;
      layers[i].entry_price = sorted[i].entry_price;
      layers[i].entry_time = sorted[i].open_time;
      layers[i].exit_ticket = 0;
      layers[i].exit_target = 0.0;
   }
}

//+------------------------------------------------------------------+
bool V2_SRE_ProcessSideHalt(string &system_alerts[],
                            const string instance_tag,
                            const V2SREHaltReason reason,
                            const V2SREPositionInput &entry_positions[],
                            const V2SREPositionInput &exit_positions[])
{
   ulong tickets[];
   if(reason == V2_SRE_HALT_01_EXIT_MAGIC_POSITION_OPEN)
      V2_SRE_CollectPositionTickets(exit_positions, tickets);
   else
      V2_SRE_CollectPositionTickets(entry_positions, tickets);

   string alert = V2_SRE_FormatHaltAlert(instance_tag, reason, tickets);
   Print(alert);
   Print("ERROR: fxmatrix_v2 ", instance_tag,
         " startup aborted — state reconstruction failed (",
         V2_SRE_HaltReasonLabel(reason),
         "). Close or reconcile manually, then reattach flat. Instance halted.");
   V2_PushSystemAlert(system_alerts, alert);
   return true;
}

//+------------------------------------------------------------------+
void V2_SRE_ResetOnInitSideResult(V2SREOnInitSideResult &result)
{
   result.side_halted = false;
   result.attempted_reconstruction = false;
   result.committed = false;
   result.halt_reason = V2_SRE_OK;
   ArrayResize(result.layers, 0);
   result.path_state.current_add_pips = 0.0;
   result.path_state.last_exit_valid = false;
   result.path_state.last_exit_price = 0.0;
   result.layer_count_after = 0;
   result.sentinel_written = false;
   result.history_read = false;
   result.sentinel_before_history = false;
   result.cap_published_on_commit = false;
   result.cap_published_layers = 0;
   result.entry_pendings_swept = 0;
}

//+------------------------------------------------------------------+
// Steps 3-10 on gathered broker inputs (Steps 0-2 already handled by caller).
V2SREHaltReason V2_SRE_RunOnInitSteps3To10(const V2SREOnInitSideConfig &cfg,
                                           V2SREPositionInput &entry_positions[],
                                           const V2SREExitOrderInput &exit_orders[],
                                           const V2SREPendingEntryInput &pending_entries[],
                                           V2SREDealInput &deals[],
                                           V2SREOnInitSideResult &result)
{
   const int entry_n = ArraySize(entry_positions);

   // Step 3 — all prechecks, no short-circuit
   const bool position_types_ok = V2_SRE_CheckOpenPositionTypes(entry_positions, cfg.side_direction);
   const bool volumes_ok = V2_SRE_CheckPositionVolumes(entry_positions, cfg.expected_volume);
   const V2SREHaltReason pending_halt =
      V2_SRE_CheckPendingEntryConsistency(pending_entries, entry_n, cfg.side_direction);
   const V2SREHaltReason entry_in_halt = V2_SRE_CheckMultipleEntryInDeals(deals, cfg.entry_magic);

   // Step 4
   V2SREMatchResult match = V2_SRE_MatchExitOrders(entry_positions, exit_orders, cfg.now,
                                                   cfg.exit_pips, cfg.point, cfg.expected_volume);

   // Step 5
   V2SREAnchorResult anchor = V2_SRE_FindAnchor(deals, cfg.now, cfg.lookback_sec,
                                                cfg.entry_magic, cfg.exit_magic);
   V2SREMapResult map_result = V2_SRE_MapHedgeToEntry(deals,
                                                      (anchor.halt == V2_SRE_OK ? anchor.anchor_time : 0),
                                                      cfg.entry_magic, cfg.exit_magic,
                                                      cfg.side_direction, cfg.exit_pips, cfg.point,
                                                      cfg.symbol, cfg.add_pips_floor);
   const V2SREHaltReason nonstd_halt = V2_SRE_CheckNonStandardClosures(deals, cfg.now,
                                                                       cfg.lookback_sec,
                                                                       cfg.entry_magic);

   // Step 6
   V2SREReplayEvent events[];
   if(anchor.halt == V2_SRE_OK)
      V2_SRE_BuildReplayEvents(deals, anchor.anchor_time, cfg.entry_magic, map_result.pairs, events);
   V2SREPathState path_state = V2_SRE_ReplayPathDependentState(events,
                                                                cfg.add_pips_floor,
                                                                cfg.widen_ratio,
                                                                cfg.add_pips_ceiling);

   // Step 7
   const V2SREHaltReason aggregate = V2_SRE_CheckAmbiguity(V2_SRE_OK, match, anchor, map_result,
                                                             nonstd_halt, position_types_ok, volumes_ok,
                                                             pending_halt, entry_in_halt);
   if(aggregate != V2_SRE_OK) {
      result.halt_reason = aggregate;
      result.side_halted = true;
      return aggregate;
   }

   // Step 8 skipped — not halted

   // Step 9 — build snapshot + dual-read validation
   V2SRELayerSnapshot reconstructed[];
   V2_SRE_BuildLayerSnapshotsFromPositions(entry_positions, match, reconstructed);

   V2SRELayerSnapshot broker_read[];
   V2_SRE_BuildBrokerReadSnapshots(entry_positions, broker_read);
   if(g_v2_sre_oninit_broker_override.test_corrupt_broker_read && ArraySize(broker_read) > 0)
      broker_read[0].entry_price = g_v2_sre_oninit_broker_override.test_corrupt_entry_price;

   const V2SREHaltReason validation = V2_SRE_ValidateReconstruction(reconstructed, broker_read);
   if(validation != V2_SRE_OK) {
      result.halt_reason = validation;
      result.side_halted = true;
      return validation;
   }

   // Step 10 — commit
   const int layer_count = ArraySize(reconstructed);
   ArrayResize(result.layers, layer_count);
   for(int i = 0; i < layer_count; i++)
      result.layers[i] = reconstructed[i];
   result.path_state = path_state;
   result.layer_count_after = layer_count;
   result.committed = true;

   V2_SRE_CapPublishLayers(cfg.cap_bridge, cfg.is_long, layer_count);
   result.cap_published_on_commit = true;
   result.cap_published_layers = layer_count;

   return V2_SRE_OK;
}

// MQL5 has no ORDER_STATE_PENDING; resting pool limits use ORDER_STATE_PLACED.
bool V2_SRE_OrderStateIsRestingPending(const long state)
{
   return (state == ORDER_STATE_PLACED || state == ORDER_STATE_STARTED);
}

//+------------------------------------------------------------------+
int V2_SRE_SweepEntryPendingOrders(const string symbol, const long entry_magic)
{
   int swept = 0;

   if(g_v2_sre_sweep_test_active) {
      for(int i = ArraySize(g_v2_sre_sweep_test_orders) - 1; i >= 0; i--) {
         const V2SRESweepTestOrderInput o = g_v2_sre_sweep_test_orders[i];
         if(o.ticket == 0)
            continue;
         if(o.symbol != symbol)
            continue;
         if(o.magic != entry_magic)
            continue;
         if(o.order_type != ORDER_TYPE_BUY_LIMIT && o.order_type != ORDER_TYPE_SELL_LIMIT)
            continue;
         if(!V2_SRE_OrderStateIsRestingPending(o.order_state))
            continue;
         swept++;
      }
      return swept;
   }

   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;
      if(!OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != symbol)
         continue;
      if(OrderGetInteger(ORDER_MAGIC) != entry_magic)
         continue;
      long otype = OrderGetInteger(ORDER_TYPE);
      if(otype != ORDER_TYPE_BUY_LIMIT && otype != ORDER_TYPE_SELL_LIMIT)
         continue;
      if(!OrderSelect(ticket))
         continue;
      if(!V2_SRE_OrderStateIsRestingPending(OrderGetInteger(ORDER_STATE)))
         continue;

      MqlTradeRequest req = {};
      MqlTradeResult res = {};
      req.action = TRADE_ACTION_REMOVE;
      req.order = ticket;
      if(V2_OrderSendCounted(req, res))
         swept++;
   }
   return swept;
}

// --- ADR-110: baseline flat-side sweep --------------------------------------
// Test seam for the flat-side gate (mirrors g_v2_sre_sweep_test_active).
bool g_v2_sre_flatsweep_test_active = false;
int  g_v2_sre_flatsweep_test_position_count = 0;

// Baseline quote-lifecycle sweep for a FLAT side (zero open positions). Orphaned
// sides are handled by SRE (reconstruct+sweep on success; frozen on halt); a flat
// side never enters reconstruction, so its stale pre-crash entry-magic limits are
// cleared here before the tick loop re-quotes. Gating on zero positions
// structurally excludes reconstructed and halted sides (both hold positions).
// Returns the count of entry pendings swept (0 if the side is not flat).
int V2_SweepFlatSideEntryPendings(const string symbol, const long entry_magic,
                                  const long exit_magic, const int side_direction)
{
   int pos_count;
   if(g_v2_sre_flatsweep_test_active) {
      pos_count = g_v2_sre_flatsweep_test_position_count;
   } else {
      V2SREPositionInput fs_entry[];
      V2SREPositionInput fs_exit[];
      V2_SRE_GatherOpenPositionsByMagic(symbol, entry_magic, side_direction, fs_entry);
      V2_SRE_GatherOpenPositionsByMagic(symbol, exit_magic, side_direction, fs_exit);
      pos_count = ArraySize(fs_entry) + ArraySize(fs_exit);
   }
   if(pos_count > 0)
      return 0;
   return V2_SRE_SweepEntryPendingOrders(symbol, entry_magic);
}

//+------------------------------------------------------------------+
// Pure approved sequence (Steps 0-10) on supplied broker inputs (unit tests).
// Returns halt reason; V2_SRE_OK means success (committed or not applicable).
V2SREHaltReason V2_SRE_RunOnInitSequencePure(const V2SREOnInitSideConfig &cfg,
                                             const V2SREPositionInput &entry_positions_in[],
                                             const V2SREPositionInput &exit_positions_in[],
                                             const V2SREExitOrderInput &exit_orders_in[],
                                             const V2SREPendingEntryInput &pending_entries_in[],
                                             const V2SREDealInput &deals_in[],
                                             V2SREOnInitSideResult &result)
{
   V2SREPositionInput entry_positions[];
   V2SREPositionInput exit_positions[];
   V2SREExitOrderInput exit_orders[];
   V2SREPendingEntryInput pending_entries[];
   V2SREDealInput deals[];

   const int entry_n = ArraySize(entry_positions_in);
   const int exit_n = ArraySize(exit_positions_in);
   ArrayResize(entry_positions, entry_n);
   ArrayResize(exit_positions, exit_n);
   for(int i = 0; i < entry_n; i++)
      entry_positions[i] = entry_positions_in[i];
   for(int i = 0; i < exit_n; i++)
      exit_positions[i] = exit_positions_in[i];

   const int ord_n = ArraySize(exit_orders_in);
   const int pend_n = ArraySize(pending_entries_in);
   const int deal_n = ArraySize(deals_in);
   ArrayResize(exit_orders, ord_n);
   ArrayResize(pending_entries, pend_n);
   ArrayResize(deals, deal_n);
   for(int i = 0; i < ord_n; i++)
      exit_orders[i] = exit_orders_in[i];
   for(int i = 0; i < pend_n; i++)
      pending_entries[i] = pending_entries_in[i];
   for(int i = 0; i < deal_n; i++)
      deals[i] = deals_in[i];

   const int total_pos = entry_n + exit_n;
   if(!V2_IsOrphanedStartupState(cfg.layer_count, total_pos))
      return V2_SRE_OK;

   result.attempted_reconstruction = true;

   const V2SREHaltReason precheck = V2_SRE_PreCheckExitMagicOpen(exit_positions);
   if(precheck != V2_SRE_OK) {
      result.halt_reason = precheck;
      result.side_halted = true;
      return precheck;
   }

   if(entry_n == 0) {
      result.halt_reason = V2_SRE_HALT_01_EXIT_MAGIC_POSITION_OPEN;
      result.side_halted = true;
      return result.halt_reason;
   }

   V2_SRE_CapWriteSentinel(cfg.cap_bridge, cfg.is_long);
   result.sentinel_written = true;
   result.history_read = (deal_n > 0 || ord_n > 0 || pend_n > 0);
   result.sentinel_before_history = result.sentinel_written;

   return V2_SRE_RunOnInitSteps3To10(cfg, entry_positions, exit_orders, pending_entries, deals, result);
}

//+------------------------------------------------------------------+
// Fixture-driven side path (unit tests). Returns true if side should halt.
bool V2_SRE_RunSideOnInitFromFixture(string &system_alerts[],
                                     const V2SREOnInitSideConfig &cfg,
                                     const V2SREOnInitBrokerOverride &fixture,
                                     V2SREOnInitSideResult &result)
{
   V2_SRE_ResetOnInitSideResult(result);

   const bool saved_corrupt = g_v2_sre_oninit_broker_override.test_corrupt_broker_read;
   const double saved_corrupt_price = g_v2_sre_oninit_broker_override.test_corrupt_entry_price;
   g_v2_sre_oninit_broker_override.test_corrupt_broker_read = fixture.test_corrupt_broker_read;
   g_v2_sre_oninit_broker_override.test_corrupt_entry_price = fixture.test_corrupt_entry_price;

   const V2SREHaltReason seq = V2_SRE_RunOnInitSequencePure(cfg,
      fixture.entry_positions,
      fixture.exit_positions,
      fixture.exit_orders,
      fixture.pending_entries,
      fixture.deals,
      result);

   g_v2_sre_oninit_broker_override.test_corrupt_broker_read = saved_corrupt;
   g_v2_sre_oninit_broker_override.test_corrupt_entry_price = saved_corrupt_price;

   if(seq != V2_SRE_OK) {
      result.side_halted = true;
      return V2_SRE_ProcessSideHalt(system_alerts, cfg.instance_tag, seq,
                                      fixture.entry_positions, fixture.exit_positions);
   }
   return false;
}

//+------------------------------------------------------------------+
// Both-side OnInit SRE block: run long then short, aggregate halt/commit/init result.
// Mirrors production OnInit wiring (fxmatrix_v2.mq5) without EA-specific apply/cap/telemetry.
V2SREOnInitAggregateOutcome V2_SRE_RunOnInitSidePair(string &long_alerts[],
                                                     string &short_alerts[],
                                                     const V2SREOnInitSideConfig &long_cfg,
                                                     const V2SREOnInitSideConfig &short_cfg,
                                                     V2SREOnInitSideResult &long_sre,
                                                     V2SREOnInitSideResult &short_sre)
{
   V2SREOnInitAggregateOutcome agg;
   agg.long_halted = V2_SRE_RunSideOnInit(long_alerts, long_cfg, long_sre);
   agg.short_halted = V2_SRE_RunSideOnInit(short_alerts, short_cfg, short_sre);
   agg.long_committed = long_sre.committed;
   agg.short_committed = short_sre.committed;
   agg.init_result = V2_OnInitResultFromOrphanFlags(agg.long_halted, agg.short_halted);
   return agg;
}

//+------------------------------------------------------------------+
// Production entry: gather live broker state, run sequence, push alerts on halt.
// Returns true if this side should halt (same contract as V2_ProcessOrphanStartupCheck).
bool V2_SRE_RunSideOnInit(string &system_alerts[],
                          const V2SREOnInitSideConfig &cfg,
                          V2SREOnInitSideResult &result)
{
   V2_SRE_ResetOnInitSideResult(result);

   V2SREPositionInput entry_positions[];
   V2SREPositionInput exit_positions[];
   V2SREExitOrderInput exit_orders[];
   V2SREPendingEntryInput pending_entries[];
   V2SREDealInput deals[];

   if(g_v2_sre_oninit_dual_override.active) {
      const V2SREOnInitBrokerOverride fixture = cfg.is_long ?
         g_v2_sre_oninit_dual_override.long_side : g_v2_sre_oninit_dual_override.short_side;
      if(!fixture.active)
         return false;
      return V2_SRE_RunSideOnInitFromFixture(system_alerts, cfg, fixture, result);
   }

   if(g_v2_sre_oninit_broker_override.active) {
      return V2_SRE_RunSideOnInitFromFixture(system_alerts, cfg,
                                             g_v2_sre_oninit_broker_override, result);
   }

   V2_SRE_GatherOpenPositionsByMagic(cfg.symbol, cfg.entry_magic, cfg.side_direction, entry_positions);
   V2_SRE_GatherOpenPositionsByMagic(cfg.symbol, cfg.exit_magic, cfg.side_direction, exit_positions);

   const int total_pos = ArraySize(entry_positions) + ArraySize(exit_positions);
   if(!V2_IsOrphanedStartupState(cfg.layer_count, total_pos))
      return false;

   result.attempted_reconstruction = true;

   const V2SREHaltReason precheck = V2_SRE_PreCheckExitMagicOpen(exit_positions);
   if(precheck != V2_SRE_OK) {
      result.halt_reason = precheck;
      result.side_halted = true;
      return V2_SRE_ProcessSideHalt(system_alerts, cfg.instance_tag, precheck,
                                    entry_positions, exit_positions);
   }

   if(ArraySize(entry_positions) == 0) {
      result.halt_reason = V2_SRE_HALT_01_EXIT_MAGIC_POSITION_OPEN;
      result.side_halted = true;
      return V2_SRE_ProcessSideHalt(system_alerts, cfg.instance_tag, result.halt_reason,
                                    entry_positions, exit_positions);
   }

   V2_SRE_CapWriteSentinel(cfg.cap_bridge, cfg.is_long);
   result.sentinel_written = true;

   V2_SRE_GatherPendingOrders(cfg.symbol, cfg.entry_magic, cfg.exit_magic, cfg.side_direction,
                              exit_orders, pending_entries);
   V2_SRE_GatherDealHistory(cfg.symbol, cfg.entry_magic, cfg.exit_magic,
                            cfg.now, cfg.lookback_sec, deals);
   result.history_read = true;
   result.sentinel_before_history = true;

   const V2SREHaltReason seq = V2_SRE_RunOnInitSteps3To10(cfg, entry_positions, exit_orders,
                                                          pending_entries, deals, result);
   if(seq != V2_SRE_OK) {
      result.side_halted = true;
      return V2_SRE_ProcessSideHalt(system_alerts, cfg.instance_tag, seq,
                                    entry_positions, exit_positions);
   }

   result.entry_pendings_swept = V2_SRE_SweepEntryPendingOrders(cfg.symbol, cfg.entry_magic);
   return false;
}

#endif // FXMATRIX_V2_SRE_ONINIT_MQH
