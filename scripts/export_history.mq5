//+------------------------------------------------------------------+
//| export_history.mq5 — READ ONLY M5 bar history CSV exporter.       |
//| Emits comma-separated files matching scripts/load_mt5_csv format: |
//|   datetime,OPEN,HIGH,LOW,CLOSE,SPREAD                             |
//| NO OrderSend / Modify / Delete / GlobalVariable writes.           |
//| Copy output from MQL5/Files/<InpOutputFolder>/ to data/ (local). |
//+------------------------------------------------------------------+
#property copyright "fxmatrix"
#property version   "1.00"
#property script_show_inputs
#property strict

// Ring pairs (8) + conversion series (5). Edit here before running.
string EXPORT_SYMBOLS[] =
{
   "EURUSD", "USDCAD", "NZDCAD", "AUDNZD", "AUDJPY", "CHFJPY", "GBPCHF", "EURGBP",
   "GBPUSD", "USDJPY", "USDCHF", "NZDUSD", "AUDUSD"
};

input datetime       InpStart         = D'2015.01.01 00:00:00';
input ENUM_TIMEFRAMES InpTimeframe    = PERIOD_M5;
input string         InpOutputFolder = "ring_m5";
input int            InpChunkBars    = 50000;

//+------------------------------------------------------------------+
string FormatCsvDatetime(const datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return StringFormat("%04d-%02d-%02d %02d:%02d:%02d",
                       dt.year, dt.mon, dt.day, dt.hour, dt.min, dt.sec);
}

//+------------------------------------------------------------------+
string OutputRelativePath(const string symbol)
{
   return InpOutputFolder + "\\" + symbol + "_m5.csv";
}

//+------------------------------------------------------------------+
bool EnsureOutputFolder()
{
   if(StringLen(InpOutputFolder) == 0)
      return true;
   if(FolderCreate(InpOutputFolder, FILE_COMMON))
      return true;
   const int err = GetLastError();
   if(err == 5019) // already exists
      return true;
   Print("export_history: FolderCreate failed folder=", InpOutputFolder,
         " err=", err);
   return false;
}

//+------------------------------------------------------------------+
int MergeRatesAsc(MqlRates &dest[], const MqlRates &src[], const int src_count)
{
   if(src_count <= 0)
      return ArraySize(dest);

   const int dest_count = ArraySize(dest);
   MqlRates merged[];
   ArrayResize(merged, dest_count + src_count);

   for(int i = 0; i < src_count; i++)
      merged[i] = src[i];
   for(int i = 0; i < dest_count; i++)
      merged[src_count + i] = dest[i];

   ArrayResize(dest, dest_count + src_count);
   ArrayCopy(dest, merged);
   return ArraySize(dest);
}

//+------------------------------------------------------------------+
int FilterRatesWindow(MqlRates &rates[],
                      const datetime start_time,
                      const datetime end_time)
{
   const int n = ArraySize(rates);
   if(n <= 0)
      return 0;

   MqlRates kept[];
   int write = 0;
   for(int i = 0; i < n; i++) {
      if(rates[i].time < start_time)
         continue;
      if(end_time > 0 && rates[i].time > end_time)
         continue;
      ArrayResize(kept, write + 1);
      kept[write++] = rates[i];
   }

   ArrayResize(rates, write);
   if(write > 0)
      ArrayCopy(rates, kept);
   return write;
}

//+------------------------------------------------------------------+
int DedupeRatesByTime(MqlRates &rates[])
{
   const int n = ArraySize(rates);
   if(n <= 1)
      return n;

   for(int i = 0; i < n - 1; i++) {
      for(int j = i + 1; j < n; j++) {
         if(rates[j].time < rates[i].time) {
            const MqlRates tmp = rates[i];
            rates[i] = rates[j];
            rates[j] = tmp;
         }
      }
   }

   int write = 0;
   for(int i = 0; i < n; i++) {
      if(write > 0 && rates[i].time == rates[write - 1].time)
         continue;
      if(write != i)
         rates[write] = rates[i];
      write++;
   }
   ArrayResize(rates, write);
   return write;
}

//+------------------------------------------------------------------+
bool CollectRatesChunked(const string symbol,
                         const ENUM_TIMEFRAMES tf,
                         const datetime start_time,
                         const datetime end_time,
                         MqlRates &out_rates[],
                         string &status_out)
{
   ArrayResize(out_rates, 0);
   status_out = "";

   int pos = 0;
   datetime prev_earliest = 0;
   const int chunk = (InpChunkBars > 0 ? InpChunkBars : 50000);

   while(true) {
      MqlRates chunk_rates[];
      const int copied = CopyRates(symbol, tf, pos, chunk, chunk_rates);
      if(copied <= 0) {
         status_out = StringFormat("CopyRates exhausted at pos=%d copied=%d", pos, copied);
         break;
      }

      const datetime chunk_earliest = chunk_rates[0].time;
      const datetime chunk_latest = chunk_rates[copied - 1].time;

      MergeRatesAsc(out_rates, chunk_rates, copied);

      if(chunk_earliest <= start_time) {
         status_out = StringFormat("reached start at pos=%d earliest=%s",
                                   pos, TimeToString(chunk_earliest, TIME_DATE|TIME_SECONDS));
         break;
      }

      if(copied < chunk) {
         status_out = StringFormat("partial final chunk copied=%d earliest=%s",
                                   copied, TimeToString(chunk_earliest, TIME_DATE|TIME_SECONDS));
         break;
      }

      if(prev_earliest > 0 && chunk_earliest >= prev_earliest) {
         status_out = StringFormat("no backward progress at pos=%d earliest=%s prev=%s",
                                   pos,
                                   TimeToString(chunk_earliest, TIME_DATE|TIME_SECONDS),
                                   TimeToString(prev_earliest, TIME_DATE|TIME_SECONDS));
         break;
      }

      prev_earliest = chunk_earliest;
      pos += copied;
   }

   const int filtered = FilterRatesWindow(out_rates, start_time, end_time);
   DedupeRatesByTime(out_rates);
   return (filtered > 0);
}

