//+------------------------------------------------------------------+
//| fxmatrix_v2_bcc.mqh — Book-Consistency Check v1 (detect-only)   |
//| Reuses SRE eligibility/assignment; emits system_alerts only.      |
//+------------------------------------------------------------------+
#ifndef FXMATRIX_V2_BCC_MQH
#define FXMATRIX_V2_BCC_MQH

#include "fxmatrix_v2_state_reconstruction.mqh"

enum V2BccCheckKind
{
   V2_BCC_CHECK_ORPHAN_EXIT  = 0,
   V2_BCC_CHECK_NAKED        = 1,
   V2_BCC_CHECK_ONE_LEGGED   = 2,
   V2_BCC_CHECK_DUPLICATE    = 3,
   V2_BCC_CHECK_UNVERIFIABLE = 4
};

struct V2BccLayerRef
{
   ulong exit_ticket;
   ulong position_ticket;
};

struct V2BccExitItem
{
   ulong    ticket;
   double   price;
   double   volume;
   datetime time;
   long     magic;
   bool     is_position;
};

struct V2BccRawFinding
{
   V2BccCheckKind check;
   ulong          ticket;
   long           magic;
   string         detail;
};

struct V2BccDebouncedFinding
{
   V2BccCheckKind check;
   ulong          ticket;
   long           magic;
   string         detail;
   int            streak;
};

struct V2BccSideRuntime
{
   bool     tier2_pending;
   datetime last_tier3_sweep;
   V2BccDebouncedFinding pending[];
};

struct V2BccSideInputs
{
   string side_label;
   string symbol;
   int    direction;
   long   entry_magic;
   long   exit_magic;
   double exit_pips;
   double point;
   double expected_volume;
   bool   halted;
   int    layer_count;
   int    max_layers;
   bool   last_exit_valid;
   bool   cap_blocks_add;
   ulong  l0_ticket;
   ulong  add_ticket;
   V2BccLayerRef layers[];
};

// Test hooks — broker pool override for unit tests (detect-only paths only).
bool g_v2_bcc_test_active = false;

struct V2BccTestPosition
{
   ulong    ticket;
   ulong    position_id;
   long     magic;
   string   symbol;
   double   volume;
   double   open_price;
   datetime open_time;
   int      position_type;
};

struct V2BccTestOrder
{
   ulong    ticket;
   long     magic;
   string   symbol;
   double   volume;
   double   price;
   datetime setup_time;
   int      order_type;
};

V2BccTestPosition g_v2_bcc_test_positions[];
V2BccTestOrder    g_v2_bcc_test_orders[];
ulong             g_v2_bcc_test_position_live[];

void V2_Bcc_TestReset()
{
   g_v2_bcc_test_active = false;
   ArrayResize(g_v2_bcc_test_positions, 0);
   ArrayResize(g_v2_bcc_test_orders, 0);
   ArrayResize(g_v2_bcc_test_position_live, 0);
}

