//+------------------------------------------------------------------+
//| grind_limit_probe.mq5 -- C78: what IC's 200 limit counts           |
//|                                                                    |
//| TRADES on an EMPTY DEMO account only (refuses anything else).     |
//| RUN:  1) opens InpPositions market BUY 0.01 on InpSymbol;          |
//|       2) places BUY_LIMIT 0.01 orders far below the market until  |
//|          the first refusal (or InpMaxPending), logging retcode,   |
//|          duration and the book at that moment;                     |
//|       3) tries ONE more market BUY with the book at that point;   |
//|       4) deletes every order and closes every position carrying   |
//|          its magic, then prints whether the account is empty.      |
//| DRY:  prints the account checks and the plan; sends nothing.       |
//| CLEANUP: step 4 only (if a run was interrupted).                   |
//| Do not stop it by hand: a stopped script cannot clean up. If it    |
//| was stopped, run again with InpMode = 2.                           |
//| Reading (from the COUNTS, not the code alone; 30 positions open):  |
//| refused at pending 170 (sum 200) -> positions count (as on FTMO    |
//| hedging, 16 Sep); refused at pending 200 (sum 230) and step 3's    |
//| market BUY accepted -> the 200 is pending orders only; refused at  |
//| pending 200 and step 3 refused -> both limits bind at 200/230.     |
//| A successful retry (retry_ok) means the refusal was not a limit.   |
//| Writes no GlobalVariables and no files. Never beside live EAs.     |
//+------------------------------------------------------------------+
#property copyright "fxmatrix"
#property version   "1.00"
#property script_show_inputs

#include <Trade\Trade.mqh>

input int    InpMode        = 0;          // 0 = DRY, 1 = RUN, 2 = CLEANUP
input long   InpExpectLogin = 53077984;   // wine-d's empty IC demo; anything else refuses
input string InpSymbol      = "EURUSD";
input int    InpPositions   = 30;         // market BUY 0.01 opened first
input int    InpMaxPending  = 260;        // safety cap on BUY_LIMIT orders
input int    InpPauseMs     = 150;        // pause between requests

const ulong  PROBE_MAGIC   = 99078001;
const string PROBE_COMMENT = "C78PROBE";

CTrade g_trade;

//+------------------------------------------------------------------+
int CountOurs(const bool positions)
{
   int n = 0;
   if(positions) {
      for(int i = PositionsTotal() - 1; i >= 0; i--) {
         const ulong t = PositionGetTicket(i);
         if(t != 0 && (ulong)PositionGetInteger(POSITION_MAGIC) == PROBE_MAGIC)
            n++;
      }
   } else {
      for(int i = OrdersTotal() - 1; i >= 0; i--) {
         const ulong t = OrderGetTicket(i);
         if(t != 0 && (ulong)OrderGetInteger(ORDER_MAGIC) == PROBE_MAGIC)
            n++;
      }
   }
   return n;
}

//+------------------------------------------------------------------+
void PrintBook(const string tag)
{
   PrintFormat("LIMPROBE|BOOK|%s|positions=%d|orders=%d|sum=%d|ours_pos=%d|ours_ord=%d",
               tag, PositionsTotal(), OrdersTotal(), PositionsTotal() + OrdersTotal(),
               CountOurs(true), CountOurs(false));
}

//+------------------------------------------------------------------+
bool AccountChecksPass(const bool need_empty)
{
   const long login  = AccountInfoInteger(ACCOUNT_LOGIN);
   const long tmode  = AccountInfoInteger(ACCOUNT_TRADE_MODE);
   const long mmode  = AccountInfoInteger(ACCOUNT_MARGIN_MODE);
   const long limit  = AccountInfoInteger(ACCOUNT_LIMIT_ORDERS);
   PrintFormat("LIMPROBE|ACCOUNT|login=%I64d|server=%s|trade_mode=%I64d|margin_mode=%I64d|limit_orders=%I64d|balance=%.2f|connected=%I64d|symbol_volume_limit=%.2f",
               login, AccountInfoString(ACCOUNT_SERVER), tmode, mmode, limit,
               AccountInfoDouble(ACCOUNT_BALANCE), TerminalInfoInteger(TERMINAL_CONNECTED),
               SymbolInfoDouble(InpSymbol, SYMBOL_VOLUME_LIMIT));
   PrintBook("start");
   bool ok = true;
   if(login != InpExpectLogin) {
      PrintFormat("LIMPROBE|REFUSE|login %I64d is not the expected %I64d", login, InpExpectLogin);
      ok = false;
   }
   if(tmode != ACCOUNT_TRADE_MODE_DEMO) {
      Print("LIMPROBE|REFUSE|not a demo account");
      ok = false;
   }
   if(mmode != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING) {
      Print("LIMPROBE|REFUSE|not a hedging account");
      ok = false;
   }
   if(!TerminalInfoInteger(TERMINAL_CONNECTED)) {
      Print("LIMPROBE|REFUSE|terminal not connected to the trade server");
      ok = false;
   }
   if(need_empty && (PositionsTotal() != 0 || OrdersTotal() != 0)) {
      Print("LIMPROBE|REFUSE|account is not empty");
      ok = false;
   }
   if(!SymbolSelect(InpSymbol, true)) {
      PrintFormat("LIMPROBE|REFUSE|symbol %s not available", InpSymbol);
      ok = false;
   }
   if(InpPositions < 0 || InpPositions > 60 || InpMaxPending < 1 || InpMaxPending > 300
      || InpPauseMs < 100) {
      Print("LIMPROBE|REFUSE|inputs out of range (positions 0-60, pending 1-300, pause >= 100 ms)");
      ok = false;
   }
   return ok;
}

