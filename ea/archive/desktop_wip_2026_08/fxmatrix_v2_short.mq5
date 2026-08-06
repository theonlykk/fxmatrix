//+------------------------------------------------------------------+
//| fxmatrix_v2_short.mq5 — Stage-2 V2 validation (MM_SHORT only)  |
//| ADR-092 minimal: BC signal, ADR-013, reload_flat, WIDEN_RATIO     |
//| Does NOT modify FXMatrix.mq5 or fxmatrix_v2_long.mq5              |
//+------------------------------------------------------------------+
#property copyright "fxmatrix"
#property version   "2.00"
#property strict

input double InpQuoteSpread       = 0.0004;
input double InpSpreadMultiplier  = 0.500;
input double InpAddPipsFloor      = 9.0;
input double InpExitPips          = 3.0;
input double InpWidenRatio        = 1.304;
input double InpAddPipsCeiling    = 1000.0;
input double InpLotSize           = 0.01;
input int    InpMaxLayers         = 20;
input ulong  InpMagicEntry        = 20261100;
input ulong  InpMagicExit         = 20261102;
input bool   InpVerboseLog        = true;

struct V2Layer {
   double entry_price;
   double exit_target;
   ulong  entry_ticket;
   ulong  position_ticket;
   ulong  exit_ticket;
};

V2Layer  g_layers[];
double   g_current_add_pips;
double   g_last_exit_price;
bool     g_last_exit_valid;
ulong    g_l0_ticket;
ulong    g_add_ticket;
datetime g_last_bar_time;

int g_stat_l0_entries;
int g_stat_add_entries;
int g_stat_reload_entries;
int g_stat_exits;
int g_stat_max_layers;
int g_stat_exit_place_fail;
int g_stat_exit_limit_placed;

ulong g_processed_deals[];
int   g_processed_count;

//+------------------------------------------------------------------+
double PipsToPrice(const double pips) {
   return pips * _Point * 10.0;
}

