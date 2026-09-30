//+------------------------------------------------------------------+
//| grind_history_dump.mq5 -- READ-ONLY dump of the account's DEALS  |
//| C83 (keep the trade history): the broker's own record of every   |
//| deal on this account since it opened -- including manual closes, |
//| broker liquidations and fills the EA never saw (C76) -- written  |
//| to MQL5\Files\history_<login>.csv. Places, modifies and deletes  |
//| nothing; writes no GlobalVariables; safe beside live EAs. Times  |
//| are TRADE SERVER time; the header records server-minus-GMT.      |
//+------------------------------------------------------------------+
#property copyright "fxmatrix"
#property version   "1.00"
#property strict
#property script_show_inputs

input string InpFrom = "2026.09.01 00:00";   // server time; history before it is skipped

//+------------------------------------------------------------------+
string HdCsv(const string s)
{
   // commas and quotes in comments would break the CSV: quote the field
   string t = s;
   StringReplace(t, "\"", "'");
   return "\"" + t + "\"";
}

//+------------------------------------------------------------------+
void OnStart()
{
   const datetime from_t = StringToTime(InpFrom);
   const datetime to_t = TimeTradeServer() + 86400;
   const long offset_s = (long)(TimeTradeServer() - TimeGMT());
   const long login = AccountInfoInteger(ACCOUNT_LOGIN);
   if(from_t <= 0) {
      PrintFormat("HISTDUMP|BAD_FROM|%s", InpFrom);
      return;
   }
   if(!HistorySelect(from_t, to_t)) {
      PrintFormat("HISTDUMP|SELECT_FAILED|err=%d", GetLastError());
      return;
   }
   const int n = HistoryDealsTotal();
   const string fname = StringFormat("history_%I64d.csv", login);
   const int fh = FileOpen(fname, FILE_WRITE | FILE_TXT | FILE_ANSI);
   if(fh == INVALID_HANDLE) {
      PrintFormat("HISTDUMP|FILE_OPEN_FAILED|file=%s|err=%d", fname, GetLastError());
      return;
   }
   FileWriteString(fh, StringFormat("# account=%I64d server=%s currency=%s server_minus_gmt_s=%I64d "
                                    "from=%s to=%s deals=%d balance=%s equity=%s\n",
                                    login, AccountInfoString(ACCOUNT_SERVER),
                                    AccountInfoString(ACCOUNT_CURRENCY), offset_s,
                                    TimeToString(from_t, TIME_DATE | TIME_MINUTES),
                                    TimeToString(to_t, TIME_DATE | TIME_MINUTES), n,
                                    DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2),
                                    DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2)));
   FileWriteString(fh, "deal,order,position,time_server,time_msc_server,type,entry,reason,magic,"
                       "symbol,volume,price,commission,swap,profit,fee,comment,external_id\n");
   int written = 0, bad = 0;
   for(int i = 0; i < n; i++) {
      const ulong tk = HistoryDealGetTicket(i);
      if(tk == 0) {
         bad++;
         continue;
      }
      const string sym = HistoryDealGetString(tk, DEAL_SYMBOL);
      int d = 5;
      if(sym != "")
         d = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
      FileWriteString(fh, StringFormat("%I64u,%I64d,%I64d,%s,%I64d,%d,%d,%d,%I64d,%s,%s,%s,%s,%s,%s,%s,%s,%s\n",
         tk,
         HistoryDealGetInteger(tk, DEAL_ORDER),
         HistoryDealGetInteger(tk, DEAL_POSITION_ID),
         TimeToString((datetime)HistoryDealGetInteger(tk, DEAL_TIME), TIME_DATE | TIME_SECONDS),
         HistoryDealGetInteger(tk, DEAL_TIME_MSC),
         (int)HistoryDealGetInteger(tk, DEAL_TYPE),
         (int)HistoryDealGetInteger(tk, DEAL_ENTRY),
         (int)HistoryDealGetInteger(tk, DEAL_REASON),
         HistoryDealGetInteger(tk, DEAL_MAGIC),
         sym,
         DoubleToString(HistoryDealGetDouble(tk, DEAL_VOLUME), 2),
         DoubleToString(HistoryDealGetDouble(tk, DEAL_PRICE), d),
         DoubleToString(HistoryDealGetDouble(tk, DEAL_COMMISSION), 2),
         DoubleToString(HistoryDealGetDouble(tk, DEAL_SWAP), 2),
         DoubleToString(HistoryDealGetDouble(tk, DEAL_PROFIT), 2),
         DoubleToString(HistoryDealGetDouble(tk, DEAL_FEE), 2),
         HdCsv(HistoryDealGetString(tk, DEAL_COMMENT)),
         HdCsv(HistoryDealGetString(tk, DEAL_EXTERNAL_ID))));
      written++;
   }
   FileClose(fh);
   PrintFormat("HISTDUMP|account=%I64d|deals=%d|written=%d|bad=%d|file=%s", login, n, written, bad, fname);
}
