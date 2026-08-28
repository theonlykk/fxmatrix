//+------------------------------------------------------------------+
//| fxmatrix_v2_engine.mqh — unified V2 engine body (Phase B)          |
//| Pair-agnostic: g_preset + shell inputs + V2_Cap_* bridge only.   |
//| Requires: g_preset (preset fragment), shell inputs, cap bridge.  |
//+------------------------------------------------------------------+
#ifndef FXMATRIX_V2_ENGINE_MQH
#define FXMATRIX_V2_ENGINE_MQH

#include "fxmatrix_v2_logic.mqh"
#include "fxmatrix_v2_exits.mqh"
#include "fxmatrix_v2_carry.mqh"
#include "fxmatrix_v2_cap_bridge.mqh"
#include "fxmatrix_v2_l0_signal.mqh"
#include "fxmatrix_v2_state_reconstruction.mqh"
#include "fxmatrix_v2_sre_oninit.mqh"
#include "fxmatrix_v2_bcc.mqh"
#include "fxmatrix_v2_circuit_breaker.mqh"
#include "fxmatrix_v2_mae.mqh"
#include "fxmatrix_v2_telemetry.mqh"
#include "fxmatrix_v2_trigger_a.mqh"
#include "fxmatrix_v2_entry_ab.mqh"

//+------------------------------------------------------------------+
double g_straddle_ref_mid = 0.0;
ulong    g_long_l0_cooldown_until = 0;
ulong    g_short_l0_cooldown_until = 0;
long     g_last_feed_tick_msc = 0;
ulong    g_last_feed_seen_local = 0;
string   g_v2_inst_api_tag = "";
double V2_EngineDeadbandSpreadRef()
{
   if(!g_preset.l0_deadband_vol_scale_enabled)
      return 0.0;
   return InpL0DeadbandVolScale ? g_preset.l0_deadband_spread_ref_pips : 0.0;
}

//+------------------------------------------------------------------+
V2L0SignalContext V2_EngineBuildLongL0Context()
{
   V2L0SignalContext ctx;
   ctx.quote_spread = InpQuoteSpread;
   ctx.spread_multiplier = InpSpreadMultiplier;
   ctx.spread_multiplier_eased = InpSpreadMultiplierEased;
   ctx.ease_depth_start = InpEaseDepthStart;
   ctx.ease_depth_full = InpEaseDepthFull;
   ctx.passivity_buffer_pips = InpPassivityBuffer;
   ctx.quoting_side_flat = (ArraySize(g_long_layers) == 0);
   ctx.opposite_depth = ArraySize(g_short_layers);
   ctx.leg_ac = InpLegAC;
   ctx.leg_bc = InpLegBC;
   return ctx;
}

V2L0SignalContext V2_EngineBuildShortL0Context()
{
   V2L0SignalContext ctx;
   ctx.quote_spread = InpQuoteSpread;
   ctx.spread_multiplier = InpSpreadMultiplier;
   ctx.spread_multiplier_eased = InpSpreadMultiplierEased;
   ctx.ease_depth_start = InpEaseDepthStart;
   ctx.ease_depth_full = InpEaseDepthFull;
   ctx.passivity_buffer_pips = InpPassivityBuffer;
   ctx.quoting_side_flat = (ArraySize(g_short_layers) == 0);
   ctx.opposite_depth = ArraySize(g_long_layers);
   ctx.leg_ac = InpLegAC;
   ctx.leg_bc = InpLegBC;
   return ctx;
}

//+------------------------------------------------------------------+
void V2_EngineApplyEntryModeIdentity()
{
   V2_InitPresetCapNamespace(g_preset);
   if(InpEntryMode == ENTRY_STRADDLE)
      V2_ApplyStraddleIdentityTransform(g_preset);
}

//+------------------------------------------------------------------+
bool V2_IsFeedStale(const string symbol, const ulong max_age_ms)
{
   MqlTick tick;
   if(!SymbolInfoTick(symbol, tick))
      return true;
   const ulong now_local = GetTickCount64();
   if(tick.time_msc != g_last_feed_tick_msc) {
      g_last_feed_tick_msc = tick.time_msc;
      g_last_feed_seen_local = now_local;
      return false;
   }
   return V2_FeedStaleElapsed(now_local, g_last_feed_seen_local, max_age_ms);
}

//+------------------------------------------------------------------+
void V2_StraddleL0OnTick()
{
   if(InpEntryMode != ENTRY_STRADDLE)
      return;

   if(V2_IsFeedStale(_Symbol, (ulong)InpFeedStaleMaxMs))
      return;

   const bool long_flat = (ArraySize(g_long_layers) == 0);
   const bool short_flat = (ArraySize(g_short_layers) == 0);
   if(!long_flat && !short_flat)
      return;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double mid = V2_DumbStraddleMid(bid, ask);
   const bool mid_drifted = V2_DumbShouldRePlace(g_straddle_ref_mid, mid,
                                                 InpDumbRefBandPips, _Point);
   const bool ref_established = (g_straddle_ref_mid > 0.0);
   const ulong now_ms = GetTickCount64();

   if(long_flat) {
      const bool long_live = Long_IsOurOrderTicket(g_long_l0_ticket, g_preset.magic_long);
      if(V2_StraddleLegShouldAttempt(long_live, mid_drifted, ref_established)) {
         double buy_theo = V2_DumbStraddleBuyPrice(mid, InpDumbStraddlePips, _Point);
         double buy_lvl;
         Long_Adr013ClampBuy(buy_theo, buy_lvl);
         const double ask_now = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(V2_StraddleL0CooldownBlocks(g_long_l0_cooldown_until, now_ms)) {
            // side blocked by hard cooldown
         } else if(!V2_StraddleL0BuyMarketable(buy_lvl, ask_now)) {
            if(InpVerboseLog)
               Print("DIAG V2_LONG | event=straddle_l0_marketability_skip | buy_lvl=",
                     DoubleToString(buy_lvl, 5), " ask=", DoubleToString(ask_now, 5));
         } else {
            g_v2_inst_api_tag = g_preset.tel_instance_long;
            if(Long_ReplacePendingBuy(g_long_l0_ticket, buy_lvl, g_preset.magic_long, "V2_L0")) {
               if(InpVerboseLog)
                  Print("DIAG V2_LONG | event=straddle_l0 | mid=", DoubleToString(mid, 5),
                        " buy_lvl=", DoubleToString(buy_lvl, 5));
            } else {
               g_long_l0_cooldown_until = now_ms + (ulong)InpL0RetryCooldownMs;
            }
         }
      }
   }

   if(short_flat) {
      const bool short_live = Short_IsOurOrderTicket(g_short_l0_ticket, g_preset.magic_short);
      if(V2_StraddleLegShouldAttempt(short_live, mid_drifted, ref_established)) {
         double sell_theo = V2_DumbStraddleSellPrice(mid, InpDumbStraddlePips, _Point);
         double sell_lvl;
         Short_Adr013ClampSell(sell_theo, sell_lvl);
         const double bid_now = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(V2_StraddleL0CooldownBlocks(g_short_l0_cooldown_until, now_ms)) {
            // side blocked by hard cooldown
         } else if(!V2_StraddleL0SellMarketable(sell_lvl, bid_now)) {
            if(InpVerboseLog)
               Print("DIAG V2_SHORT | event=straddle_l0_marketability_skip | sell_lvl=",
                     DoubleToString(sell_lvl, 5), " bid=", DoubleToString(bid_now, 5));
         } else {
            g_v2_inst_api_tag = g_preset.tel_instance_short;
            if(Short_ReplacePendingSell(g_short_l0_ticket, sell_lvl, g_preset.magic_short, "V2_L0")) {
               if(InpVerboseLog)
                  Print("DIAG V2_SHORT | event=straddle_l0 | mid=", DoubleToString(mid, 5),
                        " sell_lvl=", DoubleToString(sell_lvl, 5));
            } else {
               g_short_l0_cooldown_until = now_ms + (ulong)InpL0RetryCooldownMs;
            }
         }
      }
   }

   if(long_flat && short_flat) {
      const bool long_live = Long_IsOurOrderTicket(g_long_l0_ticket, g_preset.magic_long);
      const bool short_live = Short_IsOurOrderTicket(g_short_l0_ticket, g_preset.magic_short);
      V2_StraddleRefMidApplyGoalpost(long_flat, short_flat, long_live, short_live,
                                     mid, g_straddle_ref_mid);
   }
}

struct LongV2Layer {
   double entry_price;
   double exit_target;
   ulong  entry_ticket;
   ulong  position_ticket;
   ulong  exit_ticket;
   datetime last_exit_retry_time;
   datetime first_exit_retry_time;
   bool     exit_escalated;
   bool     exit_is_market_hedge;
   int      open_depth;   // 0=L0 at fill (Python sim parity; stable after compaction)
   datetime entry_time;   // layer open time for resolution metrics
};

LongV2Layer  g_long_layers[];
double   g_long_last_exit_price;
bool     g_long_last_exit_valid;
double   g_long_current_add_pips;
ulong    g_long_l0_ticket;
ulong    g_long_add_ticket;
datetime g_long_last_bar_time;
bool     g_long_halted = false;

V2CloseByTask g_long_closeby_queue[];
string        g_long_system_alerts[];
V2BccSideRuntime g_long_bcc;

int g_long_stat_l0_entries;
int g_long_stat_l0_requote;
int g_long_stat_l0_deadband_skip;
int g_long_stat_add_entries;
int g_long_stat_reload_entries;
int g_long_stat_exits;
int g_long_stat_max_layers;
int g_long_stat_exit_place_fail;
int g_long_stat_exit_limit_placed;

ulong g_long_processed_deals[];
int   g_long_processed_count;

V2PodSession g_long_pod;
V2PodSession g_short_pod;
datetime     g_last_telemetry_emit = 0;
int          g_v2_last_rollover_day_of_year = 0;
V2RolloverSideRetryState g_long_rollover_retry;
V2RolloverSideRetryState g_short_rollover_retry;

//+------------------------------------------------------------------+
double Long_PipsToPrice(const double pips) {
   return pips * _Point * 10.0;
}