bool V2_Bcc_TestPositionLive(const ulong ticket)
{
   if(ticket == 0)
      return false;
   if(!g_v2_bcc_test_active)
      return PositionSelectByTicket(ticket);
   for(int i = 0; i < ArraySize(g_v2_bcc_test_position_live); i++) {
      if(g_v2_bcc_test_position_live[i] == ticket)
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
string V2_Bcc_CheckLabel(const V2BccCheckKind check)
{
   switch(check) {
      case V2_BCC_CHECK_ORPHAN_EXIT:  return "ORPHAN_EXIT";
      case V2_BCC_CHECK_NAKED:        return "NAKED";
      case V2_BCC_CHECK_ONE_LEGGED:   return "ONE_LEGGED";
      case V2_BCC_CHECK_DUPLICATE:    return "DUPLICATE";
      case V2_BCC_CHECK_UNVERIFIABLE: return "UNVERIFIABLE";
   }
   return "UNKNOWN";
}

string V2_Bcc_FormatAlert(const string side_label,
                          const V2BccCheckKind check,
                          const ulong ticket,
                          const long magic,
                          const string detail)
{
   return StringFormat("BCC | side=%s | check=%s | ticket=%I64u | magic=%d | detail=%s",
                       side_label,
                       V2_Bcc_CheckLabel(check),
                       ticket,
                       (int)magic,
                       detail);
}

void V2_Bcc_BuildLiveAlerts(const string side_label,
                            const V2BccSideRuntime &rt,
                            const bool halted,
                            string &out_alerts[])
{
   ArrayResize(out_alerts, 0);

   for(int i = 0; i < ArraySize(rt.pending); i++) {
      if(rt.pending[i].streak < 2)
         continue;
      const string msg = V2_Bcc_FormatAlert(side_label, rt.pending[i].check,
                                            rt.pending[i].ticket, rt.pending[i].magic,
                                            rt.pending[i].detail);
      const int n = ArraySize(out_alerts);
      ArrayResize(out_alerts, n + 1);
      out_alerts[n] = msg;
   }

   if(halted) {
      const string halt_msg = StringFormat("HALT | side=%s | instance halted (see Experts log)",
                                           side_label);
      const int n = ArraySize(out_alerts);
      ArrayResize(out_alerts, n + 1);
      out_alerts[n] = halt_msg;
   }
}

bool V2_Bcc_FindingKeyEqual(const V2BccRawFinding &a, const V2BccDebouncedFinding &b)
{
   return (a.check == b.check && a.ticket == b.ticket && a.magic == b.magic);
}

bool V2_Bcc_RawFindingEqual(const V2BccRawFinding &a, const V2BccRawFinding &b)
{
   return (a.check == b.check && a.ticket == b.ticket && a.magic == b.magic);
}

void V2_Bcc_ResetSideRuntime(V2BccSideRuntime &rt)
{
   rt.tier2_pending = false;
   rt.last_tier3_sweep = 0;
   ArrayResize(rt.pending, 0);
}

//+------------------------------------------------------------------+
int V2_Bcc_FindExitItemIndex(const V2BccExitItem &items[], const ulong ticket)
{
   for(int i = 0; i < ArraySize(items); i++) {
      if(items[i].ticket == ticket)
         return i;
   }
   return -1;
}

bool V2_Bcc_ExitItemAlreadyListed(const V2BccExitItem &items[], const ulong ticket)
{
   return (V2_Bcc_FindExitItemIndex(items, ticket) >= 0);
}

void V2_Bcc_AppendExitItem(V2BccExitItem &items[],
                           const ulong ticket,
                           const double price,
                           const double volume,
                           const datetime time,
                           const long magic,
                           const bool is_position)
{
   if(V2_Bcc_ExitItemAlreadyListed(items, ticket))
      return;
   const int n = ArraySize(items);
   ArrayResize(items, n + 1);
   items[n].ticket = ticket;
   items[n].price = price;
   items[n].volume = volume;
   items[n].time = time;
   items[n].magic = magic;
   items[n].is_position = is_position;
}

void V2_Bcc_BuildExitItemsFromTestPool(const string symbol,
                                       const long exit_magic,
                                       V2BccExitItem &items[])
{
   ArrayResize(items, 0);
   for(int i = 0; i < ArraySize(g_v2_bcc_test_orders); i++) {
      if(g_v2_bcc_test_orders[i].symbol != symbol)
         continue;
      if(g_v2_bcc_test_orders[i].magic != exit_magic)
         continue;
      V2_Bcc_AppendExitItem(items,
                            g_v2_bcc_test_orders[i].ticket,
                            g_v2_bcc_test_orders[i].price,
                            g_v2_bcc_test_orders[i].volume,
                            g_v2_bcc_test_orders[i].setup_time,
                            exit_magic,
                            false);
   }
   for(int i = 0; i < ArraySize(g_v2_bcc_test_positions); i++) {
      if(g_v2_bcc_test_positions[i].symbol != symbol)
         continue;
      if(g_v2_bcc_test_positions[i].magic != exit_magic)
         continue;
      V2_Bcc_AppendExitItem(items,
                            g_v2_bcc_test_positions[i].ticket,
                            g_v2_bcc_test_positions[i].open_price,
                            g_v2_bcc_test_positions[i].volume,
                            g_v2_bcc_test_positions[i].open_time,
                            exit_magic,
                            true);
   }
}

void V2_Bcc_BuildExitItemsFromLivePool(const string symbol,
                                       const long exit_magic,
                                       V2BccExitItem &items[])
{
   ArrayResize(items, 0);
   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      ulong ticket = OrderGetTicket(i);
      if(!OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != symbol)
         continue;
      if(OrderGetInteger(ORDER_MAGIC) != exit_magic)
         continue;
      V2_Bcc_AppendExitItem(items,
                            ticket,
                            OrderGetDouble(ORDER_PRICE_OPEN),
                            OrderGetDouble(ORDER_VOLUME_INITIAL),
                            (datetime)OrderGetInteger(ORDER_TIME_SETUP),
                            exit_magic,
                            false);
   }
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != symbol)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != exit_magic)
         continue;
      V2_Bcc_AppendExitItem(items,
                            ticket,
                            PositionGetDouble(POSITION_PRICE_OPEN),
                            PositionGetDouble(POSITION_VOLUME),
                            (datetime)PositionGetInteger(POSITION_TIME),
                            exit_magic,
                            true);
   }
}

