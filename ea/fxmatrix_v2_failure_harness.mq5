//+------------------------------------------------------------------+
//| fxmatrix_v2_failure_harness.mq5 — failure-injection integration   |
//| Strategy Tester only. Does NOT modify production EA defaults.     |
//+------------------------------------------------------------------+
#property copyright "fxmatrix"
#property version   "1.00"
#property strict

// Production timers (15s retry / 90s escalate) — do not override here.

#include "fxmatrix_v2_exits.mqh"
#include "fxmatrix_v2_telemetry.mqh"

input double InpLotSize = 0.01;

struct HarnessLayer {
   double entry_price;
   double exit_target;
   ulong  position_ticket;
   ulong  exit_ticket;
   datetime last_exit_retry_time;
   datetime first_exit_retry_time;
   bool     exit_escalated;
};

HarnessLayer g_layer;
string       g_system_alerts[];
V2CloseByTask g_closeby_queue[];
bool         g_halted = false;

int    g_timer_fires = 0;
int    g_audit_attempts = 0;
int    g_throttled_skips = 0;
int    g_rejected_sends = 0;
bool   g_escalation_seen = false;
bool   g_recovery_seen = false;
bool   g_closeby_retry_gt1 = false;
bool   g_force_invalid_exit = true;
bool   g_finished = false;
bool   g_closeby_test_started = false;
bool   g_closeby_fail_test_started = false;
ulong  g_hedge_position_ticket = 0;
bool   g_started = false;
datetime g_test_start = 0;
datetime g_sim_now = 0;
int    g_tick_steps = 0;

//+------------------------------------------------------------------+
double NormalizeSym(const double price)
{
   return NormalizeDouble(price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
}

//+------------------------------------------------------------------+
//| Real OrderSend rejection: SELL_LIMIT inside broker stops distance.|
//+------------------------------------------------------------------+
bool Harness_ForceRejectedExitLimit(const int entry_direction,
                                    int &out_retcode)
{
   out_retcode = 0;
   double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   MqlTradeRequest req = {};
   MqlTradeResult  res = {};
   req.action       = TRADE_ACTION_PENDING;
   req.symbol       = _Symbol;
   req.volume       = InpLotSize;
   req.type         = (entry_direction > 0) ? ORDER_TYPE_SELL_LIMIT : ORDER_TYPE_BUY_LIMIT;
   req.magic        = (entry_direction > 0) ? MM_LONG_V2_EXIT : MM_SHORT_V2_EXIT;
   req.type_filling = ORDER_FILLING_RETURN;
   req.type_time    = ORDER_TIME_GTC;
   req.comment      = "V2_Exit_HARNESS_REJECT";

   // Zero volume → broker rejects with TRADE_RETCODE_INVALID_VOLUME (10014).
   req.volume = 0;

   if(entry_direction > 0) {
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      req.price = NormalizeSym(ask + 10.0 * pt);
   } else {
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      req.price = NormalizeSym(bid - 10.0 * pt);
   }

   if(!OrderSend(req, res)) {
      out_retcode = (int)res.retcode;
      Print("HARNESS | forced exit OrderSend rejected retcode=", out_retcode,
            " price=", DoubleToString(req.price, 5),
            " volume=", DoubleToString(req.volume, 2),
            " ask=", DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_ASK), 5),
            " bid=", DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_BID), 5));
      g_rejected_sends++;
      return false;
   }

   out_retcode = (int)res.retcode;
   Print("HARNESS WARN | forced exit unexpectedly succeeded ticket=", res.order,
         " retcode=", res.retcode);
   if(res.order > 0)
      V2_CancelExitOrder(res.order);
   return false;
}

//+------------------------------------------------------------------+
bool Harness_PlaceExitLimit(const bool force_invalid)
{
   if(force_invalid)
   {
      int rc = 0;
      if(!Harness_ForceRejectedExitLimit(1, rc))
         return false;
      return (rc == 0);
   }

   double target = NormalizeSym(g_layer.exit_target);
   double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double freeze = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL) * pt;
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(target <= ask + freeze)
      target = NormalizeSym(ask + freeze + 10.0 * pt);

   ulong ticket = V2_SendExitLimit(_Symbol, target, InpLotSize, 1,
                                   MM_LONG_V2_EXIT, target);
   if(ticket == 0)
      return false;

   g_layer.exit_ticket = ticket;
   g_layer.last_exit_retry_time  = 0;
   g_layer.first_exit_retry_time = 0;
   g_layer.exit_escalated        = false;
   return true;
}