double Long_NormalizeSym(const double price) {
   return NormalizeDouble(price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
}

bool Long_Adr013ClampBuy(const double theoretical, double &out_price) {
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double min_dist = MathMax(_Point, SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point);
   if (theoretical >= bid)
      out_price = Long_NormalizeSym(MathMin(theoretical, bid - min_dist));
   else
      out_price = Long_NormalizeSym(theoretical);
   return (MathAbs(out_price - theoretical) > _Point * 0.1);
}

bool Long_ComputeBidSignal(double &bid_theoretical) {
   V2L0SignalContext ctx = V2_EngineBuildLongL0Context();
   V2L0CoreDiagnostics diag;
   if(!V2_L0ComputeBid(g_preset, ctx, bid_theoretical, diag))
      return false;
   if(InpVerboseLog && g_preset.signal_slot == V2_SIGNAL_AB_TRIAD)
   {
      V2_L0PrintAbCoreDiag("LONG", diag, bid_theoretical);
      if(ctx.quoting_side_flat && ctx.opposite_depth > InpEaseDepthStart)
         V2_L0PrintAbEaseDiag("LONG", ctx.opposite_depth, diag);
   }
   else if(InpVerboseLog && ctx.quoting_side_flat && ctx.opposite_depth > InpEaseDepthStart)
      Print("DIAG V2_LONG | event=l0_ease | opposite_depth=", ctx.opposite_depth,
            " effective_multiplier=", DoubleToString(diag.effective_multiplier, 6),
            " dynamic_hs=", DoubleToString(diag.dynamic_hs, 6));
   return true;
}

bool Long_IsOurOrderTicket(const ulong ticket, const ulong magic) {
   if (ticket == 0)
      return false;
   if (OrderSelect(ticket))
      return (OrderGetInteger(ORDER_MAGIC) == (long)magic);
   if (HistoryOrderSelect(ticket))
      return (HistoryOrderGetInteger(ticket, ORDER_MAGIC) == (long)magic);
   return false;
}

void Long_CancelTicket(const ulong ticket) {
   if (ticket == 0)
      return;
   if (!OrderSelect(ticket))
      return;
   MqlTradeRequest req = {};
   MqlTradeResult  res = {};
   req.action = TRADE_ACTION_REMOVE;
   req.order  = ticket;
   g_v2_inst_api_tag = g_preset.tel_instance_long;
   V2_OrderSendCounted(req, res);
}

ulong Long_PlaceBuyLimit(const double price, const ulong magic, const string comment) {
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double min_dist = MathMax(_Point, SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point);
   if (price > bid - min_dist)
      return 0;

   MqlTradeRequest req = {};
   MqlTradeResult  res = {};
   req.action       = TRADE_ACTION_PENDING;
   req.symbol       = _Symbol;
   req.volume       = InpLotSize;
   req.type         = ORDER_TYPE_BUY_LIMIT;
   req.price        = Long_NormalizeSym(price);
   req.magic        = magic;
   req.type_filling = ORDER_FILLING_RETURN;
   req.type_time    = ORDER_TIME_GTC;
   req.comment      = comment;
   g_v2_inst_api_tag = g_preset.tel_instance_long;
   if (!V2_OrderSendCounted(req, res))
      return 0;
   return res.order;
}

ulong Long_PlaceSellLimit(const double price, const ulong magic, const string comment) {
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double min_dist = MathMax(_Point, SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point);
   if (price < ask + min_dist)
      return 0;

   MqlTradeRequest req = {};
   MqlTradeResult  res = {};
   req.action       = TRADE_ACTION_PENDING;
   req.symbol       = _Symbol;
   req.volume       = InpLotSize;
   req.type         = ORDER_TYPE_SELL_LIMIT;
   req.price        = Long_NormalizeSym(price);
   req.magic        = magic;
   req.type_filling = ORDER_FILLING_RETURN;
   req.type_time    = ORDER_TIME_GTC;
   req.comment      = comment;
   g_v2_inst_api_tag = g_preset.tel_instance_long;
   if (!V2_OrderSendCounted(req, res))
      return 0;
   return res.order;
}

ulong Long_ResolvePositionTicket(const ulong position_ref) {
   if (position_ref == 0)
      return 0;
   if (PositionSelectByTicket(position_ref))
      return position_ref;
   for (int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if (!PositionSelectByTicket(ticket))
         continue;
      if ((ulong)PositionGetInteger(POSITION_IDENTIFIER) == position_ref)
         return ticket;
   }
   return 0;
}

bool Long_SetExitTakeProfit(const int layer_idx) {
   if (layer_idx < 0 || layer_idx >= ArraySize(g_long_layers))
      return false;

   ulong position_ticket = Long_ResolvePositionTicket(g_long_layers[layer_idx].position_ticket);
   if (position_ticket == 0)
      return false;

   double target = Long_NormalizeSym(g_long_layers[layer_idx].exit_target);
   ulong existing = g_long_layers[layer_idx].exit_ticket;
   if(existing != 0 && V2_ExitOrderLiveOrFilled(existing))
      return true;

   if(existing != 0) {
      V2_CancelExitOrder(existing, g_preset.tel_instance_long);
      g_long_layers[layer_idx].exit_ticket = 0;
      g_long_layers[layer_idx].exit_is_market_hedge = false;
   }

   // STEP 1: harvest-at-market (stored target; preempts any limit placement).
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(bid >= target) {
      ulong hedge_order = 0;
      double filled_vol = 0.0;
      const V2ExitHedgeOpenOutcome hedge_result =
         V2_OpenExitHedgeAtMarket(_Symbol, +1, InpLotSize, g_preset.magic_long_exit,
                                  g_preset.tel_instance_long, hedge_order, filled_vol);
      if(hedge_result == V2_EXIT_HEDGE_OPEN_FULL) {
         g_long_layers[layer_idx].exit_ticket = hedge_order;
         g_long_layers[layer_idx].exit_is_market_hedge = true;
         if(InpVerboseLog)
            Print("DIAG V2_LONG | event=exit_market_close | layer=", layer_idx,
                  " target=", DoubleToString(target, 5),
                  " bid=", DoubleToString(bid, 5));
         return true;
      }
      if(hedge_result == V2_EXIT_HEDGE_OPEN_PARTIAL) {
         g_long_halted = true;
         V2_PushSystemAlert(g_long_system_alerts,
            StringFormat("V2_EXIT_HEDGE_PARTIAL | side=LONG | layer=%d | filled=%.4f | requested=%.4f",
                         layer_idx, filled_vol, InpLotSize));
         return true;
      }
   }

   // STEP 2: Option-1 stretch (local `place` only; stored exit_target unchanged).
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double buffer = V2_ExitClearanceBuffer(_Symbol);
   double place = Long_NormalizeSym(MathMax(target, ask + buffer));

   // STEP 3: rest passive limit at `place`.
   ulong exit_order = V2_SendExitLimit(_Symbol, place, InpLotSize, 1,
                                       g_preset.magic_long_exit, place,
                                       g_preset.tel_instance_long);
   if(exit_order == 0) {
      if (InpVerboseLog)
         Print("WARN V2_LONG | exit limit placement failed layer=", layer_idx,
               " target=", DoubleToString(target, 5),
               " place=", DoubleToString(place, 5));
      return false;
   }

   g_long_layers[layer_idx].exit_ticket = exit_order;
   g_long_layers[layer_idx].last_exit_retry_time  = 0;
   g_long_layers[layer_idx].first_exit_retry_time = 0;
   g_long_layers[layer_idx].exit_escalated        = false;
   return true;
}

void Long_ClearExitTakeProfit(const ulong position_ref) {
   int n = ArraySize(g_long_layers);
   for(int i = 0; i < n; i++) {
      if(g_long_layers[i].position_ticket != position_ref)
         continue;
      V2_CancelExitOrder(g_long_layers[i].exit_ticket, g_preset.tel_instance_long);
      g_long_layers[i].exit_ticket = 0;
      g_long_layers[i].exit_is_market_hedge = false;
      return;
   }
}

double Long_ComputeAddTarget() {
   int n = ArraySize(g_long_layers);
   if (n <= 0)
      return 0.0;

   double step_pips;
   double anchor;
   if (g_long_last_exit_valid) {
      anchor = g_long_last_exit_price;
      step_pips = V2_ADD_PIPS_FLOOR;
   } else {
      anchor = g_long_layers[n - 1].entry_price;
      bool still_shallow = (n < 3);
      step_pips = still_shallow ? InpAddPipsFloor : g_long_current_add_pips;
   }
   return Long_NormalizeSym(anchor - Long_PipsToPrice(step_pips));
}

bool Long_ReplacePendingBuy(ulong &ticket_ref, const double price, const ulong magic, const string comment) {
   if(InpEntryMode == ENTRY_SIGNAL &&
      V2_L0RestingWithinDeadband(ticket_ref, price, InpQuoteSpread, InpL0DeadbandMult, V2_EngineDeadbandSpreadRef())) {
      g_long_stat_l0_deadband_skip++;
      return false;
   }
   Long_CancelTicket(ticket_ref);
   ticket_ref = Long_PlaceBuyLimit(price, magic, comment);
   if(ticket_ref > 0) {
      g_long_stat_l0_requote++;
      return true;
   }
   return false;
}

void Long_PlaceExitForLayer(const int layer_idx, const bool immediate) {
   if (layer_idx < 0 || layer_idx >= ArraySize(g_long_layers))
      return;

   double target = g_long_layers[layer_idx].exit_target;
   if (Long_SetExitTakeProfit(layer_idx)) {
      g_long_stat_exit_limit_placed++;
      if (InpVerboseLog && immediate)
         Print("DIAG V2_LONG | event=exit_placed | layer=", layer_idx,
               " target=", DoubleToString(target, 5),
               " ticket=", g_long_layers[layer_idx].exit_ticket);
      return;
   }

   g_long_stat_exit_place_fail++;
   if (InpVerboseLog) {
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      Print("WARN V2_LONG | exit placement failed layer=", layer_idx,
            " target=", DoubleToString(target, 5),
            " ask=", DoubleToString(ask, 5),
            " immediate=", (immediate ? "1" : "0"));
   }
}

void Long_AuditExitLimits() {
   if(g_long_halted)
      return;

   datetime now = TimeCurrent();
   int n = ArraySize(g_long_layers);
   for(int i = 0; i < n; i++) {
      ulong position_ticket = Long_ResolvePositionTicket(g_long_layers[i].position_ticket);
      bool position_live = (position_ticket != 0 &&
                            PositionSelectByTicket(position_ticket));
      bool exit_live = V2_ExitOrderLiveOrFilled(g_long_layers[i].exit_ticket);

      if(g_long_layers[i].exit_ticket != 0 && !exit_live) {
         if(InpVerboseLog)
            Print("WARNING V2_LONG | stale exit ticket cleared layer=", i,
                  " ticket=", g_long_layers[i].exit_ticket);
         g_long_layers[i].exit_ticket = 0;
         g_long_layers[i].exit_is_market_hedge = false;
         exit_live = false;
      }

      V2ExitAuditAction action = V2_EvaluateExitAudit(
         position_live,
         exit_live,
         g_long_layers[i].last_exit_retry_time,
         g_long_layers[i].first_exit_retry_time,
         g_long_layers[i].exit_escalated,
         now);

      if(action == V2_EXIT_AUDIT_OK || action == V2_EXIT_AUDIT_THROTTLED)
         continue;

      if(action == V2_EXIT_AUDIT_ESCALATE) {
         V2_EscalateExitAlert(g_long_system_alerts, g_preset.tel_instance_long, i,
                              g_long_layers[i].exit_target,
                              g_long_layers[i].exit_escalated);
      }

      if(g_long_layers[i].first_exit_retry_time == 0)
         g_long_layers[i].first_exit_retry_time = now;
      g_long_layers[i].last_exit_retry_time = now;

      if(Long_SetExitTakeProfit(i)) {
         g_long_stat_exit_limit_placed++;
         if(InpVerboseLog)
            Print("INFO V2_LONG | AuditExitLimits recovered layer=", i,
                  " ticket=", g_long_layers[i].exit_ticket);
      } else {
         g_long_stat_exit_place_fail++;
      }
   }
}

void Long_EnsureAddNext() {
   int n = ArraySize(g_long_layers);
   if (n <= 0 || n >= InpMaxLayers)
      return;
   if (g_long_add_ticket != 0 && OrderSelect(g_long_add_ticket))
      return;

   double add_price = Long_ComputeAddTarget();
   if (add_price <= 0.0)
      return;
   if(!g_long_last_exit_valid &&
      V2_Cap_CheckBlocks(true)) {
      V2_Cap_RecordBlock(true);
      return;
   }
   g_long_add_ticket = Long_PlaceBuyLimit(add_price, g_preset.magic_long, g_long_last_exit_valid ? "V2_Reload" : "V2_Add");
}

void Long_OnNewBar() {
   datetime bar_time = iTime(_Symbol, PERIOD_M5, 0);
   if (bar_time == g_long_last_bar_time)
      return;
   g_long_last_bar_time = bar_time;

   int n = ArraySize(g_long_layers);
   if (n == 0 && InpEntryMode == ENTRY_SIGNAL) {
      double bid_theoretical;
      if (!Long_ComputeBidSignal(bid_theoretical))
         return;

      double bid_lvl;
      Long_Adr013ClampBuy(bid_theoretical, bid_lvl);

      g_long_last_exit_valid = false;
      if(InpVerboseLog && ArraySize(g_short_layers) > InpEaseDepthStart) {
         const double resting_price = V2_GetPendingOrderPrice(g_long_l0_ticket);
         const bool deadband_skip = V2_L0RestingWithinDeadband(g_long_l0_ticket, bid_lvl, InpQuoteSpread, InpL0DeadbandMult, V2_EngineDeadbandSpreadRef());
         const double gap_pips = (resting_price > 0.0)
            ? MathAbs(bid_theoretical - resting_price) / (_Point * 10.0)
            : 0.0;
         Print("DIAG V2_LONG | event=l0_lag | resting_price=", DoubleToString(resting_price, 5),
               " theo_price=", DoubleToString(bid_theoretical, 5),
               " gap_pips=", DoubleToString(gap_pips, 2),
               " deadband_skip=", (deadband_skip ? "true" : "false"));
      }
      if(Long_ReplacePendingBuy(g_long_l0_ticket, bid_lvl, g_preset.magic_long, "V2_L0") && InpVerboseLog)
         Print("DIAG V2_LONG | event=l0_quote | bid_theo=", DoubleToString(bid_theoretical, 5),
               " bid_lvl=", DoubleToString(bid_lvl, 5));
   }

   Long_EnsureAddNext();
}

void Long_AppendLayer(const double entry_price, const ulong entry_ticket,
                 const ulong position_ticket, const bool is_reload) {
   int n = ArraySize(g_long_layers);
   ArrayResize(g_long_layers, n + 1);
   g_long_layers[n].entry_price      = Long_NormalizeSym(entry_price);
   g_long_layers[n].entry_ticket     = entry_ticket;
   g_long_layers[n].position_ticket  = position_ticket;
   g_long_layers[n].exit_ticket      = 0;
   g_long_layers[n].exit_target      = Long_NormalizeSym(entry_price + Long_PipsToPrice(InpExitPips));
   g_long_layers[n].last_exit_retry_time  = 0;
   g_long_layers[n].first_exit_retry_time = 0;
   g_long_layers[n].exit_escalated        = false;
   g_long_layers[n].exit_is_market_hedge   = false;
   g_long_layers[n].open_depth            = n;
   g_long_layers[n].entry_time            = TimeCurrent();

   if (n == 0)
      g_long_stat_l0_entries++;
   else if (is_reload)
      g_long_stat_reload_entries++;
   else
      g_long_stat_add_entries++;

   if(n == 0) {
      datetime entry_time = TimeCurrent();
      V2PodOnFirstLayer(g_long_pod, Long_NormalizeSym(entry_price), entry_time);
   }

   if (ArraySize(g_long_layers) > g_long_stat_max_layers)
      g_long_stat_max_layers = ArraySize(g_long_layers);

   if (ArraySize(g_long_layers) >= 3)
      g_long_current_add_pips = MathMin(InpAddPipsCeiling, g_long_current_add_pips * InpWidenRatio);

   if (is_reload)
      g_long_last_exit_valid = false;

   Long_CancelTicket(g_long_add_ticket);
   g_long_add_ticket = 0;

   V2_Cap_Sync(true, ArraySize(g_long_layers));
   Long_PlaceExitForLayer(n, true);
   Long_EnsureAddNext();
}

bool V2_EngineRebaseOriginSuppressed(const datetime fill_time)
{
   return V2_RebaseOriginSuppressed(fill_time, _Symbol,
                                    InpRebaseBlackoutSec, InpRebaseMaxSpreadPips);
}

void Long_RemoveLayerAt(const int layer_idx,
                        const bool from_clean_harvest = false,
                        const datetime fill_time = 0) {
   int n = ArraySize(g_long_layers);
   if(layer_idx < 0 || layer_idx >= n)
      return;

   bool was_top = (layer_idx == n - 1);
   if(was_top && from_clean_harvest) {
      if(V2_EngineRebaseOriginSuppressed(fill_time)) {
         g_long_last_exit_valid = false;
      } else {
         const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
         g_long_last_exit_price = V2_SRE_ExpectedExitPrice(
            g_long_layers[layer_idx].entry_price, +1, InpExitPips, point);
         g_long_last_exit_valid = true;
      }
   }

   V2_CancelExitOrder(g_long_layers[layer_idx].exit_ticket, g_preset.tel_instance_long);
   if(was_top) {
      Long_CancelTicket(g_long_add_ticket);
      g_long_add_ticket = 0;
   }

   for(int i = layer_idx; i < n - 1; i++)
      g_long_layers[i] = g_long_layers[i + 1];
   ArrayResize(g_long_layers, n - 1);
   g_long_stat_exits++;

   V2_OnOwnStackFlat(g_long_last_exit_valid, ArraySize(g_long_layers));
   V2_Cap_Sync(true, ArraySize(g_long_layers));
   if(ArraySize(g_long_layers) == 0)
      g_long_current_add_pips = InpAddPipsFloor;
   else if(was_top)
      Long_EnsureAddNext();
}

void Long_PopTopLayer() {
   Long_RemoveLayerAt(ArraySize(g_long_layers) - 1, false);
}

bool Long_DealWasProcessed(const ulong deal_ticket) {
   for (int i = 0; i < g_long_processed_count; i++)
      if (g_long_processed_deals[i] == deal_ticket)
         return true;
   return false;
}

void Long_MarkDealProcessed(const ulong deal_ticket) {
   if (Long_DealWasProcessed(deal_ticket))
      return;
   ArrayResize(g_long_processed_deals, g_long_processed_count + 1);
   g_long_processed_deals[g_long_processed_count++] = deal_ticket;
}

void Long_HandleDealFill(const ulong deal_ticket, const ulong position_ref) {
   if (Long_DealWasProcessed(deal_ticket))
      return;
   if (!HistoryDealSelect(deal_ticket))
      return;

   string deal_sym = HistoryDealGetString(deal_ticket, DEAL_SYMBOL);
   if (deal_sym != _Symbol)
      return;

   long entry_type = HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
   long deal_magic = HistoryDealGetInteger(deal_ticket, DEAL_MAGIC);
   long deal_type  = HistoryDealGetInteger(deal_ticket, DEAL_TYPE);
      ulong order_ticket = (ulong)HistoryDealGetInteger(deal_ticket, DEAL_ORDER);
   ulong position_id = (ulong)HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID);
   if (position_id == 0)
      position_id = position_ref;
      double deal_price  = HistoryDealGetDouble(deal_ticket, DEAL_PRICE);

   Long_MarkDealProcessed(deal_ticket);

   const bool is_long_entry = V2_IsManagedLongEntryDeal(entry_type, deal_type, deal_magic,
                                                      (long)g_preset.magic_long);
   const bool is_long_exit  = V2_IsManagedExitDeal(entry_type, deal_magic,
                                                   (long)g_preset.magic_long_exit);

   if((is_long_entry || is_long_exit) && g_long_halted) {
      const string fill_kind = is_long_entry ? "entry" : "exit";
      string alert = V2_FormatHaltedFillAlert(g_preset.tel_instance_long, "LONG",
         deal_ticket, order_ticket, position_id, _Symbol, deal_magic, deal_price, fill_kind);
      V2_EmitHaltedFillAlert(g_long_system_alerts, alert);
      return;
   }

   if (is_long_entry) {
      bool is_reload = g_long_last_exit_valid;
      if (order_ticket == g_long_l0_ticket)
         g_long_l0_ticket = 0;
      if (order_ticket == g_long_add_ticket)
         g_long_add_ticket = 0;
      if (ArraySize(g_long_layers) == 0)
         g_long_last_exit_valid = false;
      Long_AppendLayer(deal_price, order_ticket, position_id, is_reload);
      if (InpVerboseLog)
         Print("DIAG V2_LONG | event=entry_filled | price=", DoubleToString(deal_price, 5),
               " reload=", is_reload, " layers=", ArraySize(g_long_layers));
      return;
   }

   if (is_long_exit) {
      int layer_idx = -1;
      bool matched_by_exit_ticket = false;
      for(int i = 0; i < ArraySize(g_long_layers); i++) {
         if(g_long_layers[i].exit_ticket == order_ticket) {
            layer_idx = i;
            matched_by_exit_ticket = true;
            break;
         }
      }
      if(layer_idx < 0) {
         for(int i = 0; i < ArraySize(g_long_layers); i++) {
            ulong pos_ticket = Long_ResolvePositionTicket(g_long_layers[i].position_ticket);
            if(pos_ticket == position_id ||
               g_long_layers[i].position_ticket == position_id) {
               layer_idx = i;
               break;
            }
         }
      }
      if(layer_idx < 0) {
         if(InpVerboseLog)
            Print("WARN V2_LONG | exit fill with no matching layer order=", order_ticket);
         return;
      }

      ulong orig_pos = Long_ResolvePositionTicket(g_long_layers[layer_idx].position_ticket);
      int stack_depth = ArraySize(g_long_layers);
      int layer_depth = layer_idx + 1;
      double layer_entry = g_long_layers[layer_idx].entry_price;
      datetime layer_entry_time = g_long_layers[layer_idx].entry_time;
      if(layer_entry_time <= 0 && orig_pos > 0 && PositionSelectByTicket(orig_pos))
         layer_entry_time = (datetime)PositionGetInteger(POSITION_TIME);
      int open_depth = g_long_layers[layer_idx].open_depth;

      double real_profit = V2_ComputeExitRealizedPnl(deal_ticket, orig_pos);

      if(matched_by_exit_ticket) {
         const double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
         if(g_long_layers[layer_idx].exit_is_market_hedge)
            V2_HarvestRecordMarket(+1,
               V2_HarvestPipsPure(+1, layer_entry, deal_price, pt));
         else
            V2_HarvestRecordLimit(+1,
               V2_HarvestPipsPure(+1, layer_entry, deal_price, pt));
      }

      if(orig_pos > 0 && position_id > 0) {
         V2_QueueCloseBy(g_long_closeby_queue, orig_pos, position_id);
         if(InpVerboseLog)
            Print("INFO V2_LONG | CloseBy queued position=", orig_pos,
                  " hedge=", position_id, " layer=", layer_idx);
      }

      datetime deal_time = (datetime)HistoryDealGetInteger(deal_ticket, DEAL_TIME);
      V2PodAccumulateExit(g_long_pod, real_profit);

      if(EnableTelemetry && TelemetryURL != "" && TelemetryAPIKey != "")
         V2EmitScalpClosed(EnableTelemetry, TelemetryURL, TelemetryAPIKey, InpVerboseLog,
                           g_preset.tel_instance_long, _Symbol, "LONG",
                           layer_entry, deal_price, real_profit,
                           layer_entry_time, deal_time,
                           layer_depth, stack_depth, open_depth);

      Long_RemoveLayerAt(layer_idx, true, deal_time);

      if(ArraySize(g_long_layers) == 0 && g_long_pod.layers_closed > 0) {
         double hold_mins = (double)(deal_time - g_long_pod.start_time) / 60.0;
         string payload = V2BuildPodClosePayload(
            g_preset.tel_instance_long,
            _Symbol,
            "LONG",
            g_long_pod.layers_closed,
            g_long_pod.layer0_entry,
            deal_price,
            hold_mins,
            g_long_pod.gross_pnl,
            TimeGMT(),
            deal_time
         );
         if(EnableTelemetry && TelemetryURL != "" && TelemetryAPIKey != "")
            V2TelemetryWebPost(V2DerivePodClosedUrl(TelemetryURL),
                               TelemetryAPIKey, payload, InpVerboseLog);
         V2PodReset(g_long_pod);
      }

      if (InpVerboseLog)
         Print("DIAG V2_LONG | event=exit_filled | deal=", deal_ticket,
               " layer=", layer_idx, " layers=", ArraySize(g_long_layers),
               " last_exit_valid=", g_long_last_exit_valid);
      return;
   }
}

