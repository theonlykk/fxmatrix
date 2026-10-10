//+------------------------------------------------------------------+
//| fxgrind_replay.mq5 — IC tick replay run script                   |
//+------------------------------------------------------------------+
#property copyright "fxmatrix"
#property version   "1.00"
#property script_show_inputs
#property strict

#include "fxgrind_replay_core.mqh"

input string InpRunTag = "calib";
input bool   InpSync = false;
input int    InpTiming = 0;
input string InpSens = "base";

void OnStart()
{
   Print("RPL|MIRRORS_EA|", RPL_MIRRORS_EA);
   if(!Rpl_CheckSafetyForRun()) {
      Print("RPL|ABORT|SAFETY");
      return;
   }
   if(!Rpl_WaitSymbolReady(60000))
      return;
   if(!Rpl_SetTiming(InpTiming, InpSens)) {
      Print("RPL|ABORT|TIMING_INPUT");
      return;
   }
   Print("RPL|TIMING|", InpTiming, "|", InpSens, "|", Rpl_TmD("PLACE"), "|", Rpl_TmD("MODIFY"), "|",
         Rpl_TmD("CLOSE_BY"), "|", Rpl_TmD("REMOVE"), "|", Rpl_TmD("LAM"), "|thru=", g_rpl_tm_thru_pts);
   Rpl_SetOutputSuffix(InpSync ? "_sync" : "_free");
   Print("RPL|RUN|", InpRunTag, "|sync=", InpSync ? 1 : 0, "|out=", InpRunTag, (InpSync ? "_sync" : "_free"));
   const int gv0 = Rpl_DeleteGrindGlobalVariables();
   Print("RPL|GV_DELETE|", gv0);
   if(!Rpl_RunReplayFiles(InpRunTag, InpSync)) {
      if(Rpl_WasAborted())
         Print("RPL|ABORT|", Rpl_AbortReason());
      return;
   }
   const int gv1 = Rpl_DeleteGrindGlobalVariables();
   Print("RPL|GV_DELETE|", gv1);
   Print("RPL|DONE|", InpRunTag);
}
