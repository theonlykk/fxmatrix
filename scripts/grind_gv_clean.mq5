//+------------------------------------------------------------------+
//| grind_gv_clean.mq5 -- delete persistent GRIND GlobalVariables     |
//| for account switch. No trading. Run after terminal restart.       |
//+------------------------------------------------------------------+
#property copyright "fxmatrix"
#property version   "1.00"
#property script_show_inputs
#property strict

input bool InpForce = false;   // bypass the running-fleet guard

//+------------------------------------------------------------------+
void OnStart()
{
   const string heartbeat = "GRIND_MAE_REPORTER_HEARTBEAT";
   if(GlobalVariableCheck(heartbeat) && !InpForce) {
      Print("grind_gv_clean: ABORT -- GRIND_MAE_REPORTER_HEARTBEAT exists. ",
            "Detach all fxgrind EAs, CLOSE and reopen the terminal, then run again. ",
            "Use InpForce=true ONLY if all EAs are detached, the terminal has been ",
            "restarted, and the variable still exists.");
      return;
   }
   if(GlobalVariableCheck(heartbeat) && InpForce)
      Print("grind_gv_clean: WARNING -- GRIND_MAE_REPORTER_HEARTBEAT still exists; ",
            "proceeding because InpForce=true.");

   const string prefixes[] = {
      "GRIND_DAILY_API_COUNT",
      "GRIND_DAILY_API_DATE",
      "GRIND_MAE_ANCHOR_",
      "GRIND_MAE_EQUITY_LOW_",
      "GRIND_CARRY_DAY_",
      "GRIND_CARRY_SHIFT_",
      "GRIND_CARRY_ACCRUED_",
      "GRIND_CARRY_RELEASE_",
      "GRIND2226_",
      "GRIND_DEINIT_"
   };

   int total_deleted = 0;
   const int n_prefix = ArraySize(prefixes);
   for(int p = 0; p < n_prefix; p++) {
      const int n = GlobalVariablesDeleteAll(prefixes[p]);
      Print("grind_gv_clean: prefix ", prefixes[p], " deleted=", n);
      total_deleted += n;
   }

   int remaining_grind = 0;
   const int gv_total = GlobalVariablesTotal();
   for(int i = 0; i < gv_total; i++) {
      const string name = GlobalVariableName(i);
      if(StringFind(name, "GRIND") == 0) {
         Print("grind_gv_clean: remaining ", name);
         remaining_grind++;
      }
   }

   Print("grind_gv_clean: DONE deleted=", total_deleted,
         " remaining_grind=", remaining_grind);
}