void V2_Bcc_FillLongInputs(V2BccSideInputs &cfg)
{
   cfg.side_label = "LONG";
   cfg.symbol = _Symbol;
   cfg.direction = 1;
   cfg.entry_magic = g_preset.magic_long;
   cfg.exit_magic = g_preset.magic_long_exit;
   cfg.exit_pips = InpExitPips;
   cfg.point = _Point;
   cfg.expected_volume = InpLotSize;
   cfg.halted = g_long_halted;
   cfg.layer_count = ArraySize(g_long_layers);
   cfg.max_layers = InpMaxLayers;
   cfg.last_exit_valid = g_long_last_exit_valid;
   cfg.cap_blocks_add = V2_Cap_CheckBlocks(true);
   cfg.l0_ticket = g_long_l0_ticket;
   cfg.add_ticket = g_long_add_ticket;
   const int n = ArraySize(g_long_layers);
   ArrayResize(cfg.layers, n);
   for(int i = 0; i < n; i++) {
      cfg.layers[i].exit_ticket = g_long_layers[i].exit_ticket;
      cfg.layers[i].position_ticket = g_long_layers[i].position_ticket;
   }
}

void V2_Bcc_FillShortInputs(V2BccSideInputs &cfg)
{
   cfg.side_label = "SHORT";
   cfg.symbol = _Symbol;
   cfg.direction = -1;
   cfg.entry_magic = g_preset.magic_short;
   cfg.exit_magic = g_preset.magic_short_exit;
   cfg.exit_pips = InpExitPips;
   cfg.point = _Point;
   cfg.expected_volume = InpLotSize;
   cfg.halted = g_short_halted;
   cfg.layer_count = ArraySize(g_short_layers);
   cfg.max_layers = InpMaxLayers;
   cfg.last_exit_valid = g_short_last_exit_valid;
   cfg.cap_blocks_add = V2_Cap_CheckBlocks(false);
   cfg.l0_ticket = g_short_l0_ticket;
   cfg.add_ticket = g_short_add_ticket;
   const int n = ArraySize(g_short_layers);
   ArrayResize(cfg.layers, n);
   for(int i = 0; i < n; i++) {
      cfg.layers[i].exit_ticket = g_short_layers[i].exit_ticket;
      cfg.layers[i].position_ticket = g_short_layers[i].position_ticket;
   }
}

