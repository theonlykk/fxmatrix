//+------------------------------------------------------------------+
//| fxmatrix_v2_gbp_cap.mqh — cross-chart GBP net-exposure add gate  |
//| Net GBP = (L_GBPUSD - S_GBPUSD) - (L_EURGBP - S_EURGBP)          |
//| Gates new grid adds only (not reload, not L0, not exits).         |
//| Cross-instance: MT5 terminal Global Variables (read peer, write   |
//| own key only). Missing peer GV => layer count 0 (permissive).     |
//+------------------------------------------------------------------+
#ifndef FXMATRIX_V2_GBP_CAP_MQH
#define FXMATRIX_V2_GBP_CAP_MQH

#define V2_GBP_CAP_GV_GBP_LONG   "V2GBP_L_GBPUSD"
#define V2_GBP_CAP_GV_GBP_SHORT  "V2GBP_S_GBPUSD"
#define V2_GBP_CAP_GV_EGP_LONG   "V2GBP_L_EURGBP"
#define V2_GBP_CAP_GV_EGP_SHORT  "V2GBP_S_EURGBP"

//+------------------------------------------------------------------+
//| Read peer layer count. If GV absent (peer EA not attached / not   |
//| yet synced), return 0 — permissive default, never blocks alone.  |
//+------------------------------------------------------------------+
long V2_GbpCapReadLayers(const string gv_key)
{
   if(!GlobalVariableCheck(gv_key))
      return 0;
   return (long)GlobalVariableGet(gv_key);
}

//+------------------------------------------------------------------+
void V2_GbpCapPublishLayers(const string gv_key, const int layers)
{
   GlobalVariableSet(gv_key, (double)layers);
}

//+------------------------------------------------------------------+
string V2_GbpCapGvKey(const string pair_label, const bool is_long)
{
   if(pair_label == "GBPUSD")
      return is_long ? V2_GBP_CAP_GV_GBP_LONG : V2_GBP_CAP_GV_GBP_SHORT;
   if(pair_label == "EURGBP")
      return is_long ? V2_GBP_CAP_GV_EGP_LONG : V2_GBP_CAP_GV_EGP_SHORT;
   return "";
}

//+------------------------------------------------------------------+
double V2_GbpNetExposure()
{
   long gbp_l = V2_GbpCapReadLayers(V2_GBP_CAP_GV_GBP_LONG);
   long gbp_s = V2_GbpCapReadLayers(V2_GBP_CAP_GV_GBP_SHORT);
   long egp_l = V2_GbpCapReadLayers(V2_GBP_CAP_GV_EGP_LONG);
   long egp_s = V2_GbpCapReadLayers(V2_GBP_CAP_GV_EGP_SHORT);
   return (double)((gbp_l - gbp_s) - (egp_l - egp_s));
}

//+------------------------------------------------------------------+
double V2_GbpCapDeltaForAdd(const string pair_label, const bool is_long)
{
   if(pair_label == "GBPUSD")
      return is_long ? 1.0 : -1.0;
   if(pair_label == "EURGBP")
      return is_long ? -1.0 : 1.0;
   return 0.0;
}

//+------------------------------------------------------------------+
//| Block only a widening add that would push |net| strictly above    |
//| threshold. Landing exactly on threshold (e.g. 11 -> 12) allowed. |
//| EURUSD and other pairs: delta=0 => never blocked.                 |
//+------------------------------------------------------------------+
bool V2_GbpCapBlocksNewAdd(const string pair_label,
                           const bool is_long,
                           const int threshold)
{
   if(threshold <= 0)
      return false;

   double delta = V2_GbpCapDeltaForAdd(pair_label, is_long);
   if(delta == 0.0)
      return false;

   double net = V2_GbpNetExposure();
   double new_net = net + delta;

   if(MathAbs(new_net) <= MathAbs(net) + 1e-9)
      return false;

   return MathAbs(new_net) > (double)threshold;
}

//+------------------------------------------------------------------+
void V2_GbpCapSyncInstance(const string pair_label, const bool is_long, const int layer_count)
{
   string key = V2_GbpCapGvKey(pair_label, is_long);
   if(key != "")
      V2_GbpCapPublishLayers(key, layer_count);
}

//+------------------------------------------------------------------+
void V2_GbpCapRecordBlock()
{
   string gv = "V2GBP_CAP_TRIGGERS";
   double n = GlobalVariableCheck(gv) ? GlobalVariableGet(gv) : 0.0;
   GlobalVariableSet(gv, n + 1.0);
}

#endif // FXMATRIX_V2_GBP_CAP_MQH
