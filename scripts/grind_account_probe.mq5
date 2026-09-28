//+------------------------------------------------------------------+
//| grind_account_probe.mq5 -- READ-ONLY account limits (C78)        |
//| Prints the broker's maximum active pending orders for this       |
//| account (ACCOUNT_LIMIT_ORDERS; 0 = no limit) and what the book   |
//| holds now. Places, modifies and deletes nothing; writes no       |
//| GlobalVariables and no files. Safe beside live EAs.              |
//+------------------------------------------------------------------+
#property copyright "fxmatrix"
#property version   "1.00"

void OnStart()
{
   PrintFormat("ACCTPROBE|BEGIN|login=%I64d|server=%s|company=%s",
               AccountInfoInteger(ACCOUNT_LOGIN),
               AccountInfoString(ACCOUNT_SERVER),
               AccountInfoString(ACCOUNT_COMPANY));
   PrintFormat("ACCTPROBE|LIMIT_ORDERS|%I64d|(0 = no limit on active pending orders)",
               AccountInfoInteger(ACCOUNT_LIMIT_ORDERS));
   PrintFormat("ACCTPROBE|NOW|positions=%d|orders=%d|sum=%d",
               PositionsTotal(), OrdersTotal(), PositionsTotal() + OrdersTotal());
   PrintFormat("ACCTPROBE|MODE|margin_mode=%I64d|trade_expert=%I64d|leverage=%I64d",
               AccountInfoInteger(ACCOUNT_MARGIN_MODE),
               AccountInfoInteger(ACCOUNT_TRADE_EXPERT),
               AccountInfoInteger(ACCOUNT_LEVERAGE));
   Print("ACCTPROBE|END");
}