void V2_Bcc_MaybeRunTier3Sweep()
{
   if(!InpBccEnable)
      return;

   const datetime now = TimeCurrent();
   if(g_v2_bcc_last_tier3 != 0 && (now - g_v2_bcc_last_tier3) < InpBccSweepSec)
      return;
   g_v2_bcc_last_tier3 = now;

   int long_findings = 0;
   int short_findings = 0;
   int swept = 0;

   if(!g_long_halted) {
      V2BccSideInputs cfg;
      V2_Bcc_FillLongInputs(cfg);
      long_findings = V2_Bcc_RunSideTier3Sweep(cfg, g_long_bcc, g_long_closeby_queue, g_long_system_alerts);
      swept++;
   }
   if(!g_short_halted) {
      V2BccSideInputs cfg;
      V2_Bcc_FillShortInputs(cfg);
      short_findings = V2_Bcc_RunSideTier3Sweep(cfg, g_short_bcc, g_short_closeby_queue, g_short_system_alerts);
      swept++;
   }

   Print(StringFormat("BCC | sweep=OK | long_findings=%d | short_findings=%d | swept=%d",
                      long_findings, short_findings, swept));
}

int Long_OnInit() {
   g_long_last_exit_valid  = false;
   g_long_current_add_pips = InpAddPipsFloor;
   g_long_last_bar_time    = 0;
   g_long_processed_count  = 0;
   ArrayResize(g_long_processed_deals, 0);
   V2_Bcc_ResetSideRuntime(g_long_bcc);
   Print("INFO: ", g_preset.ea_name, "_long init magic=", g_preset.magic_long,
         " WIDEN=", InpWidenRatio, " reload_flat=1");
   return INIT_SUCCEEDED;
}

void Long_OnDeinit(const int reason) {
   Print("V2_STATS_LONG | l0=", g_long_stat_l0_entries,
         " l0_requote=", g_long_stat_l0_requote,
         " l0_deadband_skip=", g_long_stat_l0_deadband_skip,
         " add=", g_long_stat_add_entries,
         " reload=", g_long_stat_reload_entries,
         " exits=", g_long_stat_exits,
         " max_layers=", g_long_stat_max_layers,
         " open_layers=", ArraySize(g_long_layers),
         " exit_limit_placed=", g_long_stat_exit_limit_placed,
         " exit_place_fail=", g_long_stat_exit_place_fail);
}

void Long_OnTick() {
   if(g_long_halted)
      return;
   g_v2_inst_api_tag = g_preset.tel_instance_long;
   Long_OnNewBar();
   Long_AuditExitLimits();
   if(InpBccEnable) {
      V2BccSideInputs bcc_cfg;
      V2_Bcc_FillLongInputs(bcc_cfg);
      V2_Bcc_RunSideTier1(bcc_cfg, g_long_bcc);
      V2_Bcc_RunSideTier2IfPending(bcc_cfg, g_long_bcc, g_long_closeby_queue, g_long_system_alerts);
   }
   V2_ProcessCloseByQueue(g_long_closeby_queue, g_preset.tel_instance_long,
                          g_preset.magic_long, g_long_halted, InpVerboseLog);
}

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
void V2_BuildLongRolloverSlots(V2RolloverLayerSlot &slots[])
{
   const int n = ArraySize(g_long_layers);
   ArrayResize(slots, n);
   for(int i = 0; i < n; i++) {
      slots[i].position_ticket = g_long_layers[i].position_ticket;
      slots[i].entry_price     = g_long_layers[i].entry_price;
      slots[i].exit_target     = g_long_layers[i].exit_target;
      slots[i].exit_ticket     = g_long_layers[i].exit_ticket;
      slots[i].position_live   = (V2_ResolvePositionTicket(g_long_layers[i].position_ticket) != 0);
   }
}

void V2_ApplyLongRolloverSlots(const V2RolloverLayerSlot &slots[])
{
   const int n = MathMin(ArraySize(g_long_layers), ArraySize(slots));
   for(int i = 0; i < n; i++) {
      g_long_layers[i].exit_target = slots[i].exit_target;
      g_long_layers[i].exit_ticket = slots[i].exit_ticket;
   }
}

void V2_BuildShortRolloverSlots(V2RolloverLayerSlot &slots[])
{
   const int n = ArraySize(g_short_layers);
   ArrayResize(slots, n);
   for(int i = 0; i < n; i++) {
      slots[i].position_ticket = g_short_layers[i].position_ticket;
      slots[i].entry_price     = g_short_layers[i].entry_price;
      slots[i].exit_target     = g_short_layers[i].exit_target;
      slots[i].exit_ticket     = g_short_layers[i].exit_ticket;
      slots[i].position_live   = (V2_ResolvePositionTicket(g_short_layers[i].position_ticket) != 0);
   }
}

void V2_ApplyShortRolloverSlots(const V2RolloverLayerSlot &slots[])
{
   const int n = MathMin(ArraySize(g_short_layers), ArraySize(slots));
   for(int i = 0; i < n; i++) {
      g_short_layers[i].exit_target = slots[i].exit_target;
      g_short_layers[i].exit_ticket = slots[i].exit_ticket;
   }
}

void V2_RunRolloverRetryPasses()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   const int mult = V2_RolloverWednesdayMultiplier(dt.day_of_week);

   V2RolloverLayerSlot slots[];

   V2_BuildLongRolloverSlots(slots);
   V2_RunRolloverRetryPass(_Symbol, 1, mult, InpVerboseLog,
                           InpRolloverRetryMinutes, InpRolloverMaxRetries,
                           g_long_rollover_retry, slots, g_preset.tel_instance_long);
   V2_ApplyLongRolloverSlots(slots);

   V2_BuildShortRolloverSlots(slots);
   V2_RunRolloverRetryPass(_Symbol, -1, mult, InpVerboseLog,
                           InpRolloverRetryMinutes, InpRolloverMaxRetries,
                           g_short_rollover_retry, slots, g_preset.tel_instance_short);
   V2_ApplyShortRolloverSlots(slots);
}

//+------------------------------------------------------------------+
void V2_RunDailyRolloverReconciliation() {
   if(!V2_RolloverTryConsumeDailyGate(g_v2_last_rollover_day_of_year, TimeCurrent()))
      return;

   V2_RolloverRetryResetState(g_long_rollover_retry);
   V2_RolloverRetryResetState(g_short_rollover_retry);

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int mult = V2_RolloverWednesdayMultiplier(dt.day_of_week);

   if(InpVerboseLog)
      Print("INFO [V2-ADR-045] RunDailyRolloverReconciliation firing. multiplier=", mult,
            " symbol=", _Symbol);

   V2RolloverLayerSlot slots[];

   V2_BuildLongRolloverSlots(slots);
   V2_RunDailyRolloverSidePass(_Symbol, 1, mult, InpVerboseLog,
                               InpRolloverRetryMinutes, g_long_rollover_retry, slots,
                               g_preset.tel_instance_long);
   V2_ApplyLongRolloverSlots(slots);

   V2_BuildShortRolloverSlots(slots);
   V2_RunDailyRolloverSidePass(_Symbol, -1, mult, InpVerboseLog,
                               InpRolloverRetryMinutes, g_short_rollover_retry, slots,
                               g_preset.tel_instance_short);
   V2_ApplyShortRolloverSlots(slots);
}
struct ShortV2Layer {
   double entry_price;
   double exit_target;
   ulong  entry_ticket;
   ulong  position_ticket;
   ulong  exit_ticket;
   datetime last_exit_retry_time;
   datetime first_exit_retry_time;
   bool     exit_escalated;
   bool     exit_is_market_hedge;
   int      open_depth;
   datetime entry_time;
};

