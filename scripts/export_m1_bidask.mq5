//+------------------------------------------------------------------+
//| export_m1_bidask.mq5 -- READ ONLY M1 bid/ask from tick history.   |
//| NO OrderSend / Modify / Delete / GlobalVariable writes.          |
//| Copy output from Terminal/Common/Files/<InpFolder>/ to data/.   |
//+------------------------------------------------------------------+
#property copyright "fxmatrix"
#property version   "1.00"
#property script_show_inputs
#property strict

input datetime InpFrom   = D'2026.09.10 00:00:00';   // broker time
input datetime InpTo     = D'2026.09.19 00:00:00';   // broker time
input string   InpFolder = "m1_bidask";

string EXPORT_SYMBOLS[] =
{
   "GBPUSD", "EURUSD", "EURGBP", "AUDCAD", "AUDCHF", "CADCHF", "NZDCAD", "AUDNZD"
};

//+------------------------------------------------------------------+
struct MinuteBar
{
   ulong    minute_msc;
   double   bid_open;
   double   bid_high;
   double   bid_low;
   double   bid_close;
   double   ask_open;
   double   ask_high;
   double   ask_low;
   double   ask_close;
   int      ticks;
};

//+------------------------------------------------------------------+
string FormatCsvDatetime(const datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return StringFormat("%04d-%02d-%02d %02d:%02d:%02d",
                       dt.year, dt.mon, dt.day, dt.hour, dt.min, dt.sec);
}

//+------------------------------------------------------------------+
bool EnsureOutputFolder()
{
   if(StringLen(InpFolder) == 0)
      return true;
   if(FolderCreate(InpFolder, FILE_COMMON))
      return true;
   const int err = GetLastError();
   if(err == 5019)
      return true;
   Print("export_m1_bidask: FolderCreate failed folder=", InpFolder, " err=", err);
   return false;
}

//+------------------------------------------------------------------+
string SymbolCsvPath(const string symbol)
{
   return InpFolder + "\\" + symbol + "_m1_bidask.csv";
}

//+------------------------------------------------------------------+
int FindMinuteIndex(const MinuteBar &bars[], const int count, const ulong minute_msc)
{
   for(int i = 0; i < count; i++) {
      if(bars[i].minute_msc == minute_msc)
         return i;
   }
   return -1;
}

//+------------------------------------------------------------------+
void ApplyTick(MinuteBar &bars[], int &count, const MqlTick &tick)
{
   if(tick.bid <= 0.0 || tick.ask <= 0.0)
      return;

   const ulong minute_msc = (tick.time_msc / 60000ULL) * 60000ULL;
   int idx = FindMinuteIndex(bars, count, minute_msc);
   if(idx < 0) {
      ArrayResize(bars, count + 1);
      idx = count;
      count++;
      bars[idx].minute_msc = minute_msc;
      bars[idx].bid_open = tick.bid;
      bars[idx].bid_high = tick.bid;
      bars[idx].bid_low = tick.bid;
      bars[idx].bid_close = tick.bid;
      bars[idx].ask_open = tick.ask;
      bars[idx].ask_high = tick.ask;
      bars[idx].ask_low = tick.ask;
      bars[idx].ask_close = tick.ask;
      bars[idx].ticks = 1;
      return;
   }

   if(tick.bid > bars[idx].bid_high)
      bars[idx].bid_high = tick.bid;
   if(tick.bid < bars[idx].bid_low)
      bars[idx].bid_low = tick.bid;
   bars[idx].bid_close = tick.bid;

   if(tick.ask > bars[idx].ask_high)
      bars[idx].ask_high = tick.ask;
   if(tick.ask < bars[idx].ask_low)
      bars[idx].ask_low = tick.ask;
   bars[idx].ask_close = tick.ask;
   bars[idx].ticks++;
}

//+------------------------------------------------------------------+
void SortBarsByMinute(MinuteBar &bars[], const int count)
{
   for(int i = 0; i < count - 1; i++) {
      for(int j = i + 1; j < count; j++) {
         if(bars[j].minute_msc < bars[i].minute_msc) {
            const MinuteBar tmp = bars[i];
            bars[i] = bars[j];
            bars[j] = tmp;
         }
      }
   }
}