void V2_Bcc_BuildExitItems(const string symbol,
                           const long exit_magic,
                           V2BccExitItem &items[])
{
   if(g_v2_bcc_test_active)
      V2_Bcc_BuildExitItemsFromTestPool(symbol, exit_magic, items);
   else
      V2_Bcc_BuildExitItemsFromLivePool(symbol, exit_magic, items);
}

void V2_Bcc_BuildEntryPositionsFromTestPool(const V2BccSideInputs &cfg,
                                            V2SREPositionInput &positions[])
{
   ArrayResize(positions, 0);
   for(int i = 0; i < ArraySize(g_v2_bcc_test_positions); i++) {
      if(g_v2_bcc_test_positions[i].symbol != cfg.symbol)
         continue;
      if(g_v2_bcc_test_positions[i].magic != cfg.entry_magic)
         continue;
      const int n = ArraySize(positions);
      ArrayResize(positions, n + 1);
      positions[n].ticket = g_v2_bcc_test_positions[i].ticket;
      positions[n].position_id = g_v2_bcc_test_positions[i].position_id;
      positions[n].open_time = g_v2_bcc_test_positions[i].open_time;
      positions[n].entry_price = g_v2_bcc_test_positions[i].open_price;
      positions[n].volume = g_v2_bcc_test_positions[i].volume;
      positions[n].direction = cfg.direction;
      positions[n].symbol = cfg.symbol;
      positions[n].position_type = g_v2_bcc_test_positions[i].position_type;
   }
}

void V2_Bcc_BuildEntryPositionsFromLivePool(const V2BccSideInputs &cfg,
                                            V2SREPositionInput &positions[])
{
   ArrayResize(positions, 0);
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != cfg.symbol)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != cfg.entry_magic)
         continue;
      const int n = ArraySize(positions);
      ArrayResize(positions, n + 1);
      positions[n].ticket = ticket;
      positions[n].position_id = (ulong)PositionGetInteger(POSITION_IDENTIFIER);
      positions[n].open_time = (datetime)PositionGetInteger(POSITION_TIME);
      positions[n].entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
      positions[n].volume = PositionGetDouble(POSITION_VOLUME);
      positions[n].direction = cfg.direction;
      positions[n].symbol = cfg.symbol;
      positions[n].position_type = (int)PositionGetInteger(POSITION_TYPE);
   }
}