//+------------------------------------------------------------------+
//| Production-equivalent audit loop (mirrors Long_AuditExitLimits).  |
//+------------------------------------------------------------------+
void Harness_AuditExitLimits()
{
   if(g_halted)
      return;

   datetime now = g_sim_now > 0 ? g_sim_now : TimeCurrent();
   bool position_live = false;
   if(g_layer.position_ticket != 0 &&
      PositionSelectByTicket(g_layer.position_ticket))
      position_live = true;

   bool exit_live = V2_ExitOrderLiveOrFilled(g_layer.exit_ticket);
   if(g_layer.exit_ticket != 0 && !exit_live) {
      Print("HARNESS | stale exit ticket cleared ticket=", g_layer.exit_ticket);
      g_layer.exit_ticket = 0;
      exit_live = false;
   }

   V2ExitAuditAction action = V2_EvaluateExitAudit(
      position_live,
      exit_live,
      g_layer.last_exit_retry_time,
      g_layer.first_exit_retry_time,
      g_layer.exit_escalated,
      now);

   if(action == V2_EXIT_AUDIT_OK) {
      Print("HARNESS | audit OK exit_live=", (exit_live ? "1" : "0"),
            " t=", TimeToString(now, TIME_SECONDS));
      return;
   }

   if(action == V2_EXIT_AUDIT_THROTTLED) {
      g_throttled_skips++;
      Print("HARNESS | audit THROTTLED t=", TimeToString(now, TIME_SECONDS),
            " since_last=", (now - g_layer.last_exit_retry_time), "s");
      return;
   }

   g_audit_attempts++;

   if(action == V2_EXIT_AUDIT_ESCALATE) {
      V2_EscalateExitAlert(g_system_alerts, V2_TEL_INSTANCE_LONG, 0,
                           g_layer.exit_target, g_layer.exit_escalated);
      g_escalation_seen = true;

      V2TelLayerSnapshot snap[1];
      snap[0].entry_price      = g_layer.entry_price;
      snap[0].exit_target      = g_layer.exit_target;
      snap[0].lot_size         = InpLotSize;
      snap[0].direction        = 1;
      snap[0].position_ticket  = g_layer.position_ticket;
      snap[0].exit_ticket      = g_layer.exit_ticket;
      string payload = V2BuildInstanceTelemetryPayload(
         V2_TEL_INSTANCE_LONG, _Symbol, snap, 1, 1, 0.0004, TimeGMT(),
         g_system_alerts);
      Print("HARNESS | telemetry payload=", payload);
   }

   if(g_layer.first_exit_retry_time == 0)
      g_layer.first_exit_retry_time = now;
   g_layer.last_exit_retry_time = now;

   Print("HARNESS | audit PLACE attempt #", g_audit_attempts,
         " action=", (int)action,
         " t=", TimeToString(now, TIME_SECONDS));

   if(Harness_PlaceExitLimit(g_force_invalid_exit && !g_escalation_seen)) {
      if(!g_force_invalid_exit || g_escalation_seen) {
         g_recovery_seen = true;
         Print("HARNESS | AuditExitLimits recovered ticket=", g_layer.exit_ticket);
      }
   } else {
      Print("HARNESS | audit placement still failing");
   }
}

//+------------------------------------------------------------------+
bool Harness_OpenLongLayer()
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   MqlTradeRequest req = {};
   MqlTradeResult  res = {};
   req.action    = TRADE_ACTION_DEAL;
   req.symbol    = _Symbol;
   req.volume    = InpLotSize;
   req.type      = ORDER_TYPE_BUY;
   req.price     = ask;
   req.deviation = 20;
   req.magic     = MM_LONG_V2;
   req.comment   = "HARNESS_ENTRY";

   if(!OrderSend(req, res)) {
      Print("HARNESS FAIL | entry OrderSend retcode=", res.retcode);
      return false;
   }

   ulong pos_id = res.order;
   if(!HistoryDealSelect(res.deal))
      return false;
   pos_id = (ulong)HistoryDealGetInteger(res.deal, DEAL_POSITION_ID);

   g_layer.entry_price      = NormalizeSym(HistoryDealGetDouble(res.deal, DEAL_PRICE));
   g_layer.exit_target      = NormalizeSym(g_layer.entry_price + 3.0 * _Point * 10.0);
   g_layer.position_ticket  = pos_id;
   g_layer.exit_ticket      = 0;
   g_layer.last_exit_retry_time  = 0;
   g_layer.first_exit_retry_time = 0;
   g_layer.exit_escalated        = false;

   Print("HARNESS | opened long position=", pos_id,
         " entry=", DoubleToString(g_layer.entry_price, 5),
         " exit_target=", DoubleToString(g_layer.exit_target, 5));
   return true;
}

