//+------------------------------------------------------------------+
//| grind_tick_dump.mq5 -- READ-ONLY raw tick dump (bid, ask)        |
//| Replay calibration (docs/research/replay-calibration-eurusd.md   |
//| s4.1, s6 T0 / T0b): every tick CopyTicksRange returns for a      |
//| symbol, COPY_TICKS_INFO (the EA's own call in the lattice),      |
//| written as time_msc, bid, ask, flags. Places, modifies and       |
//| deletes nothing; writes no GlobalVariables; safe beside live EAs |
//| (the grind_bidask_dump.mq5 pattern). Times are TRADE SERVER time |
//| in the inputs and the file; the header records server - GMT.     |
//| InpProbeOnly=true writes no file: it prints the earliest tick    |
//| served at or after InpFrom and the first chunk's count (s4.1).   |
//+------------------------------------------------------------------+
#property copyright "fxmatrix"
#property version   "1.00"
#property strict
#property script_show_inputs

input string InpSymbols      = "EURUSD";
input string InpFrom         = "2026.10.01 06:30";   // server time, inclusive
input string InpTo           = "";                   // server time, exclusive; empty = now
input int    InpChunkMinutes = 60;                   // ticks read per CopyTicksRange call
input int    InpRetries      = 5;                    // retries per chunk while history syncs
input bool   InpProbeOnly    = true;                 // true: print the earliest tick only, no file
input string InpTag          = "";                   // added to the file name (e.g. t0b_a)

//+------------------------------------------------------------------+
string TdTime(const long msc)
{
   return TimeToString((datetime)(msc / 1000), TIME_DATE | TIME_SECONDS)
          + StringFormat(".%03d", (int)(msc % 1000));
}

//+------------------------------------------------------------------+
// One chunk [a, b] inclusive, with retries. Returns the tick count, or -1.
int TdCopy(const string sym, const long a, const long b, MqlTick &t[])
{
   int n = -1, err = 0;
   for(int attempt = 1; attempt <= InpRetries; attempt++) {
      ResetLastError();
      n = CopyTicksRange(sym, t, COPY_TICKS_INFO, (ulong)a, (ulong)b);
      err = GetLastError();
      if(n >= 0 && err == 0)
         return n;
      Sleep(1000);
   }
   PrintFormat("TICKS|%s|CHUNK_FAILED|from=%s|n=%d|err=%d", sym, TdTime(a), n, err);
   return -1;
}

//+------------------------------------------------------------------+
void TdProbe(const string sym, const long from_ms, const long to_ms, const long chunk_ms)
{
   MqlTick one[];
   ResetLastError();
   const int k = CopyTicks(sym, one, COPY_TICKS_INFO, (ulong)from_ms, 1);
   const int err = GetLastError();
   if(k >= 1)
      PrintFormat("TICKS|%s|PROBE|first_at_or_after=%s|asked_from=%s|gap_s=%I64d",
                  sym, TdTime(one[0].time_msc), TdTime(from_ms),
                  (one[0].time_msc - from_ms) / 1000);
   else
      PrintFormat("TICKS|%s|PROBE|first_at_or_after=NONE|k=%d|err=%d", sym, k, err);

   const long b = ((from_ms + chunk_ms < to_ms) ? from_ms + chunk_ms : to_ms) - 1;
   MqlTick t[];
   const int n = TdCopy(sym, from_ms, b, t);
   if(n > 0)
      PrintFormat("TICKS|%s|PROBE_CHUNK|from=%s|to=%s|ticks=%d|first=%s|last=%s",
                  sym, TdTime(from_ms), TdTime(b), n, TdTime(t[0].time_msc),
                  TdTime(t[n - 1].time_msc));
   else
      PrintFormat("TICKS|%s|PROBE_CHUNK|from=%s|to=%s|ticks=%d", sym, TdTime(from_ms),
                  TdTime(b), n);
}

