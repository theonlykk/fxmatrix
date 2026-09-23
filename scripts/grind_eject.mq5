//+------------------------------------------------------------------+
//| grind_eject.mq5 — ADR-155 operator command (passive ejection)    |
//+------------------------------------------------------------------+
#property copyright "fxmatrix"
#property version   "1.00"
#property strict
#property script_show_inputs

input ulong InpMagic  = 0;
input ulong InpTicket = 0;

//+------------------------------------------------------------------+
void OnStart()
{
   if(InpMagic == 0 || InpTicket == 0) {
      Print("grind_eject: refuse -- InpMagic and InpTicket must be non-zero");
      return;
   }
   const string name = "GRIND_EJECT_" + IntegerToString((long)InpMagic);
   GlobalVariableSet(name, (double)InpTicket);
   Print("grind_eject: set ", name, " = ", InpTicket);
}