//+------------------------------------------------------------------+
bool WriteSymbolCsv(const string symbol, MinuteBar &bars[], const int count)
{
   const string path = SymbolCsvPath(symbol);
   const int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   const int fh = FileOpen(path, FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_COMMON);
   if(fh == INVALID_HANDLE) {
      Print("export_m1_bidask: FileOpen failed symbol=", symbol,
            " path=", path, " err=", GetLastError());
      return false;
   }

   FileWriteString(fh,
      "time_broker,bid_open,bid_high,bid_low,bid_close,ask_open,ask_high,ask_low,ask_close,ticks\n");

   for(int i = 0; i < count; i++) {
      const datetime t = (datetime)(bars[i].minute_msc / 1000ULL);
      const string row = StringFormat("%s,%s,%s,%s,%s,%s,%s,%s,%s,%d\n",
         FormatCsvDatetime(t),
         DoubleToString(bars[i].bid_open, digits),
         DoubleToString(bars[i].bid_high, digits),
         DoubleToString(bars[i].bid_low, digits),
         DoubleToString(bars[i].bid_close, digits),
         DoubleToString(bars[i].ask_open, digits),
         DoubleToString(bars[i].ask_high, digits),
         DoubleToString(bars[i].ask_low, digits),
         DoubleToString(bars[i].ask_close, digits),
         bars[i].ticks);
      FileWriteString(fh, row);
   }

   FileClose(fh);
   return true;
}

//+------------------------------------------------------------------+
bool WriteSymbolsMeta()
{
   const string path = InpFolder + "\\symbols.csv";
   const int fh = FileOpen(path, FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_COMMON);
   if(fh == INVALID_HANDLE) {
      Print("export_m1_bidask: symbols.csv FileOpen failed err=", GetLastError());
      return false;
   }

   FileWriteString(fh, "symbol,digits,point,contract_size\n");
   const int n = ArraySize(EXPORT_SYMBOLS);
   for(int i = 0; i < n; i++) {
      const string sym = EXPORT_SYMBOLS[i];
      const int digits = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
      const double point = SymbolInfoDouble(sym, SYMBOL_POINT);
      const double contract = SymbolInfoDouble(sym, SYMBOL_TRADE_CONTRACT_SIZE);
      FileWriteString(fh, StringFormat("%s,%d,%s,%s\n",
                                       sym,
                                       digits,
                                       DoubleToString(point, digits + 1),
                                       DoubleToString(contract, 0)));
   }
   FileClose(fh);
   return true;
}

//+------------------------------------------------------------------+
bool ExportSymbol(const string symbol, int &total_ticks_out)
{
   total_ticks_out = 0;
   MinuteBar bars[];
   int bar_count = 0;

   datetime day = InpFrom;
   while(day < InpTo) {
      datetime day_end = day + 86400;
      if(day_end > InpTo)
         day_end = InpTo;

      const ulong from_msc = (ulong)day * 1000ULL;
      const ulong to_msc = (ulong)day_end * 1000ULL - 1ULL;

      MqlTick ticks[];
      const int copied = CopyTicksRange(symbol, ticks, COPY_TICKS_INFO, from_msc, to_msc);
      if(copied > 0) {
         total_ticks_out += copied;
         for(int i = 0; i < copied; i++)
            ApplyTick(bars, bar_count, ticks[i]);
      }

      day += 86400;
   }

   SortBarsByMinute(bars, bar_count);
   if(!WriteSymbolCsv(symbol, bars, bar_count))
      return false;

   string first_tb = "";
   string last_tb = "";
   if(bar_count > 0) {
      first_tb = FormatCsvDatetime((datetime)(bars[0].minute_msc / 1000ULL));
      last_tb = FormatCsvDatetime((datetime)(bars[bar_count - 1].minute_msc / 1000ULL));
   }

   Print("export_m1_bidask: symbol=", symbol,
         " rows=", bar_count,
         " first=", first_tb,
         " last=", last_tb,
         " ticks=", total_ticks_out);
   return true;
}

//+------------------------------------------------------------------+
void OnStart()
{
   Print("export_m1_bidask: START from=", TimeToString(InpFrom, TIME_DATE|TIME_SECONDS),
         " to=", TimeToString(InpTo, TIME_DATE|TIME_SECONDS),
         " folder=", InpFolder);

   if(!EnsureOutputFolder()) {
      Print("export_m1_bidask: abort -- output folder unavailable");
      return;
   }

   if(!WriteSymbolsMeta()) {
      Print("export_m1_bidask: abort -- symbols.csv failed");
      return;
   }

   const int n = ArraySize(EXPORT_SYMBOLS);
   for(int i = 0; i < n; i++) {
      const string sym = EXPORT_SYMBOLS[i];
      if(!SymbolSelect(sym, true)) {
         Print("export_m1_bidask: SymbolSelect failed symbol=", sym);
         continue;
      }
      int ticks = 0;
      if(!ExportSymbol(sym, ticks))
         Print("export_m1_bidask: export failed symbol=", sym);
   }

   Print("export_m1_bidask: DONE");
}
