//+------------------------------------------------------------------+
//| grind_tick_probe.mq5 -- READ-ONLY tick-history probe (C63)       |
//| ADR-162 s15 precondition (GD6): does CopyTicksRange with         |
//| COPY_TICKS_INFO return ticks on this terminal (Wine box)?        |
//| Makes the EA's exact call (Grind_LatticeCopyTicks): same flags,  |
//| 'to' = SYMBOL_TIME_MSC, 'from' = to - InpHours. Places, modifies |
//| and deletes nothing; writes no GlobalVariables. Safe beside live |
//| EAs; works with the market closed.                               |
//| Tick times are TRADE SERVER time (GMT+3 on both brokers).        |
//+------------------------------------------------------------------+
#property copyright "fxmatrix"
#property version   "1.00"
#property strict
#property script_show_inputs

input string InpSymbols = "GBPUSD,EURUSD,EURGBP,AUDCAD,AUDCHF,AUDNZD,CADCHF,NZDCAD,NZDCHF";
input int    InpHours   = 24;
input int    InpCalls   = 2;   // repeat per symbol: cold vs warm timing

//+------------------------------------------------------------------+
string ProbeMsc(const long msc)
{
   return TimeToString((datetime)(msc / 1000), TIME_DATE | TIME_SECONDS)
          + StringFormat(".%03d", (int)(msc % 1000));
}

//+------------------------------------------------------------------+
void ProbeSymbol(const string sym)
{
   if(!SymbolSelect(sym, true)) {
      PrintFormat("TICKPROBE|%s|NO_SYMBOL|err=%d", sym, GetLastError());
      return;
   }
   const long to_msc = (long)SymbolInfoInteger(sym, SYMBOL_TIME_MSC);
   if(to_msc <= 0) {
      PrintFormat("TICKPROBE|%s|NO_LAST_TICK|to_msc=%I64d", sym, to_msc);
      return;
   }
   const long from_msc = to_msc - (long)InpHours * 3600 * 1000;

   for(int c = 1; c <= InpCalls; c++) {
      MqlTick t[];
      ResetLastError();
      const ulong t0 = GetMicrosecondCount();
      const int n = CopyTicksRange(sym, t, COPY_TICKS_INFO, (ulong)from_msc, (ulong)to_msc);
      const ulong us = GetMicrosecondCount() - t0;
      const int err = GetLastError();
      if(n <= 0) {
         PrintFormat("TICKPROBE|%s|call=%d|n=%d|err=%d|ms=%I64u|from=%s|to=%s",
                     sym, c, n, err, us / 1000, ProbeMsc(from_msc), ProbeMsc(to_msc));
         continue;
      }
      double min_ask = 0.0, max_bid = 0.0;
      int bad = 0;
      long max_gap_ms = 0;
      for(int i = 0; i < n; i++) {
         if(t[i].ask <= 0.0 || t[i].bid <= 0.0) {
            bad++;
            continue;
         }
         if(min_ask <= 0.0 || t[i].ask < min_ask)
            min_ask = t[i].ask;
         if(t[i].bid > max_bid)
            max_bid = t[i].bid;
         if(i > 0) {
            const long gap = (long)t[i].time_msc - (long)t[i - 1].time_msc;
            if(gap > max_gap_ms)
               max_gap_ms = gap;
         }
      }
      const int d = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
      PrintFormat("TICKPROBE|%s|call=%d|n=%d|err=%d|ms=%I64u|first=%s|last=%s"
                  "|min_ask=%s|max_bid=%s|bad_px=%d|max_gap_s=%I64d",
                  sym, c, n, err, us / 1000,
                  ProbeMsc((long)t[0].time_msc), ProbeMsc((long)t[n - 1].time_msc),
                  DoubleToString(min_ask, d), DoubleToString(max_bid, d),
                  bad, max_gap_ms / 1000);
   }
}

//+------------------------------------------------------------------+
void OnStart()
{
   PrintFormat("TICKPROBE|BEGIN|hours=%d|calls=%d|account=%I64d|server=%s",
               InpHours, InpCalls, AccountInfoInteger(ACCOUNT_LOGIN),
               AccountInfoString(ACCOUNT_SERVER));
   string syms[];
   const int k = StringSplit(InpSymbols, ',', syms);
   for(int i = 0; i < k; i++) {
      StringTrimLeft(syms[i]);
      StringTrimRight(syms[i]);
      if(syms[i] != "")
         ProbeSymbol(syms[i]);
   }
   Print("TICKPROBE|END");
}
