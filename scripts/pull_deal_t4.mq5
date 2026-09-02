//+------------------------------------------------------------------+
//| pull_deal_t4.mq5 -- READ ONLY. Dumps one deal's / position's      |
//| fields for the T-4 empirical gate. No OrderSend, no trading, no    |
//| state change. Must run on the terminal logged into the account    |
//| that holds the deal (account 1514432484 -- the VPS live terminal; |
//| the desktop terminal is not on the live account and will NOT have  |
//| this history).                                                     |
//+------------------------------------------------------------------+
#property script_show_inputs
#property strict

// 530008594 was referred to as both a "ticket" and a "position" in prior
// notes, so this tries it as a DEAL ticket first, then as a POSITION id.
input ulong InpId = 530008594;

string EntryStr(long e)
{
   return e==DEAL_ENTRY_IN     ? "IN"
        : e==DEAL_ENTRY_OUT    ? "OUT"
        : e==DEAL_ENTRY_OUT_BY ? "OUT_BY"
        : e==DEAL_ENTRY_INOUT  ? "INOUT"
        : "UNKNOWN";
}

void DumpDeal(ulong t)
{
   long     entry  = HistoryDealGetInteger(t, DEAL_ENTRY);
   long     magic  = HistoryDealGetInteger(t, DEAL_MAGIC);
   long     posid  = HistoryDealGetInteger(t, DEAL_POSITION_ID);
   long     order  = HistoryDealGetInteger(t, DEAL_ORDER);
   long     reason = HistoryDealGetInteger(t, DEAL_REASON);
   string   sym    = HistoryDealGetString(t, DEAL_SYMBOL);
   string   cmt    = HistoryDealGetString(t, DEAL_COMMENT);
   datetime tm     = (datetime)HistoryDealGetInteger(t, DEAL_TIME);
   PrintFormat("deal=%I64u time=%s sym=%s entry=%s(%d) magic=%I64d position_id=%I64d order=%I64d reason=%d comment='%s'",
               t, TimeToString(tm, TIME_DATE|TIME_SECONDS), sym,
               EntryStr(entry), (int)entry, magic, posid, order, (int)reason, cmt);
}

void OnStart()
{
   datetime to   = TimeCurrent() + 86400;
   datetime from = to - 120 * 86400;   // 120-day window so the deal is loadable
   if(!HistorySelect(from, to)) { Print("HistorySelect failed for range"); return; }

   Print("===== T-4 DEAL DUMP for id ", InpId, " =====");

   // Interpretation 1: InpId is a DEAL ticket.
   if(HistoryDealSelect(InpId)) {
      Print("[matched as DEAL ticket]");
      DumpDeal(InpId);
      Print("PASS criteria: entry=OUT (NOT OUT_BY) | magic == exit magic | position_id NON-ZERO | comment=V2_Exit");
      return;
   }

   // Interpretation 2: InpId is a POSITION id -> dump its whole deal lifecycle.
   if(HistorySelectByPosition(InpId)) {
      int n = HistoryDealsTotal();
      if(n > 0) {
         PrintFormat("[matched as POSITION id -- %d deal(s) in lifecycle]", n);
         for(int i = 0; i < n; i++) {
            ulong t = HistoryDealGetTicket(i);
            if(t > 0) DumpDeal(t);
         }
         Print("The CLOSING deal is the one with entry=OUT or OUT_BY -- check its magic + position_id.");
         return;
      }
   }

   PrintFormat("id %I64u NOT FOUND as deal ticket or position. Likely wrong terminal/account "
               "(must be the one logged into 1514432484), or outside the 120-day window.", InpId);
}
