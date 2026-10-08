//+------------------------------------------------------------------+
//| fxgrind_replay_core.mqh — replay harness broker + event loop     |
//+------------------------------------------------------------------+
#ifndef FXGRIND_REPLAY_CORE_MQH
#define FXGRIND_REPLAY_CORE_MQH

#include "grind_engine.mqh"
#include "grind_archive.mqh"
#include "grind_pnl.mqh"

const string RPL_MIRRORS_EA = "5bb5fdb";
const ulong  RPL_MAGIC_DEFAULT = 22260201UL;
const string RPL_SLOT_DEFAULT = "OPT";
const double RPL_LOTS_DEFAULT = 0.01;
const string RPL_DATA_PATH = "D:\\mt5-replay";

struct RplTick
{
   long   time_msc;
   double bid;
   double ask;
};

struct RplRealDeal
{
   long   time_ms;
   long   entry_type;
   long   deal_type;
   string role;
   string side;
   int    layer;
   double price;
   ulong  position_id;
};

struct RplSegmentConfig
{
   int    seg_id;
   string instance;
   ulong  magic;
   long   from_ms;
   long   to_ms;
   double width_l;
   double width_s;
   double add_l;
   double add_s;
   double exit_l;
   double exit_s;
   int    cap;
   double stranded;
   double deadband;
   bool   lattice;
   bool   reroll;
   int    gate;
   bool   carry;
   bool   fill_time_place;
   int    reserve;
   bool   sync;
   bool   skip_lattice_preload;
};

struct RplDealRow
{
   int    seg_id;
   int    sync_idx;
   long   time_ms;
   ulong  deal;
   ulong  order;
   ulong  position;
   long   entry_type;
   long   deal_type;
   string role;
   string side;
   int    layer;
   double price;
};

struct RplEventRow
{
   int    seg_id;
   int    sync_idx;
   long   time_ms;
   string kind;
   string code;
   string json;
};

struct RplBrokerOnlyOrder
{
   ulong  ticket;
   long   type;
   double price;
   long   placed_ms;
};

struct RplPosMeta
{
   ulong  ticket;
   double entry;
   double swap;
   double volume;
   long   open_ms;
   bool   is_long;
};

struct RplOrderPlaced
{
   ulong ticket;
   long  placed_ms;
};

struct RplSwapNight
{
   string date;
   double points_long;
   double points_short;
   double mult;
};

struct RplTrueLayer
{
   string side;
   int    layer;
   double entry;
   ulong  ticket;
   double swap;
   double volume;
   long   open_ms;
   double vl;
};

struct RplCbTask
{
   ulong t1;
   ulong t2;
};

RplDealRow       g_rpl_deals[];
RplEventRow      g_rpl_events[];
bool             g_rpl_aborted = false;
string           g_rpl_abort_reason = "";
ulong            g_rpl_next_pos_id = 900000001UL;
ulong            g_rpl_next_deal_id = 800000001UL;
ulong            g_rpl_next_broker_ticket = 9500UL;
int              g_rpl_sync_idx = -1;
long             g_rpl_last_timer_ms = 0;
RplSegmentConfig g_rpl_cfg;
RplBrokerOnlyOrder g_rpl_broker_only[];
int              g_rpl_broker_only_count = 0;
RplPosMeta       g_rpl_pos_meta[];
int              g_rpl_pos_meta_count = 0;
RplOrderPlaced   g_rpl_order_placed[];
int              g_rpl_order_placed_count = 0;
RplSwapNight     g_rpl_swaps[];
int              g_rpl_swap_count = 0;
RplRealDeal      g_rpl_real_deals[];
int              g_rpl_real_deal_count = 0;
int              g_rpl_real_applied = 0;
RplTrueLayer     g_rpl_true_book[];
int              g_rpl_true_book_count = 0;
string           g_rpl_last_scalp_json = "";
bool             g_rpl_seeded = false;
long             g_rpl_newest_seed_open_ms = 0;

//+------------------------------------------------------------------+
string Rpl_NormalizeDataPath(string path)
{
   StringReplace(path, "/", "\\");
   while(StringLen(path) > 0 && StringGetCharacter(path, StringLen(path) - 1) == '\\')
      path = StringSubstr(path, 0, StringLen(path) - 1);
   return path;
}

//+------------------------------------------------------------------+
bool Rpl_SafeToRun(const string data_path, const bool trade_allowed, const long login, const string server)
{
   if(Rpl_NormalizeDataPath(data_path) != Rpl_NormalizeDataPath(RPL_DATA_PATH))
      return false;
   if(trade_allowed)
      return false;
   if(login != 53077984)
      return false;
   if(server != "ICMarketsSC-Demo")
      return false;
   return true;
}

//+------------------------------------------------------------------+
bool Rpl_CheckSafetyForRun()
{
   const bool trade_allowed = (AccountInfoInteger(ACCOUNT_TRADE_ALLOWED) != 0);
   if(!Rpl_SafeToRun(TerminalInfoString(TERMINAL_DATA_PATH), trade_allowed,
                     AccountInfoInteger(ACCOUNT_LOGIN), AccountInfoString(ACCOUNT_SERVER))) {
      g_rpl_aborted = true;
      g_rpl_abort_reason = "SAFE_S1";
      Print("RPL|ABORT|SAFE_S1");
      return false;
   }
   if(_Symbol != "EURUSD") {
      g_rpl_aborted = true;
      g_rpl_abort_reason = "SAFE_S2_SYMBOL";
      Print("RPL|ABORT|SAFE_S2_SYMBOL");
      return false;
   }
   const long mode = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE);
   if(!Grind_MarketTradeModeFull(mode)) {
      g_rpl_aborted = true;
      g_rpl_abort_reason = "SAFE_S2_MODE";
      Print("RPL|ABORT|SAFE_S2_MODE");
      return false;
   }
   return true;
}

//+------------------------------------------------------------------+
void Rpl_Abort(const string reason)
{
   g_rpl_aborted = true;
   g_rpl_abort_reason = reason;
   Print("RPL|ABORT|", reason);
}

//+------------------------------------------------------------------+
int Rpl_DeleteGrindGlobalVariables()
{
   int deleted = 0;
   const int total = GlobalVariablesTotal();
   for(int i = total - 1; i >= 0; i--) {
      const string name = GlobalVariableName(i);
      if(StringFind(name, "GRIND") == 0) {
         if(GlobalVariableDel(name))
            deleted++;
      }
   }
   return deleted;
}