void V2_Bcc_BuildEntryPositions(const V2BccSideInputs &cfg,
                                V2SREPositionInput &positions[])
{
   if(g_v2_bcc_test_active)
      V2_Bcc_BuildEntryPositionsFromTestPool(cfg, positions);
   else
      V2_Bcc_BuildEntryPositionsFromLivePool(cfg, positions);
}

void V2_Bcc_ExitItemsToSREOrders(const V2BccExitItem &items[],
                                 const V2BccSideInputs &cfg,
                                 V2SREExitOrderInput &orders[])
{
   const int n = ArraySize(items);
   ArrayResize(orders, n);
   for(int i = 0; i < n; i++) {
      orders[i].ticket = items[i].ticket;
      orders[i].placement_time = items[i].time;
      orders[i].price = items[i].price;
      orders[i].volume = items[i].volume;
      orders[i].direction = cfg.direction;
      orders[i].symbol = cfg.symbol;
   }
}

int V2_Bcc_CountEntryPendingsFromTestPool(const V2BccSideInputs &cfg)
{
   int count = 0;
   for(int i = 0; i < ArraySize(g_v2_bcc_test_orders); i++) {
      if(g_v2_bcc_test_orders[i].symbol != cfg.symbol)
         continue;
      if(g_v2_bcc_test_orders[i].magic != cfg.entry_magic)
         continue;
      count++;
   }
   return count;
}

int V2_Bcc_CountEntryPendingsFromLivePool(const V2BccSideInputs &cfg)
{
   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      ulong ticket = OrderGetTicket(i);
      if(!OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != cfg.symbol)
         continue;
      if(OrderGetInteger(ORDER_MAGIC) != cfg.entry_magic)
         continue;
      count++;
   }
   return count;
}

int V2_Bcc_CountEntryPendings(const V2BccSideInputs &cfg)
{
   if(g_v2_bcc_test_active)
      return V2_Bcc_CountEntryPendingsFromTestPool(cfg);
   return V2_Bcc_CountEntryPendingsFromLivePool(cfg);
}

bool V2_Bcc_OrderTicketLive(const ulong ticket)
{
   if(ticket == 0)
      return false;
   if(g_v2_bcc_test_active) {
      for(int i = 0; i < ArraySize(g_v2_bcc_test_orders); i++) {
         if(g_v2_bcc_test_orders[i].ticket == ticket)
            return true;
      }
      return false;
   }
   return OrderSelect(ticket);
}

bool V2_Bcc_ResolvePositionLive(const ulong position_ref)
{
   if(position_ref == 0)
      return false;
   if(g_v2_bcc_test_active)
      return V2_Bcc_TestPositionLive(position_ref);
   return (V2_ResolvePositionTicket(position_ref) != 0);
}

bool V2_Bcc_Tier1ExitJustifiedByBinding(const ulong exit_ticket,
                                        const V2BccLayerRef &layers[])
{
   for(int i = 0; i < ArraySize(layers); i++) {
      if(layers[i].exit_ticket != exit_ticket)
         continue;
      if(!V2_Bcc_ResolvePositionLive(layers[i].position_ticket))
         return false;
      return true;
   }
   return false;
}

bool V2_Bcc_ExitIsUnverifiable(const V2SREPositionInput &positions[],
                               const V2SREExitOrderInput &ord,
                               const datetime now,
                               const double exit_pips,
                               const double point,
                               const double expected_volume)
{
   int tier2_matches = 0;
   const int pc = ArraySize(positions);
   for(int i = 0; i < pc; i++) {
      if(V2_SRE_Tier1Eligible(positions[i], ord, now, exit_pips, point, expected_volume))
         return false;
      if(V2_SRE_Tier2Eligible(positions[i], ord, positions, now,
                              exit_pips, point, expected_volume))
         tier2_matches++;
   }
   return (tier2_matches > 1);
}

