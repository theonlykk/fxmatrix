//+------------------------------------------------------------------+
//| fxmatrix_v2_exits.mqh — V2 resting exit limits + CloseBy pipeline |
//| Mirrors V1 PlaceExitLimit / AuditExitLimits / ProcessCloseByQueue |
//+------------------------------------------------------------------+
#ifndef FXMATRIX_V2_EXITS_MQH
#define FXMATRIX_V2_EXITS_MQH

#include "fxmatrix_v2_logic.mqh"
#include "fxmatrix_v2_telemetry.mqh"

//+------------------------------------------------------------------+
//| Broker-facing helpers (live book / history).                      |
//+------------------------------------------------------------------+
bool V2_ExitOrderLiveOrFilled(const ulong order_ticket)
{
   if(order_ticket == 0)
      return false;

   if(OrderSelect(order_ticket))
      return true;

   if(HistoryOrderSelect(order_ticket)) {
      long state = HistoryOrderGetInteger(order_ticket, ORDER_STATE);
      if(state == ORDER_STATE_FILLED || state == ORDER_STATE_PARTIAL)
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
bool V2_ExitPassivityOk(const string symbol,
                        const int entry_direction,
                        const double exit_price)
{
   double pt     = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double freeze = SymbolInfoInteger(symbol, SYMBOL_TRADE_FREEZE_LEVEL) * pt;

   if(entry_direction > 0) {
      double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
      return (exit_price > ask + freeze);
   }

   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   return (exit_price < bid - freeze);
}

//+------------------------------------------------------------------+
ulong V2_SendExitLimit(const string symbol,
                       const double exit_price,
                       const double volume,
                       const int entry_direction,
                       const ulong exit_magic,
                       const double normalize_price)
{
   if(!V2_ExitPassivityOk(symbol, entry_direction, exit_price))
      return 0;

   MqlTradeRequest req = {};
   MqlTradeResult  res = {};
   if(!V2_BuildExitLimitRequest(symbol, normalize_price, volume,
                                entry_direction, exit_magic, req))
      return 0;

   if(!V2_OrderSendCounted(req, res))
      return 0;

   return res.order;
}

//+------------------------------------------------------------------+
void V2_CancelExitOrder(const ulong order_ticket)
{
   if(order_ticket == 0)
      return;
   if(!OrderSelect(order_ticket))
      return;

   MqlTradeRequest req = {};
   MqlTradeResult  res = {};
   req.action = TRADE_ACTION_REMOVE;
   req.order  = order_ticket;
   V2_OrderSendCounted(req, res);
}

//+------------------------------------------------------------------+
ulong V2_ResolvePositionTicket(const ulong position_ref)
{
   if(position_ref == 0)
      return 0;
   if(PositionSelectByTicket(position_ref))
      return position_ref;
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((ulong)PositionGetInteger(POSITION_IDENTIFIER) == position_ref)
         return ticket;
   }
   return 0;
}

//+------------------------------------------------------------------+
bool V2_ModifyExitLimitPrice(const ulong order_ticket,
                             const double new_price,
                             const string symbol,
                             const int entry_direction,
                             const bool verbose_log)
{
   if(order_ticket == 0 || !OrderSelect(order_ticket))
      return false;

   double norm = NormalizeDouble(new_price, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));
   if(!V2_ExitPassivityOk(symbol, entry_direction, norm)) {
      if(verbose_log)
         Print("INFO [V2-ADR-045] Exit modify skipped — passivity/freeze. symbol=", symbol,
               " new_exit=", DoubleToString(norm, 5));
      return false;
   }

   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double stops_pts = (double)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;
   if(stops_pts > 0.0) {
      double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
      double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
      double ref_price = (entry_direction > 0) ? ask : bid;
      if(MathAbs(norm - ref_price) < stops_pts) {
         if(verbose_log)
            Print("INFO [V2-ADR-045] Exit modify skipped — stops level. symbol=", symbol,
                  " new_exit=", DoubleToString(norm, 5),
                  " stops_pts=", DoubleToString(stops_pts, 5));
         return false;
      }
   }

   MqlTradeRequest req = {};
   MqlTradeResult  res = {};
   req.action     = TRADE_ACTION_MODIFY;
   req.order      = order_ticket;
   req.price      = norm;
   req.sl         = OrderGetDouble(ORDER_SL);
   req.tp         = OrderGetDouble(ORDER_TP);
   req.type_time  = (ENUM_ORDER_TYPE_TIME)OrderGetInteger(ORDER_TYPE_TIME);
   req.expiration = (datetime)OrderGetInteger(ORDER_TIME_EXPIRATION);

   if(!V2_OrderSendCounted(req, res))
      return false;
   if(res.retcode == TRADE_RETCODE_NO_CHANGES)
      return true;
   if(res.retcode != TRADE_RETCODE_DONE) {
      if(verbose_log)
         Print("WARNING [V2-ADR-045] Exit OrderModify failed. symbol=", symbol,
               " retcode=", res.retcode);
      return false;
   }
   return true;
}