//+------------------------------------------------------------------+
void Rpl_ResetHorizonSide(GrindSideState &side)
{
   side.add_held = false;
   side.add_held_target = 0.0;
   side.entry_transitions_used = 0;
   side.add_gap_missed = 0;
   side.entry_transitions_exhausted = false;
   side.add_gap_beyond_target = false;
   side.exit_clamped_promotions = 0;
}

//+------------------------------------------------------------------+
void Rpl_ClearCarryGvs()
{
   GlobalVariablesDeleteAll("GRIND_CARRY_SHIFT_");
   GlobalVariablesDeleteAll("GRIND_CARRY_ACCRUED_");
   GlobalVariablesDeleteAll(GRIND_CARRY_RELEASE_PREFIX);
   GlobalVariablesDeleteAll("GRIND_EJECT_");
   GlobalVariablesDeleteAll("GRIND_VL_");
}

//+------------------------------------------------------------------+
void Rpl_ClearSideState()
{
   Rpl_ClearCarryGvs();
   ArrayResize(g_grind_long.layers, 0);
   ArrayResize(g_grind_short.layers, 0);
   g_grind_long.l0_pending_ticket = 0;
   g_grind_long.add_pending_ticket = 0;
   Rpl_ResetHorizonSide(g_grind_long);
   g_grind_short.l0_pending_ticket = 0;
   g_grind_short.add_pending_ticket = 0;
   Rpl_ResetHorizonSide(g_grind_short);
   g_grind_fill_count = 0;
   g_grind_scalp_count = 0;
   g_grind_halted = false;
   ArrayResize(g_grind_processed_deals, 0);
   g_grind_processed_deal_count = 0;
   Grind_ScalpEventReset();
}

//+------------------------------------------------------------------+
void Rpl_ResetAll()
{
   Grind_MarketTestReset();
   Grind_OrderTestReset();
   Grind_CloseByTestReset();
   Grind_DealTestReset();
   Grind_HistTestReset();
   Grind_CarryTestReset();
   Grind_LatticeResetBackoff();
   Grind_LatticeTestTicksReset();
   Grind_ArchiveTestReset();
   Grind_QuarantineReset();
   Grind_Adr152ResetDueFlags();
   Grind_PnlReset();
   Rpl_ClearSideState();
   ArrayResize(g_rpl_deals, 0);
   ArrayResize(g_rpl_events, 0);
   ArrayResize(g_rpl_broker_only, 0);
   g_rpl_broker_only_count = 0;
   ArrayResize(g_rpl_pos_meta, 0);
   g_rpl_pos_meta_count = 0;
   ArrayResize(g_rpl_order_placed, 0);
   g_rpl_order_placed_count = 0;
   ArrayResize(g_rpl_real_deals, 0);
   g_rpl_real_deal_count = 0;
   g_rpl_real_applied = 0;
   ArrayResize(g_rpl_true_book, 0);
   g_rpl_true_book_count = 0;
   g_rpl_aborted = false;
   g_rpl_abort_reason = "";
   g_rpl_sync_idx = -1;
   g_rpl_last_timer_ms = 0;
   g_rpl_last_scalp_json = "";
   g_rpl_seeded = false;
   g_rpl_newest_seed_open_ms = 0;
   g_rpl_next_pos_id = 900000001UL;
   g_rpl_next_deal_id = 800000001UL;
   g_rpl_next_broker_ticket = 9500UL;
   g_grind_order_test_active = true;
   g_grind_closeby_test_active = true;
   g_grind_deal_test_active = true;
   g_grind_closeby_test_send_ok = true;
   g_grind_closeby_test_send_retcode = TRADE_RETCODE_DONE;
   g_grind_market_test_active = true;
   g_grind_pnl_test_active = true;
}

//+------------------------------------------------------------------+
void Rpl_SetTestSwaps(const string date, const double pl, const double ps, const double mult)
{
   ArrayResize(g_rpl_swaps, 1);
   g_rpl_swap_count = 1;
   g_rpl_swaps[0].date = date;
   g_rpl_swaps[0].points_long = pl;
   g_rpl_swaps[0].points_short = ps;
   g_rpl_swaps[0].mult = mult;
}

//+------------------------------------------------------------------+
void Rpl_ConfigureEngine(RplSegmentConfig &cfg)
{
   g_rpl_cfg = cfg;
   g_grind_telemetry_instance = cfg.instance;
   g_grind_recon_magic = cfg.magic;
   g_grind_recon_slot = RPL_SLOT_DEFAULT;
   g_grind_recon_exit_pips = cfg.exit_l;
   g_grind_recon_exit_pips_short = cfg.exit_s;
   g_grind_recon_max_layers = cfg.cap;
   Grind_EngineConfigureAdr152(cfg.fill_time_place, cfg.reserve, 0.0);
   Grind_ApiLimitsSet(1000000, 999000);
   g_grind_archive_enabled = true;
   g_grind_archive_queue_max = 1000000;
   g_grind_breaker_enabled = false;
   g_grind_breaker_gated = false;
   g_grind_carry_test_rollover_active = true;
   g_grind_carry_test_rollover_day = 3;
   Grind_Adr152ResetDueFlags();
}

//+------------------------------------------------------------------+
void Rpl_TrackOrderPlaced(const ulong ticket, const long placed_ms)
{
   for(int i = 0; i < g_rpl_order_placed_count; i++) {
      if(g_rpl_order_placed[i].ticket == ticket)
         return;
   }
   ArrayResize(g_rpl_order_placed, g_rpl_order_placed_count + 1);
   g_rpl_order_placed[g_rpl_order_placed_count].ticket = ticket;
   g_rpl_order_placed[g_rpl_order_placed_count].placed_ms = placed_ms;
   g_rpl_order_placed_count++;
}

//+------------------------------------------------------------------+
long Rpl_OrderPlacedMs(const ulong ticket)
{
   for(int i = 0; i < g_rpl_order_placed_count; i++) {
      if(g_rpl_order_placed[i].ticket == ticket)
         return g_rpl_order_placed[i].placed_ms;
   }
   return 0;
}

