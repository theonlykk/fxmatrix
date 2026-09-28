//+------------------------------------------------------------------+
//| grind_bar_dump.mq5 -- READ-ONLY M1 bar dump (ejection study)     |
//| docs/research/ejection-value-study.md s3 (C16 revived, 28 Sep).  |
//| Writes one CSV per symbol to MQL5\Files: M1 OHLC (bid) and the   |
//| bar spread in points, for [InpFrom, InpTo]. Places, modifies and |
//| deletes nothing; writes no GlobalVariables. Safe beside live EAs |
//| (the grind_tick_probe.mq5 pattern). Bar times are TRADE SERVER   |
//| time; the header records the server-minus-GMT offset.            |
//+------------------------------------------------------------------+
#property copyright "fxmatrix"
#property version   "1.00"
#property strict
#property script_show_inputs

input string InpSymbols = "GBPUSD,EURUSD,EURGBP,AUDCAD,AUDCHF,AUDNZD,CADCHF,NZDCAD,NZDCHF";
input string InpFrom    = "2026.09.27 00:00";   // server time, inclusive
input string InpTo      = "";                   // server time; empty = now
input int    InpRetries = 3;                    // CopyRates retries while history syncs

//+------------------------------------------------------------------+
string BarDumpTime(const datetime t)
{
   return TimeToString(t, TIME_DATE | TIME_MINUTES);
}

//+------------------------------------------------------------------+
void BarDumpSymbol(const string sym, const datetime from_t, const datetime to_t,
                   const long offset_s)
{
   if(!SymbolSelect(sym, true)) {
      PrintFormat("BARDUMP|%s|NO_SYMBOL|err=%d", sym, GetLastError());
      return;
   }
   MqlRates r[];
   int n = -1;
   int err = 0;
   for(int attempt = 1; attempt <= InpRetries; attempt++) {
      ResetLastError();
      n = CopyRates(sym, PERIOD_M1, from_t, to_t, r);
      err = GetLastError();
      if(n > 0)
         break;
      Sleep(1000);
   }
   if(n <= 0) {
      PrintFormat("BARDUMP|%s|NO_BARS|n=%d|err=%d", sym, n, err);
      return;
   }

   const long login = AccountInfoInteger(ACCOUNT_LOGIN);
   const string fname = StringFormat("bars_%I64d_%s.csv", login, sym);
   const int fh = FileOpen(fname, FILE_WRITE | FILE_TXT | FILE_ANSI);
   if(fh == INVALID_HANDLE) {
      PrintFormat("BARDUMP|%s|FILE_OPEN_FAILED|file=%s|err=%d", sym, fname, GetLastError());
      return;
   }
   const int d = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
   const double pt = SymbolInfoDouble(sym, SYMBOL_POINT);
   FileWriteString(fh, StringFormat("# symbol=%s account=%I64d server=%s digits=%d point=%s "
                                    "server_minus_gmt_s=%I64d from=%s to=%s\n",
                                    sym, login, AccountInfoString(ACCOUNT_SERVER), d,
                                    DoubleToString(pt, 8), offset_s,
                                    BarDumpTime(from_t), BarDumpTime(to_t)));
   FileWriteString(fh, "time_server,time_unix_server,open,high,low,close,spread_points,tick_volume\n");
   for(int i = 0; i < n; i++) {
      FileWriteString(fh, StringFormat("%s,%I64d,%s,%s,%s,%s,%d,%I64d\n",
                                       BarDumpTime(r[i].time), (long)r[i].time,
                                       DoubleToString(r[i].open, d),
                                       DoubleToString(r[i].high, d),
                                       DoubleToString(r[i].low, d),
                                       DoubleToString(r[i].close, d),
                                       r[i].spread, (long)r[i].tick_volume));
   }
   FileClose(fh);
   PrintFormat("BARDUMP|%s|n=%d|first=%s|last=%s|file=%s",
               sym, n, BarDumpTime(r[0].time), BarDumpTime(r[n - 1].time), fname);
}

//+------------------------------------------------------------------+
void OnStart()
{
   const datetime from_t = StringToTime(InpFrom);
   const datetime to_t = (InpTo == "") ? TimeTradeServer() : StringToTime(InpTo);
   const long offset_s = (long)(TimeTradeServer() - TimeGMT());
   if(from_t <= 0 || to_t <= from_t) {
      PrintFormat("BARDUMP|BAD_RANGE|from=%s|to=%s", InpFrom, InpTo);
      return;
   }
   PrintFormat("BARDUMP|BEGIN|from=%s|to=%s|account=%I64d|server=%s|server_minus_gmt_s=%I64d",
               BarDumpTime(from_t), BarDumpTime(to_t), AccountInfoInteger(ACCOUNT_LOGIN),
               AccountInfoString(ACCOUNT_SERVER), offset_s);
   string syms[];
   const int k = StringSplit(InpSymbols, ',', syms);
   for(int i = 0; i < k; i++) {
      StringTrimLeft(syms[i]);
      StringTrimRight(syms[i]);
      if(syms[i] != "")
         BarDumpSymbol(syms[i], from_t, to_t, offset_s);
   }
   Print("BARDUMP|END");
}