//+------------------------------------------------------------------+
void LogResult(const string what, const int i, const bool sent, const ulong us)
{
   PrintFormat("LIMPROBE|%s|i=%d|ok=%s|retcode=%u|retcode_ext=%d|last_error=%d|comment=%s|duration_ms=%.1f|positions=%d|orders=%d|sum=%d",
               what, i, sent ? "true" : "false", g_trade.ResultRetcode(),
               g_trade.ResultRetcodeExternal(), GetLastError(),
               g_trade.ResultComment(), us / 1000.0,
               PositionsTotal(), OrdersTotal(), PositionsTotal() + OrdersTotal());
}

//+------------------------------------------------------------------+
bool RequestOk(const bool sent)
{
   const uint rc = g_trade.ResultRetcode();
   return sent && (rc == TRADE_RETCODE_DONE || rc == TRADE_RETCODE_PLACED
                   || rc == TRADE_RETCODE_DONE_PARTIAL);
}

//+------------------------------------------------------------------+
bool IsLimitCode(const uint rc)
{
   return rc == TRADE_RETCODE_LIMIT_ORDERS || rc == TRADE_RETCODE_LIMIT_POSITIONS;
}

//+------------------------------------------------------------------+
void Cleanup()
{
   for(int pass = 0; pass < 3; pass++) {
      for(int i = OrdersTotal() - 1; i >= 0; i--) {
         const ulong t = OrderGetTicket(i);
         if(t == 0 || (ulong)OrderGetInteger(ORDER_MAGIC) != PROBE_MAGIC)
            continue;
         if(!g_trade.OrderDelete(t))
            PrintFormat("LIMPROBE|CLEANUP|delete %I64u failed retcode=%u", t, g_trade.ResultRetcode());
         Sleep(InpPauseMs);
      }
      for(int i = PositionsTotal() - 1; i >= 0; i--) {
         const ulong t = PositionGetTicket(i);
         if(t == 0 || (ulong)PositionGetInteger(POSITION_MAGIC) != PROBE_MAGIC)
            continue;
         if(!g_trade.PositionClose(t))
            PrintFormat("LIMPROBE|CLEANUP|close %I64u failed retcode=%u", t, g_trade.ResultRetcode());
         Sleep(InpPauseMs);
      }
      if(CountOurs(true) == 0 && CountOurs(false) == 0)
         break;
      Sleep(2000);
   }
   PrintBook("after_cleanup");
   if(CountOurs(true) == 0 && CountOurs(false) == 0)
      Print("LIMPROBE|CLEANUP|DONE|nothing of ours left");
   else
      Print("LIMPROBE|CLEANUP|INCOMPLETE|run again with InpMode=2");
   PrintFormat("LIMPROBE|EMPTY|%s|positions=%d|orders=%d",
               (PositionsTotal() == 0 && OrdersTotal() == 0) ? "yes" : "NO",
               PositionsTotal(), OrdersTotal());
}

