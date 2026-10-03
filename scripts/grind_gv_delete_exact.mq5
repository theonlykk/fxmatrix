//+------------------------------------------------------------------+
//| grind_gv_delete_exact.mq5 -- delete Global Variables BY EXACT     |
//| NAME from a reviewed list (backlog C107). Never by prefix: each   |
//| line of MQL5\Files\<InpListFile> is one full name (lines starting |
//| with '#' and blank lines are skipped). InpDryRun=true (default)   |
//| only reports FOUND / MISSING per name; false deletes the FOUND    |
//| ones and reports DELETED / FAILED. Trades nothing; touches no     |
//| name that is not on the list.                                     |
//+------------------------------------------------------------------+
#property copyright "fxmatrix"
#property version   "1.00"
#property strict
#property script_show_inputs

input string InpListFile = "gv_delete.txt";
input bool   InpDryRun   = true;

//+------------------------------------------------------------------+
void OnStart()
{
   const int fh = FileOpen(InpListFile, FILE_READ | FILE_TXT | FILE_ANSI);
   if(fh == INVALID_HANDLE) {
      PrintFormat("GVDEL|LIST_OPEN_FAILED|file=%s|err=%d", InpListFile, GetLastError());
      return;
   }
   int listed = 0, found = 0, missing = 0, deleted = 0, failed = 0;
   while(!FileIsEnding(fh)) {
      string name = FileReadString(fh);
      StringTrimLeft(name);
      StringTrimRight(name);
      if(name == "" || StringGetCharacter(name, 0) == '#')
         continue;
      listed++;
      if(!GlobalVariableCheck(name)) {
         missing++;
         PrintFormat("GVDEL|MISSING|%s", name);
         continue;
      }
      found++;
      if(InpDryRun) {
         PrintFormat("GVDEL|FOUND|%s|value=%.10g", name, GlobalVariableGet(name));
         continue;
      }
      if(GlobalVariableDel(name)) {
         deleted++;
         PrintFormat("GVDEL|DELETED|%s", name);
      } else {
         failed++;
         PrintFormat("GVDEL|FAILED|%s|err=%d", name, GetLastError());
      }
   }
   FileClose(fh);
   PrintFormat("GVDEL|SUMMARY|dry_run=%s|listed=%d|found=%d|missing=%d|deleted=%d|failed=%d",
               InpDryRun ? "true" : "false", listed, found, missing, deleted, failed);
}