void V2_Bcc_CopyOrdersExcept(const V2SREExitOrderInput &orders[],
                             const int skip_idx,
                             V2SREExitOrderInput &out[])
{
   ArrayResize(out, 0);
   for(int j = 0; j < ArraySize(orders); j++) {
      if(j == skip_idx)
         continue;
      const int n = ArraySize(out);
      ArrayResize(out, n + 1);
      out[n] = orders[j];
   }
}

bool V2_Bcc_ExitAssignedInMatch(const V2SREMatchResult &match,
                                const V2SREPositionInput &positions[],
                                const ulong exit_ticket)
{
   for(int i = 0; i < ArraySize(positions); i++) {
      if(i < ArraySize(match.exit_tickets) && match.exit_tickets[i] == exit_ticket)
         return true;
   }
   return false;
}

bool V2_Bcc_Tier2ExitIsOrphan(V2SREPositionInput &positions[],
                              const V2SREExitOrderInput &orders[],
                              const int suspect_idx,
                              const datetime now,
                              const double exit_pips,
                              const double point,
                              const double expected_volume,
                              bool &unverifiable)
{
   unverifiable = false;
   if(suspect_idx < 0 || suspect_idx >= ArraySize(orders))
      return false;

   if(V2_Bcc_ExitIsUnverifiable(positions, orders[suspect_idx], now,
                                exit_pips, point, expected_volume)) {
      unverifiable = true;
      return true;
   }

   V2SREMatchResult full = V2_SRE_MatchExitOrders(positions, orders, now,
                                                    exit_pips, point, expected_volume);
   if(full.halt == V2_SRE_OK)
      return !V2_Bcc_ExitAssignedInMatch(full, positions, orders[suspect_idx].ticket);

   V2SREExitOrderInput reduced[];
   V2_Bcc_CopyOrdersExcept(orders, suspect_idx, reduced);
   V2SREMatchResult reduced_match = V2_SRE_MatchExitOrders(positions, reduced, now,
                                                           exit_pips, point, expected_volume);
   return (reduced_match.halt == V2_SRE_OK);
}

void V2_Bcc_Tier1ScanOrphans(const V2BccSideInputs &cfg,
                             V2BccSideRuntime &rt,
                             V2BccExitItem &tier2_candidates[])
{
   ArrayResize(tier2_candidates, 0);
   rt.tier2_pending = false;

   V2BccExitItem exits[];
   V2_Bcc_BuildExitItems(cfg.symbol, cfg.exit_magic, exits);

   for(int i = 0; i < ArraySize(exits); i++) {
      if(V2_Bcc_Tier1ExitJustifiedByBinding(exits[i].ticket, cfg.layers))
         continue;
      const int n = ArraySize(tier2_candidates);
      ArrayResize(tier2_candidates, n + 1);
      tier2_candidates[n] = exits[i];
      rt.tier2_pending = true;
   }
}

