//+------------------------------------------------------------------+
//| grind_deal_probe.mq5 -- READ-ONLY deal-history probe (ADR-164 P1) |
//| Lists every deal of InpSymbol in [InpFrom, InpTo] (server time)   |
//| read by ticket from the HistorySelect list (no HistoryDealSelect) |
//| then checks A10: does one HistoryDealSelect replace the list?     |
//| Places, modifies and deletes nothing; writes no GlobalVariables   |
//| and no files. Safe beside live EAs (grind_bar_dump pattern).      |
//+------------------------------------------------------------------+
#property copyright "fxmatrix"
#property version   "1.00"
#property script_show_inputs

input string InpSymbol = "GBPUSD";
input string InpFrom   = "2026.09.28 19:25";   // server time
input string InpTo     = "2026.09.28 19:30";   // server time

//+------------------------------------------------------------------+
string ProbeEntry(const long e)
{
   if(e == DEAL_ENTRY_IN)     return "IN";
   if(e == DEAL_ENTRY_OUT)    return "OUT";
   if(e == DEAL_ENTRY_INOUT)  return "INOUT";
   if(e == DEAL_ENTRY_OUT_BY) return "OUT_BY";
   return "?";
}

//+------------------------------------------------------------------+
void OnStart()
{
   const datetime from_t = StringToTime(InpFrom);
   const datetime to_t = StringToTime(InpTo);
   if(from_t <= 0 || to_t <= from_t) {
      PrintFormat("DEALPROBE|BAD_RANGE|from=%s|to=%s", InpFrom, InpTo);
      return;
   }
   ResetLastError();
   if(!HistorySelect(from_t, to_t)) {
      PrintFormat("DEALPROBE|SELECT_FAILED|err=%d", GetLastError());
      return;
   }
   const int total = HistoryDealsTotal();
   PrintFormat("DEALPROBE|BEGIN|account=%I64d|symbol=%s|from=%s|to=%s|deals_all_symbols=%d",
               AccountInfoInteger(ACCOUNT_LOGIN), InpSymbol, InpFrom, InpTo, total);

   // snapshot the tickets first (ADR-164 D1), then read by ticket
   ulong tickets[];
   ArrayResize(tickets, total);
   for(int i = 0; i < total; i++)
      tickets[i] = HistoryDealGetTicket(i);

   int listed = 0;
   ulong first_ticket = 0;
   for(int i = 0; i < total; i++) {
      const ulong t = tickets[i];
      if(t == 0)
         continue;
      if(HistoryDealGetString(t, DEAL_SYMBOL) != InpSymbol)
         continue;
      if(first_ticket == 0)
         first_ticket = t;
      PrintFormat("DEALPROBE|DEAL|ticket=%I64u|order=%I64u|position=%I64u|entry=%s|time_msc=%I64d|price=%s|magic=%I64d|comment=%s",
                  t,
                  (ulong)HistoryDealGetInteger(t, DEAL_ORDER),
                  (ulong)HistoryDealGetInteger(t, DEAL_POSITION_ID),
                  ProbeEntry(HistoryDealGetInteger(t, DEAL_ENTRY)),
                  HistoryDealGetInteger(t, DEAL_TIME_MSC),
                  DoubleToString(HistoryDealGetDouble(t, DEAL_PRICE),
                                 (int)SymbolInfoInteger(InpSymbol, SYMBOL_DIGITS)),
                  HistoryDealGetInteger(t, DEAL_MAGIC),
                  HistoryDealGetString(t, DEAL_COMMENT));
      listed++;
   }
   PrintFormat("DEALPROBE|LISTED|n=%d", listed);

   // A10: one HistoryDealSelect, then count the list again
   if(first_ticket != 0) {
      const int before = HistoryDealsTotal();
      const bool ok = HistoryDealSelect(first_ticket);
      const int after = HistoryDealsTotal();
      PrintFormat("DEALPROBE|A10|select_ok=%s|total_before=%d|total_after=%d",
                  ok ? "true" : "false", before, after);
   }
   Print("DEALPROBE|END");
}