ShortV2Layer  g_short_layers[];
double   g_short_last_exit_price;
bool     g_short_last_exit_valid;
double   g_short_current_add_pips;
ulong    g_short_l0_ticket;
ulong    g_short_add_ticket;
datetime g_short_last_bar_time;
bool     g_short_halted = false;

V2CloseByTask g_short_closeby_queue[];
string        g_short_system_alerts[];
V2BccSideRuntime g_short_bcc;
datetime         g_v2_bcc_last_tier3 = 0;

int g_short_stat_l0_entries;
int g_short_stat_l0_requote;
int g_short_stat_l0_deadband_skip;
int g_short_stat_add_entries;
int g_short_stat_reload_entries;
int g_short_stat_exits;
int g_short_stat_max_layers;
int g_short_stat_exit_place_fail;
int g_short_stat_exit_limit_placed;

ulong g_short_processed_deals[];
int   g_short_processed_count;

//+------------------------------------------------------------------+
double Short_PipsToPrice(const double pips) {
   return pips * _Point * 10.0;
}

double Short_NormalizeSym(const double price) {
   return NormalizeDouble(price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
}

bool Short_Adr013ClampSell(const double theoretical, double &out_price) {
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double min_dist = MathMax(_Point, SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point);
   if (theoretical <= ask)
      out_price = Short_NormalizeSym(MathMax(theoretical, ask + min_dist));
   else
      out_price = Short_NormalizeSym(theoretical);
   return (MathAbs(out_price - theoretical) > _Point * 0.1);
}

bool Short_ComputeOfferSignal(double &offer_theoretical) {
   V2L0SignalContext ctx = V2_EngineBuildShortL0Context();
   V2L0CoreDiagnostics diag;
   if(!V2_L0ComputeOffer(g_preset, ctx, offer_theoretical, diag))
      return false;
   if(InpVerboseLog && g_preset.signal_slot == V2_SIGNAL_AB_TRIAD)
   {
      V2_L0PrintAbCoreDiag("SHORT", diag, offer_theoretical);
      if(ctx.quoting_side_flat && ctx.opposite_depth > InpEaseDepthStart)
         V2_L0PrintAbEaseDiag("SHORT", ctx.opposite_depth, diag);
   }
   else if(InpVerboseLog && ctx.quoting_side_flat && ctx.opposite_depth > InpEaseDepthStart)
      Print("DIAG V2_SHORT | event=l0_ease | opposite_depth=", ctx.opposite_depth,
            " effective_multiplier=", DoubleToString(diag.effective_multiplier, 6),
            " dynamic_hs=", DoubleToString(diag.dynamic_hs, 6));
   return true;
}

bool Short_IsOurOrderTicket(const ulong ticket, const ulong magic) {
   if (ticket == 0)
      return false;
   if (OrderSelect(ticket))
      return (OrderGetInteger(ORDER_MAGIC) == (long)magic);
   if (HistoryOrderSelect(ticket))
      return (HistoryOrderGetInteger(ticket, ORDER_MAGIC) == (long)magic);
   return false;
}

void Short_CancelTicket(const ulong ticket) {
   if (ticket == 0)
      return;
   if (!OrderSelect(ticket))
      return;
   MqlTradeRequest req = {};
   MqlTradeResult  res = {};
   req.action = TRADE_ACTION_REMOVE;
   req.order  = ticket;
   g_v2_inst_api_tag = g_preset.tel_instance_short;
   V2_OrderSendCounted(req, res);
}

ulong Short_PlaceSellLimit(const double price, const ulong magic, const string comment) {
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double min_dist = MathMax(_Point, SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point);
   if (price < ask + min_dist)
      return 0;

   MqlTradeRequest req = {};
   MqlTradeResult  res = {};
   req.action       = TRADE_ACTION_PENDING;
   req.symbol       = _Symbol;
   req.volume       = InpLotSize;
   req.type         = ORDER_TYPE_SELL_LIMIT;
   req.price        = Short_NormalizeSym(price);
   req.magic        = magic;
   req.type_filling = ORDER_FILLING_RETURN;
   req.type_time    = ORDER_TIME_GTC;
   req.comment      = comment;
   g_v2_inst_api_tag = g_preset.tel_instance_short;
   if (!V2_OrderSendCounted(req, res))
      return 0;
   return res.order;
}

ulong Short_PlaceBuyLimit(const double price, const ulong magic, const string comment) {
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double min_dist = MathMax(_Point, SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point);
   if (price > bid - min_dist)
      return 0;

   MqlTradeRequest req = {};
   MqlTradeResult  res = {};
   req.action       = TRADE_ACTION_PENDING;
   req.symbol       = _Symbol;
   req.volume       = InpLotSize;
   req.type         = ORDER_TYPE_BUY_LIMIT;
   req.price        = Short_NormalizeSym(price);
   req.magic        = magic;
   req.type_filling = ORDER_FILLING_RETURN;
   req.type_time    = ORDER_TIME_GTC;
   req.comment      = comment;
   g_v2_inst_api_tag = g_preset.tel_instance_short;
   if (!V2_OrderSendCounted(req, res))
      return 0;
   return res.order;
}

ulong Short_ResolvePositionTicket(const ulong position_ref) {
   if (position_ref == 0)
      return 0;
   if (PositionSelectByTicket(position_ref))
      return position_ref;
   for (int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if (!PositionSelectByTicket(ticket))
         continue;
      if ((ulong)PositionGetInteger(POSITION_IDENTIFIER) == position_ref)
         return ticket;
   }
   return 0;
}

bool Short_SetExitTakeProfit(const int layer_idx) {
   if (layer_idx < 0 || layer_idx >= ArraySize(g_short_layers))
      return false;

   ulong position_ticket = Short_ResolvePositionTicket(g_short_layers[layer_idx].position_ticket);
   if (position_ticket == 0)
      return false;

   double target = Short_NormalizeSym(g_short_layers[layer_idx].exit_target);
   ulong existing = g_short_layers[layer_idx].exit_ticket;
   if(existing != 0 && V2_ExitOrderLiveOrFilled(existing))
      return true;

   if(existing != 0) {
      V2_CancelExitOrder(existing, g_preset.tel_instance_short);
      g_short_layers[layer_idx].exit_ticket = 0;
      g_short_layers[layer_idx].exit_is_market_hedge = false;
   }

   // STEP 1: harvest-at-market (stored target; preempts any limit placement).
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(ask <= target) {
      ulong hedge_order = 0;
      double filled_vol = 0.0;
      const V2ExitHedgeOpenOutcome hedge_result =
         V2_OpenExitHedgeAtMarket(_Symbol, -1, InpLotSize, g_preset.magic_short_exit,
                                  g_preset.tel_instance_short, hedge_order, filled_vol);
      if(hedge_result == V2_EXIT_HEDGE_OPEN_FULL) {
         g_short_layers[layer_idx].exit_ticket = hedge_order;
         g_short_layers[layer_idx].exit_is_market_hedge = true;
         if(InpVerboseLog)
            Print("DIAG V2_SHORT | event=exit_market_close | layer=", layer_idx,
                  " target=", DoubleToString(target, 5),
                  " ask=", DoubleToString(ask, 5));
         return true;
      }
      if(hedge_result == V2_EXIT_HEDGE_OPEN_PARTIAL) {
         g_short_halted = true;
         V2_PushSystemAlert(g_short_system_alerts,
            StringFormat("V2_EXIT_HEDGE_PARTIAL | side=SHORT | layer=%d | filled=%.4f | requested=%.4f",
                         layer_idx, filled_vol, InpLotSize));
         return true;
      }
   }

   // STEP 2: Option-1 stretch (local `place` only; stored exit_target unchanged).
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double buffer = V2_ExitClearanceBuffer(_Symbol);
   double place = Short_NormalizeSym(MathMin(target, bid - buffer));

   // STEP 3: rest passive limit at `place`.
   ulong exit_order = V2_SendExitLimit(_Symbol, place, InpLotSize, -1,
                                       g_preset.magic_short_exit, place,
                                       g_preset.tel_instance_short);
   if(exit_order == 0) {
      if (InpVerboseLog)
         Print("WARN V2_SHORT | exit limit placement failed layer=", layer_idx,
               " target=", DoubleToString(target, 5),
               " place=", DoubleToString(place, 5));
      return false;
   }

   g_short_layers[layer_idx].exit_ticket = exit_order;
   g_short_layers[layer_idx].last_exit_retry_time  = 0;
   g_short_layers[layer_idx].first_exit_retry_time = 0;
   g_short_layers[layer_idx].exit_escalated        = false;
   return true;
}

void Short_ClearExitTakeProfit(const ulong position_ref) {
   int n = ArraySize(g_short_layers);
   for(int i = 0; i < n; i++) {
      if(g_short_layers[i].position_ticket != position_ref)
         continue;
      V2_CancelExitOrder(g_short_layers[i].exit_ticket, g_preset.tel_instance_short);
      g_short_layers[i].exit_ticket = 0;
      g_short_layers[i].exit_is_market_hedge = false;
      return;
   }
}

double Short_ComputeAddTarget() {
   int n = ArraySize(g_short_layers);
   if (n <= 0)
      return 0.0;

   double step_pips;
   double anchor;
   if (g_short_last_exit_valid) {
      anchor = g_short_last_exit_price;
      step_pips = V2_ADD_PIPS_FLOOR;
   } else {
      anchor = g_short_layers[n - 1].entry_price;
      bool still_shallow = (n < 3);
      step_pips = still_shallow ? InpAddPipsFloor : g_short_current_add_pips;
   }
   return Short_NormalizeSym(anchor + Short_PipsToPrice(step_pips));
}

bool Short_ReplacePendingSell(ulong &ticket_ref, const double price, const ulong magic, const string comment) {
   if(InpEntryMode == ENTRY_SIGNAL &&
      V2_L0RestingWithinDeadband(ticket_ref, price, InpQuoteSpread, InpL0DeadbandMult, V2_EngineDeadbandSpreadRef())) {
      g_short_stat_l0_deadband_skip++;
      return false;
   }
   Short_CancelTicket(ticket_ref);
   ticket_ref = Short_PlaceSellLimit(price, magic, comment);
   if(ticket_ref > 0) {
      g_short_stat_l0_requote++;
      return true;
   }
   return false;
}

void Short_PlaceExitForLayer(const int layer_idx, const bool immediate) {
   if (layer_idx < 0 || layer_idx >= ArraySize(g_short_layers))
      return;

   double target = g_short_layers[layer_idx].exit_target;
   if (Short_SetExitTakeProfit(layer_idx)) {
      g_short_stat_exit_limit_placed++;
      if (InpVerboseLog && immediate)
         Print("DIAG V2_SHORT | event=exit_placed | layer=", layer_idx,
               " target=", DoubleToString(target, 5),
               " ticket=", g_short_layers[layer_idx].exit_ticket);
      return;
   }

   g_short_stat_exit_place_fail++;
   if (InpVerboseLog) {
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      Print("WARN V2_SHORT | exit placement failed layer=", layer_idx,
            " target=", DoubleToString(target, 5),
            " bid=", DoubleToString(bid, 5),
            " immediate=", (immediate ? "1" : "0"));
   }
}

void Short_AuditExitLimits() {
   if(g_short_halted)
      return;

   datetime now = TimeCurrent();
   int n = ArraySize(g_short_layers);
   for(int i = 0; i < n; i++) {
      ulong position_ticket = Short_ResolvePositionTicket(g_short_layers[i].position_ticket);
      bool position_live = (position_ticket != 0 &&
                            PositionSelectByTicket(position_ticket));
      bool exit_live = V2_ExitOrderLiveOrFilled(g_short_layers[i].exit_ticket);

      if(g_short_layers[i].exit_ticket != 0 && !exit_live) {
         if(InpVerboseLog)
            Print("WARNING V2_SHORT | stale exit ticket cleared layer=", i,
                  " ticket=", g_short_layers[i].exit_ticket);
         g_short_layers[i].exit_ticket = 0;
         g_short_layers[i].exit_is_market_hedge = false;
         exit_live = false;
      }

      V2ExitAuditAction action = V2_EvaluateExitAudit(
         position_live,
         exit_live,
         g_short_layers[i].last_exit_retry_time,
         g_short_layers[i].first_exit_retry_time,
         g_short_layers[i].exit_escalated,
         now);

      if(action == V2_EXIT_AUDIT_OK || action == V2_EXIT_AUDIT_THROTTLED)
         continue;

      if(action == V2_EXIT_AUDIT_ESCALATE) {
         V2_EscalateExitAlert(g_short_system_alerts, g_preset.tel_instance_short, i,
                              g_short_layers[i].exit_target,
                              g_short_layers[i].exit_escalated);
      }

      if(g_short_layers[i].first_exit_retry_time == 0)
         g_short_layers[i].first_exit_retry_time = now;
      g_short_layers[i].last_exit_retry_time = now;

      if(Short_SetExitTakeProfit(i)) {
         g_short_stat_exit_limit_placed++;
         if(InpVerboseLog)
            Print("INFO V2_SHORT | AuditExitLimits recovered layer=", i,
                  " ticket=", g_short_layers[i].exit_ticket);
      } else {
         g_short_stat_exit_place_fail++;
      }
   }
}

void Short_EnsureAddNext() {
   int n = ArraySize(g_short_layers);
   if (n <= 0 || n >= InpMaxLayers)
      return;
   if (g_short_add_ticket != 0 && OrderSelect(g_short_add_ticket))
      return;

   double add_price = Short_ComputeAddTarget();
   if (add_price <= 0.0)
      return;
   if(!g_short_last_exit_valid &&
      V2_Cap_CheckBlocks(false)) {
      V2_Cap_RecordBlock(false);
      return;
   }
   g_short_add_ticket = Short_PlaceSellLimit(add_price, g_preset.magic_short, g_short_last_exit_valid ? "V2_Reload" : "V2_Add");
}

void Short_OnNewBar() {
   datetime bar_time = iTime(_Symbol, PERIOD_M5, 0);
   if (bar_time == g_short_last_bar_time)
      return;
   g_short_last_bar_time = bar_time;

   int n = ArraySize(g_short_layers);
   if (n == 0 && InpEntryMode == ENTRY_SIGNAL) {
      double offer_theoretical;
      if (!Short_ComputeOfferSignal(offer_theoretical))
         return;

      double offer_lvl;
      Short_Adr013ClampSell(offer_theoretical, offer_lvl);

      g_short_last_exit_valid = false;
      if(InpVerboseLog && ArraySize(g_long_layers) > InpEaseDepthStart) {
         const double resting_price = V2_GetPendingOrderPrice(g_short_l0_ticket);
         const bool deadband_skip = V2_L0RestingWithinDeadband(g_short_l0_ticket, offer_lvl, InpQuoteSpread, InpL0DeadbandMult, V2_EngineDeadbandSpreadRef());
         const double gap_pips = (resting_price > 0.0)
            ? MathAbs(offer_theoretical - resting_price) / (_Point * 10.0)
            : 0.0;
         Print("DIAG V2_SHORT | event=l0_lag | resting_price=", DoubleToString(resting_price, 5),
               " theo_price=", DoubleToString(offer_theoretical, 5),
               " gap_pips=", DoubleToString(gap_pips, 2),
               " deadband_skip=", (deadband_skip ? "true" : "false"));
      }
      if(Short_ReplacePendingSell(g_short_l0_ticket, offer_lvl, g_preset.magic_short, "V2_L0") && InpVerboseLog)
         Print("DIAG V2_SHORT | event=l0_quote | offer_theo=", DoubleToString(offer_theoretical, 5),
               " offer_lvl=", DoubleToString(offer_lvl, 5));
   }

   Short_EnsureAddNext();
}

void Short_AppendLayer(const double entry_price, const ulong entry_ticket,
                 const ulong position_ticket, const bool is_reload) {
   int n = ArraySize(g_short_layers);
   ArrayResize(g_short_layers, n + 1);
   g_short_layers[n].entry_price      = Short_NormalizeSym(entry_price);
   g_short_layers[n].entry_ticket     = entry_ticket;
   g_short_layers[n].position_ticket  = position_ticket;
   g_short_layers[n].exit_ticket      = 0;
   g_short_layers[n].exit_target      = Short_NormalizeSym(entry_price - Short_PipsToPrice(InpExitPips));
   g_short_layers[n].last_exit_retry_time  = 0;
   g_short_layers[n].first_exit_retry_time = 0;
   g_short_layers[n].exit_escalated        = false;
   g_short_layers[n].exit_is_market_hedge   = false;
   g_short_layers[n].open_depth            = n;
   g_short_layers[n].entry_time            = TimeCurrent();

   if (n == 0)
      g_short_stat_l0_entries++;
   else if (is_reload)
      g_short_stat_reload_entries++;
   else
      g_short_stat_add_entries++;

   if(n == 0) {
      datetime entry_time = TimeCurrent();
      V2PodOnFirstLayer(g_short_pod, Short_NormalizeSym(entry_price), entry_time);
   }

   if (ArraySize(g_short_layers) > g_short_stat_max_layers)
      g_short_stat_max_layers = ArraySize(g_short_layers);

   if (ArraySize(g_short_layers) >= 3)
      g_short_current_add_pips = MathMin(InpAddPipsCeiling, g_short_current_add_pips * InpWidenRatio);

   if (is_reload)
      g_short_last_exit_valid = false;

   Short_CancelTicket(g_short_add_ticket);
   g_short_add_ticket = 0;

   V2_Cap_Sync(false, ArraySize(g_short_layers));
   Short_PlaceExitForLayer(n, true);
   Short_EnsureAddNext();
}

void Short_RemoveLayerAt(const int layer_idx,
                         const bool from_clean_harvest = false,
                         const datetime fill_time = 0) {
   int n = ArraySize(g_short_layers);
   if(layer_idx < 0 || layer_idx >= n)
      return;

   bool was_top = (layer_idx == n - 1);
   if(was_top && from_clean_harvest) {
      if(V2_EngineRebaseOriginSuppressed(fill_time)) {
         g_short_last_exit_valid = false;
      } else {
         const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
         g_short_last_exit_price = V2_SRE_ExpectedExitPrice(
            g_short_layers[layer_idx].entry_price, -1, InpExitPips, point);
         g_short_last_exit_valid = true;
      }
   }

   V2_CancelExitOrder(g_short_layers[layer_idx].exit_ticket, g_preset.tel_instance_short);
   if(was_top) {
      Short_CancelTicket(g_short_add_ticket);
      g_short_add_ticket = 0;
   }

   for(int i = layer_idx; i < n - 1; i++)
      g_short_layers[i] = g_short_layers[i + 1];
   ArrayResize(g_short_layers, n - 1);
   g_short_stat_exits++;

   V2_OnOwnStackFlat(g_short_last_exit_valid, ArraySize(g_short_layers));
   V2_Cap_Sync(false, ArraySize(g_short_layers));
   if(ArraySize(g_short_layers) == 0)
      g_short_current_add_pips = InpAddPipsFloor;
   else if(was_top)
      Short_EnsureAddNext();
}

void Short_PopTopLayer() {
   Short_RemoveLayerAt(ArraySize(g_short_layers) - 1, false);
}

bool Short_DealWasProcessed(const ulong deal_ticket) {
   for (int i = 0; i < g_short_processed_count; i++)
      if (g_short_processed_deals[i] == deal_ticket)
         return true;
   return false;
}

void Short_MarkDealProcessed(const ulong deal_ticket) {
   if (Short_DealWasProcessed(deal_ticket))
      return;
   ArrayResize(g_short_processed_deals, g_short_processed_count + 1);
   g_short_processed_deals[g_short_processed_count++] = deal_ticket;
}

void Short_HandleDealFill(const ulong deal_ticket, const ulong position_ref) {
   if (Short_DealWasProcessed(deal_ticket))
      return;
   if (!HistoryDealSelect(deal_ticket))
      return;

   string deal_sym = HistoryDealGetString(deal_ticket, DEAL_SYMBOL);
   if (deal_sym != _Symbol)
      return;

   long entry_type = HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
   long deal_magic = HistoryDealGetInteger(deal_ticket, DEAL_MAGIC);
   long deal_type  = HistoryDealGetInteger(deal_ticket, DEAL_TYPE);
   ulong order_ticket = (ulong)HistoryDealGetInteger(deal_ticket, DEAL_ORDER);
   ulong position_id = (ulong)HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID);
   if (position_id == 0)
      position_id = position_ref;
   double deal_price  = HistoryDealGetDouble(deal_ticket, DEAL_PRICE);

   Short_MarkDealProcessed(deal_ticket);

   const bool is_short_entry = V2_IsManagedShortEntryDeal(entry_type, deal_type, deal_magic,
                                                         (long)g_preset.magic_short);
   const bool is_short_exit  = V2_IsManagedExitDeal(entry_type, deal_magic,
                                                    (long)g_preset.magic_short_exit);

   if((is_short_entry || is_short_exit) && g_short_halted) {
      const string fill_kind = is_short_entry ? "entry" : "exit";
      string alert = V2_FormatHaltedFillAlert(g_preset.tel_instance_short, "SHORT",
         deal_ticket, order_ticket, position_id, _Symbol, deal_magic, deal_price, fill_kind);
      V2_EmitHaltedFillAlert(g_short_system_alerts, alert);
      return;
   }

   if (is_short_entry) {
      bool is_reload = g_short_last_exit_valid;
      if (order_ticket == g_short_l0_ticket)
         g_short_l0_ticket = 0;
      if (order_ticket == g_short_add_ticket)
         g_short_add_ticket = 0;
      if (ArraySize(g_short_layers) == 0)
         g_short_last_exit_valid = false;
      Short_AppendLayer(deal_price, order_ticket, position_id, is_reload);
      if (InpVerboseLog)
         Print("DIAG V2_SHORT | event=entry_filled | price=", DoubleToString(deal_price, 5),
               " reload=", is_reload, " layers=", ArraySize(g_short_layers));
      return;
   }

   if (is_short_exit) {
      int layer_idx = -1;
      bool matched_by_exit_ticket = false;
      for(int i = 0; i < ArraySize(g_short_layers); i++) {
         if(g_short_layers[i].exit_ticket == order_ticket) {
            layer_idx = i;
            matched_by_exit_ticket = true;
            break;
         }
      }
      if(layer_idx < 0) {
         for(int i = 0; i < ArraySize(g_short_layers); i++) {
            ulong pos_ticket = Short_ResolvePositionTicket(g_short_layers[i].position_ticket);
            if(pos_ticket == position_id ||
               g_short_layers[i].position_ticket == position_id) {
               layer_idx = i;
               break;
            }
         }
      }
      if(layer_idx < 0) {
         if(InpVerboseLog)
            Print("WARN V2_SHORT | exit fill with no matching layer order=", order_ticket);
         return;
      }

      ulong orig_pos = Short_ResolvePositionTicket(g_short_layers[layer_idx].position_ticket);
      int stack_depth = ArraySize(g_short_layers);
      int layer_depth = layer_idx + 1;
      double layer_entry = g_short_layers[layer_idx].entry_price;
      datetime layer_entry_time = g_short_layers[layer_idx].entry_time;
      if(layer_entry_time <= 0 && orig_pos > 0 && PositionSelectByTicket(orig_pos))
         layer_entry_time = (datetime)PositionGetInteger(POSITION_TIME);
      int open_depth = g_short_layers[layer_idx].open_depth;

      double real_profit = V2_ComputeExitRealizedPnl(deal_ticket, orig_pos);

      if(matched_by_exit_ticket) {
         const double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
         if(g_short_layers[layer_idx].exit_is_market_hedge)
            V2_HarvestRecordMarket(-1,
               V2_HarvestPipsPure(-1, layer_entry, deal_price, pt));
         else
            V2_HarvestRecordLimit(-1,
               V2_HarvestPipsPure(-1, layer_entry, deal_price, pt));
      }

      if(orig_pos > 0 && position_id > 0) {
         V2_QueueCloseBy(g_short_closeby_queue, orig_pos, position_id);
         if(InpVerboseLog)
            Print("INFO V2_SHORT | CloseBy queued position=", orig_pos,
                  " hedge=", position_id, " layer=", layer_idx);
      }

      datetime deal_time = (datetime)HistoryDealGetInteger(deal_ticket, DEAL_TIME);
      V2PodAccumulateExit(g_short_pod, real_profit);

      if(EnableTelemetry && TelemetryURL != "" && TelemetryAPIKey != "")
         V2EmitScalpClosed(EnableTelemetry, TelemetryURL, TelemetryAPIKey, InpVerboseLog,
                           g_preset.tel_instance_short, _Symbol, "SHORT",
                           layer_entry, deal_price, real_profit,
                           layer_entry_time, deal_time,
                           layer_depth, stack_depth, open_depth);

      Short_RemoveLayerAt(layer_idx, true, deal_time);

      if(ArraySize(g_short_layers) == 0 && g_short_pod.layers_closed > 0) {
         double hold_mins = (double)(deal_time - g_short_pod.start_time) / 60.0;
         string payload = V2BuildPodClosePayload(
            g_preset.tel_instance_short,
            _Symbol,
            "SHORT",
            g_short_pod.layers_closed,
            g_short_pod.layer0_entry,
            deal_price,
            hold_mins,
            g_short_pod.gross_pnl,
            TimeGMT(),
            deal_time
         );
         if(EnableTelemetry && TelemetryURL != "" && TelemetryAPIKey != "")
            V2TelemetryWebPost(V2DerivePodClosedUrl(TelemetryURL),
                               TelemetryAPIKey, payload, InpVerboseLog);
         V2PodReset(g_short_pod);
      }

      if (InpVerboseLog)
         Print("DIAG V2_SHORT | event=exit_filled | deal=", deal_ticket,
               " layer=", layer_idx, " layers=", ArraySize(g_short_layers),
               " last_exit_valid=", g_short_last_exit_valid);
      return;
   }
}