void V2_Bcc_Tier2ResolveOrphans(const V2BccSideInputs &cfg,
                                const V2BccExitItem &tier2_candidates[],
                                V2BccRawFinding &findings[])
{
   ArrayResize(findings, 0);
   if(ArraySize(tier2_candidates) == 0)
      return;

   V2SREPositionInput positions[];
   V2_Bcc_BuildEntryPositions(cfg, positions);

   V2BccExitItem all_exits[];
   V2_Bcc_BuildExitItems(cfg.symbol, cfg.exit_magic, all_exits);

   V2SREExitOrderInput orders[];
   V2_Bcc_ExitItemsToSREOrders(all_exits, cfg, orders);

   const datetime now = TimeCurrent();

   for(int c = 0; c < ArraySize(tier2_candidates); c++) {
      int ord_idx = -1;
      for(int j = 0; j < ArraySize(orders); j++) {
         if(orders[j].ticket == tier2_candidates[c].ticket) {
            ord_idx = j;
            break;
         }
      }
      if(ord_idx < 0)
         continue;

      bool unverifiable = false;
      const bool orphan = V2_Bcc_Tier2ExitIsOrphan(positions, orders, ord_idx, now,
                                                    cfg.exit_pips, cfg.point,
                                                    cfg.expected_volume, unverifiable);
      if(!orphan && !unverifiable)
         continue;

      V2BccRawFinding f;
      f.ticket = tier2_candidates[c].ticket;
      f.magic = tier2_candidates[c].magic;
      f.detail = unverifiable ? "tier2_ambiguous_band" : "sre_unassigned_exit";
      f.check = unverifiable ? V2_BCC_CHECK_UNVERIFIABLE : V2_BCC_CHECK_ORPHAN_EXIT;

      const int n = ArraySize(findings);
      ArrayResize(findings, n + 1);
      findings[n] = f;
   }
}

bool V2_Bcc_CloseByCounterpartyAlive(const ulong ticket,
                                     const V2CloseByTask &queue[])
{
   for(int i = 0; i < ArraySize(queue); i++) {
      ulong counterparty = 0;
      if(queue[i].ticket1 == ticket)
         counterparty = queue[i].ticket2;
      else if(queue[i].ticket2 == ticket)
         counterparty = queue[i].ticket1;
      else
         continue;
      if(counterparty != 0 && V2_Bcc_TestPositionLive(counterparty))
         return true;
   }
   return false;
}

bool V2_Bcc_ShouldSuppressCloseBy(const V2BccRawFinding &finding,
                                  const V2CloseByTask &queue[])
{
   if(finding.check != V2_BCC_CHECK_ORPHAN_EXIT && finding.check != V2_BCC_CHECK_NAKED)
      return false;
   return V2_Bcc_CloseByCounterpartyAlive(finding.ticket, queue);
}

bool V2_Bcc_ExitLiveForLayer(const ulong exit_ticket)
{
   if(exit_ticket == 0)
      return false;
   if(g_v2_bcc_test_active) {
      for(int i = 0; i < ArraySize(g_v2_bcc_test_orders); i++) {
         if(g_v2_bcc_test_orders[i].ticket == exit_ticket)
            return true;
      }
      for(int i = 0; i < ArraySize(g_v2_bcc_test_positions); i++) {
         if(g_v2_bcc_test_positions[i].ticket == exit_ticket)
            return true;
      }
      return false;
   }
   return V2_ExitOrderLiveOrFilled(exit_ticket);
}

void V2_Bcc_CheckNakedPositions(const V2BccSideInputs &cfg,
                                V2BccRawFinding &findings[])
{
   V2SREPositionInput positions[];
   V2_Bcc_BuildEntryPositions(cfg, positions);

   for(int i = 0; i < ArraySize(positions); i++) {
      bool has_live_exit = false;
      for(int j = 0; j < ArraySize(cfg.layers); j++) {
         if(!V2_Bcc_ResolvePositionLive(cfg.layers[j].position_ticket))
            continue;
         const bool same_pos = (cfg.layers[j].position_ticket == positions[i].ticket ||
                                cfg.layers[j].position_ticket == positions[i].position_id);
         if(!same_pos)
            continue;
         if(V2_Bcc_ExitLiveForLayer(cfg.layers[j].exit_ticket))
            has_live_exit = true;
      }
      if(has_live_exit)
         continue;

      V2BccRawFinding f;
      f.check = V2_BCC_CHECK_NAKED;
      f.ticket = positions[i].ticket;
      f.magic = cfg.entry_magic;
      f.detail = "entry_position_without_resting_exit";
      const int n = ArraySize(findings);
      ArrayResize(findings, n + 1);
      findings[n] = f;
   }
}