//+------------------------------------------------------------------+
void V2_QueueCloseBy(V2CloseByTask &queue[],
                     const ulong ticket1,
                     const ulong ticket2)
{
   int idx = ArraySize(queue);
   ArrayResize(queue, idx + 1);
   queue[idx].ticket1       = ticket1;
   queue[idx].ticket2       = ticket2;
   queue[idx].retries       = 0;
   queue[idx].last_retcode  = 0;
}

//+------------------------------------------------------------------+
//| ADR-071/072: async CloseBy with same-direction exhaustion guard.  |
//+------------------------------------------------------------------+
void V2_ProcessCloseByQueue(V2CloseByTask &queue[],
                            const string instance_tag,
                            const ulong closeby_magic,
                            bool &halted,
                            const bool verbose)
{
   int q_size = ArraySize(queue);
   if(q_size == 0)
      return;

   for(int i = q_size - 1; i >= 0; i--) {
      queue[i].retries++;

      if(queue[i].retries >= V2_CLOSEBY_MAX_RETRIES) {
         bool sel1  = PositionSelectByTicket(queue[i].ticket1);
         long type1 = sel1 ? PositionGetInteger(POSITION_TYPE) : -1;
         bool sel2  = PositionSelectByTicket(queue[i].ticket2);
         long type2 = sel2 ? PositionGetInteger(POSITION_TYPE) : -1;

         if(sel1 && sel2) {
            if(type1 != type2) {
               Print("WARNING V2_CLOSEBY_EXHAUSTED | instance=", instance_tag,
                     " opposite-direction legs — LIFO machinery will handle.",
                     " position=", queue[i].ticket1,
                     " position_by=", queue[i].ticket2,
                     " last_retcode=", queue[i].last_retcode);
            } else {
               string alert_msg = StringFormat(
                  "CRITICAL V2_CLOSEBY_SAME_DIRECTION | instance=%s "
                  "position=%I64u position_by=%I64u type=%d last_retcode=%d",
                  instance_tag, queue[i].ticket1, queue[i].ticket2,
                  type1, queue[i].last_retcode);
               Print(alert_msg);
               halted = true;
            }
         } else {
            Print("INFO V2_CLOSEBY_EXHAUSTED | instance=", instance_tag,
                  " one or both legs closed/unselectable.",
                  " position=", queue[i].ticket1,
                  " position_by=", queue[i].ticket2,
                  " last_retcode=", queue[i].last_retcode);
         }

         ArrayRemove(queue, i, 1);
         continue;
      }

      if(!PositionSelectByTicket(queue[i].ticket1) ||
         !PositionSelectByTicket(queue[i].ticket2)) {
         if(HistorySelectByPosition(queue[i].ticket1) ||
            HistorySelectByPosition(queue[i].ticket2)) {
            if(verbose)
               Print("INFO V2_CLOSEBY | instance=", instance_tag,
                     " position already closed in history — discarding task.");
            ArrayRemove(queue, i, 1);
            continue;
         }
         if(verbose)
            Print("INFO V2_CLOSEBY | instance=", instance_tag,
                  " retry ", queue[i].retries, "/", V2_CLOSEBY_MAX_RETRIES,
                  " — positions not yet on ledger.");
         continue;
      }

      PositionSelectByTicket(queue[i].ticket1);
      string sym = PositionGetString(POSITION_SYMBOL);

      PositionSelectByTicket(queue[i].ticket2);
      string sym2 = PositionGetString(POSITION_SYMBOL);

      if(sym != sym2) {
         Print("ERROR V2_CLOSEBY | instance=", instance_tag,
               " inconsistent symbols ticket1=", queue[i].ticket1,
               " sym1=", sym, " ticket2=", queue[i].ticket2,
               " sym2=", sym2, " — removing task and halting.");
         ArrayRemove(queue, i, 1);
         halted = true;
         return;
      }

      MqlTradeRequest req = {};
      MqlTradeResult  res = {};
      req.action      = TRADE_ACTION_CLOSE_BY;
      req.position    = queue[i].ticket1;
      req.position_by = queue[i].ticket2;
      req.symbol      = sym;
      req.magic       = closeby_magic;

      if(V2_OrderSendCounted(req, res)) {
         if(verbose)
            Print("INFO V2_CLOSEBY | instance=", instance_tag,
                  " success on retry ", queue[i].retries,
                  " position=", queue[i].ticket1,
                  " position_by=", queue[i].ticket2);
         ArrayRemove(queue, i, 1);
      } else {
         queue[i].last_retcode = (int)res.retcode;
         Print("WARNING V2_CLOSEBY | instance=", instance_tag,
               " retry ", queue[i].retries, "/", V2_CLOSEBY_MAX_RETRIES,
               " failed retcode=", res.retcode,
               " position=", queue[i].ticket1,
               " position_by=", queue[i].ticket2);
      }
   }
}

//+------------------------------------------------------------------+
void V2_PushSystemAlert(string &alerts[], const string alert_msg)
{
   int n = ArraySize(alerts);
   for(int i = 0; i < n; i++) {
      if(alerts[i] == alert_msg)
         return;
   }
   ArrayResize(alerts, n + 1);
   alerts[n] = alert_msg;
}