int Short_OnInit() {
   g_short_last_exit_valid  = false;
   g_short_current_add_pips = InpAddPipsFloor;
   g_short_last_bar_time    = 0;
   g_short_processed_count  = 0;
   ArrayResize(g_short_processed_deals, 0);
   V2_Bcc_ResetSideRuntime(g_short_bcc);
   Print("INFO: ", g_preset.ea_name, "_short init magic=", g_preset.magic_short,
         " WIDEN=", InpWidenRatio, " reload_flat=1");
   return INIT_SUCCEEDED;
}

void Short_OnDeinit(const int reason) {
   Print("V2_STATS_SHORT | l0=", g_short_stat_l0_entries,
         " l0_requote=", g_short_stat_l0_requote,
         " l0_deadband_skip=", g_short_stat_l0_deadband_skip,
         " add=", g_short_stat_add_entries,
         " reload=", g_short_stat_reload_entries,
         " exits=", g_short_stat_exits,
         " max_layers=", g_short_stat_max_layers,
         " open_layers=", ArraySize(g_short_layers),
         " exit_limit_placed=", g_short_stat_exit_limit_placed,
         " exit_place_fail=", g_short_stat_exit_place_fail);
}

void Short_OnTick() {
   if(g_short_halted)
      return;
   g_v2_inst_api_tag = g_preset.tel_instance_short;
   Short_OnNewBar();
   Short_AuditExitLimits();
   if(InpBccEnable) {
      V2BccSideInputs bcc_cfg;
      V2_Bcc_FillShortInputs(bcc_cfg);
      V2_Bcc_RunSideTier1(bcc_cfg, g_short_bcc);
      V2_Bcc_RunSideTier2IfPending(bcc_cfg, g_short_bcc, g_short_closeby_queue, g_short_system_alerts);
   }
   V2_ProcessCloseByQueue(g_short_closeby_queue, g_preset.tel_instance_short,
                          g_preset.magic_short, g_short_halted, InpVerboseLog);
}

