//+------------------------------------------------------------------+
//| dump_deals_range.mq5 -- READ ONLY bulk deal history CSV dumper.   |
//| Extends pull_deal_t4.mq5 conventions; adds DEAL_PROFIT/commission.|
//| Run on the desktop terminal logged into live account 1514432484;  |
//| copy CSV from MQL5/Files to d:\fxmatrix\data\local\ (gitignored).|
//| NO OrderSend / Modify / Delete — analysis export only.          |
//+------------------------------------------------------------------+
#property script_show_inputs
#property strict

input datetime InpFrom = 0;   // 0 = 60 calendar days back from InpTo
input datetime InpTo   = 0;   // 0 = now

string EntryStr(const long e)
{
   return e==DEAL_ENTRY_IN     ? "IN"
        : e==DEAL_ENTRY_OUT    ? "OUT"
        : e==DEAL_ENTRY_OUT_BY ? "OUT_BY"
        : e==DEAL_ENTRY_INOUT  ? "INOUT"
        : "UNKNOWN";
}

string TypeStr(const long t)
{
   return t==DEAL_TYPE_BUY  ? "buy"
        : t==DEAL_TYPE_SELL ? "sell"
        : "unknown";
}

string CsvEscape(string s)
{
   StringReplace(s, "\"", "\"\"");
   if(StringFind(s, ",") >= 0 || StringFind(s, "\"") >= 0 || StringFind(s, "\n") >= 0)
      return "\"" + s + "\"";
   return s;
}

void OnStart()
{
   datetime to   = (InpTo > 0 ? InpTo : TimeCurrent());
   datetime from = (InpFrom > 0 ? InpFrom : (to - 60 * 86400));

   if(!HistorySelect(from, to)) {
      Print("dump_deals_range: HistorySelect failed for range ",
            TimeToString(from, TIME_DATE|TIME_SECONDS), " .. ",
            TimeToString(to, TIME_DATE|TIME_SECONDS));
      return;
   }

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   const string out_name = StringFormat("deals_dump_%04d%02d%02d_%02d%02d.csv",
                                        dt.year, dt.mon, dt.day, dt.hour, dt.min);

   const int fh = FileOpen(out_name, FILE_WRITE|FILE_CSV|FILE_ANSI, ',');
   if(fh == INVALID_HANDLE) {
      Print("dump_deals_range: FileOpen failed err=", GetLastError(), " name=", out_name);
      return;
   }

   FileWrite(fh,
             "deal_ticket", "time", "symbol", "magic", "entry", "type",
             "volume", "price", "profit", "swap", "commission",
             "position_id", "order", "reason", "comment");

   const int total = HistoryDealsTotal();
   datetime t_min = 0;
   datetime t_max = 0;

   for(int i = 0; i < total; i++) {
      const ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0)
         continue;

      const datetime tm = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
      if(t_min == 0 || tm < t_min) t_min = tm;
      if(t_max == 0 || tm > t_max) t_max = tm;

      const string sym = HistoryDealGetString(ticket, DEAL_SYMBOL);
      const int digits = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);

      FileWrite(fh,
                (string)ticket,
                TimeToString(tm, TIME_DATE|TIME_SECONDS),
                sym,
                (string)HistoryDealGetInteger(ticket, DEAL_MAGIC),
                EntryStr(HistoryDealGetInteger(ticket, DEAL_ENTRY)),
                TypeStr(HistoryDealGetInteger(ticket, DEAL_TYPE)),
                DoubleToString(HistoryDealGetDouble(ticket, DEAL_VOLUME), 2),
                DoubleToString(HistoryDealGetDouble(ticket, DEAL_PRICE), digits),
                DoubleToString(HistoryDealGetDouble(ticket, DEAL_PROFIT), 2),
                DoubleToString(HistoryDealGetDouble(ticket, DEAL_SWAP), 2),
                DoubleToString(HistoryDealGetDouble(ticket, DEAL_COMMISSION), 2),
                (string)HistoryDealGetInteger(ticket, DEAL_POSITION_ID),
                (string)HistoryDealGetInteger(ticket, DEAL_ORDER),
                (string)HistoryDealGetInteger(ticket, DEAL_REASON),
                CsvEscape(HistoryDealGetString(ticket, DEAL_COMMENT)));
   }

   FileClose(fh);

   PrintFormat("dump_deals_range: wrote %d deals to MQL5/Files/%s | range %s .. %s",
               total, out_name,
               TimeToString(t_min, TIME_DATE|TIME_SECONDS),
               TimeToString(t_max, TIME_DATE|TIME_SECONDS));
   Print("Copy to d:\\fxmatrix\\data\\local\\ for signal_vs_dumb_ab.ipynb (do not commit CSV).");
}
