//+------------------------------------------------------------------+
//| grind_bidask_dump.mq5 -- READ-ONLY per-minute BID and ASK dump   |
//| Ejection study s9/s10 (docs/research/ejection-value-study.md):   |
//| M1 bars keep only the minute's minimum spread, so in a news or   |
//| rollover spike bid + bar spread understates the ask. This script |
//| builds each minute from the TICK history instead: bid OHLC, ask  |
//| OHLC, min and max spread, tick count. One linear pass per chunk  |
//| of ticks (CopyTicksRange COPY_TICKS_INFO, the EA's own call).    |
//| Places, modifies and deletes nothing; writes no GlobalVariables; |
//| safe beside live EAs (the grind_tick_probe.mq5 pattern). Times   |
//| are TRADE SERVER time; the header records server-minus-GMT.      |
//+------------------------------------------------------------------+
#property copyright "fxmatrix"
#property version   "1.00"
#property strict
#property script_show_inputs

input string InpSymbols    = "GBPUSD,EURUSD,EURGBP,AUDCAD,AUDCHF,AUDNZD,CADCHF,NZDCAD,NZDCHF";
input string InpFrom       = "2026.09.24 00:00";   // server time, inclusive
input string InpTo         = "";                   // server time; empty = now
input int    InpChunkHours = 6;                    // ticks read per CopyTicksRange call
input int    InpRetries    = 5;                    // retries per chunk while history syncs

//+------------------------------------------------------------------+
string BaTime(const datetime t)
{
   return TimeToString(t, TIME_DATE | TIME_MINUTES);
}

//+------------------------------------------------------------------+
// One minute being built.
struct BaMinute
{
   long   minute;          // server minute index (time_msc / 60000); -1 = none
   double bo, bh, bl, bc;  // bid
   double ao, ah, al, ac;  // ask
   double smin, smax;      // spread in price units
   int    n;               // ticks
};

//+------------------------------------------------------------------+
void BaReset(BaMinute &m)
{
   m.minute = -1;
   m.n = 0;
}

//+------------------------------------------------------------------+
void BaWrite(const int fh, const BaMinute &m, const int d, const double pt)
{
   if(m.minute < 0 || m.n == 0)
      return;
   const datetime t = (datetime)(m.minute * 60);
   FileWriteString(fh, StringFormat("%s,%I64d,%s,%s,%s,%s,%s,%s,%s,%s,%d,%d,%d\n",
                                    BaTime(t), (long)t,
                                    DoubleToString(m.bo, d), DoubleToString(m.bh, d),
                                    DoubleToString(m.bl, d), DoubleToString(m.bc, d),
                                    DoubleToString(m.ao, d), DoubleToString(m.ah, d),
                                    DoubleToString(m.al, d), DoubleToString(m.ac, d),
                                    (int)MathRound(m.smin / pt), (int)MathRound(m.smax / pt),
                                    m.n));
}

//+------------------------------------------------------------------+
void BaAdd(const int fh, BaMinute &m, const MqlTick &tk, const int d, const double pt,
           long &rows)
{
   const long minute = (long)(tk.time_msc / 60000);
   const double sp = tk.ask - tk.bid;
   if(minute != m.minute) {
      if(m.minute >= 0) {
         BaWrite(fh, m, d, pt);
         rows++;
      }
      m.minute = minute;
      m.bo = m.bh = m.bl = m.bc = tk.bid;
      m.ao = m.ah = m.al = m.ac = tk.ask;
      m.smin = m.smax = sp;
      m.n = 1;
      return;
   }
   if(tk.bid > m.bh) m.bh = tk.bid;
   if(tk.bid < m.bl) m.bl = tk.bid;
   if(tk.ask > m.ah) m.ah = tk.ask;
   if(tk.ask < m.al) m.al = tk.ask;
   if(sp < m.smin) m.smin = sp;
   if(sp > m.smax) m.smax = sp;
   m.bc = tk.bid;
   m.ac = tk.ask;
   m.n++;
}