bool V2_Bcc_ShouldExpectEntryPending(const V2BccSideInputs &cfg)
{
   if(cfg.halted)
      return false;
   if(cfg.layer_count == 0)
      return true;
   if(cfg.layer_count >= cfg.max_layers)
      return false;
   if(!cfg.last_exit_valid && cfg.cap_blocks_add)
      return false;
   return true;
}

int V2_Bcc_ExpectedEntryPendingCount(const V2BccSideInputs &cfg)
{
   return V2_Bcc_ShouldExpectEntryPending(cfg) ? 1 : 0;
}

bool V2_Bcc_HasLiveEntryPending(const V2BccSideInputs &cfg)
{
   if(cfg.layer_count == 0)
      return V2_Bcc_OrderTicketLive(cfg.l0_ticket);
   return V2_Bcc_OrderTicketLive(cfg.add_ticket);
}

void V2_Bcc_CheckOneLegged(const V2BccSideInputs &cfg,
                           V2BccRawFinding &findings[])
{
   if(cfg.halted)
      return;
   if(!V2_Bcc_ShouldExpectEntryPending(cfg))
      return;
   if(V2_Bcc_HasLiveEntryPending(cfg))
      return;

   V2BccRawFinding f;
   f.check = V2_BCC_CHECK_ONE_LEGGED;
   f.ticket = (cfg.layer_count == 0) ? cfg.l0_ticket : cfg.add_ticket;
   f.magic = cfg.entry_magic;
   f.detail = (cfg.layer_count == 0) ? "flat_side_no_l0_pending" : "stacked_side_no_add_pending";
   const int n = ArraySize(findings);
   ArrayResize(findings, n + 1);
   findings[n] = f;
}

void V2_Bcc_CheckDuplicatePending(const V2BccSideInputs &cfg,
                                  V2BccRawFinding &findings[])
{
   if(cfg.halted)
      return;
   const int live = V2_Bcc_CountEntryPendings(cfg);
   const int expected = V2_Bcc_ExpectedEntryPendingCount(cfg);
   if(live <= expected)
      return;

   V2BccRawFinding f;
   f.check = V2_BCC_CHECK_DUPLICATE;
   f.ticket = 0;
   f.magic = cfg.entry_magic;
   f.detail = StringFormat("entry_pendings=%d expected<=%d", live, expected);
   const int n = ArraySize(findings);
   ArrayResize(findings, n + 1);
   findings[n] = f;
}

void V2_Bcc_MergeFindings(V2BccRawFinding &dest[], const V2BccRawFinding &src[])
{
   for(int i = 0; i < ArraySize(src); i++) {
      bool dup = false;
      for(int j = 0; j < ArraySize(dest); j++) {
         if(V2_Bcc_RawFindingEqual(dest[j], src[i])) {
            dup = true;
            break;
         }
      }
      if(dup)
         continue;
      const int n = ArraySize(dest);
      ArrayResize(dest, n + 1);
      dest[n] = src[i];
   }
}

void V2_Bcc_CollectTier3Findings(const V2BccSideInputs &cfg,
                                 V2BccSideRuntime &rt,
                                 V2BccRawFinding &findings[])
{
   ArrayResize(findings, 0);

   V2BccExitItem tier2_candidates[];
   V2_Bcc_Tier1ScanOrphans(cfg, rt, tier2_candidates);

   V2BccRawFinding orphan_findings[];
   V2_Bcc_Tier2ResolveOrphans(cfg, tier2_candidates, orphan_findings);
   V2_Bcc_MergeFindings(findings, orphan_findings);

   V2BccRawFinding naked_findings[];
   V2_Bcc_CheckNakedPositions(cfg, naked_findings);
   V2_Bcc_MergeFindings(findings, naked_findings);

   V2BccRawFinding one_legged[];
   V2_Bcc_CheckOneLegged(cfg, one_legged);
   V2_Bcc_MergeFindings(findings, one_legged);

   V2BccRawFinding duplicate[];
   V2_Bcc_CheckDuplicatePending(cfg, duplicate);
   V2_Bcc_MergeFindings(findings, duplicate);
}