//+------------------------------------------------------------------+
void V2FillLongTelLayers(V2TelLayerSnapshot &out_layers[])
{
   int n = ArraySize(g_long_layers);
   ArrayResize(out_layers, n);
   for(int i = 0; i < n; i++) {
      out_layers[i].entry_price      = g_long_layers[i].entry_price;
      out_layers[i].exit_target      = g_long_layers[i].exit_target;
      out_layers[i].lot_size         = InpLotSize;
      out_layers[i].direction        = 1;
      out_layers[i].position_ticket  = g_long_layers[i].position_ticket;
      out_layers[i].exit_ticket      = g_long_layers[i].exit_ticket;
   }
}

void V2FillShortTelLayers(V2TelLayerSnapshot &out_layers[])
{
   int n = ArraySize(g_short_layers);
   ArrayResize(out_layers, n);
   for(int i = 0; i < n; i++) {
      out_layers[i].entry_price      = g_short_layers[i].entry_price;
      out_layers[i].exit_target      = g_short_layers[i].exit_target;
      out_layers[i].lot_size         = InpLotSize;
      out_layers[i].direction        = -1;
      out_layers[i].position_ticket  = g_short_layers[i].position_ticket;
      out_layers[i].exit_ticket      = g_short_layers[i].exit_ticket;
   }
}

void V2EmitTelemetry(const bool force = false)
{
   if(!EnableTelemetry)
      return;
   if(TelemetryURL == "" || TelemetryAPIKey == "")
      return;

   datetime now = TimeCurrent();
   if(!force && (now - g_last_telemetry_emit) < TelemetryIntervalSec)
      return;

   g_last_telemetry_emit = now;

   V2TelLayerSnapshot long_layers[];
   V2TelLayerSnapshot short_layers[];
   V2FillLongTelLayers(long_layers);
   V2FillShortTelLayers(short_layers);

   datetime ts_utc = TimeGMT();
   string long_live_alerts[];
   string short_live_alerts[];
   V2_Bcc_BuildLiveAlerts("LONG", g_long_bcc, g_long_halted, long_live_alerts);
   V2_Bcc_BuildLiveAlerts("SHORT", g_short_bcc, g_short_halted, short_live_alerts);

   string payload_long = V2BuildInstanceTelemetryPayload(
      g_preset.tel_instance_long,
      _Symbol,
      long_layers,
      ArraySize(long_layers),
      1,
      InpQuoteSpread,
      ts_utc,
      long_live_alerts,
      g_v2_harvest_type_limit_long,
      g_v2_harvest_type_market_long,
      g_v2_harvest_pips_limit_long,
      g_v2_harvest_pips_market_long
   );
   string payload_short = V2BuildInstanceTelemetryPayload(
      g_preset.tel_instance_short,
      _Symbol,
      short_layers,
      ArraySize(short_layers),
      -1,
      InpQuoteSpread,
      ts_utc,
      short_live_alerts,
      g_v2_harvest_type_limit_short,
      g_v2_harvest_type_market_short,
      g_v2_harvest_pips_limit_short,
      g_v2_harvest_pips_market_short
   );

   V2TelemetryWebPost(TelemetryURL, TelemetryAPIKey, payload_long, InpVerboseLog);
   V2TelemetryWebPost(TelemetryURL, TelemetryAPIKey, payload_short, InpVerboseLog);
}

V2SRECapBridgeKind V2_SRE_CapBridgeFromProfile(const V2CapProfile p)
{
   if(p == V2_CAP_EUR_ONLY)     return V2_SRE_CAP_BRIDGE_EURUSD;
   if(p == V2_CAP_DUAL_GBP_EUR) return V2_SRE_CAP_BRIDGE_EURGBP_DUAL;
   return V2_SRE_CAP_BRIDGE_GBPUSD;   // V2_CAP_GBP_ONLY
}

void V2_ApplyLongSRECommit(const V2SREOnInitSideResult &res)
{
   const int n = ArraySize(res.layers);
   ArrayResize(g_long_layers, n);
   for(int i = 0; i < n; i++) {
      g_long_layers[i].entry_price = res.layers[i].entry_price;
      g_long_layers[i].exit_target = res.layers[i].exit_target;
      g_long_layers[i].entry_ticket = res.layers[i].entry_ticket;
      g_long_layers[i].position_ticket = res.layers[i].position_ticket;
      g_long_layers[i].exit_ticket = res.layers[i].exit_ticket;
      g_long_layers[i].entry_time = res.layers[i].entry_time;
      g_long_layers[i].open_depth = i;
      g_long_layers[i].last_exit_retry_time = 0;
      g_long_layers[i].first_exit_retry_time = 0;
      g_long_layers[i].exit_escalated = false;
   }
   g_long_last_exit_valid = res.path_state.last_exit_valid;
   g_long_last_exit_price = res.path_state.last_exit_price;
   g_long_current_add_pips = res.path_state.current_add_pips;
}

void V2_ApplyShortSRECommit(const V2SREOnInitSideResult &res)
{
   const int n = ArraySize(res.layers);
   ArrayResize(g_short_layers, n);
   for(int i = 0; i < n; i++) {
      g_short_layers[i].entry_price = res.layers[i].entry_price;
      g_short_layers[i].exit_target = res.layers[i].exit_target;
      g_short_layers[i].entry_ticket = res.layers[i].entry_ticket;
      g_short_layers[i].position_ticket = res.layers[i].position_ticket;
      g_short_layers[i].exit_ticket = res.layers[i].exit_ticket;
      g_short_layers[i].entry_time = res.layers[i].entry_time;
      g_short_layers[i].open_depth = i;
      g_short_layers[i].last_exit_retry_time = 0;
      g_short_layers[i].first_exit_retry_time = 0;
      g_short_layers[i].exit_escalated = false;
   }
   g_short_last_exit_valid = res.path_state.last_exit_valid;
   g_short_last_exit_price = res.path_state.last_exit_price;
   g_short_current_add_pips = res.path_state.current_add_pips;
}