//+------------------------------------------------------------------+
void BaSymbol(const string sym, const datetime from_t, const datetime to_t, const long offset_s)
{
   if(!SymbolSelect(sym, true)) {
      PrintFormat("BIDASK|%s|NO_SYMBOL|err=%d", sym, GetLastError());
      return;
   }
   const long login = AccountInfoInteger(ACCOUNT_LOGIN);
   const string fname = StringFormat("bidask_%I64d_%s.csv", login, sym);
   const int fh = FileOpen(fname, FILE_WRITE | FILE_TXT | FILE_ANSI);
   if(fh == INVALID_HANDLE) {
      PrintFormat("BIDASK|%s|FILE_OPEN_FAILED|file=%s|err=%d", sym, fname, GetLastError());
      return;
   }
   const int d = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
   const double pt = SymbolInfoDouble(sym, SYMBOL_POINT);
   FileWriteString(fh, StringFormat("# symbol=%s account=%I64d server=%s digits=%d point=%s "
                                    "server_minus_gmt_s=%I64d from=%s to=%s kind=bidask\n",
                                    sym, login, AccountInfoString(ACCOUNT_SERVER), d,
                                    DoubleToString(pt, 8), offset_s, BaTime(from_t), BaTime(to_t)));
   FileWriteString(fh, "time_server,time_unix_server,bid_open,bid_high,bid_low,bid_close,"
                       "ask_open,ask_high,ask_low,ask_close,spread_min_points,spread_max_points,ticks\n");

   BaMinute m;
   BaReset(m);
   long rows = 0, ticks = 0, bad = 0;
   const long chunk_ms = (long)InpChunkHours * 3600 * 1000;
   const long end_ms = (long)to_t * 1000;
   bool failed = false;
   for(long a = (long)from_t * 1000; a < end_ms; a += chunk_ms) {
      const long b = ((a + chunk_ms < end_ms) ? a + chunk_ms : end_ms) - 1;   // inclusive; no overlap
      MqlTick t[];
      int n = -1, err = 0;
      for(int attempt = 1; attempt <= InpRetries; attempt++) {
         ResetLastError();
         n = CopyTicksRange(sym, t, COPY_TICKS_INFO, (ulong)a, (ulong)b);
         err = GetLastError();
         if(n >= 0 && err == 0)
            break;
         Sleep(1000);
      }
      if(n < 0 || err != 0) {
         PrintFormat("BIDASK|%s|CHUNK_FAILED|from=%s|n=%d|err=%d", sym,
                     BaTime((datetime)(a / 1000)), n, err);
         failed = true;
         break;
      }
      for(int i = 0; i < n; i++) {
         if(t[i].bid <= 0.0 || t[i].ask <= 0.0 || t[i].ask < t[i].bid) {
            bad++;
            continue;
         }
         BaAdd(fh, m, t[i], d, pt, rows);
         ticks++;
      }
   }
   if(!failed && m.minute >= 0) {
      BaWrite(fh, m, d, pt);
      rows++;
   }
   FileClose(fh);
   if(failed) {
      FileDelete(fname);              // a partial file would mislead the replay
      PrintFormat("BIDASK|%s|DELETED_PARTIAL|file=%s", sym, fname);
      return;
   }
   PrintFormat("BIDASK|%s|minutes=%I64d|ticks=%I64d|bad_px=%I64d|file=%s", sym, rows, ticks, bad, fname);
}

//+------------------------------------------------------------------+
void OnStart()
{
   const datetime from_t = StringToTime(InpFrom);
   const datetime to_t = (InpTo == "") ? TimeTradeServer() : StringToTime(InpTo);
   const long offset_s = (long)(TimeTradeServer() - TimeGMT());
   if(from_t <= 0 || to_t <= from_t || InpChunkHours <= 0) {
      PrintFormat("BIDASK|BAD_RANGE|from=%s|to=%s|chunk_h=%d", InpFrom, InpTo, InpChunkHours);
      return;
   }
   PrintFormat("BIDASK|BEGIN|from=%s|to=%s|account=%I64d|server=%s|server_minus_gmt_s=%I64d",
               BaTime(from_t), BaTime(to_t), AccountInfoInteger(ACCOUNT_LOGIN),
               AccountInfoString(ACCOUNT_SERVER), offset_s);
   string syms[];
   const int k = StringSplit(InpSymbols, ',', syms);
   for(int i = 0; i < k; i++) {
      StringTrimLeft(syms[i]);
      StringTrimRight(syms[i]);
      if(syms[i] != "")
         BaSymbol(syms[i], from_t, to_t, offset_s);
   }
   Print("BIDASK|END");
}