void V2_Bcc_DebounceFindings(V2BccSideRuntime &rt,
                             const V2BccRawFinding &current[],
                             const V2BccSideInputs &cfg,
                             const V2CloseByTask &closeby_queue[],
                             string &alerts[])
{
   V2BccDebouncedFinding next[];
   ArrayResize(next, 0);

   for(int i = 0; i < ArraySize(current); i++) {
      if(V2_Bcc_ShouldSuppressCloseBy(current[i], closeby_queue))
         continue;

      int streak = 1;
      for(int j = 0; j < ArraySize(rt.pending); j++) {
         if(V2_Bcc_FindingKeyEqual(current[i], rt.pending[j])) {
            streak = rt.pending[j].streak + 1;
            break;
         }
      }

      const int n = ArraySize(next);
      ArrayResize(next, n + 1);
      next[n].check = current[i].check;
      next[n].ticket = current[i].ticket;
      next[n].magic = current[i].magic;
      next[n].detail = current[i].detail;
      next[n].streak = streak;

      if(streak >= 2) {
         const string msg = V2_Bcc_FormatAlert(cfg.side_label, current[i].check,
                                               current[i].ticket, current[i].magic,
                                               current[i].detail);
         V2_PushSystemAlert(alerts, msg);
         Print(msg);
      }
   }

   ArrayResize(rt.pending, ArraySize(next));
   for(int i = 0; i < ArraySize(next); i++)
      rt.pending[i] = next[i];
}

void V2_Bcc_RunSideTier1(const V2BccSideInputs &cfg,
                         V2BccSideRuntime &rt)
{
   V2BccExitItem tier2_candidates[];
   V2_Bcc_Tier1ScanOrphans(cfg, rt, tier2_candidates);
}

void V2_Bcc_RunSideTier2IfPending(const V2BccSideInputs &cfg,
                                  V2BccSideRuntime &rt,
                                  const V2CloseByTask &closeby_queue[],
                                  string &alerts[])
{
   if(!rt.tier2_pending)
      return;

   V2BccExitItem tier2_candidates[];
   V2_Bcc_Tier1ScanOrphans(cfg, rt, tier2_candidates);

   V2BccRawFinding findings[];
   V2_Bcc_Tier2ResolveOrphans(cfg, tier2_candidates, findings);

   V2_Bcc_DebounceFindings(rt, findings, cfg, closeby_queue, alerts);
   rt.tier2_pending = false;
}

int V2_Bcc_CountPendingFindings(const V2BccSideRuntime &rt, const int min_streak)
{
   int count = 0;
   for(int i = 0; i < ArraySize(rt.pending); i++) {
      if(rt.pending[i].streak >= min_streak)
         count++;
   }
   return count;
}

int V2_Bcc_RunSideTier3Sweep(const V2BccSideInputs &cfg,
                             V2BccSideRuntime &rt,
                             const V2CloseByTask &closeby_queue[],
                             string &alerts[])
{
   V2BccRawFinding findings[];
   V2_Bcc_CollectTier3Findings(cfg, rt, findings);
   V2_Bcc_DebounceFindings(rt, findings, cfg, closeby_queue, alerts);
   rt.last_tier3_sweep = TimeCurrent();
   return V2_Bcc_CountPendingFindings(rt, 1);
}

void V2_Bcc_RunSideInitPass(const V2BccSideInputs &cfg,
                            V2BccSideRuntime &rt,
                            const V2CloseByTask &closeby_queue[],
                            string &alerts[])
{
   if(cfg.halted)
      return;
   V2_Bcc_RunSideTier3Sweep(cfg, rt, closeby_queue, alerts);
}

#endif // FXMATRIX_V2_BCC_MQH
