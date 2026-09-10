//+------------------------------------------------------------------+
//| grind_recon_failure.mqh — global recon-failure payload for heartbeat|
//+------------------------------------------------------------------+
#ifndef GRIND_RECON_FAILURE_MQH
#define GRIND_RECON_FAILURE_MQH

string g_grind_recon_failure_json = "";

//+------------------------------------------------------------------+
void Grind_ReconFailureClear()
{
   g_grind_recon_failure_json = "";
}

//+------------------------------------------------------------------+
string Grind_ReconFailureHeartbeatField()
{
   if(g_grind_recon_failure_json == "")
      return "null";
   return g_grind_recon_failure_json;
}

#endif // GRIND_RECON_FAILURE_MQH