//+------------------------------------------------------------------+
void OnStart()
{
   PrintFormat("LIMPROBE|BEGIN|mode=%d|symbol=%s|positions=%d|max_pending=%d|pause_ms=%d",
               InpMode, InpSymbol, InpPositions, InpMaxPending, InpPauseMs);
   g_trade.SetExpertMagicNumber(PROBE_MAGIC);
   g_trade.SetDeviationInPoints(30);
   g_trade.SetTypeFillingBySymbol(InpSymbol);
   g_trade.SetAsyncMode(false);

   if(InpMode == 2) {
      if(AccountChecksPass(false))
         Cleanup();
      Print("LIMPROBE|END");
      return;
   }
   if(!AccountChecksPass(true)) {
      Print("LIMPROBE|END|refused");
      return;
   }
   if(InpMode != 1) {
      Print("LIMPROBE|DRY|checks pass; RUN would open the positions, place limits until refused, try one market BUY, then clean up");
      Print("LIMPROBE|END");
      return;
   }
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED)) {
      Print("LIMPROBE|REFUSE|algo trading is off (terminal button or script setting)");
      Print("LIMPROBE|END");
      return;
   }

   const int    digits = (int)SymbolInfoInteger(InpSymbol, SYMBOL_DIGITS);
   const double point  = SymbolInfoDouble(InpSymbol, SYMBOL_POINT);
   const double pip    = (digits == 3 || digits == 5) ? point * 10.0 : point;

   // 1) market positions
   int opened = 0;
   for(int i = 0; i < InpPositions && !IsStopped(); i++) {
      const ulong t0 = GetMicrosecondCount();
      const bool sent = g_trade.Buy(0.01, InpSymbol, 0.0, 0.0, 0.0, PROBE_COMMENT);
      const ulong us = GetMicrosecondCount() - t0;
      if(!RequestOk(sent)) {
         LogResult("POSITION_REFUSED", i, sent, us);
         break;
      }
      opened++;
      Sleep(InpPauseMs);
   }
   PrintFormat("LIMPROBE|POSITIONS|opened=%d", opened);
   PrintBook("after_positions");
   if(opened < InpPositions) {
      Print("LIMPROBE|ABORT|a market BUY was refused (see POSITION_REFUSED): no conclusion");
      Cleanup();
      Print("LIMPROBE|END");
      return;
   }

   // 2) pending BUY_LIMIT far below the market until the first refusal
   //    (RETURN + GTC, as the EA places its limits on IC: grind_engine.mqh 1321-1322)
   g_trade.SetTypeFilling(ORDER_FILLING_RETURN);
   int placed = 0;
   bool refused = false;
   bool other = false;
   bool retry_ok = false;
   for(int i = 0; i < InpMaxPending && !IsStopped(); i++) {
      MqlTick tick;
      if(!SymbolInfoTick(InpSymbol, tick) || tick.ask <= 0.0) {
         Print("LIMPROBE|ABORT|no tick");
         break;
      }
      const double price = NormalizeDouble(tick.ask - (300.0 + i) * pip, digits);
      const ulong t0 = GetMicrosecondCount();
      const bool sent = g_trade.BuyLimit(0.01, price, InpSymbol, 0.0, 0.0,
                                          ORDER_TIME_GTC, 0, PROBE_COMMENT);
      const ulong us = GetMicrosecondCount() - t0;
      if(!RequestOk(sent)) {
         if(!IsLimitCode(g_trade.ResultRetcode())) {
            LogResult("PENDING_OTHER_ABORT", i, sent, us);   // not a limit: no conclusion
            other = true;
            break;
         }
         LogResult("PENDING_REFUSED", i, sent, us);
         refused = true;
         // confirm once more after a second (same book)
         Sleep(1000);
         const double price2 = NormalizeDouble(tick.ask - (300.0 + i + 1) * pip, digits);
         const ulong t1 = GetMicrosecondCount();
         const bool sent2 = g_trade.BuyLimit(0.01, price2, InpSymbol, 0.0, 0.0,
                                              ORDER_TIME_GTC, 0, PROBE_COMMENT);
         LogResult("PENDING_RETRY", i + 1, sent2, GetMicrosecondCount() - t1);
         if(RequestOk(sent2)) {
            placed++;
            retry_ok = true;      // the first refusal was not a hard limit
         }
         break;
      }
      placed++;
      Sleep(InpPauseMs);
   }
   PrintFormat("LIMPROBE|PENDING|placed=%d|refused=%s|other_abort=%s", placed,
               refused ? "true" : "false", other ? "true" : "false");
   PrintBook("at_limit");

   // 3) one more market BUY with the book as it stands (only at a limit)
   g_trade.SetTypeFillingBySymbol(InpSymbol);
   if(refused && !retry_ok) {
      const ulong t0 = GetMicrosecondCount();
      const bool sent = g_trade.Buy(0.01, InpSymbol, 0.0, 0.0, 0.0, PROBE_COMMENT);
      LogResult("MARKET_AT_LIMIT", 0, sent, GetMicrosecondCount() - t0);
      Sleep(InpPauseMs);
   }

   PrintFormat("LIMPROBE|SUMMARY|limit_orders_prop=%I64d|positions_opened=%d|pending_placed=%d|refused=%s|retry_ok=%s|other_abort=%s",
               AccountInfoInteger(ACCOUNT_LIMIT_ORDERS), opened, placed,
               refused ? "true" : "false", retry_ok ? "true" : "false",
               other ? "true" : "false");

   // 4) clean up everything we placed
   Cleanup();
   Print("LIMPROBE|END");
}