//+------------------------------------------------------------------+
void Harness_StartCloseByFailTest()
{
   if(g_closeby_fail_test_started)
      return;
   g_closeby_fail_test_started = true;

   // Same ticket for both legs → real OrderSend CloseBy rejection each tick.
   V2_QueueCloseBy(g_closeby_queue, g_layer.position_ticket, g_layer.position_ticket);
   Print("HARNESS | CloseBy fail test queued position=", g_layer.position_ticket,
         " position_by=", g_layer.position_ticket, " (same-leg, expect retcode failure)");
}

//+------------------------------------------------------------------+
void Harness_StartCloseByRetryTest()
{
   if(g_closeby_test_started)
      return;
   g_closeby_test_started = true;
   Harness_StartCloseByFailTest();
}

//+------------------------------------------------------------------+
int OnInit()
{
   Print("HARNESS START | V2_EXIT_RETRY_INTERVAL_SEC=", V2_EXIT_RETRY_INTERVAL_SEC,
         " V2_EXIT_ESCALATE_AFTER_SEC=", V2_EXIT_ESCALATE_AFTER_SEC,
         " (production timers)");
   g_sim_now = 0;
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
bool Harness_EnsureStarted()
{
   if(g_started)
      return true;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.hour < 8)
      return false;

   g_test_start = TimeCurrent();
   g_sim_now = g_test_start;

   if(!Harness_OpenLongLayer())
      return false;

   int rc = 0;
   Harness_ForceRejectedExitLimit(1, rc);
   g_layer.exit_ticket = 0;

   g_started = true;
   return true;
}

//+------------------------------------------------------------------+
void Harness_OnStep()
{
   if(g_finished || !Harness_EnsureStarted())
      return;

   g_timer_fires++;
   g_sim_now = g_test_start + g_tick_steps;

   Harness_AuditExitLimits();

   if(g_escalation_seen && !g_recovery_seen) {
      g_force_invalid_exit = false;
      Print("HARNESS | switching to valid exit placement after escalation");
   }

   if(g_escalation_seen && g_recovery_seen && !g_closeby_test_started)
      Harness_StartCloseByRetryTest();

   if(ArraySize(g_closeby_queue) > 0) {
      V2_ProcessCloseByQueue(g_closeby_queue, V2_TEL_INSTANCE_LONG,
                             MM_LONG_V2, g_halted, true);
      // Scan log-side: any task with retries>1 before removal counts.
   }
   // Detect retry>1 from queue state on subsequent ticks (tasks stay while waiting).
   for(int i = 0; i < ArraySize(g_closeby_queue); i++) {
      if(g_closeby_queue[i].retries > 1)
         g_closeby_retry_gt1 = true;
   }

   // Finish after escalation + recovery + closeby retries, or ~105s simulated timeout.
   int elapsed = (int)(g_sim_now - g_test_start);
   bool done = g_escalation_seen && g_recovery_seen && g_closeby_retry_gt1;
   if(done || elapsed >= 105 || g_tick_steps >= 110) {
      Print("HARNESS SUMMARY | timer_fires=", g_timer_fires,
            " audit_attempts=", g_audit_attempts,
            " throttled_skips=", g_throttled_skips,
            " rejected_sends=", g_rejected_sends,
            " escalation_seen=", g_escalation_seen,
            " recovery_seen=", g_recovery_seen,
            " closeby_retry_gt1=", g_closeby_retry_gt1,
            " alerts_count=", ArraySize(g_system_alerts),
            " elapsed_s=", elapsed);

      if(g_escalation_seen && ArraySize(g_system_alerts) > 0)
         Print("HARNESS PASS | escalation + system_alerts populated");
      else
         Print("HARNESS FAIL | escalation path not fully observed");

      if(g_throttled_skips > 0)
         Print("HARNESS PASS | throttle observed (", g_throttled_skips, " skips)");
      else
         Print("HARNESS FAIL | no throttle observed");

      if(g_rejected_sends > 0)
         Print("HARNESS PASS | genuine OrderSend rejections=", g_rejected_sends);
      else
         Print("HARNESS FAIL | no OrderSend rejections recorded");

      if(g_closeby_retry_gt1)
         Print("HARNESS PASS | CloseBy retry beyond attempt 1 observed");
      else
         Print("HARNESS WARN | CloseBy retry>1 not observed");

      g_finished = true;
      ExpertRemove();
   }
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
}

void OnTick()
{
   if(!Harness_EnsureStarted())
      return;

   static datetime last_bar = 0;
   datetime bar = iTime(_Symbol, PERIOD_M1, 0);
   if(bar == last_bar)
      return;
   last_bar = bar;

   Harness_OnStep();
   g_tick_steps++;
}