double NormalizeSym(const double price) {
   return NormalizeDouble(price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
}

bool Adr013ClampSell(const double theoretical, double &out_price) {
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double min_dist = MathMax(_Point, SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point);
   if (theoretical <= ask)
      out_price = NormalizeSym(MathMax(theoretical, ask + min_dist));
   else
      out_price = NormalizeSym(theoretical);
   return (MathAbs(out_price - theoretical) > _Point * 0.1);
}

bool ComputeOfferSignal(double &offer_theoretical) {
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

bool IsOurOrderTicket(const ulong ticket, const ulong magic) {
   if (ticket == 0)
      return false;
   if (OrderSelect(ticket))
      return (OrderGetInteger(ORDER_MAGIC) == (long)magic);
   if (HistoryOrderSelect(ticket))
      return (HistoryOrderGetInteger(ticket, ORDER_MAGIC) == (long)magic);
   return false;
}

void CancelTicket(const ulong ticket) {
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

ulong PlaceSellLimit(const double price, const ulong magic, const string comment) {
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
   req.price        = NormalizeSym(price);
   req.magic        = magic;
   req.type_filling = ORDER_FILLING_RETURN;
   req.type_time    = ORDER_TIME_GTC;
   req.comment      = comment;
   if (!OrderSend(req, res))
      return 0;
   return res.order;
}

ulong PlaceBuyLimit(const double price, const ulong magic, const string comment) {
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
   req.price        = NormalizeSym(price);
   req.magic        = magic;
   req.type_filling = ORDER_FILLING_RETURN;
   req.type_time    = ORDER_TIME_GTC;
   req.comment      = comment;
   if (!OrderSend(req, res))
      return 0;
   return res.order;
}

ulong ResolvePositionTicket(const ulong position_ref) {
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

bool SetExitTakeProfit(const int layer_idx) {
   if (layer_idx < 0 || layer_idx >= ArraySize(g_layers))
      return false;

   ulong position_ticket = ResolvePositionTicket(g_layers[layer_idx].position_ticket);
   if (position_ticket == 0)
      return false;

   double tp = g_layers[layer_idx].exit_target;
   MqlTradeRequest req = {};
   MqlTradeResult  res = {};
   req.action   = TRADE_ACTION_SLTP;
   req.symbol   = _Symbol;
   req.position = position_ticket;
   req.sl       = 0.0;
   req.tp       = NormalizeSym(tp);
   if (!OrderSend(req, res)) {
      if (InpVerboseLog)
         Print("WARN V2 | tp set failed pos=", position_ticket,
               " tp=", DoubleToString(tp, 5),
               " retcode=", res.retcode);
      return false;
   }
   g_layers[layer_idx].exit_ticket = position_ticket;
   return true;
}

void ClearExitTakeProfit(const ulong position_ref) {
   ulong position_ticket = ResolvePositionTicket(position_ref);
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

double ComputeAddTarget() {
   int n = ArraySize(g_layers);
   if (n <= 0)
      return 0.0;

   double step_pips;
   double anchor;
   if (g_last_exit_valid) {
      anchor = g_last_exit_price;
      step_pips = InpAddPipsFloor;
   } else {
      anchor = g_layers[n - 1].entry_price;
      bool still_shallow = (n < 3);
      step_pips = still_shallow ? InpAddPipsFloor : g_current_add_pips;
   }
   return NormalizeSym(anchor + PipsToPrice(step_pips));
}

void ReplacePendingSell(ulong &ticket_ref, const double price, const ulong magic, const string comment) {
   CancelTicket(ticket_ref);
   ticket_ref = PlaceSellLimit(price, magic, comment);
}

void PlaceExitForLayer(const int layer_idx, const bool immediate) {
   if (layer_idx < 0 || layer_idx >= ArraySize(g_layers))
      return;

   double target = g_layers[layer_idx].exit_target;
   ClearExitTakeProfit(g_layers[layer_idx].position_ticket);
   if (SetExitTakeProfit(layer_idx)) {
      g_stat_exit_limit_placed++;
      if (InpVerboseLog && immediate)
         Print("DIAG V2 | event=exit_placed | layer=", layer_idx,
               " target=", DoubleToString(target, 5));
      return;
   }

   g_stat_exit_place_fail++;
   g_layers[layer_idx].exit_ticket = 0;
   if (InpVerboseLog) {
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      Print("WARN V2 | exit placement failed layer=", layer_idx,
            " target=", DoubleToString(target, 5),
            " bid=", DoubleToString(bid, 5),
            " immediate=", (immediate ? "1" : "0"));
   }
}

void EnsureTopExit() {
   int n = ArraySize(g_layers);
   if (n <= 0)
      return;

   int top = n - 1;
   ulong position_ticket = ResolvePositionTicket(g_layers[top].position_ticket);
   if (position_ticket == 0 || !PositionSelectByTicket(position_ticket))
      return;

   double tp = PositionGetDouble(POSITION_TP);
   if (MathAbs(tp - g_layers[top].exit_target) <= _Point) {
      g_layers[top].exit_ticket = position_ticket;
      return;
   }

   PlaceExitForLayer(top, false);
}

void EnsureAddNext() {
   int n = ArraySize(g_layers);
   if (n <= 0 || n >= InpMaxLayers)
      return;
   if (g_add_ticket != 0 && OrderSelect(g_add_ticket))
      return;

   double add_price = ComputeAddTarget();
   if (add_price <= 0.0)
      return;
   g_add_ticket = PlaceSellLimit(add_price, InpMagicEntry, g_last_exit_valid ? "V2_Reload" : "V2_Add");
}

void OnNewBar() {
   datetime bar_time = iTime(_Symbol, PERIOD_M5, 0);
   if (bar_time == g_last_bar_time)
      return;
   g_last_bar_time = bar_time;

   double offer_theoretical;
   if (!ComputeOfferSignal(offer_theoretical))
      return;

   double offer_lvl;
   Adr013ClampSell(offer_theoretical, offer_lvl);

   int n = ArraySize(g_layers);
   if (n == 0) {
      g_last_exit_valid = false;
      ReplacePendingSell(g_l0_ticket, offer_lvl, InpMagicEntry, "V2_L0");
      if (InpVerboseLog)
         Print("DIAG V2 | event=l0_quote | offer_theo=", DoubleToString(offer_theoretical, 5),
               " offer_lvl=", DoubleToString(offer_lvl, 5));
   }

   EnsureTopExit();
   EnsureAddNext();
}

void AppendLayer(const double entry_price, const ulong entry_ticket,
                 const ulong position_ticket, const bool is_reload) {
   int n = ArraySize(g_layers);
   ArrayResize(g_layers, n + 1);
   g_layers[n].entry_price      = NormalizeSym(entry_price);
   g_layers[n].entry_ticket     = entry_ticket;
   g_layers[n].position_ticket  = position_ticket;
   g_layers[n].exit_ticket      = 0;
   g_layers[n].exit_target      = NormalizeSym(entry_price - PipsToPrice(InpExitPips));

   if (n == 0)
      g_stat_l0_entries++;
   else if (is_reload)
      g_stat_reload_entries++;
   else
      g_stat_add_entries++;

   if (ArraySize(g_layers) > g_stat_max_layers)
      g_stat_max_layers = ArraySize(g_layers);

   if (ArraySize(g_layers) >= 3)
      g_current_add_pips = MathMin(InpAddPipsCeiling, g_current_add_pips * InpWidenRatio);

   if (is_reload)
      g_last_exit_valid = false;

   CancelTicket(g_add_ticket);
   g_add_ticket = 0;

   if (n > 0)
      ClearExitTakeProfit(g_layers[n - 1].position_ticket);

   PlaceExitForLayer(n, true);
   EnsureAddNext();
}

void PopTopLayer() {
   int n = ArraySize(g_layers);
   if (n <= 0)
      return;

   g_last_exit_price = g_layers[n - 1].entry_price;
   g_last_exit_valid = true;

   ClearExitTakeProfit(g_layers[n - 1].position_ticket);
   CancelTicket(g_add_ticket);
   g_add_ticket = 0;

   ArrayResize(g_layers, n - 1);
   g_stat_exits++;

   if (ArraySize(g_layers) == 0) {
      g_last_exit_valid = false;
      g_current_add_pips = InpAddPipsFloor;
   } else {
      EnsureTopExit();
      EnsureAddNext();
   }
}

int OnInit() {
   g_current_add_pips = InpAddPipsFloor;
   g_last_exit_valid  = false;
   g_last_bar_time    = 0;
   g_processed_count  = 0;
   ArrayResize(g_processed_deals, 0);
   Print("INFO: fxmatrix_v2_short init magic=", InpMagicEntry, "/", InpMagicExit,
         " WIDEN=", InpWidenRatio, " reload_flat=1");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) {
   Print("V2_STATS | l0=", g_stat_l0_entries,
         " add=", g_stat_add_entries,
         " reload=", g_stat_reload_entries,
         " exits=", g_stat_exits,
         " max_layers=", g_stat_max_layers,
         " open_layers=", ArraySize(g_layers),
         " exit_limit_placed=", g_stat_exit_limit_placed,
         " exit_place_fail=", g_stat_exit_place_fail);
}

bool DealWasProcessed(const ulong deal_ticket) {
   for (int i = 0; i < g_processed_count; i++)
      if (g_processed_deals[i] == deal_ticket)
         return true;
   return false;
}

void MarkDealProcessed(const ulong deal_ticket) {
   if (DealWasProcessed(deal_ticket))
      return;
   ArrayResize(g_processed_deals, g_processed_count + 1);
   g_processed_deals[g_processed_count++] = deal_ticket;
}

void HandleDealFill(const ulong deal_ticket, const ulong position_ref) {
   if (DealWasProcessed(deal_ticket))
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

   MarkDealProcessed(deal_ticket);

   if (entry_type == DEAL_ENTRY_IN &&
       deal_type == DEAL_TYPE_SELL &&
       deal_magic == (long)InpMagicEntry) {
      bool is_reload = g_last_exit_valid;
      if (order_ticket == g_l0_ticket)
         g_l0_ticket = 0;
      if (order_ticket == g_add_ticket)
         g_add_ticket = 0;
      if (ArraySize(g_layers) == 0)
         g_last_exit_valid = false;
      AppendLayer(deal_price, order_ticket, position_id, is_reload);
      if (InpVerboseLog)
         Print("DIAG V2 | event=entry_filled | price=", DoubleToString(deal_price, 5),
               " reload=", is_reload, " layers=", ArraySize(g_layers));
      return;
   }

   if (entry_type == DEAL_ENTRY_OUT && deal_type == DEAL_TYPE_BUY &&
       ArraySize(g_layers) > 0) {
      int top = ArraySize(g_layers) - 1;
      ulong deal_pos = (ulong)HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID);
      if (deal_pos == g_layers[top].position_ticket) {
         PopTopLayer();
         if (InpVerboseLog)
            Print("DIAG V2 | event=exit_filled | deal=", deal_ticket,
                  " entry_type=", entry_type, " layers=", ArraySize(g_layers),
                  " last_exit_valid=", g_last_exit_valid);
      }
   }
}

void OnTick() {
   OnNewBar();
}

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result) {
   if (trans.type != TRADE_TRANSACTION_DEAL_ADD)
      return;
   HandleDealFill(trans.deal, trans.position);
}
