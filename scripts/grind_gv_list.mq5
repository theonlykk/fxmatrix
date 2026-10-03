//+------------------------------------------------------------------+
//| grind_gv_list.mq5 -- READ-ONLY list of the terminal's Global      |
//| Variables whose name contains InpContains (default "GRIND"), to   |
//| MQL5\Files\gv_list_<login>.csv: name, value, last write (server   |
//| time). Backlog C107: find the retired instances' leftovers before |
//| deleting anything BY EXACT NAME, by hand. Deletes, sets and       |
//| trades nothing; safe beside live EAs (GlobalVariableName/Get/Time |
//| only).                                                            |
//+------------------------------------------------------------------+
#property copyright "fxmatrix"
#property version   "1.00"
#property strict
#property script_show_inputs

input string InpContains = "GRIND";   // substring filter; "" lists every variable

//+------------------------------------------------------------------+
void OnStart()
{
   const long login = AccountInfoInteger(ACCOUNT_LOGIN);
   const string fname = StringFormat("gv_list_%I64d.csv", login);
   const int fh = FileOpen(fname, FILE_WRITE | FILE_TXT | FILE_ANSI);
   if(fh == INVALID_HANDLE) {
      PrintFormat("GVLIST|FILE_OPEN_FAILED|file=%s|err=%d", fname, GetLastError());
      return;
   }
   const int total = GlobalVariablesTotal();
   FileWriteString(fh, StringFormat("# account=%I64d server=%s total=%d filter=%s written=%s\n",
                                    login, AccountInfoString(ACCOUNT_SERVER), total, InpContains,
                                    TimeToString(TimeTradeServer(), TIME_DATE | TIME_SECONDS)));
   FileWriteString(fh, "name,value,last_write_server\n");
   int written = 0;
   for(int i = 0; i < total; i++) {
      const string name = GlobalVariableName(i);
      if(name == "")
         continue;
      if(InpContains != "" && StringFind(name, InpContains) < 0)
         continue;
      const double value = GlobalVariableGet(name);
      const datetime t = GlobalVariableTime(name);
      FileWriteString(fh, StringFormat("%s,%.10g,%s\n", name, value,
                                       TimeToString(t, TIME_DATE | TIME_SECONDS)));
      written++;
   }
   FileClose(fh);
   PrintFormat("GVLIST|account=%I64d|total=%d|written=%d|file=%s", login, total, written, fname);
}