//+------------------------------------------------------------------+
void V2_EscalateExitAlert(string &alerts[],
                          const string instance_tag,
                          const int layer_idx,
                          const double exit_price,
                          bool &escalated)
{
   if(escalated)
      return;

   string alert_msg = V2_FormatExitEscalationAlert(instance_tag, layer_idx, exit_price);
   Print(alert_msg);
   V2_PushSystemAlert(alerts, alert_msg);
   escalated = true;
}

//+------------------------------------------------------------------+
int V2_ScanOpenPositionsByMagic(const string symbol,
                                const long magic,
                                ulong &out_tickets[])
{
   ArrayResize(out_tickets, 0);
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != symbol)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      int n = ArraySize(out_tickets);
      ArrayResize(out_tickets, n + 1);
      out_tickets[n] = ticket;
   }
   return ArraySize(out_tickets);
}

//+------------------------------------------------------------------+
int V2_ScanInstanceOrphanPositions(const string symbol,
                                   const long entry_magic,
                                   const long exit_magic,
                                   ulong &out_tickets[],
                                   string &out_magic_type)
{
   ulong entry_tickets[];
   ulong exit_tickets[];
   int entry_count = V2_ScanOpenPositionsByMagic(symbol, entry_magic, entry_tickets);
   int exit_count  = V2_ScanOpenPositionsByMagic(symbol, exit_magic, exit_tickets);
   out_magic_type  = V2_OrphanMagicTypeLabel(entry_count, exit_count);

   ArrayResize(out_tickets, 0);
   for(int i = 0; i < entry_count; i++) {
      int n = ArraySize(out_tickets);
      ArrayResize(out_tickets, n + 1);
      out_tickets[n] = entry_tickets[i];
   }
   for(int i = 0; i < exit_count; i++) {
      int n = ArraySize(out_tickets);
      ArrayResize(out_tickets, n + 1);
      out_tickets[n] = exit_tickets[i];
   }
   return ArraySize(out_tickets);
}

//+------------------------------------------------------------------+
bool V2_ProcessOrphanStartupCheck(string &system_alerts[],
                                  const string instance_tag,
                                  const int layer_count,
                                  const int position_count,
                                  const string magic_type,
                                  const ulong &tickets[])
{
   if(!V2_IsOrphanedStartupState(layer_count, position_count))
      return false;

   string alert = V2_FormatOrphanStartupAlert(instance_tag, position_count, magic_type, tickets);
   Print(alert);
   Print("ERROR: fxmatrix_v2 ", instance_tag,
         " startup aborted — orphan positions from prior session detected. ",
         "Close or reconcile manually, then reattach flat. Instance halted.");
   V2_PushSystemAlert(system_alerts, alert);
   return true;
}

//+------------------------------------------------------------------+
//| Per-exit P&L: deal fields first, position fallback (ADR-050).     |
//+------------------------------------------------------------------+
double V2_ComputeExitRealizedPnl(const ulong deal_ticket,
                                 const ulong position_ticket)
{
   double pnl = HistoryDealGetDouble(deal_ticket, DEAL_PROFIT)
              + HistoryDealGetDouble(deal_ticket, DEAL_SWAP)
              + HistoryDealGetDouble(deal_ticket, DEAL_COMMISSION);

   if(MathAbs(pnl) < 1e-10 && position_ticket > 0 &&
      PositionSelectByTicket(position_ticket))
      pnl = PositionGetDouble(POSITION_PROFIT) +
            PositionGetDouble(POSITION_SWAP);

   return pnl;
}

//+------------------------------------------------------------------+
//| EmitScalpClosed — one POST per LIFO layer exit (not pod-close).   |
//+------------------------------------------------------------------+
void V2EmitScalpClosed(const bool enable_telemetry,
                       const string telemetry_url,
                       const string api_key,
                       const bool verbose_log,
                       const string instance_id,
                       const string instrument,
                       const string direction,
                       const double entry_price,
                       const double exit_price,
                       const double gross_pnl,
                       const datetime entry_time,
                       const datetime exit_time,
                       const int layer_depth,
                       const int stack_depth,
                       const int open_depth)
{
   if(!enable_telemetry || telemetry_url == "" || api_key == "")
      return;

   double hold_mins = 0.0;
   if(entry_time > 0 && exit_time >= entry_time)
      hold_mins = (double)(exit_time - entry_time) / 60.0;
   double hold_bars = V2HoldTimeBarsM5(entry_time, exit_time);

   string payload = V2BuildScalpClosedPayload(
      instance_id,
      instrument,
      direction,
      entry_price,
      exit_price,
      hold_mins,
      hold_bars,
      gross_pnl,
      layer_depth,
      stack_depth,
      open_depth,
      TimeGMT(),
      exit_time
   );

   V2TelemetryWebPost(V2DeriveScalpClosedUrl(telemetry_url),
                      api_key, payload, verbose_log);
}

#endif // FXMATRIX_V2_EXITS_MQH
