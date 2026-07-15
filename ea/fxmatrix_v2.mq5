//+------------------------------------------------------------------+
//| fxmatrix_v2.mq5 — Production V2 dual instance (MM_LONG + MM_SHORT)|
//| Magic: MM_LONG_V2=20260901, MM_SHORT_V2=20260902                 |
//| reload_flat, TRADE_ACTION_SLTP LIFO exits, running-state widen    |
//| Does NOT modify FXMatrix.mq5 or live account.                      |
//+------------------------------------------------------------------+
#property copyright "fxmatrix"
#property version   "2.11"
#property strict

#include "fxmatrix_v2_logic.mqh"
#include "fxmatrix_v2_telemetry.mqh"

input double InpQuoteSpread       = 0.0004;
input double InpSpreadMultiplier  = 0.500;
input double InpAddPipsFloor      = 9.0;
input double InpExitPips          = 3.0;
input double InpWidenRatio        = 1.304;
input double InpAddPipsCeiling    = 1000.0;
input double InpLotSize           = 0.01;
input int    InpMaxLayers         = 20;
input bool   InpVerboseLog        = true;

input bool   EnableTelemetry      = false;
input string TelemetryURL         = "https://pipshed.com/api/telemetry/push";
input string TelemetryAPIKey      = "";
input int    TelemetryIntervalSec = 60;

struct LongV2Layer {
   double entry_price;
   double exit_target;
   ulong  entry_ticket;
   ulong  position_ticket;
   ulong  exit_ticket;
};

LongV2Layer  g_long_layers[];
double   g_long_last_exit_price;
bool     g_long_last_exit_valid;
double   g_long_current_add_pips;
ulong    g_long_l0_ticket;
ulong    g_long_add_ticket;
datetime g_long_last_bar_time;

int g_long_stat_l0_entries;
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
   double closes[];
   if (CopyClose(_Symbol, PERIOD_M5, 1, 60, closes) < 49)
      return false;
   ArraySetAsSeries(closes, true);

   double c6  = closes[6];
   double c12 = closes[12];
   double c48 = closes[48];
   if (c6 <= 0.0 || c12 <= 0.0 || c48 <= 0.0)
      return false;

   double fv = 0.50 * c6 + 0.30 * c12 + 0.20 * c48;
   double mean = (c6 + c12 + c48) / 3.0;
   double sigma = MathSqrt(((c6 - mean) * (c6 - mean) +
                            (c12 - mean) * (c12 - mean) +
                            (c48 - mean) * (c48 - mean)) / 3.0);

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double half = (ask - bid) / 2.0;
   double bc_now = closes[0] + half;
   if (fv <= 0.0 || bc_now <= 0.0)
      return false;

   double r_bc = MathLog(bc_now / fv);
   double dynamic_hs = InpQuoteSpread + sigma * InpSpreadMultiplier;
   bid_theoretical = fv * MathExp(r_bc - dynamic_hs);
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
   OrderSend(req, res);
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
   if (!OrderSend(req, res))
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
   if (!OrderSend(req, res))
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

   double tp = Long_NormalizeSym(g_long_layers[layer_idx].exit_target);
   MqlTradeRequest req = {};
   MqlTradeResult  res = {};
   if(!V2_BuildExitSltpRequest(_Symbol, position_ticket, tp, req))
      return false;
   if (!OrderSend(req, res)) {
      if (InpVerboseLog)
         Print("WARN V2_LONG | tp set failed pos=", position_ticket,
               " tp=", DoubleToString(tp, 5),
               " retcode=", res.retcode);
      return false;
   }
   g_long_layers[layer_idx].exit_ticket = position_ticket;
   return true;
}