//+------------------------------------------------------------------+
bool WriteRatesCsv(const string symbol,
                   const MqlRates &rates[],
                   const int count,
                   string &out_path)
{
   out_path = OutputRelativePath(symbol);
   const int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);

   const int fh = FileOpen(out_path, FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_COMMON);
   if(fh == INVALID_HANDLE) {
      Print("export_history: FileOpen failed symbol=", symbol,
            " path=", out_path, " err=", GetLastError());
      return false;
   }

   FileWriteString(fh, "datetime,OPEN,HIGH,LOW,CLOSE,SPREAD\n");

   for(int i = 0; i < count; i++) {
      const string row = StringFormat("%s,%s,%s,%s,%s,%d\n",
                                      FormatCsvDatetime(rates[i].time),
                                      DoubleToString(rates[i].open, digits),
                                      DoubleToString(rates[i].high, digits),
                                      DoubleToString(rates[i].low, digits),
                                      DoubleToString(rates[i].close, digits),
                                      rates[i].spread);
      FileWriteString(fh, row);
   }

   FileClose(fh);
   return true;
}

//+------------------------------------------------------------------+
void OnStart()
{
   const datetime end_time = TimeCurrent();
   const int sym_count = ArraySize(EXPORT_SYMBOLS);

   Print("export_history: START symbols=", sym_count,
         " start=", TimeToString(InpStart, TIME_DATE|TIME_SECONDS),
         " end=", TimeToString(end_time, TIME_DATE|TIME_SECONDS),
         " tf=", EnumToString(InpTimeframe),
         " chunk=", InpChunkBars,
         " folder=", InpOutputFolder);

   if(!EnsureOutputFolder()) {
      Print("export_history: abort — output folder unavailable");
      return;
   }

   string short_symbols[];
   int short_count = 0;

   for(int i = 0; i < sym_count; i++) {
      const string symbol = EXPORT_SYMBOLS[i];
      Print("export_history: progress ", i + 1, "/", sym_count, " symbol=", symbol);

      ResetLastError();
      if(!SymbolSelect(symbol, true)) {
         Print("export_history: SKIP symbol=", symbol,
               " — SymbolSelect failed err=", GetLastError());
         continue;
      }

      MqlRates rates[];
      string collect_status = "";
      const bool have_rates = CollectRatesChunked(symbol,
                                                InpTimeframe,
                                                InpStart,
                                                end_time,
                                                rates,
                                                collect_status);
      const int bar_count = ArraySize(rates);

      if(!have_rates || bar_count <= 0) {
         Print("export_history: NO DATA symbol=", symbol,
               " status=", collect_status);
         continue;
      }

      string out_path = "";
      if(!WriteRatesCsv(symbol, rates, bar_count, out_path)) {
         Print("export_history: WRITE FAILED symbol=", symbol);
         continue;
      }

      const datetime first_dt = rates[0].time;
      const datetime last_dt = rates[bar_count - 1].time;
      const string full_path = TerminalInfoString(TERMINAL_COMMONDATA_PATH)
                             + "\\Files\\" + out_path;

      PrintFormat("export_history: %s, bars=%d, first=%s, last=%s, path=%s",
                  symbol,
                  bar_count,
                  TimeToString(first_dt, TIME_DATE|TIME_SECONDS),
                  TimeToString(last_dt, TIME_DATE|TIME_SECONDS),
                  full_path);

      if(first_dt > InpStart) {
         ArrayResize(short_symbols, short_count + 1);
         short_symbols[short_count++] = symbol;
      }

      if(StringLen(collect_status) > 0)
         Print("export_history: collect note symbol=", symbol, " ", collect_status);
   }

   // Symbols left selected in Market Watch — required for CopyRates and harmless
   // for attached EAs; we do not deselect after export.
   Print("export_history: symbols remain selected in Market Watch after export");

   if(short_count == 0) {
      Print("export_history: SUMMARY all symbols reached requested start ",
            TimeToString(InpStart, TIME_DATE|TIME_SECONDS));
   } else {
      string listed = short_symbols[0];
      for(int j = 1; j < short_count; j++)
         listed += ", " + short_symbols[j];
      Print("export_history: SUMMARY short history (first bar later than requested start): ",
            listed);
   }

   Print("export_history: DONE");
}