//+------------------------------------------------------------------+
void Rpl_ScanNewOrders(const long tick_ms)
{
   for(int i = 0; i < g_grind_order_test_count; i++) {
      Rpl_TrackOrderPlaced(g_grind_order_test_records[i].ticket, tick_ms);
   }
}

//+------------------------------------------------------------------+
void Rpl_AddPosMeta(const ulong ticket, const double entry, const double swap,
                    const double volume, const long open_ms, const bool is_long)
{
   ArrayResize(g_rpl_pos_meta, g_rpl_pos_meta_count + 1);
   g_rpl_pos_meta[g_rpl_pos_meta_count].ticket = ticket;
   g_rpl_pos_meta[g_rpl_pos_meta_count].entry = entry;
   g_rpl_pos_meta[g_rpl_pos_meta_count].swap = swap;
   g_rpl_pos_meta[g_rpl_pos_meta_count].volume = volume;
   g_rpl_pos_meta[g_rpl_pos_meta_count].open_ms = open_ms;
   g_rpl_pos_meta[g_rpl_pos_meta_count].is_long = is_long;
   g_rpl_pos_meta_count++;
}

//+------------------------------------------------------------------+
bool Rpl_FindPosMeta(const ulong ticket, RplPosMeta &out)
{
   for(int i = 0; i < g_rpl_pos_meta_count; i++) {
      if(g_rpl_pos_meta[i].ticket == ticket) {
         out = g_rpl_pos_meta[i];
         return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
void Rpl_RemovePosMeta(const ulong ticket)
{
   for(int i = 0; i < g_rpl_pos_meta_count; i++) {
      if(g_rpl_pos_meta[i].ticket != ticket)
         continue;
      for(int j = i; j < g_rpl_pos_meta_count - 1; j++)
         g_rpl_pos_meta[j] = g_rpl_pos_meta[j + 1];
      g_rpl_pos_meta_count--;
      ArrayResize(g_rpl_pos_meta, g_rpl_pos_meta_count);
      return;
   }
}

//+------------------------------------------------------------------+
double Rpl_GetPositionSwap(const ulong ticket)
{
   RplPosMeta m;
   if(Rpl_FindPosMeta(ticket, m))
      return m.swap;
   return 0.0;
}

//+------------------------------------------------------------------+
void Rpl_AddCloseByPos(const ulong ticket, const bool is_long)
{
   ArrayResize(g_grind_closeby_test_positions, g_grind_closeby_test_position_count + 1);
   g_grind_closeby_test_positions[g_grind_closeby_test_position_count].ticket = ticket;
   g_grind_closeby_test_positions[g_grind_closeby_test_position_count].symbol = _Symbol;
   g_grind_closeby_test_positions[g_grind_closeby_test_position_count].type =
      is_long ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
   g_grind_closeby_test_position_count++;
}

//+------------------------------------------------------------------+
void Rpl_RemoveCloseByPos(const ulong ticket)
{
   for(int i = 0; i < g_grind_closeby_test_position_count; i++) {
      if(g_grind_closeby_test_positions[i].ticket != ticket)
         continue;
      for(int j = i; j < g_grind_closeby_test_position_count - 1; j++)
         g_grind_closeby_test_positions[j] = g_grind_closeby_test_positions[j + 1];
      g_grind_closeby_test_position_count--;
      ArrayResize(g_grind_closeby_test_positions, g_grind_closeby_test_position_count);
      return;
   }
}

//+------------------------------------------------------------------+
void Rpl_RemovePositionTicket(const ulong ticket)
{
   for(int i = 0; i < g_grind_position_test_count; i++) {
      if(g_grind_position_test_tickets[i] != ticket)
         continue;
      for(int j = i; j < g_grind_position_test_count - 1; j++)
         g_grind_position_test_tickets[j] = g_grind_position_test_tickets[j + 1];
      g_grind_position_test_count--;
      ArrayResize(g_grind_position_test_tickets, g_grind_position_test_count);
      return;
   }
}

//+------------------------------------------------------------------+
void Rpl_AppendLayerManual(GrindSideState &side,
                           const bool is_long,
                           const int layer_index,
                           const double entry,
                           const ulong pos_ticket)
{
   const int n = ArraySize(side.layers);
   ArrayResize(side.layers, n + 1);
   side.layers[n].entry_price = entry;
   side.layers[n].layer_index = layer_index;
   side.layers[n].position_ticket = pos_ticket;
   side.layers[n].exit_order_ticket = 0;
   side.layers[n].exit_position_ticket = 0;
   side.layers[n].exit_target = 0.0;
}

//+------------------------------------------------------------------+
void Rpl_TrueBookAdd(const string side, const int layer, const double entry, const ulong ticket,
                     const double swap, const double volume, const long open_ms, const double vl)
{
   ArrayResize(g_rpl_true_book, g_rpl_true_book_count + 1);
   g_rpl_true_book[g_rpl_true_book_count].side = side;
   g_rpl_true_book[g_rpl_true_book_count].layer = layer;
   g_rpl_true_book[g_rpl_true_book_count].entry = entry;
   g_rpl_true_book[g_rpl_true_book_count].ticket = ticket;
   g_rpl_true_book[g_rpl_true_book_count].swap = swap;
   g_rpl_true_book[g_rpl_true_book_count].volume = volume;
   g_rpl_true_book[g_rpl_true_book_count].open_ms = open_ms;
   g_rpl_true_book[g_rpl_true_book_count].vl = vl;
   g_rpl_true_book_count++;
}

//+------------------------------------------------------------------+
void Rpl_SeedLayer(const string side,
                   const int layer_index,
                   const double entry,
                   const long open_ms,
                   const ulong ticket,
                   const double vl,
                   const double swap,
                   const double volume)
{
   const bool is_long = (side == "L");
   if(is_long)
      Rpl_AppendLayerManual(g_grind_long, true, layer_index, entry, ticket);
   else
      Rpl_AppendLayerManual(g_grind_short, false, layer_index, entry, ticket);
   Grind_PositionTestAdd(ticket);
   Rpl_AddCloseByPos(ticket, is_long);
   Grind_CarryTestSetPosition(ticket, swap, volume, open_ms / 1000);
   Rpl_AddPosMeta(ticket, entry, swap, volume, open_ms, is_long);
   if(vl > 0.0)
      Grind_VLSet(ticket, vl);
   if(open_ms > g_rpl_newest_seed_open_ms)
      g_rpl_newest_seed_open_ms = open_ms;
   g_rpl_seeded = true;
   if(g_rpl_cfg.sync)
      Rpl_TrueBookAdd(side, layer_index, entry, ticket, swap, volume, open_ms, vl);
}

//+------------------------------------------------------------------+
void Rpl_PreloadLattice(const RplSegmentConfig &cfg)
{
   if(cfg.skip_lattice_preload || !g_rpl_seeded)
      return;
   const long start_ms = MathMax(g_rpl_newest_seed_open_ms, cfg.from_ms - 86400000L);
   for(long ms = start_ms; ms < cfg.from_ms; ms += 1000) {
      const double bid = 1.09900;
      const double ask = 1.09902;
      Grind_LatticeTestAddTick((datetime)(ms / 1000), bid, ask);
   }
}

//+------------------------------------------------------------------+
void Rpl_ReplayAppendDeal(const ulong deal_ticket,
                          const string comment,
                          const long entry_type,
                          const ulong order_ticket,
                          const ulong position_id,
                          const double profit,
                          const double swap,
                          const double commission,
                          const double price,
                          const datetime deal_time,
                          const ulong magic)
{
   ArrayResize(g_grind_deal_test_records, g_grind_deal_test_count + 1);
   g_grind_deal_test_records[g_grind_deal_test_count].deal_ticket = deal_ticket;
   g_grind_deal_test_records[g_grind_deal_test_count].symbol = _Symbol;
   g_grind_deal_test_records[g_grind_deal_test_count].magic = (long)magic;
   g_grind_deal_test_records[g_grind_deal_test_count].comment = comment;
   g_grind_deal_test_records[g_grind_deal_test_count].entry_type = entry_type;
   g_grind_deal_test_records[g_grind_deal_test_count].order_ticket = order_ticket;
   g_grind_deal_test_records[g_grind_deal_test_count].position_id = position_id;
   g_grind_deal_test_records[g_grind_deal_test_count].price = price;
   g_grind_deal_test_records[g_grind_deal_test_count].profit = profit;
   g_grind_deal_test_records[g_grind_deal_test_count].swap = swap;
   g_grind_deal_test_records[g_grind_deal_test_count].commission = commission;
   g_grind_deal_test_records[g_grind_deal_test_count].deal_time = deal_time;
   g_grind_deal_test_count++;
}

//+------------------------------------------------------------------+
void Rpl_WriteDealOutput(const long time_ms,
                         const ulong deal,
                         const ulong order,
                         const ulong position,
                         const long entry_type,
                         const string comment,
                         const double price)
{
   string slot, side, role;
   int layer;
   if(!GrindCommentParse(comment, slot, side, layer, role))
      return;
   const int n = ArraySize(g_rpl_deals);
   ArrayResize(g_rpl_deals, n + 1);
   g_rpl_deals[n].seg_id = g_rpl_cfg.seg_id;
   g_rpl_deals[n].sync_idx = g_rpl_sync_idx;
   g_rpl_deals[n].time_ms = time_ms;
   g_rpl_deals[n].deal = deal;
   g_rpl_deals[n].order = order;
   g_rpl_deals[n].position = position;
   g_rpl_deals[n].entry_type = entry_type;
   g_rpl_deals[n].deal_type = (entry_type == DEAL_ENTRY_OUT_BY) ? DEAL_TYPE_SELL : DEAL_TYPE_BUY;
   g_rpl_deals[n].role = role;
   g_rpl_deals[n].side = side;
   g_rpl_deals[n].layer = layer;
   g_rpl_deals[n].price = price;
}

//+------------------------------------------------------------------+
void Rpl_WriteEventOutput(const long time_ms, const string kind, const string code, const string json)
{
   const int n = ArraySize(g_rpl_events);
   ArrayResize(g_rpl_events, n + 1);
   g_rpl_events[n].seg_id = g_rpl_cfg.seg_id;
   g_rpl_events[n].sync_idx = g_rpl_sync_idx;
   g_rpl_events[n].time_ms = time_ms;
   g_rpl_events[n].kind = kind;
   g_rpl_events[n].code = code;
   g_rpl_events[n].json = json;
}

//+------------------------------------------------------------------+
bool Rpl_CheckSeams()
{
   return g_grind_order_test_active && g_grind_closeby_test_active && g_grind_deal_test_active;
}

//+------------------------------------------------------------------+
long Rpl_OldestLatticeMs()
{
   long oldest = 0;
   for(int i = 0; i < ArraySize(g_grind_vl_test_tick_msc); i++) {
      if(i == 0 || g_grind_vl_test_tick_msc[i] < oldest)
         oldest = g_grind_vl_test_tick_msc[i];
   }
   return oldest;
}

//+------------------------------------------------------------------+
void Rpl_LatticeHistoryCheck(const bool is_long)
{
   const long from_msc = is_long ? g_grind_vl_from_msc_long : g_grind_vl_from_msc_short;
   const long oldest = Rpl_OldestLatticeMs();
   if(oldest > 0 && from_msc < oldest) {
      Print("RPL|ABORT|LATTICE_HISTORY|from=", from_msc, "|oldest=", oldest);
      Rpl_Abort("LATTICE_HISTORY");
   }
}

//+------------------------------------------------------------------+
void Rpl_PruneLattice(const long tick_ms)
{
   const long cutoff = tick_ms - 300000L;
   long kept_msc[];
   double kept_bid[];
   double kept_ask[];
   int n = 0;
   for(int i = 0; i < ArraySize(g_grind_vl_test_tick_msc); i++) {
      if(g_grind_vl_test_tick_msc[i] >= cutoff) {
         ArrayResize(kept_msc, n + 1);
         ArrayResize(kept_bid, n + 1);
         ArrayResize(kept_ask, n + 1);
         kept_msc[n] = g_grind_vl_test_tick_msc[i];
         kept_bid[n] = g_grind_vl_test_tick_bid[i];
         kept_ask[n] = g_grind_vl_test_tick_ask[i];
         n++;
      }
   }
   ArrayResize(g_grind_vl_test_tick_msc, n);
   ArrayResize(g_grind_vl_test_tick_bid, n);
   ArrayResize(g_grind_vl_test_tick_ask, n);
   for(int i = 0; i < n; i++) {
      g_grind_vl_test_tick_msc[i] = kept_msc[i];
      g_grind_vl_test_tick_bid[i] = kept_bid[i];
      g_grind_vl_test_tick_ask[i] = kept_ask[i];
   }
}

//+------------------------------------------------------------------+
void Rpl_ApplySwapRollover(const long tick_ms)
{
   const datetime day = (datetime)(tick_ms / 1000);
   MqlDateTime dt;
   TimeToStruct(day, dt);
   const string dkey = StringFormat("%04d.%02d.%02d", dt.year, dt.mon, dt.day);
   double pl = 0.0, ps = 0.0, mult = 1.0;
   bool found = false;
   for(int i = 0; i < g_rpl_swap_count; i++) {
      if(g_rpl_swaps[i].date == dkey) {
         pl = g_rpl_swaps[i].points_long;
         ps = g_rpl_swaps[i].points_short;
         mult = g_rpl_swaps[i].mult;
         found = true;
         break;
      }
   }
   if(!found)
      return;
   const double tick_val = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   for(int i = 0; i < g_rpl_pos_meta_count; i++) {
      const double points = g_rpl_pos_meta[i].is_long ? pl : ps;
      g_rpl_pos_meta[i].swap += points * mult * tick_val * g_rpl_pos_meta[i].volume;
      Grind_CarryTestSetPosition(g_rpl_pos_meta[i].ticket,
                                 g_rpl_pos_meta[i].swap,
                                 g_rpl_pos_meta[i].volume,
                                 g_rpl_pos_meta[i].open_ms / 1000);
   }
}

//+------------------------------------------------------------------+
void Rpl_DrainOutputs(const long tick_ms)
{
   for(int i = 0; i < ArraySize(g_grind_archive_queue); i++) {
      const string line = g_grind_archive_queue[i];
      int p = StringFind(line, "\"code\":\"");
      string code = "";
      if(p >= 0) {
         p += 8;
         const int p2 = StringFind(line, "\"", p);
         if(p2 > p)
            code = StringSubstr(line, p, p2 - p);
      }
      Rpl_WriteEventOutput(tick_ms, "ea_event", code, line);
   }
   ArrayResize(g_grind_archive_queue, 0);
   while(Grind_ScalpEventQueueSize() > 0) {
      g_rpl_last_scalp_json = Grind_ScalpEventQueuePeek();
      Rpl_WriteEventOutput(tick_ms, "scalp", "SCALP_CLOSED", g_rpl_last_scalp_json);
      for(int i = 1; i < g_grind_scalp_event_queue_count; i++)
         g_grind_scalp_event_queue[i - 1] = g_grind_scalp_event_queue[i];
      g_grind_scalp_event_queue_count--;
      ArrayResize(g_grind_scalp_event_queue, g_grind_scalp_event_queue_count);
   }
}

//+------------------------------------------------------------------+
void Rpl_SnapshotQueues(RplCbTask &out[], int &count)
{
   count = 0;
   ArrayResize(out, 0);
   for(int q = 0; q < 2; q++) {
      const int sz = (q == 0) ? ArraySize(g_grind_long_closeby_queue) : ArraySize(g_grind_short_closeby_queue);
      for(int i = 0; i < sz; i++) {
         ArrayResize(out, count + 1);
         out[count].t1 = (q == 0) ? g_grind_long_closeby_queue[i].ticket1 : g_grind_short_closeby_queue[i].ticket1;
         out[count].t2 = (q == 0) ? g_grind_long_closeby_queue[i].ticket2 : g_grind_short_closeby_queue[i].ticket2;
         count++;
      }
   }
}

//+------------------------------------------------------------------+
bool Rpl_QueueHasTask(const RplCbTask &tasks[], const int count, const ulong t1, const ulong t2)
{
   for(int i = 0; i < count; i++) {
      if(tasks[i].t1 == t1 && tasks[i].t2 == t2)
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
void Rpl_ProcessCloseByDone(const long tick_ms, const RplCbTask &before[], const int before_n)
{
   RplCbTask after[];
   int after_n = 0;
   Rpl_SnapshotQueues(after, after_n);
   for(int i = 0; i < before_n; i++) {
      if(Rpl_QueueHasTask(after, after_n, before[i].t1, before[i].t2))
         continue;
      RplPosMeta ent, ext;
      if(!Rpl_FindPosMeta(before[i].t1, ent))
         continue;
      if(!Rpl_FindPosMeta(before[i].t2, ext))
         continue;
      const double gross = (ext.entry - ent.entry) * (ent.is_long ? 1.0 : -1.0);
      const double tick_val = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      const double profit = (tick_size > 0.0) ? gross / tick_size * tick_val * ent.volume : 0.0;
      const ulong order_ticket = 700000001UL + (g_rpl_next_deal_id - 800000001UL);
      const datetime tsec = (datetime)(tick_ms / 1000);
      const ulong d1 = g_rpl_next_deal_id++;
      const ulong d2 = g_rpl_next_deal_id++;
      Rpl_ReplayAppendDeal(d1, "#" + IntegerToString((long)before[i].t1) + " by #" + IntegerToString((long)before[i].t2),
                           DEAL_ENTRY_OUT_BY, order_ticket, before[i].t1, profit * 0.5, ent.swap * 0.5, 0.0,
                           ent.entry, tsec, g_rpl_cfg.magic);
      Rpl_ReplayAppendDeal(d2, "#" + IntegerToString((long)before[i].t2) + " by #" + IntegerToString((long)before[i].t1),
                           DEAL_ENTRY_OUT_BY, order_ticket, before[i].t2, profit * 0.5, ext.swap * 0.5, 0.0,
                           ext.entry, tsec, g_rpl_cfg.magic);
      Rpl_WriteDealOutput(tick_ms, d1, order_ticket, before[i].t1, DEAL_ENTRY_OUT_BY,
                          GrindCommentBuild(RPL_SLOT_DEFAULT, ent.is_long ? "L" : "S", 0, "EXT"), ent.entry);
      Rpl_WriteDealOutput(tick_ms, d2, order_ticket, before[i].t2, DEAL_ENTRY_OUT_BY,
                          GrindCommentBuild(RPL_SLOT_DEFAULT, ent.is_long ? "L" : "S", 0, "EXT"), ext.entry);
      Grind_ProcessDeal(d1, g_rpl_cfg.magic, RPL_SLOT_DEFAULT, g_rpl_cfg.exit_l, g_rpl_cfg.add_l,
                        g_rpl_cfg.deadband, g_rpl_cfg.cap, RPL_LOTS_DEFAULT, g_rpl_cfg.exit_s, g_rpl_cfg.add_s);
      Grind_ProcessDeal(d2, g_rpl_cfg.magic, RPL_SLOT_DEFAULT, g_rpl_cfg.exit_l, g_rpl_cfg.add_l,
                        g_rpl_cfg.deadband, g_rpl_cfg.cap, RPL_LOTS_DEFAULT, g_rpl_cfg.exit_s, g_rpl_cfg.add_s);
      Rpl_RemoveCloseByPos(before[i].t1);
      Rpl_RemoveCloseByPos(before[i].t2);
      Rpl_RemovePositionTicket(before[i].t1);
      Rpl_RemovePositionTicket(before[i].t2);
      Rpl_RemovePosMeta(before[i].t1);
      Rpl_RemovePosMeta(before[i].t2);
   }
}

//+------------------------------------------------------------------+
void Rpl_FillsOnTick(const long tick_ms, const double bid, const double ask)
{
   for(int i = 0; i < g_grind_order_test_count; i++) {
      const ulong oticket = g_grind_order_test_records[i].ticket;
      const long placed = Rpl_OrderPlacedMs(oticket);
      if(placed <= 0 || placed >= tick_ms)
         continue;
      const long otype = g_grind_order_test_records[i].type;
      const double price = g_grind_order_test_records[i].price;
      bool touch = false;
      if(otype == ORDER_TYPE_BUY_LIMIT && ask <= price)
         touch = true;
      if(otype == ORDER_TYPE_SELL_LIMIT && bid >= price)
         touch = true;
      if(!touch)
         continue;
      const string comment = g_grind_order_test_records[i].comment;
      Grind_OrderTestRemove(oticket);
      const ulong pos_id = g_rpl_next_pos_id++;
      const ulong deal_id = g_rpl_next_deal_id++;
      const datetime tsec = (datetime)(tick_ms / 1000);
      const bool is_long_ent = (otype == ORDER_TYPE_BUY_LIMIT);
      Rpl_ReplayAppendDeal(deal_id, comment, DEAL_ENTRY_IN, oticket, pos_id, 0.0, 0.0, 0.0, price, tsec,
                           g_rpl_cfg.magic);
      Grind_PositionTestAdd(pos_id);
      Rpl_AddCloseByPos(pos_id, is_long_ent);
      Grind_CarryTestSetPosition(pos_id, 0.0, RPL_LOTS_DEFAULT, tick_ms / 1000);
      Rpl_AddPosMeta(pos_id, price, 0.0, RPL_LOTS_DEFAULT, tick_ms, is_long_ent);
      Rpl_WriteDealOutput(tick_ms, deal_id, oticket, pos_id, DEAL_ENTRY_IN, comment, price);
      Grind_ProcessDeal(deal_id, g_rpl_cfg.magic, RPL_SLOT_DEFAULT, g_rpl_cfg.exit_l, g_rpl_cfg.add_l,
                        g_rpl_cfg.deadband, g_rpl_cfg.cap, RPL_LOTS_DEFAULT, g_rpl_cfg.exit_s, g_rpl_cfg.add_s);
      i--;
   }
}

//+------------------------------------------------------------------+
void Rpl_RemoveLayerByTicket(GrindSideState &side, const ulong pos_ticket)
{
   for(int i = 0; i < ArraySize(side.layers); i++) {
      if(side.layers[i].position_ticket != pos_ticket)
         continue;
      if(side.layers[i].exit_order_ticket != 0)
         Grind_OrderTestRemove(side.layers[i].exit_order_ticket);
      for(int j = i; j < ArraySize(side.layers) - 1; j++)
         side.layers[j] = side.layers[j + 1];
      ArrayResize(side.layers, ArraySize(side.layers) - 1);
      return;
   }
}

//+------------------------------------------------------------------+
void Rpl_SyncResetToTrueBook()
{
   ulong keep_l0 = g_grind_long.l0_pending_ticket;
   ulong keep_add = g_grind_long.add_pending_ticket;
   ulong keep_l0s = g_grind_short.l0_pending_ticket;
   ulong keep_adds = g_grind_short.add_pending_ticket;
   for(int i = ArraySize(g_grind_long.layers) - 1; i >= 0; i--) {
      bool in_true = false;
      for(int t = 0; t < g_rpl_true_book_count; t++) {
         if(g_rpl_true_book[t].side == "L"
            && g_rpl_true_book[t].ticket == g_grind_long.layers[i].position_ticket) {
            in_true = true;
            break;
         }
      }
      if(!in_true)
         Rpl_RemoveLayerByTicket(g_grind_long, g_grind_long.layers[i].position_ticket);
   }
   for(int i = ArraySize(g_grind_short.layers) - 1; i >= 0; i--) {
      bool in_true = false;
      for(int t = 0; t < g_rpl_true_book_count; t++) {
         if(g_rpl_true_book[t].side == "S"
            && g_rpl_true_book[t].ticket == g_grind_short.layers[i].position_ticket) {
            in_true = true;
            break;
         }
      }
      if(!in_true)
         Rpl_RemoveLayerByTicket(g_grind_short, g_grind_short.layers[i].position_ticket);
   }
   for(int t = 0; t < g_rpl_true_book_count; t++) {
      bool present = false;
      const bool tb_long = (g_rpl_true_book[t].side == "L");
      const int layer_n = tb_long ? ArraySize(g_grind_long.layers) : ArraySize(g_grind_short.layers);
      for(int i = 0; i < layer_n; i++) {
         const ulong pt = tb_long ? g_grind_long.layers[i].position_ticket
                                : g_grind_short.layers[i].position_ticket;
         if(pt == g_rpl_true_book[t].ticket) {
            present = true;
            break;
         }
      }
      if(!present) {
         Rpl_SeedLayer(g_rpl_true_book[t].side, g_rpl_true_book[t].layer, g_rpl_true_book[t].entry,
                       g_rpl_true_book[t].open_ms, g_rpl_true_book[t].ticket, g_rpl_true_book[t].vl,
                       g_rpl_true_book[t].swap, g_rpl_true_book[t].volume);
      }
   }
   g_grind_long.l0_pending_ticket = keep_l0;
   g_grind_long.add_pending_ticket = keep_add;
   g_grind_short.l0_pending_ticket = keep_l0s;
   g_grind_short.add_pending_ticket = keep_adds;
   g_grind_start_add_reprice_long = true;
   g_grind_start_add_reprice_short = true;
}

//+------------------------------------------------------------------+
void Rpl_ApplySyncDealsUpTo(const long tick_ms)
{
   if(!g_rpl_cfg.sync)
      return;
   bool changed = false;
   while(g_rpl_real_applied < g_rpl_real_deal_count
         && g_rpl_real_deals[g_rpl_real_applied].time_ms <= tick_ms) {
      const RplRealDeal rd = g_rpl_real_deals[g_rpl_real_applied];
      if(rd.entry_type == DEAL_ENTRY_OUT_BY) {
         for(int i = g_rpl_true_book_count - 1; i >= 0; i--) {
            if(g_rpl_true_book[i].ticket == rd.position_id) {
               for(int j = i; j < g_rpl_true_book_count - 1; j++)
                  g_rpl_true_book[j] = g_rpl_true_book[j + 1];
               g_rpl_true_book_count--;
               break;
            }
         }
      }
      g_rpl_sync_idx = g_rpl_real_applied;
      g_rpl_real_applied++;
      changed = true;
   }
   if(changed)
      Rpl_SyncResetToTrueBook();
}

//+------------------------------------------------------------------+
void Rpl_ProcessOneTick(const RplTick &tick)
{
   if(g_rpl_aborted)
      return;
   const long t = tick.time_msc;
   static long last_day = 0;
   const datetime tsec = (datetime)(t / 1000);
   MqlDateTime dt;
   TimeToStruct(tsec, dt);
   const long day_key = dt.year * 10000 + dt.mon * 100 + dt.day;
   if(last_day != 0 && day_key != last_day)
      Rpl_ApplySwapRollover(t);
   last_day = day_key;

   Rpl_ApplySyncDealsUpTo(t);

   Grind_MarketTestSeed(tick.bid, tick.ask, 0, 0);
   Grind_MarketTestSeedTimeMsc(t);
   Grind_CarryTestSeedTick(t / 1000, tick.bid, tick.ask);
   g_grind_carry_test_server_time = t / 1000;
   Grind_LatticeTestAddTick(t / 1000, tick.bid, tick.ask);
   MqlTick live;
   if(SymbolInfoTick(_Symbol, live))
      g_grind_last_feed_tick_msc = live.time_msc;

   Rpl_FillsOnTick(t, tick.bid, tick.ask);
   if(g_rpl_aborted)
      return;

   RplCbTask cb_before[];
   int cb_n = 0;
   Rpl_SnapshotQueues(cb_before, cb_n);

   if(!Rpl_CheckSeams()) {
      Rpl_Abort("SEAMS");
      return;
   }

   const bool trkL0 = g_grind_vl_tracking_long;
   const bool trkS0 = g_grind_vl_tracking_short;

   Grind_ProcessCloseByQueues(g_rpl_cfg.magic, false);
   Grind_LatticeOnTick(g_rpl_cfg.magic, RPL_SLOT_DEFAULT, RPL_LOTS_DEFAULT, g_rpl_cfg.lattice,
                       g_rpl_cfg.exit_l, g_rpl_cfg.add_l, g_rpl_cfg.cap, false, t / 1000,
                       g_rpl_cfg.exit_s, g_rpl_cfg.add_s, g_rpl_cfg.reroll, g_rpl_cfg.gate);
   Grind_OnTickEngine(g_rpl_cfg.magic, RPL_SLOT_DEFAULT, g_rpl_cfg.width_l, g_rpl_cfg.exit_l, g_rpl_cfg.add_l,
                      g_rpl_cfg.stranded, g_rpl_cfg.deadband, g_rpl_cfg.cap, RPL_LOTS_DEFAULT,
                      g_rpl_cfg.width_s, g_rpl_cfg.add_s);

   if(!trkL0 && g_grind_vl_tracking_long)
      Rpl_LatticeHistoryCheck(true);
   if(!trkS0 && g_grind_vl_tracking_short)
      Rpl_LatticeHistoryCheck(false);

   Rpl_ScanNewOrders(t);
   Rpl_ProcessCloseByDone(t, cb_before, cb_n);

   if(g_rpl_last_timer_ms == 0 || t - g_rpl_last_timer_ms >= 60000) {
      Grind_CarryOnTimerStep(_Symbol, g_rpl_cfg.magic, g_rpl_cfg.exit_l, g_rpl_cfg.carry, t / 1000, g_rpl_cfg.exit_s);
      g_rpl_last_timer_ms = t;
   }

   Rpl_DrainOutputs(t);
   Rpl_PruneLattice(t);
}

//+------------------------------------------------------------------+
bool Rpl_RunTicks(const RplTick &ticks[], const int tick_count, RplSegmentConfig &cfg)
{
   g_rpl_cfg = cfg;
   if(g_rpl_seeded)
      Rpl_PreloadLattice(cfg);
   if(g_rpl_seeded) {
      g_grind_start_add_reprice_long = true;
      g_grind_start_add_reprice_short = true;
   }
   for(int i = 0; i < tick_count; i++) {
      if(ticks[i].time_msc < cfg.from_ms || ticks[i].time_msc >= cfg.to_ms)
         continue;
      Rpl_ProcessOneTick(ticks[i]);
      if(g_rpl_aborted)
         return false;
   }
   return !g_rpl_aborted;
}

//+------------------------------------------------------------------+
void Rpl_BrokerReset()
{
   ArrayResize(g_rpl_broker_only, 0);
   g_rpl_broker_only_count = 0;
   g_rpl_next_broker_ticket = 9500UL;
}

//+------------------------------------------------------------------+
ulong Rpl_BrokerPlaceLimit(const long type, const double price, const string comment, const long placed_ms)
{
   ArrayResize(g_rpl_broker_only, g_rpl_broker_only_count + 1);
   g_rpl_broker_only[g_rpl_broker_only_count].ticket = g_rpl_next_broker_ticket++;
   g_rpl_broker_only[g_rpl_broker_only_count].type = type;
   g_rpl_broker_only[g_rpl_broker_only_count].price = price;
   g_rpl_broker_only[g_rpl_broker_only_count].placed_ms = placed_ms;
   g_rpl_broker_only_count++;
   return g_rpl_broker_only[g_rpl_broker_only_count - 1].ticket;
}

//+------------------------------------------------------------------+
bool Rpl_BrokerFillOnTick(const long time_msc, const double bid, const double ask,
                          bool &filled, double &fill_price, long &fill_time_msc)
{
   filled = false;
   fill_price = 0.0;
   fill_time_msc = 0;
   for(int i = 0; i < g_rpl_broker_only_count; i++) {
      const long placed = g_rpl_broker_only[i].placed_ms;
      if(placed >= time_msc)
         continue;
      const long tp = g_rpl_broker_only[i].type;
      const double px = g_rpl_broker_only[i].price;
      if(tp == ORDER_TYPE_BUY_LIMIT && ask <= px) {
         filled = true;
         fill_price = px;
         fill_time_msc = time_msc;
         for(int j = i; j < g_rpl_broker_only_count - 1; j++)
            g_rpl_broker_only[j] = g_rpl_broker_only[j + 1];
         g_rpl_broker_only_count--;
         ArrayResize(g_rpl_broker_only, g_rpl_broker_only_count);
         return true;
      }
      if(tp == ORDER_TYPE_SELL_LIMIT && bid >= px) {
         filled = true;
         fill_price = px;
         fill_time_msc = time_msc;
         for(int j = i; j < g_rpl_broker_only_count - 1; j++)
            g_rpl_broker_only[j] = g_rpl_broker_only[j + 1];
         g_rpl_broker_only_count--;
         ArrayResize(g_rpl_broker_only, g_rpl_broker_only_count);
         return true;
      }
   }
   return true;
}

//+------------------------------------------------------------------+
int Rpl_DealsCount() { return ArraySize(g_rpl_deals); }

//+------------------------------------------------------------------+
bool Rpl_GetDealRow(const int index, RplDealRow &out)
{
   if(index < 0 || index >= ArraySize(g_rpl_deals))
      return false;
   out = g_rpl_deals[index];
   return true;
}

//+------------------------------------------------------------------+
int Rpl_EventsCount() { return ArraySize(g_rpl_events); }

//+------------------------------------------------------------------+
bool Rpl_GetEventRow(const int index, RplEventRow &out)
{
   if(index < 0 || index >= ArraySize(g_rpl_events))
      return false;
   out = g_rpl_events[index];
   return true;
}

//+------------------------------------------------------------------+
int Rpl_CountEventsWithCode(const string code)
{
   int n = 0;
   for(int i = 0; i < ArraySize(g_rpl_events); i++) {
      if(g_rpl_events[i].code == code)
         n++;
   }
   return n;
}

//+------------------------------------------------------------------+
int Rpl_OrderSeamCount() { return g_grind_order_test_count; }

//+------------------------------------------------------------------+
bool Rpl_FindOrderByRoleLayer(const string side_letter, const int layer, const string role,
                              double &price_out, ulong &ticket_out)
{
   for(int i = 0; i < g_grind_order_test_count; i++) {
      string slot, side, r;
      int lyr;
      if(!GrindCommentParse(g_grind_order_test_records[i].comment, slot, side, lyr, r))
         continue;
      if(side == side_letter && lyr == layer && r == role) {
         price_out = g_grind_order_test_records[i].price;
         ticket_out = g_grind_order_test_records[i].ticket;
         return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
bool Rpl_OrderExistsForLayer(const string side_letter, const int layer, const string role)
{
   double p;
   ulong t;
   return Rpl_FindOrderByRoleLayer(side_letter, layer, role, p, t);
}

//+------------------------------------------------------------------+
int Rpl_LongDepth() { return ArraySize(g_grind_long.layers); }

//+------------------------------------------------------------------+
int Rpl_ShortDepth() { return ArraySize(g_grind_short.layers); }

//+------------------------------------------------------------------+
bool Rpl_WasAborted() { return g_rpl_aborted; }

//+------------------------------------------------------------------+
string Rpl_AbortReason() { return g_rpl_abort_reason; }

//+------------------------------------------------------------------+
void Rpl_SetRealDeals(const RplRealDeal &deals[], const int count)
{
   ArrayResize(g_rpl_real_deals, count);
   for(int i = 0; i < count; i++)
      g_rpl_real_deals[i] = deals[i];
   g_rpl_real_deal_count = count;
   g_rpl_real_applied = 0;
}

//+------------------------------------------------------------------+
int Rpl_ScalpEventsQueued() { return Grind_ScalpEventQueueSize(); }

//+------------------------------------------------------------------+
string Rpl_ScalpEventPeek()
{
   if(Grind_ScalpEventQueueSize() > 0)
      return Grind_ScalpEventQueuePeek();
   return g_rpl_last_scalp_json;
}

//+------------------------------------------------------------------+
bool Rpl_RunReplayScript(const string tag, const bool sync_mode)
{
   Print("RPL|STUB_RUN|", tag, "|sync=", sync_mode);
   return false;
}

//+------------------------------------------------------------------+
int Rpl_CurrentSyncIdx()
{
   return g_rpl_sync_idx;
}

//+------------------------------------------------------------------+
bool Rpl_HasPosition(const ulong ticket)
{
   for(int i = 0; i < ArraySize(g_grind_long.layers); i++) {
      if(g_grind_long.layers[i].position_ticket == ticket)
         return true;
   }
   for(int i = 0; i < ArraySize(g_grind_short.layers); i++) {
      if(g_grind_short.layers[i].position_ticket == ticket)
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
bool Rpl_RunReplayFiles(const string tag, const bool sync_mode)
{
   return Rpl_RunReplayScript(tag, sync_mode);
}

//+------------------------------------------------------------------+
void Rpl_SetSyncRealKindRows(const string csv_rows[], const int count) {}

//+------------------------------------------------------------------+
int Rpl_GapReportCount()
{
   return 0;
}

//+------------------------------------------------------------------+
bool Rpl_GapReportAt(const int index, long &from_ms, long &seconds)
{
   return false;
}

#endif // FXGRIND_REPLAY_CORE_MQH
