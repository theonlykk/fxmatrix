//+------------------------------------------------------------------+
//| fxmatrix_v2_eurgbp_dual_cap.mqh — EURGBP-only dual cap helpers   |
//| Composite sync + combined gate (GBP + EUR). Not generic.         |
//+------------------------------------------------------------------+
#ifndef FXMATRIX_V2_EURGBP_DUAL_CAP_MQH
#define FXMATRIX_V2_EURGBP_DUAL_CAP_MQH

#include "fxmatrix_v2_gbp_cap.mqh"
#include "fxmatrix_v2_eur_cap.mqh"

//+------------------------------------------------------------------+
void V2_SyncAllCaps(const bool is_long, const int layer_count)
{
   V2_GbpCapSyncInstance("EURGBP", is_long, layer_count);
   V2_EurCapSyncInstance("EURGBP", is_long, layer_count);
}

//+------------------------------------------------------------------+
void V2_EvalBothCaps(const bool is_long,
                     const int gbp_threshold,
                     const int eur_threshold,
                     bool &gbp_blocked,
                     bool &eur_blocked,
                     string &eval_log)
{
   gbp_blocked = V2_GbpCapBlocksNewAdd("EURGBP", is_long, gbp_threshold);
   eur_blocked = V2_EurCapBlocksNewAdd("EURGBP", is_long, eur_threshold);
   eval_log = StringFormat(
      "GBP cap: blocked=%s net=%.0f threshold=%d | EUR cap: blocked=%s net=%.0f threshold=%d",
      gbp_blocked ? "true" : "false",
      V2_GbpNetExposure(),
      gbp_threshold,
      eur_blocked ? "true" : "false",
      V2_EurNetExposure(),
      eur_threshold);
}

//+------------------------------------------------------------------+
bool V2_AnyCapBlocksNewAdd(const bool is_long,
                           const int gbp_threshold,
                           const int eur_threshold)
{
   bool gbp_blocked = false;
   bool eur_blocked = false;
   string eval_log = "";
   V2_EvalBothCaps(is_long, gbp_threshold, eur_threshold, gbp_blocked, eur_blocked, eval_log);
   Print("INFO V2 cap eval | ", eval_log);

   if(gbp_blocked)
      V2_GbpCapRecordBlock();
   if(eur_blocked)
      V2_EurCapRecordBlock();

   return gbp_blocked || eur_blocked;
}

#endif // FXMATRIX_V2_EURGBP_DUAL_CAP_MQH