void Long_VetoPhantomLayers()
{
   const int before = ArraySize(g_long_layers);
   for(int i = ArraySize(g_long_layers) - 1; i >= 0; i--) {
      const ulong pt = Long_ResolvePositionTicket(g_long_layers[i].position_ticket);
      if(pt != 0 && V2_SRE_PhantomVetoPositionLive(pt))
         continue;
      Print("ALERT V2_SRE_PHANTOM_VETO | side=long | ticket=", g_long_layers[i].position_ticket,
            " reconstructed-open but broker-flat -> layer cleared");
      V2_CancelExitOrder(g_long_layers[i].exit_ticket, g_preset.tel_instance_long);
      const int n = ArraySize(g_long_layers);
      for(int j = i; j < n - 1; j++)
         g_long_layers[j] = g_long_layers[j + 1];
      ArrayResize(g_long_layers, n - 1);
   }
   if(ArraySize(g_long_layers) != before) {
      V2_OnOwnStackFlat(g_long_last_exit_valid, ArraySize(g_long_layers));
      V2_Cap_Sync(true, ArraySize(g_long_layers));
      if(ArraySize(g_long_layers) == 0)
         g_long_current_add_pips = InpAddPipsFloor;
   }
}

void Short_VetoPhantomLayers()
{
   const int before = ArraySize(g_short_layers);
   for(int i = ArraySize(g_short_layers) - 1; i >= 0; i--) {
      const ulong pt = Short_ResolvePositionTicket(g_short_layers[i].position_ticket);
      if(pt != 0 && V2_SRE_PhantomVetoPositionLive(pt))
         continue;
      Print("ALERT V2_SRE_PHANTOM_VETO | side=short | ticket=", g_short_layers[i].position_ticket,
            " reconstructed-open but broker-flat -> layer cleared");
      V2_CancelExitOrder(g_short_layers[i].exit_ticket, g_preset.tel_instance_short);
      const int n = ArraySize(g_short_layers);
      for(int j = i; j < n - 1; j++)
         g_short_layers[j] = g_short_layers[j + 1];
      ArrayResize(g_short_layers, n - 1);
   }
   if(ArraySize(g_short_layers) != before) {
      V2_OnOwnStackFlat(g_short_last_exit_valid, ArraySize(g_short_layers));
      V2_Cap_Sync(false, ArraySize(g_short_layers));
      if(ArraySize(g_short_layers) == 0)
         g_short_current_add_pips = InpAddPipsFloor;
   }
}

int OnInit() {
   V2_EngineApplyEntryModeIdentity();
   if(InpEntryMode == ENTRY_STRADDLE) {
      const long probe[] = {g_preset.magic_long, g_preset.magic_short,
                            g_preset.magic_long_exit, g_preset.magic_short_exit};
      for(int i = 0; i < ArraySize(probe); i++) {
         if(V2_IsLiveV2EntryMagic(probe[i])) {
            Print("ERROR: ", g_preset.ea_name,
                  " STRADDLE identity collision with live magic ", probe[i], ". Halting.");
            return INIT_FAILED;
         }
      }
   }
   if(InpEaseDepthFull <= InpEaseDepthStart || InpEaseDepthStart < 0 || InpEaseDepthFull < 0) {
      Print("ERROR: ", g_preset.ea_name, " invalid ease depth inputs — InpEaseDepthStart=",
            InpEaseDepthStart, " InpEaseDepthFull=", InpEaseDepthFull,
            ". Require 0 <= start < full. Halting.");
      return INIT_FAILED;
   }

   V2_ApiCounterMaybeReset();
   V2PodReset(g_long_pod);
   V2PodReset(g_short_pod);
   g_last_telemetry_emit = 0;
   const string init_ab_tag = (g_preset.signal_slot == V2_SIGNAL_AB_TRIAD) ? " AB-signal" : "";
   Print("INFO: ", g_preset.ea_name, " init", init_ab_tag, " magic_long=", g_preset.magic_long,
         " magic_short=", g_preset.magic_short,
         " exit_limits=1 closeby=1 audit_tick=1 reload_flat=1 orphan_guard=1 telemetry=",
         (EnableTelemetry ? "1" : "0"));
   Long_OnInit();
   Short_OnInit();

   bool long_orphan  = false;
   bool short_orphan = false;

   V2SREOnInitSideResult long_sre;
   V2SREOnInitSideConfig long_cfg;
   long_cfg.instance_tag = g_preset.tel_instance_long;
   long_cfg.symbol = _Symbol;
   long_cfg.side_direction = 1;
   long_cfg.entry_magic = g_preset.magic_long;
   long_cfg.exit_magic = g_preset.magic_long_exit;
   long_cfg.expected_volume = InpLotSize;
   long_cfg.exit_pips = InpExitPips;
   long_cfg.point = _Point;
   long_cfg.add_pips_floor = InpAddPipsFloor;
   long_cfg.widen_ratio = InpWidenRatio;
   long_cfg.add_pips_ceiling = InpAddPipsCeiling;
   long_cfg.layer_count = ArraySize(g_long_layers);
   long_cfg.now = TimeCurrent();
   long_cfg.lookback_sec = V2_SRE_DEFAULT_LOOKBACK_SEC;
   long_cfg.is_long = true;
   long_cfg.cap_bridge = V2_SRE_CapBridgeFromProfile(g_preset.cap_profile);
   long_cfg.cap_namespace = g_preset.cap_namespace;

   V2SREOnInitSideResult short_sre;
   V2SREOnInitSideConfig short_cfg;
   short_cfg.instance_tag = g_preset.tel_instance_short;
   short_cfg.symbol = _Symbol;
   short_cfg.side_direction = -1;
   short_cfg.entry_magic = g_preset.magic_short;
   short_cfg.exit_magic = g_preset.magic_short_exit;
   short_cfg.expected_volume = InpLotSize;
   short_cfg.exit_pips = InpExitPips;
   short_cfg.point = _Point;
   short_cfg.add_pips_floor = InpAddPipsFloor;
   short_cfg.widen_ratio = InpWidenRatio;
   short_cfg.add_pips_ceiling = InpAddPipsCeiling;
   short_cfg.layer_count = ArraySize(g_short_layers);
   short_cfg.now = TimeCurrent();
   short_cfg.lookback_sec = V2_SRE_DEFAULT_LOOKBACK_SEC;
   short_cfg.is_long = false;
   short_cfg.cap_bridge = V2_SRE_CapBridgeFromProfile(g_preset.cap_profile);
   short_cfg.cap_namespace = g_preset.cap_namespace;

   V2SREOnInitAggregateOutcome agg = V2_SRE_RunOnInitSidePair(
      g_long_system_alerts, g_short_system_alerts, long_cfg, short_cfg, long_sre, short_sre);
   long_orphan  = agg.long_halted;
   short_orphan = agg.short_halted;
   if(long_orphan)
      g_long_halted = true;
   else if(agg.long_committed) {
      V2_ApplyLongSRECommit(long_sre);
      Long_VetoPhantomLayers();
   }
   if(short_orphan)
      g_short_halted = true;
   else if(agg.short_committed) {
      V2_ApplyShortSRECommit(short_sre);
      Short_VetoPhantomLayers();
   }

   if(V2_CbReadAcctHaltGv()) {
      g_long_halted = true;
      g_short_halted = true;
   }

   // ADR-110: baseline flat-side entry-pending sweep. Flat sides never enter
   // reconstruction; clear their stale pre-crash entry limits before the tick
   // loop re-quotes. The zero-position gate excludes orphaned/halted sides.
   V2_SweepFlatSideEntryPendings(_Symbol, g_preset.magic_long, g_preset.magic_long_exit, 1,
                                 g_preset.tel_instance_long);
   V2_SweepFlatSideEntryPendings(_Symbol, g_preset.magic_short, g_preset.magic_short_exit, -1,
                                 g_preset.tel_instance_short);

   if(V2_ShouldPublishCapSyncOnInit(long_orphan))
      V2_Cap_Sync(true, ArraySize(g_long_layers));
   if(V2_ShouldPublishCapSyncOnInit(short_orphan))
      V2_Cap_Sync(false, ArraySize(g_short_layers));

   if(long_orphan || short_orphan) {
      if(EnableTelemetry)
         V2EmitTelemetry(true);
   }

   if(long_orphan && short_orphan) {
      Print("ERROR: ", g_preset.ea_name, " OnInit FAILED — both instances have orphaned positions. ",
            "EA will not attach. Resolve all orphans manually before reattaching.");
      return INIT_FAILED;
   }

   if(long_orphan || short_orphan) {
      Print("WARNING: ", g_preset.ea_name, " partial startup — halted instance(s) will not trade; ",
            "clean instance(s) continue. Reattach flat after resolving orphans.");
   }

   g_v2_bcc_last_tier3 = 0;
   if(InpBccEnable) {
      if(!g_long_halted) {
         V2BccSideInputs long_bcc;
         V2_Bcc_FillLongInputs(long_bcc);
         V2_Bcc_RunSideInitPass(long_bcc, g_long_bcc, g_long_closeby_queue, g_long_system_alerts);
      }
      if(!g_short_halted) {
         V2BccSideInputs short_bcc;
         V2_Bcc_FillShortInputs(short_bcc);
         V2_Bcc_RunSideInitPass(short_bcc, g_short_bcc, g_short_closeby_queue, g_short_system_alerts);
      }
   }

   return agg.init_result;
}

void OnDeinit(const int reason) {
   Long_OnDeinit(reason);
   Short_OnDeinit(reason);
}

void OnTick() {
   ArrayResize(g_long_system_alerts, 0);
   ArrayResize(g_short_system_alerts, 0);
   V2_MaeOnTick();
   V2_ApiCounterMaybeReset();
   V2_RunDailyRolloverReconciliation();
   V2_RunRolloverRetryPasses();
   V2_Cb_CheckAndMaybeHalt(g_long_halted, g_short_halted, g_long_system_alerts);
   V2_Ta_CheckStartOfTick(g_long_halted, g_short_halted, g_long_system_alerts,
                          ArraySize(g_long_layers), ArraySize(g_short_layers),
                          InpMaxLayers, g_v2_ta_samedir_crit);
   V2_StraddleL0OnTick();
   Long_OnTick();
   Short_OnTick();
   V2_Bcc_MaybeRunTier3Sweep();
   V2_Ta_CheckEndOfTick(g_long_halted, g_short_halted, g_long_system_alerts,
                        _Symbol, g_preset.magic_long, g_preset.magic_short,
                        ArraySize(g_long_layers), ArraySize(g_short_layers));
   V2EmitTelemetry(false);
}

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result) {
   if (trans.type != TRADE_TRANSACTION_DEAL_ADD)
      return;
   Long_HandleDealFill(trans.deal, trans.position);
   Short_HandleDealFill(trans.deal, trans.position);
}

#endif // FXMATRIX_V2_ENGINE_MQH