void Long_ClearExitTakeProfit(const ulong position_ref) {
   ulong position_ticket = Long_ResolvePositionTicket(position_ref);
   if (position_ticket == 0 || !PositionSelectByTicket(position_ticket))
      return;
   if (PositionGetDouble(POSITION_TP) == 0.0)
      return;

   MqlTradeRequest req = {};
   MqlTradeResult  res = {};
   req.action   = TRADE_ACTION_SLTP;
   req.symbol   = _Symbol;
   req.position = position_ticket;
   req.sl       = PositionGetDouble(POSITION_SL);
   req.tp       = 0.0;
   OrderSend(req, res);
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

void Long_ReplacePendingBuy(ulong &ticket_ref, const double price, const ulong magic, const string comment) {
   Long_CancelTicket(ticket_ref);
   ticket_ref = Long_PlaceBuyLimit(price, magic, comment);
}

void Long_PlaceExitForLayer(const int layer_idx, const bool immediate) {
   if (layer_idx < 0 || layer_idx >= ArraySize(g_long_layers))
      return;

   double target = g_long_layers[layer_idx].exit_target;
   Long_ClearExitTakeProfit(g_long_layers[layer_idx].position_ticket);
   if (Long_SetExitTakeProfit(layer_idx)) {
      g_long_stat_exit_limit_placed++;
      if (InpVerboseLog && immediate)
         Print("DIAG V2_LONG | event=exit_placed | layer=", layer_idx,
               " target=", DoubleToString(target, 5));
      return;
   }

   g_long_stat_exit_place_fail++;
   g_long_layers[layer_idx].exit_ticket = 0;
   if (InpVerboseLog) {
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      Print("WARN V2_LONG | exit placement failed layer=", layer_idx,
            " target=", DoubleToString(target, 5),
            " ask=", DoubleToString(ask, 5),
            " immediate=", (immediate ? "1" : "0"));
   }
}

void Long_EnsureTopExit() {
   int n = ArraySize(g_long_layers);
   if (n <= 0)
      return;

   int top = n - 1;
   ulong position_ticket = Long_ResolvePositionTicket(g_long_layers[top].position_ticket);
   if (position_ticket == 0 || !PositionSelectByTicket(position_ticket))
      return;

   double tp = PositionGetDouble(POSITION_TP);
   if (MathAbs(tp - g_long_layers[top].exit_target) <= _Point) {
      g_long_layers[top].exit_ticket = position_ticket;
      return;
   }

   Long_PlaceExitForLayer(top, false);
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
   g_long_add_ticket = Long_PlaceBuyLimit(add_price, 20260901, g_long_last_exit_valid ? "V2_Reload" : "V2_Add");
}

void Long_OnNewBar() {
   datetime bar_time = iTime(_Symbol, PERIOD_M5, 0);
   if (bar_time == g_long_last_bar_time)
      return;
   g_long_last_bar_time = bar_time;

   double bid_theoretical;
   if (!Long_ComputeBidSignal(bid_theoretical))
      return;

   double bid_lvl;
   Long_Adr013ClampBuy(bid_theoretical, bid_lvl);

   int n = ArraySize(g_long_layers);
   if (n == 0) {
      g_long_last_exit_valid = false;
      Long_ReplacePendingBuy(g_long_l0_ticket, bid_lvl, 20260901, "V2_L0");
      if (InpVerboseLog)
         Print("DIAG V2_LONG | event=l0_quote | bid_theo=", DoubleToString(bid_theoretical, 5),
               " bid_lvl=", DoubleToString(bid_lvl, 5));
   }

   Long_EnsureTopExit();
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

   if (n > 0)
      Long_ClearExitTakeProfit(g_long_layers[n - 1].position_ticket);

   Long_PlaceExitForLayer(n, true);
   Long_EnsureAddNext();
}

void Long_PopTopLayer() {
   int n = ArraySize(g_long_layers);
   if (n <= 0)
      return;

   g_long_last_exit_price = g_long_layers[n - 1].entry_price;
   g_long_last_exit_valid = true;

   Long_ClearExitTakeProfit(g_long_layers[n - 1].position_ticket);
   Long_CancelTicket(g_long_add_ticket);
   g_long_add_ticket = 0;

   ArrayResize(g_long_layers, n - 1);
   g_long_stat_exits++;

   // Instance-scoped flat reset: own g_long_layers only — never PositionsTotal().
   V2_OnOwnStackFlat(g_long_last_exit_valid, ArraySize(g_long_layers));
   if(ArraySize(g_long_layers) == 0)
      g_long_current_add_pips = InpAddPipsFloor;
   if(ArraySize(g_long_layers) > 0) {
      Long_EnsureTopExit();
      Long_EnsureAddNext();
   }
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

   if (entry_type == DEAL_ENTRY_IN &&
       deal_type == DEAL_TYPE_BUY &&
       deal_magic == (long)20260901) {
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

   if (entry_type == DEAL_ENTRY_OUT && deal_type == DEAL_TYPE_SELL &&
       ArraySize(g_long_layers) > 0) {
      int top = ArraySize(g_long_layers) - 1;
      ulong deal_pos = (ulong)HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID);
      if (deal_pos == g_long_layers[top].position_ticket) {
         double real_profit = HistoryDealGetDouble(deal_ticket, DEAL_PROFIT)
                              + HistoryDealGetDouble(deal_ticket, DEAL_SWAP)
                              + HistoryDealGetDouble(deal_ticket, DEAL_COMMISSION);
         datetime deal_time = (datetime)HistoryDealGetInteger(deal_ticket, DEAL_TIME);
         V2PodAccumulateExit(g_long_pod, real_profit);
         Long_PopTopLayer();
         if(ArraySize(g_long_layers) == 0 && g_long_pod.layers_closed > 0) {
            double hold_mins = (double)(deal_time - g_long_pod.start_time) / 60.0;
            string payload = V2BuildPodClosePayload(
               V2_TEL_INSTANCE_LONG,
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
                  " entry_type=", entry_type, " layers=", ArraySize(g_long_layers),
                  " last_exit_valid=", g_long_last_exit_valid);
      }
   }
}

int Long_OnInit() {
   g_long_last_exit_valid  = false;
   g_long_current_add_pips = InpAddPipsFloor;
   g_long_last_bar_time    = 0;
   g_long_processed_count  = 0;
   ArrayResize(g_long_processed_deals, 0);
   Print("INFO: fxmatrix_v2_long init magic=20260901",
         " WIDEN=", InpWidenRatio, " reload_flat=1");
   return INIT_SUCCEEDED;
}

void Long_OnDeinit(const int reason) {
   Print("V2_STATS_LONG | l0=", g_long_stat_l0_entries,
         " add=", g_long_stat_add_entries,
         " reload=", g_long_stat_reload_entries,
         " exits=", g_long_stat_exits,
         " max_layers=", g_long_stat_max_layers,
         " open_layers=", ArraySize(g_long_layers),
         " exit_limit_placed=", g_long_stat_exit_limit_placed,
         " exit_place_fail=", g_long_stat_exit_place_fail);
}

void Long_OnTick() {
   Long_OnNewBar();
}
struct ShortV2Layer {
   double entry_price;
   double exit_target;
   ulong  entry_ticket;
   ulong  position_ticket;
   ulong  exit_ticket;
};

ShortV2Layer  g_short_layers[];
double   g_short_last_exit_price;
bool     g_short_last_exit_valid;
double   g_short_current_add_pips;
ulong    g_short_l0_ticket;
ulong    g_short_add_ticket;
datetime g_short_last_bar_time;

int g_short_stat_l0_entries;
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
   double closes[];
   if (CopyClose(_Symbol, PERIOD_M5, 1, 60, closes) < 49)
      return false;
   ArraySetAsSeries(closes, true);

   double c6  = closes[6];
   double c12 = closes[12];
   double c48 = closes[48];
   if (c6 <= 0.0 || c12 <= 0.0 || c48 <= 0.0)
      return false;

   double fv = 0.50 * c6 + 0.30 * c12 + 0.20 * c48;
   double mean = (c6 + c12 + c48) / 3.0;
   double sigma = MathSqrt(((c6 - mean) * (c6 - mean) +
                            (c12 - mean) * (c12 - mean) +
                            (c48 - mean) * (c48 - mean)) / 3.0);

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double half = (ask - bid) / 2.0;
   double bc_now = closes[0] + half;
   if (fv <= 0.0 || bc_now <= 0.0)
      return false;

   double r_bc = MathLog(bc_now / fv);
   double dynamic_hs = InpQuoteSpread + sigma * InpSpreadMultiplier;
   offer_theoretical = fv * MathExp(r_bc + dynamic_hs);
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
   OrderSend(req, res);
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
   if (!OrderSend(req, res))
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
   if (!OrderSend(req, res))
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

   double tp = Short_NormalizeSym(g_short_layers[layer_idx].exit_target);
   MqlTradeRequest req = {};
   MqlTradeResult  res = {};
   if(!V2_BuildExitSltpRequest(_Symbol, position_ticket, tp, req))
      return false;
   if (!OrderSend(req, res)) {
      if (InpVerboseLog)
         Print("WARN V2_SHORT | tp set failed pos=", position_ticket,
               " tp=", DoubleToString(tp, 5),
               " retcode=", res.retcode);
      return false;
   }
   g_short_layers[layer_idx].exit_ticket = position_ticket;
   return true;
}

void Short_ClearExitTakeProfit(const ulong position_ref) {
   ulong position_ticket = Short_ResolvePositionTicket(position_ref);
   if (position_ticket == 0 || !PositionSelectByTicket(position_ticket))
      return;
   if (PositionGetDouble(POSITION_TP) == 0.0)
      return;

   MqlTradeRequest req = {};
   MqlTradeResult  res = {};
   req.action   = TRADE_ACTION_SLTP;
   req.symbol   = _Symbol;
   req.position = position_ticket;
   req.sl       = PositionGetDouble(POSITION_SL);
   req.tp       = 0.0;
   OrderSend(req, res);
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

void Short_ReplacePendingSell(ulong &ticket_ref, const double price, const ulong magic, const string comment) {
   Short_CancelTicket(ticket_ref);
   ticket_ref = Short_PlaceSellLimit(price, magic, comment);
}

void Short_PlaceExitForLayer(const int layer_idx, const bool immediate) {
   if (layer_idx < 0 || layer_idx >= ArraySize(g_short_layers))
      return;

   double target = g_short_layers[layer_idx].exit_target;
   Short_ClearExitTakeProfit(g_short_layers[layer_idx].position_ticket);
   if (Short_SetExitTakeProfit(layer_idx)) {
      g_short_stat_exit_limit_placed++;
      if (InpVerboseLog && immediate)
         Print("DIAG V2_SHORT | event=exit_placed | layer=", layer_idx,
               " target=", DoubleToString(target, 5));
      return;
   }

   g_short_stat_exit_place_fail++;
   g_short_layers[layer_idx].exit_ticket = 0;
   if (InpVerboseLog) {
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      Print("WARN V2_SHORT | exit placement failed layer=", layer_idx,
            " target=", DoubleToString(target, 5),
            " bid=", DoubleToString(bid, 5),
            " immediate=", (immediate ? "1" : "0"));
   }
}

void Short_EnsureTopExit() {
   int n = ArraySize(g_short_layers);
   if (n <= 0)
      return;

   int top = n - 1;
   ulong position_ticket = Short_ResolvePositionTicket(g_short_layers[top].position_ticket);
   if (position_ticket == 0 || !PositionSelectByTicket(position_ticket))
      return;

   double tp = PositionGetDouble(POSITION_TP);
   if (MathAbs(tp - g_short_layers[top].exit_target) <= _Point) {
      g_short_layers[top].exit_ticket = position_ticket;
      return;
   }

   Short_PlaceExitForLayer(top, false);
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
   g_short_add_ticket = Short_PlaceSellLimit(add_price, 20260902, g_short_last_exit_valid ? "V2_Reload" : "V2_Add");
}

void Short_OnNewBar() {
   datetime bar_time = iTime(_Symbol, PERIOD_M5, 0);
   if (bar_time == g_short_last_bar_time)
      return;
   g_short_last_bar_time = bar_time;

   double offer_theoretical;
   if (!Short_ComputeOfferSignal(offer_theoretical))
      return;

   double offer_lvl;
   Short_Adr013ClampSell(offer_theoretical, offer_lvl);

   int n = ArraySize(g_short_layers);
   if (n == 0) {
      g_short_last_exit_valid = false;
      Short_ReplacePendingSell(g_short_l0_ticket, offer_lvl, 20260902, "V2_L0");
      if (InpVerboseLog)
         Print("DIAG V2_SHORT | event=l0_quote | offer_theo=", DoubleToString(offer_theoretical, 5),
               " offer_lvl=", DoubleToString(offer_lvl, 5));
   }

   Short_EnsureTopExit();
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

   if (n > 0)
      Short_ClearExitTakeProfit(g_short_layers[n - 1].position_ticket);

   Short_PlaceExitForLayer(n, true);
   Short_EnsureAddNext();
}

void Short_PopTopLayer() {
   int n = ArraySize(g_short_layers);
   if (n <= 0)
      return;

   g_short_last_exit_price = g_short_layers[n - 1].entry_price;
   g_short_last_exit_valid = true;

   Short_ClearExitTakeProfit(g_short_layers[n - 1].position_ticket);
   Short_CancelTicket(g_short_add_ticket);
   g_short_add_ticket = 0;

   ArrayResize(g_short_layers, n - 1);
   g_short_stat_exits++;

   // Instance-scoped flat reset: own g_short_layers only — never PositionsTotal().
   V2_OnOwnStackFlat(g_short_last_exit_valid, ArraySize(g_short_layers));
   if(ArraySize(g_short_layers) == 0)
      g_short_current_add_pips = InpAddPipsFloor;
   if(ArraySize(g_short_layers) > 0) {
      Short_EnsureTopExit();
      Short_EnsureAddNext();
   }
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

   if (entry_type == DEAL_ENTRY_IN &&
       deal_type == DEAL_TYPE_SELL &&
       deal_magic == (long)20260902) {
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

   if (entry_type == DEAL_ENTRY_OUT && deal_type == DEAL_TYPE_BUY &&
       ArraySize(g_short_layers) > 0) {
      int top = ArraySize(g_short_layers) - 1;
      ulong deal_pos = (ulong)HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID);
      if (deal_pos == g_short_layers[top].position_ticket) {
         double real_profit = HistoryDealGetDouble(deal_ticket, DEAL_PROFIT)
                              + HistoryDealGetDouble(deal_ticket, DEAL_SWAP)
                              + HistoryDealGetDouble(deal_ticket, DEAL_COMMISSION);
         datetime deal_time = (datetime)HistoryDealGetInteger(deal_ticket, DEAL_TIME);
         V2PodAccumulateExit(g_short_pod, real_profit);
         Short_PopTopLayer();
         if(ArraySize(g_short_layers) == 0 && g_short_pod.layers_closed > 0) {
            double hold_mins = (double)(deal_time - g_short_pod.start_time) / 60.0;
            string payload = V2BuildPodClosePayload(
               V2_TEL_INSTANCE_SHORT,
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
                  " entry_type=", entry_type, " layers=", ArraySize(g_short_layers),
                  " last_exit_valid=", g_short_last_exit_valid);
      }
   }
}

int Short_OnInit() {
   g_short_last_exit_valid  = false;
   g_short_current_add_pips = InpAddPipsFloor;
   g_short_last_bar_time    = 0;
   g_short_processed_count  = 0;
   ArrayResize(g_short_processed_deals, 0);
   Print("INFO: fxmatrix_v2_short init magic=20260902",
         " WIDEN=", InpWidenRatio, " reload_flat=1");
   return INIT_SUCCEEDED;
}

void Short_OnDeinit(const int reason) {
   Print("V2_STATS_SHORT | l0=", g_short_stat_l0_entries,
         " add=", g_short_stat_add_entries,
         " reload=", g_short_stat_reload_entries,
         " exits=", g_short_stat_exits,
         " max_layers=", g_short_stat_max_layers,
         " open_layers=", ArraySize(g_short_layers),
         " exit_limit_placed=", g_short_stat_exit_limit_placed,
         " exit_place_fail=", g_short_stat_exit_place_fail);
}

void Short_OnTick() {
   Short_OnNewBar();
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
   string payload_long = V2BuildInstanceTelemetryPayload(
      V2_TEL_INSTANCE_LONG,
      _Symbol,
      long_layers,
      ArraySize(long_layers),
      1,
      InpQuoteSpread,
      ts_utc
   );
   string payload_short = V2BuildInstanceTelemetryPayload(
      V2_TEL_INSTANCE_SHORT,
      _Symbol,
      short_layers,
      ArraySize(short_layers),
      -1,
      InpQuoteSpread,
      ts_utc
   );

   V2TelemetryWebPost(TelemetryURL, TelemetryAPIKey, payload_long, InpVerboseLog);
   V2TelemetryWebPost(TelemetryURL, TelemetryAPIKey, payload_short, InpVerboseLog);
}

int OnInit() {
   V2PodReset(g_long_pod);
   V2PodReset(g_short_pod);
   g_last_telemetry_emit = 0;
   Print("INFO: fxmatrix_v2 init MM_LONG_V2=", MM_LONG_V2, " MM_SHORT_V2=", MM_SHORT_V2, " reload_flat=1 running_state_widen=1 telemetry=", (EnableTelemetry ? "1" : "0"));
   Long_OnInit();
   Short_OnInit();
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) {
   Long_OnDeinit(reason);
   Short_OnDeinit(reason);
}

void OnTick() {
   Long_OnTick();
   Short_OnTick();
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