//+------------------------------------------------------------------+
void TdSymbol(const string sym, const long from_ms, const long to_ms, const long chunk_ms,
              const long offset_s)
{
   if(!SymbolSelect(sym, true)) {
      PrintFormat("TICKS|%s|NO_SYMBOL|err=%d", sym, GetLastError());
      return;
   }
   if(InpProbeOnly) {
      TdProbe(sym, from_ms, to_ms, chunk_ms);
      return;
   }

   const long login = AccountInfoInteger(ACCOUNT_LOGIN);
   const string tag = (InpTag == "") ? "" : "_" + InpTag;
   const string fname = StringFormat("ticks_%I64d_%s%s.csv", login, sym, tag);
   const int fh = FileOpen(fname, FILE_WRITE | FILE_TXT | FILE_ANSI);
   if(fh == INVALID_HANDLE) {
      PrintFormat("TICKS|%s|FILE_OPEN_FAILED|file=%s|err=%d", sym, fname, GetLastError());
      return;
   }
   const int d = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
   FileWriteString(fh, StringFormat("# symbol=%s account=%I64d server=%s digits=%d "
                                    "server_minus_gmt_s=%I64d from=%s to=%s chunk_min=%d "
                                    "kind=ticks_info\n",
                                    sym, login, AccountInfoString(ACCOUNT_SERVER), d,
                                    offset_s, TdTime(from_ms), TdTime(to_ms),
                                    InpChunkMinutes));
   FileWriteString(fh, "time_msc_server,bid,ask,flags\n");

   long ticks = 0, bad = 0, back = 0, chunks = 0, empty_weekday = 0;
   long first_ms = 0, last_ms = 0;
   bool failed = false;
   for(long a = from_ms; a < to_ms; a += chunk_ms) {
      const long b = ((a + chunk_ms < to_ms) ? a + chunk_ms : to_ms) - 1;   // inclusive; no overlap
      MqlTick t[];
      const int n = TdCopy(sym, a, b, t);
      if(n < 0) {
         failed = true;
         break;
      }
      chunks++;
      if(n == 0) {
         MqlDateTime dt;
         TimeToStruct((datetime)(a / 1000), dt);
         if(dt.day_of_week >= 1 && dt.day_of_week <= 5) {
            empty_weekday++;
            if(empty_weekday <= 20)
               PrintFormat("TICKS|%s|EMPTY_WEEKDAY_CHUNK|from=%s", sym, TdTime(a));
         }
         continue;
      }
      string buf = "";
      int lines = 0;
      for(int i = 0; i < n; i++) {
         if(t[i].bid <= 0.0 || t[i].ask <= 0.0 || t[i].ask < t[i].bid) {
            bad++;
            continue;
         }
         if(last_ms > 0 && t[i].time_msc < last_ms)
            back++;
         if(first_ms == 0)
            first_ms = t[i].time_msc;
         last_ms = t[i].time_msc;
         buf += StringFormat("%I64d,%s,%s,%u\n", t[i].time_msc,
                             DoubleToString(t[i].bid, d), DoubleToString(t[i].ask, d),
                             t[i].flags);
         ticks++;
         lines++;
         if(lines >= 2000) {
            FileWriteString(fh, buf);
            buf = "";
            lines = 0;
         }
      }
      if(lines > 0)
         FileWriteString(fh, buf);
   }
   FileClose(fh);
   if(failed) {
      FileDelete(fname);              // a partial file would mislead the replay
      PrintFormat("TICKS|%s|DELETED_PARTIAL|file=%s", sym, fname);
      return;
   }
   PrintFormat("TICKS|%s|ticks=%I64d|bad_px=%I64d|time_back=%I64d|chunks=%I64d|"
               "empty_weekday_chunks=%I64d|first=%s|last=%s|file=%s",
               sym, ticks, bad, back, chunks, empty_weekday,
               (first_ms > 0 ? TdTime(first_ms) : "-"), (last_ms > 0 ? TdTime(last_ms) : "-"),
               fname);
}

//+------------------------------------------------------------------+
void OnStart()
{
   const datetime from_t = StringToTime(InpFrom);
   const datetime to_t = (InpTo == "") ? TimeTradeServer() : StringToTime(InpTo);
   const long offset_s = (long)(TimeTradeServer() - TimeGMT());
   if(from_t <= 0 || to_t <= from_t || InpChunkMinutes <= 0 || InpRetries <= 0) {
      PrintFormat("TICKS|BAD_RANGE|from=%s|to=%s|chunk_min=%d|retries=%d",
                  InpFrom, InpTo, InpChunkMinutes, InpRetries);
      return;
   }
   const long from_ms = (long)from_t * 1000;
   const long to_ms = (long)to_t * 1000;
   const long chunk_ms = (long)InpChunkMinutes * 60 * 1000;
   PrintFormat("TICKS|BEGIN|probe_only=%s|from=%s|to=%s|account=%I64d|server=%s|"
               "server_minus_gmt_s=%I64d",
               InpProbeOnly ? "true" : "false", TdTime(from_ms), TdTime(to_ms),
               AccountInfoInteger(ACCOUNT_LOGIN), AccountInfoString(ACCOUNT_SERVER), offset_s);
   string syms[];
   const int k = StringSplit(InpSymbols, ',', syms);
   for(int i = 0; i < k; i++) {
      StringTrimLeft(syms[i]);
      StringTrimRight(syms[i]);
      if(syms[i] != "")
         TdSymbol(syms[i], from_ms, to_ms, chunk_ms, offset_s);
   }
   Print("TICKS|END");
}
//+------------------------------------------------------------------+
