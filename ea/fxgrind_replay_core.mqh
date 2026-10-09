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
const datetime RPL_T0_DEFAULT = D'2026.10.06 10:00:00';
#define RPL_LATTICE_RESERVE 200000

string g_rpl_out_suffix = "";

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
   string side;
   int    layer;
   string role;
   long   order_type;
};

struct RplSyncRealRow
{
   long   time_ms;
   string kind;
   string side;
   int    layer;
   double price;
   ulong  position_id;
   double level;
};

struct RplGapRow
{
   long from_ms;
   long seconds;
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
   double accrued;
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
long             g_rpl_retained_from_ms = 0;
long             g_rpl_segment_day_key = 0;
bool             g_rpl_segment_first_tick = true;
long             g_rpl_last_processed_tick_ms = 0;
RplSyncRealRow   g_rpl_sync_real[];
int              g_rpl_sync_real_count = 0;
int              g_rpl_sync_real_applied = 0;
RplGapRow        g_rpl_gaps[];
int              g_rpl_gap_count = 0;
bool             g_rpl_skip_true_book_add = false;
RplTick          g_rpl_all_ticks[];
int              g_rpl_all_tick_count = 0;
int              g_rpl_lattice_backfills = 0;
ulong            g_rpl_seeded_order_tickets[];
int              g_rpl_seeded_order_count = 0;

struct RplTestInterval
{
   string kind;
   long   from_ms;
   long   to_ms;
};

RplTestInterval  g_rpl_test_intervals[];
int              g_rpl_test_interval_count = 0;
RplTestInterval  g_rpl_file_intervals[];
int              g_rpl_file_interval_count = 0;
RplSyncRealRow   g_rpl_real_file_rows[];
int              g_rpl_real_file_count = 0;
int              g_rpl_seg_ticks_processed = 0;
uint             g_rpl_seg_run_start_ms = 0;

struct RplRunOutputHandles
{
   int deals;
   int events;
   int book;
   int summary;
   int orders;
   bool open;
};

struct RplOrderRow
{
   int    seg_id;
   int    sync_idx;
   long   time_ms;
   string stage;
   string action;
   ulong  ticket;
   long   type;
   string side;
   int    layer;
   string role;
   double price;
   double old_price;
};

struct RplOrderSnap
{
   ulong  ticket;
   long   type;
   string comment;
   double price;
};

RplOrderRow  g_rpl_orders[];
RplOrderSnap g_rpl_order_snap[];

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
   string got = Rpl_NormalizeDataPath(data_path);
   string want = Rpl_NormalizeDataPath(RPL_DATA_PATH);
   StringToLower(got);
   StringToLower(want);
   if(got != want)
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
void Rpl_SetOutputSuffix(const string s)
{
   g_rpl_out_suffix = s;
}

//+------------------------------------------------------------------+
bool Rpl_WaitSymbolReady(const int timeout_ms)
{
   SymbolSelect(_Symbol, true);
   int waited_ms = 0;
   while(waited_ms < timeout_ms) {
      const double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      MqlTick tick;
      const bool tick_ok = SymbolInfoTick(_Symbol, tick);
      if(tick_value > 0.0 && tick_size > 0.0 && tick_ok) {
         Print("RPL|SYMBOL_READY|tick_value=", tick_value, "|tick_size=", tick_size, "|waited_ms=", waited_ms);
         return true;
      }
      if(waited_ms % 5000 == 0) {
         Print("RPL|SYMBOL_WAIT|tick_value=", tick_value, "|tick_size=", tick_size, "|tick_ok=", tick_ok ? 1 : 0,
               "|waited_ms=", waited_ms);
      }
      Sleep(500);
      waited_ms += 500;
   }
   const double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   MqlTick tick;
   const bool tick_ok = SymbolInfoTick(_Symbol, tick);
   Print("RPL|ABORT|NO_TICK_VALUE|tick_value=", tick_value, "|tick_size=", tick_size, "|tick_ok=", tick_ok ? 1 : 0);
   return false;
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
   GlobalVariablesDeleteAll("GRIND_CARRY_DAY_");
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
   ArrayResize(g_rpl_deals, 0);
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
   g_rpl_retained_from_ms = 0;
   g_rpl_segment_day_key = 0;
   g_rpl_segment_first_tick = true;
   g_rpl_last_processed_tick_ms = 0;
   ArrayResize(g_rpl_sync_real, 0);
   g_rpl_sync_real_count = 0;
   g_rpl_sync_real_applied = 0;
   ArrayResize(g_rpl_gaps, 0);
   g_rpl_gap_count = 0;
   ArrayResize(g_rpl_all_ticks, 0);
   g_rpl_all_tick_count = 0;
   g_rpl_lattice_backfills = 0;
   ArrayResize(g_rpl_seeded_order_tickets, 0);
   g_rpl_seeded_order_count = 0;
   g_rpl_skip_true_book_add = false;
   ArrayResize(g_rpl_test_intervals, 0);
   g_rpl_test_interval_count = 0;
   g_rpl_seg_ticks_processed = 0;
   g_grind_order_test_active = true;
   g_grind_closeby_test_active = true;
   g_grind_deal_test_active = true;
   g_grind_closeby_test_send_ok = true;
   g_grind_closeby_test_send_retcode = TRADE_RETCODE_DONE;
   g_grind_market_test_active = true;
   g_grind_pnl_test_active = true;
   ArrayResize(g_rpl_orders, 0);
   ArrayResize(g_rpl_order_snap, 0);
}

//+------------------------------------------------------------------+
bool Rpl_OrderLogSnapFind(const ulong ticket, RplOrderSnap &out)
{
   for(int i = 0; i < ArraySize(g_rpl_order_snap); i++) {
      if(g_rpl_order_snap[i].ticket == ticket) {
         out = g_rpl_order_snap[i];
         return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
bool Rpl_OrderLogBookFind(const ulong ticket, GrindOrderTestRecord &out)
{
   return Grind_OrderTestFind(ticket, out);
}

//+------------------------------------------------------------------+
bool Rpl_OrderLogDealFillAt(const long t, const ulong order_ticket)
{
   for(int i = ArraySize(g_rpl_deals) - 1; i >= 0; i--) {
      if(g_rpl_deals[i].order == order_ticket && g_rpl_deals[i].time_ms == t)
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
void Rpl_OrderLogParseComment(const string comment, string &side, int &layer, string &role)
{
   side = "";
   layer = -1;
   role = "";
   string slot;
   if(!GrindCommentParse(comment, slot, side, layer, role)) {
      side = "";
      layer = -1;
      role = "";
   }
}

//+------------------------------------------------------------------+
void Rpl_OrderLogAppendRow(const long t,
                           const string stage,
                           const string action,
                           const ulong ticket,
                           const long otype,
                           const string comment,
                           const double price,
                           const double old_price)
{
   string side;
   int layer;
   string role;
   Rpl_OrderLogParseComment(comment, side, layer, role);
   const int n = ArraySize(g_rpl_orders);
   ArrayResize(g_rpl_orders, n + 1, 4096);
   g_rpl_orders[n].seg_id = g_rpl_cfg.seg_id;
   g_rpl_orders[n].sync_idx = g_rpl_sync_idx;
   g_rpl_orders[n].time_ms = t;
   g_rpl_orders[n].stage = stage;
   g_rpl_orders[n].action = action;
   g_rpl_orders[n].ticket = ticket;
   g_rpl_orders[n].type = otype;
   g_rpl_orders[n].side = side;
   g_rpl_orders[n].layer = layer;
   g_rpl_orders[n].role = role;
   g_rpl_orders[n].price = price;
   g_rpl_orders[n].old_price = old_price;
}

//+------------------------------------------------------------------+
void Rpl_OrderLogDiff(const long t, const string stage)
{
   const double pt_half = _Point / 2.0;
   for(int i = 0; i < g_grind_order_test_count; i++) {
      const GrindOrderTestRecord rec = g_grind_order_test_records[i];
      RplOrderSnap snap;
      if(!Rpl_OrderLogSnapFind(rec.ticket, snap)) {
         Rpl_OrderLogAppendRow(t, stage, "PLACE", rec.ticket, rec.type, rec.comment, rec.price, 0.0);
         continue;
      }
      if(MathAbs(rec.price - snap.price) > pt_half)
         Rpl_OrderLogAppendRow(t, stage, "MODIFY", rec.ticket, rec.type, rec.comment, rec.price, snap.price);
   }
   for(int s = 0; s < ArraySize(g_rpl_order_snap); s++) {
      const RplOrderSnap snap = g_rpl_order_snap[s];
      GrindOrderTestRecord book_rec;
      if(Rpl_OrderLogBookFind(snap.ticket, book_rec))
         continue;
      const string action = Rpl_OrderLogDealFillAt(t, snap.ticket) ? "FILL" : "REMOVE";
      Rpl_OrderLogAppendRow(t, stage, action, snap.ticket, snap.type, snap.comment, snap.price, 0.0);
   }
   ArrayResize(g_rpl_order_snap, g_grind_order_test_count);
   for(int i = 0; i < g_grind_order_test_count; i++) {
      g_rpl_order_snap[i].ticket = g_grind_order_test_records[i].ticket;
      g_rpl_order_snap[i].type = g_grind_order_test_records[i].type;
      g_rpl_order_snap[i].comment = g_grind_order_test_records[i].comment;
      g_rpl_order_snap[i].price = g_grind_order_test_records[i].price;
   }
}

//+------------------------------------------------------------------+
int Rpl_OrderLogCount()
{
   return ArraySize(g_rpl_orders);
}

//+------------------------------------------------------------------+
bool Rpl_GetOrderLogRow(const int i, RplOrderRow &out)
{
   out.seg_id = 0;
   out.sync_idx = 0;
   out.time_ms = 0;
   out.stage = "";
   out.action = "";
   out.ticket = 0;
   out.type = 0;
   out.side = "";
   out.layer = 0;
   out.role = "";
   out.price = 0.0;
   out.old_price = 0.0;
   if(i < 0 || i >= ArraySize(g_rpl_orders))
      return false;
   out = g_rpl_orders[i];
   return true;
}

//+------------------------------------------------------------------+
void Rpl_SegmentConfigDefaults(RplSegmentConfig &cfg)
{
   cfg.seg_id = 1;
   cfg.instance = "GRIND_TEST";
   cfg.magic = RPL_MAGIC_DEFAULT;
   cfg.from_ms = ((long)RPL_T0_DEFAULT) * 1000;
   cfg.to_ms = ((long)RPL_T0_DEFAULT + 100) * 1000;
   cfg.width_l = 2.0;
   cfg.width_s = 15.0;
   cfg.add_l = 7.0;
   cfg.add_s = 7.0;
   cfg.exit_l = 10.0;
   cfg.exit_s = 10.0;
   cfg.cap = 8;
   cfg.stranded = 50.0;
   cfg.deadband = 2.0;
   cfg.lattice = true;
   cfg.reroll = false;
   cfg.gate = -1;
   cfg.carry = false;
   cfg.fill_time_place = true;
   cfg.reserve = 8;
   cfg.sync = false;
   cfg.skip_lattice_preload = false;
}

//+------------------------------------------------------------------+
void Rpl_AppendTestSwap(const string date, const double pl, const double ps, const double mult)
{
   ArrayResize(g_rpl_swaps, g_rpl_swap_count + 1);
   g_rpl_swaps[g_rpl_swap_count].date = date;
   g_rpl_swaps[g_rpl_swap_count].points_long = pl;
   g_rpl_swaps[g_rpl_swap_count].points_short = ps;
   g_rpl_swaps[g_rpl_swap_count].mult = mult;
   g_rpl_swap_count++;
}

//+------------------------------------------------------------------+
void Rpl_SetTestSwaps(const string date, const double pl, const double ps, const double mult)
{
   ArrayResize(g_rpl_swaps, 0);
   g_rpl_swap_count = 0;
   Rpl_AppendTestSwap(date, pl, ps, mult);
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
                    const double volume, const long open_ms, const bool is_long,
                    const string side = "", const int layer = -1, const string role = "",
                    const long order_type = 0)
{
   ArrayResize(g_rpl_pos_meta, g_rpl_pos_meta_count + 1);
   g_rpl_pos_meta[g_rpl_pos_meta_count].ticket = ticket;
   g_rpl_pos_meta[g_rpl_pos_meta_count].entry = entry;
   g_rpl_pos_meta[g_rpl_pos_meta_count].swap = swap;
   g_rpl_pos_meta[g_rpl_pos_meta_count].volume = volume;
   g_rpl_pos_meta[g_rpl_pos_meta_count].open_ms = open_ms;
   g_rpl_pos_meta[g_rpl_pos_meta_count].is_long = is_long;
   g_rpl_pos_meta[g_rpl_pos_meta_count].side = side;
   g_rpl_pos_meta[g_rpl_pos_meta_count].layer = layer;
   g_rpl_pos_meta[g_rpl_pos_meta_count].role = role;
   g_rpl_pos_meta[g_rpl_pos_meta_count].order_type = order_type;
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
   g_rpl_true_book[g_rpl_true_book_count].accrued = 0.0;
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
   Grind_CarryTestSetPosition(ticket, swap, volume, (datetime)(open_ms / 1000));
   Rpl_AddPosMeta(ticket, entry, swap, volume, open_ms, is_long, side, layer_index, "ENT", 0);
   if(vl > 0.0)
      Grind_VLSet(ticket, vl);
   if(open_ms > g_rpl_newest_seed_open_ms)
      g_rpl_newest_seed_open_ms = open_ms;
   g_rpl_seeded = true;
   if(g_rpl_cfg.sync && !g_rpl_skip_true_book_add)
      Rpl_TrueBookAdd(side, layer_index, entry, ticket, swap, volume, open_ms, vl);
}

//+------------------------------------------------------------------+
bool Rpl_LinkSeedOrderToSide(GrindSideState &side,
                             const string side_code,
                             const int layer,
                             const string role,
                             const double price,
                             const ulong ticket)
{
   if(role == "EXT") {
      for(int i = 0; i < ArraySize(side.layers); i++) {
         if(side.layers[i].layer_index != layer)
            continue;
         side.layers[i].exit_order_ticket = ticket;
         side.layers[i].exit_target = price;
         return true;
      }
      return false;
   }
   if(role == "ENT") {
      if(ArraySize(side.layers) == 0)
         side.l0_pending_ticket = ticket;
      else
         side.add_pending_ticket = ticket;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
void Rpl_SeedOrder(const string side,
                   const int layer,
                   const string role,
                   const double price,
                   const ulong ticket,
                   const long otype)
{
   Grind_OrderTestUpsert(ticket, g_rpl_cfg.magic,
                         GrindCommentBuild(RPL_SLOT_DEFAULT, side, layer, role),
                         price, otype);
   Rpl_TrackOrderPlaced(ticket, 1);
   bool linked = false;
   if(side == "L")
      linked = Rpl_LinkSeedOrderToSide(g_grind_long, side, layer, role, price, ticket);
   else if(side == "S")
      linked = Rpl_LinkSeedOrderToSide(g_grind_short, side, layer, role, price, ticket);
   if(!linked) {
      Rpl_Abort("SEED_ORDER_NO_LAYER");
      return;
   }
   ArrayResize(g_rpl_seeded_order_tickets, g_rpl_seeded_order_count + 1);
   g_rpl_seeded_order_tickets[g_rpl_seeded_order_count] = ticket;
   g_rpl_seeded_order_count++;
}

//+------------------------------------------------------------------+
void Rpl_SeedAccrued(const ulong ticket, const double accrued)
{
   Grind_CarryAccruedSet(ticket, accrued);
   for(int i = 0; i < g_rpl_true_book_count; i++) {
      if(g_rpl_true_book[i].ticket == ticket) {
         g_rpl_true_book[i].accrued = accrued;
         break;
      }
   }
}

//+------------------------------------------------------------------+
void Rpl_ReportOrdersKept()
{
   if(g_rpl_seeded_order_count <= 0)
      return;
   int kept = 0;
   for(int i = 0; i < g_rpl_seeded_order_count; i++) {
      GrindOrderTestRecord rec;
      if(Grind_OrderTestFind(g_rpl_seeded_order_tickets[i], rec))
         kept++;
   }
   Print("RPL|ORDERS_KEPT|", g_rpl_cfg.seg_id, "|", kept, "/", g_rpl_seeded_order_count);
}

//+------------------------------------------------------------------+
bool Rpl_LoadOrdersFile(const string orders_file, const int seg_id)
{
   const int od = FileOpen("replay\\" + orders_file, FILE_READ | FILE_CSV | FILE_ANSI, ',');
   if(od == INVALID_HANDLE) {
      Print("RPL|ABORT|MISSING_ORDERS");
      return false;
   }
   bool ord_header = false;
   string ord_fields[];
   int n_orders = 0;
   while(Rpl_CsvReadLineFields(od, ord_fields)) {
      if(Rpl_CsvFieldsAllEmpty(ord_fields))
         continue;
      if(StringFind(ord_fields[0], "#") == 0)
         continue;
      if(!ord_header) {
         if(!Rpl_CsvHeaderOk(ord_fields, "side", orders_file)) {
            FileClose(od);
            Print("RPL|ABORT|BAD_ORDERS");
            return false;
         }
         ord_header = true;
         continue;
      }
      const string side = ord_fields[0];
      const int layer = (ArraySize(ord_fields) > 1) ? (int)StringToInteger(ord_fields[1]) : 0;
      const string role = (ArraySize(ord_fields) > 2) ? ord_fields[2] : "";
      const double price = (ArraySize(ord_fields) > 3) ? StringToDouble(ord_fields[3]) : 0.0;
      const ulong ticket = (ArraySize(ord_fields) > 4) ? (ulong)StringToInteger(ord_fields[4]) : 0;
      const string type_str = (ArraySize(ord_fields) > 5) ? ord_fields[5] : "";
      long otype = 0;
      if(type_str == "BUY_LIMIT")
         otype = ORDER_TYPE_BUY_LIMIT;
      else if(type_str == "SELL_LIMIT")
         otype = ORDER_TYPE_SELL_LIMIT;
      else {
         FileClose(od);
         Print("RPL|ABORT|BAD_ORDERS");
         return false;
      }
      Rpl_SeedOrder(side, layer, role, price, ticket, otype);
      if(g_rpl_aborted) {
         FileClose(od);
         return false;
      }
      n_orders++;
   }
   FileClose(od);
   Print("RPL|ORDERS|", seg_id, "|count=", n_orders);
   return true;
}

//+------------------------------------------------------------------+
void Rpl_PreloadLatticeFromTicks(const RplSegmentConfig &cfg)
{
   if(cfg.skip_lattice_preload || !g_rpl_seeded)
      return;
   const long start_ms = MathMax(g_rpl_newest_seed_open_ms, cfg.from_ms - 86400000L);
   g_rpl_retained_from_ms = start_ms;
   int k = 0;
   for(int i = 0; i < g_rpl_all_tick_count; i++) {
      const long ms = g_rpl_all_ticks[i].time_msc;
      if(ms >= start_ms && ms < cfg.from_ms)
         k++;
   }
   const int n0 = ArraySize(g_grind_vl_test_tick_msc);
   const int n1 = n0 + k;
   ArrayResize(g_grind_vl_test_tick_msc, n1, RPL_LATTICE_RESERVE);
   ArrayResize(g_grind_vl_test_tick_bid, n1, RPL_LATTICE_RESERVE);
   ArrayResize(g_grind_vl_test_tick_ask, n1, RPL_LATTICE_RESERVE);
   int j = n0;
   for(int i = 0; i < g_rpl_all_tick_count; i++) {
      const long ms = g_rpl_all_ticks[i].time_msc;
      if(ms < start_ms || ms >= cfg.from_ms)
         continue;
      g_grind_vl_test_tick_msc[j] = (long)((datetime)(ms / 1000)) * 1000;
      g_grind_vl_test_tick_bid[j] = g_rpl_all_ticks[i].bid;
      g_grind_vl_test_tick_ask[j] = g_rpl_all_ticks[i].ask;
      j++;
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
   ArrayResize(g_grind_deal_test_records, g_grind_deal_test_count + 1, 4096);
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
                         const long deal_type,
                         const string role,
                         const string side,
                         const int layer,
                         const double price)
{
   const int n = ArraySize(g_rpl_deals);
   ArrayResize(g_rpl_deals, n + 1, 4096);
   g_rpl_deals[n].seg_id = g_rpl_cfg.seg_id;
   g_rpl_deals[n].sync_idx = g_rpl_sync_idx;
   g_rpl_deals[n].time_ms = time_ms;
   g_rpl_deals[n].deal = deal;
   g_rpl_deals[n].order = order;
   g_rpl_deals[n].position = position;
   g_rpl_deals[n].entry_type = entry_type;
   g_rpl_deals[n].deal_type = deal_type;
   g_rpl_deals[n].role = role;
   g_rpl_deals[n].side = side;
   g_rpl_deals[n].layer = layer;
   g_rpl_deals[n].price = price;
}

//+------------------------------------------------------------------+
void Rpl_WriteEventOutput(const long time_ms, const string kind, const string code, const string json)
{
   const int n = ArraySize(g_rpl_events);
   ArrayResize(g_rpl_events, n + 1, 4096);
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
bool Rpl_EngineSeamsOrAbort()
{
   if(Rpl_CheckSeams())
      return true;
   Rpl_Abort("SEAMS");
   return false;
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
void Rpl_EnsureLatticeHistoryOneSide(const GrindSideState &side, const bool is_long, const long t)
{
   const int depth = Grind_SideDepth(side);
   if(depth < g_rpl_cfg.cap)
      return;
   if(is_long ? g_grind_vl_tracking_long : g_grind_vl_tracking_short)
      return;

   datetime newest = 0;
   bool any = false;
   for(int i = 0; i < depth; i++) {
      const ulong pos = side.layers[i].position_ticket;
      if(pos == 0)
         continue;
      datetime ot = 0;
      if(!Grind_CarryPositionOpenTime(pos, g_rpl_cfg.magic, ot))
         return;
      if(!any || ot > newest) {
         newest = ot;
         any = true;
      }
   }
   if(!any)
      return;

   const long need = MathMax((long)(newest + 1) * 1000,
                             (long)((datetime)(t / 1000) - GRIND_VL_CATCHUP_MAX_SEC) * 1000);
   if(need >= g_rpl_retained_from_ms)
      return;
   if(g_rpl_all_tick_count <= 0)
      return;

   const long front = Rpl_OldestLatticeMs();
   int lo = 0;
   int hi = g_rpl_all_tick_count;
   while(lo < hi) {
      const int mid = (lo + hi) / 2;
      if(g_rpl_all_ticks[mid].time_msc < need)
         lo = mid + 1;
      else
         hi = mid;
   }

   int n_ins = 0;
   for(int i = lo; i < g_rpl_all_tick_count; i++) {
      const long s = (long)((datetime)(g_rpl_all_ticks[i].time_msc / 1000)) * 1000;
      if(s >= front)
         break;
      n_ins++;
   }

   if(n_ins > 0) {
      const int n0 = ArraySize(g_grind_vl_test_tick_msc);
      const int n1 = n0 + n_ins;
      ArrayResize(g_grind_vl_test_tick_msc, n1, RPL_LATTICE_RESERVE);
      ArrayResize(g_grind_vl_test_tick_bid, n1, RPL_LATTICE_RESERVE);
      ArrayResize(g_grind_vl_test_tick_ask, n1, RPL_LATTICE_RESERVE);
      for(int i = n0 - 1; i >= 0; i--) {
         g_grind_vl_test_tick_msc[i + n_ins] = g_grind_vl_test_tick_msc[i];
         g_grind_vl_test_tick_bid[i + n_ins] = g_grind_vl_test_tick_bid[i];
         g_grind_vl_test_tick_ask[i + n_ins] = g_grind_vl_test_tick_ask[i];
      }
      int j = 0;
      for(int i = lo; i < g_rpl_all_tick_count && j < n_ins; i++) {
         const long s = (long)((datetime)(g_rpl_all_ticks[i].time_msc / 1000)) * 1000;
         if(s >= front)
            break;
         g_grind_vl_test_tick_msc[j] = s;
         g_grind_vl_test_tick_bid[j] = g_rpl_all_ticks[i].bid;
         g_grind_vl_test_tick_ask[j] = g_rpl_all_ticks[i].ask;
         j++;
      }
      g_rpl_lattice_backfills++;
      Print("RPL|LATTICE_BACKFILL|", is_long ? "L" : "S", "|need=", need, "|count=", n_ins);
   }

   g_rpl_retained_from_ms = MathMax(need, g_rpl_all_ticks[0].time_msc);
}

//+------------------------------------------------------------------+
void Rpl_EnsureLatticeHistory(const long t)
{
   Rpl_EnsureLatticeHistoryOneSide(g_grind_long, true, t);
   Rpl_EnsureLatticeHistoryOneSide(g_grind_short, false, t);
}

//+------------------------------------------------------------------+
void Rpl_LatticeHistoryCheck(const bool is_long, const long tick_ms)
{
   const double extreme = is_long ? g_grind_vl_extreme_long : g_grind_vl_extreme_short;
   if(extreme == 0.0)
      return;
   long newest_open_s = 0;
   bool any = false;
   const int depth = is_long ? ArraySize(g_grind_long.layers) : ArraySize(g_grind_short.layers);
   for(int i = 0; i < depth; i++) {
      const ulong pt = is_long ? g_grind_long.layers[i].position_ticket
                               : g_grind_short.layers[i].position_ticket;
      RplPosMeta m;
      if(!Rpl_FindPosMeta(pt, m))
         continue;
      const long os = m.open_ms / 1000;
      if(!any || os > newest_open_s) {
         newest_open_s = os;
         any = true;
      }
   }
   if(!any)
      return;
   const long now_s = tick_ms / 1000;
   const long start_ms = MathMax((newest_open_s + 1) * 1000,
                                 (now_s - GRIND_VL_CATCHUP_MAX_SEC) * 1000);
   if(g_rpl_retained_from_ms > 0 && start_ms < g_rpl_retained_from_ms) {
      Print("RPL|ABORT|LATTICE_HISTORY|start_ms=", start_ms, "|retained=", g_rpl_retained_from_ms);
      Rpl_Abort("LATTICE_HISTORY");
   }
}

//+------------------------------------------------------------------+
void Rpl_PruneLattice(const long tick_ms)
{
   const long cutoff = tick_ms - 300000L;
   int j = 0;
   const int n = ArraySize(g_grind_vl_test_tick_msc);
   for(int i = 0; i < n; i++) {
      if(g_grind_vl_test_tick_msc[i] >= cutoff) {
         if(j != i) {
            g_grind_vl_test_tick_msc[j] = g_grind_vl_test_tick_msc[i];
            g_grind_vl_test_tick_bid[j] = g_grind_vl_test_tick_bid[i];
            g_grind_vl_test_tick_ask[j] = g_grind_vl_test_tick_ask[i];
         }
         j++;
      }
   }
   ArrayResize(g_grind_vl_test_tick_msc, j, RPL_LATTICE_RESERVE);
   ArrayResize(g_grind_vl_test_tick_bid, j, RPL_LATTICE_RESERVE);
   ArrayResize(g_grind_vl_test_tick_ask, j, RPL_LATTICE_RESERVE);
   if(cutoff > g_rpl_retained_from_ms)
      g_rpl_retained_from_ms = cutoff;
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
                                 (datetime)(g_rpl_pos_meta[i].open_ms / 1000));
   }
   for(int i = 0; i < g_rpl_true_book_count; i++) {
      const double points = (g_rpl_true_book[i].side == "L") ? pl : ps;
      g_rpl_true_book[i].swap += points * mult * tick_val * g_rpl_true_book[i].volume;
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
      ext.ticket = 0;
      if(!Rpl_FindPosMeta(before[i].t1, ent))
         continue;
      if(!Rpl_FindPosMeta(before[i].t2, ext)) {
         for(int li = 0; li < ArraySize(g_grind_long.layers); li++) {
            if(g_grind_long.layers[li].exit_position_ticket == before[i].t2) {
               ext.ticket = before[i].t2;
               ext.entry = g_grind_long.layers[li].exit_target;
               ext.is_long = false;
               ext.side = "L";
               ext.layer = g_grind_long.layers[li].layer_index;
               ext.role = "EXT";
               ext.volume = RPL_LOTS_DEFAULT;
               break;
            }
         }
         for(int li = 0; li < ArraySize(g_grind_short.layers); li++) {
            if(g_grind_short.layers[li].exit_position_ticket == before[i].t2) {
               ext.ticket = before[i].t2;
               ext.entry = g_grind_short.layers[li].exit_target;
               ext.is_long = true;
               ext.side = "S";
               ext.layer = g_grind_short.layers[li].layer_index;
               ext.role = "EXT";
               ext.volume = RPL_LOTS_DEFAULT;
               break;
            }
         }
      }
      if(ext.ticket == 0)
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
                           DEAL_ENTRY_OUT_BY, order_ticket, before[i].t1, profit, ent.swap, 0.0,
                           ext.entry, tsec, g_rpl_cfg.magic);
      Rpl_ReplayAppendDeal(d2, "#" + IntegerToString((long)before[i].t2) + " by #" + IntegerToString((long)before[i].t1),
                           DEAL_ENTRY_OUT_BY, order_ticket, before[i].t2, 0.0, ext.swap, 0.0,
                           ent.entry, tsec, g_rpl_cfg.magic);
      const long dt1 = ent.is_long ? DEAL_TYPE_SELL : DEAL_TYPE_BUY;
      const long dt2 = ext.is_long ? DEAL_TYPE_SELL : DEAL_TYPE_BUY;
      Rpl_WriteDealOutput(tick_ms, d1, order_ticket, before[i].t1, DEAL_ENTRY_OUT_BY, dt1,
                          ent.role != "" ? ent.role : "ENT", ent.side != "" ? ent.side : (ent.is_long ? "L" : "S"),
                          ent.layer >= 0 ? ent.layer : 0, ext.entry);
      Rpl_WriteDealOutput(tick_ms, d2, order_ticket, before[i].t2, DEAL_ENTRY_OUT_BY, dt2,
                          ext.role != "" ? ext.role : "EXT", ext.side != "" ? ext.side : (ext.is_long ? "L" : "S"),
                          ext.layer >= 0 ? ext.layer : 0, ent.entry);
      if(!Rpl_EngineSeamsOrAbort())
         return;
      Grind_ProcessDeal(d1, g_rpl_cfg.magic, RPL_SLOT_DEFAULT, g_rpl_cfg.exit_l, g_rpl_cfg.add_l,
                        g_rpl_cfg.deadband, g_rpl_cfg.cap, RPL_LOTS_DEFAULT, g_rpl_cfg.exit_s, g_rpl_cfg.add_s);
      if(!Rpl_EngineSeamsOrAbort())
         return;
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
   ulong fill_tickets[];
   int fill_n = 0;
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
      ArrayResize(fill_tickets, fill_n + 1);
      fill_tickets[fill_n++] = oticket;
   }
   for(int f = 0; f < fill_n; f++) {
      GrindOrderTestRecord rec;
      if(!Grind_OrderTestFind(fill_tickets[f], rec))
         continue;
      const long otype = rec.type;
      const double price = rec.price;
      const string comment = rec.comment;
      Grind_OrderTestRemove(fill_tickets[f]);
      const ulong pos_id = g_rpl_next_pos_id++;
      const ulong deal_id = g_rpl_next_deal_id++;
      const datetime tsec = (datetime)(tick_ms / 1000);
      const bool is_long_ent = (otype == ORDER_TYPE_BUY_LIMIT);
      string slot, side, role;
      int layer;
      if(!GrindCommentParse(comment, slot, side, layer, role))
         side = is_long_ent ? "L" : "S";
      const long deal_type = (otype == ORDER_TYPE_BUY_LIMIT) ? DEAL_TYPE_BUY : DEAL_TYPE_SELL;
      Rpl_ReplayAppendDeal(deal_id, comment, DEAL_ENTRY_IN, fill_tickets[f], pos_id, 0.0, 0.0, 0.0, price, tsec,
                           g_rpl_cfg.magic);
      Grind_PositionTestAdd(pos_id);
      Rpl_AddCloseByPos(pos_id, is_long_ent);
      Grind_CarryTestSetPosition(pos_id, 0.0, RPL_LOTS_DEFAULT, (datetime)(tick_ms / 1000));
      Rpl_AddPosMeta(pos_id, price, 0.0, RPL_LOTS_DEFAULT, tick_ms, is_long_ent, side, layer, role, otype);
      Rpl_WriteDealOutput(tick_ms, deal_id, fill_tickets[f], pos_id, DEAL_ENTRY_IN, deal_type, role, side, layer,
                          price);
      if(!Rpl_EngineSeamsOrAbort())
         return;
      Grind_ProcessDeal(deal_id, g_rpl_cfg.magic, RPL_SLOT_DEFAULT, g_rpl_cfg.exit_l, g_rpl_cfg.add_l,
                        g_rpl_cfg.deadband, g_rpl_cfg.cap, RPL_LOTS_DEFAULT, g_rpl_cfg.exit_s, g_rpl_cfg.add_s);
   }
}

//+------------------------------------------------------------------+
void Rpl_RemoveCloseByQueueTicket(const ulong ticket)
{
   for(int i = ArraySize(g_grind_long_closeby_queue) - 1; i >= 0; i--) {
      if(g_grind_long_closeby_queue[i].ticket1 != ticket && g_grind_long_closeby_queue[i].ticket2 != ticket)
         continue;
      for(int j = i; j < ArraySize(g_grind_long_closeby_queue) - 1; j++)
         g_grind_long_closeby_queue[j] = g_grind_long_closeby_queue[j + 1];
      ArrayResize(g_grind_long_closeby_queue, ArraySize(g_grind_long_closeby_queue) - 1);
   }
   for(int i = ArraySize(g_grind_short_closeby_queue) - 1; i >= 0; i--) {
      if(g_grind_short_closeby_queue[i].ticket1 != ticket && g_grind_short_closeby_queue[i].ticket2 != ticket)
         continue;
      for(int j = i; j < ArraySize(g_grind_short_closeby_queue) - 1; j++)
         g_grind_short_closeby_queue[j] = g_grind_short_closeby_queue[j + 1];
      ArrayResize(g_grind_short_closeby_queue, ArraySize(g_grind_short_closeby_queue) - 1);
   }
}

//+------------------------------------------------------------------+
void Rpl_PurgeTicketFromSeams(const ulong ticket)
{
   if(ticket == 0)
      return;
   Rpl_RemovePositionTicket(ticket);
   Rpl_RemoveCloseByPos(ticket);
   Rpl_RemovePosMeta(ticket);
   Rpl_RemoveCloseByQueueTicket(ticket);
}

//+------------------------------------------------------------------+
void Rpl_RemoveLayerByTicket(GrindSideState &side, const ulong pos_ticket)
{
   for(int i = 0; i < ArraySize(side.layers); i++) {
      if(side.layers[i].position_ticket != pos_ticket)
         continue;
      const ulong exit_pos = side.layers[i].exit_position_ticket;
      if(side.layers[i].exit_order_ticket != 0)
         Grind_OrderTestRemove(side.layers[i].exit_order_ticket);
      for(int j = i; j < ArraySize(side.layers) - 1; j++)
         side.layers[j] = side.layers[j + 1];
      ArrayResize(side.layers, ArraySize(side.layers) - 1);
      Rpl_PurgeTicketFromSeams(pos_ticket);
      Rpl_PurgeTicketFromSeams(exit_pos);
      return;
   }
}

//+------------------------------------------------------------------+
void Rpl_SyncResetToTrueBook()
{
   for(int t = 0; t < g_rpl_true_book_count; t++) {
      const ulong tb_ticket = g_rpl_true_book[t].ticket;
      if(GlobalVariableCheck(Grind_CarryAccruedGvName(tb_ticket)))
         g_rpl_true_book[t].accrued = Grind_CarryAccruedGet(tb_ticket);
   }
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
         g_rpl_skip_true_book_add = true;
         Rpl_SeedLayer(g_rpl_true_book[t].side, g_rpl_true_book[t].layer, g_rpl_true_book[t].entry,
                       g_rpl_true_book[t].open_ms, g_rpl_true_book[t].ticket, g_rpl_true_book[t].vl,
                       g_rpl_true_book[t].swap, g_rpl_true_book[t].volume);
         g_rpl_skip_true_book_add = false;
         if(g_rpl_true_book[t].accrued != 0.0)
            Grind_CarryAccruedSet(g_rpl_true_book[t].ticket, g_rpl_true_book[t].accrued);
      }
   }
   for(int t = 0; t < g_rpl_true_book_count; t++) {
      if(g_rpl_true_book[t].vl > 0.0)
         Grind_VLSet(g_rpl_true_book[t].ticket, g_rpl_true_book[t].vl);
      else
         Grind_VLDelete(g_rpl_true_book[t].ticket);
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
   while(g_rpl_sync_real_applied < g_rpl_sync_real_count
         && g_rpl_sync_real[g_rpl_sync_real_applied].time_ms <= tick_ms) {
      const RplSyncRealRow rd = g_rpl_sync_real[g_rpl_sync_real_applied];
      if(rd.kind == "ENT") {
         Rpl_TrueBookAdd(rd.side, rd.layer, rd.price, rd.position_id, 0.0, RPL_LOTS_DEFAULT, rd.time_ms, 0.0);
         for(int i = g_rpl_true_book_count - 1; i >= 0; i--) {
            if(g_rpl_true_book[i].ticket == rd.position_id) {
               g_rpl_true_book[i].open_ms = rd.time_ms;
               break;
            }
         }
      } else if(rd.kind == "EXT") {
         int remove_i = -1;
         long newest_ms = 0;
         for(int i = 0; i < g_rpl_true_book_count; i++) {
            if(g_rpl_true_book[i].side != rd.side || g_rpl_true_book[i].layer != rd.layer)
               continue;
            if(remove_i < 0 || g_rpl_true_book[i].open_ms >= newest_ms) {
               newest_ms = g_rpl_true_book[i].open_ms;
               remove_i = i;
            }
         }
         if(remove_i >= 0) {
            for(int j = remove_i; j < g_rpl_true_book_count - 1; j++)
               g_rpl_true_book[j] = g_rpl_true_book[j + 1];
            g_rpl_true_book_count--;
         }
      } else if(rd.kind == "OUT_BY") {
         for(int i = g_rpl_true_book_count - 1; i >= 0; i--) {
            if(g_rpl_true_book[i].ticket == rd.position_id) {
               for(int j = i; j < g_rpl_true_book_count - 1; j++)
                  g_rpl_true_book[j] = g_rpl_true_book[j + 1];
               g_rpl_true_book_count--;
               break;
            }
         }
      } else if(rd.kind == "ROLL") {
         for(int i = 0; i < g_rpl_true_book_count; i++) {
            if(g_rpl_true_book[i].ticket == rd.position_id) {
               g_rpl_true_book[i].vl = rd.level;
               break;
            }
         }
      }
      g_rpl_sync_idx = g_rpl_sync_real_applied;
      g_rpl_sync_real_applied++;
      changed = true;
   }
   if(changed)
      Rpl_SyncResetToTrueBook();
}

//+------------------------------------------------------------------+
bool Rpl_InNightlyGapExclude(const datetime tsec)
{
   MqlDateTime dt;
   TimeToStruct(tsec, dt);
   if(dt.hour == 23 && dt.min >= 50)
      return true;
   if(dt.hour == 0 && dt.min <= 15)
      return true;
   return false;
}

//+------------------------------------------------------------------+
bool Rpl_IsWeekday(const datetime tsec)
{
   MqlDateTime dt;
   TimeToStruct(tsec, dt);
   return (dt.day_of_week >= 1 && dt.day_of_week <= 5);
}

//+------------------------------------------------------------------+
void Rpl_RecordGapIfNeeded(const long prev_ms, const long cur_ms)
{
   if(prev_ms <= 0 || cur_ms <= prev_ms)
      return;
   const long gap_sec = (cur_ms - prev_ms) / 1000;
   if(gap_sec <= 60)
      return;
   const datetime mid = (datetime)((prev_ms + cur_ms) / 2000);
   if(!Rpl_IsWeekday(mid) || Rpl_InNightlyGapExclude(mid))
      return;
   ArrayResize(g_rpl_gaps, g_rpl_gap_count + 1);
   g_rpl_gaps[g_rpl_gap_count].from_ms = prev_ms;
   g_rpl_gaps[g_rpl_gap_count].seconds = gap_sec;
   g_rpl_gap_count++;
   Print("RPL|GAP|", prev_ms, "|", gap_sec);
}

//+------------------------------------------------------------------+
void Rpl_ProcessOneTick(const RplTick &tick)
{
   if(g_rpl_aborted)
      return;
   const long t = tick.time_msc;
   const bool seg_first_tick = g_rpl_segment_first_tick;
   const datetime tsec = (datetime)(t / 1000);
   MqlDateTime dt;
   TimeToStruct(tsec, dt);
   const long day_key = dt.year * 10000 + dt.mon * 100 + dt.day;
   if(g_rpl_segment_first_tick) {
      g_rpl_segment_day_key = day_key;
      g_rpl_segment_first_tick = false;
      if(g_rpl_retained_from_ms == 0)
         g_rpl_retained_from_ms = t;
   } else {
      Rpl_RecordGapIfNeeded(g_rpl_last_processed_tick_ms, t);
      if(day_key != g_rpl_segment_day_key) {
         Rpl_ApplySwapRollover(t);
         g_rpl_segment_day_key = day_key;
      }
   }
   g_rpl_last_processed_tick_ms = t;
   g_rpl_seg_ticks_processed++;

   Rpl_ApplySyncDealsUpTo(t);
   Rpl_OrderLogDiff(t, "SYNC");

   Rpl_ApplyIntervalsAt(t);

   Grind_MarketTestSeed(tick.bid, tick.ask, 0, 0);
   Grind_MarketTestSeedTimeMsc(t);
   Grind_CarryTestSeedTick((datetime)(t / 1000), tick.bid, tick.ask);
   g_grind_carry_test_server_time = (datetime)(t / 1000);
   Grind_LatticeTestAddTick((datetime)(t / 1000), tick.bid, tick.ask);
   MqlTick live;
   if(SymbolInfoTick(_Symbol, live))
      g_grind_last_feed_tick_msc = live.time_msc;

   if(seg_first_tick)
      Grind_LatticeRollGateInitRestart(g_rpl_cfg.gate);

   Rpl_FillsOnTick(t, tick.bid, tick.ask);
   Rpl_OrderLogDiff(t, "FILL");
   if(g_rpl_aborted)
      return;

   RplCbTask cb_before[];
   int cb_n = 0;
   Rpl_SnapshotQueues(cb_before, cb_n);

   if(!Rpl_EngineSeamsOrAbort())
      return;

   const bool trkL0 = g_grind_vl_tracking_long;
   const bool trkS0 = g_grind_vl_tracking_short;

   Grind_ProcessCloseByQueues(g_rpl_cfg.magic, false);
   Rpl_OrderLogDiff(t, "CLOSEBY");
   if(!Rpl_EngineSeamsOrAbort())
      return;
   Rpl_EnsureLatticeHistory(t);
   Grind_LatticeOnTick(g_rpl_cfg.magic, RPL_SLOT_DEFAULT, RPL_LOTS_DEFAULT, g_rpl_cfg.lattice,
                       g_rpl_cfg.exit_l, g_rpl_cfg.add_l, g_rpl_cfg.cap, false, (datetime)(t / 1000),
                       g_rpl_cfg.exit_s, g_rpl_cfg.add_s, g_rpl_cfg.reroll, g_rpl_cfg.gate);
   Rpl_OrderLogDiff(t, "LATTICE");
   if(!Rpl_EngineSeamsOrAbort())
      return;
   Grind_OnTickEngine(g_rpl_cfg.magic, RPL_SLOT_DEFAULT, g_rpl_cfg.width_l, g_rpl_cfg.exit_l, g_rpl_cfg.add_l,
                      g_rpl_cfg.stranded, g_rpl_cfg.deadband, g_rpl_cfg.cap, RPL_LOTS_DEFAULT,
                      g_rpl_cfg.width_s, g_rpl_cfg.add_s);
   Rpl_OrderLogDiff(t, "ENGINE");

   if(!trkL0 && g_grind_vl_tracking_long)
      Rpl_LatticeHistoryCheck(true, t);
   if(!trkS0 && g_grind_vl_tracking_short)
      Rpl_LatticeHistoryCheck(false, t);

   Rpl_ScanNewOrders(t);
   if(seg_first_tick)
      Rpl_ReportOrdersKept();
   Rpl_ProcessCloseByDone(t, cb_before, cb_n);
   Rpl_OrderLogDiff(t, "CB_DONE");

   if(g_rpl_last_timer_ms == 0 || t - g_rpl_last_timer_ms >= 60000) {
      if(!Rpl_EngineSeamsOrAbort())
         return;
      Grind_CarryOnTimerStep(_Symbol, g_rpl_cfg.magic, g_rpl_cfg.exit_l, g_rpl_cfg.carry, (datetime)(t / 1000),
                             g_rpl_cfg.exit_s);
      g_rpl_last_timer_ms = t;
   }
   Rpl_OrderLogDiff(t, "TIMER");

   Rpl_DrainOutputs(t);
   Rpl_PruneLattice(t);
}

//+------------------------------------------------------------------+
bool Rpl_RunTicks(const RplTick &ticks[], const int tick_count, RplSegmentConfig &cfg)
{
   g_rpl_cfg = cfg;
   g_rpl_segment_first_tick = true;
   g_rpl_last_processed_tick_ms = 0;
   ArrayResize(g_rpl_all_ticks, tick_count);
   for(int i = 0; i < tick_count; i++)
      g_rpl_all_ticks[i] = ticks[i];
   g_rpl_all_tick_count = tick_count;
   if(g_rpl_seeded)
      Rpl_PreloadLatticeFromTicks(cfg);
   else if(g_rpl_retained_from_ms == 0)
      g_rpl_retained_from_ms = cfg.from_ms;
   if(g_rpl_seeded) {
      g_grind_start_add_reprice_long = true;
      g_grind_start_add_reprice_short = true;
   }
   g_rpl_seg_ticks_processed = 0;
   Rpl_OrderLogDiff(cfg.from_ms, "SEED");
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
void Rpl_SetSyncRealKindRows(const string &csv_rows[], const int count)
{
   ArrayResize(g_rpl_sync_real, count);
   g_rpl_sync_real_count = count;
   g_rpl_sync_real_applied = 0;
   for(int i = 0; i < count; i++) {
      string parts[];
      const int n = StringSplit(csv_rows[i], ',', parts);
      g_rpl_sync_real[i].time_ms = (n > 0) ? (long)StringToInteger(parts[0]) : 0;
      g_rpl_sync_real[i].kind = (n > 1) ? parts[1] : "";
      g_rpl_sync_real[i].side = (n > 2) ? parts[2] : "";
      g_rpl_sync_real[i].layer = (n > 3) ? (int)StringToInteger(parts[3]) : 0;
      g_rpl_sync_real[i].price = (n > 4) ? StringToDouble(parts[4]) : 0.0;
      g_rpl_sync_real[i].position_id = (n > 5) ? (ulong)StringToInteger(parts[5]) : 0;
      g_rpl_sync_real[i].level = (n > 6) ? StringToDouble(parts[6]) : 0.0;
   }
   g_rpl_cfg.sync = true;
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
int Rpl_GapReportCount()
{
   return g_rpl_gap_count;
}

//+------------------------------------------------------------------+
bool Rpl_GapReportAt(const int index, long &from_ms, long &seconds)
{
   if(index < 0 || index >= g_rpl_gap_count)
      return false;
   from_ms = g_rpl_gaps[index].from_ms;
   seconds = g_rpl_gaps[index].seconds;
   return true;
}

//+------------------------------------------------------------------+
void Rpl_SetTestIntervals(const string &kind[], const long &from_ms[], const long &to_ms[], const int n)
{
   ArrayResize(g_rpl_test_intervals, n);
   g_rpl_test_interval_count = n;
   for(int i = 0; i < n; i++) {
      g_rpl_test_intervals[i].kind = kind[i];
      g_rpl_test_intervals[i].from_ms = from_ms[i];
      g_rpl_test_intervals[i].to_ms = to_ms[i];
   }
}

//+------------------------------------------------------------------+
bool Rpl_PositionSeamHas(const ulong ticket)
{
   for(int i = 0; i < g_grind_position_test_count; i++) {
      if(g_grind_position_test_tickets[i] == ticket)
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
bool Rpl_CloseBySeamHas(const ulong ticket)
{
   return Grind_CloseByTestSelectPosition(ticket);
}

//+------------------------------------------------------------------+
bool Rpl_PosMetaHas(const ulong ticket)
{
   RplPosMeta m;
   return Rpl_FindPosMeta(ticket, m);
}

//+------------------------------------------------------------------+
bool Rpl_CsvFieldsAllEmpty(const string &fields[])
{
   for(int i = 0; i < ArraySize(fields); i++) {
      if(StringLen(fields[i]) > 0)
         return false;
   }
   return true;
}

//+------------------------------------------------------------------+
bool Rpl_CsvReadLineFields(const int h, string &fields[])
{
   ArrayResize(fields, 0);
   if(FileIsEnding(h))
      return false;
   int n = 0;
   do {
      ArrayResize(fields, n + 1);
      fields[n++] = FileReadString(h);
   } while(!FileIsLineEnding(h) && !FileIsEnding(h));
   return true;
}

//+------------------------------------------------------------------+
bool Rpl_CsvHeaderOk(const string &fields[], const string expected0, const string file_tag)
{
   if(ArraySize(fields) == 0 || fields[0] != expected0) {
      const string got = (ArraySize(fields) > 0) ? fields[0] : "";
      Print("RPL|BAD_HEADER|", file_tag, "|", got);
      return false;
   }
   return true;
}

//+------------------------------------------------------------------+
void Rpl_RunReplayClearFileState()
{
   g_rpl_file_interval_count = 0;
   ArrayResize(g_rpl_file_intervals, 0);
   g_rpl_real_file_count = 0;
   ArrayResize(g_rpl_real_file_rows, 0);
}

//+------------------------------------------------------------------+
void Rpl_ParseSyncFields(const string &fields[], const int n, RplSyncRealRow &row)
{
   row.time_ms = (n > 0) ? (long)StringToInteger(fields[0]) : 0;
   row.kind = (n > 1) ? fields[1] : "";
   row.side = (n > 2) ? fields[2] : "";
   row.layer = (n > 3) ? (int)StringToInteger(fields[3]) : 0;
   row.price = (n > 4) ? StringToDouble(fields[4]) : 0.0;
   row.position_id = (n > 5) ? (ulong)StringToInteger(fields[5]) : 0;
   row.level = (n > 6) ? StringToDouble(fields[6]) : 0.0;
}

//+------------------------------------------------------------------+
void Rpl_ApplyIntervalsAt(const long tick_ms)
{
   const int n = (g_rpl_test_interval_count > 0) ? g_rpl_test_interval_count : g_rpl_file_interval_count;
   bool gated = false;
   bool api_warn = false;
   for(int i = 0; i < n; i++) {
      const RplTestInterval iv = (g_rpl_test_interval_count > 0) ? g_rpl_test_intervals[i]
                                                                 : g_rpl_file_intervals[i];
      if(tick_ms < iv.from_ms || tick_ms >= iv.to_ms)
         continue;
      if(iv.kind == "BREAKER_GATED")
         gated = true;
      if(iv.kind == "API_SOFT_WARN")
         api_warn = true;
   }
   g_grind_breaker_enabled = gated;
   g_grind_breaker_gated = gated;
   if(api_warn)
      Grind_ApiLimitsSet(1000000, 1);
   else
      Grind_ApiLimitsSet(1000000, 999000);
}

//+------------------------------------------------------------------+
bool Rpl_LoadRealCsvFile(const string tag)
{
   g_rpl_real_file_count = 0;
   ArrayResize(g_rpl_real_file_rows, 0);
   const int h = FileOpen("replay\\real_" + tag + ".csv", FILE_READ | FILE_CSV | FILE_ANSI, ',');
   if(h == INVALID_HANDLE)
      return false;
   bool header_skipped = false;
   string fields[];
   while(Rpl_CsvReadLineFields(h, fields)) {
      if(Rpl_CsvFieldsAllEmpty(fields))
         continue;
      if(StringFind(fields[0], "#") == 0)
         continue;
      if(!header_skipped) {
         if(!Rpl_CsvHeaderOk(fields, "time_ms", "real_" + tag + ".csv")) {
            FileClose(h);
            return false;
         }
         header_skipped = true;
         continue;
      }
      ArrayResize(g_rpl_real_file_rows, g_rpl_real_file_count + 1);
      Rpl_ParseSyncFields(fields, ArraySize(fields), g_rpl_real_file_rows[g_rpl_real_file_count]);
      g_rpl_real_file_count++;
   }
   FileClose(h);
   return true;
}

//+------------------------------------------------------------------+
void Rpl_LoadSegmentSyncFromFile(const long from_ms, const long to_ms)
{
   ArrayResize(g_rpl_sync_real, 0);
   g_rpl_sync_real_count = 0;
   g_rpl_sync_real_applied = 0;
   for(int i = 0; i < g_rpl_real_file_count; i++) {
      const long tm = g_rpl_real_file_rows[i].time_ms;
      if(tm < from_ms || tm >= to_ms)
         continue;
      ArrayResize(g_rpl_sync_real, g_rpl_sync_real_count + 1);
      g_rpl_sync_real[g_rpl_sync_real_count] = g_rpl_real_file_rows[i];
      g_rpl_sync_real_count++;
   }
}

//+------------------------------------------------------------------+
bool Rpl_LoadIntervalsFile(const string tag)
{
   g_rpl_file_interval_count = 0;
   ArrayResize(g_rpl_file_intervals, 0);
   const int h = FileOpen("replay\\intervals_" + tag + ".csv", FILE_READ | FILE_CSV | FILE_ANSI, ',');
   if(h == INVALID_HANDLE)
      return true;
   bool header_skipped = false;
   string fields[];
   while(Rpl_CsvReadLineFields(h, fields)) {
      if(Rpl_CsvFieldsAllEmpty(fields))
         continue;
      if(StringFind(fields[0], "#") == 0)
         continue;
      if(!header_skipped) {
         if(!Rpl_CsvHeaderOk(fields, "kind", "intervals_" + tag + ".csv")) {
            FileClose(h);
            return false;
         }
         header_skipped = true;
         continue;
      }
      ArrayResize(g_rpl_file_intervals, g_rpl_file_interval_count + 1);
      g_rpl_file_intervals[g_rpl_file_interval_count].kind = fields[0];
      g_rpl_file_intervals[g_rpl_file_interval_count].from_ms =
         (ArraySize(fields) > 1) ? (long)StringToInteger(fields[1]) : 0;
      g_rpl_file_intervals[g_rpl_file_interval_count].to_ms =
         (ArraySize(fields) > 2) ? (long)StringToInteger(fields[2]) : 0;
      g_rpl_file_interval_count++;
   }
   FileClose(h);
   return true;
}

//+------------------------------------------------------------------+
bool Rpl_LoadTicksCsv(const string filename, RplTick &out[], int &count)
{
   count = 0;
   ArrayResize(out, 0);
   const int h = FileOpen("replay\\" + filename, FILE_READ | FILE_CSV | FILE_ANSI, ',');
   if(h == INVALID_HANDLE)
      return false;
   bool header_skipped = false;
   string fields[];
   while(Rpl_CsvReadLineFields(h, fields)) {
      if(Rpl_CsvFieldsAllEmpty(fields))
         continue;
      if(StringFind(fields[0], "#") == 0)
         continue;
      if(!header_skipped) {
         if(!Rpl_CsvHeaderOk(fields, "time_msc_server", filename)) {
            FileClose(h);
            return false;
         }
         header_skipped = true;
         continue;
      }
      const long ms = (long)StringToInteger(fields[0]);
      const double bid = (ArraySize(fields) > 1) ? StringToDouble(fields[1]) : 0.0;
      const double ask = (ArraySize(fields) > 2) ? StringToDouble(fields[2]) : 0.0;
      ArrayResize(out, count + 1, 65536);
      out[count].time_msc = ms;
      out[count].bid = bid;
      out[count].ask = ask;
      count++;
   }
   FileClose(h);
   return count > 0;
}

//+------------------------------------------------------------------+
void Rpl_ComputeSegmentStats(int &fills, int &scalps, int &roll_closes, int &roll_accepted)
{
   fills = 0;
   scalps = 0;
   roll_closes = 0;
   roll_accepted = 0;
   for(int i = 0; i < ArraySize(g_rpl_deals); i++) {
      if(g_rpl_deals[i].entry_type == DEAL_ENTRY_IN)
         fills++;
   }
   for(int i = 0; i < ArraySize(g_rpl_events); i++) {
      if(g_rpl_events[i].code == "ROLL_ACCEPTED")
         roll_accepted++;
      if(g_rpl_events[i].kind != "scalp")
         continue;
      if(StringFind(g_rpl_events[i].json, "\"rolled\":true") >= 0)
         roll_closes++;
      else if(StringFind(g_rpl_events[i].json, "\"rolled\":false") >= 0)
         scalps++;
   }
}

//+------------------------------------------------------------------+
string Rpl_OrderLogTypeCsv(const long otype)
{
   if(otype == ORDER_TYPE_BUY_LIMIT)
      return "BUY_LIMIT";
   if(otype == ORDER_TYPE_SELL_LIMIT)
      return "SELL_LIMIT";
   return IntegerToString(otype);
}

//+------------------------------------------------------------------+
bool Rpl_OpenRunOutputs(const string tag, RplRunOutputHandles &handles)
{
   const string prefix = "replay\\out_" + tag + g_rpl_out_suffix + "_";
   handles.deals = FileOpen(prefix + "deals.csv", FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
   handles.events = FileOpen(prefix + "events.csv", FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
   handles.book = FileOpen(prefix + "book.csv", FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
   handles.summary = FileOpen(prefix + "summary.txt", FILE_WRITE | FILE_TXT | FILE_ANSI);
   handles.orders = FileOpen(prefix + "orders.csv", FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
   handles.open = (handles.deals != INVALID_HANDLE && handles.events != INVALID_HANDLE
                   && handles.book != INVALID_HANDLE && handles.summary != INVALID_HANDLE
                   && handles.orders != INVALID_HANDLE);
   if(!handles.open)
      return false;
   FileWrite(handles.deals, "seg_id", "sync_idx", "time_ms", "deal", "order", "position", "entry_type", "deal_type",
             "role", "side", "layer", "price");
   FileWrite(handles.events, "seg_id", "sync_idx", "time_ms", "kind", "code", "json");
   FileWrite(handles.book, "seg_id", "side", "layer", "entry", "vl", "open_ms", "swap");
   FileWrite(handles.orders, "seg_id", "sync_idx", "time_ms", "stage", "action", "ticket", "type", "side", "layer",
             "role", "price", "old_price");
   return true;
}

//+------------------------------------------------------------------+
void Rpl_CloseRunOutputs(RplRunOutputHandles &handles)
{
   if(handles.deals != INVALID_HANDLE)
      FileClose(handles.deals);
   if(handles.events != INVALID_HANDLE)
      FileClose(handles.events);
   if(handles.book != INVALID_HANDLE)
      FileClose(handles.book);
   if(handles.summary != INVALID_HANDLE)
      FileClose(handles.summary);
   if(handles.orders != INVALID_HANDLE)
      FileClose(handles.orders);
   handles.open = false;
}

//+------------------------------------------------------------------+
void Rpl_AppendSegmentOutputs(RplRunOutputHandles &handles)
{
   if(!handles.open)
      return;
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   for(int i = 0; i < ArraySize(g_rpl_deals); i++) {
      FileWrite(handles.deals, IntegerToString(g_rpl_deals[i].seg_id), IntegerToString(g_rpl_deals[i].sync_idx),
                IntegerToString(g_rpl_deals[i].time_ms), IntegerToString((long)g_rpl_deals[i].deal),
                IntegerToString((long)g_rpl_deals[i].order), IntegerToString((long)g_rpl_deals[i].position),
                IntegerToString(g_rpl_deals[i].entry_type), IntegerToString(g_rpl_deals[i].deal_type),
                g_rpl_deals[i].role, g_rpl_deals[i].side, IntegerToString(g_rpl_deals[i].layer),
                DoubleToString(g_rpl_deals[i].price, digits));
   }
   for(int i = 0; i < ArraySize(g_rpl_events); i++) {
      FileWrite(handles.events, IntegerToString(g_rpl_events[i].seg_id), IntegerToString(g_rpl_events[i].sync_idx),
                IntegerToString(g_rpl_events[i].time_ms), g_rpl_events[i].kind, g_rpl_events[i].code,
                g_rpl_events[i].json);
   }
   for(int i = 0; i < ArraySize(g_rpl_orders); i++) {
      FileWrite(handles.orders, IntegerToString(g_rpl_orders[i].seg_id), IntegerToString(g_rpl_orders[i].sync_idx),
                IntegerToString(g_rpl_orders[i].time_ms), g_rpl_orders[i].stage, g_rpl_orders[i].action,
                IntegerToString((long)g_rpl_orders[i].ticket), Rpl_OrderLogTypeCsv(g_rpl_orders[i].type),
                g_rpl_orders[i].side, IntegerToString(g_rpl_orders[i].layer), g_rpl_orders[i].role,
                DoubleToString(g_rpl_orders[i].price, digits), DoubleToString(g_rpl_orders[i].old_price, digits));
   }
   for(int i = 0; i < ArraySize(g_grind_long.layers); i++) {
      const ulong pt = g_grind_long.layers[i].position_ticket;
      RplPosMeta m;
      double swap = 0.0;
      long open_ms = 0;
      if(Rpl_FindPosMeta(pt, m)) {
         swap = m.swap;
         open_ms = m.open_ms;
      }
      FileWrite(handles.book, IntegerToString(g_rpl_cfg.seg_id), "L", IntegerToString(g_grind_long.layers[i].layer_index),
                DoubleToString(g_grind_long.layers[i].entry_price, 5), DoubleToString(Grind_VLGet(pt), 5),
                IntegerToString(open_ms), DoubleToString(swap, 8));
   }
   for(int i = 0; i < ArraySize(g_grind_short.layers); i++) {
      const ulong pt = g_grind_short.layers[i].position_ticket;
      RplPosMeta m;
      double swap = 0.0;
      long open_ms = 0;
      if(Rpl_FindPosMeta(pt, m)) {
         swap = m.swap;
         open_ms = m.open_ms;
      }
      FileWrite(handles.book, IntegerToString(g_rpl_cfg.seg_id), "S", IntegerToString(g_grind_short.layers[i].layer_index),
                DoubleToString(g_grind_short.layers[i].entry_price, 5), DoubleToString(Grind_VLGet(pt), 5),
                IntegerToString(open_ms), DoubleToString(swap, 8));
   }
   int fills = 0;
   int scalps = 0;
   int roll_closes = 0;
   int roll_accepted = 0;
   Rpl_ComputeSegmentStats(fills, scalps, roll_closes, roll_accepted);
   const uint run_ms = GetTickCount() - g_rpl_seg_run_start_ms;
   const int aborted = g_rpl_aborted ? 1 : 0;
   const string seg_summary =
      "seg_id=" + IntegerToString(g_rpl_cfg.seg_id) + ",ticks=" + IntegerToString(g_rpl_seg_ticks_processed)
      + ",fills=" + IntegerToString(fills) + ",scalps=" + IntegerToString(scalps) + ",roll_closes="
      + IntegerToString(roll_closes) + ",roll_accepted=" + IntegerToString(roll_accepted) + ",gaps="
      + IntegerToString(g_rpl_gap_count) + ",aborted=" + IntegerToString(aborted) + ",run_ms="
      + IntegerToString((int)run_ms);
   FileWrite(handles.summary, seg_summary);
   Print("RPL|SEG_DONE|", seg_summary);
}

//+------------------------------------------------------------------+
bool Rpl_RunReplayFiles(const string tag, const bool sync_mode)
{
   g_rpl_swap_count = 0;
   ArrayResize(g_rpl_swaps, 0);
   Rpl_RunReplayClearFileState();
   const int sh = FileOpen("replay\\swaps.csv", FILE_READ | FILE_CSV | FILE_ANSI, ',');
   if(sh == INVALID_HANDLE) {
      Print("RPL|ABORT|MISSING_SWAPS");
      Rpl_RunReplayClearFileState();
      return false;
   }
   bool swap_header = false;
   string sfields[];
   while(Rpl_CsvReadLineFields(sh, sfields)) {
      if(Rpl_CsvFieldsAllEmpty(sfields))
         continue;
      if(StringFind(sfields[0], "#") == 0)
         continue;
      if(!swap_header) {
         if(!Rpl_CsvHeaderOk(sfields, "server_date", "swaps.csv")) {
            FileClose(sh);
            Print("RPL|ABORT|BAD_SWAPS");
            Rpl_RunReplayClearFileState();
            return false;
         }
         swap_header = true;
         continue;
      }
      const string d = sfields[0];
      const double pl = (ArraySize(sfields) > 1) ? StringToDouble(sfields[1]) : 0.0;
      const double ps = (ArraySize(sfields) > 2) ? StringToDouble(sfields[2]) : 0.0;
      const double mult = (ArraySize(sfields) > 3) ? StringToDouble(sfields[3]) : 1.0;
      Rpl_AppendTestSwap(d, pl, ps, mult);
   }
   FileClose(sh);
   if(!Rpl_LoadIntervalsFile(tag)) {
      Print("RPL|ABORT|BAD_INTERVALS");
      Rpl_RunReplayClearFileState();
      return false;
   }
   if(sync_mode && !Rpl_LoadRealCsvFile(tag)) {
      Print("RPL|ABORT|MISSING_REAL");
      Rpl_RunReplayClearFileState();
      return false;
   }
   const int rh = FileOpen("replay\\run_" + tag + ".csv", FILE_READ | FILE_CSV | FILE_ANSI, ',');
   if(rh == INVALID_HANDLE) {
      Print("RPL|ABORT|MISSING_RUN");
      Rpl_RunReplayClearFileState();
      return false;
   }
   RplRunOutputHandles out;
   if(!Rpl_OpenRunOutputs(tag, out)) {
      FileClose(rh);
      Print("RPL|ABORT|OUTPUT_OPEN");
      Rpl_RunReplayClearFileState();
      return false;
   }
   string tick_cache_name = "";
   RplTick tick_cache[];
   int tick_cache_count = 0;
   bool run_header = false;
   int seg_line = 0;
   string fields[];
   while(Rpl_CsvReadLineFields(rh, fields)) {
      if(Rpl_CsvFieldsAllEmpty(fields))
         continue;
      if(StringFind(fields[0], "#") == 0)
         continue;
      if(!run_header) {
         if(!Rpl_CsvHeaderOk(fields, "seg_id", "run_" + tag + ".csv")) {
            FileClose(rh);
            Rpl_CloseRunOutputs(out);
            Print("RPL|ABORT|BAD_RUN");
            Rpl_RunReplayClearFileState();
            return false;
         }
         run_header = true;
         continue;
      }
      seg_line++;
      if(ArraySize(fields) < 22) {
         FileClose(rh);
         Rpl_CloseRunOutputs(out);
         Print("RPL|ABORT|BAD_RUN_ROW|seg_line=", seg_line, "|fields=", ArraySize(fields));
         Rpl_RunReplayClearFileState();
         return false;
      }
      const string seed_file = fields[20];
      const string ticks_file = fields[21];
      if(StringLen(ticks_file) == 0) {
         FileClose(rh);
         Rpl_CloseRunOutputs(out);
         Print("RPL|ABORT|BAD_RUN_ROW|seg_line=", seg_line, "|ticks_file=empty");
         Rpl_RunReplayClearFileState();
         return false;
      }
      if(ticks_file != tick_cache_name) {
         const uint load_t0 = GetTickCount();
         if(!Rpl_LoadTicksCsv(ticks_file, tick_cache, tick_cache_count)) {
            Print("RPL|ABORT|MISSING_TICKS");
            FileClose(rh);
            Rpl_CloseRunOutputs(out);
            Rpl_RunReplayClearFileState();
            return false;
         }
         Print("RPL|TICKS_LOADED|", ticks_file, "|count=", tick_cache_count, "|load_ms=",
               (int)(GetTickCount() - load_t0));
         tick_cache_name = ticks_file;
      }
      RplSegmentConfig cfg;
      Rpl_SegmentConfigDefaults(cfg);
      cfg.seg_id = (int)StringToInteger(fields[0]);
      cfg.instance = fields[1];
      cfg.magic = (ulong)StringToInteger(fields[2]);
      cfg.from_ms = (long)StringToInteger(fields[3]);
      cfg.to_ms = (long)StringToInteger(fields[4]);
      cfg.width_l = StringToDouble(fields[5]);
      cfg.width_s = StringToDouble(fields[6]);
      cfg.add_l = StringToDouble(fields[7]);
      cfg.add_s = StringToDouble(fields[8]);
      cfg.exit_l = StringToDouble(fields[9]);
      cfg.exit_s = StringToDouble(fields[10]);
      cfg.cap = (int)StringToInteger(fields[11]);
      cfg.stranded = StringToDouble(fields[12]);
      cfg.deadband = StringToDouble(fields[13]);
      cfg.lattice = (StringToInteger(fields[14]) != 0);
      cfg.reroll = (StringToInteger(fields[15]) != 0);
      cfg.gate = (int)StringToInteger(fields[16]);
      cfg.carry = (StringToInteger(fields[17]) != 0);
      cfg.fill_time_place = (StringToInteger(fields[18]) != 0);
      cfg.reserve = (int)StringToInteger(fields[19]);
      Rpl_ResetAll();
      g_rpl_gap_count = 0;
      ArrayResize(g_rpl_gaps, 0);
      cfg.sync = sync_mode;
      g_rpl_cfg = cfg;
      Rpl_ConfigureEngine(cfg);
      g_rpl_seg_run_start_ms = GetTickCount();
      if(seed_file != "") {
         int sd = FileOpen("replay\\" + seed_file, FILE_READ | FILE_CSV | FILE_ANSI, ',');
         if(sd == INVALID_HANDLE) {
            Print("RPL|ABORT|MISSING_SEED");
            FileClose(rh);
            Rpl_CloseRunOutputs(out);
            Rpl_RunReplayClearFileState();
            return false;
         }
         bool seed_header = false;
         string seed_fields[];
         while(Rpl_CsvReadLineFields(sd, seed_fields)) {
            if(Rpl_CsvFieldsAllEmpty(seed_fields))
               continue;
            if(StringFind(seed_fields[0], "#") == 0)
               continue;
            if(!seed_header) {
               if(!Rpl_CsvHeaderOk(seed_fields, "side", seed_file)) {
                  FileClose(sd);
                  FileClose(rh);
                  Rpl_CloseRunOutputs(out);
                  Print("RPL|ABORT|BAD_SEED");
                  Rpl_RunReplayClearFileState();
                  return false;
               }
               seed_header = true;
               continue;
            }
            const string side = seed_fields[0];
            const int layer = (ArraySize(seed_fields) > 1) ? (int)StringToInteger(seed_fields[1]) : 0;
            const double entry = (ArraySize(seed_fields) > 2) ? StringToDouble(seed_fields[2]) : 0.0;
            const long open_ms = (ArraySize(seed_fields) > 3) ? (long)StringToInteger(seed_fields[3]) : 0;
            const ulong ticket = (ArraySize(seed_fields) > 4) ? (ulong)StringToInteger(seed_fields[4]) : 0;
            const double vl = (ArraySize(seed_fields) > 5) ? StringToDouble(seed_fields[5]) : 0.0;
            const double swap = (ArraySize(seed_fields) > 6) ? StringToDouble(seed_fields[6]) : 0.0;
            const double vol = (ArraySize(seed_fields) > 7) ? StringToDouble(seed_fields[7]) : RPL_LOTS_DEFAULT;
            const double accrued = (ArraySize(seed_fields) > 8) ? StringToDouble(seed_fields[8]) : 0.0;
            Rpl_SeedLayer(side, layer, entry, open_ms, ticket, vl, swap, vol);
            if(accrued != 0.0)
               Rpl_SeedAccrued(ticket, accrued);
         }
         FileClose(sd);
      }
      if(ArraySize(fields) > 22 && StringLen(fields[22]) > 0) {
         if(!Rpl_LoadOrdersFile(fields[22], cfg.seg_id)) {
            FileClose(rh);
            Rpl_CloseRunOutputs(out);
            Rpl_RunReplayClearFileState();
            return false;
         }
         if(g_rpl_aborted) {
            FileClose(rh);
            Rpl_AppendSegmentOutputs(out);
            Rpl_CloseRunOutputs(out);
            Rpl_RunReplayClearFileState();
            return false;
         }
      }
      if(sync_mode)
         Rpl_LoadSegmentSyncFromFile(cfg.from_ms, cfg.to_ms);
      Print("RPL|SEG|", cfg.seg_id, "|from=", cfg.from_ms, "|to=", cfg.to_ms, "|seed=", seed_file);
      if(!Rpl_RunTicks(tick_cache, tick_cache_count, cfg)) {
         FileClose(rh);
         Rpl_AppendSegmentOutputs(out);
         Rpl_CloseRunOutputs(out);
         Rpl_RunReplayClearFileState();
         return false;
      }
      Rpl_AppendSegmentOutputs(out);
   }
   FileClose(rh);
   Rpl_CloseRunOutputs(out);
   const bool ok = !g_rpl_aborted;
   Rpl_RunReplayClearFileState();
   return ok;
}

#endif // FXGRIND_REPLAY_CORE_MQH
